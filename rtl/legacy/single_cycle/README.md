# 单周期实现归档

本目录保存 2026-10-20 六级流水线改造之前的单周期 RV32I 实现，**不参与编译**。

保留目的：

- 对照重构前后的数据通路与译码逻辑。
- 面试/答辩时说明“单周期 → 六级流水线”的演进过程。
- 需要时可从 `rtl/core` 的新实现回退参考。

| 文件 | 原位置 | 说明 |
|---|---|---|
| `top.v` | `rtl/core/top.v` | 单周期集成顶层 |
| `deocde.v` | `rtl/core/id_stage/deocde.v` | 原 decode（文件名拼写错误） |
| `control_unit.v` | `rtl/core/id_stage/control_unit.v` | 原控制单元 |
| `instr_decoder.v` | `rtl/core/id_stage/instr_decoder.v` | 早期重复译码器 |
| `pc_reg.v` | `rtl/core/if_stage/pc_reg.v` | 原 PC 寄存器 |
| `pc_plus4.v` | `rtl/core/if_stage/pc_plus4.v` | 原 PC+4 |
| `mux.v` | `rtl/core/if_stage/mux.v` | 原下一 PC 四选一 |
| `mux_2_alu.v` | `rtl/core/ex_stage/mux_2_alu.v` | 原 ALU 操作数 mux |
新实现中：

- `decode.v` 与 `control_unit.v` 合并为 `rtl/core/id_stage/decoder.v`。
- `pc_reg/pc_plus4/mux` 折叠进 `rtl/core/if_stage/if1_stage.v`。
- `mux_2_alu` 被 `ex_stage.v` 内的显式前递选择取代。
- `top.v` 变为只连接 `rv32_core` 的薄壳。
