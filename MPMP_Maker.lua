-- MPMP_Maker
-- Author: Gedemon
-- DateCreated: 31-Jan-14 03:16:29
--------------------------------------------------------------
--[[
	Allow the creation of a MPModspack folder in assets/DLC to copy (and format) activated mods

	todo: 
		- create a "desinstall" mod with a copy of all UI files that are loaded in the MPModspack so that they can be removed if that mod is activated (they should override the DLC UI files). That "MPModpack desinstallation" mod would be deleted/recreated each time a MP modspack is created
		- then make sure we are not copying in the DLC folder some files that can't be loaded with mods !
		- create a small additional DLC (optional installation, as this one would require manual desinstallation) to handle automatically the launch of a small game session to configure the MP Modspack when entering the mod's menu
		- artdefines for everything, not just unit (try a direct DB copy first <- maybe this would work too for units...)
		- the UI...
		- handle DLL mods that may need renaming (see also limitations as a DLL with the mandatory Game function must be loaded)

	usage: 
		- activate all desired mods, launch a new game from the mods menu, and from "MPMP_Maker" context in Firetuner call CreateMP()
		- check MPMPMaker.log for errors (but I need to add a lot more in it, actually it can output "done" even if something goes wrong) after creation
		- quit game (not to main menu, completly !)
		- start civ5 again, launch a new game from the main menu, all mods should be activated
		- check database.log if the game crashes before the main menu, or if there are errors in the Lua.log
	
	limitations : 
		- you must manually delete the MP_MODSPACK folder in Steam\steamapps\common\sid meier's civilization v\Assets\DLC if you want to use the normal game again
		- a savegame can't know if a modspack is used
		- how to check for same modspack in MP ?
		- what if other DLC are activated/deactivated while the modpack is active ?
		- only tested with G+K and BNW activated, will surely crash if only vanilla game is used. We may need to create 3 FileTableList for each version of the game, or a file parser to get the tables structures from the game's files.
		- can't be used with DLL mods without merging both projects (C++ and this lua file as an InGameUIaddin)
		- all mods won't work in MP, changing gameplay could cause massive desync issues if not done with MP in mind
--]]


--local GamePlayFileName = "CIV5Units.xml" -- that's where we write the whole database -> doesn't work, so use FileTableList for individual file instead. LastGamePlayFileName and textFileName will need to be changed too (maybe I should append the text files to one of the vanilla gameplay files.
local LastGamePlayFileName = "CIV5GameOptions_Expansion2.xml" -- that's where we create the tables added by mods
local textFileName = "CIV5Concepts_Expansion2.xml" -- that's where we put the text database. (we can't use override for the text files, the localization is handled separately)
local AudioFileName = "CIV5GreatWorks_Expansion2.xml" -- that's where we put the audio database. (we can't change the structure on this one)
local MPMPMakerModID = "c70dee73-8179-4a19-a3e5-1d931908ff43" -- we don't want to include this mod in the modspack


