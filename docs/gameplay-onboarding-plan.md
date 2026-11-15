# 《深蓝回声 · Abyssal Echo》游戏玩法说明与引导操作实施文档

- 编制日期：2026-11-15
- 当前状态：已完成 G0–G4 代码实施与字体子集同步（工作区待检状态，未提交代码）
- 核对基线：`9397993f0c219cb9b60a08637ed776d06f7a9fd6`
- 适用平台：Windows / macOS 桌面端与 Web（WebGL2）双端，兼容键鼠、触摸屏与 Xbox / PlayStation 手柄

---

## 1. 背景与现状诊断

《深蓝回声 · Abyssal Echo》目前已具备体量完整的开放海域玩法矩阵（1800m × 1800m 九大无缝海域、双游戏模式、声呐与等深线海图跃迁、矿物采集与逃生舱制造台、4 类武器与蓄力静滞场、单手能量护盾、无人机三星活捕与班乔寿司吧/玛琳卡图鉴/柯布拉商店、20 槽位猛兽与领主契约驯服、6-DOF 深潜艇驾驶，以及四大领主与极渊母树终章）。

结合现有代码实现（`scripts/game.gd`、`scripts/hud.gd`、`scripts/input_controller.gd`、`scripts/touch_controls.gd`），当前在新手上手与玩法认知层面存在以下核心缺口：

| 维度 | 现状代码表现 | 玩家体验痛点 |
| --- | --- | --- |
| 开局提示瞬时消逝 | `scripts/game.gd` 的 `_start()` 仅触发一条持续 `3.6s` 的 `hud.toast(...)` 单行提示，塞入 4–5 个快捷键说明 | 刚进入海底尚未适应视角与移动，提示已淡出消失，信息密度过高且无法回看 |
| 情境 HUD 过早隐去方向 | `scripts/hud.gd` 中 `_detail_time` 初始仅 `5.0s`，归零后进入 `quiet_explore` 静谧态，`mission_title` / `mission_detail` 自动隐藏 | 初次游玩的玩家在开局 5 秒后失去明确行动目标，不知道如何上浮补氧、声呐探图或推进主线 |
| 缺少游戏内玩法百科 | `menus` 仅有 `controls`（灵敏度/死区/触控尺寸设置），标题菜单、暂停菜单与快捷面板均无玩法说明入口 | 玩家在游戏内无法查阅捕鱼星级（`★`–`★★★`）规则、蓝光枪 3 秒蓄力静滞、残血领主驯服、超重管理及终章条件，只能退出查外部 `README.md` |
| 缺少实操交互式引导 | 无分步动作检测与进度反馈，也无中后期机制首次解锁提示 | 新玩家容易忽略 `Ctrl` 下潜、`F` 探照灯色彩还原、`C` 单手护盾、`V` 无人机活捕、`O`/`Z` 战宠编队等核心操作 |
| 多设备认知断层 | 虽然 `hud.format_input_text()` 支持动态按键文本替换，但缺少面向手柄/触屏组织的分模块玩法导览 | 触屏与手柄玩家难以快速建立“快捷操作面板 + 组合动作 + 海图手势”的完整心智模型 |

---

## 2. 设计目标与核心原则

1. **“实操渐进引导 + 随时查阅手册 + 情境首次微提示”三层互补**：
   - **第一层（潜航指南手册 `screen = "guide"`）**：结构化覆盖全部玩法系统与按键说明，在主菜单、暂停菜单、快捷面板及游戏中均可一键打开查阅。
   - **第二层（初航 6 步实操引导 `OnboardingChecklist`）**：首次开局时以非阻断式侧边日志卡片引导玩家亲手完成基础潜航、照明/护盾、声呐、海图、采集补给与制造台操作；动作达成自动推进，支持随时跳过与随时重温。
   - **第三层（情境首次微提示 `ContextualTips`）**：将蓄力静滞驯服、三星活捕、超重售鱼、前哨激活、潜艇驾驶等中后期机制延后至玩家**首次实际接触对应场景/装备时**按需点拨，避免开局信息轰炸。
