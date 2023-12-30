#!/usr/bin/bash
set -e
set -u
set -o pipefail
##
## Agregar method como flago
##  Luego determinar el mmpbsa.in adecuado
##
############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help

   echo "Syntax: bash setup_MMPBSA.sh [-h|d|s|e|o|m]"
   echo "To save a log file and also print the status, run: bash setup_MMPBSA.sh -d \$DIRECTORY | tee -a \$LOGFILE"
   echo "Options:"
   echo "h     Print help."
   echo "d     MD setupMD Working Directory."
   echo "s     START frame."
   echo "e     END frame."
   echo "o     OFFSET".
   echo "m     Method. Use alias used in FEW. Check AMBER23 manual page 880. Example: pb3_gb0."
   echo "r     PBRadii. This will modify the topology PBRadii to desired one. This need to match with correct mmpbsa.in. Example: mbondi"
   echo "l     Extract snapshots from production trajectories?"
   echo "w     Use explicit waters in MMPBSA calculations. This feature has not been tested."
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:s:e:o:m:w:r:l:" option; do
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
      m) #Method
         METHOD=$OPTARG;;
      r) #PBRadii
         PBRadii=$OPTARG;;
      w) # Use explicit waters
         WATERS=$OPTARG;;
      l) # Extract snapshots
         EXTRACT_SNAP=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

WDPATH=$(realpath $WDPATH) #Working directory, where MD is located in setupMD

