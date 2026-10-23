# 定向测试程序

本目录的测试程序覆盖 **RV32I 全部 41 条 + Zicsr 6 条 = 47 条指令**，并额外覆盖：

- `MRET`（trap 返回，不属于 47 条基础列表但异常处理必需）
- 8 类异常：ECALL、EBREAK、非法指令、load 非对齐、store 非对齐、指令地址非对齐、CSR 只读、CSR 未实现

## 生成

```powershell
cd RISC-V32\model_tb
make program        # 或 python program/gen_test.py
make sim            # 编译 + 运行，tb_top 自动比对
```

`gen_test.py` 是一个小型 RV32I/Zicsr 汇编 DSL，负责：

1. 按标签解析分支/跳转/`la` 的偏移与地址；
2. 生成 `program.hex`（指令存储器镜像）；
3. 生成 `expected.hex`（89 个结果字）与 `trap_expected.hex`（8 个 mcause）；
4. 生成 `defs.vh`（结果数/trap 数）和 `checks.txt`（索引到测试名）。

## 内存布局

| 地址 | 用途 |
|---|---|
| `0x0000_0000 – 0x0000_00FF` | 结果数组（每个测试一个字，`sw` 写入） |
| `0x0000_0400 – 0x0000_04FF` | load/store 测试数据区 |
| `0x0000_0600 – 0x0000_06FF` | trap 日志（每条 trap：mcause、mepc、mtval，x27 递增） |
| `0x0000_0080` | trap handler（mtvec） |
| `0x0000_0100` | `_start` |

## 覆盖映射

`checks.txt` 列出 89 个结果的索引与测试名，主要包括：

| 类别 | 测试名 |
|---|---|
| R 型 | ADD / SUB / SLL / SLT / SLTU / XOR / SRL / SRA / OR / AND |
| I 型 | ADDI / SLTI / SLTIU / XORI / ORI / ANDI / SLLI / SRLI / SRAI |
| Load | LB / LH / LW / LBU / LHU（含字节偏移） |
| Store | SB / SH / SW |
| 分支 | BEQ / BNE / BLT / BGE / BLTU / BGEU（taken/not-taken） |
| 跳转 | JAL / JALR（链接值与目标） |
| 高位立即数 | LUI / AUIPC |
| 系统 | FENCE / FENCE.I / ECALL / EBREAK / MRET |
| CSR | CSRRW / CSRRS / CSRRC / CSRRWI / CSRRSI / CSRRCI |

trap 期望原因顺序：

```
11 (ECALL), 3 (EBREAK), 2 (非法指令), 4 (load 非对齐),
6 (store 非对齐), 0 (指令地址非对齐), 2 (CSR 只读), 2 (CSR 未实现)
```

## 说明

- 测试程序假定 `mtvec` 为 direct 模式（低 2 位忽略）。
- trap handler 固定执行 `mepc += 4` 后 `mret`，因此测试指令都是 4 字节指令。
- `x27` 是 trap 日志指针，`x28..x30` 是 handler scratch，`x31` 是 trap 计数；测试主体只使用 `x1..x26`。
- 若新增测试，修改 `gen_test.py` 后重新生成即可，TB 会按 `defs.vh` 自动调整比较数量。