2. **严守 ABZÛ 静谧海洋美学与情境 HUD 契约**：
   - 潜航实操过程中**绝不弹出阻断移动或抢占鼠标焦点的模态弹窗**（避免破坏水下沉浸感及 Web 端 Pointer Lock 鼠标锁定状态）。
   - 初航引导全部完成或玩家主动跳过后，左上角区域立即交还给原有情境 HUD（`quiet_explore` 自动淡出），确保安静巡游时画面通透纯净。
3. **双模式与三端输入原生适配**：
   - 引导步骤根据玩家选择的 **自由探险（`explore`）** 与 **生存航程（`survival`）** 自动调整目标文案与完成判定（例如探险模式不强制引导氧气危机，生存模式重点强调安全区/巨砗磲补氧）。
   - 所有引导卡片与指南正文统一接入 `hud.format_input_text()` 与 `input_controller.hint()`，在键鼠、触屏、手柄切换时即时刷新对应键位/手势图标提示。
4. **零外部资产依赖与严守工程门禁**：
   - 视觉完全复用 `scripts/presentation/ocean_ui_theme.gd` 的海洋玻璃面板、珍珠白排版与琥珀金点缀，保持 34 项 `.glb` 模型零改动，满足字体子集、双分辨率无重叠及 Web 单文件 `<= 5 MiB` 门禁。

---

## 3. 功能架构与交互设计

### 3.1 第一层：结构化【潜航指南 / 玩法说明】面板（`screen = "guide"`）

在 `HUD.menus` 中新增 `"guide"` 全屏菜单页，采用**左侧章节导航栏 + 右侧滚动内容卡片**的双栏海洋仪器布局（小屏下外层由现有 `_prepare_menu_scrolling()` 自动包裹 `AccessibleScroll` 保证完整可达）。

#### 入口设计（全设备可达）
- **标题主菜单（`main`）**：在「操作设置 / 触摸屏与手柄」上方或并列新增 **「玩法说明 / 潜航指南」** 按钮，让新玩家在开局前即可预览模式差异与核心玩法。
- **暂停菜单（`pause`）**：新增 **「L / 潜航指南」** 按钮（与「操作设置」并列或置于海图按钮下方）。
- **快捷操作面板（`quick`）**：在 `QUICK_ACTIONS` 及底部操作区加入 **「潜航指南」** 入口，确保纯触屏与手柄玩家无需键盘即可打开。
- **操作设置页（`controls`）**：增加 **「查看潜航指南」** 与 **「重置新手引导」** 快捷按钮。
- **游戏内快捷键**：新增动作 `gameplay_guide`，默认绑定键盘 **`L`**（潜航日志/指南，规避浏览器功能键冲突）并兼容 **`F1`** 与 **`/`（`?`）**；Web 端在 `assets/web/custom_shell.html` 拦截 `F1` 浏览器默认帮助行为。
- **原路返回机制**：仿照 `controls_return_screen` 增加 `guide_return_screen`，从标题页、暂停页、快捷面板或实机游玩中打开后，按 `Esc` / 手柄 `B / ○` / 点击「返回」均精准回到来源页面。

#### 七大指南章节规划

