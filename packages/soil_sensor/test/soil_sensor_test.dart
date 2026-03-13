import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soil_sensor/soil_sensor.dart';

void main() {
  // ── SensorReading ─────────────────────────────────────────────────────────
  group('SensorReading', () {
    SensorReading makeReading({
      double moisture = 25.0,
      double temperature = 21.0,
      double conductivity = 300.0,
      double ph = 6.5,
      double nitrogen = 0,
      double phosphorus = 0,
      double potassium = 0,
      DateTime? readAt,
    }) {
      return SensorReading(
        moisture: moisture,
        temperature: temperature,
        conductivity: conductivity,
        ph: ph,
        nitrogen: nitrogen,
        phosphorus: phosphorus,
        potassium: potassium,
        readAt: readAt ?? DateTime.now(),
      );
    }

    test('stores all field values correctly', () {
      final r = makeReading(
        moisture: 35.5,
        temperature: -5.0,
        conductivity: 1450.0,
        ph: 6.8,
        nitrogen: 120,
        phosphorus: 45,
        potassium: 180,
      );
      expect(r.moisture, 35.5);
      expect(r.temperature, -5.0);
      expect(r.conductivity, 1450.0);
      expect(r.ph, 6.8);
      expect(r.nitrogen, 120);
      expect(r.phosphorus, 45);
      expect(r.potassium, 180);
    });

    test('hasNpk is true when any NPK value > 0', () {
      expect(makeReading(nitrogen: 10).hasNpk, isTrue);
      expect(makeReading(phosphorus: 1).hasNpk, isTrue);
      expect(makeReading(potassium: 0.1).hasNpk, isTrue);
    });

    test('hasNpk is false when all NPK values are 0', () {
      expect(makeReading().hasNpk, isFalse);
    });

    test('isRecent is true for a reading taken now', () {
      expect(makeReading(readAt: DateTime.now()).isRecent, isTrue);
    });

    test('isRecent is false for a reading older than 10 minutes', () {
      final old = makeReading(
        readAt: DateTime.now().subtract(const Duration(minutes: 11)),
      );
      expect(old.isRecent, isFalse);
    });
  });

  // ── ModbusRtuService ─────────────────────────────────────────────────────
  group('ModbusRtuService', () {
    test('expectedResponseLength formula is correct', () {
      expect(ModbusRtuService.expectedResponseLength(1), 7);
      expect(ModbusRtuService.expectedResponseLength(3), 11);
      expect(ModbusRtuService.expectedResponseLength(7), 19);
    });

    test('buildReadRequest produces correct 8-byte frame', () {
      // Known good: slave=1, start=0x0000, count=3 → 01 03 00 00 00 03 05 CB
      final frame = ModbusRtuService.buildReadRequest(
        slaveAddress: 1,
        startRegister: 0x0000,
        registerCount: 3,
      );
      expect(frame.length, 8);
      expect(frame[0], 0x01); // slave address
      expect(frame[1], 0x03); // function code
      expect(frame[2], 0x00); // start hi
      expect(frame[3], 0x00); // start lo
      expect(frame[4], 0x00); // count hi
      expect(frame[5], 0x03); // count lo
      expect(frame[6], 0x05); // CRC lo
      expect(frame[7], 0xCB); // CRC hi
    });

    test('calculateCrc16 matches known value', () {
      // 01 03 00 00 00 03  →  CRC = 0xCB05
      final data = Uint8List.fromList([0x01, 0x03, 0x00, 0x00, 0x00, 0x03]);
      expect(ModbusRtuService.calculateCrc16(data, 6), 0xCB05);
    });

    test('parseReadResponse returns correct register values', () {
      // 3-register response: moisture=235 (23.5%), temp=215 (21.5°C), cond=1450
      final response = Uint8List.fromList([
        0x01, 0x03, 0x06,         // addr, FC, byte count
        0x00, 0xEB,               // reg0 = 235
        0x00, 0xD7,               // reg1 = 215
        0x05, 0xAA,               // reg2 = 1450
        0x00, 0x00,               // CRC placeholder — recalculate
      ]);
      // Fix the CRC in the response
      final crc = ModbusRtuService.calculateCrc16(response, 9);
      response[9] = crc & 0xFF;
      response[10] = (crc >> 8) & 0xFF;

      final registers = ModbusRtuService.parseReadResponse(response, 3);
      expect(registers, [235, 215, 1450]);
    });

    test('parseReadResponse throws FormatException on CRC mismatch', () {
      final response = Uint8List.fromList([
        0x01, 0x03, 0x02, 0x00, 0xEB, 0xFF, 0xFF, // bad CRC
      ]);
      expect(
        () => ModbusRtuService.parseReadResponse(response, 1),
        throwsA(isA<FormatException>()),
      );
    });

    test('parseReadResponse throws StateError on Modbus exception response', () {
      // 01 83 02 C0 F1  — error code 0x02 (Illegal Data Address)
      // Use registerCount=0 so expectedResponseLength=5 matches the 5-byte error frame.
      // The exception flag check precedes the CRC check in parseReadResponse.
      final response =
          Uint8List.fromList([0x01, 0x83, 0x02, 0xC0, 0xF1]);
      expect(
        () => ModbusRtuService.parseReadResponse(response, 0),
        throwsA(isA<StateError>()),
      );
    });

    test('scaleExtendedRegisters converts raw values correctly', () {
      final raw = [235, 215, 1450, 68, 120, 45, 180];
      final scaled = ModbusRtuService.scaleExtendedRegisters(raw);
      expect(scaled['moisture'], closeTo(23.5, 0.01));
      expect(scaled['temperature'], closeTo(21.5, 0.01));
      expect(scaled['conductivity'], 1450.0);
      expect(scaled['ph'], closeTo(6.8, 0.01));
      expect(scaled['nitrogen'], 120.0);
      expect(scaled['phosphorus'], 45.0);
      expect(scaled['potassium'], 180.0);
    });

    test('scaleExtendedRegisters handles negative temperature (INT16)', () {
      // -5.0°C → raw = 65536 - 50 = 65486 = 0xFFCE
      final raw = [100, 0xFFCE, 500, 70, 0, 0, 0];
      final scaled = ModbusRtuService.scaleExtendedRegisters(raw);
      expect(scaled['temperature'], closeTo(-5.0, 0.01));
    });

    test('scaleBasicRegisters converts 3 raw values correctly', () {
      final raw = [235, 215, 1450];
      final scaled = ModbusRtuService.scaleBasicRegisters(raw);
      expect(scaled['moisture'], closeTo(23.5, 0.01));
      expect(scaled['temperature'], closeTo(21.5, 0.01));
      expect(scaled['conductivity'], 1450.0);
    });
  });
}
