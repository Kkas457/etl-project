from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from clickhouse_driver import Client
import psycopg2
from airflow.hooks.base import BaseHook
from datetime import datetime, timedelta

def fetch_data_from_postgres():
    # Connect to PostgreSQL
    postgres_conn = BaseHook.get_connection('postgres_default')
    postgres_db = psycopg2.connect(
        host=postgres_conn.host,
        user=postgres_conn.login,
        password=postgres_conn.password,
        dbname=postgres_conn.schema
    )
    cursor = postgres_db.cursor()
    
    # Extract data from PostgreSQL
    cursor.execute("SELECT * FROM mrr.customer")
    data = cursor.fetchall()
    
    cursor.close()
    postgres_db.close()
    
    return data

def load_data_to_clickhouse(data):
    # Connect to ClickHouse
    clickhouse_conn = BaseHook.get_connection('clickhouse_default')
    client = Client(
        host=clickhouse_conn.host,
        user=clickhouse_conn.login,
        password=clickhouse_conn.password,
        database=clickhouse_conn.schema
    )
    
    # Load data into ClickHouse
    client.execute("INSERT INTO mrr.customer (column1, column2) VALUES", data)

def etl_process():
    # Extract data from PostgreSQL
    data = fetch_data_from_postgres()
    
    # Load data into ClickHouse
    load_data_to_clickhouse(data)


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': days_ago(1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}
dag = DAG(
    'g_research',
    default_args=default_args,
    description='A simple ETL DAG for ClickHouse',
    schedule_interval='@daily',
)
etl_process = PythonOperator(
    task_id='etl_process',
    python_callable=etl_process,
    dag=dag,
)
