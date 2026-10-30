local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}

-- ============================================================================
-- MERGED BYPASS v3.0
-- ============================================================================
BRPlayerCharacterBase.ServerRPC.RPC_Server_ReportSimulateCharacterLocation = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ClientRPC.RPC_Client_ShootVertifyRes = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ClientRPC.RPC_ClientCoronaLab = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ReportPlayerKillFlow = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ClientSecMrpcsFlow = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_Heartbeat = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_SwiftHawk = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.RPC_Server_ClientSwiftHawkWithParams = { Reliable = true, Params = {} }
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
    self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
    self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(uVehicle)
  if not slua.isValid(uVehicle) then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:HandleOnAttachedToVehicle", Game:GetObjName(uVehicle)))
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
    self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:UpdatePlayerAttachToVehicle(uVehicle)
      end
    end)
    self.nFixMeshContainerTimer = self:AddGameTimer(3, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:FixMeshContainerOffsetIfNeeded(uVehicle)
      end
    end)
  end
end

function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
  if not slua.isValid(uLastVehicle) then
    return
  end
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnDetachedFromVehicle", uLastVehicle)
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.CapsuleComponent) or not slua.isValid(self.Mesh) or not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  if not self.nUpdatePlayerAttachToVehicleCount then
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  local ESTEPoseState = import("ESTEPoseState")
  local bStand = self.PoseState == ESTEPoseState.Stand
  local uActorRelativeLocation = self.CapsuleComponent:GetRelativeTransform():GetLocation()
  local uMeshRelativeLocation = self.Mesh:GetRelativeTransform():GetLocation()
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  local nCapsuleRadius = self.CapsuleComponent:GetScaledCapsuleRadius()
  local nCapsuleHalfHeight = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local nExpectedCapsuleRadius = self.StandRadius
  local nExpectedCapsuleHalfHeight = self.StandHalfHeight
  local uMeshExpectedRL = FVector(0, 0, 0)
  local uActorExpectedRL = FVector(0, 0, self.StandHalfHeight)
  local nTolerance = 1.0
  local bCapsuleRLCorrect = uActorRelativeLocation:Equals(uActorExpectedRL, nTolerance)
  local bMeshRLCorrect = uMeshRelativeLocation:Equals(uMeshExpectedRL, nTolerance)
  local bMeshContainerRLCorrect = nTolerance > math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ)
  local bCapsuleRadiusCorrect = nTolerance > math.abs(nCapsuleRadius - nExpectedCapsuleRadius)
  local bCapsuleHalfHeightCorrect = nTolerance > math.abs(nCapsuleHalfHeight - nExpectedCapsuleHalfHeight)
  local bAllCorrect = bStand and bCapsuleRLCorrect and bMeshRLCorrect and bMeshContainerRLCorrect and bCapsuleRadiusCorrect and bCapsuleHalfHeightCorrect
  if not bAllCorrect then
    self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1
  else
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:UpdatePlayerAttachToVehicle PlayerKey:%s. bAllCorrect=%s Check Result:%d %d %d %d %d %d, Count:%d", tostring(self.PlayerKey), tostring(bAllCorrect), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, self.nUpdatePlayerAttachToVehicleCount))
  if self.nUpdatePlayerAttachToVehicleCount >= 3 and not bAllCorrect then
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local uPlayerController = GameplayData.GetPlayerController()
    if uPlayerController.ReportCrashKitFeature and uPlayerController.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
      local sReportInfo = string.format("VehicleShapeType:%s PlayerKey:%s. Check Result:%d %d %d %d %d %d. Capsule.RelativeLoc:%s Capsule.Radius:%s Capsule.HalfHeight:%s Mesh.RelativeLoc:%s MeshContainer.RelativeLocZ:%s", tostring(uVehicle.VehicleShapeType), tostring(self.PlayerKey), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, uActorRelativeLocation:ToString(), tostring(nCapsuleRadius), tostring(nCapsuleHalfHeight), uMeshRelativeLocation:ToString(), tostring(uMeshContainerRelativeLocationZ))
      uPlayerController.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(sReportInfo)
    end
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  local nTolerance = 1.0
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  if nTolerance <= math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ) then
    print(bWriteLog and string.format("BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded PlayerKey:%s. SetMeshContainerOffsetZ from:%s to:%s", tostring(uMeshContainerExpectedZ), tostring(uMeshContainerExpectedZ)))
    self:SetMeshContainerOffsetZ(uMeshContainerExpectedZ)
  end
end

function BRPlayerCharacterBase:ClearAttachToVehicleTimer()
  if self.nUpdatePlayerAttachToVehicleTimer then
    self:RemoveGameTimer(self.nUpdatePlayerAttachToVehicleTimer)
    self.nUpdatePlayerAttachToVehicleTimer = nil
  end
  if self.nFixMeshContainerTimer then
    self:RemoveGameTimer(self.nFixMeshContainerTimer)
    self.nFixMeshContainerTimer = nil
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  local EPawnState = import("EPawnState")
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
    self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local EGameModeType = import("EGameModeType")
    local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  local EParachuteState = import("EParachuteState")
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local uGameState = GameplayData:GetGameState()
  local STExtraGameStateBase = import("STExtraGameStateBase")
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    local EGameModeType = import("EGameModeType")
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  local EMovementMode = import("EMovementMode")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local UKismetSystemLibrary = import("KismetSystemLibrary")
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end
BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.UInt32,
    UEnums.EPropertyClass.UInt32
  }
}

function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
  print(bWriteLog and string.format("BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment Type = %d, Param = %s", Type, Param))
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      local EStateType = import("EStateType")
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        local ESTEPoseState = import("ESTEPoseState")
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  local loadLater = function()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
  self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
  return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ==============================================================================
-- ========================== CHEN PUBG SKIN MOD BYPASS ==========================
-- ==============================================================================

local function Notify(msg) local s = "[ELMASRY VIP ] " .. tostring(msg)
pcall(function() if _G.LexusNotify then _G.LexusNotify(s) end end)
pcall(function() local sh = import("ScriptHelperClient") if sh and
sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1,
G=1, B=0, A=1}, {X=1.2, Y=1.2}) end end) print(s) end

local _slua = rawget(_G, "slua")

local function Valid(obj) if not obj then return false end if _slua and
_slua.isValid then local ok, v = pcall(_slua.isValid, obj) if not ok or not v
then return false end end return true end

-- ========================================== 
-- STATIC VARIABLES & GLOBAL CHEN PUBG SKIN
-- ========================================== 
local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}
local SCALE_COLOR_V2 = {R=3, G=3, B=0, A=0}

local GLOBAL_BONE_LIST = {
    "head", "neck_01", "pelvis",
    "upperarm_r", "lowerarm_r", "hand_r",
    "upperarm_l", "lowerarm_l", "hand_l",
    "thigh_l", "calf_l", "foot_l",
    "thigh_r", "calf_r", "foot_r"
}

local GLOBAL_CONNECTIONS = {
    {"neck_01", "pelvis", C_YELLOW},
    {"neck_01", "upperarm_l", C_CYAN}, {"upperarm_l", "lowerarm_l", C_CYAN}, {"lowerarm_l", "hand_l", C_CYAN},
    {"neck_01", "upperarm_r", C_CYAN}, {"upperarm_r", "lowerarm_r", C_CYAN}, {"lowerarm_r", "hand_r", C_CYAN},
    {"pelvis", "thigh_l", C_CYAN}, {"thigh_l", "calf_l", C_CYAN}, {"calf_l", "foot_l", C_CYAN},
    {"pelvis", "thigh_r", C_CYAN}, {"thigh_r", "calf_r", C_CYAN}, {"calf_r", "foot_r", C_CYAN}
}

-- ========================================== 
-- CHEN PUBG SKIN + FULL FEATURES VIP 
-- ========================================== 
_G.LexusConfig = _G.LexusConfig or { 
    CustomMagicBullet = false,
    AutoHead = false, 
    EspVip = false, 
    EspDistance = false, 
    EspVipPro = false, 
    EspRadar = false, 
    EspLoai5 = false, 
    EspLoai6 = false, 
    EspLoai7 = false,
    EspAntenna = false, 
    Esp9_Count = false,
    EspOutline = false, 
    OutlineThickness = 10, 
    UnlockFPS = false, 
    IpadView = false, 
    CustomAimbot = false, 
    CustomAimbotClose = false, 
    CustomHRecoil = false,  
    CustomVRecoil = false,  
    LessShake = false, 
    RemoveGrass = false, 
    RemoveFog = false, 
    WhiteBody = false, 
    ColorBodyV2 = false,    
    WallXuyenTuong = false, 
    Crosshair = false, 
    Accuracy = false,
    GodMode = false, 
    WallClimb = false,
    FastCar = false,
    BlackSky = false,
    
    AimTouchEnable = false,
    AimTouchHipIgKnock = true,
    AimTouchHipIgBot = true,
    AimTouchSGIgKnock = false,
    AimTouchSGIgBot = false,
    AimTouchHipVisCheck = true,
    AimTouchSGVisCheck = false,
    AimTouchHipfire = false,
    AimTouchSG = false,
    AimTouchSGAutoFire = false,
    AimTouchScopeAll = false,
    AimTouchScopeIgKnock = false,
    AimTouchScopeIgBot = false,
    AimTouchScopeVisCheck = false,
    AimTouchScopeSniper = false,
    AimTouchSniperIgKnock = false,
    AimTouchSniperIgBot = false,
    AimTouchSniperVisCheck = false,
    
    ModSkin = false,           
    SkinOptionOpen = false,
    
    EnableDamageAnalysis = false,
    IgnoreFallingDamage = false,
    DisableAIIgnoreEnemyTarget = false,
    EnableMeleeDamageReport = false,
    ShowKnowledgeUI = false,
    EnableQTESystem = false,
    EnablePoisonSystem = false,
    AutoHideWeapon = false,
    CharacterOverrideAvatar = false,
    EnableSkillFlowReport = false,
    EnableSupplyBoxEvolution = false,
    EnableMaxWalkSpeedCurve = false,
    ShowHeadHPBar = false,
    EnableCustomGender = false,
    EnableLoadingAvatar = false,
    EnableSmokeParticle = false,
    EnableDamageShake = false,
    EnableStealLifeEffect = false,
    EnableTombBoxFilter = false,
    EnableGameStartSpeedUp = false,
    ExtraEnergyBonus = false,
    BehindAttackBonus = false,
}

_G.LexusState = _G.LexusState or { 
    LoopToken = 0, 
    NativeESPReady = false,
    GraphicsUnlocked = false, 
    MenuStep = 0, 
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    LastAimbotCheckTime = 0, 
    CustomTextData = nil,     
    LastAimbotConfigString = "",
    MagicUpdateVersion = 1,
    LastMagicConfigHash = "",
    PrevGraphicsState = {},
    
    StealLifeCount = 0,
    KillPlayerNum = 0,
    IsInMineArea = false,
    AIIgnoreEnemyTarget_RefCount = 0,
    SmokeParticleList = {},
    CachedSkillFlow = {},
    LastPlayEmoteID = nil,
    IsShowLoadingAvatar = false,
    IsCloseCharacterOverrideAvatar = false,
}

-- 🔒 قفل نهائي: أي حد يحاول يفتح التفعيلات دي، هتفضل false
local _DANGEROUS_KEYS = {
    CustomMagicBullet = true, AutoHead = true,
    CustomAimbot = true, CustomAimbotClose = true,
    GodMode = true, CustomHRecoil = true,
    CustomVRecoil = true
}
for k in pairs(_DANGEROUS_KEYS) do _G.LexusConfig[k] = false end
local _lockMT = getmetatable(_G.LexusConfig) or {}
local _oldNI = _lockMT.__newindex
_lockMT.__newindex = function(t, k, v)
    if _DANGEROUS_KEYS[k] then v = false end
    if _oldNI then return _oldNI(t, k, v) end
    rawset(t, k, v)
end
setmetatable(_G.LexusConfig, _lockMT)

local limitTime = os.time({ year = 2026, month = 11, day = 15, hour = 23, min = 59, sec = 0 })
local currentTime = os.time(os.date("!*t"))
local isExpired = false

pcall(function()
    local fileName = ".sys_time_cache"
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "../../ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName
    }
    
    if os and os.getenv then
        local homeDir = os.getenv("HOME")
        if homeDir and homeDir ~= "" then
            table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName)
            table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName)
        end
    end
    
    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then 
        local s, r = pcall(require, "client.logic.common.TimeManager")
        if s and r then tm = r end
    end
    if tm and type(tm.GetServerTime) == "function" then
        local serverTime = tm.GetServerTime()
        if serverTime and serverTime > 1700000000 then 
            currentTime = serverTime
        end
    end

    local lastSeenTime = 0
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local savedTime = tonumber(data) or 0
            if savedTime > lastSeenTime then
                lastSeenTime = savedTime
            end
            file:close()
        end
    end

    if currentTime < lastSeenTime then
        currentTime = lastSeenTime
    else
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(tostring(currentTime))
                file:close()
            end
        end
    end
end)

isExpired = (currentTime > limitTime)

-- ============================================================================
-- ULTIMATE MERGED BYPASS v3.0
-- ============================================================================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then slua_serialize.check = retTrue; slua_serialize.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end
    end)
end

local function InitializeMD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue; FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then TssSdk.GetFileMD5 = function() return "BYPASS" end; TssSdk.VerifyFileSignature = retTrue end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then STExtra.CheckMD5 = retTrue; STExtra.GetMD5 = function() return "BYPASS" end; STExtra.VerifyFile = retTrue end
    end)
end
local function InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then sub.StartCheck = nop; sub.ReportAbnormalFile = nop; sub.StopCheck = nop end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)
end
local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then SMTD.MTDePicture = function() return "" end; SMTD.ReMTDePicture = function() return "" end; SMTD.HasCaptured = retTrue; SMTD.TakeScreenshot = nop end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop; TLog.Send = nop; TLog.Flush = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop; CrashSight.Log = nop; CrashSight.SendCrash = nop; CrashSight.ReportUserException = nop end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.Gameplay.GameReport.GameReportUtils"]
        if GRUtils then GRUtils.BugglyPostExceptionFull = retFalse; GRUtils.CheckCanBugglyPostException = retFalse; GRUtils.ReplayReportData = nop; GRUtils.ReportGameException = nop; GRUtils.PostException = nop end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then CTR.SendReport = nop; CTR.SendException = nop; CTR.UploadLog = nop end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "FacebookAnalytics", "GameAnalytics"}) do
            local s = _G[sdk]; if s then s.logEvent = nop; s.trackEvent = nop; s.setEnabled = retFalse; s.sendEvent = nop; s.report = nop end
        end
    end)
end

local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "AvatarExceptionSubsystem", "ShootVerifySubSystemClient", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "FileCheckSubsystem", "BehaviorScoreSubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then pcall(function() sub[k] = nop end) end
                    end
                    if sub.ReportPingDelayTimer then sub:RemoveGameTimer(sub.ReportPingDelayTimer); sub.ReportPingDelayTimer = nil end; sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then AvaEx.CheckAvatarException = nop; AvaEx.CheckAvatarExceptionOnce = nop; AvaEx.ReportAvatarException = nop; AvaEx.CheckSlotMeshVisible = retFalse; AvaEx.CheckPawnVisible = retFalse; AvaEx.CheckCanBugglyPostException = retFalse end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local origData = TssSdk.OnRecvData
            TssSdk.OnRecvData = function(data) if type(data) == "string" and (data:find("report") or data:find("exception") or data:find("cheat") or data:find("violation") or data:find("hack") or data:find("verify")) then return end; if origData then origData(data) end end
            TssSdk.SendReportInfo = nop; TssSdk.ScanMemory = retTrue; TssSdk.IsEmulator = retFalse; TssSdk.GetTssSdkReportInfo = retEmptyString; TssSdk.CheckEnvironment = retTrue; TssSdk.VerifyProcess = retTrue
        end
    end)
end

local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({"GameReportSubsystem", "ReplaySubsystem"}) do
                local sub = SubMgr:Get(name)
                if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then pcall(function() sub[k] = nop end) end end end
            end
        end
        local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logRep then logRep.ReportReplay = nop; logRep.SendReportReq = nop; logRep.UploadReplay = nop end
    end)
end

local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "ReportEquipmentFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow", "ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}) do if _G[f] then _G[f] = retFalse end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow", "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow", "IsEnableReportAttackFlow", "IsEnableReportHitFlow", "IsEnableReportCircleFlow"}) do if _G[f] then _G[f] = retFalse end end
    end)
end

local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector", "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then for k, v in pairs(_G[c]) do if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then _G[c][k] = nop end end end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then SecSub.ReportData = nop; SecSub.CheckCheat = retFalse; SecSub.ValidatePlayer = retTrue; SecSub.CollectData = nop; SecSub.SendToServer = nop end
    end)
end

local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData", "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then sub.ReportData = nop; sub.SendReport = nop; sub.CollectTelemetry = nop end
    end)
end

local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop; _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then sub.ReportData = nop; sub.SendToServer = nop; sub.CollectTelemetry = nop; sub.StopCollection = nop end
    end)
end

local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then sub.ReportException = nop; sub.CheckModifier = retTrue; sub.ValidateModifier = retTrue; sub.ReportModifierError = nop end
    end)
end

local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then sub.ReportLocation = nop; sub.SendLocationData = nop; sub.VerifyLocation = retTrue end
    end)
end

local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then sub.OnShootVerifyFailed = nop; sub.SendVerifyData = nop; sub.ReportBulletHit = nop; sub.UploadHitInfo = nop; sub.VerifyShot = retTrue end
        if _G.BulletHitInfoUploadData then _G.BulletHitInfoUploadData.Report = nop; _G.BulletHitInfoUploadData.Send = nop; _G.BulletHitInfoUploadData.Upload = nop end
    end)
end

local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1, ["ReportSecVehicleMoveFlow"]=1,
                ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1, ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_net_saturate"]=1, ["report_speed_hack"]=1, ["report_wall_hack"]=1, ["report_aim_bot"]=1, ["report_esp_usage"]=1,
                ["report_modded_files"]=1, ["detect_cheat"]=1, ["ban_player"]=1, ["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CheckReportSecAttackFlow"]=1, ["CheckReportSecAttackFlowWithAttackFlow"]=1, ["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1, ["PlayerSecurityInfo"]=1, ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1, ["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1, ["IsEnableReportMrpcsInPartCircleFlow"]=1, ["bReportedModifierException"]=1,
                ["ReportModifierException"]=1, ["RPC_Server_ReportSimulateCharacterLocation"]=1, ["ReportSimulateCharacterLocation"]=1, ["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1, ["ShootVerifyFailed"]=1, ["report_unrealnet_exception"]=1, ["tss_sdk_report"]=1, ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1, ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1, ["SwiftHawkData"]=1,
                ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1,
                ["ReportHurtFlow"]=1, ["ReportUseSkillFlow"]=1, ["MeleeDamageReport"]=1, ["SkillFlowReport"]=1
            }
            NetUtil.SendPacket = function(packetName, ...) if blocked[packetName] then return nil end; return orig(packetName, ...) end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams", "RPC_Server_ReportSimulateCharacterLocation", "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...) for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end; return origRPC(rpcName, ...) end
        end
    end)
end

local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "Tick", "OnTick", "MHActiveLogic", "TriggerAvatarCheck", "StartAvatarCheck", "ReportItemID", "ReceiveAnyDamage", "OnWeaponHitRecord", "ShowSecurityAlert", "ServerReportAvatar", "ClientReportNetAvatar", "SendHisarData", "ValidateSecurityData", "StaticShowSecurityAlertInDev", "RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation", "DisableHiggsBoson", "CheckMHActive", "ReportViolation", "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty; Higgs.GetCurWeaponSkinID = retZero; Higgs.IsMHActive = retFalse; Higgs.bMHActive = false; Higgs.bCallPreReplication = false
            if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false; if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false; pc.HiggsBosonComponent:ControlMHActive(0) end
        end
    end)
end

local function InitializeAntiCheatHooks()
    pcall(function()
        local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HBC and HBC.StaticShowSecurityAlertInDev then HBC.StaticShowSecurityAlertInDev = nop end
    end)
    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = nop; _G.AvatarCheckCallback.OnReportItemID = nop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
            if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then PlayerController.HiggsBosonComponent:ControlMHActive(0); PlayerController.HiggsBosonComponent.bMHActive = false end
        end
    end
end

local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]; if not sub then local s, r = pcall(require, path); if s and r then sub = r end end
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "OnDSConnectionSaturated", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow", "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams"}
        for _, f in ipairs(reports) do GC[f] = nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse; GC.CheckReportSecAttackFlow = retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1, ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, ["kicked"]=1, ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1, ["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = nop; GC.OnPlayerActorChannelError = nop; GC.OnPlayerRPCValidateFailed = nop; GC.OnPlayerSpectateException = nop; GC.OnShutdownAfterError = nop; GC.IsBypassed = true
    end)
end

local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient", "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem", "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem", "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem", "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem", "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem", "MD5CheckSubsystem", "PakVerifySubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then pcall(function() sub[k] = nop end) end end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY", "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT", "ENABLE_PERFORMANCE_REPORT"}) do if _G[flag] then _G[flag] = false end end
        local origReq = require
        local blocked = {"HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem"}
        _G.require = function(m) for _, b in ipairs(blocked) do if m:find(b) then return {} end end; return origReq(m) end
    end)
end

_G.StartBypass_VIP_v3 = function()
    pcall(function()
        print("[ULTIMATE BYPASS] Starting initialization...")
        InitializeSLUABypass()
        InitializeMD5Bypass()
        InitializeSkinBypass()
        InitializeLogBlocker()
        InitializeScannerBlocker()
        InitializeReplayTelemetryBlocker()
        InitializeReportFlowBlocker()
        InitializePlayerSecurityBypass()
        InitializeClientFlowBypass()
        InitializeSwiftHawkBypass()
        InitializeCoronaLabBypass()
        InitializeModifierExceptionBypass()
        InitializeSimulateCharacterLocationBypass()
        InitializeShootVerificationBypass()
        InitializeNetworkPacketBlock()
        InitializeHiggsBosonBypass()
        InitializeAntiCheatHooks()
        InitializeAntiReport()
        InitializeGameplayBypass()
        InitializeKillAllSubsystems()
        InitializeFinalProtection()
        print("[ULTIMATE BYPASS] Complete - All Security Systems Disabled")
    end)
end

-- ========================================== 
-- HÀM QUẢN LÝ DỌN RÁC MAP MARK
-- ========================================== 
local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.LexusState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mark)
        end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then
            InGameMarkTools.RemoveMapMark(mark)
        end
    end)
    _G.LexusState.TrackedMarks[mark] = nil
end

local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
        
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName()) or ""
            if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_")) then
                isAI = true
                hasChecked = true
            end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

-- ========================================== 
-- LOST TOMB FEATURES INTEGRATION
-- ==========================================
_G.LostTomb_IgnoreFallingDamageMarkMap = {}

function _G.LostTomb_MarkIgnoreFallingDamage(Reason, bRemove, Duration)
    if not _G.LexusConfig.IgnoreFallingDamage then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if bRemove then
        _G.LostTomb_IgnoreFallingDamageMarkMap[Reason] = nil
    else
        local CurTime = os.time()
        _G.LostTomb_IgnoreFallingDamageMarkMap[Reason] = CurTime + Duration
    end
    local CurTime = os.time()
    for k, v in pairs(_G.LostTomb_IgnoreFallingDamageMarkMap) do
        if CurTime > v then _G.LostTomb_IgnoreFallingDamageMarkMap[k] = nil end
    end
    pcall(function()
        local fallDamageCheck = localPlayer.CheckIgnoreFallingDamage
        if type(fallDamageCheck) == "function" then
            local bIgnore = false
            for _, v in pairs(_G.LostTomb_IgnoreFallingDamageMarkMap) do
                if v >= CurTime then bIgnore = true break end
            end
            if bIgnore then
                localPlayer:SetAttrValue("LandDamageReduce", 1, -1)
            else
                localPlayer:SetAttrValue("LandDamageReduce", 0, -1)
            end
        end
    end)
