---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- here is where your mod sets up all the things it will do.
-- this file will not be reloaded if it changes during gameplay
-- 	so you will most likely want to have it reference
--	values and functions later defined in `reload.lua`.

-- Config
local enabled = true

if not enabled then return end

-- Depends
sjson = rom.mods['SGG_Modding-SJSON']
modutil = rom.mods['SGG_Modding-ModUtil']
rom.mods['SGG_Modding-ENVY'].auto()

game = rom.game
import_as_fallback(game)

-- Utility functions
function mod.LoadAspectPackage(Name)
	local packageName = _PLUGIN.guid .. Name
	print("AuthorName-ModName - Loading package: " .. packageName)
	LoadPackages({ Name = packageName })
end

--Function for StaffAspectYoungMel trait
function mod.CheckStaffSelfHit( triggerArgs, args )
	if not IsEmpty( GetInProjectilesBlast({ Id = CurrentRun.Hero.ObjectId, DestinationName = args.ProjectileName })) then
		if (CurrentRun.Hero.Health / CurrentRun.Hero.MaxHealth) <= args.Threshold then
			if HeroHasTrait("StaffDoubleHealTraitYM") then
				Heal( CurrentRun.Hero, {HealAmount = (args.HealAmount * 2), SourceName = "Aspect" })
			else
				Heal( CurrentRun.Hero, {HealAmount = args.HealAmount, SourceName = "Aspect" })
			end
		end
	end
end

--Function for AxeAspectYoungMel trait
function mod.BlockAxeBuff( blocker, args, triggerArgs )
	if not blocker or not blocker.ObjectId then
		return
	end
	if triggerArgs.WeaponName == "WeaponAxeSpecial" then
		if (triggerArgs.BlockedProjectileName == "ScyllaNotes" or triggerArgs.BlockedProjectileName == "ScyllaNotesFinale") and not GameState.Flags.YM_Block_Scylla then
			GameState.Flags.YM_Block_Scylla = true
		elseif (triggerArgs.BlockedProjectileName == "HadesCastBeam" or triggerArgs.BlockedProjectileName == "HadesCastBeam2" or triggerArgs.BlockedProjectileName == "HadesCastBeam360" or triggerArgs.BlockedProjectileName == "HadesCastBeam2360") and not GameState.Flags.YM_Block_Hades_Laser then
			GameState.Flags.YM_Block_Hades = true
		end
		local trait = GetHeroTrait( "AxeAspectofYoungMelinoe") or GetHeroTrait("AxeAspectofYoungMelinoe_Secondary")
		if trait.RetaliateBuff ~= 1 then
			return
		end
		if HeroHasTrait("AxeExtendedRetaliateTraitYM") then
			args.Duration = args.Duration * 2
		end
		trait.RetaliateBuff = args.MaxRetaliateBuff
		ApplyEffect({ DestinationId = CurrentRun.Hero.ObjectId, Id = CurrentRun.Hero.ObjectId, EffectName = args.EffectName, DataProperties = { Duration = args.Duration }})
		wait(args.Duration)
		trait.RetaliateBuff = 1
	end
end
--Functions and consumables for SkullAspectYoungMel trait 
OverwriteTableKeys(ConsumableData, {
	LobAmmoPackYM = {
		InheritFrom = { "BaseConsumable" },
		OnUsedFunctionName = "UseConsumableItem",
		--UseFunctionNames = {_PLUGIN.guid .. "." .. "ComboPresentation"},
		--UseFunctionArgs ={{unitId = CurrentRun.Hero.ObjectId}},
		CanDuplicate = false,
		Cost = 0,
		AddAmmoWeapon = "WeaponLob",
		AddAmmo = 1,
		HideWorldText = true,
		CannotUseText = "AmmoPackCannotUse",
		CannotUseSound = "/Leftovers/SFX/OutOfAmmo",
		ConsumeSound = "/SFX/Player Sounds/MelSkullsAmmoPickup",

		CompleteObjective = "WeaponLobPickup",

		MagnetismEscalateDelay = 10.0,
		MagnetismHintRemainingTime = 5.0,
		MagnetismEscalateAmount = 99000,

		SkipCheckRoomExitsReady = true,
	}
})

--ammo drops
function mod.WeaponLobAmmoDrop( triggerArgs, weaponDataArgs )
	if not SessionMapState.LobAmmoInFlight or SessionMapState.LobAmmoInFlight <= 0 then
		return
	end
	-- Stripped optimized version of CreateConsumableItem( consumableId, "LobAmmoPack" )
	local consumableData = ConsumableData.LobAmmoPackYM --LobAmmoPackYM
	local consumable = DeepCopyTable( consumableData )
	local consumableId = SpawnObstacle({ Name = "LobAmmoPackYM", --nopkg --LobAmmoPackYM
		LocationX = triggerArgs.LocationX, LocationY = triggerArgs.LocationY, Group = "Standing",
		TriggerOnSpawn = false, AttachedTable = consumable })	
	consumable.ObjectId = consumableId
	--mod.ComboPresentation( CurrentRun.Hero.ObjectId )
	AddToGroup({Id = consumableId, Name = "UsedFishingPoint" })	-- A little silly but we want to be able to collect ammo while fishing
	local ammoDropData = weaponDataArgs.DropForces
	DecrementTableValue( SessionMapState, "LobAmmoInFlight" )
	if HeroHasTrait("LobAmmoMagnetismTrait") then
		SetObstacleProperty({ Property = "MagnetismSpeedMax", Value = GetTotalHeroTraitValue("MagnetismSpeedMultiplier"), ValueChangeType = "Multiply", DestinationId = consumableId })
	end
	consumable.ProjectileVolley = triggerArgs.ProjectileVolley
	if triggerArgs.HasImpact ~= nil and weaponDataArgs.CollideForces then
		ammoDropData = weaponDataArgs.CollideForces
	end
	if weaponDataArgs.Cooldown then
		UseableOff({ Id = consumableId })
		thread( UseableOnDelay, { consumableId }, weaponDataArgs.Cooldown )
	end
	local magnetismMultiplier = GetTotalHeroTraitValue("AmmoMagnetismMultiplier", { IsMultiplier = true } )
	if not triggerArgs.Armed then
		if SessionMapState.MagnetismMultiplier then
			magnetismMultiplier = SessionMapState.MagnetismMultiplier * magnetismMultiplier
		elseif SessionMapState.AutoMagnetizeIds[ triggerArgs.ProjectileId ] then
			local playerMagnetism = GetBaseDataValue({ Type = "Obstacle", Name = "LobAmmoPackYM", Property = "Magnetism"}) --LobAmmoPackYM
			if GetDistance ({ Id = consumableId, DestinationId = CurrentRun.Hero.ObjectId }) <= SessionMapState.AutoMagnetizeIds[ triggerArgs.ProjectileId ].MagnetismMultiplier * magnetismMultiplier * playerMagnetism then 
				magnetismMultiplier = SessionMapState.AutoMagnetizeIds[ triggerArgs.ProjectileId ].MagnetismMultiplier * magnetismMultiplier
			end
		end
	end
	SetObstacleProperty({ Property = "Magnetism", Value = magnetismMultiplier, DestinationId = consumableId, ValueChangeType = "Multiply" })
	ApplyUpwardForce({ Id = consumableId, Speed = RandomFloat( ammoDropData.UpwardForceMin or 0, ammoDropData.UpwardForceMax or 0 ) })
	if ammoDropData.ForceMax ~= nil then
		local scatter = 0
		if ammoDropData.Scatter then
			scatter = RandomFloat( -(ammoDropData.Scatter)/2, (ammoDropData.Scatter)/2)
		end
		ApplyForce({ Id = consumableId, Speed = RandomFloat( ammoDropData.ForceMin, ammoDropData.ForceMax ), Angle = triggerArgs.Angle + scatter, SelfApplied = true })
	end
	thread( mod.EscalateMagnetismYM, consumable )
	SessionMapState.AutoMagnetizeIds[ triggerArgs.ProjectileId ] = nil
end

function mod.EscalateMagnetismYM( consumable )

	if consumable.MagnetismEscalateDelay == nil then
		return
	end
	wait( consumable.MagnetismEscalateDelay - consumable.MagnetismHintRemainingTime , RoomThreadName )
	if not IsAlive({ Id = consumable.ObjectId }) then
		return
	end
	CreateAnimation({ Name = "AmmoReturnTimer", DestinationId = consumable.ObjectId })
	local trait = GetHeroTrait( "SkullAspectofYoungMelinoe") or GetHeroTrait( "SkullAspectofYoungMelinoe_Secondary")
	if trait.Combo ~= 0 and not HeroHasTrait("LobExtendComboTraitYM") then
		trait.Combo = 0
		mod.ComboPresentationCancel(CurrentRun.Hero.ObjectId)
	end
	wait( consumable.MagnetismHintRemainingTime, RoomThreadName )
	SetObstacleProperty({ Property = "Magnetism", Value = consumable.MagnetismEscalateAmount, DestinationId = consumable.ObjectId })
	if trait.Combo ~= 0 and HeroHasTrait("LobExtendComboTraitYM") then
		trait.Combo = 0
		mod.ComboPresentationCancel(CurrentRun.Hero.ObjectId)
	end
