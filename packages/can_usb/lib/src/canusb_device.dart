/// High-level device API for the USB-CANFD adapter.
///
/// [CanusbDevice] orchestrates the transport, frame protocol, and commands
/// into a single, easy-to-use object.
///
/// Typical usage:
/// ```dart
/// final device = CanusbDevice();
/// final ports = await device.listAvailablePorts();
/// await device.connect(ports.first.name);
///
/// device.rxFrames.listen((frame) => print('RX: $frame'));
/// device.protocolStatus.listen((s) => print('Status: $s'));
///
/// final id = await device.getDeviceId(); // should be 0xAC
/// await device.canStart();
/// await device.sendFrame(myCanFrame);
/// await device.disconnect();
/// ```
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:synchronized/synchronized.dart';

import 'commands/command_ids.dart';
import 'commands/cmd_get_device_id.dart';
import 'commands/cmd_can_start_stop.dart';
import 'models/bitrate.dart';
import 'commands/cmd_send_downstream.dart';
import 'commands/cmd_send_upstream.dart';
import 'commands/cmd_protocol_status.dart';
import 'commands/cmd_can_stats.dart';
import 'commands/cmd_enter_dfu.dart';
import 'exceptions.dart';
import 'models/can_frame.dart';
import 'models/device_id_info.dart';
import 'protocol/frame_builder.dart';
import 'protocol/frame_parser.dart';
import 'transport/android_serial_transport.dart';
import 'transport/serial_port_transport.dart';

export 'transport/i_serial_transport.dart' show SerialPortInfo;

/// Default response timeout applied to all request/response commands.
const Duration kDefaultCommandTimeout = Duration(seconds: 2);

/// High-level USB-CANFD device API.
///
/// Pass a custom [ISerialTransport] for testing/mocking; omit it (or pass
/// `null`) to use the default [SerialPortTransport].
class CanusbDevice {
  final ISerialTransport _transport;

  // Outgoing sequence number (wraps at 65535).
  int _seqNum = 0;

  // Frame parser wired to the transport stream.
  final FrameParser _parser = FrameParser();
  StreamSubscription<Uint8List>? _transportSub;
  StreamSubscription<ParsedFrame>? _parserSub;

  // Mutex — allows only one request/response in-flight at a time.
  final Lock _lock = Lock();

  // Pending completers keyed by command ID.
  final Map<int, Completer<Uint8List>> _pending = {};

  // Broadcast stream controllers for unsolicited notifications.
  final StreamController<CanFrame> _rxFramesCtrl =
      StreamController.broadcast();
  final StreamController<CanFrame> _txFramesCtrl =
      StreamController.broadcast();
  final StreamController<ProtocolStatus> _protocolStatusCtrl =
      StreamController.broadcast();
  final StreamController<CanStats> _canStatsNotifCtrl =
      StreamController.broadcast();

  /// Response timeout applied to all request/response commands.
  final Duration commandTimeout;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// Creates a [CanusbDevice].
  ///
  /// [transport] — inject a custom transport for testing; omit it to use
  /// the correct transport for the current platform automatically:
  /// [AndroidSerialTransport] on Android, [SerialPortTransport] elsewhere.
  ///
  /// [commandTimeout] — how long to wait for a response before throwing
  /// [CanTimeoutException].
  CanusbDevice({
    ISerialTransport? transport,
    this.commandTimeout = kDefaultCommandTimeout,
  }) : _transport = transport ??
            (Platform.isAndroid
                ? AndroidSerialTransport()
                : SerialPortTransport()) {
    // Wire parsed frames into the routing handler.
    _parserSub = _parser.frames.listen(_routeFrame);
  }

  // ---------------------------------------------------------------------------
  // Public notification streams
  // ---------------------------------------------------------------------------

  /// Stream of CAN / CAN-FD frames received from the bus (CMD_SEND_UPSTREAM).
  Stream<CanFrame> get rxFrames => _rxFramesCtrl.stream;

