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

   echo "Syntax: copy_files.sh [-h|i|n|d]"
   echo "options:"
   echo "h     Print help"
   echo "d     Working Directory."
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hi:d:" option; do
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

# Ruta de la carpeta de trabajo. Es SCRIPT_PATH / WD_PATH
WDPATH=${SCRIPT_PATH}/$WD_PATH

# Ligandos analizados
declare -a LIGANDS_MOL2=($(ls ${SCRIPT_PATH}/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

CUDA_EXE=${AMBERHOME}/bin/pmemd.cuda

# Equi input

#declare -a EQUI_IN=("min_ntr_h" "min_ntr_l" "md_nvt_ntr" "md_npt_ntr"
#                    "md_nvt_red_01"  "md_nvt_red_02"  "md_nvt_red_03"  "md_nvt_red_04"  "md_nvt_red_05" "md_nvt_red_06"    
#                    )

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
Checking existence of MD folder
##############################
"
if test -e "${WDPATH}/MD"
    then
        echo "${WDPATH}/MD/ exists"
        echo "CONTINUE
        "
    else
        echo "${WDPATH}/MD/ do not exist
        "
        exit 1
    fi 
    

echo "
##############################
Starting MD simulations
##############################
"

for rep in 1 2 3 4 5 # Repetitions
do
    for LIG in "${LIGANDS[@]}" #Run equi and prod for each lig
    do
    
        echo "Checking existence of MD/${LIG} folder"
    
        if test -e ${WDPATH}/MD/${LIG} 
        then
            echo "${WDPATH}/MD/${LIG} exist"
            echo "CONTINUE
            "
        else
     	    echo "${WDPATH}/MD/${LIG} do not exist
     	    "
       	    exit 1
        fi   	
    
    
        
        # Run Equilibration
        echo "
##############################
Starting Equilibration $LIG $rep
##############################
"

        EQUI_PATH=${WDPATH}/MD/${LIG}/setupMD/rep${rep}/equi/
        cd $EQUI_PATH
        
        #CRD=${WDPATH}/MD/${LIG}/topo/${LIG}_solv_com.crd
        CRD="../../../topo/${LIG}_solv_com.crd"
        #TOPO=${WDPATH}/MD/${LIG}/topo/${LIG}_solv_com.parm7
        TOPO="../../../topo/${LIG}_solv_com.parm7"
        
        echo "Running equilibration for ${LIG} $rep" 
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
Starting Production $LIG $rep
##############################
"
        PROD_PATH=${WDPATH}/MD/${LIG}/setupMD/rep${rep}/equi/
        cd $PROD_PATH
        $CUDA_EXE -O -i md_prod.in -o md_prod.out -p $TOPO -c ../equi/md_nvt_red_06.rst7 -x md_prod.nc -inf md_prod.info

    done
        echo "
##############################
Done rep $rep for all ligands
##############################
"
done
