import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:can_usb/can_usb.dart';

/// Minimal in-process mock of [ISerialTransport].
///
/// - Pushes bytes into [_rx] to simulate device responses.
/// - Captures bytes passed to [write] into [written].
/// - [connect] / [disconnect] are no-ops; [isConnected] tracks call state.
class _MockTransport implements ISerialTransport {
  final Stream<Uint8List> _sourceStream;
  final List<Uint8List> written;
  bool _connected = false;

  _MockTransport(this._sourceStream, this.written);

  @override
  Stream<Uint8List> get dataStream => _sourceStream;

  @override
  Future<List<SerialPortInfo>> listAvailablePorts() async => [
    const SerialPortInfo(name: 'MOCK', description: 'Mock port'),
  ];

  @override
  Future<void> connect(String portName, {int baudRate = 115200}) async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> write(Uint8List data) async {
    written.add(data);
  }

  @override
  bool get isConnected => _connected;
}

void main() {
  group('computeChecksum', () {
    test('matches spec Example 1 — Get Device ID request', () {
      // Frame bytes excluding checksum:
      // TAG=0xFF, LEN=0x000B, TS=0x00000000, SEQ=0x0000, CMD=0x00
      final frameWithoutChecksum = Uint8List.fromList([
        0xFF, 0x0B, 0x00, // TAG, Length (little-endian)
        0x00, 0x00, 0x00, 0x00, // Timestamp
        0x00, 0x00, // Packet Seq
        0x00, // Payload: CMD_GET_DEVICE_ID
      ]);
      expect(computeChecksum(frameWithoutChecksum), equals(0xF6));
    });

    test('all-zero data produces 0x00 checksum', () {
      final data = Uint8List(8); // all zeros
      // sum = 0, (~0 + 1) & 0xFF = (0xFF + 1) & 0xFF = 0x00
      expect(computeChecksum(data), equals(0x00));
    });

    test('single 0x01 byte produces 0xFF checksum', () {
      final data = Uint8List.fromList([0x01]);
      expect(computeChecksum(data), equals(0xFF));
    });

    test('wraps correctly at 8-bit boundary', () {
      // sum = 0xFF + 0x01 = 0x100 → masked to 0x00 → checksum = 0x00
      final data = Uint8List.fromList([0xFF, 0x01]);
      expect(computeChecksum(data), equals(0x00));
    });
  });

  group('verifyChecksum', () {
    test('valid frame from spec Example 1 passes verification', () {
      final completeFrame = Uint8List.fromList([
        0xFF, 0x0B, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00,
        0x00,
        0xF6, // checksum
      ]);
      expect(verifyChecksum(completeFrame), isTrue);
    });

    test('corrupted frame fails verification', () {
      final corruptedFrame = Uint8List.fromList([
        0xFF, 0x0B, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00,
        0x00,
        0xAA, // wrong checksum
      ]);
      expect(verifyChecksum(corruptedFrame), isFalse);
    });

    test(
      'round-trip: frame built with computeChecksum passes verifyChecksum',
      () {
        final payload = Uint8List.fromList([0x01, 0xAB, 0xCD]);
        final cs = computeChecksum(payload);
        final frame = Uint8List.fromList([...payload, cs]);
        expect(verifyChecksum(frame), isTrue);
      },
    );

    test('empty frame (single zero byte) passes verification', () {
      final frame = Uint8List.fromList([0x00, 0x00]); // sum = 0
      expect(verifyChecksum(frame), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // frame_builder tests
  // ---------------------------------------------------------------------------
  group('buildFrame', () {
    test('spec Example 1 — Get Device ID request (no timestamp, no seq)', () {
      // Expected bytes from https://github.com/sicrisembay/webserial_canfd/blob/main/firmware/FRAME_SPECIFICATION.md Example 1:
      // 0xFF 0x0B 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0xF6
      final frame = buildFrame(
        payload: Uint8List.fromList([0x00]),
        timestamp: 0,
        seqNum: 0,
      );
      expect(frame.length, equals(11));
      expect(frame[0], equals(0xFF)); // TAG
      expect(frame[1], equals(0x0B)); // Length low byte = 11
      expect(frame[2], equals(0x00)); // Length high byte
      expect(frame[9], equals(0x00)); // CMD_GET_DEVICE_ID
      expect(frame[10], equals(0xF6)); // checksum
      expect(verifyChecksum(frame), isTrue);
    });

    test('spec Example 2 — Send standard CAN frame (ID=0x123, DLC=2)', () {
      // Payload: CMD=0x10, TX_TYPE=0x00, ID=0x23,0x01,0x00,0x00, DLC=2, DATA=0x11,0x22
      final payload = Uint8List.fromList([
        0x10, // CMD_SEND_DOWNSTREAM
        0x00, // TX_TYPE: CAN Classic, BRS OFF, Standard ID
        0x23, 0x01, 0x00, 0x00, // Message ID 0x00000123 little-endian
        0x02, // DLC
        0x11, 0x22, // Data bytes
      ]);
      final frame = buildFrame(payload: payload, timestamp: 0, seqNum: 0);
      expect(frame.length, equals(19)); // 10 overhead + 9 payload
      expect(frame[0], equals(0xFF)); // TAG
      expect(frame[1], equals(0x13)); // Length low = 19
      expect(frame[2], equals(0x00)); // Length high
      expect(verifyChecksum(frame), isTrue);
    });

    test(
      'spec Example 3 — Send extended CAN-FD frame (TX_TYPE=0x05, DLC=12)',
      () {
        // TX_TYPE = 0x05: CAN-FD (bit0), BRS ON (bit1=0), Extended ID (bit2)
        final payload = Uint8List.fromList([
          0x10, // CMD_SEND_DOWNSTREAM
          0x05, // TX_TYPE
          0x78, 0x56, 0x34, 0x12, // ID 0x12345678 little-endian
          0x0C, // DLC = 12
          ...List.filled(12, 0xAB), // 12 data bytes
        ]);
        final frame = buildFrame(payload: payload, timestamp: 0, seqNum: 0);
        // 10 overhead + 19 payload (1+1+4+1+12) = 29 bytes total.
        // Note: spec Example 3 states "23 bytes" which appears to be a typo.
        expect(frame.length, equals(29)); // 10 + 19 payload
        expect(verifyChecksum(frame), isTrue);
      },
    );

    test('minimum frame — empty payload produces 10-byte frame', () {
      final frame = buildFrame(payload: Uint8List(0));
      expect(frame.length, equals(kFrameOverhead));
      expect(frame[0], equals(kFrameTag));
      expect(verifyChecksum(frame), isTrue);
    });

    test('timestamp and seqNum are encoded little-endian', () {
      final frame = buildFrame(
        payload: Uint8List.fromList([0x00]),
        timestamp: 0x12345678,
        seqNum: 0xABCD,
      );
      // Timestamp at bytes 3-6
      expect(frame[3], equals(0x78));
      expect(frame[4], equals(0x56));
      expect(frame[5], equals(0x34));
      expect(frame[6], equals(0x12));
      // SeqNum at bytes 7-8
      expect(frame[7], equals(0xCD));
      expect(frame[8], equals(0xAB));
      expect(verifyChecksum(frame), isTrue);
    });

    test('throws ArgumentError when payload exceeds maximum', () {
      final oversizedPayload = Uint8List(kFrameMaxLength - kFrameOverhead + 1);
      expect(() => buildFrame(payload: oversizedPayload), throwsArgumentError);
    });

    test('maximum valid payload size builds successfully', () {
      final maxPayload = Uint8List(kFrameMaxLength - kFrameOverhead);
      final frame = buildFrame(payload: maxPayload);
      expect(frame.length, equals(kFrameMaxLength));
      expect(verifyChecksum(frame), isTrue);
    });
  });

  group('extractPayload', () {
    test('round-trips payload through buildFrame → extractPayload', () {
      final original = Uint8List.fromList([
        0x10,
        0x00,
        0x23,
        0x01,
        0x00,
        0x00,
        0x02,
        0x11,
        0x22,
      ]);
      final frame = buildFrame(payload: original);
      final extracted = extractPayload(frame);
      expect(extracted, equals(original));
    });

    test('throws ArgumentError for frame shorter than overhead', () {
      expect(() => extractPayload(Uint8List(5)), throwsArgumentError);
    });
  });

  // ---------------------------------------------------------------------------
  // FrameParser tests
  // ---------------------------------------------------------------------------
  group('FrameParser', () {
    /// Helper: build a frame and feed it to a fresh [FrameParser], collecting
    /// all emitted [ParsedFrame]s synchronously.
    Future<List<ParsedFrame>> parseBytes(Uint8List bytes) async {
      final parser = FrameParser();
      final frames = <ParsedFrame>[];
      final sub = parser.frames.listen(frames.add);
      parser.addBytes(bytes);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      parser.dispose();
      return frames;
    }

    test('parses a single valid frame in one chunk', () async {
      final payload = Uint8List.fromList([0x00]); // CMD_GET_DEVICE_ID
      final raw = buildFrame(
        payload: payload,
        timestamp: 0xABCD1234,
        seqNum: 0x0102,
      );
      final frames = await parseBytes(raw);

      expect(frames.length, equals(1));
      expect(frames[0].commandId, equals(0x00));
      expect(frames[0].timestamp, equals(0xABCD1234));
      expect(frames[0].seqNum, equals(0x0102));
      expect(frames[0].payload, equals(payload));
    });

    test('parses two consecutive frames in one chunk', () async {
      final raw1 = buildFrame(payload: Uint8List.fromList([0x01]), seqNum: 1);
      final raw2 = buildFrame(payload: Uint8List.fromList([0x02]), seqNum: 2);
      final combined = Uint8List.fromList([...raw1, ...raw2]);
      final frames = await parseBytes(combined);

      expect(frames.length, equals(2));
      expect(frames[0].commandId, equals(0x01));
      expect(frames[0].seqNum, equals(1));
      expect(frames[1].commandId, equals(0x02));
      expect(frames[1].seqNum, equals(2));
    });

    test('parses a frame split across multiple chunks', () async {
      final parser = FrameParser();
      final frames = <ParsedFrame>[];
      final sub = parser.frames.listen(frames.add);

      final raw = buildFrame(
        payload: Uint8List.fromList([0x10, 0x00, 0x01, 0x02, 0x03, 0x04]),
        seqNum: 7,
      );

      // Feed in 4-byte chunks.
      for (int i = 0; i < raw.length; i += 4) {
        final end = (i + 4 > raw.length) ? raw.length : i + 4;
        parser.addBytes(Uint8List.sublistView(raw, i, end));
      }

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      parser.dispose();

      expect(frames.length, equals(1));
      expect(frames[0].seqNum, equals(7));
      expect(frames[0].commandId, equals(0x10));
    });

    test('skips leading junk bytes before TAG', () async {
      final validFrame = buildFrame(payload: Uint8List.fromList([0x13]));
      // Prepend garbage (no 0xFF in junk to avoid false TAG hits).
      final garbage = Uint8List.fromList([0x00, 0x11, 0x22, 0x33]);
      final combined = Uint8List.fromList([...garbage, ...validFrame]);
      final frames = await parseBytes(combined);

      expect(frames.length, equals(1));
      expect(frames[0].commandId, equals(0x13));
    });

    test(
      'discards frame with bad checksum and recovers next valid frame',
      () async {
        final validFrame = buildFrame(payload: Uint8List.fromList([0x01]));

        // Corrupt a copy of the valid frame (flip the checksum).
        final corrupt = Uint8List.fromList(validFrame);
        corrupt[corrupt.length - 1] ^= 0xFF;

        final validFrame2 = buildFrame(payload: Uint8List.fromList([0x02]));
        // NOTE: corrupt starts with 0xFF (TAG), so the parser will attempt it,
        // fail the checksum, skip the TAG, then keep scanning and find the next frame.
        final combined = Uint8List.fromList([...corrupt, ...validFrame2]);
        final frames = await parseBytes(combined);

        expect(frames.length, equals(1));
        expect(frames[0].commandId, equals(0x02));
      },
    );

    test(
      'discards frame with invalid length and recovers next valid frame',
      () async {
        // Craft a fake header with an invalid length of 5 (< kFrameOverhead).
        final badHeader = Uint8List.fromList([
          0xFF, 0x05, 0x00, // TAG + length=5 (invalid)
          0x00, 0x00, 0x00, 0x00, // filler
          0x00, 0x00, 0x00,
        ]);
        final validFrame = buildFrame(payload: Uint8List.fromList([0x00]));
        final combined = Uint8List.fromList([...badHeader, ...validFrame]);
        final frames = await parseBytes(combined);

        expect(frames.length, equals(1));
        expect(frames[0].commandId, equals(0x00));
      },
    );

    test('emits nothing for empty input', () async {
      final frames = await parseBytes(Uint8List(0));
      expect(frames, isEmpty);
    });

    test('emits nothing for incomplete frame (no crash)', () async {
      final raw = buildFrame(payload: Uint8List.fromList([0x00]));
      // Feed only the first 5 bytes — not enough to form a complete frame.
      final frames = await parseBytes(Uint8List.sublistView(raw, 0, 5));
      expect(frames, isEmpty);
    });

    test('ParsedFrame.toString contains expected fields', () {
      final frame = ParsedFrame(
        timestamp: 100,
        seqNum: 5,
        payload: Uint8List.fromList([0x11, 0x22]),
      );
      final s = frame.toString();
      expect(s, contains('ts=100'));
      expect(s, contains('seq=5'));
      expect(s, contains('cmd=0x11'));
    });
  });

  // ---------------------------------------------------------------------------
  // CanFrameType tests
  // ---------------------------------------------------------------------------
  group('CanFrameType', () {
    test('toByte encodes CAN Classic standard (0x00)', () {
      const t = CanFrameType(isFd: false, brsOff: false, isExtended: false);
      expect(t.toByte(), equals(0x00));
    });

    test('toByte encodes CAN-FD + BRS ON + Extended (0x05)', () {
      const t = CanFrameType(isFd: true, brsOff: false, isExtended: true);
      expect(t.toByte(), equals(0x05));
    });

    test('fromByte decodes 0x05 correctly', () {
      final t = CanFrameType.fromByte(0x05);
      expect(t.isFd, isTrue);
      expect(t.brsOff, isFalse);
      expect(t.isExtended, isTrue);
    });

    test('round-trip toByte → fromByte is identity', () {
      const original = CanFrameType(
        isFd: true,
        brsOff: true,
        isExtended: false,
      );
      final decoded = CanFrameType.fromByte(original.toByte());
      expect(decoded, equals(original));
    });

    test('CanFrameType.classic() produces 0x02 (brsOff=true)', () {
      expect(const CanFrameType.classic().toByte(), equals(0x02));
    });
  });

  // ---------------------------------------------------------------------------
  // CMD_GET_DEVICE_ID
  // ---------------------------------------------------------------------------
  group('CMD_GET_DEVICE_ID', () {
    test('request payload is [0x00]', () {
      expect(buildGetDeviceIdRequest(), equals(Uint8List.fromList([0x00])));
    });

    test('parses full 5-byte response into DeviceIdInfo', () {
      final payload = Uint8List.fromList([0x00, 0xAC, 1, 2, 3]);
      final info = parseGetDeviceIdResponse(payload);
      expect(info.deviceId, equals(0xAC));
      expect(info.versionMajor, equals(1));
      expect(info.versionMinor, equals(2));
      expect(info.versionPatch, equals(3));
      expect(info.firmwareVersion, equals('1.2.3'));
    });

    test('parses legacy 2-byte response with version defaulting to 0.0.0', () {
      final payload = Uint8List.fromList([0x00, 0xAC]);
      final info = parseGetDeviceIdResponse(payload);
      expect(info.deviceId, equals(0xAC));
      expect(info.firmwareVersion, equals('0.0.0'));
    });

    test('throws on short response', () {
      expect(
        () => parseGetDeviceIdResponse(Uint8List.fromList([0x00])),
        throwsArgumentError,
      );
    });

    test('throws on wrong command byte', () {
      expect(
        () => parseGetDeviceIdResponse(Uint8List.fromList([0x01, 0xAC])),
        throwsArgumentError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // CMD_CAN_START / CMD_CAN_STOP / CMD_DEVICE_RESET
  // ---------------------------------------------------------------------------
  group('CMD_CAN_START / STOP / RESET', () {
    test('CAN start request payload is [0x01]', () {
      expect(buildCanStartRequest(), equals(Uint8List.fromList([0x01])));
    });

    test('CAN stop request payload is [0x02]', () {
      expect(buildCanStopRequest(), equals(Uint8List.fromList([0x02])));
    });

    test('device reset request payload is [0x03]', () {
      expect(buildDeviceResetRequest(), equals(Uint8List.fromList([0x03])));
    });

    test('parses CAN start response status byte', () {
      expect(
        parseCanStartResponse(Uint8List.fromList([0x01, 0x00])),
        equals(0),
      );
    });

    test('parses CAN stop response status byte', () {
      expect(parseCanStopResponse(Uint8List.fromList([0x02, 0x00])), equals(0));
    });

    test('CAN start throws on wrong command byte', () {
      expect(
        () => parseCanStartResponse(Uint8List.fromList([0x02, 0x00])),
        throwsArgumentError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // CMD_SEND_DOWNSTREAM
  // ---------------------------------------------------------------------------
  group('CMD_SEND_DOWNSTREAM', () {
    test('builds payload for standard CAN Classic frame', () {
      final frame = CanFrame(
        frameType: const CanFrameType(
          isFd: false,
          brsOff: false,
          isExtended: false,
        ),
        messageId: 0x123,
        dlc: 2,
        data: Uint8List.fromList([0x11, 0x22]),
      );
      final payload = buildSendDownstreamRequest(frame);
      expect(payload[0], equals(cmdSendDownstream)); // CMD
      expect(payload[1], equals(0x00)); // TX_TYPE
      expect(payload[2], equals(0x23)); // ID byte 0
      expect(payload[3], equals(0x01)); // ID byte 1
      expect(payload[4], equals(0x00)); // ID byte 2
      expect(payload[5], equals(0x00)); // ID byte 3
      expect(payload[6], equals(0x02)); // DLC
      expect(payload[7], equals(0x11)); // data[0]
      expect(payload[8], equals(0x22)); // data[1]
    });

    test('parses success response (status=0)', () {
      final payload = Uint8List.fromList([0x10, 0x00]);
      expect(parseSendDownstreamResponse(payload), equals(0));
    });

    test('parses error response (status=1)', () {
      final payload = Uint8List.fromList([0x10, 0x01]);
      expect(parseSendDownstreamResponse(payload), equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  // CMD_SEND_UPSTREAM
  // ---------------------------------------------------------------------------
  group('CMD_SEND_UPSTREAM', () {
    test('parses upstream CAN-FD extended frame correctly', () {
      final payload = Uint8List.fromList([
        0x11, // CMD_SEND_UPSTREAM
        0x05, // RX_TYPE: CAN-FD, BRS ON, Extended
        0x78, 0x56, 0x34, 0x12, // ID = 0x12345678 LE
        0x04, // DLC = 4
        0xAA, 0xBB, 0xCC, 0xDD, // 4 data bytes
      ]);
      final frame = parseSendUpstream(payload);
      expect(frame.messageId, equals(0x12345678));
      expect(frame.dlc, equals(4));
      expect(frame.frameType.isFd, isTrue);
      expect(frame.frameType.isExtended, isTrue);
      expect(frame.data, equals(Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD])));
    });

    test('throws on truncated payload', () {
      expect(
        () => parseSendUpstream(Uint8List.fromList([0x11, 0x00, 0x01])),
        throwsArgumentError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // CMD_PROTOCOL_STATUS
  // ---------------------------------------------------------------------------
  group('CMD_PROTOCOL_STATUS', () {
    test('parses flags correctly', () {
      // flags = 0x07 → ErrorPassive | Warning | BusOff all set
      final payload = Uint8List.fromList([
        0x12, // CMD
        0x01, // LastErrorCode
        0x02, // DataLastErrorCode
        0x03, // Activity
        0x07, // Flags: bits 0,1,2 set
        0x0A, // TDCvalue
      ]);
      final status = parseProtocolStatus(payload);
      expect(status.lastErrorCode, equals(1));
      expect(status.dataLastErrorCode, equals(2));
      expect(status.activity, equals(3));
      expect(status.errorPassive, isTrue);
      expect(status.warning, isTrue);
      expect(status.busOff, isTrue);
      expect(status.rxEsiFlag, isFalse);
      expect(status.tdcValue, equals(0x0A));
    });

    test('throws on short payload', () {
      expect(
        () => parseProtocolStatus(Uint8List.fromList([0x12, 0x00])),
        throwsArgumentError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // CMD_GET_CAN_STATS / CMD_RESET_CAN_STATS
  // ---------------------------------------------------------------------------
  group('CMD_GET_CAN_STATS / RESET', () {
    Uint8List buildStatsPayload({
      int txErr = 0,
      int txErrMax = 0,
      int rxErr = 0,
      int rxErrMax = 0,
      int passErr = 0,
      int dsLoss = 0,
      int usLoss = 0,
      int rxOvf = 0,
      int status = 0,
    }) {
      final buf = Uint8List(18);
      final bd = ByteData.sublistView(buf);
      buf[0] = 0x13;
      bd.setUint16(1, txErr, Endian.little);
      bd.setUint16(3, txErrMax, Endian.little);
      bd.setUint16(5, rxErr, Endian.little);
      bd.setUint16(7, rxErrMax, Endian.little);
      bd.setUint16(9, passErr, Endian.little);
      bd.setUint16(11, dsLoss, Endian.little);
      bd.setUint16(13, usLoss, Endian.little);
      bd.setUint16(15, rxOvf, Endian.little);
      buf[17] = status;
      return buf;
    }

    test('parses stats fields correctly', () {
      final payload = buildStatsPayload(
        txErr: 10,
        txErrMax: 20,
        rxErr: 5,
        rxErrMax: 15,
        passErr: 3,
        dsLoss: 1,
        usLoss: 2,
        rxOvf: 4,
        status: 0,
      );
      final stats = parseGetCanStats(payload);
      expect(stats.txErrorCount, equals(10));
      expect(stats.txErrorCountMax, equals(20));
      expect(stats.rxErrorCount, equals(5));
      expect(stats.rxErrorCountMax, equals(15));
      expect(stats.passiveErrorCount, equals(3));
      expect(stats.downstreamPacketLoss, equals(1));
      expect(stats.upstreamPacketLoss, equals(2));
      expect(stats.rxBufferOverflow, equals(4));
      expect(stats.status, equals(0));
    });

    test('get stats request payload is [0x13]', () {
      expect(buildGetCanStatsRequest(), equals(Uint8List.fromList([0x13])));
    });

    test('reset stats request payload is [0x14]', () {
      expect(buildResetCanStatsRequest(), equals(Uint8List.fromList([0x14])));
    });

    test('parses reset stats response status byte', () {
      final payload = Uint8List.fromList([0x14, 0x00]);
      expect(parseResetCanStatsResponse(payload), equals(0));
    });

    test('throws on short stats payload', () {
      expect(
        () => parseGetCanStats(Uint8List.fromList([0x13, 0x00])),
        throwsArgumentError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // CMD_ENTER_DFU
  // ---------------------------------------------------------------------------
  group('CMD_ENTER_DFU', () {
    test('enter DFU request payload is [0xF0]', () {
      expect(buildEnterDfuRequest(), equals(Uint8List.fromList([0xF0])));
    });

    test('cmdEnterDfu constant equals 0xF0', () {
      expect(cmdEnterDfu, equals(0xF0));
    });
  });

  // ---------------------------------------------------------------------------
  // CanException hierarchy
  // ---------------------------------------------------------------------------
  group('CanException hierarchy', () {
    test('CanConnectionException is a CanException', () {
      const e = CanConnectionException('port failed');
      expect(e, isA<CanException>());
      expect(e.message, equals('port failed'));
      expect(e.toString(), contains('CanConnectionException'));
    });

    test('CanTimeoutException is a CanException', () {
      const e = CanTimeoutException('timed out');
      expect(e, isA<CanException>());
    });

    test('CanChecksumException is a CanException', () {
      const e = CanChecksumException('bad checksum');
      expect(e, isA<CanException>());
    });

    test('CanProtocolException carries statusCode', () {
      const e = CanProtocolException('device error', statusCode: 3);
      expect(e, isA<CanException>());
      expect(e.statusCode, equals(3));
    });
  });

  // ---------------------------------------------------------------------------
  // ISerialTransport / mock transport integration
  // ---------------------------------------------------------------------------
  group('MockSerialTransport → FrameParser integration', () {
    /// A minimal in-process mock that implements [ISerialTransport].
    /// Allows injecting raw bytes via [inject()] without real hardware.
    test(
      'piping mock bytes through FrameParser yields correct ParsedFrame',
      () async {
        final mockController = StreamController<Uint8List>();

        // Build a real frame (CMD_GET_DEVICE_ID response: cmd=0x00, id=0xAC).
        final frame = buildFrame(
          payload: Uint8List.fromList([cmdGetDeviceId, kDeviceId]),
          timestamp: 0x00001234,
          seqNum: 1,
        );

        final parser = FrameParser();
        final received = <ParsedFrame>[];
        final sub = parser.frames.listen(received.add);

        // Wire mock stream into the parser.
        mockController.stream.listen(parser.addBytes);

        // Inject the frame.
        mockController.add(frame);
        await Future<void>.delayed(Duration.zero);

        expect(received.length, equals(1));
        expect(received[0].commandId, equals(cmdGetDeviceId));
        expect(received[0].payload[1], equals(kDeviceId));
        expect(received[0].timestamp, equals(0x00001234));
        expect(received[0].seqNum, equals(1));

        await sub.cancel();
        parser.dispose();
        await mockController.close();
      },
    );

    test('SerialPortInfo toString includes name', () {
      const info = SerialPortInfo(name: 'COM3', description: 'USB Serial');
      expect(info.toString(), contains('COM3'));
      expect(info.toString(), contains('USB Serial'));
    });
  });

  // ---------------------------------------------------------------------------
  // CanusbDevice tests (mock transport)
  // ---------------------------------------------------------------------------

  /// In-process mock that implements [ISerialTransport].
  /// Bytes pushed via [inject] appear on [dataStream].
  /// Bytes written via [write] are captured in [written].
  group('CanusbDevice', () {
    late StreamController<Uint8List> mockRx;
    late List<Uint8List> written;
    late ISerialTransport mockTransport;
    late CanusbDevice device;

    setUp(() {
      mockRx = StreamController<Uint8List>();
      written = [];
      mockTransport = _MockTransport(mockRx.stream, written);
      device = CanusbDevice(
        transport: mockTransport,
        commandTimeout: const Duration(milliseconds: 200),
      );
    });

    tearDown(() async {
      device.dispose();
      await mockRx.close();
    });

    /// Helper: open the mock port and inject a pre-built response frame.
    Future<void> connect() => device.connect('MOCK');

    /// Injects [responsePayload] back into the mock stream as a valid frame,
    /// after a short async gap (simulating device latency).
    void injectResponse(Uint8List responsePayload) {
      Future<void>.delayed(const Duration(milliseconds: 10), () {
        if (!mockRx.isClosed) {
          mockRx.add(buildFrame(payload: responsePayload));
        }
      });
    }

    test('getDeviceId returns DeviceIdInfo on success', () async {
      await connect();
      injectResponse(Uint8List.fromList([cmdGetDeviceId, kDeviceId, 1, 2, 3]));
      final info = await device.getDeviceId();
      expect(info.deviceId, equals(kDeviceId));
      expect(info.versionMajor, equals(1));
      expect(info.versionMinor, equals(2));
      expect(info.versionPatch, equals(3));
      expect(info.firmwareVersion, equals('1.2.3'));
    });

    test('canStart returns HAL_OK (0)', () async {
      await connect();
      injectResponse(Uint8List.fromList([cmdCanStart, 0x00]));
      final status = await device.canStart();
      expect(status, equals(0));
    });

    test('canStop returns HAL_OK (0)', () async {
      await connect();
      injectResponse(Uint8List.fromList([cmdCanStop, 0x00]));
      final status = await device.canStop();
      expect(status, equals(0));
    });

    test('sendFrame returns success (0)', () async {
      await connect();
      injectResponse(Uint8List.fromList([cmdSendDownstream, 0x00]));
      final frame = CanFrame(
        frameType: const CanFrameType(
          isFd: false,
          brsOff: true,
          isExtended: false,
        ),
        messageId: 0x123,
        dlc: 2,
        data: Uint8List.fromList([0x11, 0x22]),
      );
      final status = await device.sendFrame(frame);
      expect(status, equals(0));
    });

    test('getCanStats returns parsed stats', () async {
      await connect();
      final statsBuf = Uint8List(18);
      final bd = ByteData.sublistView(statsBuf);
      statsBuf[0] = cmdGetCanStats;
      bd.setUint16(1, 7, Endian.little); // txErrorCount
      bd.setUint16(5, 3, Endian.little); // rxErrorCount
      statsBuf[17] = 0; // status
      injectResponse(statsBuf);
      final stats = await device.getCanStats();
      expect(stats.txErrorCount, equals(7));
      expect(stats.rxErrorCount, equals(3));
    });

    test('resetCanStats returns success (0)', () async {
      await connect();
      injectResponse(Uint8List.fromList([cmdResetCanStats, 0x00]));
      final status = await device.resetCanStats();
      expect(status, equals(0));
    });

    test('command times out when no response arrives', () async {
      await connect();
      // Do NOT inject any response.
      expect(() => device.getDeviceId(), throwsA(isA<CanTimeoutException>()));
      // Wait for timeout to fire.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    test('rxFrames stream emits upstream CAN frame', () async {
      await connect();
      final received = <CanFrame>[];
      final sub = device.rxFrames.listen(received.add);

      // Build an upstream notification frame.
      final upstreamPayload = Uint8List.fromList([
        cmdSendUpstream,
        0x00, // RX_TYPE: classic, std ID
        0x01, 0x00, 0x00, 0x00, // ID = 0x00000001
        0x02, // DLC
        0xAA, 0xBB, // data
      ]);
      mockRx.add(buildFrame(payload: upstreamPayload));
      await Future<void>.delayed(Duration.zero);

      expect(received.length, equals(1));
      expect(received[0].messageId, equals(1));
      expect(received[0].dlc, equals(2));
      await sub.cancel();
    });

    test('protocolStatus stream emits status notification', () async {
      await connect();
      final received = <ProtocolStatus>[];
      final sub = device.protocolStatus.listen(received.add);

      final statusPayload = Uint8List.fromList([
        cmdProtocolStatus,
        0x00, 0x00, 0x00, // LEC, DLEC, Activity
        0x04, // Flags: BusOff
        0x00, // TDC
      ]);
      mockRx.add(buildFrame(payload: statusPayload));
      await Future<void>.delayed(Duration.zero);

      expect(received.length, equals(1));
      expect(received[0].busOff, isTrue);
      await sub.cancel();
    });

    test('canStatsNotifications stream emits unsolicited stats', () async {
      await connect();
      final received = <CanStats>[];
      final sub = device.canStatsNotifications.listen(received.add);

      // Unsolicited stats (no pending request) — routed to notification stream.
      final statsBuf = Uint8List(18);
      statsBuf[0] = cmdGetCanStats;
      mockRx.add(buildFrame(payload: statsBuf));
      await Future<void>.delayed(Duration.zero);

      expect(received.length, equals(1));
      await sub.cancel();
    });

    test('isConnected reflects port state', () async {
      expect(device.isConnected, isFalse);
      await connect();
      expect(device.isConnected, isTrue);
    });

    test('sequence number increments with each frame sent', () async {
      await connect();

      // Send two commands, checking the seqNum in the transmitted frames.
      injectResponse(Uint8List.fromList([cmdGetDeviceId, kDeviceId, 1, 0, 0]));
      await device.getDeviceId();
      injectResponse(Uint8List.fromList([cmdGetDeviceId, kDeviceId, 1, 0, 0]));
      await device.getDeviceId();

      expect(written.length, equals(2));
      final seq0 = written[0][7] | (written[0][8] << 8);
      final seq1 = written[1][7] | (written[1][8] << 8);
      expect(seq1, equals(seq0 + 1));
    });

    test(
      'enterDfu sends 0xF0 command frame without waiting for response',
      () async {
        await connect();
        await device.enterDfu();
        expect(written.length, equals(1));
        // Payload byte is at frame offset 9 (after TAG + 2-byte len + 4-byte ts + 2-byte seq).
        expect(written[0][9], equals(cmdEnterDfu));
      },
    );

    // -------------------------------------------------------------------------
    // txFrames stream
    // -------------------------------------------------------------------------

    test('txFrames stream emits frame after successful sendFrame', () async {
      await connect();
      final received = <CanFrame>[];
      final sub = device.txFrames.listen(received.add);

      final frame = CanFrame(
        frameType: const CanFrameType.classic(),
        messageId: 0x601,
        dlc: 2,
        data: Uint8List.fromList([0x40, 0x00]),
      );
      injectResponse(Uint8List.fromList([cmdSendDownstream, 0x00]));
      await device.sendFrame(frame);
      await Future<void>.delayed(Duration.zero);

      expect(received.length, equals(1));
      expect(received[0].messageId, equals(0x601));
      expect(received[0].dlc, equals(2));
      expect(received[0].data, equals(Uint8List.fromList([0x40, 0x00])));
      await sub.cancel();
    });

    test('txFrames emits the exact frame object passed to sendFrame', () async {
      await connect();
      final received = <CanFrame>[];
      final sub = device.txFrames.listen(received.add);

      final frame = CanFrame(
        frameType: const CanFrameType(isFd: true, brsOff: false, isExtended: true),
        messageId: 0x12345678,
        dlc: 8,
        data: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
      );
      injectResponse(Uint8List.fromList([cmdSendDownstream, 0x00]));
      await device.sendFrame(frame);
      await Future<void>.delayed(Duration.zero);

      expect(received.length, equals(1));
      expect(received[0], same(frame)); // identical object reference
      await sub.cancel();
    });

    test('txFrames does NOT emit when sendFrame times out', () async {
      await connect();
      final received = <CanFrame>[];
      final sub = device.txFrames.listen(received.add);

      final frame = CanFrame(
        frameType: const CanFrameType.classic(),
        messageId: 0x601,
        dlc: 0,
        data: Uint8List(0),
      );
      // No injectResponse — will time out.
      await expectLater(
        () => device.sendFrame(frame),
        throwsA(isA<CanTimeoutException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(received, isEmpty);
      await sub.cancel();
    });

    test('txFrames and rxFrames are independent streams', () async {
      await connect();
      final txReceived = <CanFrame>[];
      final rxReceived = <CanFrame>[];
      final txSub = device.txFrames.listen(txReceived.add);
      final rxSub = device.rxFrames.listen(rxReceived.add);

      // Inject an unsolicited upstream (RX) frame.
      final upstreamPayload = Uint8List.fromList([
        cmdSendUpstream,
        0x00,
        0x05, 0x00, 0x00, 0x00,
        0x01,
        0xFF,
      ]);
      mockRx.add(buildFrame(payload: upstreamPayload));
      await Future<void>.delayed(Duration.zero);

      // Then send a downstream (TX) frame.
      injectResponse(Uint8List.fromList([cmdSendDownstream, 0x00]));
      final txFrame = CanFrame(
        frameType: const CanFrameType.classic(),
        messageId: 0x200,
        dlc: 1,
        data: Uint8List.fromList([0xAB]),
      );
      await device.sendFrame(txFrame);
      await Future<void>.delayed(Duration.zero);

      expect(rxReceived.length, equals(1));
      expect(rxReceived[0].messageId, equals(0x05));
      expect(txReceived.length, equals(1));
      expect(txReceived[0].messageId, equals(0x200));

      await txSub.cancel();
      await rxSub.cancel();
    });
  });
}
