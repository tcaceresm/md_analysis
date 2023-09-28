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
         WDPATH=$OPTARG;;
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

#### CHANGE THIS VARIABLES #####

# Ligandos analizados
declare -a LIGANDS=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" ) 
COFACTOR="ihp"

#Ruta de la carpeta del script (donde se encuentra este script)
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LEAP_SCRIPT_1="leap_script_1.in"
LEAP_SCRIPT_2="leap_script_2.in"
##############################
echo $WDPATH
echo "Checking existence of MD folder"
if test -e "${WDPATH}/MD"
    then
        echo "${WDPATH}/MD/ exist"
        echo "CONTINUE"
    else
        echo "${WDPATH}/MD/ do not exist"
        echo "Creating MD folder at ${WDPATH}"
        mkdir -p "${WDPATH}/MD/cofactor_lib"
        echo "DONE"
    fi 

for LIG in "${LIGANDS[@]}"
    do
    
    echo "Checking existence of MD/${LIG} folder"
    
    if test -e ${WDPATH}/MD/${LIG} 
    then
        echo "${WDPATH}/MD/${LIG} exist"
        echo "CONTINUE"
    else
     	echo "${WDPATH}/MD/${LIG} do not exist"
       	echo "Creating directiores at ${WDPATH}/MD for ${LIG}"
        mkdir -p ${WDPATH}/MD/${LIG}/{lib,topo,setupMD/{rep1/{equi,prod},rep2/{equi,prod},rep3/{equi,prod},rep4/{equi,prod},rep5/{equi,prod}}}
       	echo "DONE"
    fi   	
    
    TOPO="${WDPATH}/MD/${LIG}/topo/"
    
   # mkdir -p ${WDPATH}/MD/{cofactor_lib,${LIG}/{lib,topo,setupMD/{rep1/{equi,prod},rep2/{equi,prod},rep3/{equi,prod},rep4/{equi,prod},rep5/{equi,prod}}}}

    TOPO=${WDPATH}/MD/${LIG}/topo
    LIGAND_LIB=${WDPATH}/MD/${LIG}/lib
    COFACTOR_LIB=${WDPATH}/MD/cofactor_lib

    echo "Copying files to $TOPO"  
    echo "Copying ${LEAP_SCRIPT_1} and ${LEAP_SCRIPT_2} to $TOPO"
    cp $SCRIPT_PATH/input_files/topo/${LEAP_SCRIPT_1} $TOPO #TODO: check if file exists
    cp $SCRIPT_PATH/input_files/topo/${LEAP_SCRIPT_2} $TOPO # same as above

    sed -i "s/LIGND/${LIG}/g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2}
    sed -i "s+TOPO_PATH+${TOPO}+g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2}
    sed -i "s+COFACTOR_LIB_PATH+${COFACTOR_LIB}+g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2}
    sed -i "s/COF/${COFACTOR}/g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2}
    sed -i "s+LIGAND_LIB_PATH+${LIGAND_LIB}+g" ${TOPO}/${LEAP_SCRIPT_1} ${TOPO}/${LEAP_SCRIPT_2}

   #This is to obtain total atom from parmtop file
   #TOTAL_ATOM=$(cat ${WDPATH}/MD_am1/${LIG}1/cryst/${LIG}1_solv_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') #por si se usan trajectorias solvatadas para la extraccion
#   TOTAL_ATOM=$(cat ${TOPO}/${LIG}1_vac_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') # Atomos totales del complejo
   
   #LAST_ATOM_REC=$(cat ${WDPATH}/MD_am1/${LIG}1/cryst/${LIG}1_vac_rec.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') # last atom del receptor #por si se usan trajectorias solvatadas para la extraccion
#   LAST_ATOM_REC=$(cat ${TOPO}/${LIG}1_vac_rec.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}') # last atom del receptor   
   
#   FIRST_ATOM_LIG=$(($LAST_ATOM_REC + 1))
#   LAST_ATOM_LIG=$TOTAL_ATOM
   
   
   done
echo "DONE!"
