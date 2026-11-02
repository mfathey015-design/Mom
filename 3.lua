local ModCredit = "UltimateEngine"
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
local IsValid = function(obj) return obj ~= nil and slua ~= nil and slua.isValid ~= nil and slua.isValid(obj) end
local ESP_Enabled = true
local FVector2D = _G.FVector2D or import("Vector2D")
local FLinearColor = _G.FLinearColor or import("LinearColor")
local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
local SlateBlueprintLibrary = nil
local WidgetLayoutLibrary = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)
_G.PlayerMapMarker = _G.PlayerMapMarker or {}

-- ========================================================================
-- 🎉 ELMASRY VIP WELCOME POPUP SYSTEM
-- ========================================================================
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

-- ========================================================================
-- EXPIRY SYSTEM
-- ========================================================================
local EXPIRY_TIMESTAMP = os.time({ year = 2026, month = 11, day = 15, hour = 12, min = 0, sec = 0 })

function CheckExpiration()
    local remaining = EXPIRY_TIMESTAMP - os.time()
    if remaining <= 0 then _G._MOD_EXPIRED = true; return false end
    _G._MOD_EXPIRED = false
    _G._MOD_REMAINING_SECONDS = remaining
    return true
end

function _G.TryShowWelcome()
    if _G.WelcomeShown then return end
    if not CheckExpiration() then
        _G.ELMASRY_ShowExpiredPopup()
        _G.WelcomeShown = true
        return
    end
    _G.ELMASRY_ShowWelcomePopup()
    _G.WelcomeShown = true
end

CheckExpiration()

-- ========================================================================
-- ⚡ ULTIMATE BYPASS SYSTEM - 28 LAYERS
-- ========================================================================
_G._BypassActive = true
_G._Bypass_Initialized = false

local _BC = { _t = os.time, _r = math.random }
local function _AntiFingerprint() local _ = _BC._r(100, 500) end
local _origRequire = require
_G.require = function(mod) local ok, r = pcall(_origRequire, mod); return ok and r or nil end

local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
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
        if slua_serialize then
            slua_serialize.check = retTrue
            slua_serialize.verify = retTrue
        end
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
            console.ExecuteConsoleCommand(nil, "r.EnableDrawDyeingColor 1")
            console.ExecuteConsoleCommand(nil, "r.CustomDepth 3")
            console.ExecuteConsoleCommand(nil, "r.IdeaOutline.Enable 1")
            console.ExecuteConsoleCommand(nil, "r.Highlight.Enable 1")
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
            FileHashChecker.CheckFileMD5 = retTrue
            FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            TssSdk.GetFileMD5 = function() return "BYPASS" end
            TssSdk.VerifyFileSignature = retTrue
        end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then
            STExtra.CheckMD5 = retTrue
            STExtra.GetMD5 = function() return "BYPASS" end
            STExtra.VerifyFile = retTrue
        end
    end)
end

local function InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then
            ptlog.ReportEvent = nop
            ptlog.ReportDownloadResult = nop
            ptlog.ReportODPTDError = nop
            ptlog.ReportSkinError = nop
        end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = retFalse
            AvatarUtils.IsValidAvatar = retTrue
            AvatarUtils.CheckAvatarIntegrity = retTrue
            AvatarUtils.ReportInvalidAvatar = nop
        end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then
            sub.StartCheck = nop
            sub.ReportAbnormalFile = nop
            sub.StopCheck = nop
        end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then
            eqEx.Report = nop
            eqEx.SendException = nop
        end
    end)
end

local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then
            SMTD.MTDePicture = function() return "" end
            SMTD.ReMTDePicture = function() return "" end
            SMTD.HasCaptured = retTrue
            SMTD.TakeScreenshot = nop
        end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then
            TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop
            TLog.Report = nop; TLog.Send = nop; TLog.Flush = nop
        end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then
            CrashSight.ReportException = nop; CrashSight.SetCustomData = nop
            CrashSight.Log = nop; CrashSight.SendCrash = nop; CrashSight.ReportUserException = nop
        end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GRUtils then
            GRUtils.BugglyPostExceptionFull = retFalse
            GRUtils.CheckCanBugglyPostException = retFalse
            GRUtils.ReplayReportData = nop
            GRUtils.ReportGameException = nop
            GRUtils.PostException = nop
        end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then
            CTR.SendReport = nop; CTR.SendException = nop; CTR.UploadLog = nop
        end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "FacebookAnalytics", "GameAnalytics"}) do
            local s = _G[sdk]
            if s then
                s.logEvent = nop; s.trackEvent = nop; s.setEnabled = retFalse
                s.sendEvent = nop; s.report = nop
            end
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
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then
                            pcall(function() sub[k] = nop end)
                        end
                    end
                    if sub.ReportPingDelayTimer then
                        sub:RemoveGameTimer(sub.ReportPingDelayTimer)
                        sub.ReportPingDelayTimer = nil
                    end
                    sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then
            AvaEx.CheckAvatarException = nop
            AvaEx.CheckAvatarExceptionOnce = nop
            AvaEx.ReportAvatarException = nop
            AvaEx.CheckSlotMeshVisible = retFalse
            AvaEx.CheckPawnVisible = retFalse
            AvaEx.CheckCanBugglyPostException = retFalse
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local origData = TssSdk.OnRecvData
            TssSdk.OnRecvData = function(data)
                if type(data) == "string" and (data:find("report", 1, true) or data:find("exception", 1, true) or data:find("cheat", 1, true) or data:find("violation", 1, true) or data:find("hack", 1, true) or data:find("verify", 1, true)) then return end
                if origData then origData(data) end
            end
            TssSdk.SendReportInfo = nop; TssSdk.ScanMemory = retTrue; TssSdk.IsEmulator = retFalse
            TssSdk.GetTssSdkReportInfo = retEmptyString; TssSdk.CheckEnvironment = retTrue; TssSdk.VerifyProcess = retTrue
        end
    end)
end

local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({"GameReportSubsystem", "ReplaySubsystem"}) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then
                            pcall(function() sub[k] = nop end)
                        end
                    end
                end
            end
        end
        local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logRep then
            logRep.ReportReplay = nop; logRep.SendReportReq = nop; logRep.UploadReplay = nop
        end
    end)
end

local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "ReportEquipmentFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow", "ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do
            if _G[f] then _G[f] = nop end
            if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end
        end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}) do
            if _G[f] then _G[f] = retFalse end
            if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end
        end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow", "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow", "IsEnableReportAttackFlow", "IsEnableReportHitFlow", "IsEnableReportCircleFlow"}) do
            if _G[f] then _G[f] = retFalse end
        end
    end)
end

local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector", "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then
                for k, v in pairs(_G[c]) do
                    if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then
                        _G[c][k] = nop
                    end
                end
            end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then
            SecSub.ReportData = nop; SecSub.CheckCheat = retFalse; SecSub.ValidatePlayer = retTrue
            SecSub.CollectData = nop; SecSub.SendToServer = nop
        end
    end)
end

local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData", "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then
                for k, v in pairs(sub) do
                    if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then
                        pcall(function() sub[k] = nop end)
                    end
                end
            end
        end
    end)
end

local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}) do
            if _G[f] then _G[f] = nop end
            if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end
        end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then
            sub.ReportData = nop; sub.SendReport = nop; sub.CollectTelemetry = nop
        end
    end)
end

local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then
            _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop
            _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop
        end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then
            sub.ReportData = nop; sub.SendToServer = nop
            sub.CollectTelemetry = nop; sub.StopCollection = nop
        end
    end)
end

local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then
            sub.ReportException = nop; sub.CheckModifier = retTrue
            sub.ValidateModifier = retTrue; sub.ReportModifierError = nop
        end
    end)
end

local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then
            sub.ReportLocation = nop; sub.SendLocationData = nop; sub.VerifyLocation = retTrue
        end
    end)
end

local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then
            sub.OnShootVerifyFailed = nop; sub.SendVerifyData = nop
            sub.ReportBulletHit = nop; sub.UploadHitInfo = nop; sub.VerifyShot = retTrue
        end
        if _G.BulletHitInfoUploadData then
            _G.BulletHitInfoUploadData.Report = nop
            _G.BulletHitInfoUploadData.Send = nop
            _G.BulletHitInfoUploadData.Upload = nop
        end
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
                ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(packetName, ...)
                if blocked[packetName] then return nil end
                return orig(packetName, ...)
            end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams", "RPC_Server_ReportSimulateCharacterLocation", "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...)
                for _, b in ipairs(blockedRPC) do
                    if rpcName == b then return nil end
                end
                return origRPC(rpcName, ...)
            end
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
            Higgs.GetNetAvatarItemIDs = retEmpty
            Higgs.GetCurWeaponSkinID = retZero
            Higgs.IsMHActive = retFalse
            Higgs.bMHActive = false
            Higgs.bCallPreReplication = false
            if Higgs.BlackList then
                for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end
            end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then
                pc.HiggsBoson.bMHActive = false
                pc.HiggsBoson.bCallPreReplication = false
                if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end
            end
            if pc.HiggsBosonComponent then
                pc.HiggsBosonComponent.bMHActive = false
                pc.HiggsBosonComponent.bCallPreReplication = false
                pc.HiggsBosonComponent:ControlMHActive(0)
            end
        end
    end)
end

local function InitializeAntiCheatHooks()
    pcall(function()
        local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HBC and HBC.StaticShowSecurityAlertInDev then HBC.StaticShowSecurityAlertInDev = nop end
    end)
    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = nop
        _G.AvatarCheckCallback.OnReportItemID = nop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
            if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then
                PlayerController.HiggsBosonComponent:ControlMHActive(0)
                PlayerController.HiggsBosonComponent.bMHActive = false
            end
        end
    end
end

local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]
            if not sub then
                local s, r = pcall(require, path)
                if s and r then sub = r end
            end
            if sub then
                for k, v in pairs(sub) do
                    if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then
                        pcall(function() sub[k] = nop end)
                    end
                end
            end
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
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse
        GC.CheckReportSecAttackFlow = retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1, ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, ["kicked"]=1, ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1, ["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = nop
        GC.OnPlayerActorChannelError = nop
        GC.OnPlayerRPCValidateFailed = nop
        GC.OnPlayerSpectateException = nop
        GC.OnShutdownAfterError = nop
        GC.IsBypassed = true
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
                for k, v in pairs(sub) do
                    if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then
                        pcall(function() sub[k] = nop end)
                    end
                end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

local function InitializeOperationalStatsBypass()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        local OperationalStatsSubsystem = (subMgr and subMgr:Get("OperationalStatsSubsystem")) or _G.OperationalStatsSubsystem
        if OperationalStatsSubsystem then
            OperationalStatsSubsystem.ReportOperationalStats = nop
            OperationalStatsSubsystem.AddOperationalStats = nop
            OperationalStatsSubsystem.HandleTouchBegin = nop
            OperationalStatsSubsystem.HandleTouchEnd = nop
            OperationalStatsSubsystem.OnInit = nop
            OperationalStatsSubsystem.HandleEnterFighting = nop
            OperationalStatsSubsystem.OnBattleResult = nop
            if OperationalStatsSubsystem.TimerHandle then
                pcall(function() OperationalStatsSubsystem:RemoveGameTimer(OperationalStatsSubsystem.TimerHandle) end)
                OperationalStatsSubsystem.TimerHandle = nil
            end
            OperationalStatsSubsystem.StatsData = {}
        end
    end)
end

local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY", "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT", "ENABLE_PERFORMANCE_REPORT"}) do
            if _G[flag] then _G[flag] = false end
        end
        local origReq = require
        local blocked = {"HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem"}
        _G.require = function(m)
            for _, b in ipairs(blocked) do
                if m:find(b) then return {} end
            end
            return origReq(m)
        end
    end)
end

