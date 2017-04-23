#!/bin/bash

# terminar en caso de error
set -e

DIR_CONF='./dirconf'
ARCHIVO_CONF="$DIR_CONF/instalador.conf"
ARCHIVO_LOG="$DIR_CONF/instalador.log"  # este log es independiente del ingresado por el usuario
DIR_BASE='./Grupo02'

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
        echo -n "ingrese el directorio de $tipo_dir [$default]: "
        read rv

        # utilizar el valor por defecto?
        if [ "$rv" == "" ] ; then
            rv=$default
        fi

        # canonicalize
        rv=`./canonicalizar.sh $rv`

        if [ "$rv" == `./canonicalizar.sh DIR_CONF` ] ; then
            echo "$DIR_CONF es un directorio reservado, por favor elija uno distinto"
            continue
        fi

        # verifica que el path ingresado por el usuario este dentro de DIR_BASE
        if [[ ! "$rv" == `./canonicalizar.sh $DIR_BASE`* ]] ; then
            echo "El directorio debe estar dentro de $DIR_BASE"
            continue
        fi

        # si llegó a este punto todo salió bien
        break
    done

    # convierte a path relativo
    prefijo=`./canonicalizar.sh $DIR_BASE`
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
        config_set "$ARCHIVO_CONF" "$i" "${!i}"
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
        val_config=`config_get "$ARCHIVO_CONF" "$i"`
        if [ -z "$val_config" ] ; then
            continue
        fi
        eval "$i=$val_config"
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
                    echo "ese directorio ya fue elegido para '$d2'"
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
    echo 'Valores ingresados:'
    for d in "${DIRECTORIOS[@]}"; do
        echo "  $d: ${!d}"
    done
}


verificar_instalacion=0 # flag

# manejo de los parametros de entrada
while [ "$1" != "" ]; do
    case $1 in
        -t          ) verificar_instalacion=1;;
        -h | --help ) mostrar_ayuda;
                      exit 0;;
        *           ) echo "ERROR: parámetro invalido: $1";
                      echo 'utilice -h o --help para obtener información sobre como utilizar el script';
                      exit 1;;
    esac

    # cambiar al siguiente parámetro
    shift
done

if [ "$verificar_instalacion" -eq 1 ] ; then
    # TODO: checkear instalación e imprimir el archivo de configuración
    echo "IMPLEMENTAR"
    exit 0
fi

# verifica las dependencias
if ! ./dependencias.sh ; then
    echo 'Las dependencias no se cumplieron, instalación abortada.'
    exit 1
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
    echo "se crea el directorio de binarios en $path"
    mkdir -p $path
done
