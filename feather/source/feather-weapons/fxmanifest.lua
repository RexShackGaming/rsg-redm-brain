fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

description 'The official weapon system for Feather framework.'
author 'Feather Framework'
name 'feather-weapons'
version '0.23.0'

shared_scripts {
    'config.lua',
    '/shared/constants.lua',
    '/shared/errors.lua',
    '/shared/definitions/ammunition.lua',
    '/shared/definitions/attachments.lua',
    '/shared/definitions/weapons.lua',
    '/shared/validation.lua',
    '/shared/native_acceptance_view.lua',
    '/shared/native_guid_acceptance.lua',
    '/shared/ammunition_pools.lua',
    '/shared/character_ammunition.lua',
    '/shared/character_ammunition_runtime.lua',
    '/shared/character_ammunition_client.lua',
    '/shared/character_ammunition_catalog.lua',
    '/shared/character_ammunition_policy.lua',
    '/shared/character_ammunition_item.lua',
    '/shared/native_melee_catalog.lua',
    '/shared/native_knife.lua',
    '/shared/native_lasso_policy.lua',
    '/shared/native_davy_lantern_policy.lua',
    '/shared/native_binoculars_policy.lua',
    '/shared/native_camera_policy.lua',
    '/shared/native_advanced_camera_policy.lua',
    '/shared/native_improved_binoculars_policy.lua',
    '/shared/native_fishing_rod_policy.lua',
    '/shared/native_metal_detector_policy.lua',
    '/shared/native_utility_catalog.lua',
    '/shared/native_utility_item.lua',
    '/shared/native_utility_collection.lua',
    '/shared/native_throwable_policy.lua',
    '/shared/native_throwable_item.lua',
    '/shared/native_throwable_recovery.lua',
    '/shared/character_attachments.lua',
    '/shared/character_maintenance.lua',
    '/shared/character_lifecycle_wear.lua',
    '/shared/character_ammunition_materialization.lua',
    '/shared/character_ammunition_loadout_lease.lua',
    '/shared/character_ammunition_transport.lua',
    '/shared/character_ammunition_dispatch.lua',
    '/shared/character_ammunition_activation.lua',
    '/shared/character_ammunition_readiness.lua'
}

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'shop_config.lua',
    '/server/adapters/core.lua',
    '/server/services/character_ammunition_runtime.lua',
    '/server/adapters/character_ammunition_inventory.lua',
    '/server/services/character_ammunition_dispatch.lua',
    '/server/services/character_ammunition_routes.lua',
    '/server/services/native_equipment_transition.lua',
    '/server/services/definition_registry.lua',
    '/server/services/metadata.lua',
    '/server/services/attachments.lua',
    '/server/services/provenance.lua',
    '/server/services/move_delivery.lua',
    '/server/services/evidence.lua',
    '/server/services/ownership.lua',
    '/server/services/issuance.lua',
    '/server/services/shop_purchases.lua',
    '/server/services/gun_store_catalog.lua',
    '/server/services/native_throwable_projectile_probe.lua',
    '/server/services/native_acceptance_suite.lua',
    '/server/services/native_guid_acceptance.lua',
    '/shared/native_restart_acceptance.lua',
    '/server/services/native_restart_acceptance.lua',
    '/server/services/commands.lua',
    '/server/services/api.lua',
    '/server/main.lua'
}

client_scripts {
    '/client/character_ammunition_native.lua',
    '/client/character_ammunition_controller.lua',
    '/client/character_ammunition_loadout.lua',
    '/client/character_maintenance_native.lua',
    '/client/character_ammunition_creation_native.lua',
    '/client/character_ammunition_dual_native.lua',
    '/client/character_ammunition_session.lua',
    '/client/character_ammunition_owner.lua',
    '/client/character_ammunition_receiver.lua',
    '/client/character_ammunition_release.lua',
    '/client/character_ammunition_checkpoint.lua',
    '/client/character_ammunition_context.lua',
    '/client/character_ammunition_context_native.lua',
    '/client/character_ammunition_host.lua',
    '/client/character_ammunition_lifecycle.lua',
    '/client/character_ammunition_driver.lua',
    '/client/character_ammunition_client_runtime.lua',
    '/client/character_ammunition_routes.lua',
    '/client/native_knife_owner.lua',
    '/client/native_melee_owner.lua',
    '/client/native_throwable_owner.lua',
    '/client/native_throwable_adapter.lua',
    '/client/native_utility_owner.lua',
    '/client/native_utility_collection.lua',
    '/client/native_utility_adapter.lua',
    '/client/character_ammunition_native_owner.lua',
    '/client/character_ammunition_startup.lua',
    '/client/native_acceptance_suite.lua',
    '/client/native_guid_acceptance.lua',
    '/client/character_ammunition_actions.lua',
    '/client/native_equipment_actions.lua',
    '/client/native_throwable_projectile_probe.lua',
    '/client/native_maintenance_checkpoint.lua',
}

files {
    '/data/weapon_holsters.meta'
}

data_file 'WEAPONINFO_FILE_PATCH' '/data/weapon_holsters.meta'

dependencies {
    'feather-mysql',
    'feather-core',
    'feather-character',
    'feather-medical',
    'feather-inventory',
    'feather-menu-v2'
}
