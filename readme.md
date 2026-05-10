# AuraOS: Zero-Emission RF-Entropy Sensing & Active Defense 📡

AuraOS is an autonomous, zero-emission context-adaptation and physical OPSEC engine for macOS. 

Instead of relying on privacy-invasive cameras, microphones, or active network probing that drains battery and leaks MAC addresses, AuraOS introduces **Radio-Physical Privacy**. By passively measuring the density and signal variance (entropy) of ambient Bluetooth (BLE) packets, it deduces your physical environment and autonomously executes Active OS Defense and Workflow Orchestration.

## 🛡️ Active OS Defense Contexts

AuraOS doesn't just change notification labels; it actively manipulates your operating system's threat surface based on physical radio chaos.

*   🟢 **Context A: Deep Work (Static & Isolated)**
    *   *Trigger:* Low radio signal variance (`< 15.0`).
    *   *Action:* Autonomously force-quits distracting applications, unmutes system audio, and engages "Work" Focus Mode.
*   🟡 **Context B: Social / Collaborative (Static Room, Moderate Density)**
    *   *Trigger:* Moderate radio signal variance.
    *   *Action:* Unmutes audio and relaxes restrictions via "Personal" Focus Mode.
*   🔴 **Context C: Transit / High-Threat (Extreme Chaos / Moving)**
    *   *Trigger:* High radio signal variance (`> 25.0`).
    *   *Action (Acoustic & Visual OPSEC):* Instantly **hardware-mutes** system audio, kills sensitive applications, engages "Do Not Disturb," and **locks the screen**.

## 📊 Data & Evaluation
The core hypothesis—that ambient RF entropy can reliably distinguish between physical contexts—is supported by the following data visualizations generated from real-world telemetry.

#### Figure 1: RF-Entropy Across Contexts
This boxplot clearly shows that the variance of Bluetooth signals (RF-Entropy) is a statistically significant feature for separating a quiet room from a busy cafe or a moving subway.
![Figure 1: RF-Entropy](images/Fig1_Environmental_Entropy.png)

#### Figure 2: Context Classification Feature Space
This scatter plot demonstrates that Device Density and RF Signal Variance create clean, classifiable clusters. The red and blue dashed lines represent the simple thresholds used by the AuraOS Brain to make its decisions.
![Figure 2: Feature Space](images/Fig2_Feature_Space.png)

#### Figure 3: System Overhead
This bar chart proves the efficiency of AuraOS. Passive BLE scanning consumes negligible CPU resources (<0.5%) compared to other context-sensing modalities like camera vision or microphone audio, making it suitable for 24/7 background operation.
![Figure 3: System Overhead](images/Fig3_System_Overhead.png)

## ⚙️ Configuration & User Control
AuraOS is controlled via a simple `config.json` file in the project root. This allows you to customize behavior without touching the source code.

```json
{
    "autoModeEnabled": true,
    "deepWorkConfig": {
        "appsToClose": [
            "Messages",
            "Slack",
            "Discord",
            "WeChat"
        ]
    },
    "transitConfig": {
        "appsToClose": [
            "Mail"
        ]
    }
}
```
*   `autoModeEnabled`: Set to `false` to temporarily disable all autonomous actions.
*   `appsToClose`: Add or remove any application name to the lists to customize which apps are terminated in each context.

## 🚀 Setup & Installation
**Prerequisites:** 
- macOS (M-Series recommended)
- Go (1.16+)
- Python (3.9+)
- Xcode Command Line Tools (`xcode-select --install`)
- A macOS Shortcut named exactly **`Set Focus`** (see instructions in issue logs).

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/AuraOS.git
cd AuraOS

# Create and customize your configuration
cp config.json.example config.json
nano config.json

# Build and Boot the Grid
chmod +x run.sh
./run.sh
```
*Note: On first run, macOS will prompt you to grant Bluetooth permissions to your Terminal.*

## 🔒 OPSEC & Privacy Note
This tool strictly performs **passive reconnaissance**. It does not broadcast BLE beacons, it does not attempt to pair to devices, and it immediately SHA-256 hashes all intercepted identifiers. No plaintext MAC addresses ever touch the disk.