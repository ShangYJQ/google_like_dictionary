# google_like_dictionary

一个简洁的英汉词典应用，提供快速检索、释义查看与复制等能力，界面风格参考 Google 搜索。

## 功能亮点

- **离线词库**：启动时从 `assets/data/EnWords.csv` 解析 10w+ 词条，并做内存缓存。
- **智能搜索**：输入框实时筛选（含缩写、中文释义），自动节流避免卡顿。
- **结果展示**：卡片式列表支持点击展开详情、复制释义、下拉刷新。
- **多端支持**：基于 Flutter，可运行在 Android、iOS、Web、Windows。

## 开发命令

```bash
flutter pub get           # 安装依赖
flutter run -d chrome     # Web 端热重载调试
flutter analyze           # 静态检查
flutter test --coverage   # 执行测试并生成覆盖率
```

> Windows 安装的 Flutter SDK 可能带有 CRLF 换行，若在 WSL 中运行上述命令失败，请先对 `flutter/bin/*.sh` 执行 `dos2unix`。

## 目录结构

```
assets/
  data/EnWords.csv    # 词典数据
  images/google.svg   # 顶部 Logo
lib/
  data/               # 数据层（CSV 解析、缓存）
  features/           # 业务控制器
  models/             # 实体定义
  main.dart           # UI 入口
test/                 # 单元与组件测试
```

## 贡献说明

遵循 Conventional Commits（例如 `feat(search): add accent matching`）。提交前执行 `flutter analyze` 与 `flutter test` 并在 PR 中附上测试结果/截图。更多细节参见 `AGENTS.md`。
