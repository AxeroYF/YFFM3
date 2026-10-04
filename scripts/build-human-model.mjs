import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
const source='tools/makehuman-assets',out='space-football-demo/assets/humanoid';
const text=p=>fs.readFileSync(`${source}/${p}`,'utf8');
function obj(file){
 const vertices=[],uv=[],faces=[];let group='body';
 for(const line of text(file).split(/\r?\n/)){
  const a=line.trim().split(/\s+/);
  if(a[0]==='v')vertices.push(a.slice(1,4).map(Number));
  if(a[0]==='vt')uv.push(a.slice(1,3).map(Number));
  if(a[0]==='g')group=a[1];
  if(a[0]==='f')faces.push({group,points:a.slice(1).map(p=>p.split('/').slice(0,2).map(v=>Number(v)-1))});
 }return {vertices,uv,faces};
}
const base=obj('base.obj');
const vertices=structuredClone(base.vertices);
for(const [file,factor] of [['caucasian-male-young.target',1],['universal-male-young-maxmuscle-averageweight.target',0.65]]){
 for(const line of text(file).split(/\r?\n/)){
  if(!/^\d+\s/.test(line))continue;
  const [index,x,y,z]=line.trim().split(/\s+/).map(Number);
  vertices[index]=vertices[index].map((v,axis)=>v+[x,y,z][axis]*factor);
 }
}
const bodyIds=new Set(base.faces.filter(f=>f.group==='body').flatMap(f=>f.points.map(p=>p[0])));
const minY=Math.min(...[...bodyIds].map(i=>vertices[i][1])),maxY=Math.max(...[...bodyIds].map(i=>vertices[i][1]));
const height=maxY-minY;
const normalize=v=>[v[0]/height,(v[1]-minY)/height,v[2]/height].map(n=>Math.round(n*1e7)/1e7);
const rig=JSON.parse(text('default.mhskel'));
const boneNames=[];
function insert(name){if(boneNames.includes(name))return;if(rig.bones[name].parent)insert(rig.bones[name].parent);boneNames.push(name);}
Object.keys(rig.bones).forEach(insert);
const bones=boneNames.map(name=>{
 const b=rig.bones[name],ids=rig.joints[b.head];
 const head=[0,1,2].map(axis=>ids.reduce((v,i)=>v+vertices[i][axis],0)/ids.length);
 return {name,parent:boneNames.indexOf(b.parent),head:normalize(head)};
});
const sourceWeights=JSON.parse(text('default_weights.mhw')).weights;
const weights=vertices.map(()=>[]);
for(const [name,items] of Object.entries(sourceWeights))for(const [index,weight] of items)weights[index].push([boneNames.indexOf(name),weight]);
function packWeights(items){
 const map=new Map();for(const [index,w] of items)if(index>=0&&w>0)map.set(index,(map.get(index)??0)+w);
 const sorted=[...map].sort((a,b)=>b[1]-a[1]).slice(0,4);
 if(!sorted.length)return [[boneNames.indexOf('root'),1]];
 const total=sorted.reduce((s,i)=>s+i[1],0);return sorted.map(([i,w])=>[i,w/total]);
}
const allVertices=vertices.map(normalize),allWeights=weights.map(packWeights);
const surfaces=[];
function emit(mesh,name,positionOffset=0,filter=()=>true){
 const indices=[],uvs=[];
 for(const face of mesh.faces){
  if(!filter(face))continue;
  for(let i=1;i<face.points.length-1;i++)for(const p of [face.points[0],face.points[i],face.points[i+1]]){
   indices.push(p[0]+positionOffset);uvs.push(mesh.uv[p[1]]??[0,0]);
  }
 }if(indices.length)surfaces.push({material:name,indices,uv:uvs});
}
function garment(prefix,name,cutPants=false){
 const mesh=obj(prefix+'.obj'),lines=text(prefix+'.mhclo').split(/\r?\n/);
 const scales=[1,1,1];let mapping=false,deleting=false;const refs=[],hidden=new Set();
 for(const raw of lines){
  const a=raw.trim().split(/\s+/);if(!a[0]||a[0].startsWith('#'))continue;
  if(/^[xyz]_scale$/.test(a[0])){const axis='xyz'.indexOf(a[0][0]);scales[axis]=Math.abs(vertices[Number(a[1])][axis]-vertices[Number(a[2])][axis])/Number(a[3]);}
  if(a[0]==='verts'){mapping=true;continue;}
  if(a[0]==='delete_verts'){mapping=false;deleting=true;continue;}
  if(deleting){for(let i=0;i<a.length;i++){if(a[i+1]==='-'){for(let v=Number(a[i]);v<=Number(a[i+2]);v++)hidden.add(v);i+=2;}else if(/^\d+$/.test(a[i]))hidden.add(Number(a[i]));}continue;}
  if(mapping&&/^\d+$/.test(a[0]))refs.push(a.map(Number));
 }
 assert.equal(refs.length,mesh.vertices.length,`Mapping count ${name}`);
 const offset=allVertices.length;
 for(const a of refs){
  let point,weight;
  if(a.length===1){point=vertices[a[0]];weight=weights[a[0]];}
  else{
   point=[0,1,2].map(axis=>vertices[a[0]][axis]*a[3]+vertices[a[1]][axis]*a[4]+vertices[a[2]][axis]*a[5]+a[6+axis]*scales[axis]);
   weight=[0,1,2].flatMap(k=>weights[a[k]].map(([b,w])=>[b,w*a[3+k]]));
  }
  allVertices.push(normalize(point));allWeights.push(packWeights(weight));
 }
 if(cutPants){
  const parents=mesh.vertices.map((_,i)=>i);
  const find=i=>parents[i]===i?i:(parents[i]=find(parents[i]));
  for(const face of mesh.faces)for(const p of face.points)parents[find(p[0])]=find(face.points[0][0]);
  const tops=new Map();
  for(let i=0;i<parents.length;i++)tops.set(find(i),Math.max(tops.get(find(i))??0,allVertices[i+offset][1]));
  const shirt=f=>tops.get(find(f.points[0][0]))>0.65;
  const kept=mesh.faces.filter(f=>Math.max(...f.points.map(p=>allVertices[p[0]+offset][1]))>=0.385);
  const clipped={...mesh,faces:kept};
  for(const f of kept)for(const p of f.points)allVertices[p[0]+offset][1]=Math.max(0.385,allVertices[p[0]+offset][1]);
  emit(clipped,'jersey',offset,shirt);
  emit(clipped,'shorts',offset,f=>!shirt(f));
 }else if(name==='boots'){
  const kept=mesh.faces.filter(f=>Math.min(...f.points.map(p=>allVertices[p[0]+offset][1]))<0.055);
  for(const f of kept)for(const p of f.points)allVertices[p[0]+offset][1]=Math.min(0.055,allVertices[p[0]+offset][1]);
  emit({...mesh,faces:kept},name,offset);
 }else emit(mesh,name,offset);
 return hidden;
}
const hidden=garment('system/clothes/male_casualsuit06/male_casualsuit06','kit',true);
const shoeHidden=garment('system/clothes/shoes02/shoes02','boots');
garment('system/hair/short02/short02','hair');
garment('low-poly','eyes');
const visible=f=>f.group==='body'&&!(f.points.every(p=>shoeHidden.has(p[0]))&&f.points.every(p=>allVertices[p[0]][1]<0.05))&&!(f.points.every(p=>hidden.has(p[0]))&&f.points.every(p=>allVertices[p[0]][1]>0.40));
const avgY=f=>f.points.reduce((v,p)=>v+allVertices[p[0]][1],0)/f.points.length;
emit(base,'skin',0,f=>visible(f)&&avgY(f)>0.27);
emit(base,'socks',0,f=>visible(f)&&avgY(f)<=0.27);
fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(`${out}/human_mesh.json`,JSON.stringify({license:'CC0-1.0',source:'MakeHuman Community',vertices:allVertices,weights:allWeights,bones,surfaces}));
for(const [src,dst] of [['system/skins/young_caucasian_male/young_lightskinned_male_diffuse.png','skin.png'],['system/hair/short02/short02_diffuse.png','hair.png'],['brown_eye.png','eyes.png'],['LICENSE.ASSETS.md','LICENSE.CC0.txt'],['LICENSE.md','LICENSE-SETUP.txt']])fs.copyFileSync(`${source}/${src}`,`${out}/${dst}`);
const report={source:'https://github.com/makehumancommunity/makehuman',revision:JSON.parse(text('provenance.json').replace(/^\uFEFF/,'')).revision,systemPack:'https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip',assetLicense:'CC0-1.0',modifications:['male/adult and muscular morphs','normalized body dimensions','clothing lower legs cut to shorts','top four bone weights normalized','per-player proportions applied at runtime'],bones:bones.length,vertices:allVertices.length,triangles:surfaces.reduce((n,s)=>n+s.indices.length/3,0),surfaces:surfaces.map(s=>({material:s.material,triangles:s.indices.length/3})),sha256:crypto.createHash('sha256').update(fs.readFileSync(`${out}/human_mesh.json`)).digest('hex')};
fs.writeFileSync(`${out}/provenance.json`,JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));

