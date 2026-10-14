import 'package:PiliPlus/models/common/enum_with_label.dart';

/// 动态背景粒子样式（移植自 Rinne Mobile）
enum ParticleStyle with EnumWithLabel {
  floating('浮动光点'),
  rain('雨滴'),
  star('星光闪烁'),
  sakura('樱花飘落'),
  fireflies('萤火虫'),
  constellation('星座连线'),
  ripples('水波涟漪'),
  ;

  const ParticleStyle(this.label);

  @override
  final String label;
}