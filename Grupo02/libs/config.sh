#!/bin/bash

# funciones para manipular archivos de configuración
# incluir en el archivo a utilizar con la siguiente línea
#
#   . ./config.sh

config_set()
{
    # settea un valor asociado a una clave en el archivo de configuración
    # $1 es el archivo a manipular
    # $2 es la clave a la cual se asocia el valor
    # $3 es el valor

    archivo=$1
    clave=$2
    valor=$3

    # se requieren 3 parámetros de entrada
    if [ "$#" -ne 3 ] ; then
        return 1
    fi

    # si el archivo no existe lo crea
    if [ ! -f "$archivo" ] ; then
        touch $archivo
    else
        # elimina la clave (si existe)
        config_del $archivo $clave
    fi

    # escribe la entrada en el archivo
    echo "$clave=$valor=`whoami`=`date`" >> $archivo
}

config_get()
{
    # obtiene un valor asociado a una clave en el archivo de configuración
    # $1 es el archivo a manipular
    # $2 es la clave a la cual se asocia el valor que se obtiene

    archivo=$1
    clave=$2

    # se requieren 2 parámetros de entrada
    if [ "$#" -ne 2 ] ; then
        return 1
    fi

    # el archivo debe existir
    if [ ! -f "$archivo" ]; then
        return 2
    fi

    # busca la clave en el archivo
    # si por alguna razón estuviera repetida, tima el último valor solamente
    grep -e "^$clave" $archivo | tail -1 | sed -r "s/^$clave=(.*?)=.*?=.*\$/\1/"
}

config_del()
{
    # elimina un par clave/valor del archivo de configuración
    # $1 es el archivo a manipular
    # $2 es la clave a eliminar

    archivo=$1
    clave=$2

    if [ "$#" -ne 2 ] ; then
        return 1
    fi

    sed -i "/^$clave=/d" $archivo
}

if [ "$1" == "--test" ] ; then
    set -e

    config_set a b "c==d==a="
    [ `config_get a b` == 'c==d==a=' ]

    config_set a b "valor nuevo"
    [ "`config_get a b`" == 'valor nuevo' ]

    config_set a k2 "v2"
    config_set a k3 "v3"
    [ "`config_get a b`" == 'valor nuevo' ]
    [ `config_get a k2` == 'v2' ]
    [ `config_get a k3` == 'v3' ]

    config_del a k2
    config_del a k2
    [ -z `config_get a k2` ]

    echo 'PASS'
    rm a
fi
