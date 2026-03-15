# Modbus RTU Protocol Documentation - Soil Sensor

## Table of Contents
1. [Overview](#overview)
2. [Physical Connection](#physical-connection)
3. [Communication Parameters](#communication-parameters)
4. [Protocol Structure](#protocol-structure)
5. [CRC-16 Checksum](#crc-16-checksum)
6. [Function Codes](#function-codes)
7. [Register Map](#register-map)
8. [Data Format and Scaling](#data-format-and-scaling)
9. [Request/Response Examples](#requestresponse-examples)
10. [Error Handling](#error-handling)
11. [Timing Requirements](#timing-requirements)
12. [Troubleshooting](#troubleshooting)

---

## Overview

The soil sensor implements the **Modbus RTU** (Remote Terminal Unit) protocol over an RS485 physical layer. The device communicates via a USB-to-RS485 adapter that enumerates as a CDC (Communication Device Class) USB device on the host system.

### Key Characteristics:
- **Protocol**: Modbus RTU
- **Physical Layer**: RS485 (differential signaling)
- **USB Interface**: CDC USB Serial
- **Transport**: Half-duplex serial communication
- **Byte Order**: Big-endian (MSB first)
- **Addressing**: Supports slave addresses 1-247
- **Default Slave Address**: 1

---

## Physical Connection

### Hardware Setup

```
┌──────────────┐      USB       ┌─────────────────┐    RS485    ┌──────────────┐
│   Android    │--------------->│  USB-to-RS485   │------------>│ Soil Sensor  │
│   Device     │                │    Adapter      │   (A/B)     │              │
└──────────────┘                └─────────────────┘             └──────────────┘
```

### RS485 Wiring
- **A (Non-Inverting)**: Positive differential signal
- **B (Inverting)**: Negative differential signal
- **GND (Optional)**: Common ground reference

### USB Connection
- The USB-to-RS485 adapter enumerates as a **CDC USB device**
- No special drivers required on most Android devices
- The device appears as `/dev/ttyUSB*` or similar in the Android USB subsystem
- Requires USB Host Mode (OTG) support

---

## Communication Parameters

### Serial Port Settings

| Parameter    | Value      | Notes                                    |
|-------------|------------|------------------------------------------|
| Baud Rate   | 4800/9600  | Common: 9600 bps (configurable)         |
| Data Bits   | 8          | Fixed                                    |
| Stop Bits   | 1          | Fixed                                    |
| Parity      | None       | No parity checking                       |
| Flow Control| None       | RTS/CTS not used for data flow          |

**Note**: The implementation sets DTR (Data Terminal Ready) and RTS (Request To Send) to `true` during initialization, but these are control signals for the USB adapter, not actual flow control.

### Default Connection Code
```dart
await port.setPortParameters(
  9600,     // baudRate
  8,        // dataBits
  1,        // stopBits
  0,        // parity: 0 = None, 1 = Odd, 2 = Even
);
```

---

## Protocol Structure

### Modbus RTU Frame Format

Every Modbus RTU message follows this structure:

```
┌──────────┬──────────┬─────────┬───────┬──────┬──────┐
│  Slave   │ Function │  Data   │  ...  │ CRC  │ CRC  │
│ Address  │   Code   │         │       │  Lo  │  Hi  │
├──────────┼──────────┼─────────┼───────┼──────┼──────┤
│  1 byte  │  1 byte  │ N bytes │       │1 byte│1 byte│
└──────────┴──────────┴─────────┴───────┴──────┴──────┘
```

### Field Descriptions

1. **Slave Address (1 byte)**
   - Valid range: 1-247
   - Address 0 is reserved for broadcast
   - Default: 1

2. **Function Code (1 byte)**
   - Specifies the operation to perform
   - High bit (0x80) set indicates error response

3. **Data (Variable length)**
   - Request/response specific data
   - Length depends on function code and operation

4. **CRC-16 (2 bytes)**
   - 16-bit cyclic redundancy check
   - Error detection mechanism
   - Transmitted low byte first, then high byte

---

## CRC-16 Checksum

### Algorithm

Modbus RTU uses the **CRC-16-ANSI** algorithm (also known as CRC-16-IBM) with the following parameters:

- **Polynomial**: 0xA001 (reversed 0x8005)
- **Initial Value**: 0xFFFF
- **Input Reflected**: Yes
- **Output Reflected**: Yes
- **Final XOR**: None (0x0000)

### Calculation Steps

```dart
int calculateCRC16(Uint8List data, int length) {
  int crc = 0xFFFF;  // Initialize to all 1s

  for (int i = 0; i < length; i++) {
    crc ^= data[i];  // XOR byte into CRC

    for (int j = 0; j < 8; j++) {
      if ((crc & 0x0001) != 0) {
        crc >>= 1;           // Shift right
        crc ^= 0xA001;       // XOR with polynomial
      } else {
        crc >>= 1;           // Just shift
      }
    }
  }

  return crc;
}
```

### Transmission Order
- **CRC Low Byte** is transmitted first
- **CRC High Byte** is transmitted second

**Example**: If CRC = 0x1234, transmit as `[0x34, 0x12]`

---

## Function Codes

### Supported Function Codes

| Code | Name                      | Description                           |
|------|---------------------------|---------------------------------------|
| 0x03 | Read Holding Registers    | Read multiple 16-bit registers        |

The soil sensor implements **Function Code 0x03** (Read Holding Registers) to retrieve sensor measurements.

### Function Code 0x03: Read Holding Registers

#### Request Format

```
┌──────────┬──────────┬────────────┬────────────┬───────────┬───────────┬──────┬──────┐
│  Slave   │   0x03   │  Start     │  Start     │  Count    │  Count    │ CRC  │ CRC  │
│ Address  │          │  Addr Hi   │  Addr Lo   │    Hi     │    Lo     │  Lo  │  Hi  │
├──────────┼──────────┼────────────┼────────────┼───────────┼───────────┼──────┼──────┤
│  1 byte  │  1 byte  │   1 byte   │   1 byte   │  1 byte   │  1 byte   │1 byte│1 byte│
└──────────┴──────────┴────────────┴────────────┴───────────┴───────────┴──────┴──────┘
   Total: 8 bytes
```

**Fields:**
- **Start Address**: 16-bit starting register address (big-endian)
- **Register Count**: 16-bit number of registers to read (big-endian)

#### Response Format

```
┌──────────┬──────────┬───────────┬────────┬────────┬───────┬──────┬──────┐
│  Slave   │   0x03   │   Byte    │ Data   │ Data   │  ...  │ CRC  │ CRC  │
│ Address  │          │   Count   │   0    │   1    │       │  Lo  │  Hi  │
├──────────┼──────────┼───────────┼────────┼────────┼───────┼──────┼──────┤
│  1 byte  │  1 byte  │   1 byte  │ 1 byte │ 1 byte │       │1 byte│1 byte│
└──────────┴──────────┴───────────┴────────┴────────┴───────┴──────┴──────┘
   Total: 5 + (Register Count × 2) bytes
```

**Fields:**
- **Byte Count**: Number of data bytes following (= Register Count × 2)
- **Data**: Register values, 2 bytes per register (big-endian)

#### Error Response Format

```
┌──────────┬──────────┬───────────┬──────┬──────┐
│  Slave   │   0x83   │   Error   │ CRC  │ CRC  │
│ Address  │ (0x03|80)│   Code    │  Lo  │  Hi  │
├──────────┼──────────┼───────────┼──────┼──────┤
│  1 byte  │  1 byte  │   1 byte  │1 byte│1 byte│
└──────────┴──────────┴───────────┴──────┴──────┘
   Total: 5 bytes
```

**Error Codes:**
- **0x01**: Illegal Function
- **0x02**: Illegal Data Address
- **0x03**: Illegal Data Value
- **0x04**: Slave Device Failure

---

## Register Map

The soil sensor exposes sensor data through holding registers starting at address 0x0000.

### Basic Register Map (3 Registers)

| Address | Register | Parameter      | Data Type | Scale  | Unit     | Range          |
|---------|----------|----------------|-----------|--------|----------|----------------|
| 0x0000  | 0        | Moisture       | UINT16    | ×0.1   | %        | 0.0 - 100.0%   |
| 0x0001  | 1        | Temperature    | INT16     | ×0.1   | °C       | -40.0 - 80.0°C |
| 0x0002  | 2        | Conductivity   | UINT16    | ×1     | μS/cm    | 0 - 65535      |

### Extended Register Map (7 Registers)

| Address | Register | Parameter      | Data Type | Scale  | Unit     | Range          |
|---------|----------|----------------|-----------|--------|----------|----------------|
| 0x0000  | 0        | Moisture       | UINT16    | ×0.1   | %        | 0.0 - 100.0%   |
| 0x0001  | 1        | Temperature    | INT16     | ×0.1   | °C       | -40.0 - 80.0°C |
| 0x0002  | 2        | Conductivity   | UINT16    | ×1     | μS/cm    | 0 - 65535      |
| 0x0003  | 3        | pH Value       | UINT16    | ×0.1   | pH       | 0.0 - 14.0     |
| 0x0004  | 4        | Nitrogen (N)   | UINT16    | ×1     | mg/kg    | 0 - 65535      |
| 0x0005  | 5        | Phosphorus (P) | UINT16    | ×1     | mg/kg    | 0 - 65535      |
| 0x0006  | 6        | Potassium (K)  | UINT16    | ×1     | mg/kg    | 0 - 65535      |

**Note**: Not all sensors support the extended register set. Basic sensors typically only implement registers 0-2.

---

## Data Format and Scaling

### Data Types

#### UINT16 (Unsigned 16-bit Integer)
- **Range**: 0 to 65535
- **Byte Order**: Big-endian (MSB first)
- **Conversion**: `value = (highByte << 8) | lowByte`

#### INT16 (Signed 16-bit Integer)
- **Range**: -32768 to 32767
- **Byte Order**: Big-endian (MSB first)
- **Conversion**: 
  ```dart
  int value = (highByte << 8) | lowByte;
  if (value & 0x8000 != 0) {
    value = value - 0x10000;  // Two's complement
  }
  ```

### Scaling Factors

Many values are transmitted with a decimal scale factor to preserve precision:

| Parameter      | Raw Type | Scale | Formula            | Example                  |
|----------------|----------|-------|--------------------|--------------------------|
| Moisture       | UINT16   | 0.1   | `raw / 10.0`       | 235 → 23.5%             |
| Temperature    | INT16    | 0.1   | `raw / 10.0`       | 215 → 21.5°C            |
| Conductivity   | UINT16   | 1     | `raw`              | 1450 → 1450 μS/cm       |
| pH             | UINT16   | 0.1   | `raw / 10.0`       | 68 → 6.8 pH             |
| Nitrogen       | UINT16   | 1     | `raw`              | 120 → 120 mg/kg (ppm)   |
| Phosphorus     | UINT16   | 1     | `raw`              | 45 → 45 mg/kg (ppm)     |
| Potassium      | UINT16   | 1     | `raw`              | 180 → 180 mg/kg (ppm)   |

### Code Example

```dart
// Reading moisture (Register 0)
final data = await ModbusRTU.readHoldingRegisters(port, slaveAddress, 0x0000, 1);
final rawValue = ModbusRTU.bytesToUInt16(data[0], data[1]);
final moisture = rawValue / 10.0;  // Convert to percentage

// Reading temperature (Register 1) - signed value
final data = await ModbusRTU.readHoldingRegisters(port, slaveAddress, 0x0001, 1);
final rawValue = ModbusRTU.bytesToInt16(data[0], data[1]);
final temperature = rawValue / 10.0;  // Convert to °C
```

---

## Request/Response Examples

### Example 1: Read Moisture, Temperature, and Conductivity

**Request** (Read 3 registers starting at 0x0000):
```
Slave Address:     0x01
Function Code:     0x03
Start Address Hi:  0x00
Start Address Lo:  0x00
Register Count Hi: 0x00
Register Count Lo: 0x03
CRC Lo:            0x05
CRC Hi:            0xCB

Hex: 01 03 00 00 00 03 05 CB
```

**Expected Response** (11 bytes):
```
Slave Address:     0x01
Function Code:     0x03
Byte Count:        0x06  (3 registers × 2 bytes)
Moisture Hi:       0x00
Moisture Lo:       0xEB  (235 → 23.5%)
Temperature Hi:    0x00
Temperature Lo:    0xD7  (215 → 21.5°C)
Conductivity Hi:   0x05
Conductivity Lo:   0xAA  (1450 μS/cm)
CRC Lo:            0xXX
CRC Hi:            0xXX

Hex: 01 03 06 00 EB 00 D7 05 AA [CRC] [CRC]
```

### Example 2: Read Only Moisture

**Request** (Read 1 register at 0x0000):
```
Hex: 01 03 00 00 00 01 84 0A
```

**Expected Response** (7 bytes):
```
Slave Address:     0x01
Function Code:     0x03
Byte Count:        0x02
Moisture Hi:       0x01
Moisture Lo:       0x2C  (300 → 30.0%)
CRC Lo:            0xXX
CRC Hi:            0xXX

Hex: 01 03 02 01 2C [CRC] [CRC]
```

### Example 3: Read Extended Data (7 Registers)

**Request** (Read 7 registers starting at 0x0000):
```
Hex: 01 03 00 00 00 07 04 08
```

**Expected Response** (19 bytes):
```
Slave Address:     0x01
Function Code:     0x03
Byte Count:        0x0E  (7 registers × 2 bytes = 14)
[14 bytes of data]
CRC Lo:            0xXX
CRC Hi:            0xXX

Total: 19 bytes
```

### Example 4: Error Response (Invalid Register)

**Request** (Read from invalid address):
```
Hex: 01 03 00 64 00 01 C4 3E  (Register 100 which doesn't exist)
```

**Error Response**:
```
Slave Address:     0x01
Function Code:     0x83  (0x03 | 0x80 = error)
Exception Code:    0x02  (Illegal Data Address)
CRC Lo:            0xC0
CRC Hi:            0xF1

Hex: 01 83 02 C0 F1
```

---

## Error Handling

### Types of Errors

#### 1. Communication Errors
- **Timeout**: No response received within timeout period (default: 1000ms)
- **CRC Mismatch**: Received data fails CRC validation
- **Incomplete Response**: Fewer bytes received than expected

#### 2. Protocol Errors (Exception Responses)
- **0x01 - Illegal Function**: Function code not supported
- **0x02 - Illegal Data Address**: Register address out of range
- **0x03 - Illegal Data Value**: Invalid parameter value
- **0x04 - Slave Device Failure**: Sensor internal error

#### 3. USB Connection Errors
- **Permission Denied**: USB access not granted
- **Device Disconnected**: USB connection lost during operation
- **Write Failure**: Unable to send data to USB port

### Error Detection

```dart
// CRC validation
final receivedCrc = (response[response.length - 1] << 8) | 
                    response[response.length - 2];
final calculatedCrc = calculateCRC16(response, response.length - 2);

if (receivedCrc != calculatedCrc) {
  throw SensorException('CRC check failed');
}

// Check for exception response
if ((response[1] & 0x80) != 0) {
  final errorCode = response[2];
  throw SensorException('Modbus exception: $errorCode');
}
```

### Retry Strategy

Recommended retry behavior:
1. **First attempt**: Wait for timeout (1000ms)
2. **On timeout or CRC error**: Retry up to 3 times
3. **Delay between retries**: 100-200ms
4. **On persistent failure**: Notify user and suggest troubleshooting

---

## Timing Requirements

### Request Timing

| Event                    | Time Required           | Notes                          |
|--------------------------|-------------------------|--------------------------------|
| Inter-character gap      | < 1.5 character times   | Within a message              |
| Inter-frame gap          | ≥ 3.5 character times   | Between messages              |
| Response timeout         | 1000ms (configurable)   | Wait for sensor response      |
| Port stabilization       | 200ms                   | After opening USB connection  |

### Character Time Calculation

**Character Time** = (1 start bit + 8 data bits + 1 stop bit) / baud rate

At **9600 baud**:
- Character time ≈ 1.04 ms
- 1.5 character times ≈ 1.56 ms
- 3.5 character times ≈ 3.65 ms

At **4800 baud**:
- Character time ≈ 2.08 ms
- 1.5 character times ≈ 3.12 ms
- 3.5 character times ≈ 7.29 ms

### Response Length Calculation

Expected response length for Function Code 0x03:
```
Length = 5 + (RegisterCount × 2) bytes

Where:
- 5 bytes = Slave Address + Function Code + Byte Count + CRC (2 bytes)
- RegisterCount × 2 = Data bytes (2 bytes per register)
```

Examples:
- 1 register: 5 + (1 × 2) = 7 bytes
- 3 registers: 5 + (3 × 2) = 11 bytes
- 7 registers: 5 + (7 × 2) = 19 bytes

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Timeout Waiting for Response

**Symptoms**: Request sent but no response received

**Possible Causes**:
- Wrong baud rate (try 4800 or 9600)
- Incorrect slave address
- Sensor not powered or defective
- RS485 wiring issues (A/B reversed or disconnected)
- USB adapter driver issues

**Solutions**:
1. Verify baud rate matches sensor configuration
2. Try different slave addresses (usually 1)
3. Check sensor power supply (typically 12V DC)
4. Verify RS485 A/B connections are correct and secure
5. Test USB adapter with known working device

#### 2. CRC Check Failed

**Symptoms**: Data received but CRC validation fails

**Possible Causes**:
- Electrical interference on RS485 line
- Wrong baud rate causing bit errors
- Poor cable quality or loose connections
- Incorrect CRC calculation in firmware

**Solutions**:
1. Use shielded twisted-pair cable for RS485
2. Reduce cable length if possible
3. Double-check baud rate setting
4. Add termination resistors on long RS485 runs (120Ω)
5. Verify USB adapter is functioning correctly

#### 3. Incomplete Response

**Symptoms**: Some bytes received but less than expected

**Possible Causes**:
- Intermittent USB connection
- Buffer overflow in USB adapter
- Sensor timeout mid-transmission
- Wrong register count requested

**Solutions**:
1. Reduce number of registers read in single request
2. Replace USB cable if damaged
3. Restart USB adapter and sensor
4. Check if sensor supports requested register count

#### 4. Exception Response (0x83)

**Symptoms**: Sensor returns error code

**Possible Causes**:
- **0x02**: Requested register address doesn't exist
- **0x03**: Invalid register count
- **0x04**: Sensor malfunction

**Solutions**:
1. Use register scan function to discover available registers
2. Reduce register count (some sensors only have 3 registers)
3. Start with basic 3-register read before extended read
4. Reset or replace sensor if persistent 0x04 errors

#### 5. USB Permission Denied

**Symptoms**: Cannot open USB port

**Possible Causes**:
- Android app doesn't have USB permission
- USB device not supported by Android

**Solutions**:
1. Grant USB permissions when prompted
2. Enable USB debugging in Android developer options
3. Check AndroidManifest.xml for USB permission declarations
4. Try different USB OTG adapter

### Diagnostic Tools

#### Register Scanner
```dart
final result = await sensor.scanRegisters(
  startAddress: 0x0000,
  registerCount: 10,
);
print(result);
```

This will attempt to read registers and display their raw values, helping identify:
- Which registers are available
- Data format and scaling
- Communication issues

#### Communication Diagnostics
```dart
final result = await sensor.runDiagnostics();
print(result);
```

This tests reading different register counts to verify:
- USB connection stability
- Request/response reliability
- Maximum supported register read

### Debug Logging

The implementation includes detailed error messages with troubleshooting hints:

```dart
throw TimeoutException(
  'Timeout waiting for response from sensor.\n\n'
  'Received: ${responseList.length} bytes\n'
  'Expected: $expectedLength bytes\n\n'
  'Possible causes:\n'
  '• Wrong baud rate (try 4800 or 9600)\n'
  '• Wrong slave address (currently: $slaveAddress)\n'
  '• Sensor not powered or not responding\n'
  '• RS485 wiring issues (check A/B connections)\n'
  '• Incorrect USB adapter driver',
);
```

---

## Best Practices

### 1. Connection Handling
- Always call `connect()` before attempting communication
- Implement proper error handling for USB permission requests
- Allow 200ms stabilization time after opening port
- Set DTR and RTS control signals to ensure USB adapter is ready

### 2. Request Optimization
- Start with basic 3-register read before attempting extended reads
- Use single-register reads for specific parameters when possible
- Avoid excessive polling (recommend 1-second intervals minimum)
- Implement exponential backoff on repeated failures

### 3. Error Recovery
- Implement automatic retry on timeout (2-3 attempts)
- Log communication errors for debugging
- Provide clear user feedback on failure reasons
- Support manual reconnection after communication loss

### 4. Data Validation
- Always validate CRC before parsing response data
- Check response length matches expected value
- Verify sensor values are within reasonable ranges
- Handle negative temperatures correctly (INT16 conversion)

### 5. Performance Considerations
- Batch register reads when possible (read 3 or 7 registers at once)
- Cache sensor configuration (slave address, baud rate)
- Use asynchronous communication (async/await)
- Limit UI update frequency to avoid overwhelming display

---

## References

### Standards
- **Modbus Protocol Specification**: [modbus.org](https://modbus.org/docs/Modbus_Application_Protocol_V1_1b3.pdf)
- **Modbus RTU Serial Transmission**: [modbus.org](https://modbus.org/docs/Modbus_over_serial_line_V1_02.pdf)
- **RS-485 Standard**: TIA/EIA-485-A

### Related Documentation
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Android app setup and USB configuration
- [TROUBLESHOOTING_USB.md](TROUBLESHOOTING_USB.md) - USB connection troubleshooting
- [README.md](README.md) - General project overview

### Implementation Files
- [lib/communication/modbus_rtu.dart](lib/communication/modbus_rtu.dart) - Modbus RTU protocol implementation
- [lib/soil_sensor.dart](lib/soil_sensor.dart) - High-level sensor interface
- [lib/models/sensor_exception.dart](lib/models/sensor_exception.dart) - Exception handling

---

## Appendix A: CRC-16 Lookup Table

For performance optimization, CRC-16 can be calculated using a lookup table:

```dart
// Pre-calculated CRC-16 lookup table
static const List<int> crcTable = [
  0x0000, 0xC0C1, 0xC181, 0x0140, 0xC301, 0x03C0, 0x0280, 0xC241,
  0xC601, 0x06C0, 0x0780, 0xC741, 0x0500, 0xC5C1, 0xC481, 0x0440,
  // ... (256 entries total)
];

static int calculateCRC16Fast(Uint8List data, int length) {
  int crc = 0xFFFF;
  for (int i = 0; i < length; i++) {
    int index = (crc ^ data[i]) & 0xFF;
    crc = (crc >> 8) ^ crcTable[index];
  }
  return crc;
}
```

## Appendix B: Slave Address Configuration

Some sensors support changing the slave address via:
1. **DIP switches** on the device
2. **Configuration software** via Modbus write commands
3. **Factory default** (usually address 1)

To scan for sensors with unknown addresses:
```dart
for (int addr = 1; addr <= 247; addr++) {
  try {
    final data = await ModbusRTU.readHoldingRegisters(port, addr, 0x0000, 1);
    print('Sensor found at address $addr');
    break;
  } catch (e) {
    // No sensor at this address
  }
}
```

---

**Document Version**: 1.0  
**Last Updated**: March 7, 2026  
**Author**: Generated for RS485 Soil Sensor Flutter App
