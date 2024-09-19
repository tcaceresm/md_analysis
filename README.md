# md_analysis
Scripts used to setup, run and analyze molecular dynamics simulations using AMBER software.
## setupMD.sh
There are several softwares/workflows capable of automatically configuring input files to perform molecular dynamics simulations. Despite this, I wrote these scripts primarily to know in detail what happens under the hood.  

setupMD.sh script is used to create folder structure and to edit and copy the input files to their respective locations. Also, it will 
prepare* the receptor and ligands/cofactor. All template input files are locate in input_files folder.  

*To prepare the ligands it means to calculate the charges (for example, AM1-BCC partial charges), prepare frcmod, lib and topology files.
Obviously, you can change the input configurations files to meet your requirements.
### Usage
Usage is pretty easy. You can use -h flag to get help.
```bash
bash setupMD.sh -h # get help.
```
In order to succesfully run this script, move to your working directory and check the following:
- receptor folder: This folder must contain a single PDB file of the receptor.
- ligands folder: This folder must contain all ligands file in mol2 format.
- cofactor folder (optional): This folder should contain cofactor file in mol2 format.

Different flag used:
- -d (string) flag is to obtain the working path.
- -t (integer) flag is used to configure the production time in nanoseconds (assuming 2 fs timestep).
- -n (integer) flag is used to configure the different replicas of simulations. It will create a different folder for each replica, see later.
- -r (boolean, 0|1) flag is used if you want to configure the receptor. Sometimes your MD folder already contains the prepared receptor, and you only want to prepare new repetitions of the same system or add new ligands.
- -c (boolean, 0|1) flag is used to prepare the cofactor.

### Example 
Below there is an example of a working directory with the required receptor, ligand and cofactor files

```bash
WORKING_DIRECTORY_EXAMPLE/
├── cofactor
│   └── cofactor.mol2
├── ligands
│   └── ligand1.mol2
└── receptor
    └── receptor.pdb
```

Below there is an example of folder structure created with setupMD script.
```bash
ID
├── cofactor
├── ligands
├── MD
│   ├── LIG
│   │   ├── lib
│   │   ├── setupMD
│   │   │   ├── rep1
│   │   │   │   ├── equi
│   │   │   │   └── prod
│   │   │   ├── rep2
│   │   │   │   ├── equi
│   │   │   │   └── prod
│   │   │   ├── rep3
│   │   │   │   ├── equi
│   │   │   │   └── prod
│   │   └── topo
│   ├── cofactor_lib
│   └── receptor
└── receptor
```
All input files are based on input_files, ligands, receptor and cofactor folders.
```bash
cofactor/
└── cof.mol2
input_files/
├── equi
│   ├── md_npt_ntr.in
│   ├── md_nvt_ntr.in
│   ├── md_nvt_red_01.in
│   ├── md_nvt_red_02.in
│   ├── md_nvt_red_03.in
│   ├── md_nvt_red_04.in
│   ├── md_nvt_red_05.in
│   ├── md_nvt_red_06.in
│   ├── min_ntr_h.in
│   └── min_ntr_l.in
├── prod
│   └── md_prod.in
└── topo
    ├── leap_create_com.in
    ├── leap_lib.in
    ├── leap_topo_solv.in
    └── leap_topo_vac.in
ligands/
└── LIG.mol2
receptor/
└── receptor.pdb
```
## traj_proc.sh
This script is to remove water from coordinates, image, calculate RMSD and RMSF of all protein, ligand and binding site.
It's based on setup_MD folder structure.
### Usage
```bash

bash traj_proc.sh -h # get help
bash traj_proc.sh -d working_directory -e 1 -p 1 -r 1 # process equil and prod phase. Also, calculate RMSD/F
```
If you do not want to calculate, for example, RMSD and RMSF, you need to explicitly pass `-r 0`.
## 
