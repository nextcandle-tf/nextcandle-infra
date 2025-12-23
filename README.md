# NextCandle Infrastructure

Centralized infrastructure configuration and scripts for the NextCandle ecosystem.

## 📦 Contents
*   **ecosystem.config.js**: The master PM2 configuration file that orchestrates the `nextcandle-web` and `nextcandle-api` services across Production, Staging, and Development environments.
*   **scripts/**: Utility & Maintenance scripts (e.g., monitoring, setup).

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
