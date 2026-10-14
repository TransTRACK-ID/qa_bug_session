/// Notion **Screenshoot** section body for QA bug cards.
String formatQaIssueScreenshootSection({
  required String jamUrl,
  String? bugSessionZipUrl,
  bool bugSessionZipAttachedToPage = false,
}) {
  final lines = <String>['Jam recording: $jamUrl'];
  if (bugSessionZipUrl != null && bugSessionZipUrl.trim().isNotEmpty) {
    lines.add('BugSession replay (.zip): ${bugSessionZipUrl.trim()}');
    lines.add(
      'Devs: import the zip in Bug Session (panel → Import) and run Replay.',
    );
  } else if (bugSessionZipAttachedToPage) {
    lines.add(
      'BugSession replay (.zip): attached to this page (file block below).',
    );
    lines.add(
      'Devs: download the file, then Bug Session panel → Import zip → Replay.',
    );
  } else {
    lines.add(
      'BugSession replay (.zip): not attached (upload failed or zip too large).',
    );
  }
  return lines.join('\n');
}

String qaIssueReissueComment({
  required String jamUrl,
  required String screenshootSection,
}) {
  return 'New recording for this bug:\n\n$screenshootSection';
}
