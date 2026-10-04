# 文件与系统入口

更新：2026-10-04。路径相对仓库根目录。主游戏在 `space-football-demo/`。

## 交接文档入口

| 文件 | 用途 |
| --- | --- |
| [README.md](README.md) / [CURRENT_STATE.md](CURRENT_STATE.md) | 导航、当前结论、边界与接续优先级 |
| [GAMEPLAY_REFERENCE.md](GAMEPLAY_REFERENCE.md) | 模式、规则、动作、物理、AI、门将、战役与呈现 |
| [CONTROLS.md](CONTROLS.md) | 键盘 / Xbox 操作、辅助与设备行为 |
| [PLAYER_DATA.md](PLAYER_DATA.md) | 386 人、26 项能力、67 名传奇及体型机制 |
| [PROJECT_INFO.md](PROJECT_INFO.md) | 项目、启动、存档、架构、联机和部署 |
| [VERIFICATION.md](VERIFICATION.md) / [NETWORK_GRAY_TEST.md](NETWORK_GRAY_TEST.md) | 历史验证与当前协议 5 证据 |
| [NEW_CHAT_PROMPT.md](NEW_CHAT_PROMPT.md) | 可复制的新对话接续信息 |
| [archive/README.md](archive/README.md) | 综合整理前入口的历史存档说明 |

## 启动与环境

| 文件 | 用途 |
| --- | --- |
| `README.md` | 新电脑获取编辑器、首次导入、开发与验证命令 |
| `godot.cmd` | 本地 Godot 控制台入口，隔离开发存档 |
| `Start-Space-Football.cmd` | 主菜单 |
| `Start-Quick-Match-Dev.cmd` | 快速比赛开发入口 |
| `Start-Legend-Models.cmd` | 首批 67 名传奇的分页模型展厅 |
| `Edit-Space-Football.cmd` | Godot 编辑器打开主游戏 |
| `Start-Space-Football-Server.cmd` | ENet 独立服务器，默认 UDP 28765 |
| `tools/godot-installation.json` | 已安装 Godot 4.7.2 的版本、来源与校验记录 |
| `.gitignore` / `.gitattributes` | 忽略本地产物，统一源码与 Windows 脚本行尾 |

当前机器：`D:\Project\game_test\.worktrees\YFFM3`。本地编辑器位于 `tools/godot/`，不在 Git 中。

## 比赛系统

| 主游戏内文件 | 职责 |
| --- | --- |
| `project.godot` / `main.tscn` | 项目配置、2K 画布、入口场景 |
| `main.gd` | 画面、主菜单、比赛场景、相机、音效及验证入口 |
| `match_sim.gd` | 权威模拟、球员状态、传射、碰撞、边界及快照 |
| `team_config.gd` | 六人队伍、十二人总数、中场槽位和最低参赛人数 |
| `match_mechanics.gd` | 操作意图、出脚队列、预输入、跳跃、对抗、纪律及换人 |
| `match_rules.gd` / `restart_flow.gd` | 规则、犯规、死球准备/跳过、进球与重新开球 |
| `team_ai.gd` / `goalkeeper_ai.gd` | 外场协作、接应/防守/追球及门将决策 |
| `ball_physics.gd` | 球的三维飞行、阻力、摩擦和反弹预测 |
| `player_collision.gd` / `goal_frame.gd` | 身体扫掠、门柱和横梁碰撞 |
| `pitch_geometry.gd` | 球场尺度、球门尺寸、阵型与运动限制 |
| `impact_feedback.gd` | 屏幕像素标定、真实触球帧号、相机反馈去重与时效 |
| `six_a_side_tests.gd` / `six_a_side_verification.gd` | 六人制／旧存档／任意球专项与实际渲染冲击测量 |
| `goal_net.gd` | 进球后球网碰撞与接触状态序列化 |
| `goal_net_visual.gd` / `shaders/goal_net.gdshader` | 球网几何及局部形变 |
| `football_motion.gd` / `locomotion.gd` | 蓄力球路、动作时长、转身、步幅和步频 |
| `skinned_player.gd` | 当前实际使用的连续蒙皮人体、IK 与动作姿态 |
| `player_appearance.gd` / `player_morph.gd` / `player_groom.gd` | 稳定 ID 外观、连续体型/头脸变形、骨骼绑定发型与胡须 |
| `assets/humanoid/legend_appearances.json` / `assets/humanoid/hair/` | 67 名逐人配置、CC0 发型网格/纹理及来源记录 |
| `body_showroom.gd` / `legend_models_tests.gd` / `legend_models_verification.gd` | 分页展厅、全传奇 CPU 变形检查与实际图形/比赛集成检查 |
| `player_body.gd` / `player_ratings.gd` / `player_style.gd` | 体型、原始能力映射与球员偏好 |
| `player_physique.gd` / `player_movement.gd` | 有界身体比例修正；服务器和客户端共用的加减速、惯性、转向与拦截距离计算 |
| `physique_tests.gd` / `physique_verification.gd` | 全库体型机制、同能力对照与预测一致性检查；2K 资料页及身体倾斜检查 |
| `play_assistance.gd` | 传接球与操作辅助 |
| `match_tools.gd` | 本地回放、训练场景、换人界面、震动反馈 |
| `rules_presentation.gd` / `hold_skip_prompt.gd` / `impact_feedback.gd` | 死球/进球显示、长按圆环和镜头冲击 |

