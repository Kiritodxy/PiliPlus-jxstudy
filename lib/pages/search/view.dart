import 'package:PiliPlus/common/widgets/particle_background.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/sliver_wrap.dart';
import 'package:PiliPlus/common/widgets/view_insets_safe_area.dart';
import 'package:PiliPlus/pages/search/controller.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    // 定制版：已移除 搜索联想词 / 大家都在搜 / 完整榜单 / 搜索发现
    // 保留：搜索历史（记录全部关键词，长按单条删除、可清空）
    return SimpleScaffold(
      appBar: _buildAppBar,
      body: ParticleBackgroundLayer(
        child: Padding(
          padding: .only(left: padding.left, right: padding.right),
          child: ViewInsetsSafeArea(
            child: CustomScrollView(
              slivers: [
                if (_searchController.allowSearchEnabled) _buildWhitelistTip,
                _buildHistory,
                SliverPadding(padding: .only(bottom: padding.bottom)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 白名单搜索开启时的提示（关闭时搜索不受限，不显示）
  Widget get _buildWhitelistTip => SliverPadding(
    padding: const .fromLTRB(20, 16, 20, 0),
    sliver: SliverToBoxAdapter(
      child: Row(
        children: [
          Icon(
            Icons.school_outlined,
            size: 18,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '白名单搜索已开启，仅放行学习相关关键词',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    ),
  );

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

  late final mainAxisExtent = 16 + MediaQuery.textScalerOf(context).scale(14);
  Widget get _buildHistory {
    return Obx(
      () {
        final list = _searchController.historyList;
        if (list.isEmpty) {
          return const SliverToBoxAdapter();
        }
        final secondary = theme.colorScheme.secondary;
        return SliverPadding(
          padding: const .fromLTRB(10, 25, 6, 25),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverPadding(
                padding: const .fromLTRB(6, 0, 6, 6),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        '搜索历史',
                        strutStyle: const StrutStyle(leading: 0, height: 1),
                        style: theme.textTheme.titleMedium!.copyWith(
                          height: 1,
                          fontWeight: .bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Spacer(),
                      TextButton.icon(
                        style: const ButtonStyle(
                          visualDensity: .compact,
                          tapTargetSize: .shrinkWrap,
                          padding: WidgetStatePropertyAll(
                            .symmetric(horizontal: 10),
                          ),
                        ),
                        onPressed: _searchController.onClearHistory,
                        icon: Icon(
                          Icons.clear_all_outlined,
                          size: 18,
                          color: secondary,
                        ),
                        label: Text(
                          '清空',
                          style: TextStyle(height: 1, color: secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverFixedWrap(
                mainAxisExtent: mainAxisExtent,
                spacing: 8,
                runSpacing: 8,
                delegate: SliverChildBuilderDelegate(
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  childCount: list.length,
                  (context, index) => SearchText(
                    text: list[index],
                    onTap: _searchController.onClickKeyword,
                    // 长按删除该条历史
                    onLongPress: _searchController.onLongSelect,
                    height: 1,
                    maxLines: 1,
                    fontSize: 14,
                    overflow: .ellipsis,
                    padding: const .fromLTRB(11, 8, 11, 0),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}