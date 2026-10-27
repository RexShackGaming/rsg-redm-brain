local LIB <const> = Import 'class' --[[@as CLASS]]

local Item <const> = LIB.Class:Create({
	constructor = function(self, data)
		data                = data or {}
		self.id             = data.id or 0
		self.item           = data.item
		self.name           = data.name or ''
		self.label          = data.label or ''
		self.type           = data.type
		self.model          = data.model
		self.metadata       = data.metadata or {}
		self.createdAt      = data.createdAt
		self.owner          = data.owner
		self.desc           = data.desc or ''
		self.count          = data.count
		self.limit          = data.limit
		self.weight         = data.weight or 0
		self.canUse         = data.canUse
		self.canRemove      = data.canRemove or false
		self.dropOnDeath    = data.dropOnDeath or false
		self.group          = data.group or 1
		self.rarity         = data.rarity or 1
		self.durability     = data.durability
		self.instruction    = data.instruction
		self.degradation    = data.degradation
		self.maxDegradation = data.maxDegradation
		self.percentage     = data.percentage
		self.useExpired     = data.useExpired or false
	end,

	isItemExpired = function(self, degradation, maxDegradation)
		if maxDegradation ~= nil and degradation ~= nil then
			if degradation <= 0 then
				return true
			end

			local percentage = self:getPercentage(maxDegradation, degradation)
			if percentage == 0 then
				return true
			end

			return false
		end

		if self.degradation then
			if self.degradation <= 0 then
				return true
			end

			local percentage = self:getPercentage()
			if percentage == 0 then
				return true
			end
		end

		return false
	end,

	get = {
		getId                = function(self)
			return self.id
		end,

		getName              = function(self)
			return self.name
		end,

		getLabel             = function(self)
			return self.label
		end,

		getDesc              = function(self)
			return self.desc
		end,

		getType              = function(self)
			return self.type
		end,

		getModel             = function(self)
			return self.model
		end,

		getMetadata          = function(self)
			return self.metadata
		end,

		getCount             = function(self)
			return self.count
		end,

		getLimit             = function(self)
			return self.limit
		end,

		getWeight            = function(self)
			return self.metadata.weight or self.weight
		end,

		getGroup             = function(self)
			return self.group
		end,

		getRarity            = function(self)
			return self.rarity
		end,

		getDurability        = function(self)
			return self.durability
		end,

		getInstruction       = function(self)
			return self.instruction
		end,

		getOwner             = function(self)
			return self.owner
		end,

		getCanUse            = function(self)
			return self.canUse
		end,

		getCanRemove         = function(self)
			return self.canRemove
		end,

		getDropOnDeath       = function(self)
			return self.dropOnDeath
		end,

		canUseExpiredItem    = function(self)
			return self.useExpired
		end,

		getDegradation       = function(self)
			return self.degradation
		end,

		getMaxDegradation    = function(self)
			return self.maxDegradation
		end,

		getCurrentPercentage = function(self)
			return self.percentage
		end,

		getElapsedTime       = function(self, maxDegradation, percentage)
			if maxDegradation ~= nil and percentage ~= nil then
				local isDegradable = maxDegradation > 0
				if isDegradable then
					local maxDegradeSeconds = maxDegradation * 60
					local remaining_percent = percentage
					local degradation_elapsed = maxDegradeSeconds * (1 - remaining_percent / 100)
					return degradation_elapsed
				end
				return 0
			end

			local isDegradable = self.maxDegradation and self.maxDegradation > 0
			if isDegradable and self.percentage then
				local maxDegradeSeconds = self.maxDegradation * 60
				local remaining_percent = self.percentage
				local degradation_elapsed = maxDegradeSeconds * (1 - remaining_percent / 100)
				return degradation_elapsed
			end

			return 0
		end,

		getPercentage        = function(self, maxDegradation, degradation)
			if not IsDuplicityVersion() then return 0 end

			if maxDegradation ~= nil and degradation ~= nil then
				local isDegradable = maxDegradation > 0
				if isDegradable then
					local elapsedSeconds = os.time() - degradation
					local maxDegradeSeconds = maxDegradation * 60
					local percentage = math.max(0, ((maxDegradeSeconds - elapsedSeconds) / maxDegradeSeconds) * 100)
					percentage = math.floor(percentage)
					return percentage
				end

				return 0
			end

			local isDegradable = self.maxDegradation and self.maxDegradation > 0
			if isDegradable and self.degradation then
				local elapsedSeconds = os.time() - self.degradation
				local maxDegradeSeconds = self.maxDegradation * 60
				local percentage = math.max(0, ((maxDegradeSeconds - elapsedSeconds) / maxDegradeSeconds) * 100)
				self.percentage = math.floor(percentage)
				return self.percentage
			end

			return 0
		end,
	},

	set = {
		setId          = function(self, id)
			self.id = id
		end,

		setName        = function(self, name)
			self.name = name
		end,

		setLabel       = function(self, label)
			self.label = label
		end,

		setDesc        = function(self, desc)
			self.desc = desc
		end,

		setType        = function(self, itemType)
			self.type = itemType
		end,

		setModel       = function(self, model)
			self.model = model
		end,

		setMetadata    = function(self, metadata)
			if metadata then
				self.metadata = metadata
			end
		end,

		setCount       = function(self, amount)
			self.count = math.max(0, amount)
		end,

		setLimit       = function(self, limit)
			self.limit = math.max(0, limit)
		end,

		setWeight      = function(self, weight)
			self.weight = math.max(0, weight)
		end,

		setDurability  = function(self, durability)
			self.durability = math.max(0, durability)
		end,

		setDropOnDeath = function(self, dropOnDeath)
			self.dropOnDeath = dropOnDeath
		end,

		setDegradation = function(self, degradation)
			if not IsDuplicityVersion() then return end
			self.degradation = degradation or os.time()
		end,

		addCount       = function(self, amount, ignoreStackLimit)
			if self.limit == -1 or (self.count + amount <= self.limit) or ignoreStackLimit then
				self.count = self.count + amount
				return true
			end
			return false
		end,

		quitCount      = function(self, amount)
			if not amount then return end
			self.count = self.count - amount

			if self.count <= 0 then
				self.count = 0
			end
		end,
	},
}, "SHARED_ITEM")

