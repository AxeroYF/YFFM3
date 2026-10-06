# 传奇球员外观第一批

更新：2026-10-04。以下为模型升级开发时记录；模型与六人制等后续已在 `6f6c19e` 纳入 Git 并推送，最新状态见 CURRENT_STATE.md。后续已接入体型手感机制，详见 [PHYSIQUE_GAMEPLAY.md](PHYSIQUE_GAMEPLAY.md)；下方验证记录描述模型首批交付时的范围。

## 覆盖与资料边界

- 共 **67 名**：球员库中 `legendary=true` 的 61 名，以及 6 名沿用 `legend-` ID、未填写该标记的老记录。后者包含贝肯鲍尔、齐达内、小罗、贝利、姆巴佩、哈兰德。
- 66 名真人球员与 1 张“梅老鼠”趣味卡。趣味卡暂采用人形足球员骨架，增加鼠耳、鼻部装饰与蓝灰色外观；曾向用户询问偏好，截至交付未收到回复。
- 逐张查看现有本地卡画。身高继续取自原球员库；肤色、肩宽、腰胯、肢体、头脸、发型、胡须是根据卡画制作的美术近似，并非身体测量或真人扫描。
- 黑白卡画迪斯蒂法诺的肤色明确标记为暂定。没有用国籍、种族字段或随机哈希推导外观，也没有虚构体重或修改来源数据。
- 386 人的原始球员记录、26 项能力和卡画均未修改。非传奇球员继续使用已有外观。

## 实现

- `scripts/build-legend-appearances.mjs`：逐人配置的作者源，运行后输出 `assets/humanoid/legend_appearances.json`。配置以稳定球员 ID 为键，与场上位置、主客队无关。
- `player_appearance.gd`：加载、查找及传奇覆盖判定。
- `player_body.gd`：在原有身高/触球数据之上合并视觉配置。肩、腰胯、躯干厚度、四肢粗细、臂展、腿身比例、头宽/深、下颌和鼻部采用连续塑形。
- `player_morph.gd`：统一变形函数同时作用于网格、衣服、发型、骨骼 rest、inverse bind 和 IK。保留连续 MakeHuman 人体及 163 根骨骼，避免部件拼接缝隙。
- `player_groom.gd`：使用同一身体适配后的 CC0 发型网格，提供短发、侧梳、中长发、卷发、束发等；寸头、剃短发及后退发际线贴合原头皮；古利特长束卷发附加曲线发束。长发额前区域做了避眼处理。
- `skin_tint.gdshader`：在原皮肤纹理细节上调肤色；胡须遮罩保存在未摆姿势网格的顶点颜色中，随蒙皮一起变形，避免头球、转头时胡须滑动。支持胡茬、全须、山羊胡和小胡子。
- 每实例独立的皮肤、头发及球衣材质；几何缓存键包含所有体型/脸型因子，修复旧键遗漏肌肉厚度的问题。身体与发型缓存各最多 32 个，浏览 67 人不会无限增长。
- 比赛、换人和网络按球员 ID 恢复时均调用同一外观入口。仍支持原 `customize_kit()`，后续服饰自定义入口保留。
- 首批交付时这些塑形仅影响视觉；后续已将身体比例接入有限的运动、地面触球、身体碰撞和护球修正。发型、肤色、头脸仍仅为外观；原能力及身高决定的垂直接触高度保留。当前参数以 PHYSIQUE_GAMEPLAY.md 为准。

## 预览

双击根目录 `Start-Legend-Models.cmd`，或主菜单 → 设置 → 球员模型展示。

展厅共 17 页，每页最多 4 人，提供前/侧/背面、旋转、跑动以及近看外观；卡画与身高在同屏显示。近看镜头随球员实际身高定位。

```powershell
node scripts/build-legend-appearances.mjs
node scripts/build-human-model.mjs
.\godot.cmd --headless --path space-football-demo --script res://legend_models_tests.gd
.\godot.cmd --path space-football-demo --fullscreen --resolution 2560x1440 -- --verify-legends
```

构建脚本需要仓库内 `tools/makehuman-assets/` 的源文件，无需 Blender。`build-human-model.mjs` 保持原人体 JSON 哈希不变，额外导出独立发型 JSON、纹理及来源校验表。来源是 [MakeHuman 官方 CC0 资源包](https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip)，[官方资源许可](https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.ASSETS.md)及本地许可文件保留。

## 验证及剩余精修

- `legend_models_tests.gd`：**608 项通过**。所有 67 人覆盖、跨槽位一致、源身高、骨骼/网格共同变形、动画有效、物理空间不因外观变大、原始数据不变、缓存键区分不同脸型。
- `--verify-legends`：**162 项通过**。17 页全部实际 2560×1440 渲染；真实 Skin 的 inverse bind；缓存上限；12 名传奇的比赛实例；网络状态编解码后的同一外观；换人重建身体和发型。
- `tests.gd`：**531 项通过**，12 场 AI 比赛合计 30 球，三个自动操作对局全部完成。
- 本机证据：`space-football-demo/artifacts/legend-tests.log`、`legend-visual.log`、`legend-regression.log`、`legend-page-01.png` 至 `legend-page-17.png`、`legend-close-*.png`、`legend-running.png`、`legend-match-actions.png`、`legend-contact-sheet.png`。证据仍被 Git 忽略。
- 日志仅余现有沙箱系统证书库读取错误；最终运行无脚本、着色器或材质错误。首次测试曾遇到 dummy renderer 释放 ShaderMaterial 的错误，已把 CPU 骨骼/网格测试与真实图形材质测试分开，最终两条路径均重新通过。
- 这是差异化美术基础版，仍共用连续人体拓扑。真人面部相似度、毛发纹理、球衣细节和极端动作的近景效果仍需逐人精修；没有新增真人动捕、头发动力学、安卓测试或客户端打包。本轮网络检查为状态编解码，未重跑新的多进程 ENet 压测。
