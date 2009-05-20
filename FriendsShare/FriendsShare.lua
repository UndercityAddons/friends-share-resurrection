--[[
FriendsShare: AddOn to keep a global friends list across alts on the same server.
]]

local FriendsShare_Version =11 
local FriendsShare_origAddFriend
local FriendsShare_origRemoveFriend
local FriendsShare_realmName
local FriendsShare_playerFaction
local FriendsShare_lastTry = 0

function FriendsShare_CommandHandler(msg)

	if ( msg == "rebuild" ) then
		friendsShareList[FriendsShare_realmName] = nil
		FriendsShare_SyncLists()
		DEFAULT_CHAT_FRAME:AddMessage("Realmwide friendslist rebuilt.")
	else
		DEFAULT_CHAT_FRAME:AddMessage("Type '/friendsshare rebuild' if you want to rebuild the realmwide friendslist")
	end
end

function FriendsShare_RemoveFriend(friend)

	-- "friend" can either be a string with the name
	-- of a friend or a number which is the friend index
	if ( tonumber( friend ) == nil ) then
		-- cannot convert to number, therefore it has to be a
		-- string containing the name
		friendsShareList[FriendsShare_realmName][ string.lower(friend) ] = nil
		friendsShareNotes[FriendsShare_realmName][ string.lower(friend) ] = nil
		friendsShareDeleted[FriendsShare_realmName][ string.lower(friend) ] = 1
	else
		-- "friend" could be converted to a number and therefore
		-- cannot be a string containing the name

		local friendName = GetFriendInfo(friend)
		if ( friendName ) then
			friendsShareList[FriendsShare_realmName][ string.lower( friendName) ] = nil
			friendsShareNotes[FriendsShare_realmName][ string.lower( friendName ) ] = nil
			friendsShareDeleted[FriendsShare_realmName][ string.lower( friendName) ] = 1
		end
	end

	FriendsShare_origRemoveFriend(friend)
end

function FriendsShare_AddFriend(friend)

	FriendsShare_origAddFriend(friend)

	if ( friend == "target" ) then
		friend = UnitName("target")
	end

	friendsShareList[FriendsShare_realmName][string.lower(friend)] = FriendsShare_playerFaction
	friendsShareDeleted[FriendsShare_realmName][string.lower(friend)] = nil
end

function FriendsShare_SetFriendNotes(friendIndex, noteText)

	FriendsShare_origSetFriendNotes(friendIndex, noteText)

	local friendName
	if ( tonumber( friendIndex ) == nil ) then
		friendName = friendIndex
	else
		friendName = string.lower(GetFriendInfo(friendIndex))
	end

	if ( friendName ) then
		friendsShareNotes[FriendsShare_realmName][friendName] = noteText
	else
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: ERROR: Could not save new note to database. This note will be overwritten the next time you log in."))
	end
end

