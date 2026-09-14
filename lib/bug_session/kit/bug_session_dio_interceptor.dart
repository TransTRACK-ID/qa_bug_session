import 'package:dio/dio.dart';

import '../models/network_event.dart';
import '../recording/bug_session_recorder.dart';
import '../recording/network_recorder.dart';

/// Forwards Dio traffic to [NetworkRecorder] while capturing.
class BugSessionDioInterceptor extends Interceptor {
  BugSessionDioInterceptor(this._recorder);

  final BugSessionRecorder _recorder;

  NetworkRecorder get _network => _recorder.networkRecorder;

  InMemoryNetworkRecorder? get _clock {
    final recorder = _network;
    return recorder is InMemoryNetworkRecorder ? recorder : null;
  }

  int _ts() {
    if (_recorder.isShadowplayActive) {
      return _recorder.shadowplay.elapsedMs();
    }
    return _clock?.elapsedMs() ?? 0;
  }

  bool get _capturing =>
      _recorder.isRecording || _recorder.isShadowplayActive;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_capturing) {
      handler.next(options);
      return;
    }
    final event = NetworkEvent.request(
      NetworkRequestEvent(
        timestampMs: _ts(),
        method: options.method,
        url: options.uri.toString(),
        correlationId: options.hashCode.toString(),
      ),
    );
    if (_recorder.isShadowplayActive) {
      _recorder.mirrorNetworkToShadowplay(event);
    } else {
      _network.recordRequest(event.request!);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_capturing) {
      handler.next(response);
      return;
    }
    final event = NetworkEvent.response(
      NetworkResponseEvent(
        timestampMs: _ts(),
        method: response.requestOptions.method,
        url: response.requestOptions.uri.toString(),
        statusCode: response.statusCode ?? 0,
        correlationId: response.requestOptions.hashCode.toString(),
      ),
    );
    if (_recorder.isShadowplayActive) {
      _recorder.mirrorNetworkToShadowplay(event);
    } else {
      _network.recordResponse(event.response!);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_capturing) {
      handler.next(err);
      return;
    }
    final event = NetworkEvent.error(
      NetworkErrorEvent(
        timestampMs: _ts(),
        method: err.requestOptions.method,
        url: err.requestOptions.uri.toString(),
        message: err.message ?? err.type.name,
        correlationId: err.requestOptions.hashCode.toString(),
      ),
    );
    if (_recorder.isShadowplayActive) {
      _recorder.mirrorNetworkToShadowplay(event);
    } else {
      _network.recordError(event.error!);
    }
    handler.next(err);
  }
}
