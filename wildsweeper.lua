require "Window"

local wildsweeper = {} 

local eTileType = {}
eTileType.empty = 1
eTileType.bomb = 2

local tSprites = {}

tSprites.bomb = 'IconSprites:Icon_Windows_UI_CRB_Marker_Bomb'
tSprites.flag = 'CRB_InterfaceMenuList:spr_InterfaceMenuList_BlueFlagStretch'
for i=1,9 do
	tSprites['num'..i] = 'CRB_NumberFloaters:sprFloater_Normal' .. i
end

function wildsweeper:new(o)
	local o = o or {}
	setmetatable(o, self)
	self.__index = self 	
	self.tTiles = {}
	self.tTileSize={w=16,h=16}
	self.cBoard = nil
	self.tBoardSize={w=25,h=25}
	return o
end

function wildsweeper:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
	Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

function wildsweeper:OnLoad()
    -- load our form file
    self.xmlDoc = XmlDoc.CreateFromFile("forms.xml")
    self.xmlDoc:RegisterCallback("OnDocLoaded", self)
  end

function wildsweeper:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "new_dialog", nil, self)
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "container", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		self.wndMain:Show(true, true)

		self.cBoard = self.wndMain:FindChild("board")
		for x=1,self.tBoardSize.w do
			for y=1,self.tBoardSize.h do
				local button = Apollo.LoadForm(self.xmlDoc,"game_tile",self.cBoard,self)
				button:Move(0,0,self.tTileSize.w,self.tTileSize.h)
				if not self.tTiles[x] then self.tTiles[x] = {} end
				self.tTiles[x][y] = button
				button:SetData({x=x,y=y,eType = (math.random(5)==1 and 2 or 1), bFlagged = false})
				button:SetText((button:GetData().eType == eTileType.bomb) and '' or '')
			end
		end
		self.cBoard:ArrangeChildrenTiles()
	end
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

function wildsweeper:event_click_tile(h,c,m)
	local data = c:GetData()
	if m == 0 then -- left click
		if data.eType == eTileType.bomb then
		else
			local adjacent = self:get_adjacent_bombs(data.x,data.y)

			c:FindChild('tile_icon'):SetSprite(tSprites['num'..adjacent])
			c:Enable(false)
			data.bFlagged = false
			if adjacent == 0 then
				for xv = data.x-1, data.x+1 do --for every adjacent tile
					for yv = data.y-1, data.y+1 do
						if self.tTiles[xv] and self.tTiles[xv][yv] --if it exists
							and self.tTiles[xv][yv]:IsEnabled() then --and hasn't been clicked
							self:event_click_tile(h,self.tTiles[xv][yv],0) --click it
						end
					end
				end
			end
		end
	elseif m == 1 then --right click
		data.bFlagged = not data.bFlagged
		if data.bFlagged then
			c:FindChild('tile_icon'):SetSprite(tSprites.flag)
		else
			c:FindChild('tile_icon'):SetSprite('')
		end
	end
end

local wildsweeperInst = wildsweeper:new()
wildsweeperInst:Init()
