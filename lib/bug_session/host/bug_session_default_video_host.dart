import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qa_bug_session/bug_session/kit/bug_session_scope.dart';
import 'package:qa_bug_session/bug_session/recording/bug_session_video_capture.dart';
import 'package:qa_bug_session/bug_session/ui/bug_session_tap_ripple_overlay.dart';
import 'package:screen_recorder/screen_recorder.dart';

/// Real-time capture rate: one encoded frame per [bugSessionRealtimeCaptureFps] seconds.
const bugSessionRealtimeCaptureFps = 15;
const _displayFpsAssumed = 60;
const _capturePixelRatio = 0.55;

int get _skipFramesBetweenCaptures {
  final step =
      (_displayFpsAssumed / bugSessionRealtimeCaptureFps).round().clamp(1, 30);
  return step - 1;
}

final bugSessionScreenRecorderController = ScreenRecorderController(
  pixelRatio: _capturePixelRatio,
  skipFramesBetweenCaptures: _skipFramesBetweenCaptures,
  exporter: BugSessionDefaultMp4Exporter(),
);

BugSessionDefaultMp4Exporter get bugSessionDefaultMp4Exporter =>
    bugSessionScreenRecorderController.exporter as BugSessionDefaultMp4Exporter;

/// Wrap [child] when BugSession tools are enabled ([enabled] from host gate).
Widget wrapBugSessionDefaultVideoHost(
  Widget child, {
  required bool Function() enabled,
}) {
  if (!enabled()) {
    return child;
  }
  return LayoutBuilder(
    builder: (context, constraints) {
      bugSessionDefaultMp4Exporter.bindContext(context);
      final screen = MediaQuery.sizeOf(context);
      final width = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : screen.width;
      final height = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : screen.height;
      final kit = BugSessionScope.maybeOf(context);
      final recordedChild = Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (kit != null) BugSessionTapRippleOverlay(kit: kit),
        ],
      );
      return ScreenRecorder(
        controller: bugSessionScreenRecorderController,
        width: width,
        height: height,
        child: recordedChild,
      );
    },
  );
}

Future<void> _yieldToUi() async {
  await Future<void>.delayed(Duration.zero);
  await SchedulerBinding.instance.endOfFrame;
}

int _evenDimension(int value) {
  if (value <= 0) {
    return 2;
  }
  return value.isEven ? value : value - 1;
}

Duration _shadowplayVideoRetention(BuildContext? context) {
  final kit = context != null ? BugSessionScope.maybeOf(context) : null;
  if (kit == null) {
    return const Duration(seconds: 90);
  }
  return kit.config.shadowplay.defaultVideoRetention;
}

bool _useRollingVideoBuffer(BuildContext? context) {
  final kit = context != null ? BugSessionScope.maybeOf(context) : null;
  if (kit == null) {
    return true;
  }
  final recorder = kit.recorder;
  return recorder.isShadowplayActive && !recorder.isRecording;
}

class BugSessionDefaultMp4Exporter extends Exporter {
  bool _capturing = false;
  final List<int> _frameWallMs = [];
  BuildContext? _context;

  void bindContext(BuildContext context) {
    _context = context;
  }

  Future<void> prepareForRecording() async {
    _capturing = true;
    _frameWallMs.clear();
    _disposeBufferedImages();
    clear();
  }

  void haltBuffering() {
    _capturing = false;
  }

  @override
  void onNewFrame(Frame frame) {
    if (!_capturing) {
      return;
    }
    super.onNewFrame(frame);
    _frameWallMs.add(DateTime.now().millisecondsSinceEpoch);
    _trimBufferToPolicy();
  }

