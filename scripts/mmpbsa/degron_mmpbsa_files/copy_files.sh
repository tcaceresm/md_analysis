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

   echo "Syntax: bash setup_MMPBSA.sh [-h|d]"
   echo "To save a log file and also print the status, run: bash setup_MMPBSA.sh -d \$DIRECTORY | tee -a \$LOGFILE"
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

RECEPTOR_PDB=($(ls ${SCRIPT_PATH}/receptor/))
RECEPTOR=($(sed "s/.pdb//g" <<< "${RECEPTOR_PDB[*]}"))


degron=1 #procesar input para degron mmpbsa. Solo si ya existen las trayectorias
leap_script="leap_topo_gb1_pb4.in"
extract_coord="extract_coordinates_com.in"
run_mmpbsa="run_mmpbsa.pbs"
mmpbsa_in="mmpbsa_decomp.in"
#LAST_ATOM=9279 # el último átomo considerado como receptor
#TOTAL_ATOM=104595 #Todos los atomos, contando al solvente. Si no sabes, revisa la topologia solvatada del complejo

##############################

for LIG in "${arr[@]}"
    do
    
    if test -f "${WDPATH}/calc_a_1t/${LIG}_degron_gbind/" 
    then
        echo "${WDPATH}/calc_a_1t/${LIG}_degron_gbind/ exist"
        echo "CONTINUE\n"
    else
     	echo "${WDPATH}/calc_a_1t/${LIG}_degron_gbind/ do not exist"
       	echo "Creating ${WDPATH}/calc_a_1t/${LIG}_degron_gbind/"
	mkdir "${WDPATH}/calc_a_1t/${LIG}_degron_gbind/"
       	echo "DONE\n"
    fi   	
    TOPO="${WDPATH}/calc_a_1t/${LIG}_degron_gbind/topo/"

    
    echo "Doing for $LIG"
    echo "Creating directories"
    
    mkdir -p ${WDPATH}/calc_a_1t/${LIG}_degron_gbind/{topo,snapshots_rep1,snapshots_rep2,snapshots_rep3,snapshots_rep4,snapshots_rep5,s1_500_5/pb4_gb1/{rep1,rep2,rep3,rep4,rep5}}
    
    echo "Copying files to $TOPO"  
    echo "Copying ${leap_script} to $TOPO"
    cp $SCRIPT_PATH/${leap_script} $TOPO
    sed -i "s/ID/${ID}/g" $TOPO/${leap_script}	  
    sed -i "s/LIG/${LIG}/g" $TOPO/${leap_script}	
    
# this is to obtain total atom from parmtop file
   TOTAL_ATOM=$(cat ${WDPATH}/MD_am1/${LIG}1/cryst/${LIG}1_solv_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}')
   LAST_ATOM=$(cat ${WDPATH}/MD_am1/${LIG}1/cryst/${LIG}1_vac_com_noWAT.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}')
   echo "${LAST_ATOM}"
for i in 1 2 3 4 5 	
    do


    SNAP="${WDPATH}/calc_a_1t/${LIG}_degron_gbind/snapshots_rep${i}/"
    cp $SCRIPT_PATH/$extract_coord $SNAP
    sed -i "s/REP/${i}/g" $SNAP/$extract_coord
    sed -i "s/LIGND/${LIG}/g" $SNAP/$extract_coord
    sed -i "s/TOTAL_ATOM/${TOTAL_ATOM}/g" $SNAP/$extract_coord
    sed -i "s/LAST_ATOM/${LAST_ATOM}/g" $SNAP/$extract_coord
    
    MMPBSA="${WDPATH}/calc_a_1t/${LIG}_degron_gbind/s1_500_5/pb4_gb1/rep${i}/"
    cp "$SCRIPT_PATH/$run_mmpbsa" $MMPBSA
    sed -i "s/LIG/${LIG}/g" $MMPBSA/${run_mmpbsa}
    sed -i "s/repN/rep${i}/g" $MMPBSA/${run_mmpbsa}
    sed -i "s/REP/${i}/g" $MMPBSA/${run_mmpbsa}
    
    cp "$SCRIPT_PATH/$mmpbsa_in" $MMPBSA
    sed -i "s/LIGND/${LIG}/g" $MMPBSA/${mmpbsa_in}
    sed -i "s/REP/${i}/g" $MMPBSA/${mmpbsa_in}
    
    
 

    done
done
echo "DONE!"
