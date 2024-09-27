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

   echo "Syntax: bash run_MD.sh -d \$DIRECTORY "
   echo "options:"
   echo "h     Print this help"
   echo "d     Working Directory."
   echo "n     Replicas"
   echo "e     Run equilibration?."
   echo "p     Run production?."
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:e:o:n:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WD_PATH=$OPTARG;;
      e) # Run equilibration
         EQUI=$OPTARG;;
      p) # Run production
         PROD=$OPTARG;;
      n) # Replicas
         REPLICAS=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ruta de la carpeta de trabajo. Es SCRIPT_PATH / WD_PATH
WDPATH=($(realpath $WD_PATH))

# Ligandos analizados
declare -a LIGANDS_MOL2=($(ls ${WDPATH}/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

# Receptores analizados
RECEPTOR_PDB=($(ls ${WDPATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

CUDA_EXE=${AMBERHOME}/bin/pmemd.cuda

echo "
##############################
Welcome to SetupMD v0.0.0
Author: Tomás Cáceres <caceres.tomas@uc.cl>
Laboratory of Molecular Design <http://schuellerlab.org/>
https://github.com/tcaceresm/md_analysis
Powered by high fat food and procrastination
##############################
"

echo "
##############################
Starting MD simulations
##############################
"

for rep in $(seq 1 $REPLICAS) # Repetitions
  do
    for LIG in "${LIGANDS[@]}" #Run equi and prod for each lig
      do
        #Run Equilibration
        if [[ $EQUI -eq 1 ]]
          then 
          echo "
          ##############################
          Starting Equilibration $RECEPTOR $rep
          ##############################
          "   
          # Topology and coord file
          CRD=${WDPATH}/MD/${RECEPTOR}/${LIG}/topo/${LIG}_solv.crd
          TOPO=${WDPATH}/MD/${RECEPTOR}/${LIG}/topo/${LIG}_solv.parm7

          # Directory path /WDPATH/MD/${RECEPTOR_FOLDER}/setupMD/repX/equi/
          EQUI_PATH=${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD/rep${rep}/equi/
          
          cd $EQUI_PATH

          echo "Running equilibration for ${RECEPTOR} $rep" 
          OLD=$CRD
          NEW=min_ntr_h
          if [[ ! -f $NEW.rst7 ]]
          then
            $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -inf $NEW.info
          fi

          OLD=${NEW}.rst7
          NEW=min_ntr_l
          if [[ ! -f $NEW.rst7 ]]
          then      
            $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -inf $NEW.info
          fi

          OLD=${NEW}.rst7
          NEW=md_nvt_ntr
          if [[ ! -f $NEW.rst7 ]]
          then      
            $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -x $NEW.nc -inf $NEW.info
          fi

          OLD=${NEW}.rst7
          NEW=md_npt_ntr
          if [[ ! -f $NEW.rst7 ]]
          then      
            $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -x ${NEW}.nc -inf $NEW.info
          fi

          cd ${EQUI_PATH}/npt

          OLD=${NEW}.rst7
          NEW=npt_equil_1
          if [[ ! -f $NEW.rst7 ]]
          then      
            $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c ../$OLD -r ${NEW}.rst7 -ref ../md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info
          fi

          OLD=${NEW}.rst7
          NEW=npt_equil_2
          if [[ ! -f $NEW.rst7 ]]
          then      
            $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref ../md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info
          fi

          OLD=${NEW}.rst7
          NEW=npt_equil_3
          if [[ ! -f $NEW.rst7 ]]
          then      
            $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref ../md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info
          fi

          OLD=${NEW}.rst7
          NEW=npt_equil_4
          if [[ ! -f $NEW.rst7 ]]
          then      
            $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref ../md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info
          fi

          OLD=${NEW}.rst7
          NEW=npt_equil_5
          if [[ ! -f $NEW.rst7 ]]
          then      
            $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref ../md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info
          fi

          OLD=${NEW}.rst7
          NEW=npt_equil_6
          if [[ ! -f $NEW.rst7 ]]
          then      
            $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -x ${NEW}.nc -inf $NEW.info
          fi
      fi


      if [[ $PROD -eq 1 ]]
          then
            # Run Production

            echo "
            ##############################
            Starting Production phase of ${RECEPTOR} rep${rep}
            ##############################
            "
            PROD_PATH=${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD/rep${rep}/prod/
            cd $PROD_PATH

            if [[ ! -f md_prod.rst7 ]]
            then
                $CUDA_EXE -O -i md_prod.in -o md_prod.out -p $TOPO -c ${EQUI_PATH}/npt/npt_equil_6.rst7 -r md_prod.rst7 -x md_prod.nc -inf md_prod.info
            else
                echo "md_prod.rst7 already exist! If you want to start a new production (not a restart) please remove md_prod.rst7"

            fi
      fi
        echo "
        ##############################
        Done rep $rep for $RECEPTOR
        ##############################
        "
      done
        echo "
  ##############################
  Done rep $rep for all ligands
  ##############################
"
  done
