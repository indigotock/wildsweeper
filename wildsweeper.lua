require "Window"

local wildsweeper = {} 

local eTileType = {}
eTileType.empty = 1
eTileType.bomb = 2

local tDifficulties = {}
tDifficulties[1] = { text='Wimpy', colour = ApolloColor.new('ItemQuality_Average'), size = 8, bombs = 10 }
tDifficulties[2] = { text='Easy', colour = ApolloColor.new('ItemQuality_Good'), size = 10, bombs = 20 }
tDifficulties[3] = { text='Normal', colour = ApolloColor.new('ItemQuality_Excellent'), size = 16, bombs = 50 }
tDifficulties[4] = { text='Hard', colour = ApolloColor.new('ItemQuality_Superb'), size = 20, bombs = 100 }
tDifficulties[5] = { text='EXTREME!', colour = ApolloColor.new('ItemQuality_Legendary'), size = 25, bombs = 150 }

local aNumColours = {}
aNumColours[1] = 'ItemQuality_Inferior'
aNumColours[2] = 'ItemQuality_Average'
aNumColours[3] = 'ItemQuality_Average'
aNumColours[4] = 'ItemQuality_Good'
aNumColours[5] = 'ItemQuality_Excellent'
aNumColours[6] = 'ItemQuality_Superb'
aNumColours[7] = 'ItemQuality_Legendary'
aNumColours[8] = 'ItemQuality_Artifact'

local tSprites = {}


tSprites.bomb = {'IconSprites:Icon_Windows_UI_CRB_Marker_Bomb', ApolloColor.new('white')}
tSprites.check = {'IconSprites:Icon_MapNode_Map_Checkmark', ApolloColor.new('white')}
tSprites.flag = {'CRB_InterfaceMenuList:spr_InterfaceMenuList_BlueFlagStretch', ApolloColor.new('white')}
tSprites.cross = {'ClientSprites:LootCloseBox_Holo', ApolloColor.new('white')}
for i=1,8 do
	tSprites['num'..i] = {'CRB_NumberFloaters:sprFloater_Normal' .. i, ApolloColor.new(aNumColours[i])}
end

function wildsweeper:new(o)
	local o = o or {}
	setmetatable(o, self)
	self.__index = self 	
	self.tTiles = {}
	self.cBoard = nil
	return o
end

function wildsweeper:Init()
	Apollo.RegisterAddon(self)
end

function wildsweeper:open_window()
	self.wndMain:Invoke()
	self:event_change_difficulty(nil,nil,2)
	self:event_new_game()
end

function wildsweeper:OnLoad()
  -- load our form file
  self.xmlDoc = XmlDoc.CreateFromFile("forms.xml")
  self.xmlDoc:RegisterCallback("form_load", self)
  Apollo.RegisterSlashCommand("minesweeper","open_window",self)
  Apollo.RegisterSlashCommand("wildsweeper","open_window",self)
  Apollo.RegisterSlashCommand("sweep","open_window",self)
end

function wildsweeper:form_load()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "container", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end

		self.wndMain:Show(false, true)
		self.wndMain:FindChild('scores'):ArrangeChildrenVert()
		local db = Apollo.GetPackage('indigotock.btools.gui.drop_button').tPackage
		local newbtn = db(self.wndMain:FindChild('new_button'),{sText='New Game',nWindowHeight=190, nWindowWidth=200})
		newbtn:set_content(self.xmlDoc,'new_dialog',self)
		self.cDifficultySlider = newbtn.cControl:FindChild('diff_slider')

		self.cDifficultySlider:AddEventHandler("SliderBarChanged", 'event_change_difficulty', self)
		self:event_change_difficulty(nil,self.cDifficultySlider,2)
		self.cBoard = self.wndMain:FindChild("board")
		self:event_change_difficulty(nil,nil,2)
		self:event_new_game()
	end
end