---@class ITEM
---@field public New fun(self: ITEM, data: table): ITEM
---@field public Register fun(self: ITEM, data: table): ITEM
---@field public isItemExpired fun(self: ITEM, degradation: number|nil, maxDegradation: number|nil): boolean
---@field public getElapsedTime fun(self: ITEM, maxDegradation: number|nil, percentage: number|nil): number
---@field public getPercentage fun(self: ITEM, maxDegradation: number|nil, degradation: number|nil): number
---@field public getCurrentPercentage fun(self: ITEM): number
---@field public getMaxDegradation fun(self: ITEM): number
---@field public getDegradation fun(self: ITEM): number
---@field public getCount fun(self: ITEM): number
---@field public getLimit fun(self: ITEM): number
---@field public getWeight fun(self: ITEM): number
---@field public getGroup fun(self: ITEM): number
---@field public getRarity fun(self: ITEM): number
---@field public getDurability fun(self: ITEM): number
---@field public getInstruction fun(self: ITEM): string
---@field public getOwner fun(self: ITEM): string
---@field public getCanUse fun(self: ITEM): boolean
---@field public getCanRemove fun(self: ITEM): boolean
---@field public getDropOnDeath fun(self: ITEM): boolean
---@field public canUseExpiredItem fun(self: ITEM): boolean
---@field public getMetadata fun(self: ITEM): table
---@field public getName fun(self: ITEM): string
---@field public setId fun(self: ITEM, id: number)
---@field public setName fun(self: ITEM, name: string)
---@field public setLabel fun(self: ITEM, label: string)
---@field public setDesc fun(self: ITEM, desc: string)
---@field public setType fun(self: ITEM, itemType: string)
---@field public setModel fun(self: ITEM, model: string)
---@field public setMetadata fun(self: ITEM, metadata: table)
---@field public setCount fun(self: ITEM, amount: number)
---@field public setLimit fun(self: ITEM, limit: number)
---@field public setWeight fun(self: ITEM, weight: number)
---@field public setDurability fun(self: ITEM, durability: number)
---@field public setDropOnDeath fun(self: ITEM, dropOnDeath: boolean)
---@field public setDegradation fun(self: ITEM, degradation: number)
---@field public addCount fun(self: ITEM, amount: number, ignoreStackLimit: boolean): boolean
---@field public quitCount fun(self: ITEM, amount: number)
---@field public degradation number degradation time
---@field public percentage number percentage of degradation
---@field public useExpired boolean if the item can be used after it expires
---@field public id number
---@field public item string
---@field public name string
---@field public label string
---@field public type string
---@field public model string
---@field public metadata table
---@field public createdAt number
---@field public owner string
---@field public desc string
---@field public count number
---@field public limit number
---@field public weight number
---@field public canUse boolean
---@field public canRemove boolean
---@field public dropOnDeath boolean
---@field public group number
---@field public rarity number
---@field public instruction string
---@field public maxDegradation number
---@field public durability number|nil
ITEM = Item

function ITEM:Register(data)
	local itemClass <const> = ITEM:New(data)
	return itemClass
end
