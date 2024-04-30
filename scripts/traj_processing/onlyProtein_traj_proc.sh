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
   echo "W     0|1. Remove WAT from trajectories?"
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:e:p:r:w:" option; do
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
      w) # Remove waters?
         WAT=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done


SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROD_FILES=$SCRIPT_PATH/prod_processing/onlyProtein
EQUI_FILES=$SCRIPT_PATH/equi_processing/onlyProtein
echo $EQUI_FILES
WDPATH=$(realpath $WDPATH) #Working directory, where setupMD was configured

RECEPTOR_PDB=($(ls ${WDPATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

echo "
##############################
Welcome to trajectory processing v0.0.0
Author: Tomás Cáceres <caceres.tomas@uc.cl>
Laboratory of Molecular Design <http://schuellerlab.org/>
https://github.com/tcaceresm/md_analysis
##############################
"

for i in 1 
    do

    EQUI="${WDPATH}/MD/${RECEPTOR}/setupMD/rep${i}/equi/"
    
    PROD="${WDPATH}/MD/${RECEPTOR}/setupMD/rep${i}/prod/"
    TOPO="${WDPATH}/MD/${RECEPTOR}/topo/"
    
    N_RES=$(cat ${TOPO}/${RECEPTOR}_vac.pdb | tail -n 3 | awk '{print $5}')

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
	       sed -i "s/RECEPTOR/${RECEPTOR}/g" "$PROD/$RM_HOH"
	       sed -i "s/NRES/${N_RES}/g" "$PROD/$RM_HOH"
	       sed -i "s+TOPO_PATH+${TOPO}+g" "$PROD/$RM_HOH"
	    	
       if [[ $WAT -eq 1 ]]
       then  
	      echo "Removing WAT from trajectories"
	      #cd $PROD
	      ${AMBERHOME}/bin/cpptraj -i ${PROD}/${RM_HOH}
	    else
         echo "Not removing WAT from trajectories"
       fi
         cd $SCRIPT_PATH

    fi
    

    if [[ "$equi" -eq "1" ]]
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
	    sed -i "s/RECEPTOR/${RECEPTOR}/g" "$EQUI/$RM_HOH_equi"
	    sed -i "s/NRES/${N_RES}/g" "$EQUI/$RM_HOH_equi"

      if [[ $WAT -eq 1 ]]
      then  
	      echo "Removing WAT from trajectories"
	      #cd $PROD
	      ${AMBERHOME}/bin/cpptraj -i ${EQUI}/${RM_HOH_equi}
	   else
         echo "Not removing WAT from trajectories"
      fi      
   
	    
	    #echo "Copying (and overwriting) $RMSD_equi"
	    #cp $EQUI_FILES/$RMSD_equi $EQUI
	    #sed -i "s/RECEPTOR/${RECEPTOR}/g" "$EQUI/$RMSD_equi"
	    #sed -i "s/NRES/${N_RES}/g" "$EQUI/$RMSD_equi"
	    

	        
	    echo "Copying (and overwriting) process_mdout.perl"
	    cp $EQUI_FILES/process_mdout.perl $EQUI
	    #/usr/bin/perl $EQUI/process_mdout.perl min_ntr_h.out min_ntr_l.out md_nvt_ntr.out md_npt_ntr.out md_nvt_red_**.out
	    
	    cd $SCRIPT_PATH
    fi
    
    if [[ $rmsd -eq 1 ]]
    then
        if test -f ${PROD}/${RECEPTOR}_prod_noWAT.nc
        then
            echo "Correct production unsolvated coordinates available!"
            echo "Copying (and overwriting) $RMSD"
	         cp $PROD_FILES/$RMSD $PROD
	         sed -i "s/LIG/${RECEPTOR}/g" "$PROD/$RMSD"
	         sed -i "s/NRES/${N_RES}/g" "$PROD/$RMSD"
	         sed -i "s+TOPO_PATH+${TOPO}+g" "$PROD/$RMSD"
	         cd $PROD
	         echo "Calculating RMSD from unsolvated trajectories"
	         ${AMBERHOME}/bin/cpptraj -i ${PROD}/${RMSD}
	         cd $WDPATH
        else
            echo "No production unsolvated coordinates available."

        if test -f ${EQUI}/${RECEPTOR}_equi.nc
        then
            echo "Correct equilibration unsolvated coordinates available!"
            echo "Copying (and overwriting) $RMSD_equi"
            cp $EQUI_FILES/$RMSD_equi $EQUI
            sed -i "s/RECEPTOR/${RECEPTOR}/g" "$EQUI/$RMSD_equi"
            sed -i "s/NRES/${N_RES}/g" "$EQUI/$RMSD_equi"
            sed -i "s+TOPO_PATH+${TOPO}+g" "$EQUI/$RMSD_equi"
            
            cd $EQUI
            echo "Calculating RMSD from unsolvated trajectories"
            ${AMBERHOME}/bin/cpptraj -i ${EQUI}/${RMSD_equi}
            cd $WDPATH
        else
            echo "No equilibration unsolvated coordinates available."
	     fi    
	 fi
	
	     
    fi
    done
echo "DONE!"