| 章节编号与标题 | 核心说明内容（精炼分条 + 动态键位标签） | 重点突出机制 |
| --- | --- | --- |
| `01` **潜航基础与双模式** | `WASD` 推进转向、`空格 / Ctrl` 升降、`Shift` 冲刺、`F` 探照灯色彩还原、`H` 助推器、`K`/右键多角度观赏；对比**自由探险**（无限氧/免伤/全畅游）与**生存航程**（90s 氧气/深水增压/就地苏生） | 上浮水面、母港 7m 内、已激活前哨站及发光巨砗磲（`E`）四大补氧途径 |
| `02` **海图勘测与洋流跃迁** | 1800m × 1800m 九大海域与 0–600m 五层生态；`N` 广域声呐脉冲揭示周边迷雾与隐藏目标；`M` 全域等深线海图缩放、标点导航与快速跃迁 | 靠近 6 座科考前哨站按 `E` 激活中继塔，解锁安全区、野外制造与传送节点；收集 12 处远古遗珍晋升五阶探索家头衔 |
| `03` **采集、制造与成长** | 准星对准钛、铜、石英、海藻按 `E` 采集；击败巨鲨/鮟鱇拾取齿骨与晶核现场吸收加攻；按 `Tab` 打开逃生舱制造台解锁氧气瓶、脚蹼、循环呼吸器、`Q` 涡流突进与深铸强化 | 制造台支持**「追踪配方」**，置顶在 HUD 右上角实时核对材料缺口 |
| `04` **深海武装与能量护盾** | `1` 战术刀（快刺）、`2` 破拆战斧（165° 横扫击退）、`3` 蓝光静滞枪（短按 `R` 激光，**长按 3 秒松开**发射静滞球冻结 12m 内生物，`T` 瞄准，`Y` 8× 测距镜）、`4` 光标指示枪（红点集火） | `C` 键展开左臂**单手能量护盾**，100% 格挡前方撕咬伤害，且可与右手任意武器同时使用 |
| `05` **三星捕捞与深海料理** | 渔获星级判定：`★☆☆` 重武/激光击杀、`★★☆` 战术刀刺杀、`★★★` 静滞受控捕获或按 `V` 召唤**柯布拉无人机浮力袋**无损回收；按 `B` 进入班乔寿司吧、玛琳卡 13 物种图鉴与柯布拉商店 | 背包具真实重量（`kg`），超重会降低移速；可在 `B` 面板烹饪获取永久属性加成，或一键售出富余渔获清空负重 |
| `06` **猛兽驯服与深海潜艇** | 普通猛兽静滞后靠近按 `E` 驯服；四大深渊领主需削减至 **35% 生命以下** 再静滞按 `E` 缔结契约（上限 20 只，队伍伤害按 `2^(N-1)` 倍增，双向免伤）；`G` 骑乘、`5–0` 选宠、`O` 应援板、`Z` 一键召回 | 碧蓝晶簇海盆与深渊造船厂停泊深潜艇，靠近按 `E` 登舰，具备耐压装甲与脉冲炮/车载鱼雷 |
| `07` **四大领主与终章逃生** | 征服或驯服四大深渊领主（深渊水龙、风暴飞鱼、深渊巨章、远古灵龟）解除封印 → 极渊苏醒 70m 远古深海母树 → 深入母树圣所收集三大核心圣物 → 返回母港中央逃生控制台按 `E` 制作【深海跃迁逃逸器】 | 达成任意里程碑或终章后，均可选择【继续探索】返回开放海域自由漫游 |

> 指南面板底部固定提供：**「重温初航实操引导」** 按钮（重置 6 步实操引导并立即进入/返回潜航）与 **「操作灵敏度与触控设置」** 跳转按钮。

---

### 3.2 第二层：非阻断式【初航 6 步实操引导】（`OnboardingChecklist`）

针对首次进入游戏的玩家，在 `FlightInstruments` 左上角潜航日志区下方（或与潜航日志区联动托管）挂载紧凑型半透明引导卡 `OnboardingCard`，引导玩家在 1–2 分钟内通过真实操作掌握核心闭环。

#### 步骤流转与完成判定表

