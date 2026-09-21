--[[
	QiurongToolbox v1.1.1  ·  秋容工具箱
	====================================
	基于《Roblox UI 三套静态视觉样本》(sample-*.png / generate_samples.py shared-v1 布局)
	实现的 Roblox 原生 UI 库，WindUI 式链式 builder 风格：

		local Lib = loadstring(game:HttpGet(
			"https://raw.githubusercontent.com/qweqwefff222/dropshipping-hub/main/QiurongToolbox.lua"))()

		local Window = Lib:CreateWindow{
			Title       = "秋容工具箱",
			Subtitle    = "QIURONG / ROBLOX UI",
			Theme       = "tech-glass",            -- "tech-glass" | "tactical-terminal" | "premium-dark"
			Version     = "v2.3.0",
			Marquee     = "作者：秋容 · 求点赞关注，谢谢支持 · 脚本一直爽，封号两行泪",
			NoticeBadge = "置顶公告",
			ToggleKey   = Enum.KeyCode.RightShift, -- 呼出/隐藏窗口
			Folder      = "QiurongToolbox",        -- 配置保存目录（writefile 存在时启用持久化）
			CloseAction = "hide",                  -- "hide"=关闭可重开(悬浮球) | "destroy"=直接销毁
			OpenButton  = { Title = "打开工具箱", OnlyMobile = true, Draggable = true },
			KeySystem   = {                        -- 可选：卡密门禁
				KeyValidator = function(k) return k == "1234" end,
				Note = "请输入卡密", SaveKey = true,
			},
			OnClose     = function() end,
		}

		local Tab = Window:Tab{ Title = "菜单 01", Subtitle = "RELEASE NOTES · 版本 v2.3.0", Badge = "正式版本" }
		local Sec = Tab:Section("功能更新公告")

		Sec:Paragraph{ Title = "2.3.0", Badge = "本次更新", Desc = { "启动、加载与窗口适配升级" } }
		Sec:Stat{ Number = "3", Label = "新增功能" }
		Sec:Card{ Key = "新", Title = "新增", Color = "good", Bullets = { "新增快捷启动面板" } }
		Sec:Toggle{ Title = "自动开始", Default = false, Flag = "AutoStart", Callback = function(v) end }
		Sec:Slider{ Title = "延迟", Min = 0, Max = 10, Step = 0.1, Default = 1, Flag = "Delay", Callback = function(v) end }
		Sec:Dropdown{ Title = "目标", Options = { "A", "B" }, Default = "A", Flag = "Target", Callback = function(v) end }
		Sec:ColorPicker{ Title = "颜色", Default = Color3.fromRGB(57,200,255), Flag = "Color", Callback = function(c) end }
		Sec:Button{ Title = "执行", Callback = function() end }
		Sec:Input{ Title = "备注", Placeholder = "输入...", Flag = "Note" }

	-- 主题（WindUI 对齐）
	Lib:GetCurrentTheme()                        -- 当前主题名
	Lib:GetThemes()                              -- { {Id, Name}, ... }
	Lib:AddTheme("my-theme", { accent = C("#FF0000"), ... })  -- 自定义主题（缺省 token 继承 tech-glass）
	Lib:SetTheme("my-theme")   Window:SetTheme("my-theme")
	-- 顶栏 "◐" 按钮：循环切换主题；配置持久化会记住所选主题

	-- 配置保存（带 Flag 的控件自动持久化到 Folder/config.json）
	Lib:SaveConfig("备份1")   Lib:LoadConfig("备份1")   Lib:DeleteConfig("备份1")
	Lib:GetConfigs()          -- { "备份1", ... }

	-- 控件句柄（全部控件通用）
	local h = Sec:Toggle{...}
	h:Get() / h:Set(v)          -- Set 不触发 Callback（h:Set(v, true) 强制触发）
	h:SetTitle("新标题") / h:SetDesc("新描述")
	h:Lock() / h:Unlock()       -- 禁用/启用交互
	h:Highlight()               -- 高亮闪烁提示
	h:Destroy()                 -- 移除该控件
	-- Slider 另有 h:SetMin(n) / h:SetMax(n)
	-- Dropdown 另有 h:Select(v)（触发回调）/ h:SetOptions(list) / AllowNone / SearchBarEnabled
	-- ColorPicker 另有 h:Set(color3, transparency?)

	-- 窗口方法
	Window:SetTitle("新标题") / SetAuthor("副标题") / SetIcon("新")
	Window:SetSize(w, h) / SetToggleKey(Enum.KeyCode.K) / SetUIScale(1.2) / GetUIScale()
	Window:GetWindowSize() / IsResizable() / SetBackgroundTransparency(0~1)
	Window:Show() / Hide() / ToggleVisibility() / ToggleCollapse()
	Window:Notify("标题", "内容") / Notify{ Title=, Content=, Icon="✓", Duration=5 }
	Window:Dialog{ Title=, Content=, Buttons={ {Title="确定", Variant="Primary", Callback=fn}, ... } }

	18 种样本规格均落实：三主题 token、箭头菜单、跑马灯、统计格、分类卡、
	分类分页栏、展开/收起把手、缩放角标；桌面/手机横屏双布局（正文≥14 菜单≥15 标题≥20，热区≥44）。
	注：WindUI 的 SetFont / Localization / Acrylic / 背景视频 不在样本规范内，未实现。
]]

-- 前置声明（必须先于 CreateWindow 定义：CreateWindow 体内引用 WinMT/TabMT，
-- 词法作用域在编译期解析，后置 local 会让它变成全局引用 → setmetatable({}, nil) 致命）

local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

-- ===== 主题（自 generate_samples.py THEMES 逐字转换） =====
local function C(hex)
	local r = tonumber(hex:sub(2, 3), 16)
	local g = tonumber(hex:sub(4, 5), 16)
	local b = tonumber(hex:sub(6, 7), 16)
	return Color3.fromRGB(r, g, b)
end

local THEMES = {
	["tech-glass"] = {
		name = "科技玻璃",
		bg = C("#050B14"), bg2 = C("#091827"), shell = C("#0A1725"),
		panel = C("#102536"), panel2 = C("#143148"), panel3 = C("#0B1C2A"),
		line = C("#2B6076"), line_soft = C("#173A4D"), accent = C("#39C8FF"),
		accent2 = C("#77E4FF"), text = C("#F1FAFF"), muted = C("#99B6C6"),
		good = C("#58E5C2"), warn = C("#FFCB69"), danger = C("#FF6B7A"),
		pattern = "circuit", glass = true,
	},
	["tactical-terminal"] = {
		name = "战术终端",
		bg = C("#080A09"), bg2 = C("#101511"), shell = C("#0C100E"),
		panel = C("#121914"), panel2 = C("#17221A"), panel3 = C("#0D130F"),
		line = C("#344A38"), line_soft = C("#223126"), accent = C("#83D46B"),
		accent2 = C("#B2F09E"), text = C("#EDF6EA"), muted = C("#9AAC9A"),
		good = C("#83D46B"), warn = C("#E7B94D"), danger = C("#E56E5F"),
		pattern = "grid", glass = false,
	},
	["premium-dark"] = {
		name = "高级暗色",
		bg = C("#0A0D13"), bg2 = C("#111721"), shell = C("#10151E"),
		panel = C("#171E29"), panel2 = C("#1B2431"), panel3 = C("#121923"),
		line = C("#334154"), line_soft = C("#242F3D"), accent = C("#4C8DFF"),
		accent2 = C("#7DAAFF"), text = C("#F5F8FE"), muted = C("#98A6BA"),
		good = C("#62D7B1"), warn = C("#F4BE61"), danger = C("#F16E82"),
		pattern = "minimal", glass = false,
	},
}

local WinMT = {}
local TabMT = {}

local Lib = {
	Version = "1.1.1",
	ThemeName = "tech-glass",
	Flags = {},
	_Windows = {},
	_Binds = {},   -- { {inst, prop, token | get} } 主题换色绑定（token 静态 / get 动态函数）
	Seq = 0,
	Folder = "QiurongToolbox",   -- 配置目录（CreateWindow 可覆盖）
	_Pending = nil,              -- 启动时读到的持久化配置（flag -> 值）
	_Loading = false,            -- 配置回灌期间抑制回调
	_autoSaveEnabled = true,     -- Flag 值变化自动保存（⚠ 与 _autoSave 方法是两回事，勿同名）
}
Lib._GName = "QiurongToolbox"

function Lib:Theme()
	return THEMES[self.ThemeName]
end

function Lib:_reg(inst, prop, token)
	table.insert(self._Binds, { inst = inst, prop = prop, token = token })
end

local TOKEN_COLOR_PROPS = {
	BackgroundColor3 = true, TextColor3 = true, Color = true,
	BorderColor3 = true, PlaceholderColor3 = true, ScrollBarImageColor3 = true,
}

-- 注册任意实例的任意颜色属性到主题 token
function Lib:Bind(inst, prop, token)
	if not TOKEN_COLOR_PROPS[prop] and prop ~= "UIGradient" and prop ~= "ImageColor3" then return end
	self:_reg(inst, prop, token)
	if prop == "UIGradient" then
		inst.Color = ColorSequence.new(self:Theme()[token], self:Theme()[token])
	elseif TOKEN_COLOR_PROPS[prop] then
		inst[prop] = self:Theme()[token]
	end
end

-- 动态 token 绑定：getFn 返回当前应使用的 token 名（用于选中态等状态色，随 SetTheme 重算）
function Lib:BindFn(inst, prop, getFn)
	if not TOKEN_COLOR_PROPS[prop] and prop ~= "UIGradient" then return end
	table.insert(self._Binds, { inst = inst, prop = prop, get = getFn })
	self:_applyBind(self._Binds[#self._Binds])
end

function Lib:_applyBind(b)
	local t = self:Theme()
	if b.get then b.token = b.get() end
	local token = b.token
	if not t[token] then return end
	pcall(function()
		if b.prop == "UIGradient" then
			b.inst.Color = ColorSequence.new(t[token], t[token])
		else
			b.inst[b.prop] = t[token]
		end
	end)
end

function Lib:SetTheme(name)
	if not THEMES[name] then return false end
	self.ThemeName = name
	local t = THEMES[name]
	-- 惰性回收：实例已销毁（Parent=nil）的绑定清掉，防止长会话累积
	local alive = {}
	for _, b in ipairs(self._Binds) do
		if b.inst and b.inst.Parent then
			alive[#alive + 1] = b
			if b.get then b.token = b.get() end
			local token = b.token
			if t[token] then
				pcall(function()
					if b.prop == "UIGradient" then
						b.inst.Color = ColorSequence.new(t[token], t[token])
					else
						b.inst[b.prop] = t[token]
					end
				end)
			end
		end
	end
	self._Binds = alive
	for _, win in ipairs(self._Windows) do
		if win.RefreshTheme then pcall(win.RefreshTheme, win) end
	end
	return true
end

function Lib:GetThemes()
	local list = {}
	for k, v in pairs(THEMES) do table.insert(list, { Id = k, Name = v.name }) end
	table.sort(list, function(a, b) return a.Id < b.Id end)
	return list
end

function Lib:GetCurrentTheme()
	return self.ThemeName
end

-- 注册自定义主题：tokens 只需给出要覆盖的 token，缺省继承 tech-glass 基准
function Lib:AddTheme(id, tokens)
	if type(id) ~= "string" or id == "" or type(tokens) ~= "table" then return false end
	local base = THEMES["tech-glass"]
	local merged = {}
	for k, v in pairs(base) do merged[k] = v end
	for k, v in pairs(tokens) do merged[k] = v end
	merged.name = tokens.name or tostring(id)
	THEMES[id] = merged
	return true
end

-- ===== 配置持久化（Folder + Flag，WindUI 对齐） =====
local function fsAvailable()
	return type(writefile) == "function" and type(readfile) == "function"
end

local function fsPath(lib, name)
	if name and name ~= "" and name ~= "config" then
		return tostring(lib.Folder) .. "/config_" .. tostring(name) .. ".json"
	end
	return tostring(lib.Folder) .. "/config.json"
end

function Lib:SaveConfig(name)
	if not fsAvailable() then return false, "当前环境无 writefile/readfile" end
	local ok, err = pcall(function()
		if isfolder and type(isfolder) == "function" then
			if not isfolder(self.Folder) then makefolder(self.Folder) end
		else
			makefolder(self.Folder)
		end
	end)
	if not ok then return false, "无法创建配置目录: " .. tostring(err) end
	local snap = { _theme = self.ThemeName, flags = {} }
	for k, h in pairs(self.Flags) do
		local v = h.Get()
		local tv = type(v)
		if tv == "table" then
			local arr = {}
			for val in pairs(v) do table.insert(arr, tostring(val)) end
			table.sort(arr)
			snap.flags[k] = { t = h.Type, v = arr }
		elseif tv == "userdata" and typeof and typeof(v) == "Color3" then
			snap.flags[k] = { t = "color", v = string.format("%.6f,%.6f,%.6f", v.R, v.G, v.B) }
		elseif tv == "userdata" and typeof and typeof(v) == "EnumItem" then
			snap.flags[k] = { t = "keybind", v = v.Name }
		elseif tv == "string" or tv == "number" or tv == "boolean" then
			snap.flags[k] = { t = h.Type, v = v }
		end
	end
	local jok, json = pcall(function() return HttpService:JSONEncode(snap) end)
	if not jok then return false, "配置序列化失败" end
	local wok, werr = pcall(writefile, fsPath(self, name), json)
	if not wok then return false, "配置写入失败: " .. tostring(werr) end
	return true
end

local function decodeSnapshot(json)
	local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
	if not ok or type(data) ~= "table" then return nil end
	return data
end

function Lib:LoadConfig(name)
	if not fsAvailable() then return false, "当前环境无 writefile/readfile" end
	local rok, json = pcall(readfile, fsPath(self, name))
	if not rok then return false, "配置不存在: " .. tostring(name or "config") end
	local snap = decodeSnapshot(json)
	if not snap then return false, "配置解析失败" end
	if snap._theme and THEMES[snap._theme] then self:SetTheme(snap._theme) end
	local flags = snap.flags
	if type(flags) ~= "table" then return true end
	for k, ent in pairs(flags) do
		local h = self.Flags[k]
		if h and type(ent) == "table" then
			local v = ent.v
			if h.Type == "multi" then
				local set = {}
				if type(v) == "table" then
					for _, x in ipairs(v) do set[tostring(x)] = true end
				end
				h:Set(set)
			elseif h.Type == "keybind" then
				local okk, kc = pcall(function() return Enum.KeyCode[tostring(v)] end)
				if okk and kc then h:Set(kc) end
			elseif h.Type == "color" then
				local r, g, b = tostring(v):match("([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)")
				if r then h:Set(Color3.new(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)) end
			else
				pcall(function() h:Set(v) end)
			end
		end
	end
	return true
end

function Lib:DeleteConfig(name)
	if not fsAvailable() or type(delfile) ~= "function" then return false end
	local ok = pcall(delfile, fsPath(self, name))
	return ok
end

function Lib:GetConfigs()
	local list = {}
	if not fsAvailable() or type(listfiles) ~= "function" then return list end
	local ok, files = pcall(listfiles, tostring(self.Folder))
	if ok and type(files) == "table" then
		for _, f in ipairs(files) do
			local base = tostring(f):match("([^/\\]+)$") or tostring(f)
			if base == "config.json" then
				table.insert(list, "config")
			else
				local n = base:match("^config_(.+)%.[jJ][sS][oO][nN]$")
				if n then table.insert(list, n) end
			end
		end
	end
	table.sort(list)
	return list
end

function Lib:_autoSave()
	if not self._autoSaveEnabled then return end
	if self._saveQueued then return end
	self._saveQueued = true
	task.delay(0.6, function()
		self._saveQueued = false
		pcall(function() self:SaveConfig() end)
	end)
end

-- ===== 构建工具 =====
local function New(class, props, children)
	local inst = Instance.new(class)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then inst[k] = v end
		end
	end
	if children then
		for _, c in ipairs(children) do c.Parent = inst end
	end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

local function Corner(win, r)
	return New("UICorner", { CornerRadius = UDim.new(0, r) , Parent = win })
end

local function Stroke(parent, token, thickness, transparency, lib)
	local s = New("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		Parent = parent,
	})
	-- 漏传 lib 时回落到主 Lib：描边色一律跟随主题，避免散落固定色
	local l = lib or Lib
	l:Bind(s, "Color", token or "line")
	return s
end

local function Pad(parent, l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0),
		Parent = parent,
	})
