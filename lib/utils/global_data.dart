import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';

class GlobalData {
  int imgQuality = Pref.picQuality;

  num? coins;

  void afterCoin(num coin) {
    if (coins != null) {
      coins = coins! - coin;
    }
  }

  Set<int> blackMids = Pref.blackMids;

  bool dynamicsWaterfallFlow = Pref.dynamicsWaterfallFlow;

  bool showMedal = Pref.showMedal;
  // 定制版：动态粒子背景（Rx 以便设置改动后立即生效）
  final enableParticleBg = Pref.enableParticleBg.obs;
  final particleStyle = Pref.particleStyle.obs;

  // 私有构造函数
  GlobalData._();

  // 单例实例
  static final GlobalData _instance = GlobalData._();

  // 获取全局实例
  factory GlobalData() => _instance;
}

extension IterableExt<E> on Iterable<E> {
  Iterable<E> whereNotBlocked(Object? /* mid */ Function(E element) test) =>
      where((e) => !GlobalData().blackMids.contains(test(e)));
}