| 步骤 | 阶段标题 | 实时操作指引文案（支持设备动态替换） | 判定完成条件（代码检测信号/阈值） | 模式差异化处理 |
| --- | --- | --- | --- | --- |
| `Step 1` | **立体潜航与视野** | 推动 `WASD` 向前巡游，移动视角观察四周，并用 `空格` 上浮、`Ctrl` 下潜 | 累计水平位移 `>= 8.0m` 且累计垂直高度变化 `>= 1.5m` | 双模式一致（Web 端若尚未捕获鼠标，副标题温和提示“点击画面锁定视角”） |
| `Step 2` | **深海照明与护盾** | 按 `F` 开启潜水探照灯还原礁石色彩，或按 `C` 展开单手能量护盾（按住 `Shift` 可加速游动） | 触发一次 `lamp` 切换 **或** 触发一次 `toggle_shield` 展开 | 双模式一致 |
| `Step 3` | **广域声呐勘测** | 按 `N` 释放声呐勘测脉冲，扫描周边迷雾中的地标、前哨站与远古遗珍 | `_trigger_sonar_ping()` 成功释放一次声呐脉冲 | 双模式一致 |
| `Step 4` | **等深线海图导航** | 按 `M` 打开全域海图查看已点亮海域（可选点设标或查看跃迁点），再按 `M` 或 `Esc` 返回潜航 | 曾进入 `screen == "map"` 且随后返回 `screen == "play"` | 双模式一致 |
| `Step 5` | **海底采集与补给** | *生存*：对准礁石矿物、小金鱼或发光巨砗磲按 `E` 采集/补氧（母港 7m 内自动补氧）<br>*探险*：靠近矿物、遗珍或前哨站按 `E` 互动，或按 `3` 切换蓝光静滞枪体验射击 | *生存*：成功执行一次矿物采集、捕食小金鱼、触发巨砗磲或激活前哨站<br>*探险*：上述任一 `E` 交互成功，或切换至 `sonic` 并发射一次 | 按 `state.mode` 自动分支文案与判定条件 |
| `Step 6` | **工作台与潜航指南** | 按 `Tab` 查看装备制造台与配方追踪（或按 `B` 查看料理与三星图鉴）；随时可按 `L` 打开潜航指南 | 打开过一次 `craft`、`sushi` 或 `guide` 界面 | 达成后展示 `2.5s`「✦ 初航引导已完成 · 祝旅途愉快」完成态并平滑淡出，永久移交情境 HUD |

#### 交互细节与防打扰设计
- **乱序预完成兼容（Graceful Fast-Forward）**：若老手在 `Step 1` 期间已经顺手按了 `N` 声呐或开了 `M` 海图，状态机记录对应能力已掌握，轮转到对应步骤时自动顺延或合并跳过，绝不强迫玩家重复机械操作。
- **一键跳过与随时重开**：
  - 引导卡片底部附带低调提示：`L 潜航指南 / 跳过引导`；在 `guide` 面板、`pause` 菜单与 `quick` 面板中均可一键点击「跳过当前引导」或「重新开始初航引导」。
- **危险与战斗态自动退让**：
  - 当处于 Boss 激战（`fighting == true`）、远距瞄准镜开启（`scoped == true`）或氧气危急（`low_oxygen == true`）时，`OnboardingCard` 自动临时降低透明度或收起让位，待危机解除后再平滑恢复，绝不干扰生存判断。

---

### 3.3 第三层：情境式【首次机制微提示】（`ContextualTips`）

为避免新手阶段灌输过多高阶机制，建立基于事件触发的一次性微提示队列（复用优化后的 `hud.toast` 或引导条，每条提示带 `[潜航提示]` 前缀，持久化记录于 `seen_tips`，同一存档不重复打扰，且设有至少 `12s` 的最小冷却间隔防止多提示连发）：

| 提示 ID | 触发时机 | 提示内容摘要 |
| --- | --- | --- |
| `tip_sonic_charge` | 首次切换至 `3` 号蓝光静滞枪 | 短按 `R` 发射激光；**按住 3 秒后松开**发射静滞球冻结范围内生物，`T`/`Y` 切换瞄准镜 |
| `tip_tame_or_salvage` | 首次用静滞场冻结可驯服猛兽或残血（`<35%`）领主 | 目标已静滞！靠近按 `E` 可缔结契约驯服为伙伴，或按 `V` 召唤无人机气球无损活捕（`★★★`） |
| `tip_sushi_marinca` | 首次捕获满 2 份鱼类/生肉食材且处于非战斗状态 | 已获得深海食材 · 按 `B` 可在班乔料理吧制作属性料理，并点亮玛琳卡三星图鉴加成 |
| `tip_overweight` | 首次触发背包超重（`state.is_overweight()`） | 背包负重超限已减缓泳速 · 按 `B` 可一键料理售出富余渔获，或在商店购买扩容生态箱 |
| `tip_outpost_discover` | 首次进入未激活科考前哨站 `24m` 范围内 | 发现远洋科考前哨站 · 靠近中继塔按 `E` 激活，即可解锁前线补氧区、制造台与海图跃迁 |
| `tip_submarine_dock` | 首次进入深潜艇 `18m` 范围内 | 发现深海潜艇 · 靠近按 `E` 登舰驾驶，具备高耐压装甲与车载武器系统 |
| `tip_marker_command` | 拥有至少 1 只出战契约伙伴且首次切换至 `4` 号指示枪 | 扣动扳机用激光红点标记目标，可指挥全部契约伙伴集火围攻；按 `Z` 一键召回列队 |

