#!/usr/bin/bash

# Necesito resolver el tema de detectar el ultimo atomo del receptor

#### CHANGE THIS VARIABLES #####

ID="afb5_noDegron" #ID del complejo simulado
DRIVE="Backup2"
# Ligandos analizados
declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" )

##############################

for LIG in "${arr[@]}"
    do
    
   
for i in 1 2 3 4 5 	
    do
    WDPATH="/mnt/${DRIVE}/${ID}/protocolo_n5_30ns/calc_a_1t/${LIG}/snapshots_rep${i}/" #ojo con el protocolo
    cd $WDPATH    
    /home/tcaceres/amber20/bin/mm_pbsa.pl ${WDPATH}/extract_coordinates_com.in > ${WDPATH}/extract_coordinates_com.log

    
    
 

    done
done
echo "DONE!"
