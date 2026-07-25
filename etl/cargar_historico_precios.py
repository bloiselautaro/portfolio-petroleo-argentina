"""
Script de carga UNICA (backfill) del historico de precios en surtidor.
NO forma parte del pipeline automatico diario -- se corre una sola vez a mano.
Fuente: datos.energia.gob.ar, recurso "Precios historicos" (738 MB).
"""
from pathlib import Path

from bq_utils import load_csv_to_bigquery, logger

CSV_PATH = Path(r"C:\portfolio-petroleo\precios-historicos.csv")
TABLE_NAME = "precios_historicos_raw"


def main() -> None:
    logger.info(f"Cargando {CSV_PATH} a BigQuery (puede tardar varios minutos)")
    load_csv_to_bigquery(CSV_PATH, TABLE_NAME)


if __name__ == "__main__":
    main()