/// Example Flutter app demonstrating the can_usb package.
///
/// Shows how to:
///   * list available serial ports
///   * connect to a USB-CANFD adapter
///   * send a CAN Classic frame
///   * listen for received CAN frames
///   * query device identity and CAN statistics
///   * disconnect cleanly
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:can_usb/can_usb.dart';

void main() {
  runApp(const CanUsbExampleApp());
}

class CanUsbExampleApp extends StatelessWidget {
  const CanUsbExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'can_usb Example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const DevicePage(),
    );
  }
}

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final CanusbDevice _device = CanusbDevice();

  List<SerialPortInfo> _ports = [];
  String? _selectedPort;
  bool _connected = false;

  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    // Route received CAN frames and notifications to the log.
    _device.rxFrames.listen((CanFrame frame) {
      _addLog('RX  id=0x${frame.messageId.toRadixString(16).padLeft(3, '0')}  '
          'type=${frame.frameType}  data=${frame.data}');
    });

    _device.protocolStatus.listen((ProtocolStatus s) {
      _addLog('STATUS  busOff=${s.busOff}  errorPassive=${s.errorPassive}  '
          'warning=${s.warning}');
    });

    _device.canStatsNotifications.listen((CanStats s) {
      _addLog('STATS  txErr=${s.txErrorCount}  rxErr=${s.rxErrorCount}  '
          'upstreamLoss=${s.upstreamPacketLoss}');
    });
  }

  @override
  void dispose() {
    _device.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _addLog(String message) {
    setState(() => _log.insert(0, message));
  }

  Future<void> _refreshPorts() async {
    final ports = await _device.listAvailablePorts();
    setState(() {
      _ports = ports;
      if (_selectedPort == null && ports.isNotEmpty) {
        _selectedPort = ports.first.name;
      }
    });
    _addLog('Found ${ports.length} port(s)');
  }

  Future<void> _connect() async {
    if (_selectedPort == null) return;
    try {
      await _device.connect(_selectedPort!);
      setState(() => _connected = true);
      _addLog('Connected to $_selectedPort');

      // Query device identity right after connecting.
      final info = await _device.getDeviceId();
      _addLog('Device ID: 0x${info.deviceId.toRadixString(16).toUpperCase()}  '
          'FW: ${info.versionMajor}.${info.versionMinor}.${info.versionPatch}');

      await _device.canStart(
        arbBitrate: ArbBitrate.rate500k,
        dataBitrate: DataBitrate.rate2000k,
      );
      _addLog('CAN bus started');
    } on CanException catch (e) {
      _addLog('ERROR  $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      await _device.canStop();
      _addLog('CAN bus stopped');
    } on CanException catch (_) {}
    await _device.disconnect();
    setState(() => _connected = false);
    _addLog('Disconnected');
  }

  Future<void> _sendTestFrame() async {
    final frame = CanFrame(
      messageId: 0x123,
      frameType: const CanFrameType.classic(),
      dlc: 4,
      data: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
    );
    try {
      final status = await _device.sendFrame(frame);
      _addLog('TX  id=0x123  status=$status');
    } on CanException catch (e) {
      _addLog('TX ERROR  $e');
    }
  }

  Future<void> _queryStats() async {
    try {
      final stats = await _device.getCanStats();
      _addLog('STATS  txErr=${stats.txErrorCount}  '
          'rxErr=${stats.rxErrorCount}  upstreamLoss=${stats.upstreamPacketLoss}');
    } on CanException catch (e) {
      _addLog('STATS ERROR  $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('can_usb Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Port selector row
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedPort,
                    isExpanded: true,
                    hint: const Text('Select port'),
                    items: _ports
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.name,
                            child: Text('${p.name}  ${p.description ?? ''}'),
                          ),
                        )
                        .toList(),
                    onChanged: _connected
                        ? null
                        : (v) => setState(() => _selectedPort = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh ports',
                  icon: const Icon(Icons.refresh),
                  onPressed: _connected ? null : _refreshPorts,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Connect / Disconnect
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _connected || _selectedPort == null
                        ? null
                        : _connect,
                    child: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _connected ? _disconnect : null,
                    child: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // CAN actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _connected ? _sendTestFrame : null,
                    child: const Text('Send 0x123'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _connected ? _queryStats : null,
                    child: const Text('Get Stats'),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Log view
            Expanded(
              child: ListView.builder(
                reverse: false,
                itemCount: _log.length,
                itemBuilder: (_, i) => Text(
                  _log[i],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
