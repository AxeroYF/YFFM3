# 验证记录

记录时间：2026-10-04。对应游戏代码基线：`884c4e6d718fa6e9e4309fa11c21515130d078ff`。

## 最近实际执行结果

| 检查入口 | 结果 | 本机证据 |
| --- | --- | --- |
| `tests.gd` | 530 项通过；12 个 AI 对局共 12 粒进球；三个自动操控场景均完成 | `artifacts/actions-core-tests.log` |
| `action_net_tests.gd` | 185 项通过，含四角/边线追球、沿边带球逼抢、整球越线、球网、动作触发/骨骼/同步 | `artifacts/action-net-tests.log` |
| `mechanics_tests.gd` | 77 项通过 | `artifacts/actions-mechanics_tests.log` |
| `receiving_defending_tests.gd` | 57 项通过 | `artifacts/actions-receiving_defending_tests.log` |
| `keeper_goal_tests.gd` | 31 项通过 | `artifacts/actions-keeper_goal_tests.log` |
| `pitch_modes_tests.gd` | 49 项通过 | `artifacts/actions-pitch_modes_tests.log` |
| `restart_impact_tests.gd` | 178 项通过 | `artifacts/actions-restart_impact_tests.log` |
| `--verify-action-net` | 6 项通过，实际 2560×1440 渲染 | `artifacts/action-net-visual.log` |
| `--verify-keeper-goal` | 18 项通过，含回放、跳过、金球和门将 | `artifacts/actions-keeper-visual.log` |
| `--verify-input` | 79 项通过，键盘与模拟控制器菜单/比赛操作 | `artifacts/actions-input-visual.log` |
| `verify-network.ps1 -Rules -Ice -Rounds 2` | 独立服务器 + 两客户端，两轮通过 | `artifacts/actions-network-ice.log` |
| `verify-network.ps1 -Rules -PlayerHost -Rounds 2` | 玩家主机 + 客户端，两轮通过 | `artifacts/actions-network-host.log` |

上述 `artifacts/` 均相对 `space-football-demo/`。七组无窗口检查共 1,107 项；计数为断言数量，不代表同等数量的独立机制。

联机场景包含一端上行延迟 100ms、每五包丢一包；记录球网碰撞，各端终场比分和帧号一致。逐进程日志 `network-server.log`、`network-client-a.log`、`network-client-b.log` 会被后续同类运行覆盖。

## 从 Git 恢复的纯净副本验证

首次提交后，使用 `git archive` 从上述提交导出不含缓存、引擎和未提交文件的副本，随后：

1. 使用本机已安装的 Godot 4.7.2 完成主项目首次无窗口导入，无脚本错误。
2. 在该副本运行 `action_net_tests.gd`，185 项通过。

本机证据：`tools/verification/git-baseline-import.log`、`tools/verification/git-baseline-tests.log`；临时副本位于 `tools/verification/git-baseline-884c4e6/`。这些均为被忽略的验证产物，不需要提交或依赖它们继续开发。

## 可复现命令

在仓库根目录 PowerShell 执行；先按根目录 README 安装匹配的编辑器：

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

窗口检查应逐项运行，避免多个全屏进程争用显示器：

```powershell
.\godot.cmd --path space-football-demo --fullscreen --resolution 2560x1440 -- --verify-action-net
.\godot.cmd --path space-football-demo --fullscreen --resolution 2560x1440 -- --verify-keeper-goal
.\godot.cmd --path space-football-demo --fullscreen --resolution 2560x1440 -- --verify-input
powershell -NoProfile -File space-football-demo/verify-network.ps1 -Rules -Ice -Rounds 2 -Port 28835
powershell -NoProfile -File space-football-demo/verify-network.ps1 -Rules -PlayerHost -Rounds 2 -Port 28836
```

日志既要有对应 `PASS`，也要没有 `SCRIPT ERROR` / `ERROR:` / `FAILED`。Godot 编辑器导入有时会在输出错误后仍返回退出码 0，因此不能只看退出码。

## 人工画面检查与边界

- 已查看实际 2K 动作对照图及入网图片，修正了动作双臂平举和球门内地面衔接。
- 本机图片：`actions-1.png`、`actions-2.png`、`goal-net-4.png`、`goal-net-15.png`、`goal-net-40.png`，均位于主项目 `artifacts/`。
- 未做真实 Xbox 手柄震动验收；自动按键测试为合成输入。
- 未做安卓设备测试、安卓打包或本轮 Windows 发布打包。
- 未做公网/跨地域联机、长期性能或生产运维验收。
- 声音、动画真实感和操作手感仍以用户实测反馈为准。

原始日志、截图和本机 `action-net-delivery-verification.json` 被 Git 忽略；本文件保存可随仓库交接的结果摘要及复现步骤。
