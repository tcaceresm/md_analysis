Aquí se encuentran los scripts para procesar las trajectorias de las simulaciones de dinámica molecular.
1. Procesamiento de topologias:
Existe la chance de que FEW se equivoque, y las estructuras en vacio (*vac*) aun contengan aguas. 
Para remover el agua de esas estructuras es que existe este procesamiento
2. Eliminación de Aguas
Para visualizar las trajectorias, y calcular el RMSD, se requieren trajectorias sin aguas.
en estricto rigor, podria ocupar las trajectorias con agua, pero ocupan mucho espacio, por
lo que prefiero procesar las trajectorias solvatadas y quedarme solo con las trajectorias sin aguas
3. Calculo de RMSD, RMSF, etc

