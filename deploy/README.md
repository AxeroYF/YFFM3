# YFFM3 香港灰度服务

本目录提供部署模板，尚未登录或修改用户服务器。已有 Rougelite 可以继续运行；两个进程共享硬件资源，是否有足够余量需要在服务器上测量。

## 与 Rougelite 共存

核对前作工作树的 `deploy/aliyun/yellowdogs-rougelite.service` 和 Nginx 模板：

| 项目 | 已有 Rougelite 配置 | YFFM3 模板 |
| --- | --- | --- |
| 服务 | `yellowdogs-rougelite.service`，Node.js | `yffm3@28765.service`，Godot headless |
| 工作目录 | `/opt/yellowdogs-rougelite/app` | `/opt/yffm3/app/space-football-demo` |
| 系统用户 | `ydl-rougelite` | `yffm3` |
| 对外入口 | Nginx / HTTPS 443、HTTP 80 | UDP 28765 |
| 持久数据 | 原游戏自己的目录 | `/var/lib/yffm3/28765` |

这是本地部署文件的核对，不能据此断言线上配置完全一致。不要覆盖 Rougelite 的目录、环境文件或 Nginx 配置。首次只开一个 YFFM3 实例，支持一场双人对局；后续实例需要不同端口。目前没有自动分配多房间的调度器。

Godot 4 支持 `--headless` 无显示、无 GPU 运行；初次源码灰度可使用编辑器二进制，正式服务器后续再做专用导出。[Godot 官方说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html)

## Linux 首次准备

以下是部署时执行的示例，**本轮没有执行**。要求带 systemd 的 Linux，与客户端一致的 Godot **4.7.2 标准版** Linux 二进制；不需要 .NET、Node.js 或显卡驱动。下载架构必须与服务器一致，不能复制 Windows 的 exe。

1. 先检查：`free -h`、`df -h`、`ss -lunp`、`systemctl status yellowdogs-rougelite`、`systemd-cgtop`。确认 UDP 28765 空闲及原游戏负载。
2. 构建机在仓库根目录运行 `node tools/network-build.mjs`，生成并提交 `space-football-demo/network-build.json`，再运行 `node tools/network-build.mjs --check`。客户端和服务端必须来自同一份源码与清单。Node.js 只用于构建，不是服务端运行依赖。创建专用 `yffm3` 系统用户；将游戏源码放到 `/opt/yffm3/app`，将对应 Godot 放到 `/opt/yffm3/bin/godot` 并授予执行权限。不要携带开发存档、凭据和旧测试日志。
3. 首次上传及资源更新后，在停止 YFFM3 的情况下完成导入：

   ```sh
   /opt/yffm3/bin/godot --headless --editor --path /opt/yffm3/app/space-football-demo --quit
   ```

   查看完整日志确认没有脚本或缺失资源错误。导入后的 `.godot` 缓存须可被服务用户读取；systemd 模板运行时将源码设为只读，因此必须提前导入。生产用户数据在 StateDirectory，缓存另设 CacheDirectory。

4. 专用服务器默认要求邀请码。创建 root 所有、权限 600 的 `/etc/yffm3/28765.env`，内容为 `YFFM3_ROOM_CODE=实际随机邀请码`。使用至少 16 位随机字母数字，通过私下渠道告知朋友；不要写入 Git、命令行参数或公开日志。程序接受 8–128 个字符，缺失或不合法时退出。systemd 从环境文件注入，启动前自动执行版本清单预检。

   核对模板中的路径、系统用户和资源限制，将 `yffm3@.service` 安装到 `/etc/systemd/system/`：

   ```sh
   systemctl daemon-reload
   systemctl enable --now yffm3@28765
   systemctl status yffm3@28765
   journalctl -u yffm3@28765 -f
   ```

   停止或更新第三代只需操作 `yffm3@28765`。模板的 MemoryHigh 512 MiB / MemoryMax 768 MiB 是初始保护值，**不是实测容量**；OOM 会导致本场掉线。CPUWeight 只影响资源竞争时的权重，不保证实时预算。不使用严格 CPUQuota 截断比赛时钟。若原机内存紧张，应减少共置负载或换独立实例，不能直接按内存上限相加当作可用容量。

