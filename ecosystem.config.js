module.exports = {
  apps: [
    // --- PRODUCTION (Main Branch) ---
    {
      name: 'candle-backend-prod',
      script: '/home/andy/nextcandle/nextcandle-api/ml/.venv/bin/gunicorn',
      interpreter: '/home/andy/nextcandle/nextcandle-api/ml/.venv/bin/python3',
      args: '-c gunicorn_config.py -b 0.0.0.0:5000 pattern_api:app',
      cwd: '/home/andy/nextcandle/nextcandle-api',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '4G',
      env: {
        FLASK_APP: 'pattern_api.py',
        FLASK_ENV: 'production',
        PORT: 5000
      }
    },
    {
      name: 'candle-frontend-prod',
      script: 'npm',
      args: 'start',
      cwd: '/home/andy/nextcandle/nextcandle-web',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_restarts: 10,
      min_uptime: '5s',
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
        API_PORT: 5000
      }
    },

    // --- STAGING (Stg Branch) ---
    {
      name: 'candle-backend-stg',
      script: '/home/andy/nextcandle/nextcandle-api/ml/.venv/bin/gunicorn',
      interpreter: '/home/andy/nextcandle/nextcandle-api/ml/.venv/bin/python3',
      args: '-c gunicorn_config.py -b 0.0.0.0:5001 pattern_api:app',
      cwd: '/home/andy/nextcandle/nextcandle-api',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '4G',
      env: {
        FLASK_APP: 'pattern_api.py',
        FLASK_ENV: 'staging',
        PORT: 5001
      }
    },
    {
      name: 'candle-frontend-stg',
      script: 'npm',
      args: 'start',
      cwd: '/home/andy/nextcandle/nextcandle-web',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_restarts: 10,
      min_uptime: '5s',
      env: {
        NODE_ENV: 'production',
        PORT: 3001,
        API_PORT: 5001
      }
    },

    // --- DEVELOPMENT (Dev Branch) ---
    {
      name: 'candle-backend-dev',
      script: '/home/andy/nextcandle/nextcandle-api/ml/.venv/bin/gunicorn',
      interpreter: '/home/andy/nextcandle/nextcandle-api/ml/.venv/bin/python3',
      args: '-c gunicorn_config.py -b 0.0.0.0:5002 --reload pattern_api:app',
      cwd: '/home/andy/nextcandle/nextcandle-api',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false, // Gunicorn --reload handles watching
      ignore_watch: ['api/*.db*', 'api/**/*.db*', '*.db*', 'api/*.log', 'api/__pycache__'],
      max_memory_restart: '4G',
      env: {
        FLASK_APP: 'pattern_api.py',
        FLASK_ENV: 'development',
        PORT: 5002,
        PYTORCH_CUDA_ALLOC_CONF: 'expandable_segments:True'
      }
    },
    {
      name: 'candle-frontend-dev',
      script: 'npm',
      args: 'run dev',
      cwd: '/home/andy/nextcandle/nextcandle-web',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_restarts: 10,
      min_uptime: '5s',
      env: {
        NODE_ENV: 'development',
        PORT: 3002,
        API_PORT: 5002,
        DIST_DIR: '.next-dev'
      }
    }
  ]
};