## 输入、界面与网络

| 主游戏内文件 | 职责 |
| --- | --- |
| `football_input.gd` | 电脑比赛键位、组合键、蓄力和操作意图 |
| `desktop_input.gd` / `input_glyph.gd` | 菜单焦点、设备识别与按钮内提示 |
| `input_provider.gd` | 输入适配接口，安卓后续接入点 |
| `loading_screen.gd` | 阶段与进度显示 |
| `quick_match.gd` | 随机且位置合理的阵容与模式配置 |
| `campaign.gd` / `squad.gd` | 航线、队伍、训练及本地持久化 |
| `player_library.gd` / `library_screen.gd` | 球员目录加载、筛选及详情 |
| `match_network.gd` | ENet 房间、权威输入/动作校验、压缩快照、预测与重赛 |
| `network_command.gd` / `network_timeline.gd` | 数字输入编解码、球员身份绑定、动作去重与蓄力时间线 |
| `network_prediction.gd` / `network_snapshots.gd` | 私有本地动作预览、快照重放与远端插值 |
| `network_link.gd` / `network_fragments.gd` | 双向应用消息弱网注入、受限快照片段重组 |
| `network_latency_tests.gd` / `network_latency_verification.gd` | 网络边界断言及真实 ENet 下射门恰好一次验证 |
| 根目录 `deploy/` | 与 Rougelite 共存的 Linux 灰度说明和 systemd 服务模板；未部署 |
| `verify-network.ps1` | 启动真实服务器与客户端进程，检测错误和终场一致性 |

联机修改注意：新增动作名需要进入 `match_network.gd` 的 `ACTIONS`；新增权威字段需要同时覆盖本地快照、恢复、压缩打包与解包。客户端呈现与回放不应反向修改权威球路。

## 数据、美术与历史原型

| 路径 | 内容 |
| --- | --- |
| `space-football-demo/assets/player-library/catalog.json` | 386 名游戏可用球员 |
| 同目录 `source-snapshot.json` | 完整原始资料快照 |
| 同目录 `manifest.json` / `import-report.json` | 卡画路径、校验值和统计 |
| 同目录 `portraits/` / `excluded-no-art.json` | 卡画与无卡画排除清单 |
| `space-football-demo/assets/humanoid/` | 人体网格、纹理、许可与来源 |
| `tools/makehuman-assets/` | 人体构建源资源及权重 |
| `scripts/build-human-model.mjs` / `fetch-makehuman-assets.mjs` | 构建与获取人体源素材 |
| `scripts/import-player-library.mjs` | 从明确指定的前作目录重新导入球员，非日常运行依赖 |
| `player-card-demo/` / `starfield-demo/` | 早期卡片和星空原型，主游戏不在这些目录开发 |

球员库已经自包含，运行游戏不需要访问前作。重新导入会覆盖既有数据，修改导入源或范围前应先核对用户需求与当前清单。

## 现有专项说明

当前综合说明优先参考本目录的玩法、操作、球员数据及项目信息文档。主游戏中的 `多端输入说明.txt`、`动作与入网优化说明.txt`、`球场扩容与冰球模式说明.txt`、`接球转身与抢断优化说明.txt`、`AI跑位与球员差异说明.txt` 和 `球员能力值设计评估.txt` 保留为对应开发阶段的详细记录；较早说明可能描述旧键位、五人制或旧协议，冲突时以当前代码为准。

`space-football-demo/artifacts/` 保存本机测试日志与图片但被 Git 忽略。三个项目各保留 `artifacts/.gdignore`，让新克隆自带空输出目录，并阻止 Godot 将生成的图片和构建导入为游戏资源。可复现验证入口在 [VERIFICATION.md](VERIFICATION.md)。
