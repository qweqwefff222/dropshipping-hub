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

-- ===== 内置图标库（lucide 图标集 1195 个 · 资产 ID 来自 Footagesus/WindUI 预上传，MIT）=====
-- 用法：Lib.Icon("eye") / "lucide:eye" / "rbxassetid://xxx"
local ICONS_DATA = {
  ["a-arrow-down"]="rbxassetid://92867583610071",
  ["a-arrow-up"]="rbxassetid://132318504999733",
  ["a-large-small"]="rbxassetid://111491496660216",
  ["accessibility"]="rbxassetid://114029945302017",
  ["activity"]="rbxassetid://94212016861936",
  ["air-vent"]="rbxassetid://81517226012329",
  ["airplay"]="rbxassetid://115020759309179",
  ["alarm-clock-check"]="rbxassetid://76437352099157",
  ["alarm-clock-minus"]="rbxassetid://77364179863205",
  ["alarm-clock-off"]="rbxassetid://97904885874823",
  ["alarm-clock-plus"]="rbxassetid://80468822979214",
  ["alarm-clock"]="rbxassetid://126259032907535",
  ["alarm-smoke"]="rbxassetid://96965448419685",
  ["album"]="rbxassetid://127358331163602",
  ["align-center-horizontal"]="rbxassetid://81570549209434",
  ["align-center-vertical"]="rbxassetid://118470463752466",
  ["align-end-horizontal"]="rbxassetid://139502909745427",
  ["align-end-vertical"]="rbxassetid://96528869059554",
  ["align-horizontal-distribute-center"]="rbxassetid://97220086126656",
  ["align-horizontal-distribute-end"]="rbxassetid://106128590702022",
  ["align-horizontal-distribute-start"]="rbxassetid://76074660002997",
  ["align-horizontal-justify-center"]="rbxassetid://75732302772427",
  ["align-horizontal-justify-end"]="rbxassetid://129167626402283",
  ["align-horizontal-justify-start"]="rbxassetid://130161830325281",
  ["align-horizontal-space-around"]="rbxassetid://91646106782950",
  ["align-horizontal-space-between"]="rbxassetid://103886093046990",
  ["align-start-horizontal"]="rbxassetid://125674804697729",
  ["align-start-vertical"]="rbxassetid://105020230154823",
  ["align-vertical-distribute-center"]="rbxassetid://93791183635525",
  ["align-vertical-distribute-end"]="rbxassetid://139354223511433",
  ["align-vertical-distribute-start"]="rbxassetid://74961997822126",
  ["align-vertical-justify-center"]="rbxassetid://134754696166569",
  ["align-vertical-justify-end"]="rbxassetid://92569381441969",
  ["align-vertical-justify-start"]="rbxassetid://99692844572718",
  ["align-vertical-space-around"]="rbxassetid://96206012459190",
  ["align-vertical-space-between"]="rbxassetid://124998077349706",
  ["ambulance"]="rbxassetid://78599995190651",
  ["ampersand"]="rbxassetid://75272915739209",
  ["ampersands"]="rbxassetid://126947193455996",
  ["amphora"]="rbxassetid://137370389604364",
  ["anchor"]="rbxassetid://92181172123618",
  ["angry"]="rbxassetid://74237056000103",
  ["annoyed"]="rbxassetid://80064369052011",
  ["antenna"]="rbxassetid://99628923540956",
  ["anvil"]="rbxassetid://100203029845919",
  ["aperture"]="rbxassetid://83396154449972",
  ["app-window-mac"]="rbxassetid://79587216113811",
  ["app-window"]="rbxassetid://93142176757189",
  ["apple"]="rbxassetid://104349242902442",
  ["archive-restore"]="rbxassetid://78956681942188",
  ["archive-x"]="rbxassetid://75830115088395",
  ["archive"]="rbxassetid://122180020814574",
  ["armchair"]="rbxassetid://105384358373973",
  ["arrow-big-down-dash"]="rbxassetid://137987229582002",
  ["arrow-big-down"]="rbxassetid://81081164158885",
  ["arrow-big-left-dash"]="rbxassetid://97827621354677",
  ["arrow-big-left"]="rbxassetid://85973092492641",
  ["arrow-big-right-dash"]="rbxassetid://117825834972403",
  ["arrow-big-right"]="rbxassetid://82960676755590",
  ["arrow-big-up-dash"]="rbxassetid://99260194327483",
  ["arrow-big-up"]="rbxassetid://93136954756149",
  ["arrow-down-0-1"]="rbxassetid://120961896217875",
  ["arrow-down-1-0"]="rbxassetid://93474255891850",
  ["arrow-down-a-z"]="rbxassetid://99554596207900",
  ["arrow-down-from-line"]="rbxassetid://132045845807798",
  ["arrow-down-left"]="rbxassetid://102899325237364",
  ["arrow-down-narrow-wide"]="rbxassetid://129105261655061",
  ["arrow-down-right"]="rbxassetid://123109928624974",
  ["arrow-down-to-dot"]="rbxassetid://101675355931221",
  ["arrow-down-to-line"]="rbxassetid://87050478931254",
  ["arrow-down-up"]="rbxassetid://85780258549577",
  ["arrow-down-wide-narrow"]="rbxassetid://88461733425991",
  ["arrow-down-z-a"]="rbxassetid://76115279362232",
  ["arrow-down"]="rbxassetid://98764963621439",
  ["arrow-left-from-line"]="rbxassetid://87857914437603",
  ["arrow-left-right"]="rbxassetid://131324733048447",
  ["arrow-left-to-line"]="rbxassetid://118645136026970",
  ["arrow-left"]="rbxassetid://102531941843733",
  ["arrow-right-from-line"]="rbxassetid://74073639809355",
  ["arrow-right-left"]="rbxassetid://77015754304300",
  ["arrow-right-to-line"]="rbxassetid://78632510329852",
  ["arrow-right"]="rbxassetid://113692007244654",
  ["arrow-up-0-1"]="rbxassetid://105257823943016",
  ["arrow-up-1-0"]="rbxassetid://134175521693798",
  ["arrow-up-a-z"]="rbxassetid://77763416595160",
  ["arrow-up-down"]="rbxassetid://81019887641527",
  ["arrow-up-from-dot"]="rbxassetid://124408496673275",
  ["arrow-up-from-line"]="rbxassetid://95777664626453",
  ["arrow-up-left"]="rbxassetid://123490598231261",
  ["arrow-up-narrow-wide"]="rbxassetid://73006024672636",
  ["arrow-up-right"]="rbxassetid://129280608535523",
  ["arrow-up-to-line"]="rbxassetid://108818207813537",
  ["arrow-up-wide-narrow"]="rbxassetid://87437426951568",
  ["arrow-up-z-a"]="rbxassetid://107546173611884",
  ["arrow-up"]="rbxassetid://89282378235317",
  ["arrows-up-from-line"]="rbxassetid://133710016938621",
  ["asterisk"]="rbxassetid://88552752106723",
  ["at-sign"]="rbxassetid://79059152889146",
  ["atom"]="rbxassetid://73167696981648",
  ["audio-lines"]="rbxassetid://70930641819242",
  ["audio-waveform"]="rbxassetid://86462036665209",
  ["award"]="rbxassetid://132740088158419",
  ["axe"]="rbxassetid://132405197863294",
  ["axis-3d"]="rbxassetid://122438676546804",
  ["baby"]="rbxassetid://93472926933440",
  ["backpack"]="rbxassetid://140420225386018",
  ["badge-alert"]="rbxassetid://101829200081951",
  ["badge-cent"]="rbxassetid://133345018873154",
  ["badge-check"]="rbxassetid://76078495178149",
  ["badge-dollar-sign"]="rbxassetid://127139803581141",
  ["badge-euro"]="rbxassetid://120016477674659",
  ["badge-indian-rupee"]="rbxassetid://75659682309981",
  ["badge-info"]="rbxassetid://131995373201472",
  ["badge-japanese-yen"]="rbxassetid://99081574588615",
  ["badge-minus"]="rbxassetid://140321561183881",
  ["badge-percent"]="rbxassetid://121359224294885",
  ["badge-plus"]="rbxassetid://100325578561866",
  ["badge-pound-sterling"]="rbxassetid://119688217279444",
  ["badge-question-mark"]="rbxassetid://121464963737502",
  ["badge-russian-ruble"]="rbxassetid://108839463659864",
  ["badge-swiss-franc"]="rbxassetid://91447608372740",
  ["badge-turkish-lira"]="rbxassetid://137839965873529",
  ["badge-x"]="rbxassetid://122931434733842",
  ["badge"]="rbxassetid://116620312917084",
  ["baggage-claim"]="rbxassetid://86922213051957",
  ["ban"]="rbxassetid://90767043015246",
  ["banana"]="rbxassetid://140713420056179",
  ["bandage"]="rbxassetid://129660129590770",
  ["banknote-arrow-down"]="rbxassetid://139366449345199",
  ["banknote-arrow-up"]="rbxassetid://133758343082529",
  ["banknote-x"]="rbxassetid://95348701438065",
  ["banknote"]="rbxassetid://104840231536668",
  ["barcode"]="rbxassetid://118473018143689",
  ["barrel"]="rbxassetid://130647115622774",
  ["baseline"]="rbxassetid://124677132511270",
  ["bath"]="rbxassetid://76031400297942",
  ["battery-charging"]="rbxassetid://80139357470047",
  ["battery-full"]="rbxassetid://70906718268972",
  ["battery-low"]="rbxassetid://139659256984314",
  ["battery-medium"]="rbxassetid://105934079398915",
  ["battery-plus"]="rbxassetid://91931341486966",
  ["battery-warning"]="rbxassetid://115230083817257",
  ["battery"]="rbxassetid://70765800346189",
  ["beaker"]="rbxassetid://80902539995520",
  ["bean-off"]="rbxassetid://98164436608714",
  ["bean"]="rbxassetid://89491967076869",
  ["bed-double"]="rbxassetid://73820193212911",
  ["bed-single"]="rbxassetid://113423940880634",
  ["bed"]="rbxassetid://97726529032925",
  ["beef"]="rbxassetid://105850162318915",
  ["beer-off"]="rbxassetid://120333134736361",
  ["beer"]="rbxassetid://116404978807744",
  ["bell-dot"]="rbxassetid://93161277118810",
  ["bell-electric"]="rbxassetid://100277767266983",
  ["bell-minus"]="rbxassetid://126334890449727",
  ["bell-off"]="rbxassetid://78560046118930",
  ["bell-plus"]="rbxassetid://77014333795836",
  ["bell-ring"]="rbxassetid://94612128913941",
  ["bell"]="rbxassetid://97392696311902",
  ["between-horizontal-end"]="rbxassetid://81602774794322",
  ["between-horizontal-start"]="rbxassetid://76112384929846",
  ["between-vertical-end"]="rbxassetid://72817612571631",
  ["between-vertical-start"]="rbxassetid://85278312190301",
  ["biceps-flexed"]="rbxassetid://82004462003936",
  ["bike"]="rbxassetid://102930322246035",
  ["binary"]="rbxassetid://91751953950088",
  ["binoculars"]="rbxassetid://101460003267896",
  ["biohazard"]="rbxassetid://95956532900432",
  ["bird"]="rbxassetid://132284145117371",
  ["birdhouse"]="rbxassetid://83999157401433",
  ["bitcoin"]="rbxassetid://95459240442938",
  ["blend"]="rbxassetid://111679612185257",
  ["blinds"]="rbxassetid://71164165283925",
  ["blocks"]="rbxassetid://72212693357737",
  ["bluetooth-connected"]="rbxassetid://96315134002985",
  ["bluetooth-off"]="rbxassetid://80600044218117",
  ["bluetooth-searching"]="rbxassetid://100673019606426",
  ["bluetooth"]="rbxassetid://90506573139443",
  ["bold"]="rbxassetid://116141470019166",
  ["bolt"]="rbxassetid://102881251417484",
  ["bomb"]="rbxassetid://139223800924636",
  ["bone"]="rbxassetid://111242153474115",
  ["book-a"]="rbxassetid://104067275658465",
  ["book-alert"]="rbxassetid://124159928044853",
  ["book-audio"]="rbxassetid://109208148317037",
  ["book-check"]="rbxassetid://115999656081696",
  ["book-copy"]="rbxassetid://108543407492005",
  ["book-dashed"]="rbxassetid://127430784795958",
  ["book-down"]="rbxassetid://101011730128222",
  ["book-headphones"]="rbxassetid://108670200799574",
  ["book-heart"]="rbxassetid://112788845135284",
  ["book-image"]="rbxassetid://80808285757226",
  ["book-key"]="rbxassetid://116024426170705",
  ["book-lock"]="rbxassetid://118765061220571",
  ["book-marked"]="rbxassetid://73211024251780",
  ["book-minus"]="rbxassetid://112724962046282",
  ["book-open-check"]="rbxassetid://130848362492667",
  ["book-open-text"]="rbxassetid://100629528672195",
  ["book-open"]="rbxassetid://129845326810392",
  ["book-plus"]="rbxassetid://140267785051233",
  ["book-text"]="rbxassetid://94011772484232",
  ["book-type"]="rbxassetid://97817304725443",
  ["book-up-2"]="rbxassetid://130161620853665",
  ["book-up"]="rbxassetid://98640174079190",
  ["book-user"]="rbxassetid://128489189240523",
  ["book-x"]="rbxassetid://118754548186537",
  ["book"]="rbxassetid://125383279695672",
  ["bookmark-check"]="rbxassetid://93940443347986",
  ["bookmark-minus"]="rbxassetid://96807096039910",
  ["bookmark-plus"]="rbxassetid://121469724491615",
  ["bookmark-x"]="rbxassetid://112272342584706",
  ["bookmark"]="rbxassetid://121093149326239",
  ["boom-box"]="rbxassetid://99901322535868",
  ["bot-message-square"]="rbxassetid://96145330292478",
  ["bot-off"]="rbxassetid://140417690560013",
  ["bot"]="rbxassetid://80451686744860",
  ["bottle-wine"]="rbxassetid://131675403196921",
  ["bow-arrow"]="rbxassetid://124089655150375",
  ["box"]="rbxassetid://101768155599700",
  ["boxes"]="rbxassetid://136372617578355",
  ["braces"]="rbxassetid://117761094704041",
  ["brackets"]="rbxassetid://74368995728099",
  ["brain-circuit"]="rbxassetid://70547962410202",
  ["brain-cog"]="rbxassetid://132039205501538",
  ["brain"]="rbxassetid://92424107303177",
  ["brick-wall-fire"]="rbxassetid://92980588705520",
  ["brick-wall-shield"]="rbxassetid://75954432775071",
  ["brick-wall"]="rbxassetid://112878522258821",
  ["briefcase-business"]="rbxassetid://129135125207283",
  ["briefcase-conveyor-belt"]="rbxassetid://108665725653714",
  ["briefcase-medical"]="rbxassetid://119917756334087",
  ["briefcase"]="rbxassetid://96754188164225",
  ["bring-to-front"]="rbxassetid://132975903553748",
  ["brush-cleaning"]="rbxassetid://71728977448805",
  ["brush"]="rbxassetid://127035535799640",
  ["bubbles"]="rbxassetid://106183424168227",
  ["bug-off"]="rbxassetid://88020025049245",
  ["bug-play"]="rbxassetid://80107955888092",
  ["bug"]="rbxassetid://83626408925438",
  ["building-2"]="rbxassetid://77873775611951",
  ["building"]="rbxassetid://110616258983082",
  ["bus-front"]="rbxassetid://89863432456045",
  ["bus"]="rbxassetid://133798469717463",
  ["cable-car"]="rbxassetid://128643682205596",
  ["cable"]="rbxassetid://128449944504901",
  ["cake-slice"]="rbxassetid://136769828413242",
  ["cake"]="rbxassetid://103131590503275",
  ["calculator"]="rbxassetid://74915716529646",
  ["calendar-1"]="rbxassetid://98458364171044",
  ["calendar-arrow-down"]="rbxassetid://108415736543437",
  ["calendar-arrow-up"]="rbxassetid://70574654109118",
  ["calendar-check-2"]="rbxassetid://120231170248276",
  ["calendar-check"]="rbxassetid://71551019465748",
  ["calendar-clock"]="rbxassetid://119132152594595",
  ["calendar-cog"]="rbxassetid://122402172360287",
  ["calendar-days"]="rbxassetid://99072017568595",
  ["calendar-fold"]="rbxassetid://117368871270394",
  ["calendar-heart"]="rbxassetid://88839008103676",
  ["calendar-minus-2"]="rbxassetid://98846170279891",
  ["calendar-minus"]="rbxassetid://137354318924383",
  ["calendar-off"]="rbxassetid://109726151749217",
  ["calendar-plus-2"]="rbxassetid://112264562093883",
  ["calendar-plus"]="rbxassetid://125266115249843",
  ["calendar-range"]="rbxassetid://103641849247576",
  ["calendar-search"]="rbxassetid://92010083223634",
  ["calendar-sync"]="rbxassetid://78082218499697",
  ["calendar-x-2"]="rbxassetid://107518051061147",
  ["calendar-x"]="rbxassetid://106703374806500",
  ["calendar"]="rbxassetid://114792700814035",
  ["camera-off"]="rbxassetid://81057636835256",
  ["camera"]="rbxassetid://79950339943067",
  ["candy-cane"]="rbxassetid://71689468772492",
  ["candy-off"]="rbxassetid://110232752314832",
  ["candy"]="rbxassetid://107812129154678",
  ["cannabis"]="rbxassetid://98792006538601",
  ["captions-off"]="rbxassetid://105223545364193",
  ["captions"]="rbxassetid://104960225031445",
  ["car-front"]="rbxassetid://87380942739063",
  ["car-taxi-front"]="rbxassetid://122455403384057",
  ["car"]="rbxassetid://121065933462582",
  ["caravan"]="rbxassetid://120070979471783",
  ["card-sim"]="rbxassetid://134490550095771",
  ["carrot"]="rbxassetid://119118221444304",
  ["case-lower"]="rbxassetid://129303130603241",
  ["case-sensitive"]="rbxassetid://125410273293056",
  ["case-upper"]="rbxassetid://111633433531325",
  ["cassette-tape"]="rbxassetid://137065788934157",
  ["cast"]="rbxassetid://98202245922071",
  ["castle"]="rbxassetid://119275077187784",
  ["cat"]="rbxassetid://124252153404931",
  ["cctv"]="rbxassetid://99979894766624",
  ["chart-area"]="rbxassetid://123446436762366",
  ["chart-bar-big"]="rbxassetid://72336824986044",
  ["chart-bar-decreasing"]="rbxassetid://107217459044963",
  ["chart-bar-increasing"]="rbxassetid://88268905998571",
  ["chart-bar-stacked"]="rbxassetid://98478751113024",
  ["chart-bar"]="rbxassetid://105389816384108",
  ["chart-candlestick"]="rbxassetid://125676898615697",
  ["chart-column-big"]="rbxassetid://98598733210787",
  ["chart-column-decreasing"]="rbxassetid://73586137373563",
  ["chart-column-increasing"]="rbxassetid://120421615068601",
  ["chart-column-stacked"]="rbxassetid://86031449675105",
  ["chart-column"]="rbxassetid://97915995538580",
  ["chart-gantt"]="rbxassetid://88811660555940",
  ["chart-line"]="rbxassetid://101833156055618",
  ["chart-network"]="rbxassetid://104027882693561",
  ["chart-no-axes-column-decreasing"]="rbxassetid://123371717192542",
  ["chart-no-axes-column-increasing"]="rbxassetid://140383830943049",
  ["chart-no-axes-column"]="rbxassetid://94078751170351",
  ["chart-no-axes-combined"]="rbxassetid://121424233161912",
  ["chart-no-axes-gantt"]="rbxassetid://131936541106368",
  ["chart-pie"]="rbxassetid://113412261630136",
  ["chart-scatter"]="rbxassetid://108217585014571",
  ["chart-spline"]="rbxassetid://90307460742494",
  ["check-check"]="rbxassetid://95183312173858",
  ["check-line"]="rbxassetid://115122343485290",
  ["check"]="rbxassetid://93898873302694",
  ["chef-hat"]="rbxassetid://121744015002573",
  ["cherry"]="rbxassetid://139519182403183",
  ["chess-bishop"]="rbxassetid://121701705580238",
  ["chess-king"]="rbxassetid://90885687223462",
  ["chess-knight"]="rbxassetid://96467707042169",
  ["chess-pawn"]="rbxassetid://111318574652751",
  ["chess-queen"]="rbxassetid://98304702099749",
  ["chess-rook"]="rbxassetid://76223925830262",
  ["chevron-down"]="rbxassetid://134243273101015",
  ["chevron-first"]="rbxassetid://105243363790238",
  ["chevron-last"]="rbxassetid://89268452603731",
  ["chevron-left"]="rbxassetid://73780377692148",
  ["chevron-right"]="rbxassetid://92473583511724",
  ["chevron-up"]="rbxassetid://122444883127455",
  ["chevrons-down-up"]="rbxassetid://139404716013205",
  ["chevrons-down"]="rbxassetid://100524612205956",
  ["chevrons-left-right-ellipsis"]="rbxassetid://125035817741526",
  ["chevrons-left-right"]="rbxassetid://87910685945204",
  ["chevrons-left"]="rbxassetid://82617201744347",
  ["chevrons-right-left"]="rbxassetid://87149546686569",
  ["chevrons-right"]="rbxassetid://139121276490483",
  ["chevrons-up-down"]="rbxassetid://131833120209646",
  ["chevrons-up"]="rbxassetid://100467452364672",
  ["chromium"]="rbxassetid://128165143739006",
  ["church"]="rbxassetid://113714744350666",
  ["cigarette-off"]="rbxassetid://77797883078452",
  ["circle-alert"]="rbxassetid://83898160590116",
  ["circle-arrow-down"]="rbxassetid://95901860261344",
  ["circle-arrow-left"]="rbxassetid://102148876968988",
  ["circle-arrow-out-down-left"]="rbxassetid://140598097856694",
  ["circle-arrow-out-down-right"]="rbxassetid://119952801379305",
  ["circle-arrow-out-up-left"]="rbxassetid://132858212688303",
  ["circle-arrow-out-up-right"]="rbxassetid://81783743753173",
  ["circle-arrow-right"]="rbxassetid://70786767999559",
  ["circle-arrow-up"]="rbxassetid://84395128546494",
  ["circle-check-big"]="rbxassetid://93202927221730",
  ["circle-check"]="rbxassetid://85262178816537",
  ["circle-chevron-down"]="rbxassetid://137069490345718",
  ["circle-chevron-left"]="rbxassetid://130250009740827",
  ["circle-chevron-right"]="rbxassetid://125943696958495",
  ["circle-chevron-up"]="rbxassetid://111223574026321",
  ["circle-dashed"]="rbxassetid://126799443883746",
  ["circle-divide"]="rbxassetid://106398997754208",
  ["circle-dollar-sign"]="rbxassetid://91106238890387",
  ["circle-dot-dashed"]="rbxassetid://111451232827180",
  ["circle-dot"]="rbxassetid://82947033619201",
  ["circle-ellipsis"]="rbxassetid://91687150884779",
  ["circle-equal"]="rbxassetid://95133963751438",
  ["circle-fading-arrow-up"]="rbxassetid://104648212910336",
  ["circle-fading-plus"]="rbxassetid://91847890443490",
  ["circle-gauge"]="rbxassetid://108157549473765",
  ["circle-minus"]="rbxassetid://133556159576809",
  ["circle-off"]="rbxassetid://97923456918886",
  ["circle-parking-off"]="rbxassetid://128369410981252",
  ["circle-parking"]="rbxassetid://124034962915196",
  ["circle-pause"]="rbxassetid://139337739700879",
  ["circle-percent"]="rbxassetid://133311912860256",
  ["circle-play"]="rbxassetid://120408917249739",
  ["circle-plus"]="rbxassetid://113157136350384",
  ["circle-pound-sterling"]="rbxassetid://105476153083828",
  ["circle-power"]="rbxassetid://140676030155098",
  ["circle-question-mark"]="rbxassetid://97516698664325",
  ["circle-slash-2"]="rbxassetid://136766902186549",
  ["circle-slash"]="rbxassetid://125206439913049",
  ["circle-small"]="rbxassetid://73685402843600",
  ["circle-star"]="rbxassetid://120318414957104",
  ["circle-stop"]="rbxassetid://87400503942659",
  ["circle-user-round"]="rbxassetid://95489465399880",
  ["circle-user"]="rbxassetid://136220511671311",
  ["circle-x"]="rbxassetid://76821953846248",
  ["circle"]="rbxassetid://130359823580534",
  ["circuit-board"]="rbxassetid://107695264369312",
  ["citrus"]="rbxassetid://139018222976433",
  ["clapperboard"]="rbxassetid://132660667070200",
  ["clipboard-check"]="rbxassetid://92649798577170",
  ["clipboard-clock"]="rbxassetid://123957515687745",
  ["clipboard-copy"]="rbxassetid://125851897718493",
  ["clipboard-list"]="rbxassetid://96460215958908",
  ["clipboard-minus"]="rbxassetid://107968008485671",
  ["clipboard-paste"]="rbxassetid://74382068849983",
  ["clipboard-pen-line"]="rbxassetid://77711589791615",
  ["clipboard-pen"]="rbxassetid://75290966822953",
  ["clipboard-plus"]="rbxassetid://134285318675662",
  ["clipboard-type"]="rbxassetid://89949374318028",
  ["clipboard-x"]="rbxassetid://102222456890103",
  ["clipboard"]="rbxassetid://89601995828423",
  ["clock-1"]="rbxassetid://129363225422045",
  ["clock-10"]="rbxassetid://104332695855541",
  ["clock-11"]="rbxassetid://119023205186105",
  ["clock-12"]="rbxassetid://117789618723068",
  ["clock-2"]="rbxassetid://134710777209413",
  ["clock-3"]="rbxassetid://136385631189327",
  ["clock-4"]="rbxassetid://121808839832144",
  ["clock-5"]="rbxassetid://85082019959457",
  ["clock-6"]="rbxassetid://71009733505593",
  ["clock-7"]="rbxassetid://103111188546225",
  ["clock-8"]="rbxassetid://110059272125337",
  ["clock-9"]="rbxassetid://77610027126437",
  ["clock-alert"]="rbxassetid://97157344465162",
  ["clock-arrow-down"]="rbxassetid://92349314416042",
  ["clock-arrow-up"]="rbxassetid://111484286332629",
  ["clock-check"]="rbxassetid://85231630218857",
  ["clock-fading"]="rbxassetid://93205297285245",
  ["clock-plus"]="rbxassetid://93367709263150",
  ["clock"]="rbxassetid://121808839832144",
  ["closed-caption"]="rbxassetid://99832644030788",
  ["cloud-alert"]="rbxassetid://91967273658626",
  ["cloud-check"]="rbxassetid://97318598202432",
  ["cloud-cog"]="rbxassetid://96497764065749",
  ["cloud-download"]="rbxassetid://121435581993566",
  ["cloud-drizzle"]="rbxassetid://139525315752605",
  ["cloud-fog"]="rbxassetid://76650233148776",
  ["cloud-hail"]="rbxassetid://72320462748242",
  ["cloud-lightning"]="rbxassetid://133517088924849",
  ["cloud-moon-rain"]="rbxassetid://127667837827018",
  ["cloud-moon"]="rbxassetid://71938114737914",
  ["cloud-off"]="rbxassetid://131907154501444",
  ["cloud-rain-wind"]="rbxassetid://107414583736721",
  ["cloud-rain"]="rbxassetid://105547081967408",
  ["cloud-snow"]="rbxassetid://72307126270226",
  ["cloud-sun-rain"]="rbxassetid://99041604425705",
  ["cloud-sun"]="rbxassetid://86114208148727",
  ["cloud-upload"]="rbxassetid://93307473217005",
  ["cloud"]="rbxassetid://121226497050352",
  ["cloudy"]="rbxassetid://105360479023346",
  ["clover"]="rbxassetid://74925550436750",
  ["club"]="rbxassetid://108490365816628",
  ["code-xml"]="rbxassetid://130150477351734",
  ["code"]="rbxassetid://107380207681249",
  ["codepen"]="rbxassetid://135643965971885",
  ["codesandbox"]="rbxassetid://106911852964823",
  ["coffee"]="rbxassetid://106864403231093",
  ["cog"]="rbxassetid://116544501716299",
  ["coins"]="rbxassetid://116510979641930",
  ["columns-2"]="rbxassetid://113004100221850",
  ["columns-3-cog"]="rbxassetid://121589691981064",
  ["columns-3"]="rbxassetid://115223357399375",
  ["columns-4"]="rbxassetid://130807991968419",
  ["combine"]="rbxassetid://79908476334048",
  ["command"]="rbxassetid://93648221906330",
  ["compass"]="rbxassetid://115123411028382",
  ["component"]="rbxassetid://110027788875080",
  ["computer"]="rbxassetid://77480056459407",
  ["concierge-bell"]="rbxassetid://140384259310436",
  ["cone"]="rbxassetid://97759550688437",
  ["construction"]="rbxassetid://106539489968173",
  ["contact-round"]="rbxassetid://71907624112229",
  ["contact"]="rbxassetid://75868297719012",
  ["container"]="rbxassetid://91507237573499",
  ["contrast"]="rbxassetid://112796643981497",
  ["cookie"]="rbxassetid://73159504540002",
  ["cooking-pot"]="rbxassetid://94959783129799",
  ["copy-check"]="rbxassetid://91177247988892",
  ["copy-minus"]="rbxassetid://109524509933035",
  ["copy-plus"]="rbxassetid://113618379616952",
  ["copy-slash"]="rbxassetid://93805787810390",
  ["copy-x"]="rbxassetid://106557557978061",
  ["copy"]="rbxassetid://78979572434545",
  ["copyleft"]="rbxassetid://78559055698593",
  ["copyright"]="rbxassetid://129433635747111",
  ["corner-down-left"]="rbxassetid://90473561177832",
  ["corner-down-right"]="rbxassetid://86512767702085",
  ["corner-left-down"]="rbxassetid://139876989150630",
  ["corner-left-up"]="rbxassetid://126228268096099",
  ["corner-right-down"]="rbxassetid://89237035551302",
  ["corner-right-up"]="rbxassetid://112851237026705",
  ["corner-up-left"]="rbxassetid://84669279763024",
  ["corner-up-right"]="rbxassetid://115099889693145",
  ["cpu"]="rbxassetid://77549309870247",
  ["creative-commons"]="rbxassetid://90408210735312",
  ["credit-card"]="rbxassetid://99163352872346",
  ["croissant"]="rbxassetid://130710485559420",
  ["crop"]="rbxassetid://116344601101413",
  ["cross"]="rbxassetid://101833377863588",
  ["crosshair"]="rbxassetid://134242818164054",
  ["crown"]="rbxassetid://127843403295538",
  ["cuboid"]="rbxassetid://75618807946111",
  ["cup-soda"]="rbxassetid://121098640829562",
  ["currency"]="rbxassetid://90551250119972",
  ["cylinder"]="rbxassetid://90569677179169",
  ["dam"]="rbxassetid://76874486231393",
  ["database-backup"]="rbxassetid://103403210984699",
  ["database-zap"]="rbxassetid://131199921258418",
  ["database"]="rbxassetid://126791525623846",
  ["decimals-arrow-left"]="rbxassetid://120198500638749",
  ["decimals-arrow-right"]="rbxassetid://118263047146797",
  ["delete"]="rbxassetid://126279426372342",
  ["dessert"]="rbxassetid://71508133278830",
  ["diameter"]="rbxassetid://97429051503783",
  ["diamond-minus"]="rbxassetid://128989071438290",
  ["diamond-percent"]="rbxassetid://107717860105959",
  ["diamond-plus"]="rbxassetid://134701163723675",
  ["diamond"]="rbxassetid://105846996304890",
  ["dice-1"]="rbxassetid://112650149591038",
  ["dice-2"]="rbxassetid://112278274566793",
  ["dice-3"]="rbxassetid://118526270626312",
  ["dice-4"]="rbxassetid://113365650364004",
  ["dice-5"]="rbxassetid://72768312430593",
  ["dice-6"]="rbxassetid://85376239182543",
  ["dices"]="rbxassetid://81268120302865",
  ["diff"]="rbxassetid://135052708609715",
  ["disc-2"]="rbxassetid://91419420404185",
  ["disc-3"]="rbxassetid://135470554736048",
  ["disc-album"]="rbxassetid://74693460404344",
  ["disc"]="rbxassetid://101908120120777",
  ["divide"]="rbxassetid://136678191878278",
  ["dna-off"]="rbxassetid://89612426361540",
  ["dna"]="rbxassetid://74007982981741",
  ["dock"]="rbxassetid://121997427160252",
  ["dog"]="rbxassetid://71920105558570",
  ["dollar-sign"]="rbxassetid://127320961224019",
  ["donut"]="rbxassetid://72204922742657",
  ["door-closed-locked"]="rbxassetid://74027613267551",
  ["door-closed"]="rbxassetid://136249099949073",
  ["door-open"]="rbxassetid://91306356501736",
  ["dot"]="rbxassetid://137321056643916",
  ["download"]="rbxassetid://134814648082393",
  ["drafting-compass"]="rbxassetid://99701976182841",
  ["drama"]="rbxassetid://110297795801577",
  ["dribbble"]="rbxassetid://80231809663849",
  ["drill"]="rbxassetid://108644821412796",
  ["drone"]="rbxassetid://117299095794783",
  ["droplet-off"]="rbxassetid://119365002225172",
  ["droplet"]="rbxassetid://100597455015098",
  ["droplets"]="rbxassetid://140111846025180",
  ["drum"]="rbxassetid://136979060344890",
  ["drumstick"]="rbxassetid://104662462521709",
  ["dumbbell"]="rbxassetid://80277236776212",
  ["ear-off"]="rbxassetid://87421916192807",
  ["ear"]="rbxassetid://121894949934209",
  ["earth-lock"]="rbxassetid://88814147073745",
  ["earth"]="rbxassetid://76231597751076",
  ["eclipse"]="rbxassetid://114829622118222",
  ["egg-fried"]="rbxassetid://90622538210545",
  ["egg-off"]="rbxassetid://92288321309285",
  ["egg"]="rbxassetid://117851493400222",
  ["ellipsis-vertical"]="rbxassetid://117978708573781",
  ["ellipsis"]="rbxassetid://140019550645825",
  ["equal-approximately"]="rbxassetid://105382689698323",
  ["equal-not"]="rbxassetid://76864449458032",
  ["equal"]="rbxassetid://123467780715624",
  ["eraser"]="rbxassetid://133957773112410",
  ["ethernet-port"]="rbxassetid://75391715149314",
  ["euro"]="rbxassetid://72229646524456",
  ["ev-charger"]="rbxassetid://97906158859623",
  ["expand"]="rbxassetid://137492887754537",
  ["external-link"]="rbxassetid://129331830773832",
  ["eye-closed"]="rbxassetid://111063268625789",
  ["eye-off"]="rbxassetid://135928786788378",
  ["eye"]="rbxassetid://100033680381365",
  ["facebook"]="rbxassetid://72098528632192",
  ["factory"]="rbxassetid://102170024318039",
  ["fan"]="rbxassetid://78391400440696",
  ["fast-forward"]="rbxassetid://121615540167909",
  ["feather"]="rbxassetid://91872927606406",
  ["fence"]="rbxassetid://123451565578029",
  ["ferris-wheel"]="rbxassetid://79729205796176",
  ["figma"]="rbxassetid://134182122852301",
  ["file-archive"]="rbxassetid://77018106869967",
  ["file-axis-3d"]="rbxassetid://133912328009885",
  ["file-badge"]="rbxassetid://74564895394477",
  ["file-box"]="rbxassetid://119264004071690",
  ["file-braces-corner"]="rbxassetid://77253337986109",
  ["file-braces"]="rbxassetid://95314128621234",
  ["file-chart-column-increasing"]="rbxassetid://134449481172067",
  ["file-chart-column"]="rbxassetid://82048481252560",
  ["file-chart-line"]="rbxassetid://71954360551345",
  ["file-chart-pie"]="rbxassetid://81072193564497",
  ["file-check-corner"]="rbxassetid://76295552859171",
  ["file-check"]="rbxassetid://82604001452455",
  ["file-clock"]="rbxassetid://102325208830990",
  ["file-code-corner"]="rbxassetid://78293841184371",
  ["file-code"]="rbxassetid://130978036895504",
  ["file-cog"]="rbxassetid://101385347151368",
  ["file-diff"]="rbxassetid://96147216772241",
  ["file-digit"]="rbxassetid://89220220354580",
  ["file-down"]="rbxassetid://120650154178290",
  ["file-exclamation-point"]="rbxassetid://102821865889635",
  ["file-headphone"]="rbxassetid://100533735901986",
  ["file-heart"]="rbxassetid://132214916401696",
  ["file-image"]="rbxassetid://123334057511782",
  ["file-input"]="rbxassetid://124728604166044",
  ["file-key"]="rbxassetid://118790255921100",
  ["file-lock"]="rbxassetid://72170228691242",
  ["file-minus-corner"]="rbxassetid://119263271735124",
  ["file-minus"]="rbxassetid://111014798459222",
  ["file-music"]="rbxassetid://134948051536671",
  ["file-output"]="rbxassetid://92146832572911",
  ["file-pen-line"]="rbxassetid://104622936345006",
  ["file-pen"]="rbxassetid://79556179730240",
  ["file-play"]="rbxassetid://89006821567838",
  ["file-plus-corner"]="rbxassetid://76544604043974",
  ["file-plus"]="rbxassetid://78881710800060",
  ["file-question-mark"]="rbxassetid://127617422859576",
  ["file-scan"]="rbxassetid://129480105228213",
  ["file-search-corner"]="rbxassetid://90974165234008",
  ["file-search"]="rbxassetid://97780235974933",
  ["file-signal"]="rbxassetid://122070252538165",
  ["file-sliders"]="rbxassetid://85787771732439",
  ["file-spreadsheet"]="rbxassetid://134501869359270",
  ["file-stack"]="rbxassetid://138929929862605",
  ["file-symlink"]="rbxassetid://91865722036510",
  ["file-terminal"]="rbxassetid://116757454755476",
  ["file-text"]="rbxassetid://90496405707281",
  ["file-type-corner"]="rbxassetid://124902230275209",
  ["file-type"]="rbxassetid://115272552799361",
  ["file-up"]="rbxassetid://131173039312748",
  ["file-user"]="rbxassetid://99552018455009",
  ["file-video-camera"]="rbxassetid://81719056173960",
  ["file-volume"]="rbxassetid://111264764438958",
  ["file-x-corner"]="rbxassetid://87554136773609",
  ["file-x"]="rbxassetid://107333775515154",
  ["file"]="rbxassetid://74748492079329",
  ["files"]="rbxassetid://102806336233202",
  ["film"]="rbxassetid://120978945609706",
  ["fingerprint"]="rbxassetid://112173305232811",
  ["fire-extinguisher"]="rbxassetid://111643493006960",
  ["fish-off"]="rbxassetid://89756724887508",
  ["fish-symbol"]="rbxassetid://118475177681618",
  ["fish"]="rbxassetid://124360663785796",
  ["flag-off"]="rbxassetid://112944528856799",
  ["flag-triangle-left"]="rbxassetid://88045221285272",
  ["flag-triangle-right"]="rbxassetid://108292480304566",
  ["flag"]="rbxassetid://78183383236196",
  ["flame-kindling"]="rbxassetid://139728976917928",
  ["flame"]="rbxassetid://98218034436456",
  ["flashlight-off"]="rbxassetid://79780362871740",
  ["flashlight"]="rbxassetid://100286985600444",
  ["flask-conical-off"]="rbxassetid://112597970025298",
  ["flask-conical"]="rbxassetid://128406680901165",
  ["flask-round"]="rbxassetid://127508287324940",
  ["flip-horizontal-2"]="rbxassetid://103726993598186",
  ["flip-horizontal"]="rbxassetid://122937530107837",
  ["flip-vertical-2"]="rbxassetid://103836358956328",
  ["flip-vertical"]="rbxassetid://108003917346888",
  ["flower-2"]="rbxassetid://72934574245145",
  ["flower"]="rbxassetid://86129438272762",
  ["focus"]="rbxassetid://87493973153317",
  ["fold-horizontal"]="rbxassetid://92835712442240",
  ["fold-vertical"]="rbxassetid://108873727253656",
  ["folder-archive"]="rbxassetid://97312009460206",
  ["folder-check"]="rbxassetid://128492920904557",
  ["folder-clock"]="rbxassetid://111964836738545",
  ["folder-closed"]="rbxassetid://118286209350843",
  ["folder-code"]="rbxassetid://70624096349370",
  ["folder-cog"]="rbxassetid://85299519462846",
  ["folder-dot"]="rbxassetid://138687772725278",
  ["folder-down"]="rbxassetid://118044108459225",
  ["folder-git-2"]="rbxassetid://101394054141166",
  ["folder-git"]="rbxassetid://121885778095158",
  ["folder-heart"]="rbxassetid://79104747211105",
  ["folder-input"]="rbxassetid://90699920697871",
  ["folder-kanban"]="rbxassetid://78313285104072",
  ["folder-key"]="rbxassetid://85270407596791",
  ["folder-lock"]="rbxassetid://119201572260567",
  ["folder-minus"]="rbxassetid://85648718999010",
  ["folder-open-dot"]="rbxassetid://74741494767354",
  ["folder-open"]="rbxassetid://76018996254888",
  ["folder-output"]="rbxassetid://101532447937612",
  ["folder-pen"]="rbxassetid://112770491173911",
  ["folder-plus"]="rbxassetid://91865663406119",
  ["folder-root"]="rbxassetid://103333751154693",
  ["folder-search-2"]="rbxassetid://71276453442655",
  ["folder-search"]="rbxassetid://110568075123861",
  ["folder-symlink"]="rbxassetid://127485747227189",
  ["folder-sync"]="rbxassetid://91544602659796",
  ["folder-tree"]="rbxassetid://85577554337861",
  ["folder-up"]="rbxassetid://72008269765857",
  ["folder-x"]="rbxassetid://91699618247635",
  ["folder"]="rbxassetid://80846616596607",
  ["folders"]="rbxassetid://110351216219061",
  ["footprints"]="rbxassetid://139192589041315",
  ["forklift"]="rbxassetid://72030930983101",
  ["forward"]="rbxassetid://97545944739523",
  ["frame"]="rbxassetid://109080612832751",
  ["framer"]="rbxassetid://108384807262391",
  ["frown"]="rbxassetid://124407301067982",
  ["fuel"]="rbxassetid://106447647274511",
  ["fullscreen"]="rbxassetid://77793665526178",
  ["funnel-plus"]="rbxassetid://100780233821928",
  ["funnel-x"]="rbxassetid://70984385812555",
  ["funnel"]="rbxassetid://108829540827529",
  ["gallery-horizontal-end"]="rbxassetid://74672430161161",
  ["gallery-horizontal"]="rbxassetid://80004001442122",
  ["gallery-thumbnails"]="rbxassetid://136219289862706",
  ["gallery-vertical-end"]="rbxassetid://106461402088317",
  ["gallery-vertical"]="rbxassetid://119299431466725",
  ["gamepad-2"]="rbxassetid://92483947987410",
  ["gamepad-directional"]="rbxassetid://84342305212226",
  ["gamepad"]="rbxassetid://121607283959010",
  ["gauge"]="rbxassetid://110273524101447",
  ["gavel"]="rbxassetid://78952298198456",
  ["gem"]="rbxassetid://112904952151156",
  ["georgian-lari"]="rbxassetid://98084432591687",
  ["ghost"]="rbxassetid://113822048130017",
  ["gift"]="rbxassetid://109855212076373",
  ["git-branch-minus"]="rbxassetid://97385010649411",
  ["git-branch-plus"]="rbxassetid://125944221134316",
  ["git-branch"]="rbxassetid://90490195516649",
  ["git-commit-horizontal"]="rbxassetid://133646041800147",
  ["git-commit-vertical"]="rbxassetid://122098032990350",
  ["git-compare-arrows"]="rbxassetid://84874426520216",
  ["git-compare"]="rbxassetid://91945124438792",
  ["git-fork"]="rbxassetid://89954992404765",
  ["git-graph"]="rbxassetid://86166832019304",
  ["git-merge"]="rbxassetid://131833355158059",
  ["git-pull-request-arrow"]="rbxassetid://94507974577439",
  ["git-pull-request-closed"]="rbxassetid://78070600389091",
  ["git-pull-request-create-arrow"]="rbxassetid://127422677061091",
  ["git-pull-request-create"]="rbxassetid://105929577383926",
  ["git-pull-request-draft"]="rbxassetid://76173459869943",
  ["git-pull-request"]="rbxassetid://138463010991471",
  ["github"]="rbxassetid://120349554354380",
  ["gitlab"]="rbxassetid://114054627192933",
  ["glass-water"]="rbxassetid://115526102400988",
  ["glasses"]="rbxassetid://87936407455373",
  ["globe-lock"]="rbxassetid://134065526704402",
  ["globe"]="rbxassetid://114238209622913",
  ["goal"]="rbxassetid://120517954878160",
  ["gpu"]="rbxassetid://95577823614219",
  ["graduation-cap"]="rbxassetid://93771896340220",
  ["grape"]="rbxassetid://134760640415561",
  ["grid-2x2-check"]="rbxassetid://138468840220821",
  ["grid-2x2-plus"]="rbxassetid://91811610580247",
  ["grid-2x2-x"]="rbxassetid://72407303981388",
  ["grid-2x2"]="rbxassetid://99050491897640",
  ["grid-3x2"]="rbxassetid://95528684210010",
  ["grid-3x3"]="rbxassetid://70419024781206",
  ["grip-horizontal"]="rbxassetid://136255899715930",
  ["grip-vertical"]="rbxassetid://137183678565296",
  ["grip"]="rbxassetid://109058783556768",
  ["group"]="rbxassetid://107643418926671",
  ["guitar"]="rbxassetid://75915531867926",
  ["ham"]="rbxassetid://74465607934635",
  ["hamburger"]="rbxassetid://93086916815495",
  ["hammer"]="rbxassetid://83545120140895",
  ["hand-coins"]="rbxassetid://126990543175462",
  ["hand-fist"]="rbxassetid://83341608917591",
  ["hand-grab"]="rbxassetid://88867162163985",
  ["hand-heart"]="rbxassetid://117507367668412",
  ["hand-helping"]="rbxassetid://89897738419446",
  ["hand-metal"]="rbxassetid://113619498548713",
  ["hand-platter"]="rbxassetid://88594727743168",
  ["hand"]="rbxassetid://130703864968637",
  ["handbag"]="rbxassetid://135675846264061",
  ["handshake"]="rbxassetid://78442115255814",
  ["hard-drive-download"]="rbxassetid://73913801230614",
  ["hard-drive-upload"]="rbxassetid://85762133615118",
  ["hard-drive"]="rbxassetid://88183305858463",
  ["hard-hat"]="rbxassetid://128050846767382",
  ["hash"]="rbxassetid://82890331678520",
  ["hat-glasses"]="rbxassetid://101165538224815",
  ["haze"]="rbxassetid://108857561768901",
  ["hdmi-port"]="rbxassetid://103693661037020",
  ["heading-1"]="rbxassetid://118129315662110",
  ["heading-2"]="rbxassetid://110209069670094",
  ["heading-3"]="rbxassetid://90267885237062",
  ["heading-4"]="rbxassetid://129625620307602",
  ["heading-5"]="rbxassetid://120386663181267",
  ["heading-6"]="rbxassetid://90959079775093",
  ["heading"]="rbxassetid://129254312067735",
  ["headphone-off"]="rbxassetid://85038251615641",
  ["headphones"]="rbxassetid://118833729589183",
  ["headset"]="rbxassetid://129269236787694",
  ["heart-crack"]="rbxassetid://110987638564119",
  ["heart-handshake"]="rbxassetid://111483078692002",
  ["heart-minus"]="rbxassetid://96827380163326",
  ["heart-off"]="rbxassetid://89748414415617",
  ["heart-plus"]="rbxassetid://94877796283249",
  ["heart-pulse"]="rbxassetid://129352925579546",
  ["heart"]="rbxassetid://116559368303288",
  ["heater"]="rbxassetid://140478466880916",
  ["helicopter"]="rbxassetid://111557171735930",
  ["hexagon"]="rbxassetid://127592089339199",
  ["highlighter"]="rbxassetid://77411555641113",
  ["history"]="rbxassetid://123980022019922",
  ["hop-off"]="rbxassetid://103386036934034",
  ["hop"]="rbxassetid://82778923997672",
  ["hospital"]="rbxassetid://105868763850707",
  ["hotel"]="rbxassetid://132283390859718",
  ["hourglass"]="rbxassetid://86160434939203",
  ["house-heart"]="rbxassetid://136054771868597",
  ["house-plug"]="rbxassetid://71438263712075",
  ["house-plus"]="rbxassetid://118495165208309",
  ["house-wifi"]="rbxassetid://126495519725698",
  ["house"]="rbxassetid://98755624629571",
  ["ice-cream-bowl"]="rbxassetid://124867218454386",
  ["ice-cream-cone"]="rbxassetid://90751397288639",
  ["id-card-lanyard"]="rbxassetid://90761480469224",
  ["id-card"]="rbxassetid://75354294622640",
  ["image-down"]="rbxassetid://78972295741235",
  ["image-minus"]="rbxassetid://101066016918565",
  ["image-off"]="rbxassetid://81934811700938",
  ["image-play"]="rbxassetid://129501806784210",
  ["image-plus"]="rbxassetid://70391970623917",
  ["image-up"]="rbxassetid://126610009605241",
  ["image-upscale"]="rbxassetid://106963545024679",
  ["images"]="rbxassetid://79350649395557",
  ["import"]="rbxassetid://116545008906029",
  ["inbox"]="rbxassetid://112591360302868",
  ["indian-rupee"]="rbxassetid://113038778381805",
  ["infinity"]="rbxassetid://98083086936965",
  ["info"]="rbxassetid://124560466474914",
  ["inspection-panel"]="rbxassetid://70905313146088",
  ["instagram"]="rbxassetid://119864798614855",
  ["italic"]="rbxassetid://96220378864282",
  ["iteration-ccw"]="rbxassetid://140221832794083",
  ["iteration-cw"]="rbxassetid://95534489554662",
  ["japanese-yen"]="rbxassetid://106362863465813",
  ["joystick"]="rbxassetid://99416790224739",
  ["kanban"]="rbxassetid://125934100055431",
  ["kayak"]="rbxassetid://136107544609389",
  ["key-round"]="rbxassetid://83619031955390",
  ["key-square"]="rbxassetid://94621420033649",
  ["key"]="rbxassetid://96510194465420",
  ["keyboard-music"]="rbxassetid://121058541758636",
  ["keyboard-off"]="rbxassetid://92466375369772",
  ["keyboard"]="rbxassetid://121474456068237",
  ["lamp-ceiling"]="rbxassetid://80032758469141",
  ["lamp-desk"]="rbxassetid://85290686983238",
  ["lamp-floor"]="rbxassetid://104585881375892",
  ["lamp-wall-down"]="rbxassetid://91271394132073",
  ["lamp-wall-up"]="rbxassetid://132141464337445",
  ["lamp"]="rbxassetid://110730830653382",
  ["land-plot"]="rbxassetid://96449039620294",
  ["landmark"]="rbxassetid://76885079756393",
  ["languages"]="rbxassetid://90816903776498",
  ["laptop-minimal-check"]="rbxassetid://114352019833865",
  ["laptop-minimal"]="rbxassetid://136705765566068",
  ["laptop"]="rbxassetid://111387063244975",
  ["lasso-select"]="rbxassetid://105609719912753",
  ["lasso"]="rbxassetid://121072936884007",
  ["laugh"]="rbxassetid://104491311361166",
  ["layers-2"]="rbxassetid://70536710516357",
  ["layers"]="rbxassetid://81973586053257",
  ["layout-dashboard"]="rbxassetid://139929981863901",
  ["layout-grid"]="rbxassetid://81344910161871",
  ["layout-list"]="rbxassetid://87462136296578",
  ["layout-panel-left"]="rbxassetid://125092469751491",
  ["layout-panel-top"]="rbxassetid://91943941515944",
  ["layout-template"]="rbxassetid://115564446417985",
  ["leaf"]="rbxassetid://119951075637174",
  ["leafy-green"]="rbxassetid://105146290493154",
  ["lectern"]="rbxassetid://106166425183862",
  ["library-big"]="rbxassetid://106794530191412",
  ["library"]="rbxassetid://114334671982047",
  ["life-buoy"]="rbxassetid://81168450671956",
  ["ligature"]="rbxassetid://111397873269411",
  ["lightbulb-off"]="rbxassetid://83795722296178",
  ["lightbulb"]="rbxassetid://103871245626488",
  ["line-squiggle"]="rbxassetid://109555164424447",
  ["link-2-off"]="rbxassetid://76885956296867",
  ["link-2"]="rbxassetid://86072351557466",
  ["link"]="rbxassetid://131607023382430",
  ["linkedin"]="rbxassetid://132842789255788",
  ["list-check"]="rbxassetid://72374358471156",
  ["list-checks"]="rbxassetid://99809353635593",
  ["list-chevrons-down-up"]="rbxassetid://137409641500711",
  ["list-chevrons-up-down"]="rbxassetid://81825351389084",
  ["list-collapse"]="rbxassetid://124505247702401",
  ["list-end"]="rbxassetid://77650610048119",
  ["list-filter-plus"]="rbxassetid://96385120752336",
  ["list-filter"]="rbxassetid://103321376129527",
  ["list-indent-decrease"]="rbxassetid://137879979228193",
  ["list-indent-increase"]="rbxassetid://79051053161201",
  ["list-minus"]="rbxassetid://138507965142671",
  ["list-music"]="rbxassetid://126380635781840",
  ["list-ordered"]="rbxassetid://83212528113913",
  ["list-plus"]="rbxassetid://112384738137814",
  ["list-restart"]="rbxassetid://91703153577421",
  ["list-start"]="rbxassetid://84828348299727",
  ["list-todo"]="rbxassetid://132980603752108",
  ["list-tree"]="rbxassetid://97685396239010",
  ["list-video"]="rbxassetid://93648525452489",
  ["list-x"]="rbxassetid://113025303988861",
  ["list"]="rbxassetid://113179976918783",
  ["loader-circle"]="rbxassetid://116535712789945",
  ["loader-pinwheel"]="rbxassetid://108513357940900",
  ["loader"]="rbxassetid://78408734580845",
  ["locate-fixed"]="rbxassetid://137367361548433",
  ["locate-off"]="rbxassetid://73729216338137",
  ["locate"]="rbxassetid://84467676590391",
  ["lock-keyhole-open"]="rbxassetid://110863509313073",
  ["lock-keyhole"]="rbxassetid://78672912777756",
  ["lock-open"]="rbxassetid://93597915325122",
  ["lock"]="rbxassetid://134724289526879",
  ["log-in"]="rbxassetid://103768533135201",
  ["log-out"]="rbxassetid://84895399304975",
  ["logs"]="rbxassetid://89772091251787",
  ["lollipop"]="rbxassetid://84681611583044",
  ["luggage"]="rbxassetid://76619236486400",
  ["magnet"]="rbxassetid://135162361226972",
  ["mail-check"]="rbxassetid://86921536259917",
  ["mail-minus"]="rbxassetid://81989813236553",
  ["mail-open"]="rbxassetid://122785416858638",
  ["mail-plus"]="rbxassetid://104886401588341",
  ["mail-question-mark"]="rbxassetid://126540170949819",
  ["mail-search"]="rbxassetid://135616173775287",
  ["mail-warning"]="rbxassetid://81495303676089",
  ["mail-x"]="rbxassetid://74607841705644",
  ["mail"]="rbxassetid://103945161245599",
  ["mailbox"]="rbxassetid://82765503320335",
  ["mails"]="rbxassetid://90673453450080",
  ["map-minus"]="rbxassetid://129525760577747",
  ["map-pin-check-inside"]="rbxassetid://107130529843809",
  ["map-pin-check"]="rbxassetid://118110914690154",
  ["map-pin-house"]="rbxassetid://80546885029816",
  ["map-pin-minus-inside"]="rbxassetid://79005529692964",
  ["map-pin-minus"]="rbxassetid://74518762643623",
  ["map-pin-off"]="rbxassetid://82474689391020",
  ["map-pin-pen"]="rbxassetid://113515395277504",
  ["map-pin-plus-inside"]="rbxassetid://134639656514430",
  ["map-pin-plus"]="rbxassetid://91875228967029",
  ["map-pin-x-inside"]="rbxassetid://126235934252379",
  ["map-pin-x"]="rbxassetid://101085273547316",
  ["map-pin"]="rbxassetid://84279202219901",
  ["map-pinned"]="rbxassetid://103963788475034",
  ["map-plus"]="rbxassetid://129388826743495",
  ["map"]="rbxassetid://95107167260947",
  ["mars-stroke"]="rbxassetid://131973193186828",
  ["mars"]="rbxassetid://111287112372511",
  ["martini"]="rbxassetid://82977695401058",
  ["maximize-2"]="rbxassetid://73085922906397",
  ["maximize"]="rbxassetid://76045941763188",
  ["medal"]="rbxassetid://79016002264450",
  ["megaphone-off"]="rbxassetid://124280774193935",
  ["megaphone"]="rbxassetid://118759541854879",
  ["meh"]="rbxassetid://132197867028557",
  ["memory-stick"]="rbxassetid://93212591343119",
  ["menu"]="rbxassetid://77021539815611",
  ["merge"]="rbxassetid://126201866476775",
  ["message-circle-code"]="rbxassetid://112865244991651",
  ["message-circle-dashed"]="rbxassetid://81525157881897",
  ["message-circle-heart"]="rbxassetid://101990756073677",
  ["message-circle-more"]="rbxassetid://92856823884663",
  ["message-circle-off"]="rbxassetid://134955643890328",
  ["message-circle-plus"]="rbxassetid://106562979649273",
  ["message-circle-question-mark"]="rbxassetid://107700302759934",
  ["message-circle-reply"]="rbxassetid://137071749508334",
  ["message-circle-warning"]="rbxassetid://119020096067894",
  ["message-circle-x"]="rbxassetid://126843387725536",
  ["message-circle"]="rbxassetid://127255077587058",
  ["message-square-code"]="rbxassetid://110968863152123",
  ["message-square-dashed"]="rbxassetid://107653455516238",
  ["message-square-diff"]="rbxassetid://75472190472625",
  ["message-square-dot"]="rbxassetid://127806382463916",
  ["message-square-heart"]="rbxassetid://75612811742074",
  ["message-square-lock"]="rbxassetid://81268215619563",
  ["message-square-more"]="rbxassetid://120139782405970",
  ["message-square-off"]="rbxassetid://99961019005789",
  ["message-square-plus"]="rbxassetid://76934450256199",
  ["message-square-quote"]="rbxassetid://116670768629340",
  ["message-square-reply"]="rbxassetid://130985622754637",
  ["message-square-share"]="rbxassetid://131017005324026",
  ["message-square-text"]="rbxassetid://94899503194205",
  ["message-square-warning"]="rbxassetid://138432903962261",
  ["message-square-x"]="rbxassetid://137285463279462",
  ["message-square"]="rbxassetid://83881670383280",
  ["messages-square"]="rbxassetid://97532166733358",
  ["mic-off"]="rbxassetid://82123034444822",
  ["mic-vocal"]="rbxassetid://99082286164362",
  ["mic"]="rbxassetid://89640799126523",
  ["microchip"]="rbxassetid://73937907669903",
  ["microscope"]="rbxassetid://116875530102782",
  ["microwave"]="rbxassetid://108411735353008",
  ["milestone"]="rbxassetid://101618292325920",
  ["milk-off"]="rbxassetid://72388480962742",
  ["milk"]="rbxassetid://96221903896918",
  ["minimize-2"]="rbxassetid://116269596042539",
  ["minimize"]="rbxassetid://121304296213645",
  ["minus"]="rbxassetid://118026365011536",
  ["monitor-check"]="rbxassetid://86651948439229",
  ["monitor-cloud"]="rbxassetid://85931096038318",
  ["monitor-cog"]="rbxassetid://94345128715799",
  ["monitor-dot"]="rbxassetid://130394010063680",
  ["monitor-down"]="rbxassetid://97466933743423",
  ["monitor-off"]="rbxassetid://74395526657953",
  ["monitor-pause"]="rbxassetid://76002184067562",
  ["monitor-play"]="rbxassetid://133018824306217",
  ["monitor-smartphone"]="rbxassetid://84335680433378",
  ["monitor-speaker"]="rbxassetid://81744810060380",
  ["monitor-stop"]="rbxassetid://98708958984757",
  ["monitor-up"]="rbxassetid://96035360858377",
  ["monitor-x"]="rbxassetid://126265210441423",
  ["monitor"]="rbxassetid://72664649203050",
  ["moon-star"]="rbxassetid://82782200506348",
  ["moon"]="rbxassetid://83380517901735",
  ["motorbike"]="rbxassetid://94580787368233",
  ["mountain-snow"]="rbxassetid://105315495740588",
  ["mountain"]="rbxassetid://73269957566415",
  ["mouse-off"]="rbxassetid://75267871697595",
  ["mouse-pointer-2-off"]="rbxassetid://104701076865632",
  ["mouse-pointer-2"]="rbxassetid://117093892862228",
  ["mouse-pointer-ban"]="rbxassetid://106849413057133",
  ["mouse-pointer-click"]="rbxassetid://107150227368485",
  ["mouse-pointer"]="rbxassetid://72322454962935",
  ["mouse"]="rbxassetid://73096068864710",
  ["move-3d"]="rbxassetid://103365982054003",
  ["move-diagonal-2"]="rbxassetid://117298577948096",
  ["move-diagonal"]="rbxassetid://101433481954184",
  ["move-down-left"]="rbxassetid://102819433534567",
  ["move-down-right"]="rbxassetid://101479760041877",
  ["move-down"]="rbxassetid://70510115135583",
  ["move-horizontal"]="rbxassetid://88513523439149",
  ["move-left"]="rbxassetid://137614740247980",
  ["move-right"]="rbxassetid://132455779472989",
  ["move-up-left"]="rbxassetid://139079815540148",
  ["move-up-right"]="rbxassetid://105885140592646",
  ["move-up"]="rbxassetid://84505444262658",
  ["move-vertical"]="rbxassetid://86234730730899",
  ["move"]="rbxassetid://116138709011735",
  ["music-2"]="rbxassetid://134397426600888",
  ["music-3"]="rbxassetid://94466120066498",
  ["music-4"]="rbxassetid://132459323665838",
  ["music"]="rbxassetid://113343203848535",
  ["navigation-2-off"]="rbxassetid://116569611780763",
  ["navigation-2"]="rbxassetid://81889066747907",
  ["navigation-off"]="rbxassetid://87003270290777",
  ["navigation"]="rbxassetid://79308213542922",
  ["network"]="rbxassetid://127410729922644",
  ["newspaper"]="rbxassetid://123479530460544",
  ["nfc"]="rbxassetid://76822396542242",
  ["non-binary"]="rbxassetid://78442360386235",
  ["notebook-pen"]="rbxassetid://140380614761023",
  ["notebook-tabs"]="rbxassetid://127371085570083",
  ["notebook-text"]="rbxassetid://93061585217270",
  ["notebook"]="rbxassetid://136132108664987",
  ["notepad-text-dashed"]="rbxassetid://135793446376219",
  ["notepad-text"]="rbxassetid://93404682958966",
  ["nut-off"]="rbxassetid://78795397311573",
  ["nut"]="rbxassetid://127146410705656",
  ["octagon-alert"]="rbxassetid://140438367956051",
  ["octagon-minus"]="rbxassetid://74720436795421",
  ["octagon-pause"]="rbxassetid://103161463909039",
  ["octagon-x"]="rbxassetid://90498161006311",
  ["octagon"]="rbxassetid://120803515514852",
  ["omega"]="rbxassetid://70414080018786",
  ["option"]="rbxassetid://100776883894054",
  ["orbit"]="rbxassetid://108926136860562",
  ["origami"]="rbxassetid://136020626667101",
  ["package-2"]="rbxassetid://70394974762575",
  ["package-check"]="rbxassetid://102374216055130",
  ["package-minus"]="rbxassetid://114492858789692",
  ["package-open"]="rbxassetid://132890233237818",
  ["package-plus"]="rbxassetid://129261988138366",
  ["package-search"]="rbxassetid://95465120894145",
  ["package-x"]="rbxassetid://70818501607442",
  ["package"]="rbxassetid://97261141732706",
  ["paint-bucket"]="rbxassetid://124275586663284",
  ["paint-roller"]="rbxassetid://115248074358348",
  ["paintbrush-vertical"]="rbxassetid://105151296591292",
  ["paintbrush"]="rbxassetid://125572663700289",
  ["palette"]="rbxassetid://86350350950064",
  ["panda"]="rbxassetid://132509022802512",
  ["panel-bottom-close"]="rbxassetid://74287004071159",
  ["panel-bottom-dashed"]="rbxassetid://131084651621603",
  ["panel-bottom-open"]="rbxassetid://107768659586540",
  ["panel-bottom"]="rbxassetid://132127145048511",
  ["panel-left-close"]="rbxassetid://126579818823552",
  ["panel-left-dashed"]="rbxassetid://75536606374585",
  ["panel-left-open"]="rbxassetid://111075816195767",
  ["panel-left-right-dashed"]="rbxassetid://110100707973959",
  ["panel-left"]="rbxassetid://97419752870313",
  ["panel-right-close"]="rbxassetid://139528655524132",
  ["panel-right-dashed"]="rbxassetid://94959793877311",
  ["panel-right-open"]="rbxassetid://118114419142794",
  ["panel-right"]="rbxassetid://116365035443156",
  ["panel-top-bottom-dashed"]="rbxassetid://134737235653344",
  ["panel-top-close"]="rbxassetid://83578325777808",
  ["panel-top-dashed"]="rbxassetid://70522913169237",
  ["panel-top-open"]="rbxassetid://137959875507454",
  ["panel-top"]="rbxassetid://75838479462875",
  ["panels-left-bottom"]="rbxassetid://72996856149149",
  ["panels-right-bottom"]="rbxassetid://90659068960726",
  ["panels-top-left"]="rbxassetid://79858853850600",
  ["paperclip"]="rbxassetid://92088291163453",
  ["parentheses"]="rbxassetid://78950955173096",
  ["parking-meter"]="rbxassetid://84652733960568",
  ["party-popper"]="rbxassetid://111626795712193",
  ["pause"]="rbxassetid://74873705394436",
  ["paw-print"]="rbxassetid://112218825427601",
  ["pc-case"]="rbxassetid://122978648019101",
  ["pen-line"]="rbxassetid://109108135755303",
  ["pen-off"]="rbxassetid://84807123119438",
  ["pen-tool"]="rbxassetid://106145404953445",
  ["pen"]="rbxassetid://72037878096321",
  ["pencil-line"]="rbxassetid://88392917053533",
  ["pencil-off"]="rbxassetid://103330927652832",
  ["pencil-ruler"]="rbxassetid://110120288284597",
  ["pencil"]="rbxassetid://137986121120732",
  ["pentagon"]="rbxassetid://79184802179890",
  ["percent"]="rbxassetid://130155041032013",
  ["person-standing"]="rbxassetid://125020872044147",
  ["philippine-peso"]="rbxassetid://91173798254675",
  ["phone-call"]="rbxassetid://70555587592860",
  ["phone-forwarded"]="rbxassetid://113269614319737",
  ["phone-incoming"]="rbxassetid://82863576359288",
  ["phone-missed"]="rbxassetid://130156165198376",
  ["phone-off"]="rbxassetid://133318623553383",
  ["phone-outgoing"]="rbxassetid://104576478735825",
  ["phone"]="rbxassetid://128804946640049",
  ["pi"]="rbxassetid://74936036243146",
  ["piano"]="rbxassetid://85008880789520",
  ["pickaxe"]="rbxassetid://105888023317688",
  ["picture-in-picture-2"]="rbxassetid://112803319544468",
  ["picture-in-picture"]="rbxassetid://80579597835123",
  ["piggy-bank"]="rbxassetid://79498575790721",
  ["pilcrow-left"]="rbxassetid://103803000849583",
  ["pilcrow-right"]="rbxassetid://104881733911870",
  ["pilcrow"]="rbxassetid://139512780392871",
  ["pill-bottle"]="rbxassetid://118394692404597",
  ["pill"]="rbxassetid://73280534813448",
  ["pin-off"]="rbxassetid://127696372451750",
  ["pin"]="rbxassetid://120978111007514",
  ["pipette"]="rbxassetid://133167932934404",
  ["pizza"]="rbxassetid://126964453193501",
  ["plane-landing"]="rbxassetid://122555692211889",
  ["plane-takeoff"]="rbxassetid://117179478829575",
  ["plane"]="rbxassetid://126985561580989",
  ["play"]="rbxassetid://135609604299893",
  ["plug-2"]="rbxassetid://97912386476366",
  ["plug-zap"]="rbxassetid://74506269884055",
  ["plug"]="rbxassetid://99782373064495",
  ["plus"]="rbxassetid://111774323017047",
  ["pocket-knife"]="rbxassetid://134075428063965",
  ["pocket"]="rbxassetid://136686762542964",
  ["podcast"]="rbxassetid://109577075549215",
  ["pointer-off"]="rbxassetid://95488389312794",
  ["pointer"]="rbxassetid://92615117311099",
  ["popcorn"]="rbxassetid://139446511232750",
  ["popsicle"]="rbxassetid://112696318077073",
  ["pound-sterling"]="rbxassetid://127482649469130",
  ["power-off"]="rbxassetid://118768311012214",
  ["power"]="rbxassetid://96479131758775",
  ["presentation"]="rbxassetid://106134583757890",
  ["printer-check"]="rbxassetid://130273549443689",
  ["printer"]="rbxassetid://76080649734247",
  ["projector"]="rbxassetid://103281856385283",
  ["proportions"]="rbxassetid://130046855997237",
  ["puzzle"]="rbxassetid://136837798892463",
  ["pyramid"]="rbxassetid://107811442374127",
  ["qr-code"]="rbxassetid://105329945723350",
  ["quote"]="rbxassetid://103271711590001",
  ["rabbit"]="rbxassetid://98580518804206",
  ["radar"]="rbxassetid://138528222906635",
  ["radiation"]="rbxassetid://104499586848433",
  ["radical"]="rbxassetid://132758286926047",
  ["radio-receiver"]="rbxassetid://129598303378835",
  ["radio-tower"]="rbxassetid://93958663130054",
  ["radio"]="rbxassetid://85611589536956",
  ["radius"]="rbxassetid://89814505307129",
  ["rail-symbol"]="rbxassetid://134295386306962",
  ["rainbow"]="rbxassetid://132488862841895",
  ["rat"]="rbxassetid://127400975953159",
  ["ratio"]="rbxassetid://126369423897295",
  ["receipt-cent"]="rbxassetid://91557573925201",
  ["receipt-euro"]="rbxassetid://94015722210295",
  ["receipt-indian-rupee"]="rbxassetid://89718170439990",
  ["receipt-japanese-yen"]="rbxassetid://132472560758851",
  ["receipt-pound-sterling"]="rbxassetid://73934967569625",
  ["receipt-russian-ruble"]="rbxassetid://105164576936853",
  ["receipt-swiss-franc"]="rbxassetid://72503668620116",
  ["receipt-text"]="rbxassetid://138483536013737",
  ["receipt-turkish-lira"]="rbxassetid://91950765836342",
  ["receipt"]="rbxassetid://77877895901792",
  ["rectangle-circle"]="rbxassetid://100642423153903",
  ["rectangle-ellipsis"]="rbxassetid://112919953980965",
  ["rectangle-goggles"]="rbxassetid://98605436666727",
  ["rectangle-horizontal"]="rbxassetid://90224199814966",
  ["rectangle-vertical"]="rbxassetid://117277050590967",
  ["recycle"]="rbxassetid://140417023381961",
  ["redo-2"]="rbxassetid://70451039017914",
  ["redo-dot"]="rbxassetid://94252981719732",
  ["redo"]="rbxassetid://116150342119054",
  ["refresh-ccw-dot"]="rbxassetid://106702246753270",
  ["refresh-ccw"]="rbxassetid://117913330389477",
  ["refresh-cw-off"]="rbxassetid://140179498843054",
  ["refresh-cw"]="rbxassetid://138133190015277",
  ["refrigerator"]="rbxassetid://102614042652753",
  ["regex"]="rbxassetid://100727200791841",
  ["remove-formatting"]="rbxassetid://112833162022628",
  ["repeat-1"]="rbxassetid://130144534857095",
  ["repeat-2"]="rbxassetid://85927537182704",
  ["repeat"]="rbxassetid://121886242955173",
  ["replace-all"]="rbxassetid://127862728198635",
  ["replace"]="rbxassetid://128404082279430",
  ["reply-all"]="rbxassetid://71723137343562",
  ["reply"]="rbxassetid://109788633497028",
  ["rewind"]="rbxassetid://95205297521988",
  ["ribbon"]="rbxassetid://94265331526851",
  ["rocket"]="rbxassetid://87412317685854",
  ["rocking-chair"]="rbxassetid://110420269495360",
  ["roller-coaster"]="rbxassetid://112426178972099",
  ["rose"]="rbxassetid://126336840238769",
  ["rotate-3d"]="rbxassetid://76300551576392",
  ["rotate-ccw-key"]="rbxassetid://74976035240976",
  ["rotate-ccw-square"]="rbxassetid://90515853170424",
  ["rotate-ccw"]="rbxassetid://110116685948665",
  ["rotate-cw-square"]="rbxassetid://77095448159303",
  ["rotate-cw"]="rbxassetid://84183336178654",
  ["route-off"]="rbxassetid://106350402024079",
  ["route"]="rbxassetid://89968303228953",
  ["router"]="rbxassetid://102130331994471",
  ["rows-2"]="rbxassetid://112556185960101",
  ["rows-3"]="rbxassetid://117215586961375",
  ["rows-4"]="rbxassetid://125646021959055",
  ["rss"]="rbxassetid://131789058984793",
  ["ruler-dimension-line"]="rbxassetid://70673861371412",
  ["ruler"]="rbxassetid://81432445547423",
  ["russian-ruble"]="rbxassetid://126357936542156",
  ["sailboat"]="rbxassetid://87110567187540",
  ["salad"]="rbxassetid://128864507821603",
  ["sandwich"]="rbxassetid://104573187458917",
  ["satellite-dish"]="rbxassetid://136742443888305",
  ["satellite"]="rbxassetid://134967053164645",
  ["saudi-riyal"]="rbxassetid://102282769104635",
  ["save-all"]="rbxassetid://116946975799440",
  ["save-off"]="rbxassetid://87085435778560",
  ["save"]="rbxassetid://126116963775616",
  ["scale-3d"]="rbxassetid://72414199620352",
  ["scale"]="rbxassetid://108203682317477",
  ["scaling"]="rbxassetid://122360365318466",
  ["scan-barcode"]="rbxassetid://96889457154761",
  ["scan-eye"]="rbxassetid://99244790601968",
  ["scan-face"]="rbxassetid://109959345069668",
  ["scan-heart"]="rbxassetid://106280819776142",
  ["scan-line"]="rbxassetid://126544908146540",
  ["scan-qr-code"]="rbxassetid://105409149549927",
  ["scan-search"]="rbxassetid://80009010551347",
  ["scan-text"]="rbxassetid://73702396787766",
  ["scan"]="rbxassetid://123104789658180",
  ["school"]="rbxassetid://76351530290068",
  ["scissors-line-dashed"]="rbxassetid://122237447974173",
  ["scissors"]="rbxassetid://118665510911274",
  ["screen-share-off"]="rbxassetid://107677572669805",
  ["screen-share"]="rbxassetid://85137895705653",
  ["scroll-text"]="rbxassetid://97321022666868",
  ["scroll"]="rbxassetid://74072101474951",
  ["search-check"]="rbxassetid://75442076191356",
  ["search-code"]="rbxassetid://117114794592802",
  ["search-slash"]="rbxassetid://96483932261041",
  ["search-x"]="rbxassetid://137319957522951",
  ["search"]="rbxassetid://121018724060431",
  ["section"]="rbxassetid://91732188298948",
  ["send-horizontal"]="rbxassetid://111734392411664",
  ["send-to-back"]="rbxassetid://75340312862253",
  ["send"]="rbxassetid://127751956873796",
  ["separator-horizontal"]="rbxassetid://84864453699927",
  ["separator-vertical"]="rbxassetid://84031801478581",
  ["server-cog"]="rbxassetid://138470287250966",
  ["server-crash"]="rbxassetid://132810618000212",
  ["server-off"]="rbxassetid://114048751507723",
  ["server"]="rbxassetid://92188766517878",
  ["settings-2"]="rbxassetid://135684703553372",
  ["settings"]="rbxassetid://80758916183665",
  ["shapes"]="rbxassetid://129989433311409",
  ["share-2"]="rbxassetid://71210767962065",
  ["share"]="rbxassetid://87340985053299",
  ["sheet"]="rbxassetid://134902122480171",
  ["shell"]="rbxassetid://140212943563599",
  ["shield-alert"]="rbxassetid://114995877719925",
  ["shield-ban"]="rbxassetid://108765041044649",
  ["shield-check"]="rbxassetid://87354736164608",
  ["shield-ellipsis"]="rbxassetid://114794739892123",
  ["shield-half"]="rbxassetid://117842634172647",
  ["shield-minus"]="rbxassetid://89965059528921",
  ["shield-off"]="rbxassetid://133426959132690",
  ["shield-plus"]="rbxassetid://100664857995498",
  ["shield-question-mark"]="rbxassetid://135722075265150",
  ["shield-user"]="rbxassetid://124832775645347",
  ["shield-x"]="rbxassetid://73370117343811",
  ["shield"]="rbxassetid://110987169760162",
  ["ship-wheel"]="rbxassetid://130797795829448",
  ["ship"]="rbxassetid://83995100553930",
  ["shirt"]="rbxassetid://106579555405966",
  ["shopping-bag"]="rbxassetid://71885477293226",
  ["shopping-basket"]="rbxassetid://138646411956433",
  ["shopping-cart"]="rbxassetid://128420521375441",
  ["shovel"]="rbxassetid://102465000512056",
  ["shower-head"]="rbxassetid://75884944024117",
  ["shredder"]="rbxassetid://122125164414463",
  ["shrimp"]="rbxassetid://102625900815307",
  ["shrink"]="rbxassetid://90953687918880",
  ["shrub"]="rbxassetid://127326280714343",
  ["shuffle"]="rbxassetid://132382786975101",
  ["sigma"]="rbxassetid://126884244870899",
  ["signal-high"]="rbxassetid://130436670012270",
  ["signal-low"]="rbxassetid://73674683500458",
  ["signal-medium"]="rbxassetid://125003021367019",
  ["signal-zero"]="rbxassetid://130045332414754",
  ["signal"]="rbxassetid://78424889355261",
  ["signature"]="rbxassetid://114402748013000",
  ["signpost-big"]="rbxassetid://115780185675001",
  ["signpost"]="rbxassetid://106584743791433",
  ["siren"]="rbxassetid://134210267818039",
  ["skip-back"]="rbxassetid://70466132711334",
  ["skip-forward"]="rbxassetid://124844823753990",
  ["skull"]="rbxassetid://137726256442333",
  ["slack"]="rbxassetid://96089719516736",
  ["slash"]="rbxassetid://117792185664263",
  ["slice"]="rbxassetid://95810504278179",
  ["sliders-horizontal"]="rbxassetid://85538382643347",
  ["sliders-vertical"]="rbxassetid://101190569086853",
  ["smartphone-charging"]="rbxassetid://102837532613995",
  ["smartphone-nfc"]="rbxassetid://82326425754446",
  ["smartphone"]="rbxassetid://96623008834511",
  ["smile-plus"]="rbxassetid://131981881472144",
  ["smile"]="rbxassetid://105880397565283",
  ["snail"]="rbxassetid://70904536548363",
  ["snowflake"]="rbxassetid://101235206534566",
  ["soap-dispenser-droplet"]="rbxassetid://77258480479465",
  ["sofa"]="rbxassetid://114427687218324",
  ["solar-panel"]="rbxassetid://132448188047921",
  ["soup"]="rbxassetid://115092551871618",
  ["space"]="rbxassetid://87072088914178",
  ["spade"]="rbxassetid://131444449466462",
  ["sparkle"]="rbxassetid://111044800239623",
  ["sparkles"]="rbxassetid://138635884129147",
  ["speaker"]="rbxassetid://96227183003618",
  ["speech"]="rbxassetid://87013139446349",
  ["spell-check-2"]="rbxassetid://81556731785534",
  ["spell-check"]="rbxassetid://91913483031334",
  ["spline-pointer"]="rbxassetid://84842840956804",
  ["spline"]="rbxassetid://129406685807412",
  ["split"]="rbxassetid://105112438805988",
  ["spool"]="rbxassetid://124541981347743",
  ["spotlight"]="rbxassetid://77571742539344",
  ["spray-can"]="rbxassetid://128372039366326",
  ["sprout"]="rbxassetid://100091687832508",
  ["square-activity"]="rbxassetid://89496630185293",
  ["square-arrow-down-left"]="rbxassetid://108194680296901",
  ["square-arrow-down-right"]="rbxassetid://99403846801050",
  ["square-arrow-down"]="rbxassetid://135962519626588",
  ["square-arrow-left"]="rbxassetid://111671474549238",
  ["square-arrow-out-down-left"]="rbxassetid://125714881756353",
  ["square-arrow-out-down-right"]="rbxassetid://89971003001390",
  ["square-arrow-out-up-left"]="rbxassetid://103759986579087",
  ["square-arrow-out-up-right"]="rbxassetid://91221896066807",
  ["square-arrow-right"]="rbxassetid://113920471701361",
  ["square-arrow-up-left"]="rbxassetid://112424670290693",
  ["square-arrow-up-right"]="rbxassetid://76602291406940",
  ["square-arrow-up"]="rbxassetid://106998604646718",
  ["square-asterisk"]="rbxassetid://89186832353625",
  ["square-bottom-dashed-scissors"]="rbxassetid://79076980104803",
  ["square-chart-gantt"]="rbxassetid://104034017316411",
  ["square-check-big"]="rbxassetid://115320390907184",
  ["square-check"]="rbxassetid://134682053539509",
  ["square-chevron-down"]="rbxassetid://91032307924592",
  ["square-chevron-left"]="rbxassetid://73143404829510",
  ["square-chevron-right"]="rbxassetid://90612077729930",
  ["square-chevron-up"]="rbxassetid://85565910197337",
  ["square-code"]="rbxassetid://81604576616881",
  ["square-dashed-bottom-code"]="rbxassetid://100354801563230",
  ["square-dashed-bottom"]="rbxassetid://101102319625624",
  ["square-dashed-kanban"]="rbxassetid://90388067649847",
  ["square-dashed-mouse-pointer"]="rbxassetid://121016142178467",
  ["square-dashed-top-solid"]="rbxassetid://117157577548540",
  ["square-dashed"]="rbxassetid://136905537847606",
  ["square-divide"]="rbxassetid://99894657101970",
  ["square-dot"]="rbxassetid://116613421354866",
  ["square-equal"]="rbxassetid://110283363706707",
  ["square-function"]="rbxassetid://86075219551088",
  ["square-kanban"]="rbxassetid://114537101260131",
  ["square-library"]="rbxassetid://73810931222081",
  ["square-m"]="rbxassetid://117662700410577",
  ["square-menu"]="rbxassetid://104067089444415",
  ["square-minus"]="rbxassetid://116764432015770",
  ["square-mouse-pointer"]="rbxassetid://76141850603920",
  ["square-parking-off"]="rbxassetid://100857293535141",
  ["square-parking"]="rbxassetid://133116656122387",
  ["square-pause"]="rbxassetid://86608552787615",
  ["square-pen"]="rbxassetid://120239476110475",
  ["square-percent"]="rbxassetid://87111930314567",
  ["square-pi"]="rbxassetid://75383328781618",
  ["square-pilcrow"]="rbxassetid://131854284699367",
  ["square-play"]="rbxassetid://108186325238481",
  ["square-plus"]="rbxassetid://114713264461873",
  ["square-power"]="rbxassetid://129240437805187",
  ["square-radical"]="rbxassetid://132645931868292",
  ["square-round-corner"]="rbxassetid://104592745113567",
  ["square-scissors"]="rbxassetid://110601255612411",
  ["square-sigma"]="rbxassetid://113231244246816",
  ["square-slash"]="rbxassetid://105477013908757",
  ["square-split-horizontal"]="rbxassetid://76095370148660",
  ["square-split-vertical"]="rbxassetid://88589192032058",
  ["square-square"]="rbxassetid://136555087357875",
  ["square-stack"]="rbxassetid://100463396619394",
  ["square-star"]="rbxassetid://94506958703720",
  ["square-stop"]="rbxassetid://80018708472943",
  ["square-terminal"]="rbxassetid://83969264476798",
  ["square-user-round"]="rbxassetid://86484997229302",
  ["square-user"]="rbxassetid://70771214183445",
  ["square-x"]="rbxassetid://125136183850190",
  ["square"]="rbxassetid://86304921356806",
  ["squares-exclude"]="rbxassetid://102345385822324",
  ["squares-intersect"]="rbxassetid://120869602570119",
  ["squares-subtract"]="rbxassetid://131484650948795",
  ["squares-unite"]="rbxassetid://96673080107843",
  ["squircle-dashed"]="rbxassetid://129936702532522",
  ["squircle"]="rbxassetid://82426632573807",
  ["squirrel"]="rbxassetid://112864252085343",
  ["stamp"]="rbxassetid://92370779813368",
  ["star-half"]="rbxassetid://117449275562979",
  ["star-off"]="rbxassetid://75742832732503",
  ["star"]="rbxassetid://136141469398409",
  ["step-back"]="rbxassetid://108672750005121",
  ["step-forward"]="rbxassetid://126131872136145",
  ["stethoscope"]="rbxassetid://122331031702148",
  ["sticker"]="rbxassetid://79938203791608",
  ["sticky-note"]="rbxassetid://111894074643919",
  ["store"]="rbxassetid://90338129673705",
  ["stretch-horizontal"]="rbxassetid://87665042192343",
  ["stretch-vertical"]="rbxassetid://95265463417122",
  ["strikethrough"]="rbxassetid://103417324549613",
  ["subscript"]="rbxassetid://74553514785183",
  ["sun-dim"]="rbxassetid://129141645592715",
  ["sun-medium"]="rbxassetid://130278807964710",
  ["sun-moon"]="rbxassetid://75752898854559",
  ["sun-snow"]="rbxassetid://112791898014579",
  ["sun"]="rbxassetid://110150589884127",
  ["sunrise"]="rbxassetid://134705665494098",
  ["sunset"]="rbxassetid://75904872203588",
  ["superscript"]="rbxassetid://96887696590118",
  ["swatch-book"]="rbxassetid://126786244872453",
  ["swiss-franc"]="rbxassetid://113497920041625",
  ["switch-camera"]="rbxassetid://76841154349737",
  ["sword"]="rbxassetid://124448418211665",
  ["swords"]="rbxassetid://81872698913435",
  ["syringe"]="rbxassetid://123891270479254",
  ["table-2"]="rbxassetid://95751552281545",
  ["table-cells-merge"]="rbxassetid://95363715175258",
  ["table-cells-split"]="rbxassetid://114799086088649",
  ["table-columns-split"]="rbxassetid://111011625447949",
  ["table-of-contents"]="rbxassetid://135044763275414",
  ["table-properties"]="rbxassetid://125062886015372",
  ["table-rows-split"]="rbxassetid://96443733673997",
  ["table"]="rbxassetid://109109148250737",
  ["tablet-smartphone"]="rbxassetid://133680859813404",
  ["tablet"]="rbxassetid://128403991264386",
  ["tablets"]="rbxassetid://80835787970735",
  ["tag"]="rbxassetid://129104970103940",
  ["tags"]="rbxassetid://107179263080798",
  ["tally-1"]="rbxassetid://115301298241643",
  ["tally-2"]="rbxassetid://110363186864027",
  ["tally-3"]="rbxassetid://97655344572540",
  ["tally-4"]="rbxassetid://102633494371890",
  ["tally-5"]="rbxassetid://88031817475886",
  ["tangent"]="rbxassetid://123263132981724",
  ["target"]="rbxassetid://87563802520297",
  ["telescope"]="rbxassetid://91755049143647",
  ["tent-tree"]="rbxassetid://76698322463977",
  ["tent"]="rbxassetid://109779587826330",
  ["terminal"]="rbxassetid://106783148545356",
  ["test-tube-diagonal"]="rbxassetid://75662704378840",
  ["test-tube"]="rbxassetid://98801015650164",
  ["test-tubes"]="rbxassetid://92555361447433",
  ["text-align-center"]="rbxassetid://84051028246390",
  ["text-align-end"]="rbxassetid://130041738343555",
  ["text-align-justify"]="rbxassetid://80279880143030",
  ["text-align-start"]="rbxassetid://134489585487649",
  ["text-cursor-input"]="rbxassetid://107551944047171",
  ["text-cursor"]="rbxassetid://115984654447300",
  ["text-initial"]="rbxassetid://129458097472087",
  ["text-quote"]="rbxassetid://139278366448736",
  ["text-search"]="rbxassetid://92345384671606",
  ["text-select"]="rbxassetid://117087320884956",
  ["text-wrap"]="rbxassetid://114804318314018",
  ["theater"]="rbxassetid://108558145549163",
  ["thermometer-snowflake"]="rbxassetid://121876188028425",
  ["thermometer-sun"]="rbxassetid://106693240074310",
  ["thermometer"]="rbxassetid://106546011492311",
  ["thumbs-down"]="rbxassetid://87794009914015",
  ["thumbs-up"]="rbxassetid://111137070767020",
  ["ticket-check"]="rbxassetid://105428777212507",
  ["ticket-minus"]="rbxassetid://78966299769328",
  ["ticket-percent"]="rbxassetid://80834774406405",
  ["ticket-plus"]="rbxassetid://110086734392189",
  ["ticket-slash"]="rbxassetid://89045681172265",
  ["ticket-x"]="rbxassetid://88674114109926",
  ["ticket"]="rbxassetid://126527071492145",
  ["tickets-plane"]="rbxassetid://100367018248695",
  ["tickets"]="rbxassetid://135268612687833",
  ["timer-off"]="rbxassetid://110916370767271",
  ["timer-reset"]="rbxassetid://110052125369932",
  ["timer"]="rbxassetid://85473888890506",
  ["toggle-left"]="rbxassetid://85887872573050",
  ["toggle-right"]="rbxassetid://90411952142550",
  ["toilet"]="rbxassetid://80930782432931",
  ["tool-case"]="rbxassetid://87533537832522",
  ["tornado"]="rbxassetid://88358291515768",
  ["torus"]="rbxassetid://70855707283051",
  ["touchpad-off"]="rbxassetid://78784008075456",
  ["touchpad"]="rbxassetid://74882354908014",
  ["tower-control"]="rbxassetid://95937619060532",
  ["toy-brick"]="rbxassetid://86293483924633",
  ["tractor"]="rbxassetid://103376704722051",
  ["traffic-cone"]="rbxassetid://74110220470369",
  ["train-front-tunnel"]="rbxassetid://105194827005114",
  ["train-front"]="rbxassetid://125237934215370",
  ["train-track"]="rbxassetid://77451032453723",
  ["tram-front"]="rbxassetid://93315182364998",
  ["transgender"]="rbxassetid://135530817673639",
  ["trash-2"]="rbxassetid://109843431391323",
  ["trash"]="rbxassetid://106723740584310",
  ["tree-deciduous"]="rbxassetid://123124389219004",
  ["tree-palm"]="rbxassetid://103846705893963",
  ["tree-pine"]="rbxassetid://124662547202594",
  ["trees"]="rbxassetid://121203841375919",
  ["trello"]="rbxassetid://130987241149527",
  ["trending-down"]="rbxassetid://139309232226438",
  ["trending-up-down"]="rbxassetid://85083293981691",
  ["trending-up"]="rbxassetid://81819858538839",
  ["triangle-alert"]="rbxassetid://125920361880643",
  ["triangle-dashed"]="rbxassetid://124324079103935",
  ["triangle-right"]="rbxassetid://116930791412791",
  ["triangle"]="rbxassetid://126330486745540",
  ["trophy"]="rbxassetid://131545003268773",
  ["truck-electric"]="rbxassetid://111873446387359",
  ["truck"]="rbxassetid://86662707764771",
  ["turkish-lira"]="rbxassetid://114589876174070",
  ["turntable"]="rbxassetid://129870346487856",
  ["turtle"]="rbxassetid://118295081560334",
  ["tv-minimal-play"]="rbxassetid://99201833426972",
  ["tv-minimal"]="rbxassetid://100382201729427",
  ["tv"]="rbxassetid://135687724791776",
  ["twitch"]="rbxassetid://71383308134888",
  ["twitter"]="rbxassetid://88791703276842",
  ["type-outline"]="rbxassetid://80108627791690",
  ["type"]="rbxassetid://133543553793564",
  ["umbrella-off"]="rbxassetid://72395143739955",
  ["umbrella"]="rbxassetid://127502210274589",
  ["underline"]="rbxassetid://123709229216544",
  ["undo-2"]="rbxassetid://113885292059932",
  ["undo-dot"]="rbxassetid://132055277744844",
  ["undo"]="rbxassetid://111258459077271",
  ["unfold-horizontal"]="rbxassetid://117128358526398",
  ["unfold-vertical"]="rbxassetid://116593025265499",
  ["ungroup"]="rbxassetid://106674800451003",
  ["university"]="rbxassetid://84652528263642",
  ["unlink-2"]="rbxassetid://128131898892572",
  ["unlink"]="rbxassetid://139835795227752",
  ["unplug"]="rbxassetid://90171381619874",
  ["upload"]="rbxassetid://138212042425501",
  ["usb"]="rbxassetid://117230058949613",
  ["user-check"]="rbxassetid://81775205032725",
  ["user-cog"]="rbxassetid://92795491530865",
  ["user-lock"]="rbxassetid://78892639693821",
  ["user-minus"]="rbxassetid://126976941957511",
  ["user-pen"]="rbxassetid://87445472574836",
  ["user-plus"]="rbxassetid://118514469915884",
  ["user-round-check"]="rbxassetid://118794737621941",
  ["user-round-cog"]="rbxassetid://78239503290053",
  ["user-round-minus"]="rbxassetid://98944176636447",
  ["user-round-pen"]="rbxassetid://108155244324878",
  ["user-round-plus"]="rbxassetid://113301899567470",
  ["user-round-search"]="rbxassetid://71565774381870",
  ["user-round-x"]="rbxassetid://122367980560930",
  ["user-round"]="rbxassetid://136485052187963",
  ["user-search"]="rbxassetid://101335649828115",
  ["user-star"]="rbxassetid://98777846316000",
  ["user-x"]="rbxassetid://139748155894754",
  ["user"]="rbxassetid://81589895647169",
  ["users-round"]="rbxassetid://103005444008339",
  ["users"]="rbxassetid://115398113982385",
  ["utensils-crossed"]="rbxassetid://109520762270383",
  ["utensils"]="rbxassetid://139952569804235",
  ["utility-pole"]="rbxassetid://101965541238242",
  ["variable"]="rbxassetid://104743088438151",
  ["vault"]="rbxassetid://108049164599845",
  ["vector-square"]="rbxassetid://86713728565344",
  ["vegan"]="rbxassetid://119489190688082",
  ["venetian-mask"]="rbxassetid://102636443033920",
  ["venus-and-mars"]="rbxassetid://120227752103771",
  ["venus"]="rbxassetid://82891342220859",
  ["vibrate-off"]="rbxassetid://113446447326246",
  ["vibrate"]="rbxassetid://108330910738733",
  ["video-off"]="rbxassetid://132239189859305",
  ["video"]="rbxassetid://107587444636945",
  ["videotape"]="rbxassetid://114816894323398",
  ["view"]="rbxassetid://118717253976805",
  ["voicemail"]="rbxassetid://134313454010227",
  ["volleyball"]="rbxassetid://83889351124153",
  ["volume-1"]="rbxassetid://98514588731639",
  ["volume-2"]="rbxassetid://89344380902620",
  ["volume-off"]="rbxassetid://103047478058767",
  ["volume-x"]="rbxassetid://139252359189540",
  ["volume"]="rbxassetid://103236289817396",
  ["vote"]="rbxassetid://89409762851246",
  ["wallet-cards"]="rbxassetid://129728715308337",
  ["wallet-minimal"]="rbxassetid://137800448816116",
  ["wallet"]="rbxassetid://132331555762628",
  ["wallpaper"]="rbxassetid://74682121235494",
  ["wand-sparkles"]="rbxassetid://82546429942392",
  ["wand"]="rbxassetid://114580617777835",
  ["warehouse"]="rbxassetid://78388887451080",
  ["washing-machine"]="rbxassetid://104194127573858",
  ["watch"]="rbxassetid://130544621618405",
  ["waves-ladder"]="rbxassetid://101808619355514",
  ["waves"]="rbxassetid://96340135183647",
  ["waypoints"]="rbxassetid://102450133666017",
  ["webcam"]="rbxassetid://104148487911129",
  ["webhook-off"]="rbxassetid://96370548093471",
  ["webhook"]="rbxassetid://112812457747322",
  ["weight"]="rbxassetid://103860559844854",
  ["wheat-off"]="rbxassetid://133294844612307",
  ["wheat"]="rbxassetid://85261952080359",
  ["whole-word"]="rbxassetid://90111083954485",
  ["wifi-cog"]="rbxassetid://110500263326209",
  ["wifi-high"]="rbxassetid://81954601342139",
  ["wifi-low"]="rbxassetid://138217335635913",
  ["wifi-off"]="rbxassetid://74113634330106",
  ["wifi-pen"]="rbxassetid://91290205064712",
  ["wifi-sync"]="rbxassetid://84043971055177",
  ["wifi-zero"]="rbxassetid://124286465246123",
  ["wifi"]="rbxassetid://104669375183960",
  ["wind-arrow-down"]="rbxassetid://127753987414870",
  ["wind"]="rbxassetid://114551690399915",
  ["wine-off"]="rbxassetid://108294164302317",
  ["wine"]="rbxassetid://115743721332829",
  ["workflow"]="rbxassetid://99186544029189",
  ["worm"]="rbxassetid://115752311548091",
  ["wrench"]="rbxassetid://112148279212860",
  ["x"]="rbxassetid://110786993356448",
  ["youtube"]="rbxassetid://123663668456341",
  ["zap-off"]="rbxassetid://81385483183652",
  ["zap"]="rbxassetid://130551565616516",
  ["zoom-in"]="rbxassetid://127956924984803",
  ["zoom-out"]="rbxassetid://108334162607319",
  ["balloon"]="rbxassetid://97489111621526",
  ["beef-off"]="rbxassetid://99869959725200",
  ["book-search"]="rbxassetid://132585409504950",
  ["calendars"]="rbxassetid://130944763042289",
  ["cannabis-off"]="rbxassetid://101938500363812",
  ["cctv-off"]="rbxassetid://75925370187295",
  ["cigarette"]="rbxassetid://137149549886852",
  ["circle-pile"]="rbxassetid://116353155251541",
  ["cloud-backup"]="rbxassetid://111649579696132",
  ["cloud-sync"]="rbxassetid://79393911188593",
  ["database-search"]="rbxassetid://92017137080138",
  ["ellipse"]="rbxassetid://71559658267482",
  ["fingerprint-pattern"]="rbxassetid://80934710831288",
  ["fishing-hook"]="rbxassetid://121038780855899",
  ["fishing-rod"]="rbxassetid://71754848048049",
  ["form"]="rbxassetid://72999643971000",
  ["git-merge-conflict"]="rbxassetid://85677801675703",
  ["globe-off"]="rbxassetid://77775243585824",
  ["globe-x"]="rbxassetid://109268097029296",
  ["hd"]="rbxassetid://71682790698278",
  ["image"]="rbxassetid://112751259236831",
  ["layers-plus"]="rbxassetid://77587765623057",
  ["lens-concave"]="rbxassetid://94819631937027",
  ["lens-convex"]="rbxassetid://74736504195474",
  ["line-dot-right-horizontal"]="rbxassetid://104718593155221",
  ["line-style"]="rbxassetid://90176717785772",
  ["map-pin-search"]="rbxassetid://89065012915078",
  ["message-circle-check"]="rbxassetid://132772297689418",
  ["message-square-check"]="rbxassetid://125789987055668",
  ["metronome"]="rbxassetid://101991829345965",
  ["mirror-rectangular"]="rbxassetid://109046769760336",
  ["mirror-round"]="rbxassetid://121534049429097",
  ["mouse-left"]="rbxassetid://99144293708743",
  ["mouse-right"]="rbxassetid://88331710212594",
  ["printer-x"]="rbxassetid://103002721801548",
  ["radio-off"]="rbxassetid://80359258046586",
  ["road"]="rbxassetid://120251329173530",
  ["scooter"]="rbxassetid://100035452787934",
  ["search-alert"]="rbxassetid://127597984617505",
  ["shelving-unit"]="rbxassetid://80116568514793",
  ["shield-cog-corner"]="rbxassetid://111694066132698",
  ["shield-cog"]="rbxassetid://129235695057857",
  ["sport-shoe"]="rbxassetid://120495992692630",
  ["square-arrow-right-enter"]="rbxassetid://138867831495334",
  ["square-arrow-right-exit"]="rbxassetid://133688575845430",
  ["square-centerline-dashed-horizontal"]="rbxassetid://77780104374341",
  ["square-centerline-dashed-vertical"]="rbxassetid://107878435803525",
  ["stone"]="rbxassetid://135161057497830",
  ["toolbox"]="rbxassetid://85341033903792",
  ["towel-rack"]="rbxassetid://125223915620991",
  ["user-key"]="rbxassetid://105403041782190",
  ["user-round-key"]="rbxassetid://124547549008939",
  ["van"]="rbxassetid://122066377022942",
  ["waves-arrow-down"]="rbxassetid://129215220911792",
  ["waves-arrow-up"]="rbxassetid://102314705716217",
  ["weight-tilde"]="rbxassetid://112081212176951",
  ["x-line-top"]="rbxassetid://140592656289509",
  ["zodiac-aquarius"]="rbxassetid://74560047770362",
  ["zodiac-aries"]="rbxassetid://73255859670234",
  ["zodiac-cancer"]="rbxassetid://131985162532947",
  ["zodiac-capricorn"]="rbxassetid://97859568140652",
  ["zodiac-gemini"]="rbxassetid://80997588122992",
  ["zodiac-leo"]="rbxassetid://75509406718106",
  ["zodiac-libra"]="rbxassetid://113222735060218",
  ["zodiac-ophiuchus"]="rbxassetid://129180108892480",
  ["zodiac-pisces"]="rbxassetid://95845819440327",
  ["zodiac-sagittarius"]="rbxassetid://82651026742181",
  ["zodiac-scorpio"]="rbxassetid://113640924054631",
  ["zodiac-taurus"]="rbxassetid://123053219704400",
  ["zodiac-virgo"]="rbxassetid://99462994613661",
}

