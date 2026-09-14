import 'package:meta/meta.dart';

enum NetworkEventKind { request, response, error }

@immutable
class NetworkRequestEvent {
  const NetworkRequestEvent({
    required this.timestampMs,
    required this.method,
    required this.url,
    this.correlationId,
    this.headers = const {},
    this.body,
  });

  final int timestampMs;
  final String method;
  final String url;
  final String? correlationId;
  final Map<String, String> headers;
  final String? body;

  Map<String, Object?> toJson() => {
        'kind': 'request',
        'timestampMs': timestampMs,
        'method': method,
        'url': url,
        if (correlationId != null) 'correlationId': correlationId,
        if (headers.isNotEmpty) 'headers': headers,
        if (body != null) 'body': body,
      };

  factory NetworkRequestEvent.fromJson(Map<String, Object?> json) {
    return NetworkRequestEvent(
      timestampMs: json['timestampMs'] as int,
      method: json['method'] as String,
      url: json['url'] as String,
      correlationId: json['correlationId'] as String?,
      headers: Map<String, String>.from(
        (json['headers'] as Map?)?.cast<String, String>() ?? {},
      ),
      body: json['body'] as String?,
    );
  }
}

@immutable
class NetworkResponseEvent {
  const NetworkResponseEvent({
    required this.timestampMs,
    required this.method,
    required this.url,
    required this.statusCode,
    this.correlationId,
    this.durationMs,
    this.body,
  });

  final int timestampMs;
  final String method;
  final String url;
  final int statusCode;
  final String? correlationId;
  final int? durationMs;
  final String? body;

  Map<String, Object?> toJson() => {
        'kind': 'response',
        'timestampMs': timestampMs,
        'method': method,
        'url': url,
        'statusCode': statusCode,
        if (correlationId != null) 'correlationId': correlationId,
        if (durationMs != null) 'durationMs': durationMs,
        if (body != null) 'body': body,
      };

  factory NetworkResponseEvent.fromJson(Map<String, Object?> json) {
    return NetworkResponseEvent(
      timestampMs: json['timestampMs'] as int,
      method: json['method'] as String,
      url: json['url'] as String,
      statusCode: json['statusCode'] as int,
      correlationId: json['correlationId'] as String?,
      durationMs: json['durationMs'] as int?,
      body: json['body'] as String?,
    );
  }
}

@immutable
class NetworkErrorEvent {
  const NetworkErrorEvent({
    required this.timestampMs,
    required this.method,
    required this.url,
    required this.message,
    this.correlationId,
  });

  final int timestampMs;
  final String method;
  final String url;
  final String message;
  final String? correlationId;

  Map<String, Object?> toJson() => {
        'kind': 'error',
        'timestampMs': timestampMs,
        'method': method,
        'url': url,
        'message': message,
        if (correlationId != null) 'correlationId': correlationId,
      };

  factory NetworkErrorEvent.fromJson(Map<String, Object?> json) {
    return NetworkErrorEvent(
      timestampMs: json['timestampMs'] as int,
      method: json['method'] as String,
      url: json['url'] as String,
      message: json['message'] as String,
      correlationId: json['correlationId'] as String?,
    );
  }
}

@immutable
class NetworkEvent {
  const NetworkEvent._({
    required this.kind,
    this.request,
    this.response,
    this.error,
  });

  factory NetworkEvent.request(NetworkRequestEvent event) =>
      NetworkEvent._(kind: NetworkEventKind.request, request: event);

  factory NetworkEvent.response(NetworkResponseEvent event) =>
      NetworkEvent._(kind: NetworkEventKind.response, response: event);

  factory NetworkEvent.error(NetworkErrorEvent event) =>
      NetworkEvent._(kind: NetworkEventKind.error, error: event);

  final NetworkEventKind kind;
  final NetworkRequestEvent? request;
  final NetworkResponseEvent? response;
  final NetworkErrorEvent? error;

  int get timestampMs {
    return switch (kind) {
      NetworkEventKind.request => request!.timestampMs,
      NetworkEventKind.response => response!.timestampMs,
      NetworkEventKind.error => error!.timestampMs,
    };
  }

  Map<String, Object?> toJson() {
    return switch (kind) {
      NetworkEventKind.request => request!.toJson(),
      NetworkEventKind.response => response!.toJson(),
      NetworkEventKind.error => error!.toJson(),
    };
  }

  factory NetworkEvent.fromJson(Map<String, Object?> json) {
    final kind = json['kind'] as String;
    return switch (kind) {
      'request' => NetworkEvent.request(NetworkRequestEvent.fromJson(json)),
      'response' => NetworkEvent.response(NetworkResponseEvent.fromJson(json)),
      'error' => NetworkEvent.error(NetworkErrorEvent.fromJson(json)),
      _ => throw FormatException('Unknown network event kind: $kind'),
    };
  }
}
