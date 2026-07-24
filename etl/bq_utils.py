import logging
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent.parent))
from config import GCP_PROJECT_ID, RAW_DATASET, CREDENTIALS_PATH

from google.cloud import bigquery
from google.oauth2 import service_account

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger(__name__)


def get_bq_client() -> bigquery.Client:
    credentials = service_account.Credentials.from_service_account_file(str(CREDENTIALS_PATH))
    return bigquery.Client(project=GCP_PROJECT_ID, credentials=credentials)


def load_csv_to_bigquery(csv_path: Path, table_name: str) -> None:
    """Carga un CSV local a una tabla de raw_petroleo, reemplazando el contenido existente."""
    client = get_bq_client()
    table_id = f"{GCP_PROJECT_ID}.{RAW_DATASET}.{table_name}"

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        autodetect=True,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    with open(csv_path, "rb") as f:
        load_job = client.load_table_from_file(f, table_id, job_config=job_config)

    load_job.result()

    table = client.get_table(table_id)
    logger.info(f"Cargado {table.num_rows} filas en {table_id}")