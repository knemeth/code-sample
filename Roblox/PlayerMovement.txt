--!strict

-- Controls running and states bool values for running/climbing states

--[[Services]]--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TweenSerivce = game:GetService("TweenService")

--[[Requirements]]--
local require = require(ReplicatedStorage:WaitForChild("Nevermore"))
local GetRemoteEvent = require("GetRemoteEvent")

--[[Events]]--
local beachMinigameEvent = GetRemoteEvent("BeachMinigameEvent")
local dropTrashEvent = GetRemoteEvent("DropTrashEvent")

--[[Constants]]--
local RUN_SPEED = 32
local RUN_BURST_SPEED = 50
local RUN_COST = 10
local CLIMB_COST = 10
local GROUND_CHECK_ERROR = 4
local BURST_RAMP_DOWN = 0.3
local RUN_RAMP_DOWN = 0.4
local RUNNING_FOV = 75
local OVERFLOW_POINT = 0.8 		-- for trash
local DROP_CHANCE = 33

--[[Module]]--
local PlayerMovement = {}

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local defaultSpeed = humanoid.WalkSpeed
local targetSpeed = defaultSpeed
local camera = workspace.CurrentCamera
local defaultFOV = camera.FieldOfView
local minigameActive = false
local currentTrash: any
local capacity: any
local rolledDrop = false -- whether the drop chance was just rolled

local staminaValue = humanoid:FindFirstChild("Stamina")
if staminaValue == nil then
	staminaValue = Instance.new("NumberValue")
	staminaValue.Name = "Stamina"
	staminaValue.Parent = humanoid
	staminaValue:SetAttribute("Enabled", false)		-- start disabled
end

local moveState = humanoid:FindFirstChild("MoveState")
if moveState == nil then
	moveState = Instance.new("StringValue")
	moveState.Name = "MoveState"
	moveState.Parent = humanoid
end

local stateChange
local runChange
local exhaustConnect
local runAllowed = true
local speedTween = nil
local runDisable = false

-- Checks for certain parameters that might prevent sprinting
local function CanRun()
	if runDisable then
		return false
	end
	
	local state = humanoid:GetState()
	
	if humanoid.FloorMaterial ~= Enum.Material.Air and 
		state ~= Enum.HumanoidStateType.Freefall and 
		state ~= Enum.HumanoidStateType.Climbing and 
		state ~= Enum.HumanoidStateType.Swimming
	then
		return true
	end
	
	return false
end

local function EvaluateStamina(value: number)
	if value <= 0 then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		ChangeWalkSpeed(defaultSpeed)
		runAllowed = false
	else 
		-- Reset allowances once stamina returns to a high enough value
		if value >= RUN_COST then
			runAllowed = true
		end
		if value >= CLIMB_COST then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
		end
	end
end

local function TweenFOV(targetValue)
	local tweenInfo = TweenInfo.new(BURST_RAMP_DOWN, Enum.EasingStyle.Quart)
	local tween = TweenSerivce:Create(camera, tweenInfo, {FieldOfView = targetValue})
	tween:Play()
end 

local function TweenWalkSpeed(ramp, speed)
	if speedTween and speedTween.PlaybackState == Enum.PlaybackState.Playing then
		speedTween:Cancel()
	end
	local tweenInfo = TweenInfo.new(ramp, Enum.EasingStyle.Linear)
	speedTween = TweenSerivce:Create(humanoid, tweenInfo, {WalkSpeed = speed})
	speedTween:Play()
end

-- Called by pressing shift or when running out of stamina
function ChangeWalkSpeed(speed: number)
	if runDisable then
		return
	end
	if staminaValue:GetAttribute("Enabled") == false then
		runAllowed = true
	end
	-- Stamina enabled, only allow running if player has enough stamina
	if speed > defaultSpeed and runAllowed and CanRun() and humanoid.WalkSpeed <= RUN_SPEED then
		-- Has stamina
		targetSpeed = speed
		humanoid.WalkSpeed = RUN_BURST_SPEED
		
		if speedTween and speedTween.PlaybackState == Enum.PlaybackState.Playing then
			speedTween:Cancel()
		end
	else 
		rolledDrop = false
		targetSpeed = defaultSpeed
		TweenWalkSpeed(RUN_RAMP_DOWN, targetSpeed)
	end
