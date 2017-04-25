#!/bin/bash

trap "eval continuar=1" SIGINT SIGTERM

continuar=0

while [ $continuar -eq 0 ]; do
    # TODO: agregar las tareas del daemon
    sleep 1
done
