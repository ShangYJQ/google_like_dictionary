import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

import '../models/word_entry.dart';

/// 负责加载与缓存词典数据的仓库层。
///
/// 仓库会从打包在工程内的 CSV 读取所有词条，转换成强类型的 [WordEntry] 列表，
/// 并将结果缓存在内存里，从而避免每次搜索都重新访问 AssetBundle。通过注入
/// [AssetBundle]，可以在测试环境中提供假资源。
class DictionaryRepository {
  DictionaryRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle,
      // csv 解析器
      _converter = const CsvToListConverter(shouldParseNumbers: false);

  /// 用于读取静态资源的 bundle，测试时可替换。
  final AssetBundle _bundle;

  /// 共享的 CSV 解析器，避免重复创建对象。
  final CsvToListConverter _converter;

  /// 内存中的词条缓存
  List<WordEntry>? _cache;

  /// 从 CSV 中加载所有词条；必要时可以跳过缓存强制刷新。
  Future<List<WordEntry>> loadEntries({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) {
      return _cache!;
    }

    final raw = await _bundle.loadString('assets/data/EnWords.csv');
    final rows = _converter.convert(raw);

    final entries = <WordEntry>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      if (row.length >= 2) {
        final first = (row[0] ?? '').toString().trim().toLowerCase();
        final second = (row[1] ?? '').toString().trim().toLowerCase();
        if (first == 'word' && second == 'translation') {
          continue; // 跳过表头
        }
      }
      try {
        final entry = WordEntry.fromCsvRow(row);
        if (entry.word.isEmpty || entry.translation.isEmpty) continue;
        entries.add(entry);
      } on ArgumentError {
        continue;
      }
    }

    _cache = entries;
    return entries;
  }
}
