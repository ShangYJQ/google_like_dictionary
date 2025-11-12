class AvlNode<K, V> {
  AvlNode(this.key, this.values);

  K key;
  List<V> values;
  AvlNode<K, V>? left;
  AvlNode<K, V>? right;
  int height = 1;
}

class AvlMap<K, V> {
  AvlMap({required this.compare});

  final int Function(K a, K b) compare;
  AvlNode<K, V>? _root;

  bool get isEmpty => _root == null;

  void insert(K key, V value) {
    _root = _insert(_root, key, value);
  }

  List<V>? get(K key) {
    var n = _root;
    while (n != null) {
      final c = compare(key, n.key);
      if (c == 0) return n.values;
      if (c < 0) {
        n = n.left;
      } else {
        n = n.right;
      }
    }
    return null;
  }

  void forEachInRange(K low, K high, void Function(K key, List<V> values) f) {
    _forEachInRange(_root, low, high, f);
  }

  AvlNode<K, V>? _insert(AvlNode<K, V>? node, K key, V value) {
    if (node == null) {
      return AvlNode<K, V>(key, [value]);
    }
    final c = compare(key, node.key);
    if (c == 0) {
      node.values.add(value);
      return node;
    } else if (c < 0) {
      node.left = _insert(node.left, key, value);
    } else {
      node.right = _insert(node.right, key, value);
    }
    _updateHeight(node);
    return _balance(node);
  }

  void _forEachInRange(
    AvlNode<K, V>? node,
    K low,
    K high,
    void Function(K, List<V>) f,
  ) {
    if (node == null) return;
    if (compare(low, node.key) < 0) {
      _forEachInRange(node.left, low, high, f);
    }
    if (compare(low, node.key) <= 0 && compare(node.key, high) <= 0) {
      f(node.key, node.values);
    }
    if (compare(node.key, high) < 0) {
      _forEachInRange(node.right, low, high, f);
    }
  }

  int _height(AvlNode<K, V>? n) => n?.height ?? 0;

  int _balanceFactor(AvlNode<K, V>? n) =>
      n == null ? 0 : _height(n.left) - _height(n.right);

  void _updateHeight(AvlNode<K, V> n) {
    final hl = _height(n.left);
    final hr = _height(n.right);
    n.height = (hl > hr ? hl : hr) + 1;
  }

  AvlNode<K, V> _rotateRight(AvlNode<K, V> y) {
    final x = y.left!;
    final t2 = x.right;
    x.right = y;
    y.left = t2;
    _updateHeight(y);
    _updateHeight(x);
    return x;
  }

  AvlNode<K, V> _rotateLeft(AvlNode<K, V> x) {
    final y = x.right!;
    final t2 = y.left;
    y.left = x;
    x.right = t2;
    _updateHeight(x);
    _updateHeight(y);
    return y;
  }

  AvlNode<K, V> _balance(AvlNode<K, V> n) {
    final bf = _balanceFactor(n);
    if (bf > 1) {
      if (_balanceFactor(n.left) < 0) {
        n.left = _rotateLeft(n.left!);
      }
      return _rotateRight(n);
    }
    if (bf < -1) {
      if (_balanceFactor(n.right) > 0) {
        n.right = _rotateRight(n.right!);
      }
      return _rotateLeft(n);
    }
    return n;
  }
}
