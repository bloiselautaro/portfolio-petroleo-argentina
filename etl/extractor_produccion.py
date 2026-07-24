"""Extractor de produccion de petroleo por provincia (Secretaria de Energia)."""
from pathlib import Path

import requests

from bq_utils import load_csv_to_bigquery, logger

URL = (
    "http://datos.energia.gob.ar/dataset/590d1284-fd6d-4686-afd8-b3da5d90a6e9/"
    "resource/a512fef1-e98e-44af-b940-76168a4bc523/download/"
    "produccin-de-petrleo-promedio-diaria-por-provincia.csv"
)
LOCAL_PATH = Path(__file__).resolve().parent / "_tmp_produccion.csv"
TABLE_NAME = "produccion_petroleo"


def descargar_csv() -> Path:
    logger.info(f"Descargando {URL}")
    response = requests.get(URL, timeout=60)
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