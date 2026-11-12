# 《深蓝回声 · Abyssal Echo》美术与渲染技术规范

本文档定义《深蓝回声 · Abyssal Echo》通透风格化海洋科考冒险（Luminous Stylized Ocean Adventure，参考 ABZÛ 空间构图与色彩韵律原创设计）的视觉基准、九大海域场景构图、材质光照与性能法则、界面架构、资产契约及可复现双端构建管线。所有色彩令牌、着色方程、批处理预算与碰撞约束均与运行时代码及离线生产工具严格对齐。

---

## 1. 视觉定位与界面设计原则

项目摒弃高噪点均匀撒点、卡通描边（`rim_enabled`）与泛滥的霓虹自发光，确立**通透蓝绿、大尺度剪影、韵律鱼流与留白呼吸感兼具的海洋冒险美学**：

- **三层空间构图与约三分之一负空间留白**：每片海域由 `scripts/presentation/ocean_composition.gd` 固定编排**前景框景、中景主景、远景轮廓**三层空间关系，并与 `SeabedEcology` 的沙谷留白通道协同，在主景周围保留约 `1/3` 的纯净沙地与开阔水体，替代重复环形装饰。
- **层积色料表面与韵律鱼群动态**：离线资产（`tools/create_assets.py`，版本 `luminous-ocean-2`）、程序化模型精修（`scripts/presentation/model_finish.gd`）与层理礁岩着色器（`shaders/scenery.gdshader`）采用明快纯净的空气固有色料，统一使用 `DIFFUSE_BURLEY` 漫反射与 `SPECULAR_SCHLICK_GGX` 微表面高光（强制 `rim_enabled = false`）；九大海域主景上方均配置基于顶点着色器（`shaders/fish_ribbon.gdshader`）驱动的环形银/金腹群游鱼带，无需 CPU 逐帧骨骼开销即可建立生命律动。
- **沉浸式海图玻璃与金线镶嵌 UI**：
  - **实时海底主菜单**：主界面直接置入构图化实时海底实景，隐藏 3D 场景交互浮标文字（`Ocean.set_world_labels_visible(false)`），标题与两个模式入口靠左排布，中上部留出通透水体、石拱剪影与巡游鱼群空间，并由 `ExpeditionPlate` 绘制呼应古都星象仪的细金线轨迹。
  - **情境感知探索 HUD（`scripts/hud.gd`）**：常驻元素收敛为氧气、生命、深度、航向标尺与精简雷达；武器切换、采集收获与地标发现提示在事件触发时短暂浮现后自动隐退，配方追踪仅在玩家启用时显示，而低氧、受伤与 Boss 态势始终保持高对比清晰可见。
  - **统一海洋玻璃功能面板（`scripts/presentation/ocean_ui_theme.gd` / `scripts/world_map.gd`）**：海图、工作台制造、料理商店、图鉴、坐骑面板、暂停与结算界面共享轻薄半透明深海面板、细青色边框与暖金主选中态；海图保留等深线、迷雾、航路标点与科考站跃迁，并以海域色带关联世界美术。全界面正文在 `1280×800` 与 `1920×1080` 下均 `>= 14px`（默认 `15px`），搭配按脚本字形构建的 `NotoSansSC-Subset.otf`（附 `assets/fonts/OFL.txt`）与 `Symbols-Subset.ttf`，零外部贴图或 Emoji 依赖，零裁切、零遮挡、同级按钮零重叠。

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
| `core` | 全局基底（权重补集） | `#087fa7` | `#eadab2` | `#5f9295` | `#539e72` | `#ef9675` | `#123f69` | 珊瑚礁岛夹持开阔暖沙谷，石拱框定出发航向，远景岩峰错落避让沉没潜艇地标 |
| `atoll` | `(40, 340)`, `R = 255m` | `#12b2b9` | `#f2e7c5` | `#8bb7a4` | `#8db967` | `#edce7a` | `#146585` | 8 座弧形珊瑚台礁围合明亮绿松石潟湖，偏置迎宾石拱与宽阔游泳水道 |
| `kelp` | `(-260, 280)`, `R = 200m` | `#146b69` | `#cdcba0` | `#4c8278` | `#6eac63` | `#c8d47e` | `#144c5b` | 双侧高低错落巨藻林夹道成廊，间插岩笋节拍，尽头石拱与林间鱼流引导穿行 |
| `ridge` | `(380, 290)`, `R = 220m` | `#235f9a` | `#b6cdd0` | `#578eac` | `#83abb4` | `#9ee2e4` | `#193d72` | 阶梯式高耸岩脊与冰青晶柱交替起伏，冷青极光点光映亮海岭折面 |
| `citadel` | `(460, -60)`, `R = 245m` | `#155b83` | `#cccfb7` | `#8eafa6` | `#529985` | `#e1c578` | `#193859` | 双重星象石拱、完整/断裂柱廊与金环镶嵌构成轴线礼仪空间，远峰隐入深蓝水雾 |
| `wreck` | `(420, -380)`, `R = 235m` | `#1b4d70` | `#adb8ab` | `#517c88` | `#719da0` | `#d79d6a` | `#183850` | 两艘不同倾角与尺度的沉船前后呼应，桅顶暖珀信标与礁石框出中间探索水道 |
| `bones` | `(-480, -90)`, `R = 250m` | `#255775` | `#b6b9a7` | `#5d8191` | `#8fae9d` | `#e8dfbc` | `#1a3e62` | S 形蜿蜒巨兽脊骨与完整/残断肋骨拱廊贯通荒原，周边克制留白凸显巨物尺度 |
| `caldera` | `(-440, -420)`, `R = 240m` | `#173650` | `#7d8f91` | `#354d64` | `#a48f75` | `#efaa58` | `#182e4b` | 黑曜岩峰半围合火山盆地，4 组热泉烟柱成簇喷涌，暖橙盆地微光仅局部染亮岩壁 |
| `hadal` | `(60, -640)`, `R = 300m` | `#193d72` | `#96afc2` | `#466c99` | `#82a9b9` | `#b4e7e6` | `#142d56` | 31 米巨型圣殿石拱、发光纹章立柱与深渊晶簇围合圣域，保留幽邃空旷的深渊层次 |

