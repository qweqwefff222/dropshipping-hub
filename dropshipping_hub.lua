--[[
	代发货大亨 (Dropshipping Tycoon) · 订单驱动流水线 Hub  v3.1
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
	       新坐标 -> 触发 -> 立即回原位。等待默认 0.30s（实测 0.06s 会
	       因服务端未收到新 CFrame 而被拒）
	==================================================================
	【v2 -> v3.1 修复】
	  1. 旧版取箱只扫 plot，箱子其实在 Workspace.LocalWarehouseStock
	  2. 旧版无订单也硬跑 -> 严格订单驱动
	  3. 提示点每帧全量扫 -> 只扫 [地块 + 仓库] 两棵小子树并节流
	  4. 状态靠轮询 -> 靠 StateUpdate 推送，轮询只兜底
	  5. 悬浮窗拖不动 -> 全局 UIS + 区域命中 + 位置存盘
	  6. 看板空白 -> 启动先等状态就绪再建 UI
	  7. 触发等待过短被服务端拒 -> preWait 固定 0.30s
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
		on = false,
		restore = true,      -- 触发完把角色放回原处
		boost = true,        -- 拉大提示点交互距离 + 关视线校验
		tpHeight = 2.5,
		-- ⚠ 实机标定：preWait 必须 >= 0.25。给 0.06 时服务端还没收到新坐标
		--   就先收到触发，会直接判定距离不足而拒绝（这是旧版卡住的根因）。
		preWait = 0.30,
		postWait = 0.16,
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
local function activeCount()
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
-- 4. 执行引擎（传送到位 -> 触发 -> 回原位）
--=====================================================================
local Exe = { lastAction = 0 }

local function canAct()
	local now = os.clock()
	if now - Exe.lastAction < cfg.pipe.gap then return false end
	Exe.lastAction = now
	return true
end

-- 传送到提示点旁 -> 等坐标同步 -> 触发 -> 回原处
-- ⚠ 实机标定：preWait 必须 >= 0.25。服务端要先收到新坐标，否则会直接
--   判定距离不足而拒绝触发 —— 这正是旧版流水线卡住的根因。
local function fireNear(prompt)
	if not prompt or not prompt.Parent or not prompt.Parent:IsA("BasePart") then return false end
	local hrp = getHRP()
	if not hrp then return false end
	local save = hrp.CFrame
	safe(function()
		hrp.CFrame = CFrame.new(prompt.Parent.Position + Vector3.new(0, cfg.pipe.tpHeight, 0))
	end)
	if cfg.pipe.preWait > 0 then task.wait(cfg.pipe.preWait) end
	local ok = safe(function() fireproximityprompt(prompt) end)
	if cfg.pipe.restore then
		if cfg.pipe.postWait > 0 then task.wait(cfg.pipe.postWait) end
		local h2 = getHRP()
		if h2 then safe(function() h2.CFrame = save end) end
	end
	return ok
end

-- 返回 true = 已发出动作；false = 无提示点 / 节流中
local function actPrompt(prompt)
	if not prompt then return false end
	if not canAct() then return false end
	fireNear(prompt)
	return true
end

-- 取货总入口。
-- 提示：WarehouseStockTake 远程服务端同样校验距离，远距离发无效，
--       必须角色真的靠近箱子，所以走"传送到箱子旁 -> 触发 -> 回原位"。
local function pickRaw()
	local p = findPrompt("Pick up package", isInLWS)
	if p then
		actPrompt(p)
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
	local ok = safe(function() rem:FireServer(pid, qty) end)
	if ok then
		local msg = string.format("已补货 %s ×%d（原库存 %d）", pid, qty, stock)
		log(msg)
		return true, msg
	end
	return false, "补货调用失败"
end

--=====================================================================
-- 6. 自绘 HUD（拖动用全局 UIS + 区域命中）
--=====================================================================
local HUD = { row = {}, frame = nil, gui = nil }
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
end)

local function hudVisible(v)
	if HUD.gui then safe(function() HUD.gui.Enabled = v end) end
end
hudVisible(cfg.hud.on)

--=====================================================================
-- 7. 订单驱动状态机
--=====================================================================
local Pipe = { phase = "IDLE", detail = "待机", orderId = nil, phaseAt = 0,
	lastAccept = 0, completed = 0, seen = {} }

local function setPhase(name, detail)
	if Pipe.phase ~= name then
		if name ~= "IDLE" then log(string.format("[%s] %s", name, tostring(detail or ""))) end
		Pipe.phase = name
		Pipe.phaseAt = os.clock()
	end
	Pipe.detail = tostring(detail or name)
end

local function currentOrder()
	local af = S.activeFulfillments
	if type(af) == "table" then
		for _, v in pairs(af) do
			if type(v) == "number" then
				local o = orderById(v)
				-- 只认仍在履约中的，已完成/已结算的不要反复接手
				if o and FULFIL[tostring(o.status)] then return o end
			end
		end
	end
	local best
	for _, o in pairs(S.orders or {}) do
		if FULFIL[tostring(o.status)] then
			if not best or (tonumber(o.id) or 0) < (tonumber(best.id) or 0) then best = o end
		end
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
	-- 成品箱生成瞬间 Enabled 可能是 false，所以不强依赖它，找到就主动启用
	for _, d in ipairs(pkg:GetDescendants()) do
		if d:IsA("ProximityPrompt")
			and (d.ActionText == "Pick up package" or d.ActionText == "") then
			if not d.Enabled then pcall(function() d.Enabled = true end) end
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

local function pipeTick()
	if not cfg.pipe.on then
		setPhase("IDLE", "流水线未启用")
		Pipe.orderId = nil
		return
	end

	local o = currentOrder()
	if not o then
		Pipe.orderId = nil
		setPhase("IDLE", "无进行中订单")
		if cfg.ac.on then tryAutoAccept() end
		return
	end

	if tostring(Pipe.orderId) ~= tostring(o.id) then
		Pipe.orderId = o.id
		Pipe.phaseAt = os.clock()
		log(string.format("接手订单 #%s · %s · %s · %s$ · %s",
			tostring(o.id), tostring(o.product), tostring(o.status),
			tostring(o.price), o.isViral and "爆款" or "普通"))
	end

	scanThrottled(0.3)

	local st = tostring(o.status)
	local carry = carrying()

	if st == "New" then
		setPhase("ACCEPT", "订单待接受")
		if cfg.ac.on then
			local pass, why = acPass(o)
			if pass then acceptOrder(o.id) else setPhase("ACCEPT", "被过滤: " .. tostring(why)) end
		else
			setPhase("ACCEPT", "未开启自动接单")
		end
		return
	end

	if st == "Ready to Pack" then
		if carry == "none" then
			setPhase("FETCH_RAW", "取原始包裹")
			if not pickRaw() then
				Pipe.detail = "仓库无可用包裹"
				if cfg.pipe.autoRestock then doRestock(false) end
			end
		else
			setPhase("TO_BELT", "放上传送带")
			local p = findPrompt("Put on conveyor", isInPlot)
			if p then actPrompt(p) else Pipe.detail = "等待传送带提示点" end
		end
		return
	end

	if st == "Being Packed" then
		if carry == "labeled" then
			setPhase("TO_COURIER", "交给快递员")
			local p = findPrompt("Leave for courier", isInPlot)
			if p then actPrompt(p) else Pipe.detail = "等待快递员提示点" end
		elseif carry == "unlabeled" then
			-- 过渡态：上带后服务端要一点时间把手里的原始包裹收走，等它自己清空
			setPhase("FETCH_DONE", "等待手持包裹结算")
		else
			setPhase("FETCH_DONE", "取成品箱")
			local p = doneBoxPrompt()
			if p then
				local who = doneBoxCustomer()
				Pipe.detail = "取成品箱" .. (who and ("（" .. who .. "）") or "")
				actPrompt(p)
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
			if p then actPrompt(p) end
		else
			setPhase("WAIT_COURIER", "等待快递员取件")
		end
		return
	end

	if st == "Completed" then
		if not Pipe.seen[tostring(o.id)] then
			Pipe.seen[tostring(o.id)] = true
			Pipe.completed = Pipe.completed + 1
			log("订单完成 #" .. tostring(o.id))
		end
		setPhase("IDLE", "订单已完成")
		Pipe.orderId = nil
		return
	end

	setPhase("WAIT", "未知状态 " .. st)
end

--=====================================================================
-- 8. 等状态就绪
--=====================================================================
local function waitForState(timeout)
	requestState()
	local t0 = os.clock()
	while ENABLED and os.clock() - t0 < (timeout or 6) do
		if type(S) == "table" and next(S) ~= nil then return true end
		task.wait(0.25)
	end
	return false
end
local stateReady = waitForState(8)
log(stateReady and "状态已就绪" or "状态等待超时（继续运行）")

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
local Window
local ConfigMgr = { name = nil, list = {}, lastMsg = "—" }

if WindUI then
	safe(function() WindUI:SetNotificationLower(true) end)

	-- 外观设置先应用（建窗口时就要用）
	local vw = cfg.view
	Window = WindUI:CreateWindow({
		Title       = "代发货大亨 · 订单流水线",
		Icon        = "package",
		Author      = "v3.1 · 订单驱动",
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
	local function mk(kind, section, cfgT)
		local el
		local ok = pcall(function() el = section[kind](section, cfgT) end)
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

	---------------------------------------------------------------------
	-- Tab 1 · 流水线
	---------------------------------------------------------------------
	local TabPipe = Window:Tab({ Title = "流水线", Icon = "conveyor-belt" })
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
	toggle(SecMain, "补货联动提示",
		"仓库无可用包裹时提示你开自动补货（不自动花钱）。",
		"link", "pipe_autorestock", cfg.pipe.autoRestock, function(v) cfg.pipe.autoRestock = v end)

	local SecLive = TabPipe:Section({ Title = "实时阶段", Icon = "activity", Opened = true })
	UI.pOrder  = para(SecLive, "当前订单", "—", "clipboard-list")
	UI.pPhase  = para(SecLive, "阶段", "—", "git-branch")
	UI.pDetail = para(SecLive, "细节", "—", "info")

	local SecSpeed = TabPipe:Section({ Title = "时序与位移", Icon = "sliders", Opened = false })
	slider(SecSpeed, "动作间隔", "两次触发之间的最小间隔（秒）", "timer", "pipe_gap",
		cfg.pipe.gap, 0.05, 1.5, 0.05, function(v) cfg.pipe.gap = v end)
	slider(SecSpeed, "微传送抬高", "闪现时抬高多少，太低会卡进模型", "compass", "pipe_tph",
		cfg.pipe.tpHeight, 1, 8, 0.5, function(v) cfg.pipe.tpHeight = v end)
	slider(SecSpeed, "传送后等待", "改坐标到触发之间的等待（服务端需先收到新坐标）", "timer", "pipe_prewait",
		cfg.pipe.preWait, 0, 0.4, 0.02, function(v) cfg.pipe.preWait = v end)
	slider(SecSpeed, "回位前等待", "触发到回到原位之间的等待", "undo-2", "pipe_postwait",
		cfg.pipe.postWait, 0, 0.5, 0.02, function(v) cfg.pipe.postWait = v end)

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
	stepBtn("③ 放上传送带", "conveyor-belt", function()
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
	local TabAC = Window:Tab({ Title = "自动接单", Icon = "clipboard-check" })
	local SecAC = TabAC:Section({ Title = "开关与策略", Icon = "power", Opened = true })

	toggle(SecAC, "启用自动接单",
		"有符合条件的新订单时自动接单（并发受限）",
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

	local SecFilter = TabAC:Section({ Title = "价格与并发", Icon = "sliders", Opened = true })
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
	local TabRest = Window:Tab({ Title = "补货", Icon = "boxes" })
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
	local SecRestNum = TabRest:Section({ Title = "阈值与数量", Icon = "sliders", Opened = true })
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
	-- Tab 4 · 看板
	---------------------------------------------------------------------
	local TabDash = Window:Tab({ Title = "看板", Icon = "gauge" })
	local SecDash = TabDash:Section({ Title = "实时数值", Icon = "activity", Opened = true })
	UI.dCash  = para(SecDash, "现金", "—", "banknote")
	UI.dGems  = para(SecDash, "宝石", "—", "gem")
	UI.dWear  = para(SecDash, "仓库 / 库存", "—", "warehouse")
	UI.dOrder = para(SecDash, "订单", "—", "clipboard-list")
	UI.dCarry = para(SecDash, "搬运状态", "—", "hand-pointer")
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

	---------------------------------------------------------------------
	-- Tab 5 · 外观（WindUI 原生外观能力）
	---------------------------------------------------------------------
	local TabView = Window:Tab({ Title = "外观", Icon = "palette" })
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

	local SecLook = TabView:Section({ Title = "窗口外观", Icon = "layout", Opened = true })
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
	-- Tab 6 · 配置（WindUI 原生配置系统）
	---------------------------------------------------------------------
	local TabCfg = Window:Tab({ Title = "配置", Icon = "save" })
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
	-- Tab 7 · 工具 / 日志
	---------------------------------------------------------------------
	local TabTool = Window:Tab({ Title = "工具", Icon = "wrench" })
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

--=====================================================================
-- 10. 主循环
--=====================================================================
task.spawn(function()
	local tRest, tUI, tState = 0, 0, 0
	while ENABLED and STATE.alive() do
		task.wait(0.08)
		local now = os.clock()

		safe(pipeTick)

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
					HUD.row.mode.Text = "引擎 订单驱动 · 传送回位 " .. (cfg.pipe.restore and "开" or "关")
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
	if Window then safe(function() Window:Destroy() end) end
	if HUD.gui then safe(function() HUD.gui:Destroy() end) end
end)

requestState()
Notify("订单流水线 v3.1", "已加载 · 右Shift 开关窗口 · 悬浮窗可拖动", "package")
log("v3.1 载入完成 · 地块=" .. tostring(plotName()) .. " · 订单驱动")
