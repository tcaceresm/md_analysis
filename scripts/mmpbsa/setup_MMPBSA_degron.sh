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

   echo "Syntax: bash setup_MMPBSA.sh [-h|d|s|e|o|m|i]"
   echo "To save a log file and also print the status, run: bash setup_MMPBSA.sh -d \$DIRECTORY | tee -a \$LOGFILE"
   echo "Options:"
   echo "h     Print help."
   echo "d     Working Directory."
   echo "s     START frame."
   echo "e     END frame."
   echo "o     OFFSET".
   echo "m     Method. Use alias used in FEW. Check AMBER23 manual page 880. Example: pb3_gb0"
   echo "r     PBRadii used. This must match with correct parameters of mmpbsa.in. Example: parse, mbondi"
   echo "l     Extract snapshots from prepared production trajectories? 0|1"
   echo "w     Use explicit waters in MMPBSA calculations. 0|1"
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:s:e:o:m:r:w:l:" option; do
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

# Script location
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Working directory path
WDPATH=$(realpath $WDPATH) 

# Analyzed ligands
declare -a LIGANDS_MOL2=($(ls $WDPATH/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))

# cofactor
declare -a COFACTOR_MOL2=($(ls $WDPATH/cofactor/))
declare -a COFACTOR=($(sed "s/.mol2//g" <<< "${COFACTOR_MOL2[*]}"))

#extract_coordinates="extract_coordinates_prod_for_mmpbsa_degron"
#extract_snapshots="extract_snapshots.in"
#leap_topo="leap_topo.in"

##############################

for LIG in "${LIGANDS[@]}"
   do
    
   # Degron as ligand requires new topologies, so we can't use same topologies
   # from setupMD folder. 
   
   TOPO_MD="${WDPATH}/MD/${LIG}/topo"
    
   echo "Doing for $LIG"
   echo "Creating directories"
   
   # Creation of directories. To Do: Create only if not exists.
   if [[ $WATERS -eq 0 ]]
   then
      MMPBSA_FOLDER='MMPBSA'

   else
      MMPBSA_FOLDER='MMPBSA_withWAT'
   fi
   
   mkdir -p ${WDPATH}/${MMPBSA_FOLDER}/${LIG}_degron_gbind/{topo,snapshots_rep1,snapshots_rep2,snapshots_rep3,snapshots_rep4,snapshots_rep5,"s${START}_${END}_${OFFSET}"/${METHOD}/{rep1,rep2,rep3,rep4,rep5}}
   TOPO_MMPBSA=${WDPATH}/${MMPBSA_FOLDER}/${LIG}_degron_gbind/topo/ 


