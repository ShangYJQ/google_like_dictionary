import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/dictionary_repository.dart';
import '../../models/word_entry.dart';

/// 连接 UI 与数据层的核心控制器。
///
/// 负责管理词典数据的完整生命周期：首次启动时加载 CSV，维护 loading/错误状态、
/// 筛选后的结果集，并对输入进行节流，保证搜索体验顺畅。
class DictionaryController extends ChangeNotifier {
  DictionaryController(this._repository);

  final DictionaryRepository _repository;

  /// 保存所有解析完成的 [WordEntry]。
  final List<WordEntry> _entries = [];

  /// 当前查询条件下需要展示的子集。
  List<WordEntry> _visibleEntries = [];

  bool _isLoading = false;
  String? _error;
  String _query = '';
  Timer? _debounce;

  bool get isLoading => _isLoading;

  String? get errorMessage => _error;

  String get query => _query;

  List<WordEntry> get visibleEntries => _visibleEntries;

  int get totalEntries => _entries.length;

  /// 首次加载词典数据并在完成后通知监听者。
  ///
  /// 如果内部列表已有数据，则忽略后续重复调用，避免 Widget 重建时再次触发 IO。
  Future<void> load() async {
    if (_isLoading || _entries.isNotEmpty) return;
    _setLoading(true);
    try {
      final entries = await _repository.loadEntries();
      _entries
        ..clear()
        ..addAll(entries);
      _applyFilter();
      _error = null;
    } catch (error, stackTrace) {
      debugPrint('Dictionary load error: $error\n$stackTrace');
      _error = '无法加载词库，请稍后重试。';
    } finally {
      _setLoading(false);
    }
  }

  /// 即使已有缓存也会重新读取磁盘，用于下拉刷新或错误重试。
  Future<void> refresh() async {
    _setLoading(true);
    try {
      final entries = await _repository.loadEntries(forceRefresh: true);
      _entries
        ..clear()
        ..addAll(entries);
      _applyFilter();
      _error = null;
    } catch (error, stackTrace) {
      debugPrint('Dictionary refresh error: $error\n$stackTrace');
      _error = '刷新失败，请稍后再试。';
    } finally {
      _setLoading(false);
    }
  }

  /// 处理原始搜索输入，并在节流时间到达后触发筛选。
  void updateQuery(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), _applyFilter);
  }

  /// 清空搜索条件，回到默认的前 N 条列表。
  void clearQuery() {
    if (_query.isEmpty) return;
    _query = '';
    _applyFilter();
  }

  /// 根据 [_query] 计算 [_visibleEntries]。
  ///
  /// - 数据未加载完成时返回空列表；
  /// - 无查询词时仅展示前 50 条，防止一次渲染过多组件；
  /// - 搜索时最多保留 150 条，兼顾覆盖面与流畅度。
  void _applyFilter() {
    if (_entries.isEmpty) {
      _visibleEntries = const [];
    } else if (_query.isEmpty) {
      _visibleEntries = _entries.take(50).toList(growable: false);
    } else {
      final lowerQuery = _query.toLowerCase();

      int rank(WordEntry e) {
        final w = e.word.toLowerCase();
        final t = e.translation.toLowerCase();
        if (w == lowerQuery) return 0;
        if (w.startsWith(lowerQuery)) return 1;
        if (w.contains(lowerQuery)) return 2;
        if (t == lowerQuery) return 3;
        if (t.startsWith(lowerQuery)) return 4;
        return 5;
      }

      final filtered = _entries.where((e) => e.matches(lowerQuery)).toList();
      filtered.sort((a, b) {
        final ra = rank(a);
        final rb = rank(b);
        final cmp = ra.compareTo(rb);
        if (cmp != 0) return cmp;
        final lenCmp = a.word.length.compareTo(b.word.length);
        if (lenCmp != 0) return lenCmp;
        return a.word.toLowerCase().compareTo(b.word.toLowerCase());
      });
      _visibleEntries = filtered.take(150).toList(growable: false);
    }
    notifyListeners();
  }

  /// 修改 loading 状态并立即通知监听者，驱动 UI 切换骨架或列表。
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
