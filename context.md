# context.md
# Cadena de Valor del Petróleo Argentino
### Producción Provincial + Precios en Surtidor — Portfolio de Data Engineering
**Versión:** 1.0
**Autor:** Lautaro Bloise
**Estado:** Planificación
**Proyecto hermano:** `portfolio-etl-argentina` (indicadores económicos diarios — TERMINADO)

---

# 1. Visión del proyecto

## Propósito
Construir un pipeline ELT serverless que integra dos fuentes oficiales de la Secretaría de
Energía de la Nación para analizar la cadena de valor del petróleo en Argentina de punta a
punta: cuánto se produce por provincia (upstream) y a qué precio llega al consumidor en el
surtidor (downstream).

El valor diferencial no es cada fuente por separado — es cruzarlas para responder preguntas que
ninguna de las dos responde sola: ¿las provincias productoras tienen combustible más barato?
¿cómo se relaciona la producción regional con el precio final?

## Por qué existe este proyecto
Este es el segundo proyecto del portfolio, complementario a `portfolio-etl-argentina` (que
cubre indicadores macro diarios de último valor). Este proyecto demuestra un set de habilidades
distinto: integración de **múltiples fuentes** con cadencias distintas, modelo dimensional con
**más de un fact table**, y un análisis cruzado real en la última página del dashboard.

Este documento es la fuente de verdad para cualquier IA (Claude, ChatGPT, Copilot, Cursor) que
colabore en el repo. El scope está definido acá y no se vuelve a discutir sin justificación
explícita de Lautaro.

---

# 2. Principio rector: SCOPE ACOTADO

Sumar una segunda fuente de datos es la única expansión de scope permitida respecto al enfoque
de un solo dataset. No se suma una tercera fuente, no se agregan capas nuevas, no se agregan
páginas más allá de las 3 definidas en la sección 13.

Regla de oro: si una sugerencia (propia o de una IA) no está justificada por el volumen real de
datos de este proyecto o no aporta a responder las preguntas de negocio de la sección 3, no entra.

Explícitamente descartado (y por qué):
- **dbt Cloud** → dbt-core en GitHub Actions ya funciona, sin depender de un tercero.
- **Capas "bronze/silver/gold"** → se usa la convención estándar de dbt (`staging → intermediate → marts`).
- **Datos a nivel de pozo/yacimiento individual** → demasiado granular (miles de pozos, pensado
  para uso técnico-geológico). Se usa el dataset ya agregado a nivel provincia.
- **Una tercera fuente de datos** (ej. importación/exportación de combustibles) → queda como
  posible fase 2, no bloquea el MVP.

---

# 3. Escenario de negocio

Una consultora energética o un área de estrategia comercial de una petrolera necesita entender,
de forma visual y actualizada, cómo se relaciona la producción regional de petróleo con el precio
que paga el consumidor final, para informar decisiones de expansión de red de estaciones o
análisis de competitividad regional.

Preguntas que el dashboard debe responder:
- ¿Qué provincias producen más petróleo y cómo evoluciona esa producción en el tiempo?
- ¿Cómo varía el precio de los combustibles por provincia y por bandera?
- ¿Qué bandera domina el mercado en cada región?
- ¿Las provincias productoras tienen naftas más baratas que las no productoras?
- ¿Qué provincias son más "eficientes" (mucha producción, precio bajo) vs. menos eficientes?

---

# 4. Fuentes de datos

Ambas fuentes pertenecen al mismo organismo (Secretaría de Energía de la Nación) y se acceden a
través del mismo portal de datos abiertos (`datos.energia.gob.ar` / `datos.gob.ar`), con acceso
estructurado (CSV / OData) — sin parseo de Excel legacy.

## Fuente 1 — Producción de petróleo por provincia (Upstream)
- Dataset: "Producción de petróleo promedio diaria por provincia"
- Organismo: Secretaría de Energía, Dirección Nacional de Información Energética
- Formato: CSV / OData
- Granularidad: provincia × mes
- Frecuencia de publicación: mensual

