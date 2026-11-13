# GPT Image → Blender 全元素高保真海洋美术重建

> 主角与全类别对照细节见 [高保真参考还原状态](reference-fidelity-status.md) 与 `assets/source/reference-fidelity/acceptance.json`。技术回归通过不自动替代人工最终美术验收。

本轮以通透手绘风格的海洋探险美术方向为基准，由多 Agent 协同完成全套元素的重制：先冻结 7 套 GPT Image 高保真概念设计图，再在 Blender 5.2.2 LTS 中编写可复现建模与程序化 PBR 绘制脚本，导出正式三维网格并接入 Godot 4.7.2 实机运行（概念图仅作造型、结构与配色依据，绝不充当平面贴图替身）。

## 交付内容

| 类别 | 本轮内容 | 可编辑 / 可检查文件 |
| --- | --- | --- |
| 高保真概念图 | 人物、中小型生物、巨型生物、环境生态与遗迹、装备资源与舱体、潜艇载具、海洋光影共 7 套冻结参考图及提示词 | `assets/source/art-v3/concepts/` |
| 女性主角潜水员 | 117,578 三角面、76 个合并绘制部件、12 骨多关节平滑蒙皮；含雕刻五官与琥珀虹膜、微卷刘海与盘髻、透明球形压力面罩、龟裂釉面护甲、右腿皮质黄铜刀鞘、左腰发光生物标本瓶与燕尾双色脚蹼 | `assets/models/reference_diver.glb`、`assets/source/reference-fidelity/` |
| 环境 / 生物 / 装备 | 34 项独立重制 GLB（总计 356,314 三角面），含 17 类珊瑚/海百合/巨蚌/海扇/脑珊瑚/星盘遗迹、9 类带骨骼与 NLA 动作的海洋生物、8 类近战/声波武器、矿石海带资源、逃生舱与沉船 | `assets/models/*.glb`、`assets/source/asset-manifest.json` |
| 潜艇载具与巨型生物 | 76 个 Blender 精细部件（总计 52,214 三角面），涵盖 3 艘全透明观察穹顶与可透视驾驶舱内饰的潜艇（`mini`、`scout`、`titan`）及 8 类大型/深渊巨兽（海蜘蛛、斑纹海豹、深渊水龙、风暴飞鱼、克拉肯、巨岩神鳌、幽影海狼、荧光梭鱼） | `assets/models/expedition_library.glb`、`assets/source/art-v3/expedition-library.json` |
| 海洋 | 近密远疏的同心环海面，19,328 三角面、2,200m 半径、0.75m 近场环距；随观察者移动，保留世界空间波相，增加宽缓长涌和克制浪尖泡沫 | `assets/models/ocean_surface.glb`、两套 water shader |
| Blender 源文件 | 完整 34 项模型库、大型载具生物库与独立高精主角源文件（贴图均已打包） | `assets/source/art-v3/ocean-kit.blend`、`expedition-atelier.blend`、`assets/source/reference-fidelity/reference-diver.blend` |
| 实际效果与验证 | 34 张单资产渲染预览、主角 5 视角渲染与 12 姿态实机截图、九大海区 18 机位及海面/焦散实机采样、机器可读验证报告 | `assets/source/art-v3/previews/`、`assets/source/art-v3/verification/`、`assets/source/reference-fidelity/review-v3/` |

游戏运行时默认激活 `reference_diver.glb` 高保真蒙皮主角（同时保留 `expedition_library.glb` 中的回退部件）；骨骼生物沿用原 NLA 动作契约；地标遗迹与沉船保留原始冻结碰撞体 `assets/collision/*.tscn`，确保游弋穿行、手部武器挂点、载具骑乘与静滞交互契约完整无损。

## 视觉审查与迭代修正

参考图用于指导形体结构、解剖比例、色彩层次与材质质感。实时三维网格受实时渲染预算与三维多视角闭合约束，不将技术测试通过等同于“100% 像素级等同二维插画”。

