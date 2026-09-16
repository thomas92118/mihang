# Deep Research Plan: 深海迷航2 (Subnautica 2) 深度架构分析与项目优化方案

**Slug**: `subnautica-2-research`  
**Date**: 2026-09-13  
**Status**: Plan Drafted (Awaiting User Approval)

---

## 1. Key Questions (核心研究问题)

1. **UI / UX 界面与交互设计**
   - 游戏的 HUD 界面层次（氧气、健康、饥渴、深度、方位罗盘等）有哪些演变与设计规范？
   - PDA（个人数字助理）系统的功能架构：物品栏、蓝图库、数据库、日志与地图交互如何组织？
   - 基地建造与水下载具操作界面的交互流（快捷轮盘、电量/耐久监控、模块化插槽）有何特点？
   - 多人合作模式下针对队友情报、标记系统、快捷信号交互的适配改动与可访问性考量。

2. **场景建模与空间关卡设计**
   - 虚幻引擎 5（UE5 - Nanite / Lumen / 水体系统）下的海底场景建模特点、网格精度与 PBR 材质规范。
   - 不同水下生物群系（Biome）的地貌拓扑、垂直纵深构造与空间引导功能。
   - 动植物生态与外星遗迹建筑的资产复用度、碰撞体优化与 LOD / 流式加载（World Partition）策略。
   - 水下光照散射、体积雾、水下折射与粒子氛围对沉浸感和恐怖感（深海恐惧症要素）的塑造功能。

3. **故事情节与叙事节奏**
   - 背景世界观设定（Alterra 集团、先驱者前置文明、新外星星球生态与未知威胁）。
   - 主线剧情推进逻辑：探索驱动 vs 广播任务驱动的触发机制。
   - 环境叙事（PDA 日志录音、残骸遗迹、生物扫描日志）在非线性水下探索中的节奏编排。
   - 4人联机合作环境下的叙事连贯性（剧情碎片共享、进度同步与团队决策）。

4. **数值系统设计与循环经济**
   - 生存底层数值模型：氧气消耗速率（随深度衰减）、生命值、饱食/水分代谢消耗曲线。
   - 资源采集与加工阶梯：基础材料、稀有金属、合成物与高级科技树解锁门槛（时间成本、背包负荷、深潜装备壁垒）。
   - 能源与建造数值体系：基地供电（太阳能/生物/热能/核能）产出与消耗平衡、载具能耗与模块配平。
   - 联机多人生存压力缩放（资源消耗乘数、采集刷新率、协作建造分工成本）。

5. **项目优化方案（基于调研数据的重构建议）**
   - UI/UX：信息过载精简、水下视差反馈、PDA 多任务切页流畅度、手柄/键鼠双端优化方案。
   - 场景与性能：UE5 Nanite 在动态植被与水体中的开销控制、Lumen 降噪策略、大世界分块加载与显存占用优化。
   - 叙事与心流：解决中后期目标模糊、联机割裂感，强化阶段性危机与叙事线索闭环。
   - 数值与玩法闭环：资源收集枯燥期平滑化、载具升级曲线调优、多人协作数值弹性平衡机制。

---

## 2. Evidence Needed (所需证据与数据源)

- **官方发布与开发者披露**: Unknown Worlds 官方博客、财报披露信息、Steam/Epic/Xbox 商店页技术说明、官方预告片（Teaser/Trailer）帧级画面细节与 UE5 引擎特性。
- **前作迭代比对数据**: 《Subnautica 1》与《Subnautica: Below Zero》的 UI 演进对比、数值配置文件（JSON/AssetDump）、引擎性能瓶颈（Unity 阶段的 Pop-in 与物理卡顿）案例。
- **虚幻引擎 5 开放世界与水体管线实操经验**: UE5 Water System、Nanite 可编程网格、Lumen 实时全局光照在水下大型场景的渲染管线指标与性能基准。
- **玩家社区与专家测评反馈**: Reddit (r/subnautica)、Steam 评测区、各核心玩家社群针对前作的 UX、生存痛点、剧情节奏崩塌与卡关点统计。
- **游戏数值经济与关卡设计行业理论**: 生存制作类（Survival Crafting）心流曲线模型、探索奖励循环分析。

