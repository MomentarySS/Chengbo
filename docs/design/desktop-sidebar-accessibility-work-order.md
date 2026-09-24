# Windows 侧栏交互与关键流程测试工单

状态：已完成（2026-09-24）　范围：ROADMAP.md「仍需推进」第 1、2 项

## 目标

- 鼠标移入或键盘聚焦侧栏的队列项、收藏电台项时，显示该行的次操作。
- 侧栏可用 Tab / Shift+Tab 遍历控件，用上下方向键在可操作行间移动，并用 Enter / Space 激活当前控件。
- 扩充关键交互的 widget 回归测试；播放状态、队列顺序、收藏持久化和其他窗口形态的既有快捷键语义保持不变。

## 变更前分析

| 文件 | 计划变更 | 与主功能的关系 |
|---|---|---|
| `lib/shared/widgets/desk_sidebar_window.dart` | 增加队列项「从队列移除」和收藏项「取消收藏」次操作；用 Material 焦点状态显示 hover / focus affordance；提供侧栏焦点遍历 widget | 复用现有 `playQueueProvider` / `favoriteIdsProvider`。点击整行仍分别播放队列项或收藏台；不改队列和收藏数据模型 |
| `lib/features/home/home_shell.dart` | 侧栏模式挂载键盘遍历范围 | 仅包裹 Windows 侧栏分支，其他页面树和 Android 不变 |
| `lib/core/platform/desk_hotkey.dart` | 为侧栏焦点导航增加全局快捷键让行判断 | 仅在侧栏窗口模式下让全局空格 / 方向键快捷键让位给焦点控件；Ctrl+Shift+S 与其他窗口形态的播放快捷键不变 |
| `lib/shared/widgets/desk_hotkey_scope.dart` | 读取窗口模式并把键盘上下文传给快捷键逻辑 | 侧栏模式下禁用全局空格播停和播客方向键跳转，避免与行激活 / 焦点移动抢键；编辑控件继续由既有保护逻辑处理 |
| `test/desk_sidebar_window_test.dart`（新增） | 覆盖 hover / focus 次操作、队列与收藏回调、行点击播放，以及 Tab / 方向键 / Enter / Space | 使用内存存储与 provider 测试替身，不连接真实音频设备或 Windows 托盘 |
| `test/layer_test.dart` | 覆盖快捷键在侧栏和其他窗口模式中的映射 | 守住全局键盘快捷键与新局部导航的边界 |
| `ROADMAP.md` | 两项完成后标记状态并保留测试覆盖的扩展方向 | 文档同步，不影响运行时 |

## 冲突与处理

1. **全局快捷键先于 Flutter 焦点遍历处理按键**：当前 `DeskHotkeyScope` 全局捕获空格和方向键。侧栏模式必须让这些键返回给局部控件，否则方向键仍会跳播客、空格可能播停。侧栏局部遍历使用 Flutter `Shortcuts` / `FocusTraversalGroup`；Ctrl+Shift+S 仍全局有效。
2. **主操作与次操作容易重叠**：整行点击已经执行播放，因此队列行次操作选「移除」，收藏行次操作选「取消收藏」；按钮阻止点击冒泡，避免一次操作同时播放。
3. **拖动窗口与行 hover 的命中区域**：窗口拖动只绑定标题栏，不把 `MouseRegion` 扩展到整窗；列表滚动和点击热区保持原尺寸。
4. **触屏 / 非 Windows 回归**：侧栏仅由 Windows 窗口模式进入；改动不调整 Android 的列表、播放器或手势。

## 验收测试

- 鼠标移入队列项 / 收藏项时次操作出现，移出后隐藏；键盘焦点进入行时也可见。
- 队列次操作只移除目标队列索引；收藏次操作只切换目标台的收藏状态；点行仍执行原播放行为。
- Tab / Shift+Tab 可到达所有可见交互；上下键移动焦点；Enter / Space 激活焦点控件。
- 编辑控件不被全局快捷键抢占；侧栏中 Space / 方向键不再触发全局播放 / 跳秒；侧栏 Ctrl+Shift+S 仍可切换窗口形态。
- 主窗口 / 浮条模式原有空格、播客左右跳转和 Ctrl+Shift+S 行为保持不变。
- 运行定向 widget / logic tests、完整 `flutter test --no-pub`、`flutter analyze --no-pub` 与 `git diff --check`；分析器基线提示单独记录。

## 非目标

- 不改播放服务、队列持久化格式、托盘 API、Android 页面或侧栏整体视觉规格。
- 不新增全局自定义按键绑定设置；继续沿用当前固定快捷键。
- 不把测试覆盖率数字当作验收门槛；本批覆盖新增交互和最容易冲突的关键流程。

## 实施记录

- 侧栏队列项 hover / focus 时显示「从队列移除」，收藏项显示「取消收藏」；点击行原有播放行为保留。
- Windows 侧栏使用 Tab / Shift+Tab 和上下方向键遍历；焦点控件可用 Enter / Space 激活。侧栏模式下全局空格播停与播客左右跳转让位给控件，Ctrl+Shift+S 保留。
- 新增 3 个侧栏 widget tests，覆盖次操作、焦点显示、焦点移动和按键激活；layer test 覆盖快捷键隔离。
- `flutter test --no-pub --reporter compact`：175 项通过。
- `flutter analyze --no-pub`：无 error / warning；报告 15 条既有 info，因此 Flutter 命令以 exit code 1 结束。提示位于本次未改动的代码位置。
- `git diff --check`：通过。
