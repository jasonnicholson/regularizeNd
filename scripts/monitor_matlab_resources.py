#!/usr/bin/env python3
"""
Monitor CPU and RAM usage of a MATLAB process.
Polls every second and logs to a CSV file.
"""

import psutil
import time
import sys
import csv
from datetime import datetime
from pathlib import Path

def find_matlab_process():
    """Find the main MATLAB process."""
    for proc in psutil.process_iter(['pid', 'name']):
        if 'MATLAB' in proc.info['name']:
            return proc
    return None

def monitor_matlab(output_file=None, poll_interval=1):
    """
    Monitor MATLAB process resources.
    
    Args:
        output_file: CSV file to write metrics to. If None, prints to stdout.
        poll_interval: Time in seconds between polls (default: 1)
    """
    if output_file is None:
        output_file = 'matlab_resource_log.csv'
    
    output_path = Path(output_file)
    
    print(f"Waiting for MATLAB process to start...")
    
    # Wait for MATLAB process to appear
    matlab_proc = None
    start_wait = time.time()
    while matlab_proc is None:
        matlab_proc = find_matlab_process()
        if matlab_proc is None:
            if time.time() - start_wait > 30:
                print("ERROR: MATLAB process not found after 30 seconds.")
                sys.exit(1)
            time.sleep(0.5)
    
    print(f"Found MATLAB process (PID: {matlab_proc.pid})")
    print(f"Logging to: {output_path.absolute()}")
    print(f"Monitoring started at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("-" * 80)
    
    # Open CSV file
    with open(output_path, 'w', newline='') as csvfile:
        fieldnames = ['Timestamp', 'Elapsed(s)', 'CPU(%)', 'RSS_MB', 'VMS_MB', 'num_threads']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        start_time = time.time()
        sample_count = 0
        
        try:
            while True:
                try:
                    elapsed = time.time() - start_time
                    
                    # Get CPU and memory info
                    cpu_percent = matlab_proc.cpu_percent(interval=None)
                    mem_info = matlab_proc.memory_info()
                    rss_mb = mem_info.rss / (1024 * 1024)
                    vms_mb = mem_info.vms / (1024 * 1024)
                    num_threads = matlab_proc.num_threads()
                    
                    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
                    
                    row = {
                        'Timestamp': timestamp,
                        'Elapsed(s)': f'{elapsed:.1f}',
                        'CPU(%)': f'{cpu_percent:.1f}',
                        'RSS_MB': f'{rss_mb:.1f}',
                        'VMS_MB': f'{vms_mb:.1f}',
                        'num_threads': num_threads
                    }
                    
                    writer.writerow(row)
                    csvfile.flush()  # Ensure write to disk
                    
                    # Print to console every 10 samples
                    if sample_count % 10 == 0:
                        print(f"[{timestamp}] CPU: {cpu_percent:6.1f}% | RSS: {rss_mb:8.1f} MB | VMS: {vms_mb:8.1f} MB | Threads: {num_threads}")
                    
                    sample_count += 1
                    time.sleep(poll_interval)
                    
                except psutil.NoSuchProcess:
                    # MATLAB process ended
                    elapsed = time.time() - start_time
                    print(f"\nMATLAB process ended at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                    print(f"Total monitoring time: {elapsed:.1f} seconds")
                    print(f"Total samples collected: {sample_count}")
                    print(f"Results saved to: {output_path.absolute()}")
                    break
                    
        except KeyboardInterrupt:
            elapsed = time.time() - start_time
            print(f"\n\nMonitoring stopped at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"Monitoring duration: {elapsed:.1f} seconds")
            print(f"Total samples collected: {sample_count}")
            print(f"Results saved to: {output_path.absolute()}")

if __name__ == "__main__":
    output_file = sys.argv[1] if len(sys.argv) > 1 else 'matlab_resource_log.csv'
    poll_interval = float(sys.argv[2]) if len(sys.argv) > 2 else 1
    monitor_matlab(output_file, poll_interval)