function wildsweeper:event_change_difficulty(handler, control, val)
	val = math.floor(val)
	self.cDifficultySlider:SetValue(val)
	local text = self.wndMain:FindChild('diff_text')
	text:SetText(tDifficulties[val].text)
	text:SetTextColor(tDifficulties[val].colour)
end

function wildsweeper:event_new_game()
	local diff = diff or self.cDifficultySlider:GetValue()
	diff = diff or 1
	self:new_board(tDifficulties[diff])
end

function wildsweeper:new_board(diff)
	self.bWon = nil
	self.wndMain:FindChild('win_frame'):Show(false,true)
	self.wndMain:FindChild('lose_frame'):Show(false,true)
	self.diff = diff
	diff = diff or tDifficulties[1]
	self.oTimer = nil
	self.tTiles = {}
	self.bClickedOnce = false
	self.tScore = {time = 0, clicks = 0, flags = 0}
	self.cBoard:DestroyChildren()
	for xv=1,diff.size do
		for yv=1,diff.size do
			local button = Apollo.LoadForm(self.xmlDoc,"game_tile",self.cBoard,self)
			button:Move(0,0,400/diff.size,400/diff.size)
			if not self.tTiles[xv] then self.tTiles[xv] = {} end
			self.tTiles[xv][yv] = button
			button:SetData({x=xv,y=yv,eType = 1, bFlagged = false})
		end
	end
	local count = 0
	for i=1,diff.bombs do --Generate bombs. sometimes creates duplicates but that's ok
		self.tTiles[math.random(diff.size)][math.random(diff.size)]:GetData().eType = eTileType.bomb
		count = count + 1
	end
	self.wndMain:FindChild('bomb_count'):SetText(count)
	self.cBoard:ArrangeChildrenTiles()
	self:update_score()
end

function wildsweeper:get_adjacent_bombs(xp,yp)
	local retVal = 0
	for xv = xp-1, xp+1 do
		for yv = yp-1, yp+1 do
			if self.tTiles[xv] and self.tTiles[xv][yv] then
				if self.tTiles[xv][yv]:GetData().eType == eTileType.bomb then
					retVal = retVal + 1
				end
			end
		end
	end
	return retVal
end

function wildsweeper:update_score()
	self.wndMain:FindChild('time_taken'):SetText(self.tScore.time)
	self.wndMain:FindChild('clicks'):SetText(self.tScore.clicks)
	self.wndMain:FindChild('flags'):SetText(self.tScore.flags)
end

function wildsweeper:event_fire_timer()
	self.tScore.time = self.tScore.time + 1
	self:update_score()
end

function wildsweeper:event_click_tile(h,c,m, bAuto)
	if not self.bClickedOnce then
		self.bClickedOnce = true
		self.oTimer = ApolloTimer.Create(1,true,'event_fire_timer',self)
	end
	if not c then return end
	if not bAuto then
		self.tScore.clicks = self.tScore.clicks + 1
	end
	local data = c:GetData()
	if m == 0 then -- left click
		if data.eType == eTileType.bomb then
			self:lose_game()
		else
			local adjacent = self:get_adjacent_bombs(data.x,data.y)
			c:Enable(false)
			data.bFlagged = false
			if adjacent == 0 then
				for xv = data.x-1, data.x+1 do --for every adjacent tile
					for yv = data.y-1, data.y+1 do
						if self.tTiles[xv] and self.tTiles[xv][yv] --if it exists
							and self.tTiles[xv][yv]:IsEnabled() --and hasn't been clicked
								and not self.tTiles[xv][yv]:GetData().bFlagged then -- and not flagged
							self:event_click_tile(h,self.tTiles[xv][yv],0, true) --click it
						end
					end
				end
			else
				c:FindChild('tile_icon'):SetSprite(tSprites['num'..adjacent][1])
				c:FindChild('tile_icon'):SetBGColor(ApolloColor.new(tSprites['num'..adjacent][2]))
			end
			-- Check if they won
			if self:has_won() then
				self:win_game()
			end
		end
	elseif m == 1 then --right click
		data.bFlagged = not data.bFlagged
		if data.bFlagged then
			self.tScore.flags = self.tScore.flags + 1
			c:FindChild('tile_icon'):SetSprite(tSprites.flag[1])
			c:FindChild('tile_icon'):SetBGColor(tSprites.flag[2])
		else
			self.tScore.flags = self.tScore.flags - 1
			c:FindChild('tile_icon'):SetSprite('')
			c:FindChild('tile_icon'):SetBGColor(ApolloColor.new('white'))
		end
	end
	self:update_score()
