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

validarFecha(){
	#si es vacia la fecha que me pasan rechazo.
	if [ -z $1 ]; then
		return 1
	fi

	#formato de fecha aaaammdd
	#debe ser menor o igual a la fecha del dia
	#y menor o igual a 15 dias de antiguedad.
	#anio aaaa
	anioActual=`date +%Y`
	#mes mm
	mesActual=`date +%m`
	#dia dd
	diaActual=`date +%d`

	anio=`echo $1 | sed "s/^\(....\).*/\1/"`
	mes=`echo $1 | sed "s/^....\(..\).*/\1/"`
	dia=`echo $1 | sed "s/^......//"`
	
	#me fijo que la fecha sea valida.
	date -d "$anio$mes$dia" > /dev/null 2>&1
	esValida=$?
	if [ $esValida -eq 1 ]; then 
		# es invalida
		return 1
	fi

	#comparo con la fecha de hoy
	dif=$(($(($(date "+%s") - $(date -d "$anio$mes$dia" "+%s"))) / 86400))
	if [ $dif -lt 0 ]; then 
		return 1
	fi
	#no tiene que tener mas de 15 dias de antiguedad.
	if [ $dif -gt 15 ]; then
		return 1
	fi
	return 0
}

validarEntidad(){
	#si es vacia la entidad que me pasan rechazo.
	echo entidad:
	echo $1
	if [ -z $1 ]; then
		return 1
	fi
	return 0
}

validarNombreArchivo(){
	nombreArchivo=$1

	entidad=`echo $nombreArchivo | sed "s/\([^_]*\)_\(.*\)/\1/"`
	fecha=`echo $nombreArchivo | sed "s/^[^_]*_//"`

	if validarEntidad $entidad && validarFecha $fecha; then
		return 0
	fi
	return 1
}

validarArchivo(){
	
	extensionArchivo=`echo $1 | sed "s-[^.]*\.\(.*\)-\1-"`
	nombreArchivo=`echo $1 | sed "s-\([^.]*\)\.\(.*\)-\1-"`

	print "Ciclo Numero: $contadorCiclos . Archivo $nombreArchivo leido"

	directorioDestino=$directorioAceptados

	if ! validarNombreArchivo $nombreArchivo; then
		echo "Archivo $nombreArchivo rechazado: nombre invalido"
		directorioDestino=$directorioRechazados
	fi

	#si el archivo esta vacio lo rechazo directamente
	if [ ! -s "$directorioNovedades$1" ]; then
		echo "Archivo $nombreArchivo rechazado: El archivo esta vacio"
		directorioDestino=$directorioRechazados
	fi

	if [ -f "$directorioDestino$1" ]; then
		#ya existe un archivo en el destino con este nombre
		duplicados="duplicados"
		# si no existe /duplicados la creo
		if [ ! -d "$directorioDestino$duplicados" ]; then
			mkdir "$directorioDestino$duplicados"
		fi

		numeroDeCopia=0
		while [ -f "$directorioDestino$duplicados/$nombreArchivo$numeroDeCopia.$extensionArchivo" ]; do
			numeroDeCopia=$((numeroDeCopia+1))
		done 
		mv "$directorioNovedades$1" "$directorioDestino$duplicados/$nombreArchivo$numeroDeCopia.$extensionArchivo"
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