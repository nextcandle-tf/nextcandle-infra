# NextCandle Infrastructure

Centralized infrastructure configuration and scripts for the NextCandle ecosystem.

## 📦 Contents
- **ecosystem.config.js**: PM2 configuration for all environments.
- **scripts/**: Utility & maintenance scripts.
- **db/**: Database configurations and migration scripts.
- **redis/**: Redis configuration and persistent storage setup.
- **nginx/**: Reverse proxy and SSL configurations.
- **promtail/**: Log shipping configuration for Loki.
- **loki/**: Log aggregation system configuration.
- **grafana/**: Visualization dashboards for metrics and logs.
- **n8n/**: Workflow automation and integration configs.

## 🚀 Usage (PM2)
This repository is intended to be checked out on the deployment server alongside the other repositories.

### Directory Structure Assumption
The PM2 config assumes the following directory structure on the server:
```
/home/user/nextcandle/
├── nextcandle-web/
├── nextcandle-api/
└── nextcandle-infra/
```

### Starting Services
To start all configured services:
```bash
cd nextcandle-infra
pm2 start ecosystem.config.js
pm2 save
```

### Service List
*   **Production**: `candle-backend-prod` (:5000), `candle-frontend-prod` (:3000)
*   **Staging**: `candle-backend-stg` (:5001), `candle-frontend-stg` (:3001)
*   **Development**: `candle-backend-dev` (:5002), `candle-frontend-dev` (:3002)
