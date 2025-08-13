# Feast Environment Variables
FEAST_PROJECT=feast_project
FEAST_PORT=${feast_port}
REGISTRY_TYPE=${registry_type}
ONLINE_STORE_TYPE=${online_store_type}
OFFLINE_STORE_TYPE=${offline_store_type}
BIGQUERY_DATASET=${bigquery_dataset}
${use_postgres ? "POSTGRES_HOST=${postgres_host}" : ""}
${use_postgres ? "POSTGRES_PORT=${postgres_port}" : ""}
${use_postgres ? "POSTGRES_DATABASE=${postgres_database}" : ""}
${use_postgres ? "POSTGRES_USER=${postgres_user}" : ""}
${use_postgres ? "POSTGRES_PASSWORD=${postgres_password}" : ""}
