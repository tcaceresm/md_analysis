#!/usr/bin/bash

ID="afb5_noDegron"
#Change to current file directory
DRIVE="Backup2"
MDPATH="/mnt/${DRIVE}/${ID}/protocolo_n5_30ns/MD_am1"

summary=0
rm_hoh=0
rmsd=0

declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaaee" "iaa" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" ) 

for LIG in "${arr[@]}"
    do

for i in 1 2 3 4 5
    do
    
    PATH="${MDPATH}/${LIG}${i}/com/prod"
    #PATH="${WDPATH}/MD_am1/${LIG}/com/prod"
    
    echo "Changing directory to $PATH"
    cd $PATH
    
    if [[ $summary -eq 1 ]]
    then
        echo "Obtaining Summary of out files"
        /usr/bin/perl process_mdout.perl *.out
        echo "Done"
    fi
    
    if [[ $rm_hoh -eq 1 ]]
    then
        echo "Removing WAT from prod coordinates"
        /home/tcaceres/amber20/bin/cpptraj -i prod_mdcrd_script_noWAT
        echo "Done"
    fi
    
    if [[ $rmsd -eq 1 ]]
    then
        echo "Calculating RMSD/RMSF without WAT of all residues and BSite"
        /home/tcaceres/amber22/bin/cpptraj -i prod_rmsd_script_noWAT
    fi
    
    done
 done    
