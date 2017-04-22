#!/bin/bash

VERSION_MINIMA_PERL=5

# verifica la disponibilidad de perl
if perl < /dev/null > /dev/null 2>&1 ; then
    # verifica que la version sea >= VERSION_MINIMA_PERL
    version=`perl -e 'print $]' | sed -r 's/([0-9])+.*/\1/'`
    if [ "$version" -lt "$VERSION_MINIMA_PERL" ]; then
        echo "Se requiere perl versión $VERSION_MINIMA_PERL o más"
        exit 2
    fi
else
    echo 'Se requiere perl instalado para continuar'
    exit 1
fi
