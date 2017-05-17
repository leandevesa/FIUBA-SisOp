import random


BANCOS = {
    '003': 'BAPRO',
    '009': 'BAER',
    '011': 'CITI',
    '012': 'TOKYO',
    '013': 'BACOR',
    '014': 'HSBC',
    '015': 'ICBC',
    '016': 'NACION',
    '017': 'SRIO',
    '018': 'BBVA',
    '023': 'SVIELLE',
    '028': 'MACRO',
    '087': 'GALICIA',
    '332': 'BSF',
    '336': 'BRA',
    '338': 'BST',
    '339': 'RCI',
    '340': 'BACS',
    '341': 'MVTA',
    '386': 'NBER',
    '389': 'COL',
}


def gen_cbu(entidad):
    assert len(entidad) == 3
    return entidad + ''.join(str(random.randint(0, 9)) for _ in range(19))

def gen_importe():
    ent, dec = random.randint(1, 20000), random.randint(0, 99)
    signo = random.choice(['', '', '', '', '', '-'])
    return '%s%d,%0.2d' % (signo, ent, dec)


if __name__ == '__main__':
    random.seed(0)

    fechas = ['20170501', '20170502', '20170503']
    cbus = [gen_cbu(entidad) for entidad in BANCOS for _ in range(3)]

    for fecha in fechas:
        with open(fecha + '.txt', 'w') as fp:
            for i in range(30):
                # FECHA;ORIGEN;COD ORIGEN;DESTINO;COD DESTINO;FECHA;IMPORTE;ESTADO;CBU ORIGEN;CBU DESTINO}

                cbu_origen = random.choice(cbus)
                cbu_destino = random.choice(cbus)
                cod_origen, cod_dest = cbu_origen[:3], cbu_destino[:3]
                origen, destino = BANCOS[cod_origen], BANCOS[cod_dest]
                importe = gen_importe()
                estado =  random.choice(['anulada', 'pendiente'])

                fuente = '%s_%s.csv' % (random.choice(BANCOS), fecha)
                transaccion = ';'.join([fuente, origen, cod_origen, destino, cod_dest, fecha, importe, estado, cbu_origen, cbu_destino])
                fp.write(transaccion + '\n')
