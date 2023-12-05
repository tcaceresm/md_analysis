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

   echo "Syntax: traj_proc.sh -d working_directory -e 1 -p 1 -r 1 [-h|d|e|p|r]"
   echo "options:"
   echo "h     Print help"
   echo "d     Working Directory."
   echo "e     0|1. Process equilibration output."
   echo "p     0|1. Process production output"
   echo "r     0|1. Compute RMSD from trajectories"
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:e:p:r:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WDPATH=$OPTARG;;
      e) # Equilibration processing
         equi=$OPTARG;;
      p) # Production processing
         prod=$OPTARG;;
      r) # Compute RMSD
         rmsd=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done


SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROD_FILES=$SCRIPT_PATH/prod_processing/
EQUI_FILES=$SCRIPT_PATH/equi_processing/

WDPATH=$(realpath $WDPATH) #Working directory, where setupMD was configured
setupMD_PATH=$(realpath ../setupMD/)

# Analyzed ligands
declare -a LIGANDS_MOL2=($(ls $setupMD_PATH/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

echo "
##############################
Welcome to trajectory processing v0.0.0
Author: Tomás Cáceres <caceres.tomas@uc.cl>
Laboratory of Molecular Design <http://schuellerlab.org/>
https://github.com/tcaceresm/md_analysis
##############################
"

for LIG in "${LIGANDS[@]}"
    do
    echo "Doing for $LIG"
    
for i in 1 2 3 4 5
    do

    EQUI="${WDPATH}/MD/${LIG}/setupMD/rep${i}/equi/"
    PROD="${WDPATH}/MD/${LIG}/setupMD/rep${i}/prod/"
    TOPO="${WDPATH}/MD/${LIG}/topo/"
    N_RES=$(cat ${TOPO}/${LIG}_com.pdb | grep -v 'LIG' | tail -n 1 | awk '{print $5}')
    
    RM_HOH="remove_hoh_prod" #remove_hoh_prod
    RM_HOH_mmpbsa="remove_hoh_mmpbsa" #remove_hoh_mmpbsa
    RM_HOH_equi="remove_hoh_equi" #remove_hoh_equi
    
    RMSD="prod_rmsd"
    RMSD_equi="equi_rmsd"
   
    if [[ $prod -eq 1 ]]
    then
            echo "
##############################
Processing Production Files
##############################
"
	    echo "Copying files to $PROD"
	    echo "Copying process_mdout.perl to ${PROD}"   
            cp $PROD_FILES/process_mdout.perl $PROD

            cd $PROD
            
            /usr/bin/perl ${PROD}/process_mdout.perl *.out
            
            echo "Copying (and overwriting) $RM_HOH"
	    cp $PROD_FILES/$RM_HOH $PROD
	    sed -i "s/LIG/${LIG}/g" "$PROD/$RM_HOH"
	    sed -i "s/NRES/${N_RES}/g" "$PROD/$RM_HOH"
	    sed -i "s+TOPO_PATH+${TOPO}+g" "$PROD/$RM_HOH"
	    	
	    echo "Removing WAT from trajectories"
	    #cd $PROD
	    ${AMBERHOME}/bin/cpptraj -i ${PROD}/${RM_HOH}
	    

            cd $SCRIPT_PATH

    fi
    
    
    if [[ $equi -eq 1 ]]
    then
            echo "
##############################
Processing Equilibration Files
##############################
"
        
	    echo "Copying files to $EQUI"
	    
	    cd $EQUI
	    
	    echo "Copying (and overwriting) $RM_HOH_equi"
	    cp $EQUI_FILES/$RM_HOH_equi $EQUI
	    sed -i "s/LIGN/${LIG}/g" "$EQUI/$RM_HOH_equi"
	    sed -i "s/NRES/${N_RES}/g" "$EQUI/$RM_HOH_equi"

	    echo "Removing WAT from trajectories"
	    ${AMBERHOME}/bin/cpptraj -i ${EQUI}/${RM_HOH_equi}	    
	    
	    echo "Copying (and overwriting) $RMSD_equi"
	    cp $EQUI_FILES/$RMSD_equi $EQUI
	    sed -i "s/LIGN/${LIG}/g" "$EQUI/$RMSD_equi"
	    sed -i "s/NRES/${N_RES}/g" "$EQUI/$RMSD_equi"
	    

	        
	    echo "Copying (and overwriting) process_mdout.perl"
	    cp $SCRIPT_PATH/process_mdout.perl $EQUI
	    /usr/bin/perl $EQUI/process_mdout.perl min_ntr_h.out min_ntr_l.out md_nvt_ntr.out md_npt_ntr.out md_nvt_red_**.out
	    
	    cd $SCRIPT_PATH
    fi
    
    if [[ $rmsd -eq 1 ]]
    then
        if test -f ${PROD}/${LIG}_prod_noWAT.nc
        then
            echo "Correct unsolvated coordinates available!"
            echo "Copying (and overwriting) $RMSD"
	    cp $PROD_FILES/$RMSD $PROD
	    sed -i "s/LIG/${LIG}/g" "$PROD/$RMSD"
	    sed -i "s/NRES/${N_RES}/g" "$PROD/$RMSD"
	    sed -i "s+TOPO_PATH+${TOPO}+g" "$PROD/$RMSD"
		
	    echo "Calculating RMSD from unsolvated trajectories"
	    ${AMBERHOME}/bin/cpptraj -i ${PROD}/${RMSD}
        else
            echo "No unsolvated coordinates available."
	fi
	
	if test -f ${EQUI}/${LIG}_equi_noWAT.nc
        then
            echo "Correct unsolvated coordinates available!"
            echo "Copying (and overwriting) $RMSD"
	    cp $EQUI_FILES/$RMSD $PROD
	    sed -i "s/LIG/${LIG}/g" "$EQUI/$RMSD"
	    sed -i "s/NRES/${N_RES}/g" "$EQUI/$RMSD"
	    sed -i "s+TOPO_PATH+${TOPO}+g" "$EQUI/$RMSD"
		
	    echo "Calculating RMSD from unsolvated trajectories"
	    ${AMBERHOME}/bin/cpptraj -i ${EQUI}/${RMSD}
        else
            echo "No unsolvated coordinates available."
	fi
    fi
    done
done
echo "DONE!"
