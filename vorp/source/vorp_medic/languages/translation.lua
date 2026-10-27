---@class vorp_medic_translation
local Translation = {}

Translation.Langs = {
    English = {
        Menu = {
            Hire = "Hire",
            Fire = "Fire",
            HirePlayer = "Hire Player",
            FirePlayer = "Fire Player",
            DoctorMenu = "Doctor Menu",
            HireFireMenu = "Hire/Fire Menu",
            OpenDoctorMenu = "Open Doctor Menu",
            Press = "Press",
            SubMenu = "SubMenu",
            PressEnter = "Press Enter",
        },
        Teleport = {
            TeleportTo = "Teleport to",
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
            YouAreNotADoctor = "You are not a doctor",
            Nojoblabel = "Job doesn't have a label in config, please add",
        },
        Player = {
            PlayerIsNotDead = "Player is not dead",
            PlayerId = "Player ID",
            Confirm = "Confirm",
            OnlyNumbersAreAllowed = "Only numbers are allowed",
            NoPlayerFound = "Player not found. You can only hire players in session.",
            PlayeAlreadyHired = "Player is already a ",
            NotNear = "Player is not near you to be hired",
            HireedPlayer = "You have been hired as ",
            CantFirenotHired = "Player is not a doctor, you can't fire them",
            FiredPlayer = "You have fired the player",
            BeenFireed = "You have been fired",
            NoPlayerFoundToRevive = "No player close to you to revive",
        },
        Error = {
            OnlyDoctorOpenMenu = "You are not allowed to open this menu",
            PlayerNearbyCantOpenInventory = "There is a player nearby. Cannot open inventory", -- Fixed naming
            AlreadyAlertedDoctors = "You already alerted the doctors. To cancel, use /cancelalert",
            NoDoctorsAvailable = "No doctors available at this moment",
            NotDeadCantAlert = "You are not dead to alert doctors",
            NoAlertToCancel = "You have not alerted the doctors",
            NotOnCall = "You are not on call to cancel an alert",
        },
        Alert = {
            PlayerNeedsHelp = "Player needs help. Look at the map for their location",
            DoctorsAlerted = "Doctors have been alerted",
            AlertCanceled = "You have canceled the alert",
            AlertCanceledByPlayer = "Player has canceled the alert",
            AlertCanceledByDoctor = "Doctor has canceled the alert",
            PlayerDisconnectedAlertCanceled = "Player has disconnected, alert canceled",
            ArrivedAtLocation = "You have arrived at the location",
            playeralert = "player alert"
        }
    },
    Spanish = {
        Menu = {
            Hire = "Contratar",
            Fire = "Despedir",
            HirePlayer = "Contratar Jugador",
            FirePlayer = "Despedir Jugador",
            DoctorMenu = "Menú de Doctor",
            HireFireMenu = "Menú de Contratar/Despedir",
            OpenDoctorMenu = "Abrir Menú de Doctor",
            Press = "Presionar",
            SubMenu = "SubMenú",
            PressEnter = "Presiona Enter",
        },
        Teleport = {
            TeleportTo = "Teletransportarse a",
            TeleportMenu = "Menú de Teletransporte",
            TeleportToDifferentLocations = "Teletransportarse a diferentes ubicaciones",
        },
        Duty = {
            GoOnDuty = "Entrar en servicio",
            GoOffDuty = "Salir de servicio",
            OnDuty = "En Servicio",
            OffDuty = "Fuera de Servicio",
            YouAreNotOnDuty = "No estás en servicio",
            YouAreNowOnDuty = "Ahora estás en servicio",
        },
        Jobs = {
            Job = "Trabajo",
            YouAreNotADoctor = "No eres un doctor",
            Nojoblabel = "El trabajo no tiene una etiqueta en la configuración, por favor añade una",
        },
        Player = {
            PlayerIsNotDead = "El jugador no está muerto",
            PlayerId = "ID del Jugador",
            Confirm = "Confirmar",
            OnlyNumbersAreAllowed = "Solo se permiten números",
            NoPlayerFound = "Jugador no encontrado. Solo puedes contratar jugadores en la sesión.",
            PlayeAlreadyHired = "El jugador ya es un ",
            NotNear = "El jugador no está cerca de ti para ser contratado",
            HireedPlayer = "Has sido contratado como ",
            CantFirenotHired = "El jugador no es un doctor, no puedes despedirlo",
            FiredPlayer = "Has despedido al jugador",
            BeenFireed = "Has sido despedido",
            NoPlayerFoundToRevive = "No hay ningún jugador cerca para revivir",
        },
        Error = {
            OnlyDoctorOpenMenu = "No tienes permiso para abrir este menú",
            PlayerNearbyCantOpenInventory = "Hay un jugador cerca. No se puede abrir el inventario",
            AlreadyAlertedDoctors = "Ya has alertado a los doctores. Para cancelar, usa /cancelalert",
            NoDoctorsAvailable = "No hay doctores disponibles en este momento",
            NotDeadCantAlert = "No estás muerto para alertar a los doctores",
            NoAlertToCancel = "No has alertado a los doctores",
            NotOnCall = "No estás en llamada para cancelar una alerta",
        },
        Alert = {
            PlayerNeedsHelp = "El jugador necesita ayuda. Mira el mapa para su ubicación",
            DoctorsAlerted = "Los doctores han sido alertados",
            AlertCanceled = "Has cancelado la alerta",
            AlertCanceledByPlayer = "El jugador ha cancelado la alerta",
            AlertCanceledByDoctor = "El doctor ha cancelado la alerta",
            PlayerDisconnectedAlertCanceled = "El jugador se ha desconectado, alerta cancelada",
            ArrivedAtLocation = "Has llegado a la ubicación",
            playeralert = "alerta de jugador"
        }
    },
    -- Add your language here and open a PR to merge other languages to the main repo
}

return {
    Translation = Translation,
}
