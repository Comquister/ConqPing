import java.io.IOException;
import java.net.Inet4Address;
import java.net.Inet6Address;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class ConqPing {

    private static String host;
    private static int port = 80;
    private static int count = -1; // Infinite by default
    private static int timeout = 1000; // ms
    private static int interval = 1000; // ms

    private static boolean forceV4 = false;
    private static boolean forceV6 = false;

    // Stats variables
    private static List<Double> times = new ArrayList<Double>();
    private static int connected = 0;
    private static int failed = 0;

    // ANSI Colors
    public static final String ANSI_RESET = "\u001B[0m";
    // Using Bright/High Intensity colors to match typical Windows console
    // appearance
    public static final String ANSI_RED = "\u001B[91m";
    public static final String ANSI_GREEN = "\u001B[92m";
    public static final String ANSI_YELLOW = "\u001B[93m";
    public static final String ANSI_BLUE = "\u001B[94m";
    public static final String ANSI_CYAN = "\u001B[96m";

    public static void main(String[] args) {
        if (args.length == 0) {
            printUsage();
            return;
        }

        parseArgs(args);

        // Conflict check
        if (forceV4 && forceV6) {
            System.err.println("Error: Cannot specify both -4 and -6.");
            System.exit(1);
        }

        System.out.println("ConqPing v1.0");
        System.out.println("\nConnecting to " + ANSI_YELLOW + host + ANSI_RESET + " on TCP " + ANSI_YELLOW + port
                + ANSI_RESET + ":\n");

        // Hook for Ctrl+C to print stats
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
            public void run() {
                printStats();
            }
        }));

        int i = 0;
        while (count == -1 || i < count) {
            long startTime = System.nanoTime();
            boolean success = false;
            String remoteIp = host;
            try (Socket socket = new Socket()) {
                InetSocketAddress socketAddress = resolveAddress(host, port);
                socket.connect(socketAddress, timeout);
                remoteIp = socket.getInetAddress().getHostAddress();
                success = true;
            } catch (IOException e) {
                success = false;
            }
            long endTime = System.nanoTime();
            double durationMs = (endTime - startTime) / 1_000_000.0;

            if (success) {
                connected++;
                times.add(durationMs);

                System.out.printf(Locale.US, "Connected to %s%s%s: time=%s%.2fms%s protocol=TCP port=%s%d%s%n",
                        ANSI_GREEN, remoteIp, ANSI_RESET,
                        ANSI_GREEN, durationMs, ANSI_RESET,
                        ANSI_GREEN, port, ANSI_RESET);
            } else {
                failed++;
                System.out.println(ANSI_RED + "Connection timed out" + ANSI_RESET);
            }

            i++;
            if (count == -1 || i < count) {
                try {
                    Thread.sleep(interval);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }
    }

    private static InetSocketAddress resolveAddress(String host, int port) throws IOException {
        if (!forceV4 && !forceV6) {
            return new InetSocketAddress(host, port);
        }

        InetAddress[] addrs = InetAddress.getAllByName(host);
        for (InetAddress addr : addrs) {
            if (forceV4 && addr instanceof Inet4Address) {
                return new InetSocketAddress(addr, port);
            }
            if (forceV6 && addr instanceof Inet6Address) {
                return new InetSocketAddress(addr, port);
            }
        }
        throw new UnknownHostException("No address found for " + host + " with requested protocol.");
    }

    private static void parseArgs(String[] args) {
        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            if (arg.startsWith("-")) {
                switch (arg) {
                    case "-p":
                    case "--port":
                        if (i + 1 < args.length)
                            port = Integer.parseInt(args[++i]);
                        break;
                    case "-c":
                    case "--count":
                        if (i + 1 < args.length)
                            count = Integer.parseInt(args[++i]);
                        break;
                    case "-t":
                    case "--timeout":
                        if (i + 1 < args.length)
                            timeout = Integer.parseInt(args[++i]);
                        break;
                    case "--interval":
                        if (i + 1 < args.length)
                            interval = Integer.parseInt(args[++i]);
                        break;
                    case "-4":
                        forceV4 = true;
                        break;
                    case "-6":
                        forceV6 = true;
                        break;
                    case "-h":
                    case "--help":
                    case "?":
                        printUsage();
                        System.exit(0);
                        break;
                    default:
                        System.err.println("Unknown argument: " + arg);
                        printUsage();
                        System.exit(1);
                }
            } else {
                host = arg;
            }
        }

        if (host == null) {
            System.err.println("Host is required.");
            printUsage();
            System.exit(1);
        }
    }

    private static void printStats() {
        int total = connected + failed;
        if (total == 0)
            return;

        System.out.println("\nConnection statistics:");
        System.out.printf(Locale.US, "\tAttempted = %s%d%s, Connected = %s%d%s, Failed = %s%d%s (%s%.2f%%%s)%n",
                ANSI_BLUE, total, ANSI_RESET,
                ANSI_BLUE, connected, ANSI_RESET,
                ANSI_RED, failed, ANSI_RESET,
                ANSI_RED, (failed / (double) total) * 100, ANSI_RESET);

        if (connected > 0) {
            double min = Double.MAX_VALUE;
            double max = Double.MIN_VALUE;
            double sum = 0;

            for (Double t : times) {
                if (t < min)
                    min = t;
                if (t > max)
                    max = t;
                sum += t;
            }
            double avg = sum / (double) connected;

            System.out.println("Approximate connection times:");
            System.out.printf(Locale.US, "\tMinimum = %s%.2fms%s, Maximum = %s%.2fms%s, Average = %s%.2fms%s%n",
                    ANSI_BLUE, min, ANSI_RESET,
                    ANSI_BLUE, max, ANSI_RESET,
                    ANSI_BLUE, avg, ANSI_RESET);
        }
    }

    private static void printUsage() {
        System.out.println("Usage: java ConqPing [host] [options]");
        System.out.println("Options:");
        System.out.println("  -p, --port <port>       Port to connect to (default: 80)");
        System.out.println("  -c, --count <count>     Number of regular pings to send (default: infinite)");
        System.out.println("  -t, --timeout <ms>      Connection timeout in milliseconds (default: 1000)");
        System.out.println("  --interval <ms>         Interval between pings in milliseconds (default: 1000)");
        System.out.println("  -4                      Force IPv4 resolution");
        System.out.println("  -6                      Force IPv6 resolution");
        System.out.println("  -h, --help              Show this help message");
    }
}
