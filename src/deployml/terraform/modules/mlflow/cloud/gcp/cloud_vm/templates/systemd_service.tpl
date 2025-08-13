[Unit]
Description=MLflow Docker Compose Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
User=${current_user}
Group=${current_user}
WorkingDirectory=/home/${current_user}/deployml/docker
Environment=MLFLOW_BACKEND_STORE_URI=${backend_store_uri}
Environment=MLFLOW_DEFAULT_ARTIFACT_ROOT=${artifact_bucket != "" ? "gs://${artifact_bucket}" : "./mlflow-artifacts"}
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose restart
Restart=no
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
