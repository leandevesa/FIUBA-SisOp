#!/bin/bash

. ../libs/config.sh

directorioNovedades=`config_get ../dirconf/instalador.conf NOVEDADES`/
directorioAceptados=`config_get ../dirconf/instalador.conf ACEPTADOS`/
directorioRechazados=`config_get ../dirconf/instalador.conf RECHAZADOS`/

#directorioNovedades="/home/nicolas/Escritorio/novedades/"
#directorioAceptados="/home/nicolas/Escritorio/aceptados/"
#directorioRechazados="/home/nicolas/Escritorio/rechazados/"

validarArchivo(){
	
	directorioDestino=$directorioAceptados
	#si el archivo esta vacio lo rechazo directamente
	if [ ! -s "$directorioNovedades$1" ]; then
		echo "Archivo rechazado: El archivo esta vacio"
		directorioDestino=$directorioRechazados
	fi

	if [ -f "$directorioDestino$1" ]; then
		#si el archivo existe lo renombra y luego lo mueve con el nuevo nombre.
		echo "Archivo con el mismo nombre..."
		echo "Renombrando archivo..."
		extensionArchivo=`echo $1 | sed "s-[^.]*\.\(.*\)-\1-"`
		nombreArchivo=`echo $1 | sed "s-\([^.]*\)\.\(.*\)-\1-"`
		echo "$nombreArchivo"
		mv "$directorioNovedades$1" "$directorioNovedades$nombreArchivo(copia).$extensionArchivo"
	else	
		mv "$directorioNovedades$1" "$directorioDestino$1"
	fi
}

verificarArchivosNuevos(){
	archivos=`ls "$directorioNovedades"`

	for archivo in $archivos ; do 
		validarArchivo "$archivo"
	done
}

verificarDirectorio(){
	cantidadDeArhivos=`ls "$directorioNovedades" | wc -l`

	if [ $cantidadDeArhivos -ne 0 ]; then
		echo "Se encontro un nuevo archivo..."
		verificarArchivosNuevos
	fi
}

trap "eval continuar=1" SIGINT SIGTERM

continuar=0

contadorCiclos=0
while [ $continuar -eq 0 ]; do
    # TODO: agregar las tareas del daemon
    verificarDirectorio
    sleep 1
done

