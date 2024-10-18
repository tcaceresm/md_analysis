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

   echo "Usage: bash run_MD.sh -d \$DIRECTORY "
   echo "options:"
   echo "h     Print this help"
   echo "d     Working Directory."
   echo "n     Replicas"
   echo "p     Run Protein-only MD."
   echo "z     Run Protein-Ligand MD."
   echo "e     Run equilibration."
   echo "x     Run production."
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:p:z:e:x:n:" option; do
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
         REPLICAS=$OPTARG;;
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
  local CRD=$4
  
  if [[ -f $NEW.rst7 ]]
  then
    echo "${NEW}.rst7 already exists. Skipping."
  else
    echo "Running ${NEW}"

    if [[ "$NEW" != "npt_equil_6" && "$NEW" != "md_prod" ]]
    then
      $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -inf $NEW.info
    else
      $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -inf $NEW.info
    fi
    echo "Done ${NEW}"
}


#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ruta de la carpeta de trabajo. Es SCRIPT_PATH / WD_PATH
WDPATH=($(realpath $WD_PATH))

# Receptores analizados
RECEPTOR_PDB=($(ls ${WDPATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

CUDA_EXE=${AMBERHOME}/bin/pmemd.cuda


echo "
##############################
Starting MD simulations
##############################
"

for rep in $(seq 1 $REPLICAS) # Repetitions
  do

    if [[ $EQUI -eq 1 ]]
      then

      EQUI_protocol= ("min_ntr_h" "min_ntr_l" "md_nvt_ntr" "md_npt_ntr" "npt_equil_1" "npt_equil_2" "npt_equil_3" "npt_equil_4" "npt_equil_5" "npt_equil_6")

      if [[ $ONLY_PROTEIN_MD -eq 1 ]]
        then
          # Topology and coord file
          CRD=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/topo/${RECEPTOR}_solv.crd
          TOPO=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/topo/${RECEPTOR}_solv.parm7
          EQUI_PATH=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/rep${rep}/equi/

          cd $EQUI_PATH

          for STEP in "${EQUI_protocol[@]}"
            do
              run_MD $CRD $STEP $TOPO $CRD
            done
      fi
      
      if [[ $PROT_LIG_MD -eq 1 ]]
        then
          # Topology and coord file
          CRD=${WDPATH}/MD/${RECEPTOR}/${LIG}/topo/${LIG}_solv.crd
          TOPO=${WDPATH}/MD/${RECEPTOR}/${LIG}/topo/${LIG}_solv.parm7
          EQUI_PATH=${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD/rep${rep}/equi/

          declare -a LIGANDS_MOL2=($(ls ${WDPATH}/ligands/))
          declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

          for LIG in "${LIGANDS[@]}"
            do
            
            for STEP in ${EQUI_protocol[@]}
              do
                run_MD $CRD $STEP $TOPO $CRD
              done
            done
      fi

    fi

    if [[ $PROD -eq 1 ]]
    then
      if [[ $ONLY_PROTEIN_MD -eq 1 ]]
        then
          # Topology and coord file
          CRD=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/topo/${RECEPTOR}_solv.crd
          TOPO=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/topo/${RECEPTOR}_solv.parm7
          PROD_PATH=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/rep${rep}/prod/

          cd $PROD_PATH

          run_MD $CRD md_prod $TOPO ""

      fi
      
      if [[ $PROT_LIG_MD -eq 1 ]]
        then
          # Topology and coord file
          CRD=${WDPATH}/MD/${RECEPTOR}/${LIG}/topo/${LIG}_solv.crd
          TOPO=${WDPATH}/MD/${RECEPTOR}/${LIG}/topo/${LIG}_solv.parm7
          EQUI_PATH=${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD/rep${rep}/prod/

          declare -a LIGANDS_MOL2=($(ls ${WDPATH}/ligands/))
          declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

          for LIG in "${LIGANDS[@]}"
            do
            run_MD $CRD $STEP $TOPO $CRD
            done
      fi
    fi
  done

  #   if [[ $PROT_LIG_MD -eq 1 ]]
  #     then

  #     # Ligandos analizados
  #     declare -a LIGANDS_MOL2=($(ls ${WDPATH}/ligands/))
  #     declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

  #     for LIG in "${LIGANDS[@]}" #Run equi and prod for each lig
  #       do
  #         #Run Equilibration
  #         if [[ $EQUI -eq 1 ]]
  #           then 
  #           echo "
  #           ##############################
  #           Starting Equilibration $RECEPTOR $rep
  #           ##############################
  #           "   

  #           # Topology and coord file
  #           CRD=${WDPATH}/MD/${RECEPTOR}/${LIG}/topo/${LIG}_solv.crd
  #           TOPO=${WDPATH}/MD/${RECEPTOR}/${LIG}/topo/${LIG}_solv.parm7

  #           # Directory path /WDPATH/MD/${RECEPTOR_FOLDER}/setupMD/repX/equi/
  #           EQUI_PATH=${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD/rep${rep}/equi/
            
  #           cd $EQUI_PATH

  #           echo "Running equilibration for ${RECEPTOR} $rep" 
  #           OLD=$CRD
  #           NEW=min_ntr_h
  #           if [[ ! -f $NEW.rst7 ]]
  #           then
  #             $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -inf $NEW.info
  #           fi

  #           OLD=${NEW}.rst7
  #           NEW=min_ntr_l
  #           if [[ ! -f $NEW.rst7 ]]
  #           then      
  #             $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -inf $NEW.info
  #           fi

  #           OLD=${NEW}.rst7
  #           NEW=md_nvt_ntr
  #           if [[ ! -f $NEW.rst7 ]]
  #           then      
  #             $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -x $NEW.nc -inf $NEW.info
  #           fi

  #           OLD=${NEW}.rst7
  #           NEW=md_npt_ntr
  #           if [[ ! -f $NEW.rst7 ]]
  #           then      
  #             $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -x ${NEW}.nc -inf $NEW.info
  #           fi

  #           cd ${EQUI_PATH}/npt

  #           OLD=${NEW}.rst7
  #           NEW=npt_equil_1
  #           if [[ ! -f $NEW.rst7 ]]
  #           then      
  #             $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c ../$OLD -r ${NEW}.rst7 -ref ../md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info
  #           fi

  #           OLD=${NEW}.rst7
  #           NEW=npt_equil_2
  #           if [[ ! -f $NEW.rst7 ]]
  #           then      
  #             $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref ../md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info
  #           fi

  #           OLD=${NEW}.rst7
  #           NEW=npt_equil_3
  #           if [[ ! -f $NEW.rst7 ]]
  #           then      
  #             $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref ../md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info
  #           fi

  #           OLD=${NEW}.rst7
  #           NEW=npt_equil_4
  #           if [[ ! -f $NEW.rst7 ]]
  #           then      
  #             $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref ../md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info
  #           fi

  #           OLD=${NEW}.rst7
  #           NEW=npt_equil_5
  #           if [[ ! -f $NEW.rst7 ]]
  #           then      
  #             $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref ../md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info
  #           fi

  #           OLD=${NEW}.rst7
  #           NEW=npt_equil_6
  #           if [[ ! -f $NEW.rst7 ]]
  #           then      
  #             $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -x ${NEW}.nc -inf $NEW.info
  #           fi
  #       fi


  #       if [[ $PROD -eq 1 ]]
  #           then
  #             # Run Production

  #             echo "
  #             ##############################
  #             Starting Production phase of ${RECEPTOR} rep${rep}
  #             ##############################
  #             "
  #             PROD_PATH=${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD/rep${rep}/prod/
  #             cd $PROD_PATH

  #             if [[ ! -f md_prod.rst7 ]]
  #             then
  #                 $CUDA_EXE -O -i md_prod.in -o md_prod.out -p $TOPO -c ${EQUI_PATH}/npt/npt_equil_6.rst7 -r md_prod.rst7 -x md_prod.nc -inf md_prod.info
  #             else
  #                 echo "md_prod.rst7 already exist! If you want to start a new production (not a restart) please remove md_prod.rst7"

  #             fi
  #       fi
  #         echo "
  #         ##############################
  #         Done rep $rep for $RECEPTOR
  #         ##############################
  #         "
  #       done
  #         echo "
  #   ##############################
  #   Done rep $rep for all ligands
  #   ##############################
  #   "
  #     fi
  # done
