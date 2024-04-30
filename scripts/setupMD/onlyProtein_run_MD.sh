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
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WD_PATH=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#echo "SCRIPT PATH $SCRIPT_PATH"

# Ruta de la carpeta de trabajo.
#WDPATH=${SCRIPT_PATH}/$WD_PATH
WDPATH=($(realpath $WD_PATH))
#echo $WDPATH

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

for rep in 1 # Repetitions
  do
  # Run Equilibration
    echo "
##############################
Starting Equilibration $RECEPTOR $rep
##############################
"   
    #Receptor folder may vary if you are running different receptor molecular dynamics.
    # Directory path /WDPATH/MD/${RECEPTOR_FOLDER}/setupMD/repX/equi/
    EQUI_PATH=${WDPATH}/MD/${RECEPTOR}/setupMD/rep${rep}/equi/
    
    cd $EQUI_PATH
    # We are now in /WDPATH/MD/${RECEPTOR_FOLDER}/setupMD/repX/equi/
    # ../../../ is WDPATH/MD/RECEPTOR/
    CRD="../../../topo/${RECEPTOR}_solv.crd"

    TOPO="../../../topo/${RECEPTOR}_solv.parm7"
        
    echo "Running equilibration for ${RECEPTOR} $rep" 
    OLD=$CRD
    NEW=min_ntr_h
    $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -inf $NEW.info

    OLD=${NEW}.rst7
    NEW=min_ntr_l
    $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -inf $NEW.info

    OLD=${NEW}.rst7
    NEW=md_nvt_ntr
    $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -x $NEW.nc -inf $NEW.info

    OLD=${NEW}.rst7
    NEW=md_npt_ntr
    $CUDA_EXE -O -i $NEW.in -o $NEW.out -p $TOPO -c $OLD -r $NEW.rst7 -ref $CRD -x ${NEW}.nc -inf $NEW.info

    OLD=${NEW}.rst7
    NEW=md_nvt_red_01
    $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info

    OLD=${NEW}.rst7
    NEW=md_nvt_red_02
    $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info

    OLD=${NEW}.rst7
    NEW=md_nvt_red_03
    $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info

    OLD=${NEW}.rst7
    NEW=md_nvt_red_04
    $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info

    OLD=${NEW}.rst7
    NEW=md_nvt_red_05
    $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -ref md_npt_ntr.rst7 -x ${NEW}.nc -inf $NEW.info

    OLD=${NEW}.rst7
    NEW=md_nvt_red_06
    $CUDA_EXE -O -i ${NEW}.in -o ${NEW}.out -p $TOPO -c $OLD -r ${NEW}.rst7 -x ${NEW}.nc -inf $NEW.info
          
    # Run Production

    echo "
##############################
Starting Production phase of ${RECEPTOR} rep${rep}
##############################
"
    PROD_PATH=${WDPATH}/MD/${RECEPTOR}/setupMD/rep${rep}/equi/
    cd $PROD_PATH
    $CUDA_EXE -O -i md_prod.in -o md_prod.out -p $TOPO -c ../equi/md_nvt_red_06.rst7 -x md_prod.nc -inf md_prod.info

    echo "
##############################
Done rep $rep for $RECEPTOR
##############################
"
done
