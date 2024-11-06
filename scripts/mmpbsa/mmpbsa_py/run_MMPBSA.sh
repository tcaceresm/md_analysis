#!/usr/bin/bash

set -euo pipefail

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Usage: bash run_MMPBSA.sh [-h] [-d DIRECTORY] [-n REPLICAS] [-r 0|1] [-y 0|1] [-n 0|1]"
   echo
   echo "This script perform MM/PB(G)SA rescoring of docked poses."
   echo "You must run setup_MD.sh first, using the same working directory."    
   echo
   echo "Options:"
   echo "  -h                   Print this help"
   echo "  -d DIRECTORY         Working Directory."
   echo "  -r 0|1               (default=0) Run MM/PBSA rescoring."
   echo "  -g 0|1               (default=0) Run MM/GBSA rescoring."
   echo "  -y REPLICAS_START    (default=1). See example below"
   echo "  -n REPLICAS_END      Replicas. See example below"
   echo

}

# Default values
RUN_MMPBSA=0
RUN_MMGBSA=0
REPLICAS_START=1

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:d:r:g:y:n:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WD_PATH=$OPTARG;;
      r) # Run mm/pbsa rescoring
         RUN_MMPBSA=$OPTARG;;
      g) # Run mm/gbsa rescoring
         RUN_MMGBSA=$OPTARG;;
      n) # Replicas
         REPLICAS_END=$OPTARG;;
      y) # Replicas start
         REPLICAS_START=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

function displayHello() 
{
echo "
##############################
Welcome to run_MMPBSA v0.0.0
Author: Tomás Cáceres <caceres.tomas@uc.cl>
Laboratory of Molecular Design <http://schuellerlab.org/>
https://github.com/tcaceresm/md_analysis
Powered by high fat food and procrastination
##############################
"
}

############################################################
# Check output
############################################################
function check_file() {
  local FILE=$1
  
  if [[ -f "${FILE}.nc" && ! -f "${FILE}_successful.tmp" ]]
  then
    echo "${FILE} output exists but didn't finished correctly".
    echo "Please check ${FILE}.out"
    echo "Exiting"
    echo 0

  elif [[ -f "${FILE}_successful.tmp" ]]
  then
    echo "${FILE} already executed succesfully."
    echo "Skipping."
    echo 1
  else
    echo 2
  fi
}

############################################################
# Run minimization
############################################################

function run_minimization ()
{
  # 3 steps minimization in explicit solvent
  local TOPO=$1
  local REF=$2
  echo "####################"
  echo " Minimization"
  echo "####################"

  echo "Running min_ntr_h.in"
  status=$(check_file "min_ntr_h")
  #status=$? #save output from last command

  if [[ $status -eq 2 ]]
  then
    $CUDA_EXE -O -i min_ntr_h.in -o min_ntr_h.out -x min_ntr_h.nc -r min_ntr_h.rst7 -inf min_ntr_h.info -p $TOPO -c $REF.rst7 -ref $REF.rst7
    touch min_ntr_h_successful.tmp
  fi

  echo
  echo "Running min_ntr_l.in"
  
  status=$(check_file "min_ntr_l")
  #status=$?
  
  if [[ $status -eq 2 ]]
  then
    $CUDA_EXE -O -i min_ntr_l.in -o min_ntr_l.out -x min_ntr_l.nc -r min_ntr_l.rst7 -inf min_ntr_l.info -p $TOPO -c min_ntr_h.rst7 -ref $REF.rst7
    touch min_ntr_l_successful.tmp
  fi

  echo
  echo "Running min_no_ntr.in"
  
  status=$(check_file "min_no_ntr")
  #status=$?

  if [[ $status -eq 2 ]]
  then
    $CUDA_EXE -O -i min_no_ntr.in -o min_no_ntr.out -x min_no_ntr.nc -r min_no_ntr.rst7 -inf min_no_ntr.info -p $TOPO -c min_ntr_l.rst7
  touch "min_no_ntr_successful.tmp"
  fi
}

############################################################
# Strip WAT, Na+, Cl- from rst7
############################################################

