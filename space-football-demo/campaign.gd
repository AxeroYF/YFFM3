extends RefCounted
## Campaign state is independent of rendering and match simulation.
const MISSIONS = [
	{"name":"澜星", "title":"潮汐初航", "club":"澜星探索者", "tag":"QUALIFIER  /  01", "info":"蓝色海洋之上的轨道球场。熟悉传球与射门，开启星际杯航线。", "rule":"标准磁力场 · 边线能量墙会反弹足球", "color":"56dcca", "strength":0.82, "reward":420},
	{"name":"余烬", "title":"恒星风暴", "club":"余烬日冕队", "tag":"SEMI FINAL  /  02", "info":"靠近恒星的竞技场。太阳风周期性改变自由球轨迹，短传更可靠。", "rule":"每 18 秒出现 6 秒太阳风 · 自由球向下侧漂移", "color":"ff996a", "strength":0.96, "reward":580},
	{"name":"卡西尼", "title":"群星之巅", "club":"卡西尼卫冕者", "tag":"GRAND FINAL  /  03", "info":"在巨行星的星环下，挑战卫冕者。赢下最后一战，捧起群星杯。", "rule":"高速磁力场 · 自由球速度提高 15%", "color":"c0a1ff", "strength":1.08, "reward":900}
]
var stage := 0
var credits := 360
var training := [0, 0, 0, 0, 0]
var keeper := 0
var played := 0
var wins := 0
var goals := 0
var difficulty := 0
var tutorial_seen := false
var save_path := "user://starborne-save.json"
var save_error := ""

func cost(index: int) -> int:
	return 180 + int(training[index]) * 140

func train(index: int) -> bool:
	if index < 0 or index >= training.size() or int(training[index]) >= 5 or credits < cost(index): return false
	credits -= cost(index)
	training[index] += 1
	return true

func recruit() -> bool:
	if keeper > 0 or credits < 500: return false
	credits -= 500
	keeper = 1
	return true

func finish(score: Array) -> Dictionary:
	var won: bool = score[0] > score[1]
	var reward: int = MISSIONS[mini(stage,2)].reward if won else 100
	credits += reward
	played += 1
	goals += int(score[0])
	if won:
		wins += 1
		stage = mini(stage+1,3)
	return {"won":won, "reward":reward, "champion":stage==3}

func data() -> Dictionary:
	return {"version":3,"stage":stage,"credits":credits,"training":training,"keeper":keeper,"played":played,"wins":wins,"goals":goals,"difficulty":difficulty,"tutorial_seen":tutorial_seen}

func save_game() -> bool:
	save_error = ""
	var file := FileAccess.open(save_path+".tmp", FileAccess.WRITE)
	if file == null:
		save_error = "存档写入失败：" + str(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data()))
	file.close()
	var error := DirAccess.rename_absolute(save_path+".tmp", save_path)
	if error != OK:
		save_error = "存档替换失败：" + str(error)
	return error == OK

func load_game() -> bool:
	if not FileAccess.file_exists(save_path): return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not d is Dictionary: return false
	if not (d.get("version") is float or d.get("version") is int): return false
	if int(d.version) not in [1,2,3]: return false
	var levels: Variant = d.get("training",[])
	if not levels is Array or levels.size()!=int(d.version)+2: return false
	for value in levels:
		if not (value is float or value is int): return false
	for key in ["stage","credits","keeper","played","wins","goals","difficulty"]:
		if not (d.get(key) is float or d.get(key) is int): return false
	stage=clampi(int(d.stage),0,3)
	credits=clampi(int(d.credits),0,100000)
	training=[0,0,0,0,0]
	for i in levels.size(): training[i]=clampi(int(levels[i]),0,5)
	keeper=clampi(int(d.keeper),0,1)
	played=maxi(0,int(d.played))
	wins=clampi(int(d.wins),0,played)
	goals=maxi(0,int(d.goals))
	difficulty=clampi(int(d.difficulty),0,1)
	tutorial_seen=bool(d.get("tutorial_seen",false))
	return true