-- We need to know in wich file goes which tables to set the tables structure on initialisation... 
-- We can't simply update existing tables from the last file, as some mods may change the structure...
local FileTableList = {
	{ FileName = "GlobalDefines.xml", TableList = {"Defines", "PostDefines"}}, -- also include GlobalAIDefines and GlobalDiplomacyAIDefines

	{ FileName = "CIV5AICityStrategies.xml", TableList = {"AICityStrategies", "AICityStrategy_Flavors", "AICityStrategy_PersonalityFlavorThresholdMods"}},	
	{ FileName = "CIV5AIEconomicStrategies.xml", TableList = {"AIEconomicStrategies", "AIEconomicStrategy_Player_Flavors", "AIEconomicStrategy_City_Flavors", "AIEconomicStrategy_PersonalityFlavorThresholdMods"}},
	{ FileName = "CIV5AIGrandStrategies.xml", TableList = {"AIGrandStrategies", "AIGrandStrategy_Flavors", "AIGrandStrategy_Yields", "AIGrandStrategy_FlavorMods"}},
	{ FileName = "CIV5AIMilitaryStrategies.xml", TableList = {"AIMilitaryStrategies", "AIMilitaryStrategy_Player_Flavors", "AIMilitaryStrategy_City_Flavors", "AIMilitaryStrategy_PersonalityFlavorThresholdMods"}},
	{ FileName = "Civ5AnimationCategories.xml", TableList = {"AnimationCategories"}},
	{ FileName = "Civ5AnimationPaths.xml", TableList = {"AnimationPaths", "AnimationPath_Entries"}},
	{ FileName = "CIV5ArtStyleTypes.xml", TableList = {"ArtStyleTypes"}},
	{ FileName = "CIV5Attitudes.xml", TableList = {"Attitudes"}},
	{ FileName = "CIV5Automates.xml", TableList = {"Automates"}},
	{ FileName = "CIV5Beliefs.xml", TableList = {"Beliefs", "Belief_BuildingClassYieldChanges", "Belief_BuildingClassHappiness", "Belief_BuildingClassTourism", "Belief_BuildingClassFaithPurchase", "Belief_CityYieldChanges", "Belief_HolyCityYieldChanges", "Belief_EraFaithUnitPurchase", "Belief_FeatureYieldChanges", "Belief_ImprovementYieldChanges", "Belief_MaxYieldModifierPerFollower", "Belief_ResourceQuantityModifiers", "Belief_ResourceHappiness", "Belief_ResourceYieldChanges", "Belief_TerrainYieldChanges", "Belief_YieldChangeAnySpecialist", "Belief_YieldChangePerForeignCity", "Belief_YieldChangePerXForeignFollowers", "Belief_YieldChangeTradeRoute", "Belief_YieldChangeNaturalWonder", "Belief_YieldChangeWorldWonder", "Belief_YieldModifierNaturalWonder"}},
	{ FileName = "CIV5BuildingClasses.xml", TableList = {"BuildingClasses", "BuildingClass_VictoryThresholds"}},
	{ FileName = "CIV5Buildings.xml", TableList = {"Buildings", "Building_AreaYieldModifiers", "Building_BuildingClassHappiness", "Building_BuildingClassYieldChanges", "Building_ClassesNeededInCity", "Building_FreeUnits", "Building_DomainFreeExperiences", "Building_DomainFreeExperiencePerGreatWork", "Building_DomainProductionModifiers", "Building_FreeSpecialistCounts", "Building_Flavors", "Building_GlobalYieldModifiers", "Building_HurryModifiers", "Building_LocalResourceAnds", "Building_LocalResourceOrs", "Building_LockedBuildingClasses", "Building_PrereqBuildingClasses", "Building_ResourceQuantity", "Building_ResourceQuantityRequirements", "Building_ResourceYieldModifiers", "Building_ResourceCultureChanges", "Building_ResourceFaithChanges", "Building_RiverPlotYieldChanges", "Building_SeaPlotYieldChanges", "Building_LakePlotYieldChanges", "Building_SeaResourceYieldChanges", "Building_ResourceYieldChanges", "Building_FeatureYieldChanges", "Building_TerrainYieldChanges", "Building_SpecialistYieldChanges", "Building_UnitCombatFreeExperiences", "Building_UnitCombatProductionModifiers", "Building_TechAndPrereqs", "Building_YieldChanges", "Building_YieldChangesPerPop", "Building_YieldChangesPerReligion", "Building_TechEnhancedYieldChanges", "Building_YieldModifiers", "Building_ThemingBonuses"}},
	{ FileName = "CIV5Builds.xml", TableList = {"Builds", "BuildFeatures", "Build_TechTimeChanges"}},
	{ FileName = "CIV5Calendars.xml", TableList = {"Calendars"}},
	{ FileName = "CIV5CitySizes.xml", TableList = {"CitySizes"}},
	{ FileName = "CIV5CitySpecializations.xml", TableList = {"CitySpecializations", "CitySpecialization_Flavors", "CitySpecialization_TargetYields"}},
	{ FileName = "CIV5Civilizations.xml", TableList = {"Civilizations", "Civilization_BuildingClassOverrides",  "Civilization_CityNames", "Civilization_DisableTechs", "Civilization_FreeBuildingClasses", "Civilization_FreeTechs", "Civilization_FreeUnits", "Civilization_Leaders", "Civilization_Religions", "Civilization_SpyNames", "Civilization_UnitClassOverrides", "Civilization_Start_Along_Ocean", "Civilization_Start_Along_River", "Civilization_Start_Region_Priority", "Civilization_Start_Region_Avoid", "Civilization_Start_Place_First_Along_Ocean"}},
	{ FileName = "CIV5Climates.xml", TableList = {"Climates"}},
	{ FileName = "CIV5Colors.xml", TableList = {"Colors"}},
	{ FileName = "CIV5Commands.xml", TableList = {"Commands"}},
	{ FileName = "CIV5Concepts.xml", TableList = {"Concepts", "Concepts_RelatedConcept"}},
	{ FileName = "CIV5Contacts.xml", TableList = {"Contacts"}},
	{ FileName = "CIV5Controls.xml", TableList = {"Controls"}},
	--{ FileName = "CIV5CultureLevels.xml", TableList = {"CultureLevels", "CultureLevel_SpeedThresholds"}}, -- table does not exist in BNW  ?
	{ FileName = "CIV5Cursors.xml", TableList = {"Cursors"}},
	{ FileName = "CIV5DenialInfos.xml", TableList = {"DenialInfos"}},
	{ FileName = "Civ5Diplomacy_Responses.xml", TableList = {"Diplomacy_Responses"}},
	{ FileName = "CIV5Domains.xml", TableList = {"Domains"}},
	{ FileName = "CIV5EmphasizeInfos.xml", TableList = {"EmphasizeInfos", "EmphasizeInfo_Yields"}},
	{ FileName = "Civ5EntityEvents.xml", TableList = {"EntityEvents", "EntityEvent_AnimationPaths"}},
	{ FileName = "CIV5Eras.xml", TableList = {"Eras", "Era_Soundtracks", "Era_CitySoundscapes", "Era_NewEraVOs"}},
	{ FileName = "CIV5Features.xml", TableList = {"Features", "FakeFeatures", "Feature_YieldChanges", "Feature_RiverYieldChanges", "Feature_HillsYieldChanges", "Feature_TerrainBooleans", "Natural_Wonder_Placement"}},
	{ FileName = "CIV5Flavors.xml", TableList = {"Flavors"}},
	{ FileName = "CIV5GameOptions.xml", TableList = {"GameOptions"}},
	{ FileName = "CIV5GameSpeeds.xml", TableList = {"GameSpeeds", "GameSpeed_Turns"}},
	{ FileName = "CIV5GoodyHuts.xml", TableList = {"GoodyHuts"}},
	{ FileName = "CIV5GreatWorks_Expansion2.xml", TableList = {"GreatWorkSlots", "GreatWorkClasses", "GreatWorks", "GreatWorkArtifactClasses"}},
	{ FileName = "CIV5HandicapInfos.xml", TableList = {"HandicapInfos", "HandicapInfo_Goodies", "HandicapInfo_FreeTechs", "HandicapInfo_AIFreeTechs"}},
	{ FileName = "CIV5HurryInfos.xml", TableList = {"HurryInfos"}},
	{ FileName = "CIV5IconFontMapping.xml", TableList = {"IconFontTextures", "IconFontMapping"}},
	{ FileName = "CIV5IconTextureAtlases.xml", TableList = {"IconTextureAtlases"}}, --, "IconTextureAtlases_Index"}}, -- IconTextureAtlases_Index does not exist in BNW
	{ FileName = "CIV5Improvements.xml", TableList = {"Improvements", "Improvement_Flavors", "Improvement_Yields", "Improvement_YieldPerEra", "Improvement_AdjacentCityYields", "Improvement_CoastalLandYields", "Improvement_FreshWaterYields", "Improvement_HillsYields", "Improvement_AdjacentMountainYieldChanges", "Improvement_PrereqNatureYields", "Improvement_RiverSideYields", "Improvement_ValidTerrains", "Improvement_ValidFeatures", "Improvement_ValidImprovements", "Improvement_ResourceTypes", "Improvement_ResourceType_Yields", "Improvement_RouteYieldChanges", "Improvement_TechYieldChanges", "Improvement_TechNoFreshWaterYieldChanges", "Improvement_TechFreshWaterYieldChanges"}},
	{ FileName = "CIV5InterfaceModes.xml", TableList = {"InterfaceModes"}},
	{ FileName = "CIV5InvisibleInfos.xml", TableList = {"InvisibleInfos"}},
	{ FileName = "CIV5LeaderTables.xml", TableList = {"Leaders", "Leader_MajorCivApproachBiases", "Leader_MinorCivApproachBiases", "Leader_Flavors", "Leader_Traits"}},
	{ FileName = "CIV5MajorCivApproachTypes.xml", TableList = {"MajorCivApproachTypes"}},
	{ FileName = "CIV5MemoryInfos.xml", TableList = {"MemoryInfos"}},
	{ FileName = "CIV5MinorCivApproachTypes.xml", TableList = {"MinorCivApproachTypes"}},
	{ FileName = "CIV5MinorCivilizations.xml", TableList = {"MinorCivilizations", "MinorCivilization_Flavors", "MinorCivilization_CityNames"}},
	{ FileName = "CIV5MinorCivTraits.xml", TableList = {"MinorCivTraits", "MinorCivTraits_Status"}},
	{ FileName = "CIV5Missions.xml", TableList = {"Missions"}},

	--{ FileName = "CIV5ModdingText.xml", TableList = {"Language_en_US"}}, --<- maybe we can put the modded text here, but not from this table, and with replace tags...
	
	{ FileName = "CIV5Months.xml", TableList = {"Months"}},
	{ FileName = "CIV5MultiplayerOptions.xml", TableList = {"MultiplayerOptions"}},
	{ FileName = "CIV5MultiUnitFormations.xml", TableList = {"MultiUnitPositions", "MultiUnitFormations", "MultiUnitFormation_SlotEntries"}},
	{ FileName = "CIV5PlayerColors.xml", TableList = {"PlayerColors"}},
	{ FileName = "CIV5PlayerOptions.xml", TableList = {"PlayerOptions"}},
	{ FileName = "CIV5Policies.xml", TableList = {"Policies", "Policy_CityYieldChanges", "Policy_CoastalCityYieldChanges", "Policy_CapitalYieldChanges", "Policy_CapitalYieldPerPopChanges", "Policy_CapitalYieldModifiers", "Policy_Disables", "Policy_Flavors", "Policy_GreatWorkYieldChanges", "Policy_HurryModifiers", "Policy_PrereqPolicies", "Policy_PrereqORPolicies", "Policy_SpecialistExtraYields", "Policy_BuildingClassYieldModifiers", "Policy_BuildingClassYieldChanges", "Policy_BuildingClassCultureChanges", "Policy_BuildingClassProductionModifiers", "Policy_BuildingClassTourismModifiers", "Policy_BuildingClassHappiness", "Policy_ImprovementYieldChanges", "Policy_ImprovementCultureChanges", "Policy_ValidSpecialists", "Policy_YieldModifiers", "Policy_FreePromotions", "Policy_UnitCombatFreeExperiences", "Policy_FreePromotionUnitCombats", "Policy_UnitCombatProductionModifiers", "Policy_FreeUnitClasses", "Policy_TourismOnUnitCreation", "Policy_FreeItems"}},
	{ FileName = "CIV5PolicyBranchTypes.xml", TableList = {"PolicyBranchTypes", "PolicyBranch_Disables"}},
	{ FileName = "CIV5Processes.xml", TableList = {"Processes", "Process_Flavors", "Process_ProductionYields"}},
	{ FileName = "CIV5Projects.xml", TableList = {"Projects", "Project_Flavors", "Project_Prereqs", "Project_VictoryThresholds", "Project_ResourceQuantityRequirements"}},	
	{ FileName = "CIV5Regions.xml", TableList = {"Regions"}},
	{ FileName = "Civ5Religions.xml", TableList = {"Religions"}},
	{ FileName = "CIV5Resolutions.xml", TableList = {"LeagueSpecialSessions", "LeagueNames", "LeagueProjectRewards", "LeagueProjects", "ResolutionDecisions", "Resolutions"}},
	{ FileName = "CIV5Replays.xml", TableList = {"ReplayDataSets"}},
	{ FileName = "CIV5ResourceClasses.xml", TableList = {"ResourceClasses"}},
	{ FileName = "CIV5Resources.xml", TableList = {"Resources", "Resource_YieldChanges", "Resource_Flavors", "Resource_TerrainBooleans", "Resource_FeatureBooleans", "Resource_FeatureTerrainBooleans", "Resource_QuantityTypes"}},
	{ FileName = "CIV5Routes.xml", TableList = {"Routes", "Route_Yields", "Route_TechMovementChanges", "Route_ResourceQuantityRequirements"}},
	{ FileName = "CIV5SeaLevels.xml", TableList = {"SeaLevels"}},
	{ FileName = "CIV5Seasons.xml", TableList = {"Seasons"}},
	{ FileName = "CIV5SmallAwards.xml", TableList = {"SmallAwards"}},
	{ FileName = "CIV5Specialists.xml", TableList = {"Specialists", "SpecialistFlavors", "SpecialistYields"}},
	{ FileName = "CIV5SpecialUnits.xml", TableList = {"SpecialUnits", "SpecialUnit_CarrierUnitAI", "SpecialUnit_ProductionTraits"}},
	{ FileName = "CIV5TacticalMoves.xml", TableList = {"TacticalMoves"}},
	{ FileName = "CIV5Technologies.xml", TableList = {"Technologies", "Technology_DomainExtraMoves", "Technology_TradeRouteDomainExtraRange", "Technology_Flavors", "Technology_ORPrereqTechs", "Technology_PrereqTechs", "Technology_FreePromotions"}},
	{ FileName = "CIV5Terrains.xml", TableList = {"Terrains", "Terrain_Yields", "Terrain_RiverYieldChanges", "Terrain_HillsYieldChanges"}},
	{ FileName = "CIV5Trades.xml", TableList = {"Trades"}},
	{ FileName = "CIV5Traits.xml", TableList = {"Traits", "Trait_ExtraYieldThresholds", "Trait_YieldChanges", "Trait_YieldChangesStrategicResources", "Trait_YieldChangesNaturalWonder", "Trait_YieldChangesPerTradePartner", "Trait_YieldChangesIncomingTradeRoute", "Trait_YieldModifiers", "Trait_FreePromotions", "Trait_FreePromotionUnitCombats", "Trait_MovesChangeUnitCombats", "Trait_MaintenanceModifierUnitCombats", "Trait_Terrains", "Trait_ResourceQuantityModifiers", "Trait_FreeResourceFirstXCities", "Trait_ImprovementYieldChanges", "Trait_SpecialistYieldChanges", "Trait_UnimprovedFeatureYieldChanges", "Trait_NoTrain"}},
	{ FileName = "CIV5TurnTimers.xml", TableList = {"TurnTimers"}},
	{ FileName = "CIV5UnitAIInfos.xml", TableList = {"UnitAIInfos"}},
	{ FileName = "CIV5UnitClasses.xml", TableList = {"UnitClasses"}},
	{ FileName = "CIV5UnitCombatInfos.xml", TableList = {"UnitCombatInfos"}},
	{ FileName = "CIV5UnitMovementRates.xml", TableList = {"MovementRates"}},
	{ FileName = "CIV5UnitPromotions.xml", TableList = {"UnitPromotions", "UnitPromotions_Terrains", "UnitPromotions_Features", "UnitPromotions_UnitClasses", "UnitPromotions_Domains", "UnitPromotions_UnitCombatMods", "UnitPromotions_UnitCombats", "UnitPromotions_CivilianUnitType", "UnitPromotions_PostCombatRandomPromotion"}},
	{ FileName = "CIV5Units.xml", TableList = {"CivilianAttackPriorities", "Units", "Unit_AITypes", "Unit_Buildings", "Unit_BuildingClassRequireds", "Unit_ProductionModifierBuildings", "Unit_Builds", "Unit_ClassUpgrades", "Unit_FreePromotions", "Unit_Flavors", "Unit_GreatPersons", "Unit_ResourceQuantityRequirements", "Unit_UniqueNames", "Unit_YieldFromKills", "Unit_NotAITypes", "Unit_ProductionTraits", "Unit_TechTypes"}},
	{ FileName = "CIV5Victories.xml", TableList = {"Victories", "VictoryPointAwards", "HistoricRankings"}},
	{ FileName = "CIV5Votes.xml", TableList = {"Votes", "Vote_DiploVotes"}},
	{ FileName = "CIV5VoteSources.xml", TableList = {"VoteSources"}},
	{ FileName = "CIV5Worlds.xml", TableList = {"Worlds"}},
	{ FileName = "CIV5Yields.xml", TableList = {"Yields"}},
	{ FileName = "Notifications.xml", TableList = {"Notifications"}},
}

