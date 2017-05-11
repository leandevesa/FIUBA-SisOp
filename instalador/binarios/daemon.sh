#!/bin/bash

set -e

ARCHIVO_LOG="../libs/log.sh"

directorioNovedades=$DIRNOV/
directorioAceptados=$DIROK/
directorioRechazados=$DIRREC/

contadorCiclos=0

print()
{
    # muestra un mensaje obtenido en $1 por STDOUT

    mensaje=$1
    $ARCHIVO_LOG "Daemon" "Info" "$mensaje"
    echo $mensaje
}

error()
{
    # muestra un mensaje obtenido en $1 por STDOUT

    mensaje=$1
    $ARCHIVO_LOG "Daemon" "Error" "$mensaje"
    echo $mensaje
}

validarArchivo(){
	
	extensionArchivo=`echo $1 | sed "s-[^.]*\.\(.*\)-\1-"`
	nombreArchivo=`echo $1 | sed "s-\([^.]*\)\.\(.*\)-\1-"`

	print "Ciclo Numero: $contadorCiclos . Archivo $nombreArchivo leido"

	directorioDestino=$directorioAceptados
	#si el archivo esta vacio lo rechazo directamente
	if [ ! -s "$directorioNovedades$1" ]; then
		print "Archivo $nombreArchivo rechazado: El archivo esta vacio"
		directorioDestino=$directorioRechazados
	fi

	if [ -f "$directorioDestino$1" ]; then
		#si el archivo existe lo renombra y luego lo mueve con el nuevo nombre.
		print "Archivo $nombreArchivo con el mismo nombre, renombrando archivo..."
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
		verificarArchivosNuevos
	fi
}

trap "eval continuar=1" SIGINT SIGTERM

print "Daemon iniciado OK"

continuar=0
while [ $continuar -eq 0 ]; do
    # TODO: agregar las tareas del daemon
	contadorCiclos=$((contadorCiclos + 1))
    verificarDirectorio
    sleep 1
done