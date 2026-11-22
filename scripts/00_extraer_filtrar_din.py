"""Extrae los RAR mensuales de DIN 2025 y guarda solo los items de las partidas 8703 (autos, SUV) y 8704 (camionetas, furgones, camiones).
Uso: python3 -I filtrar_din.py <carpeta_rar> <diccionario.xlsx> <carpeta_salida>
"""
import csv, glob, io, os, re, sys
import libarchive, openpyxl

rar_dir, dicc, out_dir = sys.argv[1:4]
os.makedirs(out_dir, exist_ok=True)

wb = openpyxl.load_workbook(dicc, read_only=True)
names = [str(c).strip().replace('-', '_') for c in list(wb['titulos'].iter_rows(values_only=True))[1] if c is not None]
ix = {n: i for i, n in enumerate(names)}

# columnas numéricas con coma decimal -> punto
num_cols = ['FOB', 'FLETE', 'SEGURO', 'CIF', 'TOT_PESO', 'VALEXFAB', 'MONGASFOB', 'MON_178', 'MON_191',
            'CANT_MERC', 'PRE_UNIT', 'CIF_ITEM', 'ADVAL_ALA', 'VALAD', 'OTRO1', 'VAL1', 'OTRO2', 'VAL2',
            'OTRO3', 'VAL3', 'OTRO4', 'VAL4', 'AJU_ITEM', 'MON_OTRO']
num_idx = [ix[c] for c in num_cols if c in ix]

resumen_cols = ['MES', 'NUMENCRIPTADO', 'NUM_UNICO_IMPORTADOR', 'CODCOMUN', 'PA_ORIG', 'PA_ADQ', 'VIA_TRAN',
                'PTO_EMB', 'PTO_DESEM', 'FECACEP', 'CL_COMPRA', 'FORM_PAGO', 'NUMDIAS', 'BCO_COM', 'MONEDA',
                'FOB', 'FLETE', 'SEGURO', 'CIF', 'TOT_ITEMS', 'NUMITEM', 'DNOMBRE', 'DMARCA', 'DVARIEDAD',
                'DOTRO1', 'DOTRO2', 'ATR_5', 'ATR_6', 'CANT_MERC', 'MEDIDA', 'PRE_UNIT', 'ARANC_NAC',
                'NUMACU', 'CIF_ITEM', 'ADVAL_ALA', 'VALAD', 'OTRO1', 'CTA1', 'VAL1', 'OTRO2', 'CTA2', 'VAL2']

meses = {m: i for i, m in enumerate(['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
                                     'septiembre', 'octubre', 'noviembre', 'diciembre'], 1)}

f_all = open(os.path.join(out_dir, 'din2025_vehiculos_todos_paises.csv'), 'w', newline='', encoding='utf-8')
f_de = open(os.path.join(out_dir, 'din2025_vehiculos_alemania_completo.csv'), 'w', newline='', encoding='utf-8')
w_all, w_de = csv.writer(f_all), csv.writer(f_de)
w_all.writerow(resumen_cols)
w_de.writerow(['MES'] + names)

for rar in sorted(glob.glob(os.path.join(rar_dir, '*.rar'))):
    mes = meses[re.search(r'importaciones-(\w+)-2025', os.path.basename(rar)).group(1)]
    total = n8703 = nde = malas = 0
    with libarchive.file_reader(rar) as a:
        for e in a:
            buf = b''
            for b in e.get_blocks():
                buf += b
                *lines, buf = buf.split(b'\n')
                for raw in lines:
                    total += 1
                    p = raw.decode('latin-1').rstrip('\r\n ').split(';')
                    if len(p) != len(names):
                        malas += 1
                        continue
                    if not p[ix['ARANC_NAC']].startswith(('8703', '8704')):
                        continue
                    p = [x.strip() for x in p]
                    for i in num_idx:
                        p[i] = p[i].replace(',', '.')
                    n8703 += 1
                    row = dict(zip(names, p)); row['MES'] = str(mes)
                    w_all.writerow([row[c] for c in resumen_cols])
                    if p[ix['PA_ORIG']] == '563':
                        nde += 1
                        w_de.writerow([mes] + p)
    print(f'{mes:2d} lineas={total} malas={malas} items8703_8704={n8703} alemania={nde}', flush=True)

f_all.close(); f_de.close()
