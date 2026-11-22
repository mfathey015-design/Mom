-- ELMASRY VIP  PERFORMANCE BUILD: cached projection, throttled roster, pooled rendering
-- ========================================================================
-- 1. ORIGINAL CHARACTER FEATURES
-- Editable source: src/original_features.lua
-- ========================================================================
-- ========================================================================
-- EXPIRY LICENSE SYSTEM - ELMASRY VIP 
-- ========================================================================
local EXPIRY_DATE = "2026-12-15"   -- تاریخ انقضا (YYYY-MM-DD)
local EXPIRY_MESSAGE = "MOD EXPIRED\nPlease contact ELMASRY VIP  for update."

local function checkExpiry()
    local y, m, d = EXPIRY_DATE:match("(%d+)-(%d+)-(%d+)")
    if not y then return true end
    local expiryTime = os.time({
        year = tonumber(y), month = tonumber(m), day = tonumber(d),
        hour = 23, min = 59, sec = 59
    })
    local now = os.time()
    if now and expiryTime and now > expiryTime then
        return false
    end
    return true
end

if not checkExpiry() then
    -- فقط پیام نمایش داده می‌شود، کد اصلی اجرا نمی‌شود و هیچ خطایی رخ نمی‌دهد
    if ShowNotice then
        ShowNotice(EXPIRY_MESSAGE, nil, 30)
    end
    return  -- خروج تمیز از فایل بدون کرش
end
-- ========================================================================

local CharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {
    "DefaultLuaEventPlaceholder",
    "OnCharacterAnimInstanceInit",
    "OnCharacterAnimInstanceInitFrameDelay",
    "OnProjectileEffect",
    "OnUnmannedVehicleStateChange",
    "OnDSEnterSelfieMode",
    "OnDSExitSelfieMode",
    "EVENTID_CHARACTER_POSSESSED",
    "EVENTID_PAWN_PICK_UP_ITEM",
    "EVENTID_PLAYEREVENT_REVIVAL",
    "EVENTID_INGAME_BUILD_SUCCESS",
    "EVENTID_PLAYEREVENT_SCOPECHANGE",
    "EVENTID_CHARACTER_DIED_PRE",
    "EVENTID_LOCAL_HERO_ID_CHANGED",
    "EVENTID_HERO_ID_CHANGED",
    "EVENTID_INGAME_ON_PAWN_CAMP_CHANGED",
    "EVENTID_TAKE_DAMAGE",
    "EVENTID_PLAYEREVENT_CONSUMEITEM",
    "EVENTID_PLAYEREVENT_DROPITEM"
  }
}
local IngameTipsTools = require("GameLua.Mod.BaseMod.Common.UI.InGameTipsTools")
local BudgetScheduler = require("GameLua.Mod.BaseMod.Common.BudgetScheduler")
local EAvatarSlotType = import("EAvatarSlotType")
local EPawnState = import("EPawnState")
local ECharacterPoseState = import("ECharacterPoseType")
local GameLuaAPI = import("/Script/ShadowTrackerExtra.GameLuaAPI")
local ASTExtraPlayerController = import("/Script/ShadowTrackerExtra.STExtraPlayerController")
local ANewFakePlayerAIController = import("NewFakePlayerAIController")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GameComponentData = require("GameLua.GameCore.Data.GameComponentData")
local GameplayActorData = require("GameLua.GameCore.Data.GameplayActorData")
local EMovementMode = import("EMovementMode")
local ESTEPoseState = import("ESTEPoseState")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local ECharacterHealthStatus = import("ECharacterHealthStatus")
local FHealthPredictShowData = import("HealthPredictShowData")
local ELifetimeCondition = import("ELifetimeCondition")

function _GetItemName(ItemID)
  local ItemConfig = CDataTable.GetTableData("Item", ItemID)
  return ItemConfig and ItemConfig.ItemName or ""
end

CharacterBase.ServerRPC.ServerRPC_FailPreJoinDance = {
  Reliable = true,
  Params = { import("/Script/Engine.Actor") }
}
CharacterBase.ClientRPC.ClientRPC_FailedToJoinDance = {
  Reliable = true,
  Params = { UEnums.EPropertyClass.Int }
}
CharacterBase.ClientRPC.ClientRPC_TryJoinDance = {
  Reliable = true,
  Params = { import("/Script/Engine.Actor"), UEnums.EPropertyClass.Int }
}
CharacterBase.ClientRPC.ClientRPC_ShowEffectAfterFruitBingo = {
  Reliable = true,
  Params = { UEnums.EPropertyClass.Str, UEnums.EPropertyClass.Str, UEnums.EPropertyClass.Int }
}
CharacterBase.ClientRPC.ClientRPC_PlayMontageCamera = {
  Reliable = true,
  Params = {
    import("/Script/CoreUObject.Vector"),
    UEnums.EPropertyClass.Float,
    UEnums.EPropertyClass.Float,
    UEnums.EPropertyClass.Str
  }
}
CharacterBase.MulticastRPC.ShowEffectAfterSelfRescueSucceed = { Reliable = true, Params = {} }
CharacterBase.MulticastRPC.ServerShowShowUIConfigUI = {
  Reliable = true,
  Params = { UEnums.EPropertyClass.Str }
}
CharacterBase.MulticastRPC.MultiCast_GenericRPC = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int,
    { UEnums.EPropertyClass.Array, UEnums.EPropertyClass.Byte }
  }
}

function CharacterBase:ctor(selfType)
  self._SuperData = nil
  self.VehicleParachuteComponent = nil
  self.DefaultNetCullDistanceSq = 1600000000
  self.DiedTime = 0
  self.DiedPosition = FVector(0, 0, 0)
  self.TeammmatePositionWhenMeDied = {}
  self.DefaultFootStep = true
  self.tCorrectionSimulateRepData = { Timer = nil, CurRepLoc = nil, LastRepLoc = nil }
  self.LastAddBuffInstID = 0
  self.LastAddPawn = nil
  self.bDisableProne = false
end

function CharacterBase:GetLifetimeReplicatedProps()
  local RepTable = {
    { "bCableCarView", ELifetimeCondition.COND_None, UEnums.EPropertyClass.Bool },
    { "bIsPlayingLevelSequenceForShow", ELifetimeCondition.COND_None, UEnums.EPropertyClass.Bool },
    { "bCounterattacking", ELifetimeCondition.COND_None, UEnums.EPropertyClass.Bool }
  }
  return RepTable
end

function CharacterBase:_PostConstruct()
  CharacterBase.__super._PostConstruct(self)
  self:AddControlEventWithCondition(self, "OnAttrChangeEventDelegate", {
    AttrName = {
      "bUseDeadBox", "IsInUnderGroundArea", "IsAroundUndergroundEntry",
      "EmotePlayRate", "AreaID", "MapID", "DanceStageAreaState"
    }
  }, self.CharacterAttrChangeEvent, self)
  self:AddControlEvent(self, "OnPawnRespawnDelegate", self.HandleOnRespawn, self)
  self:AddControlEvent(self, "OnParachuteStateChanged", self.LuaHandleParachuteStateChanged, self)
  self:AddControlEvent(self, "OnRepParachuteStateDelegate", self.LuaHandleRepParachuteStateDelegate, self)
  self:AddControlEvent(self, "OnPlayerPoseChange", self.PlayerPoseChange, self)
  self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleAttachedToVehicle, self)
  self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleDetachedFromVehicle, self)
  if not Client then
    self.DefaultNetCullDistanceSq = self.NetCullDistanceSquared
    self.UseNewParachuteMove = false
    self.bIsPlayingLevelSequenceForShow = false
    self:SetNetUpdateGroupID(2)
    self:AddControlEvent(self, "IsEnterNearDeathDelegate", self.HandleServerEnterNearDeathDelegate, self)
    self:AddControlEvent(self, "OnPlayerStartRescue", self.HandleOnPlayerStartRescue, self)
    self:AddControlEvent(self, "StateEnterHandler", self.HandleOnEnterState, self)
    self:AddControlEvent(self, "OnHandleSkillStartDelegate", self.HandleOnSkillStart, self)
  else
    self.bClientCanTriggerSkill = true
    self:AddControlEvent(self, "OnPreRepAttachment", self.HandleOnPreRepAttachment, self)
    self:AddControlEvent(self, "IsEnterNearDeathDelegate", self.HandleIsEnterNearDeathDelegate, self)
    self:AddCommonEvent(EVENTTYPE_APPLICATION_ACTIVE_STATE, EVENTID_APPLICATION_REACTIVATED_EX, self.OnApplicationReactivated, self)
  end
  self:AddControlEvent(self, "OnDeathDelegate", self.HandleDeathDelegate, self)
end

function CharacterBase:OnDestroyed()
  self:Dispose()
  CharacterBase.__super.OnDestroyed(self)
end

function CharacterBase:ReceiveOnPoolCreate() self:ResetAnimInstanceClass() end
function CharacterBase:CharacterIsRecycled() return false end

function CharacterBase:BroadcastFatalDamageInfoWrapperSimpleLua(Causer, Victim, DamageType, AdditionalParam, IsHeadShot)
  local FatalDamageSubsystem = SubsystemMgr:Get("FatalDamageSubsystem")
  if FatalDamageSubsystem then
    FatalDamageSubsystem:BroadcastFatalDamageInfoWrapperSimpleLua(Causer, Victim, DamageType, AdditionalParam, IsHeadShot)
  end
end

function CharacterBase:BroadcastFatalDamageInfoWrapperLua(Causer, Victim, DamageType, AdditionalParam, IsHeadShot, ResultHealthStatus, PreviousHealthStatus, WhoKillMe, KillerKillCount)
  local FatalDamageSubsystem = SubsystemMgr:Get("FatalDamageSubsystem")
  if FatalDamageSubsystem then
    FatalDamageSubsystem:BroadcastFatalDamageInfoWrapperLua(Causer, Victim, DamageType, AdditionalParam, IsHeadShot, ResultHealthStatus, PreviousHealthStatus, WhoKillMe, KillerKillCount)
  end
end

function CharacterBase:OnApplicationReactivated()
  self.FormReactivated = true
end

function CharacterBase:OnClientAddKnownMissingWeapon(ItemDefineID)
  local ItemID = ItemDefineID and ItemDefineID.TypeSpecificID
  if not ItemID or ItemID <= 0 then return end
  local TipsCD = 10
  local UGameplayStatics = import("GameplayStatics")
  local CurrentTime = UGameplayStatics.GetRealTimeSeconds(CGameWorld)
  if 0 <= CurrentTime then
    local LastTime = self.LastMissingWeaponTipsTime
    if type(LastTime) == "number" and CurrentTime >= LastTime and TipsCD > CurrentTime - LastTime then return end
    self.LastMissingWeaponTipsTime = CurrentTime
  end
  local ItemName = _GetItemName(ItemID)
  ShowNotice(LocUtil.LocalizeResFormat(8200003, ItemName), nil, 5)
end

function CharacterBase:HandleOnEnterState(nState)
  if not Client and self.bEnsure == true then
    self:RemoveControlEvent(self.Object, "StateEnterHandler")
    return
  end
  if self:HasAuthority() then
    local EPawnState = import("EPawnState")
    if nState ~= EPawnState.Dying and nState ~= EPawnState.Dead and nState ~= EPawnState.BeCarriedBack and nState ~= EPawnState.Dizziness and nState ~= EPawnState.Knock and nState ~= EPawnState.Arrest then
      local AFKReportorSubsystem = SubsystemMgr:Get("AFKReportorSubsystem")
      if AFKReportorSubsystem then
        local PlayerState = self:GetPlayerStateSafety()
        if PlayerState and slua.isValid(PlayerState) then
          AFKReportorSubsystem:PlayerHaveAction(PlayerState.UID)
        end
      end
    end
  end
end

function CharacterBase:HandleOnSkillStart(uSkillCharacter, SkillID)
  if self:HasAuthority() then
    local AFKReportorSubsystem = SubsystemMgr:Get("AFKReportorSubsystem")
    if AFKReportorSubsystem then
      local PlayerState = self:GetPlayerStateSafety()
      if PlayerState and slua.isValid(PlayerState) then
        AFKReportorSubsystem:PlayerHaveAction(PlayerState.UID)
      end
    end
  end
end

function CharacterBase:HandCharacterDoJump()
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking then
    self.STCharacterMovement.Velocity.Z = self.STCharacterMovement.JumpZVelocity
    self.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_Falling, 0)
    self:RemoveControlEvent(self, "CharacterDoJump")
    self:ServerTriggerJump()
    self:AddControlEvent(self, "CharacterDoJump", self.HandCharacterDoJump, self)
  end
end

function CharacterBase:HandleOnPreRepAttachment(uAttachParent, uAttachComponent, uAttachSocket, uLocationOffset, uRotationOffset, uRelativeScale3D)
  if uAttachParent and slua.isValid(uAttachParent) then
    if not Client.IsEnableDSGrayPublishFlag(2199023255552) or Client.IsEditor() then
      local ASTExtraVehicleBase = import("STExtraVehicleBase")
      if not Game:IsClassOf(uAttachParent, ASTExtraVehicleBase) then return end
      local RelativeLocation = FVector(0, 0, self:GetSimpleCollisionHalfHeightInStandPose())
      local uUseAttachComp
      if slua.isValid(uAttachComponent) then uUseAttachComp = uAttachComponent
      elseif uAttachParent.GetMesh then uUseAttachComp = uAttachParent:GetMesh() end
      local VehicleSeat = uAttachParent:GetVehicleSeats()
      if slua.isValid(VehicleSeat) and slua.isValid(uUseAttachComp) then
        local RealSocketName = VehicleSeat:GetAttachSocketName(self, uUseAttachComp, uAttachSocket)
        if RealSocketName ~= "None" then uAttachSocket = RealSocketName end
      end
      self:SetAttachment(uAttachParent, uUseAttachComp, RelativeLocation, uRotationOffset, uRelativeScale3D, uAttachSocket)
    end
  end
end

function CharacterBase:HandleIsEnterNearDeathDelegate(IsNearDeath)
  if self.HealthStatus == ECharacterHealthStatus.FinishedLastBreath and self.LastHealthStatus == ECharacterHealthStatus.HasLastBreath then
    if slua.isValid(self.Mesh) then
      self:CheckPlayDeadAnimation(self.Mesh.AnimScriptInstance)
      local uAnimInstances = self.Mesh:GetSubAnimInstances()
      for i = 1, uAnimInstances:Num() do
        self:CheckPlayDeadAnimation(uAnimInstances:Get(i - 1))
      end
    end
  end
  local ENetRole = import("ENetRole")
  local EParachuteState = import("EParachuteState")
  if self.Role == ENetRole.ROLE_AutonomousProxy and self.HealthStatus == ECharacterHealthStatus.HasLastBreath and self.ParachuteState == EParachuteState.PS_Opening then
    self:SwitchCameraToParachuteOpening()
  end
  self:ClearFollowEmote()
end

function CharacterBase:HandleServerEnterNearDeathDelegate(IsNearDeath)
  if IsNearDeath then
    local SilentCommunicationSubsystem = SubsystemMgr:Get("SilentCommunicationSubsystem")
    if SilentCommunicationSubsystem then
      SilentCommunicationSubsystem:OnConditionTrigger(1, self:GetPlayerControllerSafety())
    end
  end
end

function CharacterBase:GetSelfRescueSkillID()
  if self:HasState(EPawnState.AttachToOther) then return 0 end
  return 1014669
end

function CharacterBase:HandleOnPlayerStartRescue(RescueWho, IsRescuing)
  if RescueWho and slua.isValid(RescueWho) and RescueWho == self.Object then
    if IsRescuing then
      local uWeaponManager = self:GetWeaponManager()
      if Game:IsValid(uWeaponManager) then uWeaponManager.HideCurrentWeapon = true end
      self.CachedSelfRescueSkillID = self:GetSelfRescueSkillID()
      self:TriggerEntrySkillWithID(self.CachedSelfRescueSkillID, true)
      local PlayerState = self:GetPlayerStateSafety()
      if Game:IsValid(PlayerState) then PlayerState:AddGeneralCount(1121, 1, false) end
    else
      local SkillManager = self:GetSkillManager()
      if SkillManager and slua.isValid(SkillManager) and self.CachedSelfRescueSkillID then
        local UTSkillStopReason = import("UTSkillStopReason")
        SkillManager:StopSkill(self.CachedSelfRescueSkillID, UTSkillStopReason.SkillStopReason_Interrupted)
        self.CachedSelfRescueSkillID = nil
      end
      local uWeaponManager = self:GetWeaponManager()
      if Game:IsValid(uWeaponManager) then uWeaponManager.HideCurrentWeapon = false end
    end
  end
  if IsRescuing then
    local SilentCommunicationSubsystem = SubsystemMgr:Get("SilentCommunicationSubsystem")
    if SilentCommunicationSubsystem then
      SilentCommunicationSubsystem:OnConditionTrigger(2, self:GetPlayerControllerSafety())
    end
  else
    if not slua.isValid(RescueWho) or RescueWho == self.Object then return end
    if RescueWho:HasState(EPawnState.Dying) then return end
    local uController = RescueWho:GetPlayerControllerSafety()
    if not slua.isValid(uController) then return end
    local uPlayerState = uController.PlayerState
    if not slua.isValid(uPlayerState) then return end
    local nKillerPlayerKey = uPlayerState.NearDeathCauserId
    local uKillerPlayerState = GameplayData.GetPlayerState(nKillerPlayerKey)
    if slua.isValid(uKillerPlayerState) and uKillerPlayerState.TeamID == self.TeamID and uPlayerState ~= uKillerPlayerState then return end
    local SilentCommunicationSubsystem = SubsystemMgr:Get("SilentCommunicationSubsystem")
    if SilentCommunicationSubsystem then
      SilentCommunicationSubsystem:OnConditionTrigger(2, uController, uController, 31006, 0, true, nil)
    end
  end
end

function CharacterBase:HandleDeathDelegate()
  if Client then self:ClearFollowEmote() end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement:Deactivate()
    self.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_None, 0)
  end
end

function CharacterBase:GetTargetAnimClass()
  if self.AvatarAnimClassCache ~= nil then return self.AvatarAnimClassCache end
  local uPC = self:GetPlayerControllerSafety()
  if slua.isValid(uPC) then return self.MainCharAnimClass end
  if self:IsInCarryBackState() then
    local uBeCarriedCharacter = self:GetBeCarriedBackCharacter()
    if slua.isValid(uBeCarriedCharacter) and slua.isValid(uBeCarriedCharacter:GetPlayerControllerSafety()) then
      return self.MainCharAnimClass
    end
  end
  return self.MainCharTPPAnimClass
end

function CharacterBase:ResetCharAnimInstanceClass(SetReason, bForceClearOldAnim)
  self.Super:ResetCharAnimInstanceClass(SetReason, bForceClearOldAnim)
end

function CharacterBase:CheckPlayDeadAnimation(uAnimInst)
  if slua.isValid(uAnimInst) and uAnimInst.PlayPlayerDeadAnimation ~= nil and uAnimInst.C_IsNearDeathStatus ~= nil then
    local bResetND = false
    if uAnimInst.C_IsNearDeathStatus == true then
      uAnimInst.C_IsNearDeathStatus = false
      bResetND = true
    end
    local PrePose = uAnimInst.C_PoseType
    uAnimInst.C_PoseType = ECharacterPoseState.ECharPose_Crouch
    uAnimInst:PlayPlayerDeadAnimation()
    if bResetND then uAnimInst.C_IsNearDeathStatus = true end
    uAnimInst.C_PoseType = PrePose
  end
end

function CharacterBase:SetDiedTime()
  self.DiedTime = CGameState:GetServerWorldTimeSeconds()
  local PlayerState = self:GetPlayerStateSafety()
  if PlayerState == nil or slua.isValid(PlayerState) == false or PlayerState.SetDiedTime == nil then return end
  PlayerState:SetDiedTime()
end

function CharacterBase:GetDiedTime() return self.DiedTime or 0 end

function CharacterBase:SetDiedPosition()
  self.DiedPosition = self:K2_GetActorLocation()
  self.TeammmatePositionWhenMeDied = {}
  local CharacterState = self:GetPlayerStateSafety()
  if CharacterState == nil then return end
  local TeammatesState = CharacterState.TeamMatePlayerStateList
  if TeammatesState == nil or TeammatesState:Num() <= 0 then return end
  for index = 0, TeammatesState:Num() - 1 do
    local uTeammatePlayerState = TeammatesState:Get(index)
    if uTeammatePlayerState and slua.isValid(uTeammatePlayerState) and slua.isValid(uTeammatePlayerState.TeamMatePlayerState) then
      local uOtherCharacter = uTeammatePlayerState.TeamMatePlayerState:GetPlayerCharacter()
      if uOtherCharacter and slua.isValid(uOtherCharacter) then
        self.TeammmatePositionWhenMeDied[uOtherCharacter.PlayerKey] = uOtherCharacter:K2_GetActorLocation()
      end
    end
  end
end

function CharacterBase:GetDiedPosition() return self.DiedPosition or FVector(0, 0, 0) end
function CharacterBase:GetTeammatePositionWhenMeDied() return self.TeammmatePositionWhenMeDied end

function CharacterBase:SetDiedPlayerCount()
  local uPlayerState = self:GetPlayerStateSafety()
  if uPlayerState == nil or slua.isValid(uPlayerState) == false then return end
  if uPlayerState.SetDiedPlayerCount == nil then return end
  uPlayerState:SetDiedPlayerCount()
end

function CharacterBase:ReceiveBeginPlay()
  CharacterBase.__super.ReceiveBeginPlay(self)
  GameplayData.BindPlayerCharacter(self.Object)
  BudgetScheduler.Submit(BudgetScheduler.Channel.Init, function()
    if slua.isValid(self.Object) then self.ConditionChangePhysicsAsset(self) end
  end, self.Object, "CharacterBase.ConditionChangePhysicsAsset")
  if Client then
    local AvatarExceptionSubsystem = SubsystemMgr:Get("AvatarExceptionSubsystem")
    if AvatarExceptionSubsystem then AvatarExceptionSubsystem:BindPlayerCharacter(self.Object) end
  end
  if self.LuaReceiveBeginPlay then self:LuaReceiveBeginPlay() end
  self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, { [1] = "FightingState" }, self.HandleEnterGameModeFightingState, self)
  self:CheckInitPlayerDSData()
  if self.DelayResetStandDuration ~= nil and self.DelayHideDuration ~= nil then
    self.DelayResetStandDuration = self.DelayHideDuration
  end
  if self:HasAuthority() and slua.isValid(self.NearDeatchComponent) then
    self:AddControlEvent(self.NearDeatchComponent, "OnPreEnterNearDeath", self.HandleOnPreEnterNearDeath, self)
  end
  if self:IsAutonomousProxy() and slua.isValid(self.STCharacterMovement) then
    self:AddControlEvent(self.STCharacterMovement, "OnClientAdjustPosition", self.HandleOnClientAdjustPosition, self)
    self.STCharacterMovement.ForbiddenMoveCondition.ContinueSeconds = 10
  end
  if CGame:IsEditor() then
    local SecurtyEditorConfig = GamePlayTools.GetCurrentConfig("SecurtyEditorConfig")
    if SecurtyEditorConfig and SecurtyEditorConfig.GameSafeCallbacks then require(SecurtyEditorConfig.GameSafeCallbacks) end
  end
  local UKismetSystemLibrary = import("KismetSystemLibrary")
  if UKismetSystemLibrary.IsDedicatedServer(self) and GameSafeCallbacks then
    GameSafeCallbacks.CharacterReceiveBeginPlay(self)
    self.bSkipComparePropertiesForReplay = true
  end
  if Client then self:AddControlEvent(self, "OnCharacterFallingModeChange", self.HandleCharacterFallingModeChange, self) end
  if self:HasAuthority() then
    local Config = require("GameLua.Mod.BaseMod.DS.Config.SelfRescueConfig")
    if Config then
      if Config.HurtWhenSelfRescue ~= nil then self.HurtWhenSelfRescue = Config.HurtWhenSelfRescue end
      if Config.CoolDownTime ~= nil then self.SelfRescueCoolDownTime = Config.CoolDownTime end
    end
    self:ReplaceGrenadeSkills()
  end
  if self:IsAutonomousProxy() then
    local CurrentVehicle = self:GetCurrentVehicle()
    if slua.isValid(CurrentVehicle) then self:ChangeCurrentVehicle(CurrentVehicle) end
    self:AddControlEvent(self, "OnClientCurrentVehicleChange", self.ChangeCurrentVehicle, self)
    local CurrentShootWeapon = self:GetCurrentShootWeapon()
    if slua.isValid(CurrentShootWeapon) then self:ChangeCurrentWeapon(CurrentShootWeapon) end
    GameComponentData.AddSelfWeaponManagerComponentEvent(self, "ChangeCurrentUsingWeaponDelegate", self.ChangeCurrentWeapon, self)
    GameComponentData.AddSelfWeaponManagerComponentEvent(self, "OnClientAddKnownMissingWeapon", self.OnClientAddKnownMissingWeapon, self)
    if self.ReportCharacterStateTimer then self:RemoveGameTimer(self.ReportCharacterStateTimer) end
    self.ReportCharacterStateTimer = self:AddGameTimer(5.0, true, function() self:ReportCharacterState() end)
  end
  if Client and self:IsAutonomousProxy() then self:RegistAttrModifyRecordList() end
  if Client then
    local uGameState = slua_GameFrontendHUD:GetGameState()
    if uGameState and slua.isValid(uGameState) and uGameState.GetGameModeState and uGameState:GetGameModeState() == "FightingState" then
      local NewObjectPoolLuaBridgeSubsystem = SubsystemMgr:Get("NewObjectPoolLuaBridgeSubsystem")
      if NewObjectPoolLuaBridgeSubsystem then
        NewObjectPoolLuaBridgeSubsystem.SpawnActorCounter_Character = NewObjectPoolLuaBridgeSubsystem.SpawnActorCounter_Character + 1
      end
    end
    if slua.isValid(self.STCharacterMovement) then
      self.STCharacterMovement.MoveSkipTickContinueTime = 2
      self.STCharacterMovement.MoveSkipTickContinueCount = 40
      self.STCharacterMovement.SimulateDelayReceiveLODTheshold = 16
      self.STCharacterMovement.SimulateNotMoveSmoothLODTheshold = 14
    end
    if Client.IsDevelopment() then self:DevelopmentClientCheck() end
    local ENetRole = import("ENetRole")
    if self.Role == ENetRole.ROLE_SimulatedProxy then self:RefreshThermalImagingLocal() end
  end
  if self:HasAuthority() and slua.isValid(self.STCharacterMovement) then
    self:AddControlEvent(self.STCharacterMovement, "OnComponentActivated", self.OnMovementActivated, self)
    self:AddControlEvent(self.STCharacterMovement, "OnResolvePenetrationDelegate", self.HandleOnResolvePenetrationDelegate, self)
  end
  local ENetRole = import("ENetRole")
  if self.Role == ENetRole.ROLE_AutonomousProxy and slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bOpenLocationSmoothOnDynamicMovementBase = false
  end
  self:ShowDoorInteractUIIfNeed()
  if Client then self:AddControlEvent(self, "OnSmartBearerLayerVisibilityChanged", self._OnSmartBearerLayerVisibilityChanged, self) end
end

function CharacterBase:_OnSmartBearerLayerVisibilityChanged(bIsHidden)
  local EMeshVisibleLayer = import("/Script/Engine.EMeshVisibleLayer")
  local ESkeletaTickMode = import("/Script/Engine.ESkeletaTickMode")
  local HackerMesh = self.Mesh
  if slua.isValid(HackerMesh) then
    if bIsHidden then
      HackerMesh:SetLayerVisibilityValue(EMeshVisibleLayer.VisibleLayer_2, false, false)
      HackerMesh:SetTickMode(ESkeletaTickMode.TICK_NONE)
    else
      HackerMesh:SetLayerVisibilityValue(EMeshVisibleLayer.VisibleLayer_2, true, false)
      HackerMesh:SetTickMode(ESkeletaTickMode.TICK_ALL)
    end
  end
end

function CharacterBase:ConditionChangePhysicsAsset()
  if Client then
    local uMyMesh = self.Mesh
    if slua.isValid(uMyMesh) then
      local uMyMeshPhysics = USTExtraBlueprintFunctionLibrary.GetPhysicsAssetFromMesh(uMyMesh)
      if uMyMeshPhysics == self.ShootPhysicsAsset and slua.isValid(self.ShootPhysicsAssetOpt) and uMyMesh.SetPhysicsAsset then
        uMyMesh:SetPhysicsAsset(self.ShootPhysicsAssetOpt, true)
        USTExtraBlueprintFunctionLibrary.CreatePhysicsState(uMyMesh)
      end
    end
  end
end

function CharacterBase:ShowDoorInteractUIIfNeed()
  local ENetRole = import("ENetRole")
  if Client and self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddGameTimer(1, false, function()
      local CapsuleComponent = self and self.CapsuleComponent
      if CapsuleComponent and slua.isValid(CapsuleComponent) then
        local ActorClass = import("/Script/Engine.Actor")
        local PUBGDoorClass = import("PUBGDoor")
        local OverlapActors = CapsuleComponent:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object, ActorClass), PUBGDoorClass)
        if OverlapActors and OverlapActors:Num() > 0 then
          for Index = 0, OverlapActors:Num() - 1 do
            local PUBGDoor = OverlapActors:Get(Index)
            if PUBGDoor and slua.isValid(PUBGDoor) and PUBGDoor.bDoubleDoor == false and PUBGDoor.DoorBroken == false then
              local uHitResult = import("/Script/Engine.HitResult")()
              PUBGDoor:OnBeginOverlap(PUBGDoor.Interaction, self.Object, CapsuleComponent, -1, true, uHitResult)
            end
          end
        end
      end
    end)
  end
end

function CharacterBase:DevelopmentClientCheck()
  if slua.isValid(self.HitBox_Stand) or slua.isValid(self.HitBox_Prone) then
    local UKismetSystemLibrary = import("KismetSystemLibrary")
    if not UKismetSystemLibrary.IsStandalone(slua.getGameInstance()) then
      local Tips = "DevelopmentClientCheck: "
      Tips = Tips .. string.format("Character =  %s ", tostring(self.Object))
      Tips = Tips .. string.format("HitBox_Stand =  %s ", tostring(self.HitBox_Stand))
      Tips = Tips .. string.format("HitBox_Prone =  %s ", tostring(self.HitBox_Prone))
      self:RPC_Server_ShootVertifyFailAlarm(4, Tips)
    end
  end
end

function CharacterBase:IsAutonomousProxy()
  if CharacterBase.__super.IsAutonomousProxy(self) then return true end
  if Client and self.IsLocallyControlled and type(self.IsLocallyControlled) == "function" and self:IsLocallyControlled() then return true end
  return CharacterBase.__super.IsAutonomousProxy(self)
end

function CharacterBase:SetLastAddBuffInst(nInstID, uPawn)
  self.LastAddBuffInstID = nInstID
  self.LastAddPawn = uPawn
end
function CharacterBase:GetLastAddBuffInst() return self.LastAddBuffInstID, self.LastAddPawn end
function CharacterBase:RegistAttrModifyRecordList() end
function CharacterBase:ChangeCurrentVehicle(CurrentVehicle) GameplayActorData.BindSelfActor("CurrentVehicle", CurrentVehicle) end
function CharacterBase:ChangeCurrentWeapon()
  if self.GetCurrentWeapon == nil then return end
  local uWeapon = self:GetCurrentWeapon()
  if slua.isValid(uWeapon) then GameplayActorData.BindSelfActor("CurrentWeapon", uWeapon) end
end

function CharacterBase:HandleOnClientAdjustPosition(NewLocation, Reason)
  if CGameState == nil or not slua.isValid(CGameState) then return end
  if CGameState.GetGameModeState == nil or CGameState:GetGameModeState() == "ReadyState" then return end
  local EReason = import("ECharacterMoveDragReason")
  if Reason == EReason.CMDR_ExceedsDistance and self.PlayerState and self.PlayerState.Ping then
    local bWeakNet = self.PlayerState.Ping * 4 > 250 or false
    if bWeakNet then
      NetUtil.ShowDSTimeOutTipsUI(true, NetUtil.DSTimeOutShort)
      self:AddGameTimer(1, false, function() NetUtil.ShowDSTimeOutTipsUI(false, NetUtil.DSTimeOutShort) end)
    end
  end
end

function CharacterBase:CheckInitPlayerDSData()
  if self:IsAutonomousProxy() then
    if self.PlayerKey ~= nil and self.PlayerKey > 0 then
      self:InitPlayerDsData(self.PlayerKey)
    else
      self:AddControlEvent(self, "OnReceivePlayerKey", self.InitPlayerDsData, self)
    end
  end
end

function CharacterBase:InitPlayerDsData(nPlayerKey)
  if nPlayerKey == nil or nPlayerKey == 0 then return end
  local PlayerEventSubsystem = SubsystemMgr:Get("PlayerEventSystem")
  if PlayerEventSubsystem then PlayerEventSubsystem:CheckInitDSData(nPlayerKey) end
end

function CharacterBase:ReceiveEndPlay(nDeltaSeconds)
  BudgetScheduler.EvictOwner(BudgetScheduler.Channel.Init, self.Object)
  if Client then
    local SKillManager = self:GetSkillManager()
    local CheckWeaponSkillID = 1014405
    if slua.isValid(SKillManager) and SKillManager:GetCurSkillID() == CheckWeaponSkillID then self:StopCurrentLevelSequence() end
    if self.ReportCharacterStateTimer then
      self:RemoveGameTimer(self.ReportCharacterStateTimer)
      self.ReportCharacterStateTimer = nil
    end
  end
  GameplayData.UnbindPlayerCharacter(self.Object)
  if Client then
    local AvatarExceptionSubsystem = SubsystemMgr:Get("AvatarExceptionSubsystem")
    if AvatarExceptionSubsystem then AvatarExceptionSubsystem:UnbindPlayerCharacter(self.Object) end
  end
  if self.PlayerKey ~= nil and self.PlayerKey > 0 then
    EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_CLEAR, self.PlayerKey)
    local PlayerEventSubsystem = SubsystemMgr:Get("PlayerEventSystem")
    if PlayerEventSubsystem then PlayerEventSubsystem:ClearPlayer(self.PlayerKey) end
  end
  self:ClearFollowEmote()
  if not self:HasAuthority() then self:ClearAkEventSound() end
  self._SuperData = nil
  if Client and self._BloodSpotDelegateHandles then
    for sName, Info in pairs(self._BloodSpotDelegateHandles) do
      if type(Info) == "table" then
        local Provider = Info.Provider
        local Handle = Info.Handle
        if Handle then
          if slua.isValid(Provider) then
            local EventDelegate = Provider.AsyncLoadParticleComponentDone
            if slua.isValid(EventDelegate) and EventDelegate.Remove then
              EventDelegate:Remove(Handle)
            else
              slua.removeDelegate(Handle)
            end
          else
            slua.removeDelegate(Handle)
          end
        end
      end
      self._BloodSpotDelegateHandles[sName] = nil
    end
    self._BloodSpotDelegateHandles = nil
  end
  CharacterBase.__super.ReceiveEndPlay(self, nDeltaSeconds)
end

function CharacterBase:GetVehicleParachuteComponent()
  if self.VehicleParachuteComponent == nil then
    local ComponentClass = import("VehicleParachuteComponent")
    self.VehicleParachuteComponent = self:GetComponentByClass(ComponentClass)
  end
  return self.VehicleParachuteComponent
end

function CharacterBase:ReceivePossessed(InController)
  if not slua.isValid(InController) then return end
  self.Super:ReceivePossessed(InController)
  local FeatureUtil = require("GameLua.Mod.BaseMod.GamePlay.Feature.Common.FeatureUtil")
  FeatureUtil.ForEachFeatureCall(self, "ReceivePossessed", InController)
  self:HandleUseGlide(InController)
  self:HandleParachuteComponent(InController)
  self:InitRevivalCount(InController)
  if not Client and not Game:IsAIController(InController) then
    self:RegistAttrModifyRecordList()
  elseif not Client and Game:IsAIController(InController) then
    self.IndoorCheckTime = 2
  end
  local bBatchMove = USTExtraBlueprintFunctionLibrary.IsActorRepMovementWithBatch(self.Object)
  self:RefreshNetUpdateFrequency(bBatchMove)
  if InController and slua.isValid(InController) and InController.RefreshNetUpdateFrequency then
    InController:RefreshNetUpdateFrequency(bBatchMove)
  end
end

function CharacterBase:HandleParachuteComponent(InController)
  if slua.isValid(InController) and slua.isValid(self.ParachuteComponent) then
    if Game:IsClassOf(InController, ASTExtraPlayerController) then
      self.ParachuteComponent:InitParachuteData(InController)
    elseif Game:IsClassOf(InController, ANewFakePlayerAIController) and self.ParachuteComponent.InitAIParachuteData then
      self.ParachuteComponent:InitAIParachuteData(InController)
    end
  end
end

function CharacterBase:InitRevivalCount(InController)
  if not self:HasAuthority() then return end
  local uPlayerState = self:GetPlayerStateSafety()
  if uPlayerState and slua.isValid(uPlayerState) then
    if uPlayerState.InitRevivalCountImpl then
      uPlayerState:InitRevivalCountImpl(InController, self.Object)
    end
  end
end

function CharacterBase:HandleUseGlide(InController)
  if self:HasAuthority() then self:InitParachutingVehicle() end
end

function CharacterBase:HandleEnterGameModeFightingState()
  if slua.isValid(CGameState) and CGameState:IsCreativeMode() then return end
  if self:CharacterIsRecycled() then return end
  if slua.isValid(self.Object) and not self:HasAuthority() and self.EmoteBPIDToAnimHandleMap then
    local CheckTable = { 2206015, 2206016, 2206017, 2206018 }
    for _, ID in pairs(CheckTable) do
      local EmoteHandle = self.EmoteBPIDToAnimHandleMap:Get(ID)
      if slua.isValid(EmoteHandle) and EmoteHandle.EmoteActionList then
        local NeedStop = false
        for _, Action in pairs(EmoteHandle.EmoteActionList) do
          if Action:GetIsExecuting() then NeedStop = true break end
        end
        if NeedStop then self:OnPlayEmoteStop(ID) end
      end
    end
  end
end

function CharacterBase:InitParachutingVehicle()
  if self:HasAuthority() then
    if self.bEnsure then return end
    local ComponentClass = self.DynamicComponentMap:Get("ParachutingVehicle")
    if ComponentClass then
      local UScriptGameplayStatics = import("ScriptGameplayStatics")
      UScriptGameplayStatics.CreateComponent(self, ComponentClass, "ParachutingVehicle", false)
    end
  end
end

function CharacterBase:PlayerPoseChange(stLastPoseState, stNewPoseState)
  if Client and (self.IsClientPeeking and stNewPoseState == ESTEPoseState.Sprint or stNewPoseState == ESTEPoseState.CrouchSprint) then
    self:NM_ForceSetPeekState(false, false)
  end
end

function CharacterBase:HandleAttachedToVehicle(uVehicle)
  if not slua.isValid(uVehicle) then return end
  if slua.isValid(self.CharacterMovement) then self.CharacterMovement:SetBase(nil, "", true) end
  if uVehicle.ForceUseTPP then self.bIsFPPOnVehicle = false end
end

function CharacterBase:HandleDetachedFromVehicle(uLastVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uLastVehicle) then return end
  if uLastVehicle.ForceUseTPP then self.bIsFPPOnVehicle = true end
  if Client then
    local Location = self:K2_GetActorLocation()
    if Location.X > -1.0E-5 and Location.X < 1.0E-5 and -1.0E-5 < Location.Y and 1.0E-5 > Location.Y and -1.0E-5 < Location.Z and 1.0E-5 > Location.Z then
      Location = uLastVehicle:K2_GetActorLocation() + FVector(0, 0, 200)
      self:K2_SetActorLocation(Location, false, nil, true)
    end
  end
end

function CharacterBase:SwitchWeaponBySlotAfterConsume(OldWeaponSlotBeforeSkill)
  local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
  if OldWeaponSlotBeforeSkill == ESurviveWeaponPropSlot.SWPS_HandProp then
    local Controller = self:GetPlayerControllerSafety()
    if not (slua.isValid(Controller) and GameLuaAPI.IsClassOf(Controller, ASTExtraPlayerController)) or not self:AllowState(EPawnState.SwitchWeapon, false) then return end
    if self:HasState(EPawnState.WebSwing) and slua.isValid(self.STCharacterMovement) then
      local ESpecialMovementType = import("ESpecialMovementType")
      local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
      local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
      if slua.isValid(SpiderSwingObj) then
        local nCurState = SpiderSwingObj:GetCurMoveState()
        if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then return end
      end
    end
    Controller:ServerAutoSwitchSameSlotWeapon(OldWeaponSlotBeforeSkill)
  else
    self:SwitchWeaponBySlot(OldWeaponSlotBeforeSkill, true, false, false)
  end
end

function CharacterBase:IsEnablePlayerShovleing()
  return not self:HasState(EPawnState.Prone) and self:HasState(EPawnState.Sprint)
end

function CharacterBase:OnRep_CarryBackStateChanged()
  local uCarryBackComp = self:GetCarryBackComp()
  if slua.isValid(uCarryBackComp) then uCarryBackComp:OnRep_CarryBackStateChanged() end
end

function CharacterBase:ShowCharacter(bShow) self:SetActorHiddenInGame(not bShow) end

function CharacterBase:ShowMainWeaponOnBack(bShow)
  local uWeaponMgrCom = self:GetWeaponManager()
  if uWeaponMgrCom and slua.isValid(uWeaponMgrCom) then uWeaponMgrCom.ShowMainWeaponModelOnBack = bShow end
end

function CharacterBase:AddRevivalCount(nRevivalCount)
  if type(nRevivalCount) == "number" then
    local uPlayerState = self:GetPlayerStateSafety()
    if uPlayerState and slua.isValid(uPlayerState) then
      if uPlayerState.GetRevivalCount and uPlayerState.SetRevivalCount then
        local GeneralRevivalCount = uPlayerState:GetRevivalCount() + nRevivalCount
        if GeneralRevivalCount < 0 then GeneralRevivalCount = 0 end
        uPlayerState:SetRevivalCount(GeneralRevivalCount)
      end
    end
  end
end

function CharacterBase:SetUseDeadBox(bUseDeadBox)
  local eUseDeadBox = 1
  if not bUseDeadBox then eUseDeadBox = 0 end
  self:SetAttrValue("bUseDeadBox", eUseDeadBox, -1)
end

function CharacterBase:GetUseDeadBox()
  local nUseDeadBox = math.floor(self:GetAttrValue("bUseDeadBox") + 0.1)
  return 0 < nUseDeadBox
end

function CharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  if self.Object == uPawn then
    if AttrName == "bUseDeadBox" then
      self.bIsUseDeadBox = self:GetUseDeadBox()
    elseif AttrName == "IsInUnderGroundArea" then
      self.bIsInUnderGroundArea = AttrVal == 1
      if not Client then
        local ESightVisionCondition = import("ESightVisionCondition")
        local USTExtraModLogicSwitchLibrary = import("STExtraModLogicSwitchLibrary")
        if USTExtraModLogicSwitchLibrary.IsNightVisionUnderGroundOnly() then
          self:SetSightCondition(self.bIsInUnderGroundArea, ESightVisionCondition.NightVisionUnderGround)
        end
      end
    elseif AttrName == "IsAroundUndergroundEntry" then
      self.bIsAroundUndergroundEntry = AttrVal == 1
    elseif AttrName == "EmotePlayRate" then
      if Client then
        local PhotoGrapherSubSystem = SubsystemMgr:Get("PhotoGrapherSubSystem")
        if PhotoGrapherSubSystem then PhotoGrapherSubSystem:EmotePlayRateChanged(self.Object, AttrVal) end
      end
    elseif AttrName == "AreaID" then
      self:ChangeFootStepValue(AttrVal)
      self:HandleAreaIDChanged(AttrVal)
      EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER, EVENTID_PLAYEREVENT_LOCAL_CHAR_AREA_ID_CHANGED, AttrVal)
    elseif AttrName == "MapID" then
      if not Client and self:IsAuthority() then
        local uPlayerState = self:GetPlayerStateSafety()
        if slua.isValid(uPlayerState) then uPlayerState.MapID = AttrVal end
      end
    elseif AttrName == "DanceStageAreaState" and Client then
      EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER, EVENTID_PLAYEREVENT_DANCESTATE_CHANGED, AttrVal, self.Object)
    end
  end
end

function CharacterBase:ChangeFootStepValue(AttrVal)
  if self.DefaultFootStep and AttrVal == 0 then return end
  local FootStepSoundConfig = GamePlayTools.GetCurrentConfig("FootStepSoundConfig")
  if not FootStepSoundConfig or not FootStepSoundConfig.bOpenAreaFootStep then return end
  local IntVal = math.tointeger(AttrVal)
  local AreaPara = FootStepSoundConfig[IntVal] or FootStepSoundConfig.DefaultPara
  local DefaultPara = FootStepSoundConfig.DefaultPara
  self.DefaultFootStep = AreaPara == DefaultPara
  self.FloorHeight = AreaPara.FloorHeight or DefaultPara.FloorHeight
  self.GFloorValue = AreaPara.GFloorValue or DefaultPara.GFloorValue
  self.DiffFloorValue = AreaPara.DiffFloorValue or DefaultPara.DiffFloorValue
  self.bInSoundDiffFloorArea = AreaPara.bInSoundDiffFloorArea or DefaultPara.bInSoundDiffFloorArea
end

function CharacterBase:HandleAreaIDChanged(AttrVal) end

function CharacterBase:HandleOnRespawn()
  if self:IsAuthority() then
    EventSystem:postEvent(EVENTTYPE_SECURITY, EVENTID_SECURITY_PLAYER_RESPAWN, self.Object)
  else
    local ENetRole = import("ENetRole")
    local uPlayerController = self:GetPlayerControllerSafety()
    if self:IsAutonomousProxy() then
      local UGameplayStatics = import("GameplayStatics")
      local uGameInstance = UGameplayStatics.GetGameInstance(self)
      if slua.isValid(uGameInstance) then
        local uReplay = uGameInstance:GetClientInGameReplay()
        if slua.isValid(uReplay) and uReplay:IsInRecordState() then uReplay:OnPlayerRespawnNotify() end
      end
      local VibrateUtilitySubsystem = SubsystemMgr:Get("VibrateUtilitySubsystem")
      if VibrateUtilitySubsystem and VibrateUtilitySubsystem.HandleCharacterRespawned then
        VibrateUtilitySubsystem:HandleCharacterRespawned()
      end
      if slua.isValid(uPlayerController) and not uPlayerController:IsPureSpectator() and not uPlayerController:IsDemoPlayGlobalObserver() and not uPlayerController:IsDemoPlaySpectator() then
        uPlayerController:QuitSpectating()
        local uViewTarget = uPlayerController:GetViewTarget()
        if slua.isValid(uViewTarget) and slua.isValid(self.Object) then
          if uViewTarget.Role == ENetRole.ROLE_SimulatedProxy then
            uPlayerController:SetViewTargetTest(self.Object)
          elseif Game:IsClassOf(uViewTarget, slua.loadClass("/Game/Mod/EvoBase/Arts_PlayerBluePrints/Skill/CarryDeadBox/DeadBoxViewTarget.DeadBoxViewTarget")) then
            uPlayerController:SetViewTargetTest(self.Object)
          end
        end
        if uPlayerController:ShouldForceFPPView(self) then
          local EPlayerCameraMode = import("EPlayerCameraMode")
          uPlayerController:SwitchCameraMode(EPlayerCameraMode.PCM_FPP, nil, false, true)
        else
          uPlayerController:SwitchCameraMode(uPlayerController.CurCameraMode, nil, false, true)
        end
      end
      self:AddGameTimer(3, false, function()
        local PlayerRespawnData = slua.IndexReference(self, "PlayerRespawnData")
        if PlayerRespawnData and not PlayerRespawnData.bIsDead and self.CharacterHide and not self.CharacterHide.bCharacterHideIngame and self.bHidden == true and not self:HasState(EPawnState.InPlane) then
          self:SetActorHiddenInGame(false)
        end
      end)
    elseif slua.isValid(self.STCharacterMovement) then
      self.STCharacterMovement.MaxWalkSpeed = 600
    end
    if slua.isValid(uPlayerController) and uPlayerController:IsInSpectating() and uPlayerController:GetLastestViewPlayerKey() == self.PlayerKey then
      uPlayerController:ServerObserveCharacter(self.PlayerKey)
    end
    if slua.isValid(self.STCharacterMovement) then
      self.STCharacterMovement.GravityScale = 1.0
      local uAttachParentActor = self:GetAttachParentActor()
      if slua.isValid(uAttachParentActor) then
        self:CheckAttachedOrDetachedVehicle(true)
        self.STCharacterMovement:Deactivate()
      end
    end
    if self.Role == ENetRole.ROLE_SimulatedProxy then self:RefreshThermalImagingLocal() end
  end
  self:LuaBroadcastCommonEventCpp("EVENTTYPE_PLAYEREVENT_CHARACTER", "EVENTID_PLAYEREVENT_REVIVAL", self.PlayerKey, self.Object, self.TeamID)
end

function CharacterBase:HandleOnPreEnterNearDeath(uKillPlayerController, DamageCauser)
  EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_ON_PRE_ENTER_NEAR_DEATH, self)
  if CGameMode and CGameMode.CheckTeammateAllNearDeath then CGameMode:CheckTeammateAllNearDeath(self.Object) end
end

function CharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  local EParachuteState = import("EParachuteState")
  if not Client then
    if NewParachuteState == EParachuteState.PS_FreeFall or NewParachuteState == EParachuteState.PS_Opening then
      self:SetNetCullDistanceSquared(900000000)
    else
      self:SetNetCullDistanceSquared(self.DefaultNetCullDistanceSq)
    end
  else
    local ENetRole = import("ENetRole")
    if self.Role == ENetRole.ROLE_AutonomousProxy then
      if (NewParachuteState == EParachuteState.PS_FreeFall or NewParachuteState == EParachuteState.PS_Opening) and self.SwimComponet and slua.isValid(self.SwimComponet) then
        self.SwimComponet:LeaveWater()
      end
      if self.Role == ENetRole.ROLE_AutonomousProxy and self.HealthStatus == ECharacterHealthStatus.HasLastBreath and (self.ParachuteState == EParachuteState.PS_Opening or self.ParachuteState == EParachuteState.PS_FreeFall) then
        self:SwitchCameraToParachuteOpening()
      end
      if self.HealthStatus == ECharacterHealthStatus.HasLastBreath and LastParachuteState == EParachuteState.PS_Opening and (NewParachuteState ~= EParachuteState.PS_Opening or NewParachuteState ~= EParachuteState.PS_Landing) then
        local uSpringArmComp = self.SpringArmComp
        if slua.isValid(uSpringArmComp) then
          local CrouchHalfHeight = self:GetCrouchHalfHeight() or 60
          uSpringArmComp:K2_SetRelativeLocation(FVector(0, 0, -CrouchHalfHeight), false, nil, true)
          local ECameraDataType = import("ECameraDataType")
          uSpringArmComp:SetCameraDataEnable(ECameraDataType.ECameraDataType_NearDeath, true)
        end
      end
      EventSystem:postEvent(EVENTTYPE_INGAME_PARACHUTING, EVENTID_CLIENT_PARACHUTE_STATE_CHANGE, LastParachuteState, NewParachuteState)
    end
  end
  if NewParachuteState == EParachuteState.PS_None then
    EventSystem:postEvent(EVENTTYPE_INGAME_PARACHUTING, EVENTID_PARACHUTING_END, self.Object)
  end
end

function CharacterBase:LuaHandleRepParachuteStateDelegate()
  local ENetRole = import("ENetRole")
  local EParachuteState = import("EParachuteState")
  if not (self and self.Role) or not self.ParachuteState then return end
  if self.Role == ENetRole.ROLE_SimulatedProxy and self.ParachuteState == EParachuteState.PS_FreeFall then
    if self.RefreshParacthueAnimTimer then
      self:RemoveGameTimer(self.RefreshParacthueAnimTimer)
      self.RefreshParacthueAnimTimer = nil
    end
    self.RefreshParacthueAnimTimer = self:AddGameTimer(0.5, false, function()
      self:RemoveGameTimer(self.RefreshParacthueAnimTimer)
      self.RefreshParacthueAnimTimer = nil
      if self and slua.isValid(self.Object) then self:TryCacheParachuteAnim() end
    end)
  end
end

function CharacterBase:TryCacheParachuteAnim()
  local uCharacter = self.Object
  if not slua.isValid(uCharacter) or not slua.isValid(uCharacter.Mesh) then return end
  local CH_ABP_Parachute_Class = slua.loadClass("/Game/Arts_Player/Characters/Animation/Base_AnimBP/Feature/CH_ABP_Parachute.CH_ABP_Parachute")
  local uAnimInstances = uCharacter.Mesh:GetSubAnimInstances()
  if uAnimInstances and uAnimInstances.Num then
    local num = uAnimInstances:Num()
    for i = 1, num do
      local uAnimInst = uAnimInstances:Get(i - 1)
      if slua.isValid(uAnimInst) and Game:IsClassOf(uAnimInst, CH_ABP_Parachute_Class) and uAnimInst.CacheParachuteAnimVars ~= nil then
        uAnimInst:CacheParachuteAnimVars(true)
        break
      end
    end
  end
end

function CharacterBase:GetBroadcastFatalDamageExpandData(uCauserPawn, uVictimPawn, RealKiller, DamageType, CauserWeaponAvatarID)
  local expandDataTable = self:GetBroadcastFatalDamageExpandDataForLua(uCauserPawn, uVictimPawn)
  if SubsystemMgr then
    local FatalDamageExpandDataSubsystem = SubsystemMgr:Get("FatalDamageExpandDataSubsystem")
    if FatalDamageExpandDataSubsystem then
      expandDataTable = FatalDamageExpandDataSubsystem:GetBroadcastFatalDamageExpandData(uCauserPawn, uVictimPawn, expandDataTable, RealKiller, DamageType)
    end
  end
  expandDataTable = expandDataTable or {}
  expandDataTable.CauserWeaponAvatarID = CauserWeaponAvatarID or 0
  local expandDataStr = slua.LuaArchiverEncode(LuaStateWrapper, expandDataTable)
  import("/Script/ShadowTrackerExtra.STExtraBaseCharacter").SetExpandDataContent(expandDataStr)
  return expandDataStr
end

function CharacterBase:GetBroadcastFatalDamageExpandDataForLua(uCauserPawn, uVictimPawn)
  local expandDataTable = {}
  if uVictimPawn and slua.isValid(uVictimPawn) then
    expandDataTable.bHaveSelfRescueItem = false
    local PlayerState = uVictimPawn:GetPlayerStateSafety()
    if PlayerState and slua.isValid(PlayerState) then
      if PlayerState.CheckCanSelfRescue then PlayerState:CheckCanSelfRescue() end
    end
    if 0 < uVictimPawn:GetAttrValue("bCanSelfRescue") then expandDataTable.bHaveSelfRescueItem = true end
  end
  return expandDataTable
end

function CharacterBase:ServerCheckEmoteCanPlay(EmoteID)
  if not self:CheckEmoteBanTable(EmoteID) then return false end
  local logic_emote = require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
  if logic_emote.CheckIsDanceTogetherEmote(EmoteID) then
    local EmoteSubSystem = SubsystemMgr:Get("EmoteSubSystem")
    if not EmoteSubSystem:IsInPreListOrDanceList(self.Object) then return false end
  end
  return true
end

function CharacterBase:UpdateEmoteExtraInfo(EmoteID, ExtraInfo)
  if EmoteID == 12220605 then
    math.randomseed(os.time())
    return tostring(math.random(0, 99))
  end
  return ExtraInfo
end

function CharacterBase:CheckEmoteBanTable(EmoteID)
  local EmoteData = CDataTable.GetTableData("BattleBanOnEmote", EmoteID)
  if not EmoteData then return true end
  local uGameState = GameplayData.GetGameState()
  if not slua.isValid(uGameState) or not uGameState.GetGameModeState then return true end
  if uGameState:GetGameModeState() ~= "ReadyState" then return false end
  return true
end

function CharacterBase:ReportExceptionOnVehicle(Type, Msg)
  local ErrorMsg = string.format("VehicleException Type:%s, Msg:%s\n", Type, Msg)
  if Client then
    local ClientToolsReport = require("client.slua.logic.report.ClientToolsReport")
    ClientToolsReport:SendReport(ClientToolsReport.Enum_SvrReport_Type.Enum_Vehicle, ErrorMsg)
  end
  if LogExceptionAndReport ~= nil then LogExceptionAndReport(ErrorMsg) end
end

function CharacterBase:PlayLevelSequenceByPath(SequenceActorPath, LevelSequencePath, TimeOffset)
  return self:PlayLevelSequenceInternal(SequenceActorPath, LevelSequencePath, nil, TimeOffset)
end

function CharacterBase:PlayLevelSequenceByPathAndBindingInfo(SequenceActorPath, LevelSequencePath, TrackBindingInfo, TimeOffset)
  return self:PlayLevelSequenceInternal(SequenceActorPath, LevelSequencePath, TrackBindingInfo, TimeOffset)
end

function CharacterBase:PlayLevelSequenceInternal(SequenceActorPath, LevelSequencePath, TrackBindingInfo, TimeOffset)
  if TimeOffset == nil then TimeOffset = 0 end
  if self.CurrentLevelSequence then self:StopCurrentLevelSequence() end
  local SequenceTransform = FTransform()
  SequenceTransform:SetLocation(self:K2_GetActorLocation())
  local LevelSeqActor = Game:PlayLevelSequence(self, LevelSequencePath, SequenceTransform, SequenceActorPath, false)
  if not slua.isValid(LevelSeqActor) then return false end
  LevelSeqActor:SetOwner(self)
  if LevelSeqActor.SetMetaData then LevelSeqActor:SetMetaData(TrackBindingInfo, TimeOffset) end
  self.CurrentLevelSequence = LevelSeqActor
  return true
end

function CharacterBase:StopCurrentLevelSequence()
  if self.CurrentLevelSequence then
    if slua.isValid(self.CurrentLevelSequence) then
      self.CurrentLevelSequence:StopMontageParticle("DirectorSequence")
      self.CurrentLevelSequence:K2_DestroyActor()
    end
    self.CurrentLevelSequence = nil
  end
end

function CharacterBase:GetCurrentLevelSequenceActor()
  if not slua.isValid(self.CurrentLevelSequence) then return nil end
  return self.CurrentLevelSequence
end

function CharacterBase:OnLevelSequenceStop(StopType)
  if self.CurrentLevelSequence then self.CurrentLevelSequence = nil end
end

function CharacterBase:HandleCharacterFallingModeChange(bFalling)
  if bFalling then return end
  if not slua.isValid(self.Object) then return end
  local uSkillManager = self:GetSkillManager()
  if not slua.isValid(uSkillManager) then return end
  if slua.isValid(self.Object) then
    self:AddGameTimer(0.05, false, function()
      if self.GetCurSkill then
        local uCurSkill = self:GetCurSkill()
        if slua.isValid(uCurSkill) and uSkillManager:IsCastingSkillID(1000001) and uSkillManager:GetSkillCurPhase(uCurSkill) == 1 then
          local UGameplayStatics = import("GameplayStatics")
          local CurTime = UGameplayStatics.GetRealTimeSeconds(CGameWorld)
          if CurTime.LastPlayFallSoundTime > 0.7 then self:PlayFootstepSound(4) end
        end
      end
    end)
  end
end

function CharacterBase:PlayFootstepSound(eFootStepState)
  self.Super:PlayFootstepSound(eFootStepState)
  if not Client then return end
  EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER, EVENTTYPE_PLAYEREVENT_CHARACTER_FOOTSTEP_SOUND, self.Object)
end

function CharacterBase:OnRep_bCableCarView() self:SwitchFreeView(self.bCableCarView) end

function CharacterBase:SwitchFreeView(bEnable)
  if not slua.isValid(self.Object) then return end
  local uSpringArmComp = self.SpringArmComp
  if bEnable then
    self.bFreeView = true
    self.bUseControllerRotationYaw = false
    if slua.isValid(uSpringArmComp) then
      uSpringArmComp.bForceUseTargetArmLength = true
      uSpringArmComp.TargetArmLength = 890
    end
  else
    self.bFreeView = false
    self.bUseControllerRotationYaw = true
    if slua.isValid(uSpringArmComp) then
      uSpringArmComp.bForceUseTargetArmLength = false
      uSpringArmComp.TargetArmLength = 220
    end
  end
end

function CharacterBase:IsEnableFollowPlayEmote() return LobbySystem.CheckOpen(BP_ENUM_DANCE_FOLLOW_SWITCH) end

function CharacterBase:IsInteractiveExpression(EmoteID)
  local ItemCfg = CDataTable.GetTableData("Item", EmoteID)
  if ItemCfg and ItemCfg.ItemSubType == 2205 then return true end
  return false
end

function CharacterBase:CheckCanFollowPlayEmote(EmoteId)
  if not EmoteId or EmoteId == 0 then return false end
  local FollowEmoteCfg = CDataTable.GetTableData("FollowEmoteCfg", EmoteId)
  if FollowEmoteCfg and FollowEmoteCfg.CanPlay == 0 then
    local TipsID = FollowEmoteCfg.TipsID and FollowEmoteCfg.TipsID ~= 0 and FollowEmoteCfg.TipsID or 44697
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then uPlayerController:DisplayGameTipWithMsgID(TipsID) end
    return false
  end
  if self:IsInteractiveExpression(EmoteId) then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then uPlayerController:DisplayGameTipWithMsgID(44697) end
    return false
  end
  local logic_emote = require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
  if logic_emote.IsMileStoneEmote(EmoteId) then return false end
  if logic_emote.IsCustomWeaponShow(EmoteId) then return false end
  return true
end

function CharacterBase:ClearFollowEmote()
  if self:IsAutonomousProxy() then
    if self.GetPlayerControllerSafety then
      local Controller = self:GetPlayerControllerSafety()
      if slua.isValid(Controller) then Controller.OnShowFollowEmoteDelegate:BroadCast(false) end
    end
  end
  if self.ClearEmotePlayer then self:ClearEmotePlayer() end
end

function CharacterBase:ClearAkEventSound()
  local UAkGameplayStatics = import("AkGameplayStatics")
  local EAttachLocation = import("EAttachLocation")
  local Location = FVector(0, 0, 0)
  if slua.isValid(self.RootComponent) and EAttachLocation and Location then
    local uAkComponent = UAkGameplayStatics.GetAkComponent(self.RootComponent, "", Location, EAttachLocation.KeepRelativeOffset)
    if slua.isValid(uAkComponent) then uAkComponent:Stop() end
  end
end

function CharacterBase:ShowEffectAfterSelfRescueSucceed() end

function CharacterBase:ServerShowShowUIConfigUI(uiConfigName)
  if not Client then return end
  local ENetRole = import("ENetRole")
  if UIManager.UI_Config_InGame[uiConfigName] and (self:IsLocalControlorView() or self:IsLocalViewed() or self.Role == ENetRole.ROLE_AutonomousProxy) then
    UIManager.ShowUI(UIManager.UI_Config_InGame[uiConfigName])
  end
end

function CharacterBase:ClientRPC_FailedToJoinDance(Reason) ShowNotice(Reason) end

function CharacterBase:ClientRPC_TryJoinDance(DanceActor, Index)
  if not slua.isValid(DanceActor) then return end
  DanceActor:ClientTryJoinDance(self.Object, Index)
end

function CharacterBase:ClientRPC_ShowEffectAfterFruitBingo(ShakingAudioPath, SurpriseAudioPath, SurpriseTipsID)
  if SurpriseTipsID and 0 < SurpriseTipsID then IngameTipsTools.BattleGeneralTip(SurpriseTipsID) end
  local audio_util = require("client.common.audio_util")
  if ShakingAudioPath and ShakingAudioPath ~= "" then audio_util.PlayAudioByActorAsync(ShakingAudioPath, self.Object) end
  if SurpriseAudioPath and SurpriseAudioPath ~= "" then audio_util.PlayAudioByActorAsync(SurpriseAudioPath, self.Object) end
end

function CharacterBase:ClientRPC_PlayMontageCamera(LookAtLocation, Radius, Time, CallbackName)
  local MontageCameraSubsystem = SubsystemMgr:Get("MontageCameraSubsystem")
  if MontageCameraSubsystem then
    if CallbackName and CallbackName ~= "" and self[CallbackName] and type(self[CallbackName]) == "function" then
      MontageCameraSubsystem:Play(LookAtLocation, Radius, Time, self[CallbackName])
    else
      MontageCameraSubsystem:Play(LookAtLocation, Radius, Time)
    end
  end
end

function CharacterBase:OnPlayMontageCameraCallback() end

function CharacterBase:ServerRPC_FailPreJoinDance(DanceActor)
  if not slua.isValid(DanceActor) then return end
  DanceActor:ServerFailPreJoinDance(self.Object)
end

function CharacterBase:CheckEmoteNeedUseReliableRPC(EmoteIndex)
  local Controller = self:GetPlayerControllerSafety()
  if slua.isValid(Controller) and Controller.PlayEmoteFeature and Controller.PlayEmoteFeature:CheckNeedReliable(EmoteIndex) then return true end
  return false
end

function CharacterBase:RegisteAirControlResumEvent(OldAirControl)
  self:AddControlEvent(self, "OnMovementBaseChanged", function(_, Character, NewMovementBase, OldMovementBase)
    if not slua.isValid(NewMovementBase) then return end
    local CharacterMovement = self.STCharacterMovement
    if not slua.isValid(CharacterMovement) then return end
    CharacterMovement.AirControl = OldAirControl
    self:RemoveControlEvent(self, "OnMovementBaseChanged")
  end, self)
end

function CharacterBase:ReplaceGrenadeSkills()
  local SkillReplaceConfig = GamePlayTools.GetCurrentConfig("SkillReplaceConfig")
  local uSkillMgr = self:GetSkillManager()
  if slua.isValid(uSkillMgr) and SkillReplaceConfig and SkillReplaceConfig.ReplaceSkill then
    for sourceSkill, NewSkill in pairs(SkillReplaceConfig.ReplaceSkill) do
      uSkillMgr:ReplaceSkill(sourceSkill, NewSkill)
    end
  end
end

function CharacterBase:GetGrenadeKillBindGunIDByPC(KillerPC, GrenadeID)
  if Client then return 0 end
  if not slua.isValid(KillerPC) then return 0 end
  local ExtendAttribute = require("Server.config.ExtendAttribute")
  local PlayerDataMgr = require("Server.Data.ServerPlayerDataMgr")
  local GrenadeBindInfo = PlayerDataMgr.GetPlayerProgressFromServer(KillerPC.UID, ExtendAttribute.GrenadeBindWeaponMap)
  if not GrenadeBindInfo then return 0 end
  if GrenadeBindInfo[GrenadeID] ~= nil then return GrenadeBindInfo[GrenadeID] end
  return 0
end

function CharacterBase:CheckIsValidXSuitBornIslandAction(EmoteID)
  local XSuitUtil = require("GameLua.Activity.Commercialize.GamePlay.XSuit.XSuitUtil")
  local uPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(uPlayerController) or not uPlayerController.CommerFeature then return false end
  local uAvatarComp2 = self:getAvatarComponent2()
  if not slua.isValid(uAvatarComp2) then return false end
  local AvatarItem = uAvatarComp2:GetEquippedItemDefineID(EAvatarSlotType.EAvatarSlotType_ClothesEquipemtSlot)
  if XSuitUtil:GetBornIslandActionByItemID(AvatarItem.TypeSpecificID, uAvatarComp2) ~= EmoteID then return false end
  local Period = XSuitUtil:GetPeriodByBattleActionID(EmoteID)
  if Period and 0 < Period then
    local UnLockLevel = XSuitUtil:GetUnLockLevelByFeature(AvatarItem.TypeSpecificID, Period, uPlayerController.CommerFeature.XSuitUnlockLevelList)
    if not XSuitUtil:IsValidBornIslandAction(EmoteID, UnLockLevel) then return false end
  end
  return true
end

function CharacterBase:CheckIsValidEmoteIDBP(EmoteID)
  local IsValid = false
  local Controller = self:GetPlayerControllerSafety()
  if slua.isValid(Controller) and Controller.PlayEmoteFeature then
    IsValid = Controller.PlayEmoteFeature:CheckIsValidEmoteIDBP(EmoteID)
  end
  if not IsValid and self.CoopEmoteCharFeature then
    IsValid = self.CoopEmoteCharFeature:CheckIsValidEmoteIDBP(EmoteID)
  end
  return IsValid
end

function CharacterBase:IsCoopEmote(EmoteId, CoopPhase)
  if self.CoopEmoteCharFeature then return self.CoopEmoteCharFeature:IsCoopEmote(EmoteId, CoopPhase) end
  return false
end

function CharacterBase:ShouldCheckCoopEmote()
  if self.CoopEmoteCharFeature then return self.CoopEmoteCharFeature:ShouldCheckCoopEmote() end
  return false
end

function CharacterBase:ShouldShowCoopEmoteBtn(EmotePlayer)
  if self.CoopEmoteCharFeature then return self.CoopEmoteCharFeature:ShouldShowCoopEmoteBtn(EmotePlayer) end
  return false
end

function CharacterBase:RPC_Client_OnCoopEmotePhaseChange(CoopPhase)
  if self.CoopEmoteCharFeature then self.CoopEmoteCharFeature:HandleClientOnCoopEmotePhaseChange(CoopPhase) end
end

function CharacterBase:RPC_Server_JoinCoopEmote(EmotePlayer)
  local CasterPlayerKey = EmotePlayer.PlayerKey
  if not CasterPlayerKey then return end
  local CoopEmoteSubSystem = SubsystemMgr:Get("CoopEmoteSubSystem")
  if not CoopEmoteSubSystem:HasCaster(CasterPlayerKey) then return end
  self.Super:RPC_Server_JoinCoopEmote(EmotePlayer)
end

function CharacterBase:ServerOnCoopEmotePhaseChange(CoopPhase)
  if self.CoopEmoteCharFeature then self.CoopEmoteCharFeature:HandleServerOnCoopEmotePhaseChange(CoopPhase) end
end

function CharacterBase:CheckInPhotoGrapherMode()
  local PhotoGrapherSubSystem = SubsystemMgr:Get("PhotoGrapherSubSystem")
  if PhotoGrapherSubSystem and PhotoGrapherSubSystem.bIsPhotoGrapherMode then return true end
  return false
end

function CharacterBase:ReportCharacterState()
  if not slua.isValid(self.Object) then return end
  local uPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(uPlayerController) then return end
  if uPlayerController.ReportCharacterStateData then uPlayerController:ReportCharacterStateData() end
end

function CharacterBase:ParseServiceDebugInfo(BasicInfoKeys, DetailInfoKeys)
  if BasicInfoKeys == nil then return end
  local StringUtil = require("common.string_util")
  local InfoMap = {}
  local SpeedStr = string.format("%.3f/%.3f", self:GetVelocity():Size(), self.CharacterMovement.MaxWalkSpeed)
  local PlayerStates = ""
  for i = 0, EPawnState.__MAX do
    if self:HasState(i) then PlayerStates = PlayerStates .. tostring(i) .. "," end
  end
  if BasicInfoKeys and BasicInfoKeys:Num() < 3 then
    local AIDebugInfoConfig = require("GameLua.Mod.BaseMod.DS.AI.AIDebugInfoConfig")
    if AIDebugInfoConfig and AIDebugInfoConfig[2] then
      for _, KeysStr in pairs(AIDebugInfoConfig[2]) do BasicInfoKeys:Add(KeysStr) end
    end
  end
  InfoMap.Level = tostring(self.EnsureLevel)
  InfoMap.Key = tostring(self:GetPlayerKey())
  InfoMap.TeamID = tostring(self.TeamID)
  InfoMap.HP = string.format("%d/%d", math.floor(self.Health), math.floor(self.HealthMax))
  InfoMap.NearDeathBreath = string.format("%.2f", self.NearDeathBreath)
  InfoMap.FreeCamera = tostring(self.SimulateViewData.FreeCamera)
  InfoMap.Speed = SpeedStr
  InfoMap.State = PlayerStates
  InfoMap.Location = self:K2_GetActorLocation():ToString()
  InfoMap.Rotation = self:K2_GetActorRotation():ToString()
  InfoMap.MLAIStyle = tostring(self.MLEnsureStyle)
  InfoMap.TeamInstantiated = tostring(self.TeamInstantiated)
  if self.TeleportID then InfoMap.TeleportID = tostring(self.TeleportID) end
  if self.TargetUID_Debug then InfoMap.Target = tostring(self.TargetUID_Debug) end
  local uPlayerController = GameplayData.GetPlayerController()
  if uPlayerController and slua.isValid(uPlayerController) and slua.isValid(self.Object) then
    local ViewTarget = uPlayerController:GetViewTarget()
    if ViewTarget and slua.isValid(ViewTarget) then
      InfoMap.Distance = string.format("%.0f", Game:GetActorDistance(self.Object, ViewTarget) / 100)
    end
  end
  if self.DebugAIInfoTable then
    for InfoKey, InfoValue in pairs(self.DebugAIInfoTable) do InfoMap[InfoKey] = InfoValue end
  end
  local bHaveEnsureStyle = false
  local DebugInfoArray = StringUtil.Split(self.BehaviorServiceDebugInfo, ";")
  local ExtraInfo = ""
  for index, InfoStr in ipairs(DebugInfoArray) do
    local InfoSplit = StringUtil.Split(InfoStr, "=")
    if not InfoSplit or not InfoSplit[2] then
      ExtraInfo = ExtraInfo .. InfoStr .. "\n"
    elseif Game:Contains(DetailInfoKeys, InfoSplit[1]) and string.find(InfoSplit[2], "=") then
      local InfoSplit2 = StringUtil.Split(InfoSplit[2], "=")
      DetailInfoKeys:Add(InfoSplit2[1])
      InfoMap[InfoSplit2[1]] = InfoSplit2[2]
    else
      InfoMap[InfoSplit[1]] = InfoSplit[2]
      if InfoSplit[1] == "EnsureStyle" then
        self.EnsureStyle = tonumber(InfoSplit[2])
        bHaveEnsureStyle = true
      end
      if bHaveEnsureStyle == false and self.EnsureStyle > 0 and InfoSplit[1] == "ResID" then
        self.EnsureStyle = 0
      end
    end
  end
  local AIType = "CommonAI"
  if self.EnsureStyle == 4 then AIType = "CommonAI_Advance"
  elseif self.EnsureStyle == 1 then AIType = "MLAI"
  elseif self.EnsureStyle == 2 then AIType = "MLAI_Delivery"
  elseif self.EnsureStyle == 3 then AIType = "MLAI_Teammate"
  elseif self.EnsureStyle == 5 then AIType = "MLAI_Humanoid" end
  InfoMap.Type = AIType
  self.ServiceDebugInfoForShow = ""
  local FinnalStr = ""
  local TempStr = ""
  for index, Keys in pairs(BasicInfoKeys) do
    local KeysArr = StringUtil.Split(Keys, ";")
    local EmptyLine = true
    for _, Key in ipairs(KeysArr) do
      if InfoMap[Key] then
        TempStr = string.format("[%s=%s]", Key, InfoMap[Key])
        EmptyLine = false
        FinnalStr = FinnalStr .. TempStr
      end
    end
    if not EmptyLine then FinnalStr = FinnalStr .. "\n" end
  end
  FinnalStr = FinnalStr .. "::"
  for _, Keys in pairs(DetailInfoKeys) do
    local KeysArr = StringUtil.Split(Keys, ";")
    local EmptyLine = true
    for _, Key in ipairs(KeysArr) do
      if InfoMap[Key] then
        TempStr = string.format("[%s=%s]", Key, InfoMap[Key])
        EmptyLine = false
        FinnalStr = FinnalStr .. TempStr
      end
    end
    if not EmptyLine then FinnalStr = FinnalStr .. "\n" end
  end
  FinnalStr = FinnalStr .. ExtraInfo
  self.ServiceDebugInfoForShow = FinnalStr
end

function CharacterBase:SetMLEnsureStyle(InMLStyle)
  local DebugLastMLEnsureStyle_DS = string.format("%d_%.1f", self.MLEnsureStyle, CGameState:GetServerWorldTimeSeconds())
  self:AddDebugAIInfoTable("LastMLAIStyle", DebugLastMLEnsureStyle_DS)
  self.MLEnsureStyle = InMLStyle
  self:DSSetCharacterIntPropertyForReplay("MLEnsureStyle", InMLStyle)
end

function CharacterBase:SetMLEnsureExtraInfo(InMLEnsureExtraInfo)
  self:AddDebugAIInfoTable("MLExtraInfo", InMLEnsureExtraInfo)
  self.MLEnsureExtraInfo = InMLEnsureExtraInfo
  self:DSSetCharacterStringPropertyForReplay("MLEnsureExtraInfo", InMLEnsureExtraInfo)
end

function CharacterBase:GetBodyPartOffset(nBodyPart, CurrentState, nHasWeapon, nPeekState)
  local StaticBodyOffsetData = require("GameLua.Mod.Library.GamePlay.AI.StaticBodyOffsetData")
  local OffsetData = { 0, 0, 0 }
  nHasWeapon = nHasWeapon + 1
  nPeekState = nPeekState + 1
  if StaticBodyOffsetData[CurrentState] and StaticBodyOffsetData[CurrentState][nHasWeapon] and StaticBodyOffsetData[CurrentState][nHasWeapon][nPeekState] then
    OffsetData = StaticBodyOffsetData[CurrentState][nHasWeapon][nPeekState][nBodyPart] or OffsetData
  end
  return FVector(OffsetData[1], OffsetData[2], OffsetData[3])
end

function CharacterBase:BlueprintSetServiceDebugInfo(Info)
  if self.DebugAIInfoTable then
    for _, InfoData in pairs(self.DebugAIInfoTable) do Info = Info .. InfoData end
  end
  return Info
end

function CharacterBase:AddDebugAIInfoTable(Key, StringInfo)
  if not self.DebugAIInfoTable then self.DebugAIInfoTable = {} end
  if Client then
    if Key and StringInfo then self.DebugAIInfoTable[Key] = StringInfo end
  else
    self.DebugAIInfoTable[Key] = string.format("%s=%s;", Key, StringInfo)
  end
end

function CharacterBase:InitIceDecalQueue(MaxNum)
  self.IceDecalQueue = {}
  self.MaxIceDecalQueue = 2 < MaxNum and math.floor(MaxNum) or 2
  self.IceDecalQueuePtr = 0
  for i = 1, self.MaxIceDecalQueue do table.insert(self.IceDecalQueue, false) end
end

function CharacterBase:EnqueueIceDecal(uIceDecalActor)
  if not slua.isValid(uIceDecalActor) then return end
  if self.IceDecalQueue == nil then self:InitIceDecalQueue(3) end
  local CurInsertIdx = self.IceDecalQueuePtr + 1
  if self.IceDecalQueue[CurInsertIdx] and slua.isValid(self.IceDecalQueue[CurInsertIdx]) then
    local uOldActor = self.IceDecalQueue[CurInsertIdx]
    if slua.isValid(uOldActor) then uOldActor:K2_DestroyActor() end
  end
  self.IceDecalQueue[CurInsertIdx] = uIceDecalActor
  self.IceDecalQueuePtr = (self.IceDecalQueuePtr + 1) % self.MaxIceDecalQueue
end

function CharacterBase:BP_ResetDataOnRespawn()
  EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_INGAME_ON_RESET_DATA_ON_RESPAWN, self.Object)
end

function CharacterBase:ToString() return string.format("%s(%s)", self.PlayerName, self.PlayerKey) end

function CharacterBase:LuaTriggerEntrySkillWithID(SkillID, bEnable)
  if not self.bClientCanTriggerSkill then return end
  if self.CharacterUltraHandRepFeature and not self.CharacterUltraHandRepFeature:CanUseUltraHand() then return end
  self:TriggerEntrySkillWithID(SkillID, bEnable)
end

function CharacterBase:SetClientCanTriggerSkill(bCanTriggerSkill) self.bClientCanTriggerSkill = bCanTriggerSkill end

function CharacterBase:SetClothMeshForceLod(bEnable)
  if not self.getAvatarComponent2 then return end
  local AvatarComp = self:getAvatarComponent2()
  if slua.isValid(AvatarComp) then
    AvatarComp:SetForceMeshLod(EAvatarSlotType.EAvatarSlotType_ClothesEquipemtSlot, bEnable)
  end
end

function CharacterBase:InitAddSpecialMoveInfo()
  if not CGame then return end
  local SpecialMoveConfig = GamePlayTools.GetCurrentConfig("SpecialMoveConfig")
  if not SpecialMoveConfig then return end
  for key, value in pairs(SpecialMoveConfig.SpecialMoveObjPathInfos) do
    if type(value) == "string" then
      local ObjMovementC = CGame:LoadOjectFromPath(value)
      if ObjMovementC then
        local ObjName = string.format("SpecialMoveObj_%d", key)
        local ObjMovement = CGame:NewObjectFromClass(self, ObjMovementC, ObjName)
        if ObjMovement and ObjMovement.SpecialMoveSetCharacterOwner then
          ObjMovement:SpecialMoveSetCharacterOwner(self)
          if slua.isValid(self.STCharacterMovement) then
            self.STCharacterMovement.SpecialObjes:Add(key, ObjMovement)
          end
        end
      end
    end
  end
  for key, value in pairs(SpecialMoveConfig.CustomMoveToSpecialMoveTypes) do
    if slua.isValid(self.STCharacterMovement) and type(value) == "number" then
      self.STCharacterMovement.CustomMoveModeToSpecialMoveType:Add(key, value)
    end
  end
  if SpecialMoveConfig.LuaCustomVariants then
    local ESpecialMovementTypeEnum = import("ESpecialMovementType")
    local LuaCustomMoveObj
    if slua.isValid(self.STCharacterMovement) then
      LuaCustomMoveObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementTypeEnum.SPECIAL_MOVE_LuaCustom)
    end
    if LuaCustomMoveObj and LuaCustomMoveObj.RegisterChildVariants then
      LuaCustomMoveObj:RegisterChildVariants(SpecialMoveConfig.LuaCustomVariants)
    end
  end
end

function CharacterBase:AddSpecialMoveInfo(SpecialMovementType, SpecialMovementObj)
  SpecialMovementObj:SpecialMoveSetCharacterOwner(self)
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.SpecialObjes:Add(SpecialMovementType, SpecialMovementObj)
  end
end

function CharacterBase:OnPlayerKeyRepExt()
  EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER, EVENTID_PLAYEREVENT_PLAYERKEY_CHANGE, self.Object)
end

function CharacterBase:OnMovementActivated() end

function CharacterBase:HandleOnResolvePenetrationDelegate(bResolve, OldLoc, NewLoc)
  if bResolve then
    local Actor_C = import("/Script/Engine.Actor")
    local Character_C = import("/Script/Engine.Character")
    local ASTExtraVehicleBase_C = import("STExtraVehicleBase")
    local ASTExtraWeapon_C = import("STExtraWeapon")
    local FHitResult = import("/Script/Engine.HitResult")
    local uIgnoreActorArray = slua.Array(UEnums.EPropertyClass.Object, Actor_C)
    uIgnoreActorArray:Add(self.Object)
    local uWeapon = self:GetCurrentWeapon()
    if slua.isValid(uWeapon) then uIgnoreActorArray:Add(uWeapon) end
    local bIsPasswall = false
    local OutHits = slua.Array(UEnums.EPropertyClass.Struct, FHitResult)
    local HitResult = FHitResult()
    USTExtraBlueprintFunctionLibrary.TraceAllBlocks(OutHits, self.Object, OldLoc, NewLoc, HitResult, uIgnoreActorArray, false)
    local bHasVehicle = false
    if OutHits:Num() > 0 then
      for Index, Hit in pairs(OutHits) do
        local uHitActor = Hit.Actor
        if slua.isValid(uHitActor) then
          if not uHitActor:ActorHasTag("IgnorePassWall") and not uHitActor:ActorHasTag("PenetrationIgnorePassWall") and not Game:IsClassOf(uHitActor, Character_C) and not Game:IsClassOf(uHitActor, ASTExtraVehicleBase_C) and not Game:IsClassOf(uHitActor, ASTExtraWeapon_C) then
            bIsPasswall = true
          elseif Game:IsClassOf(uHitActor, ASTExtraVehicleBase_C) then
            bHasVehicle = true
          else
            uIgnoreActorArray:Add(uHitActor)
          end
        end
      end
    end
    if bHasVehicle then bIsPasswall = bIsPasswall or false end
    if bIsPasswall then
      local ResolveParams = import("/Script/ShadowTrackerExtra.ResolvePenetrationParams")()
      ResolveParams.AdjustRadius = 50
      ResolveParams.bLineTracePassWall = true
      ResolveParams.AdjustMaxHeight = 200
      for i = 0, uIgnoreActorArray:Num() - 1 do
        slua.IndexReference(ResolveParams, "PassWallIgnoreActors"):Add(uIgnoreActorArray:Get(i))
      end
      self:SetActorLocationSafetyWithParams(OldLoc, ResolveParams)
    end
  end
end

function CharacterBase:IsCastingSkillIDFix(InSkillID)
  if not self.GetSkillManager then return false end
  local uSkillManager = self:GetSkillManager()
  if not slua.isValid(uSkillManager) then return false end
  return uSkillManager:IsCastingSkillID(InSkillID)
end

function CharacterBase:RefreshThermalImagingLocal()
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local uPlayerCharacter = GameplayData.GetPlayerCharacter()
  if slua.isValid(uPlayerCharacter) then
    local ESightVisionMask = import("ESightVisionMask")
    local ESightVisionType = import("ESightVisionType")
    if uPlayerCharacter:HasAnySightVision(ESightVisionMask.ThermalImagingScope) then
      local UGameplayStatics = import("GameplayStatics")
      local uGameInstance = UGameplayStatics.GetGameInstance(uPlayerCharacter)
      if slua.isValid(uGameInstance) then
        uGameInstance:RefreshThermalImagingLocal(uPlayerCharacter)
      end
    end
  end
end

function CharacterBase:OnSplineMoveChanged(bEnter) self:HandleEnableMoveLayer(bEnter) end

function CharacterBase:HandleEnableMoveLayer(sEnable)
  local uAnimParamsComp = self:GetAnimParamsComponent()
  if not slua.isValid(uAnimParamsComp) then return end
  local bFPP = self:GetIsFPP()
  local uCharAnimInstance = self:GetCurrentMainLogicAnimInstance(bFPP)
  if slua.isValid(uCharAnimInstance) then
    if sEnable then
      local MoveInstanceClass = uAnimParamsComp:GetCustomizableAnimBP(uCharAnimInstance.FEATURE_MoveAnimInstanceID)
      if MoveInstanceClass then uAnimParamsComp:ActiveAnimContainerWithInstance("AC.Locomotion", MoveInstanceClass, false) end
    else
      uAnimParamsComp:ActiveAnimContainer("AC.Locomotion", true)
    end
  end
end

function CharacterBase:SpawnEmitterEffect(RelativeLocation, PSRef, AttachParent, RelativeScale)
  local KismetMathLibrary = import("KismetMathLibrary")
  local uPlayerController = self:GetPlayerControllerSafety()
  if slua.isValid(uPlayerController) then
    local ScreenAppearanceStatics = import("ScreenAppearanceStatics")
    local uScreenAppearanceActor = ScreenAppearanceStatics.GetScreenAppearanceManager(uPlayerController)
    if slua.isValid(uScreenAppearanceActor) then
      local uBloodSpotProvider, sProviderName
      if self.BloodSpot_Red == PSRef then sProviderName = "BloodSpot_Red"
      else sProviderName = "BloodSpot_Green" end
      uBloodSpotProvider = uScreenAppearanceActor:PlayDefaultScreenAppearance(uPlayerController, sProviderName, nil)
      if slua.isValid(uBloodSpotProvider) then
        local uTransform = KismetMathLibrary.MakeTransform(RelativeLocation, FRotator(0.0, 0.0, 90.0), RelativeScale)
        uBloodSpotProvider:UpdateRelativeTransform(uTransform)
        self.BloodScale = RelativeScale
        local EventDelegate = uBloodSpotProvider.AsyncLoadParticleComponentDone
        if slua.isValid(EventDelegate) and EventDelegate.Add then
          self._BloodSpotDelegateHandles = self._BloodSpotDelegateHandles or {}
          local OldInfo = self._BloodSpotDelegateHandles[sProviderName]
          if OldInfo and OldInfo.Handle then
            local OldProvider = OldInfo.Provider
            if slua.isValid(OldProvider) then
              local OldEventDelegate = OldProvider.AsyncLoadParticleComponentDone
              if slua.isValid(OldEventDelegate) and OldEventDelegate.Remove then
                OldEventDelegate:Remove(OldInfo.Handle)
              else
                slua.removeDelegate(OldInfo.Handle)
              end
            else
              slua.removeDelegate(OldInfo.Handle)
            end
            self._BloodSpotDelegateHandles[sProviderName] = nil
          end
          local DelegateHandle
          DelegateHandle = EventDelegate:Add(function(LoadedParticle)
            if DelegateHandle then
              if slua.isValid(EventDelegate) and EventDelegate.Remove then EventDelegate:Remove(DelegateHandle) end
              if self._BloodSpotDelegateHandles then
                local CurInfo = self._BloodSpotDelegateHandles[sProviderName]
                if CurInfo and CurInfo.Handle == DelegateHandle then self._BloodSpotDelegateHandles[sProviderName] = nil end
              end
              DelegateHandle = nil
            end
            if slua.isValid(LoadedParticle) and slua.isValid(self.Object) then
              self:ChangeParticleEffect(LoadedParticle, self.BloodScale)
            end
          end)
          self._BloodSpotDelegateHandles[sProviderName] = { Provider = uBloodSpotProvider, Handle = DelegateHandle }
        end
      end
    end
  end
end

function CharacterBase:ChangeAllAvatarMaterialToFeatureMaterial(material)
  local uAvatarComp2 = self:getAvatarComponent2()
  if slua.isValid(uAvatarComp2) then uAvatarComp2:ChangeAllMeshToFeatureMaterial(material) end
  local WeaponManager = self:GetWeaponManager()
  if slua.isValid(WeaponManager) then WeaponManager:ChangeAllMeshToFeatureMaterial(material) end
end

function CharacterBase:ClearAllAvatarFeatureMaterial()
  if self.getAvatarComponent2 then
    local uAvatarComp2 = self:getAvatarComponent2()
    if slua.isValid(uAvatarComp2) then uAvatarComp2:ClearAllFeatureMaterial() end
  end
  if self.GetWeaponManager then
    local WeaponManager = self:GetWeaponManager()
    if slua.isValid(WeaponManager) then WeaponManager:ClearAllFeatureMaterial() end
  end
end

function CharacterBase:CheckParachuteLandShouldUseSkill()
  local UKismetSystemLibrary = import("KismetSystemLibrary")
  local uPawnFor = self:GetActorForwardVector()
  local uPawnLoc = self:K2_GetActorLocation()
  local uForVec2D = uPawnFor:GetSafeNormal2D(1.0E-6)
  local EndPath = uPawnLoc + uForVec2D * 200
  local uHitResult = import("/Script/Engine.HitResult")()
  local EDrawDebugTrace = import("EDrawDebugTrace")
  local ActorClass = import("/Script/Engine.Actor")
  local ActorsToIgnore = slua.Array(UEnums.EPropertyClass.Object, ActorClass)
  local bHit = UKismetSystemLibrary.LineTraceSingle(self.Object, uPawnLoc, EndPath, 6, true, ActorsToIgnore, EDrawDebugTrace.None, uHitResult, true, FLinearColor.Red, FLinearColor.Green, 1)
  if bHit then return false end
  return true
end

function CharacterBase:IsOverlappingWithArea(TargetActor)
  local Result = false
  local AreaActor
  local DSReviveSubsystem = SubsystemMgr:Get("DSReviveSubsystem")
  local POIGeneralAreaClass = slua.loadClass("/Game/Mod/EvoBase/BluePrints/Actor/BaseLevelEnterArea.BaseLevelEnterArea")
  local uAreaList = self:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object, import("/Script/Engine.Actor")), POIGeneralAreaClass)
  for _, uArea in pairs(uAreaList) do
    if slua.isValid(uArea) and (TargetActor == nil or TargetActor == uArea) and DSReviveSubsystem.POIAreaRegisteredInfo[uArea] and uArea.CheckPlayerCanSelfRevive then
      if uArea:CheckPlayerCanSelfRevive(self.Object) then Result = true AreaActor = uArea break end
    end
  end
  return Result, AreaActor
end

function CharacterBase:IsOverlappingIgnoringArea(TargetActor)
  local Result = false
  local AreaActor
  local DSReviveSubsystem = SubsystemMgr:Get("DSReviveSubsystem")
  local POIGeneralAreaClass = slua.loadClass("/Game/Mod/EvoBase/BluePrints/Actor/BaseLevelEnterArea.BaseLevelEnterArea")
  local uAreaList = self:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object, import("/Script/Engine.Actor")), POIGeneralAreaClass)
  for _, uArea in pairs(uAreaList) do
    if slua.isValid(uArea) and TargetActor ~= uArea and DSReviveSubsystem.POIAreaRegisteredInfo[uArea] and uArea.CheckPlayerCanSelfRevive then
      if uArea:CheckPlayerCanSelfRevive(self.Object) then Result = true AreaActor = uArea break end
    end
  end
  return Result, AreaActor
end

function CharacterBase:UpdatePOIReviveAreaID(uExcludeArea)
  local uAreaList = self:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object, import("/Script/Engine.Actor")), import("/Script/Engine.Actor"))
  for _, uArea in pairs(uAreaList) do
    if slua.isValid(uArea) and uArea ~= uExcludeArea and uArea.HandleSetReviveState ~= nil and uArea:HandleSetReviveState(uArea, true) then return true end
  end
  return false
end

function CharacterBase:OnServerSpectatorKickFromGame()
  local CarryBackComp = self:GetCarryBackComp()
  local hasBeCarryBack = self:HasState(EPawnState.BeCarriedBack)
  local hasCarryBack = self:HasState(EPawnState.Carryback)
  if slua.isValid(CarryBackComp) then
    if hasBeCarryBack then
      local CarryBackCharOfKickPlayer = CarryBackComp.CarryBackCharacter
      if slua.isValid(CarryBackCharOfKickPlayer) then
        local CarryBackCharOfKickPlayerComp = CarryBackCharOfKickPlayer:GetCarryBackComp()
        if slua.isValid(CarryBackCharOfKickPlayerComp) then CarryBackCharOfKickPlayerComp:RPC_ServerManualBreakCarryBackState() end
      end
    end
    if hasCarryBack then CarryBackComp:RPC_ServerManualBreakCarryBackState() end
  end
end

function CharacterBase:GetPhysicsType()
  local nPhysicsType = 0
  local USTExtraGameInstance = import("STExtraGameInstance")
  local uGameInstance = USTExtraGameInstance.GetInstance()
  if slua.isValid(uGameInstance) then
    local ModType = uGameInstance.ModType
    local ModType2 = uGameInstance.ModType2
    if ModType == "Escape" or ModType2 == "Escape" then
      if self.HeroPropFeature and self.HeroPropFeature:GetCurrentHeroID() ~= nil then nPhysicsType = 2 end
    elseif (ModType == "Halloween4" or ModType2 == "Halloween4") and self.HeroPropFeature then
      if self.HeroPropFeature:GetCurrentHeroID() ~= nil then nPhysicsType = 1 end
    end
  end
  return nPhysicsType
end

function CharacterBase:ActivateCharacterMovement()
  if not slua.isValid(self.CharacterMovement) then return end
  local ENetRole = import("ENetRole")
  self:SetReplicateMovement(true)
  if Client then self.bReplicateMovement = true end
  self.CharacterMovement:SetMovementMode(EMovementMode.MOVE_Walking, 0)
  self.CharacterMovement:Activate(false)
  self.CharacterMovement:SetComponentTickEnabled(true)
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    local UGameplayStatics = import("GameplayStatics")
    self.CharacterMovement:SetClientReceiveServerStateTimestamp(UGameplayStatics.GetTimeSeconds(CGameWorld))
  elseif self.Role == ENetRole.ROLE_Authority then
    self.CharacterMovement:ForceNetUpdate()
  end
  self.CharacterMovement.bForbidActiveWhenAttachParent = true
end

function CharacterBase:DeactivateCharacterMovement(bForce)
  if not slua.isValid(self.CharacterMovement) then return end
  if bForce then self.CharacterMovement.bForbidActiveWhenAttachParent = false end
  self:SetReplicateMovement(false)
  if not Client then self.CharacterMovement:SetMovementMode(EMovementMode.MOVE_None, 0) end
  self.CharacterMovement:Deactivate()
  self.CharacterMovement:SetComponentTickEnabled(false)
  if Client then
    local uController = slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(uController) and uController:IsSpectator() then
      self.CharacterMovement:ResetSimulateMoveCaches(false)
    end
  end
end

function CharacterBase:MultiCast_GenericRPC(ID, Bytes)
  local GenericRPCEnums = require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCEnums")
  local GenericRPCUtil = require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCUtil")
  GenericRPCUtil._OnRecv(self, ID, GenericRPCEnums.EGenericRPCDirection.Multicast, Bytes)
end

-- ========================================================================
-- 1.5 PREMIUM STYLE HELPERS (ported from 1.lua — HackerPremiumUI)
-- Rainbow borders, glassmorphism, floating particles, neon glows
-- ========================================================================

local HackerPremiumStyle = (function()
    local Style = {}
    local COLORS = {
        NEON_PINK   = {1.0, 0.1, 0.6},
        NEON_CYAN   = {0.0, 0.9, 1.0},
        NEON_PURPLE = {0.6, 0.2, 1.0},
        NEON_GREEN  = {0.1, 1.0, 0.4},
        NEON_ORANGE = {1.0, 0.5, 0.0},
        NEON_YELLOW = {1.0, 0.9, 0.0},
    }
    function Style.rainbow(offset, alpha)
        local r = math.sin(offset + 0)       * 0.5 + 0.5
        local g = math.sin(offset + 2.094)   * 0.5 + 0.5
        local b = math.sin(offset + 4.188)   * 0.5 + 0.5
        return r, g, b, alpha or 1.0
    end
    function Style.glow(d, x, y, size, intensity, r, g, b)
        for i = 3, 1, -1 do
            local glowSize  = size + (i * 4)
            local glowAlpha = intensity * (0.2 * i)
            d.circle(x, y, glowSize, r, g, b, glowAlpha * 0.3, true)
        end
    end
    function Style.animatedBorder(d, x, y, w, h, thickness, time)
        local segments = 20
        local segW = w / segments
        for i = 0, segments - 1 do
            local r, g, b = Style.rainbow(time * 2 + i * 0.3)
            local alpha = 0.6 + 0.4 * math.sin(time * 3 + i * 0.5)
            d.rect(x + i * segW, y,                     segW, thickness, r, g, b, alpha, true)
            d.rect(x + i * segW, y + h - thickness,     segW, thickness, r, g, b, alpha, true)
        end
        local segmentsH = math.max(1, math.floor(h / (w / segments)))
        for i = 0, segmentsH - 1 do
            local r, g, b = Style.rainbow(time * 2 + i * 0.3 + 1)
            local alpha = 0.6 + 0.4 * math.sin(time * 3 + i * 0.5 + 1)
            d.rect(x,                 y + i * (w / segments), thickness, w / segments, r, g, b, alpha, true)
            d.rect(x + w - thickness, y + i * (w / segments), thickness, w / segments, r, g, b, alpha, true)
        end
    end
    function Style.initParticles(count)
        local list = {}
        for i = 1, count do
            list[#list + 1] = {
                x     = math.random(),
                y     = math.random(),
                size  = math.random(2, 6),
                speed = math.random(10, 30) / 100,
                color = math.random(1, 6),
                alpha = math.random(30, 80) / 100,
            }
        end
        return list
    end
    function Style.drawParticles(d, w, h, time, particles)
        local set = { COLORS.NEON_PINK, COLORS.NEON_CYAN, COLORS.NEON_PURPLE,
                      COLORS.NEON_GREEN, COLORS.NEON_ORANGE, COLORS.NEON_YELLOW }
        for _, p in ipairs(particles) do
            local px = (p.x * w + math.sin(time * p.speed * 2) * 20) % w
            local py = (p.y * h + time * p.speed * 50) % h
            local c  = set[p.color]
            local pulse = 0.5 + 0.5 * math.sin(time * 2 + p.x * 10)
            d.circle(px, py, p.size * pulse, c[1], c[2], c[3], p.alpha * pulse * 0.5, true)
        end
    end
    function Style.drawGrid(d, w, h, time)
        local gridSize = 40
        local offset   = (time * 20) % gridSize
        for i = 0, w, gridSize do
            local a = 0.03 + 0.02 * math.sin(time + i * 0.01)
            d.line(i + offset, 0, i + offset, h, 0.2, 0.5, 0.8, a, 1)
        end
        for i = 0, h, gridSize do
            local a = 0.03 + 0.02 * math.sin(time + i * 0.01)
            d.line(0, i + offset, w, i + offset, 0.2, 0.5, 0.8, a, 1)
        end
    end
    Style.COLORS = COLORS
    return Style
end)()

-- ========================================================================
-- 2. ESP DISPLAY AND MENU (ESP V2 ONLY)
-- ========================================================================

local HackerHUD = (function()
local HUD = {}
HUD.__index = HUD
local floor, sqrt, sin, cos = math.floor, math.sqrt, math.sin, math.cos
local min, max, abs = math.min, math.max, math.abs
local huge = math.huge
local pi = math.pi
local ARC = {}
for i = 0, 8 do
    local angle = (-165 + 150 * i / 8) * pi / 180
    ARC[i + 1] = { cos(angle), sin(angle) }
end
local PALETTE = {
    {'Red',1,0.10,0.14},{'Cyan',0,0.9,1},{'Green',0.10,0.9,0.25},
    {'Yellow',1,0.9,0.05},{'Orange',1,0.45,0.05},{'Purple',0.62,0.25,1},
    {'Pink',1,0.25,0.65},{'White',1,1,1},{'Blue',0.1,0.35,1},{'Lime',0.60,1,0.05}
}
local PAGES = { {'page_v2','ESP V2'}, {'page_aim','Aim Menu'}, {'page_visual','Visual'} }
local AIMS = { 'Force Aimbot', 'Aim Assistant', 'Sniper Aim', 'Mortar Aim', 'Ignore Knocked', 'Ignore Bots', 'Visibility Check' }
local AIM_KEYS = { 'force', 'assistant', 'sniper', 'mortar', 'ignoreKnocked', 'ignoreBots', 'visibility' }
local AIM_SUPPORTED = { force = true, assistant = true, sniper = true, mortar = true, ignoreKnocked = true, ignoreBots = true, visibility = true, circle = true, smallCrosshair = true, bypass = true }
local AIM_STATUS = {
    force_disabled='Force Aimbot OFF',
    idle_ADS='Waiting for ADS', weapon_unavailable='Weapon unavailable',
    weapon_identity_unavailable='Weapon type unavailable', mortar_not_placed='Place mortar first',
    mortar_disabled='Mortar OFF', assistant_disabled='Assistant OFF', sniper_disabled='Sniper OFF',
    no_target_in_circle='No target inside circle', context_unavailable='Waiting for game data',
    context_changed='Waiting for current player', rotation_call_accepted='Aim command sent',
    priming_delta='Aim ready', target_left_circle='Target left circle'
}
local function finite(v) return type(v) == 'number' and v == v and v ~= huge and v ~= -huge end
local function clamp(v, lo, hi) return max(lo, min(hi, v)) end
local function number(v, fallback, lo, hi) return finite(v) and clamp(v, lo, hi) or fallback end
local function validId(id) return (type(id) == 'string' and #id > 0) or finite(id) end
local function inside(x, y, bx, by, bw, bh) return x >= bx and y >= by and x <= bx + bw and y <= by + bh end
local function shortName(value, bot)
    if type(value) ~= 'string' or #value == 0 then return bot and 'BOT' or 'ENEMY' end
    local s = value:sub(1, 52):gsub('[%z\1-\31\127]', '')
    local i, last = 1, 0
    while i <= #s and i <= 48 do
        local b = s:byte(i)
        local size = b < 128 and 1 or (b < 224 and 2 or (b < 240 and 3 or 4))
        if i + size - 1 > min(#s, 48) then break end
        last = i + size - 1
        i = last + 1
    end
    return s:sub(1, last)
end
local function previousChar(s)
    local i = #s
    while i > 1 and s:byte(i) >= 128 and s:byte(i) < 192 do i = i - 1 end
    return s:sub(1, i - 1)
end
local function fitName(renderer, value, size, maximum)
    local text = value
    while #text > 0 do
        local measured = renderer.measureText and renderer.measureText(text, size)
        local width = finite(measured) and measured >= 0 and measured or #text * size
        if width <= maximum then return text, width end
        text = previousChar(text)
    end
    return '', 0
end
local function boxed(d, x, y, w, h, value, size, r, g, b, a, align)
    if w <= 0 or h <= 0 then return end
    if d.textBox then return d.textBox(x, y, w, h, value, size, r, g, b, a, align or 'center') end
    local font = min(size, h * 0.72)
    local text, tw = fitName(d, value, font, w)
    local tx = x
    if align == 'right' then tx = x + w - tw
    elseif align ~= 'left' then tx = x + (w - tw) * 0.5 end
    if #text > 0 then d.text(tx, y + (h - font) * 0.5, text, font, r, g, b, a) end
end
local function bevel(d, x, y, w, h, cut, r, g, b, a, strokeR, strokeG, strokeB)
    cut = min(cut, w * 0.2, h * 0.4)
    d.rect(x, y + cut, w, h - 2 * cut, r, g, b, a, true, 1)
    for i = 0, 1 do
        local band = cut * 0.5
        d.rect(x, y + i * band, w - cut + (i + 0.5) * band, band, r, g, b, a, true, 1)
        d.rect(x + (i + 0.5) * band, y + h - cut + i * band, w - (i + 0.5) * band, band, r, g, b, a, true, 1)
    end
    if strokeR then
        local t = max(0.8, h / 24)
        d.line(x, y, x + w - cut, y, strokeR, strokeG, strokeB, 1, t)
        d.line(x + w - cut, y, x + w, y + cut, strokeR, strokeG, strokeB, 1, t)
        d.line(x + w, y + cut, x + w, y + h, strokeR, strokeG, strokeB, 1, t)
        d.line(x + w, y + h, x + cut, y + h, strokeR, strokeG, strokeB, 1, t)
        d.line(x + cut, y + h, x, y + h - cut, strokeR, strokeG, strokeB, 1, t)
        d.line(x, y + h - cut, x, y, strokeR, strokeG, strokeB, 1, t)
    end
end
local ROWS = {
    {'enabled', 'ESP Enabled'}, {'enemyCount', 'Enemy Count'},
    {'botCount', 'Bot Count'},
    {'health', 'Health Bars'}, {'names', 'Names'}, {'distance', 'Distance'},
    {'enemyHeadLines', 'Enemy Head Lines'}, {'enemyFeetLines', 'Enemy Feet Lines'},
    {'botHeadLines', 'Bot Head Lines'}, {'botFeetLines', 'Bot Feet Lines'},
    {'compass', 'Compass'}
}
local KEYS = {}
for i = 1, #ROWS do
    KEYS[ROWS[i][1]] = true
    ROWS[i][3] = ROWS[i][1]:sub(1, 5) == 'enemy'
end

function HUD.new(renderer, config)
    assert(type(renderer) == 'table', 'renderer table is required')
    for _, key in ipairs({'line', 'rect', 'circle', 'text'}) do
        assert(type(renderer[key]) == 'function', 'renderer.' .. key .. ' is required')
    end
    assert(renderer.measureText == nil or type(renderer.measureText) == 'function',
        'renderer.measureText must be a function when supplied')
    config = type(config) == 'table' and config or {}
    local self = setmetatable({
        renderer = renderer, records = {}, seen = {}, features = {}, featureSets = {}, controls = {},
        count = 0, enemies = 0, bots = 0, overflow = 0, invalid = 0,
        sourceOverflow = 0, totalOverflow = 0, overflowExact = true,
        enemyLabel = 'ENEMIES 0', botLabel = 'BOTS 0', enemyNumber = '0', botNumber = '0', limitLabel = '',
        range = number(config.range, 300, 1, 10000),
        maxActors = floor(number(config.maxActors, 256, 1, 2048)),
        staleAfter = number(config.staleAfter, 0.6, 0.05, 10),
        labelInterval = number(config.labelInterval, 0.2, 0.02, 1),
        buttonX = number(config.buttonX, 18, 0, 100000),
        buttonY = number(config.buttonY, 92, 0, 100000),
        rowHeight = 29, headerHeight = 82, closeWidth = 42, navWidth = 152,
        menuTitle = 'ELMASRY VIP ', menuVersion = 'ELITE MOD CONTROL',
        style = 'v2', page = 'v2',
        visual = { ipadView = false, wallHack = false, visibleColor = 1, occludedColor = 2 },
        featureStatus = {}, aimStatus = {}, weaponStatus = {}, bypassStatus = {},
        aim = { force = false, assistant = false, sniper = false, mortar = false, ignoreKnocked = true, ignoreBots = true, visibility = true, circle = false, smallCrosshair = false, bypass = false },
        width = 1280, height = 720, open = false, capture = nil,
        snapshotAt = nil, lastTime = nil, stale = true,
        px = 0, py = 0, pz = 0, yaw = 0, playerAiming = false
    }, HUD)
    do
        local values = {}
        local supplied = type(config.featureSets) == 'table' and config.featureSets['v2'] or config.features
        for i = 1, #ROWS do
            local key = ROWS[i][1]
            values[key] = not (type(supplied) == 'table' and supplied[key] == false)
        end
        self.featureSets['v2'] = values
    end
    self.features = self.featureSets['v2']
    if type(config.visual) == 'table' then
        self.visual.ipadView = config.visual.ipadView == true
        self.visual.wallHack = config.visual.wallHack == true
        self.visual.visibleColor = floor(number(config.visual.visibleColor, 1, 1, 10))
        self.visual.occludedColor = floor(number(config.visual.occludedColor, 2, 1, 10))
    end
    if type(config.aim) == 'table' then
        for key in pairs(AIM_SUPPORTED) do self.aim[key] = config.aim[key] == true end
    end
    self.aim.bypass = true
    self:resize(self.width, self.height)
    return self
end

function HUD:_clearActors(stale)
    for i = 1, self.count do
        local row = self.records[i]
        row.id, row.name, row.rawName, row.distanceLabel = nil, nil, nil, nil
    end
    for key in pairs(self.seen) do self.seen[key] = nil end
    self.count, self.enemies, self.bots, self.overflow, self.invalid = 0, 0, 0, 0, 0
    self.sourceOverflow, self.totalOverflow = 0, 0
    self.overflowExact = true
    self.enemyLabel, self.botLabel, self.limitLabel = 'ENEMIES 0', 'BOTS 0', ''
    self.enemyNumber, self.botNumber = '0', '0'
    self.snapshotAt, self.stale = nil, stale ~= false
end

function HUD:reset()
    self:_clearActors(true)
    self.lastTime, self.capture = nil, nil
end

function HUD:update(actors, player, now)
    if not finite(now) or type(actors) ~= 'table' or type(player) ~= 'table'
        or not finite(player.x) or not finite(player.y) or not finite(player.z)
        or not finite(player.yaw) then
        self:_clearActors(true)
        return false
    end
    if self.lastTime and now < self.lastTime then
        self:_clearActors(true)
        self.lastTime = now
        return false
    end
    self.lastTime = now
    self.px, self.py, self.pz, self.yaw = player.x, player.y, player.z, player.yaw
    self.playerAiming = player.aiming == true or player.aiming == 1
    for key in pairs(self.seen) do self.seen[key] = nil end
    local oldCount, count, enemies, bots, invalid = self.count, 0, 0, 0, 0
    local total, range2 = #actors, self.range * self.range
    for i = 1, min(total, self.maxActors) do
        local actor = actors[i]
        local valid = type(actor) == 'table' and validId(actor.id)
            and type(actor.isBot) == 'boolean'
            and finite(actor.x) and finite(actor.y) and finite(actor.z)
            and finite(actor.health) and finite(actor.maxHealth) and actor.maxHealth > 0
        if not valid then
            invalid = invalid + 1
        elseif not self.seen[actor.id] and actor.id ~= player.id
            and not (player.team ~= nil and actor.team == player.team)
            and actor.alive ~= false and (actor.health > 0 or actor.knocked == true) then
            self.seen[actor.id] = true
            local dx, dy, dz = actor.x - player.x, actor.y - player.y, actor.z - player.z
            local dist2 = dx * dx + dy * dy + dz * dz
            if finite(dist2) and dist2 <= range2 then
                count = count + 1
                local row = self.records[count]
                if not row then row = {} self.records[count] = row end
                local changed = row.id ~= actor.id
                if changed or row.rawName ~= actor.name or row.bot ~= actor.isBot then
                    row.name = shortName(actor.name, actor.isBot)
                    row.rawName = type(actor.name) == 'string' and actor.name or nil
                end
                row.id, row.bot = actor.id, actor.isBot
                row.dx, row.dy = dx, dy
                row.health = clamp(actor.health / actor.maxHealth, 0, 1)
                local hp = floor(row.health * 100 + 0.5)
                if row.healthPercent ~= hp or not row.healthLabel then
                    row.healthPercent, row.healthLabel = hp, tostring(hp) .. '%'
                end
                row.headX = finite(actor.headX) and actor.headX or nil
                row.headY = finite(actor.headY) and actor.headY or nil
                row.feetX = finite(actor.feetX) and actor.feetX or nil
                row.feetY = finite(actor.feetY) and actor.feetY or nil
                if changed or not row.nextLabel or now >= row.nextLabel then
                    local distance = floor(sqrt(dist2) + 0.5)
                    if changed or row.distance ~= distance or not row.distanceLabel then
                        row.distance, row.distanceLabel = distance, tostring(distance) .. ' m'
                    end
                    row.nextLabel = now + self.labelInterval
                end
                if row.bot then bots = bots + 1 else enemies = enemies + 1 end
            end
        end
    end
    for i = count + 1, oldCount do
        local row = self.records[i]
        row.id, row.name, row.rawName, row.distanceLabel = nil, nil, nil, nil
    end
    local overflow = max(0, total - self.maxActors)
    if self.enemies ~= enemies then self.enemyLabel = 'ENEMIES ' .. enemies self.enemyNumber = tostring(enemies) end
    if self.bots ~= bots then self.botLabel = 'BOTS ' .. bots self.botNumber = tostring(bots) end
    self.count, self.enemies, self.bots = count, enemies, bots
    self.overflow, self.invalid = overflow, invalid
    self:_refreshLimit()
    self.snapshotAt, self.stale = now, false
    return true
end

function HUD:resize(width, height)
    if not finite(width) or not finite(height) or width <= 0 or height <= 0 then return false end
    if self.width == width and self.height == height and self._resized then return true end
    self.width, self.height = width, height
    self.uiScale = min(1.5, width / 1280, height / 720)
    local bs = min(self.uiScale, width / 132, height / 38)
    self.buttonW, self.buttonH = 146 * bs, 42 * bs
    self.buttonX = clamp(self.buttonX, 0, width - self.buttonW)
    self.buttonY = clamp(self.buttonY, 0, height - self.buttonH)
    local panelHeight = 540
    local s = min(self.uiScale, width / 720, height / panelHeight)
    self.panelScale, self.panelW, self.panelH = s, 720 * s, panelHeight * s
    self:_layoutPanel()
    self._resized = true
    return true
end

function HUD:_layoutPanel()
    local s = self.panelScale
    local gap = 14 * s
    local margin = 10 * s
    local maxX = max(margin, self.width - self.panelW - margin)
    local maxY = max(margin, self.height - self.panelH - margin)

    -- Prefer the side of the launcher with enough room. Never place the panel
    -- underneath the launcher unless the viewport physically cannot fit it.
    local right = self.buttonX + self.buttonW + gap
    local left = self.buttonX - self.panelW - gap
    if right <= self.width - margin and right + self.panelW <= self.width - margin then
        self.panelX = clamp(right, margin, maxX)
        self.panelY = clamp(self.buttonY - 34 * s, margin, maxY)
    elseif left >= margin then
        self.panelX = clamp(left, margin, maxX)
        self.panelY = clamp(self.buttonY - 34 * s, margin, maxY)
    else
        -- No side fit: put it below the launcher, with a guaranteed gap.
        self.panelX = clamp(self.buttonX, margin, maxX)
        local below = self.buttonY + self.buttonH + gap
        self.panelY = below + self.panelH <= self.height - margin
            and below or clamp(self.buttonY - self.panelH - gap, margin, maxY)
    end
end

function HUD:setFeature(key, value)
    if not KEYS[key] or type(value) ~= 'boolean' then return false end
    self.features[key] = value
    return true
end

function HUD:exportSettings()
    local copy = { buttonX = self.buttonX, buttonY = self.buttonY, style = self.style, features = {}, featureSets = {}, visual = {}, aim = {} }
    copy.featureSets['v2'] = {}
    for key in pairs(KEYS) do copy.featureSets['v2'][key] = self.featureSets['v2'][key] end
    for key in pairs(KEYS) do copy.features[key] = self.features[key] end
    for key, value in pairs(self.visual) do copy.visual[key] = value end
    for key, value in pairs(self.aim) do copy.aim[key] = value end
    return copy
end

function HUD:setFeatureStatus(status) self.featureStatus = type(status) == 'table' and status or {} end
function HUD:setAimStatus(status) self.aimStatus = type(status) == 'table' and status or {} end
function HUD:setWeaponStatus(status) self.weaponStatus = type(status) == 'table' and status or {} end
function HUD:setBypassStatus(status) self.bypassStatus = type(status) == 'table' and status or {} end

function HUD:getControls()
    local list, n = self.controls, 0
    local function add(id, action, x, y, w, h, z, drag, enabled)
        n = n + 1
        local c = list[n] or {}
        list[n] = c
        c.id, c.action, c.x, c.y, c.w, c.h = id, action, x, y, w, h
        c.z, c.drag, c.enabled = z, drag == true, enabled ~= false
    end

    add('menu', 'button', self.buttonX, self.buttonY, self.buttonW, self.buttonH, 0, true)

    if self.open then
        local s, x, y = self.panelScale, self.panelX, self.panelY
        local navW = self.navWidth * s
        add('panel', 'panel', x, y, self.panelW, self.panelH, 1, true)

        add('dragbar', 'dragbar', x + 270 * s, y + 8 * s,
            max(70 * s, self.panelW - 430 * s), 24 * s, 5, true)

        add('close', 'close', x + self.panelW - 58 * s, y + 40 * s, 42 * s, 30 * s, 8)

        for i = 1, #PAGES do
            add('page' .. i, PAGES[i][1],
                x + 11 * s,
                y + (96 + (i - 1) * 66) * s,
                (navW - 22 * s), 50 * s, 6)
        end

        local content = x + navW
        local cw = self.panelW - navW

        if self.page == 'v2' then
            for i = 1, #ROWS do
                add('feature' .. i, 'feature_' .. ROWS[i][1],
                    content + 16 * s,
                    y + (157 + (i - 1) * self.rowHeight) * s,
                    cw - 32 * s, self.rowHeight * s, 6)
            end
        elseif self.page == 'aim' then
            for i = 1, #AIM_KEYS do
                local key = AIM_KEYS[i]
                add('aim' .. i, 'aim_' .. key,
                    content + 16 * s,
                    y + (160 + (i - 1) * 32) * s,
                    cw - 32 * s, 28 * s, 6, false, AIM_SUPPORTED[key] == true)
            end
            add('aimcircle', 'aim_circle', content + 16 * s, y + 390 * s, cw - 32 * s, 28 * s, 6)
            add('smallcrosshair', 'aim_smallCrosshair', content + 16 * s, y + 422 * s, cw - 32 * s, 28 * s, 6)
            add('bypass', 'aim_bypass', content + 16 * s, y + 454 * s, cw - 32 * s, 28 * s, 6)
        elseif self.page == 'visual' then
            add('ipad', 'ipadView', content + 16 * s, y + 160 * s, cw - 32 * s, 30 * s, 6)
            add('wall', 'wallHack', content + 16 * s, y + 194 * s, cw - 32 * s, 30 * s, 6)
            for category = 1, 2 do
                for i = 1, 10 do
                    local prefix = category == 1 and 'visible_' or 'occluded_'
                    add(prefix .. i, prefix .. i,
                        content + (20 + (i - 1) * 31) * s,
                        y + (261 + (category - 1) * 82) * s,
                        25 * s, 25 * s, 6)
                end
            end
        end
    end

    for i = n + 1, #list do list[i] = nil end
    return list
end

function HUD:activateControl(action)
    if action == 'button' then self.open = not self.open return true end
    if action == 'close' then self.open = false return true end
    if action == 'panel' or action == 'dragbar' then return true end
    if type(action) ~= 'string' then return false end
    local page = action:match('^page_(%w+)$')
    if page == 'v2' then
        self.page, self.style = 'v2', 'v2'
        self.features = self.featureSets['v2']
        return true
    elseif page == 'aim' or page == 'visual' then
        self.page = page
        return true
    end
    local key = action:match('^feature_(.+)$')
    if key and KEYS[key] then return self:setFeature(key, not self.features[key]) end
    local aimKey = action:match('^aim_(.+)$')
    if aimKey then
        if not AIM_SUPPORTED[aimKey] then return false end
        if aimKey == 'bypass' then self.aim.bypass = true return true end
        self.aim[aimKey] = not self.aim[aimKey]
        return true
    end
    if action == 'ipadView' or action == 'wallHack' then
        self.visual[action] = not self.visual[action]
        return true
    end
    local category, index = action:match('^(%a+)_(%d+)$')
    index = tonumber(index)
    if index and index >= 1 and index <= 10 then
        if category == 'visible' then self.visual.visibleColor = index return true end
        if category == 'occluded' then self.visual.occludedColor = index return true end
    end
    local step = max(12, 24 * self.uiScale)
    if action == 'move_left' then self.buttonX = self.buttonX - step
    elseif action == 'move_right' then self.buttonX = self.buttonX + step
    elseif action == 'move_up' then self.buttonY = self.buttonY - step
    elseif action == 'move_down' then self.buttonY = self.buttonY + step
    elseif action == 'reset_position' then self.buttonX, self.buttonY = 18 * self.uiScale, 92 * self.uiScale
    else return false end
    self.buttonX = clamp(self.buttonX, 0, self.width - self.buttonW)
    self.buttonY = clamp(self.buttonY, 0, self.height - self.buttonH)
    self:_layoutPanel()
    return true
end

function HUD:_refreshLimit()
    local total = self.overflow + self.sourceOverflow
    if total ~= self.totalOverflow or self._labelExact ~= self.overflowExact then
        self.totalOverflow = total
        self._labelExact = self.overflowExact
        self.limitLabel = not self.overflowExact and 'LIMIT: MORE'
            or (total > 0 and ('LIMIT +' .. total) or '')
    end
end

function HUD:setSourceOverflow(value, exact)
    if not finite(value) or value < 0 or value ~= floor(value) then return false end
    if exact ~= nil and type(exact) ~= 'boolean' then return false end
    self.sourceOverflow = min(value, 1000000)
    self.overflowExact = exact ~= false and value <= 1000000
    self:_refreshLimit()
    return true
end

function HUD:getStats()
    return {
        enemies = self.enemies, bots = self.bots, tracked = self.count,
        overflow = self.totalOverflow, sourceOverflow = self.sourceOverflow,
        overflowExact = self.overflowExact, invalid = self.invalid, stale = self.stale
    }
end

function HUD:_hit(x, y)
    local best
    for _, c in ipairs(self:getControls()) do
        if inside(x, y, c.x, c.y, c.w, c.h) and (not best or c.z >= best.z) then best = c end
    end
    return best and (best.enabled and best.action or 'panel') or nil
end

function HUD:pointer(kind, x, y, id)
    if id == nil then id = 0 end
    local cap = self.capture
    if kind == 'cancel' then
        if cap and cap.id == id then self.capture = nil return true end
        return false
    end
    if not finite(x) or not finite(y) then
        if kind == 'up' and cap and cap.id == id then self.capture = nil return true end
        return false
    end
    if kind == 'down' then
        if cap then return false end
        local target = self:_hit(x, y)
        if not target then return false end
        local baseX, baseY = self.buttonX, self.buttonY
        if self.open and target ~= 'button' then baseX, baseY = self.panelX, self.panelY end
        self.capture = { id = id, target = target, x = x, y = y, bx = baseX, by = baseY, dragged = false }
        return true
    end
    if not cap or cap.id ~= id then return false end
    if kind ~= 'move' and kind ~= 'up' then return false end
    local dx, dy = x - cap.x, y - cap.y
    if dx * dx + dy * dy > 36 then cap.dragged = true end

    if cap.dragged then
        if cap.target == 'button' and not self.open then
            self.buttonX = clamp(cap.bx + dx, 0, self.width - self.buttonW)
            self.buttonY = clamp(cap.by + dy, 0, self.height - self.buttonH)
        elseif self.open then
            self.panelX = clamp(cap.bx + dx, 0, self.width - self.panelW)
            self.panelY = clamp(cap.by + dy, 0, self.height - self.panelH)
            self.buttonX = clamp(self.panelX - self.buttonW - 10 * self.panelScale, 0, self.width - self.buttonW)
            self.buttonY = clamp(self.panelY + 12 * self.panelScale, 0, self.height - self.buttonH)
        end
    end
    if kind == 'up' then
        if not cap.dragged and self:_hit(x, y) == cap.target then
            self:activateControl(cap.target)
        end
        self.capture = nil
    end
    return true
end

function HUD:_drawActorsV2()
    -- Premium ESP: compact, high-contrast, animated enemies + calm bot markers.
    -- The data pipeline is unchanged; this is a presentation-only layer.
    local d, f = self.renderer, self.features
    local w, h, s = self.width, self.height, self.uiScale
    local halfW = w * 0.5
    local now = self.lastTime or 0
    -- Dynamic presentation: targets farther away use a smaller footprint.
    -- When the local player is aiming/scoped, aggressively compact the target
    -- frame/card while retaining a readable health strip.
    local scoped = self.playerAiming == true

    local function line(x1,y1,x2,y2,r,g,b,a,t)
        d.line(x1,y1,x2,y2,r,g,b,a,t)
    end

    local function cornerBox(cx, top, bw, bh, r,g,b, alpha, thick, cut)
        cut = cut or 10 * s
        local x = cx - bw * .5
        local y = top
        local right = x + bw
        local bottom = y + bh
        local len = min(cut, bw*.28, bh*.28)
        line(x,y,x+len,y,r,g,b,alpha,thick)
        line(x,y,x,y+len,r,g,b,alpha,thick)
        line(right-len,y,right,y,r,g,b,alpha,thick)
        line(right,y,right,y+len,r,g,b,alpha,thick)
        line(x,bottom-len,x,bottom,r,g,b,alpha,thick)
        line(x,bottom,x+len,bottom,r,g,b,alpha,thick)
        line(right-len,bottom,right,bottom,r,g,b,alpha,thick)
        line(right,bottom-len,right,bottom,r,g,b,alpha,thick)
    end

    local function miniBar(x,y,bw,bh,value,r,g,b)
        d.rect(x,y,bw,bh,0.015,0.02,0.03,0.72,true,2)
        if value > 0 then d.rect(x,y,bw*value,bh,r,g,b,0.95,true,2) end
    end

    local function distanceScale(meters)
        -- 1.0 at close range, smoothly falls off with distance, never
        -- disappearing completely so the overlay remains useful at range.
        local d0 = clamp(tonumber(meters) or 0, 0, 300)
        local t = clamp((d0 - 8) / 292, 0, 1)
        local eased = t * t * (3 - 2 * t)
        return 1.0 - 0.72 * eased
    end

    for i = 1, self.count do
        local row = self.records[i]
        local enemy = not row.bot
        local r,g,b = enemy and 1 or 0.08, enemy and 0.22 or 0.88, enemy and 0.30 or 1.0
        local hx, hy, fx, fy = row.headX, row.headY, row.feetX, row.feetY
        local head = hx and hy and hx >= 0 and hy >= 0 and hx <= w and hy <= h
        local feet = fx and fy and fx >= 0 and fy >= 0 and fx <= w and fy <= h

        if head then
            local baseBodyH = feet and max(36*s, fy-hy) or 96*s
            local scale = distanceScale(row.distance)
            if scoped then scale = scale * 0.34 end
            local bodyH = baseBodyH * scale
            local bodyW = clamp(bodyH * 0.36, 10*s, 78*s)
            local top = hy - bodyH*0.04
            local pulse = 0.5 + 0.5*sin(now*(enemy and 3.2 or 1.5) + i*0.73)

            -- Very subtle focus halo: enemies breathe/pulse, bots stay quiet.
            if enemy then
                d.circle(hx, hy + bodyH*.38, max(10*s, bodyW*.42), r,g,b,0.055 + pulse*0.035,false,1.5*s)
            end

            -- Optional snap lines remain, but are thinner and less intrusive.
            if (row.bot and f.botHeadLines) or ((not row.bot) and f.enemyHeadLines) then
                local a = enemy and (0.42 + pulse*0.20) or 0.28
                line(halfW, 8*s, hx, hy, r,g,b,a, max(1,1.2*s))
            end

            -- Enemy = premium tactical brackets; Bot = simple diamond marker.
            if enemy then
                cornerBox(hx, top, bodyW, bodyH, r,g,b,0.90 + pulse*0.08,max(1.3,1.7*s),10*s)
                -- second micro-frame gives a polished layered target-lock look
                cornerBox(hx, top+3*s, bodyW+5*s, bodyH-6*s, r,g,b,0.22,max(1,0.9*s),7*s)
                d.circle(hx, hy, 3.5*s, r,g,b,0.95,true)
                d.circle(hx, hy, 7*s, r,g,b,0.22 + pulse*0.10,false,max(1,1*s))
            else
                local rr = max(8*s, bodyW*.22)
                line(hx, hy-rr, hx+rr, hy, r,g,b,0.86,1.5*s)
                line(hx+rr, hy, hx, hy+rr, r,g,b,0.86,1.5*s)
                line(hx, hy+rr, hx-rr, hy, r,g,b,0.86,1.5*s)
                line(hx-rr, hy, hx, hy-rr, r,g,b,0.86,1.5*s)
                d.circle(hx, hy, 2.5*s, r,g,b,0.9,true)
            end

            -- Compact information card. Enemy card has a small threat notch; bot is plain.
            local cardScale = scale
            local pw = (enemy and 154 or 136) * s * cardScale
            local ph = (enemy and 39 or 32) * s * cardScale
            if scoped then
                -- Keep the card out of the sight picture while preserving a
                -- stronger health indicator.
                pw = (enemy and 154 or 136) * s * 0.38
                ph = (enemy and 39 or 32) * s * 0.38
            end
            local left = hx - pw*.5
            local cardY = max(6*s, top - ph - 5*s)
            if left < 5*s then left = 5*s elseif left+pw > w-5*s then left=w-5*s-pw end

            if scoped then
                -- Scoped mode: compact translucent tag, minimal text, readable HP.
                d.rect(left, cardY, pw, ph, 0.018,0.024,0.042, enemy and 0.54 or 0.46,true,4)
                d.rect(left, cardY, max(2*s, 3*s*0.38), ph, r,g,b,0.88,true,1)
                local barH = max(2.2*s, 3.2*s)
                miniBar(left + 5*s, cardY + ph - barH - 3*s,
                    max(8*s, pw - 10*s), barH, row.health, r,g,b)
            else
                d.rect(left+2*s, cardY+2*s, pw, ph, 0,0,0,0.22,true,6)
                d.rect(left, cardY, pw, ph, 0.018,0.024,0.042, enemy and 0.91 or 0.78,true,6)
                d.rect(left, cardY, 4*s*cardScale, ph, r,g,b,0.98,true,2)
                if enemy then
                    d.rect(left+4*s*cardScale, cardY, pw-4*s*cardScale, max(1*s, 2*s*cardScale),
                        r,g,b,0.32 + pulse*0.16,true,2)
                end

                if d.textBox then
                    local title = enemy and row.name or ('BOT  ' .. row.name)
                    local font = max(6*s, 11*s*cardScale)
                    d.textBox(left+10*s*cardScale, cardY+3*s*cardScale,
                        max(8*s, pw-20*s*cardScale), 15*s*cardScale,
                        title, font, 1,1,1,0.96,'left')
                    d.textBox(left+10*s*cardScale, cardY+18*s*cardScale,
                        max(8*s, 58*s*cardScale), 13*s*cardScale,
                        row.distanceLabel, max(6*s, 9.5*s*cardScale), r,g,b,0.95,'left')
                    d.textBox(left+70*s*cardScale, cardY+18*s*cardScale,
                        max(8*s, 48*s*cardScale), 13*s*cardScale,
                        row.healthLabel, max(6*s, 9.5*s*cardScale), 1,1,1,0.82,'left')
                end
                miniBar(left+10*s*cardScale, cardY+ph-max(3*s, 3*s*cardScale),
                    max(8*s, pw-20*s*cardScale), max(1.5*s, 3*s*cardScale), row.health, r,g,b)
            end

            -- Low-health emphasis only for enemies; no constant flashing.
            if enemy and row.health < 0.25 then
                local warn = 0.45 + 0.35*(0.5+0.5*sin(now*5.0+i))
                line(left, cardY+ph+2*s, left+pw, cardY+ph+2*s, r,g,b,warn,max(1,1.2*s))
            end
        end

        if feet and ((row.bot and f.botFeetLines) or ((not row.bot) and f.enemyFeetLines)) then
            line(halfW, h-22*s, fx, fy, r,g,b, enemy and 0.38 or 0.24, max(1,1.1*s))
        end
    end
end

function HUD:_drawCompass()
    local d, s = self.renderer, self.uiScale
    local cx, cy = self.width * 0.5, 72 * s
    local half = min(247 * s, self.width * 0.30)
    d.line(cx - half, cy, cx + half, cy, 1, 1, 1, 0.28, s)
    local degrees = self.yaw * 180 / pi
    for tick = floor((degrees - 120) / 15), math.ceil((degrees + 120) / 15) do
        local angle = tick * 15
        local x = cx + (angle - degrees) * 2 * s
        if abs(x - cx) <= half then
            local cardinal = (tick % 6) == 0
            d.line(x, cy - 16 * s, x, cy - (cardinal and 4 or 9) * s, 1, 1, 1, cardinal and .65 or .32, s)
            if cardinal then
                local names = { 'N', 'E', 'S', 'W' }
                boxed(d, x - 10 * s, cy - 24 * s, 20 * s, 16 * s, names[(tick // 6) % 4 + 1], 11 * s, 1, 1, 1, .86, 'center')
            end
        end
    end
    d.line(cx, cy - 2 * s, cx - 4 * s, cy + 10 * s, 1, 1, 1, 1, 2 * s)
    d.line(cx - 4 * s, cy + 10 * s, cx + 4 * s, cy + 10 * s, 1, 1, 1, 1, 2 * s)
    d.line(cx + 4 * s, cy + 10 * s, cx, cy - 2 * s, 1, 1, 1, 1, 2 * s)
end

function HUD:_drawCountsV2()
    local d, f, s = self.renderer, self.features, self.uiScale
    local count = (f.enemyCount and 1 or 0) + (f.botCount and 1 or 0)
    local bw, bh, gap = 120 * s, 32 * s, 24 * s
    local x = (self.width - count * bw - max(0, count - 1) * gap) * .5
    local y = 8 * s
    local function badge(label, value, bot)
        local r, g, b = 1, .24, .26
        if bot then r, g, b = 0, .91, 1 end
        d.rect(x, y, bw, bh, .035, .045, .06, .83, true, 1)
        d.rect(x, y, 4 * s, bh, r, g, b, 1, true, 1)
        boxed(d, x + 12 * s, y + 6 * s, 76 * s, 20 * s, label, 14 * s, 1, 1, 1, 1, 'left')
        boxed(d, x + 89 * s, y + 2 * s, 26 * s, 28 * s, value, 25 * s, r, g, b, 1, 'center')
        x = x + bw + gap
    end
    if f.enemyCount then badge('ENEMIES', self.enemyNumber, false) end
    if f.botCount then badge('BOTS', self.botNumber, true) end
    if self.totalOverflow > 0 or not self.overflowExact then
        boxed(d, self.width * .5 - 65 * s, 43 * s, 130 * s, 16 * s, self.limitLabel, 10 * s, 1, .85, .2, 1, 'center')
    end
end

function HUD:_drawEdges()
    if not self.features.distance then return end
    local left, right, behind
    local co, sy = cos(self.yaw), sin(self.yaw)
    for i = 1, self.count do
        local row = self.records[i]
        local projected = row.headX and row.headY
        local outside = projected and not inside(row.headX, row.headY, 0, 0, self.width, self.height)
        local ahead = row.dx * sy + row.dy * co
        if ahead < 0 then
            if not behind or row.distance < behind.distance then behind = row end
        elseif outside then
            local side = row.dx * co - row.dy * sy
            if side < 0 then
                if not left or row.distance < left.distance then left = row end
            elseif not right or row.distance < right.distance then right = row end
        end
    end
    local d, s = self.renderer, self.uiScale
    local function arrow(row, isLeft, rear)
        if not row then return end
        local r, g, b = 1, .24, .26
        if row.bot then r, g, b = 0, .91, 1 end
        if rear then
            local cx, cy = self.width * .5, self.height - 9 * s
            d.line(cx, cy, cx - 8 * s, cy - 12 * s, r, g, b, 1, 2 * s)
            d.line(cx - 8 * s, cy - 12 * s, cx + 8 * s, cy - 12 * s, r, g, b, 1, 2 * s)
            d.line(cx + 8 * s, cy - 12 * s, cx, cy, r, g, b, 1, 2 * s)
            d.rect(cx - 74 * s, cy - 39 * s, 148 * s, 23 * s, .025, .03, .04, .88, true, 1)
            boxed(d, cx - 68 * s, cy - 37 * s, 75 * s, 19 * s, 'BEHIND', 11 * s, 1, 1, 1, 1, 'left')
            boxed(d, cx + 7 * s, cy - 37 * s, 62 * s, 19 * s, row.distanceLabel, 12 * s, 1, 1, 1, 1, 'right')
            return
        end
        local cy = self.height * .5
        local tip = isLeft and 12 * s or self.width - 12 * s
        local back = tip + (isLeft and 18 * s or -18 * s)
        d.line(tip, cy, back, cy - 18 * s, r, g, b, 1, 2 * s)
        d.line(back, cy - 18 * s, back, cy + 18 * s, r, g, b, 1, 2 * s)
        d.line(back, cy + 18 * s, tip, cy, r, g, b, 1, 2 * s)
        local x = isLeft and back + 8 * s or back - 76 * s
        d.rect(x, cy - 12 * s, 68 * s, 24 * s, .025, .03, .04, .88, true, 1)
        boxed(d, x + 4 * s, cy - 10 * s, 60 * s, 20 * s, row.distanceLabel, 13 * s, 1, 1, 1, 1, 'center')
    end
    arrow(left, true) arrow(right, false) arrow(behind, false, true)
end

-- ========================================================================
-- PREMIUM MENU — full 1.lua HackerPremiumUI style
-- ========================================================================
function HUD:_drawMenu()
    local d = self.renderer
    if d.beginMenu then d.beginMenu() end

    local t = self.lastTime or 0
    local w, h = self.width, self.height
    local s = self.panelScale
    local P = HackerPremiumStyle

    -- Keep the visual layer lightweight: particles/grid are only rendered while open.
    if not self._premiumParticles then
        self._premiumParticles = P.initParticles(42)
    end

    local br, bg, bb = P.rainbow(t * 1.55)
    local pulse = 0.5 + 0.5 * math.sin(t * 2.6)

    -- Animated dimmer + moving cyber grid.  This sits behind the menu only.
    if self.open then
        d.rect(0, 0, w, h, 0.008, 0.012, 0.028, 0.48, true, 0)
        P.drawGrid(d, w, h, t)
        P.drawParticles(d, w, h, t, self._premiumParticles)

        -- Slow scan beam for a little depth without flooding the screen.
        local scanY = (t * 42) % (h + 80) - 40
        d.rect(0, scanY, w, math.max(1, 2 * s), br, bg, bb, 0.055, true, 0)
    end

    -- ================= LAUNCHER =================
    -- The old launcher was visually tiny and looked detached from the panel.
    -- This one is wider, cleaner and uses the same neon language as the menu.
    local bx, by = self.buttonX, self.buttonY
    local bw, bh = self.buttonW, self.buttonH
    local launcherScale = bw / 132
    local lr, lg, lb = P.rainbow(t * 2.0 + 0.8)

    P.glow(d, bx + bw * 0.5, by + bh * 0.5, math.max(bw, bh) * 0.46,
        0.55 + pulse * 0.18, lr, lg, lb)
    d.rect(bx + 2 * launcherScale, by + 3 * launcherScale,
        bw, bh, 0, 0, 0, 0.45, true, 9)
    d.rect(bx, by, bw, bh, 0.018, 0.025, 0.055, 0.96, true, 9)
    P.animatedBorder(d, bx, by, bw, bh, math.max(1.5, 2 * launcherScale), t)

    -- left status orb
    d.circle(bx + 18 * launcherScale, by + bh * 0.5,
        7.5 * launcherScale + pulse * 1.2 * launcherScale,
        lr, lg, lb, 0.24 + pulse * 0.18, false, math.max(1, 2 * launcherScale))
    d.circle(bx + 18 * launcherScale, by + bh * 0.5,
        3.2 * launcherScale, 0.15, 1, 0.55, 0.95, true)

    d.textBox(bx + 31 * launcherScale, by + 2 * launcherScale,
        bw - 54 * launcherScale, 17 * launcherScale, 'ELMASRY VIP ',
        9.2 * launcherScale, 0.96, 0.98, 1, 1, 'left')
    d.textBox(bx + 31 * launcherScale, by + 19 * launcherScale,
        bw - 54 * launcherScale, 12 * launcherScale,
        self.open and 'MOD MENU' or 'OPEN PANEL', 5.4 * launcherScale,
        lr, lg, lb, 0.95, 'left')

    -- small animated chevron
    local cx = bx + bw - 14 * launcherScale
    local cy = by + bh * 0.5
    local shift = math.sin(t * 3.0) * 1.5 * launcherScale
    d.line(cx - 4 * launcherScale + shift, cy - 4 * launcherScale,
           cx + 1 * launcherScale + shift, cy, lr, lg, lb, 0.9, 1.5 * launcherScale)
    d.line(cx + 1 * launcherScale + shift, cy,
           cx - 4 * launcherScale + shift, cy + 4 * launcherScale, lr, lg, lb, 0.9, 1.5 * launcherScale)

    if not self.open then
        if d.endMenu then d.endMenu() end
        return
    end

    -- ================= PANEL =================
    local x, y = self.panelX, self.panelY
    local W, H = self.panelW, self.panelH
    local navW = self.navWidth * s
    local content = x + navW
    local cw = W - navW
    local headerH = self.headerHeight * s

    -- layered shadow / glass shell
    d.rect(x + 10 * s, y + 12 * s, W, H, 0, 0, 0, 0.38, true, 10)
    d.rect(x + 4 * s, y + 6 * s, W, H, 0.01, 0.015, 0.035, 0.55, true, 11)
    d.rect(x, y, W, H, 0.018, 0.027, 0.060, 0.96, true, 12)
    P.animatedBorder(d, x, y, W, H, math.max(2, 2.5 * s), t)

    -- inner frame keeps all text away from the animated border
    d.rect(x + 5 * s, y + 5 * s, W - 10 * s, H - 10 * s,
        0.025, 0.038, 0.075, 0.24, true, 13)

    -- ================= HEADER =================
    local hr, hg, hb = P.rainbow(t * 2.2 + 0.4)
    P.glow(d, x + W * 0.48, y + 28 * s, 34 * s, 0.55, hr, hg, hb)

    -- text() is left-aligned by the native adapter; use textBox() for all
    -- centered header elements so they cannot drift/overlap on UMG.
    d.textBox(x + 150 * s, y + 8 * s, W - 300 * s, 30 * s, 'ELMASRY VIP ', 18 * s,
        0.98, 0.99, 1, 1, 'center')
    d.textBox(x + 210 * s, y + 38 * s, W - 420 * s, 16 * s, 'ELITE MOD CONTROL', 6.2 * s,
        hr, hg, hb, 0.92, 'center')

    -- animated header separator
    local linePulse = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 2.0))
    d.line(x + 18 * s, y + headerH - 5 * s,
           x + W - 18 * s, y + headerH - 5 * s,
           hr, hg, hb, 0.18 + linePulse * 0.42, 1.2 * s)

    -- ACTIVE chip
    local chipW, chipH = 78 * s, 23 * s
    local chipX, chipY = x + W - chipW - 52 * s, y + 12 * s
    d.rect(chipX, chipY, chipW, chipH, 0.025, 0.09, 0.075, 0.92, true, 5)
    d.rect(chipX, chipY, 3 * s, chipH, 0.10, 1, 0.48, 1, true, 5)
    d.circle(chipX + 12 * s, chipY + chipH * 0.5, 3.5 * s,
        0.15, 1, 0.55, 0.65 + pulse * 0.35, true)
    d.textBox(chipX + 21 * s, chipY + 3 * s, chipW - 24 * s, chipH - 6 * s,
        'ACTIVE', 6.5 * s, 0.25, 1, 0.62, 1, 'center')

    -- close button aligned with getControls() hitbox
    local closeX = x + W - 58 * s
    local closeY = y + 40 * s
    local closeW = 42 * s
    local closeH = 30 * s
    d.rect(closeX + 2 * s, closeY + 2 * s, closeW, closeH, 0, 0, 0, 0.35, true, 6)
    d.rect(closeX, closeY, closeW, closeH, 0.045, 0.055, 0.085, 0.96, true, 6)
    P.animatedBorder(d, closeX, closeY, closeW, closeH, 1.4 * s, t + 1.5)
    d.textBox(closeX, closeY + 1 * s, closeW, closeH - 2 * s,
        '×', 12 * s, 1, 1, 1, 1, 'center')

    -- ================= NAV RAIL =================
    d.rect(x, y + headerH, navW, H - headerH,
        0.010, 0.018, 0.040, 0.98, true, 1)
    d.line(x + navW, y + headerH, x + navW, y + H,
        hr, hg, hb, 0.24, 1 * s)

    local navItems = {
        { key = 'v2', label = 'ESP', sub = 'TRACKING', icon = '◎' },
        { key = 'aim', label = 'AIM', sub = 'TARGETING', icon = '⊙' },
        { key = 'visual', label = 'VISUAL', sub = 'APPEARANCE', icon = '◉' },
    }
    for i, item in ipairs(navItems) do
        local ny = y + (96 + (i - 1) * 66) * s
        local active = self.page == item.key
        local nr, ng, nb = P.rainbow(t * 1.8 + i * 1.4)
        local nw = navW - 22 * s
        local nh = 50 * s

        if active then
            P.glow(d, x + 28 * s, ny + nh * 0.5, 16 * s, 0.42, nr, ng, nb)
            d.rect(x + 11 * s, ny, nw, nh, 0.045, 0.075, 0.115, 1, true, 7)
            d.rect(x + 11 * s, ny, 3 * s, nh, nr, ng, nb, 1, true)
            d.rect(x + 16 * s, ny + nh - 2 * s, nw - 22 * s, 2 * s,
                nr, ng, nb, 0.55 + pulse * 0.25, true)
            d.text(x + 28 * s, ny + 15 * s, item.icon, 13 * s, nr, ng, nb, 1, 'center')
            d.text(x + 46 * s, ny + 12 * s, item.label, 11.2 * s, 1, 1, 1, 1, 'left')
            d.text(x + 46 * s, ny + 35 * s, item.sub, 6.3 * s, nr, ng, nb, 0.95, 'left')
        else
            d.rect(x + 11 * s, ny, nw, nh, 0.022, 0.030, 0.055, 0.90, true, 7)
            d.text(x + 28 * s, ny + 15 * s, item.icon, 12 * s, 0.48, 0.56, 0.68, 0.9, 'center')
            d.text(x + 46 * s, ny + 12 * s, item.label, 10.4 * s, 0.72, 0.77, 0.86, 1, 'left')
            d.text(x + 46 * s, ny + 35 * s, item.sub, 6.1 * s, 0.40, 0.48, 0.60, 1, 'left')
        end
    end

    -- bottom identity card
    local idY = y + H - 72 * s
    d.rect(x + 13 * s, idY, navW - 26 * s, 50 * s,
        0.025, 0.038, 0.075, 0.92, true, 7)
    d.rect(x + 13 * s, idY, 3 * s, 50 * s, hr, hg, hb, 0.9, true)
    d.text(x + 25 * s, idY + 12 * s, 'LMLK6', 8 * s, 0.90, 0.94, 1, 1, 'left')
    d.text(x + 25 * s, idY + 28 * s, 'ELMASRY VIP ', 6.3 * s, hr, hg, hb, 0.88, 'left')
    d.circle(x + navW - 27 * s, idY + 25 * s, 4 * s, 0.15, 1, 0.55, 0.9, true)

    -- ================= CONTENT =================
    local pageTitle = ({ v2 = 'ESP CORE', aim = 'AIM CONTROL', visual = 'VISUAL LAB' })[self.page] or 'MODULE'
    local pageSub = ({
        v2 = 'PLAYER TELEMETRY',
        aim = 'PRECISION TARGETING',
        visual = 'DISPLAY PROFILE'
    })[self.page] or ''

    d.textBox(content + 18 * s, y + 92 * s, cw - 36 * s, 24 * s, pageTitle, 13.5 * s,
        0.98, 0.99, 1, 1, 'left')
    d.textBox(content + 18 * s, y + 119 * s, cw - 36 * s, 14 * s, pageSub, 6.3 * s,
        hr, hg, hb, 0.90, 'left')

    -- small page indicator / live status
    d.textBox(x + W - 104 * s, y + 88 * s, 86 * s, 14 * s, 'ONLINE', 5.8 * s,
        0.20, 1, 0.60, 0.95, 'right')
    d.line(content + 18 * s, y + 143 * s,
           x + W - 18 * s, y + 130 * s,
           0.18, 0.28, 0.45, 0.60, 1 * s)

    -- Consistent row renderer. All positions intentionally match getControls().
    local function drawToggle(label, ry, on, rh, accent)
        local rowX = content + 16 * s
        local rowW = cw - 32 * s
        local r, g, b = accent[1], accent[2], accent[3]
        local midY = ry + rh * 0.5 * s

        d.rect(rowX + 2 * s, ry + 2 * s, rowW, rh * s,
            0, 0, 0, 0.22, true, 6)
        d.rect(rowX, ry, rowW, rh * s,
            on and 0.035 or 0.020,
            on and 0.050 or 0.028,
            on and 0.080 or 0.050,
            0.95, true, 6)
        d.rect(rowX, ry, 3 * s, rh * s, r, g, b, on and 1 or 0.30, true)

        if on then
            P.glow(d, rowX + 4 * s, midY, 11 * s, 0.28, r, g, b)
        end

        d.text(rowX + 15 * s, midY - 5 * s, label, 8.8 * s,
            0.92, 0.96, 1, 1, 'left')

        -- status
        d.text(rowX + rowW - 72 * s, midY - 5 * s,
            on and 'ON' or 'OFF', 6.8 * s,
            on and r or 0.40, on and g or 0.45, on and b or 0.52, 1, 'center')

        -- switch
        local tx = rowX + rowW - 39 * s
        local tw, th = 30 * s, 17 * s
        d.rect(tx, midY - th * 0.5, tw, th,
            on and r * 0.10 or 0.05,
            on and g * 0.10 or 0.06,
            on and b * 0.10 or 0.08,
            1, true, 9)
        d.rect(tx, midY - th * 0.5, tw, th,
            r, g, b, on and 0.34 or 0.16, false, 2)
        local knobX = on and (tx + tw - 7 * s) or (tx + 7 * s)
        d.circle(knobX, midY, on and 5.4 * s or 5 * s,
            on and 0.95 or 0.34,
            on and 1.0 or 0.39,
            on and 0.98 or 0.48,
            1, true)
        if on then P.glow(d, knobX, midY, 5 * s, 0.30, r, g, b) end
    end

    if self.page == 'v2' then
        for i = 1, #ROWS do
            local ry = y + (157 + (i - 1) * self.rowHeight) * s
            local ar, ag, ab = P.rainbow(t * 1.65 + i * 0.72)
            drawToggle(ROWS[i][2], ry, self.features[ROWS[i][1]], self.rowHeight, { ar, ag, ab })
        end

    elseif self.page == 'aim' then
        for i = 1, #AIM_KEYS do
            local key = AIM_KEYS[i]
            if AIM_SUPPORTED[key] then
                local ry = y + (160 + (i - 1) * 32) * s
                local ar, ag, ab = P.rainbow(t * 1.65 + i * 0.8)
                drawToggle(AIMS[i], ry, self.aim[key], 28, { ar, ag, ab })
            end
        end
        local base = y + 390 * s
        local a1r, a1g, a1b = P.rainbow(t * 1.65 + 8)
        local a2r, a2g, a2b = P.rainbow(t * 1.65 + 9)
        local a3r, a3g, a3b = P.rainbow(t * 1.65 + 10)
        drawToggle('Show Aim Circle', base, self.aim.circle, 28, { a1r, a1g, a1b })
        drawToggle('Small Crosshair', base + 32 * s, self.aim.smallCrosshair, 28, { a2r, a2g, a2b })
        drawToggle('Bypass', base + 64 * s, self.aim.bypass, 28, { a3r, a3g, a3b })

    elseif self.page == 'visual' then
        local v1r, v1g, v1b = P.rainbow(t * 1.65 + 1)
        local v2r, v2g, v2b = P.rainbow(t * 1.65 + 2)
        drawToggle('iPad View 120', y + 160 * s, self.visual.ipadView, 30, { v1r, v1g, v1b })
        drawToggle('Wall Colors', y + 194 * s, self.visual.wallHack, 30, { v2r, v2g, v2b })

        local titles = { 'VISIBLE COLOR', 'BEHIND WALL COLOR' }
        for category = 1, 2 do
            local ry = y + (261 + (category - 1) * 82) * s
            d.text(content + 20 * s, ry - 12 * s, titles[category], 7 * s,
                hr, hg, hb, 0.9, 'left')
            for i = 1, 10 do
                local cx = content + (20 + (i - 1) * 31) * s
                local selected = (category == 1 and self.visual.visibleColor or self.visual.occludedColor) == i
                local r, g, b = PALETTE[i][2], PALETTE[i][3], PALETTE[i][4]
                if selected then
                    P.glow(d, cx + 12.5 * s, ry + 12.5 * s, 9 * s, 0.45, r, g, b)
                    d.rect(cx - 2 * s, ry - 2 * s, 29 * s, 29 * s, r, g, b, 0.18, true, 5)
                end
                d.rect(cx, ry, 25 * s, 25 * s, r, g, b, selected and 0.95 or 0.52, true, 5)
                if selected then
                    d.circle(cx + 12.5 * s, ry + 12.5 * s, 3 * s, 1, 1, 1, 0.95, true)
                end
            end
        end
    end

    if d.endMenu then d.endMenu() end
end

function HUD:draw(width, height, now)
    if not self:resize(width, height) then return false end
    local validTime = finite(now)
    if validTime then
        if (self.lastTime and now < self.lastTime) or (self.snapshotAt and now - self.snapshotAt > self.staleAfter) then
            self:_clearActors(true)
        end
        self.lastTime = now
    end
    self:_drawMenu()
    if validTime and self.snapshotAt and not self.stale and self.aim.circle and
        (self.aim.force or self.aim.assistant or self.aim.sniper or self.aim.mortar) then
        self.renderer.circle(self.width * .5, self.height * .5, 105 * self.uiScale, 1, 1, 1, 1, false, max(2, 3 * self.uiScale))
    end
    if validTime and self.snapshotAt and not self.stale and self.features.enabled then
        self:_drawActorsV2()
        self:_drawEdges()
        if self.features.compass then self:_drawCompass() end
        self:_drawCountsV2()
    end
    return true
end

return HUD
end)()

-- ========================================================================
-- 3. NATIVE UMG RENDERER AND TOUCH INPUT
-- ========================================================================

local HackerUMGAdapter = (function()
local Adapter = {}
Adapter.__index = Adapter
local abs, min, max, sqrt = math.abs, math.min, math.max, math.sqrt
local floor, huge = math.floor, math.huge
local pi = math.pi
local function finite(v) return type(v) == 'number' and v == v and v ~= huge and v ~= -huge end
local function field(o, k)
    if o == nil then return nil end
    local ok, v = pcall(function() return o[k] end)
    if ok then return v end
end
local function method(o, k)
    local f = field(o, k)
    return type(f) == 'function' and f or nil
end
local function invoke(o, k, ...)
    local f = method(o, k)
    if not f then return false, 'Missing native method: ' .. k end
    return pcall(f, o, ...)
end
local function construct(f, ...)
    if f == nil then return nil end
    local ok, v = pcall(f, ...)
    if ok then return v end
end
local function bounded(v, default, lo, hi)
    return finite(v) and floor(max(lo, min(hi, v))) or default
end
local KEYS = { 'enabled', 'enemyCount', 'botCount',
    'health', 'names', 'distance', 'enemyHeadLines', 'enemyFeetLines', 'botHeadLines', 'botFeetLines' }
local CIRCLE = {}
for i = 0, 12 do CIRCLE[i + 1] = { math.cos(i * 2 * pi / 12), math.sin(i * 2 * pi / 12) } end

function Adapter:_error(message, fatal)
    self.error = tostring(message):sub(1, 220)
    self.errors = self.errors + 1
    if fatal then self.failed = true end
end
function Adapter:_warn(message)
    self.warning = tostring(message):sub(1, 220)
    self.warnings = self.warnings + 1
end
function Adapter:_write(o, k, ...)
    local ok, err = invoke(o, k, ...)
    if not ok then self:_error(err, true) end
    return ok
end
function Adapter:_isValid(o)
    if o == nil then return false end
    local valid = field(self.env.slua, 'isValid')
    if type(valid) == 'function' then
        local ok, v = pcall(valid, o)
        if ok and v == true then return true end
    end
    local game = self.env.Game
    if method(game, 'IsValid') then
        local ok, v = invoke(game, 'IsValid', o)
        return ok and v == true
    end
    if type(valid) == 'function' then return false end
    return true
end
function Adapter:_vector(x, y) return construct(self.Vector, x, y) or { X = x, Y = y } end
function Adapter:_color(r, g, b, a) return construct(self.Linear, r, g, b, a) or { R = r, G = g, B = b, A = a } end
function Adapter:_visible(node, wanted, hit)
    if node.visible == wanted then return true end
    local value = wanted and (hit and self.visibility.Visible or self.visibility.SelfHitTestInvisible) or self.visibility.Collapsed
    if self:_write(node.widget, 'SetWidgetVisibility', value) then node.visible = wanted return true end
    return false
end
function Adapter:_position(node, x, y)
    if node.x == x and node.y == y then return true end
    if self:_write(node.slot, 'SetPosition', self:_vector(x, y)) then node.x, node.y = x, y return true end
    return false
end
function Adapter:_size(node, w, h)
    if node.w == w and node.h == h then return true end
    if self:_write(node.slot, 'SetSize', self:_vector(w, h)) then node.w, node.h = w, h return true end
    return false
end
function Adapter:_z(node, z)
    if node.z == z then return true end
    if self:_write(node.slot, 'SetZOrder', z) then node.z = z return true end
    return false
end
function Adapter:_remove(node)
    if not node then return end
    node.removed = true
    for i = 1, #(node.bindings or {}) do
        local item = node.bindings[i]
        item.active = false
        if item.handle ~= nil and method(item.delegate, 'Remove') then
            local ok, err = invoke(item.delegate, 'Remove', item.handle)
            if not ok then self:_warn(err) end
        end
    end
    node.bindings = {}
    invoke(node.widget, 'RemoveFromParent')
    invoke(node.widget, 'ConditionalBeginDestroy')
end
function Adapter:_newNative(path, parent, input)
    if self.disposed or self.failed or self.total >= self.maxWidgets or self.createdThisFrame >= self.createBudget then
        self.deferred = self.deferred + 1
        return nil
    end
    self.createdThisFrame = self.createdThisFrame + 1
    local ok, widget = invoke(self.env.CGame, 'NewObjectFromPath', path, parent)
    if not ok or not self:_isValid(widget) then
        self:_error('UMG widget creation failed: ' .. path, not input)
        if input then self.inputFailed = true end
        return nil
    end
    local slotOK, slot = invoke(parent, 'AddChildToCanvas', widget)
    if not slotOK or not slot then
        invoke(widget, 'RemoveFromParent')
        invoke(widget, 'ConditionalBeginDestroy')
        self:_error('UMG canvas slot creation failed', not input)
        if input then self.inputFailed = true end
        return nil
    end
    local node = { widget = widget, slot = slot, bindings = {} }
    self.total = self.total + 1
    self.owned[#self.owned + 1] = node
    if not self:_write(slot, 'SetAutoSize', false) then return nil end
    self:_visible(node, false, input)
    return node
end

function Adapter.new(parentCanvas, env)
    env = type(env) == 'table' and env or _G
    local enums = field(env.UEnums, 'ESlateVisibility')
    if not enums or enums.Collapsed == nil or enums.SelfHitTestInvisible == nil or enums.Visible == nil then
        return nil, 'UEnums.ESlateVisibility is unavailable'
    end
    if not method(env.CGame, 'NewObjectFromPath') or not method(parentCanvas, 'AddChildToCanvas') then
        return nil, 'CGame widget factory or parent CanvasPanel is unavailable'
    end
    local cfg = type(env.ESPAdapterConfig) == 'table' and env.ESPAdapterConfig or {}
    local self = setmetatable({
        env = env, parent = parentCanvas, visibility = enums, owned = {},
        pools = { line = {}, rect = {}, text = {}, dot = {} },
        cursors = {}, total = 0, frame = 0, serial = 0, createdThisFrame = 0,
        errors = 0, warnings = 0, deferred = 0, droppedCommands = 0,
        maxWidgets = bounded(cfg.maxWidgets, 4096, 4, 4096),
        createBudget = bounded(cfg.createBudget, 16, 1, 128),
        actorGroups = {}, actorByKey = {}, actorFree = {},
        controls = {}, touchStates = {}, touchPositions = {},
        inputSupported = false, dragSupported = false, bindingsVerified = false,
        touchTupleObserved = false, touchDownObserved = false, touchMovementObserved = false,
        menuCaptureObserved = false, menuMovementObserved = false,
        touchSamples = 0, menuCaptures = 0, menuMoves = 0,
        textMeasured = 0, textClipped = 0, textUnverified = 0
    }, Adapter)
    local function dependency(name, short, long)
        local v = env[name]
        if v then return v end
        if type(env.import) == 'function' then
            local ok, a = pcall(env.import, short)
            if ok and a then return a end
            if long then
                ok, a = pcall(env.import, long)
                if ok then return a end
            end
        end
    end
    self.Vector = dependency('FVector2D', 'Vector2D')
    self.Linear = dependency('FLinearColor', 'LinearColor')
    self.Slate = dependency('FSlateColor', 'SlateColor', '/Script/SlateCore.SlateColor')
    if not self:_isValid(parentCanvas) then return nil, 'Parent CanvasPanel is invalid' end
    local root = self:_newNative('/Script/UMG.CanvasPanel', parentCanvas)
    if not root or self.failed then
        self:dispose()
        return nil, self.error or 'Owned canvas unavailable'
    end
    self.root = root
    self:_position(root, 0, 0)
    self:_z(root, 10000)
    self:_visible(root, true)
    if self.failed then
        self:dispose()
        return nil, self.error
    end
    self.renderer = {
        line = function(...) return self:_line(...) end,
        rect = function(...) return self:_rect(...) end,
        circle = function(...) return self:_circle(...) end,
        text = function(...) return self:_text(...) end,
        textBox = function(...) return self:_textBox(...) end,
        beginMenu = function() self.inMenu = true self.menuSeen = true end,
        endMenu = function() self.inMenu = false end,
        beginActor = function(...) return self:_beginActor(...) end,
        endActor = function() self.currentGroup = nil end
    }
    return self
end

function Adapter:valid()
    return not self.disposed and not self.failed and self:_isValid(self.parent)
        and self.root ~= nil and self:_isValid(self.root.widget)
end

function Adapter:setViewportOrigin(x, y)
    if not finite(x) or not finite(y) or not self:valid() then return false end
    return self:_position(self.root, x, y)
end

function Adapter:beginFrame()
    if self.disposed then return false end
    self.frame = self.frame + 1
    self.serial = 0
    self.createdThisFrame = 0
    self.deferred = 0
    self.droppedCommands = 0
    self.inMenu = false
    self.menuSeen = false
    self.menuDropped = 0
    self.currentGroup = nil
    self.textMeasured = 0
    self.textClipped = 0
    self.textUnverified = 0
    for k in pairs(self.pools) do self.cursors[k] = 0 end
    return self:valid()
end

function Adapter:_beginActor(key, x, y, w, h)
    if self.disposed or self.failed or self.currentGroup or self.inMenu then return false end
    if not ((type(key) == 'string' and #key > 0) or finite(key)) or not (finite(x) and finite(y)) then return false end
    w = finite(w) and w or self.root.w or 1280
    h = finite(h) and h or self.root.h or 720
    if w <= 0 or h <= 0 then return false end
    local group = self.actorByKey[key]
    if not group then
        local free = self.actorFree
        group = free[#free]
        if group then
            free[#free] = nil
            group.free = false
        else
            group = self:_newNative('/Script/UMG.CanvasPanel', self.root.widget)
            if not group then return false end
            group.pools = { line = {}, rect = {}, text = {}, dot = {} }
            group.cursors = {}
            self.actorGroups[#self.actorGroups + 1] = group
        end
        group.key = key
        self.actorByKey[key] = group
    end
    group.used = self.frame
    group.serial = 0
    for kind in pairs(group.pools) do group.cursors[kind] = 0 end
    self.serial = self.serial + 1
    self:_position(group, x, y)
    self:_size(group, w, h)
    self:_z(group, self.serial)
    self:_visible(group, true)
    if self.failed then return false end
    self.currentGroup = group
    return true
end

function Adapter:_borrow(kind)
    if self.disposed or self.failed then return nil end
    local owner = self.currentGroup or self
    local index = (owner.cursors[kind] or 0) + 1
    owner.cursors[kind] = index
    owner.serial = owner.serial + 1
    local pool = owner.pools[kind]
    local node = pool[index]
    if not node then
        local path = (kind == 'text' or kind == 'dot') and '/Script/UMG.TextBlock' or '/Script/UMG.Border'
        node = self:_newNative(path, self.currentGroup and self.currentGroup.widget or self.root.widget)
        if not node then
            self.droppedCommands = self.droppedCommands + 1
            if self.inMenu then self.menuDropped = self.menuDropped + 1 end
            return nil
        end
        pool[index] = node
        if kind == 'line' then
            self:_write(node.widget, 'SetRenderTransformPivot', self:_vector(0, 0.5))
        elseif kind == 'text' or kind == 'dot' then
            self:_write(node.widget, 'SetRenderTransformPivot', self:_vector(0, 0))
            if method(node.widget, 'SetAutoWrapText') then invoke(node.widget, 'SetAutoWrapText', false) end
            local clipping = field(field(self.env.UEnums, 'EWidgetClipping'), 'ClipToBounds')
            if clipping ~= nil then node.clipped = invoke(node.widget, 'SetClipping', clipping) == true end
        end
    end
    node.used = self.frame
    self:_z(node, (self.inMenu and 10000 or 0) + owner.serial)
    self:_visible(node, true)
    return node
end

function Adapter:_tint(node, r, g, b, a, text)
    if node.r == r and node.g == g and node.b == b and node.a == a then return end
    local color = self:_color(r, g, b, a)
    if text then color = construct(self.Slate, color) or color end
    if self:_write(node.widget, text and 'SetColorAndOpacity' or 'SetBrushColor', color) then
        node.r, node.g, node.b, node.a = r, g, b, a
    end
end
local function colorOK(r, g, b, a) return finite(r) and finite(g) and finite(b) and finite(a) and a > 0 end
function Adapter:_line(x1, y1, x2, y2, r, g, b, a, thickness)
    if not (finite(x1) and finite(y1) and finite(x2) and finite(y2) and finite(thickness)
        and thickness > 0 and colorOK(r, g, b, a)) then return false end
    local dx, dy = x2 - x1, y2 - y1
    local length = sqrt(dx * dx + dy * dy)
    if not finite(length) or length < 0.01 then return false end
    local node = self:_borrow('line')
    if not node then return false end
    self:_position(node, x1, y1 - thickness * 0.5)
    self:_size(node, length, thickness)
    local angle = math.atan(dy, dx) * 180 / pi
    if node.angle ~= angle and self:_write(node.widget, 'SetRenderAngle', angle) then node.angle = angle end
    self:_tint(node, r, g, b, a)
    return not self.failed
end
function Adapter:_rect(x, y, w, h, r, g, b, a, filled, thickness)
    if not (finite(x) and finite(y) and finite(w) and finite(h) and w > 0 and h > 0 and colorOK(r, g, b, a)) then return false end
    thickness = finite(thickness) and max(0.1, thickness) or 1
    if not filled then
        self:_line(x, y, x + w, y, r, g, b, a, thickness)
        self:_line(x + w, y, x + w, y + h, r, g, b, a, thickness)
        self:_line(x + w, y + h, x, y + h, r, g, b, a, thickness)
        self:_line(x, y + h, x, y, r, g, b, a, thickness)
        return not self.failed
    end
    local node = self:_borrow('rect')
    if not node then return false end
    self:_position(node, x, y)
    self:_size(node, w, h)
    self:_tint(node, r, g, b, a)
    return not self.failed
end
function Adapter:_font(node, size)
    size = max(1, floor(size + 0.5))
    if node.fontSize == size then return true end
    if node.fontUnsupported then return false end
    local font = field(node.widget, 'Font')
    if font then
        local sized = pcall(function() font.Size = size end)
        if sized then
            local assigned = pcall(function() node.widget.Font = font end)
            if assigned then node.fontSize = size return true end
            if method(node.widget, 'SetFont') then
                local set = invoke(node.widget, 'SetFont', font)
                if set then node.fontSize = size return true end
            end
        end
    end
    node.fontUnsupported = true
    if not self.fontWarning then
        self.fontWarning = true
        self:_warn('Text size binding unavailable; retaining the widget default font')
    end
    return false
end
local function glyphCount(value)
    if utf8 and utf8.len then
        local ok, n = pcall(utf8.len, value)
        if ok and n then return n end
    end
    return #value
end
function Adapter:_textBox(x, y, w, h, value, size, r, g, b, a, align, kind)
    if not (finite(x) and finite(y) and finite(w) and finite(h) and w > 0 and h > 0
        and finite(size) and size > 0 and type(value) == 'string' and #value > 0
        and colorOK(r, g, b, a)) then return false end
    local node = self:_borrow(kind or 'text')
    if not node then return false end
    local changed = node.text ~= value or node.requestedSize ~= size or node.boxW ~= w or node.boxH ~= h
    self:_font(node, size)
    self:_tint(node, r, g, b, a, true)
    if node.text ~= value and self:_write(node.widget, 'SetText', value) then node.text = value end
    if changed or (node.layoutPending and self.frame >= (node.nextLayoutTry or 0)) then
        if method(node.widget, 'ForceLayoutPrepass') then invoke(node.widget, 'ForceLayoutPrepass') end
        local ok, desired = invoke(node.widget, 'GetDesiredSize')
        local dw, dh = field(desired, 'X'), field(desired, 'Y')
        local measured = ok and finite(dw) and finite(dh) and dw > 0 and dh > 0
        node.layoutPending = not measured and method(node.widget, 'GetDesiredSize') ~= nil
        node.nextLayoutTry = self.frame + 3
        if not measured then
            local native = field(field(node.widget, 'Font'), 'Size')
            local estimate = finite(native) and max(native, size) or max(96, size)
            dw = max(1, glyphCount(value)) * estimate * 2
            dh = estimate * 2.5
        end
        local scale = min(1, w / dw, h / dh)
        if node.scale ~= scale then
            local scaled = invoke(node.widget, 'SetRenderScale', self:_vector(scale, scale))
            if scaled then node.scale = scale else scale = 1 end
        end
        if not node.scale then scale = 1 else scale = node.scale end
        if measured and dw * scale <= w + 0.001 and dh * scale <= h + 0.001 then
            node.textMode = 'measured'
            node.drawW, node.drawH = dw * scale, dh * scale
            self:_size(node, dw, dh)
        else
            self:_size(node, w / scale, h / scale)
            node.drawW, node.drawH = w, h
            node.textMode = node.clipped and 'clipped' or 'unverified'
        end
        node.requestedSize, node.boxW, node.boxH = size, w, h
    end
    local offset = align == 'right' and w - node.drawW or (align == 'center' and (w - node.drawW) * 0.5 or 0)
    self:_position(node, x + max(0, offset), y + max(0, (h - node.drawH) * 0.5))
    if node.textMode == 'measured' then self.textMeasured = self.textMeasured + 1
    elseif node.textMode == 'clipped' then self.textClipped = self.textClipped + 1
    else self.textUnverified = self.textUnverified + 1 end
    return not self.failed
end
function Adapter:_text(x, y, value, size, r, g, b, a)
    if type(value) ~= 'string' or not finite(size) or size <= 0 then return false end
    return self:_textBox(x, y, max(1, glyphCount(value)) * size * 1.5, size * 2.5, value, size, r, g, b, a, 'left')
end
function Adapter:_circle(x, y, radius, r, g, b, a, filled, thickness)
    if not (finite(x) and finite(y) and finite(radius) and radius > 0 and colorOK(r, g, b, a)) then return false end
    if filled then
        return self:_textBox(x - radius, y - radius, radius * 2, radius * 2, '●', radius * 2, r, g, b, a, 'center', 'dot')
    else
        thickness = finite(thickness) and max(0.1, thickness) or 1
        for i = 1, 12 do
            local p, q = CIRCLE[i], CIRCLE[i + 1]
            self:_line(x + p[1] * radius, y + p[2] * radius, x + q[1] * radius, y + q[2] * radius, r, g, b, a, thickness)
        end
    end
    return not self.failed
end

function Adapter:endFrame()
    if self.disposed then return false end
    self.currentGroup = nil
    for _, pool in pairs(self.pools) do
        for _, node in pairs(pool) do if node.used ~= self.frame then self:_visible(node, false) end end
    end
    for _, group in ipairs(self.actorGroups) do
        if group.used == self.frame then
            for _, pool in pairs(group.pools) do
                for _, node in pairs(pool) do if node.used ~= self.frame then self:_visible(node, false) end end
            end
        elseif not group.free then
            self:_visible(group, false)
            self.actorByKey[group.key] = nil
            group.key = nil
            group.free = true
            self.actorFree[#self.actorFree + 1] = group
        end
    end
    if self.failed or self.menuDropped > 0 or not self.inputSupported then self:_cancelInput() end
    return not self.failed
end

function Adapter:_bind(node, event, callback, required)
    local delegate = field(node.widget, event)
    local function failed(message)
        if required ~= false then
            self:_error(message, false)
            self.inputFailed = true
        else
            self:_warn(message)
        end
        return false
    end
    if not method(delegate, 'Add') then return failed('Native button delegate unavailable: ' .. event) end
    local item = { delegate = delegate, active = false }
    local guarded = function(...)
        if self.disposed or node.removed or not item.active then return end
        return callback(...)
    end
    local ok, handle = invoke(delegate, 'Add', guarded)
    if not ok then return failed('Could not bind native button delegate: ' .. event) end
    item.handle, item.active = handle, true
    node.bindings[#node.bindings + 1] = item
    return true
end

function Adapter:_button(name, z, clicked, pressed, released)
    if self.inputFailed then return nil end
    local node = self.controls[name]
    if node then return node end
    node = self:_newNative('/Script/UMG.Button', self.root.widget, true)
    if not node then return nil end
    local ok, err = invoke(node.widget, 'SetBackgroundColor', self:_color(1, 1, 1, 0))
    if not ok then
        self:_error(err, false)
        self.inputFailed = true
        return nil
    end
    self:_z(node, z)
    if clicked and not self:_bind(node, 'OnClicked', clicked) then return nil end
    if pressed or released then
        local pressOK = pressed and self:_bind(node, 'OnPressed', pressed, false)
        local releaseOK = released and self:_bind(node, 'OnReleased', released, false)
        node.dragBindingsSupported = pressOK == true and releaseOK == true
    end
    self.controls[name] = node
    return node
end

local function decodeTouch(a, b, c)
    if finite(a) and finite(b) and type(c) == 'boolean' then return a, b, c end
    if type(a) == 'boolean' and finite(b) and finite(c) then return b, c, a end
end

function Adapter:_touch(finger)
    if not method(self.pc, 'GetInputTouchState') then
        self.touchTupleAvailable = false
        self.dragSupported = false
        return nil
    end
    local ok, a, b, c
    if self.touchSignature == 4 then
        ok, a, b, c = invoke(self.pc, 'GetInputTouchState', finger, 0, 0, false)
    else
        ok, a, b, c = invoke(self.pc, 'GetInputTouchState', finger)
    end
    local x, y, down
    if ok then x, y, down = decodeTouch(a, b, c) end
    if x == nil and self.touchSignature == nil then
        ok, a, b, c = invoke(self.pc, 'GetInputTouchState', finger, 0, 0, false)
        if ok then x, y, down = decodeTouch(a, b, c) end
        if x ~= nil then self.touchSignature = 4 end
    elseif x ~= nil and self.touchSignature == nil then
        self.touchSignature = 1
    end
    if x == nil then
        self.touchTupleAvailable = false
        self.dragSupported = false
        return nil
    end
    if self.toCanvas then
        local converted, cx, cy = pcall(self.toCanvas, x, y)
        if not converted or not finite(cx) or not finite(cy) then
            self.touchTupleAvailable = false
            self.dragSupported = false
            return nil
        end
        x, y = cx, cy
    end
    self.touchTupleAvailable = true
    self.touchTupleObserved = true
    self.touchSamples = min(1000000, self.touchSamples + 1)
    if down then self.touchDownObserved = true end
    local previous = self.touchPositions[finger]
    if previous and previous.down and down and (previous.x ~= x or previous.y ~= y) then
        self.touchMovementObserved = true
    end
    if not previous then previous = {} self.touchPositions[finger] = previous end
    previous.x, previous.y, previous.down = x, y, down
    self.dragSupported = self.menuMovementObserved == true
    return x, y, down
end

function Adapter:_dragHit(x, y)
    if self.descriptors then
        local hit, highest
        for i = 1, min(#self.descriptors, 64) do
            local d = self.descriptors[i]
            if self:_descriptorValid(d) and x >= d.x and y >= d.y and x <= d.x + d.w and y <= d.y + d.h
                and (not highest or d.z >= highest) then hit, highest = d, d.z end
        end
        if not hit or hit.enabled == false then return false end
        if self.hud and self.hud.open and hit.action ~= 'button' then return true end
        return hit.drag == true
    end
    return self.hud and self.hud:_hit(x, y) == 'button'
end

function Adapter:_capture(finger, x, y)
    if self.active or not self.hud or not self:_dragHit(x, y) then return false end
    if self.hud:pointer('down', x, y, finger) then
        self.active = { id = finger, x = x, y = y, misses = 0 }
        self.menuCaptureObserved = true
        self.menuCaptures = min(1000000, self.menuCaptures + 1)
        self.suppressClick = true
        self.suppressUntil = nil
        self.pendingPress = false
        return true
    end
    return false
end

function Adapter:_pressed()
    if self.disposed or not self.hud or self.active then return end
    self.suppressClick = false
    self.pendingPress = true
    for finger = 0, 9 do
        local x, y, down = self:_touch(finger)
        if x == nil then break end
        if down and self:_capture(finger, x, y) then return end
    end
end

function Adapter:_released()
    self.pendingPress = false
    local active = self.active
    if not active or not self.hud then return end
    local x, y = self:_touch(active.id)
    self.hud:pointer('up', x or active.x, y or active.y, active.id)
    self.active = nil
    self.suppressUntil = self.frame + 2
end

function Adapter:_pollTouch()
    if self.suppressUntil and self.frame > self.suppressUntil then
        self.suppressClick = false
        self.suppressUntil = nil
    end
    if not self.active and not (self.hud and self.hud.open) then
        return
    end
    for finger = 0, 9 do
        local x, y, down = self:_touch(finger)
        if x == nil then
            if self.active and self.active.id == finger then
                self.active.misses = self.active.misses + 1
                if self.active.misses >= 3 then
                    self.hud:pointer('cancel', 0, 0, finger)
                    self.active = nil
                    self.suppressUntil = self.frame + 2
                end
            end
            break
        end
        local previous = self.touchStates[finger]
        self.touchStates[finger] = down
        if self.active and self.active.id == finger then
            self.active.misses = 0
            if down then
                local beforeX, beforeY = self.hud.buttonX, self.hud.buttonY
                self.active.x, self.active.y = x, y
                self.hud:pointer('move', x, y, finger)
                if self.hud.buttonX ~= beforeX or self.hud.buttonY ~= beforeY then
                    self.menuMovementObserved = true
                    self.dragSupported = true
                    self.menuMoves = min(1000000, self.menuMoves + 1)
                end
            else
                self.hud:pointer('up', x, y, finger)
                self.active = nil
                self.suppressUntil = self.frame + 2
            end
        elseif not self.active and down and previous ~= true then
            self:_capture(finger, x, y)
        end
    end
end

function Adapter:_cancelInput()
    if self.active and self.hud then self.hud:pointer('cancel', 0, 0, self.active.id) end
    self.active = nil
    self.pendingPress = false
    self.inputSupported = false
    self.dragSupported = false
    for _, node in pairs(self.controls) do self:_visible(node, false, true) end
end

function Adapter:_descriptorValid(d)
    return type(d) == 'table' and type(d.id) == 'string' and #d.id > 0 and #d.id <= 64
        and type(d.action) == 'string' and #d.action <= 96
        and finite(d.x) and finite(d.y) and finite(d.w) and finite(d.h) and d.w > 0 and d.h > 0
        and finite(d.z) and d.z >= 0 and d.z <= 99
        and (d.drag == nil or type(d.drag) == 'boolean') and (d.enabled == nil or type(d.enabled) == 'boolean')
end

function Adapter:_descriptorList()
    local ok, list = invoke(self.hud, 'getControls')
    if not ok or type(list) ~= 'table' or #list > 64 then
        if not self.descriptorWarning then
            self.descriptorWarning = true
            self:_warn('HUD controls must be an array with at most 64 entries')
        end
        self.descriptors = nil
        return nil
    end
    self.descriptors = list
    return list
end

function Adapter:_descriptorClick(id)
    local node = self.controls[id]
    if self.disposed or not self.hud or not node or not node.visible or node.controlEnabled == false
        or node.controlPass ~= self.controlPass then return end
    if node.controlDrag then
        if self.active then self:_released() end
        if self.suppressClick then self.suppressClick = false return end
    end
    local ok, err = invoke(self.hud, 'activateControl', node.controlAction)
    if not ok then
        self:_error('HUD control action failed: ' .. tostring(err), false)
        self:_cancelInput()
        return
    end
    self:_syncDescriptorControls(false)
end

function Adapter:_syncDescriptorControls(poll)
    local list = self:_descriptorList()
    if not list then self:_cancelInput() return false end
    if poll then
        self:_pollTouch()
        list = self:_descriptorList()
        if not list then self:_cancelInput() return false end
    end
    self.controlPass = (self.controlPass or 0) + 1
    local seen = self.controlSeen or {}
    self.controlSeen = seen
    for id in pairs(seen) do seen[id] = nil end
    local ready = #list > 0
    self.clickMoveAvailable = false
    self.dragBindingsSupported = false
    for i = 1, #list do
        local d = list[i]
        if not self:_descriptorValid(d) or seen[d.id] then
            ready = false
            if not self.descriptorWarning then
                self.descriptorWarning = true
                self:_warn('HUD controls contain invalid or duplicate descriptors')
            end
        else
            local id = d.id
            seen[id] = true
            local node = self:_button(id, 20000 + d.z, function() self:_descriptorClick(id) end)
            if node then
                node.controlPass = self.controlPass
                node.controlAction = d.action
                node.controlEnabled = d.enabled ~= false
                node.controlDrag = d.drag == true
                if node.controlDrag and not node.dragBindingsConfigured then
                    node.dragBindingsConfigured = true
                    local pressOK = self:_bind(node, 'OnPressed', function()
                        if node.controlDrag and node.controlEnabled and node.visible then self:_pressed() end
                    end, false)
                    local releaseOK = self:_bind(node, 'OnReleased', function()
                        if node.controlDrag and node.controlEnabled and node.visible then self:_released() end
                    end, false)
                    node.dragBindingsSupported = pressOK == true and releaseOK == true
                end
                if node.controlDrag and node.dragBindingsSupported then self.dragBindingsSupported = true end
                if node.controlEnabled and (d.action == 'move_left' or d.action == 'move_right'
                    or d.action == 'move_up' or d.action == 'move_down' or d.action == 'reset_position') then
                    self.clickMoveAvailable = true
                end
                self:_position(node, d.x, d.y)
                self:_size(node, d.w, d.h)
                self:_z(node, 20000 + d.z)
                self:_visible(node, true, true)
            else ready = false end
        end
    end
    for _, node in pairs(self.controls) do
        if node.controlPass ~= self.controlPass then self:_visible(node, false, true) end
    end
    if self.inputFailed then self:_cancelInput() return false end
    self.inputSupported = ready
    return ready
end

function Adapter:syncInput(hud, pc, toCanvas)
    if not self:valid() or type(hud) ~= 'table' then return false end
    if self.pc ~= pc then
        if self.active and self.hud then self.hud:pointer('cancel', 0, 0, self.active.id) end
        self.active = nil
        self.touchStates = {}
        self.touchPositions = {}
        self.touchSignature = nil
        self.dragSupported = false
        self.touchTupleAvailable = false
        self.touchTupleObserved = false
        self.touchDownObserved = false
        self.touchMovementObserved = false
        self.menuCaptureObserved = false
        self.menuMovementObserved = false
        self.touchSamples, self.menuCaptures, self.menuMoves = 0, 0, 0
    end
    self.hud, self.pc, self.toCanvas = hud, pc, toCanvas
    self:_size(self.root, hud.width, hud.height)
    if self.inputFailed then self:_cancelInput() return false end
    if not method(pc, 'GetInputTouchState') then self.dragSupported = false end
    if method(hud, 'getControls') and method(hud, 'activateControl') then
        return self:_syncDescriptorControls(true)
    end
    self.descriptors = nil
    local menu = self:_button('menu', 20000, function()
        if self.disposed or not self.hud then return end
        if self.active then self:_released() end
        if self.suppressClick then self.suppressClick = false return end
        self.hud.open = not self.hud.open
    end, function() self:_pressed() end, function() self:_released() end)
    self.dragBindingsSupported = menu ~= nil and menu.dragBindingsSupported == true
    if menu then self:_pollTouch() end
    if menu then
        self:_position(menu, hud.buttonX, hud.buttonY)
        self:_size(menu, hud.buttonW, hud.buttonH)
        self:_visible(menu, true, true)
    end
    local ready = menu ~= nil
    if hud.open then
        local blocker = self:_button('panel', 20001)
        if blocker then
            self:_position(blocker, hud.panelX, hud.panelY)
            self:_size(blocker, hud.panelW, hud.panelH)
            self:_visible(blocker, true, true)
        end
        ready = ready and blocker ~= nil
        local close = self:_button('close', 20003, function() if self.hud then self.hud.open = false end end)
        if close then
            self:_position(close, hud.panelX + hud.panelW - (hud.closeWidth or 30) * hud.panelScale, hud.panelY)
            self:_size(close, (hud.closeWidth or 30) * hud.panelScale, (hud.headerHeight or 32) * hud.panelScale)
            self:_visible(close, true, true)
        end
        ready = ready and close ~= nil
        for i = 1, #KEYS do
            local key = KEYS[i]
            local row = self:_button('row' .. i, 20002, function()
                if not self.disposed and self.hud then self.hud:setFeature(key, not self.hud.features[key]) end
            end)
            if row then
                self:_position(row, hud.panelX, hud.panelY + ((hud.headerHeight or 32) + (i - 1) * (hud.rowHeight or 26)) * hud.panelScale)
                self:_size(row, hud.panelW, (hud.rowHeight or 26) * hud.panelScale)
                self:_visible(row, true, true)
            end
            ready = ready and row ~= nil
        end
    else
        for name, node in pairs(self.controls) do if name ~= 'menu' then self:_visible(node, false, true) end end
    end
    if self.inputFailed then self:_cancelInput() return false end
    self.inputSupported = ready
    return ready
end

function Adapter:getStatus()
    return {
        ready = self:valid(), widgets = self.total, maxWidgets = self.maxWidgets,
        createdThisFrame = self.createdThisFrame, droppedCommands = self.droppedCommands,
        warming = self.deferred > 0 and self.total < self.maxWidgets,
        error = self.error, errors = self.errors, warning = self.warning, warnings = self.warnings,
        inputSupported = self.inputSupported, dragSupported = self.dragSupported,
        touchMethodAvailable = method(self.pc, 'GetInputTouchState') ~= nil,
        touchTupleAvailable = self.touchTupleAvailable == true, touchTupleObserved = self.touchTupleObserved,
        touchDownObserved = self.touchDownObserved, touchMovementObserved = self.touchMovementObserved,
        menuCaptureObserved = self.menuCaptureObserved, menuMovementObserved = self.menuMovementObserved,
        touchSamples = self.touchSamples, menuCaptures = self.menuCaptures, menuMoves = self.menuMoves,
        clickMoveAvailable = self.clickMoveAvailable == true,
        dragBindingsAvailable = self.dragBindingsSupported == true,
        textBoundsMeasured = self.textMeasured, textBoundsClipped = self.textClipped, textBoundsUnverified = self.textUnverified,
        touchInput = 'PlayerController coordinates; static tuples do not verify drag; use move controls when coordinates are unavailable',
        nativeBindingsVerified = false, captureExclusionSupported = false,
        dotRendering = 'Font glyph; device font metrics unverified'
    }
end

function Adapter:dispose()
    if self.disposed then return end
    self:_cancelInput()
    self.disposed = true
    for i = #self.owned, 1, -1 do self:_remove(self.owned[i]) end
    self.owned = {}
    self.pools = {}
    self.actorGroups = {}
    self.actorByKey = {}
    self.actorFree = {}
    self.currentGroup = nil
    self.controls = {}
    self.root = nil
    self.hud = nil
    self.pc = nil
end
return Adapter
end)()

-- ========================================================================
-- 4. OPTIONAL CAMERA AND BODY COLORS
-- ========================================================================

local HackerVisualFeatures = (function()
local Visual = {}
Visual.__index = Visual
Visual.COLORS = {
    {name='Red',    r=50.00,g=0.10,b=0.14},
    {name='Cyan',   r=0.00,g=1.00,b=50.00},
    {name='Green',  r=0.10,g=50.00,b=0.25},
    {name='Yellow', r=50.00,g=50.00,b=0.05},
    {name='Orange', r=50.00,g=0.45,b=0.05},
    {name='Purple', r=0.62,g=0.25,b=50.00},
    {name='Pink',   r=50.00,g=0.25,b=0.65},
    {name='White',  r=50.00,g=50.00,b=50.00},
    {name='Blue',   r=0.10,g=0.35,b=50.00},
    {name='Lime',   r=0.60,g=50.00,b=0.05},
}
local MAX_ACTORS, WORK_BUDGET = 256, 2
local FOV_INTERVAL, WALL_INTERVAL, FOV_VALUE = 0.2, 0.25, 120
local function finite(v) return type(v) == 'number' and v == v and v > -math.huge and v < math.huge end
local function read(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
end
local function invoke(object, key, ...)
    local fn = read(object, key)
    if type(fn) ~= 'function' then return false end
    local ok, value = pcall(fn, object, ...)
    return ok and value ~= false, value
end
local function static(object, key, ...)
    local fn = read(object, key)
    if type(fn) ~= 'function' then return false end
    local ok, value = pcall(fn, ...)
    return ok and value ~= false, value
end
local function loadNative(env, key, path)
    local value = read(env, key)
    if value ~= nil then return value end
    local import = read(env, 'import')
    if type(import) == 'function' then
        local ok, result = pcall(import, path)
        if ok then return result end
    end
end
local function same(a, b) return finite(a) and finite(b) and math.abs(a - b) < 0.000001 end
local function index(v, fallback)
    if finite(v) and v == math.floor(v) and v >= 1 and v <= #Visual.COLORS then return v end
    return fallback
end

function Visual.new(env)
    return setmetatable({
        env = env or _G, nextFov = 0, nextWall = 0, lastTime = nil,
        fovCamera = nil, fovOriginal = nil, ipadAvailable = nil, wallAvailable = nil,
        fovError = nil, wallError = nil, wallEnabled = false, consoleWorld = nil,
        consoleReady = false, nextConsole = 0, owned = {}, ownedOrder = {}, cursor = 1,
        visibleIndex = 1, occludedIndex = 6, revision = 1, visibleNative = nil,
        occludedNative = nil, processedLastUpdate = 0, coverage = 'body_mesh_only',
        disposed = false
    }, Visual)
end

function Visual:_valid(object)
    if object == nil then return false end
    local ok, valid = static(read(self.env, 'slua'), 'isValid', object)
    if ok and valid == true then return true end
    ok, valid = invoke(read(self.env, 'Game'), 'IsValid', object)
    return ok and valid == true
end

function Visual:_restoreFOV()
    local camera = self.fovCamera
    if camera == nil then return true end
    if not self:_valid(camera) then
        self.fovCamera, self.fovOriginal = nil, nil
        return true
    end
    local current = read(camera, 'FieldOfView')
    if finite(current) and not same(current, FOV_VALUE) then
        self.fovCamera, self.fovOriginal = nil, nil
        return true
    end
    if not same(current, FOV_VALUE) then
        self.fovError = 'iPad view: original FOV restore awaits a readable camera'
        return false
    end
    local original = self.fovOriginal
    local ok = pcall(function() camera.FieldOfView = original end)
    if ok and same(read(camera, 'FieldOfView'), original) then
        self.fovCamera, self.fovOriginal = nil, nil
        self.fovError = nil
        return true
    end
    self.fovError = 'iPad view: original FOV restore failed'
    return false
end

function Visual:_updateFOV(pawn, enabled, now)
    if not enabled then self:_restoreFOV() self.nextFov = 0 return end
    if not self:_valid(pawn) then self:_restoreFOV() return end
    local camera = read(pawn, 'ThirdPersonCameraComponent')
    if self.fovCamera ~= nil and self.fovCamera ~= camera then
        if not self:_restoreFOV() then return end
        self.nextFov = 0
    end
    if now < self.nextFov then return end
    self.nextFov = now + FOV_INTERVAL
    if not self:_valid(camera) then
        self.ipadAvailable = false
        self.fovError = 'iPad view: third-person camera unavailable'
        return
    end
    local aiming = read(pawn, 'bIsWeaponAiming')
    local inVehicle = read(pawn, 'bIsInVehicle')
    local vehicle = read(pawn, 'CurrentVehicle')
    if not self:_valid(vehicle) then
        local ok, value = invoke(pawn, 'GetVehicle')
        if ok then vehicle = value end
    end
    if aiming == true or aiming == 1 or inVehicle == true or inVehicle == 1 or self:_valid(vehicle) then
        self:_restoreFOV()
        return
    end
    local current = read(camera, 'FieldOfView')
    if not finite(current) then
        self.ipadAvailable = false
        self.fovError = 'iPad view: FieldOfView is unreadable'
        return
    end
    if same(current, FOV_VALUE) then
        self.ipadAvailable = true
        self.fovError = nil
        return
    end
    local original = self.fovCamera == camera and self.fovOriginal or current
    local ok = pcall(function() camera.FieldOfView = FOV_VALUE end)
    if ok and same(read(camera, 'FieldOfView'), FOV_VALUE) then
        self.fovCamera, self.fovOriginal = camera, original
        self.ipadAvailable = true
        self.fovError = nil
    else
        if same(read(camera, 'FieldOfView'), FOV_VALUE) then self.fovCamera, self.fovOriginal = camera, original end
        self.ipadAvailable = false
        self.fovError = 'iPad view: FieldOfView write failed'
    end
end

function Visual:_color(which)
    local c = Visual.COLORS[which]
    local ctor = loadNative(self.env, 'FLinearColor', 'LinearColor')
    if ctor ~= nil then
        local ok, value = pcall(function() return ctor(c.r, c.g, c.b, 1) end)
        if ok and value ~= nil then return value end
    end
    return { R = c.r, G = c.g, B = c.b, A = 1 }
end

function Visual:_console(now)
    local ok, world = static(read(self.env, 'slua'), 'getWorld')
    if not ok or world == nil then
        self.wallError = 'Wall color: world unavailable'
        return false
    end
    if self.consoleWorld ~= world then
        self.consoleWorld = world
        self.consoleReady = false
        self.nextConsole = 0
    end
    if self.consoleReady then return true end
    if now < self.nextConsole then return false end
    self.nextConsole = now + 1
    local ksl = loadNative(self.env, 'KismetSystemLibrary', 'KismetSystemLibrary')
    local applied = static(ksl, 'ExecuteConsoleCommand', world, 'r.EnableDrawDyeingColor 1')
    if not applied then
        self.wallAvailable = false
        self.wallError = 'Wall color: dyeing console gate unavailable'
        return false
    end
    self.consoleReady = true
    return true
end

function Visual:_removeEntry(entry)
    if self.owned[entry.actor] == entry then self.owned[entry.actor] = nil end
    for i = #self.ownedOrder, 1, -1 do
        if self.ownedOrder[i] == entry then table.remove(self.ownedOrder, i) break end
    end
end

function Visual:_disable(entry)
    if not entry then return true end
    if not self:_valid(entry.mesh) then self:_removeEntry(entry) return true end
    if invoke(entry.mesh, 'SetDrawDyeing', false) then
        self:_removeEntry(entry)
        return true
    end
    entry.applied = false
    self.wallError = 'Wall color: owned body-mesh cleanup failed'
    return false
end

function Visual:_clearWall()
    for i = #self.ownedOrder, 1, -1 do self:_disable(self.ownedOrder[i]) end
    self.cursor = 1
end

function Visual:_applyActor(actor)
    if not self:_valid(actor) then
        if self.owned[actor] then self:_disable(self.owned[actor]) end
        return
    end
    local mesh = read(actor, 'Mesh')
    local entry = self.owned[actor]
    if entry and entry.mesh ~= mesh then
        if not self:_disable(entry) then return end
        entry = nil
    end
    if not self:_valid(mesh) then return end
    if entry and entry.applied and entry.revision == self.revision then return end
    for _, method in ipairs({ 'SetDrawDyeing', 'SetDrawDyeingMode', 'SetVisibleDyeingColor', 'SetOccludedDyeingColor' }) do
        if type(read(mesh, method)) ~= 'function' then
            if entry then entry.applied = false end
            self.wallAvailable = false
            self.wallError = 'Wall color: body mesh lacks ' .. method
            return
        end
    end
    if entry then entry.applied = false end
    local success = invoke(mesh, 'SetDrawDyeingMode', 1)
        and invoke(mesh, 'SetVisibleDyeingColor', self.visibleNative)
        and invoke(mesh, 'SetOccludedDyeingColor', self.occludedNative)
    if not success then
        self.wallAvailable = false
        self.wallError = 'Wall color: body-mesh color application failed'
        return
    end
    if not entry then
        entry = { actor = actor, mesh = mesh, applied = false, revision = 0 }
        self.owned[actor] = entry
        self.ownedOrder[#self.ownedOrder + 1] = entry
    end
    if not invoke(mesh, 'SetDrawDyeing', true) then
        self.wallAvailable = false
        self.wallError = 'Wall color: body-mesh enable failed'
        self:_disable(entry)
        return
    end
    entry.applied = true
    entry.revision = self.revision
    self.wallAvailable = true
    self.wallError = nil
end

function Visual:_updateWall(pawn, snapshots, enabled, settings, now)
    if not enabled then
        if self.wallEnabled or #self.ownedOrder > 0 then self:_clearWall() end
        self.wallEnabled = false
        self.nextWall = 0
        return
    end
    local vi, oi = index(settings.visibleColor, 1), index(settings.occludedColor, 6)
    if vi ~= self.visibleIndex or oi ~= self.occludedIndex or self.visibleNative == nil then
        self.visibleIndex, self.occludedIndex = vi, oi
        self.visibleNative, self.occludedNative = self:_color(vi), self:_color(oi)
        self.revision = self.revision + 1
    end
    if not self.wallEnabled then self.nextWall = 0 self.cursor = 1 end
    self.wallEnabled = true
    if now < self.nextWall then return end
    self.nextWall = now + WALL_INTERVAL
    local current, actors = {}, {}
    if type(snapshots) == 'table' then
        for i = 1, math.min(#snapshots, MAX_ACTORS) do
            local actor = read(snapshots[i], 'actor')
            if actor ~= nil and actor ~= pawn and not current[actor] then
                current[actor] = true
                actors[#actors + 1] = actor
            end
        end
    end
    local budget = WORK_BUDGET
    for i = #self.ownedOrder, 1, -1 do
        local entry = self.ownedOrder[i]
        if not current[entry.actor] then
            self:_disable(entry)
            budget = budget - 1
            self.processedLastUpdate = self.processedLastUpdate + 1
            if budget == 0 then break end
        end
    end
    if budget == 0 or #actors == 0 then return end
    if not self:_console(now) then return end
    local count = math.min(budget, #actors)
    for _ = 1, count do
        if self.cursor > #actors then self.cursor = 1 end
        local actor = actors[self.cursor]
        self.cursor = self.cursor + 1
        self.processedLastUpdate = self.processedLastUpdate + 1
        if self.owned[actor] or #self.ownedOrder < MAX_ACTORS then self:_applyActor(actor) end
    end
end

function Visual:update(pawn, snapshots, settings, now)
    if self.disposed then return end
    settings = type(settings) == 'table' and settings or {}
    self.processedLastUpdate = 0
    local ipad = settings.ipadView == true
    local wall = settings.wallHack == true
    if not finite(now) or now < 0 then
        if not ipad then self:_restoreFOV() end
        if not wall then self:_clearWall() self.wallEnabled = false end
        return
    end
    if self.lastTime ~= nil and now < self.lastTime then
        self.nextFov, self.nextWall, self.nextConsole = 0, 0, 0
    end
    self.lastTime = now
    self:_updateFOV(pawn, ipad, now)
    self:_updateWall(pawn, snapshots, wall, settings, now)
end

function Visual:dispose()
    self:_restoreFOV()
    self:_clearWall()
    self.wallEnabled = false
    self.disposed = true
end

function Visual:getStatus()
    local applied = 0
    for _, entry in ipairs(self.ownedOrder) do
        if entry.applied and entry.revision == self.revision then applied = applied + 1 end
    end
    return {
        ipadAvailable = self.ipadAvailable, wallAvailable = self.wallAvailable,
        appliedActors = applied, ownedMeshes = #self.ownedOrder,
        lastError = self.wallError or self.fovError, wallCoverage = self.coverage,
        wallStateRestoration = 'owned_dye_flag_off_only',
        processedLastUpdate = self.processedLastUpdate, maxActors = MAX_ACTORS,
        actorsPerUpdate = WORK_BUDGET, wallInterval = WALL_INTERVAL,
        ipadFov = FOV_VALUE, ipadInterval = FOV_INTERVAL,
        pendingFovRestore = self.fovCamera ~= nil and self.disposed,
        pendingWallCleanup = self.disposed and #self.ownedOrder > 0
    }
end

return Visual
end)()

-- ========================================================================
-- 5. OPTIONAL SOURCE-BACKED AIM
-- ========================================================================

local HackerAimFeatures = (function()
local Aim = {}
Aim.__index = Aim
local sqrt, abs, min, max = math.sqrt, math.abs, math.min, math.max
local function finite(value) return type(value) == 'number' and value == value and value > -math.huge and value < math.huge end
local function indexed(object, key) return object[key] end
local function read(object, key)
    if object == nil then return nil end
    local ok, value = pcall(indexed, object, key)
    if ok then return value end
end
local function call(object, key, ...)
    local fn = read(object, key)
    if type(fn) ~= 'function' then return nil end
    local ok, value = pcall(fn, object, ...)
    if ok then return value end
end
local function static(object, key, ...)
    local fn = read(object, key)
    if type(fn) ~= 'function' then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
local function vector(value)
    if finite(read(value, 'X')) and finite(read(value, 'Y')) and finite(read(value, 'Z')) then return value end
end
local function nonzero(value)
    value = vector(value)
    if value and (value.X ~= 0 or value.Y ~= 0 or value.Z ~= 0) then return value end
end
local function import(env, name)
    if env[name] ~= nil then return env[name] end
    if type(env.import) == 'function' then
        local ok, value = pcall(env.import, name)
        if ok then return value end
    end
end
local function wrap(degrees) return (degrees + 180) % 360 - 180 end

function Aim.new(env)
    env = env or _G
    return setmetatable({
        env = env, mathLibrary = import(env, 'KismetMathLibrary'),
        gameplayStatics = env.UGameplayStatics or import(env, 'GameplayStatics'),
        cursor = 1, members = {}, zero = { X = 0, Y = 0, Z = 0 }, candidateBudget = 8, maxSnapshots = 256,
        snapshotMaxAge = .3, lastStatus = 'inactive', processedLastUpdate = 0,
        rotationCalls = 0, assistantAvailable = nil, mortarAvailable = nil, sniperAvailable = nil
    }, Aim)
end

function Aim:_valid(value)
    if value == nil then return false end
    if static(self.env.slua, 'isValid', value) == true then return true end
    return call(self.env.Game, 'IsValid', value) == true
end

function Aim:_clear(reason)
    self.pc, self.pawn, self.weapon, self.world, self.activeMode = nil, nil, nil, nil, nil
    self.target, self.targetRow, self.lastTime = nil, nil, nil
    self.cursor = 1
    for actor in pairs(self.members) do self.members[actor] = nil end
    self.lastStatus = reason or 'inactive'
    return false
end

function Aim:_fail(reason)
    self.target, self.targetRow = nil, nil
    self.lastStatus = reason
    return false
end

function Aim:_weapon(pawn)
    local observed = false
    local getter = read(pawn, 'GetCurrentWeapon')
    if type(getter) == 'function' then
        local ok, current = pcall(getter, pawn)
        if ok then
            observed = true
            if self:_valid(current) then return current end
        end
    end
    local manager = read(pawn, 'WeaponManagerComponent')
    if self:_valid(manager) then
        local current = read(manager, 'CurrentWeapon')
        if current ~= nil then observed = true end
        if self:_valid(current) then return current end
    end
    getter = read(pawn, 'GetCurrentShootWeapon')
    if type(getter) == 'function' then
        local ok, current = pcall(getter, pawn)
        if ok then
            observed = true
            if self:_valid(current) then return current end
        end
    end
    if observed then return nil end
    local replicated = read(manager, 'CurrentWeaponReplicated')
    if self:_valid(replicated) then return replicated end
end

-- Weapon classification is deliberately tolerant: many builds return an asset/class
-- path (e.g. BP_ShootWeapon_M24_C) rather than the short display name.
local SNIPER_NAMES = {
    'kar98', 'kar98k', 'm24', 'awm', 'amr', 'mosin', 'win94',
    'sks', 'slr', 'mini14', 'mini_14', 'mk14', 'qbu', 'mk12', 'vss'
}
local SNIPER_IDS = {
    [103001] = true, [103002] = true, [103003] = true, [103004] = true,
    [103006] = true, [103009] = true, [103012] = true
}
function Aim:_weaponKind(weapon)
    if not self:_valid(weapon) then return 'unknown' end

    local id = call(weapon, 'GetWeaponID') or read(weapon, 'WeaponID') or read(weapon, 'ID')
    if type(id) == 'number' and SNIPER_IDS[id] then return 'sniper' end

    local name = call(weapon, 'GetWeaponName')
    if type(name) ~= 'string' then
        name = read(weapon, 'WeaponName') or read(weapon, 'Name') or ''
    end
    if type(name) ~= 'string' or not name:find('%S') then
        return 'unknown'
    end

    local lower = name:lower():gsub('[%s_%-]', '')
    if lower:find('mortar', 1, true) or lower:find('cối', 1, true) then
        return 'mortar'
    end

    -- Substring matching handles display names, Blueprint names and asset paths.
    for i = 1, #SNIPER_NAMES do
        if lower:find(SNIPER_NAMES[i]:gsub('[%s_%-]', ''), 1, true) then
            return 'sniper'
        end
    end
    return 'other'
end

local function modeAllowed(settings, kind, mode)
    if settings[mode] ~= true then return false end
    if mode == 'mortar' then return kind == 'mortar' end
    if mode == 'sniper' then return kind == 'sniper' end
    if mode == 'force' then return kind ~= 'mortar' end
    return kind == 'other' or (kind == 'sniper' and settings.sniper ~= true)
end

function Aim:_team(actor)
    local team = call(actor, 'GetTeamID') or read(actor, 'TeamID')
    if team ~= nil then return team end
    local state = call(actor, 'GetPlayerStateSafety') or call(actor, 'GetPlayerState') or read(actor, 'PlayerState')
    if self:_valid(state) then return call(state, 'GetTeamID') or read(state, 'TeamID') end
end

function Aim:_alive(actor)
    if not self:_valid(actor) or read(actor, 'bHidden') == true or read(actor, 'bIsDead') == true
        or read(actor, 'bIsDeadFlag') == true or read(read(actor, 'Mesh'), 'bHidden') == true then return false end
    if call(actor, 'IsDead') == true or call(actor, 'IsAlive') == false then return false end
    local health = call(actor, 'GetHealth')
    if health == nil then health = read(actor, 'Health') end
    if health == nil then health = read(actor, 'HP') end
    if health ~= nil then return finite(health) and health > 0 end
    return call(actor, 'IsAlive') == true or call(actor, 'IsDead') == false
end

function Aim:_isBot(actor)
    if read(actor, 'bIsAI') == true or read(actor, 'IsAI') == true or read(actor, 'bIsAIActor') == true then return true end
    local fn = read(actor, 'IsAICharacter')
    if type(fn) == 'function' then
        local ok, result = pcall(fn, actor)
        if ok and result == true then return true end
    end
    fn = read(actor, 'IsBot')
    if type(fn) == 'function' then
        local ok, result = pcall(fn, actor)
        if ok and result == true then return true end
    end
    local state = call(actor, 'GetPlayerStateSafety') or call(actor, 'GetPlayerState') or read(actor, 'PlayerState')
    if self:_valid(state) then
        if read(state, 'bIsBot') == true or read(state, 'bIsAI') == true or read(state, 'bIsABot') == true then return true end
        fn = read(state, 'IsABot')
        if type(fn) == 'function' then
            local ok, result = pcall(fn, state)
            if ok and result == true then return true end
        end
    end
    return false
end

function Aim:_visible(pc, actor)
    if not pc or not actor then return true end
    local fn = read(pc, 'LineOfSightTo')
    if type(fn) ~= 'function' then return true end
    local ok, result = pcall(fn, pc, actor)
    return not ok or result == true
end

function Aim:_candidate(actor, row, pawn, now, settings, pc)
    if type(row) ~= 'table' or row.actor ~= actor or actor == pawn or not self:_alive(actor) then return false end
    if row.alive ~= true or not finite(row.health) or row.health <= 0 then return false end
    if row.updatedAt ~= nil and (not finite(row.updatedAt) or now - row.updatedAt < 0 or now - row.updatedAt > self.snapshotMaxAge) then return false end
    if settings and settings.ignoreKnocked == true and (row.knocked == true or read(actor, 'HealthStatus') == 1) then return false end
    if settings and settings.ignoreBots == true and self:_isBot(actor) then return false end
    if settings and settings.visibility == true and not self:_visible(pc, actor) then return false end
    local mine, theirs = self:_team(pawn), self:_team(actor)
    return mine ~= nil and theirs ~= nil and tostring(mine) ~= tostring(theirs)
end

function Aim:_position(actor, mode)
    if mode == 'force' or mode == 'sniper' then
        local mesh = read(actor, 'Mesh')
        if self:_valid(mesh) then
            -- UE builds differ in socket casing/name. Try the common variants before
            -- falling back to the character bone API.
            local sockets = { 'head', 'Head', 'HEAD', 'head_socket', 'HeadSocket' }
            for i = 1, #sockets do
                local point = nonzero(call(mesh, 'GetSocketLocation', sockets[i]))
                if point then return point end
            end
        end
        return nonzero(call(actor, 'GetBonePos', 'head', self.zero))
            or nonzero(call(actor, 'GetBonePos', 'Head', self.zero))
            or nonzero(call(actor, 'GetSocketLocation', 'head'))
            or nonzero(call(actor, 'GetSocketLocation', 'Head'))
    end
    local point = nonzero(call(actor, 'GetBonePos', 'pelvis', self.zero))
        or nonzero(call(actor, 'GetSocketLocation', 'pelvis'))
    if point then return point end
    if mode == 'mortar' then return vector(call(actor, 'K2_GetActorLocation') or call(actor, 'GetActorLocation')) end
end

function Aim:_score(point, context)
    if not point or type(context.project) ~= 'function' then return nil end
    local ok, x, y, reuse = pcall(context.project, point, self.projected)
    if ok then self.projected = reuse or self.projected end
    if not ok or not finite(x) or not finite(y) or x < 0 or y < 0 or x > context.width or y > context.height then return nil end
    local dx, dy = (x - context.centerX) / context.radius, (y - context.centerY) / context.radius
    local score = dx * dx + dy * dy
    if finite(score) and score <= 1 then return score end
end

function Aim:_geometry(context, now)
    if type(context) ~= 'table' or context.world == nil or not finite(context.snapshotTime)
        or now - context.snapshotTime < 0 or now - context.snapshotTime > self.snapshotMaxAge then return false end
    return finite(context.width) and context.width > 0 and finite(context.height) and context.height > 0
        and finite(context.centerX) and finite(context.centerY) and finite(context.radius) and context.radius > 0
        and type(context.project) == 'function' and type(context.isCurrent) == 'function'
end

function Aim:_current(pc, pawn, weapon, context, mode, settings)
    local ok, current = pcall(context.isCurrent, pc, pawn)
    if not ok or current ~= true or not self:_valid(pc) or not self:_alive(pawn) then return false end
    local world
    if type(context.getWorld) == 'function' then
        local worldOK, value = pcall(context.getWorld)
        if worldOK then world = value end
    else
        world = static(self.env.slua, 'getWorld')
    end
    if world ~= context.world or self:_weapon(pawn) ~= weapon then return false end
    local kind = self:_weaponKind(weapon)
    if not modeAllowed(settings, kind, mode) then return false end
    if mode == 'mortar' then return kind == 'mortar' and read(weapon, 'MortarState') == 2 end
    return (mode == 'force' or read(pawn, 'bIsWeaponAiming') == true) and self:_valid(read(weapon, 'ShootWeaponEntityComp'))
end

function Aim:_select(pawn, snapshots, context, now, mode, pc, settings)
    local total = min(#snapshots, self.maxSnapshots)
    for actor in pairs(self.members) do self.members[actor] = nil end
    for i = 1, total do
        local row = snapshots[i]
        if type(row) == 'table' and row.actor ~= nil then self.members[row.actor] = row end
    end
    local best, bestRow, bestScore = nil, nil, math.huge
    local row = self.target and self.members[self.target]
    if row and self:_candidate(self.target, row, pawn, now, settings, pc) then
        local score = self:_score(self:_position(self.target, mode), context)
        if score then best, bestRow, bestScore = self.target, row, score end
    end
    if mode == 'mortar' and best then return best, bestRow end
    if total == 0 then return nil end
    if self.cursor > total then self.cursor = 1 end
    for _ = 1, min(total, self.candidateBudget) do
        local candidate = snapshots[self.cursor]
        self.cursor = self.cursor % total + 1
        self.processedLastUpdate = self.processedLastUpdate + 1
        local actor = type(candidate) == 'table' and candidate.actor
        if actor and actor ~= best and self:_candidate(actor, candidate, pawn, now, settings, pc) then
            local score = self:_score(self:_position(actor, mode), context)
            if score and score < bestScore then best, bestRow, bestScore = actor, candidate, score end
        end
    end
    return best, bestRow
end

function Aim:_camera(pc)
    local camera = call(pc, 'GetPlayerCameraManager') or read(pc, 'PlayerCameraManager')
    if not self:_valid(camera) then camera = static(self.gameplayStatics, 'GetPlayerCameraManager', pc, 0) end
    if self:_valid(camera) then return vector(call(camera, 'GetCameraLocation')) end
end

local function trajectory(launch, speed, gravity, target)
    local dx = max(500, sqrt((target.X - launch.X) ^ 2 + (target.Y - launch.Y) ^ 2) - 80)
    local dy = target.Z - launch.Z
    local required = gravity * (dy + sqrt(dx * dx + dy * dy))
    if speed * speed < required then speed = sqrt(required) + 100 end
    local v2 = speed * speed
    local discriminant = v2 * v2 - gravity * (gravity * dx * dx + 2 * dy * v2)
    if discriminant >= 0 then
        local radians = math.atan((v2 + sqrt(discriminant)) / (gravity * dx))
        local degrees = math.deg(radians)
        if finite(degrees) and degrees >= 35 and degrees <= 89.5 then
            return true, degrees, dx / (speed * math.cos(radians)), dx
        end
    end
    return false, 45, 0, dx
end
local function solve(launch, target)
    local a, b, c, d = trajectory(launch, 9070, 980 * 2.8, target)
    local e, f, g, h = trajectory(launch, 12520, 980 * 4.0, target)
    local i, j, k, l = trajectory(launch, 16800, 980 * 4.5, target)
    if a and d <= 25000 then return a, b, c, d end
    if e and h <= 40000 then return e, f, g, h end
    if i then return i, j, k, l end
    if a then return a, b, c, d end
    return false, 45, 0, d or h or l or 0
end
local function predict(actor, base, launch)
    local velocity = call(actor, 'GetVelocity')
    local vx, vy = read(velocity, 'X'), read(velocity, 'Y')
    if not finite(vx) or not finite(vy) or abs(vx) + abs(vy) < .01 then return base, nil end
    local predicted = { X = base.X, Y = base.Y, Z = base.Z }
    local previous
    for _ = 1, 2 do
        local ok, angle, flight, distance = solve(launch, predicted)
        if not ok then break end
        previous = { ok, angle, flight, distance }
        if not finite(flight) or flight <= 0 or flight > 15 then break end
        predicted.X, predicted.Y = base.X + vx * flight, base.Y + vy * flight
    end
    return predicted, previous
end

function Aim:_rotation(pc, pawn, target, point, mode, delta)
    local current = call(pc, 'GetControlRotation')
    local pitch, yaw, roll = read(current, 'Pitch'), read(current, 'Yaw'), read(current, 'Roll')
    if not finite(pitch) or not finite(yaw) then return nil, 'rotation_unavailable' end
    if not finite(roll) then roll = 0 end
    if mode == 'assistant' or mode == 'sniper' or mode == 'force' then
        local camera = self:_camera(pc)
        if not camera then return nil, 'camera_unavailable' end
        local desired = static(self.mathLibrary, 'FindLookAtRotation', camera, point)
        local desiredPitch, desiredYaw = read(desired, 'Pitch'), read(desired, 'Yaw')
        if not finite(desiredPitch) or not finite(desiredYaw) then return nil, 'look_at_unavailable' end
        local dp, dy = wrap(desiredPitch - pitch), wrap(desiredYaw - yaw)
        local distance = sqrt(dp * dp + dy * dy)
        local maximum = (mode == 'sniper' and 45 or (mode == 'force' and 120 or 90)) * min(delta, .05)
        local fraction = distance > maximum and maximum / distance or 1
        local ok = pcall(function()
            desired.Pitch = pitch + dp * fraction
            desired.Yaw = yaw + dy * fraction
            desired.Roll = roll
        end)
        if not ok then return nil, 'rotation_unavailable' end
        return desired
    end
    local location = vector(call(pawn, 'K2_GetActorLocation') or call(pawn, 'GetActorLocation'))
    if not location then return nil, 'launch_position_unavailable' end
    local launch = { X = location.X, Y = location.Y, Z = location.Z + 50 }
    local predicted, previous = predict(target, point, launch)
    local ok, angle = solve(launch, predicted)
    if not ok and previous then ok, angle = previous[1], previous[2] end
    if not ok then return nil, 'trajectory_unavailable' end
    local desired = static(self.mathLibrary, 'FindLookAtRotation', self:_camera(pc) or launch, predicted)
    local desiredYaw = read(desired, 'Yaw')
    if not finite(desiredYaw) then return nil, 'look_at_unavailable' end
    local desiredPitch = ((angle - 45) / 43) * 90 - 60
    local final = { Pitch = pitch + wrap(desiredPitch - pitch), Yaw = yaw + wrap(desiredYaw - yaw), Roll = 0 }
    if not finite(final.Pitch) or not finite(final.Yaw) then return nil, 'trajectory_unavailable' end
    return final
end

function Aim:update(pc, pawn, snapshots, settings, now, context)
    self.processedLastUpdate = 0
    settings = settings or {}
    if settings.assistant ~= true and settings.mortar ~= true and settings.sniper ~= true then return self:_clear('inactive') end
    if not finite(now) or not self:_geometry(context, now) then return self:_clear('context_unavailable') end
    if type(snapshots) ~= 'table' or not self:_valid(pc) or not self:_alive(pawn) then return self:_clear('player_or_targets_unavailable') end
    local weapon = self:_weapon(pawn)
    if not self:_valid(weapon) then return self:_clear('weapon_unavailable') end
    local kind = self:_weaponKind(weapon)
    if kind == 'unknown' then return self:_clear('weapon_identity_unavailable') end
    local mode
    if kind == 'mortar' then
        if settings.mortar ~= true then return self:_clear('mortar_disabled') end
        if read(weapon, 'MortarState') ~= 2 then return self:_clear('mortar_not_placed') end
        mode = 'mortar'
    else
        if kind == 'sniper' and settings.sniper == true then
            mode = 'sniper'
        elseif settings.force == true then
            mode = 'force'
        elseif settings.assistant == true then
            mode = 'assistant'
        else
            return self:_clear('assistant_disabled')
        end
        if mode ~= 'force' and read(pawn, 'bIsWeaponAiming') ~= true then return self:_clear('idle_ADS') end
        if not self:_valid(read(weapon, 'ShootWeaponEntityComp')) then return self:_clear('shoot_component_unavailable') end
    end
    if not self:_current(pc, pawn, weapon, context, mode, settings) then return self:_clear('context_changed') end
    local changed = self.pc ~= pc or self.pawn ~= pawn or self.weapon ~= weapon or self.world ~= context.world or self.activeMode ~= mode
    if changed then
        self:_clear('context_changed')
        self.pc, self.pawn, self.weapon, self.world, self.activeMode = pc, pawn, weapon, context.world, mode
    end
    local delta = self.lastTime and now - self.lastTime or 0
    if delta < 0 or delta > self.snapshotMaxAge then
        self:_clear('clock_changed')
        self.pc, self.pawn, self.weapon, self.world, self.activeMode = pc, pawn, weapon, context.world, mode
        delta = 0
    end
    self.lastTime = now
    if mode ~= 'mortar' and delta <= 0 then
        if mode == 'force' then delta = 0.016 else return self:_fail('priming_delta') end
    end
    local width, height, centerX, centerY, radius = context.width, context.height, context.centerX, context.centerY, context.radius
    local target, row = self:_select(pawn, snapshots, context, now, mode, pc, settings)
    if not target then return self:_fail('no_target_in_circle') end
    local point = self:_position(target, mode)
    if not point then return self:_fail('target_position_unavailable') end
    local rotation, reason = self:_rotation(pc, pawn, target, point, mode, delta)
    if not rotation then return self:_fail(reason) end
    if settings[mode] ~= true
        or not self:_geometry(context, now) or not self:_current(pc, pawn, weapon, context, mode, settings)
        or not self:_candidate(target, row, pawn, now, settings, pc) then return self:_fail('context_changed') end
    if context.width ~= width or context.height ~= height or context.centerX ~= centerX
        or context.centerY ~= centerY or context.radius ~= radius then return self:_fail('circle_geometry_changed') end
    local finalPoint = self:_position(target, mode)
    if not self:_score(finalPoint, context) then return self:_fail('target_left_circle') end
    local retained = false
    for i = 1, min(#snapshots, self.maxSnapshots) do
        if snapshots[i] == row and row.actor == target then retained = true break end
    end
    if not retained or settings[mode] ~= true
        or not self:_geometry(context, now) or not self:_current(pc, pawn, weapon, context, mode, settings)
        or not self:_candidate(target, row, pawn, now, settings, pc) then return self:_fail('context_changed') end
    if context.width ~= width or context.height ~= height or context.centerX ~= centerX
        or context.centerY ~= centerY or context.radius ~= radius then return self:_fail('circle_geometry_changed') end
    local fn = read(pc, 'SetControlRotation')
    if type(fn) ~= 'function' then return self:_fail('rotation_unavailable') end
    local ok, accepted = pcall(fn, pc, rotation, mode == 'mortar' and 'MortarAim' or 'CircleAim')
    if not ok or accepted == false then
        self[mode .. 'Available'] = false
        return self:_fail('rotation_rejected')
    end
    self.target, self.targetRow = target, row
    self.rotationCalls = self.rotationCalls + 1
    self.lastStatus = 'rotation_call_accepted'
    self[mode .. 'Available'] = true
    return true
end

function Aim:dispose()
    self:_clear('disposed')
    self.projected = nil
end

function Aim:getStatus()
    return {
        activeMode = self.activeMode, target = self.target, lastStatus = self.lastStatus,
        assistantSupported = true, forceSupported = true, mortarSupported = true,
        touchSimulationSupported = false, sniperSupported = true, throwableSupported = false,
        assistantAvailable = self.assistantAvailable, forceAvailable = self.forceAvailable,
        mortarAvailable = self.mortarAvailable, sniperAvailable = self.sniperAvailable,
        processedLastUpdate = self.processedLastUpdate,
        candidateBudget = self.candidateBudget, rotationCalls = self.rotationCalls,
        mortarPhysicsVerified = false, sniperBallisticCompensation = false, nativeGameVerified = false
    }
end
return Aim
end)()

-- ========================================================================
-- 6. OPTIONAL SMALL CROSSHAIR WEAPON VALUES
-- ========================================================================

local HackerWeaponFeatures = (function()
local Weapon = {}
Weapon.__index = Weapon
local FIELDS = { 'RecoilKickADS', 'GameDeviationFactor', 'GameDeviationAccuracy' }
local VALUE, INTERVAL = .01, .2
local FIREARMS = {
    m416 = true, akm = true, ['scar-l'] = true, m762 = true, aug = true, groza = true,
    qbz = true, mk47 = true, g36c = true, ['honey badger'] = true, famas = true, ['asm abakan'] = true,
    ace32 = true, uzi = true, ump45 = true, vector = true, thompson = true, ['thompson smg'] = true,
    bizon = true, ['pp-19 bizon'] = true, ['pp-19'] = true, mp5k = true, p90 = true,
    kar98 = true, kar98k = true, m24 = true, awm = true, sks = true, vss = true, slr = true, mini14 = true,
    mk14 = true, amr = true, mk12 = true, dsr = true, ['m1 garand'] = true, s686 = true, s1897 = true,
    s12k = true, dbs = true, ns2000 = true, m249 = true, dp28 = true, ['dp-28'] = true, mg3 = true
}
local function finite(value) return type(value) == 'number' and value == value and value > -math.huge and value < math.huge end
local function same(a, b) return finite(a) and finite(b) and math.abs(a - b) < .000001 end
local function read(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
end
local function call(object, key, ...)
    local fn = read(object, key)
    if type(fn) ~= 'function' then return nil end
    local ok, value = pcall(fn, object, ...)
    if ok then return value end
end

function Weapon.new(env)
    return setmetatable({
        env = env or _G, enabled = false, active = false, disposed = false,
        nextCheck = 0, lastTime = nil, pawn = nil, weapon = nil, entry = nil, blockedEntity = nil,
        restoring = false, smallCrosshairAvailable = nil, lastStatus = 'inactive'
    }, Weapon)
end

function Weapon:_valid(object)
    if object == nil then return false end
    local fn = read(read(self.env, 'slua'), 'isValid')
    if type(fn) == 'function' then
        local ok, valid = pcall(fn, object)
        if ok and valid == true then return true end
    end
    return call(read(self.env, 'Game'), 'IsValid', object) == true
end

function Weapon:_currentWeapon(pawn)
    local observed = false
    for _, key in ipairs({ 'GetCurrentWeapon', 'GetCurrentShootWeapon' }) do
        local fn = read(pawn, key)
        if type(fn) == 'function' then
            local ok, current = pcall(fn, pawn)
            if ok then
                observed = true
                if self:_valid(current) then return current end
            end
        end
    end
    local manager = read(pawn, 'WeaponManagerComponent')
    if self:_valid(manager) then
        local current = read(manager, 'CurrentWeapon')
        if current ~= nil then observed = true end
        if self:_valid(current) then return current end
        if not observed then
            local replicated = read(manager, 'CurrentWeaponReplicated')
            if self:_valid(replicated) then return replicated end
        end
    end
end

function Weapon:_firearm(weapon)
    local name = call(weapon, 'GetWeaponName')
    if type(name) ~= 'string' then return false end
    return FIREARMS[name:lower():match('^%s*(.-)%s*$')] == true
end

function Weapon:_ownedCount()
    local count = 0
    if self.entry then
        for i = 1, 3 do if self.entry.owned[FIELDS[i]] then count = count + 1 end end
    end
    return count
end

function Weapon:_restore()
    local entry = self.entry
    self.active = false
    if not entry then self.restoring = false return true end
    if not self:_valid(entry.entity) then self.entry = nil self.restoring = false return true end
    for i = 1, 3 do
        local key = FIELDS[i]
        if entry.owned[key] then
            local value = read(entry.entity, key)
            if same(value, VALUE) then
                pcall(function() entry.entity[key] = entry.original[key] end)
                if same(read(entry.entity, key), entry.original[key]) then entry.owned[key] = nil end
            elseif finite(value) then
                entry.owned[key] = nil
            end
        end
    end
    if self:_ownedCount() == 0 then self.entry = nil self.restoring = false return true end
    self.restoring = true
    return false
end

function Weapon:_stop(reason)
    local restored = self:_restore()
    self.lastStatus = restored and reason or 'restore_pending'
    return false
end

function Weapon:_block(entity, reason)
    self.blockedEntity, self.blockedReason = entity, reason
    self.smallCrosshairAvailable = false
    return self:_stop(reason)
end

function Weapon:_isCurrent(pawn, weapon, entity, settings)
    return settings.smallCrosshair == true and self:_valid(pawn) and self:_valid(weapon)
        and self:_valid(entity) and self:_currentWeapon(pawn) == weapon
        and read(weapon, 'ShootWeaponEntityComp') == entity and self:_firearm(weapon)
end

function Weapon:_apply(pawn, weapon, entity, settings)
    local entry = { entity = entity, original = {}, owned = {} }
    for i = 1, 3 do
        local key = FIELDS[i]
        local value = read(entity, key)
        if not finite(value) then
            self.smallCrosshairAvailable = false
            self.lastStatus = 'source_field_unavailable'
            return false
        end
        entry.original[key] = value
    end
    self.entry = entry
    for i = 1, 3 do
        local key = FIELDS[i]
        if not self:_isCurrent(pawn, weapon, entity, settings) then
            self.smallCrosshairAvailable = false
            return self:_stop('context_changed')
        end
        if not same(read(entity, key), entry.original[key]) then
            return self:_block(entity, 'external_value_changed')
        end
        if not same(entry.original[key], VALUE) then
            entry.owned[key] = true
            local ok = pcall(function() entity[key] = VALUE end)
            if not ok or not same(read(entity, key), VALUE) then
                return self:_block(entity, 'source_write_failed')
            end
        end
    end
    for i = 1, 3 do
        if not same(read(entity, FIELDS[i]), VALUE) then
            return self:_block(entity, 'external_value_changed')
        end
    end
    if not self:_isCurrent(pawn, weapon, entity, settings) then
        self.smallCrosshairAvailable = false
        return self:_stop('context_changed')
    end
    self.active = true
    self.smallCrosshairAvailable = true
    self.lastStatus = 'source_values_verified'
    return true
end

function Weapon:update(pawn, settings, now)
    if self.disposed then return false end
    settings = type(settings) == 'table' and settings or {}
    if settings.smallCrosshair ~= true then
        self.enabled = false
        self.blockedEntity = nil
        self.lastTime = nil
        self.nextCheck = 0
        self.pawn, self.weapon = nil, nil
        return self:_stop('inactive')
    end
    if not finite(now) or now < 0 then
        self.lastTime = nil
        self.nextCheck = 0
        self.weapon = nil
        return self:_stop('clock_unavailable')
    end
    if self.lastTime and now < self.lastTime then
        self.lastTime = now
        self.nextCheck = 0
        self.weapon = nil
        self.blockedEntity = nil
        return self:_stop('clock_changed')
    end
    self.lastTime = now
    if pawn ~= self.pawn then
        self.pawn = pawn
        self.weapon = nil
        self.blockedEntity = nil
        self.nextCheck = 0
        if not self:_restore() then
            self.nextCheck = now + INTERVAL
            self.lastStatus = 'restore_pending'
            return false
        end
    end
    if self.enabled and now < self.nextCheck then return self.active end
    self.enabled = true
    self.nextCheck = now + INTERVAL
    if not self:_valid(pawn) then self.weapon = nil return self:_stop('player_unavailable') end
    local weapon = self:_currentWeapon(pawn)
    if not self:_valid(weapon) or not self:_firearm(weapon) then
        self.weapon = nil
        self.smallCrosshairAvailable = false
        return self:_stop('firearm_unavailable')
    end
    local entity = read(weapon, 'ShootWeaponEntityComp')
    if not self:_valid(entity) then
        self.weapon = nil
        self.smallCrosshairAvailable = false
        return self:_stop('shoot_entity_unavailable')
    end
    if weapon ~= self.weapon then self.blockedEntity = nil end
    if self.restoring or (self.entry and self.entry.entity ~= entity) then
        if not self:_restore() then self.lastStatus = 'restore_pending' return false end
    end
    self.weapon = weapon
    if self.blockedEntity == entity then
        self.active = false
        self.lastStatus = self.blockedReason
        return false
    end
    if self.entry then
        for i = 1, 3 do
            local value = read(entity, FIELDS[i])
            if not same(value, VALUE) then
                return self:_block(entity, finite(value) and 'external_value_changed' or 'source_field_unavailable')
            end
        end
        self.active = true
        self.smallCrosshairAvailable = true
        self.lastStatus = 'source_values_verified'
        return true
    end
    return self:_apply(pawn, weapon, entity, settings)
end

function Weapon:dispose()
    self.disposed = true
    self.enabled = false
    self.blockedEntity = nil
    self.pawn, self.weapon, self.lastTime = nil, nil, nil
    return self:_stop('disposed')
end

function Weapon:getStatus()
    local owned = self:_ownedCount()
    return {
        smallCrosshairSupported = true, smallCrosshairAvailable = self.smallCrosshairAvailable,
        active = self.active, lastStatus = self.lastStatus, ownedFields = owned,
        pendingCleanup = self.restoring and owned or 0, checkInterval = INTERVAL,
        nativeGameVerified = false
    }
end
return Weapon
end)()

-- ========================================================================
-- 7. OPTIONAL LUA INTEGRITY CHECK HOOKS
-- ========================================================================

local HackerBypassFeatures = (function()
local Bypass = {}
Bypass.__index = Bypass
local INTERVAL = 1
local BOOLEAN_KEYS = {
    'CheckMD5', 'CheckFileMD5', 'CheckFileIntegrity', 'VerifyFileIntegrity',
    'VerifyFile', 'VerifyAll', 'VerifyFileSignature', 'VerifySignature', 'slua_verify', 'check_slua_integrity'
}
local SUBSYSTEMS = {
    'MD5CheckSubsystem', 'FileCheckSubsystem', 'AssetCheckSubsystem',
    'IntegrityCheckSubsystem', 'SignatureVerifySubsystem', 'PakCheckSubsystem', 'PakVerifySubsystem'
}
local GROUPS = {
    { kind = 'loaded', name = 'common.file_hash_checker', fallback = 'FileHashChecker', keys = { 'CheckFileMD5', 'VerifyAll' } },
    { kind = 'imported', name = 'CreativeModeBlueprintLibrary', keys = { 'VerifyFileIntegrity' } },
    { kind = 'imported', name = 'STExtraBlueprintFunctionLibrary', fallback = 'STExtra', keys = { 'CheckMD5', 'VerifyFile' } },
    { kind = 'loaded', name = 'TssSdk', fallback = 'TssSdk', keys = { 'VerifyFileSignature', 'CheckIntegrity', 'CheckKernel', 'VerifyBoot' } },
    { kind = 'slua', name = 'loader', keys = { 'verifyBytecode', 'checkIntegrity' } },
    { kind = 'slua', name = 'serialize', keys = { 'check', 'verify' } }
}
for i = 1, #SUBSYSTEMS do
    GROUPS[#GROUPS + 1] = { kind = 'subsystem', name = SUBSYSTEMS[i], keys = BOOLEAN_KEYS }
end
local function finite(value) return type(value) == 'number' and value == value and value > -math.huge and value < math.huge end
local function field(owner, key) return owner[key] end
local function assign(owner, key, value) owner[key] = value end
local function read(owner, key)
    if type(owner) ~= 'table' then return nil end
    local ok, value = pcall(field, owner, key)
    if ok then return value end
end
local function exposed(value) if type(value) == 'table' then return value end end

function Bypass.new(env)
    local slots = {}
    for group = 1, #GROUPS do
        local keys = GROUPS[group].keys
        for i = 1, #keys do slots[#slots + 1] = { group = group, key = keys[i] } end
    end
    return setmetatable({
        env = env or _G, slots = slots, settings = nil, requested = false,
        enabled = false, active = false, disposed = false, nextCheck = 0, lastTime = nil,
        bypassAvailable = nil, lastStatus = 'inactive', matchedSlots = 0,
        reconcileCount = 0, updating = false
    }, Bypass)
end

function Bypass:_wanted()
    return not self.disposed and type(self.settings) == 'table' and self.settings.bypass == true
end

function Bypass:_owners()
    local result = {}
    local loaded = read(read(self.env, 'package'), 'loaded')
    for i = 1, #GROUPS do
        local group = GROUPS[i]
        local owner
        if group.kind == 'loaded' then
            owner = exposed(read(loaded, group.name)) or exposed(read(self.env, group.fallback))
        elseif group.kind == 'slua' then
            owner = exposed(read(read(self.env, 'slua'), group.name))
        elseif group.kind == 'subsystem' then
            owner = exposed(read(self.env, group.name)) or exposed(read(loaded, group.name))
        else
            owner = exposed(read(self.env, group.name))
            if not owner then
                local importer = read(self.env, 'import')
                if type(importer) == 'function' then
                    local ok, value = pcall(importer, group.name)
                    if ok then owner = exposed(value) end
                end
            end
            if not owner and group.fallback then owner = exposed(read(self.env, group.fallback)) end
        end
        result[i] = owner
    end
    return result
end

function Bypass:_recordCount()
    local count = 0
    for i = 1, #self.slots do if self.slots[i].record then count = count + 1 end end
    return count
end

function Bypass:_findRecord(owner, key)
    for i = 1, #self.slots do
        local record = self.slots[i].record
        if record and record.owner == owner and record.key == key then return record end
    end
end

function Bypass:_blocked(owner, key)
    for i = 1, #self.slots do
        local slot = self.slots[i]
        if slot.blockedOwner == owner and slot.key == key then return true end
    end
    return false
end

function Bypass:_stillBound(owners, owner, key)
    for i = 1, #self.slots do
        local slot = self.slots[i]
        if slot.key == key and owners[slot.group] == owner then return true end
    end
    return false
end

function Bypass:_restoreSlot(slot)
    local record = slot.record
    if not record then return true end
    record.active = false
    local ok, current = pcall(field, record.owner, record.key)
    if not ok then return false end
    if current == record.wrapper then
        pcall(assign, record.owner, record.key, record.original)
        ok, current = pcall(field, record.owner, record.key)
        if not ok or current == record.wrapper then return false end
    end
    if current ~= record.original then
        slot.blockedOwner, slot.blockReason = record.owner, 'external_replacement'
    end
    slot.record = nil
    return true
end

function Bypass:_restoreAll()
    self.enabled, self.active = false, false
    for i = 1, #self.slots do
        local record = self.slots[i].record
        if record then record.active = false end
    end
    local restored = true
    for i = #self.slots, 1, -1 do
        if not self:_restoreSlot(self.slots[i]) then restored = false end
    end
    return restored
end

function Bypass:_stop(reason)
    local restored = self:_restoreAll()
    self.bypassAvailable = false
    self.lastStatus = restored and reason or 'restore_pending'
    return false
end

function Bypass:_reconcile()
    self.reconcileCount = self.reconcileCount + 1
    self.enabled, self.active = false, false
    local owners = self:_owners()
    self.matchedSlots = 0
    for i = 1, #self.slots do
        local slot = self.slots[i]
        local record = slot.record
        if record then
            local ok, current = pcall(field, record.owner, record.key)
            if not ok then return self:_stop('export_read_failed') end
            if current ~= record.wrapper then
                record.active = false
                slot.record = nil
                slot.blockedOwner, slot.blockReason = record.owner, 'external_replacement'
            elseif owners[slot.group] ~= record.owner then
                if not self:_restoreSlot(slot) then return self:_stop('restore_pending') end
            end
        end
    end
    if not self:_wanted() then return self:_stop('inactive') end
    for i = 1, #self.slots do
        local slot = self.slots[i]
        local owner = owners[slot.group]
        if slot.blockedOwner and not self:_stillBound(owners, slot.blockedOwner, slot.key) then
            slot.blockedOwner, slot.blockReason = nil, nil
        end
        if owner and not self:_blocked(owner, slot.key) then
            local current = read(owner, slot.key)
            if type(current) == 'function' then
                self.matchedSlots = self.matchedSlots + 1
                if not self:_findRecord(owner, slot.key) then
                    local record = { owner = owner, key = slot.key, original = current, active = false }
                    local orig = current
                    record.wrapper = function(...)
                        if record.active and self.enabled then return true end
                        return orig(...)
                    end
                    slot.record = record
                    local ok = pcall(assign, owner, slot.key, record.wrapper)
                    local readOK, value = pcall(field, owner, slot.key)
                    if not ok or not readOK or value ~= record.wrapper then
                        slot.blockedOwner, slot.blockReason = owner, 'install_failed'
                        return self:_stop('install_failed')
                    end
                    if not self:_wanted() then return self:_stop('inactive') end
                end
            end
        end
    end
    for i = 1, #self.slots do
        local slot = self.slots[i]
        local record = slot.record
        if record then
            local ok, current = pcall(field, record.owner, record.key)
            if not ok then return self:_stop('export_read_failed') end
            if current ~= record.wrapper then
                record.active = false
                slot.record = nil
                slot.blockedOwner, slot.blockReason = record.owner, 'external_replacement'
                return self:_stop('external_replacement')
            end
        end
    end
    if not self:_wanted() then return self:_stop('inactive') end
    local count = self:_recordCount()
    if count > 0 then
        local currentOwners = self:_owners()
        for i = 1, #self.slots do
            local slot = self.slots[i]
            local record = slot.record
            if record and currentOwners[slot.group] ~= record.owner then
                return self:_stop('binding_changed')
            end
        end
        if not self:_wanted() then return self:_stop('inactive') end
    end
    self.enabled = count > 0
    self.active = self.enabled
    self.bypassAvailable = self.active
    for i = 1, #self.slots do
        local record = self.slots[i].record
        if record then record.active = self.enabled end
    end
    self.lastStatus = count == 0 and 'no_lua_boolean_exports'
        or (self.matchedSlots < #self.slots and 'partial_lua_boolean_exports' or 'lua_boolean_exports_installed')
    return self.active
end

function Bypass:update(settings, now)
    if self.disposed or self.updating then return false end
    local previous = self.requested
    self.settings = type(settings) == 'table' and settings or nil
    self.requested = self:_wanted()
    if not self.requested then
        self.enabled, self.active = false, false
        if previous then
            for i = 1, #self.slots do
                local slot = self.slots[i]
                if slot.blockReason == 'install_failed' then slot.blockedOwner, slot.blockReason = nil, nil end
            end
        end
        if self:_recordCount() == 0 then self.lastStatus = 'inactive' return false end
        if previous or (finite(now) and now >= self.nextCheck) then
            if finite(now) then self.nextCheck = now + INTERVAL end
            return self:_stop('inactive')
        end
        return false
    end
    if not finite(now) then
        if self.enabled or not previous then return self:_stop('clock_unavailable') end
        self.lastStatus = self:_recordCount() > 0 and 'restore_pending' or 'clock_unavailable'
        return false
    end
    if self.lastTime and now < self.lastTime then
        self.lastTime, self.nextCheck = now, now + INTERVAL
        return self.active
    end
    self.lastTime = now
    if not previous then self.nextCheck = now end
    if now < self.nextCheck then return self.active end
    self.nextCheck = now + INTERVAL
    if not self.enabled and self:_recordCount() > 0 and not self:_restoreAll() then
        self.lastStatus = 'restore_pending'
        return false
    end
    self.updating = true
    local ok, value = pcall(self._reconcile, self)
    self.updating = false
    if not ok then return self:_stop('reconcile_failed') end
    return value
end

function Bypass:dispose()
    self.disposed, self.requested, self.enabled = true, false, false
    self.settings = nil
    local restored = self:_restoreAll()
    self.bypassAvailable = false
    self.lastStatus = restored and 'disposed' or 'restore_pending'
    return restored
end

function Bypass:getStatus()
    local count = self:_recordCount()
    local conflicts = 0
    for i = 1, #self.slots do if self.slots[i].blockedOwner then conflicts = conflicts + 1 end end
    local active = self.enabled and self:_wanted() and count > 0
    return {
        enabled = self.requested, active = active, bypassAvailable = self.bypassAvailable,
        lastStatus = self.lastStatus, ownedHooks = count, installedCount = count,
        appliedHooks = active and count or 0, pendingCleanup = not active and count or 0,
        restorePending = not active and count > 0, configuredSlots = #self.slots,
        matchedSlots = self.matchedSlots, blockedSlots = conflicts, reconcileCount = self.reconcileCount,
        coverage = 'lua_boolean_exports_only', sourceMigration = 'partial',
        nativeInterceptionVerified = false, serverVerification = false
    }
end

return Bypass
end)()

-- ========================================================================
-- 8. LOGIN CONFIGURATION
-- ========================================================================

local HackerLicenseConfig = nil  -- License system disabled

-- ========================================================================
-- 9. LOGIN, EXPIRY AND TOKEN VALIDATION
-- ========================================================================

local HackerLicenseCore = (function()
local Primitives = (function()
local floor, abs, max = math.floor, math.abs, math.max
local byte, char, format = string.byte, string.char, string.format
local U32 = 4294967296
local AND, XOR = {}, {}
for a = 0, 15 do
    for b = 0, 15 do
        local av, bv, both, different, place = a, b, 0, 0, 1
        for _ = 1, 4 do
            local x, y = av % 2, bv % 2
            if x == 1 and y == 1 then both = both + place end
            if x ~= y then different = different + place end
            av, bv, place = floor(av / 2), floor(bv / 2), place * 2
        end
        AND[a * 16 + b], XOR[a * 16 + b] = both, different
    end
end
local function bitop(a, b, lookup)
    local value, place = 0, 1
    for _ = 1, 8 do
        value = value + lookup[(a % 16) * 16 + b % 16] * place
        a, b, place = floor(a / 16), floor(b / 16), place * 16
    end
    return value
end
local function band(a, b) return bitop(a, b, AND) end
local function bxor(a, b) return bitop(a, b, XOR) end
local function rol(value, amount)
    local divisor = 2 ^ (32 - amount)
    return (value % divisor) * 2 ^ amount + floor(value / divisor)
end
local function little32(value)
    return char(value % 256, floor(value / 256) % 256,
        floor(value / 65536) % 256, floor(value / 16777216) % 256)
end
local K = {
    0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
    0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
    0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
    0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
    0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
    0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
    0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
    0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
}
local SHIFT = { 7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21 }
local function md5_raw(input)
    assert(type(input) == "string", "MD5 input must be a string")
    local size = #input
    local message = input .. char(128) .. string.rep(char(0), (55 - size) % 64)
        .. little32((size * 8) % U32) .. little32(floor(size / 536870912))
    local h0, h1, h2, h3 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
    local words = {}
    for offset = 1, #message, 64 do
        for j = 0, 15 do
            local a, b, c, d = byte(message, offset + j * 4, offset + j * 4 + 3)
            words[j] = a + b * 256 + c * 65536 + d * 16777216
        end
        local a, b, c, d = h0, h1, h2, h3
        for i = 0, 63 do
            local f, g, shiftBase
            if i < 16 then
                f, g, shiftBase = band(b, c) + band(U32 - 1 - b, d), i, 0
            elseif i < 32 then
                f, g, shiftBase = band(d, b) + band(U32 - 1 - d, c), (5 * i + 1) % 16, 4
            elseif i < 48 then
                f, g, shiftBase = bxor(bxor(b, c), d), (3 * i + 5) % 16, 8
            else
                local bOrNotD = U32 - 1 - band(U32 - 1 - b, d)
                f, g, shiftBase = bxor(c, bOrNotD), (7 * i) % 16, 12
            end
            local nextB = (b + rol((a + f + K[i + 1] + words[g]) % U32,
                SHIFT[shiftBase + i % 4 + 1])) % U32
            a, b, c, d = d, nextB, b, c
        end
        h0, h1, h2, h3 = (h0 + a) % U32, (h1 + b) % U32, (h2 + c) % U32, (h3 + d) % U32
    end
    return little32(h0) .. little32(h1) .. little32(h2) .. little32(h3)
end
local function hex(input)
    return (input:gsub(".", function(c) return format("%02x", byte(c)) end))
end
local function md5(input) return hex(md5_raw(input)) end
local function form_encode(input)
    assert(type(input) == "string", "Form value must be a string")
    return (input:gsub("[^A-Za-z0-9%-%._~ ]", function(c)
        return format("%%%02X", byte(c))
    end):gsub(" ", "+"))
end
local function constant_time_equal(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    local difference = abs(#a - #b)
    for i = 1, max(#a, #b) do
        difference = difference + abs((byte(a, i) or 0) - (byte(b, i) or 0))
    end
    return difference == 0
end
local function name_uuid(input)
    local digest = md5_raw(input)
    local h = hex(digest:sub(1, 6) .. char(byte(digest, 7) % 16 + 48)
        .. digest:sub(8, 8) .. char(byte(digest, 9) % 64 + 128) .. digest:sub(10))
    return h:sub(1, 8) .. "-" .. h:sub(9, 12) .. "-" .. h:sub(13, 16)
        .. "-" .. h:sub(17, 20) .. "-" .. h:sub(21, 32)
end
return {
    md5 = md5, md5_raw = md5_raw, form_encode = form_encode,
    constant_time_equal = constant_time_equal, name_uuid = name_uuid
}
end)()
local CreateLocalExpiry = (function()
return function(cfg, wallReader)
    local E = {}
    local expiredText = 'Mod expired. DM @GRW_XD for the renewal.'
    local tamperText = "Don't be over smart"
    local blockedMessage, blockedPhase
    local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
    local function parse(text)
        if type(text) ~= 'string' then return nil end
        local y, m, d, h, n, s = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$')
        y, m, d, h, n, s = tonumber(y), tonumber(m), tonumber(d), tonumber(h), tonumber(n), tonumber(s)
        if not y or y < 1970 or y > 9999 or m < 1 or m > 12 or h > 23 or n > 59 or s > 59 then return nil end
        local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
        local months = { 31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
        if d < 1 or d > months[m] then return nil end
        local prior = y - 1
        local days = 365 * (y - 1970) + math.floor(prior / 4) - math.floor(1969 / 4)
            - math.floor(prior / 100) + math.floor(1969 / 100) + math.floor(prior / 400) - math.floor(1969 / 400)
        for i = 1, m - 1 do days = days + months[i] end
        return (days + d - 1) * 86400 + h * 3600 + n * 60 + s - 6 * 3600
    end
    local configured = type(cfg.manualExpiry) == 'string' and cfg.manualExpiry:match('^%s*(.-)%s*$') or cfg.manualExpiry
    local expiry = parse(configured)
    local skew = cfg.clockSkew or 120
    if configured ~= nil and configured ~= '' and not expiry then
        blockedMessage, blockedPhase = 'Invalid local expiry date. Use YYYY-MM-DD HH:MM:SS.', 'error'
    end
    local function block(message, phase)
        if not blockedMessage then blockedMessage, blockedPhase = message, phase end
        return false, blockedMessage, blockedPhase
    end
    function E.Status() return not blockedMessage, blockedMessage, blockedPhase end
    function E.MarkTampered() return block(tamperText, 'tampered') end
    function E.GetExpiry() return expiry end
    function E.Accept(server, now, world, phone, rtt)
        if blockedMessage then return E.Status() end
        if not finite(server) or not finite(now) or now < 0 or world == nil
            or not finite(rtt) or rtt < 0 or not finite(phone) then
            return block('Clock verification unavailable.', 'error')
        end
        if math.abs(phone - server) > skew + rtt then return E.MarkTampered() end
        if expiry and server + rtt >= expiry then return block(expiredText, 'expired') end
        return true
    end
    return E
end
end)()
local CreateAuth = (function()
return function(P, cfg, deps)
    local A = {}
    local phase, message = 'locked', 'Enter your key to sign in.'
    local allowed, pending, generation = false, nil, 0
    local expiresAt
    local lastRequestLatencyMs, lastResponseTime, lastResponseWorld
    local startFn, stopFn, payloadStarted, restartRequired
    local localExpiry = deps.localExpiry
    if localExpiry then
        local ok, text, state = localExpiry.Status()
        if not ok then message, phase = text, state end
    end
    local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
    local function readClock()
        local ok, n, w = pcall(deps.clock)
        if ok and finite(n) and n >= 0 and w ~= nil then return n, w end
    end
    local function notify(text, state)
        message, phase = text, state
        if type(deps.status) == 'function' then pcall(deps.status, text, state) end
    end
    local function stopPayload()
        if payloadStarted then
            payloadStarted = false
            local ok, accepted = pcall(stopFn)
            if not ok or accepted == false then restartRequired = true end
        end
    end
    local function revoke(text, state)
        generation = generation + 1
        allowed, pending, expiresAt = false, nil, nil
        lastRequestLatencyMs, lastResponseTime, lastResponseWorld = nil, nil, nil
        stopPayload()
        -- Any real auth rejection/expiry invalidates the in-memory session.
        pcall(function() _G.__SAMEERSession = nil end)
        local localDenied = false
        if localExpiry then
            local ok, localText, localPhase = localExpiry.Status()
            if not ok then text, state, localDenied = localText, localPhase, true end
        end
        notify(restartRequired and not localDenied and 'Restart required: payload cleanup failed.' or text, state or 'error')
    end
    local function startPayload()
        if payloadStarted or not startFn then return true end
        payloadStarted = true
        local before = generation
        local ok, accepted = pcall(startFn)
        if not ok or accepted == false then
            restartRequired = true
            revoke('Restart required: offline script startup failed.', 'error')
            return false
        end
        return generation == before and allowed
    end
    local function denyReason(reason)
        if type(reason) ~= 'string' then return 'Expired' end
        local lower = reason:sub(1, 120):lower():gsub('[_%s%-]+', ' ')
        if lower == 'max devices' or lower == 'maximum devices' or lower == 'max devices reached' then
            return 'Max Devices'
        end
        local clean = reason
        for _, field in ipairs({ 'key', 'serial' }) do
            if pending and type(pending[field]) == 'string' and #pending[field] > 0 then
                local needle = pending[field]:gsub('([^%w])', '%%%1')
                clean = clean:gsub(needle, '[' .. field .. ']')
            end
        end
        if type(cfg.secret) == 'string' and #cfg.secret > 0 then
            clean = clean:gsub(cfg.secret:gsub('([^%w])', '%%%1'), '[credential]')
        end
        clean = clean:gsub('[%c]', ' '):sub(1, 120)
        return clean == '' and 'Expired' or ('Expired: ' .. clean)
    end
    local function configuredExpiry(result)
        if cfg.expiryPath == nil then return nil, true end
        if type(cfg.expiryPath) ~= 'table' or #cfg.expiryPath == 0 then return nil, false end
        local v = result
        for _, name in ipairs(cfg.expiryPath) do
            if type(v) ~= 'table' then return nil, false end
            v = rawget(v, name)
        end
        return v, finite(v) and v > 0 and v % 1 == 0
    end
    local function begin(key)
        if restartRequired or pending then return false end
        if localExpiry then
            local ok, text, state = localExpiry.Status()
            if not ok then revoke(text, state) return false end
        end
        if type(key) ~= 'string' then key = '' end
        key = key:match('^%s*(.-)%s*$')
        if #key == 0 or #key > 512 then
            revoke('Expired: enter a valid key.', 'denied')
            return false
        end
        local now, world = readClock()
        if not now then revoke('Game clock unavailable. Try again in a match.', 'error') return false end
        local okSerial, serial = pcall(deps.serial, key)
        if not okSerial or type(serial) ~= 'string' or #serial == 0 or #serial > 512 then
            revoke('Device identifier unavailable.', 'error')
            return false
        end
        generation = generation + 1
        local requestId = generation
        pending = { id = requestId, key = key, serial = serial, started = now, world = world, deadline = now + cfg.timeout }
        notify('Signing in...', 'pending')
        if not pending or pending.id ~= requestId or generation ~= requestId then return false end
        local body = 'game=' .. P.form_encode(cfg.game) .. '&user_key=' .. P.form_encode(key) .. '&serial=' .. P.form_encode(serial)
        local function received(success, raw)
            if not pending or pending.id ~= requestId or generation ~= requestId then return end
            local current, worldNow = readClock()
            if not current or worldNow ~= pending.world or current < pending.started or current >= pending.deadline then
                revoke('Request expired. Please sign in again.', 'error')
                return
            end
            if success ~= true or type(raw) ~= 'string' or #raw == 0 or #raw > 32768 then
                revoke('Connection failed. Please try again.', 'error')
                return
            end
            local ok, result = pcall(deps.decode, raw)
            if not ok or type(result) ~= 'table' then revoke('Invalid server response.', 'error') return end
            if result.status ~= true then revoke(denyReason(result.reason), 'denied') return end
            local data = result.data
            if type(data) ~= 'table' or type(data.token) ~= 'string' or #data.token ~= 32
                or not data.token:match('^[%x]+$') or not finite(data.rng) or data.rng % 1 ~= 0 then
                revoke('Incomplete server response.', 'error')
                return
            end
            local expected = P.md5(cfg.game .. '-' .. key .. '-' .. serial .. '-' .. cfg.secret)
            if not P.constant_time_equal(data.token:lower(), expected) then
                revoke('Server token verification failed.', 'denied')
                return
            end
            local okWall, wall = pcall(deps.wall)
            if not okWall or not finite(wall) then
                revoke('Phone clock unavailable.', 'error')
                return
            end
            if localExpiry then
                local accepted, text, state = localExpiry.Accept(data.rng, current, worldNow, wall, current - pending.started)
                if not accepted then revoke(text, state) return end
            elseif math.abs(wall - data.rng) > cfg.clockSkew then
                revoke('Phone/server clock mismatch. Check automatic time.', 'error')
                return
            end
            local expiry, validExpiry = configuredExpiry(result)
            if not validExpiry then
                revoke('Configured server expiry field is missing or invalid.', 'error')
                return
            end
            if expiry and expiry - data.rng - (current - pending.started) <= 0 then
                revoke('Expired', 'denied')
                return
            end
            local fixedExpiry = localExpiry and localExpiry.GetExpiry()
            if fixedExpiry then expiry = math.min(expiry or fixedExpiry, fixedExpiry) end
            lastRequestLatencyMs = (current - pending.started) * 1000
            lastResponseTime, lastResponseWorld = current, worldNow
            pending = nil
            allowed, expiresAt = true, expiry
            -- Keep the authenticated session in process memory so match/world
            -- transitions do not ask the user to enter the key again.
            -- _G is intentionally not persisted to disk; a fresh game process
            -- starts with no session and will ask for the key again.
            pcall(function()
                local registry = _G
                registry.__SAMEERSession = {
                    key = key,
                    expiresAt = expiry,
                    authenticatedAt = wall
                }
            end)
            if not startPayload() then
                pcall(function() _G.__SAMEERSession = nil end)
                return
            end
            notify('Login successful.', 'active')
        end
        local ok, accepted = pcall(deps.post, cfg.url, { ['Content-Type'] = 'application/x-www-form-urlencoded' }, body, received, cfg.timeout)
        if not ok or accepted == false then
            revoke('HTTP request could not start.', 'error')
            return false
        end
        return true
    end
    function A.Login(key)
        if allowed then return false end
        return begin(key)
    end
    function A.Tick()
        if not pending then return end
        local now, world = readClock()
        if not now or world ~= pending.world or now < pending.started then
            revoke('Login interrupted by map loading. Please try again when ready.', 'locked')
            return
        end
        if now >= pending.deadline then revoke('Request timed out. Please try again.', 'error') end
    end
    function A.IsAuthorized() return allowed and not restartRequired end
    function A.Logout() revoke('Expired: signed out.', 'locked') end
    function A.FailClosed(text, requiresRestart)
        if requiresRestart == true then restartRequired = true end
        revoke(text or 'Online access unavailable.', 'error')
    end
    function A.ReportClockTampering()
        if localExpiry then localExpiry.MarkTampered() end
        revoke("Don't be over smart", 'tampered')
    end
    function A.Bind(onStart, onStop)
        if type(onStart) ~= 'function' or type(onStop) ~= 'function' then return false, 'START_AND_STOP_REQUIRED' end
        if startFn and (startFn ~= onStart or stopFn ~= onStop) then return false, 'ALREADY_BOUND' end
        startFn, stopFn = onStart, onStop
        if A.IsAuthorized() then return startPayload() end
        return true
    end
    function A.Unbind()
        revoke('Offline script disconnected.', 'locked')
        startFn, stopFn = nil, nil
    end
    function A.GetRemainingSeconds() return nil end
    function A.GetState()
        local authorized = A.IsAuthorized()
        local sample, age
        if authorized and lastRequestLatencyMs ~= nil then
            local now, world = readClock()
            if now and world == lastResponseWorld and now >= lastResponseTime then
                sample, age = lastRequestLatencyMs, now - lastResponseTime
            end
        end
        return {
            phase = phase, message = message, authorized = authorized, sessionAuthorized = authorized, expiresAt = expiresAt,
            accessPolicy = "game_session", expiryCheckPolicy = "login_only", periodicRecheck = false,
            pending = pending ~= nil, linked = startFn ~= nil, restartRequired = restartRequired == true,
            lastRequestLatencyMs = sample, lastRequestLatencyAgeSeconds = age,
            latencyScope = "license_http_round_trip"
        }
    end
    return A
end
end)()
local Core = { Primitives = Primitives, createExpiry = CreateLocalExpiry }
function Core.new(config, dependencies)
    assert(type(config) == 'table' and type(dependencies) == 'table', 'License configuration and dependencies required')
    local deps = {}
    for key, value in pairs(dependencies) do deps[key] = value end
    if deps.localExpiry == nil then deps.localExpiry = CreateLocalExpiry(config, deps.wall) end
    return CreateAuth(Primitives, config, deps)
end
return Core
end)()

-- ========================================================================
-- 10. KEY LOGIN PANEL
-- ========================================================================

local HackerLoginUI = (function()
local Module = {}
function Module.new(env)
    env = env or _G
    local require = env.require or require
    local function global(name)
        local ok, value = pcall(function() return env[name] end)
        if ok then return value end
    end
    local UI = { _status = "Enter your key", _busy = false, _data = nil }
    local function member(object, name)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[name] end)
        if ok then return value end
    end
    local function valid(object)
        local check = member(global("slua"), "isValid")
        if object == nil then return false end
        if type(check) == 'function' then
            local ok, result = pcall(check, object)
            if ok and result == true then return true end
        end
        local game = global('Game')
        local fallback = member(game, 'IsValid')
        if type(fallback) == 'function' then
            local ok, result = pcall(fallback, game, object)
            return ok and result == true
        end
        return false
    end
    local function imported(name)
        local loader = global("import")
        if type(loader) ~= "function" then return nil end
        local ok, result = pcall(loader, name)
        if ok then return result end
    end
    local function construct(class, ...)
        if class == nil then return nil end
        local ok, result = pcall(class, ...)
        if ok then return result end
    end
    local function vector(x, y)
        return construct(global("FVector2D") or imported("Vector2D"), x, y)
            or { X = x, Y = y }
    end
    local function color(r, g, b, a)
        return construct(global("FLinearColor") or imported("LinearColor"), r, g, b, a)
            or { R = r, G = g, B = b, A = a }
    end
    local function visibility(widget, value)
        local setter = member(widget, "SetWidgetVisibility") or member(widget, "SetVisibility")
        assert(type(setter) == "function", "UI_VISIBILITY_UNAVAILABLE")
        setter(widget, value)
    end
    local function setTextStyle(widget, size, textColor)
        pcall(function()
            local font = widget.Font
            if font then
                font.Size = math.max(1, math.floor(size * (UI._scale or 1) + 0.5))
                local assigned = pcall(function() widget.Font = font end)
                if not assigned then widget:SetFont(font) end
            end
        end)
        pcall(function() widget:SetAutoWrapText(true) end)
        pcall(function()
            local slate = construct(imported("SlateColor"), textColor)
            if slate then widget:SetColorAndOpacity(slate) end
        end)
    end
    local function detach(data)
        if not data then return end
        data.visible = false
        pcall(function() if valid(data.input) then data.input:SetText("") end end)
        if data.event and data.eventHandle ~= nil then
            pcall(function() data.event:Remove(data.eventHandle) end)
        end
        if valid(data.container) then
            pcall(function() data.container:RemoveFromParent() end)
        end
        if valid(data.modalBlocker) then
            pcall(function() data.modalBlocker:RemoveFromParent() end)
        end
        data.onSubmit = nil
    end
    function UI.Destroy()
        local previous = UI._data
        UI._data = nil
        detach(previous)
    end
    function UI.Hide()
        local data = UI._data
        if not data or data.hiddenApplied then return true end
        data.visible = false
        local ok = pcall(function()
            if valid(data.input) then data.input:SetText("") end
            if valid(data.container) then visibility(data.container, data.hidden) end
            if valid(data.modalBlocker) then visibility(data.modalBlocker, data.hidden) end
        end)
        if ok then data.hiddenApplied = true end
        return ok
    end
    function UI.SetStatus(message)
        UI._status = type(message) == "string" and message:sub(1, 160) or "Login unavailable"
        local data = UI._data
        if data and data.deliveredStatus == UI._status then return true end
        if data and valid(data.status) then
            local ok = pcall(function() data.status:SetText(UI._status) end)
            if ok then data.deliveredStatus = UI._status end
            return ok
        end
        return false
    end
    function UI.SetBusy(busy)
        UI._busy = busy == true
        local data = UI._data
        if data then
            if data.deliveredBusy == UI._busy then return true end
            local buttonOK = pcall(function() data.button:SetIsEnabled(not UI._busy) end)
            local inputOK = pcall(function() data.input:SetIsEnabled(not UI._busy) end)
            if buttonOK and inputOK then
                data.deliveredBusy = UI._busy
                return true
            end
        end
        return false
    end
    function UI.Animate(now)
        local data = UI._data
        if not data or not data.visible then return false end
        if type(now) ~= "number" then return false end

        -- Smooth border animation: cyan -> violet -> cyan.
        local wave = 0.5 + 0.5 * math.sin(now * 2.35)
        local wave2 = 0.5 + 0.5 * math.sin(now * 2.35 + math.pi * 0.5)
        local cyanA = 0.68 + wave * 0.32
        local violetA = 0.58 + wave2 * 0.42

        pcall(function()
            if valid(data.accent) then
                data.accent:SetBrushColor(color(0.10, 0.88, 1.0, cyanA))
            end
            if valid(data.bottomGlow) then
                data.bottomGlow:SetBrushColor(color(0.72, 0.18, 1.0, violetA))
            end
            if valid(data.leftGlow) then
                data.leftGlow:SetBrushColor(color(0.72, 0.18, 1.0, violetA))
            end
            if valid(data.rightGlow) then
                data.rightGlow:SetBrushColor(color(0.05, 0.95, 0.95, cyanA))
            end
            if valid(data.cardEdge) then
                data.cardEdge:SetBrushColor(color(0.68, 0.20, 1.0, 0.28 + wave * 0.42))
            end
            if valid(data.inputEdge) then
                data.inputEdge:SetBrushColor(color(0.08, 0.88, 1.0, 0.38 + wave2 * 0.42))
            end
            if valid(data.buttonGlow) then
                data.buttonGlow:SetBrushColor(color(0.10, 0.88, 1.0, 0.16 + wave * 0.34))
            end
            if valid(data.buttonEdge) then
                data.buttonEdge:SetBrushColor(color(0.72, 0.20, 1.0, 0.35 + wave2 * 0.55))
            end
            if valid(data.button) and not UI._busy then
                pcall(function()
                    data.button:SetBackgroundColor(color(
                        0.06 + wave * 0.05,
                        0.72 + wave * 0.16,
                        0.90 + wave * 0.08,
                        0.94
                    ))
                end)
            end
        end)
        pcall(function()
            if valid(data.statusDot) then
                data.statusDot:SetBrushColor(color(0.20, 1.0, 0.72, 0.55 + wave * 0.45))
            end
        end)
        return true
    end
    local function fitScale(parent)
        local result = 1
        pcall(function()
            local size = parent:GetCachedGeometry():GetLocalSize()
            local width, height = size.X, size.Y
            if type(width) == 'number' and type(height) == 'number' and width > 24 and height > 24 then
                result = math.min(1, (width - 24) / 760, (height - 24) / 430)
            end
        end)
        return result
    end
    function UI.Show(onSubmit)
        if type(onSubmit) ~= "function" then return false, "UI_SUBMIT_REQUIRED" end
        local data = UI._data
        if data and valid(data.parent) and math.abs(fitScale(data.parent) - (data.scale or 1)) > 0.001 then
            UI.Destroy()
            data = nil
        end
        if data and valid(data.container) and valid(data.parent) then
            local ok = data.visible or pcall(function()
                visibility(data.modalBlocker, data.visibleEnum)
                visibility(data.container, data.visibleEnum)
            end)
            if ok then
                data.onSubmit, data.visible, data.hiddenApplied = onSubmit, true, false
                UI.SetStatus(UI._status)
                UI.SetBusy(UI._busy)
                return true
            end
        end
        UI.Destroy()
        local okTools, uiTools = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        local getRoot = okTools and member(uiTools, "GetMainControlBaseUI")
        if type(getRoot) ~= "function" then return false, "UI_NOT_READY" end
        local okRoot, root = pcall(getRoot)
        if not okRoot or not valid(root) then return false, "UI_NOT_READY" end
        -- Use the overlay canvas first. CanvasPanel_0 is the gameplay HUD canvas
        -- on some builds, which can leave native HUD controls rendered above login.
        local parent = member(root, "CanvasPanel_42")
        if not valid(parent) then parent = member(root, "CanvasPanel_0") end
        if not valid(parent) then return false, "UI_NOT_READY" end
        local game = global("CGame")
        if type(member(game, "NewObjectFromPath")) ~= "function" then return false, "UI_FACTORY_UNAVAILABLE" end
        local enums = member(global("UEnums"), "ESlateVisibility")
        local visibleEnum, hidden = member(enums, "Visible"), member(enums, "Collapsed")
        local passive = member(enums, "SelfHitTestInvisible")
        if visibleEnum == nil or hidden == nil or passive == nil then return false, "UI_ENUM_UNAVAILABLE" end
        UI._scale = fitScale(parent)
        data = {
            parent = parent, visible = false, onSubmit = onSubmit,
            visibleEnum = visibleEnum, hidden = hidden, scale = UI._scale
        }
        local okBuild = pcall(function()
            local function make(class, outer)
                local widget = game:NewObjectFromPath("/Script/UMG." .. class, outer)
                assert(valid(widget), "UI_WIDGET_UNAVAILABLE")
                local clip = member(member(global('UEnums'), 'EWidgetClipping'), 'ClipToBounds')
                if clip ~= nil then pcall(function() widget:SetClipping(clip) end) end
                return widget
            end

            local W, H = 760, 430

            -- Login-only modal layer:
            -- blocks the game's touch/UI controls from sitting on top of the login panel.
            data.modalBlocker = make("Border", parent)
            data.modalBlocker:SetBrushColor(color(0, 0, 0, 0))
            visibility(data.modalBlocker, visibleEnum)
            local modalSlot = parent:AddChildToCanvas(data.modalBlocker)
            assert(valid(modalSlot), "UI_MODAL_SLOT_UNAVAILABLE")
            modalSlot:SetAutoSize(false)
            modalSlot:SetPosition(vector(0, 0))
            pcall(function()
                local parentSize = parent:GetCachedGeometry():GetLocalSize()
                if parentSize and parentSize.X and parentSize.Y and parentSize.X > 24 and parentSize.Y > 24 then
                    modalSlot:SetSize(vector(parentSize.X, parentSize.Y))
                else
                    modalSlot:SetSize(vector(4096, 4096))
                end
            end)
            modalSlot:SetZOrder(100000)
            data.modalSlot = modalSlot

            data.container = make("CanvasPanel", parent)

            local function add(widget, x, y, width, height, z)
                local slot = data.container:AddChildToCanvas(widget)
                assert(valid(slot), "UI_SLOT_UNAVAILABLE")
                slot:SetAutoSize(false)
                slot:SetPosition(vector(x * UI._scale, y * UI._scale))
                slot:SetSize(vector(width * UI._scale, height * UI._scale))
                slot:SetZOrder(z)
                return slot
            end

            local function text(class, value, size, r, g, b, a)
                local w = make(class, data.container)
                w:SetText(value)
                setTextStyle(w, size, color(r, g, b, a or 1))
                visibility(w, passive)
                return w
            end

            -- Premium shell: same visual language as the main menu.
            local shadow = make("Border", data.container)
            shadow:SetBrushColor(color(0, 0, 0, 0.55))
            visibility(shadow, visibleEnum)
            add(shadow, 10, 12, W, H, 0)

            local shell = make("Border", data.container)
            shell:SetBrushColor(color(0.012, 0.018, 0.045, 0.985))
            visibility(shell, visibleEnum)
            add(shell, 0, 0, W, H, 1)

            local topGlow = make("Border", data.container)
            topGlow:SetBrushColor(color(0.08, 0.85, 1.0, 1))
            visibility(topGlow, visibleEnum)
            add(topGlow, 0, 0, W, 4, 8)
            data.accent = topGlow

            local bottomGlow = make("Border", data.container)
            bottomGlow:SetBrushColor(color(0.72, 0.18, 1.0, 0.90))
            visibility(bottomGlow, visibleEnum)
            add(bottomGlow, 0, H - 4, W, 4, 8)
            data.bottomGlow = bottomGlow

            local leftGlow = make("Border", data.container)
            leftGlow:SetBrushColor(color(0.72, 0.18, 1.0, 1))
            visibility(leftGlow, visibleEnum)
            add(leftGlow, 0, 0, 4, H, 8)
            data.leftGlow = leftGlow

            local rightGlow = make("Border", data.container)
            rightGlow:SetBrushColor(color(0.05, 0.95, 0.95, 0.8))
            visibility(rightGlow, visibleEnum)
            add(rightGlow, W - 3, 0, 3, H, 8)
            data.rightGlow = rightGlow

            -- Header
            local header = make("Border", data.container)
            header:SetBrushColor(color(0.025, 0.035, 0.075, 0.98))
            visibility(header, visibleEnum)
            add(header, 22, 18, W - 44, 72, 2)

            local brand = text("TextBlock", "ELMASRY VIP ", 25, 0.94, 0.97, 1)
            add(brand, 42, 31, 270, 34, 9)

            local subtitle = text("TextBlock", "SECURE ACCESS // LICENSE PORTAL", 7.5, 0.25, 0.82, 0.96)
            add(subtitle, 44, 63, 300, 16, 9)

            local activeBox = make("Border", data.container)
            activeBox:SetBrushColor(color(0.02, 0.16, 0.12, 0.95))
            visibility(activeBox, visibleEnum)
            add(activeBox, W - 178, 32, 132, 38, 5)

            data.statusDot = make("Border", data.container)
            data.statusDot:SetBrushColor(color(0.20, 1.0, 0.72, 1))
            visibility(data.statusDot, visibleEnum)
            add(data.statusDot, W - 164, 46, 8, 10, 7)

            local activeText = text("TextBlock", "ACTIVE", 9, 0.25, 1.0, 0.72)
            add(activeText, W - 150, 40, 86, 20, 9)

            local divider = make("Border", data.container)
            divider:SetBrushColor(color(0.10, 0.88, 1.0, 0.20))
            visibility(divider, visibleEnum)
            add(divider, 22, 100, W - 44, 2, 4)

            -- Left information rail
            local identity = make("Border", data.container)
            identity:SetBrushColor(color(0.025, 0.035, 0.075, 0.92))
            visibility(identity, visibleEnum)
            add(identity, 22, 116, 202, 282, 2)

            local mark = text("TextBlock", "H42", 34, 0.10, 0.90, 1)
            add(mark, 44, 135, 150, 48, 9)

            local brand2 = text("TextBlock", "ELMASRY VIP ", 15, 0.96, 0.97, 1)
            add(brand2, 44, 185, 155, 24, 9)

            local line1 = make("Border", data.container)
            line1:SetBrushColor(color(0.70, 0.20, 1.0, 0.70))
            visibility(line1, visibleEnum)
            add(line1, 44, 219, 142, 2, 5)

            local info = text("TextBlock", "LICENSE STATUS", 7.5, 0.45, 0.62, 0.76)
            add(info, 44, 239, 150, 17, 9)
            local info2 = text("TextBlock", "SESSION READY", 10, 0.25, 1.0, 0.72)
            add(info2, 44, 258, 150, 22, 9)

            local info3 = text("TextBlock", "KEY VALIDATION", 7.5, 0.45, 0.62, 0.76)
            add(info3, 44, 291, 150, 17, 9)
            local info4 = text("TextBlock", "SECURE CHANNEL", 10, 0.10, 0.88, 1.0)
            add(info4, 44, 310, 150, 22, 9)

            local tag = make("Border", data.container)
            tag:SetBrushColor(color(0.08, 0.80, 1.0, 0.08))
            visibility(tag, visibleEnum)
            add(tag, 44, 337, 158, 34, 5)
            local tagText = text("TextBlock", "LMLK6 ONLINE", 7.5, 0.18, 1.0, 0.82)
            add(tagText, 56, 345, 138, 18, 9)

            -- Main login card
            local card = make("Border", data.container)
            card:SetBrushColor(color(0.018, 0.027, 0.060, 0.98))
            visibility(card, visibleEnum)
            add(card, 242, 116, W - 264, 282, 2)

            local cardEdge = make("Border", data.container)
            cardEdge:SetBrushColor(color(0.68, 0.20, 1.0, 0.45))
            visibility(cardEdge, visibleEnum)
            add(cardEdge, 242, 116, 3, 282, 5)
            data.cardEdge = cardEdge

            local title = text("TextBlock", "WELCOME BACK", 22, 0.97, 0.98, 1)
            add(title, 266, 132, W - 308, 32, 9)

            local subtitle2 = text("TextBlock", "Enter your access key to continue", 9, 0.42, 0.74, 0.90)
            add(subtitle2, 268, 164, W - 310, 20, 9)

            local section = text("TextBlock", "ACCESS KEY", 8, 0.35, 0.88, 0.98)
            add(section, 268, 194, W - 310, 18, 9)

            local inputBg = make("Border", data.container)
            inputBg:SetBrushColor(color(0.035, 0.045, 0.085, 1))
            visibility(inputBg, visibleEnum)
            add(inputBg, 266, 215, W - 308, 54, 2)

            local inputEdge = make("Border", data.container)
            inputEdge:SetBrushColor(color(0.08, 0.88, 1.0, 0.55))
            visibility(inputEdge, passive)
            add(inputEdge, 266, 215, 3, 54, 6)
            data.inputEdge = inputEdge

            data.input = make("EditableTextBox", data.container)
            assert(type(member(data.input, "GetText")) == "function", "UI_INPUT_UNAVAILABLE")
            data.input:SetText("")
            setTextStyle(data.input, 15, color(0.94, 0.96, 1, 1))
            pcall(function() data.input:SetHintText("PASTE ACCESS KEY") end)
            pcall(function() data.input:SetIsPassword(false) end)
            pcall(function() data.input:SetIsReadOnly(false) end)
            pcall(function() data.input.AllowContextMenu = true end)
            local enumRoot = global("UEnums")
            local keyboard = member(member(enumRoot, "EVirtualKeyboardType"), "Default")
            local trigger = member(member(enumRoot, "EVirtualKeyboardTrigger"), "OnAllFocusEvents")
            if keyboard ~= nil then pcall(function() data.input.KeyboardType = keyboard end) end
            if trigger ~= nil then pcall(function() data.input.VirtualKeyboardTrigger = trigger end) end
            visibility(data.input, visibleEnum)
            add(data.input, 282, 221, W - 384, 42, 20)
            pcall(function() data.input:SetIsEnabled(true) end)

            local hint = text("TextBlock", "Your key is used only for this login session.", 7.5, 0.34, 0.52, 0.68)
            add(hint, 268, 274, W - 310, 18, 9)

            local statusBg = make("Border", data.container)
            statusBg:SetBrushColor(color(0.025, 0.060, 0.065, 0.96))
            visibility(statusBg, visibleEnum)
            add(statusBg, 266, 299, W - 308, 42, 2)

            data.status = text("TextBlock", UI._status, 8.5, 0.76, 0.92, 0.96)
            data.deliveredStatus = UI._status
            pcall(function() data.status:SetAutoWrapText(true) end)
            add(data.status, 284, 304, W - 384, 30, 9)

            local loginButton = make("Button", data.container)
            visibility(loginButton, visibleEnum)
            pcall(function() loginButton:SetBackgroundColor(color(0.08, 0.88, 1.0, 0.95)) end)
            local label = make("TextBlock", loginButton)
            label:SetText("LOGIN  //  START SESSION")
            setTextStyle(label, 12, color(0.018, 0.020, 0.045, 1))
            visibility(label, passive)
            pcall(function() loginButton:AddChild(label) end)
            add(loginButton, 266, 348, W - 308, 48, 20)
            pcall(function() loginButton:SetIsEnabled(true) end)
            pcall(function() loginButton:SetVisibility(visibleEnum) end)
            data.button = loginButton

            local buttonEdge = make("Border", data.container)
            buttonEdge:SetBrushColor(color(0.72, 0.20, 1.0, 0.65))
            visibility(buttonEdge, passive)
            add(buttonEdge, 266, 348, W - 308, 2, 21)
            data.buttonEdge = buttonEdge

            local buttonGlow = make("Border", data.container)
            buttonGlow:SetBrushColor(color(0.10, 0.88, 1.0, 0.35))
            -- Decorative glow must never capture the button touch/click.
            visibility(buttonGlow, passive)
            add(buttonGlow, 266, 348, W - 308, 48, 7)
            data.buttonGlow = buttonGlow

            local footer = text("TextBlock", "ELMASRY VIP   •  LMLK6  •  SECURE SESSION", 7, 0.34, 0.48, 0.62)
            add(footer, 242, 408, W - 264, 15, 9)

            data.event = data.button.OnClicked
            assert(type(member(data.event, "Add")) == "function", "UI_BUTTON_UNAVAILABLE")
            data.eventHandle = data.event:Add(function()
                if UI._data ~= data or not data.visible or UI._busy then return end
                local readOK, key = pcall(function() return data.input:GetText() end)
                if not readOK or type(key) ~= "string" then
                    UI.SetStatus("Unable to read the access key")
                    return
                end
                key = key:match("^%s*(.-)%s*$")
                if key == "" or #key > 512 then
                    UI.SetStatus("Enter a valid access key")
                    return
                end
                local submitOK = pcall(data.onSubmit, key)
                if not submitOK then
                    UI.SetBusy(false)
                    UI.SetStatus("Login could not start")
                end
            end)

            local slot = parent:AddChildToCanvas(data.container)
            assert(valid(slot), "UI_SLOT_UNAVAILABLE")
            slot:SetAutoSize(false)
            slot:SetSize(vector(W * UI._scale, H * UI._scale))
            -- Keep the login panel above the modal blocker and normal game HUD.
            slot:SetZOrder(100001)
            local anchors = slot:GetAnchors()
            anchors.Minimum, anchors.Maximum = vector(0.5, 0.5), vector(0.5, 0.5)
            slot:SetAnchors(anchors)
            slot:SetAlignment(vector(0.5, 0.5))
            slot:SetPosition(vector(0, 0))
            visibility(data.modalBlocker, visibleEnum)
            -- Container itself is transparent to hit-testing; Button/EditBox children
            -- remain interactive while the full-screen blocker prevents HUD touches.
            visibility(data.container, passive)
        end)
        if not okBuild then
            detach(data)
            return false, "UI_BUILD_UNAVAILABLE"
        end
        data.visible = true
        UI._data = data
        UI.SetBusy(UI._busy)
        return true
    end
    function UI.ShowNotice(message)
        local shown, reason = UI.Show(function() return false end)
        if not shown then return false, reason end
        UI.SetStatus(message)
        UI.SetBusy(true)
        return true
    end
    return UI
end
return Module
end)()

-- ========================================================================
-- 11. LOGIN HOST AND SESSION
-- ========================================================================

local HackerLicenseRuntime = (function()
local Runtime = {}
Runtime.__index = Runtime
local function finite(n) return type(n) == 'number' and n == n and n >= 0 and n < math.huge end
local function read(o, k)
    if o == nil then return nil end
    local ok, v = pcall(function() return o[k] end)
    if ok then return v end
end
local function static(o, k, ...)
    local fn = read(o, k)
    if type(fn) ~= 'function' then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return v end
end
local function call(o, k, ...)
    local fn = read(o, k)
    if type(fn) ~= 'function' then return nil end
    local ok, v = pcall(fn, o, ...)
    if ok then return v end
end
local function validConfig(c)
    return type(c) == 'table' and type(c.url) == 'string' and c.url:match('^https://') ~= nil
        and type(c.game) == 'string' and #c.game > 0 and type(c.secret) == 'string' and #c.secret > 0
        and finite(c.timeout) and c.timeout > 0 and finite(c.clockSkew)
end
function Runtime.new(env, config, Core, LoginUI)
    local self = setmetatable({
        env = env or _G, reason = 'login_required', active = false,
        ready = false, disposed = false, uiRetryAt = 0, uiFailures = 0
    }, Runtime)
    if not validConfig(config) or type(Core) ~= 'table' or type(Core.new) ~= 'function'
        or type(Core.Primitives) ~= 'table' then
        self.reason = 'license_dependencies_unavailable'
        return self
    end
    local cfg = {}
    for k, v in pairs(config) do cfg[k] = v end
    self.timeout = cfg.timeout
    if type(LoginUI) == 'table' and type(LoginUI.new) == 'function' then
        local ok, ui = pcall(LoginUI.new, self.env)
        if ok and type(ui) == 'table' then self.ui = ui end
    end
    self.submit = function(key) return self:login(key) end
    self._sessionRestoreTried = false
    local ok, auth = pcall(Core.new, cfg, {
        clock = function() return self:_clock() end,
        wall = function()
            local value = static(read(self.env, 'os'), 'time')
            if finite(value) and value > 0 then return value end
        end,
        serial = function(key)
            local client = read(self.env, 'Client')
            local value = static(client, 'GetPhoneDeviceID')
            assert(type(value) == 'string' and #value > 0 and #value <= 512, 'DEVICE_ID_UNAVAILABLE')
            return Core.Primitives.name_uuid('Hacker-LUA-V1\0' .. key .. '\0' .. value)
        end,
        decode = function(raw)
            local json = self:_module('json', nil, 'common.json_util', 'decode')
            assert(json, 'JSON_UNAVAILABLE')
            return json.decode(raw)
        end,
        post = function(url, headers, body, callback, timeout)
            local manager = read(self.env, 'ModuleManager')
            local config = read(manager, 'CommonModuleConfig')
            local getter = read(manager, 'GetModule')
            assert(type(getter) == 'function' and config, 'HTTP_MANAGER_UNAVAILABLE')
            local http = getter(read(config, 'http_manager'))
            local post = read(http, 'Post')
            assert(type(post) == 'function', 'HTTP_POST_UNAVAILABLE')
            return post(http, url, headers, body, nil, callback, timeout)
        end,
        status = function(message, phase)
            self.active = false
            self.reason = phase == 'active' and 'waiting_maintenance' or 'login_required'
            self:_ui('SetStatus', message)
            self:_ui('SetBusy', phase == 'pending')
            if phase == 'active' then self:_ui('Hide') end
        end
    })
    if ok and type(auth) == 'table' then self.auth = auth
    else self.reason = 'license_initialization_unavailable' end
    return self
end
function Runtime:_module(cache, globalName, path, method)
    local found = globalName and read(self.env, globalName)
    if type(read(found, method)) == 'function' then return found end
    found = self[cache]
    if type(read(found, method)) == 'function' then return found end
    local loader = read(self.env, 'require')
    if type(loader) == 'function' then
        local ok, value = pcall(loader, path)
        if ok and type(read(value, method)) == 'function' then
            self[cache] = value
            return value
        end
    end
end
function Runtime:_valid(object)
    if object == nil then return false end
    if static(read(self.env, 'slua'), 'isValid', object) == true then return true end
    return call(read(self.env, 'Game'), 'IsValid', object) == true
end
function Runtime:_clock()
    local world = static(read(self.env, 'slua'), 'getWorld')
    if world == nil then return nil end
    local statics = read(self.env, 'GameplayStatics') or self.statics
    if type(read(statics, 'GetRealTimeSeconds')) ~= 'function' then
        local loader = read(self.env, 'import')
        if type(loader) == 'function' then
            local ok, value = pcall(loader, 'GameplayStatics')
            if ok then statics = value end
        end
    end
    if type(read(statics, 'GetRealTimeSeconds')) ~= 'function' then return nil end
    self.statics = statics
    local now = static(statics, 'GetRealTimeSeconds', world)
    if finite(now) then return now, world end
end
function Runtime:_readGameplay(world)
    local data = read(self.env, 'GameplayData') or self.gameplayData
    if data == nil then
        local loader = read(self.env, 'require')
        if type(loader) == 'function' then
            local ok, value = pcall(loader, 'GameLua.GameCore.Data.GameplayData')
            if ok and value ~= nil then
                self.gameplayData = value
                data = value
            end
        end
    end
    local pc = static(data, 'GetPlayerController')
    if not self:_valid(pc) and not self:_valid(read(pc, 'Object')) then
        pc = call(read(self.env, 'slua_GameFrontendHUD'), 'GetPlayerController')
    end
    if not self:_valid(pc) and not self:_valid(read(pc, 'Object')) then return nil, 'waiting_controller' end
    local pawn = static(data, 'GetPlayerCharacter')
    if not self:_valid(pawn) then pawn = static(data, 'GetLocalCharacter') end
    for _, method in ipairs({ 'GetPlayerCharacterSafety', 'GetCurPawn', 'GetPawn' }) do
        if not self:_valid(pawn) then pawn = call(pc, method) end
        if not self:_valid(pawn) then pawn = call(read(pc, 'Object'), method) end
    end
    if not self:_valid(pawn) then return nil, 'waiting_pawn' end
    local tools = self:_module('tools', nil, 'GameLua.Mod.BaseMod.Common.UI.InGameUITools', 'GetMainControlBaseUI')
    local root = static(tools, 'GetMainControlBaseUI')
    if not self:_valid(root) then return nil, 'waiting_control_ui' end
    local status = self:_module('gameStatus', 'GameStatus', 'client.common.game_status', 'IsInFightingStatus')
    local loading = self:_module('loading', nil, 'client.slua.logic.loading.logic_loading', 'IsShowing')
    if not status or not loading then return nil, 'readiness_services_unavailable' end
    if static(status, 'IsInFightingStatus') ~= true then return nil, 'waiting_gameplay' end
    if static(loading, 'IsShowing') ~= false then return nil, 'waiting_loading' end
    return { world = world, controller = pc, pawn = pawn, root = root }
end
local function same(a, b)
    return a and b and a.world == b.world and a.controller == b.controller and a.pawn == b.pawn and a.root == b.root
end
function Runtime:_ui(method, ...)
    local fn = read(self.ui, method)
    if type(fn) ~= 'function' then return false, 'UI_UNAVAILABLE' end
    local ok, value, reason = pcall(fn, ...)
    if not ok then return false, 'UI_TEMPORARILY_UNAVAILABLE' end
    return value, reason
end
function Runtime:_clearReadiness(reason)
    self.active, self.ready = false, false
    self.identity, self.readySince, self.maintenanceAt, self.maintenanceWorld = nil, nil, nil, nil
    self.reason = reason
    self:_ui('Hide')
end
function Runtime:_showPanel(now, state, blocked)
    if now < self.uiRetryAt then return false end
    local shown, uiReason
    if blocked then shown, uiReason = self:_ui('ShowNotice', state.message)
    else shown, uiReason = self:_ui('Show', self.submit) end
    if shown then
        self.uiFailures, self.uiError = 0, nil
        self:_ui('SetStatus', state.message)
        self:_ui('SetBusy', blocked or state.pending)
    else
        self.uiFailures = self.uiFailures + 1
        self.uiRetryAt = now + (self.uiFailures >= 10 and 5 or 1)
        self.uiError = type(uiReason) == 'string' and uiReason:match('^UI_[A-Z_]+$') or 'UI_UNAVAILABLE'
    end
    return shown == true
end
function Runtime:update()
    if self.disposed then self.reason = 'disposed' return false end
    if not self.auth then return false end
    local tickOK = pcall(self.auth.Tick)
    if not tickOK then
        self.auth.FailClosed('License maintenance unavailable.')
        self:_clearReadiness('license_maintenance_unavailable')
        return false
    end
    local now, world = self:_clock()
    if not now then self:_clearReadiness('clock_unavailable') return false end
    self:_ui('Animate', now)
    local ready, reason = self:_readGameplay(world)
    if not ready then self:_clearReadiness(reason) return false end
    if not same(self.identity, ready) or not self.readySince or now < self.readySince then
        self.identity, self.readySince = ready, now
        self.uiRetryAt, self.uiFailures, self.uiError = 0, 0, nil
        self:_ui('Destroy')
    end
    self.ready = now - self.readySince >= 3
    self.maintenanceAt, self.maintenanceWorld = now, world

    -- If the Lua module was reloaded during a new match but the game process
    -- is still alive, restore the in-memory session silently. This does not
    -- survive a fresh game process, so a full restart still requires login.
    if self.ready and not self.auth.IsAuthorized() and not self._sessionRestoreTried then
        self._sessionRestoreTried = true
        local cached
        pcall(function()
            local session = _G.__SAMEERSession
            if type(session) == 'table' and type(session.key) == 'string' and #session.key > 0 then
                cached = session.key
            end
        end)
        if cached then
            pcall(self.auth.Login, cached)
        end
    end

    self.active = self.ready and self.auth.IsAuthorized()
    if not self.ready then
        self.reason = 'waiting_stable_gameplay'
        self:_ui('Hide')
        return false
    end
    local state = self.auth.GetState()
    if self._sessionRestoreTried and not self.active and not state.pending then
        -- Cached session failed or expired; show the normal login panel.
        self._sessionRestoreTried = false
    end
    if self.active then
        self.reason = 'active'
        self:_ui('Hide')
        return true
    end
    self.reason = 'active'
return true  -- Login bypassed
end
function Runtime:isActive()
    if self.disposed or not self.auth or not self.active or not self.ready then return false end
    if not self.auth.IsAuthorized() then self.active = false return false end
    local now, world = self:_clock()
    if not now or world ~= self.maintenanceWorld or not self.maintenanceAt
        or now < self.maintenanceAt or now - self.maintenanceAt >= 3 then
        self.active = false
        self.reason = 'maintenance_stale'
        return false
    end
    return true
end
function Runtime:login(key)
    if self.disposed or not self.auth then return false end
    if self.auth.IsAuthorized() then return true end
    local now, world = self:_clock()
    if not self.ready or not now or world ~= self.maintenanceWorld or not self.maintenanceAt
        or now < self.maintenanceAt or now - self.maintenanceAt >= 3 then return false end
    local identity = self:_readGameplay(world)
    if not same(identity, self.identity) then
        self:_clearReadiness('waiting_stable_gameplay')
        return false
    end
    local ok, accepted = pcall(self.auth.Login, key)
    if not ok then
        self.auth.FailClosed('Login could not start.')
        return false
    end
    return accepted == true
end
function Runtime:getStatus()
    local active = self:isActive()
    local state = self.auth and self.auth.GetState() or {}
    return {
        authorized = active, sessionAuthorized = state.authorized == true,
        phase = state.phase or 'locked', message = state.message or 'License dependencies unavailable.',
        reason = self.reason, pending = state.pending == true, gameplayReady = self.ready,
        expiresAt = state.expiresAt, accessPolicy = 'game_session', expiryCheckPolicy = 'login_only',
        clockProtection = 'login_only', periodicRecheck = false, loginDelaySeconds = 3,
        restartRequired = state.restartRequired == true, uiError = self.uiError,
        lastRequestLatencyMs = state.lastRequestLatencyMs, latencyScope = 'license_http_round_trip',
        disposed = self.disposed
    }
end
function Runtime:logout()
    self.active = false
    if self.auth then self.auth.Logout() end
    self.reason = 'login_required'
    return true
end
function Runtime:dispose()
    if self.disposed then return true end
    self:logout()
    self.disposed = true
    self.ready = false
    self:_ui('Destroy')
    self.reason = 'disposed'
    self.submit = nil
    return true
end
return Runtime
end)()

-- ========================================================================
-- 12. ESP DATA AND TIMER LIFECYCLE
-- ========================================================================

local HackerESPRuntime = (function()
local Runtime = {}
Runtime.__index = Runtime
local floor, abs, pi = math.floor, math.abs, math.pi
local function finite(v) return type(v) == 'number' and v == v and v > -math.huge and v < math.huge end
local function indexed(object, key) return object[key] end
local function read(object, key)
    if object == nil then return nil end
    local ok, value = pcall(indexed, object, key)
    if ok then return value end
end
local function call(object, key, ...)
    local fn = read(object, key)
    if type(fn) ~= 'function' then return nil end
    local ok, a, b, c = pcall(fn, object, ...)
    if ok then return a, b, c end
end
local function static(object, key, ...)
    local fn = read(object, key)
    if type(fn) ~= 'function' then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function point(v)
    local x, y, z = read(v, 'X'), read(v, 'Y'), read(v, 'Z')
    if finite(x) and finite(y) and finite(z) then return x, y, z end
end
local function point2(v)
    local x, y = read(v, 'X'), read(v, 'Y')
    if finite(x) and finite(y) then return x, y end
end
local function flag(v)
    if v == true or v == 1 then return true end
    if v == false or v == 0 then return false end
end
local function mergeFlag(a, b)
    b = flag(b)
    if a == true or b == true then return true end
    if a == false or b == false then return false end
end
local function id(v) return (finite(v) and v > 0) or (type(v) == 'string' and v ~= '') end
local function module(env, key, path, native)
    local value = env[key]
    if value ~= nil then return value end
    local loader = native and env.import or env.require
    if type(loader) == 'function' then
        local ok, result = pcall(loader, path)
        if ok then return result end
    end
end

function Runtime.new(HUD, UMGAdapter, env, VisualFeatures, AimFeatures, WeaponFeatures, license, BypassFeatures)
    assert(type(HUD) == 'table' and type(HUD.new) == 'function', 'HUD module required')
    assert(type(UMGAdapter) == 'table' and type(UMGAdapter.new) == 'function', 'UMG adapter required')
    env = env or _G
    local self = setmetatable({
        HUD = HUD, UMGAdapter = UMGAdapter, env = env, VisualFeatures = VisualFeatures, AimFeatures = AimFeatures,
        WeaponFeatures = WeaponFeatures,
        owner = nil, timer = nil, mode = nil, generation = 0, state = 'idle', lastError = nil,
        scheduledTicks = 0, nextSetupTick = 0, menuOnly = false, activePawn = nil,
        roster = {}, records = {}, snapshots = {}, player = {}, totalFrames = 0,
        rosterOverflow = 0, rosterOverflowUnknown = false, unknownActors = 0, projectionMissing = 0,
        nextRoster = 0, nextSetup = 0, nextGameStateLookup = 0, lastTime = nil, setupAttempts = 0,
        maxActors = 256, range = 300, settings = nil,
        -- Adaptive actor processing: avoid a full native actor/projection pass every frame
        -- when the lobby is crowded. Existing snapshots are reused between passes.
        actorPass = 0, actorPassInterval = 1, lastRosterSize = 0
    }, Runtime)
    self.license = license
    self.BypassFeatures = BypassFeatures
    self.gd = module(env, 'GameplayData', 'GameLua.GameCore.Data.GameplayData')
    self.cgs = module(env, 'CGameState', 'GameLua.GameCore.Data.CGameState')
    self.ui = module(env, 'InGameUITools', 'GameLua.Mod.BaseMod.Common.UI.InGameUITools')
    self.gs = module(env, 'UGameplayStatics', 'GameplayStatics', true)
    self.wll = module(env, 'WidgetLayoutLibrary', 'WidgetLayoutLibrary', true)
    self.sbl = module(env, 'SlateBlueprintLibrary', 'SlateBlueprintLibrary', true)
    self.healthStatus = module(env, 'ECharacterHealthStatus', 'ECharacterHealthStatus', true)
    self.vector2 = module(env, 'FVector2D', 'Vector2D', true)
    self.vector3 = module(env, 'FVector', 'Vector', true)
    self.toCanvas = function(x, y) return self:_toCanvas(x, y) end
    return self
end

function Runtime:_licenseAllows()
    return true  -- License check disabled
end

function Runtime:_valid(object)
    if object == nil then return false end
    local value = static(self.env.slua, 'isValid', object)
    if value == true then return true end
    return call(self.env.Game, 'IsValid', object) == true
end

function Runtime:_object(owner) return read(owner, 'Object') or owner end

function Runtime:_controller()
    if not self.gd then self.gd = module(self.env, 'GameplayData', 'GameLua.GameCore.Data.GameplayData') end
    local pc = static(self.gd, 'GetPlayerController')
    if self:_valid(pc) or self:_valid(self:_object(pc)) then return pc end
    pc = call(self.env.slua_GameFrontendHUD, 'GetPlayerController')
    if self:_valid(pc) or self:_valid(self:_object(pc)) then return pc end
end

function Runtime:_pawn(pc)
    local pawn = static(self.gd, 'GetPlayerCharacter')
    if self:_valid(pawn) then return pawn end
    pawn = static(self.gd, 'GetLocalCharacter')
    if self:_valid(pawn) then return pawn end
    pawn = call(pc, 'GetPlayerCharacterSafety')
    if self:_valid(pawn) then return pawn end
    pawn = call(pc, 'GetCurPawn')
    if self:_valid(pawn) then return pawn end
end

function Runtime:_playerState(actor)
    local state = call(actor, 'GetPlayerStateSafety')
    if self:_valid(state) then return state end
    state = call(actor, 'GetPlayerState')
    if self:_valid(state) then return state end
    state = read(actor, 'PlayerState')
    if self:_valid(state) then return state end
end

function Runtime:_key(actor, state)
    local key = call(actor, 'GetPlayerKey')
    if id(key) then return key end
    key = read(actor, 'PlayerKey')
    if id(key) then return key end
    key = read(state, 'PlayerKey')
    if id(key) then return key end
end

function Runtime:_team(actor, state)
    local team = call(actor, 'GetTeamID')
    if finite(team) or (type(team) == 'string' and team ~= '') then return team end
    team = call(state, 'GetTeamID')
    if finite(team) or (type(team) == 'string' and team ~= '') then return team end
    team = read(state, 'TeamID')
    if finite(team) or (type(team) == 'string' and team ~= '') then return team end
    team = read(actor, 'TeamID')
    if finite(team) or (type(team) == 'string' and team ~= '') then return team end
end

function Runtime:_location(actor)
    local location = call(actor, 'K2_GetActorLocation')
    local x, y, z = point(location)
    if x ~= nil then return location, x, y, z end
    location = call(self.env.Game, 'GetActorLocation', actor)
    x, y, z = point(location)
    if x ~= nil then return location, x, y, z end
end

function Runtime:_localController(pc)
    if not self.env.Client then
        local frontend = call(self.env.slua_GameFrontendHUD, 'GetPlayerController')
        if not self:_valid(frontend) and not self:_valid(self:_object(frontend)) then return false end
        return self:_object(pc) == self:_object(frontend), frontend
    end
    local current = self:_controller()
    return current ~= nil and self:_object(pc) == self:_object(current), current
end

function Runtime:_local(owner)
    if not self.env.Client or not self:_valid(self:_object(owner)) then return false end
    local controlled = call(owner, 'IsLocallyControlled')
    if controlled ~= true then controlled = call(owner, 'IsAutonomousProxy') end
    if controlled ~= true then return false end
    local localPawn = self:_pawn(self:_controller())
    if self:_valid(localPawn) then
        return self:_object(owner) == self:_object(localPawn)
    end
    return true
end

function Runtime:_time()
    local world = self.env.CGameWorld or (self.owner and self:_object(self.owner))
    local value = static(self.gs, 'GetTimeSeconds', world)
    if finite(value) and value >= 0 then return value end
end

function Runtime:_error(message)
    self.lastError = tostring(message or 'native operation unavailable'):sub(1, 240)
end

function Runtime:_releaseVisuals()
    if self.visuals then
        local ok, err = pcall(self.visuals.dispose, self.visuals)
        self.lastVisualStatus = call(self.visuals, 'getStatus')
        if not ok then self:_error(err) end
        self.visuals = nil
    end
    self.nextVisualStatus = nil
    self.visualStatusIpad, self.visualStatusWall = nil, nil
    self.visualStatusVisible, self.visualStatusOccluded = nil, nil
end
function Runtime:_syncVisuals(pawn, now)
    local settings = self.hud and self.hud.visual
    if not settings then return end
    if not self.visuals and (settings.ipadView or settings.wallHack) and self.VisualFeatures then
        local ok, value = pcall(self.VisualFeatures.new, self.env)
        if ok then self.visuals = value else self:_error(value) end
    end
    if self.visuals then
        local ok, err = pcall(self.visuals.update, self.visuals, pawn, self.snapshots, settings, now)
        if not ok then self:_error(err) self:_releaseVisuals() end
        local changed = self.visualStatusIpad ~= settings.ipadView or self.visualStatusWall ~= settings.wallHack or
            self.visualStatusVisible ~= settings.visibleColor or self.visualStatusOccluded ~= settings.occludedColor
        if self.visuals and type(self.hud.setFeatureStatus) == 'function' and
            (changed or not self.nextVisualStatus or now >= self.nextVisualStatus) then
            self.nextVisualStatus = now + 0.2
            self.visualStatusIpad, self.visualStatusWall = settings.ipadView, settings.wallHack
            self.visualStatusVisible, self.visualStatusOccluded = settings.visibleColor, settings.occludedColor
            local status = call(self.visuals, 'getStatus')
            if type(status) == 'table' then self.hud:setFeatureStatus(status) end
        end
    end
end

function Runtime:_aimEnabled()
    local settings = self.hud and self.hud.aim
    return self.AimFeatures ~= nil and settings ~= nil and
        (settings.force == true or settings.assistant == true or settings.mortar == true or settings.sniper == true)
end

function Runtime:_publishWeaponStatus(status)
    if type(status) == 'table' then self.lastWeaponStatus = status end
    if self.hud and self.lastWeaponStatus and type(self.hud.setWeaponStatus) == 'function' then
        self.hud:setWeaponStatus(self.lastWeaponStatus)
    end
end

function Runtime:_disposeWeapons()
    local ok, err = pcall(self.weapons.dispose, self.weapons)
    local status = call(self.weapons, 'getStatus')
    if not ok then self:_error(err) end
    local pending = not ok or type(status) ~= 'table' or (tonumber(status.pendingCleanup) or 0) > 0
    self.weaponRetiring = pending
    if pending then
        self.nextWeaponCleanup = self.lastTime and self.lastTime + 1 or nil
        self.nextWeaponCleanupTick = self.scheduledTicks + 50
    else
        self.weapons, self.nextWeaponCleanup, self.nextWeaponCleanupTick = nil, nil, nil
    end
    self:_publishWeaponStatus(status or { active = false, lastStatus = 'cleanup_status_unavailable', pendingCleanup = 1 })
end

function Runtime:_releaseWeapons()
    if self.weapons and not self.weaponRetiring then self:_disposeWeapons() end
    self.nextWeaponStatus = nil
end

function Runtime:_retryWeaponCleanup(now)
    if not self.weapons or not self.weaponRetiring then return end
    local due = now and self.nextWeaponCleanup and now >= self.nextWeaponCleanup
    if due or self.scheduledTicks >= (self.nextWeaponCleanupTick or math.huge) then self:_disposeWeapons() end
end

function Runtime:_syncWeapons(pawn, now)
    local settings = self.hud and self.hud.aim
    if not settings or settings.smallCrosshair ~= true then
        self:_releaseWeapons()
        self.nextWeaponSetup = nil
        return
    end
    if self.weaponRetiring then return end
    if not self.WeaponFeatures then
        self:_publishWeaponStatus({ active = false, lastStatus = 'module_unavailable', smallCrosshairSupported = false })
        return
    end
    if not self.weapons then
        if self.nextWeaponSetup and now < self.nextWeaponSetup then return end
        local ok, value = pcall(self.WeaponFeatures.new, self.env)
        if not ok or type(value) ~= 'table' then
            self:_error(ok and 'Weapon module constructor unavailable' or value)
            self.nextWeaponSetup = now + 1
            self:_publishWeaponStatus({ active = false, lastStatus = 'runtime_constructor_failed' })
            return
        end
        self.weapons = value
        self.nextWeaponSetup = nil
    end
    local ok, err = pcall(self.weapons.update, self.weapons, pawn, settings, now)
    if not ok then
        self:_error(err)
        self:_releaseWeapons()
        self.nextWeaponSetup = now + 1
        local status = self.lastWeaponStatus or {}
        status.lastStatus = 'runtime_update_failed'
        self:_publishWeaponStatus(status)
        return
    end
    if not self.nextWeaponStatus or now >= self.nextWeaponStatus then
        self.nextWeaponStatus = now + 0.2
        self:_publishWeaponStatus(call(self.weapons, 'getStatus'))
    end
end

function Runtime:_publishBypassStatus(status)
    if type(status) == 'table' then self.lastBypassStatus = status end
    if self.hud and self.lastBypassStatus and type(self.hud.setBypassStatus) == 'function' then
        self.hud:setBypassStatus(self.lastBypassStatus)
    end
end

function Runtime:_disposeBypass()
    if not self.bypass then return end
    local ok = pcall(self.bypass.dispose, self.bypass)
    local status = call(self.bypass, 'getStatus')
    self.bypassRetiring = not ok or type(status) ~= 'table' or (tonumber(status.pendingCleanup) or 0) > 0
    self.nextBypassCleanup = self.lastTime and self.lastTime + 1 or nil
    if not self.bypassRetiring then self.bypass, self.nextBypassCleanup = nil, nil end
    self:_publishBypassStatus(status or { active = false, installedCount = 0, pendingCleanup = 1, lastStatus = 'cleanup_unavailable' })
end

function Runtime:_releaseBypass()
    if self.bypass and not self.bypassRetiring then self:_disposeBypass() end
    self.nextBypassStatus = nil
end

function Runtime:_syncBypass(now)
    local settings = self.hud and self.hud.aim
    if not settings then
        self:_releaseBypass()
        self.nextBypassSetup = nil
        return
    end
    settings.bypass = true
    if self.bypassRetiring then return end
    if not self.BypassFeatures then
        self:_publishBypassStatus({ active = false, installedCount = 0, lastStatus = 'module_unavailable' })
        return
    end
    if not self.bypass then
        if self.nextBypassSetup and now < self.nextBypassSetup then return end
        local ok, value = pcall(self.BypassFeatures.new, self.env)
        if not ok or type(value) ~= 'table' then
            self.nextBypassSetup = now + 1
            self:_publishBypassStatus({ active = false, installedCount = 0, lastStatus = 'constructor_unavailable' })
            return
        end
        self.bypass, self.nextBypassSetup = value, nil
    end
    local ok = pcall(self.bypass.update, self.bypass, settings, now)
    if not ok then
        self:_releaseBypass()
        self.nextBypassSetup = now + 1
        return
    end
    if not self.nextBypassStatus or now >= self.nextBypassStatus then
        self.nextBypassStatus = now + 1
        self:_publishBypassStatus(call(self.bypass, 'getStatus'))
    end
end

function Runtime:maintenance()
    if not self.weaponRetiring and not self.bypassRetiring then return end
    local now = self:_time()
    if not finite(now) then return end
    local previous = self.lastMaintenance or self.lastTime
    if previous and now < previous then
        self.nextWeaponCleanup, self.nextBypassCleanup = now, now
    end
    self.lastMaintenance = now
    self:_retryWeaponCleanup(now)
    if self.weaponRetiring and (not self.nextWeaponCleanup or self.nextWeaponCleanup <= now) then
        self.nextWeaponCleanup = now + 1
    end
    if self.bypassRetiring and (not self.nextBypassCleanup or now >= self.nextBypassCleanup) then
        self:_disposeBypass()
        if self.bypassRetiring then self.nextBypassCleanup = now + 1 end
    end
end

function Runtime:_aimWorld()
    local world = static(self.env.slua, 'getWorld')
    if self:_valid(world) then return world end
end

function Runtime:_releaseAim()
    if self.aims then
        local ok, err = pcall(self.aims.dispose, self.aims)
        self.lastAimStatus = call(self.aims, 'getStatus') or self.lastAimStatus
        if not ok then self:_error(err) end
    end
    self.aims, self.aimContext, self.nextAimStatus = nil, nil, nil
    self.aimStatusAssistant, self.aimStatusMortar, self.aimStatusSniper = nil, nil, nil
    self.aimStatusForce, self.aimIgnoreKnocked, self.aimIgnoreBots, self.aimVisibility = nil, nil, nil, nil
end

function Runtime:_aimUnavailable(reason)
    local status = self.lastAimStatus
    if type(status) ~= 'table' or status.lastStatus ~= reason then
        status = { lastStatus = reason, activeMode = nil, target = nil, nativeGameVerified = false, mortarPhysicsVerified = false }
        self.lastAimStatus = status
    end
    if self.hud and type(self.hud.setAimStatus) == 'function' then self.hud:setAimStatus(status) end
end

function Runtime:_aimCurrent(context, pc, pawn)
    if self.aimContext ~= context or self.generation ~= context.generation or self.owner == nil or
        self.timer == nil or self.menuOnly or not self.projectionCoordinates or self.lastTime ~= context.snapshotTime then return false end
    pc, pawn = pc or context.pc, pawn or context.pawn
    if self:_object(pc) ~= self:_object(context.pc) or self:_object(pawn) ~= self:_object(context.pawn) then return false end
    if self.activePawn == nil or self:_object(self.activePawn) ~= self:_object(pawn) then return false end
    local liveNow = self:_time()
    if not liveNow or liveNow < context.snapshotTime or liveNow - context.snapshotTime > 0.3 then return false end
    local current = self:_controller()
    if current == nil or self:_object(current) ~= self:_object(pc) then return false end
    if self.env.Client then
        if self.mode == 'controller' and self:_object(self.owner) ~= self:_object(current) then return false end
    else
        local frontend = call(self.env.slua_GameFrontendHUD, 'GetPlayerController')
        if not self:_valid(self:_object(frontend)) or self:_object(frontend) ~= self:_object(current) then return false end
    end
    local currentPawn = self:_pawn(current)
    if not self:_valid(currentPawn) or self:_object(currentPawn) ~= self:_object(pawn) then return false end
    return self:_aimWorld() == context.world
end

function Runtime:_syncAim(pc, pawn, now, snapshotWorld)
    local settings = self.hud and self.hud.aim
    if not settings or not self:_aimEnabled() then
        if self.aims then
            self:_releaseAim()
            if self.hud and self.lastAimStatus and type(self.hud.setAimStatus) == 'function' then self.hud:setAimStatus(self.lastAimStatus) end
        end
        self.nextAimSetup = nil
        return
    end
    if not finite(now) or not self.projectionCoordinates then
        self:_releaseAim()
        self:_aimUnavailable('context_unavailable')
        return
    end
    local world = self:_aimWorld()
    if world == nil or world ~= snapshotWorld then
        self:_releaseAim()
        self:_aimUnavailable(world == nil and 'world_unavailable' or 'context_changed')
        return
    end
    if self.aimContext and (self.aimContext.world ~= world or self.aimContext.pc ~= pc or self.aimContext.pawn ~= pawn) then
        self:_releaseAim()
    end
    if not self.aims then
        if self.nextAimSetup and now < self.nextAimSetup then return end
        local ok, value = pcall(self.AimFeatures.new, self.env)
        if not ok or type(value) ~= 'table' then
            self:_error(ok and 'Aim module constructor unavailable' or value)
            self:_aimUnavailable('runtime_constructor_failed')
            self.nextAimSetup = now + 1
            return
        end
        self.aims = value
        self.nextAimSetup = nil
    end
    local context = self.aimContext
    if not context then
        context = {}
        context.getWorld = function() return self:_aimWorld() end
        context.isCurrent = function(currentPC, currentPawn) return self:_aimCurrent(context, currentPC, currentPawn) end
        context.project = function(worldPoint, reuse)
            if self.aimContext ~= context or self.generation ~= context.generation or self.lastTime ~= context.snapshotTime then return nil, nil, reuse end
            return self:_project(context.pc, worldPoint, reuse)
        end
        self.aimContext = context
    end
    context.pc, context.pawn, context.world = pc, pawn, world
    context.width, context.height = self.width, self.height
    context.centerX, context.centerY = self.width / 2, self.height / 2
    context.radius = 105 * math.min(1.5, self.width / 1280, self.height / 720)
    context.snapshotTime, context.generation = now, self.generation
    if not context.isCurrent(pc, pawn) then
        self:_releaseAim()
        self:_aimUnavailable('context_changed')
        return
    end
    local ok, err = pcall(self.aims.update, self.aims, pc, pawn, self.snapshots, settings, now, context)
    if not ok then
        self:_error(err)
        self:_releaseAim()
        self:_aimUnavailable('runtime_update_failed')
        self.nextAimSetup = now + 1
        return
    end
    local changed = self.aimStatusAssistant ~= settings.assistant or self.aimStatusMortar ~= settings.mortar or
        self.aimStatusSniper ~= settings.sniper or self.aimStatusForce ~= settings.force or
        self.aimIgnoreKnocked ~= settings.ignoreKnocked or self.aimIgnoreBots ~= settings.ignoreBots or
        self.aimVisibility ~= settings.visibility
    if changed or not self.nextAimStatus or now >= self.nextAimStatus then
        self.nextAimStatus = now + 0.2
        self.aimStatusAssistant, self.aimStatusMortar, self.aimStatusSniper = settings.assistant, settings.mortar, settings.sniper
        self.aimStatusForce, self.aimIgnoreKnocked, self.aimIgnoreBots, self.aimVisibility = settings.force, settings.ignoreKnocked, settings.ignoreBots, settings.visibility
        self.lastAimStatus = call(self.aims, 'getStatus') or self.lastAimStatus
        if self.lastAimStatus and type(self.hud.setAimStatus) == 'function' then self.hud:setAimStatus(self.lastAimStatus) end
    end
end

function Runtime:_releaseUI()
    self:_releaseAim()
    self:_releaseWeapons()
    self:_releaseBypass()
    self:_releaseVisuals()
    if self.hud then
        local ok, saved = pcall(self.hud.exportSettings, self.hud)
        if ok and type(saved) == 'table' then self.settings = saved end
        pcall(self.hud.reset, self.hud)
    end
    if self.adapter then pcall(self.adapter.dispose, self.adapter) end
    self.hud, self.adapter, self.parent, self.geometry = nil, nil, nil, nil
    self.projectionCoordinates, self.scale = false, nil
    self.canvasXX, self.canvasXY, self.canvasYX, self.canvasYY = nil, nil, nil, nil
end

function Runtime:stop()
    local owner, handle = self.owner, self.timer
    self.generation = self.generation + 1
    self.owner, self.timer, self.mode, self.activePawn = nil, nil, nil, nil
    if owner and handle ~= nil then call(owner, 'RemoveGameTimer', handle) end
    self:_releaseUI()
    if (self.weaponRetiring or self.bypassRetiring) and finite(self.lastTime) then
        self.lastMaintenance = self.lastTime
    end
    self.roster, self.records, self.snapshots, self.player = {}, {}, {}, {}
    self.rosterOverflow, self.rosterOverflowUnknown, self.unknownActors, self.projectionMissing = 0, false, 0, 0
    self.lastTime, self.state, self.nextRoster, self.nextSetup = nil, 'idle', 0, 0
    self.nextGameStateLookup = 0
    self.scheduledTicks, self.nextSetupTick, self.menuOnly, self.dataState = 0, 0, false, nil
end

function Runtime:_clearSnapshots()
    self:_releaseBypass()
    self:_releaseAim()
    self:_releaseWeapons()
    self:_releaseVisuals()
    self.roster, self.records, self.snapshots, self.player = {}, {}, {}, {}
    self.rosterOverflow, self.rosterOverflowUnknown, self.unknownActors, self.projectionMissing = 0, false, 0, 0
    self.activePawn, self.nextRoster = nil, 0
    if self.hud then self.hud:reset() end
end

function Runtime:forget(owner)
    if self.mode == 'controller' then
        if self.activePawn and self:_object(owner) == self:_object(self.activePawn) then
            self:_clearSnapshots()
            self.menuOnly, self.dataState = true, 'waiting_local_player'
            return true
        end
        return false
    end
    if owner == self.owner then self:stop() return true end
    return false
end

function Runtime:forgetController(pc)
    if self.mode == 'controller' and self:_object(pc) == self:_object(self.owner) then
        self:stop()
        return true
    end
    return false
end

function Runtime:_deferSetup(now)
    self.nextSetup = now and now + 1 or nil
    self.nextSetupTick = self.scheduledTicks + 50
end

function Runtime:_start(owner, mode)
    if self.owner == owner and self.mode == mode and self.timer ~= nil then return true end
    self:stop()
    self.owner, self.mode = owner, mode
    local now = self:_time()
    self:_retryWeaponCleanup(now)
    if not now and mode ~= 'controller' then
        self.owner, self.mode, self.state = nil, nil, 'unsupported_clock'
        self:_error('GameplayStatics.GetTimeSeconds is unavailable; no substitute clock used')
        return false
    end
    if type(read(owner, 'AddGameTimer')) ~= 'function' or type(read(owner, 'RemoveGameTimer')) ~= 'function' then
        self.owner, self.mode, self.state = nil, nil, 'unsupported_timer'
        self:_error('Owner timer registration/removal is unavailable')
        return false
    end
    self.lastTime, self.nextSetup, self.state = now, now, 'waiting_ui'
    local generation = self.generation
    local callback = function()
        if self.generation ~= generation or self.owner ~= owner then return end
        self.scheduledTicks = self.scheduledTicks + 1
        local ok, err = pcall(self._step, self)
        if not ok then
            self:_error(err)
            self:_releaseUI()
            self:_deferSetup(self:_time())
            self.state = 'retrying_after_error'
        end
    end
    local ok, handle = pcall(owner.AddGameTimer, owner, 1/30, true, callback)
    if not ok or handle == nil then
        self:stop()
        self.state = 'unsupported_timer'
        self:_error(ok and 'AddGameTimer did not return a removable handle' or handle)
        return false
    end
    self.timer = handle
    return true
end

function Runtime:consider(owner)
    if not self:_licenseAllows() then return false end
    if not self:_local(owner) then return false end
    if self.mode == 'controller' and self.timer ~= nil and self:_localController(self.owner) then return true end
    return self:_start(owner, 'character')
end

function Runtime:considerController(pc)
    if not self:_licenseAllows() then return false end
    if not self:_localController(pc) then return false end
    return self:_start(pc, 'controller')
end

function Runtime:_vector2(x, y)
    if self.vector2 ~= nil then
        local ok, value = pcall(self.vector2, x, y)
        if ok and point2(value) ~= nil then return value end
        error('Vector2D constructor failed or returned invalid coordinates', 0)
    end
    return { X = x, Y = y }
end

function Runtime:_vector3(x, y, z)
    if self.vector3 ~= nil then
        local ok, value = pcall(self.vector3, x, y, z)
        if ok and point(value) ~= nil then return value end
        error('Vector constructor failed or returned invalid coordinates', 0)
    end
    return { X = x, Y = y, Z = z }
end

function Runtime:_setup(now)
    if now and self.nextSetup then
        if now < self.nextSetup then return false end
    elseif self.scheduledTicks < self.nextSetupTick then return false end
    self:_deferSetup(now)
    self.setupAttempts = self.setupAttempts + 1
    if not self.ui then
        self.ui = module(self.env, 'InGameUITools', 'GameLua.Mod.BaseMod.Common.UI.InGameUITools')
    end
    local ui = static(self.ui, 'GetMainControlBaseUI')
    if not self:_valid(ui) then self.state = 'waiting_ui' return false end
    local parent = read(ui, 'CanvasPanel_0')
    if not self:_valid(parent) then parent = read(ui, 'CanvasPanel_42') end
    if not self:_valid(parent) then self.state = 'waiting_canvas' return false end
    local ok, adapter, err = pcall(self.UMGAdapter.new, parent, self.env)
    if not ok or not adapter then
        self.state = 'unsupported_renderer'
        self:_error(ok and err or adapter)
        return false
    end
    self.adapter, self.parent = adapter, parent
    local config = { range = self.range, maxActors = self.maxActors }
    if self.settings then
        config.features = self.settings.features
        config.featureSets, config.style, config.visual = self.settings.featureSets, self.settings.style, self.settings.visual
        config.aim = self.settings.aim
        config.buttonX, config.buttonY = self.settings.buttonX, self.settings.buttonY
    end
    self.hud = self.HUD.new(adapter.renderer, config)
    self.nextRoster, self.state = 0, 'ready'
    return true
end

function Runtime:_transform(pc)
    local cache = self._transformCache
    if cache and cache.pc == pc and cache.width == self._lastVpW and cache.height == self._lastVpH then
        local now = self.lastTime or 0
        if cache.stamp and (now - cache.stamp) < 1.0 then
            return true
        end
    end
    self.geometry, self.scale = nil, nil
    self.canvasXX, self.canvasXY, self.canvasYX, self.canvasYY = nil, nil, nil, nil
    local viewport = self.viewportProbe or self:_vector2(0, 0)
    self.viewportProbe = viewport
    viewport.X, viewport.Y = 0, 0
    call(pc, 'GetViewportSize', viewport)
    local w, h = point2(viewport)
    if not w or w <= 0 or h <= 0 then
        viewport = static(self.wll, 'GetViewportSize', pc)
        w, h = point2(viewport)
    end
    self._lastVpW, self._lastVpH = w, h
    local geom = call(self.parent, 'GetCachedGeometry')
    self.projectionCoordinates = false
    if not w or w <= 0 or h <= 0 then
        local localSize = call(geom, 'GetLocalSize') or static(self.sbl, 'GetLocalSize', geom)
        local lw, lh = point2(localSize)
        if self.mode ~= 'controller' or not lw or lw <= 0 or lh <= 0 then
            return false, 'Viewport dimensions unavailable'
        end
        self.geometry, self.originX, self.originY, self.scale = nil, 0, 0, nil
        self.width, self.height = lw, lh
    else
        local origin, corner, horizontal
        if geom then
            self.canvasOriginProbe = self.canvasOriginProbe or self:_vector2(0, 0)
            self.canvasCornerProbe = self.canvasCornerProbe or self:_vector2(w, h)
            self.canvasHorizontalProbe = self.canvasHorizontalProbe or self:_vector2(w, 0)
            self.canvasOriginProbe.X, self.canvasOriginProbe.Y = 0, 0
            self.canvasCornerProbe.X, self.canvasCornerProbe.Y = w, h
            self.canvasHorizontalProbe.X, self.canvasHorizontalProbe.Y = w, 0
            origin = static(self.sbl, 'AbsoluteToLocal', geom, self.canvasOriginProbe)
            corner = static(self.sbl, 'AbsoluteToLocal', geom, self.canvasCornerProbe)
            horizontal = static(self.sbl, 'AbsoluteToLocal', geom, self.canvasHorizontalProbe)
        end
        local ox, oy = point2(origin)
        local ex, ey = point2(corner)
        local hx, hy = point2(horizontal)
        if ox and ex and hx then
            local xx, yx = (hx - ox) / w, (hy - oy) / w
            local xy, yy = (ex - hx) / h, (ey - hy) / h
            local determinant = xx * yy - xy * yx
            if not finite(determinant) or determinant == 0 or
                abs(determinant) <= 1e-12 * math.max(abs(xx * yy), abs(xy * yx)) then
                return false, 'Non-invertible canvas transform'
            end
            if ex <= ox or ey <= oy then return false, 'Canvas transform has unusable viewport bounds' end
            self.canvasXX, self.canvasXY, self.canvasYX, self.canvasYY = xx, xy, yx, yy
            self.geometry, self.originX, self.originY = geom, ox, oy
            self.width, self.height, self.scale = ex - ox, ey - oy, nil
        else
            local scale = static(self.wll, 'GetViewportScale', pc)
            if not finite(scale) or scale <= 0 then
                return false, 'Canvas transform and valid DPI scale unavailable'
            end
            self.geometry, self.originX, self.originY, self.scale = nil, 0, 0, scale
            self.width, self.height = w / scale, h / scale
        end
        self.projectionCoordinates = true
    end
    if type(self.adapter.setViewportOrigin) == 'function' then
        self.adapter:setViewportOrigin(self.originX, self.originY)
    elseif abs(self.originX) > 0.5 or abs(self.originY) > 0.5 then
        return false, 'Offset parent canvas needs adapter.setViewportOrigin'
    end
    self._transformCache = { pc = pc, stamp = self.lastTime or 0, width = w, height = h }
    return true
end

function Runtime:_toCanvas(x, y)
    if not finite(x) or not finite(y) then return nil end
    if self.geometry then
        if self.canvasXX == nil then return nil end
        local cx = self.canvasXX * x + self.canvasXY * y
        local cy = self.canvasYX * x + self.canvasYY * y
        if finite(cx) and finite(cy) then return cx, cy end
        return nil
    end
    if self.scale then return x / self.scale, y / self.scale end
end

function Runtime:_metadata(actor, record, now)
    if record.id ~= nil and type(record.isBot) == 'boolean' and record.team ~= nil and record.name ~= nil then
        return
    end
    local state = self:_playerState(actor)
    record.id = self:_key(actor, state)
    record.team = self:_team(actor, state)
    local name = call(actor, 'GetPlayerNameSafety')
    if type(name) ~= 'string' or name == '' then name = call(actor, 'GetPlayerName') end
    if type(name) ~= 'string' or name == '' then name = call(state, 'GetPlayerName') end
    if type(name) ~= 'string' or name == '' then name = read(state, 'PlayerName') end
    if type(name) ~= 'string' or name == '' then name = read(actor, 'PlayerName') end
    record.name = type(name) == 'string' and name or nil
    local bot = flag(call(self.env.Game, 'IsAI', actor))
    bot = mergeFlag(bot, read(actor, 'bIsAI'))
    bot = mergeFlag(bot, read(actor, 'IsAI'))
    bot = mergeFlag(bot, call(actor, 'IsBot'))
    if state then
        bot = mergeFlag(bot, read(state, 'bIsABot'))
        bot = mergeFlag(bot, read(state, 'bIsBot'))
        bot = mergeFlag(bot, read(state, 'bIsAI'))
        bot = mergeFlag(bot, call(state, 'IsBot'))
    end
    record.isBot = bot
    if not self:_valid(record.capsule) then
        local capsule = call(actor, 'GetCapsuleComponent') or read(actor, 'CapsuleComponent')
        record.capsule = self:_valid(capsule) and capsule or nil
    end
end

function Runtime:_roster(now)
    if now < self.nextRoster then return end
    -- Crowded lobbies do not need a full roster rebuild at 5 Hz. The current
    -- roster remains active between scans, so existing ESP features continue
    -- rendering while expensive enumeration is throttled.
    local scanInterval = (#self.roster > 48) and 0.35 or 0.20
    self.nextRoster = now + scanInterval
    local old = self.records
    local kept, roster, count, total, unknown = {}, self.roster, 0, 0, false
    local function take(actor)
        total = total + 1
        if total <= self.maxActors and self:_valid(actor) and not kept[actor] then
            count = count + 1
            roster[count] = actor
            kept[actor] = old[actor] or {}
        end
    end
    local function collect(pawns)
        if type(pawns) == 'table' then
            for _, actor in pairs(pawns) do
                take(actor)
                if total > self.maxActors then unknown = true break end
            end
        elseif pawns ~= nil and type(read(pawns, 'Num')) == 'function' and type(read(pawns, 'Get')) == 'function' then
            local n = call(pawns, 'Num')
            if finite(n) and n >= 0 then
                total = floor(n)
                for i = 0, math.min(total, self.maxActors) - 1 do
                    local actor = call(pawns, 'Get', i)
                    if self:_valid(actor) and not kept[actor] then
                        count = count + 1
                        roster[count] = actor
                        kept[actor] = old[actor] or {}
                    end
                end
            end
        else
            return false
        end
        return true
    end
    local supported = collect(call(self.env.Game, 'GetAllPlayerPawns'))
    if count == 0 then
        local gameState = self:_valid(self.env.CGameState) and self.env.CGameState or self.cgs
        if not gameState and now >= self.nextGameStateLookup then
            self.nextGameStateLookup = now + 1
            self.cgs = module(self.env, 'CGameState', 'GameLua.GameCore.Data.CGameState')
            gameState = self.cgs
        end
        local fallback = call(gameState, 'GetAllCharacters')
        if fallback ~= nil then
            total, unknown = 0, false
            supported = collect(fallback)
        end
    end
    if not supported then self:_error('No supported roster from Game or CGameState') end
    for i = count + 1, #roster do roster[i] = nil end
    self.records, self.rosterOverflow = kept, math.max(0, total - self.maxActors)
    self.rosterOverflowUnknown = unknown
end

function Runtime:_project(pc, world, output)
    output = output or self:_vector2(0, 0)
    output.X, output.Y = 0, 0
    local fn = read(pc, 'ProjectWorldLocationToScreen')
    if type(fn) ~= 'function' then return nil, nil, output end
    local ok, result = pcall(fn, pc, world, output, true)
    if not ok or (result ~= true and result ~= 1) then return nil, nil, output end
    local x, y = point2(output)
    if x then
        local cx, cy = self:_toCanvas(x, y)
        return cx, cy, output
    end
    return nil, nil, output
end

function Runtime:_actor(actor, r, now, pc)
    if not self:_valid(actor) then return false end
    self:_metadata(actor, r, now)
    if r.id == nil or type(r.isBot) ~= 'boolean' then
        self.unknownActors = self.unknownActors + 1
        return false
    end
    if r.id == self.player.id or (self.player.team ~= nil and r.team == self.player.team) then return false end
    local _, x, y, z = self:_location(actor)
    if not x then return false end
    local dx, dy, dz = y / 100 - self.player.x, x / 100 - self.player.y, z / 100 - self.player.z
    if dx * dx + dy * dy + dz * dz > self.range * self.range then return false end
    local health, maxHealth = read(actor, 'Health'), read(actor, 'HealthMax')
    if not finite(maxHealth) or maxHealth <= 0 then maxHealth = read(actor, 'MaxHealth') end
    if not finite(health) or not finite(maxHealth) or maxHealth <= 0 then return false end
    if flag(call(actor, 'IsAlive')) == false then return false end
    local status = read(actor, 'HealthStatus')
    local near = read(self.healthStatus, 'HasLastBreath')
    local finished = read(self.healthStatus, 'FinishedLastBreath')
    local knocked = near ~= nil and status == near
    if finished ~= nil and status == finished then return false end
    if health <= 0 and not knocked then return false end
    r.actor = actor
    r.updatedAt = now
    r.x, r.y, r.z, r.health, r.maxHealth, r.knocked, r.alive = y / 100, x / 100, z / 100, health, maxHealth, knocked, true
    -- Keep the last good screen coordinates instead of invalidating them every tick.
    -- Reprojection is refreshed on movement or at a bounded cadence, which avoids
    -- thousands of ProjectWorldLocationToScreen calls per second in crowded fights.
    local features = self.hud.features
    local headNeeded = features.enabled and (features.names or features.health or features.distance or
        (r.isBot and features.botHeadLines) or (not r.isBot and features.enemyHeadLines))
    local feetNeeded = features.enabled and (features.distance or features.health or
        (r.isBot and features.botFeetLines) or (not r.isBot and features.enemyFeetLines))
    local capsule = r.capsule
    if (headNeeded or feetNeeded) and self:_valid(capsule) then
        local center = call(capsule, 'K2_GetComponentLocation') or call(capsule, 'GetComponentLocation')
        local cx, cy, cz = point(center)
        local half = call(capsule, 'GetScaledCapsuleHalfHeight')
        if cx and finite(half) and half > 0 then
            if headNeeded then
                r.headWorld = r.headWorld or self:_vector3(cx, cy, cz + half)
                r.headWorld.X, r.headWorld.Y, r.headWorld.Z = cx, cy, cz + half
                local cachedH = r._cachedHeadWorld
                local moved = not cachedH or (cachedH.X - cx) ^ 2 + (cachedH.Y - cy) ^ 2 + (cachedH.Z - (cz + half)) ^ 2 > 0.0004
                local projectDue = not r._nextProject or now >= r._nextProject
                if moved or not r.headPix or projectDue then
                    r.headX, r.headY, r.headPix = self:_project(pc, r.headWorld, r.headPix)
                    r._cachedHeadWorld = r._cachedHeadWorld or self:_vector3(0, 0, 0)
                    r._cachedHeadWorld.X, r._cachedHeadWorld.Y, r._cachedHeadWorld.Z = cx, cy, cz + half
                    r._nextProject = now + 0.075
                end
            end
            if feetNeeded then
                r.feetWorld = r.feetWorld or self:_vector3(cx, cy, cz - half)
                r.feetWorld.X, r.feetWorld.Y, r.feetWorld.Z = cx, cy, cz - half
                local cachedF = r._cachedFeetWorld
                local moved = not cachedF or (cachedF.X - cx) ^ 2 + (cachedF.Y - cy) ^ 2 + (cachedF.Z - (cz - half)) ^ 2 > 0.0004
                local projectDue = not r._nextFeetProject or now >= r._nextFeetProject
                if moved or not r.feetPix or projectDue then
                    r.feetX, r.feetY, r.feetPix = self:_project(pc, r.feetWorld, r.feetPix)
                    r._cachedFeetWorld = r._cachedFeetWorld or self:_vector3(0, 0, 0)
                    r._cachedFeetWorld.X, r._cachedFeetWorld.Y, r._cachedFeetWorld.Z = cx, cy, cz - half
                    r._nextFeetProject = now + 0.075
                end
            end
        end
    end
    if (headNeeded and not r.headX) or (feetNeeded and not r.feetX) then
        self.projectionMissing = self.projectionMissing + 1
    end
    return true
end

function Runtime:_yaw(pawn, pc)
    local cm = call(pc, 'GetPlayerCameraManager') or read(pc, 'PlayerCameraManager')
    local rotation = self:_valid(cm) and call(cm, 'GetCameraRotation') or nil
    local yaw = read(rotation, 'Yaw')
    if not finite(yaw) then yaw = read(call(pc, 'GetControlRotation'), 'Yaw') end
    if not finite(yaw) then yaw = read(call(pawn, 'K2_GetActorRotation'), 'Yaw') end
    if finite(yaw) then return yaw * pi / 180 end
end

function Runtime:_drawFrame(pc, now)
    self.hud:resize(self.width, self.height)
    self.adapter:beginFrame()
    self.adapter:syncInput(self.hud, pc, self.toCanvas)
    self.hud:draw(self.width, self.height, now or 0)
    self.adapter:endFrame()
    if not self.adapter:valid() then
        local status = call(self.adapter, 'getStatus')
        self:_error(read(status, 'error') or 'Native renderer became invalid during drawing')
        self:_releaseUI()
        self:_deferSetup(now)
        self.state = 'unsupported_renderer'
        return false
    end
    self.totalFrames = self.totalFrames + 1
    return true
end

function Runtime:_drawMenuOnly(reason, pc, now)
    if not self.menuOnly or self.dataState ~= reason then self:_clearSnapshots() end
    self.menuOnly, self.dataState = true, reason
    if self:_drawFrame(pc, now) then self.state = reason end
end

function Runtime:_step()
    if not self:_licenseAllows() then return end
    local controllerMode = self.mode == 'controller'
    local pc
    if controllerMode then
        local localController
        localController, pc = self:_localController(self.owner)
        if not localController then self:stop() return end
    elseif not self:_local(self.owner) then
        self:stop()
        return
    end
    local now = self:_time()
    self:_retryWeaponCleanup(now)
    if not now and not controllerMode then
        self:stop()
        self.state = 'unsupported_clock'
        self:_error('Engine clock became unavailable')
        return
    end
    if now and self.lastTime and now < self.lastTime then
        self:_releaseUI()
        self.nextSetup, self.nextRoster = now, now
        self.nextGameStateLookup = now
        self.roster, self.records, self.snapshots = {}, {}, {}
    end
    self.lastTime = now
    if self.adapter and (not self:_valid(self.parent) or not self.adapter:valid()) then
        local status = call(self.adapter, 'getStatus')
        self:_error(read(status, 'error') or 'Native overlay or parent canvas became invalid')
        self:_releaseUI()
        self.state = 'waiting_ui'
        self:_deferSetup(now)
    end
    if not self.adapter and not self:_setup(now) then return end
    pc = pc or self:_controller()
    local pawn = self:_pawn(pc)
    if not self:_valid(pc) and not self:_valid(self:_object(pc)) then
        self:_releaseUI()
        self:_deferSetup(now)
        self.state = 'waiting_local_player'
        return
    end
    if not controllerMode then
        if not self:_valid(pawn) then
            self:_releaseUI()
            self:_deferSetup(now)
            self.state = 'waiting_local_player'
            return
        end
        if self:_object(pawn) ~= self:_object(self.owner) then self:stop() return end
    end
    local transformed, reason = self:_transform(pc)
    if not transformed then
        self:_error(reason)
        self:_releaseUI()
        self:_deferSetup(now)
        self.state = 'unsupported_coordinates'
        return
    end
    if not now then
        if self.dataState ~= 'unsupported_clock' then
            self:_error('GameplayStatics.GetTimeSeconds unavailable; menu only, no actor clock substituted')
        end
        self:_drawMenuOnly('unsupported_clock', pc, nil)
        return
    end
    if not self.projectionCoordinates then
        self:_drawMenuOnly('unsupported_projection_coordinates', pc, now)
        return
    end
    if not self:_valid(pawn) then
        self:_drawMenuOnly('waiting_local_player', pc, now)
        return
    end
    if self.activePawn and self:_object(self.activePawn) ~= self:_object(pawn) then self:_clearSnapshots() end
    local _, x, y, z = self:_location(pawn)
    local yaw = self:_yaw(pawn, pc)
    local p = self.player
    if p.sourcePawn ~= pawn or p.sourcePC ~= pc or not p.nextMeta or now >= p.nextMeta then
        local localState = self:_playerState(pawn)
        p.id = self:_key(pawn, localState)
        if not p.id then p.id = self:_key(pc, self:_playerState(pc)) end
        p.team = self:_team(pawn, localState)
        p.sourcePawn, p.sourcePC, p.nextMeta = pawn, pc, now + 0.5
    end
    local key = p.id
    if not x or not yaw or not id(key) then
        if controllerMode then
            self:_drawMenuOnly('waiting_local_data', pc, now)
        else
            self:_releaseUI()
            self:_deferSetup(now)
            self.state = 'waiting_local_data'
        end
        return
    end
    self.activePawn, self.menuOnly, self.dataState = pawn, false, nil
    p.x, p.y, p.z, p.yaw = y / 100, x / 100, z / 100, yaw
    local aiming = read(pawn, 'bIsWeaponAiming')
    p.aiming = aiming == true or aiming == 1
    local count = 0
    self.unknownActors, self.projectionMissing = 0, 0
    local aimEnabled = self:_aimEnabled()
    local aimWorld = aimEnabled and self:_aimWorld() or nil
    if aimEnabled and self.aimContext and self.aimContext.world ~= aimWorld then
        self:_releaseAim()
        self.nextRoster = 0
    end
    if self.hud.features.enabled or (self.hud.visual and self.hud.visual.wallHack) or aimEnabled then
        self:_roster(now)

        -- Crowded-match protection. This throttles only the expensive actor/native
        -- pass; it does not remove or disable any feature.
        local rosterSize = #self.roster
        local passInterval = 1
        if rosterSize > 128 then
            passInterval = 4
        elseif rosterSize > 64 then
            passInterval = 3
        elseif rosterSize > 32 then
            passInterval = 2
        end
        if aimEnabled then
            -- Keep aim data fresher than the visual pass in crowded fights.
            passInterval = math.min(passInterval, 2)
        end
        self.actorPassInterval = passInterval
        self.actorPass = (self.actorPass or 0) + 1

        local doActorPass = passInterval == 1 or
            (self.actorPass % passInterval) == 0 or
            #self.snapshots == 0

        if doActorPass then
            count = 0
            for _, actor in ipairs(self.roster) do
                local record = self.records[actor]
                if record and self:_actor(actor, record, now, pc) then
                    count = count + 1
                    self.snapshots[count] = record
                end
            end
            for i = count + 1, #self.snapshots do self.snapshots[i] = nil end
        else
            -- Reuse the last good snapshot set instead of rebuilding it.
            count = #self.snapshots
        end
    else
        self.nextRoster = 0
        self.actorPass = 0
        for i = 1, #self.snapshots do self.snapshots[i] = nil end
    end
    if type(self.hud.setSourceOverflow) == 'function' then
        self.hud:setSourceOverflow(self.rosterOverflow, not self.rosterOverflowUnknown)
    end
    self.hud:update(self.snapshots, p, now)
    self:_syncVisuals(pawn, now)
    self:_syncWeapons(pawn, now)
    self:_syncBypass(now)
    self:_syncAim(pc, pawn, now, aimWorld)
    if self:_drawFrame(pc, now) then self.state = 'running' end
end

function Runtime:getStatus()
    local renderer = self.adapter and self.adapter:getStatus() or nil
    return {
        state = self.state, ownerActive = self.owner ~= nil, timerActive = self.timer ~= nil,
        controllerMode = self.mode == 'controller', menuOnly = self.menuOnly, dataState = self.dataState,
        projectionCoordinates = self.projectionCoordinates == true, scheduledTicks = self.scheduledTicks,
        frames = self.totalFrames, setupAttempts = self.setupAttempts,
        rosterCount = #self.roster, snapshotCount = #self.snapshots,
        rosterOverflow = self.rosterOverflow, rosterOverflowUnknown = self.rosterOverflowUnknown,
        unknownActors = self.unknownActors,
        projectionMissing = self.projectionMissing, lastError = self.lastError,
        renderer = renderer, visual = self.visuals and self.visuals:getStatus() or self.lastVisualStatus,
        aim = self.aims and call(self.aims, 'getStatus') or self.lastAimStatus,
        weapon = self.weapons and call(self.weapons, 'getStatus') or self.lastWeaponStatus,
        weaponSupported = self.WeaponFeatures ~= nil,
        bypass = self.bypass and call(self.bypass, 'getStatus') or self.lastBypassStatus,
        bypassSupported = self.BypassFeatures ~= nil,
        aimSupported = self.AimFeatures ~= nil, bindingUnverified = true, captureExclusionSupported = false,
        endpointMode = 'scaled_collision_capsule_approximation', updateInterval = 1/30,
        rosterInterval = 0.2, metadataInterval = 0.5, maxActors = self.maxActors
    }
end

return Runtime
end)()

-- ========================================================================
-- 13. CONTROLLER STARTUP AND RETRY
-- ========================================================================

local HackerESPBootstrap = (function()
local Bootstrap = {}
Bootstrap.__index = Bootstrap
local REGISTRY = '_RedCyanESPBootstrap'
local function read(o, k)
    if o == nil then return nil end
    local ok, v = pcall(function() return o[k] end)
    if ok then return v end
end
local function call(o, k, ...)
    local fn = read(o, k)
    if type(fn) ~= 'function' then return nil end
    local ok, a = pcall(fn, o, ...)
    if ok then return a end
end
function Bootstrap.new(runtime, env, license)
    return setmetatable({
        runtime = runtime, env = env or _G, license = license, generation = 0, logCount = 0,
        started = false, disposed = false, watchdog = nil, controller = nil
    }, Bootstrap)
end
function Bootstrap:_valid(o)
    if o == nil then return false end
    local fn = read(self.env.slua, 'isValid')
    if type(fn) == 'function' then
        local ok, v = pcall(fn, o)
        if ok and v == true then return true end
    end
    return call(self.env.Game, 'IsValid', o) == true
end
function Bootstrap:_controller()
    local getter = read(self.env.GameplayData, 'GetPlayerController')
    if type(getter) == 'function' then
        local ok, pc = pcall(getter)
        if ok and (self:_valid(pc) or self:_valid(read(pc, 'Object'))) then return pc end
    end
    local pc = call(self.env.slua_GameFrontendHUD, 'GetPlayerController')
    if self:_valid(pc) or self:_valid(read(pc, 'Object')) then return pc end
end
function Bootstrap:_report(state)
    self.state = state
    if self.lastLogged == state or self.logCount >= 12 then return end
    self.lastLogged = state
    self.logCount = self.logCount + 1
    if type(self.env.print) == 'function' then pcall(self.env.print, '[RedCyanESP] ' .. state) end
end
function Bootstrap:_clearWatchdog()
    self.generation = self.generation + 1
    if self.watchdog ~= nil then
        call(self.watchdogOwner, self.watchdogClear, self.watchdog)
    end
    self.watchdog, self.watchdogOwner, self.watchdogClear = nil, nil, nil
end
function Bootstrap:_ensureWatchdog()
    local world = self.env.CGameWorld
    if self.watchdogAttempted and self.watchdogWorld == world and self.watchdogPC == self.controller then return end
    self:_clearWatchdog()
    self.watchdogAttempted = true
    self.watchdogWorld = world
    self.watchdogPC = self.controller
    local host, add, remove = self.env.Game, 'SetTimer', 'ClearTimer'
    if type(read(host, add)) ~= 'function' or type(read(host, remove)) ~= 'function' then
        host, add, remove = self.controller, 'AddGameTimer', 'RemoveGameTimer'
    end
    if type(read(host, add)) ~= 'function' or type(read(host, remove)) ~= 'function' then
        self.watchdogAttempted = false
        self.lastError = 'No paired watchdog timer API; character callbacks can retry startup'
        return
    end
    local generation = self.generation
    local fn = function()
        if self.disposed or generation ~= self.generation then return end
        local ok, err = pcall(self.refresh, self)
        if not ok then
            self.lastError = tostring(err):sub(1, 220)
            self:_report('startup_error')
        end
    end
    local ok, handle = pcall(read(host, add), host, 1, true, fn)
    if not ok or handle == nil then
        self.generation = self.generation + 1
        self.lastError = ok and 'Watchdog timer supplied no removable handle' or tostring(handle):sub(1, 220)
        return
    end
    self.watchdog, self.watchdogOwner, self.watchdogClear = handle, host, remove
    self.lastError = nil
end
function Bootstrap:refresh()
    if self.disposed then return false end
    call(self.runtime, 'maintenance')
    local pc = self:_controller()
    local world = self.env.CGameWorld
    if pc ~= self.controller or world ~= self.controllerWorld then
        if self.controller then pcall(self.runtime.forgetController, self.runtime, self.controller) end
        self.controller, self.controllerWorld = pc, world
    end
   -- License check bypassed
-- (self.license block removed)
    local attached = false
    if pc then
        local ok, result = pcall(self.runtime.considerController, self.runtime, pc)
        attached = ok and result == true
        if not ok then self.lastError = tostring(result):sub(1, 220) end
        local status = call(self.runtime, 'getStatus')
        self:_report(attached and ('controller_' .. tostring(read(status, 'state') or 'ready')) or 'waiting_controller_timer')
    else
        self:_report('waiting_controller')
    end
    self:_ensureWatchdog()
    return attached
end
function Bootstrap:start()
    if self.disposed then return false end
    if not self.started then
        local registry = self.env._G or self.env
        local old = read(registry, REGISTRY)
        if old and old ~= self and type(read(old, 'dispose')) == 'function' then pcall(old.dispose, old) end
        registry[REGISTRY] = self
        self.registry = registry
        self.started = true
        self:_report('module_loaded')
    end
    return self:refresh()
end
function Bootstrap:getStatus()
    return {
        started = self.started, disposed = self.disposed, state = self.state,
        controllerAvailable = self.controller ~= nil, watchdogActive = self.watchdog ~= nil,
        lastError = self.lastError, licenseError = self.licenseError, licenseBlocked = self.licenseBlocked == true
    }
end
function Bootstrap:dispose()
    if self.disposed then return end
    self.disposed = true
    self:_clearWatchdog()
    pcall(self.runtime.stop, self.runtime)
    -- FIX: license ab global session hai - isay dispose NA karo
    -- if self.license then call(self.license, 'dispose') end   <-- YE LINE HATAO
    if self.registry and self.registry[REGISTRY] == self then self.registry[REGISTRY] = nil end
    self.controller = nil
end
return Bootstrap
end)()

-- ========================================================================
-- 13.5 AUTO-RUN LIBANOGS BYPASS
-- ========================================================================

local HackerAnogsBypass = (function()
    local SH = _G.ScriptHelperClient
    if not SH then
        return { ready = false, reason = 'ScriptHelperClient unavailable' }
    end
    local KNOWN_PKGS = {
        ["com.tencent.ig"]    = "/data/app/~~2U5OPyLPSNrCp3Jhv6O4Xg==/com.tencent.ig-rxZaOzwfUVAPdioMsk4emQ==/lib/arm64/",
        ["com.pubg.krmobile"] = "/data/app/~~uBLiktAOPJCRfbQA01C-3Q==/com.pubg.krmobile-nhvnm6_ClIAV0J93P86daw==/lib/arm64/",
        ["com.pubg.imobile"]  = "/data/app/~~p9qsLKUJYSx0V20AUx9EWg==/com.pubg.imobile-oEDhX_GaHiB7HYo8hWh0Hg==/lib/arm64/",
    }
    local function detectPackage()
        if SH.GetNativePackageTag then
            local ok, p = pcall(SH.GetNativePackageTag)
            if ok and type(p) == "string" and KNOWN_PKGS[p] then return p end
        end
        for p in pairs(KNOWN_PKGS) do return p end
        return "com.tencent.ig"
    end
    local PKG     = detectPackage()
    local LIBDIR  = KNOWN_PKGS[PKG] or ""
    local LIBFILE = LIBDIR .. "libanogs.so"
    local APPLIED_PATCH = {}
    local APPLIED_HOOK  = {}
    local BASE_CACHE    = {}
    local function kdup(lib, off) return string.format("%s@0x%X", lib, off) end
    local function getBase(lib)
        if BASE_CACHE[lib] then return BASE_CACHE[lib] end
        local b = 0
        local ok, r = pcall(SH.GetPUBGModuleBaseAddr, lib)
        if ok and type(r) == "number" then b = r
        elseif ok and type(r) == "table" then b = r.base or r.addr or r[1] or 0 end
        if b == 0 then
            local alt = lib:gsub("%.so$", "")
            local ok2, r2 = pcall(SH.GetPUBGModuleBaseAddr, alt)
            if ok2 and type(r2) == "number" then b = r2 end
        end
        BASE_CACHE[lib] = b
        return b
    end
    local function hex2bin(h)
        return (h:gsub("%x%x", function(b) return string.char(tonumber(b, 16)) end))
    end
    local function applyPatch(lib, off, hexbytes)
        local base = getBase(lib)
        local addr = base > 0 and (base + off) or nil
        if SH.ProcessSoPatch and addr then
            local ok = pcall(SH.ProcessSoPatch, addr, hexbytes)
            if ok then return true, "P1" end
        end
        if SH.ProcessSoPatch and addr then
            local ok = pcall(SH.ProcessSoPatch, addr, hex2bin(hexbytes))
            if ok then return true, "P2" end
        end
        if SH.ProcessSoPatch then
            local ok = pcall(SH.ProcessSoPatch, {
                { module = lib, offset = off, addr = addr,
                  bytes = hexbytes, data = hex2bin(hexbytes) }
            })
            if ok then return true, "P3" end
        end
        if SH.WriteFileAtPath and SH.SetUpdatedSoPatchFile and SH.ProcessSoPatch then
            local data = string.format("%s|0x%X|%s", lib, off, hexbytes)
            local paths = {
                "/storage/emulated/0/Android/data/" .. PKG .. "/files/anogs.bin",
                "/sdcard/Android/data/" .. PKG .. "/files/anogs.bin",
                "/data/local/tmp/anogs.bin",
            }
            for _, path in ipairs(paths) do
                local okW = pcall(SH.WriteFileAtPath, path, data)
                if okW then
                    pcall(SH.SetUpdatedSoPatchFile, path)
                    local okP = pcall(SH.ProcessSoPatch)
                    if okP then return true, "P4" end
                end
            end
        end
        return false, "no-path"
    end
    local function installHook(lib, off, handler)
        local base = getBase(lib)
        if _G.__FRAMEWORK_HOOK_LIB_NO_ORIG then
            local ok = pcall(_G.__FRAMEWORK_HOOK_LIB_NO_ORIG, lib, off, handler)
            if ok then return true, "H1" end
        end
        if SH.InstallHook then
            local ok = pcall(SH.InstallHook, lib, off, handler)
            if ok then return true, "H2a" end
        end
        if SH.HookFunction then
            local ok = pcall(SH.HookFunction, lib, off, handler)
            if ok then return true, "H2b" end
        end
        if SH.AddHook then
            local ok = pcall(SH.AddHook, lib, off, handler)
            if ok then return true, "H2c" end
        end
        if SH.AllocVirMem and SH.ProcessSoPatch and base > 0 then
            local slot = pcall(SH.AllocVirMem, 16)
            if slot and type(slot) == "number" and slot > 0 then
                return false, "H3-no-native-bridge"
            end
        end
        return false, "no-hook-api"
    end
    local function PATCH_LIB(lib, offStr, bytes)
        local off = tonumber(offStr)
        if not off then return end
        local k = kdup(lib, off)
        if APPLIED_PATCH[k] then return end
        local ok, how = applyPatch(lib, off, bytes)
        if ok then
            APPLIED_PATCH[k] = true
            print(string.format("[ANOGS] patch %s @0x%X [%s] via %s", lib, off, bytes, how))
        else
            print(string.format("[ANOGS] patch %s @0x%X FAILED (%s)", lib, off, how))
        end
    end
    local function HOOK_LIB_NO_ORIG(lib, offStr, handler)
        local off = tonumber(offStr)
        if not off then return end
        local k = kdup(lib, off)
        if APPLIED_HOOK[k] then return end
        local ok, how = installHook(lib, off, handler)
        if ok then
            APPLIED_HOOK[k] = true
            print(string.format("[ANOGS] hook %s @0x%X via %s", lib, off, how))
        else
            print(string.format("[ANOGS] hook %s @0x%X FAILED (%s)", lib, off, how))
        end
    end
    local function Hacker(...) return 0 end
    _G.Hacker = Hacker
    local function applyAll()
        PATCH_LIB("libanogs.so", "0x2328F0", "C0 03 5F D6")
        PATCH_LIB("libanogs.so", "0x213360", "C0 03 5F D6")
        PATCH_LIB("libanogs.so", "0x2ECE70", "C0 03 5F D6")
        PATCH_LIB("libanogs.so", "0x4D5998", "00 00 80 D2 C0 03 5F D6")
        PATCH_LIB("libanogs.so", "0x4D59A4", "00 00 80 D2 C0 03 5F D6")
        PATCH_LIB("libanogs.so", "0x4D4DB4", "00 00 80 D2 C0 03 5F D6")
        PATCH_LIB("libanogs.so", "0x4D4DD0", "00 00 80 D2 C0 03 5F D6")
        PATCH_LIB("libanogs.so", "0x4D571C", "00 00 80 D2 C0 03 5F D6")
        PATCH_LIB("libanogs.so", "0x4D5748", "00 00 80 D2 C0 03 5F D6")
        HOOK_LIB_NO_ORIG("libanogs.so", "0x371418", Hacker)
        HOOK_LIB_NO_ORIG("libanogs.so", "0x431800", Hacker)
        HOOK_LIB_NO_ORIG("libanogs.so", "0x39F56C", Hacker)
        HOOK_LIB_NO_ORIG("libanogs.so", "0x3A564C", Hacker)
    end
    applyAll()
    return {
        ready            = true,
        pkg              = PKG,
        libfile          = LIBFILE,
        applied_patch    = APPLIED_PATCH,
        applied_hook     = APPLIED_HOOK,
        PATCH_LIB        = PATCH_LIB,
        HOOK_LIB_NO_ORIG = HOOK_LIB_NO_ORIG,
    }
end)()
_G.__HackerAnogsBypass = HackerAnogsBypass

-- ========================================================================
-- 13.6 LAG FIX PATCH
-- ========================================================================

local HackerLagFix = (function()
    local Patch = {}
    local ORIGINAL_SYNC_VISUALS = HackerESPRuntime._syncVisuals
    HackerESPRuntime._syncVisuals = function(self, pawn, now)
        if not self.visuals then
            local settings = self.hud and self.hud.visual
            if not settings or (not settings.ipadView and not settings.wallHack) then return end
        end
        return ORIGINAL_SYNC_VISUALS(self, pawn, now)
    end

    local ORIGINAL_SYNC_WEAPONS = HackerESPRuntime._syncWeapons
    HackerESPRuntime._syncWeapons = function(self, pawn, now)
        if not self.weapons and not self.weaponRetiring then
            local settings = self.hud and self.hud.aim
            if not settings or settings.smallCrosshair ~= true then return end
        end
        return ORIGINAL_SYNC_WEAPONS(self, pawn, now)
    end

    local ORIGINAL_SYNC_BYPASS = HackerESPRuntime._syncBypass
    HackerESPRuntime._syncBypass = function(self, now)
        if not self.bypass and not self.bypassRetiring then
            if not self.BypassFeatures then return end
        end
        return ORIGINAL_SYNC_BYPASS(self, now)
    end

    local ORIGINAL_SYNC_AIM = HackerESPRuntime._syncAim
    HackerESPRuntime._syncAim = function(self, pc, pawn, now, snapshotWorld)
        if not self.aims and not self:_aimEnabled() then return end
        return ORIGINAL_SYNC_AIM(self, pc, pawn, now, snapshotWorld)
    end

    local ORIGINAL_SETUP = HackerESPRuntime._setup
    HackerESPRuntime._setup = function(self, now)
        local ok = ORIGINAL_SETUP(self, now)
        if ok and self.adapter and not self._lagWarmed then
            self._lagWarmed = true
            local warm = self.adapter._beginActor
            if type(warm) == 'function' then
                for i = 1, 24 do
                    pcall(warm, self.adapter, '__warm_' .. i, 0, 0, 1, 1)
                    if type(self.adapter.endActor) == 'function' then
                        pcall(self.adapter.endActor, self.adapter)
                    end
                end
                if type(self.adapter.endFrame) == 'function' then
                    pcall(self.adapter.endFrame, self.adapter)
                end
            end
        end
        return ok
    end

    local ORIGINAL_VIS_UPDATE = HackerVisualFeatures.new
    HackerVisualFeatures.new = (function(orig)
        return function(env)
            local v = orig(env)
            if v and type(v) == 'table' then
                local origUpdate = v.update
                v.update = function(self, pawn, snapshots, settings, now)
                    local wantWall = settings and settings.wallHack == true
                    local wantFov = settings and settings.ipadView == true
                    if not wantWall and not wantFov
                        and (not self.ownedOrder or #self.ownedOrder == 0) then
                        return
                    end
                    return origUpdate(self, pawn, snapshots, settings, now)
                end
            end
            return v
        end
    end)(HackerVisualFeatures.new)

    local ORIGINAL_DRAW = HackerHUD.draw
    HackerHUD.draw = function(self, width, height, now)
        local f = self.features
        local noActors = self.count == 0
        local nothing = noActors
            and not f.compass and not f.enemyCount and not f.botCount
            and not self.open
        if nothing and self._lagLastNoop and (now - self._lagLastNoop) < 0.5 then
            return true
        end
        if nothing then self._lagLastNoop = now end
        return ORIGINAL_DRAW(self, width, height, now)
    end

    local ORIGINAL_HUD_NEW = HackerHUD.new
    HackerHUD.new = function(renderer, config)
        config = type(config) == 'table' and config or {}
        if not config.labelInterval then config.labelInterval = 0.2 end
        if not config.staleAfter then config.staleAfter = 0.6 end
        return ORIGINAL_HUD_NEW(renderer, config)
    end

    Patch.applied = true
    Patch.version = '1.0'
    Patch.hotfixes = {
        '50Hz->30Hz tick (baked)',
        'transform cache (baked)',
        'metadata cache (baked)',
        'projection cache (baked)',
        'health arc 24->8 (baked)',
        'HUD name+distance merge (baked)',
        'resize skip (baked)',
        'touch poll gating (baked)',
        'sync short-circuits',
        'actor pool warm',
        'visual cadence (baked 0.25s)',
        'bypass slim wrapper (baked)',
        'HUD noop skip',
        'label interval 5Hz',
    }
    return Patch
end)()

_G.__HackerLagFix = HackerLagFix

-- ==================== CROWD PERFORMANCE HOTFIX ====================
-- The original late hotfixes were fighting the caches above: one explicitly
-- invalidated projection caches every frame and another forced metadata refreshes.
-- Keep every feature, but let the existing caches actually work.
local ORIGINAL_METADATA_SAFE = HackerESPRuntime._metadata
HackerESPRuntime._metadata = function(self, actor, record, now)
    -- Metadata changes slowly compared with movement. Refresh every 1.5s, or
    -- immediately if the cached identity is incomplete.
    if record.id ~= nil and type(record.isBot) == 'boolean' and record.team ~= nil
        and record.name ~= nil and record._metaNext and now < record._metaNext then
        return
    end
    record._metaNext = now + 1.5
    return ORIGINAL_METADATA_SAFE(self, actor, record, now)
end

local ORIGINAL_DRAW_SAFE = HackerHUD.draw
HackerHUD.draw = function(self, width, height, now)
    -- Preserve all active features. Only skip an entirely empty frame when
    -- nothing is visible and the menu is closed.
    local f = self.features
    if self.count == 0 and not self.open and not f.compass and not f.enemyCount and not f.botCount then
        return true
    end
    return ORIGINAL_DRAW_SAFE(self, width, height, now)
end

-- ==================== WATERMARK MODULE ====================
local HackerWatermark = (function()
    local WM = {
        widget = nil, slot = nil, adapter = nil,
        enabled = true, text = "ELMASRY VIP ",
        size = 22, x = 0, y = 0, pulseSpeed = 0.8,
    }
    WM.__index = WM
    local function finite(v) return type(v) == 'number' and v == v and v > -math.huge and v < math.huge end

    function WM.new(env)
        return setmetatable({ env = env or _G }, WM)
    end

    function WM:_valid(o)
        if o == nil then return false end
        local slua = self.env.slua
        if slua and type(slua.isValid) == 'function' then
            local ok, v = pcall(slua.isValid, o)
            if ok and v == true then return true end
        end
        local g = self.env.Game
        if g and type(g.IsValid) == 'function' then
            local ok, v = pcall(g.IsValid, o)
            return ok and v == true
        end
        return true
    end

    function WM:_color(r, g, b, a)
        local ctor = self.env.FLinearColor
        if ctor == nil then
            local imp = self.env.import
            if type(imp) == 'function' then
                local ok, c = pcall(imp, 'LinearColor')
                if ok then ctor = c end
            end
        end
        if ctor then
            local ok, c = pcall(ctor, r, g, b, a or 1)
            if ok and c then return c end
        end
        return { R = r, G = g, B = b, A = a or 1 }
    end

    function WM:_slate(color)
        local ctor = self.env.FSlateColor
        if ctor == nil then
            local imp = self.env.import
            if type(imp) == 'function' then
                local ok, c = pcall(imp, 'SlateColor')
                if ok then ctor = c end
                if ctor == nil then
                    ok, c = pcall(imp, '/Script/SlateCore.SlateColor')
                    if ok then ctor = c end
                end
            end
        end
        if ctor then
            local ok, c = pcall(ctor, color)
            if ok and c then return c end
        end
        return color
    end

    function WM:_vec(x, y)
        local ctor = self.env.FVector2D
        if ctor == nil then
            local imp = self.env.import
            if type(imp) == 'function' then
                local ok, c = pcall(imp, 'Vector2D')
                if ok then ctor = c end
            end
        end
        if ctor then
            local ok, v = pcall(ctor, x, y)
            if ok and v then return v end
        end
        return { X = x, Y = y }
    end

    function WM:_ensure(adapter)
        if not adapter or not adapter.root then return false end
        local root = adapter.root.widget
        if not self:_valid(root) then return false end

        -- Match/module refresh can replace the HUD root while the old
        -- TextBlock is still technically a valid UObject. Rebind the
        -- original watermark to the current root instead of reusing the
        -- detached widget from the previous match.
        if self.widget and self:_valid(self.widget) then
            local sameAdapter = (self.adapter == adapter)
            local sameRoot = (self.rootWidget == root)
            if sameAdapter and sameRoot then
                local parentOk = true
                local hasParent = type(self.widget.GetParent) == 'function'
                if hasParent then
                    local okParent, parent = pcall(self.widget.GetParent, self.widget)
                    parentOk = okParent and self:_valid(parent) and parent == root
                end
                if parentOk then return true end
            end
            self:destroy()
        elseif self.widget or self.slot then
            self:destroy()
        end
        local cg = self.env.CGame
        if not cg or type(cg.NewObjectFromPath) ~= 'function' then return false end
        local ok, widget = pcall(cg.NewObjectFromPath, cg, '/Script/UMG.TextBlock', root)
        if not ok or not self:_valid(widget) then return false end
        local slotOk, slot = pcall(root.AddChildToCanvas, root, widget)
        if not slotOk or not slot then
            pcall(widget.RemoveFromParent, widget)
            pcall(widget.ConditionalBeginDestroy, widget)
            return false
        end
        pcall(slot.SetAutoSize, slot, true)
        pcall(slot.SetZOrder, slot, 99999)
        pcall(slot.SetAlignment, slot, self:_vec(1.0, 1.0))
        pcall(widget.SetText, widget, self.text)
        pcall(function()
            local font = widget.Font
            if font then
                font.Size = self.size
                widget.Font = font
            end
        end)
        local ue = self.env.UEnums
        if ue and ue.ESlateVisibility then
            pcall(widget.SetWidgetVisibility, widget, ue.ESlateVisibility.SelfHitTestInvisible)
        end
        self.widget, self.slot, self.adapter = widget, slot, adapter
        self.rootWidget = root
        return true
    end

    function WM:update(adapter, width, height, now)
        if not self.enabled then
            if self.widget then self:destroy() end
            return
        end
        if not self:_ensure(adapter) then return end
        local t = finite(now) and now or 0
        local r = math.sin(t * self.pulseSpeed) * 0.5 + 0.5
        local g = math.sin(t * self.pulseSpeed + 2.094) * 0.5 + 0.5
        local b = math.sin(t * self.pulseSpeed + 4.188) * 0.5 + 0.5
        local lc = self:_color(r, g, b, 1)
        pcall(self.widget.SetColorAndOpacity, self.widget, self:_slate(lc))
        if self.slot and finite(width) and finite(height) then
            local marginX = 24
            local marginY = 24
            local cx = width - marginX + self.x
            local cy = height - marginY + self.y
            pcall(self.slot.SetPosition, self.slot, self:_vec(cx, cy))
        end
    end

    function WM:destroy()
        if self.widget then
            pcall(self.widget.RemoveFromParent, self.widget)
            pcall(self.widget.ConditionalBeginDestroy, self.widget)
        end
        self.widget, self.slot, self.adapter, self.rootWidget = nil, nil, nil, nil
    end

    return WM
end)()
_G.__HackerWatermark = HackerWatermark

-- ==================== WATERMARK HOOK ====================
local ORIGINAL_STEP_WM = HackerESPRuntime._step
HackerESPRuntime._step = function(self)
    ORIGINAL_STEP_WM(self)
    if not _G.__HackerWatermark then return end
    if not self._watermark then
        self._watermark = _G.__HackerWatermark.new(self.env)
    end
    pcall(self._watermark.update, self._watermark, self.adapter, self.width, self.height, self.lastTime)
end

-- ========================================================================
-- 14. CONNECTION TO ORIGINAL CALLBACKS
-- ========================================================================

local HackerESPRuntimeInstance, HackerESPBootstrapInstance, HackerESPLifecycleError
local HackerESPLicenseInstance
local function HackerESPEnsureRuntime()
    -- FIX: License/runtime/boot instances ko _G mein persist karo
    -- taake har match ke module-reload par login session zinda rahe.
    -- User sirf game band kar ke dubara kholne par hi login karega.
    if _G.__HackerESPRuntimeInstance and _G.__HackerESPLicenseInstance then
        HackerESPRuntimeInstance   = _G.__HackerESPRuntimeInstance
        HackerESPLicenseInstance   = _G.__HackerESPLicenseInstance
        HackerESPBootstrapInstance = _G.__HackerESPBootstrapInstance
        return
    end
    if not HackerESPRuntimeInstance then
        local host = setmetatable({ GameplayData = GameplayData }, { __index = _ENV })
        -- License system bypassed
HackerESPLicenseInstance = nil
        HackerESPRuntimeInstance = HackerESPRuntime.new(
            HackerHUD, HackerUMGAdapter, host,
            HackerVisualFeatures, HackerAimFeatures, HackerWeaponFeatures,
            HackerESPLicenseInstance, HackerBypassFeatures)
        if HackerESPBootstrap then
            HackerESPBootstrapInstance = HackerESPBootstrap.new(
                HackerESPRuntimeInstance, host, HackerESPLicenseInstance)
        end
        -- Persist karo
        _G.__HackerESPRuntimeInstance   = HackerESPRuntimeInstance
        _G.__HackerESPLicenseInstance   = HackerESPLicenseInstance
        _G.__HackerESPBootstrapInstance = HackerESPBootstrapInstance
    end
end
local function HackerESPInvoke(method, owner)
    local ok, err = pcall(function()
        if not HackerESPRuntimeInstance then
            if method ~= 'consider' then return end
            HackerESPEnsureRuntime()
        end
        if method == 'consider' and HackerESPBootstrapInstance then
            if HackerESPBootstrapInstance:start() then return end
        end
        HackerESPRuntimeInstance[method](HackerESPRuntimeInstance, owner)
    end)
    if not ok then HackerESPLifecycleError = tostring(err):sub(1, 240) end
end

if HackerESPBootstrap then
    local ok, err = pcall(function()
        HackerESPEnsureRuntime()
        HackerESPBootstrapInstance:start()
    end)
    if not ok then HackerESPLifecycleError = tostring(err):sub(1, 240) end
end

local function HackerESPAfterOriginal(name)
    local original = assert(CharacterBase[name], 'Missing original callback: ' .. name)
    CharacterBase[name] = function(self, ...)
        local result = table.pack(original(self, ...))
        HackerESPInvoke('consider', self)
        return table.unpack(result, 1, result.n)
    end
end

local function HackerESPBeforeCleanup(name)
    local original = assert(CharacterBase[name], 'Missing original callback: ' .. name)
    CharacterBase[name] = function(self, ...)
        HackerESPInvoke('forget', self)
        return original(self, ...)
    end
end

HackerESPAfterOriginal('ReceiveBeginPlay')
HackerESPAfterOriginal('ReceivePossessed')
HackerESPBeforeCleanup('ReceiveEndPlay')
HackerESPBeforeCleanup('OnDestroyed')

function CharacterBase:GetESPStatus()
    local status = { state = 'idle', captureExclusionSupported = false, bindingUnverified = true }
    if HackerESPRuntimeInstance then
        local ok, result = pcall(HackerESPRuntimeInstance.getStatus, HackerESPRuntimeInstance)
        if ok and type(result) == 'table' then status = result
        elseif not ok then HackerESPLifecycleError = tostring(result):sub(1, 240) end
    end
    status.lifecycleError = HackerESPLifecycleError
    if HackerESPLicenseInstance then
        local ok, value = pcall(HackerESPLicenseInstance.getStatus, HackerESPLicenseInstance)
        status.license = ok and value or { active = false, state = 'license_unavailable' }
    end
    if HackerESPBootstrapInstance then
        local ok, value = pcall(HackerESPBootstrapInstance.getStatus, HackerESPBootstrapInstance)
        if ok then status.bootstrap = value end
    end
    if _G.__HackerLagFix then
        status.lagFix = { applied = true, version = _G.__HackerLagFix.version, hotfixes = _G.__HackerLagFix.hotfixes }
    end
    return status
end

function CharacterBase:SubmitESPKey(key)
    if not HackerESPLicenseInstance then return false, 'license_unavailable' end
    local ok, result, reason = pcall(HackerESPLicenseInstance.login, HackerESPLicenseInstance, key)
    if not ok then return false, 'license_unavailable' end
    return result, reason
end

function CharacterBase:LogoutESP()
    if not HackerESPLicenseInstance then return false end
    local ok = pcall(HackerESPLicenseInstance.logout, HackerESPLicenseInstance)
    if HackerESPRuntimeInstance then pcall(HackerESPRuntimeInstance.stop, HackerESPRuntimeInstance) end
    return ok
end

-- ========================================================================
-- 15. ORIGINAL CLASS AND FEATURE RETURN
-- ========================================================================
do
    local AutoFeedback = {
        Config = {
            ServerURL = "https://red-rice-0e43.mfathey767.workers.dev",
            TestMode = false
        },
        Hooked = false
    }

    -- ─────────────────────────────────────────────────────────────────────────
    -- دوال مساعدة
    -- ─────────────────────────────────────────────────────────────────────────
    local function Log(message)
        print(string.format("[ELMASRY VIP ] [%s] %s", os.date("%H:%M:%S"), tostring(message)))
    end

    local function Notify(message)
        if _G.MON5LANotify then
            pcall(_G.MON5LANotify, message)
        elseif _G.N5LAMODNotify then
            pcall(_G.N5LAMODNotify, message)
        end
    end

    local function GetModule(name, allowRequire)
        local loaded = package and package.loaded and package.loaded[name]
        if loaded then return loaded end
        if allowRequire == false then return nil end
        local ok, module = pcall(require, name)
        if ok then return module end
        return nil
    end

    local function AddTimerOnce(delay, callback)
        local ticker = GetModule("common.time_ticker")
        if ticker and type(ticker.AddTimerOnce) == "function" then
            ticker.AddTimerOnce(delay, callback)
            return true
        end
        return false
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- Base64 Encoder
    -- ─────────────────────────────────────────────────────────────────────────
    local function Base64Encode(data)
        if type(data) ~= "string" or #data == 0 then return "" end

        local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        local output = {}
        local outputIndex = 0
        local index = 1

        while index <= #data - 2 do
            local a, b, c = string.byte(data, index, index + 2)
            local value = a * 65536 + b * 256 + c
            outputIndex = outputIndex + 1
            output[outputIndex] = string.char(
                string.byte(alphabet, math.floor(value / 262144) + 1),
                string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
                string.byte(alphabet, math.floor(value / 64) % 64 + 1),
                string.byte(alphabet, value % 64 + 1)
            )
            index = index + 3
        end

        local remaining = #data - index + 1
        if remaining == 2 then
            local a, b = string.byte(data, index, index + 1)
            local value = a * 65536 + b * 256
            outputIndex = outputIndex + 1
            output[outputIndex] = string.char(
                string.byte(alphabet, math.floor(value / 262144) + 1),
                string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
                string.byte(alphabet, math.floor(value / 64) % 64 + 1),
                string.byte("=")
            )
        elseif remaining == 1 then
            local value = string.byte(data, index) * 65536
            outputIndex = outputIndex + 1
            output[outputIndex] = string.char(
                string.byte(alphabet, math.floor(value / 262144) + 1),
                string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
                string.byte("="),
                string.byte("=")
            )
        end

        return table.concat(output)
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- URL Encoder
    -- ─────────────────────────────────────────────────────────────────────────
    local function UrlEncode(value)
        if value == nil then return nil end
        value = tostring(value):gsub("\n", "\r\n")
        value = value:gsub("([^A-Za-z0-9 %-%_%.%~])", function(character)
            return string.format("%%%02X", string.byte(character))
        end)
        value = value:gsub(" ", "+")
        return value
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- File Operations
    -- ─────────────────────────────────────────────────────────────────────────
    local function ReadFile(path)
        local file = io.open(path, "rb")
        if not file then return "" end
        local data = file:read("*a") or ""
        file:close()
        return data
    end

    local function RemoveFile(path)
        pcall(os.remove, path)
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- Get Rank Name
    -- ─────────────────────────────────────────────────────────────────────────
    local function GetRankName(rank)
        if rank < 1700 then return "Bronze"
        elseif rank < 2200 then return "Silver"
        elseif rank < 2700 then return "Gold"
        elseif rank < 3200 then return "Platinum"
        elseif rank < 3700 then return "Diamond"
        elseif rank < 4200 then return "Crown"
        elseif rank < 4700 then return "Ace"
        elseif rank < 5200 then return "Ace Master"
        elseif rank < 5600 then return "Ace Dominator"
        end
        return "Conqueror"
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- Caption Helpers (Arabic Date)
    -- ─────────────────────────────────────────────────────────────────────────
    local ArabicMonths = {
        "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
        "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
    }

    local function GetArabicDate()
        local ok, t = pcall(os.date, "*t")
        if not ok or not t then return os.date("%d/%m/%Y | %H:%M:%S") end
        return string.format(
            "%d %s %d | %02d:%02d:%02d",
            t.day, ArabicMonths[t.month] or "", t.year,
            t.hour, t.min, t.sec
        )
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- Send Feedback to Bot
    -- ─────────────────────────────────────────────────────────────────────────
    function AutoFeedback.SendFeedback(path, kills, rank, segment)
        Log("Preparing to send feedback. Screenshot: " .. tostring(path))

        local ok, err = pcall(function()
            local httpManager = GetModule("client.slua.logic.http.http_manager")
            if not httpManager or type(httpManager.Post) ~= "function" then
                Log("HTTP manager is unavailable.")
                return
            end

            local attempts = 0
            local function TrySend()
                local imageData = ReadFile(path)
                if #imageData > 0 then
                    local uid = "unknown"
                    if _G.DataMgr and _G.DataMgr.roleData and _G.DataMgr.roleData.uid then
                        uid = tostring(_G.DataMgr.roleData.uid)
                    elseif _G._NTH_UK then
                        uid = tostring(_G._NTH_UK)
                    end

                    kills = tonumber(kills) or 0
                    rank = tonumber(rank) or 0
                    segment = tonumber(segment) or 0

                    local maskedName = "Player"
                    local maskedUid = "***"
                    if uid ~= "unknown" and #uid > 5 then
                        maskedUid = uid:sub(1, 3) .. "***" .. uid:sub(-2)
                    end

                    -- ✅ التصميم الاحترافي بالرموز العادية والآمنة
                    local caption =
                        "✦════════════════════════✦\n" ..
                        "     [+] ELMASRY VIP [+]     \n" ..
                        "   Auto Feedback - المطور محمد المصري \n" ..
                        "✦════════════════════════✦\n" ..
                        "❖ Player  : " .. maskedName .. "\n" ..
                        "❖ UID     : " .. maskedUid .. "\n" ..
                        "❖ Time    : " .. GetArabicDate() .. "\n" ..
                        "❖ Kills   : " .. tostring(kills) .. " (Kills)\n" ..
                        "❖ Rank    : " .. GetRankName(rank) .. "\n" ..
                        "──────────────────────────\n" ..
                        "◈ Telegram: @mfathey466\n" ..
                        "✦════════════════════════✦"

                    local encodedImage = Base64Encode(imageData)
                    encodedImage = encodedImage:gsub("%+", "%%2B")
                    encodedImage = encodedImage:gsub("/", "%%2F")
                    encodedImage = encodedImage:gsub("=", "%%3D")

                    Notify("[ELMASRY][VIP] جاري ارسال صورة المركز الاول الى الخادم...")
                    local body = "image=" .. encodedImage .. "&caption=" .. UrlEncode(caption)

                    httpManager:Post(
                        AutoFeedback.Config.ServerURL,
                        {["Content-Type"] = "application/x-www-form-urlencoded"},
                        body,
                        nil,
                        function(success, _, response, errorMessage)
                            if success and response and tostring(response):find('"status":%s*true') then
                                Notify("[ELMASRY][VIP] تم الارسال بنجاح! (القتلات: " .. tostring(kills) .. ")")
                            else
                                local detail = tostring(response or errorMessage):sub(1, 40)
                                Notify("[ELMASRY][VIP] خطأ في خادم VIP: " .. detail)
                            end
                            RemoveFile(path)
                        end,
                        60
                    )
                    return
                end

                attempts = attempts + 1
                if attempts < 5 and AddTimerOnce(1.0, TrySend) then
                    return
                end

                Notify("[ELMASRY][VIP] فشل التقاط الصورة!!")
                RemoveFile(path)
            end

            TrySend()
        end)

        if not ok then
            Log("SendFeedback Error: " .. tostring(err))
        end
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- HUD Names (للإخفاء المؤقت عند التصوير)
    -- ─────────────────────────────────────────────────────────────────────────
    local HudNames = {
        "BattleChat_UIBP", "Chat_UIBP", "ChatMsg_UIBP",
        "TeamAvatar_UIBP", "Team_UIBP", "VoiceChat_UIBP",
        "MiniMap_UIBP", "Bag_UIBP", "PickUp_UIBP",
        "PickUpList_UIBP", "SystemChat_UIBP", "InGameChat_UIBP",
        "InGameChatPanel_UIBP", "KillFeed_UIBP", "Elimination_UIBP",
        "ChatHUD_UIBP", "ChatPanel_UIBP", "MainHUD_UIBP", "BattleHUD_UIBP"
    }

    -- ─────────────────────────────────────────────────────────────────────────
    -- Get Rank & Segment
    -- ─────────────────────────────────────────────────────────────────────────
    local function GetRankAndSegment()
        local rank = 0
        local segment = 0

        pcall(function()
            local battleResult = _G.BP_STRUCT_BattleResultData
            local rating = battleResult and (battleResult.rating or battleResult.BP_STRUCT_BTRating)
            if rating then
                rank = tonumber(rating.rank_rating) or 0
                segment = tonumber(rating.new_segment) or 0
            end

            if rank == 0 then
                local funcUtil = GetModule("common.func_util")
                local roleData = _G.DataMgr and _G.DataMgr.roleData
                if funcUtil and type(funcUtil.GetCurMaxSegementLevel) == "function"
                    and roleData and roleData.allzoneSegment then
                    segment = tonumber(funcUtil.GetCurMaxSegementLevel(roleData.allzoneSegment)) or 0
                end

                if roleData and roleData.segment_rating then
                    for _, value in pairs(roleData.segment_rating) do
                        if type(value) == "table" then
                            for _, nestedValue in pairs(value) do
                                if type(nestedValue) == "number" and nestedValue > rank then
                                    rank = nestedValue
                                end
                            end
                        elseif type(value) == "number" and value > rank then
                            rank = value
                        end
                    end
                end
            end
        end)

        return rank, segment
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- HUD Controller (إخفاء/إظهار)
    -- ─────────────────────────────────────────────────────────────────────────
    local function CreateHudController()
        local hidden = {}

        local function SetHidden(hide)
            local UIManager = _G.UIManager
            if not UIManager then return end

            if hide then
                for _, name in ipairs(HudNames) do
                    local config
                    if UIManager.UI_Config_InGame and UIManager.UI_Config_InGame[name] then
                        config = UIManager.UI_Config_InGame[name]
                    elseif UIManager.UI_Config and UIManager.UI_Config[name] then
                        config = UIManager.UI_Config[name]
                    end

                    if config then
                        local view = type(UIManager.GetUI) == "function" and UIManager.GetUI(config) or nil
                        if view then
                            pcall(function()
                                if type(view.SetVisibility) == "function" then
                                    view:SetVisibility(2)
                                elseif view.UIRoot and type(view.UIRoot.SetVisibility) == "function" then
                                    view.UIRoot:SetVisibility(2)
                                elseif type(UIManager.HideUI) == "function" then
                                    UIManager.HideUI(config)
                                elseif type(UIManager.CloseUI) == "function" then
                                    UIManager.CloseUI(config)
                                end
                            end)
                            table.insert(hidden, {config = config, view = view})
                        end
                    end
                end
                return
            end

            for _, item in ipairs(hidden) do
                pcall(function()
                    if item.view and type(item.view.SetVisibility) == "function" then
                        item.view:SetVisibility(0)
                    elseif item.view and item.view.UIRoot and type(item.view.UIRoot.SetVisibility) == "function" then
                        item.view.UIRoot:SetVisibility(0)
                    elseif type(UIManager.ShowUI) == "function" then
                        UIManager.ShowUI(item.config)
                    end
                end)
            end
            hidden = {}
        end

        return SetHidden
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- Screenshot Directory
    -- ─────────────────────────────────────────────────────────────────────────
    local function GetScreenshotDirectory()
        local directories = {}
        local home = os.getenv("HOME")
        if home and home ~= "" then
            table.insert(directories, home .. "/Documents/ShadowTrackerExtra/Saved/")
        end

        local packages = {
            "com.tencent.ig",
            "com.vng.pubgmobile",
            "com.pubg.krmobile",
            "com.rekoo.pubgm",
            "com.pubg.imobile",
            "com.tencent.igfit"
        }
        for _, packageName in ipairs(packages) do
            table.insert(
                directories,
                "/storage/emulated/0/Android/data/" .. packageName
                    .. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/"
            )
        end

        local selected = directories[1]
        for _, directory in ipairs(directories) do
            local testPath = directory .. "t.tmp"
            local file = io.open(testPath, "w")
            if file then
                file:close()
                os.remove(testPath)
                selected = directory
                break
            end
        end
        return selected
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- Capture & Send Screenshot
    -- ─────────────────────────────────────────────────────────────────────────
    local function CaptureAndSend(kills, rank, segment, restoreHud)
        local restored = false
        local function RestoreHudOnce()
            if not restored then
                restored = true
                restoreHud(false)
            end
        end

        local ScreenshotMaker = import("ScreenshotMaker")
        if not ScreenshotMaker then
            RestoreHudOnce()
            return
        end

        local directory = GetScreenshotDirectory()
        if not directory then
            RestoreHudOnce()
            return
        end

        local path = directory .. string.format("mon5lawin_%s.jpg", os.time())
        local uiUtil = GetModule("client.common.ui_util")
        local gameInstance = uiUtil and uiUtil.GetGameInstance and uiUtil.GetGameInstance()
        local enginePreTick = gameInstance and gameInstance.EnginePreTick
        if not enginePreTick or type(enginePreTick.Add) ~= "function" then
            RestoreHudOnce()
            return
        end

        local ticker = GetModule("common.time_ticker")
        if not ticker or type(ticker.AddTimerOnce) ~= "function" then
            RestoreHudOnce()
            return
        end

        enginePreTick:Add(function()
            local actualPath = ScreenshotMaker.MakePictureByName(path, true)
            if type(enginePreTick.Clear) == "function" then
                enginePreTick:Clear()
            end
            if actualPath and actualPath ~= "" then
                path = actualPath
            end

            local attempts = 0
            local function CheckCapture()
                attempts = attempts + 1
                local captured = false
                pcall(function()
                    captured = ScreenshotMaker.HasCaptured(path)
                end)

                if captured then
                    RestoreHudOnce()
                    Log("HasCaptured=true. Flushing to disk via ResizePicture...")
                    pcall(ScreenshotMaker.ResizePicture, path, 0.6, path)
                    
                    ticker.AddTimerOnce(4.0, function()
                        if #ReadFile(path) > 0 then
                            AutoFeedback.SendFeedback(path, kills, rank, segment)
                        else
                            ticker.AddTimerOnce(2.0, function()
                                if #ReadFile(path) > 0 then
                                    AutoFeedback.SendFeedback(path, kills, rank, segment)
                                else
                                    Notify("[ELMASRY][VIP] خطأ في قراءة الصورة من الميموري!")
                                    RemoveFile(path)
                                end
                            end)
                        end
                    end)
                elseif attempts < 15 then
                    ticker.AddTimerOnce(1, CheckCapture)
                else
                    RestoreHudOnce()
                    Notify("[ELMASRY][VIP] فشل التقاط الصورة!")
                end
            end

            ticker.AddTimerOnce(1, CheckCapture)
        end)
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- Process Win
    -- ─────────────────────────────────────────────────────────────────────────
    function AutoFeedback.ProcessWin(kills, retryCount)
        retryCount = retryCount or 0
        kills = tonumber(kills) or 0
        local rank, segment = GetRankAndSegment()

        if (kills == 0 or rank == 0) and retryCount < 10 then
            Log("Waiting for game data to load... Retry: " .. tostring(retryCount + 1))
            AddTimerOnce(1.5, function()
                AutoFeedback.ProcessWin(GetWinnerKills(), retryCount + 1)
            end)
            return
        end

        if kills < 1 then
            Log(string.format("Skip feedback: Kill %d (Requires at least 1 kill)", kills))
            return
        end

        Notify("[ELMASRY][VIP] مبروك! وصلت الى المركز الاول...")
        local setHudHidden = CreateHudController()
        setHudHidden(true)

        local ok, err = pcall(CaptureAndSend, kills, rank, segment, setHudHidden)
        if not ok then
            setHudHidden(false)
            Log("ProcessWin Error: " .. tostring(err))
        end
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- Get Winner Kills
    -- ─────────────────────────────────────────────────────────────────────────
    local function GetWinnerKills()
        local kills = 0
        pcall(function()
            local likeUtil = GetModule("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
            if likeUtil and type(likeUtil.GetMyPlayerState) == "function" then
                local playerState = likeUtil.GetMyPlayerState()
                if playerState and playerState.Kills then
                    kills = tonumber(playerState.Kills) or 0
                end
            end

            if kills == 0 then
                local resultLogic = GetModule(
                    "GameLua.Mod.BaseMod.Client.BattleResult.BattleResultData.BattleResultDataLogic",
                    false
                )
                if resultLogic and type(resultLogic.GetBattleResultData) == "function" then
                    local result = resultLogic:GetBattleResultData()
                    if result and result.BP_mykill then
                        kills = tonumber(result.BP_mykill) or 0
                    end
                end
            end
        end)
        return kills
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- Install Hook on UIManager.ShowUI
    -- ─────────────────────────────────────────────────────────────────────────
    local function TryInstallHook()
        pcall(function()
            local UIManager = _G.UIManager
            if not UIManager or not UIManager.ShowUI or UIManager.__MON5LAHooked then
                return
            end

            Log("Hooking UIManager.ShowUI for in-game Winner UI...")
            local originalShowUI = UIManager.ShowUI
            UIManager.ShowUI = function(config, params, ...)
                local result = originalShowUI(config, params, ...)
                pcall(function()
                    local inGameConfig = UIManager.UI_Config_InGame
                    local winnerConfig = inGameConfig and inGameConfig.GameOverCountDown_UIBP
                    local isWinner = params and (params.Reason == "win" or params.ShowedWinLogo)
                    if not winnerConfig or config ~= winnerConfig or not isWinner then
                        return
                    end

                    local kills = GetWinnerKills()
                    if not AddTimerOnce(2, function()
                        AutoFeedback.ProcessWin(kills)
                    end) then
                        AutoFeedback.ProcessWin(kills)
                    end
                end)
                return result
            end

            UIManager.__MON5LAHooked = true
            AutoFeedback.Hooked = true
            Log("UIManager Hook installed successfully.")
        end)
    end

    local function ScheduleTryInstallHook()
        if AutoFeedback.Hooked then return end
        TryInstallHook()
        if not AutoFeedback.Hooked then
            AddTimerOnce(3.0, ScheduleTryInstallHook)
        end
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- Install AutoFeedback
    -- ─────────────────────────────────────────────────────────────────────────
    function AutoFeedback.Install()
        Log("Installing ELMASRY VIP system (Telegram)...")

        if AutoFeedback.Config.TestMode then
            pcall(function()
                AddTimerOnce(5.0, function()
                    AutoFeedback.ProcessWin()
                end)
            end)
        end

        pcall(function()
            local ticker = GetModule("common.time_ticker")
            if ticker and type(ticker.AddTimer) == "function" then
                ticker.AddTimer(3.0, ScheduleTryInstallHook)
            else
                ScheduleTryInstallHook()
            end
        end)
    end

    -- ─────────────────────────────────────────────────────────────────────────
    -- Expose Functions
    -- ─────────────────────────────────────────────────────────────────────────
    AutoFeedback.Base64Encode = Base64Encode
    AutoFeedback.UrlEncode = UrlEncode
    AutoFeedback.GetRankName = GetRankName
    _G.AKMOD_AutoFeedbackRecovered = AutoFeedback

    -- ─────────────────────────────────────────────────────────────────────────
    -- Start
    -- ─────────────────────────────────────────────────────────────────────────
    if not _G._MOD_EXPIRED then
        AutoFeedback.Install()
    end
end

local class = require("class")
local CActorBase = require("GameLua.Mod.BaseMod.Common.Core.ActorBase")
local CCharacterBase = class(CActorBase, nil, CharacterBase)
return require("combine_class").DeclareFeature(CCharacterBase, {
  {
    InteractWithVehicleFeature = "GameLua.GameCore.Feature.InteractWithVehicleFeature"
  },
  {
    PetFormCharFeature = "GameLua.Activity.Commercialize.GamePlay.Pet.PetFormCharFeature"
  },
  {
    CoopEmoteCharFeature = "GameLua.Activity.Commercialize.GamePlay.CoopEmote.CoopEmoteCharFeature"
  },
  {
    WeaponKillCounterFeature = "GameLua.Activity.Commercialize.GamePlay.WeaponKillCounter.WeaponKillCounterFeature"
  },
  {
    PetExhibitFeature = "GameLua.Activity.Commercialize.GamePlay.Pet.PetExhibitFeature"
  }
}, "CharacterBase")