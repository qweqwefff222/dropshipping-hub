--[[
	QiurongToolbox v1.0.0  ·  秋容工具箱
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
			OnClose     = function() end,
		}

		local Tab = Window:Tab{ Title = "菜单 01", Subtitle = "RELEASE NOTES · 版本 v2.3.0", Badge = "正式版本" }
		local Sec = Tab:Section("功能更新公告")

		Sec:Paragraph{ Title = "2.3.0", Badge = "本次更新", Desc = { "启动、加载与窗口适配升级", "让高频操作更稳定、更顺畅。" } }
		Sec:Stat{ Number = "3", Label = "新增功能" }
		Sec:Card{ Key = "新", Title = "新增", Color = "good", Bullets = { "新增快捷启动面板", "新增配置恢复入口" } }
		Sec:Toggle{ Title = "自动开始", Default = false, Flag = "AutoStart", Callback = function(v) end }
		Sec:Slider{ Title = "延迟", Min = 0, Max = 10, Step = 0.1, Default = 1, Callback = function(v) end }
		Sec:Dropdown{ Title = "目标", Options = { "A", "B" }, Default = "A", Callback = function(v) end }
		Sec:Button{ Title = "执行", Callback = function() end }
		Sec:Input{ Title = "备注", Placeholder = "输入..." }

		Window:SelectTab(tabId)  Window:Notify("标题", "内容")  Window:Dialog{ ... }
		Lib.Flags["AutoStart"]:Get() / :Set(v)   Lib:SetTheme("premium-dark")

	18 种样本规格均落实：三主题 token、箭头菜单、跑马灯、统计格、分类卡、
	分类分页栏、展开/收起把手、缩放角标；桌面/手机横屏双布局（正文≥14 菜单≥15 标题≥20，热区≥44）。
]]

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

local Lib = {
	Version = "1.0.0",
	ThemeName = "tech-glass",
	Flags = {},
	_Windows = {},
	_Binds = {},   -- { {inst, prop, token, aux} } 主题换色绑定
	Seq = 0,
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
	BorderColor3 = true, PlaceholderColor3 = true,
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

function Lib:SetTheme(name)
	if not THEMES[name] then return false end
	self.ThemeName = name
	local t = THEMES[name]
	for _, b in ipairs(self._Binds) do
		if b.inst.Parent then
			pcall(function()
				if b.prop == "UIGradient" then
					b.inst.Color = ColorSequence.new(t[b.token], t[b.token])
				else
					b.inst[b.prop] = t[b.token]
				end
			end)
		end
	end
	for _, win in ipairs(self._Windows) do
		if win.RefreshTheme then pcall(win.RefreshTheme, win) end
	end
	return true
end

function Lib:GetThemes()
	local list = {}
	for k, v in pairs(THEMES) do table.insert(list, { Id = k, Name = v.name }) end
	return list
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
	if lib then lib:Bind(s, "Color", token or "line") else s.Color = C("#2B6076") end
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

local function makeHandle(lib, o, kind, get, set)
	local h = { Type = kind, Key = o and o.Flag or nil }
	function h.Get()
		return get()
	end
	function h:Set(v)
		set(v)
	end
	if o and o.Flag then lib.Flags[tostring(o.Flag)] = h end
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
	Stroke(card, "line", 1)
	lib:Bind(card, "BackgroundColor3", "panel")
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
	else
		local title = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -110, 1, 0),
			Font = Enum.Font.GothamMedium, TextSize = ctx.M.body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = tostring(o.Title or o.title or ""), Parent = card,
		})
		lib:Bind(title, "TextColor3", "text")
	end
	local right = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(84, h - 12), Parent = card,
	})
	return card, right
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
	Stroke(card, "line", 1)
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
	card.MouseButton1Click:Connect(function()
		if o.Callback then
			local ok, err = pcall(o.Callback)
			if not ok then warn("[QiurongToolbox] Button 回调出错: " .. tostring(err)) end
		end
	end)
	return card
end

