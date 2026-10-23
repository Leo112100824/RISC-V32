TOP      := tb_top
WORK_LIB := work

VLIB := vlib
VMAP := vmap
VLOG := vlog
VSIM := vsim
PYTHON ?= python

INCDIRS := +incdir+../rtl/core \
           +incdir+../rtl/core/if_stage \
           +incdir+../rtl/core/id_stage \
           +incdir+../rtl/core/ex_stage \
           +incdir+../rtl/core/mem_stage \
           +incdir+../rtl/core/wb_stage

VLOG_FLAGS := -sv -work $(WORK_LIB) $(INCDIRS)
VSIM_FLAGS := -voptargs=+acc

# 直接执行 make 时默认跑控制台回归，而不是生成程序或打开 GUI
.DEFAULT_GOAL := sim
.NOTPARALLEL:

.PHONY: main help lib compile sim gui clean program unit regression-check test-runner

help:
	@echo "make sim      - 控制台回归：89 结果 + 8 trap（默认）"
	@echo "make gui      - 打开 QuestaSim GUI 并加载 start.do 波形"
	@echo "make program  - 重新生成 program.hex / expected.hex"
	@echo "make unit     - 17 个活动 RTL 模块独立回归（失败非零退出）"
	@echo "make regression-check - 模块 + 整核回归，日志在 results/"
	@echo "make test-runner - 回归脚本负向/超时自检"
	@echo "make unit-alu - 单独运行 ALU 测试"
	@echo "make clean    - 删除 work、transcript、波形等构建产物"
	@echo "make doctor   - 检查 make / python / vlog / vsim 是否在 PATH"

# 兼容旧入口：make main 仍然打开 GUI
main: gui

# 检查依赖工具是否可见
doctor:
	@echo "GNU Make : $(MAKE)"
	@echo "Python   : $(PYTHON)"
	-@where vlog
	-@where vsim

# Regenerate the directed test program and golden results.
program:
	$(PYTHON) program/gen_test.py

lib: $(WORK_LIB)/_info

$(WORK_LIB)/_info:
	$(VLIB) $(WORK_LIB)
	$(VMAP) $(WORK_LIB) $(WORK_LIB)

compile: lib
	$(VLOG) $(VLOG_FLAGS) -f filelist.f

# Console regression. The testbench prints PASS/FAIL and exits by itself.
sim:
	$(PYTHON) ../scripts/run_regression.py --suite system --vlib "$(VLIB)" --vlog "$(VLOG)" --vsim "$(VSIM)"

unit:
	$(PYTHON) ../scripts/run_regression.py --suite unit --vlib "$(VLIB)" --vlog "$(VLOG)" --vsim "$(VSIM)"

unit-%:
	$(PYTHON) ../scripts/run_regression.py --bench tb_$(subst -,_,$*) --vlib "$(VLIB)" --vlog "$(VLOG)" --vsim "$(VSIM)"

regression-check:
	$(PYTHON) ../scripts/run_regression.py --suite all --vlib "$(VLIB)" --vlog "$(VLOG)" --vsim "$(VSIM)"

test-runner:
	$(PYTHON) ../scripts/test_run_regression.py

# Interactive QuestaSim GUI.
gui: compile
	$(VSIM) $(VSIM_FLAGS) $(WORK_LIB).$(TOP) -do start.do

clean:
	-vdel -lib $(WORK_LIB) -all
	powershell -NoProfile -Command "Remove-Item -Force -ErrorAction SilentlyContinue transcript, vsim.wlf, tb_top.vcd; exit 0"
