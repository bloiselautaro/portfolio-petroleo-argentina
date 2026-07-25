"""Extractor de precio del petroleo Brent (FRED - Federal Reserve Bank of St. Louis)."""
from pathlib import Path

import requests

from bq_utils import load_csv_to_bigquery, logger

URL = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=DCOILBRENTEU"
LOCAL_PATH = Path(__file__).resolve().parent / "_tmp_brent.csv"
TABLE_NAME = "precio_brent"

HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}


def descargar_csv() -> Path:
    logger.info(f"Descargando {URL}")
    response = requests.get(URL, headers=HEADERS, timeout=120)
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