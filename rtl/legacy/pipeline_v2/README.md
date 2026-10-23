# 六级流水线 v2 归档

本目录保存 2026-10-21 CSR/异常改造之前的六级流水线实现，**不参与编译**。

- 保留原因：对照“无 CSR / 无 trap”的流水线版本，便于回滚与讲解演进。
- 当前活动实现位于 `rtl/core/`，已加入 `csr_file.v`、trap 通路与 CSR 指令。
- 本目录中的 `top.v`、`rv32_core.v` 等文件与当前版本同名，**不要加入 filelist**。

主要差异：

| 项目 | v2（本目录） | 当前 v3 |
|---|---|---|
| CSR | 无 `csr_file` | 14 个 Machine CSR + 计数器 |
| 异常 | 无 | EX/MEM 精确异常，mtvec/mepc/mcause/mtval/mstatus |
| 系统指令 | ECALL/EBREAK/FENCE 仅译码 | ECALL/EBREAK 陷入，FENCE/FENCE.I 执行，MRET 返回 |
| 测试 | 19 项定向检查 | 89 项结果 + 8 个 trap 原因 |
