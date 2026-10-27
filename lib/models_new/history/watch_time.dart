import 'dart:convert';

import 'package:hive_ce/hive.dart';

/// 定制版：单个视频的本地真实观看时长统计（毫秒）。
///
/// 与 `GStorage.watchProgress`（记录"上次播放到哪"）不同，这里是**累计观看时长**：
/// 只在播放器真正 playing 时累加，暂停/卡顿/seek 不计入。
class WatchTime {
  const WatchTime({required this.totalMs, required this.lastAt, this.sessions = 0});

  /// 累计观看时长（毫秒）
  final int totalMs;

  /// 最后一次统计的时间戳（毫秒）
  final int lastAt;

  /// 观看次数（每次进入播放并产生时长 +1）
  final int sessions;

  Map<String, dynamic> toJson() => {
    'total': totalMs,
    'last': lastAt,
    'sessions': sessions,
  };

  static WatchTime fromJson(Map<String, dynamic> json) => WatchTime(
    totalMs: (json['total'] as num?)?.toInt() ?? 0,
    lastAt: (json['last'] as num?)?.toInt() ?? 0,
    sessions: (json['sessions'] as num?)?.toInt() ?? 0,
  );

  static WatchTime decode(Object? raw) {
    if (raw is Map) {
      return WatchTime.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) return WatchTime.fromJson(Map<String, dynamic>.from(d));
      } catch (_) {}
    }
    return const WatchTime(totalMs: 0, lastAt: 0);
  }

  static Object encode(WatchTime v) => v.toJson();

  /// 按 cid 累加毫秒
  static void add(int cid, int deltaMs, {int? nowMs}) {
    if (deltaMs <= 0) return;
    final box = GStorage.watchTime;
    final prev = WatchTime.decode(box.get(cid.toString()));
    final next = WatchTime(
      totalMs: prev.totalMs + deltaMs,
      lastAt: nowMs ?? DateTime.now().millisecondsSinceEpoch,
      sessions: prev.sessions,
    );
    box.put(cid.toString(), WatchTime.encode(next));
  }

  /// 本次会话开始（sessions +1，时长不变）
  static void startSession(int cid) {
    final box = GStorage.watchTime;
    final prev = WatchTime.decode(box.get(cid.toString()));
    final next = WatchTime(
      totalMs: prev.totalMs,
      lastAt: DateTime.now().millisecondsSinceEpoch,
      sessions: prev.sessions + 1,
    );
    box.put(cid.toString(), WatchTime.encode(next));
  }

  /// 读取某视频的累计时长（毫秒）
  static int totalMs(int cid) =>
      WatchTime.decode(GStorage.watchTime.get(cid.toString())).totalMs;

  /// 清空单个视频
  static void clear(int cid) => GStorage.watchTime.delete(cid.toString());

  /// 清空全部
  static void clearAll() => GStorage.watchTime.clear();
}