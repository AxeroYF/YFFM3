extends RefCounted
## SceneMultiplayer authentication runs before peers can issue game RPCs.
signal failed(reason:String)
var api:SceneMultiplayer
var protocol:=0
var build:=""
var code:=""
var capacity:=2
var challenges:Dictionary={}
var rejected:Dictionary={}
var crypto:=Crypto.new()

func configure(value:SceneMultiplayer,version:int)->void:
 api=value;protocol=version
 api.auth_callback=receive
 api.auth_timeout=8.0
 api.server_relay=false
 api.peer_authenticating.connect(begin)
 api.peer_authentication_failed.connect(auth_failed)

func reset()->void:
 challenges.clear();rejected.clear()

func begin(id:int)->void:
 if not api.is_server(): return
 if api.get_peers().size()>=capacity:
  reject(id,"房间已满，请稍后重试");return
 var nonce:=crypto.generate_random_bytes(32).hex_encode()
 challenges[id]=nonce
 api.send_auth(id,JSON.stringify({"type":"challenge","version":protocol,"build":build,"nonce":nonce}).to_utf8_buffer())

static func proof(secret:String,nonce:String,version:int,identity:String)->String:
 var hmac:=HMACContext.new()
 hmac.start(HashingContext.HASH_SHA256,secret.sha256_buffer())
 hmac.update((str(version)+":"+identity+":"+nonce).to_utf8_buffer())
 return hmac.finish().hex_encode()

func receive(id:int,bytes:PackedByteArray)->void:
 if rejected.has(id): return
 if bytes.size()>1024 or bytes.is_empty():
  if api.is_server(): reject(id,"入场数据无效")
  else: failed.emit("服务器入场数据无效")
  return
 var message=JSON.parse_string(bytes.get_string_from_utf8())
 if not message is Dictionary:
  if api.is_server(): reject(id,"入场数据无效")
  else: failed.emit("服务器入场数据无效")
  return
 if not api.is_server() and id==1 and message.get("type")=="reject":
  failed.emit(str(message.get("reason","无法加入房间")).left(100));return
 if message.get("version")!=protocol or message.get("build")!=build:
  if api.is_server(): reject(id,"游戏版本或资源不一致，请使用同一测试包")
  else: failed.emit("游戏版本或资源不一致，请使用同一测试包")
  return
 if api.is_server():
  if message.get("type")!="proof" or not challenges.has(id): reject(id,"入场数据无效");return
  var expected:=proof(code,challenges[id],protocol,build)
  challenges.erase(id)
  if not message.get("proof") is String or not crypto.constant_time_compare(expected.to_utf8_buffer(),str(message.proof).to_utf8_buffer()):
   reject(id,"邀请码不正确，请向房主确认");return
  api.complete_auth(id)
 elif id==1 and message.get("type")=="challenge" and message.get("nonce") is String and message.nonce.length()==64:
  api.send_auth(id,JSON.stringify({"type":"proof","version":protocol,"build":build,"proof":proof(code,message.nonce,protocol,build)}).to_utf8_buffer())
  api.complete_auth(id)
 else: failed.emit("服务器入场数据无效")

func reject(id:int,reason:String)->void:
 challenges.erase(id)
 rejected[id]=Time.get_ticks_msec()+300
 api.send_auth(id,JSON.stringify({"type":"reject","reason":reason}).to_utf8_buffer())

func auth_failed(id:int)->void:
 challenges.erase(id);rejected.erase(id)
 if not api.is_server(): failed.emit("入场验证失败或超时，请确认测试包和邀请码")

func tick()->void:
 for id in rejected.keys():
  if Time.get_ticks_msec()>=int(rejected[id]):
   rejected.erase(id)
   if id in api.get_authenticating_peers(): api.disconnect_peer(id)
