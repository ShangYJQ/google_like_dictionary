import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:google_like_dictionary/data/dictionary_repository.dart';
import 'package:google_like_dictionary/models/word_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DictionaryRepository', () {
    test('parses CSV rows and skips header', () async {
      final bundle = _FakeBundle(
        '''
"word","translation"
"apple","n. 苹果"
"beta","n. 测试版本"
''',
      );

      final repository = DictionaryRepository(bundle: bundle);
      final entries = await repository.loadEntries();

      expect(entries.length, 2);
      expect(entries.first.word, 'apple');
      expect(entries.last.translation, 'n. 测试版本');
    });
  });

  group('WordEntry', () {
    test('matches finds query in word or translation', () {
      const entry = WordEntry(word: 'network', translation: 'n. 网络; 网状物');
      expect(entry.matches('net'), isTrue);
      expect(entry.matches('网络'), isTrue);
      expect(entry.matches('xyz'), isFalse);
    });
  });
}

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._data);
  final String _data;

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return _data;
  }
}