local WinMT = {}
local TabMT = {}

local Lib = {
	Version = "1.2.0",
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

Lib.ICONS = ICONS_DATA -- 对外暴露：可枚举/自定义遍历

-- ===== 内置图标 API =====
-- 解析图标标识："rbxassetid://xxx" 原样 / "lucide:eye" 取后段 / "eye" 直接查表；失败 nil
function Lib.Icon(name)
	if type(name) ~= "string" or name == "" then return nil end
	if string.sub(name, 1, 12) == "rbxassetid://" then return name end
	local q = name
	local ci = string.find(q, ":", 1, true)
	if ci then q = string.sub(q, ci + 1) end
	return ICONS_DATA[string.lower(q)]
end

-- 建图标 ImageLabel：color 传主题 token 字符串（随主题换色）或 Color3；解析失败返回 nil
function Lib:IconImage(parent, icon, size, color)
	local img = Lib.Icon(icon)
	if not img then return nil end
	local o = New("ImageLabel", {
		BackgroundTransparency = 1,
		Size = size or UDim2.fromOffset(24, 24),
		Image = img, Parent = parent,
	})
	if color then
		if type(color) == "string" then
			self:Bind(o, "ImageColor3", color)
		else
			o.ImageColor3 = color
		end
	end
	return o
end

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
		itemH = 56, itemGap = 10,
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
	-- 内嵌统计格（可选）：o.Stats = { {k="键", v="值"}, ... }，2 列网格嵌卡内底部
	local statsGrid = nil
	local statItems = (type(o.Stats) == "table" and #o.Stats > 0) and o.Stats or nil
	local gridLines = {}
	if statItems then
		statsGrid = New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -sp * 2, 0, 0), Parent = card,
		})
		New("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, ctx.M.mobile and 40 or 50),
			CellPadding = UDim2.new(0, 12, 0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder, Parent = statsGrid,
		})
		-- 样本风格：无底色格子，十字分隔线切分，大数字在上、标签在下
		for i, s in ipairs(statItems) do
			local sc = New("Frame", {
				BackgroundTransparency = 1, Parent = statsGrid,
			})
			local sv = New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 2),
				Size = UDim2.new(1, 0, 0, ctx.M.mobile and 20 or 26),
				Font = Enum.Font.GothamBold, TextSize = ctx.M.mobile and 17 or 22,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				Text = tostring(s.v or s[2] or s.k or ""), Parent = sc,
			})
			lib:Bind(sv, "TextColor3", "accent2")
			local sk = New("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -(ctx.M.mobile and 14 or 16)),
				Size = UDim2.new(1, 0, 0, ctx.M.mobile and 13 or 14),
				Font = Enum.Font.Gotham, TextSize = ctx.M.mobile and 10 or 12,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				Text = tostring(s.k or s[1] or ""), Parent = sc,
			})
			lib:Bind(sk, "TextColor3", "muted")
		end
	end
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
		if statsGrid then
			-- rebuildDesc 后重定位统计格（描述行数可变），并计入卡片高度
			statsGrid.Position = UDim2.fromOffset(sp, y + 8)
			local rows = math.ceil(#statItems / 2)
			local cellH = ctx.M.mobile and 40 or 50
			statsGrid.Size = UDim2.new(1, -sp * 2, 0, rows * cellH + (rows - 1) * 6)
			-- 十字分隔线（样本风格）：多项时画中竖线，两行时画中缝横线
			for _, l in ipairs(gridLines) do l:Destroy() end
			gridLines = {}
			local function gline(pos, size)
				local ln = New("Frame", {
					Position = pos, Size = size,
					BackgroundColor3 = lib:Theme().line, BackgroundTransparency = 0.4,
					BorderSizePixel = 0, Parent = statsGrid,
				})
				lib:Bind(ln, "BackgroundColor3", "line")
				table.insert(gridLines, ln)
			end
			if #statItems >= 3 then
				gline(UDim2.new(0.5, -3, 0, 0), UDim2.new(0, 1, 1, 0))
			end
			if rows == 2 then
				gline(UDim2.new(0, 0, 0.5, -3), UDim2.new(1, 0, 0, 1))
			end
			y = y + 8 + statsGrid.Size.Y.Offset
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
	-- 背景跟随主题纯色（按用户要求移除装饰纹理）
	return nil
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
	-- cfg.Icon 优先（"rbxassetid://..." / 内置图标名 / "lucide:xxx"），有图则盖住"秋"字标
	local markIcon = lib:IconImage(mark, cfg.Icon, UDim2.fromScale(1, 1), "bg")
	if markIcon then
		markText.Visible = false
	end
	local title = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(M.mobile and 52 or 78, M.mobile and 6 or 6),
		Size = UDim2.new(1, -(M.mobile and 60 or 90), 0, M.mobile and 20 or 26),
		Font = Enum.Font.GothamBold, TextSize = M.mobile and 15 or 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(cfg.Title or cfg.Name or "秋容工具箱"), Parent = logo,
	})
	lib:Bind(title, "TextColor3", "text")
	local subtitle = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(M.mobile and 52 or 78, M.mobile and 27 or 33),
		Size = UDim2.new(1, -(M.mobile and 60 or 90), 0, M.mobile and 12 or 14),
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
	-- 跑马灯：徽章右侧的裁剪容器内滚动（ClipsDescendants），文字不会滚到徽章上面
	local clip = New("Frame", {
		Position = UDim2.fromOffset(badgeW + (M.mobile and 22 or 32), 0),
		Size = UDim2.new(1, -(badgeW + (M.mobile and 22 or 32) + 10), 1, 0),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = ticker,
	})
	local marquee = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(0, 0.5),
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamMedium, TextSize = M.mobile and 13 or 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(cfg.Marquee or "欢迎秋容工具箱 · 求点赞关注，谢谢支持"), Parent = clip,
	})
	lib:Bind(marquee, "TextColor3", "text")
	ctx.marquee = marquee
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
		Size = UDim2.fromOffset(math.floor(M.itemH * 0.6), math.floor(M.itemH * 0.6)),
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
		BackgroundColor3 = t.good, BackgroundTransparency = 0.82, Visible = false, Parent = main,
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
	-- 底栏分类 = 当前菜单页的子分类（Section）导航，每页 5 个，‹› 翻页，点击滚动到对应分组
	local cur = ctx.win._current
	local secList = (cur and cur._secList) or {}
	local totalPages = math.max(1, math.ceil(#secList / CAT_SLOTS))
	if ctx.catPage >= totalPages then ctx.catPage = totalPages - 1 end
	if ctx.catPage < 0 then ctx.catPage = 0 end
	for i = 1, CAT_SLOTS do
		local e = ctx.catBtns[i]
		if e then
			local idx = ctx.catPage * CAT_SLOTS + i
			local ent = secList[idx]
			e.b.Visible = ent ~= nil
			if ent then
				local act = (ctx._activeCat == ent) or (ctx._activeCat == nil and idx == 1)
				-- 文字一律用 lbl 显示（TextButton 自身 TextColor3 是默认黑色，深色主题上不可见）
				e.lbl.Text = tostring(ent.title)
				e.lbl.TextColor3 = act and lib:Theme().bg or lib:Theme().text
				e.lbl.Font = act and Enum.Font.GothamBold or Enum.Font.GothamMedium
				e.b.BackgroundColor3 = act and lib:Theme().accent or lib:Theme().panel2
				e.st.Color = act and lib:Theme().accent or lib:Theme().line
			end
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
	-- 分类区位于 ‹ 与 › 之间：区宽 = 窗宽 - 两侧让位；纯 offset 定位（SetSize 后不重排，与底纹同为已知限制）
	local slotW = (M.win.w - catsX1 * 2) / CAT_SLOTS
	for i = 1, CAT_SLOTS do
		local btn = New("TextButton", {
			Position = UDim2.fromOffset(catsX1 + (i - 1) * slotW + 3, (M.bottom - byH) / 2),
			Size = UDim2.fromOffset(slotW - 6, byH),
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
		-- ⚠ 绝不给 Instance 挂自定义字段（_stroke/_lbl 这种）：跨脚本环境读取会报
		-- "not a valid member" 且直接炸掉 Tab 创建 → 界面全空。引用统一存进普通 Lua 表。
		btn.MouseButton1Click:Connect(function()
			local secList = ctx.win._current and ctx.win._current._secList or {}
			local idx = ctx.catPage * CAT_SLOTS + i
			local ent = secList[idx]
			if ent and ent.frame and ent.frame.Parent then
				-- 平滑滚动到该分组在内容区里的位置并高亮
				local target = ent.frame.AbsolutePosition.Y - ctx.bodyScroll.AbsolutePosition.Y + ctx.bodyScroll.CanvasPosition.Y - 8
				TweenService:Create(ctx.bodyScroll, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CanvasPosition = Vector2.new(0, math.max(target, 0)),
				}):Play()
				ctx._activeCat = ent
				refreshCats(ctx.lib, ctx)
			end
		end)
		catBtns[i] = { b = btn, st = st, lbl = lbl }
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
	-- cfg.Icon 优先（"rbxassetid://..." / 内置图标名 / "lucide:xxx"），有图则盖住"秋"字标
	local markIcon = lib:IconImage(mark, config.Icon, UDim2.fromScale(1, 1), "bg")
	if markIcon then
		markText.Visible = false
	end
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
	-- WindUI 式最小化：窗口缩小滑向屏幕底部，恢复时从底部弹回（悬浮球/呼出键唤回）
	function win:MinimizeAnimated()
		if ctx.minimizeAnim or ctx.minimized then return end
		ctx.minimizeAnim = true
		ctx:CloseList()
		ctx._minRestorePos = shell.Position
		ctx._minRestoreScale = scale.Scale
		local ti = TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(shell, ti, { Position = UDim2.fromScale(0.5, 1.3) }):Play()
		TweenService:Create(scale, ti, { Scale = math.max(scale.Scale * 0.55, 0.25) }):Play()
		task.delay(0.34, function()
			ctx.gui.Enabled = false
			if ctx.openBtn then ctx.openBtn.Visible = true end
			ctx.minimized = true
			ctx.minimizeAnim = false
		end)
	end
	function win:RestoreFromMinimize()
		if ctx.minimizeAnim or not ctx.minimized then return end
		ctx.minimizeAnim = true
		ctx.gui.Enabled = true
		if ctx.openBtn then ctx.openBtn.Visible = false end
		shell.Position = UDim2.fromScale(0.5, 1.3)
		scale.Scale = math.max((ctx._minRestoreScale or 1) * 0.55, 0.25)
		TweenService:Create(shell, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = ctx._minRestorePos or UDim2.fromScale(0.5, 0.5),
		}):Play()
		TweenService:Create(scale, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = ctx._minRestoreScale or 1,
		}):Play()
		task.delay(0.44, function()
			if not ctx.userScale and fitScale then fitScale() end
			ctx.minimized = false
			ctx.minimizeAnim = false
		end)
	end
	ctx.minBtn.MouseButton1Click:Connect(function() win:MinimizeAnimated() end)
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
						if ctx.minimized then win:RestoreFromMinimize() else win:Show() end
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

	-- 跑马灯滚动（隐藏时暂停；文字在徽章右侧裁剪容器内循环，从右进左出、不覆盖徽章）
	local marqueeOff = 0
	table.insert(ctx._conns, RunService.Heartbeat:Connect(function(dt)
		local m = ctx.marquee
		if m and m.Parent and ctx.gui.Enabled then
			local textW = m.TextBounds.X
			local clipW = math.max(m.Parent.AbsoluteSize.X, 1)
			marqueeOff += dt * 55
			local total = textW + clipW + 20
			if marqueeOff > total then marqueeOff = 0 end
			m.Position = UDim2.new(0, clipW - marqueeOff, 0.5, 0)
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

	-- toast 容器（挂独立全屏 ScreenGui：通知固定在 Roblox 屏幕右上角，不随窗口、不挡窗口内容）
	local toastGui = New("ScreenGui", {
		Name = "QiurongToolbox_Toast", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Parent = safeParent(),
	})
	local toastLayer = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(M.mobile and 220 or 300, 800),
		BackgroundTransparency = 1, ZIndex = 70, Parent = toastGui,
	})
	VList(toastLayer, 8)
	ctx.toastLayer = toastLayer
	ctx.toastGui = toastGui

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

function TabMT:Section(a, b, noCat)
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
	-- 注册进本页的底栏子分类导航（底栏"分类"按钮 = 当前菜单页里的 Section 列表）
	-- noCat=true 跳过注册：tabLazy 自动建的"控件"兜底分组不上分类栏
	if not noCat then
		tabObj._secList = tabObj._secList or {}
		local ent = { title = tostring(sec.title), frame = holder }
		table.insert(tabObj._secList, ent)
		if ctx.win._current == tabObj then
			refreshCats(ctx.lib, ctx)
		end
	end
	return sec
end

local function tabLazy(self)
	if not self._auto then self._auto = TabMT.Section(self, "控件", nil, true) end
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
		if old._frame then
			old._frame.Visible = false
			old._frame.Parent = nil
		end
		applyMenuStyle(lib, old, false)
	end
	self._current = target
	ctx._activeCat = nil -- 换页清空分类高亮（分类导航跟随当前页 Sections 重建）
	if target._frame then
		-- ⚠ 页帧创建时 Visible=false（防 UIListLayout 占位），挂回时必须显式恢复，
		-- 否则内容全部存在但不可见（实测踩坑：只挂 Parent 内容区全空）
		target._frame.Visible = true
		target._frame.Parent = ctx.bodyScroll
	end
	applyMenuStyle(lib, target, true)
	applyHeader(lib, ctx, target)
	refreshCats(lib, ctx)
end

function WinMT:ToggleCollapse() end -- 实例方法在 CreateWindow 中覆盖

function WinMT:ToggleVisibility()
	local ctx = self._ctx
	if ctx.gui.Enabled then
		self:Hide()
	elseif ctx.minimized then
		self:RestoreFromMinimize()
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
	if ctx.toastGui then pcall(function() ctx.toastGui:Destroy() end) end
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
