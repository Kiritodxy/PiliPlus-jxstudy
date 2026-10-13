abstract final class BuildConfig {
  static const int versionCode = int.fromEnvironment(
    'pili.code',
    defaultValue: 1,
  );
  static const String versionName = String.fromEnvironment(
    'pili.name',
    defaultValue: 'SNAPSHOT',
  );

  static const int buildTime = int.fromEnvironment('pili.time');
  static const String commitHash = String.fromEnvironment(
    'pili.hash',
    defaultValue: 'N/A',
  );
  /// 定制版：构建时对应的 git tag（非 tag 构建时为空字符串），
  /// 用于更新检测精确比对，避免「永远提示有新版本」。
  static const String tag = String.fromEnvironment('pili.tag');
}