-- Audio tables are handled separatly
local audioTableListe = {"Audio_2DSounds", "Audio_3DSounds", "Audio_ScriptTypes", "Audio_SoundLoadTypes", "Audio_SoundScapeElementScripts", "Audio_SoundScapeElements", "Audio_SoundScapes", "Audio_SoundTypes", "Audio_Sounds"}

-- List of the original tables
local checkOriginalTableListe = { 
	["AICityStrategies"] = true,
	["AICityStrategy_Flavors"] = true,
	["AICityStrategy_PersonalityFlavorThresholdMods"] = true,
	["AIEconomicStrategies"] = true,
	["AIEconomicStrategy_City_Flavors"] = true,
	["AIEconomicStrategy_PersonalityFlavorThresholdMods"] = true,
	["AIEconomicStrategy_Player_Flavors"] = true,
	["AIGrandStrategies"] = true,
	["AIGrandStrategy_FlavorMods"] = true,
	["AIGrandStrategy_Flavors"] = true,
	["AIGrandStrategy_Yields"] = true,
	["AIMilitaryStrategies"] = true,
	["AIMilitaryStrategy_City_Flavors"] = true,
	["AIMilitaryStrategy_PersonalityFlavorThresholdMods"] = true,
	["AIMilitaryStrategy_Player_Flavors"] = true,
	["AnimationCategories"] = true,
	["AnimationPath_Entries"] = true,
	["AnimationPaths"] = true,
	["ApplicationInfo"] = true,
	["ArtDefine_LandmarkTypes"] = true,
	["ArtDefine_Landmarks"] = true,
	["ArtDefine_StrategicView"] = true,
	["ArtDefine_UnitInfoMemberInfos"] = true,
	["ArtDefine_UnitInfos"] = true,
	["ArtDefine_UnitMemberCombatWeapons"] = true,
	["ArtDefine_UnitMemberCombats"] = true,
	["ArtDefine_UnitMemberInfos"] = true,
	["ArtStyleTypes"] = true,
	["Attitudes"] = true,
	["Audio_2DSounds"] = true,
	["Audio_3DSounds"] = true,
	["Audio_ScriptTypes"] = true,
	["Audio_SoundLoadTypes"] = true,
	["Audio_SoundScapeElementScripts"] = true,
	["Audio_SoundScapeElements"] = true,
	["Audio_SoundScapes"] = true,
	["Audio_SoundTypes"] = true,
	["Audio_Sounds"] = true,
	["Audio_SpeakerChannels"] = true,
	["Automates"] = true,
	["Belief_BuildingClassFaithPurchase"] = true,
	["Belief_BuildingClassHappiness"] = true,
	["Belief_BuildingClassTourism"] = true,
	["Belief_BuildingClassYieldChanges"] = true,
	["Belief_CityYieldChanges"] = true,
	["Belief_EraFaithUnitPurchase"] = true,
	["Belief_FeatureYieldChanges"] = true,
	["Belief_HolyCityYieldChanges"] = true,
	["Belief_ImprovementYieldChanges"] = true,
	["Belief_MaxYieldModifierPerFollower"] = true,
	["Belief_ResourceHappiness"] = true,
	["Belief_ResourceQuantityModifiers"] = true,
	["Belief_ResourceYieldChanges"] = true,
	["Belief_TerrainYieldChanges"] = true,
	["Belief_YieldChangeAnySpecialist"] = true,
	["Belief_YieldChangeNaturalWonder"] = true,
	["Belief_YieldChangePerForeignCity"] = true,
	["Belief_YieldChangePerXForeignFollowers"] = true,
	["Belief_YieldChangeTradeRoute"] = true,
	["Belief_YieldChangeWorldWonder"] = true,
	["Belief_YieldModifierNaturalWonder"] = true,
	["Beliefs"] = true,
	["BuildFeatures"] = true,
	["Build_TechTimeChanges"] = true,
	["BuildingClass_VictoryThresholds"] = true,
	["BuildingClasses"] = true,
	["Building_AreaYieldModifiers"] = true,
	["Building_BuildingClassHappiness"] = true,
	["Building_BuildingClassYieldChanges"] = true,
	["Building_ClassesNeededInCity"] = true,
	["Building_DomainFreeExperiencePerGreatWork"] = true,
	["Building_DomainFreeExperiences"] = true,
	["Building_DomainProductionModifiers"] = true,
	["Building_FeatureYieldChanges"] = true,
	["Building_Flavors"] = true,
	["Building_FreeSpecialistCounts"] = true,
	["Building_FreeUnits"] = true,
	["Building_GlobalYieldModifiers"] = true,
	["Building_HurryModifiers"] = true,
	["Building_LakePlotYieldChanges"] = true,
	["Building_LocalResourceAnds"] = true,
	["Building_LocalResourceOrs"] = true,
	["Building_LockedBuildingClasses"] = true,
	["Building_PrereqBuildingClasses"] = true,
	["Building_ResourceCultureChanges"] = true,
	["Building_ResourceFaithChanges"] = true,
	["Building_ResourceQuantity"] = true,
	["Building_ResourceQuantityRequirements"] = true,
	["Building_ResourceYieldChanges"] = true,
	["Building_ResourceYieldModifiers"] = true,
	["Building_RiverPlotYieldChanges"] = true,
	["Building_SeaPlotYieldChanges"] = true,
	["Building_SeaResourceYieldChanges"] = true,
	["Building_SpecialistYieldChanges"] = true,
	["Building_TechAndPrereqs"] = true,
	["Building_TechEnhancedYieldChanges"] = true,
	["Building_TerrainYieldChanges"] = true,
	["Building_ThemingBonuses"] = true,
	["Building_UnitCombatFreeExperiences"] = true,
	["Building_UnitCombatProductionModifiers"] = true,
	["Building_YieldChanges"] = true,
	["Building_YieldChangesPerPop"] = true,
	["Building_YieldChangesPerReligion"] = true,
	["Building_YieldModifiers"] = true,
	["Buildings"] = true,
	["Builds"] = true,
	["Calendars"] = true,
	["CitySizes"] = true,
	["CitySpecialization_Flavors"] = true,
	["CitySpecialization_TargetYields"] = true,
	["CitySpecializations"] = true,
	["CivilianAttackPriorities"] = true,
	["Civilization_BuildingClassOverrides"] = true,
	["Civilization_CityNames"] = true,
	["Civilization_DisableTechs"] = true,
	["Civilization_FreeBuildingClasses"] = true,
	["Civilization_FreeTechs"] = true,
	["Civilization_FreeUnits"] = true,
	["Civilization_Leaders"] = true,
	["Civilization_Religions"] = true,
	["Civilization_SpyNames"] = true,
	["Civilization_Start_Along_Ocean"] = true,
	["Civilization_Start_Along_River"] = true,
	["Civilization_Start_Place_First_Along_Ocean"] = true,
	["Civilization_Start_Region_Avoid"] = true,
	["Civilization_Start_Region_Priority"] = true,
	["Civilization_UnitClassOverrides"] = true,
	["Civilizations"] = true,
	["Climates"] = true,
	["Colors"] = true,
	["Commands"] = true,
	["Concepts"] = true,
	["Concepts_RelatedConcept"] = true,
	["Contacts"] = true,
	["Controls"] = true,
	["Cursors"] = true,
	["Defines"] = true,
	["DenialInfos"] = true,
	["Diplomacy_Responses"] = true,
	["Diplomacy_ResponsesIndex"] = true,
	["Domains"] = true,
	["DownloadableContent"] = true,
	["EmphasizeInfo_Yields"] = true,
	["EmphasizeInfos"] = true,
	["EntityEvent_AnimationPaths"] = true,
	["EntityEvents"] = true,
	["Era_CitySoundscapes"] = true,
	["Era_NewEraVOs"] = true,
	["Era_Soundtracks"] = true,
	["Eras"] = true,
	["FakeFeatures"] = true,
	["Feature_HillsYieldChanges"] = true,
	["Feature_RiverYieldChanges"] = true,
	["Feature_TerrainBooleans"] = true,
	["Feature_YieldChanges"] = true,
	["Features"] = true,
	["Flavors"] = true,
	["GameOptions"] = true,
	["GameSpeed_Turns"] = true,
	["GameSpeeds"] = true,
	["GoodyHuts"] = true,
	["GreatWorkArtifactClasses"] = true,
	["GreatWorkClasses"] = true,
	["GreatWorkSlots"] = true,
	["GreatWorks"] = true,
	["HandicapInfo_AIFreeTechs"] = true,
	["HandicapInfo_FreeTechs"] = true,
	["HandicapInfo_Goodies"] = true,
	["HandicapInfos"] = true,
	["HistoricRankings"] = true,
	["HurryInfos"] = true,
	["IconFontMapping"] = true,
	["IconFontTextures"] = true,
	["IconTextureAtlases"] = true,
	["IconTextureAtlases_Index"] = true,
	["Improvement_AdjacentCityYields"] = true,
	["Improvement_AdjacentMountainYieldChanges"] = true,
	["Improvement_CoastalLandYields"] = true,
	["Improvement_Flavors"] = true,
	["Improvement_FreshWaterYields"] = true,
	["Improvement_HillsYields"] = true,
	["Improvement_PrereqNatureYields"] = true,
	["Improvement_ResourceType_Yields"] = true,
	["Improvement_ResourceTypes"] = true,
	["Improvement_RiverSideYields"] = true,
	["Improvement_RouteYieldChanges"] = true,
	["Improvement_TechFreshWaterYieldChanges"] = true,
	["Improvement_TechNoFreshWaterYieldChanges"] = true,
	["Improvement_TechYieldChanges"] = true,
	["Improvement_ValidFeatures"] = true,
	["Improvement_ValidImprovements"] = true,
	["Improvement_ValidTerrains"] = true,
	["Improvement_YieldPerEra"] = true,
	["Improvement_Yields"] = true,
	["Improvements"] = true,
	["InterfaceModes"] = true,
	["InvisibleInfos"] = true,
	["Leader_Flavors"] = true,
	["Leader_MajorCivApproachBiases"] = true,
	["Leader_MinorCivApproachBiases"] = true,
	["Leader_Traits"] = true,
	["Leaders"] = true,
	["LeagueNames"] = true,
	["LeagueProjectRewards"] = true,
	["LeagueProjects"] = true,
	["LeagueSpecialSessions"] = true,
	["MajorCivApproachTypes"] = true,
	["MapScriptOptionPossibleValues"] = true,
	["MapScriptOptions"] = true,
	["MapScriptRequiredDLC"] = true,
	["MapScripts"] = true,
	["Map_Folders"] = true,
	["Map_Sizes"] = true,
	["Maps"] = true,
	["MemoryInfos"] = true,
	["MinorCivApproachTypes"] = true,
	["MinorCivTraits"] = true,
	["MinorCivTraits_Status"] = true,
	["MinorCivilization_CityNames"] = true,
	["MinorCivilization_Flavors"] = true,
	["MinorCivilizations"] = true,
	["Missions"] = true,
	["Months"] = true,
	["MovementRates"] = true,
	["MultiUnitFormation_SlotEntries"] = true,
	["MultiUnitFormations"] = true,
	["MultiUnitPositions"] = true,
	["MultiplayerOptions"] = true,
	["Natural_Wonder_Placement"] = true,
	["Notifications"] = true,
	["OnDeleteMapScript"] = true,
	["PlayerColors"] = true,
	["PlayerOptions"] = true,
	["Policies"] = true,
	["PolicyBranchTypes"] = true,
	["PolicyBranch_Disables"] = true,
	["Policy_BuildingClassCultureChanges"] = true,
	["Policy_BuildingClassHappiness"] = true,
	["Policy_BuildingClassProductionModifiers"] = true,
	["Policy_BuildingClassTourismModifiers"] = true,
	["Policy_BuildingClassYieldChanges"] = true,
	["Policy_BuildingClassYieldModifiers"] = true,
	["Policy_CapitalYieldChanges"] = true,
	["Policy_CapitalYieldModifiers"] = true,
	["Policy_CapitalYieldPerPopChanges"] = true,
	["Policy_CityYieldChanges"] = true,
	["Policy_CoastalCityYieldChanges"] = true,
	["Policy_Disables"] = true,
	["Policy_Flavors"] = true,
	["Policy_FreeItems"] = true,
	["Policy_FreePromotionUnitCombats"] = true,
	["Policy_FreePromotions"] = true,
	["Policy_FreeUnitClasses"] = true,
	["Policy_GreatWorkYieldChanges"] = true,
	["Policy_HurryModifiers"] = true,
	["Policy_ImprovementCultureChanges"] = true,
	["Policy_ImprovementYieldChanges"] = true,
	["Policy_PrereqORPolicies"] = true,
	["Policy_PrereqPolicies"] = true,
	["Policy_SpecialistExtraYields"] = true,
	["Policy_TourismOnUnitCreation"] = true,
	["Policy_UnitCombatFreeExperiences"] = true,
	["Policy_UnitCombatProductionModifiers"] = true,
	["Policy_ValidSpecialists"] = true,
	["Policy_YieldModifiers"] = true,
	["PostDefines"] = true,
	["Process_Flavors"] = true,
	["Process_ProductionYields"] = true,
	["Processes"] = true,
	["Project_Flavors"] = true,
	["Project_Prereqs"] = true,
	["Project_ResourceQuantityRequirements"] = true,
	["Project_VictoryThresholds"] = true,
	["Projects"] = true,
	["Regions"] = true,
	["Religions"] = true,
	["ReplayDataSets"] = true,
	["ResolutionDecisions"] = true,
	["Resolutions"] = true,
	["ResourceClasses"] = true,
	["Resource_FeatureBooleans"] = true,
	["Resource_FeatureTerrainBooleans"] = true,
	["Resource_Flavors"] = true,
	["Resource_QuantityTypes"] = true,
	["Resource_TerrainBooleans"] = true,
	["Resource_YieldChanges"] = true,
	["Resources"] = true,
	["Route_ResourceQuantityRequirements"] = true,
	["Route_TechMovementChanges"] = true,
	["Route_Yields"] = true,
	["Routes"] = true,
	["ScannedFiles"] = true,
	["SeaLevels"] = true,
	["Seasons"] = true,
	["SmallAwards"] = true,
	["SpecialUnit_CarrierUnitAI"] = true,
	["SpecialUnit_ProductionTraits"] = true,
	["SpecialUnits"] = true,
	["SpecialistFlavors"] = true,
	["SpecialistYields"] = true,
	["Specialists"] = true,
	["TacticalMoves"] = true,
	["Technologies"] = true,
	["Technology_DomainExtraMoves"] = true,
	["Technology_Flavors"] = true,
	["Technology_FreePromotions"] = true,
	["Technology_ORPrereqTechs"] = true,
	["Technology_PrereqTechs"] = true,
	["Technology_TradeRouteDomainExtraRange"] = true,
	["Terrain_HillsYieldChanges"] = true,
	["Terrain_RiverYieldChanges"] = true,
	["Terrain_Yields"] = true,
	["Terrains"] = true,
	["Trades"] = true,
	["Trait_ExtraYieldThresholds"] = true,
	["Trait_FreePromotionUnitCombats"] = true,
	["Trait_FreePromotions"] = true,
	["Trait_FreeResourceFirstXCities"] = true,
	["Trait_ImprovementYieldChanges"] = true,
	["Trait_MaintenanceModifierUnitCombats"] = true,
	["Trait_MovesChangeUnitCombats"] = true,
	["Trait_NoTrain"] = true,
	["Trait_ResourceQuantityModifiers"] = true,
	["Trait_SpecialistYieldChanges"] = true,
	["Trait_Terrains"] = true,
	["Trait_UnimprovedFeatureYieldChanges"] = true,
	["Trait_YieldChanges"] = true,
	["Trait_YieldChangesIncomingTradeRoute"] = true,
	["Trait_YieldChangesNaturalWonder"] = true,
	["Trait_YieldChangesPerTradePartner"] = true,
	["Trait_YieldChangesStrategicResources"] = true,
	["Trait_YieldModifiers"] = true,
	["Traits"] = true,
	["TurnTimers"] = true,
	["UnitAIInfos"] = true,
	["UnitClasses"] = true,
	["UnitCombatInfos"] = true,
	["UnitGameplay2DScripts"] = true,
	["UnitPromotions"] = true,
	["UnitPromotions_CivilianUnitType"] = true,
	["UnitPromotions_Domains"] = true,
	["UnitPromotions_Features"] = true,
	["UnitPromotions_PostCombatRandomPromotion"] = true,
	["UnitPromotions_Terrains"] = true,
	["UnitPromotions_UnitClasses"] = true,
	["UnitPromotions_UnitCombatMods"] = true,
	["UnitPromotions_UnitCombats"] = true,
	["Unit_AITypes"] = true,
	["Unit_BuildingClassRequireds"] = true,
	["Unit_Buildings"] = true,
	["Unit_Builds"] = true,
	["Unit_ClassUpgrades"] = true,
	["Unit_Flavors"] = true,
	["Unit_FreePromotions"] = true,
	["Unit_GreatPersons"] = true,
	["Unit_NotAITypes"] = true,
	["Unit_ProductionModifierBuildings"] = true,
	["Unit_ProductionTraits"] = true,
	["Unit_ResourceQuantityRequirements"] = true,
	["Unit_TechTypes"] = true,
	["Unit_UniqueNames"] = true,
	["Unit_YieldFromKills"] = true,
	["Units"] = true,
	["Victories"] = true,
	["VictoryPointAwards"] = true,
	["VoteSources"] = true,
	["Vote_DiploVotes"] = true,
	["Votes"] = true,
	["Worlds"] = true,
	["Yields"] = true,
}

