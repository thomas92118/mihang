# 《深蓝回声》ABZÛ 风格美术优化实施计划

- 编制日期：2026-11-13。
- 状态：已完成 P0–P6 实施与双端验收（工作区待检状态，未提交代码）。
- 核对基线：`3f29f2ac8645dad3a810af1b8f6d6426ee2efe36`。
- 目标：以 ABZÛ 宣传画面的造型、色彩、空间与生命节奏为参考，提升现有游戏的视觉统一度与完成度。

## 1. 美术目标

确定为“插画感的风格化 3D 海洋幻想冒险”：通透蓝青水体、简洁流畅的剪影、大面积有组织的色块、柔和而有主次的光影、舒展的游泳姿态，以及参与构图的鱼群。

采用原创潜水员、科考装备与遗迹设计，把参考转化为本项目的视觉规则：

| 视觉规则 | 实施方向 | 判断方法 |
| --- | --- | --- |
| 剪影先行 | 主角身形流畅，气瓶与躯干形成完整轮廓；岩体、珊瑚、建筑各有形态语言 | 缩成缩略图、转成黑色剪影后仍能辨认对象 |
| 色彩有主次 | 用大面积蓝青组织环境，暖沙作为次色，珊瑚暖色与装备金色集中点缀 | 缩小画面后，主角和主景仍是明确焦点 |
| 水体具有空间 | 近景、中景、远景在明度、对比度与颜色上分层，光束连接亮区与暗部 | 灰度图中仍能区分三层空间 |
| 场景具有呼吸感 | 大形体框景、连续游泳通道、成簇生态与开阔水体相互配合 | 主要游玩视角中，主景轮廓完整、通道清晰 |
| 动态具有韵律 | 身体、手臂、脚蹼协调；鱼群有聚散、相位和方向变化 | 连续观察巡游、转向与穿越鱼带时没有机械同步感 |

