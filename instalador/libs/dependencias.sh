#!/bin/bash

VERSION_MINIMA_PERL=5

# verifica la disponibilidad de perl
if ! command -v perl >/dev/null 2>&1 ; then
    echo "Se requiere el programa 'perl'"
    echo 'utilice sudo apt-get install realpath'
    exit 3
fi

if perl < /dev/null > /dev/null 2>&1 ; then
    # verifica que la version sea >= VERSION_MINIMA_PERL
    version=`perl -e 'print $]' | sed -r 's/([0-9])+.*/\1/'`
    if [ "$version" -lt "$VERSION_MINIMA_PERL" ]; then
        echo "Se requiere perl versión $VERSION_MINIMA_PERL o más" >&2
        exit 2
    fi
else
    echo 'Se requiere perl instalado para continuar' >&2
    exit 1
fi

# verifica que realpath esté instalado
if ! command -v realpath >/dev/null 2>&1 ; then
    echo "Se requiere el programa 'realpath'"
    echo 'utilice sudo apt-get install realpath'
    exit 3
fi
