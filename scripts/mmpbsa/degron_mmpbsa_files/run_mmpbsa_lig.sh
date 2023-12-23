#!/bin/bash

#SCRIPT=/home/tcaceres/calc_a_1t/LIG/s1_3000_30/pb3_gb0/run_mmpbsa.pbs
SY=LIG_degron
CALC=LIG_degron_repN_METHOD
PARAMS=MMPBSA_IN
TOPO=MMPBSA_TOPO
SNAPS=MMPBSA_SNAPS


#
WD_PATH=MMPBSA_PATH
cd $WD_PATH

#
# --- Create tmp directory
#
mkdir MMPBSA_TMP_PATH
cd MMPBSA_TMP_PATH
mkdir $CALC
cd $CALC
cp $WD_PATH/$PARAMS .
ln -s $TOPO topo
ln -s $SNAPS snapshots

#
# --- Execute
#
#MMPBSA=$AMBERHOME/bin/mm_pbsa.pl
perl /home/tcaceres/.conda/envs/ambertools22.5/bin/mm_pbsa.pl $PARAMS

#
# --- Zipping output
#
gzip -9 ${SY}*
cp ${SY}* $WD_PATH
#rm -r /home/tcaceres/afb5_noDegron/calc_a_1t/tmp/$CALC
gunzip $WD_PATH/${SY}_statistics.out