end
-- Change speed when holding shift
function SprintHandler(actionName, userInputState, inputObject)
	--this recieves parameters from contextactionservice that we could use.
	if userInputState == Enum.UserInputState.Begin then
		ChangeWalkSpeed(RUN_SPEED)
	elseif userInputState == Enum.UserInputState.End then
		ChangeWalkSpeed(defaultSpeed)
	end
end

function ChangeState(old, new)
	if humanoid.WalkSpeed == RUN_BURST_SPEED and humanoid.MoveDirection ~= Vector3.zero then
		-- Start easing down from run burst, player just started moving while sprinting
		if minigameActive and rolledDrop == false then
			-- Potentially drop trash
			rolledDrop = true
			local rand = math.random(100)
			if currentTrash.Value / capacity.Value > OVERFLOW_POINT and rand < DROP_CHANCE then
				dropTrashEvent:FireServer(player)
			end
		end
		TweenWalkSpeed(BURST_RAMP_DOWN, targetSpeed)
		TweenFOV(RUNNING_FOV)
	elseif humanoid.WalkSpeed < RUN_SPEED and camera.FieldOfView == RUNNING_FOV then
		TweenFOV(defaultFOV)
	end
	
	if (new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.Freefall) and humanoid.WalkSpeed >= RUN_SPEED and humanoid.MoveDirection ~= Vector3.zero then
		moveState.Value = "Running"
	elseif new == Enum.HumanoidStateType.Climbing then
		moveState.Value = "Climbing"
		-- Disallow sprint speed
		ChangeWalkSpeed(defaultSpeed)
	elseif new == Enum.HumanoidStateType.Swimming then
		moveState.Value = "Resting"
		ChangeWalkSpeed(defaultSpeed)
	elseif new == Enum.HumanoidStateType.Landed then
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and
			runAllowed and 
			humanoid.MoveDirection ~= Vector3.zero 
		then
			moveState.Value = "Running"
			ChangeWalkSpeed(RUN_SPEED)
		end
	else
		moveState.Value = "Resting"
	end
end

function EnableStamina(onOff: boolean)
	if onOff then
		-- Disable certain actions if stamina reaches 0
		exhaustConnect = staminaValue.Changed:Connect(EvaluateStamina)
	else
		exhaustConnect:Disconnect()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
	end
end

--[[Public Functions]]--

function PlayerMovement:Enable()
	runDisable = false
	
	-- Connect to state changes
	stateChange = humanoid.StateChanged:Connect(ChangeState)
	-- Running is separate from StateChanged so we have to connect seperately
	runChange = humanoid.Running:Connect(function(speed)
		ChangeState(humanoid:GetState(), Enum.HumanoidStateType.Running)
	end)
	ContextActionService:BindAction("Sprint",SprintHandler,true,Enum.KeyCode.LeftShift,Enum.KeyCode.ButtonL2)		-- bind lshift to sprint
end

function PlayerMovement:Disable()
	runDisable = true
	-- Disconnect
	if stateChange then
		stateChange:Disconnect()
	end
	if runChange then
		runChange:Disconnect()
	end
	
	if speedTween then
		speedTween:Cancel()
	end
	
	ContextActionService:UnbindAction("Sprint")
	
	ChangeWalkSpeed(defaultSpeed)
end

-- Enable stamina functions if stamina attribute changes
staminaValue.AttributeChanged:Connect(function(attribute)
	if attribute == "Enabled" then
		EnableStamina(staminaValue:GetAttribute("Enabled"))
	end
end)

beachMinigameEvent.OnClientEvent:Connect(function(onOff)
	if onOff then 
		minigameActive = true
		currentTrash = player:WaitForChild("TrashCount")
		capacity = player:WaitForChild("TrashCapacity")
		PlayerMovement:Enable()
	else 
		minigameActive = false
		PlayerMovement:Disable()
		currentTrash = nil
		capacity = nil
	end
end)

PlayerMovement:Enable()

return PlayerMovement
