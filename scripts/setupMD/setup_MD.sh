#!/usr/bin/bash

set -euo pipefail

############################################################
# Help
############################################################
Help() {
    echo "Usage: bash setup_MD.sh [-h] [-d DIRECTORY] [-t TIME] [-n REPLICAS] [-r 0|1] [-c 0|1]"
    echo
    echo "This script sets up molecular dynamics simulations in the specified directory."
    echo "The specified directory must always have a folder named  \"receptor\" containing the receptor PDB \
and an optional \"ligands\" and \"cofactor\" folder containing MOL2 file of ligands and cofactor, respectively."
    echo "There are two ways of setup MD:"
    echo "   1) Setup a only-protein MD. See p flag below."
    echo "   2) Setup a Protein-Ligand MD. See z flag below."
    echo "Both ways are not mutually excluded. You can setup both at the same time."
    echo "Sometimes you want to debug topology preparation step by re-running this script.
In order to avoid reparameterizing your ligands/cofactors, you can set r|l|c flags to zero. See below."
    echo
    echo "Options:"
    echo "  -h               Show this help message and exit."
    echo "  -d DIRECTORY     Specify the directory for the simulation."
    echo "  -t TIME          Simulation time in nanoseconds (assuming a 2 fs timestep)."
    echo "  -n REPLICAS      Number of replicas to run in the simulation."
    echo "  -p 0|1           Protein-only MD."
    echo "  -z 0|1           Protein-Ligand MD."
    echo "  -r 0|1           Flag to indicate if the receptor should be prepared."
    echo "  -l 0|1           Flag to indicate if the ligands should be parameterized."
    echo "  -c 0|1           Flag to indicate if the cofactor should be parameterized."
    echo
    echo "Examples:"
    echo "  bash setup_MD.sh -d /path/to/dir -t 100 -n 5 -r 1 -c 0"
    echo "  bash setup_MD.sh -d /path/to/dir -t 50 -n 3 -r 1 -c 0 | tee -a log.txt"
    echo
}


###########################################################
# Options
###########################################################
while getopts ":hd:t:n:p:z:r:l:c:" option; do
    case $option in
        h)  # Print this help
            Help
            exit;;
        d)  # Enter the MD Directory
            WDPATH=$OPTARG;;
        t)  # Time in nanoseconds
            TIME=$OPTARG;;
        n)  # Replicas
            REPLICAS=$OPTARG;;
        p)  # Protein-Only MD
            ONLY_PROTEIN_MD=$OPTARG;;
        z)  # Protein-Ligand MD
            PROT_LIG_MD=$OPTARG;;
        r)  # Prepare receptor?
            PREP_REC=$OPTARG;;
        l)  # Prepare ligand?
            PREP_LIG=$OPTARG;;
        c)  # Prepare cofactor?
            PREP_COFACTOR=$OPTARG;;
        \?) # Invalid option
            echo "Error: Invalid option"
            exit;;
    esac
done

################################################################
# Display message                                              #
################################################################

function displayHello
{

    echo "
    "####################################"
    Welcome to SetupMD v0.0.0
    Author: Tomás Cáceres <caceres.tomas@uc.cl>
    Laboratory of Molecular Design <http://schuellerlab.org/>
    https://github.com/tcaceresm/md_analysis
    Powered by high fat food and procrastination
    "####################################"
    "
}


############################################################
# Crear directorios
############################################################
CreateOnlyProteinDirectories() {
    # Número de replicas
    local N=$1
    # Nombre del receptor
    local RECEPTOR=$2

    # Directorio donde crearemos repN/equi_prod/npt,nvt
    BASE_DIR=${WDPATH}/MD/${RECEPTOR}/onlyProteinMD/

    mkdir -p ${BASE_DIR}/topo

    # Subdirectorios dentro de cada réplica
    SUBDIRS=("mmpbsa_rescoring" "equi/npt" "equi/nvt" "prod/npt" "prod/nvt")

    for REP in $(seq 1 $N); do
        for SUBDIR in "${SUBDIRS[@]}"; do
            mkdir -p "${BASE_DIR}/rep${REP}/${SUBDIR}"
        done
    done
}

