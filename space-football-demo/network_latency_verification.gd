extends RefCounted
var sent:Dictionary={}
func setup(s)->void:
 sent.clear();s.phase="play";s.freeze=0;s.owner=1;s.teams[0].selected=1;s.teams[1].selected=7
 s.players[1].pos=Vector2.ZERO;s.players[1].dir=Vector2.RIGHT;s.ball=Vector2(0.8,0)
 s.duration=100;s.regulation=100
func bot(s,team:int)->Dictionary:
 var c:Dictionary={"action":0,"move":Vector2.ZERO,"sprint":false,"jockey":false,"aim":0.0,"tactic":1,"assist_active":false}
 if team!=0: return c
 if s.frame>=10 and not sent.has("charge"): c.action=1;sent.charge=true
 elif s.frame>=45 and not sent.has("release"): c.action=2;sent.release=true
 return c
func verify(s)->void:
 assert(s.shots[0]==1,"Weak-network shot must execute exactly once")
 print("NETWORK_LATENCY_ACTION_PASS shots=",s.shots," score=",s.score)
