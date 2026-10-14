import '../models/bug_session.dart';
import '../models/recorded_action.dart';
import 'bug_session_replay_auth.dart';

/// Options for normalizing Shadowplay clips and live replay action lists.
class BugSessionReplayActionFilterOptions {
  const BugSessionReplayActionFilterOptions({
    this.trimBeforeMainShell = false,
    this.dropOnboardingAndSplashNavigations = false,
    this.dedupeNavigationTapPairs = true,
    this.dedupeBackTapPairs = true,
    this.dedupeTaskRetapAfterBack = true,
    this.dedupeTapFollowedByBlocPushNavigation = true,
    this.navigationTapPairWindowMs = 1500,
    this.backTapPairWindowMs = 900,
    this.taskRetapAfterBackWindowMs = 3000,
    // Start/Continue → TaskReview often waits on API (>4s); keep nav dedupe loose.
    this.tapFollowedByBlocPushWindowMs = 15000,
  });

  /// When true, drops all actions before the first main-shell navigation
  /// ([NavbarRoute], [HomeRoute], [TaskRoute]) — use when replay bootstrap
  /// already lands on home with an existing session.
  final bool trimBeforeMainShell;

  /// One-time funnel routes that should not be replayed after first launch.
  final bool dropOnboardingAndSplashNavigations;

  final bool dedupeNavigationTapPairs;
  final bool dedupeBackTapPairs;

  /// Drops coordinate taps on task list that reopen detail right after [back].
  final bool dedupeTaskRetapAfterBack;

  /// Drops push navigations that duplicate a screen the previous tap already
  /// opens via bloc/listener (e.g. DetailTask Start → TaskReview).
  final bool dedupeTapFollowedByBlocPushNavigation;

  final int navigationTapPairWindowMs;
  final int backTapPairWindowMs;
  final int taskRetapAfterBackWindowMs;

  final int tapFollowedByBlocPushWindowMs;
}

const _mainShellRouteNames = {
  'NavbarRoute',
  'HomeRoute',
  'TaskRoute',
};

const _oneTimeFunnelRouteNames = {
  'OnboardingRoute',
  'SplashRoute',
};

/// Normalizes recorded actions before clip export or replay.
List<RecordedAction> bugSessionPrepareActionsForReplay(
  List<RecordedAction> actions, {
  BugSession? session,
  BugSessionReplayActionFilterOptions options =
      const BugSessionReplayActionFilterOptions(),
}) {
  var list = List<RecordedAction>.from(actions);
  if (options.dropOnboardingAndSplashNavigations) {
    list = list
        .where((a) => !_isNavigationToRoute(a, _oneTimeFunnelRouteNames))
        .toList();
  }
  if (options.trimBeforeMainShell) {
    final start = _indexFirstMainShellNavigation(list);
    if (start != null && start > 0) {
      list = list.sublist(start);
    }
  }
  if (options.dedupeNavigationTapPairs) {
    list = _dedupeNavigationFollowedByCoordinateTap(
      list,
      windowMs: options.navigationTapPairWindowMs,
    );
  }
  if (options.dedupeBackTapPairs) {
    list = _dedupeBackAffordanceTapFollowedByPop(
      list,
      windowMs: options.backTapPairWindowMs,
    );
  }
  if (options.dedupeTaskRetapAfterBack) {
    list = _dedupeTaskListTapAfterBack(
      list,
      windowMs: options.taskRetapAfterBackWindowMs,
    );
  }
  if (options.dedupeTapFollowedByBlocPushNavigation) {
    list = _dedupeTapFollowedByBlocPushNavigation(
      list,
      windowMs: options.tapFollowedByBlocPushWindowMs,
    );
  }
  return list;
}

int? _indexFirstMainShellNavigation(List<RecordedAction> actions) {
  for (var i = 0; i < actions.length; i++) {
    final name = bugSessionParseRouteName(actions[i].route);
    if (name != null && _mainShellRouteNames.contains(name)) {
      return i;
    }
  }
  return null;
}

bool _isNavigationToRoute(
  RecordedAction action,
  Set<String> routeNames,
) {
  if (action.type != RecordedActionType.navigation) {
    return false;
  }
  final name = bugSessionParseRouteName(action.route);
  return name != null && routeNames.contains(name);
}

bool _isSessionStartNavigation(RecordedAction action) {
  if (action.type != RecordedActionType.navigation) {
    return false;
  }
  final route = action.route ?? '';
  return route.contains('session_start');
}