local function ctlToggle(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card, right = rowCard(sec, o, ctx.M.ctlH)
	local key = "toggle." .. tostring(o.Flag or (function() lib.Seq += 1 return "auto" .. lib.Seq end)())
	local val = (o.Default == true)
	Values[key] = val
	local track = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(42, 24), BackgroundColor3 = val and t.accent or t.panel3,
		Parent = right,
	})
	lib:Bind(track, "BackgroundColor3", val and "accent" or "panel3")
	Corner(track, 12)
	Stroke(track, "line", 1)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(val and 1 or 0, val and -3 or 3, 0.5, 0),
		Size = UDim2.fromOffset(18, 18), BackgroundColor3 = t.text, Parent = track,
	})
	lib:Bind(knob, "BackgroundColor3", "text")
	Corner(knob, 9)
	local btn = New("TextButton", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", Parent = track,
	})
	local function apply(v, fire)
		Values[key] = v
		lib:Bind(track, "BackgroundColor3", v and "accent" or "panel3")
		TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(v and 1 or 0, v and -3 or 3, 0.5, 0),
		}):Play()
		if fire and o.Callback then
			local ok, err = pcall(o.Callback, v)
			if not ok then warn("[QiurongToolbox] Toggle 回调出错: " .. tostring(err)) end
		end
	end
	btn.MouseButton1Click:Connect(function() apply(not Values[key], true) end)
	makeHandle(lib, o, "toggle",
		function() return Values[key] end,
		function(v) apply(v == true, true) end)
	return card
end

local function ctlSlider(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card, right = rowCard(sec, o, ctx.M.ctlH)
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
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setVal(mn + (mx - mn) * math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1), true)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setVal(mn + (mx - mn) * math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1), true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	makeHandle(lib, o, "slider",
		function() return Values[key] end,
		function(v) setVal(v, true) end)
	return card
end

