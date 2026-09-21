--[[
	QiurongToolbox 使用示例  ·  复刻《功能更新公告》样本页 + 全控件演示
	================================================================
	loadstring(game:HttpGet("https://raw.githubusercontent.com/qweqwefff222/dropshipping-hub/main/QiurongToolbox_Example.lua"))()

	· 页 1：公告（复刻 sample-tech-glass.png 的功能更新公告页）
	· 页 2：控件演示（Toggle/Slider/Dropdown/Multi/Input/Keybind/Button/Stat/Card）
	· 底部分类栏、‹ › 翻页、⌃ 展开/收起、右下角缩放、— 折叠、× 关闭
	· RightShift 呼出 / 隐藏窗口
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
secSelect:Multi{
	Title = "通知渠道", Options = { "控制台", "游戏内横幅", "Webhook" },
	Default = { "控制台" }, Flag = "Channels",
	Callback = function(list) print("[示例] Channels =", table.concat(list, ", ")) end,
}
secSelect:Input{
	Title = "备注", Placeholder = "随便写点什么...", Flag = "Note",
	Callback = function(text) print("[示例] Note =", text) end,
}
secSelect:Keybind{
	Title = "呼出键", Flag = "Key",
	Callback = function(key) print("[示例] Key =", key and key.Name) end,
}

local secActions = demo:Section("动作")
local themeOrder = { "tech-glass", "tactical-terminal", "premium-dark" }
local themeIdx = 1
secActions:Button{
	Title = "切换主题", Desc = "科技玻璃 → 战术终端 → 高级暗色",
	Callback = function()
		themeIdx = themeIdx % #themeOrder + 1
		Lib:SetTheme(themeOrder[themeIdx])
		Window:Notify("主题已切换", Lib:Theme().name)
	end,
}
secActions:Button{
	Title = "弹通知", Callback = function()
		Window:Notify("提示", "这是一条 Toast 通知")
	end,
}
secActions:Button{
	Title = "确认对话框", Callback = function()
		Window:Dialog{
			Title = "确认操作",
			Content = "此操作将重置全部配置，确定继续吗？",
			Callback = function()
				Window:Notify("已确认", "配置已重置")
			end,
		}
	end,
}

Window:Notify("秋容工具箱", "按 RightShift 呼出 / 隐藏窗口")
print("[QiurongToolbox] 示例加载完成，Flags: ", Lib.Flags)
