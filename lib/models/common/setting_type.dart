import 'package:PiliPlus/pages/setting/models/dm_settings.dart';
import 'package:PiliPlus/pages/setting/models/dyn_settings.dart';
import 'package:PiliPlus/pages/setting/models/extra_settings.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/models/play_settings.dart';
import 'package:PiliPlus/pages/setting/models/privacy_settings.dart';
import 'package:PiliPlus/pages/setting/models/recommend_settings.dart';
import 'package:PiliPlus/pages/setting/models/reply_settings.dart';
import 'package:PiliPlus/pages/setting/models/style_settings.dart';
import 'package:PiliPlus/pages/setting/models/video_settings.dart';

// 定制版：已移除 隐私设置 / 推荐流设置 / WebDAV 设置；已恢复「关于」（含自动更新）
enum SettingType {
  videoSetting('音视频设置'),
  playSetting('播放器设置'),
  dmSetting('弹幕设置'),
  replySetting('评论设置'),
  dynSetting('动态设置'),
  styleSetting('外观设置'),
  extraSetting('其它设置'),
  about('关于'),
  ;
  final String title;
  const SettingType(this.title);
  List<SettingsModel> get settings => switch (this) {
    .videoSetting => videoSettings,
    .playSetting => playSettings,
    .dmSetting => dmSettings,
    .dynSetting => dynSettings,
    .replySetting => replySettings,
    .styleSetting => styleSettings,
    .extraSetting => extraSettings,
    .webdavSetting || .about => throw UnimplementedError(),
  };
}
