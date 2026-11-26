const fields=[['number','Complete List Number','1*700003'],['name','Display Name','Sample Woodshop'],['plan','Listing type',['business','10E']],['rta','RTA Y/N',['N','Y']],['website','Website','https://example.test/workshop'],['phone','Registration phone',['+12025550101','+12025550102']],['text','Text number (optional)',['','+12025550101','+12025550102']],['video','Video reference (optional)',''],...Array.from({length:4},(_,i)=>['social'+(i+1),'Social link '+(i+1)+' (optional)',''])];
const el=id=>document.getElementById(id);let approved=false, generation=0, revision=0, saving=false;
for(const [id,label,value] of fields){const row=document.createElement('div');row.className='cell';const l=document.createElement('label');l.htmlFor=id;l.textContent=label;const input=document.createElement(Array.isArray(value)?'select':'input');input.id=id;input.name=id;if(Array.isArray(value))for(const v of value){const o=document.createElement('option');o.value=v;o.textContent=v||'None';input.append(o)}else input.value=value;input.setAttribute('aria-describedby','error-'+id);const err=document.createElement('span');err.id='error-'+id;err.className='error';row.append(l,input,err);el('fields').append(row)}
function data(){return Object.fromEntries([...fields.map(([id])=>[id,el(id).value]),['ack',el('ack').checked]])}
function errors(values){for(const [id] of fields){el('error-'+id).textContent=values[id]||'';el(id).setAttribute('aria-invalid',String(!!values[id]))}el('error-ack').textContent=values.ack||'';if(values.form)el('status').textContent=values.form}
async function request(path,body){const r=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});return [r.status,await r.json()]}
async function validate(){const seq=++generation;try{const [,v]=await request('/api/validate',data());if(seq===generation)errors(v.errors)}catch{if(seq===generation)el('status').textContent='Local validation unavailable. No permission or phone verification has occurred.'}}
function edited(){
 ++generation; ++revision;
 errors({});
 approved=false;
 el('approval').textContent='Approval not simulated yet.';
}
for(const id of [...fields.map(([id])=>id),'ack']){
 el(id).addEventListener('input',edited);
 el(id).addEventListener('change',()=>{edited();validate()});
}
// Independent browser-only demonstration, never an authorization result.
function resetPhoneResult(){
 el('phone-result').textContent='Possession not simulated. Line classification pending. Account eligibility pending; no 10E entitlement or activation.';
}
el('phone').addEventListener('input',resetPhoneResult);
el('phone').addEventListener('change',resetPhoneResult);
el('simulate-possession').onclick=()=>{
 const classification=el('phone').value==='+12025550101'?'unknown':'unavailable';
 el('phone-result').textContent='SIMULATED possession challenge passed for '+el('phone').value+'. Line classification: '+classification+'. Account eligibility pending; no 10E entitlement or activation. No real possession verified.';
};
el('approve').onclick=()=>{approved=el('pin').value==='2468';el('pin').value='';el('approval').textContent=approved?'Demo challenge passed. Permission and phone are still unverified.':'Demo challenge failed. Use only the displayed sample code.'};
async function rows(){const r=await fetch('/api/rows');if(!r.ok)throw Error();const data=await r.json();el('rows').replaceChildren();for(const row of data){const d=document.createElement('div');d.className='record';const title=document.createElement('b');title.textContent=row.number+' · '+row.name;const state=document.createElement('span');state.textContent=row.state.replaceAll('_',' ');d.append(title,state);el('rows').append(d)}}
el('sheet').onsubmit=async e=>{
 e.preventDefault();if(saving)return;
 saving=true;el('save').disabled=true;++generation;
 const submitted=data(), submittedRevision=revision;
 try{
  const [status,v]=await request('/api/save',{...submitted,simulated_approval:approved});
  const unchanged=submittedRevision===revision;
  if(unchanged)errors(v.errors||{});
  if(status===201){
   el('status').textContent=submitted.number+': '+v.message;
   if(unchanged){approved=false;el('approval').textContent='Approval not simulated yet.'}
   try{await rows()}catch{
    el('status').textContent=submitted.number+': saved, but worksheet refresh failed. Reload to see the saved row; do not resubmit it.';
   }
  }else{
   el('status').textContent=submitted.number+': not saved. '+(unchanged?'Review the marked cells.':'The result belongs to the earlier submission; your current edits are retained.')+' All verification remains simulated.';
   if(unchanged){const field=Object.keys(v.errors||{}).find(k=>el(k));if(field)el(field).focus()}
  }
 }catch{
  el('status').textContent=submitted.number+': local save unavailable. Outcome unknown: reload the worksheet before retrying. Current edits are retained.';
 }finally{saving=false;el('save').disabled=false}
};
rows().catch(()=>el('status').textContent='Local worksheet unavailable. Nothing can be published.');
