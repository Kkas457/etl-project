FROM apache/airflow:2.7.0

USER root

# Установка системной зависимости для LightGBM
RUN apt-get update && apt-get install -y libgomp1

# Копируем скрипт и requirements
COPY ./init_files/create_user.sh /create_user.sh
COPY requirements.txt /requirements.txt
RUN chmod +x /create_user.sh

USER airflow

# Установка зависимостей под пользователем airflow
RUN pip install --no-cache-dir clickhouse-driver dbt-core dbt-clickhouse && \
    pip install --no-cache-dir -r /requirements.txt

ENTRYPOINT ["/create_user.sh"]
CMD ["airflow", "webserver"]
