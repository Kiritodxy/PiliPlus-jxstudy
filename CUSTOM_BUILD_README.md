# PiliPlus 定制版 —— 修改说明

> 基于 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)（commit `11e02b8`，版本 2.1.4）定制的安卓 B 站客户端。
> 定制版应用名：**PiliPlus 定制版**，包名 `com.custom.piliplus`（与官方版可共存，互不影响）。

## 一、四项定制需求实现情况

### 1. 删除直播模块（已实现）

| 位置 | 处理方式 |
|---|---|
| 首页底部/顶部 Tab「直播」 | 从 `HomeTabType` 枚举中移除，首页仅保留 推荐 / 热门 / 分区 |
| 直播间页、直播分区、直播搜索、关注直播、直播弹幕屏蔽、直播表情等 8 个页面目录 | 整体删除（`pages/live*`、`pages/match_info` 等） |
| 搜索结果「直播间」Tab | 从 `SearchType` 枚举中移除 |
| 综合搜索结果中的电竞直播卡片 | 从综合搜索面板中移除 |
| 动态页 UP 主列表中的「Live」分组 | 移除展开按钮与直播 UP 列表 |
| 视频卡片/UP 头像上的「直播中」角标点击 | `PageUtils.toLiveRoom()` 统一改为弹 toast「直播功能已停用」 |
| 观看记录中的直播历史条目点击 | 同上，统一拦截 |
| 外部唤起（bilibili://live、赛事链接） | `app_scheme.dart` 中拦截，弹 toast |
| 设置页「直播 CDN」「直播默认画质」「SuperChat 显示」「全屏 SC 大小」等直播专属设置项 | 全部移除 |
| 用户空间页直播间粉丝勋章与「勋章墙」弹窗 | 移除勋章展示与弹窗，`medal_wall.dart` 整体删除 |
| 播放器弹幕长按菜单中的「举报直播弹幕」 | 移除该菜单项与 `HeaderControl.reportLiveDanmaku` 方法 |
| 直播网络层 `lib/http/live.dart`（26 个直播 API 方法） | 整体删除（清理后已无任何引用者） |
| 用户空间控制器中的 `live` 直播间状态字段 | 移除 |

**兜底策略**：不删除 B 站 API 中直播数据的解析模型（如动态卡片里的直播信息结构体），只删除 UI 入口与路由——这样动态流、搜索等接口返回直播数据时不会崩溃，只是无法进入直播间。

### 2. 观看记录：不可删除 + 显示实际观看时长（已实现）

**不可删除**：
- 单条记录右上角菜单中的「删除记录」选项 → 已移除
- 长按多选 → 已禁用（长按不再触发多选模式）
- AppBar 菜单「清空观看记录」「删除已看记录」→ 已移除
- 观看记录搜索页中的删除入口 → 已移除
- 控制器中 `delHistory` / `_onDelete` / `onDelViewedHistory` / `onClearHistory` 等删除方法 → 已删除

> 注：**「暂停/恢复观看记录」开关保留**。这是 B 站官方的记录上报开关（关掉后新观看不再记录），不是删除入口；若需一并禁用可再删除 `base_controller.dart` 中的 `onPauseHistory`。

**显示实际观看时长**（新增）：
- 每条记录在 UP 主名上方新增一行高亮文字：
  - 未看完：`实际观看 03:25 / 12:40`（进度秒数 / 视频总时长）
  - 已看完（progress == -1）：`已看完 · 全长 12:40`
- 数据来源为 B 站历史记录接口自带的 `progress`（观看进度，秒）与 `duration`（总时长，秒）字段，无需额外请求。

### 3. 删除消息模块（已实现）

| 位置 | 处理方式 |
|---|---|
| 首页顶栏、侧边栏、「我的」页的消息铃铛按钮与未读红点 | 移除 |
| 私信列表页（whisper）、私信详情、联系人、消息设置等 6 个页面目录 | 整体删除 |
| 回复我的 / @我的 / 收到的赞 / 系统消息 等消息子页面（msg_feed_top） | 整体删除 |
| 路由表中 9 条消息相关路由（/whisper、/whisperDetail、/replyMe、/atMe、/likeMe、/sysMsg、/msgLikeDetail 等） | 移除 |
| 用户空间页「发私信」按钮 | 移除 |
| 分享面板中的「私信分享给好友」功能（`PageUtils.pmShare` / `RequestUtils.pmShare`） | 统一改为弹 toast「私信功能已停用」 |
| MainController 中的未读消息轮询逻辑、消息未读标记/类型设置项 | 移除 |

> 保留：动态页本身的「动态未读标记」不受影响（属于动态模块，不属于消息模块）。

### 4. 删除番剧和影视模块（已实现）

