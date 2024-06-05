#!/usr/bin/bash

ID="afb5_noDegron"
declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" )
#ID="2p1o"
#declare -a arr=("naa")

#Change to current file directory
#WDPATH="/home/tcaceres/Documents/tecnicas_avanzadas/dinamica_molecular/tir1/${ID}/protocolo_n5_10ns"
WDPATH="/mnt/Backup2/${ID}/protocolo_n5_30ns"
SNAPSHOTS="s1_3000_30"

for LIG in "${arr[@]}"
    do
	for i in 1 2 3 4 5
    	do
        	echo "DOING FOR ${LIG}${i}"
        	OUT="${WDPATH}/calc_a_1t/${LIG}${i}/${SNAPSHOTS}/pb3_gb0"
		grep -i 'delta' ${OUT}/${LIG}${i}_statistics.out.snap -A9999 | grep -iv 'delta' > ${OUT}/${LIG}${i}_statistics_out.snapshot_parsed

    	done

done
