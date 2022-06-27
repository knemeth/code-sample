--!strict

--[[Services]]--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

--[[Requirements]]--
local require = require(ReplicatedStorage:WaitForChild("Nevermore"))
local GetRemoteEvent = require("GetRemoteEvent")
local loadAsset = require("AssetLoader")
local GuiManager = require("GuiManager")
local delay = require("delay")

--[[Events]]--
local packEvent = GetRemoteEvent("PackEvent")

--[[Constants]]--
local GRID_W = 6
local GRID_H = 4
local TIMER_MAX = 45
local FILL_BONUS = 50
local MULLIGAN_COST = 5
local TIME_INCREASE = 10
local itemShapes = {
	"111",			-- Single
	"2111",			-- HLine2
	"31111",		-- HLine3
	"1211",			-- VLine2
	"13111",		-- VLine3
	"221110",		-- DRElbow
	"221101",		-- DLElbow
	"220111",		-- ULElbow
	"221011",		-- URElbow
	"23101011",		-- L
	"23010111",		-- ReverseL
	"23110101",		-- InverseL
	"23111010",		-- RevInvL
	"32111100",		-- HL
	"32100111",		-- ReverseHL
	"32111001",		-- InverseHL
	"32001111",		-- RevInvHL
	"221111",		-- Square2
	"23101110",		-- HT
	"23011101",		-- ReverseHT
	"32111010",		-- VT
	"32010111",		-- ReverseVT
	"33010111010"	-- Cross
}

--[[Module]]--
local packingGui = GuiManager.new("PackingGui")

local closeButton
local okButton
local wardrobeFrame
local wardrobeSlots: {[number]: any} = {}
local mulliganButton
local itemOnCursor: any
local suitcaseGrid
local suitcaseButtons: {[number]: any} = {}
local nextLayerButton
local timerDisplay
local scoreboard
local scoreDisplay
local pointDisplay
local buttonConnects: {[any]: any} = {}
local mouse2Connection: any = nil
local timer = -1
local timerConnection: any = nil
local score = 0
local firstMulligan = true

local random = Random.new()

--[[Utility]]--
local function GetElement(name: string)
	return packingGui._screen[name].Value --element references currently represented as ObjectValues parented under menu
end
local function ButtonConnect(func, arg)
	return function()
		func(arg)
	end
end
local function CheckForMouse2(input) 
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		RemoveItemOnCursor()
	end
end
local function CheckForMouseRelease(input) 
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mousePos = UserInputService:GetMouseLocation()
		local inset, brInset = GuiService:GetGuiInset()
		local guiObjects = packingGui._screen.Parent:GetGuiObjectsAtPosition(mousePos.X-inset.X, mousePos.Y-inset.Y)
		for _,object in ipairs(guiObjects) do 
			if object:IsA("TextButton") and object:FindFirstAncestor("Suitcase") then
				local success = PutItemInSuitcase(object)
				if success then
					return
				end
			end
		end
		RemoveItemOnCursor()
	end
end
-- Keep image on mouse cursor
local function ImageToMouse()
	if itemOnCursor.Visible then
		local mousePos = UserInputService:GetMouseLocation()
		itemOnCursor.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y - (itemOnCursor.Size.Y.Offset/2))
	end
end
-- Determine the amount of points a shape is worth
local function GetPointsFromShape(shape: string)
	-- shape strings defined in the Constants section
	-- points = each square in a shape squared
	local points = 0
	for i=3, string.len(shape) do
		if string.sub(shape, i, i) == "1" then
			points += 1
		end
	end
	points *= points
	return points
end
-- Create a text display in the center of the screen to display points
local function DisplayPoints(amount: number, message: string)
	message = message or ""		-- default arg
	
	local pointsText = pointDisplay:Clone()
	pointsText.Text = "+" .. tostring(amount) .. message
	pointsText.Parent = wardrobeFrame.Parent
	pointsText.Visible = true
	
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = {
		Position = UDim2.fromScale(0.5,0),
		TextTransparency = 1,
		TextStrokeTransparency = 1
	}
	local tween = TweenService:Create(pointsText, tweenInfo, goal)
	tween:Play()
	tween.Completed:Connect(function()
		pointsText:Destroy()
	end)
end

