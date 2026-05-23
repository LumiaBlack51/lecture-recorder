import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class PlatformFileService {
  static const _methodChannel = MethodChannel('lecture_recorder/platform');

  bool get supportsOpenLocation =>
      Platform.isWindows || Platform.isLinux || Platform.isAndroid;

  Future<void> openLocation(String filePath) async {
    if (Platform.isWindows) {
      await _openWindowsLocation(filePath);
      return;
    }

    if (Platform.isLinux) {
      await _openLinuxLocation(filePath);
      return;
    }

    if (Platform.isAndroid) {
      await _methodChannel.invokeMethod<void>('openLocation', {
        'filePath': filePath,
      });
      return;
    }

    throw UnsupportedError('Opening file location is not supported.');
  }

  Future<void> _openWindowsLocation(String filePath) async {
    final targetDirectory = await _resolveDirectory(filePath);
    final normalizedPath = targetDirectory.replaceAll('/', '\\');
    final result = await Process.run('explorer.exe', [normalizedPath]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'explorer.exe',
        [normalizedPath],
        result.stderr.toString(),
        result.exitCode,
      );
    }
  }

  Future<void> _openLinuxLocation(String filePath) async {
    final targetDirectory = await _resolveDirectory(filePath);
    final result = await Process.run('xdg-open', [targetDirectory]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'xdg-open',
        [targetDirectory],
        result.stderr.toString(),
        result.exitCode,
      );
    }
  }

  Future<String> _resolveDirectory(String filePath) async {
    final type = FileSystemEntity.typeSync(filePath);
    if (type == FileSystemEntityType.directory) {
      return filePath;
    }
    return path.dirname(filePath);
  }
}
