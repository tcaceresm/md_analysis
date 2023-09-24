#!/usr/bin/bash

ID="2p1m"
#LIG="iaa"

#Change to current file directory
MDPATH="/mnt/Backup2/${ID}/protocolo_n5_30ns/MD_am1"

declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp")

for LIG in "${arr[@]}"
    do


for i in 1 2 3 4 5
    do
    
    #PATH="${WDPATH}/MD_am1/${LIG}${i}/com/equi"
    PATH="${MDPATH}/${LIG}${i}/com/equi"
    
    echo "Changing directory to $PATH"
    cd $PATH

    echo "Obtaining Summary of out files"
    /usr/bin/perl process_mdout.perl min_ntr_h.out min_ntr_l.out md_nvt_ntr.out md_npt_ntr.out md_nvt_red_**.out
 
 
 #BUG si se repite 2 veces. TO-DO: remover hoh solo cuando no exista el archivo
    echo "Removing WAT from equi coordinates"
    /home/tcaceres/amber20/bin/cpptraj -i ./equi_mdcrd
    echo "Done"
    
    echo "Calculating RMSD without WAT"
    /home/tcaceres/amber20/bin/cpptraj -i ./equi_rmsd
    echo "Done"

    done
 
done