function process_rst7 () {
  local LIG=$1
  
  cat > remove_solvent.in <<EOF
parm ../../../topo/${LIG}_solv_com.parm7
trajin min_no_ntr.rst7
strip :WAT,Na+,Cl-
trajout min_no_ntr_noWAT.rst7
EOF
}

############################################################
# Perform MM/PBGSA calculations
############################################################

function run_rescoring () {
  local LIG=$1
  local INPUT_FILE=$2
  local TRAJECTORY=$3
  local COM_TOP=$4
  local REC_TOP=$5
  local LIG_TOP=$6
  local THREADS=$7
  local EXE=$8
  local TYPE=$9

  echo "##############"
  echo " Rescoring"
  echo "##############"

  /usr/bin/mpirun --oversubscribe -np $THREADS ${EXE} -O \
  -i $INPUT_FILE \
  -cp $COM_TOP \
  -rp $REC_TOP \
  -lp $LIG_TOP \
  -y $TRAJECTORY \
  -o ${LIG}_${TYPE}.data \
  -eo ${LIG}_${TYPE}_frame.data 
}



#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ruta de la carpeta de trabajo. Es SCRIPT_PATH / WD_PATH
WDPATH=($(realpath $WD_PATH))

# Receptor
RECEPTOR_PDB=($(basename "${WDPATH}/receptor/"*.pdb))
if [[ ${#RECEPTOR_PDB[@]} -eq 0 ]]
then
    echo "Empty receptor folder."
    echo "Exiting."
    exit 1
fi

RECEPTOR_NAME=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

# Ligandos analizados
LIGANDS_MOL2=("${WDPATH}/ligands/"*.mol2)

if [[ ${#LIGANDS_MOL2[@]} -eq 0 ]]
then
    echo "Empty ligands folder."
    echo "Exiting."
    exit 1
fi

LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

CUDA_EXE=${AMBERHOME}/bin/pmemd.cuda

echo
echo "###########################"
echo "# Receptor is ${RECEPTOR} #"
echo "###########################"
echo 

for rep in $(seq $REPLICAS_START $REPLICAS_END) # Repetitions
  do
    echo "#########################"
    echo "# Doing replica ${rep} !#"
    echo "#########################"
    echo 
      
    for LIG in "${LIGANDS[@]}"
    do
      LIG=$(basename "${LIG}")
      echo "#######################"
      echo " Doing ligand: ${LIG} "
      echo "#######################"
      echo

      # Topology and coord file
      TOPO=${WDPATH}/MD/${RECEPTOR}/proteinLigandMD/${LIG}/topo/
      REF=${WDPATH}/MD/${RECEPTOR}/proteinLigandMD/${LIG}/topo/${LIG}_solv_com
      RESCORING_PATH=${WDPATH}/MD/${RECEPTOR}/proteinLigandMD/${LIG}/setupMD/rep${rep}/mmpbsa_rescoring
      
      cd $RESCORING_PATH
      
      run_minimization $TOPO/${LIG}_solv_com.parm7 $REF
      
      process_rst7 ${LIG}
      cpptraj -i ${RESCORING_PATH}/remove_solvent.in

      if [[ $RUN_MMPBSA -eq 1 ]]
      then
        #create_mmpbsa_input 
        run_rescoring $LIG "mm_pbsa.in" min_no_ntr_noWAT.rst7 ${TOPO}/${LIG}_vac_com.parm7 ${TOPO}/${LIG}_vac_rec.parm7 ${TOPO}/${LIG}_vac_lig.parm7 1 MMPBSA.py.MPI mmpbsa
      elif [[ $RUN_MMGBSA -eq 1 ]]
      then
        #create_mmgbsa_input
        run_rescoring $LIG "mm_gbsa.in" ${RESCORING_PATH}/min_no_ntr_noWAT.rst7 ${TOPO}/${LIG}_vac_com.parm7 ${TOPO}/${LIG}_vac_rec.parm7 ${TOPO}/${LIG}_vac_lig.parm7 1 MMPBSA.py.MPI mmgbsa
      fi
    done
  done
