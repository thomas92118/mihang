# Direct Research Notes: 深海迷航 2 (Subnautica 2) 游戏深度调研与优化方案

**Slug**: `subnautica-2-research`  
**Date**: 2026-09-13  
**Method**: Direct Multi-Angle Web & Technical Pipeline Research

---

## 1. Search Queries Executed (检索查询记录)

1. `"Subnautica 2" "Unknown Worlds" official announcement details gameplay Unreal Engine 5 multiplayer`
2. `"Subnautica 2" features co-op UI PDA new planet biomes story`
3. `Subnautica numerical design oxygen depth progression crafting economy game design analysis`
4. `"Subnautica 2" UI HUD PDA inventory base building improvements`
5. `"Subnautica 2" "Unreal Engine 5" graphics Nanite Lumen water physics biomes`
6. `Subnautica game design breakdown oxygen mechanics progression curve crafting tree GDC`
7. `"Subnautica 2" story lore plot protagonist Alterra Architects`
8. `Subnautica Below Zero player criticism feedback Sea Truck Cyclops story inventory`
9. `"Subnautica" numerical design depth gates oxygen consumption crafting costs balance`

---

## 2. Core Fact Sheet & Technical Data Points (核心调研事实与技术数据)

### A. 研发背景与引擎架构迁移
- **开发商/发行商**: Unknown Worlds Entertainment / KRAFTON。
- **引擎架构升级**: 从初代与《零度之下》的 **Unity 引擎**全面迁移至 **虚幻引擎 5 (Unreal Engine 5)**。
  - 核心痛点根除：初代 Unity 引擎因体素多边形与动态 LOD 生成机制缺陷，导致长期存在严重的“资产突然冒出 (Pop-in)”、大地图帧率骤降与物理碰撞丢失等问题。
  - UE5 特性赋能：
    - **Nanite (虚拟微多边形几何体)**: 彻底解决海底极其复杂的珊瑚礁、海沟岩壁、外星大型残骸的几何拓扑细节，提供近乎无限细节且无视传统 LOD 切换断裂。
    - **Lumen (全动态全局光照与反射)**: 解决水下复杂光线穿透、焦散（Caustics）、浮游生物自发光反射、深海阴影柔和衰减与深海幽闭感营造。
    - **Chaos Physics & Water System**: 驱动动态水流（Ocean Currents）、多向水下拖拽力矩、浮力仿真与载具流体阻力。
    - **World Partition**: 替代前作粗暴的 Chunk 加载，实现大世界流式网格划分与内存管理。

### B. 核心玩法与游戏模式
- **多人协作 (Co-op)**: 正式支持 1~4 人在线跨平台联机合作（保留完整单人生存沉浸体验）。
- **设计哲学**: “三分之一保留（经典探索与深海生存恐怖）、三分之一进化（建造、载具、UI 交互）、三分之一创新（新星球生态、动态洋流、生物演化/环境适应机制）”。
- **抢先体验规模**: 首个章节预计提供 14~20 小时核心体验，包含 10 个以上各具特色的独立生物群系（Biomes）。

### C. 剧情背景与叙事世界观 (Narrative & Worldbuilding)
- **空间背景**: 远离 4546B 星球，设定在由 Alterra 殖民舰队遭遇异变的目标星系：殖民船“蝉号 (Cicada)”搭载 40,000 名冷冻/打印胚胎殖民者前往荒漠星球 Zezura 途中，Alterra 船载 AI 顾问 **NoA** 追踪到神秘异常信号，偏离原航线穿越未授权相转移门，最终坠毁在海洋卫星 **Proteus** 上。
- **叙事驱动力**:
  - **人体重印机制 (Bodyprinting)**：不仅作为游戏死亡惩罚与复活的世界观自洽解释，也是多人联机队友同时存在的机制依托。
  - **派系冲突与生态威胁**：残存人类阵营的分歧，原生智慧/共生生物群系 **Axum**，两株互为对抗的变异病毒株 **Proteavirus**，以及神秘的“世界树 (World Tree)”深海宏观生态。
  - **先驱者/建筑师 (Architects)** 遗存：古老机械-生物融合文明在 Proteus 留下的深海设施与相控门遗迹。