--[[Packing Item Functions]]--
function CreatePackingShape(parent)
	local shape: string = itemShapes[random:NextInteger(1, #itemShapes)]
	-- digits 1-2 are width/height, the rest are 1/0 for occupancy
	local width = tonumber(shape:sub(1, 1))
	local height = tonumber(shape:sub(2, 2))
	assert(width ~= nil and height ~= nil, "Invalid shape constant: NaN")
	local color = BrickColor.random().Color

	local function CreateUnit(x: number, y: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x+0.5, y+0.5)
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = color

		return f
	end

	local offset: number = 0 	-- aligns shape horizontally with the first unit in the top row
	for i=3, width + 3 do
		if shape:sub(i,i) == "0" then
			offset -= 1
		else
			break
		end
	end

	local frame = CreateUnit(0, 0)
	frame.Name = "PackingItem"
	local size = 1 / math.max(width, height)
	frame.Size = UDim2.fromScale(size, size)
	frame:SetAttribute("Shape", shape)
	frame:SetAttribute("ShapeSize", size)		-- for resizing when returning to wardrobe
	frame:SetAttribute("ShapeOffset", offset)
	frame.BackgroundTransparency = 1

	local cell
	local i,j = 0,0
	for bit=3, string.len(shape) do
		if shape:sub(bit, bit) == "1" then
			cell = CreateUnit(i + offset, j)
			cell.Parent = frame
		end

		if i == width-1 then
			-- next row
			i = 0
			j += 1
		else 
			i += 1
		end
	end

	-- Create point value indicator
	local pointDisplay = Instance.new("TextLabel")
	pointDisplay.Parent = frame
	pointDisplay.Size = UDim2.fromScale(1,1)
	pointDisplay.AnchorPoint = Vector2.new(0.5, 0.5)
	pointDisplay.Position = UDim2.fromScale(0.5, 0.5)
	pointDisplay.Text = tostring(GetPointsFromShape(shape))
	pointDisplay.TextSize = 50
	pointDisplay.TextScaled = true
	pointDisplay.BackgroundTransparency = 1

	return frame
end

function SetItemOnCursor(button: any)
	if itemOnCursor:FindFirstChild("PackingItem") then
		return
	end

	if button:FindFirstAncestor("Suitcase") then
		EmptySuitcaseButton(button)		-- Suitcase Button
	else
		button.Visible = false			-- Wardrobe Button
	end

	local absSize = suitcaseButtons[1].AbsoluteSize
	itemOnCursor.Size = UDim2.fromOffset(absSize.X, absSize.Y)
	itemOnCursor.OriginalParent.Value = button
	local packingItem = button:FindFirstChild("PackingItem")
	packingItem.Parent = itemOnCursor
	packingItem.Size = UDim2.fromScale(1, 1)
	itemOnCursor.Visible = true
end

function RemoveItemOnCursor()
	if not itemOnCursor.Visible then
		return
	end
	local packingItem
	packingItem = itemOnCursor:FindFirstChild("PackingItem")
	if packingItem then
		local parent = itemOnCursor.OriginalParent.Value
		
		if parent:FindFirstAncestor("Wardrobe") then
			-- Wardrobe button
			local size = packingItem:GetAttribute("ShapeSize")
			packingItem.Size = UDim2.fromScale(size, size)
		else
			-- Suitcase button
			PutItemInSuitcase(parent)
		end
		
		packingItem.Parent = parent

		parent.Visible = true			-- Make button usable
	end
	itemOnCursor.Visible = false
	itemOnCursor.OriginalParent.Value = nil
end

--[[Suitcase Functions]]--
function PutItemInSuitcase(button)
	if itemOnCursor.Visible == false then
		return false
	end

	local packingItem = itemOnCursor:FindFirstChild("PackingItem")
	if packingItem then
		local points = GetPointsFromShape(packingItem:GetAttribute("Shape"))
		local slotsToFill = GetOccupiedSlots(button, packingItem)
		if #slotsToFill > 0 and CheckSlotFit(slotsToFill) then
			packingItem.Parent = button
			
			local slotButton
			for _,slot in ipairs(slotsToFill) do
				slot.Points.Value = points / #slotsToFill
				slotButton = slot:FindFirstChildWhichIsA("TextButton")
				if buttonConnects[slotButton] then
					buttonConnects[slotButton]:Disconnect()
				end
				buttonConnects[slotButton] = slotButton.MouseButton1Down:Connect(ButtonConnect(SetItemOnCursor, button))
			end
			
			ResetWardrobeButtons()
			-- Tween score label
			local scoreLabel = packingItem:FindFirstChildWhichIsA("TextLabel")
			local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.InOut, 0, true, 0)
			local tween = TweenService:Create(scoreLabel, tweenInfo, {Size = UDim2.fromScale(2, 2)})
			tween:Play()
			return true
		end
	end
	
	return false
end

function EmptySuitcaseButton(button)
	local packingItem = button:FindFirstChild("PackingItem")
	if packingItem then 
		local slotsToFill = GetOccupiedSlots(button, packingItem)
		local slotButton
		for _,slot in ipairs(slotsToFill) do
			slotButton = slot:FindFirstChildWhichIsA("TextButton")
			slotButton.Parent.Points.Value = 0

			if buttonConnects[slotButton] then
				buttonConnects[slotButton]:Disconnect()
			end
			buttonConnects[slotButton] = slotButton.MouseButton1Down:Connect(ButtonConnect(PutItemInSuitcase, slotButton))
		end
	else
		if buttonConnects[button] then
			buttonConnects[button]:Disconnect()
		end
		button.Parent.Points.Value = 0
		buttonConnects[button] = button.MouseButton1Down:Connect(ButtonConnect(PutItemInSuitcase, button))
	end
	
	return packingItem
end

function GetOccupiedSlots(button, item): {[number]: any}
	local slot = button.Parent
	local shape: string = item:GetAttribute("Shape")
	local width = tonumber(shape:sub(1, 1))
	local height = tonumber(shape:sub(2, 2))
	local slotNum = tonumber(slot.Name:sub(5, 6))
	local offset = tonumber(item:GetAttribute("ShapeOffset"))
	assert(typeof(width) == "number" and typeof(height) == "number" and typeof(slotNum) == "number" and typeof(offset) == "number")

	local cells = slot.Parent:GetChildren()

	if math.fmod(slotNum-1, GRID_W) + width + offset > GRID_W or math.fmod(slotNum-1, GRID_W) < math.abs(offset) then
		-- Shape goes off one edge
		return {}
	end

	local occupiedCells = {}

	local cell
	local i,j = 0,0
	for bit=3, string.len(shape) do
		if shape:sub(bit, bit) == "1" then
			cell = cells[1 + slotNum + i + (j*GRID_W) + offset]
			if cell then
				occupiedCells[#occupiedCells+1] = cell
			else
				return {}
			end
		end

		if i == width-1 then
			-- next row
			i = 0
			j += 1
		else 
			i += 1
		end
	end

	return occupiedCells
end

function CheckSlotFit(cells: any)
	for _,cell in ipairs(cells) do
		if cell.Points.Value > 0 or buttonConnects[cell:FindFirstChildWhichIsA("TextButton")] == nil then
			return false
		end
	end

	return true
end

function ClearSuitcase()
	local item
	for _,button in ipairs(suitcaseButtons) do
		item = EmptySuitcaseButton(button)
		if item then
			item:Destroy()
		end
		button.BackgroundTransparency = 1
	end
end

function NextSuitcaseLayer()
	local points = TallyScore()
	if points == 0 then
		-- suitcase empty
		return
	end
	
	nextLayerButton._object.Visible = false
	TimerTick(-TIME_INCREASE)
	
	local item
	for _,button in ipairs(suitcaseButtons) do
		item = button:FindFirstChild("PackingItem")
		if item then
			item:Destroy()
		end
		
		if buttonConnects[button] then
			buttonConnects[button]:Disconnect()
			buttonConnects[button] = nil
		end
		
		if button.Parent.Points.Value == 0 then
			-- Permanently disable button
			button.BackgroundColor = BrickColor.Black()
			button.BackgroundTransparency = 0
		else 
			button.Parent.Points.Value = 0
			buttonConnects[button] = button.MouseButton1Down:Connect(ButtonConnect(PutItemInSuitcase, button))
		end
	end
	
	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Elastic, Enum.EasingDirection.InOut, 2, true)
	local tween = TweenService:Create(suitcaseGrid.Parent, tweenInfo, {Rotation = 5})
	tween:Play()
	tween.Completed:Wait()
	nextLayerButton._object.Visible = true
end

--[[Wardrobe Functions]]--
function ResetWardrobeButtons()
	local packingItem
	-- Reset all buttons
	for _,child in ipairs(wardrobeSlots) do
		child.Visible = true
		packingItem = child:FindFirstChild("PackingItem")
		if packingItem == nil then
			packingItem = CreatePackingShape(child)
			packingItem.Parent = child
		end
		if buttonConnects[child] then buttonConnects[child]:Disconnect() end
		buttonConnects[child] = child.MouseButton1Down:Connect(ButtonConnect(SetItemOnCursor, child))
	end
end

function MulliganWardrobe()
	local packingItem
	-- Reset all buttons
	for _,child in ipairs(wardrobeSlots) do
		child.Visible = true
		packingItem = child:FindFirstChild("PackingItem")
		if packingItem then
			packingItem:Destroy()
		end
		packingItem = CreatePackingShape(child)
		packingItem.Parent = child
	end

	if firstMulligan then
		firstMulligan = false
		mulliganButton._object:FindFirstChild("Free").Text = "-5s"
	else
		TimerTick(MULLIGAN_COST)
	end
end

--[[Flow Functions]]--
function Init()
	closeButton = packingGui:NewGuiButton(GetElement("CloseButton"), OpenScoreboard)
	mulliganButton = packingGui:NewGuiButton(GetElement("MulliganButton"), MulliganWardrobe)
	okButton = packingGui:NewGuiButton(GetElement("OKButton"), ClosePacking)
	nextLayerButton = packingGui:NewGuiButton(GetElement("NextLayerButton"), NextSuitcaseLayer)
	
	wardrobeFrame = GetElement("Wardrobe")
	local packingItem, button
	local i = 1
	for _,child in ipairs(wardrobeFrame:GetChildren()) do
		if child:IsA("Frame") then
			wardrobeSlots[i] = child:FindFirstChildWhichIsA("ImageButton")
			i += 1
		end
	end
	-- Populate suitcasegrid with clones
	suitcaseGrid = GetElement("SuitcaseGrid")
	local suitcaseSlot = suitcaseGrid:FindFirstChildWhichIsA("Frame")
	table.insert(suitcaseButtons, suitcaseSlot:FindFirstChildWhichIsA("TextButton"))
	for i=2, GRID_W * GRID_H do
		suitcaseSlot = suitcaseSlot:Clone()
		suitcaseSlot.Parent = suitcaseGrid
		-- Order names to keep them in the correct order in the object hierarchy
		if i < 10 then
			suitcaseSlot.Name = "Slot0" .. tostring(i)
		else 
			suitcaseSlot.Name = "Slot" .. tostring(i)
		end
		table.insert(suitcaseButtons, suitcaseSlot:FindFirstChildWhichIsA("TextButton"))
	end
	
	itemOnCursor = GetElement("ItemOnCursor")
	timerDisplay = GetElement("Timer")
	scoreboard = GetElement("Scoreboard")
	scoreDisplay = GetElement("Score")
	pointDisplay = GetElement("PointDisplay")
end

function StartPacking()
	packingGui:Open()
	RunService:BindToRenderStep("MoveMouseImage", 1, ImageToMouse)
	
	timer = TIMER_MAX
	timerDisplay.Text = timer
	timerConnection = delay(1, TimerTick)
	
	scoreboard.Visible = false
	score = 0
	scoreDisplay.Text = "0"
	
	closeButton._object.Visible = true
	
	firstMulligan = true
	mulliganButton._object:FindFirstChild("Free").Text = "Free!"
	
	-- Empty wardrobe
	local item
	for _,child in ipairs(wardrobeSlots) do
		item = child:FindFirstChild("PackingItem")
		if item then
			item:Destroy()
		end
	end
	ResetWardrobeButtons()
	ClearSuitcase()
	
	if not mouse2Connection then
		mouse2Connection = UserInputService.InputEnded:Connect(CheckForMouseRelease)
	end
end

function ClosePacking()
	packingGui:Close()
	packEvent:FireServer()
	
	local success, message = pcall(function() RunService:UnbindFromRenderStep("MoveMouseImage") end)
	if not success then
		warn("An error occurred unbinding from RenderStep: " .. message)
	end
	
	timer = -1
	if timerConnection then
		timerConnection:Cancel()
		timerConnection = nil
	end
	
	if mouse2Connection then
		mouse2Connection:Disconnect()
		mouse2Connection = nil
	end
end

function TimerTick(value)
	value = value or 1
	timer -= value
	if timer <= 0 then
		-- Timer over
		timer = 0
		OpenScoreboard()
		return
	end
	timerDisplay.Text = timer
	-- Mulligan button only active if there's enough time to use it
	if timer <= MULLIGAN_COST then
		mulliganButton._object.Visible = false
	else 
		mulliganButton._object.Visible = true
	end
	
	if timerConnection and timerConnection._done == false then
		timerConnection:Cancel()
	end
	timerConnection = delay(1, TimerTick)
end

function TallyScore()
	local addedPoints = 0
	local slotsFilled = 0
	for _,child in ipairs(suitcaseGrid:GetChildren()) do
		if child:IsA("Frame") then
			if child.Points.Value > 0 then
				addedPoints += child.Points.Value
				slotsFilled += 1
			end
		end
	end
	
	local ratioFilled = slotsFilled / (GRID_H*GRID_W)
	local fillBonus = math.floor(FILL_BONUS * ratioFilled)
	if ratioFilled == 1 then
		fillBonus *= 2		-- Extra bonus for 100% fill
	end
	addedPoints += fillBonus
	
	score += addedPoints
	
	if addedPoints > 0 then
		DisplayPoints(addedPoints-fillBonus, "")
	end
	if fillBonus > 0 then
		local delayedDisplay = function()
			DisplayPoints(fillBonus, " Fill Bonus!")
		end
		delay(0.5, delayedDisplay)
	end
	
	return addedPoints
end

function OpenScoreboard()
	scoreboard.Visible = true
	closeButton._object.Visible = false
	
	for _,connect in pairs(buttonConnects) do
		connect:Disconnect()
	end
	
	if timerConnection then
		timerConnection:Cancel()
	end
	
	TallyScore()
	scoreDisplay.Text = tostring(score)
end

Init()

packEvent.OnClientEvent:Connect(StartPacking)

return nil
