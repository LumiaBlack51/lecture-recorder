import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as path;

import '../../../services/storage_service.dart';

class RecordingEntry {
  const RecordingEntry({
    required this.filePath,
    required this.fileName,
    required this.courseName,
    required this.modifiedAt,
    required this.sizeBytes,
    required this.segmentIndex,
  });

  final String filePath;
  final String fileName;
  final String courseName;
  final DateTime modifiedAt;
  final int sizeBytes;
  final int segmentIndex;
}

class RecordingsRepository {
  RecordingsRepository(this._storageService);

  final StorageService _storageService;

  Future<List<RecordingEntry>> loadRecordings() async {
    final root = await _storageService.ensureRecordingsRoot();
    if (!await root.exists()) {
      return const [];
    }

    final entries = <RecordingEntry>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final extension = path.extension(entity.path).toLowerCase();
      if (!{'.m4a', '.wav', '.aac', '.flac'}.contains(extension)) {
        continue;
      }

      final stat = await entity.stat();
      if (stat.size == 0) {
        continue;
      }
      final fileName = path.basename(entity.path);
      final courseName = path.basename(path.dirname(entity.path));
      final segmentMatch = RegExp(r'_(\d{2})\.[^.]+$').firstMatch(fileName);

      entries.add(
        RecordingEntry(
          filePath: entity.path,
          fileName: fileName,
          courseName: courseName,
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
          segmentIndex: int.tryParse(segmentMatch?.group(1) ?? '1') ?? 1,
        ),
      );
    }

    entries.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return entries;
  }

  Future<void> deleteRecording(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Duration?> loadDuration(String filePath) async {
    final player = AudioPlayer();
    try {
      await player.setSourceDeviceFile(filePath);
      return await player.getDuration();
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }
}
