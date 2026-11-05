# feather-doors

Version 0.1.0-dev. Authoritative door domain for the Feather Framework (schema foundation)

Authoritative RedM door domain for the Feather Framework. Version `0.1.0-dev` contains a headless trusted server API and native proof adapter. Player interaction and native replication are not enabled.

Source: https://github.com/FeatherFramework/feather-doors

**Dependencies:** `feather-mysql`, `feather-core`

## Exports (call as exports['feather-doors']:Name)

**server:** `GetCapabilities()`, `GetHealth()`

## Commands (RegisterCommand)

**server:** `/DoorsAccess`, `/DoorsAccessFixture`, `/DoorsApiFixture`, `/DoorsControllerFixture`, `/DoorsEventFixture`, `/DoorsOutbox`, `/DoorsPropertyFixture`, `/DoorsSchemaSmokeTest`

## Public (table) functions

**client/native.lua:** `FeatherDoorsNative.New(port)`, `api:Inspect()`, `api:Release()`, `api:Acquire(hashes)`, `api:SetLocked(locked)`, `FeatherDoorsNative.GamePort()`

**server/access.lua:** `DoorsAccess.New(db,port,ready,binding)`, `api:Drop()`, `api:Resolve(request)`, `api:Register()`, `api:Unregister()`, `api:Context(caller,request)`

**server/authority.lua:** `DoorsAuthority.New(binding,port,ready)`, `api:Drop()`, `api:Bump(source)`, `api:Check(caller,request)`

**server/binding.lua:** `DoorsBinding.New(db,repository,port,ready)`, `api:Drop()`, `api:Read(id)`, `api:Set(caller,request)`, `api:Context(caller,request)`

**server/contract.lua:** `C.Err(code)`, `C.Ok(value)`, `C.Int(n,min,max)`, `C.Token(s,max)`, `C.Uuid(s)`, `C.Fields(t,allowed)`, `C.Canonical(value)`, `C.Validate(kind,request)`

**server/events.lua:** `E.Decode(text)`, `E.Validate(payload,name)`, `E.Matches(row,payload)`, `E.Record(tx,caller,kind,request,snapshot)`, `E.New(db,publish,ready)`, `api:Drain()`, `api:Status()`, `E.RecoverFixture(db)`, `E.DiagnoseFixture(db)`

**server/repository.lua:** `DoorsRepository.New(db,allowed,controlled)`, `api:Mutate(caller,kind,request,authoritySource)`, `api:Get(caller,request,byKey)`, `api:Find(caller,request)`, `api:List(caller,request)`, `api:Event(caller,request)`, `api:ControlGet(caller,request)`, `api:ControlFind(caller,request)`

**server/schema.lua:** `DoorsSchema.Run(db)`, `DoorsSchema.Check(db)`

**tests/events_spec.lua:** `db.query()`, `db.exec(sql)`

**tests/native_spec.lua:** `port.registered(hash)`, `port.state(hash)`, `port.ratio(hash)`, `port.add(hash)`, `port.remove(hash)`, `port.setState(hash,state)`, `port.setRatio(hash,ratio)`

**tests/repository_spec.lua:** `db.transaction(callback)`, `tx.value(sql)`, `tx.one(sql,a,b)`, `tx.query(sql,a,b,limit)`, `tx.exec(sql,...)`, `db.query()`, `db.exec(sql,eventId)`, `db.one(sql,targetId)`

**tests/schema_spec.lua:** `db.query(sql)`, `db.value(sql)`, `db.exec(sql,id,sum,status)`
