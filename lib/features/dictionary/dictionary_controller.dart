import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/dictionary_repository.dart';
import '../../models/word_entry.dart';
import '../../data_structures/avl.dart';

/// 连接 UI 与数据层的核心控制器。
///
/// 负责管理词典数据的完整生命周期：首次启动时加载 CSV，维护 loading/错误状态、
/// 筛选后的结果集，并对输入进行节流，保证搜索体验顺畅。
enum SearchStrategy { linear, avl } // 线性扫描 / AVL 索引

class DictionaryController extends ChangeNotifier {
  DictionaryController(this._repository);

  final DictionaryRepository _repository; // 数据仓库（负责加载/缓存 CSV 词库）

  /// 保存所有解析完成的 [WordEntry]。
  final List<WordEntry> _entries = []; // 全量词条数据

  /// 当前查询条件下需要展示的子集。
  List<WordEntry> _visibleEntries = []; // 根据查询筛选出来的列表

  bool _isLoading = false; // 加载状态（驱动骨架/进度条）
  String? _error; // 错误消息（展示在错误态）
  String _query = ''; // 原始搜索词
  Timer? _debounce; // 输入节流定时器
  Duration? _lastSearchDuration; // 最近一次搜索耗时
  SearchStrategy _strategy = SearchStrategy.linear; // 当前搜索策略
  AvlMap<String, WordEntry>? _avl; // 单词小写 -> 词条 的索引结构

  bool get isLoading => _isLoading;

  String? get errorMessage => _error;

  String get query => _query;

  List<WordEntry> get visibleEntries => _visibleEntries;

  int get totalEntries => _entries.length;

  Duration? get lastSearchDuration => _lastSearchDuration;

  SearchStrategy get strategy => _strategy;

  /// 首次加载词典数据并在完成后通知监听者。
  ///
  /// 如果内部列表已有数据，则忽略后续重复调用，避免 Widget 重建时再次触发 IO。
  Future<void> load() async {
    if (_isLoading || _entries.isNotEmpty) return; // 避免重复加载
    _setLoading(true); // 切换到加载态
    try {
      final entries = await _repository.loadEntries(); // IO：读取 CSV 并解析
      _entries
        ..clear() // 保持引用不变，减少潜在观察者失效
        ..addAll(entries); // 批量写入
      _buildAvlIndex(); // 重建 AVL 索引
      _applyFilter(); // 初始化可见列表
      _error = null; // 清空错误
    } catch (error, stackTrace) {
      debugPrint('Dictionary load error: $error\n$stackTrace'); // 记录日志
      _error = '无法加载词库，请稍后重试。'; // 用户可读的错误
    } finally {
      _setLoading(false); // 结束加载态
    }
  }

  /// 即使已有缓存也会重新读取磁盘，用于下拉刷新或错误重试。
  Future<void> refresh() async {
    _setLoading(true); // 显示刷新中的状态
    try {
      final entries = await _repository.loadEntries(
        forceRefresh: true,
      ); // 强制绕过缓存
      _entries
        ..clear()
        ..addAll(entries);
      _buildAvlIndex(); // 重新索引
      _applyFilter(); // 重新筛选
      _error = null; // 清空错误
    } catch (error, stackTrace) {
      debugPrint('Dictionary refresh error: $error\n$stackTrace'); // 记录日志
      _error = '刷新失败，请稍后再试。'; // 用户提示
    } finally {
      _setLoading(false); // 收起刷新态
    }
  }

  /// 处理原始搜索输入，并在节流时间到达后触发筛选。
  void updateQuery(String value) {
    _query = value; // 更新查询词
    _debounce?.cancel(); // 取消上一次节流任务
    _debounce = Timer(
      const Duration(milliseconds: 120),
      _applyFilter,
    ); // 120ms 后执行筛选
  }

  /// 清空搜索条件，回到默认的前 N 条列表。
  void clearQuery() {
    if (_query.isEmpty) return; // 无需重复清空
    _query = ''; // 置空查询
    _applyFilter(); // 刷新可见列表
  }

  void setStrategy(SearchStrategy strategy) {
    if (_strategy == strategy) return; // 未变更，直接返回
    _strategy = strategy; // 切换策略
    _applyFilter(); // 用新的策略重新筛选
  }

