#!/usr/bin/bash

set -euo pipefail

############################################################
# Help
############################################################
Help() {
    echo "Usage: bash setup_MD.sh [-h] [-d DIRECTORY] [-t TIME] [-n REPLICAS] [-p 0|1] [-z 0|1] [-r 0|1] [-l 0|1] [-c 0|1] [-x 0|1] [-k 0|1] [-g 0|1] [-u 0|1] [-y CHARGE]"
    echo
    echo "This script sets up molecular dynamics simulations in the specified directory."
    echo "Also, it can setup MM/P(G)BSA rescoring calculations (only in protein-ligand setup)."
    echo "The specified directory must always have a folder named  \"receptor\" containing the receptor PDB \
and an optional \"ligands\" and \"cofactor\" folder containing MOL2 file of ligands and cofactor, respectively."
    echo "There are two ways of setup MD:"
    echo "   1) Setup a only-protein MD. See [-p] flag below."
    echo "   2) Setup a Protein-Ligand MD. See [-z] flag below."
    echo "You can setup both at the same time."
    echo "If you want to re-run this script to debug something, you can save some time setting r|l|c|x|k flags to zero. See examples below."
    echo
    echo "Options:"
    echo "  -h               Show this help message and exit."
    echo "  -d DIRECTORY     Specify the directory for the simulation."
    echo "  -p 0|1           Set up Protein-only MD."
    echo "  -z 0|1           Set up Protein-Ligand MD."
    echo "  -t TIME          Simulation time in nanoseconds (assuming a 2 fs timestep)."
    echo "  -f EQUI_TIME     (default=1) Simulation time (in ns) of last step of equilibration (2 fs timestep)"
    echo "  -n REPLICAS      Number of replicas to run in the simulation."
    echo "  -r 0|1           (default=1) Flag to indicate if the receptor should be prepared."
    echo "  -l 0|1           (default=1) Flag to indicate if the ligands should be parameterized. Doesn't apply for only-protein MD"
    echo "  -c 0|1           (default=0) Flag to indicate if the cofactor should be parameterized."
    echo "  -x 0|1           (default=1) Preparation of topologies. If 0, won't copy input files or calculate topologies"
    echo "  -k 0|1           (default=1) Copy MD input files."
    echo "  -g 0|1           (default=0) Setup MM/PB(G)SA rescoring."
    echo "  -u 0|1           (default=1) Compute partial charges using antechamber"
    echo "  -y CHARGE        (default='bcc') Charge method for ligand parameterization. See antechamber -L for charge methods."

    echo
    echo "Examples:"
    echo " -Perform both Protein-only MD and Protein-Ligand MD, 100 ns length, 3 replicas, without cofactor:"
    echo "   bash setup_MD.sh -d /path/to/dir -p 1 -z 1 -t 100 -n 3"
    echo " -Perform only Protein-Ligand MD, with a cofactor:"
    echo "   bash setup_MD.sh -d /path/to/dir -p 0 -z 1 -t 100 -n 3 -c 1"
    echo " -Re-run this script to debug topologies in Protein-Ligand MD. This won't re-parameterize ligands:"
    echo "   bash setup_MD.sh -d /path/to/dir -p 0 -z 1 -t 100 -n 3 -r 0 -l 0"
    echo
}

# Default values
EQUI_TIME=1
MMPBSA=0
PREP_REC=1
PREP_LIG=1
PREP_COFACTOR=0
PREP_TOPO=1
PREP_MD=1
CHARGE_METHOD='bcc'
COMPUTE_CHARGES=1

