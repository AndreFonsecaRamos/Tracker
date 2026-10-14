# Remo App - Project Guidelines & Development Memory

This document serves as the persistent architectural reference, technical specification, and progress/lessons-learned log for the Remo app. It is automatically loaded into context at the start of every session to guide development and prevent repeating past errors.

---

## 1. Core Architecture & Components

- **State Management**: Provider (`ChangeNotifier`, `Selector`, `Consumer2`) is used for reactive state management across screens (`JustRow`, `PaginaMetros`, `SegundaPagina`).
- **Sensor Analysis (`ImprovedMovementAnalyzer` in `lib/movementeanalizer.dart`)**:
  - Processes high-frequency accelerometer events (`sensors_plus`).
  - Applies low-pass smoothing (`_alphaSmooth = 0.10`) and gravity isolation (`_alphaGravity = 0.002`).
  - Hysteresis stroke detection with `driveThreshold = 0.30` and `thresholdRecovery = -0.12`.
- **GPS Tracking & Pace (`GPSController` in `lib/expGPS.dart`)**:
  - Uses `geolocator` with high navigation accuracy (`LocationAccuracy.bestForNavigation`).
  - Rolling window (`_windowDurationSeconds = 3`) combined with Double Exponential Moving Average (EMA) to smooth speed and pace (`parcialPor500m`).

---

## 2. Lessons Learned & Water Testing Guidelines

### A. Voga Stability & Anti-Double-Counting
- **Issue**: Water chop, boat pitch, and secondary acceleration peaks during recovery or oar release previously caused double-counting of strokes.
- **Rules / Fixes**:
  - `_minStrokeInterval` must be at least **1250ms** (disallowing intervals shorter than 1.25s, corresponding to max ~48 SPM).
  - Stroke rate calculation (`_calculateStrokeRates`) must use a sliding window of the last 6 intervals (`_tamanhoMediaIntervalos = 6`) with a **trimmed mean** (discarding highest and lowest outliers when `length >= 5`) to prevent erratic spikes from water noise.

### B. Parcial (Pace) Responsiveness in Fast Starts & Series
- **Issue**: A 6-second rolling window and heavy EMA smoothing caused pace (`parcialPor500m`) to lag during explosive starts or sudden rate/power increases.
- **Rules / Fixes**:
  - Rolling window duration (`_windowDurationSeconds`) must be kept at **3 seconds** so old slow/stopped samples flush out quickly.
  - EMA alpha weights must remain reactive (`_alpha1 = 0.45`, `_alpha2 = 0.25`) so speed changes reflect immediately without excessive lag.

---

## 3. Progress & Change Log

- **Session (October 2026)**:
  - Fixed voga instability and overcounting by increasing `_minStrokeInterval` to 1250ms, expanding buffer to 6 intervals, and adding trimmed mean outlier rejection.
  - Fixed split/parcial update latency during fast starts and series by shortening the GPS rolling window to 3 seconds and tuning EMA filter responsiveness.
