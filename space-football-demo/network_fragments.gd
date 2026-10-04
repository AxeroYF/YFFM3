extends RefCounted
## Application fragments stay below ENet's MTU. Incomplete snapshots expire;
## there is no retransmission queue blocking newer state.
const CHUNK:=1000
const MAX_PARTS:=16
var pending:Dictionary={}

static func split(bytes:PackedByteArray)->Array:
 var result:Array=[]
 for offset in range(0,bytes.size(),CHUNK): result.append(bytes.slice(offset,offset+CHUNK))
 return result

func accept(frame:int,index:int,count:int,bytes:PackedByteArray,now:int)->PackedByteArray:
 for key in pending.keys():
  if now-int(pending[key].at)>600 or key<frame-12: pending.erase(key)
 if count<1 or count>MAX_PARTS or index<0 or index>=count or bytes.is_empty() or bytes.size()>CHUNK: return PackedByteArray()
 if not pending.has(frame):
  if pending.size()>=8: return PackedByteArray()
  pending[frame]={"at":now,"count":count,"parts":{}}
 var entry:Dictionary=pending[frame]
 if entry.count!=count: return PackedByteArray()
 entry.parts[index]=bytes
 if entry.parts.size()!=count: return PackedByteArray()
 var result:=PackedByteArray()
 for part in count: result.append_array(entry.parts[part])
 pending.erase(frame)
 return result
