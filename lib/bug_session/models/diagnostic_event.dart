import 'package:meta/meta.dart';

@immutable
class DiagnosticEvent {
  const DiagnosticEvent({
    required this.timestampMs,
    required this.type,
    required this.message,
    this.stackTrace,
  });

  final int timestampMs;
  final String type;
  final String message;
  final String? stackTrace;

  Map<String, Object?> toJson() => {
        'timestampMs': timestampMs,
        'type': type,
        'message': message,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };

  factory DiagnosticEvent.fromJson(Map<String, Object?> json) {
    return DiagnosticEvent(
      timestampMs: json['timestampMs'] as int,
      type: json['type'] as String,
      message: json['message'] as String,
      stackTrace: json['stackTrace'] as String?,
    );
  }
}
