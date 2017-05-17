#!/usr/bin/env perl


# verifica el entorno
if( not defined $ENV{'DIRMAE'} or
    not defined $ENV{'DIRPROC'} or
    not defined $ENV{'DIRLIBS'} or
    not defined $ENV{'DIRINFO'} ) {
    die "No se inicializó el ambiente.\n";
}

use lib $ENV{'DIRLIBS'};
use Tee;
use warnings;
use strict;
use Getopt::Long;
use Time::Local;
use List::Util qw(reduce);
use POSIX qw(strftime);
use Data::Dumper;


#$SIG{'__DIE__'} = sub { require Carp; Carp::confess };

Getopt::Long::Configure("pass_through");


# expresion regular para validar fechas en la entrada
our $RE_FECHA = q/\d{8}/;

# expresion regular para validar el estado de la transacción
our $RE_ESTADO = q/pendiente|anulada/;

# expresion regular para validar montos
our $RE_MONTO = q/-?\d+\,\d{2}/;

# expresion regular para CBUs
our $RE_CBU = qw/\d{22}/;

# un hash que mappea el código de la entidad al nombre
our %ENTIDADES;

# un hash que mappea el nombre de la entidad al código
our %CODIGOS;


# muestra el mesaje de ayuda
sub help {
    my $subcomando = shift @ARGV;
    if( $subcomando ) {
        if( $subcomando eq 'help' ) {
            print "Muestra ayuda sobre un comando.\n";
        } elsif( $subcomando eq 'listado-origen' ) {
            print "Lista las transacciones originadas en una cierta entidad.\n";
            print "  --entidad      Indica la entidad a listar (puede repetirse).\n";
            print "  --detalle      Mostrar el detalle de las transacciones.\n";
        } elsif( $subcomando eq 'listado-destino' ) {
            print "Lista las transacciones hacia una cierta entidad.\n";
            print "  --entidad      Indica la entidad a listar (puede repetirse).\n";
            print "  --detalle      Mostrar el detalle de las transacciones.\n";
        } elsif( $subcomando eq 'listado-cbu' ) {
            print "Lista las transacciones para una cierta cuenta.\n";
            print "  --cbu          CBU del cual listar las operaciones.\n";
            print "  --detalle      Mostrar el detalle de las transacciones.\n";
        } elsif( $subcomando eq 'ranking' ) {
            print "Lista las 3 transacciones que mas emitieron y recibieron.\n";
        } elsif( $subcomando eq 'balance-entidad' ) {
            print "Realiza un balance entre 1 entidad y todas las demás.\n";
            print "  --entidad      Entidad a la cual realizar el balance (puede repetirse).\n";
            print "  --detalle      Mostrar el detalle de las transacciones.\n";
        } elsif( $subcomando eq 'balance-entre' ) {
            print "Realiza un balance entre 2 entidades.\n";
            print "Recibe varios argumentos, los cuales son pares de entidades entre las cuales\n";
            print "se realiza el balance. Por ejemplo:\n";
            print "  ./consultas.pl BACOR-HSBC 014-TOKYO\n";
        } else {
            die "Subcomando inválido: $subcomando\n";
        }
        exit 0;
    }

    print<<EOF;
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
  --salida             Guardar el reporte en un archivo.
  --verbose            Mostrar el reporte por pantalla (se activa por defecto si --salida no está
                       presente).

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

Para ver las opciones específicas de cada comando utilice
  ./consultas.pl help COMANDO
EOF
    exit 0;
}