end

local function VList(parent, gap, sort)
	return New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent = parent,
	})
end

local function safeParent()
	local ok, ui = pcall(function() return gethui and gethui() end)
	if ok and ui then return ui end
	local ok2, core = pcall(function()
		local cg = game:GetService("CoreGui")
		cg.Name = cg.Name -- 访问即校验
		return cg
	end)
	if ok2 and core then return core end
	return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local function isMobile()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- 布局参数（桌面 / 手机横屏，自样本 draw_ui 与适配规则）
local function metrics(mobile)
	if mobile then
		return {
			mobile = true,
			top = 66, navW = 118, bottom = 52, gap = 10, radius = 18, pad = 12,
			win = { w = 780, h = 520 },
			itemH = 46, itemGap = 8,
			title = 20, subtitle = 12, body = 14, menu = 15, big = 30,
			ctlH = 46, notch = true,
		}
	end
	return {
		mobile = false,
		top = 92, navW = 250, bottom = 64, gap = 16, radius = 30, pad = 20,
		win = { w = 1080, h = 660 },
		itemH = 50, itemGap = 10,
		title = 30, subtitle = 14, body = 15, menu = 16, big = 44,
		ctlH = 50, notch = true,
	}
end

-- ===== 值仓与句柄 =====
local Values = {}  -- key -> value（库级，控件状态唯一来源）

-- 交互后挂自动保存（回灌期间抑制）
local function saveHook(lib)
	if not lib._Loading then pcall(function() lib:_autoSave() end) end
end

local function makeHandle(lib, o, kind, get, set, refs)
	refs = refs or {}
	local h = { Type = kind, Key = o and o.Flag or nil, _locked = false }
	function h.Get()
		return get()
	end
	function h:Set(v, fire)
		if fire == nil then fire = true end
		if lib._Loading then fire = false end
		set(v, fire)
		if fire then saveHook(lib) end
	end
	function h:SetTitle(v)
		if refs.title then refs.title.Text = tostring(v) end
	end
	function h:SetDesc(v)
		if refs.desc then
			if v == nil or v == "" then
				refs.desc.Visible = false
			else
				refs.desc.Visible = true
				refs.desc.Text = tostring(v)
			end
		end
	end
	local lockBtn
	function h:Lock()
		if not lockBtn then
			lockBtn = New("TextButton", {
				BackgroundTransparency = 1, Text = "",
				Size = UDim2.fromScale(1, 1), ZIndex = 50,
				Parent = refs.card,
			})
		end
		lockBtn.Visible = true
		if refs.title then refs.title.TextTransparency = 0.55 end
		h._locked = true
	end
	function h:Unlock()
		if lockBtn then lockBtn.Visible = false end
		if refs.title then refs.title.TextTransparency = 0 end
		h._locked = false
	end
	function h:Highlight()
		local st = refs.stroke
		if not st or not st.Parent then return end
		st.Color = lib:Theme().accent
		st.Thickness = 2
		task.delay(0.45, function()
			if st and st.Parent then
				st.Thickness = 1
				st.Color = lib:Theme()[refs.strokeToken or "line"]
			end
		end)
	end
	function h:Destroy()
		if refs.card then refs.card:Destroy() end
		if o and o.Flag and lib.Flags[tostring(o.Flag)] == h then
			lib.Flags[tostring(o.Flag)] = nil
		end
	end
	if o and o.Flag then
		lib.Flags[tostring(o.Flag)] = h
		-- 启动回灌：持久化配置里有该 Flag 的已保存值 → 静默应用（不触发回调）
		local pend = lib._Pending and lib._Pending[tostring(o.Flag)]
		if type(pend) == "table" and pend.v ~= nil or type(pend) == "boolean" then
			local pval = type(pend) == "table" and pend.v or pend
			-- 类型适配：keybind 名字→EnumItem，color 字符串→Color3
			if kind == "keybind" and type(pval) == "string" then
				local okk, kc = pcall(function() return Enum.KeyCode[pval] end)
				if okk and kc then pval = kc end
			elseif kind == "color" and type(pval) == "string" then
				local r, g, b = tostring(pval):match("([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)")
				if r then pval = Color3.new(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1) end
			end
			local was = lib._Loading
			lib._Loading = true
			pcall(function() h:Set(pval, false) end)
			lib._Loading = was
		end
	end
	return h
end

-- ===== Section / Tab 对象构造 =====
local function newSection(lib, ctx, tabObj, title)
	local sec = {
		lib = lib, ctx = ctx, tab = tabObj,
		title = tostring(title or "分组"),
		_statRow = nil,
	}
	return sec
end

-- 行卡基元：panel 圆角卡 + 标题/描述 + 右侧控件区
local function rowCard(sec, o, baseH)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local hasDesc = o and (o.Desc or o.desc) and (o.Desc ~= "" or o.desc ~= "")
	local h = baseH + (hasDesc and 18 or 0)
	if ctx.M.mobile and h < 44 then h = 44 end
	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, h),
		BackgroundColor3 = t.panel,
		BackgroundTransparency = t.glass and 0.06 or 0,
		Parent = sec.holder,
		LayoutOrder = sec._order or 0,
	})
	sec._order = (sec._order or 0) + 1
	Corner(card, 12)
	local cardSt = Stroke(card, "line", 1)
	lib:Bind(card, "BackgroundColor3", "panel")
	local refs = { card = card, stroke = cardSt, strokeToken = "line" }
	if hasDesc then
		local title = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -110, 0, 18),
			Font = Enum.Font.GothamMedium, TextSize = ctx.M.body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = tostring(o.Title or o.title or ""), Parent = card,
		})
		lib:Bind(title, "TextColor3", "text")
		local desc = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 26),
			Size = UDim2.new(1, -110, 0, 14),
			Font = Enum.Font.Gotham, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tostring(o.Desc or o.desc), Parent = card,
		})
		lib:Bind(desc, "TextColor3", "muted")
		refs.title = title
		refs.desc = desc
	else
		local title = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -110, 1, 0),
			Font = Enum.Font.GothamMedium, TextSize = ctx.M.body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = tostring(o.Title or o.title or ""), Parent = card,
		})
		lib:Bind(title, "TextColor3", "text")
		refs.title = title
	end
	local right = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(84, h - 12), Parent = card,
	})
	return card, right, refs
end

-- ===== 控件工厂（每个独立函数，隔离寄存器帧） =====
local function ctlButton(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card = New("TextButton", {
		Size = UDim2.new(1, 0, 0, ctx.M.ctlH),
		BackgroundColor3 = t.panel2, Text = "",
		AutoButtonColor = true, Parent = sec.holder,
	})
	sec._order = (sec._order or 0) + 1
	Corner(card, 12)
	local cardSt = Stroke(card, "line", 1)
	lib:Bind(card, "BackgroundColor3", "panel2")
	local title = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(14, 0),
		Font = Enum.Font.GothamMedium, TextSize = ctx.M.body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(o.Title or o.title or "按钮"), Parent = card,
	})
	lib:Bind(title, "TextColor3", "text")
	local arrow = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(20, 20),
		Font = Enum.Font.GothamBold, TextSize = ctx.M.body, Text = "›",
	})
	lib:Bind(arrow, "TextColor3", "accent2")
	arrow.Parent = card
	local btnLock = false
	card.MouseButton1Click:Connect(function()
		if btnLock then return end
		if o.Callback then
			local ok, err = pcall(o.Callback)
			if not ok then warn("[QiurongToolbox] Button 回调出错: " .. tostring(err)) end
		end
	end)
	local h = makeHandle(lib, o, "button",
		function() return nil end,
		function() end,
		{ card = card, title = title, stroke = cardSt })
	function h:Lock() btnLock = true if title then title.TextTransparency = 0.55 end h._locked = true end
	function h:Unlock() btnLock = false if title then title.TextTransparency = 0 end h._locked = false end
	return h
end

local function ctlToggle(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card, right, refs = rowCard(sec, o, ctx.M.ctlH)
	local key = "toggle." .. tostring(o.Flag or (function() lib.Seq += 1 return "auto" .. lib.Seq end)())
	local val = (o.Default == true)
	Values[key] = val
	local isCheckbox = (o.Type == "Checkbox")
	local track, knob, boxLbl
	if isCheckbox then
		boxLbl = New("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold, TextSize = 20,
			Text = val and "☑" or "☐", Parent = right,
		})
		lib:Bind(boxLbl, "TextColor3", "accent")
	else
		track = New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(42, 24), BackgroundColor3 = t.accent,
			Parent = right,
		})
		-- 动态 token 绑定：开/关态随 SetTheme 正确重刷（修复旧版重复 Bind 累积泄漏）
		lib:BindFn(track, "BackgroundColor3", function() return Values[key] and "accent" or "panel3" end)
		Corner(track, 12)
		Stroke(track, "line", 1)
		knob = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(val and 1 or 0, val and -3 or 3, 0.5, 0),
			Size = UDim2.fromOffset(18, 18), BackgroundColor3 = t.text, Parent = track,
		})
		lib:Bind(knob, "BackgroundColor3", "text")
		Corner(knob, 9)
	end
	local clickBtn = New("TextButton", {
		BackgroundTransparency = 1, Text = "",
		Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = right,
	})
	local function apply(v, fire)
		Values[key] = v
		if isCheckbox then
			boxLbl.Text = v and "☑" or "☐"
		else
			track.BackgroundColor3 = lib:Theme()[v and "accent" or "panel3"]
			TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(v and 1 or 0, v and -3 or 3, 0.5, 0),
			}):Play()
		end
		if fire and o.Callback then
			local ok, err = pcall(o.Callback, v)
			if not ok then warn("[QiurongToolbox] Toggle 回调出错: " .. tostring(err)) end
		end
		if fire then saveHook(lib) end
	end
	clickBtn.MouseButton1Click:Connect(function() apply(not Values[key], true) end)
	return makeHandle(lib, o, "toggle",
		function() return Values[key] end,
		function(v, fire) apply(v == true, fire ~= false) end,
		refs)
end

