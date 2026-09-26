import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

// 定制版：首页已移除 推荐/热门/分区 模块，仅保留居中的搜索入口
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  late ColorScheme _colorScheme;
  final _homeController = Get.putOrFind(HomeController.new);

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorScheme = ColorScheme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: searchBar(),
        ),
      ),
    );
  }

  Widget searchBar() {
    const borderRadius = BorderRadius.all(Radius.circular(28));
    return SizedBox(
      height: 52,
      child: Material(
        borderRadius: borderRadius,
        color: _colorScheme.onSecondaryContainer.withValues(alpha: 0.05),
        child: InkWell(
          borderRadius: borderRadius,
          splashColor: _colorScheme.primaryContainer.withValues(alpha: 0.3),
          onTap: () {
            feedBack();
            Get.toNamed(
              '/search',
              parameters: _homeController.enableSearchWord
                  ? {'hintText': _homeController.defaultSearch.value}
                  : null,
            );
          },
          child: Row(
            children: [
              const SizedBox(width: 18),
              Icon(
                Icons.search_outlined,
                color: _colorScheme.onSecondaryContainer,
                semanticLabel: '搜索',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(
                  () => Text(
                    _homeController.defaultSearch.value.isEmpty
                        ? '搜索'
                        : _homeController.defaultSearch.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _colorScheme.outline),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// 保留：底部导航栏/侧边栏仍在使用该头像组件（定制版已移除其上的无痕角标）
Widget userAvatar({
  required ColorScheme colorScheme,
  required MainController mainController,
}) {
  return Semantics(
    label: "我的",
    child: Obx(
      () {
        if (mainController.accountService.isLogin.value) {
          return Stack(
            clipBehavior: .none,
            children: [
              NetworkImgLayer(
                type: .avatar,
                width: 34,
                height: 34,
                src: mainController.accountService.face.value,
              ),
              Positioned.fill(
                child: Material(
                  type: .transparency,
                  child: InkWell(
                    onTap: mainController.toMinePage,
                    splashColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    customBorder: const CircleBorder(),
                  ),
                ),
              ),
            ],
          );
        }
        return SizedBox(
          width: 38,
          height: 38,
          child: IconButton(
            tooltip: '点击登录',
            style: IconButton.styleFrom(
              padding: .zero,
              backgroundColor: colorScheme.onInverseSurface,
            ),
            onPressed: mainController.toMinePage,
            icon: Icon(
              Icons.person_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
          ),
        );
      },
    ),
  );
}
