# 秋容UI框架 · 全面操作手册

> 提取自 `秋容脚本VIP(2).lua`（原脚本 v2.2，作者 秋容作者），已剔除全部游戏功能模块，只保留 UI 框架。
> 本手册覆盖：结构模型、全部 18 种控件、状态与数据、日志通知、收藏/搜索/存档、主题、自定义渲染、扩展方式、以及本脚本的移植约定。

---

## 目录

1. [它是什么 / 不是什么](#1-它是什么--不是什么)
2. [快速上手](#2-快速上手)
3. [结构模型](#3-结构模型)
4. [AppConfig 全局配置](#4-appconfig-全局配置)
5. [页面 Page 完整 schema](#5-页面-page-完整-schema)
6. [控件总览（18 种）](#6-控件总览18-种)
7. [逐控件字段详解 + 示例](#7-逐控件字段详解--示例)
8. [状态与数据层 State](#8-状态与数据层-state)
9. [控件实例 API](#9-控件实例-api)
10. [日志与通知](#10-日志与通知)
11. [侧边栏 / 搜索 / 收藏 / 最近](#11-侧边栏--搜索--收藏--最近)
12. [配置存档 ConfigManager](#12-配置存档-configmanager)
13. [重载保留](#13-重载保留)
14. [主题 Theme](#14-主题-theme)
15. [自定义渲染（脱离声明式）](#15-自定义渲染脱离声明式)
16. [扩展指引](#16-扩展指引)
17. [本脚本的移植约定](#17-本脚本的移植约定)
18. [坑与注意事项](#18-坑与注意事项)
19. [API 速查表](#19-api-速查表)

---

## 1. 它是什么 / 不是什么

**是**：一个**声明式**的 Roblox UI 框架。你用 Lua 表描述"有哪些页面、每个页面有哪些分区、每个分区有哪些控件"，框架负责渲染侧边栏、分区、滚动容器、动画、搜索、收藏、存档、提示。

**不是**：命令式 UI 库。没有 `Window:CreateWindow()` / `Tab:Section()` 那套链式 API。所有内容都是**数据**，通过 `AddPage({...})` 提交，最后 `UI.Build()` 一次性构建。

**关键心智模型**：

```
AppConfig（全局信息）
  └─ Pages.List[]（页面数组，决定侧边栏顺序）
       └─ page.sections[] 或 page.subcategories[].sections[]
            └─ section.items[]（控件数组）
```

---

## 2. 快速上手

最小可用骨架（框架代码之后调用）：

```lua
AddPage({
    id = "demo", title = "示例", icon = "D", subtitle = "第一个页面",
    sections = {
        {
            title = "开关区",
            items = {
                { type = "toggle", key = "demo.on", title = "总开关", desc = "开启后生效",
                  default = false, internal = true,
                  onChanged = function(v) print("开关 =", v) end },

                { type = "slider", key = "demo.size", title = "大小", desc = "1-30",
                  min = 1, max = 30, step = 1, default = 10, format = "%d层",
                  onChanged = function(v) print("大小 =", v) end },

                { type = "dropdown", key = "demo.mode", title = "模式",
                  default = "跟随", options = {
                      Option("跟随", "跟随"), Option("指定", "指定") },
                  onChanged = function(v) print("模式 =", v) end },

                { type = "button", key = "demo.run", title = "立即执行",
                  desc = "点一下跑一次", actionText = "执行", internal = true,
                  onChanged = function() print("执行了") end },
            },
        },
    },
})

UI.Build()
```

规则：
- `AddPage` 必须在 `UI.Build()` **之前**调用。
- `key` 全局唯一，是存档和取值的唯一标识。
- 想改侧边栏顺序，见 [§11](#11-侧边栏--搜索--收藏--最近)。

---

## 3. 结构模型

### 3.1 两种页面形态

**A. 扁平页面**（`sections` 直接挂页面下）：

```lua
AddPage({ id = "x", title = "X", icon = "X", subtitle = "...",
          sections = { { title = "...", items = {...} } } })
```

**B. 带子分类的页面**（顶部有分类切换条）：

```lua
AddPage({
    id = "esp", title = "绘制", icon = "E", subtitle = "...",
    subcategoryTitle = "绘制分类",          -- 分类条标题
    subcategories = {
        { id = "zombie", title = "僵尸", sections = { { title = "...", items = {...} } } },
        { id = "player", title = "玩家", sections = { { title = "...", items = {...} } } },
    },
})
```

### 3.2 特殊页面

| 形态 | 写法 | 说明 |
|---|---|---|
| 搜索页 | `dynamic = "search"` | 自动聚合全部 item，按关键字过滤 |
| 收藏页 | `dynamic = "favorites"` | 只显示被收藏的控件 |
| 空页面 + 自定义渲染 | `sections = {}` + 自己写 `RenderXxx()`，并在 `UI.RenderPage` 里 `pageId == "x"` 分支调用（见 §15） |

---

## 4. AppConfig 全局配置

```lua
local AppConfig = {
    Name = "大不列颠超入脚本-代发货大亨",
    Version = "正式版 1.0.0",
    Author = "合作:b站大不列颠超入",
    GuiName = "DropshipHubUI",       -- ScreenGui 名字（重名会被重建）
    DefaultPage = "about",           -- 启动后默认打开哪个页面
    MarqueeText = "...",             -- 顶部跑马灯
    AnnouncementTitle = "公告详情",   -- 公告弹窗标题
    AnnouncementText = [[...]],      -- 公告正文（支持长文本）
    MaxRecent = 18,                  -- "最近使用"保留条数
}
```

---

## 5. 页面 Page 完整 schema

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | string | ✓ | 唯一标识，侧边栏跳转与 `DefaultPage` 都用它 |
| `title` | string | ✓ | 侧边栏显示名 |
| `icon` | string | ✓ | 侧边栏图标字符（如 `"A"`、`"P"`） |
| `subtitle` | string | | 页面顶部副标题 |
| `sections` | table | | 分区数组（扁平页面用） |
| `subcategoryTitle` | string | | 分类条标题 |
| `subcategories` | table | | 子分类数组（每个含 `id/title/sections`） |
| `dynamic` | string | | `"search"` / `"favorites"` |

**Section schema**：

| 字段 | 说明 |
|---|---|
| `title` | 分区标题 |
| `items` | 控件数组 |

---

## 6. 控件总览（18 种）

`item.type` 决定用哪个渲染器。全部类型：

| type | 用途 | 值类型 |
|---|---|---|
| `toggle` | 开关 | boolean |
| `slider` | 滑块 | number |
| `number` | 数字输入 | number |
| `input` | 文本输入 | string |
| `dropdown` | 单选下拉 | string |
| `multi` | 多选下拉 | table（集合） |
| `segment` | 分段选择 | string |
| `button` | 按钮 | — |
| `keybind` | 按键绑定 | KeyCode |
| `color` | 颜色选择 | Color3 |
| **`status`** | **只读状态行（可实时刷新）** | string |
| `list` | 静态信息行（标题+徽章） | — |
| `progress` | 进度条 | number |
| `tags` | 标签行 | table |
| `table` | 表格 | table |
| `log` | 日志输出框 | — |
| `category` | 跳转卡片 | — |
| `collapsible` | 可折叠分组（内含 `items`） | — |

> 未知类型会被记一条 `ERROR` 日志并跳过，不会崩。

---

## 7. 逐控件字段详解 + 示例

### 7.1 toggle（开关）

```lua
{ type = "toggle", key = "pipe.on", title = "订单流水线", desc = "开启后自动跑流程",
  default = false, internal = true,
  -- 可选：带一个颜色小方块
  colorKey = "color.pipe", colorDefault = Color3.fromRGB(255, 200, 0),
  onColorChanged = function(c) applyColor(c) end,
  onChanged = function(v) cfg.pipe.on = v end }
```

字段：`key / title / desc / default / internal / colorKey / colorDefault / onChanged / onColorChanged`

### 7.2 slider（滑块）

```lua
{ type = "slider", key = "pipe.preWait", title = "传送前等待", desc = "运行时下限 0.18s",
  min = 0.10, max = 0.60, step = 0.02, default = 0.30, format = "%.2fs",
  dynamicMax = nil,     -- 可选：动态上限回调
  onChanged = function(v) cfg.pipe.preWait = v end }
```

字段：`key / title / desc / min / max / step / default / format / dynamicMax / onChanged`

### 7.3 number（数字输入）

```lua
{ type = "number", key = "x.n", title = "数量", min = 1, max = 99, step = 1,
  default = 5, format = "%d", onChanged = function(v) ... end }
```

字段：`key / title / desc / min / max / step / default / format`

### 7.4 input（文本输入）

```lua
{ type = "input", key = "cfg.name", title = "配置名称", desc = "存档名",
  placeholder = "例如: 配置1", default = "", width = nil,
  onChanged = function(v) ... end }
```

字段：`key / title / desc / placeholder / width / default`

### 7.5 dropdown（单选）

```lua
{ type = "dropdown", key = "ac.priority", title = "优先级",
  default = "价格最高优先",
  options = { Option("价格最高优先", "价格最高优先"), Option("爆款优先", "爆款优先") },
  optionsCallback = function() return dynamicOptions() end,   -- 可选：动态选项
  onChanged = function(v) cfg.ac.priority = v end }
```

`Option(label, value)` 是框架提供的构造助手。字段：`key / title / desc / default / options / optionsCallback`

### 7.6 multi（多选）

```lua
{ type = "multi", key = "ac.white", title = "商品白名单", desc = "空=全部；多选",
  default = { LedStrip = true },                 -- 值是【集合】：{[值]=true}
  options = prodOpts(),
  optionsCallback = function() ... end,
  optionLabelCallback = nil, separator = nil, isOptionDisabled = nil,
  onChanged = function(set) cfg.ac.white = set end }
```

⚠ **值形态是集合**（`selected[值] == true`），不是数组。字段：`key / title / desc / default / options / optionsCallback / optionLabelCallback / separator / isOptionDisabled`

### 7.7 segment（分段）

```lua
{ type = "segment", key = "ad.duration", title = "广告时长",
  options = { "300", "600" }, default = "600", stacked = false, width = nil,
  desc = "...", internal = true, onChanged = function(v) ... end }
```

字段：`key / title / desc / options / stacked / width / default / internal`

### 7.8 button（按钮）

```lua
{ type = "button", key = "tool.export", title = "导出配置到剪贴板", desc = "...",
  actionText = "导出", internal = true,
  confirm = true, confirmTitle = "确认导入", confirmText = "将覆盖，确定吗？",   -- 可选二次确认
  onChanged = function() exportCfg() end }
```

字段：`key / title / desc / actionText / internal / confirm / confirmTitle / confirmText / onChanged`

### 7.9 keybind（快捷键）

```lua
{ type = "keybind", key = "app.toggle", title = "开关窗口", desc = "...",
  default = Enum.KeyCode.RightShift, onChanged = function(k) ... end }
```

字段：`key / title / desc / default`

### 7.10 color（颜色）

```lua
{ type = "color", key = "color.main", title = "主色", desc = "...",
  default = Color3.fromRGB(255,255,255), presets = { Color3.fromRGB(...) },
  onChanged = function(c) ... end }
```

字段：`key / title / desc / presets / default`

### 7.11 status（只读状态行）★ 实时数值首选

```lua
{ type = "status", key = "dash.cash", title = "现金", desc = "当前现金",
  value = "—", internal = true }
```

⚠ **`value` 可以传函数**，渲染时求值 —— 这是做"实时数值"的关键：

```lua
{ type = "status", key = "dash.cash", title = "现金", desc = "...", internal = true,
  value = function() return fmt(S.cash) end }
```

更新方式二选一（或都用）：
1. `value = function()` —— 每次页面渲染重新求值（切页/重开窗口即刷新）。
2. `State.Controls[key].SetValue(str)` —— 对**当前可见**的页面做实时推送（见 §9）。

字段：`key / title / desc / value（string 或 function）/ internal`

### 7.12 list（静态信息行）

```lua
{ type = "list", key = "doc.f1", title = "订单流水线",
  desc = "接单→取货→上带→…", badge = "核心", internal = true }
```

只渲染一次，值固定。字段：`key / title / desc / badge / internal`

### 7.13 progress / tags / table

```lua
{ type = "progress", key = "p.x", title = "进度", value = 0.5, default = 0, color = nil, internal = true }
{ type = "tags",     key = "t.x", title = "标签", tags = {"A","B"}, internal = true }
{ type = "table",    key = "tb.x", title = "表格", rows = {...}, columns = {...}, internal = true }
```

### 7.14 log（日志输出）

```lua
{ type = "log", key = "tool.log", title = "操作与错误日志", desc = "最近 120 条",
  clearKey = "tool.logclear" }
```

自动显示 `State.Logs` 的内容并随 `State:AddLog` 刷新。

### 7.15 category（跳转卡片）

```lua
{ type = "category", key = "go.vip", title = "VIP 功能", desc = "点这里跳转",
  icon = "V", targetPage = "vip" }
```

### 7.16 collapsible（可折叠分组）

```lua
{ type = "collapsible", key = "doc.principle", title = "为什么稳（点开看）",
  desc = "...", locked = false, lockText = "VIP 专属",
  items = {
      { type = "status", key = "doc.p1", title = "...", value = "...", internal = true },
      { type = "list",   key = "doc.p2", title = "...", desc = "...", internal = true },
  } }
```

---

## 8. 状态与数据层 State

### 8.1 值桶（bucket）

`State:Get(kind, key, default)` / `State:Set(kind, key, value)`。`kind` → 桶名映射：

| kind | 桶 | 值类型 |
|---|---|---|
| `"toggle"` | `State.Toggles` | boolean |
| `"slider"` | `State.Sliders` | number |
| `"input"` | `State.Inputs` | string |
| `"dropdown"` | `State.Dropdowns` | string |
| `"segment"` | `State.Segments` | string |
| `"number"` | `State.Numbers` | number |
| `"color"` | `State.Colors` | Color3 |
| `"multi-dropdown"` | `State.MultiDropdowns` | table（集合） |

⚠ 注意 multi 的 kind 字符串是 **`"multi-dropdown"`**（带连字符）。

示例：

```lua
local cur = State:Get("toggle", "pipe.on", false)
State:Set("slider", "pipe.preWait", 0.35)
local set = State.MultiDropdowns["ac.white"] or {}
```

### 8.2 其它 State 成员

| 成员 | 说明 |
|---|---|
| `State.Controls[key]` | 当前**可见**页面的控件实例（切页会被清空） |
| `State.VisibleControlKeys` | 当前可见控件的 key 集合 |
| `State.Logs` | 日志数组（最新在前，上限 120） |
| `State.Favorites[key]` | 是否被收藏 |
| `State.Recent` | 最近使用列表 |
| `State.SubPages[pageId]` | 子分类当前选中项 |
| `State.CurrentPage` / `State.SearchText` | 当前页面 id / 搜索关键字 |

**重要**：`State:ClearVisibleControls()` 在每次切页时被调用，会把 `State.Controls` 清空。
所以**不要用 `State.Controls` 做长期数据存取**，只用它做「当前页实时刷新」。

---

## 9. 控件实例 API

```lua
local c = State.Controls["dash.cash"]
if c and c.SetValue then c.SetValue("9527") end      -- status：改右侧徽章文字
if c and c.GetValue then print(c.GetValue()) end
```

| 控件 | 实例方法 |
|---|---|
| status | `SetValue(str)` / `GetValue()` |
| dropdown / multi | `SetValue(v)`，另外 dropdown 有 `SetOptions(opts)` |
| 其它 | 一般由框架内部维护，通过 `State:Set(kind,key,val)` 改值再重渲染即可 |

⚠ 只有**当前显示的页面**才存在控件实例；页面不可见时 `State.Controls[key]` 为 `nil`，推送会被忽略（这是正常的，切回来时会用 `value` 函数重算）。

---

## 10. 日志与通知

```lua
State:AddLog("INFO", "已复制群号", "about.qq")
State:AddLog("ERROR", "音效加载失败", "sfx.preload")
State:ClearLogs()
```

- `AddLog` 会：写入 `State.Logs` → 刷新 log 控件 → **同时弹一个 Toast**（`UI.Notify`）。
- Toast 有 **0.25s 节流**（同 key + 同内容会合并）；最多同时 5 个。
- `level == "ERROR"` 时 Toast 变红。
- 直接调 `UI.Notify(level, message, key)` 也行（`UI.ToastRoot` 未就绪时会静默返回）。

---

## 11. 侧边栏 / 搜索 / 收藏 / 最近

```lua
-- 重排侧边栏（按 id 顺序）
local order = { "about", "pipe", "ac", "restock", "buy", "hire", "ad", "ops", "ai", "conv", "dash", "config", "tool" }
local new = {}
for _, id in ipairs(order) do
    local p = Pages.ById[id]
    if p then table.insert(new, p) end
end
Pages.List = new
if UI.Main and UI.Sidebar then
    UI.Sidebar:Destroy()
    UI.Sidebar = nil
    UI.SidebarButtons = {}
    UI.BuildSidebar(UI.Main)
    UI.UpdateSidebar()
end
```

- 每个控件右侧有收藏按钮，收藏项出现在 `dynamic = "favorites"` 页。
- 顶栏搜索框会自动在所有 item 的标题/描述里匹配（`UI.ItemTextMatches`）。
- `State:TouchRecent(key, title, page)` 手动记一条"最近使用"。

---

## 12. 配置存档 ConfigManager

| 方法 | 作用 |
|---|---|
| `:ListConfigs()` | 列出存档名 |
| `:SaveConfig(name)` | 保存当前全部控件状态 |
| `:LoadConfig(name)` | 载入存档（会触发所有 `onChanged`） |
| `:DeleteConfig(name)` | 删除 |
| `:WriteAutoLoad(name)` / `:ClearAutoLoad()` / `:ReadAutoLoad()` | 自动载入设置 |
| `:RefreshDropdown()` | 刷新"选择配置"下拉 |
| `:_collectState()` / `:_applyState(data)` | 内部：收集/应用状态（也可手动用） |

典型「存档页」结构：名称输入 → 保存按钮 → 下拉选择 → 加载/删除按钮（键名沿用：
`config.input.name` / `config.button.save` / `config.dropdown.select` / `config.button.load`）。

---

## 13. 重载保留

框架启动顺序（在 `UI.Build()` 之后）：

```lua
if ConfigManager then ConfigManager:_registerCallbacks() end     -- 预注册所有 onChanged
local al = ConfigManager:ReadAutoLoad()
if al and al ~= "" then
    ConfigManager:LoadConfig(al)
elseif _G._BFH_PRESERVE and next(_G._BFH_PRESERVE) then
    ConfigManager:_applyState(_G._BFH_PRESERVE)                  -- 恢复上一份脚本的开启状态
end
_G._BFH_PRESERVE = nil
```

- 单例：框架内部会 `rawget(_G, "BanFengHeUIFramework")`，旧实例先 `UI.Destroy()`。
- 全局停止：`_G._BFH_STOP_ALL` 是函数数组，重载时逐个执行（用来停线程、清对象）。
- 卸载：`UI.Destroy()` 会清 toast、断连接、销毁窗口。

---

## 14. 主题 Theme

`Theme.Colors.*`（`Window / Panel / PanelDeep / Control / ControlHover / Accent / AccentDim / AccentSoft / Text / TextMuted / TextDim`）、
`Theme.Font`、`Theme.Radius`（`Window / Control`）。

框架内部构造助手：`New(className, props)`、`AddCorner(obj, radius)`、`AddStroke(obj, color)`、`AddPadding(...)`。

---

## 15. 自定义渲染（脱离声明式）

适合"关于页""反馈页"这类排版特殊的页面：

```lua
AddPage({ id = "about", title = "关于", icon = "A", subtitle = "脚本信息", sections = {} })

local function RenderAbout()
    local C = UI.Content
    if not C then return end
    C:ClearAllChildren()
    C.AutomaticCanvasSize = Enum.AutomaticSize.None
    C.CanvasSize = UDim2.fromOffset(0, C.AbsoluteWindowSize.Y)
    New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = C })
    local function T(txt, sz, col)
        New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, sz or 20),
            Text = txt, TextSize = (sz or 20) - 6, Font = Theme.Font, TextColor3 = col or Theme.Colors.TextMuted,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Parent = C })
    end
    T("大不列颠超入脚本-代发货大亨", 30, Theme.Colors.Text)
    T("版本：正式版 1.0.0", 20)
end
```

然后在 `UI.RenderPage(pageId)` 里加分支：

```lua
if pageId == "about" then
    UI.Content.Visible = true
    RenderAbout()
    return
end
```

⚠ `UI.RenderPage` 里已有 `feedback` / `chat` 两个硬编码分支，提取版已把它们替换成空壳函数。

---

## 16. 扩展指引

| 想做的事 | 做法 |
|---|---|
| 加一个页面 | `AddPage({...})`，然后按需重排 `Pages.List` 并重建侧边栏 |
| 加一个控件 | 往目标 `section.items` 里追加一条 `{type=..., key=...}` |
| 加一个自定义控件类型 | 实现 `Components.XXX(parent, item)`，再到 `UI.RenderItem` 的 if 链里加一个分支；别忘了 `State:RegisterControl(item.key, {Type=..., SetValue=..., GetValue=...})` |
| 动态选项 | 用 `optionsCallback`（每次渲染调用） |
| 动态上限 | slider 的 `dynamicMax` |
| 二次确认 | button 的 `confirm / confirmTitle / confirmText` |
| 置顶/收藏 | 控件右侧收藏按钮；或把页面排到 `Pages.List` 前面 |

---

## 17. 本脚本的移植约定

移植版文件：`dropshipping_hub_qiurong.lua`

| 约定 | 说明 |
|---|---|
| 键名前缀 | 全部用 `qr.` 前缀（如 `qr.pipe.on`），避免与框架内置 `config.*` 冲突 |
| 配置唯一来源 | 仍是脚本自己的 `cfg`（存 `DropshipHub_v3.json`）；框架的存档是**额外的**快照 |
| 写入配置 | 统一走 `SET("cfg.path", value)` → 写 `cfg` + `cfgTouch()` + `guardRefresh()` |
| 读取默认值 | `default = CFG("cfg.path", 兜底)` |
| 白/黑名单 | 用 `multi`，值直接是集合，与 `cfg` 里 `{产品=true}` 形态一致 |
| 实时数值 | `ST(key, 标题, 描述)` 生成 `status` 控件，`value` 是从 `LIVE[key]` 取的函数；主循环每 0.35s 再用 `qrSet(key, text)` 推一次（对可见页生效） |
| 通知 | 旧 `Notify(title, content, icon)` 已改为兼容层 → 走 `State:AddLog("INFO", "标题 · 内容", key)` |
| 卸载 | `dispose()` 会额外调用 `_G.QiuRongUI.UI.Destroy()` |
| 页面清单 | 脚本详细 / 流水线 / 自动接单 / 补货 / 自动购买 / 自动招聘 / 自动广告 / 自动运营 / AI 调参 / 传送带 / 看板 / 存档 / 工具（共 13 页） |

---

## 18. 坑与注意事项

| # | 坑 | 后果 / 规避 |
|---|---|---|
| 1 | **`State.Controls` 只在当前页有效** | 切页会被 `ClearVisibleControls()` 清空；长期数据放 `State:Set/Get` 或你自己的配置 |
| 2 | **multi 的值是集合不是数组** | `selected[值]==true`；`default` 也要传集合 |
| 3 | **`status` 想实时刷新必须给函数或手动 SetValue** | 只给字符串就永远是静态的 |
| 4 | **参数 arity 必须读源码确认** | 例如 `Window:SetBackgroundTransparency(A,B)` 读第二个参数；`ToggleTransparency(C,F)` 读第二个 |
| 5 | **亚克力 `WindUI:ToggleAcrylic` 依赖 `AcrylicPaint`** | 它只在创建窗口时 `Acrylic = true` 才生成；否则整个函数空转 |
| 6 | **库在开窗时会自己 `ToggleAcrylic(true)`** | 想保持"关"必须做状态守夜纠偏 |
| 7 | **`UI.RenderPage` 硬编码 `RenderFeedback` / `RenderChat`** | 删除这两个函数会导致报错；提取版已留空壳 |
| 8 | **Luau 单函数 200 局部寄存器上限** | 页面定义很多局部变量时，把它们收进一张表里，或整段包进函数 |
| 9 | **`UI.Build()` 之后才能拿到 `State.Controls`** | 存档/自动载入也必须在 Build 之后 |
| 10 | **Toast 有 0.25s 同内容节流** | 同一条消息频繁触发只显示一次 |

---

## 19. API 速查表

```lua
-- 页面
AddPage(page)                    -- 注册页面
Pages.List / Pages.ById          -- 页面数组 / 索引
Option(label, value)             -- 下拉/多选选项构造

-- 状态
State:Get(kind, key, default)
State:Set(kind, key, value)
State.Controls[key]              -- 当前页控件实例（SetValue / GetValue）
State:AddLog(level, message, key)
State:ClearLogs()
State:IsFavorite(key) / State:SetFavorite(key, on)
State:TouchRecent(key, title, page)

-- 通知 / 界面
UI.Notify(level, message, key)
UI.Build() / UI.Destroy()
UI.RenderPage(pageId) / UI.RenderItem(parent, item, forceChildren)
UI.BuildSidebar(parent) / UI.UpdateSidebar()
UI.Content                       -- 当前内容滚动框（自定义渲染用）

-- 存档
ConfigManager:SaveConfig(n) / LoadConfig(n) / DeleteConfig(n) / ListConfigs()
ConfigManager:WriteAutoLoad(n) / ClearAutoLoad() / ReadAutoLoad() / RefreshDropdown()

-- 构造助手
New(className, props)  AddCorner(obj, r)  AddStroke(obj, color)  AddPadding(...)
Theme.Colors.* / Theme.Font / Theme.Radius.*
```

---

*本手册依据 `秋容脚本VIP(2).lua`（v2.2）源码逐段核对编写，控件字段表由 `Components.*` 实现反查得出。*
