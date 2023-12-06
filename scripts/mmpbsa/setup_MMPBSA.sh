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

   echo "Syntax: bash setup_MMPBSA.sh [-h|d|s]"
   echo "To save a log file and also print the status, run: bash setup_MMPBSA.sh -d \$DIRECTORY | tee -a \$LOGFILE"
   echo "Options:"
   echo "h     Print help."
   echo "d     MD setupMD Working Directory."
   echo "s     START frame."
   echo "e     END frame."
   echo "o     OFFSET".
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:s:e:o:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WDPATH=$OPTARG;;
      s) # START frame
         START=$OPTARG;;
      e) #END frame
         END=$OPTARG;;
      o) #OFFSET
         OFFSET=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

WDPATH=$(realpath $WDPATH) #Working directory, where MD is located in setupMD
setupMD_PATH=$(realpath ../setupMD/)

# Analyzed ligands
declare -a LIGANDS_MOL2=($(ls $WDPATH/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

degron=1 #procesar input para degron mmpbsa. Solo si ya existen las trayectorias
leap_script="leap_topo_gb1_pb4.in"
extract_coordinates="prod_mdcrd_mmpbsa"
extract_coord="extract_coordinates_com.in"
run_mmpbsa="run_mmpbsa.pbs"
mmpbsa_in="mmpbsa_decomp.in"
method='pb4_gb1'

#LAST_ATOM=9279 # el último átomo considerado como receptor
#TOTAL_ATOM=104595 #Todos los atomos, contando al solvente. Si no sabes, revisa la topologia solvatada del complejo

##############################

for LIG in "${LIGANDS[@]}"
    do
    
    if test -f "${WDPATH}/MMPBSA/${LIG}_gbind/" 
    then
        echo "${WDPATH}/MMPBSA/${LIG}_gbind/ exist"
        echo "CONTINUE"
    else
     	echo "${WDPATH}/MMPBSA/${LIG}_gbind/ do not exist"
       	echo "Creating ${WDPATH}/MMPBSA/${LIG}_gbind/"
	mkdir -p ${WDPATH}/MMPBSA/${LIG}_gbind/
       	echo "DONE"
    fi
    
    #TOPO="${WDPATH}/MD/${LIG}_gbind/topo/"
    TOPO_MD=${WDPATH}/MD/${LIG}/topo
    
    echo "Doing for $LIG"
    echo "Creating directories"
    
    mkdir -p ${WDPATH}/MMPBSA/${LIG}_gbind/{snapshots_rep1,snapshots_rep2,snapshots_rep3,snapshots_rep4,snapshots_rep5,"s${START}_${END}_${OFFSET}"/${method}/{rep1,rep2,rep3,rep4,rep5}}
     
# this is to obtain total atom from parmtop file of setupMD
   TOTAL_ATOM_SOLVATED=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_solv_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}')
   
   LAST_ATOM_COM=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}')
   
   FIRST_ATOM_LIG=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb | grep 'LIG' | awk '{print $2}' | head -n 1)
   LAST_ATOM_LIG=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb | grep 'LIG' | awk '{print $2}' | tail -n 1)
   
   FIRST_LAST_ATOM_REC=$(($FIRST_ATOM_LIG - 1))
   SECOND_FIRST_ATOM_REC=$(($LAST_ATOM_LIG + 1))
   SECOND_LAST_ATOM_REC=$LAST_ATOM_COM
   
   # Hay dos "grupos de receptores"
   # del átomo 1 hasta el primer átomo del ligando -1, es el primer receptor y corresponde a la proteína
   # Luego del primer átomo del ligando hasta el ultimo, es el ligando
   # Luego vienen 2 moleculas de agua, a eso le llamo el segundo grupo de atomo
   
   
for i in 1 2 3 4 5 	
    do
    
    # MD
    MD_coords=${WDPATH}/MD/${LIG}/setupMD/rep${i}/prod
    
    if test -f ${MD_coords}/${LIG}_prod_noWAT_mmpbsa.nc
    then
        echo "Correct coordinates available!"
    else
        echo "Correct coordinates not available!
Going to extract coordinates starting at ${START}, ending at ${END} by offset ${OFFSET}"
        cp $SCRIPT_PATH/mmpbsa_files/${extract_coordinates} $MD_coords
        cd $MD_coords 
        sed -i "s+TOPO_MD+${TOPO_MD}+g" $MD_coords/${extract_coordinates}
        sed -i "s+MD_coords+${MD_coords}+g" $MD_coords/${extract_coordinates}
        sed -i "s/START/${START}/g" $MD_coords/${extract_coordinates}
        sed -i "s/END/${END}/g" $MD_coords/${extract_coordinates}
        sed -i "s/OFFSET/${OFFSET}/g" $MD_coords/${extract_coordinates}
        sed -i "s/LIG/${LIG}/g" $MD_coords/${extract_coordinates}
        
        ${AMBERHOME}/bin/cpptraj -i $MD_coords/${extract_coordinates}
        
    fi

    SNAP="${WDPATH}/MMPBSA/${LIG}_gbind/snapshots_rep${i}/"
    cp $SCRIPT_PATH/mmpbsa_files/$extract_coord $SNAP
    sed -i "s/TOPO/${TOPO_MD}/g" $SNAP/$extract_coord
    sed -i "s/REP/${i}/g" $SNAP/$extract_coord
    sed -i "s/LIGND/${LIG}/g" $SNAP/$extract_coord
    sed -i "s/TOTAL_ATOM/${TOTAL_ATOM_SOLVATED}/g" $SNAP/$extract_coord
    sed -i "s/FIRST_LAST_ATOM_REC/${FIRST_LAST_ATOM_REC}/g" $SNAP/$extract_coord
    sed -i "s/SECOND_FIRST_ATOM_REC/${SECOND_FIRST_ATOM_REC}/g" $SNAP/$extract_coord
    sed -i "s/SECOND_LAST_ATOM_REC/${SECOND_LAST_ATOM_REC}/g" $SNAP/$extract_coord
    sed -i "s/FIRST_ATOM_LIG/${FIRST_ATOM_LIG}/g" $SNAP/$extract_coord
    sed -i "s/LAST_ATOM_LIG/${LAST_ATOM_LIG}/g" $SNAP/$extract_coord
    sed -i "s+RUTA_MD+${MD_coords}+g" $SNAP/$extract_coord
    
    MMPBSA="${WDPATH}/${LIG}_gbind/pb4_gb1/rep${i}/"
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
