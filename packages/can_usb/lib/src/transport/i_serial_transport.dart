/// Abstract serial transport interface.
///
/// Implemented by [SerialPortTransport] (using `flutter_libserialport`, for
/// Windows / Linux / macOS) and [AndroidSerialTransport] (using `usb_serial`,
/// for Android). Can also be implemented by a mock for unit testing.
library;

import 'dart:typed_data';

/// Describes an available serial port.
class SerialPortInfo {
  /// OS-level port name (e.g. `COM3` on Windows, `/dev/ttyACM0` on Linux).
  final String name;

  /// Human-readable description reported by the OS / driver, if available.
  final String? description;

  const SerialPortInfo({required this.name, this.description});

  @override
  String toString() => 'SerialPortInfo(name=$name, description=$description)';
}

/// Abstract contract for a serial transport layer.
abstract class ISerialTransport {
  /// Stream of raw bytes received from the device.
  Stream<Uint8List> get dataStream;

  /// Returns a list of currently available serial ports on the system.
  Future<List<SerialPortInfo>> listAvailablePorts();

  /// Opens [portName] at [baudRate] bps.
  ///
  /// Throws a [CanConnectionException] on failure.
  Future<void> connect(String portName, {int baudRate = 115200});

  /// Closes the connection and releases resources.
  Future<void> disconnect();

  /// Sends [data] to the device.
  Future<void> write(Uint8List data);

  /// Whether the port is currently open.
  bool get isConnected;
}