local function ctlSlider(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card, right, refs = rowCard(sec, o, ctx.M.ctlH)
	local mn = tonumber(o.Min) or 0
	local mx = tonumber(o.Max) or 100
	local st = tonumber(o.Step) or 1
	local suffix = tostring(o.Suffix or "")
	local key = "slider." .. tostring(o.Flag or (function() lib.Seq += 1 return "auto" .. lib.Seq end)())
	local function normalize(v)
		v = math.clamp(tonumber(v) or mn, mn, mx)
		if st and st > 0 then
			local steps = math.floor((v - mn) / st + 0.5)
			v = mn + steps * st
			-- 修浮点尾差
			v = tonumber(string.format("%.4g", v))
		end
		return math.clamp(v, mn, mx)
	end
	local val = normalize(o.Default)
	Values[key] = val
	local track = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, -58, 0, 6), BackgroundColor3 = t.panel3, Parent = right,
	})
	lib:Bind(track, "BackgroundColor3", "panel3")
	Corner(track, 3)
	local fill = New("Frame", {
		Size = UDim2.new((val - mn) / math.max(mx - mn, 1e-9), 0, 1, 0),
		BackgroundColor3 = t.accent, Parent = track,
	})
	lib:Bind(fill, "BackgroundColor3", "accent")
	Corner(fill, 3)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new((val - mn) / math.max(mx - mn, 1e-9), 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14), BackgroundColor3 = t.accent2, Parent = track,
	})
	lib:Bind(knob, "BackgroundColor3", "accent2")
	Corner(knob, 7)
	local vLabel = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(50, 20), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 13,
		Text = tostring(val) .. suffix, Parent = right,
	})
	lib:Bind(vLabel, "TextColor3", "text")
	local dragging = false
	local function setVal(v, fire)
		local nv = normalize(v)
		local changed = nv ~= Values[key]
		Values[key] = nv
		local pct = (nv - mn) / math.max(mx - mn, 1e-9)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		knob.Position = UDim2.new(pct, 0, 0.5, 0)
		vLabel.Text = tostring(nv) .. suffix
		if fire and changed and o.Callback then
			local ok, err = pcall(o.Callback, nv)
			if not ok then warn("[QiurongToolbox] Slider 回调出错: " .. tostring(err)) end
		end
		if fire and changed then saveHook(lib) end
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setVal(mn + (mx - mn) * math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1), true)
		end
	end)
	table.insert(ctx._conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setVal(mn + (mx - mn) * math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1), true)
		end
	end))
	table.insert(ctx._conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	local h = makeHandle(lib, o, "slider",
		function() return Values[key] end,
		function(v, fire) setVal(v, fire ~= false) end,
		refs)
	function h:SetMin(nv)
		mn = tonumber(nv) or mn
		if mn > mx then mn = mx end
		setVal(Values[key], false)
	end
	function h:SetMax(nv)
		mx = tonumber(nv) or mx
		if mx < mn then mx = mn end
		setVal(Values[key], false)
	end
	return h
end

-- 选项浮层（dropdown / multi / 主题菜单共用；挂 shell 顶层避免被裁剪）
-- opts.Search = true 顶部搜索栏；opts.AllowNone = true 底部"（无）"清空项；opts.Title 浮层标题
local function openList(ctx, anchorInst, options, current, multi, onPick, onClose, opts)
	local lib = ctx.lib
	local shell = ctx.shell
	local t = lib:Theme()
	ctx:CloseList()
	opts = opts or {}
	local rowH = ctx.M.mobile and 36 or 34
	local maxShow = 6
	local searchOn = opts.Search == true
	local allowNone = opts.AllowNone == true and not multi
	local listH = 40
	local ap = anchorInst.AbsolutePosition - shell.AbsolutePosition
	local box = New("Frame", {
		Position = UDim2.fromOffset(math.floor(ap.X), math.floor(ap.Y + anchorInst.AbsoluteSize.Y + 4)),
		Size = UDim2.fromOffset(anchorInst.AbsoluteSize.X, listH),
		BackgroundColor3 = t.panel2, ZIndex = 60, Parent = ctx.dropdownLayer,
	})
	Corner(box, 10)
	Stroke(box, "accent", 1)
	lib:Bind(box, "BackgroundColor3", "panel2")
	local listTop = 0
	local searchBox
	if searchOn then
		listTop = 32
		searchBox = New("TextBox", {
			Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 24),
			BackgroundColor3 = t.panel3, Text = "",
			PlaceholderText = tostring(opts.SearchPlaceholder or "搜索..."),
			Font = Enum.Font.GothamMedium, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
			ZIndex = 61, Parent = box,
		})
		Pad(searchBox, 8, 0, 8, 0)
		Corner(searchBox, 6)
		Stroke(searchBox, "line", 1)
		lib:Bind(searchBox, "BackgroundColor3", "panel3")
		lib:Bind(searchBox, "TextColor3", "text")
		lib:Bind(searchBox, "PlaceholderColor3", "muted")
	end
	local sc = New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, listTop),
		Size = UDim2.new(1, 0, 1, -listTop),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = t.accent, ZIndex = 61, Parent = box,
	})
	lib:Bind(sc, "ScrollBarImageColor3", "accent")
	VList(sc, 2)
	local sel = {}
	if multi and type(current) == "table" then
		for v in pairs(current) do sel[v] = true end
	end
	local function buildRows(filter)
		for _, c in ipairs(sc:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		local shown = 0
		local needle = filter and string.lower(tostring(filter)) or ""
		if needle == "" then needle = nil end
		for i, opt in ipairs(options) do
			local optText = tostring(opt)
			if not needle or string.find(string.lower(optText), needle, 1, true) then
				shown += 1
				local optBtn = New("TextButton", {
					Size = UDim2.new(1, -8, 0, rowH), Text = "",
					BackgroundColor3 = t.accent, BackgroundTransparency = 1,
					LayoutOrder = i, ZIndex = 62, Parent = sc,
				})
				Corner(optBtn, 6)
				local isOn = multi and sel[optText] or (optText == tostring(current))
				local lbl = New("TextLabel", {
					BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(10, 0),
					Font = Enum.Font.GothamMedium, TextSize = ctx.M.body,
					TextXAlignment = Enum.TextXAlignment.Left, Text = optText, Parent = optBtn,
				})
				-- 动态 token：multi 行点击切换选中态后，SetTheme 重算仍取当前状态（静态 Bind 会刷回打开时的旧状态）
				if multi then
					lib:BindFn(lbl, "TextColor3", function() return sel[optText] and "accent" or "text" end)
				else
					lib:Bind(lbl, "TextColor3", isOn and "accent" or "text")
				end
				local mark
				if multi then
					mark = New("TextLabel", {
						BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(16, 16),
						Font = Enum.Font.GothamBold, TextSize = 14,
						Text = sel[optText] and "✓" or "", Parent = optBtn,
					})
					lib:Bind(mark, "TextColor3", "accent")
				end
				optBtn.MouseButton1Click:Connect(function()
					if multi then
						if sel[optText] then sel[optText] = nil else sel[optText] = true end
						lbl.TextColor3 = lib:Theme()[sel[optText] and "accent" or "text"]
						mark.Text = sel[optText] and "✓" or ""
					end
					onPick(optText, sel[optText] == true)
				end)
			end
		end
		if allowNone then
			shown += 1
			local noneBtn = New("TextButton", {
				Size = UDim2.new(1, -8, 0, rowH), Text = "",
				BackgroundTransparency = 1,
				LayoutOrder = 9999, ZIndex = 62, Parent = sc,
			})
			local nlbl = New("TextLabel", {
				BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(10, 0),
				Font = Enum.Font.GothamMedium, TextSize = ctx.M.body,
				TextXAlignment = Enum.TextXAlignment.Left, Text = "（无）", Parent = noneBtn,
			})
			lib:Bind(nlbl, "TextColor3", "muted")
			noneBtn.MouseButton1Click:Connect(function()
				onPick(nil, false)
			end)
		end
		listH = math.min(shown, maxShow) * rowH + 12 + listTop
		box.Size = UDim2.fromOffset(anchorInst.AbsoluteSize.X, listH)
	end
	buildRows(nil)
	if searchOn then
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			buildRows(searchBox.Text)
		end)
	end
	ctx.activeList = {
		box = box,
		conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local m = UserInputService:GetMouseLocation()
				local bp = box.AbsolutePosition
				local bs = box.AbsoluteSize
				if m.X < bp.X or m.X > bp.X + bs.X or m.Y < bp.Y or m.Y > bp.Y + bs.Y then
					ctx:CloseList()
				end
			end
		end),
	}
	if onClose then ctx.activeList.onClose = onClose end
end

local function closeListImpl(ctx)
	if ctx.activeList then
		pcall(function() ctx.activeList.conn:Disconnect() end)
		if ctx.activeList.extraConns then
			for _, c in ipairs(ctx.activeList.extraConns) do
				pcall(function() c:Disconnect() end)
			end
		end
		if ctx.activeList.box then ctx.activeList.box:Destroy() end
		if ctx.activeList.onClose then pcall(ctx.activeList.onClose) end
		ctx.activeList = nil
	end
end

local function ctlDropdown(sec, o, multi)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card, right, refs = rowCard(sec, o, ctx.M.ctlH)
	local key = (multi and "multi." or "dropdown.") .. tostring(o.Flag or (function() lib.Seq += 1 return "auto" .. lib.Seq end)())
	local options = {}
	for _, v in ipairs(type(o.Options) == "table" and o.Options or {}) do
		table.insert(options, tostring(v))
	end
	local current = multi and {} or tostring(o.Default or options[1] or "")
	if multi and type(o.Default) == "table" then
		for _, v in ipairs(o.Default) do current[tostring(v)] = true end
	end
	Values[key] = current
	local btn = New("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = t.panel3, Text = "",
		Parent = right,
	})
	Corner(btn, 8)
	Stroke(btn, "line", 1)
	lib:Bind(btn, "BackgroundColor3", "panel3")
	local curText
	if multi then
		local n = 0
		for _ in pairs(current) do n += 1 end
		curText = n > 0 and ("已选 " .. n) or "全选"
	else
		curText = current
	end
	local lbl = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(10, 0),
		Font = Enum.Font.GothamMedium, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left, Text = curText, Parent = btn,
	})
	lib:Bind(lbl, "TextColor3", "text")
	local caret = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(14, 14),
		Font = Enum.Font.GothamBold, TextSize = 12, Text = "▾",
	})
	lib:Bind(caret, "TextColor3", "muted")
	caret.Parent = btn
	local function refreshLabel()
		if multi then
			local n = 0
			for _ in pairs(Values[key]) do n += 1 end
			lbl.Text = n > 0 and ("已选 " .. n) or "全选"
		else
			lbl.Text = tostring(Values[key])
		end
	end
	local function fireChange(v)
		if o.Callback then
			local ok, err = pcall(o.Callback, v)
			if not ok then warn("[QiurongToolbox] " .. (multi and "Multi" or "Dropdown") .. " 回调出错: " .. tostring(err)) end
		end
	end
	btn.MouseButton1Click:Connect(function()
		if ctx.activeList and ctx.activeList.anchor == btn then
			ctx:CloseList()
			return
		end
		if multi then
			openList(ctx, btn, options, Values[key], true, function(optText, on)
				if on then Values[key][optText] = true else Values[key][optText] = nil end
				refreshLabel()
				local picked = {}
				for v in pairs(Values[key]) do table.insert(picked, v) end
				fireChange(picked)
				saveHook(lib)
			end, nil, { Search = o.SearchBarEnabled == true })
		else
			openList(ctx, btn, options, Values[key], false, function(optText)
				Values[key] = optText and tostring(optText) or ""
				refreshLabel()
				ctx:CloseList()
				fireChange(optText and tostring(optText) or nil)
				saveHook(lib)
			end, nil, { AllowNone = o.AllowNone == true, Search = o.SearchBarEnabled == true })
		end
		if ctx.activeList then ctx.activeList.anchor = btn end
	end)
	local h = makeHandle(lib, o, multi and "multi" or "dropdown",
		function() return Values[key] end,
		function(v, fire)
			if multi then
				Values[key] = {}
				if type(v) == "table" then
					for _, item in ipairs(v) do Values[key][tostring(item)] = true end
				end
			else
				Values[key] = v and tostring(v) or ""
			end
			refreshLabel()
			if fire then
				if multi then
					local picked = {}
					for item in pairs(Values[key]) do table.insert(picked, item) end
					fireChange(picked)
				else
					fireChange(Values[key] ~= "" and Values[key] or nil)
				end
			end
		end, refs)
	function h:Select(v)
		h:Set(v, true)
	end
	function h:SetOptions(list)
		options = {}
		for _, v in ipairs(type(list) == "table" and list or {}) do
			table.insert(options, tostring(v))
		end
		if not multi and Values[key] ~= "" and not table.find(options, Values[key]) then
			Values[key] = options[1] or ""
			refreshLabel()
		end
	end
	return h
end

local function ctlMulti(sec, o)
	return ctlDropdown(sec, o, true)
end

local function ctlInput(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card, right, refs = rowCard(sec, o, ctx.M.ctlH)
	local key = "input." .. tostring(o.Flag or (function() lib.Seq += 1 return "auto" .. lib.Seq end)())
	Values[key] = tostring(o.Default or "")
	local box = New("TextBox", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = t.panel3, Text = "",
		PlaceholderText = tostring(o.Placeholder or "输入..."),
		Font = Enum.Font.GothamMedium, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
		Text = Values[key], Parent = right,
	})
	Pad(box, 10, 0, 10, 0)
	Corner(box, 8)
	Stroke(box, "line", 1)
	lib:Bind(box, "BackgroundColor3", "panel3")
	lib:Bind(box, "TextColor3", "text")
	lib:Bind(box, "PlaceholderColor3", "muted")
	box.FocusLost:Connect(function(enter)
		Values[key] = box.Text
		if o.Callback and (enter or o.CallbackOnBlur ~= false) then
			local ok, err = pcall(o.Callback, box.Text, enter)
			if not ok then warn("[QiurongToolbox] Input 回调出错: " .. tostring(err)) end
		end
		if lib._Loading then return end
		saveHook(lib)
	end)
	return makeHandle(lib, o, "input",
		function() return Values[key] end,
		function(v)
			box.Text = tostring(v or "")
			Values[key] = box.Text
		end, refs)
end

local function ctlKeybind(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card, right, refs = rowCard(sec, o, ctx.M.ctlH)
	local current = o.Default or nil
	local listening = false
	local btn = New("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = t.panel3,
		Font = Enum.Font.GothamBold, TextSize = 12,
		Text = current and current.Name or "未绑定", Parent = right,
	})
	Corner(btn, 8)
	Stroke(btn, "line", 1)
	lib:Bind(btn, "BackgroundColor3", "panel3")
	lib:Bind(btn, "TextColor3", "text")
	local conn
	btn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		btn.Text = "按下按键..."
		conn = UserInputService.InputBegan:Connect(function(input, gpe)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				pcall(function()
					if input.KeyCode == Enum.KeyCode.Escape then
						btn.Text = current and current.Name or "未绑定"
					else
						current = input.KeyCode
						btn.Text = current.Name
						if o.Callback then pcall(o.Callback, current) end
						if not lib._Loading then saveHook(lib) end
					end
				end)
				if conn then conn:Disconnect() conn = nil end
				listening = false
			end
		end)
	end)
	local h = makeHandle(lib, o, "keybind",
		function() return current end,
		function(v, fire)
			current = v
			if btn.Parent then btn.Text = v and v.Name or "未绑定" end
			if fire and o.Callback and v then pcall(o.Callback, v) end
		end, refs)
	return h
end