## Fuente 2 — Precios en Surtidor (Downstream)
- Dataset: "Precios en Surtidor - Resolución 314/2016"
- Organismo: Secretaría de Energía
- Formato: OData
- Granularidad: estación de servicio × combustible × fecha de vigencia del precio
- Frecuencia de publicación: casi en tiempo real (declaración obligatoria dentro de las 8 horas
  de cambiar un precio); el pipeline toma una foto (snapshot) diaria, no procesa cada cambio
  individual.

> **Pendiente de confirmar antes de escribir los extractores:** columnas exactas y endpoints
> OData de cada dataset (URLs, nombres de campos, formato de fecha, códigos de provincia). Esto
> se resuelve en la Fase 0, bajando una muestra de cada fuente y documentando en
> `docs/data_source_notes.md` antes de tocar código de extracción.

---

# 5. Stack tecnológico (consistente con el proyecto hermano)

| Capa | Tecnología |
|---|---|
| Lenguaje | Python 3.13 |
| Extracción | `requests` (consumo de OData/CSV) |
| Almacenamiento raw | Google Cloud Storage (bucket, landing zone inmutable) |
| Data Warehouse | Google BigQuery (dataset `raw_petroleo`, `analytics_petroleo`, región `US`) |
| Transformación | dbt-core 1.7.x + dbt-bigquery |
| Orquestación | GitHub Actions (dos triggers: mensual para producción, diario para surtidor) |
| Visualización | Looker Studio |
| Control de versiones | Git / GitHub |

No se introduce ninguna herramienta nueva respecto al proyecto anterior.

---

# 6. Arquitectura de alto nivel

```text
   Secretaría de Energía              Secretaría de Energía
   Producción por provincia            Precios en Surtidor
   (CSV/OData, mensual)                 (OData, casi tiempo real)
              │                                   │
              ▼                                   ▼
   GitHub Actions (cron mensual)      GitHub Actions (cron diario)
              │                                   │
              ▼                                   ▼
                    Python ETL (extract / validate / load)
                                    │
              ┌─────────────────────┴─────────────────────┐
              ▼                                             ▼
        Cloud Storage                                BigQuery raw_petroleo
        (respaldo inmutable                          (datos parseados,
         de cada extracción)                          mínima normalización)
                                                              │
                                                              ▼
                                                          dbt-core
                                            staging → intermediate → marts
                                                              │
                                                              ▼
                                                  analytics_petroleo (marts)
                                                              │
                                                              ▼
                                                       Looker Studio
                                                              │
                                                              ▼
                                          Dashboard Cadena de Valor Petrolera
```

---

# 7. Requisitos funcionales
- El pipeline de producción corre mensualmente y detecta si hay un período nuevo publicado.
- El pipeline de surtidores corre diariamente y toma una foto del precio vigente por estación.
- Ambos preservan el dato crudo sin modificar en Cloud Storage.
- Ambos transforman los datos en un modelo dimensional consultable desde BigQuery.
- El pipeline debe fallar visiblemente (log + exit code ≠ 0) si la validación de datos no pasa.
- El dashboard consume únicamente tablas de `marts`, nunca `staging` ni `raw`.

# 8. Requisitos no funcionales
- Cloud-native, serverless, dentro de free tier de GCP.
- Cero ejecución local una vez desplegado — todo corre en GitHub Actions.
- Código modular, tipado (type hints), sin credenciales hardcodeadas.
- Autenticación de GitHub Actions hacia GCP vía **Workload Identity Federation**.
- Tests con `pytest` desde el día 1, no como mejora futura.

---

# 9. Estructura del repositorio

```text
portfolio-petroleo-argentina/
├── etl/
│   ├── extract_produccion.py     # fuente 1 (mensual)
│   ├── extract_surtidor.py       # fuente 2 (diario)
│   ├── validate.py
│   ├── load.py
│   ├── logger.py
│   ├── config.py
│   └── main.py
├── dbt_project/
│   └── petroleo_ar/
│       ├── models/
│       │   ├── staging/          # stg_produccion.sql, stg_surtidor.sql
│       │   ├── intermediate/     # normalización de provincias, claves surrogate
│       │   └── marts/            # fact_produccion, fact_precio_combustible, dim_*
│       ├── tests/
│       ├── macros/
│       └── seeds/                # mapeo provincia -> región, provincia -> lat/long (mapa)
├── docs/
│   ├── data_source_notes.md      # estructura real de cada fuente, decisiones de parsing
│   └── CONTEXT.md                # gitignored, documento de continuidad para IA
├── tests/                        # pytest para etl/
├── .github/workflows/
│   ├── pipeline_produccion.yml   # cron mensual
│   └── pipeline_surtidor.yml     # cron diario
├── README.md
├── context.md                    # este documento
├── requirements.txt
└── .env.example
```

