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
   echo "Usage: bash traj_proc.sh [-h] [-d DIRECTORY] [-n REPLICAS] [-e 0|1] [-p 0|1] [-r 0|1] [-w 0|1] [-o 0|1]"
   echo
   echo "This script process MD trajectories."
   echo "You must run run_MD.sh first, using the same working directory."    
   echo
   echo "Options:"
   echo "  -h     Print help"
   echo "  -d     Working Directory."
   echo "  -y     (default=1) REPLICAS_START."
   echo "  -n     Replicas END."
   echo "  -k     Process Protein-only MD."
   echo "  -z     Process Protein-Ligand MD."
   echo "  -e     0|1. (default=0) Process equilibration output."
   echo "  -p     0|1. (default=0) Process production output"
   echo "  -r     0|1. (default=0) Compute RMSD from trajectories"
   echo "  -w     0|1. (default=0) Remove WAT from trajectories"
   echo "  -o     0|1. (default=0) Process .out files"
}

# Default values
REPLICAS_START=1
PROCESS_EQUI=0
PROCESS_PROD=0
PROCESS_RMSD=0
PROCESS_WAT=0
PROCESS_OUT_FILES=0

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:y:n:k:z:e:p:r:w:o:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WDPATH=$OPTARG;;
      y) # Replicas
         REPLICAS_START=$OPTARG;;
      n) # Replicas end
         REPLICAS_END=$OPTARG;;
      k) # Protein-only
         PROCESS_ONLY_PROTEIN=$OPTARG;;
      z) # Protein-ligand
         PROCESS_PROTEIN_LIGAND=$OPTARG;;
      e) # Equilibration processing
         PROCESS_EQUI=$OPTARG;;
      p) # Production processing
         PROCESS_PROD=$OPTARG;;
      r) # Compute RMSD
         PROCESS_RMSD=$OPTARG;;
      w) # Remove waters?
         PROCESS_WAT=$OPTARG;;
      o) # Process out files
         PROCESS_OUT_FILES=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

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

   local OUTPUT_PATH=$1
   local INPUT_FILE_PATH=$2
   local INPUT_FILE=$3
   local REC_LIG_NAME=$4
   local NRES=$5

   echo "Copying input $INPUT_FILE file"
      
   cp $INPUT_FILE_PATH/$INPUT_FILE $OUTPUT_PATH

   sed -i "s/LIG\|RECEPTOR/${REC_LIG_NAME}/g" "$OUTPUT_PATH/$INPUT_FILE"
   sed -i "s/NRES/${NRES}/g" "$OUTPUT_PATH/$INPUT_FILE"

}

################################################################
# Prepare paths & Number of residues                           #
################################################################
function obtainPaths
{
   local WDPATH=$1
   local RECEPTOR=$2
   local PROCESS_ONLY_PROTEIN=$3
   local PROCESS_PROTEIN_LIGAND=$4
   local LIG=$5
   local ENSEMBLE=$6

   if [[ $PROCESS_ONLY_PROTEIN -eq 1 ]]
   then
      EQUI_PATH="${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/rep${i}/equi/"
      PROD_PATH="${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/rep${i}/prod/${ENSEMBLE}"
      TOPO_PATH="${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/topo/"
      N_RES=$(cat ${TOPO_PATH}/${RECEPTOR}_rec.pdb | tail -n 3 | awk '{print $5}')      
   fi

   if [[ $PROCESS_PROTEIN_LIGAND -eq 1 ]]
   then
      EQUI_PATH="${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD/rep${i}/equi/"
      PROD_PATH="${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD/rep${i}/prod/${ENSEMBLE}"
      TOPO_PATH="${WDPATH}/MD/${RECEPTOR}/${LIG}/topo/"
      N_RES=$(cat ${TOPO}/${LIG}_com.pdb | tail -n 3 | awk '{print $5}')
   fi
}

################################################################
# Process production .out files                                #
################################################################