local function InitializeDebugHookRemoval()
    pcall(function()
        if debug then
            if debug.sethook then debug.sethook() end
            if debug.setmetatable then
                local orig_setmt = debug.setmetatable
                debug.setmetatable = function(t, mt)
                    if t == _G then return end
                    return orig_setmt(t, mt)
                end
            end
        end
        if jit then
            pcall(function() jit.off() end)
            pcall(function() if jit.attach then jit.attach(function() end, "bc") end end)
        end
    end)
end

local function InitializeDSStateBanFilter()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        local GC = _G.GameplayCallbacks
        local _origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = string.lower(tostring(State or ""))
            local blocked_states = {"cheatdetected", "banned", "kicked", "suspended", "violationdetected", "integrityfailure", "securityviolation", "hackdetected", "moddetected", "anticheat", "permanentban", "temporaryban", "10yearban", "1dayban", "punished", "penalized", "sanctioned", "restricted", "accountsuspended", "cheatingpenalty", "fairplaybanned"}
            for _, bs in ipairs(blocked_states) do
                if s:find(bs, 1, true) then return end
            end
            if _origState then pcall(_origState, UID, State, bPure, bSafe, Param) end
        end
        local ban_rpcs = {"OnPlayerBanned", "OnPlayerKicked", "OnPlayerSuspended", "OnCheatDetected", "OnViolationDetected", "OnSecurityBan", "OnFairPlayBan", "OnPermanentBan", "OnTemporaryBan", "OnAccountSuspended", "NotifyBanResult", "OnBanNotification", "OnPunishmentApplied", "OnPenaltyApplied", "OnSanctionApplied", "OnPlayerNetConnectionClosed", "OnPlayerActorChannelError", "OnPlayerRPCValidateFailed", "OnShutdownAfterError"}
        for _, rpc in ipairs(ban_rpcs) do GC[rpc] = nop end
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.BanNotificationSubsystem", "GameLua.Mod.BaseMod.Client.Security.PunishmentSubsystem", "GameLua.Mod.BaseMod.Client.Security.FairPlaySubsystem", "GameLua.Mod.BaseMod.Client.AntiCheat.BanProcessSubsystem"}) do
            if not package.loaded[path] then
                package.preload[path] = function()
                    return { OnBanReceived = nop, ProcessBan = nop, NotifyBan = nop, ApplyPunishment = nop, StartBanTimer = nop }
                end
            end
        end
    end)
end

local function InitializeBanPacketAbsorber()
    pcall(function()
        if not NetUtil or not NetUtil.SendPacket then return end
        if NetUtil._BanAbsorberActive then return end
        local orig = NetUtil.SendPacket
        local ban_packets = {["BanPlayer"]=1, ["KickPlayer"]=1, ["SuspendPlayer"]=1, ["NotifyBan"]=1, ["ApplyPunishment"]=1, ["ReportCheatResult"]=1, ["ProcessBanRequest"]=1, ["FairPlayBan"]=1, ["SecurityBan"]=1, ["TemporaryBan"]=1, ["PermanentBan"]=1, ["AccountBan"]=1, ["CheatPenalty"]=1, ["ViolationPenalty"]=1, ["BanNotification"]=1, ["SendBanInfo"]=1, ["BanResultPacket"]=1, ["PunishmentPacket"]=1}
        NetUtil.SendPacket = function(name, ...)
            if ban_packets[name] then return nil end
            return orig(name, ...)
        end
        NetUtil._BanAbsorberActive = true
    end)
end

local function InitializePrintFilter()
    pcall(function()
        if _G._PrintFilterActive then return end
        local orig_print = print
        print = function(...)
            local args = {...}
            for _, v in ipairs(args) do
                local s = tostring(v)
                if s:find("Bypass",1,true) or s:find("BYPASS",1,true) or s:find("Antiban",1,true) or s:find("Anti-Ban",1,true) then return end
            end
            orig_print(...)
        end
        _G._PrintFilterActive = true
    end)
end

local function InitializeMetatableShield()
    pcall(function()
        local orig_mt = getmetatable(_G) or {}
        local orig_index = orig_mt.__index
        orig_mt.__index = function(t, k)
            if k == "_BYPASS_DONE" or k == "_bypass_active" then return nil end
            if orig_index then return orig_index(t, k) end
            return rawget(t, k)
        end
        setmetatable(_G, orig_mt)
    end)
end

local function InitializeSubsystemTimerKiller()
    pcall(function()
        local subMgr
        pcall(function() subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr") end)
        if not subMgr then return end
        local timerSubs = {"CoronaLabSubsystem", "SwiftHawkSubsystem", "BehaviorScoreSubsystem", "ClientDataStatistcsSubsystem", "AFKReportorSubsystem", "AntiCheatSubsystem", "IntegrityCheckSubsystem", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem", "GameReportSubsystem", "TelemetrySubsystem", "OperationalStatsSubsystem", "MD5CheckSubsystem"}
        for _, name in ipairs(timerSubs) do
            pcall(function()
                local sub = subMgr:Get(name)
                if not sub then return end
                for _, field in ipairs({"TimerHandle","timer","heartbeatTimer","reportTimer","scanTimer","checkTimer","uploadTimer","sendTimer","collectTimer","telemetryTimer","statsTimer"}) do
                    if sub[field] then
                        pcall(function() sub:RemoveGameTimer(sub[field]); sub[field] = nil end)
                    end
                end
                if sub.OnInit then sub.OnInit = nop end
                if sub.StartTimer then sub.StartTimer = nop end
                if sub.RestartTimer then sub.RestartTimer = nop end
            end)
        end
    end)
end

function _G.StartUltimateProtection()
    if _G._Bypass_Initialized then return end
    _G._Bypass_Initialized = true
    pcall(function()
        print("[ULTIMATE PROTECTION] Starting 28 layers...")
        InitializeSLUABypass(); InitializeMD5Bypass(); InitializeSkinBypass(); InitializeLogBlocker()
        InitializeScannerBlocker(); InitializeReplayTelemetryBlocker(); InitializeReportFlowBlocker()
        InitializePlayerSecurityBypass(); InitializeClientFlowBypass(); InitializeSwiftHawkBypass()
        InitializeCoronaLabBypass(); InitializeModifierExceptionBypass(); InitializeSimulateCharacterLocationBypass()
        InitializeShootVerificationBypass(); InitializeNetworkPacketBlock(); InitializeHiggsBosonBypass()
        InitializeAntiCheatHooks(); InitializeAntiReport(); InitializeGameplayBypass()
        InitializeKillAllSubsystems(); InitializeOperationalStatsBypass(); InitializeFinalProtection()
        InitializeDebugHookRemoval(); InitializeDSStateBanFilter(); InitializeBanPacketAbsorber()
        InitializePrintFilter(); InitializeMetatableShield(); InitializeSubsystemTimerKiller()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then
                pc.HiggsBoson.bMHActive = false
                pc.HiggsBoson.bCallPreReplication = false
            end
            if pc.HiggsBosonComponent then
                pc.HiggsBosonComponent.bMHActive = false
                pc.HiggsBosonComponent.bCallPreReplication = false
            end
        end
        print("[ULTIMATE PROTECTION] All 28 layers active!")
    end)
end

local function InitializeFakeHWID()
    pcall(function()
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and not _G.FakeHWID_Hooked then
            _G.Original_GetDeviceId = SystemLib.GetDeviceId
            SystemLib.GetDeviceId = function(...)
                if not _G.FakeHWID_String then
                    local chars = "0123456789abcdef"
                    local hwid = ""
                    for i = 1, 32 do hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16)) end
                    _G.FakeHWID_String = hwid
                end
                return _G.FakeHWID_String
            end
            _G.FakeHWID_Hooked = true
        end
    end)
end

local function FastProtectionTick()
    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then
                pc.HiggsBoson.bMHActive = false
                pc.HiggsBoson.bCallPreReplication = false
            end
            if pc.HiggsBosonComponent then
                pc.HiggsBosonComponent.bMHActive = false
                pc.HiggsBosonComponent.bCallPreReplication = false
            end
        end
    end)
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.5, FastProtectionTick)
    end
end

pcall(function()
    _G._BypassActive = true
    _G.StartUltimateProtection()
    InitializeFakeHWID()
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.5, FastProtectionTick)
    end
    print("[ULTIMATE PROTECTION] System ACTIVE - 28 layers auto-loaded")
end)

function CheckProtectionStatus()
    return { BypassActive = _G._BypassActive or false, HiggsBosonDisabled = true, ReportsBlocked = true, HWIDFaked = _G.FakeHWID_Hooked or false, AllLayersActive = _G._Bypass_Initialized or false }
end

-- ========================================================================
-- NTH SETTINGS
-- ========================================================================
_G.NTH_Settings = _G.NTH_Settings or {
    WALLHACK_CHAMS = 1, CHAMS_COLOR_VIS = 4, CHAMS_COLOR_HID = 2,
    AIM_TOUCH = 1, AIM_TOUCH_MUC_TIEU = 1, AIM_TOUCH_VI_TRI_AIM = 1,
    AIM_TOUCH_CHE_DO_BAN = 5, AIM_TOUCH_SPEED = 30,
    AIM_TOUCH_FOV_TAM_TRANG = 8, AIM_TOUCH_FOV_SCOPE = 2,
    AIM_TOUCH_BO_BOT = 0, AIM_TOUCH_BO_KNOCK = 1, AIM_TOUCH_CHECK_VAT_CAN = 1,
    AIM_TOUCH_DU_DOAN_ACTIVE = 1, AIM_TOUCH_DU_DOAN = 50,
    AIM_TOUCH_RECOIL_ACTIVE = 1, AIM_TOUCH_LESS_RECOIL = 30,
    AIM_TOUCH_KHOAN_CACH = 80, AIM_TOUCH_SNIPER_AUTO_DAU = 1,
    FOV_SNIP = 1.5, SPEED_SNIP = 30, DU_DOAN_SNIP = 50,
    AIM_TOUCH_SHOTGUN_AUTO = 0, AIM_TOUCH_SHOTGUN_VI_TRI = 1, AIM_TOUCH_SHOTGUN_VISCHECK = 1,
    FOV_SHOTGUN = 10, SPEED_SHOTGUN = 35,
    AIM_TOUCH_NO = 1, SPEED_NO = 30, DU_DOAN_NO = 0, FOV_NO = 1.5,
    AIMBOT = 1, SPEED_AIMBOT = 0, FOV_AIMBOT = 0,
    THU_TAM = 90, GIAM_GIAT_NGANG = 0, GIAM_GIAT_DOC = 0, GIAM_RUNG_SCOPE = 0,
}
function _G.NTH_GetVal(k) return _G.NTH_Settings[k] or 0 end

-- ========================================================================
-- HELPERS
-- ========================================================================
local function IsEnemyTarget(A, B)
    if not (slua.isValid(A) and slua.isValid(B)) then return false end
    if A == B then return false end
    if A.PlayerKey ~= nil and B.PlayerKey ~= nil and A.PlayerKey == B.PlayerKey then return false end
    local TA, TB = -1, -2
    pcall(function()
        TA = A.TeamID or (A.PlayerState and A.PlayerState.TeamNum) or -1
        TB = B.TeamID or (B.PlayerState and B.PlayerState.TeamNum) or -2
    end)
    return TA ~= TB
end
_G.IsEnemyTarget = IsEnemyTarget

local function MakeLinearColor(R, G, B, A)
    if FLinearColor then return FLinearColor(R, G, B, A) end
    return { R = R, G = G, B = B, A = A, r = R, g = G, b = B, a = A }
end

local ColorPresets = {
    {50, 50, 50, 1}, {50, 0, 0, 1}, {50, 50, 0, 1}, {0, 50, 0, 1},
    {0, 50, 50, 1}, {0, 0, 50, 1}, {50, 0, 50, 1}, {50, 20, 35, 1}, {0, 0, 0, 1}
}
local function GetPresetColor(i)
    local p = ColorPresets[i] or ColorPresets[2]
    return MakeLinearColor(p[1], p[2], p[3], p[4])
