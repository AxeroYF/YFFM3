# 联机优化与同机灰度

本文保留协议 5 开发阶段记录。当前代码为协议 8，最新入场验证、房间恢复及测试见 [ONLINE_READINESS.md](ONLINE_READINESS.md)。下列历史证据不代表当前版本重新执行的结果。

更新：2026-10-04。用户已确认：阿里云香港服务器，中国大陆玩家为主；同机已有 Rougelite。当前请求是先准备联机优化，后续由用户挂载灰度。本轮没有连接生产服务器、修改网站、创建 DNS、开放防火墙或打包 Windows / Android。

## 实现

- 协议升级为 **5**，客户端与服务器须一起更新。权威模拟固定 60 Hz，快照默认 30 Hz；服务可用 `--snapshots=20` 降为 20 Hz，客户端需同样设置以使快照缺口统计正确。
- `network_command.gd` 将每帧操作编码为有界数字数据，绑定队伍、当前球员、球员库 ID、换人版本。六帧输入冗余随不可靠消息发送；有动作的帧另走可靠通道备份，两条路使用同一动作 ID，服务端去重。
- `network_timeline.gd` 将移动与动作放在同一输入时间线上，初始缓冲两帧。延迟动作有 12 帧容忍，超期丢弃；不能让旧球员的抢断应用到刚切换的球员。蓄力按按下/松开对应的输入帧间隔计算，避免抖动放大射门力度。上行断流 300 ms 后释放方向、冲刺、协防等保持状态。
- `network_prediction.gd` 使用私有模拟副本，复用现有移动、转身、动作释放时间；立即呈现本地移动、切人、蓄力、出脚、铲球。服务端快照恢复后重放未确认输入，已确认动作不重复播放。小位置误差短暂平滑，换人/阶段跳转及大误差直接校正。
- 足球的本地预览最多前推快照后 250 ms；对手争抢区、边界附近交还服务端，禁止推测进球和身体触球。球的视觉交接有短插值。比分、所有权裁定、碰撞、犯规及结果仍以服务器为准。此处不是完整世界回滚，也不预测成功抢断或抢到球。
- `network_snapshots.gd` 缓存最多 12 个状态，用约 50–117 ms 自适应缓冲播放远端球员；远端位置最多外推 50 ms。普通远端球不外推门线事件；阶段改变清空跨阶段插值。
- 一次打包的快照复用于两位玩家；`network_fragments.gd` 以 1000 字节片段发送，避免超过 ENet MTU。最多 16 片、8 个未完成快照；过时/缺片不阻塞新状态。实测日志不再有超 MTU 警告。
- 应用层探测覆盖故障注入后的双向延迟；HUD 显示双方 RTT 和本地快照抖动，超过 300 ms 没有快照显示等待同步。每 10 秒及终场输出 `NETWORK_METRICS`，包含快照缺口、纠正、丢包/重传模拟、载荷和服务步耗时。
- 无窗口服务/测试机器人限制主循环 60 FPS，避免闲置图形循环占用共享 CPU；端口创建失败以非零状态退出，便于 systemd 识别。

## 弱网模型边界

`network_link.gd` 对所有参与者的上行输入、可靠动作备份、下行快照片段、RTT 探测/回应注入延迟、抖动、周期丢包、连续丢包、乱序。可靠丢包以额外等待模拟重传。真实 ENet socket 同时在本机运行。

这是**应用消息层故障模型**，不是内核 UDP 抓包/netem，也不是中国大陆到香港实测。入场、加载屏障、终场结果等可靠生命周期消息不注入此模型。没有生产抗攻击、重连恢复或公开匹配上线承诺。

## 本轮实际验证

- `network_latency_tests.gd` **98 项**：非有限数字/身份/范围校验、重复与乱序、动作仅一次、射门蓄力时长、失联释放、球员切换/替补身份、本地预测隔离与回退、待出脚快照、插值与分片边界。
- 回归：`tests.gd` **531 项**，`physique_tests.gd` **1995 项**，`mechanics_tests.gd` **77 项**，`receiving_defending_tests.gd` **57 项**。
- 独立服务器 + 两客户端：双向各 100 ms、抖动 25 ms、每 7 条消息模拟一次丢包、每 11 条乱序，连续两轮终场比分/帧一致。一次本机运行 RTT 约 215–270 ms，不能解读为香港线路数据。
- 追加 `-LatencyActions -BurstEvery 37 -AlternateRoster -LoadDelay 500 -Rounds 2`：冗余输入/备份共存、连续丢包、更换阵容、准备屏障、第二轮清理；每轮权威端及两客户端均确认射门恰好一次，结束于同一帧 240。
- 本地玩家房主 + 实际图形客户端：同样双向弱网，使用替换阵容，**实际 2560×1440** 比赛/终场截图，预测启用与最终结果一致。
- 规则回归：独立服务器 `-Rules -Ice` 一轮、`-Mechanics` 一轮通过，分别观察死球/进球/规则与动作/换人/纪律。此两组刻意使用零故障注入，避免把固定帧测试场景的切换时间误当成真实网络操作窗口。
- 原图形检查曾因 48 秒进程期限超时，延长到 60 秒后重跑通过；最终图形测试采用全屏，避免窗口边框将实际渲染高度压低。最后仅保留已有 Windows 沙箱 CA 库警告，脚本使用明确开关精确允许它，其余错误与 MTU 警告仍使检查失败。

证据位于被 Git 忽略的 `space-football-demo/artifacts/`：`v5-unit.log`、`v5-latency-actions-dedicated-*.log`、`v5-graphical-host-*.log`、`v5-rules-dedicated-*.log`、`network-match.png`、`network-result.png`。一般全量回归输出另保留在本次工具执行记录；旧轮的 `physique-*` 日志不是本次网络专项证据。

复现：

```powershell
.\godot.cmd --headless --path space-football-demo --script res://network_latency_tests.gd
.\space-football-demo\verify-network.ps1 -LatencyActions -Rounds 2 -BurstEvery 37 -AlternateRoster -LoadDelay 500 -AllowSystemCertificateWarning
.\space-football-demo\verify-network.ps1 -PlayerHost -Graphical -Rounds 1 -AlternateRoster -AllowSystemCertificateWarning
.\space-football-demo\verify-network.ps1 -Rules -Ice -Rounds 1 -Delay 0 -Jitter 0 -LossEvery 0 -ReorderEvery 0 -AllowSystemCertificateWarning
```

不要同时启动多个使用相同端口/日志名的验证脚本。脚本会核对实际 fault_profile，防止只在一端启用故障却宣称双向覆盖。

## 同机部署

详见 [部署说明](../deploy/README.md) 和 [systemd 模板](../deploy/yffm3@.service)。YFFM3 单独目录、用户、UDP 端口和服务，不改 Rougelite 的 Node.js/Nginx 服务。首次只开放一场灰度，测量双方游戏资源占用及三网 RTT 后再扩大。服务器规格和剩余资源尚未获得，Linux 服务安装与容量尚未测试。

后续优先补充生产入场票据、多房间分配和断线恢复；再依据公网日志调整缓冲/纠正阈值。不要把当前客户端预览与固定小窗口当成完整反作弊或延迟补偿方案。
