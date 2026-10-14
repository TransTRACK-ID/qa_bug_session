import 'package:flutter/foundation.dart';

import 'bug_session_config.dart';
import '../ui/bug_session_flash.dart';

typedef BugSessionWorkSubProgressReporter = void Function(double progress);

/// One step in a weighted background pipeline.
class BugSessionWorkPhase {
  const BugSessionWorkPhase({
    required this.label,
    required this.weight,
    required this.run,
  });

  final String label;
  final double weight;
  final Future<void> Function(BugSessionWorkSubProgressReporter reportSubProgress)
      run;
}

/// Computes overall progress from phase weights and sub-progress.
double bugSessionWeightedProgress({
  required List<BugSessionWorkPhase> phases,
  required int stepIndex,
  required double stepProgress,
}) {
  if (phases.isEmpty) {
    return stepProgress.clamp(0.0, 1.0);
  }
  final totalWeight = phases.fold<double>(0, (sum, p) => sum + p.weight);
  if (totalWeight <= 0) {
    return stepProgress.clamp(0.0, 1.0);
  }
  var completed = 0.0;
  for (var i = 0; i < stepIndex && i < phases.length; i++) {
    completed += phases[i].weight;
  }
  if (stepIndex >= 0 && stepIndex < phases.length) {
    completed += phases[stepIndex].weight * stepProgress.clamp(0.0, 1.0);
  }
  return (completed / totalWeight).clamp(0.0, 1.0);
}

class BugSessionBackgroundWorkBusyException implements Exception {
  BugSessionBackgroundWorkBusyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Kit-wide single-flight background work + progress for the top banner.
class BugSessionBackgroundWorkController extends ChangeNotifier {
  bool _active = false;
  String _label = '';
  double _progress = 0;
  List<BugSessionWorkPhase> _phases = const [];
  int _stepIndex = 0;

  bool get active => _active;
  String get label => _label;
  double get progress => _progress;

  void _finish({required bool success}) {
    _active = false;
    _label = '';
    _progress = success ? 1 : 0;
    _phases = const [];
    _stepIndex = 0;
    notifyListeners();
    if (!success) {
      _progress = 0;
      notifyListeners();
    }
  }

  void reportStep(
    int stepIndex, {
    String? label,
    double stepProgress = 0,
  }) {
    if (!_active) {
      return;
    }
    _stepIndex = stepIndex;
    if (label != null) {
      _label = label;
    }
    _progress = bugSessionWeightedProgress(
      phases: _phases,
      stepIndex: stepIndex,
      stepProgress: stepProgress,
    );
    notifyListeners();
  }

  /// Runs [phases] sequentially; rejects if another task is active.
  Future<void> run({
    required BugSessionConfig config,
    required String title,
    required List<BugSessionWorkPhase> phases,
    String? startToast,
    String? successToast,
    String? errorToastPrefix,
  }) async {
    if (_active) {
      const message = 'Another background task is already running';
      BugSessionTaskToasts.notifyError(config, message);
      throw BugSessionBackgroundWorkBusyException(message);
    }

    if (startToast != null && startToast.isNotEmpty) {
      BugSessionTaskToasts.notifyStarted(config, startToast);
    }

    _active = true;
    _label = title;
    _progress = 0;
    _phases = phases;
    _stepIndex = 0;
    notifyListeners();

    try {
      for (var i = 0; i < phases.length; i++) {
        final phase = phases[i];
        reportStep(i, label: phase.label, stepProgress: 0);
        await phase.run((sub) {
          reportStep(i, label: phase.label, stepProgress: sub);
        });
        reportStep(i, label: phase.label, stepProgress: 1);
      }

      _finish(success: true);

      if (successToast != null && successToast.isNotEmpty) {
        BugSessionTaskToasts.notifySuccess(config, successToast);
      }
    } catch (e, st) {
      _finish(success: false);
      final prefix = errorToastPrefix ?? 'Task failed';
      BugSessionTaskToasts.notifyError(config, '$prefix: $e');
      if (kDebugMode) {
        debugPrint('BugSessionBackgroundWork: $st');
      }
      rethrow;
    }
  }
}

class BugSessionTaskToasts {
  BugSessionTaskToasts._();

  static void notifyStarted(BugSessionConfig config, String message) {
    BugSessionFlash.showTopFlash(
      config,
      message: message,
      duration: const Duration(seconds: 2),
    );
  }

  static void notifySuccess(BugSessionConfig config, String message) {
    BugSessionFlash.showTopFlash(config, message: message);
  }

  static void notifyError(BugSessionConfig config, String message) {
    BugSessionFlash.showTopFlash(config, message: message, isError: true);
  }
}
