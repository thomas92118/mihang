# 《深蓝回声 · Abyssal Echo》美术与渲染技术规范

本文档定义《深蓝回声 · Abyssal Echo》通透风格化海洋科考冒险（Luminous Stylized Ocean Adventure，参考 ABZÛ 空间构图与色彩韵律原创设计）的视觉基准、九大海域场景构图、材质光照与性能法则、界面架构、资产契约及可复现双端构建管线。所有色彩令牌、着色方程、批处理预算与碰撞约束均与运行时代码及离线生产工具严格对齐。

---

## 1. 视觉定位与界面设计原则

项目摒弃高噪点均匀撒点、卡通描边（`rim_enabled`）与泛滥的霓虹自发光，确立**通透蓝绿、大尺度剪影、韵律鱼流与留白呼吸感兼具的海洋冒险美学**：

- **三层空间构图与约三分之一负空间留白**：每片海域由 `scripts/presentation/ocean_composition.gd` 固定编排**前景框景、中景主景、远景轮廓**三层空间关系，并与 `SeabedEcology` 的沙谷留白通道协同，在主景周围保留约 `1/3` 的纯净沙地与开阔水体，替代重复环形装饰。
- **琢面层积色料与多轨迹群游鱼流**：离线资产（`tools/create_assets.py`，34 项 `.glb` 均保持版本 `luminous-ocean-2`）、主角流线科考服（`scripts/presentation/diver_silhouette.gd`，契约 `expedition-silhouette-1`）、程序化精修（`scripts/presentation/model_finish.gd`）与琢面礁石着色器（`shaders/scenery.gdshader`）均采用空气固有色料，统一使用 `DIFFUSE_BURLEY` 漫反射与 `SPECULAR_SCHLICK_GGX` 高光（强制 `rim_enabled = false`）；九大海域主景上方均配置由 `shaders/fish_ribbon.gdshader` 顶点驱动的 8 棱放样立体鱼群（支持椭圆、交叉 S 流、新月回环 3 类 `curve_mode` 及双簇留空相位），无需 CPU 逐帧骨骼开销即可建立有机生命律动。
- **沉浸式海图玻璃与金线镶嵌 UI**：
  - **实时海底主菜单（`scripts/game.gd`）**：主界面直接置入实时海底构图，`title_camera`（`fov = 62°`, `far = 280m`）锚定于 `(-19.5, -6.2, 9.5)` 微幅呼吸漂移并朝向 `(-4.5, -8.6, -34.0)`，隐藏全部 3D 世界标签（`Ocean.set_world_labels_visible(false)`），避开近处逃生舱对右上画面的压迫；标题与两个模式入口靠左排布，中右部完整留给远景石拱、光束与 S 形鱼带，并由 `ExpeditionPlate` 绘制呼应古都星象仪的细金线轨迹。
  - **安静探索态情境 HUD 与防重叠提示（`scripts/hud.gd`）**：平静巡游（`quiet_explore`）下，任务、货舱、武器提示在触发 `3.5s` 后自动隐退，日志标题与金线降至 `0.28 / 0.26`，常驻仪表按层次柔化不透明度（生命支持 `0.88`、航向罗盘 `0.72`、深度 `0.90`、生态带状态 `0.68`、雷达 `0.80`、母港距离 `0.68`、底栏键位 `0.48`）；低氧或生命 `< 30` 时立即切回高对比告警。`_layout_toast()` 动态计算 `status_value` 与 `boss_panel` 全局底边并保持 `>= 12px` 净空（长句自动换行扩展为 `66px` 高），彻底消除地标发现横幅与深度告警、Boss 血条重叠。
  - **克制近距 3D 世界标牌（`scripts/ocean.gd`）**：救生舱 `Label3D` 下调至贴近舱顶的 `HOME + (0, 3.35, 0)`，可见距离收紧至 `visibility_range_end = 13.5m`（`margin = 2.0m`, `VISIBILITY_RANGE_FADE_SELF`）；近邻交互终端 `EscapeConsole` 与 `BlackBoxTerminal` 收紧至 `9.5m`（其余 `[E]` 交互提示 `10.5m`、地标信标 `28.0m`），避免浅礁巡游时与顶中罗盘叠压。
  - **统一海洋玻璃面板与三字体子集回退链（`scripts/presentation/ocean_ui_theme.gd` / `scripts/hud.gd`）**：海图、工作台制造、料理商店、图鉴、坐骑面板、暂停、快捷轮盘与键位设置共享半透明深海面板、细青色边框与暖金主选中态。全界面正文在 `1280×800` 与 `1920×1080` 下均 `>= 14px`（默认 `15px`），内置三款按需子集字体：`NotoSansSC-Subset.otf`（主界面与 3D 标牌中文，附 `assets/fonts/OFL.txt`）、`Controls-CJK-Subset.otf`（键位/外设重映射补充字形）与 `Symbols-Subset.ttf`（几何与海图符号回退），通过 `font.fallbacks` 串联，零外部贴图或系统 Emoji 依赖。