---

## 4. 技术落点与模块划分

为保持现有核心脚本职责清晰、便于独立单元测试，采用“独立状态模块 + 轻量 UI 视图组件 + 最小侵入式钩子”的代码组织方案：

### 4.1 新增文件规划

1. **`scripts/gameplay_guide.gd`（纯逻辑与数据层，`extends RefCounted`）**
   - **常量数据**：定义 `GUIDE_CHAPTERS`（7 大章节标题、副标题、结构化条目数组、关联快捷键标签）、`ONBOARDING_STEPS`（6 步实操定义与双模式文案）、`CONTEXTUAL_TIPS`（7 条情境微提示定义与冷却参数）。
   - **运行状态机**：维护 `onboarding_completed: bool`、`onboarding_skipped: bool`、`current_step_index: int`、`completed_flags: Dictionary`（支持乱序动作记录）、`seen_tips: Dictionary`、移动与升降采样累计量（`horiz_moved`、`vert_moved`）及提示冷却计时器 `tip_cooldown`。
   - **核心接口**：
     - `load_state(persist_path := "user://onboarding_state.cfg")` / `save_state()`（支持传入 `persist = false` 供自动化测试无副作用运行，对齐 `scripts/input_controller.gd` 的持久化规范）；
     - `start_or_resume_for_voyage(mode: String)`：新航程启动时初始化步骤文案分支；
     - `record_motion(delta_pos: Vector3)`：统计水平与垂直位移推进 `Step 1`；
     - `notify_event(event_id: String, context: Dictionary = {}) -> Dictionary`：统一接收动作事件，返回 `{"step_advanced": bool, "completed_now": bool, "tip_text": String}`；
     - `skip_onboarding()` / `reset_onboarding()`：一键跳过与重温重置。

2. **`scripts/presentation/guide_panel.gd`（指南面板 UI 构建器，`extends RefCounted`）**
   - 遵循 `scripts/presentation/ocean_ui_theme.gd` 的配色与样式约定（`Art.PAPER`、`Art.MUTED`、`Art.CYAN`、`Art.AMBER`、`Art.PANEL`，全部正文字号 `>= 14px`）。
   - 构建 `960 × 700` 居中海洋玻璃卡片（纳入 `hud.menu_min_sizes["guide"] = Vector2(992, 732)`）：
     - **左栏（宽 `248px`）**：7 个章节切换按钮（选中态使用 `OceanUiTheme.button(btn, true)` 琥珀金高亮）+ 当前初航引导状态摘要；
     - **右栏（宽 `664px`）**：章节主标题、核心机制要点卡片列表、键鼠/手柄/触屏三端对照速查块；
     - **底栏**：`「重温初航引导」`、`「跳过当前引导」`（仅引导进行中可用）、`「操作设置」`、`「返回」` 四个标准焦点按钮。
   - 所有含按键名的文本节点不打 `_no_hint` 标记（纯装饰英文标题除外），自动享受 `hud._apply_device_hints()` 的实时设备键位转换与 `_refresh_navigation()` 的手柄十字键焦点图构建。

3. **`tests/gameplay_guide.gd`（专项自动化测试，`extends SceneTree`）**
   - 独立验证 `GameplayGuide` 状态机（双模式 6 步顺序与乱序推进、跳过/重置、`ConfigFile` 读写持久化、情境提示去重与冷却）以及 `HUD` 中 `"guide"` 面板切换、`OnboardingCard` 布局安全区与静谧 HUD 退让行为。

### 4.2 现有文件最小修改点（后续实施阶段执行）

