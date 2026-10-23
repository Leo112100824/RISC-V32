# RTL 单模块测试环境

运行 `make unit`（可从工程根目录、`RISC-V32` 或 `model_tb` 目录执行）会编译一次，再依次运行 17 个活动 RTL 模块各自的 SystemVerilog testbench。每个 bench 直接实例化被测模块并自检。`scripts/run_regression.py` 同时检查退出码、Fatal/Error/FAIL 和独立的完成标记；失败或超时使回归非零退出。日志分别保存到 `model_tb/results/tb_<module>.log`，`summary.json` 记录逐项结论与检查数量。

在 `model_tb` 中可运行 `make unit-alu`、`make unit-ex-stage`、`make unit-top-module` 单测。完整回归入口是 `make regression-check`，包括 17 个模块和原有 `tb_top`；`make test-runner` 检查错误退出、伪 PASS 和超时处理。

| RTL 模块 | bench | 检查内容 |
|---|---|---|
| `alu` | `tb_alu.sv` | 10 种运算、符号比较、算术移位 |
| `branch_unit` | `tb_branch_unit.sv` | 6 种比较、分支禁用和目标地址 |
| `forward_unit` | `tb_forward_unit.sv` | EX/MEM 优先、x0、load/CSR 禁止 EX/MEM 前递 |
| `imm_gen` | `tb_imm_gen.sv` | I/S/B/U/J/CSR 立即数及符号扩展 |
| `regfile` | `tb_regfile.sv` | x0、读写、同拍旁路 |
| `hazard_unit` | `tb_hazard_unit.sv` | load/CSR use、无效/非法/x0/未使用源 |
| `if1_stage` | `tb_if1_stage.sv` | PC+4、stall、redirect 优先级、valid |
| `if2_stage` | `tb_if2_stage.sv` | 16 项：PC=0、重复 head/tail、skid 晋升、flush 优先 |
| `decoder` | `tb_decoder.sv` | 算术/访存/CSR/ECALL 译码、非法指令副作用门控 |
| `id_stage` | `tb_id_stage.sv` | ID/EX 捕获、寄存器写读、flush |
| `lsu` | `tb_lsu.sv` | 字节 lane、半字/字掩码、符号/零扩展 |
| `csr_file` | `tb_csr_file.sv` | 14 项：高低计数器读写/进位、retire 门控、trap/MRET、CSR 写与事件顺序 |
| `wb_stage` | `tb_wb_stage.sv` | valid/wen/x0 写回门控 |
| `ex_stage` | `tb_ex_stage.sv` | 21 项：IMM/PC+4/MEM-WB 前递、跳转/目标对齐、系统异常、MRET/FENCE.I、MEM 异常优先 |
| `mem_stage` | `tb_mem_stage.sv` | 20 项：5 路写回、CSR 写/置位/清位、只读/未实现保护、非对齐抑制 |
| `rv32_core` | `tb_rv32_core.sv` | 两段真实程序、18 项：前递/停顿、错误路径抑制、trap handler/MRET、MEM 与 EX 同拍异常优先 |
| `top` | `tb_top_module.sv` | 独立实例化顶层，复用同样两段程序和 18 项端到端检查 |

此外，原有 `tb_top.sv` 继续提供指令级端到端回归（89 个结果 + 8 个 trap）。历史 `rtl/legacy` 不在活动编译清单内。

`core_test_env.vh` 只复用内存模型、指令构造函数与 scoreboard；`rv32_core`/`top` 分别直接实例化自己的 DUT。程序 1 检查 load/CSR RAW、taken branch 的错误路径 store/illegal 抑制、ECALL 以及紧邻 `csrw mepc` 的 MRET；程序 2 在 MEM 产生非对齐 load，同时在 EX 产生 ECALL，确认事件确实重叠，且只交付较老异常。两个场景通过完成签名结束，分别记录 44/31 周期到签名；这不是通用 CPI 基准。

当前是定向验证，尚不等于官方兼容性测试或完整功能覆盖率；`riscv-tests`、中断投递、随机测试和 Spike 差分仍待推进。
