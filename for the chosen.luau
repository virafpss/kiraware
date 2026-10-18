-- for the chosen: self-contained loadstring, with the full corrected script embedded.
-- Requires a client Luau environment that supplies loadstring and Roblox APIs.
-- Standard Roblox LocalScripts do not provide client-side loadstring.

local Compile = loadstring
if type(Compile) ~= "function" then
    error("This client environment does not provide loadstring. Use the LocalScript version in Roblox Studio.", 0)
end

local Run, CompileError = Compile([====[
--========================================================
-- for the chosen
-- CLIENT PAYLOAD / REVISION 21 / STANDALONE LOADSTRING
-- The enclosing loader embeds this entire payload. Run the complete file
-- in a client Luau environment that provides loadstring and Roblox APIs.
-- All panel logic, camera controls, overlays and movement run on the client.
-- Tool:Activate uses your existing weapon implementation; this panel does not
-- grant server permissions, apply server damage, kick players or save data.
-- M panic; Right Control open/close menu; F8 toggle streamer mode. Select players on Targets before using targeting.
-- Y issues one paired activation per press, without requiring a selected target.
-- DB and TAC must be real Tools using Tool.Activated, with simultaneous equip
-- supported by your weapon system. The panel cannot confirm server-side shots.
-- Repeat presses can queue ONE additional pair while both guns recover.
-- Trigger checks the current camera ray every frame, before GUI refresh work.
-- Automatic range trigger starts enabled: DB + TAC at 1 <= distance < 50;
-- manually equipped revolver at 50 <= distance <= 245 studs. The panel never
-- draws REV from the backpack. Distances are measured between character roots.
-- CameraLock aligns the target with the actual cursor, not the screen center.
-- When DB ammo reaches zero, close-range automation continues with TAC alone.
-- Reloading DB restores paired fire; TAC still respects its own cooldown.
-- If either shotgun is empty, a manually equipped REV can trigger at 0–245.
-- The adjustable trigger square starts enabled and follows the cursor.
-- A selected, visible target's body center must be inside it to trigger.
-- The cursor ray must hit that same selected player before any automatic shot.
-- The square controls activation; Q/J still control camera aim separately.
-- T toggles firing. Settings can disable the square or automatic DB + TAC.
-- Y still requests a manual pair; normal trigger behavior resumes afterward.
-- Both guns stay equipped until their activation has been released; the
-- previous equipment is restored afterward. Panic cancels the queued pair.
-- Panic stays stopped until you explicitly enable a control again.
-- Config export/import transfers JSON manually; it is not automatic saving.
--
-- NAME ESP: SELECTED TARGETS RED / CREWMATES GREEN / OTHERS HIDDEN
-- TEXTURED UI
-- COMPACT MINIMIZE
-- STREAMER MODE
--========================================================

local C = {}
local S = {}
local St = {}
local UI = {}
local F = {}
local T = {}

--========================================================
-- SERVICES
--========================================================

if not game:GetService("RunService"):IsClient() then
	error("for the chosen requires a Roblox client environment with a LocalPlayer")
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

S.Players = game:GetService("Players")
S.RunService = game:GetService("RunService")
S.UIS = game:GetService("UserInputService")
S.TweenService = game:GetService("TweenService")
S.SoundService = game:GetService("SoundService")
S.ReplicatedStorage = game:GetService("ReplicatedStorage")
S.HttpService = game:GetService("HttpService")
S.GuiService = game:GetService("GuiService")

S.Player = S.Players.LocalPlayer

while not S.Player do
	task.wait()
	S.Player = S.Players.LocalPlayer
end

S.Camera = workspace.CurrentCamera
S.Mouse = S.Player:GetMouse()
S.PlayerGui = S.Player:WaitForChild("PlayerGui", 15)
if not S.PlayerGui then
	error("for the chosen: PlayerGui did not load")
end

-- The previous revision of this client script must release its connections
-- and movement overrides before the new instance captures any defaults.
local PreviousRuntime = S.PlayerGui:FindFirstChild("for the chosenGuiRuntime")
if PreviousRuntime then
	if PreviousRuntime:IsA("BindableFunction") then
		pcall(function()
			PreviousRuntime:Invoke()
		end)
	end
	PreviousRuntime:Destroy()
end

--========================================================
-- CONFIG
--========================================================

C.CameraLockKey = Enum.KeyCode.Q
C.SequentialKey = Enum.KeyCode.T
C.UniversalKey = Enum.KeyCode.T
C.DualFireKey = Enum.KeyCode.Y

-- Exact tool names take precedence; common DB/TAC names are also recognized.
-- You can set these names through the dualFire section in exported JSON.
C.DualFireDBName = "[Double-Barrel SG]"
C.DualFireTacName = "[TacticalShotgun]"
C.RangeAuto = true
C.RangeRevName = "[Revolver]"
-- Shared boundary belongs to REV: there is no gap and no overlapping shot.
C.RangeMinimum = 1
C.RangeSwitch = 50
C.RangeMaximum = 245
C.TriggerFOVEnabled = true
C.TriggerFOVSize = 180 -- full square width/height in viewport pixels
C.ShowTriggerFOV = true
-- Readiness flags are respected in addition to these minimum delays.
C.DualFireCooldown = 0 -- optional added delay; the tools still own their cooldowns
C.DualFireEquipDelay = 0.05
C.DualFireEquipTimeout = 2
C.DualFireReadyStable = 0.02 -- overlaps equip/repeat waits rather than stacking
C.DualFirePulse = 0.08
C.DualFirePostShotHold = 0.08
C.DualFireReleaseTimeout = 2.5

C.MenuKey = Enum.KeyCode.RightControl
C.StreamerKey = Enum.KeyCode.F8
C.PanicKey = Enum.KeyCode.M

-- Local camera aim assistance. No companion script or custom remote is required.
C.AimAssistKey = Enum.KeyCode.J
C.AimAssistFOV = 100
C.ShowAimAssistFOV = true

-- When CameraLock first acquires a target, multiple selected players
-- are ranked by BOTH cursor proximity and world distance.
-- After acquisition, the lock stays on that player until they become invalid.
C.TargetCursorWeight = 0.70
C.TargetWorldDistanceWeight = 0.30

-- CameraLock follows only selected targets.

-- Local movement controls
C.SpeedKey = Enum.KeyCode.V
C.WalkSpeed = 32

C.HoldCameraLock = false
C.HoldSequential = false
C.HoldUniversal = false

-- Universal starts enabled, but its button/key and Panic can stop it.

-- Seconds internally
-- Shot cooldown is a minimum; actual activations are capped by frame rate
-- and by the equipped tool's own cooldown/Enabled state.
C.ShotCooldown = 0.001
C.SequentialTargetGrace = 0.120
C.UIRefresh = 0.100

-- Triggerbot safety: do not auto-activate knife/melee tools whose
-- Tool.Name contains "knife".
C.TriggerKnifeCheck = true

-- Sequential now uses a single configured weapon.
-- Legacy hotbar mapping is retained for importing older configurations.
C.UniversalSlot = 1

C.Distance = {
	Fallback = 250,
	Double = 50,
	Rev = 245,
	Tac = 50
}

--========================================================
-- THEME
--========================================================

T.BG = Color3.fromRGB(48, 48, 48)
T.BG2 = Color3.fromRGB(58, 58, 58)

T.Sidebar = Color3.fromRGB(38, 38, 38)
T.Topbar = Color3.fromRGB(31, 31, 31)

T.Panel = Color3.fromRGB(43, 43, 43)
T.Panel2 = Color3.fromRGB(55, 55, 55)

T.Card = Color3.fromRGB(45, 45, 45)
T.CardHover = Color3.fromRGB(62, 62, 62)

T.Red = Color3.fromRGB(230, 91, 157)
T.RedBright = Color3.fromRGB(244, 119, 177)
T.RedDark = Color3.fromRGB(91, 43, 65)
T.RedDeep = Color3.fromRGB(65, 35, 49)

T.Green = Color3.fromRGB(130, 190, 151)
T.Yellow = Color3.fromRGB(220, 184, 112)

T.Text = Color3.fromRGB(238, 238, 238)
T.Muted = Color3.fromRGB(174, 174, 174)

T.Border = Color3.fromRGB(59, 59, 59)
T.BorderBright = Color3.fromRGB(70, 70, 70)

--========================================================
-- STATE
--========================================================

St.CameraLock = false
St.Sequential = false
St.Universal = true

St.MenuOpen = true
St.StreamerMode = false

-- Local camera aim assist state.
St.AimAssist = false
St.AimAssistTarget = nil
St.LastAimScan = 0

-- Local movement state
St.Speed = false

St.SpeedHumanoid = nil
St.DefaultWalkSpeed = nil


-- Name ESP state. Its control is integrated into the existing Settings page.
St.NameESPEnabled = true
St.NameESPTags = {}
St.NameESPConnections = {}
St.NameESPPending = {}
St.NameESPPlayerAddedConnection = nil
St.NameESPPlayerRemovingConnection = nil
St.NameESPHeartbeatConnection = nil

St.CameraLockTarget = nil
St.SeqTarget = nil
St.UniTarget = nil

-- UserId -> true. Entries are deliberately kept when a player leaves,
-- so the same UserId is automatically selected again if they rejoin.
St.SelectedTargets = {}
St.TargetPlayerAddedConnection = nil
St.TargetPlayerRemovingConnection = nil

-- Saved cursor state so CameraLock can restore the normal mouse icon.

St.LastSeqTarget = nil
St.LastUniTarget = nil

St.LastSeqShot = 0
St.LastUniShot = 0

St.SeqLostSince = nil

St.LastUI = 0
St.Focused = true

St.Sequence = {1}
St.SequenceIndex = 1
-- Actual hotbar number -> Tool.Name
St.LearnedSlots = {}
St.LearnGeneration = {}

St.SequentialTool = nil
St.UniversalTool = nil

St.LocalKO = nil
St.LocalCrouch = nil

St.KOCache = setmetatable({}, {
	__mode = "k"
})

St.KeyCapture = nil
St.SlotCapture = nil
St.Ready = false
St.Cleaned = false
St.Panicked = false
St.Connections = {}
St.CharacterConnections = {}
St.CharacterGeneration = 0
St.LearnSerial = 0
St.ActiveTool = nil
St.PendingToolReleases = setmetatable({}, {__mode = "k"})
-- An older runtime may have been stopped while its equipped gun was disabled.
-- Drain that release on this runtime, including upgrades from older revisions.
if PreviousRuntime and S.Player.Character then
	for _, Tool in ipairs(S.Player.Character:GetChildren()) do
		if Tool:IsA("Tool") then St.PendingToolReleases[Tool] = true end
	end
end
St.ToolReleasedFrame = setmetatable({}, {__mode = "k"})
St.ToolLastShots = setmetatable({}, {__mode = "k"})
St.TriggerFrame = 0
St.TriggerRayParams = RaycastParams.new()
St.TriggerRayParams.FilterType = Enum.RaycastFilterType.Exclude
St.TriggerRayParams.IgnoreWater = true
St.DualFire = nil
St.TacFallback = nil
St.ManualRevTool = nil
St.TriggerFOVTarget = nil
St.RangeLastNotice = nil
St.RangeRetryAt = 0
St.HeldDualKey = nil
St.LastDualFire = -math.huge
St.StateCache = setmetatable({}, {__mode = "k"})
St.CrewCache = setmetatable({}, {__mode = "k"})
St.CrouchAnimationIds = {}
St.NextAnimationScan = 0
St.RenderBinding = "for the chosenCameraLock_" .. S.HttpService:GenerateGUID(false)

St.Logs = {}

--========================================================
-- NUMBER KEYS
--========================================================

C.NumberKeys = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9
}

C.KeyByName = {}

for _, Key in ipairs(
	Enum.KeyCode:GetEnumItems()
) do
	C.KeyByName[Key.Name] = Key
end

--========================================================
-- SOUNDS
--========================================================

S.OnSound = Instance.new("Sound")

S.OnSound.SoundId =
	"rbxassetid://139009780109934"

S.OnSound.Volume = 1
S.OnSound.Parent = S.SoundService

S.OffSound = Instance.new("Sound")

S.OffSound.SoundId =
	"rbxassetid://124081596667728"

S.OffSound.Volume = 1
S.OffSound.Parent = S.SoundService

--========================================================
-- LOGGING
--========================================================

function F.Log(Text)
	table.insert(
		St.Logs,
		1,
		Text
	)

	while #St.Logs > 6 do
		table.remove(St.Logs)
	end

	if UI.Log then
		UI.Log.Text =
			table.concat(
				St.Logs,
				"\n"
			)
	end
end

--========================================================
-- LIFETIME / INPUT / VALUE HELPERS
--========================================================

function F.Connect(Signal, Callback, Connections)
	local Connection = Signal:Connect(function(...)
		if not St.Cleaned then
			Callback(...)
		end
	end)
	table.insert(Connections or St.Connections, Connection)
	return Connection
end

function F.DisconnectAll(Connections)
	for _, Connection in pairs(Connections) do
		Connection:Disconnect()
	end
	table.clear(Connections)
end

function F.FiniteNumber(Value)
	if typeof(Value) ~= "number" and typeof(Value) ~= "string" then
		return nil
	end
	local Number = tonumber(Value)
	if Number and Number == Number and math.abs(Number) < math.huge then
		return Number
	end
	return nil
end

function F.StateEnabled(Value)
	if typeof(Value) == "boolean" then
		return Value
	end
	local Number = F.FiniteNumber(Value)
	if Number ~= nil then
		return Number > 0
	end
	if typeof(Value) == "string" then
		local Text = string.lower(string.match(Value, "^%s*(.-)%s*$"))
		return Text == "true" or Text == "yes" or Text == "on"
			or Text == "ko" or Text == "k.o" or Text == "knocked"
			or Text == "knockedout" or Text == "crouch"
			or Text == "crouched" or Text == "crouching"
	end
	return false
end

function F.CachedStateValue(Character, Kind, Names)
	local Cache = St.StateCache[Character]
	if not Cache then
		Cache = {}
		St.StateCache[Character] = Cache
	end
	local Entry = Cache[Kind]
	if Entry and Entry.Object and Entry.Object:IsDescendantOf(Character) then
		return Entry.Object
	end
	local Now = os.clock()
	if Entry and not Entry.Object and Now < Entry.NextScan then
		return nil
	end
	local Object = F.FindValue(Character, Names)
	Cache[Kind] = {Object = Object, NextScan = Now + 0.5}
	return Object
end

function F.PointerOverPanel()
	if not UI.Gui or not UI.Gui.Enabled or not UI.Main or not UI.Main.Visible then
		return false
	end
	local Point = S.UIS:GetMouseLocation()
	local Position = UI.Main.AbsolutePosition
	local Size = UI.Main.AbsoluteSize
	return Point.X >= Position.X and Point.X <= Position.X + Size.X
		and Point.Y >= Position.Y and Point.Y <= Position.Y + Size.Y
end

function F.CanInteract(AllowResume)
	return St.Ready and not St.Cleaned and (AllowResume or not St.Panicked) and St.Focused
		and not S.UIS:GetFocusedTextBox() and not S.GuiService.MenuIsOpen
		and not St.KeyCapture and not St.SlotCapture
end

-- A disabled tool ignores Deactivate. Keep the release request until the
-- tool becomes enabled again instead of forgetting its activation latch.
function F.FlushToolReleases()
	for Tool in pairs(St.PendingToolReleases) do
		if not Tool.Parent or Tool.Parent ~= S.Player.Character then
			-- Unequipping ends the engine activation; never reclaim dropped tools.
			St.PendingToolReleases[Tool] = nil
		elseif Tool.Enabled then
			local Success = pcall(function() Tool:Deactivate() end)
			if Success then
				St.PendingToolReleases[Tool] = nil
				St.ToolReleasedFrame[Tool] = St.TriggerFrame
			end
		end
	end
end

function F.RequestToolRelease(Tool)
	if Tool and Tool.Parent then
		St.PendingToolReleases[Tool] = true
		F.FlushToolReleases()
	end
end

function F.ReleaseTool()
	local Tool = St.ActiveTool
	St.ActiveTool = nil
	F.RequestToolRelease(Tool)
end

function F.PauseInput()
	St.HeldDualKey = nil
	St.TriggerFOVTarget = nil
	F.EndRangeFire()
	F.EndDualFire()
	F.ReleaseTool()
	if St.HeldCameraKey then
		F.DisableCameraLock()
	end
	if St.HeldUniversalKey then
		F.DisableUniversal(false)
	end
	St.HeldCameraKey = nil
	St.HeldUniversalKey = nil
end

function F.Panic()
	St.Panicked = true
	St.KeyCapture = nil
	St.SlotCapture = nil
	F.PauseInput()
	F.DisableCameraLock()
	F.DisableSequential(false)
	F.DisableUniversal(false, true)
	F.SetAimAssist(false)
	F.SetSpeed(false)
	St.MenuOpen = false
	if UI.Gui then
		UI.Gui.Enabled = false
	end
	F.ApplyNameESPVisibility()
	F.Log("Stopped / Right Control shows the panel; enable a control to resume")
end

function F.Cleanup()
	if St.Cleaned then
		return
	end
	St.Cleaned = true
	St.Ready = false
	St.CharacterGeneration += 1
	St.LearnSerial += 1
	F.DisconnectAll(St.Connections)
	F.DisconnectAll(St.CharacterConnections)
	if St.BackpackConnection then
		St.BackpackConnection:Disconnect()
		St.BackpackConnection = nil
	end
	for _, Connection in pairs(St.NameESPConnections) do
		Connection:Disconnect()
	end
	table.clear(St.NameESPConnections)
	table.clear(St.NameESPPending)
	for Player, Tag in pairs(St.NameESPTags) do
		Tag:Destroy()
		St.NameESPTags[Player] = nil
	end
	St.Speed = false
	St.HeldDualKey = nil
	F.EndRangeFire()
	F.EndDualFire()
	F.ReleaseTool()
	F.FlushToolReleases()
	table.clear(St.PendingToolReleases)
	F.ApplySpeed()
	S.RunService:UnbindFromRenderStep(St.RenderBinding)
	S.OnSound:Destroy()
	S.OffSound:Destroy()
	if UI.Gui then
		UI.Gui:Destroy()
	end
	if St.Runtime then
		St.Runtime:Destroy()
	end
end

function F.SetKey(Name, Key)
	if Key == Enum.KeyCode.Unknown or Key == Enum.KeyCode.Escape then
		F.Log("Choose a keyboard key other than Escape")
		return false
	end
	for _, Other in ipairs({"CameraLockKey", "UniversalKey", "MenuKey", "StreamerKey",
		"PanicKey", "SpeedKey", "AimAssistKey", "DualFireKey"}) do
		if Other ~= Name and C[Other] == Key then
			F.Log(Key.Name .. " is already bound to " .. Other)
			return false
		end
	end
	F.PauseInput()
	C[Name] = Key
	return true
end

--========================================================
-- CHARACTER HELPERS
--========================================================

function F.Humanoid(Character)
	return Character
		and Character:FindFirstChildOfClass(
			"Humanoid"
		)
end

function F.EquippedTool()
	local Character =
		S.Player.Character

	return Character
		and Character:FindFirstChildWhichIsA(
			"Tool"
		)
end

function F.Alive(Character)
	local Humanoid =
		F.Humanoid(Character)

	return Humanoid
		and Humanoid.Health > 0
end

function F.FirstPerson()
	S.Camera =
		workspace.CurrentCamera

	if not S.Camera then
		return false
	end

	return (
		S.Camera.CFrame.Position
		- S.Camera.Focus.Position
	).Magnitude < 1
end

function F.FindValue(Container, Names)
	if not Container then
		return nil
	end
	local Wanted = {}
	for _, Name in ipairs(Names) do
		Wanted[string.lower(Name):gsub("[%s_%.%-]", "")] = true
	end
	for _, Object in ipairs(Container:GetDescendants()) do
		if Object:IsA("BoolValue") or Object:IsA("IntValue")
			or Object:IsA("NumberValue") or Object:IsA("StringValue") then
			local Name = string.lower(Object.Name):gsub("[%s_%.%-]", "")
			if Wanted[Name] then
				return Object
			end
		end
	end
	return nil
end

--========================================================
-- KO
--========================================================

function F.KO(Character)
	-- Historical name: true means the character is NOT knocked out.
	if not Character then
		return false
	end
	for _, Name in ipairs({"K.O", "KO", "KnockedOut", "IsKnockedOut"}) do
		if F.StateEnabled(Character:GetAttribute(Name)) then
			return false
		end
	end
	local Value = F.CachedStateValue(Character, "KO", {"k.o", "ko", "knockedout", "isknockedout"})
	return not (Value and F.StateEnabled(Value.Value))
end

--========================================================
-- CREW
--========================================================

--========================================================
-- CREW CHECK
--
-- Older versions treated numeric/string 0 as a real crew ID.
-- In many games, 0 means "no crew", so two unrelated players with
-- Crew = 0 were incorrectly treated as teammates.
--========================================================

function F.NormalizeCrewValue(Value)
	if typeof(Value) ~= "string" and typeof(Value) ~= "number" then
		return nil
	end
	local Text = string.lower(string.match(tostring(Value), "^%s*(.-)%s*$"))
	local Number = F.FiniteNumber(Text)
	if Number ~= nil then
		return Number > 0 and tostring(Number) or nil
	end
	if Text == "" or Text == "nil" or Text == "none" or Text == "false"
		or Text == "no crew" or Text == "nocrew" or Text == "no_crew"
		or Text == "nan" or Text == "inf" or Text == "-inf" then
		return nil
	end
	return Text
end

function F.FindCrewValue(Player)
	if not Player then
		return nil
	end
	-- A present attribute is authoritative, including a zero/no-crew value.
	for _, Name in ipairs({"Crew", "CrewID", "CrewId", "Crew_ID"}) do
		local Attribute = Player:GetAttribute(Name)
		if Attribute ~= nil then
			return F.NormalizeCrewValue(Attribute)
		end
	end
	local Now = os.clock()
	local Entry = St.CrewCache[Player]
	if Entry and Entry.Object and Entry.Object:IsDescendantOf(Player) then
		return F.NormalizeCrewValue(Entry.Object.Value)
	end
	if Entry and not Entry.Object and Now < Entry.NextScan then
		return nil
	end
	local Object = F.FindValue(Player, {"crew", "crewid"})
	St.CrewCache[Player] = {Object = Object, NextScan = Now + 0.5}
	return Object and F.NormalizeCrewValue(Object.Value) or nil
end

function F.Crew(Player)
	if not Player
		or Player == S.Player then

		return true
	end

	local MyCrew =
		F.FindCrewValue(
			S.Player
		)

	local TheirCrew =
		F.FindCrewValue(
			Player
		)

	if not MyCrew
		or not TheirCrew then

		return true
	end

	return MyCrew ~= TheirCrew
end

--========================================================
-- RANGE
--========================================================

function F.RangeForTool(Tool)
	if not Tool then
		return C.Distance.Fallback
	end

	local ToolName =
		string.lower(
			Tool.Name
		)

	for Name, Range in pairs(
		C.Distance
	) do
		if Name ~= "Fallback"
			and string.find(
				ToolName,
				string.lower(Name),
				1,
				true
			) then

			return Range
		end
	end

	return C.Distance.Fallback
end

function F.InRange(
	Character,
	Tool
)
	local Mine =
		S.Player.Character

	if not Mine
		or not Character then

		return false
	end

	local MyRoot =
		Mine:FindFirstChild(
			"HumanoidRootPart"
		)

	local TheirRoot =
		Character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not MyRoot
		or not MyRoot:IsA("BasePart")
		or not TheirRoot
		or not TheirRoot:IsA("BasePart") then

		return false
	end

	return (
		TheirRoot.Position
		- MyRoot.Position
	).Magnitude
		<= F.RangeForTool(Tool)
end

--========================================================
-- LOCAL MOVEMENT
--========================================================

function F.MovementParts()
	local Character =
		S.Player.Character

	local Humanoid =
		F.Humanoid(Character)

	local Root =
		Character
		and Character:FindFirstChild(
			"HumanoidRootPart"
		)

	return Character, Humanoid, Root
end

function F.ApplySpeed()
	local Humanoid = F.Humanoid(S.Player.Character)
	if not St.Speed or St.SpeedHumanoid ~= Humanoid then
		if St.SpeedHumanoid and St.SpeedHumanoid.Parent and St.DefaultWalkSpeed ~= nil then
			St.SpeedHumanoid.WalkSpeed = St.DefaultWalkSpeed
		end
		St.SpeedHumanoid = nil
		St.DefaultWalkSpeed = nil
	end
	if not St.Speed or not Humanoid or Humanoid.Health <= 0 then
		return
	end
	if St.SpeedHumanoid ~= Humanoid then
		St.SpeedHumanoid = Humanoid
		St.DefaultWalkSpeed = Humanoid.WalkSpeed
	end
	Humanoid.WalkSpeed = C.WalkSpeed
end

function F.SetSpeed(Enabled)
	if Enabled then St.Panicked = false end
	St.Speed =
		Enabled == true

	F.ApplySpeed()

	if St.Speed then
		F.Log(
			"Speed ON / "
			.. tostring(C.WalkSpeed)
		)
	else
		F.Log(
			"Speed OFF"
		)
	end

	F.Refresh()
end

--========================================================
-- CROUCH
--========================================================

function F.Crouch(Character)
	-- true means firing is allowed. Read values once per frame in the main loop.
	if not Character then
		return false
	end
	if Character ~= S.Player.Character then
		return true
	end
	local Value = F.CachedStateValue(Character, "Crouch",
		{"iscrouching", "iscrouched", "crouching", "crouched", "crouch"})
	if Value and F.StateEnabled(Value.Value) then
		return false
	end
	local Humanoid = F.Humanoid(Character)
	-- pairs intentionally handles a missing Humanoid without skipping Player.
	for _, Container in pairs({Character, Humanoid, S.Player}) do
		for _, Name in ipairs({"Crouching", "Crouch", "Crouched", "IsCrouching", "IsCrouched"}) do
			if F.StateEnabled(Container:GetAttribute(Name)) then
				return false
			end
		end
	end
	local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		return true
	end
	if os.clock() >= St.NextAnimationScan then
		St.NextAnimationScan = os.clock() + 1
		table.clear(St.CrouchAnimationIds)
		local Animations = S.ReplicatedStorage:FindFirstChild("ClientAnimations")
		if Animations then
			for _, Object in ipairs(Animations:GetDescendants()) do
				if Object:IsA("Animation") and string.find(string.lower(Object.Name), "crouch", 1, true) then
					St.CrouchAnimationIds[Object.AnimationId] = true
				end
			end
		end
	end
	for _, Track in ipairs(Animator:GetPlayingAnimationTracks()) do
		local Animation = Track.Animation
		if string.find(string.lower(Track.Name), "crouch", 1, true)
			or (Animation and (string.find(string.lower(Animation.Name), "crouch", 1, true)
			or St.CrouchAnimationIds[Animation.AnimationId])) then
			return false
		end
	end
	return true
end

--========================================================
-- BASIC TARGET
--
-- Range intentionally happens later,
-- after the requested weapon is equipped.
--========================================================

function F.BasicTarget(Player, Character)
	if not Player or Player == S.Player or Player.Parent ~= S.Players
		or not Character or Player.Character ~= Character
		or not Character:IsDescendantOf(workspace) then
		return false
	end
	return F.Alive(Character) and F.KO(Character) and not F.NameESPIsAlly(Player)
end

--========================================================
-- TARGET SELECTION
--========================================================

function F.TargetSelected(Player)
	return Player
		and Player ~= S.Player
		and St.SelectedTargets[Player.UserId] == true
end

function F.SelectedTargetCount()
	local Count = 0

	for _, Selected in pairs(
		St.SelectedTargets
	) do
		if Selected == true then
			Count += 1
		end
	end

	return Count
end

function F.SetTargetSelected(
	Player,
	Selected
)
	if not Player
		or Player == S.Player then

		return
	end

	if Selected then
		St.SelectedTargets[Player.UserId] = true
	else
		St.SelectedTargets[Player.UserId] = nil
        if St.UniTarget == Player.Character then F.EndRangeFire(); F.ReleaseTool() end

		if St.CameraLockTarget == Player.Character then
			St.CameraLockTarget = nil
		end

		if St.SeqTarget == Player.Character then
			St.SeqTarget = nil
			St.LastSeqTarget = nil
		end

		if St.UniTarget == Player.Character then
			St.UniTarget = nil
			St.LastUniTarget = nil
		end
	end

	F.EnsureNameESP(Player)
	F.ApplyNameESPVisibility()
	if F.RefreshTargetsPage then
		F.RefreshTargetsPage()
	end

	if F.Refresh then
		F.Refresh()
	end
end

function F.ClearSelectedTargets()
	table.clear(
		St.SelectedTargets
	)

	St.CameraLockTarget = nil
	St.AimAssistTarget = nil
	St.LastAimScan = 0
	St.SeqTarget = nil
	St.UniTarget = nil
	St.LastSeqTarget = nil
	St.LastUniTarget = nil
	F.EndRangeFire()
	F.ReleaseTool()
	F.ApplyNameESPVisibility()

	if F.RefreshTargetsPage then
		F.RefreshTargetsPage()
	end

	if F.Refresh then
		F.Refresh()
	end
end

function F.SelectAllTargets()
	for _, Player in ipairs(
		S.Players:GetPlayers()
	) do
		if Player ~= S.Player then
			St.SelectedTargets[Player.UserId] = true
		end
	end

	F.ApplyNameESPVisibility()
	if F.RefreshTargetsPage then
		F.RefreshTargetsPage()
	end

	if F.Refresh then
		F.Refresh()
	end
end

--========================================================
-- TOOL READY
--========================================================

function F.IsKnifeTool(Tool)
	if not Tool
		or not Tool:IsA("Tool") then

		return false
	end

	return string.find(
		string.lower(Tool.Name),
		"knife",
		1,
		true
	) ~= nil
end

function F.ToolEmpty(Tool)
	if not Tool or not Tool:IsA("Tool") then return false end
	for _, Name in ipairs({"AmmoClient", "Ammo"}) do
		local Ammo = Tool:FindFirstChild(Name)
		if Ammo and (Ammo:IsA("IntValue") or Ammo:IsA("NumberValue") or Ammo:IsA("StringValue")) then
			local Count = F.FiniteNumber(Ammo.Value)
			if Count ~= nil and Count <= 0 then return true end
		end
	end
	return false
end

function F.ToolReady(Tool, IgnoreEnabled)
	if not Tool or not Tool:IsA("Tool") or (not IgnoreEnabled and not Tool.Enabled) then
		return false
	end
	if C.TriggerKnifeCheck and F.IsKnifeTool(Tool) then
		return false
	end
	if Tool.RequiresHandle then
		local Handle = Tool:FindFirstChild("Handle")
		if not Handle or not Handle:IsA("BasePart") then
			return false
		end
	end
	return not F.ToolEmpty(Tool)
end

--========================================================
-- MANUAL DB + TAC VOLLEY
--========================================================

function F.DualTool(ExactName, Aliases)
	local Exact = F.FindTool(ExactName)
	if Exact then return Exact end
	local function Normalize(Name)
		return string.lower(Name):gsub("[^%w]", "")
	end
	local Names = {[Normalize(ExactName)] = true}
	for _, Alias in ipairs(Aliases) do Names[Normalize(Alias)] = true end
	local Backpack = S.Player:FindFirstChildOfClass("Backpack")
	for _, Container in pairs({S.Player.Character, Backpack}) do
		for _, Tool in ipairs(Container:GetChildren()) do
			if Tool:IsA("Tool") and Names[Normalize(Tool.Name)] then return Tool end
		end
	end
	return nil
end

function F.RestoreEquipment(Session)
	-- If the user selected another weapon during an automatic session, keep
	-- that choice instead of putting the previously held gun beside it.
	local KeepEquipped = {}
	if S.Player.Character == Session.Character then
		for _, Tool in ipairs(Session.Character:GetChildren()) do
			local Controlled = Session.Tools and table.find(Session.Tools, Tool) or Tool == Session.Tool
			if Tool:IsA("Tool") and not Controlled then KeepEquipped[Tool] = true end
		end
	end
	local ManualSelection = next(KeepEquipped) ~= nil
	-- Restore only tools that still belong to this character/backpack. Do not
	-- retrieve consumed/dropped tools or move equipment into a new character.
	for _, Entry in ipairs(Session.Restore) do
		local Tool = Entry.Tool
		pcall(function()
			local Parent = Entry.Parent
			if Parent == Session.Character and ManualSelection and not KeepEquipped[Tool] then
				Parent = Session.Backpack
			end
			if Parent == Session.Character and
				(S.Player.Character ~= Session.Character or not F.Alive(Session.Character)) then
				Parent = Session.Backpack
			end
			if Parent and Parent.Parent and
				(Tool.Parent == Session.Character or Tool.Parent == Session.Backpack) then
				Tool.Parent = Parent
			end
			if Entry.ManualActivationOnly ~= nil and Tool.Parent then
				Tool.ManualActivationOnly = Entry.ManualActivationOnly
			end
		end)
	end
end

function F.EndDualFire(Message)
	local Session = St.DualFire
	if not Session then return end
	-- Clear first: equipment events may re-enter cleanup or input handlers.
	St.DualFire = nil
	if Session.Activated then
		for _, Tool in ipairs(Session.Tools) do
			if not Session.Released[Tool] then F.RequestToolRelease(Tool) end
		end
	end
	F.RestoreEquipment(Session)
	if Message and not St.Cleaned then
		if Session.Automatic then
			St.RangeRetryAt = os.clock() + 0.5
			F.RangeNotice(Message)
		else F.Log(Message) end
	end
end

function F.BeginDualFire(Automatic)
	if not F.CanInteract(not Automatic) then return false end
	if Automatic then
		if F.RangeTarget() ~= "Dual" then return false end
	elseif St.TacFallback or (St.DualFire and St.DualFire.Automatic) then
		-- A manual Y press owns its own bounded session.
		F.EndRangeFire()
	end
	if Automatic and St.DualFire then return false end
	local function Notice(Message)
		if Automatic then F.RangeNotice(Message) else F.Log(Message) end
	end
	if St.DualFire then
		-- Keep at most one repeat; never build an unbounded delayed-shot queue.
		if not St.DualFire.RepeatQueued then
			St.DualFire.RepeatQueued = true
			F.Log("DB + TAC: one repeat queued until both guns are ready")
		else
			F.Log("DB + TAC: a repeat is already queued")
		end
		return true
	end
	local Character = S.Player.Character
	local Backpack = S.Player:FindFirstChildOfClass("Backpack")
	if not F.Alive(Character) or not Backpack or not F.KO(Character) or not F.Crouch(Character) then
		Notice("DB + TAC: character must be alive, standing and ready")
		return false
	end
	local DB = F.DualTool(C.DualFireDBName, {"DB", "Double Barrel", "Double Barrel SG", "Double Barrel Shotgun"})
	local Tac = F.DualTool(C.DualFireTacName, {"Tac", "Tactical", "Tactical SG", "Tactical Shotgun"})
	if not DB or not Tac or DB == Tac then
		Notice("DB + TAC: both Tools are needed / check dualFire tool names in Config")
		return false
	end
	if not F.ToolReady(DB, true) or not F.ToolReady(Tac, true) then
		Notice("DB + TAC: both guns need ammo and must be ready")
		return false
	end
	St.Panicked = false
	F.ReleaseTool()
	local Now = os.clock()
	local RepeatDelay = Automatic and math.max(C.DualFireCooldown, C.ShotCooldown) or C.DualFireCooldown
	local Session = {
		Character = Character, Backpack = Backpack, Tools = {DB, Tac},
		Restore = {}, Phase = "Equip", Activated = false, Automatic = Automatic == true,
		Released = {}, ResetSent = false, RepeatQueued = false, ReadySince = nil,
		ReadyAfter = Now + C.DualFireEquipDelay,
		Deadline = math.max(Now, St.LastDualFire + RepeatDelay) + C.DualFireEquipTimeout,
	}
	-- Restore DB/TAC first, then restore any previously equipped third tool.
	for _, Tool in ipairs(Session.Tools) do
		table.insert(Session.Restore, {Tool = Tool, Parent = Tool.Parent,
			ManualActivationOnly = Tool.ManualActivationOnly})
	end
	for _, Tool in ipairs(Character:GetChildren()) do
		if Tool:IsA("Tool") and Tool ~= DB and Tool ~= Tac then
			table.insert(Session.Restore, {Tool = Tool, Parent = Character})
		end
	end
	St.DualFire = Session
	local Success, Error = pcall(function()
		for _, Entry in ipairs(Session.Restore) do
			if Entry.Tool ~= DB and Entry.Tool ~= Tac then Entry.Tool.Parent = Backpack end
		end
		for _, Tool in ipairs(Session.Tools) do
			-- This session owns release/reset until it hands the tool back.
			St.PendingToolReleases[Tool] = nil
			Tool.ManualActivationOnly = true
			-- EquipTool would unequip the first gun when equipping the second.
			-- Parenting requests local equip; the game may still reject dual equip.
			Tool.Parent = Character
		end
	end)
	if not Success then
		F.EndDualFire("DB + TAC equip failed: " .. tostring(Error))
		return false
	end
	return true
end

function F.UpdateDualFire()
	local Session = St.DualFire
	if not Session then return end
	if not F.CanInteract() or S.Player.Character ~= Session.Character
		or not F.Alive(Session.Character) or not F.KO(Session.Character)
		or not F.Crouch(Session.Character) then
		F.EndDualFire()
		return
	end
	local ShotTarget
	-- Revalidate on the firing phase, not just the earlier render callback.
	-- Losing the ray, changing range or disabling T cancels every auto repeat.
	if Session.Automatic then
		local Mode, Target = F.RangeTarget()
		ShotTarget = Target
		if Mode ~= "Dual" or not Target then
			if Mode == "Tac" then
				F.BeginTacFallback()
			else
				F.EndRangeFire()
				St.UniTarget, St.LastUniTarget = nil, nil
			end
			return
		end
	end
	local Now = os.clock()
	local RepeatDelay = Session.Automatic and math.max(C.DualFireCooldown, C.ShotCooldown) or C.DualFireCooldown
	local DB, Tac = Session.Tools[1], Session.Tools[2]
	if Session.Automatic and (not F.ToolReady(DB, true) or not F.ToolReady(Tac, true)) then
		F.EndRangeFire()
		F.RangeNotice("Range trigger: both shotguns need ammo")
		return
	end
	if DB.Parent ~= Session.Character or Tac.Parent ~= Session.Character then
		F.EndDualFire("DB + TAC stopped: weapon system did not keep both guns equipped")
		return
	end
	if Session.Phase == "Release" then
		if Now < Session.ReleaseAt then return end
		local AllReleased = true
		for _, Tool in ipairs(Session.Tools) do
			if not Session.Released[Tool] then
				-- Tool:Deactivate() is ignored while Tool.Enabled is false.
				-- Keep the gun equipped and release it once Enabled recovers.
				if Tool.Enabled then
					local Success, Error = pcall(function() Tool:Deactivate() end)
					if not Success then
						F.EndDualFire("DB + TAC release failed: " .. tostring(Error))
						return
					end
					if St.DualFire ~= Session then return end
					Session.Released[Tool] = true
				else
					AllReleased = false
				end
			end
		end
		if AllReleased and Now >= Session.RestoreAt then
			if Session.RepeatQueued or Session.Automatic then
				-- Reuse the equipped pair instead of racing another equip/unequip.
				Session.RepeatQueued = false
				Session.Phase = "Equip"
				Session.Activated = false
				Session.ResetSent = true -- both guns were just released above
				Session.ReadySince = Now
				Session.Released = {}
				Session.ReadyAfter = Now
				Session.Deadline = math.max(Now, St.LastDualFire + RepeatDelay) + C.DualFireEquipTimeout
			else
				F.EndDualFire()
			end
		elseif Now >= Session.ReleaseDeadline then
			F.EndDualFire("DB + TAC: gun stayed busy; queued repeat cancelled")
		end
		return
	end
	if not F.ToolReady(DB) or not F.ToolReady(Tac) then
		Session.ReadySince = nil
		if Now >= Session.Deadline then F.EndDualFire("DB + TAC: both guns did not become ready") end
		return
	end
	if not Session.ResetSent then
		-- Clear an old activation that could not be released during a previous
		-- cooldown, focus loss or cancelled action. Both guns are Enabled here.
		local Success, Error = pcall(function()
			DB:Deactivate()
			Tac:Deactivate()
		end)
		if not Success then F.EndDualFire("DB + TAC reset failed: " .. tostring(Error)); return end
		if St.DualFire ~= Session then return end
		Session.ResetSent = true
		Session.ReadySince = Now
		return -- let Deactivated handlers run before the next activation
	end
	Session.ReadySince = Session.ReadySince or Now
	-- These minimums overlap; a ready gun does not pay each wait in series.
	if Now < Session.ReadyAfter or Now < St.LastDualFire + RepeatDelay
		or Now - Session.ReadySince < C.DualFireReadyStable then
		if Now >= Session.Deadline then F.EndDualFire("DB + TAC: readiness did not settle") end
		return
	end
	if Session.Automatic and (not F.TriggerShotAllowed(DB, ShotTarget)
		or not F.TriggerShotAllowed(Tac, ShotTarget)) then
		F.StopTriggerTarget()
		return
	end
	Session.Phase = "Release"
	Session.ReleaseAt = Now + C.DualFirePulse
	Session.RestoreAt = Now + C.DualFirePostShotHold
	Session.ReleaseDeadline = Now + C.DualFireReleaseTimeout
	Session.Activated = true
	Session.Released = {}
	St.LastDualFire = Now
	St.ToolLastShots[DB], St.ToolLastShots[Tac] = Now, Now
	-- Both requests are still issued together; never retry only TAC based on
	-- delayed ammo replication, which could produce an unintended extra shot.
	local Success, Error = pcall(function()
		DB:Activate()
		-- A weapon callback can change selection or cancel the session. Do not
		-- let the second activation inherit permission from the first one.
		if Session.Automatic and (St.DualFire ~= Session or not St.Universal
			or not F.CanInteract() or not F.TriggerShotAllowed(Tac, ShotTarget)) then
			if St.DualFire == Session then F.StopTriggerTarget() end
			return
		end
		Tac:Activate()
	end)
	if not Success then
		F.EndDualFire("DB + TAC activation failed: " .. tostring(Error))
	elseif not Session.Automatic then
		F.Log("DB + TAC activation sent / waiting for release")
	end
end

--========================================================
-- HOTBAR
--========================================================

function F.FindTool(Name)
	if not Name then
		return nil
	end

	local Character =
		S.Player.Character

	local Backpack =
		S.Player:FindFirstChildOfClass(
			"Backpack"
		)

	if Character then
		local Tool =
			Character:FindFirstChild(
				Name
			)

		if Tool
			and Tool:IsA("Tool") then

			return Tool
		end
	end

	if Backpack then
		local Tool =
			Backpack:FindFirstChild(
				Name
			)

		if Tool
			and Tool:IsA("Tool") then

			return Tool
		end
	end

	return nil
end

function F.ToolForSlot(Slot)
	local Name =
		St.LearnedSlots[Slot]

	if not Name then
		return nil
	end

	return F.FindTool(Name)
end

function F.ToolName(Slot)
	return St.LearnedSlots[Slot]
		or "UNMAPPED"
end

--========================================================
-- TOOL SLOT METADATA
--========================================================

function F.SeedTool(Tool)
	if not Tool
		or not Tool:IsA("Tool") then

		return
	end

	for _, Name in ipairs({
		"HotbarSlot",
		"SlotNumber",
		"InventorySlot"
	}) do
		local Attribute =
			Tool:GetAttribute(Name)

		if typeof(Attribute)
			== "number" then

			local Slot =
				math.floor(Attribute)

			if Slot >= 1
				and Slot <= 9 then

				St.LearnedSlots[Slot] =
					Tool.Name

				return
			end
		end

		local Value =
			Tool:FindFirstChild(Name)

		if Value
			and Value:IsA("IntValue")
			and Value.Value >= 1
			and Value.Value <= 9 then

			St.LearnedSlots[
				Value.Value
			] = Tool.Name

			return
		end
	end
end

function F.SeedSlots()
	local Character =
		S.Player.Character

	local Backpack =
		S.Player:FindFirstChildOfClass(
			"Backpack"
		)

	if Character then
		for _, Object in ipairs(
			Character:GetChildren()
		) do
			F.SeedTool(Object)
		end
	end

	if Backpack then
		for _, Object in ipairs(
			Backpack:GetChildren()
		) do
			F.SeedTool(Object)
		end
	end
end

--========================================================
-- LEARN ACTUAL NUMBER KEY -> TOOL
--========================================================

function F.LearnSlot(Slot)
	if St.Cleaned or S.UIS:GetFocusedTextBox() then
		return
	end
	St.LearnSerial += 1
	local Serial = St.LearnSerial
	local Character = S.Player.Character
	local Before = F.EquippedTool()
	task.spawn(function()
		local Deadline = os.clock() + 0.4
		while os.clock() < Deadline do
			S.RunService.RenderStepped:Wait()
			if St.Cleaned or St.LearnSerial ~= Serial or Character ~= S.Player.Character then
				return
			end
			local Current = F.EquippedTool()
			local Candidate = nil
			if Current and Current ~= Before then
				Candidate = Current
			elseif not Current and Before and Before.Parent
				and Before.Parent:IsA("Backpack") then
				Candidate = Before
			end
			if Candidate then
				St.LearnedSlots[Slot] = Candidate.Name
				F.RefreshSequence()
				return
			end
		end
		-- No observed equip/unequip means no evidence that this slot changed.
	end)
end

--========================================================
-- EQUIP / HOLSTER
--========================================================

function F.Equip(
	Slot,
	Mode
)
	local Character =
		S.Player.Character

	if not Character then
		return false
	end

	local Humanoid =
		F.Humanoid(Character)

	if not Humanoid then
		return false
	end

	local Tool =
		F.ToolForSlot(Slot)

	if not Tool then
		return false
	end

	if F.EquippedTool() ~= Tool then
		Humanoid:EquipTool(Tool)
	end

	if Mode == "Sequential" then
		St.SequentialTool = Tool
	else
		St.UniversalTool = Tool
	end

	return true
end

function F.Holster(Tool)
	if not Tool then
		return
	end

	if F.EquippedTool()
		~= Tool then

		return
	end

	local Humanoid =
		F.Humanoid(
			S.Player.Character
		)

	if Humanoid then
		Humanoid:UnequipTools()
	end
end

function F.HolsterSequential()
	F.Holster(
		St.SequentialTool
	)

	St.SequentialTool = nil
end

function F.HolsterUniversal()
	F.Holster(
		St.UniversalTool
	)

	St.UniversalTool = nil
end

--========================================================
-- SEQUENCE
--========================================================

function F.ResetSequence(Holster)
	St.SequenceIndex = 1
	if Holster then
		F.HolsterSequential()
	end
end

function F.CurrentSequenceSlot()
	return St.Sequence[
		St.SequenceIndex
	]
end

function F.SequenceText()
	local Slot =
		St.Sequence[1]

	if not Slot then
		return "UNMAPPED"
	end

	return
		"Hotbar "
		.. tostring(Slot)
		.. " / single weapon"
end

--========================================================
-- TARGET UNDER CURSOR
--========================================================

function F.CharacterFromPart(Part)
	local Current = Part

	while Current
		and Current ~= workspace do

		if Current:IsA("Model") then
			local Player =
				S.Players:
				GetPlayerFromCharacter(
					Current
				)

			if Player then
				return Player, Current
			end
		end

		Current = Current.Parent
	end

	return nil, nil
end

function F.CursorTarget(Tool, RangeOverride)
	local Camera = workspace.CurrentCamera
	local Mine = S.Player.Character
	if not Camera or not Mine then return nil end
	local Cursor = S.UIS:GetMouseLocation()
	-- GetMouseLocation and ViewportPointToRay use viewport pixels. Casting
	-- here observes this frame's camera updates instead of cached Mouse.Target.
	local Ray = Camera:ViewportPointToRay(Cursor.X, Cursor.Y)
	local Ignore = {Mine, Camera}
	if S.Mouse.TargetFilter then table.insert(Ignore, S.Mouse.TargetFilter) end
	St.TriggerRayParams.FilterDescendantsInstances = Ignore
	local Root = Mine:FindFirstChild("HumanoidRootPart")
	local CameraDistance = Root and Root:IsA("BasePart")
		and (Camera.CFrame.Position - Root.Position).Magnitude or 0
	local Length = math.min(15000, (RangeOverride or F.RangeForTool(Tool)) + CameraDistance + 8)
	local Hit = workspace:Raycast(Ray.Origin, Ray.Direction * Length, St.TriggerRayParams)
	-- Never fall back to an old hit or cast through an obstruction.
	local Player, Character = F.CharacterFromPart(Hit and Hit.Instance)
	if F.BasicTarget(Player, Character) and F.TargetSelected(Player) then
		return Character
	end
	return nil
end

-- The trigger square only controls acquisition. It never redirects the gun's
-- firing direction; camera lock/aim assist remain independent user controls.
function F.TriggerTarget(Tool, RangeOverride)
	St.TriggerFOVTarget = nil
	if not C.TriggerFOVEnabled then return F.CursorTarget(Tool, RangeOverride) end
	-- Nearby selection is not permission to fire along a different cursor ray.
	-- FOV and ray checks must resolve to the exact same selected character.
	local CursorCharacter = F.CursorTarget(Tool, RangeOverride)
	if not CursorCharacter then return nil end
	local Camera = workspace.CurrentCamera
	local Mine = S.Player.Character
	local Root = Mine and Mine:FindFirstChild("HumanoidRootPart")
	if not Camera or not Root or not Root:IsA("BasePart") then return nil end
	local Cursor = S.UIS:GetMouseLocation()
	local HalfSize = C.TriggerFOVSize * 0.5
	local Range = RangeOverride or F.RangeForTool(Tool)
	local Candidates = {}
	for _, Player in ipairs(S.Players:GetPlayers()) do
		local Character = Player.Character
		if Character ~= CursorCharacter or not F.TargetSelected(Player)
			or not F.BasicTarget(Player, Character) then continue end
		local Part = F.CameraLockBodyPart(Character)
		local TheirRoot = Character:FindFirstChild("HumanoidRootPart")
		if not Part or not TheirRoot or not TheirRoot:IsA("BasePart")
			or (TheirRoot.Position - Root.Position).Magnitude > Range then continue end
		local Point, Visible = Camera:WorldToViewportPoint(Part.Position)
		local DX, DY = Point.X - Cursor.X, Point.Y - Cursor.Y
		if Visible and Point.Z > 0 and math.abs(DX) <= HalfSize and math.abs(DY) <= HalfSize then
			table.insert(Candidates, {Character = Character, Part = Part,
				Distance = DX * DX + DY * DY, UserId = Player.UserId,
				Locked = St.CameraLock and St.CameraLockTarget == Character})
		end
	end
	table.sort(Candidates, function(A, B)
		if A.Locked ~= B.Locked then return A.Locked end
		if A.Distance == B.Distance then return A.UserId < B.UserId end
		return A.Distance < B.Distance
	end)
	local Ignore = {Mine, Camera}
	if S.Mouse.TargetFilter then table.insert(Ignore, S.Mouse.TargetFilter) end
	St.TriggerRayParams.FilterDescendantsInstances = Ignore
	-- Check nearest candidates first, so a normal frame needs only one cast.
	for _, Candidate in ipairs(Candidates) do
		local Offset = Candidate.Part.Position - Camera.CFrame.Position
		local Hit = workspace:Raycast(Camera.CFrame.Position, Offset, St.TriggerRayParams)
		if not Hit or Hit.Instance:IsDescendantOf(Candidate.Character) then
			St.TriggerFOVTarget = Candidate.Character
			return Candidate.Character
		end
	end
	return nil
end

function F.SetTriggerFOV(Enabled)
	F.StopTriggerTarget()
	C.TriggerFOVEnabled = Enabled == true
	F.UpdateTriggerFOV()
end

function F.SetTriggerFOVSize(Value)
	local Size = F.FiniteNumber(Value)
	if not Size then return end
	F.StopTriggerTarget()
	C.TriggerFOVSize = math.floor(math.clamp(Size, 20, 1200) + 0.5)
	F.UpdateTriggerFOV()
end

-- The trigger FOV remains a detection boundary, but its visual square is removed.
function F.UpdateTriggerFOV()
	-- Intentionally no visual overlay.
end

--========================================================
-- CAMERALOCK
--========================================================

function F.CameraLockBodyPart(Character)
	if not Character then
		return nil
	end
	for _, Name in ipairs({"UpperTorso", "Torso", "HumanoidRootPart"}) do
		local Part = Character:FindFirstChild(Name)
		if Part and Part:IsA("BasePart") then
			return Part
		end
	end
	return nil
end

function F.FindCameraLockTarget()
	S.Camera =
		workspace.CurrentCamera

	if not S.Camera then
		return nil
	end

	local Cursor = S.UIS:GetMouseLocation()

	local MyCharacter =
		S.Player.Character

	local MyRoot =
		MyCharacter
		and MyCharacter:FindFirstChild(
			"HumanoidRootPart"
		)

	if not MyRoot or not MyRoot:IsA("BasePart") then
		return nil
	end

	local Candidates = {}
	local MaxCursorDistance = 0
	local MaxWorldDistance = 0

	for _, Player in ipairs(
		S.Players:GetPlayers()
	) do
		if Player == S.Player
			or not F.TargetSelected(
				Player
			) then

			continue
		end

		local Character =
			Player.Character

		if not F.BasicTarget(
			Player,
			Character
		) then

			continue
		end

		local BodyPart =
			F.CameraLockBodyPart(
				Character
			)

		local TheirRoot =
			Character
			and Character:FindFirstChild(
				"HumanoidRootPart"
			)

		if not BodyPart
			or not TheirRoot
			or not TheirRoot:IsA("BasePart") then

			continue
		end

		local Point, Visible =
			S.Camera:
				WorldToViewportPoint(
					BodyPart.Position
				)

		if not Visible
			or Point.Z <= 0 then

			continue
		end

		local CursorDistance =
			(
				Vector2.new(
					Point.X,
					Point.Y
				)
				- Cursor
			).Magnitude

		local WorldDistance =
			(
				TheirRoot.Position
				- MyRoot.Position
			).Magnitude

		MaxCursorDistance =
			math.max(
				MaxCursorDistance,
				CursorDistance
			)

		MaxWorldDistance =
			math.max(
				MaxWorldDistance,
				WorldDistance
			)

		table.insert(
			Candidates,
			{
				Character = Character,
				CursorDistance = CursorDistance,
				WorldDistance = WorldDistance
			}
		)
	end

	if #Candidates == 0 then
		return nil
	end

	local Best = nil
	local BestScore = math.huge

	for _, Candidate in ipairs(
		Candidates
	) do
		local CursorScore =
			MaxCursorDistance > 0
			and Candidate.CursorDistance
				/ MaxCursorDistance
			or 0

		local WorldScore =
			MaxWorldDistance > 0
			and Candidate.WorldDistance
				/ MaxWorldDistance
			or 0

		local Score =
			CursorScore
				* C.TargetCursorWeight
			+ WorldScore
				* C.TargetWorldDistanceWeight

		if Score < BestScore then
			BestScore = Score
			Best = Candidate.Character
		end
	end

	return Best
end

function F.EnableCameraLock()
	St.Panicked = false
	if F.SelectedTargetCount() <= 0 then
		St.CameraLock = false
		St.CameraLockTarget = nil

		F.Log(
			"CameraLock: select a target first"
		)

		return false
	end

	St.CameraLock = true
	St.CameraLockTarget = nil

	return true
end

function F.DisableCameraLock()
	St.CameraLock = false
	St.CameraLockTarget = nil
end

function F.UpdateCameraLock()
	if not St.CameraLock or not F.CanInteract() or F.PointerOverPanel() or not F.Alive(S.Player.Character) then
		return
	end

	S.Camera =
		workspace.CurrentCamera

	if not S.Camera then
		return
	end

	local LockedPlayer =
		St.CameraLockTarget
		and S.Players:GetPlayerFromCharacter(
			St.CameraLockTarget
		)
		or nil

	local NeedsTarget =
		not St.CameraLockTarget
		or not St.CameraLockTarget.Parent
		or not F.BasicTarget(LockedPlayer, St.CameraLockTarget)
		or not F.TargetSelected(
			LockedPlayer
		)

	-- Pick the best selected target only when there is no valid lock.
	-- Once acquired, CameraLock stays on that same player even if another
	-- selected player walks closer to the cursor.
	if NeedsTarget then
		St.CameraLockTarget =
			F.FindCameraLockTarget()
	end

	local Character =
		St.CameraLockTarget

	if not Character then
		return
	end

	local TargetPart =
		F.CameraLockBodyPart(
			Character
		)

	if not TargetPart then
		St.CameraLockTarget = nil
		return
	end

	-- The trigger casts through the actual cursor. Centering the camera on
	-- the target leaves an off-center cursor beside them in third person.
	F.AimCameraAt(TargetPart)
end

--========================================================
-- CLIENT CAMERA AIM ASSIST
-- Rotates the local view so the selected visible target lines up with the
-- cursor. It does not redirect bullets or apply damage. CameraLock takes
-- priority when both camera controls are enabled.
--========================================================

function F.AimCameraAt(Part)
	local Camera = workspace.CurrentCamera
	if not Camera or not Part or not Part:IsA("BasePart") then return end
	local Base = Camera.CFrame
	local Offset = Part.Position - Base.Position
	if Offset.Magnitude < 0.001 then return end
	local Cursor = S.UIS:GetMouseLocation()
	-- Use the same viewport coordinates as CursorTarget; do not subtract
	-- the top bar inset or move/lock the user's mouse to a different point.
	local Ray = Camera:ViewportPointToRay(Cursor.X, Cursor.Y)
	local Direction = Ray.Direction.Unit
	local Desired = Offset.Unit
	local Dot = math.clamp(Direction:Dot(Desired), -1, 1)
	if Dot >= 1 - 1e-12 then return end
	local Axis = Direction:Cross(Desired)
	if Axis.Magnitude < 1e-8 then
		-- Opposite rays need a defined perpendicular axis for a 180-degree turn.
		Axis = Direction:Cross(Base.UpVector)
		if Axis.Magnitude < 1e-8 then Axis = Direction:Cross(Base.RightVector) end
	end
	local Rotation = CFrame.fromAxisAngle(Axis.Unit, math.acos(Dot))
	Camera.CFrame = CFrame.new(Base.Position) * Rotation * Base.Rotation
end

function F.AimAssistLineOfSight(Character)
	S.Camera = workspace.CurrentCamera

	if not S.Camera
		or not Character then

		return false
	end

	local Head =
		Character:FindFirstChild(
			"Head"
		)

	if not Head or not Head:IsA("BasePart") then
		return false
	end

	local Params =
		RaycastParams.new()

	Params.FilterType =
		Enum.RaycastFilterType.Exclude

	Params.FilterDescendantsInstances = {
		S.Player.Character
	}

	Params.IgnoreWater = true

	local Origin =
		S.Camera.CFrame.Position

	local Direction =
		Head.Position - Origin

	local Result =
		workspace:Raycast(
			Origin,
			Direction,
			Params
		)

	return not Result
		or Result.Instance:IsDescendantOf(
			Character
		)
end

function F.FindAimAssistTarget(Tool)
	if not St.AimAssist then
		return nil
	end

	S.Camera = workspace.CurrentCamera

	if not S.Camera then
		return nil
	end

	local Cursor = S.UIS:GetMouseLocation()

	local Best = nil
	local BestDistance =
		C.AimAssistFOV

	for _, Player in ipairs(
		S.Players:GetPlayers()
	) do
		if Player == S.Player or not F.TargetSelected(Player) then
			continue
		end

		local Character =
			Player.Character

		if not F.BasicTarget(
			Player,
			Character
		) then

			continue
		end

		if Tool
			and not F.InRange(
				Character,
				Tool
			) then

			continue
		end

		local Head =
			Character:FindFirstChild(
				"Head"
			)

		if not Head or not Head:IsA("BasePart") then
			continue
		end

		local Point, Visible =
			S.Camera:
			WorldToViewportPoint(
				Head.Position
			)

		if not Visible
			or Point.Z <= 0 then

			continue
		end

		local Distance =
			(
				Vector2.new(
					Point.X,
					Point.Y
				)
				- Cursor
			).Magnitude

		if Distance <= BestDistance
			and F.AimAssistLineOfSight(
				Character
			) then

			BestDistance = Distance
			Best = Character
		end
	end

	return Best
end

function F.SetAimAssist(Enabled)
	if Enabled then St.Panicked = false end
	St.LastAimScan = 0
	St.AimAssist =
		Enabled == true

	if not St.AimAssist then
		St.AimAssistTarget = nil
	end

	F.Log(
		St.AimAssist
		and (
			"Aim assist ON / FOV "
			.. tostring(C.AimAssistFOV)
		)
		or "Aim assist OFF"
	)

	F.Refresh()
end

function F.AimAssistInFOV(Character)
	local Camera = workspace.CurrentCamera
	local Head = Character and Character:FindFirstChild("Head")
	if not Camera or not Head or not Head:IsA("BasePart") then return false end
	local Point, Visible = Camera:WorldToViewportPoint(Head.Position)
	return Visible and Point.Z > 0
		and (Vector2.new(Point.X, Point.Y) - S.UIS:GetMouseLocation()).Magnitude <= C.AimAssistFOV
end

function F.UpdateAimAssist()
	if not UI.AimAssistFOV then return end
	local Cursor = S.UIS:GetMouseLocation()
	UI.AimAssistFOV.Size = UDim2.fromOffset(C.AimAssistFOV * 2, C.AimAssistFOV * 2)
	UI.AimAssistFOV.Position = UDim2.fromOffset(Cursor.X, Cursor.Y)
	UI.AimAssistFOV.Visible = St.AimAssist and C.ShowAimAssistFOV
		and not St.StreamerMode and not St.Panicked
	local Tool = F.EquippedTool()
	if not St.AimAssist or not F.CanInteract() or F.PointerOverPanel()
		or St.CameraLock or not F.Alive(S.Player.Character) or not F.ToolReady(Tool) then
		St.AimAssistTarget = nil
	else
		local Now = os.clock()
		if Now - St.LastAimScan >= 0.1 then
			St.LastAimScan = Now
			St.AimAssistTarget = F.FindAimAssistTarget(Tool)
		end
		local Target = St.AimAssistTarget
		local Player = Target and S.Players:GetPlayerFromCharacter(Target)
		if Target and F.BasicTarget(Player, Target) and F.TargetSelected(Player)
			and F.InRange(Target, Tool) and F.AimAssistInFOV(Target)
			and F.AimAssistLineOfSight(Target) then
			F.AimCameraAt(Target:FindFirstChild("Head"))
		else
			St.AimAssistTarget = nil
			St.LastAimScan = 0
		end
	end
	UI.AimAssistFOVStroke.Color = St.AimAssistTarget and T.Green or T.RedBright
end

--========================================================
-- AUTOMATIC RANGE EQUIP / FIRE
--========================================================

function F.RangeNotice(Message)
	if St.RangeLastNotice ~= Message then
		St.RangeLastNotice = Message
		F.Log(Message)
	end
end

function F.RangeTarget()
	local Mine = S.Player.Character
	if not C.RangeAuto or not St.Universal or not F.CanInteract()
		or F.PointerOverPanel() or not F.Alive(Mine) or not F.KO(Mine)
		or not F.Crouch(Mine) then return nil end
	-- Never shorten the acquisition ray to the currently equipped shotgun.
	local Target = F.TriggerTarget(nil, C.RangeMaximum)
	local MyRoot = Mine:FindFirstChild("HumanoidRootPart")
	local TheirRoot = Target and Target:FindFirstChild("HumanoidRootPart")
	if not MyRoot or not MyRoot:IsA("BasePart")
		or not TheirRoot or not TheirRoot:IsA("BasePart") then return nil end
	local Distance = (TheirRoot.Position - MyRoot.Position).Magnitude
	if Distance > C.RangeMaximum then return nil end
	if Distance < C.RangeSwitch then
		local DB = F.DualTool(C.DualFireDBName, {"DB", "Double Barrel", "Double Barrel SG", "Double Barrel Shotgun"})
		local Tac = F.DualTool(C.DualFireTacName, {"Tac", "Tactical", "Tactical SG", "Tactical Shotgun"})
		-- Empty ammo, not a temporary cooldown, grants the close-range REV band.
		-- It only takes priority when the player has equipped the REV themselves.
		if (F.ToolEmpty(DB) or F.ToolEmpty(Tac)) and F.IsRangeRevolver(F.EquippedTool()) then
			return "Rev", Target
		end
		if Distance < C.RangeMinimum then return nil end
		return F.ToolEmpty(DB) and "Tac" or "Dual", Target
	end
	return "Rev", Target
end

function F.EndRangeFire()
	if St.DualFire and St.DualFire.Automatic then F.EndDualFire() end
	F.EndTacFallback()
end

function F.SetRangeAuto(Enabled)
	F.StopTriggerTarget()
	C.RangeAuto = Enabled == true
	St.RangeLastNotice = nil
	St.RangeRetryAt = 0
end

function F.IsRangeRevolver(Tool)
	if not Tool or not Tool:IsA("Tool") then return false end
	local Name = string.lower(Tool.Name):gsub("[^%w]", "")
	local Configured = string.lower(C.RangeRevName):gsub("[^%w]", "")
	return Name == Configured or Name == "rev" or Name == "revolver"
end

function F.EndTacFallback()
	local Session = St.TacFallback
	if not Session then return end
	St.TacFallback = nil
	F.ReleaseTool()
	F.RequestToolRelease(Session.Tool)
	F.RestoreEquipment(Session)
end

function F.BeginTacFallback()
	if St.TacFallback then return true end
	if F.RangeTarget() ~= "Tac" then return false end
	local Character = S.Player.Character
	local Backpack = S.Player:FindFirstChildOfClass("Backpack")
	local Tac = F.DualTool(C.DualFireTacName, {"Tac", "Tactical", "Tactical SG", "Tactical Shotgun"})
	if not Backpack or not F.ToolReady(Tac, true) then
		F.EndRangeFire()
		F.RangeNotice("DB is empty / TAC needs ammo to continue")
		return false
	end
	local Pair = St.DualFire
	if Pair and not Pair.Automatic then return false end
	F.ReleaseTool()
	local Session = {
		Character = Character, Backpack = Backpack, Tool = Tac,
		Restore = {}, ReadyAfter = os.clock() + (Tac.Parent == Character and 0 or C.DualFireEquipDelay),
	}
	if Pair then
		-- Transfer restoration ownership without unequipping a recovering TAC.
		Session.Restore = Pair.Restore
		St.DualFire = nil
	else
		table.insert(Session.Restore, {Tool = Tac, Parent = Tac.Parent,
			ManualActivationOnly = Tac.ManualActivationOnly})
		for _, Equipped in ipairs(Character:GetChildren()) do
			if Equipped:IsA("Tool") and Equipped ~= Tac then
				table.insert(Session.Restore, {Tool = Equipped, Parent = Character})
			end
		end
	end
	St.TacFallback = Session
	local Success, Error = pcall(function()
		for _, Tool in ipairs(Character:GetChildren()) do
			if Tool:IsA("Tool") and Tool ~= Tac then
				F.RequestToolRelease(Tool)
				Tool.Parent = Backpack
			end
		end
		Tac.ManualActivationOnly = true
		Tac.Parent = Character
		-- A final paired TAC shot may still be cooling down. Drain that release
		-- through the normal trigger before asking for another activation.
		F.RequestToolRelease(Tac)
	end)
	if not Success or St.TacFallback ~= Session or Tac.Parent ~= Character then
		if St.TacFallback == Session then F.EndTacFallback() end
		St.RangeRetryAt = os.clock() + 0.5
		F.RangeNotice("TAC fallback equip failed" .. (Success and "" or ": " .. tostring(Error)))
		return false
	end
	F.RangeNotice("DB is empty / TAC trigger active until DB has ammo")
	return true
end

function F.RangeMain()
	local Mode, Target = F.RangeTarget()
	if not Mode then F.StopTriggerTarget(); return end
	St.UniTarget, St.LastUniTarget = Target, Target
	if Mode == "Dual" then
		St.ManualRevTool = nil
		F.EndTacFallback()
		F.ReleaseTool()
		if not St.DualFire and os.clock() >= St.RangeRetryAt then
			if F.BeginDualFire(true) then St.RangeLastNotice = nil end
		end
		return -- the paired state machine activates both in one callback
	end
	if Mode == "Tac" then
		St.ManualRevTool = nil
		if not St.TacFallback then
			if os.clock() < St.RangeRetryAt or not F.BeginTacFallback() then return end
		end
		local Session = St.TacFallback
		local Tac = Session.Tool
		if Session.Character ~= S.Player.Character or Tac.Parent ~= Session.Character
			or not F.ToolReady(Tac, true) then F.EndTacFallback(); return end
		local Now = os.clock()
		if Now >= Session.ReadyAfter and Now - (St.ToolLastShots[Tac] or -math.huge) >= C.ShotCooldown
			and F.FireTool(Tac, Target) then
			St.LastUniShot, St.ToolLastShots[Tac] = Now, Now
		end
		return
	end
	F.EndTacFallback()
	if St.DualFire and St.DualFire.Automatic then F.EndDualFire() end
	-- Only inspect the equipped tool. Never search the backpack for REV,
	-- equip/holster it, or change its manual-activation setting.
	local Tool = F.EquippedTool()
	if not F.IsRangeRevolver(Tool) or not F.ToolReady(Tool, true) then
		F.StopTriggerTarget()
		return
	end
	if St.ActiveTool and St.ActiveTool ~= Tool then F.ReleaseTool() end
	if St.ManualRevTool ~= Tool then
		St.ManualRevTool = Tool
		-- Clear a press left behind by a manual equip or completed Y volley.
		-- No equipment changes or fixed equip delay are needed for a held REV.
		F.RequestToolRelease(Tool)
		return
	end
	local Now = os.clock()
	local LastShot = St.ToolLastShots[Tool] or -math.huge
	if Now - LastShot >= C.ShotCooldown and F.FireTool(Tool, Target) then
		St.LastUniShot, St.ToolLastShots[Tool] = Now, Now
	end
end

function F.StopTriggerTarget()
	F.EndRangeFire()
	St.ManualRevTool = nil
	St.TriggerFOVTarget = nil
	St.UniTarget = nil
	St.LastUniTarget = nil
	F.ReleaseTool()
end

-- Recheck at activation time as well as acquisition: a queued shot must not
-- retain permission after deselection, target loss or a cursor change.
function F.TriggerShotAllowed(Tool, Target)
	return Target ~= nil and F.InRange(Target, Tool)
		and F.TriggerTarget(Tool) == Target
end

function F.FireTool(Tool, Target)
	if not F.CanInteract() or not F.ToolReady(Tool) or Tool.Parent ~= S.Player.Character then
		F.ReleaseTool()
		return false
	end
	if St.ActiveTool then
		if St.ActiveTool ~= Tool then F.ReleaseTool() end
		return false
	end
	-- Keep release and activation in separate scheduler turns so weapon
	-- callbacks cannot see a new press before the old release is processed.
	if St.PendingToolReleases[Tool] or St.ToolReleasedFrame[Tool] == St.TriggerFrame then
		return false
	end
	if not F.TriggerShotAllowed(Tool, Target) then
		F.ReleaseTool()
		return false
	end
	St.ActiveTool = Tool
	local Success, Error = pcall(function() Tool:Activate() end)
	if not Success then
		F.ReleaseTool()
		F.Log("Trigger activation failed: " .. tostring(Error))
	end
	return Success
end

--========================================================
-- TRIGGER MODES
--========================================================

function F.DisableSequential(Holster)
	St.Sequential = false

	St.SeqTarget = nil
	St.LastSeqTarget = nil
	St.SeqLostSince = nil

	F.ResetSequence(
		Holster == true
	)
end

function F.EnableSequential()
	-- This legacy mode remains disabled; the panel uses the equipped tool.
	St.Sequential = false
	return false
end

function F.DisableUniversal(_Holster, _Force)
	St.Universal = false
	St.HeldUniversalKey = nil
	F.StopTriggerTarget()
	return true
end

function F.EnableUniversal()
	F.DisableSequential(false)
	St.Panicked = false
	St.Universal = true
	return true
end

--========================================================
-- SEQUENTIAL TRIGGER
--========================================================

function F.SequentialMain()
	if not St.Sequential then
		return
	end

	-- Local crouch check: Sequential never fires or changes weapons
	-- while the local player is crouched.
	local Character =
		S.Player.Character

	if not Character
		or not F.Crouch(Character) then

		return
	end

	local Target =
		F.CursorTarget()

	-- A one-frame cursor miss should not tear down the whole weapon
	-- sequence. Keep the previous target briefly, but never fire while
	-- the cursor is actually off target.
	if not Target then
		if St.LastSeqTarget then
			if not St.SeqLostSince then
				St.SeqLostSince = os.clock()
			end

			if os.clock() - St.SeqLostSince
				< C.SequentialTargetGrace then

				St.SeqTarget =
					St.LastSeqTarget

				return
			end

			St.SeqTarget = nil
			St.LastSeqTarget = nil
			St.SeqLostSince = nil

			-- Reset the sequence without unequipping the player's gun.
			F.ResetSequence(false)

			F.Log(
				"Sequential target lost"
			)
		else
			St.SeqTarget = nil
		end

		return
	end

	St.SeqLostSince = nil
	St.SeqTarget = Target

	if St.LastSeqTarget
		~= Target then

		St.LastSeqTarget =
			Target

		F.ResetSequence(false)

		F.Log(
			"Sequential target → "
			.. Target.Name
		)
	end

	local Slot =
		F.CurrentSequenceSlot()

	if not Slot then
		return
	end

	local Expected =
		F.ToolForSlot(Slot)

	if not Expected then
		return
	end

	local Current =
		F.EquippedTool()

	-- Equip the current sequence weapon. It remains selected until its
	-- ammo is exhausted; Sequential no longer swaps after every shot.
	if Current ~= Expected then
		F.Equip(
			Slot,
			"Sequential"
		)

		return
	end

	-- Check range using the gun that is actually being fired.
	if not F.InRange(
		Target,
		Expected
	) then

		return
	end

	-- Stop if the configured Sequential weapon has no usable ammo.
	-- Multi-gun automatic switching has been removed.
	if not F.ToolReady(
		Expected
	) then
		return
	end

	if os.clock()
		- St.LastSeqShot
		< C.ShotCooldown then

		return
	end

	F.FireTool(Expected, Target)

	St.LastSeqShot =
		os.clock()
end

--========================================================
-- UNIVERSAL TRIGGER
-- AUTO RANGE MODE OR MANUAL EQUIPPED-TOOL MODE
--========================================================

function F.UniversalMain()
	St.TriggerFrame += 1
	F.FlushToolReleases()
	-- HeldDualKey debounces the Y key only. Once its session is finished,
	-- continuing to hold Y must not keep the normal trigger disabled.
	if (St.DualFire and not St.DualFire.Automatic)
		or not St.Universal or not F.CanInteract() or F.PointerOverPanel() then
		F.StopTriggerTarget()
		return
	end
	if C.RangeAuto then F.RangeMain(); return end
	F.EndRangeFire()
	local Current = F.EquippedTool()
	if St.ActiveTool and St.ActiveTool ~= Current then F.ReleaseTool() end
	if not F.ToolReady(Current) then
		F.StopTriggerTarget()
		return
	end
	local Target = F.TriggerTarget(Current)
	if not Target or not F.InRange(Target, Current) then
		F.StopTriggerTarget()
		return
	end
	St.UniTarget = Target
	local TargetChanged = St.LastUniTarget ~= Target
	St.LastUniTarget = Target
	local Now = os.clock()
	-- Swapping guns does not inherit the previous gun's configured delay.
	local LastShot = St.ToolLastShots[Current] or -math.huge
	if Now - LastShot >= C.ShotCooldown and F.FireTool(Current, Target) then
		St.LastUniShot = Now
		St.ToolLastShots[Current] = Now
	end
	if TargetChanged then F.Log("Universal target → " .. Target.Name) end
end

--========================================================
-- NAME ESP
--
-- The control is integrated into for the chosen's existing Settings page.
-- Only selected targets and actual crewmates are visible. Selected targets
-- are red, including selected crewmates; other crewmates remain green.
--========================================================

function F.NameESPIsAlly(Player)
	if not Player
		or Player == S.Player then

		return false
	end

	-- Native Roblox team support.
	if S.Player.Team
		and Player.Team
		and S.Player.Team == Player.Team
		and not S.Player.Neutral
		and not Player.Neutral then

		return true
	end

	-- Re-use for the chosen's corrected crew logic.
	-- F.Crew() returns false only when both players have the same valid,
	-- non-empty/non-zero crew ID.
	if not F.Crew(Player) then
		return true
	end

	return false
end

function F.NameESPColor(Player)
	if F.TargetSelected(Player) then
		return T.RedBright
	end
	if Player and Player ~= S.Player and not F.Crew(Player) then
		return T.Green
	end

	return Color3.fromRGB(255, 255, 255)
end

function F.NameESPVisible(Player)
	-- Streamer mode hides ESP entirely when active
	return St.NameESPEnabled and not St.StreamerMode and not St.Panicked
		and Player ~= nil and Player ~= S.Player and Player.Parent == S.Players
		and (F.TargetSelected(Player) or not F.Crew(Player))
end

function F.RemoveNameESP(Player)
	if not Player then
		return
	end

	local Tag =
		St.NameESPTags[Player]

	if Tag then
		Tag:Destroy()
	end

	St.NameESPTags[Player] = nil
end

function F.UpdateNameESPTag(Player)
	if not Player then
		return false
	end

	local Tag =
		St.NameESPTags[Player]

	if not Player.Parent
		or not Tag
		or not Tag.Parent then

		F.RemoveNameESP(Player)
		return false
	end

	local Character =
		Player.Character

	local Head =
		Character
		and Character:FindFirstChild(
			"Head"
		)

	-- A tag from an old character should never block the respawn/new-player path.
	if not Head
		or Tag.Adornee ~= Head then

		F.RemoveNameESP(Player)
		return false
	end

	local Label =
		Tag:FindFirstChild(
			"NameLabel"
		)

	if Label then
		Label.Text =
			Player.DisplayName

		Label.TextColor3 =
			F.NameESPColor(Player)
	end

	Tag.Enabled = F.NameESPVisible(Player)

	return true
end

function F.ApplyNameESPVisibility()
	for Player, Tag in pairs(
		St.NameESPTags
	) do
		if Tag
			and Tag.Parent then

			-- Refresh color too: selecting/deselecting or importing targets
			-- must not wait for the periodic crew/player reconciliation.
			F.UpdateNameESPTag(Player)
		end
	end
end

function F.CreateNameESPTag(
	Player,
	Character,
	Head
)
	if St.Cleaned or not Player
		or Player == S.Player
		or not Player.Parent
		or not Character
		or Character ~= Player.Character
		or not Character.Parent then

		return false
	end

	Head =
		Head
		or Character:FindFirstChild(
			"Head"
		)

	if not Head
		or not Head:IsA("BasePart")
		or not Head:IsDescendantOf(Character) then

		return false
	end

	F.RemoveNameESP(Player)

	local Tag =
		Instance.new("BillboardGui")

	Tag.Name = "for the chosenPlayerNameTag"
	Tag.Adornee = Head
	Tag.Size =
		UDim2.fromOffset(
			120,
			20
		)
	Tag.StudsOffset =
		Vector3.new(
			0,
			2.3,
			0
		)
	Tag.AlwaysOnTop = true
	Tag.Enabled = F.NameESPVisible(Player)
	Tag.Parent = S.PlayerGui

	local Label =
		Instance.new("TextLabel")

	Label.Name = "NameLabel"
	Label.Size = UDim2.fromScale(1, 1)
	Label.BackgroundTransparency = 1
	Label.Text = Player.DisplayName
	Label.TextColor3 =
		F.NameESPColor(Player)
	Label.TextStrokeTransparency = 0.4
	Label.TextSize = 11
	Label.TextScaled = false
	Label.Font = Enum.Font.GothamMedium
	Label.Parent = Tag

	St.NameESPTags[Player] = Tag
	return true
end

function F.EnsureNameESP(
	Player,
	Character
)
	if St.Cleaned or not Player
		or Player == S.Player
		or not Player.Parent then

		return
	end

	Character =
		Character
		or Player.Character

	if not Character
		or Character ~= Player.Character then

		return
	end

	if F.UpdateNameESPTag(Player) then
		return
	end

	-- Only one Head-wait/create task may exist for a player's current character.
	-- This removes the old retry overlap where several tasks could race each other.
	if St.NameESPPending[Player]
		== Character then

		return
	end

	St.NameESPPending[Player] =
		Character

	task.spawn(function()
		local Head =
			Character:FindFirstChild(
				"Head"
			)
			or Character:WaitForChild(
				"Head",
				10
			)

		-- A newer character/request supersedes this one.
		if St.Cleaned or St.NameESPPending[Player]
			~= Character then

			return
		end

		St.NameESPPending[Player] = nil

		if not Head
			or not Player.Parent
			or Player.Character ~= Character
			or not Character.Parent then

			return
		end

		F.CreateNameESPTag(
			Player,
			Character,
			Head
		)
	end)
end

function F.BindNameESPPlayer(Player)
	if not Player
		or Player == S.Player then

		return
	end

	-- Binding is idempotent. Reconciliation no longer disconnects/reconnects
	-- CharacterAdded, which could create gaps while a late joiner was spawning.
	if not St.NameESPConnections[Player] then
		St.NameESPConnections[Player] =
			Player.CharacterAdded:
			Connect(function(Character)
				St.NameESPPending[Player] = nil
				F.RemoveNameESP(Player)
				F.EnsureNameESP(
					Player,
					Character
				)
			end)
	end

	F.EnsureNameESP(Player)
end

-- The Name ESP control lives inside for the chosen's existing Settings page.
-- Player tracking runs separately from GUI refresh/focus so late joiners are
-- still discovered even while the window is minimized or unfocused.
function F.StartNameESP()
	-- Subscribe first so a player joining during initialization is not missed.
	St.NameESPPlayerAddedConnection = F.Connect(S.Players.PlayerAdded, F.BindNameESPPlayer)
	St.NameESPPlayerRemovingConnection = F.Connect(S.Players.PlayerRemoving, function(Player)
		local Connection = St.NameESPConnections[Player]
		if Connection then Connection:Disconnect() end
		St.NameESPConnections[Player] = nil
		St.NameESPPending[Player] = nil
		St.CrewCache[Player] = nil
		F.RemoveNameESP(Player)
	end)
	for _, Player in ipairs(S.Players:GetPlayers()) do
		F.BindNameESPPlayer(Player)
	end
	local LastReconcile = 0
	St.NameESPHeartbeatConnection = F.Connect(S.RunService.Heartbeat, function()
		local Now = os.clock()
		if Now - LastReconcile < 1 then return end
		LastReconcile = Now
		for _, Player in ipairs(S.Players:GetPlayers()) do
			F.BindNameESPPlayer(Player)
		end
	end)
end

--========================================================
-- MENU OPEN / CLOSE & STREAMER MODE
--========================================================

function F.ToggleMenu()
	St.MenuOpen = not St.MenuOpen

	if UI.Gui then
		if St.MenuOpen then
			UI.Gui.Enabled = true
			UI.Main.Size = UDim2.fromOffset(0, 0)
			UI.Main.Visible = true
			S.TweenService:Create(UI.Main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UI.Minimized and UDim2.fromOffset(218, 42) or UDim2.fromOffset(720, 600)
			}):Play()
		else
			local tween = S.TweenService:Create(UI.Main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.fromOffset(0, 0)
			})
			tween:Play()
			tween.Completed:Connect(function()
				if not St.MenuOpen then
					UI.Main.Visible = false
				end
			end)
		end
	end

	if St.MenuOpen then
		F.Log("Menu opened")
	else
		F.Log("Menu closed")
	end
