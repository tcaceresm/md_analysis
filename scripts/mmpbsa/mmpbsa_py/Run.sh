#!/bin/bash
set -e
set -u
set -o pipefail

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help

   echo "Syntax: bash setup_MD.sh [-h|d]"
   echo "To save a log file and also print the status, run: bash setup_MD.sh -d \$DIRECTORY | tee -a \$LOGFILE"
   echo "Options:"
   echo "h     Print help"
   echo "d     Working Directory."
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:n:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WDPATH=$OPTARG;;
      n) # Number of threads
         THREADS=$OPTARG;; 
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done



SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MMPBSA_IN=${SCRIPT_PATH}/mm_pbsa.in

WDPATH=$(realpath $WDPATH) #Working directory, where setupMD was configured

# Analyzed ligands
declare -a LIGANDS_MOL2=($(ls $WDPATH/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

# Analyzed receptors
RECEPTOR_PDB=($(ls ${WDPATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))


for LIG in "${LIGANDS[@]}"
  do
  
  echo "Doing for $LIG"

  TOPO="${WDPATH}/MD/${RECEPTOR}/${LIG}/topo/"
  COM_TOP=${TOPO}/${LIG}_vac_com.parm7
  REC_TOP=${TOPO}/${LIG}_vac_rec.parm7
  LIG_TOP=${TOPO}/${LIG}_vac_lig.parm7

  for i in 1 2 3 4 5
    do
    
    PROD="${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD/rep${i}/prod/"
    MMPBSA_PATH="${PROD}/mmpbsa/"

    if test -e "${MMPBSA_PATH}"
    then
      echo "${MMPBSA_PATH} exists"
      echo "CONTINUE
        "
    else

      mkdir ${MMPBSA_PATH}
      echo "Created ${MMPBSA_PATH}"
    fi
    
    cp ${MMPBSA_IN} ${MMPBSA_PATH}

    cd ${MMPBSA_PATH}

    /usr/bin/mpirun --oversubscribe -np $THREADS ${AMBERHOME}/bin/MMPBSA.py -O -i mm_pbsa.in \
      -cp $COM_TOP \
      -rp $REC_TOP \
      -lp $LIG_TOP \
      -y ${PROD}/${LIG}_prod_noWAT.nc \
      -o ${LIG}_mmpbsa.data \
      -eo ${LIG}_mmpbsa_frame.data 

      echo "Done MMPBSA calculation for ${LIG} rep${i}"   

    done

  done