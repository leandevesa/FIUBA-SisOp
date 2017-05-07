#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;

Getopt::Long::Configure("pass_through");

# TODO: usar el PATH correcto desde las variables de entorno!!!
our $DIR_TRANSFER = "test/transacciones";

# expresion regular para validar fechas en la entrada
our $RE_FECHA = q/\d{8}/;

# expresion regular para validar el estado de la transacción
our $RE_ESTADO = q/pendiente|anulada/;

# expresion regular para validar montos
our $RE_MONTO = q/-?\d+\,\d{2}/;

# expresion regular para CBUs
our $RE_CBU = qw/\d{22}/;


# muestra el mesaje de ayuda
sub help {
    print<<EOF;
Uso: ./consultas.pl [-hfodeti]
  -h, --help          Muestra este mensaje y termina el programa
  -f, --fuente        Indica una fuente por la cual filtrar la consulta (puede repetirse varias
                      veces)
  -o, --origen        Indica una entidad de origen por la cual filtrar la consulta (puede
                      repetirse varias veces)
  -d, --destino       Indica una entidad de destino por la cual filtrar la consulta (puede
                      repetirse varias veces)
  -e, --estado        Indica el estado por el cual filtrar la consulta
  -s, --fecha-desde   Indica la fecha de transferencia desde la cual aceptar transacciones.
  -u, --fecha-hasta   Indica la fecha de transferencia hasta la cual aceptar transacciones.
  -i, --importe       Indica el importe por el cual filtrar la consulta

Realiza consultas en las transacciones aplicando los filtros especificados por el usuario.
Si no se especifica un filtro se incluyen todos los valores posibles para ese campo.
EOF
    exit 0;
}

# array de filtros para aplicar a la búsqueda
# los filtros se arman en base a los parámetros de entrada usando GetOptions
my @filtros;

# recibe un array y una subrutina que fabrica filtros.
# por cada elemento del array crea un filtro y retorna un filtro OR de todos los anteriormente
# creados
sub factory_filtros_or($$) {
    my ($valores, $factory) = @_;

    # crea un filtro para cada elemento
    my @filtros;
    for my $v (@{$valores}) {
        # crea el filtro y lo mete en el array
        push @filtros, $factory->( $v );
    }

    # crea un filtro OR con los filtros del array
    return crear_filtro_or( @filtros );
}

# crea un filtro que dados otros filtros realiza un OR, es decir, que al menos 1 de los filtros
# debe activarse o sino retorna falso
sub crear_filtro_or {
    my (@filtros) = @_;

    return sub {
        # ejecuta todos los filtros hasta que alguno sea aprobado
        for my $f (@filtros) {
            if( $f->( @_ ) ) {
                return 1;
            }
        }
        # ningún filtro se activó
        return 0;
    };
}

# crea un filtro para una fecha, ya sea inferior o superior
sub crear_filtro_fecha($$) {
    my ($fecha, $superior) = @_;

    # valida el formato de la fecha
    if( $fecha !~ /^(${RE_FECHA})$/ ) {
        # no es un patron valido
        die "formato de fecha inválido, se espera aaaammdd, se obtuvo $fecha.\n";
    }

    # TODO: verificar que sea una fecha válida

    if( $superior ) {
        return sub {
            # TODO: implementar el filtro
            print "filtro por fechas hasta $fecha\n";
        };
    } else {
        return sub {
            # TODO: implementar el filtro
            print "filtro por fechas desde $fecha\n";
        };
    }
}

# crea un filtro para una fuente específica
sub crear_filtro_fuente {
    my $fuente = $_[0];

    return sub {
        my %data = %{$_[0]};
        return $data{'fuente'} =~ /^$fuente/;
    };
}

# crea un filtro para una una entidad de origen
sub crear_filtro_origen {
    my $origen = $_[0];

    return sub {
        my %data = %{$_[0]};
        return $data{'cbu_origen'} =~ /^$origen/;
    };
}

# crea un filtro para una una entidad de destino
sub crear_filtro_destino {
    my $destino = $_[0];

    return sub {
        my %data = %{$_[0]};
        return $data{'cbu_destino'} =~ /^$destino/;
    };
}

sub crear_filtro_estado {
    my $estado = $_[0];

    return sub {
        my %data = %{$_[0]};
        return $data{'estado'} =~ /^$estado/;
    };
}

# crea un filtro para un estado y lo agrega al pipeline de filtros
sub agregar_filtro_estado {
    my ($k, $v) = @_;

    if( $v =~ /^(${RE_ESTADO})$/i ) {
        push @filtros, crear_filtro_estado( lc $1 );
    } else {
        die "valor de estado inválido $v.\n";
    }
}