end

function F.ToggleStreamerMode()
	St.StreamerMode = not St.StreamerMode

	-- Update ESP visibility instantly when Streamer Mode toggles
	F.ApplyNameESPVisibility()

	if St.StreamerMode then
		F.Log("Streamer mode ON (ESP hidden)")
	else
		F.Log("Streamer mode OFF (ESP shown)")
	end
end

--========================================================
-- CONFIG EXPORT
--========================================================

function F.ExportConfig()
	local Learned = {}
	local SelectedTargetUserIds = {}

	for UserId, Selected in pairs(
		St.SelectedTargets
	) do
		if Selected == true then
			table.insert(
				SelectedTargetUserIds,
				tostring(UserId)
			)
		end
	end

	for Slot, Name in pairs(
		St.LearnedSlots
	) do
		Learned[
			tostring(Slot)
		] = Name
	end

	return S.HttpService:JSONEncode({
		version = 21,
		dualFire = {
			db = C.DualFireDBName, tac = C.DualFireTacName,
			repeatDelayMs = C.DualFireCooldown * 1000,
			equipDelayMs = C.DualFireEquipDelay * 1000,
			postShotHoldMs = C.DualFirePostShotHold * 1000,
		},
		nameESP = {enabled = St.NameESPEnabled},
		trigger = {enabled = St.Universal, autoRange = C.RangeAuto, revolver = C.RangeRevName,
			fovEnabled = C.TriggerFOVEnabled, fovSize = C.TriggerFOVSize, showFov = C.ShowTriggerFOV},

		keys = {
			dualFire = C.DualFireKey.Name,
			cameralock =
				C.CameraLockKey.Name,

			sequential =
				C.SequentialKey.Name,

			universal =
				C.UniversalKey.Name,

			menu = C.MenuKey.Name,

			streamer =
				C.StreamerKey.Name,

			panic =
				C.PanicKey.Name,

			speed =
				C.SpeedKey.Name,


			aimAssist =
				C.AimAssistKey.Name
		},

		hold = {
			cameralock =
				C.HoldCameraLock,

			sequential =
				C.HoldSequential,

			universal =
				C.HoldUniversal
		},

		timing = {
			shotCooldown =
				C.ShotCooldown
				* 1000,

			uiRefresh =
				C.UIRefresh
				* 1000,

			triggerKnifeCheck =
				C.TriggerKnifeCheck
		},

		aimAssist = {
			enabled =
				St.AimAssist,

			fov =
				C.AimAssistFOV,

			showFov =
				C.ShowAimAssistFOV
		},

		movement = {
			speedEnabled =
				St.Speed,

			walkSpeed =
				C.WalkSpeed,

		},

		distance =
			C.Distance,

		sequence =
			St.Sequence,

		universalSlot =
			C.UniversalSlot,

		targetSelection = {
			userIds =
				SelectedTargetUserIds
		},

		learnedSlots =
			Learned
	})
