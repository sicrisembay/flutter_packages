/// Frame parser for the USB-CANFD binary frame protocol.
///
/// [FrameParser] is a stateful, streaming parser. Feed raw bytes from the
/// serial transport into [addBytes]; it emits complete, checksum-verified
/// [ParsedFrame] objects via the [frames] stream.
///
/// The parser follows the algorithm in FRAME_SPECIFICATION.md:
///   1. Scan forward for a TAG byte (0xFF).
///   2. Wait until at least [kFrameOverhead] (10) bytes are buffered.
///   3. Read the 16-bit little-endian Length field; reject and re-scan if
///      outside [kFrameOverhead, kFrameMaxLength].
///   4. Wait until the full declared number of bytes is buffered.
///   5. Verify the two's-complement checksum; reject and re-scan on failure.
///   6. Emit the validated [ParsedFrame] on [frames].
///   7. Advance the read pointer by Length and repeat.
library;

import 'dart:async';
import 'dart:typed_data';

import 'checksum.dart';
import 'frame_builder.dart';

/// A fully validated frame decoded from the byte stream.
class ParsedFrame {
  /// Hardware timestamp in 10 µs ticks (from TIM2).
  final int timestamp;

  /// Packet sequence number.
  final int seqNum;

  /// Command byte + command-specific data (the frame payload, without the
  /// trailing checksum byte).
  final Uint8List payload;

  /// First byte of [payload] — the command identifier.
  int get commandId => payload.isNotEmpty ? payload[0] : -1;

  const ParsedFrame({
    required this.timestamp,
    required this.seqNum,
    required this.payload,
  });

  @override
  String toString() =>
      'ParsedFrame(ts=$timestamp, seq=$seqNum, cmd=0x${commandId.toRadixString(16).padLeft(2, '0')}, '
      'payloadLen=${payload.length})';
}

/// Streaming frame parser for the USB-CANFD binary frame protocol.
///
/// Typical usage:
/// ```dart
/// final parser = FrameParser();
/// transport.dataStream.listen(parser.addBytes);
/// parser.frames.listen((frame) { ... });
/// // When done:
/// parser.dispose();
/// ```
class FrameParser {
  final StreamController<ParsedFrame> _controller =
      StreamController.broadcast();

  /// The list acts as a simple FIFO accumulation buffer.
  final List<int> _buf = [];

  /// Stream of complete, checksum-verified frames.
  Stream<ParsedFrame> get frames => _controller.stream;

  /// Feed raw bytes from the transport into the parser.
  ///
  /// May be called multiple times as chunks arrive. Internally accumulates
  /// bytes and emits [ParsedFrame]s via [frames] whenever a complete frame
  /// is available.
  void addBytes(Uint8List bytes) {
    _buf.addAll(bytes);
    _parse();
  }

  /// Release resources. Closes the [frames] stream.
  void dispose() {
    _controller.close();
    _buf.clear();
  }

  // ---------------------------------------------------------------------------
  // Internal parsing loop
  // ---------------------------------------------------------------------------

  void _parse() {
    while (true) {
      // Step 1 — scan for TAG byte.
      while (_buf.isNotEmpty && _buf[0] != kFrameTag) {
        _buf.removeAt(0);
      }
      if (_buf.isEmpty) return;

      // Step 2 — need at least kFrameOverhead bytes before reading length.
      if (_buf.length < kFrameOverhead) return;

      // Step 3 — read and validate length.
      final int length = _buf[1] | (_buf[2] << 8);
      if (length < kFrameOverhead || length > kFrameMaxLength) {
        // Invalid length: skip the TAG and keep scanning.
        _buf.removeAt(0);
        continue;
      }

      // Step 4 — wait until the complete frame is buffered.
      if (_buf.length < length) return;

      // Step 5 — verify checksum.
      final Uint8List frameBytes = Uint8List.fromList(_buf.sublist(0, length));
      if (!verifyChecksum(frameBytes)) {
        // Bad checksum: skip the TAG and keep scanning.
        _buf.removeAt(0);
        continue;
      }

      // Step 6 — extract fields and emit.
      final ByteData bd = ByteData.sublistView(frameBytes);
      final int timestamp = bd.getUint32(3, Endian.little);
      final int seqNum = bd.getUint16(7, Endian.little);
      // Payload runs from byte 9 up to (but not including) the checksum byte.
      final Uint8List payload = Uint8List.fromList(frameBytes.sublist(9, length - 1));

      _controller.add(
        ParsedFrame(timestamp: timestamp, seqNum: seqNum, payload: payload),
      );

      // Step 7 — advance past the consumed frame.
      _buf.removeRange(0, length);
    }
  }
}
