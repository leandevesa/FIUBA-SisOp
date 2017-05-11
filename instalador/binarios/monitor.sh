#!/bin/bash

# inicia el daemon

ARCHIVO_PID="$DIRBIN/pid"  # nombre del archivo donde se guarda el pid del daemon

ARCHIVO_LOG="../libs/log.sh"

set -e

print()
{
    # muestra un mensaje obtenido en $1 por STDOUT

    mensaje=$1
    $ARCHIVO_LOG "Monitor" "Info" "$mensaje"
    echo $mensaje
}

error()
{
    # muestra un mensaje de error por STDERR y termina el programa
    # $1 es el mensaje a mostrar
    # $2 valor de retorno del programa (1 si no está presente)

    mensaje=$1
    rc=$2

    $ARCHIVO_LOG "Monitor" "Error" "$mensaje"

    if [ -z "$rc" ] ; then
        rc=1
    fi

    echo -e $mensaje >&2
    exit $rc
}

mostrar_ayuda()
{
    echo "Uso: ./`basename "$0"` [-h] start|stop"
    echo 'Inicia/detiene el proceso monitor de archivos.'
    echo
    echo '  -h, --help     muestra este mensaje y termina el programa'
    echo
    echo 'Comandos:'
    echo '  start          inicia el demonio que monitorea el directorio'
    echo '  stop           detiene el demonio (tiene que haber sido inicializado previamente)'
}

daemon_activo()
{
    # retorna 0 si el daemon esta corriendo

    if [ -f $ARCHIVO_PID ] ; then
        return 0
    else
        return 1
    fi
}

iniciar_daemon()
{
    # verifica si el daemon ya está corriendo
    if daemon_activo ; then
        error 'El demonio se encuentra activo'
    fi

    script="`dirname $0`/daemon.sh"

    set +e

    # inicia el proceso en background
    nohup $script &> /dev/null &
    if [ ! $! ] ; then
        error 'No se pudo inicializar el demonio'
    fi

    set -e

    # obtiene y guarda el process ID
    pid=$!
    echo $pid > $ARCHIVO_PID

    print "se inició el demonio con el pid $pid"
}

detener_daemon()
{
    if ! daemon_activo ; then
        error 'El demonio no se encuentra activo'
    fi

    set +e
    kill `cat $ARCHIVO_PID`

    if [ ! "$?" ] ; then
        error 'No se pudo detener el demonio'
    fi

    set -e

    print 'demonio detenido'
    rm $ARCHIVO_PID
}


# maneja los parámetros de entrada
if [ "$#" -ne 1 ] ; then
    error 'Se esperaba solamente 1 parámetro.\nUtilice -h para obtener información sobre como utilizar el programa'
fi

case $1 in
    -h | --help ) mostrar_ayuda;
                  exit 0;;
    start       ) iniciar_daemon;;
    stop        ) detener_daemon;;
    *           ) error 'Comando inválido: $1.\nUtilice -h para obtener información sobre como utilizar el programa';;
esac