---

## 2. 全局色彩词汇与九大海域构图色板表

全局色彩定义位于 `scripts/art_direction.gd`。**核心原则：色板存储的是物体在空气白光下的固有色料（Material Pigment），绝不预先烘焙水深暗蓝。**

### 2.1 全局界面与材质语义令牌

| 令牌常量 | 色值（Hex / RGBA） | 视觉与功能语义 |
| :--- | :--- | :--- |
| `INK` | `#082b42` | 深海墨蓝：主按钮悬停/按下反白文字衬底、潜水服暗部接缝与结构阴影基准 |
| `PAPER` | `#f4f0dc` | 珍珠暖白：HUD 主读数、界面正文、焦点细框与生物浅腹高光基准 |
| `CYAN` | `#83ded9` | 通透海青：次级玻璃面板细边框、声呐等深线、冷光生物/晶簇受控微光 |
| `AMBER` | `#edce7a` | 圣坛暖金：主操作按钮（Primary CTA）、古都拱顶徽记镶嵌、航路信标与高优提示 |
| `DANGER` | `#f28c77` | 珊瑚暖红：低氧/低耐久告警、掠食者与 Boss 威胁提示 |
| `PANEL` | `rgba(0.025, 0.10, 0.15, 0.82)` | 海洋玻璃底板：轻薄半透明深青面板，配合 `1px` 低透明度 `CYAN` 细边 |
| `MUTED` | `#abc9ce` | 雾化浅青：次要说明文字、辅助单位标尺与禁用态控件基准 |

### 2.2 九大海域色板、空间锚点与主景构图（对照 `scripts/art_direction.gd` & `ocean_composition.gd`）

世界地形通过 `ArtDirection.region_weights()` 以径向 `smoothstep(0.30 * R, R, d)` 平滑混合八大外围海域与中央核心区（`core` 承接剩余权重），并由 `OceanDepths.region_palette_texture()` 编码为 `9×2` `RGBA8` 贴图供海床着色器采样（第 `0` 行为 `sand`，第 `1` 行为 `rock`）：

| 海域 ID | 空间锚点 `(X, Z)` 与半径 `R` | `water` | `sand` | `rock` | `flora` | `accent` | `shadow` | 主景构图与视觉导引 |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| `core` | 全局基底（权重补集） | `#0982b0` | `#f1d9a7` | `#3e7486` | `#469c79` | `#f09674` | `#0f355d` | 珊瑚礁台夹持开阔暖沙谷，石拱框定出发航向，S 形鱼流穿拱而过，远峰错落避让潜艇地标 |
| `atoll` | `(40, 340)`, `R = 255m` | `#12b3c4` | `#f4e3bc` | `#4e8a8d` | `#6fa874` | `#efd07a` | `#125975` | 8 座弧形珊瑚台礁围合明亮绿松石潟湖，偏置迎宾石拱、新月鱼带与宽阔游泳水道 |
| `kelp` | `(-260, 280)`, `R = 200m` | `#15727c` | `#d4ca9f` | `#3d7276` | `#4fa276` | `#d0dc7e` | `#104453` | 双侧高低错落巨藻林夹道成廊，间插琢面岩台与岩峰节拍，尽头石拱与 S 形鱼流引导穿行 |
| `ridge` | `(380, 290)`, `R = 220m` | `#1f639e` | `#b8cfd4` | `#437494` | `#7ea9b5` | `#9ce8ee` | `#153668` | 阶梯式高耸岩脊与冰青晶柱交替起伏，`AuroraRidgeLight` 冷青点光映亮海岭琢面 |
| `citadel` | `(460, -60)`, `R = 245m` | `#165d88` | `#cfcfb6` | `#5c8284` | `#4f9682` | `#e6c875` | `#153354` | 双重星象石拱、完整/断裂柱廊与金环镶嵌构成礼仪轴线，`CitadelSanctumLight` 暖金柔光勾勒圣殿 |
| `wreck` | `(420, -380)`, `R = 235m` | `#1b4f73` | `#aeb9ad` | `#436b78` | `#6e9ca0` | `#e09e63` | `#15324a` | 两艘不同倾角与尺度的沉船前后呼应，桅顶灯笼与 `WreckChannelBeacon` 暖珀信标框出中间水道 |
| `bones` | `(-480, -90)`, `R = 250m` | `#235979` | `#b8bca9` | `#4c7082` | `#8eae9e` | `#f0e7c8` | `#16375a` | S 形蜿蜒巨兽脊骨与完整/残断肋骨拱廊贯通荒原，`BonefieldPaleLight` 冷白微光凸显巨物尺度 |
| `caldera` | `(-440, -420)`, `R = 240m` | `#16354f` | `#748589` | `#273b4f` | `#a88e72` | `#f4a64c` | `#11233b` | 黑曜岩峰半围合火山盆地，4 组热泉烟柱（`24m` 橙光）与 `28m` `CalderaBasinGlow` 仅局部染亮岩壁 |
| `hadal` | `(60, -640)`, `R = 300m` | `#183e74` | `#98b2c6` | `#3d628c` | `#84adc0` | `#bceef0` | `#10264b` | 31 米巨型圣殿石拱、发光纹章立柱与深渊晶簇围合圣域，`SanctumPearlLight` 保留幽邃深渊层次 |

