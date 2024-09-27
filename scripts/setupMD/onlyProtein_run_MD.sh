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
   echo "e     Run equilibration."
   echo "p     Run production."
   echo "n     Replicas."
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:e:p:n:" option; do
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

#####
# This script will check if restart file exists. That means is not necessary to start over
# In case you want to start over, first remove all restart files (*.rst7)
#####

#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ruta de la carpeta de trabajo.
WDPATH=($(realpath $WD_PATH))

# Archivo de receptor
RECEPTOR_PDB=($(ls ${WDPATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

# CUDA ejecutable
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
    #Run Equilibration
    if [[ $EQUI -eq 1 ]]
      then 
      echo "
      ##############################
      Starting Equilibration $RECEPTOR $rep
      ##############################
      "   
      # Topology and coord file
      CRD=${WDPATH}/MD/${RECEPTOR}/topo/${RECEPTOR}_solv.crd
      TOPO=${WDPATH}/MD/${RECEPTOR}/topo/${RECEPTOR}_solv.parm7

      #Receptor folder may vary if you are running different receptor molecular dynamics.
      # Directory path /WDPATH/MD/${RECEPTOR_FOLDER}/setupMD/repX/equi/
      EQUI_PATH=${WDPATH}/MD/${RECEPTOR}/setupMD/rep${rep}/equi/
      
      cd $EQUI_PATH

      echo "Running equilibration for ${RECEPTOR} $rep" 
      OLD=$CRD
      NEW=min_ntr_h
      if [[ ! -f $NEW.rst7 ]]
      then
         $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -x $NEW.nc -inf $NEW.info
      fi

      OLD=${NEW}.rst7
      NEW=min_ntr_l
      if [[ ! -f $NEW.rst7 ]]
      then      
         $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -x $NEW.nc -inf $NEW.info
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
         PROD_PATH=${WDPATH}/MD/${RECEPTOR}/setupMD/rep${rep}/prod/
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
