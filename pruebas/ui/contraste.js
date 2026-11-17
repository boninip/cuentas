// Prueba de colores de Cuentas: lee los tokens reales de index.html (claro y oscuro) y calcula contraste WCAG.
// Texto normal >= 4.5; elementos gráficos (barras, foco) >= 3. Es cálculo sobre los valores del archivo, no prueba en celular.
const fs=require('fs'),path=require('path');
const src=fs.readFileSync(path.join(__dirname,'../../index.html'),'utf8');
const lines=src.split('\n');
const parse=l=>{const o={};for(const m of l.matchAll(/--([a-z0-9-]+):([^;}]+)/g))o[m[1]]=m[2].trim();return o};
// Tokens = bloque común (:root y :root[data-eff=dark]) + propios de Cuentas; los alias viejos se resuelven al valor común.
const blk=re=>{const o={};for(const m of src.matchAll(re))Object.assign(o,parse(m[0]));return o};
const resolve=(th)=>{const r={};for(const k in th){let v=th[k],n=0,m;while((m=/^var\(--([a-z0-9-]+)\)$/.exec(v))&&n++<8)v=th[m[1]]??v;r[k]=v}return r};
const baseL=blk(/^:root\{[^}]*\}/gm);
const light=resolve(baseL);
const dark=resolve({...baseL,...blk(/^:root\[data-eff=dark\]\{[^}]*\}/gm)});
const lin=c=>{c/=255;return c<=0.03928?c/12.92:Math.pow((c+0.055)/1.055,2.4)};
const rgb=h=>{h=h.replace('#','');return[0,2,4].map(i=>parseInt(h.slice(i,i+2),16))};
const Lum=h=>{const[r,g,b]=rgb(h);return .2126*lin(r)+.7152*lin(g)+.0722*lin(b)};
const cr=(a,b)=>{let x=Lum(a),y=Lum(b);if(x<y)[x,y]=[y,x];return(x+.05)/(y+.05)};
const hueOf=h=>{let[r,g,b]=rgb(h).map(v=>v/255);const mx=Math.max(r,g,b),mn=Math.min(r,g,b),d=mx-mn;if(!d)return 0;let H=mx===r?((g-b)/d)%6:mx===g?(b-r)/d+2:(r-g)/d+4;return Math.round((H*60+360)%360)};
const lab=h=>{const[r,g,b]=rgb(h).map(lin);let X=(.4124*r+.3576*g+.1805*b)/.95047,Y=.2126*r+.7152*g+.0722*b,Z=(.0193*r+.1192*g+.9505*b)/1.08883;const f=t=>t>.008856?Math.cbrt(t):7.787*t+16/116;return[116*f(Y)-16,500*(f(X)-f(Y)),200*(f(Y)-f(Z))]};
const dE=(a,b)=>{const p=lab(a),q=lab(b);return Math.hypot(p[0]-q[0],p[1]-q[1],p[2]-q[2])};
const T=[ // [fg, bg, mínimo, nota]
['fg','bg',4.5],['fg','card',4.5],['fg','tile',4.5],['fg','field',4.5],
['muted','bg',4.5],['muted','card',4.5],['muted','tile',4.5],['muted','field',4.5],
['accent-text','bg',4.5],['accent-text','card',4.5],['accent-text','tile',4.5],
['logo','bg',4.5],['logo','card',4.5],['logo','tile',4.5],
['accent-fg','accent',4.5],['warm-fg','warm',4.5],['#FFFFFF','accent',4.5,'texto del hero'],['#FFFFFF','bad-solid',4.5,'aviso de error'],
['warm-text','bg',4.5],['warm-text','card',4.5],
['good','bg',4.5],['good','card',4.5],['good','pos-bg',4.5],['bad','bg',4.5],['bad','card',4.5],['bad','neg-bg',4.5],
['a1fg','a1bg',4.5],['a2fg','a2bg',4.5],['a3fg','a3bg',4.5],
// gráficos (barras, leyendas, foco): 3:1
['accent-text','card',3,'barra/foco'],['accent-text','bg',3,'foco'],['good','card',3,'barra a favor'],['bad','card',3,'barra en contra'],['good','tile',3,'pista de deuda'],['bad','tile',3,'pista de deuda'],['warm-text','card',3,'barra elegida'],
...[1,2,3,4,5,6].flatMap(n=>[['k'+n,'card',3,'categoría'],['k'+n,'bg',3,'categoría']])];
let fails=0,rows=[];
for(const[name,th]of[['claro',light],['oscuro',dark]]){
 const v=k=>k.startsWith('#')?k:th[k];
 for(const[f,b,min,nota]of T){const r=cr(v(f),v(b));const ok=r>=min;if(!ok)fails++;rows.push([name,f+' / '+b,v(f)+' / '+v(b),r.toFixed(2),min,ok?'OK':'FALLA',nota||''])}
}
for(const r of rows)console.log(r.join(' | '));
const worst=n=>rows.filter(r=>r[0]===n&&r[4]===4.5).map(r=>+r[3]).sort((a,b)=>a-b)[0];
console.log('\nPeor contraste de texto: claro',worst('claro'),'· oscuro',worst('oscuro'));
// «te deben» / «debés» no se confunden con el primario ni entre sí
for(const[name,th]of[['claro',light],['oscuro',dark]]){
 const p=th['accent-text'],g=th.good,b=th.bad,w=th['warm-text'];
 const s=`${name}: matiz primario ${hueOf(p)}°, a favor ${hueOf(g)}° (dif ${Math.abs(hueOf(g)-hueOf(p))}°, ΔE ${dE(g,p).toFixed(0)}), en contra ${hueOf(b)}° (dif con a favor ${Math.abs(hueOf(g)-hueOf(b))}°), coral ${hueOf(w)}°`;
 console.log(s);
 if(Math.abs(hueOf(g)-hueOf(p))<30||dE(g,p)<20){console.log('FALLA: «a favor» se parece al primario');fails++}
 if(Math.abs(hueOf(g)-hueOf(b))<90){console.log('FALLA: a favor y en contra se parecen');fails++}
}
// reglas de uso: el amarillo del logo solo es decorativo (punto del logo y viñeta del hero); nunca texto
const goldUses=[...src.matchAll(/([^{};]*)\{[^{}]*var\(--gold\)[^{}]*\}/g)].map(m=>m[1].trim());
const okGold=goldUses.every(s=>/^h1 span$|\.hero-img \.kicker::first-letter$/.test(s.split('}').pop().trim()));
console.log('Usos de --gold:',goldUses.join(' ; '),okGold?'(solo decorativo)':'FALLA');if(!okGold)fails++;
// theme-color y manifest
const tcs=[...src.matchAll(/name="theme-color" content="(#[0-9A-Fa-f]{6})"/g)].map(m=>m[1].toUpperCase());
const man=JSON.parse(fs.readFileSync(path.join(__dirname,'../../manifest.webmanifest'),'utf8'));
const okTc=tcs.includes('#FAF8F4')&&tcs.includes('#12201F')&&!tcs.some(c=>!['#FAF8F4','#12201F'].includes(c))&&man.theme_color.toUpperCase()==='#FAF8F4'&&src.includes('m.content=dark?"#12201F":"#FAF8F4"');
console.log('theme-color:',tcs.join(', '),'· manifest',man.theme_color,okTc?'OK':'FALLA');if(!okTc)fails++;
// ninguna variable CSS usada sin definir (salvo con valor de respaldo)
const defd=new Set(Object.keys(baseL));
const undef=[...new Set([...src.matchAll(/var\(--([a-z0-9-]+)(,?)(['$])?/g)].filter(m=>!defd.has(m[1])&&m[1]!=='ck'&&!m[2]&&!m[3]).map(m=>m[1]))];
console.log('Variables usadas sin definir y sin respaldo:',undef.length?undef.join(', '):'ninguna');if(undef.length)fails++;
// colores de la marca vieja
const old=['#637B55','#F7F5EA','#D7B96A','#2F4230','#EDF0DD','#1B241A','#16241A'].filter(c=>src.toUpperCase().includes(c));
console.log('Restos de la paleta vieja:',old.length?old.join(', '):'ninguno');if(old.length)fails++;
// sin degradados decorativos: el único permitido es el velo de legibilidad sobre la foto
const grads=[...src.matchAll(/linear-gradient\([^)]*\)/g)].map(m=>m[0]);
const okG=grads.length===1&&/#12201F/.test(grads[0]);console.log('Degradados:',grads.length,okG?'(solo el velo sobre la foto)':'FALLA');if(!okG)fails++;
console.log(fails?`\n${fails} FALLAS`:'\ncontraste ok');process.exit(fails?1:0);
