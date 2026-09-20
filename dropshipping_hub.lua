--[[
	代发货大亨 (Dropshipping Tycoon) · 订单驱动流水线 Hub  v3.2
	UI: WindUI（主题 / 配置存取 / 窗口外观 / 弹窗 全部启用）
	==================================================================
	【订单驱动的状态机】
	  流水线不跑固定步骤序列，而是：
	    读当前进行中订单 -> 看它的 status -> 只做该 status 该做的那一件事
	  New                -> AcceptOrder(id)                     [远程]
	  Ready to Pack 空手  -> 取原始包裹                           [远程 / 提示点]
	  Ready to Pack 手持  -> Put on conveyor                     [提示点]
	  Being Packed 空手   -> 成品箱出现后 Pick up package          [提示点]
	  Being Packed 手持   -> Leave for courier                   [提示点]
	  Ready for Courier   -> 等快递员取件（约 17s 自动 Completed）
	  任何一步失败/卡住都不会跑偏：下一 tick 重新读状态再决定。
	==================================================================
	【执行引擎（实机标定结论）】
	  · AcceptOrder / BuySupply 是纯 RemoteEvent，与角色位置无关
	  · WarehouseStockTake / Put on conveyor / 成品箱 Pick up package /
	    Leave for courier 都由服务端做距离校验（12 stud），必须人到位
	    -> 统一用"闪现微传送"：瞬间把角色挪到提示点 -> 等服务端收到
	       新坐标 -> 触发 -> 停在那里等状态确认（最多 1.4s，没确认就原地补一枪）
	       —— 真正会丢动作的是"触发完立刻回位"：服务端做距离校验读的是服务器端坐标，人已经闪回去，动作直接被丢。
	==================================================================
	【v2 -> v3.2 修复】
	  1. 旧版取箱只扫 plot，箱子其实在 Workspace.LocalWarehouseStock
	  2. 旧版无订单也硬跑 -> 严格订单驱动
	  3. 提示点每帧全量扫 -> 只扫 [地块 + 仓库] 两棵小子树并节流
	  4. 状态靠轮询 -> 靠 StateUpdate 推送，轮询只兜底
	  5. 悬浮窗拖不动 -> 全局 UIS + 区域命中 + 位置存盘
	  6. 看板空白 -> 启动先等状态就绪再建 UI
	  7. 触发完立刻回位导致动作被丢 -> 改为「等到状态确认再回位」，未确认原地补一枪（v3.2）
	  8. 自动接单被绑在流水线总开关里 -> 拆成独立线程，关掉流水线也能接单（v3.2）
	  9. 旧存档里的坏时序 -> 载入时自动迁移到安全值（pipe.ver = 2）
	  10. 流水线等确认会阻塞主循环 -> 流水线/接单/UI 拆成三条线程，HUD 不再卡
	  11. 成品箱抢跑传送 -> 只认服务端置的 Enabled=true（箱子到带末才为真），已不再强行启用
	  12. 状态跳到 Being Packed 但原包还在手上 -> 该分支改为重试上带，不再干等卡死
	==================================================================
	【v3.2 新增：自动购买 / 自动招聘 / 自动广告】（接口全部实机标定）
	  1. 商品解锁  UnlockProduct(productId : string)，已拥有时是空操作
	  2. 员工招聘  HireEmployee(offerId : number)   ← 必须 number，字符串无效
	               免费拉取: RequestEmployees / RequestJobs（和花钱的重掷是两回事）
	               重掷候选人: RefreshJobs()  花 5 宝石
	               补候选位  : BuyCandidateSlot()  100 现金，offers 3 -> 4
	               补员工工位: BuyWorkerSlot()  价格见 EmployeeState.workerSlotCost
	  3. 广告投放  RecordAd() -> adState=Recording（adRecordTotal 秒）
	               -> adState=Ready -> PublishAd() 才真正投放并生成 campaign
	               费用 = CampaignState.campaignCosts[rarity][duration]
	               选品 = SelectAdProduct(productId : string)
	               数据拉取 = RequestCampaigns -> CampaignState（campaigns 里 left 是剩余秒）
	==================================================================
	【v3.2 新增：自动运营 / AI 调参 / 传送带感知】
	  1. 自动运营
	     自动领取  QuestClaim(uid:string) ✅ / DailyClaim() / QuestClaimBonus()
	     自动休假  SendVacation(empId:number) ✅（status -> "On Vacation"）
	     自动训练  StartTraining(empId:number)（需 training.mozliwy、现金 >= training.cena）
	     自动研究  ResearchBuy(productId)（后期内容，当前被服务端门禁）
	     自动合同  ContractAccept(idx)（需先建办公室）
	  2. AI 调参：读实时信号自动写回配置（每类都可单独关）
	     时序 <- Exe.stats 的动作确认失败率
	     补货 <- warehouseCapacity / warehouse
	     并发 <- maxFulfillments 与传送带条数
	     预算 <- 当前现金 × 强度比例（保守 5% / 标准 10% / 激进 15%）
	     广告 <- 600s / 300s 花费与现金
	  3. 传送带：从 Plot.Conveyor.UpgradeAnchor 读条数与等级
	     面板文本 Tytul="CONVEYOR N" / Poziom="LEVEL x/3" / Cena="$n"
	     最多 3 条；升级点 Enabled=true 时可自动点 UPGRADE
	==================================================================
	快捷键: 右Shift 开关窗口（可在 外观 页改键）
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
		--   所以触发后改为「留在原地等状态确认（最多 ~1.4s），没确认就原地补一枪」。
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
	-- 自动购买商品（解锁产品线）
	buyprod = {
		on = false, maxPrice = 0, cashFloor = 200, interval = 6,
		allow = {}, deny = {},
	},
	-- 自动购买员工（JobCenter 招聘）
	hire = {
		on = false, interval = 6, cashFloor = 300, maxPrice = 0,
		minLevel = "无要求", roles = {}, denyRoles = {},
		autoWorkerSlot = true, autoRefresh = false, gemFloor = 0,
	},
	-- 自动发送广告（录制 -> 发布）
	ad = {
		on = false, interval = 5, duration = 600,
		productMode = "跟随广告位", product = "",
		maxCost = 0, cashFloor = 200, minLeft = 30, autoSelect = true,
		viralFollow = false,
	},
	-- 保护模式：现金低于阈值时自动停掉一切花钱模块（流水线照常跑）
	guard = { on = true, cashFloor = 150 },
	-- 传送带（后期可升级 / 增加，最多 3 条）
	conv = {
		auto = true, count = 1, level = 0, maxCount = 3,
		autoUpgrade = false, upgradeFloor = 300,
	},
	-- AI 自动调参（结合现况动态改配置）
	ai = {
		on = false, interval = 10, style = "标准",
		timing = true, restock = true, concurrency = true,
		budget = true, adPace = true, conveyorAware = true,
		preWaitMin = 0.18, preWaitMax = 0.60, note = "待机",
	},
	-- 自动运营：领取 / 休假 / 训练 / 研究 / 合同
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

-- 配置迁移：旧存档里可能存着坏时序（preWait=0.06 / postWait=0.14），
-- 那正是"传送成功但动作不生效"的根因，这里统一抬到安全值。
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

local function requestState()
	if Remotes and Remotes:FindFirstChild("RequestState") then
		safe(function() Remotes.RequestState:FireServer() end)
	end
end
if Remotes and Remotes:FindFirstChild("StateUpdate") then
	STATE.connect(Remotes.StateUpdate.OnClientEvent, function(t) S = t or {} end)
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
--   activeFulfillments，而不是我们自己的状态表。
--   原因：订单进入 Ready for Courier（包裹已交到快递员位）时，服务端就已经
--   把履约位释放了（实测 maxFulfillments=1 下，activeFulfillments 只剩新单，
--   老的 Ready for Courier 已不在其中），但我们的 FULFIL 仍把它算作占用，
--   于是 activeCount()=2 >= 1 -> 自动接单永久停摆。
local function activeCount()
	local af = S.activeFulfillments
	if type(af) == "table" then
		local n = 0
		for _ in pairs(af) do n = n + 1 end
		if n > 0 then return n end
	end
	-- 兜底（没有该字段时）才退回按状态数
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
				-- 实测能让"放上传送带"在 89 stud 外直接生效。
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

-- 有些接口会被游戏静默拒绝（研究未开放 / 今日已领 / 无办公室 / 钱不够）。
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
	-- 给 AI 调参用的信号：只在有确认条件时统计（真实成功率）
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
-- confirmFn 省略 = 发出即算成功；给了就等到状态确认（最多 ~1.4s + 补射 ~0.9s）
local function actPrompt(prompt, confirmFn)
	if not prompt then return false end
	if not canAct() then return false end
	local _, confirmed = fireNear(prompt, confirmFn)
	return true, confirmed
end

-- 取货总入口。
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
	for _, c in ipairs(productCandidates()) do
		if passList(cfg.buyprod.allow, c.id, true) and not passList(cfg.buyprod.deny, c.id, false) then
			if cfg.buyprod.maxPrice <= 0 or c.price <= cfg.buyprod.maxPrice then
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

local function hireCandidates()
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
					if (cfg.hire.maxPrice <= 0 or price <= cfg.hire.maxPrice) and roleHasFreeSlot(role) then
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
	local list = hireCandidates()
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
--   录制结束变 Ready，此时 PublishAd() 才真正投放并生成 campaign。
--   费用取 CampaignState.campaignCosts[rarity][duration]。
local Ad = { at = 0, last = "待机", published = 0, armed = false }

-- 爆款联动：ViralState 会轮换当期的爆款商品（位面 mnoznik 倍），
-- 优先投它 —— 但只挑自己已经解锁的，否则广告面板根本不认。
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
	if owned - used <= 0 and campaignLeft(pid) <= 0 then
		Ad.last = string.format("广告位已满（%d/%d）", used, owned)
		return
	end
	local left = campaignLeft(pid)
	if left > cfg.ad.minLeft then
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
--     SendVacation(empId:number)  -> status 变 "On Vacation"、vacationLeft=180  ✅
--     QuestClaim(uid:string)      -> 该任务 claimed=true                       ✅
--     HireEmployee(offerId:number) / BuyCandidateSlot() / RefreshJobs(5宝石)   ✅
--     StartTraining(empId:number) -> 条件：training.mozliwy 且 trwa=false、
--                                    zajete=false、现金 >= training.cena（750）
--     ResearchBuy / DailyClaim / QuestClaimBonus / ContractAccept 的参数为自然
--       推断，当前被游戏门禁（研究未开放 / 今日已领 / 奖励未就绪 / 无办公室）。
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
			-- 今天已领过也会落到 else：不是故障，30 分钟后自然再试一次
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
-- 5.6 传送带感知（后期可升级 / 增加，最多 3 条）+ AI 自动调参
--=====================================================================
local Conv = { at = 0, count = 1, level = 0, maxLevel = 3, price = nil,
	prompt = nil, last = "—" }

-- 实机标定：传送带升级是地块里的物理提示点
--   Plot.Conveyor.UpgradeAnchor.UpgradePrompt  (ActionText="UPGRADE")
--   面板 UpgradePanel 文本：Tytul="CONVEYOR 1" / Poziom="LEVEL 0 / 3" /
--                           Efekt="Packages move 1.5x faster" / Cena="$100"
--   等级从 0 起、最高 3；后期会有 CONVEYOR 1/2/3（最多 3 条）。
local function readConv(force)
	if not force and os.clock() - Conv.at < 1.5 then return end
	Conv.at = os.clock()
	local plot = getPlot()
	if not plot then return end
	local n, lvl, price, prompt = 0, 0, nil, nil
	for _, m in ipairs(plot:GetChildren()) do
		if m:IsA("Model") and string.find(string.lower(m.Name), "conveyor", 1, true) then
			n = n + 1
			local ua = m:FindFirstChild("UpgradeAnchor", true)
			local pr = ua and ua:FindFirstChild("UpgradePrompt", true)
			if pr then prompt = pr end
			local panel = ua and ua:FindFirstChild("UpgradePanel", true)
			if panel then
				for _, d in ipairs(panel:GetDescendants()) do
					if d:IsA("TextLabel") then
						local key = string.lower(d.Name)
						if string.find(key, "poziom", 1, true) then
							local cur, mx = string.match(d.Text, "(%d+)%s*/%s*(%d+)")
							if cur then lvl = math.max(lvl, tonumber(cur) or 0) end
							if mx then Conv.maxLevel = tonumber(mx) or Conv.maxLevel end
						elseif string.find(key, "cena", 1, true) then
							local v = string.match(d.Text, "%d+")
							if v then price = tonumber(v) end
						end
					end
				end
			end
		end
	end
	if n > 0 then
		Conv.count, Conv.level, Conv.price, Conv.prompt = n, lvl, price, prompt
	end
	if cfg.conv.auto then
		cfg.conv.count = math.clamp(Conv.count, 1, cfg.conv.maxCount)
		cfg.conv.level = lvl
	end
end

local function convUpgrade()
	readConv(true)
	local pr = Conv.prompt
	if not pr or not pr.Parent then
		Conv.last = "未发现传送带升级点"
		return false, Conv.last
	end
	local maxLv = Conv.maxLevel or 3
	if Conv.level >= maxLv then
		Conv.last = string.format("已是满级（%d/%d）", Conv.level, maxLv)
		return false, Conv.last
	end
	if not pr.Enabled then
		Conv.last = string.format("升级尚未开放（服务端 Enabled=false · 当前 %d/%d）", Conv.level, maxLv)
		return false, Conv.last
	end
	local price = tonumber(Conv.price) or 0
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
	Conv.last = string.format("已触发升级（%s）", fmt(price))
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
	lastAccept = 0, completed = 0, seen = {}, beltTries = 0, beltUntil = 0 }

local function setPhase(name, detail)
	if Pipe.phase ~= name then
		if name ~= "IDLE" then log(string.format("[%s] %s", name, tostring(detail or ""))) end
		Pipe.phase = name
		Pipe.phaseAt = os.clock()
	end
	Pipe.detail = tostring(detail or name)
end

-- 状态优先级：能动手的先干；Ready for Courier 只是在等快递员 NPC（约 17s），
-- 如果它一直占着 currentOrder()，新接的单会被饿死（并发放开后必然发生）。
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
	table.sort(r, function(a, b)
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
	if not cfg.ac.on then return false end
	if os.clock() - Pipe.lastAccept < cfg.ac.interval then return false end
	if activeCount() >= math.min(cfg.ac.maxActive, maxActive()) then return false end
	local c = acCandidates()
	if #c == 0 then return false end
	Pipe.lastAccept = os.clock()
	return acceptOrder(c[1].id)
end

local function doneBoxPrompt()
	local plot = getPlot()
	if not plot then return nil end
	local pkg = plot:FindFirstChild("Package", true)
	if not pkg then return nil end
	-- ⚠ 实机标定（v3.2）：成品箱会沿传送带移动，服务端只在箱子「到达末端」
	--   那一刻才把 ProximityPrompt.Enabled 置 true（上带后约 4s）。
	--   所以这里必须只认 Enabled=true —— 绝不能强行启用它，
	--   否则箱子还在带子中间就传送过去，就是抢跑空触。
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

-- 订单完成的统计与日志。
-- ⚠ 完成的订单会离开履约集合，currentOrder() 不再返回它，所以必须独立扫描，
--   否则 Pipe.completed 与"订单完成"日志永远是死代码。
--   seed=true 用于启动时把历史已完成订单先登记好，避免开局刷屏。
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
	-- 会话很长时清一次，避免 seen 无限增长
	local cnt = 0
	for _ in pairs(Pipe.seen) do cnt = cnt + 1 end
	if cnt > 400 then
		Pipe.seen = {}
		for _, o in pairs(S.orders or {}) do
			if tostring(o.status) == "Completed" then Pipe.seen[tostring(o.id)] = true end
		end
	end
end

-- 把原始包裹交给传送带（Ready to Pack 与 Being Packed 共用）
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

	-- 角色不在场（死亡 / 复活中）时不做任何传送与触发，等它回来
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
				-- 确认条件：成品箱到手（打包完成后才会出现，所以这步要等状态自己推进）
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
	-- 完成统计改由 trackCompletions() 独立扫描（原分支是死代码）。
	setPhase("WAIT", "未知状态 " .. st)
end

--=====================================================================
-- 8. 等状态就绪
--=====================================================================
local function waitForState(timeout)
	requestState()
	-- 顺手把招聘 / 广告 / 领取 / 合同 / 研究面板也拉一次，
	-- 这样 UI 建页签时就有岗位列表、广告价、任务与员工数据
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
-- 启动时先把历史已完成订单登记掉，否则完成计数/日志会开局刷屏
safe(function() trackCompletions(true) end)

--=====================================================================
-- 9. WindUI
--=====================================================================
local okW, WindUI = pcall(function()
	return loadstring(game:HttpGet(
		"https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not okW or type(WindUI) ~= "table" then
	WindUI = nil
	log("WindUI 加载失败，仅运行 HUD + 执行引擎")
end

local Notify = function() end
local UI = { text = {} }
-- Window 已在 §0 前向声明（单例清理闭包要用）
local ConfigMgr = { name = nil, list = {}, lastMsg = "—" }

if WindUI then
	-- ⚠ 界面构建必须放进独立函数：整个 UI 有 60+ 个局部变量，直接摊在主 chunk
	--   里会撞 Luau「单函数 200 个局部寄存器」上限，导致整个脚本编译失败。
	--   包一层函数后，UI 的局部变量有自己的寄存器帧，互不挤占。
	local function buildUI()
	safe(function() WindUI:SetNotificationLower(true) end)

	-- 外观设置先应用（建窗口时就要用）
	local vw = cfg.view
	Window = WindUI:CreateWindow({
		Title       = "大不列颠超入脚本-代发货大亨",
		Icon        = "package",
		Author      = "版本:正式版1.0.0",
		Folder      = "DropshipHub",
		Size        = UDim2.fromOffset(vw.width, vw.height),
		MinSize     = Vector2.new(560, 400),
		MaxSize     = Vector2.new(1000, 700),
		Theme       = vw.theme,
		Transparent = vw.transparency,
		Resizable   = vw.resizable,
		SideBarWidth = 190,
		HideSearchBar = false,
		ScrollBarEnabled = true,
		Acrylic     = vw.acrylic,
		BackgroundImageTransparency = 0.35,
		ToggleKey   = Enum.KeyCode.RightShift,
		User        = { Enabled = true, Anonymous = false },
	})
	safe(function() Window:SetBackgroundTransparency(vw.bgTransparency) end)
	safe(function() Window:SetPanelBackground(vw.panelBg) end)
	safe(function() Window:SetUIScale(vw.uiScale) end)
	if vw.bgImage ~= "" then safe(function() Window:SetBackgroundImage(vw.bgImage) end) end

	Notify = function(t, c, i)
		safe(function()
			WindUI:Notify({ Title = t, Content = tostring(c), Duration = 3, Icon = i or "check" })
		end)
	end

	local function setText(obj, text)
		if type(obj) ~= "table" then return end
		for _, m in ipairs({ "SetDesc", "SetTitle" }) do
			if type(obj[m]) == "function" then
				if pcall(obj[m], obj, text) then return end
			end
		end
	end
	UI.setText = setText

	local function para(section, title, desc, icon)
		local p
		pcall(function() p = section:Paragraph({ Title = title, Desc = desc or "—", Icon = icon }) end)
		if not p then
			pcall(function()
				p = section:Button({ Title = title, Desc = desc or "—", Icon = icon, Callback = function() end })
			end)
		end
		return p
	end
	UI.para = para

	-- 安全建元素：不支持就跳过，绝不让整窗崩掉
	-- ⚠ 实机标定：WindUI 的图标表随版本变动，Toggle 遇到解析不到的图标名
	--   会直接抛 "attempt to index nil with number" 整块不建（Button 不校验）。
	--   所以失败时丢掉 Icon 重试一次，保证元素一定出现。
	local function mk(kind, section, cfgT)
		local el
		local ok = pcall(function() el = section[kind](section, cfgT) end)
		if not ok and cfgT.Icon ~= nil then
			cfgT.Icon = nil
			ok = pcall(function() el = section[kind](section, cfgT) end)
			if ok then log("图标不可用，已降级为无图标: " .. kind .. " / " .. tostring(cfgT.Title)) end
		end
		if not ok then log("元素不支持: " .. kind .. " / " .. tostring(cfgT.Title)) end
		return el
	end
	UI.mk = mk

	local function slider(section, title, desc, icon, flag, def, min, max, step, apply)
		return mk("Slider", section, {
			Title = title, Desc = desc, Icon = icon, Flag = flag,
			Value = { Min = min, Max = max, Default = def }, Step = step,
			Callback = function(v) apply(v) cfgTouch() end,
		})
	end
	local function toggle(section, title, desc, icon, flag, def, apply)
		return mk("Toggle", section, {
			Title = title, Desc = desc, Icon = icon, Flag = flag, Value = def,
			Callback = function(v) apply(v) cfgTouch() end,
		})
	end

	-- Tab 创建保护：图标名解析失败时丢掉图标重试，避免整窗建不起来
	local function mkTab(cfgT)
		local t
		local ok = pcall(function() t = Window:Tab(cfgT) end)
		if not ok and cfgT.Icon ~= nil then
			cfgT.Icon = nil
			pcall(function() t = Window:Tab(cfgT) end)
		end
		if not t then log("页签创建失败: " .. tostring(cfgT.Title)) end
		return t
	end

	---------------------------------------------------------------------
	-- Tab 0 · 脚本详细（置顶）
	---------------------------------------------------------------------
	local TabInfo = mkTab({ Title = "脚本详细", Icon = "info" })

	local SecAbout = TabInfo:Section({ Title = "关于", Icon = "info", Opened = true })
	para(SecAbout, "作者", "b站英吉利超入", "users")
	para(SecAbout, "版本", "正式版 1.0.0", "tag")
	para(SecAbout, "适配游戏", "代发货大亨（Dropshipping Tycoon）", "play")
	para(SecAbout, "说明", "本页只做功能说明与使用指引，不含任何源码。", "info")

	local SecPrinciple = TabInfo:Section({ Title = "核心原理（为什么稳）", Icon = "zap", Opened = false })
	para(SecPrinciple, "订单驱动而非固定循环",
		"脚本不跑死板的步骤序列，而是实时读取每一张订单的状态，只执行该状态对应的那一步；没有进行中的订单时绝不空跑，因此不会乱花钱、也不会误触发。",
		"clipboard-list")
	para(SecPrinciple, "哪些操作与位置无关",
		"接单、买原材料、解锁商品、投放广告、招聘员工、领取奖励等属于服务器远程调用，角色站在原地也能生效。",
		"link")
	para(SecPrinciple, "哪些操作必须人到位置",
		"取原始包裹、放上传送带、取成品箱、交快递员、点升级按钮属于服务器校验距离的交互（约 12 格），人必须在交互点旁边才会被受理。",
		"move")
	para(SecPrinciple, "微传送机制",
		"脚本会瞬间把角色挪到交互点旁，等待服务器同步坐标（默认 0.30 秒）再触发，随后回到原处。实测「触发完立刻回位」会被服务器判为距离不足而丢弃动作，所以脚本改成停在原地等状态确认，最多 1.4 秒，未确认就再补一次。",
		"scan-eye")
	para(SecPrinciple, "传送带节奏",
		"成品箱会沿传送带移动，服务器只在箱子抵达末端那一刻才开放取件。脚本严格以该开放信号为准，绝不提前抢跑，因此不会出现「箱子还在带子中间就被取走」的假动作。",
		"move-horizontal")
	para(SecPrinciple, "并发上限跟随游戏",
		"能不能再接新单由游戏自己的履约位决定；包裹交到快递员处后游戏会立刻释放履约位，脚本据此判断，因此不会出现「游戏允许接单但脚本不接」的情况。",
		"layers")

	local SecFeatures = TabInfo:Section({ Title = "功能清单", Icon = "list-checks", Opened = false })
	para(SecFeatures, "订单流水线",
		"接单 → 取原始包裹 → 放上传送带 → 等待打包 → 取成品箱 → 交快递员 → 等待结算，全程按订单状态推进，任一步卡住都会自动重试。",
		"repeat")
	para(SecFeatures, "自动接单",
		"支持价格区间、爆款筛选、产品白名单与黑名单、优先级（价格最高 / 爆款 / 最早），并发上限自动跟随游戏允许的履约数。",
		"clipboard-check")
	para(SecFeatures, "自动补货",
		"按库存阈值与批量自动采购原材料，带现金下限保护；仓库见底时流水线也会自行补货，两条路径共用节流，不会重复下单。",
		"boxes")
	para(SecFeatures, "自动购买商品",
		"自动解锁尚未拥有的商品，支持单价上限、现金保留与白名单 / 黑名单。",
		"package-plus")
	para(SecFeatures, "自动招聘员工",
		"按岗位、最低等级、薪资上限从招聘中心挑选员工，支持岗位白名单 / 黑名单、自动补工位、候选人为空时花宝石重掷。",
		"user-plus")
	para(SecFeatures, "自动发送广告",
		"自动走完「录制 → 等录制完成 → 投放」全流程，支持选品来源、时长（300 / 600 秒）、单次花费上限、现金保留与续投阈值。",
		"megaphone")
	para(SecFeatures, "自动运营",
		"自动领取任务与每日奖励、按满意度阈值自动送员工休假、自动训练员工、自动研究、自动接合同（需先建办公室，否则自动跳过）。",
		"workflow")
	para(SecFeatures, "AI 自动调参",
		"用真实运行数据改配置：按动作确认失败率调时序、按仓库容量调补货、按游戏并发与传送带条数调接单并发、按现金调各模块预算、按现金在 300 / 600 秒之间切换广告时长。每一项都可单独关闭，并会记录每次调整原因。",
		"cpu")
	para(SecFeatures, "传送带模块",
		"自动读取传送带条数与等级（等级最高 3，后期最多 3 条），条数与等级会参与 AI 的并发判断；升级点开放且资金充足时可自动升级。",
		"move-horizontal")
	para(SecFeatures, "悬浮看板",
		"常驻数值面板，鼠标可直接拖动，位置自动保存；显示现金、宝石、仓库、订单、搬运、阶段、接单、补货、购买、广告等实时信息。",
		"monitor")
	para(SecFeatures, "配置系统",
		"全部设置自动存盘，支持多套配置档案的保存 / 载入 / 设为自动载入 / 删除，切换配置即切换整套策略。",
		"save")

	local SecHow = TabInfo:Section({ Title = "使用指引", Icon = "compass", Opened = false })
	para(SecHow, "开关窗口", "默认右 Shift，可在「外观」页改成其他按键。", "keyboard")
	para(SecHow, "手动单步",
		"「流水线」页底部有分步按钮，可单独执行接单 / 取货 / 上带 / 取成品 / 交件，便于观察或人工干预。",
		"mouse-pointer-click")
	para(SecHow, "单例保护",
		"重复加载脚本会自动卸载上一个实例，避免双份触发导致双倍花钱。", "check-check")
	para(SecHow, "卸载",
		"「工具」页危险区可卸载脚本，会先关停全部自动化并保存配置。", "power")
	para(SecHow, "界面导航",
		"点击左侧页签切换模块：流水线 / 自动接单 / 补货 / 自动购买 / 自动广告 / 自动运营 / AI 调参 / 传送带 / 看板 / 外观 / 配置 / 工具。",
		"layout-grid")

	local SecFAQ = TabInfo:Section({ Title = "常见问题", Icon = "info", Opened = false })
	para(SecFAQ, "为什么窗口没出现",
		"界面库需要联网加载，网络不通时会失败；此时悬浮看板与全部自动化仍会正常运行。", "triangle-alert")
	para(SecFAQ, "为什么动作没生效",
		"说明服务器拒绝了这次交互。把「传送前等待」调大一些，或直接开启 AI 调参里的「时序自适应」由脚本自行收敛。",
		"triangle-alert")
	para(SecFAQ, "为什么箱子不取",
		"成品箱必须抵达传送带末端才会开放取件，脚本会等这个信号，属正常等待，不是卡住。", "triangle-alert")
	para(SecFAQ, "为什么提示点找不到",
		"确认角色停在自己的地块内；可在「工具」页输出提示点列表排查。", "triangle-alert")

	---------------------------------------------------------------------
	-- Tab 1 · 流水线
	---------------------------------------------------------------------
	local TabPipe = mkTab({ Title = "流水线", Icon = "move-horizontal" })
	local SecMain = TabPipe:Section({ Title = "主控（订单驱动）", Icon = "play", Opened = true })

	toggle(SecMain, "启用订单流水线",
		"按订单状态自动执行：接单 → 取货 → 上带 → 取成品 → 交件。无单不空跑。",
		"repeat", "pipe_on", cfg.pipe.on, function(v)
			cfg.pipe.on = v
			Notify("流水线", v and "已启用（订单驱动）" or "已停止", "repeat")
		end)
	toggle(SecMain, "触发后回到原位",
		"触发完立刻把角色放回原处，外观上人一直站着没动。",
		"undo-2", "pipe_restore", cfg.pipe.restore, function(v) cfg.pipe.restore = v end)
	toggle(SecMain, "拉大交互距离",
		"放宽提示点距离并关闭视线校验，上带可从远触发。",
		"scan-eye", "pipe_boost", cfg.pipe.boost, function(v)
			cfg.pipe.boost = v
			Prompt.at = 0   -- 立刻重扫一次
			Notify("交互距离", v and "已拉大" or "恢复默认", "scan-eye")
		end)
	toggle(SecMain, "缺货自动买货",
		"仓库没货卡住时自动买一次（会花钱，受现金下限保护）。",
		"link", "pipe_autorestock", cfg.pipe.autoRestock, function(v) cfg.pipe.autoRestock = v end)

	local SecLive = TabPipe:Section({ Title = "实时阶段", Icon = "activity", Opened = true })
	UI.pOrder  = para(SecLive, "当前订单", "—", "clipboard-list")
	UI.pPhase  = para(SecLive, "阶段", "—", "git-branch")
	UI.pDetail = para(SecLive, "细节", "—", "info")

	local SecSpeed = TabPipe:Section({ Title = "时序与位移", Icon = "wrench", Opened = false })
	slider(SecSpeed, "动作间隔", "两次触发之间的最小间隔（秒）", "timer", "pipe_gap",
		cfg.pipe.gap, 0.05, 1.5, 0.05, function(v) cfg.pipe.gap = v end)
	slider(SecSpeed, "微传送抬高", "闪现时抬高多少，太低会卡进模型", "compass", "pipe_tph",
		cfg.pipe.tpHeight, 1, 8, 0.5, function(v) cfg.pipe.tpHeight = v end)
	slider(SecSpeed, "传送前等待", "闪过去到触发之间的等待（运行时下限 0.18）", "timer", "pipe_prewait",
		cfg.pipe.preWait, 0.10, 0.60, 0.02, function(v) cfg.pipe.preWait = v end)
	slider(SecSpeed, "回位前等待", "状态确认后再等多久回原位（别调太小）", "undo-2", "pipe_postwait",
		cfg.pipe.postWait, 0.05, 0.80, 0.05, function(v) cfg.pipe.postWait = v end)

	local SecManual = TabPipe:Section({ Title = "手动单步", Icon = "mouse-pointer-click", Opened = false })
	local function stepBtn(title, icon, fn)
		mk("Button", SecManual, {
			Title = title, Icon = icon,
			Callback = function()
				local ok, msg = fn()
				Notify("手动", ok and (msg or "已触发") or (msg or "条件不满足"),
					ok and icon or "triangle-alert")
			end,
		})
	end
	stepBtn("① 自动接一单", "clipboard-check", function()
		local c = acCandidates()
		if #c == 0 then return false, "没有符合条件的 New 订单" end
		if not acceptOrder(c[1].id) then return false, "节流中，稍后再试" end
		return true, "已接 #" .. tostring(c[1].id)
	end)
	stepBtn("② 取原始包裹", "box", function()
		local p = findPrompt("Pick up package", isInLWS)
		if not p then return false, "仓库无 InStock 包裹" end
		actPrompt(p)
		return true, "已触发取货"
	end)
	stepBtn("③ 放上传送带", "move-horizontal", function()
		scanPrompts()
		local p = findPrompt("Put on conveyor", isInPlot)
		if not p then return false, "找不到提示点" end
		actPrompt(p)
		return true, "已触发上带"
	end)
	stepBtn("④ 取成品箱", "package-open", function()
		scanPrompts()
		local p = doneBoxPrompt()
		if not p then return false, "成品箱还没出来" end
		actPrompt(p)
		return true, "已触发取成品"
	end)
	stepBtn("⑤ 交给快递员", "truck", function()
		scanPrompts()
		local p = findPrompt("Leave for courier", isInPlot)
		if not p then return false, "找不到提示点" end
		actPrompt(p)
		return true, "已触发交件"
	end)

	---------------------------------------------------------------------
	-- Tab 2 · 自动接单
	---------------------------------------------------------------------
	local TabAC = mkTab({ Title = "自动接单", Icon = "clipboard-check" })
	local SecAC = TabAC:Section({ Title = "开关与策略", Icon = "power", Opened = true })

	toggle(SecAC, "启用自动接单",
		"有符合条件的新订单就接（独立于流水线开关）",
		"clipboard-check", "ac_on", cfg.ac.on, function(v)
			cfg.ac.on = v
			Notify("自动接单", v and "已启用" or "已停止", "clipboard-check")
		end)
	mk("Dropdown", SecAC, {
		Title = "优先级", Desc = "多个候选订单时先接哪一个", Icon = "arrow-down-wide-narrow",
		Flag = "ac_priority",
		Values = { "价格最高优先", "爆款优先", "订单最早优先" },
		Value = cfg.ac.priority,
		Callback = function(v) cfg.ac.priority = v cfgTouch() end,
	})
	toggle(SecAC, "仅接爆款单（Viral）", "只接 isViral = true 的订单", "flame",
		"ac_viral", cfg.ac.viralOnly, function(v) cfg.ac.viralOnly = v end)
	toggle(SecAC, "启用产品白名单", "开启后只接白名单里的产品", "list-filter",
		"ac_usewhite", cfg.ac.useWhite, function(v) cfg.ac.useWhite = v end)

	local SecFilter = TabAC:Section({ Title = "价格与并发", Icon = "wrench", Opened = true })
	slider(SecFilter, "最低价格", "低于此价格不接（0 = 不限）", "trending-down", "ac_minp",
		cfg.ac.minPrice, 0, 500, 1, function(v) cfg.ac.minPrice = v end)
	slider(SecFilter, "最高价格", "高于此价格不接（0 = 不限）", "trending-up", "ac_maxp",
		cfg.ac.maxPrice, 0, 5000, 10, function(v) cfg.ac.maxPrice = v end)
	slider(SecFilter, "最大同时进行", "同时处于履约中的订单上限", "layers", "ac_maxactive",
		cfg.ac.maxActive, 1, 5, 1, function(v) cfg.ac.maxActive = v end)
	slider(SecFilter, "检查间隔", "多久扫一次可接订单（秒）", "clock", "ac_interval",
		cfg.ac.interval, 0.2, 5, 0.1, function(v) cfg.ac.interval = v end)

	local SecWL = TabAC:Section({ Title = "白名单 / 黑名单", Icon = "list-checks", Opened = true })
	local prodVals = productList()
	local whiteSel, blackSel = {}, {}
	for k in pairs(cfg.ac.white) do whiteSel[#whiteSel + 1] = k end
	for k in pairs(cfg.ac.black) do blackSel[#blackSel + 1] = k end
	mk("Dropdown", SecWL, {
		Title = "白名单产品", Desc = "多选，需开启白名单",
		Icon = "check-check", Flag = "ac_white", Values = prodVals,
		Multi = true, AllowNone = true, SearchBarEnabled = true,
		Callback = function(sel)
			cfg.ac.white = {}
			if type(sel) == "table" then
				for _, v in pairs(sel) do cfg.ac.white[tostring(v)] = true end
			elseif type(sel) == "string" then cfg.ac.white[sel] = true end
			cfgTouch()
		end,
	})
	mk("Dropdown", SecWL, {
		Title = "黑名单产品", Desc = "多选；这些产品永不接单",
		Icon = "ban", Flag = "ac_black", Values = prodVals,
		Multi = true, AllowNone = true, SearchBarEnabled = true,
		Callback = function(sel)
			cfg.ac.black = {}
			if type(sel) == "table" then
				for _, v in pairs(sel) do cfg.ac.black[tostring(v)] = true end
			elseif type(sel) == "string" then cfg.ac.black[sel] = true end
			cfgTouch()
		end,
	})
	UI.pAC = para(SecWL, "当前可接订单", "—", "clipboard-list")

	---------------------------------------------------------------------
	-- Tab 3 · 补货
	---------------------------------------------------------------------
	local TabRest = mkTab({ Title = "补货", Icon = "boxes" })
	local SecRest = TabRest:Section({ Title = "自动补货", Icon = "truck", Opened = true })
	toggle(SecRest, "启用自动补货",
		"库存低于阈值自动买货（真花钱）",
		"repeat", "rst_on", cfg.restock.on, function(v)
			cfg.restock.on = v
			Notify("补货", v and "已启用" or "已停止", "truck")
		end)
	mk("Dropdown", SecRest, {
		Title = "补货产品来源", Desc = "决定补哪个产品", Icon = "shopping-cart",
		Flag = "rst_mode",
		Values = { "跟随进行中订单", "跟随当前产品", "指定产品" },
		Value = cfg.restock.mode,
		Callback = function(v) cfg.restock.mode = v cfgTouch() end,
	})
	local prodVals2 = productList()
	prodVals2[#prodVals2 + 1] = "（不指定）"
	mk("Dropdown", SecRest, {
		Title = "指定产品", Desc = "仅在“补货产品来源 = 指定产品”时生效",
		Icon = "package", Flag = "rst_product", Values = prodVals2,
		Value = (cfg.restock.product ~= "" and cfg.restock.product) or "（不指定）",
		SearchBarEnabled = true,
		Callback = function(v)
			cfg.restock.product = (v == "（不指定）") and "" or tostring(v)
			cfgTouch()
		end,
	})
	local SecRestNum = TabRest:Section({ Title = "阈值与数量", Icon = "wrench", Opened = true })
	slider(SecRestNum, "库存阈值", "低于此值就补货", "gauge", "rst_low",
		cfg.restock.low, 1, 50, 1, function(v) cfg.restock.low = v end)
	slider(SecRestNum, "每次补货数量", "一次买多少个（约 12/个）", "package", "rst_batch",
		cfg.restock.batch, 1, 50, 1, function(v) cfg.restock.batch = v end)
	slider(SecRestNum, "检查间隔", "多久检查一次库存（秒）", "clock", "rst_interval",
		cfg.restock.interval, 2, 60, 1, function(v) cfg.restock.interval = v end)
	slider(SecRestNum, "现金下限", "现金低于此值就不补货，避免破产", "banknote", "rst_floor",
		cfg.restock.cashFloor, 0, 5000, 10, function(v) cfg.restock.cashFloor = v end)

	local SecRestAct = TabRest:Section({ Title = "操作", Icon = "zap", Opened = true })
	mk("Button", SecRestAct, {
		Title = "立即补货一次（忽略阈值）", Icon = "zap",
		Callback = function()
			local ok, msg = doRestock(true)
			Notify("补货", msg or (ok and "已下单" or "失败"), ok and "zap" or "triangle-alert")
		end,
	})
	UI.pRest = para(SecRestAct, "补货状态", "—", "truck")

	---------------------------------------------------------------------
	-- Tab 4 · 自动购买 / 自动招聘
	---------------------------------------------------------------------
	local TabBuy = mkTab({ Title = "自动购买", Icon = "shopping-cart" })

	local SecBP = TabBuy:Section({ Title = "商品解锁", Icon = "package-plus", Opened = true })
	toggle(SecBP, "自动解锁商品",
		"有预算就解锁未拥有的商品（UnlockProduct）", "package-plus", "bp_on", cfg.buyprod.on,
		function(v)
			cfg.buyprod.on = v
			Notify("自动购买", v and "商品解锁已启用" or "已停止", "package-plus")
		end)
	slider(SecBP, "单价上限", "超过这个价不解锁（0 = 不限）", "trending-up", "bp_maxp",
		cfg.buyprod.maxPrice, 0, 100000, 100, function(v) cfg.buyprod.maxPrice = v end)
	slider(SecBP, "现金保留", "买完至少要留这么多现金", "banknote", "bp_floor",
		cfg.buyprod.cashFloor, 0, 50000, 50, function(v) cfg.buyprod.cashFloor = v end)
	slider(SecBP, "检查间隔", "多久检查一次（秒）", "clock", "bp_interval",
		cfg.buyprod.interval, 1, 60, 1, function(v) cfg.buyprod.interval = v end)
	local bpVals = productList()
	mk("Dropdown", SecBP, {
		Title = "只买这些商品（白名单）", Desc = "空 = 全部；多选", Icon = "list-filter",
		Flag = "bp_allow", Values = bpVals, Multi = true, AllowNone = true, SearchBarEnabled = true,
		Callback = function(sel)
			cfg.buyprod.allow = {}
			if type(sel) == "table" then for _, v in pairs(sel) do cfg.buyprod.allow[tostring(v)] = true end
			elseif type(sel) == "string" then cfg.buyprod.allow[sel] = true end
			cfgTouch()
		end,
	})
	mk("Dropdown", SecBP, {
		Title = "永不购买（黑名单）", Desc = "多选；优先级高于白名单", Icon = "ban",
		Flag = "bp_deny", Values = bpVals, Multi = true, AllowNone = true, SearchBarEnabled = true,
		Callback = function(sel)
			cfg.buyprod.deny = {}
			if type(sel) == "table" then for _, v in pairs(sel) do cfg.buyprod.deny[tostring(v)] = true end
			elseif type(sel) == "string" then cfg.buyprod.deny[sel] = true end
			cfgTouch()
		end,
	})
	mk("Button", SecBP, {
		Title = "立即解锁一次", Icon = "zap",
		Callback = function()
			local ok, msg = doBuyProd(false)
			Notify("自动购买", msg or (ok and "已解锁" or "失败"), ok and "zap" or "triangle-alert")
		end,
	})
	UI.pBuy = para(SecBP, "商品解锁状态", "—", "package-plus")

	local SecHire = TabBuy:Section({ Title = "员工招聘", Icon = "user-plus", Opened = true })
	toggle(SecHire, "自动招聘员工",
		"按条件从 JobCenter 候选人里招人（HireEmployee）", "user-plus", "hr_on", cfg.hire.on,
		function(v)
			cfg.hire.on = v
			Notify("自动招聘", v and "已启用" or "已停止", "user-plus")
		end)
	mk("Dropdown", SecHire, {
		Title = "最低等级", Desc = "低于该等级的候选人直接跳过", Icon = "graduation-cap",
		Flag = "hr_lvl", Values = { "无要求", "Noob 及以上", "Pro 及以上", "Expert 及以上" },
		Value = cfg.hire.minLevel,
		Callback = function(v) cfg.hire.minLevel = v cfgTouch() end,
	})
	slider(SecHire, "薪资上限", "单个员工最高出价（0 = 不限）", "trending-up", "hr_maxp",
		cfg.hire.maxPrice, 0, 100000, 50, function(v) cfg.hire.maxPrice = v end)
	slider(SecHire, "现金保留", "招完至少留这么多现金", "banknote", "hr_floor",
		cfg.hire.cashFloor, 0, 50000, 50, function(v) cfg.hire.cashFloor = v end)
	slider(SecHire, "检查间隔", "多久看一次候选人（秒）", "clock", "hr_interval",
		cfg.hire.interval, 2, 120, 1, function(v) cfg.hire.interval = v end)
	local roleVals = {}
	do
		local seen = {}
		for _, r in ipairs((G.jobs and G.jobs.roles) or {}) do
			local id = tostring(r.id or r.name or "")
			if id ~= "" and not seen[id] then seen[id] = true roleVals[#roleVals + 1] = id end
		end
		for k in pairs((G.employees and G.employees.slots) or {}) do
			local id = tostring(k)
			if not seen[id] then seen[id] = true roleVals[#roleVals + 1] = id end
		end
		if #roleVals == 0 then
			roleVals = { "WarehouseWorker", "Manager", "MarketingSpecialist",
				"HrSpecialist", "ForkliftDriver", "FactoryWorker" }
		end
		table.sort(roleVals)
	end
	mk("Dropdown", SecHire, {
		Title = "岗位白名单", Desc = "空 = 所有岗位；多选", Icon = "briefcase",
		Flag = "hr_roles", Values = roleVals, Multi = true, AllowNone = true, SearchBarEnabled = true,
		Callback = function(sel)
			cfg.hire.roles = {}
			if type(sel) == "table" then for _, v in pairs(sel) do cfg.hire.roles[tostring(v)] = true end
			elseif type(sel) == "string" then cfg.hire.roles[sel] = true end
			cfgTouch()
		end,
	})
	mk("Dropdown", SecHire, {
		Title = "岗位黑名单", Desc = "多选；这些岗位永不招", Icon = "user-x",
		Flag = "hr_deny", Values = roleVals, Multi = true, AllowNone = true, SearchBarEnabled = true,
		Callback = function(sel)
			cfg.hire.denyRoles = {}
			if type(sel) == "table" then for _, v in pairs(sel) do cfg.hire.denyRoles[tostring(v)] = true end
			elseif type(sel) == "string" then cfg.hire.denyRoles[sel] = true end
			cfgTouch()
		end,
	})

	local SecHire2 = TabBuy:Section({ Title = "工位与刷新", Icon = "wrench", Opened = false })
	toggle(SecHire2, "自动购买员工工位",
		"工位没解锁且钱够时自动买（BuyWorkerSlot）", "layout-grid", "hr_wslot",
		cfg.hire.autoWorkerSlot, function(v) cfg.hire.autoWorkerSlot = v end)
	toggle(SecHire2, "候选人为空时宝石重掷",
		"没人可招时花 5 宝石刷新候选人（RefreshJobs）", "dices", "hr_refresh",
		cfg.hire.autoRefresh, function(v) cfg.hire.autoRefresh = v end)
	slider(SecHire2, "宝石保留", "重掷后至少要留这么多宝石", "gem", "hr_gemfloor",
		cfg.hire.gemFloor, 0, 500, 1, function(v) cfg.hire.gemFloor = v end)
	mk("Button", SecHire2, {
		Title = "立即招聘一次", Icon = "zap",
		Callback = function()
			local ok, msg = doHire(false)
			Notify("自动招聘", msg or (ok and "已雇佣" or "失败"), ok and "zap" or "triangle-alert")
		end,
	})
	mk("Button", SecHire2, {
		Title = "花宝石重掷候选人", Icon = "dices",
		Callback = function()
			local _, msg = refreshCandidates()
			Notify("自动招聘", msg or "—", "dices")
		end,
	})
	UI.pHire = para(SecHire2, "招聘状态", "—", "user-plus")

	---------------------------------------------------------------------
	-- Tab 5 · 自动广告
	---------------------------------------------------------------------
	local TabAd = mkTab({ Title = "自动广告", Icon = "megaphone" })
	local SecAd = TabAd:Section({ Title = "投放策略", Icon = "megaphone", Opened = true })
	toggle(SecAd, "自动投放广告",
		"自动 录制 → 等录制完成 → 发布（RecordAd / PublishAd）", "megaphone", "ad_on", cfg.ad.on,
		function(v)
			cfg.ad.on = v
			Ad.last = v and "已启用" or "已停止"
			Notify("自动广告", v and "已启用" or "已停止", "megaphone")
		end)
	mk("Dropdown", SecAd, {
		Title = "广告商品来源", Desc = "决定投哪个商品", Icon = "package",
		Flag = "ad_pmode", Values = { "跟随广告位", "跟随当前产品", "指定" },
		Value = cfg.ad.productMode,
		Callback = function(v) cfg.ad.productMode = v cfgTouch() end,
	})
	local adVals = productList()
	mk("Dropdown", SecAd, {
		Title = "指定商品", Desc = "仅在来源 = 指定 时生效", Icon = "package-search",
		Flag = "ad_product", Values = adVals, Value = (cfg.ad.product ~= "" and cfg.ad.product) or (adVals[1] or ""),
		SearchBarEnabled = true,
		Callback = function(v) cfg.ad.product = tostring(v or "") cfgTouch() end,
	})
	mk("Dropdown", SecAd, {
		Title = "广告时长", Desc = "影响花费（300s 便宜，600s 贵）", Icon = "hourglass",
		Flag = "ad_dur", Values = { "300", "600" }, Value = tostring(cfg.ad.duration),
		Callback = function(v) cfg.ad.duration = tonumber(v) or 600 cfgTouch() end,
	})
	toggle(SecAd, "自动选品",
		"投放前先调 SelectAdProduct 选中目标商品", "mouse-pointer-click", "ad_select",
		cfg.ad.autoSelect, function(v) cfg.ad.autoSelect = v end)
	toggle(SecAd, "爆款联动",
		"优先投当期爆款商品（只挑已解锁的，爆款有倍率加成）", "flame", "ad_viral",
		cfg.ad.viralFollow, function(v)
			cfg.ad.viralFollow = v
			requestViral()
			Notify("自动广告", v and "已跟随当期爆款" or "已关闭爆款联动", "flame")
		end)

	local SecAd2 = TabAd:Section({ Title = "预算与节奏", Icon = "wrench", Opened = true })
	slider(SecAd2, "单次花费上限", "超过就不投（0 = 不限）", "trending-up", "ad_maxcost",
		cfg.ad.maxCost, 0, 5000, 10, function(v) cfg.ad.maxCost = v end)
	slider(SecAd2, "现金保留", "投完至少留这么多现金", "banknote", "ad_floor",
		cfg.ad.cashFloor, 0, 50000, 50, function(v) cfg.ad.cashFloor = v end)
	slider(SecAd2, "续投阈值", "当前广告剩余低于此秒数才续投", "timer-reset", "ad_minleft",
		cfg.ad.minLeft, 0, 600, 5, function(v) cfg.ad.minLeft = v end)
	slider(SecAd2, "检查间隔", "多久检查一次广告状态（秒）", "clock", "ad_interval",
		cfg.ad.interval, 1, 60, 1, function(v) cfg.ad.interval = v end)
	mk("Button", SecAd2, {
		Title = "立即投一次", Icon = "zap",
		Callback = function()
			local ok, msg = doAdOnce()
			Notify("自动广告", msg or (ok and "已开始" or "失败"), ok and "zap" or "triangle-alert")
		end,
	})
	mk("Button", SecAd2, {
		Title = "刷新广告状态（拉取 CampaignState）", Icon = "refresh-cw",
		Callback = function()
			requestCampaigns()
			Notify("自动广告", "已请求刷新", "refresh-cw")
		end,
	})
	UI.pAd = para(SecAd2, "广告状态", "—", "megaphone")

	---------------------------------------------------------------------
	-- Tab 6 · 自动运营
	---------------------------------------------------------------------
	local TabOps = mkTab({ Title = "自动运营", Icon = "workflow" })
	local SecClaim = TabOps:Section({ Title = "自动领取", Icon = "gift", Opened = true })
	toggle(SecClaim, "自动领取（任务 / 每日）",
		"已完成未领的任务自动领，每日奖励到点自动领", "gift", "op_claim", cfg.ops.claim,
		function(v)
			cfg.ops.claim = v
			Notify("自动领取", v and "已启用" or "已停止", "gift")
		end)
	slider(SecClaim, "检查间隔", "多久查一次可领取（秒）", "clock", "op_claim_iv",
		cfg.ops.claimInterval, 5, 300, 5, function(v) cfg.ops.claimInterval = v end)
	mk("Button", SecClaim, {
		Title = "一键全领一次", Desc = "含离线收益 / 社区目标等全部领取口", Icon = "hand-coins",
		Callback = function()
			local did = {}
			for _, n in ipairs({ "DailyClaim", "OfflineCollect", "CommunityGoalClaim",
				"QuestClaimBonus", "ArcadeWeekly" }) do
				local r = Remotes and Remotes:FindFirstChild(n)
				if r and safe(function() r:FireServer() end) then did[#did + 1] = n end
			end
			safe(opsClaimTick)
			Notify("自动领取", #did > 0 and table.concat(did, "、") or "无可用领取口",
				#did > 0 and "hand-coins" or "triangle-alert")
		end,
	})
	UI.pClaim = para(SecClaim, "领取状态", "—", "gift")

	local SecStaff = TabOps:Section({ Title = "员工管理", Icon = "users", Opened = true })
	toggle(SecStaff, "自动送休假",
		"满意度低于阈值且不在休假的员工，自动 SendVacation", "plane", "op_vac", cfg.ops.vacation,
		function(v)
			cfg.ops.vacation = v
			Notify("员工休假", v and "已启用" or "已停止", "plane")
		end)
	slider(SecStaff, "满意度阈值", "低于此值就送休假", "heart-crack", "op_vacth",
		cfg.ops.vacThreshold, 0, 100, 5, function(v) cfg.ops.vacThreshold = v end)
	slider(SecStaff, "检查间隔", "多久检查一次员工状态（秒）", "clock", "op_vac_iv",
		cfg.ops.vacInterval, 5, 300, 5, function(v) cfg.ops.vacInterval = v end)
	toggle(SecStaff, "自动训练员工",
		"可训练且钱够时自动 StartTraining（目标等级由游戏决定）", "dumbbell", "op_train",
		cfg.ops.train, function(v)
			cfg.ops.train = v
			Notify("员工训练", v and "已启用" or "已停止", "dumbbell")
		end)
	slider(SecStaff, "训练现金保留", "报名训练后至少留这么多现金", "banknote", "op_trainfloor",
		cfg.ops.trainFloor, 0, 50000, 50, function(v) cfg.ops.trainFloor = v end)
	slider(SecStaff, "训练检查间隔", "多久检查一次（秒）", "clock", "op_train_iv",
		cfg.ops.trainInterval, 5, 600, 5, function(v) cfg.ops.trainInterval = v end)
	UI.pStaff = para(SecStaff, "员工状态", "—", "users")

	local SecOth = TabOps:Section({ Title = "研究与合同", Icon = "flask-conical", Opened = true })
	toggle(SecOth, "自动研究", "后期内容：商品研究等级自动升（当前可能仍被门禁）",
		"flask-conical", "op_res", cfg.ops.research,
		function(v)
			cfg.ops.research = v
			Notify("自动研究", v and "已启用" or "已停止", "flask-conical")
		end)
	slider(SecOth, "研究现金保留", "升级后至少留这么多现金", "banknote", "op_resfloor",
		cfg.ops.researchFloor, 0, 100000, 100, function(v) cfg.ops.researchFloor = v end)
	slider(SecOth, "研究检查间隔", "多久检查一次（秒）", "clock", "op_res_iv",
		cfg.ops.researchInterval, 10, 900, 10, function(v) cfg.ops.researchInterval = v end)
	toggle(SecOth, "自动接合同",
		"库存够时自动接（需先建办公室，否则会自动跳过）", "link", "op_con",
		cfg.ops.contract, function(v)
			cfg.ops.contract = v
			Notify("自动合同", v and "已启用" or "已停止", "link")
		end)
	slider(SecOth, "合同检查间隔", "多久检查一次可接合同（秒）", "clock", "op_con_iv",
		cfg.ops.contractInterval, 10, 900, 10, function(v) cfg.ops.contractInterval = v end)
	UI.pOth = para(SecOth, "研究与合同", "—", "flask-conical")

	---------------------------------------------------------------------
	-- Tab 7 · AI 调参
	---------------------------------------------------------------------
	local TabAI = mkTab({ Title = "AI 调参", Icon = "cpu" })
	local SecAI = TabAI:Section({ Title = "AI 自动调参", Icon = "cpu", Opened = true })
	toggle(SecAI, "启用 AI 自动调参",
		"读实时数据，自动改时序 / 补货 / 并发 / 预算 / 广告节奏", "cpu", "ai_on", cfg.ai.on,
		function(v)
			cfg.ai.on = v
			AI.at = 0
			Notify("AI 调参", v and "已启用（每轮都会写回配置）" or "已停止", "cpu")
		end)
	mk("Dropdown", SecAI, {
		Title = "调节强度", Desc = "保守=小步慢调 · 激进=大幅快速", Icon = "gauge",
		Flag = "ai_style", Values = { "保守", "标准", "激进" }, Value = cfg.ai.style,
		Callback = function(v) cfg.ai.style = tostring(v) cfgTouch() end,
	})
	slider(SecAI, "决策间隔", "多久做一次判断（秒）", "clock", "ai_iv",
		cfg.ai.interval, 3, 120, 1, function(v) cfg.ai.interval = v end)
	mk("Button", SecAI, {
		Title = "立即调一次", Icon = "zap",
		Callback = function()
			AI.at = 0
			local wasOn = cfg.ai.on
			if not wasOn then cfg.ai.on = true end
			safe(aiTick)
			cfg.ai.on = wasOn
			Notify("AI 调参", cfg.ai.note or "已执行", "zap")
		end,
	})
	mk("Button", SecAI, {
		Title = "清空调整记录", Icon = "eraser",
		Callback = function()
			AI.changes = {}
			AI.runs = 0
			Notify("AI 调参", "记录已清空", "eraser")
		end,
	})
	UI.pAI = para(SecAI, "当前判断", "—", "cpu")
	UI.pAIChg = para(SecAI, "最近调整", "—", "scroll-text")

	local SecKnob = TabAI:Section({ Title = "允许 AI 调整的项目", Icon = "wrench", Opened = true })
	toggle(SecKnob, "时序自适应", "按动作确认失败率动态调传送前等待", "timer", "ai_timing",
		cfg.ai.timing, function(v) cfg.ai.timing = v end)
	toggle(SecKnob, "补货阈值", "按仓库容量比例调补货阈/批量，见底自动买货", "boxes", "ai_restock",
		cfg.ai.restock, function(v) cfg.ai.restock = v end)
	toggle(SecKnob, "接单并发", "跟随 maxFulfillments，且不超过传送带条数", "layers", "ai_conc",
		cfg.ai.concurrency, function(v) cfg.ai.concurrency = v end)
	toggle(SecKnob, "预算比例", "各模块的「现金保留 / 薪资上限」按现况现金定", "banknote", "ai_budget",
		cfg.ai.budget, function(v) cfg.ai.budget = v end)
	toggle(SecKnob, "广告节奏", "按现金在 600s / 300s 之间切换并调续投线", "megaphone", "ai_ad",
		cfg.ai.adPace, function(v) cfg.ai.adPace = v end)
	toggle(SecKnob, "传送带感知", "考虑传送带条数/等级（最多 3 条）", "scan-eye", "ai_conv",
		cfg.ai.conveyorAware, function(v) cfg.ai.conveyorAware = v end)
	slider(SecKnob, "传送前等待下限", "AI 不会把等待调到低于此值", "arrow-down-narrow-wide", "ai_pwmin",
		cfg.ai.preWaitMin, 0.10, 0.50, 0.02, function(v) cfg.ai.preWaitMin = v end)
	slider(SecKnob, "传送前等待上限", "AI 最多把等待调到这个值", "arrow-up-narrow-wide", "ai_pwmax",
		cfg.ai.preWaitMax, 0.20, 1.00, 0.05, function(v) cfg.ai.preWaitMax = v end)
	mk("Button", SecKnob, {
		Title = "把时序恢复成实机安全值", Icon = "rotate-ccw",
		Callback = function()
			cfg.pipe.preWait, cfg.pipe.postWait, cfg.pipe.gap = 0.30, 0.30, 0.30
			cfgTouch()
			Notify("AI 调参", "时序已恢复 0.30/0.30/0.30", "rotate-ccw")
		end,
	})

	---------------------------------------------------------------------
	-- Tab 8 · 传送带（独立模块，最多 3 条）
	---------------------------------------------------------------------
	local TabConv = mkTab({ Title = "传送带", Icon = "move-horizontal" })
	local SecConv = TabConv:Section({ Title = "传送带（最多 3 条）", Icon = "move-horizontal", Opened = true })
	UI.pConv = para(SecConv, "传送带状态", "—", "move-horizontal")
	toggle(SecConv, "自动检测条数与等级",
		"从地块 UpgradePanel 读取 CONVEYOR N / LEVEL x/3", "scan-eye", "cv_auto",
		cfg.conv.auto, function(v) cfg.conv.auto = v readConv(true) end)
	slider(SecConv, "最大条数", "后期最多 3 条，用来给并发留上限", "layers", "cv_max",
		cfg.conv.maxCount, 1, 3, 1, function(v) cfg.conv.maxCount = v readConv(true) end)
	toggle(SecConv, "自动升级传送带",
		"升级点开放（Enabled=true）且钱够时自动点 UPGRADE", "circle-arrow-up", "cv_upg",
		cfg.conv.autoUpgrade, function(v)
			cfg.conv.autoUpgrade = v
			Notify("传送带", v and "自动升级已启用" or "已停止", "circle-arrow-up")
		end)
	slider(SecConv, "升级后现金保留", "升级后至少留这么多现金", "banknote", "cv_floor",
		cfg.conv.upgradeFloor, 0, 100000, 100, function(v) cfg.conv.upgradeFloor = v end)
	mk("Button", SecConv, {
		Title = "立即尝试升级", Icon = "circle-arrow-up",
		Callback = function()
			local ok, msg = convUpgrade()
			Notify("传送带", msg or (ok and "已触发" or "失败"), ok and "circle-arrow-up" or "triangle-alert")
		end,
	})
	UI.pConvLog = para(SecConv, "升级结果", "—", "info")

	---------------------------------------------------------------------
	-- Tab 9 · 看板
	---------------------------------------------------------------------
	local TabDash = mkTab({ Title = "看板", Icon = "gauge" })
	local SecDash = TabDash:Section({ Title = "实时数值", Icon = "activity", Opened = true })
	UI.dCash  = para(SecDash, "现金", "—", "banknote")
	UI.dGems  = para(SecDash, "宝石", "—", "gem")
	UI.dWear  = para(SecDash, "仓库 / 库存", "—", "warehouse")
	UI.dOrder = para(SecDash, "订单", "—", "clipboard-list")
	UI.dCarry = para(SecDash, "搬运状态", "—", "move")
	UI.dProd  = para(SecDash, "当前产品", "—", "shopping-cart")
	UI.dFps   = para(SecDash, "FPS / Ping", "—", "activity")

	local SecHudCfg = TabDash:Section({ Title = "悬浮窗", Icon = "monitor", Opened = true })
	toggle(SecHudCfg, "屏幕悬浮看板",
		"常驻数值面板，可鼠标直接拖动。",
		"monitor", "hud_on", cfg.hud.on, function(v) cfg.hud.on = v hudVisible(v) end)
	local function applyHud(x, y)
		cfg.hud.x, cfg.hud.y = x, y
		if HUD.frame then safe(function() HUD.frame.Position = UDim2.new(0, x, 0, y) end) end
		cfgTouch()
	end
	slider(SecHudCfg, "悬浮窗 X", "水平位置（也可直接拖面板）", "compass", "hud_x",
		cfg.hud.x, 0, 1920, 1, function(v) applyHud(v, cfg.hud.y) end)
	slider(SecHudCfg, "悬浮窗 Y", "垂直位置（也可直接拖面板）", "layers", "hud_y",
		cfg.hud.y, 0, 1080, 1, function(v) applyHud(cfg.hud.x, v) end)
	mk("Button", SecHudCfg, {
		Title = "重置悬浮窗位置", Icon = "undo-2",
		Callback = function()
			applyHud(DEFAULTS.hud.x, DEFAULTS.hud.y)
			cfgSave(true)
			Notify("看板", "位置已重置", "undo-2")
		end,
	})
	mk("Button", SecHudCfg, {
		Title = "请求状态刷新", Icon = "refresh-cw",
		Callback = function() requestState() Notify("看板", "已请求刷新", "refresh-cw") end,
	})

	local SecGuard = TabDash:Section({ Title = "保护模式与统计", Icon = "boxes", Opened = true })
	toggle(SecGuard, "低现金自动刹车",
		"现金低于阈值时暂停一切花钱模块（广告 / 招聘 / 研究 / 解锁 / 升级 / 买货）",
		"boxes", "gd_on", cfg.guard.on, function(v)
			cfg.guard.on = v
			guardRefresh()
			Notify("保护模式", v and "已启用" or "已关闭", "boxes")
		end)
	slider(SecGuard, "刹车现金线", "低于此现金就刹车，只保留流水线", "banknote", "gd_floor",
		cfg.guard.cashFloor, 0, 100000, 50, function(v) cfg.guard.cashFloor = v guardRefresh() end)
	mk("Button", SecGuard, {
		Title = "重置本次会话统计", Icon = "rotate-ccw",
		Callback = function()
			Stat.startAt, Stat.gain, Stat.lastCash = os.clock(), 0, nil
			Exe.stats.total, Exe.stats.fail = 0, 0
			Notify("看板", "会话统计已重置", "rotate-ccw")
		end,
	})
	UI.dStat = para(SecGuard, "运行统计", "—", "activity")
	UI.dEcon = para(SecGuard, "收益效率", "—", "trending-up")
	UI.dFail = para(SecGuard, "动作确认率", "—", "check-check")
	UI.dViral = para(SecGuard, "当期爆款", "—", "flame")

	---------------------------------------------------------------------
	-- Tab 10 · 外观（WindUI 原生外观能力）
	---------------------------------------------------------------------
	local TabView = mkTab({ Title = "外观", Icon = "palette" })
	local SecTheme = TabView:Section({ Title = "主题", Icon = "palette", Opened = true })
	local themes = { "Dark" }
	safe(function()
		local t = WindUI:GetThemes()
		if type(t) == "table" then
			themes = {}
			for k, v in pairs(t) do themes[#themes + 1] = tostring(type(v) == "string" and v or k) end
			table.sort(themes)
		end
	end)
	mk("Dropdown", SecTheme, {
		Title = "界面主题", Desc = "WindUI 内置主题（共 " .. #themes .. " 个）",
		Icon = "swatch-book", Flag = "view_theme", Values = themes,
		Value = cfg.view.theme, SearchBarEnabled = true,
		Callback = function(v)
			cfg.view.theme = v
			cfgTouch()
			safe(function() WindUI:SetTheme(v) end)
			Notify("外观", "主题切换为 " .. tostring(v), "palette")
		end,
	})
	UI.pTheme = para(SecTheme, "当前主题", "—", "swatch-book")

	local SecLook = TabView:Section({ Title = "窗口外观", Icon = "layout-grid", Opened = true })
	slider(SecLook, "UI 缩放", "整个窗口的缩放比例", "zoom-in", "view_uiscale",
		cfg.view.uiScale, 0.6, 1.6, 0.05, function(v)
			cfg.view.uiScale = v
			safe(function() Window:SetUIScale(v) end)
		end)
	slider(SecLook, "窗口宽度", "窗口像素宽度", "move-horizontal", "view_w",
		cfg.view.width, 460, 1000, 10, function(v)
			cfg.view.width = v
			safe(function() Window:SetSize(UDim2.fromOffset(v, cfg.view.height)) end)
		end)
	slider(SecLook, "窗口高度", "窗口像素高度", "move-vertical", "view_h",
		cfg.view.height, 320, 700, 10, function(v)
			cfg.view.height = v
			safe(function() Window:SetSize(UDim2.fromOffset(cfg.view.width, v)) end)
		end)
	slider(SecLook, "背景透明度", "0 = 全不透明，1 = 全透明", "contrast", "view_bgtrans",
		cfg.view.bgTransparency, 0, 0.9, 0.05, function(v)
			cfg.view.bgTransparency = v
			safe(function() Window:SetBackgroundTransparency(v) end)
		end)
	toggle(SecLook, "窗口整体透明", "WindUI 的透明模式", "droplet", "view_trans",
		cfg.view.transparency, function(v)
			cfg.view.transparency = v
			safe(function() Window:ToggleTransparency() end)
		end)
	toggle(SecLook, "亚克力模糊", "背景模糊效果（较吃性能）", "sparkles", "view_acrylic",
		cfg.view.acrylic, function(v)
			cfg.view.acrylic = v
			safe(function() WindUI:ToggleAcrylic(v) end)
		end)
	toggle(SecLook, "显示面板背景", "关掉后内容区透明", "square-dashed", "view_panel",
		cfg.view.panelBg, function(v)
			cfg.view.panelBg = v
			safe(function() Window:SetPanelBackground(v) end)
		end)
	toggle(SecLook, "允许拖动缩放窗口", "关闭后窗口尺寸锁定", "move", "view_resizable",
		cfg.view.resizable, function(v) cfg.view.resizable = v end)

	local SecLookAct = TabView:Section({ Title = "快捷操作", Icon = "wand-sparkles", Opened = true })
	mk("Button", SecLookAct, {
		Title = "窗口居中", Icon = "align-center-horizontal",
		Callback = function() safe(function() Window:SetToTheCenter() end)
			Notify("外观", "已居中", "align-center-horizontal") end,
	})
	mk("Button", SecLookAct, {
		Title = "全屏 / 还原", Icon = "maximize",
		Callback = function() safe(function() Window:ToggleFullscreen() end)
			Notify("外观", "已切换全屏", "maximize") end,
	})
	mk("Button", SecLookAct, {
		Title = "切换亚克力（库级）", Icon = "sparkles",
		Callback = function() safe(function() WindUI:ToggleAcrylic() end)
			Notify("外观", "已切换亚克力", "sparkles") end,
	})
	local bgInput = mk("Input", SecLookAct, {
		Title = "窗口背景图", Desc = "rbxassetid:// 或 https 图片地址",
		Icon = "image", Flag = "view_bgimg",
		Value = cfg.view.bgImage, Placeholder = "rbxassetid://0",
		Callback = function(v)
			cfg.view.bgImage = tostring(v or "")
			cfgTouch()
		end,
	})
	mk("Button", SecLookAct, {
		Title = "应用背景图", Icon = "image-plus",
		Callback = function()
			if cfg.view.bgImage == "" then
				Notify("外观", "背景图地址为空", "triangle-alert") return
			end
			safe(function() Window:SetBackgroundImage(cfg.view.bgImage) end)
			Notify("外观", "背景图已应用", "image-plus")
		end,
	})
	mk("Button", SecLookAct, {
		Title = "清除背景图", Icon = "image-off",
		Callback = function()
			cfg.view.bgImage = ""
			cfgTouch()
			safe(function() Window:SetBackgroundImage("") end)
			Notify("外观", "背景图已清除", "image-off")
		end,
	})

	local SecKey = TabView:Section({ Title = "开关快捷键", Icon = "keyboard", Opened = true })
	local keyNames = {}
	for _, k in ipairs({ "RightShift", "LeftShift", "RightControl", "LeftControl",
		"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
		"K", "J", "H", "G", "P", "O", "U", "Y", "Insert", "Delete", "Home", "End" }) do
		keyNames[#keyNames + 1] = k
	end
	mk("Dropdown", SecKey, {
		Title = "开关窗口按键", Desc = "选中后立即生效", Icon = "keyboard",
		Flag = "view_togglekey", Values = keyNames, SearchBarEnabled = true,
		Value = cfg.view.toggleKey,
		Callback = function(v)
			cfg.view.toggleKey = tostring(v)
			cfgTouch()
			local kc = Enum.KeyCode[v]
			if kc then
				safe(function() Window:SetToggleKey(kc) end)
				Notify("外观", "开关键 = " .. tostring(v), "keyboard")
			end
		end,
	})

	---------------------------------------------------------------------
	-- Tab 11 · 配置（WindUI 原生配置系统）
	---------------------------------------------------------------------
	local TabCfg = mkTab({ Title = "配置", Icon = "save" })
	local SecCfg = TabCfg:Section({ Title = "配置档案", Icon = "folder-cog", Opened = true })
	UI.pCfg = para(SecCfg, "状态", "—", "info")

	local configObj = nil
	local function cm()
		return Window and Window.ConfigManager or nil
	end
	local function refreshConfigList()
		ConfigMgr.list = {}
		safe(function()
			local m = cm()
			if not m then return end
			local t = m:AllConfigs()
			if type(t) == "table" then
				for k, v in pairs(t) do
					if type(k) == "number" then
						ConfigMgr.list[#ConfigMgr.list + 1] = tostring(v)
					else
						ConfigMgr.list[#ConfigMgr.list + 1] = tostring(k)
					end
				end
			end
		end)
		if #ConfigMgr.list == 0 then ConfigMgr.list = { "default" } end
		table.sort(ConfigMgr.list)
	end
	refreshConfigList()

	local function useConfig(name)
		if name == nil or name == "" then return false, "名称为空" end
		local m = cm()
		if not m then return false, "无配置管理器" end
		local ok, res = safe(function() return m:Config(name) end)
		if not ok or type(res) ~= "table" then return false, "创建配置失败" end
		configObj = res
		ConfigMgr.name = name
		safe(function() Window:SetCurrentConfig(configObj) end)
		return true, "已切换到配置 " .. name
	end

	local defaultName = ConfigMgr.list[1] or "default"
	useConfig(defaultName)

	-- WindUI 的 Input 元素没有 :Get()，自己记最后输入值
	local nameBuf = ConfigMgr.name or "default"
	local cfgInput = mk("Input", SecCfg, {
		Title = "配置名称", Desc = "新建/切换用，回车确认", Icon = "tag",
		Value = nameBuf, Placeholder = "default",
		Callback = function(v) nameBuf = tostring(v or "") end,
	})
	UI.cfgInput = cfgInput
	mk("Dropdown", SecCfg, {
		Title = "已存在的配置", Desc = "选中后自动切换", Icon = "folder",
		Values = ConfigMgr.list, Value = ConfigMgr.name, SearchBarEnabled = true,
		Callback = function(v)
			local ok, msg = useConfig(tostring(v))
			ConfigMgr.lastMsg = msg
			Notify("配置", ok and msg or "切换失败", ok and "folder" or "triangle-alert")
			refreshConfigList()
		end,
	})

	local function inputName()
		if type(nameBuf) == "string" and nameBuf ~= "" then return nameBuf end
		return ConfigMgr.name or "default"
	end

	local SecCfgAct = TabCfg:Section({ Title = "操作", Icon = "wrench", Opened = true })
	mk("Button", SecCfgAct, {
		Title = "保存当前设置到配置", Icon = "save",
		Callback = function()
			local n = inputName()
			local ok, msg = useConfig(n)
			if not ok then Notify("配置", msg, "triangle-alert") return end
			local ok2 = safe(function() configObj:Save() end)
			ConfigMgr.lastMsg = ok2 and ("已保存 " .. n) or "保存失败（可能未指定 Folder）"
			if ok2 then cfgSave(true) end
			Notify("配置", ConfigMgr.lastMsg, ok2 and "save" or "triangle-alert")
			refreshConfigList()
		end,
	})
	mk("Button", SecCfgAct, {
		Title = "从配置载入", Icon = "folder-open",
		Callback = function()
			local n = inputName()
			local ok, msg = useConfig(n)
			if not ok then Notify("配置", msg, "triangle-alert") return end
			local ok2 = safe(function() configObj:Load() end)
			ConfigMgr.lastMsg = ok2 and ("已载入 " .. n) or "载入失败"
			Notify("配置", ConfigMgr.lastMsg, ok2 and "folder-open" or "triangle-alert")
		end,
	})
	mk("Button", SecCfgAct, {
		Title = "设为自动载入", Desc = "下次启动时自动应用这个配置", Icon = "pin",
		Callback = function()
			if not configObj then return end
			local ok = safe(function() configObj:SetAutoLoad(true) end)
			Notify("配置", ok and "已设为自动载入" or "设置失败", "pin")
		end,
	})
	mk("Button", SecCfgAct, {
		Title = "删除该配置", Icon = "trash", Color = Color3.fromRGB(200, 80, 80),
		Callback = function()
			local n = inputName()
			local m = cm()
			if not m then Notify("配置", "无配置管理器", "triangle-alert") return end
			local ok, msg = safe(function() return m:DeleteConfig(n) end)
			Notify("配置", tostring(msg or (ok and "已删除" or "失败")), "trash")
			refreshConfigList()
		end,
	})
	mk("Button", SecCfgAct, {
		Title = "全部恢复默认", Icon = "rotate-ccw",
		Callback = function()
			cfg = deepcopy(DEFAULTS)
			cfgSave(true)
			Notify("配置", "已恢复默认（重载脚本后完全生效）", "rotate-ccw")
		end,
	})

	---------------------------------------------------------------------
	-- Tab 12 · 工具 / 日志
	---------------------------------------------------------------------
	local TabTool = mkTab({ Title = "工具", Icon = "wrench" })
	local SecClaim = TabTool:Section({ Title = "领取", Icon = "gift", Opened = true })
	for _, c in ipairs({
		{ "每日奖励", "DailyClaim" }, { "离线收益", "OfflineCollect" }, { "任务奖励", "QuestClaim" },
	}) do
		mk("Button", SecClaim, {
			Title = c[1], Desc = "远程 " .. c[2], Icon = "hand-coins",
			Callback = function()
				local r = Remotes and Remotes:FindFirstChild(c[2])
				if not r then Notify("领取", c[2] .. " 不存在", "triangle-alert") return end
				local ok = safe(function() r:FireServer() end)
				Notify("领取", (ok and "已触发 " or "失败 ") .. c[1],
					ok and "hand-coins" or "triangle-alert")
			end,
		})
	end

	local SecDiag = TabTool:Section({ Title = "诊断", Icon = "info", Opened = true })
	mk("Button", SecDiag, {
		Title = "复制当前状态到剪贴板", Icon = "clipboard-copy",
		Callback = function()
			local out = {}
			for _, k in ipairs(keysOf(S)) do
				local v = S[k]
				if type(v) == "table" then
					out[#out + 1] = k .. " = [" .. table.concat(keysOf(v), ", ") .. "]"
				else
					out[#out + 1] = k .. " = " .. tostring(v)
				end
			end
			safe(setclipboard, table.concat(out, "\n"))
			Notify("诊断", "已复制", "clipboard-copy")
		end,
	})
	mk("Button", SecDiag, {
		Title = "列出地块与仓库提示点", Icon = "list-checks",
		Callback = function()
			scanPrompts()
			log("=== 提示点 " .. #Prompt.list .. " 个 ===")
			local h = getHRP()
			for _, d in ipairs(Prompt.list) do
				log(string.format("%s | %s | %s | dist=%.0f", tostring(d.ActionText),
					tostring(d.ObjectText), d:GetFullName(),
					(d.Parent.Position - (h and h.Position or Vector3.zero)).Magnitude))
			end
			Notify("诊断", "已输出到控制台 (F9)", "list-checks")
		end,
	})
	local SecLog = TabTool:Section({ Title = "运行日志", Icon = "scroll-text", Opened = true })
	UI.pLog = para(SecLog, "最近动作", "—", "scroll-text")

	local SecDanger = TabTool:Section({ Title = "危险区", Icon = "triangle-alert", Opened = false })
	mk("Button", SecDanger, {
		Title = "卸载脚本", Icon = "power", Color = Color3.fromRGB(214, 70, 70),
		Callback = function()
			local function doUnload()
				cfg.pipe.on, cfg.restock.on, cfg.ac.on = false, false, false
				cfgSave(true)
				safe(function() Window:Destroy() end)
				if HUD.gui then safe(function() HUD.gui:Destroy() end) end
			end
			local ok = safe(function()
				WindUI:Popup({
					Title = "确认卸载", Icon = "triangle-alert",
					Content = "将关闭界面与全部自动化。确定吗？",
					Buttons = {
						{ Title = "取消", Variant = "Tertiary", Callback = function() end },
						{ Title = "卸载", Icon = "power", Variant = "Primary", Callback = doUnload },
					},
				})
			end)
			if not ok then doUnload() end
		end,
	})

	refreshConfigList()
	UI.setText(UI.pCfg, string.format("当前配置 %s · 已发现 %d 个",
		tostring(ConfigMgr.name), #ConfigMgr.list))
	safe(function() UI.setText(UI.pTheme, tostring(WindUI:GetCurrentTheme())) end)
	log("WindUI 界面已建立 · 主题 " .. tostring(cfg.view.theme) .. " · 产品 " .. #prodVals .. " 种")
	end
	-- 界面构建失败也不影响自动化：悬浮看板与三条线程照常跑
	local okUI, errUI = pcall(buildUI)
	if not okUI then log("界面构建异常: " .. tostring(errUI)) end
end

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

-- 线程 B：自动接单（独立于流水线开关，关掉流水线也能接单）
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

-- 线程 D：自动购买（商品解锁 / 员工招聘 / 广告投放 / 传送带 / AI 调参）
task.spawn(function()
	local tB, tH, tConv, tViral = 0, 0, 0, 0
	while ENABLED and STATE.alive() do
		task.wait(0.25)
		local now = os.clock()

		-- 每轮先刷新保护模式与会话统计（看板与所有花钱模块都依赖它）
		safe(guardRefresh)
		safe(statTick)

		-- 爆款轮换是慢变量，60s 拉一次足够
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

		-- 传送带：只是读状态很便宜；升级尝试 15s 一次，避免刷屏
		safe(readConv)
		if cfg.conv.autoUpgrade and now - tConv >= 15 then
			tConv = now
			safe(convUpgrade)
		end

		safe(aiTick)
	end
end)

-- 线程 C：补货 / 完成统计 / 状态兜底 / UI
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

		-- 状态兜底轮询（推送为主，这里只是保险）
		if now - tState >= 5 then
			tState = now
			requestState()
		end

		-- 完成统计（1s 一次即可）
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
					HUD.row.ac.Text = "接单 " .. (cfg.ac.on and ("开 · 候选 " .. #acCandidates()) or "关")
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

			local t = UI.setText
			if t then
				local co = orderById(Pipe.orderId)
				t(UI.pOrder, co and string.format("#%s · %s · %s$ · %s · %s",
					tostring(co.id), tostring(co.product), tostring(co.price),
					tostring(co.status), co.isViral and "爆款" or "普通") or "—")
				t(UI.pPhase, Pipe.phase)
				t(UI.pDetail, Pipe.detail)
				t(UI.pAC, string.format("可接 %d 单 · 过滤后候选 %d · 优先级 %s",
					nNew, #acCandidates(), cfg.ac.priority))
				t(UI.pRest, Rst.last)
				t(UI.pBuy, BuyProd.last)
				t(UI.pHire, string.format("%s（已招 %d 人）", Hire.last, Hire.count))
				t(UI.pAd, Ad.last)
				t(UI.pClaim, Ops.last["领取"] or "—")
				t(UI.pStaff, string.format("休假 %s ｜ 训练 %s",
					Ops.last["休假"] or "—", Ops.last["训练"] or "—"))
				t(UI.pOth, string.format("研究 %s ｜ 合同 %s",
					Ops.last["研究"] or "—", Ops.last["合同"] or "—"))
				t(UI.pAI, string.format("第 %d 轮 · %s", AI.runs, tostring(cfg.ai.note or "—")))
				t(UI.pAIChg, #AI.changes > 0 and table.concat(AI.changes, "\n") or "（暂无调整）")
				t(UI.pConv, string.format("条数 %d/%d ｜ 等级 %d/%d ｜ 升级价 %s ｜ %s",
					cfg.conv.count, cfg.conv.maxCount, cfg.conv.level, Conv.maxLevel or 3,
					Conv.price and fmt(Conv.price) or "—",
					Conv.prompt and (Conv.prompt.Enabled and "可升级" or "未开放") or "无升级点"))
				t(UI.pConvLog, Conv.last or "—")

				-- 会话统计 / 收益效率 / 动作确认率 / 当期爆款
				local mins = math.floor((os.clock() - Stat.startAt) / 60)
				t(UI.dStat, string.format("会话 %d 分 ｜ 完成 %d 单 ｜ 现金 %s ｜ 宝石 %s ｜ %s",
					mins, Pipe.completed, fmt(S.cash), fmt(S.gems),
					Guard.blocked and "保护模式中" or "正常"))
				t(UI.dEcon, string.format("毛收入累计 %s ｜ 约 %s/小时 ｜ 单均 %s",
					fmt(Stat.gain), fmt(Stat.gain / statHours()),
					Pipe.completed > 0 and fmt(Stat.gain / math.max(1, Pipe.completed)) or "—"))
				local tot, bad = Exe.stats.total, Exe.stats.fail
				t(UI.dFail, tot > 0
					and string.format("确认 %d 次 · 通过 %d · 失败率 %.0f%%", tot, tot - bad, bad / tot * 100)
					or "暂无样本（有确认条件的动作才会统计）")
				do
					local v = G.viral
					local vp = viralProduct()
					local names = {}
					for _, p in ipairs((v and v.produkty) or {}) do
						names[#names + 1] = tostring(p.nazwa or p.id)
					end
					t(UI.dViral, #names > 0
						and (table.concat(names, " / ") .. (vp and ("　可投：" .. vp) or "　（均未解锁）"))
						or "无数据（需打开一次爆款面板）")
				end
				t(UI.dCash, fmt(S.cash))
				t(UI.dGems, fmt(S.gems))
				t(UI.dWear, string.format("%d / %s（库存 %d）", wh,
					tostring(S.warehouseCapacity or "—"), stock))
				t(UI.dOrder, lineOrder)
				t(UI.dCarry, carryCn)
				t(UI.dProd, string.format("%s · 广告 %s", tostring(S.activeProduct or "—"),
					tostring(S.adState or "—")))
				t(UI.pLog, table.concat(Log, "\n"))
				if ConfigMgr.lastMsg ~= "—" then
					t(UI.pCfg, string.format("配置 %s · %s · 共 %d 个",
						tostring(ConfigMgr.name), ConfigMgr.lastMsg, #ConfigMgr.list))
				end
			end

			local ping = 0
			safe(function() ping = math.floor(plr:GetNetworkPing() * 1000) end)
			local dt = RunSvc.RenderStepped:Wait()
			if UI.setText then
				UI.setText(UI.dFps, string.format("%d fps · %d ms",
					math.floor(1 / math.max(dt, 1 / 240)), ping))
			end

			cfgSave()
		end
	end
end)

--=====================================================================
-- 11. 收尾
--=====================================================================
STATE.onCleanup(function()
	cfgSave(true)
	safe(dispose)   -- 关界面 + 停线程 + 释放单例标记
end)

requestState()
Notify("订单流水线 v3.2", "已加载 · 右Shift 开关窗口 · 悬浮窗可拖动", "package")
log("v3.2 载入完成 · 地块=" .. tostring(plotName()) .. " · 订单驱动")