# Analyzed ligands
declare -a LIGANDS_MOL2=($(ls $WDPATH/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

extract_coordinates="extract_coordinates_prod_mmpbsa"
extract_snapshots="extract_snapshots_com.in"
mmpbsa_in="mmpbsa_${METHOD}.in"

##############################

for LIG in "${LIGANDS[@]}"
    do
    echo "Doing for $LIG"
    if test -d "${WDPATH}/MMPBSA/${LIG}_gbind/" 
    then
        echo "${WDPATH}/MMPBSA/${LIG}_gbind/ exist"
        echo "CONTINUE"
    else
     	echo "${WDPATH}/MMPBSA/${LIG}_gbind/ do not exist"
       	echo "Creating ${WDPATH}/MMPBSA/${LIG}_gbind/"
	mkdir -p ${WDPATH}/MMPBSA/${LIG}_gbind/
        echo "Creating sub-directories"    
        mkdir -p ${WDPATH}/MMPBSA/${LIG}_gbind/{topo,snapshots_rep1,snapshots_rep2,snapshots_rep3,snapshots_rep4,snapshots_rep5,"s${START}_${END}_${OFFSET}"/${METHOD}/{rep1,rep2,rep3,rep4,rep5}}
       	echo "DONE"
    fi
    
    TOPO_MD="${WDPATH}/MD/${LIG}/topo" # Necessary for coordinates extraction
    TOPO_MMPBSA="${WDPATH}/MMPBSA/${LIG}_gbind/topo" # Necessary to set correct PBRadii in topology file used in MMPBSA calculations
    
    # Preparation of topology files for MMPBSA calculations. We will modify the topology of lig, rec and com of MD topology files
    echo "Modifying PBRadii using ParmEd utility"
    cp ${SCRIPT_PATH}/mmpbsa_files/*modify* ${TOPO_MMPBSA}
    sed -i "s/PBRADII/${PBRadii}/g" ${TOPO_MMPBSA}/*modify*
    sed -i "s/LIG/${LIG}/g" ${TOPO_MMPBSA}/*modify*
    
    cd ${TOPO_MMPBSA}
    ${AMBERHOME}/bin/parmed --overwrite -p ${TOPO_MD}/${LIG}_vac_com.parm7 -i ${TOPO_MMPBSA}/modify_pbradii_vac_com.txt
    ${AMBERHOME}/bin/parmed --overwrite -p ${TOPO_MD}/${LIG}_vac_rec.parm7 -i ${TOPO_MMPBSA}/modify_pbradii_vac_rec.txt
    ${AMBERHOME}/bin/parmed --overwrite -p ${TOPO_MD}/${LIG}_vac_lig.parm7 -i ${TOPO_MMPBSA}/modify_pbradii_vac_lig.txt
    cd ${WDPATH}
    
# this is to obtain total atom from pdb file of setupMD, a necessary value forr.
   TOTAL_ATOM_SOLVATED=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_solv_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}')
   
   if [[ $WATERS -eq 0 ]]
   then
       echo "Not considering explicit waters in MMPBSA calculations"
       echo "Modifying MMPSA input file"
       echo "Computing Total Atoms in Unsolvated complex"
       TOTAL_ATOM_UNSOLVATED=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb | grep -v 'WAT\|TER\|END' | tail -n 1 | grep 'ATOM' | awk '{print $2}')
       FIRST_ATOM_LIG=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb | grep 'LIG' | awk '{print $2}' | head -n 1)
       LAST_ATOM_REC=$(($FIRST_ATOM_LIG - 1))
       LAST_ATOM_LIG=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb | grep 'LIG' | awk '{print $2}' | tail -n 1)
       echo "Please check prepared input files for MMPBSA are correct!"
   else
       echo "Assuming that you do want to consider explicit waters in MMPBSA calculations"
       echo "Computing Total Atoms in Unsolvated complex considering explicit waters"
       TOTAL_ATOM_UNSOLVATED=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb | tail -n 1 | grep 'ATOM' | awk '{print $2}')
       FIRST_ATOM_LIG=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb | grep 'LIG' | awk '{print $2}' | head -n 1)
       LAST_ATOM_LIG=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb | grep 'LIG' | awk '{print $2}' | tail -n 1)
       LAST_ATOM_REC=$(($FIRST_ATOM_LIG - 1))
       echo "Please check prepared input files for MMPBSA are correct!"
    fi 
for i in 1 2 3 4 5 	
    do
    echo "Doing for ${LIG} repetition ${i}"
    # MD
    MD_coords=${WDPATH}/MD/${LIG}/setupMD/rep${i}/prod
    
    if test -f ${MD_coords}/${LIG}_prod_noWAT_mmpbsa.crd
    # Solvated coordinates -> unsolvated and specific snapshots for MMPBSA
    # i.e, from 3000 snapshots trajectory, we choose only 100. Then, we
    # will use mm_pbsa.pl to finally extract the snapshots used for MMPBSA.
    then
        echo "Coordinates for snapshots extraction available!"
    else
        echo "Correct coordinates for snapshots extraction not available!"
        echo "Going to extract coordinates from production trajectory starting at ${START}, ending at ${END} by offset ${OFFSET}"
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
    
    if [[ $EXTRACT_SNAP -eq 1 ]]
    then
        #Snapshot extraction
        
        echo "Going to extract snapshots"
        SNAP="${WDPATH}/MMPBSA/${LIG}_gbind/snapshots_rep${i}/"
        cp $SCRIPT_PATH/mmpbsa_files/$extract_snapshots $SNAP
        sed -i "s+TOPO+${TOPO_MD}+g" $SNAP/$extract_snapshots
        sed -i "s/REP/${i}/g" $SNAP/$extract_snapshots
        sed -i "s/LIGND/${LIG}/g" $SNAP/$extract_snapshots
        sed -i "s/TOTAL_ATOM/${TOTAL_ATOM_UNSOLVATED}/g" $SNAP/$extract_snapshots
        sed -i "s/LAST_ATOM_REC/${LAST_ATOM_REC}/g" $SNAP/$extract_snapshots
        sed -i "s/FIRST_ATOM_LIG/${FIRST_ATOM_LIG}/g" $SNAP/$extract_snapshots
        sed -i "s/LAST_ATOM_LIG/${LAST_ATOM_LIG}/g" $SNAP/$extract_snapshots
        sed -i "s+RUTA_MD+${MD_coords}+g" $SNAP/$extract_snapshots
    
        cd ${SNAP}
        echo "Extracting snapshots from ${MD_coords}/${LIG}_prod_noWAT_mmpbsa.nc"
        $AMBERHOME/bin/mm_pbsa.pl ${SNAP}/${extract_snapshots} > ${SNAP}/extract_coordinates_com.log
        echo "Done!"   
        cd ${WDPATH}
    else
    echo "Not extracting snapshots"
    SNAP="${WDPATH}/MMPBSA/${LIG}_gbind/snapshots_rep${i}/"
    echo "Done!"
    fi
    

    # MMPBSA files location
    MMPBSA="${WDPATH}/MMPBSA/${LIG}_gbind/"s${START}_${END}_${OFFSET}"/${METHOD}/rep${i}/"
    
    # Edit mmpbsa.in file
    cp "$SCRIPT_PATH/mmpbsa_files/$mmpbsa_in" $MMPBSA
    sed -i "s/LIGND/${LIG}/g" $MMPBSA/${mmpbsa_in}
    sed -i "s/REP/${i}/g" $MMPBSA/${mmpbsa_in}
    sed -i "s+SNAP_PATH+${SNAP}+g" $MMPBSA/${mmpbsa_in}
    sed -i "s+TOPO+${TOPO_MD}+g" $MMPBSA/${mmpbsa_in}
    
    # Edit run_mmpbsa_lig.sh file, to run in NLHPC cluster

    cp "$SCRIPT_PATH/mmpbsa_files/run_mmpbsa_lig.sh" $MMPBSA
    sed -i "s/LIG/${LIG}/g" "$MMPBSA/run_mmpbsa_lig.sh"
    sed -i "s/repN/rep${i}/g" "$MMPBSA/run_mmpbsa_lig.sh"
    sed -i "s/MMPBSA_IN/${mmpbsa_in}/g" "$MMPBSA/run_mmpbsa_lig.sh"
    sed -i "s+MD_TOPO+${WDPATH}/MD/${LIG}/topo+g" "$MMPBSA/run_mmpbsa_lig.sh"
    sed -i "s+MMPBSA_SNAPS+${WDPATH}/MMPBSA/${LIG}_gbind/snapshots_rep${i}+g" "$MMPBSA/run_mmpbsa_lig.sh"
    sed -i "s+MMPBSA_PATH+${WDPATH}/MMPBSA/${LIG}_gbind/s1_3000_30/${METHOD}/rep${i}/+g" "$MMPBSA/run_mmpbsa_lig.sh"
    sed -i "s/METHOD/${METHOD}/g" "$MMPBSA/run_mmpbsa_lig.sh"
    sed -i "s+MMPBSA_TMP_PATH+${WDPATH}/MMPBSA/tmp/+g" "$MMPBSA/run_mmpbsa_lig.sh"
    
    # Edit run_ppbsa_slurm.sh file, to run in NLHPC cluster
    cp "$SCRIPT_PATH/mmpbsa_files/run_mmpbsa_slurm.sh" $MMPBSA
    sed -i "s/LIG/${LIG}/g" "$MMPBSA/run_mmpbsa_slurm.sh"
    sed -i "s/repN/rep${i}/g" "$MMPBSA/run_mmpbsa_slurm.sh"
    sed -i "s/REP/${i}/g" "$MMPBSA/run_mmpbsa_slurm.sh"
    
    done
done
echo "DONE!"
