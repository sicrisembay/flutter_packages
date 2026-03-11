/// Typed exception hierarchy for the can_usb package.
library;

/// Base class for all can_usb exceptions.
class CanException implements Exception {
  final String message;
  const CanException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when opening or closing a serial port fails.
class CanConnectionException extends CanException {
  const CanConnectionException(super.message);
}

/// Thrown when a request command receives no response within the timeout.
class CanTimeoutException extends CanException {
  const CanTimeoutException(super.message);
}

/// Thrown when a received frame has an invalid checksum.
class CanChecksumException extends CanException {
  const CanChecksumException(super.message);
}

/// Thrown when the device returns a non-zero HAL status code.
class CanProtocolException extends CanException {
  /// The status byte returned by the device.
  final int statusCode;
  const CanProtocolException(super.message, {required this.statusCode});
}
