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
   echo "Minimization needs to be performed at least one time before performing MM/PB(G)SA calculations."
   echo "If you need to compute MM/PB(G)SA for several ligands, specify [-c] flag. See below."
   echo " In this case, each ligand calculation will be asigned to different threads and ran in parallel."
   echo " Only MM/PB(G)SA calculation can be parallelized. Minimization won't be parallelized"

   echo
   echo "Options:"
   echo "  -h                   Print this help"
   echo "  -d DIRECTORY         Working Directory."
   echo "  -m MINIMIZATION      (default=0) Run minimization"
   echo "  -r 0|1               (default=0) Run MM/PBSA rescoring."
   echo "  -g 0|1               (default=0) Run MM/GBSA rescoring."
   echo "  -y REPLICAS_START    (default=1). See example below."
   echo "  -n REPLICAS_END      Replicas. See example below."
   echo "  -c NUM_CORES         Number of threads to use."
   echo

}

# Default values
RUN_MMPBSA=0
RUN_MMGBSA=0
REPLICAS_START=1
RUN_MINIMIZATION=0

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:d:m:r:g:y:n:c:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WD_PATH=$OPTARG;;
      m) # Run minimization
         RUN_MINIMIZATION=$OPTARG;;
      r) # Run mm/pbsa rescoring
         RUN_MMPBSA=$OPTARG;;
      g) # Run mm/gbsa rescoring
         RUN_MMGBSA=$OPTARG;;
      n) # Replicas
         REPLICAS_END=$OPTARG;;
      y) # Replicas start
         REPLICAS_START=$OPTARG;;
      c) # Number of threads to use
         NUM_CORES=$OPTARG;;
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
function check_output() {
  
  local file=$1
  
  if [[ -f "${file}.nc" && ! -f "${file}_successful.tmp" ]]
  then
    echo "${file} output exists but didn't finished correctly".
    echo "Please check ${file}.out"
    echo "Exiting"
    echo 0
  elif [[ -f "${file}_successful.tmp" ]]
  then
    echo "${file} already executed succesfully."
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
  local wdpath=$1
  local receptor=$2
  local lig=$3
  local rep=$4

  # Topology and coord file
  topo=${wdpath}/MD/${receptor}/proteinLigandMD/${lig}/topo/
  ref=${wdpath}/MD/${receptor}/proteinLigandMD/${lig}/topo/${li}_solv_com
  #RESCORING_PATH=${WDPATH}/MD/${RECEPTOR}/proteinLigandMD/${LIG}/setupMD/rep${rep}/mmpbsa_rescoring

  echo "####################"
  echo " Minimization receptor: ${receptor} - ligand: ${ligand}"
  echo "####################"

  echo "Running min_ntr_h.in"
  status=$(check_output "min_ntr_h")
  #status=$? #save output from last command

  if [[ $status -eq 2 ]]
  then
    $cuda_exe -O -i min_ntr_h.in -o min_ntr_h.out -x min_ntr_h.nc -r min_ntr_h.rst7 -inf min_ntr_h.info -p $topo -c $ref.rst7 -ref $ref.rst7
    touch min_ntr_h_successful.tmp
  fi

  echo
  echo "Running min_ntr_l.in"
  
  status=$(check_output "min_ntr_l")
  #status=$?
  
  if [[ $status -eq 2 ]]
  then
    $cuda_exe -O -i min_ntr_l.in -o min_ntr_l.out -x min_ntr_l.nc -r min_ntr_l.rst7 -inf min_ntr_l.info -p $topo -c min_ntr_h.rst7 -ref $ref.rst7
    touch min_ntr_l_successful.tmp
  fi

  echo
  echo "Running min_no_ntr.in"
  
  status=$(check_output "min_no_ntr")
  #status=$?

  if [[ $status -eq 2 ]]
  then
    $cuda_exe -O -i min_no_ntr.in -o min_no_ntr.out -x min_no_ntr.nc -r min_no_ntr.rst7 -inf min_no_ntr.info -p $topo -c min_ntr_l.rst7
  touch "min_no_ntr_successful.tmp"
  fi
}