### D. UI/UX 交互与操作体系
- **动态 HUD (Adaptive HUD)**: 闲庭游弋时自动退色虚化，当生命、氧气警戒、水深剧变、辐射/毒素/极端温度或潜水捕食者逼近时即时唤醒高亮。
- **模块化 PDA**: 重组标签页为物品仓储、蓝图制造、扫描百科、演化/适应基因库、任务通讯日志。支持玩家自定义首页标签。
- **导航革命**: 引入全息 3D 洞穴投影扫描雷达（Cave Holographic Mapping）与信号标（Beacons）分级过滤系统，根治前作“下潜容易寻路回水面难”的洞穴窒息迷航痛点。
- **建造体验优化**: 建造枪（Habitat Builder）吸附与对齐算法优化，减小载具对接舱与工作台的几何包围盒尺寸，提供更大拆解判定区。

### E. 数值系统与生态经济曲线
- **氧气循环模型**:
  - 基础氧气量：45秒标准容量。
  - 气瓶进阶梯度：标准气瓶 (+30s，达 75s) -> 大容量气瓶 (+60s，达 135s) -> 超大容量气瓶 (+90s，达 225s)。
  - 深度惩罚与水压代谢：深度超过 100m/200m 在未佩戴抗压再呼吸器（Rebreather）时，每下潜单位时间的氧气消耗存在乘数惩罚（1.5x ~ 3.0x）。
- **空间与深度门槛 (Depth Gates)**:
  - 0 ~ 100m（安全浅滩/海草林）: 基础采集工具与轻量推进器（Seaglide）。
  - 100 ~ 300m（暮光带/暗礁）: 载具阶段开启（新潜水艇 Tadpole / 独眼巨人级前置），初级抗压模块。
  - 300 ~ 800m（午夜带/深海遗迹）: 外骨骼机甲（Prawn Suit）、热能与生化供电、稀有矿石（锂、磁铁矿、红宝石）。
  - 800 ~ 1500m+（深渊带/熔岩或剧毒海沟）: 终极抗压模组、核能科技、离子能源与外星相转移装置。
- **联机模式下的数值挑战**:
  - 4 人联机导致地图浅层消耗性资源（石灰岩、铜、石英、盐）消耗速率翻 4 倍，若沿用固定产出模型将诱发严重资源枯竭与玩家内耗；但大型基地建设与载具材料仅需消耗一次，产生“个体消耗剧增 vs 共享资产冗余”的数值矛盾。

---

## 3. Key Community Pain Points & Design Regressions (前作痛点与反面教材)

1. **《Subnautica: Below Zero》的反思**:
   - 过于密集的真人配音与主动打扰式对白破坏了初代“孤寂、幽闭、向死而生”的崇高感。
   - 地图水体纵深大幅缩水（平均深度与空间广度不及初代），陆地探索占比过大且笨拙。
   - 海斗士载具（Seatruck）虽然模块化，但拖挂过长后机动性如“烤串”般迟钝，缺乏一代独眼巨人号（Cyclops）“移动母舰与机舱火灾警报”的宏大沉浸感。
2. **UI 整理与物品管理地狱**:
   - 后期基地需要建立数十个储物柜，缺乏物品一键分类、就近容器自动拉取与配方追踪。
3. **性能衰减**:
   - 基地规模扩大或下潜过快时，物理碰撞计算与网格加载引发严重掉帧与破音。

---

## 4. Synthesis Direction for Project Optimization (优化方案核心构想)

1. **UI/UX 维度**: 动态自适应雷达、就近储物箱穿透制造（Fabricator Container Linking）、配方钉选 HUD、4人队伍分工战术轮盘。
2. **场景渲染与性能维度**: UE5 Nanite 材质层叠优化、Lumen 水下光追噪点抑制（TSR 联合抗锯齿）、利用深海水雾与流式 World Partition 实现零卡顿加载。
3. **叙事与沉浸感维度**: 恢复环境叙事与氛围悬疑为主轴，联机剧情广播采用“局部触发+异步全员存盘”，杜绝打断玩家自主下潜。
4. **数值与联机经济维度**: 动态资源刷新与富集节点机制（Dynamic Nodes based on Party Size）、多人载具多席位操作（驾驶、声呐侦测、护盾/维修）、阶梯式死亡损失与信标打捞机制。
