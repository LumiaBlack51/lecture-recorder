import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../domain/app_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _androidMaxSizeController = TextEditingController();
  final _windowsSegmentMinutesController = TextEditingController();
  bool _didInitializeControllers = false;

  @override
  void dispose() {
    _androidMaxSizeController.dispose();
    _windowsSegmentMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final settingsState = ref.watch(settingsControllerProvider);
    final storagePathFuture = ref
        .watch(storageServiceProvider)
        .ensureRecordingsRoot();

    return PopScope(
      onPopInvokedWithResult: (_, _) => _persistPendingNumericValues(),
      child: Scaffold(
        appBar: AppBar(title: Text(localization.settingsTitle)),
        body: settingsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (settings) {
            _syncControllers(settings);
            final controller = ref.read(settingsControllerProvider.notifier);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: SwitchListTile(
                    value: settings.segmentationEnabled,
                    onChanged: controller.setSegmentationEnabled,
                    title: Text(localization.segmentationTitle),
                    subtitle: Text(localization.segmentationSubtitle),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.languageTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<AppLanguage>(
                          key: ValueKey(settings.language),
                          initialValue: settings.language,
                          items: [
                            DropdownMenuItem(
                              value: AppLanguage.system,
                              child: Text(localization.languageSystem),
                            ),
                            DropdownMenuItem(
                              value: AppLanguage.english,
                              child: Text(localization.languageEnglish),
                            ),
                            DropdownMenuItem(
                              value: AppLanguage.chinese,
                              child: Text(localization.languageChinese),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              controller.setLanguage(value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.audioQualityTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<AudioQualityPreset>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: AudioQualityPreset.low,
                              label: Text(localization.audioQualityLow),
                            ),
                            ButtonSegment(
                              value: AudioQualityPreset.standard,
                              label: Text(localization.audioQualityStandard),
                            ),
                            ButtonSegment(
                              value: AudioQualityPreset.high,
                              label: Text(localization.audioQualityHigh),
                            ),
                          ],
                          selected: {settings.audioQuality},
                          onSelectionChanged: (selection) {
                            controller.setAudioQuality(selection.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Platform.isAndroid
                              ? localization.androidSplitTitle
                              : localization.windowsSplitTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (Platform.isAndroid)
                          TextFormField(
                            controller: _androidMaxSizeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: localization.maxFileSizeLabel,
                              suffixText: 'MB',
                            ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null && parsed >= 1) {
                                controller.setAndroidMaxSizeMb(parsed);
                              }
                            },
                            onEditingComplete: _persistPendingNumericValues,
                            onTapOutside: (_) => _persistPendingNumericValues(),
                          ),
                        if (Platform.isWindows)
                          TextFormField(
                            controller: _windowsSegmentMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: localization.segmentMinutesLabel,
                              suffixText: localization.minutesShort,
                            ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null && parsed >= 1) {
                                controller.setWindowsSegmentMinutes(parsed);
                              }
                            },
                            onEditingComplete: _persistPendingNumericValues,
                            onTapOutside: (_) => _persistPendingNumericValues(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                localization.courseManagementTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showCourseDialog(
                                context: context,
                                title: localization.addCourseAction,
                                initialValue: '',
                                onSubmit: controller.addCourse,
                              ),
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...settings.courses.map(
                          (course) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(course),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _showCourseDialog(
                                    context: context,
                                    title: localization.editCourseAction,
                                    initialValue: course,
                                    onSubmit: (value) =>
                                        controller.updateCourse(
                                          previousName: course,
                                          nextName: value,
                                        ),
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  onPressed: settings.courses.length <= 1
                                      ? null
                                      : () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (dialogContext) {
                                                  return AlertDialog(
                                                    title: Text(
                                                      localization
                                                          .deleteCourseTitle,
                                                    ),
                                                    content: Text(
                                                      localization
                                                          .deleteCourseMessage(
                                                            course,
                                                          ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop(false),
                                                        child: Text(
                                                          localization
                                                              .cancelAction,
                                                        ),
                                                      ),
                                                      FilledButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop(true),
                                                        child: Text(
                                                          localization
                                                              .deleteAction,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ) ??
                                              false;
                                          if (confirmed) {
                                            controller.deleteCourse(course);
                                          }
                                        },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.storageDirectoryTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder(
                          future: storagePathFuture,
                          builder: (context, snapshot) {
                            return SelectableText(snapshot.data?.path ?? '...');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCourseDialog({
    required BuildContext context,
    required String title,
    required String initialValue,
    required Future<void> Function(String) onSubmit,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final localization = AppLocalizations.of(context)!;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: localization.courseNameLabel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(localization.cancelAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(localization.saveAction),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await onSubmit(controller.text);
    }
    controller.dispose();
  }

  void _syncControllers(AppSettings settings) {
    if (!_didInitializeControllers) {
      _androidMaxSizeController.text = settings.androidMaxSizeMb.toString();
      _windowsSegmentMinutesController.text = settings.windowsSegmentMinutes
          .toString();
      _didInitializeControllers = true;
      return;
    }

    if (!_androidMaxSizeController.selection.isValid &&
        _androidMaxSizeController.text !=
            settings.androidMaxSizeMb.toString()) {
      _androidMaxSizeController.text = settings.androidMaxSizeMb.toString();
    }
    if (!_windowsSegmentMinutesController.selection.isValid &&
        _windowsSegmentMinutesController.text !=
            settings.windowsSegmentMinutes.toString()) {
      _windowsSegmentMinutesController.text = settings.windowsSegmentMinutes
          .toString();
    }
  }

  void _persistPendingNumericValues() {
    final controller = ref.read(settingsControllerProvider.notifier);

    final androidValue = int.tryParse(_androidMaxSizeController.text);
    if (androidValue != null && androidValue >= 1) {
      controller.setAndroidMaxSizeMb(androidValue);
    }

    final windowsValue = int.tryParse(_windowsSegmentMinutesController.text);
    if (windowsValue != null && windowsValue >= 1) {
      controller.setWindowsSegmentMinutes(windowsValue);
    }
  }
}