function FriendsShare_SyncLists()

	local iItem, currentFriend, localFriends, note, trash, localNotes

	-- initialize friendsShareList
	if ( friendsShareList == nil ) then
		friendsShareList = { }
	end

	if ( friendsShareList[FriendsShare_realmName] == nil) then
		friendsShareList[FriendsShare_realmName] = { }
	end

	-- initialize friendsShareDeleted
	if ( friendsShareDeleted == nil ) then
		friendsShareDeleted = { }
	end

	if ( friendsShareDeleted[FriendsShare_realmName] == nil) then
		friendsShareDeleted[FriendsShare_realmName] = { }
	end

	-- initialize friendsShareNotes
	if ( friendsShareNotes == nil ) then
		friendsShareNotes = { }
	end

	if ( friendsShareNotes[FriendsShare_realmName] == nil) then
		friendsShareNotes[FriendsShare_realmName] = { }
	end

	localFriends = { }
	localNotes = { }
	local retval = true

	local numFriends = GetNumFriends()

	for iItem = 1, numFriends, 1 do
		currentFriend, trash, trash, trash, trash, trash, note = GetFriendInfo(iItem)

		if ( currentFriend ) then
			localFriends[string.lower(currentFriend)] = 1
			localNotes[string.lower(currentFriend)] = note
		else
			-- friend list not loaded from server. we will try again later.
			return false
		end
	end

	local index, value
	for index,value in pairs(localFriends) do
		if ( friendsShareDeleted[FriendsShare_realmName][index] ) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removing \"%s\" from friends list.", index))
			RemoveFriend(index)
		else
			friendsShareList[FriendsShare_realmName][index] = FriendsShare_playerFaction

			if (friendsShareNotes[FriendsShare_realmName][index] ~= nil) then
				if (localNotes[index] == nil or friendsShareNotes[FriendsShare_realmName][index] ~= localNotes[index]) then
					if ( friendsShareNotes[FriendsShare_realmName][index] == "" ) then
						DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Removeing note for \"%s\".", index))
					else
						DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Setting note \"%s\" for \"%s\".", friendsShareNotes[FriendsShare_realmName][index], index))
					end
					FriendsShare_origSetFriendNotes(index, friendsShareNotes[FriendsShare_realmName][index])
				end
			elseif (localNotes[index] ~= nil) then
				-- save to database
				friendsShareNotes[FriendsShare_realmName][index] = localNotes[index]
			end
		end
	end

	for index,value in pairs(friendsShareList[FriendsShare_realmName]) do
		if ( value == FriendsShare_playerFaction and localFriends[index] == nil and not (index == string.lower(UnitName("player")))) then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: Adding \"%s\" to friends list.", index))
			AddFriend(index)

			if (friendsShareNotes[FriendsShare_realmName][index] ~= nil) then
				-- We cannot set the notes now because adding a new user takes
				-- some time. We return false which triggers another update
				-- as soon as the user opens the friends list.

				retval = false
			end
		end
	end

	return retval
end

function FriendsShare_OnEvent(event)

	if ( event == "PLAYER_ENTERING_WORLD" ) then
		this:UnregisterEvent("PLAYER_ENTERING_WORLD")
		
		FriendsShare_realmName = GetCVar("realmName")
		FriendsShare_playerFaction = UnitFactionGroup("player")

		SLASH_FRIENDSSHARE1 = "/friendsshare"
		SlashCmdList["FRIENDSSHARE"] = function(msg) FriendsShare_CommandHandler(msg) end

		FriendsShare_origAddFriend = AddFriend
		AddFriend = FriendsShare_AddFriend

		FriendsShare_origRemoveFriend = RemoveFriend
		RemoveFriend = FriendsShare_RemoveFriend

		FriendsShare_origSetFriendNotes = SetFriendNotes
		SetFriendNotes = FriendsShare_SetFriendNotes

		-- call ShowFriends() to trigger an FRIENDLIST_UPDATE event
		-- after the friends list is loaded

		this:RegisterEvent("FRIENDLIST_UPDATE")
		ShowFriends()
		
		DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection %i loaded.", FriendsShare_Version ))
	elseif ( event == "FRIENDLIST_UPDATE" ) then

		-- This is to prevent update spam loops for slow clients
		-- Do not try to update the list more than every 5 seconds
		local time = GetTime()
		if ( ( time - FriendsShare_lastTry ) > 5 ) then

			FriendsShare_lastTry = time

			if ( not FriendsShare_SyncLists() ) then
				DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends list not ready, will try again later."))

				-- call ShowFriends() to trigger a new FRIENDLIST_UPDATE event
				ShowFriends()
			else
				DEFAULT_CHAT_FRAME:AddMessage(string.format("FriendsShare Resurrection: friends list synced."))

				-- The list is updated, unregister from the event.
				-- We sync only once per run.
				this:UnregisterEvent("FRIENDLIST_UPDATE")
			end
		end
	end
end