end

function wildsweeper:has_won()
	for xv = 1, #self.tTiles do
		for yv = 1,#self.tTiles[xv] do
			local data = self.tTiles[xv][yv]:GetData()
			if data.eType == eTileType.empty and self.tTiles[xv][yv]:IsEnabled() then
				return false
			end
		end
	end
	return true
end

function wildsweeper:win_game()
	self.bWon=true
	self.wndMain:FindChild('win_frame'):Show(true,false)
	self.oTimer:Stop()
	for _,v in pairs(self.tTiles) do
		for _,tile in pairs(v) do
			tile:Enable(false)
			if tile:GetData().eType == eTileType.bomb then
				if tile:GetData().bFlagged then
					tile:FindChild('tile_icon'):SetSprite(tSprites.check[1])
					tile:FindChild('tile_icon'):SetBGColor(tSprites.check[2])
				else
					tile:FindChild('tile_icon'):SetSprite(tSprites.bomb[1])
					tile:FindChild('tile_icon'):SetBGColor(tSprites.bomb[2])
				end
			elseif tile:GetData().bFlagged then
				tile:FindChild('tile_icon'):SetSprite(tSprites.cross[1])
				tile:FindChild('tile_icon'):SetBGColor(tSprites.cross[2])
			end
		end
	end
end

function wildsweeper:lose_game()
	self.bWon = false
	self.wndMain:FindChild('lose_frame'):Show(true,false)
	self.oTimer:Stop()
	for _,v in pairs(self.tTiles) do
		for _,tile in pairs(v) do
			tile:Enable(false)
			if tile:GetData().eType == eTileType.bomb then
				if tile:GetData().bFlagged then
					tile:FindChild('tile_icon'):SetSprite(tSprites.check[1])
					tile:FindChild('tile_icon'):SetBGColor(tSprites.check[2])
				else
					tile:FindChild('tile_icon'):SetSprite(tSprites.bomb[1])
					tile:FindChild('tile_icon'):SetBGColor(tSprites.bomb[2])
				end
			elseif tile:GetData().bFlagged then
				tile:FindChild('tile_icon'):SetSprite(tSprites.cross[1])
				tile:FindChild('tile_icon'):SetBGColor(tSprites.cross[2])
			end
		end
	end
end

function wildsweeper:event_share_score(h,c,m)
	if self.bWon then
		local msg = ' I found all %d bombs in %s mode WildSweeper in %d seconds; how awesome am I!'
		ChatSystemLib.Command(c:GetText()..string.format(msg,tonumber(self.wndMain:FindChild('bomb_count'):GetText()),self.diff.text,self.tScore.time))
	else
	local msg = ' Oops! I just lost a game of %s mode WildSweeper in %d seconds. Didn\'t quite mean for that to happen'
		ChatSystemLib.Command(c:GetText()..string.format(msg,self.diff.text,self.tScore.time))
	end
end

function wildsweeper:close_game()
	self.wndMain:Show(false)
	self:new_board()
end

---------------------------------------------------------------------------------------------------
-- game_tile Functions
---------------------------------------------------------------------------------------------------

function wildsweeper:event_flash_stop( wndHandler, wndControl, strAnimDataId )
	wndControl:Show(false,false)
end

local wildsweeperInst = wildsweeper:new()
wildsweeperInst:Init()
