create_project -force cpu_proj ./cpu_proj -part xc7a35tcpg236-1
add_files ./cpu.v
add_files ./alu32.v
add_files ./regfile.v
add_files ./decoder.v

add_files -fileset sim_1 ./cpu_tb.v
add_files -fileset sim_1 ./dmem.v
add_files -fileset sim_1 ./imem.v

add_files -fileset sim_1 ./idata.mem
add_files -fileset sim_1 ./expout.txt

update_compile_order -fileset sim_1
launch_simulation
run all
close_sim

launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run [current_run -synth -quiet]
namespace import ::tclapp::xilinx::designutils::report_failfast
report_failfast -csv -transpose -no_header -file utilisation.csv 

launch_simulation -mode post-synthesis -type functional
run all 
close_sim

# namespace import ::tclapp::xilinx::designutils::report_failfast
# open_run [current_run -implementation -quiet]
