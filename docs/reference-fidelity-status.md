# 高保真参考还原状态说明

本记录跟踪 7 套冻结 GPT Image 概念设计图（`assets/source/art-v3/concepts/*.png`）在 Blender 5.2.2 LTS 与 Godot 4.7.2 中的三维高保真重建状态。严格遵循诚实披露原则：**自动化契约、面数与实机渲染测试全部通过，不代表自动获得“100% 等同二维原画”的免审认证；最终艺术相似度由人工视觉审阅裁定。**

## 1. 女性主角潜水员（`concepts/diver.png`）

- **当前模型**：`assets/models/reference_diver.glb`（源文件 `assets/source/reference-fidelity/reference-diver.blend`，`117,578` 三角面、`76` 个合并材质部件、`12` 骨多关节平滑蒙皮，SHA-256 为 `b507d3ef55477d92f5fbdd5996a517267fa31ada94cba777a6dc32b059f44542`）。
- **已完成还原的结构与材质**：柔和东亚青年女性面部解剖与琥珀褐虹膜高光、自然微卷八字刘海与后脑盘髻、高透球形抗压玻璃面罩（Alpha 混合无遮挡白雾）、深海藏青修身潜水服与香槟金走线、带 Voronoi 细胞裂纹浮雕的青瓷色叶形护肩/护臂/护膝、左髋发光生物样本瓶、右大腿深棕皮革配古铜刀柄护手潜水刀鞘、背部象牙白双联氧气瓶及波纹管、象牙白渐变琥珀金燕尾分叉脚蹼。
- **近期修复**：已消除水平潜泳姿态下颈根穿模与发顶贴罩问题，补齐右大腿潜水刀鞘，并完成 `mesh.corner_normals` 多轮平滑/平直收敛，使全部 117,578 个三角面通过 `tests/character_art.gd` 绕序与有限骨骼动画检查。
- **渲染与实机证据**：Blender 多角度正交与潜泳渲染见 `assets/source/reference-fidelity/review-v3/{front,side,back,three-quarter,swimming}.png`；Godot 实机 12 种姿态截图见 `assets/source/reference-fidelity/gameplay/` 与 `assets/source/art-v3/verification/character/`。

## 2. 其余六大类别高保真重制（生物 / 巨兽 / 环境 / 装备 / 潜艇 / 海洋）

- **中小型生物（`concepts/creatures.png`）**：9 类带骨骼与 NLA 动作的模型（帝王神仙鱼、花鮨群鱼、大青鲨、深渊琵琶鱼、鬼蝠鲼、玳瑁海龟、枪乌贼、红斑梭子蟹、海月水母）均已重制并绘制 1024×1024 PBR 贴图，已修复蟹螯蒙皮衔接与水母口腕过渡。
- **巨型与奇幻生物（`concepts/creatures_large.png`）**：深海长足海蜘蛛、斑纹礁海豹、深渊水龙、风暴飞鱼、克拉肯巨章、远古巨岩神鳌、幽影海狼与荧光幻梭鱼共 8 类部件已按概念图在 `tools/art_v3_hero.py` 中高保真建模并接入 `expedition_library.glb`。
- **环境生态与遗迹（`concepts/environment.png`）**：17 类礁盘岩石、巨藻、鹿角珊瑚、层叠桌形珊瑚、管状珊瑚、棱纹桶状海绵、海葵、柳珊瑚海扇、深海管虫、潮池五腕海星与长刺海胆、迷宫脑珊瑚、砗磲巨蚌、海百合、发光晶簇与古天文星盘石拱遗迹均已重制。
- **装备、资源与舱体（`concepts/equipment.png`）**：潜水匕首、破礁战斧、扇形声呐屏静滞枪、钛/原生铜/海蓝石英/海带束四类采集资源、陶瓷球形内饰逃生舱（`pod.glb`）与断裂铁骨沉船（`shipwreck.glb`）均已重制。
- **潜艇载具（`concepts/submarines.png`）**：`mini`、`scout`、`titan` 三艘潜艇均已重制为全透明青绿曲面玻璃观察罩 + 立体驾驶舱内饰（座椅、仪表台、黄铜舵轮、舷窗与推进器），彻底消除了鼻端白盘遮挡。
- **海洋与水下光影（`concepts/ocean.png`）**：19,328 面同心环海面网格配合海面波峰泡沫、水下斯涅尔窗（Snell's Window）、海底 Voronoi 焦散与体积丁达尔光束着色器。

## 3. 客观边界说明

实时游戏三维资产受单资产面数预算、贴图分辨率（1024×1024）与关节碰撞体积契约限制，手绘概念图中的超微距笔触肌理、发丝级散落碎发与非对称插画透视在实时引擎中仍存在合理的三维工程化取舍。相关状态如实登记在 `assets/source/reference-fidelity/acceptance.json` 与 `assets/source/reference-fidelity/technical-verification.json`。

## 复现人物制作稿与验证

```powershell
rtk proxy blender --background --factory-startup --python tools/create_reference_diver.py
Copy-Item -LiteralPath assets/source/reference-fidelity/reference_diver.glb -Destination assets/models/reference_diver.glb -Force
rtk proxy godot --headless --path . --import
rtk proxy python -X utf8 tools/verify_reference_diver.py --godot godot
```
