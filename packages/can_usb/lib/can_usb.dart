/// can_usb — Flutter package for the USB-CANFD adapter.
library;

// Exceptions
export 'src/exceptions.dart';

// Transport layer
export 'src/transport/i_serial_transport.dart';
export 'src/transport/android_serial_transport.dart';
export 'src/transport/serial_port_transport.dart';

// Protocol layer
export 'src/protocol/checksum.dart';
export 'src/protocol/frame_builder.dart';
export 'src/protocol/frame_parser.dart';

// Models
export 'src/models/bitrate.dart';
export 'src/models/can_frame.dart';
export 'src/models/can_stats.dart';
export 'src/models/device_id_info.dart';
export 'src/models/protocol_status.dart';

// Commands
export 'src/commands/command_ids.dart';
export 'src/commands/cmd_get_device_id.dart';
export 'src/commands/cmd_can_start_stop.dart';
export 'src/commands/cmd_send_downstream.dart';
export 'src/commands/cmd_send_upstream.dart';
export 'src/commands/cmd_protocol_status.dart';
export 'src/commands/cmd_can_stats.dart';
export 'src/commands/cmd_enter_dfu.dart';

// High-level device API
export 'src/canusb_device.dart';