-- 选项浮层（dropdown / multi 共用；挂 shell 顶层避免被裁剪）
local function openList(ctx, anchorInst, options, current, multi, onPick, onClose)
	local lib = ctx.lib
	local shell = ctx.shell
	local t = lib:Theme()
	ctx:CloseList()
	local rowH = ctx.M.mobile and 36 or 34
	local maxShow = 6
	local listH = math.min(#options, maxShow) * rowH + 12
	local ap = anchorInst.AbsolutePosition - shell.AbsolutePosition
	local box = New("Frame", {
		Position = UDim2.fromOffset(math.floor(ap.X), math.floor(ap.Y + anchorInst.AbsoluteSize.Y + 4)),
		Size = UDim2.fromOffset(anchorInst.AbsoluteSize.X, listH),
		BackgroundColor3 = t.panel2, ZIndex = 60, Parent = ctx.dropdownLayer,
	})
	Corner(box, 10)
	local st = Stroke(box, "accent", 1)
	lib:Bind(st, "Color", "accent")
	lib:Bind(box, "BackgroundColor3", "panel2")
	local sc = New("ScrollingFrame", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, #options * rowH),
		ScrollBarThickness = 3, BorderSizePixel = 0,
		ScrollBarImageColor3 = t.accent, Parent = box,
	})
	lib:Bind(sc, "ScrollBarImageColor3", "accent")
	VList(sc, 2)
	local sel = {}
	if multi and type(current) == "table" then
		for v in pairs(current) do sel[v] = true end
	end
	for i, opt in ipairs(options) do
		local optText = tostring(opt)
		local optBtn = New("TextButton", {
			Size = UDim2.new(1, -8, 0, rowH), Text = "",
			BackgroundColor3 = t.accent, BackgroundTransparency = 1,
			LayoutOrder = i, Parent = sc,
		})
		Corner(optBtn, 6)
		local isOn = multi and sel[optText] or (optText == tostring(current))
		local lbl = New("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(10, 0),
			Font = Enum.Font.GothamMedium, TextSize = ctx.M.body,
			TextXAlignment = Enum.TextXAlignment.Left, Text = optText, Parent = optBtn,
		})
		lib:Bind(lbl, "TextColor3", isOn and "accent" or "text")
		if multi then
			local mark = New("TextLabel", {
				BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(16, 16),
				Font = Enum.Font.GothamBold, TextSize = 14,
				Text = sel[optText] and "✓" or "", Parent = optBtn,
			})
			lib:Bind(mark, "TextColor3", "accent")
		end
		optBtn.MouseButton1Click:Connect(function()
			if multi then
				sel[optText] = not sel[optText] or nil
				lbl.TextColor3 = sel[optText] and lib:Theme().accent or lib:Theme().text
				lbl.TextColor3 = lib:Theme()[sel[optText] and "accent" or "text"]
				lbl.Parent:FindFirstChildOfClass("TextLabel")
			end
			onPick(optText, sel[optText] == true)
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
		if ctx.activeList.box then ctx.activeList.box:Destroy() end
		if ctx.activeList.onClose then pcall(ctx.activeList.onClose) end
		ctx.activeList = nil
	end
end

local function ctlDropdown(sec, o, multi)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card, right = rowCard(sec, o, ctx.M.ctlH)
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
	btn.MouseButton1Click:Connect(function()
		if ctx.activeList and ctx.activeList.anchor == btn then
			ctx:CloseList()
			return
		end
		if multi then
			openList(ctx, btn, options, Values[key], true, function(optText, on)
				if on then Values[key][optText] = true else Values[key][optText] = nil end
				refreshLabel()
				if o.Callback then
					local picked = {}
					for v in pairs(Values[key]) do table.insert(picked, v) end
					local ok, err = pcall(o.Callback, picked)
					if not ok then warn("[QiurongToolbox] Multi 回调出错: " .. tostring(err)) end
				end
			end)
		else
			openList(ctx, btn, options, Values[key], false, function(optText)
				Values[key] = optText
				refreshLabel()
				ctx:CloseList()
				if o.Callback then
					local ok, err = pcall(o.Callback, optText)
					if not ok then warn("[QiurongToolbox] Dropdown 回调出错: " .. tostring(err)) end
				end
			end)
		end
		if ctx.activeList then ctx.activeList.anchor = btn end
	end)
	local h = makeHandle(lib, o, multi and "multi" or "dropdown",
		function() return Values[key] end,
		function(v)
			if multi then
				Values[key] = {}
				if type(v) == "table" then
					for _, item in ipairs(v) do Values[key][tostring(item)] = true end
				end
			else
				Values[key] = tostring(v)
			end
			refreshLabel()
		end)
	if multi then
		function h.SetOptions(list)
			options = {}
			for _, v in ipairs(type(list) == "table" and list or {}) do
				table.insert(options, tostring(v))
			end
		end
	end
	return card
end

local function ctlMulti(sec, o)
	return ctlDropdown(sec, o, true)
end

local function ctlInput(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card, right = rowCard(sec, o, ctx.M.ctlH)
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
	end)
	makeHandle(lib, o, "input",
		function() return Values[key] end,
		function(v) box.Text = tostring(v) Values[key] = box.Text end)
	return card
end

local function ctlKeybind(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
	local card, right = rowCard(sec, o, ctx.M.ctlH)
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
				if input.KeyCode == Enum.KeyCode.Escape then
					conn:Disconnect()
					listening = false
					btn.Text = current and current.Name or "未绑定"
				else
					current = input.KeyCode
					btn.Text = current.Name
					conn:Disconnect()
					listening = false
					if o.Callback then pcall(o.Callback, current) end
				end
			end
		end)
	end)
	local h = makeHandle(lib, o, "keybind",
		function() return current end,
		function(v) current = v btn.Text = v and v.Name or "未绑定" end)
	return card
end