function CreateMP()

	print2 ("Deleting previous ModPack if exist...")
	Game.DeleteMPMP()
	
	print2 ("Creating New ModPack folder...")
	Game.CreateMPMP()
	--[[
	print2 ("Getting content of the modded database...")
	CopyDatabase()
	
	print2 ("Getting tables added by mods...")
	CopyAddedDatabase()
	
	print2 ("Getting Audio tables...")
	CopyAudioDatabase()
	--]]
	print2 ("Getting Texts tables...")
	CopyTextDatabase()
	--]]
	CopyFullDatabase()

	--print2 ("Creating Civ5ArtDefines_Units...")
	--CreateCiv5ArtDefines_Units()
	
	--print2 ("Creating Civ5ArtDefines_UnitMembers...")
	--CreateCiv5ArtDefines_UnitMembers()
	
	print2 ("Copying Activated Mods...")
	CopyActivatedMods()
	
	--ContextPtr:LookUpControl("/InGame/TopPanel/TopPanelInfoStack"):SetHide( false )

end

function CopyDatabase()

	local sDatabase = ""	
	for i, data in ipairs(FileTableList) do
		Game.WriteMPMP( data.FileName, "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!-- generated by MP Modpacks Maker (Gedemon) -->\n<GameData>\n", true ) -- Create file
		for j, TableName in ipairs(data.TableList) do
			print2 ("Copying: " .. TableName)
			local query = "PRAGMA table_info(".. tostring(TableName) ..");"
			local structure = DB.CreateQuery(query)

			--sDatabase = "<GameData> \n"
			sDatabase = GetTablesStructure(TableName)
			sDatabase = sDatabase .. "	<".. tostring(TableName) ..">"		
			Game.WriteMPMP( data.FileName, sDatabase, false)

			local columns = {}
			for c in structure() do			
				table.insert(columns, {Name = c.name})
			end

			local query = "SELECT * FROM " .. TableName ..";"	
			for result in DB.Query(query) do
				sDatabase = "		<Row> \n"
				for i, col in pairs(columns) do				
					local tagStr = ""
					local valueStr = tostring(result[col.Name])			
					if valueStr:len() > 0 and valueStr ~= "nil" then sDatabase = sDatabase .. "			<".. col.Name ..">".. valueStr .."</".. col.Name .."> \n" end
				end
				sDatabase = sDatabase .. "		</Row>"
				Game.WriteMPMP( data.FileName, sDatabase, false)
			end

			sDatabase = "	</".. tostring(TableName) .."> \n"
			Game.WriteMPMP( data.FileName, sDatabase, false)
			sDatabase = ""
		end
		sDatabase = sDatabase .. "</GameData>"
		Game.WriteMPMP( data.FileName, sDatabase, false)
	end