### 2.3 资产材质色料配置（`ArtDirection.material_profile`）

`ArtDirection.material_profile()` 将主角潜水服与沉船残骸从通用工业舱体色板中独立分离，确保深海军蓝主角剪影、风化灰青沉船与浅暖白科考载具各司其职（暗部统一按 `base.darkened(0.55).lerp(region.shadow, 0.15)` 推导）：

| 材质键 / 角色 | `base` | `tip` | `roughness` | `metallic` | `emission` / `energy` | 视觉职责说明 |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| `diver` | `#17354b` | `#b9cdc9` | `0.66` | `0.10` | 无（局部槽位 `<= 0.12`） | 深海军蓝主体压稳剪影，配合青灰护甲与暖金点缀（`tint_strength = 0`） |
| `shipwreck` | `#9da6a2` | `#d8cdb8` | `0.68` | `0.22` | 无（信标槽位受控限幅） | 风化灰绿船壳与暖沙盐渍高光，避免与救生舱亮白外壳同质化 |
| `pod` / `submarine` / `weapon` | `#d4d6c9` | `#e7dfc9` | `0.46` | `0.30` | 无（指示灯槽位独立） | 科考救生舱、三型潜艇与手持装备的暖白陶瓷金属基底 |
| `ruins` | `#9ba695` | `#c5c3a6` | `0.92` | `0.00` | 无 | 沉没石构遗迹与碑刻风化石料 |
| `crystal_spire` / `resource_quartz` | `#83b4b5` | `#d3e3d8` | `0.35` | `0.00` | `CYAN` / `0.06` | 低能量冰青矿物微光，深海可见而不刺眼 |
| `jellyfish` / `fish_abyss` / `water_dragon` / `flying_fish` | `#58768e` | `#a7c8cc` | `0.61` | `0.00` | `CYAN` / `0.22` | 深海生物冷光色料基准 |
| `material_role`: `glass` / `metal` / `light` | `#466e80` / `#516675` / `#83ded9` | `#83ded9` / `#a7b4b4` / `#f4f0dc` | `0.18` / `0.40` / `0.72` | `0.10` / `0.65` / `0.00` | `light`: `CYAN` / `0.35` | 舷窗玻璃、结构金属件与受控灯珠语义覆写 |

---

## 3. 材质语义、构图批处理与水下光照性能法则

### 3.1 水下天光大气、海面地平线消隐与深度光照曲线

- **垂向生态带（`scripts/ocean_depths.gd`）**：海床最大深度 `600m`（下潜极限 `660m`），划分为阳光浅礁带（`0–35m`）、大陆架海藻与海扇带（`35–90m`，巨藻上限 `55m`）、暮光陆坡冷水珊瑚带（`90–200m`）、深海盆地海绵与海百合带（`200–360m`）及极深海沟黏土与结核带（`360–600m`）。
- **全水深 `BG_SKY` 水下大气散射（`Ocean.set_depth` & `shaders/ocean_atmosphere.gdshader`）**：环境背景在所有深度统一保持 `Environment.BG_SKY`，在 `depth < 0.05m` 使用水上 `air_sky`（`ProceduralSkyMaterial`, `fog_sky_affect = 0.0`），入水后切换为 `water_sky`（`shaders/ocean_atmosphere.gdshader`, `Sky.RADIANCE_SIZE_32`, `Sky.PROCESS_MODE_QUALITY`, `fog_sky_affect = 0.58`）。`ocean_atmosphere.gdshader` 仅计算无屏幕采样的垂向水柱散射梯度（`rise = smoothstep(-0.68, 0.80, EYEDIR.y)` 与顶光 `overhead = smoothstep(0.12, 0.97, EYEDIR.y)`），并由 `Ocean._update_water_atmosphere()` 按颜色/能量变化阈值惰性更新，避免静止时重复刷新反射立方体贴图。
- **斯涅尔窗与掠射角/远距海面平滑消隐（`shaders/water.gdshader` & `shaders/water_underwater.gdshader`）**：水下相机（`y < -0.75m`）自动切换至无屏幕/深度纹理读取的 `water_underwater.gdshader`。两套水面着色器的水下仰视分支均同步施加掠射角与距离双重消隐：`grazing_fade = smoothstep(0.015, 0.24, facing)`、`horizon_fade = (1.0 - smoothstep(55.0, 190.0, distance_to_camera)) * grazing_fade`、`ALPHA = (1.0 - smoothstep(180.0, 300.0, camera_depth)) * horizon_fade`（天光散射按 `95–240m` 先行衰减），消除水下远景生硬的水平亮线断层，使远端水面无缝交接至 `water_sky` 与指数深度雾。
- **连续水深光照与区域水体色调（`OceanDepths.light_profile` & `Ocean.set_art_observer`）**：
  - 太阳能量：`sun_energy = 0.84 * exp(-depth * 0.012)`；
  - 环境填充光：`ambient_energy = 0.24 * exp(-depth * 0.0068) + 0.105`（深海保底 `0.105` 冷蓝填充，确保极渊剪影可读而不死黑）；
  - 指数雾密度：`fog_density = 0.0045 + (1.0 - exp(-depth * 0.005)) * 0.0058`（表层 `0.0045` 平滑过渡至渐近上限 `0.0103`，`fog_energy = 0.54 * exp(-depth * 0.004) + 0.32`）；
  - 区域混色：按观察者位置的 `ArtDirection.region_weights()` 将区域 `water` 色混入 `fog_light_color`、`background_color` 与 `water_sky`（`<= 150m` 混合权重 `63%`，至 `600m` 收敛为 `15%`）。