# crea un filtro para una fecha base y lo agrega al pipeline de filtros
sub agregar_filtro_fecha_desde {
    my ($k, $v) = @_;

    my $superior = 0;
    push @filtros, crear_filtro_fecha( $v, $superior );
}

# crea un filtro para una fecha final y lo agrega al pipeline de filtros
sub agregar_filtro_fecha_hasta {
    my ($k, $v) = @_;

    my $superior = 1;
    push @filtros, crear_filtro_fecha( $v, $superior );
}

# loggea un mensaje
sub logger {
    # TODO: loggear al archivo correspondiente
    print STDERR @_;
    print STDERR "\n";
}

# convierte el codigo de una entidad al nombre correspondiente
sub codigo2entidad($) {
    # TODO: leer del maestro de bancos y retornar el nombre adecuado
    $_[0] or die "Código de entidad inválido.\n";
    $_[0] =~ /^\d{3}$/ or die "Código de entidad inválido: $_[0]\n";
    return $_[0];
}

# parsea una transaccion desde una linea leida del archivo
# si el formato es valido, retorna un hash con los campos y los valores asociados
# si el formato es invalido, retorna 0
# recibe la linea de texto a parsear como parametro
sub parsear_transaccion {
    my $linea = $_[0];

    if( $linea =~ /^(${RE_FECHA});(${RE_MONTO});(${RE_ESTADO});(${RE_CBU});(${RE_CBU})$/i ) {
        # las variables de los matches se tienen que copiar a variables locales o sino se pierden
        # cuando se sale del scope
        my ($fecha, $monto, $estado, $cbu_origen, $cbu_destino) = ($1, $2, $3, $4, $5);
        $monto  =~ s/,/./;
        return (
            'fecha'       => $fecha,
            'monto'       => $monto,
            'estado'      => $estado,
            'cbu_origen'  => $cbu_origen,
            'cbu_destino' => $cbu_destino,
        );
    } else {
        return 0;
    }
}

# lee un archivo con los datos de entrada y lo convierte a un hash
sub parsear_archivo {
    my $archivo = $_[0];
}

# itera cada transaccion en un archivo aplicando la subrutina a cada una
# el primer parametro es el file pointer
# el segundo parametro es el puntero al array de filtros
# el tercer parametro es la subrutina que se ejecura para cada transaccion
#    la subrutina recibe el hash con los datos de la transaccion (ver parsear_transaccion)
sub iterar_archivo {
    my ($fp, $filtros, $cb) = @_;

    # itera cada línea del archivo procesando la transacción
    LINEA:
    while( my $linea = <$fp> ) {
        # procesa la transaccion y retorna los campos en un hash
        my %datos = parsear_transaccion $linea;
        if( not %datos ) {
            logger "Formato de transacción inválido: $linea\n";
            next;
        }
        # pasa la transaccion por los filtros
        for my $f (@{$filtros}) {
            if( not $f->( \%datos ) ) {
                # si el filtro no aprueba, se ignora la transaccion
                next LINEA;
            }
        }

        # se ejecuta la accion generica para esta transaccion
        $cb->( \%datos );
    }
}

# subcomando para generar listados
# recibe un puntero al array de filtros
sub listado {
    my $filtros = shift;
    my $total = 0;

    # TODO: buscar los archivos que estan en el rango correcto de fechas
    opendir( DIR, $DIR_TRANSFER );
    my @archivos = grep(/${RE_FECHA}.txt/,readdir(DIR));
    closedir( DIR );

    print "FECHA,IMPORTE,ESTADO,ORIGEN,DESTINO\n";

    foreach my $archivo (@archivos) {
        my $subtotal = 0;

        open my $fp, "$DIR_TRANSFER/$archivo" or die "No se pudo abrir $archivo: $!\n";

        # la subrutina acumula los montos en el total e imprime las transacciones
        iterar_archivo $fp, $filtros, sub {
                                          my %data = %{$_[0]};
                                          print join( ',', $data{'fecha'},
                                                           $data{'monto'},
                                                           $data{'estado'},
                                                           $data{'cbu_origen'},
                                                           $data{'cbu_destino'} ) . "\n";
                                          $total += $data{'monto'};
                                          $subtotal += $data{'monto'};
                                      };

        my ($dia) = $archivo =~ /^\d{6}0?(\d{1,2}).txt/;
        print "subtotal del día $dia,$subtotal\n\n";
    }
    print "total general,$total\n";
}

