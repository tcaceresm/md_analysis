#!/usr/bin/bash

ID="2p1q_noDegron2"
#Change to current file directory
WDPATH="/mnt/Backup1/${ID}/protocolo_n5_30ns/"

declare -a arr=("ben" "bma" "cfa" "cpoa" "cpya" "flu" "iaa" "iaaee" "ipa" "naa" "nta" "paa" "pic" "qui" "tri" "trp" )

N_RES='569'

for LIG in "${arr[@]}"
    do

for i in 1 2 3 4 5
    do
        echo "DOING FOR $LIG$i"
        
        leap_COM_pdb="${WDPATH}/leap/${LIG}${i}/${LIG}${i}_com.pdb"
    	leap_COM_noWAT_pdb="${WDPATH}/leap/${LIG}${i}/${LIG}${i}_com_noWAT.pdb"
        leap_REC_pdb="${WDPATH}/leap/${LIG}${i}/${LIG}${i}_rec.pdb"
        leap_REC_noWAT_pdb="${WDPATH}/leap/${LIG}${i}/${LIG}${i}_rec_noWAT.pdb"

    	MDam1_vac_com_pdb="${WDPATH}/MD_am1/${LIG}${i}/cryst/${LIG}${i}_vac_com.pdb"
    	MDam1_vac_com_noWAT_pdb="${WDPATH}/MD_am1/${LIG}${i}/cryst/${LIG}${i}_vac_com_noWAT.pdb"
    	leapScript="${WDPATH}/MD_am1/${LIG}${i}/cryst/leap_script_4.in" #ojo aqui
	MDam1_vac_rec_pdb="${WDPATH}/MD_am1/${LIG}${i}/cryst/${LIG}${i}_vac_rec.pdb"
	MDam1_vac_rec_noWAT_pdb="${WDPATH}/MD_am1/${LIG}${i}/cryst/${LIG}${i}_vac_rec_noWAT.pdb"

    	
    	echo "Checking the existence of $leap_COM_noWAT_pdb"
    	
        if test -f "$leap_COM_noWAT_pdb" 
            then
                echo "$leap_COM_noWAT_pdb exist"
                echo "CONTINUE"
            else
            	echo "$leap_COM_noWAT_pdb do not exist"
            	echo "Removing WAT from $leap_COM_pdb"
            	echo "Creating $leap_COM_noWAT_pdb file" 
            	grep -iv 'hoh' $leap_COM_pdb > $leap_COM_noWAT_pdb
            	echo "DONE"            
        fi
        
        if test -f "$leap_REC_noWAT_pdb" 
            then
                echo "$leap_REC_noWAT_pdb exist"
                echo "CONTINUE"
            else
                echo "$leap_REC_noWAT_pdb do not exist"
                echo "Removing WAT from $leap_REC_pdb"
                echo "Creating $leap_REC_noWAT_pdb file" 
                grep -iv 'hoh' $leap_REC_pdb > $leap_REC_noWAT_pdb
                echo "DONE"            
        fi
        
        echo "Checking the existence of $MDam1_vac_com_noWAT_pdb"
        if test -f "$MDam1_vac_com_noWAT_pdb"
            then
                echo "$MDam1_vac_com_noWAT_pdb exist"
                echo "CONTINUE"
            else
                echo "$MDam1_vac_com_noWAT_pdb Do not exist"
                echo "Checking the existence of $leapScript"
                     if test -f "$leapScript"
                         then

                             echo "Creating $MDam1_vac_rec_noWAT_pdb using TLEaP and $leap_COM_noWAT_pdb file"
                             /home/tcaceres/amber20/bin/tleap -f $leapScript 
                         else
                             echo "File not found"
                             echo "Check scripts/ folder"
                             exit 1
                     fi
         fi

        echo "Checking the existence of $MDam1_vac_rec_noWAT_pdb"
        if test -f "$MDam1_vac_rec_noWAT_pdb"
            then
                echo "$MDam1_vac_rec_noWAT_pdb exist"
                echo "CONTINUE"
            else
                echo "$MDam1_vac_rec_noWAT_pdb Do not exist"
                echo "Checking the existence of $leapScript"
                     if test -f "$leapScript"
                         then

                             echo "Creating $MDam1_vac_rec_noWAT_pdb using TLEaP and $leap_REC_noWAT_pdb file"
                             /home/tcaceres/amber20/bin/tleap -f $leapScript 
                         else
                             echo "File not found"
                             echo "Check scripts/ folder"
                             exit 1
                     fi
         fi


    done
done