- **波长选择性太阳光衰减与琢面礁岩着色**：`shaders/sand.gdshader` 与 `shaders/plant_sway.gdshader` 在 `fragment()` 中保持固有色料，在 `light()` 中仅对平行太阳光（`LIGHT_IS_DIRECTIONAL`）施加红绿波段优先吸收与相机深度修正：`transmission_sun = exp(-vec3(0.016, 0.0045, 0.0008) * depth) * exp(clamp((camera_depth - depth) * 0.012, -8.0, 7.2))`；`shaders/scenery.gdshader` 则通过 `shadow_pigment` 强化悬挑暗面，并在自定义 `light()` 中以 `facet = smoothstep(-0.08, 0.58, dot(NORMAL, LIGHT))` 与 `plane_light = mix(lambert, facet, 0.55)` 实现冷暗面/暖受光面分明的琢面岩石明暗。
- **程序化海床微地貌**：`sand.gdshader` 利用无 UV 表面梯度凹凸（`dFdx`/`dFdy`）合成 `0.5m` 沙脊波纹、断崖沉积岩层、陆架砾石与海沟锰结核，并在 `< 46m` 朝上表面叠加随深度指数衰减的双频焦散。

### 3.2 探照灯真实显色与受控自发光

- **局部光源显色还原**：局部光源（`SpotLight3D` / `OmniLight3D`）在着色器中保持 `transmission = vec3(1.0)`。当潜水员头灯（暖白 `Color(1.0, 0.96, 0.88)`）或潜艇探照灯照亮暮光带/深渊海床时，被水柱吸收的红橙暖色（珊瑚、锈蚀沉船、铜矿、岩层）会在光锥内自然显色。
- **深海主景 6 盏无阴影区域点光、热泉点光与自发光白名单**：普通底栖珊瑚、岩石与海藻**零自发光**。仅受控发光资产（水母 `0.32`、深渊鱼/晶簇 `0.12`、救生舱/沉船/遗迹/石英 `0.06` 等 `Ocean._asset_emission_scale()` 限幅项）及古都/极渊建筑金环镶嵌保留发光槽位；同时 `OceanComposition` 在中深海六大海域各布置 1 盏无阴影主景氛围 `OmniLight3D`（`AuroraRidgeLight` `66m`、`CitadelSanctumLight` `54m`、`WreckChannelBeacon` `54m`、`BonefieldPaleLight` `64m`、`CalderaBasinGlow` `28m`、`SanctumPearlLight` `52m`，标记 `authored_light = true`），配合 `24m` 作用半径的海底热泉点光（`vent_lights`），全部启用 `distance_fade_enabled = true`（主景光 `135m + 24m`、热泉光 `40m + 12m`、其余水下装饰点光收敛至 `<= 16m` 且能量 `×0.22`），保证深海主景层次清晰而不泛白过曝。

### 3.3 GL Compatibility 渲染器批处理、光照掩码与骨骼动画 LOD

项目面向桌面与 WebGL2 双端统一采用 `gl_compatibility` 渲染器（`TONE_MAPPER_FILMIC` 电影级色调映射 + 深度指数雾 `Environment.fog_enabled` + 3D `2× MSAA`）：

