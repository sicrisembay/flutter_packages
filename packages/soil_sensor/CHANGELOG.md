## 0.1.0

* Initial release.
* USB serial transport for Android (`usb_serial`) and Windows (`flutter_libserialport`).
* Modbus RTU FC03 implementation via `ModbusRtuService`.
* High-level `SoilSensorService` API: `listDevices`, `connect`, `disconnect`, `readSensor`.
* `SensorReading` model: moisture, temperature, conductivity, pH, nitrogen, phosphorus, potassium.
* Automatic fallback from 7-register (NPK) read to 3-register (basic) read on Modbus exception 0x02.
* `hasNpk` and `isRecent` convenience getters on `SensorReading`.
