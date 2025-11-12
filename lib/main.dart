import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'data/dictionary_repository.dart';
import 'features/dictionary/dictionary_controller.dart';
import 'models/word_entry.dart';

/// Flutter 程序入口：负责挂载根 Widget。
void main() {
  runApp(const DictionaryApp());
}

/// 全局 MaterialApp，集中处理主题/路由等顶层配置。
class DictionaryApp extends StatelessWidget {
  const DictionaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF838383),
      brightness: Brightness.dark,
    );

    // MaterialApp 管理导航、主题与根页面。
    return MaterialApp(
      title: '英汉词典',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0x612F2F2F),
          contentTextStyle: TextStyle(color: Colors.amber),
        ),
      ),
      home: const DictionaryHomePage(),
    );
  }
}

/// 主界面，包含搜索、状态信息、结果列表三大区块。
class DictionaryHomePage extends StatefulWidget {
  const DictionaryHomePage({super.key});

  @override
  State<DictionaryHomePage> createState() => _DictionaryHomePageState();
}

class _DictionaryHomePageState extends State<DictionaryHomePage> {
  /// 控制器负责真正的数据加载/筛选逻辑。
  late final DictionaryController _controller;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 初始化控制器并异步加载词典。
    _controller = DictionaryController(DictionaryRepository());
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold 提供 AppBar + Body 的基础视觉骨架。
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_controller.errorMessage != null) {
              // 加载失败时渲染错误态，并允许用户重试。
              return _ErrorState(
                message: _controller.errorMessage!,
                onRetry: _controller.refresh,
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/images/google.svg',
                      height: 96,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: _SearchField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _controller.updateQuery,
                    onSubmitted: (_) => _searchFocusNode.unfocus(),
                  ),
                ),
                _StatusBanner(
                  query: _controller.query,
                  visibleCount: _controller.visibleEntries.length,
                  totalCount: _controller.totalEntries,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _ResultList(
                    entries: _controller.visibleEntries,
                    query: _controller.query,
                    onRefresh: _controller.refresh,
                    onTapEntry: _showEntryDetails,
                    onCopy: _copyEntry,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _copyEntry(WordEntry entry) async {
    await Clipboard.setData(
      ClipboardData(text: '${entry.word}\n${entry.translation}'),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('提示'),
        content: Text('已复制 ${entry.word}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showEntryDetails(WordEntry entry) {
    // 通过 BottomSheet 展示完整释义与操作按钮。
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.word,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                entry.translation,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _copyEntry(entry);
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('复制释义'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    // 圆角卡片模拟 Google 输入框样式。
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索英文单词或缩写…',
            icon: Icon(Icons.search),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.query,
    required this.visibleCount,
    required this.totalCount,
  });

  final String query;
  final int visibleCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final text = query.isEmpty
        ? '共收录 $totalCount 个词条'
        : '找到 $visibleCount 个匹配项';
    // 状态条提供当前搜索结果的即时反馈。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.entries,
    required this.query,
    required this.onRefresh,
    required this.onTapEntry,
    required this.onCopy,
  });

  final List<WordEntry> entries;
  final String query;
  final Future<void> Function() onRefresh;
  final ValueChanged<WordEntry> onTapEntry;
  final ValueChanged<WordEntry> onCopy;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyState(
        message: query.isEmpty ? '开始搜索以查看释义。' : '未找到匹配的释义。',
        onRetry: query.isEmpty ? onRefresh : null,
      );
    }

    // 列表支持下拉刷新以便触发重新解析/加载。
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Scrollbar(
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _WordResultTile(
              entry: entry,
              query: query,
              onTap: () => onTapEntry(entry),
              onCopy: () => onCopy(entry),
            );
          },
        ),
      ),
    );
  }
}

class _WordResultTile extends StatelessWidget {
  const _WordResultTile({
    required this.entry,
    required this.query,
    required this.onTap,
    required this.onCopy,
  });

  final WordEntry entry;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: SvgPicture.asset(
                  'assets/images/search.svg',
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
                title: Text(
                  entry.word,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: IconButton(
                  tooltip: '复制',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_all_outlined),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.translation,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 使用大尺寸 Icon + 文本避免空白屏幕。
          const Icon(Icons.search_off, size: 72, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => onRetry!(),
              child: const Text('重新加载'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 红色 icon 强调错误，按钮用于重新触发加载。
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
