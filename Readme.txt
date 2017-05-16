--------------------------------------------------------------------------------------------------------------------

﻿1. Una explicación de cómo descargar el paquete


--------------------------------------------------------------------------------------------------------------------

2. Una explicación de cómo descomprimir, crear directorio del grupo, etc

Para descomprimir, hay que posicionarse sobre el directorio donde se descargó el paquete y ejecutar el siguiente comando en la terminal:

“tar -xvzf Grupo02.tgz“

--------------------------------------------------------------------------------------------------------------------

3. Una explicación de lo que se crea a partir de la descompresión

A partir de la descompresión se crea un archivo “instalador” y su correspondiente carpeta que tiene los binarios, librerías y archivos maestros que se copiaran a la carpeta en la que se decida instalar el sistema. También se crean dos carpetas, una llamada “dirconf” que va a tener informacion de los parámetros que se ingresen en el instalador y otra llamada “Grupo02” donde se va a instalar el sistema con las subcarpetas elegidas previamente.

--------------------------------------------------------------------------------------------------------------------

4. Una explicación sobre que se requiere para poder instalar y/o ejecutar el sistema 

Para poder instalar se debe ejecutar la aplicación sobre un sistema operativo Linux/Unix, que tenga instalado “Perl 5” o superior.

--------------------------------------------------------------------------------------------------------------------

5. Instrucciones de instalación del sistema 

   1. Para instalar (o reinstalar el sistema, en caso de que haya quedado corrupta la instalación) hay que ejecutar el instalador con el parámetro “-i”.

Ejemplo: “./instalador.sh -i”

(si es la primera instalación se pueda obviar el parámetro “-i”)

   2. Para verificar el estado de la instalación (parámetros elegidos previamente, o ver si realmente está instalado el sistema), hay que ejecutar el instalador con el parámetro “-t”.

Ejemplo: “./instalador.sh -t”

--------------------------------------------------------------------------------------------------------------------

6. Que nos deja la instalación y dónde

A partir de la instalación, se generan los diferentes directorios por default, (estos pueden ser elegidos por el usuario, excepto dirconf que es una palabra reservada):

- Binarios
- Maestros
- Novedades
- Aceptados
- Rechazados
- Validados
- Reportes
- Logs

Todos estos sub-directorios son creados dentro del directorio “Grupo02” que se encuentra en la misma carpeta donde se descomprimió el paquete.

--------------------------------------------------------------------------------------------------------------------

7. Cuáles son los primeros pasos para poder ejecutar el sistema

Para poder ejecutar el sistema lo primero que hay que hacer es ejecutar el “inicializador.sh” (ubicado dentro de la carpeta “binarios” seleccionada al momento de la instalación). 

Es importante que sea ejecutado (en la terminal) de la siguiente forma: “. ./inicializador.sh”. Ya que así es la única forma en la que el programa pueda settear las variables de entorno en la terminal.

--------------------------------------------------------------------------------------------------------------------

8. Como arrancar o detener comandos

No se puede hacer uso de los siguientes programas sin previamente haber ejecutado el “inicializador”.

    Programa “monitor”:

        Tiene dos funciones básicas, las cuales se pueden ejecutar utilizando los parámetros especificados.

                a) Ejecutar el proceso de daemon (si no se ejecutó al momento de la inicialización): 

                      Parámetro “start”

                      Ejemplo: “./monitor.sh start”

                b) Detener el proceso de daemon

                      Parámetro “stop”

                      Ejemplo “./monitor.sh stop”

    Programa “consultas”

        Uso: ./consultas.pl [-hfodesuil] COMANDO [PARAMETROS EXTRA]

        Parámetros globales (aplican a todos los comandos)
        
         -h, --help           Muestra este mensaje y termina el programa.
         -f, --fuente         Indica una fuente por la cual filtrar la consulta (puede repetirse varias
                              veces).
         -o, --origen         Indica una entidad de origen por la cual filtrar la consulta (puede
                              repetirse varias veces).
         -d, --destino        Indica una entidad de destino por la cual filtrar la consulta (puede
                              repetirse varias veces).
         -e, --estado         Indica el estado por el cual filtrar la consulta (pendiente|anulada).
         -s, --fecha-desde    Indica la fecha de transferencia desde la cual aceptar transacciones.
         -u, --fecha-hasta    Indica la fecha de transferencia hasta la cual aceptar transacciones.
         -i, --importe-desde  Las transacciones con importe menor al indicado son filtradas.
         -l, --importe-hasta  Las transacciones con importe mayor al indicado son filtradas.

        Realiza consultas en las transacciones aplicando los filtros especificados por el usuario.
        Si no se especifica un filtro se incluyen todos los valores posibles para ese campo.
        Las entidades bancarias pueden indicarse mediante el código de 3 dígitos o el nombre corto (p.e.
        013 o BACOR).
        Los importes pueden ser negativos (con el prefijo -) y contener 2 decimales de precisión (p.e.
        100, -50, 150.30).
        Las fechas se ingresan con formato 'aaaammdd' (4 digitos para el año, 2 para el mes y 2 para el
        día). Por ejemplo, 19900811 para el 11/08/1990.

        Comandos
         help
         listado-origen
         listado-destino
         listado-cbu
         ranking
         balance-entidad
         balance-entre