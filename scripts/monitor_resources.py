
import time
import csv
import psutil
import subprocess
import os
from datetime import datetime

LOG_FILE = 'stress_test_log.csv'
TARGET_PORT = 5002  # Dev Backend Port

def get_gpu_info():
    try:
        # Run nvidia-smi to get memory used and utilization
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=memory.used,utilization.gpu', '--format=csv,noheader,nounits'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            if lines:
                mem_used, util = lines[0].split(',')
                return int(mem_used), int(util)
    except Exception as e:
        pass
    return 0, 0

def find_target_process():
    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            cmdline = proc.info.get('cmdline')
            if cmdline:
                # Look for the gunicorn process binding to the target port
                if 'gunicorn' in proc.info['name'] and any(str(TARGET_PORT) in arg for arg in cmdline):
                    # If it's the master process, we might want children, but let's stick to simple identification first.
                    # Alternatively, if we see pattern_api:app, that's good.
                    # The worker usually consumes the most. Let's return the one with highest memory among matches.
                    pass
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
            
    # Refined search: Find all processes related to 'pattern_api:app' and port 5002
    candidates = []
    for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'memory_info']):
        try:
            cmdline = proc.info.get('cmdline') or []
            if any(str(TARGET_PORT) in str(arg) for arg in cmdline) and 'python' in proc.info['name']:
                 candidates.append(proc)
        except:
            pass
    
    if candidates:
        # Return process with max memory usage (likely the active worker)
        return max(candidates, key=lambda p: p.info['memory_info'].rss)
    return None

def monitor():
    print(f"Starting detailed resource monitor. Logging to {LOG_FILE}...")
    
    headers = [
        'Timestamp', 
        'Sys_CPU_Pct', 'Sys_RAM_Pct', 'Sys_RAM_Used_MB', 
        'Load_1m', 'Load_5m',
        'Net_Sent_MB', 'Net_Recv_MB',
        'Proc_CPU_Pct', 'Proc_RAM_MB',
        'GPU_Mem_MiB', 'GPU_Util_Pct'
    ]

    # Initialize CSV
    with open(LOG_FILE, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)

    try:
        with open(LOG_FILE, 'a', newline='') as f:
            writer = csv.writer(f)
            while True:
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                # System Stats
                sys_cpu = psutil.cpu_percent(interval=None)
                ram = psutil.virtual_memory()
                sys_ram_pct = ram.percent
                sys_ram_used = ram.used / (1024**2)
                
                load_avg = psutil.getloadavg() # (1m, 5m, 15m)
                
                net = psutil.net_io_counters()
                net_sent = net.bytes_sent / (1024**2)
                net_recv = net.bytes_recv / (1024**2)
                
                # GPU Stats
                gpu_mem, gpu_util = get_gpu_info()
                
                # Process Stats
                proc_cpu = 0.0
                proc_ram = 0.0
                target_proc = find_target_process()
                if target_proc:
                    try:
                        # cpu_percent(interval=None) compares to last call, so first call is 0. 
                        # We need it to be persistent or just accept 0 first time.
                        proc_cpu = target_proc.cpu_percent(interval=None) 
                        proc_ram = target_proc.memory_info().rss / (1024**2)
                    except:
                        pass # Process might have died

                row = [
                    timestamp,
                    sys_cpu, sys_ram_pct, f"{sys_ram_used:.1f}",
                    f"{load_avg[0]:.2f}", f"{load_avg[1]:.2f}",
                    f"{net_sent:.1f}", f"{net_recv:.1f}",
                    f"{proc_cpu:.1f}", f"{proc_ram:.1f}",
                    gpu_mem, gpu_util
                ]
                
                writer.writerow(row)
                f.flush()
                
                print(f"[{timestamp}] CPU:{sys_cpu}% | RAM:{sys_ram_pct}% | Proc:{proc_ram:.0f}MB | GPU:{gpu_mem}MiB", end='\r')
                time.sleep(1)
    except KeyboardInterrupt:
        print("\nMonitoring stopped.")

if __name__ == "__main__":
    monitor()
