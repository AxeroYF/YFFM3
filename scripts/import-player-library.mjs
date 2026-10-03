import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=path.resolve(process.argv[2]??path.join(workspace,'../Rougelite'));
const destination=path.join(workspace,'space-football-demo/assets/player-library');
const attributes=['passing','firstTouch','dribbling','crossing','finishing','longShots','heading','setPieces','tackling','marking','positioning','vision','decisions','composure','offBall','discipline','pace','acceleration','strength','stamina','agility','jumping','workRate','aggression','goalkeeping','reflexes'];
const read=relative=>JSON.parse(fs.readFileSync(path.join(source,relative),'utf8').replace(/^\uFEFF/,''));
const hash=data=>crypto.createHash('sha256').update(data).digest('hex');
const catalogPath='assets/data/s4-player-catalog.json';
const registryPath='assets/data/s4-player-profile-registry.json';
const catalog=read(catalogPath),registry=read(registryPath);
const studio=read('data/player-library-admin.json');
const overrides=read('assets/data/s4-production-content-overrides.json');
assert.equal(Object.keys(studio.drafts??{}).length,0,'Source now contains drafts; review before changing the established published-player scope.');
assert.equal(new Set(catalog.map(p=>p.id)).size,catalog.length,'Duplicate source IDs');
const pending=[],excluded=[];
for(const player of catalog){
 const profile=registry.profiles[player.id];
 if(!profile){
  assert(!player.portrait,`Unregistered portrait needs review: ${player.id}`);
  excluded.push({id:player.id,name:player.name,reason:'no_registered_card_art'});continue;
 }
 const file=path.resolve(source,'assets/player-profiles',profile.fileName);
 assert(file.startsWith(path.resolve(source,'assets/player-profiles')+path.sep),'Art path escapes source profile directory');
 assert(fs.existsSync(file),`Missing card art: ${player.id} ${profile.fileName}`);
 assert.equal(Object.keys(player.attributes).length,26,`Attribute count: ${player.id}`);
 for(const key of attributes)assert(Number.isFinite(player.attributes[key]),`Missing numeric attribute ${player.id}.${key}`);
 const bytes=fs.readFileSync(file),sha256=hash(bytes);
 const extension=path.extname(file).toLowerCase();
 assert(['.png','.webp','.jpg','.jpeg'].includes(extension),'Unsupported art format');
 pending.push({player,profile,file,bytes,sha256,asset:`portraits/${sha256}${extension}`});
}
assert.equal(pending.length,Object.keys(registry.profiles).length,'Orphan registry records need review');
fs.mkdirSync(path.join(destination,'portraits'),{recursive:true});
const write=(relative,value)=>fs.writeFileSync(path.join(destination,relative),JSON.stringify(value,null,2)+'\n');
const players=[],manifest=[];
for(const item of pending){
 const output=path.join(destination,item.asset);
 if(fs.existsSync(output))assert.equal(hash(fs.readFileSync(output)),item.sha256,'Existing local art differs');
 else fs.copyFileSync(item.file,output);
 assert.equal(hash(fs.readFileSync(output)),item.sha256,'Copied image hash mismatch');
 const portrait=`res://assets/player-library/${item.asset}`;
 players.push({...structuredClone(item.player),portrait,profile:{...structuredClone(item.profile),imageUrl:portrait},sourcePortrait:item.player.portrait,portraitPosition:{x:item.profile.x,y:item.profile.y,width:item.profile.width}});
 manifest.push({playerId:item.player.id,name:item.player.name,sourceFile:item.profile.fileName,asset:item.asset,sha256:item.sha256,bytes:item.bytes.length});
}
// Preserve all original record fields and original art placement separately from Godot paths.
write('source-snapshot.json',{sourceProject:'黄狗风云 / Rougelite',sourceCatalog:catalogPath,sourceRegistry:registryPath,catalogSha256:hash(fs.readFileSync(path.join(source,catalogPath))),registrySha256:hash(fs.readFileSync(path.join(source,registryPath))),players:pending.map(i=>i.player),profiles:Object.fromEntries(pending.map(i=>[i.player.id,i.profile])),overrides:Object.fromEntries(pending.filter(i=>overrides.players?.[i.player.id]).map(i=>[i.player.id,overrides.players[i.player.id]]))});
write('catalog.json',players);
write('manifest.json',{schemaVersion:1,sourceProject:'黄狗风云 / Rougelite',sourceRecords:catalog.length,imported:players.length,excluded:excluded.length,attributes,assets:manifest});
write('excluded-no-art.json',excluded);
const countBy=key=>players.reduce((acc,p)=>(acc[p[key]]=(acc[p[key]]??0)+1,acc),{});
const report={imported:players.length,uniqueArt:new Set(manifest.map(a=>a.sha256)).size,artBytes:manifest.reduce((n,a)=>n+a.bytes,0),sourceRecords:catalog.length,excludedNoArt:excluded.length,attributeValues:players.length*26,roles:countBy('role'),grades:countBy('grade'),missingHeight:players.filter(p=>p.heightCm==null).length,missingWeakFoot:players.filter(p=>p.weakFoot==null).length,missingSkillMoves:players.filter(p=>p.skillMoves==null).length,attributesOutside1to99:players.flatMap(p=>attributes.filter(k=>p.attributes[k]<1||p.attributes[k]>99).map(k=>({id:p.id,key:k,value:p.attributes[k]}))),verification:'All original records preserved; all copied art SHA-256 verified; no source files modified.'};
write('import-report.json',report);
console.log(JSON.stringify(report,null,2));
