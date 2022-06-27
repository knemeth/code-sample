--!strict

-- Shake the model while proxprompt is being held, then spawn collectibles nearby

--[[Services]]--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

--[[Requirements]]--
local require = require(ReplicatedStorage:WaitForChild("Nevermore"))
local ClassUtils = require("ClassUtils")
local Component = require("Component")
local loadAsset = require("AssetLoader")
local delay = require("delay")

--[[Constants]]--
--local DEFAULT_OBJECT = loadAsset("Trash")
local MAX_SPAWN_COUNT = 50
local SHAKE_ANGLE = 10

--[[Module]]--
local random = Random.new()

--[[Class]]--
local CollectibleSource = ClassUtils.NewClass(Component)

function CollectibleSource:_Constructor(model)
	if not model:IsA("Model") then
		warn("CollectibleSource must be a model!")
		return
	end

	self._object = model
	self._partOrientation = model.PrimaryPart.Orientation
	self._tween = nil
	self._shaking = false
	-- Asset that will spawn upon activation
	self._spawnObject = loadAsset(model.AssetName.Value)
	self._spawnCount = model.SpawnCount.Value
	-- Connect proxprompt events
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt == nil then
		warn("CollectibleSource has no proximity prompt; creating one...")
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = model
		prompt.ActionText = "Search"
		prompt.HoldDuration = 2
		prompt.UIOffset = UDim.new(0, 2)
	end
	prompt.PromptButtonHoldBegan:Connect(function()
		self:_ShakeModel()
	end)
	prompt.PromptButtonHoldEnded:Connect(function()
		self:_StopShaking()
	end)
	prompt.Triggered:Connect(function()
		self:_SpawnCollectibles()
	end)
end

function CollectibleSource:_ShakeModel(player)
	local part = self._object.PrimaryPart
	local tweenInfo = TweenInfo.new(
		0.1,
		Enum.EasingStyle.Elastic,
		Enum.EasingDirection.InOut
	)
	local goal = {}
	self._shaking = true
	
	local function loopTween(angle)
		if not self._shaking then
			return
		end
		
		goal.Orientation = angle

		self._tween = TweenService:Create(part, tweenInfo, goal)
		self._tween:Play()
		self._tween.Completed:Wait()
		
		loopTween(Vector3.new(random:NextInteger(-SHAKE_ANGLE, SHAKE_ANGLE), 0, random:NextInteger(-SHAKE_ANGLE, SHAKE_ANGLE)))
	end
	
	loopTween(Vector3.new(random:NextInteger(-SHAKE_ANGLE, SHAKE_ANGLE), 0, random:NextInteger(-SHAKE_ANGLE, SHAKE_ANGLE)))
end

function CollectibleSource:_StopShaking(player)
	self._shaking = false
	-- Reset Orientation
	if self._tween then
		self._tween:Cancel()
		self._tween = nil
	end
	self._object.PrimaryPart.Orientation = self._partOrientation
end

function CollectibleSource:_SpawnCollectibles(player)
	local prompt = self._object:FindFirstChildWhichIsA("ProximityPrompt")
	prompt:Destroy()
	
	local part = self._object.PrimaryPart
	local collider = self._object:FindFirstChild("Collider")
	
	local function RemoveForce(vForce, attach)
		return function()
			vForce:Destroy()
			attach:Destroy()
		end
	end
	
	local spawnPosition
	if collider then
		spawnPosition = collider.Position + Vector3.new(0, collider.Size.Y / 2, 0)
	else
		spawnPosition = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
	end
	
	local collectible, attachment, vectorForce
	for i=1, self._spawnCount, 1 do
		collectible = self._spawnObject:Clone()
		collectible.Parent = self._object
		collectible.Position = spawnPosition + Vector3.new(random:NextInteger(-4,4), random:NextInteger(0,2), random:NextInteger(-4,4))
		collectible.Anchored = false
		-- Send in a random direction
		attachment = Instance.new("Attachment")
		attachment.Parent = collectible
		attachment.Position = collectible.Position
		
		vectorForce = Instance.new("VectorForce")
		vectorForce.Parent = collectible
		vectorForce.Attachment0 = attachment
		vectorForce.ApplyAtCenterOfMass = true
		vectorForce.Force = Vector3.new(random:NextInteger(-500,500), 3000, random:NextInteger(-500,500))
		
		delay(0.1, RemoveForce(vectorForce, attachment))
	end
end

CollectibleSource:_CacheComponents("CollectibleSource")

return CollectibleSource