---

# 10. Modelo dimensional (Kimball, star schema)

## Fact tables

### `fact_produccion_petroleo`
Grano: una fila = una provincia + un mes.

Medidas:
- `produccion_petroleo_m3`
- `variacion_pct_interanual` (calculado en marts)

Foreign keys: `provincia_id`, `periodo_id`

### `fact_precio_combustible`
Grano: una fila = una estación de servicio + un tipo de combustible + una fecha de snapshot.

Medidas:
- `precio_litro`
- `variacion_pct_vs_mes_anterior` (calculado en marts)

Foreign keys: `provincia_id`, `bandera_id`, `tipo_combustible_id`, `periodo_id`

## Dimensiones compartidas
- **`dim_provincia`**: provincia_id, nombre, región económica, latitud, longitud (para el mapa)
- **`dim_periodo`**: periodo_id, mes, año, fecha

## Dimensiones específicas
- **`dim_bandera`**: bandera_id, nombre (YPF, Shell, Axion, Puma, etc.)
- **`dim_tipo_combustible`**: tipo_combustible_id, nombre (nafta súper, premium, gasoil, GNC)

---

# 11. Modelos dbt

## Staging
- `stg_produccion.sql` — renombra columnas, tipa correctamente, sin lógica de negocio.
- `stg_surtidor.sql` — ídem para precios en surtidor.

## Intermediate
- `int_produccion_normalizada.sql` — resuelve nombres de provincia inconsistentes, genera claves.
- `int_surtidor_normalizado.sql` — normaliza banderas y tipos de combustible, genera claves.

## Marts
- `fact_produccion_petroleo.sql`
- `fact_precio_combustible.sql`
- `dim_provincia.sql`, `dim_periodo.sql`, `dim_bandera.sql`, `dim_tipo_combustible.sql`
- `mart_cadena_valor.sql` — cruce provincia × producción × precio promedio, la tabla que
  alimenta la Page 3 del dashboard.

---

# 12. Calidad de datos

**Validaciones en Python (`validate.py`):**
- Montos/precios no negativos
- Provincias reconocidas contra catálogo fijo (24 jurisdicciones)
- No hay filas duplicadas por (provincia, período) en producción, ni por (estación, combustible,
  fecha) en surtidor
- Precios dentro de un rango razonable (descarta outliers de carga manual errónea)

**Tests dbt:**
- `unique`, `not_null` en claves de dimensiones
- `relationships` entre cada fact table y sus dimensiones
- `accepted_values` en tipo de combustible y región económica

El pipeline debe fallar (exit code ≠ 0) si alguna validación crítica no pasa.

---

# 13. Diseño del dashboard (Looker Studio)

**3 páginas, cada una con un propósito de negocio distinto. Se construyen en orden: Page 1
completa y validada antes de arrancar Page 2, y así sucesivamente.**

## Page 1 — Producción (Upstream)
Target: entender dónde y cuánto se produce.
- **Scorecards**: producción nacional total, provincia líder, variación interanual
- **Mapa (bubble/geo chart)**: producción de petróleo (m³) por provincia
- **Línea**: evolución mensual de la producción nacional
- **Torta**: participación de cada provincia/región en el total producido
- Filtros: período, región

## Page 2 — Surtidores (Downstream / Retail)
Target: entender el precio al consumidor y quién domina el mercado.
- **Mapa**: precio promedio de nafta por provincia
- **Torta**: participación de mercado por bandera (YPF, Shell, Axion, etc.)
- **Barras apiladas**: precio por tipo de combustible (súper, premium, gasoil, GNC), por región
- Filtros: período, región, bandera, tipo de combustible