end

function GetTablesStructure(tableName)
	
	local sTableStructure = "	<Table name=\"".. tostring(tableName) .."\">\n"
	local query = "PRAGMA table_info(".. tostring(tableName) ..");"
	--local query = "SELECT sql FROM (SELECT * FROM sqlite_master UNION ALL SELECT * FROM sqlite_temp_master) WHERE tbl_name =  '".. tostring(tableName) .."' AND type!='meta' AND sql NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY substr(type,2,1), name);"
	
	local structure = DB.CreateQuery(query)	
	local bHasPrimaryKey = false
	for line in structure() do	

		-- prepare for Crude Formatting(tm)
		local bAutoIncrement = false
		local bUnique = false
		local bIsPrimaryKey = (line.pk > 0)
		local bNotNull = (line.notnull > 0)
		local sDefaultValue = tostring(line.dflt_value)
		sDefaultValue = string.gsub(sDefaultValue, "'", "")
		if sDefaultValue:len() > 0 and sDefaultValue ~= "nil" then sDefaultValue = "default=\"".. sDefaultValue .."\"" else sDefaultValue = "" end
		if bIsPrimaryKey then bHasPrimaryKey = true end
		if (line.name == "ID" and bIsPrimaryKey ) then bAutoIncrement = true end
		if (line.name == "Type" and bHasPrimaryKey ) then bUnique = true end
		
		-- Write the line...
		local sColumn = "		<Column name=\"".. tostring(line.name).."\" type=\"".. tostring(line.type).."\" "
		if bIsPrimaryKey then sColumn = sColumn .. " primarykey=\"true\"" end
		if bAutoIncrement then sColumn = sColumn .. " autoincrement=\"true\"" end
		if bUnique then sColumn = sColumn .. " unique=\"true\"" end
		if bNotNull then sColumn = sColumn .. " notnull=\"true\"" end
		sColumn = sColumn .. " " .. sDefaultValue
		sTableStructure = sTableStructure .. sColumn .. "/>\n"
	end	

	return sTableStructure .. "	</Table> \n"
end

function CreateCiv5ArtDefines_Units()
	
	local sDatabase = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!-- generated by MP Modpacks Maker (Gedemon) -->\n"
	sDatabase = sDatabase .. "<UnitArtInfos> \n"
	Game.WriteMPMP( "Civ5ArtDefines_Units.xml", sDatabase, true ) -- Open file

	for UnitInfos in DB.Query("SELECT * FROM ArtDefine_UnitInfos;") do
		
		-- ArtDefine_UnitInfoMemberInfos table
		local UnitMemberArt = ""
		for MemberInfos in DB.Query("SELECT * FROM ArtDefine_UnitInfoMemberInfos WHERE UnitInfoType = '"..UnitInfos.Type.."';") do
			UnitMemberArt = UnitMemberArt .. "		<UnitMemberArt>\n			  <MemberType>" .. tostring(MemberInfos.UnitMemberInfoType) .. "</MemberType>\n			  <MemberCount>".. tostring(MemberInfos.NumMembers) .."</MemberCount>\n			</UnitMemberArt>\n"
		end
			
		-- ArtDefine_UnitInfos table
		local Formation 			= tostring(UnitInfos.Formation)
		local DamageStates 			= tostring(UnitInfos.DamageStates)
		local UnitFlagAtlas 		= tostring(UnitInfos.UnitFlagAtlas)
		local UnitFlagIconOffset 	= tostring(UnitInfos.UnitFlagIconOffset)
		local IconAtlas 			= tostring(UnitInfos.IconAtlas)
		local PortraitIndex 		= tostring(UnitInfos.PortraitIndex)
		
		if Formation:len() > 0 			and Formation ~= "nil"			then Formation = "		<Formation>".. Formation .."</Formation>\n" 									else Formation = "" end
		if DamageStates:len() > 0 		and DamageStates ~= "nil"		then DamageStates = "		<DamageStates>".. DamageStates .."</DamageStates>\n" 						else DamageStates = "" end
		if UnitFlagAtlas:len() > 0 		and UnitFlagAtlas ~= "nil"		then UnitFlagAtlas = "		<UnitFlagAtlas>".. UnitFlagAtlas .."</UnitFlagAtlas>\n" 					else UnitFlagAtlas = "" end
		if UnitFlagIconOffset:len() > 0 and UnitFlagIconOffset ~= "nil" then UnitFlagIconOffset = "		<UnitFlagIconOffset>".. UnitFlagIconOffset .."</UnitFlagIconOffset>\n" else UnitFlagIconOffset = "" end
		if IconAtlas:len() > 0 			and IconAtlas ~= "nil"			then IconAtlas = "		<IconAtlas>".. IconAtlas .."</IconAtlas>\n" 									else IconAtlas = "" end
		if PortraitIndex:len() > 0 		and PortraitIndex ~= "nil"		then PortraitIndex = "		<PortraitIndex>".. PortraitIndex .."</PortraitIndex>\n" 					else PortraitIndex = "" end

		sDatabase = "	<UnitArtInfo>\n		<Type>".. tostring(UnitInfos.Type) .. "</Type>\n ".. PortraitIndex .. IconAtlas .. UnitFlagAtlas.. UnitFlagIconOffset .. Formation .. DamageStates .. UnitMemberArt .."	</UnitArtInfo>"
		
		Game.WriteMPMP( "Civ5ArtDefines_Units.xml", sDatabase, false ) -- Append file
	end	
	Game.WriteMPMP( "Civ5ArtDefines_Units.xml", "</UnitArtInfos>\n", false ) -- Append file

end

