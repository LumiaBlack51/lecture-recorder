import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../../shared/formatters.dart';
import '../data/recordings_repository.dart';

enum RecordingGroupMode { day, course }

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  final AudioPlayer _player = AudioPlayer();
  RecordingGroupMode _groupMode = RecordingGroupMode.day;
  String? _playingPath;

  @override
  void initState() {
    super.initState();
    _requestAndroidMediaAccess();
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingPath = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _requestAndroidMediaAccess() async {
    if (!Platform.isAndroid) {
      return;
    }

    await Permission.audio.request();
    await Permission.storage.request();
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final recordingsAsync = ref.watch(recordingsProvider);
    final platformFileService = ref.watch(platformFileServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.recordingsTitle),
        actions: [
          IconButton(
            tooltip: localization.refreshAction,
            onPressed: () {
              ref.read(recordingsRefreshProvider.notifier).state++;
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: recordingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(localization.recordingsEmptyState));
          }

          final groups = _buildGroups(items);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<RecordingGroupMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: RecordingGroupMode.day,
                    label: Text(localization.groupByDay),
                  ),
                  ButtonSegment(
                    value: RecordingGroupMode.course,
                    label: Text(localization.groupByCourse),
                  ),
                ],
                selected: {_groupMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _groupMode = selection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              ...groups.entries.map(
                (entry) => Card(
                  child: ExpansionTile(
                    title: Text(entry.key),
                    children: entry.value.map((item) {
                      final durationAsync = ref.watch(
                        recordingDurationProvider(item.filePath),
                      );
                      final isPlaying = _playingPath == item.filePath;
                      return ListTile(
                        title: Text(item.fileName),
                        subtitle: Text(
                          '${item.courseName} • ${formatDateTime(item.modifiedAt)} • ${formatFileSize(item.sizeBytes)} • ${durationAsync.maybeWhen(data: formatDurationLabel, orElse: () => '--:--')}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: isPlaying
                                  ? localization.pauseAction
                                  : localization.playAction,
                              onPressed: () => _togglePlayback(item.filePath),
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_circle_outline_rounded
                                    : Icons.play_circle_outline_rounded,
                              ),
                            ),
                            if (platformFileService.supportsOpenLocation)
                              IconButton(
                                tooltip: localization.openLocationAction,
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    await platformFileService.openLocation(
                                      item.filePath,
                                    );
                                  } catch (error) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.folder_open_outlined),
                              ),
                            IconButton(
                              tooltip: localization.deleteAction,
                              onPressed: () async {
                                final confirmed =
                                    await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) {
                                        return AlertDialog(
                                          title: Text(
                                            localization.deleteRecordingTitle,
                                          ),
                                          content: Text(
                                            localization.deleteRecordingMessage(
                                              item.fileName,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                dialogContext,
                                              ).pop(false),
                                              child: Text(
                                                localization.cancelAction,
                                              ),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(
                                                dialogContext,
                                              ).pop(true),
                                              child: Text(
                                                localization.deleteAction,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ) ??
                                    false;

                                if (!confirmed) {
                                  return;
                                }

                                final repository = ref.read(
                                  recordingsRepositoryProvider,
                                );
                                await repository.deleteRecording(item.filePath);
                                ref
                                    .read(recordingsRefreshProvider.notifier)
                                    .state++;
                              },
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                            IconButton(
                              tooltip: localization.shareAction,
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await SharePlus.instance.share(
                                    ShareParams(
                                      files: [XFile(item.filePath)],
                                      text: item.fileName,
                                    ),
                                  );
                                } catch (error) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              },
                              icon: const Icon(Icons.share_outlined),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<RecordingEntry>> _buildGroups(List<RecordingEntry> items) {
    final groups = <String, List<RecordingEntry>>{};
    for (final item in items) {
      final key = _groupMode == RecordingGroupMode.day
          ? formatDateLabel(item.modifiedAt)
          : item.courseName;
      groups.putIfAbsent(key, () => <RecordingEntry>[]).add(item);
    }
    return groups;
  }

  Future<void> _togglePlayback(String filePath) async {
    if (_playingPath == filePath) {
      await _player.pause();
      setState(() {
        _playingPath = null;
      });
      return;
    }

    await _player.stop();
    await _player.play(DeviceFileSource(filePath));
    setState(() {
      _playingPath = filePath;
    });
  }
}
