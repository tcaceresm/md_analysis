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
   echo "i     ID of protein structure."
   echo "n     Residue Number in structure complex."
   echo "d     Working Directory."
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hi:n:d:e:p:t:r:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      i) # Enter a folder ID.
         ID=$OPTARG;;
      n) # Enter the residue Number from PDB complex structure.
         N_RES=$OPTARG;;
      d) # Enter the MD Directory
         WD_PATH=$OPTARG;;
      e) # Equilibration processing
         equi=$OPTARG;;
      p) # Production processing
         prod=$OPTARG;;
      t) # Topology processing
         topo=$OPTARG;;
      r) # Compute RMSD
         rmsd=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "SCRIPT PATH $SCRIPT_PATH"

# Ruta de la carpeta de trabajo. Es SCRIPT_PATH / WD_PATH
WDPATH=${SCRIPT_PATH}/$WD_PATH

# Ligandos analizados
declare -a LIGANDS_MOL2=($(ls ${SCRIPT_PATH}/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))
echo "LIGANDS ${LIGANDS[*]}"

COFACTOR_MOL2=($(ls ${SCRIPT_PATH}/cofactor/))
echo "COFACTOR mol2 $COFACTOR_MOL2"
COFACTOR=($(sed "s/.mol2//g" <<< "${COFACTOR_MOL2[*]}"))
echo "COFACTOR $COFACTOR"

RECEPTOR=($(ls ${SCRIPT_PATH}/cofactor/))
# Input para LEaP
LEAP_SCRIPT_1="leap_script_1.in"
LEAP_SCRIPT_2="leap_script_2.in"
LEAP_LIB="leap_lib.in"

echo "
##############################
Welcome to SetupMD v0.0.0
Author: Tomás Cáceres <caceres.tomas@uc.cl>
Laboratory of Molecular Design
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
        mkdir -p "${WDPATH}/MD/cofactor_lib"
        echo "DONE!
        "
    fi 

COFACTOR_LIB=${WDPATH}/MD/cofactor_lib

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
    cp $SCRIPT_PATH/input_files/topo/${LEAP_LIB} $LIGAND_LIB 
    cp $SCRIPT_PATH/ligands/${LIG}.mol2 $LIGAND_LIB # copy ligand.mol2 to lib folder

    sed -i "s/LIGND/${LIG}/g" ${TOPO}/${LEAP_SCRIPT_1} $TOPO/$LEAP_SCRIPT_2 $LIGAND_LIB/$LEAP_LIB
    sed -i "s+TOPO_PATH+${TOPO}+g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2}
    sed -i "s+COFACTOR_LIB_PATH+${COFACTOR_LIB}+g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2}
    sed -i "s/COF/${COFACTOR}/g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2}
    sed -i "s+LIGAND_LIB_PATH+${LIGAND_LIB}+g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2}
    
    
    
done #Done with create directories

# Prepare cofactor. 
echo "
####################################
Preparing cofactor ${COFACTOR_MOL2}
####################################
"

cp $SCRIPT_PATH/cofactor/$COFACTOR_MOL2 $COFACTOR_LIB
cp $SCRIPT_PATH/input_files/topo/leap_lib.in $COFACTOR_LIB
sed -i "s/LIGND/${COFACTOR}/g" $COFACTOR_LIB/leap_lib.in

cd $COFACTOR_LIB 

echo "Computing net charge from partial charges of mol2 file"
COFACTOR_NET_CHARGE=$(awk '/ATOM/{ f = 1; next } /BOND/{ f = 0 } f' $COFACTOR_MOL2 | awk '{sum += $9} END {printf "%.0f\n", sum}')
echo "Net charge of ${COFACTOR_MOL2}: ${COFACTOR_NET_CHARGE}"



$AMBERHOME/bin/antechamber -i ${COFACTOR_MOL2} -fi mol2 -o ${COFACTOR_MOL2} -fo mol2 -c bcc -nc $COFACTOR_NET_CHARGE
$AMBERHOME/bin/parmchk2 -i $COFACTOR_MOL2 -f mol2 -o "${COFACTOR}.frcmod"
$AMBERHOME/bin/tleap -f ${COFACTOR_LIB}/${LEAP_LIB}
   
echo "Done preparing cofactor"
    
cd $SCRIPT_PATH

# Prepare receptor. 
echo "
####################################
Preparing receptor ${RECEPTOR}
####################################
"
# Prepare Ligands
for LIG in ${LIGANDS[@]}
do

echo "
####################################
Preparing ligand ${LIG}
####################################
"
    cd $LIGAND_LIB
    $AMBERHOME/bin/antechamber -i $LIGAND_LIB/$LIG.mol2 -fi mol2 -o $LIGAND_LIB/$LIG.mol2 -fo mol2 -c bcc
    $AMBERHOME/bin/parmchk2 -i $LIGAND_LIB/$LIG.mol2 -f mol2 -o "$LIGAND_LIB/$LIG.frcmod"
    $AMBERHOME/bin/tleap -f $LIGAND_LIB/$LEAP_LIB
    cd $SCRIPT_PATH
    
echo "
Done preparing ligand
"

echo "
####################################
Preparing Complex $LIG
####################################
"
done
    

   #This is to obtain total atom from parmtop file
   #TOTAL_ATOM=$(cat ${WDPATH}/MD_am1/${LIG}1/cryst/${LIG}1_solv_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') #por si se usan trajectorias solvatadas para la extraccion
#   TOTAL_ATOM=$(cat ${TOPO}/${LIG}1_vac_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') # Atomos totales del complejo
   
   #LAST_ATOM_REC=$(cat ${WDPATH}/MD_am1/${LIG}1/cryst/${LIG}1_vac_rec.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') # last atom del receptor #por si se usan trajectorias solvatadas para la extraccion
#   LAST_ATOM_REC=$(cat ${TOPO}/${LIG}1_vac_rec.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') # last atom del receptor   
   
#   FIRST_ATOM_LIG=$(($LAST_ATOM_REC + 1))
#   LAST_ATOM_LIG=$TOTAL_ATOM
   

echo "DONE!"
