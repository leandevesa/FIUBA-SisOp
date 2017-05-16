#!/bin/bash

set -e

NOMBRE_PAQUETE='Grupo02.tgz'
DIR_PROYECTO=$1
if [ -z "$DIR_PROYECTO" ] ; then
    DIR_PROYECTO=.
fi

cd $DIR_PROYECTO

if [ -f $NOMBRE_PAQUETE ] ; then
    rm $NOMBRE_PAQUETE
fi

if [ -d /tmp/TP ] ; then
    rm -R /tmp/TP
fi

mkdir /tmp/TP
mkdir /tmp/TP/Grupo02
mkdir /tmp/TP/dirconf
cp instalador.sh /tmp/TP
cp Readme.txt /tmp/TP
cp -r instalador /tmp/TP/

tar -czvf $NOMBRE_PAQUETE -C /tmp/TP .

rm -R /tmp/TP
