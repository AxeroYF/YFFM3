extends SceneTree
const Network=preload("res://match_network.gd")
var nodes:Array=[]
var checks:=0
var failures:=0
var rejected_reason:=""
func _initialize()->void:
 Engine.max_fps=120
 call_deferred("run")
func check(value:bool,label:String)->void:
 checks+=1
 if not value: failures+=1;push_error("NETWORK_LIFECYCLE_FAILED "+label)
func make_peer(label:String):
 var branch:=Node.new();branch.name=label;root.add_child(branch)
 var api:=SceneMultiplayer.new()
 set_multiplayer(api,branch.get_path())
 var net=Network.new();net.name="Network";branch.add_child(net);nodes.append(net)
 return net
func wait_for(predicate:Callable,label:String,seconds:float=3.0)->bool:
 var end:=Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec()<end:
  await process_frame
  for node in nodes:
   if node.active: node.advance(1.0/60)
 var passed:bool=predicate.call()
 # Network failure handlers close peers on the next idle turn, outside polling.
 await process_frame
 check(passed,label)
 return passed
func run()->void:
 var server=make_peer("Server")
 var a=make_peer("ClientA")
 var b=make_peer("ClientB")
 a.session_lost.connect(func(reason):rejected_reason=reason)
 server.room_code="";server.require_invite=true
 check(server.host(28853,true)==ERR_INVALID_PARAMETER,"private dedicated server refuses missing invitation")
 server.room_code="short"
 check(server.host(28853,true)==ERR_INVALID_PARAMETER,"short invitation rejected before opening listener")
 server.room_code="test-invite-20261006"
 check(server.host(28853,true)==OK,"dedicated server starts with invitation")
 check(server.multiplayer.auth_timeout==8.0,"unauthenticated connections have bounded timeout")
 a.room_code="wrong-invite";a.join("127.0.0.1",28853)
 if not await wait_for(func():return not a.active,"wrong invitation rejected"): finish();return
 check(server.peers.is_empty() and rejected_reason.contains("邀请码"),"wrong invitation takes no match seat and reports reason")
 a.room_code=server.room_code;a.join("127.0.0.1",28853);a.admission.build="different-build"
 if not await wait_for(func():return not a.active,"different build rejected"): finish();return
 check(server.peers.is_empty(),"mismatched build does not occupy room")
 a.join("127.0.0.1",28853);a.admission.protocol=Network.PROTOCOL-1
 if not await wait_for(func():return not a.active,"old protocol rejected"): finish();return
 a.admission.protocol=Network.PROTOCOL
 # Exercise the engine authentication timeout without an eight-second test delay.
 server.multiplayer.auth_timeout=0.2
 a.multiplayer.auth_callback=func(_id,_data):pass
 a.join("127.0.0.1",28853)
 if not await wait_for(func():return not a.active,"silent authentication expires"): finish();return
 server.multiplayer.auth_timeout=8.0;a.multiplayer.auth_callback=a.admission.receive
 a.join("127.0.0.1",28853)
 if not await wait_for(func():return a.local_team>=0,"correct invitation admitted"): finish();return
 var id:int=server.peers.keys()[0]
 server.lobby_since[id]=Time.get_ticks_msec()-Network.LOBBY_TIMEOUT_MS-1
 if not await wait_for(func():return not a.active,"unready player expires"): finish();return
 check(server.active and server.peers.is_empty(),"idle timeout frees seat and keeps server online")
 a.join("127.0.0.1",28853)
 if not await wait_for(func():return a.local_team>=0 and server.peers.size()==1,"seat reusable after idle expiry"): finish();return
 a.local_roster=[];a.set_ready()
 if not await wait_for(func():return not a.active,"invalid roster rejected and disconnected"): finish();return
 a.local_roster=Network.Squad.DEFAULT.duplicate()
 a.join("127.0.0.1",28853);b.room_code=server.room_code;b.join("127.0.0.1",28853)
 if not await wait_for(func():return a.local_team>=0 and b.local_team>=0,"two invited players admitted"): finish();return
 a.set_ready();b.set_ready()
 if not await wait_for(func():return server.preparing and a.preparing and b.preparing,"both clients receive loading state"): finish();return
 check(server.sim.duration==300 and a.sim.duration==300 and b.sim.duration==300,"five-minute authority duration reaches both clients")
 a.scene_ready()
 server.prepare_started=Time.get_ticks_msec()-Network.LOADING_TIMEOUT_MS-1
 if not await wait_for(func():return not a.active and not b.active,"loading timeout closes both clients"): finish();return
 check(server.active and not server.preparing and server.sim==null and server.peers.is_empty(),"loading timeout recovers the same listening server")
 a.join("127.0.0.1",28853);b.join("127.0.0.1",28853)
 if not await wait_for(func():return a.local_team>=0 and b.local_team>=0,"new players join recovered server"): finish();return
 a.set_ready();b.set_ready()
 if not await wait_for(func():return a.preparing and b.preparing,"new round starts after timeout"): finish();return
 a.scene_ready();b.scene_ready()
 if not await wait_for(func():return server.running and a.running and b.running,"new round passes loading barrier"): finish();return
 a.close()
 if not await wait_for(func():return server.peers.is_empty() and not b.active,"disconnect ends round and clears remaining seat"): finish();return
 check(server.active and not server.running,"disconnect recovery leaves listener healthy")
 a.join("127.0.0.1",28853);b.join("127.0.0.1",28853)
 if not await wait_for(func():return a.local_team>=0 and b.local_team>=0,"room reusable after disconnect"): finish();return
 a.set_ready();b.set_ready()
 if not await wait_for(func():return a.preparing and b.preparing,"third round begins"): finish();return
 a.scene_ready();b.scene_ready()
 if not await wait_for(func():return server.running and a.running and b.running,"third round running"): finish();return
 server.sim.phase="play";server.sim.freeze=0;server.sim.score=[1,0];server.sim.elapsed=300
 if not await wait_for(func():return not server.running and not a.running and not b.running,"normal result reaches both clients"): finish();return
 check(a.sim.score==[1,0] and b.sim.score==[1,0],"normal finish preserves final result")
 a.set_ready();b.set_ready()
 if not await wait_for(func():return a.preparing and b.preparing,"same connected players can rematch"): finish();return
 check(server.active and server.peers.size()==2,"rematch needs no process restart")
 finish()
func finish()->void:
 for node in nodes: node.close();node.get_parent().queue_free()
 print("NETWORK_LIFECYCLE_", "PASS" if failures==0 else "FAILED", " checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
