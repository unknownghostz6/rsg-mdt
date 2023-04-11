local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterCommand(""..Config.Command.."", function(source, args)
    local _source = source
	local tablex = {}
    local _source = source
	local xPlayer = RSGCore.Functions.GetPlayer(_source)
	local group = RSGCore.Functions.GetPermission(_source)
    local cid = xPlayer.PlayerData.citizenid
	local officername = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
	local job_access = false
        for k,v in pairs(Config.Jobs) do
    if xPlayer.PlayerData.job.name == v then
		job_access = true
				exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_reports` ORDER BY `id` DESC LIMIT 6) sub ORDER BY `id` DESC", {}, function(reports)
					for r = 1, #reports do
						reports[r].charges = json.decode(reports[r].charges)
					end
					exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_warrants` ORDER BY `id` DESC LIMIT 6) sub ORDER BY `id` DESC", {}, function(warrants)
						for w = 1, #warrants do
							warrants[w].charges = json.decode(warrants[w].charges)
						end
						exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_telegrams` ORDER BY `id` DESC LIMIT 6) sub ORDER BY `id` DESC", {}, function(note)
							for n = 1, #note do
								note[n].charges = json.decode(note[n].charges)
							end
						TriggerClientEvent('rsg-mdt:toggleVisibilty', _source, reports, warrants, officername, job, jobgrade, note)
					end)
				end)
			end)
            end
        end
        if job_access == false then
            return false
        end
end)

RegisterServerEvent("rsg-mdt:getOffensesAndOfficer")
AddEventHandler("rsg-mdt:getOffensesAndOfficer", function()
	local usource = source
	local xPlayer = RSGCore.Functions.GetPlayer(usource)
	--local officername = (Character.firstname.. " " ..Character.lastname)
	local officername = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname

	local charges = {}
	exports.oxmysql:fetch('SELECT * FROM fine_types', {}, function(fines)
		for j = 1, #fines do
			if fines[j].category == 0 or fines[j].category == 1 or fines[j].category == 2 or fines[j].category == 3 then
				table.insert(charges, fines[j])
			end
		end

		TriggerClientEvent("rsg-mdt:returnOffensesAndOfficer", usource, charges, officername)
	end)
end)


RegisterServerEvent("rsg-mdt:performOffenderSearch")
AddEventHandler("rsg-mdt:performOffenderSearch", function(query)
	local usource = source
	local matches = {}
	exports.oxmysql:query("SELECT * FROM `players` WHERE `charinfo` LIKE ?", {string.lower('%'..query..'%')}, function(result) -- % wildcard, needed to search for all alike results

		for index, data in ipairs(result) do
			if data.charinfo then
				local player = json.decode(data.charinfo)
				local metadata = json.decode(data.metadata)
				local core = RSGCore.Functions.GetPlayerByCitizenId(data.citizenid)

				if core then
					player = core['PlayerData']['charinfo']
					metadata = core['PlayerData']['metadata']
				end

				player.id = data.id
				player.metadata = metadata
				player.citizenid = data.citizenid
				table.insert(matches, player)
			end
		end

		TriggerClientEvent("rsg-mdt:returnOffenderSearchResults", usource, matches)
	end)
end)


---------------------------------------------------------------------------------------




RegisterServerEvent("rsg-mdt:getOffenderDetails")
AddEventHandler("rsg-mdt:getOffenderDetails", function(offender)
	local usource = source

	--print(offender.id)

    exports.oxmysql:fetch('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {offender.id}, function(result)

		if result[1] then
            offender.notes = result[1].notes
            offender.mugshot_url = result[1].mugshot_url
            offender.bail = result[1].bail
		else
			offender.notes = ""
			offender.mugshot_url = ""
			offender.bail = false
		end

        exports.oxmysql:fetch('SELECT * FROM `user_convictions` WHERE `char_id` = ?', {offender.id}, function(convictions)

            if convictions[1] then
                offender.convictions = {}
                for i = 1, #convictions do
                    local conviction = convictions[i]
                    offender.convictions[conviction.offense] = conviction.count
                end
            end

            exports.oxmysql:fetch('SELECT * FROM `mdt_warrants` WHERE `char_id` = ?', {offender.id}, function(warrants)

                if warrants[1] then
                    offender.haswarrant = true
                end
			
				TriggerClientEvent("rsg-mdt:returnOffenderDetails", usource, offender)
            end)
        end)
    end)
end)



RegisterServerEvent("rsg-mdt:getOffenderDetailsById")
AddEventHandler("rsg-mdt:getOffenderDetailsById", function(char_id)
    local usource = source
	print(char_id)

    exports.oxmysql:execute('SELECT * FROM `players` WHERE `id` = ?', {char_id}, function(result)

        local offender = result[1]

        if not offender then
            TriggerClientEvent("rsg-mdt:closeModal", usource)
            TriggerClientEvent("rsg-mdt:sendNotification", usource, "This person no longer exists.")
            return
        end
    
        exports.oxmysql:execute('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {char_id}, function(result)

			if result[1] then
                offender.notes = result[1].notes
                offender.mugshot_url = result[1].mugshot_url
                offender.bail = result[1].bail
			else
				offender.notes = ""
				offender.mugshot_url = ""
				offender.bail = false
			end

            exports.oxmysql:execute('SELECT * FROM `user_convictions` WHERE `char_id` = ?', {char_id}, function(convictions) 

                if convictions[1] then
                    offender.convictions = {}
                    for i = 1, #convictions do
                        local conviction = convictions[i]
                        offender.convictions[conviction.offense] = conviction.count
                    end
                end

                exports.oxmysql:execute('SELECT * FROM `mdt_warrants` WHERE `char_id` = ?', {char_id}, function(warrants)
                    
                    if warrants[1] then
                        offender.haswarrant = true
                    end

					TriggerClientEvent("rsg-mdt:returnOffenderDetails", usource, offender)
                end)
            end)
        end)
    end)
end)

RegisterServerEvent("rsg-mdt:saveOffenderChanges")
AddEventHandler("rsg-mdt:saveOffenderChanges", function(id, changes, identifier)
	local usource = source

	exports.oxmysql:fetch('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {id}, function(result)
		if result[1] then
			exports.oxmysql:execute('UPDATE `user_mdt` SET `notes` = ?, `mugshot_url` = ?, `bail` = ? WHERE `char_id` = ?', {changes.notes, changes.mugshot_url, changes.bail, id})
		else
			exports.oxmysql:insert('INSERT INTO `user_mdt` (`char_id`, `notes`, `mugshot_url`, `bail`) VALUES (?, ?, ?, ?)', {id, changes.notes, changes.mugshot_url, changes.bail})
		end

		if changes.convictions ~= nil then
			for conviction, amount in pairs(changes.convictions) do	
				exports.oxmysql:execute('UPDATE `user_convictions` SET `count` = ? WHERE `char_id` = ? AND `offense` = ?', {id, amount, conviction})
			end
		end

		for i = 1, #changes.convictions_removed do
			exports.oxmysql:execute('DELETE FROM `user_convictions` WHERE `char_id` = ? AND `offense` = ?', {id, changes.convictions_removed[i]})
		end

		TriggerClientEvent("rsg-mdt:sendNotification", usource, Config.Notify['1'])
	end)
end)

RegisterServerEvent("rsg-mdt:saveReportChanges")
AddEventHandler("rsg-mdt:saveReportChanges", function(data)
	exports.oxmysql:execute('UPDATE `mdt_reports` SET `title` = ?, `incident` = ? WHERE `id` = ?', {data.id, data.title, data.incident})
	TriggerClientEvent("rsg-mdt:sendNotification", source, Config.Notify['2'])
end)

RegisterServerEvent("rsg-mdt:deleteReport")
AddEventHandler("rsg-mdt:deleteReport", function(id)
	exports.oxmysql:execute('DELETE FROM `mdt_reports` WHERE `id` = ?', {id})
	TriggerClientEvent("rsg-mdt:sendNotification", source, Config.Notify['3'])
end)

RegisterServerEvent("rsg-mdt:deleteNote")
AddEventHandler("rsg-mdt:deleteNote", function(id)
	exports.oxmysql:execute('DELETE FROM `mdt_telegrams` WHERE `id` = ?', {id})
	TriggerClientEvent("rsg-mdt:sendNotification", source, Config.Notify['9'])
end)

RegisterServerEvent("rsg-mdt:submitNewReport")
AddEventHandler("rsg-mdt:submitNewReport", function(data)
	local usource = source
	local tablex = {}
    local _source = source
	local xPlayer = RSGCore.Functions.GetPlayer(usource)
	--local cid = xPlayer.PlayerData.citizenid
	local officername = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname

	charges = json.encode(data.charges)
	data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
	exports.oxmysql:insert('INSERT INTO `mdt_reports` (`char_id`, `title`, `incident`, `charges`, `author`, `name`, `date`) VALUES (?, ?, ?, ?, ?, ?, ?)', {data.char_id, data.title, data.incident, charges, officername, data.name, data.date,}, function(id)
		TriggerEvent("rsg-mdt:getReportDetailsById", id, usource)
		TriggerClientEvent("rsg-mdt:sendNotification", usource, Config.Notify['4'])
	end)

	for offense, count in pairs(data.charges) do
		exports.oxmysql:fetch('SELECT * FROM `user_convictions` WHERE `offense` = ? AND `char_id` = ?', {offense, data.char_id}, function(result)
			if result[1] then
				exports.oxmysql:execute('UPDATE `user_convictions` SET `count` = ? WHERE `offense` = ? AND `char_id` = ?', {data.char_id, offense, count + 1})
			else
				exports.oxmysql:insert('INSERT INTO `user_convictions` (`char_id`, `offense`, `count`) VALUES (?, ?, ?)', {data.char_id, offense, count})
			end
		end)
	end
end)

RegisterServerEvent("rsg-mdt:submitNote")
AddEventHandler("rsg-mdt:submitNote", function(data)
	local usource = source
	local tablex = {}
    local _source = source
	local xPlayer = RSGCore.Functions.GetPlayer(usource)
	--local cid = xPlayer.PlayerData.citizenid
	local officername = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
	charges = json.encode(data.charges)
	data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
	exports.oxmysql:insert('INSERT INTO `mdt_telegrams` ( `title`, `incident`, `author`, `date`) VALUES (?, ?, ?, ?)', {data.title, data.note, officername, data.date,}, function(id)
		TriggerEvent("rsg-mdt:getNoteDetailsById", id, usource)
		TriggerClientEvent("rsg-mdt:sendNotification", usource, Config.Notify['8'])
	end)
end)

RegisterServerEvent("rsg-mdt:performReportSearch")
AddEventHandler("rsg-mdt:performReportSearch", function(query)
	local usource = source
	local matches = {}
	exports.oxmysql:fetch("SELECT * FROM `mdt_reports` WHERE `id` LIKE @query OR LOWER(`title`) LIKE @query OR LOWER(`name`) LIKE @query OR LOWER(`author`) LIKE @query or LOWER(`charges`) LIKE @query", {
		['@query'] = string.lower('%'..query..'%') -- % wildcard, needed to search for all alike results
	}, function(result)

		for index, data in ipairs(result) do
			data.charges = json.decode(data.charges)
			table.insert(matches, data)
		end

		TriggerClientEvent("rsg-mdt:returnReportSearchResults", usource, matches)
	end)
end)

RegisterServerEvent("rsg-mdt:getWarrants")
AddEventHandler("rsg-mdt:getWarrants", function()
	local usource = source
	exports.oxmysql:fetch("SELECT * FROM `mdt_warrants`", {}, function(warrants)
		for i = 1, #warrants do
			warrants[i].expire_time = ""
			warrants[i].charges = json.decode(warrants[i].charges)
		end
		TriggerClientEvent("rsg-mdt:returnWarrants", usource, warrants)
	end)
end)

RegisterServerEvent("rsg-mdt:submitNewWarrant")
AddEventHandler("rsg-mdt:submitNewWarrant", function(data)
	local usource = source
	local tablex = {}
    local _source = source
	local xPlayer = RSGCore.Functions.GetPlayer(usource)
	--local cid = xPlayer.PlayerData.citizenid
	local officername = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname

	data.charges = json.encode(data.charges)
	data.author = officername
	data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
	exports.oxmysql:insert('INSERT INTO `mdt_warrants` (`name`, `char_id`, `report_id`, `report_title`, `charges`, `date`, `expire`, `notes`, `author`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {data.name, data.char_id, data.report_id, data.report_title, data.charges, data.date, data.expire, data.notes, data.author}, function()
		TriggerClientEvent("rsg-mdt:completedWarrantAction", usource)
		TriggerClientEvent("rsg-mdt:sendNotification", usource, Config.Notify['5'])
	end)
end)

RegisterServerEvent("rsg-mdt:deleteWarrant")
AddEventHandler("rsg-mdt:deleteWarrant", function(id)
	local usource = source
	exports.oxmysql:execute('DELETE FROM `mdt_warrants` WHERE `id` = ?', {id}, function()
		TriggerClientEvent("rsg-mdt:completedWarrantAction", usource)
	end)
	TriggerClientEvent("rsg-mdt:sendNotification", usource, Config.Notify['6'])
end)

RegisterServerEvent("rsg-mdt:getReportDetailsById")
AddEventHandler("rsg-mdt:getReportDetailsById", function(query, _source)
	if _source then source = _source end
	local usource = source
	exports.oxmysql:fetch("SELECT * FROM `mdt_reports` WHERE `id` = ?", {query}, function(result)
		if result and result[1] then
			result[1].charges = json.decode(result[1].charges)
			TriggerClientEvent("rsg-mdt:returnReportDetails", usource, result[1])
		else
			TriggerClientEvent("rsg-mdt:closeModal", usource)
			TriggerClientEvent("rsg-mdt:sendNotification", usource, Config.Notify['7'])
		end
	end)
end)

RegisterServerEvent("rsg-mdt:getNoteDetailsById")
AddEventHandler("rsg-mdt:getNoteDetailsById", function(query, _source)
	if _source then source = _source end
	local usource = source
	exports.oxmysql:fetch("SELECT * FROM `mdt_telegrams` WHERE `id` = ?", {query}, function(result)
		if result and result[1] then
			TriggerClientEvent("rsg-mdt:returnNoteDetails", usource, result[1])
		else
			TriggerClientEvent("rsg-mdt:closeModal", usource)
			TriggerClientEvent("rsg-mdt:sendNotification", usource, Config.Notify['8'])
		end
	end)
end)