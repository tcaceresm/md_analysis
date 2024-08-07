#!/usr/bin/bash

set -euo pipefail

############################################################
# Help
############################################################
Help() {
    echo "Syntax: bash setup_MD.sh [-h|d]"
    echo "To save a log file and also print the status, run: bash setup_MD.sh -d \$DIRECTORY | tee -a \$LOGFILE"
    echo "Options:"
    echo "h     Print help"
    echo "d     Working Directory."
    echo "n     Replicas."
    echo
}

############################################################
# Crear directorios
############################################################
CreateDirectories() {
    # Número de replicas
    local N=$1
    # Nombre del ligando
    local LIG=$2
    # Nombre del receptor
    local RECEPTOR=$3

    mkdir -p ${WDPATH}/MD/${RECEPTOR}/{cofactor_lib,receptor,${LIG}/{lib,setupMD,topo}}
    
    # Crear la lista de replicas
    REPS=()
    for ((i=1; i<=N; i++)); do
        REPS+=("rep$i")
    done

    # Directorio donde crearemos repN/equi_prod/npt,nvt
    BASE_DIR=${WDPATH}/MD/${RECEPTOR}/${LIG}/setupMD
    # Subdirectorios dentro de cada replicación
    SUBDIRS=("equi/npt" "equi/nvt" "prod/npt" "prod/nvt")

    # Crear la estructura de directorios
    for REP in "${REPS[@]}"; do
        for SUBDIR in "${SUBDIRS[@]}"; do
            mkdir -p "${BASE_DIR}/${REP}/${SUBDIR}"
        done
    done
    

}

############################################################
# Preparar receptor
############################################################
PrepareReceptor() {
    local REC=$1
    echo "####################################"
    echo "Preparing receptor: $REC"
    echo "####################################"
    
    local RECEPTOR_PDB_FILE="${WDPATH}/receptor/${REC}.pdb"
    local RECEPTOR_PDB_FILE_PREPARED_LOCATION="${WDPATH}/MD/$REC/receptor/"
    local RECEPTOR_PDB_FILE_PREPARED="${RECEPTOR_PDB_FILE_PREPARED_LOCATION}/${REC}_prep.pdb"

    cp ${RECEPTOR_PDB_FILE} ${RECEPTOR_PDB_FILE_PREPARED_LOCATION}/${REC}_original.pdb
    
    cd ${RECEPTOR_PDB_FILE_PREPARED_LOCATION}

    $AMBERHOME/bin/pdb4amber -i ${RECEPTOR_PDB_FILE_PREPARED_LOCATION}/${REC}_original.pdb -o ${RECEPTOR_PDB_FILE_PREPARED}  -l prepare_receptor.log

    echo "Done preparing receptor $REC"

}

############################################################
# Preparar ligando
############################################################
PrepareLigand() {
    local REC=$1
    local LIG=$2
    local LEAP_TOPO=$3
    local LEAP_LIG=$4
    local LIGAND_LIB="${WDPATH}/MD/${REC}/${LIG}/lib"
    local RECEPTOR_PATH="${WDPATH}/MD/${REC}/receptor"
    local TOPO="${WDPATH}/MD/${REC}/${LIG}/topo"

    echo "####################################"
    echo "Preparing ligand: $LIG"
    echo "####################################"

    cp "${SCRIPT_PATH}/input_files/topo/${LEAP_TOPO}" ${TOPO}
    cp "${SCRIPT_PATH}/input_files/topo/${LEAP_LIG}" ${LIGAND_LIB}
    cp ${WDPATH}/ligands/${LIG}.mol2 ${LIGAND_LIB}/${LIG}.mol2

    sed -i "s/LIGND/${LIG}/g" ${TOPO}/${LEAP_TOPO} $LIGAND_LIB/$LEAP_LIG

    cd "$LIGAND_LIB"

    echo "Computing net charge from partial charges of mol2 file"
    LIGAND_NET_CHARGE=$(awk '/ATOM/{ f = 1; next } /BOND/{ f = 0 } f' "${LIG}.mol2" | awk '{sum += $9} END {printf "%.0f\n", sum}')
    echo "Net charge of ${LIG}.mol2: ${LIGAND_NET_CHARGE}" | tee -a ligand_net_charge.log

    $AMBERHOME/bin/antechamber -i "${LIGAND_LIB}/${LIG}.mol2" -fi mol2 -o "${LIGAND_LIB}/${LIG}.mol2" -fo mol2 -rn LIG -nc "$LIGAND_NET_CHARGE" -at gaff2 
    $AMBERHOME/bin/antechamber -i "${LIGAND_LIB}/${LIG}.mol2" -fi mol2 -o "${LIGAND_LIB}/${LIG}_lig.pdb" -fo pdb -dr n -rn LIG -at gaff2
    $AMBERHOME/bin/parmchk2 -i "${LIGAND_LIB}/${LIG}.mol2" -f mol2 -o "${LIGAND_LIB}/${LIG}.frcmod"
    $AMBERHOME/bin/tleap -f "${LIGAND_LIB}/${LEAP_LIGAND}" > prepare_ligand.log
    
    cd "$WDPATH"

    echo "Done preparing ligand"
}