CreateProteinLigandDirectories() {
    # Número de replicas
    local N=$1
    # Nombre del ligando
    local LIG=$2
    # Nombre del receptor
    local RECEPTOR=$3

    # Directorio donde crearemos repN/equi_prod/npt,nvt
    BASE_DIR=${WDPATH}/MD/${RECEPTOR}
    # Subdirectorios dentro de cada réplica
    SUBDIRS=("mmpbsa_rescoring" "equi/npt" "equi/nvt" "prod/npt" "prod/nvt")

    mkdir -p ${BASE_DIR}/${LIG}/{lib,setupMD,topo}
    # Crear la estructura de directorios
    for REP in $(seq 1 $N); do
        for SUBDIR in "${SUBDIRS[@]}"; do
            mkdir -p "${BASE_DIR}/${LIG}/setupMD/rep${REP}/${SUBDIR}"
        done
    done
}

############################################################
# Preparar receptor
############################################################
PrepareReceptor() {
    local REC=$1
    echo "####################################"
    echo "# Preparing receptor: $REC         #"
    echo "####################################"
    
    local RECEPTOR_PDB_FILE="${WDPATH}/receptor/${REC}.pdb"
    local PREP_PDB_PATH="${WDPATH}/MD/$REC/receptor/"
    local PREP_PDB_FILE="${PREP_PDB_PATH}/${REC}_prep.pdb"

    mkdir -p ${PREP_PDB_PATH}

    cp ${RECEPTOR_PDB_FILE} ${PREP_PDB_PATH}/${REC}_original.pdb
    
    cd ${PREP_PDB_PATH}

    $AMBERHOME/bin/pdb4amber -i ${PREP_PDB_PATH}/${REC}_original.pdb -o ${PREP_PDB_FILE} -l prepare_receptor.log

    echo 
    echo "Done preparing receptor $REC"
    echo 
}

############################################################
# Preparar non-standard residue (ligand)
############################################################
PrepareLigand() {
    local LIG=$1
    local LIG_PATH=$2
    local LEAP_LIG=$3
    local LIGAND_LIB=$4
    local RESNAME=$5
        
    echo "####################################"
    echo "# Preparing ligand: $LIG           #"
    echo "####################################"

    cp "${SCRIPT_PATH}/input_files/topo/${LEAP_LIG}" ${LIGAND_LIB}
    cp ${LIG_PATH}/${LIG}.mol2 ${LIGAND_LIB}/${LIG}.mol2

    sed -i "s/LIGND/${LIG}/g" $LIGAND_LIB/$LEAP_LIG

    cd "$LIGAND_LIB"

    echo "Computing net charge from partial charges of mol2 file"
    LIGAND_NET_CHARGE=$(awk '/ATOM/{ f = 1; next } /BOND/{ f = 0 } f' "${LIG}.mol2" | awk '{sum += $9} END {printf "%.0f\n", sum}')
    echo "Net charge of ${LIG}.mol2: ${LIGAND_NET_CHARGE}" | tee -a ligand_net_charge.log

    $AMBERHOME/bin/antechamber -i "${LIGAND_LIB}/${LIG}.mol2" -fi mol2 -o "${LIGAND_LIB}/${LIG}.mol2" -fo mol2 -c bcc -nc "$LIGAND_NET_CHARGE" -at gaff2 -rn $RESNAME
    $AMBERHOME/bin/antechamber -i "${LIGAND_LIB}/${LIG}.mol2" -fi mol2 -o "${LIGAND_LIB}/${LIG}_lig.pdb" -fo pdb -dr n -nc $LIGAND_NET_CHARGE -at gaff2 -rn $RESNAME
    $AMBERHOME/bin/parmchk2 -i "${LIGAND_LIB}/${LIG}.mol2" -f mol2 -o "${LIGAND_LIB}/${LIG}.frcmod"
    $AMBERHOME/bin/tleap -f "${LIGAND_LIB}/${LEAP_LIG}" > prepare_ligand.log
    
    cd "$WDPATH"

    echo 
    echo "Done! preparing ligand"
    echo 
}


