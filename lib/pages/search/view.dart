import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_insets_safe_area.dart';
import 'package:PiliPlus/pages/search/controller.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/study_guard.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _tag = Utils.generateRandomString(6);
  late final SSearchController _searchController;
  late ThemeData theme;
  late bool isPortrait;
  late EdgeInsets padding;

  @override
  void initState() {
    super.initState();
    _searchController = Get.put(SSearchController(_tag), tag: _tag);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    theme = Theme.of(context);
    padding = MediaQuery.viewPaddingOf(context);
    isPortrait = MediaQuery.sizeOf(context).isPortrait;
  }

  @override
  Widget build(BuildContext context) {
    // 定制版：已移除 搜索联想词 / 搜索历史 / 大家都在搜 / 完整榜单 / 搜索发现
    return SimpleScaffold(
      appBar: _buildAppBar,
      body: Padding(
        padding: .only(left: padding.left, right: padding.right),
        child: ViewInsetsSafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const .symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: .min,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 56,
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '仅支持搜索学习相关内容',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '可搜索：${StudyGuard.whitelist.take(8).join('、')} 等',
                          textAlign: .center,
                          style: TextStyle(
                            color: theme.colorScheme.outline,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(padding: .only(bottom: padding.bottom)),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget get _buildAppBar => AppBar(
    shape: Border(
      bottom: BorderSide(
        color: theme.dividerColor.withValues(alpha: 0.08),
        width: 1,
      ),
    ),
    actions: [
      Obx(
        () => _searchController.showUidBtn.value
            ? IconButton(
                tooltip: 'UID搜索用户',
                icon: const Icon(Icons.person_outline, size: 22),
                onPressed: () => Get.toNamed(
                  '/member?mid=${_searchController.controller.text}',
                ),
              )
            : const SizedBox.shrink(),
      ),
      IconButton(
        tooltip: '清空',
        icon: const Icon(Icons.clear, size: 22),
        onPressed: _searchController.onClear,
      ),
      IconButton(
        tooltip: '搜索',
        onPressed: _searchController.submit,
        icon: const Icon(Icons.search, size: 22),
      ),
      const SizedBox(width: 10),
    ],
    title: TextField(
      autofocus: true,
      focusNode: _searchController.searchFocusNode,
      controller: _searchController.controller,
      textInputAction: TextInputAction.search,
      onChanged: _searchController.onChange,
      decoration: InputDecoration(
        visualDensity: .standard,
        hintText: _searchController.hintText ?? '搜索',
        border: InputBorder.none,
      ),
      onSubmitted: (value) => _searchController.submit(),
    ),
  );
}
