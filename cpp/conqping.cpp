#include <iostream>
#include <string>
#include <vector>
#include <thread>
#include <chrono>
#include <iomanip>
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <cmath>

#ifdef _WIN32
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #pragma comment(lib, "ws2_32.lib")
    typedef int socklen_t;
    #define CLOSE_SOCKET(s) closesocket(s)
    #define IS_VALID_SOCKET(s) ((s) != INVALID_SOCKET)
#else
    #include <sys/types.h>
    #include <sys/socket.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    #include <unistd.h>
    #include <netdb.h>
    #include <fcntl.h>
    #define SOCKET int
    #define INVALID_SOCKET -1
    #define SOCKET_ERROR -1
    #define CLOSE_SOCKET(s) close(s)
    #define IS_VALID_SOCKET(s) ((s) >= 0)
#endif

// ANSI Color Codes (High Intensity)
const std::string ANSI_RESET = "\u001B[0m";
const std::string ANSI_RED = "\u001B[91m";
const std::string ANSI_GREEN = "\u001B[92m";
const std::string ANSI_YELLOW = "\u001B[93m";
const std::string ANSI_BLUE = "\u001B[94m";

// Globals
std::string host;
int port = 80;
int count = -1;
int timeout = 1000;
int interval = 1000;
bool forceV4 = false;
bool forceV6 = false;

struct Stats {
    std::vector<double> times;
    int connected = 0;
    int failed = 0;
} stats;

void printUsage() {
    std::cout << "Usage: conqping [host] [options]\n"
              << "Options:\n"
              << "  -p, --port <port>       Port to connect to (default: 80)\n"
              << "  -c, --count <count>     Number of regular pings to send (default: infinite)\n"
              << "  -t, --timeout <ms>      Connection timeout in milliseconds (default: 1000)\n"
              << "  --interval <ms>         Interval between pings in milliseconds (default: 1000)\n"
              << "  -4                      Force IPv4 resolution\n"
              << "  -6                      Force IPv6 resolution\n"
              << "  -h, --help              Show this help message\n";
}

void parseArgs(int argc, char* argv[]) {
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg[0] == '-') {
            if (arg == "-p" || arg == "--port") {
                if (i + 1 < argc) port = std::stoi(argv[++i]);
            } else if (arg == "-c" || arg == "--count") {
                if (i + 1 < argc) count = std::stoi(argv[++i]);
            } else if (arg == "-t" || arg == "--timeout") {
                if (i + 1 < argc) timeout = std::stoi(argv[++i]);
            } else if (arg == "--interval") {
                if (i + 1 < argc) interval = std::stoi(argv[++i]);
            } else if (arg == "-4") {
                forceV4 = true;
            } else if (arg == "-6") {
                forceV6 = true;
            } else if (arg == "-h" || arg == "--help") {
                printUsage();
                exit(0);
            }
        } else {
            host = arg;
        }
    }

    if (host.empty()) {
        std::cerr << "Host is required.\n";
        printUsage();
        exit(1);
    }
}

void printStats() {
    int total = stats.connected + stats.failed;
    if (total == 0) return;

    std::cout << "\nConnection statistics:\n"
              << "\tAttempted = " << ANSI_BLUE << total << ANSI_RESET
              << ", Connected = " << ANSI_BLUE << stats.connected << ANSI_RESET
              << ", Failed = " << ANSI_RED << stats.failed << ANSI_RESET
              << " (" << ANSI_RED << std::fixed << std::setprecision(2) << (double)stats.failed / total * 100.0 << "%" << ANSI_RESET << ")\n";

    if (stats.connected > 0) {
        double min = 1e9, max = -1.0, sum = 0.0;
        for (double t : stats.times) {
            if (t < min) min = t;
            if (t > max) max = t;
            sum += t;
        }
        double avg = sum / stats.connected;

        std::cout << "Approximate connection times:\n"
                  << "\tMinimum = " << ANSI_BLUE << std::fixed << std::setprecision(2) << min << "ms" << ANSI_RESET
                  << ", Maximum = " << ANSI_BLUE << max << "ms" << ANSI_RESET
                  << ", Average = " << ANSI_BLUE << avg << "ms" << ANSI_RESET << "\n";
    }
}

#ifdef _WIN32
BOOL WINAPI ctrlHandler(DWORD fdwCtrlType) {
    if (fdwCtrlType == CTRL_C_EVENT) {
        printStats();
        exit(0);
    }
    return TRUE;
}
#else
#include <signal.h>
void sigHandler(int s) {
    printStats();
    exit(0);
}
#endif

