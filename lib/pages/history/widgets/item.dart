import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/select_mask.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/models_new/history/watch_time.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

class HistoryItem extends StatelessWidget {
  final HistoryItemModel item;
  final MultiSelectBase ctr;

  const HistoryItem({
    super.key,
    required this.item,
    required this.ctr,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDuration = item.hasDuration;
    final business = item.history.business;
    final enableMultiSelect = ctr.enableMultiSelect.value;
    int aid = item.history.oid!;
    String bvid = item.history.bvid ?? IdUtils.av2bv(aid);

    // 定制版：观看记录不支持多选删除，长按无操作
    // ignore: unused_local_variable

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: enableMultiSelect
            ? () => ctr.onSelect(item)
            : () async {
                if (business?.contains('article') == true) {
                  PageUtils.toDupNamed(
                    '/articlePage',
                    parameters: {
                      'id': business == 'article-list'
                          ? '${item.history.cid}'
                          : '${item.history.oid}',
                      'type': 'read',
                    },
                  );
                } else if (business == 'live') {
                  if (item.liveStatus == 1) {
                    PageUtils.toLiveRoom(item.history.oid);
                  } else {
                    SmartDialog.showToast('直播未开播');
                  }
                } else if (business == 'pgc') {
                  PageUtils.viewPgc(
                    epId: item.history.epid,
                    progress: item.playbackProgress,
                  );
                } else if (business == 'cheese') {
                  if (item.uri?.isNotEmpty == true) {
                    PageUtils.viewPgcFromUri(
                      item.uri!,
                      isPgc: false,
                      aid: item.history.oid,
                      progress: item.playbackProgress,
                    );
                  }
                } else {
                  int? cid = item.history.cid;
                  Dimension? dimension;
                  if (cid == null) {
                    if (await SearchHttp.ab2cWithDimension(
                          aid: aid,
                          bvid: bvid,
                          part: item.history.page,
                        )
                        case final res?) {
                      cid = res.cid;
                      dimension = res.dimension;
                    }
                  }
                  if (cid != null) {
                    // TODO: dimension
                    PageUtils.toVideoPage(
                      aid: aid,
                      bvid: bvid,
                      cid: cid,
                      cover: item.cover,
                      title: item.title,
                      dimension: dimension,
                      progress: item.playbackProgress,
                    );
                  }
                }
              },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Style.safeSpace,
                vertical: 5,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: Style.aspectRatio,
                    child: LayoutBuilder(
                      builder: (context, boxConstraints) {
                        double maxWidth = boxConstraints.maxWidth;
                        double maxHeight = boxConstraints.maxHeight;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            NetworkImgLayer(
                              src: item.cover?.isNotEmpty == true
                                  ? item.cover
                                  : item.covers?.firstOrNull ?? '',
                              width: maxWidth,
                              height: maxHeight,
                            ),
                            ?item.label,
                            if (hasDuration)
                              ...item.progressIndicator(theme.colorScheme),
                            Positioned.fill(
                              child: selectMask(
                                theme.colorScheme,
                                item.checked,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  content(theme),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 0,
              width: 29,
              height: 29,
              child: PopupMenuButton(
                padding: EdgeInsets.zero,
                tooltip: '功能菜单',
                icon: Icon(
                  Icons.more_vert_outlined,
                  color: theme.colorScheme.outline,
                  size: 18,
                ),
                position: PopupMenuPosition.under,
                itemBuilder: (_) => [
                  if (item.authorMid != null &&
                      item.authorName?.isNotEmpty == true)
                    PopupMenuItem(
                      onTap: () => Get.toNamed('/member?mid=${item.authorMid}'),
                      height: 38,
                      child: Row(
                        children: [
                          const Icon(
                            MdiIcons.accountCircleOutline,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '访问：${item.authorName}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  if (business != 'pgc' &&
                      item.badge != '番剧' &&
                      item.tagName?.contains('动画') != true &&
                      business != 'live' &&
                      business?.contains('article') != true)
                    PopupMenuItem(
                      onTap: () =>
                          UserHttp.toViewLater(bvid: item.history.bvid),
                      height: 38,
                      child: const Row(
                        children: [
                          Icon(Icons.watch_later_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('稍后再看', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget content(ThemeData theme) {
    // 定制版：实际观看时长（供下方显示）
    final hasDuration = item.duration != null && item.duration != 0;
    int aid = item.history.oid!;
    String bvid = item.history.bvid ?? IdUtils.av2bv(aid);
    return Expanded(
      child: Column(
        spacing: 2,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title!,
            style: TextStyle(
              fontSize: theme.textTheme.bodyMedium!.fontSize,
              height: 1.42,
              letterSpacing: 0.3,
            ),
            maxLines: item.videos! > 1 ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.history.business == 'pgc' &&
              item.showTitle?.isNotEmpty == true)
            Text(
              item.showTitle!,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.outline,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const Spacer(),
          // 定制版：显示本地累计的「真实观看时长」
            // 与 B 站返回的 progress（上次播放位置）区分：这里只统计本 App 内的真实播放
            if (hasDuration)
              Builder(builder: (context) {
                final cid = item.history.cid;
                final localMs = cid != null ? WatchTime.readTotalMs(cid) : 0;
                if (localMs > 0) {
                  final watched = DurationUtils.formatDuration(localMs ~/ 1000);
                  final total = DurationUtils.formatDuration(item.duration);
                  return Text(
                    '实际观看 $watched / $total',
                    style: TextStyle(
                      fontSize: theme.textTheme.labelMedium!.fontSize,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                // 本地无统计（未在本 App 看过）：显示 B 站的上次播放位置
                final watched = item.progress == -1
                    ? DurationUtils.formatDuration(item.duration)
                    : DurationUtils.formatDuration(item.progress);
                return Text(
                  item.progress == -1
                      ? '已看完 · 全长 $watched'
                      : '上次看到 $watched / ${DurationUtils.formatDuration(item.duration)}',
                  style: TextStyle(
                    fontSize: theme.textTheme.labelMedium!.fontSize,
                    color: theme.colorScheme.outline,
                  ),
                );
              }),
          if (item.authorName?.isNotEmpty == true)
            Text(
              item.authorName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: theme.textTheme.labelMedium!.fontSize,
                color: theme.colorScheme.outline,
              ),
            ),
          Text(
            DateFormatUtils.chatFormat(item.viewAt!, isHistory: true),
            style: TextStyle(
              fontSize: theme.textTheme.labelMedium!.fontSize,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> onPushHistory(HistoryItemModel item) async {
  final business = item.history.business;
  if (business?.contains('article') == true) {
    PageUtils.toDupNamed(
      '/articlePage',
      parameters: {
        'id': business == 'article-list'
            ? '${item.history.cid}'
            : '${item.history.oid}',
        'type': 'read',
      },
    );
  } else if (business == 'live') {
    if (item.liveStatus == 1) {
      PageUtils.toLiveRoom(item.history.oid);
    } else {
      SmartDialog.showToast('直播未开播');
    }
  } else if (business == 'pgc') {
    PageUtils.viewPgc(
      epId: item.history.epid,
      progress: item.playbackProgress,
    );
  } else if (business == 'cheese') {
    if (item.uri?.isNotEmpty == true) {
      PageUtils.viewPgcFromUri(
        item.uri!,
        isPgc: false,
        aid: item.history.oid,
        progress: item.playbackProgress,
      );
    }
  } else {
    final aid = item.history.oid!;
    final bvid = item.history.bvid ?? IdUtils.av2bv(aid);
    int? cid = item.history.cid;
    Dimension? dimension;
    if (cid == null) {
      if (await SearchHttp.ab2cWithDimension(
            aid: aid,
            bvid: bvid,
            part: item.history.page,
          )
          case final res?) {
        cid = res.cid;
        dimension = res.dimension;
      }
    }
    if (cid != null) {
      // TODO: dimension
      PageUtils.toVideoPage(
        aid: aid,
        bvid: bvid,
        cid: cid,
        cover: item.cover,
        title: item.title,
        dimension: dimension,
        progress: item.playbackProgress,
      );
    }
  }
}