function CreateCiv5ArtDefines_UnitMembers()
	
	local sDatabase = "<?xml version=\"1.0\" encoding=\"utf-8\"?> \n<!-- generated by MP Modpacks Maker (Gedemon) -->\n"
	sDatabase = sDatabase .. "<UnitMemberArtInfos>"
	Game.WriteMPMP( "Civ5ArtDefines_UnitMembers.xml", sDatabase, true ) -- Open file

	for UnitMemberInfos in DB.Query("SELECT * FROM ArtDefine_UnitMemberInfos;") do

		-- ArtDefine_UnitMemberCombats table
		local Combat = ""
		for CombatInfos in DB.Query("SELECT * FROM ArtDefine_UnitMemberCombats WHERE UnitMemberType = '"..UnitMemberInfos.Type.."';") do
			
			-- ArtDefine_UnitMemberCombatWeapons table
			local Weapon = ""
			for WeaponInfos in DB.Query("SELECT * FROM ArtDefine_UnitMemberCombatWeapons WHERE UnitMemberType = '"..CombatInfos.UnitMemberType.."';") do
				-- local usage = ???
				-- local ???	= tostring(WeaponInfos.Index)
				-- local ???	= tostring(WeaponInfos.SubIndex)
				local ID							= tostring(WeaponInfos.ID)
				local fVisKillStrengthMin			= tostring(WeaponInfos.VisKillStrengthMin)
				local fVisKillStrengthMax			= tostring(WeaponInfos.VisKillStrengthMax)
				local fProjectileSpeed				= tostring(WeaponInfos.ProjectileSpeed)
				local fProjectileTurnRateMin		= tostring(WeaponInfos.ProjectileTurnRateMin) -- not used in game's XML
				local fProjectileTurnRateMax		= tostring(WeaponInfos.ProjectileTurnRateMax) -- not used in game's XML
				local HitEffect						= tostring(WeaponInfos.HitEffect)
				local fHitEffectScale				= tostring(WeaponInfos.HitEffectScale)
				local fHitRadius					= tostring(WeaponInfos.HitRadius)
				local fProjectileChildEffectScale	= tostring(WeaponInfos.ProjectileChildEffectScale)
				local fAreaDamageDelay				= tostring(WeaponInfos.AreaDamageDelay)
				local bContinuousFire				= tostring(WeaponInfos.ContinuousFire)
				local bWaitForEffectCompletion		= tostring(WeaponInfos.WaitForEffectCompletion)
				local bTargetGround					= tostring(WeaponInfos.TargetGround)
				local bIsDropped					= tostring(WeaponInfos.IsDropped)
				local WeaponTypeTag					= tostring(WeaponInfos.WeaponTypeTag)
				local WeaponTypeSoundOverrideTag	= tostring(WeaponInfos.WeaponTypeSoundOverrideTag)
				local fMissTargetSlopRadius			= tostring(WeaponInfos.MissTargetSlopRadius)				
					
				if ID:len() > 0 and ID ~= "nil" then ID = "				<ID>".. ID .."</ID>" else ID = "" end
				if fVisKillStrengthMin:len() > 0 and fVisKillStrengthMin ~= "nil" then fVisKillStrengthMin = "				<fVisKillStrengthMin>".. fVisKillStrengthMin .."</fVisKillStrengthMin>\n" else fVisKillStrengthMin = "" end
				if fVisKillStrengthMax:len() > 0 and fVisKillStrengthMax ~= "nil" then fVisKillStrengthMax = "				<fVisKillStrengthMax>".. fVisKillStrengthMax .."</fVisKillStrengthMax>\n" else fVisKillStrengthMax = "" end
				if fProjectileTurnRateMin:len() > 0 and fProjectileTurnRateMin ~= "nil" then fProjectileTurnRateMin = "				<fProjectileTurnRateMin>".. fProjectileTurnRateMin .."</fProjectileTurnRateMin>\n" else fProjectileTurnRateMin = "" end
				if fProjectileTurnRateMax:len() > 0 and fProjectileTurnRateMax ~= "nil" then fProjectileTurnRateMax = "				<fProjectileTurnRateMax>".. fProjectileTurnRateMax .."</fProjectileTurnRateMax>\n" else fProjectileTurnRateMax = "" end
				if fProjectileSpeed:len() > 0 and fProjectileSpeed ~= "nil" then fProjectileSpeed = "				<fProjectileSpeed>".. fProjectileSpeed .."</fProjectileSpeed>\n" else fProjectileSpeed = "" end
				if HitEffect:len() > 0 and HitEffect ~= "nil" then HitEffect = "				<HitEffect>".. HitEffect .."</HitEffect>\n" else HitEffect = "" end
				if fHitEffectScale:len() > 0 and fHitEffectScale ~= "nil" then fHitEffectScale = "				<fHitEffectScale>".. fHitEffectScale .."</fHitEffectScale>\n" else fHitEffectScale = "" end
				if fHitRadius:len() > 0 and fHitRadius ~= "nil" then fHitRadius = "				<fHitRadius>".. fHitRadius .."</fHitRadius>\n" else fHitRadius = "" end
				if fProjectileChildEffectScale:len() > 0 and fProjectileChildEffectScale ~= "nil" then fProjectileChildEffectScale = "				<fProjectileChildEffectScale>".. fProjectileChildEffectScale .."</fProjectileChildEffectScale>\n" else fProjectileChildEffectScale = "" end
				if fAreaDamageDelay:len() > 0 and fAreaDamageDelay ~= "nil" then fAreaDamageDelay = "				<fAreaDamageDelay>".. fAreaDamageDelay .."</fAreaDamageDelay>\n" else fAreaDamageDelay = "" end
				if bContinuousFire:len() > 0 and bContinuousFire ~= "nil" then bContinuousFire = "				<bContinuousFire>".. bContinuousFire .."</bContinuousFire>\n" else bContinuousFire = "" end
				if bWaitForEffectCompletion:len() > 0 and bWaitForEffectCompletion ~= "nil" then bWaitForEffectCompletion = "				<bWaitForEffectCompletion>".. bWaitForEffectCompletion .."</bWaitForEffectCompletion>\n" else bWaitForEffectCompletion = "" end
				if bTargetGround:len() > 0 and bTargetGround ~= "nil" then bTargetGround = "				<bTargetGround>".. bTargetGround .."</bTargetGround>\n" else bTargetGround = "" end
				if bIsDropped:len() > 0 and bIsDropped ~= "nil" then bIsDropped = "				<bIsDropped>".. bIsDropped .."</bIsDropped>\n" else bIsDropped = "" end
				if WeaponTypeTag:len() > 0 and WeaponTypeTag ~= "nil" then WeaponTypeTag = "				<WeaponTypeTag>".. WeaponTypeTag .."</WeaponTypeTag>\n" else WeaponTypeTag = "" end
				if WeaponTypeSoundOverrideTag:len() > 0 and WeaponTypeSoundOverrideTag ~= "nil" then WeaponTypeSoundOverrideTag = "				<WeaponTypeSoundOverrideTag>".. WeaponTypeSoundOverrideTag .."</WeaponTypeSoundOverrideTag>\n" else WeaponTypeSoundOverrideTag = "" end
				if fMissTargetSlopRadius:len() > 0 and fMissTargetSlopRadius ~= "nil" then fMissTargetSlopRadius = "				<fMissTargetSlopRadius>".. fMissTargetSlopRadius .."</fMissTargetSlopRadius>\n" else fMissTargetSlopRadius = "" end
				
				-- Can have multiple entries
				Weapon = Weapon .. "			<Weapon>\n "..ID..fVisKillStrengthMin..fVisKillStrengthMax..fProjectileSpeed..fProjectileTurnRateMin..fProjectileTurnRateMax..HitEffect..fHitEffectScale..fHitRadius..fProjectileChildEffectScale..fAreaDamageDelay..bContinuousFire..bWaitForEffectCompletion..bTargetGround..bIsDropped..WeaponTypeTag..WeaponTypeSoundOverrideTag..fMissTargetSlopRadius.."			</Weapon>\n"
			end
				
			-- local fDeathRotationAmount = ???
			local EnableActions 				= tostring(CombatInfos.EnableActions)
			local DisableActions 				= tostring(CombatInfos.DisableActions) -- not used in game's XML
			local fMoveRadius 					= tostring(CombatInfos.MoveRadius)
			local fShortMoveRadius 				= tostring(CombatInfos.ShortMoveRadius) 
			local fChargeRadius 				= tostring(CombatInfos.ChargeRadius) -- not used in game's XML
			local fAttackRadius 				= tostring(CombatInfos.AttackRadius)
			local fRangedAttackRadius 			= tostring(CombatInfos.RangedAttackRadius)
			local fMoveRate 					= tostring(CombatInfos.MoveRate)
			local fShortMoveRate 				= tostring(CombatInfos.ShortMoveRate)
			local fTurnRateMin 					= tostring(CombatInfos.TurnRateMin)
			local fTurnRateMax 					= tostring(CombatInfos.TurnRateMax)
			local fTurnFacingRateMin 			= tostring(CombatInfos.TurnFacingRateMin)
			local fTurnFacingRateMax 			= tostring(CombatInfos.TurnFacingRateMax)
			local fRollRateMin 					= tostring(CombatInfos.RollRateMin) -- not used in game's XML
			local fRollRateMax 					= tostring(CombatInfos.RollRateMax) -- not used in game's XML
			local fPitchRateMin 				= tostring(CombatInfos.PitchRateMin)
			local fPitchRateMax 				= tostring(CombatInfos.PitchRateMax)
			local fLOSRadiusScale 				= tostring(CombatInfos.LOSRadiusScale) -- not used in game's XML
			local fTargetRadius 				= tostring(CombatInfos.TargetRadius)
			local fTargetHeight 				= tostring(CombatInfos.TargetHeight)
			local bHasShortRangedAttack 		= tostring(CombatInfos.HasShortRangedAttack)
			local bHasLongRangedAttack 			= tostring(CombatInfos.HasLongRangedAttack)
			local bHasLeftRightAttack 			= tostring(CombatInfos.HasLeftRightAttack)
			local bHasStationaryMelee 			= tostring(CombatInfos.HasStationaryMelee)
			local bHasStationaryRangedAttack 	= tostring(CombatInfos.HasStationaryRangedAttack) -- not used in game's XML
			local bHasRefaceAfterCombat 		= tostring(CombatInfos.HasRefaceAfterCombat)
			local bReformBeforeCombat 			= tostring(CombatInfos.ReformBeforeCombat)
			local bHasIndependentWeaponFacing 	= tostring(CombatInfos.HasIndependentWeaponFacing)
			local bHasOpponentTracking 			= tostring(CombatInfos.HasOpponentTracking)
			local bHasCollisionAttack 			= tostring(CombatInfos.HasCollisionAttack)
			local fAttackAltitude 				= tostring(CombatInfos.AttackAltitude)
			local fAltitudeDecelerationDistance = tostring(CombatInfos.AltitudeDecelerationDistance) -- not used in game's XML
			local bOnlyTurnInMovementActions 	= tostring(CombatInfos.OnlyTurnInMovementActions)
			local RushAttackFormation 			= tostring(CombatInfos.RushAttackFormation)
			local bLastToDie 					= tostring(CombatInfos.LastToDie)
				
			if EnableActions:len() > 0 and EnableActions ~= "nil" then EnableActions = "			<EnableActions>".. EnableActions .."</EnableActions>\n" else EnableActions = "" end
			if DisableActions:len() > 0 and DisableActions ~= "nil" then DisableActions = "			<DisableActions>".. DisableActions .."</DisableActions>\n" else DisableActions = "" end
			if fMoveRadius:len() > 0 and fMoveRadius ~= "nil" then fMoveRadius = "			<fMoveRadius>".. fMoveRadius .."</fMoveRadius>\n" else fMoveRadius = "" end
			if fShortMoveRadius:len() > 0 and fShortMoveRadius ~= "nil" then fShortMoveRadius = "			<fShortMoveRadius>".. fShortMoveRadius .."</fShortMoveRadius>\n" else fShortMoveRadius = "" end
			if fChargeRadius:len() > 0 and fChargeRadius ~= "nil" then fChargeRadius = "			<fChargeRadius>".. fChargeRadius .."</fChargeRadius>\n" else fChargeRadius = "" end
			if fAttackRadius:len() > 0 and fAttackRadius ~= "nil" then fAttackRadius = "			<fAttackRadius>".. fAttackRadius .."</fAttackRadius>\n" else fAttackRadius = "" end
			if fRangedAttackRadius:len() > 0 and fRangedAttackRadius ~= "nil" then fRangedAttackRadius = "			<fRangedAttackRadius>".. fRangedAttackRadius .."</fRangedAttackRadius>\n" else fRangedAttackRadius = "" end
			if fMoveRate:len() > 0 and fMoveRate ~= "nil" then fMoveRate = "			<fMoveRate>".. fMoveRate .."</fMoveRate>\n" else fMoveRate = "" end
			if fShortMoveRate:len() > 0 and fShortMoveRate ~= "nil" then fShortMoveRate = "			<fShortMoveRate>".. fShortMoveRate .."</fShortMoveRate>\n" else fShortMoveRate = "" end
			if fTurnRateMin:len() > 0 and fTurnRateMin ~= "nil" then fTurnRateMin = "			<fTurnRateMin>".. fTurnRateMin .."</fTurnRateMin>\n" else fTurnRateMin = "" end
			if fTurnRateMax:len() > 0 and fTurnRateMax ~= "nil" then fTurnRateMax = "			<fTurnRateMax>".. fTurnRateMax .."</fTurnRateMax>\n" else fTurnRateMax = "" end
			if fTurnFacingRateMin:len() > 0 and fTurnFacingRateMin ~= "nil" then fTurnFacingRateMin = "			<fTurnFacingRateMin>".. fTurnFacingRateMin .."</fTurnFacingRateMin>\n" else fTurnFacingRateMin = "" end
			if fTurnFacingRateMax:len() > 0 and fTurnFacingRateMax ~= "nil" then fTurnFacingRateMax = "			<fTurnFacingRateMax>".. fTurnFacingRateMax .."</fTurnFacingRateMax>\n" else fTurnFacingRateMax = "" end
			if fRollRateMin:len() > 0 and fRollRateMin ~= "nil" then fRollRateMin = "			<fRollRateMin>".. fRollRateMin .."</fRollRateMin>\n" else fRollRateMin = "" end
			if fRollRateMax:len() > 0 and fRollRateMax ~= "nil" then fRollRateMax = "			<fRollRateMax>".. fRollRateMax .."</fRollRateMax>\n" else fRollRateMax = "" end
			if fPitchRateMin:len() > 0 and fPitchRateMin ~= "nil" then fPitchRateMin = "			<fPitchRateMin>".. fPitchRateMin .."</fPitchRateMin>\n" else fPitchRateMin = "" end
			if fPitchRateMax:len() > 0 and fPitchRateMax ~= "nil" then fPitchRateMax = "			<fPitchRateMax>".. fPitchRateMax .."</fPitchRateMax>\n" else fPitchRateMax = "" end
			if fLOSRadiusScale:len() > 0 and fLOSRadiusScale ~= "nil" then fLOSRadiusScale = "			<fLOSRadiusScale>".. fLOSRadiusScale .."</fLOSRadiusScale>\n" else fLOSRadiusScale = "" end
			if fTargetRadius:len() > 0 and fTargetRadius ~= "nil" then fTargetRadius = "			<fTargetRadius>".. fTargetRadius .."</fTargetRadius>\n" else fTargetRadius = "" end
			if fTargetHeight:len() > 0 and fTargetHeight ~= "nil" then fTargetHeight = "			<fTargetHeight>".. fTargetHeight .."</fTargetHeight>\n" else fTargetHeight = "" end
			if bHasShortRangedAttack:len() > 0 and bHasShortRangedAttack ~= "nil" then bHasShortRangedAttack = "			<bHasShortRangedAttack>".. bHasShortRangedAttack .."</bHasShortRangedAttack>\n" else bHasShortRangedAttack = "" end
			if bHasLongRangedAttack:len() > 0 and bHasLongRangedAttack ~= "nil" then bHasLongRangedAttack = "			<bHasLongRangedAttack>".. bHasLongRangedAttack .."</bHasLongRangedAttack>\n" else bHasLongRangedAttack = "" end
			if bHasLeftRightAttack:len() > 0 and bHasLeftRightAttack ~= "nil" then bHasLeftRightAttack = "			<bHasLeftRightAttack>".. bHasLeftRightAttack .."</bHasLeftRightAttack>\n" else bHasLeftRightAttack = "" end
			if bHasStationaryMelee:len() > 0 and bHasStationaryMelee ~= "nil" then bHasStationaryMelee = "			<bHasStationaryMelee>".. bHasStationaryMelee .."</bHasStationaryMelee>\n" else bHasStationaryMelee = "" end
			if bHasStationaryRangedAttack:len() > 0 and bHasStationaryRangedAttack ~= "nil" then bHasStationaryRangedAttack = "			<bHasStationaryRangedAttack>".. bHasStationaryRangedAttack .."</bHasStationaryRangedAttack>\n" else bHasStationaryRangedAttack = "" end
			if bHasRefaceAfterCombat:len() > 0 and bHasRefaceAfterCombat ~= "nil" then bHasRefaceAfterCombat = "			<bHasRefaceAfterCombat>".. bHasRefaceAfterCombat .."</bHasRefaceAfterCombat>\n" else bHasRefaceAfterCombat = "" end
			if bReformBeforeCombat:len() > 0 and bReformBeforeCombat ~= "nil" then bReformBeforeCombat = "			<bReformBeforeCombat>".. bReformBeforeCombat .."</bReformBeforeCombat>\n" else bReformBeforeCombat = "" end
			if bHasIndependentWeaponFacing:len() > 0 and bHasIndependentWeaponFacing ~= "nil" then bHasIndependentWeaponFacing = "			<bHasIndependentWeaponFacing>".. bHasIndependentWeaponFacing .."</bHasIndependentWeaponFacing>\n" else bHasIndependentWeaponFacing = "" end
			if bHasOpponentTracking:len() > 0 and bHasOpponentTracking ~= "nil" then bHasOpponentTracking = "			<bHasOpponentTracking>".. bHasOpponentTracking .."</bHasOpponentTracking>\n" else bHasOpponentTracking = "" end
			if bHasCollisionAttack:len() > 0 and bHasCollisionAttack ~= "nil" then bHasCollisionAttack = "			<bHasCollisionAttack>".. bHasCollisionAttack .."</bHasCollisionAttack>\n" else bHasCollisionAttack = "" end
			if fAttackAltitude:len() > 0 and fAttackAltitude ~= "nil" then fAttackAltitude = "			<fAttackAltitude>".. fAttackAltitude .."</fAttackAltitude>\n" else fAttackAltitude = "" end
			if fAltitudeDecelerationDistance:len() > 0 and fAltitudeDecelerationDistance ~= "nil" then fAltitudeDecelerationDistance = "			<fAltitudeDecelerationDistance>".. fAltitudeDecelerationDistance .."</fAltitudeDecelerationDistance>\n" else fAltitudeDecelerationDistance = "" end
			if bOnlyTurnInMovementActions:len() > 0 and bOnlyTurnInMovementActions ~= "nil" then bOnlyTurnInMovementActions = "			<bOnlyTurnInMovementActions>".. bOnlyTurnInMovementActions .."</bOnlyTurnInMovementActions>\n" else bOnlyTurnInMovementActions = "" end
			if RushAttackFormation:len() > 0 and RushAttackFormation ~= "nil" then RushAttackFormation = "			<RushAttackFormation>".. RushAttackFormation .."</RushAttackFormation>\n" else RushAttackFormation = "" end
			if bLastToDie:len() > 0 and bLastToDie ~= "nil" then bLastToDie = "			<bLastToDie>".. bLastToDie .."</bLastToDie>\n" else bLastToDie = "" end
				
			-- Only one entry per UnitMemberType
			Combat = "		<Combat>\n" ..EnableActions..DisableActions..fMoveRadius..fShortMoveRadius..fChargeRadius..fAttackRadius..fRangedAttackRadius..fMoveRate..fShortMoveRate..fTurnRateMin..fTurnRateMax..fTurnFacingRateMin..fTurnFacingRateMax..fRollRateMin..fRollRateMax..fPitchRateMin..fPitchRateMax..fLOSRadiusScale..fTargetRadius..fTargetHeight..bHasShortRangedAttack..bHasLongRangedAttack..bHasLeftRightAttack..bHasStationaryMelee..bHasStationaryRangedAttack..bHasRefaceAfterCombat..bReformBeforeCombat..bHasIndependentWeaponFacing..bHasOpponentTracking..bHasCollisionAttack..fAttackAltitude..fAltitudeDecelerationDistance..bOnlyTurnInMovementActions..RushAttackFormation..bLastToDie.. Weapon .."		</Combat>\n"
		end
			
		-- ArtDefine_UnitMemberInfos table
		local fScale 			= tostring(UnitMemberInfos.Scale)
		local fZOffset 			= tostring(UnitMemberInfos.ZOffset)
		local Domain 			= tostring(UnitMemberInfos.Domain)
		local Granny 			= tostring(UnitMemberInfos.Model)
		local MaterialTypeTag 	= tostring(UnitMemberInfos.MaterialTypeTag)
		local MaterialTypeSoundOverrideTag 	= tostring(UnitMemberInfos.MaterialTypeSoundOverrideTag)
		
		if fScale:len() > 0 and fScale ~= "nil" then fScale = "		<fScale>".. fScale .."</fScale>\n" else fScale = "" end
		if fZOffset:len() > 0 and fZOffset ~= "nil" then fZOffset = "		<fZOffset>".. fZOffset .."</fZOffset>\n" else fZOffset = "" end
		if Domain:len() > 0 and Domain ~= "nil" then Domain = "		<Domain>".. Domain .."</Domain>\n" else Domain = "" end
		if Granny:len() > 0 and Granny ~= "nil" then Granny = "		<Granny>".. Granny .."</Granny>\n" else Granny = "" end
		if MaterialTypeTag:len() > 0 and MaterialTypeTag ~= "nil" then MaterialTypeTag = "		<MaterialTypeTag>".. MaterialTypeTag .."</MaterialTypeTag>\n" else MaterialTypeTag = "" end
		if MaterialTypeSoundOverrideTag:len() > 0 and MaterialTypeSoundOverrideTag ~= "nil" then MaterialTypeSoundOverrideTag = "		<MaterialTypeSoundOverrideTag>".. MaterialTypeSoundOverrideTag .."</MaterialTypeSoundOverrideTag>\n" else MaterialTypeSoundOverrideTag = "" end

		sDatabase = "  <UnitMemberArtInfo>\n		<Type>".. tostring(UnitMemberInfos.Type) .. "</Type>\n".. fScale .. fZOffset .. Domain.. Granny .. Combat .. MaterialTypeTag .. MaterialTypeSoundOverrideTag .."	</UnitMemberArtInfo>"


		Game.WriteMPMP( "Civ5ArtDefines_UnitMembers.xml", sDatabase, false ) -- Append file
	end	
	Game.WriteMPMP( "Civ5ArtDefines_UnitMembers.xml", "</UnitMemberArtInfos>\n", false ) -- Append file