int main(int argc, char* argv[]) {
#ifdef _WIN32
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);
    SetConsoleCtrlHandler(ctrlHandler, TRUE);
    // Enable ANSI support on Windows 10+
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD dwMode = 0;
    GetConsoleMode(hOut, &dwMode);
    dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    SetConsoleMode(hOut, dwMode);
#else
    signal(SIGINT, sigHandler);
#endif

    if (argc < 2) {
        printUsage();
        return 0;
    }

    parseArgs(argc, argv);

    std::cout << "ConqPing v1.0\n\n"
              << "Connecting to " << ANSI_YELLOW << host << ANSI_RESET 
              << " on TCP " << ANSI_YELLOW << port << ANSI_RESET << ":\n\n";

    int i = 0;
    while (count == -1 || i < count) {
        struct addrinfo hints, *res;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;

        if (forceV4) hints.ai_family = AF_INET;
        if (forceV6) hints.ai_family = AF_INET6;

        std::string portStr = std::to_string(port);
        
        auto start = std::chrono::high_resolution_clock::now();
        SOCKET sock = INVALID_SOCKET;
        bool success = false;
        std::string remoteIp = host;

        if (getaddrinfo(host.c_str(), portStr.c_str(), &hints, &res) == 0) {
            sock = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
            if (IS_VALID_SOCKET(sock)) {
                 // Set Non-blocking
                #ifdef _WIN32
                    u_long mode = 1;
                    ioctlsocket(sock, FIONBIO, &mode);
                #else
                    int flags = fcntl(sock, F_GETFL, 0);
                    fcntl(sock, F_SETFL, flags | O_NONBLOCK);
                #endif

                int result = connect(sock, res->ai_addr, (int)res->ai_addrlen);
                if (result == SOCKET_ERROR) {
                    #ifdef _WIN32
                         if (WSAGetLastError() == WSAEWOULDBLOCK) {
                    #else
                         if (errno == EINPROGRESS) {
                    #endif
                        fd_set set;
                        FD_ZERO(&set);
                        FD_SET(sock, &set);
                        struct timeval tv;
                        tv.tv_sec = timeout / 1000;
                        tv.tv_usec = (timeout % 1000) * 1000;
                        result = select((int)sock + 1, NULL, &set, NULL, &tv);
                        if (result > 0) success = true; 
                    }
                } else {
                    success = true;
                }

                if (success) {
                    char ipStr[INET6_ADDRSTRLEN];
                    if (res->ai_family == AF_INET) {
                        inet_ntop(AF_INET, &(((struct sockaddr_in*)res->ai_addr)->sin_addr), ipStr, sizeof(ipStr));
                    } else {
                        inet_ntop(AF_INET6, &(((struct sockaddr_in6*)res->ai_addr)->sin6_addr), ipStr, sizeof(ipStr));
                    }
                    remoteIp = ipStr;
                }
                
                // start = std::chrono::high_resolution_clock::now(); // REMOVED: This was causing 0.00ms time
            }
            freeaddrinfo(res);
        }

        // Correct timing logic:
        // We actually want strictly the TCP handshake time. 
        // Resolution should essentially be cached or fast, but typically 'ping' tools include it if not cached.
        // Let's stick to simple (Time now - Time start).
        
        // Wait, the above logic was slightly flawed around 'start' time reset.
        // Let's stick to: Start = before resolve/socket. End = after success.
        
        auto end = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double, std::milli> duration = end - start;

        // If we timed out in 'select', the duration will be ~timeout.

        if (success) {
            stats.connected++;
            stats.times.push_back(duration.count());
            std::cout << "Connected to " << ANSI_GREEN << remoteIp << ANSI_RESET 
                      << ": time=" << ANSI_GREEN << std::fixed << std::setprecision(2) << duration.count() << "ms" << ANSI_RESET
                      << " protocol=TCP port=" << ANSI_GREEN << port << ANSI_RESET << "\n";
        } else {
            stats.failed++;
            std::cout << ANSI_RED << "Connection timed out" << ANSI_RESET << "\n";
        }

        if (IS_VALID_SOCKET(sock)) CLOSE_SOCKET(sock);

        i++;
        if (count == -1 || i < count) {
            std::this_thread::sleep_for(std::chrono::milliseconds(interval));
        }
    }

#ifdef _WIN32
    WSACleanup();
#endif
    return 0;
}
