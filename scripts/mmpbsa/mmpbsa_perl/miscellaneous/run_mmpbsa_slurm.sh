#!/bin/bash
#---------------Script SBATCH - NLHPC ----------------
#SBATCH -J ID_LIG_mmpbsa
#SBATCH -p general
#SBATCH -n 20
#SBATCH -c 1
#SBATCH --ntasks-per-node=20
#SBATCH --mem-per-cpu=2000
#SBATCH --mail-user=caceres.tomas@uc.cl
#SBATCH --mail-type=ALL
#SBATCH -o mmpbsa_%j.out
#SBATCH -e mmpbsa_%j.err

#-----------------Toolchain---------------------------
ml purge
ml intel/2019b
ml fosscuda/2019b
# ----------------Modulos----------------------------
ml  Amber/20  
# ----------------Comando--------------------------
#/home/tcaceres/.conda/envs/ambertools22.5/bin/mm_pbsa.pl /home/tcaceres/LIG/s1_3000_30/pb3_gb0/mmpbsa.in
./run_mmpbsa_lig.sh


