```
RISC-V/
├── rtl/
│   ├── core/          # 六级流水线（IF1/IF2/ID/EX/MEM/WB）+ CSR + 异常单元
│   ├── mem/           # 访存、对齐处理、BRAM 封装
│   └── soc/           # 总线、外设、顶层
├── tb/
│   ├── unit/          # 单元级 testbench（每个模块一个）
│   ├── top/           # 顶层指令级 testbench
│   └── uvm/           # UVM 验证环境（阶段五）
├── sw/
│   ├── tests/         # 裸机测试程序、crt0.S、链接脚本
│   └── bench/         # CoreMark / Dhrystone
├── fpga/              # XDC 约束文件、Vivado 工程、上板脚本
├── scripts/           # 编译、回归、覆盖率收集、差分对比脚本
├── docs/
│   ├── spec/          # RISC-V ISA / 特权架构手册 PDF
│   ├── xilinx/        # UG473、UG472、DS181/DS182 等器件手册
│   ├── adr/           # ⭐ 架构决策记录（面试与答辩的主要依据）
│   ├── diagrams/      # 数据通路框图、流水线时序图
│   └── notes/         # 每周踩坑记录（简历素材，现在就攒）
└── README.md
```

## 文档

- [架构总览](doc/architecture.md)：六级流水线、CSR/异常、存储器接口
- [已完成功能与后续方向](doc/已完成功能与完善方向.md)：47 条指令状态、验证结果、技术债、阶段路线
- [47 条指令框架图](doc/diagrams/riscv32_47instr_框架与完善方向.png)
- [测试程序说明](model_tb/program/README.md)：生成方式、内存布局、覆盖映射
- [历史 v2 框架图](doc/diagrams/archive/pipeline_v2_架构框架.png)
- [历史单周期框架图](doc/diagrams/archive/single_cycle_架构框架.png)

## 快速开始

```powershell
cd model_tb
make          # 默认：控制台回归，89 结果 + 8 trap
make unit     # 17 个活动 RTL 模块的独立测试环境
make regression-check # 模块 + 整核完整回归，严格检查失败状态
make test-runner # 回归脚本错误处理/超时自检
make doctor   # 检查 make / python / vlog / vsim 是否可见
make program  # 重新生成测试程序（可选）
make gui      # QuestaSim GUI + start.do 波形
```

也可以在 `RISC-V32` 或工程根目录直接执行 `make sim`、`make unit`，上层 Makefile 会自动转到 `model_tb`。模块测试清单见 [单元测试环境](model_tb/unit/README.md)。

回归由 `scripts/run_regression.py` 执行，日志与机器可读汇总写入 `model_tb/results/`（已忽略）。回归脚本需要 Python 标准库和 QuestaSim 的 `vlib`、`vlog`、`vsim`；仿真器路径需在 PATH 中，或通过 `--vlib/--vlog/--vsim` 指定。`make sim` 及 `make unit` 在仿真断言失败、缺少 PASS 标记或仿真器退出非零时都会返回失败。
