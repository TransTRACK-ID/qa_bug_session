import 'dart:convert';

import '../models/bug_session.dart';
import '../models/recorded_action.dart';

/// True when replay should logout and start from login (opening or any login nav).
bool bugSessionSessionIncludesAuthentication(BugSession session) {
  if (_authInOpeningActions(session)) {
    return true;
  }
  for (final action in session.actions) {
    if (action.type != RecordedActionType.navigation) {
      continue;
    }
    final route = action.route ?? action.target ?? '';
    if (_looksLikeAuthRoute(route) ||
        _isAuthRouteName(bugSessionParseRouteName(route))) {
      return true;
    }
  }
  return false;
}

const _authRouteNames = {
  'LoginRoute',
  'ForgotPasswordRoute',
  'ResetPasswordRoute',
  'ResetPasswordSuccessRoute',
  'ResetPasswordExpiredRoute',
  'OnboardingRoute',
  'SplashRoute',
};

bool _authInOpeningActions(BugSession session) {
  const window = 15;
  var seen = 0;
  for (final action in session.actions) {
    if (seen >= window) {
      break;
    }
    seen++;
    if (action.type == RecordedActionType.navigation) {
      final name = bugSessionParseRouteName(action.route);
      if (name == 'NavbarRoute' ||
          name == 'HomeRoute' ||
          name == 'TaskRoute') {
        return false;
      }
      if (_isAuthRouteName(name) ||
          _looksLikeAuthRoute(action.route ?? '')) {
        return true;
      }
    }
    if (action.type == RecordedActionType.tap) {
      final target = action.target ?? '';
      if (_isAuthTapTarget(target)) {
        return true;
      }
      if (target.startsWith('NavbarRoute') ||
          target.startsWith('TaskRoute') ||
          target.startsWith('HomeRoute')) {
        return false;
      }
    }
  }
  return false;
}

bool _isAuthRouteName(String? name) {
  if (name == null || name.isEmpty) {
    return false;
  }
  return _authRouteNames.contains(name);
}

bool _isAuthTapTarget(String target) {
  if (target.startsWith('LoginRoute') ||
      target.startsWith('ForgotPasswordRoute') ||
      target.startsWith('ResetPasswordRoute') ||
      target.startsWith('OnboardingRoute')) {
    return true;
  }
  return _looksLikeAuthRoute(target);
}

bool _looksLikeAuthRoute(String route) {
  final lower = route.toLowerCase();
  return lower.contains('login') ||
      lower.contains('signin') ||
      lower.contains('sign_in') ||
      lower.contains('authenticate') ||
      lower.contains('authroute') ||
      lower.contains('forgotpassword') ||
      lower == 'auth';
}

/// Parses route name from BugSession navigation JSON or plain route label.
String? bugSessionParseRouteName(String? payload) {
  if (payload == null || payload.isEmpty) {
    return null;
  }
  final trimmed = payload.trim();
  if (!trimmed.startsWith('{')) {
    return trimmed.contains('Route') ? trimmed : null;
  }
  try {
    final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
    return decoded['name'] as String?;
  } catch (_) {
    return null;
  }
}
