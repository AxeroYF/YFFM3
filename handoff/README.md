# YFFM3 对话交接

更新日期：**2026-10-09**。球场天气、低重力与两轮重构已纳入 `20b1921`；本次 Git 归档包含后续五分钟比赛、HUD 清理和协议 8 联机修复。最新变更见 [ONLINE_READINESS.md](ONLINE_READINESS.md)，当前仍未部署公网服务，远端同步状态以实际 Git 为准。

## 项目速览

| 项目 | 当前状态 |
| --- | --- |
| 名称 | YFFM3 · 群星绿茵 / STARBORNE，第三代足球项目 |
| 核心玩法 | 星际场景中的六人制足球；每位玩家操控整支球队并切换球员 |
| 引擎与画面 | Godot 4.7.2 标准版，GDScript；2560×1440 设计画布 |
| 可玩内容 | 本地快速比赛、冰球反弹模式、三站战役、基础联机 |
| 球员 | 386 名带卡画球员，完整 26 项能力；67 名传奇已有逐人外观配置 |
| 输入 | 键盘、Xbox 风格手柄；安卓仅预留接口 |
| 网络 | 协议 8，邀请码与版本校验，权威服务器 60 Hz、默认 30 Hz 快照；加载超时及掉线后清理房间 |
| 发布 | 开发阶段，仅有本地验证用 Windows 导出包；未发布、未部署公网，安卓未打包 |
| 仓库 | 独立公开仓库 `AxeroYF/YFFM3`，分支 `codex/yffm3` |
| 本地目录 | `D:\Project\game_test\.worktrees\YFFM3`；主游戏在 `space-football-demo/` |

## 阅读顺序

1. [CURRENT_STATE.md](CURRENT_STATE.md)：当前结论、开发约束、已知缺口和下一步。
2. [GAMEPLAY_REFERENCE.md](GAMEPLAY_REFERENCE.md)：比赛流程、动作、物理、AI、规则、战役及呈现。
3. [CONTROLS.md](CONTROLS.md)：键盘 / Xbox 操作、组合键、辅助及菜单行为。
4. [PLAYER_DATA.md](PLAYER_DATA.md)：球员库、26 项能力用途、传奇模型与体型手感。
5. [PROJECT_INFO.md](PROJECT_INFO.md)：启动、目录、存档、架构、联机、部署和维护。
6. [MANIFEST.md](MANIFEST.md)：定位实现文件；[VERIFICATION.md](VERIFICATION.md)：历史测试范围。

直接开启新对话，可复制 [NEW_CHAT_PROMPT.md](NEW_CHAT_PROMPT.md)。

## 专项资料

最新高 / 中高优先级重构见 [ARCHITECTURE_REFACTOR.md](ARCHITECTURE_REFACTOR.md)：模块职责、协议 7、统一验证入口与本轮验证范围。

[MATCH_ENVIRONMENT.md](MATCH_ENVIRONMENT.md) 保留快速比赛球场、天气、间歇闪电与低重力，以及协议 6 阶段验证；当前协议为 8，最新联机测试见 [ONLINE_READINESS.md](ONLINE_READINESS.md)。

| 文档 | 用途 |
| --- | --- |
| [SIX_A_SIDE_AND_ROADMAP.md](SIX_A_SIDE_AND_ROADMAP.md) | 六人制升级、小场规则来源及当轮机制评估 |
| [LEGEND_MODELS.md](LEGEND_MODELS.md) | 67 名传奇外观、素材来源、展厅和模型验证 |
| [PHYSIQUE_GAMEPLAY.md](PHYSIQUE_GAMEPLAY.md) | 体型对启动、惯性、转向和对抗的有界影响 |
| [NETWORK_GRAY_TEST.md](NETWORK_GRAY_TEST.md) | 协议 5 历史记录、弱网模型、历史验证证据及灰度边界 |
| [部署说明](../deploy/README.md) | 与 Rougelite 同机部署的目录、端口、服务模板及观测步骤 |

## 资料时效

- 本轮综合文档以当前源码为依据；具体数值以后续代码为准。专项文档中的“本轮”指各自开发阶段。
- 历史协议、五人制及旧 Git 基线结果不能替代当前协议 8 / 六人制验证。
- 日志、截图、引擎和用户存档通常不在 Git 中。代码存在、测试通过、人工体验满意、已上线，是四种不同状态。
- 整理前的三份入口文档已存入 [历史入口存档说明](archive/README.md)，仅供追溯，不作为当前开发指令。
