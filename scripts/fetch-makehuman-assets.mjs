import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import {execFileSync} from 'node:child_process';
import assert from 'node:assert/strict';
const root='tools/makehuman-assets';
const entries=JSON.parse(fs.readFileSync(`${root}/pack-index.json`,'utf8'));
const url='https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip';
const requested=process.argv.slice(2);
for(const name of requested){
 const item=entries.find(e=>e.name===name);assert(item,`Missing entry ${name}`);
 const output=path.join(root,'system',name);
 assert(path.resolve(output).startsWith(path.resolve(root,'system')+path.sep));
 if(fs.existsSync(output)){console.log('cached',name);continue;}
 const bytes=execFileSync('curl.exe',['--fail','--location','--silent','--show-error','--max-time','180','--range',`${item.offset}-${item.offset+item.compressed+4095}`,url],{maxBuffer:32*1024*1024});
 assert.equal(bytes.readUInt32LE(0),0x04034b50,'ZIP local header');
 const start=30+bytes.readUInt16LE(26)+bytes.readUInt16LE(28);
 const packed=bytes.subarray(start,start+item.compressed);
 const data=item.method===8?zlib.inflateRawSync(packed):packed;
 assert.equal(data.length,item.size,'Uncompressed length');
 fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,data);
 console.log('extracted',name,data.length);
}