end

function mod.ComboPresentation(weaponData, functionArgs, triggerArgs)
	--if unitId ~= CurrentRun.Hero.ObjectId then
	--	return
	--end
	local unitId = CurrentRun.Hero.ObjectId
	local trait = GetHeroTrait( "SkullAspectofYoungMelinoe") or GetHeroTrait( "SkullAspectofYoungMelinoe_Secondary")
	trait.Combo = trait.Combo + 1
	if trait.Combo <= 1 then
		return
	end
	PlaySound({ Name = "/Leftovers/Menu Sounds/LevelUpFlash", Id = unitId, ManagerCap = 46 })
	Flash({ Id = unitId, Speed = 0.85, MinFraction = 0.7, MaxFraction = 0.0, Color = Color.White, Duration = 0.15, ExpireAfterCycle = true })
	thread( InCombatText, unitId, "X" .. trait.Combo, 0.5 , { SkipShadow = true } )
	
	if HeroHasTrait("DummyComboDisplayBoonYM") then
		local traitData = GetHeroTrait("DummyComboDisplayBoonYM")
		UpdateTraitNumber( traitData )
	end
end

function mod.ComboPresentationCancel(unitId)
	if unitId ~= CurrentRun.Hero.ObjectId then
		return
	end
	local trait = GetHeroTrait( "SkullAspectofYoungMelinoe") or GetHeroTrait( "SkullAspectofYoungMelinoe_Secondary")
	if trait.Combo ~= 0 then
		return
	end
	PlaySound({ Name = "/Leftovers/Menu Sounds/LevelUpFlash", Id = unitId, ManagerCap = 46 })
	Flash({ Id = unitId, Speed = 0.85, MinFraction = 0.7, MaxFraction = 0.0, Color = Color.White, Duration = 0.15, ExpireAfterCycle = true })
	thread( InCombatText, unitId, "X" .. trait.Combo, 0.5 , { SkipShadow = true } )
	if HeroHasTrait("DummyComboDisplayBoonYM") then
		local traitData = GetHeroTrait("DummyComboDisplayBoonYM")
		UpdateTraitNumber( traitData )
	end
end

function mod.ComboDamageMod(weaponData, functionArgs, triggerArgs)
	local trait = GetHeroTrait( "SkullAspectofYoungMelinoe") or GetHeroTrait( "SkullAspectofYoungMelinoe_Secondary")
	local Multi = (functionArgs.Multiplier -1)
	if trait.Combo <= 1 then
		trait.ComboDamageMod = 1
	end
	if trait.Combo >= 2 and trait.Combo <= 10 then
  		trait.ComboDamageMod = Multi * (trait.Combo -1) +1
	elseif (trait.Combo > 10 and trait.Combo <= 20) or (trait.Combo > 20 and HeroHasTrait("LobComboScalingTraitYM")) then
		trait.ComboDamageMod =   (Multi * 10) + (Multi / 2 * (trait.Combo -11)) + 1
	elseif trait.Combo > 20 and trait.Combo <= 30 and not HeroHasTrait("LobComboScalingTraitYM") then
		trait.ComboDamageMod =   (Multi * 10) + (Multi / 2 * 10) + (Multi / 4 * (trait.Combo -21)) + 1
	elseif trait.Combo > 30 and not HeroHasTrait("LobComboScalingTraitYM") then
		trait.ComboDamageMod =   (Multi * 10) + (Multi / 2 * 10) + (Multi / 4 * 10) + (Multi / 8 * (trait.Combo -31)) + 1
	end
	if trait.Combo == 49 and CurrentRun.CurrentRoom and not game.CurrentHubRoom and not GameState.Flags.High_Combo then
		GameState.Flags.High_Combo = true
		--CheckAchievement({ Name = "AchYM_HighCombo" })
	end
end

function mod.SetupComboUI()
	if TempTextData then
		TempTextData.ComboStacks = 0
	end
	if not HeroHasTrait("DummyComboDisplayBoonYM") then
		AddTraitToHero({ TraitName = "DummyComboDisplayBoonYM" })
	end
end

function mod.CheckComboUI()
	RemoveTrait( CurrentRun.Hero, "DummyComboDisplayBoonYM" )
end

--Loading the package at every room
modutil.mod.Path.Wrap("SetupMap", function(base, source, args)
	mod.LoadAspectPackage("")
	return base(source, args)
end)

ModUtil.Path.Wrap("Heal", function(baseFunc, victim, triggerArgs)
        -- Fallback to the original logic first so we don't break actual gameplay healing
        baseFunc(victim, triggerArgs)
		if victim == CurrentRun.Hero and (HeroHasTrait("StaffAspectofYoungMelinoe") or HeroHasTrait("StaffAspectofYoungMelinoe_Secondary")) then
			CurrentRun.HealingTracker = CurrentRun.HealingTracker or 0
			CurrentRun.HealingTracker = CurrentRun.HealingTracker + triggerArgs.ActualHealAmount
			if CurrentRun.HealingTracker >= 500 and not GameState.Flags.LargeHealRun then
				GameState.Flags.LargeHealRun = true
			end
		end
end)

import "Aspect_cast_functions.lua"

---- Adding Custom Textures ------

--Whether to change new aspect textures
import "config.lua"
if config.Alter_Textures == true then
	--Importing Axe Textures
	local weapon_axe_hash = rom.data.get_hash_guid_from_string("WeaponAxe")
	local custom_axe_hash = rom.data.get_hash_guid_from_string("AxeTest-WeaponAxe")
	if weapon_axe_hash~=0 and custom_axe_hash~=0 then
		local current_axe_overrides = {custom_axe_hash}

		-- table.insert(current_axe_overrides, 1, custom_axe_hash)
		-- table.insert(current_axe_overrides, weapon_axe_hash)

		rom.data.load_package_overrides_set(weapon_axe_hash, current_axe_overrides)
	end
else
	--New Axe Texture
	local weapon_axe_hash = rom.data.get_hash_guid_from_string("WeaponAxe")
	local custom_pkg_hash = rom.data.get_hash_guid_from_string("Enderclem-CG3HBuilder-Enderclem-Axe")
	if weapon_axe_hash~=0 and custom_pkg_hash~=0 then
		local current_overrides = {custom_pkg_hash}
		-- table.insert(current_overrides, 1, custom_pkg_hash)
		-- table.insert(current_overrides, weapon_axe_hash)
		rom.data.load_package_overrides_set(weapon_axe_hash, current_overrides)
	end

	local gpk_path = rom.path.combine(
		_PLUGIN.plugins_data_mod_folder_path, 'Axe.gpk')
	rom.data.add_granny_file('Axe.gpk', gpk_path)
end

--New Staff Texture
local weapon_staff_hash = rom.data.get_hash_guid_from_string("WeaponStaffSwing")
custom_pkg_hash = rom.data.get_hash_guid_from_string("Enderclem-CG3HBuilder-Enderclem-Staff")

if weapon_staff_hash ~= 0 and custom_pkg_hash ~= 0 then
	current_overrides = {custom_pkg_hash}
	-- table.insert(current_overrides, 1, custom_pkg_hash)
	-- table.insert(current_overrides, weapon_staff_hash)
	rom.data.load_package_overrides_set(weapon_staff_hash, current_overrides)
end

gpk_path = rom.path.combine(
    _PLUGIN.plugins_data_mod_folder_path, 'Staff.gpk')
rom.data.add_granny_file('Staff.gpk', gpk_path)

--New Dagger Texture
local weapon_dagger_hash = rom.data.get_hash_guid_from_string("WeaponDagger")
custom_pkg_hash = rom.data.get_hash_guid_from_string("Enderclem-CG3HBuilder-Enderclem-Dagger")
if weapon_dagger_hash ~= 0 and custom_pkg_hash ~= 0 then
	current_overrides = {custom_pkg_hash}
	-- table.insert(current_overrides, 1, custom_pkg_hash)
	-- table.insert(current_overrides, weapon_dagger_hash)
	rom.data.load_package_overrides_set(weapon_dagger_hash, current_overrides)
end

gpk_path = rom.path.combine(
    _PLUGIN.plugins_data_mod_folder_path, 'Dagger.gpk')
rom.data.add_granny_file('Dagger.gpk', gpk_path)

