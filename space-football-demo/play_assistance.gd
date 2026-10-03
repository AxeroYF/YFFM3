extends RefCounted
## Presentation presets; authority validates the level and computes all assistance.
const NAMES:=["低辅助","标准辅助","高辅助"]
const DESCRIPTIONS:=[
 "方向优先、小幅修正传球；接球队员由你主动跑位。",
 "修正附近队友的传球方向；移动时适度帮助对准接球点。",
 "扩大传球选人范围；移动时持续迎球、调整接球朝向，并帮助争取附近自由球。"
]
static func level(value:int)->int:
 return clampi(value,0,2)
