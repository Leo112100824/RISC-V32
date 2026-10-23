# RV32I + Zicsr 六级流水线处理器

当前实现为 IF1 → IF2 → ID → EX → MEM → WB 六级流水线，支持 RV32I、Zicsr、MRET 和机器模式同步异常。官方兼容性回归、中断、M 扩展与 SoC/FPGA 集成仍待推进。

## 文档入口

| 想做什么 | 阅读文档 |
|---|---|
| 了解工程和实际目录 | [工程总览与文档索引](doc/工程总览与文档索引.md) |
| 跑测试、GUI，查看失败日志 | [测试运行与故障排查](doc/测试运行与故障排查.md) |
| 修改输入、添加检查、重新生成 HEX | [测试数据修改指南](doc/测试数据修改指南.md) |
| 理解流水线、CSR 与异常 | [架构总览](doc/architecture.md) |
| 查看验证基线与下一步 | [工程状态与后续路线](doc/已完成功能与完善方向.md) |
| 查看每个模块覆盖范围 | [单元测试清单](model_tb/unit/README.md) |
| 查看整核程序布局与测试名 | [测试程序说明](model_tb/program/README.md) |

## 快速运行

以下命令在克隆后的仓库目录（含本 README 的目录）执行。需要 Python 3.10+、GNU Make 和 QuestaSim 2024.1；其他仿真器版本尚未在本工程验证。

~~~powershell
make regression-check  # 全部 17 个模块 + 原有整核程序
make unit-alu          # 单测示例
make program           # 修改生成器后重新生成测试数据
make sim               # 验证生成的整核程序
~~~

没有 Make 时可直接调用 Python，详见运行指南。RTL 仿真使用 Python 生成的指令镜像，当前不需要 RISC-V GCC 或 Spike；它们用于后续官方软件测试和差分验证。

日志位于 model_tb/results/，summary.json 保存最近一次运行的汇总。日志、波形和工作库不提交到 Git；测试生成器及其五个生成文件需要一起提交。
