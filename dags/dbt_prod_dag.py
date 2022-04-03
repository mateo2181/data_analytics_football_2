import os
import logging
import pygit2
import subprocess
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator

path_to_local_home = os.environ.get("AIRFLOW_HOME", "/opt/airflow/")

default_args = {
    "owner": "airflow",
    "start_date": datetime(2022, 1, 1),
    "depends_on_past": False,
    "retries": 1,
}

with DAG(
    dag_id="dbt_prod_dag",
    schedule_interval=None,
    default_args=default_args,
    catchup=False,
    max_active_runs=1,
    tags=['data_football'],
) as dag:

    dbt_run = BashOperator(
        task_id='dbt_buid_prod',
        bash_command=f"""
            cd {path_to_local_home}/dbt/football_dbt &&
            export DBT_PROFILES_DIR={path_to_local_home}/config/dbt &&
            dbt build --target prod
        """
    )