# realiza un listado por CBU
sub listado_cbu {
    # parsea los argumentos particulares del comando
    my ($cbu, $origen, $destino);
    GetOptions(
        'cbu=s'   => \$cbu,
        'origen'  => \$origen,
        'destino' => \$destino,
        '<>'      => sub{ die "Opción inválida $_[0]\n"; },
    ) or die "Utilice ./consultas.pl help listado-cbu para obtener mas información.\n";

    # valida los parametros del usuario
    if( not $cbu ) {
        die "Se require un CBU.\n";
    } elsif( $cbu !~ /^${RE_CBU}$/ ) {
        die "El CBU ingresado no es válido\n";
    }
    if( not $origen and not $destino ) {
        die "Se debe indicar si el CBU es de origen o destino.\n"
    } elsif( $origen and $destino ) {
        die "Seleccione origen o destino (no ambos).\n"
    }

    my @filtros = @{$_[0]};

    # agrega el filtro por CBU
    if( $origen ) {
        push @filtros, crear_filtro_origen( $cbu );
    } else {
        push @filtros, crear_filtro_destino( $cbu );
    }

    # ejecuta el listado
    print "Transferencias de la cuenta $cbu\n\n";
    listado \@filtros;
}

sub listado_origen {
    my @filtros = @{$_[0]};
    my ($entidad, $banco);

    GetOptions(
        'entidad=s' => \$entidad,
        '<>'      => sub{ die "Opción inválida $_[0]\n"; },
    ) or die "Utilice ./consultas.pl help listado-origen para obtener mas información.\n";

    if( not $entidad ) {
        die "Se require una entidad\n";
    }
    $banco = codigo2entidad $entidad;

    # agrega el filtro correspondiente
    push @filtros, crear_filtro_origen( $entidad );

    # imprime el titulo y genera el listado
    print "Transferencias del banco $banco hacia otras entidades bancarias\n\n";
    listado \@filtros;
}

sub listado_destino {
    my @filtros = @{$_[0]};
    my ($entidad, $banco);

    GetOptions(
        'entidad=s' => \$entidad,
        '<>'      => sub{ die "Opción inválida $_[0]\n"; },
    ) or die "Utilice ./consultas.pl help listado-destino para obtener mas información.\n";

    if( not $entidad ) {
        die "Se require una entidad\n";
    }
    $banco = codigo2entidad $entidad;

    # agrega el filtro correspondiente
    push @filtros, crear_filtro_destino( $entidad );

    # imprime el titulo y genera el listado
    print "Transferencias desde otras entidades hacia el banco $banco\n\n";
    listado \@filtros;
}

# routinas de cada subcomando
my %COMANDOS = (
    'listado-origen'  => \&listado_origen,
    'listado-destino' => \&listado_destino,
    'listado-cbu'     => \&listado_cbu,
    'balance' => sub { die "IMPLEMENTAR"; }, # TODO
    'ranking' => sub { die "IMPLEMENTAR"; }, # TODO
);

# variables ingresadas por parámetro
my ($subcomando, @fuentes, @origen, @destino);

# parsea los parámetros de entrada generando los filtros de búsqueda
GetOptions('help|h'          => \&help,
           'fuente|f=s@'     => \@fuentes,
           'estado|e=s@'     => \&agregar_filtro_estado,
           'origen|o=s'      => \@origen,
           'destino|d=s'     => \@destino,
           'fecha-desde|s=s' => \&agregar_filtro_fecha_desde,
           'fecha-hasta|u=s' => \&agregar_filtro_fecha_hasta,
           "<>"              => sub {
                                    # al encontrar una opcion desconocida se dejan de parsear los
                                    # parametros y se asume que debe ser un sub-comando
                                    # el resto de los parametros no se validan, ya que de eso se
                                    # encarga la subrutina de cada sub-comando
                                    if ($_[0] =~ /^-/) {
                                        die "Opción inválida $_[0]\n";
                                    } else {
                                        $subcomando = $_[0];
                                        die "!FINISH";
                                    }
                                })
    or die "Utilice -h/--help para obtener mas información\n";

# valida el subcomando
my $cb;
if( $subcomando ) {
    $cb = $COMANDOS{$subcomando};
    if( not $cb ) {
        die "Comando inválido: $subcomando.\nSe esperaba " . join( "|", keys %COMANDOS ) . "\n";
    }
} else {
    die "No se indicó ningún comando.\n";
}

# crea los filtros para aplicar a las transacciones
# crea un filtro para las fuentes
if( @fuentes ) {
    # crea un filtro OR con todos los filtros para fuentes y lo mete en la lista final
    push @filtros, factory_filtros_or( \@fuentes, \&crear_filtro_fuente );
}

# crea un filtro para la entidad de origen
if( @origen ) {
    push @filtros, factory_filtros_or( \@origen, \&crear_filtro_origen );
}

# crea un filtro para la entidad de destino
if( @destino ) {
    push @filtros, factory_filtros_or( \@destino, \&crear_filtro_destino );
}

# ejecuta el subcomando con las transacciones filtradas
$cb->( \@filtros );
