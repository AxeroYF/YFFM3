# 架构重构记录

## 第二轮：环境资源与剩余界面边界（最新）

2026-10-04，继续处理其余收益明确的结构问题。玩法参数、存档格式与协议 7 保持不变；开发交付时尚未提交；2026-10-06 已统一纳入 `20b1921` 并推送。

| 改动 | 维护收益 |
| --- | --- |
| `environment/` 的 3 种 Resource 类型与 8 个 `.tres` 配置 | 球场、天气、重力各自维护；风力、抓地力、摩擦、弹性和闪电间隔 / 时长 / 亮度不再散落在不同系统里 |
| `match_environment.gd::CATALOG` | 以稳定 ID 注册配置；界面标签、循环选项、物理和视觉读取同一配置，效果不再依赖枚举位置 |
| `ball_flight_conditions.gd` / `ball_physics.gd::step()` | 单步球路使用具名参数；正常比赛、预测、进球入网和定位球准备共享接口；每次生成独立设置，禁风不会修改共享资源 |
| `library_screen.gd` | 只接收 UI 服务与页面根节点；导航、弹层、通知通过信号交给主入口，不再持有整个主入口 |
| `rules_presentation.gd` / `hold_skip_prompt.gd` | 显式读取模拟、HUD 和输入；只负责表现，规则音效通过信号请求 |
| `stadium_view.gd::follow_ball()` / `impact_feedback.gd` | 跟球相机回到球场视图；碰撞镜头只接收相机、模拟与开关，不依赖主入口 |
| `loading_screen.gd` / `game_audio.gd` | 加载页只依赖 UI 服务；独立音效节点拥有播放器、采样缓冲和合成状态 |

`main.gd` 当前 1402 行，负责组装、导航及兼容转发。保留旧物理 `advance()` 适配入口，现有独立物理测试可继续使用；产品调用已使用具名设置。没有为了消除兼容入口而改写所有测试或引入全局服务容器。

新增天气时，在 `environment/` 建立资源并在 `CATALOG` 注册新的稳定 ID；禁止复用或重排既有 ID。已加载的资源视为只读。新增选项或调整物理参数涉及预测一致性，客户端和服务器必须使用相同配置，发布时仍需评估协议兼容性。资源化不等于允许运行中任意修改联机规则。

本轮实际验证：

- Full 的 13 组全部通过，共 **3997 项检查**（环境专项从 90 增至 96）。覆盖任意具名重力 / 摩擦 / 弹性、设置隔离、球网一致性，以及既有 16 种环境的快照与预测检查。
- Visual 扩至 **9 组**，全部实际运行于 2560×1440：阵容搜索 / 按钮换人 / 保存重载、定位球准备与镜头反馈、六人制、快速比赛、输入、加载、比赛工具、门将回放、天气闪电。检查了阵容与环境截图。
- 窗口验证发现并修复 UI 服务遗漏 `MUTED` / `GOLD` 颜色常量的问题；修复后重新运行全部 Visual，未放宽错误检查。
- 独立服务器 + 两客户端，`-Rules -Ice -LoadDelay 1500 -Rounds 2` 弱网通过；单向延迟 100ms、抖动 25ms、每 7 包丢 1 包、每 11 包乱序。两轮各端终场比分、帧号一致。此多进程测试仍是默认环境；天气同步由 16 组合专项覆盖。
- 证据为 `artifacts/phase2-Full-summary.json`、`phase2-Visual-summary.json`、`phase2-network-rules.log` 及对应日志。统一运行器新增可选 `-LogPrefix phase2`，避免覆盖前轮证据。

```powershell
.\space-football-demo\verify-project.ps1 -Suite Full -LogPrefix phase2 -AllowSystemCertificateWarning
.\space-football-demo\verify-project.ps1 -Suite Visual -LogPrefix phase2 -AllowSystemCertificateWarning
.\space-football-demo\verify-network.ps1 -Rules -Ice -LoadDelay 1500 -Rounds 2 -Port 28846 -AllowSystemCertificateWarning
```

仍保留的边界：主入口的战役 / 联机菜单和旧转发接口、模拟中的 Dictionary 状态结构、既有 AI / 规则算法。没有以缩短文件为目的整体重写这些部分；后续随具体玩法需求和性能证据继续拆分。尚未进行公网、真实手柄、Linux 和低端设备验证。

## 第一轮：高 / 中高优先级（历史记录）

日期：2026-10-04。基于已加入球场、天气、闪电与低重力的工作区继续开发。没有调整玩法参数，没有打包或部署；以下为第一轮交付时记录；后续已连同环境功能、第二轮重构在 `20b1921` 提交并推送。

## 模块职责与依赖

主入口 `space-football-demo/main.gd` 从 2021 行降到 1412 行。它保留应用组装、菜单 / 战役导航、网络事件接线，以及供旧界面和验证脚本使用的转发属性；转发属性没有第二份状态。代码行数只是结果，主要变化是下面这些职责具有独立所有者。

| 模块 | 所有权 / 接口 |
| --- | --- |
| `match_session.gd` | 比赛对象、本地 / 联机 / 快速比赛上下文、加载代次；准备比赛、提交命令、运行 / 输入 / 呈现条件 |
| `match_loading.gd` | 分阶段加载、取消代次、网络就绪等待；通过明确的准备、建界面、渲染、完成回调协调 |
| `stadium_view.gd` | 球场节点、相机、天气节点、演员创建 / 清理 / 换人模型重建 |
| `match_renderer.gd` | 读取会话和预测画面，更新球员、足球、轨迹、选择与传球指示 |
| `match_hud.gd` | HUD 控件、数据刷新和音效请求信号，不启动或修改比赛 |
| `quick_match_screen.gd` / `match_tools_screen.gd` | 快速比赛与替补 / 高级设置 / 帮助界面；显式传入参数和操作回调 |
| `ui_kit.gd` / `ui_palette.gd` | 通用控件、字体、按键提示与共享颜色；不加载比赛模拟 |
| `desktop_input.gd` | 只接收输入收集器、UI 服务、页面根节点和当前页面查询；导航 / 取消通过信号返回 |
| `match_tools.gd` | 回放与训练场景；显式接收模拟、球场、HUD、输入服务，不再接收整个主入口 |
| `verification_driver.gd` | 从主入口迁出的旧图形验证流程；允许以主入口作为测试夹具 |

