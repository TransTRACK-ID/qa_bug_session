import 'package:meta/meta.dart';

@immutable
class VisualEvidenceFrame {
  const VisualEvidenceFrame({
    required this.timestampMs,
    required this.archivePath,
  });

  final int timestampMs;
  final String archivePath;

  Map<String, Object?> toJson() => {
        'timestampMs': timestampMs,
        'archivePath': archivePath,
      };

  factory VisualEvidenceFrame.fromJson(Map<String, Object?> json) {
    return VisualEvidenceFrame(
      timestampMs: json['timestampMs'] as int,
      archivePath: json['archivePath'] as String,
    );
  }
}
