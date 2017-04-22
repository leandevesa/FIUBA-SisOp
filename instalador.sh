#/bin/sh

# terminar en caso de error
set -e

DIR_CONF='./dirconf'
ARCHIVO_CONF="$DIR_CONF/config.sh"
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
        if [[ ! "$rv" == `./canonicalizar.sh $DIR_BASE`* ]]; then
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
    valores_conf=(dir_inst dir_bins)

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
    solicitar_directorio instalación $dir_inst dir_inst
    solicitar_directorio binarios $dir_bins dir_bins
}


dir_inst=$DIR_BASE              # directorio de instalación
dir_bins="$DIR_BASE/bin"        # directorio de binarios

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
    echo 'Las dependencias no se encuentran instaladas, instalación abortada.'
    exit 1
fi

obtener_datos_del_usuario
until ./pregunta.sh "Desea proceder con la instalación?" ; do
    obtener_datos_del_usuario
done

# se periste la configuración en un archivo
guardar_config

echo "se crea el directorio de instalación en $dir_inst"
mkdir -p $dir_inst

echo "se crea el directorio de binarios en $dir_bins"
mkdir -p $dir_bins
