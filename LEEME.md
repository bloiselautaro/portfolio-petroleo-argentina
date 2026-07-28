# Cadena de Valor del Petróleo Argentino — ELT Serverless

[🇬🇧 English](README.md) | 🇦🇷 Español

![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python&logoColor=white)
![dbt](https://img.shields.io/badge/dbt--core-1.7.9-FF694B?logo=dbt&logoColor=white)
![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?logo=googlebigquery&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?logo=githubactions&logoColor=white)
![Looker Studio](https://img.shields.io/badge/Looker_Studio-4285F4?logo=looker&logoColor=white)

Pipeline ELT serverless que integra 4 fuentes de la cadena de valor del
petróleo argentino: producción de crudo por provincia y por empresa
(upstream, mensual), precios en surtidor (downstream, snapshot + histórico),
y precio internacional del Brent (FRED).

**Dashboard en vivo:** https://datastudio.google.com/reporting/acb3c54c-6361-470b-8e04-56ea25c7b775

## Qué muestra el dashboard

- **Página 1 — Producción Nacional y Provincial**: tendencia de producción
  nacional, desglose provincial (área apilada, dona, ranking), con Neuquén
  (Vaca Muerta) representando ~69% de la producción nacional.
- **Página 2 — Producción vs. Precio Internacional**: scorecards de Brent
  Spot y Nafta Súper con variación interanual, dispersión que testea la
  correlación entre Brent y producción nacional (hallazgo: sin correlación
  mensual clara, pero con tendencia convergente de largo plazo), líneas
  indexadas base 100, y dos gauges que muestran la posición actual de cada
  serie dentro de su propio rango histórico 2009-2026.
- **Página 3 — Precios en Surtidor**: selector de tipo de combustible (Nafta
  Súper, Nafta Premium, Gasoil Grado 2/3, GNC), scorecards de promedio/mínimo/
  máximo nacional, mapa coroplético por provincia, y rankings de precio por
  provincia y por bandera.

## Stack

| Capa | Tecnología |
|---|---|
| Extracción | Python 3.13 (`requests`, `google-cloud-bigquery`) |
| Orquestación | GitHub Actions (cron, diario L-V, + disparo manual) |
| Almacenamiento y cómputo | BigQuery (`raw_petroleo`, `analytics_petroleo`, región US) |
| Transformación | dbt-core 1.7.9 + dbt-bigquery + dbt_utils |
| Visualización | Looker Studio |

## Fuentes de datos

- **Producción por provincia** — Secretaría de Energía (mensual, desde
  2009). Excluye la fila agregada "Estado Nacional" para evitar doble
  conteo.
- **Producción por empresa** — mismo organismo/patrón, ~12.600 filas. YPF
  representa aproximadamente 40-45% de la producción nacional.
- **Precios en surtidor (snapshot vigente)** — Secretaría de Energía,
  Resolución 314/2016, ~4.626 estaciones, ~36.700 filas. Grano: estación ×
  producto × tipo de horario × fecha de vigencia.
- **Precios históricos en surtidor** — misma fuente, backfill único
  (~3,36M filas, 738 MB), *no* forma parte del pipeline diario; se cargó una
  sola vez a mano vía `cargar_historico_precios.py`.
- **Petróleo Brent (FRED, DCOILBRENTEU)** — diario desde 1987, USD/barril.
  Requiere header `User-Agent`; falla por timeout de forma intermitente
  desde GitHub Actions (funciona bien en local), por eso este paso corre
  con `continue-on-error: true`.

## Arquitectura

```
Extractores (Python)
        ↓
BigQuery — raw_petroleo (datos crudos, tal cual llegan de la fuente)
        ↓
dbt — staging (limpieza y tipado)
        ↓
dbt — marts (fct_produccion, fct_produccion_empresa, fct_precios_surtidor,
              fct_nafta_mensual, fct_brent_actual, fct_brent_mensual,
              fct_comparativa_mensual, fct_indices_comparativos,
              fct_posicion_historica)
        ↓
Looker Studio (dashboard)
```

`fct_comparativa_mensual` es un full outer join de producción, Brent y
nafta por período — la base del análisis cruzado de la Página 2.
`fct_indices_comparativos` construye índices base 100 (ene-2009) para Brent
y producción nacional, válido porque ambas series tienen escalas de
crecimiento comparables. `fct_posicion_historica` calcula el valor actual de
cada serie como porcentaje de su propio rango mín-máx histórico, y alimenta
los dos gauges de la Página 2.

## Sobre la frescura de los datos — leer antes de confiar en el Brent "de hoy"

El pipeline corre **una sola vez al día**, de lunes a viernes, a las 11:17
ART. Esto importa especialmente para el scorecard de Brent, por tres motivos
que se suman entre sí:

1. **Cadencia del pipeline**: una sola corrida por día, no varias — a
   diferencia de un feed realmente en tiempo real.
2. **Rezago de la fuente**: FRED publica el Brent con 1-4 días de rezago;
   no es un tick en vivo.
3. **Tolerancia a fallos**: el paso del extractor de Brent está configurado
   a propósito con `continue-on-error: true`, porque ocasionalmente falla
   por timeout al correr desde GitHub Actions (funciona de forma confiable
   desde una máquina local). Si falla un día determinado, ese día
   simplemente no se actualiza el valor — no hay reintento automático hasta
   la corrida programada siguiente.

En el peor caso (una falla un viernes), el valor de Brent mostrado en el
dashboard podría quedar desactualizado varios días hasta corregirse solo en
la próxima corrida exitosa. Es un trade-off conocido y aceptado para un
proyecto de portfolio — no es un bug.

Los datos de producción y precios en surtidor siguen sus propios
calendarios de publicación de origen (mensual para producción, con el
último mes llegando a menudo parcial y marcado como tal; casi en tiempo
real para precios en surtidor, sujeto a la cadencia de reporte de cada
estación).

## Decisiones de diseño destacadas

- **Cálculo de variación por "rachas" (streaks)**: la variación porcentual
  se calcula contra el último valor de una racha genuinamente distinta
  (vía un `streak_id` basado en `SUM()` corrido), no contra el día
  calendario anterior. Esto evita mostrar 0,00% después de dos o más días
  seguidos sin cambios.
- **Índices base 100 usados de forma selectiva**: `fct_indices_comparativos`
  (producción vs. Brent) es válido y se usa en el dashboard porque ambas
  series tienen magnitudes de crecimiento comparables. Se construyó y
  probó un índice similar entre Nafta (ARS, afectada por inflación) y
  Brent (USD) (`fct_indices_nafta_brent`), pero se decidió a propósito
  **no usarlo** — el desajuste de escala resultante (índice ~26.000 vs.
  ~240 en el mismo período) era matemáticamente correcto pero visualmente
  inútil. El modelo queda en el repo como código muerto documentado, en
  vez de borrarse en silencio.
- **Gauges evitan métricas que pueden ser negativas**: el eje mínimo de un
  gauge en Looker Studio no acepta valores negativos, así que la variación
  interanual (que puede bajar) nunca se usó en gauges. En su lugar, los
  gauges muestran la posición porcentual de cada serie dentro de su propio
  rango mín-máx histórico — siempre no negativa por construcción.
- **Filtro de coordenadas de estaciones**: se excluyeron 26 filas con
  latitud/longitud nulas de `fct_precios_surtidor` para poder armar el mapa
  de la Página 3. Un número reducido de estaciones restantes puede tener
  coordenadas que caen apenas del lado de una provincia vecina respecto a
  su campo `provincia` declarado — corregir esto de forma fina requeriría
  polígonos de límites provinciales (una 5ta fuente de datos), lo cual se
  evaluó y se decidió postergar a propósito para mantener acotado el scope
  del proyecto.

## Cómo correrlo localmente

Requiere Python 3.13, una cuenta de servicio de GCP con permisos sobre
BigQuery, y dbt-core.

```bash
git clone https://github.com/bloiselautaro/portfolio-petroleo-argentina.git
cd portfolio-petroleo-argentina
pip install google-cloud-bigquery requests "dbt-core==1.7.9" dbt-bigquery "protobuf<5,>=4.25.3"

# Correr los extractores principales
cd etl
python extractor_produccion.py
python extractor_produccion_empresa.py
python extractor_precios.py
python extractor_brent.py

# Correr las transformaciones de dbt
cd ../dbt_project/petroleo_ar
dbt deps
dbt run
dbt test
```

El backfill único de precios históricos (`etl/cargar_historico_precios.py`,
~738 MB) queda a propósito fuera de los pasos de arriba — está pensado para
correr una sola vez, a mano, no como parte de la ejecución rutinaria del
pipeline.

## Limitaciones conocidas

- La frescura del precio de Brent depende de la cadencia del pipeline, el
  rezago de la fuente y la tolerancia a fallos del extractor, combinados —
  ver "Sobre la frescura de los datos" arriba.
- Se evaluó una fuente de tipo de cambio (para comparar Nafta en USD contra
  Brent) y se decidió explícitamente **no** sumarla, para mantener el scope
  del proyecto en sus 4 fuentes confirmadas.
- La geolocalización de estaciones puede no coincidir perfectamente con la
  provincia declarada en un subconjunto reducido de registros; ver
  "Decisiones de diseño destacadas" arriba.
- El pipeline depende de la disponibilidad y el rezago de publicación de
  cada fuente pública, que está fuera de nuestro control.
