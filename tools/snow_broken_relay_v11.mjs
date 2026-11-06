// Compile the authored Broken Relay v11 character grid from the Python source.
// Node is used here because it is part of the local toolchain; this never edits v10.
import fs from "node:fs";
const root = new URL("../", import.meta.url);
const source = JSON.parse(fs.readFileSync(new URL("content/land_layouts/snow_mountain_reference.json", root), "utf8"));
const py = fs.readFileSync(new URL("tools/snow_broken_relay_v11.py", root), "utf8");

// Execute the deliberately small authoring subset by mirroring its operations.
const g = Array.from({length:40},()=>Array(48).fill("."));
const set=(x,y,c)=>{if(x>=0&&x<48&&y>=0&&y<40)g[y][x]=c};
const road=(pts,c="=",width=2)=>{for(let p=0;p<pts.length-1;p++){const [ax,ay]=pts[p],[bx,by]=pts[p+1],n=Math.max(Math.abs(bx-ax),Math.abs(by-ay),1);for(let i=0;i<=n;i++){const x=Math.round(ax+(bx-ax)*i/n),y=Math.round(ay+(by-ay)*i/n);for(let k=0;k<width;k++)set(x+(Math.abs(bx-ax)<Math.abs(by-ay)?k:0),y+(Math.abs(bx-ax)>=Math.abs(by-ay)?k:0),c)}}};
const lefts=[34,33,32,31,30,30,29,29,29,30,30,31,31,32,33,34,35,37];
for(let y=0;y<18;y++)for(let x=lefts[y];x<48;x++)set(x,y,x>=46||y<2?"M":x===lefts[y]||y===17?"%":":");
for(const x of [34,35]){set(x,16,"U");set(x,17,"S")}
const spans=[[9,18,29],[10,15,34],[11,13,37],[12,12,38],[13,11,39],[14,11,40],[15,10,40],[16,10,40],[17,11,40],[18,11,39],[19,12,38],[20,13,37],[21,14,36]];
for(const [y,l,r] of spans)for(let x=l;x<=r;x++)set(x,y,x===l||x===r||y===21?"#":",");
for(const x of [16,17]){set(x,21,"S");set(x,22,"s")};for(const x of [32,33]){set(x,21,"L");set(x,22,"=")}
for(let y=11;y<17;y++)for(let x=18;x<30;x++)set(x,y,x===18||x===29||y===11||y===16?"T":"f");for(const x of [23,24])set(x,16,"-");
road([[16,20],[20,18],[24,18],[29,19],[34,18]],"-",2);road([[24,16],[24,19]],"-",2);
for(let y=24;y<40;y++){const l=21+([25,29,35].includes(y)?1:0)-([27,36,37].includes(y)?1:0),r=29+([26,34,38].includes(y)?1:0)-([30,31].includes(y)?1:0);for(let x=l;x<=r;x++)set(x,y,"~");set(l-1,y,"o");set(r+1,y,"o")};for(let x=20;x<=30;x++)set(x,32,"B");
road([[43,39],[42,36],[37,34],[31,32]]);road([[19,32],[16,29],[15,25],[16,22]]);road([[34,17],[38,14],[42,10],[45,6]],"_",2);road([[16,27],[11,26],[7,23]]);
for(const [x,y] of [[3,28],[5,31],[8,34],[11,36],[15,35],[38,29],[41,27],[44,24],[5,18],[7,20]])if(g[y][x]===".")set(x,y,"^");for(const [x,y] of [[9,25],[12,29],[18,27],[33,28],[36,25],[40,22],[8,12]])if(g[y][x]===".")set(x,y,"o");
const legend={".":["snow",0,"snowfield"],",":["terrace",1,"snowfield"],":":["terrace",2,"snowfield"],"#":["cliff",1,"cliff"],"%":["cliff",2,"cliff"],M:["cliff",3,"cliff"],"=":["trail",0,"trail"],"-":["trail",1,"trail"],_:["trail",2,"trail"],s:["stairs",0,"trail"],S:["stairs",1,"trail"],U:["stairs",2,"trail"],L:["ledge",1,"trail"],"~":["ravine",0,"water"],B:["bridge",0,"trail"],o:["rock",0,"rock"],"^":["grove",0,"pine"],T:["timber",1,"timber"],f:["floor",1,"floor"]};
const zones=[{rect:[0,0,48,40],height:0,surface:"snowfield",style:"snow"}];for(let y=0;y<40;y++)for(let x=0;x<48;){const c=g[y][x];let e=x;while(e+1<48&&g[y][e+1]===c)e++;if(c!=="."){const [style,height,surface]=legend[c];zones.push({rect:[x,y,e-x+1,1],height,surface,style})}x=e+1}
const transitions=[{a:[16,21],b:[16,22]},{a:[17,21],b:[17,22]},{a:[34,16],b:[34,17]},{a:[35,16],b:[35,17]},{a:[32,21],b:[32,22],one_way:true},{a:[33,21],b:[33,22],one_way:true}];
source.version=11;source.notes="Isolated Broken Relay v11 preview; v10 remains intact. Windcut is copied unchanged.";Object.assign(source.reference_area,{zones,transitions,shelter:{id:"relay_outpost",rect:[18,11,12,6],doors:[[23,16],[24,16]]},layer_contract:["ground_opaque","cliff_grounded","world_facade_and_props","actors_sorted_by_feet","roof_only_and_rail_occluders","weather_fog","hud"]});
const anchors={relay_locker:[22,14],relay_strongbox:[28,18],bandit_stash:[8,23]};for(const s of source.sites)if(anchors[s.id]){delete s.at;delete s.shelter;s.spatial=anchors[s.id]};const homes={ambush_0:[38,34],ambush_1:[15,27],outpost_perch:[34,15],relay_0:[20,19],relay_1:[29,19],relay_2:[35,18]};for(const h of source.creature_homes)if(homes[h.id]){delete h.at;h.spatial=homes[h.id]}
fs.writeFileSync(new URL("content/land_layouts/snow_mountain_reference_v11.json",root),JSON.stringify(source,null,2)+"\n");console.log(`Wrote v11 with ${zones.length} zones (${py.length} byte authored source)`);