###########################################################
# Options
###########################################################
while getopts ":hd:p:z:g:t:f:n:r:l:c:x:k:u:y:" option; do
    case $option in
        h)  # Print this help
            Help
            exit;;
        d)  # Enter the MD Directory
            WDPATH=$OPTARG;;
        t)  # Time in nanoseconds
            TIME=$OPTARG;;
        f)  # EQUI TIME
            EQUI_TIME=$OPTARG;;
        n)  # Replicas
            REPLICAS=$OPTARG;;
        p)  # Protein-Only MD
            ONLY_PROTEIN_MD=$OPTARG;;
        z)  # Protein-Ligand MD
            PROT_LIG_MD=$OPTARG;;
        g)  # MM/P(G)BSA rescoring
            MMPBSA=$OPTARG;;
        r)  # Prepare receptor?
            PREP_REC=$OPTARG;;
        l)  # Prepare ligand?
            PREP_LIG=$OPTARG;;
        c)  # Prepare cofactor?
            PREP_COFACTOR=$OPTARG;;
        x)  # Prepare TOPO?
            PREP_TOPO=$OPTARG;;
        k)  # Prep MD input files
            PREP_MD=$OPTARG;;
        u)  # Compute charges
            COMPUTE_CHARGES=$OPTARG;;
        y)  # Charge method
            CHARGE_METHOD=$OPTARG;;
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
"#############################################################"
Welcome to SetupMD v0.0.0
Author: Tomás Cáceres <caceres.tomas@uc.cl>
Laboratory of Molecular Design <http://schuellerlab.org/>
https://github.com/tcaceresm/md_analysis
Powered by high fat food and procrastination
"#############################################################"
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
    SUBDIRS=("equi/npt" "equi/nvt" "prod/npt" "prod/nvt")

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
    BASE_DIR=${WDPATH}/MD/${RECEPTOR}/proteinLigandMD
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
# Prepare receptor
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
# Prepare non-standard residue (ligand)
############################################################
PrepareLigand() {
    local LIG=$1
    local LIG_PATH=$2
    local LEAP_LIG=$3
    local LIGAND_LIB=$4
    local RESNAME=$5
    local COMPUTE_CHARGES=$6
        
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

    if [[ ${COMPUTE_CHARGES} -eq 1 ]]
    then
        $AMBERHOME/bin/antechamber -i "${LIGAND_LIB}/${LIG}.mol2" -fi mol2 -o "${LIGAND_LIB}/${LIG}.mol2" -fo mol2 -c "${CHARGE_METHOD}" -nc "$LIGAND_NET_CHARGE" -at gaff2 -rn $RESNAME
    else
        $AMBERHOME/bin/antechamber -i "${LIGAND_LIB}/${LIG}.mol2" -fi mol2 -o "${LIGAND_LIB}/${LIG}.mol2" -fo mol2 -at gaff2 -rn $RESNAME
    fi
    $AMBERHOME/bin/antechamber -i "${LIGAND_LIB}/${LIG}.mol2" -fi mol2 -o "${LIGAND_LIB}/${LIG}_lig.pdb" -fo pdb -dr n -at gaff2 -rn $RESNAME
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
    local TOPO="${WDPATH}/MD/${REC}/proteinLigandMD/${LIG}/topo"

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
    NSTEPS_EQUI=$((500000 * $EQUI_TIME))

    for rep in $(seq 1 $N); do 
        cp -r ${SCRIPT_PATH}/input_files/equi/* ${MD_FOLDER}/rep${rep}/equi/
        sed -i "s/TOTALRES/${TOTALRES}/g" ${MD_FOLDER}/rep${rep}/equi/*.in ${MD_FOLDER}/rep${rep}/equi/n*t/*.in 
        sed -i "s/TIME/${NSTEPS_EQUI}/g" ${MD_FOLDER}/rep${rep}/equi/npt/npt_equil_6.in

        cp "${SCRIPT_PATH}/input_files/prod/md_prod.in" "${MD_FOLDER}/rep${rep}/prod/npt/"
        sed -i "s/TIME/${NSTEPS}/g" "${MD_FOLDER}/rep${rep}/prod/npt/md_prod.in"
    done

    echo "Done copying files for MD!"
    echo 
}

PrepareProteinLigandMD() {
    local LIG=$1
    local REC=$2
    local N=$3
    local TOPO="${WDPATH}/MD/${REC}/proteinLigandMD/${LIG}/topo"
    local MD_FOLDER="${WDPATH}/MD/${REC}/proteinLigandMD/${LIG}/setupMD/"

    echo "####################################"
    echo "# Preparing ProteinLigand MD files #"
    echo "####################################"

    if [[ ! -f ${TOPO}/${LIG}_com.pdb ]]
    then
        echo "ERROR! Can't find ${TOPO}/${LIG}_com.pdb in order to obtain ligand (${LIG}) residue number."
        echo "Make sure that protein-ligand complex topologies exist."
        echo "Have you run the [-x 1] flag previously?"
        echo "Exiting"
        exit 1
    fi

    TOTALRES=$(awk '/ATOM/ {print $5}' "${TOPO}/${LIG}_com.pdb" | tail -n 1)
    NSTEPS=$((500000 * $TIME))
    NSTEPS_EQUI=$((500000 * $EQUI_TIME))
    for rep in $(seq 1 $N)
    do 
        cp -r ${SCRIPT_PATH}/input_files/equi/* ${MD_FOLDER}/rep${rep}/equi/
        sed -i "s/TOTALRES/${TOTALRES}/g" ${MD_FOLDER}/rep${rep}/equi/*.in ${MD_FOLDER}/rep${rep}/equi/n*t/*.in 
        sed -i "s/TIME/${NSTEPS_EQUI}/g" ${MD_FOLDER}/rep${rep}/equi/npt/npt_equil_6.in

        cp "${SCRIPT_PATH}/input_files/prod/md_prod.in" "${MD_FOLDER}/rep${rep}/prod/npt"
        sed -i "s/TIME/${NSTEPS}/g" "${MD_FOLDER}/rep${rep}/prod/npt/md_prod.in"  
    done

    echo "Done copying files for ProteinLigand MD"
    echo
}

PrepareProteinLigandMMPBSA() {
    local LIG=$1
    local REC=$2
    local N=$3
    local TOPO="${WDPATH}/MD/${REC}/proteinLigandMD/${LIG}/topo"
    local MD_FOLDER="${WDPATH}/MD/${REC}/proteinLigandMD/${LIG}/setupMD/"

    echo "#########################################"
    echo "# Preparing ProteinLigand MMPBSA files #"
    echo "#########################################"

    if [[ ! -f ${TOPO}/${LIG}_com.pdb ]]
    then
        echo "ERROR! Can't find ${TOPO}/${LIG}_com.pdb in order to obtain ligand (${LIG}) residue number."
        echo "Make sure that protein-ligand complex topologies exist."
        echo "Have you run the [-x 1] flag previously?"
        echo "Exiting"
        exit 1
    fi

    TOTALRES=$(awk '/ATOM/ {print $5}' "${TOPO}/${LIG}_com.pdb" | tail -n 1)

    for rep in $(seq 1 $N)
    do 
        cp ${SCRIPT_PATH}/input_files/mmpbsa_rescoring/*.in ${MD_FOLDER}/rep${rep}/mmpbsa_rescoring
        sed -i "s/TOTALRES/${TOTALRES}/g" ${MD_FOLDER}/rep${rep}/mmpbsa_rescoring/*.in
    done

    echo " Done!"
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
RECEPTOR_PDB=($(basename "${WDPATH}/receptor/"*.pdb))
if [[ ${#RECEPTOR_PDB[@]} -eq 0 ]]
then
    echo "Empty receptor folder."
    echo "Exiting."
    exit 1
fi

RECEPTOR_NAME=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))

ENSEMBLE="npt"

displayHello

if [[ $PREP_REC -eq 1 ]]
then
    PrepareReceptor $RECEPTOR_NAME
fi

# Preparar cofactor
if [[ $PREP_COFACTOR -eq 1 ]]
then
    mkdir -p ${WDPATH}/MD/${RECEPTOR_NAME}/cofactor_lib
    COFACTOR_MOL2=($(basename "${WDPATH}/cofactor/"*.mol2))
    
    COFACTOR_NAME=($(sed "s/.mol2//g" <<< "${COFACTOR_MOL2[*]}"))

    PrepareLigand $COFACTOR_NAME "${WDPATH}/cofactor" "leap_lib_cof.in" "${WDPATH}/MD/${RECEPTOR_NAME}/cofactor_lib" "COF" ${COMPUTE_CHARGES}
else
    COFACTOR_NAME="a" #I'm not a good programmer

fi

if [[ $ONLY_PROTEIN_MD -eq 1 ]]
then
    echo "#############################"
    echo "# Preparing Only Protein MD #"
    echo "#############################"
    # Input para LEaP
    LEAP_SCRIPT="leap_create_rec.in"

    CreateOnlyProteinDirectories $REPLICAS $RECEPTOR_NAME
    if [[ $PREP_TOPO -eq 1 ]]
    then
        PrepareOnlyProteinTopology $RECEPTOR_NAME $LEAP_SCRIPT
    fi
    if [[ $PREP_MD -eq 1 ]]
    then
        PrepareOnlyProteinMD $RECEPTOR_NAME $REPLICAS
    fi
fi

# Preparar ligandos, complejos y archivos de MD
if [[ $PROT_LIG_MD -eq 1 ]]
then
    echo "####################################"
    echo "# Preparing Protein-Ligand MD      #"
    echo "####################################"
    # Ligandos
    LIGANDS_MOL2=("${WDPATH}/ligands/"*.mol2)

    if [[ ${#LIGANDS_MOL2[@]} -eq 0 ]]
    then
        echo "Empty ligands folder."
        echo "Exiting."
        exit 1
    fi

    LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))
    # Ligand leap input
    LEAP_LIGAND="leap_lib.in"
    # Leap input para topologias complejo proteina-ligando
    LEAP_TOPO="leap_create_com.in"

    # for LIG in "${LIGANDS[@]}"
    # do
    #     LIG=$(basename "${LIG}")
        
    #     CreateProteinLigandDirectories $REPLICAS $LIG $RECEPTOR_NAME
        
    #     if [[ $PREP_LIG -eq 1 ]]
    #     then
    #         PrepareLigand $LIG "${WDPATH}/ligands" "leap_lib.in" "${WDPATH}/MD/${RECEPTOR_NAME}/proteinLigandMD/${LIG}/lib" "LIG" ${COMPUTE_CHARGES}
    #     fi

    #     if [[ $PREP_TOPO -eq 1 ]]
    #     then
    #         PrepareProteinLigandTopology "$LIG" "$RECEPTOR_NAME" $LEAP_TOPO
    #     fi

    #     if [[ $PREP_MD -eq 1 ]]
    #     then
    #         PrepareProteinLigandMD "$LIG" "$RECEPTOR_NAME" $REPLICAS
    #     fi

    #     if [[ $MMPBSA -eq 1 ]]
    #     then
    #         PrepareProteinLigandMMPBSA $LIG $RECEPTOR_NAME $REPLICAS
    #     fi

    # done

    #######

    # Assuming necessary environment variables are set:
    # $LIGANDS (Array of ligands), $RECEPTOR_NAME, $WDPATH, $LEAP_TOPO, $COMPUTE_CHARGES, etc.

    # Export functions
    export -f CreateProteinLigandDirectories
    export -f PrepareLigand
    export -f PrepareProteinLigandTopology
    export -f PrepareProteinLigandMD
    export -f PrepareProteinLigandMMPBSA

    # Export necessary variables for parallel jobs
    export AMBERHOME
    export SCRIPT_PATH
    export LIG
    export WDPATH
    export LEAP_LIGAND
    export LEAP_TOPO
    export COMPUTE_CHARGES
    export PREP_LIG
    export PREP_TOPO
    export PREP_MD
    export MMPBSA
    export REPLICAS
    export TIME
    export EQUI_TIME

    RECEPTOR_NAME=${RECEPTOR_NAME[0]} 
    
    export RECEPTOR_NAME

    # Function to process each ligand
    process_ligand() {
	echo "REPLICAS ${REPLICAS}"
        LIG=$1  # The ligand file name
	RECEPTOR_NAME=$2

        LIG=$(basename "${LIG}")
        # Create directories for protein-ligand setup
        CreateProteinLigandDirectories $REPLICAS $LIG $RECEPTOR_NAME

         if [[ $PREP_LIG -eq 1 ]]
         then
             PrepareLigand $LIG "${WDPATH}/ligands" "leap_lib.in" "${WDPATH}/MD/${RECEPTOR_NAME}/proteinLigandMD/${LIG}/lib" "LIG" ${COMPUTE_CHARGES}
         fi

         if [[ $PREP_TOPO -eq 1 ]]
         then
             PrepareProteinLigandTopology "$LIG" "$RECEPTOR_NAME" $LEAP_TOPO
         fi

         if [[ $PREP_MD -eq 1 ]]
         then
             PrepareProteinLigandMD "$LIG" "$RECEPTOR_NAME" $REPLICAS
         fi

         if [[ $MMPBSA -eq 1 ]]
         then
             PrepareProteinLigandMMPBSA $LIG $RECEPTOR_NAME $REPLICAS
         fi
    }

    # Export the function so it can be used by parallel
    export -f process_ligand

    # Run the jobs in parallel
    parallel --jobs 33 process_ligand ::: "${LIGANDS[@]}" ::: "${RECEPTOR_NAME}"
    ###################
fi

echo "DONE!"
