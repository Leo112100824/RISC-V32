# 整核定向测试程序

gen_test.py 生成 RV32I/Zicsr 镜像和期望值，供 model_tb/tb_top.v 使用。具体示例见[测试数据修改指南](../../doc/测试数据修改指南.md)，运行与排错见[测试运行指南](../../doc/测试运行与故障排查.md)。

## 源文件与生成文件

在仓库根目录执行 make program，然后 make sim。

| 文件 | 用途 | 是否手改 |
|---|---|---|
| gen_test.py | 汇编 DSL、测试输入、期望值的生成源 | 是 |
| program.hex | 每行一个 32 位指令字 | 否 |
| expected.hex | 按结果序号排列的 32 位期望值 | 否 |
| trap_expected.hex | 按 trap 顺序排列的 cause | 否 |
| defs.vh | 结果数、trap 数宏定义 | 否 |
| checks.txt | 结果索引、测试名、期望值映射 | 否 |

基线为 380 个指令字、89 项结果、8 次 trap；新增测试后数量可以变化。

## 内存布局

imem 和 dmem 是独立数组，数值地址相同不表示共享存储。

| 存储器/地址 | 用途 |
|---|---|
| imem 0x0000 | 入口跳转 |
| imem 0x0080 | trap handler |
| imem 0x0100 | _start |
| dmem 0x0000–0x0163 | 当前 89 个结果字，即 89×4=356 字节 |
| dmem 0x0400–0x04FF | 约定的 load/store 数据区 |
| dmem 0x0600–0x065F | 当前 8 条日志，每条 cause/mepc/mtval 共 12 字节 |

TB 容量：imem 1024 字（4 KiB），dmem 512 字（2 KiB）。保持数据基址 0x400 时结果最多放 256 个字；生成器偏移检查不会自动保证区域互不重叠。增加 trap 还要修改 TB 固定索引的 mtval 分类断言，不能只增加 cause 数量。

## 覆盖

| 类别 | 测试范围 |
|---|---|
| 运算 | R 型 10 条、I 型 9 条；负数/移位/有符号与无符号比较 |
| 访存 | LB/LBU/LH/LHU/LW、SB/SH/SW，偏移和扩展 |
| 控制 | 6 类条件分支 taken/not-taken、JAL/JALR、链接值前递 |
| 高位立即数 | LUI、AUIPC |
| 系统/CSR | FENCE、FENCE.I、6 类 CSR、纯读与只读保护、ECALL/EBREAK、MRET |

trap 顺序：11（ECALL）、3（EBREAK）、2（非法字 0）、4（load 非对齐）、6（store 非对齐）、0（目标非对齐）、2（写只读 CSR）、2（未实现 CSR）。结果序号见 checks.txt。

x1 为结果基址，x2 为访存数据基址；x27 为 trap 日志指针，x28–x30 为 handler 临时寄存器，x31 为 trap 计数。新增用例保持这些约定，并显式初始化所有读取的寄存器。handler 跳过一条 4 字节指令后返回，仅适用于这里的定向同步异常。
