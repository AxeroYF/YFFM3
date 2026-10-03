# YFFM3 · 群星绿茵

基于 Godot 的星际五人制足球游戏，当前处于开发阶段。每位玩家控制一支五人球队，可切换球员；支持本地对 AI 和服务器权威计算的联机比赛。

## 当前内容

- 经典五人制与冰球反弹模式，快速比赛自动生成位置合理的双方阵容。
- 386 名带卡画的球员，保留原始 26 项能力值，并映射到操作手感、跑位、接球和防守。
- 传球、直塞、传中、蓄力射门、搓射、挑射、头球、凌空、普通抢断、滑铲及门将动作。
- 边线球、角球、任意球、犯规、换人、进球入网和回放。
- 键盘及 Xbox 风格手柄操作，多级辅助、菜单导航和设备按键提示。
- 原生开发分辨率 2560×1440。安卓仅保留输入接入口，暂未开展打包与设备测试。

## 项目结构

| 路径 | 内容 |
| --- | --- |
| `space-football-demo/` | 当前主游戏、比赛模拟、联网、界面及测试 |
| `space-football-demo/assets/player-library/` | 球员资料、完整原始数据快照、卡画和校验清单 |
| `space-football-demo/assets/humanoid/` | 连续人体模型、纹理及资源许可 |
| `player-card-demo/` | 早期球员卡视觉原型 |
| `starfield-demo/` | 早期星空视觉原型 |
| `scripts/` | 球员库导入和人体资源处理脚本 |
| `tools/makehuman-assets/` | 人体模型源素材及来源记录 |

主游戏文件夹名称沿用早期开发路径，当前功能开发以该目录为准。

## 开发环境与启动

当前已验证版本为 **Godot 4.7.2 stable，Windows x86_64 标准版 / GDScript**。游戏本身不需要 .NET 或 Node.js；资源处理脚本使用 Node.js。

仓库不包含 Godot 安装程序、导出模板、导入缓存、游戏存档、测试截图与历史构建。

首次克隆后：

1. 从 [Godot 官方版本页](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable) 下载标准版 Windows x86_64 编辑器。
2. 将 `Godot_v4.7.2-stable_win64.exe` 和 `Godot_v4.7.2-stable_win64_console.exe` 解压到项目的 `tools/godot/`。
3. 运行 `Edit-Space-Football.cmd` 完成首次导入，或在已有 Godot 编辑器中导入 `space-football-demo/project.godot`。
4. 运行 `Start-Quick-Match-Dev.cmd` 测试快速比赛，或 `Start-Space-Football.cmd` 打开主菜单。

使用其他位置的编辑器也可以直接打开 `project.godot`。根目录脚本使用上述便携路径，并将用户存档放入 `tools/godot/user_data/`。开发运行不要求安装导出模板。

## 验证

在项目根目录运行 PowerShell：

```powershell
New-Item -ItemType Directory -Force space-football-demo/artifacts | Out-Null
.\godot.cmd --headless --path space-football-demo --editor --quit
.\godot.cmd --headless --path space-football-demo --script tests.gd
.\godot.cmd --headless --path space-football-demo --script action_net_tests.gd
.\godot.cmd --headless --path space-football-demo --script mechanics_tests.gd
.\godot.cmd --headless --path space-football-demo --script receiving_defending_tests.gd
.\godot.cmd --headless --path space-football-demo --script keeper_goal_tests.gd
.\godot.cmd --headless --path space-football-demo --script pitch_modes_tests.gd
.\godot.cmd --headless --path space-football-demo --script restart_impact_tests.gd
```

实际窗口与联机验证：

```powershell
.\godot.cmd --path space-football-demo --fullscreen --resolution 2560x1440 -- --verify-action-net
.\godot.cmd --path space-football-demo --fullscreen --resolution 2560x1440 -- --verify-input
powershell -NoProfile -File space-football-demo/verify-network.ps1 -Rules -Ice -Rounds 2 -Port 28835
powershell -NoProfile -File space-football-demo/verify-network.ps1 -Rules -PlayerHost -Rounds 2 -Port 28836
```

最近完整验证记录见 `space-football-demo/动作与入网优化说明.txt`。控制器自动验证使用合成输入，真实手柄的震动和操作手感需要实机体验。动画目前为程序骨骼动画。

## 版本管理

本目录是独立仓库，初始开发分支为 `codex/yffm3`。代码、Godot 资源导入配置、`.uid`、美术源素材和数据全部纳入版本管理。单个源文件均低于 GitHub 普通 Git 的文件大小限制，当前不要求 Git LFS。

日常提交前检查 `git status` 和 `git diff`，运行与改动相关的验证，再提交和推送。避免加入本地引擎、存档、截图、安装包、导出程序或凭据。

## 资源来源

保留各素材目录已有的许可与来源说明。人体素材的 CC0 许可见 `space-football-demo/assets/humanoid/LICENSE.CC0.txt`；球员卡画沿用前作导入资料与清单。本仓库为私有开发仓库，未对整个项目新增开源许可证。
