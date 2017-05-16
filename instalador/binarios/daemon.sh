#!/bin/bash

set -e

ARCHIVO_LOG="../libs/log.sh"
ARCHIVO_PID_PROC="$DIRBIN/pid_proc"  # nombre del archivo donde se guarda el pid del daemon

directorioNovedades=$DIRNOV
directorioAceptados=$DIROK
directorioRechazados=$DIRREC
directorioMaestros=$DIRMAE

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
	if [ -z $1 ]; then
		return 1
	fi
	listaEntidades=`cat $directorioMaestros/bamae.txt | sed "s/^\([^;]*\).*/\1/"`

	for entidad in $listaEntidades ; do 
		if [ $entidad = $1 ]; then
			return 0
		fi
	done
	return 1
}

validarNombreArchivo(){
	nombreArchivo=$1

	entidad=`echo $nombreArchivo | sed "s/\([^_]*\)_\(.*\)/\1/"`
	fecha=`echo $nombreArchivo | sed "s/^[^_]*_//"`

	if ! validarEntidad $entidad; then
		error "archivo $nombreArchivo con entidad inexistente"
		return 1
	fi

	if ! validarFecha $fecha ; then
		error "archivo $nombreArchivo con fecha invalida"
		return 1
	fi
	return 0
}

validarArchivo(){
	
	extensionArchivo=`echo $1 | sed "s-[^.]*\.\(.*\)-\1-"`
	nombreArchivo=`echo $1 | sed "s-\([^.]*\)\.\(.*\)-\1-"`

	print "Ciclo Numero: $contadorCiclos . Archivo $1 leido"

	directorioDestino=$directorioAceptados

	if ! [ $extensionArchivo = "csv" ]; then
		print "error! archivo con extension invalida $1"
		directorioDestino=$directorioRechazados
	fi

	if ! validarNombreArchivo $nombreArchivo; then
		#print "error! archivo con nombre invalido $1"
		directorioDestino=$directorioRechazados
	fi

	#si el archivo esta vacio lo rechazo directamente
	if [ ! -s "$directorioNovedades/$1" ]; then
		print "error! archivo vacio $1"
		directorioDestino=$directorioRechazados
	fi

	if [ -f "$directorioDestino/$1" ]; then
		#ya existe un archivo en el destino con este nombre
		print "Archivo $1 duplicado en $directorioDestino."

		duplicados="duplicados"
		# si no existe /duplicados la creo
		if [ ! -d "$directorioDestino/$duplicados" ]; then
			mkdir "$directorioDestino/$duplicados"
		fi

		numeroDeCopia=0
		while [ -f "$directorioDestino/$duplicados/$nombreArchivo$numeroDeCopia.$extensionArchivo" ]; do
			numeroDeCopia=$((numeroDeCopia+1))
		done 
		mv "$directorioNovedades/$1" "$directorioDestino/$duplicados/$nombreArchivo$numeroDeCopia.$extensionArchivo"
	else	
		mv "$directorioNovedades/$1" "$directorioDestino/$1"
	fi
}

verificarArchivosNuevos(){
	#por si hay archivos con espacios configuro el IFS
	#para que no me los tome como archivos distintos.
	#me guardo el IFS original.
	_IFS="$IFS"
	IFS=$'\n'
	
	archivos=`ls "$directorioNovedades"`

	for archivo in $archivos ; do 
		validarArchivo "$archivo"
	done
	#restauro el IFS original.
	IFS=$_IFS
}

verificarDirectorioNovedades(){
	cantidadDeArhivos=`ls "$directorioNovedades" | wc -l`

	if [ $cantidadDeArhivos -ne 0 ]; then
		verificarArchivosNuevos
	fi
}

procesadorActivo(){
    if [ -f $ARCHIVO_PID_PROC ] ; then
        return 0
    else
        return 1
    fi
}
verificarDirectorioAceptados(){
	nombre=procesarTransferencias.sh
		
		# verifica si el procesador ya está corriendo
	    if procesadorActivo ; then
			print "El proceso ya se encuentra en ejecucion, invocacion propuesta para la siguiente iteracion"
			return
		fi

		script="$DIRBIN/$nombre"

	    set +e

	    # inicia el proceso en background
	    nohup $script &> /dev/null &
	    if [ ! $! ] ; then
	        error 'No se pudo inicializar el procesador'
	    else
	    	set -e

	    	# obtiene y guarda el process ID
	    	pid=$!
	    	echo $pid > $ARCHIVO_PID_PROC

	    	print "se inició el procesador con el pid $pid"
	    fi
	    set -e
	#fi
	#cantidadDeArhivos=`ls "$DIROK" | wc -l`
	#$DIRBIN/$nombre &
	#nombre=procesarTransferencias.sh
	#if ! [ -z `pidof -x $nombre` ]; then
		#log
	#	echo "El proceso ya se encuentra en ejecucion, invocacion propuesta para la siguiente iteracion"
	#	return
	#fi

	#if [ -f "$DIRBIN/$nombre" ]; then
		#log
	#	$DIRBIN/$nombre &
		#a veces anda a veces no. preguntar.
	#	echo "proceso procesarTransferencias.sh lanzado con pid" `pidof -x $DIRBIN/$nombre`
	#else
	#	echo "No se encuentra el ejecutable en $DIRBIN"
	#fi
	#return 0
}

#para probar, se sale el demonio despues de esto
ver(){
	pid=`pidof aaa`
	echo $pid
}

#trap "eval continuar=1" SIGINT SIGTERM

print "Daemon iniciado OK"

continuar=0
while [ $continuar -eq 0 ]; do
    # TODO: agregar las tareas del daemon
	contadorCiclos=$((contadorCiclos + 1))
	# faltaria grabarlo en el log
    verificarDirectorioNovedades

   	verificarDirectorioAceptados
    #ver
    sleep 1
done