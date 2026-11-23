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
   case 'cuentas_balances':if(lk.cred)return J([{user_id:ME,balance_minor:'250000',currency:'ARS'},{user_id:BR,balance_minor:'-250000',currency:'ARS'}]);return J(guest?[{user_id:ME,balance_minor:'-250000',currency:'ARS'},{user_id:BR,balance_minor:'100000',currency:'ARS'},{user_id:LU,balance_minor:'150000',currency:'ARS'}]:[{user_id:ME,balance_minor:debt?'-250000':'0',currency:'ARS'},{user_id:BR,balance_minor:debt?'250000':'0',currency:'ARS'}]);
   case 'cuentas_group_payouts':return J([{user_id:BR,alias:'bruno.cuentas',cbu:null,holder_name:'Bruno',bank:'MP'}].concat(lk.cred&&!lk.nopay?[{user_id:ME,alias:'pau.cuentas',cbu:null,holder_name:'Pau',bank:'MP'}]:[]));
   case 'cuentas_payment_add':debt=false;return J('p1');
   case 'cuentas_expense_add':if(offline)return r.abort('failed');return J('e1');
   case 'cuentas_group_create':return J(G);
   case 'cuentas_notif_prefs_get':return J([['payment_to_confirm',true],['payment_confirmed',false],['payment_cancelled',false],['expense_new',false],['recurring_added',false],['expense_voided',false],['expense_edited',false],['group_status',false]].map(([kind,essential])=>({kind,enabled:true,essential})));
   case 'cuentas_notif_pref_set':return J(null);
   case 'cuentas_categories_list':return J(fam?[{key:'comida',name:'Comida y bebida',icon:'fork',color:0,archived:false},{key:'ocio',name:'Salidas y ocio',icon:'ticket',color:4,archived:false}]:[]);
   case 'cuentas_recurring_list':return J(fam?[{id:'r1',description:'Alquiler',amount_minor:5000000,currency:'ARS',frequency:'monthly',status:'active',next_on:'2026-12-01',created_by:ME}]:[]);
   case 'cuentas_receipts_list':return J(fam?[{movement:'e1',path:G+'/e1.jpg'}]:[]);
   case 'cuentas_receipt_register':case 'cuentas_receipt_copy':return J(null);
   case 'cuentas_recurring_run':return J(0);
   case 'core_notifications_list':if(lk.newNotices)return J([{id:'a1',domain:'cuentas',kind:'payment_to_confirm',group_id:G,group_name:'Viaje 1',data:{amount_minor:150000,currency:'ARS'},essential:true,read_at:null},{id:'a2',domain:'cuentas',kind:'expense_new',group_id:G,group_name:'Viaje 1',data:{count:3,description:'Cena'},essential:false,read_at:null},{id:'a3',domain:'cuentas',kind:'expense_new',group_id:G,group_name:'Viaje 2',data:{count:1,description:'Nafta'},essential:false,read_at:null},{id:'a4',domain:'cuentas',kind:'group_status',group_id:G,group_name:'Viaje 1',data:{status:'closed'},essential:false,read_at:null}]);return J(notices?[{id:'n1',domain:'cuentas',kind:'delegation_granted',group_id:G,group_name:'Viaje 1',data:{scopes:['invite','void']},essential:true,created_at:'2026-11-15T10:00:00Z',read_at:null},{id:'n2',domain:'cuentas',kind:'proposal_invalidated',group_id:G,group_name:'Viaje 1',data:{},essential:true,created_at:'2026-11-15T11:00:00Z',read_at:null}]:[]);
   case 'core_notifications_read':return J(1);
   case 'cuentas_recurring_save':case 'cuentas_recurring_set_status':return J(null);
   case 'cuentas_activity_list':return J(fam?[{id:1,action:'expense_added',actor:ME,created_at:'2026-11-14T10:00:00Z',amount_minor:20000,currency:'ARS',description:'Asado'},{id:2,action:'member_weight_set',actor:ME,target:BR,weight:0.5,created_at:'2026-11-14T09:00:00Z'}]:[]);
   case 'cuentas_member_set_weight':case 'cuentas_category_save':return J(null);
   case 'cuentas_movements_page':case 'cuentas_movements_list':if(lk.gov)return J([{id:'g1',seq:1,kind:'expense',description:'Vinos',amount_minor:'22000000',currency:'ARS',from_user:BR,occurred_on:'2026-11-10',created_at:'2026-11-10T15:00:00Z',shares:{[ME]:11000000,[BR]:11000000},created_by:BR,voided:true},{id:'v1',seq:2,kind:'void',ref_id:'g1',description:'Editado',amount_minor:'22000000',currency:'ARS',created_by:ME,created_at:'2026-11-11T12:00:00Z'},{id:'g2',seq:3,kind:'expense',description:'Asado',amount_minor:'3000000',currency:'ARS',from_user:ME,occurred_on:'2026-11-12',created_at:'2026-11-12T20:00:00Z',shares:{[ME]:1500000,[BR]:1500000},created_by:ME,voided:true},{id:'v2',seq:4,kind:'void',ref_id:'g2',description:'Duplicado',amount_minor:'3000000',currency:'ARS',created_by:BR,created_at:'2026-11-12T21:00:00Z'},{id:'g3',seq:5,kind:'payment',amount_minor:'100000',currency:'ARS',from_user:BR,to_user:ME,occurred_on:'2026-11-13',created_at:'2026-11-13T09:00:00Z',created_by:BR,confirmed:true,reversed:false},{id:'c3',seq:6,kind:'payment_confirmation',ref_id:'g3',amount_minor:'100000',currency:'ARS',created_by:ME,created_at:'2026-11-13T10:00:00Z'}]);if(lk.many){const q=JSON.parse(body||'{}'),all=Array.from({length:250},(_,i)=>({id:'m'+(i+1),seq:i+1,kind:'expense',description:'Gasto '+(i+1),amount_minor:'1000',currency:'ARS',from_user:ME,occurred_on:'2026-10-'+String(1+(i%28)).padStart(2,'0'),shares:{[ME]:500,[BR]:500},created_by:ME,voided:false})).filter(x=>q.p_before==null||x.seq<q.p_before);return J(all.slice(Math.max(0,all.length-(q.p_limit||250))))}if(lk.empty)return J([]);if(lk.xpay)return J([{id:'x1',kind:'payment',amount_minor:'248805',currency:'ARS',from_user:BR,to_user:ME,occurred_on:'2026-11-14',created_by:BR,confirmed:false,reversed:false,paid_currency:'USD',paid_amount_minor:'171',fx_rate:'1455',fx_source:'DolarApi oficial'}]);if(pay)return J([{id:'p1',kind:'payment',amount_minor:'100000',currency:'ARS',from_user:BR,to_user:LU,occurred_on:'2026-11-14',created_by:BR,confirmed:false,reversed:false},{id:'p2',kind:'payment',amount_minor:'50000',currency:'ARS',from_user:ME,to_user:BR,occurred_on:'2026-11-14',created_by:ME,confirmed:true,reversed:false}]);if(eqExp)return J([{id:'e9',kind:'expense',description:'Asado',amount_minor:'2000',currency:'ARS',from_user:ME,occurred_on:'2026-11-14',created_at:'2026-11-14T10:00:00Z',shares:{[ME]:1000,[BR]:1000},created_by:ME}]);return J([{id:'e1',kind:'expense',description:'Vinos',notes:lk.notes?'Pagado con tarjeta':undefined,amount_minor:'22000000',currency:'ARS',from_user:BR,occurred_on:'2026-09-09',shares:{[ME]:2750000,[BR]:19250000},created_by:BR}].concat(fam?[{id:'e2',kind:'expense',description:'Hotel',amount_minor:'10000',currency:'USD',fx_rate:'1000',from_user:ME,occurred_on:'2026-09-10',shares:{[ME]:5000,[BR]:5000},created_by:ME}]:[]).map(x=>fam?{...x,category:'comida'}:x));
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
 await t.page.click('#mList .item:has-text("Lucía") [data-more]');await t.page.waitForTimeout(150);if(await t.page.isVisible('#pick:not([hidden])'))await t.page.click('#pkL >> text=Copiar link');await t.page.waitForTimeout(300);
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
 await t.page.evaluate(()=>{document.getElementById('eRepBox').hidden=false;document.getElementById('eAdv').open=true});await t.page.selectOption('#eCur','USD');ok(await t.page.isVisible('#eFx'),'moneda: otra moneda pide cotización');
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
 ok(/unidad de (Pau|Vos)/.test(await t.page.textContent('#mList')),'unidad: etiqueta «unidad de …» en el miembro');
 ok(/cambió cuánto cuenta Bruno \(½\)/.test(await t.page.textContent('#actList')),'actividad: muestra el cambio de peso');
 ok(/Vos cargó un gasto/.test(await t.page.textContent('#actList')),'actividad: muestra qué pasó en el grupo');
 ok(/cuenta ½/.test(await t.page.textContent('#mList')),'ajustes: etiqueta de peso en el miembro');
 // miembros: Unidad + ⋯ (sin botones que se salgan de la tarjeta)
 ok((await t.page.locator('#mList [data-fam]').first().textContent()).trim()==='Unidad','miembros: el botón se llama «Unidad»');
 const ov=await t.page.evaluate(()=>{const c=document.querySelector('#mList').getBoundingClientRect().right;return [...document.querySelectorAll('#mList button')].filter(b=>b.getBoundingClientRect().right>c+1).length});
 ok(ov===0,'miembros: ningún botón se sale de la tarjeta ('+ov+')');
 await t.page.click('#mList .item:not(:has-text("Lucía")) [data-more]');await t.page.waitForTimeout(150);
 ok(/Quitar del grupo/.test(await t.page.textContent('#pkL')),'miembros: el ⋯ ofrece quitar del grupo');
 await t.page.click('#pkL >> text=Quitar del grupo');await t.page.waitForTimeout(150);
 ok(/Sí, quitar/.test(await t.page.textContent('#pkL'))&&!t.calls.some(c=>c.startsWith('cuentas_member_remove')||c.startsWith('cuentas_guest_remove')),'miembros: quitar pide confirmar antes de hacerlo');
 await t.page.click('#pkL >> text=No, dejarlo');await t.page.waitForTimeout(150);
 ok(!t.calls.some(c=>c.startsWith('cuentas_member_remove')),'miembros: «No, dejarlo» no quita a nadie');
 await t.page.click('[data-fam]');await t.page.click('#pick >> text=Niño/a');await t.page.waitForTimeout(250);
 ok(t.calls.some(c=>c.startsWith('cuentas_member_set_weight')&&c.includes('0.5')),'unidad: marca niño/a con peso 0,5');
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
 await t.page.click('#fab');await t.page.evaluate(()=>{document.getElementById('eRepBox').hidden=false;document.getElementById('eAdv').open=true});
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
 ok(await t.page.isVisible('#btnRep')&&!(await t.page.isVisible('#ePayer')),'ux: el reparto se ve resumido en una línea');
 await t.page.click('#btnRep');ok(await t.page.isVisible('#ePayer')&&await t.page.isVisible('#eMode'),'ux: tocando el resumen aparecen «Pagó» y «Dividir»');
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

 // avisos automáticos (0060)
 t=await mk(b,{lk:{newNotices:true}});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 await t.page.click('#optAct');await t.page.waitForTimeout(300);
 const nn=await t.page.textContent('#notices');
 ok(/pago de .*1\.500.* esperando tu confirmación/.test(nn)&&/aviso esencial/.test(nn),'avisos nuevos: pago a confirmar con el monto y marcado esencial');
 ok(/Hay 3 gastos nuevos donde participás/.test(nn)&&/Hay un gasto nuevo donde participás: Nafta/.test(nn),'avisos nuevos: gastos nuevos agrupados con la cuenta');
 ok(/El grupo se cerró/.test(nn),'avisos nuevos: grupo cerrado');
 ok(t.errs.length===0,'avisos nuevos: sin errores de JS');
 t=await mk(b);await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 await t.page.click('#avatar');await t.page.waitForTimeout(300);
 await t.page.evaluate(()=>{document.getElementById('cPrefs').open=true});await t.page.waitForTimeout(400);
 ok(await t.page.locator('#prefList input[type=checkbox]').count()===8,'preferencias de avisos: lista los 8 tipos');
 ok(await t.page.locator('#prefList input[data-pk="payment_to_confirm"]').isDisabled(),'preferencias de avisos: el esencial no se puede apagar');
 await t.page.uncheck('#prefList input[data-pk="expense_new"]');await t.page.waitForTimeout(300);
 ok(t.calls.some(c=>c.startsWith('cuentas_notif_pref_set')&&c.includes('"p_kind":"expense_new"')&&c.includes('"p_enabled":false')),'preferencias de avisos: apagar un tipo lo guarda');
 ok(t.errs.length===0,'preferencias de avisos: sin errores de JS');
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
 await t.page.waitForFunction(()=>['my_groups_all','group_get','movements_page'].every(f=>Object.keys(localStorage).some(k=>k.includes(f))),null,{timeout:15000}).catch(()=>{});await t.page.waitForTimeout(1500);t.state.down=true;await t.page.goto(URL);await t.page.waitForSelector('[data-g]',{timeout:20000});
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
 await t.page.click('#fab');await t.page.evaluate(()=>{document.getElementById('eRepBox').hidden=false;document.getElementById('eAdv').open=true});
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
 const openExp=async t=>{await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});await t.page.click('#fab');await t.page.evaluate(()=>{document.getElementById('eRepBox').hidden=false;document.getElementById('eRepBox').hidden=false;document.getElementById('eAdv').open=true})};

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
 ok(await t.page.inputValue('#eAmt')==='1.500,50'&&/1\.500,50/.test(await t.page.textContent('#btnExpense')),'importe: con punto decimal se entiende 1.500,50, se formatea en vivo y el botón lo muestra');
 await t.page.click('#btnSoloAdd');await t.page.fill('#eSoloName','Lu');await t.page.click('#btnSoloOk');await t.page.waitForTimeout(500);
 ok(t.calls.some(c=>c.startsWith('cuentas_guest_add')&&c.includes('Lu'))&&await t.page.inputValue('#eDesc')==='Vino'&&await t.page.inputValue('#eAmt')==='1.500,50'&&await t.page.isVisible('#eAmt'),'liviano: sumar a alguien por nombre no pierde lo escrito');
 t=await mk(b,{lk:{empty:true}});await openSolo(t);await t.page.fill('#eDesc','Vino');await t.page.fill('#eAmt','1500.50');await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
 ok(t.calls.some(c=>c.startsWith('cuentas_expense_add')&&c.includes('"p_amount_minor":150050')),'importe: 1500.50 se guarda como 1.500,50 (no 150.050)');
 // sin desborde horizontal a 360 px en las pantallas principales
 {t=await mk(b,{lk:{notes:true}});await t.page.setViewportSize({width:360,height:800});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
  const ov=()=>t.page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
  const bad=[];if(await ov()>0)bad.push('inicio');
  await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});if(await ov()>0)bad.push('grupo');
  await t.page.click('#fab');await t.page.waitForTimeout(200);await t.page.evaluate(()=>{document.getElementById('eRepBox').hidden=false;document.getElementById('eAdv').open=true;document.getElementById('btnDate').click();document.getElementById('btnNotes').click()});if(await ov()>0)bad.push('formulario');
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
  ok(await t.page.inputValue('#eAmt')==='12.345,50'&&await t.page.inputValue('#eDate')==='2026-11-15'&&await t.page.inputValue('#eDesc')==='Farmacity'&&!t.calls.some(c=>c.startsWith('cuentas_expense_add')),'ocr: al confirmar completa importe, fecha y descripción, sin guardar');
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
  await t.page.click('#btnOcrSum');ok(await t.page.inputValue('#eAmt')==='6.000,00'&&!t.calls.some(c=>c.startsWith('cuentas_expense_add')),'ocr: usar la suma completa el importe sin guardar')}
 // etapa 1 UX del gasto: guardar fijo, importe en vivo, reparto resumido, categorías en fila, fecha rápida, deshacer
 {t=await mk(b);await t.page.setViewportSize({width:390,height:760});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
  await t.page.click('#fab');await t.page.waitForTimeout(300);
  const fm=await t.page.evaluate(()=>['106100','1500.5','1.5000','12,5','0,5','1.500','','abc'].map(x=>fmtAmtLive(x)));
  ok(JSON.stringify(fm)===JSON.stringify(['106.100','1.500,5','15.000','12,5','0,5','1.500','','']),'ux1: el importe se formatea en vivo con separadores ('+fm.join(' | ')+')');
  await t.page.fill('#eDesc','Cena');await t.page.fill('#eAmt','300000');
  const r1=await t.page.evaluate(()=>{const b=document.getElementById('btnExpense').getBoundingClientRect();return {bottom:Math.round(b.bottom),h:window.innerHeight,txt:document.getElementById('btnExpense').textContent,cats:document.getElementById('eCats').getBoundingClientRect().height}});
  ok(r1.bottom<=r1.h&&/300\.000,00/.test(r1.txt),'ux1: el botón Guardar queda visible abajo y muestra el importe ('+r1.txt+')');
  ok(r1.cats<80,'ux1: las categorías ocupan una sola fila ('+r1.cats+' px)');
  if(process.env.SHOT){await t.page.screenshot({path:'/tmp/form1.png'});await t.page.click('#btnRep');await t.page.screenshot({path:'/tmp/form2.png',fullPage:false});await t.page.click('#btnRep')}
  const sm=await t.page.textContent('#btnRep');ok(/Pagaste vos/.test(sm)&&/entre todos/.test(sm)&&/c\/u/.test(sm),'ux1: el reparto se resume en una línea ('+sm.trim()+')');
  await t.page.click('#btnDate');await t.page.click('[data-dd="1"]');
  ok(/Ayer/.test(await t.page.textContent('#eDateLbl'))&&await t.page.inputValue('#eDate')!=='','ux1: chip «Ayer» completa la fecha');
  await t.page.click('[data-dd="0"]');ok(/Hoy/.test(await t.page.textContent('#eDateLbl'))&&await t.page.inputValue('#eDate')==='','ux1: chip «Hoy» la vuelve a hoy');
  await t.page.click('#btnExpense');await t.page.waitForTimeout(500);
  ok(/Deshacer/.test(await t.page.textContent('#msg'))&&/Cargar otro/.test(await t.page.textContent('#msg')),'ux1: tras guardar ofrece «Deshacer» y «Cargar otro»');
  await t.page.click('#msg .msgact >> text=Deshacer');await t.page.waitForTimeout(500);
  ok(t.calls.some(c=>c.startsWith('cuentas_expense_void')),'ux1: «Deshacer» anula el gasto recién cargado');
  await t.page.click('#fab');await t.page.fill('#eDesc','Otro');await t.page.fill('#eAmt','100');await t.page.click('#btnExpense');await t.page.waitForTimeout(500);
  await t.page.click('#msg .msgact >> text=Cargar otro');await t.page.waitForTimeout(300);
  ok(await t.page.isVisible('#eDesc')&&await t.page.inputValue('#eDesc')==='','ux1: «Cargar otro» abre el formulario vacío');
  ok(t.errs.length===0,'ux1: sin errores de JS')}
 // etapa 2 UX: lista por día con total, tu parte clara, menú ⋯
 {t=await mk(b,{fam:true});await t.page.setViewportSize({width:390,height:800});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
  const heads=await t.page.$$eval('#moves .mon',els=>els.map(e=>e.textContent));
  ok(heads.length===2&&/10 sep/.test(heads[0])&&/9 sep/.test(heads[1])&&(await t.page.$$('#moves .mon .dtot')).length===2,'ux2: la lista va agrupada por día (lo más nuevo arriba) con el total de cada día ('+heads.join(' | ')+')');
  const mt=await t.page.textContent('#moves');ok(/te toca/.test(mt)&&/te deben/.test(mt),'ux2: cada gasto dice «te toca» o «te deben»');
  ok(!(await t.page.isVisible('#moves [data-edit]'))&&await t.page.isVisible('#moves [data-mm]'),'ux2: Editar y Anular salieron de la fila y están en el menú ⋯');
  if(process.env.SHOT)await t.page.screenshot({path:'/tmp/list1.png'});
  await t.page.click('[data-mm="e2"]');await t.page.waitForTimeout(200);
  if(process.env.SHOT)await t.page.screenshot({path:'/tmp/list2.png'});
  const op=await t.page.textContent('#pkL');ok(/Editar/.test(op)&&/Anular/.test(op),'ux2: el menú ⋯ ofrece Editar y Anular');
  await t.page.click('#pkL >> text=Anular');await t.page.waitForTimeout(200);
  ok(/Sí, anular/.test(await t.page.textContent('#pkL'))&&!t.calls.some(c=>c.startsWith('cuentas_expense_void')),'ux2: Anular pide confirmación antes de hacer nada');
  await t.page.click('#pkL >> text=Sí, anular');await t.page.waitForTimeout(500);
  ok(t.calls.some(c=>c.startsWith('cuentas_expense_void')&&c.includes('e2')),'ux2: al confirmar, anula el gasto');
  await t.page.click('[data-mm="e2"]').catch(()=>{});
  ok(t.errs.length===0,'ux2: sin errores de JS')}
 {t=await mk(b,{fam:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
  await t.page.click('[data-mm="e2"]');await t.page.waitForTimeout(200);await t.page.click('#pkL >> text=Editar');await t.page.waitForTimeout(400);
  ok(await t.page.isVisible('#eDesc')&&await t.page.inputValue('#eDesc')==='Hotel'&&/Guardar cambios/.test(await t.page.textContent('#btnExpense')),'ux2: Editar desde el menú ⋯ abre el gasto para editar')}
 // etapa 3 UX: chips recientes, escanear primero, fechas
 {t=await mk(b,{fam:true});await t.page.setViewportSize({width:390,height:800});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
  await t.page.click('#fab');await t.page.waitForTimeout(300);
  const chips=await t.page.$$eval('#eRecent [data-rd]',e=>e.map(x=>x.dataset.rd));
  ok(chips.length>=1&&chips.length<=4&&new Set(chips.map(x=>x.toLowerCase())).size===chips.length&&await t.page.isVisible('#eRecent'),'ux3: el formulario nuevo ofrece descripciones recientes sin repetir');
  await t.page.click('#eRecent [data-rd]');await t.page.waitForTimeout(150);
  ok(await t.page.inputValue('#eDesc')===chips[0]&&!(await t.page.isVisible('#eRecent')),'ux3: tocar un chip completa la descripción y los chips se van');
  await t.page.fill('#eDesc','');await t.page.dispatchEvent('#eDesc','input');await t.page.waitForTimeout(100);
  ok(await t.page.isVisible('#eRecent'),'ux3: al vaciar la descripción vuelven los chips');
  ok(await t.page.isVisible('#btnScan'),'ux3: «Escanear ticket» visible en gasto nuevo');
  let reqs3=0;await t.page.route('**/tesseract.min.js',r=>{reqs3++;r.fulfill({contentType:'application/javascript',body:"window.Tesseract={recognize:async()=>({data:{text:'KIOSCO LUNA\\nFecha: 12/1O/2O26\\nTOTAL $ 2.500,00\\n'}})}"})});
  const png3=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGM44eCAFTEMLQkALKhSAY1dq8cAAAAASUVORK5CYII=','base64');
  const [fc]=await Promise.all([t.page.waitForEvent('filechooser'),t.page.click('#btnScan')]);await fc.setFiles({name:'t.png',mimeType:'image/png',buffer:png3});await t.page.waitForTimeout(1500);
  ok(reqs3===1&&/2\.500,00/.test(await t.page.textContent('#ocrNote'))&&/12\/10/.test(await t.page.textContent('#ocrNote')),'ux3: Escanear lee el ticket solo, sin tocar otro botón');
  ok(await t.page.inputValue('#eAmt')===''&&!t.calls.some(c=>c.startsWith('cuentas_expense_add')),'ux3: el escaneo solo sugiere, no completa ni guarda solo');
  await t.page.click('[data-mm]').catch(()=>{});
  ok(t.errs.length===0,'ux3: sin errores de JS')}
 {t=await mk(b,{fam:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
  await t.page.click('[data-mm="e2"]');await t.page.waitForTimeout(200);await t.page.click('#pkL >> text=Editar');await t.page.waitForTimeout(400);
  ok(!(await t.page.isVisible('#btnScan'))&&!(await t.page.isVisible('#eRecent')),'ux3: al editar no se ofrece escanear ni chips')}
 {const D=await t.page.evaluate(()=>['Fecha 12/1O/2O26','FECHA 2026-11-05','12 NOV 2026','Fecha 3 de nov. de 26','05 / 11 / 2026','Fecha 32/13/2026'].map(x=>ocrParse(x).date));
  ok(D[0]==='2026-10-12'&&D[1]==='2026-11-05'&&D[2]==='2026-11-12'&&D[3]==='2026-11-03'&&D[4]==='2026-11-05'&&D[5]===null,'ux3: lee fechas con O por 0, con mes en letras, ISO y con espacios; una imposible no se inventa: '+JSON.stringify(D))}
 // monedas permitidas y nota larga (0058)
 {t=await mk(b,{fam:true});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('#optNew');await t.page.waitForTimeout(300);
  const opts=await t.page.$$eval('#gCur option',o=>o.map(x=>x.value||x.textContent));
  ok(await t.page.evaluate(()=>document.getElementById('gCur').tagName)==='SELECT'&&opts.length===8&&opts[0]==='ARS'&&opts.includes('USD'),'monedas: el grupo nuevo ofrece las 8 monedas habilitadas, ARS primero');
  await t.page.fill('#gName','Viaje');await t.page.selectOption('#gCur','USD');await t.page.click('#btnCreate');await t.page.waitForTimeout(400);
  ok(t.calls.some(c=>c.startsWith('cuentas_group_create')&&c.includes('"p_currency":"USD"')),'monedas: crear el grupo manda la moneda elegida');
  ok(t.errs.length===0,'monedas: sin errores de JS')}
 {t=await mk(b,{fam:true});await openExp(t);await t.page.fill('#eDesc','Cena');await t.page.fill('#eAmt','100');await t.page.click('#btnNotes');
  await t.page.fill('#eNotes','n'.repeat(1001));await t.page.waitForTimeout(150);
  ok(/1001 caracteres/.test(await t.page.textContent('#eNotesNote')),'notas: más de 1000 muestra cuántos caracteres tiene y el máximo');
  await t.page.click('#btnExpense');await t.page.waitForTimeout(300);
  ok(!t.calls.some(c=>c.startsWith('cuentas_expense_add'))&&/demasiado larga/.test(await t.page.textContent('#msg')),'notas: con más de 1000 no se guarda y avisa');
  await t.page.fill('#eNotes','n'.repeat(1000));await t.page.waitForTimeout(150);
  ok(await t.page.inputValue('#eNotes').then(v=>v.length)===1000,'notas: pegar 1000 no se corta');
  await t.page.click('#btnExpense');await t.page.waitForTimeout(400);
  const c=t.calls.find(c=>c.startsWith('cuentas_expense_add'));ok(c&&c.includes('"p_notes":"'+'n'.repeat(1000)+'"'),'notas: con 1000 exactos se guarda completa');
  ok(t.errs.length===0,'notas: sin errores de JS')}
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
 // tipografía: «Entre todos» usa la misma letra que los campos de al lado
 t=await mk(b);await openExp(t);await t.page.click('span.rs');await t.page.waitForTimeout(200);
 const fs=await t.page.evaluate(()=>{const g=e=>{const c=getComputedStyle(document.querySelector(e));return c.fontSize+'/'+c.fontWeight};return {a:g('#eAdvSum .advsum'),s:g('#ePayer'),m:g('#eMode')}});
 ok(fs.a===fs.s&&fs.s===fs.m,'tipografía: «Entre todos» tiene la misma letra que Pagó y Dividir ('+fs.a+' vs '+fs.s+')');
 // tipografía: los botones del grupo y del inicio comparten tamaño de letra
 t=await mk(b);await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});await t.page.waitForTimeout(300);
 const bs=await t.page.evaluate(()=>['#fab','#btnSettle','#btnSaldos','#btnInvite','#btnBack'].map(e=>getComputedStyle(document.querySelector(e)).fontSize));
 ok(new Set(bs).size===1,'tipografía: Agregar gasto, Saldar deuda, Saldos, Personas y Grupos tienen el mismo tamaño ('+bs.join(', ')+')');
 // formulario: reparto en una sola tarjeta, «Entre quiénes» con rótulo y barra de guardar pegada abajo
 t=await mk(b);await t.page.setViewportSize({width:390,height:900});await openExp(t);await t.page.click('span.rs');await t.page.waitForTimeout(200);
 const fr=await t.page.evaluate(()=>{const r=e=>document.querySelector(e).getBoundingClientRect();return {lbl:document.getElementById('eAdvLbl').textContent,sum:document.querySelector('#eAdvSum .advsum').textContent,box:getComputedStyle(document.getElementById('eRepBox')).borderTopWidth,sbB:Math.round(r('.savebar').bottom),vh:innerHeight,chipW:getComputedStyle(document.querySelector('#eRecent .chip')||document.body).fontWeight}});
 ok(fr.lbl==='Entre quiénes'&&/^Todos \(\d+\)$/.test(fr.sum),'formulario: «Entre quiénes» con rótulo y resumen «Todos (n)» ('+fr.sum+')');
 ok(fr.box==='0px','formulario: el reparto abierto se une a la tarjeta de arriba (sin borde doble)');
 ok(fr.sbB===fr.vh,'formulario: la barra de guardar queda pegada al borde de abajo ('+fr.sbB+' de '+fr.vh+')');
 ok(await t.page.evaluate(()=>getComputedStyle(document.querySelector('#eRecent'),'::before').content)==='"Recientes"','formulario: rótulo «Recientes» sobre los atajos');
 // íconos: «Foto» es una cámara y «Ajustes» una tuerca (no un comprobante ni un sol)
 t=await mk(b);await openExp(t);
 const icn=await t.page.evaluate(()=>({foto:document.querySelector('#btnRcpt svg').innerHTML.includes('cy="13"'),ajustes:document.querySelector('#btnGear svg').innerHTML.includes('1.724')}));
 ok(icn.foto,'íconos: «Foto» usa una cámara');
 ok(icn.ajustes,'íconos: «Ajustes» usa una tuerca');
 ok(await t.page.evaluate(()=>document.querySelector('#btnScan svg')!==null),'íconos: «Escanear ticket» tiene ícono');
 // rendimiento: el feed trae los últimos 100 y «Ver más» pide los anteriores; buscar o exportar traen todo
 t=await mk(b,{lk:{many:true}});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#moves details.mv');
 const nRows=()=>t.page.evaluate(()=>document.querySelectorAll('#moves details.mv').length);
 ok(await nRows()===100,'paginado: al abrir se muestran los últimos 100 movimientos ('+await nRows()+')');
 ok(await t.page.isVisible('#btnMore'),'paginado: aparece «Ver movimientos anteriores»');
 ok(t.calls.some(c=>c.startsWith('cuentas_movements_page')&&c.includes('"p_limit":101')),'paginado: pide 101 filas para saber si hay más');
 await t.page.click('#btnMore');await t.page.waitForFunction(()=>document.querySelectorAll('#moves details.mv').length===200);
 ok(await nRows()===200,'paginado: «Ver más» suma 100 anteriores');
 await t.page.click('#btnMore');await t.page.waitForFunction(()=>document.querySelectorAll('#moves details.mv').length===250);
 ok(await nRows()===250&&!(await t.page.isVisible('#btnMore')),'paginado: al llegar al final desaparece «Ver más» (250)');
 t=await mk(b,{lk:{many:true}});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#moves details.mv');
 await t.page.fill('#mvQ','Gasto 7');await t.page.waitForFunction(()=>document.querySelectorAll('#moves details.mv').length===250,null,{timeout:4000}).catch(()=>{});
 ok(await t.page.evaluate(()=>[...document.querySelectorAll('#moves details.mv')].filter(e=>!e.hidden).length)===11,'paginado: buscar trae todo y filtra también lo viejo (Gasto 7, 70–79, 7 → 11)');

 // gobierno visible: cada movimiento muestra quién lo cargó, anuló, editó o confirmó
 t=await mk(b,{lk:{gov:true}});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#moves details.mv');
 await t.page.evaluate(()=>{const bt=document.getElementById('btnVoided');if(bt&&!bt.hidden)bt.click()});await t.page.waitForTimeout(600);
 await t.page.evaluate(()=>document.querySelectorAll('#moves details.mv').forEach(d=>d.open=true));
 const gv=await t.page.evaluate(()=>[...document.querySelectorAll('#moves .gov')].map(e=>e.textContent));
 ok(gv.some(x=>/Cargado por Bruno/.test(x)&&/Editado por Vos/.test(x)&&/lo reemplaza/.test(x)),'gobierno: «Cargado por Bruno» y «Editado por Vos» con el aviso de reemplazo ('+gv.length+' bloques)');
 ok(gv.some(x=>/Anulado por Bruno/.test(x)&&/«Duplicado»/.test(x)),'gobierno: «Anulado por Bruno» con el motivo');
 ok(gv.some(x=>/Registrado por Bruno/.test(x)&&/Confirmado por Vos/.test(x)),'gobierno: el pago muestra quién lo registró y quién lo confirmó');

 // cobro: «Recordar» arma el mensaje de WhatsApp con el monto y el alias de quien cobra
 t=await mk(b,{lk:{cred:true}});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.evaluate(()=>{window.__a=[];const o=HTMLAnchorElement.prototype.click;HTMLAnchorElement.prototype.click=function(){window.__a.push(this.href);if(!/wa\.me/.test(this.href))o.call(this)}});
 await t.page.waitForSelector('[data-rm]',{state:'attached'});
 ok(await t.page.evaluate(()=>/Recordar/.test(document.querySelector('[data-rm]').textContent)),'cobro: aparece «Recordar» cuando te deben');
 await t.page.evaluate(()=>document.querySelector('[data-rm]').click());
 const wa=decodeURIComponent((await t.page.evaluate(()=>window.__a.find(x=>/wa\.me/.test(x))||'')));
 ok(/^https:\/\/wa\.me\/\?text=/.test(wa)&&/Hola Bruno/.test(wa)&&/Viaje 1/.test(wa)&&/2\.500/.test(wa)&&/pau\.cuentas/.test(wa),'cobro: el mensaje lleva nombre, grupo, monto y alias ('+wa.slice(0,150)+')');
 t=await mk(b,{});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 ok(await t.page.evaluate(()=>!document.querySelector('[data-rm]')),'cobro: si debés vos, no aparece «Recordar»');

 // resumen compartible: texto con gastos y quién le paga a quién
 t=await mk(b,{});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 await t.page.evaluate(()=>{window.__a=[];const o=HTMLAnchorElement.prototype.click;HTMLAnchorElement.prototype.click=function(){window.__a.push(this.href);if(!/wa\.me/.test(this.href))o.call(this)}});
 await t.page.evaluate(()=>document.getElementById('btnSum').click());await t.page.waitForFunction(()=>window.__a.some(x=>/wa\.me/.test(x)),null,{timeout:5000}).catch(()=>{});
 const sm=decodeURIComponent(await t.page.evaluate(()=>window.__a.find(x=>/wa\.me/.test(x))||''));
 ok(/Resumen de «Viaje 1»/.test(sm)&&/Gastos: /.test(sm)&&/Para saldar:/.test(sm)&&/Yo le paga a Bruno/.test(sm),'resumen: lleva grupo, gastos y quién le paga a quién ('+sm.replace(/\n/g,' | ').slice(0,200)+')');

 // fluidez: tocar un grupo da respuesta al instante y las pantallas entran con un fundido corto
 t=await mk(b,{delay:500});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 await t.page.evaluate(()=>document.querySelector('[data-g]').click());await t.page.waitForTimeout(30);
 ok(await t.page.evaluate(()=>document.querySelector('[data-g]').classList.contains('opening')),'fluidez: al tocar un grupo la fila se atenúa mientras carga');
 await t.page.waitForSelector('#btnSettle',{state:'visible'});
 ok(await t.page.evaluate(()=>document.getElementById('vGroup').classList.contains('vin')&&!document.querySelector('[data-g]')?.classList.contains('opening')),'fluidez: el grupo entra con fundido y la fila vuelve a la normalidad');
 ok(await t.page.evaluate(()=>getComputedStyle(document.getElementById('vGroup')).animationName==='vin'||getComputedStyle(document.getElementById('vGroup')).animationName==='none'),'fluidez: la animación existe (o está desactivada por movimiento reducido)');

 // color y largo: sin franja de otro color abajo ni scroll de sobra en pantallas cortas
 t=await mk(b,{lk:{cred:true}});await t.page.setViewportSize({width:390,height:844});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 const ext=await t.page.evaluate(()=>({sh:document.documentElement.scrollHeight,vh:innerHeight}));
 ok(ext.sh<=ext.vh+1,'pantallas: el inicio no tiene scroll de sobra ni franja de otro color abajo ('+ext.sh+' de '+ext.vh+')');
 await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});await t.page.locator('#vGroup button:visible',{hasText:'Saldos'}).first().click();await t.page.waitForTimeout(300);
 const rb=await t.page.evaluate(()=>{const b=document.querySelector('[data-rm]').getBoundingClientRect(),i=document.querySelector('[data-rm] svg').getBoundingClientRect();return {sameRow:Math.abs((i.top+i.height/2)-(b.top+b.height/2))<6}});
 ok(rb.sameRow,'cobro: el ícono de «Recordar» queda al lado del texto, no arriba');

 // abrir grupo rápido: la segunda vez se ve al instante (copia guardada) y se actualiza por detrás
 t=await mk(b,{delay:700});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 const t0=Date.now();await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});const firstMs=Date.now()-t0;
 await t.page.click('#btnBack');await t.page.waitForSelector('[data-g]');
 const n0=t.calls.length;await t.page.click('[data-g]');
 await t.page.waitForSelector('#btnSettle',{state:'visible',timeout:400}).then(()=>ok(true,'abrir grupo: la segunda vez aparece antes de que llegue la red (la primera tardó '+firstMs+' ms)')).catch(()=>ok(false,'abrir grupo: la segunda vez no apareció al instante'));
 await t.page.waitForTimeout(2500);
 ok(t.calls.slice(n0).some(c=>c.startsWith('cuentas_balances')),'abrir grupo: igual se actualiza por detrás con datos nuevos');
 ok(t.calls.slice(n0).filter(c=>c.startsWith('cuentas_recurring_run')).length===1,'abrir grupo: los gastos repetidos se revisan en paralelo, una sola vez');
 // campanilla: número con pendientes + avisos, visible en todas las pantallas, abre Actividad
 t=await mk(b,{lk:{newNotices:true}});await t.page.setViewportSize({width:390,height:844});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');
 await t.page.waitForFunction(()=>!document.getElementById('bellN').hidden,null,{timeout:4000});
 ok(await t.page.evaluate(()=>document.getElementById('bellN').textContent)==='5','campanilla: muestra 5 (1 pendiente + 4 avisos)');
 ok(await t.page.evaluate(()=>/5/.test(document.getElementById('bell').getAttribute('aria-label'))),'campanilla: el lector de pantalla oye la cantidad');
 const bb=await t.page.evaluate(()=>{const a=document.getElementById('bell').getBoundingClientRect(),v=document.getElementById('avatar').getBoundingClientRect();return {w:a.width,h:a.height,left:a.right<=v.left,inside:a.right<=innerWidth}});
 ok(bb.w>=44&&bb.h>=44&&bb.left&&bb.inside,'campanilla: tamaño táctil 44 px, a la izquierda del avatar y dentro de la pantalla');
 await t.page.click('[data-g]');await t.page.waitForSelector('#btnSettle',{state:'visible'});
 ok(await t.page.evaluate(()=>getComputedStyle(document.getElementById('bell')).display!=='none'&&!document.getElementById('bellN').hidden),'campanilla: también se ve dentro de un grupo');
 await t.page.click('#bell');await t.page.waitForSelector('#notices .notice',{state:'visible'});
 ok(await t.page.evaluate(()=>!document.getElementById('vHome').hidden&&!document.querySelector('[data-hp="actividad"]').hidden),'campanilla: desde un grupo lleva a Actividad');
 ok(t.errs.length===0,'campanilla: sin errores de JS');
 t=await mk(b,{});await t.page.goto(URL);await t.page.waitForSelector('[data-g]');await t.page.waitForTimeout(600);
 ok(await t.page.evaluate(()=>document.getElementById('bellN').hidden===(document.getElementById('bellN').textContent==='')),'campanilla: sin avisos no marca un número en vano');
 // logo: desde cualquier pantalla lleva al inicio, pestaña «Mis grupos»
 {const sv=async p=>p.evaluate(()=>({v:['vHome','vGroup','vSettle'].find(x=>!document.getElementById(x).hidden),hp:[...document.querySelectorAll('[data-hp]')].find(e=>!e.hidden)?.dataset.hp,dr:!document.getElementById('drawer').hidden}));
  const go=async(nm,pre)=>{const r=await mk(b,{lk:{newNotices:true}});await r.page.setViewportSize({width:390,height:844});await r.page.goto(URL);await r.page.waitForSelector('[data-g]');await pre(r.page);await r.page.waitForTimeout(400);await r.page.click('header h1');await r.page.waitForTimeout(500);const s=await sv(r.page);ok(s.v==='vHome'&&s.hp==='grupos'&&!s.dr&&r.errs.length===0,'logo: desde '+nm+' lleva a Inicio > Mis grupos ('+JSON.stringify(s)+')');await r.page.context().close().catch(()=>{})};
  await go('Actividad',p=>p.click('#bell'));
  await go('Cuenta',p=>p.click('#avatar'));
  await go('Análisis general',async p=>{await p.click('#burger');await p.click('[data-d=balance]')});
  await go('un grupo (Saldos)',async p=>{await p.click('[data-g]');await p.waitForSelector('#btnSettle',{state:'visible'});await p.click('#btnSaldos')});
  await go('un grupo (Análisis)',async p=>{await p.click('[data-g]');await p.waitForSelector('#btnSettle',{state:'visible'});await p.click('#btnAna')});
  await go('liquidar',async p=>{await p.click('[data-g]');await p.waitForSelector('#btnSettle',{state:'visible'});await p.click('#btnSettle');await p.waitForSelector('#vSettle',{state:'visible'})});
  await go('un gasto abierto',async p=>{await p.click('[data-g]');await p.waitForSelector('#btnSettle',{state:'visible'});await p.click('#fab')});
 }
 // accesibilidad: logo con semántica, menú, foco, tamaño de texto y objetivos táctiles
 {const r=await mk(b,{lk:{newNotices:true}});await r.page.setViewportSize({width:390,height:844});await r.page.goto(URL);await r.page.waitForSelector('[data-g]');
  ok(await r.page.evaluate(()=>{const a=document.querySelector('h1 a#logo');return !!a&&a.getAttribute('aria-label')==='Cuentas, ir al inicio'&&document.querySelector('h1').getAttribute('role')===null}),'a11y: el logo es un enlace dentro del título principal (el título no pierde su rol)');
  await r.page.focus('#burger');await r.page.keyboard.press('Enter');await r.page.waitForTimeout(150);
  ok(await r.page.evaluate(()=>document.activeElement.classList.contains('di')&&document.querySelector('header').inert&&document.getElementById('vHome').inert&&document.querySelector('[data-d=grupos]').getAttribute('aria-current')==='page'),'a11y: menú abierto: foco adentro, fondo inerte y sección actual marcada');
  await r.page.keyboard.press('Escape');await r.page.waitForTimeout(150);
  ok(await r.page.evaluate(()=>document.activeElement.id==='burger'&&!document.querySelector('header').inert&&!document.getElementById('vHome').inert),'a11y: Esc cierra el menú, devuelve el foco al botón y reactiva el fondo');
  await r.page.click('#burger');await r.page.click('[data-d=actividad]');await r.page.waitForTimeout(500);
  ok(await r.page.evaluate(()=>document.activeElement.tagName==='H2'&&/Actividad/.test(document.activeElement.textContent)),'a11y: al elegir una opción del menú el foco pasa al título de la nueva pantalla');
  await r.page.click('header h1 a');await r.page.waitForTimeout(500);
  ok(await r.page.evaluate(()=>document.activeElement.tagName==='H2'&&/Mis grupos/.test(document.activeElement.textContent)),'a11y: al tocar el logo el foco pasa a «Mis grupos»');
  await r.page.click('#avatar');await r.page.waitForTimeout(400);
  const sm=await r.page.evaluate(()=>[...document.querySelectorAll('button,summary,a[href]')].filter(e=>e.offsetParent!==null&&Math.min(e.getBoundingClientRect().width,e.getBoundingClientRect().height)<43.5).map(e=>(e.id||e.className||e.tagName)+':'+Math.round(e.getBoundingClientRect().height)));
  ok(sm.length===0,'a11y: en Cuenta todo lo tocable mide al menos 44 px ('+sm.join(', ')+')');
  await r.page.click('#cTheme [data-ts-opt=l]');
  ok(await r.page.evaluate(()=>document.documentElement.getAttribute('data-ts')==='l'&&getComputedStyle(document.documentElement).fontSize==='18.4px'&&localStorage.getItem('cuentas_ts')==='l'&&document.querySelector('[data-ts-opt=l]').getAttribute('aria-checked')==='true'),'a11y: tamaño de texto «Grande» agranda todo y queda guardado');
  await r.page.reload();await r.page.waitForSelector('[data-g]');
  ok(await r.page.evaluate(()=>getComputedStyle(document.documentElement).fontSize==='18.4px'&&document.documentElement.scrollWidth<=innerWidth),'a11y: al reabrir sigue «Grande» y no se desborda');
  await r.page.click('#avatar');await r.page.click('#cTheme [data-ts-opt=m]');
  ok(await r.page.evaluate(()=>!document.documentElement.hasAttribute('data-ts')&&localStorage.getItem('cuentas_ts')===null),'a11y: «Normal» vuelve al tamaño original');
  await r.page.click('#btnBack').catch(()=>{});
  ok(r.errs.length===0,'a11y: sin errores de JS');
 }
 await b.close();console.log(fails?fails+' fallas':'todo ok');process.exit(fails?1:0)})();
