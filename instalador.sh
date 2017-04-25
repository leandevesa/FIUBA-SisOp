#!/bin/bash

# terminar en caso de error
set -e

# permite la ejecución desde otros directorios
if [ `pwd` != `dirname $0` ] ; then
    cd `dirname $0`
fi

DIR_CONF='dirconf'
ARCHIVO_CONF="$DIR_CONF/instalador.conf"
ARCHIVO_LOG="$DIR_CONF/instalador.log"  # este log es independiente del ingresado por el usuario
DIR_BASE='Grupo02'

# listado de directorios a solicitar
DIRECTORIOS=(
    binarios
    maestros
    novedades
    aceptados
    rechazados
    validados
    reportes
    logs
)

# incluye las funciones para manejar la config
. ./config.sh


mostrar_ayuda()
{
    echo "Uso: ./`basename "$0"` [-ti]"
    echo 'Realiza la instalación del paquete'
    echo
    echo '  -h, --help     muestra este mensaje y termina el programa'
    echo '  -t             imprime la configuración actual y termina el programa sin realizar cambios'
    echo '  -i             reinstala el paquete (o lo instala si aún no se hizo)'
    echo
    echo "Todos los archivos se crearán en el directorio $DIR_BASE"
}

print()
{
    # muestra un mensaje obtenido en $1 por STDOUT

    mensaje=$1
    echo $mensaje
}

error()
{
    # muestra un mensaje de error por STDERR y termina el programa
    # $1 es el mensaje a mostrar
    # $2 valor de retorno del programa (1 si no está presente)

    mensaje=$1
    rc=$2

    if [ -z "$rc" ] ; then
        rc=1
    fi

    echo -e $mensaje >&2
    exit $rc
}

canonicalizar()
{
    readlink -m $1
}

mayuscula()
{
    # convierte a mayuscula $1

    echo "$1" | awk '{ print toupper($0) }'
}

inicializar_var_directorios()
{
    # inicializa las variables donde se van a guardar los directorios ingresados por el usuario
    # toma los valores de DIRECTORIOS e inicializa cada valor con DIR_BASE/<nombre directorio>
    # si había valores previos en el archivo de configuración, utiliza esos

    for d in "${DIRECTORIOS[@]}"; do
        eval "$d=$DIR_BASE/$d"
    done

    cargar_config
}

solicitar_directorio()
{
    # solicita al usuario que ingrese un directorio y lo valida
    # $1 debe ser el tipo directorio que se solicita (configuración, log, etc)
    # $2 debe ser el valor por defecto si el usuario no ingresa uno
    # $3 debe ser el nombre de la variable en la cual se guarda el resultado

    tipo_dir=$1
    default=$2
    salida=$3

    rv=""

    while true ; do
        read -e -p "ingrese el directorio de $tipo_dir ($default): " rv

        # utilizar el valor por defecto?
        if [ "$rv" == "" ] ; then
            rv=$default
        fi

        # canonicalize
        rv=`canonicalizar $rv`

        if [ "$rv" == `canonicalizar DIR_CONF` ] ; then
            print "$DIR_CONF es un directorio reservado, por favor elija uno distinto"
            continue
        fi

        # verifica que el path ingresado por el usuario este dentro de DIR_BASE
        if [[ ! "$rv" == `canonicalizar $DIR_BASE`* ]] ; then
            print "El directorio debe estar dentro de $DIR_BASE"
            continue
        fi

        # si llegó a este punto todo salió bien
        break
    done

    # convierte a path relativo
    prefijo=`canonicalizar $DIR_BASE`
    rv=`echo $rv | sed s:$prefijo::`

    eval "$salida='${DIR_BASE}$rv'"
    return 0
}

guardar_config()
{
    # guarda los valores de las variables de los directorios (DIRECTORIOS) en el archivo de
    # configuración

    if [ ! -d "$DIR_CONF" ]; then
        mkdir -p $DIR_CONF
    fi

    for i in "${DIRECTORIOS[@]}"; do
        # convierte los paths en absolutos
        valor=`canonicalizar ${!i}`
        config_set "$ARCHIVO_CONF" `mayuscula "$i"` "$valor"
    done
}

cargar_config()
{
    # carga el archivo de configuración en las variables con los de los directorios (DIRECTORIOS)

    if [ ! -f "$ARCHIVO_CONF" ] ; then
        return 0
    fi

    # carga los valores en las variables correspondientes
    for i in "${DIRECTORIOS[@]}"; do
        clave=`mayuscula "$i"`
        val_config=`config_get "$ARCHIVO_CONF" "$clave"`
        if [ -z "$val_config" ] ; then
            continue
        fi

        # convierte los paths a relativos
        val_config=`realpath --canonicalize-missing --relative-to=. $val_config`
        eval "$i=$val_config"
    done
}

mostrar_config()
{
    print 'Valores ingresados:'
    for d in "${DIRECTORIOS[@]}"; do
        print "  $d: ${!d}"
    done
}

obtener_datos_del_usuario()
{
    i=0

    # por cada directorio solicita al usuario ingresar un path
    for d in "${DIRECTORIOS[@]}"; do
        repetir=0
        while [ $repetir -eq 0 ]; do
            solicitar_directorio $d ${!d} nuevo

            # verifica que el directorio no haya sido ingresado anteriormente
            repetir=1
            for d2 in "${DIRECTORIOS[@]:0:$i}"; do
                if [ "${!d2}" == "$nuevo" ]; then
                    print "ese directorio ya fue elegido para '$d2'"
                    repetir=0  # volver a solicitar el ingreso
                    break
                fi
            done
        done

        # guarda el nuevo valor en la variable
        eval "$d=$nuevo"

        # incrementa el contador
        i=$(( $i + 1 ))
    done

    # muestra los datos ingresados
    mostrar_config
}


verificar_instalacion=0 # flag

# manejo de los parametros de entrada
while [ "$1" != "" ]; do
    case $1 in
        -t          ) verificar_instalacion=1;;
        -h | --help ) mostrar_ayuda;
                      exit 0;;
        *           ) echo "ERROR: parámetro invalido: $1" >&2;
                      echo 'utilice -h o --help para obtener información sobre como utilizar el script';
                      exit 1;;
    esac

    # cambiar al siguiente parámetro
    shift
done

if [ "$verificar_instalacion" -eq 1 ] ; then
    cargar_config
    mostrar_config

    # TODO: checkear instalación e imprimir el archivo de configuración
    echo "IMPLEMENTAR CHECKEO DE LA INSTALACION" >&2
    exit 0
fi

# verifica las dependencias
if ! ./dependencias.sh ; then
    error 'Las dependencias no se cumplieron, instalación abortada.' >&2
fi

# crea la variable para cada directorio y con los valores por defecto/configurados
inicializar_var_directorios

# solicita al usuario los datos necesarios
obtener_datos_del_usuario
until ./pregunta.sh "Desea proceder con la instalación?" ; do
    obtener_datos_del_usuario
done

# se persiste la configuración en un archivo
guardar_config

# crea los directorios
for d in "${DIRECTORIOS[@]}"; do
    path=${!d}
    print "se crea el directorio de binarios en $path"
    mkdir -p $path
done