| 目标文件 | 计划接入内容 | 风险与兼容控制 |
| --- | --- | --- |
| `scripts/input_controller.gd` | 在 `ACTIONS`、`MENU_ACTIONS`、`KEY_HINTS`、`ACTION_LABELS`、`PAD_HINTS` 注册 `"gameplay_guide"`（键位提示 `"L / F1"`，触屏/手柄标签 `"潜航指南"`） | 不改动任何既有动作名称与按键绑定，确保 `tests/input_controller.gd` 零回归 |
| `scripts/hud.gd` | 1) 构建 `menus["guide"]` 与左上角 `OnboardingCard`；<br>2) 在 `main`、`pause`、`quick`、`controls` 增加指南/重温入口并发射信号；<br>3) 在 `update_hud()` 接收可选 `"onboarding"` 字典控制 `OnboardingCard` 显隐，并在 `_apply_layout()` / `_layout_toast()` 加入防重叠计算；<br>4) `_hint_regex` 安全支持 `F1` / `L` 提示转换 | 当 `data` 未传入激活的 `"onboarding"`（如旧有单元测试直接调用 `HUD.new()`）时，`OnboardingCard` 默认隐藏，100% 保持 `tests/presentation_context.gd` 既有静谧淡出断言通过 |
| `scripts/game.gd` | 1) 实例化 `gameplay_guide` 并连接 `hud` 的打开指南、跳过引导、重温引导信号；<br>2) 在 `_setup_input()` 绑定 `KEY_L`、`KEY_F1`、`KEY_SLASH` 至 `gameplay_guide`，在 `_set_screen()` 将 `"guide"` 纳入暂停菜单集合并维护 `guide_return_screen`；<br>3) 在 `_start()`、`_physics_process()` 位移采样、照明/护盾/声呐/海图/交互/制造/切枪/静滞/靠近前哨与潜艇处调用 `gameplay_guide.notify_event(...)` | 开局 `_start()` 当初航引导激活时不再弹冗长单行 `toast`，改为简洁欢迎词配合左上角分步引导卡；老存档已完成引导时保留清爽开局提示 |
| `assets/web/custom_shell.html` | 在键盘监听中对 `F1` 调用 `event.preventDefault()`，防止桌面浏览器弹出系统帮助页 | 仅拦截 `F1`，不影响 `F5` / `F11` / `F12` 等浏览器调试与刷新快捷键 |
| `assets/fonts/NotoSansSC-Subset.otf` | 新增文案定稿后，通过 `tools/subset_font.py` 基于 SIL OFL 授权的 `NotoSansCJKsc-Regular.otf` 重新生成字体子集 | 严禁混入非开源系统字体；构建后校验全部脚本字符 `has_char()` 覆盖率 100% |
| `docs/input-controls.md` & `README.md` | 同步补充 `L / F1` 潜航指南快捷键与新手引导说明 | 保持文档与实机键位表完全一致 |

---

## 5. 关键工程约束与避坑细则

1. **子集字体缺字防线（必检项）**：
   - 仓库内 `assets/fonts/NotoSansSC-Subset.otf` 仅打包了当前 `scripts/**/*.gd` 与 `tools/art_report.py` 出现过的汉字码点（参见 `tools/subset_font.py`）。
   - 若新增指南与引导文案后未重跑字体子集构建，新出现的汉字在桌面与 Web 端均会显示为空白或方框。
   - 实施时需先确认 `.tools/NotoSansCJKsc-Regular.otf`（官方开源 Noto Sans CJK SC Regular）就绪，运行 `python tools/subset_font.py .tools/NotoSansCJKsc-Regular.otf` 更新 `assets/fonts/NotoSansSC-Subset.otf`，并在测试中遍历 `scripts/` 全部非注释字符串断言字体包含全部字符。
2. **`_hint_regex` 误替换防线**：
   - `scripts/hud.gd` 中的 `_hint_regex` 会自动扫描单字母按键（如 `R`、`E`、`M`、`N`、`G`、`C` 等）替换为手柄/触屏提示。
   - 若将 `L` 加入正则，必须附带负向先行断言排除英文单词与单位（如 `Lv.1` 等级缩写中的 `L` 已因后接 `v` 被 `(?![A-Za-z0-9₂:])` 排除，但仍需在测试中补充 `"餐厅声望 Lv.2 · 按 L 查看指南"` 的转换断言）。