end

function _G.LostTomb_AddAIIgnoreEnemyTargetRef()
    if not _G.LexusConfig.DisableAIIgnoreEnemyTarget then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if localPlayer:HasAuthority() then
        if localPlayer.AddAIIgnoreEnemyTargetRef then
            localPlayer:AddAIIgnoreEnemyTargetRef()
        end
    end
end

function _G.LostTomb_RemoveAIIgnoreEnemyTargetRef()
    if not _G.LexusConfig.DisableAIIgnoreEnemyTarget then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if localPlayer:HasAuthority() then
        if localPlayer.RemoveAIIgnoreEnemyTargetRef then
            localPlayer:RemoveAIIgnoreEnemyTargetRef()
        end
    end
end

function _G.LostTomb_UpdateStealLifeCount(count)
    if not _G.LexusConfig.EnableStealLifeEffect then return end
    _G.LexusState.StealLifeCount = (_G.LexusState.StealLifeCount or 0) + count
    local localPlayer = GameplayData.GetPlayerCharacter()
    if Valid(localPlayer) then
        if localPlayer.StealLifeCount ~= nil then
            localPlayer.StealLifeCount = _G.LexusState.StealLifeCount
            if type(localPlayer.OnRep_StealLifeCount) == "function" then
                localPlayer:OnRep_StealLifeCount()
            end
        end
    end
end

function _G.LostTomb_GetCustomGender()
    if not _G.LexusConfig.EnableCustomGender then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.GetCustomGender) == "function" then
        return localPlayer:GetCustomGender()
    end
    return 0
end

function _G.LostTomb_SetCloseCharacterOverrideAvatar(bClose)
    if not _G.LexusConfig.EnableLoadingAvatar then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.SetCloseCharacterOverrideAvatar) == "function" then
        localPlayer:SetCloseCharacterOverrideAvatar(bClose)
        _G.LexusState.IsCloseCharacterOverrideAvatar = bClose
    end
end

function _G.LostTomb_ShowHeadHPBar()
    if not _G.LexusConfig.ShowHeadHPBar then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if Valid(localPlayer.HeadHPBar) and type(localPlayer.HeadHPBar.CreateSceneMark) == "function" then
        localPlayer.HeadHPBar:CreateSceneMark()
    end
end

function _G.LostTomb_TryEnterQTE(ID)
    if not _G.LexusConfig.EnableQTESystem then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.TryEnterQTE) == "function" then
        return localPlayer:TryEnterQTE(ID)
    end
    return nil
end

function _G.LostTomb_LeaveQTE(ID)
    if not _G.LexusConfig.EnableQTESystem then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.LeaveQTE) == "function" then
        localPlayer:LeaveQTE(ID)
    end
end

function _G.LostTomb_SetPoisonOriginArray(actor, bIsAdd)
    if not _G.LexusConfig.EnablePoisonSystem then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.SetPoisonOriginArray) == "function" then
        localPlayer:SetPoisonOriginArray(actor, bIsAdd)
    end
end

function _G.LostTomb_ShowSupplyBoxEvolution(EvolutionShowParam)
    if not _G.LexusConfig.EnableSupplyBoxEvolution then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.SetSupplyBoxEvolutionShow) == "function" then
        localPlayer:SetSupplyBoxEvolutionShow(EvolutionShowParam)
    end
    if type(localPlayer.ShowSupplyBoxEvolutionTopTips) == "function" then
        localPlayer:ShowSupplyBoxEvolutionTopTips(EvolutionShowParam)
    end
end

function _G.LostTomb_MarkHiddenWeaponActor(Reason, bIsHidden)
    if not _G.LexusConfig.AutoHideWeapon then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.MarkHiddenWeaponActor) == "function" then
        localPlayer:MarkHiddenWeaponActor(Reason, bIsHidden)
    end
end

function _G.LostTomb_CreateNewDamageAnalysis(Info)
    if not _G.LexusConfig.EnableDamageAnalysis then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.CreateNewDamageAnalysis) == "function" then
        localPlayer:CreateNewDamageAnalysis(Info)
    end
end

function _G.LostTomb_AddDamageAnalysisInfo(Key, Value)
    if not _G.LexusConfig.EnableDamageAnalysis then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.AddDamageAnalysisInfo) == "function" then
        localPlayer:AddDamageAnalysisInfo(Key, Value)
    end
end

function _G.LostTomb_AddMaxWalkSpeedCurve(Curve)
    if not _G.LexusConfig.EnableMaxWalkSpeedCurve then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.AddMaxWalkSpeedCurve) == "function" then
        localPlayer:AddMaxWalkSpeedCurve(Curve)
    end
end

function _G.LostTomb_RemoveMaxWalkSpeedCurve(Curve)
    if not _G.LexusConfig.EnableMaxWalkSpeedCurve then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.RemoveMaxWalkSpeedCurve) == "function" then
        localPlayer:RemoveMaxWalkSpeedCurve(Curve)
    end
end

function _G.LostTomb_CheckIsBehindAttack(VictimActor)
    if not _G.LexusConfig.BehindAttackBonus then return false end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return false end
    if type(localPlayer.CheckIsBehindAttack) == "function" then
        return localPlayer:CheckIsBehindAttack(nil, VictimActor)
    end
    return false
end

function _G.LostTomb_OnGameStartSpeedUp()
    if not _G.LexusConfig.EnableGameStartSpeedUp then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.OnGameStartSpeedUp) == "function" then
        localPlayer:OnGameStartSpeedUp()
    end
end

function _G.LostTomb_HandleAddExtraEnergy(SkillMgr, SkillUID, StringEvent)
    if not _G.LexusConfig.ExtraEnergyBonus then return end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end
    if type(localPlayer.HandleAddExtraEnergy) == "function" then
        localPlayer:HandleAddExtraEnergy(SkillMgr, SkillUID, StringEvent)
    end
end

-- ==============================================================================
-- ================= DATA & LOGIC MOD SKIN ======================================
-- ==============================================================================
_G.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0}
}

_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}

_G.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then
            _G.VipAttachToIndex[attachId] = index
        end
    end
end

_G.WeaponSkinMap = _G.WeaponSkinMap or {}
_G.VehicleSkinMap = _G.VehicleSkinMap or {}
_G.OutfitMap = _G.OutfitMap or {}
_G.skinIdCache = _G.skinIdCache or {}
_G.skinIdCache2 = _G.skinIdCache2 or {}

_G.OutfitSkins = {
    Suit = {403003,1407916,1406469,1405870,1407140,1407141,1407142,1407550,1406638,1406872,1406971,1407103,1407512,1407391,1407366,1407330,1407329,1407286,1407285,1407277,1407276,1407275,1407225,1407224,1407259,1407161,1407160,1407107,1407106,1407079,1407048,1406977,1406976,1406898,1400569,1404000,1404049,1400119,1400117,1406060,1406891,1400687,1405160,1405145,1405436,1405435,1405434,1405064,1405207,1406895,1400333,1400377,1405092,1405121,1406889,1407278,1407279,1407381,1407380,1407385,1406389,1406388,1406387,1406386,1406385,1406140,1400782,1407392,1407318,1407317,1407404,1407402,1407401,1407387,1404434,1404437,1404440,1404448,1400324,1400708,1404043,1404048,1405953,1400101,1404153,1407440,1407441},
    Bag = {
        {501001, 501002, 501003}, {1501001174, 1501002174, 1501003174}, {1501001220, 1501002220, 1501003220},
        {1501001051, 1501002051, 1501003051}, {1501001443, 1501002443, 1501003443}, {1501001265, 1501002265, 1501003265},
        {1501001321, 1501002321, 1501003321}, {1501001277, 1501002277, 1501003277}, {1501001550, 1501002550, 1501003550},
        {1501001592, 1501002592, 1501003592}, {1501001608, 1501002608, 1501003608}, {1501001024, 1501002024, 1501003024},
        {1501001019, 1501002019, 1501003019}, {1501001179, 1501002179, 1501003179}, {1501001194, 1501002194, 1501003194},
        {1501001346, 1501002346, 1501003346}
    },
    Helmet = {
        {502001, 502002, 502003}, {1502001014, 1502002014, 1502003014}, {1502001349, 1502002349, 1502003349},
        {1502001012, 1502002012, 1502003012}, {1502001009, 1502002009, 1502003009}, {1502001397, 1502002397, 1502003397},
        {1502001390, 1502002390, 1502003390}, {1502001381, 1502002381, 1502003381}, {1502001358, 1502002358, 1502003358},
        {1502001350, 1502002350, 1502003350}, {1502001342, 1502002342, 1502003342}
    },
    Pet = {50000,50001,50002,50003,50004,50005,50006,50021,50022,50038,50039,50040}
}

_G.skinIdMappings = {
    [101004]={101004, 1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218},
    [101001]={101001,1101001276,1101001089,1101001213,1101001172,1101001127,1101001230,1101001241},                    
    [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},                    
    [102002]={102002,1102002136,1102002043,1102002061,1102002424},                                          
    [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008146,1101008061,1101008116},                    
    [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084},
    [102001]={102001, 1102001120},
    [101005]={101005, 1101005098},
    [104003]={104003, 1104003037},
    [104004]={104004, 1104004035, 1104004041}
}

_G.VehicleSkins = { 
    [1961001] = { 1961007, 1961010, 1961012, 1961013, 1961014, 1961015, 1961016, 1961017, 1961018, 1961020, 1961021, 1961024, 1961025, 1961029, 1961030, 1961031, 1961032, 1961033, 1961034, 1961035, 1961036, 1961037, 1961038, 1961039, 1961040, 1961041, 1961042, 1961043, 1961044, 1961045, 1961046, 1961047, 1961048, 1961049, 1961050, 1961051, 1961052, 1961053, 1961054, 1961055, 1961056, 1961057, 1961058, 1961059, 1961060, 1961061, 1961062, 1961063, 1961064, 1961065, 1961066, 1961067, 1961068, 1961069, 1961136, 1961137, 1961138, 1961139, 1961140, 1961141, 1961142, 1961143, 1961144, 1961145, 1961147, 1961148, 1961149, 1961150, 1961151, 1961152, 1961153 },
    [1903001] = { 1903005, 1903006, 1903007, 1903008, 1903011, 1903012, 1903013, 1903014, 1903015, 1903016, 1903017, 1903018, 1903019, 1903020, 1903021, 1903022, 1903023, 1903024, 1903029, 1903030, 1903031, 1903032, 1903033, 1903034, 1903035, 1903036, 1903037, 1903039, 1903040, 1903041, 1903042, 1903043, 1903044, 1903045, 1903046, 1903051, 1903052, 1903053, 1903054, 1903055, 1903056, 1903057, 1903058, 1903059, 1903060, 1903061, 1903062, 1903063, 1903066, 1903067, 1903068, 1903069, 1903070, 1903071, 1903072, 1903073, 1903074, 1903075, 1903076, 1903079, 1903080, 1903081, 1903082, 1903084, 1903085, 1903086, 1903087, 1903088, 1903089, 1903090, 1903189, 1903190, 1903191, 1903192, 1903193, 1903194, 1903195, 1903196, 1903197, 1903198, 1903199, 1903200, 1903201, 1903202, 1903203, 1903204, 1903205, 1903206, 1903207, 1903208, 1903209, 1903210, 1903211, 1903212, 1903213, 1903214, 1903215, 1903216, 1903217, 1903218, 1903219, 1903220, 1903221, 1903222, 1903223, 1903225, 1903226, 1903227, 1903228 }, 
    [1915001] = { 1915002, 1915003, 1915004, 1915005, 1915006, 1915007, 1915008, 1915009, 1915010, 1915011, 1915012, 1915013, 1915014, 1915015, 1915016, 1915017, 1915018, 1915019, 1915020, 1915021, 1915022, 1915023, 1915024, 1915025, 1915026, 1915099 },          
    [1908001] = { 1908002, 1908003, 1908005, 1908006, 1908007, 1908008, 1908009, 1908010, 1908011, 1908012, 1908013, 1908015, 1908016, 1908017, 1908018, 1908019, 1908021, 1908023, 1908030, 1908031, 1908032, 1908033, 1908034, 1908035, 1908036, 1908037, 1908039, 1908040, 1908041, 1908043, 1908047, 1908049, 1908050, 1908051, 1908052, 1908053, 1908054, 1908055, 1908056, 1908057, 1908059, 1908060, 1908061, 1908062, 1908063, 1908064, 1908066, 1908067, 1908068, 1908069, 1908070, 1908075, 1908076, 1908077, 1908078, 1908080, 1908081, 1908082, 1908083, 1908084, 1908085, 1908086, 1908087, 1908088, 1908089, 1908091, 1908094, 1908095, 1908096, 1908097, 1908098, 1908099, 1908100, 1908101, 1908102, 1908104, 1908105, 1908106, 1908107, 1908108, 1908109, 1908110, 1908111, 1908112, 1908188, 1908189 },   
    [1907001] = { 1907007, 1907008, 1907010, 1907011, 1907012, 1907013, 1907014, 1907016, 1907018, 1907019, 1907021, 1907022, 1907023, 1907025, 1907026, 1907027, 1907028, 1907029, 1907030, 1907032, 1907033, 1907034, 1907035, 1907036, 1907037, 1907038, 1907040, 1907041, 1907043, 1907044, 1907045, 1907046, 1907047, 1907048, 1907049, 1907050, 1907051, 1907052, 1907053, 1907054, 1907055, 1907056, 1907058, 1907059, 1907060, 1907061, 1907062, 1907063, 1907064, 1907065, 1907066, 1907067, 1907068, 1907069, 1907070, 1907071, 1907072, 1907073, 1907074 }
}
_G.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

local function DownloadGameItem(id)
    local puffer_manager = require('client.slua.logic.download.puffer.puffer_manager')
    local puffer_const = require('client.slua.logic.download.puffer_const')
    if puffer_manager and puffer_const and puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id}) ~= puffer_const.ENUM_DownloadState.Done then
        puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
    end
end
_G.download_item = DownloadGameItem

_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        if not _G.skinIdCache2[targetSkinId] then
            if _G.download_item then pcall(_G.download_item, targetSkinId) end
            _G.skinIdCache2[targetSkinId] = true
        end
        return targetSkinId
    end
    return weaponID
end

_G.equip_character_avatar = function(Character)
    if not Character or not slua.isValid(Character) or not Character.AvatarComponent2 then return end
    local BackpackUtils = import("BackpackUtils")
    local SlotSyncData = Character.AvatarComponent2.NetAvatarData and Character.AvatarComponent2.NetAvatarData.SlotSyncData
    if not SlotSyncData or not slua.isValid(SlotSyncData) or not BackpackUtils then return end
    
    local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
        if not mappedSkin or mappedSkin == 0 then return end
        local slotData = SlotSyncData:Get(ApplyDataIdx)
        if slotData and slotData.SlotID == ApplyEquipSlot then
            local applyItemId = mappedSkin
            if isLevelDependent and type(mappedSkin) == "table" then
                local level = levelFunc(slotData.AdditionalItemID) or 1
                if level < 1 then level = 1 end
                if level > 3 then level = 3 end
                applyItemId = mappedSkin[level] or mappedSkin[1]
            end
            if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then return end
            if not _G.skinIdCache[applyItemId] then
                if _G.download_item then pcall(_G.download_item, applyItemId) end
                _G.skinIdCache[applyItemId] = true
            end
            slotData.ItemId = applyItemId
            SlotSyncData:Set(ApplyDataIdx, slotData)
            Character.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
    end

    local hasGliderSlot = false
    for i = 0, SlotSyncData:Num() - 1 do
        local slotData = SlotSyncData:Get(i)
        if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then 
            hasGliderSlot = true
            break 
        end
    end
    if not hasGliderSlot then SlotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end

    for i = 0, SlotSyncData:Num() - 1 do
        EquipAvatar(i, _G.OutfitMap.Suit or 0, _G.CustSlotType.ClothesEquipemtSlot, false)
        EquipAvatar(i, _G.OutfitMap.Bag, _G.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
        EquipAvatar(i, _G.OutfitMap.Helmet, _G.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
        EquipAvatar(i, _G.OutfitMap.Parachute or 0, _G.CustSlotType.ParachuteEquipemtSlot, false)
    end
end

_G.ApplyWeaponSkins = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end
        
        for slot = 1, 3 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.get_skin_id(WeaponID) or WeaponID
                local isModified = false
                
                local SkinData = Weapon.synData:Get(7) 
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.skinIdCache[SkinID] then 
                        _G.download_item(SkinID)
                        _G.skinIdCache[SkinID] = true 
                    end
                    isModified = true
                end
                
                if SkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do 
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.BaseAttachToIndex[attachmentId] or _G.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.VIP_Attachments[SkinID][mapIndex] and _G.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.skinIdCache2[targetAttachId] then 
                                                if _G.download_item then pcall(_G.download_item, targetAttachId) end
                                                _G.skinIdCache2[targetAttachId] = true 
                                            end
                                            isModified = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                if isModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end
        end
    end)
end

_G.ApplyVehicleSkins = function(PlayerCharacter)
    pcall(function()
        local Vehicle = PlayerCharacter:GetCurrentVehicle()
        if not slua.isValid(Vehicle) then 
            _G.LastVehicleEntity = nil
            return 
        end
        
        local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
        if not slua.isValid(VehicleAvatar) then return end

        local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
        local currentId = tostring(Vehicle:GetAvatarId() or "")
        local applySkinId = 0
        
        for baseMapId, targetSkin in pairs(_G.VehicleSkinMap) do
            if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then 
                applySkinId = targetSkin
                break 
            end
        end

        if applySkinId and applySkinId > 0 and currentId ~= tostring(applySkinId) then
            _G.skinIdCache = _G.skinIdCache or {}
            if not _G.skinIdCache[applySkinId] then 
                if _G.download_item then pcall(_G.download_item, applySkinId) end
                _G.skinIdCache[applySkinId] = true 
            end

            VehicleAvatar.curSwitchEffectId = 7303001
            if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(applySkinId, true) end
            
            _G.CurrentEquipVehicleID = applySkinId
            _G.LastVehicleEntity = Vehicle
        end
    end)
end

_G.HandlePetLogic = function()
    pcall(function()
        local petSkin = _G.OutfitMap.Pet
        if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.LastAppliedPet then return end
        
        _G.skinIdCache = _G.skinIdCache or {}
        if not _G.skinIdCache[petSkin] then 
            if _G.download_item then pcall(_G.download_item, petSkin) end
            _G.skinIdCache[petSkin] = true 
        end
        
        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if logic_pet then
                if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
            end
        end
        _G.LastAppliedPet = petSkin
    end)
end

_G.ForceRefreshSkinMaps = function()
    pcall(function()
        if not _G.LexusState or not _G.LexusState.CustomTextData then return end
        local cData = _G.LexusState.CustomTextData

        if _G.OutfitSkins then
            if cData.SkinSuit and _G.OutfitSkins.Suit[cData.SkinSuit] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[cData.SkinSuit] end
            if cData.SkinBag and _G.OutfitSkins.Bag[cData.SkinBag] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[cData.SkinBag] end
            if cData.SkinHelmet and _G.OutfitSkins.Helmet[cData.SkinHelmet] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[cData.SkinHelmet] end
        end

        if _G.skinIdMappings then
            if cData.SkinM416 and _G.skinIdMappings[101004] and _G.skinIdMappings[101004][cData.SkinM416] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][cData.SkinM416] end
            if cData.SkinAKM and _G.skinIdMappings[101001] and _G.skinIdMappings[101001][cData.SkinAKM] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][cData.SkinAKM] end
            if cData.SkinSCAR and _G.skinIdMappings[101003] and _G.skinIdMappings[101003][cData.SkinSCAR] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][cData.SkinSCAR] end
            if cData.SkinM762 and _G.skinIdMappings[101008] and _G.skinIdMappings[101008][cData.SkinM762] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][cData.SkinM762] end
            if cData.SkinAUG and _G.skinIdMappings[101006] and _G.skinIdMappings[101006][cData.SkinAUG] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][cData.SkinAUG] end
            if cData.SkinUMP and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][cData.SkinUMP] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][cData.SkinUMP] end
            
            if cData.SkinUZI and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][cData.SkinUZI] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinGroza and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][cData.SkinGroza] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinS12K and _G.skinIdMappings[104003] and _G.skinIdMappings[104003][cData.SkinS12K] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][cData.SkinS12K] end
            if cData.SkinDBS and _G.skinIdMappings[104004] and _G.skinIdMappings[104004][cData.SkinDBS] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][cData.SkinDBS] end
        end

        if _G.VehicleSkins then
            if cData.SkinDacia and _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][cData.SkinDacia] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][cData.SkinDacia] end
            if cData.SkinUAZ and _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][cData.SkinUAZ] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][cData.SkinUAZ] end
            if cData.SkinCoupe and _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][cData.SkinCoupe] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][cData.SkinCoupe] end
            if cData.SkinBuggy and _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][cData.SkinBuggy] then _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][cData.SkinBuggy] end
            if cData.SkinMirado and _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][cData.SkinMirado] then _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][cData.SkinMirado] end
        end
    end)
end

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 0

_G.DeadBox_TemperRequest = function(PlayerController)
    if _G.NeedCheckDeadBoxTimer <= 0 then return end
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass))
    
    for _, deadBoxActor in pairs(deadBoxes) do
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    local currentBoxSkinId = 0
                    if PlayerCharacter.CurrentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                        currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                    else
                        local currentWeapon = PlayerCharacter:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) and currentWeapon.synData then
                            local weaponSkinData = currentWeapon.synData:Get(7)
                            if weaponSkinData and weaponSkinData.defineID then
                                currentBoxSkinId = weaponSkinData.defineID.TypeSpecificID
                            end
                        end
                    end
                    if currentBoxSkinId ~= 0 then
                        pcall(function()
                            DeadBoxAvatarComponent:ResetItemAvatar()
                            DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                            DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                        end)
                    end
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local CACHED_LinearColor = import("LinearColor")
local CACHED_GoldColor = CACHED_LinearColor and CACHED_LinearColor(1.0, 0.8, 0.0, 1.0) or nil
local CACHED_UI_Manager = nil

_G.ForceEnableKillCounterUI = function()
    pcall(function()
        local KillCounterUISubsystem = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KillCounterUISubsystem and KillCounterUISubsystem.__inner_impl and not _G.KCUISystemHacked2 then
            local kcImpl = KillCounterUISubsystem.__inner_impl
            kcImpl.CheckSupportKCUI = function() return true end
            kcImpl.CheckNeedMainKillCounterUI = function(self, PlayerWeapon, PlayerID)
                if slua.isValid(PlayerWeapon) then
                    local WeaponID = PlayerWeapon:GetWeaponID()
                    self:UpdateMainKillCounterUI(true, WeaponID, _G.get_skin_id(WeaponID) or WeaponID)
                else self:UpdateMainKillCounterUI(false) end
            end
            local originalUpdateMainKillCounterUI = kcImpl.UpdateMainKillCounterUI
            kcImpl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
                if bShow then AvatarID = _G.get_skin_id(WeaponID) or AvatarID end
                if originalUpdateMainKillCounterUI then originalUpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID) end
            end
            _G.KCUISystemHacked2 = true
        end

        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager and not _G.KCLogicHacked2 then
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if LogicKillCounter then
                LogicKillCounter.CheckSupportKC = function() return true end
                LogicKillCounter.CheckSupportKillCounterAvatar = function() return true end
                LogicKillCounter.CheckHasWeaponKillCounter = function() return true end
                LogicKillCounter.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                LogicKillCounter.GetEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetMyEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetOneWeaponKillCountInBattle = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                LogicKillCounter.GetWeaponKillCountByUid = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                _G.KCLogicHacked2 = true
            end
        end

        local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
        local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)
        
        if KillInfo and KillInfo.__inner_impl and not _G.KillInfoCounterHacked then
            local originalFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local LocalPlayer = require("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then 
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local skinID = _G.get_skin_id(weaponID)
                            if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                            if _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit end
                            
                            if CACHED_GoldColor then
                                DamageRecordData.IsUseColor, DamageRecordData.UseColor = true, CACHED_GoldColor
                            end
                            
                            if DamageRecordData.ResultHealthStatus == 2 then
                                _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
                                _G.NeedCheckDeadBoxTimer = 50 
                                
                                if not CACHED_UI_Manager then CACHED_UI_Manager = require("client.slua_ui_framework.manager") end
                                local uiMainKillCounter = CACHED_UI_Manager.GetUI(CACHED_UI_Manager.UI_Config_InGame.MainKillCounter)
                                
                                if uiMainKillCounter and uiMainKillCounter.UpdateWeaponID then
                                    local mainAvatarID = skinID or currentWeapon:GetWeaponMainAvatarID()
                                    uiMainKillCounter:UpdateWeaponID(weaponID, mainAvatarID)
                                    local kcModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                                    local kcItemID = kcModule:GetEquipedKillCounterId(0, mainAvatarID)
                                    uiMainKillCounter:SetKillCounterItemShowWithNum(kcItemID, _G.TDFTDeKillCounts[weaponID], mainAvatarID)
                                end
                            end
                        end
                    end
                end)
                if originalFileItem then return originalFileItem(self, DamageRecordData) end
            end
            _G.KillInfoCounterHacked = true
        end

        local SwitchWeaponSlotMode2 = package.loaded["GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2"] or require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
        if SwitchWeaponSlotMode2 and SwitchWeaponSlotMode2.__inner_impl and not _G.SlotBaseHacked then
            SwitchWeaponSlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                if slua.isValid(self.KillCounterImg) then 
                    self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible) 
                end
            end
            _G.SlotBaseHacked = true
        end
    end)
