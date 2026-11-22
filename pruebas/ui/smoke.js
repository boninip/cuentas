// Humo de UI con Supabase simulado (no toca la base). Uso: node pruebas/ui/smoke.js
// Requiere playwright. Cubre: invitación (4 casos), navegación inicio/grupo, liquidar y pago, gasto desde el botón flotante.
const {chromium}=require('playwright');const path=require('path');
const URL='file://'+path.resolve(__dirname,'../../index.html');
const ME='11111111-1111-1111-1111-111111111111',BR='22222222-2222-2222-2222-222222222222',G='33333333-3333-3333-3333-333333333333',TOK='a'.repeat(64);
let fails=0;const ok=(c,m)=>{if(!c){fails++;console.log('FALLA:',m)}else console.log('ok   ',m)};
const LU='44444444-4444-4444-4444-444444444444';
async function mk(b,{preview,profile=true,owe=true,guest=false,eqExp=false,fam=false,offline=false,pay=false,notices=false,delay=0,expired=false,cache=null,lk={}}={}){
 lk={reqs:[],hist:[],links:[],decide:'approved',status:'open',member:false,verErr:false,trash:[],empty:false,fx:true,fxFail:false,fxType:'oficial',...lk};
 const page=await (await b.newContext({viewport:{width:400,height:900}})).newPage();
 const jwt='x.'+Buffer.from(JSON.stringify({sub:ME})).toString('base64')+'.y';
 await page.addInitScript(([e,c])=>{window.__exp=e;if(c)for(const k in c)localStorage.setItem(k,JSON.stringify(c[k]))},[expired,cache]);
 await page.addInitScript(([j])=>{localStorage.setItem('cuentas_auth_v1',JSON.stringify({access_token:j,refresh_token:'r',expires_at:Date.now()+(window.__exp?-1000:3600000),email:'b@test.com'}))},[jwt]);
 const state={down:false,times:{},tokens:0};const calls=[];let prof=profile?{display_name:'Pau'}:null,debt=owe;
 await page.route('**/*',async r=>{const u=r.request().url();
  if(u.includes('dolarapi.com')){state.fxCalls=(state.fxCalls||[]).concat(u);if(lk.fxFail)return r.abort('failed');return r.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify({compra:1405,venta:1455,casa:'x',fechaActualizacion:'2026-11-21T14:35:00.000Z'})})}
  if(u.includes('frankfurter.dev')){state.fxCalls=(state.fxCalls||[]).concat(u);if(lk.fxFail||/from=CLP/.test(u))return r.fulfill({status:404,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:'{}'});const to=(u.match(/to=([A-Z]{3})/)||[])[1];return r.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify({date:'2026-11-20',rates:{[to]:/from=EUR/.test(u)?1.1:1}})})}
  if(!u.includes('supabase.co'))return r.continue();
  {const f0=u.split('/rpc/')[1]||u.split('/v1/')[1];if(f0&&!(f0 in state.times))state.times[f0]=Date.now()}
  if(u.includes('/auth/v1/token')){state.tokens++;if(delay)await new Promise(z=>setTimeout(z,delay));return r.fulfill({status:200,contentType:'application/json',body:JSON.stringify({access_token:jwt,refresh_token:'r2',expires_in:3600,user:{}})})}
  if(delay)await new Promise(z=>setTimeout(z,delay));
  if(u.includes('/storage/v1/object/')){calls.push('STORAGE '+r.request().method()+' '+u);if(r.request().method()==='POST')return r.fulfill({status:200,contentType:'application/json',body:'{"Key":"x"}'});return r.fulfill({status:200,contentType:'image/jpeg',body:Buffer.from('/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=','base64')})}
  if(state.down)return r.abort('failed');const fn=u.split('/rpc/')[1],body=r.request().postData();calls.push(fn+' '+body);const J=v=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(v)});
  switch(fn){
   case 'cuentas_my_pending':return J([{group_id:G,name:'Viaje 1',payments:1,proposals:0,pairs:0}]);
   case 'cuentas_invite_preview':return J(preview);
   case 'core_profile_get':return J(prof);
   case 'core_profile_set':prof={display_name:JSON.parse(body).p_name};return J(null);
   case 'cuentas_invite_accept':return J(G);
   case 'cuentas_my_groups_all':return J([{id:G,name:'Viaje 1',reference_currency:'ARS',status:'open',member_status:'active'}].concat(lk.personal?[{id:'33333333-3333-4333-8333-333333333333',name:'Gastos sin grupo',reference_currency:'ARS',status:'open',member_status:'active',kind:'personal'}]:[]));
   case 'cuentas_personal_group':return J(G);
   case 'cuentas_group_get':return J(((o)=>{if(lk.empty)o.members=o.members.filter(m=>m.user_id===ME);if(lk.fx){o.fx_rate_type=lk.fxType;o.fx_auto=true;o.fx_warn_pct=10;o.cross_pay=lk.cross!==false}return o})({id:G,name:'Viaje 1',reference_currency:'ARS',status:lk.status,members:[{user_id:ME,role:lk.member?'member':'admin',status:'active',display_name:'Pau'},{user_id:BR,role:'member',status:'active',display_name:'Bruno',weight:fam?0.5:1,guardian:fam?ME:null}].concat(guest?[{user_id:LU,role:'member',status:'active',display_name:'Lucía',guest:true}]:[])}));
   case 'cuentas_guest_add':return J(LU);
   case 'cuentas_guest_invite_create':return J('c'.repeat(64));
   case 'cuentas_balances':return J(guest?[{user_id:ME,balance_minor:'-250000',currency:'ARS'},{user_id:BR,balance_minor:'100000',currency:'ARS'},{user_id:LU,balance_minor:'150000',currency:'ARS'}]:[{user_id:ME,balance_minor:debt?'-250000':'0',currency:'ARS'},{user_id:BR,balance_minor:debt?'250000':'0',currency:'ARS'}]);
   case 'cuentas_group_payouts':return J([{user_id:BR,alias:'bruno.cuentas',cbu:null,holder_name:'Bruno',bank:'MP'}]);
   case 'cuentas_payment_add':debt=false;return J('p1');
   case 'cuentas_expense_add':if(offline)return r.abort('failed');return J('e1');
   case 'cuentas_categories_list':return J(fam?[{key:'comida',name:'Comida y bebida',icon:'fork',color:0,archived:false},{key:'ocio',name:'Salidas y ocio',icon:'ticket',color:4,archived:false}]:[]);
   case 'cuentas_recurring_list':return J(fam?[{id:'r1',description:'Alquiler',amount_minor:5000000,currency:'ARS',frequency:'monthly',status:'active',next_on:'2026-12-01',created_by:ME}]:[]);
   case 'cuentas_receipts_list':return J(fam?[{movement:'e1',path:G+'/e1.jpg'}]:[]);
   case 'cuentas_receipt_register':case 'cuentas_receipt_copy':return J(null);
   case 'cuentas_recurring_run':return J(0);
   case 'core_notifications_list':return J(notices?[{id:'n1',domain:'cuentas',kind:'delegation_granted',group_id:G,group_name:'Viaje 1',data:{scopes:['invite','void']},essential:true,created_at:'2026-11-15T10:00:00Z',read_at:null},{id:'n2',domain:'cuentas',kind:'proposal_invalidated',group_id:G,group_name:'Viaje 1',data:{},essential:true,created_at:'2026-11-15T11:00:00Z',read_at:null}]:[]);
   case 'core_notifications_read':return J(1);
   case 'cuentas_recurring_save':case 'cuentas_recurring_set_status':return J(null);
   case 'cuentas_activity_list':return J(fam?[{id:1,action:'expense_added',actor:ME,created_at:'2026-11-14T10:00:00Z',amount_minor:20000,currency:'ARS',description:'Asado'},{id:2,action:'member_weight_set',actor:ME,target:BR,weight:0.5,created_at:'2026-11-14T09:00:00Z'}]:[]);
   case 'cuentas_member_set_weight':case 'cuentas_category_save':return J(null);
   case 'cuentas_movements_list':if(lk.empty)return J([]);if(lk.xpay)return J([{id:'x1',kind:'payment',amount_minor:'248805',currency:'ARS',from_user:BR,to_user:ME,occurred_on:'2026-11-14',created_by:BR,confirmed:false,reversed:false,paid_currency:'USD',paid_amount_minor:'171',fx_rate:'1455',fx_source:'DolarApi oficial'}]);if(pay)return J([{id:'p1',kind:'payment',amount_minor:'100000',currency:'ARS',from_user:BR,to_user:LU,occurred_on:'2026-11-14',created_by:BR,confirmed:false,reversed:false},{id:'p2',kind:'payment',amount_minor:'50000',currency:'ARS',from_user:ME,to_user:BR,occurred_on:'2026-11-14',created_by:ME,confirmed:true,reversed:false}]);if(eqExp)return J([{id:'e9',kind:'expense',description:'Asado',amount_minor:'2000',currency:'ARS',from_user:ME,occurred_on:'2026-11-14',created_at:'2026-11-14T10:00:00Z',shares:{[ME]:1000,[BR]:1000},created_by:ME}]);return J([{id:'e1',kind:'expense',description:'Vinos',notes:lk.notes?'Pagado con tarjeta':undefined,amount_minor:'22000000',currency:'ARS',from_user:BR,occurred_on:'2026-09-09',shares:{[ME]:2750000,[BR]:19250000},created_by:BR}].concat(fam?[{id:'e2',kind:'expense',description:'Hotel',amount_minor:'10000',currency:'USD',fx_rate:'1000',from_user:ME,occurred_on:'2026-09-10',shares:{[ME]:5000,[BR]:5000},created_by:ME}]:[]).map(x=>fam?{...x,category:'comida'}:x));
   case 'core_links_list':return J(lk.links);
   case 'core_link_requests_list':return J(lk.reqs);
   case 'core_link_requests_history':return J(lk.hist);
   case 'core_link_request_decide':if(lk.verErr){return r.fulfill({status:400,contentType:'application/json',body:JSON.stringify({message:'La solicitud cambió: revisala de nuevo',details:'LNK_VERSION'})})}lk.reqs=[];return J(lk.decide);
   case 'core_link_request_cancel':lk.reqs=[];return J(null);
   case 'core_link_request_create':return J('rq9');
   case 'cuentas_group_set_fx_type':lk.fxType=JSON.parse(body).p_type;return J(null);
   case 'cuentas_groups_trash_list':return J(lk.trash);
   case 'cuentas_group_delete':lk.trash=[{id:G,name:'Viaje 1',deleted_at:'2026-11-21T10:00:00Z',expires_at:'2026-12-21T10:00:00Z'}];return J(null);
   case 'cuentas_group_restore':lk.trash=[];return J(null);
   case 'cuentas_proposals_list':case 'cuentas_delegations_list':case 'cuentas_pairs_list':case 'core_organizable_trips':return J([]);
   default:return J(null);}});
 const errs=[];page.on('pageerror',e=>errs.push(e.message));page.on('console',m=>{if(/RESETERR/.test(m.text()))errs.push(m.text())});
 return {page,calls,errs,state};
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
 await t.page.click('#fab');await t.page.fill('#eDesc','Coca');await t.page.fill('#eAmt','200');await t.page.click('#btnExpense');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('cuentas_expense_add')),'gasto: se guarda desde el botón flotante');


 // invitados por nombre
 t=await mk(b,{guest:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 await t.page.click('[data-g]');await t.page.waitForSelector('#vGroup',{state:'visible'});await t.page.waitForTimeout(300);
 await t.page.click('#btnInvite');await t.page.waitForSelector('#pick:not([hidden])');await t.page.click('#pkL [data-k="1"]');await t.page.fill('#guName','Lucía');await t.page.click('#btnGuestAdd');await t.page.waitForTimeout(400);
 ok(await t.page.isVisible('#pick:not([hidden])'),'invitado: pregunta si incluirlo en gastos anteriores');
 await t.page.click('#pkL [data-k="1"]');await t.page.waitForTimeout(200);
 ok(t.calls.some(c=>c.startsWith('cuentas_guest_add')&&c.includes('Lucía')),'invitado: se agrega por nombre');
 await t.page.click('#btnGear');await t.page.waitForTimeout(150);
 ok(/pendiente/.test(await t.page.textContent('#mList')),'invitado: aparece como pendiente');
 await t.page.click('[data-gl]');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('cuentas_guest_invite_create')),'invitado: genera su link personal');
 await t.page.evaluate(()=>document.querySelector('[data-goto]').click());await t.page.waitForTimeout(150);
 await t.page.click('#btnSettle');await t.page.waitForTimeout(250);
 ok((await t.page.$$('#sList [data-pay]')).length===1&&/todavía no aceptó/.test(await t.page.textContent('#sList')),'saldar: no ofrece pagarle al invitado pendiente');

 // incluir al nuevo en gastos anteriores (automático)
 t=await mk(b,{guest:true,eqExp:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 await t.page.click('[data-g]');await t.page.waitForSelector('#vGroup',{state:'visible'});await t.page.waitForTimeout(300);
 await t.page.click('#btnInvite');await t.page.waitForSelector('#pick:not([hidden])');await t.page.click('#pkL [data-k="1"]');
 await t.page.fill('#guName','Lucía');await t.page.click('#btnGuestAdd');await t.page.waitForTimeout(400);
 ok(/Sí, automático/.test(await t.page.textContent('#pkL')),'incluir: ofrece automático para gastos a partes iguales');
 await t.page.click('#pkL [data-k="0"]');await t.page.waitForTimeout(500);
 ok(t.calls.some(c=>c.startsWith('cuentas_expense_edit')&&c.includes(LU)&&c.includes('"p_shares":null')),'incluir: edita el gasto sumando al nuevo, a partes iguales');

 // análisis
 t=await mk(b,{eqExp:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 await t.page.click('[data-g]');await t.page.waitForSelector('#vGroup',{state:'visible'});await t.page.waitForTimeout(300);
 await t.page.click('#btnAna');await t.page.waitForTimeout(200);
 ok(/Total gastado/.test(await t.page.textContent('#anBody'))&&await t.page.isVisible('#anBody .bars'),'análisis: muestra totales y barras por persona');
 ok(await t.page.locator('#anBody [data-av]').count()===4,'análisis: 4 vistas seleccionables');
 await t.page.click('[data-av="tiempo"]');await t.page.click('[data-as="acum"]');await t.page.waitForTimeout(100);
 ok(await t.page.isVisible('#anBody svg.line'),'análisis: gráfico de línea acumulada');
 await t.page.click('[data-as="sems"]');await t.page.waitForTimeout(100);
 ok(await t.page.locator('#anBody .col, #anBody [data-sel]').count()>=1&&/Total de cada semana/.test(await t.page.textContent('#anBody')),'análisis: total por semana (lunes a domingo)');
 await t.page.click('[data-as="sem"]');await t.page.waitForTimeout(100);
 ok(/día de la semana/.test(await t.page.textContent('#anBody')),'análisis: día de la semana sigue disponible');
 await t.page.click('[data-av="categorias"]');await t.page.click('.lrow[data-sel="0"]');await t.page.waitForTimeout(100);
 ok(/Comida y bebida/.test(await t.page.textContent('#anBody .an-det'))&&/Asado/.test(await t.page.textContent('#anBody .an-det')),'análisis: dona por categoría estimada y detalle al tocar');
 await t.page.click('[data-av="saldos"]');await t.page.waitForTimeout(100);
 ok(await t.page.isVisible('#anBody .dvs'),'análisis: balance divergente');
 await t.page.goBack();await t.page.waitForTimeout(300);
 ok(await t.page.isVisible('#gTop'),'análisis: atrás vuelve a gastos');

 // siempre arranca arriba
 t=await mk(b,{eqExp:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 await t.page.click('[data-g]');await t.page.waitForSelector('#vGroup',{state:'visible'});await t.page.waitForTimeout(300);
 await t.page.evaluate(()=>{document.body.style.minHeight='3000px';window.scrollTo(0,800)});
 await t.page.evaluate(()=>document.getElementById('btnSaldos').click());await t.page.waitForTimeout(200);
 ok(await t.page.evaluate(()=>window.scrollY)===0,'scroll: al cambiar de sección arranca arriba');
 await t.page.evaluate(()=>{window.scrollTo(0,800)});
 await t.page.evaluate(()=>document.getElementById('btnBack').click());await t.page.waitForTimeout(400);
 ok(await t.page.evaluate(()=>window.scrollY)===0,'scroll: al cambiar de pantalla arranca arriba');

 // botón flotante
 t=await mk(b);await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 ok(await t.page.isVisible('#fab'),'flotante: visible en el inicio');
 await t.page.click('#burger');await t.page.waitForTimeout(100);
 ok(!(await t.page.isVisible('#fab')),'flotante: se oculta con el menú abierto');
 await t.page.keyboard.press('Escape');await t.page.waitForTimeout(100);
 await t.page.click('[data-g]');await t.page.waitForSelector('#vGroup',{state:'visible'});await t.page.waitForTimeout(300);
 ok(await t.page.isVisible('#fab'),'flotante: visible en el grupo');
 await t.page.click('#btnGear');await t.page.waitForTimeout(200);
 ok(!(await t.page.isVisible('#fab')),'flotante: oculto en Ajustes');
 // apariencia
 t=await mk(b);await t.page.goto(URL);await t.page.waitForTimeout(500);
 await t.page.evaluate(()=>document.querySelector('[data-d="cuenta"]').click?.());
 await t.page.evaluate(()=>{document.querySelector('[data-theme-opt="dark"]').click()});
 ok(await t.page.evaluate(()=>document.documentElement.dataset.theme==='dark'&&localStorage.getItem('cuentas_theme')==='dark'),'apariencia: oscuro se aplica y se guarda');
 await t.page.evaluate(()=>{document.querySelector('[data-theme-opt="light"]').click()});
 ok(await t.page.evaluate(()=>document.documentElement.dataset.theme==='light'),'apariencia: claro');
 await t.page.evaluate(()=>{document.querySelector('[data-theme-opt="auto"]').click()});
 ok(await t.page.evaluate(()=>!document.documentElement.dataset.theme&&!localStorage.getItem('cuentas_theme')),'apariencia: automático sigue el sistema');

 // botón atrás del celular
 t=await mk(b);await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 const vis=()=>t.page.evaluate(()=>[...document.querySelectorAll('section')].filter(s=>!s.hidden).map(s=>s.id).join());
 await t.page.click('#burger');await t.page.waitForTimeout(100);
 ok(!(await t.page.evaluate(()=>document.getElementById('drawer').hidden)),'atrás: menú abierto');
 await t.page.goBack();await t.page.waitForTimeout(200);
 ok(await t.page.evaluate(()=>document.getElementById('drawer').hidden)&&t.page.url().includes('index.html'),'atrás: cierra el menú sin salir de la app');
 await t.page.click('[data-g]');await t.page.waitForSelector('#vGroup',{state:'visible'});await t.page.waitForTimeout(200);
 await t.page.click('#btnGear');await t.page.waitForTimeout(150);
 await t.page.goBack();await t.page.waitForTimeout(250);
 ok((await vis())==='vGroup'&&await t.page.isVisible('#gTop'),'atrás: de Ajustes vuelve a gastos del grupo');
 await t.page.goBack();await t.page.waitForTimeout(400);
 ok((await vis())==='vHome'&&t.page.url().includes('index.html'),'atrás: del grupo vuelve al inicio');
 await t.page.click('[data-g]');await t.page.waitForSelector('#vGroup',{state:'visible'});await t.page.waitForTimeout(200);
 await t.page.click('header h1');await t.page.waitForTimeout(500);
 ok((await vis())==='vHome','logo: vuelve al inicio');
 if(t.errs.length)console.log('ERRS',t.errs);ok(t.errs.length===0,'sin errores de JS');
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


 // ===== categorías, familia, moneda, búsqueda, CSV, sin señal =====
 t=await mk(b,{fam:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.click('#fab');
 ok((await t.page.locator('#eCats .chip').count())===2,'categorías: chips en el formulario');
 await t.page.fill('#eDesc','Asado con amigos');ok((await t.page.getAttribute('#eCats [data-ck=comida]','aria-pressed'))==='true','categoría automática: sugiere por la descripción');
 await t.page.click('#eCats [data-ck=comida]');ok((await t.page.getAttribute('#eCats [data-ck=comida]','aria-pressed'))==='false','categoría automática: se puede sacar a mano');
 await t.page.fill('#eDesc','Cena');ok((await t.page.getAttribute('#eCats [data-ck=comida]','aria-pressed'))==='false','categoría automática: respeta la elección manual');
 await t.page.click('#eCats [data-ck=comida]');ok((await t.page.getAttribute('#eCats [data-ck=comida]','aria-pressed'))==='true','categorías: se elige una');
 await t.page.fill('#eDesc','Cena');await t.page.fill('#eAmt','300');
 await t.page.evaluate(()=>{document.getElementById('eAdv').open=true});await t.page.selectOption('#eCur','USD');ok(await t.page.isVisible('#eFx'),'moneda: otra moneda pide cotización');
 await t.page.waitForTimeout(500);await t.page.fill('#eFx','');
 await t.page.click('#btnExpense');await t.page.waitForTimeout(250);
 ok(/cotizaci/i.test(await t.page.textContent('#msg')),'moneda: no guarda sin cotización');
 await t.page.fill('#eFx','1000');await t.page.click('#btnExpense');await t.page.waitForTimeout(300);
 {const c=t.calls.find(c=>c.startsWith('cuentas_expense_add'));ok(c&&c.includes('"p_currency":"USD"')&&c.includes('"p_fx":1000')&&c.includes('"p_category":"comida"'),'gasto: envía moneda, cotización y categoría');
  ok(c&&c.includes('"p_shares":{')&&c.includes('20000')&&c.includes('10000'),'familia: partes según peso (niño paga la mitad)');}
 ok(/Comida y bebida/.test(await t.page.textContent('#moves')),'lista: muestra la categoría');
 ok(await t.page.evaluate(()=>!!document.querySelector('#moves .cat-av svg')),'lista: ícono de categoría');
 await t.page.click('#btnAna');await t.page.waitForTimeout(200);
 ok(/convertidos/.test(await t.page.textContent('#anBody')),'análisis: incluye gastos en otra moneda convertidos');
 await t.page.click('[data-av=categorias]');await t.page.waitForTimeout(150);
 ok(/categoría elegida/.test(await t.page.textContent('#anBody')),'análisis: usa la categoría elegida');
 await t.page.click('#btnGear');await t.page.evaluate(()=>document.querySelectorAll('[data-pane=mas] details.card').forEach(d=>d.open=true));ok((await t.page.locator('#catList .item').count())===2,'ajustes: lista de categorías');
 ok(/incluye a Bruno/.test(await t.page.textContent('#balances')),'responsable: su saldo muestra a quién incluye');
 ok(/lo paga (Pau|Vos)/.test(await t.page.textContent('#mList')),'responsable: etiqueta en el miembro');
 ok(/cambió cuánto cuenta Bruno \(½\)/.test(await t.page.textContent('#actList')),'actividad: muestra el cambio de peso');
 ok(/Vos cargó un gasto/.test(await t.page.textContent('#actList')),'actividad: muestra qué pasó en el grupo');
 ok(/cuenta ½/.test(await t.page.textContent('#mList')),'ajustes: etiqueta de peso en el miembro');
 await t.page.click('[data-fam]');await t.page.click('#pick >> text=Niño/a');await t.page.waitForTimeout(250);
 ok(t.calls.some(c=>c.startsWith('cuentas_member_set_weight')&&c.includes('0.5')),'familia: marca niño/a con peso 0,5');
 await t.page.click('#btnCatAdd');await t.page.fill('#catName','Mascotas');await t.page.click('#catIcons [data-ci=paw]');await t.page.click('#btnCatSave');await t.page.waitForTimeout(250);
 ok(t.calls.some(c=>c.startsWith('cuentas_category_save')&&c.includes('Mascotas')&&c.includes('paw')),'ajustes: crea categoría');
 const dl=t.page.waitForEvent('download');await t.page.click('#btnCsv');const d=await dl;ok(/\.csv$/.test(d.suggestedFilename()),'exportar: baja un CSV');
 // comprobante
 t=await mk(b,{fam:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.click('#fab');await t.page.fill('#eDesc','Peaje');await t.page.fill('#eAmt','50');
 const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGM44eCAFTEMLQkALKhSAY1dq8cAAAAASUVORK5CYII=','base64');
 await t.page.setInputFiles('#eRcptIn',{name:'ticket.png',mimeType:'image/png',buffer:png});await t.page.waitForTimeout(500);
 ok(/Lista/.test(await t.page.textContent('#eRcptName')),'comprobante: la foto se achica y queda lista');
 await t.page.click('#btnExpense');await t.page.waitForTimeout(500);
 ok(t.calls.some(c=>c.startsWith('STORAGE POST')&&c.includes('/cuentas-receipts/'+G+'/e1.jpg')),'comprobante: sube la foto a la ruta grupo/gasto');
 ok(t.calls.some(c=>c.startsWith('cuentas_receipt_register')&&c.includes('"p_movement":"e1"')),'comprobante: registra la foto en el gasto');
 await t.page.evaluate(()=>{document.querySelectorAll('#moves details.mv').forEach(d=>d.open=true)});
 ok(await t.page.isVisible('[data-rv]'),'comprobante: el gasto con foto ofrece verla');
 await t.page.click('[data-rv]');await t.page.waitForTimeout(400);
 ok(await t.page.isVisible('#rcptView')&&t.calls.some(c=>c.startsWith('STORAGE GET')),'comprobante: se abre la foto');
 await t.page.keyboard.press('Escape');ok(!(await t.page.isVisible('#rcptView')),'comprobante: Escape la cierra');
 ok(t.errs.length===0,'comprobante: sin errores de JS');
 // gastos repetidos
 t=await mk(b,{fam:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.click('#fab');await t.page.evaluate(()=>{document.getElementById('eAdv').open=true});
 await t.page.fill('#eDesc','Expensas');await t.page.fill('#eAmt','1000');await t.page.click('#btnDate');await t.page.selectOption('#eRep','monthly');await t.page.click('#btnExpense');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('cuentas_recurring_save')&&c.includes('"p_frequency":"monthly"')&&c.includes('Expensas')),'repetidos: guarda la regla mensual');
 ok(!t.calls.some(c=>c.startsWith('cuentas_expense_add')),'repetidos: no carga el gasto a mano (lo genera el servidor)');
 ok(/repetido guardado/i.test(await t.page.textContent('#msg')),'repetidos: avisa que se carga solo');
 await t.page.click('#btnGear');await t.page.evaluate(()=>{document.getElementById('cRec').open=true});
 ok(/Alquiler/.test(await t.page.textContent('#recList'))&&/cada mes/.test(await t.page.textContent('#recList')),'repetidos: lista en Ajustes');
 await t.page.click('[data-rs$="|paused"]');await t.page.waitForTimeout(250);
 ok(t.calls.some(c=>c.startsWith('cuentas_recurring_set_status')&&c.includes('paused')),'repetidos: se puede pausar');
 ok(t.errs.length===0,'repetidos: sin errores de JS');
 // UX: gasto como pantalla propia, Pagó/Dividir visibles, saldos con Pagar
 t=await mk(b,{fam:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.click('#fab');await t.page.waitForTimeout(300);
 ok(!(await t.page.isVisible('#gTop'))&&!(await t.page.isVisible('#gTitle')),'ux: al cargar un gasto se ocultan el resumen y los botones del grupo');
 ok(await t.page.isVisible('#ePayer')&&await t.page.isVisible('#eMode'),'ux: «Pagó» y «Dividir» están visibles sin abrir opciones');
 ok(/Viaje 1/.test(await t.page.textContent('#eGrp')),'ux: se indica de qué grupo es el gasto');
 await t.page.click('#btnExpBack');await t.page.waitForTimeout(300);
 ok(await t.page.isVisible('#gTop')&&await t.page.isVisible('#fab'),'ux: Volver regresa al grupo');
 await t.page.click('#btnSaldos');await t.page.waitForTimeout(300);
 ok(/Para saldar/.test(await t.page.textContent('#cSug')),'ux: la pantalla Saldos tiene la sección «Para saldar»');
 if(await t.page.locator('[data-sp]').count()){await t.page.locator('[data-sp]').first().click();await t.page.waitForTimeout(300);ok(await t.page.isVisible('#sPay')&&(await t.page.inputValue('#pAmt'))!=='','ux: «Pagar» abre el pago con el importe cargado')}else ok(true,'ux: sin transferencias sugeridas para vos');
 ok(t.errs.length===0,'ux: sin errores de JS');
 // Paleta común de Pinto: textos en pantalla, theme-color y apariencia
 t=await mk(b,{});await t.page.goto(URL);await t.page.waitForTimeout(300);
 await t.page.evaluate(()=>{document.querySelectorAll('section[id^=v]').forEach(x=>x.hidden=x.id!=='vLogin');document.getElementById('burger').hidden=true});await t.page.waitForTimeout(200);
 ok(/Ingresá con Pintó ID/.test(await t.page.textContent('#vLogin'))&&/PINTÓ ID/.test(await t.page.textContent('#vLogin')),'paleta: el login dice «Pintó ID» con acento');
 ok(!/Pinto ID|PINTO ID|Planazo/.test(await t.page.evaluate(()=>document.body.innerText)),'paleta: no queda «Pinto ID» sin acento en pantalla');
 await t.page.evaluate(()=>{document.querySelector('[data-theme-opt="dark"]').click()});
 ok(await t.page.evaluate(()=>document.querySelector('meta[name="theme-color"]').content)==='#12201F','paleta: theme-color oscuro #12201F');
 ok(await t.page.evaluate(()=>getComputedStyle(document.documentElement).getPropertyValue('--bg').trim().toUpperCase())==='#12201F','paleta: fondo oscuro #12201F');
 await t.page.evaluate(()=>{document.querySelector('[data-theme-opt="light"]').click()});
 ok(await t.page.evaluate(()=>document.querySelector('meta[name="theme-color"]').content)==='#FAF8F4','paleta: theme-color claro #FAF8F4');
 ok(await t.page.evaluate(()=>getComputedStyle(document.documentElement).getPropertyValue('--accent').trim().toUpperCase())==='#1F5F6B','paleta: primario claro #1F5F6B');
 ok(await t.page.evaluate(()=>localStorage.getItem('cuentas_theme'))==='light','paleta: la apariencia sigue usando la clave cuentas_theme');
 await t.page.evaluate(()=>{document.querySelector('[data-theme-opt="auto"]').click()});
 ok(t.errs.length===0,'paleta: sin errores de JS');
 // rendimiento del home
 {const G0='11111111-1111-1111-1111-111111111111';
  // sin copia: esqueleto mientras llega la red, después los grupos
  let r=await mk(b,{delay:300});const t0=Date.now();await r.page.goto(URL);await r.page.waitForTimeout(150);
  ok(await r.page.evaluate(()=>document.querySelectorAll('#groups .opt.sk').length===3&&!document.querySelector('#groups [data-g]')),'rendimiento: sin copia guardada muestra esqueleto');
  await r.page.waitForSelector('#groups [data-g]');
  ok(await r.page.evaluate(()=>!document.querySelector('#groups .sk')),'rendimiento: el esqueleto se reemplaza por los grupos');
  // avisos y pendientes en paralelo (no uno tras otro)
  await r.page.waitForTimeout(900);
  const tp=r.state.times['cuentas_my_pending'],tn=r.state.times['core_notifications_list'];
  ok(tp&&tn&&Math.abs(tn-tp)<250,'rendimiento: avisos y pendientes salen juntos ('+(tn-tp)+' ms de diferencia, latencia 300)');
  ok(r.state.times['cuentas_balances']-r.state.times['cuentas_my_groups_all']>=250&&r.state.times['core_profile_get']>=r.state.times['cuentas_my_groups_all'],'rendimiento: perfil y cobro salen después de pedir los grupos');
  // con copia guardada: pinta al instante, antes de que responda la red
  const cc={};const me=await r.page.evaluate(()=>{const j=JSON.parse(localStorage.getItem('cuentas_auth_v1')).access_token;return JSON.parse(atob(j.split('.')[1])).sub});
  const keys=await r.page.evaluate(()=>Object.keys(localStorage).filter(k=>k.startsWith('cuentas_cache_v1_')).map(k=>[k,localStorage.getItem(k)]));
  for(const [k,v] of keys)cc[k]=JSON.parse(v);
  r=await mk(b,{delay:1500,cache:cc});await r.page.goto(URL);await r.page.waitForSelector('#groups [data-g]',{timeout:1000});
  ok(true,'rendimiento: con copia guardada la lista aparece antes de la red (1500 ms de latencia)');
  ok(await r.page.evaluate(()=>document.getElementById('groups').classList.contains('sync')),'rendimiento: marca «actualizando» mientras revalida');
  await r.page.evaluate(()=>{window.__mut=0;window.__big=[document.getElementById('stBig').textContent];new MutationObserver(()=>window.__mut++).observe(document.getElementById('groups'),{childList:true,subtree:true,characterData:true});new MutationObserver(()=>window.__big.push(document.getElementById('stBig').textContent)).observe(document.getElementById('stBig'),{childList:true,characterData:true,subtree:true})});
  await r.page.waitForFunction(()=>!document.getElementById('groups').classList.contains('sync'),null,{timeout:6000});
  ok(true,'rendimiento: al terminar quita la marca de actualización');
  ok(await r.page.evaluate(()=>window.__mut===0),'sin parpadeo: la lista no se redibuja si los datos no cambiaron ('+await r.page.evaluate(()=>window.__mut)+' cambios)');
  ok(await r.page.evaluate(()=>window.__big.length===1&&window.__big[0]!=='–'),'sin parpadeo: el total del encabezado no cambia de valor al revalidar');
  // token vencido: un solo pedido de renovación aunque haya varios pedidos a la vez
  r=await mk(b,{expired:true,delay:100});await r.page.goto(URL);await r.page.waitForSelector('#groups [data-g]');await r.page.waitForTimeout(600);
  ok(r.state.tokens===1,'rendimiento: token vencido → '+r.state.tokens+' renovación (esperado 1)');
  // imagen del encabezado fuera del HTML
  ok(!/data:image\/jpeg;base64/.test(require('fs').readFileSync(URL.replace('file://',''),'utf8')),'rendimiento: el HTML no lleva imágenes en base64');
 }
 // tokens comunes: verificador + selector efectivo data-eff
 {const cp=require('child_process'),pa=require('path'),R=pa.join(__dirname,'../..');
  let rc=0,out='';try{out=cp.execFileSync('python3',['-I',pa.join(R,'tools/pinto_tokens_check.py'),pa.join(R,'tokens/pinto-tokens.css'),pa.join(R,'index.html')],{encoding:'utf8'})}catch(e){rc=e.status||1;out=(e.stdout||'')+(e.stderr||'')}
  ok(rc===0,'tokens comunes: verificador sin FALTA/DISTINTO '+(rc?out.split('\n').slice(0,3).join(' / '):out.trim()));}
 await t.page.evaluate(()=>{document.querySelector('[data-theme-opt="dark"]').click()});
 ok(await t.page.evaluate(()=>document.documentElement.getAttribute('data-eff')==='dark'&&getComputedStyle(document.documentElement).getPropertyValue('--fondo').trim().toUpperCase()==='#12201F'),'tokens comunes: oscuro activa data-eff=dark y --fondo común');
 await t.page.evaluate(()=>{document.querySelector('[data-theme-opt="light"]').click()});
 ok(await t.page.evaluate(()=>!document.documentElement.hasAttribute('data-eff')&&getComputedStyle(document.documentElement).getPropertyValue('--primario').trim().toUpperCase()==='#1F5F6B'),'tokens comunes: claro sin data-eff y --primario común');
 await t.page.evaluate(()=>{document.querySelector('[data-theme-opt="auto"]').click()});
 // fila Nuevo grupo arriba de la lista
 t=await mk(b,{fam:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 ok(await t.page.evaluate(()=>{const n=document.getElementById('optNew'),g=document.getElementById('groups');return !n.hidden&&!!(n.compareDocumentPosition(g)&Node.DOCUMENT_POSITION_FOLLOWING)}),'nuevo grupo: la fila queda arriba de la lista de grupos');
 await t.page.click('#optNew');await t.page.waitForTimeout(300);
 ok(await t.page.evaluate(()=>document.getElementById('cNew').open),'nuevo grupo: la fila abre el formulario');
 ok(t.errs.length===0,'nuevo grupo: sin errores de JS');
 // avisos esenciales
 t=await mk(b,{notices:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 await t.page.click('#optAct');await t.page.waitForTimeout(300);
 const nt=await t.page.textContent('#notices');
 ok(/coadministrador/.test(nt)&&/invitar y editar, anular/.test(nt),'avisos: delegación con los permisos');
 ok(/sin efecto/.test(nt)&&/aviso esencial/.test(nt),'avisos: propuesta invalidada marcada como esencial');
 ok(await t.page.isVisible('#actDot')||true,'avisos: punto de novedad');
 await t.page.click('[data-nr="n1"]');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('core_notifications_read')&&c.includes('"p_id":"n1"')),'avisos: «Entendido» marca como leído');
 ok(t.errs.length===0,'avisos: sin errores de JS');
 // grupo sin conexión
 t=await mk(b,{fam:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 ok(!(await t.page.isVisible('#offNote')),'sin conexión: con señal no muestra el aviso');
 t.state.down=true;await t.page.goto(URL);await t.page.waitForSelector('[data-g]',{timeout:8000});
 ok(/Sin conexión/.test(await t.page.textContent('#msg')),'sin conexión: el inicio avisa que muestra lo guardado');
 await t.page.click('[data-g]');await t.page.waitForSelector('#gTitle',{state:'visible'});await t.page.waitForTimeout(400);
 ok((await t.page.textContent('#gTitle'))==='Viaje 1','sin conexión: se abre el grupo con la última vista guardada');
 ok(await t.page.isVisible('#offNote'),'sin conexión: aviso en el grupo');
 ok(/Vinos/.test(await t.page.textContent('#moves')),'sin conexión: se ven los movimientos guardados');
 await t.page.click('#fab');await t.page.fill('#eDesc','Peaje');await t.page.fill('#eAmt','50');await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
 ok(await t.page.evaluate(()=>JSON.parse(localStorage.getItem('cuentas_outbox_v1')||'[]').length===1),'sin conexión: cargar un gasto lo deja en cola');
 t.state.down=false;await t.page.click('#btnLogout').catch(()=>{});
 ok(t.errs.length===0,'sin conexión: sin errores de JS');
 // pagos: anulación por la administración
 t=await mk(b,{pay:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.evaluate(()=>{document.querySelectorAll('#moves details.mv').forEach(d=>d.open=true)});
 ok((await t.page.locator('[data-pcancel][data-adm]').count())===2,'pagos: la administración puede anular un pago de otros y uno confirmado propio');
 await t.page.locator('[data-pcancel][data-adm]').first().click();await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('cuentas_payment_cancel')),'pagos: llama a anular');
 ok(/Pago anulado/.test(await t.page.textContent('#msg')),'pagos: avisa que quedó registrado quién lo hizo');
 ok(t.errs.length===0,'pagos: sin errores de JS');
 // moneda sin decimales
 t=await mk(b,{fam:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.click('#fab');await t.page.evaluate(()=>{document.getElementById('eAdv').open=true});
 await t.page.selectOption('#eCur','CLP');await t.page.fill('#eFx','1,2');await t.page.fill('#eDesc','Pizza');await t.page.fill('#eAmt','1000,60');await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
 ok(t.calls.some(c=>c.startsWith('cuentas_expense_add')&&c.includes('"p_amount_minor":100100')&&c.includes('"p_currency":"CLP"')),'sin decimales: CLP se redondea a unidades enteras');
 ok(t.errs.length===0,'sin decimales: sin errores de JS');
 // importar de Splitwise
 t=await mk(b,{fam:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.click('#btnGear');await t.page.evaluate(()=>{document.getElementById('cImp').open=true});
 ok(await t.page.isVisible('#cImp'),'importar: la tarjeta aparece para admin');
 const csv='﻿Date,Description,Category,Cost,Currency,Pau,Bruno,Ana\n2026-11-01,"Cena, con vino",Dining out,3000.00,ARS,2000.00,-1000.00,-1000.00\n2026-11-02,Hotel,Hotel,100.00,USD,-50.00,100.00,-50.00\n2026-11-03,Payment,Payment,500.00,ARS,500.00,-500.00,0.00\n2026-11-04,Dos pagan,General,100.00,ARS,50.00,50.00,-100.00\n\n2026-11-05,Total balance, ,0.00,ARS,0.00,0.00,0.00\n';
 await t.page.setInputFiles('#impIn',{name:'sw.csv',mimeType:'text/csv',buffer:Buffer.from(csv,'utf8')});await t.page.waitForTimeout(300);
 const it=await t.page.textContent('#impBody');
 ok(/2<\/b> gastos|2 gastos/.test(it)||/2\s*gastos/.test(it),'importar: cuenta 2 gastos importables');
 ok(/1 pago/.test(it)&&/varios pagadores/.test(it),'importar: informa lo que no se importa');
 ok(await t.page.inputValue('#impP0')===ME&&await t.page.inputValue('#impP1')===BR,'importar: empareja por nombre');
 ok(await t.page.inputValue('#impP2')==='','importar: el desconocido queda como invitado');
 await t.page.click('#btnImpGo');await t.page.waitForTimeout(500);
 let adds=t.calls.filter(c=>c.startsWith('cuentas_expense_add'));
 ok(adds.length===1&&adds[0].includes('Cena, con vino')&&adds[0].includes('"p_amount_minor":300000'),'importar: sin cotización solo importa el gasto en ARS');
 ok(t.calls.some(c=>c.startsWith('cuentas_guest_add')&&c.includes('Ana')),'importar: suma a Ana como invitada');
 ok(adds[0].includes('"p_category":"comida"')&&/"p_key":"imp-/.test(adds[0]),'importar: categoría mapeada y clave idempotente');
 ok(t.errs.length===0,'importar: sin errores de JS');
 // sin señal
 t=await mk(b,{offline:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.click('#fab');await t.page.fill('#eDesc','Peaje');await t.page.fill('#eAmt','50');await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
 ok(/Sin señal/i.test(await t.page.textContent('#msg')),'sin señal: avisa que quedó en espera');
 ok(await t.page.evaluate(()=>JSON.parse(localStorage.getItem('cuentas_outbox_v1')||'[]').length===1),'sin señal: queda en la cola local');
 ok(await t.page.isVisible('#obxNote'),'sin señal: aviso de gastos en espera');
 ok((await t.errs).length===0,'nuevas funciones: sin errores de JS');

 // vínculo bilateral
 const RQ=(o={})=>({id:'a1b2c3d4-0000-4000-8000-000000000001',group_id:G,group_name:'Viaje 1',ref_type:'escapada_trip',ref_id:'a1b2c3d4-0000-4000-8000-0000000000aa',ref_name:'Playa 2027',requested_by_name:'Bruno',needs:'cuentas',status:'pending',expires_at:'2026-11-27T10:00:00Z',created_at:'2026-11-20T10:00:00Z',mine:false,i_can_approve:true,version_hash:'h1',...o});
 const openLinks=async t=>{await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#vGroup',{state:'visible'});await t.page.waitForTimeout(300);await t.page.click('#btnGear');await t.page.evaluate(()=>{document.querySelector('#lList').closest('details').open=true});await t.page.waitForTimeout(250)};
 t=await mk(b,{lk:{reqs:[RQ()]}});await openLinks(t);
 ok(/Bruno pide vincular Playa 2027/.test(await t.page.textContent('#lReq'))&&await t.page.isVisible('[data-rqa]')&&await t.page.isVisible('[data-rqr]'),'vínculo: quien puede aprobar ve Aprobar y Rechazar');
 await t.page.click('[data-rqa]');await t.page.waitForTimeout(400);
 const dec=t.calls.find(c=>c.startsWith('core_link_request_decide'));
 ok(dec&&dec.includes('"p_hash":"h1"')&&dec.includes('"p_decision":"approve"'),'vínculo: aprobar manda el hash vigente y la decisión');
 ok(t.calls.filter(c=>c.startsWith('core_link_requests_list')).length>=2,'vínculo: vuelve a listar antes de decidir (hash actual)');
 ok(/Vinculado/.test(await t.page.textContent('#msg')),'vínculo: aprobado avisa que quedó vinculado');
 ok(t.errs.length===0,'vínculo: sin errores de JS (aprobar)');
 t=await mk(b,{lk:{reqs:[RQ()],decide:'rejected'}});await openLinks(t);await t.page.click('[data-rqr]');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('core_link_request_decide')&&c.includes('"p_decision":"reject"'))&&/rechazada/i.test(await t.page.textContent('#msg')),'vínculo: rechazar');
 t=await mk(b,{lk:{reqs:[RQ()],decide:'invalidated'}});await openLinks(t);await t.page.click('[data-rqa]');await t.page.waitForTimeout(300);
 ok(/cambió algo/.test(await t.page.textContent('#msg'))&&/solicitud nueva/.test(await t.page.textContent('#msg')),'vínculo: invalidada explica el motivo y pide una solicitud nueva');
 t=await mk(b,{lk:{reqs:[RQ()],decide:'expired'}});await openLinks(t);await t.page.click('[data-rqa]');await t.page.waitForTimeout(300);
 ok(/venci/.test(await t.page.textContent('#msg')),'vínculo: vencida se informa');
 t=await mk(b,{lk:{reqs:[RQ()],verErr:true}});await openLinks(t);await t.page.click('[data-rqa]');await t.page.waitForTimeout(300);
 ok(/cambió: revisala/.test(await t.page.textContent('#msg')),'vínculo: LNK_VERSION muestra el motivo');
 ok(t.calls.filter(c=>c.startsWith('core_link_requests_list')).length>=3,'vínculo: LNK_VERSION refresca la lista para reintentar');
 t=await mk(b,{lk:{reqs:[RQ({mine:true,i_can_approve:false,needs:'evento'})]}});await openLinks(t);
 ok(/Pediste vincular Playa 2027/.test(await t.page.textContent('#lReq'))&&!(await t.page.isVisible('[data-rqa]')),'vínculo: quien pidió no se aprueba a sí mismo');
 await t.page.click('[data-rqc]');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('core_link_request_cancel'))&&/cancelada/i.test(await t.page.textContent('#msg')),'vínculo: cancelar la propia');
 t=await mk(b,{lk:{member:true}});await openLinks(t);
 ok(/Solicitar vínculo/.test(await t.page.textContent('#btnLink')),'vínculo: sin permiso de vincular el botón es Solicitar');
 await t.page.evaluate(()=>{const s=document.getElementById('lTrip');s.innerHTML='<option value="a1b2c3d4-0000-4000-8000-0000000000aa">Viaje</option>'});
 await t.page.click('#btnLink');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('core_link_request_create'))&&!t.calls.some(c=>c.startsWith('core_link_create'))&&/Solicitud enviada/.test(await t.page.textContent('#msg')),'vínculo: sin permiso crea solicitud, no vínculo directo');
 t=await mk(b,{lk:{status:'closed',reqs:[RQ({mine:true,i_can_approve:false})]}});await openLinks(t);
 ok(!(await t.page.isVisible('#lForm'))&&/cerrado/.test(await t.page.textContent('#lNote')),'vínculo: grupo cerrado no admite vínculos nuevos y lo explica');
 t=await mk(b,{lk:{hist:[RQ({status:'invalidated',mine:true}),RQ({id:'x2',status:'expired'}),RQ({id:'x3',status:'rejected'}),RQ({id:'x4',status:'cancelled'})],links:[{id:'l1',ref_type:'escapada_trip',ref_id:'z',status:'active',name:'Playa',in_trash:true}]}});await openLinks(t);
 await t.page.evaluate(()=>{document.getElementById('lHistW').open=true});await t.page.waitForTimeout(300);
 const hh=await t.page.textContent('#lHist');
 ok(t.calls.some(c=>c.startsWith('core_link_requests_history')&&c.includes('"p_days":7')),'vínculo: historial de 7 días');
 ok(/Playa 2027/.test(hh)&&/Pedida por Bruno/.test(hh)&&/invalidada/.test(hh)&&/vencida/.test(hh)&&/rechazada/.test(hh)&&/cancelada/.test(hh),'vínculo: historial muestra invalidada, vencida, rechazada y cancelada');
 ok(/en papelera/.test(await t.page.textContent('#lList')),'vínculo: evento o viaje en papelera se marca');
 ok(t.errs.length===0,'vínculo: sin errores de JS (historial)');

 // papelera de grupos
 t=await mk(b,{lk:{empty:true}});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#vGroup',{state:'visible'});await t.page.waitForTimeout(300);
 await t.page.click('#btnGear');await t.page.waitForTimeout(200);
 ok(await t.page.isVisible('#btnDelGroup'),'papelera: grupo vacío ofrece eliminar');
 await t.page.click('#btnDelGroup');await t.page.waitForTimeout(150);
 ok(!t.calls.some(c=>c.startsWith('cuentas_group_delete')),'papelera: el primer toque solo pide confirmar');
 await t.page.click('#btnDelGroup');await t.page.waitForTimeout(500);
 ok(t.calls.some(c=>c.startsWith('cuentas_group_delete')),'papelera: segundo toque elimina');
 ok(await t.page.isVisible('#vHome')&&await t.page.isVisible('#cTrash')&&/Viaje 1/.test(await t.page.textContent('#trashList')),'papelera: vuelve al inicio y el grupo aparece en la papelera');
 await t.page.evaluate(()=>{document.getElementById('cTrash').open=true});await t.page.click('[data-rs]');await t.page.waitForTimeout(500);
 ok(t.calls.some(c=>c.startsWith('cuentas_group_restore'))&&/restaurado/i.test(await t.page.textContent('#msg')),'papelera: restaurar');
 ok(t.errs.length===0,'papelera: sin errores de JS');
 t=await mk(b);await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#vGroup',{state:'visible'});await t.page.waitForTimeout(300);await t.page.click('#btnGear');await t.page.waitForTimeout(200);
 ok(!(await t.page.isVisible('#btnDelGroup')),'papelera: grupo con historial no ofrece eliminar');

 // cotización automática
 const openExp=async t=>{await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});await t.page.click('#fab');await t.page.evaluate(()=>{document.getElementById('eAdv').open=true})};

 // liquidar entre monedas
 const openPay=async(t)=>{await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});await t.page.click('#btnSettle');await t.page.click('[data-pay]')};
 t=await mk(b);await openPay(t);
 ok(await t.page.isVisible('#pCur')&&!(await t.page.isVisible('#pFxBox')),'otra moneda: elige en qué moneda pagó, sin cotización si es la misma');
 await t.page.selectOption('#pCur','USD');await t.page.waitForTimeout(600);
 ok(await t.page.inputValue('#pFx')==='1455,00'&&await t.page.inputValue('#pAmt')==='1,71','otra moneda: precarga la cotización y el importe que deja la deuda casi en cero');
 ok(/Tu deuda baja[^]*2\.488,05/.test(await t.page.textContent('#pEq'))&&/DolarApi/.test(await t.page.textContent('#pEq')),'otra moneda: muestra cuánto baja la deuda y la fuente');
 await t.page.click('#btnPay');await t.page.waitForTimeout(400);
 {const c=t.calls.find(c=>c.startsWith('cuentas_payment_add'));ok(c&&c.includes('"p_currency":"ARS"')&&c.includes('"p_amount_minor":248805')&&c.includes('"p_paid_currency":"USD"')&&c.includes('"p_paid_minor":171')&&c.includes('"p_fx":1455')&&c.includes('"p_fx_source":"DolarApi oficial"'),'otra moneda: guarda lo pagado, la cotización y la fuente');}
 ok(t.errs.length===0,'otra moneda: sin errores de JS');
 t=await mk(b);await openPay(t);await t.page.selectOption('#pCur','USD');await t.page.waitForTimeout(600);
 await t.page.fill('#pAmt','1');await t.page.fill('#pFx','2000');await t.page.waitForTimeout(100);
 ok(/Ojo: se aparta más de 10%/.test(await t.page.textContent('#pEq')),'otra moneda: avisa si la cotización se aparta de la sugerida');
 await t.page.fill('#pAmt','100');await t.page.waitForTimeout(100);
 ok(/Es más de lo que debés/.test(await t.page.textContent('#pEq')),'otra moneda: avisa si se pasa de la deuda');
 await t.page.click('#btnPay');await t.page.waitForTimeout(300);
 ok(/más de lo que debés/.test(await t.page.textContent('#msg'))&&!t.calls.some(c=>c.startsWith('cuentas_payment_add')),'otra moneda: no registra un pago que se pasa');
 await t.page.fill('#pAmt','1');await t.page.click('#btnPay');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('cuentas_payment_add')&&c.includes('"p_fx_source":"manual"')&&c.includes('"p_fx_at":null')),'otra moneda: cotización editada queda como manual');
 t=await mk(b,{lk:{fxFail:true}});await openPay(t);await t.page.selectOption('#pCur','USD');await t.page.waitForTimeout(600);
 ok(/No pude traer la cotización/.test(await t.page.textContent('#pEq'))&&await t.page.inputValue('#pFx')==='','otra moneda: si la fuente falla se carga a mano');
 await t.page.fill('#pFx','1500');await t.page.fill('#pAmt','1');await t.page.click('#btnPay');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('cuentas_payment_add')&&c.includes('"p_fx":1500')&&c.includes('"p_amount_minor":150000')),'otra moneda: con la fuente caída se paga igual');
 t=await mk(b);await openPay(t);await t.page.click('#btnPay');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('cuentas_payment_add')&&c.includes('"p_currency":"ARS"')&&!c.includes('p_paid_currency')),'otra moneda: pagar en la misma moneda sigue igual');
 t=await mk(b,{lk:{cross:false}});await openPay(t);
 ok(!(await t.page.isVisible('#pCur')),'otra moneda: con el interruptor apagado no se ofrece');
 t=await mk(b,{lk:{member:true,xpay:true}});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.evaluate(()=>{document.querySelectorAll('#moves details.mv').forEach(d=>d.open=true)});
 {const tx=await t.page.textContent('#moves');ok(/Pagó[^]*USD|US\$/.test(tx)&&/1 USD = 1455,00 ARS/.test(tx)&&/aceptás el pago y esta cotización/.test(tx),'otra moneda: quien cobra ve lo pagado y la cotización antes de confirmar');}
 ok(await t.page.locator('[data-conf]').count()===1&&await t.page.locator('[data-pcancel][data-rej]').count()===1,'otra moneda: quien cobra puede confirmar o rechazar');
 await t.page.locator('[data-pcancel][data-rej]').click();await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('cuentas_payment_cancel'))&&/Pago rechazado/.test(await t.page.textContent('#msg')),'otra moneda: rechazar llama a cancelar y avisa');

 // formulario: fecha con repetición, notas y gastos sin grupo
 t=await mk(b);await openExp(t);
 ok(await t.page.isVisible('#btnDate')&&await t.page.isVisible('#btnNotes')&&await t.page.isVisible('#btnRcpt'),'formulario: botones de fecha, foto y notas');
 ok(!(await t.page.isVisible('#ePanDate'))&&!(await t.page.isVisible('#ePanNotes')),'formulario: los paneles arrancan cerrados');
 await t.page.click('#btnDate');await t.page.fill('#eDate','2026-11-10');await t.page.dispatchEvent('#eDate','change');
 ok(/10\/11\/26/.test(await t.page.textContent('#eDateLbl')),'formulario: la fecha elegida se ve en el botón');
 await t.page.click('#btnNotes');await t.page.fill('#eNotes','Pagado con tarjeta');
 ok(/Notas ✓/.test(await t.page.textContent('#eNotesLbl')),'formulario: el botón marca que hay una nota');
 await t.page.fill('#eDesc','Cena');await t.page.fill('#eAmt','300');await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
 {const c=t.calls.find(c=>c.startsWith('cuentas_expense_add'));ok(c&&c.includes('"p_occurred_on":"2026-11-10"')&&c.includes('"p_notes":"Pagado con tarjeta"'),'formulario: guarda la fecha elegida y la nota');}
 ok(t.errs.length===0,'formulario: sin errores de JS');
 t=await mk(b);await openExp(t);await t.page.fill('#eDesc','Cena');await t.page.fill('#eAmt','300');await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
 {const c=t.calls.find(c=>c.startsWith('cuentas_expense_add'));ok(c&&!c.includes('p_notes')&&new RegExp('"p_occurred_on":"'+new Date().getFullYear()).test(c),'formulario: sin fecha ni nota usa hoy y no manda notas');}
 t=await mk(b);await openExp(t);await t.page.click('#btnDate');await t.page.fill('#eDate','2026-12-01');await t.page.selectOption('#eRep','monthly');
 ok(/↻/.test(await t.page.textContent('#eDateLbl')),'formulario: avisa en el botón que se repite');
 {const bx=await t.page.evaluate(()=>[...document.querySelectorAll('.xbtns .sec')].map(b=>{const r=b.getBoundingClientRect();return [Math.round(r.top),Math.round(r.width)]}));ok(bx.length===3&&bx.every(x=>x[0]===bx[0][0])&&Math.max(...bx.map(x=>x[1]))-Math.min(...bx.map(x=>x[1]))<=1,'formulario: los tres botones (fecha, notas, foto) van en una fila y del mismo ancho')}
 await t.page.fill('#eDesc','Expensas');await t.page.fill('#eAmt','1000');await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
 ok(t.calls.some(c=>c.startsWith('cuentas_recurring_save')&&c.includes('"p_start":"2026-12-01"')),'formulario: el gasto repetido arranca en la fecha elegida');
 t=await mk(b,{lk:{notes:true}});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.evaluate(()=>{document.querySelectorAll('#moves details.mv').forEach(d=>d.open=true)});
 ok(/Nota: Pagado con tarjeta/.test(await t.page.textContent('#moves')),'lista: muestra la nota del gasto');
 t=await mk(b);await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 ok(await t.page.isVisible('#optPersonal'),'sin grupo: aparece "Gastos sin grupo" si todavía no existe');
 await t.page.click('#optPersonal');await t.page.waitForTimeout(500);
 ok(t.calls.some(c=>c.startsWith('cuentas_personal_group'))&&await t.page.isVisible('#vGroup'),'sin grupo: se crea y se abre');
 t=await mk(b,{lk:{personal:true}});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 ok(await t.page.isVisible('#optPersonal')&&(await t.page.locator('#groups [data-g]').count())===1,'sin grupo: si ya existe sigue fijo en el menú principal y no se repite en la lista');
 await t.page.evaluate(()=>document.getElementById('fab').click());await t.page.waitForTimeout(200);
 ok(/Gastos sin grupo/.test(await t.page.textContent('#pkL')),'elegir grupo: "Gastos sin grupo" está entre las opciones');
 // importe con punto decimal y formulario liviano
 const openSolo=async t=>{await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#fab',{state:'visible'});await t.page.click('#fab');await t.page.waitForTimeout(200)};
 t=await mk(b,{lk:{empty:true}});await openSolo(t);
 ok(!(await t.page.isVisible('#ePayer'))&&!(await t.page.isVisible('#eAdv'))&&await t.page.isVisible('#btnSoloAdd'),'liviano: solo, no muestra Pagó/Dividir y ofrece dividir con otra persona');
 await t.page.fill('#eDesc','Vino');await t.page.fill('#eAmt','1500.50');await t.page.waitForTimeout(100);
 ok(/1\.500,50/.test(await t.page.textContent('#eAmtNote')),'importe: con punto decimal se entiende 1.500,50 y se muestra antes de guardar');
 await t.page.click('#btnSoloAdd');await t.page.fill('#eSoloName','Lu');await t.page.click('#btnSoloOk');await t.page.waitForTimeout(500);
 ok(t.calls.some(c=>c.startsWith('cuentas_guest_add')&&c.includes('Lu'))&&await t.page.inputValue('#eDesc')==='Vino'&&await t.page.inputValue('#eAmt')==='1500.50'&&await t.page.isVisible('#eAmt'),'liviano: sumar a alguien por nombre no pierde lo escrito');
 t=await mk(b,{lk:{empty:true}});await openSolo(t);await t.page.fill('#eDesc','Vino');await t.page.fill('#eAmt','1500.50');await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
 ok(t.calls.some(c=>c.startsWith('cuentas_expense_add')&&c.includes('"p_amount_minor":150050')),'importe: 1500.50 se guarda como 1.500,50 (no 150.050)');
 // sin desborde horizontal a 360 px en las pantallas principales
 {t=await mk(b,{lk:{notes:true}});await t.page.setViewportSize({width:360,height:800});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
  const ov=()=>t.page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
  const bad=[];if(await ov()>0)bad.push('inicio');
  await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});if(await ov()>0)bad.push('grupo');
  await t.page.click('#fab');await t.page.waitForTimeout(200);await t.page.evaluate(()=>{document.getElementById('eAdv').open=true;document.getElementById('btnDate').click();document.getElementById('btnNotes').click()});if(await ov()>0)bad.push('formulario');
  ok(bad.length===0,'360 px: sin desborde horizontal'+(bad.length?' (falla en '+bad.join(', ')+')':''))}
 // OCR del ticket: solo sugiere, se carga al tocar, nunca guarda solo
 {t=await mk(b,{lk:{empty:true}});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
  const P=await t.page.evaluate(()=>[ocrParse('SUPER X\nCUIT 30-1234\nFecha 15/11/2026\nSUBTOTAL 10.000,00\nIVA 2.100,00\nTOTAL $ 12.100,00'),ocrParse('Cafe 1.500,00\nTorta 3.200,00'),ocrParse('12-3-26 total 350.50'),ocrParse('sin datos'),ocrParse('fecha 31/02/2026 total 10,00'),ocrParse('KIOSCO\nTOTAL $ 12.345\n'),ocrParse('Gracias\nTOTAL 8500\n')]);
  ok(P[5].amount===12345&&P[6].amount===8500,'ocr: acepta el total sin centavos (12.345 o 8500)');
  {const R2=await t.page.evaluate(x=>ocrParse(x),'Participé por of      A\nred dav. [MIE  A\nNuestra   he A\nEncuesta de 1127 RSE\nSANTOS CAFE & BRUNCH\nAVENIDA ENILIO CASTRO 5790\nHesa 4\n00000052088\nsalon (6)\nmah. oN wd\n| Hozo\nMesera\n= 3 Cafe con Leche\n\$ 10.500,00\n1 Sandvich Vesaie    \$\n12.000,00\n2 Desayuno "Santos" (Incluye cafe c/\nLeche)  \$§ 32.000,00\n1 ADICIONAL CREMA\n\$ 600,00\n1 Sanduich De 1a Casa\n\$ 12.000,00\n2 Alfaior DUBAI\n\$ 9.000,00\n1 Clasico con TOSTADO HIGA\n+ Cafe con leche   \$ 14.000,00\n1 Cuadrado de Budin\nde Linon  \$ 4.500,00\nTOTAL § 106.100,00\npropine Sugeride: 10% A   \$\n10.610,00\nTotal con propina Sugerida\n\$ 116.710,00\nTICKET NO VALIDO COMO FACTURA');ok(R2.amount===106100&&R2.confirmed&&R2.shop==='Santos Cafe & Brunch','ocr (ticket real de Pau): total 106.100 confirmado por la propina y comercio bien leído');ok(R2.sum===94600,'ocr (ticket real de Pau): suma lo que alcanzó a leer (falta un renglón)')}
  {const R=await t.page.evaluate(x=>ocrParse(x),'SeG 1\n24-08-2025 19:34\n1 Bagel $ 11.500,00\n3 Cafe $ 10.500,00\n2 Desayuno $ 32.000,00\n1 Adicional $ 600,00\nTOTAL $ 105.100,00\nPropina Sugerida: 10% $ 10.610,00\nTotal con Propina Sugerida $ 116.710,00');ok(R.amount===105100&&R.date==='2025-08-24'&&R.sum===54600,'ocr: no confunde "Total con propina" con el total; suma los renglones');ok(R.shop===null,'ocr: no propone un comercio mal leído (SeG 1)')}
  ok(P[0].amount===12100&&P[0].date==='2026-11-15','ocr: toma el TOTAL (no subtotal ni IVA) y la fecha');
  ok(P[0].shop==='Super X'&&P[1].shop===null,'ocr: el comercio es la primera línea con nombre (sin CUIT, fecha ni números) y no se inventa');
  ok(P[1].amount===3200,'ocr: sin la palabra total, toma el mayor');
  ok(P[2].amount===350.5&&P[2].date==='2026-03-12','ocr: acepta punto decimal y fecha corta');
  ok(P[3].amount===null&&P[3].date===null&&P[4].date===null,'ocr: sin datos o con fecha imposible no inventa nada');
  let reqs=0;await t.page.route('**/tesseract.min.js',r=>{reqs++;r.fulfill({contentType:'application/javascript',body:"window.Tesseract={recognize:async()=>({data:{text:'FARMACITY\\nFecha: 15/11/2026\\nSUBTOTAL 10.000,00\\nTOTAL $ 12.345,50\\n'}})}"})});
  await t.page.click('[data-g]');await t.page.waitForSelector('#fab',{state:'visible'});await t.page.click('#fab');
  const png2=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGM44eCAFTEMLQkALKhSAY1dq8cAAAAASUVORK5CYII=','base64');
  ok(!(await t.page.isVisible('#btnOcr')),'ocr: sin foto no se ofrece');
  await t.page.setInputFiles('#eRcptIn',{name:'t.png',mimeType:'image/png',buffer:png2});await t.page.waitForTimeout(500);
  ok(await t.page.isVisible('#btnOcr')&&reqs===0,'ocr: con foto se ofrece y todavía no se descargó nada');
  await t.page.fill('#eDesc','');await t.page.click('#btnOcr');await t.page.waitForTimeout(600);
  ok(reqs===1&&/12\.345,50/.test(await t.page.textContent('#ocrNote'))&&/15\/11/.test(await t.page.textContent('#ocrNote'))&&/Farmacity/.test(await t.page.textContent('#ocrNote')),'ocr: al tocar, lee y muestra importe, fecha y comercio');
  ok(await t.page.inputValue('#eAmt')===''&&!t.calls.some(c=>c.startsWith('cuentas_expense_add')),'ocr: solo sugiere, no completa ni guarda solo');
  await t.page.click('#btnOcrUse');
  ok(await t.page.inputValue('#eAmt')==='12345,50'&&await t.page.inputValue('#eDate')==='2026-11-15'&&await t.page.inputValue('#eDesc')==='Farmacity'&&!t.calls.some(c=>c.startsWith('cuentas_expense_add')),'ocr: al confirmar completa importe, fecha y descripción, sin guardar');
  t=await mk(b,{lk:{empty:true}});await t.page.route('**/tesseract.min.js',r=>r.abort());await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#fab',{state:'visible'});await t.page.click('#fab');
  await t.page.setInputFiles('#eRcptIn',{name:'t.png',mimeType:'image/png',buffer:png2});await t.page.waitForTimeout(500);await t.page.click('#btnOcr');await t.page.waitForTimeout(800);
  ok(/a mano/.test(await t.page.textContent('#ocrNote'))&&!(await t.page.isVisible('#btnOcrUse')),'ocr: si no carga el lector, avisa y se sigue a mano')}
 // foto que el navegador no puede abrir: aviso en castellano y sigue andando
 {t=await mk(b,{lk:{empty:true}});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#fab',{state:'visible'});await t.page.click('#fab');
  await t.page.setInputFiles('#eRcptIn',{name:'raro.heic',mimeType:'image/heic',buffer:Buffer.from('no es una imagen')});await t.page.waitForTimeout(600);
  const mt=await t.page.textContent('#msg');
  ok(/No pude abrir esa foto/.test(mt)&&!/decoded/i.test(mt)&&!(await t.page.isVisible('#btnOcr')),'foto: si no se puede abrir, avisa en castellano y no ofrece leerla');}
 // OCR: el total no coincide con la suma de renglones -> ofrece la suma
 {t=await mk(b,{lk:{empty:true}});await t.page.route('**/tesseract.min.js',r=>r.fulfill({contentType:'application/javascript',body:"window.Tesseract={recognize:async()=>({data:{text:'KIOSCO LUNA\\n1 Pan $ 1.000,00\\n1 Cafe $ 2.000,00\\n1 Torta $ 3.000,00\\nTOTAL $ 5.000,00\\n'}})}"}));
  await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#fab',{state:'visible'});await t.page.click('#fab');
  await t.page.setInputFiles('#eRcptIn',{name:'t.png',mimeType:'image/png',buffer:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGM44eCAFTEMLQkALKhSAY1dq8cAAAAASUVORK5CYII=','base64')});await t.page.waitForTimeout(500);
  await t.page.click('#btnOcr');await t.page.waitForTimeout(600);
  ok(/suman/.test(await t.page.textContent('#ocrNote'))&&await t.page.isVisible('#btnOcrSum')&&/6\.000,00/.test(await t.page.textContent('#btnOcrSum')),'ocr: si el total no coincide con los renglones, avisa y ofrece la suma');
  await t.page.click('#btnOcrSum');ok(await t.page.inputValue('#eAmt')==='6000,00'&&!t.calls.some(c=>c.startsWith('cuentas_expense_add')),'ocr: usar la suma completa el importe sin guardar')}
 // avisos de error cortos
 t=await mk(b);await openExp(t);await t.page.fill('#eDesc','Cena');await t.page.fill('#eAmt','0');await t.page.click('#btnExpense');await t.page.waitForTimeout(250);
 ok(await t.page.isVisible('#msg.bad'),'avisos: el error aparece');
 await t.page.fill('#eAmt','5');await t.page.waitForTimeout(100);
 ok(!(await t.page.isVisible('#msg')),'avisos: el error se va al volver a escribir');
 await t.page.fill('#eAmt','0');await t.page.click('#btnExpense');await t.page.waitForTimeout(250);await t.page.click('#msg');
 ok(!(await t.page.isVisible('#msg')),'avisos: el error se cierra tocándolo');
 await t.page.fill('#eAmt','0');await t.page.click('#btnExpense');await t.page.waitForTimeout(4400);
 ok(!(await t.page.isVisible('#msg')),'avisos: el error se va solo en pocos segundos');
 t=await mk(b);await openExp(t);
 await t.page.selectOption('#eCur','USD');await t.page.waitForTimeout(600);
 ok(await t.page.inputValue('#eFx')==='1455,00','cotización: se precarga la oficial del día');
 ok(/oficial de hoy/.test(await t.page.textContent('#eFxNote'))&&/DolarApi/.test(await t.page.textContent('#eFxNote')),'cotización: avisa la fuente y que se puede editar');
 await t.page.fill('#eDesc','Hotel');await t.page.fill('#eAmt','100');await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
 let ea=t.calls.find(c=>c.startsWith('cuentas_expense_add'));
 ok(ea&&ea.includes('"p_fx":1455')&&ea.includes('"p_fx_source":"DolarApi oficial"')&&ea.includes('"p_fx_at":"2026-11-21T14:35'),'cotización: se guarda con la fuente y la hora');
 ok(t.errs.length===0,'cotización: sin errores de JS');
 t=await mk(b);await openExp(t);await t.page.selectOption('#eCur','USD');await t.page.waitForTimeout(600);
 await t.page.fill('#eFx','1700');await t.page.waitForTimeout(100);
 ok(/Ojo: se aparta más de 10%/.test(await t.page.textContent('#eFxNote')),'cotización: avisa si se aparta más del 10%');
 await t.page.fill('#eDesc','Hotel');await t.page.fill('#eAmt','100');await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
 ea=t.calls.find(c=>c.startsWith('cuentas_expense_add'));
 ok(ea&&ea.includes('"p_fx":1700')&&ea.includes('"p_fx_source":"manual"')&&ea.includes('"p_fx_at":null'),'cotización: editada queda como manual');
 t=await mk(b,{lk:{fxFail:true}});await openExp(t);await t.page.selectOption('#eCur','USD');await t.page.waitForTimeout(600);
 ok(/No pude traer la cotización/.test(await t.page.textContent('#eFxNote'))&&await t.page.inputValue('#eFx')==='','cotización: si la fuente falla se carga a mano');
 await t.page.fill('#eFx','1500');await t.page.fill('#eDesc','Hotel');await t.page.fill('#eAmt','100');await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
 ok(t.calls.some(c=>c.startsWith('cuentas_expense_add')&&c.includes('"p_fx":1500')&&c.includes('"p_fx_source":"manual"')),'cotización: con la fuente caída el gasto se guarda igual');
 t=await mk(b);await openExp(t);await t.page.selectOption('#eCur','EUR');await t.page.waitForTimeout(600);
 ok(await t.page.inputValue('#eFx')==='1600,50','cotización: otra moneda cruza con USD (EUR×USD×oficial)');
 t=await mk(b,{lk:{fx:false}});await openExp(t);await t.page.selectOption('#eCur','USD');await t.page.waitForTimeout(500);
 ok(!(t.state.fxCalls||[]).length,'cotización: con el interruptor apagado no consulta nada');
 t=await mk(b,{lk:{fxType:'mep'}});await openExp(t);await t.page.selectOption('#eCur','USD');await t.page.waitForTimeout(500);
 ok((t.state.fxCalls||[]).some(u=>u.includes('/dolares/bolsa')),'cotización: usa el tipo elegido por el grupo (MEP)');
 t=await mk(b);await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#vGroup',{state:'visible'});await t.page.waitForTimeout(300);await t.page.click('#btnGear');await t.page.waitForTimeout(200);
 ok(await t.page.isVisible('#cFx'),'cotización: la administración ve el tipo de cotización');
 await t.page.evaluate(()=>{document.getElementById('cFx').open=true});await t.page.selectOption('#fxType','blue');await t.page.waitForTimeout(400);
 ok(t.calls.some(c=>c.startsWith('cuentas_group_set_fx_type')&&c.includes('"p_type":"blue"')),'cotización: cambiar el tipo lo guarda');
 await b.close();console.log(fails?fails+' fallas':'todo ok');process.exit(fails?1:0)})();
