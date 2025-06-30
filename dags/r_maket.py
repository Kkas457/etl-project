from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
import mysql.connector
import psycopg2
from airflow.hooks.base import BaseHook
from datetime import datetime, timedelta

def load_data(transformed_data):
    # Connect to MySQL
    mysql_conn = BaseHook.get_connection('mysql_default')
    mysql_db = mysql.connector.connect(
        host=mysql_conn.host,
        user=mysql_conn.login,
        password=mysql_conn.password,
        database=mysql_conn.schema
    )
    cursor = mysql_db.cursor()
    # Load data into Mysql
    for row in transformed_data:
        cursor.execute("INSERT INTO your_table (column1, column2) VALUES (%s, %s)", row)
    cursor.close()
    mysql_db.close()

def transform_data(data):
    # Example transformation: Convert data to uppercase
    transformed_data = [(str(item).upper() for item in row) for row in data]
    return transformed_data

def extract_data():
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

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': days_ago(1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}
dag = DAG(
    'r_maket',
    default_args=default_args,
    description='A simple ETL DAG',
    schedule_interval='@daily',
)
extract_task = PythonOperator(
    task_id='extract_data',
    python_callable=extract_data,
    dag=dag,
)
transform_task = PythonOperator(
    task_id='transform_data',
    python_callable=transform_data,
    op_kwargs={'data': '{{ task_instance.xcom_pull(task_ids="extract_data") }}'},
    dag=dag,
)
load_task = PythonOperator(
    task_id='load_data',
    python_callable=load_data,
    op_kwargs={'transformed_data': '{{ task_instance.xcom_pull(task_ids="transform_data") }}'},
    dag=dag,
)

extract_task >> transform_task >> load_task