end

function _G.InitializeSkinModSystem()
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.LobbyBypassHacked then
            local originalPutonEquipment = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                if attachIndex then
                    local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                    if holdingWeaponSkinID and holdingWeaponSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[holdingWeaponSkinID] then
                        local vipAttachID = _G.VIP_Attachments[holdingWeaponSkinID][attachIndex]
                        if vipAttachID and vipAttachID > 0 then
                            if self.HandleDownload then self:HandleDownload(vipAttachID, nil, nil, false) end
                            itemID = vipAttachID
                        end
                    end
                end
                if originalPutonEquipment then return originalPutonEquipment(self, itemID, tAvatarCustom, tExtraData) end
            end

            local originalCharEquipWeaponByResId = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local retValue = originalCharEquipWeaponByResId and originalCharEquipWeaponByResId(self, resID, isUse, isAsync, SocketName) or nil
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return retValue
            end
            _G.LobbyBypassHacked = true
        end
    end)
    
    pcall(function()
        local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if Common_Items_UIBP and not _G.IconBaloHacked then
        local originalInitView = Common_Items_UIBP.InitView
            Common_Items_UIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displayResId = nil
                
                if _G.get_skin_id then
                    local skinID = _G.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then displayResId = skinID end
                end
                
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
                if not displayResId and attachIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) then
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local finalSkinID = _G.get_skin_id(weaponID) or weaponID
                            if finalSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[finalSkinID] then
                                local vipAttachID = _G.VIP_Attachments[finalSkinID][attachIndex]
                                if vipAttachID and vipAttachID > 0 then displayResId = vipAttachID end
                            end
                        end
                    end
                end
                
                if displayResId then
                    tExtraData.displayResId = displayResId
                    if not _G.skinIdCache2[displayResId] then
                        if _G.download_item then pcall(_G.download_item, displayResId) end
                        _G.skinIdCache2[displayResId] = true
                    end
                end
                if originalInitView then return originalInitView(self, nItemId, nCount, nValidTime, tExtraData) end
            end
            _G.IconBaloHacked = true
        end
    end)
end

-- ========================================== 
-- HỆ THỐNG LƯU VÀ TẢI SETTING MENU VIP
-- ========================================== 
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
                table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName)
            end
        end
    end)
    return paths
end

local ConfigFileName = "rpad_settings.txt"
_G.LastConfigSaveStr = ""

_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\nLexusConfig = {\n"
        for k, v in pairs(_G.LexusConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "},\nCustomTextData = {\n"
        if _G.LexusState and _G.LexusState.CustomTextData then
            for k, v in pairs(_G.LexusState.CustomTextData) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            end
        end
        data = data .. "}\n}"
        
        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data

        local paths = GetConfigPaths(ConfigFileName)
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(data)
                file:close()
                break
            end
        end
    end)
end

_G.LoadModSettings = function()
    pcall(function()
        local paths = GetConfigPaths(ConfigFileName)
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then
                content = file:read("*a")
                file:close()
                break
            end
        end

        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    if savedData.LexusConfig then
                        for k, v in pairs(savedData.LexusConfig) do
                            _G.LexusConfig[k] = v
                        end
                    end
                    if savedData.CustomTextData then
                        _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                        for k, v in pairs(savedData.CustomTextData) do
                            _G.LexusState.CustomTextData[k] = v
                        end
                    end
                end
            end
        end
        _G.SaveModSettings() 
    end)
end

local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker") 
        if okTicker and ticker and ticker.AddTimerOnce then 
            ticker.AddTimerOnce(3.0, AutoSaveLoop)
        end
    end)
end

if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

_G.ReadLiveConfig = function()
    if _G.SaveModSettings then _G.SaveModSettings() end
end

-- ============================================================
-- FAKE TEXT MAP - (بعد حذف النصوص الخطيرة)
-- ============================================================
local FakeTextMap = {
    [999000] = "ELMASRY VIP ",
    [999001] = "قائمة ESP المخصصة",
    [999002] = "قائمة الـ Aimbot المخصصة",
    [999003] = "ميزات إضافية",
    [999004] = "الجلود المميزة",
    [999005] = "⚠ قسم الحظر (خطير) ⚠",
    [999006] = "ميزات Lost Tomb",
    [999110] = "إظهار عداد اللاعبين والبوتات",
    
    [999100] = "مربع الهيكل العظمي",
    [999101] = "مسافة العدو",
    [999102] = "شريط الصحة",
    [999103] = "علامة الإصابة",
    [999104] = "مربع ESP",
    [999105] = "هيكل عظمي فقط",
    [999106] = "تمييز عدو/بوت",
    [999107] = "هوائي أخضر",
    [999108] = "هالة حمراء للعدو",
    [999109] = "حجم اللون",
    
    -- AimTouch فقط (الآمن)
    [999213] = "ثبات السلاح",
[999214] = "تصغير المؤشر",
    [999219] = "تفعيل اللمس للتصويب",
    [999220] = "تفعيل إطلاق من الورك",
    [999221] = "تفعيل الشوت قن",
    [999222] = "تفعيل جميع نطاقات التصويب",
    [999223] = "تفعيل القناصة",
    
    [999300] = "منظور الآيباد المخصص",
    [999301] = "زاوية الرؤية",
    [999302] = "165 إطار في الثانية حقيقي",
    [999303] = "ويل هلك (رؤية عبر الجدران)",
    [999304] = "جسم أبيض",
    [999305] = "سماء سوداء",
    [999306] = "إزالة الضباب",
    [999307] = "إزالة العشب",
    [999308] = "تسلق الجدران",
    [999309] = "سرعة السيارة الخارقة",
    
    [999400] = "جلود المود المميزة مفعلة",
    [999401] = "جميع بدلات X",
    [999402] = "جميع جلود الحقائب",
    [999403] = "جميع جلود الخوذ",
    [999404] = "M416",
    [999405] = "AKM",
    [999406] = "SCAR-L",
    [999407] = "M762",
    [999408] = "AUG",
    [999409] = "UMP45",
    [999410] = "UZI",
    [999411] = "GROZA",
    [999412] = "S12K",
    [999413] = "DBS",
    [999414] = "DACIA",
    [999415] = "UAZ",
    [999416] = "COUPE RB",
    [999417] = "BUGGY",
    [999418] = "MIRADO",
    
    [999500] = "⚠ قسم الحظر (خطير) ⚠",
    [999501] = "وضع الطيران",
    [999502] = "وضع الدوران",
    [999503] = "إلغاء ضرر السقوط",
    [999504] = "إزالة الضباب (عام)",
    [999505] = "إزالة العشب (عام)",
    
    [999600] = "ميزات Lost Tomb",
    [999601] = "تفعيل تحليل الضرر",
    [999602] = "تجاهل ضرر السقوط",
    [999603] = "تعطيل تجاهل الذكاء الاصطناعي للهدف",
    [999604] = "تفعيل تقرير ضرر الاشتباك",
    [999605] = "إظهار واجهة المعرفة",
    [999606] = "تفعيل نظام QTE",
    [999607] = "تفعيل نظام السموم",
    [999608] = "إخفاء السلاح تلقائياً",
    [999609] = "تجاوز مظهر الشخصية",
    [999610] = "تفعيل تقرير تدفق المهارات",
    [999611] = "تفعيل تطور صندوق الإمدادات",
    [999612] = "تفعيل منحنى سرعة المشي القصوى",
    [999613] = "إظهار شريط صحة الرأس",
    [999614] = "تفعيل الجنس المخصص",
    [999615] = "تفعيل مظهر التحميل",
    [999616] = "تفعيل جزيئات الدخان",
    [999617] = "تفعيل اهتزاز الضرر",
    [999618] = "تفعيل تأثير سرقة الحياة",
    [999619] = "تفعيل فلتر صندوق القبر",
    [999620] = "تفعيل تسريع بدء اللعبة",
    [999621] = "مكافأة طاقة إضافية",
    [999622] = "مكافأة الهجوم من الخلف",
}

local function HookLocUtil()
    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    if LocUtil and not LocUtil._IsModMenuHooked then
        local old = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if type(id) == "string" and not tonumber(id) then
                return id
            end
            if FakeTextMap[id] then 
                return FakeTextMap[id] 
            end
            return old(id)
        end
        LocUtil._IsModMenuHooked = true
        print("[MENU FIX] LocUtil hooked successfully!")
    end
end

_G.InitModMenuTab = function()
    HookLocUtil()
    
    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
    
    -- ============================================================
    -- ESP STACK
    -- ============================================================
    local StackESP = {
        { UI = AliasMap.Title, Text = 999001 },
        {
            Key = "ModMenu_ESP1", UI = AliasMap.Switcher,
            Text = 999100,
            GetFunc = function() return _G.LexusConfig.EspVip end,
            SetFunc = function(_, v) _G.LexusConfig.EspVip = v; return true end
        },
        {
            Key = "ModMenu_ESP2", UI = AliasMap.Switcher,
            Text = 999101,
            GetFunc = function() return _G.LexusConfig.EspDistance end,
            SetFunc = function(_, v) _G.LexusConfig.EspDistance = v; return true end
        },
        {
            Key = "ModMenu_ESP3", UI = AliasMap.Switcher,
            Text = 999102,
            GetFunc = function() return _G.LexusConfig.EspVipPro end,
            SetFunc = function(_, v) _G.LexusConfig.EspVipPro = v; return true end
        },
        {
            Key = "ModMenu_ESP4", UI = AliasMap.Switcher,
            Text = 999103,
            GetFunc = function() return _G.LexusConfig.EspRadar end,
            SetFunc = function(_, v) _G.LexusConfig.EspRadar = v; return true end
        },
        {
            Key = "ModMenu_ESP5", UI = AliasMap.Switcher,
            Text = 999104,
            GetFunc = function() return _G.LexusConfig.EspLoai5 end,
            SetFunc = function(_, v) _G.LexusConfig.EspLoai5 = v; return true end
        },
        {
            Key = "ModMenu_ESP6", UI = AliasMap.Switcher,
            Text = 999105,
            GetFunc = function() return _G.LexusConfig.EspLoai6 end,
            SetFunc = function(_, v) _G.LexusConfig.EspLoai6 = v; return true end
        },
        {
            Key = "ModMenu_ESP7", UI = AliasMap.Switcher,
            Text = 999106,
            GetFunc = function() return _G.LexusConfig.EspLoai7 end,
            SetFunc = function(_, v) _G.LexusConfig.EspLoai7 = v; return true end
        },
        {
            Key = "ModMenu_ESPAntenna", UI = AliasMap.Switcher,
            Text = 999107,
            GetFunc = function() return _G.LexusConfig.EspAntenna end,
            SetFunc = function(_, v) _G.LexusConfig.EspAntenna = v; return true end
        },
        {
            Key = "ModMenu_ESP9_Count", UI = AliasMap.Switcher,
            Text = 999110,
            GetFunc = function() return _G.LexusConfig.Esp9_Count end,
            SetFunc = function(_, v) 
                _G.LexusConfig.Esp9_Count = v
                if v and _G.RedBoxOverlay then
                    pcall(function() _G.RedBoxOverlay.Start() end)
                elseif not v and _G.RedBoxOverlay then
                    pcall(function() _G.RedBoxOverlay.Stop() end)
                end
                return true 
            end
        },
        {
            Key = "ModMenu_ESPOutline_Ex", UI = AliasMap.TitleSwitcher,
            Text = 999108, ExpandIndex = 0,
            GetFunc = function() return _G.LexusConfig.EspOutline end,
            SetFunc = function(_, v) _G.LexusConfig.EspOutline = v; return true end
        },
        {
            Key = "ModMenu_ESPOutline_Thickness", UI = AliasMap.Slider,
            Text = 999109, ExpandHandle = "ModMenu_ESPOutline_Ex",
            MinValue = 1, MaxValue = 20, min = 1, max = 20,
            GetFunc = function() return _G.LexusConfig.OutlineThickness or 10 end,
            SetFunc = function(_, v) _G.LexusConfig.OutlineThickness = v; return true end
        },
    }

    -- ============================================================
    -- AIMBOT STACK - الـ AimTouch الآمن فقط
    -- ============================================================
    local StackAimbot = {
        { UI = AliasMap.Title, Text = 999002 },
        {
            Key = "ModMenu_AT_Ex", UI = AliasMap.TitleSwitcher,
            Text = 999219, ExpandIndex = 0,
            GetFunc = function() return _G.LexusConfig.AimTouchEnable end,
            SetFunc = function(_, v) _G.LexusConfig.AimTouchEnable = v; return true end
        },
        {
            Key = "ModMenu_AT_Hip_Ex", UI = AliasMap.TitleSwitcher,
            Text = 999220, ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0,
            GetFunc = function() return _G.LexusConfig.AimTouchHipfire end,
            SetFunc = function(_, v) _G.LexusConfig.AimTouchHipfire = v; return true end
        },
        {
            Key = "ModMenu_AT_SG_Ex", UI = AliasMap.TitleSwitcher,
            Text = 999221, ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0,
            GetFunc = function() return _G.LexusConfig.AimTouchSG end,
            SetFunc = function(_, v) _G.LexusConfig.AimTouchSG = v; return true end
        },
        {
            Key = "ModMenu_AT_ScopeAll_Ex", UI = AliasMap.TitleSwitcher,
            Text = 999222, ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0,
            GetFunc = function() return _G.LexusConfig.AimTouchScopeAll end,
            SetFunc = function(_, v) _G.LexusConfig.AimTouchScopeAll = v; return true end
        },
        {
                    Key = "ModMenu_AT_Sniper_Ex", UI = AliasMap.TitleSwitcher,
        Text = 999223, ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0,
        GetFunc = function() return _G.LexusConfig.AimTouchScopeSniper end,
        SetFunc = function(_, v) _G.LexusConfig.AimTouchScopeSniper = v; return true end
    },
    {
        Key = "ModMenu_Crosshair", UI = AliasMap.Switcher,
        Text = 999214,
        GetFunc = function() return _G.LexusConfig.Crosshair end,
        SetFunc = function(_, v) _G.LexusConfig.Crosshair = v; return true end
    },
    {
        Key = "ModMenu_Accuracy", UI = AliasMap.Switcher,
        Text = 999213,
        GetFunc = function() return _G.LexusConfig.Accuracy end,
        SetFunc = function(_, v) _G.LexusConfig.Accuracy = v; return true end
    },
}

    -- ============================================================
    -- EXTRA FEATURES STACK
    -- ============================================================
    local StackCombat = {
        { UI = AliasMap.Title, Text = 999003 },
        {
            Key = "ModMenu_Ipad_Ex", UI = AliasMap.TitleSwitcher,
            Text = 999300, ExpandIndex = 0,
            GetFunc = function() return _G.LexusConfig.IpadView end,
            SetFunc = function(_, v) _G.LexusConfig.IpadView = v; return true end
        },
        {
            Key = "ModMenu_Ipad_FOV", UI = AliasMap.Slider,
            Text = 999301, ExpandHandle = "ModMenu_Ipad_Ex",
            MinValue = 1, MaxValue = 100, min = 1, max = 100,
            GetFunc = function() return (_G.LexusState.CustomTextData.IpadViewFOV or 120) - 90 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.IpadViewFOV = 90 + v; return true end
        },
        {
            Key = "ModMenu_165FPS", UI = AliasMap.Switcher,
            Text = 999302,
            GetFunc = function() return _G.LexusConfig.UnlockFPS end,
            SetFunc = function(_, v) _G.LexusConfig.UnlockFPS = v; return true end
        },
        {
            Key = "ModMenu_WallColor", UI = AliasMap.Switcher,
            Text = 999303,
            GetFunc = function() return _G.LexusConfig.WallXuyenTuong end,
            SetFunc = function(_, v) _G.LexusConfig.WallXuyenTuong = v; _G.LexusConfig.ColorBodyV2 = v; return true end
        },
        {
            Key = "ModMenu_WhiteBody", UI = AliasMap.Switcher,
            Text = 999304,
            GetFunc = function() return _G.LexusConfig.WhiteBody end,
            SetFunc = function(_, v) _G.LexusConfig.WhiteBody = v; return true end
        },
        {
            Key = "ModMenu_BlackSky", UI = AliasMap.Switcher,
            Text = 999305,
            GetFunc = function() return _G.LexusConfig.BlackSky end,
            SetFunc = function(_, v) _G.LexusConfig.BlackSky = v; return true end
        },
        {
            Key = "ModMenu_RemoveFog", UI = AliasMap.Switcher,
            Text = 999306,
            GetFunc = function() return _G.LexusConfig.RemoveFog end,
            SetFunc = function(_, v) _G.LexusConfig.RemoveFog = v; return true end
        },
        {
            Key = "ModMenu_RemoveGrass", UI = AliasMap.Switcher,
            Text = 999307,
            GetFunc = function() return _G.LexusConfig.RemoveGrass end,
            SetFunc = function(_, v) _G.LexusConfig.RemoveGrass = v; return true end
        },
    }

    -- ============================================================
    -- SKIN STACK
    -- ============================================================
    local StackSkin = {
        { UI = AliasMap.Title, Text = 999004 },
        {
            Key = "ModMenu_ModSkin", UI = AliasMap.TitleSwitcher,
            Text = 999400, ExpandIndex = 0,
            GetFunc = function() return _G.LexusConfig.ModSkin end,
            SetFunc = function(_, v) _G.LexusConfig.ModSkin = v; return true end
        },
        {
            Key = "ModMenu_Skin_Suit", UI = AliasMap.Slider,
            Text = 999401, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 80,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinSuit or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinSuit = v; 
                if _G.OutfitSkins and _G.OutfitSkins.Suit[v] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_Bag", UI = AliasMap.Slider,
            Text = 999402, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 15,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinBag or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinBag = v; 
                if _G.OutfitSkins and _G.OutfitSkins.Bag[v] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_Helmet", UI = AliasMap.Slider,
            Text = 999403, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 11,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinHelmet or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinHelmet = v; 
                if _G.OutfitSkins and _G.OutfitSkins.Helmet[v] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_M416", UI = AliasMap.Slider,
            Text = 999404, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 8,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinM416 or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinM416 = v; 
                if _G.skinIdMappings[101004] and _G.skinIdMappings[101004][v] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_AKM", UI = AliasMap.Slider,
            Text = 999405, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 8,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinAKM or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinAKM = v; 
                if _G.skinIdMappings[101001] and _G.skinIdMappings[101001][v] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_SCAR", UI = AliasMap.Slider,
            Text = 999406, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 8,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinSCAR or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinSCAR = v; 
                if _G.skinIdMappings[101003] and _G.skinIdMappings[101003][v] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_M762", UI = AliasMap.Slider,
            Text = 999407, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 8,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinM762 or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinM762 = v; 
                if _G.skinIdMappings[101008] and _G.skinIdMappings[101008][v] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_AUG", UI = AliasMap.Slider,
            Text = 999408, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 7,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinAUG or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinAUG = v; 
                if _G.skinIdMappings[101006] and _G.skinIdMappings[101006][v] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_UMP", UI = AliasMap.Slider,
            Text = 999409, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 5,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinUMP or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinUMP = v; 
                if _G.skinIdMappings[102002] and _G.skinIdMappings[102002][v] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_UZI", UI = AliasMap.Slider,
            Text = 999410, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 2,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinUZI or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinUZI = v; 
                if _G.skinIdMappings[102001] and _G.skinIdMappings[102001][v] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_Groza", UI = AliasMap.Slider,
            Text = 999411, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 2,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinGroza or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinGroza = v; 
                if _G.skinIdMappings[101005] and _G.skinIdMappings[101005][v] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_S12K", UI = AliasMap.Slider,
            Text = 999412, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 2,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinS12K or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinS12K = v; 
                if _G.skinIdMappings[104003] and _G.skinIdMappings[104003][v] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_DBS", UI = AliasMap.Slider,
            Text = 999413, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 3,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinDBS or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinDBS = v; 
                if _G.skinIdMappings[104004] and _G.skinIdMappings[104004][v] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_Dacia", UI = AliasMap.Slider,
            Text = 999414, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 90,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinDacia or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinDacia = v; 
                if _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][v] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_UAZ", UI = AliasMap.Slider,
            Text = 999415, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 90,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinUAZ or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinUAZ = v; 
                if _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][v] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_Coupe", UI = AliasMap.Slider,
            Text = 999416, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 70,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinCoupe or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinCoupe = v; 
                if _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][v] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_Buggy", UI = AliasMap.Slider,
            Text = 999417, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 50,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinBuggy or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinBuggy = v; 
                if _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][v] then _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][v] end 
                return true end
        },
        {
            Key = "ModMenu_Skin_Mirado", UI = AliasMap.Slider,
            Text = 999418, ExpandHandle = "ModMenu_ModSkin",
            MinValue = 1, MaxValue = 27,
            GetFunc = function() return _G.LexusState.CustomTextData.SkinMirado or 1 end,
            SetFunc = function(_, v) _G.LexusState.CustomTextData.SkinMirado = v; 
                if _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][v] then _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][v] end 
                return true end
        },
    }

    -- ============================================================
    -- BAN SECTION STACK
    -- ============================================================
    if not _G.BanConfig then 
        _G.BanConfig = {
            FlyMode = false,
            SpinMode = false,
            NoFallDamage = false,
            RemoveFogGlobal = false,
            RemoveGrassGlobal = false
        }
    end

    local StackBan = {
        { UI = AliasMap.Title, Text = 999500 },
        {
            Key = "Ban_FlyMode", UI = AliasMap.Switcher,
            Text = 999501,
            GetFunc = function() return _G.BanConfig.FlyMode end,
            SetFunc = function(_, v) _G.BanConfig.FlyMode = v; return true end
        },
        {
            Key = "Ban_SpinMode", UI = AliasMap.Switcher,
            Text = 999502,
            GetFunc = function() return _G.BanConfig.SpinMode end,
            SetFunc = function(_, v) _G.BanConfig.SpinMode = v; return true end
        },
        {
            Key = "Ban_NoFallDamage", UI = AliasMap.Switcher,
            Text = 999503,
            GetFunc = function() return _G.BanConfig.NoFallDamage end,
            SetFunc = function(_, v) _G.BanConfig.NoFallDamage = v; return true end
        },
        {
            Key = "Ban_RemoveFog", UI = AliasMap.Switcher,
            Text = 999504,
            GetFunc = function() return _G.BanConfig.RemoveFogGlobal end,
            SetFunc = function(_, v) _G.BanConfig.RemoveFogGlobal = v; return true end
        },
        {
            Key = "Ban_RemoveGrass", UI = AliasMap.Switcher,
            Text = 999505,
            GetFunc = function() return _G.BanConfig.RemoveGrassGlobal end,
            SetFunc = function(_, v) _G.BanConfig.RemoveGrassGlobal = v; return true end
        },
    }

    -- ============================================================
    -- LOST TOMB STACK
    -- ============================================================
    local StackLostTomb = {
        { UI = AliasMap.Title, Text = 999600 },
        {
            Key = "LT_DamageAnalysis", UI = AliasMap.Switcher,
            Text = 999601,
            GetFunc = function() return _G.LexusConfig.EnableDamageAnalysis end,
            SetFunc = function(_, v) _G.LexusConfig.EnableDamageAnalysis = v; return true end
        },
        {
            Key = "LT_IgnoreFallingDamage", UI = AliasMap.Switcher,
            Text = 999602,
            GetFunc = function() return _G.LexusConfig.IgnoreFallingDamage end,
            SetFunc = function(_, v) _G.LexusConfig.IgnoreFallingDamage = v; return true end
        },
        {
            Key = "LT_DisableAIIgnore", UI = AliasMap.Switcher,
            Text = 999603,
            GetFunc = function() return _G.LexusConfig.DisableAIIgnoreEnemyTarget end,
            SetFunc = function(_, v) _G.LexusConfig.DisableAIIgnoreEnemyTarget = v; return true end
        },
        {
            Key = "LT_MeleeDamageReport", UI = AliasMap.Switcher,
            Text = 999604,
            GetFunc = function() return _G.LexusConfig.EnableMeleeDamageReport end,
            SetFunc = function(_, v) _G.LexusConfig.EnableMeleeDamageReport = v; return true end
        },
        {
            Key = "LT_ShowKnowledgeUI", UI = AliasMap.Switcher,
            Text = 999605,
            GetFunc = function() return _G.LexusConfig.ShowKnowledgeUI end,
            SetFunc = function(_, v) _G.LexusConfig.ShowKnowledgeUI = v; return true end
        },
        {
            Key = "LT_QTE", UI = AliasMap.Switcher,
            Text = 999606,
            GetFunc = function() return _G.LexusConfig.EnableQTESystem end,
            SetFunc = function(_, v) _G.LexusConfig.EnableQTESystem = v; return true end
        },
        {
            Key = "LT_Poison", UI = AliasMap.Switcher,
            Text = 999607,
            GetFunc = function() return _G.LexusConfig.EnablePoisonSystem end,
            SetFunc = function(_, v) _G.LexusConfig.EnablePoisonSystem = v; return true end
        },
        {
            Key = "LT_AutoHideWeapon", UI = AliasMap.Switcher,
            Text = 999608,
            GetFunc = function() return _G.LexusConfig.AutoHideWeapon end,
            SetFunc = function(_, v) _G.LexusConfig.AutoHideWeapon = v; return true end
        },
        {
            Key = "LT_OverrideAvatar", UI = AliasMap.Switcher,
            Text = 999609,
            GetFunc = function() return _G.LexusConfig.CharacterOverrideAvatar end,
            SetFunc = function(_, v) _G.LexusConfig.CharacterOverrideAvatar = v; return true end
        },
        {
            Key = "LT_SkillFlowReport", UI = AliasMap.Switcher,
            Text = 999610,
            GetFunc = function() return _G.LexusConfig.EnableSkillFlowReport end,
            SetFunc = function(_, v) _G.LexusConfig.EnableSkillFlowReport = v; return true end
        },
        {
            Key = "LT_SupplyBoxEvolution", UI = AliasMap.Switcher,
            Text = 999611,
            GetFunc = function() return _G.LexusConfig.EnableSupplyBoxEvolution end,
            SetFunc = function(_, v) _G.LexusConfig.EnableSupplyBoxEvolution = v; return true end
        },
        {
            Key = "LT_MaxWalkSpeed", UI = AliasMap.Switcher,
            Text = 999612,
            GetFunc = function() return _G.LexusConfig.EnableMaxWalkSpeedCurve end,
            SetFunc = function(_, v) _G.LexusConfig.EnableMaxWalkSpeedCurve = v; return true end
        },
        {
            Key = "LT_HeadHPBar", UI = AliasMap.Switcher,
            Text = 999613,
            GetFunc = function() return _G.LexusConfig.ShowHeadHPBar end,
            SetFunc = function(_, v) _G.LexusConfig.ShowHeadHPBar = v; return true end
        },
        {
            Key = "LT_CustomGender", UI = AliasMap.Switcher,
            Text = 999614,
            GetFunc = function() return _G.LexusConfig.EnableCustomGender end,
            SetFunc = function(_, v) _G.LexusConfig.EnableCustomGender = v; return true end
        },
        {
            Key = "LT_LoadingAvatar", UI = AliasMap.Switcher,
            Text = 999615,
            GetFunc = function() return _G.LexusConfig.EnableLoadingAvatar end,
            SetFunc = function(_, v) _G.LexusConfig.EnableLoadingAvatar = v; return true end
        },
        {
            Key = "LT_SmokeParticle", UI = AliasMap.Switcher,
            Text = 999616,
            GetFunc = function() return _G.LexusConfig.EnableSmokeParticle end,
            SetFunc = function(_, v) _G.LexusConfig.EnableSmokeParticle = v; return true end
        },
        {
            Key = "LT_DamageShake", UI = AliasMap.Switcher,
            Text = 999617,
            GetFunc = function() return _G.LexusConfig.EnableDamageShake end,
            SetFunc = function(_, v) _G.LexusConfig.EnableDamageShake = v; return true end
        },
        {
            Key = "LT_StealLife", UI = AliasMap.Switcher,
            Text = 999618,
            GetFunc = function() return _G.LexusConfig.EnableStealLifeEffect end,
            SetFunc = function(_, v) _G.LexusConfig.EnableStealLifeEffect = v; return true end
        },
        {
            Key = "LT_TombBoxFilter", UI = AliasMap.Switcher,
            Text = 999619,
            GetFunc = function() return _G.LexusConfig.EnableTombBoxFilter end,
            SetFunc = function(_, v) _G.LexusConfig.EnableTombBoxFilter = v; return true end
        },
        {
            Key = "LT_GameStartSpeedUp", UI = AliasMap.Switcher,
            Text = 999620,
            GetFunc = function() return _G.LexusConfig.EnableGameStartSpeedUp end,
            SetFunc = function(_, v) _G.LexusConfig.EnableGameStartSpeedUp = v; return true end
        },
        {
            Key = "LT_ExtraEnergy", UI = AliasMap.Switcher,
            Text = 999621,
            GetFunc = function() return _G.LexusConfig.ExtraEnergyBonus end,
            SetFunc = function(_, v) _G.LexusConfig.ExtraEnergyBonus = v; return true end
        },
        {
            Key = "LT_BehindAttack", UI = AliasMap.Switcher,
            Text = 999622,
            GetFunc = function() return _G.LexusConfig.BehindAttackBonus end,
            SetFunc = function(_, v) _G.LexusConfig.BehindAttackBonus = v; return true end
        },
    }

    -- ============================================================
    -- REGISTER MENU
    -- ============================================================
    if not SettingPageDefine.MyModMenu then
        SettingPageDefine.MyModMenu = {
            Key = "MyModMenu",
            Text = 999000,
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "Cat_ESP", Text = 999001, Stack = StackESP },
                { Key = "Cat_Aimbot", Text = 999002, Stack = StackAimbot },
                { Key = "Cat_Combat", Text = 999003, Stack = StackCombat },
                { Key = "Cat_Skin", Text = 999004, Stack = StackSkin },
                -- { Key = "Cat_Ban", Text = 999500, Stack = StackBan },
                -- { Key = "Cat_LostTomb", Text = 999600, Stack = StackLostTomb },
            }
        }
        table.insert(SettingCatalog, SettingPageDefe.MyModMenu)
        print("[MENU FIX] Menu registered successfully!")
    end

    -- ============================================================
    -- HOOK UIMANAGER
    -- ============================================================
    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...)
            
            if config and config.keyName and string.find(string.lower(config.keyName), "setting_main") then
                local catalog = args[1]
                if type(catalog) == "table" then
                    local has = false
                    for _, page in ipairs(catalog) do
                        if type(page) == "table" and page.Key == "MyModMenu" then
                            has = true
                            break
                        end
                    end
                    if not has and SettingPageDefine.MyModMenu then
                        table.insert(catalog, 1, SettingPageDefine.MyModMenu)
                    end
                end
            end
            local table_unpack = table.unpack or unpack
            return old(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
        print("[MENU FIX] UIManager hooked successfully!")
    end
end

_G.InitModMenuTab()
print("[MENU FIX] Menu fixed successfully!")
print("[CREDIT] ELMASRY VIP  | ELMASRY VIP ")
print("[INFO] If you need any paid stuff in cheap price, contact us!")

-- ============================================================
-- BAN SECTION FEATURES
-- ============================================================
local function BanFeaturesLoop()
    pcall(function()
        local uCon = slua_GameFrontendHUD:GetPlayerController()
        if not Valid(uCon) then return end
        local pawn = uCon:GetPlayerCharacterSafety()
        if not Valid(pawn) then return end
        
        if _G.BanConfig.FlyMode then
            pawn.CharacterMovement.GravityScale = -0.45
            pawn.CharacterMovement.MaxWalkSpeed = 1350
            pawn.CharacterMovement.JumpZVelocity = 1350
        end
        
        if _G.BanConfig.NoFallDamage then
            pawn.CharacterMovement.bEnableLandDamage = false
            pawn.CharacterMovement.FallingLandedDamageEnabled = false
            pawn:SetAttrValue("LandDamageReduce", 1, -1)
            pawn:AddBuffByID(60447, pawn, 1, 0, 1)
        end
        
        if _G.BanConfig.SpinMode and Valid(pawn.Mesh) then
            local spinAngle = (spinAngle or 0) + 20
            if spinAngle > 360 then spinAngle = 0 end
            pawn.Mesh:K2_SetRelativeRotation(FRotator(0, spinAngle, 0), false, nil, false)
        end
        
        if _G.BanConfig.RemoveFogGlobal then
            local UKismetSystemLibrary = import("KismetSystemLibrary")
            UKismetSystemLibrary.ExecuteConsoleCommand(nil, "r.Fog 0")
            UKismetSystemLibrary.ExecuteConsoleCommand(nil, "r.VolumetricFog 0")
        end
        
        if _G.BanConfig.RemoveGrassGlobal then
            local UKismetSystemLibrary = import("KismetSystemLibrary")
            UKismetSystemLibrary.ExecuteConsoleCommand(nil, "foliage.DensityScale 0")
            UKismetSystemLibrary.ExecuteConsoleCommand(nil, "grass.DensityScale 0")
            UKismetSystemLibrary.ExecuteConsoleCommand(nil, "r.Foliage.DensityScale 0")
        end
    end)
end

local function StartBanLoop()
    local uCon = slua_GameFrontendHUD:GetPlayerController()
    if not Valid(uCon) then
        uCon = import("GameplayStatics").GetPlayerController(slua_GameFrontendHUD:GetWorld(), 0)
    end
    if not Valid(uCon) then return end
    uCon:AddGameTimer(0.05, true, BanFeaturesLoop)
end

pcall(StartBanLoop)

print("[MENU FIX] All features integrated successfully!")

-- ========================================== 
-- KHỞI TẠO HỆ THỐNG ESP (GỐC)
-- ========================================== 
local function InitializeNativeESP() 
    if _G.LexusState.NativeESPReady then return end
    pcall(function() 
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools") 
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig") 
        local function ApplyCfg(cfg)
            if not cfg then return end 
            if cfg[1006] then 
                cfg[1006].bBindBlocked = true;
                cfg[1006].bBindOutScreen = true; 
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000; 
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root"; 
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30) 
            end 
            if cfg[1003] then 
                cfg[1003].bBindBlocked = true;
                cfg[1003].bBindOutScreen = true; 
                cfg[1003].MaxWidgetNum = 99
                cfg[1003].MaxShowDistance = 6000000; 
                cfg[1003].bScaleByDistance = false
                cfg[1003].BindSocketName = "head"; 
                cfg[1003].bUseLuaWorldSocketName = true
            end 
            cfg[9999] = { 
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, 
                MaxShowDistance = 6000000, 
                bBindOutScreen = true,
                bBindBlocked = true, 
                bIsBindingActor = true, 
                BindSocketName = "head",
                bUseLuaWorldSocketName = true, 
                WorldPositionOffset = FVector(0, 0, 50),
                bNeedPreLoad = true, 
                Priority = 2 
            } 
        end 
        ApplyCfg(currentMarkCfg) 
        for k, cfg in pairs(package.loaded) do 
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then 
                ApplyCfg(cfg) 
            end 
        end 
    end)
    _G.LexusState.NativeESPReady = true 
    Notify("Native ESP System Initialized") 
