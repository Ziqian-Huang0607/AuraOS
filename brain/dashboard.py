import sqlite3
import pandas as pd
import numpy as np
import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import time

DB_PATH = "/tmp/auraos_state.sqlite"

# Set up the webpage
st.set_page_config(page_title="AuraOS RF Radar", layout="wide")
st.title("📡 AuraOS: Passive RF-Entropy Radar")
st.markdown("Real-time telemetry and spatial mapping of local Bluetooth anomalies.")

def load_data(window_minutes=5):
    """Fetch the last N minutes of telemetry from the Swift Actor's SQLite DB"""
    try:
        conn = sqlite3.connect(DB_PATH, timeout=5)
        cutoff_ms = int((time.time() - (window_minutes * 60)) * 1000)
        query = f"SELECT uuid_hash, rssi, timestamp_ms FROM ble_telemetry WHERE timestamp_ms > {cutoff_ms}"
        df = pd.read_sql_query(query, conn)
        conn.close()
        
        if not df.empty:
            # Convert timestamp to human-readable datetime
            df['datetime'] = pd.to_datetime(df['timestamp_ms'], unit='ms')
            # Calculate an estimated distance (meters) using standard Free Space Path Loss
            # Assuming average TxPower of -59 dBm and Path Loss Exponent of 2.0
            df['distance_m'] = 10 ** ((-59 - df['rssi']) / (10 * 2.0))
            return df
        return pd.DataFrame()
    except Exception as e:
        st.error(f"Database locked or unavailable: {e}")
        return pd.DataFrame()

# Create a placeholder for live updates
placeholder = st.empty()

# Auto-refresh loop
while True:
    df = load_data(window_minutes=2) # Look at the last 2 minutes
    
    with placeholder.container():
        if df.empty:
            st.warning("Awaiting RF Telemetry... (Ensure run.sh is active)")
        else:
            # High-Level Metrics
            total_devices = df['uuid_hash'].nunique()
            avg_rssi = df['rssi'].mean()
            
            col1, col2, col3 = st.columns(3)
            col1.metric("Unique Devices in Range", total_devices)
            col2.metric("Average System RSSI", f"{avg_rssi:.1f} dBm")
            col3.metric("Highest Threat (Closest)", f"{df['distance_m'].min():.1f} m")

            # --- GRAPH 1: THE RADAR MAP ---
            st.subheader("Spatial RF Radar (Estimated Distance)")
            
            # Group by device to get their average distance right now
            radar_df = df.groupby('uuid_hash').agg({'distance_m': 'mean', 'rssi': 'mean'}).reset_index()
            # Assign a random angle (0-360) for visual radar spread, as we only know distance, not direction
            np.random.seed(42) # Keep angles somewhat stable for the same UUIDs
            radar_df['angle'] =[np.random.randint(0, 360) for _ in range(len(radar_df))]
            
            fig_radar = go.Figure()
            fig_radar.add_trace(go.Scatterpolar(
                r=radar_df['distance_m'],
                theta=radar_df['angle'],
                mode='markers',
                marker=dict(
                    size=12,
                    color=radar_df['rssi'], # Color by signal strength
                    colorscale='Viridis',
                    showscale=True,
                    colorbar=dict(title="RSSI (dBm)")
                ),
                text=radar_df['uuid_hash'],
                hoverinfo='text'
            ))
            fig_radar.update_layout(
                polar=dict(
                    radialaxis=dict(visible=True, title=dict(text="Distance (Meters)")),
                    angularaxis=dict(visible=False)
                ),
                showlegend=False,
                height=500
            )
            st.plotly_chart(fig_radar, use_container_width=True)

            # --- GRAPH 2: ENTROPY OVER TIME ---
            st.subheader("RF Chaos/Entropy (RSSI vs Time)")
            fig_line = px.line(df, x='datetime', y='rssi', color='uuid_hash', 
                               title="Signal Variance (High variance = Moving/Transit)",
                               labels={'datetime': 'Time', 'rssi': 'Signal Strength (dBm)'})
            fig_line.update_layout(showlegend=False) # Hide legend because UUIDs are long
            st.plotly_chart(fig_line, use_container_width=True)

    # Sleep for 3 seconds before refreshing the web UI
    time.sleep(3)