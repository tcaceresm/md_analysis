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

   echo "Syntax: bash parse_mmpbsa_output.sh [-h|d]"
   echo "Options:"
   echo "h     Print help."
   echo "d     Working Directory."
   echo "s     Snapshots used from MD. Example: s1_3000_30"
   echo "m     Method used in MMPBSA. Example: pb4_gb1"
   echo "p     Degron MMPBSA. 0 no 1 yes"
   echo "f     Decomposition scheme? 0 no 1 yes"
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hd:s:m:p:f:" option; do
   case $option in
      h) # Print this help
         Help
         exit;;
      d) # Enter the MD Directory
         WDPATH=$OPTARG;;
         
      s) # Snapshots. Example:s1_3000_30
         SNAPSHOTS=$OPTARG;;
      
      m) # Method. Example: pb4_gb1
         METHOD=$OPTARG;;
      p) # Degron?
         DEGRON=$OPTARG;;
      f) # Decomp?
         DECOMP=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

WDPATH=$(realpath $WDPATH) #Working directory


# Analyzed ligands
declare -a LIGANDS_MOL2=($(ls $WDPATH/ligands/))
declare -a LIGANDS=($(sed "s/.mol2//g" <<< "${LIGANDS_MOL2[*]}"))
for i in 1 2 3 4 5
    do
        for LIG in "${LIGANDS[@]}"
    	do
    	    echo "DOING FOR ${LIG}${i}"
    	    if [ "$DEGRON" -eq 1 ]
    	    then
                OUT="${WDPATH}/MMPBSA/${LIG}_degron_gbind/${SNAPSHOTS}/${METHOD}/rep${i}/"   	
    	    else    	
                OUT="${WDPATH}/MMPBSA/${LIG}_gbind/${SNAPSHOTS}/${METHOD}/rep${i}/"
        
    	    fi
            if [ "$DECOMP" -eq 1 ]
            then  	
		grep -i 'delta' ${OUT}/${LIG}_statistics_decomp.out -A9999 | grep -iv 'delta' | grep -iv 'number' > ${OUT}/${LIG}_statistics_parsed.out || continue
	    else
	    
	    if [ "$DEGRON" -eq 1 ]
	    then
	        grep -i 'delta' ${OUT}/${LIG}_degron${i}_statistics.out.snap -A9999 | grep -iv 'delta' | grep -iv 'number' > ${OUT}/${LIG}_statistics_snap_parsed.out || continue
	    
	    else
		grep -i 'delta' ${OUT}/${LIG}_statistics.out.snap -A9999 | grep -iv 'delta' | grep -iv 'number' > ${OUT}/${LIG}_statistics_snap_parsed.out || continue
	    fi
	    fi
    	done
    done
