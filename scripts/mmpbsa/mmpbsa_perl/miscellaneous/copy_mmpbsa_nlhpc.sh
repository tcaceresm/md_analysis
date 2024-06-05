#!/usr/bin/bash

#
# Copia los scripts para ejecutar el calculo a las carpetas respectivas
#
#### CHANGE THIS VARIABLES #####

ID="2p1q_noDegron2" #ID del complejo simulado
N_RES="570" # Numero del residuo del ligando. 566 afb5 570 2p1q_noDegron 569 2p1m
SNAPSHOTS="s1_3000_30"

# Ligandos analizados
declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" ) 
#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="/mnt/Backup2/scripts"
#Ruta de las simulaciones
WDPATH="/mnt/Backup1/${ID}/protocolo_n5_30ns" #ojo con el protocolo

##############################

for LIG in "${arr[@]}"
    do
    echo "Doing for $LIG"
for i in 1 2 3 4 5 	
    do
    
    WHERE="${WDPATH}/calc_a_1t/${LIG}/s1_3000_30/pb3_gb0/rep${i}"
    cp ${SCRIPT_PATH}/run_mmpbsa_lig2.sh ${WHERE}
    sed -i "s/LIG/${LIG}/g" "${WHERE}/run_mmpbsa_lig2.sh"
    sed -i "s/repN/rep${i}/g" "${WHERE}/run_mmpbsa_lig2.sh"
    cp ${SCRIPT_PATH}/run_mmpbsa_slurm2.sh ${WHERE}
    sed -i "s/LIG/${LIG}${i}/g" "${WHERE}/run_mmpbsa_slurm2.sh"
    sed -i "s/ID/${ID}/g" "${WHERE}/run_mmpbsa_slurm2.sh"


    done
done
echo "DONE!"
