local root=arg and arg[1] or '.'
local registered={}
exports=function(name,fn) registered[name]=fn end
GetInvokingResource=function() return 'bcc-stables' end
Config={Access={trustedReaders={['bcc-stables']=true}},Authorization={enabled=true,issueAction='economy.currency.issue'},Limits={maximumTransferAmount=100000}}
EconomyResults={Ok=function(v) return {ok=true,value=v} end,Err=function(code) return {ok=false,code=code} end}
local writes=0
local wallet={accountType='wallet',status='open',currency='dollars',ownerType='character',ownerId='owner'}
EconomyAccounts={Get=function() return EconomyResults.Ok(wallet) end,
    FindByOwner=function() return EconomyResults.Ok({{accountId='source',currency='dollars',accountType='system_source',status='open'}}) end}
EconomyJournal={MayPost=function(operation,resource,reason) return operation=='issue' and resource=='bcc-stables' and reason=='stables.tack_sale' end,
    Issue=function() writes=writes+1;return EconomyResults.Ok(true) end}
dofile(root..'/server/services/api.lua')
local request={accountId='wallet',currency='dollars',amount=100,reasonCode='stables.tack_sale'}
local context={actorCharacterId='owner'}
local function allow(action,p)
    assert(action=='economy.currency.issue' and p.subject.resource=='bcc-stables' and p.subject.amount==100)
    return {ok=true,value={allowed=true}}
end
assert(EconomyAPI.CheckIssue(request,context,'bcc-stables',allow).ok)
assert(writes==0)
assert(not EconomyAPI.CheckIssue(request,context,'other',allow).ok)
assert(not EconomyAPI.CheckIssue(request,context,'bcc-stables',function() return {ok=true,value={allowed=false}} end).ok)
assert(not EconomyAPI.CheckIssue(request,context,'bcc-stables',function() error('offline') end).ok)
wallet.ownerId='other';assert(not EconomyAPI.CheckIssue(request,context,'bcc-stables',allow).ok)
wallet.ownerId='owner';wallet.status='closed';assert(not EconomyAPI.CheckIssue(request,context,'bcc-stables',allow).ok)
wallet.status='open';assert(writes==0)
assert(EconomyAPI.Supply('issue',request,context,'bcc-stables',allow).ok and writes==1)
assert(not EconomyAPI.Supply('issue',request,context,'bcc-stables',function() return {} end).ok and writes==1)
print('PASS issue preflight: scoped caller/reason, shared policy, exact owner/wallet, no writes; supply authorization unchanged')
