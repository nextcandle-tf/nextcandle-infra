
import requests
import concurrent.futures
import random
import time
from datetime import datetime, timedelta

# Configuration
API_URL = "http://localhost:5001/api/historical-analysis"  # Assuming Staging/Dev port, checking later
# dev is usually port 5000 or 5002, let's check ecosystem.config.js but I'll make it configurable or try port 5000 first (prod) or 5001 (stg). 
# Wait, dev in ecosystem is candle-backend-dev.
# I will check the port usage. Usually dev might be a different port. 
# Based on ecosystem.config.js viewed earlier:
# candle-backend-prod: 5000
# candle-backend-stg: 5001
# candle-backend-dev: likely 5002 (need to verify)

API_URL_DEV = "http://localhost:5002/api/historical-analysis" 

CONCURRENT_USERS = 20
TOTAL_REQUESTS = 100

def generate_random_params():
    # Random historical point between 2018 and 2024
    start_date = datetime(2018, 1, 1)
    end_date = datetime(2024, 1, 1)
    random_days = random.randrange((end_date - start_date).days)
    random_date = start_date + timedelta(days=random_days)
    
    # 09:00, 13:00, 17:00, 21:00, 01:00, 05:00 usually for 4H candles
    valid_hours = [1, 5, 9, 13, 17, 21] 
    random_hour = random.choice(valid_hours)
    
    historical_point = random_date.replace(hour=random_hour, minute=0, second=0).strftime('%Y-%m-%d %H:%M')
    
    # query_length from allowed list
    query_length = random.choice([3, 5, 10, 20, 30])
    
    return {
        'symbol': 'BTC/USDT',
        'timeframe': '4H',
        'historical_point': historical_point,
        'query_length': query_length,
        'target_length': query_length, # Pattern length = Target length in new UI
        'top_k': 5
    }

def send_request(request_id):
    params = generate_random_params()
    start_time = time.time()
    try:
        response = requests.post(API_URL_DEV, json=params, timeout=30)
        elapsed = time.time() - start_time
        status = response.status_code
        try:
            data = response.json()
            success = 'similar_patterns' in data
        except:
            success = False
            
        return {
            'id': request_id,
            'status': status,
            'elapsed': elapsed,
            'success': success,
            'params': params
        }
    except Exception as e:
        return {
            'id': request_id,
            'status': 'Error',
            'elapsed': time.time() - start_time,
            'success': False,
            'error': str(e)
        }

def run_stress_test():
    print(f"Starting Stress Test on {API_URL_DEV}")
    print(f"Users: {CONCURRENT_USERS}, Total Requests: {TOTAL_REQUESTS}")
    
    results = []
    start_total = time.time()
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=CONCURRENT_USERS) as executor:
        futures = [executor.submit(send_request, i) for i in range(TOTAL_REQUESTS)]
        
        for i, future in enumerate(concurrent.futures.as_completed(futures)):
            res = future.result()
            results.append(res)
            print(f"[{i+1}/{TOTAL_REQUESTS}] Status: {res['status']}, Time: {res['elapsed']:.2f}s, Success: {res['success']}")

    end_total = time.time()
    total_time = end_total - start_total
    
    success_count = sum(1 for r in results if r['success'])
    avg_time = sum(r['elapsed'] for r in results) / len(results)
    
    print("\n--- Test Summary ---")
    print(f"Total Time: {total_time:.2f}s")
    print(f"Throughput: {len(results)/total_time:.2f} req/s")
    print(f"Success Rate: {success_count}/{len(results)} ({success_count/len(results)*100:.1f}%)")
    print(f"Avg Response Time: {avg_time:.2f}s")

if __name__ == "__main__":
    run_stress_test()
