# md_analysis
Scripts used to setup, run and analyze MD. This is not intended for all purposes. It's just an automation of my tasks: setup and run  5 repetitions molecular dynamics simulations of different ligands docked to only one receptor, containing one cofactor.
## setupMD.sh
The main goal is to have only essential files required to setup the molecular dynamics. There is a lot of software/workflows capable of doing this but I dont require that complexity (I used to use FEW workflow).
This script is used to create folder structure and configure input files. Also, it will calculate the charges (AM1-BCC) of ligands and cofactor, prepare frcmod, lib and topology files.
Obviously, you can change the input configurations files to meet your requirements.
### Usage
```bash
bash setupMD.sh -h # get help.
bash setupMD.sh -d working_directory 
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
│   │   │   ├── rep4
│   │   │   │   ├── equi
│   │   │   │   └── prod
│   │   │   └── rep5
│   │   │       ├── equi
│   │   │       └── prod
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
