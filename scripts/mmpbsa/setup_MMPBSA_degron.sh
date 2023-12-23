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
   echo "d     Working Directory."
   echo "s     START frame."
   echo "e     END frame."
   echo "o     OFFSET".
   echo "m     Method. Use alias used in FEW. Check AMBER23 manual page 880. Example: pb3_gb0"
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:s:e:o:m:" option; do
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
      \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

# Script location
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Working directory path
WDPATH=$(realpath $WDPATH) 

# Analyzed ligands
declare -a LIGANDS_MOL2=($(ls $WDPATH/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

# Cofactor
COFACTOR_MOL2=($(ls ${WDPATH}/cofactor/))
COFACTOR=($(sed "s/.mol2//g" <<< "${COFACTOR_MOL2[*]}"))

leap_script="leap_topo_pb3_gb0.in"
extract_coordinates="prod_mdcrd_mmpbsa_degron"
extract_snapshots="extract_coordinates_com.in"
run_mmpbsa="run_mmpbsa.pbs"

##############################

for LIG in "${LIGANDS[@]}"
    do
    
    if test -d "${WDPATH}/MMPBSA/${LIG}_degron_gbind/" 
    then
        echo "${WDPATH}/MMPBSA/${LIG}_degron_gbind/ exist"
        echo "CONTINUE"
    else
     	echo "${WDPATH}/MMPBSA/${LIG}_degron_gbind/ do not exist"
       	echo "Creating ${WDPATH}/MMPBSA/${LIG}_degron_gbind/"
	mkdir -p ${WDPATH}/MMPBSA/${LIG}_degron_gbind/
       	echo "DONE"
    fi
    
   # Degron as ligand requires new topologies, so we can't use same topologies
   # from setupMD folder. 
   TOPO_MD="${WDPATH}/MD/${LIG}/topo"
   TOPO_MMPBSA=${WDPATH}/MMPBSA/${LIG}_degron_gbind/topo/ # We'll use this later. But I prefer to define here.

   if test -d "${WDPATH}/MMPBSA/${LIG}_degron_gbind/topo" 
   then
      echo "${WDPATH}/MMPBSA/${LIG}_degron_gbind/topo exist"
      echo "CONTINUE"
   else
     	echo "${WDPATH}/MMPBSA/${LIG}_degron_gbind/topo do not exist"
     	echo "Creating ${WDPATH}/MMPBSA/${LIG}_degron_gbind/topo"
	   mkdir -p ${WDPATH}/MMPBSA/${LIG}_degron_gbind/topo
      echo "DONE"
   fi
    
   echo "Doing for $LIG"
   echo "Creating directories"
    
   mkdir -p ${WDPATH}/MMPBSA/${LIG}_degron_gbind/{topo,snapshots_rep1,snapshots_rep2,snapshots_rep3,snapshots_rep4,snapshots_rep5,"s${START}_${END}_${OFFSET}"/${METHOD}/{rep1,rep2,rep3,rep4,rep5}}
     
# Obtain correct topologies of degron and receptor.
   # Obtain degron as pdb from complex pdb. Complex pdb is obtained from setupMD, so it won't work
   # if setupMD folder is not prepared.
   echo "Now starting to create degron.pdb and receptor.pdb"
   echo "Creating degron.pdb"
      grep '8989' -A 232 ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb > ${TOPO_MMPBSA}/degron.pdb
   echo "Done creating degron.pdb!"
   
   echo "Creating receptor.pdb"
   # Obtain receptor.
   set +e
      diff ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb ${TOPO_MMPBSA}/degron.pdb | grep '^[<>]' | sed -E 's/(< |> )//g' > ${TOPO_MMPBSA}/receptor.pdb
   echo "Done creating receptor.pdb!"
   set -e
   # Obtain topologies of com, rec and degron

      # We need to load auxin and ihp lib files, and we obtain this from MD folder.
      # This script won't work if MD folder don't exist and lib files don't exist.
      LIGAND_LIB=${WDPATH}/MD/${LIG}/lib #lib file of auxin
      COFACTOR_LIB=${WDPATH}/MD/cofactor_lib #lib file of cofactor

      # TLEaP script to finally obtain topologies.
      cp ${SCRIPT_PATH}/degron_mmpbsa_files/leap_topo_${METHOD}.in ${TOPO_MMPBSA}
      sed -i "s+LIGAND_LIB_PATH+${LIGAND_LIB}+g" ${TOPO_MMPBSA}/leap_topo_${METHOD}.in
      sed -i "s+COFACTOR_LIB_PATH+${COFACTOR_LIB}+g" ${TOPO_MMPBSA}/leap_topo_${METHOD}.in
      sed -i "s+LIGND+${LIG}+g" ${TOPO_MMPBSA}/leap_topo_${METHOD}.in
      sed -i "s+COF+${COFACTOR}+g" ${TOPO_MMPBSA}/leap_topo_${METHOD}.in

      sed -i "s+TOPO_PATH+${TOPO_MMPBSA}+g" ${TOPO_MMPBSA}/leap_topo_${METHOD}.in
      sed -i "s+TOPO_MD+${TOPO_MD}+g" ${TOPO_MMPBSA}/leap_topo_${METHOD}.in

      
      ${AMBERHOME}/bin/tleap -f ${TOPO_MMPBSA}/leap_topo_${METHOD}.in

   TOTAL_ATOM_UNSOLVATED=$(cat ${WDPATH}/MD/${LIG}/topo/${LIG}_com.pdb | tail -n 3 | grep 'ATOM' | awk '{print $2}')
   
   FIRST_ATOM_LIG="8989"
   LAST_ATOM_LIG="9220"
   
   LAST_ATOM_REC=${TOTAL_ATOM_UNSOLVATED}
        
   for i in 1 2 3 4 5 	
      do
      echo "Doing for ${LIG} repetition ${i}"
      # MD
      MD_coords=${WDPATH}/MD/${LIG}/setupMD/rep${i}/prod
      
      if test -f ${MD_coords}/${LIG}_prod_noWAT_mmpbsa_degron.crd
      # Solvated coordinates -> unsolvated and specific snapshots for MMPBSA
      # i.e, from 3000 snapshots trajectory, we choose only 100. Then, we
      # will use mm_pbsa.pl to finally extract the snapshots used for MMPBSA.
      then
         echo "Correct coordinates available!"
      else
         echo "Correct coordinates not available!
   Going to extract coordinates starting at ${START}, ending at ${END} by offset ${OFFSET}"
         cp $SCRIPT_PATH/degron_mmpbsa_files/${extract_coordinates} $MD_coords
         cd $MD_coords 
         sed -i "s+TOPO_MD+${TOPO_MD}+g" $MD_coords/${extract_coordinates}
         sed -i "s+MD_coords+${MD_coords}+g" $MD_coords/${extract_coordinates}
         sed -i "s/START/${START}/g" $MD_coords/${extract_coordinates}
         sed -i "s/END/${END}/g" $MD_coords/${extract_coordinates}
         sed -i "s/OFFSET/${OFFSET}/g" $MD_coords/${extract_coordinates}
         sed -i "s/LIG/${LIG}/g" $MD_coords/${extract_coordinates}
         
         ${AMBERHOME}/bin/cpptraj -i $MD_coords/${extract_coordinates}
         
      fi

      SNAP="${WDPATH}/MMPBSA/${LIG}_degron_gbind/snapshots_rep${i}/"
      cp $SCRIPT_PATH/degron_mmpbsa_files/$extract_snapshots $SNAP
      sed -i "s+TOPO+${TOPO_MMPBSA}+g" $SNAP/$extract_snapshots
      sed -i "s/REP/${i}/g" $SNAP/$extract_snapshots
      sed -i "s/LIGND/${LIG}/g" $SNAP/$extract_snapshots
      sed -i "s/TOTAL_ATOM/${TOTAL_ATOM_UNSOLVATED}/g" $SNAP/$extract_snapshots
      sed -i "s/LAST_ATOM_REC/${LAST_ATOM_REC}/g" $SNAP/$extract_snapshots
      sed -i "s/FIRST_ATOM_LIG/${FIRST_ATOM_LIG}/g" $SNAP/$extract_snapshots
      sed -i "s/LAST_ATOM_LIG/${LAST_ATOM_LIG}/g" $SNAP/$extract_snapshots
      sed -i "s+MDCOORDS+${MD_coords}+g" $SNAP/$extract_snapshots
      
      cd ${SNAP}
      echo "Extracting snapshots from ${MD_coords}/${LIG}_prod_noWAT_mmpbsa_degron.crd"
      $AMBERHOME/bin/mm_pbsa.pl ${SNAP}/${extract_snapshots} > ${SNAP}/extract_coordinates_com.log
      echo "Done!"   
      cd ${WDPATH}
      
      MMPBSA="${WDPATH}/MMPBSA/${LIG}_degron_gbind/"s${START}_${END}_${OFFSET}"/${METHOD}/rep${i}/"
      cp "$SCRIPT_PATH/degron_mmpbsa_files/run_mmpbsa_lig.sh" $MMPBSA
      sed -i "s/LIG/${LIG}/g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s/repN/rep${i}/g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s/MMPBSA_IN/mmpbsa.in/g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s+MMPBSA_TOPO+~/2p1q/MMPBSA/${LIG}_degron_gbind/topo+g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s+MMPBSA_SNAPS+~/2p1q/MMPBSA/${LIG}_degron_gbind/snapshots_rep${i}+g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s+MMPBSA_PATH+~/2p1q/MMPBSA/${LIG}_degron_gbind/s1_3000_30/pb3_gb0/rep${i}/+g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s/METHOD/${METHOD}/g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s+MMPBSA_TMP_PATH+~/2p1q/MMPBSA/tmp/+g" "$MMPBSA/run_mmpbsa_lig.sh"
      
      cp "$SCRIPT_PATH/degron_mmpbsa_file/run_mmpbsa_slurm.sh" $MMPBSA
      sed -i "s/LIG/${LIG}/g" "$MMPBSA/run_mmpbsa_slurm.sh"
      sed -i "s/repN/rep${i}/g" "$MMPBSA/run_mmpbsa_slurm.sh"
      sed -i "s/REP/${i}/g" "$MMPBSA/run_mmpbsa_slurm.sh"
      
      cp "$SCRIPT_PATH/degron_mmpbsa_file/mmpbsa_in" $MMPBSA
      sed -i "s/LIGND/${LIG}/g" $MMPBSA/${mmpbsa_in}
      sed -i "s/REP/${i}/g" $MMPBSA/${mmpbsa_in}
      sed -i "s+SNAP_PATH+${SNAP}+g" $MMPBSA/${mmpbsa_in}
      sed -i "s+TOPO+${TOPO_MD}+g" $MMPBSA/${mmpbsa_in}

      done
done
echo "DONE!"