-- 颜色选择器：右侧行内色块 → 弹出 HSV 面板（SV 渐变 + 色相条 + 预设色板 + Hex）
local function ctlColorpicker(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card, right, refs = rowCard(sec, o, ctx.M.ctlH)
	local key = "color." .. tostring(o.Flag or (function() lib.Seq += 1 return "auto" .. lib.Seq end)())
	local color = typeof(o.Default) == "Color3" and o.Default or Color3.fromRGB(255, 255, 255)
	Values[key] = color
	local hCur, sCur, vCur = Color3.toHSV(color)
	local swatch = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(30, 22), BackgroundColor3 = color, Text = "",
		Parent = right, ZIndex = 5,
	})
	Corner(swatch, 6)
	Stroke(swatch, "line", 1)
	local function applyColor(fire)
		color = Color3.fromHSV(hCur, sCur, vCur)
		Values[key] = color
		if swatch.Parent then swatch.BackgroundColor3 = color end
		if fire and o.Callback then
			local ok, err = pcall(o.Callback, color)
			if not ok then warn("[QiurongToolbox] ColorPicker 回调出错: " .. tostring(err)) end
		end
		if fire then saveHook(lib) end
	end
	swatch.MouseButton1Click:Connect(function()
		ctx:CloseList()
		local PW = 210
		local SVH = 132
		local HUEH = 12
		local ap = swatch.AbsolutePosition - ctx.shell.AbsolutePosition
		local bx = math.floor(ap.X)
		if bx + PW > ctx.shell.AbsoluteSize.X - 10 then bx = math.floor(ctx.shell.AbsoluteSize.X - PW - 10) end
		if bx < 10 then bx = 10 end
		local box = New("Frame", {
			Position = UDim2.fromOffset(bx, math.floor(ap.Y + swatch.AbsoluteSize.Y + 6)),
			Size = UDim2.fromOffset(PW, 268),
			BackgroundColor3 = t.panel2, ZIndex = 60, Parent = ctx.dropdownLayer,
		})
		Corner(box, 10)
		Stroke(box, "accent", 1)
		lib:Bind(box, "BackgroundColor3", "panel2")
		-- SV 面板：底色 = 当前色相；白层左→右透明；黑层上→下变黑
		local sv = New("Frame", {
			Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(PW - 16, SVH),
			BackgroundColor3 = Color3.fromHSV(hCur, 1, 1), ZIndex = 61, Parent = box,
		})
		Corner(sv, 8)
		local whiteL = New("Frame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 62, Parent = sv,
		})
		Corner(whiteL, 8)
		New("UIGradient", { Rotation = 0, Transparency = NumberSequence.new(0, 1), Parent = whiteL })
		local blackL = New("Frame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 63, Parent = sv,
		})
		Corner(blackL, 8)
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = blackL })
		local svDot = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(sCur * (PW - 16), (1 - vCur) * SVH),
			Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 64, Parent = sv,
		})
		Corner(svDot, 6)
		Stroke(svDot, "text", 2)
		-- 色相条
		local hue = New("Frame", {
			Position = UDim2.fromOffset(8, 8 + SVH + 8), Size = UDim2.fromOffset(PW - 16, HUEH),
			BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 61, Parent = box,
		})
		Corner(hue, 6)
		New("UIGradient", {
			Rotation = 0, Parent = hue,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
			}),
		})
		local hueDot = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(hCur * (PW - 16), HUEH / 2),
			Size = UDim2.fromOffset(6, HUEH + 8), BackgroundTransparency = 1, ZIndex = 64, Parent = hue,
		})
		Corner(hueDot, 3)
		Stroke(hueDot, "text", 2)
		-- 预设色板
		local presets = {
			Color3.fromRGB(57, 200, 255), Color3.fromRGB(131, 212, 107), Color3.fromRGB(76, 141, 255),
			Color3.fromRGB(255, 107, 122), Color3.fromRGB(255, 203, 105), Color3.fromRGB(155, 130, 255),
			Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 168, 176), Color3.fromRGB(60, 66, 74),
			Color3.fromRGB(10, 12, 16),
		}
		local pr = New("Frame", {
			Position = UDim2.fromOffset(8, 8 + SVH + HUEH + 18), Size = UDim2.fromOffset(PW - 16, 24),
			BackgroundTransparency = 1, ZIndex = 61, Parent = box,
		})
		local hl = New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pr,
		})
		for pi, pc in ipairs(presets) do
			local pb = New("TextButton", {
				Size = UDim2.new(0.1, -5, 1, 0), BackgroundColor3 = pc, Text = "",
				LayoutOrder = pi, ZIndex = 62, Parent = pr,
			})
			Corner(pb, 6)
			Stroke(pb, "line", 1)
			pb.MouseButton1Click:Connect(function()
				hCur, sCur, vCur = Color3.toHSV(pc)
				applyColor(true)
			end)
		end
		-- Hex 显示
		local hexLbl = New("TextLabel", {
			Position = UDim2.fromOffset(8, 8 + SVH + HUEH + 48), Size = UDim2.new(1, -16, 0, 16),
			BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 61, Parent = box,
		})
		lib:Bind(hexLbl, "TextColor3", "muted")
		local function refreshPicker()
			if not sv.Parent then return end
			sv.BackgroundColor3 = Color3.fromHSV(hCur, 1, 1)
			svDot.Position = UDim2.fromOffset(sCur * (PW - 16), (1 - vCur) * SVH)
			hueDot.Position = UDim2.fromOffset(hCur * (PW - 16), HUEH / 2)
			hexLbl.Text = "#" .. color:ToHex():upper() .. string.format("   H%.0f S%.0f%% V%.0f%%", hCur * 360, sCur * 100, vCur * 100)
		end
		local extra = {}
		local svDrag, hueDrag = false, false
		local function svUpdate(input)
			local rp = input.Position - sv.AbsolutePosition
			sCur = math.clamp(rp.X / math.max(sv.AbsoluteSize.X, 1), 0, 1)
			vCur = 1 - math.clamp(rp.Y / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
			applyColor(true)
			refreshPicker()
		end
		local function hueUpdate(input)
			local rp = input.Position - hue.AbsolutePosition
			hCur = math.clamp(rp.X / math.max(hue.AbsoluteSize.X, 1), 0, 0.999)
			applyColor(true)
			refreshPicker()
		end
		sv.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				svDrag = true
				svUpdate(input)
			end
		end)
		hue.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				hueDrag = true
				hueUpdate(input)
			end
		end)
		table.insert(extra, UserInputService.InputChanged:Connect(function(input)
			if svDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				svUpdate(input)
			elseif hueDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				hueUpdate(input)
			end
		end))
		table.insert(extra, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				svDrag = false
				hueDrag = false
			end
		end))
		refreshPicker()
		ctx.activeList = {
			box = box,
			extraConns = extra,
			conn = UserInputService.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local m = UserInputService:GetMouseLocation()
					local bp = box.AbsolutePosition
					local bs = box.AbsoluteSize
					if m.X < bp.X or m.X > bp.X + bs.X or m.Y < bp.Y or m.Y > bp.Y + bs.Y then
						ctx:CloseList()
					end
				end
			end),
		}
	end)
	local h = makeHandle(lib, o, "color",
		function() return Values[key] end,
		function(cv, fire)
			if typeof(cv) == "Color3" then
				hCur, sCur, vCur = Color3.toHSV(cv)
				applyColor(fire ~= false)
			end
		end, refs)
	return h
end

local function ctlLabel(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = sec.holder,
	})
	sec._order = (sec._order or 0) + 1
	local lbl = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(tostring(o.Title or o.title or "")), Parent = card,
	})
	lib:Bind(lbl, "TextColor3", "muted")
	return makeHandle(lib, o, "label",
		function() return tostring(lbl.Text) end,
		function(v)
			lbl.Text = string.upper(tostring(v or ""))
		end,
		{ card = card, title = lbl })
end

local function ctlDivider(sec)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local line = New("Frame", {
		Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = t.line_soft,
		BorderSizePixel = 0, Parent = sec.holder,
	})
	sec._order = (sec._order or 0) + 1
	lib:Bind(line, "BackgroundColor3", "line_soft")
	return makeHandle(lib, o or {}, "divider",
		function() return nil end,
		function() end,
		{ card = line })
end

local function ctlParagraph(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local descs = type(o.Desc) == "table" and o.Desc or (o.Desc and { tostring(o.Desc) } or {})
	local h = (ctx.M.mobile and 52 or 68) + (o.Badge and (ctx.M.mobile and 30 or 38) or 0) + #descs * (ctx.M.mobile and 18 or 22) + 14
	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = t.panel, Parent = sec.holder,
	})
	sec._order = (sec._order or 0) + 1
	Corner(card, 14)
	local cardSt = Stroke(card, "line", 1)
	lib:Bind(card, "BackgroundColor3", "panel")
	local sp = ctx.M.mobile and 12 or 18
	local y = sp
	if o.Badge then
		local badge = New("Frame", {
			Size = UDim2.new(1, -sp * 2, 0, ctx.M.mobile and 26 or 34),
			Position = UDim2.fromOffset(sp, y), BackgroundColor3 = t.accent,
			BackgroundTransparency = 0.68, Parent = card,
		})
		Corner(badge, 10)
		Stroke(badge, "accent", 1)
		lib:Bind(badge, "BackgroundColor3", "accent")
		local dot = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(8, 8), BackgroundColor3 = t.accent, Parent = badge,
		})
		lib:Bind(dot, "BackgroundColor3", "accent")
		Corner(dot, 4)
		local bt = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(1, -36, 1, 0), Font = Enum.Font.GothamBold,
			TextSize = ctx.M.mobile and 12 or 15, TextXAlignment = Enum.TextXAlignment.Left,
			Text = tostring(o.Badge), Parent = badge,
		})
		lib:Bind(bt, "TextColor3", "accent2")
		y += badge.Size.Y.Offset + 8
	end
	local big = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(sp, y),
		Size = UDim2.new(1, -sp * 2, 0, ctx.M.mobile and 28 or 44),
		Font = Enum.Font.GothamBold, TextSize = ctx.M.big,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(o.Title or o.title or ""), Parent = card,
	})
	lib:Bind(big, "TextColor3", "text")
	y += big.Size.Y.Offset + 6
	-- 描述行集中管理：支持 SetDesc 动态重建
	local descLabels = {}
	local function rebuildDesc(items)
		for _, l in ipairs(descLabels) do l:Destroy() end
		descLabels = {}
		local list = type(items) == "table" and items or (items and { tostring(items) } or {})
		for _, d in ipairs(list) do
			local dl = New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(sp, y),
				Size = UDim2.new(1, -sp * 2, 0, ctx.M.mobile and 16 or 20),
				Font = Enum.Font.Gotham, TextSize = ctx.M.mobile and 12 or 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = tostring(d), Parent = card,
			})
			lib:Bind(dl, "TextColor3", "muted")
			table.insert(descLabels, dl)
			y += dl.Size.Y.Offset
		end
		card.Size = UDim2.new(1, 0, 0, y + 14)
	end
	rebuildDesc(descs)
	local hnd = makeHandle(lib, o, "paragraph",
		function() return descs end,
		function() end,
		{ card = card, stroke = cardSt, title = big })
	function hnd:SetTitle(v)
		if big.Parent then big.Text = tostring(v) end
	end
	function hnd:SetDesc(v)
		descs = v
		rebuildDesc(v)
	end
	return hnd
end

local function ctlStat(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local cellW = 0.5
	local parent, posX
	if sec._statRow then
		parent = sec._statRow
		posX = UDim2.new(0.5, 5, 0, 0)
		sec._statRow = nil
	else
		local row = New("Frame", {
			Size = UDim2.new(1, 0, 0, ctx.M.mobile and 46 or 60),
			BackgroundTransparency = 1, Parent = sec.holder,
		})
		sec._order = (sec._order or 0) + 1
		sec._statRow = row
		parent = row
		posX = UDim2.new(0, 0, 0, 0)
	end
	local cell = New("Frame", {
		Position = posX, Size = UDim2.new(cellW, posX.X.Offset ~= 0 and -5 or 0, 1, 0),
		BackgroundColor3 = t.panel, Parent = parent,
	})
	Corner(cell, 10)
	Stroke(cell, "line", 1)
	lib:Bind(cell, "BackgroundColor3", "panel")
	local topLine = New("Frame", {
		Size = UDim2.new(1, -20, 0, 2), Position = UDim2.fromOffset(10, 0),
		BackgroundColor3 = t.line, BorderSizePixel = 0, Parent = cell,
	})
	lib:Bind(topLine, "BackgroundColor3", "line")
	local num = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -20, 0, ctx.M.mobile and 20 or 28),
		Font = Enum.Font.GothamBold, TextSize = ctx.M.mobile and 16 or 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(o.Number or o.number or ""), Parent = cell,
	})
	lib:Bind(num, "TextColor3", "accent")
	local lbl = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, ctx.M.mobile and 26 or 34),
		Size = UDim2.new(1, -20, 0, 14), Font = Enum.Font.Gotham,
		TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(o.Label or o.label or ""), Parent = cell,
	})
	lib:Bind(lbl, "TextColor3", "muted")
	local h = makeHandle(lib, o, "stat",
		function() return tostring(num.Text) end,
		function(v)
			num.Text = tostring(v)
		end,
		{ card = cell, title = lbl })
	function h:SetLabel(v)
		if lbl.Parent then lbl.Text = tostring(v) end
	end
	return h
end

