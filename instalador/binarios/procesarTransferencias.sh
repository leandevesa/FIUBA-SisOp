#!/bin/bash

DIROKPROCESADOS=$DIROK/proc
DIROKDUPLICADOS=$DIROK/duplicados
DIRRECDUPLICADOS=$DIRREC/duplicados
DIRTRANSFER=$DIRINFO/transfer

set -e

ARCHIVO_LOG="../libs/log.sh"

CANTDIGITOSCBU=22

print()
{
    # muestra un mensaje obtenido en $1 por STDOUT
    mensaje=$1
    $ARCHIVO_LOG "ProceasdorArchivo" "Info" "$mensaje"
    echo $mensaje
}

error()
{
    # muestra un mensaje obtenido en $1 por STDOUT
    mensaje=$1
    $ARCHIVO_LOG "ProceasdorArchivo" "Error" "$mensaje"
    echo $mensaje
}


verificarDirectorios(){
	if ! [ -d $DIROKPROCESADOS ]; then
		mkdir $DIROKPROCESADOS
	fi	
	if ! [ -d $DIROKDUPLICADOS ]; then
		mkdir $DIROKDUPLICADOS
	fi	
	if ! [ -d $DIRRECDUPLICADOS ]; then
		mkdir $DIRRECDUPLICADOS
	fi
	if ! [ -d $DIRTRANSFER ]; then
		mkdir $DIRTRANSFER
	fi
}

fueProcesado(){
	if [ -f "$DIROKPROCESADOS/$1" ]; then
		return 0
	fi
	return 1
}



moverArchivo(){
	origen=$1
	destino=$2

	if [ -f "$destino" ]; then
		#ya existe un archivo en el destino con este nombre
		
		nombreCompleto=`echo $destino | sed "s-^.*/--"`
		#print "Archivo $nombreCompleto duplicado en $destino."
		
		nombreArchivo=`echo $nombreCompleto | sed "s-\([^.]*\)\.\(.*\)-\1-"`
		extensionArchivo=`echo $nombreCompleto | sed "s-[^.]*\.\(.*\)-\1-"`
	    dirDestino=`echo $destino | sed "s-^\(.*/\).*-\1-"`

		duplicados="duplicados"
		dirDestDup=$dirDestino/$duplicados
		# si no existe /duplicados la creo
		if [ ! -d "$dirDestDup" ]; then
			mkdir "$dirDestDup"
		fi

		numeroDeCopia=0

		while [ -f "$dirDestDup/$nombreArchivo$numeroDeCopia.$extensionArchivo" ]; do
			numeroDeCopia=$((numeroDeCopia+1))
		done 
		mv "$origen" "$dirDestDup/$nombreArchivo$numeroDeCopia.$extensionArchivo"
	else
		mv "$origen" "$destino"
	fi
}

rechazarArchivo(){
	moverArchivo "$DIROK/$archivo" "$DIRREC/$archivo"
}

aceptarArchivo(){
	moverArchivo "$DIROK/$archivo" "$DIROKPROCESADOS/$archivo"
}

calcularMontoTotal(){
	lista=`cat "$DIROK/$1" | sed -e 1'd'  | sed "s/^[^;]*;\([^;]*\);.*/\1/"`
	total=0
	impconvert=0
	for importe in $lista ; do
		#le pongo un punto en vez de coma.
		impconvert=`echo $importe | sed "s/,/./g"`
		total=$(echo $total + $impconvert | bc)
	done
	echo $total
}

# separar en dos esta funcion, quedo muy cargada.
# validar los estados primero y luego los importes.
validarImportesSegunEstado(){
	archivo=$1
	
	#estados="Pendiente Anulada"
	
	estados=(Pendiente Anulada)
	registrosTotalesLeidos=0
	#signo mayor a cero para pendiente
	signo=">"
	for estado in "${estados[@]}" ; do
		listaImportes=`cat "$DIROK/$archivo" | sed -e 1'd' | grep "^.*;.*;${estado}.*" | cut -d';' -f2 | sed "s/,.*//g"`	
		#cuento cuantos registros tiene cada estado para verificar 
		#si todos los registros tienen un estado valido.
		registrosTotalesLeidos=$(($registrosTotalesLeidos+`echo $listaImportes | wc -w`))
		for importe in $listaImportes; do
			#forma de comparar dos numeros decimales.
			if ! (( $(echo "$importe $signo 0.0" | bc -l) )); then			
				return 1
			fi
		done
		#signo menor a cero para pendiente
		signo="<"
	done
	regTotalesEnArchivo=`cat "$DIROK/$archivo" | sed -e 1'd' | wc -l` 
	# si el total de registrios del archivos no coincide con la suma de la cantidad de registros
	# de cada estado. entonces hay algun registro invalido, se rechaza el archivo.
	if ! [ $registrosTotalesLeidos -eq $regTotalesEnArchivo ]; then
		echo "archivo rechazado por estado invalido"
		return 1
	fi

	return 0
}

