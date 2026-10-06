# 球场、天气与低重力

状态更新：2026-10-06。功能最初基于 `3501ce4` 开发，现已连同两轮重构纳入 `20b1921` 并推送；未打包或部署。以下功能验证保留 2026-10-04 当轮记录。

## 玩家入口

主菜单 → 快速比赛（或冰球模式）→ 阵容预览下方的三个环境按钮。鼠标点击、键盘确认及手柄 A 循环选择。

- 球场：蓝色星球 / 银河流星雨。银河使用程序星云与持续划过的流星，移除该场比赛的蓝色星球和轨道环；背景本身不修改能力或物理。
- 天气：晴朗 / 大风 / 暴雨 / 风暴。暴雨包含雨线、地面涟漪、湿地反光与间歇闪电；风暴组合大风和暴雨。
- 重力：标准 / 55% 低重力。所有选项独立，可与经典六人制或冰球反弹组合。

切换环境不随机阵容；同阵容重赛和重新随机重赛均保留环境。设置只在当前运行会话保留，不写入战役、首发或偏好存档。HUD 显示环境和横风方向。退出比赛恢复菜单的蓝色星球与晴朗效果。暂未增加联机大厅的环境选择入口。

## 实际比赛影响

| 环境 | 效果 |
| --- | --- |
| 大风 | 沿场地横轴吹向近侧边线，高球发生偏移；风加速度以比赛时间按 `3.4 + 1.2 × sin(t × 0.7)` 有界变化，并按球高缩放。双方使用同一风场，不按进攻方向给某队顺风。地面静止球和地滚球不受新增风力推动。 |
| 暴雨 | 抓地力为 0.80，刹车强度降低 20%，加速度乘 √0.80；最高速度和原始能力不改。地滚球摩擦乘 1.30，落地竖直反弹由 0.32 降为 0.23。 |
| 低重力 | 足球重力和球员跳跃重力均乘 0.55；起跳/出球初速度保留，因此高球飞得更高、更远，球员滞空更久。不是全场慢动作。 |
| 闪电 | 首次等待约 3.5–6.5 秒，此后间隔约 8–16 秒。背景分叉闪电与短暂场地照明在约 0.48 秒内衰减；只影响表现，不修改比分、球权、物理或模拟随机数。 |

现有战役太阳风独立保留。新天气没有随机滑倒、随机射偏或雷击伤害；冰球边界反弹仍使用原规则。捡球阶段保留湿地和低重力，但不让横风吹走准备中的定位球。

## 实现位置与兼容

- 后续两轮重构已经完成，目前协议为 **7**；本文件下方“本轮验证”保留环境最初开发时协议 6 的历史记录，最新验证见 [ARCHITECTURE_REFACTOR.md](ARCHITECTURE_REFACTOR.md)。
- `match_environment.gd` / `environment/`：稳定 ID 注册表、选项校验及说明；球场 / 天气 / 重力资源统一提供物理和视觉参数。
- `ball_flight_conditions.gd` / `ball_physics.gd::step()`：具名、每步独立的重力、摩擦、弹性和风力设置。
- `match_sim.gd::advance_ball()`：比赛、接球辅助、外场 AI、门将与客户端球路预测共用环境物理入口。
- `player_movement.gd`：移动与可达距离共享湿地抓地力；球员原始 ratings 不改。
- `match_mechanics.gd`、`match_rules.gd`、`goal_net.gd`、`restart_flow.gd`：空中动作、死球、进球入网延续环境。
- `environment_visual.gd`、`shaders/weather.gdshader`、`shaders/lightning.gdshader`、`shaders/space.gdshader`、`shaders/pitch.gdshader`：程序化视觉，无外部新增图片资源。雨线、涟漪、风线使用固定数量 GPU 批次，流星为固定 18 条；闪电使用独立视觉时钟。
- `quick_match_screen.gd` / `match_session.gd` / `stadium_view.gd` / `match_hud.gd`：环境选择、开赛 / 重赛应用、画面与 HUD；主入口负责导航组装。
- 环境随本地快照、压缩快照和私有预测副本传递。客户端与服务器须成套更新。新选项目前只开放本地快速比赛；线上默认仍为标准环境。

## 本轮验证

- `environment_tests.gd`：90 项，通过全部 16 种组合的快照、网络编解码、球路与移动预测一致性；校验风偏、湿地、球员/足球低重力、背景不影响物理；风暴低重力下普通和冰球 AI 对局自然终场。
- 七组既有回归：531 / 1995 / 98 / 49 / 31 / 185 / 178 项全部通过；基础 AI 对局恢复原默认环境下的 30 球结果。
- `--verify-environment`：12 项，实际 2560×1440 图形；菜单、开赛、重赛、退出恢复、暴雨/风暴闪电、光照消退和视觉不污染模拟。
- `--verify-quick` 13 项与 `--verify-input` 79 项通过，后者使用合成输入，不等于真实手柄体验验收。
- 协议 6 独立服务器 + 两客户端：两轮真实 ENet，双向延迟 100 ms、抖动 25 ms、1/7 周期丢包、1/11 乱序、连续丢包、替换阵容及准备屏障通过，射门恰好一次、终场帧 240 一致。本次多进程联机是默认环境，新环境组合的同步覆盖为上述模拟/编解码专项。
- 日志只有已知 Windows 证书库诊断；没有脚本或着色器错误。没有公网、Linux、安卓或低配设备性能验收。

本机证据：`space-football-demo/artifacts/environment-*.log`、`environment-options.png`、`environment-galaxy.png`、`environment-storm.png`、`environment-lightning.png`、`environment-planet-rain.png`，继续被 Git 忽略。

```powershell
.\godot.cmd --headless --path space-football-demo --script res://environment_tests.gd
.\godot.cmd --path space-football-demo --fullscreen --resolution 2560x1440 -- --verify-environment
.\space-football-demo\verify-network.ps1 -LatencyActions -Rounds 2 -BurstEvery 37 -AlternateRoster -LoadDelay 500 -Port 28836 -AllowSystemCertificateWarning
```
