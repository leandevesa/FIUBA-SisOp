#/bin/sh

# verifica la disponibilidad de perl
if perl < /dev/null > /dev/null 2>&1 ; then
    # verifica que la version sea >= 5
else
    echo 'Se requiere perl instalado para continuar'
    exit 1
fi
