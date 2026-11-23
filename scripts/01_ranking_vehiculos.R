# =============================================================================
# 01_ranking_vehiculos.R
# Comercio Exterior – EV3 (Grupo 11) · Estudio de mercado
#
# Fuente: Registro de Importaciones (DIN) 2025, Servicio Nacional de Aduanas
#         (datos.gob.cl). Partidas 8703 (autos, SUV) y 8704 (camionetas,
#         furgones, camiones), ya filtradas con scripts/00_extraer_filtrar_din.py
#
# Entrega 7 resultados:
#   1. Modelos de vehículos que más llegaron a Chile en 2025
#   2. Tipos de vehículos que más llegaron (SUV, automóvil, camioneta, etc.)
#   3. Modelos fabricados en Alemania que llegaron a Chile en 2025
#   4. Los 5 SUV fabricados en Alemania más importados
#   5. Validación: ventas BMW vs. importaciones desde Alemania
#   6. Demanda estimada en Ñuble de los 5 SUV
#   7. Plan de compras trimestral (tabla como imagen)
#
# Abrir Comercio_Exterior.Rproj antes de correr (las rutas son relativas).
# =============================================================================

library(dplyr)
library(readr)
library(stringr)
library(ggplot2)
library(forcats)
library(scales)

COD_ALEMANIA <- "563"   # código de país de Aduanas (verificado: BMW, Mercedes, Porsche...)
PRECIO_MIN   <- 1500    # US$ FOB mínimo por unidad para considerar la cantidad válida

# -----------------------------------------------------------------------------
# 1. Leer datos
# -----------------------------------------------------------------------------
din <- read_csv("data/processed/din2025_vehiculos_todos_paises.csv",
                col_types = cols(.default = col_character())) |>
  mutate(across(c(CANT_MERC, PRE_UNIT, CIF_ITEM, FOB, FLETE, SEGURO, CIF, ADVAL_ALA),
                as.numeric))

# -----------------------------------------------------------------------------
# 2. Limpiar
# -----------------------------------------------------------------------------
# a) Cantidades erróneas: algunas DIN traen la cantidad igual al valor en US$
#    (precio unitario de US$ 1). Un vehículo no cuesta menos de US$ 1.500,
#    así que esas filas no se cuentan.
din <- din |> filter(PRE_UNIT >= PRECIO_MIN)

# b) La descripción viene en 7 campos de 30 caracteres. A veces cada campo es un
#    dato (tipo | combustible | marca | modelo | año | cc) y a veces todo viene
#    corrido y separado por "~". Se arma un solo texto para buscar ahí.
din <- din |>
  mutate(
    nombre = str_remove(DNOMBRE, "^[^~]*~") |> str_squish(),     # quita el código interno
    texto  = str_c(str_replace_na(nombre, ""), str_replace_na(DMARCA, ""),
                   str_replace_na(DVARIEDAD, ""), str_replace_na(DOTRO1, ""),
                   str_replace_na(DOTRO2, ""), str_replace_na(ATR_5, ""),
                   str_replace_na(ATR_6, ""), sep = " ") |> str_to_upper() |> str_squish(),
    tipo_txt = str_extract(nombre, "^[^~]+") |> str_to_upper()
  )

# c) Tipo de vehículo (Aduanas usa la carrocería que declara el importador)
din <- din |>
  mutate(tipo = case_when(
    str_detect(tipo_txt, "CASA.?RODANTE|MOTORHOME")                       ~ "Casa rodante",
    str_detect(tipo_txt, "MOTO|CUA[DT]RI|GOLF|ATV|UTV|BUGGY|NIEVE")       ~ "Moto todo terreno / carro de golf",
    str_detect(tipo_txt, "STAT|WAGON|SUV|TODO.?TERRENO|JEEP")             ~ "SUV / station wagon",
    str_detect(tipo_txt, "AUTOMOVIL|AUTO DE TURISMO|SEDAN|HATCH|COUP|CONVERT|AUTO A BATERIA") ~ "Automóvil (sedán, hatchback, coupé)",
    str_detect(tipo_txt, "CAM(I)?ONETA|PICK")                             ~ "Camioneta / pick-up",
    str_detect(tipo_txt, "FURG|VAN|MINIBUS")                              ~ "Furgón / minibús",
    str_detect(tipo_txt, "CHAS|CAMION|TRACTO|TOLVA")                      ~ "Camión / chasis",
    TRUE                                                                  ~ "Otro / sin clasificar"
  ))

