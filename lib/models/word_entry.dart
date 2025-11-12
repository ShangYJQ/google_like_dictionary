/// 词典中的原子数据模型（不可变值对象）。
///
/// 每条记录同时保存英文原词 [`word`] 与对应的中文释义 [`translation`]。模型尽量保持轻量，
/// 这样就算一次性创建十万条记录也不会对 GC 造成明显压力，便于在内存中做快速搜索。
class WordEntry {
  /// 直接通过两个字符串构造 [WordEntry]。
  const WordEntry({
    required this.word,
    required this.translation,
  }); // 不可变构造，必须提供中英

  /// 英文字段
  final String word;

  /// 对应的中文含义
  final String translation;

  /// 利用 CSV 中的一行原始数据创建 [WordEntry]。
  factory WordEntry.fromCsvRow(List<dynamic> row) {
    if (row.length < 2) {
      // 至少包含两列：英文、中文
      throw ArgumentError('CSV row 要有中英！'); // 行格式不正确
    }

    return WordEntry(
      word: (row[0] ?? '').toString().trim(), // 清理空白并确保为字符串
      translation: (row[1] ?? '').toString().trim(), // 清理空白并确保为字符串
    );
  }

  /// 判断 [query] 是否同时或分别命中英文或中文字段（不区分大小写）。
  bool matches(String query) {
    if (query.isEmpty) return true; // 空查询直接命中
    final lowerQuery = query.toLowerCase(); // 统一转小写进行不区分大小写匹配
    return word.toLowerCase().contains(lowerQuery) || // 英文字段包含
        translation.toLowerCase().contains(lowerQuery); // 中文字段包含
  }
}