end

--========================================================
-- CONFIG IMPORT
--========================================================

function F.ApplyKey(
	Name,
	Setter
)
	if typeof(Name)
		~= "string" then

		return
	end

	local Key =
		C.KeyByName[Name]

	if Key then
		Setter(Key)
	end
end

function F.ImportConfig(Text)
	if typeof(Text) ~= "string" or #Text > 262144 then
		return false, "Config must be JSON text under 256 KB"
	end
	local Success, Data = pcall(S.HttpService.JSONDecode, S.HttpService, Text)
	if not Success or typeof(Data) ~= "table" then return false, "Invalid JSON" end
	local function Section(Name)
		return typeof(Data[Name]) == "table" and Data[Name] or {}
	end
	local function Number(Value, Min, Max, Default)
		local Parsed = F.FiniteNumber(Value)
		return Parsed and math.clamp(Parsed, Min, Max) or Default
	end
	local function Boolean(Value, Default)
		if typeof(Value) == "boolean" then return Value end
		return Default
	end
	local KeyFields = {cameralock = "CameraLockKey", universal = "UniversalKey",
		menu = "MenuKey", streamer = "StreamerKey", panic = "PanicKey", speed = "SpeedKey",
		aimAssist = "AimAssistKey", dualFire = "DualFireKey"}
	local Keys, NewKeys, Used = Section("keys"), {}, {}
	local LegacyY = Keys.dualFire == nil and Keys.universal == "Y"
	for JsonKey, ConfigKey in pairs(KeyFields) do
		local Value = Keys[JsonKey]
		-- Migrate older exports whose trigger occupied the new dual-fire key.
		if JsonKey == "universal" and LegacyY then Value = "T" end
		if JsonKey == "cameralock" and Value == nil then Value = Keys.camlock end
		local Key = C[ConfigKey]
		if Value ~= nil then
			Key = typeof(Value) == "string" and C.KeyByName[Value] or nil
		end
		if not Key or Key == Enum.KeyCode.Unknown or Key == Enum.KeyCode.Escape then
			return false, "Invalid keybind: " .. JsonKey
		end
		if Used[Key] then return false, "Duplicate keybind: " .. Key.Name end
		Used[Key] = true
		NewKeys[ConfigKey] = Key
	end
	-- Validate keybinds before applying anything; false values must not fall
	-- through to a legacy alias (Lua's `a or b` loses an explicit false).
	F.PauseInput()
	for Name, Key in pairs(NewKeys) do C[Name] = Key end
	local Dual = Section("dualFire")
	C.DualFireCooldown = Number(Dual.repeatDelayMs, 0, 3000, C.DualFireCooldown * 1000) / 1000
	C.DualFireEquipDelay = Number(Dual.equipDelayMs, 0, 1000, C.DualFireEquipDelay * 1000) / 1000
	C.DualFirePostShotHold = Number(Dual.postShotHoldMs, 0, 1500, C.DualFirePostShotHold * 1000) / 1000
	for Field, Setting in pairs({db = "DualFireDBName", tac = "DualFireTacName"}) do
		local Value = Dual[Field]
		if typeof(Value) == "string" and #Value <= 256 then
			local Trimmed = string.match(Value, "^%s*(.-)%s*$")
			if Trimmed ~= "" then C[Setting] = Trimmed end
		end
	end
	local Trigger = Section("trigger")
	C.RangeAuto = Boolean(Trigger.autoRange, C.RangeAuto)
	C.TriggerFOVEnabled = Boolean(Trigger.fovEnabled, C.TriggerFOVEnabled)
	C.TriggerFOVSize = math.floor(Number(Trigger.fovSize, 20, 1200, C.TriggerFOVSize) + 0.5)
	C.ShowTriggerFOV = Boolean(Trigger.showFov, C.ShowTriggerFOV)
	if typeof(Trigger.revolver) == "string" and #Trigger.revolver <= 256 then
		local Name = string.match(Trigger.revolver, "^%s*(.-)%s*$")
		if Name ~= "" then C.RangeRevName = Name end
	end
	local Hold = Section("hold")
	local CameraHold = Hold.cameralock
	if CameraHold == nil then CameraHold = Hold.camlock end
	C.HoldCameraLock = Boolean(CameraHold, C.HoldCameraLock)
	C.HoldUniversal = Boolean(Hold.universal, C.HoldUniversal)
	F.DisableCameraLock()
	local Timing = Section("timing")
	C.ShotCooldown = Number(Timing.shotCooldown, 1, 1000, C.ShotCooldown * 1000) / 1000
	C.UIRefresh = Number(Timing.uiRefresh, 50, 1000, C.UIRefresh * 1000) / 1000
	C.TriggerKnifeCheck = Boolean(Timing.triggerKnifeCheck, C.TriggerKnifeCheck)
	local Aim = Section("aimAssist")
	C.AimAssistFOV = Number(Aim.fov, 25, 500, C.AimAssistFOV)
	C.ShowAimAssistFOV = Boolean(Aim.showFov, C.ShowAimAssistFOV)
	local Movement = Section("movement")
	C.WalkSpeed = Number(Movement.walkSpeed, 1, 100, C.WalkSpeed)
	local Distance = Section("distance")
	for Name, Old in pairs(C.Distance) do C.Distance[Name] = Number(Distance[Name], 1, 5000, Old) end
	if typeof(Data.learnedSlots) == "table" then
		table.clear(St.LearnedSlots)
		for SlotText, Name in pairs(Data.learnedSlots) do
			local Slot = F.FiniteNumber(SlotText)
			if Slot and Slot % 1 == 0 and Slot >= 1 and Slot <= 9 and typeof(Name) == "string" then
				St.LearnedSlots[Slot] = Name
			end
		end
	end
	if typeof(Data.sequence) == "table" then
		St.Sequence = {math.floor(Number(Data.sequence[1], 1, 9, St.Sequence[1] or 1))}
	end
	C.UniversalSlot = math.floor(Number(Data.universalSlot, 1, 9, C.UniversalSlot))
	local Selection = Section("targetSelection")
	if typeof(Selection.userIds) == "table" then
		table.clear(St.SelectedTargets)
		for _, Raw in ipairs(Selection.userIds) do
			local UserId = F.FiniteNumber(Raw)
			-- Negative integers also support Studio test players.
			if UserId and UserId % 1 == 0 and UserId ~= 0 and UserId ~= S.Player.UserId then
				St.SelectedTargets[UserId] = true
			end
		end
	end
	St.AimAssistTarget = nil
	St.LastAimScan = 0
	St.NameESPEnabled = Boolean(Section("nameESP").enabled, St.NameESPEnabled)
	F.ApplyNameESPVisibility()
	F.SetAimAssist(Boolean(Aim.enabled, St.AimAssist))
	F.SetSpeed(Boolean(Movement.speedEnabled, St.Speed))
	local TriggerEnabled = Boolean(Section("trigger").enabled, St.Universal)
	if TriggerEnabled and not C.HoldUniversal then F.EnableUniversal() else F.DisableUniversal(false) end
	F.RefreshTargetsPage()
	F.Refresh()
	return true, "Config imported"
end

--========================================================
-- UI HELPERS
--========================================================

function F.Round(
	Object,
	Radius
)
	local Corner =
		Instance.new("UICorner")

	Corner.CornerRadius =
		UDim.new(
			0,
			Radius or 8
		)

	Corner.Parent = Object

	return Corner
end

function F.Stroke(
	Object,
	Color,
	Transparency
)
	local Stroke =
		Instance.new("UIStroke")

	Stroke.Color =
		Color or T.Border

	Stroke.Thickness = 1

	Stroke.Transparency =
		Transparency or 0

	Stroke.Parent = Object

	return Stroke
end

function F.Label(
	Parent,
	Text,
	Size,
	Position,
	TextSize,
	Color
)
	local Object =
		Instance.new("TextLabel")

	Object.Size = Size
	Object.Position = Position

	Object.BackgroundTransparency = 1

	Object.Text = Text

	Object.TextColor3 =
		Color or T.Text

	Object.TextSize =
		TextSize or 12

	Object.Font =
		Enum.Font.Gotham

	Object.TextXAlignment =
		Enum.TextXAlignment.Left

	Object.Parent = Parent

	return Object
end

function F.Button(
	Parent,
	Text,
	Size,
	Position
)
	local Object =
		Instance.new("TextButton")

	Object.Size = Size
	Object.Position = Position

	Object.BackgroundColor3 =
		T.Panel2

	Object.BorderSizePixel = 0

	Object.Text = Text
	Object.TextColor3 = T.Text

	Object.TextSize = 10

	Object.Font =
		Enum.Font.GothamBold

	Object.AutoButtonColor = false

	Object.Parent = Parent

	F.Round(Object, 7)
	F.Stroke(Object)

	Object.MouseEnter:Connect(function()
		S.TweenService:Create(
			Object,
			TweenInfo.new(
				0.12,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),

			{
				BackgroundColor3 =
					T.CardHover
			}
		):Play()
	end)

	Object.MouseLeave:Connect(function()
		S.TweenService:Create(
			Object,
			TweenInfo.new(
				0.12,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),

			{
				BackgroundColor3 =
					T.Panel2
			}
		):Play()
	end)

	return Object
end

function F.Card(
	Parent,
	Height
)
	local Object =
		Instance.new("Frame")

	Object.Size =
		UDim2.new(
			1,
			0,
			0,
			Height
		)

	Object.BackgroundColor3 =
		T.Card

	Object.BorderSizePixel = 0

	Object.Parent = Parent

	F.Round(Object, 9)
	F.Stroke(Object)

	return Object
end

function F.Scroll(Page)
	local Scroll =
		Instance.new(
			"ScrollingFrame"
		)

	Scroll.Size =
		UDim2.fromScale(
			1,
			1
		)

	Scroll.BackgroundTransparency = 1
	Scroll.BorderSizePixel = 0

	Scroll.ScrollBarThickness = 3

	Scroll.ScrollBarImageColor3 =
		T.Red

	Scroll.AutomaticCanvasSize =
		Enum.AutomaticSize.Y

	Scroll.CanvasSize =
		UDim2.new()

	Scroll.Parent = Page

	local Layout =
		Instance.new("UIListLayout")

	Layout.Padding =
		UDim.new(
			0,
			8
		)

	Layout.SortOrder =
		Enum.SortOrder.LayoutOrder

	Layout.Parent = Scroll

	local Padding =
		Instance.new("UIPadding")

	Padding.PaddingRight =
		UDim.new(
			0,
			7
		)

	Padding.PaddingBottom =
		UDim.new(
			0,
			16
		)

	Padding.Parent = Scroll

	return Scroll
end

--========================================================
-- BACKGROUND TEXTURE
--========================================================

function F.AddTexture(Parent)
	local Texture =
		Instance.new("Frame")

	Texture.Name =
		"BackgroundTexture"

	Texture.Size =
		UDim2.fromScale(
			1,
			1
		)

	Texture.BackgroundTransparency =
		1

	Texture.BorderSizePixel = 0

	Texture.Parent =
		Parent

	-- Dark red gradient wash
	local Wash =
		Instance.new("Frame")

	Wash.Size =
		UDim2.fromScale(
			1,
			1
		)

	Wash.BackgroundColor3 =
		Color3.fromRGB(
			28,
			10,
			17
		)

	Wash.BackgroundTransparency =
		0.22

	Wash.BorderSizePixel = 0

	Wash.Parent =
		Texture

	local Gradient =
		Instance.new("UIGradient")

	Gradient.Rotation = 28

	Gradient.Color =
		ColorSequence.new({
			ColorSequenceKeypoint.new(
				0,
				Color3.fromRGB(
					43,
					13,
					21
				)
			),

			ColorSequenceKeypoint.new(
				0.38,
				Color3.fromRGB(
					13,
					14,
					20
				)
			),

			ColorSequenceKeypoint.new(
				1,
				Color3.fromRGB(
					7,
					9,
					13
				)
			)
		})

	Gradient.Parent =
		Wash

	-- Horizontal grid
	for Y = 18, 600, 30 do
		local Line =
			Instance.new("Frame")

		Line.Size =
			UDim2.new(
				1,
				0,
				0,
				1
			)

		Line.Position =
			UDim2.fromOffset(
				0,
				Y
			)

		Line.BackgroundColor3 =
			Color3.fromRGB(
				104,
				76,
				83
			)

		Line.BackgroundTransparency =
			0.93

		Line.BorderSizePixel = 0

		Line.Parent =
			Texture
	end

	-- Vertical grid
	for X = 20, 720, 40 do
		local Line =
			Instance.new("Frame")

		Line.Size =
			UDim2.new(
				0,
				1,
				1,
				0
			)

		Line.Position =
			UDim2.fromOffset(
				X,
				0
			)

		Line.BackgroundColor3 =
			Color3.fromRGB(
				89,
				72,
				79
			)

		Line.BackgroundTransparency =
			0.955

		Line.BorderSizePixel = 0

		Line.Parent =
			Texture
	end

	-- Small tech markers
	for Index = 1, 10 do
		local Marker =
			Instance.new("Frame")

		Marker.Size =
			UDim2.fromOffset(
				2,
				2
			)

		Marker.Position =
			UDim2.fromOffset(
				28 + (Index * 61),
				82 + ((Index % 4) * 97)
			)

		Marker.BackgroundColor3 =
			T.RedBright

		Marker.BackgroundTransparency =
			0.68

		Marker.BorderSizePixel = 0

		Marker.Parent =
			Texture
	end

	-- Upper-left red atmospheric glow
	local Glow =
		Instance.new("Frame")

	Glow.Size =
		UDim2.fromOffset(
			320,
			180
		)

	Glow.Position =
		UDim2.fromOffset(
			-110,
			-65
		)

	Glow.BackgroundColor3 =
		T.RedDark

	Glow.BackgroundTransparency =
		0.64

	Glow.BorderSizePixel = 0

	Glow.Parent =
		Texture

	F.Round(
		Glow,
		110
	)

	local GlowGradient =
		Instance.new("UIGradient")

	GlowGradient.Rotation = 45

	GlowGradient.Transparency =
		NumberSequence.new({
			NumberSequenceKeypoint.new(
				0,
				0.15
			),

			NumberSequenceKeypoint.new(
				1,
				1
			)
		})

	GlowGradient.Parent =
		Glow
end

--========================================================
-- BASE GUI
--========================================================

function F.BuildBaseUI()
	local PlayerGui =
		S.Player:FindFirstChildOfClass(
			"PlayerGui"
		)
		or S.Player:WaitForChild(
			"PlayerGui",
			10
		)

	if not PlayerGui then
		error("PlayerGui did not load within 10 seconds")
	end

	for _, Name in ipairs({
		"for the chosensGUI"
	}) do
		local Old =
			PlayerGui:
				FindFirstChild(Name)

		if Old then
			Old:Destroy()
		end
	end

	UI.Gui =
		Instance.new("ScreenGui")

	UI.Gui.Name =
		"for the chosensGUI"

	UI.Gui.ResetOnSpawn = false
	UI.Gui.IgnoreGuiInset = true
	UI.Gui.DisplayOrder = 50
	UI.Gui.AutoLocalize = false

	UI.Gui.ZIndexBehavior =
		Enum.ZIndexBehavior.Sibling

	UI.Gui.Parent =
		PlayerGui
	F.Connect(UI.Gui.Destroying, F.Cleanup)

	-- Aim-assist FOV overlay. It follows the mouse and is hidden when
	-- aim assist or its visualization is disabled.
	UI.AimAssistFOV =
		Instance.new("Frame")

	UI.AimAssistFOV.Name =
		"AimAssistFOV"

	UI.AimAssistFOV.AnchorPoint =
		Vector2.new(0.5, 0.5)

	UI.AimAssistFOV.Size =
		UDim2.fromOffset(
			C.AimAssistFOV * 2,
			C.AimAssistFOV * 2
		)

	UI.AimAssistFOV.BackgroundTransparency = 1
	UI.AimAssistFOV.BorderSizePixel = 0
	UI.AimAssistFOV.ZIndex = 100
	UI.AimAssistFOV.Visible = false
	UI.AimAssistFOV.Parent = UI.Gui

	local AimCorner =
		Instance.new("UICorner")

	AimCorner.CornerRadius =
		UDim.new(1, 0)

	AimCorner.Parent =
		UI.AimAssistFOV

	UI.AimAssistFOVStroke =
		Instance.new("UIStroke")

	UI.AimAssistFOVStroke.Thickness = 1.5
	UI.AimAssistFOVStroke.Transparency = 0.15
	UI.AimAssistFOVStroke.Color = T.RedBright
	UI.AimAssistFOVStroke.Parent = UI.AimAssistFOV

	UI.Main =
		Instance.new("Frame")

	UI.Main.Size =
		UDim2.fromOffset(
			720,
			600
		)

	UI.Main.Position =
		UDim2.new(
			0.5,
			-360,
			0.5,
			-300
		)

	UI.Main.BackgroundColor3 =
		T.BG

	UI.Main.BorderSizePixel = 0
	UI.Main.ClipsDescendants = true

	UI.Main.Parent =
		UI.Gui

	F.Round(
		UI.Main,
		16
	)

	-- Clean, rounded dashboard surface with no accent edge.

	UI.Top =
		Instance.new("Frame")

	UI.Top.Position =
		UDim2.fromOffset(0, 0)

	UI.Top.Size =
		UDim2.new(1, 0, 0, 58)

	UI.Top.BackgroundColor3 =
		T.Topbar

	UI.Top.BackgroundTransparency =
		0

	UI.Top.BorderSizePixel = 0

	UI.Top.Parent =
		UI.Main
		
	F.Round(
		UI.Top,
		16
	)

	UI.Title =
		F.Label(
			UI.Top,
			"for the chosen",
			UDim2.fromOffset(270, 28),
			UDim2.fromOffset(20, 15),
			16
		)

	UI.Title.Font =
		Enum.Font.GothamBold

	UI.Minimize =
		F.Button(
			UI.Top,
			"—",
			UDim2.fromOffset(
				30,
				28
			),
			UDim2.new(
				1,
				-72,
				0,
				17
			)
		)

	UI.Close =
		F.Button(
			UI.Top,
			"×",
			UDim2.fromOffset(
				30,
				28
			),
			UDim2.new(
				1,
				-37,
				0,
				17
			)
		)

	UI.Close.TextColor3 =
		T.RedBright

	UI.Sidebar =
		Instance.new("Frame")

	UI.Sidebar.Position =
		UDim2.fromOffset(0, 58)

	UI.Sidebar.Size =
		UDim2.new(
			0,
			150,
			1,
			-58
		)

	UI.Sidebar.BackgroundColor3 =
		T.Sidebar

	UI.Sidebar.BackgroundTransparency =
		0

	UI.Sidebar.BorderSizePixel = 0

	UI.Sidebar.Parent =
		UI.Main
		
	F.Round(
		UI.Sidebar,
		16
	)

	UI.Content =
		Instance.new("Frame")

	UI.Content.Position =
		UDim2.fromOffset(
			162,
			78
		)

	UI.Content.Size =
		UDim2.new(
			1,
			-174,
			1,
			-90
		)

	UI.Content.BackgroundTransparency = 1
	UI.Content.ClipsDescendants = true

	UI.Content.Parent =
		UI.Main

	UI.Pages = {}
	UI.Nav = {}

	UI.Mode =
		Instance.new("TextLabel")

	UI.Mode.Size =
		UDim2.fromOffset(
			126,
			34
		)

	UI.Mode.Position =
		UDim2.new(
			0,
			12,
			1,
			-52
		)

	UI.Mode.BackgroundColor3 =
		T.Panel

	UI.Mode.BorderSizePixel = 0

	UI.Mode.Text =
		"MODE / IDLE"

	UI.Mode.TextColor3 =
		T.Muted

	UI.Mode.TextSize = 9

	UI.Mode.Font =
		Enum.Font.GothamBold

	UI.Mode.Parent =
		UI.Sidebar

	F.Round(
		UI.Mode,
		7
	)

	F.Stroke(
		UI.Mode
	)
end

--========================================================
-- PAGE SYSTEM
--========================================================

function F.MakePage(Name)
	local Page =
		Instance.new("Frame")

	Page.Size =
		UDim2.fromScale(
			1,
			1
		)

	Page.BackgroundTransparency = 1
	Page.Visible = false

	Page.Parent =
		UI.Content

	UI.Pages[Name] =
		Page

	return Page
end

function F.ShowPage(Name)
	for PageName, Page in pairs(
		UI.Pages
	) do
		Page.Visible =
			PageName == Name
	end

	for ButtonName, Data in pairs(
		UI.Nav
	) do
		local Active =
			ButtonName == Name

		Data.Button.BackgroundColor3 =
			Active
			and T.RedDeep
			or T.Sidebar

		Data.Button.TextColor3 =
			Active
			and T.RedBright
			or T.Muted

		Data.Bar.Visible =
			Active
	end
end

function F.MakeNav(
	Name,
	Text,
	Y
)
	local Button =
		Instance.new("TextButton")

	Button.Size =
		UDim2.fromOffset(
			126,
			38
		)

	Button.Position =
		UDim2.fromOffset(
			12,
			Y
		)

	Button.BackgroundColor3 =
		T.Sidebar

	Button.BorderSizePixel = 0

	Button.Text =
		"   " .. Text

	Button.TextColor3 =
		T.Muted

	Button.TextSize = 10

	Button.TextXAlignment =
		Enum.TextXAlignment.Left

	Button.Font =
		Enum.Font.GothamBold

	Button.AutoButtonColor = false

	Button.Parent =
		UI.Sidebar

	F.Round(
		Button,
		7
	)

	local Bar =
		Instance.new("Frame")

	Bar.Size =
		UDim2.fromOffset(
			3,
			22
		)

	Bar.Position =
		UDim2.fromOffset(
			0,
			8
		)

	Bar.BackgroundColor3 =
		T.Red

	Bar.BorderSizePixel = 0
	Bar.Visible = false

	Bar.Parent =
		Button

	F.Round(
		Bar,
		2
	)

	Button.MouseButton1Click:
	Connect(function()
		F.ShowPage(Name)
	end)

	UI.Nav[Name] = {
		Button = Button,
		Bar = Bar
	}
end

--========================================================
-- STATUS PAGE
--========================================================

function F.BuildStatusPage()
	UI.StatusPage =
		F.MakePage("Status")

	local Header =
		F.Label(
			UI.StatusPage,
			"Runtime overview",
			UDim2.fromOffset(
				360,
				26
			),
			UDim2.fromOffset(
				0,
				0
			),
			18
		)

	Header.Font =
		Enum.Font.GothamBold

	F.Label(
		UI.StatusPage,
		"Live state for targeting, weapons and input.",
		UDim2.fromOffset(
			450,
			18
		),
		UDim2.fromOffset(
			0,
			28
		),
		9,
		T.Muted
	)

	local function StatusCard(
		X,
		Y,
		W,
		H
	)
		local Frame =
			Instance.new("Frame")

		Frame.Position =
			UDim2.fromOffset(
				X,
				Y
			)

		Frame.Size =
			UDim2.fromOffset(
				W,
				H
			)

		Frame.BackgroundColor3 =
			T.Card

		Frame.BackgroundTransparency =
			0.05

		Frame.BorderSizePixel = 0

		Frame.Parent =
			UI.StatusPage

		F.Round(Frame, 9)
		F.Stroke(Frame)

		local Text =
			F.Label(
				Frame,
				"",
				UDim2.new(
					1,
					-20,
					1,
					-20
				),
				UDim2.fromOffset(
					10,
					10
				),
				11
			)

		Text.TextWrapped = true

		return Text
	end

	UI.CameraLockStatus =
		StatusCard(
			0,
			62,
			264,
			74
		)

	UI.TriggerStatus =
		StatusCard(
			274,
			62,
			264,
			74
		)

	UI.TargetStatus =
		StatusCard(
			0,
			146,
			264,
			74
		)

	UI.ToolStatus =
		StatusCard(
			274,
			146,
			264,
			74
		)

	UI.SequenceStatus =
		StatusCard(
			0,
			230,
			538,
			74
		)

	local LogFrame =
		Instance.new("Frame")

	LogFrame.Position =
		UDim2.fromOffset(
			0,
			314
		)

	LogFrame.Size =
		UDim2.fromOffset(
			538,
			130
		)

	LogFrame.BackgroundColor3 =
		T.Card

	LogFrame.BackgroundTransparency =
		0.05

	LogFrame.BorderSizePixel = 0

	LogFrame.Parent =
		UI.StatusPage

	F.Round(LogFrame, 9)
	F.Stroke(LogFrame)

	F.Label(
		LogFrame,
		"RECENT EVENTS",
		UDim2.fromOffset(
			180,
			18
		),
		UDim2.fromOffset(
			11,
			8
		),
		9,
		T.Muted
	)

	UI.Log =
		F.Label(
			LogFrame,
			"",
			UDim2.new(
				1,
				-22,
				0,
				92
			),
			UDim2.fromOffset(
				11,
				29
			),
			10
		)

	UI.Log.Font =
		Enum.Font.Code

	UI.Log.TextYAlignment =
		Enum.TextYAlignment.Top
end

--========================================================
-- SEQUENCE PAGE
--========================================================

function F.BuildSequencePage()
	UI.SequencePage =
		F.MakePage("Sequence")

	UI.SequenceScroll =
		F.Scroll(
			UI.SequencePage
		)

	local Order = 0

	local function Next()
		Order += 1
		return Order
	end

	local Header =
		Instance.new("Frame")

	Header.LayoutOrder =
		Next()

	Header.Size =
		UDim2.new(
			1,
			0,
			0,
			52
		)

	Header.BackgroundTransparency = 1

	Header.Parent =
		UI.SequenceScroll

	local HeaderText =
		F.Label(
			Header,
			"Trigger control",
			UDim2.fromOffset(
				350,
				24
			),
			UDim2.fromOffset(
				0,
				0
			),
			18
		)

	HeaderText.Font =
		Enum.Font.GothamBold

	F.Label(
		Header,
		"Aim at a selected target inside the square to trigger. Equip REV yourself; Q aims.",
		UDim2.new(
			1,
			0,
			0,
			18
		),
		UDim2.fromOffset(
			0,
			29
		),
		9,
		T.Muted
	)

	local function Section(Text)
		local Frame =
			Instance.new("Frame")

		Frame.LayoutOrder =
			Next()

		Frame.Size =
			UDim2.new(
				1,
				0,
				0,
				32
			)

		Frame.BackgroundTransparency = 1

		Frame.Parent =
			UI.SequenceScroll

		local Label =
			F.Label(
				Frame,
				Text,
				UDim2.new(
					1,
					0,
					1,
					0
				),
				UDim2.new(),
				10,
				T.RedBright
			)

		Label.Font =
			Enum.Font.GothamBold

		return Frame
	end

	local function TriggerCard(
		Title,
		Description
	)
		local Frame =
			F.Card(
				UI.SequenceScroll,
				94
			)

		Frame.LayoutOrder =
			Next()

		Frame.BackgroundTransparency =
			0.04

		local TitleLabel =
			F.Label(
				Frame,
				Title,
				UDim2.new(
					1,
					-250,
					0,
					22
				),
				UDim2.fromOffset(
					16,
					13
				),
				12
			)

		TitleLabel.Font =
			Enum.Font.GothamBold

		local DescriptionLabel =
			F.Label(
				Frame,
				Description,
				UDim2.new(
					1,
					-245,
					0,
					42
				),
				UDim2.fromOffset(
					16,
					40
				),
				9,
				T.Muted
			)

		DescriptionLabel.TextWrapped = true

		local State =
			F.Button(
				Frame,
				"OFF",
				UDim2.fromOffset(
					74,
					26
				),
				UDim2.new(
					1,
					-226,
					0,
					34
				)
			)

		local Key =
			F.Button(
				Frame,
				"",
				UDim2.fromOffset(
					128,
					34
				),
				UDim2.new(
					1,
					-143,
					0,
					30
				)
			)

		return {
			State = State,
			Key = Key
		}
	end

	Section("TRIGGER MODES")

	UI.SequentialMode =
		TriggerCard(
			"Sequential trigger",
			"Automatically equips and fires one configured weapon. Multi-gun switching is disabled."
		)

	UI.UniversalMode =
		TriggerCard(
			"Universal trigger",
			"T toggles fire. Auto DB + TAC below 50; manually equip REV for 50–245."
		)

	UI.SequentialMode.State.Parent.Visible = false

	local LegacyUniversalSection = Section("UNIVERSAL WEAPON")
	LegacyUniversalSection.Visible = false

	local UniversalCard =
		F.Card(
			UI.SequenceScroll,
			72
		)

	UniversalCard.LayoutOrder =
		Next()
	UniversalCard.Visible = false

	UI.UniversalMapping =
		F.Label(
			UniversalCard,
			"",
			UDim2.fromOffset(
				330,
				22
			),
			UDim2.fromOffset(
				14,
				25
			),
			10,
			T.Muted
		)

	UI.UniversalBind =
		F.Button(
			UniversalCard,
			"",
			UDim2.fromOffset(
				130,
				34
			),
			UDim2.new(
				1,
				-145,
				0,
				19
			)
		)

	local SequentialWeaponSection =
		Section("SEQUENTIAL WEAPON")

	-- Removed from the visible GUI at the user's request.
	-- The hierarchy/objects stay intact so existing runtime references remain safe.
	SequentialWeaponSection.Visible = false

	UI.SequenceRows = {}

	for Index = 1, 3 do
		local Frame =
			F.Card(
				UI.SequenceScroll,
				70
			)

		Frame.LayoutOrder =
			Next()

		local Badge =
			Instance.new("TextLabel")

		Badge.Size =
			UDim2.fromOffset(
				36,
				36
			)

		Badge.Position =
			UDim2.fromOffset(
				12,
				17
			)

		Badge.BackgroundColor3 =
			T.RedDark

		Badge.BorderSizePixel = 0

		Badge.Text =
			tostring(Index)

		Badge.TextColor3 =
			T.RedBright

		Badge.TextSize = 13

		Badge.Font =
			Enum.Font.GothamBold

		Badge.Parent =
			Frame

		F.Round(Badge, 8)

		local Mapping =
			F.Label(
				Frame,
				"",
				UDim2.fromOffset(
					340,
					20
				),
				UDim2.fromOffset(
					62,
					26
				),
				10,
				T.Muted
			)

		local Bind =
			F.Button(
				Frame,
				"",
				UDim2.fromOffset(
					130,
					34
				),
				UDim2.new(
					1,
					-145,
					0,
					18
				)
			)

		UI.SequenceRows[Index] = {
			Frame = Frame,
			Mapping = Mapping,
			Bind = Bind
		}

		-- Sequential weapon mapping cards are intentionally hidden.
		Frame.Visible = false
	end

	local Buttons =
		Instance.new("Frame")

	Buttons.LayoutOrder =
		Next()

	Buttons.Size =
		UDim2.new(
			1,
			0,
			0,
			42
		)

	Buttons.BackgroundTransparency = 1

	Buttons.Parent =
		UI.SequenceScroll

	-- Preserve the existing GUI hierarchy, but hide the old multi-gun
	-- add/remove controls because the gun macro has been removed.
	Buttons.Visible = false

	UI.AddWeapon =
		F.Button(
			Buttons,
			"",
			UDim2.fromOffset(
				155,
				34
			),
			UDim2.fromOffset(
				0,
				4
			)
		)

	UI.AddWeapon.TextColor3 =
		T.RedBright

	UI.RemoveWeapon =
		F.Button(
			Buttons,
			"",
			UDim2.fromOffset(
				155,
				34
			),
			UDim2.fromOffset(
				165,
				4
			)
		)

	local Info =
		F.Card(
			UI.SequenceScroll,
			68
		)

	Info.LayoutOrder =
		Next()

	Info.BackgroundColor3 =
		T.RedDeep

	-- Hide the old Sequential/Universal mapping summary card.
	Info.Visible = false

	UI.SequenceInfo =
		F.Label(
			Info,
			"",
			UDim2.new(
				1,
				-24,
				1,
				-20
			),
			UDim2.fromOffset(
				12,
				10
			),
			9,
			T.Muted
		)

	UI.SequenceInfo.TextWrapped = true
end

--========================================================
-- TARGETS PAGE
-- Triggerbot + CameraLock are restricted to this selection.
--========================================================

function F.RefreshTargetsPage()
	if St.Cleaned or not UI.TargetsScroll then
		return
	end

	for _, Object in ipairs(
		UI.TargetsScroll:GetChildren()
	) do
		if Object.Name
			== "TargetPlayerRow" then

			Object:Destroy()
		end
	end

	if UI.TargetSelectionStatus then
		local Count =
			F.SelectedTargetCount()

		UI.TargetSelectionStatus.Text =
			"SELECTED / "
			.. tostring(Count)
	end

	local Players = {}

	for _, Player in ipairs(
		S.Players:GetPlayers()
	) do
		if Player ~= S.Player then
			table.insert(
				Players,
				Player
			)
		end
	end

	table.sort(
		Players,
		function(A, B)
			return string.lower(
				A.DisplayName
			) < string.lower(
				B.DisplayName
			)
		end
	)

	local BaseOrder = 10

	for Index, Player in ipairs(
		Players
	) do
		local Row =
			F.Card(
				UI.TargetsScroll,
				64
			)

		Row.Name =
			"TargetPlayerRow"

		Row.LayoutOrder =
			BaseOrder + Index

		local Display =
			F.Label(
				Row,
				Player.DisplayName,
				UDim2.new(
					1,
					-150,
					0,
					20
				),
				UDim2.fromOffset(
					14,
					10
				),
				11
			)

		Display.Font =
			Enum.Font.GothamSemibold

		F.Label(
			Row,
			"@" .. Player.Name,
			UDim2.new(
				1,
				-150,
				0,
				18
			),
			UDim2.fromOffset(
				14,
				34
			),
			9,
			T.Muted
		)

		local Selected =
			F.TargetSelected(
				Player
			)

		local Select =
			F.Button(
				Row,
				Selected
				and "SELECTED"
				or "SELECT",
				UDim2.fromOffset(
					112,
					32
				),
				UDim2.new(
					1,
					-126,
					0,
					16
				)
			)

		Select.TextColor3 =
			Selected
			and T.Green
			or T.Text

		if Selected then
			Row.BackgroundColor3 =
				T.RedDeep
		else
			Row.BackgroundColor3 =
				T.Card
		end

		Select.MouseButton1Click:
		Connect(function()
			F.SetTargetSelected(
				Player,
				not F.TargetSelected(
					Player
				)
			)
		end)
	end
end

function F.BuildTargetsPage()
	UI.TargetsPage =
		F.MakePage("Targets")

	UI.TargetsScroll =
		F.Scroll(
			UI.TargetsPage
		)

	local Header =
		Instance.new("Frame")

	Header.LayoutOrder = 1

	Header.Size =
		UDim2.new(
			1,
			0,
			0,
			58
		)

	Header.BackgroundTransparency = 1
	Header.Parent = UI.TargetsScroll

	local HeaderText =
		F.Label(
			Header,
			"Target selection",
			UDim2.fromOffset(
				300,
				24
			),
			UDim2.fromOffset(
				0,
				0
			),
			18
		)

	HeaderText.Font =
		Enum.Font.GothamBold

	F.Label(
		Header,
		"Selected targets are remembered by UserId. CameraLock picks the best selected target once, then stays locked until that target becomes invalid.",
		UDim2.new(
			1,
			0,
			0,
			18
		),
		UDim2.fromOffset(
			0,
			30
		),
		9,
		T.Muted
	)

	local Controls =
		F.Card(
			UI.TargetsScroll,
			60
		)

	Controls.Name =
		"TargetControls"

	Controls.LayoutOrder = 2

	UI.TargetSelectionStatus =
		F.Label(
			Controls,
			"SELECTED / 0",
			UDim2.fromOffset(
				150,
				22
			),
			UDim2.fromOffset(
				14,
				19
			),
			10,
			T.Muted
		)

	UI.TargetSelectionStatus.Font =
		Enum.Font.GothamBold

	local SelectAll =
		F.Button(
			Controls,
			"SELECT ALL",
			UDim2.fromOffset(
				112,
				32
			),
			UDim2.new(
				1,
				-238,
				0,
				14
			)
		)

	local Clear =
		F.Button(
			Controls,
			"CLEAR",
			UDim2.fromOffset(
				102,
				32
			),
			UDim2.new(
				1,
				-116,
				0,
				14
			)
		)

	SelectAll.MouseButton1Click:
	Connect(function()
		F.SelectAllTargets()
	end)

	Clear.MouseButton1Click:
	Connect(function()
		F.ClearSelectedTargets()
	end)

	if St.TargetPlayerAddedConnection then
		St.TargetPlayerAddedConnection:
			Disconnect()
	end

	if St.TargetPlayerRemovingConnection then
		St.TargetPlayerRemovingConnection:
			Disconnect()
	end

	St.TargetPlayerAddedConnection =
		F.Connect(S.Players.PlayerAdded, function(Player)
			task.defer(function()
				if St.Cleaned then return end
				F.RefreshTargetsPage()

				if F.TargetSelected(
					Player
				) then

					F.Log(
						Player.Name
						.. " rejoined / target restored"
					)
				end

				if F.Refresh then
					F.Refresh()
				end
			end)
		end)

	St.TargetPlayerRemovingConnection =
		F.Connect(S.Players.PlayerRemoving, function(Player)
			-- Deliberately keep St.SelectedTargets[UserId].
			-- If this same account rejoins, F.TargetSelected() will
			-- immediately recognize the same UserId as selected.
			if St.CameraLockTarget
				== Player.Character then

				St.CameraLockTarget = nil
			end

			task.defer(function()
				if St.Cleaned then return end
				F.RefreshTargetsPage()

				if F.Refresh then
					F.Refresh()
				end
			end)
		end)

	F.RefreshTargetsPage()
end

--========================================================
-- SETTINGS PAGE
--========================================================

function F.BuildSettingsPage()
	UI.SettingsPage =
		F.MakePage("Settings")

	UI.SettingsScroll =
		F.Scroll(
			UI.SettingsPage
		)

	UI.SettingRefreshers = {}

	local Order = 0

	local function Next()
		Order += 1
		return Order
	end

	local function Section(Text)
		local Frame =
			Instance.new("Frame")

		Frame.LayoutOrder =
			Next()

		Frame.Size =
			UDim2.new(
				1,
				0,
				0,
				32
			)

		Frame.BackgroundTransparency = 1

		Frame.Parent =
			UI.SettingsScroll

		local Label =
			F.Label(
				Frame,
				Text,
				UDim2.new(
					1,
					0,
					1,
					0
				),
				UDim2.new(),
				10,
				T.RedBright
			)

		Label.Font =
			Enum.Font.GothamBold
	end

	local function SettingCard(
		Name,
		Description
	)
		local Frame =
			F.Card(
				UI.SettingsScroll,
				66
			)

		Frame.LayoutOrder =
			Next()

		local NameLabel =
			F.Label(
				Frame,
				Name,
				UDim2.fromOffset(
					320,
					20
				),
				UDim2.fromOffset(
					13,
					10
				),
				11
			)

		NameLabel.Font =
			Enum.Font.GothamSemibold

		local DescriptionLabel = F.Label(
			Frame,
			Description,
			UDim2.new(
				1,
				-180,
				0,
				24
			),
			UDim2.fromOffset(
				13,
				35
			),
			9,
			T.Muted
		)

		DescriptionLabel.TextWrapped = true
		DescriptionLabel.TextYAlignment = Enum.TextYAlignment.Top

		return Frame
	end

	local function NumberSetting(
		Name,
		Description,
		Get,
		Set,
		Min,
		Max,
		Suffix
	)
		local Frame =
			SettingCard(
				Name,
				Description
			)

		local Box =
			Instance.new("TextBox")

		Box.Size =
			UDim2.fromOffset(
				130,
				34
			)

		Box.Position =
			UDim2.new(
				1,
				-145,
				0,
				16
			)

		Box.BackgroundColor3 =
			T.Panel2

		Box.BorderSizePixel = 0

		Box.TextColor3 =
			T.Text

		Box.TextSize = 11

		Box.Font =
			Enum.Font.GothamSemibold

		Box.ClearTextOnFocus = true

		Box.Parent =
			Frame

		F.Round(Box, 7)
		F.Stroke(Box)

		local function Refresh()
			if not Box:IsFocused() then
				Box.Text =
					tostring(Get())
					.. (Suffix or "")
			end
		end

		table.insert(
			UI.SettingRefreshers,
			Refresh
		)

		Box.FocusLost:Connect(function()
			local Raw =
				string.gsub(
					Box.Text,
					"[^%d%.%-]",
					""
				)

			local Value = F.FiniteNumber(Raw)

			if Value then
				Set(
					math.clamp(
						Value,
						Min,
						Max
					)
				)
			end

			Refresh()
			F.RefreshSequence()
		end)

		Refresh()
		return Box
	end

	local function ToggleSetting(
		Name,
		Description,
		Get,
		Set
	)
		local Frame =
			SettingCard(
				Name,
				Description
			)

		local Toggle =
			F.Button(
				Frame,
				"",
				UDim2.fromOffset(
					92,
					34
				),
				UDim2.new(
					1,
					-107,
					0,
					16
				)
			)

		local function Refresh()
			if Get() then
				Toggle.Text =
					"ENABLED"

				Toggle.TextColor3 =
					T.RedBright

				Toggle.BackgroundColor3 =
					T.RedDark
			else
				Toggle.Text =
					"OFF"

				Toggle.TextColor3 =
					T.Muted

				Toggle.BackgroundColor3 =
					T.Panel2
			end
		end

		table.insert(
			UI.SettingRefreshers,
			Refresh
		)

		Toggle.MouseButton1Click:
		Connect(function()
			Set(
				not Get()
			)

			Refresh()
		end)

		Refresh()

		return Frame
	end

	local function KeySetting(
		Name,
		Description,
		Get,
		Set
	)
		local Frame =
			SettingCard(
				Name,
				Description
			)

		local KeyButton =
			F.Button(
				Frame,
				"",
				UDim2.fromOffset(
					130,
					34
				),
				UDim2.new(
					1,
					-145,
					0,
					16
				)
			)

		local function Refresh()
			if not (
				St.KeyCapture
				and St.KeyCapture.Button
				== KeyButton
			) then

				KeyButton.Text =
					Get().Name

				KeyButton.TextColor3 =
					T.Text
			end
		end

		table.insert(
			UI.SettingRefreshers,
			Refresh
		)

		KeyButton.MouseButton1Click:
		Connect(function()
			if St.SlotCapture then
				return
			end

			St.KeyCapture = {
				Button = KeyButton,

				Set = function(Key)
					Set(Key)
				end
			}

			KeyButton.Text =
				"PRESS KEY"

			KeyButton.TextColor3 =
				T.Yellow
		end)
	end

	Section("KEYBINDS")

	KeySetting(
		"DB + TAC key",
		"Activates both guns once per press; requires dual-equip support.",
		function() return C.DualFireKey end,
		function(Key) F.SetKey("DualFireKey", Key) end
	)

	KeySetting(
		"CameraLock key",
		"Toggles CameraLock. The camera follows the selected target's body.",
		function()
			return C.CameraLockKey
		end,
		function(Key)
			F.SetKey("CameraLockKey", Key)
		end
	)

	KeySetting(
		"Menu key",
		"Opens and closes the menu.",
		function()
			return C.MenuKey
		end,
		function(Key)
			F.SetKey("MenuKey", Key)
		end
	)

	KeySetting(
		"Streamer mode",
		"Toggles streamer mode.",
		function()
			return C.StreamerKey
		end,
		function(Key)
			F.SetKey("StreamerKey", Key)
		end
	)

	KeySetting(
		"Panic key",
		"Disables runtime systems and hides the GUI.",
		function()
			return C.PanicKey
		end,
		function(Key)
			F.SetKey("PanicKey", Key)
		end
	)

	KeySetting(
		"Speed key",
		"Toggles the local walk-speed override.",
		function()
			return C.SpeedKey
		end,
		function(Key)
			F.SetKey("SpeedKey", Key)
		end
	)


	KeySetting(
		"Aim assist key",
		"Toggles local camera aim assist for selected targets.",
		function()
			return C.AimAssistKey
		end,
		function(Key)
			F.SetKey("AimAssistKey", Key)
		end
	)

	Section("DB + TAC TIMING")
	NumberSetting(
		"Pair repeat delay",
		"Optional extra delay between pairs. At 0, the guns control recovery.",
		function() return math.floor(C.DualFireCooldown * 1000 + 0.5) end,
		function(Value) C.DualFireCooldown = Value / 1000 end,
		0, 3000, " ms"
	)
	NumberSetting(
		"Pair equip delay",
		"Allows both weapon scripts to finish equipping.",
		function() return math.floor(C.DualFireEquipDelay * 1000 + 0.5) end,
		function(Value) C.DualFireEquipDelay = Value / 1000 end,
		0, 1000, " ms"
	)
	Section("INPUT BEHAVIOR")

	ToggleSetting(
		"Hold CameraLock",
		"CameraLock stays active only while its key is held.",
		function()
			return C.HoldCameraLock
		end,
		function(Value)
			C.HoldCameraLock = Value
			F.DisableCameraLock()
		end
	)

	local HoldSequentialCard =
		ToggleSetting(
			"Hold sequential",
			"Sequential trigger stays active only while held.",
			function()
				return C.HoldSequential
			end,
			function(Value)
				C.HoldSequential =
					Value
			end
		)

	-- Removed from the visible Settings GUI.
	HoldSequentialCard.Visible = false

	ToggleSetting(
		"Hold universal",
		"Universal trigger stays active only while held.",
		function()
			return C.HoldUniversal
		end,
		function(Value)
			C.HoldUniversal = Value
			F.DisableUniversal(false)
		end
	)

	Section("AIM ASSIST")

	ToggleSetting(
		"Aim assist",
		"Moves your camera toward a visible selected target inside the FOV.",
		function()
			return St.AimAssist
		end,
		function(Value)
			F.SetAimAssist(Value)
		end
	)

	NumberSetting(
		"Aim FOV radius",
		"Pixel radius around the cursor used for target selection.",
		function()
			return C.AimAssistFOV
		end,
		function(Value)
			C.AimAssistFOV = Value
		end,
		25,
		500,
		" px"
	)

	ToggleSetting(
		"Show aim FOV",
		"Shows the aim-assist circle; green means a valid target is inside.",
		function()
			return C.ShowAimAssistFOV
		end,
		function(Value)
			C.ShowAimAssistFOV = Value
		end
	)

	Section("MOVEMENT")

	ToggleSetting(
		"Speed",
		"Toggles the local walk-speed override.",
		function()
			return St.Speed
		end,
		function(Value)
			F.SetSpeed(Value)
		end
	)

	NumberSetting(
		"Walk speed",
		"WalkSpeed used while Speed is enabled.",
		function()
			return C.WalkSpeed
		end,
		function(Value)
			C.WalkSpeed = Value
			if St.Speed then
				F.ApplySpeed()
			end
		end,
		1,
		100,
		""
	)


	Section("PLAYER ESP")

	ToggleSetting(
		"Player names",
		"Selected targets are red; other crewmates are green. Everyone else is hidden.",
		function()
			return St.NameESPEnabled
		end,
		function(Value)
			St.NameESPEnabled = Value
			F.ApplyNameESPVisibility()
		end
	)

	Section("TRIGGERBOT")

	UI.TriggerFOVControl = ToggleSetting(
		"Trigger FOV",
		"Enable trigger detection within the configured cursor area.",
		function() return C.TriggerFOVEnabled end,
		function(Value) F.SetTriggerFOV(Value) end
	)
	UI.TriggerFOVSizeBox = NumberSetting(
		"Trigger FOV size",
		"Detection area width and height in pixels. Both sides change together.",
		function() return C.TriggerFOVSize end,
		function(Value) F.SetTriggerFOVSize(Value) end,
		20, 1200, " px"
	)
	ToggleSetting(
		"Auto DB + TAC",
		"Empty DB uses TAC. Equip REV: 50–245, or 0–245 if either shotgun is empty.",
		function() return C.RangeAuto end,
		function(Value) F.SetRangeAuto(Value) end
	)

	ToggleSetting(
		"Knife check",
		"Prevents automatic trigger activation while the selected/equipped tool is a knife.",
		function()
			return C.TriggerKnifeCheck
		end,
		function(Value)
			C.TriggerKnifeCheck = Value
		end
	)

	Section("TIMING")

	NumberSetting(
		"Shot cooldown",
		"Minimum delay; frame rate and your tool may limit firing further.",
		function()
			return math.floor(
				C.ShotCooldown
				* 1000
				+ 0.5
			)
		end,
		function(Value)
			C.ShotCooldown =
				Value / 1000
		end,
		1,
		1000,
		" ms"
	)

	NumberSetting(
		"GUI refresh",
		"How often live GUI text refreshes.",
		function()
			return math.floor(
				C.UIRefresh
				* 1000
				+ 0.5
			)
		end,
		function(Value)
			C.UIRefresh =
				Value / 1000
		end,
		50,
		1000,
		" ms"
	)

	Section("MANUAL TOOL RANGE / AUTO MODE USES 1–<50 AND 50–245")

	for _, Name in ipairs({
		"Fallback",
		"Double",
		"Rev",
		"Tac"
	}) do
		NumberSetting(
			Name .. " range",
			"Maximum target distance for this weapon category.",
			function()
				return C.Distance[Name]
			end,
			function(Value)
				C.Distance[Name] =
					Value
			end,
			1,
			5000,
			""
		)
	end
end

--========================================================
-- CONFIG PAGE
--========================================================

function F.BuildConfigPage()
	UI.ConfigPage =
		F.MakePage("Config")

	local Title =
		F.Label(
			UI.ConfigPage,
			"Config transfer",
			UDim2.fromOffset(
				350,
				25
			),
			UDim2.fromOffset(
				0,
				0
			),
			18
		)

	Title.Font =
		Enum.Font.GothamBold

	F.Label(
		UI.ConfigPage,
		"Export settings as JSON or paste a previous config to restore it.",
		UDim2.fromOffset(
			520,
			18
		),
		UDim2.fromOffset(
			0,
			28
		),
		9,
		T.Muted
	)

	local Card =
		Instance.new("Frame")

	Card.Position =
		UDim2.fromOffset(
			0,
			62
		)

	Card.Size =
		UDim2.new(
			1,
			0,
			1,
			-63
		)

	Card.BackgroundColor3 =
		T.Card

	Card.BorderSizePixel = 0

	Card.Parent =
		UI.ConfigPage

	F.Round(Card, 9)
	F.Stroke(Card)

	UI.ConfigBox =
		Instance.new("TextBox")

	UI.ConfigBox.Position =
		UDim2.fromOffset(
			12,
			14
		)

	UI.ConfigBox.Size =
		UDim2.new(
			1,
			-24,
			1,
			-78
		)

	UI.ConfigBox.BackgroundColor3 =
		T.BG

	UI.ConfigBox.BorderSizePixel = 0

	UI.ConfigBox.Text = ""

	UI.ConfigBox.PlaceholderText =
		"Export JSON here or paste a config to import."

	UI.ConfigBox.PlaceholderColor3 =
		T.Muted

	UI.ConfigBox.TextColor3 =
		T.Text

	UI.ConfigBox.TextSize = 10
	UI.ConfigBox.Font = Enum.Font.Code

	UI.ConfigBox.TextXAlignment =
		Enum.TextXAlignment.Left

	UI.ConfigBox.TextYAlignment =
		Enum.TextYAlignment.Top

	UI.ConfigBox.TextWrapped = true
	UI.ConfigBox.MultiLine = true
	UI.ConfigBox.ClearTextOnFocus = false

	UI.ConfigBox.Parent =
		Card

	F.Round(UI.ConfigBox, 7)
	F.Stroke(UI.ConfigBox)

	local Export =
		F.Button(
			Card,
			"EXPORT",
			UDim2.fromOffset(
				120,
				34
			),
			UDim2.new(
				0,
				12,
				1,
				-48
			)
		)

	Export.TextColor3 =
		T.RedBright

	local Import =
		F.Button(
			Card,
			"IMPORT",
			UDim2.fromOffset(
				120,
				34
			),
			UDim2.new(
				0,
				142,
				1,
				-48
			)
		)

	local Clear =
		F.Button(
			Card,
			"CLEAR",
			UDim2.fromOffset(
				90,
				34
			),
			UDim2.new(
				0,
				272,
				1,
				-48
			)
		)

	UI.ConfigState =
		F.Label(
			Card,
			"Ready",
			UDim2.fromOffset(
				150,
				34
			),
			UDim2.new(
				1,
				-165,
				1,
				-48
			),
			9,
			T.Muted
		)

	UI.ConfigState.TextXAlignment =
		Enum.TextXAlignment.Right

	Export.MouseButton1Click:
	Connect(function()
		UI.ConfigBox.Text =
			F.ExportConfig()

		UI.ConfigState.Text =
			"Exported"

		UI.ConfigState.TextColor3 =
			T.Green

		F.Log(
			"Config exported"
		)
	end)

	Import.MouseButton1Click:
	Connect(function()
		local Success, Message =
			F.ImportConfig(
				UI.ConfigBox.Text
			)

		UI.ConfigState.Text =
			Message

		UI.ConfigState.TextColor3 =
			Success
			and T.Green
			or T.RedBright

		if Success then
			for _, Refresh in ipairs(
				UI.SettingRefreshers
				or {}
			) do
				Refresh()
			end

			F.Log(
				"Config imported"
			)
		end
	end)

	Clear.MouseButton1Click:
	Connect(function()
		UI.ConfigBox.Text = ""

		UI.ConfigState.Text =
			"Cleared"

		UI.ConfigState.TextColor3 =
			T.Muted
	end)
end

--========================================================
-- BUILD UI
--========================================================

function F.BuildUI()
	F.BuildBaseUI()

	F.MakeNav(
		"Status",
		"STATUS",
		52
	)

	F.MakeNav(
		"Sequence",
		"TRIGGER",
		96
	)

	F.MakeNav(
		"Settings",
		"SETTINGS",
		140
	)

	F.MakeNav(
		"Targets",
		"TARGETS",
		184
	)

	F.MakeNav(
		"Config",
		"CONFIG",
		228
	)

	F.BuildStatusPage()
	F.BuildSequencePage()
	F.BuildSettingsPage()
	F.BuildTargetsPage()
	F.BuildConfigPage()

	F.ShowPage(
		"Status"
	)
end

--========================================================
-- SEQUENCE UI REFRESH
--========================================================

function F.RefreshSequence()
	if St.Cleaned or not St.Ready or not UI.SequenceRows then
		return
	end

	if not (
		St.KeyCapture
		and St.KeyCapture.Button
		== UI.SequentialMode.Key
	) then
		UI.SequentialMode.Key.Text =
			C.SequentialKey.Name

		UI.SequentialMode.Key.TextColor3 =
			T.Text
	end

	if not (
		St.KeyCapture
		and St.KeyCapture.Button
		== UI.UniversalMode.Key
	) then
		UI.UniversalMode.Key.Text =
			C.UniversalKey.Name

		UI.UniversalMode.Key.TextColor3 =
			T.Text
	end

	if St.Sequential then
		UI.SequentialMode.State.Text =
			"ACTIVE"

		UI.SequentialMode.State.TextColor3 =
			T.RedBright

		UI.SequentialMode.State.BackgroundColor3 =
			T.RedDark
	else
		UI.SequentialMode.State.Text =
			"OFF"

		UI.SequentialMode.State.TextColor3 =
			T.Muted

		UI.SequentialMode.State.BackgroundColor3 =
			T.Panel2
	end

	if St.Universal then
		UI.UniversalMode.State.Text =
			"ACTIVE"

		UI.UniversalMode.State.TextColor3 =
			T.RedBright

		UI.UniversalMode.State.BackgroundColor3 =
			T.RedDark
	else
		UI.UniversalMode.State.Text =
			"OFF"

		UI.UniversalMode.State.TextColor3 =
			T.Muted

		UI.UniversalMode.State.BackgroundColor3 =
			T.Panel2
	end

	UI.UniversalMapping.Text =
		"HOTBAR "
		.. tostring(
			C.UniversalSlot
		)
		.. " / "
		.. F.ToolName(
			C.UniversalSlot
		)

	if St.SlotCapture
		and St.SlotCapture.Kind
		== "Universal" then

		UI.UniversalBind.Text =
			"PRESS 1 - 9"

		UI.UniversalBind.TextColor3 =
			T.Yellow
	else
		UI.UniversalBind.Text =
			"KEY "
			.. tostring(
				C.UniversalSlot
			)

		UI.UniversalBind.TextColor3 =
			St.LearnedSlots[
				C.UniversalSlot
			]
			and T.Green
			or T.Text
	end

	for Index = 1, 3 do
		local Row =
			UI.SequenceRows[Index]

		local Active =
			Index == 1

		-- Sequential weapon mapping UI was removed from the visible page.
		Row.Frame.Visible = false

		if Active then
			local Slot =
				St.Sequence[Index]

			Row.Mapping.Text =
				"HOTBAR "
				.. tostring(Slot)
				.. " / "
				.. F.ToolName(Slot)

			if St.SlotCapture
				and St.SlotCapture.Kind
				== "Sequence"
				and St.SlotCapture.Index
				== Index then

				Row.Bind.Text =
					"PRESS 1 - 9"

				Row.Bind.TextColor3 =
					T.Yellow
			else
				Row.Bind.Text =
					"KEY "
					.. tostring(Slot)

				Row.Bind.TextColor3 =
					St.LearnedSlots[Slot]
					and T.Green
					or T.Text
			end
		end
	end

	-- Multi-gun macro controls are kept in the existing hierarchy
	-- but hidden so the rest of the GUI structure is unchanged.
	UI.AddWeapon.Visible = false
	UI.RemoveWeapon.Visible = false

	UI.SequenceInfo.Text =
		"SEQUENTIAL / "
		.. F.SequenceText()
		.. "    •    UNIVERSAL / "
		.. tostring(
			C.UniversalSlot
		)
		.. " / "
		.. F.ToolName(
			C.UniversalSlot
		)
end

--========================================================
-- LIVE UI
--========================================================

function F.Refresh()
	if St.Cleaned or not St.Ready or not UI.Gui then
		return
	end

	UI.CameraLockStatus.Text =
		"CAMERALOCK\n"
		.. (
			St.CameraLock
			and "● ACTIVE"
			or "○ OFF"
		)
		.. "\n"
		.. C.CameraLockKey.Name

	local Mode = "IDLE"

	if St.Sequential then
		Mode = "SEQUENTIAL"

	elseif St.Universal then
		Mode = St.TacFallback and "TAC FALLBACK" or (C.RangeAuto and "RANGE TRIGGER" or "UNIVERSAL")
	end

	UI.Mode.Text =
		"MODE / " .. Mode

	UI.Mode.TextColor3 =
		Mode == "IDLE"
		and T.Muted
		or T.RedBright

	UI.TriggerStatus.Text = "TRIGGER\n"
		.. (St.Universal and "● ON" or "○ OFF") .. (C.RangeAuto and "\nAUTO DB + TAC" or "\nSELECTED TARGETS")

	local Target =
		St.Sequential
		and St.SeqTarget
		or St.UniTarget

	UI.TargetStatus.Text =
		"ACTIVE TARGET\n"
		.. (
			Target
			and Target.Name
			or "none"
		)
		.. "\nSELECTED "
		.. tostring(
			F.SelectedTargetCount()
		)

	local Tool =
		F.EquippedTool()

	UI.ToolStatus.Text =
		"CURRENT TOOL\n"
		.. (
			Tool
			and Tool.Name
			or "none"
		)
		.. "\n"
		.. (
			F.FirstPerson()
			and "first person"
			or "third person"
		)

	UI.SequenceStatus.Text = (C.RangeAuto and "AUTO DB + TAC 1–<50  •  MANUAL EQUIP REV 50–245"
		or C.DualFireKey.Name .. " / DB + TAC once  •  TRIGGER / equipped tool")
		.. "\n" .. C.UniversalKey.Name .. " toggle/hold  •  "
		.. C.PanicKey.Name .. " stop  •  " .. C.MenuKey.Name .. " menu"
	for _, Refresh in ipairs(UI.SettingRefreshers or {}) do Refresh() end

	F.RefreshSequence()
end

--========================================================
-- SEQUENCE UI EVENTS
--========================================================

function F.ConnectSequenceUI()
	UI.UniversalMode.State.MouseButton1Click:Connect(function()
		if St.Universal then F.DisableUniversal(false) else
			if C.HoldUniversal then
				F.Log("Hold " .. C.UniversalKey.Name .. " to enable the trigger")
			else
				F.EnableUniversal()
			end
		end
		F.Refresh()
	end)
	UI.UniversalMode.Key.MouseButton1Click:Connect(function()
		St.KeyCapture = {Button = UI.UniversalMode.Key, Set = function(Key)
			F.SetKey("UniversalKey", Key)
		end}
		UI.UniversalMode.Key.Text = "PRESS KEY"
	end)
end

--========================================================
-- WINDOW / DRAG / MINIMIZE
--========================================================

function F.ConnectWindow()
	local Dragging = false
	local DragStart = nil
	local StartPosition = nil

	UI.Top.InputBegan:
	Connect(function(Input)
		if Input.UserInputType
			== Enum.UserInputType.MouseButton1 then

			Dragging = true

			DragStart =
				Input.Position

			StartPosition =
				UI.Main.Position
		end
	end)

	F.Connect(S.UIS.InputChanged, function(Input)
		if not St.Focused or not St.MenuOpen then Dragging = false end
		if not Dragging then
			return
		end

		if Input.UserInputType
			~= Enum.UserInputType.MouseMovement then

			return
		end

		local Delta =
			Input.Position
			- DragStart

		UI.Main.Position =
			UDim2.new(
				StartPosition.X.Scale,
				StartPosition.X.Offset
				+ Delta.X,

				StartPosition.Y.Scale,
				StartPosition.Y.Offset
				+ Delta.Y
			)
	end)

	F.Connect(S.UIS.InputEnded, function(Input)
		if Input.UserInputType
			== Enum.UserInputType.MouseButton1 then

			Dragging = false
		end
	end)

	UI.Minimized = false

	UI.Minimize.MouseButton1Click:
	Connect(function()
		UI.Minimized =
			not UI.Minimized

		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

		if UI.Minimized then
			UI.Sidebar.Visible = false
			UI.Content.Visible = false

			S.TweenService:Create(UI.Main, tweenInfo, {Size = UDim2.fromOffset(218, 42)}):Play()
			S.TweenService:Create(UI.Top, tweenInfo, {Size = UDim2.new(1, 0, 0, 39)}):Play()

			UI.Title.Position = UDim2.fromOffset(12, 9)
			UI.Title.Size = UDim2.fromOffset(150, 20)
			UI.Title.TextSize = 11

			UI.Minimize.Size = UDim2.fromOffset(23, 23)
			UI.Minimize.Position = UDim2.new(1, -55, 0, 7)

			UI.Close.Size = UDim2.fromOffset(23, 23)
			UI.Close.Position = UDim2.new(1, -27, 0, 7)
		else
			UI.Sidebar.Visible = true
			UI.Content.Visible = true

			S.TweenService:Create(UI.Main, tweenInfo, {Size = UDim2.fromOffset(720, 600)}):Play()
			S.TweenService:Create(UI.Top, tweenInfo, {Size = UDim2.new(1, 0, 0, 58)}):Play()

			UI.Title.Position = UDim2.fromOffset(20, 15)
			UI.Title.Size = UDim2.fromOffset(270, 28)
			UI.Title.TextSize = 16

			UI.Minimize.Size = UDim2.fromOffset(30, 28)
			UI.Minimize.Position = UDim2.new(1, -72, 0, 17)

			UI.Close.Size = UDim2.fromOffset(30, 28)
			UI.Close.Position = UDim2.new(1, -37, 0, 17)
		end
	end)

	UI.Close.MouseButton1Click:Connect(F.Panic)
end

--========================================================
-- CHARACTER AND BACKPACK LIFETIME
--========================================================

function F.BindBackpack(Backpack)
	if St.BackpackConnection then St.BackpackConnection:Disconnect() end
	St.BackpackConnection = nil
	if not Backpack or not Backpack:IsA("Backpack") then return end
	St.BackpackConnection = Backpack.ChildAdded:Connect(function(Object)
		if St.Cleaned then return end
		F.SeedTool(Object)
		F.RefreshSequence()
	end)
	for _, Object in ipairs(Backpack:GetChildren()) do F.SeedTool(Object) end
end

function F.SetupCharacter(Character)
	if St.Cleaned or Character ~= S.Player.Character then return end
	St.CharacterGeneration += 1
	local Generation = St.CharacterGeneration
	F.DisconnectAll(St.CharacterConnections)
	F.EndDualFire()
	F.ReleaseTool()
	St.LocalKO, St.LocalCrouch = nil, nil
	St.CameraLockTarget, St.AimAssistTarget = nil, nil
	St.SeqTarget, St.UniTarget = nil, nil
	St.LastSeqTarget, St.LastUniTarget = nil, nil
	St.LastAimScan = 0
	St.LastUniShot = 0
	St.StateCache[Character] = nil
	F.Connect(Character.DescendantAdded, function(Object)
		St.StateCache[Character] = nil
		if Object:IsA("Tool") then F.SeedTool(Object) end
	end, St.CharacterConnections)
	F.Connect(Character.DescendantRemoving, function()
		St.StateCache[Character] = nil
	end, St.CharacterConnections)
	task.spawn(function()
		local Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 10)
		if St.Cleaned or Generation ~= St.CharacterGeneration or Character ~= S.Player.Character
			or not Humanoid or not Humanoid:IsA("Humanoid") then return end
		F.Connect(Humanoid.Died, function()
			F.PauseInput()
					St.CameraLockTarget = nil
			St.AimAssistTarget = nil
			F.StopTriggerTarget()
		end, St.CharacterConnections)
		F.ApplySpeed()
		F.SeedSlots()
		F.Log("Character ready")
	end)
