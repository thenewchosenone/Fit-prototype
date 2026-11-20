import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {stripTypeScriptTypes} from 'node:module';
import {readFileSync} from 'node:fs';
const source=stripTypeScriptTypes(readFileSync(new URL('../../supabase/functions/remove-lift-submission/index.ts',import.meta.url),'utf8').replace(/^import .*;\n/,''));
const owner='e1111111-1111-4111-8111-111111111111',lift='e2222222-2222-4222-8222-222222222222',requestID='e3333333-3333-4333-8333-333333333333';
const object=n=>({bucket_id:'lift-videos',name:`${owner}/${lift}/${n}.mp4`});
async function server({reserved={id:requestID,status:'processing',protected_record:true,storage_objects:[object(1)]},reserveError=null,finalizeError=null,storageError=null,userError=null}={}){
  const calls=[];let handler;
  const admin={rpc:async(name,args)=>{calls.push({rpc:name,args});return{name,data:name==='reserve_lift_removal'?reserved:true,error:name==='reserve_lift_removal'?reserveError:finalizeError};},from(table){const call={table};calls.push(call);return{update(value){call.update=value;return this;},eq(...args){call.eq=args;return this;},neq(...args){call.neq=args;return this;}};},storage:{from(bucket){return{remove:async paths=>{calls.push({bucket,paths});return{error:storageError};}};}}};
  vm.runInNewContext(source,{Deno:{serve:fn=>{handler=fn;},env:{get:name=>({SUPABASE_URL:'https://example.invalid',SUPABASE_ANON_KEY:'anon',SUPABASE_SERVICE_ROLE_KEY:'server-only-test'})[name]}},createClient:(url,key)=>key==='anon'?{auth:{getUser:async()=>({data:{user:userError?null:{id:owner}},error:userError})}}:admin,Response});
  const invoke=async(payload={submission_id:lift},method='POST')=>handler(new Request('https://example.invalid/remove',{method,headers:{Authorization:'Bearer test'},...(method==='POST'?{body:JSON.stringify(payload)}:{})}));
  return{calls,invoke};
}
test('removal reserves before Storage cleanup and finalization, using authenticated owner only',async()=>{
  const value=await server();const response=await value.invoke({submission_id:lift,user_id:'spoof'});assert.equal(response.status,200);assert.deepEqual(await response.json(),{status:'completed',protected_record:true});
  assert.equal(value.calls[0].rpc,'reserve_lift_removal');assert.equal(value.calls[0].args.target_owner_id,owner);assert.equal(value.calls[1].bucket,'lift-videos');assert.equal(value.calls[2].rpc,'finalize_lift_removal');assert.ok(!value.calls.some(call=>call.table));
});
test('completed replay performs no cleanup or finalization',async()=>{
  const value=await server({reserved:{id:requestID,status:'completed',protected_record:false,storage_objects:[]}});assert.equal((await value.invoke()).status,200);assert.equal(value.calls.length,1);
});
test('reserved cleanup batches large manifests without truncation',async()=>{
  const value=await server({reserved:{id:requestID,status:'processing',protected_record:true,storage_objects:Array.from({length:205},(_,n)=>object(n))}});assert.equal((await value.invoke()).status,200);assert.deepEqual(value.calls.filter(call=>call.paths).map(call=>call.paths.length),[100,100,5]);
});
test('unsafe reservation paths never reach privileged Storage.remove',async()=>{
  for(const object of [{bucket_id:'profile-avatars',name:`${owner}/${lift}/avatar`},{bucket_id:'lift-videos',name:`foreign/${lift}/video`},{bucket_id:'lift-videos',name:`${owner}/${requestID}/other-lift`},{bucket_id:'lift-videos',name:`${owner}/${lift}/../foreign`},null]){
    const value=await server({reserved:{id:requestID,status:'processing',protected_record:true,storage_objects:[object]}});assert.equal((await value.invoke()).status,409);assert.equal(value.calls.length,1);
  }
});
test('reservation errors and invalid manifests cannot start cleanup',async()=>{
  for(const [options,status] of [[{reserveError:{code:'P0002'}},404],[{reserveError:{code:'22023'}},409],[{reserved:null},500],[{reserved:{id:requestID,status:'pending',storage_objects:[]}},409]]){
    const value=await server(options);assert.equal((await value.invoke()).status,status);assert.equal(value.calls.length,1);
  }
});
test('cleanup failures retain retry state without downgrading a completed request',async()=>{
  for(const options of [{storageError:new Error('offline')},{finalizeError:new Error('pending')}]){
    const value=await server(options);assert.equal((await value.invoke()).status,500);const failure=value.calls.find(call=>call.update);assert.equal(failure.update.status,'failed');assert.deepEqual(failure.neq,['status','completed']);if(options.storageError)assert.ok(!value.calls.some(call=>call.rpc==='finalize_lift_removal'));
  }
});
test('unauthorized, malformed and unsupported requests have no cleanup side effects',async()=>{
  const noUser=await server({userError:new Error('expired')});assert.equal((await noUser.invoke()).status,401);assert.equal(noUser.calls.length,0);
  const value=await server();assert.equal((await value.invoke({submission_id:'invalid'})).status,400);assert.equal((await value.invoke({},'OPTIONS')).status,204);assert.equal((await value.invoke({},'GET')).status,405);assert.equal(value.calls.length,0);
});
