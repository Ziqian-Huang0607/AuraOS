package main

/*
#cgo CFLAGS: -x objective-c -fobjc-arc
#cgo LDFLAGS: -framework Foundation -framework CoreBluetooth
#include "bridge.h"
*/
import "C"
import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"time"
)

type SocketMessage struct {
	Type      string `json:"type"`
	UUIDHash  string `json:"uuid_hash"`
	RSSI      int    `json:"rssi"`
	Timestamp int64  `json:"timestamp"`
}

var socketConn net.Conn

//export ReportDevice
func ReportDevice(cUUID *C.char, rssi C.int) {
	uuidStr := C.GoString(cUUID)
	
	// OPSEC: Hash immediately.
	hash := sha256.Sum256([]byte(uuidStr))
	uuidHash := hex.EncodeToString(hash[:])

	msg := SocketMessage{
		Type:      "telemetry",
		UUIDHash:  uuidHash,
		RSSI:      int(rssi),
		Timestamp: time.Now().UnixMilli(),
	}

	jsonData, _ := json.Marshal(msg)
	if socketConn != nil {
		fmt.Fprintf(socketConn, "%s\n", string(jsonData))
	}
}

func main() {
	sockPath := "/tmp/auraos.sock"
	var err error
	
	// Retry loop for socket connection (waits for Swift Actor to boot)
	for i := 0; i < 5; i++ {
		socketConn, err = net.Dial("unix", sockPath)
		if err == nil {
			break
		}
		time.Sleep(1 * time.Second)
	}

	if err != nil {
		log.Fatalf("[-] Failed to connect to Swift Actor. Ensure Actor is running.")
	}
	defer socketConn.Close()

	log.Println("[+] Go Sniffer initialized. Yielding to CoreBluetooth...")
	C.startBLEScan() // Blocks forever
}