---

## 3. 材质语义、构图批处理与水下光照性能法则

### 3.1 固有本色、水柱吸收与区域水雾平滑着色

- **垂向生态带（`scripts/ocean_depths.gd`）**：海床最大深度 `600m`（下潜极限 `660m`），划分为阳光浅礁带（`0–35m`）、大陆架海藻与海扇带（`35–90m`，巨藻上限 `55m`）、暮光陆坡冷水珊瑚带（`90–200m`）、深海盆地海绵与海百合带（`200–360m`）及极深海沟黏土与结核带（`360–600m`）。
- **连续水深光照与区域水体色调（`OceanDepths.light_profile` & `Ocean.set_art_observer`）**：随水深连续插值太阳光能量、天光环境色与指数深度雾密度（`0.0046` → `0.0106`），同时按观察者所在位置的 `ArtDirection.region_weights()` 将区域特征 `water` 色平滑混入 `fog_light_color` 与 `background_color`（浅海混合权重最高 `63%`，至 `600m` 收敛为 `15%`），在不破坏深度能见度契约的前提下赋予九大海域鲜明的水色辨识度。
- **波长选择性太阳光衰减与层理礁岩着色**：`shaders/sand.gdshader`、`shaders/plant_sway.gdshader` 与 `shaders/scenery.gdshader` 在 `fragment()` 中保持沙砾、珊瑚岛台、巨藻与古建筑的固有色料；在 `light()` 中仅对平行太阳光（`LIGHT_IS_DIRECTIONAL`）施加红绿波段优先吸收，避免与全局环境光重复变暗：
  - `transmission_sun = exp(-vec3(0.022, 0.0055, 0.0) * depth) * exp(clamp((camera_depth - depth) * 0.012, -8.0, 7.2))`
- **程序化海床微地貌**：`sand.gdshader` 利用无 UV 表面梯度凹凸（`dFdx`/`dFdy`）合成 `0.5m` 沙脊波纹、断崖沉积岩层、陆架砾石与海沟锰结核，并在 `< 46m` 朝上表面叠加随深度指数衰减的双频焦散。

### 3.2 探照灯真实显色与受控自发光

- **局部光源显色还原**：局部光源（`SpotLight3D` / `OmniLight3D`）在着色器中保持 `transmission = vec3(1.0)`。当潜水员头灯（暖白 `Color(1.0, 0.96, 0.88)`）或潜艇探照灯照亮暮光带/深渊海床时，被水柱吸收的红橙暖色（珊瑚、锈蚀沉船、铜矿、岩层）会在光锥内自然显色。
- **深海主景受控点光与自发光白名单**：普通底栖珊瑚、岩石与海藻**零自发光**。仅 `LUMINOUS_ASSETS`（水母、深渊鱼、石英/晶簇、救生舱/沉船/遗迹信标、声波武器）及古都/极渊建筑金环镶嵌保留受控发光槽位，运行时由 `Ocean._asset_emission_scale()` 与 `ModelFinish` 二次限幅；同时在海岭、火山口与极渊圣域设置单盏无阴影主景氛围光（`AuroraRidgeLight`、`CalderaBasinGlow`、`SanctumPearlLight`），保证深海远景与主景层次清晰可读而不泛白过曝。

