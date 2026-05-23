import 'package:flutter/widgets.dart';

abstract class AppLocalizations {
  AppLocalizations(this.localeName);

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = <Locale>[Locale('en'), Locale('zh')];

  String get appTitle;
  String get recordingsTitle;
  String get settingsTitle;
  String get exitWhileRecordingTitle;
  String get exitWhileRecordingMessage;
  String get cancelAction;
  String get exitAction;
  String get switchCourseTitle;
  String switchCourseMessage(String currentCourse, String nextCourse);
  String get switchAction;
  String get stopAction;
  String get resumeAction;
  String get pauseAction;
  String get androidStorageHint;
  String get statusIdle;
  String get statusStarting;
  String get statusRecording;
  String get statusPaused;
  String get statusStopping;
  String get statusError;
  String get currentCourseLabel;
  String get notRecordingValue;
  String get elapsedLabel;
  String get segmentLabel;
  String get segmentationTitle;
  String get segmentationSubtitle;
  String get languageTitle;
  String get languageSystem;
  String get languageEnglish;
  String get languageChinese;
  String get audioQualityTitle;
  String get audioQualityLow;
  String get audioQualityStandard;
  String get audioQualityHigh;
  String get androidSplitTitle;
  String get windowsSplitTitle;
  String get maxFileSizeLabel;
  String get segmentMinutesLabel;
  String get minutesShort;
  String get courseManagementTitle;
  String get addCourseAction;
  String get editCourseAction;
  String get deleteCourseTitle;
  String deleteCourseMessage(String courseName);
  String get deleteAction;
  String get storageDirectoryTitle;
  String get courseNameLabel;
  String get saveAction;
  String get recordingsEmptyState;
  String get refreshAction;
  String get groupByDay;
  String get groupByCourse;
  String get playAction;
  String get shareAction;
  String get openLocationAction;
  String get deleteRecordingTitle;
  String deleteRecordingMessage(String fileName);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return switch (locale.languageCode) {
      'zh' => AppLocalizationsZh(),
      _ => AppLocalizationsEn(),
    };
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn() : super('en');

  @override
  String get appTitle => 'Lecture Recorder';
  @override
  String get recordingsTitle => 'Recordings';
  @override
  String get settingsTitle => 'Settings';
  @override
  String get exitWhileRecordingTitle => 'Recording in progress';
  @override
  String get exitWhileRecordingMessage =>
      'A recording is still running. Exit the app anyway?';
  @override
  String get cancelAction => 'Cancel';
  @override
  String get exitAction => 'Exit';
  @override
  String get switchCourseTitle => 'Switch course?';
  @override
  String switchCourseMessage(String currentCourse, String nextCourse) =>
      'Stop recording $currentCourse and start $nextCourse instead?';
  @override
  String get switchAction => 'Switch';
  @override
  String get stopAction => 'Stop';
  @override
  String get resumeAction => 'Resume';
  @override
  String get pauseAction => 'Pause';
  @override
  String get androidStorageHint =>
      'Android recordings are saved to Music/Recordings/Lecture Recorder so Files and audio pickers can find them.';
  @override
  String get statusIdle => 'Ready';
  @override
  String get statusStarting => 'Starting';
  @override
  String get statusRecording => 'Recording';
  @override
  String get statusPaused => 'Paused';
  @override
  String get statusStopping => 'Stopping';
  @override
  String get statusError => 'Needs attention';
  @override
  String get currentCourseLabel => 'Current course';
  @override
  String get notRecordingValue => 'Not recording';
  @override
  String get elapsedLabel => 'Elapsed';
  @override
  String get segmentLabel => 'Segment';
  @override
  String get segmentationTitle => 'Automatic segmentation';
  @override
  String get segmentationSubtitle => 'Split long recordings automatically.';
  @override
  String get languageTitle => 'Language';
  @override
  String get languageSystem => 'Follow system';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageChinese => 'Chinese';
  @override
  String get audioQualityTitle => 'Audio quality';
  @override
  String get audioQualityLow => 'Low';
  @override
  String get audioQualityStandard => 'Standard';
  @override
  String get audioQualityHigh => 'High';
  @override
  String get androidSplitTitle => 'Android split by file size';
  @override
  String get windowsSplitTitle => 'Desktop split by duration';
  @override
  String get maxFileSizeLabel => 'Maximum file size';
  @override
  String get segmentMinutesLabel => 'Segment duration';
  @override
  String get minutesShort => 'min';
  @override
  String get courseManagementTitle => 'Courses';
  @override
  String get addCourseAction => 'Add course';
  @override
  String get editCourseAction => 'Edit course';
  @override
  String get deleteCourseTitle => 'Delete course?';
  @override
  String deleteCourseMessage(String courseName) =>
      'Remove $courseName from the home screen? Existing recordings will stay on disk.';
  @override
  String get deleteAction => 'Delete';
  @override
  String get storageDirectoryTitle => 'Storage directory';
  @override
  String get courseNameLabel => 'Course name';
  @override
  String get saveAction => 'Save';
  @override
  String get recordingsEmptyState => 'No recordings yet.';
  @override
  String get refreshAction => 'Refresh';
  @override
  String get groupByDay => 'By day';
  @override
  String get groupByCourse => 'By course';
  @override
  String get playAction => 'Play';
  @override
  String get shareAction => 'Share';
  @override
  String get openLocationAction => 'Open location';
  @override
  String get deleteRecordingTitle => 'Delete recording?';
  @override
  String deleteRecordingMessage(String fileName) =>
      'Delete $fileName permanently?';
}