参考来源：[ABZÛ 官网](https://abzugame.com/)、[官网游戏宣传图](https://freight.cargo.site/t/original/i/5562ebf161ade095b1c9c6f56de74827f1b3f9eaf839a95c39914f66194f5484/vid1.jpg)。本文对该风格的描述属于视觉分析。官网 Inspiration 栏的水下摄影与游戏宣传图分开归档。宣传镜头用于确定风格，真实游玩镜头用于验收可用性。

## 2. 当前基础与实际缺口

已经核对 [美术规范](art-direction.md)、[九海域总览](art-nine-seas.png)、[近景总览](art-details.png)、[游玩截图](gameplay.png)、[主菜单](title-screen.png)及相关实现。现有系统具备以下基础，本轮以精修为主。

| 模块 | 已有基础 | 本轮待解决问题 | 主要落点 |
| --- | --- | --- | --- |
| 全局美术 | 九海域色板、材质语义、深度带 | 空气固有色与实际水下结果仍有落差，浅海灰绿、深海主景偏暗 | `scripts/art_direction.gd`、`scripts/ocean_depths.gd` |
| 主角 | 程序化身体、四肢枢轴、手部插槽、多种动作 | 球柱盒部件拼装感强，气瓶高光抢眼，轮廓与游姿仍需统一 | `scripts/diver.gd`、`scripts/presentation/model_finish.gd` |
| 光照水体 | 深度雾、太阳光、头灯、面片光束、焦散 | 浅海亮度偏平均，远景层次弱，部分深海景观沉入暗部 | `scripts/ocean.gd`、`shaders/shaft.gdshader`、`shaders/water*.gdshader` |
| 场景构图 | 九海域主景、石拱、岩台、沙谷留白、批处理 | 石拱与石柱形态重复，部分地面铺陈感强，大形体层次不足 | `scripts/presentation/ocean_composition.gd`、`scripts/seabed_ecology.gd` |
| 鱼群 | 骨骼生物、环境鱼群、顶点着色器鱼带 | 构图鱼带共用环形运动，仍需区别不同海域的路径、密度与节奏 | `shaders/fish_ribbon.gdshader`、`shaders/ecosystem_fish.gdshader` |
| 材质资产 | 34 项 GLB、四通道纹理、暂存与晋升流程 | 沙地细节、光滑装备、棱角植被的表达需要协调 | `tools/create_assets.py`、`shaders/sand.gdshader`、`shaders/plant_sway.gdshader`、`shaders/scenery.gdshader` |
| 界面 | 情境 HUD、双分辨率布局、海图玻璃主题 | 需要在真实安静探索与多事件叠加状态下继续收敛干扰 | `scripts/hud.gd`、`scripts/presentation/ocean_ui_theme.gd`、`scripts/world_map.gd` |

以上画面判断基于编制时的已保存截图；此后 P0 已在 `.tools/abzu-refinement/` 建立同机可复现基线，并完成 P1–P6 迭代与复测。

## 3. 实施边界

1. 延续桌面与 Web 共用的 `gl_compatibility` 渲染路径，沿用现有资产预算、批处理、距离剔除与动画 LOD。
2. 保留移动、战斗、低氧、瞄准、触控、手柄、坐骑和潜艇行为；主角视觉调整继续对接现有身体/四肢枢轴、左右手插槽、武器、护盾与推进器挂点。
3. 科考站、遗珍、出入口、既有地标与主游泳路线保持可达；装饰岩体可重排，视觉几何与碰撞必须匹配，遵守既有净空保护。既有沉船和遗迹的冻结碰撞契约继续有效。
4. 原有 GLB 的尺寸、动画名、骨骼数量与贴图预算保持有效。新增角色网格或变体资产需显式补充契约与预算，再走暂存、校验、晋升流程。
5. 光束采用现有面片与深度雾方案精修。真实体积雾、SSR、SSIL 不作为本轮实现依赖。Godot 4.7 官方文档列出 Compatibility 对 Glow、SSAO 的支持，二者只列为可选增强，先确认实际引擎版本与 Web 成本再决定采用。[渲染器功能对照](https://github.com/godotengine/godot-docs/blob/4.7/tutorials/rendering/renderers.rst)
6. `project.godot` 的 `config.features` 含 4.4，不能据此认定实际引擎版本。P0 记录真实二进制版本、渲染器、GPU 和浏览器，能力判断以该组合为准。

## 4. 阶段安排

实施顺序：P0 基线 → P1 浅海色光与构图 → P2 主角 → P3 材质与鱼群 → 样板区验收 → P4 九海域扩展 → P5 界面与镜头整合 → P6 双端总验收。

P1–P3 先形成中央浅礁的完整样板；涉及共享材质或光照时，同步抽查深海区域。样板通过后再展开全世界修改。阶段按下面的交付物和通过条件推进，P0 后根据网格制作量与实测性能细化工期。

### P0：建立参考板与可复现基线

**任务**

- 建立参考板：分别标注角色剪影、环境大色块、光束/雾层、鱼群框景和留白方式；补充本项目对应画面及拟修改点。
- 锁定当前提交、分辨率、机位/FOV、随机种子、水深、光照和动画采样条件。现有着色器使用 `TIME`，需要记录或增加可控采样相位，确保前后对比可解释。
- 复用 `tests/art_review.gd` 的九海域到达/近景共 18 个机位；补充包含主角的正侧背视图，以及静止、巡游、上下潜、转向急停、冲刺、持武器、载具/坐骑状态观察。
- 同时保存安静探索 HUD 与低氧/Boss/发现提示叠加的画面，覆盖 `1280×800` 和 `1920×1080`。
- 重测桌面与浏览器基线，记录帧时间、绘制调用、显存或可用的等价内存指标，以及移动加载时的卡顿。标注浏览器无法取得的指标。

**交付物**：参考规则表、角色与场景截图集、新性能基线；后续实现时保存到独立的 `.tools/abzu-refinement/` 工作目录。

**通过条件**：每项差异有对应证据；同机位可复测；真实游玩与固定镜头的结果分别记录。

**工具修正事项**：`tools/art_report.py` 的渲染器/硬件描述目前是固定文本，报告前需改成真实采集或明确传入。该工具会覆盖 `docs/` 下的画廊与报告，先为新一轮增加独立输出位置。现有规范提到的 `.tools/run_checks.py` 当前不存在，执行清单采用仓库实际存在的测试脚本。

### P1：完成中央浅礁的色彩、光影与空间样板

**任务**

- 以蓝青水体、暖沙和少量珊瑚暖色建立主次，先调整光照结果，再判断是否需要修改固有色；角色与交互物留出独立的明度空间。
- 减轻浅海灰绿感与气瓶/浅色材质的泛白；细化太阳光、环境光和头灯的分工，形成可辨认的亮区、过渡区、暗部。
- 精修光束方向、宽窄与消隐，控制透明面片重叠；焦散主要服务近景和浅海，避免铺满全部表面。
- 用前景礁体/植被、中景石拱与鱼流、远景岩峰重组出发视野。约三分之一留白是样板构图参考，在多个可玩视角验证后调整。
- 优先通过装饰岩台、礁体与远景轮廓建立高差，保留权威海床采样和既有任务锚点。

**主要落点**：`scripts/art_direction.gd`、`scripts/ocean_depths.gd`、`scripts/ocean.gd`、`scripts/presentation/ocean_composition.gd`、`shaders/sand.gdshader`、`shaders/shaft.gdshader`。

**交付物**：浅礁同机位前后对比、灰度与缩略图审查、普通游玩视角检查记录。

**通过条件**：主角/主景有明确焦点；近中远三层可分；沙地细节从属于大色块；向上、向下及转身观察没有明显色带、纯色墙感或面片穿帮。

### P2：优化主角轮廓、动作与取景

**任务**

- 制作原创轮廓草案：收束头盔与肩部，连贯胸腰轮廓，整合双气瓶与背包，延展脚蹼；保留科考潜水员身份。
- 用少量定制轮廓网格替换主要可见球/柱/盒部件，继续挂接现有枢轴，避免同时迁移整套角色控制结构。
- 以深海蓝服装为主体，暖金/珍珠白作为识别点，压低大面积白色背包和玻璃的高光与装饰发光。
- 精修躯干俯仰、转向倾侧、手臂划水、腿部打水与脚蹼滞后；区分悬停、巡游、加速、转向、持武器状态。
- 调整默认镜头距离与取景高度，使前方游泳空间更充足；保留玩家视角控制、镜头碰撞、瞄准及载具镜头切换。

**主要落点**：`scripts/diver.gd`、`scripts/presentation/model_finish.gd`；如新增离线网格，扩展 `tools/create_assets.py` 及资产契约。

**交付物**：角色正侧背与剪影展示、动作观察记录、穿越石拱与贴近岩壁的游玩验证。

**通过条件**：正常游玩距离下，轮廓连贯且动作舒展；手部、武器、护盾、推进器挂接正确；上下潜和转向无明显穿插；换装、瞄准、冲刺、骑乘与登艇不发生姿态或相机跳变。

### P3：统一材质与鱼群语言，完成浅海样板

**任务**

- 建立沙地、礁岩、珊瑚/植被、生物、科考装备五类材质样本，统一细节尺度、粗糙度与高光强弱。
- 降低远处沙地高频噪点与植被碎边干扰，增加叶片宽窄、弯曲和簇群疏密变化；明确珊瑚的主枝、次枝与群落轮廓。
- 提供有限的石拱破损、厚薄与偏置变体，减少砌块和石柱的机械重复；延续现有批处理。
- 在现有鱼带基础上加入开放弧线、椭圆或 S 形路径，分出引导鱼流、主景鱼团与远景小鱼三种尺度和密度。
- 路径修改同时校准鱼头朝向、速度、个体相位、法线变换与 `custom_aabb`，测试出入视野时的剔除和 LOD；环境装饰鱼与可交互生物继续各自承担原有职责。

**主要落点**：`tools/create_assets.py`、`scripts/presentation/ocean_composition.gd`、`scripts/seabed_ecology.gd`、`shaders/fish_ribbon.gdshader`、`shaders/ecosystem_fish.gdshader`、`shaders/plant_sway.gdshader`、`shaders/scenery.gdshader`。

**交付物**：材质样本、浅礁完整样板、鱼群路径与数量说明、性能增量报告。

**样板区通过条件**：P1–P3 的角色、光色、构图、材质和鱼群同时达到第 5 节标准；实际游玩可读性与性能通过。通过后冻结共享风格参数，再进入 P4。

### P4：扩展到九大海域

分三批推进：浅海/巨藻 → 海岭/古都/沉船 → 龙骨/火山/极渊。每批完成视觉、通行和性能复核，再展开下一批。

| 海域 | 精修重点 | 必须保留的辨识度 |
| --- | --- | --- |
| 中央浅礁 `core` | 固化样板，打磨出发航向与礁岛群落 | 蓝青水体、暖沙谷、出发石拱 |
| 北境环礁 `atoll` | 拉开台礁尺度与疏密，减少均匀铺陈 | 明亮绿松石潟湖、宽阔泳道 |
| 巨藻海峡 `kelp` | 建立林间亮暗与通透窗口，错开植被高度 | 巨藻夹道、穿行鱼流、出口亮区 |
| 晶柱海岭 `ridge` | 岩脊前后分层，局部冷光突出晶体 | 高耸海岭、冰青晶柱 |
| 星象古都 `citadel` | 调整建筑比例、断裂节奏与主轴亮区 | 原创星象纹章、金色镶嵌、礼仪空间 |
| 沉船海滩 `wreck` | 提升船体剪影与探索开口，组织暖信标 | 倾斜沉船、锈色细节、航道 |
| 龙骨荒原 `bones` | 利用肋骨大小变化与水体留白表现巨物尺度 | 蜿蜒脊骨、完整与残断肋骨 |
| 火山口 `caldera` | 分离黑岩、水雾与烟柱，局部暖光限定范围 | 黑曜岩、成簇热泉、橙暖核心 |
| 极渊圣域 `hadal` | 保留幽深，同时确保入口和主景轮廓可读 | 巨拱、珍珠冷光、空旷尺度 |

**主要落点**：共享美术参数、九海域构图、生态分布及现有场景着色器。

**通过条件**：每片海域有独立的轮廓与色彩焦点；跨区域水色连续；全部主通道、交互点、海图跃迁和地标保持可达。深海通过局部主光、轮廓和明度层次提高可读性。

### P5：整合界面、主菜单与游玩镜头

**任务**

- 复用现有情境 HUD，重点检查“安静探索—事件浮现—提示消退”的节奏与多事件叠加；控制文字、浮标和面板对主景的遮挡。
- 氧气、生命、低氧、受伤与 Boss 威胁维持清晰可读；为键鼠、手柄、触控保留操作提示和对应安全区域。
- 主菜单采用样板风格的真实场景取景，校准标题、按钮与主景的避让关系；海图和功能面板延续同一套颜色与线条规则。
- 分别审查探索、战斗、瞄准、冲刺、潜艇和坐骑取景，确认景观展示与操作判断可以兼顾。

**主要落点**：`scripts/hud.gd`、`scripts/presentation/ocean_ui_theme.gd`、`scripts/world_map.gd`、`scripts/game.gd`、`scripts/diver.gd`；必要时同步 `scripts/touch_controls.gd`。

**交付物**：双分辨率界面状态图、输入方式检查记录、主菜单与实际游玩取景对照。

**通过条件**：安静探索时环境是视觉主体；关键告警清晰；无界面越界、遮挡交互和焦点丢失。沿用现有正文最小字号标准。

### P6：双端验证与交付

**任务**

- 汇总九海域同机位对比、角色动作与双分辨率界面证据，进行实际游玩路线检查。
- 在同机、同引擎、同分辨率及相同帧率/VSync 设置下比较性能；浏览器单独建立与比较基线，记录浏览器版本和图形后端。
- 固定镜头快筛沿用现有预热/采样方法；最终代表场景增加较长采样，并覆盖持续移动、生态分块加载、鱼群与战斗共存状态。
- 确认桌面资产质量、Web 压缩结果、字体与着色器输出；完成桌面和 Web 构建验证。
- 更新正式美术规范、画廊、资产清单和性能报告，记录各项证据与剩余问题。

**通过条件**：满足第 5 节全部门禁；产出可以回溯到同一候选提交、资产版本和运行环境。发布部署另列任务。

## 5. 验收标准

### 视觉验收

以下六项分别按 0–5 分人工审查，目标为每项至少 4 分。4 分表示在样板固定机位及普通游玩视角中都稳定成立；5 分表示复杂状态下仍保持一致。结构测试只验证必要条件，最终画面由审图和连续游玩判断。

| 维度 | 4 分的可观察标准 |
| --- | --- |
| 角色 | 正侧背轮廓连贯；动作舒展；装备颜色有主次；常见状态无明显穿插 |
| 色彩 | 大色块关系清楚，角色和目标易识别，浅海无普遍灰绿或泛白，区域各有辨识度 |
| 光影水体 | 前中远层次明确，光束柔和且有方向，深海主景能辨认，头灯能恢复局部固有色 |
| 场景构图 | 主景、框景、泳道与留白关系明确，多个游玩视角有效，重复形体不主导画面 |
| 材质 | 沙地、装备、生物与植被细节尺度协调，远景稳定，无明显闪烁和高光抢眼 |
| 生命节奏 | 鱼群路径服务场景引导，个体相位与大小有变化，转向和进出视野自然 |

### 功能与性能门禁

- 角色挂点、冻结碰撞、交互距离、战斗与载具控制全部通过相关回归；新增装饰几何不堵塞主泳道和地标开口。
- 桌面与 Web 各自相对 P0 新基线：每海域 `p95` 帧时间增幅不超过 15%，同时报告绝对毫秒值和移动加载时的尖峰。该门禁不等于固定 60 FPS 承诺；目标设备的绝对帧时间上限在 P0 明确。
- 绘制调用、显存、透明叠绘及包体单独记录增量。超预算时先调整批次、可见距离、粒子和鱼群密度，再重新审查画面。
- 延续当前 GLB 面数/贴图预算与阴影光源限制；Web 保持现有单文件不超过 5 MiB 的构建约束。
- 两种分辨率与三类输入方式下，菜单、关键仪表、警告和操作区域可用；新增字符纳入字体子集检查。

## 6. 复用的验证工具与需要补充的覆盖

| 验证内容 | 现有入口 | 已补充覆盖 |
| --- | --- | --- |
| 资产尺寸、纹理、骨骼动画 | `tests/asset_pipeline.gd` | 34 项 `.glb` 资产保持 `luminous-ocean-2` 零改动契约；新增 `tests/character_art.gd` + `tests/art_character_visual.gd` 校验程序化主角轮廓契约 `expedition-silhouette-1`（`3,272 / 3,600` 三角面、12 组姿态与正侧背视图、脚蹼/膝关节相位滞后、`diver_pigment` 自发光 `<= 0.12`） |
| 挂点、材质隔离、冻结碰撞、阴影预算 | `tests/art_regression.gd` | `tests/character_art.gd` + `tests/art_regression.gd` 校验新轮廓枢轴与手部插槽、瞄准/护盾/推进器/载具挂点、`diver_pigment` 自发光 `<= 0.12`、单阴影主灯/头灯预算及沉船与遗迹冻结碰撞契约 |
| 九海域构图、泳道、情境 HUD | `tests/art_composition.gd` | `tests/art_composition.gd` + `tests/art_regression.gd` 覆盖凿刻多面岩景（chiseled scenery）、3 类 `curve_mode` 八棱鱼带路径与 `custom_aabb`、开放凸楔形石拱碰撞与宽泳道净空，以及灯光/阴影预算 |
| 固定机位与性能 | `tests/art_review.gd`、`tools/art_report.py` | `tests/art_capture_support.gd` + `tests/art_review.gd` + `tools/art_report.py` + `tests/test_art_report.py`（5 项单测），支持 `--phase 12.0` 可控采样相位、真实 GPU/渲染器环境采集与核验、`--output-dir` 独立输出目录及 `--fail-on-regression` 回归门禁，并配合 `tests/art_performance.gd` 与连续巡游压测覆盖流式加载 |
| UI 状态图与字体子集 | `tests/art_ui_visual.gd` | `tests/presentation_context.gd` + `tests/art_ui_visual.gd` 覆盖安静探索自动淡出、提示/状态/Boss 多事件叠加零重叠（`1280×800` 与 `1920×1080` 双分辨率共 36 张 UI 状态截图）及 3 套字体子集审计 |
| WebGL2 探针与浏览器实机巡检 | —（原缺独立浏览器探针） | 新增 `tests/art_web_probe.gd` + `tools/build_art_web_probe.mjs` + `tools/verify_art_web.py`，在隔离工程执行 WebGL2 固定机位九海域同镜头探针，并对 `build/web` 执行浏览器实机游玩冒烟与连续移动 `rAF` 采样 |
| 深度、水体与生态 | `tests/depth_regions.gd`、`tests/depth_visual.gd`、`tests/water_visual.gd`、`tests/seabed_ecology.gd` | 覆盖调色与光影精修后的九海域跨深度雾色/能见度连续性、海床分块流式加载与动态生态鱼群表现 |
| 操作与玩法 | `tests/input_controller.gd`、`tests/input_integration.gd`、`tests/input_ui.gd`、`tests/touch_controls.gd`、`tests/submarines_and_booster.gd`、`tests/laser_stasis_boss.gd`、`tests/open_world_exploration.gd`、`tests/mount_tame_mothertree_schools.gd`、`tests/smoke.gd` | 全量回归新角色轮廓、优化取景与情境 HUD 下的移动、瞄准、冲刺、键鼠/手柄/触控、潜艇、推进器、坐骑与 Boss 战斗行为 |

视觉和性能检查使用真实渲染器。`tests/art_review.gd` 会关闭部分世界处理以获得固定镜头，不能单独证明正常游玩时的 CPU 成本、动态表现和加载稳定性。结构测试与图像审查、连续游玩记录共同验收。

## 7. 实施与验收记录

- P0 在基线 `3f29f2ac8645dad3a810af1b8f6d6426ee2efe36` 采集的同机截图与数据作为本轮唯一比较基线；编制前的旧版性能记录只作为历史参考。
- 每个阶段记录修改文件、参数、生成器/资产版本、前后证据、性能变化与回归结果。代码、资产与对应报告一起形成可回溯的阶段版本。
- 共享光照或材质改动造成跨海域退化时，在该阶段修复或回退该组改动，保持样板与全局规则一致。
- 首个可验收成果是“中央浅礁完整样板 + 原创角色轮廓/游姿 + 统一材质 + 一套有构图作用的鱼流”，随后扩展九海域。

### P0–P6 实施与双端验收摘要

在基线 `3f29f2ac8645dad3a810af1b8f6d6426ee2efe36` 上已完成 P0–P6 全阶段实施与双端验收（当前工作区处于待检状态，尚未提交代码或执行部署）：

- **核心代码与着色器落点**：完成 `scripts/presentation/diver_silhouette.gd`、`scripts/diver.gd`、`scripts/presentation/model_finish.gd`、`scripts/art_direction.gd`、`scripts/ocean_depths.gd`、`scripts/ocean.gd`、`scripts/presentation/ocean_composition.gd`、`scripts/seabed_ecology.gd`、`scripts/hud.gd`、`scripts/presentation/ocean_ui_theme.gd`、`scripts/game.gd` 及 `shaders/ocean_atmosphere.gdshader`、`shaders/water.gdshader`、`shaders/water_underwater.gdshader`、`shaders/sand.gdshader`、`shaders/plant_sway.gdshader`、`shaders/scenery.gdshader`、`shaders/shaft.gdshader`、`shaders/fish_ribbon.gdshader`、`shaders/ecosystem_fish.gdshader`、`shaders/marine_snow.gdshader` 的协同精修；全部 34 项 `.glb` 资产保持 `luminous-ocean-2` 零改动。
- **桌面端固定机位门禁（`docs/art-performance.json`）**：在 Godot `4.7.2-stable`、`gl_compatibility` / `opengl3`、`AMD Radeon(TM) Graphics`、`1280×800`、`warmup = 90`、`samples = 300`、`phase = 12.0` 同机同环境下完成前后复测，`environment_verified = true`、`p95_gate_passed = true`，9 海域 `p95` 变化全部 `<= +15.0%`（候选版各海域 `p95` 位于 `5.903–15.737 ms`：`core -11.92%`、`atoll +5.14%`、`kelp -32.92%`、`ridge -11.20%`、`citadel -38.26%`、`wreck -10.39%`、`bones -14.99%`、`caldera +7.38%`、`hadal -22.59%`）。
- **桌面端连续巡游与生态流式加载压测（`.tools/abzu-refinement/dynamic-before.json` → `dynamic-after.json`）**：沿“浅礁—石拱鱼流—大陆坡战斗”路线连续采样 `600` 帧，`p50_ms` `18.948 → 18.961 ms`（`+0.07%`），`p95_ms` `25.138 → 25.985 ms`（`+3.37%`），`p99_ms` `32.839 → 32.775 ms`（`-0.19%`），`max_spike_ms` `47.935 → 51.367 ms`，平均 `draw_calls` `1200.1 → 1197.7`，显存 `450.39 → 448.89 MiB`。
- **WebGL2 浏览器同机位探针与实机巡检（`.tools/abzu-refinement/web-report/web-verification.json`）**：在 Chrome `157.0.8103.39`（ANGLE D3D11，`1280×800`，`warmup = 60`、`samples = 80`、`phase = 12.0`）下运行隔离探针，`passed = true`，9 海域 `p95` 变化全部 `<= +15.0%`（候选版各海域 `p95` 位于 `11.975–20.680 ms`：`core -41.66%`、`atoll -5.01%`、`kelp -7.54%`、`ridge +0.49%`、`citadel -0.08%`、`wreck -0.21%`、`bones -0.08%`、`caldera +10.42%`、`hadal -11.61%`）；`build/web` 实机冒烟 `gameplay_passed = true`（主菜单→自由探险 Pointer Lock→移动跳跃→海图→暂停恢复 6 态非空且无控制台/WebGL 错误，无头浏览器连续移动 `rAF` `p50 = 44.46 ms` / `p95 = 66.68 ms`）。
- **全量回归与双端构建产物**：18 套 Godot 测试脚本 + `tests/test_art_report.py`（5 项单测）全部 `0` 错误通过；Windows 桌面版 `build/深蓝回声.exe`（`118.11 MiB`）与 Web 生产包 `build/web/`（37 个文件，最大单文件 `524,288 B = 0.50 MiB <= 5 MiB`，总计 `13.64 MiB`，桌面源贴图零污染）构建通过；所有证据归档于 `.tools/abzu-refinement/` 与 `docs/`。