  void _buildAvlIndex() {
    final map = AvlMap<String, WordEntry>(
      compare: (a, b) => a.compareTo(b),
    ); // 字典序比较器
    for (final e in _entries) {
      final key = e.word.toLowerCase(); // 用小写单词作为键，支持不区分大小写
      map.insert(key, e); // 同键聚合多个词条（处理同形词）
    }
    _avl = map; // 替换索引引用
  }

  /// 根据 [_query] 计算 [_visibleEntries]。
  ///
  /// - 数据未加载完成时返回空列表；
  /// - 无查询词时仅展示前 50 条，防止一次渲染过多组件；
  /// - 搜索时最多保留 150 条，兼顾覆盖面与流畅度。
  void _applyFilter() {
    if (_entries.isEmpty) {
      // 尚未加载数据
      _visibleEntries = const [];
      _lastSearchDuration = null;
    } else if (_query.isEmpty) {
      // 无查询词：展示前 50 条
      _visibleEntries = _entries.take(50).toList(growable: false);
      _lastSearchDuration = null;
    } else {
      // 有查询词：根据策略筛选
      final sw = Stopwatch()..start(); // 计时
      final lowerQuery = _query.toLowerCase(); // 统一转小写

      if (_strategy == SearchStrategy.linear) {
        // 线性遍历
        int rank(WordEntry e) {
          final w = e.word.toLowerCase();
          final t = e.translation.toLowerCase();
          if (w == lowerQuery) return 0; // 完全匹配（英文）
          if (w.startsWith(lowerQuery)) return 1; // 前缀匹配（英文）
          if (w.contains(lowerQuery)) return 2; // 子串匹配（英文）
          if (t == lowerQuery) return 3; // 完全匹配（中文）
          if (t.startsWith(lowerQuery)) return 4; // 前缀匹配（中文）
          return 5; // 其它
        }

        final filtered = _entries
            .where((e) => e.matches(lowerQuery))
            .toList(); // 先筛选
        filtered.sort((a, b) {
          // 再排序：优先级 -> 更短单词 -> 字典序
          final ra = rank(a);
          final rb = rank(b);
          final cmp = ra.compareTo(rb);
          if (cmp != 0) return cmp;
          final lenCmp = a.word.length.compareTo(b.word.length);
          if (lenCmp != 0) return lenCmp;
          return a.word.toLowerCase().compareTo(b.word.toLowerCase());
        });
        _visibleEntries = filtered.take(150).toList(growable: false); // 限制上限
      } else {
        // AVL 前缀检索
        final index = _avl;
        if (index == null) {
          _visibleEntries = const [];
        } else {
          final high = '$lowerQuery\uffff'; // 使用 U+FFFF 作为闭区间上界
          final results = <WordEntry>[];
          index.forEachInRange(lowerQuery, high, (k, vs) {
            if (k.startsWith(lowerQuery)) {
              // 仅保留真正的前缀匹配
              results.addAll(vs);
            }
          });
          results.sort((a, b) {
            // 与线性策略一致的排序
            final wa = a.word.toLowerCase();
            final wb = b.word.toLowerCase();
            final ea = wa == lowerQuery
                ? 0
                : (wa.startsWith(lowerQuery) ? 1 : 2);
            final eb = wb == lowerQuery
                ? 0
                : (wb.startsWith(lowerQuery) ? 1 : 2);
            final cmp = ea.compareTo(eb);
            if (cmp != 0) return cmp;
            final lenCmp = wa.length.compareTo(wb.length);
            if (lenCmp != 0) return lenCmp;
            return wa.compareTo(wb);
          });
          _visibleEntries = results.take(150).toList(growable: false);
        }
      }
      sw.stop();
      _lastSearchDuration = sw.elapsed; // 记录耗时
    }
    notifyListeners(); // 通知 UI 刷新
  }

  /// 修改 loading 状态并立即通知监听者，驱动 UI 切换骨架或列表。
  void _setLoading(bool value) {
    _isLoading = value; // 更新状态
    notifyListeners(); // 推送给 AnimatedBuilder/Listener
  }

  @override
  void dispose() {
    _debounce?.cancel(); // 释放定时器
    super.dispose();
  }
}