# d) Marca: se busca en el texto, con las variantes mal escritas más comunes.
#    El orden importa (ej. "MITSUBISHI FUSO" antes que "MITSUBISHI").
marcas <- c(
  "MERCEDES-BENZ" = "MERCEDES|MERCEDEZ|MERCEDS|MECEDES",
  "LAND ROVER"    = "LAND ROVER|RANGE ROVER",
  "ALFA ROMEO"    = "ALFA ROMEO",
  "MITSUBISHI FUSO" = "MITSUBISHI FUSO|\\bFUSO\\b",
  "GREAT WALL"    = "GREAT WALL|\\bGWM\\b",
  "MG"            = "MORRIS GARAGE|\\bMG\\b|\\bMGZX|MARCA MG",
  "VOLKSWAGEN"    = "VOLKSWAGEN|\\bVW\\b",
  "DONGFENG"      = "DONG ?FENG",
  "LYNK & CO"     = "LYNK|LINK AND CO",
  "SUZUKI"        = "SUZUKI|SUSUKI",
  "ISUZU"         = "ISUZU|ISUZO",
  "KIA"           = "\\bKIA\\b",
  "DS"            = "\\bDS\\b",
  "OMODA"         = "\\bOMODA\\b|\\bOMADA\\b",
  "SSANGYONG / KGM" = "SSANG ?YONG|\\bKGM\\b",
  setNames(nm = c("TOYOTA", "HYUNDAI", "CHEVROLET", "NISSAN", "PEUGEOT", "CITROEN",
    "MAZDA", "SUBARU", "MITSUBISHI", "FORD", "RAM", "JEEP", "DODGE", "CHRYSLER",
    "HONDA", "RENAULT", "FIAT", "OPEL", "BMW", "MINI", "AUDI", "PORSCHE", "VOLVO",
    "TESLA", "LEXUS", "JAGUAR", "CUPRA", "SEAT", "SKODA", "CHERY", "JETOUR",
    "JAECOO", "JMC", "MAHINDRA", "NAMMI", "GEELY", "CHANGAN", "HAVAL", "JAC", "BYD", "DFSK", "BAIC",
    "MAXUS", "FOTON", "KAIYI", "LEAPMOTOR", "ZEEKR", "RIDDARA", "LANDKING", "GAC",
    "KYC", "SHINERAY", "FAW", "HINO", "SCANIA", "IVECO", "INEOS",
    "POLARIS", "YAMAHA", "CAN-AM", "SEGWAY", "CFMOTO", "TAKASAKI", "LIVAN", "SMART")) |>
    (\(x) setNames(paste0("\\b", x, "\\b"), x))()
)

din <- din |>
  mutate(marca = NA_character_)
for (m in names(marcas)) {
  din <- din |>
    mutate(marca = if_else(is.na(marca) & str_detect(texto, marcas[[m]]), m, marca))
}
din <- din |> mutate(marca = coalesce(marca, "OTRA / SIN IDENTIFICAR"))