### 3.3 GL Compatibility 渲染器批处理、光照掩码与骨骼动画 LOD

项目面向桌面与 WebGL2 双端统一采用 `gl_compatibility` 渲染器（`TONE_MAPPER_FILMIC` 电影级色调映射 + 深度指数雾 `Environment.fog_enabled` + 3D `2× MSAA`）：

- **严格实时阴影与深度门控预算**：
  1. 主平行太阳光 `sun`（`DirectionalLight3D`）仅在浅海 `depth < 58.0m` 开启实时阴影（`shadow_enabled = depth < 58.0`），并在 `depth >= 210.0m` 关闭光源参与；海面网格同样随深度门控隐藏，消除深海无意义渲染开销；
  2. 潜水员主头灯 `lamp`（`SpotLight3D`, `shadow_enabled = true`），辅以无阴影柔光补光灯 `lamp_fill`；
  3. 每艘潜艇（`scout` / `titan` / `mini`）无论外观灯具数量多少，**最多仅允许 1 盏前照灯开启阴影**（`headlights[i].shadow_enabled = (i == 0)`，由 `tests/art_regression.gd` 强制回归校验）。
- **装饰点光源剔除掩码隔离（`light_cull_mask = 2`）**：在 `gl_compatibility` 多通道前向渲染下，科考站与热泉等装饰点光源统一设置 `light_cull_mask = 2`，仅照亮第 `2` 层实体与构图几何（`layers = 3`），避免对第 `1` 层大面积海床地形分块产生逐光源重复像素绘制。
- **MultiMesh 构图批处理与碰撞对齐**：`OceanComposition` 将九大海域的台礁、岩峰、石柱、石拱砌块、徽记镶嵌及缓存复用的 4 类龙骨肋骨网格（`bones_rib_{l|r}_{whole|broken}`）按区域与材质自动合并为 `MultiMeshInstance3D`（`visibility_range_end = 210m`，关闭投影），同时为实体岩台、岩峰、石柱与石拱自动生成匹配的凸包/盒体 `StaticBody3D` 碰撞并避让所有科考站、遗珍与既有地标（`_reserved` 净空保护）。
- **全场景骨骼生物距离 LOD（`Ocean._sync_animation_lod`）**：世界内约 `242` 只带骨骼生物按与观察者的距离动态启停 `AnimationPlayer`（`<= 30m` 全速播放，远距暂停骨骼矩阵求值）；无论在实时游玩（`_process`）还是主界面/固定机位巡检（`not is_processing()`）下均同步生效。
- **丁达尔光束（Sun Shafts）预算**：浅海阳光柱由 `26` 片共享 `shaders/shaft.gdshader` 的无光照加色面片组成（`16` 道散射光柱 + `10` 道光幕，`render_mode unshaded, blend_add, depth_draw_never, shadows_disabled`），峰值不透明度严格限制在 `ALPHA <= 0.058`，并在水深 `30–120m` 及相机深度 `85–190m` 区间平滑消隐。
- **同机位实测性能基线（`docs/art-performance.json`）**：在 `1280×800` 实机 `Compatibility` 渲染器下对九大海域固定机位各预热 `60` 帧并采样 `80` 帧，全部 `9 / 9` 海域均大幅优于 `p95 <= +15%` 门禁——`p95` 帧时间较改造前下降 `50.7% – 85.1%`，每帧 `draw_calls` 下降 `1.9% – 34.8%`，显存占用由约 `392.4 MB` 降至 `383.6 MB`。

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
- **程序化装配体契约与材质实例隔离**：`Diver`、`Submarine`（`scout`/`titan`/`mini`）与 8 类程序化 `MarineCreature` 通过 `ModelFinish.apply()` 原地升级材质与低频有机曲面，标记 `art_finished = true`，同时完整保留手部插槽（`left_hand_socket`/`right_hand_socket`）、武器挂点、推进器、护盾与鳍/触手/尾椎动画枢轴。每个 `MarineCreature` 实例持有独立的 `StandardMaterial3D` 实例，狂暴（`enraged`）或静滞（stasis）变色绝不跨实例串染；GLB 生物在冻结状态下通过 `AnimationPlayer.speed_scale = 0.0` 或暂停实现无漂移定格。

