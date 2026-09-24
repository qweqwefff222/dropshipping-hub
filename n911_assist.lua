--[[
	911 调度助手 v1.0 · Obsidian UI（全中文）
	游戏：[911调度模拟器] placeId 74226462246442
	三合一：自动接听（含全对话+CAD提交）/ 自动调度派遣 / 自动购买单位
	协议（反编译实锤）：
	  接听   PlayerAnsweredCall:FireServer(call.Id)
	  对话   PlayerSelectedDialogue:FireServer(callId, choiceId, {Priority, Services})
	  派遣   DispatchUnits:FireServer({IncidentId=inc.Id, UnitIds={unit.Id,...}})
	  购买   BuyUnit:FireServer(unit.Id)
]]

local g = getgenv()
if g._N911_ASSIST_STOP then g._N911_ASSIST_STOP() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local lp = Players.LocalPlayer

local N = ReplicatedStorage:WaitForChild("NineOneOne")
local Remotes = N:WaitForChild("NineOneOne_Remotes")
local Modules = N:WaitForChild("NineOneOne_Modules")
local function R(name) return Remotes:FindFirstChild(name) end

-- ================= 对话库索引（TemplateId -> 定义） =================
local CallLib = {}
do
	for _, m in ipairs(Modules:GetChildren()) do
		if m.Name:find("CallContentV2_Data") and m:IsA("ModuleScript") then
			local ok, d = pcall(require, m)
			if ok and type(d) == "table" then
				for _, def in pairs(d) do
					if type(def) == "table" and def.TemplateId then
						CallLib[tostring(def.TemplateId)] = def
					end
				end
			end
		end
	end
end

local function orderedChoices(def)
	local list = {}
	if type(def) ~= "table" or type(def.Choices) ~= "table" then return list end
	for k, v in pairs(def.Choices) do
		local nk = tonumber(k)
		if nk then list[nk] = v end
	end
	table.sort(list, function(a, b) return (a._i or 0) < (b._i or 0) end)
	-- ipairs 语义：按数字键顺序
	local out = {}
	for i = 1, #list do out[i] = list[i] end
	return out
end

-- ================= 状态 =================
local State = {
	Enabled = true,         -- AI 总开关（默认开启）
	AutoAnswer = true,      -- 自动接听+对话+CAD
	AutoDispatch = true,    -- 自动派遣
	AutoBuy = true,         -- 自动购买单位
	AutoStartShift = true,  -- 自动开始值班（每天掉线自动重开）
	AutoDistrict = true,    -- 自动扩展城区（钱够就解锁新城区）
	AutoBoard = true,       -- 自动扩任务板（钱够就买 ExtraIncidentSlot）
	DistrictReserve = 0,    -- 扩城区现金预留
	BuySelection = {},      -- 用户勾选要买的单位（中文名集合）
	BuyAll = true,          -- 未勾选时买全部可买
	CashReserve = 0,        -- 购买现金预留
	DialogueStep = 0.9,     -- 对话选项间隔（秒）
	Stat = {
		Answered = 0, Dialogue = 0, CAD = 0,
		Incidents = 0, Dispatched = 0, Bought = 0, Shifts = 0, Districts = 0, Board = 0,
	},
}

-- 运行时表（监听维护）
local Calls = {}         -- [callId] = call 对象（服务器推送，含 Status/ChoicesUsed/TemplateId）
local CallOrder = {}     -- 有序 callId 列表
local LocalProgress = {} -- [callId] = 本地已提交选项数（独立存储，防 CallUpdated 重建丢失）
local CallCool = {}      -- [callId] = 冷却截止（防重发）
local Incidents = {}  -- [incidentId] = {Id, Category, RecommendServices, Dispatched}
local Units = {}      -- [unitId] = {Id, Service, Status, AssignedIncidentId}
local Shop = nil      -- ShopData
local UnlockedDistricts = {}  -- [districtId] = true
local OwnedUpgrades = {}      -- [upgradeId] = true
local DistrictCool = {}       -- [districtId] = 冷却截止
local BoardCool = 0           -- 板子扩容冷却