| 位置 | 处理方式 |
|---|---|
| 首页「番剧」「影视」Tab | 从 `HomeTabType` 枚举中移除 |
| 番剧索引页、番剧点评页、番剧搜索面板、用户空间追番页等 5 个页面目录 | 整体删除 |
| 搜索结果「番剧」「影视」Tab | 从 `SearchType` 枚举中移除 |
| 综合搜索结果中的番剧/影视媒体卡片 | 移除 |
| 收藏页「追番」「追剧」Tab | 从 `FavTabType` 枚举中移除，收藏页仅保留 视频/专栏/笔记/话题/课堂 |
| 用户空间主页的「追番」区块与「番剧」Tab | 移除 |
| `PageUtils.viewPgc()`（番剧/影视播放统一入口） | 改为弹 toast「番剧/影视功能已停用」 |

## 二、其他配套修改

- **应用身份**：应用名「PiliPlus 定制版」，applicationId `com.custom.piliplus`（可与官方 PiliPlus 共存安装）；版本号 `2.1.4-custom.1`。
- **旧配置容错**：若设备曾安装过官方版并自定义过首页 Tab 顺序，定制版启动时会自动过滤掉已删除 Tab 的失效索引，不会崩溃。
- **构建产物**：`pili_release.json`（版本注入文件，CI 中由脚本生成，本地构建需手动创建）。

## 三、构建方法（Linux 环境）

```bash
# 前置：Flutter 3.47.4（stable）、JDK 17+、NDK 28.2.13676358、
#       Android SDK（platforms;android-36 与 android-37、build-tools 36.0.0、platform-tools）

# 1. 给 Flutter SDK 与 material_ui 包打项目自带补丁（等价于 CI 的 patch.ps1）
#    SDK 补丁（24 个，在 Flutter 根目录执行）：
for p in modal_barrier text_selection mouse_cursor image_anim layout_builder \
         navigation_drawer popup_menu fab null_safety_for_selectable_region \
         selectable_region editable_text text_field scroll_position scrollable \
         scrollable_gesture draggable_scrollable_sheet scaffold text text_painter \
         sliver refresh_indicator bottom_sheet_android scroll_view navigator; do
  tr -d '\r' < lib/scripts/$p.patch | git apply
done
#    material_ui 补丁（9 个，在 pub 缓存的 material_ui-1.2.0 目录执行）：
for p in modal_barrier_material navigation_drawer popup_menu fab text_field \
         scaffold refresh_indicator tabs bottom_sheet_android; do
  tr -d '\r' < lib/scripts/material/$p.patch | git apply
done

# 2. 拉取依赖
flutter pub get   # 建议配置 PUB_HOSTED_URL=https://pub.flutter-io.cn

# 3. 构建Release APK
flutter build apk --release --dart-define-from-file=pili_release.json --no-pub
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

### 3.1 中国大陆网络环境构建要点

本项目构建时若官方源不可达（`dl.google.com`、`github.com`、`services.gradle.org` 在部分网络下握手失败），需做以下替换：

| 环节 | 官方地址 | 替换方案 |
|---|---|---|
| Maven 仓库（AGP / Kotlin / 传递依赖） | `dl.google.com`、`repo.maven.apache.org` | `~/.gradle/init.gradle` 全局改写为 `maven.aliyun.com/repository/{google,public,central}` |
| Gradle 发行包 | `services.gradle.org` | `mirrors.cloud.tencent.com/gradle/` |
| Flutter 引擎与 pub 包 | `storage.googleapis.com`、`pub.dev` | `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`、`PUB_HOSTED_URL=https://pub.flutter-io.cn` |
| Android SDK 组件（platform/build-tools/NDK） | `dl.google.com/android/repository/` | `mirrors.cloud.tencent.com/AndroidSDK/`（注意其命名：`platform-36_r02.zip`、`build-tools_r34-linux.zip`、`android-ndk-r28c-linux.zip`） |
| media_kit 的 libmpv 原生库（GitHub Releases） | `github.com/.../releases/download/...` | 用 `gh-proxy.com` 代理预先下载，放入插件 buildDir 后由插件的 SHA-256/MD5 校验放行 |

**注意事项**：
- 腾讯 AndroidSDK 镜像的 build-tools 最高只到 **r34**，而 AGP 需要 **36.0.0**。实测可用 r34 内容配合改名（目录名 `36.0.0` + `source.properties` 内 `Pkg.Revision=36.0.0`）通过；核心工具 aapt2/d8/apksigner/zipalign 均存在。
- 若本地 SDK 内的 `platforms/android-37` 来自非标准渠道（`localPackage path` 写作 `platforms;android-37.0`），Gradle 会报 `Failed to find target with hash string 'android-37'`，需将目录名与 `package.xml` 中的路径标识统一。
- 插件模块（如 `android_file_picker`）自带 `buildscript` 块，会绕过项目 settings 的仓库配置直连官方源，必须用 `~/.gradle/init.gradle` 全局改写才能生效。
- `io.flutter:flutter_embedding_*` 引擎构件托管在 `storage.googleapis.com`，需在项目 `build.gradle.kts` 的 `allprojects.repositories` 中加入 `https://storage.flutter-io.cn/download.flutter.io`。