end

-- ========================================== 
-- CORE FUNCTIONS
-- ========================================== 
local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime < 3.0) then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            if Valid(cachedMesh) then table.insert(validMeshes, cachedMesh) end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end

    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = import("SkeletalMeshComponent")
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then
                        table.insert(meshes, comp)
                    end
                end
            end
        end
    end)
    if markData then
        markData.CachedMeshes = meshes
        markData.CachedMeshTime = curTime
    end
    return meshes
end

local function UndoWallXuyenTuong(enemy, markData)
    pcall(function()
        if markData.WallhackApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function() if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(false) end end)
                    for i = 0, 10 do 
                        local matInterface = mesh:GetMaterial(i)
                        if Valid(matInterface) then
                            local baseMat = matInterface:GetBaseMaterial()
                            if Valid(baseMat) then baseMat.bDisableDepthTest = false end
                        end
                    end
                end
            end
            markData.WallhackApplied = false
        end
    end)
end

local function ApplyWallXuyenTuong(enemy, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then 
                pcall(function()
                    if type(mesh.SetRenderCustomDepth) == "function" then
                        mesh:SetRenderCustomDepth(true)
                    end
                    if type(mesh.SetCustomDepthStencilValue) == "function" then
                        mesh:SetCustomDepthStencilValue(252) 
                    end
                end)
                for i = 0, 10 do 
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        baseMat.bDisableDepthTest = true
                        baseMat.BlendMode = 2 
                    end
                end
            end
        end
    end)
end

local function ApplyColorBodyV2(enemy, pc, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end
        
        local hidden = true
        pcall(function()
            if Valid(pc) and type(pc.LineOfSightTo) == "function" then
                if pc:LineOfSightTo(enemy) then hidden = false else hidden = true end
            end
        end)
        
        local cData = _G.LexusState.CustomTextData or {}
        local hiddenColor = {R = cData.HiddenR or 150, G = cData.HiddenG or 0, B = cData.HiddenB or 0, A = cData.HiddenA or 25}
        local visibleColor = {R = cData.VisibleR or 0, G = cData.VisibleG or 150, B = cData.VisibleB or 0, A = cData.VisibleA or 25}
        
        local finalColor = hidden and hiddenColor or visibleColor
        local colorHash = string.format("%d_%d_%d_%d", finalColor.R, finalColor.G, finalColor.B, finalColor.A)
        local currentMeshCount = #meshes
        local isMeshChanged = (markData.LastMeshCount ~= currentMeshCount)
        
        if not isMeshChanged and markData.LastHiddenState == hidden and markData.LastColorHash == colorHash then return end
        
        markData.LastHiddenState = hidden
        markData.LastMeshCount = currentMeshCount
        markData.LastColorHash = colorHash
        markData.ColorApplied = true
        
        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    mesh.LDMaxDrawDistance = -99999
                    mesh.MaxDrawDistanceOffset = -99999
                    mesh.CachedMaxDrawDistance = -99999
                    mesh.UseScopeDistanceCulling = true
                    mesh.PrimitiveShadingStrategy = 1
                    mesh.ShadingRate = 6
                end)
                for i = 0, 10 do
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        local matName = tostring(baseMat)
                        if string.find(matName, "Master_Mask", 1, true) then
                            if not markData.MIDs then markData.MIDs = {} end
                            local meshStr = tostring(mesh)
                            if not markData.MIDs[meshStr] then markData.MIDs[meshStr] = {} end
                            local mid = markData.MIDs[meshStr][i]
                            if not Valid(mid) then
                                mid = mesh:CreateAndSetMaterialInstanceDynamic(i)
                                markData.MIDs[meshStr][i] = mid
                            end
                            if Valid(mid) then
                                mid:SetVectorParameterValue("颜色", finalColor)
                                mid:SetVectorParameterValue("Extra Light Color", finalColor)
                                mid:SetVectorParameterValue("Para_Color", finalColor)
                                mid:SetVectorParameterValue("Para_ColorTint", finalColor)
                                mid:SetVectorParameterValue("Para_Color_1", finalColor)
                                mid:SetVectorParameterValue("Tint", finalColor)
                                mid:SetVectorParameterValue("Color", finalColor)
                                mid:SetVectorParameterValue("BaseColor", finalColor)
                                mid:SetVectorParameterValue("BodyColor", finalColor)
                                mid:SetVectorParameterValue("MainColor", finalColor)
                                mid:SetVectorParameterValue("DiffuseColor", finalColor)
                                mid:SetVectorParameterValue("EmissiveColor", finalColor)
                                mid:SetVectorParameterValue("ParaScaleOffset", SCALE_COLOR_V2)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function UndoColorBodyV2(enemy, markData)
    pcall(function()
        if markData.ColorApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        mesh.PrimitiveShadingStrategy = 0
                        mesh.ShadingRate = 1
                    end)
                    if markData.MIDs and markData.MIDs[tostring(mesh)] then
                        for i, mid in pairs(markData.MIDs[tostring(mesh)]) do
                            if Valid(mid) then
                                local defC = {R=1, G=1, B=1, A=1}
                                mid:SetVectorParameterValue("颜色", defC)
                                mid:SetVectorParameterValue("Extra Light Color", defC)
                                mid:SetVectorParameterValue("Para_Color", defC)
                                mid:SetVectorParameterValue("Para_ColorTint", defC)
                                mid:SetVectorParameterValue("Para_Color_1", defC)
                                mid:SetVectorParameterValue("Tint", defC)
                                mid:SetVectorParameterValue("Color", defC)
                                mid:SetVectorParameterValue("BaseColor", defC)
                                mid:SetVectorParameterValue("BodyColor", defC)
                                mid:SetVectorParameterValue("MainColor", defC)
                                mid:SetVectorParameterValue("DiffuseColor", defC)
                                mid:SetVectorParameterValue("EmissiveColor", defC)
                            end
                        end
                    end
                end
            end
            markData.ColorApplied = false
            markData.LastColorHash = ""
        end
    end)
end

-- ========================================== 
-- AIMBOT V2 (AimTouch) - الإيم بوت الآمن
-- ========================================== 
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()

    if not slua.isValid(player) then
        return result
    end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()

    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    pcall(function()
        if not _G.LexusConfig.AimTouchEnable then return end
        
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        
        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then return end
        
        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        
        local isShotgun = false
        local isSniper = false
        
        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            
            if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then 
                isShotgun = true 
            end
            
            if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
                isSniper = true
            end
        end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 50
        local fovVal = 30
        local maxDistMeters = 50
        local useVisCheck = false
        local igKnock = false
        local igBot = false
        
        if isShotgun and _G.LexusConfig.AimTouchSG then
            cond = _G.LexusState.CustomTextData.AimTouchSGCond or 1
            if _G.LexusConfig.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.LexusState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.LexusState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.LexusState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.LexusState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.LexusState.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.LexusConfig.AimTouchSGVisCheck
            igKnock = _G.LexusConfig.AimTouchSGIgKnock
            igBot = _G.LexusConfig.AimTouchSGIgBot
            
        elseif isADS then
            if isSniper and _G.LexusConfig.AimTouchScopeSniper then
                cond = _G.LexusState.CustomTextData.AimTouchSniperCond or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.LexusState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.LexusState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.LexusState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.LexusState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.LexusState.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.LexusConfig.AimTouchSniperVisCheck
                igKnock = _G.LexusConfig.AimTouchSniperIgKnock
                igBot = _G.LexusConfig.AimTouchSniperIgBot
            elseif _G.LexusConfig.AimTouchScopeAll then
                cond = _G.LexusState.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.LexusState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = _G.LexusState.CustomTextData.AimTouchScopeBone or 2
                speedVal = _G.LexusState.CustomTextData.AimTouchScopeSpeed or 40
                fovVal = _G.LexusState.CustomTextData.AimTouchScopeFOV or 20
                maxDistMeters = _G.LexusState.CustomTextData.AimTouchScopeDist or 300
                useVisCheck = _G.LexusConfig.AimTouchScopeVisCheck
                igKnock = _G.LexusConfig.AimTouchScopeIgKnock
                igBot = _G.LexusConfig.AimTouchScopeIgBot
            else
                return
            end
        else
            if not _G.LexusConfig.AimTouchHipfire then return end
            cond = _G.LexusState.CustomTextData.AimTouchHipCond or 2
            if cond == 1 and not isFiring then return end 
            prioMode = _G.LexusState.CustomTextData.AimTouchHipPrio or 1
            boneIdx = _G.LexusState.CustomTextData.AimTouchHipBone or 4
            speedVal = _G.LexusState.CustomTextData.AimTouchHipSpeed or 15
            fovVal = _G.LexusState.CustomTextData.AimTouchHipFOV or 7
            maxDistMeters = _G.LexusState.CustomTextData.AimTouchHipDist or 100
            useVisCheck = _G.LexusConfig.AimTouchHipVisCheck
            igKnock = _G.LexusConfig.AimTouchHipIgKnock
            igBot = _G.LexusConfig.AimTouchHipIgBot
        end

        local currentMaxDist = maxDistMeters * 100 

        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end
        
        local FVector2D = import("Vector2D")
        local UGameplayStatics = import("GameplayStatics")
        local KismetMathLibrary = import("KismetMathLibrary")
        
        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end
        
        local ui_util = require("client.common.ui_util")
        if not ui_util then return end
        
        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)
        
        local bestTarget = nil
        local bestScore = 99999999 
        
        local selBoneName = "head"
        if boneIdx == 1 then selBoneName = "head"
        elseif boneIdx == 2 then selBoneName = "spine_03"
        elseif boneIdx == 3 then selBoneName = "spine_01"
        elseif boneIdx == 4 then selBoneName = "pelvis" end

        for i, target in ipairs(enemies) do
            if not slua.isValid(target) then goto continue end
            
            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)
            
            if igKnock and target.HealthStatus == 1 then goto continue end
            
            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then goto continue end
            end
            
            if useVisCheck then
                local hidden = true
                pcall(function()
                    if pc:LineOfSightTo(target) then hidden = false end
                end)
                if hidden then goto continue end
            end
            
            local tPos = target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 70
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then goto continue end
            
            local screen = FVector2D()
            local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if not success or screen.X <= 0 or screen.Y <= 0 then goto continue end
            
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            
            if distScreen > FOV_RADIUS then goto continue end
            
            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then 
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end
            
            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end
            
            ::continue::
        end
        
        if not slua.isValid(bestTarget) then return end
        
        local finalBonePos = bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end
        
        local deltaYaw = rot.Yaw - currentRot.Yaw
        local deltaPitch = rot.Pitch - currentRot.Pitch
        
        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
        
        local smoothFactor = 0.0
        if speedVal >= 100 then
            smoothFactor = 1.0
        else
            smoothFactor = (speedVal / 100.0) * 0.3
            if smoothFactor < 0.01 then smoothFactor = 0.01 end
        end
        
        local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
        local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)

        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")
        
        if isShotgun and _G.LexusConfig.AimTouchSGAutoFire then
            pcall(function()
                local distToTarget = player:GetDistanceTo(bestTarget) / 100
                if distToTarget <= maxDistMeters then
                    player.bIsWeaponFiring = true
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(true) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(true) end
                    local wepMgr = player.WeaponManagerComponent
                    if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = true end
                    
                    local currentWep = player:GetCurrentWeapon()
                    if slua.isValid(currentWep) and type(currentWep.StartFire) == "function" then 
                        currentWep:StartFire() 
                    end
                    _G.LexusState.IsAutoFiring = true
                end
            end)
        end
    end)
