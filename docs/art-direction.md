# 《深蓝回声 · Abyssal Echo》美术与渲染技术规范

本文档定义《深蓝回声 · Abyssal Echo》绘画感半写实海洋冒险（Painterly Semi-Realistic Ocean Adventure）美术重构的视觉基准、材质光照物理法则、资产契约与可复现双端构建管线。所有色彩令牌、着色方程、网格/贴图预算与碰撞约束均与运行时代码及离线生产工具严格对齐。

---

## 1. 视觉定位（绘画感半写实海洋冒险风）

项目摒弃早期高饱和度卡通着色（`DIFFUSE_TOON` / `SPECULAR_TOON`）、硬边霓虹描边（`rim_enabled`）与泛滥的装饰性自发光，确立**绘画感半写实海洋科考冒险**风格：

- **笔触化层积色料，物理化表面响应**：离线纹理（`tools/create_assets.py`）与程序化模型精修（`scripts/presentation/model_finish.gd`）采用柔和的云雾色阶、笔触肌理（`cloud` + `brush`）与岩层节理（`strata`）构建手绘色料层次；运行时统一使用基于物理的 `DIFFUSE_BURLEY` 漫反射与 `SPECULAR_SCHLICK_GGX` 微表面高光，并强制关闭边缘光（`rim_enabled = false`）。
- **克制、可信的深海可读性**：生物与生态群落依靠大剪影比例、背腹明度反差（背暗腹浅）与水体体积雾层次拉开空间景深，而非靠全身发光勾边。
- **静谧海图仪器级 UI**：界面主题（`scripts/presentation/ocean_ui_theme.gd`）采用深海墨色面板、暖纸色读数与青/琥珀双功能强调色；主界面底图由 `ExpeditionPlate` 程序化绘制等深线与航迹点，搭配 `NotoSansSC-Subset.otf` 与 `Symbols-Subset.ttf` 子集字体，无外部图片或 Emoji 依赖，并在 `1280×800` 与 `1920×1080` 双分辨率下保证零越界与同级按钮零重叠。

---

## 2. 全局色彩词汇与九大海域色板表

全局色彩定义位于 `scripts/art_direction.gd`。**核心原则：色板存储的是物体在空气白光下的固有色料（Material Pigment），绝不预先烘焙水深暗蓝。**

### 2.1 全局界面与材质语义令牌

| 令牌常量 | 色值（Hex / RGBA） | 视觉与功能语义 |
| :--- | :--- | :--- |
| `INK` | `#102735` | 深海墨蓝：主按钮文字反白衬底、潜水服橡胶接缝与深暗结构基准 |
| `PAPER` | `#ede7d8` | 海图纸白：HUD 主读数、正文文本、高亮刻度与生物浅腹高光基准 |
| `CYAN` | `#80c6c4` | 声呐冷青：次级仪器边框、等深线、冷光生物/石英晶体受控微光 |
| `AMBER` | `#dfb46d` | 航标暖珀：主操作按钮（Primary CTA）、热泉微光、航路信标与高优提示 |
| `DANGER` | `#d76e62` | 珊瑚朱红：低氧/低耐久告警、敌对掠食者威胁提示 |
| `PANEL` | `rgba(0.035, 0.085, 0.12, 0.94)` | 仪器舱底板：半透明深青墨色面板，配合 `1px` `20%` 透明度 `CYAN` 细边框 |
| `MUTED` | `#91a9ab` | 雾化灰青：次要说明文字、禁用态控件与辅助标尺 |

### 2.2 九大海域色板与空间锚点表（对照 `scripts/art_direction.gd`）

世界地形通过 `ArtDirection.region_weights()` 以径向 `smoothstep(0.30 * R, R, d)` 平滑混合八大外围海域与中央核心区（`core` 承接剩余权重），并由 `OceanDepths.region_palette_texture()` 编码为 `9×2` `RGBA8` 贴图供海床着色器采样（第 `0` 行为 `sand`，第 `1` 行为 `rock`）：