---

## 3. Scale Decision (规模决策)

- **主题性质**: 涉及 UI/UX、场景建模与引擎渲染、剧情叙事架构、底层数值模型及系统优化方案 5 个大型专业维度，属于高深度、多领域的系统性研究。
- **执行规模**: **Broad survey / Multi-faceted deep research**（复合型深度调研）。
- **执行架构**: 采用多阶段协同推进：
  - **T1**: UI / UX 架构、信息层级与交互设计调研
  - **T2**: 场景建模、生物群系、UE5 渲染特性与场景性能分析
  - **T3**: 世界观剧情、叙事机制与多人合作环境叙事分析
  - **T4**: 生存代谢、科技树阶梯与联机经济数值设计分析
  - **T5**: 综合调研数据整合与跨维度项目优化方案工程化设计

---

## 4. Task Ledger (任务清单)

| Task ID | 任务内容 | 交付目标文件 | 责任与阶段 | 状态 |
|---|---|---|---|---|
| **T0** | 方案制定与确认 | `outputs/.plans/subnautica-2-research.md` | Lead / 规划阶段 | **Completed** |
| **T1** | UI/UX 架构与交互设计调研 | `outputs/.drafts/subnautica-2-t1-ui.md` | Research / 证据收集 | Pending Approval |
| **T2** | 场景建模、关卡拓扑与渲染分析 | `outputs/.drafts/subnautica-2-t2-art-scene.md` | Research / 证据收集 | Pending Approval |
| **T3** | 剧情线、叙事节奏与联机故事机制 | `outputs/.drafts/subnautica-2-t3-narrative.md` | Research / 证据收集 | Pending Approval |
| **T4** | 数值模型、生存循环与科技树设计 | `outputs/.drafts/subnautica-2-t4-progression.md` | Research / 证据收集 | Pending Approval |
| **T5** | 撰写整合研究报告草稿 (含项目优化方案) | `outputs/.drafts/subnautica-2-research-draft.md` | Lead / 报告撰写 | Pending |
| **T6** | 事实核验与数据源交叉验证引用 | `outputs/.drafts/subnautica-2-research-cited.md` | Verification / 引用校对 | Pending |
| **T7** | 质量评审与严密性审查 (FATAL/MAJOR) | `outputs/.drafts/subnautica-2-research-verification.md` | Review / 审阅 | Pending |
| **T8** | 生成最终研究报告与出处凭证 | `outputs/subnautica-2-research.md`, `.provenance.md` | Delivery / 交付 | Pending |

---

## 5. Verification Log (验证日志)

| 时间戳 | 检查项 | 验证手段 | 结果 | 备注 |
|---|---|---|---|---|
| 2026-09-13 | 目标目录结构就绪 | `mkdir -p outputs/.plans outputs/.drafts` | PASS | 目录结构创建完成 |
| 2026-09-13 | 计划文件落地验证 | `outputs/.plans/subnautica-2-research.md` | PASS | 涵盖 5 大维度及完整任务清单 |
| 待定 | 数据源有效性验证 | 官方网站/公告/技术白皮书验证 | PENDING | 待用户确认后执行 |
| 待定 | 引用完整性验证 | 全文数据点与断言对齐 | PENDING | 待起草完成后执行 |

---

## 6. Decision Log (决策日志)

- **2026-09-13**: 确定主题 Slug 为 `subnautica-2-research`，覆盖《深海迷航 2》的核心系统（UI、场景、剧情、数值）及基于痛点诊断的优化方案。
- **2026-09-13**: 鉴于《深海迷航 2》采用虚幻引擎 5（UE5）并引入最高 4 人合作模式，确定研究重点将围绕 UE5 资产/渲染特性、前作两部作品（Subnautica 1 & Below Zero）的经验与已知痛点、以及多人联机机制对数值和叙事的重塑展开深入剖析。
- **2026-09-13**: 根据工作流规范，在制定好详细研究规划后立即暂停，向用户呈送计划概要并请求显式确认。