- **严格实时阴影与深度门控预算**：
  1. 主平行太阳光 `sun`（`DirectionalLight3D`）仅在浅海 `depth < 58.0m` 开启实时阴影（`shadow_enabled = depth < 58.0`），并在 `depth >= 210.0m` 关闭光源参与；海面网格在 `y < -64.0m`（仰视时放宽至 `y < -180.0m`）自动隐藏，消除深海无意义渲染开销；
  2. 潜水员主头灯 `lamp`（`SpotLight3D`, `shadow_enabled = true`），辅以无阴影柔光补光灯 `lamp_fill`；
  3. 每艘潜艇（`scout` / `titan` / `mini`）无论外观灯具数量多少，**最多仅允许 1 盏前照灯开启阴影**（`headlights[i].shadow_enabled = (i == 0)`，由 `tests/art_regression.gd` 强制回归校验）。
- **装饰点光源剔除掩码隔离（`light_cull_mask = 2`）**：在 `gl_compatibility` 多通道前向渲染下，区域主景光、科考站与热泉等全部 `OmniLight3D` 统一设置 `light_cull_mask = 2` 与 `distance_fade_enabled = true`，仅照亮第 `2` 层实体与构图几何（`layers = 3`），避免对第 `1` 层大面积海床地形分块产生逐光源重复像素绘制。
- **琢面构图 MultiMesh 批处理、开放拱券楔形碰撞与多曲线鱼带**：`OceanComposition` 采用 `SurfaceTool.set_smooth_group(-1)` 生成硬朗折面几何——9 棱阶梯台礁（`_make_terrace`）、7 棱倾斜凹槽岩峰（`_make_spire`）、8 棱倒角完整/残断石柱（`_make_pillar`）与 3 种样式的 8 棱倒角连续石拱（`_make_arch_band`），连同徽记镶嵌与 4 类龙骨肋骨（`bones_rib_{l|r}_{whole|broken}`）按区域和材质合并为 `MultiMeshInstance3D`（`visibility_range_end = 210m`，关闭投影，遵循 `_reserved` 地标净空）。台礁、岩峰与石柱生成凸包 `StaticBody3D`；石拱则沿拱弧分段生成**开放式 `ConvexPolygonShape3D` 楔形碰撞链**（附 `ecology_clearance` 元数据与斜坡拱脚），严禁以单一闭合凸包封死穿拱泳道。各海域主景鱼带（`visibility_range_end = 140m`，浅海 `80` 尾 / 外海 `48` 尾）采用带分叉尾鳍、背鳍与胸鳍的 8 棱放样立体鱼网格，支持 `curve_mode = 0`（宽椭圆：`ridge`/`bones`）、`1`（交叉 S 流：`core`/`kelp`/`wreck`/`hadal`）与 `2`（内凹新月：`atoll`/`citadel`/`caldera`）。
- **全场景骨骼生物距离 LOD（`Ocean._sync_animation_lod`）**：世界内约 `242` 只带骨骼生物按与观察者的距离动态启停 `AnimationPlayer`（`<= 30m` 全速播放，远距暂停骨骼矩阵求值）；无论在实时游玩（`_process`）还是主界面/固定机位巡检（`not is_processing()`）下均同步生效。
- **丁达尔光束（Sun Shafts）预算**：浅海阳光柱由 `26` 片共享 `shaders/shaft.gdshader` 的无光照加色面片组成（`16` 道散射光柱 + `10` 道宽幅光幕，`render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled`），基础不透明度系数设为 `0.046`（叠加双频斜向光线调制 `0.84–1.12` 后峰值 `ALPHA <= 0.052`），具备近距消隐（`0.9–4.5m`）、掠射法线消隐及水深 `30–120m` / 相机深度 `85–190m` 平滑消隐。
- **同机位实测性能验证（`docs/art-performance.json`）**：在 Godot `4.7.2-stable (official)`、`gl_compatibility` / `opengl3`（Windows，`AMD Radeon(TM) Graphics`，`1280×800`，`vsync_mode = 0`，`review_phase_seconds = 12.0`）确定性静态镜头下，对九大海域各预热 `warmup = 90` 帧并采样 `samples = 300` 帧（`environment_verified = true`）。全部 `9 / 9` 海域均通过 `p95 <= +15.0%` 回归门禁（`p95` 变化区间 `-38.26%` 至 `+7.38%`，显存稳定在约 `384.0–384.1 MB`；注：静态固定镜头用于同机位渲染回归校验，实时游玩与浏览器 WebGL2 帧间隔由独立探针核验）：