联机菜单继续推进权威比赛，本地暂停继续冻结模拟；规则、AI 与物理保持原来的确定性调用顺序，没有引入全局事件总线。球员库和旧规则表现仍通过主入口兼容接口读取画面，后续新增模块应使用上述明确接口，不应扩大兼容接口。

## 状态与协议 7

- `match_state.gd` 集中维护完整本地快照字段及模拟属性映射，补入 RNG 状态、拾球锁、加时长度、难度 / 战役参数。四种比赛阶段恢复后继续 120 帧，与原模拟逐项一致。
- `match_player_state.gd` 是比赛创建与网络身份重建共用的球员工厂，避免两套姓名、身体、能力与速度初始化规则。
- `snapshot_codec.gd` 仅编码传入快照，解码不需要运行中的模拟。去掉旧 `mechanics.wire(sim)` 混入实时状态、`unpack_state()` 以客户端当前快照为底的依赖。
- 本地完整快照保留 AI 计划；高频网络快照明确不传 authority-only AI 规划，解码使用规范初始 AI 状态，绝不继承客户端旧计划。网络快照服务于客户端呈现 / 预测，不是服务器迁移存档。
- 紧凑字段顺序集中声明；额外球员 / 队伍 / 顶层字段使用显式扩展字典传送。规则与球网沿用各自的紧凑格式。增加权威状态时仍须登记本地快照所有权，并为对应子系统补恢复测试。
- 解码检查协议版本、长度、有限数值、枚举、球员身份、队伍选择归属和关键嵌套字段类型，异常快照返回空字典并在收包入口丢弃。
- 协议号升至 **7**，客户端与服务器必须一起更新。基础探针压缩载荷约 709 字节，之前协议 6 约 653 字节；旧核心单包预算断言继续通过。复杂状态仍使用既有 1000 字节分片与 16 片上限。
- `match_actions.gd` 统一命令位定义；输入不再为了使用常量而加载比赛机制模块，网络命令不再依赖整个模拟。旧 `_predict` 移到 `movement_test_probe.gd`，仅供旧移动比较测试使用；运行时预测仍由 `network_prediction.gd` 负责。

## 验证与复现

新增 `verification-suites.json` 和 `verify-project.ps1`，统一 Fast / Full / Visual 三组入口，检查退出码、明确 PASS 标记及错误日志，输出 JSON 汇总。Windows 已知证书库诊断只有在显式指定参数时才允许，原始日志保留；脚本错误始终失败。

```powershell
.\godot.cmd --headless --path space-football-demo --editor --import --quit
.\space-football-demo\verify-project.ps1 -Suite Fast -AllowSystemCertificateWarning
.\space-football-demo\verify-project.ps1 -Suite Full -AllowSystemCertificateWarning
.\space-football-demo\verify-project.ps1 -Suite Visual -AllowSystemCertificateWarning
.\space-football-demo\verify-network.ps1 -Mechanics -PlayerHost -AlternateRoster -Rounds 2 -AllowSystemCertificateWarning
.\space-football-demo\verify-network.ps1 -Rules -Ice -LoadDelay 1500 -Rounds 2 -AllowSystemCertificateWarning
```

本轮已完成：

- 13 组无窗口检查全部通过；最终新增重构检查 49 项，加既有套件共 **3991 项断言**。完整套件跑通后又针对新增嵌套校验重跑 Fast。基础回归 12 场 AI 比赛合计 30 球。
- 重构检查覆盖旧快照编码不受实时修改影响、接收端历史不污染状态、四阶段确定性恢复、扩展字段、协议 / 长度 / 身份 / 非有限数值 / 类型拒绝、身份缓存隔离、离线暂停及在线菜单行为。
- 六组实际 2560×1440 图形检查通过：快速比赛 13、输入 79、加载 12、门将与进球回放 18、环境 12；另有替补 / 训练恢复 / 回放等机制图形流程通过。已查看环境设置和闪电截图。
- 玩家主机 + 客户端，自定义阵容，机制场景两轮通过；独立服务器 + 双客户端，冰球 / 规则场景、1500ms 延迟加载两轮通过。双方应用层故障配置为单向 100ms、抖动 25ms、每 7 包丢 1 包、每 11 包乱序；各端最终比分与帧号一致。
- 最终嵌套类型校验加入后，额外运行玩家主机的 `-LatencyActions -Rounds 2` 双轮弱网动作场景，通过；日志为 `artifacts/refactor-network-latency.log`。
- 修复了旧门将图形测试未注册虚拟 Xbox 设备的夹具问题；保留原来“跳过回放不传球、不改变比赛阶段”的断言，没有放宽产品输入过滤。
- 本地日志、截图和汇总位于 `space-football-demo/artifacts/refactor-*`，Git 忽略。导入无脚本错误，`git diff --check` 通过；仅有已知 Windows 根证书库诊断。

没有进行公网、Linux、真实手柄和低端设备验证；没有把历史环境验证重新算作本轮执行。天气配置资源化属于此前“中”优先级，未纳入本轮高 / 中高重构。
