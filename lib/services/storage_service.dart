import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../shared/recording_naming.dart';

class StorageService {
  static const _methodChannel = MethodChannel('lecture_recorder/platform');
  static const _androidSharedRecordingsPath =
      '/storage/emulated/0/Music/Recordings/Lecture Recorder';

  Future<Directory> ensureRecordingsRoot() async {
    final baseDirectory = await _resolveBaseDirectory();
    final recordingsDirectory = Directory(
      Platform.isAndroid
          ? baseDirectory.path
          : path.join(baseDirectory.path, 'recordings'),
    );
    if (!await recordingsDirectory.exists()) {
      await recordingsDirectory.create(recursive: true);
    }
    return recordingsDirectory;
  }

  Future<Directory> ensureCourseDirectory(String courseName) async {
    final root = await ensureRecordingsRoot();
    final courseDirectory = Directory(
      path.join(root.path, sanitizeFileComponent(courseName)),
    );
    if (!await courseDirectory.exists()) {
      await courseDirectory.create(recursive: true);
    }
    return courseDirectory;
  }

  Future<Directory> _resolveBaseDirectory() async {
    if (Platform.isAndroid) {
      try {
        final publicRoot = await _methodChannel.invokeMethod<String>(
          'getPublicRecordingsDirectory',
        );
        final resolvedPath = publicRoot?.isNotEmpty == true
            ? publicRoot!
            : _androidSharedRecordingsPath;
        await _methodChannel.invokeMethod<void>('migrateLegacyRecordings', {
          'publicRootPath': resolvedPath,
        });
        return Directory(resolvedPath);
      } on PlatformException {
        return Directory(_androidSharedRecordingsPath);
      }
    }
    return getApplicationDocumentsDirectory();
  }
}