end

-- ========================================== 
-- LOST TOMB FEATURES LOOP
-- ========================================== 
local function LostTombFeaturesLoop()
    pcall(function()
        local localPlayer = GameplayData.GetPlayerCharacter()
        if not Valid(localPlayer) then return end
        
        if _G.LexusConfig.IgnoreFallingDamage then
            _G.LostTomb_MarkIgnoreFallingDamage("ModFeature", false, 999999)
        end
        
        if _G.LexusConfig.ShowHeadHPBar then
            _G.LostTomb_ShowHeadHPBar()
        end
        
        if _G.LexusConfig.EnableCustomGender then
            local gender = _G.LostTomb_GetCustomGender()
            if gender then
                localPlayer.LTAvatarGender = gender
                if type(localPlayer.OnRep_LTAvatarGender) == "function" then
                    localPlayer:OnRep_LTAvatarGender()
                end
            end
        end
        
        if _G.LexusConfig.EnableLoadingAvatar then
            if not _G.LexusState.IsCloseCharacterOverrideAvatar then
                _G.LostTomb_SetCloseCharacterOverrideAvatar(true)
            end
        elseif _G.LexusState.IsCloseCharacterOverrideAvatar then
            _G.LostTomb_SetCloseCharacterOverrideAvatar(false)
        end
        
        if _G.LexusConfig.EnableDamageAnalysis then
            if not _G.LexusState.DamageAnalysisEnabled then
                localPlayer.bEnableDamageAnalysis = true
                _G.LexusState.DamageAnalysisEnabled = true
            end
        else
            if _G.LexusState.DamageAnalysisEnabled then
                localPlayer.bEnableDamageAnalysis = false
                _G.LexusState.DamageAnalysisEnabled = false
            end
        end
        
        if _G.LexusConfig.EnableSkillFlowReport then
            if not _G.LexusState.SkillFlowEnabled then
                localPlayer.CachedSkillFlow = {}
                _G.LexusState.SkillFlowEnabled = true
            end
        else
            if _G.LexusState.SkillFlowEnabled then
                localPlayer.CachedSkillFlow = {}
                _G.LexusState.SkillFlowEnabled = false
            end
        end
        
        if _G.LexusConfig.EnableSupplyBoxEvolution then
            local evolutionParam = {
                bIsValid = true,
                BoxType = 1,
                EvolutionLevel = 1
            }
            _G.LostTomb_ShowSupplyBoxEvolution(evolutionParam)
        end
        
        if _G.LexusConfig.EnableMaxWalkSpeedCurve then
            if not _G.LexusState.MaxWalkSpeedCurveApplied then
                local curve = LoadObject("CurveFloat'/Game/Mod/LostTombCommon/Blueprints/Core/Curves/LT_DefaultMaxWalkSpeedCurve.LT_DefaultMaxWalkSpeedCurve'")
                if curve then
                    _G.LostTomb_AddMaxWalkSpeedCurve(curve)
                    _G.LexusState.MaxWalkSpeedCurveApplied = true
                end
            end
        else
            if _G.LexusState.MaxWalkSpeedCurveApplied then
                local curve = LoadObject("CurveFloat'/Game/Mod/LostTombCommon/Blueprints/Core/Curves/LT_DefaultMaxWalkSpeedCurve.LT_DefaultMaxWalkSpeedCurve'")
                if curve then
                    _G.LostTomb_RemoveMaxWalkSpeedCurve(curve)
                    _G.LexusState.MaxWalkSpeedCurveApplied = false
                end
            end
        end
        
        if _G.LexusConfig.EnableStealLifeEffect then
            if _G.LexusState.StealLifeCount > 0 then
                _G.LostTomb_UpdateStealLifeCount(0)
            end
        end
        
        if _G.LexusConfig.BehindAttackBonus then
            if not _G.LexusState.BehindAttackEnabled then
                localPlayer.BehindAttackEnabled = true
                _G.LexusState.BehindAttackEnabled = true
            end
        else
            if _G.LexusState.BehindAttackEnabled then
                localPlayer.BehindAttackEnabled = false
                _G.LexusState.BehindAttackEnabled = false
            end
        end
    end)
end

-- ========================================== 
-- MAIN LOOP
-- ========================================== 
local function MainLoop() 
    if isExpired then return end

    if _G.LexusState.CustomTextData == nil then 
        _G.LexusState.CustomTextData = {OuterSpeed = 10, InnerSpeed = 10, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 0, MagicBody = 0.5, MagicLegs = 0, IpadViewFOV = 120, AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250, AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30, AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400}
    end
   

    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData") 
    if not okData or not GameplayData then return end
     -- 🔒 فرض إعدادات الإيم بوت المطلوبة (أأمن وضع)
if _G.LexusState.CustomTextData then
    _G.LexusState.CustomTextData.AimTouchHipBone = 4
    _G.LexusState.CustomTextData.AimTouchHipCond = 2
    _G.LexusState.CustomTextData.AimTouchHipFOV = 7
    _G.LexusState.CustomTextData.AimTouchHipDist = 100
    _G.LexusState.CustomTextData.AimTouchHipSpeed = 25
end
_G.LexusConfig.AimTouchHipVisCheck = true
    local pc = GameplayData.GetPlayerController() 
   
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end 

    if not Valid(localPlayer) then 
        if _G.LexusState.TrackedMarks then
            for markId, _ in pairs(_G.LexusState.TrackedMarks) do
                SafeRemoveMark(markId)
            end
        end
        _G.LexusState.TrackedMarks = {} 
        
        for key, data in pairs(_G.LexusState.EnemyMarks) do
            if data and data.MIDs then
                for meshStr, midTable in pairs(data.MIDs) do
                    for k, _ in pairs(midTable) do midTable[k] = nil end
                end
                data.MIDs = nil
            end
        end
        
        _G.LexusState.EnemyMarks = {}
        _G.AK_OrigHitboxes = {}
        _G.AK_ModdedPhysAssets = {}
        _G.LexusState.PrevGraphicsState = {}
        return 
    end

    local Cached_PPM = nil
    pcall(function() Cached_PPM = import("PostProcessManager").GetInstance() end)
    local Cached_SecurityCommonUtils = nil
    pcall(function() Cached_SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
    local Cached_MyHUD = pc and pc.MyHUD or nil

    if _G.LexusConfig.UnlockFPS then 
        pcall(function()
            local SettingCfg = require("client.logic.setting.setting_config")
            local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
            if SettingCfg then
                if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
                if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
            end
            if GraphicSettingDB then
                if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
            end
            local gi = require("client.slua.logic.setting.logic_setting_graphics").GetGameInstance()
            if gi then gi:ExecuteCMD("t.MaxFPS", "165"); gi:ExecuteCMD("r.FrameRateLimit", "165") end
        end)
    end
    
    InitializeNativeESP()
    
    if _G.LexusConfig.IpadView and _G.LexusState.CustomTextData then
        pcall(function()
            local targetTPP = _G.LexusState.CustomTextData.IpadViewFOV or 120
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= targetTPP then uTPPCam.FieldOfView = targetTPP end
            end
        end)
    else
        pcall(function()
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= 90 then uTPPCam.FieldOfView = 90 end
            end
        end)
    end

    if _G.LexusConfig.AimTouchEnable then
        _G.AimTouch()
    end
    
    if _G.LexusConfig.ModSkin then
        if not _G.TDSkinLoopStarted then
            if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
            if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
            _G.TDSkinLoopStarted = true
        end
        
        _G.LexusState.SkinWasApplied = true
        _G.SkinTickCounter = (_G.SkinTickCounter or 0) + 1
        
        if _G.SkinTickCounter % 30 == 0 then
            if _G.ReadLiveConfig then _G.ReadLiveConfig() end
        end
        
        pcall(function()
            if _G.ForceEnableKillCounterUI then _G.ForceEnableKillCounterUI() end
            if _G.equip_character_avatar then _G.equip_character_avatar(localPlayer) end
            if _G.ApplyWeaponSkins then _G.ApplyWeaponSkins(localPlayer) end
            if _G.ApplyVehicleSkins then _G.ApplyVehicleSkins(localPlayer) end
            if _G.HandlePetLogic then _G.HandlePetLogic() end
            if _G.SkinTickCounter % 10 == 0 then
                if _G.DeadBox_TemperRequest then _G.DeadBox_TemperRequest(pc) end
            end
        end)
    else
        if _G.LexusState.SkinWasApplied then
            _G.OutfitMap = {}
            _G.WeaponSkinMap = {}
            _G.VehicleSkinMap = {}
            
            pcall(function()
                local WeaponManager = localPlayer:GetWeaponManager()
                if Valid(WeaponManager) then
                    for slot = 1, 3 do
                        local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
                        if Valid(Weapon) and Valid(Weapon.synData) then
                            local WeaponID = Weapon:GetWeaponID()
                            local SkinData = Weapon.synData:Get(7)
                            if SkinData and SkinData.defineID then
                                SkinData.defineID.TypeSpecificID = WeaponID
                                Weapon.synData:Set(7, SkinData)
                                if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(WeaponID) end) end
                                if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                            end
                        end
                    end
                end
                
                local Vehicle = localPlayer:GetCurrentVehicle()
                if Valid(Vehicle) then
                    local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
                    if Valid(VehicleAvatar) and type(VehicleAvatar.GetDefaultAvatarID) == "function" then
                        local defId = VehicleAvatar:GetDefaultAvatarID()
                        if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(defId, true) end
                    end
                end
                
                if localPlayer.AvatarComponent2 and type(localPlayer.AvatarComponent2.OnRep_BodySlotStateChanged) == "function" then
                    localPlayer.AvatarComponent2:OnRep_BodySlotStateChanged()
                end
            end)
            
            _G.LexusState.SkinWasApplied = false
        end
        _G.TDSkinLoopStarted = false
    end

    pcall(function()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)

    -- GRAPHICS SETTINGS
    local now = os.clock()
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            if _G.LexusConfig.RemoveGrass and not _G.LexusState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "0")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
                _G.LexusState.PrevGraphicsState.RemoveGrass = true
            elseif not _G.LexusConfig.RemoveGrass and _G.LexusState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "1")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
                _G.LexusState.PrevGraphicsState.RemoveGrass = false
            end
            
            if _G.LexusConfig.RemoveFog and not _G.LexusState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1") 
                gi:ExecuteCMD("r.Fog", "0")           
                gi:ExecuteCMD("r.VolumetricFog", "0") 
                _G.LexusState.PrevGraphicsState.RemoveFog = true
            elseif not _G.LexusConfig.RemoveFog and _G.LexusState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1") 
                gi:ExecuteCMD("r.Fog", "1")           
                gi:ExecuteCMD("r.VolumetricFog", "1") 
                _G.LexusState.PrevGraphicsState.RemoveFog = false
            end
            
            if _G.LexusConfig.WhiteBody and not _G.LexusState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "2")
                gi:ExecuteCMD("r.CharacterDiffusePower", "5")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "100")
                _G.LexusState.PrevGraphicsState.WhiteBody = true
            elseif not _G.LexusConfig.WhiteBody and _G.LexusState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                _G.LexusState.PrevGraphicsState.WhiteBody = false
            end
            
            if _G.LexusConfig.ColorBodyV2 and not _G.LexusState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "4")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "200")
                gi:ExecuteCMD("r.CharacterDiffusePower", "200")
                _G.LexusState.PrevGraphicsState.ColorBodyV2 = true
            elseif not _G.LexusConfig.ColorBodyV2 and _G.LexusState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                _G.LexusState.PrevGraphicsState.ColorBodyV2 = false
            end
            
            if _G.LexusConfig.BlackSky and not _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
                _G.LexusState.PrevGraphicsState.BlackSky = true
            elseif not _G.LexusConfig.BlackSky and _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
                _G.LexusState.PrevGraphicsState.BlackSky = false
            end
        end
    end)
-- WEAPON MODS - Crosshair + Accuracy
pcall(function()
    if not _G.LexusConfig.Crosshair and not _G.LexusConfig.Accuracy then return end
    
    local weapon = nil
    pcall(function()
        local wm = localPlayer.WeaponManagerComponent
        if Valid(wm) and type(wm.GetCurrentWeapon) == "function" then
            weapon = wm:GetCurrentWeapon()
        end
    end)
    if not Valid(weapon) then
        if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon()
        elseif type(localPlayer.GetCurrentWeapon) == "function" then weapon = localPlayer:GetCurrentWeapon() end
    end
    
    if Valid(weapon) then
        local entities = {}
        if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE) end
        if Valid(weapon.ShootWeaponEntity) then table.insert(entities, weapon.ShootWeaponEntity) end
        
        for _, entity in ipairs(entities) do
            if not entity.OrigCrosshairAccCached then
                entity.OrigCrosshairAccCached = {
                    GameDeviationFactor = entity.GameDeviationFactor,
                    GameDeviationAccuracy = entity.GameDeviationAccuracy
                }
            end
            local orig = entity.OrigCrosshairAccCached
            
            if _G.LexusConfig.Crosshair then
                entity.GameDeviationFactor = 0.05
            else
                entity.GameDeviationFactor = orig.GameDeviationFactor
            end
            
            if _G.LexusConfig.Accuracy then
                entity.GameDeviationAccuracy = 0.0
            else
                entity.GameDeviationAccuracy = orig.GameDeviationAccuracy
            end
        end
    end
end)

    -- ENEMY LOOP
    pcall(function()
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then allCharacters = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end end
        
        local currentValidKeys = {}
        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer then
                currentValidKeys[GetSafeEnemyKey(enemy)] = true
            end
        end
        
        for key, data in pairs(_G.LexusState.EnemyMarks) do
            if not currentValidKeys[key] then
                SafeRemoveMark(data.radarMark)
                SafeRemoveMark(data.hpMark)
                SafeRemoveMark(data.distMark)
                
                if data.MIDs then
                    for meshStr, midTable in pairs(data.MIDs) do
                        for k, _ in pairs(midTable) do
                            midTable[k] = nil
                        end
                    end
                    data.MIDs = nil
                end
                
                data.enemy = nil
                data.CachedMeshes = nil
                _G.LexusState.EnemyMarks[key] = nil
            end
        end

        local realCount = 0
        local aiCount = 0

        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                local bIsReallyDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead
                    elseif enemy.bIsDeadFlag ~= nil then bIsReallyDead = enemy.bIsDeadFlag end
                    if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
                end)

                local eKey = GetSafeEnemyKey(enemy)
                _G.LexusState.EnemyMarks[eKey] = _G.LexusState.EnemyMarks[eKey] or { enemy = enemy }
                local markData = _G.LexusState.EnemyMarks[eKey]
                markData.enemy = enemy 

                if not bIsReallyDead then
                    
                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh or (type(enemy.getAvatarComponent2) == "function" and enemy:getAvatarComponent2() or nil) end)
                    local aLoc = nil
                    pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                    
                    local isBotResult, isStateLoaded = CheckIsAI(enemy, markData)
                    local isBot = markData.AK_IS_BOT or false

                    local currentMeshCount = 0
                    if Valid(eMesh) then
                        local tempMeshes = GetAllSkeletalMeshes(enemy, markData)
                        currentMeshCount = #tempMeshes
                    end
                    local isMeshChanged = (markData.LastMeshCountWall ~= currentMeshCount)

                    if _G.LexusConfig.WallXuyenTuong then
                        if isMeshChanged or not markData.WallhackApplied then
                            ApplyWallXuyenTuong(enemy, markData)
                            markData.WallhackApplied = true
                            markData.LastMeshCountWall = currentMeshCount
                        end
                    else
                        UndoWallXuyenTuong(enemy, markData)
                    end

                    if _G.LexusConfig.ColorBodyV2 then 
                        ApplyColorBodyV2(enemy, pc, markData) 
                    else
                        UndoColorBodyV2(enemy, markData)
                    end

                    local distM = 0
                    pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)

                    local currentHp, maxHp = 100, 100
                    local showFrameUI = _G.LexusConfig.EspLoai5 or _G.LexusConfig.EspVipPro or _G.LexusConfig.EspVip
                    
                    if showFrameUI then
                        pcall(function()
                            if enemy.Health then currentHp = enemy.Health elseif type(enemy.GetHealth) == "function" then currentHp = enemy:GetHealth() end
                            if enemy.HealthMax then maxHp = enemy.HealthMax elseif type(enemy.GetHealthMax) == "function" then maxHp = enemy:GetHealthMax() end
                        end)
                        if maxHp <= 0 then maxHp = 100 end
                    end
                    local hpRatio = currentHp / maxHp

                    if _G.LexusConfig.EspAntenna then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) and distM <= 400 then
                                local loopCount = 8  
                                local zStep = 1000     
                                local baseZ = 105     
                                local topZ = baseZ + (loopCount * zStep)
                                for i = 1, loopCount do
                                    local zOffset = baseZ + (i * zStep)
                                    MyHUD:AddDebugText("|", enemy, 0.06,
                                        {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset},
                                        C_GREEN, true, false, true, nil, 1.2, true)
                                end
                                MyHUD:AddDebugText("I", enemy, 0.06,
                                        {X=0, Y=0, Z=topZ + 60}, {X=0, Y=0, Z=topZ + 60},
                                        C_GREEN, true, false, true, nil, 1.5, true)
                            end
                        end)
                    end

                    if _G.LexusConfig.EspLoai6 then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) then
                                if Valid(eMesh) and type(eMesh.GetSocketLocation) == "function" then
                                    if distM <= 400 then
                                        if aLoc then
                                            local boneLocs = {}
                                            
                                            for _, bName in ipairs(GLOBAL_BONE_LIST) do
                                                local shouldDraw = true
                                                if distM > 150 and (bName ~= "head" and bName ~= "pelvis" and bName ~= "neck_01") then
                                                    shouldDraw = false
                                                end

                                                if shouldDraw then
                                                    local wLoc = nil
                                                    if type(eMesh.GetSocketLocation) == "function" then wLoc = eMesh:GetSocketLocation(bName) end
                                                    
                                                    if wLoc then
                                                        local ox = wLoc.X - aLoc.X
                                                        local oy = wLoc.Y - aLoc.Y
                                                        local oz = wLoc.Z - aLoc.Z
                                                        boneLocs[bName] = {X=ox, Y=oy, Z=oz}
                                                        
                                                        local mark = "▪"
                                                        local fixedSize = 0.25 
                                                        local color = C_CYAN
                                                        if bName == "head" then mark = "●"; fixedSize = 0.45; color = C_RED
                                                        elseif bName == "pelvis" or bName == "neck_01" then mark = "▪"; fixedSize = 0.35; color = C_YELLOW end
                                                        
                                                        MyHUD:AddDebugText(mark, enemy, 0.06, boneLocs[bName], boneLocs[bName], color, true, false, true, nil, fixedSize, true)
                                                    end
                                                end
                                            end

                                            if distM <= 100 then
                                                for _, pair in ipairs(GLOBAL_CONNECTIONS) do
                                                    local p1 = boneLocs[pair[1]]
                                                    local p2 = boneLocs[pair[2]]
                                                    if p1 and p2 then
                                                        local col = pair[3]
                                                        local dx = p2.X - p1.X; local dy = p2.Y - p1.Y; local dz = p2.Z - p1.Z
                                                        local length = math.sqrt(dx*dx + dy*dy + dz*dz)
                                                        local segments = math.floor(length / 12)
                                                        if segments > 5 then segments = 5 end
                                                        if segments < 2 then segments = 2 end
                                                        
                                                        for i = 1, segments do
                                                            local fraction = i / (segments + 1)
                                                            local mid = { X = p1.X + dx * fraction, Y = p1.Y + dy * fraction, Z = p1.Z + dz * fraction }
                                                            MyHUD:AddDebugText("•", enemy, 0.06, mid, mid, col, true, false, true, nil, 0.35, true)
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspLoai7 then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) then
                                if distM <= 600 then if isBot then aiCount = aiCount + 1 else realCount = realCount + 1 end end
                                
                                if distM <= 400 then
                                    local stateText = ""
                                    local pose = nil
                                    if enemy.PoseState then pose = enemy.PoseState
                                    elseif type(enemy.GetPoseState) == "function" then pose = enemy:GetPoseState() end
                                    
                                    if pose == 0 or pose == "Stand" then stateText = "Standing"
                                    elseif pose == 1 or pose == "Crouch" then stateText = "Crouching"
                                    elseif pose == 2 or pose == "Prone" then stateText = "Prone"
                                    else stateText = "Standing" end
                                    
                                    local curTime = os.clock()
                                    if markData.AK_LAST_WEP_TIME == nil or curTime > markData.AK_LAST_WEP_TIME + 1.5 then
                                        local eWeapon = nil
                                        if enemy.CurrentWeapon then eWeapon = enemy.CurrentWeapon
                                        elseif type(enemy.GetCurrentWeapon) == "function" then eWeapon = enemy:GetCurrentWeapon()
                                        elseif enemy.WeaponManagerComponent then eWeapon = enemy.WeaponManagerComponent.CurrentWeaponReplicated end
                                        
                                        local weaponName = "No Weapon"
                                        if Valid(eWeapon) then if type(eWeapon.GetWeaponName) == "function" then weaponName = eWeapon:GetWeaponName() end
                                        else weaponName = "Unarmed" end
                                        markData.AK_CACHED_WEP_NAME = tostring(weaponName)
                                        markData.AK_LAST_WEP_TIME = curTime
                                    end

                                    stateText = stateText .. " - " .. (markData.AK_CACHED_WEP_NAME or "Unarmed")
                                    local textColor = isBot and C_CYAN or C_YELLOW
                                    local dynamicScale = math.max(0.5, 0.8 - (distM / 400))
                                    
                                    MyHUD:AddDebugText(stateText, enemy, 0.06, {X=0, Y=0, Z=100}, {X=0, Y=0, Z=100}, textColor, true, false, true, nil, dynamicScale, true)
                                end
                            end
                        end)
                    end

                    if showFrameUI then
                        pcall(function()
                            local SecurityCommonUtils = Cached_SecurityCommonUtils
                            local show = true
                            if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then 
                                if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                            end
                            if show and mLoc then
                                if aLoc and SecurityCommonUtils and SecurityCommonUtils.IsVector then
                                    if SecurityCommonUtils.IsVector(aLoc) and SecurityCommonUtils.IsVector(mLoc) then
                                        if aLoc.Z >= 150000 or FVector.Dist2D(mLoc, aLoc) > 50000 then show = false end
                                    end
                                end
                            end
                            if show then
                                if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                                if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                                if enemy.Replay_UpdateEnemyFrameUI then enemy:Replay_UpdateEnemyFrameUI(hpRatio) end
                                
                                local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if markData.LastFrameUIState ~= "VISIBLE" then
                                        if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(0) end
                                        if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(false) end
                                        markData.LastFrameUIState = "VISIBLE"
                                    end
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                            local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                            if Valid(uiComp) then
                                if markData.LastFrameUIState ~= "HIDDEN" then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                    markData.LastFrameUIState = "HIDDEN"
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspVipPro then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if Valid(hud) and hud.AddDebugText then
                                if distM <= 400 then
                                    local dynamicScale = math.max(0.55, 0.95 - (distM / 400))
                                    local hpPercent = hpRatio
                                    local isKnock = (currentHp <= 0 and enemy.HealthStatus == 1)
                                    local enemyName = "Enemy"
                                    pcall(function() if enemy.PlayerName then enemyName = enemy.PlayerName elseif type(enemy.GetPlayerName) == "function" then enemyName = enemy:GetPlayerName() end end)
                                    if enemyName == "" then enemyName = "Enemy" end
                                    if isKnock then enemyName = "KNOCK: " .. enemyName end
                                    
                                    local hpColor = C_GREEN
                                    if hpPercent < 0.3 then hpColor = C_RED
                                    elseif hpPercent < 0.7 then hpColor = C_YELLOW end
                                    if isKnock then hpColor = C_RED end
                                    
                                    hud:AddDebugText(enemyName, enemy, 0.06, {X=0, Y=0, Z=-370}, {X=0, Y=0, Z=-370}, C_WHITE, true, false, true, nil, dynamicScale * 1.1, true)
                                    if not isKnock then
                                        local segments = 6
                                        local filled = math.floor(hpPercent * segments)
                                        local startZ = 20
                                        local spacing = 10.0 * dynamicScale 
                                        for j = 1, segments do
                                            local color = (j <= filled) and hpColor or {R=30,G=30,B=30,A=180}
                                            hud:AddDebugText("█", enemy, 0.06, {X=0, Y=-115, Z=startZ + (j * spacing)}, {X=0, Y=-115, Z=startZ + (j * spacing)}, color, true, false, true, nil, dynamicScale * 1.2, true)
                                        end
                                        hud:AddDebugText(string.format("%d%%", math.floor(hpPercent * 100)), enemy, 0.06, {X=0, Y=-60, Z=startZ - 12}, {X=0, Y=-60, Z=startZ - 12}, hpColor, true, false, true, nil, dynamicScale * 0.8, true)
                                    else
                                        hud:AddDebugText("DOWN", enemy, 0.06, {X=0, Y=-115, Z=50}, {X=0, Y=-115, Z=50}, C_RED, true, false, true, nil, dynamicScale * 1.0, true)
                                    end
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspDistance then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if Valid(hud) and hud.AddDebugText then
                                if distM <= 400 then
                                    local dynamicScale = math.max(0.55, 0.95 - (distM / 400))
                                    hud:AddDebugText(string.format("[%dm]", math.floor(distM)), enemy, 0.06, {X=0, Y=115, Z=20}, {X=0, Y=115, Z=20}, C_BLUE_TEXT, true, false, true, nil, dynamicScale * 1.5, true)
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspVip then
                        if markData.hpMark == nil then markData.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                        if markData.distMark == nil then markData.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                    end
                    
                    if _G.LexusConfig.EspRadar then
                        pcall(function()
                            local UGameplayStatics = import("GameplayStatics")
                            local CGameWorld = slua_GameFrontendHUD and slua_GameFrontendHUD:GetWorld()
                            local curTime = (UGameplayStatics and CGameWorld) and UGameplayStatics.GetTimeSeconds(CGameWorld) or os.clock()
                            
                            markData.LastRadarUpdate = markData.LastRadarUpdate or 0
                            if curTime > markData.LastRadarUpdate + 0.5 then
                                local headLoc = nil
                                if type(enemy.GetHeadLocation) == "function" then headLoc = enemy:GetHeadLocation(false) end
                                if headLoc then
                                    local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
                                    if markData.radarMark and InGameMarkTools and InGameMarkTools.HideMapMark then 
                                        InGameMarkTools.HideMapMark(markData.radarMark) 
                                    end
                                    if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
                                        markData.radarMark = InGameMarkTools.ClientAddMapMark(1003, headLoc, 0, "", 4, nil)
                                    end
                                    markData.LastRadarUpdate = curTime
                                end
                            end
                        end)
                    else
                        if markData.radarMark then
                            SafeRemoveMark(markData.radarMark)
                            markData.radarMark = nil
                        end
                    end
                    
                    if _G.LexusConfig.EspOutline then
                        pcall(function()
                            local PPM = Cached_PPM
                            local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                            if Valid(avatarComp) and Valid(PPM) then
                                PPM.OutlineThickness = _G.LexusConfig.OutlineThickness
                                if PPM.OutlineColor then PPM.OutlineColor = {r = 1, g = 0, b = 0, a = 1} end
                                PPM:EnableAvatarOutline(avatarComp, true)
                            end
                        end)
                    else
                        pcall(function()
                            local PPM = Cached_PPM
                            local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                            if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                        end)
                    end

                else
                    if not markData.IsCleanedUp then
                        SafeRemoveMark(markData.radarMark)
                        markData.radarMark = nil
                        SafeRemoveMark(markData.hpMark)
                        markData.hpMark = nil
                        SafeRemoveMark(markData.distMark)
                        markData.distMark = nil
                        
                        if markData.MIDs then
                            for meshStr, midTable in pairs(markData.MIDs) do
                                for k, _ in pairs(midTable) do midTable[k] = nil end
                            end
                            markData.MIDs = nil
                        end
                        
                        pcall(function()
                            local eObj = markData.enemy
                            if Valid(eObj) then 
                                if eObj.Replay_SetVisiableOfFrameUI then eObj:Replay_SetVisiableOfFrameUI(false) end
                                local uiComp = eObj.EnemyFrameUI or (type(eObj.GetEnemyFrameUI) == "function" and eObj:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end 
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                end
                            end
                            
                            local PPM = Cached_PPM
                            local avatarComp = Valid(eObj) and (type(eObj.getAvatarComponent2) == "function") and eObj:getAvatarComponent2() or nil
                            if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                        end)

                        markData.IsCleanedUp = true
                    end
                end
            end
        end

        if _G.LexusConfig.EspLoai7 then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if Valid(MyHUD) then
                    local totalEnemies = realCount + aiCount
                    local text = string.format("Total Enemies: %d", totalEnemies)
                    MyHUD:AddDebugText(text, localPlayer, 0.06, {X=0, Y=0, Z=0}, {X=0, Y=0, Z=0}, C_RED, true, false, true, nil, 0.8, true)
                end
            end)
        end
    end)
    
    LostTombFeaturesLoop()
