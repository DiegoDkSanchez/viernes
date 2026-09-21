import {readFileSync} from 'node:fs';
import {before, after, test} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, setDoc, updateDoc, getDoc, getDocs, collection, query, where, orderBy, serverTimestamp, Timestamp, deleteDoc} from 'firebase/firestore';
let env;
const root = 'shops/main/';
const auth = uid => env.authenticatedContext(uid, {name: uid, firebase: {sign_in_provider:'google.com'}}).firestore();
const order = () => ({name:'Customer',address:'123 Street',creatorId:'alice',creatorName:'alice',status:'pending',createdAt:serverTimestamp(),deliveredAt:null,totalCents:550,lines:[{itemId:'burger',name:'Burger',priceCents:550,quantity:1,options:['Cheese']}]});
const menu = () => ({name:'Burger',priceCents:550,options:['Cheese'],active:true});
before(async () => {
 env = await initializeTestEnvironment({projectId:'demo-viernes',firestore:{rules:readFileSync('../../firestore.rules','utf8'),host:'127.0.0.1',port:8080}});
});
after(async()=>{await env.cleanup()});
test('Google users share orders without membership; signed-out clients denied',async()=>{
 const a=auth('alice'), b=auth('bob');
 await assertSucceeds(setDoc(doc(a,root+'orders/shared'),order()));
 await assertSucceeds(getDoc(doc(b,root+'orders/shared')));
 await assertSucceeds(getDocs(query(collection(b,root+'orders'),where('status','==','pending'),orderBy('createdAt','desc'))));
 for(const db of [env.unauthenticatedContext().firestore(),env.authenticatedContext('password-user', {firebase: {sign_in_provider:'password'}}).firestore()]) {
  await assertFails(getDocs(collection(db,root+'orders')));
  await assertFails(setDoc(doc(db,root+'orders/no'),order()));
 }
 await assertFails(setDoc(doc(auth('outsider'),root+'members/outsider'),{}));
 await assertFails(getDoc(doc(b,root+'members/alice')));
 await assertFails(setDoc(doc(env.authenticatedContext('alice').firestore(),root+'menu/no'),menu()));
});
test('delivery and reopen preserve immutable fields',async()=>{
 const ref=doc(auth('alice'),root+'orders/transitions'); await setDoc(ref,order());
 await assertSucceeds(updateDoc(ref,{status:'delivered',deliveredAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(doc(auth('bob'),root+'orders/transitions'),{status:'pending',deliveredAt:null}));
 for(const change of [{creatorId:'bob'},{creatorName:'bob'},{createdAt:serverTimestamp()},{address:'x'.repeat(301)},{extra:'bad'},{status:'bad'},{status:'delivered',deliveredAt:Timestamp.fromMillis(0)},{totalCents:-1}]) await assertFails(updateDoc(ref,change));
 await assertSucceeds(updateDoc(doc(auth('new-user'),root+'orders/transitions'),{name:'Updated customer',address:'456 Street',lines:[{...order().lines[0],quantity:2}],totalCents:1100}));
 await assertFails(deleteDoc(doc(env.unauthenticatedContext().firestore(),root+'orders/transitions')));
 await assertSucceeds(deleteDoc(doc(auth('new-user'),root+'orders/transitions')));
});
test('reject malformed orders, nested values, totals and forged identities',async()=>{
 const db=auth('alice'); let i=0;
 const invalid=[{creatorId:'bob'},{creatorName:'bob'},{name:5},{name:''},{address:'x'.repeat(301)},{extra:'bad'},{createdAt:Timestamp.fromMillis(0)},{totalCents:1},{lines:[]},{lines:Array(11).fill(order().lines[0])},{lines:[{...order().lines[0],quantity:0}]},{lines:[{...order().lines[0],quantity:100}]},{lines:[{...order().lines[0],options:[42]}]},{lines:[{...order().lines[0],options:['a'.repeat(51)]}]}];
 for(const patch of invalid) await assertFails(setDoc(doc(db,root+'orders/bad'+i++),{...order(),...patch}));
 const validRef=doc(db,root+'orders/validation-update'); await setDoc(validRef,order());
 for (const patch of invalid) await assertFails(updateDoc(validRef,patch));
 const missing=order();delete missing.address;await assertFails(setDoc(doc(db,root+'orders/missing'),missing));
 const full={...order(),lines:Array(4).fill({...order().lines[0],options:['a','b','c','d','e','f','g','h']}),totalCents:2200};
 for (let n=1;n<=4;n++) { console.log('Checking maximum options with '+n+' lines'); await assertSucceeds(setDoc(doc(db,root+'orders/full'+n),{...full,lines:full.lines.slice(0,n),totalCents:550*n})); await assertSucceeds(updateDoc(doc(db,root+'orders/full'+n),{status:'delivered',deliveredAt:serverTimestamp()})); await assertSucceeds(updateDoc(doc(db,root+'orders/full'+n),{status:'pending',deliveredAt:null})); await assertSucceeds(updateDoc(doc(auth('bob'),root+'orders/full'+n),{name:'Edited maximum order'})); }
});
test('menu validates creates and updates and denies other paths',async()=>{
 const db=auth('alice'), ref=doc(db,root+'menu/burger'); await assertSucceeds(setDoc(ref,menu()));
 for(const patch of [{name:'x'.repeat(101)},{priceCents:-1},{priceCents:1.5},{options:Array(9).fill('a')},{options:['a','a']},{options:[{}]},{active:'yes'},{extra:1}]) {
   await assertFails(updateDoc(ref,patch)); await assertFails(setDoc(doc(db,root+'menu/invalid'),{...menu(),...patch}));
 }
 await assertSucceeds(updateDoc(ref,{active:false}));
 await assertFails(setDoc(doc(db,'users/alice'),{admin:true}));
 await assertFails(setDoc(doc(db,'shops/other/menu/no'),menu()));
});

test('delivery clock time supports legacy orders, ASAP and valid minutes on create/update', async () => {
 const db = auth('alice');
 const ref = doc(db, root + 'orders/delivery-time');
 await assertSucceeds(setDoc(ref, order()));
 for (const value of [null, 0, 750, 1439]) {
  await assertSucceeds(setDoc(doc(db, root + 'orders/time-' + value), {...order(), deliveryTimeMinutes: value}));
  await assertSucceeds(updateDoc(ref, {deliveryTimeMinutes: value}));
 }
 for (const value of [-1, 1440, 12.5, '12:30', true, {}, []]) {
  await assertFails(setDoc(doc(db, root + 'orders/invalid-time'), {...order(), deliveryTimeMinutes: value}));
  await assertFails(updateDoc(ref, {deliveryTimeMinutes: value}));
 }
 await assertSucceeds(updateDoc(ref, {deliveryTimeMinutes: null}));
});
