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

#Ruta de la carpeta del script (donde se encuentra este script y demás input files).
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ruta de la carpeta de trabajo: /path/to/MD.
# WD contiene también la carpeta del receptor, ligando y cofactor.
WDPATH=($(realpath $WDPATH))

# Ligandos analizados
declare -a LIGANDS_MOL2=($(ls ${WDPATH}/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

#COFACTOR_MOL2=($(ls ${WDPATH}/cofactor/))
#echo "COFACTOR mol2 $COFACTOR_MOL2"
#COFACTOR=($(sed "s/.mol2//g" <<< "${COFACTOR_MOL2[*]}"))
#echo "COFACTOR $COFACTOR"

RECEPTOR_PDB=($(ls ${WDPATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

# Input para LEaP
LEAP_SCRIPT_1="leap_topo_vac.in"
LEAP_SCRIPT_2="leap_topo_solv.in"
LEAP_SCRIPT="leap_create_com.in"
LEAP_LIGAND="leap_lib.in"

# Ensemble

ENSEMBLE="npt"

#echo "RECEPTOR $RECEPTOR"
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
Checking existence of ${RECEPTOR} folder located at MD folder inside working directory
##############################
"
RECEPTOR_MD=${WDPATH}/MD/${RECEPTOR}

if test -e "${RECEPTOR_MD}"
    then
        echo "${RECEPTOR_MD} exists"
        echo "CONTINUE
        "
    else
        echo "${RECEPTOR_MD} does not exist"
        echo "Creating MD/${RECEPTOR} folder at ${WDPATH}"
        echo "Creating cofactor_lib and receptor folders"
        mkdir -p ${RECEPTOR_MD}/{cofactor_lib,receptor}
        echo "DONE!
        "
    fi 


# Prepare receptor. 
echo "
####################################
Preparing receptor ${RECEPTOR}
####################################
"

RECEPTOR_PATH=${WDPATH}/MD/$RECEPTOR/receptor/

ln -s ${WDPATH}/receptor/$RECEPTOR_PDB ${RECEPTOR_PATH}/$RECEPTOR_PDB

$AMBERHOME/bin/pdb4amber -i ${RECEPTOR_PATH}/$RECEPTOR_PDB -o ${RECEPTOR_PATH}/${RECEPTOR}_prep.pdb --add-missing-atoms --no-conect > "${RECEPTOR_PATH}/pdb4amber.log"

echo "Done preparing receptor ${RECEPTOR}"

# Prepare cofactor. 

if test -e "${WDPATH}/cofactor"
  then
    echo "
    ####################################
    Preparing cofactor ${COFACTOR_MOL2}
    ####################################
    "

    COFACTOR_LIB=${WDPATH}/MD/cofactor_lib

    cp ${SCRIPT_PATH}/cofactor/$COFACTOR_MOL2 $COFACTOR_LIB
    cp ${SCRIPT_PATH}/input_files/topo/leap_liGAND.in $COFACTOR_LIB
    sed -i "s/LIGND/${COFACTOR}/g" $COFACTOR_LIB/leap_liGAND.in
    sed -i "s/LIG/${COFACTOR}/g" $COFACTOR_LIB/leap_liGAND.in

    cd $COFACTOR_LIB 

    echo "Computing net charge from partial charges of mol2 file"
    COFACTOR_NET_CHARGE=$(awk '/ATOM/{ f = 1; next } /BOND/{ f = 0 } f' $COFACTOR_MOL2 | awk '{sum += $9} END {printf "%.0f\n", sum}')
    echo "Net charge of ${COFACTOR_MOL2}: ${COFACTOR_NET_CHARGE}"

    $AMBERHOME/bin/antechamber -i ${COFACTOR_MOL2} -fi mol2 -o ${COFACTOR_MOL2} -fo mol2 -c bcc -nc $COFACTOR_NET_CHARGE -rn $COFACTOR
    $AMBERHOME/bin/parmchk2 -i $COFACTOR_MOL2 -f mol2 -o "${COFACTOR}.frcmod"
    $AMBERHOME/bin/tleap -f ${COFACTOR_LIB}/${LEAP_LIGAND}

    cd ${WDPATH}

    echo "Done preparing cofactor"
fi    

for LIG in "${LIGANDS[@]}" #Create folders and copy input files and mol2
  do
    echo "
    ####################################
    Preparing ligand ${LIG}
    ####################################
    "
    echo "Checking existence of MD/${LIG} folder"
    
    if test -e ${RECEPTOR_MD}/${LIG} 
      then
        echo "${RECEPTOR_MD}/${LIG} exist"
        echo "CONTINUE
        "
      else
        echo "${RECEPTOR_MD}/${LIG} do not exist"
        echo "Creating directiores at ${RECEPTOR_MD} for ${LIG}"
        mkdir -p ${RECEPTOR_MD}/${LIG}/{lib,topo,setupMD/{rep1/{equi/{nvt,npt},prod/{nvt,npt}},rep2/{equi/{nvt,npt},prod/{nvt,npt}},rep3/{equi/{nvt,npt},prod/{nvt,npt}},rep4/{equi/{nvt,npt},prod/{nvt,npt}},rep5/{equi/{nvt,npt},prod/{nvt,npt}}}}

        echo "DONE
         "
    fi   	
    
    #TOPO is topology folder of ligand 
    TOPO=${RECEPTOR_MD}/${LIG}/topo
    #LIGAND_LIB is library folder of ligand
    LIGAND_LIB=${RECEPTOR_MD}/${LIG}/lib

    echo "Copying files to $TOPO  
    Copying ${LEAP_SCRIPT_1}, ${LEAP_SCRIPT_2} to $TOPO
    Copying ${LEAP_LIGAND} to ${LIGAND_LIB}"
    

    cp ${SCRIPT_PATH}/input_files/topo/${LEAP_SCRIPT} $TOPO
    cp ${SCRIPT_PATH}/input_files/topo/${LEAP_LIGAND} $LIGAND_LIB 
    cp ${WDPATH}/ligands/${LIG}.mol2 $LIGAND_LIB # copy ligand.mol2 to lib folder

    sed -i "s/LIGND/${LIG}/g" ${TOPO}/${LEAP_SCRIPT_1} $TOPO/$LEAP_SCRIPT_2 ${TOPO}/${LEAP_SCRIPT} $LIGAND_LIB/$LEAP_LIGAND
    sed -i "s+TOPO_PATH+${TOPO}+g" ${TOPO}/${LEAP_SCRIPT}
    #sed -i "s+COFACTOR_LIB_PATH+${COFACTOR_LIB}+g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2} ${TOPO}/${LEAP_SCRIPT}
    #sed -i "s/COF/${COFACTOR}/g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2} ${TOPO}/${LEAP_SCRIPT}
    sed -i "s+LIGAND_LIB_PATH+${LIGAND_LIB}+g" ${TOPO}/${LEAP_SCRIPT}
    sed -i "s+REC_PATH+${RECEPTOR_PATH}+g" ${TOPO}/${LEAP_SCRIPT}
    sed -i "s/RECEPTOR/${RECEPTOR}/g" ${TOPO}/${LEAP_SCRIPT} 

    cd $LIGAND_LIB
    
    echo "Computing net charge from partial charges of mol2 file"
    LIGAND_NET_CHARGE=$(awk '/ATOM/{ f = 1; next } /BOND/{ f = 0 } f' ${LIG}.mol2 | awk '{sum += $9} END {printf "%.0f\n", sum}')
    echo "Net charge of ${LIG}.mol2: ${LIGAND_NET_CHARGE}"


    $AMBERHOME/bin/antechamber -i $LIGAND_LIB/$LIG.mol2 -fi mol2 -o $LIGAND_LIB/$LIG.mol2 -fo mol2 -rn LIG -nc $LIGAND_NET_CHARGE -at gaff2
    $AMBERHOME/bin/antechamber -i $LIGAND_LIB/$LIG.mol2 -fi mol2 -o $LIGAND_LIB/${LIG}_lig.pdb -fo pdb -dr n -rn LIG
    $AMBERHOME/bin/parmchk2 -i $LIGAND_LIB/$LIG.mol2 -f mol2 -o "$LIGAND_LIB/$LIG.frcmod"
    $AMBERHOME/bin/tleap -f $LIGAND_LIB/$LEAP_LIGAND
    cd ${WDPATH}
    
    echo "
    Done preparing ligand
    "

    echo "    
    ####################################
    Preparing Complex $RECEPTOR $LIG
    ####################################
    "
    $AMBERHOME/bin/tleap -f $TOPO/${LEAP_SCRIPT} 

    echo "
    Done preparing complex $RECEPTOR $LIG
    " 
    echo "    
    ####################################
    Preparing MD files
    ####################################
    "
    for rep in 1 2 3 4 5
      do
        TOTALRES=$(cat ${TOPO}/${LIG}_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $5}') # last atom del receptor
        
        cp -r ${SCRIPT_PATH}/input_files/equi/*  $WDPATH/MD/$RECEPTOR/$LIG/setupMD/rep$rep/equi/
        sed -i "s/TOTALRES/${TOTALRES}/g" $WDPATH/MD/$RECEPTOR/$LIG/setupMD/rep$rep/equi/*.in $WDPATH/MD/$RECEPTOR/$LIG/setupMD/rep$rep/equi/npt/*.in $WDPATH/MD/$RECEPTOR/$LIG/setupMD/rep$rep/equi/nvt/*.in
        
        cp ${SCRIPT_PATH}/input_files/prod/md_prod.in $WDPATH/MD/$RECEPTOR/$LIG/setupMD/rep$rep/prod/
        
        done
      echo "Done copying files for MD
        "

echo "DONE!"
done

