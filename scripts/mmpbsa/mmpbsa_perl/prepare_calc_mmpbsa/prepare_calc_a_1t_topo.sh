#!/usr/bin/bash

#### CHANGE THIS VARIABLES #####

ID="afb5_noDegron" #ID del complejo simulado
DRIVE="Backup2"
PROTOCOL="protocolo_n5_30ns"
# Ligandos analizados
declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" )

##############################

for LIG in "${arr[@]}"
    do
    
   
for i in 1 2 3 4 5 	
    do
    WDPATH="/mnt/${DRIVE}/${ID}/${PROTOCOL}/calc_a_1t/${LIG}/topo/" #ojo con el protocolo
    cd $WDPATH    
    /home/tcaceres/amber20/bin/tleap -f ${WDPATH}/leap_topo_gb0_pb3.in > ${WDPATH}/leap_topo_gb0_pb3.log

    
    
 

    done
done
echo "DONE!"
