--[[ 秋容UI框架 · 提取版  (from 秋容脚本VIP v2.2) --]]
do
local _G_ = _G
_G._BFH_STOP_ALL = _G._BFH_STOP_ALL or {}
_G._BFH_PRESERVE = _G._BFH_PRESERVE or {}
local ChatPollThread = nil   -- 聊天页已移除，UI.Destroy 仍会引用它

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
        Author = "b站英吉利超入",
        GuiName = "DropshipHubUI",
        DefaultPage = "about",
        MarqueeText = "秋容脚本V2.0 | 秋容之作",
                AnnouncementTitle = "公告详情",
        AnnouncementText = [=[

【置顶】作者:秋容   求点赞 关注 谢谢你的支持是我的最大动力    作者快手:ROBLOX[秋容]
脚本一直爽，封号两行泪  开挂一时嗨，父母后排看
开挂不演戏，畜生把你算  躲在挂服里，转头去频道
想要活得久，演戏必不少  想要活得长，功能开得少
欢迎使用此脚本！此脚本仍然有很多bug 有bug一定要反馈主播 主播看到第一时间会修复
若有一定想法的功能可向主播推荐  主播尽可能的给你做出来
QQ群:1079353586欢迎加入一起聊天哦

=== v2.2 更新内容 (2026-08-04) ===
注:此版本新增重载保留+医生传送重做

新增:重载保留[重复执行脚本后之前开过的功能自动保留|没开过的开关不会被打开|旧窗口全部清掉只留最新一个]

修复:[自动治疗]=不再自动切换医疗工具[只有手上拿着医疗用品才治疗]

修复:[医生传送]=传送过去先卸下工具0.5秒再重新拿起[然后持续发送治疗]
修复:[医生传送]=取消选择后再选同一个人会重新卸下重装[不再跳过]

优化:[自动拾取纱布]=拾取速度提升

=== v2.1 更新内容 (2026-08-04) ===
注:此版本新增服务器菜单+VIP菜单+大量修复

新增:半缝合VIP版[服务器菜单]
新增:搜索玩家[秒查|输入名字找到他在哪个服]
新增:抢服务器[满员一直抢到进为止]
新增:展开服务器[看玩家头像+名字]
新增:地图缩略图[每行显示]
新增:地图中文名[全地图翻译]
新增:筛选[类型|平台|满员|地区]
新增:排序[延迟|人数|波数]

新增:VIP菜单[心跳在线目录|显示谁在线|点名字加入]

修复:[服务器菜单]=打开自动刷新[不用手动点]
修复:[自动修复]=提速[连续修3下|支持ConstructHealth建筑]
修复:[自爆倒计时]=正确识别点燃
修复:[自动跳刀]=手机端监听开火键[单次跳]
修复:[碰撞箱强制爆头]=拿枪刺刀也能打
修复:[滑块]=多指不再乱跳
修复:[医生传送]=传到目标前面[治疗工具自动卸装重装]
修复:[自动剪纱布]=提速
修复:[逃脱攀爬]=性能优化[不卡了]
新增:建筑数显示[信息面板建12/己5]

=== v2.0 更新内容 (2026-08-02) ===
注:此版本大修退出清理[退出脚本后所有残留都清干净]

修复:[自动跳刀]=开启后退出脚本不再卡死崩溃
修复:[强制爆头]=开局加载中开启不再报错
修复:[亮度提升]=退出脚本后恢复原亮度[监听不残留]
修复:[信息面板]=退出脚本后不再残留[也不会突然出现]
修复:[退出清理]=高亮/悬浮窗/面板全部销毁[一个不留]

=== v1.9 更新内容 (2026-08-02) ===
注:此版本新增存档系统+重做医生传送窗口

新增:[存档]菜单
新增:保存配置[JSON存到本地|可命名]
新增:加载配置[恢复所有设置]
新增:删除配置[带确认]
新增:叠加替换[开启=同名覆盖|关闭=同名自动编号]
新增:设置自动加载[指定下次恢复]
新增:去除自动加载
修复:加载配置后功能真正生效[不只是开关显示]

重做:[医生传送悬浮窗]
新增:锁定区[当前目标固定顶部]
新增:候选区[只列前6个|血量低→高]
新增:整行点击[不用专门点按钮]
新增:顶部固定收缩[从下面收起]
新增:整体缩放[文字跟着变]

修复:[自动治疗]=必须手上拿医疗用品才发远程
修复:[治疗范围]=固定7米[去掉可调]
修复:[受伤玩家不显示]=去掉血量稳定过滤
修复:[重载清理]=不再销毁游戏自带高亮

=== v1.8 更新内容 (2026-08-02) ===
注:此版本重做医生传送+杀戮光环+快捷建造

重构:[杀戮光环]=两个小组
小组1:杀戮光环[正常打头]
小组2:杀戮光环去血版[临时碰撞箱]
新增:攻击方式[攻击最近一个|按优先级攻击]
新增:互斥[开一个自动关另一个]

新增小组:[医生]
新增:传送悬浮窗[圆角滚动列表|缩小键|退出键]
新增:传送开关[点开=锁定跟随|高亮|自动拿起医疗用品发远程]
新增:悬浮窗大小[0.5~2倍]
新增:过滤[只列1~89%血量|脚下超过45不传|回血掉血0.5秒复查不列]
优化:自动治疗[找对医疗用品工具]
优化:自动拾取纱布[交互提示捡取]

新增:[快捷建造]
新增:路障=蒺藜=木桩[三个独立悬浮窗|可拖动]
新增:0.2秒长按拖动[快速点击放置]
新增:白色圆角描边[透明无背景]
新增:悬浮窗大小[0.5~2倍]

修复:[自动修复建筑物]=模式正确[7米范围|0.1秒扫描]
修复:[攻击回收]=取消后摇
修复:[肘击]=类型过滤[不勾选不打]
修复:[自动跳刀]=触发Swing[换武器也生效]
修复:[碰撞箱/飞行/第三人称]=死亡重生自动恢复
新增:[强制第三人称无限制版]

新增:[显示布料位置]

移除:[牧师]全部功能
移除:[军官]自动冲锋

=== v1.7 更新内容 (2026-07-30 18:40) ===
注:此版本为底层重构=性能大幅提升|僵尸再多也不卡

重构:[僵尸绘制]=全部改用Highlight高亮[普通僵尸不再用绿点]统一颜色管理
重构:[碰撞箱系统]=从17层简化到6部位[每部位1个]减少10倍部件数量
新增:[统一监听系统]=僵尸绘制和碰撞箱共享一个监听[不再各自扫各自]
优化:[事件监听]=功能关掉后自动断开所有监听[不再后台吃资源]
优化:[玩家ESP]=没人开玩家功能时不监听玩家事件
优化:[碰撞箱重生]=碰撞箱开着才监听重生[关了就不管]
优化:[防抓取]=关了自动断开重生监听
优化:[消除名称]=关了自动断开监听
修复:[ESP圆点报错]=移除了旧的绿点系统[已改用Highlight]
修复:[普通僵尸双圆点]=不再出现重复标记
修复:[碰撞箱残留]=关闭后彻底清理不留渣
修复:[监听重复]=绘制和碰撞箱合并为一个监听路径

=== v1.6 更新内容 (2026-07-30) ===
注:此版本为超大更新=新增3个菜单+职业系统+防护全家桶

添加:HOOK[菜单]
新增:强制爆头[所有近战/刺刀命中强制判定爆头]

添加:防护[菜单]
新增:防红眼扑[被红眼扑倒自动传送挣脱+攀爬防再抓]
新增:防抓取[僵尸抓取时自动向上推开]
新增:肘击自救[6格内自动斧击晕僵尸]
新增:自动格挡劈砍[工兵静默格挡斧头僵尸攻击]
新增:队友灭火[7格内自动灭队友身上的火]

添加:职业[菜单]=职业分类切换
新增小组:[通用]
自动跳刀=攻击瞬间自动跳跃[全近战武器通用]

新增小组:[工兵]
肘击僵尸类型=普通僵尸=红眼=提灯人=斧头[先选先打不选不打]
肘击=斧击击晕[距离+数量可调]
静默自动修复建筑物=自动修+自动拆[修复模式修受损建筑拆卸模式拆所有建筑血量低优先]
攻击回收=取消攻击后摇

新增小组:[军官]
自动冲锋=自动触发Charge冲锋

新增小组:[医生]
自动治疗受伤玩家=血量低于阈值自动治疗[阈值可调0-99%]
自动拾取纱布=自动捡医疗掉落
自动传送到受伤玩家=坐标传送+持续跟随[血量优先=距离优先=范围可调]

新增小组:[牧师]
自动祝福感染玩家=感染高于阈值自动祝福[阈值可调0-99%]
自动传送到受伤玩家=坐标传送+持续跟随

新增小组:[乐手]
自动强制百分百=演奏自动100%准确度

重构:绘制[菜单]=子分类切换[僵尸/玩家/地图/面板]
新增小组:[面板]=统计行/僵尸详情/职业详情/个人信息 共21个独立开关
新增:统计行=僵尸总数=玩家总数=存活人数=死亡人数
新增:僵尸详情=山伯乐=红眼=胸甲骑兵=自爆=提灯人=斧头
新增:职业详情=军官=工兵=医生=牧师=步兵=水手=乐手=枪骑兵
新增:个人信息=血量=感染=延迟
注:关闭某项自动隐藏不留空格
改名:要塞=地图[子分类]
改名:人物菜单=人物
改名:防护菜单=防护

优化:右上角提示显示名称不再显示英文id
优化:子分类标题可自定义[绘制分类/职业分类]
修复:强制爆头和碰撞箱强制爆头真正生效
修复:信息面板开关不影响子开关[子开关独立控制]
修复:碰撞箱爆头定位最外层碰撞箱
修复:自动修复建筑物无效果[缺少参数+扫描路径+判断修复拆卸模式]
修复:自动跳刀无效果[拦截PrepareSwing远程事件]
修复:牧师祝福读感染值[改为UserStates.Infected]
修复:肘击间隔改为0.1秒
修复:长按开关不再弹key文本

=== v1.4 更新内容 (2026-07-29) ===
[修复]飞行动画锁定不恢复
[修复]右上角通知只显示"开启"不显示"关闭"
[修复]新僵尸出现不自动添加碰撞箱
[修复]玩家重生后名字重新显示
[修复]自爆倒计时和自爆范围不生效
[修复]脚本重载后残留效果
[修复]强制第三人称死后不关闭
[修复]下拉滑块卡顿/手指位置偏移
[修复]收藏快捷栏无提示文字
[修复]通知刷新率过低
[新增]杀戮光环去除血迹版=60帧攻击|血迹隐藏脚下
[新增]强制爆头=近战刺刀命中判定为头
[新增]碰撞箱强制爆头=打碰撞箱范围判定爆头|血迹在碰撞箱位置
[新增]攻击墙后自爆=只攻击墙后自爆|不浪费远程事件
[新增]自爆倒计时显示=头顶3.5秒倒计时
[新增]6部位分层碰撞箱=头胸双臂双腿不均等分配
[新增]FeatureManager=统一生命周期管理
[新增]快捷栏空状态文字提示
[优化]删除旧高频光环=减少后台循环
[优化]删除传送攻击+队友救援=减少无用代码
[优化]删除State.OnLoad死代码×7
[优化]自动转向更丝滑
[优化]碰撞箱菜单独立=面板→碰撞箱→特殊→要塞→僵尸→玩家
[优化]去除血迹版攻击频率提升至60帧
[优化]强制爆头与碰撞箱强制爆头互斥开关
[优化]自爆范围刷新率0.1s
[优化]自动装备仅限近战武器
[移除]墙后自爆循环200Hz=完全无效
[移除]旧高频光环=已被去除血迹版替代
[移除]传送攻击+队友救援=无用功能

=== v1.3 更新内容 (2026-07-28) ===
注:此版本重在新增音效快捷栏和一堆杂七杂八的问题下个版本将增添新功能
重构:右上角提示重新更换动画[不知可不可以]注:后续将考虑优化
新增:[音效提示和入场提示]
新增:[快捷栏]注:这是比较实用的东西|使用方法:[开关按钮和滑动模块中间有五角星点击它变黄就行]
修复:[ESP问题]:人物重生时开启只会显示4个标签[添加了初始化]解决了这一个问题
修复:[杀戮光环]一些功能
优化:[攻击墙后自爆逻辑]确保有效果
优化:[自动装备武器]没效果
优化:[自动转向]太垃圾优化了一下

=== v1.2 更新内容 (2026-07-27) ===
修复了[输入框没效果]=目前没有任何问题😍
优化了[人物菜单]=亮度提升功能[添加监听属性遇到任何恢复亮度将会强行追踪并强行杀死或让他无限等待]
优化了右上角提示[以后右上角提示将不再固定文字限制，而是跟随文字多少进行定制]
添加:杀戮光环[菜单]
新增小组:[僵尸锁定类型]
自爆=斧头僵尸=红眼=胸甲骑兵=提灯人=山伯乐
注:[先选先打|不选不打]
新增:显示类型标签[作者调试用的]所以你们不用管🤓
新增小组:[杀戮光环特殊选项]
新增:可攻击状态才打[僵尸出生动画期间不攻击]
新增:攻击墙后自爆
新增:强制爆头
新增:传送攻击僵尸
新增:队友被扑传送攻击
新增:自动装备武器
新增:自动转向
新增小组:[Bot 杀戮光环]
新增:Bot 开关+攻击范围调节
新增小组:[高频光环]
新增:高频光环开关+攻击距离+攻击数量
新增小组:[刺刀光环]
新增:刺刀光环开关+攻击距离
【界面改进】
滑块旁边添加操作提示文字[防止某些傻逼不知道]🤓
=== v1.1 更新内容 (2026-07-26) ===
优化了一些人物菜单的问题
目前存在问题:[输入框没效果]请等待修复
新增人物菜功能如下↓↓↓
添加:移动小组
新增:[坐标加速]
新增:[人物加速]
新增:飞行功能开启功能后显示[飞行悬浮窗]
飞行:[可调节UI大小包括飞行速度]
添加:跳跃小组
新增:[手动跳跃]点击游戏跳跃按钮|可无限跳跃|无视摔伤|无视断腿| 注:不要跳太快！！！
新增:[自动跳跃]自动跳跃|无视摔伤|无视断腿
添加:视角/物品栏小组
新增:[强制第三人称]可调节0-400默认200
新增:[强制显示物品栏]某些禁用物品栏情况下强行显示使用 比如:自救灭火[前提有水桶]
添加:状态小组
新增:[高亮提升]提升亮度去除阴影
新增:[移动治疗]医生治疗时可移动[建议搭配强制显示物品栏]
新增:[无减速]人物受到伤害或者被抓或者被PVP队友扔火[无视减速]
新增:[移除摔伤]高空摔下不会摔伤减伤[太高摔断腿受着]

=== v1.0 更新内容 (2026-07-25) ===
新增：反馈菜单[可以向我反馈功能或者说意见]
新增：聊天菜单[可以跟使用同脚本玩家进行交流，后续预计添加跟随服务器包括一些神秘功能]
新增：绘制菜单[改用纯驱动监听优化大部分的性能问题包括内存消耗问题]

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

	-- 反馈/聊天页在提取版里被移除，这里留空壳：UI.RenderPage 会调用它们
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

--===== 启动 + 对外接口 =====
AddPage({
	id = 'about', title = '关于', icon = 'A', subtitle = '脚本信息',
	sections = { { title = '关于', items = {
		{ type = 'status', key = 'about.author', title = '作者', desc = 'b站英吉利超入', default = 'b站英吉利超入' },
		{ type = 'status', key = 'about.version', title = '版本', desc = '正式版 1.0.0', default = '正式版 1.0.0' },
		{ type = 'button', key = 'about.qq', title = 'QQ群（点击复制）', desc = '群号 1105244454', actionText = '复制', internal = true,
		  onChanged = function() if setclipboard then pcall(setclipboard, '1105244454') State:AddLog('INFO', '群号 1105244454 已复制', 'about.qq') end end },
	} } },
})
UI.Build()
if ConfigManager then ConfigManager:_registerCallbacks() end
local _al = ConfigManager:ReadAutoLoad()
if _al and _al ~= '' then ConfigManager:LoadConfig(_al) end

_G.QiuRongUI = {
	UI = UI, State = State, Pages = Pages, Components = Components,
	Registry = Registry, Theme = Theme, AppConfig = AppConfig,
	AddPage = AddPage, Option = Option, ConfigManager = ConfigManager,
	Notify = function(msg, level) State:AddLog(level or 'INFO', msg, 'ext.notify') end,
}
end