function processProdOutFiles
{
   local PROD_PATH=$1
   local PROD_FILES=$2

   echo "Copying process_mdout.perl to ${PROD_PATH}/"   
   cp ${PROD_FILES}/process_mdout.perl ${PROD_PATH}/               
   /usr/bin/perl ${PROD_PATH}/process_mdout.perl ${PROD_PATH}/*.out

}

################################################################
# Process equilibration .out files                             #
################################################################

function processEquiOutFiles
{
   local EQUI_PATH=$1
   local EQUI_FILES=$2
   local ENSEMBLE=$3

   echo "Copying process_mdout.perl to ${EQUI_PATH}"
   cp ${EQUI_FILES}/process_mdout.perl ${EQUI_PATH}
   /usr/bin/perl ${EQUI_PATH}/process_mdout.perl min_ntr_h.out min_ntr_l.out md_nvt_ntr.out md_npt_ntr.out ./${ENSEMBLE}/*.out
}

################################################################
# Process everything                                           #
################################################################


function process_trajectories
{
   #echo "PROCESS TRAJECTORIES ARGUMENTS ${@}"
   local WDPATH=$1
   local RECEPTOR=$2
   local LIG=$3
   local PROCESS_EQUI=$4
   local PROCESS_PROD=$5
   local PROCESS_ONLY_PROTEIN=$6
   local PROCESS_PROTEIN_LIGAND=$7
   local PROCESS_OUT_FILES=$8
   local PROCESS_WAT=$9
   local PROCESS_RMSD=${10}
   local ENSEMBLE=${11}

   obtainPaths ${WDPATH} ${RECEPTOR} ${PROCESS_ONLY_PROTEIN} ${PROCESS_PROTEIN_LIGAND} ${LIG} ${ENSEMBLE}

   if [[ $PROCESS_PROD -eq 1 ]]
      then
         echo ""
         echo "   ################################"
         echo "   # Processing Production Files  #"
         echo "   ################################"
         echo ""

         if [[ ${PROCESS_OUT_FILES} -eq 1 ]] # Process .out files
            then
               cd ${PROD_PATH}
               processProdOutFiles ${PROD_PATH} ${PROD_INPUT_FILES}
         fi
                              
         if [[ ${PROCESS_WAT} -eq 1 ]] # Remove waters
            then
               cd ${PROD_PATH}  
               PrepareInputFile ${PROD_PATH} ${PROD_INPUT_FILES} ${RM_HOH} ${RECEPTOR} ${N_RES} 
               ${AMBERHOME}/bin/cpptraj -i ${PROD_PATH}/${RM_HOH}
            else
               echo "   Not removing WAT from trajectories"
         fi

         if [[ ${PROCESS_RMSD} -eq 1 ]] #Calculate RMSD
            then
               echo "   Computing RMSD"
               PrepareInputFile ${PROD_PATH} ${PROD_INPUT_FILES} ${RMSD} ${RECEPTOR} ${N_RES}
               ${AMBERHOME}/bin/cpptraj -i ${PROD_PATH}/${RMSD}
            else
               echo "   Not calculating RMSD"
         fi
   fi 

   if [[ $PROCESS_EQUI -eq 1 ]] # Process equilibration phase files
      then
         echo ""
         echo "   ##################################"
         echo "   # Processing Equilibration Files #"
         echo "   ##################################"
         echo ""          
         if [[ ${PROCESS_OUT_FILES} -eq 1 ]]
            then
               cd ${EQUI_PATH}
               processEquiOutFiles ${EQUI_PATH} ${EQUI_INPUT_FILES} ${ENSEMBLE}
         fi
         
         ### REMOVE HOH
         if [[ ${PROCESS_WAT} -eq 1 ]]
            then 
               cd ${EQUI_PATH}/${ENSEMBLE}
               PrepareInputFile ${EQUI_PATH}/${ENSEMBLE} ${EQUI_INPUT_FILES} ${RM_HOH_equi} ${RECEPTOR} ${N_RES} #${TOPO}
               ${AMBERHOME}/bin/cpptraj -i ${EQUI_PATH}/${ENSEMBLE}/${RM_HOH_equi}
            else
               echo "   Not removing WAT from trajectories"
         fi

         ### Calculate RMSD
         if [[ ${PROCESS_RMSD} -eq 1 ]] #unsolvated coordinates
            then
               PrepareInputFile ${EQUI_PATH}/${ENSEMBLE} ${EQUI_INPUT_FILES} ${RMSD_equi} ${RECEPTOR} ${N_RES} #${TOPO}
               echo "   Calculating RMSD"
               cd ${EQUI_PATH}/${ENSEMBLE}
               ${AMBERHOME}/bin/cpptraj -i ${EQUI_PATH}/${ENSEMBLE}/${RMSD_equi}
            else
               echo "   Not calculating RMSD"
               echo ""
         fi
         
   fi
}

############################################################
#                       Main                               #
############################################################

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PROD_INPUT_FILES=$SCRIPT_PATH/prod_processing/onlyProtein/
EQUI_INPUT_FILES=$SCRIPT_PATH/equi_processing/onlyProtein/

WDPATH=$(realpath $WDPATH) #Working directory, where setupMD was configured

# Analyzed receptor
RECEPTOR_PDB=($(ls ${WDPATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

# Input files names
RM_HOH="remove_hoh_prod.in" 
RM_HOH_equi="remove_hoh_equi.in" 

RMSD="prod_rmsd.in"
RMSD_equi="equi_rmsd.in"

# MD ensemble
ENSEMBLE="npt"

displayHello

for i in $(seq ${REPLICAS_START} ${REPLICAS_END})
do
   if [[ ${PROCESS_ONLY_PROTEIN} -eq 1 ]]
      then
      echo " # Processing Only-protein # "
      echo " #       Repetition ${i}   # "
      LIG=false
      process_trajectories ${WDPATH} ${RECEPTOR} ${LIG} ${PROCESS_EQUI} ${PROCESS_PROD} \
                           ${PROCESS_ONLY_PROTEIN} 0 \
                           ${PROCESS_OUT_FILES} ${PROCESS_WAT} ${PROCESS_RMSD} ${ENSEMBLE}
   fi
   if [[ ${PROCESS_PROTEIN_LIGAND} -eq 1 ]]
      then
      echo " # Processing Protein-Ligand # "
      # Analyzed ligands
      declare -a LIGANDS_MOL2=($(ls ${WDPATH}/ligands/))
      declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

      for LIG in "${LIGANDS[@]}"
         do
         echo "Ligand is ${LIG}"
         process_trajectories ${WDPATH} ${RECEPTOR} ${LIG} ${PROCESS_EQUI} ${PROCESS_PROD} \
                              0 ${PROCESS_PROTEIN_LIGAND} \ 
                              ${PROCESS_OUT_FILES} ${PROCESS_WAT} ${PROCESS_RMSD} ${ENSEMBLE}
      done
   fi
done