end
local function GetVisibleChamsColor() return GetPresetColor(_G.NTH_GetVal("CHAMS_COLOR_VIS") or 1) end
local function GetOccludedChamsColor() return GetPresetColor(_G.NTH_GetVal("CHAMS_COLOR_HID") or 2) end

local function EnableChams(A, V, O)
    if not A or not slua.isValid(A) then return end
    pcall(function() A:SetDrawDyeing(true) end)
    pcall(function() A:SetDrawDyeingMode(1) end)
    pcall(function() A:SetVisibleDyeingColor(V) end)
    pcall(function() A:SetOccludedDyeingColor(O) end)
    pcall(function() A:SetDyeingColorFadeDistance(99999.0) end)
    pcall(function() A:SetDyeingColorMinMaxDistance(0.0, 99999.0) end)
    pcall(function() A:SetDrawHighlight(true) end)
    pcall(function() A:SetRenderCustomDepth(true) end)
    pcall(function() A:SetCustomDepthStencilValue(255) end)
end

local function DisableChams(A)
    if not A or not slua.isValid(A) then return end
    pcall(function() A:SetDrawDyeing(false) end)
    pcall(function() A:SetDrawHighlight(false) end)
    pcall(function() A:SetRenderCustomDepth(false) end)
    pcall(function() A:SetCustomDepthStencilValue(0) end)
end

_G.NTH_BotCache = _G.NTH_BotCache or {}
local function NTH_CheckIsBot(C)
    if not C or not slua.isValid(C) then return false, false end
    local ck = tostring(C)
    if _G.NTH_BotCache[ck] then return _G.NTH_BotCache[ck].n, _G.NTH_BotCache[ck].m end
    local n, m = false, false
    pcall(function()
        if C.bMEnsure == true or (C.MLEnsureStyle and 0 < C.MLEnsureStyle) then m = true end
        if C.EnsureStyle then
            if C.EnsureStyle == 1 or C.EnsureStyle == 2 or C.EnsureStyle == 3 or C.EnsureStyle == 5 then m = true
            elseif C.EnsureStyle == 4 then n = true end
        end
        if C.bEnsure == true or C.bIsAI == true or C.bIsBot == true or C.IsAI == true then n = true end
        if type(C.IsBot) == "function" and C:IsBot() then n = true end
        local ctrl
        if type(C.GetControllerSafety) == "function" then ctrl = C:GetControllerSafety() end
        if not ctrl then ctrl = C.Controller end
        if slua.isValid(ctrl) then
            if ctrl.IsMLAI == true or (type(ctrl.IsMLAIPlayerParam) == "function" and ctrl:IsMLAIPlayerParam()) then m = true end
            if ctrl.FakePlayerBornType == 1 and not ctrl.bForceRecordKillNum then m = true end
            local ap
            if type(ctrl.GetAIParams) == "function" then ap = ctrl:GetAIParams() end
            if not ap then ap = ctrl.AIParams end
            if ap and (ap.bMLAIPlayer == true or ap.bMLDelivery == true or (ap.MLBotType and 0 < ap.MLBotType)) then m = true end
            if ctrl.IsMercenary == true or ctrl.IsAdvancedAI == true then n = true end
        end
        local ps = C.PlayerState
        if not ps and type(C.GetPlayerStateSafety) == "function" then ps = C:GetPlayerStateSafety() end
        if slua.isValid(ps) then
            if ps.bIsMLAI == true then m = true end
            if ps.bPSEnsure == true or ps.bIsABot == true or ps.bIsBot == true or ps.bIsAI == true then n = true end
            if ps.MLAIDisplayUID and 0 < ps.MLAIDisplayUID then m = true end
            if ps.TeammateTakeOverFeature and ps.TeammateTakeOverFeature.bAITakeOver == true then n = true end
            local uid = tonumber(ps.UID) or tonumber(ps.PlayerUID) or 0
            if 44001 <= uid and uid <= 44010 then n = true end
            if type(ps.IsBot) == "function" and ps:IsBot() then n = true end
            if type(ps.IsABot) == "function" and ps:IsABot() then n = true end
        end
    end)
    if m then n = false end
    if n or m then _G.NTH_BotCache[ck] = { n = n, m = m } end
    return n, m
end
_G.NTH_CheckIsBot = NTH_CheckIsBot

-- ========================================================================
-- AIM CURSOR
-- ========================================================================
_G._AimCursorActive = false

_G.ApplySmallAimCursor = function()
    pcall(function()
        local pc = GameplayData.GetPlayerController()
        local ch = GameplayData.GetPlayerCharacter()
        if not slua.isValid(pc) or not slua.isValid(ch) then return end
        local w = ch.GetCurrentWeapon and ch:GetCurrentWeapon()
        if not slua.isValid(w) then return end
        local e = w.ShootWeaponEntity_GEN_VARIABLE or w.ShootWeaponEntity
        if not slua.isValid(e) then return end
        local tt = _G.NTH_GetVal("THU_TAM") / 100.0
        local hn = _G.NTH_GetVal("GIAM_GIAT_NGANG") / 100.0
        local vd = _G.NTH_GetVal("GIAM_GIAT_DOC") / 100.0
        local rs = _G.NTH_GetVal("GIAM_RUNG_SCOPE") / 100.0
        e.GameDeviationFactor = 3.36 - 3.36 * tt
        e.AccessoriesHRecoilFactor = 0.8 - 0.8 * hn
        e.AccessoriesVRecoilFactor = 0.5 - 0.5 * vd
        e.RecoilKickADS = 0.2 - 0.2 * rs
        if _G.NTH_GetVal("AIMBOT") == 1 and e.AutoAimingConfig then
            local ac = e.AutoAimingConfig
            for _, r in ipairs({"OuterRange", "InnerRange"}) do
                local c = ac[r]
                if c then
                    c.Speed = 3.0; c.SpeedRate = 3.0; c.RangeRate = 3.2
                    c.RangeRateSight = 2.2; c.SpeedRateSight = 2.2
                    c.CrouchRate = 3.2; c.ProneRate = 3.0; c.DyingRate = 0
                    c.adsorbMaxRange = 100; c.adsorbMinRange = 30
                    c.adsorbMinAttenuationDis = 150; c.adsorbMaxAttenuationDis = 5000
                    c.adsorbActiveMinRange = 30
                end
            end
            e.AutoAimingConfig = ac
        end
    end)
end

_G.RemoveSmallAimCursor = function()
    pcall(function()
        local pc = GameplayData.GetPlayerController()
        local ch = GameplayData.GetPlayerCharacter()
        if not slua.isValid(pc) or not slua.isValid(ch) then return end
        local w = ch.GetCurrentWeapon and ch:GetCurrentWeapon()
        if not slua.isValid(w) then return end
        local e = w.ShootWeaponEntity_GEN_VARIABLE or w.ShootWeaponEntity
        if not slua.isValid(e) then return end
        e.GameDeviationFactor = 3.36
        e.AccessoriesHRecoilFactor = 0.8
        e.AccessoriesVRecoilFactor = 0.5
        e.RecoilKickADS = 0.2
        if e.AutoAimingConfig then
            local ac = e.AutoAimingConfig
            for _, r in ipairs({"OuterRange", "InnerRange"}) do
                local c = ac[r]
                if c then
                    c.Speed = 4.0; c.SpeedRate = 4.0; c.RangeRate = 4.5
                    c.RangeRateSight = 3.0; c.SpeedRateSight = 3.0
                    c.CrouchRate = 4.5; c.ProneRate = 4.0; c.DyingRate = 0
                    c.adsorbMaxRange = 200; c.adsorbMinRange = 20
                    c.adsorbMinAttenuationDis = 100; c.adsorbMaxAttenuationDis = 8000
                    c.adsorbActiveMinRange = 20
                end
            end
            e.AutoAimingConfig = ac
        end
    end)
end

-- ========================================================================
-- WALLHACK
-- ========================================================================
_G._WallhackActive = false
_G.EnvRequiresUpdate = true

local function RunCmd(name, val)
    pcall(function()
        local KSL = import("KismetSystemLibrary")
        local ctrl = GameplayData.GetPlayerController()
        if slua.isValid(KSL) and slua.isValid(ctrl) then KSL.ExecuteConsoleCommand(ctrl, name .. " " .. val) end
        local gi = slua_GameFrontendHUD and slua_GameFrontendHUD:GetGameInstance()
        if slua.isValid(gi) and gi.ExecuteCMD then gi:ExecuteCMD(name, val) end
    end)
end

local function WallhackLoop()
    if not _G._WallhackActive then return end
    if not CheckExpiration() then return end
    pcall(function()
        if _G.EnvRequiresUpdate then
            _G.EnvRequiresUpdate = false
            if _G.NTH_GetVal("WALLHACK_CHAMS") == 1 then
                RunCmd("r.EnableDrawDyeingColor", "1")
                RunCmd("r.SupportDyeingColorDistanceFade", "1")
                RunCmd("r.SupportDyeingColorMeshProxy", "1")
                RunCmd("r.EnablePrimitiveHighlight", "1")
                RunCmd("r.CustomDepth", "3")
                RunCmd("r.DeviceLevelUseHighLightMode", "1")
                RunCmd("r.Highlight.Enable", "1")
            end
        end
        local on = _G.NTH_GetVal("WALLHACK_CHAMS") == 1
        local me = GameplayData.GetPlayerCharacter()
        if not slua.isValid(me) then return end
        local chars = {}
        if GameplayData.GetAllPlayerCharacters then chars = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then for _, c in pairs(GameplayData.GameCharacters) do table.insert(chars, c) end end
        local myTeam = -1
        pcall(function() myTeam = (type(me.GetTeamID) == "function" and me:GetTeamID()) or me.TeamID or (me.PlayerState and me.PlayerState.TeamNum) or -1 end)
        for _, c in pairs(chars) do
            if slua.isValid(c) and c ~= me then
                local tm = -2
                pcall(function() tm = (type(c.GetTeamID) == "function" and c:GetTeamID()) or c.TeamID or (c.PlayerState and c.PlayerState.TeamNum) or -2 end)
                if tm ~= myTeam then
                    local dead, knock, hp = false, false, 100
                    pcall(function()
                        if type(c.IsNearDeath) == "function" then knock = c:IsNearDeath() elseif c.bIsNearDeath ~= nil then knock = c.bIsNearDeath end
                        if type(c.IsDead) == "function" then dead = c:IsDead() elseif c.bIsDead ~= nil then dead = c.bIsDead elseif c.bIsDeadFlag ~= nil then dead = c.bIsDeadFlag end
                        if c.bHidden or (c.Mesh and c.Mesh.bHidden) then dead = true end
                        if type(c.GetHealth) == "function" then hp = c:GetHealth() elseif c.Health ~= nil then hp = c.Health end
                        if not knock and hp <= 0 then dead = true end
                    end)
                    if not dead then
                        local SMC = import("SkeletalMeshComponent")
                        local meshes = {}
                        if slua.isValid(c.Mesh) then table.insert(meshes, c.Mesh) end
                        if SMC then
                            pcall(function()
                                local comps = c:GetComponentsByClass(SMC)
                                if comps then
                                    local cnt = (type(comps.Num) == "function" and comps:Num()) or #comps
                                    for i = 1, cnt do
                                        local cc = (type(comps.Get) == "function" and comps:Get(i - 1)) or comps[i]
                                        if slua.isValid(cc) and cc ~= c.Mesh then table.insert(meshes, cc) end
                                    end
                                end
                            end)
                        end
                        c.NTH_CachedMeshes = meshes
                        local mc = #meshes
                        local mcChanged = c.LastMeshCountWall ~= mc
                        if on then
                            local vc = GetVisibleChamsColor()
                            local oc = GetOccludedChamsColor()
                            local key = tostring(_G.NTH_GetVal("CHAMS_COLOR_VIS")) .. "_" .. tostring(_G.NTH_GetVal("CHAMS_COLOR_HID"))
                            local hash = "p_" .. key
                            if mcChanged or c.LastAuraHash ~= hash or not c.WallhackApplied then
                                pcall(function()
                                    if mcChanged and c.NTH_AuraMeshes then
                                        for _, m in ipairs(c.NTH_AuraMeshes) do DisableChams(m) end
                                    end
                                    for _, m in ipairs(meshes) do
                                        if slua.isValid(m) then EnableChams(m, vc, oc) end
                                    end
                                    if c.DelayCustomDepth then pcall(function() c:DelayCustomDepth(true) end) end
                                end)
                                c.WallhackApplied = true
                                c.LastAuraHash = hash
                                c.LastMeshCountWall = mc
                                c.NTH_AuraMeshes = meshes
                            end
                        else
                            if c.WallhackApplied then
                                pcall(function()
                                    for _, m in ipairs(c.NTH_AuraMeshes or meshes) do
                                        if slua.isValid(m) then DisableChams(m) end
                                    end
                                end)
                                c.WallhackApplied = false
                                c.NTH_AuraHash = nil
                                c.NTH_AuraMeshes = nil
                                c.LastMeshCountWall = nil
                            end
                        end
                    else
                        if c.WallhackApplied then
                            pcall(function()
                                for _, m in ipairs(c.NTH_AuraMeshes or {}) do
                                    if slua.isValid(m) then DisableChams(m) end
                                end
                            end)
                            c.WallhackApplied = false
                            c.NTH_AuraMeshes = nil
                        end
                    end
                end
            end
        end
    end)
