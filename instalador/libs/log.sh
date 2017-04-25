#!/bin/bash


# "$1" es lugar de invocacion
# "$2" tipo de mensaje 
# "$3" mensaje
# "$4" [OPCIONAL] Path absoluto donde se escribira
# Ejemplo de codigo para invocar al log:
# bash log.sh "Instalador" "INFORMATIVO O INF" "DEFINA EL DIRECTORIO..."

function log {
	lugar="$1"
	tipoMensaje="$2"  
	mensaje="$3"
	carpeta="$4"
	usuario=$(whoami)	
	fecha=$(date +%Y%m%d" "%H:%M:%S)


	echo "$fecha-$usuario-$lugar-$tipoMensaje-$mensaje" >> "$carpeta/$lugar.log"
	
}

logCarpeta=$4

if [ -z "$logCarpeta" ]
then
	logCarpeta="$DIRLOG"
fi

if ! [ -d "$logCarpeta" ]
then
	mkdir "$logCarpeta"
fi

log "$1" "$2" "$3" "$logCarpeta"