end

function CopyActivatedMods()
	local activatedMods = Modding.GetActivatedMods()
	for i,v in ipairs(activatedMods) do
		if v.ID ~= MPMPMakerModID then -- but not this mod !
			local folder = Modding.GetModProperty(v.ID, v.Version, "Name");
			folder = tostring(folder) .. " (v ".. tostring(v.Version) .. ")"		
			-- to do: pass modID and version, parse the Mods folder in C++ for .modinfo files to find the correct folder even if it was not conventionnaly named...
			print2 ("Copying " .. folder)
			local bCopied = Game.CopyModDataToMPMP(folder)
			if not bCopied then
				-- convert to civfanatics downloaded name
				folder = string.lower(folder)
				folder = string.gsub(folder, " ", "_")
				folder = string.gsub(folder, ")", "")
				folder = string.gsub(folder, "(", "_")
				print2 ("Failed ! trying " .. folder)
				local bCopied = Game.CopyModDataToMPMP(folder)
			end
		end
	end

	for addin in Modding.GetActivatedModEntryPoints("InGameUIAddin") do
		if addin.ModID ~= MPMPMakerModID then
			local addinFile = Modding.GetEvaluatedFilePath(addin.ModID, addin.Version, addin.File)
			local addinPath = addinFile.EvaluatedPath
			local filename = Path.GetFileNameWithoutExtension(addinPath)
			print2 ("Adding " .. filename .. " to InGame.lua...")
			Game.AddUIAddinToMPMP("InGame.lua", filename)		
		end
	end	

	for addin in Modding.GetActivatedModEntryPoints("CityViewUIAddin") do
		if addin.ModID ~= MPMPMakerModID then
			local addinFile = Modding.GetEvaluatedFilePath(addin.ModID, addin.Version, addin.File)
			local addinPath = addinFile.EvaluatedPath
			local filename = Path.GetFileNameWithoutExtension(addinPath)
			print2 ("Adding " .. filename .. " to InGame.lua...")
			Game.AddUIAddinToMPMP("CityView.lua", filename)	
		end
	end	

	for addin in Modding.GetActivatedModEntryPoints("DiplomacyUIAddin") do
		if addin.ModID ~= MPMPMakerModID then
			local addinFile = Modding.GetEvaluatedFilePath(addin.ModID, addin.Version, addin.File)
			local addinPath = addinFile.EvaluatedPath
			local filename = Path.GetFileNameWithoutExtension(addinPath)
			print2 ("Adding " .. filename .. " to InGame.lua...")
			Game.AddUIAddinToMPMP("LeaderHeadRoot.lua", filename)		
		end
	end
