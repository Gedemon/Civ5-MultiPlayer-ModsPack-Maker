-- MPMP_Maker
-- Author: Gedemon
-- DateCreated: 31-Jan-14 03:16:29
--------------------------------------------------------------
--[[
	Allow the creation of a MPModspack folder in assets/DLC to copy (and format) activated mods

	usage: 
		- activate all desired mods, launch a new game from the mods menu, and from "MPMP_Maker" context in Firetuner call CreateMP()
		- check MPMPMaker.log for errors (but I need to add a lot more in it, actually it can output "done" even if something goes wrong) after creation
		- quit game (not to main menu, completly !)
		- start civ5 again, launch a new game from the main menu, the modspack should be activated
		- check database.log if the game crashes before the main menu, or if there are errors in the Lua.log
	
	limitations : 
		- you must manually delete the MP_MODSPACK folder in Steam\steamapps\common\sid meier's civilization v\Assets\DLC if you want to use the normal game again
		- a savegame can't know if a modspack is used
		- how to check for same modspack in MP ?
		- what if other DLC are activated/deactivated while the modpack is active ?
		- can't be used with DLL mods without merging both projects (C++ and this lua file as an InGameUIaddin)
		- all mods won't work in MP, changing gameplay could cause massive desync issues if not done with MP in mind

	todo: 
		- create a "desinstall" mod with a copy of all UI files that are loaded in the MPModspack so that they can be removed if that mod is activated (they should override the DLC UI files). That "MPModpack desinstallation" mod would be deleted/recreated each time a MP modspack is created
		- then make sure we are not copying in the DLC folder some files that can't be loaded with mods !
		- create a small additional DLC (optional installation, as this one would require manual desinstallation) to handle automatically the launch of a small game session to configure the MP Modspack when entering the mod's menu
		- the UI...
		- handle DLL mods that may need renaming (see also limitations as a DLL with the mandatory Game function must be loaded)

		- maybe put all frontend custom files in a separate DLC folder, and edit them (no delete/replace) with the content of the modded or original files (still need an uninstall mod for UI files):
		std::ifstream ifs("input.txt", std::ios::binary);
		std::ofstream ofs("output.txt", std::ios::binary);
		ofs << ifs.rdbuf();
--]]

local MPMPMakerModID = "c70dee73-8179-4a19-a3e5-1d931908ff43" -- we don't want to include MPMPMaker in the modspack
local GamePlayFileName = "CIV5Units.xml" -- that's where we write the whole database
local textFileName = "CIV5Units_Mongol.xml" -- that's where we write the text database. (we can't use override for the text files, the localization is handled separately)
local AudioFileName = "CIV5Civilization_Mongol.xml" -- that's where we write the audio database. (we can't change the structure on those, neither update previous entries, just add new entries)

-- Table that are already filled when the XMLSerializer is called
local tableToIgnore = {
	["ApplicationInfo"] = true,
	["ScannedFiles"] = true,
	["DownloadableContent"] = true,
	["MapScriptOptionPossibleValues"] = true,
	["MapScriptOptions"] = true,
	["MapScriptRequiredDLC"] = true,
	["MapScripts"] = true,
	["Map_Folders"] = true,
	["Map_Sizes"] = true,
	["Maps"] = true,
	["MemoryInfos"] = true,
}

-- Table that are already defined but need to be (re)filled with the mods data
local structureToIgnore = { 
	["ArtDefine_LandmarkTypes"] = true,
	["ArtDefine_Landmarks"] = true,
	["ArtDefine_StrategicView"] = true,
	["ArtDefine_UnitInfoMemberInfos"] = true,
	["ArtDefine_UnitInfos"] = true,
	["ArtDefine_UnitMemberCombatWeapons"] = true,
	["ArtDefine_UnitMemberCombats"] = true,
	["ArtDefine_UnitMemberInfos"] = true,
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
}

local audioTableListe = {
	"Audio_2DSounds",
	"Audio_3DSounds",
	"Audio_SoundScapeElementScripts",
	"Audio_SoundScapeElements",
	"Audio_SoundScapes",
	"Audio_Sounds",
}

function CreateMP()

	print2 ("Deleting previous ModPack if exist...")
	Game.DeleteMPMP()
	
	print2 ("Creating New ModPack folder...")
	Game.CreateMPMP()
	
	print2 ("Copying Activated Mods...")
	CopyActivatedMods()
	
	print2 ("Getting the Database...")
	CopyFullDatabase()

	print2 ("Getting Texts...")
	CopyTextDatabase()

	print2 ("Getting Audio Tables...")
	CopyAudioDatabase()
	
	--ContextPtr:LookUpControl("/InGame/TopPanel/TopPanelInfoStack"):SetHide( false )
	
	print2 ("MP_MODSPACK Done !")
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

function CopyAudioDatabase()
	local sDatabase = ""
	Game.WriteMPMP( AudioFileName, "<?xml version=\"1.0\" encoding=\"utf-8\"?> \n<!-- generated by MP Modpacks Maker (Gedemon) -->\n<GameData> \n", true ) -- replace file

	local tables = DB.CreateQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")	
	for i, tableName in ipairs(audioTableListe) do	
		print2 ("Copying: " .. tableName)
		local query = "PRAGMA table_info(".. tostring(tableName) ..");"
		local structure = DB.CreateQuery(query)

		sDatabase = "	<".. tostring(tableName) ..">"		
		Game.WriteMPMP( AudioFileName, sDatabase, false)

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
			Game.WriteMPMP( AudioFileName, sDatabase, false)
		end

		sDatabase = "	</".. tostring(tableName) .."> \n"
		Game.WriteMPMP( AudioFileName, sDatabase, false)
		sDatabase = ""
	end
	Game.WriteMPMP( AudioFileName, "</GameData> \n", false)

end

function CopyTextDatabase()
	print2 ("Copying: Language_en_US")
	Game.WriteMPMP( textFileName, "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!-- generated by MP Modpacks Maker (Gedemon) -->\n<GameData>\n	<Language_en_US>", true ) -- Create file
	local sDatabase = ""	
	local query = "SELECT * FROM Language_en_US;" -- to do: select by user language...
	for result in DB.Query(query) do
		if not (string.find(tostring(result.Tag), "TURN_REMINDER_EMAIL")) then -- to do : encode the HTML tags in those strings...
			sDatabase = "		<Replace Tag=\"".. tostring(result.Tag) .."\"> \n"
			sDatabase = sDatabase .. "			<Text>\n				".. tostring(result.Text) .."\n			</Text>\n"
			sDatabase = sDatabase .. "		</Replace>"
			Game.WriteMPMP( textFileName, sDatabase, false)
		end
	end
	Game.WriteMPMP( textFileName, "	</Language_en_US> \n</GameData>", false)
end

function CopyFullDatabase()
	local sDatabase = ""
	Game.WriteMPMP( GamePlayFileName, "<?xml version=\"1.0\" encoding=\"utf-8\"?> \n<!-- generated by MP Modpacks Maker (Gedemon) -->\n<GameData> \n", true ) -- Open file

	local tables = DB.CreateQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")	
	for t in tables() do	
		if not (string.find(t.name, "sqlite") or tableToIgnore[t.name] ) then
			print2 ("Copying: " .. t.name)
			local query = "PRAGMA table_info(".. tostring(t.name) ..");"
			local structure = DB.CreateQuery(query)

			if not (structureToIgnore[t.name] ) then
				sDatabase = GetTablesStructure(t.name)
			end
			sDatabase = sDatabase .. "	<".. tostring(t.name) ..">\n		<Delete />\n"		
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