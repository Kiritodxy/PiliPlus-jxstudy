import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/utils/study_guard.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 定制版：家长设置 —— 学习白名单词库
///
/// 进入需家长密码；首次进入由家长设定密码。
class StudyWhitelistPage extends StatefulWidget {
  const StudyWhitelistPage({super.key});

  @override
  State<StudyWhitelistPage> createState() => _StudyWhitelistPageState();
}

class _StudyWhitelistPageState extends State<StudyWhitelistPage> {
  late List<String> _list = StudyGuard.whitelist;
  final TextEditingController _ctr = TextEditingController();

  Future<void> _save() async {
    await StudyGuard.saveWhitelist(_list);
    SmartDialog.showToast('已保存');
    setState(() {});
  }

  void _add() {
    final word = _ctr.text.trim();
    if (word.isEmpty) return;
    if (_list.contains(word)) {
      SmartDialog.showToast('该词条已存在');
      return;
    }
    setState(() {
      _list.add(word);
      _ctr.clear();
    });
    _save();
  }

  void _remove(String word) {
    setState(() => _list.remove(word));
    _save();
  }

  Future<void> _reset() async {
    await StudyGuard.resetWhitelist();
    setState(() => _list = StudyGuard.whitelist);
    SmartDialog.showToast('已恢复默认词库');
  }

  void _exportImport() {
    Utils.copyText(_list.join('\n'));
    SmartDialog.showToast('词库已复制到剪贴板');
  }

  void _bulkEdit() async {
    final res = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctr = TextEditingController(text: _list.join('\n'));
        return AlertDialog(
          title: const Text('批量编辑词库'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: ctr,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText: '每行一个词条',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('取消')),
            TextButton(
              onPressed: () => Get.back(result: ctr.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (res == null) return;
    setState(() {
      _list = res
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    });
    await _save();
  }

  @override
  void dispose() {
    _ctr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('学习白名单'),
        actions: [
          IconButton(
            tooltip: '批量编辑',
            icon: const Icon(Icons.edit_note_outlined),
            onPressed: _bulkEdit,
          ),
          IconButton(
            tooltip: '复制全部',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _exportImport,
          ),
          IconButton(
            tooltip: '恢复默认',
            icon: const Icon(Icons.restart_alt_outlined),
            onPressed: _reset,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const .fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctr,
                    decoration: const InputDecoration(
                      hintText: '添加允许的关键词',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(onPressed: _add, child: const Text('添加')),
              ],
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: Text(
              '搜索关键词需包含以下任一词条才会放行（例如「高中数学 三角函数」命中「数学」）。'
              '包含匹配、不区分大小写；词库清空等于全部禁止。',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: .min,
                      children: [
                        Icon(
                          Icons.block_outlined,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Text('词库为空，当前所有搜索都被禁止'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _reset,
                          child: const Text('恢复默认词库'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _list.length,
                    itemBuilder: (context, index) {
                      final word = _list[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(word),
                        trailing: IconButton(
                          tooltip: '移除',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _remove(word),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 家长密码校验 / 首次设定。
/// 返回 true 表示通过，允许进入词库设置。
Future<bool> checkParentPassword(BuildContext context) async {
  final ctr = TextEditingController();
  final isFirst = !StudyGuard.hasPassword;

  final res = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(isFirst ? '设置家长密码' : '需要家长密码'),
      content: TextField(
        controller: ctr,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(
          hintText: isFirst ? '请设定密码（勿泄露给孩子）' : '请输入家长密码',
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Get.back(result: v),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        TextButton(
          onPressed: () => Get.back(result: ctr.text),
          child: const Text('确定'),
        ),
      ],
    ),
  );

  if (res == null || res.isEmpty) return false;

  if (isFirst) {
    await StudyGuard.savePassword(res);
    SmartDialog.showToast('密码已设置，请牢记');
    return true;
  }

  if (StudyGuard.verifyPassword(res)) return true;

  SmartDialog.showToast('密码错误');
  return false;
}
