// 定制版：原 私信分享面板(pages/share) 已移除，
// 此处仅保留被 粉丝/关注列表 复用的 UserModel 数据类
class UserModel {
  UserModel({
    required this.mid,
    required this.name,
    required this.avatar,
    this.selected = false,
  });

  final int mid;
  final String name;
  final String avatar;
  bool selected;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is UserModel) {
      return mid == other.mid;
    }
    return false;
  }

  @override
  int get hashCode => mid.hashCode;
}