end

function F.HandleInput(Input, Processed)
	if not St.Ready or not St.Focused or Input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local Key = Input.KeyCode
	if St.KeyCapture then
		local Capture = St.KeyCapture
		St.KeyCapture = nil
		if Key ~= Enum.KeyCode.Escape and Key ~= Enum.KeyCode.Unknown then Capture.Set(Key) end
		F.Refresh()
		return
	end
	
	-- Streamer Mode and Menu toggle check first so they never get eaten by processed flags or focus states
	if Key == C.StreamerKey then F.ToggleStreamerMode(); return end
	if Key == C.MenuKey then F.ToggleMenu(); return end
	if Key == C.PanicKey then F.Panic(); return end

	-- Typing never changes mappings or toggles movement/targeting systems.
	if S.UIS:GetFocusedTextBox() then return end
	if S.GuiService.MenuIsOpen then return end

	local Slot = C.NumberKeys[Key]
	if Slot then F.LearnSlot(Slot) end
	if Key == C.CameraLockKey then
		if St.CameraLock and not C.HoldCameraLock then
			F.DisableCameraLock()
			S.OffSound:Play()
		elseif F.EnableCameraLock() then
			if C.HoldCameraLock then St.HeldCameraKey = Key end
			S.OnSound:Play()
		end
	elseif Key == C.DualFireKey then
		if Processed or St.HeldDualKey then return end
		St.HeldDualKey = Key
		F.BeginDualFire()
	elseif Key == C.UniversalKey then
		if St.Universal and not C.HoldUniversal then F.DisableUniversal(false) else
			F.EnableUniversal()
			if C.HoldUniversal then St.HeldUniversalKey = Key end
		end
	elseif Processed then
		return
	elseif Key == C.AimAssistKey then
		F.SetAimAssist(not St.AimAssist)
	elseif Key == C.SpeedKey then
		F.SetSpeed(not St.Speed)
	end
	F.Refresh()
