/// Codec for CMD_ENTER_DFU (0xF0).
///
/// Triggers entry into the STM32 ROM USB DFU bootloader.
/// The device writes a magic word to `.noinit` RAM, calls
/// `NVIC_SystemReset()`, and re-enumerates as a DFU device
/// (`idVendor=0x0483`, `idProduct=0xDF11`).
///
/// **No response is sent** — the device resets immediately.
library;

import 'dart:typed_data';

import 'command_ids.dart';

/// Builds the Enter DFU request payload: a single byte `0xF0`.
Uint8List buildEnterDfuRequest() => Uint8List.fromList([cmdEnterDfu]);