---

## 5. 可复现构建与双端导出流程

美术生产、实机视觉采样与双端打包遵循“暂存生成 → 契约与构图回归校验 → 签名晋升 → 实机画廊与性能核验 → 双端无损/压缩隔离导出”的闭环：

1. **Blender 离线暂存生成**
   ```bash
   blender --background --factory-startup --python tools/create_assets.py
   ```
   在 `.tools/art-staging/` 下确定性生成 `.glb` 模型与 `asset-manifest.json`，不直接覆盖生产目录。若界面新增中文字符，可通过 `python tools/subset_font.py .tools/NotoSansCJKsc-Regular.otf` 重建 `assets/fonts/NotoSansSC-Subset.otf`。

2. **Godot 契约与回归校验**
   ```bash
   godot --headless --path . -s tests/asset_pipeline.gd -- --staging
   godot --headless --path . -s tests/art_regression.gd
   godot --headless --path . -s tests/art_composition.gd
   python -X utf8 .tools/run_checks.py
   ```
   `tests/asset_pipeline.gd -- --staging` 校验全部资产的许可证、面数/贴图上限、四通道 PBR 绑定、Godot 空间 `AABB` 尺寸契约与骨骼动画形变，通过后写入 `SHA-256` 校验摘要 `.tools/art-staging/validated.sha256`。`tests/art_regression.gd` 与 `tests/art_composition.gd` 进一步验证冻结碰撞挂载、九大海域主景与留白通道、角色/载具/生物枢轴与阴影预算、材质/动画隔离以及 `1280×800` 与 `1920×1080` 全界面布局无越界无重叠；`.tools/run_checks.py` 一键串联全部 `11` 项玩法、生态与美术回归测试。

3. **生产目录受控晋升**
   ```bash
   blender --background --python tools/create_assets.py -- --promote
   ```
   核对 `.tools/art-staging/validated.sha256` 与暂存清单哈希完全一致后，才将验证通过的 `.glb` 晋升至 `assets/models/` 并同步更新 `assets/source/asset-manifest.json`。桌面端工作区始终保留完整的 `512/1024px` 源级纹理质量。

4. **实机画廊对比、UI 全分辨率截图与性能报告**
   ```bash
   godot --path . --quit-after 3600 -s tests/art_review.gd -- res://.tools/abzu-review/after
   python -X utf8 tools/art_report.py .tools/abzu-review/before .tools/abzu-review/after
   godot --path . --quit-after 2400 -s tests/art_ui_visual.gd
   ```
   在真实 `Compatibility` 渲染器下输出九大海域抵达机位总览 `docs/art-nine-seas.png`、近景细节总览 `docs/art-details.png`、同机位改造前后对比长图 `docs/art-comparison.png` 及性能门禁报告 `docs/art-performance.json`，并在 `1280×800` 与 `1920×1080` 下输出全界面状态截图供视觉巡检。

5. **桌面端导出与独立副本 Web 压缩构建（`tools/build_web.mjs`）**
   ```bash
   godot --headless --path . --export-release "Windows Desktop" "build/深蓝回声.exe"
   npm run build:web
   ```
   - 清理并重建隔离构建副本 `.tools/web-build-stage`，仅复制运行时必需文件（`project.godot`、`export_presets.cfg`、`icon.svg*`、`scenes`、`scripts`、`shaders`、`assets/audio`、`assets/collision`、`assets/fonts`、`assets/models`），**`ROOT/assets/models` 保持 100% 零改动**。
   - 在副本内确保 `.glb.import` 启用外置贴图提取（`gltf/embedded_image_handling=1`），仅改写 `<stage>/assets/models/*.png.import` 为有损压缩（`compress/mode=1`）、开启 Mipmap（`mipmaps/generate=true`）并按分级设置 `process/size_limit=256|512`，随后执行 `godot --headless --path <stage> --import` 将压缩纹理真正烘焙进导出缓存。
   - 从 `<stage>` 直接导出 `"Web"` 至 `build/web/index.html`，后处理将 `index.wasm` 与 `index.pck` 进行 `gzip -9` 压缩并切分为 `<= 512 KiB` 的 `.gz.part*` 分片，生成 `chunks.json`、注入浏览器端 `DecompressionStream('gzip')` 并行流式解压 `fetch` 垫片与 `COOP/COEP` `_headers`，并校验所有静态产物严格 `<= 5 MiB`（兼容 Cloudflare Workers 静态资源限制）。
