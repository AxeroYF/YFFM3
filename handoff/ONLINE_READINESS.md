# 联机修复与朋友测试准备

更新：2026-10-09。当前协议 **8**，常规比赛 **300 秒有效比赛时间**。本轮修复位于 `c0a085f` 之后，随五分钟比赛与 HUD 清理一同纳入本次 Git 归档；远端同步状态以实际 Git 为准。没有登录或修改生产服务器。

## 已完成

- 入场前验证邀请码、协议和构建清单；错误客户端不占比赛座位。专用服务器默认要求邀请码，客户端大厅增加隐藏输入框。邀请码通过随机挑战及 HMAC 校验，不直接传送明文口令；不提供传输加密或服务端身份认证。
- 验证等待上限 8 秒，入场后未准备上限 120 秒。已准备等待对手的玩家不按此未准备超时踢出，因此不应把它当成完整防占位或防攻击方案。
- 场景加载超过 45 秒，通知双方退出、释放座位并清理比赛；同一个服务器继续监听并接受下一局。对局中一人离开也会清理本场，另一人可重新加入；正常终场支持原连接再战。
- 修复错误入场回调内同步销毁 ENet peer 引发的 Windows 内存访问崩溃。现在先停用会话，再通过 deferred 回调释放连接，避免在网络轮询时替换 peer。
- 修复服务 / 版本预检提前退出时未托管的球场节点；无窗口退出不再遗留此节点与资源。
- 快照协议由 7 升为 8；双方需要同时更新。系统服务增加邀请码环境文件和启动前版本检查。

## 版本清单与导出

`tools/network-build.mjs` 生成 `space-football-demo/network-build.json`，包括 GDScript、shader、场景、规则 Resource、项目配置和运行时球员 JSON 的规范化 SHA-256。源码运行逐项校验；导出后的脚本已编译，因此使用导出前生成的源码身份，并校验实际 JSON 数据。清单不覆盖全部图像，也不能验证恶意客户端是否诚实执行。

修改相关源码后在仓库根目录执行：

```powershell
node tools/network-build.mjs
node tools/network-build.mjs --check
.\godot.cmd --headless --path space-football-demo -- --verify-network-build
```

提交清单与对应源码。统一测试入口先执行 `--check`，禁止测试过期清单。导出前同样执行 `--check`；将同一清单随客户端和服务器发布。引擎编辑器的直接导出不会自动运行 Node 检查，维护者必须遵守此构建步骤。

本轮 Windows 调试导出仅用于验证，位置 `space-football-demo/artifacts/build/YFFM3-online-check.exe`，未公开发布。默认用户数据保持隔离在仓库 `tools/godot/user_data`。

## 实际验证

2026-10-09 最新源码与导出清单指纹：`0e5a44c84463176571cd6e201be4a7de3d5ba304a8f9831a5361529232242201`。

| 检查 | 结果 / 证据 |
| --- | --- |
| Fast 五组 | 325 项通过；`artifacts/online-final-Fast-summary.json` |
| ENet 生命周期 | 上表包含 32 项，覆盖缺失 / 错误邀请码、不同构建 / 协议、验证超时、未准备超时、无效阵容、加载超时、掉线释放、再次入场与正常再战 |
| Visual 九组 | 全部通过；`artifacts/online-final-Visual-summary.json`；输入专项 83 项，含邀请码控件、焦点与状态传递 |
| 独立服务 + 两客户端 | 源码版两轮通过：`artifacts/online-repair-dedicated.log`；最终导出包两轮通过：`artifacts/online-final-export-network.log` |
| 玩家房主 + 客户端 | 两轮通过：`artifacts/online-repair-host.log`（早于最终球场节点清理及 UI 测试新增，核心网络实现一致） |
| 导出与启动检查 | `artifacts/online-final-export.log`、`online-final-export-preflight.log`；退出码 0，预检 stderr 为空，指纹与源码一致 |
| 界面查看 | `artifacts/online-invitation-lobby.png`，2560×1440；邀请码输入与状态区域无重叠 |

复现主要命令：

```powershell
.\space-football-demo\verify-project.ps1 -Suite Fast -LogPrefix online-final -AllowSystemCertificateWarning
.\space-football-demo\verify-project.ps1 -Suite Visual -LogPrefix online-final -AllowSystemCertificateWarning
.\space-football-demo\verify-network.ps1 -Executable space-football-demo/artifacts/build/YFFM3-online-check.exe -LatencyActions -Rounds 2 -BurstEvery 37 -AlternateRoster -LoadDelay 500 -Port 28850 -AllowSystemCertificateWarning
```

多进程模型在双方应用消息每个方向注入 100 ms 延迟、25 ms 抖动、每 7 包丢 1 包、每 11 包乱序和每 37 包触发连续丢包；各端终场比分与帧一致。加载屏障通过 500 ms 延迟客户端验证。网络集成用加速短局，不代表已完成公网五分钟对局或长稳验证。生命周期超时测试通过缩短认证等待 / 推进时间戳覆盖故障路径，避免真实等待数分钟。

本次沙箱内回环连接曾超时；获准在沙箱外运行后通过。历史初版生命周期测试曾触发用户所见原生崩溃；最终故障场景复测通过。旧失败日志保留，不应误当成最终结果。此前五分钟改动的 Full 13 组 4004 项记录见 [VERIFICATION.md](VERIFICATION.md)，本轮未宣称重跑 Full。

## 部署边界与下一步

已具备准备朋友间单房间测试的代码条件。按 [部署说明](../deploy/README.md) 配置 Linux Godot、专用用户、邀请码环境文件、资源导入、UDP 防火墙及 systemd 后，仍需真实服务器验收。当前未验证 Linux 安装、公网三网延迟、多人长时间并发或与 Rougelite 共置容量。

保持一进程一场比赛、两名玩家；尚无多房间调度、账号、短效票据、断线续赛和 DDoS 防护。下一步先部署一个受限测试房间，实测同机负载和朋友完整对局，再决定扩容与体验优化。