local function ctlCard(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local token = tostring(o.Color or o.color or "accent")
	if not t[token] then token = "accent" end
	local bullets = type(o.Bullets) == "table" and o.Bullets or {}
	local lineH = ctx.M.mobile and 19 or 23
	local h = (ctx.M.mobile and 50 or 60) + #bullets * lineH + 12
	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = t.panel, Parent = sec.holder,
	})
	sec._order = (sec._order or 0) + 1
	sec._statRow = nil
	Corner(card, 12)
	Stroke(card, "line", 1)
	lib:Bind(card, "BackgroundColor3", "panel")
	local strip = New("Frame", {
		Size = UDim2.new(0, 5, 1, -16), Position = UDim2.new(0, 0, 0, 8),
		BackgroundColor3 = t[token], Parent = card,
	})
	Corner(strip, 2)
	lib:Bind(strip, "BackgroundColor3", token)
	local badge = New("Frame", {
		Size = UDim2.fromOffset(ctx.M.mobile and 24 or 32, ctx.M.mobile and 24 or 32),
		Position = UDim2.fromOffset(ctx.M.mobile and 14 or 16, ctx.M.mobile and 12 or 14),
		BackgroundColor3 = t[token], BackgroundTransparency = 0.8, Parent = card,
	})
	Corner(badge, 7)
	Stroke(badge, token, 1, 0.2, lib)
	lib:Bind(badge, "BackgroundColor3", token)
	local bt = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold, TextSize = ctx.M.mobile and 12 or 15,
		Text = tostring(o.Key or o.key or ""), Parent = badge,
	})
	lib:Bind(bt, "TextColor3", token)
	local title = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(ctx.M.mobile and 46 or 56, ctx.M.mobile and 14 or 16),
		Size = UDim2.new(1, -(ctx.M.mobile and 60 or 72), 0, ctx.M.mobile and 22 or 28),
		Font = Enum.Font.GothamBold, TextSize = ctx.M.mobile and 14 or 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(o.Title or o.title or ""), Parent = card,
	})
	lib:Bind(title, "TextColor3", "text")
	local bulletRows = {}
	local by = ctx.M.mobile and 42 or 52
	for _, line in ipairs(bullets) do
		local dot = New("Frame", {
			Position = UDim2.fromOffset(ctx.M.mobile and 20 or 24, by + 7),
			Size = UDim2.fromOffset(6, 6), BackgroundColor3 = t[token], Parent = card,
		})
		Corner(dot, 3)
		lib:Bind(dot, "BackgroundColor3", token)
		local bl = New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(ctx.M.mobile and 32 or 38, by),
			Size = UDim2.new(1, -(ctx.M.mobile and 44 or 52), 0, lineH - 2),
			Font = Enum.Font.Gotham, TextSize = ctx.M.body,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tostring(line), Parent = card,
		})
		lib:Bind(bl, "TextColor3", "text")
		table.insert(bulletRows, { dot = dot, lbl = bl })
		by += lineH
	end
	local h = makeHandle(lib, o, "card",
		function() return tostring(title.Text) end,
		function(v)
			if title.Parent then title.Text = tostring(v) end
		end,
		{ card = card, title = title })
	function h:SetBullets(list)
		for _, row in ipairs(bulletRows) do
			row.dot:Destroy()
			row.lbl:Destroy()
		end
		local items = type(list) == "table" and list or {}
		card.Size = UDim2.new(1, 0, 0, (ctx.M.mobile and 50 or 60) + #items * lineH + 12)
		local yy = ctx.M.mobile and 42 or 52
		for _, line in ipairs(items) do
			local dot = New("Frame", {
				Position = UDim2.fromOffset(ctx.M.mobile and 20 or 24, yy + 7),
				Size = UDim2.fromOffset(6, 6), BackgroundColor3 = t[token], Parent = card,
			})
			Corner(dot, 3)
			lib:Bind(dot, "BackgroundColor3", token)
			local bl = New("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(ctx.M.mobile and 32 or 38, yy),
				Size = UDim2.new(1, -(ctx.M.mobile and 44 or 52), 0, lineH - 2),
				Font = Enum.Font.Gotham, TextSize = ctx.M.body,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = tostring(line), Parent = card,
			})
			lib:Bind(bl, "TextColor3", "text")
			table.insert(bulletRows, { dot = dot, lbl = bl })
			yy += lineH
		end
	end
	return h
end

-- Section builder 方法表（挂在 tabObj 的 Sec 上）
local SectionMethods = {}
SectionMethods.__index = SectionMethods
function SectionMethods:Button(o) return ctlButton(self, o or {}) end
function SectionMethods:Toggle(o) return ctlToggle(self, o or {}) end
function SectionMethods:Slider(o) return ctlSlider(self, o or {}) end
function SectionMethods:Dropdown(o) return ctlDropdown(self, o or {}, false) end
function SectionMethods:Multi(o) return ctlMulti(self, o or {}) end
function SectionMethods:Input(o) return ctlInput(self, o or {}) end
function SectionMethods:Keybind(o) return ctlKeybind(self, o or {}) end
function SectionMethods:Label(o) return ctlLabel(self, o or {}) end
function SectionMethods:Divider() return ctlDivider(self) end
function SectionMethods:Paragraph(o) return ctlParagraph(self, o or {}) end
function SectionMethods:Stat(o) return ctlStat(self, o or {}) end
function SectionMethods:Card(o) return ctlCard(self, o or {}) end
function SectionMethods:ColorPicker(o) return ctlColorpicker(self, o or {}) end

-- ===== 窗口壳 =====
local function buildPattern(lib, shell, t, M)
	local layer = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = 0, ClipsDescendants = true, Parent = shell,
	})
	local soft = t.line_soft
	local acc = t.accent
	if t.pattern == "grid" then
		local step = 56
		local w = M.win.w
		local h = M.win.h
		for x = 0, w, step do
			local v = New("Frame", {
				Position = UDim2.fromOffset(x, 0), Size = UDim2.new(0, 1, 1, 0),
				BackgroundColor3 = soft, BackgroundTransparency = 0.55,
				BorderSizePixel = 0, ZIndex = 0, Parent = layer,
			})
		end
		for y = 0, h, step do
			local hl = New("Frame", {
				Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = soft, BackgroundTransparency = 0.55,
				BorderSizePixel = 0, ZIndex = 0, Parent = layer,
			})
		end
		for i = 0, 4 do
			local tick = New("Frame", {
				Position = UDim2.fromOffset(12 + i * 180, 12),
				Size = UDim2.fromOffset(32, 3), BackgroundColor3 = acc,
				BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 0, Parent = layer,
			})
		end
	elseif t.pattern == "circuit" then
		for i = 0, 11 do
			local x = 24 + i * math.max(96, math.floor(M.win.w / 12))
			local y = 20 + (i % 4) * 30
			local seg1 = New("Frame", {
				Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(64, 2),
				BackgroundColor3 = soft, BackgroundTransparency = 0.4,
				BorderSizePixel = 0, ZIndex = 0, Parent = layer,
			})
			local seg2 = New("Frame", {
				Position = UDim2.fromOffset(x + 62, y), Size = UDim2.fromOffset(2, 22),
				BackgroundColor3 = soft, BackgroundTransparency = 0.4,
				BorderSizePixel = 0, ZIndex = 0, Parent = layer,
			})
			local seg3 = New("Frame", {
				Position = UDim2.fromOffset(x + 62, y + 22), Size = UDim2.fromOffset(90, 2),
				BackgroundColor3 = soft, BackgroundTransparency = 0.4,
				BorderSizePixel = 0, ZIndex = 0, Parent = layer,
			})
			local dot = New("Frame", {
				Position = UDim2.fromOffset(x + 150, y + 19), Size = UDim2.fromOffset(8, 8),
				BackgroundColor3 = acc, BackgroundTransparency = 0.35,
				BorderSizePixel = 0, ZIndex = 0, Parent = layer,
			})
			Corner(dot, 4)
		end
	else -- minimal
		local top = New("Frame", {
			Position = UDim2.fromOffset(24, 18), Size = UDim2.new(1, -48, 0, 2),
			BackgroundColor3 = soft, BackgroundTransparency = 0.5,
			BorderSizePixel = 0, ZIndex = 0, Parent = layer,
		})
		local bot = New("Frame", {
			Position = UDim2.fromOffset(24, M.win.h - 20), Size = UDim2.fromOffset(280, 2),
			BackgroundColor3 = soft, BackgroundTransparency = 0.5,
			BorderSizePixel = 0, ZIndex = 0, Parent = layer,
		})
	end
	return layer
end

local function buildTopBar(lib, ctx, cfg)
	local M = ctx.M
	local t = lib:Theme()
	local top = New("Frame", {
		Size = UDim2.new(1, 0, 0, M.top), BackgroundTransparency = 1, Parent = ctx.shell,
	})
	ctx.top = top
	-- Logo 卡
	local logoW = M.mobile and 190 or 300
	local logo = New("Frame", {
		Position = UDim2.fromOffset(M.pad, M.pad),
		Size = UDim2.new(0, logoW, 1, -M.pad * 2),
		BackgroundColor3 = t.panel2, Parent = top,
	})
	Corner(logo, M.mobile and 12 or 20)
	Stroke(logo, "accent", 1.5)
	lib:Bind(logo, "BackgroundColor3", "panel2")
	local mark = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, M.mobile and 10 or 16, 0.5, 0),
		Size = UDim2.fromOffset(M.mobile and 34 or 50, M.mobile and 34 or 50),
		BackgroundColor3 = t.accent, Parent = logo,
	})
	Corner(mark, M.mobile and 9 or 13)
	Stroke(mark, "accent2", 1.5)
	lib:Bind(mark, "BackgroundColor3", "accent")
	local markText = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold, TextSize = M.mobile and 18 or 24,
		Text = "秋", Parent = mark,
	})
	lib:Bind(markText, "TextColor3", "bg")
	local title = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(M.mobile and 52 or 78, M.mobile and 8 or 16),
		Size = UDim2.new(1, -(M.mobile and 60 or 90), 0, M.mobile and 22 or 34),
		Font = Enum.Font.GothamBold, TextSize = M.mobile and 17 or 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(cfg.Title or cfg.Name or "秋容工具箱"), Parent = logo,
	})
	lib:Bind(title, "TextColor3", "text")
	local subtitle = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(M.mobile and 52 or 78, M.mobile and 30 or 52),
		Size = UDim2.new(1, -(M.mobile and 60 or 90), 0, 14),
		Font = Enum.Font.GothamBold, TextSize = M.mobile and 9 or 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(tostring(cfg.Subtitle or "QIURONG / ROBLOX UI")), Parent = logo,
	})
	lib:Bind(subtitle, "TextColor3", "accent2")
	-- 跑马灯
	local ctlW = M.mobile and 96 or 170
	local ticker = New("Frame", {
		Position = UDim2.fromOffset(M.pad + logoW + M.gap, M.pad),
		Size = UDim2.new(1, -(logoW + ctlW + M.gap * 2 + M.pad * 2), 1, -M.pad * 2),
		BackgroundColor3 = t.panel3, ClipsDescendants = true, Parent = top,
	})
	Corner(ticker, M.mobile and 10 or 16)
	Stroke(ticker, "line", 1)
	lib:Bind(ticker, "BackgroundColor3", "panel3")
	local badgeW = M.mobile and 64 or 104
	local badge = New("Frame", {
		Position = UDim2.fromOffset(M.mobile and 8 or 12, M.mobile and 8 or 12),
		Size = UDim2.new(0, badgeW, 1, -(M.mobile and 16 or 24)),
		BackgroundColor3 = t.accent, Parent = ticker,
	})
	Corner(badge, M.mobile and 8 or 10)
	lib:Bind(badge, "BackgroundColor3", "accent")
	local badgeText = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold, TextSize = M.mobile and 12 or 17,
		Text = tostring(cfg.NoticeBadge or "置顶公告"), Parent = badge,
	})
	lib:Bind(badgeText, "TextColor3", "bg")
	local marquee = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, badgeW + (M.mobile and 22 or 32), 0.5, 0),
		Size = UDim2.new(1, -(badgeW + (M.mobile and 30 or 42)), 1, 0),
		Font = Enum.Font.GothamMedium, TextSize = M.mobile and 13 or 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(cfg.Marquee or "欢迎秋容工具箱 · 求点赞关注，谢谢支持"), Parent = ticker,
	})
	lib:Bind(marquee, "TextColor3", "text")
	ctx.marquee = marquee
	ctx.marqueeX = 0
	-- 最小化 / 主题切换 / 关闭
	local btnH = M.top - M.pad * 2
	local btnW = math.floor((ctlW - M.gap * 2) / 3)
	local themeBtn = New("TextButton", {
		Position = UDim2.new(1, -(ctlW + M.pad), 0, M.pad),
		Size = UDim2.fromOffset(btnW, btnH),
		BackgroundColor3 = t.panel2, Font = Enum.Font.GothamBold,
		TextSize = M.mobile and 18 or 24, Text = "◐", Parent = top,
	})
	Corner(themeBtn, M.mobile and 10 or 14)
	Stroke(themeBtn, "line", 1)
	lib:Bind(themeBtn, "BackgroundColor3", "panel2")
	lib:Bind(themeBtn, "TextColor3", "accent2")
	local minBtn = New("TextButton", {
		Position = UDim2.new(1, -(ctlW + M.pad) + btnW + M.gap, 0, M.pad),
		Size = UDim2.fromOffset(btnW, btnH),
		BackgroundColor3 = t.panel2, Font = Enum.Font.GothamBold,
		TextSize = M.mobile and 18 or 26, Text = "—", Parent = top,
	})
	Corner(minBtn, M.mobile and 10 or 14)
	Stroke(minBtn, "line", 1)
	lib:Bind(minBtn, "BackgroundColor3", "panel2")
	lib:Bind(minBtn, "TextColor3", "text")
	local closeBtn = New("TextButton", {
		Position = UDim2.new(1, -(M.pad + btnW), 0, M.pad),
		Size = UDim2.fromOffset(btnW, btnH),
		BackgroundColor3 = t.danger, Font = Enum.Font.GothamBold,
		TextSize = M.mobile and 18 or 26, Text = "×", Parent = top,
	})
	Corner(closeBtn, M.mobile and 10 or 14)
	Stroke(closeBtn, "danger", 1)
	lib:Bind(closeBtn, "BackgroundColor3", "danger")
	lib:Bind(closeBtn, "TextColor3", "text")
	ctx.themeBtn = themeBtn
	ctx.minBtn = minBtn
	ctx.closeBtn = closeBtn
	ctx.topTitle = title
	ctx.topSub = subtitle
	ctx.markText = markText
	return top
end

local function buildNav(lib, ctx)
	local M = ctx.M
	local t = lib:Theme()
	local nav = New("Frame", {
		Position = UDim2.fromOffset(0, M.top),
		Size = UDim2.new(0, M.navW, 1, -(M.top + M.bottom)),
		BackgroundTransparency = 1, Parent = ctx.shell,
	})
	ctx.nav = nav
	local pad = M.mobile and 10 or 16
	local sc = New("ScrollingFrame", {
		Position = UDim2.fromOffset(pad, pad),
		Size = UDim2.new(1, -pad * 2, 1, -pad * 2),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = t.line,
		Parent = nav,
	})
	lib:Bind(sc, "ScrollBarImageColor3", "line")
	VList(sc, M.itemGap)
	ctx.navScroll = sc
	return nav
end

