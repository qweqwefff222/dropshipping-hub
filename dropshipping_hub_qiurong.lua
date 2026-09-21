--[[
	代发货大亨 · 订单驱动流水线 Hub v3.2    作者: b站英吉利超入
	UI: 秋容UI框架（提取自秋容脚本VIP）    快捷键: 右Shift 开关窗口
	状态机: New -> AcceptOrder ｜ Ready to Pack -> 取原包 / 上带
	        ｜ Being Packed -> 取成品箱 / 交快递员 ｜ Ready for Courier -> 等结算
	纯远程(与位置无关): 接单 / 买货 / 解锁 / 广告 / 招聘 / 领取
	需微传送到位(服务端校验 12 格): 取货 / 上带 / 取成品 / 交件 / 物理升级点
	⚠ 触发后不能立刻回位，要停在原地等状态确认（服务端读的是服务器端坐标）
--]]

--=====================================================================
-- 0. 环境
--=====================================================================
local STATE = (typeof(STATE) == "table") and STATE or {
	onCleanup = function() end,
	connect   = function(sig, fn) return sig:Connect(fn) end,
	alive     = function() return true end,
}
local ENABLED = STATE.alive()

-- 前向声明：单例清理闭包必须引用它们，所以要先作为局部 upvalue 存在
local Window, HUD

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local RunSvc  = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local Http    = game:GetService("HttpService")
local plr     = Players.LocalPlayer

local Notify   -- 前向声明：秋容UI就绪后由兼容层填充实现
local Log = {}
local function log(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	local line = table.concat(parts, " ")
	Log[#Log + 1] = string.format("[%s] %s", os.date("%H:%M:%S"), line)
	while #Log > 200 do table.remove(Log, 1) end
	print("[DropHub]", line)
end

local function safe(fn, ...)
	local ok, res = pcall(fn, ...)
	if not ok then log("ERR " .. tostring(res)) end
	return ok, res
end

-- 单例保护：同一脚本被加载两次（执行器手载 + 工具重载）会变成双份触发，
-- 真的会双倍花钱。加载时先把上一个实例卸掉并让它自杀。
local GENV = (getgenv and getgenv()) or _G
if type(GENV.__DropshipHubDispose) == "function" then
	pcall(GENV.__DropshipHubDispose)
	log("检测到旧实例，已先卸载")
end
local dispose
dispose = function()
	ENABLED = false
	if Window then safe(function() Window:Destroy() end) end
	if _G.QiuRongUI and _G.QiuRongUI.UI and _G.QiuRongUI.UI.Destroy then
		safe(function() _G.QiuRongUI.UI.Destroy() end)
	end
	if HUD and HUD.gui then safe(function() HUD.gui:Destroy() end) end
	if GENV.__DropshipHubDispose == dispose then GENV.__DropshipHubDispose = nil end
end
GENV.__DropshipHubDispose = dispose

local function fmt(n)
	n = tonumber(n)
	if not n then return tostring(n or "—") end
	if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(math.floor(n))
end

local function keysOf(t)
	local r = {}
	if type(t) == "table" then for k in pairs(t) do r[#r + 1] = tostring(k) end end
	table.sort(r)
	return r
end

local function deepcopy(t)
	if type(t) ~= "table" then return t end
	local r = {}
	for k, v in pairs(t) do r[k] = deepcopy(v) end
	return r
end

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

--=====================================================================
-- 1. 配置（自管，存盘）
--=====================================================================
local CFG_FILE = "DropshipHub_v3.json"

local DEFAULTS = {
	pipe = {
		ver = 2,
		on = false,
		restore = true,      -- 触发完把角色放回原处
		boost = true,        -- 拉大提示点交互距离 + 关视线校验
		tpHeight = 2.5,
		-- ⚠ 实机标定（v3.2）：真正会丢动作的不是 preWait，而是"触发完立刻回位"。
		--   服务端做距离校验时读的是服务器端坐标，人已经闪回去 -> 判定距离不足 -> 丢弃。
		preWait = 0.30,
		postWait = 0.30,
		gap = 0.30, autoRestock = true,
	},
	ac = {
		on = false, priority = "价格最高优先", viralOnly = false,
		minPrice = 0, maxPrice = 0, maxActive = 1, interval = 0.8,
		useWhite = false, white = {}, black = {},
	},
	restock = {
		on = false, mode = "跟随进行中订单", product = "",
		low = 2, batch = 5, interval = 8, cashFloor = 60,
	},
	hud = { on = true, x = 16, y = 330 },
	buyprod = {
		on = false, maxPrice = 0, cashFloor = 200, interval = 6,
		allow = {}, deny = {},
	},
	hire = {
		on = false, interval = 6, cashFloor = 300, maxPrice = 0,
		minLevel = "无要求", roles = {}, denyRoles = {},
		autoWorkerSlot = true, autoRefresh = false, gemFloor = 0,
	},
	ad = {
		on = false, interval = 5, duration = 600,
		productMode = "跟随广告位", product = "",
		maxCost = 0, cashFloor = 200, minLeft = 30, autoSelect = true,
		viralFollow = false,
	},
	-- 保护模式：现金低于阈值时自动停掉一切花钱模块（流水线照常跑）
	guard = { on = true, cashFloor = 150 },
	sched = {
		questBoost = true, contractBoost = true,
		selfHeal = true, hourlyReport = true,
	},
	maint = {
		logFile = false, logInterval = 30,
		gateRecheck = true, recheckInterval = 600,
	},
	conv = {
		auto = true, count = 1, level = 0, maxCount = 3,
		autoUpgrade = false, upgradeFloor = 300,
	},
	ai = {
		on = false, interval = 10, style = "标准",
		timing = true, restock = true, concurrency = true,
		budget = true, adPace = true, conveyorAware = true,
		preWaitMin = 0.18, preWaitMax = 0.60, note = "待机",
	},
	ops = {
		claim = false, claimInterval = 20,
		vacation = false, vacThreshold = 60, vacInterval = 30,
		train = false, trainInterval = 30, trainFloor = 200,
		research = false, researchInterval = 60, researchFloor = 300,
		contract = false, contractInterval = 60,
	},
	view = {
		theme = "Dark", uiScale = 1, transparency = false,
		bgTransparency = 0.1, acrylic = false, panelBg = true,
		width = 660, height = 520, resizable = true,
		bgImage = "", toggleKey = "RightShift",
	},
}

local cfg = deepcopy(DEFAULTS)

local function mergeInto(dst, src)
	for k, v in pairs(src or {}) do
		if type(v) == "table" and type(dst[k]) == "table" then
			mergeInto(dst[k], v)
		else
			dst[k] = v
		end
	end
end

safe(function()
	if isfile and isfile(CFG_FILE) then
		mergeInto(cfg, Http:JSONDecode(readfile(CFG_FILE)))
		log("配置已载入")
	end
end)

local cfgDirty = false
local function cfgTouch() cfgDirty = true end
local function cfgSave(force)
	if not cfgDirty and not force then return end
	cfgDirty = false
	safe(function()
		if writefile then writefile(CFG_FILE, Http:JSONEncode(cfg)) end
	end)
end

safe(function()
	local v = tonumber(cfg.pipe.ver) or 0
	if v < 2 then
		cfg.pipe.preWait  = math.max(tonumber(cfg.pipe.preWait)  or 0, 0.30)
		cfg.pipe.postWait = math.max(tonumber(cfg.pipe.postWait) or 0, 0.30)
		cfg.pipe.ver = 2
		cfgDirty = true
		log("配置迁移 -> v2（时序抬到安全值）")
	end
end)

--=====================================================================
-- 2. 游戏接口层
--=====================================================================
local Remotes = RS:FindFirstChild("Remotes") or RS:WaitForChild("Remotes", 10)
local S = {}
local STATEPush = 0   -- 最后一次收到 StateUpdate 的时间（自愈判据）

local function requestState()
	if Remotes and Remotes:FindFirstChild("RequestState") then
		safe(function() Remotes.RequestState:FireServer() end)
	end
end
if Remotes and Remotes:FindFirstChild("StateUpdate") then
	STATE.connect(Remotes.StateUpdate.OnClientEvent, function(t)
		S = t or {}
		STATEPush = os.clock()   -- 自愈用：记录最后一次收到服务端状态的时间
	end)
end

local function plotName() return plr:GetAttribute("TycoonArea") end
local function getPlot()
	local area = plotName()
	local plots = workspace:FindFirstChild("Plots")
	if not area or not plots then return nil end
	return plots:FindFirstChild(area)
end
local function getHRP()
	local ch = plr.Character
	return ch and ch:FindFirstChild("HumanoidRootPart") or nil
end
local function carrying() return tostring(S.carrying or "none") end

local FULFIL = {
	["Ready to Pack"] = true,
	["Being Packed"] = true,
	["Ready for Courier"] = true,
}

local function orderById(id)
	if id == nil then return nil end
	for _, o in pairs(S.orders or {}) do
		if tostring(o.id) == tostring(id) then return o end
	end
	return nil
end
local function countStatus(st)
	local n = 0
	for _, o in pairs(S.orders or {}) do if tostring(o.status) == st then n = n + 1 end end
	return n
end
-- ⚠ 实机标定（v3.2 关键修复）：判断"还能不能接新单"必须看服务端的
--   原因：订单进入 Ready for Courier（包裹已交到快递员位）时，服务端就已经
local function activeCount()
	local af = S.activeFulfillments
	if type(af) == "table" then
		-- ⚠ 服务端给了这个字段就一律以它为准 —— 空表就是真的 0（槽位已释放）。
		local n = 0
		for _ in pairs(af) do n = n + 1 end
		return n
	end
	-- 只有服务端根本没给这个字段时，才退回按状态数估算
	local n = 0
	for _, o in pairs(S.orders or {}) do if FULFIL[tostring(o.status)] then n = n + 1 end end
	return n
end
local function maxActive() return math.max(1, tonumber(S.maxFulfillments) or 1) end

local function productList()
	local set = {}
	for k in pairs(S.productPrices or {}) do set[tostring(k)] = true end
	for k, v in pairs(S.unlocked or {}) do if v then set[tostring(k)] = true end end
	for k in pairs(cfg.ac.white or {}) do set[tostring(k)] = true end
	for k in pairs(cfg.ac.black or {}) do set[tostring(k)] = true end
	if S.activeProduct then set[tostring(S.activeProduct)] = true end
	local list = {}
	for k in pairs(set) do list[#list + 1] = k end
	table.sort(list)
	if #list == 0 then list = { "LedStrip" } end
	return list
end

--=====================================================================
-- 3. 提示点索引
--=====================================================================
local Prompt = { list = {}, at = 0 }

local function scanPrompts()
	Prompt.list = {}
	local function walk(root)
		if not root then return end
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Enabled and d.Parent and d.Parent:IsA("BasePart") then
				Prompt.list[#Prompt.list + 1] = d
				-- 可选：拉大交互距离并关掉视线校验。
				if cfg.pipe.boost then
					pcall(function()
						if d.MaxActivationDistance < 200 then d.MaxActivationDistance = 200 end
						d.RequiresLineOfSight = false
					end)
				end
			end
		end
	end
	walk(getPlot())
	walk(workspace:FindFirstChild("LocalWarehouseStock"))
	Prompt.at = os.clock()
end
local function scanThrottled(iv)
	if os.clock() - Prompt.at >= (iv or 0.35) then scanPrompts() end
end
local function findPrompt(text, filter)
	for _, d in ipairs(Prompt.list) do
		if d.ActionText == text and (not filter or filter(d)) then return d end
	end
	return nil
end
local function isInLWS(d)
	local w = workspace:FindFirstChild("LocalWarehouseStock")
	return w ~= nil and d:IsDescendantOf(w)
end
local function isInPlot(d)
	local p = getPlot()
	return p ~= nil and d:IsDescendantOf(p)
end

--=====================================================================
-- 3.5 保护模式 / 失败退避 / 会话统计
--     （必须放在 §4 之前：§5 的补货等花钱入口都要用 guardBlock）
--=====================================================================
local Guard = { blocked = false }

-- 现金低于阈值时停掉一切"会花钱"的模块，只保留流水线本体。
-- 买货也一并受保护，否则低现金时越买越穷。
local function guardRefresh()
	local low = cfg.guard.on and (tonumber(S.cash) or 0) < (tonumber(cfg.guard.cashFloor) or 0)
	if low ~= Guard.blocked then
		Guard.blocked = low
		log(low and string.format("保护模式开启：现金 %s < %s，暂停花钱模块",
			fmt(S.cash), fmt(cfg.guard.cashFloor)) or "保护模式解除：恢复花钱模块")
	end
end
local function guardBlock() return Guard.blocked end

-- 没有退避就会每个周期都发一次无效远程并刷屏日志，这里做指数退避。
local Backoff = {}
local function backoffWait(key)
	local b = Backoff[key]
	if not b then return 0 end
	local left = b.expires - os.clock()
	return left > 0 and left or 0
end
local function backoffFail(key, label)
	local b = Backoff[key] or { fails = 0 }
	b.fails = b.fails + 1
	local wait = math.min(1800, 20 * (2 ^ math.min(b.fails - 1, 6)))
	-- 注意：不能叫 b.until —— until 是 Lua 保留字，会直接语法错误
	b.expires = os.clock() + wait
	Backoff[key] = b
	return string.format("%s 未被服务端接受（第 %d 次，%d 秒后重试）", label, b.fails, math.floor(wait))
end
local function backoffReset(key) Backoff[key] = nil end

-- 会话统计：只统计"现金净增长"，用于看板的收益 / 效率指标
local Stat = { startAt = os.clock(), lastCash = nil, gain = 0 }

local function statTick()
	local cash = tonumber(S.cash) or 0
	if Stat.lastCash then
		local d = cash - Stat.lastCash
		if d > 0 then Stat.gain = Stat.gain + d end
	end
	Stat.lastCash = cash
end
local function statHours()
	return math.max(1 / 60, (os.clock() - Stat.startAt) / 3600)
end

local Sched

--=====================================================================
-- 4. 执行引擎（传送到位 -> 触发 -> 回原位）
--=====================================================================
local Exe = { lastAction = 0, stats = { total = 0, fail = 0 } }

local PRE_FLOOR  = 0.18   -- preWait 运行时下限，防止滑块改坏
local HOLD_MAX   = 1.4    -- 触发后最多留在原地等确认多久（秒）
local HOLD_RETRY = 0.9    -- 没确认时原地补一枪，再等多久

-- 留在原地等 confirmFn 返回 true；没给确认条件就当成功
-- 每 0.2s 主动 requestState 拉一次，避免只依赖服务端推送导致确认永远等不到
local function holdUntil(confirmFn, limit)
	if not confirmFn then return true end
	local t0, tPoll = os.clock(), 0
	while os.clock() - t0 < limit do
		if confirmFn() then return true end
		if os.clock() - tPoll >= 0.2 then
			tPoll = os.clock()
			requestState()
		end
		task.wait(0.05)
	end
	return false
end

local function canAct()
	local now = os.clock()
	if now - Exe.lastAction < cfg.pipe.gap then return false end
	Exe.lastAction = now
	return true
end

-- 传送到提示点旁 -> 等坐标同步 -> 触发 -> 留在原地等状态确认 -> 回原处
-- ⚠ 实机标定（v3.2）：真正丢动作的不是 preWait，而是"触发完立刻回位"。
--   服务端做距离校验时读的是服务器端坐标，人已经闪回去了 -> 判定距离不足 -> 丢弃。
--   所以触发后必须留在原地等确认；没确认就原地补一枪。
local function fireNear(prompt, confirmFn)
	if not prompt or not prompt.Parent or not prompt.Parent:IsA("BasePart") then return false end
	local hrp = getHRP()
	if not hrp then return false end
	local save = hrp.CFrame
	safe(function()
		hrp.CFrame = CFrame.new(prompt.Parent.Position + Vector3.new(0, cfg.pipe.tpHeight, 0))
	end)
	local pre = math.max(tonumber(cfg.pipe.preWait) or 0, PRE_FLOOR)
	task.wait(pre)
	safe(function() fireproximityprompt(prompt) end)
	-- ok 语义 = 动作是否被服务端确认（没人给确认条件时按成功算）
	local ok = holdUntil(confirmFn, HOLD_MAX)
	if not ok then
		safe(function() fireproximityprompt(prompt) end)
		ok = holdUntil(confirmFn, HOLD_RETRY)
	end
	if confirmFn then
		Exe.stats.total = Exe.stats.total + 1
		if not ok then Exe.stats.fail = Exe.stats.fail + 1 end
	end
	if cfg.pipe.restore then
		if cfg.pipe.postWait > 0 then task.wait(cfg.pipe.postWait) end
		local h2 = getHRP()
		if h2 then safe(function() h2.CFrame = save end) end
	end
	return ok
end

-- 返回 true = 已发出动作；false = 无提示点 / 节流中
local function actPrompt(prompt, confirmFn)
	if not prompt then return false end
	if not canAct() then return false end
	local _, confirmed = fireNear(prompt, confirmFn)
	return true, confirmed
end

-- 提示：WarehouseStockTake 远程服务端同样校验距离，远距离发无效，
--       必须角色真的靠近箱子，所以走"传送到箱子旁 -> 触发 -> 回原位"。
local function pickRaw()
	local p = findPrompt("Pick up package", isInLWS)
	if p then
		actPrompt(p, function() return carrying() ~= "none" end)
		return true
	end
	return false
end

local function acceptOrder(id)
	if not Remotes or not Remotes:FindFirstChild("AcceptOrder") then return false end
	local ok = safe(function() Remotes.AcceptOrder:FireServer(id) end)
	if ok then log("自动接单 #" .. tostring(id)) end
	return ok
end

--=====================================================================
-- 5. 补货
--=====================================================================
local Rst = { at = 0, last = "待机" }

local function stockOf(pid)
	local inv = S.inventory
	if type(inv) == "table" then
		if pid and pid ~= "" then
			local v = inv[pid]
			if v ~= nil then return tonumber(v) or 0 end
			return 0
		end
		local n = 0
		for _, v in pairs(inv) do n = n + (tonumber(v) or 0) end
		if n > 0 then return n end
	end
	return tonumber(S.warehouse) or 0
end

local function restockProduct()
	if Sched and Sched.prefProducts then
		for pid in pairs(Sched.prefProducts) do
			if stockOf(pid) <= 0 then return pid end
		end
	end
	local m = cfg.restock.mode
	if m == "指定产品" and cfg.restock.product ~= "" then return cfg.restock.product end
	if m == "跟随当前产品" then
		return S.activeProduct and tostring(S.activeProduct) or nil
	end
	for _, o in pairs(S.orders or {}) do
		if FULFIL[tostring(o.status)] and o.product then return tostring(o.product) end
	end
	for _, o in pairs(S.orders or {}) do
		if tostring(o.status) == "New" and o.product then return tostring(o.product) end
	end
	return S.activeProduct and tostring(S.activeProduct) or nil
end

local function doRestock(force)
	local rem = Remotes and Remotes:FindFirstChild("BuySupply")
	if not rem then return false, "无 BuySupply" end
	-- ⚠ 流水线（缺货自动买货）和补货线程都会调这里，两条路径合用一个节流，
	--   否则会在同一秒内重复下单（真花钱）。
	if not force and guardBlock() then return false, "保护模式：现金过低，暂停买货" end
	local now = os.clock()
	local gap = math.max(2, (tonumber(cfg.restock.interval) or 8) * 0.5)
	if not force and now - Rst.at < gap then
		return false, "补货节流中"
	end
	local pid = restockProduct()
	if not pid then return false, "未确定补货产品" end
	local stock = stockOf(pid)
	if not force and stock >= cfg.restock.low then
		return false, string.format("%s 库存 %d ≥ 阈值 %d", pid, stock, cfg.restock.low)
	end
	local cash = tonumber(S.cash) or 0
	if not force and cash < cfg.restock.cashFloor then
		return false, string.format("现金 %s 低于下限 %s", fmt(cash), fmt(cfg.restock.cashFloor))
	end
	if not canAct() then return false, "节流中" end
	local qty = math.max(1, math.floor(cfg.restock.batch))
	Rst.at = now
	local ok = safe(function() rem:FireServer(pid, qty) end)
	if ok then
		local msg = string.format("已补货 %s ×%d（原库存 %d）", pid, qty, stock)
		log(msg)
		return true, msg
	end
	return false, "补货调用失败"
end

--=====================================================================
-- 5.5 自动购买 / 自动招聘 / 自动广告
--      （接口签名均实机标定，见每处注释）
--=====================================================================
local G = { jobs = nil, employees = nil, campaign = nil,
	quest = nil, daily = nil, contract = nil, research = nil, viral = nil }

local function requestJobs()
	if Remotes and Remotes:FindFirstChild("RequestJobs") then
		safe(function() Remotes.RequestJobs:FireServer() end)
	end
end
local function requestEmployees()
	if Remotes and Remotes:FindFirstChild("RequestEmployees") then
		safe(function() Remotes.RequestEmployees:FireServer() end)
	end
end
local function requestCampaigns()
	if Remotes and Remotes:FindFirstChild("RequestCampaigns") then
		safe(function() Remotes.RequestCampaigns:FireServer() end)
	end
end
local function requestQuest()
	if Remotes and Remotes:FindFirstChild("QuestRequest") then
		safe(function() Remotes.QuestRequest:FireServer() end)
	end
end
local function requestDaily()
	if Remotes and Remotes:FindFirstChild("DailyRequest") then
		safe(function() Remotes.DailyRequest:FireServer() end)
	end
end
local function requestContract()
	if Remotes and Remotes:FindFirstChild("ContractRequest") then
		safe(function() Remotes.ContractRequest:FireServer() end)
	end
end
local function requestResearch()
	if Remotes and Remotes:FindFirstChild("ResearchRequest") then
		safe(function() Remotes.ResearchRequest:FireServer() end)
	end
end
local function requestViral()
	if Remotes and Remotes:FindFirstChild("ViralRequest") then
		safe(function() Remotes.ViralRequest:FireServer() end)
	end
end
-- 这些都是「免费拉取」，和花宝石的 RefreshJobs「重掷候选」是两回事
safe(function()
	if not Remotes then return end
	local pairsList = {
		{ "JobState", "jobs" }, { "EmployeeState", "employees" }, { "CampaignState", "campaign" },
		{ "QuestState", "quest" }, { "DailyState", "daily" }, { "ContractState", "contract" },
		{ "ResearchState", "research" }, { "ViralState", "viral" },
	}
	for _, p in ipairs(pairsList) do
		local inst = Remotes:FindFirstChild(p[1])
		if inst then
			STATE.connect(inst.OnClientEvent, function(t) G[p[2]] = t end)
		end
	end
end)

local function cashNow() return tonumber(S.cash) or 0 end
local function gemsNow() return tonumber(S.gems) or 0 end
local function passList(list, id, emptyMeansAll)
	if type(list) == "table" then
		if next(list) == nil then return emptyMeansAll ~= false end
		return list[id] == true
	end
	return emptyMeansAll ~= false
end

-- ---------------------------------------------------------------- 商品解锁
-- 实机标定：UnlockProduct(productId:string)。已拥有时调用是空操作。
local BuyProd = { at = 0, last = "待机", count = 0 }

local function productCandidates()
	local out, owned = {}, {}
	for k, v in pairs(S.unlocked or {}) do if v then owned[tostring(k)] = true end end
	for pid, price in pairs(S.productPrices or {}) do
		pid = tostring(pid)
		if not owned[pid] then out[#out + 1] = { id = pid, price = tonumber(price) or 0 } end
	end
	table.sort(out, function(a, b) return a.price < b.price end)
	return out
end

local function productPicks()
	local out = {}
	-- 任务加速：任务要"解锁商品"时放宽单价上限（现金下限照旧）
	local questWantsUnlock = cfg.sched.questBoost and Sched and Sched.focus.unlock
	for _, c in ipairs(productCandidates()) do
		if passList(cfg.buyprod.allow, c.id, true) and not passList(cfg.buyprod.deny, c.id, false) then
			if questWantsUnlock or cfg.buyprod.maxPrice <= 0 or c.price <= cfg.buyprod.maxPrice then
				if cashNow() - c.price >= cfg.buyprod.cashFloor then out[#out + 1] = c end
			end
		end
	end
	return out
end

local function doBuyProd(dryRun)
	local list = productPicks()
	local c = list[1]
	if not c then
		local all = productCandidates()
		if #all == 0 then return false, "没有待解锁的商品"
		else return false, string.format("有 %d 个商品，但不满足预算/白名单", #all) end
	end
	if dryRun then return true, string.format("将解锁 %s（%s）", c.id, fmt(c.price)) end
	if guardBlock() then return false, "保护模式：现金过低，暂停解锁" end
	local rem = Remotes and Remotes:FindFirstChild("UnlockProduct")
	if not rem then return false, "无 UnlockProduct" end
	if not canAct() then return false, "节流中" end
	local ok = safe(function() rem:FireServer(c.id) end)
	if ok then
		BuyProd.count = BuyProd.count + 1
		local m = string.format("解锁商品 %s（%s）", c.id, fmt(c.price))
		log(m)
		return true, m
	end
	return false, "解锁失败"
end

-- ---------------------------------------------------------------- 员工招聘
-- 实机标定：HireEmployee(offerId:number) —— 传字符串无效。
local LEVEL_RANK = { Noob = 1, Pro = 2, Expert = 3, Ex = 3, Legendary = 4 }
local LEVEL_LABEL = { ["无要求"] = 0, ["Noob 及以上"] = 1, ["Pro 及以上"] = 2, ["Expert 及以上"] = 3 }
local function levelRank(l) return LEVEL_RANK[tostring(l)] or 0 end

local Hire = { at = 0, last = "待机", count = 0, refreshAt = 0 }

local function roleCap(roleId)
	local es = G.employees
	if not es or type(es.slots) ~= "table" then return nil end
	return tonumber(es.slots[roleId]) or 0
end
local function roleUsed(roleId)
	local n = 0
	for _, e in pairs((G.employees and G.employees.employees) or {}) do
		if tostring(e.role) == tostring(roleId) then n = n + 1 end
	end
	return n
end
local function roleHasFreeSlot(roleId)
	local cap = roleCap(roleId)
	if cap == nil then return true end
	return roleUsed(roleId) < cap
end

local function hireCandidates(ignoreMaxPrice)
	local out, j = {}, G.jobs
	if not j or type(j.offers) ~= "table" then return out end
	local floorRank = LEVEL_LABEL[cfg.hire.minLevel] or 0
	for _, o in ipairs(j.offers) do
		local role = tostring(o.role or "")
		-- hired 字段缺失时按"无人应聘"处理，不要因为字段不存在就漏掉整个候选人
		if o.available ~= false and not o.full and (tonumber(o.hired) or 0) == 0 then
			if passList(cfg.hire.roles, role, true) and not passList(cfg.hire.denyRoles, role, false) then
				if levelRank(o.level) >= floorRank then
					local price = tonumber(o.price) or 0
					if (ignoreMaxPrice or cfg.hire.maxPrice <= 0 or price <= cfg.hire.maxPrice)
						and roleHasFreeSlot(role) then
						out[#out + 1] = {
							id = o.id, name = tostring(o.name), role = role, level = o.level,
							price = price, speed = tonumber(o.speed) or 0,
							ability = tostring(o.ability or ""),
						}
					end
				end
			end
		end
	end
	table.sort(out, function(a, b)
		if levelRank(a.level) ~= levelRank(b.level) then return levelRank(a.level) > levelRank(b.level) end
		if a.speed ~= b.speed then return a.speed > b.speed end
		return a.price < b.price
	end)
	return out
end

local function doHire(dryRun)
	-- 任务加速：任务要"雇人"时放宽薪资上限（其余条件与现金下限照旧）
	local questWantsHire = cfg.sched.questBoost and Sched and Sched.focus.hire
	local list = hireCandidates(questWantsHire)
	local target
	for _, c in ipairs(list) do
		if cashNow() - c.price >= cfg.hire.cashFloor then target = c break end
	end
	if not target then
		-- 没人可招：先看要不要补工位
		local es = G.employees
		if cfg.hire.autoWorkerSlot and es and not es.workerSlotUnlocked then
			local cost = tonumber(es.workerSlotCost) or 0
			if cost > 0 and cashNow() - cost >= cfg.hire.cashFloor then
				local r = Remotes and Remotes:FindFirstChild("BuyWorkerSlot")
				if r then
					if dryRun then return true, string.format("将购买工位（%s）", fmt(cost)) end
					if canAct() and safe(function() r:FireServer() end) then
						local m = string.format("购买员工工位（%s）", fmt(cost))
						log(m)
						return true, m
					end
				end
			end
		end
		local offers = (G.jobs and G.jobs.offers) or nil
		if #list == 0 and type(offers) == "table" and #offers > 0 then
			return false, "候选人不满足条件（等级/薪资/岗位/名额）"
		end
		return false, "当前没有合适候选人"
	end
	if dryRun then
		return true, string.format("将雇佣 %s（%s · %s · %s）", target.name, target.role, tostring(target.level), fmt(target.price))
	end
	if guardBlock() then return false, "保护模式：现金过低，暂停招聘" end
	local rem = Remotes and Remotes:FindFirstChild("HireEmployee")
	if not rem then return false, "无 HireEmployee" end
	if not canAct() then return false, "节流中" end
	-- 回执确认：FireServer 不抛异常 ≠ 服务器受理，重新拉一次员工表比对人数
	local before, verify = roleUsed(target.role), G.employees ~= nil
	local ok = safe(function() rem:FireServer(target.id) end)   -- ⚠ 必须传 number
	if not ok then return false, "雇佣调用失败" end
	if verify then
		task.wait(0.6)
		requestEmployees()
		task.wait(0.4)
	end
	if (not verify) or roleUsed(target.role) > before then
		Hire.count = Hire.count + 1
		backoffReset("hire")
		local m = verify and string.format("已雇佣 %s（%s · %s · %s）",
			target.name, target.role, tostring(target.level), fmt(target.price))
			or string.format("%s 已发出雇佣（未回执确认）", target.name)
		log(m)
		return true, m
	end
	return false, backoffFail("hire", string.format("雇佣 %s", target.name))
end

local function refreshCandidates()
	local j = G.jobs
	if not j then return false, "无 JobState" end
	local cost = tonumber(j.refreshCost) or 0
	if gemsNow() - cost < cfg.hire.gemFloor then
		return false, string.format("宝石不足（%d，需 %d+%d）", gemsNow(), cost, cfg.hire.gemFloor)
	end
	local r = Remotes and Remotes:FindFirstChild("RefreshJobs")
	if not r then return false, "无 RefreshJobs" end
	if not safe(function() r:FireServer() end) then return false, "刷新失败" end
	Hire.refreshAt = os.clock()
	local m = string.format("重掷候选人（-%d 宝石）", cost)
	log(m)
	return true, m
end

-- ---------------------------------------------------------------- 自动广告
-- 实机标定：RecordAd() 让 adState 变 Recording（adRecordTotal 秒），
local Ad = { at = 0, last = "待机", published = 0, armed = false }

local RARITY_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }

local function viralProduct()
	local v = G.viral
	if type(v) ~= "table" then return nil end
	local owned = {}
	for k, val in pairs(S.unlocked or {}) do if val then owned[tostring(k)] = true end end
	local best
	for _, p in ipairs(v.produkty or {}) do
		local id = tostring(p.id)
		if owned[id] then
			local r = RARITY_RANK[tostring(p.rzadkosc)] or 0
			if not best or r > best.r then best = { id = id, r = r } end
		end
	end
	return best and best.id or nil
end

local function adProductPick()
	if cfg.ad.viralFollow then
		local vp = viralProduct()
		if vp then return vp end
	end
	if cfg.ad.productMode == "指定" and cfg.ad.product ~= "" then return cfg.ad.product end
	if cfg.ad.productMode == "跟随当前产品" and S.activeProduct then return tostring(S.activeProduct) end
	if S.adProduct and tostring(S.adProduct) ~= "" then return tostring(S.adProduct) end
	if S.activeProduct then return tostring(S.activeProduct) end
	local ps = G.campaign and G.campaign.products
	if type(ps) == "table" then for _, v in ipairs(ps) do return tostring(v) end end
	return nil
end

local function adCostOf(pid, dur)
	local cs = G.campaign
	if not cs or type(cs.productInfo) ~= "table" then return nil end
	local rarity
	for _, p in ipairs(cs.productInfo) do
		if tostring(p.id) == tostring(pid) then rarity = tostring(p.rarity) end
	end
	if not rarity then return nil end
	local tbl = (cs.campaignCosts or {})[rarity]
	if type(tbl) ~= "table" then return nil end
	return tonumber(tbl[dur]) or tonumber(tbl[tostring(dur)])
end

local function campaignLeft(pid)
	local best = 0
	for _, c in ipairs((G.campaign and G.campaign.campaigns) or {}) do
		if tostring(c.productId) == tostring(pid) then
			local left = tonumber(c.left) or 0
			if left > best then best = left end
		end
	end
	return best
end

local function adTick()
	if not cfg.ad.on then Ad.last = "未启用" return end
	if os.clock() - Ad.at < cfg.ad.interval then return end
	Ad.at = os.clock()
	requestCampaigns()

	local st = tostring(S.adState or "None")
	if st == "Recording" then
		Ad.armed = true
		Ad.last = "录制中…（等待录制完成）"
		return
	end
	if st == "Ready" then
		local r = Remotes and Remotes:FindFirstChild("PublishAd")
		if not r then Ad.last = "无 PublishAd" return end
		if safe(function() r:FireServer() end) then
			Ad.armed = false
			Ad.published = Ad.published + 1
			local m = string.format("已投放广告（累计 %d 次）", Ad.published)
			log(m)
			Ad.last = m
		else
			Ad.last = "投放失败"
		end
		return
	end

	local pid = adProductPick()
	if not pid then Ad.last = "没有可选商品" return end
	-- ⚠ campaignLeft 只看目标商品；别的商品占着广告位时也要拦住，
	--   否则会反复向服务端发无效投放。CampaignState.slots 是"拥有的位数"，不是空位数。
	local owned = tonumber((G.campaign and G.campaign.slots) or 1) or 1
	local used = #((G.campaign and G.campaign.campaigns) or {})
	local free = owned - used
	if free <= 0 and campaignLeft(pid) <= 0 then
		Ad.last = string.format("广告位已满（%d/%d）", used, owned)
		return
	end
	local left = campaignLeft(pid)
	-- 任务加速：任务要求"投放广告"时不等剩余时间 —— 但必须真有空位，否则服务端必拒
	local questAd = cfg.sched.questBoost and Sched and Sched.focus.ad
	if left > cfg.ad.minLeft and not (questAd and free > 0) then
		Ad.last = string.format("%s 广告剩余 %ds", pid, left)
		return
	end
	local dur = tonumber(cfg.ad.duration) or 600
	local cost = adCostOf(pid, dur)
	if not cost then Ad.last = "拿不到该商品的广告价（先打开一次广告面板）" return end
	if cfg.ad.maxCost > 0 and cost > cfg.ad.maxCost then
		Ad.last = string.format("花费 %d 超过上限 %d", cost, cfg.ad.maxCost) return
	end
	if guardBlock() then Ad.last = "保护模式：现金过低，暂停广告" return end
	if cashNow() - cost < cfg.ad.cashFloor then
		Ad.last = string.format("现金不足（%d，需 %d+%d）", cashNow(), cost, cfg.ad.cashFloor) return
	end

	if cfg.ad.autoSelect then
		local sp = Remotes and Remotes:FindFirstChild("SelectAdProduct")
		if sp then safe(function() sp:FireServer(pid) end) task.wait(0.25) end
	end
	local rr = Remotes and Remotes:FindFirstChild("RecordAd")
	if not rr then Ad.last = "无 RecordAd" return end
	if not safe(function() rr:FireServer() end) then Ad.last = "开始录制失败" return end
	Ad.armed = true
	Ad.last = string.format("开始录制 %s（%s / %ds）", pid, fmt(cost), dur)
end

local function doAdOnce()
	local pid = adProductPick()
	if not pid then return false, "没有可选商品" end
	local st = tostring(S.adState or "None")
	if st == "Ready" then
		local r = Remotes and Remotes:FindFirstChild("PublishAd")
		if r and safe(function() r:FireServer() end) then
			Ad.published = Ad.published + 1
			return true, "已投放待发布的广告"
		end
		return false, "投放失败"
	end
	if st == "Recording" then return false, "正在录制中，稍等" end
	local dur = tonumber(cfg.ad.duration) or 600
	local cost = adCostOf(pid, dur)
	local sp = Remotes and Remotes:FindFirstChild("SelectAdProduct")
	if cfg.ad.autoSelect and sp then safe(function() sp:FireServer(pid) end) task.wait(0.25) end
	local rr = Remotes and Remotes:FindFirstChild("RecordAd")
	if not rr then return false, "无 RecordAd" end
	if not safe(function() rr:FireServer() end) then return false, "开始录制失败" end
	Ad.last = string.format("开始录制 %s（%s / %ds）", pid, cost and fmt(cost) or "?", dur)
	return true, Ad.last
end

--=====================================================================
-- 5.55 自动运营：领取 / 休假 / 训练 / 研究 / 合同
--   实机标定：
--     HireEmployee(offerId:number) / BuyCandidateSlot() / RefreshJobs(5宝石)   ✅
--                                    zajete=false、现金 >= training.cena（750）
--     ResearchBuy / DailyClaim / QuestClaimBonus / ContractAccept 的参数为自然
--       这里如实回报"服务端未接受"，不会假装成功。
--=====================================================================
local Ops = { at = {}, last = {}, log = {} }

local function opsLog(tag, msg)
	Ops.last[tag] = msg
	Ops.log[#Ops.log + 1] = string.format("%s %s: %s", os.date("%H:%M:%S"), tag, msg)
	while #Ops.log > 30 do table.remove(Ops.log, 1) end
end

local function fireR(name, ...)
	local r = Remotes and Remotes:FindFirstChild(name)
	if not r then return false, "无 " .. name end
	local args = { ... }
	local ok = safe(function() r:FireServer(table.unpack(args)) end)
	return ok, ok and "已发出" or "调用失败"
end

local function opsClaimTick()
	local did = {}
	-- 先把"未领"的快照存下来，稍后回执比对，避免把"已发出"写成"已领取"
	local pend = {}
	for _, q in ipairs((G.quest and G.quest.questy) or {}) do
		if q.completed and not q.claimed and q.uid then pend[#pend + 1] = tostring(q.uid) end
	end
	local tried = 0
	if G.quest then
		for _, uid in ipairs(pend) do
			if fireR("QuestClaim", uid) then tried = tried + 1 end
		end
		if G.quest.bonusGotowy and not G.quest.bonusClaimed then
			if fireR("QuestClaimBonus") then did[#did + 1] = "任务额外奖励（已发出）" end
		end
	end
	if G.daily then
		-- ⚠ DailyState.claimed 语义不明确（疑似"已领天数"），用它判断会在领过
		--   一次之后永远为真。改为固定节流：每 30 分钟最多尝试一次，覆盖每日刷新。
		local tnow = os.clock()
		if tnow - (Ops.dailyAt or 0) >= 1800 and backoffWait("daily") <= 0 then
			Ops.dailyAt = tnow
			local before = tonumber(G.daily.claimed) or 0
			fireR("DailyClaim")
			task.wait(0.5)
			requestDaily()
			task.wait(0.3)
			local after = tonumber((G.daily or {}).claimed) or 0
			if after > before then
				backoffReset("daily")
				did[#did + 1] = "每日奖励"
			end
		end
	end
	-- 回执确认：重新拉一次任务表，只有真的变成已领取才算数
	if tried > 0 then
		task.wait(0.5)
		requestQuest()
		task.wait(0.4)
		local nowClaimed = {}
		for _, q in ipairs((G.quest and G.quest.questy) or {}) do
			if q.claimed then nowClaimed[tostring(q.uid)] = true end
		end
		for _, uid in ipairs(pend) do
			if nowClaimed[uid] then did[#did + 1] = "任务 " .. uid end
		end
		if #did == 0 then
			opsLog("领取", backoffFail("quest", string.format("任务领取（%d 个）", tried)))
			return
		end
		backoffReset("quest")
	end
	opsLog("领取", #did > 0 and table.concat(did, "、") or "暂无可领取")
end

local function opsVacationTick()
	if backoffWait("vac") > 0 then
		opsLog("休假", string.format("退避中，%d 秒后重试", math.floor(backoffWait("vac"))))
		return
	end
	local best
	for _, e in ipairs((G.employees and G.employees.employees) or {}) do
		local sat = tonumber(e.satisfaction) or 100
		local vac = tonumber(e.vacationLeft) or 0
		if vac <= 0 and sat < cfg.ops.vacThreshold then
			if not best or sat < (tonumber(best.satisfaction) or 100) then best = e end
		end
	end
	if not best then
		opsLog("休假", string.format("全队状态良好（阈值 %d）", cfg.ops.vacThreshold))
		return
	end
	local id = tonumber(best.id) or best.id
	fireR("SendVacation", id)
	-- 回执确认：休假成功会变成 vacationLeft>0 / status="On Vacation"
	task.wait(0.6)
	requestEmployees()
	task.wait(0.4)
	local now
	for _, e in ipairs((G.employees and G.employees.employees) or {}) do
		if tostring(e.id) == tostring(best.id) then now = e end
	end
	if now and (tonumber(now.vacationLeft) or 0) > 0 then
		backoffReset("vac")
		opsLog("休假", string.format("%s 已进入休假（满意度 %s）",
			tostring(best.name), tostring(best.satisfaction)))
	else
		opsLog("休假", backoffFail("vac", string.format("%s 休假", tostring(best.name))))
	end
end

local function opsTrainTick()
	if backoffWait("train") > 0 then
		opsLog("训练", string.format("退避中，%d 秒后重试", math.floor(backoffWait("train"))))
		return
	end
	if guardBlock() then opsLog("训练", "保护模式：现金过低，暂停训练") return end
	for _, e in ipairs((G.employees and G.employees.employees) or {}) do
		local t = e.training
		if type(t) == "table" and t.mozliwy and not t.trwa and not t.zajete then
			local cost = tonumber(t.cena) or 0
			if cashNow() - cost >= cfg.ops.trainFloor then
				fireR("StartTraining", tonumber(e.id) or e.id)
				-- 回执确认：训练开始后 training.trwa 会变 true
				task.wait(0.6)
				requestEmployees()
				task.wait(0.4)
				local now
				for _, x in ipairs((G.employees and G.employees.employees) or {}) do
					if tostring(x.id) == tostring(e.id) then now = x end
				end
				if now and type(now.training) == "table" and now.training.trwa then
					backoffReset("train")
					opsLog("训练", string.format("%s 已开始训练（%s -> %s，%s）",
						tostring(e.name), tostring(e.level), tostring(t.cel), fmt(cost)))
				else
					opsLog("训练", backoffFail("train", string.format("%s 训练", tostring(e.name))))
				end
				return
			end
		end
	end
	opsLog("训练", "暂无可训练的员工")
end

local function opsResearchTick()
	if backoffWait("research") > 0 then
		opsLog("研究", string.format("退避中，%d 秒后重试", math.floor(backoffWait("research"))))
		return
	end
	if guardBlock() then opsLog("研究", "保护模式：现金过低，暂停研究") return end
	for _, p in ipairs((G.research and G.research.products) or {}) do
		local lvl = tonumber(p.poziom) or 0
		local mx = tonumber(p.max) or 3
		local cost = tonumber(p.cenaUlepszenia) or 0
		if lvl < mx and cashNow() - cost >= cfg.ops.researchFloor then
			fireR("ResearchBuy", tostring(p.id))
			-- 回执确认：等级涨了才算成功
			task.wait(0.6)
			requestResearch()
			task.wait(0.4)
			local now
			for _, q in ipairs((G.research and G.research.products) or {}) do
				if tostring(q.id) == tostring(p.id) then now = q end
			end
			if now and (tonumber(now.poziom) or 0) > lvl then
				backoffReset("research")
				opsLog("研究", string.format("%s 研究已升到 %s 级", tostring(p.id), tostring(now.poziom)))
			else
				opsLog("研究", backoffFail("research", string.format("%s 研究 %d→%d", tostring(p.id), lvl, lvl + 1)))
			end
			return
		end
	end
	opsLog("研究", "暂无可研究项（可能未开放）")
end

local function opsContractTick()
	if backoffWait("contract") > 0 then
		opsLog("合同", string.format("退避中，%d 秒后重试", math.floor(backoffWait("contract"))))
		return
	end
	local c = G.contract
	if not c then opsLog("合同", "无数据") return end
	if not c.hasOffice then opsLog("合同", "未建办公室，合同系统未开放") return end
	for _, o in ipairs(c.offers or {}) do
		local need = tonumber(o.ilosc) or 0
		if stockOf(tostring(o.productId)) >= need then
			local before = #(c.offers or {})
			fireR("ContractAccept", tonumber(o.idx) or o.idx)
			task.wait(0.6)
			requestContract()
			task.wait(0.4)
			local now = G.contract
			if now and #(now.offers or {}) ~= before then
				backoffReset("contract")
				opsLog("合同", string.format("已接合同 %s（%d 件 %s）",
					tostring(o.firma), need, tostring(o.productId)))
			else
				opsLog("合同", backoffFail("contract", string.format("合同 %s", tostring(o.firma))))
			end
			return
		end
	end
	opsLog("合同", "库存不足以接任何合同")
end

local function opsTick()
	local now = os.clock()
	local at = Ops.at
	if cfg.ops.claim and now - (at.claim or 0) >= cfg.ops.claimInterval then
		at.claim = now
		requestQuest() requestDaily() task.wait(0.4)
		safe(opsClaimTick)
	end
	if cfg.ops.vacation and now - (at.vac or 0) >= cfg.ops.vacInterval then
		at.vac = now
		requestEmployees() task.wait(0.35)
		safe(opsVacationTick)
	end
	if cfg.ops.train and now - (at.train or 0) >= cfg.ops.trainInterval then
		at.train = now
		requestEmployees() task.wait(0.35)
		safe(opsTrainTick)
	end
	if cfg.ops.research and now - (at.res or 0) >= cfg.ops.researchInterval then
		at.res = now
		requestResearch() task.wait(0.35)
		safe(opsResearchTick)
	end
	if cfg.ops.contract and now - (at.con or 0) >= cfg.ops.contractInterval then
		at.con = now
		requestContract() task.wait(0.35)
		safe(opsContractTick)
	end
end

--=====================================================================
-- 5.7 调度联动：任务加速 / 合同驱动 / 自愈 / 报表 / 维护
--=====================================================================
Sched = {
	questAt = 0, focus = { texts = {} }, prefProducts = {},
	lastReport = os.clock(), recheckAt = 0, logAt = 0, healAt = 0, heals = 0,
	noPlot = 0, note = "待机", gated = {},
}

function Sched.refreshQuest()
	if os.clock() - Sched.questAt < 20 then return end
	Sched.questAt = os.clock()
	requestQuest()
	local f = Sched.focus
	f.accept, f.deliver, f.ad, f.hire, f.unlock = false, false, false, false, false
	f.texts = {}
	for _, q in ipairs((G.quest and G.quest.questy) or {}) do
		if not q.claimed then
			local s = string.lower(tostring(q.opis or ""))
			f.texts[#f.texts + 1] = string.format("%s  %s/%s",
				tostring(q.opis or "?"), tostring(q.postep or 0), tostring(q.cel or 0))
			if string.find(s, "accept", 1, true) and string.find(s, "order", 1, true) then f.accept = true end
			if string.find(s, "courier", 1, true) or string.find(s, "deliver", 1, true)
				or string.find(s, "ship", 1, true) then f.deliver = true end
			if string.find(s, "ad", 1, true) or string.find(s, "campaign", 1, true) then f.ad = true end
			if string.find(s, "hire", 1, true) or string.find(s, "train", 1, true) then f.hire = true end
			if string.find(s, "unlock", 1, true) or string.find(s, "research", 1, true) then f.unlock = true end
		end
	end
	Sched.note = (#f.texts > 0) and string.format("在追 %d 个未完成任务", #f.texts) or "无未完成任务"
end

function Sched.refreshContract()
	Sched.prefProducts = {}
	if not cfg.sched.contractBoost then return end
	local best, bestVal
	for _, o in ipairs((G.contract and G.contract.offers) or {}) do
		local v = tonumber(o.wartosc) or 0
		if (tonumber(o.ilosc) or 0) > 0 and (not best or v > bestVal) then best, bestVal = o, v end
	end
	if best and best.productId then Sched.prefProducts[tostring(best.productId)] = true end
end

-- 自愈：服务端长时间不推状态就主动拉；地块暂时找不到就报警
function Sched.heal()
	if not cfg.sched.selfHeal then return end
	if os.clock() - Sched.healAt < 5 then return end
	Sched.healAt = os.clock()
	local stale = os.clock() - STATEPush
	if STATEPush > 0 and stale > 15 then
		Sched.heals = Sched.heals + 1
		requestState()
		if Sched.heals % 6 == 1 then
			log(string.format("自愈：%.0fs 未收到状态推送，已主动请求", stale))
		end
	elseif stale <= 15 then
		Sched.heals = 0
	end
	if not getPlot() then
		Sched.noPlot = Sched.noPlot + 1
		if Sched.noPlot % 20 == 1 then log("自愈：地块对象暂时找不到（可能正在重载）") end
	else
		Sched.noPlot = 0
	end
end

function Sched.report(force)
	local now = os.clock()
	if not force then
		if not cfg.sched.hourlyReport then return end
		if now - (Sched.lastReport or 0) < 3600 then return end
	end
	Sched.lastReport = now
	local msg = string.format("近 1 小时：完成 %d 单 ｜ 毛收入 %s ｜ 动作确认 %d 次（失败 %d）｜ AI 调整 %d 次",
		Pipe.completed, fmt(Stat.gain), Exe.stats.total, Exe.stats.fail, AI.runs)
	log("报表 " .. msg)
	Notify("运行报表", msg, "activity")
end

function Sched.recheckGates()
	if not cfg.maint.gateRecheck then return end
	local now = os.clock()
	if now - (Sched.recheckAt or 0) < (tonumber(cfg.maint.recheckInterval) or 600) then return end
	Sched.recheckAt = now
	for _, k in ipairs({ "research", "contract", "daily", "train", "hire" }) do
		local b = Backoff[k]
		if b and b.fails >= 3 then
			Backoff[k] = nil
			Sched.gated[k] = string.format("%s（已试 %d 次失败，本轮复测）", k, b.fails)
		elseif not b then
			Sched.gated[k] = nil
		end
	end
end

function Sched.flushLog()
	if not cfg.maint.logFile then return end
	if not (writefile and appendfile) then return end
	local now = os.clock()
	if now - (Sched.logAt or 0) < (tonumber(cfg.maint.logInterval) or 30) then return end
	Sched.logAt = now
	safe(function()
		local n = #Log
		local from = math.max(1, n - 40)
		local out = {}
		for i = from, n do out[#out + 1] = Log[i] end
		appendfile("DropshipHub_log.txt", table.concat(out, "\n") .. "\n")
	end)
end

function Sched.exportCfg()
	if not setclipboard then return false, "当前执行器不支持 setclipboard" end
	local ok, json = safe(function() return Http:JSONEncode(cfg) end)
	if not ok or type(json) ~= "string" then return false, "编码失败" end
	local ok2 = safe(function() setclipboard(json) end)
	if not ok2 then return false, "写入剪贴板失败" end
	log(string.format("配置已导出到剪贴板（%d 字节）", #json))
	return true, string.format("已复制 %d 字节配置 JSON", #json)
end

function Sched.importCfg()
	if not getclipboard then return false, "当前执行器不支持 getclipboard" end
	local ok, txt = safe(function() return getclipboard() end)
	if not ok or type(txt) ~= "string" or txt == "" then return false, "剪贴板为空" end
	local ok2, decoded = pcall(function() return Http:JSONDecode(txt) end)
	if not ok2 or type(decoded) ~= "table" then return false, "剪贴板内容不是合法 JSON" end
	mergeInto(cfg, decoded)
	cfgTouch()
	guardRefresh()
	log("配置已从剪贴板导入")
	return true, "已导入（部分项重载后完全生效）"
end

local function schedTick()
	safe(Sched.refreshQuest)
	safe(Sched.refreshContract)
	safe(Sched.heal)
	safe(Sched.recheckGates)
	safe(Sched.report)
	safe(Sched.flushLog)
end

--=====================================================================
-- 5.6 传送带感知（后期可升级 / 增加，最多 3 条）+ AI 自动调参
--=====================================================================
local Conv = { at = 0, count = 1, level = 0, maxLevel = 3, price = nil,
	prompt = nil, last = "—", belts = {}, avgLevel = 0, target = nil }

-- 实机标定：传送带升级是地块里的物理提示点
local function readConv(force)
	if not force and os.clock() - Conv.at < 1.5 then return end
	Conv.at = os.clock()
	local plot = getPlot()
	if not plot then return end
	local belts = {}
	for _, m in ipairs(plot:GetChildren()) do
		if m:IsA("Model") and string.find(string.lower(m.Name), "conveyor", 1, true) then
			local b = { name = m.Name, level = 0, maxLevel = 3, price = nil, prompt = nil, enabled = false }
			local ua = m:FindFirstChild("UpgradeAnchor", true)
			if ua then
				local pr = ua:FindFirstChild("UpgradePrompt", true)
				if pr then b.prompt, b.enabled = pr, pr.Enabled == true end
				local panel = ua:FindFirstChild("UpgradePanel", true)
				if panel then
					for _, d in ipairs(panel:GetDescendants()) do
						if d:IsA("TextLabel") then
							local key = string.lower(d.Name)
							if string.find(key, "poziom", 1, true) then
								local cur, mx = string.match(d.Text, "(%d+)%s*/%s*(%d+)")
								if cur then b.level = tonumber(cur) or 0 end
								if mx then b.maxLevel = tonumber(mx) or 3 end
							elseif string.find(key, "cena", 1, true) then
								local v = string.match(d.Text, "%d+")
								if v then b.price = tonumber(v) end
							end
						end
					end
				end
			end
			belts[#belts + 1] = b
		end
	end
	if #belts > 0 then
		table.sort(belts, function(x, y) return tostring(x.name) < tostring(y.name) end)
		Conv.belts = belts
		Conv.count = #belts
		local maxLv, sumLv = 0, 0
		for _, b in ipairs(belts) do
			maxLv = math.max(maxLv, b.level)
			sumLv = sumLv + b.level
			Conv.maxLevel = b.maxLevel
		end
		Conv.level = maxLv
		Conv.avgLevel = sumLv / #belts
		local target
		for _, b in ipairs(belts) do
			if b.enabled and b.level < b.maxLevel and (not target or b.level < target.level) then target = b end
		end
		if not target then
			for _, b in ipairs(belts) do
				if b.level < b.maxLevel and (not target or b.level < target.level) then target = b end
			end
		end
		Conv.target = target
		Conv.prompt = target and target.prompt or nil
		Conv.price = target and target.price or nil
	end
	if cfg.conv.auto then
		cfg.conv.count = math.clamp(Conv.count, 1, cfg.conv.maxCount)
		cfg.conv.level = Conv.level
	end
end

local function convUpgrade()
	readConv(true)
	local belts = Conv.belts or {}
	if #belts == 0 then
		Conv.last = "未发现传送带"
		return false, Conv.last
	end
	local target = Conv.target
	if not target then
		Conv.last = string.format("全部满级（%d 条 · 平均 Lv%.1f）", #belts, Conv.avgLevel or 0)
		return false, Conv.last
	end
	local pr = target.prompt
	if not pr or not pr.Parent then
		Conv.last = string.format("%s 没有升级提示点", tostring(target.name))
		return false, Conv.last
	end
	if not pr.Enabled then
		Conv.last = string.format("%s Lv%d/%d 升级未开放（服务端 Enabled=false）",
			tostring(target.name), target.level, target.maxLevel)
		return false, Conv.last
	end
	local price = tonumber(target.price) or 0
	if guardBlock() then
		Conv.last = "保护模式：现金过低，暂停升级"
		return false, Conv.last
	end
	if cashNow() - price < cfg.conv.upgradeFloor then
		Conv.last = string.format("现金不足（需 %s + 保留 %s）", fmt(price), fmt(cfg.conv.upgradeFloor))
		return false, Conv.last
	end
	if not canAct() then return false, "节流中" end
	fireNear(pr)
	Conv.last = string.format("已触发 %s 升级（Lv%d → %d，%s）",
		tostring(target.name), target.level, target.level + 1, fmt(price))
	log("传送带升级：" .. Conv.last)
	return true, Conv.last
end

-- ---------------------------------------------------------------- AI 调参
local AI = { at = 0, changes = {}, runs = 0 }

local function aiLog(msg)
	AI.changes[#AI.changes + 1] = string.format("%s  %s", os.date("%H:%M:%S"), msg)
	while #AI.changes > 40 do table.remove(AI.changes, 1) end
	cfg.ai.note = msg
	log("AI " .. msg)
end

local function aiTick()
	if not cfg.ai.on then cfg.ai.note = "未启用" return end
	if os.clock() - AI.at < math.max(3, tonumber(cfg.ai.interval) or 10) then return end
	AI.at = os.clock()
	AI.runs = AI.runs + 1

	local style = tostring(cfg.ai.style)
	local mul = (style == "激进") and 2 or ((style == "保守") and 0.5 or 1)
	local lo = tonumber(cfg.ai.preWaitMin) or 0.18
	local hi = math.max(lo + 0.05, tonumber(cfg.ai.preWaitMax) or 0.60)
	local function clampW(v) return math.clamp(v, lo, hi) end

	-- 1) 时序自适应：用真实"动作是否被确认"的失败率来调传送前等待
	if cfg.ai.timing then
		local st = Exe.stats
		if st.total >= 6 then
			local rate = st.fail / st.total
			if rate > 0.25 then
				local nv = clampW(cfg.pipe.preWait + 0.04 * mul)
				if nv > cfg.pipe.preWait + 0.001 then
					cfg.pipe.preWait = nv
					aiLog(string.format("动作确认失败率 %.0f%% -> 传送前等待提到 %.2fs", rate * 100, nv))
				end
			elseif rate == 0 and cfg.pipe.preWait > lo + 0.06 then
				cfg.pipe.preWait = clampW(cfg.pipe.preWait - 0.02)
				aiLog(string.format("确认全通过 -> 传送前等待降到 %.2fs（提速）", cfg.pipe.preWait))
			end
			st.total, st.fail = 0, 0
		end
		if cfg.pipe.postWait < 0.20 then
			cfg.pipe.postWait = 0.20
			aiLog("回位前等待抬到 0.20s（低于此值会丢动作）")
		end
	end

	-- 2) 接单并发：跟随服务端 maxFulfillments，且不超过传送带条数
	if cfg.ai.concurrency then
		local mx = maxActive()
		local cap = cfg.ai.conveyorAware and math.max(1, math.min(mx, cfg.conv.count)) or mx
		local want = math.max(1, cap)
		if cfg.ac.maxActive ~= want then
			cfg.ac.maxActive = want
			aiLog(string.format("接单并发 -> %d（maxFulfillments=%d · 传送带 %d 条）", want, mx, cfg.conv.count))
		end
	end

	-- 3) 补货阈值：按仓库容量按比例，仓库见底就开自动买货
	if cfg.ai.restock then
		local capShip = tonumber(S.warehouseCapacity) or 50
		local wantLow = math.max(1, math.min(math.floor(capShip * 0.15), 10))
		local wantBatch = math.max(2, math.min(math.floor(capShip * 0.30), 20))
		if cfg.restock.low ~= wantLow then
			cfg.restock.low = wantLow
			aiLog("补货阈值 -> " .. wantLow)
		end
		if cfg.restock.batch ~= wantBatch then
			cfg.restock.batch = wantBatch
			aiLog("每次补货数量 -> " .. wantBatch)
		end
		if (tonumber(S.warehouse) or 0) == 0 and not cfg.pipe.autoRestock then
			cfg.pipe.autoRestock = true
			aiLog("仓库见底 -> 打开缺货自动买货")
		end
		cfg.restock.cashFloor = math.max(0, math.floor(cashNow() * 0.05))
	end

	-- 4) 预算比例：所有"现金保留"跟着现有现金走
	if cfg.ai.budget then
		local cash = cashNow()
		local pct = (style == "激进") and 0.15 or ((style == "保守") and 0.05 or 0.10)
		local f = math.max(0, math.floor(cash * pct))
		if cfg.buyprod.cashFloor ~= f then cfg.buyprod.cashFloor = f aiLog("商品解锁现金保留 -> " .. fmt(f)) end
		if cfg.hire.cashFloor ~= f then cfg.hire.cashFloor = f aiLog("招聘现金保留 -> " .. fmt(f)) end
		if cfg.ad.cashFloor ~= f then cfg.ad.cashFloor = f aiLog("广告现金保留 -> " .. fmt(f)) end
		local wage = math.max(0, math.floor(cash * ((style == "激进") and 0.4 or 0.25)))
		if cfg.hire.maxPrice ~= wage then
			cfg.hire.maxPrice = wage
			aiLog("招聘薪资上限 -> " .. fmt(wage))
		end
	end

	-- 5) 广告节奏：现金够投 600s，不够退 300s；续投阈值按时长比例
	if cfg.ai.adPace and cfg.ad.on then
		local pid = adProductPick()
		if pid then
			local c600, c300 = adCostOf(pid, 600), adCostOf(pid, 300)
			if c600 and c300 then
				local want = (cashNow() - c600 >= cfg.ad.cashFloor) and 600 or 300
				if tonumber(cfg.ad.duration) ~= want then
					cfg.ad.duration = want
					aiLog(string.format("广告时长 -> %ds（600s 花费 %s）", want, fmt(c600)))
				end
				cfg.ad.minLeft = math.max(5, math.floor(want * 0.15))
			end
		end
	end

	-- 6) 传送带感知：重读条数/等级，并兜住传送抬高
	if cfg.ai.conveyorAware then
		readConv(true)
		if cfg.pipe.tpHeight < 2.0 then
			cfg.pipe.tpHeight = 2.5
			aiLog("微传送抬高恢复 2.5")
		end
	end

	cfgTouch()
end

--=====================================================================
-- 6. 自绘 HUD（拖动用全局 UIS + 区域命中）
--=====================================================================
HUD = { row = {}, frame = nil, gui = nil }
safe(function()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DropshipHubHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = (gethui and gethui()) or plr:WaitForChild("PlayerGui")
	HUD.gui = gui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Position = UDim2.new(0, cfg.hud.x, 0, cfg.hud.y)
	frame.Size = UDim2.new(0, 276, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Color3.fromRGB(17, 19, 25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Parent = gui
	HUD.frame = frame

	local cr = Instance.new("UICorner") cr.CornerRadius = UDim.new(0, 10) cr.Parent = frame
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(72, 112, 222) st.Transparency = 0.35 st.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8) pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 10) pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = frame
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 3) lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = frame

	local function row(order, text, color)
		local l = Instance.new("TextLabel")
		l.Name = "R" .. order
		l.LayoutOrder = order
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 16)
		l.Font = Enum.Font.GothamMedium
		l.TextSize = 13
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = color or Color3.fromRGB(228, 231, 238)
		l.Text = text
		l.Parent = frame
		return l
	end

	local title = Instance.new("TextButton")
	title.Name = "DragHandle"
	title.LayoutOrder = 0
	title.BackgroundTransparency = 1
	title.AutoButtonColor = false
	title.Size = UDim2.new(1, 0, 0, 18)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(122, 172, 255)
	title.Text = "代发货大亨 · 订单流水线   (可拖动)"
	title.Parent = frame

	local dragging, dragStart, startPos = false, nil, nil
	local function inPanel(p)
		local ap, sz = frame.AbsolutePosition, frame.AbsoluteSize
		return p.X >= ap.X and p.X <= ap.X + sz.X and p.Y >= ap.Y and p.Y <= ap.Y + sz.Y
	end
	STATE.connect(UIS.InputBegan, function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		if inPanel(input.Position) then
			dragging, dragStart, startPos = true, input.Position, frame.Position
		end
	end)
	STATE.connect(UIS.InputChanged, function(input)
		if not dragging then return end
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
		local d = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end)
	STATE.connect(UIS.InputEnded, function(input)
		if not dragging then return end
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		dragging = false
		cfg.hud.x = math.floor(frame.Position.X.Offset)
		cfg.hud.y = math.floor(frame.Position.Y.Offset)
		cfgSave(true)
	end)

	HUD.row.cash   = row(1, "现金 —")
	HUD.row.stock  = row(2, "库存 —")
	HUD.row.orders = row(3, "订单 —")
	HUD.row.carry  = row(4, "搬运 —")
	HUD.row.phase  = row(5, "阶段 —", Color3.fromRGB(150, 216, 178))
	HUD.row.ac     = row(6, "接单 —", Color3.fromRGB(180, 190, 240))
	HUD.row.rest   = row(7, "补货 —", Color3.fromRGB(232, 202, 140))
	HUD.row.mode   = row(8, "模式 —", Color3.fromRGB(170, 200, 255))
	HUD.row.buy    = row(9, "购买 —", Color3.fromRGB(198, 222, 178))
	HUD.row.ad     = row(10, "广告 —", Color3.fromRGB(240, 194, 214))
end)

local function hudVisible(v)
	if HUD.gui then safe(function() HUD.gui.Enabled = v end) end
end
hudVisible(cfg.hud.on)

--=====================================================================
-- 7. 订单驱动状态机
--=====================================================================
local Pipe = { phase = "IDLE", detail = "待机", orderId = nil, phaseAt = 0,
	lastAccept = 0, completed = 0, seen = {}, beltTries = 0, beltUntil = 0, acWhy = "" }

local function setPhase(name, detail)
	if Pipe.phase ~= name then
		if name ~= "IDLE" then log(string.format("[%s] %s", name, tostring(detail or ""))) end
		Pipe.phase = name
		Pipe.phaseAt = os.clock()
	end
	Pipe.detail = tostring(detail or name)
end

local ORDER_PRI = { ["Ready to Pack"] = 3, ["Being Packed"] = 2, ["Ready for Courier"] = 1 }

local function currentOrder()
	local best, bestPri
	local function consider(o)
		if not o then return end
		local pri = ORDER_PRI[tostring(o.status)]
		if not pri then return end
		if not bestPri or pri > bestPri
			or (pri == bestPri and (tonumber(o.id) or 0) < (tonumber(best.id) or 0)) then
			best, bestPri = o, pri
		end
	end
	local af = S.activeFulfillments
	if type(af) == "table" then
		for _, v in pairs(af) do
			if type(v) == "number" then consider(orderById(v)) end
		end
	end
	if not best then
		for _, o in pairs(S.orders or {}) do consider(o) end
	end
	return best
end

local function acPass(o)
	local prod = tostring(o.product or "")
	if cfg.ac.black[prod] then return false, "黑名单" end
	if cfg.ac.useWhite and not cfg.ac.white[prod] then return false, "不在白名单" end
	if cfg.ac.viralOnly and not o.isViral then return false, "非爆款" end
	local price = tonumber(o.price) or 0
	if cfg.ac.minPrice > 0 and price < cfg.ac.minPrice then return false, "低于最低价" end
	if cfg.ac.maxPrice > 0 and price > cfg.ac.maxPrice then return false, "高于最高价" end
	return true
end

local function acCandidates()
	local r = {}
	for _, o in pairs(S.orders or {}) do
		if tostring(o.status) == "New" and acPass(o) then r[#r + 1] = o end
	end
	local pri = cfg.ac.priority
	local pref = (Sched and Sched.prefProducts) or {}
	local function prefRank(o) return pref[tostring(o.product or "")] and 1 or 0 end
	table.sort(r, function(a, b)
		if prefRank(a) ~= prefRank(b) then return prefRank(a) > prefRank(b) end
		if pri == "价格最高优先" then
			return (tonumber(a.price) or 0) > (tonumber(b.price) or 0)
		elseif pri == "爆款优先" then
			if a.isViral ~= b.isViral then return a.isViral == true end
			return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
		end
		return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
	end)
	return r
end

local function tryAutoAccept()
	if not cfg.ac.on then Pipe.acWhy = "未启用" return false end
	if os.clock() - Pipe.lastAccept < cfg.ac.interval then
		Pipe.acWhy = string.format("节流中（%.1fs）", cfg.ac.interval)
		return false
	end
	-- 闸门明细：把"为什么没接"直接暴露到看板上，别再靠猜
	local used, cap = activeCount(), math.min(cfg.ac.maxActive, maxActive())
	if used >= cap then
		Pipe.acWhy = string.format("履约位满 %d/%d", used, cap)
		return false
	end
	local c = acCandidates()
	if #c == 0 then
		Pipe.acWhy = "没有符合条件的新单"
		return false
	end
	Pipe.acWhy = ""
	Pipe.lastAccept = os.clock()
	return acceptOrder(c[1].id)
end

local function doneBoxPrompt()
	local plot = getPlot()
	if not plot then return nil end
	local pkg = plot:FindFirstChild("Package", true)
	if not pkg then return nil end
	-- ⚠ 实机标定（v3.2）：成品箱会沿传送带移动，服务端只在箱子「到达末端」
	--   所以这里必须只认 Enabled=true —— 绝不能强行启用它，
	for _, d in ipairs(pkg:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled
			and (d.ActionText == "Pick up package" or d.ActionText == "") then
			return d
		end
	end
	return nil
end

local function doneBoxCustomer()
	local plot = getPlot()
	if not plot then return nil end
	local pkg = plot:FindFirstChild("Package", true)
	if not pkg then return nil end
	for _, box in ipairs(pkg:GetChildren()) do
		local tag = box:FindFirstChild("Tag")
		local t = tag and tag:FindFirstChild("Text")
		if t and t:IsA("TextLabel") then return t.Text end
	end
	return nil
end

-- ⚠ 完成的订单会离开履约集合，currentOrder() 不再返回它，所以必须独立扫描，
local function trackCompletions(seed)
	local n = 0
	for _, o in pairs(S.orders or {}) do
		local id = tostring(o.id)
		if tostring(o.status) == "Completed" and not Pipe.seen[id] then
			Pipe.seen[id] = true
			if not seed then
				Pipe.completed = Pipe.completed + 1
				log(string.format("订单完成 #%s（%s · %s$）", id, tostring(o.product), tostring(o.price)))
			end
			n = n + 1
		end
	end
	if seed or n == 0 then return end
	local cnt = 0
	for _ in pairs(Pipe.seen) do cnt = cnt + 1 end
	if cnt > 400 then
		Pipe.seen = {}
		for _, o in pairs(S.orders or {}) do
			if tostring(o.status) == "Completed" then Pipe.seen[tostring(o.id)] = true end
		end
	end
end

-- ⚠ 实机标定：状态偶尔会先跳到 Being Packed，但手里的原始包裹没收走，
--   这时必须重试上带，否则会卡死在「手里还拿着原包」的假过渡态。
-- 但也要限次：一旦服务端长时间不收（例如卡在 Being Packed 的结算窗口），
-- 无限重试会变成"原地反复闪现"，所以连续失败后强制冷却。
local BELT_MAX_TRIES = 6
local BELT_COOLDOWN  = 3

local function putOnBelt()
	if os.clock() < (Pipe.beltUntil or 0) then
		Pipe.detail = string.format("上带冷却中（%.0fs）", Pipe.beltUntil - os.clock())
		return false
	end
	local p = findPrompt("Put on conveyor", isInPlot)
	if not p then
		Pipe.detail = "等待传送带提示点"
		return false
	end
	-- 确认条件：手里那件原始包裹被服务端收走
	local _, ok = actPrompt(p, function() return carrying() == "none" end)
	if ok == false then
		Pipe.beltTries = (Pipe.beltTries or 0) + 1
		if Pipe.beltTries >= BELT_MAX_TRIES then
			Pipe.beltTries = 0
			Pipe.beltUntil = os.clock() + BELT_COOLDOWN
			Pipe.detail = string.format("上带 %d 次未生效，冷却 %ds", BELT_MAX_TRIES, BELT_COOLDOWN)
			log(Pipe.detail)
		else
			Pipe.detail = string.format("上带未被确认（%d/%d），下一轮重试", Pipe.beltTries, BELT_MAX_TRIES)
		end
	else
		Pipe.beltTries = 0
	end
	return true
end

local function pipeTick()
	if not cfg.pipe.on then
		setPhase("IDLE", "流水线未启用")
		Pipe.orderId = nil
		return
	end

	if not getHRP() then
		setPhase("WAIT", "角色不在场（等待复活）")
		return
	end

	local o = currentOrder()
	if not o then
		Pipe.orderId = nil
		setPhase("IDLE", "无进行中订单")
		-- 接单不在这里做：自动接单是独立线程，关掉流水线也能接单
		return
	end

	if tostring(Pipe.orderId) ~= tostring(o.id) then
		Pipe.orderId = o.id
		Pipe.phaseAt = os.clock()
		Pipe.beltTries, Pipe.beltUntil = 0, 0
		log(string.format("接手订单 #%s · %s · %s · %s$ · %s",
			tostring(o.id), tostring(o.product), tostring(o.status),
			tostring(o.price), o.isViral and "爆款" or "普通"))
	end

	scanThrottled(0.3)

	local st = tostring(o.status)
	local carry = carrying()

	-- 注意：currentOrder() 只返回"履约中"的订单，New 订单由 tryAutoAccept 独立处理，
	-- 这里不再保留 New 分支（原来是死代码，永远不会命中）。
	if st == "Ready to Pack" then
		if carry == "none" then
			setPhase("FETCH_RAW", "取原始包裹")
			if not pickRaw() then
				Pipe.detail = "仓库无可用包裹"
				if cfg.pipe.autoRestock then doRestock(false) end
			end
		else
			setPhase("TO_BELT", "放上传送带")
			putOnBelt()
		end
		return
	end

	if st == "Being Packed" then
		if carry == "labeled" then
			setPhase("TO_COURIER", "交给快递员")
			local p = findPrompt("Leave for courier", isInPlot)
			if p then
				actPrompt(p, function() return carrying() ~= "labeled" end)
			else
				Pipe.detail = "等待快递员提示点"
			end
		elseif carry == "unlabeled" then
			-- 原始包裹还在手上 = 上带其实没生效（状态可能已经先跳到 Being Packed），重试
			setPhase("TO_BELT", "重试上带（原包还在手上）")
			putOnBelt()
		else
			setPhase("FETCH_DONE", "取成品箱")
			local p = doneBoxPrompt()
			if p then
				local who = doneBoxCustomer()
				Pipe.detail = "取成品箱" .. (who and ("（" .. who .. "）") or "")
				actPrompt(p, function() return carrying() == "labeled" end)
			else
				Pipe.detail = "打包中…"
			end
		end
		return
	end

	if st == "Ready for Courier" then
		if carry == "labeled" then
			setPhase("TO_COURIER", "交给快递员")
			local p = findPrompt("Leave for courier", isInPlot)
			if p then actPrompt(p, function() return carrying() ~= "labeled" end) end
		else
			setPhase("WAIT_COURIER", "等待快递员取件")
		end
		return
	end

	-- 注：订单完成 = 状态离开履约集合，currentOrder() 已经不会再返回它，
	setPhase("WAIT", "未知状态 " .. st)
end

--=====================================================================
-- 8. 等状态就绪
--=====================================================================
local function waitForState(timeout)
	requestState()
	requestJobs()
	requestEmployees()
	requestCampaigns()
	requestQuest()
	requestDaily()
	requestContract()
	requestResearch()
	local t0 = os.clock()
	while ENABLED and os.clock() - t0 < (timeout or 6) do
		if type(S) == "table" and next(S) ~= nil then return true end
		task.wait(0.25)
	end
	return false
end
local stateReady = waitForState(8)
log(stateReady and "状态已就绪" or "状态等待超时（继续运行）")
safe(function() trackCompletions(true) end)

--=====================================================================
-- 秋容UI框架（提取自 秋容脚本VIP v2.2，已剔除所有游戏功能模块）
--=====================================================================
do
local _G_ = _G
_G._BFH_STOP_ALL = _G._BFH_STOP_ALL or {}
_G._BFH_PRESERVE = _G._BFH_PRESERVE or {}
local ChatPollThread = nil
    -- ===== SFX 音效 =====
    local SFX = {}
    do
        local TOAST_ID   = "rbxassetid://109856611672718"
        local WELCOME_ID = "rbxassetid://76390685841193"

        local function _play(id, vol, lifetime)
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = vol or 0.5
            s.Parent = game:GetService("CoreGui")
            s:Play()
            game:GetService("Debris"):AddItem(s, lifetime or 2)
        end

        function SFX.PlayToast()     _play(TOAST_ID, 0.4, 3) end
        function SFX.PlayWelcome()   _play(WELCOME_ID, 0.7, 10) end
    end

    local AppConfig = {
        Name = "大不列颠超入脚本-代发货大亨",
        Version = "正式版 1.0.0",
        Author = "合作:b站大不列颠超入",
        GuiName = "DropshipHubUI",
        DefaultPage = "about",
        MarqueeText = "大不列颠超入脚本-代发货大亨 | 合作:b站大不列颠超入 | 交流群 1105244454",
                AnnouncementTitle = "公告详情",
        AnnouncementText = [=[

【大不列颠超入脚本 · 代发货大亨】

作者：合作:b站大不列颠超入
版本：正式版 1.0.0
交流群：1105244454（脚本详细页可一键复制）

== 使用说明 ==
右Shift 开关窗口，悬浮看板可拖动
打开「流水线」页开启订单流水线，自动接单并完成全流程
建议搭配：自动接单 / 补货 / AI 调参 一起开
现金过低会自动刹车（保护模式），放心挂机

== 温馨提示 ==
有问题先看「工具 → 运行日志」里的报错
觉得好用记得支持作者，谢谢！
]=] .. string.char(10) .. string.char(10) .. "" .. string.char(10) .. string.rep(string.char(10), 1500) .. "居然翻到这里了，我就给你一个彩蛋吧。询问群主彩蛋内容是什么？可获得惊喜" .. string.rep(string.char(10), 500) .. "既然都翻到这了，要不加个群呗" .. string.rep(string.char(10), 1000),WindowSize = Vector2.new(760, 500),
        WindowPresets = {
            { label = "迷你", value = "mini", size = Vector2.new(620, 420) },
            { label = "标准", value = "standard", size = Vector2.new(760, 500) },
            { label = "宽屏", value = "wide", size = Vector2.new(900, 560) },
            { label = "大型", value = "large", size = Vector2.new(1020, 640) },
        },
        MinimumDpi = 65,
        MaximumDpi = 140,
        MaxRecent = 18,
    }

    local Theme = {
        Colors = {
            Background = Color3.fromRGB(10, 10, 10),
            Window = Color3.fromRGB(15, 15, 15),
            Panel = Color3.fromRGB(18, 18, 18),
            PanelDeep = Color3.fromRGB(8, 8, 8),
            Card = Color3.fromRGB(20, 20, 20),
            CardHover = Color3.fromRGB(26, 26, 26),
            Control = Color3.fromRGB(24, 24, 24),
            ControlHover = Color3.fromRGB(32, 32, 32),
            Stroke = Color3.fromRGB(34, 34, 34),
            StrokeStrong = Color3.fromRGB(48, 48, 48),
            Text = Color3.fromRGB(242, 242, 242),
            TextMuted = Color3.fromRGB(156, 156, 156),
            TextDim = Color3.fromRGB(112, 112, 112),
            Accent = Color3.fromRGB(60, 140, 255),
            AccentSoft = Color3.fromRGB(32, 72, 132),
            AccentDim = Color3.fromRGB(22, 44, 76),
            Success = Color3.fromRGB(82, 180, 126),
            Warning = Color3.fromRGB(226, 176, 74),
            Danger = Color3.fromRGB(235, 92, 92),
            ToggleOff = Color3.fromRGB(52, 52, 52),
            Overlay = Color3.fromRGB(0, 0, 0),
            Transparent = Color3.fromRGB(255, 255, 255),
        },

        Radius = {
            Window = 8,
            Panel = 6,
            Control = 5,
            Pill = 999,
        },

        Font = Enum.Font.SourceSans,
        FontBold = Enum.Font.SourceSansBold,

        Animation = {
            Press = 0.08,
            Fast = 0.12,
            Normal = 0.18,
            Slow = 0.26,
            TooltipDelay = 0,
            TouchTooltipDelay = 0.42,
            ToastDuration = 2.6,
            Style = Enum.EasingStyle.Quad,
            EmphasisStyle = Enum.EasingStyle.Back,
            Direction = Enum.EasingDirection.Out,
        },
    }

    local UI = {
        RootGui = nil,
        Main = nil,
        ShowButton = nil,
        Content = nil,
        ContentLayout = nil,
        Sidebar = nil,
        SidebarCollapsed = false,
        SidebarButtons = {},
        _sidebarVisualState = {},
        ShowButtonDragged = false,
        LogList = nil,
        LogVersion = 0,
        _renderedLogList = nil,
        _renderedLogVersion = -1,
        ToastRoot = nil,
        ToastId = 0,
        ToastToken = 0,
        ToastThrottle = {},
        ToastLastMsg = {},
        Tooltip = nil,
        TooltipSource = nil,
        TooltipToken = 0,
        VisibleToken = 0,
        ModalRoot = nil,
        Announcement = nil,
        MarqueeToken = 0,
        Scale = nil,
        ToastScale = nil,
        TooltipScale = nil,
        ModalScale = nil,
        ShowScale = nil,
        Connections = {},
        PageConnections = {},
        LogConnections = {},
        _trackedConnections = setmetatable({}, { __mode = "k" }),
    }

    local Components = {}
    local Registry = {
        Callbacks = {},
        Meta = {},
    }
    local Pages = {
        List = {},
        ById = {},
    }
    local State = {
        CurrentPage = AppConfig.DefaultPage,
        SearchText = "",
        Toggles = {},
        Sliders = {},
        Inputs = {},
        Dropdowns = {},
        Segments = {},
        Collapsed = {},
        SubPages = {},
        Logs = {},
        Controls = {},
        VisibleControlKeys = {},
        Favorites = {},
        FavoriteOrder = {},
        FavoriteCount = 0,
        Recent = {},
        Keybinds = {},
        Colors = {},
        Numbers = {},
        MultiDropdowns = {},
        ConfirmEnabled = true,
        SearchScope = "current",
        SearchReturnPage = AppConfig.DefaultPage,
        WindowPreset = "mini",
        WindowTransparency = 0,
        DpiScale = 0.75,

        }

    local STATE_BUCKET_NAMES = {
        toggle = "Toggles",
        slider = "Sliders",
        input = "Inputs",
        dropdown = "Dropdowns",
        segment = "Segments",
        number = "Numbers",
        color = "Colors",
        ["multi-dropdown"] = "MultiDropdowns",
    }
    local STATE_STRING_ONLY = {
        input = true,
        dropdown = true,
        segment = true,
        color = true,
    }

    -- ===== ESP 透视模块（自建） =====
    local Services = {
        TweenService = game:GetService("TweenService"),
        UserInputService = game:GetService("UserInputService"),
        TextService = game:GetService("TextService"),
        Players = game:GetService("Players"),
        CoreGui = game:GetService("CoreGui"),
        RunService = game:GetService("RunService"),
    }

    local DefaultProperties = {
        Frame = {
            BorderSizePixel = 0,
        },
        ScrollingFrame = {
            BorderSizePixel = 0,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Colors.StrokeStrong,
            ScrollingDirection = Enum.ScrollingDirection.Y,
        },
        TextLabel = {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = Theme.Font,
            TextColor3 = Theme.Colors.Text,
            TextSize = 15,
            TextWrapped = false,
        },
        TextButton = {
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Font = Theme.Font,
            TextColor3 = Theme.Colors.Text,
            TextSize = 15,
            Text = "",
        },
        TextBox = {
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = Theme.Font,
            TextColor3 = Theme.Colors.Text,
            TextSize = 15,
            PlaceholderColor3 = Theme.Colors.TextDim,
        },
        ImageButton = {
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        },
        ImageLabel = {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        },
        UIListLayout = {
            SortOrder = Enum.SortOrder.LayoutOrder,
        },
    }

    local function New(className, properties)
        local object = Instance.new(className)

        for key, value in pairs(DefaultProperties[className] or {}) do
            object[key] = value
        end

        for key, value in pairs(properties or {}) do
            object[key] = value
        end

        return object
    end

    local function Tween(object, properties, duration, easingStyle, easingDirection)
        if not object then
            return nil
        end

        local tweenInfo = TweenInfo.new(
            duration or Theme.Animation.Normal,
            easingStyle or Theme.Animation.Style,
            easingDirection or Theme.Animation.Direction
        )
        local tween = Services.TweenService:Create(object, tweenInfo, properties)
        tween:Play()
        return tween
    end

    local function IsPointerInput(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end

    local function AddCorner(parent, radius)
        return New("UICorner", {
            CornerRadius = UDim.new(0, radius or Theme.Radius.Control),
            Parent = parent,
        })
    end

    local function AddStroke(parent, color, thickness)
        return New("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = color or Theme.Colors.Stroke,
            Thickness = thickness or 1,
            Parent = parent,
        })
    end

    local function AddPadding(parent, left, right, top, bottom)
        return New("UIPadding", {
            PaddingLeft = UDim.new(0, left or 0),
            PaddingRight = UDim.new(0, right or left or 0),
            PaddingTop = UDim.new(0, top or 0),
            PaddingBottom = UDim.new(0, bottom or top or 0),
            Parent = parent,
        })
    end

    local function UpdateScrollCanvas(scroller, layout, extra)
        if scroller and scroller.Parent and layout and layout.Parent then
            local contentHeight = layout.AbsoluteContentSize.Y + (extra or 48)
            local viewportHeight = scroller.AbsoluteWindowSize and scroller.AbsoluteWindowSize.Y or scroller.AbsoluteSize.Y
            local targetHeight = math.max(contentHeight, viewportHeight + 1)
            if scroller.CanvasSize.Y.Offset ~= targetHeight then
                scroller.CanvasSize = UDim2.new(0, 0, 0, targetHeight)
            end
        end
    end

    local function SetScrollCanvas(scroller, layout, extra, scope)
        local function update()
            UpdateScrollCanvas(scroller, layout, extra)
        end

        local connection = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
        if UI.Track then
            UI.Track(connection, scope or "page")
        end

        local sizeConnection = scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
        if UI.Track then
            UI.Track(sizeConnection, scope or "page")
        end

        update()
        task.defer(update)
        task.delay(0.15, update)
    end

    local function DisconnectConnections(connections)
        for _, connection in ipairs(connections) do
            if connection and connection.Connected then
                connection:Disconnect()
            end
            if UI._trackedConnections and connection then
                UI._trackedConnections[connection] = nil
            end
        end

        table.clear(connections)
    end

    local function ContainsText(value, query)
        if query == "" then
            return true
        end

        if value == nil then
            return false
        end

        return string.find(string.lower(tostring(value)), query, 1, true) ~= nil
    end

    local function ShallowCopy(source)
        local copy = {}
        for key, value in pairs(source or {}) do
            copy[key] = value
        end
        return copy
    end

    local function ColorToHex(color)
        local r = math.floor(color.R * 255 + 0.5)
        local g = math.floor(color.G * 255 + 0.5)
        local b = math.floor(color.B * 255 + 0.5)
        return string.format("#%02X%02X%02X", r, g, b)
    end

    local function RefreshContentCanvas()
        if UI.Content and UI.ContentLayout then
            UpdateScrollCanvas(UI.Content, UI.ContentLayout, 20)
            task.delay(Theme.Animation.Normal + 0.04, function()
                if UI.Content and UI.ContentLayout then
                    UpdateScrollCanvas(UI.Content, UI.ContentLayout, 20)
                end
            end)
        end
    end

    local function ResolveOptionValue(option)
        if type(option) == "table" then
            return option.value
        end
        return option
    end

    local function ResolveOptionLabel(option)
        if type(option) == "table" then
            return option.label or tostring(option.value)
        end
        return tostring(option)
    end

    local function ClampFrameToScreen(frame, position)
        if not frame or not UI.RootGui then
            return position
        end

        local container = frame.Parent or UI.RootGui
        local rootSize = container.AbsoluteSize
        local frameSize = frame.AbsoluteSize
        local anchor = frame.AnchorPoint
        local minX = math.floor(frameSize.X * anchor.X)
        local minY = math.floor(frameSize.Y * anchor.Y)
        local maxX = math.max(minX, rootSize.X - math.floor(frameSize.X * (1 - anchor.X)))
        local maxY = math.max(minY, rootSize.Y - math.floor(frameSize.Y * (1 - anchor.Y)))
        local scaledX = rootSize.X * position.X.Scale
        local scaledY = rootSize.Y * position.Y.Scale
        local absoluteX = math.clamp(scaledX + position.X.Offset, minX, maxX)
        local absoluteY = math.clamp(scaledY + position.Y.Offset, minY, maxY)
        local x = absoluteX - scaledX
        local y = absoluteY - scaledY

        return UDim2.new(position.X.Scale, x, position.Y.Scale, y)
    end

    function State:GetBucket(kind)
        return self[STATE_BUCKET_NAMES[kind] or "Inputs"]
    end

    function State:Get(kind, key, defaultValue)
        local bucket = self:GetBucket(kind)
        if bucket[key] == nil then
            bucket[key] = defaultValue
        end

        return bucket[key]
    end

    function State:Set(kind, key, value)
        if type(value) == "string" and value:find("^table: 0") then return false end
        if STATE_STRING_ONLY[kind] and type(value) == "table" then return false end
        local bucket = self:GetBucket(kind)
        if bucket[key] == value then return false end
        bucket[key] = value
        return true
    end

    function State:IsFavorite(key)
        return self.Favorites[key] == true
    end

    function State:SetFavorite(key, enabled)
        if enabled then
            if not self.Favorites[key] then
                self.Favorites[key] = true
                table.insert(self.FavoriteOrder, key)
                self.FavoriteCount = self.FavoriteCount + 1
            end
        else
            if self.Favorites[key] then
                self.Favorites[key] = nil
                self.FavoriteCount = math.max(0, self.FavoriteCount - 1)
                for i, k in ipairs(self.FavoriteOrder) do
                    if k == key then
                        table.remove(self.FavoriteOrder, i)
                        break
                    end
                end
            end
        end
    end

    function State:TouchRecent(key, title, page)
        if not key or key == "" then
            return
        end

        for index = #self.Recent, 1, -1 do
            if self.Recent[index].key == key then
                table.remove(self.Recent, index)
                break
            end
        end

        table.insert(self.Recent, 1, {
            key = key,
            title = title or key,
            page = page or "",
            time = os.date("%H:%M:%S"),
        })

        while #self.Recent > AppConfig.MaxRecent do
            table.remove(self.Recent)
        end
    end


    function State:CountFavorites()
        return self.FavoriteCount
    end

    function State:AddLog(level, message, key)
        if type(message) ~= "string" then
            message = type(message) == "table" and "操作返回了无效值" or tostring(message or "")
        end
        table.insert(self.Logs, 1, {
            Time = os.date("%H:%M:%S"),
            Level = level or "INFO",
            Message = message or "",
            Key = key or "",
        })
        UI.LogVersion = (UI.LogVersion or 0) + 1

        while #self.Logs > 120 do
            table.remove(self.Logs)
        end

        if UI.ScheduleLogRefresh then
            UI.ScheduleLogRefresh()
        elseif UI.RefreshLogs then
            UI.RefreshLogs()
        end

        if UI.Notify then
            UI.Notify(level or "INFO", message or "", key or "")
        end
    end

    function State:ClearLogs()
        self.Logs = {}
        UI.LogVersion = (UI.LogVersion or 0) + 1

        if UI.ScheduleLogRefresh then
            UI.ScheduleLogRefresh()
        elseif UI.RefreshLogs then
            UI.RefreshLogs()
        end
    end

    function State:RegisterControl(key, control)
        if not key or key == "" or not control then
            return
        end

        self.Controls[key] = control
        self.VisibleControlKeys[key] = true
    end

    function State:ClearVisibleControls()
        for key in pairs(self.VisibleControlKeys) do
            self.Controls[key] = nil
        end
        self.VisibleControlKeys = {}
    end

    function Registry.Noop()
    end

    function Registry.Ensure(key, meta)
        if not key or key == "" then
            return
        end

        if Registry.Meta[key] then
            Registry.Callbacks[key] = Registry.Callbacks[key] or Registry.Noop
            return
        end

        Registry.Meta[key] = meta or {}
        Registry.Callbacks[key] = Registry.Callbacks[key] or Registry.Noop
    end


    function Registry.Invoke(key, payload)
        local callback = Registry.Callbacks[key] or Registry.Noop
        local ok, err = pcall(callback, payload or {})

        if not ok then
            State:AddLog("ERROR", tostring(err), key)
        end
    end


    function Components.Interaction(object, normalColor, hoverColor, pressedColor)
        if not object then
            return
        end

        local function resolve(value)
            if type(value) == "function" then
                return value()
            end
            return value
        end

        local isHovering = false
        local isPressed = false

        object.MouseEnter:Connect(function()
            isHovering = true
            local color = resolve(hoverColor)
            if not isPressed and color then
                Tween(object, { BackgroundColor3 = color }, Theme.Animation.Fast)
            end
        end)

        object.MouseLeave:Connect(function()
            isHovering = false
            local color = resolve(normalColor)
            if not isPressed and color then
                Tween(object, { BackgroundColor3 = color }, Theme.Animation.Fast)
            end
        end)

        object.InputBegan:Connect(function(input)
            if not IsPointerInput(input) then
                return
            end

            isPressed = true
            local color = resolve(pressedColor) or resolve(hoverColor)
            if color then
                Tween(object, { BackgroundColor3 = color }, Theme.Animation.Press)
            end
        end)

        object.InputEnded:Connect(function(input)
            if not IsPointerInput(input) then
                return
            end

            isPressed = false
            local color = isHovering and (resolve(hoverColor) or resolve(normalColor)) or resolve(normalColor)
            if color then
                Tween(object, { BackgroundColor3 = color }, Theme.Animation.Fast)
            end
        end)
    end

    function Components.Tooltip(object, text)
        if not text or text == "" then
            return
        end

        local touchToken = 0
        local touchStart = nil

        object.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and UI.ShowTooltip then
                touchToken += 1
                local token = touchToken
                touchStart = input.Position
                task.delay(Theme.Animation.TouchTooltipDelay, function()
                    if token == touchToken and touchStart and UI.ShowTooltip then
                        UI.ShowTooltip(text, object)
                    end
                end)
            end
        end)

        object.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and touchStart then
                local delta = input.Position - touchStart
                if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
                    touchToken += 1
                    touchStart = nil
                    if UI.HideTooltip then
                        UI.HideTooltip(object)
                    end
                end
            end
        end)

        object.MouseLeave:Connect(function()
            if UI.HideTooltip then
                UI.HideTooltip()
            end
        end)

        object.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                touchToken += 1
                touchStart = nil
                if UI.HideTooltip then
                    UI.HideTooltip(object)
                end
            end

            if IsPointerInput(input) and UI.HideTooltip then
                UI.HideTooltip(object)
            end
        end)

        object.SelectionGained:Connect(function()
            if UI.ShowTooltip then
                UI.ShowTooltip(text, object)
            end
        end)

        object.SelectionLost:Connect(function()
            if UI.HideTooltip then
                UI.HideTooltip(object)
            end
        end)
    end

    function Components.Label(parent, text, size, color, bold)
        return New("TextLabel", {
            Font = bold and Theme.FontBold or Theme.Font,
            Text = text or "",
            TextColor3 = color or Theme.Colors.Text,
            TextSize = size or 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Parent = parent,
        })
    end

    function Components.IconButton(parent, key, iconText, tooltipText, onClick)
        Registry.Ensure(key, {
            Type = "icon-button",
            Title = tooltipText,
            Internal = true,
        })

        local button = New("TextButton", {
            Name = key,
            BackgroundColor3 = Theme.Colors.Control,
            Size = UDim2.fromOffset(28, 28),
            Text = iconText or "?",
            TextSize = 14,
            TextColor3 = Theme.Colors.TextMuted,
            Parent = parent,
        })
        AddCorner(button, Theme.Radius.Control)
        AddStroke(button)
        Components.Interaction(button, Theme.Colors.Control, Theme.Colors.ControlHover, Theme.Colors.AccentDim)
        Components.Tooltip(button, tooltipText or key)
        local icnScale = New("UIScale", { Scale = 1, Parent = button })

        button.MouseButton1Click:Connect(function()
            Tween(icnScale, { Scale = 0.92 }, Theme.Animation.Press)
            task.delay(Theme.Animation.Press + 0.04, function()
                Tween(icnScale, { Scale = 1 }, Theme.Animation.Fast)
            end)
            if onClick then
                onClick()
            end
        end)

        return button
    end

    function Components.Section(parent, title, subtitle)
        local section = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = parent,
        })

        local layout = New("UIListLayout", {
            Padding = UDim.new(0, 8),
            Parent = section,
        })

        local header = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, subtitle and 42 or 24),
            Parent = section,
        })

        local titleLabel = Components.Label(header, title, 18, Theme.Colors.Text, true)
        titleLabel.Size = UDim2.new(1, 0, 0, 20)
        titleLabel.Position = UDim2.fromOffset(0, 0)
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center

        if subtitle then
            local subtitleLabel = Components.Label(header, subtitle, 14, Theme.Colors.TextDim, false)
            subtitleLabel.Size = UDim2.new(1, 0, 0, 18)
            subtitleLabel.Position = UDim2.fromOffset(0, 22)
            subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
        end

        return section, layout
    end

    function Components.ControlFrame(parent, height)
        local frame = New("Frame", {
            BackgroundColor3 = Theme.Colors.Card,
            Size = UDim2.new(1, 0, 0, height or 48),
            Parent = parent,
        })
        AddCorner(frame, Theme.Radius.Panel)
        AddStroke(frame)
        return frame
    end

    function Components.TitleBlock(parent, item, rightWidth, centerAlign)
        local title = Components.Label(parent, item.title or item.key, 16, Theme.Colors.Text, false)
        title.Position = UDim2.fromOffset(12, item.desc and 7 or 0)
        title.Size = UDim2.new(1, -(rightWidth or 110) - 24, 0, item.desc and 19 or 1)
        title.TextTruncate = Enum.TextTruncate.AtEnd
        if centerAlign then title.TextXAlignment = Enum.TextXAlignment.Center end

        if not item.desc then
            title.Size = UDim2.new(1, -(rightWidth or 110) - 24, 1, 0)
        end

        if item.desc then
            local desc = Components.Label(parent, item.desc, 13, Theme.Colors.TextDim, false)
            desc.Position = UDim2.fromOffset(12, 27)
            desc.Size = UDim2.new(1, -(rightWidth or 110) - 24, 0, 16)
            desc.TextTruncate = Enum.TextTruncate.AtEnd
            if centerAlign then desc.TextXAlignment = Enum.TextXAlignment.Center end
        end

        Components.Tooltip(parent, (item.desc or item.title))

        return title
    end

    function Components.InvokeItem(item, payload)
        payload = payload or {}
        payload.key = item.key
        payload.item = item
        payload.state = State
        State:TouchRecent(item.key, item.title, item.page)

        if item.onChanged then
            local ok, err = pcall(item.onChanged, payload.value, payload)
            if not ok then
                State:AddLog("ERROR", tostring(err), item.key)
            end
        end

        if not item.internal then
            Registry.Invoke(item.key, payload)
        end
    end

    function Components.Button(parent, item)
        Registry.Ensure(item.key, {
            Type = "button",
            Title = item.title,
            Page = item.page,
        })

        local button = New("TextButton", {
            Name = item.key,
            BackgroundColor3 = Theme.Colors.Card,
            Size = UDim2.new(1, 0, 0, 46),
            Text = "",
            Parent = parent,
        })
        AddCorner(button, Theme.Radius.Panel)
        AddStroke(button)
        Components.Interaction(button, Theme.Colors.Card, Theme.Colors.CardHover, Theme.Colors.ControlHover)
        local btnScale = New("UIScale", { Scale = 1, Parent = button })

        Components.TitleBlock(button, item, 88)

        local action = Components.Label(button, item.actionText or "执行", 13, Theme.Colors.TextMuted, true)
        action.AnchorPoint = Vector2.new(1, 0.5)
        action.BackgroundColor3 = Theme.Colors.Control
        action.BackgroundTransparency = 0
        action.Position = UDim2.new(1, -10, 0.5, 0)
        action.Size = UDim2.fromOffset(62, 24)
        action.TextXAlignment = Enum.TextXAlignment.Center
        AddCorner(action, Theme.Radius.Control)
        AddStroke(action)

        local function runButton()
            Tween(btnScale, { Scale = 0.96 }, Theme.Animation.Press)
            task.delay(Theme.Animation.Press + 0.04, function()
                Tween(btnScale, { Scale = 1 }, Theme.Animation.Normal)
            end)
            if not item.internal then
                State:AddLog("ACTION", item.title or "按钮触发", item.key)
            end
            Components.InvokeItem(item, {
                type = "button",
            })
        end

        button.MouseButton1Click:Connect(function()
            if item.confirm and UI.Confirm then
                UI.Confirm(item.confirmTitle or item.title or "确认操作", item.confirmText or item.desc or "确认执行这个 UI 操作？", runButton)
            else
                runButton()
            end
        end)

        return button
    end

    function Components.FavoriteButton(row, item)
        local isFav = State:IsFavorite(item.key)
        local favBtn = New("TextButton", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(18, 18),
            Text = isFav and "★" or "☆",
            TextColor3 = isFav and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(100, 100, 100),
            TextSize = 14,
            Font = Theme.FontBold,
            Parent = row,
            ZIndex = 10,
        })
        AddStroke(favBtn, isFav and Color3.fromRGB(255, 180, 30) or Color3.fromRGB(60, 60, 60))
        favBtn.MouseButton1Click:Connect(function()
            local nf = not State:IsFavorite(item.key)
            State:SetFavorite(item.key, nf)
            favBtn.Text = nf and "★" or "☆"
            favBtn.TextColor3 = nf and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(100, 100, 100)
            if favBtn:FindFirstChildOfClass("UIStroke") then favBtn:FindFirstChildOfClass("UIStroke"):Destroy() end
            AddStroke(favBtn, nf and Color3.fromRGB(255, 180, 30) or Color3.fromRGB(60, 60, 60))
        end)
    end

    function Components.Toggle(parent, item)
        Registry.Ensure(item.key, {
            Type = "toggle",
            Title = item.title,
            Page = item.page,
        })
        Registry.Meta[item.key].Item = item  -- 缓存 onChanged，供快捷面板/快捷键在页面未渲染时调用

        local row = New("TextButton", {
            Name = item.key,
            BackgroundColor3 = Theme.Colors.Card,
            Size = UDim2.new(1, 0, 0, 48),
            Text = "",
            Parent = parent,
        })
        AddCorner(row, Theme.Radius.Panel)
        AddStroke(row)
        Components.Interaction(row, Theme.Colors.Card, Theme.Colors.CardHover, Theme.Colors.ControlHover)

        Components.TitleBlock(row, item, 72)

        local track = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Colors.ToggleOff,
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(42, 22),
            Parent = row,
        })
        AddCorner(track, Theme.Radius.Pill)

        local knob = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Colors.Text,
            Size = UDim2.fromOffset(18, 18),
            Parent = track,
        })
        AddCorner(knob, Theme.Radius.Pill)

        -- 行内颜色块（item.colorKey 存在时显示在开关左侧，点开色轮）
        if item.colorKey then
            local colorSwatch = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = State:Get("color", item.colorKey, item.colorDefault or Color3.new(1, 1, 1)),
                Position = UDim2.new(1, -62, 0.5, 0),
                Size = UDim2.fromOffset(20, 20),
                Text = "",
                Parent = row,
            })
            AddCorner(colorSwatch, 5)
            AddStroke(colorSwatch, Theme.Colors.StrokeStrong)
            colorSwatch.MouseButton1Click:Connect(function()
                local cur = State:Get("color", item.colorKey, item.colorDefault or Color3.new(1, 1, 1))
                Components.OpenColorWheel(item.title, cur, function(c)
                    State:Set("color", item.colorKey, c)
                    colorSwatch.BackgroundColor3 = c
                    if item.onColorChanged then pcall(item.onColorChanged, c) end
                end)
            end)
        end

        local value = State:Get("toggle", item.key, item.default == true)

        local function paint(instant)
            local targetColor = value and Theme.Colors.Accent or Theme.Colors.ToggleOff
            local targetPosition = value and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0)
            local targetSize = value and UDim2.fromOffset(19, 19) or UDim2.fromOffset(18, 18)
            local stroke = row:FindFirstChildOfClass("UIStroke")
            local strokeColor = value and Theme.Colors.AccentSoft or Theme.Colors.Stroke

            if instant then
                track.BackgroundColor3 = targetColor
                knob.Position = targetPosition
                knob.Size = targetSize
                if stroke then
                    stroke.Color = strokeColor
                end
            else
                Tween(track, { BackgroundColor3 = targetColor }, Theme.Animation.Normal)
                Tween(knob, { Position = targetPosition, Size = targetSize }, Theme.Animation.Normal)
                if stroke then
                    Tween(stroke, { Color = strokeColor }, Theme.Animation.Normal)
                end
            end
        end

        local function setValue(newValue, silent)
            value = newValue == true
            State:Set("toggle", item.key, value)
            paint(false)

            if not silent then
                local pageTitle = item.page and Pages.ById[item.page] and Pages.ById[item.page].title or "功能"
                local logMsg = (item.title or item.key) .. " 已" .. (value and "开启" or "关闭")
                State:AddLog(pageTitle, logMsg, item.key)
                Components.InvokeItem(item, {
                    type = "toggle",
                    value = value,
                })
            end
        end

        row.MouseButton1Click:Connect(function()
            setValue(not value, false)
        end)

        State:RegisterControl(item.key, {
            Type = "toggle",
            SetValue = setValue,
            GetValue = function()
                return value
            end,
        })

        Components.FavoriteButton(row, item)

        paint(true)
        return row
    end

    function Components.Slider(parent, item)
        Registry.Ensure(item.key, {
            Type = "slider",
            Title = item.title,
            Page = item.page,
        })
        -- 存储范围供快捷栏使用
        Registry.Meta[item.key].Min = item.min or 0
        Registry.Meta[item.key].Max = item.max or 100
        Registry.Meta[item.key].Step = item.step or 1

        local minValue = item.min or 0
        local maxValue = item.max or 100
        if type(item.dynamicMax) == "function" then
            local dm = item.dynamicMax()
            if dm and dm > minValue then maxValue = dm end
        end
        Registry.Meta[item.key].Max = maxValue
        if maxValue < minValue then
            minValue, maxValue = maxValue, minValue
        end
        local step = tonumber(item.step) or 1
        if step <= 0 then step = 1 end

        local value = State:Get("slider", item.key, item.default or minValue)
        local dragging, changedWhileDragging = false, false

        -- ===== 所有函数定义（必须在 UI 创建前定义完毕） =====
        local function normalize(raw)
            raw = math.clamp(raw, minValue, maxValue)
            local stepped = math.floor(((raw - minValue) / step) + 0.5) * step + minValue
            return math.clamp(stepped, minValue, maxValue)
        end
        local function formatValue(nextValue)
            if item.format then return string.format(item.format, nextValue) end
            if math.floor(nextValue) == nextValue then return tostring(nextValue) end
            return string.format("%.2f", nextValue)
        end
        local paint, setValue, setFromInput

        local row = Components.ControlFrame(parent, 64)
        Components.TitleBlock(row, item, 132)

        local valueHint = New("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -72, 0, 10),
            Size = UDim2.fromOffset(140, 14),
            Text = (_G.BFH_ANTIFLING_ON and "点击此处输入无限数值 →") or "点击此处输入精确数值 →",
            Name = "ValueHint",
            TextSize = 10,
            TextColor3 = Theme.Colors.TextDim,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = row,
        })

        local valueInput = New("TextBox", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = Theme.Colors.Control,
            Position = UDim2.new(1, -12, 0, 5),
            Size = UDim2.fromOffset(56, 22),
            Text = "",
            TextSize = 12,
            TextColor3 = Theme.Colors.TextMuted,
            TextXAlignment = Enum.TextXAlignment.Center,
            ClearTextOnFocus = false,
            Parent = row,
        })
        AddCorner(valueInput, Theme.Radius.Control)
        local valueStroke = AddStroke(valueInput)

        valueInput.Focused:Connect(function()
            Tween(valueStroke, { Color = Theme.Colors.AccentSoft }, Theme.Animation.Fast)
        end)

        setValue = function(nextValue, silent, instant)
            value = normalize(nextValue)
            State:Set("slider", item.key, value)
            paint(instant == true)
            if not silent then
                State:AddLog("SLIDER", (item.title or item.key) .. " = " .. formatValue(value), item.key)
                Components.InvokeItem(item, { type = "slider", value = value })
            end
            task.delay(Theme.Animation.Slow, function()
                if valueInput and valueInput.Parent then
                    Tween(valueInput, { TextColor3 = Theme.Colors.TextMuted }, Theme.Animation.Fast)
                end
            end)
        end


        local bar = New("TextButton", {
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.new(0, 12, 1, -14),
            Size = UDim2.new(1, -24, 0, 5),
            Text = "",
            Parent = row,
        })
        AddCorner(bar, Theme.Radius.Pill)

        local fill = New("Frame", {
            BackgroundColor3 = Theme.Colors.Accent,
            Size = UDim2.new(0, 0, 1, 0),
            Parent = bar,
        })
        AddCorner(fill, Theme.Radius.Pill)

        local knob = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Colors.Text,
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(10, 10),
            Parent = bar,
        })
        AddCorner(knob, Theme.Radius.Pill)

        paint = function(instant)
            local percent = 0
            if maxValue ~= minValue then
                percent = (value - minValue) / (maxValue - minValue)
            end
            percent = math.clamp(percent, 0, 1)
            valueInput.Text = formatValue(value)

            local fillSize = UDim2.new(percent, 0, 1, 0)
            local knobPosition = UDim2.new(percent, 0, 0.5, 0)

            if instant then
                fill.Size = fillSize
                knob.Position = knobPosition
                valueInput.TextColor3 = Theme.Colors.TextMuted
            else
                Tween(fill, { Size = fillSize }, Theme.Animation.Fast)
                Tween(knob, { Position = knobPosition }, Theme.Animation.Fast)
                Tween(valueInput, { TextColor3 = Theme.Colors.Text }, Theme.Animation.Fast)
            end
        end


        local _dragInput, _parentSF = nil, nil
        local function setFromInput(input)
            -- 绝对位置：手指/鼠标在滑块上的位置直接对应值
            local barAbsX = bar.AbsolutePosition.X
            local barW = math.max(bar.AbsoluteSize.X, 1)
            local clickPercent = math.clamp((input.Position.X - barAbsX) / barW, 0, 1)
            local newVal = normalize(minValue + (maxValue - minValue) * clickPercent)
            local prevVal = value
            setValue(newVal, true)
            if item.onChanged then pcall(item.onChanged, value) end
            if value ~= prevVal then
                State:AddLog("SLIDER", (item.title or item.key) .. " = " .. formatValue(value), item.key)
            end
            changedWhileDragging = true
        end

        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if Components.__sliderLock then return end
                dragging = true
                _dragInput = input  -- 捕获启动拖拽的那根手指/鼠标，只跟随它
                Components.__sliderLock = true
                local _p = bar.Parent
                while _p do
                    if _p:IsA("ScrollingFrame") then _parentSF = _p; _p.ScrollingEnabled = false; break end
                    _p = _p.Parent
                end
                setFromInput(input)
            end
        end)

        UI.Track(Services.UserInputService.InputChanged:Connect(function(input)
            if not dragging or input ~= _dragInput then return end
            setFromInput(input)
        end), "page")

        UI.Track(Services.UserInputService.InputEnded:Connect(function(input)
            if input ~= _dragInput then return end
            if dragging and changedWhileDragging then
                setValue(value, true)
            end
            dragging = false
            changedWhileDragging = false
            _dragInput = nil
            Components.__sliderLock = nil
            if _parentSF then _parentSF.ScrollingEnabled = true; _parentSF = nil end
            UI.RefreshQuickPanel()
        end), "page")

        State:RegisterControl(item.key, {
            Type = "slider",
            SetValue = setValue,
            GetValue = function()
                return value
            end,
        })

        Components.FavoriteButton(row, item)

        valueInput.FocusLost:Connect(function(enterPressed)
            Tween(valueStroke, { Color = Theme.Colors.Stroke }, Theme.Animation.Fast)
            local num = tonumber(valueInput.Text)
            if num then
                value = normalize(num)
                State:Set("slider", item.key, value)
                paint(true)
                State:AddLog("SLIDER", (item.title or item.key) .. " = " .. formatValue(value), item.key)
                Components.InvokeItem(item, { type = "slider", value = value })
                task.delay(Theme.Animation.Slow, function()
                    if valueInput and valueInput.Parent then
                        Tween(valueInput, { TextColor3 = Theme.Colors.TextMuted }, Theme.Animation.Fast)
                    end
                end)
            else
                valueInput.Text = formatValue(value)
            end
        end)

        value = normalize(value)
        paint(true)
        return row
    end

    function Components.TextInput(parent, item)
        Registry.Ensure(item.key, {
            Type = "input",
            Title = item.title,
            Page = item.page,
        })

        local row = Components.ControlFrame(parent, 50)
        Components.TitleBlock(row, item, 220)

        local input = New("TextBox", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Colors.PanelDeep,
            PlaceholderText = item.placeholder or "",
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(item.width or 190, 28),
            Text = State:Get("input", item.key, item.default or ""),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
        AddCorner(input, Theme.Radius.Control)
        local inputStroke = AddStroke(input)
        AddPadding(input, 8, 8, 0, 0)

        input.Focused:Connect(function()
            Tween(inputStroke, { Color = Theme.Colors.AccentSoft }, Theme.Animation.Fast)
        end)

        input.FocusLost:Connect(function()
            Tween(inputStroke, { Color = Theme.Colors.Stroke }, Theme.Animation.Fast)
            State:Set("input", item.key, input.Text)
            State:AddLog("INPUT", (item.title or item.key) .. " = " .. input.Text, item.key)
            Components.InvokeItem(item, {
                type = "input",
                value = input.Text,
            })
        end)

        State:RegisterControl(item.key, {
            Type = "input",
            SetValue = function(value)
                if type(value) == "table" then return end
                input.Text = tostring(value or "")
                State:Set("input", item.key, input.Text)
            end,
            GetValue = function()
                return input.Text
            end,
        })

        return row
    end

    function Components.Dropdown(parent, item)
        Registry.Ensure(item.key, {
            Type = "dropdown",
            Title = item.title,
            Page = item.page,
        })

        -- 支持动态选项：optionsCallback 在渲染时调用（如存档配置列表）
        local options = item.options or {}
        if type(item.optionsCallback) == "function" then
            local okOpt, dynOpt = pcall(item.optionsCallback)
            if okOpt and type(dynOpt) == "table" then options = dynOpt end
        end

        local root = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 50),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = parent,
        })

        local layout = New("UIListLayout", {
            Padding = UDim.new(0, 6),
            Parent = root,
        })

        local row = Components.ControlFrame(root, 50)
        Components.TitleBlock(row, item, 190)

        local display = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(170, 28),
            Text = "",
            Parent = row,
        })
        AddCorner(display, Theme.Radius.Control)
        local displayStroke = AddStroke(display)
        Components.Interaction(display, Theme.Colors.PanelDeep, Theme.Colors.Control, Theme.Colors.ControlHover)

        local displayLabel = Components.Label(display, "", 14, Theme.Colors.TextMuted, false)
        displayLabel.Position = UDim2.fromOffset(8, 0)
        displayLabel.Size = UDim2.new(1, -28, 1, 0)
        displayLabel.TextTruncate = Enum.TextTruncate.AtEnd

        local arrow = Components.Label(display, "v", 13, Theme.Colors.TextDim, true)
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, -8, 0.5, 0)
        arrow.Size = UDim2.fromOffset(14, 16)
        arrow.TextXAlignment = Enum.TextXAlignment.Center

        local optionsFrame = New("ScrollingFrame", {
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Size = UDim2.new(1, 0, 0, 0),
            Visible = false,
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarThickness = 3,
            Parent = root,
        })
        AddCorner(optionsFrame, Theme.Radius.Panel)
        AddStroke(optionsFrame)
        AddPadding(optionsFrame, 8, 8, 8, 8)

        local optionsLayout = New("UIListLayout", {
            Padding = UDim.new(0, 8),
            Parent = optionsFrame,
        })
        SetScrollCanvas(optionsFrame, optionsLayout, 16, "page")

        local function optionText(option)
            if type(option) == "table" then
                return option.label or tostring(option.value)
            end
            return tostring(option)
        end

        local function optionValue(option)
            if type(option) == "table" then
                return option.value
            end
            return option
        end

        local value = State:Get("dropdown", item.key, item.default or optionValue(options[1]) or "")
        local openToken = 0
        local optionButtons = {}

        local function findLabel(nextValue)
            if type(nextValue) == "table" then return "(无效)" end
            for _, option in ipairs(options) do
                if optionValue(option) == nextValue then
                    return optionText(option)
                end
            end

            return tostring(nextValue or "")
        end

        local function setOpen(open)
            openToken += 1
            local token = openToken
            local itemH = 34; local gap = 8; local count = #options
            local contentH = count * itemH + (count > 0 and (count - 1) * gap or 0) + 16
            local height = contentH
            if open then
                optionsFrame.Visible = true
                optionsFrame.BackgroundTransparency = 1
                optionsFrame.CanvasPosition = Vector2.zero
                optionsFrame.Size = UDim2.new(1, 0, 0, 0)
                Tween(optionsFrame, {
                    BackgroundTransparency = 0,
                    Size = UDim2.new(1, 0, 0, height),
                }, Theme.Animation.Normal)
                Tween(root, { Size = UDim2.new(1, 0, 0, 56 + height) }, Theme.Animation.Normal)
                arrow.Text = "^"
            else
                Tween(optionsFrame, {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                }, Theme.Animation.Fast)
                Tween(root, { Size = UDim2.new(1, 0, 0, 50) }, Theme.Animation.Fast)
                task.delay(Theme.Animation.Fast + 0.02, function()
                    if optionsFrame and optionsFrame.Parent and token == openToken and not open then
                        optionsFrame.Visible = false
                    end
                end)
                arrow.Text = "v"
            end
            RefreshContentCanvas()
        end

        local function setValue(nextValue, silent)
            if type(nextValue) == "table" then return end
            value = nextValue
            State:Set("dropdown", item.key, value)
            displayLabel.Text = findLabel(value)
            Tween(displayLabel, { TextColor3 = Theme.Colors.Text }, Theme.Animation.Fast)
            Tween(arrow, { TextColor3 = Theme.Colors.Accent }, Theme.Animation.Fast)
            Tween(displayStroke, { Color = Theme.Colors.AccentSoft }, Theme.Animation.Fast)
            for nextOptionValue, data in pairs(optionButtons) do
                local active = nextOptionValue == value
                Tween(data.Button, { BackgroundColor3 = active and Theme.Colors.AccentDim or Theme.Colors.Control }, Theme.Animation.Fast)
                Tween(data.Label, { TextColor3 = active and Theme.Colors.Text or Theme.Colors.TextMuted }, Theme.Animation.Fast)
                if data.Stroke then
                    Tween(data.Stroke, { Color = active and Theme.Colors.AccentSoft or Theme.Colors.Stroke }, Theme.Animation.Fast)
                end
            end
            setOpen(false)

            if not silent then
                State:AddLog("DROPDOWN", (item.title or item.key) .. " = " .. displayLabel.Text, item.key)
                Components.InvokeItem(item, {
                    type = "dropdown",
                    value = value,
                    label = displayLabel.Text,
                })
            end
        end

        for _, option in ipairs(options) do
            local nextOptionValue = optionValue(option)
            local optionButton = New("TextButton", {
                BackgroundColor3 = Theme.Colors.Control,
                Size = UDim2.new(1, 0, 0, 34),
                Text = "",
                Parent = optionsFrame,
            })
            AddCorner(optionButton, Theme.Radius.Control)
            local optionStroke = AddStroke(optionButton)
            Components.Interaction(
                optionButton,
                function()
                    return nextOptionValue == value and Theme.Colors.AccentDim or Theme.Colors.Control
                end,
                function()
                    return nextOptionValue == value and Theme.Colors.AccentDim or Theme.Colors.ControlHover
                end,
                Theme.Colors.AccentDim
            )

            local optionLabel = Components.Label(optionButton, optionText(option), 14, Theme.Colors.TextMuted, false)
            optionLabel.Position = UDim2.fromOffset(8, 0)
            optionLabel.Size = UDim2.new(1, -16, 1, 0)
            optionLabel.TextTruncate = Enum.TextTruncate.AtEnd
            optionButtons[nextOptionValue] = {
                Button = optionButton,
                Label = optionLabel,
                Stroke = optionStroke,
            }

            optionButton.MouseButton1Click:Connect(function()
                setValue(nextOptionValue, false)
            end)
        end

        display.MouseButton1Click:Connect(function()
            setOpen(not optionsFrame.Visible)
        end)

        function item.SetOptions(_, newOptions)
            options = newOptions or {}
            for _, child in ipairs(optionsFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end
            optionButtons = {}
            for _, option in ipairs(options) do
                local nextOptionValue = optionValue(option)
                local optionButton = New("TextButton", {
                    BackgroundColor3 = Theme.Colors.Control,
                    Size = UDim2.new(1, 0, 0, 34),
                    Text = "",
                    Parent = optionsFrame,
                })
                AddCorner(optionButton, Theme.Radius.Control)
                local optionStroke = AddStroke(optionButton)
                Components.Interaction(
                    optionButton,
                    function()
                        return nextOptionValue == value and Theme.Colors.AccentDim or Theme.Colors.Control
                    end,
                    function()
                        return nextOptionValue == value and Theme.Colors.AccentDim or Theme.Colors.ControlHover
                    end,
                    Theme.Colors.AccentDim
                )
                local optionLabel = Components.Label(optionButton, optionText(option), 14, Theme.Colors.TextMuted, false)
                optionLabel.Position = UDim2.fromOffset(8, 0)
                optionLabel.Size = UDim2.new(1, -16, 1, 0)
                optionLabel.TextTruncate = Enum.TextTruncate.AtEnd
                optionButtons[nextOptionValue] = {
                    Button = optionButton,
                    Label = optionLabel,
                    Stroke = optionStroke,
                }
                optionButton.MouseButton1Click:Connect(function()
                    setValue(nextOptionValue, false)
                end)
            end
            displayLabel.Text = findLabel(value)
            for nextOptValue, data in pairs(optionButtons) do
                local active = nextOptValue == value
                data.Button.BackgroundColor3 = active and Theme.Colors.AccentDim or Theme.Colors.Control
                data.Label.TextColor3 = active and Theme.Colors.Text or Theme.Colors.TextMuted
                if data.Stroke then
                    data.Stroke.Color = active and Theme.Colors.AccentSoft or Theme.Colors.Stroke
                end
            end
        end

        State:RegisterControl(item.key, {
            Type = "dropdown",
            SetValue = setValue,
            SetOptions = item.SetOptions,
            GetValue = function()
                return value
            end,
        })

        setValue(value, true)
        return root
    end

    function Components.Segmented(parent, item)
        Registry.Ensure(item.key, {
            Type = "segment",
            Title = item.title,
            Page = item.page,
            Internal = item.internal == true,
        })

        local options = item.options or {}
        local stacked = item.stacked == true
        local containerWidth = item.width or 284
        local root = Components.ControlFrame(parent, stacked and (item.desc and 92 or 74) or (item.desc and 72 or 54))
        local titleLabel = Components.TitleBlock(root, item, stacked and 24 or (containerWidth + 24), stacked)
        if stacked and not item.desc then
            titleLabel.Position = UDim2.fromOffset(12, 6)
            titleLabel.Size = UDim2.new(1, -48, 0, 22)
        end

        local container = New("Frame", {
            AnchorPoint = stacked and Vector2.new(0, 0) or Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = stacked and UDim2.new(0, 12, 1, -40) or UDim2.new(1, -12, 0.5, item.desc and 10 or 0),
            Size = stacked and UDim2.new(1, -24, 0, 30) or UDim2.fromOffset(containerWidth, 30),
            Parent = root,
        })
        AddCorner(container, Theme.Radius.Control)
        AddStroke(container)
        AddPadding(container, 3, 3, 3, 3)

        local layout = New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 4),
            Parent = container,
        })

        local buttons = {}

        local function optionText(option)
            return type(option) == "table" and (option.label or tostring(option.value)) or tostring(option)
        end

        local function optionValue(option)
            return type(option) == "table" and option.value or option
        end

        local value = State:Get("segment", item.key, item.default or optionValue(options[1]) or "")

        local function paint()
            for nextValue, button in pairs(buttons) do
                local active = nextValue == value
                local label = button:FindFirstChild("SegmentLabel")
                Tween(button, {
                    BackgroundColor3 = active and Theme.Colors.Accent or Theme.Colors.Control,
                }, Theme.Animation.Fast)
                if label then
                    Tween(label, { TextColor3 = active and Theme.Colors.Text or Theme.Colors.TextMuted }, Theme.Animation.Fast)
                end
            end
        end

        local function setValue(nextValue, silent, instant)
            value = nextValue
            State:Set("segment", item.key, value)
            paint()

            if not silent then
                local dispVal = value
                for _, o in ipairs(options) do
                    if optionValue(o) == value then dispVal = optionText(o); break end
                end
                State:AddLog("SEGMENT", (item.title or item.key) .. " = " .. tostring(dispVal), item.key)
                Components.InvokeItem(item, {
                    type = "segment",
                    value = value,
                })
            end
        end

        local buttonCount = math.max(#options, 1)
        local buttonWidth = math.floor((containerWidth - 6 - math.max(#options - 1, 0) * 4) / buttonCount)
        for _, option in ipairs(options) do
            local nextValue = optionValue(option)
            local button = New("TextButton", {
                BackgroundColor3 = Theme.Colors.Control,
                Size = stacked and UDim2.new(1 / buttonCount, -math.ceil((math.max(buttonCount - 1, 0) * 4) / buttonCount), 1, 0) or UDim2.new(0, buttonWidth, 1, 0),
                Text = "",
                Parent = container,
            })
            AddCorner(button, Theme.Radius.Control)
            Components.Interaction(
                button,
                function()
                    return nextValue == value and Theme.Colors.Accent or Theme.Colors.Control
                end,
                function()
                    return nextValue == value and Theme.Colors.Accent or Theme.Colors.ControlHover
                end,
                Theme.Colors.AccentDim
            )

            local buttonLabel = Components.Label(button, optionText(option), 13, Theme.Colors.TextMuted, false)
            buttonLabel.Name = "SegmentLabel"
            buttonLabel.Size = UDim2.fromScale(1, 1)
            buttonLabel.TextXAlignment = Enum.TextXAlignment.Center
            buttonLabel.TextTruncate = Enum.TextTruncate.AtEnd

            buttons[nextValue] = button

            button.MouseButton1Click:Connect(function()
                setValue(nextValue, false)
            end)
        end

        State:RegisterControl(item.key, {
            Type = "segment",
            SetValue = setValue,
            GetValue = function()
                return value
            end,
        })

        paint()
        UI.Track(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(paint), "page")
        return root
    end

    function Components.NumberInput(parent, item)
        Registry.Ensure(item.key, {
            Type = "number",
            Title = item.title,
            Page = item.page,
        })

        local minValue = item.min or -999999
        local maxValue = item.max or 999999
        if maxValue < minValue then
            minValue, maxValue = maxValue, minValue
        end
        local step = tonumber(item.step) or 1
        if step <= 0 then
            step = 1
        end
        local value = tonumber(State:Get("number", item.key, item.default or 0)) or 0

        local row = Components.ControlFrame(parent, 50)
        Components.TitleBlock(row, item, 180)

        local box = New("TextBox", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.new(1, -46, 0.5, 0),
            Size = UDim2.fromOffset(96, 28),
            Text = tostring(value),
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = row,
        })
        AddCorner(box, Theme.Radius.Control)
        AddStroke(box)

        local function format(nextValue)
            if item.format then
                return string.format(item.format, nextValue)
            end
            if math.floor(nextValue) == nextValue then
                return tostring(nextValue)
            end
            return string.format("%.2f", nextValue)
        end

        local function setValue(nextValue, silent)
            local raw = math.clamp(tonumber(nextValue) or value, minValue, maxValue)
            local stepped = math.floor(((raw - minValue) / step) + 0.5) * step + minValue
            value = math.clamp(stepped, minValue, maxValue)
            State:Set("number", item.key, value)
            box.Text = format(value)
            Tween(box, { TextColor3 = Theme.Colors.Text }, Theme.Animation.Fast)
            if not silent then
                State:AddLog("NUMBER", (item.title or item.key) .. " = " .. box.Text, item.key)
                Components.InvokeItem(item, { type = "number", value = value })
            end
        end

        local minus = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Colors.Control,
            Position = UDim2.new(1, -148, 0.5, 0),
            Size = UDim2.fromOffset(28, 28),
            Text = "-",
            TextSize = 18,
            Parent = row,
        })
        AddCorner(minus, Theme.Radius.Control)
        AddStroke(minus)
        Components.Interaction(minus, Theme.Colors.Control, Theme.Colors.ControlHover, Theme.Colors.AccentDim)

        local plus = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Colors.Control,
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(28, 28),
            Text = "+",
            TextSize = 18,
            Parent = row,
        })
        AddCorner(plus, Theme.Radius.Control)
        AddStroke(plus)
        Components.Interaction(plus, Theme.Colors.Control, Theme.Colors.ControlHover, Theme.Colors.AccentDim)

        minus.MouseButton1Click:Connect(function()
            setValue(value - step, false)
        end)
        plus.MouseButton1Click:Connect(function()
            setValue(value + step, false)
        end)
        box.FocusLost:Connect(function()
            setValue(box.Text, false)
        end)

        State:RegisterControl(item.key, {
            Type = "number",
            SetValue = setValue,
            GetValue = function()
                return value
            end,
        })

        setValue(value, true)
        return row
    end

    -- 共享色轮弹窗：title=标题, startColor=初始色, onPick=确认回调(color)
    local _cwPanel = nil
    function Components.OpenColorWheel(title, startColor, onPick)
        local h0, s0, v0 = startColor:ToHSV()
        local hue, sat, val = h0, s0, v0
        local dragWheel, dragBright = false, false
        local uis = game:GetService("UserInputService")
        local bg = nil

        local pParent = UI and UI.RootGui
        if not pParent then
            pcall(function() if gethui then pParent = gethui() end end)
        end
        if not pParent then pParent = game:GetService("CoreGui") end

        if _cwPanel then pcall(_cwPanel.Destroy, _cwPanel) end
        _cwPanel = New("TextButton", {
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.45,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            Parent = pParent,
            ZIndex = 100,
        })
        _cwPanel.MouseButton1Click:Connect(function()
            pcall(_cwPanel.Destroy, _cwPanel); _cwPanel = nil
        end)

        local card = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(236, 322), BackgroundColor3 = Theme.Colors.Window,
            BorderSizePixel = 0, ZIndex = 101, Parent = _cwPanel,
        })
        AddCorner(card, Theme.Radius.Window)
        AddStroke(card, Theme.Colors.StrokeStrong)

        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
            Text = title or "选择颜色", TextColor3 = Theme.Colors.Text,
            TextSize = 15, Font = Enum.Font.GothamSemibold, ZIndex = 102, Parent = card,
        })

        local wheel = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 32),
            Size = UDim2.fromOffset(188, 188), Text = "", ZIndex = 102, Parent = card,
        })
        AddCorner(wheel, 94)
        local wGrad = New("UIGradient", {
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 80)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(80, 255, 80)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 255)),
                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(80, 120, 255)),
                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 80, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 60)),
            },
            Rotation = 0, Parent = wheel,
        })
        pcall(function() wGrad.Rotate = Enum.RotationDirection.Clockwise; wGrad.Period = 10 end)
        local pick = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 2,
            BorderColor3 = Color3.new(0, 0, 0), ZIndex = 103, Parent = wheel,
        })
        AddCorner(pick, 7)
        local pickInner = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = startColor, ZIndex = 104, Parent = pick,
        })
        AddCorner(pickInner, 7)

        local function applyPickRel(rx, ry)
            local cx = wheel.AbsoluteSize.X / 2
            local cy = wheel.AbsoluteSize.Y / 2
            local dx, dy = rx - cx, ry - cy
            local r = wheel.AbsoluteSize.X / 2
            local dist = (dx * dx + dy * dy) ^ 0.5
            if dist > r and dist > 0.001 then
                dx = dx / dist * r
                dy = dy / dist * r
                rx = cx + dx
                ry = cy + dy
                dist = r
            end
            hue = (math.atan2(dy, dx) + math.pi) / (2 * math.pi)
            sat = dist / r
            pick.Position = UDim2.fromOffset(rx, ry)
            pickInner.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
            bg.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, 1)),
                ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
            }
        end
        local function syncPick()
            local ang = hue * 2 * math.pi - math.pi
            local rad = sat * (wheel.AbsoluteSize.X / 2)
            pick.Position = UDim2.fromOffset(wheel.AbsoluteSize.X / 2 + math.cos(ang) * rad, wheel.AbsoluteSize.Y / 2 + math.sin(ang) * rad)
            pickInner.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
        end

        local btrack = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 230),
            Size = UDim2.fromOffset(180, 16), BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0, ZIndex = 102, Text = "", Parent = card,
        })
        AddCorner(btrack, 8)
        bg = New("UIGradient", {
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromHSV(h0, s0, 1)),
                ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
            },
            Parent = btrack,
        })
        local bdot = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 2,
            BorderColor3 = Color3.new(0, 0, 0), ZIndex = 103, Parent = btrack,
        })
        AddCorner(bdot, 9)
        local function applyBrightRel(rx)
            local ww = btrack.AbsoluteSize.X
            val = math.clamp(1 - rx / ww, 0, 1)
            bdot.Position = UDim2.new(math.clamp(rx / ww, 0, 1), 0, 0.5, 0)
            bg.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, 1)),
                ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
            }
            pickInner.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
        end

        local function isPress(t) return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch end
        local dragWheelInput, dragBrightInput = nil, nil

        wheel.InputBegan:Connect(function(input)
            if isPress(input.UserInputType) then
                dragWheel = true
                dragWheelInput = input
                applyPickRel(input.Position.X - wheel.AbsolutePosition.X, input.Position.Y - wheel.AbsolutePosition.Y)
            end
        end)
        btrack.InputBegan:Connect(function(input)
            if isPress(input.UserInputType) then
                dragBright = true
                dragBrightInput = input
                applyBrightRel(input.Position.X - btrack.AbsolutePosition.X)
            end
        end)
        uis.InputChanged:Connect(function(input)
            if dragWheel and input == dragWheelInput then
                applyPickRel(input.Position.X - wheel.AbsolutePosition.X, input.Position.Y - wheel.AbsolutePosition.Y)
            elseif dragBright and input == dragBrightInput then
                applyBrightRel(input.Position.X - btrack.AbsolutePosition.X)
            end
        end)
        uis.InputEnded:Connect(function(input)
            if input == dragWheelInput then dragWheel = false; dragWheelInput = nil end
            if input == dragBrightInput then dragBright = false; dragBrightInput = nil end
        end)

        local cancelBtn = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.28, 0, 0, 260),
            Size = UDim2.fromOffset(90, 32), Text = "取消", TextColor3 = Theme.Colors.Text,
            TextSize = 14, Font = Enum.Font.GothamSemibold,
            BackgroundColor3 = Theme.Colors.Control, BorderSizePixel = 0, ZIndex = 102, Parent = card,
        })
        AddCorner(cancelBtn, Theme.Radius.Control)
        cancelBtn.MouseButton1Click:Connect(function()
            pcall(_cwPanel.Destroy, _cwPanel); _cwPanel = nil
        end)
        local okBtn = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.72, 0, 0, 260),
            Size = UDim2.fromOffset(90, 32), Text = "确认", TextColor3 = Color3.new(1, 1, 1),
            TextSize = 14, Font = Enum.Font.GothamSemibold,
            BackgroundColor3 = Theme.Colors.Accent, BorderSizePixel = 0, ZIndex = 102, Parent = card,
        })
        AddCorner(okBtn, Theme.Radius.Control)
        okBtn.MouseButton1Click:Connect(function()
            if onPick then pcall(onPick, Color3.fromHSV(hue, sat, val)) end
            pcall(_cwPanel.Destroy, _cwPanel); _cwPanel = nil
        end)

        syncPick()
        applyBrightRel((1 - val) * btrack.AbsoluteSize.X)
    end

    function Components.ColorPicker(parent, item)
        Registry.Ensure(item.key, {
            Type = "color",
            Title = item.title,
            Page = item.page,
        })

        local presets = item.presets or {
            { label = "Trace 蓝", value = Color3.fromRGB(60, 140, 255) },
            { label = "冷白", value = Color3.fromRGB(230, 236, 245) },
            { label = "雾灰", value = Color3.fromRGB(120, 130, 145) },
            { label = "柔绿", value = Color3.fromRGB(82, 180, 126) },
            { label = "琥珀", value = Color3.fromRGB(226, 176, 74) },
        }
        local value = State:Get("color", item.key, item.default or Color3.new(1, 1, 1))

        local root = Components.ControlFrame(parent, 64)
        Components.TitleBlock(root, item, 236)

        -- 彩虹 swatch 按钮：点击弹出色轮
        local swatch = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -176, 0.5, 0),
            Size = UDim2.fromOffset(36, 36),
            Text = "",
            Parent = root,
        })
        AddCorner(swatch, 9)
        local swGrad = New("UIGradient", {
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 80)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(80, 255, 80)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 255)),
                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(80, 120, 255)),
                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 80, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 60)),
            },
            Rotation = 45,
            Parent = swatch,
        })
        pcall(function() swGrad.Rotate = Enum.RotationDirection.Clockwise; swGrad.Period = 8 end)
        local inner = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.58, 0.58),
            BackgroundColor3 = value,
            Parent = swatch,
        })
        AddCorner(inner, 6)
        AddStroke(inner, Theme.Colors.StrokeStrong)
        Components.Tooltip(swatch, "点开色轮自定义颜色")

        -- 快捷预设小圆点
        local holder = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(156, 30),
            Parent = root,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 5),
            Parent = holder,
        })

        local function setValue(nextValue, label, silent)
            if label == true and silent == nil then
                label = nil
                silent = true
            end
            if typeof(nextValue) ~= "Color3" then return false end
            local changed = value ~= nextValue
            value = nextValue
            State:Set("color", item.key, value)
            Tween(inner, { BackgroundColor3 = value }, Theme.Animation.Fast)
            if not silent and changed then
                State:AddLog("COLOR", (item.title or item.key) .. " = " .. (label or ColorToHex(value)), item.key)
                Components.InvokeItem(item, { type = "color", value = value, label = label, hex = ColorToHex(value) })
            end
            return changed
        end

        for _, preset in ipairs(presets) do
            local button = New("TextButton", {
                BackgroundColor3 = preset.value,
                Size = UDim2.fromOffset(22, 22),
                Text = "",
                Parent = holder,
            })
            AddCorner(button, Theme.Radius.Pill)
            AddStroke(button, Theme.Colors.StrokeStrong)
            Components.Tooltip(button, preset.label .. " " .. ColorToHex(preset.value))
            button.MouseButton1Click:Connect(function()
                setValue(preset.value, preset.label, false)
            end)
        end

        swatch.MouseButton1Click:Connect(function()
            Components.OpenColorWheel(item.title, value, function(c)
                setValue(c, ColorToHex(c), false)
            end)
        end)

        State:RegisterControl(item.key, {
            Type = "color",
            SetValue = setValue,
            GetValue = function()
                return value
            end,
        })

        return root
    end

    function Components.MultiDropdown(parent, item)
        Registry.Ensure(item.key, {
            Type = "multi-dropdown",
            Title = item.title,
            Page = item.page,
        })

        local root = Components.ControlFrame(parent, 56)
        Components.TitleBlock(root, item, 230)

        local selected = State:Get("multi-dropdown", item.key, ShallowCopy(item.default or {}))
        local options = item.options or {}
        if type(item.optionsCallback) == "function" then
            local okOpt, dynOpt = pcall(item.optionsCallback)
            if okOpt and type(dynOpt) == "table" then options = dynOpt end
        end

        local display = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.new(1, -12, 0, 30),
            Size = UDim2.fromOffset(220, 30),
            Text = "",
            Parent = root,
        })
        AddCorner(display, Theme.Radius.Control)
        local displayStroke = AddStroke(display)
        Components.Interaction(display, Theme.Colors.PanelDeep, Theme.Colors.Control, Theme.Colors.ControlHover)

        local label = Components.Label(display, "", 13, Theme.Colors.TextMuted, false)
        label.Position = UDim2.fromOffset(8, 0)
        label.Size = UDim2.new(1, -26, 1, 0)
        label.TextTruncate = Enum.TextTruncate.AtEnd

        local arrow = Components.Label(display, "v", 13, Theme.Colors.TextDim, true)
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, -8, 0.5, 0)
        arrow.Size = UDim2.fromOffset(14, 16)
        arrow.TextXAlignment = Enum.TextXAlignment.Center

        local popup = New("ScrollingFrame", {
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.new(0.5, 0, 0, 52.5),
            Size = UDim2.new(1, -24, 0, 0),
            Visible = false,
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarThickness = 3,
            Parent = root,
            ZIndex = 35,
        })
        AddCorner(popup, Theme.Radius.Panel)
        AddStroke(popup, Theme.Colors.Stroke)
        AddPadding(popup, 7, 7, 7, 7)
        local popupLayout = New("UIListLayout", {
            Padding = UDim.new(0, 5),
            Parent = popup,
        })
        SetScrollCanvas(popup, popupLayout, 14, "page")

        local function selectedText()
            local names = {}
            for _, option in ipairs(options) do
                local optionValue = ResolveOptionValue(option)
                if selected[optionValue] then
                    local label = item.optionLabelCallback and item.optionLabelCallback(optionValue, ResolveOptionLabel(option)) or ResolveOptionLabel(option)
                    table.insert(names, label)
                end
            end
            return #names == 0 and "未选择" or table.concat(names, item.separator or ", ")
        end

        local function syncLabel()
            label.Text = selectedText()
            local hasSelected = false
            for _, enabled in pairs(selected) do
                if enabled then
                    hasSelected = true
                    break
                end
            end
            Tween(label, { TextColor3 = hasSelected and Theme.Colors.Text or Theme.Colors.TextMuted }, Theme.Animation.Fast)
            Tween(arrow, { TextColor3 = hasSelected and Theme.Colors.Accent or Theme.Colors.TextDim }, Theme.Animation.Fast)
            Tween(displayStroke, { Color = hasSelected and Theme.Colors.AccentSoft or Theme.Colors.Stroke }, Theme.Animation.Fast)
        end

        local function fire(silent)
            State:Set("multi-dropdown", item.key, selected)
            if silent then return end
            State:AddLog("MULTI", (item.title or item.key) .. " = " .. selectedText(), item.key)
            Components.InvokeItem(item, { type = "multi-dropdown", value = selected, label = selectedText() })
        end

        local function sameSelection(nextValue)
            nextValue = nextValue or {}
            for key, enabled in pairs(selected) do
                if enabled ~= (nextValue[key] == true) then return false end
            end
            for key, enabled in pairs(nextValue) do
                if enabled ~= (selected[key] == true) then return false end
            end
            return true
        end

        local openToken = 0
        local optionRows = {}

        local function paintOptions()
            for optionValue, data in pairs(optionRows) do
                local disabled = item.isOptionDisabled and item.isOptionDisabled(optionValue)
                local active = selected[optionValue] == true and not disabled
                data.Check.Text = active and "✓" or ""
                local opt = data.option
                if opt and disabled and item.optionLabelCallback then
                    data.Text.Text = item.optionLabelCallback(optionValue, ResolveOptionLabel(opt))
                elseif opt and not disabled and item.optionLabelCallback then
                    data.Text.Text = ResolveOptionLabel(opt)
                end
                Tween(data.Button, { BackgroundColor3 = disabled and Theme.Colors.ControlDim or (active and Theme.Colors.AccentDim or Theme.Colors.Control) }, Theme.Animation.Fast)
                Tween(data.Text, { TextColor3 = disabled and Theme.Colors.TextDim or (active and Theme.Colors.Text or Theme.Colors.TextMuted) }, Theme.Animation.Fast)
                if data.Stroke then
                    Tween(data.Stroke, { Color = disabled and Theme.Colors.Stroke or (active and Theme.Colors.AccentSoft or Theme.Colors.Stroke) }, Theme.Animation.Fast)
                end
            end
        end

        local function rebuildOptions()
            for _, row in pairs(optionRows) do
                if row.Button then pcall(row.Button.Destroy, row.Button) end
            end
            optionRows = {}
            if type(item.optionsCallback) == "function" then
                local okOpt, dynOpt = pcall(item.optionsCallback)
                if okOpt and type(dynOpt) == "table" then options = dynOpt end
            end
            for _, option in ipairs(options) do
                local optionValue = ResolveOptionValue(option)
                local defaultLabel = ResolveOptionLabel(option)
                local optionLabel = item.optionLabelCallback and item.optionLabelCallback(optionValue, defaultLabel) or defaultLabel
                local optionButton = New("TextButton", {
                    BackgroundColor3 = Theme.Colors.Control,
                    Size = UDim2.new(1, 0, 0, 26),
                    Text = "",
                    Parent = popup,
                    ZIndex = 36,
                })
                AddCorner(optionButton, Theme.Radius.Control)
                local optionStroke = AddStroke(optionButton)
                Components.Interaction(
                    optionButton,
                    function()
                        return selected[optionValue] and Theme.Colors.AccentDim or Theme.Colors.Control
                    end,
                    function()
                        return selected[optionValue] and Theme.Colors.AccentDim or Theme.Colors.ControlHover
                    end,
                    Theme.Colors.AccentDim
                )

                local check = Components.Label(optionButton, selected[optionValue] and "✓" or "", 14, Theme.Colors.Accent, true)
                check.Position = UDim2.fromOffset(8, 0)
                check.Size = UDim2.fromOffset(20, 26)
                check.TextXAlignment = Enum.TextXAlignment.Center
                check.ZIndex = 37

                local text = Components.Label(optionButton, optionLabel, 13, Theme.Colors.TextMuted, false)
                text.Position = UDim2.fromOffset(34, 0)
                text.Size = UDim2.new(1, -42, 1, 0)
                text.TextTruncate = Enum.TextTruncate.AtEnd
                text.ZIndex = 37
                optionRows[optionValue] = {
                    Button = optionButton,
                    Check = check,
                    Text = text,
                    Stroke = optionStroke,
                    option = option,
                }

                optionButton.MouseButton1Click:Connect(function()
                    if item.isOptionDisabled and item.isOptionDisabled(optionValue) then return end
                    selected[optionValue] = not selected[optionValue] or nil
                    syncLabel()
                    paintOptions()
                    fire()
                end)
            end
            paintOptions()
        end
        rebuildOptions()

        local popupHeight = 170

        local function setOpen(open)
            openToken += 1
            local token = openToken
            arrow.Text = open and "^" or "v"
            if open then
                popup.Visible = true
                popup.BackgroundTransparency = 1
                popup.Size = UDim2.new(1, -24, 0, 1)
                local optionCount = #options
                local itemH = 26
                local gap = 5
                local padding = 14
                local h = optionCount * itemH + math.max(optionCount - 1, 0) * gap + padding
                task.defer(function()
                    if token ~= openToken then return end
                    Tween(popup, {
                        BackgroundTransparency = 0,
                        Size = UDim2.new(1, -24, 0, h),
                    }, Theme.Animation.Normal)
                    Tween(root, { Size = UDim2.new(1, 0, 0, 60 + h) }, Theme.Animation.Normal)
                end)
            else
                Tween(popup, {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -24, 0, 1),
                }, Theme.Animation.Normal)
                Tween(root, { Size = UDim2.new(1, 0, 0, 56) }, Theme.Animation.Normal)
                task.delay(Theme.Animation.Normal + 0.03, function()
                    if popup and popup.Parent and token == openToken then
                        popup.Visible = false
                    end
                end)
            end
            RefreshContentCanvas()
        end

        display.MouseButton1Click:Connect(function()
            if not popup.Visible then rebuildOptions() end
            setOpen(not popup.Visible)
        end)

        State:RegisterControl(item.key, {
            Type = "multi-dropdown",
            SetValue = function(nextValue, silent)
                if sameSelection(nextValue) then return false end
                selected = ShallowCopy(nextValue or {})
                syncLabel()
                paintOptions()
                fire(silent)
                return true
            end,
            GetValue = function()
                return selected
            end,
        })

        syncLabel()
        paintOptions()
        return root
    end

    function Components.Keybind(parent, item)
        Registry.Ensure(item.key, {
            Type = "keybind",
            Title = item.title,
            Page = item.page,
        })

        local value = State.Keybinds[item.key] or item.default or "未绑定"
        local row = Components.ControlFrame(parent, 48)
        Components.TitleBlock(row, item, 140)

        local button = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(116, 28),
            Text = tostring(value),
            TextColor3 = Theme.Colors.TextMuted,
            TextSize = 13,
            Parent = row,
        })
        AddCorner(button, Theme.Radius.Control)
        AddStroke(button)
        Components.Interaction(button, Theme.Colors.PanelDeep, Theme.Colors.Control, Theme.Colors.ControlHover)

        local waiting = false
        local normalStroke = button:FindFirstChildOfClass("UIStroke")
        button.MouseButton1Click:Connect(function()
            waiting = true
            button.Text = "按下按键..."
            Tween(button, { BackgroundColor3 = Theme.Colors.AccentDim, TextColor3 = Theme.Colors.Text }, Theme.Animation.Fast)
            if normalStroke then
                Tween(normalStroke, { Color = Theme.Colors.AccentSoft }, Theme.Animation.Fast)
            end
            State:AddLog("UI", "等待键位绑定: " .. (item.title or item.key), item.key)
        end)

        UI.Track(Services.UserInputService.InputBegan:Connect(function(input, processed)
            if not waiting or processed then
                return
            end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end
            waiting = false
            value = input.KeyCode.Name
            State.Keybinds[item.key] = value
            button.Text = value
            Tween(button, { BackgroundColor3 = Theme.Colors.PanelDeep, TextColor3 = Theme.Colors.TextMuted }, Theme.Animation.Fast)
            if normalStroke then
                Tween(normalStroke, { Color = Theme.Colors.Stroke }, Theme.Animation.Fast)
            end
            State:AddLog("KEY", (item.title or item.key) .. " = " .. value, item.key)
            Components.InvokeItem(item, { type = "keybind", value = value })
        end), "page")

        return row
    end

    function Components.Progress(parent, item)
        if not item.internal then
            Registry.Ensure(item.key, {
                Type = "progress",
                Title = item.title,
                Page = item.page,
                Internal = item.internal == true,
            })
        end

        local value = math.clamp(item.value or item.default or 0, 0, 1)
        local row = Components.ControlFrame(parent, 58)
        Components.TitleBlock(row, item, 120)

        local valueLabel = Components.Label(row, string.format("%d%%", value * 100), 13, Theme.Colors.TextMuted, true)
        valueLabel.AnchorPoint = Vector2.new(1, 0)
        valueLabel.Position = UDim2.new(1, -12, 0, 9)
        valueLabel.Size = UDim2.fromOffset(70, 18)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right

        local bar = New("Frame", {
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.new(0, 12, 1, -20),
            Size = UDim2.new(1, -24, 0, 8),
            Parent = row,
        })
        AddCorner(bar, Theme.Radius.Pill)

        local fill = New("Frame", {
            BackgroundColor3 = item.color or Theme.Colors.Accent,
            Size = UDim2.new(value, 0, 1, 0),
            Parent = bar,
        })
        AddCorner(fill, Theme.Radius.Pill)

        return row
    end

    function Components.TagRow(parent, item)
        if not item.internal then
            Registry.Ensure(item.key, {
                Type = "tags",
                Title = item.title,
                Page = item.page,
                Internal = true,
            })
        end

        local row = Components.ControlFrame(parent, 58)
        Components.TitleBlock(row, item, 300)

        local holder = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(280, 28),
            Parent = row,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, 6),
            Parent = holder,
        })

        for _, tag in ipairs(item.tags or {}) do
            local tagLabel = Components.Label(holder, type(tag) == "table" and tag.label or tostring(tag), 12, Theme.Colors.TextMuted, true)
            tagLabel.BackgroundColor3 = type(tag) == "table" and (tag.color or Theme.Colors.Control) or Theme.Colors.Control
            tagLabel.BackgroundTransparency = 0
            tagLabel.Size = UDim2.fromOffset(type(tag) == "table" and (tag.width or 62) or 62, 24)
            tagLabel.TextXAlignment = Enum.TextXAlignment.Center
            AddCorner(tagLabel, Theme.Radius.Pill)
            AddStroke(tagLabel)
        end

        return row
    end

    function Components.Table(parent, item)
        if not item.internal then
            Registry.Ensure(item.key, {
                Type = "table",
                Title = item.title,
                Page = item.page,
                Internal = true,
            })
        end

        local rows = item.rows or {}
        if type(rows) == "function" then
            local ok, result = pcall(rows)
            rows = ok and result or {}
        end

        local columns = item.columns or {
            { key = "name", label = "名称", width = 0.45 },
            { key = "value", label = "值", width = 0.55 },
        }

        local root = New("Frame", {
            BackgroundColor3 = Theme.Colors.Card,
            Size = UDim2.new(1, 0, 0, math.max(90, 34 + (#rows * 30))),
            Parent = parent,
        })
        AddCorner(root, Theme.Radius.Panel)
        AddStroke(root)
        AddPadding(root, 10, 10, 10, 10)

        local header = New("Frame", {
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Size = UDim2.new(1, 0, 0, 34),
            Parent = root,
        })
        AddCorner(header, Theme.Radius.Control)

        local xOffset = 0
        for _, column in ipairs(columns) do
            local label = Components.Label(header, column.label, 12, Theme.Colors.TextDim, true)
            label.Position = UDim2.new(xOffset, 8, 0, 0)
            label.Size = UDim2.new(column.width, -10, 1, 0)
            xOffset += column.width
        end

        local y = 34
        for _, row in ipairs(rows) do
            local line = New("Frame", {
                BackgroundColor3 = Theme.Colors.Control,
                BackgroundTransparency = 0.25,
                Position = UDim2.fromOffset(0, y),
                Size = UDim2.new(1, 0, 0, 26),
                Parent = root,
            })
            AddCorner(line, Theme.Radius.Control)

            xOffset = 0
            for _, column in ipairs(columns) do
                local value = row[column.key]
                local cell = Components.Label(line, tostring(value or ""), 12, Theme.Colors.TextMuted, false)
                cell.Position = UDim2.new(xOffset, 8, 0, 0)
                cell.Size = UDim2.new(column.width, -10, 1, 0)
                cell.TextTruncate = Enum.TextTruncate.AtEnd
                xOffset += column.width
            end
            y += 30
        end

        return root
    end

    function Components.StatusLabel(parent, item)
        if not item.internal then
            Registry.Ensure(item.key, {
                Type = "status",
                Title = item.title,
                Page = item.page,
                Internal = true,
            })
        end

        local row = Components.ControlFrame(parent, 44)
        Components.TitleBlock(row, item, 130)

        local resolvedValue = item.value
        if type(resolvedValue) == "function" then
            local ok, result = pcall(resolvedValue)
            resolvedValue = ok and result or "读取失败"
        end

        local badge = Components.Label(row, resolvedValue or "待定", 13, Theme.Colors.Text, true)
        badge.AnchorPoint = Vector2.new(1, 0.5)
        badge.BackgroundColor3 = Theme.Colors.AccentDim
        badge.BackgroundTransparency = 0
        badge.Position = UDim2.new(1, -12, 0.5, 0)
        badge.Size = UDim2.fromOffset(100, 24)
        badge.TextXAlignment = Enum.TextXAlignment.Center
        AddCorner(badge, Theme.Radius.Control)
        AddStroke(badge, Theme.Colors.AccentSoft)

        State:RegisterControl(item.key, {
            Type = "status",
            SetValue = function(_, value)
                if type(value) ~= "string" then return end
                badge.Text = value
            end,
            GetValue = function()
                return badge.Text
            end,
        })

        return row
    end

    function Components.ListItem(parent, item)
        if not item.internal then
            Registry.Ensure(item.key, {
                Type = "list-item",
                Title = item.title,
                Page = item.page,
                Internal = item.internal == true,
            })
        end

        local row = Components.ControlFrame(parent, item.desc and 52 or 36)
        Components.TitleBlock(row, item, item.badge and 110 or 24)

        if item.badge then
            local badge = Components.Label(row, item.badge, 12, Theme.Colors.TextMuted, true)
            badge.AnchorPoint = Vector2.new(1, 0.5)
            badge.BackgroundColor3 = Theme.Colors.Control
            badge.BackgroundTransparency = 0
            badge.Position = UDim2.new(1, -12, 0.5, 0)
            badge.Size = UDim2.fromOffset(86, 22)
            badge.TextXAlignment = Enum.TextXAlignment.Center
            AddCorner(badge, Theme.Radius.Control)
        end

        return row
    end

    function Components.CategoryCard(parent, item)
        Registry.Ensure(item.key, {
            Type = "category-card",
            Title = item.title,
            Page = item.page,
            TargetPage = item.targetPage,
            Internal = true,
        })

        local button = New("TextButton", {
            BackgroundColor3 = Theme.Colors.Card,
            Size = UDim2.new(1, 0, 0, 58),
            Text = "",
            Parent = parent,
        })
        AddCorner(button, Theme.Radius.Panel)
        AddStroke(button)
        Components.Interaction(button, Theme.Colors.Card, Theme.Colors.CardHover, Theme.Colors.ControlHover)
        local cardScale = New("UIScale", { Scale = 1, Parent = button })
        button.MouseEnter:Connect(function()
            Tween(cardScale, { Scale = 1.02 }, Theme.Animation.Normal)
        end)
        button.MouseLeave:Connect(function()
            Tween(cardScale, { Scale = 1 }, Theme.Animation.Normal)
        end)

        local icon = Components.Label(button, item.icon or ">", 18, Theme.Colors.Accent, true)
        icon.BackgroundColor3 = Theme.Colors.AccentDim
        icon.BackgroundTransparency = 0
        icon.Position = UDim2.fromOffset(12, 11)
        icon.Size = UDim2.fromOffset(36, 36)
        icon.TextXAlignment = Enum.TextXAlignment.Center
        AddCorner(icon, Theme.Radius.Control)
        AddStroke(icon, Theme.Colors.AccentSoft)

        local title = Components.Label(button, item.title, 16, Theme.Colors.Text, true)
        title.Position = UDim2.fromOffset(58, 8)
        title.Size = UDim2.new(1, -112, 0, 20)

        local desc = Components.Label(button, item.desc, 13, Theme.Colors.TextDim, false)
        desc.Position = UDim2.fromOffset(58, 30)
        desc.Size = UDim2.new(1, -112, 0, 18)
        desc.TextTruncate = Enum.TextTruncate.AtEnd

        local arrow = Components.Label(button, ">", 18, Theme.Colors.TextDim, true)
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, -14, 0.5, 0)
        arrow.Size = UDim2.fromOffset(20, 24)
        arrow.TextXAlignment = Enum.TextXAlignment.Center

        button.MouseButton1Click:Connect(function()
            if item.targetPage then
                UI.SetPage(item.targetPage)
            end
            State:AddLog("UI", "进入 " .. (item.title or item.targetPage or ""), item.key)
        end)

        return button
    end

    function Components.Collapsible(parent, item)
        Registry.Ensure(item.key, {
            Type = "collapsible-group",
            Title = item.title,
            Page = item.page,
            Internal = true,
        })

        local root = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = parent,
        })

        local layout = New("UIListLayout", {
            Padding = UDim.new(0, 8),
            Parent = root,
        })

        local header = New("TextButton", {
            BackgroundColor3 = Theme.Colors.Control,
            Size = UDim2.new(1, 0, 0, 38),
            Text = "",
            Parent = root,
        })
        AddCorner(header, Theme.Radius.Panel)
        AddStroke(header)
        Components.Interaction(header, Theme.Colors.Control, Theme.Colors.ControlHover, Theme.Colors.AccentDim)

        local arrow = Components.Label(header, "v", 14, Theme.Colors.TextDim, true)
        arrow.Position = UDim2.fromOffset(12, 0)
        arrow.Size = UDim2.fromOffset(18, 38)
        arrow.TextXAlignment = Enum.TextXAlignment.Center

        local title = Components.Label(header, item.title or "分组", 16, Theme.Colors.Text, true)
        title.Position = UDim2.fromOffset(36, 0)
        title.Size = UDim2.new(1, -48, 1, 0)

        local content = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            ClipsDescendants = true,
            Parent = root,
        })

        local contentLayout = New("UIListLayout", {
            Padding = UDim.new(0, 8),
            Parent = sf,
        })

        local collapsed = State.Collapsed[item.key] == true

        local function getContentHeight()
            return contentLayout.AbsoluteContentSize.Y + 8
        end

        local animToken = 0
        local function animate(expand)
            animToken += 1
            local token = animToken
            if expand then
                content.Visible = true
                content.Size = UDim2.new(1, 0, 0, 0)
                task.defer(function()
                    if token ~= animToken then return end
                    local h = getContentHeight()
                    Tween(content, { Size = UDim2.new(1, 0, 0, h) }, Theme.Animation.Normal)
                end)
            else
                local cur = content.AbsoluteSize.Y
                if cur > 0 then
                    Tween(content, { Size = UDim2.new(1, 0, 0, 1) }, Theme.Animation.Fast)
                    task.delay(Theme.Animation.Fast + 0.03, function()
                        if token == animToken then
                            content.Visible = false
                        end
                    end)
                else
                    content.Visible = false
                end
            end
        end

        header.MouseButton1Click:Connect(function()
            collapsed = not collapsed
            State.Collapsed[item.key] = collapsed
            arrow.Text = collapsed and ">" or "v"
            animate(not collapsed)
            State:AddLog("UI", (collapsed and "折叠 " or "展开 ") .. (item.title or item.key), item.key)
        end)

        if collapsed then
            content.Visible = false
            content.Size = UDim2.new(1, 0, 0, 0)
        else
            task.defer(function()
                local h = getContentHeight()
                content.Size = UDim2.new(1, 0, 0, h)
            end)
        end
        return root, content
    end

    function Components.LogOutput(parent, item)
        Registry.Ensure(item.key, {
            Type = "log-output",
            Title = item.title,
            Page = item.page,
            Internal = true,
        })

        local root = New("Frame", {
            BackgroundColor3 = Theme.Colors.Card,
            Size = UDim2.new(1, 0, 0, 300),
            Parent = parent,
        })
        AddCorner(root, Theme.Radius.Panel)
        AddStroke(root)
        AddPadding(root, 10, 10, 10, 10)

        local header = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 32),
            Parent = root,
        })

        local title = Components.Label(header, item.title or "日志输出", 17, Theme.Colors.Text, true)
        title.Size = UDim2.new(1, -100, 1, 0)

        local clear = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Colors.Control,
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(84, 26),
            Text = "清空",
            TextSize = 14,
            TextColor3 = Theme.Colors.TextMuted,
            Parent = header,
        })
        AddCorner(clear, Theme.Radius.Control)
        AddStroke(clear)
        Components.Interaction(clear, Theme.Colors.Control, Theme.Colors.ControlHover, Theme.Colors.AccentDim)

        Registry.Ensure(item.clearKey or "logs.clear", {
            Type = "button",
            Title = "清空日志",
            Page = item.page,
            Internal = true,
        })

        clear.MouseButton1Click:Connect(function()
            State:ClearLogs()
            State:AddLog("UI", "日志已清空", item.clearKey or "logs.clear")
        end)

        local scroller = New("ScrollingFrame", {
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.fromOffset(0, 38),
            Size = UDim2.new(1, 0, 1, -38),
            CanvasSize = UDim2.fromOffset(0, 0),
            Parent = root,
        })
        AddCorner(scroller, Theme.Radius.Control)
        AddStroke(scroller)
        AddPadding(scroller, 8, 8, 8, 8)

        local layout = New("UIListLayout", {
            Padding = UDim.new(0, 5),
            Parent = scroller,
        })
        SetScrollCanvas(scroller, layout, 16, "log")

        UI.LogList = scroller
        UI.RefreshLogs()
        return root
    end


    function Components.Marquee(parent, text)
        local root = New("Frame", {
            BackgroundColor3 = Theme.Colors.PanelDeep,
            ClipsDescendants = true,
            Size = UDim2.fromOffset(250, 30),
            Parent = parent,
        })
        AddCorner(root, Theme.Radius.Control)
        local ms = AddStroke(root)
        ms.Transparency = 1

        local label = Components.Label(root, text or "", 14, Theme.Colors.TextMuted, false)
        label.Name = "MarqueeText"
        label.AnchorPoint = Vector2.new(0, 0.5)
        label.Position = UDim2.new(0, 0, 0.5, 0)
        label.Size = UDim2.new(0, 0, 0, root.Size.Y.Offset)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.TextTruncate = Enum.TextTruncate.None

        local function start()
            UI.MarqueeToken += 1
            local token = UI.MarqueeToken
            local function cycle()
                if not (root and root.Parent) or token ~= UI.MarqueeToken then return end
                local rootWidth = math.max(root.AbsoluteSize.X, 1)
                local textWidth = Services.TextService:GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(math.huge, root.AbsoluteSize.Y)).X
                label.Size = UDim2.fromOffset(textWidth, root.AbsoluteSize.Y)
                label.Position = UDim2.new(0, rootWidth + 100, 0.5, 0)
                local distance = rootWidth + textWidth + 100
                local duration = math.max(distance / 72, 1.2) / 1.2
                local tween = Tween(label, {
                    Position = UDim2.new(0, -textWidth, 0.5, 0),
                }, duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
                if tween then
                    tween.Completed:Connect(function()
                        cycle()
                    end)
                else
                    task.delay(duration, function()
                        cycle()
                    end)
                end
            end
            task.defer(function()
                task.wait()
                cycle()
            end)
        end

        start()
        return root
    end


    function Components.LockOverlay(parent, text)
        local overlay = Instance.new("TextButton")
        overlay.BackgroundColor3 = Theme.Colors.Card
        overlay.BackgroundTransparency = 0.9
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.Position = UDim2.fromOffset(0, 0)
        overlay.Text = ""
        overlay.AutoButtonColor = false
        overlay.BorderSizePixel = 0
        overlay.Parent = parent
        overlay.ZIndex = 50
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, Theme.Radius.Panel)
        corner.Parent = overlay
        local stroke = Instance.new("UIStroke")
        stroke.Color = Theme.Colors.Stroke
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = overlay
        -- Lock icon
        local icon = Instance.new("ImageLabel")
        icon.Image = "rbxassetid://124695679871798"
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.new(0, 28, 0, 28)
        icon.Position = UDim2.new(0.5, -14, 0.32, -14)
        icon.ImageColor3 = Theme.Colors.TextMuted
        icon.ImageTransparency = 0.25
        icon.ZIndex = 51
        icon.Parent = overlay
        -- Hint text
        local hint = Instance.new("TextLabel")
        hint.Text = text or "当前功能未开发。后续将会挨个补齐。"
        hint.BackgroundTransparency = 1
        hint.Size = UDim2.new(1, -24, 0, 24)
        hint.Position = UDim2.new(0, 12, 0.58, 0)
        hint.TextSize = 15
        hint.TextColor3 = Theme.Colors.TextDim
        hint.TextXAlignment = Enum.TextXAlignment.Center
        hint.TextYAlignment = Enum.TextYAlignment.Top
        hint.Font = Theme.Font
        hint.ZIndex = 51
        hint.Parent = overlay
        return overlay
    end


function AddPage(page)
        table.insert(Pages.List, page)
        Pages.ById[page.id] = page
    end

    local function Option(label, value)
        return {
            label = label,
            value = value,
        }
    end

    -- ===== 配置管理器（存档） =====
    local CONFIG_DIR = "秋容配置"
    ConfigManager = {
        _autoloadFile = CONFIG_DIR .. "/_autoload.txt",
        _onChanged = {},  -- 所有页面 item 的 onChanged（加载配置时触发功能）
        _callbacksReady = false,
        _configSignature = nil,
        _configControl = nil,
        _applyToken = 0,
        _listCache = nil,
        _listCacheAt = 0,
        _savedJson = {},
    }
    function ConfigManager:_normalizeName(name)
        name = tostring(name or "")
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        name = name:gsub("[\\/:*?\"<>|]", "_")
        name = name:gsub("%.%.+", ".")
        if #name > 64 then name = name:sub(1, 64) end
        if name == "" or name == "." or name == "_autoload" then return nil end
        return name
    end
    -- 从所有页面遍历注册 onChanged（比依赖渲染更可靠，覆盖全部功能）
    function ConfigManager:_registerCallbacks()
        if self._callbacksReady then return end
        local map = {}
        local function walk(items)
            for _, item in ipairs(items or {}) do
                if item.key and item.onChanged then
                    map[item.key] = item.onChanged
                end
                if item.colorKey and item.onColorChanged then
                    map[item.colorKey] = item.onColorChanged
                end
                if item.items then walk(item.items) end
            end
        end
        for _, page in ipairs(Pages.List) do
            if page.sections then
                for _, section in ipairs(page.sections) do walk(section.items) end
            end
            if page.subcategories then
                for _, sub in ipairs(page.subcategories) do
                    for _, section in ipairs(sub.sections or {}) do walk(section.items) end
                end
            end
        end
        ConfigManager._onChanged = map
        self._callbacksReady = true
    end
    function ConfigManager:_path(name)
        return CONFIG_DIR .. "/" .. name .. ".json"
    end
    function ConfigManager:_ensureDir()
        if type(makefolder) == "function" and type(isfolder) == "function" then
            pcall(function()
                if not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
            end)
        end
    end
    function ConfigManager:_collectState()
        local data = {}
        for k, v in pairs(State.Toggles) do data["T:" .. k] = v and true or false end
        for k, v in pairs(State.Sliders) do data["S:" .. k] = v end
        for k, v in pairs(State.Inputs) do if v ~= nil and v ~= "" then data["I:" .. k] = v end end
        for k, v in pairs(State.Dropdowns) do if v ~= nil and v ~= "" and v ~= "无" then data["D:" .. k] = v end end
        for k, v in pairs(State.Segments) do if v ~= nil then data["G:" .. k] = v end end
        for k, v in pairs(State.Numbers) do data["N:" .. k] = v end
        for k, v in pairs(State.Colors) do
            if typeof(v) == "Color3" then data["C:" .. k] = { v.R, v.G, v.B } end
        end
        for k, v in pairs(State.MultiDropdowns) do
            local set = {}
            for kk, vv in pairs(v) do if vv then table.insert(set, kk) end end
            if #set > 0 then
                table.sort(set)
                data["M:" .. k] = set
            end
        end
        return data
    end
    local function _readStateVal(k)
        local v = State.Toggles[k]
        if v == nil then v = State.Sliders[k] end
        if v == nil then v = State.Segments[k] end
        if v == nil then v = State.Dropdowns[k] end
        if v == nil then v = State.Numbers[k] end
        if v == nil then v = State.Inputs[k] end
        if v == nil then v = State.Colors[k] end
        if v == nil then v = State.MultiDropdowns[k] end
        return v
    end
    function ConfigManager:_applyState(data)
        if not data then return end
        self._applyToken = self._applyToken + 1
        local applyToken = self._applyToken
        local loaded = {}
        local function finiteNumber(value)
            local number = tonumber(value)
            if not number or number ~= number or math.abs(number) == math.huge then return nil end
            return number
        end
        local function validColor(value)
            if type(value) ~= "table" then return nil end
            local r, g, b = finiteNumber(value[1]), finiteNumber(value[2]), finiteNumber(value[3])
            if not r or not g or not b then return nil end
            if r < 0 or r > 1 or g < 0 or g > 1 or b < 0 or b > 1 then return nil end
            return Color3.new(r, g, b)
        end
        for key, val in pairs(data) do
            local kind, k = key:match("^([A-Z]):(.+)$")
            if kind and k then
                if kind == "T" then State.Toggles[k] = val == true
                elseif kind == "S" then
                    local number = finiteNumber(val); if number then State.Sliders[k] = number else continue end
                elseif kind == "I" and type(val) == "string" then State.Inputs[k] = val
                elseif kind == "D" and type(val) == "string" then State.Dropdowns[k] = val
                elseif kind == "G" and type(val) == "string" then State.Segments[k] = val
                elseif kind == "N" then
                    local number = finiteNumber(val); if number then State.Numbers[k] = number else continue end
                elseif kind == "C" then
                    local color = validColor(val); if color then State.Colors[k] = color else continue end
                elseif kind == "M" and type(val) == "table" then
                    local set = {}
                    for _, item in ipairs(val) do if type(item) == "string" and item ~= "" then set[item] = true end end
                    State.MultiDropdowns[k] = set
                else
                    continue
                end
                loaded[k] = true
            end
        end
        -- 分散触发 onChanged（分批跨帧，避免几十个重活同步跑卡死；控件视觉先同步刷新）
        local pending = {}
        for k in pairs(loaded) do
            -- 刷新已渲染控件视觉
            local ctrl = State.Controls[k]
            if ctrl and ctrl.SetValue then
                local cv = _readStateVal(k)
                if cv ~= nil then pcall(function() ctrl.SetValue(cv, true) end) end
            end
            local cb = ConfigManager._onChanged[k]
            if cb then pending[#pending + 1] = { key = k, cb = cb } end
        end
        task.spawn(function()
            for i, p in ipairs(pending) do
                if applyToken ~= ConfigManager._applyToken then return end
                pcall(p.cb, _readStateVal(p.key))
                if i % 4 == 0 then task.wait() end  -- 每4个让一帧，避免卡顿
            end
        end)
        return #pending
    end
    function ConfigManager:ListConfigs()
        local now = os.clock()
        if self._listCache and now - self._listCacheAt < 0.25 then
            return self._listCache
        end
        local names = {}
        if type(listfiles) == "function" then
            local ok, files = pcall(function() return listfiles(CONFIG_DIR) end)
            if ok and files then
                for _, f in ipairs(files) do
                    local base = f:match("([^/\\]+)%.json$")
                    if base then table.insert(names, base) end
                end
            end
        end
        table.sort(names)
        self._listCache = names
        self._listCacheAt = now
        return names
    end
    function ConfigManager:RefreshDropdown()
        local names = ConfigManager:ListConfigs()
        local signature = table.concat(names, "\0")
        local ctrl = State.Controls["config.dropdown.select"]
        if signature == self._configSignature and ctrl == self._configControl then
            return
        end
        self._configSignature = signature
        self._configControl = ctrl
        local opts = {}
        for _, n in ipairs(names) do table.insert(opts, { label = n, value = n }) end
        if ctrl and ctrl.SetOptions then
            -- SetOptions 签名是 (_, newOptions)，必须传 nil 占位
            pcall(function() ctrl.SetOptions(nil, opts) end)
        end
    end
    function ConfigManager:SaveConfig(name)
        name = self:_normalizeName(name)
        if not name then return false, "配置名称无效" end
        ConfigManager:_ensureDir()
        local path = ConfigManager:_path(name)
        if not State.Toggles["config.toggle.overwrite"] and type(isfile) == "function" then
            local exists = false
            pcall(function() exists = isfile(path) end)
            if exists then
                local i = 1
                while true do
                    local p = ConfigManager:_path(name .. "_" .. i)
                    local e = false
                    pcall(function() e = isfile(p) end)
                    if not e then path = p; break end
                    i = i + 1
                end
            end
        end
        local data = ConfigManager:_collectState()
        local ok, json = pcall(function() return game:GetService("HttpService"):JSONEncode(data) end)
        if not ok then return false, "序列化失败" end
        local cached = self._savedJson[path]
        local existsNow = false
        if type(isfile) == "function" then pcall(function() existsNow = isfile(path) end) end
        if existsNow and cached == json then
            self._configSignature = nil
            self._listCacheAt = 0
            ConfigManager:RefreshDropdown()
            return true, "已保存"
        end
        local wok, werr = pcall(function() writefile(path, json) end)
        if not wok then return false, "写入失败: " .. tostring(werr) end
        self._savedJson[path] = json
        self._configSignature = nil
        self._listCacheAt = 0
        ConfigManager:RefreshDropdown()
        return true, "已保存"
    end
    function ConfigManager:LoadConfig(name)
        name = self:_normalizeName(name)
        if not name then return false, "配置名称无效" end
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return false, "执行器无readfile" end
        local path = ConfigManager:_path(name)
        local exists = false
        pcall(function() exists = isfile(path) end)
        if not exists then return false, "配置不存在" end
        local ok, content = pcall(function() return readfile(path) end)
        if not ok or not content then return false, "读取失败" end
        local dok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(content) end)
        if not dok or type(data) ~= "table" then return false, "解析失败" end
        ConfigManager:_registerCallbacks()  -- 重建完整 onChanged 表
        local fired = ConfigManager:_applyState(data)
        self._configSignature = nil
        self._listCacheAt = 0
        ConfigManager:RefreshDropdown()
        return true, "已加载(" .. tostring(fired) .. "项生效)"
    end
    function ConfigManager:DeleteConfig(name)
        name = self:_normalizeName(name)
        if not name then return false, "配置名称无效" end
        if type(delfile) ~= "function" then return false, "无delfile" end
        local path = ConfigManager:_path(name)
        local ok, err = pcall(function() delfile(path) end)
        if not ok then return false, "删除失败" end
        self._configSignature = nil
        self._listCacheAt = 0
        ConfigManager:RefreshDropdown()
        return true, "已删除"
    end
    function ConfigManager:WriteAutoLoad(name)
        name = self:_normalizeName(name)
        if not name then return false end
        ConfigManager:_ensureDir()
        if type(writefile) ~= "function" then return false end
        local ok = pcall(function() writefile(ConfigManager._autoloadFile, name) end)
        if not ok then return false end
        if type(isfile) == "function" then
            local exists = false
            pcall(function() exists = isfile(ConfigManager._autoloadFile) end)
            if not exists then return false end
        end
        return true
    end
    function ConfigManager:ClearAutoLoad()
        if type(delfile) ~= "function" then return false end
        if type(isfile) == "function" then
            local exists = false
            pcall(function() exists = isfile(ConfigManager._autoloadFile) end)
            if not exists then return true end
        end
        local ok = pcall(function() delfile(ConfigManager._autoloadFile) end)
        return ok
    end
    function ConfigManager:ReadAutoLoad()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return nil end
        local exists = false
        pcall(function() exists = isfile(ConfigManager._autoloadFile) end)
        if not exists then return nil end
        local ok, content = pcall(function() return readfile(ConfigManager._autoloadFile) end)
        if ok and content and content ~= "" then return content end
        return nil
    end
    -- 重载保留用：无自动加载时只保存已开启的功能开关（重载后仅恢复这些，没开的不会被打开）
    _G._BFH_PRESERVE_FN = function()
        local _al = ConfigManager:ReadAutoLoad()
        if _al and _al ~= "" then return nil end
        local _data = {}
        for _k, _v in pairs(State.Toggles) do
            if _v then _data["T:" .. _k] = true end
        end
        if not next(_data) then return nil end
        return _data
    end

    AddPage({
        id = "config",
        title = "存档",
        icon = "C",
        subtitle = "配置存档管理",
        sections = {
            {
                title = "配置管理",
                items = {
                    {
                        type = "input",
                        key = "config.input.name",
                        title = "配置名称",
                        desc = "输入存档名称",
                        placeholder = "例如: 配置1",
                        default = "",
                    },
                    {
                        type = "toggle",
                        key = "config.toggle.overwrite",
                        title = "叠加替换原名称",
                        desc = "开启：同名直接替换 / 关闭：同名自动编号保存",
                        default = true,
                        internal = true,
                    },
                    {
                        type = "button",
                        key = "config.button.save",
                        title = "保存配置",
                        desc = "将当前所有控件状态保存到文件",
                        actionText = "保存",
                        internal = true,
                        onChanged = function()
                            local name = State.Inputs['config.input.name'] or ''
                            if name == '' then
                                State:AddLog('存档', '请输入配置名称', 'config.save.empty')
                                return
                            end
                            local ok, msg = ConfigManager:SaveConfig(name)
                            State:AddLog('存档', msg, ok and 'config.save.ok' or 'config.save.fail')
                            ConfigManager:RefreshDropdown()
                        end,
                    },
                    {
                        type = "dropdown",
                        key = "config.dropdown.select",
                        title = "选择配置",
                        desc = "选择一个已保存的配置",
                        default = "无",
                        options = {},
                        optionsCallback = function()
                            local names = ConfigManager and ConfigManager:ListConfigs() or {}
                            local opts = {}
                            for _, n in ipairs(names) do table.insert(opts, { label = n, value = n }) end
                            return opts
                        end,
                    },
                    {
                        type = "button",
                        key = "config.button.load",
                        title = "加载配置",
                        desc = "加载选中配置到当前界面",
                        actionText = "加载",
                        internal = true,
                        onChanged = function()
                            local name = State.Dropdowns['config.dropdown.select']
                            if type(name) ~= 'string' or name == '无' then
                                State:AddLog('存档', '请先选择配置', 'config.load.empty')
                                return
                            end
                            local ok, msg = ConfigManager:LoadConfig(name)
                            ConfigManager:RefreshDropdown()
                            local ctrlLoad = State.Controls["config.dropdown.select"]
                            if ctrlLoad and ctrlLoad.SetValue then ctrlLoad.SetValue(name, true) end
                            if type(msg) ~= 'string' then msg = ok and '配置已加载' or '操作失败' end
                            if State.Toggles['config.toggle.autosave'] then
                                State.Toggles['config.toggle.autosave'] = false
                                local ac = State.Controls['config.toggle.autosave']
                                if ac and ac.SetValue then ac.SetValue(false, true) end
                                State:AddLog('TOGGLE', '自动保存已关闭', 'config.autosave.off')
                            end
                            State:AddLog('存档', msg, ok and 'config.load.ok' or 'config.load.fail')
                        end,
                    },
                    {
                        type = "button",
                        key = "config.button.delete",
                        title = "删除配置",
                        desc = "删除选中的配置文件",
                        actionText = "删除",
                        confirm = true,
                        confirmText = '确认删除此配置？',
                        internal = true,
                        onChanged = function()
                            local name = State.Dropdowns['config.dropdown.select']
                            if type(name) ~= 'string' or name == '无' then
                                State:AddLog('存档', '请先选择配置', 'config.delete.empty')
                                return
                            end
                            local ok, msg = ConfigManager:DeleteConfig(name)
                            task.wait()
                            ConfigManager:RefreshDropdown()
                            local ctrlDel = State.Controls['config.dropdown.select']
                            if ctrlDel and ctrlDel.SetValue then ctrlDel.SetValue('无', true) end
                            if type(msg) ~= 'string' then msg = ok and '已删除' or '操作失败' end
                            State:AddLog('存档', msg, ok and 'config.delete.ok' or 'config.delete.fail')
                        end,
                    },
                    {
                        type = "button",
                        key = "config.button.autoload",
                        title = "自动加载",
                        desc = "设置当前选中配置为下次启动时自动加载",
                        actionText = "设置自动加载",
                        internal = true,
                        onChanged = function()
                            local name = State.Dropdowns["config.dropdown.select"]
                            if not name or name == "无" then
                                State:AddLog("存档", "请先选择配置", "config.autoload.empty")
                                return
                            end
                            ConfigManager:WriteAutoLoad(name)
                            local ok, msg = ConfigManager:LoadConfig(name)
                            ConfigManager:RefreshDropdown()
                            if ok then
                                local ctrl = State.Controls["config.dropdown.select"]
                                if ctrl and ctrl.SetValue then ctrl.SetValue(name, true) end
                            end
                            -- 更新当前自动加载配置状态显示
                            local ctrlStatus = State.Controls["config.status.current"]
                            if ctrlStatus and ctrlStatus.SetValue then
                                pcall(function() ctrlStatus.SetValue(nil, name) end)
                            end
                            if State.Toggles["config.toggle.autosave"] then
                                State.Toggles["config.toggle.autosave"] = false
                                local ac = State.Controls["config.toggle.autosave"]
                                if ac and ac.SetValue then ac.SetValue(false, true) end
                                State:AddLog("TOGGLE", "自动保存已关闭", "config.autosave.off")
                            end
                            State:AddLog("存档", ok and "已设置自动加载: " .. name or "操作失败", ok and "config.autoload.ok" or "config.autoload.fail")
                        end,
                    },
                    {
                        type = "status",
                        key = "config.status.current",
                        title = "当前自动加载配置",
                        desc = "当前加载的配置名称",
                        value = "无",
                    },
                    {
                        type = "button",
                        key = "config.button.clear_autoload",
                        title = "去除当前自动加载配置",
                        desc = "清除自动加载设置",
                        actionText = "去除",
                        internal = true,
                        onChanged = function()
                            ConfigManager:ClearAutoLoad()
                            local ctrlStatus = State.Controls["config.status.current"]
                            if ctrlStatus and ctrlStatus.SetValue then
                                pcall(function() ctrlStatus.SetValue(nil, "无") end)
                            end
                            State:AddLog("存档", "已去除自动加载", "config.autoload.clear")
                        end,
                    },
                },
            },
            {
                title = "自动保存",
                items = {
                    {
                        type = "toggle",
                        key = "config.toggle.autosave",
                        title = "自动保存与读取",
                        desc = "记录你上次开关了哪些按钮，下次执行脚本时自动恢复",
                        default = false,
                        internal = true,
                    },
                },
            },
        },
    })


    local function RegisterItems(page, section, items)
        for _, item in ipairs(items or {}) do
            item.page = page.id

            if item.key then
                Registry.Ensure(item.key, {
                    Type = item.type,
                    Title = item.title,
                    Page = page.id,
                    Section = section and section.title or nil,
                    Internal = item.internal == true,
                })
                -- 注册 onChanged 供加载配置时触发（不分页面是否渲染）
                if item.onChanged and ConfigManager then
                    ConfigManager._onChanged[item.key] = item.onChanged
                end
            end

            if item.items then
                RegisterItems(page, section, item.items)
            end
        end
    end

    local function RegisterPageKeys()
        for _, page in ipairs(Pages.List) do
            if page.sections then
                for _, section in ipairs(page.sections) do
                    RegisterItems(page, section, section.items)
                end
            end

            if page.subcategories then
                Registry.Ensure("page." .. page.id .. ".subcategory", {
                    Type = "segment",
                    Title = page.title .. "子分类",
                    Page = page.id,
                    Internal = true,
                })

                for _, subcategory in ipairs(page.subcategories) do
                    for _, section in ipairs(subcategory.sections or {}) do
                        RegisterItems(page, section, section.items)
                    end
                end
            end
        end

        Registry.Ensure("topbar.marquee", { Type = "marquee", Title = "顶部走马灯", Internal = true })
        Registry.Ensure("window.minimize", { Type = "icon-button", Title = "最小化", Internal = true })
        Registry.Ensure("window.close", { Type = "icon-button", Title = "关闭", Internal = true })
        Registry.Ensure("window.restore", { Type = "button", Title = "恢复窗口", Internal = true })
    end

    function UI.GetScreenParent()
        local candidates = {}

        local okHui, hui = pcall(function()
            if gethui then
                return gethui()
            end
            return nil
        end)

        if okHui and hui then
            table.insert(candidates, hui)
        end

        table.insert(candidates, Services.CoreGui)

        local localPlayer = Services.Players.LocalPlayer
        if localPlayer then
            table.insert(candidates, localPlayer:WaitForChild("PlayerGui"))
        end

        for _, candidate in ipairs(candidates) do
            local testGui = Instance.new("ScreenGui")
            local ok = pcall(function()
                testGui.Parent = candidate
            end)
            testGui:Destroy()

            if ok then
                return candidate
            end
        end

        return Services.Players.LocalPlayer:WaitForChild("PlayerGui")
    end

    function UI.GetWindowPresetSize()
        for _, preset in ipairs(AppConfig.WindowPresets) do
            if preset.value == State.WindowPreset then
                return preset.size
            end
        end

        return AppConfig.WindowSize
    end

    function UI.GetBoundedWindowSize(targetSize)
        targetSize = targetSize or UI.GetWindowPresetSize()
        if not UI.RootGui then
            return targetSize
        end

        local rootSize = UI.RootGui.AbsoluteSize
        if rootSize.X <= 0 or rootSize.Y <= 0 then
            return targetSize
        end

        local scale = math.max(State.DpiScale or 1, 0.01)
        local maxWidth = math.max(1, math.floor((rootSize.X - 24) / scale))
        local maxHeight = math.max(1, math.floor((rootSize.Y - 24) / scale))

        return Vector2.new(math.min(targetSize.X, maxWidth), math.min(targetSize.Y, maxHeight))
    end

    function UI.ApplyWindowBounds()
        if UI.Main then
            local targetSize = UI.GetBoundedWindowSize(UI.GetWindowPresetSize())
            UI.Main.Size = UDim2.fromOffset(targetSize.X, targetSize.Y)
            UI.Main.Position = ClampFrameToScreen(UI.Main, UI.Main.Position)
        end

        if UI.ShowButton then
            UI.ShowButton.Position = ClampFrameToScreen(UI.ShowButton, UI.ShowButton.Position)
        end
    end

    function UI.ScheduleApplyWindowBounds()
        if UI.BoundsPending then return end
        UI.BoundsPending = true
        task.defer(function()
            UI.BoundsPending = false
            if UI.RootGui then UI.ApplyWindowBounds() end
        end)
    end




    function UI.SetVisible(visible)
        UI.VisibleToken = (UI.VisibleToken or 0) + 1
        local token = UI.VisibleToken
        local MinimizeDuration = 0.06

        if visible then
            if UI.Main then
                UI.Main.Visible = true
                UI.Main.Size = UDim2.fromOffset(1, 1)
                task.defer(function()
                    if token ~= UI.VisibleToken then return end
                    Tween(UI.Main, {
                        Size = UI._savedWindowSize or UDim2.fromOffset(760, 500),
                    }, Theme.Animation.Slow, Enum.EasingStyle.Back)
                end)
            end
            if UI.ShowButton then
                Tween(UI.ShowButton, { BackgroundTransparency = 1, ImageTransparency = 1 }, MinimizeDuration)
                if UI.ShowButtonStroke then Tween(UI.ShowButtonStroke, { Transparency = 1 }, MinimizeDuration) end
                task.delay(MinimizeDuration + 0.02, function()
                    if UI.ShowButton and token == UI.VisibleToken and visible then
                        UI.ShowButton.Visible = false
                        UI.ShowButton.ImageTransparency = 0
                    end
                end)
            end
        else
            if UI.Main then
                UI._savedWindowSize = UI.Main.Size
                Tween(UI.Main, {
                    Size = UDim2.fromOffset(1, 1),
                }, Theme.Animation.Normal)
                task.delay(Theme.Animation.Normal + 0.04, function()
                    if token == UI.VisibleToken and not visible then
                        UI.Main.Visible = false
                        UI.Main.Size = UI._savedWindowSize
                    end
                end)
            end
            if UI.ShowButton then
                UI.ShowButton.Visible = true
                UI.ShowButton.BackgroundTransparency = 1
                UI.ShowButton.ImageTransparency = 1
                Tween(UI.ShowButton, { BackgroundTransparency = 1, ImageTransparency = 0 }, MinimizeDuration)
                if UI.ShowButtonStroke then Tween(UI.ShowButtonStroke, { Transparency = 0 }, MinimizeDuration) end
            end
        end
        State:AddLog("UI", visible and "已打开窗口" or "已隐藏窗口", "window.visibility")
    end


    function UI.Track(connection, scope)
        if not connection then
            return nil
        end

        if UI._trackedConnections[connection] then
            return connection
        end

        if scope == "page" then
            table.insert(UI.PageConnections, connection)
        elseif scope == "log" then
            table.insert(UI.LogConnections, connection)
        else
            table.insert(UI.Connections, connection)
        end
        UI._trackedConnections[connection] = true
        return connection
    end

    function UI.ClearPageConnections()
        DisconnectConnections(UI.PageConnections)
    end

    function UI.ClearLogConnections()
        DisconnectConnections(UI.LogConnections)
    end

    function UI.Destroy()
        -- 停止聊天轮询线程
        if ChatPollThread then task.cancel(ChatPollThread); ChatPollThread = nil end
        -- 销毁飞行悬浮窗
        if Movement and Movement.hideFlyWindow then Movement.hideFlyWindow() end
        -- 销毁 Livestream
        UI.DestroyLivestream()

        UI.ClearPageConnections()
        UI.ClearLogConnections()
        DisconnectConnections(UI.Connections)
        State:ClearVisibleControls()

        if UI.RootGui then
            UI.RootGui:Destroy()
        end
        UI.RootGui = nil
        UI.Main = nil
        UI.ShowButton = nil
        UI.Content = nil
        UI.ContentLayout = nil
        UI.Sidebar = nil
        UI.LogList = nil
        UI.LogRefreshPending = false
        UI.BoundsPending = false
        UI.ToastRoot = nil
        UI.ToastToken = UI.ToastToken + 1
        UI.ToastThrottle = {}
        UI.ToastScale = nil
        UI.TooltipScale = nil
        UI.TooltipSource = nil
        UI.ModalScale = nil
        UI.ShowScale = nil
        UI.Livestream = nil
        UI.ShowButtonStroke = nil
        UI.Tooltip = nil
        UI.TooltipToken += 1
        UI.VisibleToken += 1
        UI.ModalRoot = nil
        UI.Scale = nil
        UI.SidebarButtons = {}
        UI._sidebarVisualState = {}
        UI.Connections = {}
        UI.PageConnections = {}
        UI.LogConnections = {}
        UI._trackedConnections = setmetatable({}, { __mode = "k" })
    end

    function UI.UpdateSidebar()
        for pageId, button in pairs(UI.SidebarButtons) do
            local active = pageId == State.CurrentPage
            if UI._sidebarVisualState[pageId] == active then
                continue
            end
            local targetColor = active and Theme.Colors.AccentDim or Theme.Colors.Window
            local targetStroke = active and Theme.Colors.AccentSoft or Theme.Colors.Stroke

            Tween(button, { BackgroundColor3 = targetColor }, Theme.Animation.Fast)
            local stroke = button:FindFirstChildOfClass("UIStroke")
            if stroke then
                Tween(stroke, { Color = targetStroke }, Theme.Animation.Fast)
            end

            local label = button:FindFirstChild("PageName")
            if label then
                label.TextSize = active and 15 or 13
                label.TextColor3 = active and Theme.Colors.Text or Theme.Colors.TextMuted
            end
            UI._sidebarVisualState[pageId] = active
        end
    end

    function UI.SetPage(pageId)
        if not Pages.ById[pageId] then
            return
        end
        if State.CurrentPage == pageId and UI.Content and UI.Content.Visible then
            return
        end

        State.CurrentPage = pageId
        UI.UpdateSidebar()
        UI.RenderPage(pageId)
    end

    local searchResultsCache = {}
    local searchResultsCacheOrder = {}
    local SEARCH_CACHE_LIMIT = 24
    local function clearSearchResultsCache()
        table.clear(searchResultsCache)
        table.clear(searchResultsCacheOrder)
    end

    function UI.FindItems(query)
        local results = {}
        query = string.lower(query or "")
        if searchResultsCache[query] then
            return searchResultsCache[query]
        end

        local function scanItems(page, items, sectionTitle)
            for _, item in ipairs(items or {}) do
                if UI.ItemMatches(item, query) then
                    table.insert(results, {
                        page = page,
                        section = sectionTitle or "",
                        item = item,
                    })
                end

                if item.items then
                    scanItems(page, item.items, sectionTitle)
                end
            end
        end

        for _, page in ipairs(Pages.List) do
            for _, section in ipairs(page.sections or {}) do
                scanItems(page, section.items, section.title)
            end

            for _, subcategory in ipairs(page.subcategories or {}) do
                for _, section in ipairs(subcategory.sections or {}) do
                    scanItems(page, section.items, subcategory.title .. " / " .. section.title)
                end
            end
        end

        searchResultsCache[query] = results
        table.insert(searchResultsCacheOrder, query)
        while #searchResultsCacheOrder > SEARCH_CACHE_LIMIT do
            local expired = table.remove(searchResultsCacheOrder, 1)
            searchResultsCache[expired] = nil
        end
        return results
    end

    function UI.ItemTextMatches(item, query)
        return ContainsText(item.key, query)
            or ContainsText(item.title, query)
            or ContainsText(item.desc, query)
            or ContainsText(item.badge, query)
    end

    local itemMatchCache = {}
    local itemMatchCacheOrder = {}
    function UI.ItemMatches(item, query)
        if query == "" then
            return true
        end

        local queryCache = itemMatchCache[query]
        if not queryCache then
            queryCache = setmetatable({}, { __mode = "k" })
            itemMatchCache[query] = queryCache
            table.insert(itemMatchCacheOrder, query)
            while #itemMatchCacheOrder > SEARCH_CACHE_LIMIT do
                local expired = table.remove(itemMatchCacheOrder, 1)
                itemMatchCache[expired] = nil
            end
        elseif queryCache[item] ~= nil then
            return queryCache[item]
        end

        if UI.ItemTextMatches(item, query) then
            queryCache[item] = true
            return true
        end

        for _, child in ipairs(item.items or {}) do
            if UI.ItemMatches(child, query) then
                queryCache[item] = true
                return true
            end
        end

        queryCache[item] = false
        return false
    end

    function UI.RenderItem(parent, item, forceChildren)
        local query = State.CurrentPage == "search" and "" or string.lower(State.SearchText or "")
        if not forceChildren and not UI.ItemMatches(item, query) then
            return false
        end

        local rendered = true
        local control = nil
        if item.type == "button" then
            control = Components.Button(parent, item)
        elseif item.type == "toggle" then
            control = Components.Toggle(parent, item)
        elseif item.type == "slider" then
            control = Components.Slider(parent, item)
        elseif item.type == "input" then
            control = Components.TextInput(parent, item)
        elseif item.type == "dropdown" then
            control = Components.Dropdown(parent, item)
        elseif item.type == "segment" then
            control = Components.Segmented(parent, item)
        elseif item.type == "number" then
            control = Components.NumberInput(parent, item)
        elseif item.type == "color" then
            control = Components.ColorPicker(parent, item)
        elseif item.type == "multi" then
            control = Components.MultiDropdown(parent, item)
        elseif item.type == "keybind" then
            control = Components.Keybind(parent, item)
        elseif item.type == "progress" then
            control = Components.Progress(parent, item)
        elseif item.type == "tags" then
            control = Components.TagRow(parent, item)
        elseif item.type == "table" then
            control = Components.Table(parent, item)
        elseif item.type == "status" then
            control = Components.StatusLabel(parent, item)
        elseif item.type == "list" then
            control = Components.ListItem(parent, item)
        elseif item.type == "category" then
            control = Components.CategoryCard(parent, item)
        elseif item.type == "log" then
            control = Components.LogOutput(parent, item)
        elseif item.type == "collapsible" then
            local _, content = Components.Collapsible(parent, item)
            if item.locked then Components.LockOverlay(content, item.lockText) end
            local groupMatched = UI.ItemTextMatches(item, query)
            for _, child in ipairs(item.items or {}) do
                UI.RenderItem(content, child, forceChildren or groupMatched)
            end
        else
            State:AddLog("ERROR", "未知控件类型: " .. tostring(item.type), item.key or "render.unknown")
            rendered = false
        end

        if control and item.locked then
            Components.LockOverlay(control, item.lockText)
        end

        return rendered
    end

    function UI.ResolveSections(page)
        if page.dynamic == "favorites" then
            local items = {}
            for key in pairs(State.Favorites) do
                local meta = Registry.Meta[key]
                if meta then
                    table.insert(items, {
                        type = "list",
                        key = "favorites.item." .. key,
                        title = meta.Title or key,
                        desc = key .. " / " .. (meta.Page or "unknown"),
                        badge = meta.Type or "key",
                        internal = true,
                        page = page.id,
                    })
                end
            end
            table.sort(items, function(a, b)
                return a.key < b.key
            end)
            if #items == 0 then
                items = {
                    { type = "list", key = "favorites.empty", title = "暂无收藏", desc = "当前未添加收藏按钮，请前往主UI点击五角星收藏", badge = "空", internal = true, page = page.id },
                }
            end
            return { { title = "收藏功能", subtitle = "保留旧收藏数据展示，不再在控件上显示星标。", items = items } }
        elseif page.dynamic == "recent" then
            local items = {}
            for _, row in ipairs(State.Recent) do
                table.insert(items, {
                    type = "list",
                    key = "recent.item." .. row.key,
                    title = row.title,
                    desc = row.key .. " / " .. row.time,
                    badge = row.page ~= "" and row.page or "recent",
                    internal = true,
                    page = page.id,
                })
            end
            if #items == 0 then
                items = {
                    { type = "list", key = "recent.empty", title = "暂无最近使用", desc = "操作任意控件后会自动显示在这里。", badge = "空", internal = true, page = page.id },
                }
            end
            return { { title = "最近使用", subtitle = "自动记录最近操作过的控件。", items = items } }
        elseif page.dynamic == "search" then
            local items = {}
            if State.SearchText ~= "" then
                for _, result in ipairs(UI.FindItems(State.SearchText)) do
                    table.insert(items, {
                        type = "list",
                        key = "search.result." .. result.item.key,
                        title = result.item.title or result.item.key,
                        desc = result.item.key .. " / " .. result.page.title .. " / " .. result.section,
                        badge = result.item.type or "item",
                        internal = true,
                        page = page.id,
                    })
                end
            end
            if #items == 0 then
                items = {
                    { type = "list", key = "search.empty", title = "没有全局搜索结果", desc = "在顶部搜索框输入 key、标题或描述。", badge = "搜索", internal = true, page = page.id },
                }
            end
            return { { title = "全局搜索", subtitle = "搜索全部页面、子分类和控件。", items = items } }
        elseif page.dynamic == "registry" then
            local items = {}
            for _, row in ipairs(Registry.GetAll()) do
                table.insert(items, {
                    type = "list",
                    key = "registry.item." .. row.Key,
                    title = row.Title or row.Key,
                    desc = row.Key .. " / " .. (row.Page or "global"),
                    badge = row.Bound and "已绑定" or "空回调",
                    internal = true,
                    page = page.id,
                })
            end
            return {
                {
                    title = "Registry Key 清单",
                    subtitle = "用于以后接功能时查 key，默认都是空回调。",
                    items = items,
                },
            }
        end

        if not page.subcategories then
            return page.sections or {}
        end

        local active = State.SubPages[page.id]
        if not active and page.subcategories[1] then
            active = page.subcategories[1].id
            State.SubPages[page.id] = active
        end

        for _, subcategory in ipairs(page.subcategories) do
            if subcategory.id == active then
                return subcategory.sections or {}
            end
        end

        return {}
    end

    function UI.RenderSubcategories(parent, page)
        if not page.subcategories then
            return
        end

        local options = {}
        for _, subcategory in ipairs(page.subcategories) do
            table.insert(options, Option(subcategory.title, subcategory.id))
        end

        Components.Segmented(parent, {
            type = "segment",
            key = "page." .. page.id .. ".subcategory",
            page = page.id,
            title = page.subcategoryTitle or "子分类",
            desc = "切换当前分类下的功能组",
            default = State.SubPages[page.id] or (page.subcategories[1] and page.subcategories[1].id),
            options = options,
            stacked = true,
            internal = true,
            onChanged = function(value)
                State.SubPages[page.id] = value
                UI._skipRenderAnim = true  -- 子分类切换跳过淡出动画，直接刷新
                UI.RenderPage(page.id)
            end,
        })
    end


    -- ===== 反馈页面布局 =====
    -- 层级: UI.Content(ScrollingFrame) → root(Frame,铺满) → Box辅助 → 子区块
function Registry.GetAll() return {} end   -- 原脚本里是死代码，这里补空实现防未定义
	local function RenderFeedback() return end
	local function RenderChat() return end
    function UI.RenderPage(pageId)

        if not UI.Content then
            return
        end

        -- 反馈/聊天 特殊渲染（取消旧动画）
        if pageId == "feedback" then
            UI._switchToken = (UI._switchToken or 0) + 1
            UI.Content.Visible = true
            UI.Content.AutomaticCanvasSize = Enum.AutomaticSize.None
            RenderFeedback()
            return
        end
        if pageId == "chat" then
            UI._switchToken = (UI._switchToken or 0) + 1
            UI.Content.Visible = true
            UI.Content.AutomaticCanvasSize = Enum.AutomaticSize.None
            RenderChat()
            return
        end

        UI.Content.AutomaticCanvasSize = Enum.AutomaticSize.Y

        local page = Pages.ById[pageId]
        if not page then
            return
        end

        UI.ClearPageConnections()
        UI.ClearLogConnections()
        UI.HideTooltip()
        UI.LogList = nil
        State:ClearVisibleControls()

        local C = UI.Content
        -- === 清除旧内容（无动画） ===
        UI._switchToken = (UI._switchToken or 0) + 1
        if UI._skipRenderAnim then
            UI._skipRenderAnim = false
        end
        C.Visible = false
        C:ClearAllChildren()
        C.CanvasPosition = Vector2.zero
        AddCorner(C, Theme.Radius.Window)
        AddPadding(C, 16, 16, 14, 16)

        local layout = New("UIListLayout", {
            Padding = UDim.new(0, 14),
            Parent = C,
        })
        UI.ContentLayout = layout
        SetScrollCanvas(C, layout, 20)

        UI.RenderSubcategories(UI.Content, page)

        local query = page.id == "search" and "" or string.lower(State.SearchText or "")
        local renderedAny = false

        for _, section in ipairs(UI.ResolveSections(page)) do
            local sectionHasVisibleItem = false
            for _, item in ipairs(section.items or {}) do
                if UI.ItemMatches(item, query) then
                    sectionHasVisibleItem = true
                    break
                end
            end

            if sectionHasVisibleItem then
                local sectionFrame = Components.Section(UI.Content, section.title, section.subtitle)
                for _, item in ipairs(section.items or {}) do
                    if UI.RenderItem(sectionFrame, item, false) then
                        renderedAny = true
                    end
                end
            end
        end

        if not renderedAny then
            local empty = Components.ControlFrame(UI.Content, 58)
            local label = Components.Label(empty, "没有匹配内容", 17, Theme.Colors.TextMuted, true)
            label.Size = UDim2.new(1, -24, 1, 0)
            label.Position = UDim2.fromOffset(12, 0)
        end

        if pageId == 'config' and ConfigManager and ConfigManager.RefreshDropdown then
            -- 不阻塞渲染：内容立即显示，刷新配置列表异步执行
            task.defer(function()
                if ConfigManager and ConfigManager.RefreshDropdown then
                    pcall(ConfigManager.RefreshDropdown, ConfigManager)
                end
            end)
        end

        -- === 无入场动画，直接显示 ===
        C.Visible = true

    end

    function UI.RefreshLogs()
        if not UI.LogList then
            return
        end
        local version = UI.LogVersion or 0
        if UI._renderedLogList == UI.LogList and UI._renderedLogVersion == version then
            return
        end
        UI._renderedLogList = UI.LogList
        UI._renderedLogVersion = version

        UI.ClearLogConnections()
        for _, child in ipairs(UI.LogList:GetChildren()) do
            if not child:IsA("UICorner") and not child:IsA("UIStroke") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end

        if not UI.LogList:FindFirstChildOfClass("UIPadding") then
            AddPadding(UI.LogList, 8, 8, 8, 8)
        end

        local layout = New("UIListLayout", {
            Padding = UDim.new(0, 5),
            Parent = UI.LogList,
        })
        SetScrollCanvas(UI.LogList, layout, 16, "log")

        if #State.Logs == 0 then
            local empty = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 34),
                Text = "暂无日志",
                TextColor3 = Theme.Colors.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = UI.LogList,
            })
            return empty
        end

        for _, log in ipairs(State.Logs) do
            local row = New("Frame", {
                BackgroundColor3 = Theme.Colors.Control,
                Size = UDim2.new(1, 0, 0, 30),
                Parent = UI.LogList,
            })
            AddCorner(row, Theme.Radius.Control)

            local level = Components.Label(row, log.Level, 12, Theme.Colors.Accent, true)
            level.Position = UDim2.fromOffset(8, 0)
            level.Size = UDim2.fromOffset(58, 30)

            local msgText = type(log.Message) == "string" and log.Message or tostring(log.Message or ""); local message = Components.Label(row, log.Time .. "  " .. msgText, 13, Theme.Colors.TextMuted, false)
            message.Position = UDim2.fromOffset(70, 0)
            message.Size = UDim2.new(1, -210, 1, 0)
            message.TextTruncate = Enum.TextTruncate.AtEnd

            local key = Components.Label(row, log.Key, 12, Theme.Colors.TextDim, false)
            key.AnchorPoint = Vector2.new(1, 0)
            key.Position = UDim2.new(1, -8, 0, 0)
            key.Size = UDim2.fromOffset(130, 30)
            key.TextXAlignment = Enum.TextXAlignment.Right
            key.TextTruncate = Enum.TextTruncate.AtEnd
        end
    end

    function UI.ScheduleLogRefresh()
        if UI.LogRefreshPending then return end
        UI.LogRefreshPending = true
        task.delay(0.1, function()
            UI.LogRefreshPending = false
            if UI.LogList then UI.RefreshLogs() end
        end)
    end

    function UI.BuildToastRoot(parent)
        UI.ToastToken = UI.ToastToken + 1
        local toastToken = UI.ToastToken

        UI.ToastRoot = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -10, 0, 10),
            Size = UDim2.fromOffset(440, 320),
            ClipsDescendants = true,
            Parent = parent,
            ZIndex = 80,
        })
        UI.ToastScale = New("UIScale", {
            Scale = State.DpiScale,
            Parent = UI.ToastRoot,
        })
        UI.ActiveToasts = {}
    end

    function UI._repositionToasts()
        for i, t in ipairs(UI.ActiveToasts) do
            local xOff = (i - 1) * 8
            local yOff = (i - 1) * 48
            Tween(t.wrapper, {
                Position = UDim2.new(1, -xOff, 0, yOff),
            }, 0.2, Enum.EasingStyle.Quad)
        end
    end

    function UI.Notify(level, message, key)
        if not UI.ToastRoot then return end
        local toastToken = UI.ToastToken
        key = tostring(key or "")
        message = tostring(message or "")
        local now = os.clock()
        local throttleKey = key ~= "" and key or message
        if key ~= "" and UI.ToastThrottle[throttleKey] and now - UI.ToastThrottle[throttleKey] < 0.25 and UI.ToastLastMsg[throttleKey] == message then return end
        UI.ToastThrottle[throttleKey] = now
        UI.ToastLastMsg[throttleKey] = message

        -- 超上限时直接干掉最旧的
        while #UI.ActiveToasts >= 5 do
            local old = table.remove(UI.ActiveToasts, #UI.ActiveToasts)
            if old.wrapper and old.wrapper.Parent then old.wrapper:Destroy() end
        end

        SFX.PlayToast()
        local toastDuration = 2.6
        local accent = level == "ERROR" and Color3.fromRGB(255, 96, 96) or Theme.Colors.Accent
        local textW = Services.TextService:GetTextSize(message, 16, Theme.Font, Vector2.new(math.huge, 22)).X
        local toastWidth = math.max(math.min(textW + 44, 420), 160)

        local wrapper = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, 40, 0, 320),  -- 从右侧屏幕外开始
            Size = UDim2.fromOffset(toastWidth, 46),
            Parent = UI.ToastRoot,
            ZIndex = 85,
        })

        local toast = New("Frame", {
            BackgroundColor3 = Theme.Colors.Window,
            BackgroundTransparency = 0.15,
            Size = UDim2.new(1, -2, 1, -2),
            Position = UDim2.fromOffset(1, 1),
            Parent = wrapper,
            ZIndex = 86,
        })
        AddCorner(toast, Theme.Radius.Control)
        local stroke = AddStroke(toast, Color3.fromRGB(80, 80, 80))
        stroke.Transparency = 0.3

        local bar = New("Frame", {
            BackgroundColor3 = accent,
            Size = UDim2.new(0, 3, 1, -8),
            Position = UDim2.fromOffset(6, 4),
            Parent = toast,
            ZIndex = 87,
        })
        AddCorner(bar, Theme.Radius.Pill)

        local titleLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 60, 0, 16),
            Position = UDim2.fromOffset(14, 4),
            Text = tostring(level or "INFO"),
            TextColor3 = accent,
            TextSize = 12,
            Font = Theme.FontBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = toast,
            ZIndex = 87,
        })

        local textLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -22, 0, 20),
            Position = UDim2.fromOffset(14, 20),
            Text = message,
            TextColor3 = Theme.Colors.Text,
            TextSize = 13,
            Font = Theme.Font,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = toast,
            ZIndex = 87,
        })

        -- 进度条
        local progressBg = New("Frame", {
            BackgroundColor3 = Theme.Colors.StrokeStrong,
            BackgroundTransparency = 0.4,
            Size = UDim2.new(1, -20, 0, 2),
            Position = UDim2.fromOffset(14, 42),
            Parent = toast,
            ZIndex = 87,
        })
        AddCorner(progressBg, Theme.Radius.Pill)
        local progressBar = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = accent,
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Parent = progressBg,
            ZIndex = 88,
        })
        AddCorner(progressBar, Theme.Radius.Pill)

        -- 入场动画：从右侧飞入
        Tween(wrapper, {
            Position = UDim2.new(1, 0, 0, 0),
        }, 0.3, Enum.EasingStyle.Quad)

        -- 进度条收缩
        Tween(progressBar, {
            Size = UDim2.new(0, 0, 1, 0),
        }, toastDuration, Enum.EasingStyle.Linear)

        table.insert(UI.ActiveToasts, 1, { wrapper = wrapper })
        UI._repositionToasts()

        -- 退场：淡出 + 右移 + 缩小
        task.delay(toastDuration, function()
            if toastToken ~= UI.ToastToken or not wrapper or not wrapper.Parent then return end
            Tween(wrapper, {
                BackgroundTransparency = 1,
                Position = wrapper.Position + UDim2.fromOffset(50, -4),
                Size = UDim2.fromOffset(toastWidth - 30, 42),
            }, 0.25)
            for _, c in ipairs(toast:GetDescendants()) do
                if c:IsA("TextLabel") then Tween(c, { TextTransparency = 1 }, 0.25)
                elseif c:IsA("Frame") and c ~= progressBg and c ~= progressBar then Tween(c, { BackgroundTransparency = 1 }, 0.25) end
            end
            Tween(stroke, { Transparency = 1 }, 0.25)
            Tween(bar, { BackgroundTransparency = 1 }, 0.25)
            Tween(progressBg, { BackgroundTransparency = 1 }, 0.25)
            Tween(progressBar, { BackgroundTransparency = 1 }, 0.25)

            task.delay(0.28, function()
                if toastToken ~= UI.ToastToken then return end
                if wrapper and wrapper.Parent then wrapper:Destroy() end
                for i, t in ipairs(UI.ActiveToasts) do
                    if t.wrapper == wrapper then table.remove(UI.ActiveToasts, i); break end
                end
                UI._repositionToasts()
            end)
        end)
    end

    function UI.PositionTooltip(object)
        if not UI.Tooltip or not UI.RootGui then
            return
        end

        object = object or UI.TooltipSource
        if not object then
            return
        end

        local rootPosition = UI.RootGui.AbsolutePosition
        local objectPosition = object.AbsolutePosition
        local objectSize = object.AbsoluteSize
        local gap = 8
        local x = objectPosition.X - rootPosition.X + objectSize.X + gap
        local y = objectPosition.Y - rootPosition.Y + objectSize.Y + gap

        UI.Tooltip.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
    end

    function UI.ShowTooltip(text, object)
        if not UI.RootGui then
            return
        end

        UI.TooltipToken += 1
        local token = UI.TooltipToken
        UI.TooltipSource = object
        UI.HideTooltip(nil, true)

        local function createTooltip()
            if token ~= UI.TooltipToken or UI.TooltipSource ~= object or not UI.RootGui then
                return
            end

            local textSize = Services.TextService:GetTextSize(tostring(text), 12, Theme.Font, Vector2.new(300, 120))
            local width = math.clamp(textSize.X + 22, 180, 320)
            local height = math.clamp(textSize.Y + 18, 38, 104)

            local tooltip = New("Frame", {
                BackgroundColor3 = Theme.Colors.PanelDeep,
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(width, math.max(1, height - 6)),
                Parent = UI.RootGui,
                ZIndex = 120,
            })
            UI.TooltipScale = New("UIScale", {
                Scale = State.DpiScale,
                Parent = tooltip,
            })
            AddCorner(tooltip, Theme.Radius.Control)
            AddStroke(tooltip, Theme.Colors.StrokeStrong)
            AddPadding(tooltip, 10, 10, 7, 7)

            local label = Components.Label(tooltip, text, 12, Theme.Colors.TextMuted, false)
            label.Size = UDim2.fromScale(1, 1)
            label.TextWrapped = true
            label.TextYAlignment = Enum.TextYAlignment.Top
            label.TextTransparency = 1
            label.ZIndex = 121

            UI.Tooltip = tooltip
            UI.PositionTooltip(object)

            Tween(tooltip, {
                BackgroundTransparency = 0,
                Size = UDim2.fromOffset(width, height),
            }, Theme.Animation.Fast, Theme.Animation.EmphasisStyle)
            Tween(label, { TextTransparency = 0 }, Theme.Animation.Fast)
            local stroke = tooltip:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Transparency = 1
                Tween(stroke, { Transparency = 0 }, Theme.Animation.Fast)
            end
        end

        if Theme.Animation.TooltipDelay > 0 then
            task.delay(Theme.Animation.TooltipDelay, createTooltip)
        else
            createTooltip()
        end
    end

    function UI.HideTooltip(source, keepToken)
        if source and UI.TooltipSource and source ~= UI.TooltipSource then
            return
        end

        if not keepToken then
            UI.TooltipToken += 1
            UI.TooltipSource = nil
        end

        if UI.Tooltip then
            local tooltip = UI.Tooltip
            UI.Tooltip = nil
            local stroke = tooltip:FindFirstChildOfClass("UIStroke")
            for _, child in ipairs(tooltip:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                    Tween(child, { TextTransparency = 1 }, Theme.Animation.Fast)
                end
            end
            if stroke then
                Tween(stroke, { Transparency = 1 }, Theme.Animation.Fast)
            end
            Tween(tooltip, { BackgroundTransparency = 1 }, Theme.Animation.Fast)
            task.delay(Theme.Animation.Fast + 0.03, function()
                if tooltip and tooltip.Parent then
                    tooltip:Destroy()
                end
            end)
        end
    end

    function UI.Confirm(title, text, onConfirm)
        if not UI.RootGui then
            return
        end

        if not State.ConfirmEnabled then
            if onConfirm then
                onConfirm()
            end
            return
        end

        if UI.ModalRoot then
            UI.ModalRoot:Destroy()
        end

        -- 全屏遮罩
        local overlay = New("TextButton", {
            BackgroundColor3 = Theme.Colors.Overlay,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            Parent = UI.Main,
            ZIndex = 100,
        })
        UI.ModalRoot = overlay

        local modal = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Colors.Window,
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(459, 211),
            Parent = overlay,
            ZIndex = 101,
        })
        UI.ModalScale = New("UIScale", {
            Scale = State.DpiScale,
            Parent = modal,
        })
        AddCorner(modal, Theme.Radius.Window)
        local modalStroke = AddStroke(modal, Theme.Colors.StrokeStrong)
        modalStroke.Transparency = 1

        -- 标题栏（可拖动把手）
        local header = New("Frame", {
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Size = UDim2.new(1, 0, 0, 42),
            Parent = modal,
            ZIndex = 102,
        })
        AddCorner(header, Theme.Radius.Window)

        local titleLabel = Components.Label(header, title or "确认操作", 18, Theme.Colors.Text, true)
        titleLabel.Position = UDim2.fromOffset(0, 0)
        titleLabel.Size = UDim2.new(1, 0, 1, 0)
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.TextYAlignment = Enum.TextYAlignment.Center
        titleLabel.TextTransparency = 1
        titleLabel.ZIndex = 103

        local desc = Components.Label(modal, text or "确认执行？", 16, Theme.Colors.TextMuted, false)
        desc.Position = UDim2.fromOffset(24, 56)
        desc.Size = UDim2.new(1, -48, 0, 72)
        desc.TextWrapped = true
        desc.TextXAlignment = Enum.TextXAlignment.Center
        desc.TextTransparency = 1
        desc.ZIndex = 102

        local cancel = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Colors.Control,
            Position = UDim2.new(0.5, -57, 1, -64),
            Size = UDim2.fromOffset(101, 40),
            Text = "取消",
            TextSize = 16,
            TextColor3 = Theme.Colors.TextMuted,
            TextTransparency = 1,
            Parent = modal,
            ZIndex = 102,
        })
        AddCorner(cancel, Theme.Radius.Control)
        AddStroke(cancel)
        Components.Interaction(cancel, Theme.Colors.Control, Theme.Colors.ControlHover, Theme.Colors.AccentDim)

        local confirm = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Colors.AccentDim,
            Position = UDim2.new(0.5, 57, 1, -64),
            Size = UDim2.fromOffset(101, 40),
            Text = "确认",
            TextSize = 16,
            TextColor3 = Theme.Colors.Text,
            TextTransparency = 1,
            Parent = modal,
            ZIndex = 102,
        })
        AddCorner(confirm, Theme.Radius.Control)
        AddStroke(confirm, Theme.Colors.AccentSoft)
        Components.Interaction(confirm, Theme.Colors.AccentDim, Theme.Colors.AccentSoft, Theme.Colors.Accent)

        -- 拖动支持（像公告一样）
        UI.MakeDraggable(modal, header)

        local function close()
            local root = UI.ModalRoot
            if not root then
                return
            end
            UI.ModalRoot = nil
            Tween(overlay, { BackgroundTransparency = 1 }, Theme.Animation.Fast)
            Tween(modal, {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(459, 211),
            }, Theme.Animation.Fast)
            Tween(modalStroke, { Transparency = 1 }, Theme.Animation.Fast)
            Tween(titleLabel, { TextTransparency = 1 }, Theme.Animation.Fast)
            Tween(desc, { TextTransparency = 1 }, Theme.Animation.Fast)
            Tween(cancel, { TextTransparency = 1, BackgroundTransparency = 1 }, Theme.Animation.Fast)
            Tween(confirm, { TextTransparency = 1, BackgroundTransparency = 1 }, Theme.Animation.Fast)
            task.delay(Theme.Animation.Fast + 0.03, function()
                if root and root.Parent then
                    root:Destroy()
                end
            end)
        end

        cancel.Activated:Connect(close)
        overlay.Activated:Connect(close)
        confirm.Activated:Connect(function()
            close()
            if onConfirm then
                onConfirm()
            end
        end)

        Tween(overlay, { BackgroundTransparency = 0.45 }, Theme.Animation.Normal)
        Tween(modal, {
            BackgroundTransparency = 0,
            Size = UDim2.fromOffset(480, 227),
        }, Theme.Animation.Normal, Theme.Animation.EmphasisStyle)
        Tween(modalStroke, { Transparency = 0 }, Theme.Animation.Normal)
        Tween(titleLabel, { TextTransparency = 0 }, Theme.Animation.Normal)
        Tween(desc, { TextTransparency = 0 }, Theme.Animation.Normal)
        Tween(cancel, { TextTransparency = 0 }, Theme.Animation.Normal)
        Tween(confirm, { TextTransparency = 0 }, Theme.Animation.Normal)
    end

    function UI.ShowAnnouncement()
        if not UI.Main then
            return
        end

        if UI.Announcement and UI.Announcement.Parent then
            UI.Announcement:Destroy()
        end

        local mainSize = UI.Main.AbsoluteSize
        local width = math.max(math.floor(mainSize.X * 0.92), 550)
        local height = math.max(math.floor(mainSize.Y * 0.85), 350)

        local panel = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Colors.Window,
            BackgroundTransparency = 0,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(width, height),
            Parent = UI.Main,
            ZIndex = 70,
        })
        UI.Announcement = panel
        AddCorner(panel, Theme.Radius.Window)
        AddStroke(panel, Theme.Colors.StrokeStrong)

        local header = New("Frame", {
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.fromOffset(1, 1),
            Size = UDim2.new(1, -2, 0, 40),
            Parent = panel,
            ZIndex = 71,
        })
        AddCorner(header, Theme.Radius.Window)

        local title = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(0.98, 0, 1.25, 0),
            Text = AppConfig.AnnouncementTitle or "公告详情",
            TextColor3 = Theme.Colors.Text,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Font = Enum.Font.SourceSansBold,
            Parent = header,
            ZIndex = 72,
        })

        local close = Components.IconButton(header, "announcement.close", "X", "", function()
            if panel and panel.Parent then
                panel:Destroy()
            end
            if UI.Announcement == panel then
                UI.Announcement = nil
            end
        end)
        close.AnchorPoint = Vector2.new(1, 0.5)
        close.Position = UDim2.new(1, -8, 0.5, 0)
        close.Size = UDim2.fromOffset(28, 28)
        close.ZIndex = 72

        local body = New("ScrollingFrame", {
            BackgroundColor3 = Theme.Colors.Background,
            Position = UDim2.fromOffset(12, 52),
            Size = UDim2.new(1, -24, 1, -64),
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Colors.StrokeStrong,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Parent = panel,
            ZIndex = 71,
        })
        AddCorner(body, Theme.Radius.Panel)
        AddStroke(body, Theme.Colors.Stroke)

        local text = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -30, 0, 0),
            Position = UDim2.fromOffset(14, 10),
            Text = AppConfig.AnnouncementText or "",
            TextColor3 = Theme.Colors.TextMuted,
            TextSize = 15,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Top,
            Font = Theme.Font,
            Parent = body,
            ZIndex = 72,
        })

        local function updateCanvas()
            task.wait()
            if text and text.Parent then
                local h = Services.TextService:GetTextSize(text.Text, text.TextSize, text.Font, Vector2.new(text.AbsoluteSize.X, math.huge)).Y
                text.Size = UDim2.new(1, -30, 0, h)
                body.CanvasSize = UDim2.fromOffset(0, h + 24)
            end
        end

        task.spawn(updateCanvas)
        UI.Track(body:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvas))

        UI.MakeDraggable(panel, header)
    end

    function UI.MakeDraggable(frame, handle)
        local dragging = false
        local startMouse = nil
        local startPosition = nil
        local moved = false
        local dragInputType = nil

        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if frame == UI.ShowButton and UI.ShowButtonDragLock then return end
                dragging = true
                moved = false
                startMouse = input.Position
                startPosition = frame.Position
                dragInputType = input.UserInputType
            end
        end)

        UI.Track(Services.UserInputService.InputChanged:Connect(function(input)
            if not dragging then
                return
            end

            if dragInputType == Enum.UserInputType.Touch then
                if input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end
            elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end

            local delta = input.Position - startMouse
            if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
                moved = true
                if frame == UI.ShowButton then
                    UI.ShowButtonDragged = true
                end
            end
            local nextPosition = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
            frame.Position = ClampFrameToScreen(frame, nextPosition)
        end))

        UI.Track(Services.UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if frame == UI.ShowButton and not moved and startMouse then
                    local totalDelta = input.Position - startMouse
                    if math.abs(totalDelta.X) > 8 or math.abs(totalDelta.Y) > 8 then
                        moved = true
                        UI.ShowButtonDragged = true
                    end
                end
                if frame == UI.ShowButton and moved then
                    task.delay(0.08, function()
                        UI.ShowButtonDragged = false
                    end)
                end
                dragging = false
                dragInputType = nil
            end
        end))
    end

    function UI.BuildSidebar(parent)
        UI._sidebarVisualState = {}
        UI.Sidebar = New("ScrollingFrame", {
            BackgroundColor3 = Theme.Colors.Window,
            Position = UDim2.fromOffset(1, 42),
            Size = UDim2.new(0, 149, 1, -43),
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarThickness = 3,
            Parent = parent,
        })
        AddCorner(UI.Sidebar, Theme.Radius.Window)
        AddPadding(UI.Sidebar, 10, 10, 10, 10)

        local layout = New("UIListLayout", {
            Padding = UDim.new(0, 7),
            Parent = UI.Sidebar,
        })
        SetScrollCanvas(UI.Sidebar, layout, 28, "window")

        for _, page in ipairs(Pages.List) do
            local button = New("TextButton", {
                BackgroundColor3 = Theme.Colors.Window,
                Size = UDim2.new(1, 0, 0, 36),
                Text = "",
                Parent = UI.Sidebar,
            })
            AddCorner(button, Theme.Radius.Panel)
            AddStroke(button)
            Components.Interaction(
                button,
                function()
                    return page.id == State.CurrentPage and Theme.Colors.AccentDim or Theme.Colors.Window
                end,
                function()
                    return page.id == State.CurrentPage and Theme.Colors.AccentDim or Theme.Colors.Control
                end,
                Theme.Colors.AccentDim
            )
            local sideScale = New("UIScale", { Scale = 1, Parent = button })

            local name = Components.Label(button, page.title, 13, Theme.Colors.TextMuted, true)
            name.Name = "PageName"
            name.Position = UDim2.fromOffset(0, 0)
            name.Size = UDim2.new(1, 0, 1, 0)
            name.TextXAlignment = Enum.TextXAlignment.Center
            name.Visible = not UI.SidebarCollapsed

            button.MouseButton1Click:Connect(function()
                Tween(sideScale, { Scale = 0.95 }, Theme.Animation.Press)
                task.delay(Theme.Animation.Press + 0.04, function()
                    Tween(sideScale, { Scale = 1 }, Theme.Animation.Fast)
                end)
                UI.SetPage(page.id)
                State:AddLog("UI", "切换页面: " .. page.title, "sidebar." .. page.id)
            end)

            UI.SidebarButtons[page.id] = button
        end

        return layout
    end

    function UI.DestroyLivestream()
        if UI.Livestream then
            UI.Livestream:Destroy()
            UI.Livestream = nil
        end
    end

    function UI.UpdateLivestreamPos(cont)
        local c = cont or UI.Livestream
        if not c then return end
        local x = State.Sliders["settings.ui.livestream_x"] or 52
        local y = State.Sliders["settings.ui.livestream_y"] or -7
        c.Position = UDim2.new(x / 100, 0, y / 100, 10)
    end

    function UI.BuildLivestream()
        UI.DestroyLivestream()
        if not UI.RootGui then return end
        if not State.Toggles["settings.toggle.livestream"] then return end
        local container = Instance.new("Frame")
        container.Name = "TopColorfulText"
        container.Size = UDim2.new(0, 320, 0, 40)
        container.AnchorPoint = Vector2.new(0.5, 0)
        container.BackgroundTransparency = 1
        container.Parent = UI.RootGui
        container.ZIndex = 10
        local fs = State.Sliders["settings.ui.livestream_size"] or 20
        local gap = fs + 90
        container.Size = UDim2.new(0, gap * 3, 0, fs + 20)
        UI.UpdateLivestreamPos(container)
        local texts = {
            {text = "高级PS技术", color = Color3.fromRGB(255, 100, 100)},
            {text = "注意分辨",   color = Color3.fromRGB(100, 255, 100)},
            {text = "无不良引导", color = Color3.fromRGB(100, 100, 255)}
        }
        local xOffset = 0
        local lh = fs + 10
        for _, data in ipairs(texts) do
            local shadow = Instance.new("TextLabel")
            shadow.Size = UDim2.new(0, gap, 0, lh)
            shadow.Position = UDim2.new(0, xOffset + 2, 0, 2)
            shadow.BackgroundTransparency = 1
            shadow.Text = data.text
            shadow.TextColor3 = data.color
            shadow.TextTransparency = 0.5
            shadow.TextSize = fs
            shadow.Font = Enum.Font.SourceSansBold
            shadow.TextXAlignment = Enum.TextXAlignment.Left
            shadow.Parent = container
            local main = Instance.new("TextLabel")
            main.Size = UDim2.new(0, gap, 0, lh)
            main.Position = UDim2.new(0, xOffset, 0, 0)
            main.BackgroundTransparency = 1
            main.Text = data.text
            main.TextColor3 = Color3.new(1, 1, 1)
            main.TextSize = fs
            main.Font = Enum.Font.SourceSansBold
            main.TextXAlignment = Enum.TextXAlignment.Left
            main.Parent = container
            xOffset = xOffset + gap
        end
        UI.Livestream = container
    end


    function UI.UpdateBtnPos()
        if not UI.ShowButton then return end
        if State.Toggles["settings.toggle.custom_btn_pos"] then
            local x = State.Sliders["settings.ui.btn_pos_x"] or 90
            local y = State.Sliders["settings.ui.btn_pos_y"] or 50
            UI.ShowButton.Position = UDim2.new(1, -x, 0, y)
            UI.ShowButton.Visible = true
            UI.ShowButtonDragLock = true
        else
            if UI.Main and UI.Main.Visible then
                UI.ShowButton.Visible = false
            end
            UI.ShowButton.Position = UDim2.new(1, -90, 0, 50)
            UI.ShowButtonDragLock = false
        end
    end
    

    function UI.Build()
        UI.Destroy()
        RegisterPageKeys()

        local root = New("ScreenGui", {
            Name = AppConfig.GuiName,
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            Parent = UI.GetScreenParent(),
        })
        UI.RootGui = root
        UI.BuildToastRoot(root)

        local initialWindowSize = UI.GetBoundedWindowSize()
        local main = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Colors.Window,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(initialWindowSize.X, initialWindowSize.Y),
            Parent = root,
        })
        AddCorner(main, Theme.Radius.Window)
        AddStroke(main, Theme.Colors.StrokeStrong)
        main.ClipsDescendants = true
        UI.Main = main

        UI.Scale = New("UIScale", {
            Scale = State.DpiScale,
            Parent = main,
        })

        local topbar = New("Frame", {
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.fromOffset(1, 1),
            Size = UDim2.new(1, -2, 0, 41),
            Parent = main,
        })
        AddCorner(topbar, Theme.Radius.Window)

        local logo = New("ImageLabel", {
            BackgroundTransparency = 1,
            Image = "rbxassetid://104393405110206",
            ScaleType = Enum.ScaleType.Fit,
            Position = UDim2.fromOffset(10, 8),
            Size = UDim2.fromOffset(125, 26),
            Parent = topbar,
        })

        local topRight = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(1, -150, 0, 30),
            Parent = topbar,
        })

        -- Top-right controls: buttons anchored to right edge
        local topRightLayout = {
            MarqueePosition = UDim2.fromOffset(0, 0),
            MarqueeSize = UDim2.new(1, -75, 0, 30),
            MinimizePosition = UDim2.new(1, -68, 0, 1),
            MinimizeSize = UDim2.fromOffset(28, 28),
            ClosePosition = UDim2.new(1, -30, 0, 1),
            CloseSize = UDim2.fromOffset(28, 28),
        }

        local closeButton = Components.IconButton(topRight, "window.close", "X", "关闭窗口", function()
            UI.Confirm("确认退出", "确定要关闭此脚本吗？关闭之后需要重新执行脚本才能打开哦。", function()
                State:AddLog("UI", "关闭窗口", "window.close")
                -- 触发所有模块的全局停止回调（ESP/HUD/防护/核清理）
                for _, _fn in ipairs(_G._BFH_STOP_ALL) do pcall(_fn) end
                _G._BFH_STOP_ALL = {}
                UI.Destroy()
                -- 销毁标记，确保下次注入能正常初始化
                local _m = game:GetService("CoreGui"):FindFirstChild("_BFH_Marker")
                if _m then _m:Destroy() end
                -- 清理所有角色残留物理对象
                for _, _p in ipairs(game:GetService("Players"):GetPlayers()) do
                    if _p.Character then
                        for _, _c in ipairs(_p.Character:GetDescendants()) do
                            pcall(function()
                                if _c:IsA("BodyVelocity") or _c:IsA("BodyGyro") or _c:IsA("BodyPosition")
                                or _c:IsA("BodyAngularVelocity") or _c:IsA("RocketPropulsion")
                                or _c:IsA("BodyThrust") or _c:IsA("LineForce") or _c:IsA("Torque")
                                or _c:IsA("VectorForce") then
                                    _c:Destroy()
                                end
                            end)
                        end
                    end
                end
            end)
        end)
        closeButton.Position = topRightLayout.ClosePosition
        closeButton.Size = topRightLayout.CloseSize

        local minimizeButton = Components.IconButton(topRight, "window.minimize", "-", "最小化窗口", function()
            UI.SetVisible(false)
        end)
        minimizeButton.Position = topRightLayout.MinimizePosition
        minimizeButton.Size = topRightLayout.MinimizeSize

        local marquee = Components.Marquee(topRight, AppConfig.MarqueeText)
        marquee.Position = topRightLayout.MarqueePosition
        marquee.Size = topRightLayout.MarqueeSize

        UI.BuildSidebar(main)

        UI.Content = New("ScrollingFrame", {
            BackgroundColor3 = Theme.Colors.Background,
            Position = UDim2.fromOffset(150, 42),
            Size = UDim2.new(1, -150, 1, -42),
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarThickness = 3,
            Parent = main,
        })
        AddCorner(UI.Content, Theme.Radius.Window)

        UI.ShowButton = New("ImageButton", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Position = UDim2.new(1, -90, 0, 50),
            Size = UDim2.fromOffset(80, 40),
            Image = "rbxassetid://106447267002508",
            BackgroundTransparency = 1,
            ZIndex = 999,
            Visible = false,
            Parent = root,
        })
        AddCorner(UI.ShowButton, 8)
        UI.ShowButtonStroke = AddStroke(UI.ShowButton, Color3.fromRGB(255, 255, 255))
        UI.ShowScale = New("UIScale", {
            Scale = State.DpiScale,
            Parent = UI.ShowButton,
        })

        UI._showDragStart = nil
        UI.ShowButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                UI._showDragStart = input.Position
            end
        end)
        UI.ShowButton.InputEnded:Connect(function(input)
            if UI._showDragStart and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                local dx = math.abs(input.Position.X - UI._showDragStart.X)
                local dy = math.abs(input.Position.Y - UI._showDragStart.Y)
                if dx > 8 or dy > 8 then
                    UI.ShowButton.Active = false
                    task.delay(0.15, function() UI.ShowButton.Active = true end)
                end
                UI._showDragStart = nil
            end
        end)
        UI.ShowButton.Activated:Connect(function()
            Tween(UI.ShowButton, { Size = UDim2.fromOffset(72, 36) }, Theme.Animation.Press)
            task.delay(Theme.Animation.Press + 0.04, function()
                Tween(UI.ShowButton, { Size = UDim2.fromOffset(80, 40) }, Theme.Animation.Fast)
            end)
            UI.SetVisible(true)
        end)

        UI.MakeDraggable(main, topbar)
        UI.MakeDraggable(UI.ShowButton, UI.ShowButton)
        UI.Track(Services.UserInputService.InputBegan:Connect(function(input, processed)
            if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end

            local toggleKeyName = State.Keybinds["settings.keybind.toggle_ui"] or "RightShift"
            if input.KeyCode.Name == toggleKeyName then
                UI.SetVisible(not (UI.Main and UI.Main.Visible))
            end
        end))
        UI.Track(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            UI.ScheduleApplyWindowBounds()
        end))

        UI.SetPage(AppConfig.DefaultPage)
        task.defer(function()
            UI.ShowAnnouncement()
        end)
        UI.BuildLivestream()
        UI.UpdateBtnPos()

        -- 右侧展开按钮 + 侧边面板
        UI.QuickExpanded = false
        UI.QuickPanel = nil

        local screenH = root.AbsoluteSize.Y
        local panelY = UDim.new(0.25, 0)

        local quickBtn = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.new(1, -8, 0.14, 0),
            Size = UDim2.new(0, 28, 0, 44),
            Text = ">",
            TextSize = 14,
            TextColor3 = Theme.Colors.TextMuted,
            Font = Theme.FontBold,
            Parent = root,
            ZIndex = 95,
        })
        AddCorner(quickBtn, Theme.Radius.Window)
        AddStroke(quickBtn, Theme.Colors.StrokeStrong)

        local quickPanel = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = Theme.Colors.PanelDeep,
            Position = UDim2.new(1, 260, 0.25, 0),
            Size = UDim2.new(0, 200, 0.5, 0),
            Visible = false,
            Parent = root,
            ZIndex = 94,
        })
        AddCorner(quickPanel, Theme.Radius.Window)
        AddStroke(quickPanel, Theme.Colors.StrokeStrong)
        UI.QuickPanel = quickPanel

        quickBtn.MouseButton1Click:Connect(function()
            UI.QuickExpanded = not UI.QuickExpanded
            if UI.QuickExpanded then
                quickBtn.Text = "<"
                quickPanel.Visible = true
                UI.RefreshQuickPanel()
                Tween(quickPanel, {
                    Position = UDim2.new(1, -8, 0.25, 0),
                }, 0.35, Enum.EasingStyle.Quad)
            else
                quickBtn.Text = ">"
                Tween(quickPanel, {
                    Position = UDim2.new(1, 260, 0.25, 0),
                }, 0.3, Enum.EasingStyle.Quad)
                task.delay(0.32, function()
                    if not UI.QuickExpanded then quickPanel.Visible = false end
                end)
            end
        end)

        function UI._renderPanel(panel)
            -- 保持 ScrollingFrame 不销毁，避免滚动位置丢失
            local sf = panel:FindFirstChildOfClass("ScrollingFrame")
            if not sf then
                sf = New("ScrollingFrame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    CanvasSize = UDim2.fromOffset(0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollBarThickness = 0,
                    ScrollingDirection = Enum.ScrollingDirection.Y,
                    Parent = panel,
                    ZIndex = 97,
                })
                local layout = New("UIListLayout", {
                    Padding = UDim.new(0, 4),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = sf,
                })
            else
                for _, c in ipairs(sf:GetChildren()) do
                    if not c:IsA("UIListLayout") then c:Destroy() end
                end
            end

            local layout = sf:FindFirstChildOfClass("UIListLayout")

            for _, key in ipairs(State.FavoriteOrder) do
                if State.Favorites[key] then
                local meta = Registry.Meta[key]
                if meta and meta.Type == "toggle" then
                    local title = meta.Title or key
                    local val = State.Toggles[key] or false
                    local row = New("TextButton", {
                        BackgroundColor3 = Theme.Colors.Control,
                        Size = UDim2.new(1, 0, 0, 40),
                        Text = "",
                        Parent = sf,
                        ZIndex = 98,
                    })
                    AddCorner(row, Theme.Radius.Control)

                    local lbl = New("TextLabel", {
                        BackgroundTransparency = 1,
                        AnchorPoint = Vector2.new(0, 0.5),
                        Size = UDim2.new(1, -40, 0, 16),
                        Position = UDim2.new(0, 8, 0.5, 0),
                        Text = title,
                        TextColor3 = Theme.Colors.TextMuted,
                        TextSize = 12,
                        Font = Theme.FontBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Parent = row,
                        ZIndex = 99,
                    })

                    local track = New("Frame", {
                        AnchorPoint = Vector2.new(1, 0.5),
                        BackgroundColor3 = val and Theme.Colors.Accent or Theme.Colors.ToggleOff,
                        Position = UDim2.new(1, -6, 0.5, 0),
                        Size = UDim2.fromOffset(28, 14),
                        Parent = row,
                        ZIndex = 99,
                    })
                    AddCorner(track, Theme.Radius.Pill)
                    local knob = New("Frame", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Theme.Colors.Text,
                        Position = val and UDim2.new(1, -7, 0.5, 0) or UDim2.new(0, 7, 0.5, 0),
                        Size = UDim2.fromOffset(val and 13 or 12, val and 13 or 12),
                        Parent = track,
                        ZIndex = 100,
                    })
                    AddCorner(knob, Theme.Radius.Pill)

                    row.MouseButton1Click:Connect(function()
                        local nv = not State.Toggles[key]
                        State:Set("toggle", key, nv)
                        local ctrl = State.Controls[key]
                        if ctrl and ctrl.SetValue then
                            ctrl.SetValue(nv, true)  -- silent，下方统一触发 onChanged
                        end
                        -- 页面未渲染时 control 为 nil，直接从缓存 meta 调 onChanged
                        local _meta = Registry.Meta[key]
                        if _meta and _meta.Item and _meta.Item.onChanged then
                            pcall(_meta.Item.onChanged, nv)
                        end
                        track.BackgroundColor3 = nv and Theme.Colors.Accent or Theme.Colors.ToggleOff
                        Tween(knob, {
                            Position = nv and UDim2.new(1, -7, 0.5, 0) or UDim2.new(0, 7, 0.5, 0),
                            Size = UDim2.fromOffset(nv and 13 or 12, nv and 13 or 12),
                        }, 0.15)
                    end)
                elseif meta.Type == "slider" then
                    local title = meta.Title or key
                    local val = State.Sliders[key] or 0
                    local mn = meta.Min or 0
                    local mx = meta.Max or 100
                    local stp = meta.Step or 1
                    if mx < mn then mn, mx = mx, mn end
                    local function qNormalize(v)
                        local nv = math.clamp(v, mn, mx)
                        nv = math.floor(nv / stp + 0.5) * stp
                        return math.clamp(nv, mn, mx)
                    end

                    local row = New("Frame", {
                        BackgroundColor3 = Theme.Colors.Control,
                        Size = UDim2.new(1, 0, 0, 44),
                        Parent = sf,
                        ZIndex = 98,
                    })
                    AddCorner(row, Theme.Radius.Control)

                    local lbl = New("TextLabel", {
                        BackgroundTransparency = 1,
                        AnchorPoint = Vector2.new(0, 0.5),
                        Size = UDim2.new(1, -44, 0, 16),
                        Position = UDim2.new(0, 8, 0.5, -5),
                        Text = title,
                        TextColor3 = Theme.Colors.TextMuted,
                        TextSize = 12,
                        Font = Theme.FontBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Parent = row,
                        ZIndex = 99,
                    })
                    local valLabel = New("TextLabel", {
                        BackgroundTransparency = 1,
                        AnchorPoint = Vector2.new(1, 0.5),
                        Size = UDim2.fromOffset(38, 16),
                        Position = UDim2.new(1, -8, 0.5, -5),
                        Text = tostring(val),
                        TextColor3 = Theme.Colors.TextMuted,
                        TextSize = 11,
                        Font = Theme.FontBold,
                        TextXAlignment = Enum.TextXAlignment.Right,
                        Parent = row,
                        ZIndex = 99,
                    })

                    local pct = math.clamp((val - mn) / math.max(mx - mn, 1), 0, 1)
                    local bar = New("TextButton", {
                        BackgroundColor3 = Theme.Colors.PanelDeep,
                        Position = UDim2.fromOffset(8, 26),
                        Size = UDim2.new(1, -16, 0, 5),
                        Text = "",
                        Parent = row,
                        ZIndex = 99,
                    })
                    AddCorner(bar, Theme.Radius.Pill)
                    local fill = New("Frame", {
                        BackgroundColor3 = Theme.Colors.Accent,
                        Size = UDim2.fromScale(pct, 1),
                        Parent = bar,
                        ZIndex = 100,
                    })
                    AddCorner(fill, Theme.Radius.Pill)
                    local qKnob = New("Frame", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Theme.Colors.Text,
                        Size = UDim2.fromOffset(8, 8),
                        Position = UDim2.fromScale(pct, 0.5),
                        Parent = bar,
                        ZIndex = 101,
                    })
                    AddCorner(qKnob, Theme.Radius.Pill)
                    -- 拖动支持（捕获手指，绝对位置，多指不串）
                    local qDrag, qChanged, qDragInput = false, false, nil
                    local function qSetFromInput(input)
                        local barAbsX = bar.AbsolutePosition.X
                        local barW = math.max(bar.AbsoluteSize.X, 1)
                        local clickPercent = math.clamp((input.Position.X - barAbsX) / barW, 0, 1)
                        local nv = qNormalize(mn + (mx - mn) * clickPercent)
                        local np = math.clamp((nv - mn) / math.max(mx - mn, 1), 0, 1)
                        local prevVal = State.Sliders[key]
                        fill.Size = UDim2.fromScale(np, 1)
                        qKnob.Position = UDim2.fromScale(np, 0.5)
                        valLabel.Text = tostring(nv)
                        State:Set("slider", key, nv)
                        local ctrl = State.Controls[key]; if ctrl and ctrl.SetValue then ctrl.SetValue(nv, true, false) end
                        if nv ~= prevVal then
                            State:AddLog("SLIDER", title .. " = " .. tostring(nv), key)
                        end
                        qChanged = true
                    end
                    bar.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            if Components.__sliderLock then return end
                            qDrag = true; qDragInput = input  -- 只跟随这根手指
                            Components.__sliderLock = true; Components.__quickSliderLock = true
                            qSetFromInput(input)
                        end
                    end)
                    local tC1 = game:GetService("UserInputService").InputChanged:Connect(function(input)
                        if not qDrag or input ~= qDragInput then return end
                        qSetFromInput(input)
                    end)
                    local tC2 = game:GetService("UserInputService").InputEnded:Connect(function(input)
                        if input ~= qDragInput then return end
                        qDrag = false; qChanged = false; qDragInput = nil
                        Components.__sliderLock = nil; Components.__quickSliderLock = nil
                        UI.RefreshQuickPanel()
                    end)
                    table.insert(UI.QuickConns, tC1); table.insert(UI.QuickConns, tC2)
                end
                end
            end
            -- 无收藏时的空状态提示
            if State:CountFavorites() == 0 then
                local emptyLabel = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -16, 0, 60),
                    Position = UDim2.fromOffset(8, 20),
                    Text = "当前未添加收藏按钮，请前往主UI点击五角星收藏",
                    TextColor3 = Theme.Colors.TextDim,
                    TextSize = 13,
                    Font = Theme.Font,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Center,
                    Parent = sf,
                    ZIndex = 99,
                })
            end
        end

        function UI.RefreshQuickPanel()
            if UI.QuickConns then for _, c in ipairs(UI.QuickConns) do pcall(c.Disconnect, c) end end
            UI.QuickConns = {}
            if UI.QuickPanel then UI._renderPanel(UI.QuickPanel) end
        end
        function UI.ScheduleQuickPanel()
            if UI.QuickPanelPending then return end
            UI.QuickPanelPending = true
            task.delay(0.08, function()
                UI.QuickPanelPending = false
                if UI.QuickPanel then UI.RefreshQuickPanel() end
            end)
        end

        -- 收藏变更时刷新
        local _origSetFav = State.SetFavorite
        State.SetFavorite = function(self, key, enabled)
            local previous = self:IsFavorite(key)
            _origSetFav(self, key, enabled)
            if previous ~= (enabled == true) then
                UI.ScheduleQuickPanel()
            end
        end
        -- 开关/滑块值变更时同步刷新快捷栏（拖动中跳过，避免重建断连）
        local _origSet = State.Set
        State.Set = function(self, kind, key, value)
            local previous = self:Get(kind, key, nil)
            _origSet(self, kind, key, value)
            if previous == value then
                return
            end
            if kind == "slider" and not Components.__quickSliderLock then
                UI.ScheduleQuickPanel()
            elseif kind == "toggle" and not Components.__sliderLock then
                UI.ScheduleQuickPanel()
            end
        end

        State:AddLog("UI", "框架启动: " .. AppConfig.Version, "app.start")
        SFX.PlayWelcome()
    end

    local previous = rawget(_G, "BanFengHeUIFramework")
	--=================================================================
	-- 大不列颠超入脚本 · 页面定义（声明式，交给秋容UI框架渲染）
	--=================================================================
	local function CFG(path, fallback)
		local cur = cfg
		for part in string.gmatch(path, "[^.]+") do
			if type(cur) ~= "table" then return fallback end
			cur = cur[part]
		end
		if cur == nil then return fallback end
		return cur
	end

	local function SET(path, value)
		local parts = {}
		for p in string.gmatch(path, "[^.]+") do parts[#parts + 1] = p end
		if #parts == 0 then return end
		local cur = cfg
		for i = 1, #parts - 1 do
			cur = cur[parts[i]]
			if type(cur) ~= "table" then return end
		end
		cur[parts[#parts]] = value
		cfgTouch()
		safe(guardRefresh)
	end

	local function prodOpts()
		local out = {}
		for _, p in ipairs(productList()) do out[#out + 1] = Option(tostring(p), tostring(p)) end
		return out
	end
	local function roleOpts()
		local out, seen = {}, {}
		for _, r in ipairs((G.jobs and G.jobs.roles) or {}) do
			local id = tostring(r.id or r.name or "")
			if id ~= "" and not seen[id] then seen[id] = true out[#out + 1] = Option(id, id) end
		end
		for k in pairs((G.employees and G.employees.slots) or {}) do
			local id = tostring(k)
			if not seen[id] then seen[id] = true out[#out + 1] = Option(id, id) end
		end
		if #out == 0 then
			for _, id in ipairs({ "WarehouseWorker", "Manager", "MarketingSpecialist",
				"HrSpecialist", "ForkliftDriver", "FactoryWorker" }) do
				out[#out + 1] = Option(id, id)
			end
		end
		table.sort(out, function(a, b) return a.value < b.value end)
		return out
	end
	local function info(msg, key) safe(function() State:AddLog("INFO", tostring(msg), key or "qr") end) end

	-- ---- 实时状态行：value 传函数，渲染时求值；同时支持当前页实时推送 ----
	local LIVE = {}
	local function ST(key, title, desc)
		return {
			type = "status", key = key, title = title, desc = desc, internal = true,
			value = function()
				local f = LIVE[key]
				if not f then return "—" end
				local ok, v = pcall(f)
				return ok and tostring(v) or "读取失败"
			end,
		}
	end

	LIVE["qr.about.plot"]     = function() return tostring(plotName() or "未知") end
	LIVE["qr.pipe.phase"]     = function() return tostring(Pipe.phase) .. " · " .. tostring(Pipe.detail) end
	LIVE["qr.pipe.order"]     = function() return Pipe.orderId and ("#" .. tostring(Pipe.orderId)) or "无" end
	LIVE["qr.pipe.carry"]     = function()
		local c = carrying()
		return c == "none" and "空手" or (c == "labeled" and "手持成品箱" or "手持原始包裹")
	end
	LIVE["qr.pipe.done"]      = function() return tostring(Pipe.completed) .. " 单" end
	LIVE["qr.ac.why"]         = function() return (Pipe.acWhy ~= "" and Pipe.acWhy) or "可接单" end
	LIVE["qr.ac.cand"]        = function() return tostring(#acCandidates()) .. " 张" end
	LIVE["qr.restock.last"]   = function() return tostring(Rst.last or "—") end
	LIVE["qr.restock.stock"]  = function()
		return string.format("%d / %s（库存 %d）", tonumber(S.warehouse) or 0,
			tostring(S.warehouseCapacity or "—"), stockOf(nil))
	end
	LIVE["qr.bp.last"]        = function() return tostring(BuyProd.last or "—") end
	LIVE["qr.hire.last"]      = function() return tostring(Hire.last or "—") end
	LIVE["qr.hire.count"]     = function() return tostring(Hire.count) .. " 人" end
	LIVE["qr.ad.last"]        = function() return tostring(Ad.last or "—") end
	LIVE["qr.ad.published"]   = function() return tostring(Ad.published) .. " 次" end
	LIVE["qr.ops.claimlast"]  = function() return tostring(Ops.last["领取"] or "—") end
	LIVE["qr.ops.staff"]      = function()
		return string.format("休假 %s ｜ 训练 %s", tostring(Ops.last["休假"] or "—"), tostring(Ops.last["训练"] or "—"))
	end
	LIVE["qr.ops.oth"]        = function()
		return string.format("研究 %s ｜ 合同 %s", tostring(Ops.last["研究"] or "—"), tostring(Ops.last["合同"] or "—"))
	end
	LIVE["qr.ai.runs"]        = function() return string.format("第 %d 轮 · %s", AI.runs, tostring(cfg.ai.note or "—")) end
	LIVE["qr.ai.chg"]         = function()
		return #AI.changes > 0 and AI.changes[#AI.changes] or "（暂无调整）"
	end
	LIVE["qr.conv.state"]     = function()
		local b = {}
		for _, x in ipairs(Conv.belts or {}) do
			b[#b + 1] = string.format("%s Lv%d/%d%s", tostring(x.name), x.level, x.maxLevel,
				x.enabled and "(可升级)" or "")
		end
		return (#b > 0 and table.concat(b, " ｜ ") or "未检测到") ..
			string.format("  最高Lv%d 平均%.1f", Conv.level, Conv.avgLevel or 0)
	end
	LIVE["qr.conv.last"]      = function() return tostring(Conv.last or "—") end
	LIVE["qr.dash.cash"]      = function() return fmt(S.cash) end
	LIVE["qr.dash.gems"]      = function() return fmt(S.gems) end
	LIVE["qr.dash.stock"]     = function()
		return string.format("%d / %s", tonumber(S.warehouse) or 0, tostring(S.warehouseCapacity or "—"))
	end
	LIVE["qr.dash.orders"]    = function()
		return string.format("待接 %d ｜ 履约 %d/%d ｜ 完成 %d",
			countStatus("New"), activeCount(), maxActive(), countStatus("Completed"))
	end
	LIVE["qr.dash.inflight"]  = function()
		local t = {}
		for _, o in pairs(S.orders or {}) do
			if FULFIL[tostring(o.status)] then
				t[#t + 1] = string.format("#%s %s", tostring(o.id), tostring(o.status))
			end
		end
		return #t > 0 and table.concat(t, " ｜ ") or "无在飞订单"
	end
	LIVE["qr.dash.stat"]      = function()
		return string.format("会话 %d 分 ｜ 完成 %d 单 ｜ %s",
			math.floor((os.clock() - Stat.startAt) / 60), Pipe.completed,
			Guard.blocked and "保护模式中" or "正常")
	end
	LIVE["qr.dash.econ"]      = function()
		return string.format("毛收入 %s ｜ 约 %s/小时 ｜ 单均 %s",
			fmt(Stat.gain), fmt(Stat.gain / statHours()),
			Pipe.completed > 0 and fmt(Stat.gain / math.max(1, Pipe.completed)) or "—")
	end
	LIVE["qr.dash.fail"]      = function()
		local tot, bad = Exe.stats.total, Exe.stats.fail
		if tot <= 0 then return "暂无样本" end
		return string.format("确认 %d 次 · 失败率 %.0f%%", tot, bad / tot * 100)
	end
	LIVE["qr.dash.viral"]     = function()
		local v = G.viral
		local names = {}
		for _, x in ipairs((v and v.produkty) or {}) do names[#names + 1] = tostring(x.nazwa or x.id) end
		if #names == 0 then return "无数据（打开一次爆款面板）" end
		local vp = viralProduct()
		return table.concat(names, " / ") .. (vp and ("　可投：" .. vp) or "　（均未解锁）")
	end
	LIVE["qr.guard.state"]    = function()
		return Guard.blocked and string.format("刹车中（现金 %s < %s）", fmt(S.cash), fmt(cfg.guard.cashFloor)) or "正常"
	end
	LIVE["qr.sched.quests"]   = function()
		local f = Sched.focus
		return (#f.texts > 0) and table.concat(f.texts, " ｜ ") or "无未完成任务"
	end
	LIVE["qr.sched.target"]   = function()
		local t = {}
		for pid in pairs(Sched.prefProducts or {}) do t[#t + 1] = pid end
		if #t > 0 then return "优先生产：" .. table.concat(t, " / ") end
		if not G.contract then return "无数据" end
		return G.contract.hasOffice and "有办公室，暂无可接合同" or "未建办公室，合同未开放"
	end
	LIVE["qr.maint.gates"]    = function()
		local t = {}
		for _, msg in pairs(Sched.gated or {}) do t[#t + 1] = tostring(msg) end
		return #t > 0 and table.concat(t, " ｜ ") or "无被门禁的接口"
	end
	LIVE["qr.tool.env"]       = function()
		return string.format("剪贴板 %s ｜ 文件 %s ｜ HTTP %s",
			setclipboard and "有" or "无", writefile and "有" or "无",
			(game.HttpGet and "有" or "无"))
	end
	LIVE["qr.tool.hints"]     = function() return tostring(#Prompt.list) .. " 个可用提示点" end


	--================================================= 1 脚本详细（置顶）
	AddPage({
		id = "about", title = "脚本详细", icon = "A", subtitle = "作者 / 版本 / 交流群",
		sections = {
			{ title = "交流群", items = {
				{ type = "button", key = "qr.about.qq", title = "QQ群（点击复制）",
				  desc = "群号 1105244454 · 点一下直接复制到剪贴板", actionText = "复制", internal = true,
				  onChanged = function()
					if not setclipboard then info("群号 1105244454（当前执行器不支持剪贴板）", "qr.about.qq") return end
					local ok = safe(function() setclipboard("1105244454") end)
					info(ok and "群号 1105244454 已复制" or "复制失败，请手动记下 1105244454", "qr.about.qq")
				  end },
			} },
			{ title = "关于", items = {
				{ type = "status", key = "qr.about.author", title = "作者", desc = "合作:b站大不列颠超入", value = "合作:b站大不列颠超入", internal = true },
				{ type = "status", key = "qr.about.ver", title = "版本", desc = "适配游戏：代发货大亨", value = "正式版 1.0.0", internal = true },
				ST("qr.about.plot", "当前地块", "脚本自动跟随"),
			} },
			{ title = "核心原理", items = {
				{ type = "collapsible", key = "qr.doc.principle", title = "为什么稳（点开看）", desc = "订单驱动 / 微传送 / 传送带节奏", items = {
					ST("qr.doc.p1", "订单驱动", "不跑固定步骤，只做当前状态该做的那件事"),
					ST("qr.doc.p2", "微传送", "纯远程与位置无关；需校验距离的动作必须人到位置"),
					ST("qr.doc.p3", "等确认", "触发后停在原地等状态确认，不立刻回位"),
					ST("qr.doc.p4", "成品箱", "只认服务端置的 Enabled，箱子到带末才取"),
				} },
			} },
			{ title = "功能清单", items = {
				{ type = "collapsible", key = "qr.doc.features", title = "全部功能说明", desc = "点开查看每个模块做什么", items = {
					{ type = "list", key = "qr.f1", title = "订单流水线", desc = "接单→取原包→上带→等打包→取成品→交快递→等结算", badge = "核心", internal = true },
					{ type = "list", key = "qr.f2", title = "自动接单", desc = "价格区间 / 爆款 / 白黑名单 / 优先级 / 并发", badge = "自动化", internal = true },
					{ type = "list", key = "qr.f3", title = "自动补货", desc = "阈值与批量自动买原材料，带现金下限保护", badge = "自动化", internal = true },
					{ type = "list", key = "qr.f4", title = "自动购买商品", desc = "自动解锁未拥有的商品", badge = "自动化", internal = true },
					{ type = "list", key = "qr.f5", title = "自动招聘", desc = "按岗位/等级/薪资挑人，可重掷候选", badge = "自动化", internal = true },
					{ type = "list", key = "qr.f6", title = "自动广告", desc = "录制→等完成→投放，支持爆款联动", badge = "自动化", internal = true },
					{ type = "list", key = "qr.f7", title = "自动运营", desc = "领取 / 休假 / 训练 / 研究 / 合同", badge = "自动化", internal = true },
					{ type = "list", key = "qr.f8", title = "AI 调参", desc = "按实时数据自动改时序 / 补货 / 并发 / 预算", badge = "智能", internal = true },
					{ type = "list", key = "qr.f9", title = "传送带", desc = "读条数与等级（最多 3 条），可自动升级", badge = "后期", internal = true },
					{ type = "list", key = "qr.f10", title = "保护模式", desc = "低现金自动刹车，停掉所有花钱模块", badge = "安全", internal = true },
				} },
			} },
		},
	})

	--================================================= 2 流水线
	AddPage({
		id = "pipe", title = "流水线", icon = "P", subtitle = "订单驱动主引擎",
		sections = {
			{ title = "总开关", items = {
				{ type = "toggle", key = "qr.pipe.on", title = "订单流水线", desc = "开启后自动接单并完成全流程",
				  default = CFG("pipe.on", false), internal = true, onChanged = function(v) SET("pipe.on", v) info(v and "流水线已启用" or "流水线已停止", "qr.pipe.on") end },
				{ type = "toggle", key = "qr.pipe.restore", title = "触发后回原位", desc = "动作确认后把角色放回原处",
				  default = CFG("pipe.restore", true), internal = true, onChanged = function(v) SET("pipe.restore", v) end },
				{ type = "toggle", key = "qr.pipe.boost", title = "放大交互距离", desc = "拉大提示点交互距离并关闭视线校验",
				  default = CFG("pipe.boost", true), internal = true, onChanged = function(v) SET("pipe.boost", v) end },
				{ type = "toggle", key = "qr.pipe.autorestock", title = "缺货自动买货", desc = "仓库没货卡住时自动买一次（会花钱）",
				  default = CFG("pipe.autoRestock", true), internal = true, onChanged = function(v) SET("pipe.autoRestock", v) end },
			} },
			{ title = "实时阶段", items = {
				ST("qr.pipe.phase", "当前阶段", "正在做什么"),
				ST("qr.pipe.order", "当前订单", "正在处理的订单号"),
				ST("qr.pipe.carry", "搬运状态", "空手 / 原始包裹 / 成品箱"),
				{ type = "status", key = "qr.pipe.done", title = "已完成", desc = "本次会话完成单数", value = "0", internal = true },
			} },
			{ title = "时序（实机标定，别乱调）", items = {
				{ type = "slider", key = "qr.pipe.prewait", title = "传送前等待", desc = "闪过去到触发之间的等待，运行时下限 0.18s",
				  min = 0.10, max = 0.60, step = 0.02, default = CFG("pipe.preWait", 0.3), format = "%.2fs",
				  onChanged = function(v) SET("pipe.preWait", v) end },
				{ type = "slider", key = "qr.pipe.postwait", title = "回位前等待", desc = "确认后再等多久回原位，别调太小",
				  min = 0.05, max = 0.80, step = 0.05, default = CFG("pipe.postWait", 0.3), format = "%.2fs",
				  onChanged = function(v) SET("pipe.postWait", v) end },
				{ type = "slider", key = "qr.pipe.gap", title = "动作间隔", desc = "两次触发之间的最小间隔",
				  min = 0.05, max = 1.50, step = 0.05, default = CFG("pipe.gap", 0.3), format = "%.2fs",
				  onChanged = function(v) SET("pipe.gap", v) end },
				{ type = "slider", key = "qr.pipe.tpheight", title = "微传送抬高", desc = "闪现时抬高多少，太低会卡进模型",
				  min = 1, max = 8, step = 0.5, default = CFG("pipe.tpHeight", 2.5), format = "%.1f格",
				  onChanged = function(v) SET("pipe.tpHeight", v) end },
			} },
			{ title = "手动单步", items = {
				{ type = "button", key = "qr.step.accept", title = "① 接一单", desc = "按当前筛选条件接一张新订单", actionText = "执行", internal = true,
				  onChanged = function()
					local c = acCandidates()
					if #c == 0 then info("没有符合条件的新单", "qr.step.accept") return end
					acceptOrder(c[1].id) info("已接单 #" .. tostring(c[1].id), "qr.step.accept")
				  end },
				{ type = "button", key = "qr.step.pick", title = "② 取原始包裹", desc = "传送到仓库并把原始包裹拿到手", actionText = "执行", internal = true,
				  onChanged = function() info(pickRaw() and "已触发取货" or "仓库无可用包裹", "qr.step.pick") end },
				{ type = "button", key = "qr.step.belt", title = "③ 放上传送带", desc = "把手里的原始包裹交给传送带", actionText = "执行", internal = true,
				  onChanged = function() info(putOnBelt() and "已触发上带" or "没找到传送带提示点", "qr.step.belt") end },
				{ type = "button", key = "qr.step.done", title = "④ 取成品箱", desc = "成品箱到达带末后取走", actionText = "执行", internal = true,
				  onChanged = function()
					local p = doneBoxPrompt()
					if not p then info("成品箱还没到传送带末端", "qr.step.done") return end
					actPrompt(p, function() return carrying() == "labeled" end) info("已触发取成品", "qr.step.done")
				  end },
				{ type = "button", key = "qr.step.courier", title = "⑤ 交给快递员", desc = "把手里的成品箱交给快递员", actionText = "执行", internal = true,
				  onChanged = function()
					local p = findPrompt("Leave for courier", isInPlot)
					if not p then info("没找到快递员提示点", "qr.step.courier") return end
					actPrompt(p, function() return carrying() ~= "labeled" end) info("已触发交件", "qr.step.courier")
				  end },
			} },
		},
	})

	--================================================= 3 自动接单
	AddPage({
		id = "ac", title = "自动接单", icon = "C", subtitle = "筛选 / 优先级 / 并发",
		sections = {
			{ title = "开关", items = {
				{ type = "toggle", key = "qr.ac.on", title = "启用自动接单", desc = "独立于流水线开关，关掉流水线也能接单",
				  default = CFG("ac.on", false), internal = true, onChanged = function(v) SET("ac.on", v) info(v and "自动接单已启用" or "自动接单已停止", "qr.ac.on") end },
				ST("qr.ac.why", "闸门状态", "为什么没接单"),
				{ type = "status", key = "qr.ac.cand", title = "可接数量", desc = "符合筛选条件的新单数", value = "0", internal = true },
			} },
			{ title = "并发与节奏", items = {
				{ type = "slider", key = "qr.ac.max", title = "接单并发", desc = "同时进行的订单上限（不超过游戏允许的履约位）",
				  min = 1, max = 5, step = 1, default = CFG("ac.maxActive", 1), format = "%d单",
				  onChanged = function(v) SET("ac.maxActive", v) end },
				{ type = "slider", key = "qr.ac.interval", title = "接单间隔", desc = "两次接单之间的最小间隔",
				  min = 0.2, max = 10, step = 0.2, default = CFG("ac.interval", 0.8), format = "%.1fs",
				  onChanged = function(v) SET("ac.interval", v) end },
				{ type = "dropdown", key = "qr.ac.priority", title = "优先级", desc = "多张候选订单时的排序方式",
				  default = CFG("ac.priority", "价格最高优先"),
				  options = { Option("价格最高优先", "价格最高优先"), Option("爆款优先", "爆款优先"), Option("最早发布优先", "最早发布优先") },
				  onChanged = function(v) SET("ac.priority", v) end },
			} },
			{ title = "筛选条件", items = {
				{ type = "toggle", key = "qr.ac.viral", title = "只要爆款", desc = "只接当期爆款商品的订单",
				  default = CFG("ac.viralOnly", false), internal = true, onChanged = function(v) SET("ac.viralOnly", v) end },
				{ type = "slider", key = "qr.ac.minprice", title = "最低价", desc = "低于此价不接（0 = 不限）",
				  min = 0, max = 5000, step = 5, default = CFG("ac.minPrice", 0), format = "%d$",
				  onChanged = function(v) SET("ac.minPrice", v) end },
				{ type = "slider", key = "qr.ac.maxprice", title = "最高价", desc = "高于此价不接（0 = 不限）",
				  min = 0, max = 5000, step = 5, default = CFG("ac.maxPrice", 0), format = "%d$",
				  onChanged = function(v) SET("ac.maxPrice", v) end },
				{ type = "toggle", key = "qr.ac.usewhite", title = "启用白名单", desc = "只接白名单里的商品",
				  default = CFG("ac.useWhite", false), internal = true, onChanged = function(v) SET("ac.useWhite", v) end },
				{ type = "multi", key = "qr.ac.white", title = "商品白名单", desc = "默认空 = 全部；多选",
				  default = CFG("ac.white", {}), options = prodOpts(),
				  onChanged = function(v) SET("ac.white", v) end },
				{ type = "multi", key = "qr.ac.black", title = "商品黑名单", desc = "多选；优先级高于白名单",
				  default = CFG("ac.black", {}), options = prodOpts(),
				  onChanged = function(v) SET("ac.black", v) end },
			} },
		},
	})

	--================================================= 4 补货
	AddPage({
		id = "restock", title = "补货", icon = "R", subtitle = "原材料自动采购",
		sections = {
			{ title = "开关", items = {
				{ type = "toggle", key = "qr.restock.on", title = "自动补货", desc = "低于阈值自动买原材料",
				  default = CFG("restock.on", false), internal = true, onChanged = function(v) SET("restock.on", v) info(v and "自动补货已启用" or "自动补货已停止", "qr.restock.on") end },
				ST("qr.restock.last", "最近一次", "补货结果"),
				ST("qr.restock.stock", "库存 / 容量", "当前库存与容量"),
			} },
			{ title = "策略", items = {
				{ type = "dropdown", key = "qr.restock.mode", title = "补货产品来源", desc = "决定补哪种原材料",
				  default = CFG("restock.mode", "跟随进行中订单"),
				  options = { Option("跟随进行中订单", "跟随进行中订单"), Option("跟随当前产品", "跟随当前产品"), Option("指定产品", "指定产品") },
				  onChanged = function(v) SET("restock.mode", v) end },
				{ type = "dropdown", key = "qr.restock.product", title = "指定产品", desc = "仅在来源 = 指定产品 时生效",
				  default = CFG("restock.product", ""), options = prodOpts(),
				  onChanged = function(v) SET("restock.product", v) end },
				{ type = "slider", key = "qr.restock.low", title = "补货阈值", desc = "库存低于此值就补",
				  min = 1, max = 30, step = 1, default = CFG("restock.low", 2), format = "%d件",
				  onChanged = function(v) SET("restock.low", v) end },
				{ type = "slider", key = "qr.restock.batch", title = "每次补货数量", desc = "一次买多少",
				  min = 1, max = 50, step = 1, default = CFG("restock.batch", 5), format = "%d件",
				  onChanged = function(v) SET("restock.batch", v) end },
				{ type = "slider", key = "qr.restock.cashfloor", title = "现金保留", desc = "买完至少要留这么多现金",
				  min = 0, max = 50000, step = 50, default = CFG("restock.cashFloor", 60), format = "%d$",
				  onChanged = function(v) SET("restock.cashFloor", v) end },
				{ type = "slider", key = "qr.restock.interval", title = "检查间隔", desc = "多久检查一次库存",
				  min = 1, max = 120, step = 1, default = CFG("restock.interval", 8), format = "%ds",
				  onChanged = function(v) SET("restock.interval", v) end },
				{ type = "button", key = "qr.restock.now", title = "立即补货一次", desc = "忽略阈值直接补一次", actionText = "执行", internal = true,
				  onChanged = function() local _, m = doRestock(true) Rst.last = tostring(m) info(m or "补货失败", "qr.restock.now") end },
			} },
		},
	})

	--================================================= 5 自动购买商品
	AddPage({
		id = "buy", title = "自动购买", icon = "B", subtitle = "自动解锁商品",
		sections = {
			{ title = "开关", items = {
				{ type = "toggle", key = "qr.bp.on", title = "自动解锁商品", desc = "有预算就解锁未拥有的商品",
				  default = CFG("buyprod.on", false), internal = true, onChanged = function(v) SET("buyprod.on", v) info(v and "自动解锁已启用" or "已停止", "qr.bp.on") end },
				ST("qr.bp.last", "最近一次", "解锁结果"),
			} },
			{ title = "预算与范围", items = {
				{ type = "slider", key = "qr.bp.maxprice", title = "单价上限", desc = "超过此价不解锁（0 = 不限）",
				  min = 0, max = 100000, step = 100, default = CFG("buyprod.maxPrice", 0), format = "%d$",
				  onChanged = function(v) SET("buyprod.maxPrice", v) end },
				{ type = "slider", key = "qr.bp.floor", title = "现金保留", desc = "买完至少留这么多现金",
				  min = 0, max = 50000, step = 50, default = CFG("buyprod.cashFloor", 200), format = "%d$",
				  onChanged = function(v) SET("buyprod.cashFloor", v) end },
				{ type = "slider", key = "qr.bp.interval", title = "检查间隔", desc = "多久检查一次",
				  min = 1, max = 60, step = 1, default = CFG("buyprod.interval", 6), format = "%ds",
				  onChanged = function(v) SET("buyprod.interval", v) end },
				{ type = "multi", key = "qr.bp.allow", title = "只买这些（白名单）", desc = "空 = 全部；多选",
				  default = CFG("buyprod.allow", {}), options = prodOpts(), onChanged = function(v) SET("buyprod.allow", v) end },
				{ type = "multi", key = "qr.bp.deny", title = "永不购买（黑名单）", desc = "多选；优先于白名单",
				  default = CFG("buyprod.deny", {}), options = prodOpts(), onChanged = function(v) SET("buyprod.deny", v) end },
				{ type = "button", key = "qr.bp.now", title = "立即解锁一次", desc = "按当前条件尝试解锁", actionText = "执行", internal = true,
				  onChanged = function() local _, m = doBuyProd(false) BuyProd.last = tostring(m) info(m or "—", "qr.bp.now") end },
			} },
		},
	})

	--================================================= 6 自动招聘
	AddPage({
		id = "hire", title = "自动招聘", icon = "H", subtitle = "员工招聘与培养",
		sections = {
			{ title = "开关", items = {
				{ type = "toggle", key = "qr.hire.on", title = "自动招聘员工", desc = "按条件自动 HireEmployee",
				  default = CFG("hire.on", false), internal = true, onChanged = function(v) SET("hire.on", v) info(v and "自动招聘已启用" or "已停止", "qr.hire.on") end },
				ST("qr.hire.last", "最近一次", "招聘结果"),
				{ type = "status", key = "qr.hire.count", title = "已招人数", desc = "本次会话招到的人", value = "0", internal = true },
			} },
			{ title = "筛选", items = {
				{ type = "dropdown", key = "qr.hire.minlevel", title = "最低等级", desc = "低于该等级直接跳过",
				  default = CFG("hire.minLevel", "无要求"),
				  options = { Option("无要求", "无要求"), Option("Noob 及以上", "Noob 及以上"), Option("Pro 及以上", "Pro 及以上"), Option("Expert 及以上", "Expert 及以上") },
				  onChanged = function(v) SET("hire.minLevel", v) end },
				{ type = "slider", key = "qr.hire.maxprice", title = "薪资上限", desc = "单个员工最高出价（0 = 不限）",
				  min = 0, max = 100000, step = 50, default = CFG("hire.maxPrice", 0), format = "%d$",
				  onChanged = function(v) SET("hire.maxPrice", v) end },
				{ type = "slider", key = "qr.hire.floor", title = "现金保留", desc = "招完至少留这么多现金",
				  min = 0, max = 50000, step = 50, default = CFG("hire.cashFloor", 300), format = "%d$",
				  onChanged = function(v) SET("hire.cashFloor", v) end },
				{ type = "slider", key = "qr.hire.interval", title = "检查间隔", desc = "多久看一次候选人",
				  min = 2, max = 120, step = 1, default = CFG("hire.interval", 6), format = "%ds",
				  onChanged = function(v) SET("hire.interval", v) end },
				{ type = "multi", key = "qr.hire.roles", title = "岗位白名单", desc = "空 = 所有岗位；多选",
				  default = CFG("hire.roles", {}), options = roleOpts(), onChanged = function(v) SET("hire.roles", v) end },
				{ type = "multi", key = "qr.hire.deny", title = "岗位黑名单", desc = "多选；这些岗位永不招",
				  default = CFG("hire.denyRoles", {}), options = roleOpts(), onChanged = function(v) SET("hire.denyRoles", v) end },
			} },
			{ title = "工位与重掷", items = {
				{ type = "toggle", key = "qr.hire.wslot", title = "自动购买员工工位", desc = "工位没解锁且钱够时自动买",
				  default = CFG("hire.autoWorkerSlot", true), internal = true, onChanged = function(v) SET("hire.autoWorkerSlot", v) end },
				{ type = "toggle", key = "qr.hire.refresh", title = "候选人为空时宝石重掷", desc = "没人可招时花 5 宝石刷新候选人",
				  default = CFG("hire.autoRefresh", false), internal = true, onChanged = function(v) SET("hire.autoRefresh", v) end },
				{ type = "slider", key = "qr.hire.gemfloor", title = "宝石保留", desc = "重掷后至少要留这么多宝石",
				  min = 0, max = 500, step = 1, default = CFG("hire.gemFloor", 0), format = "%d颗",
				  onChanged = function(v) SET("hire.gemFloor", v) end },
				{ type = "button", key = "qr.hire.now", title = "立即招聘一次", desc = "按当前条件尝试招人", actionText = "执行", internal = true,
				  onChanged = function() local _, m = doHire(false) Hire.last = tostring(m) info(m or "—", "qr.hire.now") end },
				{ type = "button", key = "qr.hire.reroll", title = "花宝石重掷候选人", desc = "消耗 5 宝石刷新招聘列表", actionText = "重掷", internal = true,
				  confirm = true, confirmTitle = "确认重掷", confirmText = "将消耗宝石刷新候选人，确定吗？",
				  onChanged = function() local _, m = refreshCandidates() info(m or "—", "qr.hire.reroll") end },
			} },
		},
	})

	--================================================= 7 自动广告
	AddPage({
		id = "ad", title = "自动广告", icon = "D", subtitle = "录制 → 投放",
		sections = {
			{ title = "开关", items = {
				{ type = "toggle", key = "qr.ad.on", title = "自动投放广告", desc = "自动 录制 → 等录制完成 → 发布",
				  default = CFG("ad.on", false), internal = true, onChanged = function(v) SET("ad.on", v) Ad.last = v and "已启用" or "已停止" info(v and "自动广告已启用" or "已停止", "qr.ad.on") end },
				ST("qr.ad.last", "广告状态", "当前进度"),
				{ type = "status", key = "qr.ad.published", title = "累计投放", desc = "本次会话投放次数", value = "0", internal = true },
			} },
			{ title = "选品与时长", items = {
				{ type = "dropdown", key = "qr.ad.pmode", title = "广告商品来源", desc = "决定投哪个商品",
				  default = CFG("ad.productMode", "跟随广告位"),
				  options = { Option("跟随广告位", "跟随广告位"), Option("跟随当前产品", "跟随当前产品"), Option("指定", "指定") },
				  onChanged = function(v) SET("ad.productMode", v) end },
				{ type = "dropdown", key = "qr.ad.product", title = "指定商品", desc = "仅在来源 = 指定 时生效",
				  default = CFG("ad.product", ""), options = prodOpts(),
				  onChanged = function(v) SET("ad.product", v) end },
				{ type = "dropdown", key = "qr.ad.duration", title = "广告时长", desc = "影响花费（300s 便宜 / 600s 贵）",
				  default = tostring(CFG("ad.duration", 600)),
				  options = { Option("300", "300"), Option("600", "600") },
				  onChanged = function(v) SET("ad.duration", tonumber(v) or 600) end },
				{ type = "toggle", key = "qr.ad.select", title = "自动选品", desc = "投放前先调 SelectAdProduct 选中目标商品",
				  default = CFG("ad.autoSelect", true), internal = true, onChanged = function(v) SET("ad.autoSelect", v) end },
				{ type = "toggle", key = "qr.ad.viral", title = "爆款联动", desc = "优先投当期爆款商品（只挑已解锁的）",
				  default = CFG("ad.viralFollow", false), internal = true, onChanged = function(v) SET("ad.viralFollow", v) requestViral() info(v and "已跟随当期爆款" or "已关闭爆款联动", "qr.ad.viral") end },
			} },
			{ title = "预算与节奏", items = {
				{ type = "slider", key = "qr.ad.maxcost", title = "单次花费上限", desc = "超过就不投（0 = 不限）",
				  min = 0, max = 5000, step = 10, default = CFG("ad.maxCost", 0), format = "%d$",
				  onChanged = function(v) SET("ad.maxCost", v) end },
				{ type = "slider", key = "qr.ad.floor", title = "现金保留", desc = "投完至少留这么多现金",
				  min = 0, max = 50000, step = 50, default = CFG("ad.cashFloor", 200), format = "%d$",
				  onChanged = function(v) SET("ad.cashFloor", v) end },
				{ type = "slider", key = "qr.ad.minleft", title = "续投阈值", desc = "当前广告剩余低于此秒数才续投",
				  min = 0, max = 600, step = 5, default = CFG("ad.minLeft", 30), format = "%ds",
				  onChanged = function(v) SET("ad.minLeft", v) end },
				{ type = "slider", key = "qr.ad.interval", title = "检查间隔", desc = "多久检查一次广告状态",
				  min = 1, max = 60, step = 1, default = CFG("ad.interval", 5), format = "%ds",
				  onChanged = function(v) SET("ad.interval", v) end },
				{ type = "button", key = "qr.ad.now", title = "立即投一次", desc = "马上开始录制并投放", actionText = "执行", internal = true,
				  onChanged = function() local ok, m = doAdOnce() info(m or (ok and "已开始" or "失败"), "qr.ad.now") end },
			} },
		},
	})

	--================================================= 8 自动运营
	AddPage({
		id = "ops", title = "自动运营", icon = "O", subtitle = "领取 / 员工 / 研究 / 合同",
		sections = {
			{ title = "自动领取", items = {
				{ type = "toggle", key = "qr.ops.claim", title = "自动领取（任务 / 每日）", desc = "已完成未领的任务自动领，每日奖励到点自动领",
				  default = CFG("ops.claim", false), internal = true, onChanged = function(v) SET("ops.claim", v) end },
				{ type = "slider", key = "qr.ops.claimiv", title = "检查间隔", desc = "多久查一次可领取",
				  min = 5, max = 300, step = 5, default = CFG("ops.claimInterval", 20), format = "%ds",
				  onChanged = function(v) SET("ops.claimInterval", v) end },
				ST("qr.ops.claimlast", "领取状态", "最近一次结果"),
				{ type = "button", key = "qr.ops.claimnow", title = "一键全领一次", desc = "含离线收益 / 社区目标等全部领取口", actionText = "执行", internal = true,
				  onChanged = function()
					for _, n in ipairs({ "DailyClaim", "OfflineCollect", "CommunityGoalClaim", "QuestClaimBonus", "ArcadeWeekly" }) do
						local r = Remotes and Remotes:FindFirstChild(n)
						if r then safe(function() r:FireServer() end) end
					end
					safe(opsClaimTick) info("已触发全部领取口", "qr.ops.claimnow")
				  end },
			} },
			{ title = "员工管理", items = {
				{ type = "toggle", key = "qr.ops.vac", title = "自动送休假", desc = "满意度低于阈值且不在休假的员工自动 SendVacation",
				  default = CFG("ops.vacation", false), internal = true, onChanged = function(v) SET("ops.vacation", v) end },
				{ type = "slider", key = "qr.ops.vacth", title = "满意度阈值", desc = "低于此值就送休假",
				  min = 0, max = 100, step = 5, default = CFG("ops.vacThreshold", 60), format = "%d%%",
				  onChanged = function(v) SET("ops.vacThreshold", v) end },
				{ type = "slider", key = "qr.ops.vaciv", title = "休假检查间隔", desc = "多久检查一次员工状态",
				  min = 5, max = 300, step = 5, default = CFG("ops.vacInterval", 30), format = "%ds",
				  onChanged = function(v) SET("ops.vacInterval", v) end },
				{ type = "toggle", key = "qr.ops.train", title = "自动训练员工", desc = "可训练且钱够时自动 StartTraining",
				  default = CFG("ops.train", false), internal = true, onChanged = function(v) SET("ops.train", v) end },
				{ type = "slider", key = "qr.ops.trainfloor", title = "训练现金保留", desc = "报名训练后至少留这么多现金",
				  min = 0, max = 50000, step = 50, default = CFG("ops.trainFloor", 200), format = "%d$",
				  onChanged = function(v) SET("ops.trainFloor", v) end },
				{ type = "slider", key = "qr.ops.trainiv", title = "训练检查间隔", desc = "多久检查一次",
				  min = 5, max = 600, step = 5, default = CFG("ops.trainInterval", 30), format = "%ds",
				  onChanged = function(v) SET("ops.trainInterval", v) end },
				ST("qr.ops.staff", "员工状态", "休假 / 训练 最近结果"),
			} },
			{ title = "研究与合同", items = {
				{ type = "toggle", key = "qr.ops.res", title = "自动研究", desc = "后期内容：商品研究等级自动升（当前可能仍被门禁）",
				  default = CFG("ops.research", false), internal = true, onChanged = function(v) SET("ops.research", v) end },
				{ type = "slider", key = "qr.ops.resfloor", title = "研究现金保留", desc = "升级后至少留这么多现金",
				  min = 0, max = 100000, step = 100, default = CFG("ops.researchFloor", 300), format = "%d$",
				  onChanged = function(v) SET("ops.researchFloor", v) end },
				{ type = "slider", key = "qr.ops.resiv", title = "研究检查间隔", desc = "多久检查一次",
				  min = 10, max = 900, step = 10, default = CFG("ops.researchInterval", 60), format = "%ds",
				  onChanged = function(v) SET("ops.researchInterval", v) end },
				{ type = "toggle", key = "qr.ops.con", title = "自动接合同", desc = "库存够时自动接（需先建办公室）",
				  default = CFG("ops.contract", false), internal = true, onChanged = function(v) SET("ops.contract", v) end },
				{ type = "slider", key = "qr.ops.coniv", title = "合同检查间隔", desc = "多久检查一次可接合同",
				  min = 10, max = 900, step = 10, default = CFG("ops.contractInterval", 60), format = "%ds",
				  onChanged = function(v) SET("ops.contractInterval", v) end },
				ST("qr.ops.oth", "研究与合同", "最近结果"),
			} },
		},
	})

	--================================================= 9 AI 调参
	AddPage({
		id = "ai", title = "AI 调参", icon = "I", subtitle = "按现况自动改配置",
		sections = {
			{ title = "开关", items = {
				{ type = "toggle", key = "qr.ai.on", title = "启用 AI 自动调参", desc = "读实时数据自动改时序 / 补货 / 并发 / 预算 / 广告节奏",
				  default = CFG("ai.on", false), internal = true, onChanged = function(v) SET("ai.on", v) AI.at = 0 info(v and "AI 调参已启用（每轮都会写回配置）" or "已停止", "qr.ai.on") end },
				{ type = "dropdown", key = "qr.ai.style", title = "调节强度", desc = "保守=小步慢调 · 激进=大幅快速",
				  default = CFG("ai.style", "标准"),
				  options = { Option("保守", "保守"), Option("标准", "标准"), Option("激进", "激进") },
				  onChanged = function(v) SET("ai.style", v) end },
				{ type = "slider", key = "qr.ai.iv", title = "决策间隔", desc = "多久做一次判断",
				  min = 3, max = 120, step = 1, default = CFG("ai.interval", 10), format = "%ds",
				  onChanged = function(v) SET("ai.interval", v) end },
				ST("qr.ai.runs", "当前判断", "AI 最近一次决策"),
				{ type = "button", key = "qr.ai.now", title = "立即调一次", desc = "马上跑一轮 AI 决策", actionText = "执行", internal = true,
				  onChanged = function()
					local was = cfg.ai.on
					cfg.ai.on = true AI.at = 0 safe(aiTick) cfg.ai.on = was
					info(cfg.ai.note or "已执行", "qr.ai.now")
				  end },
			} },
			{ title = "允许 AI 调整的项目", items = {
				{ type = "toggle", key = "qr.ai.timing", title = "时序自适应", desc = "按动作确认失败率动态调传送前等待",
				  default = CFG("ai.timing", true), internal = true, onChanged = function(v) SET("ai.timing", v) end },
				{ type = "toggle", key = "qr.ai.restock", title = "补货阈值", desc = "按仓库容量比例调补货阈 / 批量，见底自动买货",
				  default = CFG("ai.restock", true), internal = true, onChanged = function(v) SET("ai.restock", v) end },
				{ type = "toggle", key = "qr.ai.conc", title = "接单并发", desc = "跟随 maxFulfillments，且不超过传送带条数",
				  default = CFG("ai.concurrency", true), internal = true, onChanged = function(v) SET("ai.concurrency", v) end },
				{ type = "toggle", key = "qr.ai.budget", title = "预算比例", desc = "各模块的现金保留 / 薪资上限按现况现金定",
				  default = CFG("ai.budget", true), internal = true, onChanged = function(v) SET("ai.budget", v) end },
				{ type = "toggle", key = "qr.ai.ad", title = "广告节奏", desc = "按现金在 600s / 300s 之间切换并调续投线",
				  default = CFG("ai.adPace", true), internal = true, onChanged = function(v) SET("ai.adPace", v) end },
				{ type = "toggle", key = "qr.ai.conv", title = "传送带感知", desc = "考虑传送带条数 / 等级（最多 3 条）",
				  default = CFG("ai.conveyorAware", true), internal = true, onChanged = function(v) SET("ai.conveyorAware", v) end },
				{ type = "slider", key = "qr.ai.pwmin", title = "传送前等待下限", desc = "AI 不会把等待调到低于此值",
				  min = 0.10, max = 0.50, step = 0.02, default = CFG("ai.preWaitMin", 0.18), format = "%.2fs",
				  onChanged = function(v) SET("ai.preWaitMin", v) end },
				{ type = "slider", key = "qr.ai.pwmax", title = "传送前等待上限", desc = "AI 最多把等待调到这个值",
				  min = 0.20, max = 1.00, step = 0.05, default = CFG("ai.preWaitMax", 0.60), format = "%.2fs",
				  onChanged = function(v) SET("ai.preWaitMax", v) end },
				ST("qr.ai.chg", "最近调整", "AI 改了哪些配置"),
				{ type = "button", key = "qr.ai.reset", title = "把时序恢复成实机安全值", desc = "重置为 0.30 / 0.30 / 0.30", actionText = "重置", internal = true,
				  onChanged = function()
					cfg.pipe.preWait, cfg.pipe.postWait, cfg.pipe.gap = 0.30, 0.30, 0.30
					cfgTouch() info("时序已恢复 0.30 / 0.30 / 0.30", "qr.ai.reset")
				  end },
			} },
		},
	})

	--================================================= 10 传送带
	AddPage({
		id = "conv", title = "传送带", icon = "T", subtitle = "最多 3 条 · 可升级",
		sections = {
			{ title = "状态", items = {
				ST("qr.conv.state", "传送带", "条数 / 等级 / 升级价"),
				ST("qr.conv.last", "升级结果", "最近一次尝试结果"),
			} },
			{ title = "设置", items = {
				{ type = "toggle", key = "qr.conv.auto", title = "自动检测条数与等级", desc = "从地块升级面板读取 CONVEYOR N / LEVEL x/3",
				  default = CFG("conv.auto", true), internal = true, onChanged = function(v) SET("conv.auto", v) readConv(true) end },
				{ type = "slider", key = "qr.conv.max", title = "最大条数", desc = "后期最多 3 条，用来给并发留上限",
				  min = 1, max = 3, step = 1, default = CFG("conv.maxCount", 3), format = "%d条",
				  onChanged = function(v) SET("conv.maxCount", v) readConv(true) end },
				{ type = "toggle", key = "qr.conv.upg", title = "自动升级传送带", desc = "升级点开放且钱够时自动点 UPGRADE",
				  default = CFG("conv.autoUpgrade", false), internal = true, onChanged = function(v) SET("conv.autoUpgrade", v) info(v and "自动升级已启用" or "已停止", "qr.conv.upg") end },
				{ type = "slider", key = "qr.conv.floor", title = "升级后现金保留", desc = "升级后至少留这么多现金",
				  min = 0, max = 100000, step = 100, default = CFG("conv.upgradeFloor", 300), format = "%d$",
				  onChanged = function(v) SET("conv.upgradeFloor", v) end },
				{ type = "button", key = "qr.conv.now", title = "立即尝试升级", desc = "马上检查并升级等级最低的那条", actionText = "执行", internal = true,
				  onChanged = function() local ok, m = convUpgrade() info(m or (ok and "已触发" or "失败"), "qr.conv.now") end },
			} },
		},
	})

	--================================================= 11 看板
	AddPage({
		id = "dash", title = "看板", icon = "K", subtitle = "实时数值与统计",
		sections = {
			{ title = "实时数值", items = {
				ST("qr.dash.cash", "现金", "当前现金"),
				ST("qr.dash.gems", "宝石", "当前宝石"),
				ST("qr.dash.stock", "仓库", "库存 / 容量"),
				ST("qr.dash.orders", "订单", "待接 / 履约 / 完成"),
				ST("qr.dash.inflight", "在飞订单", "当前所有履约中订单"),
				ST("qr.dash.stat", "会话统计", "时长 / 完成数 / 保护模式"),
				ST("qr.dash.econ", "收益效率", "毛收入 / 每小时 / 单均"),
				ST("qr.dash.fail", "动作确认率", "传送触发的真实成功率"),
				ST("qr.dash.viral", "当期爆款", "爆款列表与可投项"),
				ST("qr.dash.perf", "运行性能", "fps / 延迟 / 提示点数量"),
			} },
			{ title = "保护模式", items = {
				{ type = "toggle", key = "qr.guard.on", title = "低现金自动刹车", desc = "现金低于阈值时暂停一切花钱模块",
				  default = CFG("guard.on", true), internal = true, onChanged = function(v) SET("guard.on", v) guardRefresh() info(v and "保护模式已启用" or "已关闭", "qr.guard.on") end },
				{ type = "slider", key = "qr.guard.floor", title = "刹车现金线", desc = "低于此现金就刹车，只保留流水线",
				  min = 0, max = 100000, step = 50, default = CFG("guard.cashFloor", 150), format = "%d$",
				  onChanged = function(v) SET("guard.cashFloor", v) guardRefresh() end },
				ST("qr.guard.state", "刹车状态", "当前是否在保护模式"),
			} },
			{ title = "调度联动与自愈", items = {
				{ type = "toggle", key = "qr.sched.quest", title = "任务加速", desc = "读任务描述反推目标并放宽对应门槛",
				  default = CFG("sched.questBoost", true), internal = true, onChanged = function(v) SET("sched.questBoost", v) end },
				{ type = "toggle", key = "qr.sched.contract", title = "合同驱动生产", desc = "把最值钱的合同所需商品设为优先",
				  default = CFG("sched.contractBoost", true), internal = true, onChanged = function(v) SET("sched.contractBoost", v) end },
				{ type = "toggle", key = "qr.sched.heal", title = "异常自愈", desc = "超过 15s 收不到服务端状态就主动拉取",
				  default = CFG("sched.selfHeal", true), internal = true, onChanged = function(v) SET("sched.selfHeal", v) end },
				{ type = "toggle", key = "qr.sched.report", title = "每小时报表", desc = "每小时播报完成数 / 毛收入 / 失败率",
				  default = CFG("sched.hourlyReport", true), internal = true, onChanged = function(v) SET("sched.hourlyReport", v) end },
				ST("qr.sched.quests", "任务进度", "未完成任务目标"),
				ST("qr.sched.target", "合同目标", "当前优先生产的商品"),
				{ type = "button", key = "qr.sched.reportnow", title = "立即出一份报表", desc = "马上输出一次运行报表", actionText = "执行", internal = true,
				  onChanged = function() safe(function() Sched.report(true) end) info("已输出报表到控制台与通知", "qr.sched.reportnow") end },
				{ type = "button", key = "qr.dash.reset", title = "重置会话统计", desc = "清空收益 / 成功率统计", actionText = "重置", internal = true,
				  onChanged = function()
					Stat.startAt, Stat.gain, Stat.lastCash = os.clock(), 0, nil
					Exe.stats.total, Exe.stats.fail = 0, 0
					info("会话统计已重置", "qr.dash.reset")
				  end },
			} },
		},
	})

	--================================================= 12 工具
	AddPage({
		id = "tool", title = "工具", icon = "L", subtitle = "维护 / 诊断 / 卸载",
		sections = {
			{ title = "运行日志", items = {
				{ type = "log", key = "qr.tool.log", title = "操作与错误日志", desc = "最近 120 条", clearKey = "qr.tool.logclear" },
				{ type = "toggle", key = "qr.maint.logfile", title = "运行日志落盘", desc = "追加写入 DropshipHub_log.txt",
				  default = CFG("maint.logFile", false), internal = true, onChanged = function(v) SET("maint.logFile", v) info(v and "日志落盘已启用" or "已关闭", "qr.maint.logfile") end },
				{ type = "slider", key = "qr.maint.logiv", title = "落盘间隔", desc = "多久写入一次",
				  min = 10, max = 300, step = 5, default = CFG("maint.logInterval", 30), format = "%ds",
				  onChanged = function(v) SET("maint.logInterval", v) end },
			} },
			{ title = "门禁与存档", items = {
				{ type = "toggle", key = "qr.maint.gate", title = "门禁接口复测", desc = "被反复拒绝的接口定期放行复测",
				  default = CFG("maint.gateRecheck", true), internal = true, onChanged = function(v) SET("maint.gateRecheck", v) end },
				{ type = "slider", key = "qr.maint.recheck", title = "复测间隔", desc = "多久复测一次",
				  min = 60, max = 3600, step = 30, default = CFG("maint.recheckInterval", 600), format = "%ds",
				  onChanged = function(v) SET("maint.recheckInterval", v) end },
				ST("qr.maint.gates", "门禁状态", "当前被拦住的接口"),
				{ type = "button", key = "qr.tool.export", title = "导出配置到剪贴板", desc = "把当前全部设置导出为 JSON", actionText = "导出", internal = true,
				  onChanged = function() local _, m = Sched.exportCfg() info(m or "导出失败", "qr.tool.export") end },
				{ type = "button", key = "qr.tool.import", title = "从剪贴板导入配置", desc = "从剪贴板 JSON 恢复全部设置", actionText = "导入", internal = true,
				  confirm = true, confirmTitle = "确认导入", confirmText = "将用剪贴板内容覆盖当前设置，确定吗？",
				  onChanged = function() local _, m = Sched.importCfg() info(m or "导入失败", "qr.tool.import") end },
				{ type = "button", key = "qr.tool.clearlog", title = "清空日志文件", desc = "把 DropshipHub_log.txt 清空", actionText = "清空", internal = true,
				  onChanged = function()
					if not writefile then info("执行器不支持 writefile", "qr.tool.clearlog") return end
					local ok = safe(function() writefile("DropshipHub_log.txt", "") end)
					info(ok and "日志文件已清空" or "清空失败", "qr.tool.clearlog")
				  end },
			} },
			{ title = "诊断", items = {
				ST("qr.tool.env", "执行器能力", "剪贴板 / 文件 / HTTP"),
				{ type = "status", key = "qr.tool.hints", title = "提示点数量", desc = "当前扫描到的可用提示点", value = "0", internal = true },
				{ type = "button", key = "qr.tool.copystate", title = "复制当前状态到剪贴板", desc = "便于排查问题", actionText = "复制", internal = true,
				  onChanged = function()
					if not setclipboard then info("执行器不支持剪贴板", "qr.tool.copystate") return end
					local out = {}
					for _, k in ipairs(keysOf(S)) do
						local v = S[k]
						out[#out + 1] = k .. " = " .. (type(v) == "table" and ("[" .. table.concat(keysOf(v), ", ") .. "]") or tostring(v))
					end
					safe(function() setclipboard(table.concat(out, "\n")) end)
					info("状态已复制到剪贴板", "qr.tool.copystate")
				  end },
			} },
			{ title = "危险区", items = {
				{ type = "button", key = "qr.tool.unload", title = "卸载脚本", desc = "关闭界面与全部自动化并保存配置",
				  actionText = "卸载", internal = true,
				  confirm = true, confirmTitle = "确认卸载", confirmText = "将关闭界面与全部自动化，确定吗？",
				  onChanged = function()
					cfg.pipe.on, cfg.restock.on, cfg.ac.on = false, false, false
					cfgSave(true)
					safe(dispose)
				  end },
			} },
		},
	})

	--===== 启动 + 对外接口 =====
	UI.Build()
	if ConfigManager then ConfigManager:_registerCallbacks() end
	local _al = ConfigManager:ReadAutoLoad()
	if _al and _al ~= "" then ConfigManager:LoadConfig(_al) end

	_G.QiuRongUI = {
		UI = UI, State = State, Pages = Pages, Components = Components,
		Registry = Registry, Theme = Theme, AppConfig = AppConfig,
		AddPage = AddPage, Option = Option, ConfigManager = ConfigManager,
	}
end
local QRU = _G.QiuRongUI
local function qrSet(key, text)
	if not (QRU and QRU.State and QRU.State.Controls) then return end
	local c = QRU.State.Controls[key]
	if c and c.SetValue then pcall(function() c.SetValue(tostring(text)) end) end
end
Notify = function(title, content, icon)
	if QRU and QRU.State then
		safe(function() QRU.State:AddLog("INFO", tostring(title) .. " · " .. tostring(content), "qr.notify") end)
	end
end
log("秋容UI 已就绪 · 作者 合作:b站大不列颠超入")

--=====================================================================
-- 10. 主循环
--=====================================================================
-- 线程 A：流水线（会长时间 task.wait 等确认，所以必须独立，别拖住 UI）
task.spawn(function()
	while ENABLED and STATE.alive() do
		safe(pipeTick)
		task.wait(0.08)
	end
end)

task.spawn(function()
	local tAc = 0
	while ENABLED and STATE.alive() do
		task.wait(0.2)
		if cfg.ac.on then
			local now = os.clock()
			if now - tAc >= math.max(0.2, tonumber(cfg.ac.interval) or 0.8) then
				tAc = now
				safe(tryAutoAccept)
			end
		end
	end
end)

task.spawn(function()
	local tB, tH, tConv, tViral = 0, 0, 0, 0
	while ENABLED and STATE.alive() do
		task.wait(0.25)
		local now = os.clock()

		-- 每轮先刷新保护模式与会话统计（看板与所有花钱模块都依赖它）
		safe(guardRefresh)
		safe(statTick)

		if now - tViral >= 60 then
			tViral = now
			requestViral()
		end

		if cfg.hire.on and now - tH >= cfg.hire.interval then
			tH = now
			requestEmployees()
			requestJobs()
			task.wait(0.35)
			local _, m = doHire(false)
			Hire.last = tostring(m or Hire.last)
			-- 没人可招 + 开了重掷 + 过了冷却 + 宝石够 -> 花宝石刷新
			if cfg.hire.autoRefresh and #hireCandidates() == 0
				and now - Hire.refreshAt >= 30 then
				local ok, rm = refreshCandidates()
				if ok then Hire.last = rm end
			end
		end

		if cfg.buyprod.on and now - tB >= cfg.buyprod.interval then
			tB = now
			local _, m = doBuyProd(false)
			BuyProd.last = tostring(m or BuyProd.last)
		end

		if cfg.ad.on then safe(adTick) end

		safe(opsTick)

		safe(readConv)
		if cfg.conv.autoUpgrade and now - tConv >= 15 then
			tConv = now
			safe(convUpgrade)
		end

		safe(aiTick)

		-- 调度联动：任务反推 / 合同驱动 / 自愈 / 报表 / 复测 / 日志落盘
		safe(schedTick)
	end
end)

task.spawn(function()
	local tRest, tUI, tState, tDone = 0, 0, 0, 0
	while ENABLED and STATE.alive() do
		task.wait(0.08)
		local now = os.clock()

		if cfg.restock.on and now - tRest >= cfg.restock.interval then
			tRest = now
			local _, msg = doRestock(false)
			Rst.last = tostring(msg or "—")
		end

		if now - tState >= 5 then
			tState = now
			requestState()
		end

		if now - tDone >= 1 then
			tDone = now
			safe(trackCompletions)
		end

		if now - tUI >= 0.35 then
			tUI = now
			local carry = carrying()
			local carryCn = (carry == "none") and "空手"
				or (carry == "labeled" and "手持成品箱" or "手持原始包裹")
			local stock = stockOf(cfg.restock.product ~= "" and cfg.restock.product or nil)
			local wh = tonumber(S.warehouse) or 0
			local nNew, nDone, nFul = countStatus("New"), countStatus("Completed"), activeCount()
			local lineOrder = string.format("待接 %d · 履约 %d/%d · 完成 %d", nNew, nFul, maxActive(), nDone)

			if HUD.gui and HUD.row.cash then
				safe(function()
					HUD.row.cash.Text = "现金 " .. fmt(S.cash) .. "   宝石 " .. fmt(S.gems)
					HUD.row.stock.Text = string.format("仓库 %d/%s   库存 %d", wh,
						tostring(S.warehouseCapacity or "—"), stock)
					HUD.row.orders.Text = lineOrder
					HUD.row.carry.Text = "搬运 " .. carryCn
					HUD.row.phase.Text = "阶段 " .. Pipe.phase .. " · " .. Pipe.detail
					HUD.row.ac.Text = string.format("接单 %s ｜ 履约 %d/%d ｜ %s",
						cfg.ac.on and "开" or "关", activeCount(), math.min(cfg.ac.maxActive, maxActive()),
						cfg.ac.on and ((Pipe.acWhy ~= "" and Pipe.acWhy) or ("候选 " .. #acCandidates())) or "—")
					HUD.row.rest.Text = "补货 " .. (cfg.restock.on and ("开 · " .. Rst.last) or "关")
					HUD.row.mode.Text = string.format("传送带 %d 条·Lv%d ｜ AI %s ｜ 回位 %s",
						cfg.conv.count, cfg.conv.level,
						cfg.ai.on and "开" or "关", cfg.pipe.restore and "开" or "关")
					HUD.row.buy.Text = string.format("购买 商品%d(%s) 员工%d(%s)%s",
						BuyProd.count, cfg.buyprod.on and "开" or "关",
						Hire.count, cfg.hire.on and "开" or "关",
						Guard.blocked and "  刹车中" or "")
					HUD.row.ad.Text = "广告 " .. (cfg.ad.on and Ad.last or "关")
				end)
			end

			-- 把实时值推给秋容UI（只有当前显示的页面存在控件；
			-- 其他页面切过去时由 ST(...) 的 value 函数重新求值，两条路都对）
			local co = orderById(Pipe.orderId)
			qrSet("qr.pipe.phase", Pipe.phase .. " · " .. Pipe.detail)
			qrSet("qr.pipe.order", co and string.format("#%s · %s · %s$ · %s · %s",
				tostring(co.id), tostring(co.product), tostring(co.price),
				tostring(co.status), co.isViral and "爆款" or "普通") or "—")
			qrSet("qr.pipe.carry", carryCn)
			qrSet("qr.pipe.done", tostring(Pipe.completed) .. " 单")
			qrSet("qr.ac.why", (Pipe.acWhy ~= "" and Pipe.acWhy) or string.format("可接 · 候选 %d", #acCandidates()))
			qrSet("qr.ac.cand", string.format("可接 %d 单 · 候选 %d · %s", nNew, #acCandidates(), cfg.ac.priority))
			qrSet("qr.restock.last", Rst.last)
			qrSet("qr.restock.stock", string.format("%d / %s（库存 %d）", wh, tostring(S.warehouseCapacity or "—"), stock))
			qrSet("qr.bp.last", BuyProd.last)
			qrSet("qr.hire.last", string.format("%s（已招 %d 人）", tostring(Hire.last), Hire.count))
			qrSet("qr.hire.count", tostring(Hire.count) .. " 人")
			qrSet("qr.ad.last", Ad.last)
			qrSet("qr.ad.published", tostring(Ad.published) .. " 次")
			qrSet("qr.ops.claimlast", Ops.last["领取"] or "—")
			qrSet("qr.ops.staff", string.format("休假 %s ｜ 训练 %s", tostring(Ops.last["休假"] or "—"), tostring(Ops.last["训练"] or "—")))
			qrSet("qr.ops.oth", string.format("研究 %s ｜ 合同 %s", tostring(Ops.last["研究"] or "—"), tostring(Ops.last["合同"] or "—")))
			qrSet("qr.ai.runs", string.format("第 %d 轮 · %s", AI.runs, tostring(cfg.ai.note or "—")))
			qrSet("qr.ai.chg", #AI.changes > 0 and AI.changes[#AI.changes] or "（暂无调整）")
			do
				local lines = { string.format("条数 %d/%d ｜ 最高 Lv%d ｜ 平均 Lv%.1f",
					cfg.conv.count, cfg.conv.maxCount, Conv.level, Conv.avgLevel or 0) }
				for _, b in ipairs(Conv.belts or {}) do
					lines[#lines + 1] = string.format("%s Lv%d/%d %s %s",
						tostring(b.name), b.level, b.maxLevel,
						b.enabled and "可升级" or "未开放",
						b.price and ("$" .. tostring(b.price)) or "")
				end
				qrSet("qr.conv.state", table.concat(lines, " ｜ "))
			end
			qrSet("qr.conv.last", Conv.last or "—")
			qrSet("qr.dash.cash", fmt(S.cash))
			qrSet("qr.dash.gems", fmt(S.gems))
			qrSet("qr.dash.stock", string.format("%d / %s（库存 %d）", wh, tostring(S.warehouseCapacity or "—"), stock))
			qrSet("qr.dash.orders", lineOrder)
			do
				local fl = {}
				for _, o in pairs(S.orders or {}) do
					if FULFIL[tostring(o.status)] then
						fl[#fl + 1] = string.format("#%s %s", tostring(o.id), tostring(o.status))
					end
				end
				qrSet("qr.dash.inflight", #fl > 0 and table.concat(fl, " ｜ ") or "无在飞订单")
			end
			qrSet("qr.dash.stat", string.format("会话 %d 分 ｜ 完成 %d 单 ｜ 现金 %s ｜ 宝石 %s ｜ %s",
				math.floor((os.clock() - Stat.startAt) / 60), Pipe.completed, fmt(S.cash), fmt(S.gems),
				Guard.blocked and "保护模式中" or "正常"))
			qrSet("qr.dash.econ", string.format("毛收入 %s ｜ 约 %s/小时 ｜ 单均 %s",
				fmt(Stat.gain), fmt(Stat.gain / statHours()),
				Pipe.completed > 0 and fmt(Stat.gain / math.max(1, Pipe.completed)) or "—"))
			do
				local tot, bad = Exe.stats.total, Exe.stats.fail
				qrSet("qr.dash.fail", tot > 0
					and string.format("确认 %d 次 · 通过 %d · 失败率 %.0f%%", tot, tot - bad, bad / tot * 100)
					or "暂无样本")
			end
			do
				local v = G.viral
				local vp = viralProduct()
				local names = {}
				for _, p in ipairs((v and v.produkty) or {}) do
					names[#names + 1] = tostring(p.nazwa or p.id)
				end
				qrSet("qr.dash.viral", #names > 0
					and (table.concat(names, " / ") .. (vp and ("　可投：" .. vp) or "　（均未解锁）"))
					or "无数据（需打开一次爆款面板）")
			end
			qrSet("qr.guard.state", Guard.blocked
				and string.format("刹车中（现金 %s < %s）", fmt(S.cash), fmt(cfg.guard.cashFloor)) or "正常")
			do
				local f = Sched.focus
				qrSet("qr.sched.quests", (#f.texts > 0) and table.concat(f.texts, " ｜ ") or "无未完成任务")
				local prefs = {}
				for pid in pairs(Sched.prefProducts or {}) do prefs[#prefs + 1] = pid end
				qrSet("qr.sched.target", #prefs > 0
					and ("优先生产：" .. table.concat(prefs, " / "))
					or (G.contract and (G.contract.hasOffice and "有办公室，暂无可接合同" or "未建办公室，合同未开放")
						or "无数据"))
				local gl = {}
				for _, msg in pairs(Sched.gated or {}) do gl[#gl + 1] = msg end
				qrSet("qr.maint.gates", (#gl > 0) and table.concat(gl, " ｜ ") or "无被门禁的接口")
			end
			qrSet("qr.tool.env", string.format("剪贴板 %s ｜ 文件 %s ｜ HTTP %s",
				setclipboard and "有" or "无", writefile and "有" or "无", game.HttpGet and "有" or "无"))
			qrSet("qr.tool.hints", tostring(#Prompt.list) .. " 个可用提示点")
		end


			local ping = 0
			safe(function() ping = math.floor(plr:GetNetworkPing() * 1000) end)
			local dt = RunSvc.RenderStepped:Wait()
			qrSet("qr.dash.perf", string.format("%d fps · %d ms · %d 提示点",
				math.floor(1 / math.max(dt, 1 / 240)), ping, #Prompt.list))

			cfgSave()
		end
	end
)

--=====================================================================
-- 11. 收尾
--=====================================================================
STATE.onCleanup(function()
	cfgSave(true)
	safe(dispose)   -- 关界面 + 停线程 + 释放单例标记
end)

requestState()
if QRU and QRU.State then safe(function() QRU.State:AddLog("INFO", "已加载 · 合作:b站大不列颠超入", "app.ready") end) end
log("v3.2 载入完成 · 地块=" .. tostring(plotName()) .. " · 订单驱动")
