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
while getopts ":hd:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WDPATH=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

WDPATH=($(realpath $WDPATH))

RECEPTOR_PDB=($(ls ${WDPATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))
# Input para LEaP

LEAP_SCRIPT_1="leap_topo_rec_vac.in"
LEAP_SCRIPT_2="leap_topo_rec_solv.in"

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
        echo "${WDPATH}/MD/ do not exists"
        echo "Creating MD folder at ${WDPATH}"
        echo "Creating receptor folders"
        mkdir -p "${WDPATH}/MD/${RECEPTOR}/receptor/"
        echo "DONE!
        "
    fi 

# Prepare receptor. 
echo "
####################################
Preparing receptor ${RECEPTOR}
####################################
"

RECEPTOR_PATH="$WDPATH/MD/${RECEPTOR}/receptor"
cp ${WDPATH}/receptor/$RECEPTOR_PDB $RECEPTOR_PATH
$AMBERHOME/bin/pdb4amber -i "$WDPATH/MD/$RECEPTOR/receptor/$RECEPTOR_PDB" -o "$WDPATH/MD/$RECEPTOR/receptor/${RECEPTOR}_prep.pdb" --add-missing-atoms --no-conect --nohyd --reduce > "${WDPATH}/MD/${RECEPTOR}/receptor/pdb4amber.log"

echo "Done preparing receptor: ${RECEPTOR}"

echo "Creating directories"
mkdir -p ${WDPATH}/MD/${LIG}/{topo,setupMD/{rep1/{equi,prod},rep2/{equi,prod},rep3/{equi,prod},rep4/{equi,prod},rep5/{equi,prod}}}
echo "Done creating directories"
   	
TOPO=${WDPATH}/MD/${RECEPTOR}/topo
echo "Copying files to $TOPO  
      Copying ${LEAP_SCRIPT_1}, ${LEAP_SCRIPT_2} to $TOPO
     "
    
cp $SCRIPT_PATH/input_files/topo/onlyProtein/${LEAP_SCRIPT_1} $TOPO #TODO: check if file exists
cp $SCRIPT_PATH/input_files/topo/onlyProtein/${LEAP_SCRIPT_2} $TOPO # same as above

echo "Done copying files to $TOPO"

sed -i "s+TOPO_PATH+${TOPO}+g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2} 

    for rep in 1 2 3 4 5
        do
        TOTALRES=$(cat ${TOPO}/${LIG}_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $5}') # last atom del receptor
        
        cp $SCRIPT_PATH/input_files/equi/*  $WDPATH/MD/$LIG/setupMD/rep$rep/equi/
        sed -i "s/TOTALRES/${TOTALRES}/g" $WDPATH/MD/$LIG/setupMD/rep$rep/equi/*
        
        cp $SCRIPT_PATH/input_files/prod/md_prod.in $WDPATH/MD/$LIG/setupMD/rep$rep/prod/
        
        done
     echo "Done copying files for MD
        "

echo "DONE!"
done