local function ctlLabel(sec, o)
	local lib, ctx = sec.lib, sec.ctx
	local t = lib:Theme()
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
	return card
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
	return line
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
	Stroke(card, "line", 1)
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
	for _, d in ipairs(descs) do
		local dl = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(sp, y),
			Size = UDim2.new(1, -sp * 2, 0, ctx.M.mobile and 16 or 20),
			Font = Enum.Font.Gotham, TextSize = ctx.M.mobile and 12 or 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = tostring(d), Parent = card,
		})
		lib:Bind(dl, "TextColor3", "muted")
		y += dl.Size.Y.Offset
	end
	return card
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
	return cell
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
	-- 侧条用固定色（主题 token 动态换色走 SetTheme RefreshTheme）
	strip.BackgroundColor3 = t[token]
	local badge = New("Frame", {
		Size = UDim2.fromOffset(ctx.M.mobile and 24 or 32, ctx.M.mobile and 24 or 32),
		Position = UDim2.fromOffset(ctx.M.mobile and 14 or 16, ctx.M.mobile and 12 or 14),
		BackgroundColor3 = t[token], BackgroundTransparency = 0.8, Parent = card,
	})
	Corner(badge, 7)
	Stroke(badge, token, 1, 0.2, lib)
	local bt = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold, TextSize = ctx.M.mobile and 12 or 15,
		Text = tostring(o.Key or o.key or ""), Parent = badge,
	})
	bt.TextColor3 = t[token]
	local title = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(ctx.M.mobile and 46 or 56, ctx.M.mobile and 14 or 16),
		Size = UDim2.new(1, -(ctx.M.mobile and 60 or 72), 0, ctx.M.mobile and 22 or 28),
		Font = Enum.Font.GothamBold, TextSize = ctx.M.mobile and 14 or 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(o.Title or o.title or ""), Parent = card,
	})
	lib:Bind(title, "TextColor3", "text")
	local by = ctx.M.mobile and 42 or 52
	for _, line in ipairs(bullets) do
		local dot = New("Frame", {
			Position = UDim2.fromOffset(ctx.M.mobile and 20 or 24, by + 7),
			Size = UDim2.fromOffset(6, 6), BackgroundColor3 = t[token], Parent = card,
		})
		Corner(dot, 3)
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
		by += lineH
	end
	return card
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
	-- 最小化 / 关闭
	local btnH = M.top - M.pad * 2
	local btnW = math.floor((ctlW - M.gap) / 2)
	local minBtn = New("TextButton", {
		Position = UDim2.new(1, -(ctlW + M.pad), 0, M.pad),
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
	ctx.minBtn = minBtn
	ctx.closeBtn = closeBtn
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
	Stroke(tip, "line", 1)
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

-- ===== CreateWindow =====
function Lib:CreateWindow(self2, config)
	if config == nil then config = self2 end
	config = config or {}
	local mobile = isMobile()
	local M = metrics(mobile)
	local t = self:Theme()

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

	-- 关闭
	ctx.closeBtn.MouseButton1Click:Connect(function()
		if config.OnClose then pcall(config.OnClose) end
		win:Destroy()
	end)

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
				scale.Scale = math.clamp(scStart * (1 + (input.Position.Y - rzStart).Y * 0.002), 0.55, 1.4)
			end
		end))
		table.insert(ctx._conns, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then rz = false end
		end))
	end

	-- 跑马灯滚动
	local baseX = (M.mobile and 64 or 104) + (M.mobile and 22 or 32)
	local marqueeOff = 0
	table.insert(ctx._conns, RunService.Heartbeat:Connect(function(dt)
		local m = ctx.marquee
		if m and m.Parent then
			local textW = m.TextBounds.X
			local visW = math.max(m.AbsoluteSize.X, 1)
			marqueeOff += dt * 55
			if marqueeOff > textW + visW + 80 then marqueeOff = 0 end
			m.Position = UDim2.new(0, baseX - marqueeOff, 0.5, 0)
		end
	end))

	-- 呼出键
	if config.ToggleKey then
		table.insert(ctx._conns, UserInputService.InputBegan:Connect(function(input, gpe)
			if not gpe and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == config.ToggleKey then
				win:ToggleVisibility()
			end
		end))
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
	return win
