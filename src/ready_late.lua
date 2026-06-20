---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- here is where your mod sets up all the things it will do after all other mods load.
-- this file will not be reloaded if it changes during gameplay
-- 	so you will most likely want to have it reference
--	values and functions later defined in `reload_late.lua`.

local pkg_list = {
    "WeaponAxe",
    "WeaponDagger",
    "WeaponLob",
    "WeaponStaffSwing",
    "WeaponSuit",
    -- "WeaponTorch",
}

for _, pkg in ipairs(pkg_list) do
    pkg_hash = rom.data.get_hash_guid_from_string(pkg)

    custom_pkg_hash =  rom.data.get_hash_guid_from_string(_PLUGIN.guid .. pkg)

    if pkg_hash ~= 0 and custom_pkg_hash ~= 0 then
        local current_overrides = {pkg_hash}
        rom.data.load_package_overrides_set(pkg_hash, current_overrides)
    end
end