---@class vorp_police_translation
local Translation = {}

Translation.Langs = {
	English = {
		Menu = {
			Hire = "Hire",
			Fire = "Fire",
			HirePlayer = "Hire Player",
			FirePlayer = "Fire Player",
			SheriffMenu = "Sheriff Menu",
			HireFireMenu = "Hire/Fire Menu",
			OpenPoliceMenu = "Open Police Menu",
			Press = "Press",
			SubMenu = "SubMenu"
		},
		Teleport = {
			TeleportTo = "Teleport to ",
			TeleportMenu = "Teleport Menu",
			TeleportToDifferentLocations = "Teleport to different locations",
		},
		Duty = {
			GoOnDuty = "Go on duty",
			GoOffDuty = "Go off duty",
			OnDuty = "On Duty",
			OffDuty = "Off Duty",
			YouAreNotOnDuty = "You are not on duty",
			YouAreNowOnDuty = "You are now on duty",
		},
		Jobs = {
			Job = "Job",
			YouAreNotAPoliceOfficer = "You are not a police officer",
			Nojoblabel = "job doesnt have label in config please add",
		},
		Player = {
			PlayerId = "Player ID",
			Confirm = "Confirm",
			OnlyNumbersAreAllowed = "Only numbers are allowed",
			NoPlayerFound = "player not found can only hire players in session",
			PlayeAlreadyHired = "player is already a ",
			NotNear = "player is not near you to be hired",
			HireedPlayer = "you have been hired as ",
			CantFirenotHired = "player is not a police officer you cant fire them",
			FiredPlayer = "you have fired the player",
			BeenFireed = "you have been fired",
		},
		Cuff = {
			PlayerCuffAlready = "player is already cuffed remove cuffs first",
			PlayerNotcuffed = "player is not cuffed to use the keys",
		},
		Error = {
			OnlyPoliceopenmenu = "You Are Not Allowed ToOpen This Menu",
			Playernearby = "There Is A Player Nearby Cant Open Inventory"
		},
		Alerts = {
			tocancalert = "You already alerted the police to cancel it do /cancelalert",
			noofficers = "No one to receive alert at this moment",
			onlydead = "You are not dead to alert police",
			policealert = "Player needs help look in the map to see location",
			playeralert = "Police have been alerted, stay where you are so they can find you",
			noalerts = "You have not alerted the police",
			alertcanceled = "Player has canceled the alert",
			canceled = "You have canceled the alert",
			notoncall = "You are not on call to cancel an alert",
			policecancel = "Police has canceled the alert",
			playerDropped = "Player has disconnected call canceled",
			arive = "you have arrived to the location look for the player"
		},
		Jail = {
			jailTimeNotFound       = "Jail time not found",
			jailTimeRemaining      = "You still have %d minutes and %d seconds left in jail",
			noPlayerID             = "No player ID",
			invalidTime            = "Invalid time was provided",
			playerNotFound         = "Player not found, can only jail online players",
			playerAlreadyJailed    = "Player is already jailed",
			noJailPermission       = "You do not have permission to jail players or you are not on duty",
			playerJailed           = "Player was jailed",
			jailedForTime          = "You were jailed for %d minutes",
			playerReleased         = "Player was released from jail",
			playerNotJailed        = "Player is not jailed",
			unjailPermissionDenied = "You do not have permission to unjail players or you are not on duty",
			changeJailPermission   = "You do not have permission to modify jail time or you are not on duty",
			timeNotProvided        = "Time was not provided",
			jailTimeModified       = "Jail time was modified from %d minutes to %d minutes",
			jailTimeExpired        = "Player was released from jail because the time was up",
			playerReleasedFromJail = "Player was released from jail",
			cantalertJail          = "you are in jail you can't alert police",
			cantLeaveJail          = "you are in jail you can't leave",

			jailSuggestions        = {
				openPoliceMenu        = "Open Police Menu",
				jailPlayerCommand     = "Jail player",
				unjailPlayerCommand   = "Unjail player",
				checkJailTimeCommand  = "to check your jail time and get released use /checkjailtime",
				changeJailTimeCommand = "Reduce/Increase jail time",

				Help                  = {
					jailPlayer = {
						name = "ID",
						help = "the player id and time in minutes to jail",
						Minites = {
							name = "MINUTES",
							help = "the time in minutes to reduce or increase jail time"
						}
					},
					unjailPlayer = {
						name = "ID",
						help = "the player id to unjail"
					}
				}
			}

		}
	},
}

return {
	Translation = Translation
}