  void _trimBufferToPolicy() {
    if (!_useRollingVideoBuffer(_context)) {
      return;
    }
    final retentionMs = _shadowplayVideoRetention(_context).inMilliseconds;
    final now = DateTime.now().millisecondsSinceEpoch;
    while (frames.isNotEmpty &&
        _frameWallMs.isNotEmpty &&
        now - _frameWallMs.first > retentionMs) {
      frames.removeAt(0).image.dispose();
      _frameWallMs.removeAt(0);
    }
    final maxFrames =
        (retentionMs / 1000 * bugSessionRealtimeCaptureFps).ceil() +
            bugSessionRealtimeCaptureFps;
    while (frames.length > maxFrames) {
      frames.removeAt(0).image.dispose();
      if (_frameWallMs.isNotEmpty) {
        _frameWallMs.removeAt(0);
      }
    }
  }

  Future<BugSessionVideoArtifact?> finishAsMp4Artifact() async {
    if (frames.isEmpty) {
      releaseFrameBuffer();
      return null;
    }

    final snapshot = List<Frame>.from(frames);
    var maxWidth = 2;
    var maxHeight = 2;
    for (final frame in snapshot) {
      if (frame.image.width > maxWidth) {
        maxWidth = frame.image.width;
      }
      if (frame.image.height > maxHeight) {
        maxHeight = frame.image.height;
      }
    }
    maxWidth = _evenDimension(maxWidth);
    maxHeight = _evenDimension(maxHeight);

    File? tempFile;
    try {
      final dir = await getTemporaryDirectory();
      tempFile = File(
        '${dir.path}/bug_session_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      await FlutterQuickVideoEncoder.setup(
        width: maxWidth,
        height: maxHeight,
        fps: bugSessionRealtimeCaptureFps,
        videoBitrate: 2500000,
        profileLevel: ProfileLevel.baselineAutoLevel,
        audioBitrate: 0,
        audioChannels: 0,
        sampleRate: 0,
        filepath: tempFile.path,
      );

      for (final frame in snapshot) {
        await _yieldToUi();
        final rgba = await _rgbaBytes(frame.image, maxWidth, maxHeight);
        await FlutterQuickVideoEncoder.appendVideoFrame(rgba);
      }

      await FlutterQuickVideoEncoder.finish();
      final bytes = await tempFile.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return BugSessionVideoArtifact(
        bytes: bytes,
        archiveFileName: 'session.mp4',
        mimeType: 'video/mp4',
      );
    } on Object catch (e, st) {
      debugPrint('BugSession MP4 encode failed: $e\n$st');
      return null;
    } finally {
      releaseFrameBuffer();
      if (tempFile != null && tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } on Object {
          // ignore cleanup errors
        }
      }
    }
  }

  void releaseFrameBuffer() {
    _capturing = false;
    _frameWallMs.clear();
    _disposeBufferedImages();
    clear();
  }

  void _disposeBufferedImages() {
    for (final frame in frames) {
      frame.image.dispose();
    }
  }
}

Future<Uint8List> _rgbaBytes(ui.Image image, int width, int height) async {
  if (image.width == width && image.height == height) {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw StateError('Failed to read RGBA frame');
    }
    return byteData.buffer.asUint8List();
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint(),
  );
  final picture = recorder.endRecording();
  final resized = await picture.toImage(width, height);
  picture.dispose();
  try {
    final byteData =
        await resized.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw StateError('Failed to resize RGBA frame');
    }
    return byteData.buffer.asUint8List();
  } finally {
    resized.dispose();
  }
}

/// Default MP4 Shadowplay / record capture (requires [screen_recorder] in the app).
class BugSessionDefaultVideoCapture
    implements BugSessionVideoCapture, BugSessionDeferrableVideoCapture {
  @override
  Future<void> start({required Duration maxDuration}) async {
    await bugSessionDefaultMp4Exporter.prepareForRecording();
    bugSessionScreenRecorderController.start();
  }

  @override
  Future<void> haltCapture() async {
    bugSessionScreenRecorderController.stop();
    bugSessionDefaultMp4Exporter.haltBuffering();
    await _yieldToUi();
  }

  @override
  Future<BugSessionVideoArtifact?> finalizeCapture() async {
    return bugSessionDefaultMp4Exporter.finishAsMp4Artifact();
  }

  @override
  Future<BugSessionVideoArtifact?> stop() async {
    await haltCapture();
    return finalizeCapture();
  }
}
