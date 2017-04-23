#!/bin/bash

#******************** FUNCIONES ********************

# $1=valor, $2=nombre de la variable
# valida si la variable tiene asignada algun valor, si no se termina el programa.}
checkVar() {
	if [ -z "$1" ] 
	then 
		echo "No se puede inicializar la variable $2." 
		return 1
	fi
}

# se toman los valores de las variables del archivo de configuracion
# estan en el segundo campo y delimitados por "="
setVariablesDeEntorno() {
    DIRBIN=$(grep '^DIRBIN' "$FILECONF" | cut -d "=" -f 2)
    DIRMAE=$(grep '^DIRMAE' "$FILECONF" | cut -d "=" -f 2)
    DIRREC=$(grep '^DIRREC' "$FILECONF" | cut -d "=" -f 2)
    DIROK=$(grep '^DIROK' "$FILECONF" | cut -d "=" -f 2)
    DIRPROC=$(grep '^DIRPROC' "$FILECONF" | cut -d "=" -f 2)
    DIRINFO=$(grep '^DIRINFO' "$FILECONF" | cut -d "=" -f 2)
    DIRLOG=$(grep '^DIRLOG' "$FILECONF" | cut -d "=" -f 2)
    DIRNOK=$(grep '^DIRNOK' "$FILECONF" | cut -d "=" -f 2)
}

# inicializo variables
inicializarVariables() {
    PATH=$PATH:$DIRBIN
    export DIRMAE
    export DIRREC
    export DIROK
    export DIRPROC
    export DIRINFO
    export DIRLOG
    export DIRNOK
}

# chequeo si las variables fueron seteadas
verificarVariables() {
checkVar "$GRUPO" "GRUPO" || return 1
checkVar "$DIRBIN" "DIRBIN" || return 1
checkVar "$DIRMAE" "DIRMAE" || return 1
checkVar "$DIRREC" "DIRREC" || return 1
checkVar "$DIROK" "DIROK" || return 1
checkVar "$DIRPROC" "DIRPROC" || return 1
checkVar "$DIRINFO" "DIRINFO" || return 1
checkVar "$DIRLOG" "DIRLOG" || return 1
checkVar "$DIRNOK" "DIRNOK" || return 1
}

# verifico los permisos
# si se retorna 0 es porque los archivos tienen los permisos adecuados, en caso contrario, se retorna 1
verificarPermisos() {

    permiso=0
    cd $DIRBIN
    for script in $DIRBIN/*; do
	    chmod +x "$script"
	    
		if [[ ! -x "$script" ]]; then
		    let permiso+=1
		fi
    done

    for file in $DIRMAE/*; do
		chmod u=rx "$file"
		if [[ ! -r "$file" ]]; then
		    let permiso+=1
		fi
    done

    if [[ "$permiso" == 0 ]]; then
		# los archivos tienen permiso
		return 0
    else
		# los archivos no tienen permiso
		return 1
    fi	
}

#iniciarDemonio() {                                                                                  VERIFICAR NOMBRE DEMONIO
#	Demonio &
#	processID=$(pgrep -x -n "Demonio")
#	echo "Demonio corriendo bajo el id: $processID"
#	echo "Para detener el proceso puede ejecutar el comando Stop_Demonio."                         #VERIFICAR
#}


#******************** EJECUCION ********************


DIRCONF=$(pwd)'/dirconf'
FILECONF=$DIRCONF/instalador.conf #VERIFICAR NOMBRE

#Valida que se haya ingresado un parámetro
if [ "$FILECONF" = "" ] 
then
	echo "Debe indicar por parámetro un archivo de configuracion."
	return 1

#Valida que el archivo de configuracion tenga permiso de lectura
elif ! test -r "$FILECONF" 
then
	echo "El archivo no puede ser leído."
	return 1
fi


#veo si ya fue iniciado el ambiente
if [ "$AMBIENTE_INICIALIZADO" = "true" ]
then
	echo "Ambiente ya inicializado, para reiniciar termine la sesión e ingrese nuevamente."
	return 1 #retorna 1 para indicar error
fi


# seteo variables
setVariablesDeEntorno
inicializarVariables
echo "Se setearon las variables de entorno."

# chequeo variables
verificarVariables

# verifico permisos
verificarPermisos
resultado=$?
if [ $resultado != 0 ]; then
#se termina la ejecucion
	echo "No se pueden dar los permisos a los archivos."
else
	echo "Ambiente Inicializado."

export AMBIENTE_INICIALIZADO="true"
echo "El sistema se ha iniciado correctamente."

MSG="¿Desea activar el Demonio? s/n"
read start
if [ $start = "s" ]
then
	echo "S: Iniciando Demonio."
	iniciarDemonio
else
	echo "N: No se inicia el Demonio. Saliendo de la aplicación."
	echo "Puede ejecutar el Demonio manualmente, ejecutando el comando ./Demonio"                        #VERIFICAR
fi