3. **双分辨率与触控安全区零重叠**：
   - 在桌面 `1280×800`、`1920×1080` 及触屏紧凑高度（`< 650px`，如 `844×390`、`640×360`）下：
     - 触屏布局（`_touch_layout == true`）时，`LifeSupportInstrument` 会上移至 `y = 96` 或 `144`（见 `scripts/hud.gd:1538`）以避让左下角虚拟摇杆！
     - 因此 `OnboardingCard` 在 `_touch_layout == true` 时**绝不能放在左上角 `y = 96~240` 与生命面板冲突**，而应自动重排至顶部罗盘下方居中偏右或紧凑单行条（并在 `< 420px` 超矮横屏战斗态可折叠），通过矩形相交断言（`not rect_a.intersects(rect_b)`）严格验证。
4. **Web Pointer Lock 与暂停状态一致性**：
   - 打开 `"guide"` 面板时，`get_tree().paused = true` 且 `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`；
   - 关闭 `"guide"` 返回 `"play"` 时，沿用 `_sync_input_presentation()` 与 `_unhandled_input()` 现有的点击重捕获 Pointer Lock 逻辑，不引入悬空焦点或误开火（`_cancel_attack_input()` 在切屏时同步清理蓄力状态）。

---

## 6. 分阶段实施计划

后续确认开始修改后，按 **G0 → G4** 五个原子阶段推进，每阶段均可独立验证：

### 阶段 G0：状态机与指南内容库搭建
- **工作内容**：
  - 新建 `scripts/gameplay_guide.gd`，录入与当前代码数值严格对齐的 7 大章节说明数据、6 步初航引导定义及 7 条情境首次提示；
  - 实现事件驱动推进、乱序动作记忆、模式自适应分支与 `user://onboarding_state.cfg` 持久化读写。
- **阶段产出**：`scripts/gameplay_guide.gd`，可在无渲染环境下直接运行状态机单测。

### 阶段 G1：潜航指南面板（`guide`）与多入口接入
- **工作内容**：
  - 新建 `scripts/presentation/guide_panel.gd`，完成双栏章节浏览、三端键位速查与重温/跳过控制按钮；
  - 在 `scripts/input_controller.gd` 与 `scripts/game.gd` 注册 `gameplay_guide`（`L` / `F1` / `/`）与 `guide_return_screen` 返回栈；
  - 在 `scripts/hud.gd` 的标题主菜单（`main`）、暂停菜单（`pause`）、快捷面板（`quick`）和操作设置（`controls`）接入入口按钮，并配置 `menu_min_sizes["guide"]` 响应式滚动与手柄焦点导航。
- **阶段产出**：在主菜单与游戏内任意时刻可通过键鼠、触屏、手柄打开/浏览/关闭完整的【潜航指南】。

### 阶段 G2：初航 6 步实操引导卡与情境首次微提示联调
- **工作内容**：
  - 在 `scripts/hud.gd` 实现 `OnboardingCard` 组件，完成桌面端、触屏布局（`_touch_layout`）与 `toast_label` / `boss_panel` / `LifeSupportInstrument` 的动态避让布局；
  - 在 `scripts/game.gd` 挂载移动升降采样、声呐、海图、照明/护盾、交互采集、制造台、武器切换、静滞驯服、超重、前哨与潜艇接近钩子；
  - 验证引导完成/跳过后无缝移交 `quiet_explore` 静谧 HUD。
- **阶段产出**：新档首次下水可完整走通 6 步实操教学，中后期首次接触关键机制时精准弹出一次性点拨。

### 阶段 G3：开源字体子集更新与 Web 壳层细节同步
- **工作内容**：
  - 使用 SIL OFL 授权的 `NotoSansCJKsc-Regular.otf` 执行 `tools/subset_font.py` 重建 `assets/fonts/NotoSansSC-Subset.otf`；
  - 在 `assets/web/custom_shell.html` 补充 `F1` 默认行为拦截；
  - 同步更新 `docs/input-controls.md` 与 `README.md` 操作键位表。
