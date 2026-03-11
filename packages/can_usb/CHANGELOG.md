## 0.1.0

* Initial release.
* Serial transport layer via `flutter_libserialport` (`SerialPortTransport`).
* Injectable `ISerialTransport` interface for easy unit-test mocking.
* Binary frame builder (`buildFrame`) and streaming frame parser (`FrameParser`).
* CRC/checksum implementation matching the device frame specification.
* Commands: Get Device ID, CAN Start, CAN Stop, Send Downstream (TX), Send
  Upstream (RX), Protocol Status, Get/Reset CAN Stats, Enter DFU.
* High-level `CanusbDevice` API with broadcast streams for received frames,
  protocol status notifications, and CAN stats notifications.
* Typed exception hierarchy: `CanConnectionException`, `CanTimeoutException`,
  `CanChecksumException`, `CanProtocolException`.
