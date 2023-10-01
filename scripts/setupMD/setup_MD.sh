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
#echo "LIGANDS ${LIGANDS[*]}"

COFACTOR_MOL2=($(ls ${SCRIPT_PATH}/cofactor/))
#echo "COFACTOR mol2 $COFACTOR_MOL2"
COFACTOR=($(sed "s/.mol2//g" <<< "${COFACTOR_MOL2[*]}"))
#echo "COFACTOR $COFACTOR"

RECEPTOR_PDB=($(ls ${SCRIPT_PATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))
# Input para LEaP
LEAP_SCRIPT_1="leap_topo_vac.in"
LEAP_SCRIPT_2="leap_topo_solv.in"
LEAP_SCRIPT_3="leap_create_com.in"
LEAP_LIB="leap_lib.in"

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
        echo "Creating cofactor_lib and receptor folders"
        mkdir -p ${WDPATH}/MD/{cofactor_lib,receptor}
        echo "DONE!
        "
    fi 

# Prepare receptor. 
echo "
####################################
Preparing receptor ${RECEPTOR}
####################################
"
RECEPTOR_PATH=$WDPATH/MD/receptor/
cp $SCRIPT_PATH/receptor/$RECEPTOR_PDB $RECEPTOR_PATH
$AMBERHOME/bin/pdb4amber -i $WDPATH/MD/receptor/$RECEPTOR_PDB -o $WDPATH/MD/receptor/${RECEPTOR}_prep.pdb --add-missing-atoms --no-conect --nohyd --reduce

echo "Done"



# Prepare cofactor. 
echo "
####################################
Preparing cofactor ${COFACTOR_MOL2}
####################################
"

COFACTOR_LIB=${WDPATH}/MD/cofactor_lib

cp $SCRIPT_PATH/cofactor/$COFACTOR_MOL2 $COFACTOR_LIB
cp $SCRIPT_PATH/input_files/topo/leap_lib.in $COFACTOR_LIB
sed -i "s/LIGND/${COFACTOR}/g" $COFACTOR_LIB/leap_lib.in
sed -i "s/LIG/${COFACTOR}/g" $COFACTOR_LIB/leap_lib.in

cd $COFACTOR_LIB 

echo "Computing net charge from partial charges of mol2 file"
COFACTOR_NET_CHARGE=$(awk '/ATOM/{ f = 1; next } /BOND/{ f = 0 } f' $COFACTOR_MOL2 | awk '{sum += $9} END {printf "%.0f\n", sum}')
echo "Net charge of ${COFACTOR_MOL2}: ${COFACTOR_NET_CHARGE}"



$AMBERHOME/bin/antechamber -i ${COFACTOR_MOL2} -fi mol2 -o ${COFACTOR_MOL2} -fo mol2 -c bcc -nc $COFACTOR_NET_CHARGE -rn $COFACTOR
$AMBERHOME/bin/parmchk2 -i $COFACTOR_MOL2 -f mol2 -o "${COFACTOR}.frcmod"
$AMBERHOME/bin/tleap -f ${COFACTOR_LIB}/${LEAP_LIB}
 
cd $SCRIPT_PATH
   
echo "Done preparing cofactor"
    



for LIG in "${LIGANDS[@]}" #Create folders and copy input files and mol2
    do
    
    echo "Checking existence of MD/${LIG} folder"
    
    if test -e ${WDPATH}/MD/${LIG} 
    then
        echo "${WDPATH}/MD/${LIG} exist"
        echo "CONTINUE
        "
    else
     	echo "${WDPATH}/MD/${LIG} do not exist"
       	echo "Creating directiores at ${WDPATH}/MD for ${LIG}"
        mkdir -p ${WDPATH}/MD/${LIG}/{lib,topo,setupMD/{rep1/{equi,prod},rep2/{equi,prod},rep3/{equi,prod},rep4/{equi,prod},rep5/{equi,prod}}}
       	echo "DONE
       	"
    fi   	
    
      
    TOPO=${WDPATH}/MD/${LIG}/topo
    LIGAND_LIB=${WDPATH}/MD/${LIG}/lib

    echo "Copying files to $TOPO  
  Copying ${LEAP_SCRIPT_1}, ${LEAP_SCRIPT_2} to $TOPO
  Copying ${LEAP_LIB} to ${LIGAND_LIB}"
    
    cp $SCRIPT_PATH/input_files/topo/${LEAP_SCRIPT_1} $TOPO #TODO: check if file exists
    cp $SCRIPT_PATH/input_files/topo/${LEAP_SCRIPT_2} $TOPO # same as above
    cp $SCRIPT_PATH/input_files/topo/${LEAP_SCRIPT_3} $TOPO
    cp $SCRIPT_PATH/input_files/topo/${LEAP_LIB} $LIGAND_LIB 
    cp $SCRIPT_PATH/ligands/${LIG}.mol2 $LIGAND_LIB # copy ligand.mol2 to lib folder

    sed -i "s/LIGND/${LIG}/g" ${TOPO}/${LEAP_SCRIPT_1} $TOPO/$LEAP_SCRIPT_2 ${TOPO}/${LEAP_SCRIPT_3} $LIGAND_LIB/$LEAP_LIB
    sed -i "s+TOPO_PATH+${TOPO}+g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2} ${TOPO}/${LEAP_SCRIPT_3}
    sed -i "s+COFACTOR_LIB_PATH+${COFACTOR_LIB}+g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2} ${TOPO}/${LEAP_SCRIPT_3}
    sed -i "s/COF/${COFACTOR}/g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2} ${TOPO}/${LEAP_SCRIPT_3}
    sed -i "s+LIGAND_LIB_PATH+${LIGAND_LIB}+g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2} ${TOPO}/${LEAP_SCRIPT_3}
    sed -i "s+REC_PATH+${RECEPTOR_PATH}+g" ${TOPO}/${LEAP_SCRIPT_3}
    sed -i "s/RECEPTOR/${RECEPTOR}/g" ${TOPO}/${LEAP_SCRIPT_3} 
echo "
####################################
Preparing ligand ${LIG}
####################################
"
    cd $LIGAND_LIB
    $AMBERHOME/bin/antechamber -i $LIGAND_LIB/$LIG.mol2 -fi mol2 -o $LIGAND_LIB/$LIG.mol2 -fo mol2 -c bcc -rn LIG
    $AMBERHOME/bin/antechamber -i $LIGAND_LIB/$LIG.mol2 -fi mol2 -o $LIGAND_LIB/${LIG}_lig.pdb -fo pdb -dr n -rn LIG
    $AMBERHOME/bin/parmchk2 -i $LIGAND_LIB/$LIG.mol2 -f mol2 -o "$LIGAND_LIB/$LIG.frcmod"
    $AMBERHOME/bin/tleap -f $LIGAND_LIB/$LEAP_LIB
    cd $SCRIPT_PATH
    
echo "
Done preparing ligand
"

echo "    
####################################
Preparing Complex $RECEPTOR $LIG
####################################
"
     $AMBERHOME/bin/tleap -f $TOPO/${LEAP_SCRIPT_3} # Obtain complex.pdb
#    $AMBERHOME/bin/tleap -f $TOPO/${LEAP_SCRIPT_1} # Obtain vacuum
#    $AMBERHOME/bin/tleap -f $TOPO/${LEAP_SCRIPT_2} # solvated

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
        
        cp $SCRIPT_PATH/input_files/equi/*  $WDPATH/MD/$LIG/setupMD/rep$rep/equi/
        sed -i "s/RES_TOTAL/${TOTALRES}/g" $WDPATH/MD/$LIG/setupMD/rep$rep/equi/*
        
        cp $SCRIPT_PATH/input_files/prod/md_prod.in $WDPATH/MD/$LIG/setupMD/rep$rep/prod/
        
        done
     echo "Done copying files for MD
        "

echo "DONE!"
done

