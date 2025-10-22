# Airflow FAB Docker Image

The Apache Airflow helm chart under [charts/airflow](https://github.com/airflow-helm/charts/tree/main/charts/airflow) uses this docker image to provide [Apache Airflow](https://airflow.apache.org/) v3 with [Flask AppBuilder (FAB)](https://flask-appbuilder.readthedocs.io/) support.

### Important Links:
- The [Dockerfile](https://github.com/airflow-helm/charts/blob/main/images/airflow-fab/3/Dockerfile) for this image.

### Pull Locations:
- [GitHub Container Registry](http://ghcr.io/airflow-helm/airflow-fab):
  - `docker pull ghcr.io/airflow-helm/airflow-fab:3-latest`

### About This Image:
This image extends the official Apache Airflow v3 image with the `apache-airflow-providers-fab` package pre-installed. This provides Flask AppBuilder functionality for Airflow v3, which is useful for environments that require the FAB-based UI and authentication system.
