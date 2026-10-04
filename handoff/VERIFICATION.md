# 验证记录

更新时间：2026-10-04。本文件保留多轮开发结果；“本轮”指各小节对应的阶段，不代表本次全部重跑。最新提交前验证如下；旧协议、五人制与旧 Git 基线记录单独保留。

## Git 归档阶段的提交前验证（2026-10-04）

功能基线为 `6f6c19e`，交接文档单独提交。本阶段没有修改游戏机制、打包或部署。

- Godot 4.7.2 无窗口编辑器导入完成，无脚本错误。
- 七组检查全部通过：`tests.gd` 531、`six_a_side_tests.gd` 43、`legend_models_tests.gd` 608、`physique_tests.gd` 1,995、`network_latency_tests.gd` 98、`mechanics_tests.gd` 77、`receiving_defending_tests.gd` 57，共 **3,409 项断言**。
- 基础回归含 12 场 AI 对局（共 30 球）及三次自动操控对局。
- 日志检查仅发现既知 `ERROR: Failed to read the root certificate store.`，没有其他 `ERROR:`、`SCRIPT ERROR` 或 `FAILED`。未重跑实际图形、多进程 ENet、公网或 Linux 验证。
- 提交范围检查：未加入本地引擎、存档、导出包、测试产物；没有 100 MiB 及以上文件，未发现高置信度私钥 / 令牌签名。素材来源和 `.uid` / `.import` 保留。
- `git diff --cached --check` 通过。第三方 MakeHuman `.mhclo` 原始文件自带末尾空行，使用 `.gitattributes` 中限定该路径类型的规则保留上游原文。
- 本机日志在 `space-football-demo/artifacts/git-prepush-*.log`，仍由 Git 忽略。

## 此前交接整理的验证范围

本次只核对当前源码 / 配置、球员数据与卡画清单、传奇配置和 Markdown 本地链接，并整理文档。没有启动比赛回归、图形验证或网络集成，没有打包、部署或推送。资料检查结果见 `space-football-demo/artifacts/handoff-audit-20261004.json`（本地产物，Git 忽略）。

- 386 个唯一球员 ID，26 项能力共 10,036 个值，均在 1–99；全员有身高。
- 386 个唯一卡画文件全部存在，逐文件 SHA-256 和字节数匹配清单，总计 40,666,520 字节。
- 67 份传奇配置全部能对应球员，并覆盖当前传奇范围；逆足、花式字段各 151 条缺失，与导入报告一致。
- 检查 15 份现行 / 导航 Markdown 文档的 107 个本地链接，无断链。三份历史入口原文中的旧相对链接按归档说明保留，不作为现行链接检查。
- `git diff --check` 通过；仅有既有工作区的行尾转换提示。本次没有修改游戏源码。

不能把下列历史测试重新计入本次执行数量，也不能将本机 ENet 验证解释为香港公网或 Linux 部署验证。

## 最近一次网络集成验证：网络协议 5（历史）

协议 5 的 **98 项专项**、**531 / 1995 / 77 / 57 项回归**、双向弱网与连续丢包射门验证、实际 2K 联机图形检查见 [NETWORK_GRAY_TEST.md](NETWORK_GRAY_TEST.md)。这些是此前联机优化阶段的执行结果。本地弱网模型不注入入场 / 加载 / 终场生命周期消息，没有公网或系统级 UDP 故障注入证据。

## 体型手感接入验证（历史，协议 4）

- `physique_tests.gd`：1,995 项通过；`legend_models_tests.gd`：608 项重新通过；下方八组机制回归再次全部通过（1,151 项），合计 **3,754 项**。`tests.gd` 12 个 AI 对局共 30 球，三次自动操作对局完成。
- `--verify-physique`：11 项通过，实际 2560×1440 资料页与两名传奇身体倾斜检查；`--verify-locomotion` 通过，行走/跑动/冲刺/停止和摆臂截图已检查。
- 协议 4：`verify-network.ps1 -Mechanics -PlayerHost -AlternateRoster -Rounds 2 -AllowSystemCertificateWarning`，以及 `-Mechanics -Ice -Rounds 2 -AllowSystemCertificateWarning` 两种拓扑均通过；一端上行 100ms、1/5 丢包，终场比分与帧号一致。
- 最终日志仅余已知系统 CA 库错误；网络脚本新增显式可选参数，仅精确允许该诊断，原日志和提示保留，其他错误仍失败。没有公网或真实手柄手感验证。
- 证据为 `artifacts/physique-*.log`、`physique-report.json`、`physique-*.png` 和最新步态截图。测试时限调整的诊断、完整修正边界和复现方式见 [PHYSIQUE_GAMEPLAY.md](PHYSIQUE_GAMEPLAY.md)。

