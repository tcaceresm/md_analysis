#!/usr/bin/bash
set -e
set -u
set -o pipefail

############################################################
# Help                                                     #
############################################################
function Help
{
   # Display Help

   #echo "Syntax: traj_proc.sh -d working_directory -e 1 -p 1 -r 1 [-h|d|e|p|r]"
   echo "Syntax: traj_proc.sh OPTIONS"
   echo "options:"
   echo "h     Print help"
   echo "d     Working Directory."
   echo "e     0|1. Process equilibration output."
   echo "p     0|1. Process production output"
   echo "r     0|1. Compute RMSD from trajectories"
   echo "W     0|1. Remove WAT from trajectories"
   echo
}

################################################################
# Remove waters from molecular dynamics trajectories function. #
################################################################

function removeWater
{
   #ARG1: PROD|EQUI
   #ARG2: (PROD|EQUI)_FILES
   #ARG3: RM_HOH
   #ARG4: LIG
   #ARG5: N_RES
   #ARG6: TOPO
   #              1       2         3      4    5       6
   #removeWater $PROD $PROD_FILES $RM_HOH $LIG $N_RES $TOPO

   echo "Removing WAT from trajectories"
   echo "Copying input $3 file"
      
   cp $2/$3 $1

   sed -i "s/LIG/${4}/g" "$1/$3"
   sed -i "s/NRES/${5}/g" "$1/$3"
   sed -i "s+TOPO_PATH+${6}+g" "$1/$3"

   cd $1

   ${AMBERHOME}/bin/cpptraj -i ${1}/${3}
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

############################################################
#                       Main                               #
############################################################

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PROD_FILES=$SCRIPT_PATH/prod_processing/
EQUI_FILES=$SCRIPT_PATH/equi_processing/

WDPATH=$(realpath $WDPATH) #Working directory, where setupMD was configured

# Analyzed ligands
declare -a LIGANDS_MOL2=($(ls $WDPATH/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

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

for LIG in "${LIGANDS[@]}"
   do
      echo "Doing for $LIG"
    
      for i in 1 2 3 4 5
         do
            
            EQUI="${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD/rep${i}/equi/"
            PROD="${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD/rep${i}/prod/"
            TOPO="${WDPATH}/MD/${RECEPTOR}/${LIG}/topo/"
            N_RES=$(cat ${TOPO}/${LIG}_com.pdb | grep "LIG" | tail -n 1 | awk '{print $5}')

            RM_HOH="remove_hoh_prod" #remove_hoh_prod
            RM_HOH_mmpbsa="remove_hoh_mmpbsa" #remove_hoh_mmpbsa
            RM_HOH_equi="remove_hoh_equi" #remove_hoh_equi
            
            RMSD="prod_rmsd"
            RMSD_equi="equi_rmsd"
         
            if [[ $prod -eq 1 ]]
               then
                  echo "
################################
# Processing Production Files  #
################################
                  "
                  echo "Copying files to $PROD"
                  echo "Copying process_mdout.perl to ${PROD}"   
                  cp $PROD_FILES/process_mdout.perl $PROD

                  cd $PROD
                     
                  #/usr/bin/perl ${PROD}/process_mdout.perl *.out
                                   
               if [[ $WAT -eq 1 ]]
                  then
                     removeWater ${PROD} ${PROD_FILES} ${RM_HOH} ${LIG} ${N_RES} ${TOPO}
                     # echo "Removing WAT from trajectories"
                     # echo "Copying (and preparing) $RM_HOH file"
                     # cp $PROD_FILES/$RM_HOH $PROD
                     # sed -i "s/LIG/${LIG}/g" "$PROD/$RM_HOH"
                     # sed -i "s/NRES/${N_RES}/g" "$PROD/$RM_HOH"
                     # sed -i "s+TOPO_PATH+${TOPO}+g" "$PROD/$RM_HOH"
                     # cd $PROD
                     # ${AMBERHOME}/bin/cpptraj -i ${PROD}/${RM_HOH}
                  else
                     echo "Not removing WAT from trajectories"
               fi
                  #cd $SCRIPT_PATH

               if [[ $rmsd -eq 1 ]]
                  then
                     if test -f ${PROD}/${LIG}_prod_noWAT.nc
                        then
                           echo "Correct production unsolvated coordinates available!"
                           echo "Copying (and overwriting) $RMSD"
                           cp $PROD_FILES/$RMSD $PROD
                           sed -i "s/LIG/${LIG}/g" "$PROD/$RMSD"
                           sed -i "s/NRES/${N_RES}/g" "$PROD/$RMSD"
                           sed -i "s+TOPO_PATH+${TOPO}+g" "$PROD/$RMSD"
                           cd $PROD
                           echo "Calculating RMSD from unsolvated trajectories"
                           ${AMBERHOME}/bin/cpptraj -i ${PROD}/${RMSD}
                           cd $WDPATH
                        else
                           echo "No production unsolvated coordinates available."
                     fi
               fi
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

                  echo "Copying (and overwriting) process_mdout.perl"
                  cp $EQUI_FILES/process_mdout.perl $EQUI
                  echo "Processing *.out files with process_mdout.perl"
                  #/usr/bin/perl $EQUI/process_mdout.perl min_ntr_h.out min_ntr_l.out md_nvt_ntr.out md_npt_ntr.out md_nvt_red_**.out
                  /usr/bin/perl $EQUI/process_mdout.perl min_ntr_h.out min_ntr_l.out md_nvt_ntr.out md_npt_ntr.out ./npt/*.out
               
                  ### REMOVE HOH
                  if [[ $WAT -eq 1 ]]
                     then 
                        removeWater $EQUI $EQUI_FILES $RM_HOH $LIG $N_RES $TOPO
                        # echo "Copying (and overwriting) $RM_HOH_equi"
                        # cp $EQUI_FILES/$RM_HOH_equi $EQUI/npt/
                        # sed -i "s/LIGN/${LIG}/g" "$EQUI/npt/$RM_HOH_equi"
                        # sed -i "s/NRES/${N_RES}/g" "$EQUI/npt/$RM_HOH_equi"
                        # sed -i "s+TOPO_PATH+${TOPO}+g" $EQUI/npt/$RM_HOH_equi

                        # echo "Removing WAT from trajectories"
                        # cd $EQUI/npt
                        # ${AMBERHOME}/bin/cpptraj -i ${EQUI}/npt/${RM_HOH_equi}
                  fi

                  ### Calculate RMSD
                  if  test -f ${EQUI}/npt/${LIG}_equi.nc && [[ $rmsd -eq 1 ]] #unsolvated coordinates
                     then
                        echo "Correct unsolvated coordinates available!"
                        echo "Copying (and overwriting) $RMSD_equi"
                        cp $EQUI_FILES/$RMSD_equi $EQUI/npt/
                        sed -i "s/LIGN/${LIG}/g" "$EQUI/npt/$RMSD_equi"
                        sed -i "s/NRES/${N_RES}/g" "$EQUI/npt/$RMSD_equi"
                        sed -i "s+TOPO_PATH+${TOPO}+g" "$EQUI/npt/$RMSD_equi"

                        cd $EQUI/npt
                        echo "Calculating RMSD from unsolvated trajectories"
                        ${AMBERHOME}/bin/cpptraj -i ${EQUI}/npt/${RMSD_equi}
                     else
                        echo "No unsolvated coordinates available. Can't calculate RMSD"
                  fi
               #  echo "Copying (and overwriting) $RMSD_equi"
               #  cp $EQUI_FILES/$RMSD_equi $EQUI/npt/
               #  sed -i "s/LIGN/${LIG}/g" "$EQUI/npt/$RMSD_equi"
               #  sed -i "s/NRES/${N_RES}/g" "$EQUI/npt/$RMSD_equi"
               
               cd $SCRIPT_PATH
            fi

         done
   done
echo "DONE!"