# e) Modelo:
#    - Formato ordenado (campo 2 = combustible CH/D/ELE..., campo 3 = marca):
#      el modelo es el campo DOTRO1.
#    - Formato corrido: se toma lo que viene después del nombre de la marca.
#    "modelo" = primera palabra del modelo (X1, GLA, CRETA, TIGGO...), sin "NEW"/"ALL".
din <- din |>
  mutate(
    ordenado = !str_detect(nombre, "~") & str_detect(DMARCA, "^(CH|D|ELE|OTS|HEV|PHEV|GLP|GNC)\\b"),
    modelo_detalle = if_else(
      ordenado,
      str_to_upper(DOTRO1),
      str_match(texto, paste0("(?:", marcas[marca], ")\\W*([^~]{0,30})"))[, 2]
    ) |> str_squish(),
    modelo = modelo_detalle |>
      str_remove("^(NEW|ALL NEW|ALL|NUEVO|NUEVA|THE|MOD\\.?|MODELO)\\s+") |>
      str_extract("^[A-Z0-9\\-\\.]+") |>
      str_remove("[\\.\\-]+$"),
    modelo = str_remove(modelo, "(\\d[\\.,]\\d.*|\\dP)$"),   # FRONX1.5 -> FRONX, JIMNY5P -> JIMNY
    # nombres de dos palabras (TIGGO 2, GRAND I10, GRAND AVENUE...)
    modelo = if_else(modelo %in% c("TIGGO", "GRAND", "COROLLA", "YARIS", "CX", "ID", "HAVAL"),
                     str_extract(modelo_detalle |> str_remove("^(NEW|ALL NEW|ALL|NUEVO|NUEVA)\\s+"),
                                 "^\\S+\\s+[A-Z0-9\\-]+"),
                     modelo),
    modelo = if_else(is.na(modelo) | modelo == "", "SIN MODELO", modelo),
    # Mercedes declara versión pegada al modelo (GLC220D, A200): se deja solo la clase
    modelo = if_else(marca == "MERCEDES-BENZ" & str_detect(modelo, "^[A-Z]{1,3}\\d"),
                     str_extract(modelo, "^[A-Z]{1,3}"), modelo),
    # BMW numera sus series (120I, 420I, 530E): se agrupan como "SERIE n"
    modelo = if_else(marca == "BMW" & str_detect(modelo, "^[1-8]\\d\\d"),
                     str_c("SERIE ", str_sub(modelo, 1, 1)), modelo),
    marca_modelo = str_c(marca, " ", modelo)
  )

# Universo de "vehículos livianos": se excluyen camiones/chasis y motos/carros de golf
livianos <- din |>
  filter(!tipo %in% c("Camión / chasis", "Moto todo terreno / carro de golf", "Casa rodante"))

guardar <- function(tabla, nombre) {
  write_csv(tabla, file.path("output/tablas", paste0(nombre, ".csv")))
  tabla
}

# -----------------------------------------------------------------------------
# RESULTADO 1: modelos que más llegaron a Chile en 2025 (todos los orígenes)
# -----------------------------------------------------------------------------
top_modelos <- livianos |>
  group_by(marca, modelo) |>
  summarise(unidades = sum(CANT_MERC),
            fob_prom_usd = weighted.mean(PRE_UNIT, CANT_MERC),
            .groups = "drop") |>
  arrange(desc(unidades)) |>
  mutate(participacion = unidades / sum(unidades)) |>
  guardar("1_top_modelos_chile_2025")

print(head(top_modelos, 20))

top_modelos |>
  filter(marca != "OTRA / SIN IDENTIFICAR") |>
  slice_head(n = 15) |>
  mutate(etiqueta = fct_reorder(str_c(marca, " ", modelo), unidades)) |>
  ggplot(aes(unidades, etiqueta)) +
  geom_col(fill = "#2f5d8a") +
  geom_text(aes(label = number(unidades, big.mark = ".", decimal.mark = ",")), hjust = -0.1, size = 3) +
  scale_x_continuous(labels = label_number(big.mark = ".", decimal.mark = ","), expand = expansion(c(0, 0.12))) +
  labs(title = "Modelos de vehículos livianos más importados por Chile, 2025",
       x = "Unidades", y = NULL,
       caption = "Fuente: elaboración propia con datos DIN 2025, Servicio Nacional de Aduanas.") +
  theme_minimal(base_size = 11)
ggsave("output/graficos/1_top_modelos_chile_2025.png", width = 8, height = 5, dpi = 200)

# -----------------------------------------------------------------------------
# RESULTADO 2: tipos de vehículos que más llegaron
# -----------------------------------------------------------------------------
por_tipo <- din |>
  group_by(tipo) |>
  summarise(unidades = sum(CANT_MERC), .groups = "drop") |>
  arrange(desc(unidades)) |>
  mutate(participacion = unidades / sum(unidades)) |>
  guardar("2_tipos_vehiculo_chile_2025")