  /// Stream of CAN / CAN-FD frames successfully sent to the bus (CMD_SEND_DOWNSTREAM).
  Stream<CanFrame> get txFrames => _txFramesCtrl.stream;

  /// Stream of FDCAN protocol status notifications (CMD_PROTOCOL_STATUS).
  Stream<ProtocolStatus> get protocolStatus => _protocolStatusCtrl.stream;

  /// Stream of unsolicited CAN stats notifications (CMD_GET_CAN_STATS).
  Stream<CanStats> get canStatsNotifications => _canStatsNotifCtrl.stream;

  /// Whether the serial port is currently open.
  bool get isConnected => _transport.isConnected;

  // ---------------------------------------------------------------------------
  // Connection management
  // ---------------------------------------------------------------------------

  /// Lists available serial ports on the current system.
  Future<List<SerialPortInfo>> listAvailablePorts() =>
      _transport.listAvailablePorts();

  /// Opens [portName] at [baudRate] and starts the receive pipeline.
  Future<void> connect(String portName, {int baudRate = 115200}) async {
    await _transport.connect(portName, baudRate: baudRate);
    _transportSub = _transport.dataStream.listen(
      _parser.addBytes,
      onError: (Object err) {
        // Propagate transport errors to all pending completers.
        for (final c in _pending.values) {
          if (!c.isCompleted) c.completeError(err);
        }
        _pending.clear();
      },
    );
  }