-- 菜单项：圆角块 + 右缘菱形箭头尖（样本 arrow_button 的 Roblox 近似）
local function buildMenuItem(lib, ctx, tabObj, order)
	local M = ctx.M
	local t = lib:Theme()
	local item = New("TextButton", {
		Size = UDim2.new(1, -14, 0, M.itemH),
		BackgroundColor3 = t.panel2, Text = "", AutoButtonColor = true,
		LayoutOrder = order, Parent = ctx.navScroll,
	})
	Corner(item, M.mobile and 8 or 10)
	local st = Stroke(item, "line", 1)
	lib:Bind(item, "BackgroundColor3", "panel2")
	lib:Bind(st, "Color", "line")
	-- 菱形箭头尖（右缘中点，旋转 45° 方块，一半露在外面）
	local tip = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(math.floor(M.itemH * 0.42), math.floor(M.itemH * 0.42)),
		Rotation = 45, BackgroundColor3 = t.panel2, Parent = item,
	})
	local tipSt = Stroke(tip, "line", 1)
	lib:Bind(tip, "BackgroundColor3", "panel2")
	local lbl = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Font = Enum.Font.GothamMedium, TextSize = M.menu,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = tostring(tabObj.title), Parent = item,
	})
	lib:Bind(lbl, "TextColor3", "text")
	tabObj._menuBtn = item
	tabObj._menuTip = tip
	tabObj._menuTipSt = tipSt
	tabObj._menuStroke = st
	tabObj._menuLbl = lbl
	return item
end

local function applyMenuStyle(lib, tabObj, active)
	local t = lib:Theme()
	local btn = tabObj._menuBtn
	if not btn then return end
	btn.BackgroundColor3 = active and t.accent or t.panel2
	tabObj._menuStroke.Color = active and t.accent or t.line
	tabObj._menuTip.BackgroundColor3 = active and t.accent or t.panel2
	tabObj._menuTipSt.Color = active and t.accent2 or t.line
	tabObj._menuLbl.TextColor3 = active and t.bg or t.text
end

-- ===== 主内容区 =====
local function buildMain(lib, ctx)
	local M = ctx.M
	local t = lib:Theme()
	local main = New("Frame", {
		Position = UDim2.new(0, M.navW + M.gap, 0, M.top + M.gap),
		Size = UDim2.new(1, -(M.navW + M.gap * 2 + M.pad), 1, -(M.top + M.bottom + M.gap * 2)),
		BackgroundColor3 = t.panel2, Parent = ctx.shell,
	})
	ctx.main = main
	Corner(main, M.mobile and 12 or 20)
	Stroke(main, "line", 1)
	lib:Bind(main, "BackgroundColor3", "panel2")
	-- 顶部 accent 边线（样本 accent_edge）
	local edge = New("Frame", {
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 0, 3),
		BackgroundColor3 = t.accent, BorderSizePixel = 0, Parent = main,
	})
	lib:Bind(edge, "BackgroundColor3", "accent")
	-- 头部：标题 + 副标题 + 徽章
	local headerH = M.mobile and 56 or 92
	local title = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(M.mobile and 14 or 24, M.mobile and 8 or 14),
		Size = UDim2.new(1, -(M.mobile and 110 or 220), 0, M.mobile and 22 or 36),
		Font = Enum.Font.GothamBold, TextSize = M.title,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = main,
	})
	lib:Bind(title, "TextColor3", "text")
	local subtitle = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(M.mobile and 14 or 24, M.mobile and 32 or 54),
		Size = UDim2.new(1, -(M.mobile and 110 or 220), 0, 16),
		Font = Enum.Font.GothamBold, TextSize = M.subtitle,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = main,
	})
	lib:Bind(subtitle, "TextColor3", "accent2")
	local badgePill = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(M.mobile and 14 or 24), 0, M.mobile and 12 or 22),
		Size = UDim2.fromOffset(M.mobile and 64 or 110, M.mobile and 26 or 36),
		BackgroundColor3 = t.good, BackgroundTransparency = 0.82, Parent = main,
	})
	Corner(badgePill, 8)
	Stroke(badgePill, "good", 1, 0.15, lib)
	lib:Bind(badgePill, "BackgroundColor3", "good")
	local badgeLbl = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold, TextSize = M.mobile and 11 or 15,
		Text = "", Parent = badgePill,
	})
	lib:Bind(badgeLbl, "TextColor3", "good")
	ctx.headerTitle = title
	ctx.headerSub = subtitle
	ctx.headerBadge = badgeLbl
	ctx.headerBadgePill = badgePill
	-- 分隔线
	local hr = New("Frame", {
		Position = UDim2.fromOffset(M.mobile and 14 or 22, headerH),
		Size = UDim2.new(1, -(M.mobile and 28 or 44), 0, 2),
		BackgroundColor3 = t.line_soft, BorderSizePixel = 0, Parent = main,
	})
	lib:Bind(hr, "BackgroundColor3", "line_soft")
	-- 内容滚动区
	local bodyScroll = New("ScrollingFrame", {
		Position = UDim2.fromOffset(M.mobile and 10 or 16, headerH + 8),
		Size = UDim2.new(1, -(M.mobile and 20 or 32), 1, -(headerH + 14)),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 3, ScrollBarImageColor3 = t.accent,
		Parent = main,
	})
	lib:Bind(bodyScroll, "ScrollBarImageColor3", "accent")
	ctx.bodyScroll = bodyScroll
	return main
end

-- Tab 页容器（首次创建）
local function ensureTabFrame(lib, ctx, tabObj)
	if tabObj._frame then return tabObj._frame end
	local f = New("Frame", {
		Size = UDim2.new(1, -8, 0, 0), BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false, Parent = ctx.bodyScroll,
	})
	VList(f, ctx.M.mobile and 10 or 14)
	tabObj._frame = f
	return f
end

local function applyHeader(lib, ctx, tabObj)
	ctx.headerTitle.Text = tostring(tabObj.title)
	ctx.headerSub.Text = tostring(tabObj.subtitle or " ")
	local hasBadge = tabObj.badge and tabObj.badge ~= ""
	ctx.headerBadge.Text = hasBadge and tostring(tabObj.badge) or ""
	ctx.headerBadgePill.Visible = hasBadge
end

-- ===== 底栏：‹ › 分类分页 + 展开/收起把手 + 缩放角标 =====
local CAT_SLOTS = 5

local function refreshCats(lib, ctx)
	local M = ctx.M
	local tabs = ctx.win._tabOrder
	local totalPages = math.max(1, math.ceil(#tabs / CAT_SLOTS))
	if ctx.catPage >= totalPages then ctx.catPage = totalPages - 1 end
	if ctx.catPage < 0 then ctx.catPage = 0 end
	for i = 1, CAT_SLOTS do
		local btn = ctx.catBtns[i]
		local idx = ctx.catPage * CAT_SLOTS + i
		local tabObj = tabs[idx]
		btn.Visible = tabObj ~= nil
		if tabObj then
			btn.Text = tostring(tabObj.title)
			btn.BackgroundColor3 = (ctx.win._current == tabObj) and lib:Theme().accent or lib:Theme().panel2
			btn._stroke.Color = (ctx.win._current == tabObj) and lib:Theme().accent or lib:Theme().line
			btn._lbl.TextColor3 = (ctx.win._current == tabObj) and lib:Theme().bg or lib:Theme().text
			btn._lbl.Font = (ctx.win._current == tabObj) and Enum.Font.GothamBold or Enum.Font.GothamMedium
		end
	end
	ctx.prevBtn.TextTransparency = ctx.catPage > 0 and 0 or 0.55
	ctx.nextBtn.TextTransparency = ctx.catPage < totalPages - 1 and 0 or 0.55
end

local function buildBottom(lib, ctx, cfg)
	local M = ctx.M
	local t = lib:Theme()
	local bar = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, M.bottom), BackgroundTransparency = 1, Parent = ctx.shell,
	})
	ctx.bottom = bar
	local byH = M.bottom - (M.mobile and 8 or 12) * 2
	local arrowW = M.mobile and 44 or 64
	local prevBtn = New("TextButton", {
		Position = UDim2.fromOffset(M.mobile and 10 or 18, (M.bottom - byH) / 2),
		Size = UDim2.fromOffset(arrowW, byH),
		BackgroundColor3 = t.panel2, Font = Enum.Font.GothamBold,
		TextSize = M.mobile and 20 or 30, Text = "‹", Parent = bar,
	})
	Corner(prevBtn, 8)
	local prevSt = Stroke(prevBtn, "line", 1)
	lib:Bind(prevBtn, "BackgroundColor3", "panel2")
	lib:Bind(prevBtn, "TextColor3", "accent2")
	local nextBtn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(M.mobile and 10 or 18), 0, (M.bottom - byH) / 2),
		Size = UDim2.fromOffset(arrowW, byH),
		BackgroundColor3 = t.panel2, Font = Enum.Font.GothamBold,
		TextSize = M.mobile and 20 or 30, Text = "›", Parent = bar,
	})
	Corner(nextBtn, 8)
	local nextSt = Stroke(nextBtn, "line", 1)
	lib:Bind(nextBtn, "BackgroundColor3", "panel2")
	lib:Bind(nextBtn, "TextColor3", "accent2")
	local catBtns = {}
	local catsX1 = M.mobile and 10 + arrowW + 8 or 18 + arrowW + 12
	local catsX2 = M.mobile and -(10 + arrowW + 8) or -(18 + arrowW + 12)
	for i = 1, CAT_SLOTS do
		local w = UDim2.new(1 / CAT_SLOTS, (catsX2 - catsX1) / CAT_SLOTS - 6, 0, byH)
		local btn = New("TextButton", {
			Position = UDim2.new(0, catsX1 + (i - 1) * ((catsX2 - catsX1) / CAT_SLOTS) + 3, 0, (M.bottom - byH) / 2),
			Size = UDim2.new(1 / CAT_SLOTS, (catsX2 - catsX1) / CAT_SLOTS - 6, 0, byH),
			BackgroundColor3 = t.panel2, Font = Enum.Font.GothamMedium,
			TextSize = M.mobile and 12 or 15, Text = "", Parent = bar,
		})
		Corner(btn, 8)
		local st = Stroke(btn, "line", 1)
		lib:Bind(btn, "BackgroundColor3", "panel2")
		local lbl = New("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamMedium, TextSize = M.mobile and 12 or 15,
			Text = "", Parent = btn,
		})
		lib:Bind(lbl, "TextColor3", "text")
		btn._stroke = st
		btn._lbl = lbl
		btn.MouseButton1Click:Connect(function()
			local idx = ctx.catPage * CAT_SLOTS + i
			local tabObj = ctx.win._tabOrder[idx]
			if tabObj then ctx.win:SelectTab(tabObj) end
		end)
		catBtns[i] = btn
	end
	ctx.catBtns = catBtns
	ctx.prevBtn = prevBtn
	ctx.nextBtn = nextBtn
	prevBtn.MouseButton1Click:Connect(function()
		if ctx.catPage > 0 then
			ctx.catPage -= 1
			refreshCats(lib, ctx)
		end
	end)
	nextBtn.MouseButton1Click:Connect(function()
		local totalPages = math.max(1, math.ceil(#ctx.win._tabOrder / CAT_SLOTS))
		if ctx.catPage < totalPages - 1 then
			ctx.catPage += 1
			refreshCats(lib, ctx)
		end
	end)
	-- 展开 / 收起把手（居中，浮于底栏上沿）
	local handleW = M.mobile and 96 or 150
	local handle = New("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, M.navW / 2, 1, -M.bottom),
		Size = UDim2.fromOffset(handleW, M.mobile and 20 or 24),
		BackgroundColor3 = t.accent, Font = Enum.Font.GothamBold,
		TextSize = M.mobile and 10 or 12,
		Text = "⌃  展开 / 收起", ZIndex = 20, Parent = ctx.shell,
	})
	Corner(handle, 8)
	Stroke(handle, "accent2", 1)
	lib:Bind(handle, "BackgroundColor3", "accent")
	lib:Bind(handle, "TextColor3", "bg")
	ctx.handle = handle
	-- 缩放角标（三道斜线 + 拖拽热区）
	if not M.mobile then
		local rz = New("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -8),
			Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Parent = ctx.shell,
		})
		for i = 0, 2 do
			local ln = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -6 - i * 7, 1, -6 + i * 7),
				Size = UDim2.fromOffset(22 - i * 4, 3), Rotation = -45,
				BackgroundColor3 = t.accent, BackgroundTransparency = 0.15,
				BorderSizePixel = 0, Parent = rz,
			})
			lib:Bind(ln, "BackgroundColor3", "accent")
		end
		local grip = New("TextButton", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -2, 1, -2),
			Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, Text = "", Parent = ctx.shell,
		})
		grip.ZIndex = 30
		ctx.resizeGrip = grip
	end
	return bar
end

-- ===== 卡密门禁 UI（WindUI KeySystem 对齐：KeyValidator/Key + Note + SaveKey） =====
local function buildKeyGate(lib, mainGui, config, ksCfg, validateKey, onPass)
	local t = lib:Theme()
	local M = metrics(isMobile())
	local kgui = New("ScreenGui", {
		Name = "QiurongToolbox_KeyGate", ResetOnSpawn = false, IgnoreGuiInset = true,
		DisplayOrder = 1000, Parent = safeParent(),
	})
	New("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = t.bg, BackgroundTransparency = 0.15,
		Parent = kgui,
	})
	local card = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(M.mobile and 300 or 360, 252),
		BackgroundColor3 = t.panel2, Parent = kgui,
	})
	Corner(card, 16)
	Stroke(card, "accent", 1.5)
	lib:Bind(card, "BackgroundColor3", "panel2")
	local mark = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22),
		Size = UDim2.fromOffset(46, 46), BackgroundColor3 = t.accent, Parent = card,
	})
	Corner(mark, 12)
	Stroke(mark, "accent2", 1.5)
	lib:Bind(mark, "BackgroundColor3", "accent")
	local markText = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold, TextSize = 22, Text = "秋", Parent = mark,
	})
	lib:Bind(markText, "TextColor3", "bg")
	local title = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 76),
		Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.GothamBold, TextSize = 17,
		Text = tostring(config.Title or "秋容工具箱 · 卡密验证"), Parent = card,
	})
	lib:Bind(title, "TextColor3", "text")
	local note = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0, 100),
		Size = UDim2.new(1, -40, 0, 30), Font = Enum.Font.Gotham, TextSize = 12,
		TextWrapped = true, Text = tostring(ksCfg.Note or "请输入卡密后确认"), Parent = card,
	})
	lib:Bind(note, "TextColor3", "muted")
	local box = New("TextBox", {
		Position = UDim2.new(0, 30, 0, 140), Size = UDim2.new(1, -60, 0, 36),
		BackgroundColor3 = t.panel3, Text = "",
		PlaceholderText = "输入卡密...",
		Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	Pad(box, 10, 0, 10, 0)
	Corner(box, 8)
	Stroke(box, "line", 1)
	lib:Bind(box, "BackgroundColor3", "panel3")
	lib:Bind(box, "TextColor3", "text")
	lib:Bind(box, "PlaceholderColor3", "muted")
	local status = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 182),
		Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.Gotham, TextSize = 12,
		Text = "", Parent = card,
	})
	lib:Bind(status, "TextColor3", "danger")
	local goBtn = New("TextButton", {
		Position = UDim2.new(0.5, -60, 0, 204), Size = UDim2.fromOffset(120, 34),
		BackgroundColor3 = t.accent, Font = Enum.Font.GothamBold, TextSize = 14,
		Text = "确认", Parent = card,
	})
	Corner(goBtn, 8)
	lib:Bind(goBtn, "BackgroundColor3", "accent")
	lib:Bind(goBtn, "TextColor3", "bg")
	local function submit()
		local k = box.Text
		if k == "" then
			status.Text = "请输入卡密"
			return
		end
		if validateKey(k) then
			kgui:Destroy()
			if onPass then pcall(onPass, k) end
		else
			status.Text = "卡密无效，请重试"
		end
	end
	goBtn.MouseButton1Click:Connect(submit)
	box.FocusLost:Connect(function(enter)
		if enter then submit() end
	end)
