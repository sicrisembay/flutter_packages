/// [SerialPortTransport] — concrete [ISerialTransport] implementation backed by
/// `flutter_libserialport` (supports Android, Windows, and Linux).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../exceptions.dart';
import 'i_serial_transport.dart';

export 'i_serial_transport.dart';

/// Serial transport implementation using `flutter_libserialport`.
///
/// Wraps [SerialPort] and [SerialPortReader] to expose a unified
/// [ISerialTransport] interface across Android, Windows, and Linux.
///
/// Usage:
/// ```dart
/// final transport = SerialPortTransport();
/// final ports = await transport.listAvailablePorts();
/// await transport.connect(ports.first.name);
/// transport.dataStream.listen((bytes) { ... });
/// await transport.write(someFrame);
/// await transport.disconnect();
/// ```
class SerialPortTransport implements ISerialTransport {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamController<Uint8List>? _controller;

  // Completer that is resolved by the reader's onDone callback.
  // disconnect() awaits this (with a safety timeout) instead of using a fixed
  // delay, ensuring we only close the OS handle after the reader isolate has
  // truly finished its last native read call.
  Completer<void>? _readerClosed;

  @override
  bool get isConnected => _port?.isOpen ?? false;

  @override
  Stream<Uint8List> get dataStream {
    _controller ??= StreamController<Uint8List>.broadcast();
    return _controller!.stream;
  }

  @override
  Future<List<SerialPortInfo>> listAvailablePorts() async {
    final portNames = SerialPort.availablePorts;
    final result = <SerialPortInfo>[];
    for (final name in portNames) {
      String? description;
      try {
        final sp = SerialPort(name);
        description = sp.description;
        sp.dispose();
      } catch (_) {
        // Description not available for this port — skip silently.
      }
      result.add(SerialPortInfo(name: name, description: description));
    }
    return result;
  }

  @override
  Future<void> connect(String portName, {int baudRate = 115200}) async {
    if (isConnected) await disconnect();

    // Always create a fresh broadcast controller so listeners from a previous
    // session do not receive data from the new session.
    await _controller?.close();
    _controller = StreamController<Uint8List>.broadcast();

    final port = SerialPort(portName);
    _port = port;

    final config = SerialPortConfig();
    config.baudRate = baudRate;
    config.bits = 8;
    config.stopBits = 1;
    config.parity = SerialPortParity.none;
    config.setFlowControl(SerialPortFlowControl.none);

    if (!port.openReadWrite()) {
      final err = SerialPort.lastError;
      throw CanConnectionException(
        'Failed to open "$portName": ${err?.message ?? "unknown error"}',
      );
    }

    try {
      port.config = config;
    } catch (e) {
      port.close();
      throw CanConnectionException(
        'Failed to configure "$portName": $e',
      );
    }

    config.dispose();

    // Fresh completer for this connection's reader lifetime.
    final readerClosed = Completer<void>();
    _readerClosed = readerClosed;

    final reader = SerialPortReader(port);
    _reader = reader;
    reader.stream.listen(
      (data) => _controller?.add(Uint8List.fromList(data)),
      onError: (Object err) {
        _controller?.addError(err);
        // A read error almost always means the USB device was physically
        // removed.  Mark the transport as disconnected immediately so that
        // callers get an accurate isConnected == false without having to
        // wait for onDone (which may never fire on Windows in this case).
        if (identical(_reader, reader)) {
          if (!readerClosed.isCompleted) readerClosed.complete();
          // Explicitly close the OS handle so Windows can update its COM
          // port enumeration and the same port can be re-opened after
          // the device is plugged back in.
          try {
            _port?.close();
          } catch (_) {}
          _port = null;
          _reader = null;
          _readerClosed = null;
        }
      },
      onDone: () {
        if (!readerClosed.isCompleted) readerClosed.complete();
        // Only null out the fields if this reader is still the active one.
        // Guards against a race where disconnect() has already swapped in a
        // new connection by the time onDone fires.
        if (identical(_reader, reader)) {
          _port = null;
          _reader = null;
          _readerClosed = null;
        }
      },
      cancelOnError: false,
    );
  }

  @override
  Future<void> disconnect() async {
    // Snapshot the completer before nulling fields so we can await it below.
    final readerClosed = _readerClosed;
    final port = _port;
    _reader?.close();
    _reader = null;
    _readerClosed = null;
    _port = null;

    // Wait for the reader isolate's onDone to fire, confirming the Dart stream
    // is closed.  A 500 ms ceiling prevents an infinite wait on driver bugs.
    if (readerClosed != null) {
      await readerClosed.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      );
    }

    // Close the OS handle (sp_close).
    port?.close();

    // Do NOT call port.dispose() (sp_free_port) here.
    // The reader isolate holds a copy of the native sp_port* pointer.
    // Even after onDone fires the native thread may not have fully exited,
    // so freeing the struct causes the CRT heap double-free assertion on
    // Windows.  We detach our Dart reference instead and let the GC collect
    // the SerialPort object once the isolate is truly gone.  A new SerialPort
    // instance is always created in connect(), so this does not leak handles.

    // Close the stream controller so any residual listeners receive onDone.
    await _controller?.close();
    _controller = null;
  }

  @override
  Future<void> write(Uint8List data) async {
    final port = _port;
    if (port == null || !port.isOpen) {
      throw CanConnectionException('Cannot write: port is not open.');
    }
    final written = port.write(data);
    if (written != data.length) {
      throw CanConnectionException(
        'Short write: expected ${data.length} bytes, wrote $written.',
      );
    }
  }

  /// Disposes of all resources. Call when the transport is no longer needed.
  void dispose() {
    disconnect();
    // _controller is closed by disconnect(); no further action needed.
  }
}
