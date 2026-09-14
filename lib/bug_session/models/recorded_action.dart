import 'package:meta/meta.dart';

/// Semantic user interaction captured during a BugSession.
enum RecordedActionType {
  tap,
  textInput,
  scroll,
  swipe,
  navigation,
  back,
}

@immutable
class RecordedAction {
  const RecordedAction({
    required this.type,
    required this.timestampMs,
    this.target,
    this.text,
    this.route,
    this.scrollDelta,
    this.metadata = const {},
  });

  final RecordedActionType type;
  final int timestampMs;
  final String? target;
  final String? text;
  final String? route;
  final double? scrollDelta;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
        'type': type.name,
        'timestampMs': timestampMs,
        if (target != null) 'target': target,
        if (text != null) 'text': text,
        if (route != null) 'route': route,
        if (scrollDelta != null) 'scrollDelta': scrollDelta,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory RecordedAction.fromJson(Map<String, Object?> json) {
    final typeName = json['type'] as String;
    final type = RecordedActionType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => throw FormatException('Unknown action type: $typeName'),
    );
    return RecordedAction(
      type: type,
      timestampMs: json['timestampMs'] as int,
      target: json['target'] as String?,
      text: json['text'] as String?,
      route: json['route'] as String?,
      scrollDelta: (json['scrollDelta'] as num?)?.toDouble(),
      metadata: Map<String, Object?>.from(
        (json['metadata'] as Map?)?.cast<String, Object?>() ?? {},
      ),
    );
  }
}

/// Wrapper returned by [InteractionRecorder.stop].
@immutable
class RecordedActions {
  const RecordedActions({required this.actions});

  final List<RecordedAction> actions;
}
