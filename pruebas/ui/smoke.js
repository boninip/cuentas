// Humo de UI con Supabase simulado (no toca la base). Uso: node pruebas/ui/smoke.js
// Requiere playwright. Cubre: invitación (4 casos), navegación inicio/grupo, liquidar y pago, gasto desde el botón flotante.
const {chromium}=require('playwright');const path=require('path');
const URL='file://'+path.resolve(__dirname,'../../index.html');
const ME='11111111-1111-1111-1111-111111111111',BR='22222222-2222-2222-2222-222222222222',G='33333333-3333-3333-3333-333333333333',TOK='a'.repeat(64);
let fails=0;const ok=(c,m)=>{if(!c){fails++;console.log('FALLA:',m)}else console.log('ok   ',m)};
async function mk(b,{preview,profile=true,owe=true}={}){
 const page=await (await b.newContext({viewport:{width:400,height:900}})).newPage();
 const jwt='x.'+Buffer.from(JSON.stringify({sub:ME})).toString('base64')+'.y';
 await page.addInitScript(([j])=>{localStorage.setItem('cuentas_auth_v1',JSON.stringify({access_token:j,refresh_token:'r',expires_at:Date.now()+3600000,email:'b@test.com'}))},[jwt]);
 const calls=[];let prof=profile?{display_name:'Pau'}:null,debt=owe;
 await page.route('**/*',async r=>{const u=r.request().url();if(!u.includes('supabase.co'))return r.continue();
  const fn=u.split('/rpc/')[1],body=r.request().postData();calls.push(fn+' '+body);const J=v=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(v)});
  switch(fn){
   case 'cuentas_my_pending':return J([{group_id:G,name:'Viaje 1',payments:1,proposals:0,pairs:0}]);
   case 'cuentas_invite_preview':return J(preview);
   case 'core_profile_get':return J(prof);
   case 'core_profile_set':prof={display_name:JSON.parse(body).p_name};return J(null);
   case 'cuentas_invite_accept':return J(G);
   case 'cuentas_my_groups_all':return J([{id:G,name:'Viaje 1',reference_currency:'ARS',status:'open',member_status:'active'}]);
   case 'cuentas_group_get':return J({id:G,name:'Viaje 1',reference_currency:'ARS',status:'open',members:[{user_id:ME,role:'admin',status:'active',display_name:'Pau'},{user_id:BR,role:'member',status:'active',display_name:'Bruno'}]});
   case 'cuentas_balances':return J([{user_id:ME,balance_minor:debt?'-250000':'0',currency:'ARS'},{user_id:BR,balance_minor:debt?'250000':'0',currency:'ARS'}]);
   case 'cuentas_group_payouts':return J([{user_id:BR,alias:'bruno.cuentas',cbu:null,holder_name:'Bruno',bank:'MP'}]);
   case 'cuentas_payment_add':debt=false;return J('p1');
   case 'cuentas_expense_add':return J('e1');
   case 'cuentas_movements_list':return J([{id:'e1',kind:'expense',description:'Vinos',amount_minor:'22000000',currency:'ARS',from_user:BR,occurred_on:'2026-09-09',shares:{[ME]:2750000,[BR]:19250000},created_by:BR}]);
   case 'cuentas_proposals_list':case 'cuentas_delegations_list':case 'core_links_list':case 'cuentas_pairs_list':case 'core_organizable_trips':return J([]);
   default:return J(null);}});
 const errs=[];page.on('pageerror',e=>errs.push(e.message));
 return {page,calls,errs};
}
const views=p=>p.evaluate(()=>[...document.querySelectorAll('section')].filter(s=>!s.hidden).map(s=>s.id));
(async()=>{const b=await chromium.launch();
 // invitación: nuevo sin nombre
 let t=await mk(b,{profile:false,preview:{valid:true,group_id:G,name:'Viaje 1',invited_by:'Paula',members:1,already_member:false}});
 await t.page.goto(URL+'?invite='+TOK);await t.page.waitForSelector('#vInvite',{state:'visible'});
 ok((await views(t.page)).join()==='vInvite','invitación: primera pantalla es la invitación (no el inicio)');
 await t.page.click('#btnAccept');await t.page.waitForTimeout(150);ok(/nombre/i.test(await t.page.textContent('#msg')),'invitación: pide nombre si no hay');
 await t.page.fill('#invName2','Bruno');await t.page.click('#btnAccept');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('core_profile_set'))&&t.calls.some(c=>c.startsWith('cuentas_invite_accept')),'invitación: guarda nombre y acepta');
 ok(!t.page.url().includes('invite='),'invitación: el token sale de la URL');
 // ya miembro / vencida
 t=await mk(b,{preview:{valid:true,group_id:G,name:'Viaje 1',members:2,already_member:true}});await t.page.goto(URL+'?invite='+TOK);await t.page.waitForTimeout(500);
 ok((await views(t.page)).join()==='vGroup','invitación: ya miembro entra directo al grupo');
 t=await mk(b,{preview:{valid:false}});await t.page.goto(URL+'?invite='+TOK);await t.page.waitForTimeout(500);
 ok((await views(t.page)).join()==='vHome'&&/venci/i.test(await t.page.textContent('#msg')),'invitación: vencida va al inicio con aviso');
 // navegación + liquidar + gasto
 t=await mk(b);await t.page.goto(URL);await t.page.waitForSelector('#burger',{state:'visible'});
 ok(await t.page.isVisible('#actDot'),'inicio: punto de actividad en el menú');
 await t.page.focus('#burger');await t.page.keyboard.press('Enter');await t.page.waitForTimeout(100);
 ok(await t.page.evaluate(()=>!!document.activeElement.closest('#drawer')),'teclado: el foco entra al menú');
 ok((await t.page.getAttribute('#burger','aria-expanded'))==='true','teclado: aria-expanded en la hamburguesa');
 await t.page.keyboard.press('Escape');await t.page.waitForTimeout(100);
 ok(!(await t.page.isVisible('#drawer'))&&(await t.page.evaluate(()=>document.activeElement.id))==='burger','teclado: Escape cierra y devuelve el foco');
 await t.page.click('#burger');await t.page.click('[data-d=actividad]');await t.page.waitForTimeout(300);ok(await t.page.isVisible('#pending'),'menú: Actividad');
 await t.page.click('#burger');await t.page.click('[data-d=balance]');await t.page.waitForTimeout(300);ok(/Debés/.test(await t.page.textContent('#balTot')),'balance general: total que debés');ok(/Viaje 1/.test(await t.page.textContent('#balGrp')),'balance general: por grupo');
 await t.page.click('#burger');await t.page.click('[data-d=grupos]');await t.page.waitForTimeout(300);ok(!(await t.page.isVisible('#bnav').catch(()=>false)),'sin barra inferior');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 {const n0=t.calls.filter(c=>c.startsWith('cuentas_balances')).length;await t.page.evaluate(()=>document.dispatchEvent(new Event('visibilitychange')));await t.page.waitForTimeout(400);ok(t.calls.filter(c=>c.startsWith('cuentas_balances')).length>n0,'refresco automático al volver a la app');}
 await t.page.click('#btnSaldos');ok(await t.page.isVisible('#balances'),'grupo: saldos');await t.page.click('[data-pane=saldos] [data-goto]');
 await t.page.click('#btnGear');ok(await t.page.isVisible('#mList'),'grupo: ajustes');await t.page.click('[data-pane=mas] [data-goto]');
 await t.page.click('#btnSettle');await t.page.click('[data-pay]');ok((await t.page.inputValue('#pAmt'))==='2500,00','liquidar: monto prellenado');
 await t.page.click('#btnPay');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('cuentas_payment_add')&&c.includes('250000')),'liquidar: registra pago por 250000');
 await t.page.click('#btnGAdd');await t.page.fill('#eDesc','Coca');await t.page.fill('#eAmt','200');await t.page.click('#btnExpense');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('cuentas_expense_add')),'gasto: se guarda desde el botón flotante');
 ok(t.errs.length===0,'sin errores de JS');
 // robustez: sin conexión
 t=await mk(b);
 await t.page.route('**/rest/v1/rpc/**',r=>r.abort('failed'));
 await t.page.goto(URL);await t.page.waitForTimeout(700);
 ok(/conexi/i.test(await t.page.textContent('#msg')),'sin conexión: mensaje claro');
 ok(await t.page.evaluate(()=>!!localStorage.getItem('cuentas_auth_v1')),'sin conexión: no cierra la sesión');
 // robustez: 401 una vez -> renueva y reintenta
 t=await mk(b);let first=true,refreshed=0;
 await t.page.route('**/auth/v1/token**',r=>{refreshed++;r.fulfill({status:200,contentType:'application/json',body:JSON.stringify({access_token:'x.'+Buffer.from(JSON.stringify({sub:ME})).toString('base64')+'.y',refresh_token:'r2',expires_in:3600})})});
 await t.page.route('**/rest/v1/rpc/cuentas_my_groups_all',r=>{if(first){first=false;return r.fulfill({status:401,contentType:'application/json',body:JSON.stringify({message:'JWT expired'})})}return r.fallback()});
 await t.page.goto(URL);await t.page.waitForTimeout(800);
 ok(refreshed>=1&&await t.page.isVisible('[data-g]'),'401: renueva la sesión y reintenta');
 // robustez: sesión realmente vencida -> login
 t=await mk(b);
 await t.page.route('**/rest/v1/rpc/cuentas_my_groups_all',r=>r.fulfill({status:401,contentType:'application/json',body:JSON.stringify({message:'JWT expired'})}));
 await t.page.route('**/auth/v1/token**',r=>r.fulfill({status:400,contentType:'application/json',body:JSON.stringify({error_description:'Invalid Refresh Token'})}));
 await t.page.goto(URL);await t.page.waitForTimeout(800);
 ok((await views(t.page)).join()==='vLogin'&&/venci/i.test(await t.page.textContent('#msg')),'sesión vencida: vuelve al login con aviso');

 await b.close();console.log(fails?fails+' fallas':'todo ok');process.exit(fails?1:0)})();
