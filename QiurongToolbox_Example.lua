--[[
	QiurongToolbox 使用示例 v1.1.0  ·  复刻《功能更新公告》样本页 + 全控件 + WindUI 对齐功能演示
	================================================================
	loadstring(game:HttpGet("https://raw.githubusercontent.com/qweqwefff222/dropshipping-hub/main/QiurongToolbox_Example.lua"))()

	· 页 1：公告（复刻 sample-tech-glass.png 的功能更新公告页）
	· 页 2：控件演示（含 ColorPicker / Checkbox / 搜索下拉）
	· 页 3：WindUI 对齐功能（配置保存 / 句柄操作 / 窗口方法 / 多按钮对话框）
	· 顶栏 "◐" 循环切换主题；× 关闭后悬浮球重开；RightShift 呼出/隐藏
	· 开屏公告：CreateWindow 传 Notice 即自动弹出（未传则不弹）
]]

local Lib = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/qweqwefff222/dropshipping-hub/main/QiurongToolbox.lua"))()

local Window = Lib:CreateWindow{
	Title       = "秋容工具箱",
	Subtitle    = "QIURONG / ROBLOX UI",
	Theme       = "tech-glass",
	Marquee     = "作者：秋容  ·  求点赞关注，谢谢支持  ·  脚本一直爽，封号两行泪  ·  请合理使用功能",
	NoticeBadge = "置顶公告",
	ToggleKey   = Enum.KeyCode.RightShift,
	Folder      = "QiurongToolboxDemo",   -- 配置持久化目录（带 Flag 的控件自动保存/回灌）
	CloseAction = "hide",                 -- × 隐藏而非销毁，悬浮球可重开
	OpenButton  = { Title = "打开 工具箱", OnlyMobile = true, Draggable = true },
	Notice      = {                        -- 开屏公告（没写就默认不弹）
		Badge = "新版本",
		Title = "v1.1.0 更新公告",
		Lines = {
			"· 新增窗口内主题切换（顶栏 ◐ 按钮）",
			"· 新增配置持久化：带 Flag 的控件自动保存",
			"· 新增 ColorPicker / 卡密门禁 / 悬浮打开按钮",
			"· 控件句柄支持 Lock / Unlock / SetTitle / Highlight",
		},
	},
	-- KeySystem = {                       -- 需要卡密门禁时解开注释
	-- 	KeyValidator = function(k) return k == "1234" end,
	-- 	Note = "示例卡密：1234", SaveKey = true,
	-- },
}

-- ===== 页 1：功能更新公告（样本复刻） =====
local notes = Window:Tab{
	Title    = "公告",
	Subtitle = "RELEASE NOTES  ·  版本 v2.3.0  ·  2026-09-12",
	Badge    = "正式版本",
}

local secTop = notes:Section("功能更新公告")
secTop:Paragraph{
	Badge = "本次更新",
	Title = "2.3.0",
	Desc  = { "启动、加载与窗口适配升级", "让高频操作更稳定、更顺畅。" },
}

local secStats = notes:Section("变更统计")
secStats:Stat{ Number = "3", Label = "新增功能" }
secStats:Stat{ Number = "4", Label = "体验优化" }
secStats:Stat{ Number = "2", Label = "问题修复" }
secStats:Stat{ Number = "9", Label = "全部变更" }

local secCards = notes:Section("变更明细")
secCards:Card{
	Key = "新", Title = "新增", Color = "good",
	Bullets = {
		"新增快捷启动面板，支持固定常用模块",
		"新增配置恢复入口，可继续上次设置",
		"新增运行状态概览，结果集中展示",
	},
}
secCards:Card{
	Key = "优", Title = "优化", Color = "accent",
	Bullets = {
		"优化模块加载速度与初始化顺序",
		"优化窗口缩放后的内容自适应",
		"调整提示层级，减少视觉干扰",
	},
}
secCards:Card{
	Key = "修", Title = "修复", Color = "warn",
	Bullets = {
		"修复窗口缩放后局部内容错位",
		"修复快速退出时偶发未保存",
		"修复重复打开时状态显示不同步",
	},
}

-- ===== 页 2：控件演示 =====
local demo = Window:Tab{
	Title    = "控件演示",
	Subtitle = "SAMPLE CONTROLS  ·  全控件一览",
	Badge    = "演示",
}

local secToggles = demo:Section("开关与滑条")
secToggles:Toggle{
	Title = "自动开始", Desc = "开启后自动执行主流程",
	Default = false, Flag = "AutoStart",
	Callback = function(v) print("[示例] AutoStart =", v) end,
}
secToggles:Toggle{
	Title = "勾选框样式", Desc = "Type = \"Checkbox\" 变体",
	Type = "Checkbox", Default = true, Flag = "CheckboxDemo",
	Callback = function(v) print("[示例] Checkbox =", v) end,
}
secToggles:Slider{
	Title = "执行延迟", Min = 0, Max = 10, Step = 0.5, Default = 1,
	Suffix = "s", Flag = "Delay",
	Callback = function(v) print("[示例] Delay =", v) end,
}

