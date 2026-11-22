# =============================================================================
# 01_ranking_vehiculos.R
# Comercio Exterior – EV3 (Grupo 11) · Estudio de mercado
#
# Fuente: Registro de Importaciones (DIN) 2025, Servicio Nacional de Aduanas
#         (datos.gob.cl). Partidas 8703 (autos, SUV) y 8704 (camionetas,
#         furgones, camiones), ya filtradas con scripts/00_extraer_filtrar_din.py
#
# Entrega 3 resultados:
#   1. Modelos de vehículos que más llegaron a Chile en 2025
#   2. Tipos de vehículos que más llegaron (SUV, automóvil, camioneta, etc.)
#   3. Modelos fabricados en Alemania que llegaron a Chile en 2025
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