| 海域 ID | 空间锚点 `(X, Z)` 与半径 `R` | `water`（水体） | `sand`（沉积沙） | `rock`（岩体） | `flora`（植群） | `accent`（点缀） | `shadow`（暗部） |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `core` | 全局基底（权重补集） | `#166b78` | `#d8c49e` | `#7e8b85` | `#839f69` | `#d8856a` | `#254753` |
| `atoll` | `(40, 340)`, `R = 255m` | `#187e89` | `#e4d7b4` | `#a1ad9b` | `#8eaa74` | `#e5b75f` | `#325964` |
| `kelp` | `(-260, 280)`, `R = 200m` | `#163f45` | `#b8b591` | `#657c70` | `#7c9752` | `#c9b56c` | `#233e44` |
| `ridge` | `(380, 290)`, `R = 220m` | `#203f5a` | `#a6b1ae` | `#819cac` | `#8a94a2` | `#91ccc8` | `#273d54` |
| `citadel` | `(460, -60)`, `R = 245m` | `#173b4b` | `#a3aa9a` | `#86958b` | `#8c8b94` | `#78bdb6` | `#243e4a` |
| `wreck` | `(420, -380)`, `R = 235m` | `#152e3d` | `#8f8b7d` | `#6b7778` | `#909ba0` | `#d99558` | `#273c46` |
| `bones` | `(-480, -90)`, `R = 250m` | `#203b43` | `#9e9986` | `#6f6759` | `#a5a88a` | `#cec7ae` | `#2f454b` |
| `caldera` | `(-440, -420)`, `R = 240m` | `#121f28` | `#756a5e` | `#524a43` | `#b29b85` | `#c96f36` | `#28343e` |
| `hadal` | `(60, -640)`, `R = 300m` | `#111b35` | `#777d88` | `#6d7b9b` | `#9ca6b1` | `#92bdd2` | `#1b2d44` |

---

## 3. 材质语义与水下光照物理法则

### 3.1 固有本色与水体光吸收严格分离

- **垂向生态带（`scripts/ocean_depths.gd`）**：海床最大深度 `600m`（下潜极限 `660m`），划分为阳光浅礁带（`0–35m`）、大陆架海藻与海扇带（`35–90m`，巨藻上限 `55m`）、暮光陆坡冷水珊瑚带（`90–200m`）、深海盆地海绵与海百合带（`200–360m`）及极深海沟黏土与结核带（`360–600m`）。
- **波长选择性太阳光衰减**：`shaders/sand.gdshader` 与 `shaders/plant_sway.gdshader` 在 `fragment()` 中保持沙砾、岩层、珊瑚与海藻的中性/暖色固有 `ALBEDO`；在 `light()` 中仅对平行太阳光（`LIGHT_IS_DIRECTIONAL`）施加红绿波段优先吸收与相机水深补偿，避免与全局环境光二次叠加变暗：
  - `transmission_sun = exp(-vec3(0.022, 0.0055, 0.0) * depth) * exp(clamp((camera_depth - depth) * 0.012, -8.0, 7.2))`
- **程序化海床微地貌**：`sand.gdshader` 利用无 UV 表面梯度凹凸（`dFdx`/`dFdy`）合成 `0.5m` 沙脊波纹、断崖沉积岩层、陆架砾石与海沟锰结核，并在 `< 46m` 朝上表面叠加随深度指数衰减的双频焦散。

### 3.2 探照灯真实显色与受控自发光

- **局部光源显色还原**：局部光源（`SpotLight3D` / `OmniLight3D`）在着色器中保持 `transmission = vec3(1.0)`。当潜水员头灯（暖白 `Color(1.0, 0.96, 0.88)`）或潜艇探照灯照亮暮光带/深渊海床时，被水柱吸收的红橙暖色（珊瑚、锈蚀沉船、铜矿、岩层）会在光锥内自然显色。
- **自发光白名单与能量上限**：普通底栖珊瑚、岩石与海藻**零自发光**。仅 `LUMINOUS_ASSETS`（如水母、深渊鱼、石英/晶簇、救生舱/沉船/遗迹信标、声波武器）保留受控发光槽位，且运行时由 `Ocean._asset_emission_scale()` 与 `ModelFinish` 二次限幅（例如水母 `0.32`、深渊鱼/晶簇 `0.12`、舱体/遗迹/石英 `0.06`；程序化部件冷光 `0.22`、热泉暖珀光 `0.70`），杜绝过曝霓虹感。

### 3.3 GL Compatibility 渲染器阴影与丁达尔光束预算

项目面向桌面与 WebGL2 双端统一采用 `gl_compatibility` 渲染器（`TONE_MAPPER_FILMIC` 电影级色调映射 + 深度指数雾 `Environment.fog_enabled` + 3D `2× MSAA`）：

