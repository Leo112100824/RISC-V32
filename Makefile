# Convenience wrapper: run `make` from RISC-V32/ without cd'ing into model_tb.
.PHONY: all sim gui program unit regression-check test-runner clean help
.NOTPARALLEL:

all: sim

sim:
	$(MAKE) -C model_tb sim

gui:
	$(MAKE) -C model_tb gui

program:
	$(MAKE) -C model_tb program

unit:
	$(MAKE) -C model_tb unit

unit-%:
	$(MAKE) -C model_tb unit-$*

regression-check:
	$(MAKE) -C model_tb regression-check

test-runner:
	$(MAKE) -C model_tb test-runner

clean:
	$(MAKE) -C model_tb clean

help:
	@echo "make          - 控制台回归（默认）"
	@echo "make sim      - 控制台回归：89 结果 + 8 trap"
	@echo "make gui      - QuestaSim GUI"
	@echo "make program  - 重新生成测试程序"
	@echo "make unit     - 17 个活动 RTL 模块独立回归"
	@echo "make regression-check - 模块 + 整核完整回归"
	@echo "make test-runner - 回归脚本错误处理自检"
	@echo "make clean    - 清理构建产物"
