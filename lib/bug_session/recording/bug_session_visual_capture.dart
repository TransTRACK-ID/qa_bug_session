import 'dart:async';
import 'dart:typed_data';

import '../models/visual_evidence_frame.dart';

class CapturedVisualFrame {
  CapturedVisualFrame({
    required this.timestampMs,
    required this.pngBytes,
  });

  final int timestampMs;
  final Uint8List pngBytes;
}

/// Periodic PNG capture while a session is recording (host supplies [capturePng]).
class BugSessionVisualCapture {
  BugSessionVisualCapture({
    required this.capturePng,
    this.interval = const Duration(seconds: 3),
    this.maxFrames = 80,
  });

  final Future<Uint8List?> Function() capturePng;
  final Duration interval;
  final int maxFrames;

  final List<CapturedVisualFrame> _frames = [];
  Timer? _timer;
  int? _startedAtMs;
  bool _captureInFlight = false;

  List<CapturedVisualFrame> get frames => List.unmodifiable(_frames);

  int _elapsedMs() {
    final start = _startedAtMs;
    if (start == null) return 0;
    return DateTime.now().millisecondsSinceEpoch - start;
  }

  void start() {
    _frames.clear();
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      unawaited(_captureTick());
    });
  }

  Future<void> _captureTick() async {
    if (_captureInFlight || _frames.length >= maxFrames) {
      return;
    }
    _captureInFlight = true;
    try {
      final bytes = await capturePng();
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      _frames.add(
        CapturedVisualFrame(timestampMs: _elapsedMs(), pngBytes: bytes),
      );
    } catch (_) {
      // Visual capture must not break recording.
    } finally {
      _captureInFlight = false;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _startedAtMs = null;
  }

  List<VisualEvidenceFrame> toArchiveIndex() {
    return [
      for (var i = 0; i < _frames.length; i++)
        VisualEvidenceFrame(
          timestampMs: _frames[i].timestampMs,
          archivePath: 'visual/frame_${i.toString().padLeft(4, '0')}.png',
        ),
    ];
  }

  Map<String, Uint8List> toArchiveFiles() {
    final map = <String, Uint8List>{};
    for (var i = 0; i < _frames.length; i++) {
      map['visual/frame_${i.toString().padLeft(4, '0')}.png'] =
          _frames[i].pngBytes;
    }
    return map;
  }
}