class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh() : super('zh');

  @override
  String get appTitle => '课堂录音';
  @override
  String get recordingsTitle => '录音列表';
  @override
  String get settingsTitle => '设置';
  @override
  String get exitWhileRecordingTitle => '正在录音';
  @override
  String get exitWhileRecordingMessage => '当前录音尚未结束，仍要退出应用吗？';
  @override
  String get cancelAction => '取消';
  @override
  String get exitAction => '退出';
  @override
  String get switchCourseTitle => '切换课程？';
  @override
  String switchCourseMessage(String currentCourse, String nextCourse) =>
      '停止录制$currentCourse，并开始录制$nextCourse吗？';
  @override
  String get switchAction => '切换';
  @override
  String get stopAction => '停止';
  @override
  String get resumeAction => '继续';
  @override
  String get pauseAction => '暂停';
  @override
  String get androidStorageHint =>
      'Android 录音会保存到 Music/Recordings/Lecture Recorder，文件管理器和音频选择器都能找到。';
  @override
  String get statusIdle => '待命';
  @override
  String get statusStarting => '开始中';
  @override
  String get statusRecording => '录音中';
  @override
  String get statusPaused => '已暂停';
  @override
  String get statusStopping => '停止中';
  @override
  String get statusError => '需要处理';
  @override
  String get currentCourseLabel => '当前课程';
  @override
  String get notRecordingValue => '未录音';
  @override
  String get elapsedLabel => '已录时长';
  @override
  String get segmentLabel => '分段';
  @override
  String get segmentationTitle => '自动分段';
  @override
  String get segmentationSubtitle => '自动拆分较长的录音文件。';
  @override
  String get languageTitle => '语言';
  @override
  String get languageSystem => '跟随系统';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageChinese => '中文';
  @override
  String get audioQualityTitle => '音质';
  @override
  String get audioQualityLow => '低';
  @override
  String get audioQualityStandard => '标准';
  @override
  String get audioQualityHigh => '高';
  @override
  String get androidSplitTitle => 'Android 按文件大小分段';
  @override
  String get windowsSplitTitle => '桌面端按时长分段';
  @override
  String get maxFileSizeLabel => '最大文件大小';
  @override
  String get segmentMinutesLabel => '分段时长';
  @override
  String get minutesShort => '分钟';
  @override
  String get courseManagementTitle => '课程管理';
  @override
  String get addCourseAction => '添加课程';
  @override
  String get editCourseAction => '编辑课程';
  @override
  String get deleteCourseTitle => '删除课程？';
  @override
  String deleteCourseMessage(String courseName) =>
      '将$courseName从主页移除？已有录音不会被删除。';
  @override
  String get deleteAction => '删除';
  @override
  String get storageDirectoryTitle => '存储目录';
  @override
  String get courseNameLabel => '课程名称';
  @override
  String get saveAction => '保存';
  @override
  String get recordingsEmptyState => '还没有录音文件。';
  @override
  String get refreshAction => '刷新';
  @override
  String get groupByDay => '按日期';
  @override
  String get groupByCourse => '按课程';
  @override
  String get playAction => '播放';
  @override
  String get shareAction => '分享';
  @override
  String get openLocationAction => '打开位置';
  @override
  String get deleteRecordingTitle => '删除录音？';
  @override
  String deleteRecordingMessage(String fileName) => '确定永久删除$fileName吗？';
}