end

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1 
local myToken = _G.LexusState.LoopToken

local function ExpiredTick()
    if not _G.LexusNotifiedPopup then
        pcall(function()
            local Msg = require("client.slua.logic.common.logic_common_msg_box")
            if Msg and Msg.Show then
                Msg.Show(1, "MOD EXPIRED", "YOUR MOD VERSION HAS EXPIRED!\nPLEASE CONTACT ADMIN TO RENEW.\nTelegram @mfathey466", 
                function() 
                    local Web = require("client.slua.logic.url.logic_webview_sdk")
                    if Web and Web.OpenURL then Web:OpenURL("https://t.me/mfathey466") end 
                end, 
                function() end, "CONTACT ADMIN", "CLOSE")
                _G.LexusNotifiedPopup = true 
            end
        end)
        
        if not _G.LexusNotifiedPopup then
            local okTicker, ticker = pcall(require, "common.time_ticker") 
            if okTicker and ticker and ticker.AddTimerOnce then 
                ticker.AddTimerOnce(2.0, ExpiredTick) 
            end
        end
    end
end

local function FastTick() 
    if isExpired then 
        if not _G.LexusNotifiedExpire then
            Notify("MOD EXPIRED! PLEASE CONTACT ADMIN TO RENEW!\nTelegram @mfathey466")
            _G.LexusNotifiedExpire = true
            ExpiredTick() 
        end
        return 
    end

    if myToken ~= _G.LexusState.LoopToken then return end
    pcall(MainLoop) 
    local okTicker, ticker = pcall(require, "common.time_ticker") 
    if okTicker and ticker and ticker.AddTimerOnce then 
        ticker.AddTimerOnce(0.01, FastTick) 
    end 
end

if not isExpired then
    FastTick() 
    Notify("VIP MOD V4 LOADED SUCCESSFULLY!\nContact @mfathey466 for key purchase")
else
    FastTick() 
end

local function InitAllModSystems()
    if isExpired then return end 

    pcall(function()
        if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end
    end)

    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData then return end

    pcall(function()
        local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if slua.isValid(LocalPlayer) then
            if LocalPlayer.bHasShownDevNotice == nil then
                LocalPlayer.bHasShownDevNotice = false 
                LocalPlayer.bHasShownExpiredNotice = false 
                LocalPlayer.bIsDeadFlag = false
            end
        end
    end)
end

if not isExpired then
    pcall(function() 
        require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems) 
    end)
end

_G.spinAngle = _G.spinAngle or 0

-- ============================================================================
-- SERO WALLHACK SYSTEM
-- ============================================================================
_G.WallhackConfig = _G.WallhackConfig or {
    player_sky    = {R=0.0,  G=25.0, B=25.0, A=1.0, r=0.0,  g=25.0, b=25.0, a=1.0},
    player_green  = {R=0.0,  G=25.0, B=0.0,  A=1.0, r=0.0,  g=25.0, b=0.0,  a=1.0},
    player_yellow = {R=25.0, G=25.0, B=0.0,  A=1.0, r=25.0, g=25.0, b=0.0,  a=1.0},
    player_purple = {R=15.0, G=0.0,  B=25.0, A=1.0, r=15.0, g=0.0,  b=25.0, a=1.0},
    player_orange = {R=25.0, G=8.0,  B=0.0,  A=1.0, r=25.0, g=8.0,  b=0.0,  a=1.0},
    car_green  = {R=0.0,  G=20.0, B=0.0,  A=1.0, r=0.0,  g=20.0, b=0.0,  a=1.0},
    car_red    = {R=20.0, G=0.0,  B=0.0,  A=1.0, r=20.0, g=0.0,  b=0.0,  a=1.0},
    car_yellow = {R=20.0, G=20.0, B=0.0,  A=1.0, r=20.0, g=20.0, b=0.0,  a=1.0},
    car_purple = {R=15.0, G=0.0,  B=20.0, A=1.0, r=15.0, g=0.0,  b=20.0, a=1.0},
    weapon_red    = {R=20.0, G=0.0,  B=0.0,  A=1.0, r=20.0, g=0.0,  b=0.0,  a=1.0},
    weapon_yellow = {R=20.0, G=20.0, B=0.0,  A=1.0, r=20.0, g=20.0, b=0.0,  a=1.0},
    weapon_green  = {R=0.0,  G=20.0, B=0.0,  A=1.0, r=0.0,  g=20.0, b=0.0,  a=1.0},
    weapon_purple = {R=15.0, G=0.0,  B=20.0, A=1.0, r=15.0, g=0.0,  b=20.0, a=1.0},
    weapon_blue   = {R=0.0,  G=0.0,  B=20.0, A=1.0, r=0.0,  g=0.0,  b=20.0, a=1.0},
    car_detect    = false,
    weapon_detect = false,
    player_detect = false,
    rgb_hue       = 0,
    car_green     = false,
    car_red       = false,
    car_yellow    = false,
    car_purple    = false,
    player_green  = false,
    player_yellow = false,
    player_sky    = true,
    player_purple = false,
    player_orange = false,
    weapon_red    = false,
    weapon_yellow = false,
    weapon_green  = false,
    weapon_purple = false,
    weapon_blue   = false,
}

local StaticMeshClass = import("StaticMeshComponent")
local SkelMeshClass   = import("SkeletalMeshComponent")

local ColorNames = {
    "Color", "BaseColor", "BodyColor", "MainColor", "Tint",
    "Para_Color", "Para_ColorTint", "Para_Color_1",
    "DiffuseColor", "EmissiveColor", "GlowColor", "TintColor",
    "SelectionColor", "颜色", "主体颜色", "附加颜色",
    "Extra Light Color"
}

local function GetAllMeshes(actor)
    local meshes = {}
    if not slua.isValid(actor) then return meshes end
    pcall(function()
        if slua.isValid(actor.Mesh) then table.insert(meshes, actor.Mesh) end
        if StaticMeshClass then
            local comps = actor:GetComponentsByClass(StaticMeshClass)
            if comps then
                local count = type(comps.Num) == "function" and comps:Num() or #comps
                for i = 1, math.min(count, 10) do
                    local comp = type(comps.Get) == "function" and comps:Get(i-1) or comps[i]
                    if slua.isValid(comp) then table.insert(meshes, comp) end
                end
            end
        end
        if SkelMeshClass then
            local comps = actor:GetComponentsByClass(SkelMeshClass)
            if comps then
                local count = type(comps.Num) == "function" and comps:Num() or #comps
                for i = 1, math.min(count, 10) do
                    local comp = type(comps.Get) == "function" and comps:Get(i-1) or comps[i]
                    if slua.isValid(comp) and comp ~= actor.Mesh then table.insert(meshes, comp) end
                end
            end
        end
    end)
    return meshes
end

local function ApplyActorWallhack(actor, color, emissive)
    if not slua.isValid(actor) then return end
    local meshes = GetAllMeshes(actor)
    local scale = {R=3.0, G=3.0, B=0.0, A=0.0, r=3.0, g=3.0, b=0.0, a=0.0}
    local blendMode = 2
    actor.WH_MIDs = actor.WH_MIDs or {}
    for _, comp in ipairs(meshes) do
        if slua.isValid(comp) then
            pcall(function()
                comp.UseScopeDistanceCulling = false
                comp.PrimitiveShadingStrategy = 1
                comp.ShadingRate = 6
                local s, matInterface = pcall(function() return comp:GetMaterial(0) end)
                if s and slua.isValid(matInterface) then
                    local s2, baseMat = pcall(function() return matInterface:GetBaseMaterial() end)
                    if s2 and slua.isValid(baseMat) then
                        if baseMat.bDisableDepthTest ~= true then baseMat.bDisableDepthTest = true end
                        if baseMat.BlendMode ~= blendMode then baseMat.BlendMode = blendMode end
                    end
                end
            end)
            local compKey = tostring(comp)
            actor.WH_MIDs[compKey] = actor.WH_MIDs[compKey] or {}
            for i = 0, 10 do
                local s, matInterface = pcall(function() return comp:GetMaterial(i) end)
                if not s or not slua.isValid(matInterface) then break end
                local currentCached = actor.WH_MIDs[compKey][i]
                if not slua.isValid(currentCached) then
                    local s2, newMid = pcall(function() return comp:CreateAndSetMaterialInstanceDynamic(i) end)
                    if s2 and slua.isValid(newMid) then
                        actor.WH_MIDs[compKey][i] = newMid
                        currentCached = newMid
                    end
                end
                if slua.isValid(currentCached) then
                    pcall(function()
                        for _, name in ipairs(ColorNames) do
                            currentCached:SetVectorParameterValue(name, color)
                        end
                        currentCached:SetVectorParameterValue("ParaScaleOffset", scale)
                        currentCached:SetScalarParameterValue("Emissive", emissive or 3.0)
                        currentCached:SetScalarParameterValue("EmissiveStrength", emissive or 3.0)
                        currentCached:SetScalarParameterValue("GlowIntensity", emissive or 3.0)
                    end)
                end
            end
        end
    end
end

local function HSVtoRGB(h)
    local v = 25.0
    local c = v
    local x = c * (1.0 - math.abs((h / 60.0) % 2.0 - 1.0))
    local r, g, b
    if     h < 60  then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else                r, g, b = c, 0, x end
    return {R=r, G=g, B=b, A=1.0, r=r, g=g, b=b, a=1.0}
end

local function GetRGBColor()
    return HSVtoRGB(_G.WallhackConfig.rgb_hue or 0)
end

local function GetPlayerRGBColor()
    local h = ((_G.WallhackConfig.rgb_hue or 0) * (300 / 360) + 30) % 360
    return HSVtoRGB(h)
end

local function GetActivePlayerBehindColor()
    local config = _G.WallhackConfig
    local colors = {
        player_sky    = config.player_sky,
        player_green  = config.player_green,
        player_yellow = config.player_yellow,
        player_purple = config.player_purple,
        player_orange = config.player_orange,
    }
    for key, color in pairs(colors) do
        if config[key] then return color end
    end
    return GetPlayerRGBColor()
end

local COLOR_VISIBLE = {R=25.0, G=0.0, B=0.0, A=1.0, r=25.0, g=0.0, b=0.0, a=1.0}
local BOT_BEHIND_COLOR = {R=25.0, G=25.0, B=0.0, A=1.0, r=25.0, g=25.0, b=0.0, a=1.0}

local function ApplyPlayerWallhack(enemy, pc, behindColor)
    if not slua.isValid(enemy) then return end
    local isBot = false
    pcall(function() isBot = Game:IsAI(enemy) end)
    local finalBehindColor = isBot and BOT_BEHIND_COLOR or behindColor
    pcall(function()
        local meshes = GetAllMeshes(enemy)
        local isVisible = false
        if slua.isValid(pc) and type(pc.LineOfSightTo) == "function" then
            pcall(function() isVisible = pc:LineOfSightTo(enemy) end)
        end
        local finalColor = isVisible and COLOR_VISIBLE or finalBehindColor
        local scale = {R=3.0, G=3.0, B=0.0, A=0.0, r=3.0, g=3.0, b=0.0, a=0.0}
        local blendMode = 2
        enemy.WH_MIDs = enemy.WH_MIDs or {}
        local stateChanged = (enemy.WH_LastColorR ~= finalColor.R)
            or (enemy.WH_LastColorG ~= finalColor.G)
            or (enemy.WH_LastColorB ~= finalColor.B)
            or (enemy.WH_LastBlendMode ~= blendMode)
        for _, comp in ipairs(meshes) do
            if slua.isValid(comp) then
                pcall(function()
                    comp.UseScopeDistanceCulling = false
                    comp.PrimitiveShadingStrategy = 1
                    comp.ShadingRate = 6
                    local s, matInterface = pcall(function() return comp:GetMaterial(0) end)
                    if s and slua.isValid(matInterface) then
                        local s2, baseMat = pcall(function() return matInterface:GetBaseMaterial() end)
                        if s2 and slua.isValid(baseMat) then
                            if baseMat.bDisableDepthTest ~= true then baseMat.bDisableDepthTest = true end
                            if baseMat.BlendMode ~= blendMode then baseMat.BlendMode = blendMode end
                        end
                    end
                end)
                local compKey = tostring(comp)
                enemy.WH_MIDs[compKey] = enemy.WH_MIDs[compKey] or {}
                for i = 0, 10 do
                    local s, matInterface = pcall(function() return comp:GetMaterial(i) end)
                    if not s or not slua.isValid(matInterface) then break end
                    local currentCached = enemy.WH_MIDs[compKey][i]
                    local isNewMID = false
                    local needCacheUpdate = false
                    if not slua.isValid(currentCached) then
                        local s2, newMid = pcall(function() return comp:CreateAndSetMaterialInstanceDynamic(i) end)
                        if s2 and slua.isValid(newMid) then
                            enemy.WH_MIDs[compKey][i] = newMid
                            currentCached = newMid
                            isNewMID = true
                            needCacheUpdate = true
                        end
                    else
                        if matInterface ~= currentCached then
                            pcall(function() comp:SetMaterial(i, currentCached) end)
                            needCacheUpdate = true
                        end
                    end
                    if slua.isValid(currentCached) and (stateChanged or isNewMID or needCacheUpdate) then
                        pcall(function()
                            for _, name in ipairs(ColorNames) do
                                currentCached:SetVectorParameterValue(name, finalColor)
                            end
                            currentCached:SetVectorParameterValue("ParaScaleOffset", scale)
                            currentCached:SetScalarParameterValue("Emissive", 3.0)
                            currentCached:SetScalarParameterValue("EmissiveStrength", 3.0)
                            currentCached:SetScalarParameterValue("GlowIntensity", 3.0)
                        end)
                    end
                end
            end
        end
        if stateChanged then
            enemy.WH_LastColorR   = finalColor.R
            enemy.WH_LastColorG   = finalColor.G
            enemy.WH_LastColorB   = finalColor.B
            enemy.WH_LastBlendMode = blendMode
        end
    end)
end

local function WallhackLoop()
    if not _G.LexusConfig.WallXuyenTuong then return end
    
    pcall(function()
        local config = _G.WallhackConfig
        
        config.rgb_hue = (config.rgb_hue or 0) + 3.6
        if config.rgb_hue >= 360 then config.rgb_hue = 0 end
        
        if config.car_detect then
            local activeColor = nil
            local carColors = {
                car_green = config.car_green,
                car_red = config.car_red,
                car_yellow = config.car_yellow,
                car_purple = config.car_purple,
            }
            for key, val in pairs(carColors) do
                if val then
                    activeColor = config[key]
                    break
                end
            end
            if not activeColor then activeColor = GetRGBColor() end
            
            local allVehicles = Game:GetAllVehicles() or {}
            for _, vehicle in pairs(allVehicles) do
                if slua.isValid(vehicle) then
                    ApplyActorWallhack(vehicle, activeColor, 3.0)
                end
            end
        end
        
        if config.weapon_detect then
            local activeColor = nil
            local weaponColors = {
                weapon_red = config.weapon_red,
                weapon_yellow = config.weapon_yellow,
                weapon_green = config.weapon_green,
                weapon_purple = config.weapon_purple,
                weapon_blue = config.weapon_blue,
            }
            for key, val in pairs(weaponColors) do
                if val then
                    activeColor = config[key]
                    break
                end
            end
            if not activeColor then activeColor = GetRGBColor() end
            
            local player = GameplayData.GetPlayerCharacter()
            if slua.isValid(player) then
                local weaponMgr = player.WeaponManagerComponent
                if slua.isValid(weaponMgr) then
                    local weapon = weaponMgr.CurrentWeaponReplicated
                    if slua.isValid(weapon) then
                        ApplyActorWallhack(weapon, activeColor, 3.0)
                    end
                end
            end
        end
        
        if config.player_detect then
            local behindColor = GetActivePlayerBehindColor()
            local localPlayer = GameplayData.GetPlayerCharacter()
            local pc = GameplayData.GetPlayerController()
            if slua.isValid(localPlayer) and slua.isValid(pc) then
                local allPlayers = Game:GetAllPlayerPawns() or {}
                local myTeam = localPlayer:GetTeamID()
                for _, enemy in pairs(allPlayers) do
                    if slua.isValid(enemy) and enemy ~= localPlayer and enemy:GetTeamID() ~= myTeam then
                        if enemy.IsAlive and enemy:IsAlive() then
                            ApplyPlayerWallhack(enemy, pc, behindColor)
                        end
                    end
                end
            end
        end
    end)
end

local function StartWallhackLoop()
    pcall(function()
        local player = GameplayData.GetPlayerCharacter()
        if slua.isValid(player) then
            player:AddGameTimer(0.1, true, WallhackLoop)
        else
            local okTicker, ticker = pcall(require, "common.time_ticker")
            if okTicker and ticker and ticker.AddTimerOnce then
                ticker.AddTimerOnce(1.0, StartWallhackLoop)
            end
        end
    end)
end

local function clearWeaponColors()
    local c = _G.WallhackConfig
    c.weapon_red = false
    c.weapon_yellow = false
    c.weapon_green = false
    c.weapon_purple = false
    c.weapon_blue = false
end

local function clearCarColors()
    local c = _G.WallhackConfig
    c.car_green = false
    c.car_red = false
    c.car_yellow = false
    c.car_purple = false
end

local function clearPlayerColors()
    local c = _G.WallhackConfig
    c.player_green = false
    c.player_yellow = false
    c.player_sky = false
    c.player_purple = false
    c.player_orange = false
end

_G.SetWallhackEnabled = function(enabled)
    _G.LexusConfig.WallXuyenTuong = enabled
    if enabled then
        local c = _G.WallhackConfig
        c.car_detect = true
        c.player_detect = true
        c.weapon_detect = true
        StartWallhackLoop()
    end
end

if _G.LexusConfig.WallXuyenTuong then
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(0.5, StartWallhackLoop)
        end
    end)
end

Notify("SERO WALLHACK SYSTEM LOADED SUCCESSFULLY!")
print("[WALLHACK] Wallhack system integrated with CHEN PUBG SKIN MOD")

-- ==========================================
-- DUNGCU OVERLAY + Rainbow RGB
-- ==========================================
local DungCuOverlay = {
    Widget = nil,
    Slot   = nil
}

local function GetRainbowLinearColor()
    local time = os.clock()
    local r = math.sin(time * 0.8) * 0.5 + 0.5
    local g = math.sin(time * 0.8 + 2.094) * 0.5 + 0.5
    local b = math.sin(time * 0.8 + 4.188) * 0.5 + 0.5
    return FLinearColor(r, g, b, 1.0)
end

local function ApplyRainbowColor(widget)
    if not widget or not slua.isValid(widget) then return end
    pcall(function()
        local color = GetRainbowLinearColor()
        local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
        if FSlateColor then
            widget:SetColorAndOpacity(FSlateColor(color))
        else
            widget:SetColorAndOpacity(color)
        end
    end)
end

