"""Extractor de precios en surtidor - Resolucion 314/2016 (Secretaria de Energia)."""
from pathlib import Path

import requests

from bq_utils import load_csv_to_bigquery, logger

URL = (
    "http://datos.energia.gob.ar/dataset/1c181390-5045-475e-94dc-410429be4b17/"
    "resource/80ac25de-a44a-4445-9215-090cf55cfda5/download/"
    "precios-en-surtidor-resolucin-3142016.csv"
)
LOCAL_PATH = Path(__file__).resolve().parent / "_tmp_precios.csv"
TABLE_NAME = "precios_surtidor"


def descargar_csv() -> Path:
    logger.info(f"Descargando {URL}")
    response = requests.get(URL, timeout=120)
    response.raise_for_status()
    LOCAL_PATH.write_bytes(response.content)
    logger.info(f"CSV guardado en {LOCAL_PATH} ({len(response.content)} bytes)")
    return LOCAL_PATH


def main() -> None:
    csv_path = descargar_csv()
    load_csv_to_bigquery(csv_path, TABLE_NAME)
    csv_path.unlink()


if __name__ == "__main__":
    main()