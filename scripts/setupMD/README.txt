Aqui se encuentran los archivos necesarios para configurar las simulaciones de dinamica molecular.
1. input files para equi, prod
2. input files para preparar topologias
3. script principal

Los ligandos se espera QUE YA ESTÉN PREPARADOS (atom charges, atom types)
Se debe utilizar antechamber para preparar los ligandos.
En base a los ligandos preparados, se obtienen los archivos .lib y .frcmod
No lo autimaticé a propósito: uno debe chequear a mano los resultados de antechamber (que estén las cargas correctas, atom types).
Uno debe también revisar el output de frcmod.

Para el cofactor, se siguen los mismos pasos de preparación.


ToDO: Debo hacer un README más bonito para esto.
