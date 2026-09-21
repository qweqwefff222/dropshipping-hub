--[[ QiurongUI 使用示例 —— loadstring 加载库 + CreateWindow 建窗 + 全控件演示 ]]

local QiurongUI = _G.QiuRongUI or loadstring(game:HttpGet("https://raw.githubusercontent.com/qweqwefff222/dropshipping-hub/main/QiurongUI.lua"))()

QiurongUI.CreateWindow{
	Name = "示例脚本",
	Version = "1.0.0",
	Author = "你的名字",
	GuiName = "ExampleUI",
	DefaultPage = "home",
	MarqueeText = "QiurongUI 示例 · 快捷键 右Shift 开关窗口",
	AnnouncementTitle = "公告",
	AnnouncementText = "这是 CreateWindow 弹出的公告。\n支持多行文本。",
	OnClose = function()
		print("脚本被用户关闭，这里做你自己的清理")
	end,
	Pages = {
		{
			id = "home", title = "主页", icon = "H", subtitle = "基础控件",
			sections = { { title = "开关与按钮", items = {
				{ type = "toggle", key = "demo.autofarm", title = "自动挂机", desc = "示例开关",
				  onChanged = function(v) print("autofarm =", v) end },
				{ type = "button", key = "demo.ping", title = "测延迟", desc = "点我", actionText = "测试",
				  onChanged = function() QiurongUI.Notify("当前延迟 " .. math.floor(game.Players.LocalPlayer:GetNetworkPing() * 1000) .. " ms") end },
			} }, { title = "数值", items = {
				{ type = "slider", key = "demo.speed", title = "速度倍率", min = 1, max = 10, step = 0.5, default = 2,
				  onChanged = function(v) print("speed =", v) end },
				{ type = "number", key = "demo.count", title = "循环次数", min = 1, max = 99, default = 5 },
				{ type = "input", key = "demo.name", title = "物品名", default = "木头" },
			} } },
		},
		{
			id = "live", title = "实时面板", icon = "L", subtitle = "status/progress 实时刷新演示",
			sections = { { title = "每 0.4 秒自动刷新", items = {
				{ type = "status", key = "demo.clock", title = "当前时间",
				  value = function() return os.date("%H:%M:%S") end },
				{ type = "status", key = "demo.pos", title = "我的坐标",
				  value = function()
					local c = game.Players.LocalPlayer.Character
					local p = c and c:GetPivot().Position
					return p and (math.floor(p.X) .. ", " .. math.floor(p.Z)) or "加载中"
				  end },
				{ type = "progress", key = "demo.hp", title = "生命值",
				  value = function()
					local c = game.Players.LocalPlayer.Character
					local h = c and c:FindFirstChildOfClass("Humanoid")
					return h and math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1) or 0
				  end },
			} } },
		},
	},
}

print("[示例] QiurongUI " .. tostring(QiurongUI.Version) .. " 已加载")
