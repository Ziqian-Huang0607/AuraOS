import sqlite3
import time
import json
import socket
import numpy as np
from sklearn.cluster import DBSCAN
from collections import defaultdict

DB_PATH = "/tmp/auraos_state.sqlite"
SOCK_PATH = "/tmp/auraos.sock"

class AuraBrain:
    def __init__(self, eps=4.0, min_samples=3):
        self.dbscan = DBSCAN(eps=eps, min_samples=min_samples)
        self.last_context = None
        self.context_buffer =[]

    def fetch_recent_telemetry(self, window_seconds=60):
        try:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cutoff_ms = int((time.time() - window_seconds) * 1000)
            
            # PROXIMITY FILTER: 'AND rssi > -80' creates a digital fence.
            cursor.execute("SELECT uuid_hash, rssi FROM ble_telemetry WHERE timestamp_ms > ? AND rssi > -80", (cutoff_ms,))
            rows = cursor.fetchall()
            conn.close()
            
            history = defaultdict(list)
            for uuid_hash, rssi in rows:
                history[uuid_hash].append(rssi)
            return history
        except sqlite3.OperationalError:
            return {}

    def send_command(self, context_name):
        if context_name == self.last_context:
            return

        self.last_context = context_name
        payload = json.dumps({"type": "command", "context": context_name}) + "\n"
        
        try:
            client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            client.connect(SOCK_PATH)
            client.sendall(payload.encode('utf-8'))
            time.sleep(0.1)
            client.close()
            print(f"\n[!] ---> COMMAND SENT TO SWIFT: {context_name} <---")
        except Exception as e:
            print(f"[-] Socket Error: Could not reach Swift Actor: {e}")

    def analyze(self):
        history = self.fetch_recent_telemetry(window_seconds=60)
        if not history:
            print("[Brain] Waiting for telemetry (or no devices in immediate -80dBm range)...")
            return

        variances =[]
        device_count = len(history)

        for _, rssi_list in history.items():
            if len(rssi_list) > 3:
                variances.append(np.var(rssi_list))

        if not variances:
            return

        X = np.array(variances).reshape(-1, 1)
        clusters = self.dbscan.fit_predict(X)
        noise_count = list(clusters).count(-1)
        stable_count = len(clusters) - noise_count
        avg_variance = np.mean(variances)

        raw_context = "UNKNOWN"
        if avg_variance < 15.0:
            raw_context = "CONTEXT_A_DEEP_WORK"
        elif avg_variance > 25.0 or noise_count > stable_count: # Increased sensitivity
            raw_context = "CONTEXT_C_TRANSIT"
        else:
            raw_context = "CONTEXT_B_SOCIAL"

        print(f"[Brain] Devs (Local Room): {device_count} | Var: {avg_variance:.2f} | Guessed Context: {raw_context}")

        self.context_buffer.append(raw_context)
        if len(self.context_buffer) > 3:
            self.context_buffer.pop(0)
        
        print(f"[Brain] Debounce Buffer: {self.context_buffer}")

        if len(self.context_buffer) == 3 and all(c == raw_context for c in self.context_buffer):
            self.send_command(raw_context)

if __name__ == "__main__":
    print("[+] AuraOS Brain initialized. Waiting for telemetry...")
    brain = AuraBrain()
    while True:
        brain.analyze()
        time.sleep(10)