## 传奇模型升级验证

- `legend_models_tests.gd`：608 项通过，覆盖 67 名传奇、各槽位外观一致、原始身高/能力不变、连续变形、骨骼和动作有效。
- `--verify-legends`：162 项通过，17 页实际 2560×1440 渲染、真实蒙皮绑定、缓存上限、十二人比赛实例、网络状态编解码恢复外观、换人重建。已查看全员联系表、近看、跑动与比赛动作截图。
- `tests.gd`：531 项重新通过；12 个 AI 对局合计 30 球，三个自动操作对局完成。
- 日志：`artifacts/legend-tests.log`、`legend-visual.log`、`legend-regression.log`。最终无脚本/着色器/材质错误；保留已有沙箱证书库读取错误。
- 命令、证据和未验证范围详见 [LEGEND_MODELS.md](LEGEND_MODELS.md)。本轮没有新增真手柄、安卓或公网验证，也没有重跑多进程 ENet。

## 六人制升级阶段的执行结果（历史）

| 检查入口 | 六人制结果 | 本机证据 |
| --- | --- | --- |
| `tests.gd` | 531 项通过；12 个 AI 对局共 30 粒进球；三次自动操控对局完成 | `artifacts/six-tests.log` |
| `action_net_tests.gd` | 185 项通过 | `artifacts/six-action_net_tests.log` |
| `mechanics_tests.gd` | 77 项通过 | `artifacts/six-mechanics_tests.log` |
| `receiving_defending_tests.gd` | 57 项通过 | `artifacts/six-receiving_defending_tests.log` |
| `keeper_goal_tests.gd` | 31 项通过 | `artifacts/six-keeper_goal_tests.log` |
| `pitch_modes_tests.gd` | 49 项通过 | `artifacts/six-pitch_modes_tests.log` |
| `restart_impact_tests.gd` | 178 项通过 | `artifacts/six-restart_impact_tests.log` |
| `six_a_side_tests.gd` | 43 项通过；六人操作、退距、球门区、旧存档、室内选项、触球事件时效 | `artifacts/six-six_a_side_tests.log` |
| `--verify-six` | 8 项通过；实际 2560×1440，所测大力射门即时位移 8.206 像素，匹配标定值 | `artifacts/six-visual.log`、`six-visual.json` |
| `--verify-input` | 79 项通过，合成键盘／控制器菜单与操作 | `artifacts/six-input.log` |
| `--verify-loading` | 12 项通过；十二人分数进度、加载期间冻结、重赛与取消 | `artifacts/six-loading.log` |
| `verify-network.ps1 -Rules -Ice -Rounds 2` | 独立服务器 + 两客户端，两轮通过 | `artifacts/six-network-ice.log` |
| `verify-network.ps1 -Rules -PlayerHost -AlternateRoster -Rounds 2` | 玩家主机 + 客户端，自定义六人阵容，两轮通过 | `artifacts/six-network-host.log` |

八组无窗口检查共 **1,151 项断言**。本轮联机仍是本机真实 ENet 进程，一端上行 100ms、每五包丢一包，各端比分与终场帧号一致；不代表公网下行抖动测试。

新增复现入口：

```powershell
.\godot.cmd --headless --path space-football-demo --script six_a_side_tests.gd
.\godot.cmd --path space-football-demo --fullscreen --resolution 2560x1440 -- --verify-six
.\godot.cmd --path space-football-demo --fullscreen --resolution 2560x1440 -- --verify-loading
```

已查看 `six-squad.png`、`six-campaign.png`、`six-lineups.png`、`six-free-kick.png` 等实际画面。截图与日志仍被 Git 忽略。新图形验证没有保存或覆盖玩家的球队／战役存档。

## 上一轮五人制验证（历史）

以下对应旧基线 `884c4e6d718fa6e9e4309fa11c21515130d078ff`，不能当作当前六人制的纯净克隆或旧动作专项图形验证。

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
