# Data Source Notes — portfolio-petroleo-argentina

## Fuente 1 — Producción de petróleo por provincia

- Dataset: "Producción de petróleo promedio diaria por provincia"
- Organismo: Secretaría de Energía, Dirección Nacional de Información Energética
- URL descarga: http://datos.energia.gob.ar/dataset/590d1284-fd6d-4686-afd8-b3da5d90a6e9/resource/a512fef1-e98e-44af-b940-76168a4bc523/download/produccin-de-petrleo-promedio-diaria-por-provincia.csv
- Formato: CSV, separador coma, decimal punto, encoding UTF-8 (tildes OK)
- Frecuencia real de publicación: mensual, actualizado hasta 2026-01 al momento de la muestra (bajada 2026-07-23)

### Columnas confirmadas
| Columna | Tipo | Nota |
|---|---|---|
| anio | int | ej. 2025 |
| mes | int | sin cero a la izquierda (1-12) |
| indice_tiempo | string 'YYYY-MM' | usar como fuente de verdad del período |
| provincia | string | incluye "Estado Nacional" como fila de total agregado |
| produccion_petroleo_promedio_dia_m3 | float | ya viene con nombre explícito |

### Hallazgos / decisiones
- La fila con provincia = "Estado Nacional" es un total agregado, NO una provincia real.
  Se excluye en stg_produccion.sql (WHERE provincia != 'Estado Nacional') para evitar
  doble conteo. Si se necesita el total país, se recalcula con SUM(provincia), no se
  confía en esta fila pre-agregada.
- Parsear período desde indice_tiempo ('YYYY-MM') con PARSE_DATE, no concatenar anio+mes
  por separado.

### Pendiente
- Confirmar rango histórico completo (desde qué año arranca el dataset)
- Confirmar si existe endpoint OData para este resource_id además del CSV

## Fuente 2 — Precios en Surtidor (Resolución 314/2016)

- Dataset: "Precios en Surtidor - Resolución 314/2016" (recurso "Precios vigentes")
- URL descarga: http://datos.energia.gob.ar/dataset/1c181390-5045-475e-94dc-410429be4b17/resource/80ac25de-a44a-4445-9215-090cf55cfda5/download/precios-en-surtidor-resolucin-3142016.csv
- Formato: CSV, separador coma, encoding UTF-8
- Volumen muestra: 36.752 filas (snapshot actual, manejable en free tier)

### Columnas confirmadas
indice_tiempo, idempresa, cuit, empresa, direccion, localidad, provincia, region,
idproducto, producto, idtipohorario, tipohorario, precio, fecha_vigencia,
idempresabandera, empresabandera, latitud, longitud, geojson

### Hallazgos / decisiones
- GRANO REAL (corrige sección 10 de context.md): estación + producto + tipohorario +
  fecha_vigencia. La columna tipohorario (Diurno/Nocturno) es parte del grano, no un
  duplicado. Se agrega dim_tipo_horario (idtipohorario, tipohorario) como dimensión
  conformada chica.
- fecha_vigencia (timestamp) es la fuente de verdad temporal, no indice_tiempo (que es
  solo el mes de la muestra).
- provincia viene en mayúsculas sin tildes -> normalizar en int_surtidor_normalizado.sql
  contra catálogo de 24 jurisdicciones.
- empresa (razón social) != empresabandera (marca) -> empresabandera alimenta dim_bandera.
- latitud/longitud vienen a nivel estación, ya listos para mapa.
- geojson es redundante con lat/long -> se descarta en staging.
- Productos observados (constante conocida por la resolución): Nafta Grado 2/3,
  Gasoil Grado 2/3, GNC -> universo cerrado de ~5 valores para dim_tipo_combustible.
### Hallazgo adicional (mart)
- direccion como string NO identifica de forma unica una boca de expendio: el mismo
  idempresa puede repetir el mismo texto de direccion para dos sucursales distintas con
  coordenadas diferentes. El grano real de fct_precios_surtidor incluye latitud/longitud
  ademas de idempresa+idproducto+idtipohorario+fecha_vigencia.
- Algunas coordenadas no coinciden geograficamente con la provincia declarada (posible
  error de carga del lado de la EESS al declarar). Revisar si hace falta un filtro de
  sanidad geografica antes de usar el mapa en Looker Studio.
  ## Fuente 4 — Producción de petróleo por empresa

- Dataset: mismo dataset que Fuente 1 ("Producción de petróleo por provincia"),
  recurso distinto.
- URL descarga: http://datos.energia.gob.ar/dataset/590d1284-fd6d-4686-afd8-b3da5d90a6e9/resource/2c1f455e-0103-4d51-8f94-a49c939ac0a1/download/produccin-de-petrleo-promedio-diaria-por-empresa.csv
- Formato: CSV, mismo patron que Fuente 1
- Volumen: 12.642 filas (2009-actualidad)
- Columnas: anio, mes, indice_tiempo, empresa, produccion_petroleo_promedio_dia_m3
- Se espera el mismo bug de "ultimo mes con carga parcial" que Fuente 1 (misma
  fuente/organismo). Aplicar es_periodo_confiable con el mismo criterio.