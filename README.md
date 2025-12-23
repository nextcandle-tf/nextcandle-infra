# NextCandle Infrastructure

Infrastructure configuration and scripts for NextCandle.

## Contents
- **ecosystem.config.js**: PM2 configuration for managing processes (Web, API).
- **scripts/**: Maintenance and utility scripts.

## Usage
Start all services using PM2:
```bash
pm2 start ecosystem.config.js
```
