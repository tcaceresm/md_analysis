#/usr/bin/sh

#Script para copiar archivos relevantes desde el almacenamiento Backup1 al almacenamiento principal
#Esto para no ocupar mucho espacio en el almacenamiento principal

DINAMICA='/home/tcaceres/Documents/tecnicas_avanzadas/dinamica_molecular/tir1'

for dir in */
do
	echo "$dir"
	find $dir -name *prod_noWAT.crd* -type f -exec cp {} ${DINAMICA}/${dir}/protocolo_n5_10ns/MD_am1/ \;
	find $dir -name *vac_com_noWAT.top* -type f -exec cp {} ${DINAMICA}/${dir}/protocolo_n5_10ns/MD_am1/ \;
	find $dir -name plots -type d -exec cp -r {} ${DINAMICA}/${dir}/protocolo_n5_10ns/ \;
done
