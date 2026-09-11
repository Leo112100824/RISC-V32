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