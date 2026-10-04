// Authored from the local card portraits. No nationality/race-to-colour rules,
// random hashes, measured weights, or scanned-likeness claims.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const catalog=JSON.parse(fs.readFileSync('space-football-demo/assets/player-library/catalog.json','utf8'));
const builds={
 tall:{label:'高挑 / 长肢',shoulder_scale:.97,waist_scale:.94,hip_scale:.97,torso_depth:.95,limb_scale:.96,arm_span:1.025,leg_bias:.008},
 keeper:{label:'宽肩 / 长臂',shoulder_scale:1.07,waist_scale:1.02,hip_scale:1.01,torso_depth:1.04,limb_scale:1.02,arm_span:1.025,leg_bias:.003},
 lean:{label:'修长 / 轻盈',shoulder_scale:.94,waist_scale:.90,hip_scale:.95,torso_depth:.92,limb_scale:.93,arm_span:1.0,leg_bias:.006},
 balanced:{label:'匀称 / 运动型',shoulder_scale:1.0,waist_scale:.98,hip_scale:1.0,torso_depth:1.0,limb_scale:1.0,arm_span:1.0,leg_bias:0},
 compact:{label:'紧凑 / 低重心',shoulder_scale:1.01,waist_scale:1.02,hip_scale:1.05,torso_depth:1.02,limb_scale:1.07,arm_span:.985,leg_bias:-.010},
 powerful:{label:'宽肩 / 强壮',shoulder_scale:1.09,waist_scale:1.04,hip_scale:1.04,torso_depth:1.10,limb_scale:1.09,arm_span:1.01,leg_bias:-.002},
 stocky:{label:'厚实 / 强壮下肢',shoulder_scale:1.09,waist_scale:1.11,hip_scale:1.09,torso_depth:1.12,limb_scale:1.15,arm_span:.985,leg_bias:-.014},
 athletic:{label:'精壮 / 长腿',shoulder_scale:1.04,waist_scale:.94,hip_scale:.97,torso_depth:1.03,limb_scale:1.03,arm_span:1.015,leg_bias:.007}
};
// profile key | build | skin | hair | hairstyle | facial hair | head width | jaw | nose
const rows=`
Courtois|tall|d4ad90|29221c|quiff|none|.95|1.04|1.03
Neuer|keeper|dfb797|8c704b|crop|none|1.02|1.09|1.02
Buffon|keeper|c89b78|25221f|swept|stubble|.98|1.05|1.10
Casillas|balanced|d0a27f|2d231e|short|stubble|.98|1.02|1.01
Kahn|powerful|ddb496|987b53|swept|none|1.07|1.14|1.06
Júlio César|keeper|bd956e|28231d|crop|none|1.08|1.08|1.04
Vítor Baía|balanced|c6a080|392e23|crop|none|1.0|1.04|1.02
Beckenbauer|lean|d1ad91|584536|swept|none|.97|1.02|1.06
Maldini|athletic|c6a085|503626|waves|none|.96|1.10|1.02
Baresi|compact|cfaa87|685037|curly|none|1.03|1.03|1.06
Nesta|tall|d0a27c|2b211d|long|none|.97|1.09|1.03
Cannavaro|compact|c6a080|483428|long|none|1.03|1.10|.97
Puyol|stocky|c29d77|3d3023|curls_long|none|1.0|1.12|1.05
Ferdinand|tall|a98161|211d19|buzz|stubble|1.02|1.05|1.02
Lahm|compact|dab394|6b4d32|crop|none|.98|.98|.97
Cafu|athletic|a57b54|211e1b|buzz|none|1.02|1.08|1.01
Zanetti|balanced|c9a284|352820|quiff|none|1.02|1.13|1.05
Marcelo|compact|976e4b|262019|afro|full|1.06|1.04|1.07
Roberto_Carlos|stocky|aa835f|30251e|bald|none|1.07|1.12|1.04
Marco Materazzi|powerful|d0ad93|352c25|long|stubble|1.02|1.12|1.08
Zidane|athletic|c6a083|453428|receding|none|1.02|1.06|1.13
Ronaldinho|athletic|8f6947|28211a|tied|none|1.04|1.03|1.12
Kroos|balanced|dfb797|927348|crop|none|1.04|1.09|1.03
Beckham|athletic|d5ad8e|ab8b55|quiff|stubble|.98|1.09|1.03
Modric|lean|d6b596|8c6a41|long|none|.94|.96|1.10
Rodri|powerful|c9a589|3a2a20|crop|stubble|1.04|1.10|1.04
Scholes|compact|dfb29a|8f5831|crop|none|1.07|1.05|1.02
Lampard|balanced|d4ad90|3a2b23|quiff|none|1.05|1.11|1.04
Vieira|tall|6f4f36|211c17|buzz|stubble|.98|1.06|1.07
Makélélé|compact|735238|241e18|buzz|none|1.03|1.08|1.08
Touré|powerful|70503a|241e18|buzz|none|1.04|1.11|1.06
Kaká|lean|caa484|30251d|waves|none|.97|1.03|1.01
Figo|balanced|c49b7b|34291e|swept|stubble|1.0|1.11|1.10
Nedvěd|athletic|d6b492|b39660|long|none|1.01|1.08|1.05
Seedorf|powerful|79563c|292018|bald|none|1.08|1.13|1.10
Riquelme|balanced|c39a73|33281e|short|none|1.03|1.05|1.10
Gattuso|stocky|bd9371|2c241e|long|full|1.06|1.13|1.04
Frank Rijkaard|tall|ac8260|29211a|curly|moustache|1.04|1.09|1.10
Ruud Gullit|powerful|a87c55|30251c|locks|moustache|1.02|1.12|1.13
Rivaldo|lean|af8761|2b241c|buzz|none|.97|1.04|1.10
Didi|lean|a27c59|2a251e|crop|moustache|.96|1.04|1.08
Franck Ribéry|compact|c59b7f|30251d|buzz|stubble|1.0|1.06|1.08
Pelé|compact|916946|28221a|curly|none|1.08|1.07|1.12
Maradona|stocky|b9906d|211e19|curly|none|1.10|1.10|1.06
Ronaldo_Nazário|stocky|bd8f6a|30231a|shaved|none|1.12|1.12|1.08
Messi|compact|d4a581|3b2b20|quiff|full|1.02|1.01|1.02
Cristiano_Ronaldo|athletic|c69b76|2b231b|quiff|none|.98|1.10|1.02
Mbappé|athletic|ac805a|241f18|buzz|none|1.07|1.07|1.02
Haaland|powerful|e1ba9b|bea06c|tied|none|1.08|1.15|.96
Benzema|powerful|bd9472|30241c|buzz|full|1.04|1.08|1.06
Henry|tall|936c48|252018|shaved|goatee|.98|1.04|1.08
Rooney|stocky|d6ab90|684b32|receding|none|1.14|1.14|.98
Drogba|powerful|89623f|251f19|tied|goatee|1.04|1.11|1.13
Etoo|athletic|755437|28221a|shaved|none|.99|1.07|1.07
Shevchenko|athletic|d4b092|745737|swept|none|1.0|1.06|1.01
Batistuta|powerful|c29c78|6c492d|curls_long|stubble|1.03|1.14|1.07
Bergkamp|tall|ddb797|a28356|receding|none|1.0|1.08|1.05
Eusébio|compact|966f4d|2d241a|curly|none|1.09|1.12|1.10
Marco_van_Basten|tall|d1ad8f|5e422b|swept|none|.98|1.06|1.09
Cruyff|lean|d2ad91|513b2b|long|none|.94|1.02|1.04
George_Best|lean|d3ac8f|533a27|long|none|.98|1.05|1.02
Romário|compact|b38a62|31261d|crop|none|1.06|1.09|1.05
Neymar Jr|lean|bd966e|30271d|curly|stubble|.96|1.02|1.02
Alfredo Di Stéfano|athletic|c8a181|503928|receding|none|1.03|1.10|1.06
Hugo Sánchez|compact|b38c68|2d241c|curly|none|1.02|1.07|1.05
Eric Cantona|powerful|cfa78a|3a2b21|crop|stubble|1.07|1.17|1.04
MessiRat|compact|82a6a5|455d5f|mascot|none|1.06|1.01|1.0
`.trim().split('\n');
const profiles={};
for(const row of rows){
 const [key,build,skin,hair,style,beard,head,jaw,nose]=row.split('|');
 const p=catalog.find(p=>p.profile?.profileKey===key);
 assert(p,`Unknown player ${key}`);assert(!profiles[p.id],`Duplicate ${p.id}`);
 const special={Haaland:{hair_length:.58},Ronaldinho:{hair_length:.85},Drogba:{hair_length:.62},Puyol:{hair_volume:1.16},Marcelo:{hair_volume:1.28},Maradona:{hair_volume:1.08},'Ruud Gullit':{hair_length:1.1},Nedvěd:{hair_volume:1.06},'Alfredo Di Stéfano':{note:'黑白卡画；肤色为暂定美术色值，非测量结果。'},MessiRat:{note:'趣味卡：人形运动员骨架配鼠耳与鼻部装饰。'}}[key]??{};
 profiles[p.id]={name:p.name,reference:p.portrait,build,build_name:builds[build].label,...Object.fromEntries(Object.entries(builds[build]).filter(([k])=>k!=='label')),skin,hair,hair_style:style,beard_style:beard,head_width:+head,head_depth:1+(Number(head)-1)*.4,jaw_width:+jaw,nose_scale:+nose,hair_volume:1,hair_length:1,...special};
}
const legends=catalog.filter(p=>p.legendary===true||p.id.startsWith('legend-'));
assert.equal(Object.keys(profiles).length,legends.length);
for(const p of legends)assert(profiles[p.id],`Missing legend ${p.id}`);
fs.writeFileSync('space-football-demo/assets/humanoid/legend_appearances.json',JSON.stringify({version:1,scope:'catalog legendary=true OR legacy legend- ID; includes one fictional card',basis:'Height comes only from player-library/catalog.json. Other proportions, colours and shapes are authored approximations of local card art, not scans or measured anatomy.',profiles},null,2)+'\n');
console.log(`Authored appearance coverage: ${legends.length}/${legends.length}`);
