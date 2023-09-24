#!/usr/bin/bash
set -e
set -u
set -o pipefail

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help

   echo "Syntax: copy_files.sh [-h|i|n|d|e|p|t]"
   echo "options:"
   echo "h     Print help"
   echo "i     ID of protein structure."
   echo "n     Residue Number in structure complex."
   echo "d     Working Directory."
   echo "e     0|1. Process equilibration output."
   echo "p     0|1. Process production output"
   echo "t     0|1. Process topology."
   echo "r     0|1. Compute RMSD from trajectories"
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hi:n:d:e:p:t:r:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      i) # Enter a folder ID.
         ID=$OPTARG;;
      n) # Enter the residue Number from PDB complex structure.
         N_RES=$OPTARG;;
      d) # Enter the MD Directory
         WDPATH=$OPTARG;;
      e) # Equilibration processing
         equi=$OPTARG;;
      p) # Production processing
         prod=$OPTARG;;
      t) # Topology processing
         topo=$OPTARG;;
      r) # Compute RMSD
         rmsd=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

#### CHANGE THIS VARIABLES #####

# Ligandos analizados
declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" ) 
declare -a arr=("iaa") 

#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_PATH_prod="${SCRIPT_PATH}/prod_processing"
SCRIPT_PATH_equi="${SCRIPT_PATH}/equi_processing"

##############################

for LIG in "${arr[@]}"
    do
    echo "Doing for $LIG"
    
for i in 1	
    do

    EQUI="${WDPATH}/MD_am1/${LIG}${i}/com/equi/"
    PROD="${WDPATH}/MD_am1/${LIG}${i}/com/prod/"
    CRYST="${WDPATH}/MD_am1/${LIG}${i}/cryst/"
    
    RM_HOH="remove_hoh_prod" #remove_hoh_prod
    RM_HOH_mmpbsa="remove_hoh_mmpbsa" #remove_hoh_mmpbsa
    RM_HOH_equi="remove_hoh_equi" #remove_hoh_equi
    
    RMSD="prod_rmsd"
    RMSD_equi="equi_rmsd"
   
    if [[ $prod -eq 1 ]]
    then
    
	    echo "Copying files to $PROD"
	    
	    cd $PROD

	    echo "Copying process_mdout.perl to ${PROD}"
            cp $SCRIPT_PATH_prod/process_mdout.perl $PROD
            /usr/bin/perl ${PROD}/process_mdout.perl *.out  
	    
  	    if [[ $rmsd -eq 1 ]]
    	    then
    	        echo "Copying (and overwriting) $RM_HOH"
	    	cp $SCRIPT_PATH_prod/$RM_HOH $PROD
	    	sed -i "s/LIG/${LIG}${i}/g" "$PROD/$RM_HOH"
	    	sed -i "s/NRES/${N_RES}/g" "$PROD/$RM_HOH"
	    	
	    	echo "Removing WAT from trajectories"
	    	${AMBERHOME}/bin/cpptraj -i ${PROD}/${RM_HOH}
	    	
            	echo "Copying (and overwriting) $RMSD"
		cp $SCRIPT_PATH_prod/$RMSD $PROD
		sed -i "s/LIG/${LIG}${i}/g" "$PROD/$RMSD"
		sed -i "s/NRES/${N_RES}/g" "$PROD/$RMSD"
		
		echo "Calculating RMSD from unsolvated trajectories"
		${AMBERHOME}/bin/cpptraj -i ${PROD}/${RMSD}
	    fi
            cd $SCRIPT_PATH

    fi
    
    if [[ $topo -eq 1 ]]
    then     
	    echo "Copying files to $CRYST"  
	    echo "Copying (and overwriting) leap_script_4.in"
	    cp $SCRIPT_PATH/tleap_input/leap_script_4.in $CRYST
	    sed -i "s/LIGN/${LIG}${i}/g" "$CRYST/leap_script_4.in"
	    sed -i "s/ID/${ID}/g" "$CRYST/leap_script_4.in"
	    sed -i "s+WDPATH+${WDPATH}+g" "$CRYST/leap_script_4.in"
    fi
    
    if [[ $equi -eq 1 ]]
    then
        
	    echo "Copying files to $EQUI"
	    
	    cd $EQUI
	    
	    echo "Copying (and overwriting) $RM_HOH_equi"
	    cp $SCRIPT_PATH_equi/$RM_HOH_equi $EQUI
	    sed -i "s/LIGN/${LIG}${i}/g" "$EQUI/$RM_HOH_equi"
	    sed -i "s/NRES/${N_RES}/g" "$EQUI/$RM_HOH_equi"

	    echo "Removing WAT from trajectories"
	    ${AMBERHOME}/bin/cpptraj -i ${EQUI}/${RM_HOH_equi}	    
	    
	    echo "Copying (and overwriting) $RMSD_equi"
	    cp $SCRIPT_PATH_equi/$RMSD_equi $EQUI
	    sed -i "s/LIGN/${LIG}${i}/g" "$EQUI/$RMSD_equi"
	    sed -i "s/NRES/${N_RES}/g" "$EQUI/$RMSD_equi"
	    

	        
	    echo "Copying (and overwriting) process_mdout.perl"
	    cp $SCRIPT_PATH/process_mdout.perl $EQUI
	    /usr/bin/perl $EQUI/process_mdout.perl min_ntr_h.out min_ntr_l.out md_nvt_ntr.out md_npt_ntr.out md_nvt_red_**.out
	    
	    cd $SCRIPT_PATH
    fi

    done
done
echo "DONE!"