--new Torch texture
--local weapon_torch_hash = rom.data.get_hash_guid_from_string("WeaponTorch")
--custom_pkg_hash = rom.data.get_hash_guid_from_string("Enderclem-CG3HBuilder-Enderclem-WeaponTorch")

--current_overrides = {custom_pkg_hash}
--table.insert(current_overrides, 1, custom_pkg_hash)
--table.insert(current_overrides, weapon_torch_hash)
--rom.data.load_package_overrides_set(weapon_torch_hash, current_overrides)

--gpk_path = rom.path.combine(
--    _PLUGIN.plugins_data_mod_folder_path, 'WeaponTorch.gpk')
--rom.data.add_granny_file('WeaponTorch.gpk', gpk_path)

--new Skull texture
local weapon_lob_hash = rom.data.get_hash_guid_from_string("WeaponLob")
custom_pkg_hash = rom.data.get_hash_guid_from_string("Enderclem-CG3HBuilder-Enderclem-Lob")
if weapon_lob_hash ~= 0 and custom_pkg_hash ~= 0 then
	current_overrides = {custom_pkg_hash}
	-- table.insert(current_overrides, 1, custom_pkg_hash)
	-- table.insert(current_overrides, weapon_lob_hash)
	rom.data.load_package_overrides_set(weapon_lob_hash, current_overrides)
end

gpk_path = rom.path.combine(
    _PLUGIN.plugins_data_mod_folder_path, 'Lob.gpk')
rom.data.add_granny_file('Lob.gpk', gpk_path)

--New suit texture
local weapon_suit_hash = rom.data.get_hash_guid_from_string("WeaponSuit")
custom_pkg_hash = rom.data.get_hash_guid_from_string("Enderclem-CG3HBuilder-Enderclem-WeaponSuit")

gpk_path = rom.path.combine(
    _PLUGIN.plugins_data_mod_folder_path, 'WeaponSuit.gpk')
rom.data.add_granny_file('WeaponSuit.gpk', gpk_path)

if weapon_suit_hash ~= 0 and custom_pkg_hash ~= 0 then
	current_overrides = {custom_pkg_hash}
	-- table.insert(current_overrides, 1, custom_pkg_hash)
	-- table.insert(current_overrides, weapon_suit_hash)
	rom.data.load_package_overrides_set(weapon_suit_hash, current_overrides)
end

gpk_path = rom.path.combine(
    _PLUGIN.plugins_data_mod_folder_path, 'WeaponSuit.gpk')
rom.data.add_granny_file('WeaponSuit.gpk', gpk_path)

ModUtil.Path.Wrap("EquipWeaponUpgrade", function(baseFunc, hero, args)
    baseFunc(hero, args)
	--if (HeroHasTrait("StaffAspectofYoungMelinoe") or HeroHasTrait("StaffAspectofYoungMelinoe_Secondary")) then
	if HeroHasTrait("StaffAspectofYoungMelinoe") then
		rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaffYM_MeshShapeDeformed", true)
        rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaff_Rig:WeaponStaff_MeshShapeDeformed", false)
	--elseif (HeroHasTrait("BaseStaffAspect") or HeroHasTrait("BaseStaffAspect_Secondary")) then
	elseif HeroHasTrait("BaseStaffAspect") then
		rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaffYM_MeshShapeDeformed", false)
        rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaff_Rig:WeaponStaff_MeshShapeDeformed", true)
	elseif HeroHasTrait("DaggerAspectofYoungMelinoe") then
		rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerA_Rig:WeaponDaggerA_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerB_Rig:WeaponDaggerB_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", true)
		rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", true)
		
		rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)

		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerMultipleFree_Rig:WeaponDaggerA_WeaponDaggerA_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerB_WeaponDaggerB_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", true)
		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", true)
		
		rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	elseif HeroHasTrait("DaggerBackstabAspect") then
		rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerA_Rig:WeaponDaggerA_MeshShapeDeformed", true)
		rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerB_Rig:WeaponDaggerB_MeshShapeDeformed", true)
		rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
		
		rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)

		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerMultipleFree_Rig:WeaponDaggerA_WeaponDaggerA_MeshShapeDeformed", true)
		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerB_WeaponDaggerB_MeshShapeDeformed", true)
		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
		
		rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
		rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	--elseif HeroHasTrait("TorchAspectofYoungMelinoe") then
	--	Destroy({ Id = "MelTorchFlameLeft", DestinationId = weaponId })
	--	StopAnimation({  Names = { "MelTorchFlameRight", "MelTorchFlameLeft", "MelTorchFlameGlow", "MelTorchFlameTrail" }, DestinationId = CurrentRun.Hero.ObjectId })
		--SetAlpha({ Id = "MelTorchFlameLeft", Fraction = 0.0, Duration = 0})
		--SetAlpha({ Id = "MelTorchFlameGlowL", Fraction = 0.0, Duration = 0})
		--SetAlpha({ Id = "MelTorchFlameTrail", Fraction = 0.0, Duration = 0})
	--	rom.data.draw_set_mesh_visible("WeaponTorchR_Mesh", "WeaponTorchYM_MeshShape", true)
	--	rom.data.draw_set_mesh_visible("WeaponTorchL_Mesh", "WeaponTorchYM_MeshShape", true)
	--	rom.data.draw_set_mesh_visible("WeaponTorchR_Mesh", "WeaponHecateR_Rig:WeaponTorch_MeshShape", false)
	--	rom.data.draw_set_mesh_visible("WeaponTorchL_Mesh", "WeaponHecateL_Rig:WeaponTorch_MeshShape", false)
	--elseif HeroHasTrait("TorchSpecialDurationAspect") then
	--	rom.data.draw_set_mesh_visible("WeaponTorchR_Mesh", "WeaponTorchYM_MeshShape", false)
	--	rom.data.draw_set_mesh_visible("WeaponTorchL_Mesh", "WeaponTorchYM_MeshShape", false)
	--	rom.data.draw_set_mesh_visible("WeaponTorchR_Mesh", "WeaponHecateR_Rig:WeaponTorch_MeshShape", true)
	--	rom.data.draw_set_mesh_visible("WeaponTorchL_Mesh", "WeaponHecateL_Rig:WeaponTorch_MeshShape", true)

	--elseif (HeroHasTrait("SkullAspectofYoungMelinoe") or HeroHasTrait("SkullAspectofYoungMelinoe_Secondary")) then
	elseif HeroHasTrait("SkullAspectofYoungMelinoe") then
        rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLobYM_MeshShape", true)
        rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLob_Rig:WeaponLob_MeshShape", false)
	--elseif (HeroHasTrait("LobAmmoBoostAspect") or HeroHasTrait("LobAmmoBoostAspect_Secondary")) then
    elseif HeroHasTrait("LobAmmoBoostAspect") then
        rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLobYM_MeshShape", false)
        rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLob_Rig:WeaponLob_MeshShape", true)
	elseif HeroHasTrait("SuitAspectofYoungMelinoe") then
        rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBmultYM_MeshShape", true)
		rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBmultOutlineYM_MeshShape", true)
		
		rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBYM_MeshShape", false)
		rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBOutlineYM_MeshShape", false)
        
		rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitMultiple_Rig:WeaponSuitB_MeshShape", false)
		rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitMultiple_Rig:WeaponSuitBOutline_MeshShape", false)

		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBmultYM_MeshShape", false)
		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBmultOutlineYM_MeshShape", false)
		
		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBYM_MeshShape", true)
		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBOutlineYM_MeshShape", true)
        
		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitB_Rig:WeaponSuitB_MeshShape", false)
		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitB_Rig:WeaponSuitBOutline_MeshShape", false)
    elseif HeroHasTrait("BaseSuitAspect") then
        rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBYM_MeshShape", false)
		rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBOutlineYM_MeshShape", false)
		
		rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBmultYM_MeshShape", false)
		rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBmultOutlineYM_MeshShape", false)
        
		rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitMultiple_Rig:WeaponSuitB_MeshShape", true)
		rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitMultiple_Rig:WeaponSuitBOutline_MeshShape", true)

		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBYM_MeshShape", false)
		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBOutlineYM_MeshShape", false)
		
		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBYM_MeshShape", false)
		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBOutlineYM_MeshShape", false)
        
		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitB_Rig:WeaponSuitB_MeshShape", true)
		rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitB_Rig:WeaponSuitBOutline_MeshShape", true)
    end
		--elseif (HeroHasTrait("AxeAspectofYoungMelinoe") or HeroHasTrait("AxeAspectofYoungMelinoe_Secondary")) then
	if config.Alter_Textures == false then
		if HeroHasTrait("AxeAspectofYoungMelinoe") then
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxeYM_MeshShapeDeformed", true)
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxe_MeshShapeDeformed", false)
		--elseif (HeroHasTrait("AxeRecoveryAspect") or HeroHasTrait("AxeRecoveryAspect_Secondary")) then
		elseif HeroHasTrait("AxeRecoveryAspect") then
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxeYM_MeshShapeDeformed", false)
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxe_MeshShapeDeformed", true)

			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh", "WeaponAxeYM_MeshShapeDeformed", false)
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh", "WeaponAxeYMOutline_MeshShapeDeformed", false)
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh", "WeaponAxe_Rig_01:WeaponAxe_MeshShapeDeformed", false)
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh", "WeaponAxe_Rig_01:WeaponAxeOutline_MeshShapeDeformed", false)
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxeYMOutline_MeshShapeDeformed", false)
		end
	end
	
