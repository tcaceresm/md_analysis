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
   echo "n     Number of repetitions."
   echo "e     0|1. Process equilibration output."
   echo "p     0|1. Process production output"
   echo "r     0|1. Compute RMSD from trajectories"
   echo "w     0|1. Remove WAT from trajectories"
   echo "o     0|1. Process .out files"
}

################################################################
# Display message                                              #
################################################################

function displayHello
{

echo "
##############################################################
# Welcome to trajectory processing v0.0.0                    #   
# Author: Tomás Cáceres <caceres.tomas@uc.cl>                #
# Laboratory of Molecular Design <http://schuellerlab.org/>  #
# https://github.com/tcaceresm/md_analysis                   #
##############################################################
"
}

################################################################
# Prepare input files                                          #
################################################################

function PrepareInputFile
{
   #               1       2         3      4    5    
   #removeWater $PROD $PROD_FILES $RM_HOH $REC $N_RES 

   echo "Copying input $3 file"
      
   cp $2/$3 $1

   sed -i "s/LIG\|RECEPTOR/${4}/g" "$1/$3"
   sed -i "s/NRES/${5}/g" "$1/$3"

}

################################################################
# Prepare paths & Number of residues                           #
################################################################
function obtainPaths
{
   local WDPATH=$1
   local RECEPTOR=$2

   EQUI="${WDPATH}/MD/${RECEPTOR}/setupMD/rep${i}/equi/"
   PROD="${WDPATH}/MD/${RECEPTOR}/setupMD/rep${i}/prod/"
   TOPO="${WDPATH}/MD/${RECEPTOR}/topo/"
   N_RES=$(cat ${TOPO}/${RECEPTOR}_rec.pdb | tail -n 3 | awk '{print $5}')

}

################################################################
# Process production .out files                                #
################################################################

function processProdOutFiles
{
   local $PROD=$1
   local $PROD_FILES=$2

   echo "Copying process_mdout.perl to ${PROD}"   
   cp $PROD_FILES/process_mdout.perl $PROD               
   /usr/bin/perl ${PROD}/process_mdout.perl ${PROD}/*.out

}

################################################################
# Process equilibration .out files                             #
################################################################

function processEquiOutFiles
{
   local $EQUI=$1
   local $PROD_FILES=$2

   echo "Copying process_mdout.perl to ${PROD}"
   cp $EQUI_FILES/process_mdout.perl $EQUI
   /usr/bin/perl $EQUI/process_mdout.perl min_ntr_h.out min_ntr_l.out md_nvt_ntr.out md_npt_ntr.out ./$ensemble/*.out
}  

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:n:e:p:r:w:o:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WDPATH=$OPTARG;;
      n) # Replicas
         N=$OPTARG;;
      e) # Equilibration processing
         equi=$OPTARG;;
      p) # Production processing
         prod=$OPTARG;;
      r) # Compute RMSD
         rmsd=$OPTARG;;
      w) # Remove waters?
         WAT=$OPTARG;;
      o) # Process out files
         PROCESS_OUT_FILES=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

############################################################
#                       Main                               #
############################################################

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PROD_FILES=$SCRIPT_PATH/prod_processing/onlyProtein/
EQUI_FILES=$SCRIPT_PATH/equi_processing/onlyProtein/

WDPATH=$(realpath $WDPATH) #Working directory, where setupMD was configured

# Analyzed ligands
declare -a LIGANDS_MOL2=($(ls $WDPATH/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

# Analyzed receptor
RECEPTOR_PDB=($(ls ${WDPATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

# Input files names
RM_HOH="remove_hoh_prod" 
RM_HOH_mmpbsa="remove_hoh_mmpbsa"
RM_HOH_equi="remove_hoh_equi" 

RMSD="prod_rmsd"
RMSD_equi="equi_rmsd"

# MD ensemble
ensemble="npt"

displayHello

for i in $(seq 1 $N)
   do
      echo ""
      echo "Processing ${RECEPTOR} repetition ${i}"
      echo ""
      obtainPaths ${WDPATH} $RECEPTOR

      if [[ $prod -eq 1 ]]
         then
            echo ""
            echo "   ################################"
            echo "   # Processing Production Files  #"
            echo "   ################################"
            echo ""
         if [[ $PROCESS_OUT_FILES -eq 1 ]]
            then
               cd $PROD
               processProdOutFiles $PROD $PROD_FILES
         fi
                              
         if [[ $WAT -eq 1 ]]
            then
               cd ${PROD}  
               PrepareInputFile ${PROD} ${PROD_FILES} ${RM_HOH} ${RECEPTOR} ${N_RES} 
               ${AMBERHOME}/bin/cpptraj -i ${PROD}/${RM_HOH}
            else
               echo "   Not removing WAT from trajectories"
         fi

         if [[ $rmsd -eq 1 ]]
            then
               if [[ -f ${RECEPTOR}_prod_noWAT.nc ]]
                  then
                     echo "   Correct unsolvated production coordinates available!"
                     PrepareInputFile ${PROD} ${PROD_FILES} ${RMSD} ${RECEPTOR} ${N_RES}
                     ${AMBERHOME}/bin/cpptraj -i ${PROD}/${RMSD}
                  else
                     echo "   No unsolvated production coordinates available."
               fi
            else
               echo "   Not calculating RMSD"
         fi
      fi 

      if [[ $equi -eq 1 ]]
         then
            #echo ""
            echo -e "   \n##################################"
            echo "   # Processing Equilibration Files #"
            echo "   ##################################"
            echo ""          
            if [[ $PROCESS_OUT_FILES -eq 1 ]]
               then
                  cd $EQUI
                  processEquiOutFiles $EQUI $EQUI_FILES
            fi
            
            ### REMOVE HOH
            if [[ $WAT -eq 1 ]]
               then 
                  cd $EQUI/$ensemble
                  PrepareInputFile ${EQUI}/$ensemble ${EQUI_FILES} ${RM_HOH_equi} ${RECEPTOR} ${N_RES} #${TOPO}
                  ${AMBERHOME}/bin/cpptraj -i ${EQUI}/$ensemble/${RM_HOH_equi}
               else
                  echo ""
                  echo "   Not removing WAT from trajectories"
            fi

            ### Calculate RMSD
            if [[ $rmsd -eq 1 ]] #unsolvated coordinates
               then
                  if [[ -f ${EQUI}/$ensemble/${RECEPTOR}_equi.nc ]]
                     then
                        echo "   Correct unsolvated coordinates available!"
                        PrepareInputFile ${EQUI}/$ensemble ${EQUI_FILES} ${RMSD_equi} ${RECEPTOR} ${N_RES} #${TOPO}
                        echo "   Calculating RMSD from unsolvated trajectories"
                        cd $EQUI/$ensemble
                        ${AMBERHOME}/bin/cpptraj -i ${EQUI}/$ensemble/${RMSD_equi}
                     else
                        echo "   No unsolvated coordinates available. Can't calculate RMSD"
                  fi
               else
                  echo "   Not calculating RMSD"
                  echo ""
            fi
            
      fi

   done
 
echo "DONE!"
