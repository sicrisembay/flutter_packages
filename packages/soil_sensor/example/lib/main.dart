import 'package:flutter/material.dart';
import 'package:soil_sensor/soil_sensor.dart';

void main() {
  runApp(const SoilSensorExampleApp());
}

class SoilSensorExampleApp extends StatelessWidget {
  const SoilSensorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soil Sensor Example',
      theme: ThemeData(colorSchemeSeed: Colors.green),
      home: const SensorPage(),
    );
  }
}

class SensorPage extends StatefulWidget {
  const SensorPage({super.key});

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  final SoilSensorService _service = SoilSensorService(
    baudRate: 9600,
    slaveAddress: 1,
  );

  List<String> _devices = [];
  String? _connectedDevice;
  SensorReading? _reading;
  String? _error;
  bool _busy = false;

  Future<void> _scanDevices() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final devices = await _service.listDevices();
      setState(() => _devices = devices);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _connect(String deviceId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.connect(deviceId);
      setState(() => _connectedDevice = deviceId);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _read() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reading = await _service.readSensor();
      setState(() => _reading = reading);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    await _service.disconnect();
    setState(() {
      _connectedDevice = null;
      _reading = null;
    });
  }

  @override
  void dispose() {
    _service.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soil Sensor Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Device list ──────────────────────────────────────────────────
            ElevatedButton(
              onPressed: _busy ? null : _scanDevices,
              child: const Text('Scan for devices'),
            ),
            if (_devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No devices found. Press Scan to search.'),
              )
            else
              ...(_devices.map(
                (d) => ListTile(
                  title: Text(d),
                  trailing: _connectedDevice == d
                      ? const Chip(label: Text('Connected'))
                      : TextButton(
                          onPressed: _busy ? null : () => _connect(d),
                          child: const Text('Connect'),
                        ),
                ),
              )),

            const Divider(),

            // ── Controls ─────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _busy || !_service.isConnected ? null : _read,
                    child: const Text('Read sensor'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _busy || !_service.isConnected ? null : _disconnect,
                    child: const Text('Disconnect'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Reading display ───────────────────────────────────────────────
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            if (_reading != null) ...[
              _ReadingRow('Moisture', '${_reading!.moisture} %'),
              _ReadingRow('Temperature', '${_reading!.temperature} °C'),
              _ReadingRow('Conductivity', '${_reading!.conductivity} µS/cm'),
              _ReadingRow('pH', '${_reading!.ph}'),
              if (_reading!.hasNpk) ...[
                _ReadingRow('Nitrogen', '${_reading!.nitrogen} mg/kg'),
                _ReadingRow('Phosphorus', '${_reading!.phosphorus} mg/kg'),
                _ReadingRow('Potassium', '${_reading!.potassium} mg/kg'),
              ],
              Text(
                'Read at: ${_reading!.readAt}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
