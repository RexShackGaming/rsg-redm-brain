local LIB <const>    = Import 'class' --[[@as CLASS]]

local Weapon <const> = LIB.Class:Create({
	constructor = function(self, data)
		local value <const>  = SHARED_DATA.WEAPONS[data.name]
		self.id              = data.id or 0
		self.name            = data.name or ''
		self.label           = data.label or ''
		self.desc            = data.desc or ''
		self.propietary      = data.propietary
		self.charId          = data.charId
		self.ammo            = data.ammo or {}
		self.components      = data.components or {}
		self.used            = data.used or false
		self.used2           = data.used2 or false
		self.currInv         = data.currInv or ''
		self.dropped         = data.dropped or 0
		self.group           = data.group or 5
		self.weight          = data.weight or 0
		self.source          = data.source
		self.serial_number   = data.serial_number
		self.custom_label    = data.custom_label
		self.custom_desc     = data.custom_desc
		self.defaultClipSize = value.DefaultClipSize or 0
		self.degradation     = data.degradation or 0.0
		self.damage          = data.damage or 0.0
		self.dirt            = data.dirt or 0.0
		self.soot            = data.soot or 0.0
		self.canDegrade      = value.NoDegradation ~= true
	end,

	get = {
		getDegradation     = function(self)
			return self.degradation
		end,

		getId              = function(self)
			return self.id
		end,

		getName            = function(self)
			return self.name
		end,

		getLabel           = function(self)
			return self.label
		end,

		getDesc            = function(self)
			return self.desc
		end,

		getPropietary      = function(self)
			return self.propietary
		end,

		getCharId          = function(self)
			return self.charId
		end,

		getCurrInv         = function(self)
			return self.currInv
		end,

		getDropped         = function(self)
			return self.dropped
		end,

		getGroup           = function(self)
			return self.group
		end,

		getWeight          = function(self)
			return self.weight
		end,

		getSource          = function(self)
			return self.source
		end,

		getSerialNumber    = function(self)
			return self.serial_number
		end,

		getCustomLabel     = function(self)
			return self.custom_label
		end,

		getCustomDesc      = function(self)
			return self.custom_desc
		end,

		getUsed            = function(self)
			return self.used
		end,

		getUsed2           = function(self)
			return self.used2
		end,

		getAllAmmo         = function(self)
			return self.ammo
		end,

		getAllComponents   = function(self)
			return self.components
		end,

		getAmmo            = function(self, type)
			return self.ammo[type]
		end,
		getDefaultClipSize = function(self)
			return self.defaultClipSize
		end,

		getStatus          = function(self)
			return {
				degradation = self.degradation,
				damage = self.damage,
				dirt = self.dirt,
				soot = self.soot,
			}
		end,
	},

	set = {
		setId                = function(self, id)
			self.id = id
		end,

		setName              = function(self, name)
			self.name = name
		end,

		setDesc              = function(self, desc)
			self.desc = desc
		end,

		setPropietary        = function(self, propietary)
			self.propietary = propietary
		end,

		setCharId            = function(self, charId)
			self.charId = charId
		end,

		setCurrInv           = function(self, invId)
			self.currInv = invId
		end,

		setDropped           = function(self, dropped)
			self.dropped = dropped
		end,

		setSource            = function(self, source)
			self.source = source
		end,

		setSerialNumber      = function(self, serial_number)
			self.serial_number = serial_number
		end,

		setCustomLabel       = function(self, custom_label)
			self.custom_label = custom_label
		end,

		setCustomDesc        = function(self, custom_desc)
			self.custom_desc = custom_desc
		end,

		setUsed              = function(self, isUsed)
			self.used = isUsed
		end,

		setUsed2             = function(self, isUsed)
			self.used2 = isUsed
		end,

		hasAmmoType          = function(self, type)
			if self.ammo[type] then
				return true
			end
			return false
		end,

		setAmmo              = function(self, type, amount)
			self.ammo[type] = tonumber(amount)
			DB_SERVICE.ASYNC.UPDATE('UPDATE loadout SET ammo = @ammo WHERE id=@id', { ammo = json.encode(self:getAllAmmo()), id = self.id })
		end,
		-- when we reload
		addAmmoToClip        = function(self, type, amount)
			if not self.ammo[type] then
				self.ammo[type] = amount
			end

			if self.defaultClipSize > 0 then
				self.ammo[type] = math.min(self.ammo[type] + amount, self.defaultClipSize)
			else
				self.ammo[type] = self.ammo[type] + amount
			end
		end,

		cleanAllAmmoFromClip = function(self)
			for ammoType, _ in pairs(self.ammo) do
				self.ammo[ammoType] = nil
			end
		end,

		subAmmoFromClip      = function(self, type, amount)
			-- player must have the ammo type in weapon ?
			if not self.ammo[type] then
				self.ammo[type] = nil
				return
			end
			self.ammo[type] = math.max(0, self.ammo[type] - tonumber(amount))
		end,

		addComponent         = function(self, component, category)
			self.components[category] = component
			DB_SERVICE.ASYNC.UPDATE('UPDATE loadout SET comps = @comps WHERE id = @id', { id = self.id, comps = json.encode(self:getAllComponents()) })
		end,

		removeComponent      = function(self, component, category)
			local _component <const> = self.components[category]
			if _component and _component == component then
				self.components[category] = nil
				DB_SERVICE.ASYNC.UPDATE('UPDATE loadout SET comps = @comps WHERE id = @id', { id = self.id, comps = json.encode(self:getAllComponents()) })
			end
		end,

		updateStatus         = function(self, data)
			if not self.canDegrade then return end
			self.degradation = data.degradation
			self.damage = data.damage
			self.dirt = data.dirt
			self.soot = data.soot
		end,
	},
}, "SERVER_WEAPON")

---@class WEAPON_SERVER
---@field public New fun(self: WEAPON_SERVER, data: table): WEAPON_SERVER
---@field public Register fun(self: WEAPON_SERVER, data: table): WEAPON_SERVER
WEAPON               = Weapon

function WEAPON:Register(data)
	local weapon <const> = WEAPON:New(data)
	return weapon
end