print(por_tipo)

por_tipo |>
  mutate(tipo = fct_reorder(tipo, unidades)) |>
  ggplot(aes(unidades, tipo)) +
  geom_col(fill = "#2f5d8a") +
  geom_text(aes(label = percent(participacion, accuracy = 0.1, decimal.mark = ",")),
            hjust = -0.1, size = 3) +
  scale_x_continuous(labels = label_number(big.mark = ".", decimal.mark = ","), expand = expansion(c(0, 0.12))) +
  labs(title = "Vehículos importados por Chile según tipo, 2025",
       x = "Unidades", y = NULL,
       caption = "Fuente: elaboración propia con datos DIN 2025, Servicio Nacional de Aduanas.") +
  theme_minimal(base_size = 11)
ggsave("output/graficos/2_tipos_vehiculo_chile_2025.png", width = 8, height = 4.5, dpi = 200)

# -----------------------------------------------------------------------------
# RESULTADO 3: modelos fabricados en Alemania que llegaron a Chile
# -----------------------------------------------------------------------------
alemania <- livianos |> filter(PA_ORIG == COD_ALEMANIA)

alemania_marcas <- alemania |>
  group_by(marca) |>
  summarise(unidades = sum(CANT_MERC), .groups = "drop") |>
  arrange(desc(unidades)) |>
  mutate(participacion = unidades / sum(unidades)) |>
  guardar("3a_marcas_desde_alemania_2025")

alemania_modelos <- alemania |>
  group_by(marca, modelo, tipo) |>
  summarise(unidades = sum(CANT_MERC),
            fob_prom_usd = weighted.mean(PRE_UNIT, CANT_MERC),
            cif_prom_usd = sum(CIF_ITEM) / sum(CANT_MERC),
            .groups = "drop") |>
  arrange(desc(unidades)) |>
  guardar("3b_modelos_desde_alemania_2025")

print(alemania_marcas)
print(head(alemania_modelos, 20))

# Peso de Alemania en el total de vehículos livianos importados
cat("\nVehículos livianos importados 2025:", sum(livianos$CANT_MERC),
    "\nDesde Alemania:", sum(alemania$CANT_MERC),
    sprintf("(%.1f%%)\n", 100 * sum(alemania$CANT_MERC) / sum(livianos$CANT_MERC)))

alemania_modelos |>
  slice_head(n = 15) |>
  mutate(etiqueta = fct_reorder(str_c(marca, " ", modelo), unidades)) |>
  ggplot(aes(unidades, etiqueta, fill = marca)) +
  geom_col() +
  geom_text(aes(label = number(unidades, big.mark = ".", decimal.mark = ",")), hjust = -0.1, size = 3) +
  scale_x_continuous(expand = expansion(c(0, 0.12))) +
  labs(title = "Modelos fabricados en Alemania importados por Chile, 2025",
       x = "Unidades", y = NULL, fill = "Marca",
       caption = "Fuente: elaboración propia con datos DIN 2025, Servicio Nacional de Aduanas.") +
  theme_minimal(base_size = 11)
ggsave("output/graficos/3_modelos_desde_alemania_2025.png", width = 8, height = 5, dpi = 200)

# -----------------------------------------------------------------------------
# RESULTADO 4: los 5 SUV fabricados en Alemania más importados
# -----------------------------------------------------------------------------
top5_suv <- alemania_modelos |>
  filter(tipo == "SUV / station wagon") |>
  slice_head(n = 5) |>
  guardar("4_top5_suv_desde_alemania_2025")

print(top5_suv)

top5_suv |>
  mutate(etiqueta = fct_reorder(str_c(marca, " ", modelo), unidades)) |>
  ggplot(aes(unidades, etiqueta, fill = marca)) +
  geom_col() +
  geom_text(aes(label = number(unidades, big.mark = ".", decimal.mark = ",")),
            hjust = -0.1, size = 3.5) +
  scale_x_continuous(expand = expansion(c(0, 0.12))) +
  labs(title = "Los 5 SUV fabricados en Alemania más importados por Chile, 2025",
       x = "Unidades importadas", y = NULL, fill = "Marca",
       caption = "Fuente: elaboración propia con datos DIN 2025, Servicio Nacional de Aduanas.") +
  theme_minimal(base_size = 11)
