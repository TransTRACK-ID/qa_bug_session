import '../models/diagnostic_event.dart';
import '../models/network_event.dart';
import '../models/recorded_action.dart';
import '../models/visual_evidence_frame.dart';

class TimelineEntry {
  TimelineEntry({
    required this.timestampMs,
    required this.label,
    required this.detail,
  });

  final int timestampMs;
  final String label;
  final String detail;

  String formatClock() {
    final totalSeconds = timestampMs / 1000;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toStringAsFixed(3).padLeft(6, '0');
    return '$minutes:$seconds';
  }
}

class TimelineBuilder {
  static String _actionDetail(RecordedAction action) {
    if (action.type == RecordedActionType.navigation && action.route != null) {
      return action.route!;
    }
    return action.target ?? action.route ?? action.text ?? '';
  }

  List<TimelineEntry> build({
    required List<RecordedAction> actions,
    required List<NetworkEvent> networkEvents,
    required List<DiagnosticEvent> diagnostics,
    List<VisualEvidenceFrame> visualFrames = const [],
  }) {
    final entries = <TimelineEntry>[];

    for (final action in actions) {
      entries.add(
        TimelineEntry(
          timestampMs: action.timestampMs,
          label: action.type.name.toUpperCase(),
          detail: _actionDetail(action),
        ),
      );
    }
    for (final event in networkEvents) {
      entries.add(
        TimelineEntry(
          timestampMs: event.timestampMs,
          label: switch (event.kind) {
            NetworkEventKind.request => 'NETWORK_REQUEST',
            NetworkEventKind.response => 'NETWORK_RESPONSE',
            NetworkEventKind.error => 'NETWORK_ERROR',
          },
          detail: switch (event.kind) {
            NetworkEventKind.request =>
              '${event.request!.method} ${event.request!.url}',
            NetworkEventKind.response =>
              '${event.response!.statusCode} ${event.response!.method} ${event.response!.url}',
            NetworkEventKind.error => event.error!.message,
          },
        ),
      );
    }
    for (final diag in diagnostics) {
      entries.add(
        TimelineEntry(
          timestampMs: diag.timestampMs,
          label: diag.type.toUpperCase(),
          detail: diag.message,
        ),
      );
    }
    for (final frame in visualFrames) {
      entries.add(
        TimelineEntry(
          timestampMs: frame.timestampMs,
          label: 'VISUAL_FRAME',
          detail: frame.archivePath,
        ),
      );
    }

    entries.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return entries;
  }
}
