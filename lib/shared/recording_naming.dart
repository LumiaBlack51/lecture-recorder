import 'package:intl/intl.dart';

String sanitizeFileComponent(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return sanitized.isEmpty ? 'Course' : sanitized;
}

String buildRecordingFileName({
  required String courseName,
  required DateTime sessionStart,
  required int segmentIndex,
  required String extension,
}) {
  final safeCourse = sanitizeFileComponent(courseName);
  final dateCode = DateFormat('MMdd').format(sessionStart);
  final safeExtension = extension.startsWith('.')
      ? extension.substring(1)
      : extension;
  final index = segmentIndex.toString().padLeft(2, '0');
  return '${safeCourse}_${dateCode}_$index.$safeExtension';
}
