import 'dart:io' show Platform;

import 'package:PiliPlus/build_config.dart';
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

abstract final class Update {
  // 定制版：GitHub 下载加速镜像前缀（把 https://github.com/... 套在前缀之后即可加速）。
  // 站点参考 https://www.moretools.app/zh-CN/github-proxy ；镜像仅反代公开仓库下载，无鉴权问题。
  // 若主镜像失效，可在此调整/增补（按顺序取第一个可用者）。
  static const List<String> _ghMirrors = [
    'https://gh-proxy.net/',
    'https://github.cnxiaobai.com/',
    'https://hub.gitmirror.com/',
  ];

  // 定制版：把 GitHub 下载链接转换为加速镜像链接；非 GitHub 链接原样返回
  static String _accelerate(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('https://github.com/') ||
        url.startsWith('http://github.com/')) {
      return '${_ghMirrors.first}$url';
    }
    return url;
  }

  // 检查更新
  static Future<void> checkUpdate([bool isAuto = true]) async {
    if (kDebugMode) return;
    SmartDialog.dismiss();
    try {
      final res = await Request().get(
        Api.latestApp,
        options: Options(
          headers: {'user-agent': BrowserUa.mob},
          extra: {'account': const NoAccount()},
        ),
      );
      if (res.data is Map || res.data.isEmpty) {
        if (!isAuto) {
          SmartDialog.showToast('检查更新失败，GitHub接口未返回数据，请检查网络');
        }
        return;
      }
      final List<dynamic> releaseList = res.data as List;
      final data = releaseList[0];
      // 定制版：用「公开 tag 列表」精确判定是否有更新版本，而不是简单地「与本机 tag 不相等」。
      // 1) 公开列表首条 == 本机 tag        → 已是最新（不提示）
      // 2) 本机 tag 在公开列表里但非首条   → 确有更新版本（提示）
      // 3) 本机 tag 不在公开列表（draft/未发布/本地自构建）→ 不提示，避免误报
      final List<String> remoteTags = releaseList
          .map((e) => '${(e as Map)['tag_name'] ?? ''}')
          .where((e) => e.isNotEmpty)
          .toList();
      final String remoteTag = remoteTags.isNotEmpty ? remoteTags.first : '';
      final bool hasNewVersion;
      if (BuildConfig.tag.isNotEmpty && remoteTag.isNotEmpty) {
        if (remoteTag == BuildConfig.tag) {
          hasNewVersion = false;
        } else {
          hasNewVersion = remoteTags.contains(BuildConfig.tag);
        }
      } else {
        final int latest =
            DateTime.parse(data['created_at']).millisecondsSinceEpoch ~/
                1000;
        hasNewVersion = latest > BuildConfig.buildTime;
      }
      if (!hasNewVersion) {
        if (!isAuto) {
          SmartDialog.showToast('已是最新版本');
        }
      } else {
        SmartDialog.show(
          animationType: SmartAnimationType.centerFade_otherSlide,
          builder: (context) {
            final colorScheme = ColorScheme.of(context);
            Widget downloadBtn(String text, {String? ext}) => TextButton(
              onPressed: () => onDownload(data, ext: ext),
              child: Text(text),
            );
            return AlertDialog(
              title: const Text('🎉 发现新版本 '),
              content: SizedBox(
                height: 280,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['tag_name']}',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text('${data['body']}'),
                      TextButton(
                        onPressed: () => PageUtils.launchURL(
                          '${Constants.sourceCodeUrl}/commits/main',
                        ),
                        child: Text(
                          "点此查看完整更新(即commit)内容",
                          style: TextStyle(color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isAuto)
                  TextButton(
                    onPressed: () {
                      SmartDialog.dismiss();
                      GStorage.setting.put(SettingBoxKey.autoUpdate, false);
                    },
                    child: Text(
                      '不再提醒',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  ),
                TextButton(
                  onPressed: SmartDialog.dismiss,
                  child: Text(
                    '取消',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ),
                if (Platform.isWindows) ...[
                  downloadBtn('zip', ext: 'zip'),
                  downloadBtn('exe', ext: 'exe'),
                ] else if (Platform.isLinux) ...[
                  downloadBtn('rpm', ext: 'rpm'),
                  downloadBtn('deb', ext: 'deb'),
                  downloadBtn('targz', ext: 'tar.gz'),
                ] else
                  downloadBtn('下载'),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('failed to check update: $e');
    }
  }

  // 下载适用于当前系统的安装包
  static Future<void> onDownload(Map data, {String? ext}) async {
    SmartDialog.dismiss();
    try {
      void download(String plat) {
        if (data['assets'].isNotEmpty) {
          for (Map<String, dynamic> i in data['assets']) {
            final String name = i['name'];
            if (name.contains(plat) &&
                (ext == null || ext.isEmpty ? true : name.endsWith(ext))) {
              // 定制版：GitHub 直连下载慢，改走加速镜像
              PageUtils.launchURL(_accelerate(i['browser_download_url']));
              return;
            }
          }
          throw UnsupportedError('platform not found: $plat');
        }
      }

      if (Platform.isAndroid) {
        // 获取设备信息
        AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        // [arm64-v8a]
        download(androidInfo.supportedAbis.first);
      } else {
        download(Platform.operatingSystem);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('download error: $e');
      PageUtils.launchURL(
        _accelerate('${Constants.sourceCodeUrl}/releases/latest'),
      );
    }
  }
}
