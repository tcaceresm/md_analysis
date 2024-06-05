#!/usr/bin/bash

## CHANGE THIS VARIABLES#
#SCRIPT_PATH="/home/tcaceres/Documents/tecnicas_avanzadas/dinamica_molecular/tir1/scripts/"
#WDPATH="/home/tcaceres/Documents/tecnicas_avanzadas/dinamica_molecular/tir1/"

ID="2p1q_noDegron"
LIG="pic"

SCRIPT_PATH="/mnt/Backup1/UC/10mo_Semestre/tecnicas_avanzadas/dinamica_molecular/tir1/scripts/"
WDPATH="/mnt/Backup1/UC/10mo_Semestre/tecnicas_avanzadas/dinamica_molecular/tir1/${ID}/protocolo_n5_10ns"

equi=0
prod=1
topo=0

###


for i in 1 2 3 4 5
    do
    
    CALC="${WDPATH}/calc_a_1t/${LIG}${i}/s1_100_1/pb3_gb0/"

    
    if [[ $prod -eq 1 ]]
    then
	    echo "Copying run_mmpbsa to $CALC"
	    cp $SCRIPT_PATH/run_mmpbsa_decomp.pbs $CALC
	    sed -i "s/iaa1/${LIG}${i}/g" $CALC/run_mmpbsa_decomp.pbs
	    sed -i "s/2p1q/${ID}/g" $CALC/run_mmpbsa_decomp.pbs


            echo "Copying mmpbsa_decomp.in to $CALC"
            cp $SCRIPT_PATH/mmpbsa_decomp.in $CALC
            sed -i "s/iaa1/${LIG}${i}/g" $CALC/mmpbsa_decomp.in
            sed -i "s/2p1q/${ID}/g" $CALC/mmpbsa_decomp.in
    fi
    done

echo "DONE!"
