## 问题

设置页点「电台管理」进入的页面 AppBar 标题显示「源」——这是该页（`SourceSettingsScreen`）沿用的旧内部名称，页面内容本身确实是电台管理功能，只是标题没跟着改。

## 修改内容（纯文案，无逻辑改动）

1. `lib/features/settings/source_screen.dart`
   - 第 54 行：`AppBar(title: const Text('源'))` → `AppBar(title: const Text('电台管理'))`
   - 第 19 行类注释「源设置：…」→「电台管理：…」（保持代码与 UI 一致）

2. `lib/features/radio/radio_screen.dart`（两处提示文案）
   - 第 126 行：「可在设置「源」中打开「显示境外电台」」→「可在设置「电台管理」中打开…」
   - 第 129 行：「连不上的台去设置「源」里更换地址」→「…设置「电台管理」里更换地址」

3. `lib/features/radio/station_catalog_setup_screen.dart`
   - 第 111 行：「之后可在「设置 → 源」里修改」→「之后可在「设置 → 电台管理」里修改」

## 验证

- 运行 `flutter analyze` 确认无编译/静态检查问题（改的是 const 字符串，风险极低）。
- 不改类名（`SourceSettingsScreen` 是内部符号，对用户不可见），避免无意义的大范围 diff。