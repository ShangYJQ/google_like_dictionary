/// AVL 树节点，保存键、值集合以及左右子树和高度信息。
/// 使用泛型 K/V，允许同一键对应多个值。
class AvlNode<K, V> {
  AvlNode(this.key, this.values);

  K key; // 键（用于排序）
  List<V> values; // 该键对应的值集合（允许重复键聚合）
  AvlNode<K, V>? left; // 左子树
  AvlNode<K, V>? right; // 右子树
  int height = 1; // 当前节点高度（叶子为 1）
}

/// 一个最小实现的 AVL 树 Map：
/// - 按给定 `compare` 比较器对键排序；
/// - 同一键可存储多个值（使用 List<V> 聚合）；
/// - 提供按范围遍历以支持前缀检索。
class AvlMap<K, V> {
  AvlMap({required this.compare});

  final int Function(K a, K b) compare;
  AvlNode<K, V>? _root;

  bool get isEmpty => _root == null;

  /// 插入一个键值对；若键已存在则将值追加到该键的列表。
  void insert(K key, V value) {
    _root = _insert(_root, key, value);
  }

  /// 根据键查找对应的值列表（若不存在返回 null）。
  List<V>? get(K key) {
    var n = _root; // 从根节点开始
    while (n != null) {
      // 二叉搜索
      final c = compare(key, n.key); // 比较传入键与当前节点键
      if (c == 0) return n.values; // 命中返回
      if (c < 0) {
        n = n.left; // 小于则去左子树
      } else {
        n = n.right; // 大于则去右子树
      }
    }
    return null; // 未找到
  }

  /// 按键的闭区间 [low, high] 中序遍历，针对每个命中键回调 f。
  void forEachInRange(K low, K high, void Function(K key, List<V> values) f) {
    _forEachInRange(_root, low, high, f);
  }

  /// 内部插入实现：返回子树新的根节点（可能经过旋转平衡）。
  AvlNode<K, V>? _insert(AvlNode<K, V>? node, K key, V value) {
    if (node == null) {
      return AvlNode<K, V>(key, [value]); // 新建叶子节点
    }
    final c = compare(key, node.key);
    if (c == 0) {
      node.values.add(value); // 相同键，追加到列表
      return node;
    } else if (c < 0) {
      node.left = _insert(node.left, key, value); // 插入到左子树
    } else {
      node.right = _insert(node.right, key, value); // 插入到右子树
    }
    _updateHeight(node); // 回溯更新高度
    return _balance(node); // 局部平衡旋转
  }

  /// 递归中序遍历闭区间 [low, high]。
  void _forEachInRange(
    AvlNode<K, V>? node,
    K low,
    K high,
    void Function(K, List<V>) f,
  ) {
    if (node == null) return; // 递归终止
    if (compare(low, node.key) < 0) {
      _forEachInRange(node.left, low, high, f); // 左侧仍有可能命中
    }
    if (compare(low, node.key) <= 0 && compare(node.key, high) <= 0) {
      f(node.key, node.values); // 当前节点在区间内
    }
    if (compare(node.key, high) < 0) {
      _forEachInRange(node.right, low, high, f); // 右侧仍有可能命中
    }
  }

  /// 空节点高度为 0，叶子节点高度为其自身的 `height`。
  int _height(AvlNode<K, V>? n) => n?.height ?? 0;

  /// 平衡因子 = 左高 - 右高；理想范围为 [-1, 1]。
  int _balanceFactor(AvlNode<K, V>? n) =>
      n == null ? 0 : _height(n.left) - _height(n.right);

  /// 根据左右子树高度更新当前节点高度。
  void _updateHeight(AvlNode<K, V> n) {
    final hl = _height(n.left); // 左子树高度
    final hr = _height(n.right); // 右子树高度
    n.height = (hl > hr ? hl : hr) + 1; // 取较大者 + 1
  }

  /// 右旋（以 y 为根，x = y.left）。
  AvlNode<K, V> _rotateRight(AvlNode<K, V> y) {
    final x = y.left!; // 新根
    final t2 = x.right; // 暂存 x 的右子树
    x.right = y; // y 作为 x 的右孩子
    y.left = t2; // 原 x.right 挂接到 y.left
    _updateHeight(y);
    _updateHeight(x);
    return x;
  }

  /// 左旋（以 x 为根，y = x.right）。
  AvlNode<K, V> _rotateLeft(AvlNode<K, V> x) {
    final y = x.right!; // 新根
    final t2 = y.left; // 暂存 y 的左子树
    y.left = x; // x 作为 y 的左孩子
    x.right = t2; // 原 y.left 挂接到 x.right
    _updateHeight(x);
    _updateHeight(y);
    return y;
  }

  /// 根据平衡因子对以 n 为根的子树进行必要的旋转（LL/LR/RR/RL）。
  AvlNode<K, V> _balance(AvlNode<K, V> n) {
    final bf = _balanceFactor(n);
    if (bf > 1) {
      // 左侧过高
      if (_balanceFactor(n.left) < 0) {
        // LR 型：先对左子树左旋
        n.left = _rotateLeft(n.left!);
      }
      return _rotateRight(n); // LL 型：右旋
    }
    if (bf < -1) {
      // 右侧过高
      if (_balanceFactor(n.right) > 0) {
        // RL 型：先对右子树右旋
        n.right = _rotateRight(n.right!);
      }
      return _rotateLeft(n); // RR 型：左旋
    }
    return n; // 已平衡
  }
}
