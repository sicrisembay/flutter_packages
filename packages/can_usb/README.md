# can_usb

A Flutter package for communicating with a USB-CANFD adapter over a serial
(UART / USB-CDC) connection.

`can_usb` provides a serial transport layer, a binary frame builder/parser, and
a high-level `CanusbDevice` API for sending and receiving CAN / CAN-FD frames.

## Features

- **Connect / disconnect** to any serial port exposed by the adapter
- **Send CAN frames** (CAN Classic and CAN-FD, standard and extended IDs)
- **Receive CAN frames** via a reactive broadcast stream (`rxFrames`)
- **Device identity** — query firmware version and device ID
- **CAN bus control** — start / stop the FDCAN peripheral
- **Statistics** — read and reset CAN error/loss counters (`CanStats`)
- **Protocol status** stream — monitor FDCAN bus state and error counters
- **DFU entry** — trigger STM32 ROM USB bootloader for firmware updates
- **Testable** — injectable `ISerialTransport` interface for easy mocking
- **Supported platforms**: Windows, Linux, macOS (via `flutter_libserialport`)
  and Android (via `usb_serial` / Android USB Host API)

## Getting started

### Prerequisites

- Flutter ≥ 3.22.0 / Dart ≥ 3.5.0
- A USB-CANFD adapter that implements the binary frame protocol described in
  [FRAME_SPECIFICATION.md](https://github.com/sicrisembay/webserial_canfd/blob/main/firmware/FRAME_SPECIFICATION.md)
- On Linux you may need to add your user to the `dialout` group:
  ```bash
  sudo usermod -aG dialout $USER
  ```

### Installation

Add `can_usb` to your `pubspec.yaml`:

```yaml
dependencies:
  can_usb: ^0.1.2
```

Then run:

```bash
flutter pub get
```

## Usage

### List available ports and connect

```dart
import 'package:can_usb/can_usb.dart';

final device = CanusbDevice();

// List ports
final ports = await device.listAvailablePorts();
for (final p in ports) {
  print('${p.name}  ${p.description}');
}

// Connect to the first available port
await device.connect(ports.first.name);
```

### Send and receive CAN frames

```dart
// Listen for incoming frames from the bus
device.rxFrames.listen((CanFrame frame) {
  print('RX id=0x${frame.id.toRadixString(16)}  '
        'data=${frame.data}');
});

// Send a Classic CAN frame
final frame = CanFrame(
  id: 0x123,
  frameType: const CanFrameType.classic(),
  data: Uint8List.fromList([0x01, 0x02, 0x03, 0x04]),
);
await device.sendFrame(frame);
```

### CAN-FD frame with Bit Rate Switch

```dart
final fdFrame = CanFrame(
  id: 0x456,
  frameType: const CanFrameType.fd(),   // BRS ON, Standard ID
  data: Uint8List.fromList(List.generate(64, (i) => i)),
);
await device.sendFrame(fdFrame);
```

### Device identity and bus control

```dart
final info = await device.getDeviceId();
print('Device ID: 0x${info.deviceId.toRadixString(16)}');
print('Firmware:  ${info.versionMajor}.${info.versionMinor}.${info.versionPatch}');

// Start FDCAN peripheral with explicit bitrates
await device.canStart(
  arbBitrate: ArbBitrate.rate500k,   // 500 kbit/s arbitration phase
  dataBitrate: DataBitrate.rate2000k, // 2000 kbit/s data phase
);
// ... communicate ...
await device.canStop();    // Stop FDCAN peripheral
```

> **Note:** `canStart()` defaults to `ArbBitrate.rate1000k` / `DataBitrate.rate2000k` when
> no bitrate arguments are supplied.

### Protocol status and statistics

```dart
// Unsolicited FDCAN bus state notifications
device.protocolStatus.listen((ProtocolStatus s) {
  print('Bus state: ${s.busState}');
});

// Unsolicited CAN stats notifications
device.canStatsNotifications.listen((CanStats s) {
  print('TX errors: ${s.txErrorCount}');
});

// On-demand stats query
final stats = await device.getCanStats();
await device.resetCanStats();
```

### Disconnect and dispose

```dart
await device.disconnect();
device.dispose();   // call when the object is no longer needed
```

### Dependency injection / testing

Provide a custom `ISerialTransport` implementation to unit-test your code
without real hardware:

```dart
final mockTransport = MyMockTransport();
final device = CanusbDevice(transport: mockTransport);
```

## API overview

| Symbol | Description |
|--------|-------------|
| `CanusbDevice` | High-level device façade — the main entry point |
| `CanusbDevice.rxFrames` | Broadcast stream of CAN/CAN-FD frames received from the bus |
| `CanusbDevice.txFrames` | Broadcast stream of CAN/CAN-FD frames successfully sent to the bus |
| `ISerialTransport` | Abstract transport interface (injectable / mockable) |
| `SerialPortTransport` | Default transport backed by `flutter_libserialport` |
| `SerialPortInfo` | Describes an available serial port (`name`, `description`) |
| `CanFrame` | CAN / CAN-FD frame model |
| `CanFrameType` | TX/RX type byte encoder/decoder (FD, BRS, extended ID) |
| `CanStats` | Error counters and frame loss statistics |
| `DeviceIdInfo` | Device ID byte and firmware version |
| `ProtocolStatus` | FDCAN bus state and error passive/warning flags |
| `ArbBitrate` | Arbitration phase bitrate enum (`rate10k` … `rate1000k`) |
| `DataBitrate` | Data phase bitrate enum (`rate100k` … `rate5000k`) |
| `CanException` | Base exception class |
| `CanConnectionException` | Thrown on serial port open/close failure |
| `CanTimeoutException` | Thrown when a command receives no response in time |
| `CanChecksumException` | Thrown on invalid frame checksum |
| `CanProtocolException` | Thrown when the device returns a non-zero HAL status |

## Additional information

- **Frame protocol specification**: see
  [FRAME_SPECIFICATION.md](https://github.com/sicrisembay/webserial_canfd/blob/main/firmware/FRAME_SPECIFICATION.md)
- **Issues and feature requests**:
  [GitHub Issues](https://github.com/sicrisembay/flutter_packages/issues)
- **Source code**:
  [github.com/sicrisembay/flutter_packages](https://github.com/sicrisembay/flutter_packages/tree/main/packages/can_usb)
- **License**: MIT
