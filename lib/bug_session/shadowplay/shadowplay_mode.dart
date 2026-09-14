/// What the rolling buffer records (Shadowplay plan §2–3).
enum BugSessionShadowplayMode {
  /// Every tap, text input, navigation, back (UI / scroll investigations).
  raw,

  /// Navigation, back, taps, text — no extra raw gesture types yet.
  semantic,
}
