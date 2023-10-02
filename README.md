# md_analysis
Scripts used to setup, run and analyze MD.
# setupMD
This script is used to create folder structure and configure input files. Below there is an example of folder structure created with setupMD script.
```bash
ID/
└── MD
    ├── cofactor_lib
    ├── iaa
    │   ├── lib
    │   ├── setupMD
    │   │   ├── rep1
    │   │   │   ├── equi
    │   │   │   └── prod
    │   │   ├── rep2
    │   │   │   ├── equi
    │   │   │   └── prod
    │   │   ├── rep3
    │   │   │   ├── equi
    │   │   │   └── prod
    │   │   ├── rep4
    │   │   │   ├── equi
    │   │   │   └── prod
    │   │   └── rep5
    │   │       ├── equi
    │   │       └── prod
    │   └── topo
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
└── iaa.mol2
receptor/
└── 2p1q_receptor.pdb
```