- **阶段产出**：双端所有新增中文字符与符号清晰渲染无缺字，Web 端快捷键无浏览器弹窗干扰。

### 阶段 G4：自动化测试扩充与双端回归验收
- **工作内容**：
  - 编写并运行 `tests/gameplay_guide.gd`；
  - 在 `tests/input_ui.gd` 增加 `"guide"` 屏幕焦点闭环、小分辨率裁剪滚动与 `_hint_regex` 转换用例；
  - 在 `tests/art_ui_visual.gd` 增加 `"guide"` 与 `"onboarding"` 双分辨率（`1280×800`、`1920×1080`）状态截图与零重叠检查；
  - 运行现有核心测试套件（`smoke.gd`、`presentation_context.gd`、`input_controller.gd`、`touch_controls.gd`、`open_world_exploration.gd`）与 Web 构建检查（`tools/build_web.mjs`）。
- **阶段产出**：全量测试 0 错误通过，桌面与 Web 构建产物符合包体与性能门禁。

---

## 7. 验收标准清单

1. **功能完整性**：
   - 新玩家（无 `user://onboarding_state.cfg`）进入自由探险或生存航程后，左上角自动开启 6 步初航实操引导，每步通过实际游玩动作即可顺畅核销推进；
   - 完成或跳过引导后重进游戏不再重复弹出引导卡；点击「重温初航引导」可随时重新体验；
   - 【潜航指南】7 大章节完整涵盖移动、双模式补氧、声呐海图跃迁、采集制造追踪、武器蓄力与单手护盾、三星活捕与寿司图鉴、猛兽驯服与潜艇、四大领主与母树终章，且所有数值与代码实机逻辑一致。
2. **多端输入与无障碍**：
   - 键鼠、触摸屏、手柄三种输入设备均可独立打开/浏览/切换指南章节并关闭返回，焦点不丢失、不越出当前屏幕；
   - 切换输入设备时，引导卡与指南中的按键提示实时切换为对应设备键位名；小屏幕（如 `844×390`、`640×360`）可通过滚动完整操作全部章节与底部按钮。
3. **视觉、字体与性能门禁**：
   - `1280×800`、`1920×1080` 及触控模式下，`OnboardingCard` 与生命支持仪、顶部罗盘、Boss 血条、发现 Toast 及虚拟摇杆均无矩形重叠；
   - 新增文案在 `NotoSansSC-Subset.otf` 中覆盖率达 100%，无任何缺字方块；
   - 既有情境 HUD 测试（`tests/presentation_context.gd`）、输入测试（`tests/input_ui.gd`）与冒烟测试全部通过，Web 构建单文件体积保持 `<= 5 MiB`。

---

## 8. 实施落地摘要

已在当前工作区完成 G0–G4 全阶段实现（保持未提交状态供检视）：

- **引导状态机与指南内容库**：`scripts/gameplay_guide.gd`（7 大章节百科数据、6 步双模式初航实操状态机、乱序动作记忆、7 项情境首次提示冷却与 `user://onboarding_state.cfg` 持久化）。
- **海洋玻璃指南面板组件**：`scripts/presentation/guide_panel.gd`（`960 × 700` 双栏布局、章节切换、三端动态按键提示适配、重温/跳过/设置/返回焦点按钮）。
- **HUD 与主循环接入**：`scripts/hud.gd`、`scripts/game.gd`、`scripts/input_controller.gd`、`assets/web/custom_shell.html`（标题页/暂停页/快捷面板/设置页入口，`L / F1 / ?` 快捷键与返回栈，左上角 `OnboardingInstrument` 桌面与触屏自适应防重叠布局，全链路游玩事件埋点与 Web `F1` 默认行为拦截）。
- **字体子集与文档测试同步**：基于 SIL OFL 授权的 `Noto Sans SC` 更新 `assets/fonts/NotoSansSC-Subset.otf`（`308,104 B`，1,333 个字形，与 fallback 字体链合集对新增引导与指南字符覆盖率 100%），同步更新 `docs/input-controls.md`、`README.md`，并新增/扩充 `tests/gameplay_guide.gd`、`tests/input_ui.gd`、`tests/art_ui_visual.gd`。