经过逐张 Blender 预览与 Godot 实机截图审查，本轮额外定位并修复了以下真实视觉缺陷：
- **潜艇观察罩**：消除三艘潜艇鼻端极点产生的不透明白色圆盘伪影，改为完整透澈的青绿曲面玻璃穹顶并完整露出内部座椅、舵轮与仪表台。
- **女性主角潜水员**：修正水平潜泳姿态下颈根部与抗压领圈穿插、微卷刘海与头盔内壁间距，将右大腿白色圆筒替换为深棕皮质镶黄铜潜水刀鞘，并迭代修正混合平直/平滑角法线使 117,578 面全部通过严格绕序校验。
- **生物与生态模型**：修正 `_smoothstep` 反向区间导致的螃蟹螯臂权重断裂（恢复象牙白蟹钳与斑纹螯臂自然衔接）及水母口腕过渡；修正五腕海星极坐标周期并采用礁石表面射线采样贴合；消除柳珊瑚海扇离散色阶与底座串色；加密脑珊瑚网格使回纹平滑圆润；修正原生铜矿金属晶尖、海带束中脉叶缘过渡与沉积灰岩水平层理。

本机 34 项暂存契约校验、主角 7 项专项验证、v3 全量 12 项回归及实机 OpenGL 截图采样全部通过；Windows 桌面版（`build/深蓝回声.exe`）、Web 构建包与桌面成品 120 帧启动冒烟均已更新验证，详见 `assets/source/art-v3/verification/results.json` 与 `assets/source/art-v3/verification/packages.json`。

## 复现

以下命令中的 `blender` 与 `godot` 应替换为本机可执行文件。Windows 本机已使用 Blender 5.2.2 LTS 与 Godot 4.7.2。

```powershell
# 七张参考图保存在 assets/source/art-v3/concepts/；生成提示词紧邻图片。
rtk proxy blender --background --factory-startup --python tools/create_art_v3.py -- --previews
rtk proxy blender --background --factory-startup --python tools/create_reference_diver.py

# 验证暂存 34 项模型，同步主角并晋升导入。
Copy-Item -LiteralPath assets/source/reference-fidelity/reference_diver.glb -Destination assets/models/reference_diver.glb -Force
rtk proxy godot --headless --path . -s tests/asset_pipeline.gd -- --staging
rtk proxy blender --background --factory-startup --python tools/create_art_v3.py -- --promote
rtk proxy godot --headless --path . --import

# 运行主角与全场景技术及实机视觉验证（扫描脚本/Shader错误，不单独采信零退出码）。
rtk proxy python -X utf8 tools/verify_reference_diver.py --godot godot
rtk proxy python -X utf8 tools/verify_art_v3.py --godot godot --visual

# 可选：重渲完整源文件的预览、或仅重建潜艇与巨兽部件库。
rtk proxy blender --background --python tools/create_art_v3.py -- --preview-only
rtk proxy blender --background --factory-startup --python tools/create_art_v3.py -- --hero-only
```

`--assets id...` 只重建指定 GLB，另存 `ocean-kit-subset.blend`，不会覆盖完整源库；准备正式源文件交付时仍应执行一次完整构建。晋升前检查暂存验证签名、每个 GLB 的内容哈希以及两个额外库是否存在。

建模模块分别为 `tools/art_v3_environment.py`、`tools/art_v3_creatures.py`、`tools/art_v3_equipment.py`、`tools/art_v3_hero.py` 以及独立高精人物模块 `tools/create_reference_diver.py`（含 `fidelity_body.py`、`fidelity_head.py`、`fidelity_apparel.py`）；公共尺寸、UV、PBR、骨骼与动画处理复用 `tools/create_assets.py`。`tests/art_v3_pipeline.gd` 与 `tests/reference_diver.gd` 验证真实游戏装配使用 Blender 表面，而非仅检查磁盘文件存在。

本轮验证范围是本地 Compatibility 渲染与本地导出；云端发布、浏览器实机表现及相对旧版的帧率提升不在通过声明中。
