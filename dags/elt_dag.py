import os
import logging
import pygit2
import subprocess
from datetime import datetime

from airflow import DAG
from airflow.utils.dates import days_ago
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

from google.cloud import storage
from airflow.providers.google.cloud.operators.bigquery import BigQueryCreateExternalTableOperator
import pyarrow.csv as pv
import pyarrow.parquet as pq

PROJECT_ID = os.environ.get("GCP_PROJECT_ID")
BUCKET = os.environ.get("GCP_GCS_BUCKET")
BIGQUERY_DATASET = os.environ.get("GCP_BIGQUERY_DATASET")

leagues: list = [
    'dutch_eredivisie',
    'english_premier_league',
    'french_ligue_1',
    'german_bundesliga_1',
    'italian_serie_a',
    'portugese_liga_nos',
    'spanish_primera_division'
]

dataset_url = 'https://raw.githubusercontent.com/ewenme/transfers/master/data'

path_to_local_home = os.environ.get("AIRFLOW_HOME", "/opt/airflow/")

def format_to_parquet(src_file):
    if not src_file.endswith('.csv'):
        logging.error("Can only accept source files in CSV format, for the moment")
        return
    table = pv.read_csv(src_file)
    pq.write_table(table, src_file.replace('.csv', '.parquet'))


# NOTE: takes 20 mins, at an upload speed of 800kbps. Faster if your internet has a better upload speed
def upload_to_gcs(bucket, object_name, local_file):
    """
    Ref: https://cloud.google.com/storage/docs/uploading-objects#storage-upload-object-python
    :param bucket: GCS bucket name
    :param object_name: target path & file-name
    :param local_file: source path & file-name
    :return:
    """
    # WORKAROUND to prevent timeout for files > 6 MB on 800 kbps upload speed.
    # (Ref: https://github.com/googleapis/python-storage/issues/74)
    storage.blob._MAX_MULTIPART_SIZE = 5 * 1024 * 1024  # 5 MB
    storage.blob._DEFAULT_CHUNKSIZE = 5 * 1024 * 1024  # 5 MB
    # End of Workaround

    client = storage.Client()
    bucket = client.bucket(bucket)

    blob = bucket.blob(object_name)
    blob.upload_from_filename(local_file)


def pull_dbt_repo():
    subprocess.run(["rm", "-rf", "dbt"]) # Delete folder on run
    # git_token = GITHUB_ACCESS_TOKEN
    dbt_repo_name = "football_data_dbt"
    # dbt_repo = (f"https://{git_token}:x-oauth-basic@github.com/mateo2181/{dbt_repo_name}")
    dbt_repo = (f"https://github.com/mateo2181/{dbt_repo_name}")
    pygit2.clone_repository(dbt_repo, "dbt")


default_args = {
    "owner": "airflow",
    "depends_on_past": True,
    "retries": 1,
}

year = '{{ execution_date.strftime(\'%Y\') }}'

with DAG(
    dag_id="elt_dag_v3",
    schedule_interval="@yearly",
    start_date=datetime(1999, 12, 31),
    default_args=default_args,
    catchup=True,
    max_active_runs=1,
    tags=['data_football'],
) as dag:

    bigquery_table_task = BigQueryCreateExternalTableOperator(
        task_id="bigquery_table_task",
        table_resource={
            "tableReference": {
                "projectId": PROJECT_ID,
                "datasetId": BIGQUERY_DATASET,
                "tableId": "transfers",
            },
            "externalDataConfiguration": {
                "sourceFormat": "PARQUET",
                "sourceUris": [f"gs://{BUCKET}/*"],
            },
        },
    )

    pull_dbt_repository = PythonOperator(
        task_id=f"pull_dbt_repository",
        python_callable=pull_dbt_repo,
    )

    dbt_run = BashOperator(
        task_id='dbt_buid_dev',
        bash_command=f"""
            cd {path_to_local_home}/dbt/football_dbt &&
            export DBT_PROFILES_DIR={path_to_local_home}/config/dbt &&
            dbt build
        """,
    )

    for league in leagues:
        dataset_file = f"{league}.csv"
        parquet_file = dataset_file.replace('.csv', '.parquet')

        githubLink = f"{dataset_url}/{year}/{league}.csv"
        download_dataset_task = BashOperator(
            task_id=f"download_dataset_task_{league}",
            bash_command=f"curl -sSL {githubLink} > {path_to_local_home}/{dataset_file}"
        )

        format_to_parquet_task = PythonOperator(
            task_id=f"format_to_parquet_task_{league}",
            python_callable=format_to_parquet,
            op_kwargs={
                "src_file": f"{path_to_local_home}/{dataset_file}",
            },
        )

        local_to_gcs_task = PythonOperator(
            task_id=f"local_to_gcs_task_{league}",
            python_callable=upload_to_gcs,
            op_kwargs={
                "bucket": BUCKET,
                "object_name": f"{year}/{parquet_file}",
                "local_file": f"{path_to_local_home}/{parquet_file}",
            },
        )

        remove_tmp_file = BashOperator(
            task_id=f"remove_tmp_file_task_{league}",
            bash_command=f"rm {path_to_local_home}/{dataset_file} {path_to_local_home}/{parquet_file}"
        )

        download_dataset_task >> format_to_parquet_task >> local_to_gcs_task >> remove_tmp_file >> bigquery_table_task >> pull_dbt_repository >> dbt_run