verificarCodigoDeBanco(){
	codBancoCbu=`echo $1 | sed "s/^\(...\).*/\1/"`

	listaCodEntidades=`cat $DIRMAE/bancos.csv | sed "s/^[^;]*;\([^;]*\).*/\1/"`

	for codigo in $listaCodEntidades ; do 
		if [ $codigo = $codBancoCbu ]; then
			return 0
		fi
	done
	return 1
}

validarCantidadDigitosCbu(){
	cbu=`echo "$1" | grep "^[0-9]\{$CANTDIGITOSCBU\}$"`

	#si cbu esta vacio es por que no tiene 22 (CANTDIGITOSCBU) digitos decimales. 
	if [ -z $cbu ]; then
		return 1
	fi
	return 0
}

validarCBU(){
	archivo=$1
	listaCBUs=`cat "$DIROK/$archivo" | sed -e 1'd' | cut -d';' -f4,5`

	for cbu in $listaCBUs ; do 
		cbuOrigen=`echo "$cbu" | sed "s/^\([^;]*\);.*/\1/"`
		if ! validarCantidadDigitosCbu $cbuOrigen ; then
			return 1
		fi
		cbuDestino=`echo "$cbu" | sed "s/^[^;]*;//"`
		if ! validarCantidadDigitosCbu $cbuDestino ; then
			return 1
		fi
		if ! [ $cbuOrigen = $cbuDestino ]; then
			return 1
		fi
		if ! verificarCodigoDeBanco $cbuOrigen ; then
			return 1
		fi
		if ! verificarCodigoDeBanco $cbuDestino ; then
			return 1
		fi
	done
	return 0
}

convertirYEscribirSalida(){
	# FORMATO SALIDA
	# FUENTE;ENTIDADORIGEN;CODENTORIGEN;ENTIDADDESTINO;CODENTDEST;FECHA;IMPORTE;ESTADO;CBUO;CBUD

	registro=$1
	fuente=$2

	cbuOrigen=`echo $registro | cut -d';' -f4`
	codEntOrigen=`echo $cbuOrigen | cut -c1-3`
	entOrigen=`cat $DIRMAE/bancos.csv | grep "^.*;$codEntOrigen" | cut -d';' -f1`
	
	cbuDestino=`echo $registro | cut -d';' -f5`
	codEntDestino=`echo $cbuDestino | cut -c1-3`
	entDestino=`cat $DIRMAE/bancos.csv | grep "^.*;$codEntDestino" | cut -d';' -f1`

	fecha=`echo $registro | cut -d';' -f1`
	importe=`echo $registro | cut -d';' -f2`
	estado=`echo $registro | cut -d';' -f3`

	linea="$fuente;$entOrigen;$codEntOrigen;$entDestino;$codEntDestino;$fecha"
	linea="$linea;$importe;$estado;$cbuOrigen;$cbuDestino"

	echo "$linea" >> "$DIRTRANSFER/$fecha.txt"
}

procesarArchivo(){
	archivo=$1
	#		$DIRINFO/transfer
	echo estoy procesando el archivo. $archivo
	#saco la cabecera del archivo
	registros=`cat $DIROK/$archivo | sed -e 1'd'`
	for reg in $registros; do
		convertirYEscribirSalida "$reg" "$archivo"
	done
	echo termine de procesar

}
validarFecha(){
	#si es vacia la fecha que me pasan rechazo.
	if [ -z $1 ]; then
		return 1
	fi
	#sea una fecha valida
	#mayor o igual a la fecha del filename
	#menor o igual a la fecha del filename + 7 dias
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

	aniof2=`echo $2 | sed "s/^\(....\).*/\1/"`
	mesf2=`echo $2 | sed "s/^....\(..\).*/\1/"`
	diaf2=`echo $2 | sed "s/^......//"`


	dif=$(($(($(date -d "$aniof2$mesf2$diaf2" "+%s") - $(date -d "$anio$mes$dia" "+%s"))) / 86400))
	if [ $dif -lt 0 ]; then
		echo la fecha $1 - $2 es menor a cero  
		return 1 
	fi
	#no tiene que tener mas de 7 dias de antiguedad con respecto a la fecha del archivo.
	if [ $dif -gt 7 ]; then
		echo la fecha $1 - $2 es mayor a 7
		return 1
	fi
	return 0
}
validarFechasRegistros(){
	archivo=$1
	fechaArchivo=`echo $archivo |sed "s/^[^_]*_//" | cut -d'.' -f1`
	fechas=`cat "$DIROK/$archivo" | sed -e 1'd' | cut -d';' -f1`
	for fecha in $fechas; do
		validarFecha $fecha $fechaArchivo
	done
}