- **严格实时阴影预算**：全局仅允许极少数关键投影光源以避免 WebGL 阴影图集与绘制调用瓶颈：
  1. 主平行太阳光 `sun`（`DirectionalLight3D`, `shadow_enabled = true`）；
  2. 潜水员主头灯 `lamp`（`SpotLight3D`, `shadow_enabled = true`），辅以无阴影柔光补光灯 `lamp_fill`；
  3. 每艘潜艇（`scout` / `titan` / `mini`）无论外观灯具数量多少，**最多仅允许 1 盏前照灯开启阴影**（`headlights[i].shadow_enabled = (i == 0)`，由 `tests/art_regression.gd` 强制回归校验）。
- **丁达尔光束（Sun Shafts）预算**：浅海阳光柱由 `26` 片共享 `shaders/shaft.gdshader` 的无光照加色面片组成（`16` 道散射光柱 + `10` 道光幕，`render_mode unshaded, blend_add, depth_draw_never, shadows_disabled`），峰值不透明度严格限制在 `ALPHA <= 0.058`，并在水深 `30–120m` 及相机深度 `85–190m` 区间平滑消隐。

---

## 4. 资产规格、面数/贴图预算与碰撞解耦契约

### 4.1 原创离线资产契约（`tools/create_assets.py` & `assets/source/asset-contract.json`）

全部 `34` 项 3D `.glb` 资产均由 `tools/create_assets.py`（生成器版本 `painterly-ocean-1`，`MIT` 许可，`external_sources = []`）确定性离线生成，包含语义化 8 槽色料图集及完整四通道 PBR 贴图（`albedo`、`normal`、`orm`、`emission`）：

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

美术生产与打包遵循“暂存生成 → 契约校验 → 签名晋升 → 双端无损/压缩隔离导出”的四步闭环：

1. **Blender 离线暂存生成**
   ```bash
   blender --background --factory-startup --python tools/create_assets.py
   ```
   在 `.tools/art-staging/` 下确定性生成 `.glb` 模型与 `asset-manifest.json`，不直接覆盖生产目录。

2. **Godot 契约与回归校验**
   ```bash
   godot --headless --path . -s tests/asset_pipeline.gd -- --staging
   godot --headless --path . -s tests/art_regression.gd
   ```
   `tests/asset_pipeline.gd -- --staging` 校验全部资产的许可证、面数/贴图上限、四通道 PBR 绑定、Godot 空间 `AABB` 尺寸契约与骨骼动画形变，通过后写入 `SHA-256` 校验摘要 `.tools/art-staging/validated.sha256`。`tests/art_regression.gd` 进一步验证冻结碰撞挂载、角色/载具/生物枢轴与阴影预算、材质/动画隔离以及 `1280×800` 与 `1920×1080` 全界面布局无越界无重叠。

3. **生产目录受控晋升**
   ```bash
   blender --background --python tools/create_assets.py -- --promote
   ```
   核对 `.tools/art-staging/validated.sha256` 与暂存清单哈希完全一致后，才将验证通过的 `.glb` 晋升至 `assets/models/` 并同步更新 `assets/source/asset-manifest.json`。桌面端工作区始终保留完整的 `512/1024px` 源级纹理质量。

4. **独立副本 Web 压缩构建（`tools/build_web.mjs`）**
   ```bash
   npm run build:web
   ```
   - 清理并重建隔离构建副本 `.tools/web-build-stage`，仅复制运行时必需文件（`project.godot`、`export_presets.cfg`、`icon.svg*`、`scenes`、`scripts`、`shaders`、`assets/audio`、`assets/collision`、`assets/fonts`、`assets/models`），**`ROOT/assets/models` 保持 100% 零改动**。
   - 在副本内确保 `.glb.import` 启用外置贴图提取（`gltf/embedded_image_handling=1`），仅改写 `<stage>/assets/models/*.png.import` 为有损压缩（`compress/mode=1`）、开启 Mipmap（`mipmaps/generate=true`）并按分级设置 `process/size_limit=256|512`，随后执行 `godot --headless --path <stage> --import` 将压缩纹理真正烘焙进导出缓存。
   - 从 `<stage>` 直接导出 `"Web"` 至 `build/web/index.html`，后处理将 `index.wasm` 与 `index.pck` 进行 `gzip -9` 压缩并切分为 `<= 512 KiB` 的 `.gz.part*` 分片，生成 `chunks.json`、注入浏览器端 `DecompressionStream('gzip')` 并行流式解压 `fetch` 垫片与 `COOP/COEP` `_headers`，并校验所有静态产物严格 `<= 5 MiB`（兼容 Cloudflare Workers 静态资源限制）。
