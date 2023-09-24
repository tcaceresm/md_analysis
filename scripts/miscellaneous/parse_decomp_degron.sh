#!/usr/bin/bash

ID="2p1q"
#Change to current file directory
WDPATH="/mnt/Backup3/${ID}/protocolo_n5_10ns"

declare -a arr=("iaa_degron_gbind" "ipa_degron_gbind")

for LIG in "${arr[@]}"
    do
    echo "Doing for $LIG"

    for i in 1 2 3 4 5
        do
	    echo "Repetition $i"
	    OUT="${WDPATH}/calc_a_1t/$LIG/s50_100_1/pb4_gb1/rep${i}"
	    grep -i 'delta' ${OUT}/degron${i}_statistics.out -A9999 | grep -iv 'delta' | grep -iv 'number' > ${OUT}/${LIG}${i}_statistics_Decomp_parsed.out

	done
    done