-- 城区定义（GAME_CONFIG.Districts 快照，价格升序）
local DistrictList = {}
do
	local okCfg, cfg911 = pcall(require, N and Modules and Modules:FindFirstChild("NineOneOne_Config"))
	if okCfg and type(cfg911) == "table" and type(cfg911.Districts) == "table" then
		for _, d in ipairs(cfg911.Districts) do
			if type(d) == "table" and d.Id then
				DistrictList[#DistrictList + 1] = { Id = tostring(d.Id), Price = tonumber(d.Price) or 0, DisplayName = tostring(d.DisplayName or d.Id) }
			end
		end
	end
end
-- 板子升级链
local BOARD_SLOTS = { "ExtraIncidentSlot1", "ExtraIncidentSlot2", "ExtraIncidentSlot3" }

local RecentLog = {}  -- UI 日志
local function log(text)
	table.insert(RecentLog, 1, os.date("%H:%M:%S") .. " " .. text)
	if #RecentLog > 8 then table.remove(RecentLog) end
end

-- 单位名中文翻译
local UNIT_ZH = {
	PatrolCar = "巡逻车", Patrol = "巡逻车",
	Ambulance = "救护车", Medic = "救护车", EMS = "急救单元",
	Engine = "消防车", Pumper = "泵浦消防车", FireEngine = "消防车",
	Ladder = "云梯车", LadderTruck = "云梯车", TruckCo = "云梯车", Quint = "云梯救援车",
	Rescue = "救援车", HeavyRescue = "重型救援车",
	K9 = "警犬单元", K9Unit = "警犬单元",
	SWAT = "特警车", SWATVan = "特警车",
	Hazmat = "防化单元", HazmatUnit = "防化单元",
	Traffic = "交通执法车", TrafficUnit = "交通执法车",
	Helicopter = "直升机", PoliceHelicopter = "警用直升机", Air = "空中支援",
	Tanker = "水罐车", Tender = "水罐车", WaterTender = "水罐车",
	Brush = "越野消防车", BrushTruck = "越野消防车",
	Supervisor = "指挥车", SupervisorSUV = "主管指挥车", Command = "指挥车", CommandUnit = "指挥车",
	Battalion = "消防指挥车", Chief = "队长指挥车",
	Van = "警用大巴", PoliceVan = "警用大巴", Transport = "押运车",
	Boat = "消防艇", Marine = "水上单元",
	BombSquad = "排爆单元", Dive = "潜水救援", Water = "水上救援",
}
local function zhUnitName(unit)
	if type(unit) ~= "table" then return tostring(unit) end
	local key = tostring(unit.UnitType or unit.Id or "")
	local name = tostring(unit.DisplayName or unit.Name or key)
	if UNIT_ZH[key] then return UNIT_ZH[key] end
	for en, zh in pairs(UNIT_ZH) do
		if key:find(en, 1, true) or name:find(en, 1, true) then return zh end
	end
	return name
end
-- 商店条目 -> "中文 (类别)" 显示名
local function shopEntryLabel(unit)
	return zhUnitName(unit) .. " [" .. tostring(unit.ShopCategory or "?") .. "] $" .. tostring(unit.Cost or "?")
end

-- ================= Obsidian UI =================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()
local Window = Library:CreateWindow({
	Title = "911 调度助手",
	Footer = "v1.0 · 接听/调度/购买 三合一",
	ToggleKeybind = Enum.KeyCode.RightControl,
	Center = true,
	AutoShow = true,
})
local TabMain = Window:AddTab("主页", "home")
local TabStat = Window:AddTab("状态", "activity")
local TabSet = Window:AddTab("设置", "settings")

local grpMain = TabMain:AddLeftGroupbox("AI 总控")
grpMain:AddToggle("Enabled", {
	Text = "AI 自动游玩（总开关）",
	Default = true,
	Callback = function(v) State.Enabled = v end,
})
grpMain:AddLabel("快捷键：右Ctrl 显隐界面")

local grpFn = TabMain:AddRightGroupbox("功能开关")
grpFn:AddToggle("AutoAnswer", { Text = "自动接听（全对话+发CAD）", Default = true, Callback = function(v) State.AutoAnswer = v end })
grpFn:AddToggle("AutoDispatch", { Text = "自动调度（派单位去事故）", Default = true, Callback = function(v) State.AutoDispatch = v end })
grpFn:AddToggle("AutoBuy", { Text = "自动购买单位", Default = true, Callback = function(v) State.AutoBuy = v end })
grpFn:AddToggle("AutoStartShift", { Text = "自动开始值班（每日自动重开）", Default = true, Callback = function(v) State.AutoStartShift = v end })
grpFn:AddToggle("AutoDistrict", { Text = "自动扩展城区（钱够解锁最便宜的）", Default = true, Callback = function(v) State.AutoDistrict = v end })
grpFn:AddToggle("AutoBoard", { Text = "自动扩任务板（钱够买下一个槽位）", Default = true, Callback = function(v) State.AutoBoard = v end })

local grpParam = TabMain:AddLeftGroupbox("参数")
grpParam:AddSlider("DialogueStep", {
	Text = "对话选项间隔", Default = 0.9, Min = 0.01, Max = 2, Rounding = 2, Suffix = "秒",
	Callback = function(v) State.DialogueStep = v end,
})
grpParam:AddSlider("CashReserve", {
	Text = "购单位现金预留", Default = 0, Min = 0, Max = 50000, Rounding = 0, Suffix = "$",
	Callback = function(v) State.CashReserve = v end,
})

local grpBuy = TabMain:AddRightGroupbox("购买单位选择（勾选要买的）")
local buyDropdown = grpBuy:AddDropdown("BuySelection", {
	Values = { "（等待商店数据...）" },
	Default = {},
	Multi = true,
	Text = "要自动购买的单位",
	Tooltip = "从商店目录勾选要自动购买的单位类型",
	Callback = function(v)
		State.BuySelection = type(v) == "table" and v or {}
	end,
})
grpBuy:AddToggle("BuyAll", { Text = "未勾选时买全部可买", Default = true, Callback = function(v) State.BuyAll = v end })
grpBuy:AddButton({
	Text = "全选商店单位",
	Func = function()
		if type(Shop) == "table" and type(Shop.Units) == "table" then
			for _, u in ipairs(Shop.Units) do
				if type(u) == "table" then
					State.BuySelection[shopEntryLabel(u)] = true
				end
			end
		end
		log("已全选商店单位")
	end,
})
grpBuy:AddButton({
	Text = "清空选择",
	Func = function()
		State.BuySelection = {}
		pcall(function() buyDropdown:SetValues({}) end)
	end,
})

local grpStat = TabStat:AddLeftGroupbox("计数")
local lbl = {}
local function makeLabel(grp, key, text)
	lbl[key] = grp:AddLabel(text)
end
makeLabel(grpStat, "Answered", "已接来电：0")
makeLabel(grpStat, "Dialogue", "对话选项：0")
makeLabel(grpStat, "CAD", "CAD 提交：0")
makeLabel(grpStat, "Incidents", "事故总数：0")
makeLabel(grpStat, "Dispatched", "派遣次数：0")
makeLabel(grpStat, "Bought", "购买单位：0")
makeLabel(grpStat, "Shifts", "值班重开：0")
makeLabel(grpStat, "Districts", "扩城区：0")
makeLabel(grpStat, "Board", "扩任务板：0")
makeLabel(grpStat, "Calls", "进行中对话：0")
makeLabel(grpStat, "UnitsAvail", "可用单位：0")

local grpLog = TabStat:AddRightGroupbox("日志")
local lblLog = grpLog:AddLabel("-")

local grpHelp = TabSet:AddLeftGroupbox("说明")
grpHelp:AddLabel("接听：来电自动接起，全部问题按库顺序问完，最后自动提交 CAD 生成事故。")
grpHelp:AddLabel("调度：事故生成后自动派匹配服务的可用单位。")
grpHelp:AddLabel("购买：商店内可买可负担的单位自动购入。")
grpHelp:AddLabel("快捷键：右Ctrl 显隐 / P 总开关。")
grpHelp:AddButton({
	Text = "卸载脚本",
	Func = function()
		if g._N911_ASSIST_STOP then g._N911_ASSIST_STOP() end
		Library:Unload()
	end,
})

task.spawn(function()
	while true do
		task.wait(0.5)
		pcall(function()
			lbl.Answered:SetText("已接来电：" .. State.Stat.Answered)
			lbl.Dialogue:SetText("对话选项：" .. State.Stat.Dialogue)
			lbl.CAD:SetText("CAD 提交：" .. State.Stat.CAD)
			lbl.Incidents:SetText("事故总数：" .. State.Stat.Incidents)
			lbl.Dispatched:SetText("派遣次数：" .. State.Stat.Dispatched)
			lbl.Bought:SetText("购买单位：" .. State.Stat.Bought)
			lbl.Shifts:SetText("值班重开：" .. State.Stat.Shifts)
			lbl.Districts:SetText("扩城区：" .. State.Stat.Districts)
			lbl.Board:SetText("扩任务板：" .. State.Stat.Board)
			local nCalls = 0
			for _ in pairs(Calls) do nCalls += 1 end
			local nAvail = 0
			for _, u in pairs(Units) do
				if u.Status == "Available" then nAvail += 1 end
			end
			lbl.Calls:SetText("进行中对话：" .. nCalls)
			lbl.UnitsAvail:SetText("可用单位：" .. nAvail)
			lblLog:SetText(#RecentLog > 0 and table.concat(RecentLog, "\n") or "-")
		end)
	end
end)

-- ================= 监听器 =================
local function trackIncoming(call)
	if type(call) ~= "table" or call.Id == nil then return end
	local id = tostring(call.Id)
	local isNew = Calls[id] == nil
	call._answered = call._answered or (Calls[id] and Calls[id]._answered)
	call._choiceIdx = call._choiceIdx or (Calls[id] and Calls[id]._choiceIdx) or 0
	call._busy = call._busy or (Calls[id] and Calls[id]._busy)
	Calls[id] = call
	if isNew then
		CallOrder[#CallOrder + 1] = id
		log("来电 " .. tostring(call.TemplateId or id):sub(1, 40))
	end
end

local function connectEvents()
	local c1 = R("IncomingCall")
	if c1 then c1.OnClientEvent:Connect(function(call, ...) trackIncoming(call) end) end
	local c2 = R("CallUpdated")
	if c2 then c2.OnClientEvent:Connect(function(call, ...) trackIncoming(call) end) end
	local c3 = R("CallEnded")
	if c3 then c3.OnClientEvent:Connect(function(callId, ...)
		if callId then Calls[tostring(callId)] = nil end
	end) end
	local c4 = R("IncidentCreated")
	if c4 then c4.OnClientEvent:Connect(function(inc, ...)
		if type(inc) == "table" and inc.Id then
			local id = tostring(inc.Id)
			if Incidents[id] == nil then
				Incidents[id] = {
					Id = id,
					Category = inc.Category or inc.CallCategory,
					RequiredServiceCounts = inc.RequiredServiceCounts or {},
					SentCount = {},
					RecommendServices = inc.RecommendServices or (inc.ClientDisplay and inc.ClientDisplay.MapIcon),
					Dispatched = false,
				}
				State.Stat.Incidents += 1
				log("事故 " .. id:sub(1, 20) .. " (" .. tostring(inc.Category) .. ") 待派 需求:" .. HttpService:JSONEncode(inc.RequiredServiceCounts or {}))
			end
		end
	end) end
	local c5 = R("IncidentResolved")
	if c5 then c5.OnClientEvent:Connect(function(inc, ...)
		local id = type(inc) == "table" and tostring(inc.Id) or tostring(inc or "")
		Incidents[id] = nil
	end) end
	local c6 = R("UnitUpdated")
	if c6 then c6.OnClientEvent:Connect(function(payload, ...)
		if type(payload) ~= "table" then return end
		if payload.Mode == "FullList" and type(payload.Units) == "table" then
			Units = {}
			for _, u in ipairs(payload.Units) do
				if type(u) == "table" and u.Id then Units[tostring(u.Id)] = u end
			end
		elseif payload.Id then
			Units[tostring(payload.Id)] = payload
		end
	end) end
	local c7 = R("ShopUpdated")
	if c7 then c7.OnClientEvent:Connect(function(data, ...)
		if type(data) == "table" then
			Shop = data
			-- 刷新购买下拉选项（中文名列表）
			if type(data.Units) == "table" and buyDropdown then
				local labels = {}
				for _, u in ipairs(data.Units) do
					if type(u) == "table" then labels[#labels + 1] = shopEntryLabel(u) end
				end
				table.sort(labels)
				pcall(function() buyDropdown:SetValues(labels) end)
			end
		end
	end) end
	-- c8：FullStateUpdate（全量数据：OwnedUnits/ActiveIncidents/Cash/ShiftActive）
	local c8 = R("FullStateUpdate")
	if c8 then c8.OnClientEvent:Connect(function(st, ...)
		if type(st) ~= "table" then return end
		-- 单位表全量重建
		if type(st.OwnedUnits) == "table" then
			Units = {}
			for _, u in ipairs(st.OwnedUnits) do
				if type(u) == "table" and u.Id then Units[tostring(u.Id)] = u end
			end
		end
		-- 城区解锁表 / 已购升级表
		if type(st.UnlockedDistricts) == "table" then
			UnlockedDistricts = {}
			for _, d in ipairs(st.UnlockedDistricts) do UnlockedDistricts[tostring(d)] = true end
		end
		if type(st.OwnedUpgrades) == "table" then
			OwnedUpgrades = {}
			for k, v in pairs(st.OwnedUpgrades) do
				OwnedUpgrades[tostring(k)] = (v == true) or (tonumber(v) or 0) > 0
			end
		end
		-- 现金
		if st.Cash then
			if type(Shop) ~= "table" then Shop = {} end
			Shop.Cash = st.Cash
		end
		-- 自动开始值班：班次结束立即重开（10s 冷却防连发）
		if State.AutoStartShift and st.ShiftActive == false and os.clock() > (g._N911_SHIFT_COOL or 0) then
			local ss = R("StartShift")
			if ss then
				g._N911_SHIFT_COOL = os.clock() + 10
				ss:FireServer()
				State.Stat.Shifts += 1
				log("班次已结束，自动重新开始值班（第 " .. State.Stat.Shifts .. " 次）")
			end
		end
		-- 活跃事故表（含需求），并清理已解决的
		if type(st.ActiveIncidents) == "table" then
			local present = {}
			for _, inc in ipairs(st.ActiveIncidents) do
				if type(inc) == "table" and inc.Id then
					local id = tostring(inc.Id)
					present[id] = true
					if Incidents[id] == nil then
						Incidents[id] = {
							Id = id,
							Category = inc.Category or inc.CallCategory,
							RequiredServiceCounts = inc.RequiredServiceCounts or {},
							SentCount = {},
							Dispatched = false,
						}
						State.Stat.Incidents += 1
						log("事故 " .. id:sub(1, 20) .. " (" .. tostring(inc.Category) .. ") 待派")
					else
						Incidents[id].RequiredServiceCounts = inc.RequiredServiceCounts or Incidents[id].RequiredServiceCounts
					end
				end
			end
			for id in pairs(Incidents) do
				if not present[id] then Incidents[id] = nil end
			end
		end
	end) end
end
connectEvents()

-- 服务器→客户端的接听确认（PlayerAnsweredCall 也回显）：本地标记
local answeredConn
do
	local r = R("PlayerAnsweredCall")
	if r then
		answeredConn = r.OnClientEvent:Connect(function(call, ...)
			trackIncoming(call)
		end)
	end
end

-- ================= 核心动作 =================
local function fireAnswered(callId)
	local r = R("PlayerAnsweredCall")
	if r then r:FireServer(callId) end
end

local function fireDialogue(callId, choiceId, cfg)
	local r = R("PlayerSelectedDialogue")
	if r then r:FireServer(callId, choiceId, cfg) end
end

local function fireDispatch(incidentId, unitIds)
	local r = R("DispatchUnits")
	if r then r:FireServer({ IncidentId = incidentId, UnitIds = unitIds }) end
end

local function fireBuy(unitId)
	local r = R("BuyUnit")
	if r then r:FireServer(unitId) end
end

-- 接听 + 全对话 + CAD：v1.4b —— 本地接听去重（fire 过不再发）+ 双参数 + Dispatcher 发言数作进度
local AnsweredSet = {} -- [callId] = true（本地已 fire 接听）

local function countDispatcherLines(call)
	local n = 0
	if type(call.Conversation) == "table" then
		for _, m in ipairs(call.Conversation) do
			if type(m) == "table" and m.Speaker == "Dispatcher" then n += 1 end
		end
	end
	return n
end

local function stepDialogue()
	for _, callId in ipairs(CallOrder) do
		local call = Calls[callId]
		if type(call) ~= "table" then
			Calls[callId] = nil
		else
			local id = tostring(call.Id or callId)
			local status = tostring(call.Status or "")
			local flags = call.Flags or {}
			local serverAnswered = (tonumber(call.AnsweredAt) or 0) > 0
			-- 1) 接听：响铃中、本地没 fire 过、未被自动话务处理
			if status == "Ringing" and not AnsweredSet[id] and not serverAnswered and call.AutoCalltakerProcessing ~= true then
				AnsweredSet[id] = true
				local r = R("PlayerAnsweredCall")
				if r then r:FireServer(id, call) end -- 源码 OnAnswer(Id, call) 双参数
				State.Stat.Answered += 1
				CallCool[id] = os.clock() + math.max(State.DialogueStep, 0.05)
				log("已自动接听 " .. tostring(call.IncidentDisplayTitle or id):sub(1, 30))
				return true
			end
			-- 2) 对话推进：确认驱动——以服务器 ChoicesUsed 为唯一进度真相
			if (AnsweredSet[id] or serverAnswered) and status ~= "Ended" and not flags.CreatedIncident and call.TemplateId then
				if (CallCool[id] or 0) > os.clock() then
					-- 冷却中：等服务器确认
				else
					local def = CallLib[tostring(call.TemplateId)]
					if def then
						local choices = orderedChoices(def)
						-- 进度真相 = Conversation 里 Dispatcher 发言数（每提交一个选项产生一条问句/建议）
						-- ChoicesUsed 只统计详情问题，不覆盖 ASK_LOCATION/ADVISE，弃用
						local asked = countDispatcherLines(call)
						local localSent = LocalProgress[id] or 0
						local usedN = math.max(asked, localSent)
						if usedN >= #choices then
							-- 全部选项已提交，等 CreatedIncident
						else
							-- 提交下一个选项
							local choice = choices[usedN + 1]
							if choice then
								local cfg = {
									Priority = def.Priority or "Low",
									Services = {
										Police = (def.RequiredServiceCounts and def.RequiredServiceCounts.Police) or 0,
										Fire = (def.RequiredServiceCounts and def.RequiredServiceCounts.Fire) or 0,
										EMS = (def.RequiredServiceCounts and def.RequiredServiceCounts.EMS) or 0,
									},
								}
								local isLast = (usedN + 1) >= #choices
								fireDialogue(id, tostring(choice.Id), cfg)
								LocalProgress[id] = usedN + 1
								CallCool[id] = os.clock() + math.max(State.DialogueStep, 0.05)
								State.Stat.Dialogue += 1
								if isLast then
									State.Stat.CAD += 1
									log("CAD 提交（" .. tostring(call.IncidentDisplayTitle or id):sub(1, 24) .. "）")
								else
									log("对话 " .. (usedN + 1) .. "/" .. #choices .. " " .. tostring(choice.Id):sub(1, 26))
								end
								return true
							end
						end
						-- 全部用完但 CreatedIncident 未回：等服务器
					elseif not call._unknownLogged then
						call._unknownLogged = true
						log("未知模板 " .. tostring(call.TemplateId):sub(1, 30))
					end
				end
			end
		end
	end
	return false
end

-- 派遣：按事故的 RequiredServiceCounts 逐服务补派缺口（Multi 事故各服务分别派）
local function stepDispatch()
	for incId, inc in pairs(Incidents) do
		local req = inc.RequiredServiceCounts
		if type(req) ~= "table" then
			-- 兜底：按 Category 派一个
			req = { [inc.Category or "Police"] = 1 }
		end
		inc.SentCount = inc.SentCount or {}
		local toSend = {}
		local allSatisfied = true
		for service, need in pairs(req) do
			need = tonumber(need) or 0
			if need > 0 then
				local sent = tonumber(inc.SentCount[service]) or 0
				local missing = need - sent
				if missing > 0 then
					allSatisfied = false
					for _, u in pairs(Units) do
						if missing > 0 and tostring(u.Service) == service and u.Status == "Available" and u.AssignedIncidentId == nil then
							toSend[#toSend + 1] = u.Id
							missing -= 1
						end
					end
				end
			end
		end
		if #toSend > 0 then
			fireDispatch(incId, toSend)
			-- 记账（按 UnitType 对应服务粗记：直接把本次发送数摊到缺的服务上）
			for service, need in pairs(req) do
				need = tonumber(need) or 0
				local sent = tonumber(inc.SentCount[service]) or 0
				if need - sent > 0 then
					inc.SentCount[service] = math.min(need, sent + #toSend)
					break
				end
			end
			State.Stat.Dispatched += 1
			local names = {}
			for _, uid in ipairs(toSend) do
				names[#names + 1] = zhUnitName(Units[uid] or { Id = uid })
			end
			log("派遣 " .. #toSend .. " 单位（" .. table.concat(names, "、") .. "）→ " .. incId:sub(1, 18))
			return true
		end
		if allSatisfied and not inc.Dispatched then
			inc.Dispatched = true
		end
	end
	return false
end

-- 购买：商店 CanBuy 且可负担（现金 - 预留）；按用户勾选过滤，未勾选时按 BuyAll
local function stepBuy()
	if type(Shop) ~= "table" or type(Shop.Units) ~= "table" then return false end
	local cash = tonumber(Shop.Cash) or 0
	for _, unit in ipairs(Shop.Units) do
		if type(unit) == "table" and unit.Id then
			local label = shopEntryLabel(unit)
			local want = State.BuyAll or State.BuySelection[label] == true
			local canBuy = unit.CanBuy == true
			local afford = cash - State.CashReserve >= (tonumber(unit.Cost) or math.huge)
			if want and canBuy and afford then
				fireBuy(unit.Id)
				State.Stat.Bought += 1
				log("购买单位：" .. zhUnitName(unit) .. "（$" .. tostring(unit.Cost or "?") .. "）")
				return true
			end
		end
	end
	return false
end

-- 自动扩展城区：按价格升序找未解锁的，钱够就 BuyDistrict（服务器校验等级/相邻，被拒进冷却不刷）
local function stepDistrict()
	if type(Shop) ~= "table" then return false end
	local cash = tonumber(Shop.Cash) or 0
	for _, d in ipairs(DistrictList) do
		if not UnlockedDistricts[d.Id] and d.Price > 0 then
			if cash - State.DistrictReserve >= d.Price then
				if (DistrictCool[d.Id] or 0) <= os.clock() then
					local r = R("BuyDistrict")
					if r then
						r:FireServer(d.Id)
						DistrictCool[d.Id] = os.clock() + 30
						State.Stat.Districts += 1
						log("扩展城区：" .. d.DisplayName .. "（$" .. d.Price .. "）")
						return true
					end
				end
				return false -- 钱够但在冷却，等下一轮
			end
			return false -- 最便宜的未解锁城区钱不够，后面的更贵不用看
		end
	end
	return false
end

-- 自动扩任务板：ExtraIncidentSlot1→2→3 顺序买（钱够就买下一个）
local function stepBoard()
	if type(Shop) ~= "table" or type(Shop.Upgrades) ~= "table" then return false end
	local cash = tonumber(Shop.Cash) or 0
	local shopCost = {}
	for _, up in ipairs(Shop.Upgrades) do
		if type(up) == "table" and up.Id then shopCost[tostring(up.Id)] = tonumber(up.Cost) end
	end
	for _, slotId in ipairs(BOARD_SLOTS) do
		if not OwnedUpgrades[slotId] then
			local cost = shopCost[slotId] or 3250
			if cash - State.DistrictReserve >= cost then
				if BoardCool <= os.clock() then
					local r = R("BuyUpgrade")
					if r then
						r:FireServer(slotId)
						BoardCool = os.clock() + math.max(State.DialogueStep, 0.5)
						State.Stat.Board += 1
						log("扩任务板：" .. slotId .. "（$" .. cost .. "）")
						return true
					end
				end
				return false -- 冷却中
			end
			return false -- 钱不够，后面更贵
		end
	end
	return false
end

-- ================= 主循环 =================
local stopped = false
g._N911_ASSIST_STOP = function() stopped = true end
g._N911_STATE = State      -- 远程诊断句柄
g._N911_TABLES = function() return Calls, Incidents, Units, Shop end

local RF_FullState = R("GetFullState")
local RD_Refresh = R("RequestDataRefresh")
local lastFullPoll = 0

task.spawn(function()
	task.wait(1)
	local lastBeat = 0
	while not stopped do
		if State.Enabled then
			-- 每 3s 触发一次 RequestDataRefresh → 服务器推 FullStateUpdate（单位/事故/现金全量）
			if RD_Refresh and os.clock() - lastFullPoll > 3 then
				lastFullPoll = os.clock()
				pcall(function() RD_Refresh:FireServer() end)
			end
			local acted = false
			pcall(function()
				if State.AutoAnswer then acted = stepDialogue() or acted end
				if State.AutoDispatch then acted = stepDispatch() or acted end
				if State.AutoBuy then acted = stepBuy() or acted end
				if State.AutoDistrict then acted = stepDistrict() or acted end
				if State.AutoBoard then acted = stepBoard() or acted end
			end)
			-- 心跳（每 6s 一条，确认循环活着）
			if os.clock() - lastBeat > 6 then
				lastBeat = os.clock()
				local nCalls = 0
				for _ in pairs(Calls) do nCalls += 1 end
				log("运行中：对话 " .. nCalls .. " | 事故 " .. (function() local n = 0 for _ in pairs(Incidents) do n += 1 end return n end)() .. " | 单位 " .. (function() local n = 0 for _ in pairs(Units) do n += 1 end return n end)())
			end
			task.wait(acted and State.DialogueStep or 0.6)
		else
			task.wait(0.4)
		end
	end
end)

Library:Notify("911 调度助手 v1.1 已加载（全自动）", 4)
print("[911调度助手] v1.1 加载完成，对话库 " .. (function() local n = 0 for _ in pairs(CallLib) do n += 1 end return n end)() .. " 个模板")
