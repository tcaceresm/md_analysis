#!/usr/bin/bash
set -e
set -u
set -o pipefail

############################################################
# Help
############################################################
Help() {
    echo "Syntax: bash setup_MD.sh [-h|d]"
    echo "To save a log file and also print the status, run: bash setup_MD.sh -d \$DIRECTORY | tee -a \$LOGFILE"
    echo "Options:"
    echo "h     Print help"
    echo "d     Working Directory."
    echo "t     Time in nanoseconds (asuming 2 fs timestep)."
    echo "n     Replicas."
    echo "r     Prepare receptor?"
    echo "c     Prepare cofactor?"
    echo
}

###########################################################
# Options
###########################################################
while getopts ":hd:t:n:r:c:" option; do
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
        r)  # Prepare receptor?
            PREP_REC=$OPTARG;;
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
##############################
Welcome to SetupMD v0.0.0
Author: Tomás Cáceres <caceres.tomas@uc.cl>
Laboratory of Molecular Design <http://schuellerlab.org/>
https://github.com/tcaceresm/md_analysis
Powered by high fat food and procrastination
THIS SCRIPT IS ONLY FOR RECEPTOR MOLECULAR DYNAMICS, NOT PROTEIN-LIGAND MD
##############################
"
}

############################################################
# Crear directorios
############################################################
CreateDirectories() {

    # Número de replicas
    local N=$1
    # Nombre del receptor
    local RECEPTOR=$2

    mkdir -p ${WDPATH}/MD/${RECEPTOR}/{cofactor_lib,receptor,setupMD,topo}
        
    # Crear la lista de replicas
    REPS=()
    for ((i=1; i<=N; i++)); do
        REPS+=("rep$i")
    done

    # Directorio donde crearemos repN/equi_prod/npt,nvt
    BASE_DIR=${WDPATH}/MD/${RECEPTOR}/setupMD
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
# Preparar Topologias
############################################################
PrepareTopology() {

    local REC=$1
    local LEAP_TOPO=$2
    local COFACTOR=$3   
    local TOPO="${WDPATH}/MD/${REC}/topo"

    echo "####################################"
    echo "Preparing Topologies $REC"
    echo "####################################"

    cp "${SCRIPT_PATH}/input_files/topo/onlyProtein/${LEAP_TOPO}" ${TOPO}

    cd ${TOPO}

    if [[ -n $COFACTOR ]]
    then
        sed -i "s+COFACTOR+${COFACTOR}+g" ${LEAP_TOPO}
        sed -i "s+#++g" ${LEAP_TOPO}
    fi

    sed -i "s+RECEPTOR+${REC}+g" ${LEAP_TOPO}
  
    $AMBERHOME/bin/tleap -f ${LEAP_TOPO} > prepare_topologies.log

    echo "Done preparing complex $REC"
}

############################################################
# Preparar archivos de MD
############################################################
PrepareMD() {
    local REC=$1
    local N=$2
    local TOPO="${WDPATH}/MD/${REC}/topo"
    local MD_FOLDER="${WDPATH}/MD/${REC}/setupMD/"

    echo "####################################"
    echo "Preparing MD files"
    echo "####################################"

    TOTALRES=$(awk '/ATOM/ {print $5}' "${TOPO}/${REC}_rec.pdb" | tail -n 1)
    NSTEPS=$((500000 * $TIME))

    for rep in $(seq 1 $N); do 
        cp -r ${SCRIPT_PATH}/input_files/equi/* ${MD_FOLDER}/rep${rep}/equi/
        sed -i "s/TOTALRES/${TOTALRES}/g" ${MD_FOLDER}/rep${rep}/equi/*.in ${MD_FOLDER}/rep${rep}/equi/n*t/*.in 
        cp "${SCRIPT_PATH}/input_files/prod/md_prod.in" "${MD_FOLDER}/rep${rep}/prod/"
        sed -i "s/TIME/${NSTEPS}/g" "${MD_FOLDER}/rep${rep}/prod/md_prod.in"
    done
    echo "Done copying files for MD"
}

#Ruta de la carpeta del script (donde se encuentra este script y demás input files)
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ruta de la carpeta de trabajo: /path/to/MD.
WDPATH=($(realpath $WDPATH))

RECEPTOR_PDB=($(ls ${WDPATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

# Input para LEaP
LEAP_SCRIPT="leap_create_rec.in"


CreateDirectories $REPLICAS $RECEPTOR
PrepareReceptor $RECEPTOR
PrepareTopology $RECEPTOR $LEAP_SCRIPT ""
PrepareMD $RECEPTOR $REPLICAS
# Prepare receptor.
# echo "
# ####################################
# Preparing receptor ${RECEPTOR}
# ####################################
# "

# RECEPTOR_PATH="$WDPATH/MD/${RECEPTOR}/receptor"
# cp ${WDPATH}/receptor/$RECEPTOR_PDB $RECEPTOR_PATH
# $AMBERHOME/bin/pdb4amber -i "$WDPATH/MD/$RECEPTOR/receptor/$RECEPTOR_PDB" -o "$WDPATH/MD/$RECEPTOR/receptor/${RECEPTOR}_prep.pdb" --add-missing-atoms --no-conect > "${WDPATH}/MD/${RECEPTOR}/receptor/pdb4amber.log"

# echo "Done preparing receptor: ${RECEPTOR}"

# echo "Creating directories"
# mkdir -p ${WDPATH}/MD/${RECEPTOR}/{topo,setupMD/{rep1/{equi,prod},rep2/{equi,prod},rep3/{equi,prod},rep4/{equi,prod},rep5/{equi,prod}}}
# echo "Done creating directories"

# TOPO=${WDPATH}/MD/${RECEPTOR}/topo
# echo "Copying files to $TOPO
#       Copying ${LEAP_SCRIPT} to $TOPO"

# cp $SCRIPT_PATH/input_files/topo/onlyProtein/${LEAP_SCRIPT} $TOPO #TODO: check if file exists

# echo "Done copying files to $TOPO"

# sed -i "s+TOPO_PATH+${TOPO}+g" ${TOPO}/${LEAP_SCRIPT}
# sed -i "s/RECEPTOR/${RECEPTOR}/g" ${TOPO}/${LEAP_SCRIPT}
# sed -i "s+REC_PATH+${RECEPTOR_PATH}+g" ${TOPO}/${LEAP_SCRIPT}

# ${AMBERHOME}/bin/tleap -f $TOPO/${LEAP_SCRIPT} # Obtain complex.pdb


# for rep in 1 2 3 4 5
#   do
#     TOTALRES=$(cat ${TOPO}/${RECEPTOR}_rec.pdb | tail -n 3 | grep 'ATOM' | awk '{print $5}') # last atom del receptor
#     cp -r $WDPATH/input_files/equi/*  $WDPATH/MD/${RECEPTOR}/setupMD/rep$rep/equi/
#     sed -i "s/TOTALRES/${TOTALRES}/g" $WDPATH/MD/${RECEPTOR}/setupMD/rep$rep/equi/*.in \
#                                       $WDPATH/MD/${RECEPTOR}/setupMD/rep$rep/equi/npt/*.in \
#                                       $WDPATH/MD/${RECEPTOR}/setupMD/rep$rep/equi/nvt/*.in

#     cp $WDPATH/input_files/prod/md_prod.in $WDPATH/MD/${RECEPTOR}/setupMD/rep$rep/prod/
    
#     echo "Done copying files for MD"
#   done
echo "DONE!"


