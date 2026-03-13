# soil_sensor

A Flutter package for reading Modbus RTU soil sensors (NPK, moisture, temperature, pH,
and conductivity) over USB serial on **Android** and **Windows**.

## Features

- Enumerate connected USB serial devices on Android and Windows
- Connect and disconnect with configurable baud rate and Modbus slave address
- Read soil parameters via **Modbus RTU FC03**:
  - Basic sensors (3 registers): moisture (%), temperature (°C), conductivity (µS/cm)
  - Extended sensors (7 registers): + pH, nitrogen (mg/kg), phosphorus (mg/kg), potassium (mg/kg)
- Automatic fallback from extended to basic read when the sensor doesn't support NPK registers
- Configurable retry logic for noisy serial connections
- Typed `SensorReading` model with `hasNpk` and `isRecent` convenience getters

## Supported platforms

| Platform | Transport |
|----------|-----------|
| Android  | [`usb_serial`](https://pub.dev/packages/usb_serial) |
| Windows  | [`flutter_libserialport`](https://pub.dev/packages/flutter_libserialport) |

## Getting started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  soil_sensor: ^0.1.0
```

### Android permissions

Add USB host permission to `AndroidManifest.xml`:

```xml
<uses-feature android:name="android.hardware.usb.host" />
```

### Windows

No additional setup required — `flutter_libserialport` uses the native Windows serial API.

## Usage

```dart
import 'package:soil_sensor/soil_sensor.dart';

final service = SoilSensorService(baudRate: 9600, slaveAddress: 1);

// 1. List available devices
final devices = await service.listDevices();
print(devices); // e.g. ['COM3', 'COM4'] on Windows

// 2. Connect
await service.connect(devices.first);

// 3. Read sensor data
final reading = await service.readSensor();
print('Moisture:     ${reading.moisture} %');
print('Temperature:  ${reading.temperature} °C');
print('Conductivity: ${reading.conductivity} µS/cm');
print('pH:           ${reading.ph}');
if (reading.hasNpk) {
  print('Nitrogen:   ${reading.nitrogen} mg/kg');
  print('Phosphorus: ${reading.phosphorus} mg/kg');
  print('Potassium:  ${reading.potassium} mg/kg');
}

// 4. Disconnect when done
await service.disconnect();
```

## API overview

### `SoilSensorService`

The main entry point.

| Member | Description |
|--------|-------------|
| `SoilSensorService({baudRate, slaveAddress})` | Constructor. Defaults: `baudRate = 9600`, `slaveAddress = 1`. |
| `listDevices()` | Returns a list of connectable device identifiers. |
| `connect(deviceId)` | Opens the serial port and configures it. |
| `disconnect()` | Closes and releases the serial port. |
| `isConnected` | `true` if a port is currently open. |
| `readSensor({maxRetries})` | Reads all available sensor registers and returns a `SensorReading`. |

### `SensorReading`

Immutable value object returned by `readSensor()`.

| Field | Type | Description |
|-------|------|-------------|
| `moisture` | `double` | Volumetric water content (%) |
| `temperature` | `double` | Soil temperature (°C) |
| `conductivity` | `double` | Electrical conductivity (µS/cm) |
| `ph` | `double` | Soil pH |
| `nitrogen` | `double` | Available nitrogen (mg/kg) |
| `phosphorus` | `double` | Available phosphorus (mg/kg) |
| `potassium` | `double` | Available potassium (mg/kg) |
| `readAt` | `DateTime` | Timestamp of the reading |
| `hasNpk` | `bool` | `true` when at least one of N/P/K is non-zero |
| `isRecent` | `bool` | `true` when the reading is less than 10 minutes old |

### `ModbusRtuService`

Low-level Modbus RTU framing primitives (advanced use). All methods are static.

| Method | Description |
|--------|-------------|
| `buildReadRequest(...)` | Builds an FC03 read holding registers request frame. |
| `parseReadResponse(...)` | Parses and CRC-validates an FC03 response, returns raw register values. |
| `scaleExtendedRegisters(raw)` | Converts 7 raw register values to physical quantities. |
| `scaleBasicRegisters(raw)` | Converts 3 raw register values to physical quantities. |
| `calculateCrc16(data, length)` | CRC-16/ANSI (Modbus) calculator. |

## Protocol details

The sensor communicates over **Modbus RTU** (FC03 Read Holding Registers) via a
**USB-to-RS485 adapter** that enumerates as a CDC USB serial device.

### Hardware setup

```
┌──────────────┐     USB      ┌─────────────────┐   RS485   ┌──────────────┐
│  Android /   │─────────────>│  USB-to-RS485   │──────────>│ Soil Sensor  │
│   Windows    │              │    Adapter      │  (A / B)  │              │
└──────────────┘              └─────────────────┘           └──────────────┘
```

### Serial port settings

| Parameter    | Value          |
|-------------|----------------|
| Baud rate   | 9600 (default) |
| Data bits   | 8              |
| Stop bits   | 1              |
| Parity      | None           |
| Flow control| None           |
| Default slave address | 1  |

### Register map

#### Basic sensors (3 registers — starting at 0x0000)

| Address | Parameter    | Type   | Scale | Unit   | Range           |
|---------|-------------|--------|-------|--------|-----------------|
| 0x0000  | Moisture     | UINT16 | ×0.1  | %      | 0.0 – 100.0     |
| 0x0001  | Temperature  | INT16  | ×0.1  | °C     | −40.0 – 80.0    |
| 0x0002  | Conductivity | UINT16 | ×1    | µS/cm  | 0 – 65535       |

#### Extended sensors (7 registers — starting at 0x0000)

| Address | Parameter    | Type   | Scale | Unit   | Range           |
|---------|-------------|--------|-------|--------|-----------------|
| 0x0000  | Moisture     | UINT16 | ×0.1  | %      | 0.0 – 100.0     |
| 0x0001  | Temperature  | INT16  | ×0.1  | °C     | −40.0 – 80.0    |
| 0x0002  | Conductivity | UINT16 | ×1    | µS/cm  | 0 – 65535       |
| 0x0003  | pH           | UINT16 | ×0.1  | pH     | 0.0 – 14.0      |
| 0x0004  | Nitrogen     | UINT16 | ×1    | mg/kg  | 0 – 65535       |
| 0x0005  | Phosphorus   | UINT16 | ×1    | mg/kg  | 0 – 65535       |
| 0x0006  | Potassium    | UINT16 | ×1    | mg/kg  | 0 – 65535       |

> `SoilSensorService.readSensor()` automatically attempts the 7-register read first and
> falls back to 3 registers when the sensor returns exception code 0x02 (Illegal Data Address).

For full protocol details — frame format, CRC algorithm, timing requirements, error codes,
and troubleshooting — see
[doc/MODBUS_RTU_PROTOCOL.md](https://github.com/sicrisembay/flutter_packages/blob/main/packages/soil_sensor/doc/MODBUS_RTU_PROTOCOL.md).

---

## Additional information

- **Issues & feature requests:** [GitHub Issues](https://github.com/sicrisembay/flutter_packages/issues)
- **Source code:** [github.com/sicrisembay/flutter_packages](https://github.com/sicrisembay/flutter_packages)
- **Contributions:** Pull requests are welcome. Please open an issue first to discuss significant changes.

