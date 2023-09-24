#!/bin/bash

#SCRIPT=/home/tcaceres/calc_a_1t/LIG/s1_3000_30/pb3_gb0/run_mmpbsa.pbs
SY=LIG
CALC=LIG_repN_pb3_gb0
PARAMS=mmpbsa.in
TOPO=/home/tcaceres/afb5_noDegron/calc_a_1t/LIG/topo
SNAPS=/home/tcaceres/afb5_noDegron/calc_a_1t/LIG/snapshots_repN


#
WD_PATH=/home/tcaceres/afb5_noDegron/calc_a_1t/LIG/s1_3000_30/pb3_gb0/repN
cd $WD_PATH

#
# --- Create tmp directory
#
mkdir /home/tcaceres/afb5_noDegron/calc_a_1t/tmp
cd /home/tcaceres/afb5_noDegron/calc_a_1t/tmp
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

