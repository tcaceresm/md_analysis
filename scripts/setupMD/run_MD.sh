#!/usr/bin/bash

set -euo pipefail

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Usage: bash run_MD.sh [-h] [-d DIRECTORY] [-n REPLICAS] [-p 0|1] [-z 0|1] [-e 0|1] [-x 0|1]"
   echo
   echo "This script perform molecular dynamics simulations."
   echo "You must run setup_MD.sh first, using the same working directory."    
   echo
   echo "Options:"
   echo "  -h                   Print this help"
   echo "  -d DIRECTORY         Working Directory."
   echo "  -p 0|1               Run Protein-only MD."
   echo "  -z 0|1               Run Protein-Ligand MD."
   echo "  -e 0|1               (default=1) Run equilibration."
   echo "  -x 0|1               (default=1) Run production."
   echo "  -y REPLICAS_START    (default=1). See example below"
   echo "  -n REPLICAS_END      Replicas. See example below"
   echo
   echo "Examples:"
   echo " -Run protein-ligand MD, five replicas"
   echo "   bash run_MD.sh -d /path/to/dir -n 5 -p 0 -z 1"
   echo " -Run protein-ligand, replicas 1 to 3, but no 4 and 5"
   echo "   bash run_MD.sh -d /path/to/dir -y 1 -n 3 -p 0 -z 1"
}

# Default values
EQUI=1
PROD=1
REPLICAS_START=1

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:p:z:e:x:y:n:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WD_PATH=$OPTARG;;
      p) # Protein-Only MD
         ONLY_PROTEIN_MD=$OPTARG;;
      z) # Protein-Ligand MD
         PROT_LIG_MD=$OPTARG;;         
      e) # Run equilibration
         EQUI=$OPTARG;;
      x) # Run production
         PROD=$OPTARG;;
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
Welcome to SetupMD v0.0.0
Author: Tomás Cáceres <caceres.tomas@uc.cl>
Laboratory of Molecular Design <http://schuellerlab.org/>
https://github.com/tcaceresm/md_analysis
Powered by high fat food and procrastination
##############################
"
}

############################################################
# Run Simulations
############################################################

function run_MD ()
{
  local OLD=$1
  local NEW=$2
  local TOPO=$3
  local REF=$4
  local RESTRAINED=$5
  
  if [[ -f "${NEW}.nc" && ! -f "${NEW}_successful.tmp" ]]
  then
    echo "${NEW} output exists but didn't finished correctly".
    echo "Please check ${NEW}.out"
    echo "Exiting"
    exit 1

  elif [[ -f "${NEW}_successful.tmp" ]]
  then
    echo "${NEW} already executed succesfully."
    echo "Skipping."
  else
    echo 
    echo "Running ${NEW}.in"
    echo

    if [[ ${RESTRAINED} -eq 1 ]]
    then  
      $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO.parm7 -x $NEW.nc -c $OLD.rst7 -r $NEW.rst7 -ref $REF.rst7 -inf $NEW.info
    else
      $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO.parm7 -x $NEW.nc -c $OLD.rst7 -r $NEW.rst7 -inf $NEW.info
    fi
    touch "${NEW}_successful.tmp"
    echo "Done ${NEW}"
  fi
}


#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ruta de la carpeta de trabajo. Es SCRIPT_PATH / WD_PATH
WDPATH=($(realpath $WD_PATH))

