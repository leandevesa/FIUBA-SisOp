#/bin/sh

# este programa realiza una pregunta al usuario (que pueda responderse con si/no) hasta obtener
# una respuesta valida, y retorna con 0 si la respuesta es afirmativa, o 1 si es negativa
# el primer parametro es la pregunta a hacer al usuario
pregunta=$1

finalizar=0

while true; do
    echo -n "$pregunta [s/n]: "
    read respuesta

    case "$respuesta" in
        s|y|si|yes|obvio ) exit 0;;
        n|no|nah ) exit 1;;
    esac
done
