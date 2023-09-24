#!/usr/bin/bash

#### CHANGE THIS VARIABLES #####

ID="2p1m" #ID del complejo simulado
N_RES="569" # Numero del residuo del ligando. 566 afb5 570 2p1q_noDegron 569 2p1m

# Ligandos analizados
declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" ) 

#Ruta de la carpeta del script (donde se encuentra este script)
DRIVE="Backup1"
SCRIPT_PATH="/mnt/${DRIVE}/scripts"
SCRIPT_PATH_prod="${SCRIPT_PATH}/prod_processing"
SCRIPT_PATH_equi="${SCRIPT_PATH}/equi_processing"

#Ruta de las simulaciones
MDPATH="/mnt/${DRIVE}/${ID}/protocolo_n5_30ns/MD_am1" #ojo con el protocolo

equi=0 #procesar output de la equilibracion
prod=0 #procesar output de la produccion
topo=0 #procesar topologias

rm_hoh=0
rmsd=0

##############################

for LIG in "${arr[@]}"
    do
    echo "Doing for $LIG"
    
for i in 1 2 3 4 5	
    do

    EQUI="${MDPATH}/${LIG}${i}/com/equi/"
    PROD="${MDPATH}/${LIG}${i}/com/prod/"
    CRYST="${MDPATH}/${LIG}${i}/cryst/"
    
    RM_HOH="remove_hoh_prod" #remove_hoh_prod
    RM_HOH_mmpbsa="remove_hoh_mmpbsa" #remove_hoh_mmpbsa
    RM_HOH_equi="remove_hoh_equi" #remove_hoh_equi
    
    RMSD="prod_rmsd"
    RMSD_equi="equi_rmsd"
   
    if [[ $prod -eq 1 ]]
    then
    
	    echo "Copying files to $PROD"
            
	    echo "Copying process_mdout.perl to ${PROD}"
            cp $SCRIPT_PATH_prod/process_mdout.perl $PROD	    
	    

	    if [[ $rm_hoh -eq 1 ]]
	    then
	    	echo "Copying (and overwriting) $RM_HOH"
	    	cp $SCRIPT_PATH_prod/$RM_HOH $PROD
	    	sed -i "s/LIG/${LIG}${i}/g" "$PROD/$RM_HOH"
	    	sed -i "s/NRES/${N_RES}/g" "$PROD/$RM_HOH"
	    fi
	    
	    if [[ $rm_hoh_mmpbsa -eq 1 ]]
	    then
	    	echo "Copying (and overwriting) $RM_HOH_mmpbsa"
	    	cp $SCRIPT_PATH_prod/$RM_HOH_mmpbsa $PROD
	    	sed -i "s/LIG/${LIG}${i}/g" "$PROD/$RM_HOH_mmpbsa"
	    	sed -i "s/NRES/${N_RES}/g" "$PROD/$RM_HOH_mmpbsa"
	    fi
	    
   	    if [[ $rmsd -eq 1 ]]
    	    then
            	echo "Copying (and overwriting) $RMSD"
		cp $SCRIPT_PATH_prod/$RMSD $PROD
		sed -i "s/LIG/${LIG}${i}/g" "$PROD/$RMSD"
		sed -i "s/NRES/${N_RES}/g" "$PROD/$RMSD"
	    fi
		    
	    echo "Copying process_mdout.perl to ../MD_am1/${LIG}/com/prod"
	    cp $SCRIPT_PATH_prod/process_mdout.perl $PROD

    fi
    
    if [[ $topo -eq 1 ]]
    then     
	    echo "Copying files to $CRYST"  
	    echo "Copying (and overwriting) leap_script_4.in\n"
	    cp $SCRIPT_PATH/tleap_input/leap_script_4.in $CRYST
	    sed -i "s/LIGN/${LIG}${i}/g" "$CRYST/leap_script_4.in"
	    sed -i "s/ID/${ID}/g" "$CRYST/leap_script_4.in"
	    sed -i "s/DRIVE/${DRIVE}/g" "$CRYST/leap_script_4.in"
    fi
    
    if [[ $equi -eq 1 ]]
    then
        
	    echo "Copying files to ../MD_am1/${LIG}${i}/com/equi"
	    
	    echo "Copying (and overwriting) $RM_HOH_equi"
	    cp $SCRIPT_PATH/$RM_HOH_equi $EQUI
	    sed -i "s/LIGN/${LIG}${i}/g" "$EQUI/$RM_HOH_equi"
	    sed -i "s/NRES/${N_RES}/g" "$EQUI/$RM_HOH_equi"
	    
	    echo "Copying (and overwriting) $RMSD_equi"
	    cp $SCRIPT_PATH/$RMSD_equi $EQUI
	    sed -i "s/LIGN/${LIG}${i}/g" "$EQUI/$RMSD_equi"
	    sed -i "s/NRES/${N_RES}/g" "$EQUI/$RMSD_equi"

	        
	    echo "Copying (and overwriting) process_mdout.perl"
	    cp $SCRIPT_PATH/process_mdout.perl $EQUI
    fi

    done
done
echo "DONE!"
