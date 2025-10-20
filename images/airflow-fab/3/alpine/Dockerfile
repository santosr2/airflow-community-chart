ARG VERSION=3.1.0-python3.12-alpine
ARG FAB_VERSION=3.0.0

FROM apache/airflow:${VERSION}

RUN pip install --no-cache-dir apache-airflow-providers-fab==${FAB_VERSION}
