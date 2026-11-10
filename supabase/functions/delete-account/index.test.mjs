import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const source=readFileSync(process.env.LIFTRIVALS_DELETE_ACCOUNT_SOURCE || new URL('./index.ts',import.meta.url),'utf8');
const script=stripTypeScriptTypes(source.replace(/^import .*;\n/gm,''));
const owner='a1111111-1111-4111-8111-111111111111';

function deletion({path=null,signedIn=true,cleanupError=false,profileError=false,apple=false}={}) {
  let handler;const calls=[];
  const userClient={auth:{getUser:async()=>({data:{user:signedIn?{id:owner,identities:apple?[{provider:'apple',identity_data:{sub:'apple-owner'}}]:[]}:null},error:null})}};
  const admin={from(table){const query={select(){return query;},eq(key,value){assert.equal(value,owner);return query;},maybeSingle:async()=>({data:{avatar_path:path},error:profileError?new Error('read failed'):null}),then(resolve,reject){return Promise.resolve({data:[],error:null}).then(resolve,reject);}};return query;},storage:{from(bucket){return{list:async()=>({data:[],error:null}),remove:async paths=>{calls.push({bucket,paths:Array.from(paths)});return{error:cleanupError?new Error('storage unavailable'):null};}};}},auth:{admin:{deleteUser:async id=>{calls.push({deleteUser:id});return{error:null};}}}};
  vm.runInNewContext(script,{
    Deno:{env:{get:key=>({SUPABASE_URL:'https://example.invalid',SUPABASE_ANON_KEY:'public-test',SUPABASE_SERVICE_ROLE_KEY:'server-test-only'})[key]},serve:fn=>{handler=fn;}},
    createClient:(url,key)=>key==='public-test'?userClient:admin,createRemoteJWKSet:()=>({}),URL,URLSearchParams,Request,Response,atob,
  });
  const request=({method='POST',body='{}',iat=Date.now()/1000,origin='https://liftrivals.com'}={})=>new Request('https://example.invalid/delete-account',{method,headers:{Authorization:`Bearer test.${Buffer.from(JSON.stringify({iat})).toString('base64url')}.test`,Origin:origin},...(method==='POST'?{body}:{})});
  return{calls,run:options=>handler(request(options))};
}

test('account deletion cleans interrupted fixed-path photos even without a profile pointer',async()=>{
  const fixture=deletion();const response=await fixture.run();assert.equal(response.status,204);
  assert.deepEqual(fixture.calls[0],{bucket:'profile-avatars',paths:[`${owner}/avatar/avatar-full.jpg`,`${owner}/avatar/avatar-thumb.jpg`]});
  assert.deepEqual(fixture.calls.at(-1),{deleteUser:owner});
});

test('account deletion cannot follow owner-controlled foreign or traversal photo pointers',async()=>{
  for(const path of ['b1111111-1111-4111-8111-111111111111/avatar',`${owner}-other/avatar`,`${owner}/../foreign/avatar`,`${owner}/./avatar`,`${owner}/%2e%2e/foreign`,`${owner}/a//b`,`${owner}/a\\b`,`${owner}/avatar?path=foreign`]) {
    const fixture=deletion({path});assert.equal((await fixture.run()).status,204);
    assert.deepEqual(fixture.calls[0].paths,[`${owner}/avatar/avatar-full.jpg`,`${owner}/avatar/avatar-thumb.jpg`],path);
  }
});

test('account deletion accepts safe own legacy paths without duplicating the canonical path',async()=>{
  for(const path of [`${owner}/avatar`,`${owner}/legacy/photo-1`]) {
    const fixture=deletion({path});assert.equal((await fixture.run()).status,204);
    const paths=fixture.calls[0].paths;assert.equal(new Set(paths).size,paths.length);
    assert.ok(paths.every(key=>key.startsWith(`${owner}/`)));assert.ok(paths.includes(`${path}/avatar-full.jpg`));
  }
});

test('failed photo lookup or cleanup never proceeds to deleting the account',async()=>{
  for(const options of [{cleanupError:true},{profileError:true}]) {const fixture=deletion(options);assert.equal((await fixture.run()).status,500);assert.ok(!fixture.calls.some(call=>call.deleteUser));}
});

test('existing authentication, recency, method and CORS gates remain intact',async()=>{
  const anonymous=deletion({signedIn:false});assert.equal((await anonymous.run()).status,401);assert.equal(anonymous.calls.length,0);
  const stale=deletion();assert.equal((await stale.run({iat:Date.now()/1000-601})).status,403);assert.equal(stale.calls.length,0);
  const method=deletion();assert.equal((await method.run({method:'GET'})).status,405);assert.equal(method.calls.length,0);
  const preflight=await method.run({method:'OPTIONS'});assert.equal(preflight.status,204);assert.equal(preflight.headers.get('Access-Control-Allow-Origin'),'https://liftrivals.com');
  assert.equal((await method.run({method:'OPTIONS',origin:'https://other.invalid'})).headers.get('Access-Control-Allow-Origin'),null);
});

if(source.includes('appleAuthorizationCode')) test('deployed Apple identity/configuration failures still stop before data cleanup',async()=>{
  const unlinked=deletion();assert.equal((await unlinked.run({body:JSON.stringify({appleAuthorizationCode:'test-code'})})).status,403);assert.equal(unlinked.calls.length,0);
  const missingConfig=deletion({apple:true});assert.equal((await missingConfig.run({body:JSON.stringify({appleAuthorizationCode:'test-code'})})).status,503);assert.equal(missingConfig.calls.length,0);
});