############################################################
# Preparar Topologias
############################################################
PrepareOnlyProteinTopology() {

    local REC=$1
    local LEAP_TOPO=$2
    local TOPO="${WDPATH}/MD/${REC}/onlyProteinMD/topo"

    echo "####################################"
    echo "# Preparing Topologies $REC        #"
    echo "####################################"

    cp "${SCRIPT_PATH}/input_files/topo/onlyProtein/${LEAP_TOPO}" ${TOPO}

    cd ${TOPO}

    if [[ $PREP_COFACTOR -eq 1 ]]
    then
        sed -i "s+COFACTOR+${COFACTOR_NAME}+g" ${LEAP_TOPO}
        sed -i "s+#++g" ${LEAP_TOPO}
    fi

    sed -i "s+RECEPTOR+${REC}+g" ${LEAP_TOPO}
  
    $AMBERHOME/bin/tleap -f ${LEAP_TOPO} > prepare_topologies.log

    echo "Done preparing $REC"
    echo
}

PrepareProteinLigandTopology() {

    local LIG=$1
    local REC=$2
    local LEAP_TOPO=$3
    local TOPO="${WDPATH}/MD/${REC}/${LIG}/topo"

    echo "####################################"
    echo "# Preparing Topologies $REC - $LIG #"
    echo "####################################"

    cp "${SCRIPT_PATH}/input_files/topo/${LEAP_TOPO}" ${TOPO}

    cd ${TOPO}

    if [[ $PREP_COFACTOR -eq 1 ]]
    then
        sed -i "s+COFACTOR+${COFACTOR_NAME}+g" ${LEAP_TOPO}
        sed -i "s+#++g" ${LEAP_TOPO}
    fi

    sed -i "s+LIGAND+${LIG}+g" ${LEAP_TOPO}
    sed -i "s+RECEPTOR+${REC}+g" ${LEAP_TOPO}
  
    $AMBERHOME/bin/tleap -f ${LEAP_TOPO} > prepare_topologies.log

    echo "Done preparing complex $REC $LIG "
    echo 
}

