#!/usr/bin/bash

ID="2p1q_iaa"
LIG="iaa"

#Change to current file directory
WDPATH="/mnt/Backup1/UC/10mo_Semestre/tecnicas_avanzadas/dinamica_molecular/tir1/${ID}/protocolo_n5_10ns"

cd $WD_PATH

for i in 1 2 3 4 5 
    do
    
    PATH="${WDPATH}/calc_a_1t/${LIG}${i}/s1_100_1/pb3_gb0"
    
    echo "Changing directory to $PATH\n"
    cd $PATH

    echo "Executing run_mmpbsa_decomp.pbs for ${LIG}${i}"
    /usr/bin/csh run_mmpbsa_decomp.pbs
    echo "Done\n"

    
    done
 
