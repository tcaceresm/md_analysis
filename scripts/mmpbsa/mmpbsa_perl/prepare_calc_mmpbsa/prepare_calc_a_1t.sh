#!/usr/bin/bash

#### CHANGE THIS VARIABLES #####

ID="2p1m" #ID del complejo simulado
N_RES="569" # Numero del residuo del ligando. 566 afb5 570 2p1q_noDegron 569 2p1m


# Ligandos analizados
declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" )
declare -a arr=("iaa")

#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="/mnt/Backup2/scripts/prepare_calc_mmpbsa"
#Ruta de las simulaciones
WDPATH="/mnt/Backup2/${ID}/protocolo_n5_30ns" #ojo con el protocolo


degron=0 #procesar input para degron mmpbsa. Solo si ya existen las trayectorias
leap_script="leap_topo_gb0_pb3.in"
extract_coord="extract_coordinates_com.in"
mmpbsa_in="mmpbsa.in"
snapshots="s1_3000_30"
protocol="pb3_gb0"
#LAST_ATOM=9279 # el último átomo considerado como receptor
#TOTAL_ATOM=104595 #Todos los atomos, contando al solvente. Si no sabes, revisa la topologia solvatada del complejo

##############################

for LIG in "${arr[@]}"
    do
    
    if test -f "${WDPATH}/calc_a_1t/" 
    then
        echo "${WDPATH}/calc_a_1t/ exist"
        echo "CONTINUE\n"
    else
     	echo "${WDPATH}/calc_a_1t/ do not exist"
       	echo "Creating ${WDPATH}/calc_a_1t/"
	mkdir "${WDPATH}/calc_a_1t/${LIG}/"
       	echo "DONE\n"
    fi   	
    
    TOPO="${WDPATH}/calc_a_1t/${LIG}/topo/"
    
  
    echo "Doing for ${LIG}"
    echo "Creating directories"
    
    mkdir -p ${WDPATH}/calc_a_1t/${LIG}/{topo,snapshots_rep1,snapshots_rep2,snapshots_rep3,snapshots_rep4,snapshots_rep5,${snapshots}/${protocol}/{rep1,rep2,rep3,rep4,rep5}}
    
    echo "Copying files to $TOPO"  
    echo "Copying ${leap_script} to $TOPO"
    cp $SCRIPT_PATH/${leap_script} $TOPO
    sed -i "s/ID/${ID}/g" "${TOPO}/${leap_script}"	  
    sed -i "s/LIGND/${LIG}1/g" "${TOPO}/${leap_script}"
    sed -i "s+WDPATH+${WDPATH}+g" "${TOPO}/${leap_script}"
    sed -i "s+RUTA+${WDPATH}/calc_a_1t/${LIG}/topo+g" "${TOPO}/${leap_script}"
    sed -i "s+MD_am1+${WDPATH}/MD_am1/${LIG}1/cryst+g" "${TOPO}/${leap_script}"
    
# this is to obtain total atom from parmtop file
   #TOTAL_ATOM=$(cat ${WDPATH}/MD_am1/${LIG}1/cryst/${LIG}1_solv_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') #por si se usan trajectorias solvatadas para la extraccion
   TOTAL_ATOM=$(cat ${TOPO}/${LIG}1_vac_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') # Atomos totales del complejo
   
   #LAST_ATOM_REC=$(cat ${WDPATH}/MD_am1/${LIG}1/cryst/${LIG}1_vac_rec.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') # last atom del receptor #por si se usan trajectorias solvatadas para la extraccion
   LAST_ATOM_REC=$(cat ${TOPO}/${LIG}1_vac_rec.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') # last atom del receptor   
   
   FIRST_ATOM_LIG=$(($LAST_ATOM_REC + 1))
   LAST_ATOM_LIG=$TOTAL_ATOM

for i in 1 2 3 4 5 	
    do

	
    SNAP="${WDPATH}/calc_a_1t/${LIG}/snapshots_rep${i}/"
    
    cp $SCRIPT_PATH/$extract_coord $SNAP
    #sed -i "s/REP/${i}/g" $SNAP/$extract_coord
    sed -i "s/LIGND/${LIG}${i}/g" $SNAP/$extract_coord
    sed -i "s/TOTAL_ATOM/${TOTAL_ATOM}/g" $SNAP/$extract_coord
    sed -i "s/LAST_ATOM_REC/${LAST_ATOM_REC}/g" $SNAP/$extract_coord
    sed -i "s/FIRST_ATOM_LIG/${FIRST_ATOM_LIG}/g" $SNAP/$extract_coord     
    sed -i "s/LAST_ATOM_LIG/${LAST_ATOM_LIG}/g" $SNAP/$extract_coord    
    sed -i "s+RUTA+${WDPATH}/MD_am1/${LIG}${i}/com/prod/+g" $SNAP/$extract_coord
    
    MMPBSA="${WDPATH}/calc_a_1t/${LIG}/${snapshots}/${protocol}/rep${i}/"
    cp "$SCRIPT_PATH/run_mmpbsa_lig2.sh" $MMPBSA
    sed -i "s/LIG/${LIG}/g" "$MMPBSA/run_mmpbsa_lig2.sh"
    sed -i "s/repN/rep${i}/g" "$MMPBSA/run_mmpbsa_lig2.sh"
    sed -i "s/REP/${i}/g" "$MMPBSA/run_mmpbsa_lig2.sh"
    
    cp "$SCRIPT_PATH/run_mmpbsa_slurm2.sh" $MMPBSA
    sed -i "s/LIG/${LIG}/g" "$MMPBSA/run_mmpbsa_slurm2.sh"
    sed -i "s/repN/rep${i}/g" "$MMPBSA/run_mmpbsa_slurm2.sh"
    sed -i "s/REP/${i}/g" "$MMPBSA/run_mmpbsa_slurm2.sh"



    cp "$SCRIPT_PATH/$mmpbsa_in" $MMPBSA
    sed -i "s/LIGND_REP/${LIG}${i}/g" $MMPBSA/${mmpbsa_in}
    sed -i "s/LIGND/${LIG}/g" $MMPBSA/${mmpbsa_in}
    
 

    done
done
echo "DONE!"