############################################################
# Preparar archivos de MD
############################################################
PrepareOnlyProteinMD() {
    local REC=$1
    local N=$2
    local TOPO="${WDPATH}/MD/${REC}/onlyProteinMD/topo"
    local MD_FOLDER="${WDPATH}/MD/${REC}/onlyProteinMD/"

    echo "####################################"
    echo "# Preparing Only Protein MD files  #"
    echo "####################################"

    TOTALRES=$(awk '/ATOM/ {print $5}' "${TOPO}/${REC}_rec.pdb" | tail -n 1)
    NSTEPS=$((500000 * $TIME))

    for rep in $(seq 1 $N); do 
        cp -r ${SCRIPT_PATH}/input_files/equi/* ${MD_FOLDER}/rep${rep}/equi/
        sed -i "s/TOTALRES/${TOTALRES}/g" ${MD_FOLDER}/rep${rep}/equi/*.in ${MD_FOLDER}/rep${rep}/equi/n*t/*.in 
        cp "${SCRIPT_PATH}/input_files/prod/md_prod.in" "${MD_FOLDER}/rep${rep}/prod/"
        sed -i "s/TIME/${NSTEPS}/g" "${MD_FOLDER}/rep${rep}/prod/md_prod.in"
    done

    echo "Done copying files for MD!"
    echo 
}

PrepareProteinLigandMD() {
    local LIG=$1
    local REC=$2
    local N=$3
    local TOPO="${WDPATH}/MD/${REC}/${LIG}/topo"
    local MD_FOLDER="${WDPATH}/MD/${REC}/${LIG}/setupMD/"

    echo "####################################"
    echo "# Preparing ProteinLigand MD files #"
    echo "####################################"

    TOTALRES=$(awk '/ATOM/ {print $5}' "${TOPO}/${LIG}_com.pdb" | tail -n 1)
    NSTEPS=$((500000 * $TIME))

    for rep in $(seq 1 $N); do 
        cp -r ${SCRIPT_PATH}/input_files/equi/* ${MD_FOLDER}/rep${rep}/equi/
        sed -i "s/TOTALRES/${TOTALRES}/g" ${MD_FOLDER}/rep${rep}/equi/*.in ${MD_FOLDER}/rep${rep}/equi/n*t/*.in 
        cp "${SCRIPT_PATH}/input_files/prod/md_prod.in" "${MD_FOLDER}/rep${rep}/prod/"
        sed -i "s/TIME/${NSTEPS}/g" "${MD_FOLDER}/rep${rep}/prod/md_prod.in"
    done

    echo "Done copying files for ProteinLigand MD"
    echo
}

############################################################
# Main script
############################################################


# Ruta de la carpeta del script (donde se encuentra este script y demás input files).
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ruta de la carpeta de trabajo.
# WD debe contener la carpeta del receptor, ligando y cofactor (opcional). 
WDPATH=$(realpath "$WDPATH")

# Receptor
RECEPTOR_PDB=($(ls "${WDPATH}/receptor/"))
RECEPTOR_NAME=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

ENSEMBLE="npt"

if [[ $PREP_REC -eq 1 ]]
then
    PrepareReceptor $RECEPTOR_NAME
fi

# Preparar cofactor
if [[ $PREP_COFACTOR -eq 1 ]]
then
    
    mkdir -p ${WDPATH}/MD/${RECEPTOR_NAME}/cofactor_lib
    COFACTOR_MOL2=($(ls "${WDPATH}/cofactor/"))
    COFACTOR_NAME=($(sed "s/.mol2//g" <<< "${COFACTOR_MOL2[*]}"))
    PrepareLigand $COFACTOR_NAME "${WDPATH}/cofactor" "leap_lib_cof.in" "${WDPATH}/MD/${RECEPTOR_NAME}/cofactor_lib" "COF"
else
    COFACTOR_NAME="a"

fi



if [[ $ONLY_PROTEIN_MD -eq 1 ]]
then
    echo "#############################"
    echo "# Preparing Only Protein MD #"
    echo "#############################"
    # Input para LEaP
    LEAP_SCRIPT="leap_create_rec.in"

    CreateOnlyProteinDirectories $REPLICAS $RECEPTOR_NAME
    PrepareOnlyProteinTopology $RECEPTOR_NAME $LEAP_SCRIPT
    PrepareOnlyProteinMD $RECEPTOR_NAME $REPLICAS
fi


# Preparar ligandos, complejos y archivos de MD
if [[ $PROT_LIG_MD -eq 1 ]]
then
    echo "####################################"
    echo "# Preparing Protein-Ligand MD      #"
    echo "####################################"
    # Ligandos
    LIGANDS_MOL2=($(ls "${WDPATH}/ligands/"))
    LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

    # Ligand leap input
    LEAP_LIGAND="leap_lib.in"
    # Leap input para topologias complejo proteina-ligando
    LEAP_TOPO="leap_create_com.in"

    for LIG in "${LIGANDS[@]}"
    do
        CreateProteinLigandDirectories $REPLICAS $LIG $RECEPTOR_NAME
        PrepareLigand $LIG "${WDPATH}/ligands" "leap_lib.in" "${WDPATH}/MD/${RECEPTOR_NAME}/${LIG}/lib" "LIG"
        PrepareProteinLigandTopology "$LIG" "$RECEPTOR_NAME" $LEAP_TOPO
        PrepareProteinLigandMD "$LIG" "$RECEPTOR_NAME" $REPLICAS
    done
fi

echo "DONE!"