ggsave("output/graficos/4_top5_suv_desde_alemania_2025.png", width = 8, height = 3.5, dpi = 200)

# -----------------------------------------------------------------------------
# RESULTADO 5: ¿las importaciones se parecen a las ventas? (validación con BMW)
#   Ventas: BMW Chile 2025, publicadas por Autocosmos (13-01-2026)
#   https://noticias.autocosmos.cl/2026/01/13/bmw-chile-cierra-el-2025-lleno-de-optimismo
# -----------------------------------------------------------------------------
ventas_bmw <- read_csv("data/raw/ventas_bmw_chile_2025.csv", show_col_types = FALSE)

# Agrupa los modelos importados en las mismas "familias" que usa BMW
familia_bmw <- function(modelo) {
  case_when(str_detect(modelo, "^I") ~ "GAMA I",     # eléctricos: iX, iX1, i4, i5...
            TRUE                     ~ modelo)
}

imp_bmw <- livianos |>
  filter(marca == "BMW") |>
  mutate(modelo = familia_bmw(modelo),
         desde_alemania = PA_ORIG == COD_ALEMANIA) |>
  group_by(modelo) |>
  summarise(importados_total    = sum(CANT_MERC),
            importados_alemania = sum(CANT_MERC[desde_alemania]),
            .groups = "drop")

comparacion_bmw <- ventas_bmw |>
  left_join(imp_bmw, by = "modelo") |>
  mutate(across(starts_with("importados"), \(x) coalesce(x, 0)),
         pct_desde_alemania = importados_alemania / importados_total) |>
  guardar("5_bmw_ventas_vs_importaciones_2025")

print(comparacion_bmw)

comparacion_bmw |>
  select(modelo, `Vendidos en Chile` = ventas_2025,
         `Importados desde Alemania` = importados_alemania) |>
  tidyr::pivot_longer(-modelo, names_to = "serie", values_to = "unidades") |>
  mutate(modelo = fct_reorder(modelo, unidades, .fun = max)) |>
  ggplot(aes(unidades, modelo, fill = serie)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  geom_text(aes(label = unidades), position = position_dodge(width = 0.8),
            hjust = -0.15, size = 3) +
  scale_x_continuous(expand = expansion(c(0, 0.1))) +
  scale_fill_manual(values = c("Vendidos en Chile" = "#2f5d8a",
                               "Importados desde Alemania" = "#9bbcd9")) +
  labs(title = "BMW en Chile 2025: unidades vendidas vs. importadas desde Alemania",
       x = "Unidades", y = NULL, fill = NULL,
       caption = "Fuentes: ventas BMW Chile (Autocosmos, 2026); importaciones DIN 2025, Servicio Nacional de Aduanas.") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "top")
ggsave("output/graficos/5_bmw_ventas_vs_importaciones_2025.png", width = 8, height = 5, dpi = 200)

# -----------------------------------------------------------------------------
# RESULTADO 6: demanda estimada en Ñuble de los 5 SUV
#   Supuesto: Ñuble compra la misma proporción de estos SUV que de autos nuevos
#   en general. Ñuble = 4.097 de 310.598 autos nuevos vendidos en Chile 2025
#   (1,32%), según ANAC, Informe Mercado Automotor diciembre 2025.
# -----------------------------------------------------------------------------
PART_NUBLE <- 0.0132

demanda_nuble <- top5_suv |>
  transmute(modelo     = str_c(marca, " ", modelo),
            chile_anual = unidades,
            nuble_anual = chile_anual * PART_NUBLE,
            nuble_mensual = nuble_anual / 12) |>
  bind_rows(tibble(modelo = "TOTAL",
                   chile_anual   = sum(top5_suv$unidades),
                   nuble_anual   = sum(top5_suv$unidades) * PART_NUBLE,
                   nuble_mensual = sum(top5_suv$unidades) * PART_NUBLE / 12)) |>
  mutate(across(c(nuble_anual, nuble_mensual), \(x) round(x, 1))) |>
  guardar("6_demanda_estimada_nuble_top5_suv")