end

function DeleteMP()
	print2 ("Deleting ModPack if exist...")
	Game.DeleteMPMP()
end

function CopyAddedDatabase()
	local sDatabase = ""
	Game.WriteMPMP( LastGamePlayFileName, "<?xml version=\"1.0\" encoding=\"utf-8\"?> \n<!-- generated by MP Modpacks Maker (Gedemon) -->\n<GameData> \n", true ) -- Replace file

	local tables = DB.CreateQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")	
	for t in tables() do	
		if not (string.find(t.name, "sqlite") or checkOriginalTableListe[t.name]) then -- get only the new tables
			print2 ("Copying: " .. t.name)
			local query = "PRAGMA table_info(".. tostring(t.name) ..");"
			local structure = DB.CreateQuery(query)

			sDatabase = GetTablesStructure(t.name)
			sDatabase = sDatabase .. "	<".. tostring(t.name) ..">"		
			Game.WriteMPMP( LastGamePlayFileName, sDatabase, false)

			local columns = {}
			for c in structure() do			
				table.insert(columns, {Name = c.name})
			end

			local query = "SELECT * FROM " .. t.name ..";"	
			for result in DB.Query(query) do
				sDatabase = "		<Row> \n"
				for i, col in pairs(columns) do				
					local tagStr = ""
					local valueStr = tostring(result[col.Name])			
					if valueStr:len() > 0 and valueStr ~= "nil" then sDatabase = sDatabase .. "			<".. col.Name ..">".. valueStr .."</".. col.Name .."> \n" end
				end
				sDatabase = sDatabase .. "		</Row>"
				Game.WriteMPMP( LastGamePlayFileName, sDatabase, false)
			end

			sDatabase = "	</".. tostring(t.name) .."> \n"
			Game.WriteMPMP( LastGamePlayFileName, sDatabase, false)
			sDatabase = ""
		end
	end
	Game.WriteMPMP( LastGamePlayFileName, "</GameData> \n", false)

end


function CopyAudioDatabase()
	local sDatabase = ""
	Game.WriteMPMP( AudioFileName, "<?xml version=\"1.0\" encoding=\"utf-8\"?> \n<!-- generated by MP Modpacks Maker (Gedemon) -->\n<GameData> \n", true ) -- replace file

	local tables = DB.CreateQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")	
	for i, tableName in ipairs(audioTableListe) do	
		print2 ("Copying: " .. tableName)
		local query = "PRAGMA table_info(".. tostring(tableName) ..");"
		local structure = DB.CreateQuery(query)

		sDatabase = "	<".. tostring(tableName) ..">"		
		Game.WriteMPMP( LastGamePlayFileName, sDatabase, false)

		local columns = {}
		for c in structure() do			
			table.insert(columns, {Name = c.name})
		end

		local query = "SELECT * FROM " .. tableName ..";"	
		for result in DB.Query(query) do
			sDatabase = "		<Row> \n"
			for i, col in pairs(columns) do				
				local tagStr = ""
				local valueStr = tostring(result[col.Name])			
				if valueStr:len() > 0 and valueStr ~= "nil" then sDatabase = sDatabase .. "			<".. col.Name ..">".. valueStr .."</".. col.Name .."> \n" end
			end
			sDatabase = sDatabase .. "		</Row>"
			Game.WriteMPMP( LastGamePlayFileName, sDatabase, false)
		end

		sDatabase = "	</".. tostring(tableName) .."> \n"
		Game.WriteMPMP( LastGamePlayFileName, sDatabase, false)
		sDatabase = ""
	end
	Game.WriteMPMP( LastGamePlayFileName, "</GameData> \n", false)

end

function CopyTextDatabase()
	print2 ("Copying: LocalizedText")
	Game.WriteMPMP( textFileName, "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!-- generated by MP Modpacks Maker (Gedemon) -->\n<GameData>\n	<Language_en_US>", true ) -- Create file
	local sDatabase = ""
	--local query = "SELECT * FROM LocalizedText;"	
	local query = "SELECT * FROM Language_en_US;"	
	for result in DB.Query(query) do
		sDatabase = "		<Replace Tag=\"".. tostring(result.Tag) .."\"> \n"
		sDatabase = sDatabase .. "			<Text>\n				".. result.Text .."\n			</Text>\n"
		sDatabase = sDatabase .. "		</Replace>"
		Game.WriteMPMP( textFileName, sDatabase, false)
	end
	Game.WriteMPMP( textFileName, "	</Language_en_US> \n</GameData>", false)
end

-- unused...
function CopyFullDatabase()
	local sDatabase = ""
	Game.WriteMPMP( GamePlayFileName, "<?xml version=\"1.0\" encoding=\"utf-8\"?> \n<!-- generated by MP Modpacks Maker (Gedemon) -->\n<GameData> \n", true ) -- Open file

	local tables = DB.CreateQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")	
	for t in tables() do	
		if not (string.find(t.name, "sqlite") ) then --or string.find(t.name, "ArtDefine_")) then
			print2 ("Copying: " .. t.name)
			local query = "PRAGMA table_info(".. tostring(t.name) ..");"
			local structure = DB.CreateQuery(query)

			sDatabase = GetTablesStructure(t.name)
			sDatabase = sDatabase .. "	<".. tostring(t.name) ..">"		
			WriteToGamePlayFile(sDatabase)

			local columns = {}
			for c in structure() do			
				table.insert(columns, {Name = c.name})
			end

			local query = "SELECT * FROM " .. t.name ..";"	
			for result in DB.Query(query) do
				sDatabase = "		<Row> \n"
				for i, col in pairs(columns) do				
					local tagStr = ""
					local valueStr = tostring(result[col.Name])			
					if valueStr:len() > 0 and valueStr ~= "nil" then sDatabase = sDatabase .. "			<".. col.Name ..">".. valueStr .."</".. col.Name .."> \n" end
				end
				sDatabase = sDatabase .. "		</Row>"
				WriteToGamePlayFile(sDatabase)
			end

			sDatabase = "	</".. tostring(t.name) .."> \n"
			WriteToGamePlayFile(sDatabase)
			sDatabase = ""
		end
	end
	sDatabase = sDatabase .. "</GameData> \n"
	WriteToGamePlayFile(sDatabase)

end

function WriteToGamePlayFile(str)
	Game.WriteMPMP( GamePlayFileName, str, false ) -- Append file
end

function print2(str)
	--Events.GameplayAlertMessage(str)
	--ContextPtr:LookUpControl("/InGame/TopPanel/CurrentTurn"):SetText( str )
	print(str)
end