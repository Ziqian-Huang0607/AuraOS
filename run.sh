#!/bin/bash

echo "[!] Booting AuraOS Ecosystem..."

# 1. Start the Swift System Actor (Run in background)
echo "[+] Compiling and starting Swift Actor..."
swift actor/AuraActor.swift &
ACTOR_PID=$!
sleep 2 # Give the socket time to bind

# 2. Compile and Start Go Sniffer
echo "[+] Compiling Go Sniffer..."
cd sniffer
# Initialize go.mod if it doesn't exist
if [ ! -f "go.mod" ]; then
    go mod init sniffer
fi
go build -o sniffer_bin .
cd ..
echo "[+] Starting Sniffer (requires Bluetooth Permissions)..."
./sniffer/sniffer_bin &
SNIFFER_PID=$!

# 3. Setup Python Virtual Environment & Start Brain
echo "[+] Setting up Python Brain..."
cd brain
# Check if venv exists, create if it doesn't
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install -r requirements.txt -q
python3 brain.py &
BRAIN_PID=$!
cd ..

# Trap SIGINT (Ctrl+C) to gracefully kill all processes
trap "echo -e '\n[!] Shutting down AuraOS...'; kill $ACTOR_PID $SNIFFER_PID $BRAIN_PID; exit" SIGINT

echo "[*] AuraOS is running in passive mode. Press Ctrl+C to terminate."
wait