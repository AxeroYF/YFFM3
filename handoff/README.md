# YFFM3 对话交接

更新：2026-10-04，Asia/Shanghai。

本目录交接的是第三代项目 **YFFM3 · 群星绿茵**。主游戏采用 Godot，比赛为每方五人的即时操控足球。前作目录仅作为历史素材来源。

## 阅读顺序

1. [CURRENT_STATE.md](CURRENT_STATE.md)：目标、用户已确定的要求、完成内容、当前边界与后续建议。
2. [MANIFEST.md](MANIFEST.md)：项目地图、启动方式和修改不同系统时的入口。
3. [VERIFICATION.md](VERIFICATION.md)：已经执行的验证、证据位置、复现命令与未验证项。
4. [NEW_CHAT_PROMPT.md](NEW_CHAT_PROMPT.md)：可复制到新对话的接续提示。

## 仓库身份

- GitHub：[AxeroYF/YFFM3](https://github.com/AxeroYF/YFFM3)，私有仓库。
- 开发分支：`codex/yffm3`，跟踪 `origin/codex/yffm3`。
- 当前电脑路径：`D:\Project\game_test\.worktrees\YFFM3`。
- 游戏代码基线提交：`884c4e6d718fa6e9e4309fa11c21515130d078ff`。
- 交接文档在基线之后单独提交；最新提交以 `git log -1` 为准。

虽然当前目录位于 `.worktrees/` 下，它现在拥有自己的 `.git/`，是独立仓库。运行 `git rev-parse --show-toplevel` 应得到 YFFM3 目录；不要把父目录的 `football_rouge_online` 当成本项目远程仓库。

## 本轮交付

独立 Git 仓库与私有远程已建立，源码、386 名球员完整数据和卡画、人体素材、脚本及现有说明进入版本管理。引擎、导出模板、缓存、存档、构建、测试截图和运行日志保留在本机并被忽略。

交接整理没有新增游戏机制或改变键位。进入新对话后按用户下一项需求继续开发即可。

## 更新约定

游戏行为改变时同步 `CURRENT_STATE.md`；文件入口改变时更新 `MANIFEST.md`；只有实际执行过的检查才能写入 `VERIFICATION.md`。保留通过测试的范围和未验证的范围，避免把历史设计建议写成已实现功能。
