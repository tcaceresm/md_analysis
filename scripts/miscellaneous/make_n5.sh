#!/usr/bin/bash

declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" )

for LIG in "${arr[@]}"
    do
    echo "Doing for $LIG"
for i in 1 2 3 4       
    do
    cp ${LIG}5.mol2 ${LIG}${i}.mol2
done
done
