#!/bin/bash

#SCRIPT=/home/tcaceres/LIG/s1_3000_30/pb3_gb0/run_mmpbsa.pbs
SY=LIG
CALC=LIG_pb3_gb0
PARAMS=mmpbsa.in
TOPO=/home/tcaceres/LIG/topo
SNAPS=/home/tcaceres/LIG/snapshots


#
WD_PATH=/home/tcaceres/LIG/s1_3000_30/pb3_gb0
cd $WD_PATH

#
# --- Create tmp directory
#
mkdir /home/tcaceres/tmp
cd /home/tcaceres/tmp
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
rm -r /home/tcaceres/tmp/$CALC
gunzip $WD_PATH/${SY}_statistics.out