print(demanda_nuble)

# Llegadas mes a mes a Chile (muestran que los autos llegan en lotes, no parejo)
llegadas_mensuales <- livianos |>
  filter(PA_ORIG == COD_ALEMANIA, tipo == "SUV / station wagon") |>
  semi_join(top5_suv, by = c("marca", "modelo")) |>
  mutate(MES = as.integer(MES), modelo = str_c(marca, " ", modelo)) |>
  group_by(modelo, MES) |>
  summarise(unidades = sum(CANT_MERC), .groups = "drop") |>
  tidyr::complete(modelo, MES = 1:12, fill = list(unidades = 0)) |>
  tidyr::pivot_wider(names_from = MES, values_from = unidades, names_prefix = "mes_") |>
  guardar("6b_llegadas_mensuales_top5_suv")

print(llegadas_mensuales)

demanda_nuble |>
  filter(modelo != "TOTAL") |>
  mutate(modelo = fct_reorder(modelo, nuble_anual)) |>
  ggplot(aes(nuble_anual, modelo)) +
  geom_col(fill = "#2f5d8a") +
  geom_text(aes(label = str_c(number(nuble_anual, accuracy = 0.1, decimal.mark = ","),
                              " al año (", number(nuble_mensual, accuracy = 0.1, decimal.mark = ","),
                              " al mes)")),
            hjust = -0.05, size = 3.3) +
  scale_x_continuous(expand = expansion(c(0, 0.45))) +
  labs(title = "Demanda anual estimada en Ñuble de los 5 SUV alemanes, 2025",
       subtitle = str_c("Total: ", number(sum(top5_suv$unidades) * PART_NUBLE, accuracy = 0.1, decimal.mark = ","),
                        " unidades al año (aprox. ",
                        number(sum(top5_suv$unidades) * PART_NUBLE / 12, accuracy = 0.1, decimal.mark = ","),
                        " al mes)"),
       x = "Unidades al año", y = NULL,
       caption = "Fuente: elaboración propia con datos DIN 2025 (Aduanas) y participación de Ñuble en ventas de autos nuevos (ANAC, 2025: 1,32%).") +
  theme_minimal(base_size = 11)
ggsave("output/graficos/6_demanda_estimada_nuble_top5_suv.png", width = 8.5, height = 3.8, dpi = 200)

# Abre las tablas en RStudio (como una hoja de cálculo) al presionar Source
if (interactive()) {
  View(demanda_nuble, "Demanda Ñuble")
  View(llegadas_mensuales, "Llegadas mensuales")
}

# -----------------------------------------------------------------------------
# RESULTADO 7: plan de compras trimestral (tabla como imagen)
#   1. La demanda anual de Ñuble se redondea hacia arriba (7,4 -> 8 GLC).
#   2. Cada modelo se reparte en 4 trimestres: la parte entera va pareja en
#      todos y las unidades que sobran se asignan a los trimestres que dejan
#      los embarques más parejos (sin pasar de 6 autos), separando las llegadas
#      de los modelos que se piden poco (ej. X3: trimestres 1 y 3).
# -----------------------------------------------------------------------------
plan <- demanda_nuble |>
  filter(modelo != "TOTAL") |>
  transmute(modelo, anual = ceiling(nuble_anual))

# Patrones posibles para repartir las unidades que sobran (1, 2 o 3 por año)
patrones <- list(
  `1` = list(1, 2, 3, 4),
  `2` = list(c(1, 3), c(2, 4)),                       # separados, no seguidos
  `3` = list(c(1, 2, 3), c(1, 2, 4), c(1, 3, 4), c(2, 3, 4))
)

trim <- matrix(0, nrow = nrow(plan), ncol = 4,
               dimnames = list(plan$modelo, paste0("T", 1:4)))
