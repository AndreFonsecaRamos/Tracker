import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HeartRateController extends ChangeNotifier {
  int heartRate = 0;
  bool isScanning = false;
  bool isConnected = false;
  String connectedDeviceName = '';
  String errorMessage = '';

  List<ScanResult> scanResults = [];
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _hrSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  bool _isIntentionalDisconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  // UUIDs padrão para dispositivos de frequência cardíaca (Heart Rate Service & Measurement)
  static const String hrServiceUuid = "180d";
  static const String hrMeasurementUuid = "2a37";

  void startScan() async {
    if (isScanning) return;
    
    // Verificar se o Bluetooth está ligado
    if (await FlutterBluePlus.isSupported == false) {
      errorMessage = "Bluetooth não suportado neste dispositivo.";
      notifyListeners();
      return;
    }

    try {
      errorMessage = '';
      scanResults.clear();
      isScanning = true;
      notifyListeners();

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        scanResults = results;
        notifyListeners();
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid(hrServiceUuid)],
      );
    } catch (e) {
      errorMessage = "Erro no scan BLE: $e";
      isScanning = false;
      notifyListeners();
    }

    // Parar scan automaticamente após o timeout
    Timer(const Duration(seconds: 10), () {
      stopScan();
    });
  }

  void stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
    } catch (_) {}
    isScanning = false;
    notifyListeners();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    stopScan();
    errorMessage = '';
    _isIntentionalDisconnect = false;
    _reconnectAttempts = 0;
    
    try {
      connectedDeviceName = device.platformName.isNotEmpty ? device.platformName : "Banda Cardíaca";
      notifyListeners();

      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;
      isConnected = true;
      _reconnectAttempts = 0;
      notifyListeners();

      // Monitorizar estado de conexão
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (!_isIntentionalDisconnect) {
            _handleUnexpectedDisconnect(device);
          } else {
            disconnect();
          }
        }
      });

      // Descobrir serviços
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase().contains(hrServiceUuid)) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains(hrMeasurementUuid)) {
              await characteristic.setNotifyValue(true);
              _hrSubscription = characteristic.onValueReceived.listen((value) {
                _parseHeartRateData(value);
              });
            }
          }
        }
      }
    } catch (e) {
      errorMessage = "Erro ao ligar: $e";
      isConnected = false;
      _connectedDevice = null;
      notifyListeners();
    }
  }

  void _handleUnexpectedDisconnect(BluetoothDevice device) async {
    isConnected = false;
    heartRate = 0;
    notifyListeners();

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      debugPrint("BLE: Conexão perdida. A tentar reconectar (tentativa $_reconnectAttempts/$_maxReconnectAttempts)...");
      await Future.delayed(Duration(seconds: _reconnectAttempts * 2));
      if (!_isIntentionalDisconnect) {
        try {
          await device.connect(timeout: const Duration(seconds: 5));
          _connectedDevice = device;
          isConnected = true;
          errorMessage = '';
          notifyListeners();
        } catch (e) {
          debugPrint("BLE: Falha na reconexão: $e");
          _handleUnexpectedDisconnect(device);
        }
      }
    } else {
      errorMessage = "Perda de conexão com a banda cardíaca.";
      disconnect();
    }
  }

  void _parseHeartRateData(List<int> data) {
    if (data.isEmpty) return;

    // O primeiro byte contém flags
    int flags = data[0];
    int hrValue = 0;

    // Bit 0 indica o formato do valor da frequência cardíaca (0 = 8-bit, 1 = 16-bit)
    bool is16Bit = (flags & 0x01) != 0;

    if (!is16Bit && data.length >= 2) {
      hrValue = data[1];
    } else if (is16Bit && data.length >= 3) {
      hrValue = data[1] + (data[2] << 8);
    }

    if (hrValue > 0) {
      heartRate = hrValue;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _isIntentionalDisconnect = true;
    try {
      await _hrSubscription?.cancel();
      await _connectionStateSubscription?.cancel();
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
    } catch (_) {}

    _connectedDevice = null;
    isConnected = false;
    isScanning = false;
    connectedDeviceName = '';
    heartRate = 0;
    errorMessage = '';
    notifyListeners();
  }

  void reset() {
    heartRate = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
