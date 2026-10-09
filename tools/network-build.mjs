import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../space-football-demo');
const manifestPath=path.join(root,'network-build.json');
const normalize=s=>s.replace(/\r\n/g,'\n');
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
const files={};
function walk(dir){
 for(const entry of fs.readdirSync(path.join(root,dir),{withFileTypes:true})){
  const relative=path.posix.join(dir,entry.name);
  if(entry.name.startsWith('.') || ['artifacts','node_modules'].includes(entry.name))continue;
  if(entry.isDirectory()){walk(relative);continue;}
  if(!/\.(gd|gdshader|tscn|tres|godot)$/.test(relative) && !(relative.endsWith('.json') && (dir==='assets' || dir==='assets/humanoid' || relative==='assets/player-library/catalog.json')))continue;
  files[relative]=hash(normalize(fs.readFileSync(path.join(root,relative),'utf8')));
 }
}
walk('');
const ordered=Object.fromEntries(Object.entries(files).sort(([a],[b])=>a<b?-1:1));
const fingerprint=hash(Object.entries(ordered).map(([name,digest])=>`${name}:${digest}\n`).join(''));
const output=JSON.stringify({format:1,fingerprint,files:ordered},null,2)+'\n';
if(process.argv.includes('--check')){
 if(!fs.existsSync(manifestPath)||normalize(fs.readFileSync(manifestPath,'utf8'))!==output){console.error('NETWORK_BUILD_STALE: run node tools/network-build.mjs before testing/export/deployment');process.exit(1);}
 console.log(`NETWORK_BUILD_OK ${fingerprint.slice(0,12)}`);
}else{fs.writeFileSync(manifestPath,output);console.log(`NETWORK_BUILD_UPDATED ${fingerprint.slice(0,12)}`);}