| 海域 ID | 改造前 `p50 / p95` (ms) | 改造后 `p50 / p95` (ms) | `p95` 变化率 | `draw_calls`（前 → 后） | 门禁结果 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `core` | `12.376 / 17.867` | `11.709 / 15.737` | `-11.92%` | `1323 → 1317` (`-0.45%`) | PASS |
| `atoll` | `7.911 / 10.646` | `7.239 / 11.193` | `+5.14%` | `287 → 286` (`-0.35%`) | PASS |
| `kelp` | `9.707 / 14.324` | `7.375 / 9.608` | `-32.92%` | `53 → 52` (`-1.89%`) | PASS |
| `ridge` | `6.172 / 9.754` | `6.025 / 8.662` | `-11.20%` | `45 → 44` (`-2.22%`) | PASS |
| `citadel` | `11.222 / 18.222` | `6.821 / 11.251` | `-38.26%` | `66 → 62` (`-6.06%`) | PASS |
| `wreck` | `5.479 / 8.613` | `5.329 / 7.718` | `-10.39%` | `53 → 53` (`0.00%`) | PASS |
| `bones` | `5.852 / 7.732` | `4.673 / 6.573` | `-14.99%` | `50 → 52` (`+4.00%`) | PASS |
| `caldera` | `5.739 / 8.514` | `6.062 / 9.142` | `+7.38%` | `73 → 72` (`-1.37%`) | PASS |
| `hadal` | `5.108 / 7.626` | `4.249 / 5.903` | `-22.59%` | `53 → 52` (`-1.89%`) | PASS |

---

## 4. 资产规格、面数/贴图预算与碰撞解耦契约

### 4.1 原创离线资产契约（`tools/create_assets.py` & `assets/source/asset-contract.json`）

全部 `34` 项 3D `.glb` 资产均由 `tools/create_assets.py`（生成器版本 `luminous-ocean-2`，`MIT` 许可，`external_sources = []`）确定性离线生成，包含明快分层的色料贴图及完整四通道 PBR 纹理（`albedo`、`normal`、`orm`、`emission`）：

- **坐标轴与包围盒契约**：Blender `(X, Y, Z)` 导出至 Godot 自动映射为 `(X, Z, Y)`；每项资产在 Godot 内的实测世界 `AABB` 各轴尺寸必须与 `assets/source/asset-contract.json` 中的 `dimensions_godot_xyz` 误差 `< 10%`（下限容差 `5mm`）。
- **骨骼与动画契约**：带骨骼生物（`fish` `6` 骨、`fish_small` `6` 骨、`fish_predator` `7` 骨、`fish_abyss` `7` 骨、`manta_ray` `5` 骨、`sea_turtle` `5` 骨、`crab` `27` 骨、`squid` `33` 骨、`jellyfish` `38` 骨）骨骼总数均 `<= 64` 根，包含 `30 FPS` 有效关节形变动画片段（`swim` / `bite` / `pulse` / `walk` / `defend`）。

### 4.2 三角面数与贴图分辨率分级预算

| 资产类别 | 包含资产 ID | 三角面预算上限 | 桌面源贴图尺寸 | Web 独立副本尺寸上限 |
| :--- | :--- | :---: | :---: | :---: |
| 大型地标与舱体 | `pod`, `shipwreck` (`11,000`)；`ruins` (`10,000`) | `10,000 – 11,000` | `1024×1024` | `512×512` (Lossy) |
| 主角武器装备 | `weapon_sonic` (`3,800`)；`weapon_knife`, `weapon_axe` (`3,500`) | `3,500 – 3,800` | `1024×1024` | `512×512` (Lossy) |
| 中大型骨骼生物 | `fish_predator`, `fish_abyss` (`4,900`)；`manta_ray`, `sea_turtle`, `squid`, `jellyfish` (`4,500`) | `4,500 – 4,900` | `1024×1024` | `512×512` (Lossy) |
| 甲壳与群游鱼类 | `crab` (`4,000`)；`fish` (`1,900`)；`fish_small` (`1,500`) | `1,500 – 4,000` | `512×512` | `crab`/`fish_small`: `256`；`fish`: `512` |
| 矿物晶簇与岩石 | `crystal_spire` (`1,500`)；`rock` (`590`) | `590 – 1,500` | `512×512` | `512×512` (Lossy) |
| 可采集资源节点 | `resource_titanium`, `resource_copper`, `resource_kelp` (`900`)；`resource_quartz` (`600`) | `600 – 900` | `512×512` | `256×256` (Lossy) |
| 底栖珊瑚与生态植群 | `coral`, `tube_coral`, `kelp`, `anemone`, `sea_fan`, `tubeworms`, `starfish_urchin`, `brain_coral`, `staghorn_coral`, `table_coral`, `barrel_sponge`, `giant_clam`, `sea_lily` | `1,450` | `512×512` | 小型附着物 `256`；其余 `512` |

> 注：Web 端 `256px` 小型道具前缀白名单（`SMALL_PROP_TEXTURE_PREFIXES`）包含：`anemone_`、`crab_`、`fish_small_`、`resource_copper_`、`resource_kelp_`、`resource_quartz_`、`resource_titanium_`、`sea_lily_`、`starfish_urchin_`、`tube_coral_`、`tubeworms_`。

### 4.3 视觉网格与物理碰撞/动画枢轴解耦契约