## Page 3 — Cadena de Valor (análisis cruzado)
Target: la pregunta que ninguna de las dos páginas anteriores responde sola.
- **Comparación producción vs. precio por provincia** (¿las provincias productoras tienen
  combustible más barato?)
- **Ranking de provincias** por "eficiencia" (producción alta / precio bajo vs. producción
  baja / precio alto)
- **Variación interanual combinada**: producción vs. precio
- Filtros: período, provincia

## Filtros globales
- Período
- Región

---

# 14. Automatización (GitHub Actions)

- **Pipeline de producción**: cron mensual. Chequea si hay un período nuevo publicado antes de
  procesar (idempotencia). Si no hay novedad, termina en éxito sin generar cambios (se loguea
  explícitamente, no se trata como error).
- **Pipeline de surtidor**: cron diario. Toma una foto del precio vigente por estación ese día;
  no reprocesa el historial completo.
- Autenticación vía Workload Identity Federation en ambos workflows.

---

# 15. Fases del proyecto

## Fase 0 — Reconocimiento de las fuentes
Bajar una muestra real de cada dataset (producción y surtidor), documentar su estructura exacta
en `docs/data_source_notes.md`, confirmar endpoints OData y nombres de campos.
**No se escribe una sola línea de extractor sin esto.**

## Fase 1 — Infraestructura
GitHub repo, BigQuery datasets, Cloud Storage bucket, dbt project scaffolding, WIF.

## Fase 2 — ETL en Python
`extract_produccion.py`, `extract_surtidor.py`, `validate.py`, `load.py`, tests con pytest desde
el día 1.

## Fase 3 — Modelado dbt
staging → intermediate → marts, tests, seeds de provincia/región/lat-long, `mart_cadena_valor`.

## Fase 4 — Dashboard
Page 1 completa y validada primero. Page 2 después. Page 3 al final, una vez que las dos
fuentes están confiables — es la que depende de ambas.

## Fase 5 — Documentación
README, diagrama de arquitectura, data dictionary, capturas del dashboard.

---

# 16. Qué demuestra este proyecto
- Integración de **múltiples fuentes** con cadencias de actualización distintas (mensual vs.
  diaria) dentro de un mismo warehouse.
- Modelo dimensional con **más de un fact table** compartiendo dimensiones comunes.
- Un análisis de negocio real que cruza fuentes (Page 3), no solo dos dashboards pegados.
- Automatización 100% cloud, sin ejecución local, con idempotencia real.
- Autenticación cloud vía Workload Identity Federation.
- Criterio para acotar scope: dos fuentes sí, granularidad de pozo no, tercera fuente no (por
  ahora).

---

# 17. Reglas para cualquier IA que colabore en este repo

- Este documento es la fuente de verdad del scope. No proponer arquitectura nueva sin que
  Lautaro lo pida explícitamente.
- No agregar fuentes de datos, herramientas, capas o servicios que no estén justificados por el
  volumen real de datos de este proyecto o por las preguntas de negocio de la sección 3.
- No usar dbt Cloud, ni nomenclatura bronze/silver/gold.
- No usar el dataset de producción a nivel de pozo — solo el agregado por provincia.
- No asumir que un paso está terminado sin evidencia (output de terminal, resultado de query en
  BigQuery, captura de pantalla).
- Priorizar siempre la opción técnica más estándar/profesional sin preguntar, salvo que la
  decisión cambie meaningfully el resultado.
- No proponer soluciones parche sin diagnosticar la causa raíz primero.
- Antes de escribir cada extractor, confirmar la estructura real de la fuente correspondiente —
  no asumir columnas ni endpoints.
- El dashboard tiene como máximo 3 páginas (sección 13), construidas en orden. La Page 3 no
  arranca hasta que Page 1 y Page 2 estén validadas con datos reales.
- Todo el pipeline corre 100% en la nube (GCS, BigQuery, dbt-core vía GitHub Actions, Looker
  Studio). No se propone ni se acepta ningún paso de ejecución local una vez desplegado.