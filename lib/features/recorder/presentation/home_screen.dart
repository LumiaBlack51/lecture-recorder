import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/providers.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../../shared/formatters.dart';
import '../../recordings/presentation/recordings_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/recorder_models.dart';
import 'recording_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static const _platformChannel = MethodChannel('lecture_recorder/platform');

  bool _isRequestingStartupPermissions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestStartupPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestStartupPermissions();
    }
  }

  Future<void> _requestStartupPermissions() async {
    if (!Platform.isAndroid || _isRequestingStartupPermissions) {
      return;
    }

    _isRequestingStartupPermissions = true;
    try {
      if (!await Permission.manageExternalStorage.isGranted) {
        await _platformChannel.invokeMethod<void>('openManageAllFilesAccess');
        return;
      }

      if (!await Permission.systemAlertWindow.isGranted) {
        await _platformChannel.invokeMethod<void>(
          'openOverlayPermissionAccess',
        );
        return;
      }

      await Permission.audio.request();
      await Permission.notification.request();
    } finally {
      _isRequestingStartupPermissions = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    ref.listen<RecordingUiState>(recordingControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
        ref.read(recordingControllerProvider.notifier).clearError();
      }
    });

    final localization = AppLocalizations.of(context)!;
    final settingsState = ref.watch(settingsControllerProvider);
    final recordingState = ref.watch(recordingControllerProvider);

    return PopScope(
      canPop: !recordingState.isRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !recordingState.isRecording) {
          return;
        }

        final shouldExit =
            await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title: Text(localization.exitWhileRecordingTitle),
                  content: Text(localization.exitWhileRecordingMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(localization.cancelAction),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(localization.exitAction),
                    ),
                  ],
                );
              },
            ) ??
            false;

        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: settingsState.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) =>
            Scaffold(body: Center(child: Text(error.toString()))),
        data: (settings) {
          return Scaffold(
            appBar: AppBar(
              title: Text(localization.appTitle),
              actions: [
                IconButton(
                  tooltip: localization.recordingsTitle,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecordingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.library_music_outlined),
                ),
                IconButton(
                  tooltip: localization.settingsTitle,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF6F1E7),
                    Color(0xFFF1F7F3),
                    Color(0xFFEAF3F2),
                  ],
                ),
              ),
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _RecordingSummaryCard(state: recordingState),
                    const SizedBox(height: 18),
                    ...settings.courses.map(
                      (courseName) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CourseButton(
                          label: courseName,
                          isActive:
                              recordingState.courseName == courseName &&
                              recordingState.isRecording,
                          onPressed: () async {
                            if (recordingState.isBusy) {
                              return;
                            }

                            final controller = ref.read(
                              recordingControllerProvider.notifier,
                            );
                            if (!recordingState.isRecording) {
                              await controller.startRecording(courseName);
                              return;
                            }

                            if (recordingState.courseName == courseName) {
                              return;
                            }

                            final shouldSwitch =
                                await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      title: Text(
                                        localization.switchCourseTitle,
                                      ),
                                      content: Text(
                                        localization.switchCourseMessage(
                                          recordingState.courseName ?? '',
                                          courseName,
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
                                            localization.switchAction,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ) ??
                                false;

                            if (!shouldSwitch) {
                              return;
                            }

                            await controller.stopRecording();
                            await controller.startRecording(courseName);
                          },
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                recordingState.isRecording &&
                                    !recordingState.isBusy
                                ? () => ref
                                      .read(
                                        recordingControllerProvider.notifier,
                                      )
                                      .stopRecording()
                                : null,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: Text(localization.stopAction),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                recordingState.canPauseResume &&
                                    recordingState.isRecording &&
                                    !recordingState.isBusy
                                ? () => ref
                                      .read(
                                        recordingControllerProvider.notifier,
                                      )
                                      .pauseOrResume()
                                : null,
                            icon: Icon(
                              recordingState.status == RecordingStatus.paused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_circle_outline_rounded,
                            ),
                            label: Text(
                              recordingState.status == RecordingStatus.paused
                                  ? localization.resumeAction
                                  : localization.pauseAction,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (Platform.isAndroid) ...[
                      const SizedBox(height: 12),
                      Text(
                        localization.androidStorageHint,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecordingSummaryCard extends StatelessWidget {
  const _RecordingSummaryCard({required this.state});

  final RecordingUiState state;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final statusLabel = switch (state.status) {
      RecordingStatus.idle => localization.statusIdle,
      RecordingStatus.starting => localization.statusStarting,
      RecordingStatus.recording => localization.statusRecording,
      RecordingStatus.paused => localization.statusPaused,
      RecordingStatus.stopping => localization.statusStopping,
      RecordingStatus.error => localization.statusError,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.status == RecordingStatus.recording
                        ? Colors.redAccent
                        : theme.colorScheme.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (state.status == RecordingStatus.recording
                                    ? Colors.redAccent
                                    : theme.colorScheme.primaryContainer)
                                .withValues(alpha: 0.6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  statusLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoChip(
                  label: localization.currentCourseLabel,
                  value: state.courseName ?? localization.notRecordingValue,
                ),
                _InfoChip(
                  label: localization.elapsedLabel,
                  value: formatElapsed(state.elapsed),
                ),
                _InfoChip(
                  label: localization.segmentLabel,
                  value: state.currentSegmentIndex > 0
                      ? state.currentSegmentIndex.toString().padLeft(2, '0')
                      : '--',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CourseButton extends StatelessWidget {
  const _CourseButton({
    required this.label,
    required this.onPressed,
    required this.isActive,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isActive ? scheme.primaryContainer : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Row(
            children: [
              Icon(
                isActive
                    ? Icons.mic_rounded
                    : Icons.play_circle_outline_rounded,
                color: isActive ? scheme.onPrimaryContainer : scheme.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
