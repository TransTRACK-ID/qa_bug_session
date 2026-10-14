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
      final hideRipples = kit != null &&
          kit.qaTesting.active &&
          kit.config.hideRecordingChromeDuringQaTest;
      final recordedChild = Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (kit != null && !hideRipples)
            BugSessionTapRippleOverlay(kit: kit),
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
  bool _encoding = false;
  final List<int> _frameWallMs = [];
  BuildContext? _context;

  void bindContext(BuildContext context) {
    _context = context;
  }

  Future<void> prepareForRecording() async {
    if (_encoding) {
      return;
    }
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
    if (_encoding) {
      return null;
    }
    _encoding = true;
    _capturing = false;

    if (frames.isEmpty) {
      _encoding = false;
      releaseFrameBuffer();
      return null;
    }

    final detached = List<Frame>.from(frames);
    frames.clear();
    _frameWallMs.clear();

    var maxWidth = 2;
    var maxHeight = 2;
    for (final frame in detached) {
      if (frame.image.width > maxWidth) {
        maxWidth = frame.image.width;
      }
      if (frame.image.height > maxHeight) {
        maxHeight = frame.image.height;
      }
    }
    maxWidth = _evenDimension(maxWidth);
    maxHeight = _evenDimension(maxHeight);

    final rgbaFrames = <Uint8List>[];
    try {
      for (final frame in detached) {
        await _yieldToUi();
        try {
          rgbaFrames.add(
            await _rgbaBytes(frame.image, maxWidth, maxHeight),
          );
        } on Object catch (e, st) {
          debugPrint('BugSession skip video frame: $e\n$st');
        } finally {
          frame.image.dispose();
        }
      }
    } finally {
      clear();
      _frameWallMs.clear();
    }

    if (rgbaFrames.isEmpty) {
      _encoding = false;
      return null;
    }

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

      for (final rgba in rgbaFrames) {
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
        width: maxWidth,
        height: maxHeight,
      );
    } on Object catch (e, st) {
      debugPrint('BugSession MP4 encode failed: $e\n$st');
      return null;
    } finally {
      _encoding = false;
      _capturing = false;
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

  /// Encodes buffered frames, clears the buffer, and resumes capture.
  Future<BugSessionVideoArtifact?> snapshotMp4AndContinue() async {
    final artifact = await finishAsMp4Artifact();
    await prepareForRecording();
    return artifact;
  }

  void _disposeBufferedImages() {
    for (final frame in frames) {
      frame.image.dispose();
    }
  }
}

Future<Uint8List> _rgbaBytes(ui.Image image, int width, int height) async {
  if (image.width <= 0 || image.height <= 0 || width < 2 || height < 2) {
    throw StateError('Invalid video frame size');
  }

  if (image.width == width && image.height == height) {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw StateError('Failed to read RGBA frame');
    }
    return byteData.buffer.asUint8List();
  }

  final srcW = image.width.toDouble();
  final srcH = image.height.toDouble();
  final dstW = width.toDouble();
  final dstH = height.toDouble();

  // Letterbox: scale to fit inside encoder dimensions (avoids invalid drawImageRect).
  final scale = (dstW / srcW) < (dstH / srcH) ? dstW / srcW : dstH / srcH;
  final drawW = (srcW * scale).floorToDouble();
  final drawH = (srcH * scale).floorToDouble();
  final offsetX = ((dstW - drawW) / 2).floorToDouble();
  final offsetY = ((dstH - drawH) / 2).floorToDouble();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..filterQuality = FilterQuality.medium;
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, srcW, srcH),
    Rect.fromLTWH(offsetX, offsetY, drawW, drawH),
    paint,
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

  @override
  Future<void> waitForMinimumFrames({
    int minimum = 1,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (bugSessionDefaultMp4Exporter.frames.length >= minimum) {
        return;
      }
      await _yieldToUi();
    }
  }
}
