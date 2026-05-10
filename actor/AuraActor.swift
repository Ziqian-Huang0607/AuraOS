import Foundation
import Network
import SQLite3

// --- Configuration Data Structures ---
struct AppConfig: Codable {
    let autoModeEnabled: Bool
    let deepWorkConfig: ContextConfig
    let transitConfig: ContextConfig
}

struct ContextConfig: Codable {
    let appsToClose: [String]
}


// --- Main Application Logic ---
class AuraActor {
    let socketPath = "/tmp/auraos.sock"
    let dbPath = "/tmp/auraos_state.sqlite"
    var listener: NWListener?
    var db: OpaquePointer?
    var config: AppConfig?

    init() {
        loadConfig()
        setupDatabase()
    }
    
    private func loadConfig() {
        // Assume run.sh is executed from the project root
        let configPath = FileManager.default.currentDirectoryPath + "/config.json"
        do {
            let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
            self.config = try JSONDecoder().decode(AppConfig.self, from: configData)
            print("[+] Configuration loaded successfully.")
        } catch {
            print("[-] FATAL: Could not load or parse config.json. \(error)")
            print("[-] Ensure config.json exists in the AuraOS root directory.")
        }
    }
    
    func setupDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK { print("[-] Error opening SQLite DB"); return }
        let createTableQuery = "CREATE TABLE IF NOT EXISTS ble_telemetry (id INTEGER PRIMARY KEY AUTOINCREMENT, uuid_hash TEXT NOT NULL, rssi INTEGER NOT NULL, timestamp_ms INTEGER NOT NULL);"
        if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK { print("[-] Error creating table") }
        print("[+] SQLite Database initialized at \(dbPath)")
    }

    func startListening() {
        unlink(socketPath)
        let unixSocketParams = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        unixSocketParams.requiredLocalEndpoint = NWEndpoint.unix(path: socketPath)
        do {
            listener = try NWListener(using: unixSocketParams)
            listener?.stateUpdateHandler = { state in if case .ready = state { print("[+] Swift Actor Listening on \(self.socketPath)") } }
            listener?.newConnectionHandler = { connection in connection.start(queue: .global()); self.receiveData(on: connection) }
            listener?.start(queue: .main)
        } catch { print("[-] Failed to create Unix socket: \(error)") }
    }

    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
            if let data = data, let messages = String(data: data, encoding: .utf8) {
                messages.split(separator: "\n").forEach { self.processMessage(String($0)) }
            }
            if error == nil && !isComplete { self.receiveData(on: connection) }
        }
    }

    private func processMessage(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        if type == "telemetry" {
            guard let hash = json["uuid_hash"] as? String, let rssi = json["rssi"] as? Int, let ts = json["timestamp"] as? Int64 else { return }
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, "INSERT INTO ble_telemetry (uuid_hash, rssi, timestamp_ms) VALUES (?, ?, ?);", -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (hash as NSString).utf8String, -1, nil); sqlite3_bind_int(statement, 2, Int32(rssi)); sqlite3_bind_int64(statement, 3, ts); sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        } else if type == "command" {
            if let context = json["context"] as? String { executeContextAction(context) }
        }
    }

    private func runShell(_ command: String) {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", command]
        try? task.run()
        task.waitUntilExit()
    }

    private func executeContextAction(_ context: String) {
        guard let config = self.config, config.autoModeEnabled else {
            print("[!] Auto-Mode is disabled in config.json. Ignoring context shift.")
            return
        }
        
        print("\n========================================")
        print("[!] ENGAGING OS CONTEXT SHIFT: \(context)")
        print("========================================\n")
        
        switch context {
        case "CONTEXT_A_DEEP_WORK":
            print(" -> [DEFENSE] Optimizing for Deep Work.")
            print(" -> [ACTION] Terminating configured apps: \(config.deepWorkConfig.appsToClose.joined(separator: ", "))")
            for app in config.deepWorkConfig.appsToClose { runShell("osascript -e 'tell application \"\(app)\" to quit'") }
            print(" -> [ACTION] Unmuting Audio for calls.")
            runShell("osascript -e 'set volume output muted false'")
            print(" -> [ACTION] Engaging Work Focus.")
            runShell("shortcuts run \"Set Focus\" <<< \"Work\"")

        case "CONTEXT_C_TRANSIT":
            print(" -> [DEFENSE] High Threat Environment Detected (Transit).")
            print(" -> [ACTION] Terminating configured apps: \(config.transitConfig.appsToClose.joined(separator: ", "))")
            for app in config.transitConfig.appsToClose { runShell("osascript -e 'tell application \"\(app)\" to quit'") }
            print(" -> [ACTION] Hardware Audio Muted.")
            runShell("osascript -e 'set volume output muted true'")
            print(" -> [ACTION] Engaging Do Not Disturb.")
            runShell("shortcuts run \"Set Focus\" <<< \"Do Not Disturb\"")
            print(" -> [ACTION] Locking Screen to protect data.")
            runShell("pmset displaysleepnow")

        default: // CONTEXT_B_SOCIAL
            print(" -> [DEFENSE] Social Collaboration Environment.")
            print(" -> [ACTION] Unmuting Audio.")
            runShell("osascript -e 'set volume output muted false'")
            runShell("shortcuts run \"Set Focus\" <<< \"Personal\"")
        }
    }
}

let actor = AuraActor()
actor.startListening()
RunLoop.main.run()