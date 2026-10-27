# RV32I + Zicsr 五级流水线架构总览

> 工程入口见[工程总览与文档索引](工程总览与文档索引.md)；详细状态、技术债与路线见[工程状态与后续路线](已完成功能与完善方向.md)。

## 1. 流水线划分

```
IF  →  ID  →  EX  →  MEM  →  WB
取指   译码   执行   访存   写回
```

| 级 | 模块 | 关键内容 |
|---|---|---|
| IF | `if_stage` | PC/redirect、同步 BRAM 返回对齐、ID 停顿时保持 IF/ID 指令 |
| ID | `id_stage` | `decoder`（译码+控制+立即数+CSR/SYSTEM）、`regfile`、ID/EX 寄存器 |
| EX | `ex_stage` | `forward_unit`、ALU、`branch_unit`、异常检测、MRET、EX/MEM 寄存器 |
| MEM | `mem_stage` | LSU、CSR 读写、非对齐/CSR 异常、写回数据选择、MEM/WB 寄存器 |
| WB | `wb_stage` | regfile 写口，`valid && wb_en && rd!=0` 门控 |

指令存储器保持同步读：IF 发出地址，下一拍的指令数据与延迟 PC 直接构成 IF/ID 边界。ID stall 时 IF 暂存当前响应；重定向清除旧路径响应后从目标地址重新取指。

## 2. 关键控制

- **前递**：EX/MEM → EX（ALU / PC+4 / IMM）、MEM/WB → EX；EX/MEM 优先。load 与 CSR 读不从 EX/MEM 前递。
- **load-use / CSR-use**：EX 是 load 或 CSR 读且 ID 使用其 `rd` 时 `stall` 1 拍；IF 保持当前指令，ID/EX 插 bubble。
- **控制冒险**：静态预测不跳转；`branch_taken/jal/jalr/mret/fence_i` 产生 redirect，清除 IF 返回和 ID/EX 中的年轻指令。
- **写回旁路**：regfile 支持同拍写优先，覆盖“load 后隔两条指令”的读。

## 3. CSR 与异常

- **CSR**：`csr_file` 在 MEM 级读写；14 个 Machine CSR，含 64 位 `mcycle/minstret` 高低半。
- **CSR 指令**：CSRRW/S/C + 立即数变体；`CSRRS/CSRRC` 的 `rs1=x0` 不写，`CSRRSI/CSRRCI` 的 `zimm=0` 不写。
- **异常**：非法指令、ECALL、EBREAK、指令/load/store 非对齐、CSR 只读/未实现。
- **优先级**：MEM 异常 > EX 异常；trap 写 `mepc/mcause/mtval/mstatus` 并跳到 `mtvec` 基址。
- **MRET**：从 `mepc` 返回，恢复 `mstatus.MIE/MPIE`。

| cause | 含义 |
|---:|---|
| 0 | 指令地址非对齐 |
| 2 | 非法指令 / CSR 只读 / CSR 未实现 |
| 3 | EBREAK |
| 4 | load 非对齐 |
| 6 | store 非对齐 |
| 11 | ECALL from M-mode |

## 4. 存储器接口

| 接口 | 约定 |
|---|---|
| 指令 | 同步读，1 拍延迟；`imem_addr` → 下一拍 `imem_rdata` |
| 数据 | 组合读、同步字节写（`mem_wmask`）；暂无 `mem_ready` 握手 |

> 数据侧若换成同步 BRAM/总线，需要增加 `mem_ready` 并在 MEM 级停顿。这属于阶段七 SoC 集成。

## 5. 代码入口

- 顶层：`rtl/core/top.v`（薄壳）
- 小顶层：`rtl/core/rv32_core.v`
- CSR：`rtl/core/csr_file.v`
- 译码：`rtl/core/id_stage/decoder.v`
- 取指：`rtl/core/if_stage/if_stage.v`
- 架构图：[五级流水线总览](diagrams/riscv32_47instr_框架与完善方向.svg)
- 冒险：`rtl/core/hazard_unit.v`、`rtl/core/ex_stage/forward_unit.v`
- 验证：`model_tb/tb_top.v`、`model_tb/program/gen_test.py`

## 6. 当前边界

- 支持 **47/47** 条 RV32I + Zicsr 指令，额外实现 MRET。
- 89 项结果 + 8 个 trap 原因通过定向仿真。
- 未实现外部中断投递、M/A 扩展、Cache/总线、U/S 模式、FPGA 约束。
- `riscv-tests` 尚未跑；阶段三验收以官方回归为准。