- **地标冻结碰撞体（Frozen Landmark Collisions）**：`ruins` 与 `shipwreck` 的高细节视觉 `.glb` 与物理碰撞严格分离。`tools/freeze_landmark_collision.gd` 将局部空间 `StaticBody3D` + `ConcavePolygonShape3D` 预冻结为 `res://assets/collision/ruins.tscn` 与 `res://assets/collision/shipwreck.tscn`，由 `Ocean` 在生成地标实例时挂载，确保视觉模型重拓扑或细分不会破坏探索通道与遗迹可拾取性。
- **主角流线科考服剪影契约（`scripts/presentation/diver_silhouette.gd` & `scripts/diver.gd`）**：全部 `34` 项离线 `.glb` 资产保持 `luminous-ocean-2` 不变，第三人称主角则采用纯代码缓存生成的 `expedition-silhouette-1` 紧凑流线科考服（实测 `3,272 / 3,600` 三角面，全部 `ArrayMesh` 静态缓存复用并满足顺时针非退化法线契约）：
  - **分段放样轮廓与三叶燕尾长脚蹼**：躯干、胸甲、流线头盔、面罩、领环、导航腰带、贴合背囊、双气瓶及四肢均由截面放样生成，脚蹼采用中脊加双侧长翼的三叶燕尾流线叶片（`fin().get_aabb().size.z > 0.49m`），配合默认第三人称机位 `THIRD_PERSON_DEFAULT_DIST = 3.05`（缩放范围 `1.6–6.5m`，精准瞄准 `1.45m`，开镜/入舱自动隐藏）建立清晰修长的游泳剪影。
  - **膝踝相位滞后与枢轴零侵入**：完整保留 `body_pivot`、`head_pivot`、肩肘枢轴与 `left_hand_socket` / `right_hand_socket` 武器挂点，并在大腿下挂载关节化膝枢轴（`LeftKneePivot` / `RightKneePivot`）与柔性踝枢轴（`LeftFinPivot` / `RightFinPivot`）；巡游时躯干随水流速度矢量俯仰侧倾，膝盖（`cos(phase - 0.20)`）与脚蹼（`sin(phase - 1.15)`）依次相位滞后摆动，不改动任何物理速度或胶囊碰撞体。
  - **`diver_pigment` 主次色保护**：潜水服材质显式标记 `diver_pigment = true`，使 `ModelFinish` 原样保留深海军蓝主体（`#17354b`）、青灰护甲/气瓶（`#527d88` / `#345969`）与暖金点缀（`#d5b566` 腰带、领环、面罩框、腕环与脚蹼），强制 `rim_enabled = false` 且自发光倍增严格限制在 `emission_energy_multiplier <= 0.12`（背脊/气表指示 `0.09`、面罩 `0.07`）。
- **程序化装配体契约与材质实例隔离**：`Diver`、`Submarine`（`scout`/`titan`/`mini`）与 8 类程序化 `MarineCreature` 通过 `ModelFinish.apply()` 原地升级材质与低频有机曲面，标记 `art_finished = true`，同时完整保留手部插槽（`left_hand_socket`/`right_hand_socket`）、武器挂点、推进器、护盾与鳍/触手/尾椎动画枢轴。每个 `MarineCreature` 实例持有独立的 `StandardMaterial3D` 实例，狂暴（`enraged`）或静滞（stasis）变色绝不跨实例串染；GLB 生物在冻结状态下通过 `AnimationPlayer.speed_scale = 0.0` 或暂停实现无漂移定格。

---

## 5. 可复现构建与双端导出流程

美术生产、实机视觉采样与双端打包遵循“暂存生成 → 契约与构图回归校验 → 签名晋升 → 实机画廊与性能核验 → 双端无损/压缩隔离导出”的闭环：

1. **Blender 离线暂存生成**
   ```bash
   blender --background --factory-startup --python tools/create_assets.py
   ```
   在 `.tools/art-staging/` 下确定性生成 34 项 `luminous-ocean-2` `.glb` 模型与 `asset-manifest.json`，不直接覆盖生产目录。若界面新增中文字符，可通过 `python tools/subset_font.py .tools/NotoSansCJKsc-Regular.otf` 重建 `assets/fonts/NotoSansSC-Subset.otf`（配合仓库内置的 `Controls-CJK-Subset.otf` 与 `Symbols-Subset.ttf` 组成完整回退链）。