trim[] <- plan$anual %/% 4                              # parte pareja
resto  <- plan$anual %% 4

# Se reparten primero los modelos con menos unidades al año
for (i in order(plan$anual)) {
  if (resto[i] == 0) next
  opciones <- patrones[[as.character(resto[i])]]
  total_con <- sapply(opciones, \(p) { t <- colSums(trim); t[p] <- t[p] + 1; max(t) })
  elegido <- opciones[[which.min(total_con)]]           # el que deja embarques más parejos
  trim[i, elegido] <- trim[i, elegido] + 1
}

plan_trimestral <- as_tibble(trim, rownames = "Modelo") |>
  mutate(`Total año` = T1 + T2 + T3 + T4) |>
  bind_rows(tibble(Modelo = "Total embarque",
                   T1 = sum(trim[, 1]), T2 = sum(trim[, 2]),
                   T3 = sum(trim[, 3]), T4 = sum(trim[, 4]),
                   `Total año` = sum(trim))) |>
  mutate(Modelo = if_else(Modelo == "Total embarque", Modelo,
                          str_c(str_to_title(word(Modelo, 1, -2)) |> str_replace("Bmw", "BMW"),
                                " ", word(Modelo, -1) |> str_replace("GRANDLAND", "Grandland"))))

guardar(plan_trimestral, "7_plan_compras_trimestral")
print(plan_trimestral)

# Tabla como imagen (para el informe), dibujada con ggplot2 (sin paquetes extra)
tabla_larga <- plan_trimestral |>
  mutate(fila = row_number(),
         across(-c(Modelo, fila), as.character)) |>
  tidyr::pivot_longer(-fila, names_to = "columna", values_to = "valor") |>
  mutate(columna = factor(columna, levels = names(plan_trimestral)),
         x = as.numeric(columna),
         es_total = fila == max(fila))

encabezado <- tibble(columna = factor(names(plan_trimestral), levels = names(plan_trimestral)),
                     x = seq_along(names(plan_trimestral)), fila = 0)
anchos <- c(3.2, 1, 1, 1, 1, 1.6)                      # ancho de cada columna
bordes <- c(0, cumsum(anchos))
centro <- (head(bordes, -1) + tail(bordes, -1)) / 2

ggplot() +
  geom_rect(data = tabla_larga,
            aes(xmin = bordes[x], xmax = bordes[x + 1], ymin = -fila - 0.5, ymax = -fila + 0.5,
                fill = case_when(es_total ~ "total", fila %% 2 == 0 ~ "par", TRUE ~ "impar"))) +
  geom_rect(data = encabezado,
            aes(xmin = bordes[x], xmax = bordes[x + 1], ymin = -0.5, ymax = 0.5), fill = "#2f5d8a") +
  geom_text(data = encabezado, aes(x = centro[x], y = 0, label = columna),
            colour = "white", fontface = "bold", size = 4.2) +
  geom_text(data = tabla_larga,
            aes(x = if_else(x == 1, 0.15, centro[x]), y = -fila, label = valor,
                hjust = if_else(x == 1, 0, 0.5),
                fontface = if_else(es_total, "bold", "plain")),
            size = 4.2) +
  scale_fill_manual(values = c(impar = "white", par = "#eef3f8", total = "#d9e4ef"), guide = "none") +
  labs(title = "Plan de compras trimestral de Automotora Ñuble SpA",
       caption = "Fuente: elaboración propia en base a la demanda anual estimada para Ñuble (DIN 2025, Aduanas; ANAC 2025).") +
  coord_cartesian(expand = FALSE) +
  theme_void(base_size = 12) +
  theme(plot.title = element_text(face = "bold", hjust = 0.5, margin = margin(b = 10)),
        plot.caption = element_text(colour = "grey30", hjust = 0.5, margin = margin(t = 10)),
        plot.margin = margin(15, 20, 10, 20))

ggsave("output/tablas/7_plan_compras_trimestral.png", width = 8, height = 3.6, dpi = 200, bg = "white")

if (interactive()) View(plan_trimestral, "Plan trimestral")