# Receptores analizados
RECEPTOR_PDB=($(ls ${WDPATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

CUDA_EXE=${AMBERHOME}/bin/pmemd.cuda

echo
echo "###########################"
echo "# Receptor is ${RECEPTOR} #"
echo "###########################"

for rep in $(seq $REPLICAS_START $REPLICAS_END) # Repetitions
  do
    echo "#########################"
    echo "# Doing replica ${rep} !#"
    echo "#########################"
    echo 

    if [[ $EQUI -eq 1 ]]
      then

      echo "##########################"
      echo "# Starting equilibration #"
      echo "##########################"

      EQUI_protocol=("min_ntr_h" "min_ntr_l" "md_nvt_ntr" "md_npt_ntr" "npt_equil_1" "npt_equil_2" "npt_equil_3" "npt_equil_4" "npt_equil_5" "npt_equil_6")

      if [[ $ONLY_PROTEIN_MD -eq 1 ]]
        then

          echo 
          echo " # Protein-only! #"
          echo 

          # Topology and coord file
          CRD=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/topo/${RECEPTOR}_solv
          TOPO=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/topo/${RECEPTOR}_solv
          EQUI_PATH=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/rep${rep}/equi/

          cd $EQUI_PATH

          OLD=$CRD
          RESTRAINED=1

          for STEP in "${EQUI_protocol[@]}"
            do
              if [[ "$STEP" == "npt_equil_1" ]] #change directory
              then
                cd $EQUI_PATH/npt 
                OLD="../${OLD}"             
              fi
              if [[ "$STEP" == "npt_equil_6" ]]
              then
                RESTRAINED=0
              fi
              NEW=$STEP
              run_MD $OLD $NEW $TOPO $CRD $RESTRAINED
              OLD=$NEW
            done
      fi
      
      if [[ $PROT_LIG_MD -eq 1 ]]
        then

          echo 
          echo " # Protein-Ligand! #"
          echo 

          LIGANDS_MOL2=("${WDPATH}/ligands/"*.mol2)
          LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))
          
          for LIG in "${LIGANDS[@]}"
            do

            LIG=$(basename "${LIG}")
            echo "  Doing for ${LIG}"

            # Topology and coord file
            CRD=${WDPATH}/MD/${RECEPTOR}/proteinLigandMD/${LIG}/topo/${LIG}_solv_com
            TOPO=${WDPATH}/MD/${RECEPTOR}/proteinLigandMD/${LIG}/topo/${LIG}_solv_com
            EQUI_PATH=${WDPATH}/MD/${RECEPTOR}/proteinLigandMD/${LIG}/setupMD/rep${rep}/equi/     

            OLD=$CRD

            cd $EQUI_PATH

            for STEP in ${EQUI_protocol[@]}
              do
                if [[ "$STEP" == "npt_equil_1" ]] #change directory
                then
                  cd $EQUI_PATH/npt     
                  OLD="../${OLD}" 
                fi

                if [[ "$STEP" == "npt_equil_6" ]]
                then
                  RESTRAINED=0
                else
                  RESTRAINED=1
                fi               
                NEW=$STEP
                run_MD $OLD $NEW $TOPO $CRD $RESTRAINED
                OLD=$NEW
              done
            done
      fi

    fi

    if [[ $PROD -eq 1 ]]
    then

      echo "##########################"
      echo "# Starting production    #"
      echo "##########################"

      if [[ $ONLY_PROTEIN_MD -eq 1 ]]
        then
          
          echo 
          echo " # Protein-only! #"
          echo 
          
          # Topology and coord file
          TOPO=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/topo/${RECEPTOR}_solv
          PROD_PATH=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/rep${rep}/prod/npt
          OLD=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/rep${rep}/equi/npt/npt_equil_6

          cd $PROD_PATH
          run_MD $OLD md_prod $TOPO "" 0

      fi
      
      if [[ $PROT_LIG_MD -eq 1 ]]
        then
          
          echo 
          echo " # Protein-Ligand! #"
          echo

          declare -a LIGANDS_MOL2=($(ls ${WDPATH}/ligands/))
          declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))
      
          for LIG in "${LIGANDS[@]}"
          do
            # Topology and coord file
            TOPO=${WDPATH}/MD/${RECEPTOR}/proteinLigandMD/${LIG}/topo/${LIG}_solv_com
            PROD_PATH=${WDPATH}/MD/${RECEPTOR}/proteinLigandMD/${LIG}/setupMD/rep${rep}/prod/npt
            OLD=${WDPATH}/MD/${RECEPTOR}/proteinLigandMD/${LIG}/setupMD/rep${rep}/equi/npt/npt_equil_6

            cd $PROD_PATH
            run_MD $OLD md_prod $TOPO "" 0

          done
      fi
    fi
  done