end

-- ========================================================================
-- AIM TOUCH SYSTEM
-- ========================================================================
function _G.InitializeAimTouch()
    if _G.AimTouchInitialized then return end
    _G.AimTouchInitialized = true
    local ticker = package.loaded["common.time_ticker"] or require("common.time_ticker")
    local function Norm(a)
        while 180 < a do a = a - 360 end
        while a < -180 do a = a + 360 end
        return a
    end
    local function Tick()
        if not _G._AimCursorActive then
            if ticker and ticker.AddTimerOnce then ticker.AddTimerOnce(0.015, Tick) end
            return
        end
        pcall(function()
            if _G.NTH_GetVal("AIM_TOUCH") ~= 1 then return end
            local GPD = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
            if not GPD then return end
            local pc_char = GPD.GetPlayerCharacter()
            local pc = GPD.GetPlayerController()
            if not slua.isValid(pc_char) or not slua.isValid(pc) then return end
            if type(pc_char.IsDead) == "function" and pc_char:IsDead() then return end
            local firing = pc_char.bIsWeaponFiring
            local ads = pc_char.bIsGunADS
            local wid = 0
            pcall(function()
                local w = pc_char:GetCurrentWeapon()
                if slua.isValid(w) then wid = w:GetWeaponID() end
            end)
            local ws = tostring(wid)
            local sniper = string.find(ws, "103") ~= nil
            local shotgun = string.find(ws, "104") ~= nil
            local throwable = string.find(ws, "107001") ~= nil or ws == "107008"
            local sniperMode = sniper and ads and (_G.NTH_GetVal("AIM_TOUCH_SNIPER_AUTO_DAU") == 1)
            local shotgunMode = shotgun and (_G.NTH_GetVal("AIM_TOUCH_SHOTGUN_AUTO") == 1)
            local throwMode = throwable and (_G.NTH_GetVal("AIM_TOUCH_NO") == 1)
            local fm = _G.NTH_GetVal("AIM_TOUCH_CHE_DO_BAN") or 1
            local should = false
            if fm == 1 and firing then should = true
            elseif fm == 2 and ads then should = true
            elseif fm == 3 and firing and not ads then should = true
            elseif fm == 4 then should = true
            elseif fm == 5 and ads and firing then should = true end
            if sniperMode then should = true end
            if shotgunMode then should = true end
            if throwMode then should = true end
            if not should then return end
            local best, bestScore = nil, 999999
            local prio = _G.NTH_GetVal("AIM_TOUCH_MUC_TIEU") or 1
            local maxDist = (_G.NTH_GetVal("AIM_TOUCH_KHOAN_CACH") or 400) * 100.0
            if shotgunMode then prio = 1 end
            local cm = pc.PlayerCameraManager
            if not slua.isValid(cm) then return end
            local camLoc = cm:GetCameraLocation()
            local camRot = cm:GetCameraRotation()
            local fov = 20
            if sniperMode then fov = _G.NTH_GetVal("FOV_SNIP") or 5
            elseif shotgunMode then fov = _G.NTH_GetVal("FOV_SHOTGUN") or 15
            elseif throwMode then fov = _G.NTH_GetVal("FOV_NO") or 15
            elseif ads then fov = _G.NTH_GetVal("AIM_TOUCH_FOV_SCOPE") or 10
            else fov = _G.NTH_GetVal("AIM_TOUCH_FOV_TAM_TRANG") or 20 end
            if fov == 0 then fov = 20 end
            local chars = GPD.GetAllPlayerCharacters and GPD.GetAllPlayerCharacters() or GPD.GameCharacters or {}
            for _, t in pairs(chars) do
                if slua.isValid(t) and _G.IsEnemyTarget(pc_char, t) then
                    local d = 999999
                    pcall(function() d = pc_char:GetDistanceTo(t) end)
                    if d <= maxDist then
                        local skip = false
                        if shotgunMode and 3000.0 < d then skip = true end
                        local nb, mb = _G.NTH_CheckIsBot(t)
                        if (nb or mb) and _G.NTH_GetVal("AIM_TOUCH_BO_BOT") == 1 then skip = true end
                        if not skip then
                            local td, tk, th = false, false, 100
                            pcall(function()
                                td = (type(t.IsDead) == "function" and t:IsDead()) or t.bIsDead or t.bIsDeadFlag
                                tk = (type(t.IsNearDeath) == "function" and t:IsNearDeath()) or t.bIsNearDeath
                                th = (type(t.GetHealth) == "function" and t:GetHealth()) or t.Health or 100
                            end)
                            if td or th <= 0 then skip = true end
                            if tk and _G.NTH_GetVal("AIM_TOUCH_BO_KNOCK") == 1 then skip = true end
                            if not skip and slua.isValid(t.Mesh) then
                                local los = true
                                local needCheck = false
                                if shotgunMode then
                                    if _G.NTH_GetVal("AIM_TOUCH_SHOTGUN_VISCHECK") == 1 then needCheck = true end
                                else
                                    if _G.NTH_GetVal("AIM_TOUCH_CHECK_VAT_CAN") == 1 then needCheck = true end
                                end
                                if needCheck then
                                    los = false
                                    pcall(function() los = pc:LineOfSightTo(t, import("Vector")(0, 0, 0), false) end)
                                end
                                if los then
                                    local tl = t.Mesh:GetSocketLocation("spine_03")
                                    if tl then
                                        local dx, dy, dz = tl.X - camLoc.X, tl.Y - camLoc.Y, tl.Z - camLoc.Z
                                        local hd = math.sqrt(dx * dx + dy * dy)
                                        local ty = math.atan(dy, dx) * (180.0 / math.pi)
                                        local tp = math.atan(dz, hd) * (180.0 / math.pi)
                                        local yd = Norm(ty - camRot.Yaw)
                                        local pd = Norm(tp - camRot.Pitch)
                                        local ang = math.sqrt(yd * yd + pd * pd)
                                        if ang <= fov then
                                            local sc = 999999
                                            if prio == 1 then sc = ang
                                            elseif prio == 2 then sc = d
                                            elseif prio == 3 then sc = th
                                            elseif prio == 4 then
                                                local tmax = 100
                                                pcall(function() tmax = (type(t.GetHealthMax) == "function" and t:GetHealthMax()) or t.HealthMax or 100 end)
                                                sc = (th / tmax) * 100.0
                                            end
                                            if sc < bestScore then bestScore = sc; best = t end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if not best or not slua.isValid(best.Mesh) then return end
            local aimPart = _G.NTH_GetVal("AIM_TOUCH_VI_TRI_AIM") or 1
            if sniperMode or throwMode then aimPart = 2 end
            if shotgunMode then
                aimPart = _G.NTH_GetVal("AIM_TOUCH_SHOTGUN_VI_TRI") or 2
                if aimPart == 1 then aimPart = 2 end
            end
            if aimPart == 1 then aimPart = 2 end
            local bone = "spine_03"
            if aimPart == 3 then bone = "pelvis"
            elseif aimPart == 4 then bone = "calf_l" end
            local loc = best.Mesh:GetSocketLocation(bone)
            if not loc then return end
            if sniperMode or shotgunMode then loc.Z = loc.Z + 12.0 end
            if throwable then
                local tdx, tdy, tdz = loc.X - camLoc.X, loc.Y - camLoc.Y, loc.Z - camLoc.Z
                local tdist = math.sqrt(tdx * tdx + tdy * tdy) / 100.0
                local theight = tdz / 100.0
                local tspeed = 160.0
                local gs = 0.65
                local g = 9.8 * gs
                local v2 = tspeed * tspeed
                local v4 = v2 * v2
                local disc = v4 - g * (g * tdist * tdist + 2.0 * theight * v2)
                if disc > 0 then
                    local la = math.atan((v2 - math.sqrt(disc)) / (g * tdist))
                    loc.Z = camLoc.Z + tdist * math.tan(la) * 100.0
                else
                    loc.Z = loc.Z + tdist * 100.0 * gs
                end
            end
            if _G.NTH_GetVal("AIM_TOUCH_DU_DOAN_ACTIVE") == 1 then
                local dd = pc_char:GetDistanceTo(best)
                local pr = throwable and 16000.0 or 85000.0
                local pt = dd / pr
                local ps = 1.0
                if sniperMode then ps = (_G.NTH_GetVal("DU_DOAN_SNIP") or 50) / 50.0
                elseif throwable then ps = (_G.NTH_GetVal("DU_DOAN_NO") or 50) / 50.0
                else ps = (_G.NTH_GetVal("AIM_TOUCH_DU_DOAN") or 50) / 50.0 end
                local v = import("Vector")(0, 0, 0)
                pcall(function() v = best:GetVelocity() end)
                loc.X = loc.X + v.X * pt * ps
                loc.Y = loc.Y + v.Y * pt * ps
                loc.Z = loc.Z + v.Z * pt * ps
            end
            local rec = _G.NTH_GetVal("AIM_TOUCH_RECOIL_ACTIVE") == 1
            if sniper or shotgunMode or throwable then rec = false end
            if rec then
                local rd = pc_char:GetDistanceTo(best) / 100.0
                local rs = (_G.NTH_GetVal("AIM_TOUCH_LESS_RECOIL") or 50) / 50.0
                if ads then loc.Z = loc.Z - rd * 1.5 * rs
                else loc.Z = loc.Z - rd * 0.5 * rs end
            else
                if not throwable then loc.Z = loc.Z - 1.2 end
                if not sniper and not shotgunMode and not throwable and ads and firing then
                    loc.Z = loc.Z - (pc_char:GetDistanceTo(best) / 100.0) * 1.3
                end
            end
            local adx, ady, adz = loc.X - camLoc.X, loc.Y - camLoc.Y, loc.Z - camLoc.Z
            local ahd = math.sqrt(adx * adx + ady * ady)
            local ay = math.atan(ady, adx) * (180.0 / math.pi)
            local ap = math.atan(adz, ahd) * (180.0 / math.pi)
            local ayd = Norm(ay - camRot.Yaw)
            local apd = Norm(ap - camRot.Pitch)
            local sp = _G.NTH_GetVal("AIM_TOUCH_SPEED") or 30
            if sniperMode then sp = _G.NTH_GetVal("SPEED_SNIP") or 70
            elseif shotgunMode then sp = _G.NTH_GetVal("SPEED_SHOTGUN") or 70
            elseif throwMode then sp = _G.NTH_GetVal("SPEED_NO") or 60 end
            if sp <= 0 then sp = 1 end
            local sd = ads and (51 - sp) * 1.5 or (51 - sp)
            if sd < 1.0 then sd = 1.0 end
            pc:AddYawInput(ayd / sd)
            pc:AddPitchInput(apd / sd)
            if shotgunMode then
                local err = math.sqrt(ayd * ayd + apd * apd)
                if err < 8.0 then
                    local now = os.clock()
                    if not _G.NTH_LastAutoFireTime then _G.NTH_LastAutoFireTime = 0 end
                    if 0.1 < (now - _G.NTH_LastAutoFireTime) then
                        pcall(function()
                            local SM = import("EShootWeaponShootMode")
                            local sm = (SM and SM.SWST_TraceTarget) or 0
                            if type(pc_char.StartFire) == "function" then
                                pc_char:StartFire(0, 0, sm, import("Vector")(0, 0, 0), true, nil)
                            end
                            if type(pc_char.StartWeaponFire) == "function" then pc_char:StartWeaponFire() end
                            if ticker and ticker.AddTimerOnce then
                                ticker.AddTimerOnce(0.02, function()
                                    pcall(function()
                                        if type(pc_char.StopWeaponFire) == "function" then pc_char:StopWeaponFire() end
                                    end)
                                end)
                            end
                        end)
                        _G.NTH_LastAutoFireTime = now
                    end
                end
            end
        end)
        if ticker and ticker.AddTimerOnce then ticker.AddTimerOnce(0.015, Tick) end
    end
    Tick()