5. 阿里云安全组及系统防火墙仅增加所需的 UDP 28765。第一轮限制测试玩家来源 IP。邀请码验证在允许游戏 RPC 前完成，验证等待最多 8 秒；入场后未准备最多等待 120 秒。它不是账号认证、短效票据或 DDoS 防护，不作为公开匹配服务开放。

## 地址与客户端

可先填香港服务器真实公网 IP，端口 `28765`。域名建议为 `match-hk.yellowdogsleague.online`，A 记录指向该机器并设为 **DNS only**；这个子域名尚未创建。原 `yellowdogsleague.online` 的网页和代理设置继续服务 Rougelite。普通 Cloudflare HTTP 代理不能转发此任意 UDP 端口。[Cloudflare 端口说明](https://developers.cloudflare.com/fundamentals/reference/network-ports/)

客户端在「联机对战」填写地址、端口和邀请码，再加入、准备。PC 客户端直接连接比赛服务；当前没有把原主页改为 YFFM3 的登录或匹配大厅，也不是网页运行 Godot。当前为 **协议 8**，常规比赛为 5 分钟有效时间。协议及源码 / 规则 / 球员数据清单不一致会拒绝入场；旧客户端需要一起更新。

无 systemd 时，先由外部环境配置 `YFFM3_ROOM_CODE`，再运行前台诊断命令：

```sh
/opt/yffm3/bin/godot --headless --path /opt/yffm3/app/space-football-demo -- --server --port=28765
```

仅受信任的本地网络诊断可显式附加 `--allow-open-room` 允许空邀请码。玩家在客户端创建房间时仍可留空；配置后双方使用同一码。邀请码采用随机挑战与 HMAC 校验，不提供流量加密或服务端身份认证。

双方准备后，场景加载超过 45 秒会通知客户端退出并释放座位，服务器继续监听；比赛中一人离开也会清理本场，双方重新加入即可开始新局。正常终场支持原连接再战。断线续赛尚未实现。源码运行会检查清单是否过期；导出程序使用随包携带的源码清单，并校验包内 JSON 数据，因此导出前必须执行清单检查。清单不覆盖全部贴图，也不是反作弊证明。

## 第一轮灰度记录

每 10 秒及终场输出 `NETWORK_METRICS`：双方应用层 RTT、快照缺口、抖动、位置纠正、输入积压、模拟步耗时及载荷字节。客户端左上角也显示双方 RTT / 本端快照抖动；未知 RTT 显示 `--`。日志中的 `fault_profile` 应为全零，部署时不要带 `--delay` 等故障注入参数。

- 分别用移动、电信、联通玩家对局，记录平均/高位延迟、丢包时的接球/射门体验、异常时间与服务日志。
- 同时观察 Rougelite 的请求耗时、CPU、RSS、网卡流量。模拟 60 Hz 每步预算约 16.67 ms；`tick_mean_ms/tick_peak_ms` 包含该回调内计算及快照打包，但不含全部进程、系统调度和公网时间，不能当作完整负载报告。
- `payload_bytes` 是应用层计划发送载荷累计值，包含后来被测试模型丢掉的消息；不是网卡计费流量，也不包含完整 ENet/IP 开销。
- 若资源充足但大陆 RTT 高，先比较运营商和时段，再决定线路加速或换区；增加同机进程不会缩短网络路径。

仍需后续实现的运营功能：账号/短效入场票据、多房间分配、断线重连与比赛恢复、持续容量测试。当前断开会终止本场，不自动补算积分。Linux 服务安装、生产端口、防火墙、域名及真实公网联调均未在本轮验证。