# lee el maestro de bancos y carga los valores en el hash de salida
sub leer_maestro_bancos {
    my ($entidades, $codigos) = (shift, shift);
    my $archivo = $ENV{'DIRMAE'} . '/bancos.csv';

    open my $fp, $archivo or die "No se pudo abrir el maestro de bancos $archivo: $!\n";

    my $contador = 1;
    while (my $linea = <$fp>) {
        my @campos = split /;/, $linea;
        scalar @campos == 3 or die "Formato del maestro de bancos inesperado.\nLinea $contador: $linea\n";

        $entidades->{$campos[1]} = $campos[0];
        $codigos->{$campos[0]} = $campos[1];
        $contador += 1;
    }
}


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

    my ($year, $month, $day) = unpack "A4 A2 A2", $fecha;
    eval{ timelocal(0,0,0,$day, $month-1, $year); 1; } or die "Fecha inválida: $@\n";

    if( $superior ) {
        return sub {
            my ($fecha_fuente) = $_[0] =~ s/\.txt$//r;
            return ($fecha gt $fecha_fuente or $fecha eq $fecha_fuente);
        };
    } else {
        return sub {
            my ($fecha_fuente) = $_[0] =~ s/\.txt$//r;
            return ($fecha lt $fecha_fuente or $fecha eq $fecha_fuente);
        };
    }
}

# crea un filtro para una fuente específica
sub crear_filtro_fuente {
    my $fuente = $_[0];

    if( $fuente !~ /^${RE_FECHA}.txt$/ ) {
        die "Los nombres de fuentes deben tener el formato 'aaaammdd.txt'\n";
    }

    return sub {
        return $_[0] eq $fuente;
    };
}

# crea un filtro para un importe minimo o tope
sub crear_filtro_importe {
    my ($importe, $minimo) = @_;

    $importe =~ /(^-?\d+\.\d{2}$)|(^\-?\d+$)/ or die "Importe inválido: $importe.\n";

    return sub {
        my %data = %{$_[0]};
        if( $minimo ) {
            return $data{'importe'} >= $importe;
        } else {
            return $data{'importe'} <= $importe;
        }
    };
}

# crea un filtro para una una entidad de origen
sub crear_filtro_origen {
    my $origen = shift;

    $origen or die "Error!";

    if( $origen !~ /^${RE_CBU}$/ ) {
        $origen = entidad2codigo( $origen );
    }

    return sub {
        my %data = %{$_[0]};
        return $data{'cbu_origen'} =~ /^$origen/;
    };
}

# crea un filtro para una una entidad de destino
sub crear_filtro_destino {
    my $destino = shift;

    if( $destino !~ /^${RE_CBU}$/ ) {
        $destino = entidad2codigo( $destino );
    }

    return sub {
        my %data = %{$_[0]};
        return $data{'cbu_destino'} =~ /^$destino/;
    };
}

sub crear_filtro_estado {
    my $estado = lc $_[0];

    if( $estado !~ /^(${RE_ESTADO})$/i ) {
        die "valor de estado inválido: $estado.\n";
    }

    return sub {
        my %data = %{$_[0]};
        return $data{'estado'} =~ /^$estado$/;
    };
}

# loggea un mensaje
sub logger {
    # TODO: loggear al archivo correspondiente
    print STDERR @_;
    print STDERR "\n";
}

sub min($$) {
    my ($x, $y) = @_;
    return ($x, $y)[$x > $y];
}

sub max($$) {
    my ($x, $y) = @_;
    return ($x, $y)[$x < $y];
}

# convierte el codigo de una entidad al nombre correspondiente
sub entidad2codigo($) {
    my $rv = $_[0];
    if( exists $CODIGOS{$rv} ) {
        $rv = $CODIGOS{$rv};
    }

    exists $ENTIDADES{$rv} or die "Entidad desconocida: $rv.\n";
    return $rv;
}

# convierte la entidad al codigo correspondiente
sub codigo2entidad($) {
    my $rv = $_[0];
    if( exists $ENTIDADES{$rv} ) {
        $rv = $ENTIDADES{$rv};
    }

    exists $CODIGOS{$rv} or die "Entidad desconocida: $rv.\n";
    return $rv;
}

# retorna los archivos fuente a analizar recibe como parametro una lista de filtros para los archivos
sub listar_archivos_fuente {
    my $filtros = shift;

    my $dir = $ENV{'DIRINFO'} . "/" . "transfer";
    opendir( DIR, $dir ) or die "Directorio inválido: $dir\n";
    my @archivos = grep(/${RE_FECHA}.txt/,readdir(DIR)) or die "No se pudo leer el directorio $dir\n";
    closedir( DIR );

    my @filtrados;

    ARCHIVO:
    for my $archivo (@archivos) {
        # pasa nombre del archivo por los filtros
        for my $f (@{$filtros}) {
            if( not $f->( $archivo ) ) {
                # si el filtro no aprueba, se ignora
                next ARCHIVO;
            }
        }
        # todos los filtros pasaron
        push @filtrados, $dir . "/" . $archivo;
    }

    return sort @filtrados;
}

