import 'dart:typed_data';

/// Low-level Modbus RTU framing primitives.
///
/// Supports FC03 (Read Holding Registers) as required by the soil sensor.
/// All multi-byte values are big-endian on the wire; CRC is sent lo-byte first.
class ModbusRtuService {
  /// Calculates the CRC-16/ANSI (Modbus) checksum for [length] bytes of [data].
  ///
  /// Polynomial: 0xA001 (reflected 0x8005), initial value: 0xFFFF.
  /// The result is a 16-bit unsigned integer; transmit the low byte first.
  static int calculateCrc16(Uint8List data, int length) {
    int crc = 0xFFFF;
    for (int i = 0; i < length; i++) {
      crc ^= data[i];
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x0001) != 0) {
          crc = (crc >> 1) ^ 0xA001;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc;
  }

  /// Build an FC03 Read Holding Registers request (8 bytes).
  static Uint8List buildReadRequest({
    required int slaveAddress,
    required int startRegister,
    required int registerCount,
  }) {
    final frame = Uint8List(8);
    frame[0] = slaveAddress & 0xFF;
    frame[1] = 0x03; // FC: Read Holding Registers
    frame[2] = (startRegister >> 8) & 0xFF;
    frame[3] = startRegister & 0xFF;
    frame[4] = (registerCount >> 8) & 0xFF;
    frame[5] = registerCount & 0xFF;
    final crc = calculateCrc16(frame, 6);
    frame[6] = crc & 0xFF;        // CRC lo byte
    frame[7] = (crc >> 8) & 0xFF; // CRC hi byte
    return frame;
  }

  /// Expected total response length for FC03 with [registerCount] registers.
  /// Formula: 3 (addr + fc + byteCount) + registerCount*2 + 2 (CRC)
  static int expectedResponseLength(int registerCount) =>
      5 + registerCount * 2;

  /// Parse and validate an FC03 response.
  ///
  /// Returns the raw register integer values (unsigned 16-bit).
  /// Throws [FormatException] on CRC mismatch or short response.
  /// Throws [StateError] on Modbus exception response.
  static List<int> parseReadResponse(Uint8List response, int registerCount) {
    final expected = expectedResponseLength(registerCount);
    if (response.length < expected) {
      throw FormatException(
        'Response too short: got ${response.length}, expected $expected bytes.',
      );
    }

    // Exception response: FC has high bit set (0x03 | 0x80 = 0x83)
    if ((response[1] & 0x80) != 0) {
      final code = response[2];
      final msg = switch (code) {
        0x01 => 'Illegal Function',
        0x02 => 'Illegal Data Address',
        0x03 => 'Illegal Data Value',
        0x04 => 'Slave Device Failure',
        _ => '0x${code.toRadixString(16).toUpperCase()}',
      };
      throw StateError('Modbus exception: $msg');
    }

    // Validate CRC (lo byte first in frame)
    final receivedCrc = response[expected - 2] | (response[expected - 1] << 8);
    final calculatedCrc = calculateCrc16(response, expected - 2);
    if (receivedCrc != calculatedCrc) {
      throw FormatException(
        'CRC mismatch: received 0x${receivedCrc.toRadixString(16)}, '
        'calculated 0x${calculatedCrc.toRadixString(16)}.',
      );
    }

    // Extract register values (big-endian, starting at byte 3)
    final registers = <int>[];
    for (int i = 0; i < registerCount; i++) {
      final offset = 3 + i * 2;
      registers.add((response[offset] << 8) | response[offset + 1]);
    }
    return registers;
  }

  /// Scale 7 raw register values into physical quantities.
  ///
  /// Register order: moisture, temperature, conductivity, pH, N, P, K
  static Map<String, double> scaleExtendedRegisters(List<int> raw) {
    assert(raw.length >= 7);

    // Temperature is INT16 — apply two's complement if high bit set.
    int rawTemp = raw[1];
    if (rawTemp & 0x8000 != 0) rawTemp -= 0x10000;

    return {
      'moisture': raw[0] / 10.0,
      'temperature': rawTemp / 10.0,
      'conductivity': raw[2].toDouble(),
      'ph': raw[3] / 10.0,
      'nitrogen': raw[4].toDouble(),
      'phosphorus': raw[5].toDouble(),
      'potassium': raw[6].toDouble(),
    };
  }

  /// Scale 3 raw register values (basic sensor: moisture, temp, conductivity).
  static Map<String, double> scaleBasicRegisters(List<int> raw) {
    assert(raw.length >= 3);
    int rawTemp = raw[1];
    if (rawTemp & 0x8000 != 0) rawTemp -= 0x10000;
    return {
      'moisture': raw[0] / 10.0,
      'temperature': rawTemp / 10.0,
      'conductivity': raw[2].toDouble(),
    };
  }
}