############################################################
# Strip WAT, Na+, Cl- from coordinates
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

function rescoring () {
  
  lig=$1
  rep=$2
  wdpath=$3
  receptor=$4
  input_file=$5
  type=$6

  mmpbsa_exe=$(which MMPBSA.py)
  if [[ -z ${mmpbsa_exe} ]]
  then
    echo "MMPBSA.py not present. Did you source amber?"
    exit 1
  fi

  # rescoring folder
  rescoring_path="${wdpath}/MD/${receptor}/proteinLigandMD/${lig}/setupMD/rep${rep}/mmpbsa_rescoring"
  
  echo "##############"
  echo " Rescoring $receptor - $lig"
  echo "##############"
  
  cd ${rescoring_path}

  ${mmpbsa_exe} -O \
  -i $input_file \
  -cp ../../../topo/${lig}_vac_com.parm7 \
  -rp ../../../topo/${lig}_vac_rec.parm7 \
  -lp ../../../topo/${lig}_vac_lig.parm7 \
  -y min_no_ntr_noWAT.rst7 \
  -o ${lig}_${type}.data \
  -eo ${lig}_${type}_frame.data
  
  echo "DONE!"
  }

############################################################
# Main
############################################################

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

RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

# Ligandos analizados
LIGANDS_MOL2=("${WDPATH}/ligands/"*.mol2)

if [[ ${#LIGANDS_MOL2[@]} -eq 0 ]]
then
    echo "Empty ligands folder."
    echo "Exiting."
    exit 1
fi

LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

echo
echo "###########################"
echo "# Receptor is ${RECEPTOR} #"
echo "###########################"
echo 

################################
# Testing GNU parallel
################################

# Export the function to be used by parallel
export -f rescoring

# Generate a list of all jobs
JOBS_MMPBSA=()
JOBS_MMGBSA=()

for REP in $(seq ${REPLICAS_START} ${REPLICAS_END})
do
  for LIG in "${LIGANDS[@]}"
  do  
    LIG=$(basename "${LIG}")
    
    # Minimization
    if [[ ${RUN_MINIMIZATION} -eq 1 ]]
    then
      run_minimization ${WDPATH} ${RECEPTOR} ${LIG} ${REP} #$TOPO/${LIG}_solv_com.parm7 $REF
    fi
          
    # For each replica-ligand combination, prepare the job for parallel execution
    JOBS_MMPBSA+=("${LIG} ${REP} ${WDPATH} ${RECEPTOR}" "mm_pbsa.in" "mmpbsa") # lig rep wdpath receptor
    JOBS_MMGBSA+=("${LIG} ${REP} ${WDPATH} ${RECEPTOR}" "mm_gbsa.in" "mmgbsa")

  done

done

if [[ ${RUN_MMGBSA} -eq 1 ]]
then
  # Run with GNU parallel
  printf "%s\n" "${JOBS_MMGBSA[@]}" | parallel -j $NUM_CORES --colsep ' ' rescoring {1} {2} {3} {4} {5} {6}
fi

if [[ ${RUN_MMPBSA} -eq 1 ]]
then
  # Run with GNU parallel
  printf "%s\n" "${JOBS_MMPBSA[@]}" | parallel -j $NUM_CORES --colsep ' ' rescoring {1} {2} {3} {4} {5} {6}
fi


# if [[ ${RUN_MMGBSA} -eq 1 ]]
# then
#   JOBS_MMGBSA=()
#   for LIG in "${LIGANDS[@]}"
#   do
#     for REP in $(seq $REPLICAS_START $REPLICAS_END)
#       LIG=$(basename "${LIG}")
#       # For each replica-ligand combination, prepare the job for parallel execution
#       JOBS_MMGBSA+=("${LIG} ${REP} ${WDPATH} ${RECEPTOR}" "mm_gbsa.in" "mmgbsa") # lig rep wdpath receptor
#     done
#   done
#   # Run with GNU parallel
#   printf "%s\n" "${JOBS_MMGBSA[@]}" | parallel -j $NUM_CORES --colsep ' ' rescoring {1} {2} {3} {4} {5} {6}

# fi