// Independent fitted hair meshes share the body's normalization and official weights.
// Keep the canonical body unchanged so non-legendary players retain their old asset.
const hairDirectory=`${out}/hair`;
fs.mkdirSync(hairDirectory,{recursive:true});
const hairReport=[];
for(const style of ['short01','short02','short03','short04','bob01','bob02','afro01','ponytail01']){
 const first=allVertices.length, surfaceStart=surfaces.length;
 const prefix=`system/hair/${style}/${style}`;
 garment(prefix,'hair');
 const data={license:'CC0-1.0',vertices:allVertices.slice(first),weights:allWeights.slice(first),surfaces:surfaces.slice(surfaceStart).map(s=>({...s,indices:s.indices.map(i=>i-first)}))};
 const json=JSON.stringify(data);
 fs.writeFileSync(`${hairDirectory}/${style}.json`,json);
 fs.copyFileSync(`${source}/system/hair/${style}/${style==='afro01'?'afro':style}_diffuse.png`,`${hairDirectory}/${style}.png`);
 hairReport.push({style,vertices:data.vertices.length,triangles:data.surfaces.reduce((n,s)=>n+s.indices.length/3,0),sha256:crypto.createHash('sha256').update(json).digest('hex')});
 allVertices.length=first;allWeights.length=first;surfaces.length=surfaceStart;
}
fs.writeFileSync(`${hairDirectory}/provenance.json`,JSON.stringify({license:'CC0-1.0',source:report.systemPack,modifications:['fitted to the same CC0 base body','normalized to body height','four normalized bone weights retained','style proportions and colours authored at runtime'],meshes:hairReport},null,2));
console.log('Exported',hairReport.length,'CC0 hair meshes');
