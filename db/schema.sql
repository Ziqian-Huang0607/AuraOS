CREATE TABLE IF NOT EXISTS ble_telemetry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid_hash TEXT NOT NULL,
    rssi INTEGER NOT NULL,
    timestamp_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS known_contexts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    context_name TEXT NOT NULL,
    device_density INTEGER,
    avg_variance REAL,
    last_seen_ms INTEGER NOT NULL
);