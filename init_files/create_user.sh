#!/bin/bash
airflow db init
airflow users create --username admin --firstname Admin --lastname User --role Admin --email mutanterfmika@gmail.com --password Mika2u7w || true

exec airflow "$@"
