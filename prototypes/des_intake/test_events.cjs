// Actual app.js executed with a small DOM/event fixture, not browser evidence.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
function setup(){
 const nodes=new Map(), pending=[];
 class Element{
  constructor(){this.value='';this.textContent='';this.checked=false;this.attrs={};this.listeners={};this.children=[];}
  set id(value){this._id=value;nodes.set(value,this)} get id(){return this._id}
  append(...values){this.children.push(...values)} replaceChildren(){this.children=[]}
  setAttribute(k,v){this.attrs[k]=v} addEventListener(k,fn){(this.listeners[k]??=[]).push(fn)}
  emit(k){for(const fn of this.listeners[k]||[])fn({target:this})} focus(){this.focused=true}
 }
 const get=id=>{if(!nodes.has(id)){const n=new Element();n.id=id}return nodes.get(id)};
 const fetch=(url,opts)=>{if(url==='/api/rows')return Promise.resolve({ok:true,json:async()=>[]});return new Promise(resolve=>pending.push({url,body:JSON.parse(opts.body),reply:(status,data)=>resolve({status,json:async()=>data})}))};
 vm.runInNewContext(fs.readFileSync(path.join(__dirname,'web/app.js'),'utf8'),{document:{getElementById:get,createElement:()=>new Element()},fetch});
 return {get,pending,edit(value){get('number').value=value;get('number').emit('input')},approve(){get('pin').value='2468';get('approve').onclick()},submit(){return get('sheet').onsubmit({preventDefault(){}})}};
}
const flush=()=>new Promise(r=>setImmediate(r));
test('input before change invalidates delayed occupied response and approval',async()=>{
 const h=setup();h.edit('1*700001');h.get('number').emit('change');h.approve();
 h.get('error-number').textContent='Old error';h.get('number').setAttribute('aria-invalid','true');
 h.edit('81*700001');
 assert.equal(h.get('error-number').textContent,'');assert.equal(h.get('number').attrs['aria-invalid'],'false');
 assert.match(h.get('approval').textContent,/not simulated/);
 h.pending[0].reply(200,{errors:{number:'Occupied'}});await flush();
 assert.equal(h.get('error-number').textContent,'');
 const submit=h.submit();assert.equal(h.pending[1].body.simulated_approval,false);
 h.pending[1].reply(422,{errors:{form:'Complete simulated approval'}});await submit;
});
test('stale save failure stays visible without invalidating or focusing new input',async()=>{
 const h=setup();h.edit('1*700001');h.approve();const save=h.submit();
 h.edit('81*700001');h.pending[0].reply(409,{errors:{number:'Occupied'}});await save;
 assert.equal(h.get('number').value,'81*700001');assert.equal(h.get('error-number').textContent,'');
 assert.equal(h.get('number').focused,undefined);assert.match(h.get('status').textContent,/1\*700001/);assert.match(h.get('status').textContent,/not saved/i);
});
test('successful old save reports original identity, preserves edits and blocks duplicate submit',async()=>{
 const h=setup();h.edit('1*529');h.approve();const save=h.submit();await h.submit();assert.equal(h.pending.length,1);
 h.edit('81*529');h.pending[0].reply(201,{message:'Synthetic draft saved.'});await save;
 assert.equal(h.get('number').value,'81*529');assert.match(h.get('status').textContent,/1\*529/);assert.match(h.get('status').textContent,/saved/);
 assert.equal(h.get('save').disabled,false);
});
test('unchanged save errors remain actionable; acknowledgment also invalidates feedback',async()=>{
 const h=setup();const save=h.submit();h.pending[0].reply(422,{errors:{number:'Occupied'}});await save;
 assert.equal(h.get('error-number').textContent,'Occupied');assert.equal(h.get('number').focused,true);
 h.approve();h.get('ack').checked=true;h.get('ack').emit('input');assert.equal(h.get('error-number').textContent,'');assert.match(h.get('approval').textContent,/not simulated/);
});
test('new validation wins even when old validation arrives last',async()=>{
 const h=setup();h.edit('1*700001');h.get('number').emit('change');
 h.edit('81*700001');h.get('number').emit('change');
 h.pending[1].reply(200,{errors:{name:'Current name error'}});await flush();
 h.pending[0].reply(200,{errors:{number:'Old occupied result'}});await flush();
 assert.equal(h.get('error-number').textContent,'');assert.equal(h.get('error-name').textContent,'Current name error');
});
test('simulated possession is distinct from eligibility and invalidated by phone edit',async()=>{
 const h=setup();h.get('phone').value='+12025550101';h.get('plan').value='10E';
 h.get('simulate-possession').onclick();
 assert.match(h.get('phone-result').textContent,/SIMULATED possession challenge passed/);
 assert.match(h.get('phone-result').textContent,/classification: unknown/);
 assert.match(h.get('phone-result').textContent,/eligibility pending; no 10E entitlement or activation/);
 h.approve();h.get('phone').value='+12025550102';h.get('phone').emit('input');
 assert.match(h.get('phone-result').textContent,/Possession not simulated/);
 assert.match(h.get('approval').textContent,/not simulated/);
 h.get('simulate-possession').onclick();assert.match(h.get('phone-result').textContent,/classification: unavailable/);
 h.approve();const save=h.submit();
 assert.equal(h.pending[0].body.phone,'+12025550102');
 assert.equal(h.pending[0].body.possession,undefined);assert.equal(h.pending[0].body.pin,undefined);
 h.pending[0].reply(201,{message:'Synthetic draft saved. Phone verification remains pending.'});await save;
 assert.match(h.get('status').textContent,/pending/);
});
