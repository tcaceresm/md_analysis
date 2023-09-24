#!/usr/bin/bash

ID="2p1n"
declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" )
declare -a arr=("cfa")
#Change to current file directory
WDPATH="/mnt/Backup3/${ID}/protocolo_n5_10ns"

for LIG in "${arr[@]}"
do
for i in 1 2 3 4 5
    do
        echo "DOING FOR ${LIG}${i}"
        OUT="${WDPATH}/calc_a_1t/$LIG${i}/s1_500_5/pb4_gb1_dec/"
	grep -i 'delta' ${OUT}/${LIG}${i}_statistics.out -A9999 | grep -iv 'delta' | grep -iv 'number' > ${OUT}/${LIG}${i}_statistics_Decomp_parsed.out

    done

done
