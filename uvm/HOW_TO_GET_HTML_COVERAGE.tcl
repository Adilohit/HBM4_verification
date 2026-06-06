vlib work
vmap work work

vlog -sv -timescale 1ns/1ps +cover=bcfst hbm4_bank_model.sv

vlog -sv -timescale 1ns/1ps +incdir+. hbm4_pkg.sv hbm4_if.sv tb_top.sv

vsim -coverage work.tb_top +UVM_TESTNAME=hbm4_full_regression_test +UVM_VERBOSITY=UVM_MEDIUM

add wave -r sim:/tb top/*

run -all


coverage exclude -scope /tb_top/dut -ftrans state S_ACT_CMD->S_IDLE S_tRCD->S_IDLE S_COL_CMD->S_IDLE S_DATA->S_IDLE S_PRE->S_IDLE
coverage save hbm4_cov.ucdb

quit -sim

vcover report -html -htmldir ./cov_html -details -verbose hbm4_cov.ucdb