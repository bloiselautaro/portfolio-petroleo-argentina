from pathlib import Path
import os

ROOT_DIR = Path(__file__).resolve().parent
CREDENTIALS_PATH = ROOT_DIR / "petroleo-etl-key.json"

GCP_PROJECT_ID = "portfolio-petroleo-argentina"
RAW_DATASET = "raw_petroleo"
ANALYTICS_DATASET = "analytics_petroleo"

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(CREDENTIALS_PATH)