local secSelect = demo:Section("选择与输入")
secSelect:Dropdown{
	Title = "目标模块", Options = { "主线任务", "日常任务", "活动任务" },
	Default = "主线任务", Flag = "Target",
	Callback = function(v) print("[示例] Target =", v) end,
}
secSelect:Dropdown{
	Title = "搜索选择", Desc = "SearchBarEnabled + AllowNone",
	Options = { "火系", "水系", "草系", "雷系", "冰系", "光系", "暗系" },
	SearchBarEnabled = true, AllowNone = true, Flag = "SearchPick",
	Callback = function(v) print("[示例] SearchPick =", v) end,
}
secSelect:Multi{
	Title = "通知渠道", Options = { "控制台", "游戏内横幅", "Webhook" },
	Default = { "控制台" }, Flag = "Channels",
	Callback = function(list) print("[示例] Channels =", table.concat(list, ", ")) end,
}
secSelect:ColorPicker{
	Title = "主题色", Desc = "HSV 面板 + 色相条 + 预设色板",
	Default = Color3.fromRGB(57, 200, 255), Flag = "AccentColor",
	Callback = function(c) print("[示例] Color =", c) end,
}
secSelect:Input{
	Title = "备注", Placeholder = "随便写点什么...", Flag = "Note",
	Callback = function(text) print("[示例] Note =", text) end,
}
secSelect:Keybind{
	Title = "呼出键", Flag = "Key",
	Callback = function(key) print("[示例] Key =", key and key.Name) end,
}

-- ===== 页 3：WindUI 对齐功能 =====
local adv = Window:Tab{
	Title    = "高级功能",
	Subtitle = "WINDUI ALIGNED  ·  配置 / 句柄 / 窗口 API",
	Badge    = "v1.1.0",
}

local secHandle = adv:Section("控件句柄操作")
local demoToggle = secHandle:Toggle{
	Title = "被管理的开关", Desc = "用下方按钮 Lock/Unlock/Highlight 它",
	Flag = "Managed", Default = false,
	Callback = function(v) print("[示例] Managed =", v) end,
}
secHandle:Button{
	Title = "句柄：Lock / Unlock", Callback = function()
		if demoToggle._locked then demoToggle:Unlock() else demoToggle:Lock() end
	end,
}
secHandle:Button{
	Title = "句柄：Highlight + SetTitle", Callback = function()
		demoToggle:Highlight()
		demoToggle:SetTitle("标题改于 " .. os.date("%H:%M:%S"))
	end,
}
secHandle:Button{
	Title = "句柄：Destroy（移除开关）", Callback = function()
		demoToggle:Destroy()
		demoToggle = nil
	end,
}

local secTheme = adv:Section("主题与配置")
local themeOrder = { "tech-glass", "tactical-terminal", "premium-dark" }
local themeIdx = 1
secTheme:Button{
	Title = "Lib:SetTheme 循环切换", Desc = "等价于顶栏 ◐ 按钮",
	Callback = function()
		themeIdx = themeIdx % #themeOrder + 1
		Lib:SetTheme(themeOrder[themeIdx])
		Window:Notify{
			Title = "主题已切换", Icon = "◐", Duration = 2.5,
			Content = Lib:Theme().name .. " · 当前 " .. Lib:GetCurrentTheme(),
		}
	end,
}
secTheme:Button{
	Title = "Lib:AddTheme 自定义主题", Callback = function()
		Lib:AddTheme("ocean", { name = "海洋", accent = Color3.fromRGB(64, 224, 208), pattern = "minimal" })
		Lib:SetTheme("ocean")
	end,
}
secTheme:Button{
	Title = "立即保存配置", Desc = "平时带 Flag 控件变化后 0.6s 自动保存",
	Callback = function()
		local ok, err = Lib:SaveConfig()
		Window:Notify("配置保存", ok and ("已写入 " .. Lib.Folder .. "/config.json") or tostring(err))
	end,
}
secTheme:Button{
	Title = "列出 / 载入命名配置", Callback = function()
		Lib:SaveConfig("备份1")
		local list = Lib:GetConfigs()
		Window:Notify("配置列表", #list > 0 and table.concat(list, ", ") or "（空）")
	end,
}

local secWin = adv:Section("窗口方法")
secWin:Button{
	Title = "SetTitle / SetAuthor / SetIcon", Callback = function()
		Window:SetTitle("标题改于 " .. os.date("%M:%S"))
		Window:SetAuthor("subtitle changed")
		Window:SetIcon("落")
	end,
}
secWin:Button{
	Title = "SetUIScale(1.2) / SetSize", Callback = function()
		Window:SetUIScale(1.2)
		print("[示例] UIScale =", Window:GetUIScale(), "窗口 =", Window:GetWindowSize())
	end,
}
secWin:Button{
	Title = "背景透明度 0.5", Callback = function()
		Window:SetBackgroundTransparency(0.5)
	end,
}
secWin:Button{
	Title = "多按钮对话框", Callback = function()
		Window:Dialog{
			Title = "选择操作",
			Content = "WindUI Popup 风格：自定义按钮组 + Variant",
			Buttons = {
				{ Title = "取消",   Variant = "Tertiary" },
				{ Title = "重置",   Variant = "Danger",  Callback = function() Window:Notify("已重置", "danger 按钮") end },
				{ Title = "继续",   Variant = "Primary", Callback = function() Window:Notify("已继续", "primary 按钮", "✓", 2) end },
			},
		}
	end,
}

Window:Notify("秋容工具箱 v1.1.0", "按 RightShift 呼出 / 隐藏窗口；顶栏 ◐ 切换主题")
print("[QiurongToolbox] 示例加载完成 v1.1.0；配置目录:", Lib.Folder)