end

-- ===== WinMT / TabMT 链式方法 =====
local WinMT = {}
WinMT.__index = WinMT
local TabMT = {}
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
	"Keybind", "Label", "Divider", "Paragraph", "Stat", "Card" }) do
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
	ctx.gui.Enabled = not ctx.gui.Enabled
end

function WinMT:Notify(a, b, ttl)
	local ctx = self._ctx
	local lib = ctx.lib
	local t = lib:Theme()
	local title = tostring(a or "通知")
	local content = type(b) == "string" and b or (type(a) == "table" and tostring(a.Content or a.content or "") or "")
	if type(a) == "table" then title = tostring(a.Title or a.title or "通知") end
	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = t.panel2, Parent = ctx.toastLayer,
	})
	Corner(card, 10)
	Stroke(card, "accent", 1, 0.3, lib)
	lib:Bind(card, "BackgroundColor3", "panel2")
	local bar = New("Frame", {
		Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = t.accent, BorderSizePixel = 0, Parent = card,
	})
	lib:Bind(bar, "BackgroundColor3", "accent")
	Corner(bar, 2)
	local tl = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -26, 0, 16), Font = Enum.Font.GothamBold, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, Text = title, Parent = card,
	})
	lib:Bind(tl, "TextColor3", "text")
	local cl = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 26),
		Size = UDim2.new(1, -26, 0, 24), Font = Enum.Font.Gotham, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		Text = content, Parent = card,
	})
	lib:Bind(cl, "TextColor3", "muted")
	task.delay(tonumber(ttl) or 3.5, function()
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
	local card = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(M.mobile and 260 or 380, M.mobile and 130 or 160),
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
	local cancelBtn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -14),
		Size = UDim2.fromOffset(M.mobile and 70 or 90, 34),
		BackgroundColor3 = t.panel3, Font = Enum.Font.GothamMedium, TextSize = 14,
		Text = "取消", ZIndex = 83, Parent = card,
	})
	Corner(cancelBtn, 8)
	Stroke(cancelBtn, "line", 1)
	lib:Bind(cancelBtn, "BackgroundColor3", "panel3")
	lib:Bind(cancelBtn, "TextColor3", "text")
	local okBtn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -(M.mobile and 98 or 122), 1, -14),
		Size = UDim2.fromOffset(M.mobile and 70 or 90, 34),
		BackgroundColor3 = t.accent, Font = Enum.Font.GothamBold, TextSize = 14,
		Text = "确认", ZIndex = 83, Parent = card,
	})
	Corner(okBtn, 8)
	lib:Bind(okBtn, "BackgroundColor3", "accent")
	lib:Bind(okBtn, "TextColor3", "bg")
	mask.MouseButton1Click:Connect(close)
	cancelBtn.MouseButton1Click:Connect(close)
	okBtn.MouseButton1Click:Connect(function()
		close()
		local cb = o.Callback or o.callback or o.onConfirm
		if cb then pcall(cb) end
	end)
end

function WinMT:Destroy()
	local ctx = self._ctx
	ctx:CloseList()
	for _, c in ipairs(ctx._conns) do
		pcall(function() c:Disconnect() end)
	end
	if ctx.gui then ctx.gui:Destroy() end
	local arr = Lib._Windows
	for i = #arr, 1, -1 do
		if arr[i] == self then table.remove(arr, i) end
	end
end

function WinMT:SetTheme(name)
	return Lib:SetTheme(name)
end

-- Theme 变化时同步卡侧条/徽章等固定色
function Lib:RefreshWindowTheme(win)
	-- 预留：卡侧条颜色跟随 token（当前版本侧条构建时取色，SetTheme 主体 token 已全覆盖）
end

Lib.WinMT = WinMT
Lib.TabMT = TabMT
Lib.SectionMethods = SectionMethods
Lib.THEMES = THEMES

rawset(_G, Lib._GName, Lib)

return Lib