end

-- ===== CreateWindow =====
-- 点定义以兼容三种调用：Lib:CreateWindow{cfg} / Lib.CreateWindow{cfg} / Lib:CreateWindow(cfg)
-- （若用冒号定义，Lib.CreateWindow{cfg} 会把 config 表当成 self → self:Theme() 必炸）
function Lib.CreateWindow(a, b)
	local self, config
	if a == Lib then self, config = Lib, b else self, config = Lib, a end
	config = config or {}
	local mobile = isMobile()
	local M = metrics(mobile)
	local t = self:Theme()

	-- 持久化目录与回灌准备（Folder=false 关闭持久化）
	if config.Folder ~= nil then
		if config.Folder == false then
			self._autoSaveEnabled = false
		else
			self.Folder = tostring(config.Folder)
		end
	end
	self._Pending = nil
	if self._autoSaveEnabled and fsAvailable() then
		local rok, json = pcall(readfile, tostring(self.Folder) .. "/config.json")
		if rok and type(json) == "string" then
			local snap = decodeSnapshot(json)
			if snap then
				self._Pending = snap.flags
				if snap._theme and THEMES[snap._theme] then self:SetTheme(snap._theme) end
				t = self:Theme()
			end
		end
	end

	local gui = New("ScreenGui", {
		Name = "QiurongToolbox_" .. HttpService:GenerateGUID(false):sub(1, 8),
		ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
		Parent = safeParent(),
	})
	local scale = New("UIScale", { Parent = gui })
	local shell = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(M.win.w, M.win.h),
		BackgroundColor3 = t.shell, Parent = gui,
	})
	Corner(shell, M.radius)
	local shellSt = Stroke(shell, "accent", 2, 0.08, self)
	self:Bind(shell, "BackgroundColor3", "shell")
	-- 背景渐变（bg -> bg2）
	local grad = New("UIGradient", { Rotation = 90, Parent = shell })
	self:Bind(grad, "UIGradient", "bg")
	local function refreshGradient()
		grad.Color = ColorSequence.new(self:Theme().bg, self:Theme().bg2)
	end
	refreshGradient()

	local ctx = {
		lib = self, M = M, mobile = mobile, gui = gui, shell = shell, scale = scale,
		gradient = grad, RefreshGradient = refreshGradient,
		catPage = 0, collapsed = false, _conns = {},
	}
	ctx.CloseList = function(c) closeListImpl(c) end

	local win = setmetatable({}, WinMT)
	ctx.win = win
	win._ctx = ctx
	win._tabOrder = {}
	win._current = nil
	win._gui = gui

	local dropdownLayer = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 55, Parent = shell,
	})
	ctx.dropdownLayer = dropdownLayer

	buildPattern(self, shell, t, M)
	buildTopBar(self, ctx, config)
	buildNav(self, ctx)
	buildMain(self, ctx)
	buildBottom(self, ctx, config)

	-- 初始缩放适配（小屏不越界）
	local cam = workspace.CurrentCamera
	local function fitScale()
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		if not ctx.userScale then
			scale.Scale = math.min(1, vp.X * 0.94 / M.win.w, vp.Y * 0.9 / M.win.h)
		end
	end
	fitScale()
	table.insert(ctx._conns, cam and cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale) or nil)

	-- 窗口拖动（顶栏空白区）
	local dragging = false
	local dragStart, posStart
	ctx.top.Active = true
	ctx.top.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			posStart = shell.Position
		end
	end)
	table.insert(ctx._conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			shell.Position = UDim2.new(posStart.X.Scale, posStart.X.Offset + d.X, posStart.Y.Scale, posStart.Y.Offset + d.Y)
		end
	end))
	table.insert(ctx._conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	-- 折叠 / 展开
	function win:ToggleCollapse()
		ctx.collapsed = not ctx.collapsed
		local collapsedH = M.top + M.bottom + M.pad
		ctx.nav.Visible = not ctx.collapsed
		ctx.main.Visible = not ctx.collapsed
		ctx.handle.Text = ctx.collapsed and "⌄  展开 / 收起" or "⌃  展开 / 收起"
		TweenService:Create(shell, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(M.win.w, ctx.collapsed and collapsedH or M.win.h),
		}):Play()
	end
	ctx.minBtn.MouseButton1Click:Connect(function() win:ToggleCollapse() end)
	ctx.handle.MouseButton1Click:Connect(function() win:ToggleCollapse() end)

	-- 显示 / 隐藏（WindUI 对齐：关闭可由悬浮球重开）
	function win:Show()
		ctx:CloseList()
		ctx.gui.Enabled = true
		if ctx.openBtn then ctx.openBtn.Visible = false end
	end
	function win:Hide()
		ctx:CloseList()
		ctx.gui.Enabled = false
		if ctx.openBtn then ctx.openBtn.Visible = true end
	end

	-- 关闭按钮：CloseAction = "hide"（默认，悬浮球可重开）| "destroy"
	ctx.closeBtn.MouseButton1Click:Connect(function()
		if (config.CloseAction or "hide") == "destroy" then
			if config.OnClose then pcall(config.OnClose) end
			win:Destroy()
		else
			win:Hide()
		end
	end)

	-- 顶栏主题按钮：循环切换全部主题（内置三套 + AddTheme 自定义）
	ctx.themeBtn.MouseButton1Click:Connect(function()
		local names = {}
		for k in pairs(THEMES) do table.insert(names, k) end
		table.sort(names)
		local idx = table.find(names, self.ThemeName) or 1
		local nextName = names[(idx % #names) + 1]
		self:SetTheme(nextName)
		win:Notify("主题已切换", tostring(THEMES[nextName].name) .. " · " .. nextName, "◐", 2)
		if not self._Loading then saveHook(self) end
	end)

	-- 悬浮打开按钮（WindUI OpenButton 对齐；关闭窗口后显示，点击重开，可拖动）
	local obCfg = config.OpenButton
	if obCfg ~= false and (type(obCfg) ~= "table" or obCfg.Enabled ~= false) then
		local onlyMobile = (type(obCfg) ~= "table") and true or (obCfg.OnlyMobile ~= false)
		if not (onlyMobile and not mobile) then
			local obGui = New("ScreenGui", {
				Name = "QiurongToolbox_OpenBtn", ResetOnSpawn = false,
				IgnoreGuiInset = true, DisplayOrder = 998, Parent = safeParent(),
			})
			local obBtn = New("TextButton", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.82, 0),
				Size = UDim2.fromOffset(type(obCfg) == "table" and obCfg.Width or 128, 44),
				BackgroundColor3 = t.accent,
				Font = Enum.Font.GothamBold, TextSize = 15,
				Text = tostring((type(obCfg) == "table" and obCfg.Title) or "打开 工具箱"),
				TextColor3 = t.bg, Visible = false, Parent = obGui,
			})
			Corner(obBtn, 22)
			Stroke(obBtn, "accent2", 2)
			self:Bind(obBtn, "BackgroundColor3", "accent")
			self:Bind(obBtn, "TextColor3", "bg")
			local obDrag, obMoved = false, false
			local obStart, obPos
			obBtn.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					obDrag = true
					obMoved = false
					obStart = input.Position
					obPos = obBtn.Position
				end
			end)
			table.insert(ctx._conns, UserInputService.InputChanged:Connect(function(input)
				if obDrag and obBtn.Visible and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					local d = input.Position - obStart
					if math.abs(d.X) + math.abs(d.Y) > 6 then obMoved = true end
					obBtn.Position = UDim2.new(obPos.X.Scale, obPos.X.Offset + d.X, obPos.Y.Scale, obPos.Y.Offset + d.Y)
				end
			end))
			table.insert(ctx._conns, UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					if obDrag and not obMoved and obBtn.Visible then
						win:Show()
					end
					obDrag = false
				end
			end))
			ctx.openBtn = obBtn
			ctx.openGui = obGui
		end
	end

	-- 主题刷新回调（状态色：菜单项选中态、分类按钮选中态）
	function win:RefreshTheme()
		for _, tb in ipairs(win._tabOrder) do
			applyMenuStyle(self, tb, win._current == tb)
		end
		refreshCats(self, ctx)
	end

	-- 缩放拖拽
	if ctx.resizeGrip then
		local rz = false
		local rzStart, scStart
		ctx.resizeGrip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				rz = true
				rzStart = input.Position.Y
				scStart = scale.Scale
			end
		end)
		table.insert(ctx._conns, UserInputService.InputChanged:Connect(function(input)
			if rz and input.UserInputType == Enum.UserInputType.MouseMovement then
				ctx.userScale = true
				scale.Scale = math.clamp(scStart * (1 + (input.Position.Y - rzStart) * 0.002), 0.55, 1.4)
			end
		end))
		table.insert(ctx._conns, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then rz = false end
		end))
	end

	-- 跑马灯滚动（隐藏时暂停）
	local baseX = (M.mobile and 64 or 104) + (M.mobile and 22 or 32)
	local marqueeOff = 0
	table.insert(ctx._conns, RunService.Heartbeat:Connect(function(dt)
		local m = ctx.marquee
		if m and m.Parent and ctx.gui.Enabled then
			local textW = m.TextBounds.X
			local visW = math.max(m.AbsoluteSize.X, 1)
			marqueeOff += dt * 55
			if marqueeOff > textW + visW + 80 then marqueeOff = 0 end
			m.Position = UDim2.new(0, baseX - marqueeOff, 0.5, 0)
		end
	end))

	-- 呼出键
	if config.ToggleKey then
		ctx._toggleConn = UserInputService.InputBegan:Connect(function(input, gpe)
			if not gpe and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == config.ToggleKey then
				win:ToggleVisibility()
			end
		end)
	end

	-- toast 容器
	local toastLayer = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(M.mobile and 220 or 300, 800),
		BackgroundTransparency = 1, ZIndex = 70, Parent = shell,
	})
	VList(toastLayer, 8)
	ctx.toastLayer = toastLayer

	table.insert(self._Windows, win)
	rawset(_G, self._GName, self)

	-- ===== 卡密门禁（WindUI KeySystem 对齐） =====
	local ksCfg = config.KeySystem
	if ksCfg and (ksCfg.KeyValidator or ksCfg.Key) then
		local function validateKey(k)
			if ksCfg.KeyValidator then
				local okv, res = pcall(ksCfg.KeyValidator, tostring(k))
				return okv and res == true
			end
			if type(ksCfg.Key) == "table" then
				return table.find(ksCfg.Key, tostring(k)) ~= nil
			end
			return tostring(k) == tostring(ksCfg.Key)
		end
		local passed = false
		if ksCfg.SaveKey and fsAvailable() then
			local rok, sk = pcall(readfile, tostring(self.Folder) .. "/key.txt")
			if rok and type(sk) == "string" and validateKey(sk) then passed = true end
		end
		if not passed then
			gui.Enabled = false
			buildKeyGate(self, gui, config, ksCfg, validateKey, function(key)
				gui.Enabled = true
				if ksCfg.SaveKey and fsAvailable() then
					pcall(function()
						if isfolder and not isfolder(self.Folder) then makefolder(self.Folder) end
					end)
					pcall(writefile, tostring(self.Folder) .. "/key.txt", tostring(key))
				end
			end)
		end
	end

	-- 开屏公告：作者配置了 Notice/Announce 才弹出（未配置默认不弹）
	if config.Notice or config.Announce then
		task.delay(0.2, function()
			if not ctx._destroyed and gui.Enabled then
				pcall(function() win:Notice(config.Notice or config.Announce) end)
			end
		end)
	end

	return win
end

-- ===== WinMT / TabMT 链式方法 =====
-- ⚠ 表已在文件头前置声明区创建（CreateWindow 内 setmetatable 引用的是那个表）。
-- 这里绝不能再 local 重复声明——那会生成新表，方法全挂到新表上，实例上的方法查找全部失败。
WinMT.__index = WinMT
TabMT.__index = TabMT

function TabMT:Section(a, b)
	local tabObj = self._tab
	local ctx = self._ctx
	if type(a) == "table" then
		b = a.Subtitle or a.subtitle
		a = a.Title or a.title
	end
	local sec = newSection(ctx.lib, ctx, tabObj, a or "分组")
	local tabFrame = ensureTabFrame(ctx.lib, ctx, tabObj)
	local holder = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y, Parent = tabFrame,
	})
	sec.holder = holder
	sec._order = 0
	local st = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamBold, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(tostring(sec.title)), Parent = holder,
	})
	ctx.lib:Bind(st, "TextColor3", "muted")
	local body = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(0, 22), Parent = holder,
	})
	VList(body, 8)
	sec.holder = body
	setmetatable(sec, SectionMethods)
	tabObj._sections += 1
	return sec
end

local function tabLazy(self)
	if not self._auto then self._auto = TabMT.Section(self, "控件") end
	return self._auto
end
for _, kind in ipairs({ "Button", "Toggle", "Slider", "Dropdown", "Multi", "Input",
	"Keybind", "Label", "Divider", "Paragraph", "Stat", "Card", "ColorPicker" }) do
	TabMT[kind] = function(s, o) local sec = tabLazy(s) return sec[kind](sec, o) end
end

