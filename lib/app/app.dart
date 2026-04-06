import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/recorder/presentation/home_screen.dart';
import '../features/settings/domain/app_settings.dart';
import '../generated/l10n/app_localizations.dart';
import 'app_theme.dart';
import 'providers.dart';

class LectureRecorderApp extends ConsumerWidget {
  const LectureRecorderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final locale = settingsState.maybeWhen(
      data: (settings) => settings.language.locale,
      orElse: () => null,
    );

    return MaterialApp(
      title: 'Lecture Recorder',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const HomeScreen(),
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
    );
  }
}
