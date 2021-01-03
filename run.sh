#!/bin/sh
#
# Compile and run the test bench

NCYCLES=10000
OUTFILE=output.txt 

[ -x "$(command -v iverilog)" ] || { echo "Install iverilog"; exit 1; }

# Clear out existing log file
rm -f cpu_tb.log 

# Go into the `compile` folder and compile the code
cd compile  && echo "Compiling in $PWD"
./compile.sh main.c > ../test/idata.mem

# Go back to parent directory with verilog code
cd ../
# You may need to change NCYCLES below
iverilog -DNCYCLES=$NCYCLES -DOUTFILE=$OUTFILE -DTESTDIR=\"./test\" -g2012 -o cpu_tb -c program_file.txt
./cpu_tb 

# Check the output in OUTFILE
# retval=$(grep -c "HelloWorld" $OUTFILE)
# if [ ! $retval -eq 0 ];
# then
#     echo "Passed"
# else
#     echo "Failed"
# fi

# cat << EOF

# The print output required by your program should have been printed correctly in output.txt
# EOF

# exit 0