# Obtain correct topologies of degron and receptor.
   # Obtain degron as pdb from complex pdb. Complex pdb is obtained from setupMD, so it won't work
   # if setupMD folder is not prepared.
   echo "Now starting to create degron.pdb and receptor.pdb from complex.pdb from setupMD"
   echo "Creating degron.pdb. Assuming that Degron starts at Atom 8989 of complex pdb, and is 232 atoms long"
      grep '8989' -A 232 ${TOPO_MD}/${LIG}_com.pdb > ${TOPO_MMPBSA}/degron.pdb
   echo "Done creating degron.pdb!"
   
   echo "Creating receptor.pdb"
   # Obtain receptor. It may contain waters
   # Idea: The receptor is the difference between degron and complex.
   set +e
   if [[ $WATERS -eq 0 ]] #It means that we don't want any waters. So
                          # the topologies created in the next step wont contain waters.
   then
      diff ${TOPO_MD}/${LIG}_com.pdb ${TOPO_MMPBSA}/degron.pdb | grep '^[<>]' | sed -E 's/(< |> )//g' | grep -v 'WAT' > ${TOPO_MMPBSA}/receptor.pdb
   else
      diff ${TOPO_MD}/${LIG}_com.pdb ${TOPO_MMPBSA}/degron.pdb | grep '^[<>]' | sed -E 's/(< |> )//g' > ${TOPO_MMPBSA}/receptor.pdb
   fi
   echo "Done creating receptor.pdb!"
   set -e

   # Obtain topologies of com, rec and degron.

      # We need to load auxin and ihp lib files, and we obtain this from MD folder.
      # This script won't work if MD folder don't exist and lib files don't exist.
      LIGAND_LIB=${WDPATH}/MD/${LIG}/lib #lib file of auxin
      COFACTOR_LIB=${WDPATH}/MD/cofactor_lib #lib file of cofactor

      leap_topo="leap_topo.in"
      # TLEaP script to finally obtain topologies.
      # leap_topo.in is used to create new topologies of ligand (degron), and receptor (TIR1 + auxin)
      echo "Preparing ${leap_topo} file"
      cp ${SCRIPT_PATH}/degron_mmpbsa_files/${leap_topo} ${TOPO_MMPBSA}
      sed -i "s+LIGAND_LIB_PATH+${LIGAND_LIB}+g" ${TOPO_MMPBSA}/${leap_topo}
      sed -i "s+COFACTOR_LIB_PATH+${COFACTOR_LIB}+g" ${TOPO_MMPBSA}/${leap_topo}
      sed -i "s+LIGND+${LIG}+g" ${TOPO_MMPBSA}/${leap_topo}
      sed -i "s+COF+${COFACTOR}+g" ${TOPO_MMPBSA}/${leap_topo}
      sed -i "s/PBRADII/${PBRadii}/g" ${TOPO_MMPBSA}/${leap_topo}
      sed -i "s+TOPO_MMPBSA+${TOPO_MMPBSA}+g" ${TOPO_MMPBSA}/${leap_topo}
      #sed -i "s+TOPO_MD+${TOPO_MD}+g" ${TOPO_MMPBSA}/${leap_topo}

      echo "Creating topologies"
      cd ${TOPO_MMPBSA}
      ${AMBERHOME}/bin/tleap -f ${TOPO_MMPBSA}/${leap_topo}
      cd ${WDPATH}
      echo "Done!"
      
   # Prepare MMPBSA coordinates extraction and snapshots extraction
    #Coordinate extraction refer to create a subset (or the complete set) of coordinates
    #from solvated MD trajectories. For example, if we have 3000 frames of solvated MD (prod.mdcrd) and we
    # will analyze only 100 frames, we process prod.mdcrd to only have 100 frames of UNSOLVATED prod.mdcrd.
    # If we let mm_pbsa.pl use solvated trajectories, it's too slow. That's why I process solvated prod.mdcrd
    # before with cpptraj, removing waters.
    # Then, we will extract snapshots with mm_pbsa.pl of this 100 frames unsolvated prod.mdcrd.
   
   #TIR1 luego IHP luego Aux luego Degron y luego agua en caso de tener.

   TOTAL_ATOM_UNSOLVATED=$(cat ${TOPO_MMPBSA}/${LIG}_com.pdb | grep -v 'TER\|END' | tail -n 1  | grep 'ATOM' | awk '{print $2}')
   echo "Total Atoms in unsolvated complex is ${TOTAL_ATOM_UNSOLVATED}"
      
   LAST_ATOM_AUX=$(cat ${TOPO_MMPBSA}/${LIG}_com.pdb | grep 'LIG' | tail -n 1  | awk '{print $2}')


   if [[ $WATERS -eq 1 ]]
   then
      extract_coordinates="extract_coordinates_prod_for_mmpbsa_degron_withWAT"
      extract_snapshots="extract_snapshots_withWAT.in"
      #LIG is degron
      FIRST_ATOM_LIG=$(($LAST_ATOM_AUX + 1))
      LAST_ATOM_LIG=$(($FIRST_ATOM_LIG + 231))

      RSTART_1=1
      RSTOP_1=${LAST_ATOM_AUX}
      RSTART_2=$(($LAST_ATOM_LIG + 1))
      RSTOP_2=${TOTAL_ATOM_UNSOLVATED}
      echo "Asumming RSTART1 is ${RSTART_1}"
      echo "Asumming RSTOP1 is ${RSTOP_1}"
      
      echo "Assuming first atom of degron in complex is ${FIRST_ATOM_LIG}"
      echo "Assuming last atom of degron in complex is ${LAST_ATOM_LIG}"

      echo "Asumming RSTART2 is ${RSTART_2}"
      echo "Asumming RSTOP2 is ${RSTOP_2}"
   else
      extract_coordinates="extract_coordinates_prod_for_mmpbsa_degron"
      extract_snapshots="extract_snapshots.in"
      FIRST_ATOM_LIG=$(($LAST_ATOM_AUX + 1))
      LAST_ATOM_LIG=$(($FIRST_ATOM_LIG + 231))

      RSTART_1=1
      RSTOP_1=${LAST_ATOM_AUX}      
      
      echo "Asumming RSTART1 is ${RSTART_1}"
      echo "Asumming RSTOP1 is ${RSTOP_1}"

      echo "Assuming first atom of degron in complex is ${FIRST_ATOM_LIG}"
      echo "Assuming last atom of degron in complex is ${LAST_ATOM_LIG}"

   fi

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
         sed -i "s/TOTAL_ATOM/${TOTAL_ATOM_UNSOLVATED}/g" $MD_coords/${extract_coordinates}
         
         ${AMBERHOME}/bin/cpptraj -i $MD_coords/${extract_coordinates}
         
      fi

      # Snapshot extraction of prepared production coordinates.
      SNAP="${WDPATH}/${MMPBSA_FOLDER}/${LIG}_degron_gbind/snapshots_rep${i}/"
      if [[ $EXTRACT_SNAP -eq 1 ]]
      then
         echo "Preparing ${extract_snapshots} file"
         cp $SCRIPT_PATH/degron_mmpbsa_files/$extract_snapshots $SNAP
         sed -i "s+TOPO+${TOPO_MMPBSA}+g" $SNAP/$extract_snapshots
         sed -i "s/REP/${i}/g" $SNAP/$extract_snapshots
         sed -i "s/LIGND/${LIG}/g" $SNAP/$extract_snapshots
         sed -i "s/TOTAL_ATOM/${TOTAL_ATOM_UNSOLVATED}/g" $SNAP/$extract_snapshots
         sed -i "s/RSTART_1/${RSTART_1}/g" $SNAP/$extract_snapshots
         sed -i "s/RSTOP_1/${RSTOP_1}/g" $SNAP/$extract_snapshots
         if [[ $WATERS -eq 1 ]]
            then
            sed -i "s/RSTART_2/${RSTART_2}/g" $SNAP/$extract_snapshots
            sed -i "s/RSTOP_2/${RSTOP_2}/g" $SNAP/$extract_snapshots
            fi
         sed -i "s/FIRST_ATOM_LIG/${FIRST_ATOM_LIG}/g" $SNAP/$extract_snapshots
         sed -i "s/LAST_ATOM_LIG/${LAST_ATOM_LIG}/g" $SNAP/$extract_snapshots
         sed -i "s+MDCOORDS+${MD_coords}+g" $SNAP/$extract_snapshots
         
         cd ${SNAP}
         echo "Extracting snapshots from ${MD_coords}/${LIG}_prod_noWAT_mmpbsa_degron.crd"
         $AMBERHOME/bin/mm_pbsa.pl ${SNAP}/${extract_snapshots} > ${SNAP}/extract_snapshots.log
         echo "Done!"   
         cd ${WDPATH}
      else
      echo "Not extracting snapshots"
      fi
      
      # MMPBSA folder of ligand
      if [[ $WATERS -eq 0 ]]
      then
         mmpbsa_in="mmpbsa_${METHOD}.in"
      else
         mmpbsa_in="mmpbsa_${METHOD}_withWAT.in"
      fi

      MMPBSA="${WDPATH}/${MMPBSA_FOLDER}/${LIG}_degron_gbind/"s${START}_${END}_${OFFSET}"/${METHOD}/rep${i}/"

      # Prepare MMPBSA.in file
      cp "$SCRIPT_PATH/degron_mmpbsa_files/${mmpbsa_in}" $MMPBSA
      sed -i "s/LIGND/${LIG}/g" $MMPBSA/${mmpbsa_in}
      sed -i "s/REP/${i}/g" $MMPBSA/${mmpbsa_in}
      sed -i "s+SNAP_PATH+${SNAP}+g" $MMPBSA/${mmpbsa_in}
      sed -i "s+TOPO+${TOPO_MD}+g" $MMPBSA/${mmpbsa_in}
      sed -i "s/PBRADII/${PBRadii}/g" $MMPBSA/${mmpbsa_in}


      # Prepare run_mmpbsa_lig.sh file, to run in NLHPC cluster
      cp "$SCRIPT_PATH/degron_mmpbsa_files/run_mmpbsa_lig.sh" $MMPBSA
      sed -i "s/LIG/${LIG}/g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s/repN/rep${i}/g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s/MMPBSA_IN/${mmpbsa_in}/g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s+MMPBSA_TOPO+~/2p1q/MMPBSA/${LIG}_degron_gbind/topo+g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s+MMPBSA_SNAPS+~/2p1q/MMPBSA/${LIG}_degron_gbind/snapshots_rep${i}+g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s+MMPBSA_PATH+~/2p1q/MMPBSA/${LIG}_degron_gbind/s${START}_${END}_${OFFSET}/${METHOD}/rep${i}/+g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s/METHOD/${METHOD}/g" "$MMPBSA/run_mmpbsa_lig.sh"
      sed -i "s+MMPBSA_TMP_PATH+~/2p1q/MMPBSA/tmp_degron/+g" "$MMPBSA/run_mmpbsa_lig.sh"
      
      # Prepare run_ppbsa_slurm.sh file, to run in NLHPC cluster
      cp "$SCRIPT_PATH/degron_mmpbsa_files/run_mmpbsa_slurm.sh" $MMPBSA
      sed -i "s/LIG/${LIG}/g" "$MMPBSA/run_mmpbsa_slurm.sh"
      sed -i "s/repN/rep${i}/g" "$MMPBSA/run_mmpbsa_slurm.sh"
      sed -i "s/REP/${i}/g" "$MMPBSA/run_mmpbsa_slurm.sh"
      
      done
done
echo "DONE!"