2. **Godot 契约与回归校验**
   ```bash
   godot --headless --path . -s tests/asset_pipeline.gd -- --staging
   godot --headless --path . -s tests/art_regression.gd
   godot --headless --path . -s tests/art_composition.gd
   godot --headless --path . -s tests/character_art.gd
   godot --headless --path . -s tests/presentation_context.gd
   python -X utf8 -m unittest tests/test_art_report.py
   python -X utf8 .tools/abzu-refinement/run_jobs.py .tools/abzu-refinement/full-regression-jobs.json
   ```
   `tests/asset_pipeline.gd -- --staging` 校验全部资产的许可证、面数/贴图上限、四通道 PBR 绑定、Godot 空间 `AABB` 尺寸契约与骨骼动画形变，通过后写入 `SHA-256` 校验摘要 `.tools/art-staging/validated.sha256`。`tests/art_regression.gd`、`tests/art_composition.gd`、`tests/character_art.gd` 与 `tests/presentation_context.gd` 分别验证冻结碰撞、九大海域构图与拱门开放碰撞链、`expedition-silhouette-1` 主角面数/法线/脚蹼相位滞后契约，以及安静探索 HUD、低氧/Boss/发现横幅零重叠与超时消隐；`tests/test_art_report.py` 校验性能门禁对比逻辑，`.tools/abzu-refinement/run_jobs.py` 串联执行全量玩法、生态、视觉与桌面导出批处理回归并扫描 `SCRIPT ERROR` / `SHADER ERROR`。

3. **生产目录受控晋升**
   ```bash
   blender --background --python tools/create_assets.py -- --promote
   ```
   核对 `.tools/art-staging/validated.sha256` 与暂存清单哈希完全一致后，才将验证通过的 `.glb` 晋升至 `assets/models/` 并同步更新 `assets/source/asset-manifest.json`。桌面端工作区始终保留完整的 `512/1024px` 源级纹理质量。

4. **实机画廊对比、主角姿态、UI 双分辨率截图与性能门禁报告**
   ```bash
   godot --path . --audio-driver Dummy --disable-vsync --quit-after 3600 -s tests/art_review.gd -- res://.tools/abzu-refinement/after --samples 300 --warmup 90 --phase 12.0
   python -X utf8 tools/art_report.py .tools/abzu-refinement/before .tools/abzu-refinement/after --fail-on-regression
   godot --path . --audio-driver Dummy --disable-vsync --quit-after 2400 -s tests/art_character_visual.gd -- res://.tools/abzu-refinement/character-after --phase 12.0
   godot --path . --audio-driver Dummy --disable-vsync --quit-after 2400 -s tests/art_ui_visual.gd -- res://.tools/ui-review --phase 12.0
   ```
   在真实 `gl_compatibility`（`opengl3`）渲染器与固定采样相位（`phase = 12.0`, `warmup = 90`, `samples = 300`）下输出九大海域抵达总览 `docs/art-nine-seas.png`、近景细节总览 `docs/art-details.png`、同机位前后对比长图 `docs/art-comparison.png` 及验证环境一致性的 `docs/art-performance.json`，并采集主角 12 组水下姿态截图与 `1280×800` / `1920×1080` 下 18 类情境 UI 状态截图（共 36 张）。

5. **桌面端导出、独立副本 Web 压缩构建与浏览器 WebGL2 探针核验（`tools/build_web.mjs` & `tools/verify_art_web.py`）**
   ```bash
   godot --headless --path . --export-release "Windows Desktop" "build/深蓝回声.exe"
   npm run build:web
   node tools/build_art_web_probe.mjs --project . --output .tools/abzu-refinement/web-candidate
   python -X utf8 tools/verify_art_web.py --baseline .tools/abzu-refinement/web-baseline/project/build/web --candidate .tools/abzu-refinement/web-candidate/project/build/web --game build/web --output .tools/abzu-refinement/web-report
   ```
   - 清理并重建隔离构建副本 `.tools/web-build-stage`，仅复制运行时必需文件（`project.godot`、`export_presets.cfg`、`icon.svg*`、`scenes`、`scripts`、`shaders`、`assets/audio`、`assets/collision`、`assets/fonts`、`assets/models`），**`ROOT/assets/models` 保持 100% 零改动**。
   - 在副本内确保 `.glb.import` 启用外置贴图提取（`gltf/embedded_image_handling=1`），仅改写 `<stage>/assets/models/*.png.import` 为有损压缩（`compress/mode=1`）、开启 Mipmap（`mipmaps/generate=true`）并按分级设置 `process/size_limit=256|512`，随后执行 `godot --headless --path <stage> --import` 将压缩纹理真正烘焙进导出缓存。
   - 从 `<stage>` 直接导出 `"Web"` 至 `build/web/index.html`，后处理将 `index.wasm` 与 `index.pck` 进行 `gzip -9` 压缩并切分为 `<= 512 KiB` 的 `.gz.part*` 分片，生成 `chunks.json`、注入浏览器端 `DecompressionStream('gzip')` 并行流式解压 `fetch` 垫片与 `COOP/COEP` `_headers`，并校验所有静态产物严格 `<= 5 MiB`（兼容 Cloudflare Workers 静态资源限制）。
   - `tools/build_art_web_probe.mjs` 在 `.tools/` 下独立构建不触碰生产目录与 `build/web` 的固定机位 Web 探针副本，`tools/verify_art_web.py` 在本地带 `COOP/COEP` 头的 Chrome WebGL2 环境中执行九大海域同机位前后对比采样与 `build/web` 实机冒烟校验，输出 `web-verification.json`。
