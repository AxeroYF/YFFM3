extends RefCounted
## Reproducible application-level weak-network model. Reliable loss is simulated
## as delayed retransmission, never silently dropping an acknowledged action.
var delay_ms:=0
var jitter_ms:=0
var loss_every:=0
var reorder_every:=0
var burst_every:=0
var queue:Array=[]
var serial:=0
var sent:=0
var dropped:=0
var retried:=0
var delivered:=0
var payload_bytes:=0
var kinds:Dictionary={}
var reliable_due:Dictionary={}
var rng:=RandomNumberGenerator.new()

func configure(delay:int,jitter:int,loss:int,reorder:int=0,burst:int=0,seed_value:int=971)->void:
 delay_ms=maxi(0,delay);jitter_ms=maxi(0,jitter);loss_every=maxi(0,loss)
 reorder_every=maxi(0,reorder);burst_every=maxi(0,burst);rng.seed=seed_value

func send(kind:String,peer:int,payload:Array,reliable:bool,now:int)->void:
 if queue.size()>=1024: dropped+=1;return
 serial+=1;sent+=1
 payload_bytes+=var_to_bytes(payload).size()
 kinds[kind]=int(kinds.get(kind,0))+1
 var lost:bool=(loss_every>0 and serial%loss_every==0) or (burst_every>0 and serial%burst_every<3)
 if lost and not reliable: dropped+=1;return
 var due:=now+maxi(0,delay_ms+rng.randi_range(-jitter_ms,jitter_ms))
 if lost: due+=maxi(70,delay_ms*2);retried+=1
 if reorder_every>0 and serial%reorder_every==0: due+=45
 if reliable:
  var channel:=str(peer)+":"+kind
  due=maxi(due,int(reliable_due.get(channel,0)));reliable_due[channel]=due
 queue.append({"kind":kind,"peer":peer,"payload":payload,"due":due,"serial":serial})

func take(now:int)->Array:
 queue.sort_custom(func(a,b):return a.due<b.due or (a.due==b.due and a.serial<b.serial))
 var ready:Array=[]
 while not queue.is_empty() and int(queue[0].due)<=now:
  ready.append(queue.pop_front());delivered+=1
 return ready

func reset()->void:
 queue.clear();reliable_due.clear();serial=0;sent=0;dropped=0;retried=0;delivered=0
 payload_bytes=0;kinds.clear()