  /// Closes the serial port and releases resources.
  Future<void> disconnect() async {
    await _transportSub?.cancel();
    _transportSub = null;
    await _transport.disconnect();
    // Fail any still-pending requests.
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(const CanConnectionException('Disconnected'));
      }
    }
    _pending.clear();
  }

  /// Closes all stream controllers and disposes the parser.
  /// Call when the device object is no longer needed.
  void dispose() {
    disconnect();
    _parserSub?.cancel();
    _parser.dispose();
    _rxFramesCtrl.close();
    _txFramesCtrl.close();
    _protocolStatusCtrl.close();
    _canStatsNotifCtrl.close();
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  /// Retrieves the device identity and firmware version.
  ///
  /// Returns a [DeviceIdInfo] with the device ID byte (expected:
  /// [kDeviceId] = 0xAC) and the firmware major/minor/patch version.
  Future<DeviceIdInfo> getDeviceId() async {
    final resp = await _sendCommand(
      cmdGetDeviceId,
      buildGetDeviceIdRequest(),
    );
    return parseGetDeviceIdResponse(resp);
  }

  /// Starts the FDCAN peripheral on the device.
  ///
  /// [arbBitrate] selects the arbitration phase bitrate
  /// (default: [ArbBitrate.rate500k] — 500 kbit/s).
  ///
  /// [dataBitrate] selects the data phase bitrate
  /// (default: [DataBitrate.rate2000k] — 2000 kbit/s).
  ///
  /// Returns the HAL status byte (0 = HAL_OK).
  Future<int> canStart({
    ArbBitrate arbBitrate = ArbBitrate.rate500k,
    DataBitrate dataBitrate = DataBitrate.rate2000k,
  }) async {
    final resp = await _sendCommand(
      cmdCanStart,
      buildCanStartRequest(
        arbBitrate: arbBitrate,
        dataBitrate: dataBitrate,
      ),
    );
    return parseCanStartResponse(resp);
  }

  /// Stops the FDCAN peripheral on the device.
  ///
  /// Returns the HAL status byte (0 = HAL_OK).
  Future<int> canStop() async {
    final resp = await _sendCommand(cmdCanStop, buildCanStopRequest());
    return parseCanStopResponse(resp);
  }

  /// Triggers a device reset. The device resets immediately; no response
  /// is sent.
  Future<void> deviceReset() async {
    final frame = buildFrame(
      payload: buildDeviceResetRequest(),
      seqNum: _nextSeq(),
    );
    await _transport.write(frame);
  }

  /// Transmits [frame] to the CAN bus.
  ///
  /// Returns the status byte (0 = success).
  Future<int> sendFrame(CanFrame frame) async {
    final resp = await _sendCommand(
      cmdSendDownstream,
      buildSendDownstreamRequest(frame),
    );
    _txFramesCtrl.add(frame); // emit only after device ack
    return parseSendDownstreamResponse(resp);
  }

  /// Requests the current CAN error counters and loss statistics.
  Future<CanStats> getCanStats() async {
    final resp = await _sendCommand(cmdGetCanStats, buildGetCanStatsRequest());
    return parseGetCanStats(resp);
  }

  /// Resets all CAN error counters and loss statistics to zero.
  ///
  /// Returns the status byte (0 = success).
  Future<int> resetCanStats() async {
    final resp =
        await _sendCommand(cmdResetCanStats, buildResetCanStatsRequest());
    return parseResetCanStatsResponse(resp);
  }

  /// Triggers entry into the STM32 ROM USB DFU bootloader.
  ///
  /// The device writes a magic word to `.noinit` RAM and calls
  /// `NVIC_SystemReset()` immediately — **no response is sent**.
  /// After flashing, the device reboots into normal firmware.
  Future<void> enterDfu() async {
    final frame = buildFrame(
      payload: buildEnterDfuRequest(),
      seqNum: _nextSeq(),
    );
    await _transport.write(frame);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Sends [payload] as a frame, registers a pending completer for [cmdId],
  /// and waits for the matching response with a timeout.
  ///
  /// Uses [_lock] to serialise requests so only one is in-flight at a time.
  Future<Uint8List> _sendCommand(int cmdId, Uint8List payload) {
    return _lock.synchronized(() async {
      if (_pending.containsKey(cmdId)) {
        throw CanProtocolException(
          'Command 0x${cmdId.toRadixString(16)} already in-flight',
          statusCode: 0,
        );
      }

      final completer = Completer<Uint8List>();
      _pending[cmdId] = completer;

      final frame = buildFrame(payload: payload, seqNum: _nextSeq());
      await _transport.write(frame);

      try {
        return await completer.future.timeout(
          commandTimeout,
          onTimeout: () {
            _pending.remove(cmdId);
            throw CanTimeoutException(
              'No response for command '
              '0x${cmdId.toRadixString(16)} within $commandTimeout',
            );
          },
        );
      } finally {
        _pending.remove(cmdId);
      }
    });
  }

  /// Routes a validated [ParsedFrame] to either a pending completer
  /// (request/response) or a notification stream (unsolicited).
  void _routeFrame(ParsedFrame frame) {
    final int cmd = frame.commandId;

    // Unsolicited notifications — always routed to streams.
    if (cmd == cmdSendUpstream) {
      try {
        _rxFramesCtrl.add(parseSendUpstream(frame.payload));
      } catch (_) {/* malformed upstream frame — ignore */}
      return;
    }

    if (cmd == cmdProtocolStatus) {
      try {
        _protocolStatusCtrl.add(parseProtocolStatus(frame.payload));
      } catch (_) {}
      return;
    }

    // CMD_GET_CAN_STATS can arrive both as a response and as an unsolicited
    // notification. Route to notification stream if no pending request exists.
    if (cmd == cmdGetCanStats && !_pending.containsKey(cmd)) {
      try {
        _canStatsNotifCtrl.add(parseGetCanStats(frame.payload));
      } catch (_) {}
      return;
    }

    // Request/response commands — complete the pending completer.
    final completer = _pending.remove(cmd);
    if (completer != null && !completer.isCompleted) {
      completer.complete(frame.payload);
    }
  }

  int _nextSeq() {
    final seq = _seqNum;
    _seqNum = (_seqNum + 1) & 0xFFFF;
    return seq;
  }
}
