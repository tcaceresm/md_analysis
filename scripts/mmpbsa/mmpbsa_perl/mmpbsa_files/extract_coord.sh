#!/usr/bin/bash

#### CHANGE THIS VARIABLES #####

ID="2p1q" #ID del complejo simulado
N_RES="569" # Numero del residuo del ligando. 566 afb5 570 2p1q_noDegron 569 2p1m


# Ligandos analizados
declare -a arr=("cpya")

#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="/mnt/Backup2/scripts/degron_mmpbsa_files"
#Ruta de las simulaciones
WDPATH="/mnt/Backup3/${ID}/protocolo_n5_10ns" #ojo con el protocolo

degron=1 #procesar input para degron mmpbsa. Solo si ya existen las trayectorias

extract_coord="extract_coordinates_com.in"

##############################

for LIG in "${arr[@]}"
    do
       
for i in 1 2 3 4 5 	
    do

    
    SNAP="${WDPATH}/calc_a_1t/${LIG}_degron_gbind/snapshots_rep${i}/"
    
    cd $SNAP
    
    mm_pbsa.pl ${SNAP}/extract_coordinates_com.in   
 

    done
done
echo "DONE!"
