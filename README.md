# ConqPing

ConqPing is a powerful, cross-platform ping utility designed for network diagnostics and latency monitoring. It is built in C++ for maximum performance and offers detailed statistics.

## Installation

You can install ConqPing with a single command. The installation will automatically download the correct version for your system and make the `conqping` command available globally.

### Windows (PowerShell)

Run the following command in PowerShell:

```powershell
irm https://raw.githubusercontent.com/Comquister/ConqPing/main/install.ps1 | iex
```

### Linux & macOS (Bash)

Run the following command in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Comquister/ConqPing/main/install.sh | bash
```

## Usage

Once installed, you can use the command `conqping` from anywhere.

```bash
conqping <IP>
```

### Examples

**Ping Google DNS:**
```bash
conqping 8.8.8.8
```

**Ping Cloudflare DNS:**
```bash
conqping 1.1.1.1
```

## Features

- **Cross-Platform:** Works on Windows, Linux, and macOS (x64, ARM64, x86).
- **High Performance:** Written in C++ for low overhead.
- **Detailed Stats:** Provides real-time latency updates and packet loss information.
- **Easy Install:** Simple one-line installation scripts.

## Building from Source

If you prefer to build from source, you will need CMake and a C++ compiler.

1. Clone the repository:
   ```bash
   git clone https://github.com/Comquister/ConqPing.git
   cd ConqPing
   ```

2. Generate build files:
   ```bash
   cmake -B build -S cpp
   ```

3. Build:
   ```bash
   cmake --build build --config Release
   ```
