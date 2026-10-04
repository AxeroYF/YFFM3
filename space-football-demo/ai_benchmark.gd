extends SceneTree
const Team=preload("res://team_config.gd")
const Match=preload("res://match_sim.gd")
const Campaign=preload("res://campaign.gd")

func _initialize()->void:
 await process_frame
 var results:Array=[]
 for tactic in 3:
  for seed_value in [451,8127]:
   var s=Match.new()
   var competitive:bool="--competitive" in OS.get_cmdline_user_args()
   s.setup(Campaign.new(),seed_value,Match.Squad.DEFAULT,Match.Squad.DEFAULT,competitive)
   s.teams[0].human=false;s.teams[1].human=false
   s.teams[0].tactic=tactic;s.teams[1].tactic=tactic
   s.duration=60;s.overtime_duration=5;s.freeze=0
   var samples:=0;var crowded:=0;var swarmed:=0;var support:=0
   var completed:=0;var intercepted:=0;var pending_team:=-1
   var cost:=0;var ticks:=0
   for tick in 10000:
    var before_passes:int=s.passes[0]+s.passes[1]
    var before_shots:int=s.shots[0]+s.shots[1]
    var start:=Time.get_ticks_usec()
    s.step(1.0/60)
    cost+=Time.get_ticks_usec()-start;ticks+=1
    if s.passes[0]+s.passes[1]>before_passes: pending_team=s.last_touch/Team.SIZE
    if s.shots[0]+s.shots[1]>before_shots or s.phase!="play": pending_team=-1
    if pending_team>=0 and s.owner>=0:
     if s.owner/Team.SIZE==pending_team: completed+=1
     else: intercepted+=1
     pending_team=-1
    if tick%12==0 and s.owner>=0 and s.phase=="play" and s.freeze<=0:
     samples+=1
     var team:int=s.owner/Team.SIZE
     var crowded_now:=false;var close_defenders:=0;var outlets:=0
     for i in range(team*Team.SIZE+1,team*Team.SIZE+Team.SIZE):
      for j in range(i+1,team*Team.SIZE+Team.SIZE):
       if s.players[i].pos.distance_to(s.players[j].pos)<3: crowded_now=true
      if i!=s.owner and s.players[i].pos.distance_to(s.players[s.owner].pos)>4 and s.players[i].pos.distance_to(s.players[s.owner].pos)<16: outlets+=1
     for i in range((1-team)*Team.SIZE+1,(1-team)*Team.SIZE+Team.SIZE):
      if s.players[i].pos.distance_to(s.ball)<3.5: close_defenders+=1
     if crowded_now: crowded+=1
     if close_defenders>1: swarmed+=1
     if outlets>=2: support+=1
    if s.finished: break
   var result:={"seed":seed_value,"tactic":tactic,"finished":s.finished,"score":s.score,"passes":s.passes,"shots":s.shots,"completed_passes":completed,"intercepted_passes":intercepted,"crowded_attack_fraction":float(crowded)/maxi(1,samples),"multiple_close_defenders_fraction":float(swarmed)/maxi(1,samples),"two_short_outlets_fraction":float(support)/maxi(1,samples),"mean_step_us":float(cost)/ticks}
   results.append(result);print("AI_BENCHMARK ",JSON.stringify(result))
 var name:="ai-before.json" if "--baseline" in OS.get_cmdline_user_args() else "ai-competitive.json" if "--competitive" in OS.get_cmdline_user_args() else "ai-after.json"
 var file:=FileAccess.open("res://artifacts/"+name,FileAccess.WRITE)
 file.store_string(JSON.stringify(results,"  "))
 print("AI_BENCHMARK_COMPLETE ",name)
 quit()
