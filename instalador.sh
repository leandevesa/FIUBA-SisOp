#!/bin/bash

# terminar en caso de error
set -e

DIR_CONF='./dirconf'
ARCHIVO_CONF="$DIR_CONF/instalador.conf"
ARCHIVO_LOG="$DIR_CONF/instalador.log"  # este log es independiente del ingresado por el usuario
DIR_BASE='./Grupo02'

mostrar_ayuda()
{
    echo "Uso: ./`basename "$0"` [-ti]"
    echo 'Realiza la instalción del paquete'
    echo
    echo '  -h, --help     muestra este mensaje y termina el programa'
    echo '  -t             imprime la configuración actual y termina el programa sin realizar cambios'
    echo '  -i             reinstala el paquete (o lo instala si aún no se hizo)'
    echo
    echo "Todos los archivos se crearán en el directorio $DIR_BASE"
}

solicitar_directorio()
{
    # solicita al usuario que ingrese un directorio y lo valida
    # el primer parámetro debe ser el tipo directorio que se solicita (configuración, log, etc)
    # el segundo parámetro debe ser el valor por defecto si el usuario no ingresa uno
    # el tercer parámetro debe ser el nombre de la variable en la cual se guarda el resultado

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
    valores_conf=(
        dir_bins
        dir_maes
        dir_nove
        dir_acep
        dir_rech
        dir_vali
        dir_repo
        dir_logs
    )

    if [ ! -d "$DIR_CONF" ]; then
        mkdir -p $DIR_CONF
    fi

    echo '#/bin/sh' > $ARCHIVO_CONF
    echo '' >> $ARCHIVO_CONF

    for i in "${valores_conf[@]}"; do
        echo "$i=${!i}" >> $ARCHIVO_CONF
    done
}

obtener_datos_del_usuario()
{
    solicitar_directorio binarios $dir_bins dir_bins
    solicitar_directorio maestros $dir_maes dir_maes
    solicitar_directorio novedades $dir_nove dir_nove
    solicitar_directorio aceptados $dir_acep dir_acep
    solicitar_directorio rechazados $dir_rech dir_rech
    solicitar_directorio validados $dir_vali dir_vali
    solicitar_directorio reportes $dir_repo dir_repo
    solicitar_directorio logs $dir_logs dir_logs
}


# valores por defecto de directorios a definir por el usuario
dir_bins="$DIR_BASE/bin"        # directorio de binarios
dir_maes="$DIR_BASE/maestros"   # directorio de maestros
dir_nove="$DIR_BASE/novedades"  # directorio de novedades
dir_acep="$DIR_BASE/aceptados"  # directorio de aceptados
dir_rech="$DIR_BASE/rechazados" # directorio de rechazados
dir_vali="$DIR_BASE/validados"  # directorio de validados
dir_repo="$DIR_BASE/reportes"   # directorio de reportes
dir_logs="$DIR_BASE/logs"       # directorio de logs de comandos

verificar_instalacion=0 # flag

# carga el archivo de configuración
if [ -f "$ARCHIVO_CONF" ] ; then
    source $ARCHIVO_CONF
fi

# manejo de los parametros de entrada
while [ "$1" != "" ]; do
    case $1 in
        -t          ) verificar_instalacion=1;;
        -h | --help ) mostrar_ayuda;
                      exit 0;;
        *           ) echo "ERROR: parámetro invalido: $1";
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

if ! ./dependencias.sh ; then
    echo 'Las dependencias no se cumplieron, instalación abortada.'
    exit 1
fi

obtener_datos_del_usuario
until ./pregunta.sh "Desea proceder con la instalación?" ; do
    obtener_datos_del_usuario
done

# se persiste la configuración en un archivo
guardar_config

# crear directorios
echo "se crea el directorio de binarios en $dir_bins"
mkdir -p $dir_bins
echo "se crea el directorio de binarios en $dir_maes"
mkdir -p $dir_maes
echo "se crea el directorio de binarios en $dir_nove"
mkdir -p $dir_nove
echo "se crea el directorio de binarios en $dir_acep"
mkdir -p $dir_acep
echo "se crea el directorio de binarios en $dir_rech"
mkdir -p $dir_rech
echo "se crea el directorio de binarios en $dir_vali"
mkdir -p $dir_vali
echo "se crea el directorio de binarios en $dir_repo"
mkdir -p $dir_repo
echo "se crea el directorio de binarios en $dir_logs"
mkdir -p $dir_logs