### 3.2 容器环境构建：内存与 Lint 陷阱（本次实际踩坑）

在受限容器（cgroup 内存 8G / 4 核）中构建时，会遇到**构建进程被静默杀掉**的现象：

```
> Gradle build daemon disappeared unexpectedly (it may have been killed or may have crashed)
```

这不是 Gradle 崩溃，而是 **JVM 堆设置超过了 cgroup 内存上限，被内核 OOM killer 杀死**。排查与解决：

```bash
cat /sys/fs/cgroup/memory.max    # 先确认真实内存上限（常远小于 free 显示值）
```

| 参数 | 错误配置 | 正确配置（8G/4核） |
|---|---|---|
| `org.gradle.jvmargs` | `-Xmx12G`（超限被杀） | `-Xmx5G -XX:MaxMetaspaceSize=1G -XX:+UseG1GC` |
| `org.gradle.workers.max` | `16`（4 核下无意义） | `4` |
| Android Lint | 默认开启（29 个 lint 任务，主要 OOM 来源） | 全局禁用 |

禁用 Lint（在 `android/build.gradle.kts` 末尾追加）：

```kotlin
allprojects {
    tasks.matching {
        it.name.startsWith("lint") || it.name.contains("Lint")
    }.configureEach {
        enabled = false
    }
}
```

并在 `android/app/build.gradle.kts` 内设置：

```kotlin
lint {
    checkReleaseBuilds = false
    abortOnError = false
}
```

> 经验：容器内 `free -h` 显示的内存（如 123G）**不代表可用上限**，必须看 cgroup 限制。按 cgroup 上限的 60% 左右设置 `-Xmx` 才安全。


## 四、已知边界说明（坦诚声明）

1. **数据侧不可控项**：「不可删除观看记录」禁用的是 App 内所有删除入口；但观看记录实际存储在 B 站服务器上，理论上用户用官方 App/网页仍可删除。App 层面已做到无法删除。
2. **观看时长的精度**：显示的是 B 站服务端记录的观看进度（`progress` 字段），与「实际观看秒数」可能有轻微出入（B 站本身按进度位置上报，快进会跳计）。这是接口能提供的最准确数据。
3. **间接残留**：视频详情页简介中的部分番剧关联入口（如 UGC 视频挂的「合集/列表」）属于视频模块功能，未删除；纯番剧播放入口已全部拦截。
4. **签名**：APK 使用 debug 签名（项目未提供 release 密钥库）。安装时若提示签名问题，属正常现象；如需正式签名，在 `android/key.properties` 配置密钥库后重新构建。

## 五、修改文件清单（相对原版）

**删除目录**（17 个）：
`lib/pages/live*`（8 个直播目录）、`lib/pages/pgc*`（3 个）、`lib/pages/member_pgc`、`lib/pages/search_panel/live`、`lib/pages/search_panel/pgc`、`lib/pages/whisper*`（5 个）、`lib/pages/contact`、`lib/pages/msg_feed_top`、`lib/pages/share`、`lib/pages/match_info`、`lib/pages/setting/pages/fullscreen_sc_size.dart` 等

**核心修改文件**：
- `lib/models/common/home_tab_type.dart` —— 移除 live/bangumi/cinema
- `lib/models/common/search/search_type.dart` —— 移除 live_room/media_bangumi/media_ft
- `lib/models/common/fav_type.dart` —— 移除追番/追剧
- `lib/models/common/member/tab_type.dart` —— 移除空间页番剧 Tab
- `lib/router/app_pages.dart` —— 移除 11 条路由
- `lib/pages/history/*`（controller/view/item/base_controller）—— 禁删除 + 显示观看时长
- `lib/pages/history_search/*` —— 移除删除入口
- `lib/utils/page_utils.dart` —— toLiveRoom/viewPgc/pmShare 拦截
- `lib/utils/app_scheme.dart` —— 直播/赛事外链拦截
- `lib/pages/main/{controller,view}.dart`、`lib/pages/home/view.dart`、`lib/pages/mine/view.dart` —— 移除消息入口与未读逻辑
- `lib/pages/member/widget/user_info_card.dart` —— 移除发私信按钮、直播间勋章、直播房间号传参
- `lib/pages/member/controller.dart` —— 移除 `live` 直播间状态字段
- `lib/pages/member/widget/medal_wall.dart` —— 整体删除（直播勋章墙）
- `lib/http/live.dart` —— 整体删除（直播网络层，已无引用者）
- `lib/pages/video/widgets/header_control.dart` —— 移除 `reportLiveDanmaku`
- `lib/pages/member_home/view.dart` —— 移除追番区块
- 设置页 4 个模型文件 —— 移除直播/消息相关设置项
- `android/app/build.gradle.kts`、`res/values/string.xml`、`pubspec.yaml` —— 应用身份定制