end

function F.StartRuntime()
	F.Connect(S.UIS.InputBegan, F.HandleInput)
	F.Connect(S.RunService.Heartbeat, function()
		-- Release in the next scheduler phase, including while the GUI/trigger
		-- is stopped. A busy tool's pending release is retried, never activated.
		F.ReleaseTool()
		F.FlushToolReleases()
		F.UpdateDualFire()
		local Now = os.clock()
		if Now - St.LastUI >= C.UIRefresh then
			St.LastUI = Now
			F.Refresh()
		end
	end)
	F.Connect(S.UIS.InputEnded, function(Input)
		if Input.KeyCode == St.HeldDualKey then St.HeldDualKey = nil end
		if Input.KeyCode == St.HeldCameraKey then
			St.HeldCameraKey = nil
			F.DisableCameraLock()
		end
		if Input.KeyCode == St.HeldUniversalKey then
			St.HeldUniversalKey = nil
			F.DisableUniversal(false)
		end
		F.Refresh()
	end)
	F.Connect(S.UIS.WindowFocused, function() St.Focused = true end)
	F.Connect(S.UIS.WindowFocusReleased, function()
		St.Focused = false
		F.PauseInput()
	end)
	F.Connect(S.UIS.TextBoxFocused, F.PauseInput)
	F.Connect(S.GuiService.MenuOpened, F.PauseInput)
	F.Connect(S.Player.CharacterAdded, F.SetupCharacter)
	F.Connect(S.Player.CharacterRemoving, function()
		St.CharacterGeneration += 1
		F.DisconnectAll(St.CharacterConnections)
		F.PauseInput()
			St.CameraLockTarget, St.AimAssistTarget = nil, nil
		F.StopTriggerTarget()
	end)
	F.Connect(S.Player.ChildAdded, function(Object)
		if Object:IsA("Backpack") then F.BindBackpack(Object) end
	end)
	F.BindBackpack(S.Player:FindFirstChildOfClass("Backpack"))
	if S.Player.Character then F.SetupCharacter(S.Player.Character) end
	S.RunService:BindToRenderStep(St.RenderBinding, Enum.RenderPriority.Camera.Value + 1, function()
		F.ApplyNameESPVisibility() -- Ensure ESP updates continuously regardless of menu visibility
		if St.Cleaned or not St.Ready then return end
		F.UpdateCameraLock()
		F.UpdateAimAssist()
		local Character = S.Player.Character
		if not F.CanInteract() or not F.Alive(Character) then
			F.PauseInput()
			F.StopTriggerTarget()
			F.UpdateTriggerFOV()
			return
		end
		if St.Speed then F.ApplySpeed() end
		if not St.Universal or not F.KO(Character) or not F.Crouch(Character) then
			F.StopTriggerTarget()
			F.UpdateTriggerFOV()
			return
		end
		F.UniversalMain()
		F.UpdateTriggerFOV()
	end)
end

--========================================================
-- STARTUP
--========================================================

local Success, Error = xpcall(function()
	St.Runtime = Instance.new("BindableFunction")
	St.Runtime.Name = "for the chosenGuiRuntime"
	St.Runtime.OnInvoke = function() F.Cleanup(); return true end
	St.Runtime.Parent = S.PlayerGui
	F.BuildUI()
	F.ConnectSequenceUI()
	F.ConnectWindow()
	St.Ready = true
	F.StartNameESP()
	F.StartRuntime()
	-- A dynamically loaded chunk may have no Script instance.
	if typeof(script) == "Instance" then
		F.Connect(script.Destroying, F.Cleanup)
	end
	F.RefreshTargetsPage()
	F.Refresh()
	F.Log("for the chosen loaded / client controls ready")
end, debug.traceback)

if not Success then
	F.Cleanup()
	warn("[for the chosen] Startup error:\n" .. tostring(Error))
end
]====], "for the chosensGUI")
if not Run then
    error("for the chosen failed to compile: " .. tostring(CompileError), 0)
end
return Run()