bool _isCoordinateOnlyTap(RecordedAction action) {
  if (action.type != RecordedActionType.tap) {
    return false;
  }
  final recorderId = action.metadata['recorderId'];
  if (recorderId is String && recorderId.isNotEmpty) {
    return false;
  }
  return true;
}

bool _isPushNavigation(RecordedAction action) {
  if (action.type != RecordedActionType.navigation ||
      _isSessionStartNavigation(action)) {
    return false;
  }
  final name = bugSessionParseRouteName(action.route);
  if (name == null || name.isEmpty) {
    return false;
  }
  if (_mainShellRouteNames.contains(name)) {
    return false;
  }
  return true;
}

List<RecordedAction> _dedupeNavigationFollowedByCoordinateTap(
  List<RecordedAction> actions, {
  required int windowMs,
}) {
  if (actions.length < 2) {
    return actions;
  }
  final out = <RecordedAction>[];
  for (var i = 0; i < actions.length; i++) {
    final current = actions[i];
    if (i + 1 < actions.length &&
        _isPushNavigation(current) &&
        _isCoordinateOnlyTap(actions[i + 1]) &&
        actions[i + 1].timestampMs - current.timestampMs <= windowMs) {
      out.add(current);
      i++;
      continue;
    }
    out.add(current);
  }
  return out;
}

bool _isBackAffordanceTap(RecordedAction action) {
  if (action.type != RecordedActionType.tap) {
    return false;
  }
  final semantics = action.metadata['semanticsLabel'];
  if (semantics == 'Back') {
    return true;
  }
  final target = action.target;
  if (target != null && target.endsWith('/Back')) {
    return true;
  }
  return false;
}

List<RecordedAction> _dedupeBackAffordanceTapFollowedByPop(
  List<RecordedAction> actions, {
  required int windowMs,
}) {
  if (actions.length < 2) {
    return actions;
  }
  final out = <RecordedAction>[];
  for (var i = 0; i < actions.length; i++) {
    final current = actions[i];
    if (i + 1 < actions.length &&
        _isBackAffordanceTap(current) &&
        actions[i + 1].type == RecordedActionType.back &&
        actions[i + 1].timestampMs - current.timestampMs <= windowMs) {
      out.add(actions[i + 1]);
      i++;
      continue;
    }
    out.add(current);
  }
  return out;
}

List<RecordedAction> _dedupeTaskListTapAfterBack(
  List<RecordedAction> actions, {
  required int windowMs,
}) {
  if (actions.length < 2) {
    return actions;
  }
  final out = <RecordedAction>[];
  for (var i = 0; i < actions.length; i++) {
    final current = actions[i];
    if (i + 1 < actions.length &&
        current.type == RecordedActionType.back &&
        _isCoordinateOnlyTap(actions[i + 1]) &&
        _isTaskListRetap(actions[i + 1]) &&
        actions[i + 1].timestampMs - current.timestampMs <= windowMs) {
      out.add(current);
      i++;
      continue;
    }
    out.add(current);
  }
  return out;
}

bool _isTaskListRetap(RecordedAction action) {
  final target = action.target;
  if (target == null) {
    return false;
  }
  return target.startsWith('TaskRoute/') ||
      target.startsWith('HomeRoute/');
}

const _blocDrivenChildRouteNames = {
  'TaskReviewRoute',
  'TaskCompletionRoute',
};

bool _isBlocDrivenChildPush(RecordedAction action) {
  if (!_isPushNavigation(action)) {
    return false;
  }
  final name = bugSessionParseRouteName(action.route);
  return name != null && _blocDrivenChildRouteNames.contains(name);
}

List<RecordedAction> _dedupeTapFollowedByBlocPushNavigation(
  List<RecordedAction> actions, {
  required int windowMs,
}) {
  if (actions.length < 2) {
    return actions;
  }
  final out = <RecordedAction>[];
  for (var i = 0; i < actions.length; i++) {
    final current = actions[i];
    if (i + 1 < actions.length &&
        current.type == RecordedActionType.tap &&
        _isBlocDrivenChildPush(actions[i + 1]) &&
        actions[i + 1].timestampMs - current.timestampMs <= windowMs) {
      out.add(current);
      i++;
      continue;
    }
    out.add(current);
  }
  return out;
}
