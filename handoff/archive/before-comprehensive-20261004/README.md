# YFFM3 对话交接

更新：2026-10-04，Asia/Shanghai。

本目录交接的是第三代项目 **YFFM3 · 群星绿茵**。主游戏采用 Godot，比赛为每方六人的即时操控足球。前作目录仅作为历史素材来源。

## 阅读顺序

1. [CURRENT_STATE.md](CURRENT_STATE.md)：目标、用户已确定的要求、完成内容、当前边界与后续建议。
   最新联机专项：[NETWORK_GRAY_TEST.md](NETWORK_GRAY_TEST.md)，同机部署：[deploy/README.md](../deploy/README.md)。
2. [MANIFEST.md](MANIFEST.md)：项目地图、启动方式和修改不同系统时的入口。
3. [VERIFICATION.md](VERIFICATION.md)：已经执行的验证、证据位置、复现命令与未验证项。
4. [NEW_CHAT_PROMPT.md](NEW_CHAT_PROMPT.md)：可复制到新对话的接续提示。
5. [SIX_A_SIDE_AND_ROADMAP.md](SIX_A_SIDE_AND_ROADMAP.md)：本轮六人制、任意球依据、冲击反馈与后续机制评估。
6. [LEGEND_MODELS.md](LEGEND_MODELS.md)：67 名传奇首批模型、外观来源、渲染入口与美术精修边界。
7. [PHYSIQUE_GAMEPLAY.md](PHYSIQUE_GAMEPLAY.md)：体型对启动、刹车、变向、伸脚及护球的实际影响，修正幅度、对照数据及协议 4 验证。

## 仓库身份

- GitHub：[AxeroYF/YFFM3](https://github.com/AxeroYF/YFFM3)，私有仓库。
- 开发分支：`codex/yffm3`，跟踪 `origin/codex/yffm3`。
- 当前电脑路径：`D:\Project\game_test\.worktrees\YFFM3`。
- 首次游戏基线：`884c4e6d718fa6e9e4309fa11c21515130d078ff`；交接基线：`78d8e94e711f3b775423ba5fccd5f2485903aef3`。
- 六人制、传奇模型及体型手感机制在工作区；当前提交与未提交改动以 `git log -1` 和 `git status` 为准。

虽然当前目录位于 `.worktrees/` 下，它现在拥有自己的 `.git/`，是独立仓库。运行 `git rev-parse --show-toplevel` 应得到 YFFM3 目录；不要把父目录的 `football_rouge_online` 当成本项目远程仓库。

## 本轮交付

独立 Git 仓库与私有远程已建立，源码、386 名球员完整数据和卡画、人体素材、脚本及现有说明进入版本管理。引擎、导出模板、缓存、存档、构建、测试截图和运行日志保留在本机并被忽略。

交接整理没有新增游戏机制或改变键位。进入新对话后按用户下一项需求继续开发即可。

## 更新约定

游戏行为改变时同步 `CURRENT_STATE.md`；文件入口改变时更新 `MANIFEST.md`；只有实际执行过的检查才能写入 `VERIFICATION.md`。保留通过测试的范围和未验证的范围，避免把历史设计建议写成已实现功能。
