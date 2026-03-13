import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:usb_serial/usb_serial.dart';

import 'package:soil_sensor/models/sensor_reading.dart';
import 'package:soil_sensor/services/modbus_rtu_service.dart';

/// High-level USB serial sensor service.
///
/// Abstracts over platform differences (Android: usb_serial / Windows: flutter_libserialport).
/// Implements Modbus RTU FC03 to read soil sensor registers.
class SoilSensorService {
  SoilSensorService({this.baudRate = 9600, this.slaveAddress = 1});

  int baudRate;
  int slaveAddress;

  // ── Android-specific state ────────────────────────────────────────────────
  UsbPort? _usbPort;
  final Map<String, UsbDevice> _androidDevices = {};

  // ── Windows-specific state ────────────────────────────────────────────────
  SerialPort? _winPort;

  // ─────────────────────────────────────────────────────────────────────────

  bool get isConnected {
    if (Platform.isAndroid) return _usbPort != null;
    if (Platform.isWindows) return _winPort != null && _winPort!.isOpen;
    return false;
  }

  // ── Device discovery ─────────────────────────────────────────────────────

  /// Returns displayable / connectable device identifiers.
  Future<List<String>> listDevices() async {
    _androidDevices.clear();
    if (Platform.isAndroid) {
      final devices = await UsbSerial.listDevices();
      final names = <String>[];
      for (final d in devices) {
        final key =
            '${d.manufacturerName ?? 'USB'} (${d.vid?.toRadixString(16).toUpperCase()}:${d.pid?.toRadixString(16).toUpperCase()})';
        _androidDevices[key] = d;
        names.add(key);
      }
      return names;
    }
    if (Platform.isWindows) {
      return SerialPort.availablePorts;
    }
    throw UnsupportedError('USB serial is not supported on this platform.');
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Open connection to [deviceId] (as returned by [listDevices]).
  Future<void> connect(String deviceId) async {
    await disconnect(); // clean up any previous connection

    if (Platform.isAndroid) {
      final device = _androidDevices[deviceId];
      if (device == null) throw StateError('Device not found: $deviceId');
      final port = await device.create();
      if (port == null) throw StateError('Failed to create port for $deviceId');
      final opened = await port.open();
      if (!opened) throw StateError('Permission denied or port busy: $deviceId');
      await port.setPortParameters(
        baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
      await port.setDTR(true);
      await port.setRTS(true);
      _usbPort = port;
    } else if (Platform.isWindows) {
      final port = SerialPort(deviceId);
      if (!port.openReadWrite()) {
        throw StateError(
            'Cannot open $deviceId: ${SerialPort.lastError?.message}');
      }
      final cfg = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none
        ..xonXoff = 0
        ..rts = SerialPortRts.flowControl
        ..cts = SerialPortCts.ignore
        ..dsr = SerialPortDsr.ignore
        ..dtr = SerialPortDtr.flowControl;
      port.config = cfg;
      _winPort = port;
    } else {
      throw UnsupportedError('USB serial not supported on this platform.');
    }

    // Allow port to stabilise (as specified in the protocol doc).
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  /// Close the active connection.
  Future<void> disconnect() async {
    if (Platform.isAndroid) {
      await _usbPort?.close();
      _usbPort = null;
    } else if (Platform.isWindows) {
      _winPort?.close();
      _winPort?.dispose();
      _winPort = null;
    }
  }

  // ── Reading ───────────────────────────────────────────────────────────────

  /// Read sensor data with up to [maxRetries] attempts.
  ///
  /// First attempts the extended 7-register read (moisture, temperature,
  /// conductivity, pH, N, P, K).  Falls back to the basic 3-register read
  /// if the sensor returns a Modbus exception 0x02 (Illegal Data Address).
  Future<SensorReading> readSensor({int maxRetries = 3}) async {
    if (!isConnected) throw StateError('Not connected to sensor.');

    Object? lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      try {
        return await _tryReadExtended();
      } on StateError catch (e) {
        // Modbus exception 0x02 = sensor only has 3 registers — don't retry.
        if (e.message.contains('Illegal Data Address')) {
          return await _tryReadBasic();
        }
        lastError = e;
      } on Exception catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('Failed to read sensor after $maxRetries attempts.');
  }

  Future<SensorReading> _tryReadExtended() async {
    final request = ModbusRtuService.buildReadRequest(
      slaveAddress: slaveAddress,
      startRegister: 0x0000,
      registerCount: 7,
    );
    final expected = ModbusRtuService.expectedResponseLength(7);
    final response = await _transact(request, expected);
    final registers = ModbusRtuService.parseReadResponse(response, 7);
    final values = ModbusRtuService.scaleExtendedRegisters(registers);
    return _buildReading(values, hasNpk: true);
  }

  Future<SensorReading> _tryReadBasic() async {
    final request = ModbusRtuService.buildReadRequest(
      slaveAddress: slaveAddress,
      startRegister: 0x0000,
      registerCount: 3,
    );
    final expected = ModbusRtuService.expectedResponseLength(3);
    final response = await _transact(request, expected);
    final registers = ModbusRtuService.parseReadResponse(response, 3);
    final values = ModbusRtuService.scaleBasicRegisters(registers);
    return _buildReading(values, hasNpk: false);
  }

  SensorReading _buildReading(Map<String, double> v, {required bool hasNpk}) {
    return SensorReading(
      moisture: v['moisture'] ?? 0,
      temperature: v['temperature'] ?? 0,
      conductivity: v['conductivity'] ?? 0,
      ph: v['ph'] ?? 0,
      nitrogen: v['nitrogen'] ?? 0,
      phosphorus: v['phosphorus'] ?? 0,
      potassium: v['potassium'] ?? 0,
      readAt: DateTime.now(),
    );
  }

  // ── Platform-specific transact ────────────────────────────────────────────

  /// Send [request] bytes and wait for exactly [expectedLength] response bytes.
  Future<Uint8List> _transact(Uint8List request, int expectedLength) async {
    if (Platform.isAndroid) {
      return _transactAndroid(request, expectedLength);
    } else if (Platform.isWindows) {
      return _transactWindows(request, expectedLength);
    }
    throw UnsupportedError('Unsupported platform.');
  }

  Future<Uint8List> _transactAndroid(
      Uint8List request, int expectedLength) async {
    final port = _usbPort!;
    final buffer = <int>[];
    final completer = Completer<Uint8List>();
    late StreamSubscription<Uint8List> sub;

    sub = port.inputStream!.listen(
      (data) {
        buffer.addAll(data);
        if (buffer.length >= expectedLength && !completer.isCompleted) {
          sub.cancel();
          completer.complete(
              Uint8List.fromList(buffer.sublist(0, expectedLength)));
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          sub.cancel();
          completer.completeError(e);
        }
      },
    );

    await port.write(request);

    return completer.future.timeout(
      const Duration(milliseconds: 1000),
      onTimeout: () {
        sub.cancel();
        throw TimeoutException(
          'Timeout waiting for response.\n'
          'Received: ${buffer.length}/$expectedLength bytes.\n'
          'Check baud rate, slave address, and wiring.',
        );
      },
    );
  }

  Future<Uint8List> _transactWindows(
      Uint8List request, int expectedLength) async {
    final port = _winPort!;
    final buffer = <int>[];
    final completer = Completer<Uint8List>();
    final reader = SerialPortReader(port, timeout: 1100);
    late StreamSubscription<Uint8List> sub;

    sub = reader.stream.listen(
      (data) {
        buffer.addAll(data);
        if (buffer.length >= expectedLength && !completer.isCompleted) {
          sub.cancel();
          completer.complete(
              Uint8List.fromList(buffer.sublist(0, expectedLength)));
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          sub.cancel();
          completer.completeError(e);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
              TimeoutException('Port stream ended before response complete.'));
        }
      },
    );

    port.write(request);

    return completer.future.timeout(
      const Duration(milliseconds: 1000),
      onTimeout: () {
        sub.cancel();
        throw TimeoutException(
          'Timeout waiting for response.\n'
          'Received: ${buffer.length}/$expectedLength bytes.',
        );
      },
    );
  }
}
