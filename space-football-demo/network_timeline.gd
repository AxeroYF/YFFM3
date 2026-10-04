extends RefCounted
## One input sample per 60 Hz authority tick. Missing movement holds briefly;
## actions have independent exactly-once receipts and a bounded late window.
const Command=preload("res://network_command.gd")
const BUFFER_TICKS:=2
const LATE_TICKS:=12
const MAX_AHEAD:=120
var samples:Dictionary={}
var actions:Dictionary={}
var cursor:=0
var action_ack:=0
var start_frame:=-1
var last_sample:=0
var held:Dictionary={}
var charge_start:=-1
var charge_player:=-1
var missing:=0
var rejected:=0
var applied:=0

func receive(c:Dictionary,frame:int)->bool:
 if c.is_empty(): return false
 var seq:int=c.seq;var aid:int=c.action_id
 if start_frame<0:
  if seq>600: return false
  cursor=maxi(0,seq-1);start_frame=frame+BUFFER_TICKS
 if seq>cursor+MAX_AHEAD or seq<cursor-LATE_TICKS or aid>action_ack+64: return false
 if seq>cursor and not samples.has(seq): samples[seq]=c.duplicate(true)
 if aid>action_ack and not actions.has(aid): actions[aid]=c.duplicate(true)
 return true

func tick(frame:int)->Dictionary:
 if start_frame<0 or frame<start_frame: return Command.neutral()
 cursor+=1
 if samples.has(cursor):
  held=samples[cursor];samples.erase(cursor);last_sample=cursor
 else: missing+=1
 for seq in samples.keys():
  if seq<=cursor: samples.erase(seq)
 var c:=held.duplicate(true) if cursor-last_sample<=18 else Command.neutral()
 c.action=0
 return c

func ready_actions()->Array:
 var result:Array=[]
 # Missing reliable fallback cannot block all future actions forever.
 if not actions.has(action_ack+1) and not actions.is_empty():
  var ids:=actions.keys();ids.sort()
  if cursor-int(actions[ids[0]].seq)>LATE_TICKS:
   rejected+=int(ids[0])-action_ack-1;action_ack=int(ids[0])-1
 for count in 4:
  if not actions.has(action_ack+1): break
  var c:Dictionary=actions[action_ack+1]
  if int(c.seq)>cursor: break
  action_ack+=1;actions.erase(action_ack)
  if cursor-int(c.seq)>LATE_TICKS:
   rejected+=1;continue
  result.append(c)
 return result

func apply_action(s,team:int,c:Dictionary)->bool:
 if not Command.matches(s,team,c): rejected+=1;return false
 var action:int=c.action
 if action&1:
  charge_start=int(c.seq);charge_player=int(c.player)
 if action&2 and charge_start>=0 and charge_player==int(c.player) and s.teams[team].charging:
  # Both edges use captured input ticks, so jitter cannot alter held-shot power.
  s.teams[team].charge=clampf(0.1+(int(c.seq)-charge_start)/60.0*0.9,0.1,1.0)
 s.apply_command(team,c)
 if action&(2|16|128|s.Mechanics.SWITCH|s.Mechanics.CANCEL): charge_start=-1;charge_player=-1
 applied+=1
 return true
