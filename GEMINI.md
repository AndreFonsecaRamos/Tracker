# Remo App - Project Guidelines & Development Memory

> **Governança do Projeto:** As cláusulas pétreas, missão central e invariantes arquiteturais e sensoriais estão formalmente definidas em [`CONSTITUTION.md`](./CONSTITUTION.md).

This document serves as the persistent architectural reference, technical specification, and progress/lessons-learned log for the Remo app. It is automatically loaded into context at the start of every session to guide development and prevent repeating past errors.

---

## 1. Core Architecture & Components

- **State Management**: Provider (`ChangeNotifier`, `Selector`, `Consumer2`) is used for reactive state management across screens (`JustRow`, `PaginaMetros`, `SegundaPagina`).
- **Sensor Analysis (`ImprovedMovementAnalyzer` in `lib/movement_analyzer.dart`)**:
  - Processes high-frequency accelerometer events (`sensors_plus`).
  - Applies low-pass smoothing (`_alphaSmooth = 0.10`) and gravity isolation (`_alphaGravity = 0.002`).
  - Hysteresis stroke detection with `driveThreshold = 0.30` and `thresholdRecovery = -0.12`.
  - Stroke rate smoothing via EMA (`alpha = 0.35`) to prevent hunting/overshooting (e.g. 20 -> 23 -> 20).
- **GPS Tracking & Pace (`GPSController` in `lib/exp_gps.dart`)**:
  - Uses `geolocator` with high navigation accuracy (`LocationAccuracy.bestForNavigation`).
  - Rolling window (`_windowDurationSeconds = 2`) combined with Double Exponential Moving Average (EMA) (`_alpha1 = 0.55`, `_alpha2 = 0.35`) to ensure swift drop in split (`parcialPor500m`) during acceleration.
- **Heart Rate Monitor Support (`HeartRateController` in `lib/heart_rate_controller.dart`)**:
  - Integrates `flutter_blue_plus` for Bluetooth Low Energy (BLE) heart rate monitors (Standard HR Service `0x180D`, Measurement Characteristic `0x2A37`).
  - Records BPM per trackpoint and exports `<HeartRateBpm>` tags in TCX files for Strava.
  - Adds dedicated HR block in Concept 2 PM5 horizontal interface without cluttering other metrics.

---

## 2. Lessons Learned & Water Testing Guidelines

### A. Voga Stability & Anti-Double-Counting
- **Issue / Historical Trials**:
  - *Attempt 1*: Raw cadence from interval without smoothing or trimmed mean -> Resulted in double-counting from water chop and wild fluctuations.
  - *Attempt 2*: Added `_minStrokeInterval = 1250ms`, buffer of 6 intervals, and trimmed mean outlier rejection. This fixed double-counting, but cadence still suffered from **hunting / overshooting** (e.g. holding steady at 20 SPM but reading 22/23 and dropping back down due to minor interval variance).
- **Current Fix**:
  - Trimmed mean + **EMA smoothing (`alpha = 0.35`)** on `strokesPerMinute` to stabilize cadence without hunting.

### B. Parcial (Pace) Responsiveness in Fast Starts & Series
- **Issue / Historical Trials**:
  - *Attempt 1*: 6-second rolling window and heavy EMA (`_alpha1 = 0.45`, `_alpha2 = 0.25`) -> Resulted in severe lag during acceleration (split dropped way too slowly).
  - *Attempt 2 (Tested)*: 3-second rolling window with same EMA -> Still slightly too slow to reflect sudden speed increases during explosive starts.
  - *Attempt 3 (Current)*: 2-second rolling window (`_windowDurationSeconds = 2`) with more reactive EMA weights (`_alpha1 = 0.55`, `_alpha2 = 0.35`) to ensure swift drop in split (`parcialPor500m`) during acceleration.

---

## 3. Progress & Change Log

- **Session (November 2026 - Refactoring & Resilience)**:
  - Executed Phase 1: Normalized file naming conventions to `snake_case` (`movement_analyzer.dart`, `exp_gps.dart`).
  - Executed Phase 2: Decoupled architecture by extracting TCX export logic from `GPSController` into a dedicated `TcxExportService`.
  - Executed Phase 3 & 4: Enhanced `HeartRateController` with robust automatic BLE reconnection logic (exponential backoff up to 3 attempts) and clean error handling. Verified clean build with zero errors via `flutter analyze`.