end)

ModUtil.Path.Wrap("MouseOverBounty", function(baseFunc, button )
	if button.Data.WeaponKitName ~= nil then
		if button.Data.WeaponUpgradeName == "StaffAspectofYoungMelinoe" then
			rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaffYM_MeshShapeDeformed", true)
        	rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaff_Rig:WeaponStaff_MeshShapeDeformed", false)
		elseif button.Data.WeaponUpgradeName == "BaseStaffAspect" then
			rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaffYM_MeshShapeDeformed", false)
        	rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaff_Rig:WeaponStaff_MeshShapeDeformed", true)
			--rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxeYMOutline_MeshShapeDeformed", false)
		elseif button.Data.WeaponUpgradeName == "SkullAspectofYoungMelinoe" then	
			rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLobYM_MeshShape", true)
        	rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLob_Rig:WeaponLob_MeshShape", false)
		elseif button.Data.WeaponUpgradeName == "LobAmmoBoostAspect" then	
			rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLobYM_MeshShape", false)
        	rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLob_Rig:WeaponLob_MeshShape", true)
		elseif button.Data.WeaponUpgradeName == "SuitAspectofYoungMelinoe" then
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBmultYM_MeshShape", true)
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBmultOutlineYM_MeshShape", true)
			
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBYM_MeshShape", false)
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBOutlineYM_MeshShape", false)
			
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitMultiple_Rig:WeaponSuitB_MeshShape", false)
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitMultiple_Rig:WeaponSuitBOutline_MeshShape", false)

			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBmultYM_MeshShape", false)
			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBmultOutlineYM_MeshShape", false)
			
			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBYM_MeshShape", true)
			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBOutlineYM_MeshShape", true)
			
			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitB_Rig:WeaponSuitB_MeshShape", false)
			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitB_Rig:WeaponSuitBOutline_MeshShape", false)
    	elseif button.Data.WeaponUpgradeName == "BaseSuitAspect" then
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBYM_MeshShape", false)
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBOutlineYM_MeshShape", false)
			
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBmultYM_MeshShape", false)
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitBmultOutlineYM_MeshShape", false)
			
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitMultiple_Rig:WeaponSuitB_MeshShape", true)
			rom.data.draw_set_mesh_visible("WeaponSuitMultiple_Base_Mesh", "WeaponSuitMultiple_Rig:WeaponSuitBOutline_MeshShape", true)

			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBYM_MeshShape", false)
			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBOutlineYM_MeshShape", false)
			
			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBYM_MeshShape", false)
			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitBOutlineYM_MeshShape", false)
			
			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitB_Rig:WeaponSuitB_MeshShape", true)
			rom.data.draw_set_mesh_visible("WeaponSuitB_Base_Mesh", "WeaponSuitB_Rig:WeaponSuitBOutline_MeshShape", true)
		end
		if config.Alter_Textures == false then
			if button.Data.WeaponUpgradeName == "AxeAspectofYoungMelinoe" then
				rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxeYM_MeshShapeDeformed", true)
				rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxe_MeshShapeDeformed", false)
			--elseif (HeroHasTrait("AxeRecoveryAspect") or HeroHasTrait("AxeRecoveryAspect_Secondary")) then
			elseif button.Data.WeaponUpgradeName == "AxeRecoveryAspect" then
				rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxeYM_MeshShapeDeformed", false)
				rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxe_MeshShapeDeformed", true)
			end
		end
	end
	baseFunc(button)
end)

ModUtil.Path.Wrap("CloseBountyBoardScreen",  function(baseFunc, screen, button )
	baseFunc(screen,button)
	--if (HeroHasTrait("StaffAspectofYoungMelinoe") or HeroHasTrait("StaffAspectofYoungMelinoe_Secondary")) then
	if HeroHasTrait("StaffAspectofYoungMelinoe") then
		rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaffYM_MeshShapeDeformed", true)
        rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaff_Rig:WeaponStaff_MeshShapeDeformed", false)
	--elseif (HeroHasTrait("BaseStaffAspect") or HeroHasTrait("BaseStaffAspect_Secondary"))then
	elseif HeroHasTrait("BaseStaffAspect") then
		rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaffYM_MeshShapeDeformed", false)
        rom.data.draw_set_mesh_visible("WeaponStaff_Mesh", "WeaponStaff_Rig:WeaponStaff_MeshShapeDeformed", true)
	--elseif (HeroHasTrait("SkullAspectofYoungMelinoe") or HeroHasTrait("SkullAspectofYoungMelinoe_Secondary")) then
	elseif HeroHasTrait("SkullAspectofYoungMelinoe") then
        rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLobYM_MeshShape", true)
        rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLob_Rig:WeaponLob_MeshShape", false)
    --elseif (HeroHasTrait("LobAmmoBoostAspect") or HeroHasTrait("LobAmmoBoostAspect_Secondary")) then
	elseif HeroHasTrait("LobAmmoBoostAspect") then
        rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLobYM_MeshShape", false)
        rom.data.draw_set_mesh_visible("WeaponLob_Mesh", "WeaponLob_Rig:WeaponLob_MeshShape", true)
	end
	if config.Alter_Textures == false then
		--if (HeroHasTrait("AxeAspectofYoungMelinoe") or HeroHasTrait("AxeAspectofYoungMelinoe_Secondary")) then
		if HeroHasTrait("AxeAspectofYoungMelinoe") then
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxeYM_MeshShapeDeformed", true)
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxe_MeshShapeDeformed", false)
		--elseif (HeroHasTrait("AxeRecoveryAspect") or HeroHasTrait("AxeRecoveryAspect_Secondary")) then
		elseif HeroHasTrait("AxeRecoveryAspect") then
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxeYM_MeshShapeDeformed", false)
			rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxe_MeshShapeDeformed", true)
		end
	end
end)

-- Steps to create new Aspects
	-- 1.Adding projectile data
	-- 2.Adding Effects to default attack with active=false
	-- 3.Loading Packge with new icon/texture/model
	-- 4.Adding new aspect
		--a.Icon
		--b.Mesh / Texture
		--c.Sounds
		--d.Trait
		--e.Modify attacks
	-- 5.Adding text of new Aspect
	-- 6.Adding god effects to FireFX / ProjectileFX
	-- 7.Modifying Hammers
	-- 8.Overwrite an existing aspect with the new one.

-- AxeAspectYoungMel - 1,2,3,4(a,b,c,d,e),5,6,7,8
-- StaffAspectYoungMel - 1,3,4(a,b,d,e),5,6,8
-- DaggerAspectYoungMel - 1,3,4(a,b,c,e),~5,6,8
-- SkullAspectYoungMel - 3,4(a,d,e),5,7,8

