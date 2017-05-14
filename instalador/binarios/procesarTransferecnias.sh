#!/bin/bash

set -e

calcularMontoTotal(){
	lista=`cat "$DIROK/$archivo" | sed -e 1'd'  | sed "s/^[^;]*;\([^;]*\);.*/\1/"`

	#convierto los numeros en en formato decimal correcto
	# reemplazo la coma por un punto para poder realizar las cuentas.
	listaImportes=`echo $lista | sed "s/^\([^,]*\),\(.*\)/\1.\2/"`

	total=0
	for importe in listaImportes ; do
		total=$(echo $total + $importe | bc)
	done
	echo $total
}

validarImportesSegunEstado(){
	archivo=$1
	
	Estados="Pendiente Anulada"
	#signo mayor a cero para pendiente
	signo="-gt"
	for estado in $estado do
		listaImportes=`cat "$DIROK/$archivo" | sed -e 1'd' | grep "^.*;.*;$estado.*" | cut -d';' -f2`
		for importe in $listaImportes; do
			if ! [ $importe $signo 0 ]; then
				return 1
			fi
		done
		signo="-lt"
	done
	return 0
}

validarCampos(){
	archivo=$1
	
	cantidadDeRegistros=`sed -e 1'!d' $directorioNovedades/trans.txt | sed "s/^\([^;]*\);.*/\1/"` 
	montoTotalCabecera=`cat "$DIROK/$archivo" | sed 1'!d'  | sed "s/^[^;]*;//"`

	cantidadDeRegistrosReal=`cat "$DIROK/$archivo" | sed -e 1'd' | wc -l`

	if [ ! $cantidadDeRegistros -eq $cantidadDeRegistrosReal ]; then
		echo rechazar
		return
	fi

	montoTotal=`calcularMontoTotal $archivo`

	if [ ! $montoTotal -eq $montoTotalCabecera ]; then
		echo rechazar
		return
	fi

	if ! validarImportesSegunEstado $archivo ; then
		echo rechazar
		return
	fi

}

verificarEstructura(){
	archivo=$1
	#el registro de cabecera tiene este formato numero;numero
	cabecera=`cat "$DIROK/$archivo" | sed 1'!d' | grep "^.*;.*$"`
	cantidadDeRegistros=`cat "$DIROK/$archivo" | sed 1'd' | wc -c`
	cantidadConEstructuraValida=`cat "$DIROK/$archivo" | sed 1'd' | grep "^.*;.*;.*;.*;.*$" | wc -l`
	if [[ ! -z $cabecera  &&  $cantidadDeRegistros -eq $cantidadConEstructuraValida ]]; then
		#verifico los siguientes campos que son 5 campos
		#separados por punto y coma
		validarCampos $archivo
	else
		echo rechazar
	fi
}

procesarArchivos(){
	#por si hay archivos con espacios configuro el IFS
	#IFS=$'\n'
	archivos=`ls "$DIROK"`

	for archivo in $archivos ; do 
		verificarEstructura "$archivo"
	done
}


procesarArchivos