# 项目信息与开发接续

核对日期：2026-10-06。主目录 `D:\Project\game_test\.worktrees\YFFM3`。游戏机制见 [GAMEPLAY_REFERENCE.md](GAMEPLAY_REFERENCE.md)，当前限制见 [CURRENT_STATE.md](CURRENT_STATE.md)。

最新模块分工、快照边界和统一验证入口见 [架构重构](ARCHITECTURE_REFACTOR.md)。

## 1. 技术与仓库

| 项目 | 当前配置 |
| --- | --- |
| 名称 | YFFM3 · 群星绿茵 / STARBORNE |
| 引擎 | 本地记录与启动器使用 Godot 4.7.2 stable，Windows x86_64 标准版 |
| 语言 | GDScript；资源处理脚本使用 Node.js |
| 主项目 | `space-football-demo/project.godot` → `main.tscn` → `main.gd` |
| 渲染 | Forward Plus，3D MSAA 配置值 2 |
| 画布 | 2560×1440；默认窗口 1920×1080；`canvas_items`、保持宽高比 |
| 模拟 | 固定物理频率 60 Hz |
| 仓库 | 独立公开仓库 [AxeroYF/YFFM3](https://github.com/AxeroYF/YFFM3) |
| 分支 | `codex/yffm3` |
| 当前功能基线 | `20b1921 feat: add match environments and modularize game architecture`，已推送；当前协议 7，交接文档另行提交 |
| 更早基线 | `884c4e6 feat: establish YFFM3 Godot football baseline` |

虽然目录在 `.worktrees` 下，YFFM3 自身已经是独立 Git 仓库，不能把它当作前作仓库中的普通子目录。六人制、传奇模型、身体机制和协议 5 已在 `6f6c19e` 纳入版本管理；旧提交 `78d8e94` 不包含这些进度。Git 归档前已 fetch 并确认没有远端分叉；最新文档提交与远端同步状态请用 Git 查询。

画布尺寸与物理尺寸是不同概念。字体由实际窗口上的 Control 绘制，避免将整个低分辨率画面放大造成 UI 模糊。图形验收应检查实际渲染尺寸，带边框的“2K 窗口请求”不一定有 2560×1440 内容区。

## 2. 本机启动

从仓库根目录双击或在 PowerShell 运行：

| 入口 | 用途 |
| --- | --- |
| [Start-Space-Football.cmd](../Start-Space-Football.cmd) | 正常主菜单，进入球队、快速比赛、模式及联机 |
| [Start-Quick-Match-Dev.cmd](../Start-Quick-Match-Dev.cmd) | 直接进入开发用快速比赛 |
| [Start-Legend-Models.cmd](../Start-Legend-Models.cmd) | 67 名传奇分页模型展厅 |
| [Edit-Space-Football.cmd](../Edit-Space-Football.cmd) | Godot 编辑器打开主游戏 |
| [Start-Space-Football-Server.cmd](../Start-Space-Football-Server.cmd) | 无窗口独立服务，默认 UDP 28765，日志 `artifacts/server.log` |
| [godot.cmd](../godot.cmd) | 转发 Godot 参数并隔离本地用户数据 |

启动器使用 `tools/godot/Godot_v4.7.2-stable_win64_console.exe`。该目录的引擎和用户数据不提交；新机器需自行准备对应标准版、首次导入项目。详细获取与导入步骤见 [仓库 README](../README.md)。运行游戏无需 .NET、Node.js 或导出模板；处理美术 / 导入数据时才使用相应资源工具。

常见开发命令：

```powershell
.\godot.cmd --headless --path space-football-demo --editor --quit
.\godot.cmd --path space-football-demo --fullscreen --resolution 2560x1440
.\godot.cmd --headless --path space-football-demo -- --server --port=28765
```

最后一条会启动长期运行的本地比赛服务，按需使用并在测试结束关闭。正常客户端可在联机界面创建 / 加入会话；该服务端启动参数不是网站 HTTP 入口。

## 3. 目录与职责

| 目录 / 模块 | 内容 |
| --- | --- |
| `space-football-demo/` | 当前正式推进的主游戏，目录名沿用原型时期 |
| `match_sim`、`match_mechanics`、`match_rules` | 权威状态、动作与身体交互、比赛判罚和阶段 |
| `team_ai`、`goalkeeper_ai` | 外场组织和门将判断 |
| `ball_physics`、`player_collision`、`goal_frame`、`goal_net` | 飞行、触地、人体、门框和球网 |
| `player_library`、`player_ratings`、`player_style`、`player_body`、`player_physique` | 数据、能力、偏好、身体和比例修正 |
| `player_movement`、`football_motion`、`locomotion`、`skinned_player` | 共用运动、动作参数、步态和蒙皮表现 |
| `main`、`desktop_input`、`football_input`、`match_tools` | UI / 渲染编排、菜单设备、比赛输入、回放 / 换人 / 训练工具 |
| `match_network`、`network_*` | ENet 会话、输入编码、时间线、预测、插值、分片和诊断 |
| `assets/player-library/` | 自包含球员资料、原始快照、卡画、校验清单 |
| `assets/humanoid/` | 人体、纹理、67 人配置、毛发、许可 |
| `scripts/`、`tools/makehuman-assets/` | 资源导入 / 生成脚本及源素材 |
| `player-card-demo/`、`starfield-demo/` | 早期视觉原型，不是当前比赛入口 |
| `deploy/` | Linux 共置灰度说明及 systemd 模板，未实际安装 |
| `handoff/` | 当前交接、专项记录和历史入口归档 |

完整文件表见 [MANIFEST.md](MANIFEST.md)。主模拟尽量独立于画面，便于服务器 headless 运行。客户端动画、UI 和回放不能反向改变权威比分或足球所有权。

## 4. 本地数据与存档

根目录脚本把 `APPDATA` 定向到仓库内 `tools/godot/user_data/`，Godot 再在其应用用户目录内存放 `user://` 文件。直接用其他编辑器启动、Linux 服务或修改环境变量，会使用不同位置；不能假设所有启动方式共享一份存档。

| 逻辑路径 | 内容 / 兼容 |
| --- | --- |
| `user://starborne-save.json` | 战役版本 3；航线、星币、五个外场训练、门将升级、统计；兼容版本 1 / 2 / 3 |
| `user://starborne-squad.json` | 六个首发 ID；旧五人队伍补中场 |
| `user://input-preferences.cfg` | 图标偏好、总体辅助、接球 / 射门 / 切人、震动 / 回放 / 规则 / 镜头选项 |
| F2 场景检查点 | 当前进程内存中的比赛与随机状态，不是磁盘存档 |
| `space-football-demo/artifacts/` | 测试日志、截图、报告；Git 忽略 |

战役和阵容采用临时文件写入再替换，读档校验字段与范围。验证入口可使用专用测试存档，维护测试时继续避免覆盖玩家真实阵容 / 战役。偏好文件不要当成源码默认值提交。

## 5. 联机架构与延迟处理

球场、天气与重力参数已加入本地和压缩快照，环境开发时协议由 5 升为 6，后续重构已升为 7。快照恢复和私有预测复用同一环境；联机大厅暂未提供环境选择，默认仍为标准环境。最新实现与验证见 [MATCH_ENVIRONMENT.md](MATCH_ENVIRONMENT.md)，下文保留既有联机架构。

当前协议 **7**，支持独立服务器加两客户端，也保留玩家房主加一客户端拓扑。部署优先独立服务，一场比赛一个进程。阵容 / 准备完成屏障后开始比赛，终场核对权威结果。

| 层次 | 实现和边界 |
| --- | --- |
| 权威模拟 | 60 Hz；客户端发送操作，服务端决定运动结果、接触、犯规、进球和比分 |
| 快照 | 默认 30 Hz，可指定 `--snapshots=20`；客户端也需相同设置才能正确统计缺口 |
| 输入编码 | 每帧 20 个 Float32 字段，基础 80 字节；带序号、球员 ID / 槽、换人版本，禁止任意对象直接成为权威状态 |
| 输入投递 | 最近 6 帧冗余包，有动作另走可靠备份；相同动作 ID 去重，不重复执行射门 |
| 时间线 | 起始缓冲 2 帧，动作容忍窗口 12 帧；断流 18 帧即 300 ms 后释放持续方向等状态 |
| 本方预测 | 私有模拟副本复用移动 / 转身 / 出脚，立即预览切人、蓄力、出脚与铲球；快照恢复后重放未确认输入 |
| 足球预览 | 最多前推最新快照后 250 ms，接近争抢 / 边界时回交；不预测成功碰撞裁定或比分 |
| 远端表现 | 最多 12 状态缓存，约 50–117 ms 自适应插值；球员最多外推 50 ms，普通远端球不外推门线事件 |
| 纠正 | 小误差短暂平滑；大误差、换人、阶段切换直接恢复；跨阶段清空插值 |
| 分片 | 同一打包结果供两端，1000 字节片段；最多 16 片 / 8 个待组装状态，过期丢弃 |
| 超时 | 300 ms 无新快照停止预测并提示；客户端连接 / 比赛接收超时约 10 秒，加载准备超时 45 秒；不提供断线续赛 |
| 性能 | 无窗口服务器 / 测试机器人主循环限制 60 FPS，避免忙转；监听失败返回非零退出码 |

ENet 通道分离控制、输入、快照和可靠动作备份。蓄力依据输入序号时间差，不依据包到达间隔。`match_network.gd` 保留的旧 `_predict()` 仅供旧回归探针，现行运行路径使用 `network_prediction.gd`，不要根据旧 helper 判断新实现。

这是部分本地预测与权威校正，不是完整世界回滚、命中回溯或生产级反作弊。程序和球员库应成套更新，网络数值索引依赖同一目录顺序；新动作 / 状态还要同步修改动作表、快照、恢复、打包 / 解包和预测。

### 弱网与指标

应用消息层可对所有参与者的输入、可靠动作备份、快照片段、RTT 探测双向注入延迟、抖动、周期 / 连续丢包和乱序。可靠丢失通过等待模拟重传；入场、加载屏障、终场等生命周期消息没有注入。真实 ENet 在本机运行，但这不是系统级 UDP netem，也不是大陆到香港线路测试。

每 500 ms 应用探测一次 RTT；未知显示 `--`，本地主机显示 0。每 10 秒及终场记录 `NETWORK_METRICS`，包括 RTT、快照抖动 / 缺口、纠正、待确认输入、故障模型、载荷和模拟步耗时。均值 / 峰值只能说明该次机器运行，不代表香港服务容量。

实现细节、历史证据与复现命令见 [NETWORK_GRAY_TEST.md](NETWORK_GRAY_TEST.md)。

## 6. 与 Rougelite 同机部署

用户信息：主页 `https://yellowdogsleague.online` 位于阿里云香港，现有黄狗风云 Rougelite 服务；玩家以大陆为主。读取到的前作部署资料指向 `ydl-rougelite`、`/opt/yellowdogs-rougelite/app` 及 Node.js / Nginx；没有连接生产服务器核对当前实况。

YFFM3 可以独立进程运行，能开多少场取决于共享主机的实际资源和网络。当前模板安排为：

| 项目 | 模板值 |
| --- | --- |
| 代码 / 引擎 | `/opt/yffm3/app/space-football-demo` / `/opt/yffm3/bin/godot` |
| 服务用户 | `yffm3` |
| 服务名 | `yffm3@28765.service`，可按端口实例化 |
| 网络 | UDP 28765 起；不是复用 Nginx 的 80 / 443 HTTP 接口 |
| 状态 / 缓存 | `/var/lib/yffm3/28765` / `/var/cache/yffm3/28765` |
| 资源保护 | MemoryHigh 512M、MemoryMax 768M、CPUWeight 75；是初始保护值，不是实测需求或容量保证 |
| 恢复 | 进程失败重启；不等于玩家断线重连恢复比赛 |

代码目录在服务中只读，Linux 要先使用对应引擎版本完成资源导入。主机的安全组和系统防火墙需允许测试 UDP；第一批只开一场并限制测试来源。可规划独立解析的 `match-hk.yellowdogsleague.online`，但没有创建该记录。普通网站代理不自动转发这条游戏 UDP 服务。

按 [deploy/README.md](../deploy/README.md) 及 [systemd 模板](../deploy/yffm3@.service) 实施。当前没有远程安装、DNS / 防火墙变更、生产切换或公网测试。服务器 CPU / RAM / 带宽未知，不能承诺同机并发数量。

## 7. 验证与维护

按改动选相关检查，不要把旧阶段所有输出累计成“本次测试数量”。交接整理与随后 Git 归档阶段的检查分开记录在 VERIFICATION.md；下表是按变更范围选择检查的入口。

| 变更范围 | 主要验证入口 |
| --- | --- |
| 通用模拟 | `tests.gd` |
| 动作 / 入网 | `action_net_tests.gd`、`mechanics_tests.gd`、`keeper_goal_tests.gd` |
| 接球 / 防守 / 场地 | `receiving_defending_tests.gd`、`pitch_modes_tests.gd` |
| 死球 / 冲击 / 六人规则 | `restart_impact_tests.gd`、`six_a_side_tests.gd`、`--verify-six` |
| 传奇 / 体型 / 步态 | `legend_models_tests.gd`、`physique_tests.gd`、`--verify-legends`、`--verify-physique`、`--verify-locomotion` |
| 输入 / 加载 | `--verify-input`、`--verify-loading` |
| 协议 7 | `network_latency_tests.gd`、`verify-network.ps1` |

网络常用复现（在仓库根目录，依次执行，不要占用相同端口并行运行）：

```powershell
.\godot.cmd --headless --path space-football-demo --script res://network_latency_tests.gd
.\space-football-demo\verify-network.ps1 -LatencyActions -Rounds 2 -BurstEvery 37 -AlternateRoster -LoadDelay 500 -AllowSystemCertificateWarning
.\space-football-demo\verify-network.ps1 -PlayerHost -Graphical -Rounds 1 -AlternateRoster -AllowSystemCertificateWarning
.\space-football-demo\verify-network.ps1 -Rules -Ice -Rounds 1 -Delay 0 -Jitter 0 -LossEvery 0 -ReorderEvery 0 -AllowSystemCertificateWarning
```

`-AllowSystemCertificateWarning` 仅精确容许本机已知 Windows CA 库读取警告，保留原日志；其他错误与 MTU 警告仍失败。固定帧规则 / 动作脚本应按已验证的零故障方案运行，弱网操作用专门场景，不要混用后错误解释结果。

提交前核对工作区、相应测试与资源来源，保留 `.uid` 和导入配置；不要提交引擎、`.godot` 缓存、用户存档、截图、安装包、`.env` 或凭据。维护球员导入时保留原快照与 SHA-256 清单。资源许可按各素材目录分别判断，人体 CC0 不覆盖所有卡画或整个项目。

实际历次结果与局限在 [VERIFICATION.md](VERIFICATION.md)。后续修改后应更新相关专题和 CURRENT_STATE，而不是继续把不同时期的“最新状态”叠加到文件尾部。