modutil.once_loaded.game(function()
	
	local file = rom.path.combine(rom.paths.Content, 'Game/Obstacles/Gameplay.sjson')
	sjson.hook(file, function(data)
	-- Axe Aspect of Young Mel special 
    	table.insert(data.Obstacles,{
			Name = "LobAmmoPackYM",
			InheritFrom = "BaseLoot",
			DisplayInEditor = true,
			Magnetism = 100.0,
			MagnetismSpeedMax = 2000.0,
			MagnetismSpeedMin = 1500.0,
			MagnetismWhileBlocked = 9999.0 ,
			RequiresUsable = true,
			Thing = 
			{
				EditorOutlineDrawBounds = false,
				Graphic = "LobProjectileIdle",
				OffsetZ = 60.0,
				StopsProjectiles = false,
				StopsUnits = false,
				Tallness = 25.0,
				TouchdownSound = "/SFX/Player Sounds/MelSkullsAmmoBounce",
				SortBoundsScale = 0.15,
				UseBoundsForSortDrawArea = true,
				Interact = 
				{
					AutoActivate = true,
					Distance = 50.0,
					UseableWhileInputDisabled = true,
				},
				Points =
				{
					{ X = 0, Y = 24 },
					{ X = 48, Y = 0 },
					{ X = 0, Y = -24 },
					{ X = -48, Y = 0 },
				},
			},
		})
		return data
		end)
	
	
	--Ensuring no problems with dagger textures
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDagger_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
	
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Pan_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Pan_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Pan_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Pan_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Pan_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Pan_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Pan_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Pan_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Pan_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Pan_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Pan_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Pan_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)

	rom.data.draw_set_mesh_visible("WeaponDaggerA_Artemis_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Artemis_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Artemis_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Artemis_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Artemis_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Artemis_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Artemis_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Artemis_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Artemis_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Artemis_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Artemis_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Artemis_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Morrigan_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Morrigan_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Morrigan_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Morrigan_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Morrigan_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Morrigan_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerB_Morrigan_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerA_Morrigan_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Morrigan_Mesh", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Morrigan_Mesh", "WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Morrigan_Mesh", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("WeaponDaggerMultiple_Morrigan_Mesh", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)
	

	--Removing Axe Shadow bug
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxeCharon_MeshShape", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxeCharonOutline_MeshShape", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxeNergal_MeshShape", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxeNergalOutline_MeshShape", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxeThanatos_MeshShape", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxe_Rig_01:WeaponAxeThanatosOutline_MeshShape", false)

	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponSuitBmultYM_MeshShape", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponSuitBmultOutlineYM_MeshShape", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponSuitBYM_MeshShape", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponSuitBOutlineYM_MeshShape", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponStaffYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponLobYM_MeshShape", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponAxeYMOutline_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponDaggerBYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponDaggerA_WeaponDaggerAYM_MeshShapeDeformed", false)
	rom.data.draw_set_mesh_visible("Melinoe_Axe_Mesh1", "WeaponDaggerB_WeaponDaggerBYM_MeshShapeDeformed", false)

	-- Changing Aspect text
	import "Aspects_text.lua"
	-- Changing the weapon effects, adding all possible aspects and switching new effects to inactive
	import "Aspects_weapon_effects.lua"

	-- import "Aspect_VFX.lua"	-- Adds new VFX for attacks, Inside Aspects_projectiles.lua
	-- Adds new projectiles
	import "Aspects_projectiles.lua"

	import "Aspects_weapon_data.lua"

		--Adds Animations
	--import "Aspects_Animations.lua"

	-- Adding Axe Aspect of Young Mel
	AxeAspectofYoungMelinoe = {
		InheritFrom = { "WeaponEnchantmentTrait" },
		RarityLevels =
		{
			Common =
			{
				Multiplier = 1.4,
			},
			Rare =
			{
				Multiplier = 1.8,
			},
			Epic =
			{
				Multiplier = 2.2,
			},
			Heroic =
			{
				Multiplier = 2.6,
			},
			Legendary =
			{
				Multiplier = 3,
			},
			Perfect =
			{
				Multiplier = 3.4,
			},
		},
		Icon = "JarlUlsfark-AspectYoungMel\\AxeAspectYoungMelIcon",
		RequiredWeapon = "WeaponAxe",
		WeaponKitGrannyModel = "Melinoe_Axe_Mesh1",
		ReplacementGrannyModels = 
		{
			Melinoe_Axe_Mesh1 = "Melinoe_Axe_Mesh1",
		},
		OnBlockDamageFunction = 
		{
			Name = _PLUGIN.guid .. "." .. "BlockAxeBuff",
			Args = 
			{
				MaxRetaliateBuff = { BaseValue = 1 },
				EffectName = "CastGripEffect",
				Duration = 3,
				ReportValues = 
				{ 
					MaxBuff = "MaxRetaliateBuff",

				}
			}
		},
		AddOutgoingDamageModifiers = {
			ValidWeapons = WeaponSets.HeroPrimaryWeapons,
			UseTraitValue = "RetaliateBuff",
			IsMultiplier = true,
		},
		RetaliateBuff = 1,
		WeaponDataOverride =
		{
			WeaponAxeSpecial =
			{
				Sounds =
				{
					FireSounds =
					{
						{ Name = "/SFX/Player Sounds/ZagreusFistWhoosh" },
					},
					ImpactSounds =
					{
						Invulnerable = "/SFX/Player Sounds/ZagreusShieldRicochet",
						Armored = "/SFX/Player Sounds/ZagreusShieldRicochet",
						Bone = "/SFX/Player Sounds/ShieldObstacleHit",
						Brick = "/SFX/Player Sounds/ShieldObstacleHit",
						Stone = "/SFX/Player Sounds/ShieldObstacleHit",
						Organic = "/SFX/Player Sounds/ShieldObstacleHit",
						StoneObstacle = "/SFX/SwordWallHitClankSmall",
						BrickObstacle = "/SFX/SwordWallHitClankSmall",
						MetalObstacle = "/SFX/SwordWallHitClankSmall",
						BushObstacle = "/Leftovers/World Sounds/LeavesRustle",
						Shell = "/SFX/ShellImpact",
					},
				},
			},
		},
		-- Changing special to Block
		PropertyChanges =
		{
			{
				WeaponName = "WeaponAxeSpecial",
				WeaponProperties = {
					Projectile = "ProjectileAxeBlockSpin",
					ExpireProjectilesOnFire = "ProjectileAxeSpin",
					DoProjectileBlockPresentation = true,
					DefaultKnockbackForce = 480,
					DefaultKnockbackScale = 0.6,
					ActiveProjectileCap = 1,
					FizzleOldSpawns = true,
					BlockedByAllOtherFireRequest = false,
					RootOwnerWhileFiring = true,
					FireFx = "null",
					FullyAutomatic = true,
					Cooldown = 0.4,
					AddOnFire = "WeaponAxeSpecialSwing",
				},
				ExcludeLinked = true,
			},
			{
				WeaponName = "WeaponAxeSpecialSwing",
				WeaponProperty = "Projectile",
				ChangeValue = "ProjectileAxeBlock2",
			},
			{
				WeaponName = "WeaponAxeSpecial",
				EffectName = "AxeSpecialBlockSelfTriggerLock",
    			EffectProperty = "Active",
    			ChangeValue = false,
    			ChangeType = "Absolute",
    			ExcludeLinked = true,
			},
			{
				WeaponName = "WeaponAxeSpecial",
				EffectName = "AxeSpecialDisable",
    			EffectProperty = "Active",
    			ChangeValue = false,
    			ChangeType = "Absolute",
    			ExcludeLinked = true,
			},
			{
				WeaponName = "WeaponAxeSpecial",
				EffectName = "AxeSpecialDisable",
    			EffectProperty = "Active",
    			ChangeValue = false,
    			ChangeType = "Absolute",
    			ExcludeLinked = true,
			},
			{
				WeaponName = "WeaponAxeSpecial",
				EffectName = "AxeSpecialDisableCancelable",
    			EffectProperty = "Active",
    			ChangeValue = false,
    			ChangeType = "Absolute",
    			ExcludeLinked = true,
			},
			{
				WeaponName = "WeaponAxeSpecial",
				EffectName = "AxeSpecialDisableMovementCancelable",
    			EffectProperty = "Active",
    			ChangeValue = false,
    			ChangeType = "Absolute",
    			ExcludeLinked = true,
			},
			{
				WeaponName = "WeaponAxeSpecial",
				EffectName = "ShieldSelfSpeed",
    			EffectProperty = "Active",
    			ChangeValue = true,
    			ChangeType = "Absolute",
    			ExcludeLinked = true,
			},
			{
				WeaponName = "WeaponAxeSpecial",
				EffectName = "ShieldSelfInvulnerableRush",
    			EffectProperty = "Active",
    			ChangeValue = true,
    			ChangeType = "Absolute",
    			ExcludeLinked = true,
			},
			{
				WeaponName = "WeaponAxeSpecial",
				EffectName = "ShieldSelfInvulnerableRush2",
    			EffectProperty = "Active",
    			ChangeValue = true,
    			ChangeType = "Absolute",
    			ExcludeLinked = true,
			},
			{
				WeaponName = "WeaponAxeSpecial",
				EffectName = "ShieldFireDisableAttack",
    			EffectProperty = "Active",
    			ChangeValue = true,
    			ChangeType = "Absolute",
    			ExcludeLinked = true,
			},
			{
				WeaponName = "WeaponAxeSpecial",
				EffectName = "ShieldChargeDisableMove",
    			EffectProperty = "Active",
    			ChangeValue = true,
    			ChangeType = "Absolute",
    			ExcludeLinked = true,
			},
			{
				WeaponName = "WeaponAxeSpecial",
				EffectName = "ShieldFireDisableMove2",
    			EffectProperty = "Active",
    			ChangeValue = true,
    			ChangeType = "Absolute",
    			ExcludeLinked = true,
			},
		},
		StatLines =
		{
			"AxeAspectYoungMelStat",
		},
		ExtractValues =
		{
			{
				Key = "MaxBuff",
				ExtractAs = "RetaliateDamage",
				Format = "PercentDelta",
			},
		},
		FlavorText = "AxeAspectofYoungMelinoe_FlavorText",
	}

	-- Adding Staff Aspect of Young Mel
	StaffAspectofYoungMelinoe = 
	{
		InheritFrom = { "WeaponEnchantmentTrait" },
		Icon = "JarlUlsfark-AspectYoungMel\\StaffAspectYoungMelIcon",
		RequiredWeapon = "WeaponStaffSwing",
		-- 'I have a good idea for a prank for this Asclepius character' ~Momus
		WeaponKitGrannyModel = "WeaponStaff_Mesh",
		ReplacementGrannyModels = 
		{
			WeaponStaff_Mesh = "WeaponStaff_Mesh"
		},
		RarityLevels =
		{
			Common =
			{
				Multiplier = 1,
			},
			Rare =
			{
				Multiplier = 1.333,
			},
			Epic =
			{
				Multiplier = 1.666,
			},
			Heroic =
			{
				Multiplier = 2,
			},
			Legendary =
			{
				Multiplier = 2.333,
			},
			Perfect =
			{
				Multiplier = 2.666,
			},
		},
		OnProjectileDeathFunction = 
		{
			Name = _PLUGIN.guid .. "." .. "CheckStaffSelfHit",
			ValidProjectiles = {"ProjectileStaffBallCharged"},
			Args = 
			{
				ProjectileName = "ProjectileStaffBallCharged",
				Threshold = { BaseValue = 0.3 },
				HealAmount = 5,
				ReportValues = 
				{ 
					ReportedThreshold = "Threshold" ,
					ReportedHeal = "HealAmount" 
				},
			}
		},
		ExtractValues =
		{
			{
				Key = "ReportedThreshold",
				ExtractAs = "HealthThreshold",
				Format = "Percent",
				SkipAutoExtract = true
			},
			{
				Key = "ReportedHeal",
				ExtractAs = "HealAmount",
				SkipAutoExtract = true
			},
		},
		StatLines =
		{
			"HealthThresholdStatDisplay"
		},
		PropertyChanges =
		{
			{
				WeaponName = "WeaponStaffBall",
				WeaponProperties = {
					Projectile = "ProjectileStaffBoltEA",
					InitialCooldown = 0,
					Cooldown = 0.4,
				},
				ExcludeLinked = true,
			},
		},
		FlavorText = "StaffAspectofYoungMelinoe_FlavorText",
	}


	-- Adding Dagger Aspect of Young Mel
	DaggerAspectofYoungMelinoe = 
	{
		InheritFrom = { "WeaponEnchantmentTrait" },
		Icon = "JarlUlsfark-AspectYoungMel\\DaggerAspectYoungMelIcon",
		RequiredWeapon = "WeaponDagger",
		WeaponKitGrannyModel = "WeaponDagger_Mesh",
		ReplacementGrannyModels = 
		{
			WeaponDaggerA_Mesh = "WeaponDaggerA_Mesh",
			WeaponDaggerB_Mesh = "WeaponDaggerB_Mesh"
		},
		RarityLevels =
		{
			Common =
			{
				Multiplier = 1.00,
			},
			Rare =
			{
				Multiplier = 1.15384,
			},
			Epic =
			{
				Multiplier = 1.2962,
			},
			Heroic =
			{
				Multiplier = 1.425000,
			},
			Legendary =
			{
				Multiplier = 1.54,
			},
			Perfect =
			{
				Multiplier = 1.673,
			},
		},
		WeaponDataOverride =
		{
			WeaponDaggerThrow = {
				ChargeWeaponStages =
					{
						{ ManaCost = 12, WeaponProperties = { Projectile = "ProjectileDaggerThrowEA", FireGraphic = "Melinoe_Dagger_SpecialEx_Fire", NumProjectiles = 3, AdditionalProjectileWaveChance = 0, ProjectileInterval = 0.08}, ApplyEffects = { "WeaponDaggerThrowEXDisable", "WeaponDaggerThrowEXDisableCancellable", "WeaponDaggerThrowEXDisableMoveHold" }, Wait = 0.32, HideStageReachedFx = true, ChannelSlowEventOnEnter = true },
						{ ManaCost = 16, WeaponProperties = { NumProjectiles = 4, AdditionalProjectileWaveChance = 0}, ApplyEffects = { "WeaponDaggerThrowEXDisable", "WeaponDaggerThrowEXDisableCancellable", "WeaponDaggerThrowEXDisableMoveHold" }, Wait = 0.14, HideStageReachedFx = true, },
						{ ManaCost = 20, WeaponProperties = { NumProjectiles = 5, AdditionalProjectileWaveChance = 0}, ApplyEffects = { "WeaponDaggerThrowEXDisable", "WeaponDaggerThrowEXDisableCancellable", "WeaponDaggerThrowEXDisableMoveHold" }, Wait = 0.14, HideStageReachedFx = true, },
						{ ManaCost = 24, WeaponProperties = { NumProjectiles = 6, AdditionalProjectileWaveChance = 0}, ApplyEffects = { "WeaponDaggerThrowEXDisable", "WeaponDaggerThrowEXDisableCancellable", "WeaponDaggerThrowEXDisableMoveHold" }, Wait = 0.14, },
					},
				Sounds = 
					{
						ImpactSounds = {
							Invulnerable = "/SFX/Player Sounds/ZagreusShieldRicochet",
							Armored = "/SFX/Player Sounds/ZagreusShieldRicochet",
							Bone = "/SFX/DaggerImpactWoodHard",
							Brick = "/SFX/DaggerImpactWoodSoft",
							Stone = "/SFX/DaggerImpactWoodSoft",
							Robot = "/SFX/MetalStoneClangShort",
							Organic = "/SFX/DaggerImpactOrganic",
							StoneObstacle = "/SFX/SwordWallHitClankSmall",
							BrickObstacle = "/SFX/SwordWallHitClankSmall",
							MetalObstacle = "/SFX/SwordWallHitClankSmall",
							BushObstacle = "/Leftovers/World Sounds/LeavesRustle",
							Shell = "/SFX/ShellImpact",
						}
					},
			},
		},
		PropertyChanges =
		{
			{
				WeaponNames = WeaponSets.HeroBlinkWeapons,
				WeaponProperty = "ClipRegenInterval",
				BaseValue = 0.8,
				SourceIsMultiplier = true,
				DecimalPlaces = 3,
				ChangeType = "Multiply",
				ReportValues = { ReportedReduction = "ChangeValue"},
			},
			{
				WeaponName = "WeaponDagger2",
				WeaponProperty = "SwapOnFire",
				ChangeValue = "WeaponDagger",
			},
			{
				WeaponName = "WeaponDagger",
				ProjectileName ="ProjectileDaggerSliceLeft",
				ProjectileProperty = "Damage",
				ChangeValue = 40,
				ChangeType = "Absolute"
			},
			{
				WeaponName = "WeaponDagger",
				WeaponProperty = "FireFx",
				ChangeValue = "DaggerSwipeFastBrown",
			},
			{
				WeaponName = "WeaponDagger2",
				ProjectileName ="ProjectileDaggerSliceRight",
				ProjectileProperty = "Damage",
				ChangeValue = 40,
				ChangeType = "Absolute"
			},
			{
				WeaponName = "WeaponDagger2",
				WeaponProperty = "FireFx",
				ChangeValue = "DaggerSwipeFastFlipBrown",
			},
			{
				WeaponName = "WeaponDaggerThrow",
				WeaponProperty = "Projectile",
				ChangeValue = "ProjectileDaggerThrowEA",
			},
			{
				WeaponName = "WeaponDaggerThrow",
				ProjectileName = "ProjectileDaggerThrowEA",
				ProjectileProperty = "Damage",
				ChangeValue = 50,
				ChangeType = "Absolute"
			},
		},
		StatLines =
		{
			"AspectDashRechargeStatDisplay",
		},
		ExtractValues =
		{
			{
				Key = "ReportedReduction",
				ExtractAs = "TooltipMultiplier",
				Format = "PercentReciprocalDelta",
			},
		},
		FlavorText = "DaggerAspectofYoungMelinoe_FlavorText",
	}
	
	SkullAspectofYoungMelinoe = 
	{
		InheritFrom = { "WeaponEnchantmentTrait" },
		Icon = "JarlUlsfark-AspectYoungMel\\SkullAspectYoungMelIcon",
		RequiredWeapon = "WeaponLob",
		WeaponKitGrannyModel = "WeaponLob_Mesh",
		ReplacementGrannyModels = 
		{
			WeaponLob_Mesh = "WeaponLob_Mesh"
		},
		RarityLevels =
		{
			Common =
			{
				Multiplier = 1.2,
			},
			Rare =
			{
				Multiplier = 1.3,
			},
			Epic =
			{
				Multiplier = 1.4,
			},
			Heroic =
			{
				Multiplier = 1.5,
			},
			Legendary =
			{
				Multiplier = 1.6,
			},
			Perfect =
			{
				Multiplier = 1.8,
			},
		},
		WeaponDataOverride = {
			WeaponLob = {
				OnProjectileDeathFunction = _PLUGIN.guid .. "." .. "WeaponLobAmmoDrop",
				OnProjectileDeathFunctionArgs = {
					CollideForces = 
					{
						UpwardForceMin = 300,
						UpwardForceMax = 800, 
						ForceMin = 840,
						ForceMax = 880,
						Scatter = 360,
					},
					DropForces = 
					{
						UpwardForceMin = 435,
						UpwardForceMax = 445,
						ForceMin = 500,
						ForceMax = 530,
						Scatter = 0,
					},
				},
				
				MagnetismMultiplier = 1,
			},
			WeaponLobSpecial = {
				MagnetismMultiplier = 1,
			},
		},
		SetupFunction =
		{
			Threaded = true,
			Name = _PLUGIN.guid .. "." .. "SetupComboUI",
		},
		OnUnequipFunctionName = _PLUGIN.guid .. "." .. "CheckComboUI",
		OnWeaponFiredFunctions = 
		{
			ValidWeapons = WeaponSets.HeroPrimaryWeapons,
			FunctionName = _PLUGIN.guid .. "." .. "ComboDamageMod",
			FunctionArgs = {
				Multiplier = { BaseValue = 1 },
				ReportValues = { ComboMult = "Multiplier" }
			},
		}, 
		OnEnemyDamagedAction = 
		{
			ValidWeapons = WeaponSets.HeroPrimaryWeapons,
			FunctionName = _PLUGIN.guid .. "." .. "ComboPresentation",
			FirstHitOnly = true,
			Args = {
				test =''
			},
		},
		AddOutgoingDamageModifiers = {
			ValidWeapons = WeaponSets.HeroPrimarySecondaryWeapons,
			UseTraitValue = "ComboDamageMod",
			IsMultiplier = true,
		},
		Combo = 0,
		ComboDamageMod = 1,
		StatLines =
		{
			"SkullAspectYoungMelStat",
		},
		ExtractValues =
		{
			{
				Key = "ComboMult",
				ExtractAs = "ComboMultiplier",
				Format = "PercentDelta",
			},
		},
		FlavorText = "SkullAspectofYoungMelinoe_FlavorText",
	}



	TorchAspectofYoungMelinoe = {
		InheritFrom = { "WeaponEnchantmentTrait" },
		PreEquipWeapons = { "WeaponCastYM", "WeaponCastHammerYM", "WeaponCastArmYM",  "WeaponCastArmHammerYM"},
		RarityLevels =
		{
			Common =
			{
				Multiplier = 1.05,
			},
			Rare =
			{
				Multiplier = 1.1,
			},
			Epic =
			{
				Multiplier = 1.15,
			},
			Heroic =
			{
				Multiplier = 1.2,
			},
			Legendary =
			{
				Multiplier = 1.25,
			},
			Perfect =
			{
				Multiplier = 1.4,
			},
		},
		Icon = "JarlUlsfark-AspectYoungMel\\TorchAspectYoungMelIcon",
		RequiredWeapon = "WeaponTorch",
		WeaponKitGrannyModel = "WeaponHecateMultiple_Mesh",
		ReplacementGrannyModels = 
		{
			WeaponTorchR_Mesh = "WeaponTorchR_Mesh",
			WeaponTorchL_Mesh = "WeaponTorchL_Mesh"
		},
		OnProjectileDeathFunction = {
			Name = _PLUGIN.guid .. "." .. "FireCastAtLocationYM",
			ValidProjectiles = { "ProjectileCastLobYM", "ProjectileCastLobChargeYM" },
		},
		WeaponDataOverride = {
			--WeaponTorch = {
				
			--	FirstTimeEquipAnimation = "Melinoe_Torch_Equip_YM",
			--	SwapAnimations =
			--	{
			--		["MelinoeIdle"] = "Melinoe_Torch_Idle_YM",	
			--		["MelinoeDashStart"] = "Melinoe_Torch_Dash_Start_YM",
			--		["MelinoeDash"] = "Melinoe_Torch_Dash_Fire_YM",	

			--		["MelinoeStart"] = "Melinoe_Torch_Run_Start_YM",


			--		["MelinoeGetHit"] = "Melinoe_Torch_GetHit_YM",
			--		["Melinoe_GetHit_LastStand"] = "Melinoe_Torch_GetHit_LastStand_YM",


			--		["MelinoeEquip"] = "Melinoe_Torch_Equip_YM",
			--		["MelinoeActionIdle"] = "Melinoe_Torch_Idle_YM",
			--		["Melinoe_Torch_Idle"] = "Melinoe_Torch_Idle_YM",
			--		["MelinoeBaseTorchAnimations"] = "MelinoeBaseTorchAnimations_YM",
			--	},
			--},
			WeaponTorchSpecial = {
				OnProjectileDeathFunction = "null",
				ChargeWeaponStages = 
				{
					{
						ManaCost = 0,
						--ManaCost = 15,
						Wait = 0.8,
						ChannelSlowEventOnStart = true,
						ForceRelease = true,
						WeaponProperties =
						{
							Projectile = "ProjectileCastLobYM",
							--Projectile = "ProjectileCastLobChargeYM",
							NumProjectiles = 1,
							ProjectileAngleStartOffset = 0,
							ProjectileAngleOffset = 0,
							FireGraphic = "Melinoe_Torch_Special1Ex_Fire",
							FireFx = "null",
							AdditionalProjectileWaveChance = 0,
						},
						ProjectileProperties = 
						{
							ArcEnd = 0,
						},
						CompleteObjective = "WeaponTorchSpecialCharged",
					},
				},
			},
		},
		PropertyChanges =
		{
			{
				WeaponName = "WeaponTorchSpecial",
				WeaponProperties = {
					Projectile = "ProjectileCastLobYM",
					ActiveProjectileCap = 1,
					Cooldown = 2,
					FireFx = "StaffProjectileFireFxRing",
					FireGraphic = "Melinoe_Cast_Fire_Quick",
					ChargeStartAnimation = "Melinoe_Cast_Start",
					ChargeCancelGraphic = "Melinoe_Cast_Fire_Quick",
					AutoLock = false,
					AutoLockRange = 1200,
					AutoLockArcDistance = 75,
					LockTriggerForCharge =false,
					FullyAutomatic = false,
					BlockMoveInput = true,
					RootOwnerWhileFiring = false,
					TargetReticleAnimation = "CastProjectileReticle",
					ShowFreeAimLine = true,
					AimLineAnimation = "null",
					ManualAiming = true,
					ManualAimingInitialOffset = 420,
					CancelMovement = true,
					ChargeCancelMovement = true,
					BarrelLength = 0,
					RetainAimLocationWindow = 0.95,
					ChargeStartFx = "CastFireBallCharge",
					ChargeFinishFx = "null",
					FailedToFireCooldownDuration = 0.1,
					AllowMultiFireRequest = false,
					SwapOnFire = "null",
					WeaponRange = 500,
					ProjectileSpacing = 0,
					IgnoreOwnerAttackDisabled = true,
					PriorityFireRequest = true,
					IgnoreUnitChargeMultiplier = true,
					FizzleOldSpawns = false,
					ProjectileAngleStartOffset = 0,
					ProjectileAngleOffset = 0,
					ActiveProjectileCap2 = 0,
					ActiveProjectileNameCap2 = "null",
				},
			},
			{
				WeaponName = "WeaponTorch",
				ProjectileName = "ProjectileTorchBall",
				ProjectileProperty = "Graphic",
				ChangeValue = "DionysusLobProjectile",
			},
			{
				WeaponName = "WeaponTorch",
				ProjectileName = "ProjectileTorchWave",
				ProjectileProperty = "Graphic",
				ChangeValue = "PoseidonSprintBallIn",
			},
			{
				WeaponName = "WeaponTorch",
				ProjectileName = "ProjectileTorchWave",
				ProjectileProperty = "AttachedAnim",
				ChangeValue = "MedusaShadow",
			},
		},
		AddOutgoingDamageModifiersArray = 
		{
			{
				ValidProjectiles = WeaponSets.OlympianProjectileNames,
				ValidWeaponMultiplier = {BaseValue = 1},
				ReportValues = { ReportedMultiplier = "ValidWeaponMultiplier"}
			},
			{
				ValidEffects = WeaponSets.OlympianEffectNames,
				ValidWeaponMultiplier = {BaseValue = 1},
			}
		},
		ExtractValues =
		{
			{
				Key = "ReportedMultiplier",
				ExtractAs = "OlympicBoonsYM",
				Format = "PercentDelta",
			},
		},
		StatLines = {
			"TorchAspectYoungMelStat"
		},
		FlavorText = "TorchAspectofYoungMelinoe_FlavorText",
	}

	SuitAspectofYoungMelinoe = {
		InheritFrom = { "WeaponEnchantmentTrait", "CostumeTrait" },
		Icon = "JarlUlsfark-AspectYoungMel\\SuitAspectYoungMelIcon",
		RequiredWeapon = "WeaponSuit",
		PreEquipWeapons = { "WeaponSuit3" },
		WeaponKitGrannyModel = "WeaponSuitMultiple_Base_Mesh",
		ReplacementGrannyModels = 
		{
			WeaponSuitR_Base_Mesh = "WeaponSuitR_Base_Mesh",
			WeaponSuitL_Base_Mesh = "WeaponSuitL_Base_Mesh",
			WeaponSuitB_Base_Mesh = "WeaponSuitB_Base_Mesh",
		},
		RarityLevels =
		{
			Common =
			{
				Multiplier = 1.0,
			},
			Rare =
			{
				Multiplier = 2.0,
			},
			Epic =
			{
				Multiplier = 3.0,
			},
			Heroic =
			{
				Multiplier = 4.0,
			},
			Legendary =
			{
				Multiplier = 5.0,
			},
			Perfect =
			{
				Multiplier = 7.5,
			},
		},
		SetupFunction =
		{
			Name = "CostumeArmor",
			Args =
			{
				Source = "Aspect",
				Delay = 0.75,
				BaseAmount = { BaseValue = 20 },
				ReportValues = 
				{ 
					ReportedArmor = "BaseAmount",
				},
			},
		},
		ExtractValues =
		{
			{
				Key = "ReportedArmor",
				ExtractAs = "TooltipAmount",
			},
		},
		WeaponDataOverride = {
			--WeaponSuit = {
			--	SwapAnimations =
			--	{
			--		["MelinoeSprint"] = "Melinoe_Suit_Sprint_FireLoop_YM",
			--		["MelinoeStart"] = "Melinoe_Suit_Run_Start_YM",
			--		["MelinoeRun"] = "Melinoe_Suit_Run_FireLoop_YM",
			--	},
			--	FirstTimeEquipAnimation = "null",
			--},
			WeaponSuitCharged = {
				ChargeWeaponStages =
					{
						{ ManaCost = 1, Force = 700, Scale =2, WeaponProperties = { NumProjectiles = 2, ProjectileInterval = 0.08, ProjectileAngleOffset = math.rad(20), AdditionalProjectileWaveChance = 0, FireGraphic = "Melinoe_Suit_AttackExPunch_Start", DamageMultiplier  = 1 }, Wait = 0.15, HideStageReachedFx = true },
						{ ManaCost = 2, Force = 725, Scale =2, WeaponProperties = { DamageMultiplier  = 1.13 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 3, Force = 750, Scale =2, WeaponProperties = { DamageMultiplier = 1.26 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 4, Force = 775, Scale =2, WeaponProperties = { DamageMultiplier = 1.39 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 5, Force = 800, Scale =2, WeaponProperties = { DamageMultiplier = 1.52 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 6, Force = 825, Scale =2, WeaponProperties = { DamageMultiplier = 1.65 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 7, Force = 850, Scale =2, WeaponProperties = { DamageMultiplier = 1.78 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 8, Force = 875, Scale =2, WeaponProperties = { DamageMultiplier = 1.91 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 9, Force = 900, Scale =2, WeaponProperties = { DamageMultiplier = 2.04 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 10, Force = 900, Scale =2, WeaponProperties = { DamageMultiplier = 2.17 }, Wait = 0.05, HideStageReachedFx = true },

						{ ManaCost = 11, Force = 900, WeaponProperties = { NumProjectiles = 3, DamageMultiplier  = 2.30 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 12, Force = 900, WeaponProperties = { DamageMultiplier = 2.43 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 13, Force = 900, WeaponProperties = { DamageMultiplier = 2.57 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 14, Force = 900, WeaponProperties = { DamageMultiplier = 2.70 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 15, Force = 900, WeaponProperties = { DamageMultiplier = 2.83 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 16, Force = 900, WeaponProperties = { DamageMultiplier = 2.96 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 17, Force = 900, WeaponProperties = { DamageMultiplier = 3.09 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 18, Force = 900, WeaponProperties = { DamageMultiplier = 3.22 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 19, Force = 900, WeaponProperties = { DamageMultiplier = 3.35 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 20, Force = 900, WeaponProperties = { DamageMultiplier = 3.48 }, Wait = 0.05, HideStageReachedFx = true },

						{ ManaCost = 21, Force = 900, WeaponProperties = { NumProjectiles = 4, DamageMultiplier  = 3.61 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 22, Force = 900, WeaponProperties = { DamageMultiplier = 3.74 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 23, Force = 900, WeaponProperties = { DamageMultiplier = 3.87 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 24, Force = 900, WeaponProperties = { DamageMultiplier = 4.00 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 25, Force = 900, WeaponProperties = { DamageMultiplier = 4.13 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 26, Force = 900, WeaponProperties = { DamageMultiplier = 4.26 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 27, Force = 900, WeaponProperties = { DamageMultiplier = 4.39 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 28, Force = 900, WeaponProperties = { DamageMultiplier = 4.52 }, Wait = 0.05, HideStageReachedFx = true },
						{ ManaCost = 29, Force = 900, WeaponProperties = { DamageMultiplier = 4.65 }, Wait = 0.05, HideStageReachedFx = true },

						{ ManaCost = 30, Force = 900, WeaponProperties = { NumProjectiles = 5, DamageMultiplier = 5.00 }, Wait = 0.1, ForceRelease = true, BlockForceReleaseWithoutMana = true},
					},
			},
			WeaponSuit2 = {
				InheritFrom = { "WeaponSuit", },
			},
			WeaponSuit3 = {
				InheritFrom = { "WeaponSuit", },
			},
		},
		PropertyChanges =
		{
			{
				WeaponName = "WeaponSuit",
				WeaponProperties = {
					SwapOnFire = "WeaponSuit",
					BlockMoveInput = true,
					CancelMovement = true,
					Cooldown = 0.6,
					FireGraphic = "Melinoe_Suit_SpecialMissile_FireQuick",
					RootOwnerWhileFiring = true,
					SelfVelocity = -500,
				},
			},
			{
				WeaponName = "WeaponSuit",
				WeaponProperty = "Projectile",
				ChangeValue = "HarpyFlapFast_YM",
			},
			{
				WeaponName = "WeaponSuit2",
				WeaponProperty = "Projectile",
				ChangeValue = "HarpyFlapFast2_YM",
			},
			{
				WeaponName = "WeaponSuit3",
				WeaponProperty = "Projectile",
				ChangeValue = "HarpyFlapFast3_YM",
			},
			{
				WeaponName = "WeaponSuit",
				WeaponProperty = "FireGraphic",
				ChangeValue = "Melinoe_Suit_SpecialMissile_FireQuick",
			},
			{
				WeaponName = "WeaponSuitCharged",
				WeaponProperty = "Projectile",
				ChangeValue = "HarpyFlapFastCharge_YM",
			},
		},
		StatLines = {
			"SuitAspectYoungMelStat",
		},
		FlavorText = "SuitAspectofYoungMelinoe_FlavorText",
	}

	--OverwriteTableKeys( TraitSetData.Aspects.BaseSuitAspect, SuitAspectofYoungMelinoe)
	
	TraitData.StaffAspectofYoungMelinoe = StaffAspectofYoungMelinoe
	TraitData.DaggerAspectofYoungMelinoe = DaggerAspectofYoungMelinoe
	TraitData.TorchAspectofYoungMelinoe = TorchAspectofYoungMelinoe
	TraitData.AxeAspectofYoungMelinoe = AxeAspectofYoungMelinoe
	TraitData.SkullAspectofYoungMelinoe = SkullAspectofYoungMelinoe
	TraitData.SuitAspectofYoungMelinoe = SuitAspectofYoungMelinoe


	--Adds the new traits to the in-game shop
	import "Aspect_weaponshop.lua"

	--Adding special boons for the torch
	import "Aspect_Torch_boons.lua"

	--Adds god specific VFX
	import "Aspects_god_effects.lua"

	--Adds/removes Aspect specific hammers
	import "Aspects_hammers.lua"

	--Adds minor propechies
	import "Aspects_Quests.lua"

	--Adds Bounties
	import "Aspects_Bounty.lua"

	--Adds Arcana backs
	import "Aspects_Cosmetics.lua"

	--Add Speeches
	import "Aspects_Conversations.lua"



end)
