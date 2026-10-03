extends SceneTree
const Library=preload("res://player_library.gd")
const Ratings=preload("res://player_ratings.gd")
func _initialize()->void:
 var rows:Array=[]
 for record in Library.all():
  var ratings:=Ratings.derive(record.attributes,float(record.heightCm))
  rows.append({"id":record.id,"name":record.name,"role":record.role,"height_cm":record.heightCm,"agility":record.attributes.agility,"acceleration":record.attributes.acceleration,"dribbling":record.attributes.dribbling,"strength":record.attributes.strength,"turn_180_ms":snappedf(ratings.turn_time*1000,0.1),"turn_90_ms":snappedf(ratings.turn_time*500,0.1),"turn_45_ms":snappedf(ratings.turn_time*250,0.1)})
 rows.sort_custom(func(a,b):return a.turn_180_ms<b.turn_180_ms)
 var total:=0.0
 var lines:="386 名球员转身设定（游戏数值，不是现实测量）\n180° 理论范围限定 224～352 ms；全体时长增加 60%，角速度降低 37.5%。90° 为一半，45° 为四分之一。\n60 Hz 实际到位时间会向上取整至一个物理帧，最大额外约 16.7 ms。\n响应系数：灵活 65% + 加速 20% + 盘带 15%。身高、力量仅提供小幅体型修正。\n原有 26 项能力保持不变，不新增原始能力；转身为派生比赛系数。\n\n姓名 | ID | 位置 | 身高 | 灵活/加速/盘带/力量 | 180°/90°/45°（ms）\n"
 for row in rows:
  total+=row.turn_180_ms
  lines+="%s | %s | %s | %d cm | %d/%d/%d/%d | %.1f / %.1f / %.1f\n" % [row.name,row.id,row.role,row.height_cm,row.agility,row.acceleration,row.dribbling,row.strength,row.turn_180_ms,row.turn_90_ms,row.turn_45_ms]
 var data:={"count":rows.size(),"minimum_ms":rows[0].turn_180_ms,"maximum_ms":rows[-1].turn_180_ms,"mean_ms":snappedf(total/rows.size(),0.1),"players":rows}
 FileAccess.open("res://artifacts/player-turning.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
 FileAccess.open("res://artifacts/球员转身时间一览.txt",FileAccess.WRITE).store_string(lines)
 print("TURNING_REPORT count=",data.count," min_ms=",data.minimum_ms," max_ms=",data.maximum_ms," mean_ms=",data.mean_ms)
 for id in ["legend-messi","legend-haaland","s4-fc26-252371","s4-fc26-203376","legend-courtois"]:
  for row in rows:
   if row.id==id: print(JSON.stringify(row))
 quit()