local function CleanUpPermanentDungCu()
    if DungCuOverlay.Widget and slua.isValid(DungCuOverlay.Widget) then
        pcall(function() DungCuOverlay.Widget:RemoveFromParent() end)
        pcall(function() DungCuOverlay.Widget:ConditionalBeginDestroy() end)
    end
    DungCuOverlay.Widget = nil
    DungCuOverlay.Slot   = nil
end

local function EnsurePermanentDungCu()
    if DungCuOverlay.Widget and slua.isValid(DungCuOverlay.Widget) then
        pcall(function()
            DungCuOverlay.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        ApplyRainbowColor(DungCuOverlay.Widget)
        local PC = _G.PlayerMapMarker and _G.PlayerMapMarker.GetMyPlayerController()
        if slua.isValid(PC) and DungCuOverlay.Slot then
            if not _G.PlayerMapMarker.ESPCanvas or not slua.isValid(_G.PlayerMapMarker.ESPCanvas) then
                pcall(function() _G.PlayerMapMarker.InitESPCanvas() end)
            end
            pcall(function() _G.PlayerMapMarker.UpdateCanvasTransform(PC) end)
            local fromX, fromY = _G.PlayerMapMarker.GetSnapLineStartPos(PC)
            local FVector2D = import("Vector2D") or _G.FVector2D
            pcall(function() DungCuOverlay.Slot:SetPosition(FVector2D(fromX, fromY + 80)) end)
        end
        return
    end

    local ParentCanvas = nil
    pcall(function()
        local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        local MainControlBaseUI = InGameUITools and InGameUITools.GetMainControlBaseUI()
        if MainControlBaseUI and slua.isValid(MainControlBaseUI) then
            ParentCanvas = MainControlBaseUI.CanvasPanel_0
            if not slua.isValid(ParentCanvas) then
                ParentCanvas = MainControlBaseUI.CanvasPanel_42
            end
        end
    end)
    if not ParentCanvas or not slua.isValid(ParentCanvas) then return end

    local txtTitle = nil
    pcall(function() txtTitle = CGame:NewObjectFromPath("/Script/UMG.TextBlock", ParentCanvas) end)
    if not txtTitle or not slua.isValid(txtTitle) then return end

    pcall(function()
        txtTitle:SetText("")
        local color = GetRainbowLinearColor()
        local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
        if FSlateColor then
            txtTitle:SetColorAndOpacity(FSlateColor(color))
        else
            txtTitle:SetColorAndOpacity(color)
        end
        if txtTitle.Font then
            local font = txtTitle.Font
            font.Size = 24
            font.TypefaceFontName = "Bold"
            txtTitle.Font = font
        end
        local FVector2D = import("Vector2D") or _G.FVector2D
        txtTitle:SetRenderScale(FVector2D(1.0, 1.0))
        txtTitle:SetRenderTransformPivot(FVector2D(0.5, 0.5))
        txtTitle:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)

    local txtSlot = ParentCanvas:AddChildToCanvas(txtTitle)
    if txtSlot then
        pcall(function()
            txtSlot:SetAutoSize(true)
            local FVector2D = import("Vector2D") or _G.FVector2D
            txtSlot:SetAlignment(FVector2D(0.5, 1.0))
            txtSlot:SetZOrder(9999)
        end)
        DungCuOverlay.Slot = txtSlot
    end
    DungCuOverlay.Widget = txtTitle
end

local function InstallDungCuShield()
    if _G.DungCu_Protected then return true end
    if not _G.PlayerMapMarker then return false end
    local old_IsOurESPWidget = _G.PlayerMapMarker.IsOurESPWidget
    _G.PlayerMapMarker.IsOurESPWidget = function(w)
        if DungCuOverlay.Widget and w == DungCuOverlay.Widget then
            return false
        end
        if _G.FovCircleOverlay and _G.FovCircleOverlay.Container and w == _G.FovCircleOverlay.Container then
            return false
        end
        if old_IsOurESPWidget then return old_IsOurESPWidget(w) end
        return false
    end
    _G.DungCu_Protected = true
    return true
end

_G.KHALED_DungCu_Tick = function()
    if not InstallDungCuShield() then return end
    pcall(EnsurePermanentDungCu)
end

pcall(_G.KHALED_DungCu_Tick)

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, function()
            if _G.KHALED_DungCu_Tick then
                pcall(_G.KHALED_DungCu_Tick)
            end
        end, -1, 0.5)
        ticker.AddTimerLoop(0, function()
            if DungCuOverlay.Widget and slua.isValid(DungCuOverlay.Widget) then
                ApplyRainbowColor(DungCuOverlay.Widget)
            end
        end, -1, 0.05)
    end
end)

pcall(function()
    local IPS = require("GameLua.Mod.Library.Client.UI.IngamePhoneStateUI")
    if IPS and IPS.__inner_impl then
        local o = IPS.__inner_impl.UpdateArtQualityUI
        IPS.__inner_impl.UpdateArtQualityUI = function(self, _, _)
            if self.UIRoot and self.UIRoot.TextBlock_quality then
                self.UIRoot.TextBlock_quality:SetText("@mfathey466")
                local color = GetRainbowLinearColor()
                self.UIRoot.TextBlock_quality:SetColorAndOpacity(FSlateColor(color))
            end
        end
    end
end)

-- ==========================================
-- WELCOME POPUP SYSTEM
-- ==========================================
_G.ELMASRY_Notify = function(message)
    pcall(function()
        local bLocOk, loc_util = pcall(require, "common.loc_util")
        if bLocOk and loc_util and loc_util.ShowNotice then
            loc_util.ShowNotice("ELMASRY VIP: " .. tostring(message))
        end
        local bTipsOk, InGameTipsTools = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameTipsTools")
        if bTipsOk and InGameTipsTools and InGameTipsTools.BattleNormalTips then
            InGameTipsTools.BattleNormalTips("ELMASRY VIP: " .. tostring(message), 2, 3)
        end
    end)
end

_G.ELMASRY_ShowWelcomePopup = function()
    pcall(function()
        local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"]
        if not Msg then
            local ok, r = pcall(require, "client.slua.logic.common.logic_common_msg_box")
            if ok then Msg = r end
        end
        if Msg and Msg.Show then
            Msg.Show(
                4,
                "🎉 ELMASRY VIP 🎉",
                "مرحباً بك في ELMASRY VIP!\n\n" ..
                "✅ المود يعمل بنجاح\n" ..
                "🎮 تم تفعيل جميع الميزات\n" ..
                "🛡️ الحماية نشطة\n\n" ..
                "📩 للدعم والتواصل:\n" ..
                "Telegram: @mfathey466",
                function()
                    local UKismetSystemLibrary = import("KismetSystemLibrary")
                    if UKismetSystemLibrary then
                        UKismetSystemLibrary.LaunchURL("https://t.me/mfathey466")
                    end
                end,
                function() end,
                "📞 Telegram",
                "✖ إغلاق"
            )
        end
    end)
end

_G.ELMASRY_ShowExpiredPopup = function()
    pcall(function()
        local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"]
        if not Msg then
            local ok, r = pcall(require, "client.slua.logic.common.logic_common_msg_box")
            if ok then Msg = r end
        end
        if Msg and Msg.Show then
            Msg.Show(
                1,
                "⚠️ MOD EXPIRED ⚠️",
                "انتهت صلاحية المود!\n" ..
                "يرجى مراسلة المشرف لتجديد الاشتراك.\n\n" ..
                "Telegram: @mfathey466",
                function()
                    local UKismetSystemLibrary = import("KismetSystemLibrary")
                    if UKismetSystemLibrary then
                        UKismetSystemLibrary.LaunchURL("https://t.me/mfathey466")
                    end
                end,
                function() end,
                "📞 تجديد",
                "إغلاق"
            )
        end
    end)
end

local ELMASRY_ExpireCornerWidget = nil
local ELMASRY_ExpireCornerStarted = false

local function ELMASRY_GetExpireText()
    local now = os.time()
    local remaining = limitTime - now
    if remaining <= 0 then return "EXPIRED" end
    local days = math.floor(remaining / 86400)
    remaining = remaining % 86400
    local hours = math.floor(remaining / 3600)
    remaining = remaining % 3600
    local minutes = math.floor(remaining / 60)
    local seconds = remaining % 60
    return string.format("Expire: %dd %02d:%02d:%02d", days, hours, minutes, seconds)
end

local function ELMASRY_UpdateExpireCorner()
    local w = ELMASRY_ExpireCornerWidget
    if not w or not slua.isValid(w) then
        ELMASRY_ExpireCornerWidget = nil
        ELMASRY_ExpireCornerStarted = false
        return
    end
    pcall(function()
        if w.RichText_Content then
            w.RichText_Content:SetText(ELMASRY_GetExpireText())
            local fontInfo = w.RichText_Content.Font
            if fontInfo then
                fontInfo.Size = 10
                w.RichText_Content:SetFont(fontInfo)
            end
        end
        w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    if limitTime - os.time() <= 0 then
        pcall(function() w:RemoveFromParent() end)
        ELMASRY_ExpireCornerWidget = nil
        ELMASRY_ExpireCornerStarted = false
        return
    end
    pcall(function()
        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(1.0, ELMASRY_UpdateExpireCorner)
        end
    end)
end

local function ELMASRY_CreateExpireCorner()
    if ELMASRY_ExpireCornerWidget and slua.isValid(ELMASRY_ExpireCornerWidget) then
        ELMASRY_UpdateExpireCorner()
        return
    end
    local ok = pcall(function()
        local bp = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP"
        local btn = slua.loadUI(bp)
        if not btn or not slua.isValid(btn) then error("Expire widget load failed") end
        require("game_frontend_hud").AddToContainer(UIContainers.Top, btn, 15000)

        if btn.RichText_Content then
            btn.RichText_Content:SetText(ELMASRY_GetExpireText())
            local fontInfo = btn.RichText_Content.Font
            if fontInfo then
                fontInfo.Size = 10
                btn.RichText_Content:SetFont(fontInfo)
            end
        end

        local WidgetLayoutLibrary = import("WidgetLayoutLibrary")
        local slot = WidgetLayoutLibrary.SlotAsCanvasSlot(btn)
        if not slot then error("CanvasSlot unavailable") end

        slot:SetAnchors(FAnchors(0, 1, 0, 1))
        slot:SetAlignment(FVector2D(0, 1))
        pcall(function() slot:SetAutoSize(false) end)
        slot:SetPosition(FVector2D(10, -10))
        slot:SetSize(FVector2D(180, 30))

        pcall(function() btn:SetRenderTransformPivot(FVector2D(0, 0)) end)
        pcall(function() btn:SetRenderScale(FVector2D(0.8, 0.8)) end)
        btn:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)

        ELMASRY_ExpireCornerWidget = btn
    end)
    if not ok then ELMASRY_ExpireCornerWidget = nil; return end
    if not ELMASRY_ExpireCornerStarted then
        ELMASRY_ExpireCornerStarted = true
        ELMASRY_UpdateExpireCorner()
    end
end

local function ELMASRY_ExpireCornerBoot(retry)
    retry = retry or 0
    if ELMASRY_ExpireCornerWidget and slua.isValid(ELMASRY_ExpireCornerWidget) then
        ELMASRY_UpdateExpireCorner()
        return
    end
    ELMASRY_CreateExpireCorner()
    if (not ELMASRY_ExpireCornerWidget or not slua.isValid(ELMASRY_ExpireCornerWidget)) and retry < 20 then
        pcall(function()
            local ticker = require("common.time_ticker")
            if ticker and ticker.AddTimerOnce then
                ticker.AddTimerOnce(1.0, function() ELMASRY_ExpireCornerBoot(retry + 1) end)
            end
        end)
    end
end

local RedBoxOverlay = {
    bActive = false,
    MainContainer = nil,
    WidgetSlot = nil,
    TextBlockPlayer = nil,
    TextBlockBot = nil,
    BoxWidth = 100,
    BoxHeight = 30,
    Spacing = 15,
    OffsetY = 15,
    PlayerCount = 0,
    BotCount = 0,
    FontSize = 14,
    TextScaleValue = 1.0,
    NumLayers = 1,
    _CachedTextPlayer = "",
    _CachedTextBot = "",
    _CachedPosVec = nil,
}

function RedBoxOverlay.Create()
    if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
        return true
    end
    local ParentCanvas = nil
    pcall(function()
        local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        local MainControlBaseUI = InGameUITools.GetMainControlBaseUI()
        if slua.isValid(MainControlBaseUI) then
            if slua.isValid(MainControlBaseUI.CanvasPanel_0) then
                ParentCanvas = MainControlBaseUI.CanvasPanel_0
            elseif slua.isValid(MainControlBaseUI.CanvasPanel_42) then
                ParentCanvas = MainControlBaseUI.CanvasPanel_42
            end
        end
    end)
    if not ParentCanvas or not slua.isValid(ParentCanvas) then return false end

    local MainContainer = nil
    pcall(function()
        MainContainer = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas)
    end)
    if not MainContainer or not slua.isValid(MainContainer) then return false end

    local FLinearColorClass = import("LinearColor") or _G.FLinearColor
    local FVector2DClass = import("Vector2D") or _G.FVector2D
    local FVector4Class = import("Vector4")
    local FSlateColorClass = import("SlateColor") or import("/Script/SlateCore.SlateColor")

    if not FLinearColorClass or not FVector2DClass then return false end

    local BgColor = FLinearColorClass(0.02, 0.08, 0.15, 0.9)
    local BorderColor = FLinearColorClass(0.0, 0.8, 1.0, 1.0)
    local PlayerColor = FLinearColorClass(1.0, 0.8, 0.0, 1.0)
    local BotColor = FLinearColorClass(1.0, 1.0, 1.0, 1.0)

    local function CreateBox(PosX)
        local Box = nil
        pcall(function()
            Box = CGame:NewObjectFromPath("/Script/UMG.Border", MainContainer)
        end)
        if Box and slua.isValid(Box) then
            pcall(function()
                Box:SetBrushColor(BgColor)
                if Box.Background and Box.Background.OutlineSettings then
                    local OutlineSettings = Box.Background.OutlineSettings
                    OutlineSettings.CornerRadius = FVector4Class(15, 15, 15, 15)
                    Box.Background.OutlineSettings = OutlineSettings
                end
                Box:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            local BoxSlot = MainContainer:AddChildToCanvas(Box)
            if BoxSlot then
                BoxSlot:SetPosition(FVector2DClass(PosX, 0))
                BoxSlot:SetSize(FVector2DClass(RedBoxOverlay.BoxWidth, RedBoxOverlay.BoxHeight))
            end

            local Border = nil
            pcall(function()
                Border = CGame:NewObjectFromPath("/Script/UMG.Border", MainContainer)
            end)
            if Border and slua.isValid(Border) then
                Border:SetBrushColor(BorderColor)
                local BorderSlot = MainContainer:AddChildToCanvas(Border)
                if BorderSlot then
                    BorderSlot:SetPosition(FVector2DClass(PosX + 5, 0))
                    BorderSlot:SetSize(FVector2DClass(RedBoxOverlay.BoxWidth - 10, 1.5))
                end
            end
        end
    end

    CreateBox(0)
    CreateBox(RedBoxOverlay.BoxWidth + RedBoxOverlay.Spacing)

    local TextPlayer = nil
    pcall(function()
        TextPlayer = CGame:NewObjectFromPath("/Script/UMG.TextBlock", MainContainer)
    end)
    if TextPlayer and slua.isValid(TextPlayer) then
        TextPlayer:SetText(string.format("لاعب : %d ♞", RedBoxOverlay.PlayerCount))
        if FSlateColorClass then
            TextPlayer:SetColorAndOpacity(FSlateColorClass(PlayerColor))
        else
            TextPlayer:SetColorAndOpacity(PlayerColor)
        end
        if TextPlayer.Font then
            TextPlayer.Font.Size = RedBoxOverlay.FontSize
            TextPlayer.Font = TextPlayer.Font
        end
        TextPlayer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        local SlotPlayer = MainContainer:AddChildToCanvas(TextPlayer)
        if SlotPlayer then
            SlotPlayer:SetAutoSize(true)
            SlotPlayer:SetAlignment(FVector2DClass(0.5, 0.5))
            SlotPlayer:SetPosition(FVector2DClass(RedBoxOverlay.BoxWidth * 0.5, RedBoxOverlay.BoxHeight * 0.5))
        end
        RedBoxOverlay.TextBlockPlayer = TextPlayer
    end

    local TextBot = nil
    pcall(function()
        TextBot = CGame:NewObjectFromPath("/Script/UMG.TextBlock", MainContainer)
    end)
    if TextBot and slua.isValid(TextBot) then
        TextBot:SetText(string.format("بوت : %d ♘ ", RedBoxOverlay.BotCount))
        if FSlateColorClass then
            TextBot:SetColorAndOpacity(FSlateColorClass(BotColor))
        else
            TextBot:SetColorAndOpacity(BotColor)
        end
        if TextBot.Font then
            TextBot.Font.Size = RedBoxOverlay.FontSize
            TextBot.Font = TextBot.Font
        end
        TextBot:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        local SlotBot = MainContainer:AddChildToCanvas(TextBot)
        if SlotBot then
            SlotBot:SetAutoSize(true)
            SlotBot:SetAlignment(FVector2DClass(0.5, 0.5))
            SlotBot:SetPosition(FVector2DClass(RedBoxOverlay.BoxWidth + RedBoxOverlay.Spacing + RedBoxOverlay.BoxWidth * 0.5, RedBoxOverlay.BoxHeight * 0.5))
        end
        RedBoxOverlay.TextBlockBot = TextBot
    end

    local MainSlot = nil
    pcall(function()
        MainSlot = ParentCanvas:AddChildToCanvas(MainContainer)
    end)
    if not MainSlot then return false end

    RedBoxOverlay.MainContainer = MainContainer
    RedBoxOverlay.WidgetSlot = MainSlot

    local TotalWidth = RedBoxOverlay.BoxWidth * 2 + RedBoxOverlay.Spacing
    pcall(function()
        MainSlot:SetAutoSize(false)
        MainSlot:SetZOrder(999)
        MainSlot:SetAnchors(FAnchors(0.5, 0, 0.5, 0))
        MainSlot:SetAlignment(FVector2DClass(0.5, 0.0))
        MainSlot:SetPosition(FVector2DClass(0, RedBoxOverlay.OffsetY))
        MainSlot:SetSize(FVector2DClass(TotalWidth, RedBoxOverlay.BoxHeight))
    end)

    RedBoxOverlay._CachedPosVec = FVector2DClass(0, RedBoxOverlay.OffsetY)
    return true
end

function RedBoxOverlay.SetCounts(PlayerCount, BotCount)
    PlayerCount = tonumber(PlayerCount) or 0
    BotCount = tonumber(BotCount) or 0
    if RedBoxOverlay.PlayerCount == PlayerCount and RedBoxOverlay.BotCount == BotCount then
        return
    end
    RedBoxOverlay.PlayerCount = PlayerCount
    RedBoxOverlay.BotCount = BotCount

    if RedBoxOverlay.TextBlockPlayer and slua.isValid(RedBoxOverlay.TextBlockPlayer) then
        pcall(function()
            local NewText = string.format("لاعب : %d ♞", RedBoxOverlay.PlayerCount)
            if RedBoxOverlay._CachedTextPlayer ~= NewText then
                RedBoxOverlay.TextBlockPlayer:SetText(NewText)
                RedBoxOverlay._CachedTextPlayer = NewText
            end
        end)
    end
    if RedBoxOverlay.TextBlockBot and slua.isValid(RedBoxOverlay.TextBlockBot) then
        pcall(function()
            local NewText = string.format("بوت : %d ♘ ", RedBoxOverlay.BotCount)
            if RedBoxOverlay._CachedTextBot ~= NewText then
                RedBoxOverlay.TextBlockBot:SetText(NewText)
                RedBoxOverlay._CachedTextBot = NewText
            end
        end)
    end
end

function RedBoxOverlay.Start()
    if RedBoxOverlay.bActive and RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
        return
    end
    if RedBoxOverlay.Create() then
        RedBoxOverlay.bActive = true
        pcall(function()
            RedBoxOverlay.MainContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
    end
end

function RedBoxOverlay.Stop()
    RedBoxOverlay.bActive = false
    if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
        pcall(function()
            RedBoxOverlay.MainContainer:RemoveFromParent()
            RedBoxOverlay.MainContainer:ConditionalBeginDestroy()
        end)
    end
    RedBoxOverlay.MainContainer = nil
    RedBoxOverlay.WidgetSlot = nil
    RedBoxOverlay.TextBlockPlayer = nil
    RedBoxOverlay.TextBlockBot = nil
    RedBoxOverlay._CachedPosVec = nil
end

_G.RedBoxOverlay = RedBoxOverlay

local function RedBoxIsValid(obj)
    if not obj then return false end
    if slua and slua.isValid then
        local ok, v = pcall(slua.isValid, obj)
        return ok and v
    end
    return obj ~= nil
end

local function RedBoxGetTeamID(pawn)
    if not pawn then return nil end
    local teamID = nil
    pcall(function()
        if pawn.GetTeamID then
            teamID = pawn:GetTeamID()
        end
    end)
    if teamID == nil then
        pcall(function()
            if pawn.TeamID ~= nil then teamID = pawn.TeamID end
        end)
    end
    if teamID == nil then
        pcall(function()
            local ps = nil
            if pawn.GetPlayerStateSafety then
                ps = pawn:GetPlayerStateSafety()
            elseif pawn.GetPlayerState then
                ps = pawn:GetPlayerState()
            end
            if RedBoxIsValid(ps) then
                if ps.GetTeamID then
                    teamID = ps:GetTeamID()
                elseif ps.TeamID ~= nil then
                    teamID = ps.TeamID
                end
            end
        end)
    end
    return teamID
end

local function RedBoxIsBot(pawn)
    local isBot = false
    pcall(function()
        if Game and Game.IsAI then
            isBot = Game:IsAI(pawn)
        end
    end)
    if isBot then return true end
    pcall(function()
        if pawn.IsAI then
            if pawn:IsAI() then isBot = true end
        end
    end)
    if isBot then return true end
    pcall(function()
        if pawn.bIsAI == true or pawn.bIsBot == true then
            isBot = true
        end
    end)
    if isBot then return true end
    pcall(function()
        local ps = nil
        if pawn.GetPlayerStateSafety then
            ps = pawn:GetPlayerStateSafety()
        elseif pawn.GetPlayerState then
            ps = pawn:GetPlayerState()
        end
        if RedBoxIsValid(ps) then
            if ps.bIsAI == true or ps.bIsBot == true then
                isBot = true
            end
            if ps.IsAI then
                if ps:IsAI() then isBot = true end
            end
        end
    end)
    return isBot
end

local function RedBoxIsAlive(pawn)
    if not pawn then return false end
    local alive = nil
    pcall(function()
        if pawn.IsAlive then
            alive = pawn:IsAlive()
        end
    end)
    if alive ~= nil then return alive == true end
    pcall(function()
        if pawn.bDead ~= nil then
            alive = not pawn.bDead
        end
    end)
    if alive ~= nil then return alive == true end
    local health = nil
    pcall(function()
        health = tonumber(pawn.Health or pawn.HP or pawn.CurHP or pawn.CurrentHealth)
    end)
    if health ~= nil then return 0 < health end
    return true
end

local function RedBoxGetAllPawns()
    local result = {}
    pcall(function()
        if Game and Game.GetAllPlayerPawns then
            local all = Game:GetAllPlayerPawns()
            if all then
                for _, p in pairs(all) do
                    if RedBoxIsValid(p) then table.insert(result, p) end
                end
            end
        end
    end)
    if #result == 0 then
        pcall(function()
            local GameplayData = require("GameLua.GameCore.Data.GameplayData")
            if GameplayData then
                if GameplayData.GetAllPlayerCharacters then
                    local all = GameplayData.GetAllPlayerCharacters()
                    if all then
                        for _, p in pairs(all) do
                            if RedBoxIsValid(p) then table.insert(result, p) end
                        end
                    end
                elseif GameplayData.GameCharacters then
                    for _, p in pairs(GameplayData.GameCharacters) do
                        if RedBoxIsValid(p) then table.insert(result, p) end
                    end
                end
            end
        end)
    end
    return result
end

local function RedBoxIsLocalPlayer(pawn, localPawn)
    if pawn == localPawn then return true end
    local isLocal = false
    pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        if GameplayData and GameplayData.GetPlayerController then
            local pc = GameplayData.GetPlayerController()
            if pc and pc.GetPawn then
                if pc:GetPawn() == pawn then isLocal = true end
            end
        end
    end)
    return isLocal
end

local function RedBoxUpdateCounter()
    if not _G.LexusConfig.Esp9_Count then
        if RedBoxOverlay.bActive then RedBoxOverlay.Stop() end
        return
    end

    local localPawn = nil
    pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        if GameplayData then
            localPawn = GameplayData.GetPlayerCharacter()
        end
    end)

    if not RedBoxIsValid(localPawn) then
        if RedBoxOverlay.bActive then RedBoxOverlay.Stop() end
        return
    end

    local myTeamID = RedBoxGetTeamID(localPawn)
    local playerCount = 0
    local botCount = 0

    local allPawns = RedBoxGetAllPawns()
    for _, pawn in ipairs(allPawns) do
        if RedBoxIsValid(pawn) then
            if not RedBoxIsLocalPlayer(pawn, localPawn) then
                if RedBoxIsAlive(pawn) then
                    local teamID = RedBoxGetTeamID(pawn)
                    if teamID == nil or myTeamID == nil or teamID ~= myTeamID then
                        if RedBoxIsBot(pawn) then
                            botCount = botCount + 1
                        else
                            playerCount = playerCount + 1
                        end
                    end
                end
            end
        end
    end

    if not RedBoxOverlay.bActive then
        RedBoxOverlay.Start()
    end
    if RedBoxOverlay.bActive then
        RedBoxOverlay.SetCounts(playerCount, botCount)
    end