# parsea una transaccion desde una linea leida del archivo
# si el formato es valido, retorna un hash con los campos y los valores asociados
# si el formato es invalido, retorna 0
# recibe la linea de texto a parsear como parametro
sub parsear_transaccion {
    my $linea = $_[0];

    if( $linea =~ /^(.*?);.*?;(\d{3});.*?;(\d{3});(${RE_FECHA});(${RE_MONTO});(${RE_ESTADO});(${RE_CBU});(${RE_CBU})$/i ) {
        # las variables de los matches se tienen que copiar a variables locales o sino se pierden
        # cuando se sale del scope
        my ($fuente, $origen, $destino, $fecha, $importe, $estado, $cbu_origen, $cbu_destino) = ($1, $2, $3, $4, $5, $6, $7, $8);
        $importe  =~ s/,/./;
        return (
            'fuente'      => $fuente,
            'fecha'       => $fecha,
            'importe'     => $importe,
            'estado'      => lc $estado,
            'cbu_origen'  => $cbu_origen,
            'cbu_destino' => $cbu_destino,
            'origen'      => codigo2entidad $origen,
            'destino'     => codigo2entidad $destino,
        );
    } else {
        return ();
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

# dada una lista de archivos, los recorre parseando las transacciones y aplicando los filtros.
# por cada archivo se ejecuta una subrutina, y luego se itera cada transaccion.
# si los filtros aprobaron la transaccion, se ejecuta la subrutina que recibe los datos de la
# transaccion en un hash.
# paramtros: referencia a lista de archivos, referencia a lista de filtros, subrutina
sub iterar_archivos($$$$) {
    my ($archivos, $filtros, $cb_archivo, $cb_transaccion) = @_;
}

# subcomando para generar listados
# recibe un puntero al array de filtros
sub listado {
    my ($filtros, $fuentes, $detalle) = @_;
    my $total = 0;
    my @archivos = @{$fuentes};

    if( $detalle ) {
        print "FECHA,IMPORTE,ESTADO,ORIGEN,DESTINO\n";
    } else {
        print "FECHA,IMPORTE\n";
    }

    foreach my $archivo (@archivos) {
        my $subtotal = 0;

        open my $fp, $archivo or die "No se pudo abrir $archivo: $!\n";

        # la subrutina acumula los montos en el total e imprime las transacciones
        iterar_archivo $fp, $filtros, sub {
                                          my %data = %{$_[0]};
                                          if( $detalle ) {
                                              print join( ',', $data{'fecha'},
                                                               $data{'importe'},
                                                               $data{'estado'},
                                                               $data{'cbu_origen'},
                                                               $data{'cbu_destino'} ) . "\n";
                                          }
                                          $total += $data{'importe'};
                                          $subtotal += $data{'importe'};
                                      };

        if( $subtotal != 0 ) {
            my ($dia) = $archivo =~ /\d{6}0?(\d{1,2}).txt$/;
            print "subtotal del día $dia,$subtotal\n";
            if( $detalle ) { print "\n"; }
        }
    }
    print "total general,$total\n";
}

# realiza un listado por CBU
sub listado_cbu {
    # parsea los argumentos particulares del comando
    my ($cbu, $detalle);
    GetOptions(
        'detalle' => \$detalle,
        'cbu=s'   => \$cbu,
        '<>'      => sub{ die "Opción inválida $_[0]\n"; },
    ) or die "Utilice ./consultas.pl help listado-cbu para obtener ayuda.\n";

    # valida los parametros del usuario
    if( not $cbu ) {
        die "Se require un CBU.\n";
    } elsif( $cbu !~ /^${RE_CBU}$/ ) {
        die "El CBU ingresado no es válido\n";
    }

    my @filtros_origen = @{$_[0]};
    my @filtros_destino = @{$_[0]};
    my $fuentes = $_[1];

    # agrega el filtro por CBU
    push @filtros_origen, crear_filtro_origen( $cbu );
    push @filtros_destino, crear_filtro_destino( $cbu );

    # ejecuta el listado
    print "Transferencias de la cuenta $cbu\n\n";

    if( $detalle ) {
        print "FECHA,IMPORTE,ESTADO,ORIGEN,DESTINO\n";
    } else {
        print "FECHA,IMPORTE\n";
    }

    my ($ingresos, $egresos) = (0, 0);
    foreach my $archivo (@{$fuentes}) {
        my $subtotal = 0;
        my $fp;

        open $fp, $archivo or die "No se pudo abrir $archivo: $!\n";

        # la subrutina acumula los montos en el total e imprime las transacciones
        iterar_archivo $fp, \@filtros_origen, sub {
                                          my %data = %{$_[0]};
                                          if( $detalle ) {
                                              print join( ',', $data{'fecha'},
                                                               $data{'importe'},
                                                               $data{'estado'},
                                                               $data{'cbu_origen'},
                                                               $data{'cbu_destino'} ) . "\n";
                                          }
                                          $subtotal += $data{'importe'};
                                      };
        close $fp;

        if( $subtotal != 0 ) {
            my ($dia) = $archivo =~ /\d{6}0?(\d{1,2}).txt$/;
            print "subtotal del día $dia,$subtotal\n";
            if( $detalle ) { print "\n"; }
            $egresos += $subtotal;
        }


        open $fp, $archivo or die "No se pudo abrir $archivo: $!\n";

        # la subrutina acumula los montos en el total e imprime las transacciones
        $subtotal = 0;
        iterar_archivo $fp, \@filtros_destino, sub {
                                          my %data = %{$_[0]};
                                          if( $detalle ) {
                                              print join( ',', $data{'fecha'},
                                                               $data{'importe'},
                                                               $data{'estado'},
                                                               $data{'cbu_origen'},
                                                               $data{'cbu_destino'} ) . "\n";
                                          }
                                          $subtotal += $data{'importe'};
                                      };
        close $fp;

        if( $subtotal != 0 ) {
            my ($dia) = $archivo =~ /\d{6}0?(\d{1,2}).txt$/;
            print "subtotal del día $dia,$subtotal\n";
            if( $detalle ) { print "\n"; }
            $ingresos += $subtotal;
        }
    }

    my $balance = $ingresos - $egresos;
    my $signo = ('NEUTRO', 'POSITIVO', 'NEGATIVO')[$balance <=> 0];
    print "Balance $signo,$balance,para $cbu\n\n";
}

sub listado_origen {
    my @filtros = @{$_[0]};
    my $fuentes = $_[1];
    my ($entidad, $banco, $detalle);

    GetOptions(
        'detalle'   => \$detalle,
        'entidad=s' => \$entidad,
        '<>'      => sub{ die "Opción inválida $_[0]\n"; },
    ) or die "Utilice ./consultas.pl help listado-origen para obtener ayuda.\n";

    if( not $entidad ) {
        die "Se require una entidad\n";
    }
    $banco = codigo2entidad( $entidad );

    # agrega el filtro correspondiente
    push @filtros, crear_filtro_origen( $entidad );

    # imprime el titulo y genera el listado
    print "Transferencias del banco $banco hacia otras entidades bancarias\n\n";
    listado \@filtros, $fuentes, $detalle;
}

sub listado_destino {
    my @filtros = @{$_[0]};
    my $fuentes = $_[1];
    my ($entidad, $banco, $detalle);

    GetOptions(
        'detalle'   => \$detalle,
        'entidad=s' => \$entidad,
        '<>'        => sub{ die "Opción inválida $_[0]\n"; },
    ) or die "Utilice ./consultas.pl help listado-destino para obtener ayuda.\n";

    if( not $entidad ) {
        die "Se require una entidad\n";
    }
    $banco = codigo2entidad( $entidad );

    # agrega el filtro correspondiente
    push @filtros, crear_filtro_destino( $entidad );

    # imprime el titulo y genera el listado
    print "Transferencias desde otras entidades hacia el banco $banco\n\n";
    listado \@filtros, $fuentes, $detalle;
}

sub ranking {
    GetOptions('<>' => sub { die "El comando ranking no acepta parámetros de entrada.\n" });

    my ($filtros, $fuentes) = @_;
    my %balance = map { $_ => 0 } keys %CODIGOS;
    my @archivos = @{$fuentes};

    foreach my $archivo (@archivos) {
        open my $fp, $archivo or die "No se pudo abrir $archivo: $!\n";

        # la subrutina acumula los montos ingresados y emitidos para cada entidad
        iterar_archivo $fp, $filtros, sub {
                                          my %data = %{$_[0]};

                                          # se ignoran las transferencias internas
                                          if( $data{'origen'} eq $data{'destino'} ) {
                                            return;
                                          }

                                          $balance{$data{'destino'}} += $data{'importe'};
                                          $balance{$data{'origen'}} -= $data{'importe'};
                                      };
    }

    my @claves = sort { $balance{$b} <=> $balance{$a} } keys(%balance);
    my (@top_ingresos, @top_egresos);

    for my $entidad (@claves) {
        if( $balance{$entidad} <= 0 or scalar @top_ingresos == 3 ) {
            while( scalar @top_ingresos < 3 ) { push @top_ingresos, '-'; }
            last;
        }
        push @top_ingresos, $entidad;
    }

    for my $entidad (reverse @claves) {
        if( $balance{$entidad} >= 0 or scalar @top_egresos == 3 ) {
            while( scalar @top_egresos < 3 ) { push @top_egresos, '-'; }
            last;
        }
        push @top_egresos, $entidad;
    }

    $balance{'-'} = '-';

    print "Top 3 ingresos\n";
    print join( "\n", map { "$_,$balance{$_}" } @top_ingresos ) . "\n";

    print "\nTop 3 egresos\n";
    print join( "\n", map { my $v = abs $balance{$_}; "$_,$v" } @top_egresos ) . "\n";
}

# realiza un balance entre una cierta entidad y otra(s)
sub balance {
    my ($filtros, $fuentes, $detalle, $entidad, @otras) = @_;

    $entidad = codigo2entidad $entidad;
    @otras = map { codigo2entidad $_ } @otras;

    # crea un hash con una clave para cada entidad con balance inicial 0
    my %ingresos = map { $_ => 0 } @otras;
    my %egresos  = map { $_ => 0 } @otras;
    my @archivos = @{$fuentes};

    # copia los filtros
    my @filtros = @{$filtros};

    # agrega un filtro para las otras entidades
    push @filtros, crear_filtro_or(
                          factory_filtros_or( \@otras, \&crear_filtro_origen ),
                          factory_filtros_or( \@otras, \&crear_filtro_destino ));
    # agrega un filtro para la entidad en particular
    push @filtros, crear_filtro_or(
                          crear_filtro_origen( $entidad ), crear_filtro_destino( $entidad ));

    # recorre los archivos y las transacciones
    foreach my $archivo (@archivos) {
        open my $fp, $archivo or die "No se pudo abrir $archivo: $!\n";

        # la subrutina acumula el balance para cada entidad
        iterar_archivo $fp, \@filtros, sub {
                                          my %data = %{$_[0]};
                                          if( $data{'origen'} eq $data{'destino'} ) {
                                            return;
                                          }

                                          if( $detalle and $data{'origen'} eq $entidad ) {
                                              print join( ',', $data{'fecha'},
                                                               $data{'importe'},
                                                               $data{'estado'},
                                                               $data{'cbu_origen'},
                                                               $data{'cbu_destino'} ) . "\n";
                                          }

                                          # es una transaccion desde una de las entidades?
                                          if( $data{'origen'} eq $entidad ) {
                                              $egresos{$data{'destino'}} += $data{'importe'};
                                          }

                                          # o es hacia una?
                                          if( $data{'destino'} eq $entidad ) {
                                              $ingresos{$data{'origen'}} += $data{'importe'};
                                          }
                                      };
    }

    return (\%ingresos, \%egresos);
}

sub balance_entre_entidades {
    my ($filtros, $fuentes) = @_;
    my (@pares, $detalle);

    GetOptions(
        'detalle' => \$detalle,
        '<>'      => sub{
                            $_[0] =~ /^(.*)-(.*)$/ or die "Opción inválida $_[0]\n";
                            my $e1 = codigo2entidad $1;
                            my $e2 = codigo2entidad $2;

                            if( not $e1 ) {
                                die "entidad inválida: $e1\n";
                            } elsif( not $e2 ) {
                                die "entidad inválida: $e2\n";
                            }

                            push @pares, $e1, $e2;
                       },
    ) or die "Utilice ./consultas.pl help balance-entre para obtener ayuda.\n";


    for my $i (0 .. (scalar @pares / 2 - 1 )) {
        $i *= 2;
        my ($entidad1, $entidad2) = ($pares[$i], $pares[$i+1]);

        print "Transferencias entre $entidad1 y $entidad2\n";

        my ($ingresos_ref, $egresos_ref) = balance $filtros, $fuentes, $detalle, $entidad1, $entidad2;
        my %ingresos = %{$ingresos_ref};
        my %egresos = %{$egresos_ref};

        print "Desde $entidad1 hacia $entidad2,$egresos{$entidad2}\n";
        my $balance = $ingresos{$entidad2} - $egresos{$entidad2};

        ($ingresos_ref, $egresos_ref) = balance $filtros, $fuentes, $detalle, $entidad2, $entidad1;
        %ingresos = %{$ingresos_ref};
        %egresos = %{$egresos_ref};

        print "Desde $entidad2 hacia $entidad1,$egresos{$entidad1}\n";

        my $signo = ('NEUTRO', 'POSITIVO', 'NEGATIVO')[$balance <=> 0];
        print "Balance $signo para $entidad1,$balance\n\n";
    }
}

sub balance_por_entidad {
    my (@entidades, $detalle);

    GetOptions(
        '--detalle'    => \$detalle,
        '--entidad=s@' => \@entidades,
        '<>'           => sub{ die "Opción inválida $_[0]\n"; },
    ) or die "Utilice ./consultas.pl help balance-entidad para obtener ayuda.\n";

    my ($filtros, $fuentes) = @_;

    if( scalar @entidades == 0 ) {
        @entidades = keys %CODIGOS;
    }

    # imprime el resultado por cada entidad
    for my $entidad (sort @entidades) {
        my ($ingresos, $egresos) = balance $filtros, $fuentes, $detalle, $entidad, keys %CODIGOS;

        my $ingreso = reduce { $a + $b } values %{$ingresos};
        my $egreso = reduce { $a + $b } values %{$egresos};

        my $balance = $ingreso - $egreso;
        my $signo = ('NEUTRO', 'POSITIVO', 'NEGATIVO')[$balance <=> 0];

        print "Desde $entidad,$egreso,Hacia otras entidades\n";

        # TODO: imprimir las transferencias desde otras entidades a $entidad

        print "Hacia $entidad,$ingreso,Desde otras entidades\n";
        print "Balance $signo para $entidad,$balance\n";
        print "\n";
    }
}


my %DIR_REPORTE = (
    'listado-origen'  => '/listados/',
    'listado-destino' => '/listados/',
    'listado-cbu'     => '/listados/',
    'ranking'         => '/listados/',
    'balance-entidad' => '/balances/',
    'balance-entre'   => '/balances/',
);

sub nombre_reporte {
    my $subcomando = shift;

    if( not $DIR_REPORTE{$subcomando} ) {
        die "EL comando $subcomando no soporta la opción --salida.\n";
    }

    my $datestring = strftime "%Y-%m-%dT%H:%M:%S", localtime;
    my $dir = $ENV{'DIRINFO'} . $DIR_REPORTE{$subcomando};
    my @archivos = <$dir/*>;
    my $seq = 0;

    for my $archivo (@archivos) {
        if( $archivo =~ /${datestring}\.(\d+)\.txt$/ ) {
            if( $seq == $1 ) {
                $seq += 1;
            } else {
                $seq = max($seq, $1);
            }
        }
    }

    mkdir $dir unless -d $dir;

    return $dir . $datestring . '.' . $seq . '.txt';
}

# routinas de cada subcomando
my %COMANDOS = (
    'listado-origen'  => \&listado_origen,
    'listado-destino' => \&listado_destino,
    'listado-cbu'     => \&listado_cbu,
    'ranking'         => \&ranking,
    'balance-entidad' => \&balance_por_entidad,
    'balance-entre'   => \&balance_entre_entidades,
    'help'            => \&help,
);


# carga los datos del maestro
leer_maestro_bancos \%ENTIDADES, \%CODIGOS;


# array de filtros para aplicar a la búsqueda
# los filtros se arman en base a los parámetros de entrada usando GetOptions
my @filtros;

# variables ingresadas por parámetro
my ($subcomando, @fuentes, @origen, @destino, $verbose, $salida, $estado, $fecha_desde, $fecha_hasta);

# parsea los parámetros de entrada generando los filtros de búsqueda
GetOptions('help|h'            => \&help,
           'verbose'           => \$verbose,
           'salida'            => \$salida,
           'fuente|f=s@'       => \@fuentes,
           'estado|e=s'        => \$estado,
           'origen|o=s'        => \@origen,
           'destino|d=s'       => \@destino,
           'fecha-desde|s=s'   => \$fecha_desde,
           'fecha-hasta|u=s'   => \$fecha_hasta,
           'importe-desde|i=s' => sub { push @filtros, crear_filtro_importe( $_[1], 1 ); },
           'importe-hasta|l=s' => sub { push @filtros, crear_filtro_importe( $_[1], 0 ); },
           "<>"                => sub {
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
    or die "Utilice -h/--help para obtener ayuda.\n";

# valida el subcomando
my $cb;
if( $subcomando ) {
    $cb = $COMANDOS{$subcomando};
    if( not $cb ) {
        die "Comando inválido: $subcomando.\nSe esperaba " . join( "|", keys %COMANDOS ) . "\n";
    }
} else {
    die "No se indicó ningún comando.\nSe esperaba " . join( "|", keys %COMANDOS ) . "\n";
}

# crea los filtros para aplicar a las transacciones
# crea un filtro para la entidad de origen
if( @origen ) {
    push @filtros, factory_filtros_or( \@origen, \&crear_filtro_origen );
}

# crea un filtro para la entidad de destino
if( @destino ) {
    push @filtros, factory_filtros_or( \@destino, \&crear_filtro_destino );
}

if( $estado ) {
    push @filtros, crear_filtro_estado( $estado );
}

# crea los filtros para las fuentes
my @filtros_fuentes;
if( @fuentes ) {
    # crea un filtro OR con todos los filtros para fuentes y lo mete en la lista final
    push @filtros_fuentes, factory_filtros_or( \@fuentes, \&crear_filtro_fuente );
}
if( $fecha_hasta ) {
    push @filtros_fuentes, crear_filtro_fecha( $fecha_hasta, 1 );
}
if( $fecha_desde ) {
    push @filtros_fuentes, crear_filtro_fecha( $fecha_desde, 0 );
}

# obtiene la lista de fuentes
my @archivos = listar_archivos_fuente \@filtros_fuentes;
if( scalar @archivos == 0 ) {
    die "No hay archivos fuentes.\n";
}

# redirecciona la salida
my $fp;
if( $salida ) {
    open my $fp, '>', nombre_reporte( $subcomando ) or die "No se pudo crear $salida: $!\n";
    if( $verbose ) {
        my $tee=IO::Tee->new( $fp, \*STDOUT );
        select $tee;
    } else {
        select $fp;
    }
}

# imprime los fuentes que va a utilizar
print join( ',', map { $_ =~ s/.*\///r } @archivos ) . "\n";

# ejecuta el subcomando y se le pasan los filtros gobales
$cb->( \@filtros, \@archivos );

if( $fp ) {
    close $fp;
}
