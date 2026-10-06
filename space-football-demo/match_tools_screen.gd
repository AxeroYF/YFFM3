extends RefCounted
## Match tools views. Mutations are emitted through explicit controller callbacks.
const Team=preload("res://team_config.gd")
var outgoing_slot:=1
func advanced_settings(modal:Control,kit,router,refresh:Callable,back:Callable)->void:
 kit.panel(modal,Rect2(560,235,1440,990))
 kit.text(modal,"操作与比赛选项",Vector2(625,282),44,kit.INK,true)
 var labels={"receive_assist":"接球跑位辅助","shot_assist":"射门辅助","auto_switch":"自动切人","vibration":"手柄震动","replay":"进球回放","strict_rules":"室内附加规则","camera_impact":"镜头冲击","alternate_directions":"方向操作键盘布局"}
 var values={"receive_assist":["低","标准","高"],"shot_assist":["低","标准","高"],"auto_switch":["手动","接球队员","接球与自由球"],"vibration":["关","开"],"replay":["关","开"],"strict_rules":["关","开（下场生效）"],"camera_impact":["关","轻微（默认）","标准"],"alternate_directions":["小键盘 8/2/4/6","I / K / J / L"]}
 var n:=0
 for key in labels:
  var setting:String=key
  var current:int=int(router.options[setting])
  kit.button(modal,labels[setting]+"："+values[setting][current],Rect2(625,385+n*80,1310,66),func():
   router.options[setting]=(int(router.options[setting])+1)%values[setting].size()
   router.update_prompts();router.save_preferences();refresh.call())
  n+=1
 kit.text(modal,"附加规则：任意球 / 门将 4 秒、重复回传与累计犯规罚球。",Vector2(625,1055),23,kit.MUTED)
 kit.button(modal,"返回辅助设置",Rect2(625,1110,1310,68),back)

func substitutions(modal:Control,kit,s,submit:Callable,refresh:Callable,close:Callable)->void:
 kit.panel(modal,Rect2(450,250,1660,900))
 kit.text(modal,"替补席",Vector2(510,295),46,kit.INK,true)
 var team:int=s.view_team
 kit.text(modal,"选择场上球员，再选择替补；重新开球准备时执行。",Vector2(510,365),26,kit.MUTED)
 for i in range(team*Team.SIZE,team*Team.SIZE+Team.SIZE):
  var index:int=i
  var status:String=" · 疲劳 %d%%" % int(s.players[index].fatigue*100) if s.players[index].active else " · 减员 %d 秒" % ceili(s.players[index].sinbin)
  kit.button(modal,("✓ " if index%Team.SIZE==outgoing_slot else "")+s.players[index].name+status,Rect2(510,425+i%Team.SIZE*90,665,75),func():
   outgoing_slot=index%Team.SIZE
   refresh.call())
 for j in s.mechanics.benches[team].size():
  var slot:int=j;var record:Dictionary=s.Library.find(s.mechanics.benches[team][j].id)
  var b=kit.button(modal,record.name+" · "+record.role,Rect2(1210,440+j*100,830,75),func():
   submit.call({"action":s.Mechanics.SUBSTITUTE,"reserve":slot,"out":outgoing_slot})
   close.call())
  b.disabled=(record.role=="GK")!=(outgoing_slot==0) or (not s.players[team*Team.SIZE+outgoing_slot].active and s.players[team*Team.SIZE+outgoing_slot].sinbin>0)
 kit.button(modal,"返回比赛",Rect2(510,1010,1530,75),func(): close.call())

func extra_help(modal:Control,kit,router,back:Callable)->void:
 kit.panel(modal,Rect2(450,180,1660,1080))
 kit.text(modal,"进阶操作",Vector2(515,230),46,kit.INK,true)
 var pad:bool=router.kind=="gamepad"
 var glyph=router
 var short_pass:String=glyph.symbol("pass");var shot:String=glyph.symbol("shoot");var cross:String=glyph.symbol("cross")
 var left:String=glyph.symbol("switch");var right:String=glyph.symbol("finesse")
 var entries:Array=[
  ["右摇杆方向" if pad else "小键盘方向 / IJKL（设置切换）","无球方向切人；持球拉球变向"],
  [glyph.symbol("sprint")+(" + 右摇杆" if pad else " + 方向操作键"),"趟球突破；足球可被对方抢走"],
  ["轻点 "+left+" / 轻点 "+right,"呼叫前插 / 呼叫靠近接应"],
  ["无球按住 "+right,"呼叫一名队友协防"],
  ["按住 "+short_pass+" / "+glyph.symbol("through")+" / "+cross+" 再松开","控制传球力度；"+right+" 修饰为大力地滚球或低平传中"],
  ["接球前 "+short_pass+" / "+shot,"预输入一脚传球 / 射门，短时有效"],
  ["高球 "+short_pass+" / "+cross+" / "+shot,"头球摆渡 / 解围 / 攻门，适时起跳"],
  ["按下右摇杆" if pad else "Backspace","取消待执行动作；进球回放时任意传射键跳过"],
  ["定位球十字键 上 / 下" if pad else "定位球 4 / 5","更换主罚 / 切换短接应、近点、后点配合"],
  ["比赛菜单 → 替补席","申请换人；红牌席位减员后按规则补员"],
  ["快速比赛 F2 / F3","保存当前训练场景 / 重试（仅本地开发模式）"]]
 for i in entries.size():
  kit.text(modal,entries[i][0],Vector2(515,340+i*66),25,kit.CYAN,false,650)
  kit.text(modal,entries[i][1],Vector2(1175,340+i*66),24,kit.INK,false,860)
 kit.button(modal,"返回基础操作",Rect2(515,1140,1530,72),back)