validarCampos(){
	archivo=$1

	montoTotalInformado=`cat "$DIROK/$archivo" | sed 1'!d' | sed "s/^[^;]*;//" | sed "s/,/./g"`
	if [ -z $montoTotalInformado ]; then
		#log
		echo "Error de formato en registro nro 1 (cabecera)"
		rechazarArchivo "$archivo"
		return
	fi

	montoTotal=`calcularMontoTotal "$archivo"`

	if ! [ $montoTotal = $montoTotalInformado ]; then
		echo rechazar montoTotal distinto montoTotalInformado
		rechazarArchivo "$archivo"
		return
	fi

	if ! validarImportesSegunEstado $archivo ; then
		echo rechazar importe invalido segun estado.
		rechazarArchivo "$archivo"
		return
	fi

	if ! validarCBU $archivo ; then
		error "Registro con CBU invalido en $archivo"
		rechazarArchivo "$archivo"
		return
	fi

	if ! validarFechasRegistros $archivo; then
		error "Registro con fecha invalida en $archivo"
		rechazarArchivo "$archivo"
		return
	fi
	procesarArchivo "$archivo"
	aceptarArchivo "$archivo"
}

verificarEstructura(){
	archivo=$1
	#el registro de cabecera tiene este formato numero;numero
	#CONSULTAR POR QUE CORTA EL SCRIPT SI EL ARCHIVO ESTA VACIO 
	# NO ES IMPORTANTE POR QUE ES ESTA ETAPA YA VIENE VALIDADO QUE EL ARCHIVO NO ESTE VACIO
	cabecera=`cat "$DIROK/$archivo" | sed -e 1'!d' | grep "^.*;.*$"`
	cantidadDeRegistros=`cat "$DIROK/$archivo" | sed -e 1'd' | wc -l`
	cantidadDeRegistrosValida=`cat "$DIROK/$archivo" | sed -e 1'd' | grep "^.*;.*;.*;.*;.*$" | wc -l`	
	cantidadDeRegInformada=`echo "$cabecera" | cut -d';' -f1`	

	if [ -z $cabecera ]; then
		error "Formato de cabecera invalido del archivo $archivo."
		rechazarArchivo "$archivo"
		return 1
	fi

	if ! [ $cantidadDeRegistros -eq $cantidadDeRegInformada ]; then
		error "Cantidad de registros: leidos: $cantidadDeRegistros Cantidad informada: $cantidadDeRegInformada"
		rechazarArchivo "$archivo"
		return 1
	fi
	if ! [ $cantidadDeRegistros -eq $cantidadDeRegInformada ]; then
		error "Cantidad de registros: leidos: $cantidadDeRegistros Cantidad informada: $cantidadDeRegInformada"
		rechazarArchivo "$archivo"
		return 1
	fi
	validarCampos $archivo
}

procesarArchivos(){
	#_IFS="$IFS"
	#IFS=$'\n'
	archivos=`ls "$DIROK"`
	for archivo in $archivos ; do
		if [ $archivo = "proc" ]; then
			continue
		fi
		if [ $archivo = "duplicados" ]; then
			continue
		fi
		if fueProcesado "$archivo" ; then
			#log
			print "El archivo $archivo ya fue procesadodo."
			rechazarArchivo "$archivo"
		else
			verificarEstructura "$archivo"
		fi
	done
	#restauro el IFS original.
	#IFS=$_IFS
}

set -e
verificarDirectorios
procesarArchivos
if [ -f "$DIRBIN/pid_proc" ]; then
	rm "$DIRBIN/pid_proc"
fi