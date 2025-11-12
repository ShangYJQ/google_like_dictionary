import 'package:csv/csv.dart'; // CSV 解析器
import 'package:flutter/services.dart'; // AssetBundle 读取静态资源

import '../models/word_entry.dart'; // 词条模型

/// 负责加载与缓存词典数据的仓库层。
///
/// 仓库会从打包在工程内的 CSV 读取所有词条，转换成强类型的 [WordEntry] 列表，
/// 并将结果缓存在内存里，从而避免每次搜索都重新访问 AssetBundle。通过注入
/// [AssetBundle]，可以在测试环境中提供假资源。
class DictionaryRepository {
  DictionaryRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle,
      // 允许注入自定义 bundle（便于测试），默认使用全局 rootBundle
      // csv 解析器
      _converter = const CsvToListConverter(
        shouldParseNumbers: false,
      ); // 不解析为数字，保留原始字符串

  /// 用于读取静态资源的 bundle，测试时可替换。
  final AssetBundle _bundle; // 用于加载打包资源（assets）

  /// 共享的 CSV 解析器，避免重复创建对象。
  final CsvToListConverter _converter; // 共享解析器实例，避免频繁创建

  /// 内存中的词条缓存
  List<WordEntry>? _cache; // 内存缓存，避免重复 IO 与解析

  /// 从 CSV 中加载所有词条；必要时可以跳过缓存强制刷新。
  Future<List<WordEntry>> loadEntries({bool forceRefresh = false}) async {
    // 是否强制刷新
    if (!forceRefresh && _cache != null) {
      // 命中缓存：直接返回
      return _cache!;
    }

    final raw = await _bundle.loadString(
      'assets/data/EnWords.csv',
    ); // 读取项目内置 CSV
    final rows = _converter.convert(raw); // 解析为二维表（List<List<dynamic>>）

    final entries = <WordEntry>[];
    for (var i = 0; i < rows.length; i++) {
      // 遍历每一行
      final row = rows[i];
      if (row.isEmpty) continue; // 跳过空行
      if (row.length >= 2) {
        // 简单检测并跳过表头
        final first = (row[0] ?? '').toString().trim().toLowerCase();
        final second = (row[1] ?? '').toString().trim().toLowerCase();
        if (first == 'word' && second == 'translation') {
          continue; // 跳过表头
        }
      }
      try {
        final entry = WordEntry.fromCsvRow(row); // 解析每行到强类型模型
        if (entry.word.isEmpty || entry.translation.isEmpty) {
          continue; // 过滤异常/空值
        }
        entries.add(entry); // 累加到结果集
      } on ArgumentError {
        // 行格式异常：跳过
        continue;
      }
    }

    _cache = entries; // 写入缓存
    return entries; // 返回解析结果
  }
}