############################################################
# Preparar Topologias
############################################################
PrepareTopology() {

    local LIG=$1
    local REC=$2
    local LEAP_TOPO=$3
    local TOPO="${WDPATH}/MD/${REC}/${LIG}/topo"

    echo "####################################"
    echo "Preparing Topologies $REC $LIG"
    echo "####################################"

    cp "${SCRIPT_PATH}/input_files/topo/${LEAP_TOPO}" ${TOPO}

    cd ${TOPO}

    sed -i "s+LIGAND+${LIG}+g" ${LEAP_TOPO}
    sed -i "s+RECEPTOR+${REC}+g" ${LEAP_TOPO}
  
    $AMBERHOME/bin/tleap -f ${LEAP_TOPO} > prepare_topologies.log

    echo "Done preparing complex $REC $LIG"
}

############################################################
# Preparar archivos de MD
############################################################
PrepareMD() {
    local LIG=$1
    local REC=$2
    local N=$3
    local TOPO="${WDPATH}/MD/${REC}/${LIG}/topo"
    local MD_FOLDER="${WDPATH}/MD/${REC}/${LIG}/setupMD/"

    echo "####################################"
    echo "Preparing MD files"
    echo "####################################"

    TOTALRES=$(awk '/ATOM/ {print $5}' "${TOPO}/${LIG}_com.pdb" | tail -n 1)

    for rep in $(seq 1 $N); do 
        cp -r ${SCRIPT_PATH}/input_files/equi/* ${MD_FOLDER}/rep${rep}/equi/
        sed -i "s/TOTALRES/${TOTALRES}/g" ${MD_FOLDER}/rep${rep}/equi/*.in ${MD_FOLDER}/rep${rep}/equi/n*t/*.in 
        cp "${SCRIPT_PATH}/input_files/prod/md_prod.in" "${MD_FOLDER}/rep${rep}/prod/"
    done
    echo "Done copying files for MD"
}

###########################################################
# Options
###########################################################
while getopts ":hd:n:" option; do
    case $option in
        h)  # Print this help
            Help
            exit;;
        d)  # Enter the MD Directory
            WDPATH=$OPTARG;;
        n)  # Replicas
            REPLICAS=$OPTARG;;
        \?) # Invalid option
            echo "Error: Invalid option"
            exit;;
    esac
done


############################################################
# Main script
############################################################


# Ruta de la carpeta del script (donde se encuentra este script y demás input files).
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ruta de la carpeta de trabajo.
# WD debe contener la carpeta del receptor, ligando y cofactor (opcional). 
WDPATH=$(realpath "$WDPATH")

# Ligandos analizados
LIGANDS_MOL2=($(ls "${WDPATH}/ligands/"))
LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

RECEPTOR_PDB=($(ls "${WDPATH}/receptor/"))
RECEPTOR_NAME=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

# Input para LEaP
LEAP_TOPO="leap_create_com.in"
LEAP_LIGAND="leap_lib.in"

ENSEMBLE="npt"


echo "##############################"
echo "Welcome to SetupMD v0.1.0"
echo "Author: Tomás Cáceres <caceres.tomas@uc.cl>"
echo "##############################"

# Preparar ligandos, complejos y archivos de MD
for LIG in "${LIGANDS[@]}"; do
    CreateDirectories $REPLICAS $LIG $RECEPTOR_NAME
    PrepareReceptor $RECEPTOR_NAME 
    PrepareLigand $RECEPTOR_NAME $LIG $LEAP_TOPO $LEAP_LIGAND
    PrepareTopology "$LIG" "$RECEPTOR_NAME" $LEAP_TOPO
    PrepareMD "$LIG" "$RECEPTOR_NAME" $REPLICAS
    
done

echo "DONE!"