end

-- ========================================================================
-- COUNTER OVERLAY
-- ========================================================================
local CounterOverlay = {
    bActive = false, MainContainer = nil, WidgetSlot = nil,
    TextBlockPlayer = nil, TextBlockBot = nil,
    Width = 260, Height = 25, OffsetY = 10,
    PositionXPercent = 0.42,
    PositionYPercent = 0.03,
    PlayerCount = 0, BotCount = 0, FontSize = 14,
    NumLayers = 50, Red = 0.0, Green = 0.0, Blue = 0.0, LayerAlpha = 0.06,
    _CachedTextPlayer = "", _CachedTextBot = "", _CachedPosVec = nil,
    CenterX = 0, CenterY = 0
}

function CounterOverlay.Create()
    if CounterOverlay.MainContainer and slua.isValid(CounterOverlay.MainContainer) then return true end
    local ParentCanvas = PlayerMapMarker and PlayerMapMarker.ESPCanvas
    if not ParentCanvas or not slua.isValid(ParentCanvas) then
        if PlayerMapMarker and PlayerMapMarker.InitESPCanvas then
            if not PlayerMapMarker.InitESPCanvas() then return false end
            ParentCanvas = PlayerMapMarker.ESPCanvas
        end
    end
    if not ParentCanvas or not slua.isValid(ParentCanvas) then return false end
    local Container = nil
    pcall(function() Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas) end)
    if not Container or not slua.isValid(Container) then return false end
    local color = FLinearColor(CounterOverlay.Red, CounterOverlay.Green, CounterOverlay.Blue, CounterOverlay.LayerAlpha)
    local numLayers = CounterOverlay.NumLayers
    local totalWidth = CounterOverlay.Width
    for i = 1, numLayers do
        local progress = (i / numLayers) ^ 1.15
        local layerWidth = progress * totalWidth
        local layerX = (totalWidth - layerWidth) / 2.0
        local border = nil
        pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", Container) end)
        if border and slua.isValid(border) then
            pcall(function()
                border:SetBrushColor(color)
                border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            local slot = Container:AddChildToCanvas(border)
            if slot then
                slot:SetPosition(FVector2D(layerX, 0))
                slot:SetSize(FVector2D(layerWidth, CounterOverlay.Height))
            end
        end
    end
    local txtPlayer = nil
    pcall(function() txtPlayer = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
    if txtPlayer and slua.isValid(txtPlayer) then
        pcall(function()
            local strText = string.format("Player: %d", CounterOverlay.PlayerCount)
            txtPlayer:SetText(strText)
            CounterOverlay._CachedTextPlayer = strText
            local redLinear = FLinearColor(1.0, 0.0, 0.0, 1.0)
            if FSlateColor then txtPlayer:SetColorAndOpacity(FSlateColor(redLinear)) else txtPlayer:SetColorAndOpacity(redLinear) end
            if txtPlayer.Font then
                local font = txtPlayer.Font
                font.Size = CounterOverlay.FontSize
                txtPlayer.Font = font
            end
            txtPlayer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        local txtSlot1 = Container:AddChildToCanvas(txtPlayer)
        if txtSlot1 then
            pcall(function()
                txtSlot1:SetAutoSize(true)
                txtSlot1:SetAlignment(FVector2D(0.5, 0.5))
                txtSlot1:SetPosition(FVector2D(totalWidth * 0.35, CounterOverlay.Height * 0.5))
                txtSlot1:SetZOrder(1000)
            end)
        end
        CounterOverlay.TextBlockPlayer = txtPlayer
    end
    local txtBot = nil
    pcall(function() txtBot = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
    if txtBot and slua.isValid(txtBot) then
        pcall(function()
            local strText = string.format("Bot: %d", CounterOverlay.BotCount)
            txtBot:SetText(strText)
            CounterOverlay._CachedTextBot = strText
            local greenLinear = FLinearColor(1.0, 0.0, 1.0, 1.0)
            if FSlateColor then txtBot:SetColorAndOpacity(FSlateColor(greenLinear)) else txtBot:SetColorAndOpacity(greenLinear) end
            if txtBot.Font then
                local font = txtBot.Font
                font.Size = CounterOverlay.FontSize
                txtBot.Font = font
            end
            txtBot:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        local txtSlot2 = Container:AddChildToCanvas(txtBot)
        if txtSlot2 then
            pcall(function()
                txtSlot2:SetAutoSize(true)
                txtSlot2:SetAlignment(FVector2D(0.5, 0.5))
                txtSlot2:SetPosition(FVector2D(totalWidth * 0.65, CounterOverlay.Height * 0.5))
                txtSlot2:SetZOrder(1000)
            end)
        end
        CounterOverlay.TextBlockBot = txtBot
    end
    local MainSlot = nil
    pcall(function() MainSlot = ParentCanvas:AddChildToCanvas(Container) end)
    if not MainSlot then return false end
    CounterOverlay.MainContainer = Container
    CounterOverlay.WidgetSlot = MainSlot
    pcall(function()
        MainSlot:SetAutoSize(false)
        MainSlot:SetZOrder(999)
        MainSlot:SetAlignment(FVector2D(0.5, 0.0))
        MainSlot:SetSize(FVector2D(CounterOverlay.Width, CounterOverlay.Height))
    end)
    return true
end

function CounterOverlay.SetCounts(players, bots)
    if CounterOverlay.PlayerCount == players and CounterOverlay.BotCount == bots then return end
    CounterOverlay.PlayerCount = players or 0
    CounterOverlay.BotCount = bots or 0
    if CounterOverlay.TextBlockPlayer and slua.isValid(CounterOverlay.TextBlockPlayer) then
        pcall(function()
            local s = string.format("Player: %d", CounterOverlay.PlayerCount)
            if CounterOverlay._CachedTextPlayer ~= s then
                CounterOverlay.TextBlockPlayer:SetText(s)
                CounterOverlay._CachedTextPlayer = s
            end
        end)
    end
    if CounterOverlay.TextBlockBot and slua.isValid(CounterOverlay.TextBlockBot) then
        pcall(function()
            local s = string.format("Bot: %d", CounterOverlay.BotCount)
            if CounterOverlay._CachedTextBot ~= s then
                CounterOverlay.TextBlockBot:SetText(s)
                CounterOverlay._CachedTextBot = s
            end
        end)
    end
end

function CounterOverlay.UpdatePosition()
    local Slot = CounterOverlay.WidgetSlot
    if not Slot or not slua.isValid(Slot) then return end
    local PC = PlayerMapMarker and PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end
    local viewW = PlayerMapMarker._cachedViewportW or 1920
    local viewH = PlayerMapMarker._cachedViewportH or 1080
    pcall(function()
        if PC.GetViewportSize then
            local vs = FVector2D(0, 0)
            PC:GetViewportSize(vs)
            if vs and vs.X and vs.X > 200 then
                viewW = vs.X
                viewH = vs.Y
            end
        end
    end)
    pcall(function()
        local posX = (viewW * (CounterOverlay.PositionXPercent or 0.42)) - (CounterOverlay.Width / 2)
        local posY = (viewH * (CounterOverlay.PositionYPercent or 0.03))

        if not CounterOverlay._CachedPosVec then
            CounterOverlay._CachedPosVec = FVector2D(posX, posY)
        else
            CounterOverlay._CachedPosVec.X = posX
            CounterOverlay._CachedPosVec.Y = posY
        end
        Slot:SetPosition(CounterOverlay._CachedPosVec)

        local pixelX = viewW * (CounterOverlay.PositionXPercent or 0.42)
        local pixelY = posY + (CounterOverlay.Height / 2)
        local canvasX, canvasY = pixelX, pixelY
        pcall(function()
            local SBL = SlateBlueprintLibrary
            if SBL and SBL.AbsoluteToLocal then
                local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
                if cg then
                    local loc = SBL.AbsoluteToLocal(cg, FVector2D(pixelX, pixelY))
                    if loc then
                        canvasX = loc.X
                        canvasY = loc.Y
                    end
                end
            end
        end)
        CounterOverlay.CenterX = canvasX
        CounterOverlay.CenterY = canvasY
    end)
end

function CounterOverlay.Start()
    if CounterOverlay.bActive and CounterOverlay.MainContainer and slua.isValid(CounterOverlay.MainContainer) then return end
    if CounterOverlay.Create() then
        CounterOverlay.bActive = true
        pcall(function() CounterOverlay.MainContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    end
end

function CounterOverlay.Stop()
    CounterOverlay.bActive = false
    if CounterOverlay.MainContainer and slua.isValid(CounterOverlay.MainContainer) then
        pcall(function()
            CounterOverlay.MainContainer:RemoveFromParent()
            CounterOverlay.MainContainer:ConditionalBeginDestroy()
        end)
    end
    CounterOverlay.MainContainer = nil
    CounterOverlay.WidgetSlot = nil
    CounterOverlay.TextBlockPlayer = nil
    CounterOverlay.TextBlockBot = nil
    CounterOverlay._CachedPosVec = nil
end
_G.CounterOverlay = CounterOverlay

-- ========================================================================
-- PLAYER MAP MARKER
-- ========================================================================
local PlayerMapMarker = {}
PlayerMapMarker.SnapLines = {}
PlayerMapMarker.BoxWidgets = {}
PlayerMapMarker.ArrowWidgets = {}
PlayerMapMarker.FOVCircleLines = {}
PlayerMapMarker.ESPCanvas = nil
PlayerMapMarker.bActive = false
PlayerMapMarker._EnemyCache = {}
PlayerMapMarker._cachedViewportW = 1920
PlayerMapMarker._cachedViewportH = 1080
PlayerMapMarker._CanvasScaleX = 1.0
PlayerMapMarker._CanvasScaleY = 1.0
PlayerMapMarker._CanvasOffsetX = 0.0
PlayerMapMarker._CanvasOffsetY = 0.0

PlayerMapMarker.FOVCircleRadius = 70.0
PlayerMapMarker.FOVCircleSegments = 36
PlayerMapMarker.FOVCircleThickness = 3.5
PlayerMapMarker.FOVCircleColor = FLinearColor and FLinearColor(0.2, 0.8, 1.0, 0.85) or { R = 0.2, G = 0.8, B = 1, A = 0.85 }

PlayerMapMarker.ArrowStemLen = 10.0
PlayerMapMarker.ArrowHeadLen = 5.0
PlayerMapMarker.ArrowWingAngle = 0.45
PlayerMapMarker.ArrowOffset = 32.0
PlayerMapMarker.ArrowThickness = 3.0
PlayerMapMarker.ArrowColor = FLinearColor and FLinearColor(1.0, 0.1, 0.1, 0.95) or { R = 1, G = 0.1, B = 0.1, A = 0.95 }

PlayerMapMarker.SnapThickness = 2.5
PlayerMapMarker.SnapColor = FLinearColor and FLinearColor(0.2, 0.5, 1.0, 0.95) or { R = 0.2, G = 0.5, B = 1, A = 0.95 }

PlayerMapMarker.BoxThickness = 3.0
PlayerMapMarker.BoxWidthFactor = 0.40
PlayerMapMarker.BoxColor = FLinearColor and FLinearColor(0.1, 0.4, 1.0, 0.95) or { R = 0.1, G = 0.4, B = 1, A = 0.95 }

PlayerMapMarker.nUpdateInterval = 0.5
PlayerMapMarker._LightUpdateInterval = 0.05

function PlayerMapMarker.GetGameplayData()
    if PlayerMapMarker._CachedGDP then return PlayerMapMarker._CachedGDP end
    local ok, GDP = pcall(function() return require("GameLua.GameCore.Data.GameplayData") end)
    if ok and GDP then PlayerMapMarker._CachedGDP = GDP; return GDP end
    return nil
end

function PlayerMapMarker.GetMyPlayerController()
    local PC = PlayerMapMarker._CachedPC
    if PC and IsValid(PC) then return PC end
    local GDP = PlayerMapMarker.GetGameplayData()
    if GDP then pcall(function() PC = GDP.GetPlayerController and GDP.GetPlayerController() end) end
    if not (PC and IsValid(PC)) then
        pcall(function() if slua_GameFrontendHUD then PC = slua_GameFrontendHUD:GetPlayerController() end end)
    end
    if PC and IsValid(PC) then PlayerMapMarker._CachedPC = PC end
    return PC
end

function PlayerMapMarker.GetCGameState()
    if PlayerMapMarker._CachedGS and IsValid(PlayerMapMarker._CachedGS) then return PlayerMapMarker._CachedGS end
    local ok, GS = pcall(function() return require("GameLua.GameCore.Data.CGameState") end)
    if ok and GS then PlayerMapMarker._CachedGS = GS; return GS end
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
    if not next(AllChars) then
        local GS = PlayerMapMarker.GetCGameState()
        if GS and GS.GetAllCharacters then pcall(function() AllChars = GS:GetAllCharacters() end) end
    end
    return AllChars
end

function PlayerMapMarker.GetMyPlayerKey()
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return nil end
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
            if MyChar and Character == MyChar then bIsMe = true; return end
        end
        local PC = PlayerMapMarker.GetMyPlayerController()
        if PC and PC.GetPawn then
            local Pawn = PC:GetPawn()
            if Pawn and Character == Pawn then bIsMe = true; return end
        end
    end)
    if not bIsMe and MyKey ~= nil and PlayerKey ~= nil then
        bIsMe = (tostring(PlayerKey) == tostring(MyKey))
    end
    return bIsMe
end

function PlayerMapMarker.IsAlive(Character)
    local bAlive = true
    pcall(function()
        if Character.HealthStatus then
            bAlive = SecurityCommonUtils.IsHealthStatusAlive(Character.HealthStatus)
        elseif Character.IsAlive then
            bAlive = Character:IsAlive()
        elseif Character.Health ~= nil then
            bAlive = Character.Health > 0
        elseif Character.HP ~= nil then
            bAlive = Character.HP > 0
        end
    end)
    return bAlive
end

function PlayerMapMarker.GetTeamID(Character)
    if not IsValid(Character) then return nil end
    local TeamID = nil
    pcall(function() if Character.GetTeamID then TeamID = Character:GetTeamID() end end)
    if not TeamID then
        pcall(function()
            local PS = nil
            if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety()
            elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
            if IsValid(PS) then
                if PS.GetTeamID then TeamID = PS:GetTeamID()
                elseif PS.TeamID then TeamID = PS.TeamID end
            end
        end)
    end
    if not TeamID then
        pcall(function() if Character.TeamID then TeamID = Character.TeamID end end)
    end
    return TeamID
end

function PlayerMapMarker.GetCharacterFeetLoc(Character)
    if not IsValid(Character) then return nil end
    local Loc = nil
    pcall(function() if Character.K2_GetActorLocation then Loc = Character:K2_GetActorLocation() end end)
    if not Loc then
        pcall(function() if Game and Game.GetActorLocation then Loc = Game:GetActorLocation(Character) end end)
    end
    return Loc
end

function PlayerMapMarker.GetCharacterHeadLoc(Character)
    local Feet = PlayerMapMarker.GetCharacterFeetLoc(Character)
    if not Feet then return nil end
    local headZ = Feet.Z
    pcall(function()
        local h = 170
        if Character.bIsCrouched then h = 120 end
        if Character.IsProne and Character:IsProne() then h = 50 end
        headZ = Feet.Z + h
    end)
    return { X = Feet.X, Y = Feet.Y, Z = headZ }
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
        if MainControlBaseUI.CanvasPanel_0 and Game:IsValid(MainControlBaseUI.CanvasPanel_0) then
            ParentCanvas = MainControlBaseUI.CanvasPanel_0
        elseif MainControlBaseUI.CanvasPanel_42 and Game:IsValid(MainControlBaseUI.CanvasPanel_42) then
            ParentCanvas = MainControlBaseUI.CanvasPanel_42
        end
    end)
    if not ParentCanvas then return false end
    PlayerMapMarker.ESPCanvas = ParentCanvas
    return true
end

function PlayerMapMarker.UpdateCanvasTransform(PC)
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local success = false
    pcall(function()
        local SBL = SlateBlueprintLibrary
        if SBL and SBL.AbsoluteToLocal then
            local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
            if cg then
                local pt0 = SBL.AbsoluteToLocal(cg, FVector2D and FVector2D(0, 0) or { X = 0, Y = 0 })
                local pt1 = SBL.AbsoluteToLocal(cg, FVector2D and FVector2D(100, 100) or { X = 100, Y = 100 })
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
        local WLL = WidgetLayoutLibrary
        if WLL and WLL.GetViewportScale then scale = WLL.GetViewportScale(PC) or 1.0 end
        PlayerMapMarker._CanvasScaleX = 1.0 / scale
        PlayerMapMarker._CanvasScaleY = 1.0 / scale
        PlayerMapMarker._CanvasOffsetX = 0
        PlayerMapMarker._CanvasOffsetY = 0
    end
end

function PlayerMapMarker.ScreenPixelToCanvas(p)
    if not p then return { X = 0, Y = 0 } end
    local sx = PlayerMapMarker._CanvasScaleX or 1.0
    local sy = PlayerMapMarker._CanvasScaleY or 1.0
    local ox = PlayerMapMarker._CanvasOffsetX or 0
    local oy = PlayerMapMarker._CanvasOffsetY or 0
    return (FVector2D and FVector2D(p.X * sx + ox, p.Y * sy + oy)) or { X = p.X * sx + ox, Y = p.Y * sy + oy }
end

function PlayerMapMarker.ProjectToCanvas(PC, WorldLoc)
    if not IsValid(PC) or not WorldLoc then return false, { X = 0, Y = 0 } end
    local Pix = FVector2D and FVector2D(0, 0) or { X = 0, Y = 0 }
    local bOK = false
    pcall(function()
        local res = PC:ProjectWorldLocationToScreen(WorldLoc, Pix, true)
        bOK = (res == true or res == 1 or (Pix and (Pix.X ~= 0 or Pix.Y ~= 0)))
    end)
    if not bOK then return false, { X = 0, Y = 0 } end
    return true, PlayerMapMarker.ScreenPixelToCanvas(Pix)
end

function PlayerMapMarker.GetScreenCenter(PC)
    local W, H = 0, 0
    pcall(function()
        if PC and PC.GetViewportSize then
            local vs = FVector2D and FVector2D(0, 0) or { X = 0, Y = 0 }
            PC:GetViewportSize(vs)
            if vs and vs.X and vs.X > 200 then W, H = vs.X, vs.Y end
        end
    end)
    if W <= 200 then
        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportSize then
                local vs = WLL.GetViewportSize(PC)
                if vs and vs.X and vs.X > 200 then W, H = vs.X, vs.Y end
            end
        end)
    end
    if W <= 200 then W = PlayerMapMarker._cachedViewportW or 1920; H = PlayerMapMarker._cachedViewportH or 1080 end
    return PlayerMapMarker.ScreenPixelToCanvas(FVector2D and FVector2D(W / 2, H / 2) or { X = W / 2, Y = H / 2 }), W, H
end

function PlayerMapMarker.GetArrowAngleRad(PC, WorldLoc, CenterCanvas)
    local angle_rad = 0
    local Pix = FVector2D and FVector2D(0, 0) or { X = 0, Y = 0 }
    local bOK = false
    pcall(function()
        local res = PC:ProjectWorldLocationToScreen(WorldLoc, Pix, true)
        bOK = (res == true or res == 1)
    end)
    if bOK then
        local cp = PlayerMapMarker.ScreenPixelToCanvas(Pix)
        local dx = cp.X - CenterCanvas.X
        local dy = cp.Y - CenterCanvas.Y
        if math.abs(dx) > 0.1 or math.abs(dy) > 0.1 then
            angle_rad = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
        end
    else
        pcall(function()
            local CamMgr = PC:GetPlayerCameraManager()
            if not IsValid(CamMgr) then return end
            local CamLoc = CamMgr:GetCameraLocation()
            local CamRot = CamMgr:GetCameraRotation()
            local dx3 = WorldLoc.X - CamLoc.X
            local dy3 = WorldLoc.Y - CamLoc.Y
            local eYaw = math.atan2 and math.atan2(dy3, dx3) or math.atan(dy3, dx3)
            local cYaw = math.rad(CamRot.Yaw)
            local delta = eYaw - cYaw
            while delta > math.pi do delta = delta - 2 * math.pi end
            while delta < -math.pi do delta = delta + 2 * math.pi end
            angle_rad = delta + math.pi
            while angle_rad > math.pi do angle_rad = angle_rad - 2 * math.pi end
            while angle_rad < -math.pi do angle_rad = angle_rad + 2 * math.pi end
        end)
    end
    return angle_rad
end

function PlayerMapMarker.CreateLineWidget(color, zOrder)
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local Border = nil
    pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not Border or not slua.isValid(Border) then return nil end
    pcall(function() Border:SetBrushColor(color) end)
    pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    pcall(function() Border:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or { X = 0, Y = 0.5 }) end)
    local Slot = nil
    pcall(function()
        Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border)
        if Slot then Slot:SetAutoSize(false); Slot:SetZOrder(zOrder or 1) end
    end)
    if not Slot then return nil end
    return { Widget = Border, Slot = Slot }
end

function PlayerMapMarker.DrawLine(ld, x1, y1, x2, y2, thickness)
    if not ld or not ld.Widget or not ld.Slot then return end
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.5 then return end
    local ang = (math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)) * (180.0 / math.pi)
    pcall(function()
        ld.Slot:SetPosition(FVector2D and FVector2D(x1, y1 - thickness / 2) or { X = x1, Y = y1 - thickness / 2 })
        ld.Slot:SetSize(FVector2D and FVector2D(len, thickness) or { X = len, Y = thickness })
        ld.Widget:SetRenderAngle(ang)
        ld.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
end

local function HideWidget(ld)
    if ld and ld.Widget and slua.isValid(ld.Widget) then
        pcall(function() ld.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    end
end

local function DestroyWidget(ld)
    if ld and ld.Widget and slua.isValid(ld.Widget) then
        pcall(function()
            ld.Widget:RemoveFromParent()
            ld.Widget:ConditionalBeginDestroy()
        end)
    end
end

function PlayerMapMarker.UpdateCenterCircle(cx, cy)
    local radius = PlayerMapMarker.FOVCircleRadius or 70.0
    local segments = PlayerMapMarker.FOVCircleSegments or 36
    local thickness = PlayerMapMarker.FOVCircleThickness or 3.5
    local color = PlayerMapMarker.FOVCircleColor
    for i = 1, segments do
        local a1 = ((i - 1) / segments) * (2 * math.pi)
        local a2 = (i / segments) * (2 * math.pi)
        if not PlayerMapMarker.FOVCircleLines[i] then
            PlayerMapMarker.FOVCircleLines[i] = PlayerMapMarker.CreateLineWidget(color, 0)
        end
        PlayerMapMarker.DrawLine(PlayerMapMarker.FOVCircleLines[i], cx + math.cos(a1) * radius, cy + math.sin(a1) * radius, cx + math.cos(a2) * radius, cy + math.sin(a2) * radius, thickness)
    end
end

function PlayerMapMarker.RemoveCenterCircle()
    for _, ld in pairs(PlayerMapMarker.FOVCircleLines) do DestroyWidget(ld) end
    PlayerMapMarker.FOVCircleLines = {}
end

function PlayerMapMarker.UpdateArrow(KeyStr, WorldLoc, PC, CenterCanvas)
    local color = PlayerMapMarker.ArrowColor
    local arr = PlayerMapMarker.ArrowWidgets[KeyStr]
    if not arr then
        arr = {
            stem = PlayerMapMarker.CreateLineWidget(color, 2),
            wL = PlayerMapMarker.CreateLineWidget(color, 2),
            wR = PlayerMapMarker.CreateLineWidget(color, 2),
        }
        if not arr.stem or not arr.wL or not arr.wR then
            DestroyWidget(arr.stem); DestroyWidget(arr.wL); DestroyWidget(arr.wR)
            return
        end
        PlayerMapMarker.ArrowWidgets[KeyStr] = arr
    end
    if not WorldLoc then
        HideWidget(arr.stem); HideWidget(arr.wL); HideWidget(arr.wR)
        return
    end
    local a = PlayerMapMarker.GetArrowAngleRad(PC, WorldLoc, CenterCanvas)
    local radius = PlayerMapMarker.FOVCircleRadius or 70.0
    local stemLen = PlayerMapMarker.ArrowStemLen or 10.0
    local headLen = PlayerMapMarker.ArrowHeadLen or 5.0
    local wingAng = PlayerMapMarker.ArrowWingAngle or 0.45
    local offset = PlayerMapMarker.ArrowOffset or 32.0
    local thick = PlayerMapMarker.ArrowThickness or 3.0
    local cx = CenterCanvas.X
    local cy = CenterCanvas.Y
    local baseX = cx + math.cos(a) * radius
    local baseY = cy + math.sin(a) * radius
    local tipX = cx + math.cos(a) * (radius + offset + stemLen)
    local tipY = cy + math.sin(a) * (radius + offset + stemLen)
    local backL = a + math.pi - wingAng
    local backR = a + math.pi + wingAng
    local wLX = tipX + math.cos(backL) * headLen
    local wLY = tipY + math.sin(backL) * headLen
    local wRX = tipX + math.cos(backR) * headLen
    local wRY = tipY + math.sin(backR) * headLen
    PlayerMapMarker.DrawLine(arr.stem, baseX, baseY, tipX, tipY, thick)
    PlayerMapMarker.DrawLine(arr.wL, tipX, tipY, wLX, wLY, thick)
    PlayerMapMarker.DrawLine(arr.wR, tipX, tipY, wRX, wRY, thick)
end

function PlayerMapMarker.RemoveArrow(KeyStr)
    local arr = PlayerMapMarker.ArrowWidgets[KeyStr]
    if arr then DestroyWidget(arr.stem); DestroyWidget(arr.wL); DestroyWidget(arr.wR) end
    PlayerMapMarker.ArrowWidgets[KeyStr] = nil
end

function PlayerMapMarker.ClearAllArrows()
    for k, arr in pairs(PlayerMapMarker.ArrowWidgets) do
        if arr then DestroyWidget(arr.stem); DestroyWidget(arr.wL); DestroyWidget(arr.wR) end
    end
    PlayerMapMarker.ArrowWidgets = {}
end

function PlayerMapMarker.UpdateSnapLine(KeyStr, headCanvas, originCanvas, bOnScreen)
    local ld = PlayerMapMarker.SnapLines[KeyStr]
    if not bOnScreen then HideWidget(ld); return end
    if not ld then
        ld = PlayerMapMarker.CreateLineWidget(PlayerMapMarker.SnapColor, 1)
        if not ld then return end
        PlayerMapMarker.SnapLines[KeyStr] = ld
    end
    local startX = originCanvas.X
    local startY = originCanvas.Y
    if CounterOverlay and CounterOverlay.CenterX and CounterOverlay.CenterX ~= 0 then
        startX = CounterOverlay.CenterX
        startY = CounterOverlay.CenterY
    end
    PlayerMapMarker.DrawLine(ld, startX, startY, headCanvas.X, headCanvas.Y, PlayerMapMarker.SnapThickness)
end

function PlayerMapMarker.RemoveSnapLine(KeyStr)
    DestroyWidget(PlayerMapMarker.SnapLines[KeyStr])
    PlayerMapMarker.SnapLines[KeyStr] = nil
end

function PlayerMapMarker.ClearAllSnapLines()
    for k, ld in pairs(PlayerMapMarker.SnapLines) do DestroyWidget(ld) end
    PlayerMapMarker.SnapLines = {}
end

function PlayerMapMarker.UpdateBox(KeyStr, headCanvas, feetCanvas, bOnScreen)
    local box = PlayerMapMarker.BoxWidgets[KeyStr]
    if not bOnScreen then
        if box then
            HideWidget(box.top); HideWidget(box.bot)
            HideWidget(box.left); HideWidget(box.right)
        end
        return
    end
    local boxH = feetCanvas.Y - headCanvas.Y
    if boxH < 10 then return end
    local boxW = boxH * (PlayerMapMarker.BoxWidthFactor or 0.40)
    local cx = (headCanvas.X + feetCanvas.X) * 0.5
    local L = cx - boxW * 0.5
    local R = cx + boxW * 0.5
    local T = headCanvas.Y
    local B = feetCanvas.Y
    local thick = PlayerMapMarker.BoxThickness or 3.0
    local color = PlayerMapMarker.BoxColor
    if not box then
        box = {
            top = PlayerMapMarker.CreateLineWidget(color, 1),
            bot = PlayerMapMarker.CreateLineWidget(color, 1),
            left = PlayerMapMarker.CreateLineWidget(color, 1),
            right = PlayerMapMarker.CreateLineWidget(color, 1),
        }
        PlayerMapMarker.BoxWidgets[KeyStr] = box
    end
    PlayerMapMarker.DrawLine(box.top, L, T, R, T, thick)
    PlayerMapMarker.DrawLine(box.bot, L, B, R, B, thick)
    PlayerMapMarker.DrawLine(box.left, L, T, L, B, thick)
    PlayerMapMarker.DrawLine(box.right, R, T, R, B, thick)
end

function PlayerMapMarker.RemoveBox(KeyStr)
    local box = PlayerMapMarker.BoxWidgets[KeyStr]
    if box then
        DestroyWidget(box.top); DestroyWidget(box.bot)
        DestroyWidget(box.left); DestroyWidget(box.right)
    end
    PlayerMapMarker.BoxWidgets[KeyStr] = nil
end

function PlayerMapMarker.ClearAllBoxes()
    for k, box in pairs(PlayerMapMarker.BoxWidgets) do
        if box then
            DestroyWidget(box.top); DestroyWidget(box.bot)
            DestroyWidget(box.left); DestroyWidget(box.right)
        end
    end
    PlayerMapMarker.BoxWidgets = {}
end

function PlayerMapMarker.ScanAndUpdate()
    if not ESP_Enabled then return end
    if not CheckExpiration() then return end
    if not PlayerMapMarker.InitESPCanvas() then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end
    PlayerMapMarker.UpdateCanvasTransform(PC)
    local centerCanvas, viewW, viewH = PlayerMapMarker.GetScreenCenter(PC)
    local originCanvas = PlayerMapMarker.ScreenPixelToCanvas(FVector2D and FVector2D(viewW / 2, 0) or { X = viewW / 2, Y = 0 })
    PlayerMapMarker.UpdateCenterCircle(centerCanvas.X, centerCanvas.Y)
    local AllChars = PlayerMapMarker.GetAllCharacters()
    if not AllChars then return end
    local MyKey = PlayerMapMarker.GetMyPlayerKey()
    local MyChar = nil
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then MyChar = GDP.GetLocalCharacter()
        elseif PC and PC.GetPawn then MyChar = PC:GetPawn() end
    end)
    local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)
    local realPlayers = 0
    local botPlayers = 0
    local SeenKeys = {}
    for PlayerKey, Character in pairs(AllChars) do
        if IsValid(Character) then
            local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
            local KeyStr = tostring(PlayerKey)
            local bAlive = PlayerMapMarker.IsAlive(Character)
            local TeamID = PlayerMapMarker.GetTeamID(Character)
            local bSkip = bIsMe
            if MyTeamID ~= nil and TeamID == MyTeamID and not bIsMe then bSkip = true end
            if not bAlive then bSkip = true end
            if not bSkip then
                SeenKeys[KeyStr] = true
                PlayerMapMarker._EnemyCache[KeyStr] = Character
                local bIsNormalBot, bIsMLBot = NTH_CheckIsBot(Character)
                local bIsBot = bIsNormalBot or bIsMLBot
                if bIsBot then botPlayers = botPlayers + 1
                else realPlayers = realPlayers + 1 end
                local HeadLoc = PlayerMapMarker.GetCharacterHeadLoc(Character)
                local FeetLoc = PlayerMapMarker.GetCharacterFeetLoc(Character)
                local bHeadOK, headCanvas = PlayerMapMarker.ProjectToCanvas(PC, HeadLoc)
                local bFeetOK, feetCanvas = PlayerMapMarker.ProjectToCanvas(PC, FeetLoc)
                local bOnScreen = bHeadOK and bFeetOK
                PlayerMapMarker.UpdateSnapLine(KeyStr, headCanvas, originCanvas, bOnScreen)
                PlayerMapMarker.UpdateBox(KeyStr, headCanvas, feetCanvas, bOnScreen)
                PlayerMapMarker.UpdateArrow(KeyStr, HeadLoc or FeetLoc, PC, centerCanvas)
            end
        end
    end
    if CounterOverlay.bActive then
        CounterOverlay.SetCounts(realPlayers, botPlayers)
        CounterOverlay.UpdatePosition()
    end
    local allKeys = {}
    for k in pairs(PlayerMapMarker.SnapLines) do allKeys[k] = true end
    for k in pairs(PlayerMapMarker.ArrowWidgets) do allKeys[k] = true end
    for KeyStr in pairs(allKeys) do
        if not SeenKeys[KeyStr] then
            PlayerMapMarker.RemoveSnapLine(KeyStr)
            PlayerMapMarker.RemoveBox(KeyStr)
            PlayerMapMarker.RemoveArrow(KeyStr)
            PlayerMapMarker._EnemyCache[KeyStr] = nil
        end
    end
end

function PlayerMapMarker.UpdateLight()
    if not ESP_Enabled then return end
    if not CheckExpiration() then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end
    PlayerMapMarker.UpdateCanvasTransform(PC)
    local centerCanvas, viewW, viewH = PlayerMapMarker.GetScreenCenter(PC)
    local originCanvas = PlayerMapMarker.ScreenPixelToCanvas(FVector2D and FVector2D(viewW / 2, 0) or { X = viewW / 2, Y = 0 })
    if CounterOverlay.bActive then CounterOverlay.UpdatePosition() end
    for KeyStr, Character in pairs(PlayerMapMarker._EnemyCache) do
        if IsValid(Character) and PlayerMapMarker.IsAlive(Character) then
            local HeadLoc = PlayerMapMarker.GetCharacterHeadLoc(Character)
            local FeetLoc = PlayerMapMarker.GetCharacterFeetLoc(Character)
            local bHeadOK, headCanvas = PlayerMapMarker.ProjectToCanvas(PC, HeadLoc)
            local bFeetOK, feetCanvas = PlayerMapMarker.ProjectToCanvas(PC, FeetLoc)
            local bOnScreen = bHeadOK and bFeetOK
            PlayerMapMarker.UpdateSnapLine(KeyStr, headCanvas, originCanvas, bOnScreen)
            PlayerMapMarker.UpdateBox(KeyStr, headCanvas, feetCanvas, bOnScreen)
            PlayerMapMarker.UpdateArrow(KeyStr, HeadLoc or FeetLoc, PC, centerCanvas)
        else
            PlayerMapMarker.RemoveSnapLine(KeyStr)
            PlayerMapMarker.RemoveBox(KeyStr)
            PlayerMapMarker.RemoveArrow(KeyStr)
            PlayerMapMarker._EnemyCache[KeyStr] = nil
        end
    end
end

function PlayerMapMarker.AttachTimers()
    pcall(function()
        local pc = PlayerMapMarker.GetMyPlayerController()
        if not slua.isValid(pc) or not pc.AddGameTimer then
            local now = os.time()
            if PlayerMapMarker._AttachPending then
                if PlayerMapMarker._AttachPendingTime and (now - PlayerMapMarker._AttachPendingTime) < 2 then return end
            end
            PlayerMapMarker._AttachPending = true
            PlayerMapMarker._AttachPendingTime = now
            pcall(function()
                require("timer").SetGameTimer(1.0, false, function()
                    PlayerMapMarker._AttachPending = nil
                    PlayerMapMarker._AttachPendingTime = nil
                    PlayerMapMarker.AttachTimers()
                end)
            end)
            return
        end
        PlayerMapMarker._AttachPending = nil
        PlayerMapMarker._AttachPendingTime = nil
        local now = os.time()
        local lastPC = PlayerMapMarker._ActiveTimerPC
        if lastPC and slua.isValid(lastPC) and lastPC == pc then
            if PlayerMapMarker._ActiveTimerTick and (now - PlayerMapMarker._ActiveTimerTick) < 5 then return end
        end
        PlayerMapMarker._ActiveTimerPC = pc
        PlayerMapMarker._ActiveTimerTick = now
        pcall(function()
            pc:AddGameTimer(PlayerMapMarker.nUpdateInterval or 0.5, true, function()
                PlayerMapMarker._ActiveTimerTick = os.time()
                if PlayerMapMarker.bActive then
                    pcall(function() PlayerMapMarker.ScanAndUpdate() end)
                end
            end)
        end)
        pcall(function()
            pc:AddGameTimer(PlayerMapMarker._LightUpdateInterval or 0.05, true, function()
                PlayerMapMarker._ActiveTimerTick = os.time()
                if PlayerMapMarker.bActive then
                    pcall(function() PlayerMapMarker.UpdateLight() end)
                end
            end)
        end)
        pcall(function() require("timer").SetGameTimer(5.0, false, PlayerMapMarker.AttachTimers) end)
    end)
end

function PlayerMapMarker.Start()
    if PlayerMapMarker.bActive then return end
    if not CheckExpiration() then return end
    PlayerMapMarker.bActive = true
    PlayerMapMarker.ScanAndUpdate()
    PlayerMapMarker.AttachTimers()
    CounterOverlay.Start()
    _G.InitializeAimTouch()
end

function PlayerMapMarker.Stop()
    PlayerMapMarker.bActive = false
    PlayerMapMarker.ClearAllSnapLines()
    PlayerMapMarker.ClearAllBoxes()
    PlayerMapMarker.ClearAllArrows()
    PlayerMapMarker.RemoveCenterCircle()
    PlayerMapMarker._EnemyCache = {}
    PlayerMapMarker.ESPCanvas = nil
    CounterOverlay.Stop()
end

_G.PlayerMapMarker = PlayerMapMarker

-- ========================================================================
-- TOGGLE BUTTON
-- ========================================================================
local BTN_BP = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP_C"
local BTN_BP2 = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP"
local C_ON = FLinearColor(.10, .80, .28, 1)
local C_OFF = FLinearColor(.80, .12, .12, 1)
local ToggleBtn = nil

local function LoadUI(p1, p2)
    local w = nil
    pcall(function() w = slua.loadUI(p1) end)
    if not IsValid(w) and p2 then pcall(function() w = slua.loadUI(p2) end) end
    return w
end

local function AddToHUD(w, z)
    if not IsValid(w) then return end
    pcall(function()
        if w.AddToViewport then w:AddToViewport(z or 10900)
        else require("game_frontend_hud").AddToContainer(UIContainers.Top, w, z or 10900) end
    end)
end

local function FindImg(w)
    for _, n in ipairs({"Image_BtnBg", "Image_backGround", "Image_BG", "Image_1", "Image_0", "Image", "BgImage", "Background"}) do
        if w[n] and w[n].SetColorAndOpacity then return w[n] end
    end
    for _, c in pairs(w) do
        if type(c) == "userdata" and IsValid(c) and c.SetColorAndOpacity then return c end
    end
end

local function FindTxt(w)
    for _, n in ipairs({"TextBlock", "Text", "RichText", "RichText_Content", "Label", "Text_0", "ContentText"}) do
        if w[n] and (w[n].SetText or w[n].SetTextString) then return w[n] end
    end
    for _, c in pairs(w) do
        if type(c) == "userdata" and IsValid(c) and (c.SetText or c.SetTextString) then return c end
    end
end

local function FindBtn(w)
    for _, n in ipairs({"Button", "Btn", "Button_Temp", "MainButton", "Button_0", "Btn_0"}) do
        if w[n] and (w[n].OnClicked or w[n].OnClickBg or w[n].OnClick) then return w[n] end
    end
    for _, c in pairs(w) do
        if type(c) == "userdata" and IsValid(c) and (c.OnClicked or c.OnClickBg or c.OnClick) then return c end
    end
end

local function SetTxt(w, txt, sz)
    if not IsValid(w) then return end
    pcall(function()
        local t = FindTxt(w) or w
        if t.SetText then t:SetText(txt)
        elseif t.SetTextString then t:SetTextString(txt) end
        if sz then
            local f = t.Font
            if f then f.Size = sz; t:SetFont(f) end
        end
    end)
end

local function SetClr(w, c)
    if not IsValid(w) then return end
    pcall(function()
        local i = FindImg(w)
        if i then i:SetColorAndOpacity(c) end
    end)
end

local function Bind(w, fn)
    pcall(function()
        local function tryBind(src)
            if not IsValid(src) then return false end
            if src.OnClicked then src.OnClicked:Add(function() pcall(fn) end); return true end
            if src.OnClickBg then src.OnClickBg:Add(function() pcall(fn) end); return true end
            if src.OnClick then src.OnClick:Add(function() pcall(fn) end); return true end
            return false
        end
        if not tryBind(FindBtn(w)) then tryBind(w) end
    end)
end

local function RefreshBtn()
    if not IsValid(ToggleBtn) then return end
    if ESP_Enabled then
        SetTxt(ToggleBtn, "ESP ON", 12)
        SetClr(ToggleBtn, C_ON)
    else
        SetTxt(ToggleBtn, "ESP OFF", 12)
        SetClr(ToggleBtn, C_OFF)
    end
end

local function CreateToggleButton()
    if IsValid(ToggleBtn) then return end
    ToggleBtn = LoadUI(BTN_BP, BTN_BP2)
    if not IsValid(ToggleBtn) then return end
    AddToHUD(ToggleBtn, 10900)
    pcall(function()
        if ToggleBtn.SetPositionInViewport then
            ToggleBtn:SetPositionInViewport(FVector2D(-15, 10), false)
            ToggleBtn:SetDesiredSizeInViewport(FVector2D(120, 32))
        end
    end)
    ToggleBtn:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
    RefreshBtn()
    Bind(ToggleBtn, function()
        ESP_Enabled = not ESP_Enabled
        if ESP_Enabled then
            PlayerMapMarker.Start()
            _G._WallhackActive = true
            _G.NTH_Settings.WALLHACK_CHAMS = 1
            _G._AimCursorActive = true
            _G.NTH_Settings.AIM_TOUCH = 1
            _G.NTH_Settings.AIMBOT = 1
            _G.EnvRequiresUpdate = true
        else
            PlayerMapMarker.Stop()
            _G._WallhackActive = false
            _G.NTH_Settings.WALLHACK_CHAMS = 0
            _G._AimCursorActive = false
            _G.NTH_Settings.AIM_TOUCH = 0
            _G.NTH_Settings.AIMBOT = 0
            _G.RemoveSmallAimCursor()
        end
        RefreshBtn()
    end)
end

-- ========================================================================
-- AUTO FEEDBACK SYSTEM (إرسال صورة المركز الأول للتليجرام تلقائياً)
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
        if _G.ELMASRY_Notify then
            pcall(_G.ELMASRY_Notify, message)
        elseif _G.MON5LANotify then
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
        Log("Installing ELMASRY VIP AutoFeedback system (Telegram)...")

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
    -- Start (فقط لو المود مش منتهي)
    -- ─────────────────────────────────────────────────────────────────────────
    if not _G._MOD_EXPIRED then
        AutoFeedback.Install()
    end
end

-- ========================================================================
-- START SYSTEMS
-- ========================================================================
local _ActivePC = nil

local function StartAll()
    pcall(function()
        if not CheckExpiration() then
            if not _G.WelcomeShown then
                _G.ELMASRY_ShowExpiredPopup()
                _G.WelcomeShown = true
            end
            return
        end
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if IsValid(pc) and pc ~= _ActivePC then
            _ActivePC = pc
            CreateToggleButton()
            if not PlayerMapMarker.bActive then
                PlayerMapMarker.Start()
                _G._WallhackActive = true
                _G._AimCursorActive = true
                _G.EnvRequiresUpdate = true
            end
        end
    end)
end

pcall(function()
    StartAll()
    if slua_GameFrontendHUD then
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if IsValid(pc) then pc:AddGameTimer(1.0, true, StartAll) end
    end
end)

-- ========================================================================
-- 🎉 WELCOME POPUP (بعد 4 ثواني من التشغيل)
-- ========================================================================
pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(4, function()
            _G.TryShowWelcome()
        end)
    else
        _G.TryShowWelcome()
    end
end)

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, function()
            if _G._WallhackActive then pcall(WallhackLoop) end
        end, -1, 0.1)
        print("[ELMASRY VIP] Wallhack loop linked to ESP button")
    end
end)

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, function()
            if _G._AimCursorActive then pcall(_G.ApplySmallAimCursor) end
        end, -1, 0.3)
        print("[ELMASRY VIP] AimCursor loop linked to ESP button")
    end
end)

print("[ELMASRY VIP] Full Edition loaded - ESP + Counter + Wallhack + Aim Assist + Aimbot + AutoFeedback")