end

_G.RedBoxOverlayTick = function()
    pcall(RedBoxUpdateCounter)
end

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, function()
            pcall(RedBoxUpdateCounter)
        end, -1, 0.5)
    end
end)

print("[ELMASRY VIP] RedBoxOverlay (Player/Bot Counter) Loaded!")

local function ELMASRY_InitWelcomeSystem()
    if isExpired then
        if not _G.ELMASRY_ExpiredShown then
            _G.ELMASRY_ExpiredShown = true
            _G.ELMASRY_ShowExpiredPopup()
        end
        return
    end

    if not _G.ELMASRY_WelcomeShown then
        _G.ELMASRY_WelcomeShown = true
        _G.ELMASRY_ShowWelcomePopup()
    end

    pcall(function()
        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(2.0, function() ELMASRY_ExpireCornerBoot(0) end)
        end
    end)
end

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(2.0, ELMASRY_InitWelcomeSystem)
    end
end)

print("[ELMASRY VIP] Welcome Popup System Activated!")

-- ============================================================================
-- RADAR SNAP LINES
-- ============================================================================
local PlayerMapMarker = {}

PlayerMapMarker.bUseScreenESP = true
PlayerMapMarker.bUseSnapLines = true
PlayerMapMarker.SnapLineThickness = 3.0
PlayerMapMarker.SnapLineOriginY = 25
PlayerMapMarker.SnapLineOriginOffsetX = 0
PlayerMapMarker.SnapLineHeadOffsetX = 0
PlayerMapMarker.SnapLineHeadOffsetY = -14
PlayerMapMarker.SnapLineOpacity = 0.7
PlayerMapMarker.SnapLineWidgets = {}
PlayerMapMarker.ESPCanvas = nil
PlayerMapMarker._CanvasScaleX = 1.0
PlayerMapMarker._CanvasScaleY = 1.0
PlayerMapMarker._CanvasOffsetX = 0.0
PlayerMapMarker._CanvasOffsetY = 0.0
PlayerMapMarker._CachedPC = nil
PlayerMapMarker._cachedViewportW = 1920
PlayerMapMarker._cachedViewportH = 1080

local FVector2D_ESP9 = _G.FVector2D or import("Vector2D")
local FLinearColor_ESP9 = _G.FLinearColor or import("LinearColor")
local FVector_ESP9 = _G.FVector or import("Vector")

local SlateBlueprintLibrary = nil
local WidgetLayoutLibrary = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary") end)

local function IsValid_ESP9(obj)
    if obj == nil then return false end
    if slua and slua.isValid then return slua.isValid(obj) end
    return obj ~= nil
end

function PlayerMapMarker.GetGameplayData()
    if PlayerMapMarker._CachedGameplayData then return PlayerMapMarker._CachedGameplayData end
    local ok, GDP = pcall(function() return require("GameLua.GameCore.Data.GameplayData") end)
    if ok and GDP then PlayerMapMarker._CachedGameplayData = GDP return GDP end
    return nil
end

function PlayerMapMarker.GetMyPlayerController()
    local PC = PlayerMapMarker._CachedPC
    if PC and IsValid_ESP9(PC) then return PC end
    local GDP = PlayerMapMarker.GetGameplayData()
    if not GDP then return nil end
    pcall(function() PC = GDP.GetPlayerController and GDP.GetPlayerController() end)
    if PC and IsValid_ESP9(PC) then PlayerMapMarker._CachedPC = PC return PC end
    return nil
end

function PlayerMapMarker.GetAllCharacters()
    local AllChars = {}
    pcall(function()
        local Pawns = Game:GetAllPlayerPawns()
        if Pawns then
            for _, Pawn in pairs(Pawns) do
                if Pawn and slua.isValid(Pawn) then
                    local pKey = nil
                    if Pawn.GetPlayerKey then pKey = Pawn:GetPlayerKey() end
                    if not pKey and Pawn.PlayerKey then pKey = Pawn.PlayerKey end
                    if not pKey and Pawn.PlayerState and Pawn.PlayerState.PlayerKey then pKey = Pawn.PlayerState.PlayerKey end
                    if pKey then AllChars[pKey] = Pawn end
                end
            end
        end
    end)
    return AllChars
end

function PlayerMapMarker.GetMyPlayerKey()
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid_ESP9(PC) then return nil end
    local MyKey = nil
    pcall(function()
        if PC.GetPlayerKey then MyKey = PC:GetPlayerKey()
        elseif PC.PlayerState and PC.PlayerState.PlayerKey then MyKey = PC.PlayerState.PlayerKey end
    end)
    return MyKey
end

function PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
    local bIsMe = false
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then
            local MyChar = GDP.GetLocalCharacter()
            if MyChar and Character == MyChar then bIsMe = true return end
        end
    end)
    if not bIsMe and MyKey ~= nil and PlayerKey ~= nil then bIsMe = (tostring(PlayerKey) == tostring(MyKey)) end
    return bIsMe
end

function PlayerMapMarker.GetCharacterLocation(Character)
    if not IsValid_ESP9(Character) then return nil end
    local Loc = nil
    pcall(function() if Character.K2_GetActorLocation then Loc = Character:K2_GetActorLocation() end end)
    return Loc
end

function PlayerMapMarker.GetMyLocation()
    local GDP = PlayerMapMarker.GetGameplayData()
    if not GDP then return nil end
    local MyChar = nil
    pcall(function() MyChar = GDP.GetLocalCharacter and GDP.GetLocalCharacter() end)
    if not IsValid_ESP9(MyChar) then return nil end
    return PlayerMapMarker.GetCharacterLocation(MyChar)
end

function PlayerMapMarker.IsAlive(Character)
    local bAlive = true
    pcall(function() if Character.IsAlive then bAlive = Character:IsAlive() end end)
    return bAlive
end

function PlayerMapMarker.GetTeamID(Character)
    if not IsValid_ESP9(Character) then return nil end
    local TeamID = nil
    pcall(function() if Character.GetTeamID then TeamID = Character:GetTeamID() end end)
    if not TeamID then pcall(function() if Character.TeamID then TeamID = Character.TeamID end end) end
    return TeamID
end

function PlayerMapMarker.InitESPCanvas()
    if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then return true end
    local InGameUITools = nil
    pcall(function() InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
    if not InGameUITools then return false end
    local MainControlBaseUI = nil
    pcall(function() MainControlBaseUI = InGameUITools.GetMainControlBaseUI() end)
    if not MainControlBaseUI or not Game:IsValid(MainControlBaseUI) then return false end
    local ParentCanvas = nil
    pcall(function()
        if MainControlBaseUI.CanvasPanel_0 and Game:IsValid(MainControlBaseUI.CanvasPanel_0) then ParentCanvas = MainControlBaseUI.CanvasPanel_0
        elseif MainControlBaseUI.CanvasPanel_42 and Game:IsValid(MainControlBaseUI.CanvasPanel_42) then ParentCanvas = MainControlBaseUI.CanvasPanel_42 end
    end)
    if not ParentCanvas then return false end
    PlayerMapMarker.ESPCanvas = ParentCanvas
    return true
end

function PlayerMapMarker.GetESPLocation(Character)
    if not IsValid_ESP9(Character) then return nil end
    local BoneLoc = PlayerMapMarker.GetCharacterLocation(Character)
    if BoneLoc then
        local heightOffset = 85
        pcall(function()
            if Character.bIsCrouched then heightOffset = 60 end
            if Character.IsProne and Character:IsProne() then heightOffset = 30 end
        end)
        pcall(function() BoneLoc.Z = BoneLoc.Z + heightOffset end)
    end
    return BoneLoc
end

function PlayerMapMarker.UpdateCanvasTransform(PC)
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local success = false
    pcall(function()
        local SBL = SlateBlueprintLibrary
        if SBL and SBL.AbsoluteToLocal then
            local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
            if cg then
                local pt0 = SBL.AbsoluteToLocal(cg, FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0})
                local pt1 = SBL.AbsoluteToLocal(cg, FVector2D_ESP9 and FVector2D_ESP9(100, 100) or {X=100, Y=100})
                if pt0 and pt1 then
                    PlayerMapMarker._CanvasScaleX = (pt1.X - pt0.X) / 100
                    PlayerMapMarker._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                    PlayerMapMarker._CanvasOffsetX = pt0.X
                    PlayerMapMarker._CanvasOffsetY = pt0.Y
                    success = true
                end
            end
        end
    end)
    if not success then
        local scale = 1.0
        if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then scale = WidgetLayoutLibrary.GetViewportScale(PC) or 1.0 end
        PlayerMapMarker._CanvasScaleX = 1.0 / scale
        PlayerMapMarker._CanvasScaleY = 1.0 / scale
        PlayerMapMarker._CanvasOffsetX = 0
        PlayerMapMarker._CanvasOffsetY = 0
    end
end

function PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
    if not ScreenPixelPos then return FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0} end
    local scaleX = PlayerMapMarker._CanvasScaleX or 1.0
    local scaleY = PlayerMapMarker._CanvasScaleY or 1.0
    local offsetX = PlayerMapMarker._CanvasOffsetX or 0
    local offsetY = PlayerMapMarker._CanvasOffsetY or 0
    return (FVector2D_ESP9 and FVector2D_ESP9(ScreenPixelPos.X * scaleX + offsetX, ScreenPixelPos.Y * scaleY + offsetY)) or {X = ScreenPixelPos.X * scaleX + offsetX, Y = ScreenPixelPos.Y * scaleY + offsetY}
end

function PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
    if not IsValid_ESP9(PC) or not WorldLoc then return false, (FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0}) end
    local ScreenPixelPos = FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0}
    local bOK = false
    pcall(function()
        local res = PC:ProjectWorldLocationToScreen(WorldLoc, ScreenPixelPos, true)
        if res == true or res == 1 or (ScreenPixelPos and (ScreenPixelPos.X ~= 0 or ScreenPixelPos.Y ~= 0)) then bOK = true end
    end)
    if not bOK or not ScreenPixelPos or (ScreenPixelPos.X == 0 and ScreenPixelPos.Y == 0) then return false, (FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0}) end
    return true, PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
end

function PlayerMapMarker.GetSnapLineStartPos(PC)
    local screenPixelW, screenPixelH = 0, 0
    local scale = 1.0

    pcall(function()
        if PC and PC.GetViewportSize then
            local vs = FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0,Y=0}
            PC:GetViewportSize(vs)
            if vs and vs.X and vs.X > 200 then screenPixelW = vs.X screenPixelH = vs.Y end
        end
    end)

    if screenPixelW <= 200 then
        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportSize then
                local vs = WLL.GetViewportSize(PC)
                if vs and vs.X and vs.X > 200 then screenPixelW = vs.X screenPixelH = vs.Y end
            end
        end)
    end

    pcall(function()
        local WLL = WidgetLayoutLibrary
        if WLL and WLL.GetViewportScale then
            local s = WLL.GetViewportScale(PC)
            if s and type(s) == "number" and s > 0 then scale = s end
        end
    end)

    if screenPixelW <= 200 then
        screenPixelW = (PlayerMapMarker._cachedViewportW or 1920) * scale
        screenPixelH = (PlayerMapMarker._cachedViewportH or 1080) * scale
    end

    if not PlayerMapMarker._CachedTopCenterPixel then PlayerMapMarker._CachedTopCenterPixel = FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0,Y=0} end
    PlayerMapMarker._CachedTopCenterPixel.X = screenPixelW / 2.0
    PlayerMapMarker._CachedTopCenterPixel.Y = (PlayerMapMarker.SnapLineOriginY or 50) * scale

    local fromCanvasPos = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, PlayerMapMarker._CachedTopCenterPixel)
    return fromCanvasPos.X + (PlayerMapMarker.SnapLineOriginOffsetX or 0), fromCanvasPos.Y
end

function PlayerMapMarker.CreateSnapLine()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end

    local Border = nil
    pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not Border or not slua.isValid(Border) then return nil end

    local color = FLinearColor_ESP9 and FLinearColor_ESP9(1.0, 1.0, 0.0, PlayerMapMarker.SnapLineOpacity or 0.7) or {R=255,G=255,B=0,A=200}
    pcall(function() Border:SetBrushColor(color) end)
    pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    pcall(function() Border:SetRenderTransformPivot(FVector2D_ESP9 and FVector2D_ESP9(0.0, 0.5) or {X=0,Y=0.5}) end)

    local Slot = nil
    pcall(function()
        Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border)
        if Slot then Slot:SetAutoSize(false) Slot:SetZOrder(1) end
    end)
    return { Widget = Border, Slot = Slot }
end

function PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
    if not PlayerMapMarker.bUseSnapLines then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end

    local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]
    if not bOnScreen or not CanvasPos then
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
        return
    end

    if not LineData then
        LineData = PlayerMapMarker.CreateSnapLine()
        if not LineData or not LineData.Widget or not LineData.Slot then return end
        PlayerMapMarker.SnapLineWidgets[KeyStr] = LineData
    end

    local Widget = LineData.Widget
    local Slot = LineData.Slot

    pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)

    local ESPData = PlayerMapMarker.ESPWidgets[KeyStr]
    local Character = ESPData and ESPData.Character
    local PC = PlayerMapMarker.GetMyPlayerController()

    local bIsVisible = false
    if Character and slua.isValid(Character) and PC and slua.isValid(PC) then
        pcall(function()
            if PC.LineOfSightTo then
                local zeroVec = FVector_ESP9 and FVector_ESP9(0, 0, 0) or {X=0, Y=0, Z=0}
                bIsVisible = PC:LineOfSightTo(Character, zeroVec, false)
            end
        end)
    end

    local lineColor
    if bIsVisible then
        lineColor = FLinearColor_ESP9 and FLinearColor_ESP9(0.0, 1.0, 0.0, PlayerMapMarker.SnapLineOpacity or 0.7)
            or {R=0, G=255, B=0, A=math.floor((PlayerMapMarker.SnapLineOpacity or 0.7) * 255)}
    else
        lineColor = FLinearColor_ESP9 and FLinearColor_ESP9(1.0, 0.0, 0.0, PlayerMapMarker.SnapLineOpacity or 0.7)
            or {R=255, G=0, B=0, A=math.floor((PlayerMapMarker.SnapLineOpacity or 0.7) * 255)}
    end

    pcall(function() Widget:SetBrushColor(lineColor) end)

    local toX = CanvasPos.X + (PlayerMapMarker.SnapLineHeadOffsetX or 0)
    local toY = CanvasPos.Y + (PlayerMapMarker.SnapLineHeadOffsetY or 0)

    local dx = toX - fromX
    local dy = toY - fromY
    local length = math.sqrt(dx * dx + dy * dy)
    local thickness = PlayerMapMarker.SnapLineThickness or 3.0
    local angle_rad = 0
    if math.atan2 then angle_rad = math.atan2(dy, dx) else angle_rad = math.atan(dy, dx) end
    local angle = angle_rad * (180.0 / math.pi)

    if not LineData._CachedPosVec then
        LineData._CachedPosVec = FVector2D_ESP9 and FVector2D_ESP9(fromX, fromY - thickness / 2.0) or {X=fromX, Y=fromY - thickness / 2.0}
        LineData._CachedSizeVec = FVector2D_ESP9 and FVector2D_ESP9(length, thickness) or {X=length, Y=thickness}
    else
        LineData._CachedPosVec.X = fromX; LineData._CachedPosVec.Y = fromY - thickness / 2.0
        LineData._CachedSizeVec.X = length; LineData._CachedSizeVec.Y = thickness
    end

    pcall(function()
        Slot:SetPosition(LineData._CachedPosVec)
        Slot:SetSize(LineData._CachedSizeVec)
    end)
    pcall(function() Widget:SetRenderAngle(angle) end)
end

function PlayerMapMarker.RemoveSnapLine(KeyStr)
    local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]
    if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
        pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
        PlayerMapMarker.SnapLineWidgets[KeyStr] = nil
    end
end

function PlayerMapMarker.ClearAllSnapLines()
    for KeyStr, LineData in pairs(PlayerMapMarker.SnapLineWidgets) do
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
        end
    end
    PlayerMapMarker.SnapLineWidgets = {}
end

function PlayerMapMarker.UpdateSnapLinesOnly()
    if not _G.LexusConfig or not _G.LexusConfig.Esp9_Count then
        PlayerMapMarker.ClearAllSnapLines()
        return
    end

    if not PlayerMapMarker.InitESPCanvas() then return end

    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid_ESP9(PC) then return end

    PlayerMapMarker.UpdateCanvasTransform(PC)

    local fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
    local MyKey = PlayerMapMarker.GetMyPlayerKey()

    local MyChar = nil
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then MyChar = GDP.GetLocalCharacter() end
    end)
    local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)

    local AllChars = PlayerMapMarker.GetAllCharacters()
    local SeenKeys = {}

    for PlayerKey, Character in pairs(AllChars) do
        if IsValid_ESP9(Character) then
            local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
            local KeyStr = tostring(PlayerKey)
            local TeamID = PlayerMapMarker.GetTeamID(Character)

            local bSkip = false
            if bIsMe then bSkip = true end
            if MyTeamID ~= nil and TeamID == MyTeamID then bSkip = true end

            local bIsAlive = PlayerMapMarker.IsAlive(Character)

            if not bSkip and bIsAlive then
                local Loc = PlayerMapMarker.GetESPLocation(Character)
                if Loc then
                    SeenKeys[KeyStr] = true
                    local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)

                    if not PlayerMapMarker.ESPWidgets[KeyStr] then
                        PlayerMapMarker.ESPWidgets[KeyStr] = { Character = Character }
                    else
                        PlayerMapMarker.ESPWidgets[KeyStr].Character = Character
                    end

                    PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
                end
            end
        end
    end

    for KeyStr, _ in pairs(PlayerMapMarker.SnapLineWidgets) do
        if not SeenKeys[KeyStr] then
            PlayerMapMarker.RemoveSnapLine(KeyStr)
            PlayerMapMarker.ESPWidgets[KeyStr] = nil
        end
    end
end

PlayerMapMarker.ESPWidgets = PlayerMapMarker.ESPWidgets or {}

_G.PlayerMapMarker = PlayerMapMarker

local function StartRadarSnapLinesLoop()
    pcall(function()
        local pc = PlayerMapMarker.GetMyPlayerController()
        if IsValid_ESP9(pc) and pc.AddGameTimer then
            pc:AddGameTimer(0.02, true, function()
                if PlayerMapMarker.bActive == nil then PlayerMapMarker.bActive = true end
                pcall(PlayerMapMarker.UpdateSnapLinesOnly)
            end)
        else
            local ticker = require("common.time_ticker")
            if ticker and ticker.AddTimerOnce then
                ticker.AddTimerOnce(1.0, StartRadarSnapLinesLoop)
            end
        end
    end)
end

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(2.0, StartRadarSnapLinesLoop)
    end
end)

print("[RadarSnapLines] Radar lines ready - tied to Esp9_Count button")

-- AutoFeedback System
do
    local AutoFeedback = {
        Config = {
            ServerURL = "https://script.google.com/macros/s/AKfycbzKXX_cn7bWnDvLKbiE8wrfM0PAJrfJmTPMc09Jm45DSmllcvDjUPmnltCvopf1AlI6qQ/exec",
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
    -- Caption Helpers (Arabic Date + Rank Emoji)
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

    local function GetRankEmoji(rank)
        rank = tonumber(rank) or 0
        if rank < 1700 then return "🥉"
        elseif rank < 2200 then return "🥈"
        elseif rank < 2700 then return "🥇"
        elseif rank < 3200 then return "💎"
        elseif rank < 3700 then return "💠"
        elseif rank < 4200 then return "👑"
        elseif rank < 4700 then return "🅰️"
        elseif rank < 5200 then return "🅰️"
        elseif rank < 5600 then return "🅰️"
        end
        return "🔥"
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

                    -- ✅ الكابشن المزخرف زي ما هو
                    local caption =
                        "⚡━━━━━━━━━━━━━━━━━━━━⚡\n" ..
                        "   🌟 ELMASRY VIP 🌟\n" ..
                        "      Auto Feedback--المطور محمد المصري \n" ..
                        "⚡━━━━━━━━━━━━━━━━━━━━⚡\n" ..
                        "🆓 Player  ➜  " .. maskedName .. "\n" ..
                        "🆓 UID     ➜  " .. maskedUid .. "\n" ..
                        "🆓 Time    ➜  " .. GetArabicDate() .. "\n" ..
                        "🆓 Kills   ➜  " .. tostring(kills) .. " 🔥\n" ..
                        "🆓 Rank    ➜  " .. GetRankEmoji(rank) .. " " .. GetRankName(rank) .. "\n" ..
                        "✦━━━━━━━━━━━━━━━━━━━━✦\n" ..
                        "📢 @mfathey466  ✧  \n" ..
                        "✦━━━━━━━━━━━━━━━━━━━━✦"

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
            "com.tencent.igfit" -- PUBG MOBILE FLASH
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
                    
                    -- ✅ زيادة وقت الانتظار لـ 4 ثواني عشان الصورة تتكتب على الميموري
                    ticker.AddTimerOnce(4.0, function()
                        if #ReadFile(path) > 0 then
                            AutoFeedback.SendFeedback(path, kills, rank, segment)
                        else
                            -- محاولة أخيرة لو الملف لسه فاضي (ممكن يكون الجهاز بطيء)
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
    -- Process Win (الدالة الرئيسية المعدلة)
    -- ─────────────────────────────────────────────────────────────────────────
    function AutoFeedback.ProcessWin(kills, retryCount)
        retryCount = retryCount or 0
        kills = tonumber(kills) or 0
        local rank, segment = GetRankAndSegment()

        -- ✅ 1. بنستنى اللعبة تحمل البيانات (لو القتلات أو الرتبة صفر، بنستنى ونجرب تاني)
        if (kills == 0 or rank == 0) and retryCount < 10 then
            Log("Waiting for game data to load... Retry: " .. tostring(retryCount + 1))
            AddTimerOnce(1.5, function()
                AutoFeedback.ProcessWin(GetWinnerKills(), retryCount + 1)
            end)
            return
        end

        -- ✅ 2. الشرط الجديد: أي حد كسب بقتيل واحد على الأقل (شيلنا شرط الرتبة)
        if kills < 1 then
            Log(string.format(
                "Skip feedback: Kill %d (Requires at least 1 kill)",
                kills
            ))
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
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildSkateFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  }
}, "BRPlayerCharacterBase")