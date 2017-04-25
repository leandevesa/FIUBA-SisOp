#!bin/bash


# "$1" es lugar de invocacion
# "$2" tipo de mensaje 
# "$3" mensaje
# Ejemplo de codigo para invocar al log:
# bash log.sh "Instalador" "INFORMATIVO O INF" "DEFINA EL DIRECTORIO..."
if ! [ -d "logCarpeta" ]
then
	mkdir "logCarpeta"
fi	

function log {
	lugar="$1"
	tipoMensaje="$2"  
	mensaje="$3"
	usuario=$(whoami)	
	fecha=$(date +%Y%m%d" "%H:%M:%S)


	echo "$fecha-$usuario-$lugar-$tipoMensaje-$mensaje" >> "logCarpeta/$lugar.log"
	
}
log "$1" "$2" "$3"


