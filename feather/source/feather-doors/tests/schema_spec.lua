dofile('server/schema.lua')
local passed=0
local function check(value,label) assert(value,label); passed=passed+1 end
local function database()
    local state={rows={},tables=0,ddl=0,failDDL=nil,exceptions=false}
    local db={}
    function db.query(sql)
        if sql:find('information_schema.columns',1,true) then
            local shapes={
                feather_door_groups={door_id='char',door_key='varchar',label='varchar',manager_resource='varchar',status='varchar',locked='tinyint',revision='bigint',delegation_epoch='bigint',startup_policy='varchar',created_at='timestamp',updated_at='timestamp'},
                feather_door_leaves={door_hash='bigint',door_id='char',model_hash='bigint',x='double',y='double',z='double',ordinal='tinyint'},
                feather_door_schema_migrations={id='varchar',checksum='varchar',status='varchar',applied_at='timestamp'},
                feather_door_operations={source_resource='varchar',request_id='varchar',request_json='longtext',result_json='longtext',created_at='timestamp'},
                feather_door_outbox={event_id='char',door_id='char',source_resource='varchar',request_id='varchar',event_type='varchar',revision='bigint',payload_json='longtext',status='varchar',attempts='int',available_at='timestamp',created_at='timestamp',published_at='timestamp'}
                ,feather_door_bindings={door_id='char',mode='varchar',link_id='char',property_id='char',property_epoch='bigint',property_status='varchar'}
            }
            local rows={}
            for tableName,columns in pairs(shapes) do
                for name,kind in pairs(columns) do
                    if name~=state.missingColumn then
                        rows[#rows+1]={tableName=tableName,columnName=name,dataType=state.badType and 'unknown' or kind}
                    end
                end
            end
            return rows
        end
        return state.rows
    end
    function db.value(sql)
        if sql:find("engine='InnoDB'",1,true) then return state.tables+1 end
        if sql:find("IN ('feather_door_operations')",1,true) then return state.operations and 1 or 0 end
        if sql:find("IN ('feather_door_outbox')",1,true) then return state.outbox and 1 or 0 end
        if sql:find("IN ('feather_door_bindings')",1,true) then return state.bindings and 1 or 0 end
        return state.tables
    end
    function db.exec(sql,id,sum,status)
        if state.exceptions then error('database unavailable') end
        if sql:find('INSERT INTO',1,true) then
            state.rows[#state.rows+1]={id=id,checksum=sum,status=status}
        elseif sql:match('^UPDATE') then
            for _,row in ipairs(state.rows) do if row.id==id then row.status='applied' end end
        elseif sql:find('CREATE TABLE IF NOT EXISTS `feather_door_groups`',1,true) then
            state.ddl=state.ddl+1; state.tables=math.max(state.tables,1)
            if state.failDDL==1 then error('process interrupted after first DDL') end
        elseif sql:find('CREATE TABLE IF NOT EXISTS `feather_door_leaves`',1,true) then
            state.ddl=state.ddl+1; state.tables=2
            if state.failDDL==2 then error('lost reply after second DDL') end
        elseif sql:find('CREATE TABLE IF NOT EXISTS `feather_door_operations`',1,true) then
            state.ddl=state.ddl+1; state.tables=3; state.operations=true
        elseif sql:find('CREATE TABLE IF NOT EXISTS `feather_door_outbox`',1,true) then
            state.ddl=state.ddl+1; state.tables=4; state.outbox=true
            if state.failDDL==3 then error('lost reply after outbox DDL') end
        elseif sql:find('CREATE TABLE IF NOT EXISTS `feather_door_bindings`',1,true) then
            state.ddl=state.ddl+1;state.tables=5;state.bindings=true
            if state.failDDL==4 then error('lost reply after binding DDL') end
        end
    end
    return db,state
end
local db,state=database()
local result=DoorsSchema.Run(db)
check(result.ok and result.value.applied==4 and result.value.resumed==0,'fresh migrations')
check(state.rows[1].status=='applied' and state.rows[2].status=='applied' and state.rows[3].status=='applied' and state.rows[4].status=='applied' and state.tables==5,'ledger completed after DDL')
check(DoorsSchema.Check(db).ok,'read-only schema check')
local ddl=state.ddl
result=DoorsSchema.Run(db)
check(result.ok and result.value.applied==0 and state.ddl==ddl,'restart does not replay applied DDL')
state.rows[1].checksum='wrong'
result=DoorsSchema.Run(db)
check(not result.ok and result.code=='migration_checksum_mismatch' and state.ddl==ddl,'changed applied SQL refuses startup')
check(not DoorsSchema.Check(db).ok,'checksum mismatch also fails smoke')
for _,point in ipairs({1,2,3,4}) do
    db,state=database(); state.failDDL=point
    check(not pcall(DoorsSchema.Run,db),'DDL interruption surfaces')
    check(state.rows[point>=3 and point or 1].status=='applying','intent survives interrupted DDL')
    check(not DoorsSchema.Check(db).ok,'partial migration not ready')
    state.failDDL=nil; result=DoorsSchema.Run(db)
    check(result.ok and result.value.resumed==1 and result.value.applied==(point==4 and 0 or point==3 and 1 or 3),'same-checksum interrupted migration resumes')
    check(DoorsSchema.Check(db).ok,'resumed migration checks clean')
end
db,state=database(); state.tables=1
result=DoorsSchema.Run(db)
check(not result.ok and result.code=='untracked_schema' and state.ddl==0 and #state.rows==0,'never adopt unjournaled domain table')
db,state=database(); state.rows={{id='future_migration',checksum='unknown',status='applied'}}
result=DoorsSchema.Run(db)
check(not result.ok and result.code=='unknown_migration' and state.ddl==0,'older code refuses newer schema')
db,state=database(); DoorsSchema.Run(db); state.rows[1].status='broken'
check(DoorsSchema.Run(db).code=='invalid_migration_status','invalid ledger status refused')
db,state=database(); DoorsSchema.Run(db); state.tables=1
check(DoorsSchema.Check(db).code=='schema_tables_missing','missing domain table fails readiness')
db,state=database(); DoorsSchema.Run(db); state.missingColumn='locked'
check(DoorsSchema.Check(db).code=='schema_columns_missing','missing required column fails readiness')
state.missingColumn=nil; state.badType=true
check(DoorsSchema.Check(db).code=='schema_columns_mismatch','wrong column type fails readiness')
db,state=database(); state.exceptions=true
check(not pcall(DoorsSchema.Run,db),'database error never becomes success')
print(('PASS %d schema checks'):format(passed))