function WinMT:Tab(o)
	o = o or {}
	local ctx = self._ctx
	local lib = ctx.lib
	self._Seq = (self._Seq or 0) + 1
	local tabObj = {
		id = tostring(o.Id or o.id or o.Title or o.title or ("tab" .. self._Seq)),
		title = tostring(o.Title or o.title or o.Id or o.id or ("菜单 " .. string.format("%02d", self._Seq))),
		subtitle = o.Subtitle or o.subtitle,
		badge = o.Badge or o.badge,
		_sections = 0,
		order = #self._tabOrder + 1,
	}
	setmetatable(tabObj, TabMT)
	tabObj._ctx = ctx
	tabObj._tab = tabObj
	table.insert(self._tabOrder, tabObj)
	buildMenuItem(lib, ctx, tabObj, tabObj.order)
	ensureTabFrame(lib, ctx, tabObj)
	-- UIListLayout 会给不可见元素占位：非当前 Tab 的页帧先摘下来，选中再挂回
	if self._current and self._current ~= tabObj then
		tabObj._frame.Parent = nil
	end
	tabObj._menuBtn.MouseButton1Click:Connect(function()
		self:SelectTab(tabObj)
	end)
	if not self._current then
		self:SelectTab(tabObj)
	end
	refreshCats(lib, ctx)
	return tabObj
end

function WinMT:SelectTab(idOrObj)
	local ctx = self._ctx
	local lib = ctx.lib
	local target
	if type(idOrObj) == "table" then
		target = idOrObj
	else
		for _, tb in ipairs(self._tabOrder) do
			if tb.id == tostring(idOrObj) then target = tb break end
		end
	end
	if not target or self._current == target then return end
	local old = self._current
	if old then
		if old._frame then old._frame.Parent = nil end
		applyMenuStyle(lib, old, false)
	end
	self._current = target
	if target._frame then target._frame.Parent = ctx.bodyScroll end
	applyMenuStyle(lib, target, true)
	applyHeader(lib, ctx, target)
	refreshCats(lib, ctx)
end

function WinMT:ToggleCollapse() end -- 实例方法在 CreateWindow 中覆盖

function WinMT:ToggleVisibility()
	local ctx = self._ctx
	if ctx.gui.Enabled then
		self:Hide()
	else
		self:Show()
	end
end

function WinMT:Notify(a, b, ttl)
	local ctx = self._ctx
	local lib = ctx.lib
	local t = lib:Theme()
	local title, content, icon, dur = "通知", "", nil, 3.5
	if type(a) == "table" then
		title = tostring(a.Title or a.title or "通知")
		content = tostring(a.Content or a.content or "")
		icon = a.Icon or a.icon
		dur = tonumber(a.Duration or a.duration) or 3.5
	else
		title = tostring(a or "通知")
		content = type(b) == "string" and b or ""
		dur = tonumber(ttl) or 3.5
	end
	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = t.panel2, Parent = ctx.toastLayer,
	})
	Corner(card, 10)
	Stroke(card, "accent", 1, 0.3, lib)
	lib:Bind(card, "BackgroundColor3", "panel2")
	local textX = 18
	if icon and icon ~= "" then
		textX = 58
		local ib = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(38, 38), BackgroundColor3 = t.accent, Parent = card,
		})
		Corner(ib, 10)
		lib:Bind(ib, "BackgroundColor3", "accent")
		local it = New("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold, TextSize = 18, Text = tostring(icon), Parent = ib,
		})
		lib:Bind(it, "TextColor3", "bg")
	else
		local bar = New("Frame", {
			Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(8, 8),
			BackgroundColor3 = t.accent, BorderSizePixel = 0, Parent = card,
		})
		lib:Bind(bar, "BackgroundColor3", "accent")
		Corner(bar, 2)
	end
	local tl = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(textX, 8),
		Size = UDim2.new(1, -(textX + 8), 0, 16), Font = Enum.Font.GothamBold, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, Text = title, Parent = card,
	})
	lib:Bind(tl, "TextColor3", "text")
	local cl = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(textX, 26),
		Size = UDim2.new(1, -(textX + 8), 0, 24), Font = Enum.Font.Gotham, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		Text = content, Parent = card,
	})
	lib:Bind(cl, "TextColor3", "muted")
	task.delay(dur, function()
		if not card.Parent then return end
		TweenService:Create(card, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(tl, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(cl, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.delay(0.35, function() card:Destroy() end)
	end)
end

function WinMT:Dialog(o)
	o = o or {}
	local ctx = self._ctx
	local lib = ctx.lib
	local t = lib:Theme()
	local M = ctx.M
	local mask = New("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = t.bg,
		BackgroundTransparency = 0.4, Text = "", ZIndex = 80, Parent = ctx.shell,
	})
	-- 按钮集（WindUI Popup 对齐）：默认 确认/取消
	local buttons = o.Buttons or o.buttons
	if type(buttons) ~= "table" or #buttons == 0 then
		buttons = {
			{ Title = "取消", Variant = "Tertiary" },
			{ Title = "确认", Variant = "Primary", Callback = o.Callback or o.callback or o.onConfirm },
		}
	end
	local bH = M.mobile and 32 or 34
	local bGap = 8
	local widths, total = {}, 0
	for i, bd in ipairs(buttons) do
		local w = math.clamp(18 + #tostring(bd.Title or "按钮") * 15, 64, 120)
		widths[i] = w
		total += w
	end
	total += bGap * (#buttons - 1)
	local cardW = math.max(M.mobile and 260 or 380, total + 36)
	local card = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(cardW, M.mobile and 130 or 160),
		BackgroundColor3 = t.panel2, ZIndex = 82, Parent = ctx.shell,
	})
	Corner(card, 14)
	Stroke(card, "accent", 1.5)
	lib:Bind(card, "BackgroundColor3", "panel2")
	local tl = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 14),
		Size = UDim2.new(1, -36, 0, 22), Font = Enum.Font.GothamBold, TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(o.Title or o.title or "确认"), Parent = card,
	})
	lib:Bind(tl, "TextColor3", "text")
	local cl = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 40),
		Size = UDim2.new(1, -36, 0, 44), Font = Enum.Font.Gotham, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		Text = tostring(o.Content or o.content or "确认执行？"), Parent = card,
	})
	lib:Bind(cl, "TextColor3", "muted")
	local function close()
		mask:Destroy()
		card:Destroy()
	end
	local cursor = 18
	for i = #buttons, 1, -1 do
		local bd = buttons[i]
		local w = widths[i]
		local variant = string.lower(tostring(bd.Variant or "Secondary"))
		local b = New("TextButton", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -cursor, 1, -14),
			Size = UDim2.fromOffset(w, bH),
			Font = (variant == "primary") and Enum.Font.GothamBold or Enum.Font.GothamMedium,
			TextSize = 14, Text = tostring(bd.Title or "按钮"), ZIndex = 83, Parent = card,
		})
		Corner(b, 8)
		if variant == "primary" then
			b.BackgroundColor3 = t.accent
			b.TextColor3 = t.bg
			lib:Bind(b, "BackgroundColor3", "accent")
			lib:Bind(b, "TextColor3", "bg")
		elseif variant == "danger" then
			b.BackgroundColor3 = t.danger
			b.TextColor3 = t.bg
			lib:Bind(b, "BackgroundColor3", "danger")
			lib:Bind(b, "TextColor3", "bg")
		elseif variant == "tertiary" then
			b.BackgroundTransparency = 1
			b.TextColor3 = t.text
			Stroke(b, "line", 1)
			lib:Bind(b, "TextColor3", "text")
		else
			b.BackgroundColor3 = t.panel3
			b.TextColor3 = t.text
			Stroke(b, "line", 1)
			lib:Bind(b, "BackgroundColor3", "panel3")
			lib:Bind(b, "TextColor3", "text")
		end
		b.MouseButton1Click:Connect(function()
			close()
			if bd.Callback then
				local ok, err = pcall(bd.Callback)
				if not ok then warn("[QiurongToolbox] Dialog 按钮回调出错: " .. tostring(err)) end
			end
		end)
		cursor += w + bGap
	end
	mask.MouseButton1Click:Connect(close)
end

-- 开屏公告（作者配置了 Notice 才弹出；Notice=字符串 或 { Title, Badge, Lines } ）
function WinMT:Notice(o)
	if type(o) == "string" then o = { Content = o } end
	o = o or {}
	local ctx = self._ctx
	local lib = ctx.lib
	local t = lib:Theme()
	local M = ctx.M
	local lines
	if type(o.Lines) == "table" then
		lines = o.Lines
	elseif type(o.Content) == "table" then
		lines = o.Content
	else
		lines = { tostring(o.Content or o.content or "") }
	end
	local lineH = M.mobile and 19 or 23
	local cardH = (M.mobile and 168 or 200) + #lines * lineH
	local mask = New("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = t.bg,
		BackgroundTransparency = 0.35, Text = "", ZIndex = 85, Parent = ctx.shell,
	})
	local card = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(M.mobile and 300 or 420, math.min(cardH, 460)),
		BackgroundColor3 = t.panel2, ZIndex = 86, Parent = ctx.shell,
	})
	Corner(card, 16)
	Stroke(card, "accent", 1.5)
	lib:Bind(card, "BackgroundColor3", "panel2")
	local sp = M.mobile and 14 or 20
	local y = sp
	if o.Badge or o.badge then
		local badge = New("Frame", {
			Position = UDim2.fromOffset(sp, y), Size = UDim2.fromOffset(M.mobile and 96 or 120, 28),
			BackgroundColor3 = t.accent, BackgroundTransparency = 0.68, Parent = card,
		})
		Corner(badge, 9)
		Stroke(badge, "accent", 1)
		lib:Bind(badge, "BackgroundColor3", "accent")
		local bt = New("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold, TextSize = 12,
			Text = tostring(o.Badge or o.badge), Parent = badge,
		})
		lib:Bind(bt, "TextColor3", "accent2")
		y += 36
	end
	local big = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(sp, y),
		Size = UDim2.new(1, -sp * 2, 0, M.mobile and 24 or 32),
		Font = Enum.Font.GothamBold, TextSize = M.big - 8,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(o.Title or o.title or "公告"), Parent = card,
	})
	lib:Bind(big, "TextColor3", "text")
	y += (M.mobile and 24 or 32) + 8
	for _, line in ipairs(lines) do
		local dl = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(sp, y),
			Size = UDim2.new(1, -sp * 2, 0, lineH),
			Font = Enum.Font.Gotham, TextSize = M.mobile and 13 or 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tostring(line), Parent = card,
		})
		lib:Bind(dl, "TextColor3", "muted")
		y += lineH
	end
	local okBtn = New("TextButton", {
		Position = UDim2.new(0.5, -50, 1, -44), Size = UDim2.fromOffset(100, 32),
		BackgroundColor3 = t.accent, Font = Enum.Font.GothamBold, TextSize = 14,
		Text = "我知道了", ZIndex = 87, Parent = card,
	})
	Corner(okBtn, 8)
	lib:Bind(okBtn, "BackgroundColor3", "accent")
	lib:Bind(okBtn, "TextColor3", "bg")
	local function close()
		mask:Destroy()
		card:Destroy()
	end
	mask.MouseButton1Click:Connect(close)
	okBtn.MouseButton1Click:Connect(close)
end

-- ===== 窗口运行时方法（WindUI 对齐） =====
function WinMT:SetTitle(v)
	local ctx = self._ctx
	if ctx.topTitle then ctx.topTitle.Text = tostring(v) end
end

function WinMT:SetAuthor(v)
	local ctx = self._ctx
	if ctx.topSub then ctx.topSub.Text = string.upper(tostring(v or "")) end
end

function WinMT:SetIcon(v)
	local ctx = self._ctx
	if ctx.markText then ctx.markText.Text = tostring(v or "秋") end
end

function WinMT:SetSize(w, h)
	local ctx = self._ctx
	local M = ctx.M
	local nw = math.clamp(tonumber(w) or M.win.w, 420, 1600)
	local nh = math.clamp(tonumber(h) or M.win.h, 320, 1000)
	M.win.w = nw
	M.win.h = nh
	TweenService:Create(ctx.shell, TweenInfo.new(0.2), { Size = UDim2.fromOffset(nw, nh) }):Play()
end

function WinMT:GetWindowSize()
	local ctx = self._ctx
	return UDim2.fromOffset(ctx.M.win.w, ctx.M.win.h)
end

function WinMT:SetToggleKey(key)
	local ctx = self._ctx
	if ctx._toggleConn then
		pcall(function() ctx._toggleConn:Disconnect() end)
		ctx._toggleConn = nil
	end
	if key then
		ctx._toggleConn = UserInputService.InputBegan:Connect(function(input, gpe)
			if not gpe and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == key then
				ctx.win:ToggleVisibility()
			end
		end)
	end
end

function WinMT:SetUIScale(n)
	local ctx = self._ctx
	ctx.userScale = true
	ctx.scale.Scale = math.clamp(tonumber(n) or 1, 0.55, 1.4)
end

function WinMT:GetUIScale()
	local ctx = self._ctx
	return ctx.scale.Scale
end

function WinMT:IsResizable()
	local ctx = self._ctx
	return ctx.resizeGrip ~= nil
end

function WinMT:SetBackgroundTransparency(v)
	local ctx = self._ctx
	v = math.clamp(tonumber(v) or 0, 0, 0.9)
	ctx.shell.BackgroundTransparency = v
	if ctx.gradient then ctx.gradient.Enabled = v < 0.99 end
end

function WinMT:Destroy()
	local ctx = self._ctx
	if ctx._destroyed then return end
	ctx._destroyed = true
	ctx:CloseList()
	for _, c in ipairs(ctx._conns) do
		pcall(function() c:Disconnect() end)
	end
	if ctx._toggleConn then pcall(function() ctx._toggleConn:Disconnect() end) end
	if ctx.openGui then pcall(function() ctx.openGui:Destroy() end) end
	if ctx.gui then ctx.gui:Destroy() end
	local arr = Lib._Windows
	for i = #arr, 1, -1 do
		if arr[i] == self then table.remove(arr, i) end
	end
end

function WinMT:SetTheme(name)
	return Lib:SetTheme(name)
end

Lib.WinMT = WinMT
Lib.TabMT = TabMT
Lib.SectionMethods = SectionMethods
Lib.THEMES = THEMES

rawset(_G, Lib._GName, Lib)

return Lib
