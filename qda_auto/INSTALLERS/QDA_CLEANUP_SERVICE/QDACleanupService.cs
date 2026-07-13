using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

internal static class QDACleanupService
{
    // =====================================================
    // CAU HINH CHUNG
    // =====================================================

    private const string ServiceName = "QDACleanupService";

    private static readonly string BaseDirectory =
        @"C:\ProgramData\QDA\ShutdownCleanup";

    private static readonly string CleanupScript =
        Path.Combine(
            BaseDirectory,
            "cleanup_exam_remote_client.ps1"
        );

    private static readonly string LogDirectory =
        Path.Combine(BaseDirectory, "Logs");

    private static readonly string ServiceLog =
        Path.Combine(LogDirectory, "service.log");

    private static readonly string CleanupLog =
        Path.Combine(LogDirectory, "cleanup_output.log");

    private static readonly string LastResultFile =
        Path.Combine(LogDirectory, "last_result.txt");

    /*
     * Co danh dau:
     * Recycle Bin can duoc don sau khi Windows khoi dong lai.
     */
    private static readonly string RecyclePendingFlag =
        Path.Combine(BaseDirectory, "recycle_pending.flag");

    /*
     * Gioi han toi da Windows cho preshutdown.
     * Neu cleanup xong som thi Windows tiep tuc ngay,
     * khong phai doi du 15 giay.
     */
    private const int PreShutdownTimeoutMilliseconds = 15000;

    /*
     * PS1 don Desktop, Downloads, ThiCNTT.
     */
    private const int SystemCleanupTimeoutMilliseconds = 10000;

    /*
     * Sau khi explorer.exe xuat hien,
     * cho them 10 giay de user session on dinh.
     */
    private const int RecycleDelayAfterExplorerMilliseconds = 10000;

    /*
     * Cho toi da 5 phut de user dang nhap.
     */
    private const int MaximumUserWaitSeconds = 300;

    /*
     * Clear-RecycleBin cho toi da 20 giay.
     */
    private const int UserRecycleTimeoutMilliseconds = 20000;

    // =====================================================
    // WINDOWS SERVICE CONSTANTS
    // =====================================================

    private const int SERVICE_WIN32_OWN_PROCESS = 0x00000010;

    private const int SERVICE_STOPPED = 0x00000001;
    private const int SERVICE_START_PENDING = 0x00000002;
    private const int SERVICE_STOP_PENDING = 0x00000003;
    private const int SERVICE_RUNNING = 0x00000004;

    private const int SERVICE_ACCEPT_STOP = 0x00000001;
    private const int SERVICE_ACCEPT_SHUTDOWN = 0x00000004;
    private const int SERVICE_ACCEPT_PRESHUTDOWN = 0x00000100;

    private const int SERVICE_CONTROL_STOP = 0x00000001;
    private const int SERVICE_CONTROL_INTERROGATE = 0x00000004;
    private const int SERVICE_CONTROL_SHUTDOWN = 0x00000005;
    private const int SERVICE_CONTROL_PRESHUTDOWN = 0x0000000F;

    private const int SC_MANAGER_CONNECT = 0x0001;
    private const int SERVICE_CHANGE_CONFIG = 0x0002;
    private const int SERVICE_CONFIG_PRESHUTDOWN_INFO = 7;

    private const uint MAXIMUM_ALLOWED = 0x02000000;

    private const int SecurityImpersonation = 2;
    private const int TokenPrimary = 1;

    private const uint CREATE_UNICODE_ENVIRONMENT = 0x00000400;
    private const uint CREATE_NO_WINDOW = 0x08000000;

    private const uint WAIT_OBJECT_0 = 0x00000000;
    private const uint WAIT_TIMEOUT = 0x00000102;

    // =====================================================
    // TRANG THAI SERVICE
    // =====================================================

    private static IntPtr serviceStatusHandle = IntPtr.Zero;

    private static readonly ManualResetEvent serviceStoppedEvent =
        new ManualResetEvent(false);

    /*
     * Windows co the gui ca PRESHUTDOWN va SHUTDOWN.
     * Dam bao cleanup chi chay mot lan.
     */
    private static int shutdownWorkerStarted = 0;

    private static int statusCheckpoint = 1;

    /*
     * Giu reference delegate de Garbage Collector
     * khong thu hoi delegate khi service dang chay.
     */
    private static ServiceMainDelegate serviceMainDelegate;
    private static HandlerExDelegate handlerDelegate;

    // =====================================================
    // STRUCT
    // =====================================================

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct SERVICE_TABLE_ENTRY
    {
        [MarshalAs(UnmanagedType.LPWStr)]
        public string serviceName;

        public ServiceMainDelegate serviceMain;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SERVICE_STATUS
    {
        public int serviceType;
        public int currentState;
        public int controlsAccepted;
        public int win32ExitCode;
        public int serviceSpecificExitCode;
        public int checkPoint;
        public int waitHint;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SERVICE_PRESHUTDOWN_INFO
    {
        public uint preShutdownTimeout;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SECURITY_ATTRIBUTES
    {
        public int length;
        public IntPtr securityDescriptor;

        [MarshalAs(UnmanagedType.Bool)]
        public bool inheritHandle;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct STARTUPINFO
    {
        public int cb;
        public string reserved;
        public string desktop;
        public string title;

        public int x;
        public int y;
        public int xSize;
        public int ySize;
        public int xCountChars;
        public int yCountChars;
        public int fillAttribute;
        public int flags;

        public short showWindow;
        public short reserved2;

        public IntPtr reserved2Pointer;
        public IntPtr stdInput;
        public IntPtr stdOutput;
        public IntPtr stdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PROCESS_INFORMATION
    {
        public IntPtr process;
        public IntPtr thread;
        public int processId;
        public int threadId;
    }

    // =====================================================
    // DELEGATE
    // =====================================================

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void ServiceMainDelegate(
        int argumentCount,
        IntPtr argumentPointer
    );

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate int HandlerExDelegate(
        int control,
        int eventType,
        IntPtr eventData,
        IntPtr context
    );

    // =====================================================
    // WINDOWS SERVICE API
    // =====================================================

    [DllImport(
        "advapi32.dll",
        SetLastError = true,
        CharSet = CharSet.Unicode
    )]
    private static extern bool StartServiceCtrlDispatcher(
        SERVICE_TABLE_ENTRY[] serviceTable
    );

    [DllImport(
        "advapi32.dll",
        SetLastError = true,
        CharSet = CharSet.Unicode
    )]
    private static extern IntPtr RegisterServiceCtrlHandlerEx(
        string serviceName,
        HandlerExDelegate handler,
        IntPtr context
    );

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool SetServiceStatus(
        IntPtr statusHandle,
        ref SERVICE_STATUS serviceStatus
    );

    [DllImport(
        "advapi32.dll",
        SetLastError = true,
        CharSet = CharSet.Unicode
    )]
    private static extern IntPtr OpenSCManager(
        string machineName,
        string databaseName,
        int desiredAccess
    );

    [DllImport(
        "advapi32.dll",
        SetLastError = true,
        CharSet = CharSet.Unicode
    )]
    private static extern IntPtr OpenService(
        IntPtr serviceControlManager,
        string serviceName,
        int desiredAccess
    );

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool ChangeServiceConfig2(
        IntPtr serviceHandle,
        int infoLevel,
        ref SERVICE_PRESHUTDOWN_INFO info
    );

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool CloseServiceHandle(
        IntPtr serviceHandle
    );

    // =====================================================
    // USER SESSION API
    // =====================================================

    [DllImport("kernel32.dll")]
    private static extern uint WTSGetActiveConsoleSessionId();

    [DllImport("wtsapi32.dll", SetLastError = true)]
    private static extern bool WTSQueryUserToken(
        uint sessionId,
        out IntPtr token
    );

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool DuplicateTokenEx(
        IntPtr existingToken,
        uint desiredAccess,
        ref SECURITY_ATTRIBUTES tokenAttributes,
        int impersonationLevel,
        int tokenType,
        out IntPtr newToken
    );

    [DllImport("userenv.dll", SetLastError = true)]
    private static extern bool CreateEnvironmentBlock(
        out IntPtr environment,
        IntPtr token,
        bool inherit
    );

    [DllImport("userenv.dll", SetLastError = true)]
    private static extern bool DestroyEnvironmentBlock(
        IntPtr environment
    );

    [DllImport(
        "advapi32.dll",
        SetLastError = true,
        CharSet = CharSet.Unicode
    )]
    private static extern bool CreateProcessAsUser(
        IntPtr token,
        string applicationName,
        StringBuilder commandLine,
        ref SECURITY_ATTRIBUTES processAttributes,
        ref SECURITY_ATTRIBUTES threadAttributes,
        bool inheritHandles,
        uint creationFlags,
        IntPtr environment,
        string currentDirectory,
        ref STARTUPINFO startupInfo,
        out PROCESS_INFORMATION processInformation
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(
        IntPtr handle,
        uint milliseconds
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetExitCodeProcess(
        IntPtr process,
        out uint exitCode
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateProcess(
        IntPtr process,
        uint exitCode
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(
        IntPtr handle
    );

    // =====================================================
    // MAIN
    // =====================================================

    public static void Main()
    {
        EnsureDirectories();

        serviceMainDelegate = ServiceMain;

        SERVICE_TABLE_ENTRY[] serviceTable =
        {
            new SERVICE_TABLE_ENTRY
            {
                serviceName = ServiceName,
                serviceMain = serviceMainDelegate
            },

            new SERVICE_TABLE_ENTRY
            {
                serviceName = null,
                serviceMain = null
            }
        };

        bool started =
            StartServiceCtrlDispatcher(serviceTable);

        if (!started)
        {
            WriteLog(
                "[FAIL] StartServiceCtrlDispatcher error=" +
                Marshal.GetLastWin32Error()
            );
        }
    }

    // =====================================================
    // SERVICE MAIN
    // =====================================================

    private static void ServiceMain(
        int argumentCount,
        IntPtr argumentPointer
    )
    {
        handlerDelegate = ServiceControlHandler;

        serviceStatusHandle =
            RegisterServiceCtrlHandlerEx(
                ServiceName,
                handlerDelegate,
                IntPtr.Zero
            );

        if (serviceStatusHandle == IntPtr.Zero)
        {
            WriteLog(
                "[FAIL] RegisterServiceCtrlHandlerEx error=" +
                Marshal.GetLastWin32Error()
            );

            return;
        }

        ReportStatus(
            SERVICE_START_PENDING,
            0,
            3000
        );

        ConfigurePreShutdownTimeout();

        WriteLog("");
        WriteLog("==========================================");
        WriteLog("QDA CLEANUP SERVICE STARTED");
        WriteLog("Computer : " + Environment.MachineName);

        WriteLog(
            "RunAs    : " +
            Environment.UserDomainName +
            "\\" +
            Environment.UserName
        );

        WriteLog("Script   : " + CleanupScript);

        WriteLog(
            "Recycle pending: " +
            File.Exists(RecyclePendingFlag)
        );

        WriteLog(
            "Preshutdown timeout: " +
            PreShutdownTimeoutMilliseconds +
            " ms"
        );

        WriteLog("==========================================");

        ReportStatus(
            SERVICE_RUNNING,
            SERVICE_ACCEPT_STOP |
            SERVICE_ACCEPT_SHUTDOWN |
            SERVICE_ACCEPT_PRESHUTDOWN,
            0
        );

        /*
         * Thread khoi dong chi xu ly Recycle Bin
         * neu co recycle_pending.flag.
         */
        Thread startupRecycleThread =
            new Thread(StartupRecycleBinWorker);

        startupRecycleThread.IsBackground = true;
        startupRecycleThread.Start();

        serviceStoppedEvent.WaitOne();
    }

    // =====================================================
    // NHAN LENH TU WINDOWS
    // =====================================================

    private static int ServiceControlHandler(
        int control,
        int eventType,
        IntPtr eventData,
        IntPtr context
    )
    {
        switch (control)
        {
            case SERVICE_CONTROL_PRESHUTDOWN:
                WriteLog(
                    "SERVICE_CONTROL_PRESHUTDOWN received."
                );

                StartShutdownCleanupWorker(
                    "PRESHUTDOWN"
                );

                return 0;

            case SERVICE_CONTROL_SHUTDOWN:
                WriteLog(
                    "SERVICE_CONTROL_SHUTDOWN received."
                );

                StartShutdownCleanupWorker(
                    "SHUTDOWN"
                );

                return 0;

            case SERVICE_CONTROL_STOP:
                WriteLog(
                    "SERVICE_CONTROL_STOP received. " +
                    "Cleanup skipped."
                );

                ReportStatus(
                    SERVICE_STOPPED,
                    0,
                    0
                );

                serviceStoppedEvent.Set();

                return 0;

            case SERVICE_CONTROL_INTERROGATE:
                return 0;

            default:
                return 0;
        }
    }

    // =====================================================
    // BAT DAU CLEANUP TRUOC KHI TAT MAY
    // =====================================================

    private static void StartShutdownCleanupWorker(
        string source
    )
    {
        if (
            Interlocked.Exchange(
                ref shutdownWorkerStarted,
                1
            ) != 0
        )
        {
            WriteLog(
                "[SKIP] Shutdown cleanup already started."
            );

            return;
        }

        ReportStatus(
            SERVICE_STOP_PENDING,
            0,
            PreShutdownTimeoutMilliseconds
        );

        Thread worker =
            new Thread(
                delegate()
                {
                    ShutdownCleanupWorker(source);
                }
            );

        worker.IsBackground = false;
        worker.Start();
    }

    private static void ShutdownCleanupWorker(
        string source
    )
    {
        Stopwatch timer = Stopwatch.StartNew();

        WriteLog("");
        WriteLog("==========================================");

        WriteLog(
            "START SHUTDOWN CLEANUP - SOURCE=" +
            source
        );

        WriteLog("==========================================");

        /*
         * Don Desktop, Downloads va ThiCNTT
         * bang SYSTEM.
         */
        bool systemCleanupOk =
            RunSystemCleanupPowerShell();

        /*
         * Tao co de lan boot tiep theo
         * service empty Recycle Bin.
         */
        bool recycleFlagOk =
            CreateRecyclePendingFlag();

        timer.Stop();

        string result =
            "SystemCleanup=" +
            systemCleanupOk +
            "; RecyclePendingFlag=" +
            recycleFlagOk +
            "; ElapsedMs=" +
            timer.ElapsedMilliseconds;

        WriteLog("[RESULT] " + result);

        WriteLastResult(
            DateTime.Now.ToString(
                "yyyy-MM-dd HH:mm:ss"
            ) +
            " | " +
            result
        );

        ReportStatus(
            SERVICE_STOPPED,
            0,
            0
        );

        serviceStoppedEvent.Set();
    }

    // =====================================================
    // TAO CO RECYCLE PENDING
    // =====================================================

    private static bool CreateRecyclePendingFlag()
    {
        try
        {
            File.WriteAllText(
                RecyclePendingFlag,
                "Requested at " +
                DateTime.Now.ToString(
                    "yyyy-MM-dd HH:mm:ss"
                ),
                Encoding.UTF8
            );

            WriteLog(
                "[OK] Recycle pending flag created: " +
                RecyclePendingFlag
            );

            return true;
        }
        catch (Exception exception)
        {
            WriteLog(
                "[FAIL] Cannot create recycle pending flag: " +
                exception.Message
            );

            return false;
        }
    }

    // =====================================================
    // WORKER DON RECYCLE BIN SAU KHI BOOT
    // =====================================================

    private static void StartupRecycleBinWorker()
    {
        try
        {
            if (!File.Exists(RecyclePendingFlag))
            {
                WriteLog(
                    "[STARTUP] No recycle pending flag. Skip."
                );

                return;
            }

            WriteLog(
                "[STARTUP] Recycle pending flag found."
            );

            int waitedSeconds = 0;
            uint activeSessionId = 0xFFFFFFFF;
            bool userSessionReady = false;

            /*
             * Cho user dang nhap va explorer.exe chay.
             */
            while (waitedSeconds < MaximumUserWaitSeconds)
            {
                activeSessionId =
                    WTSGetActiveConsoleSessionId();

                bool sessionFound =
                    activeSessionId != 0xFFFFFFFF;

                bool explorerFound = false;

                if (sessionFound)
                {
                    try
                    {
                        Process[] explorerProcesses =
                            Process.GetProcessesByName(
                                "explorer"
                            );

                        foreach (
                            Process explorer
                            in explorerProcesses
                        )
                        {
                            try
                            {
                                if (
                                    explorer.SessionId ==
                                    (int)activeSessionId
                                )
                                {
                                    explorerFound = true;
                                    break;
                                }
                            }
                            catch
                            {
                            }
                            finally
                            {
                                explorer.Dispose();
                            }
                        }
                    }
                    catch
                    {
                    }
                }

                if (sessionFound && explorerFound)
                {
                    userSessionReady = true;

                    WriteLog(
                        "[STARTUP] User session ready. " +
                        "SessionId=" +
                        activeSessionId
                    );

                    break;
                }

                Thread.Sleep(2000);
                waitedSeconds += 2;
            }

            if (!userSessionReady)
            {
                WriteLog(
                    "[STARTUP] User session not ready after " +
                    MaximumUserWaitSeconds +
                    " seconds. Pending flag kept."
                );

                return;
            }

            WriteLog(
                "[STARTUP] Waiting 10 seconds before " +
                "Recycle Bin cleanup."
            );

            Thread.Sleep(
                RecycleDelayAfterExplorerMilliseconds
            );

            bool recycleSuccess =
                RunRecycleBinAsLoggedOnUser(
                    activeSessionId
                );

            if (!recycleSuccess)
            {
                WriteLog(
                    "[STARTUP] Recycle Bin cleanup failed. " +
                    "Pending flag kept for next service start."
                );

                return;
            }

            try
            {
                File.Delete(RecyclePendingFlag);

                WriteLog(
                    "[STARTUP] Recycle Bin cleanup success. " +
                    "Pending flag removed."
                );
            }
            catch (Exception deleteException)
            {
                WriteLog(
                    "[WARN] Recycle cleanup succeeded but " +
                    "cannot delete pending flag: " +
                    deleteException.Message
                );
            }
        }
        catch (Exception exception)
        {
            WriteLog(
                "[FAIL] StartupRecycleBinWorker exception: " +
                exception
            );
        }
    }

    // =====================================================
    // DON DESKTOP / DOWNLOADS / THICNTT
    // =====================================================

    private static bool RunSystemCleanupPowerShell()
    {
        if (!File.Exists(CleanupScript))
        {
            WriteLog(
                "[FAIL] Missing cleanup script: " +
                CleanupScript
            );

            return false;
        }

        try
        {
            File.WriteAllText(
                CleanupLog,
                "===== QDA CLEANUP OUTPUT =====" +
                Environment.NewLine +
                "START " +
                DateTime.Now.ToString(
                    "yyyy-MM-dd HH:mm:ss"
                ) +
                Environment.NewLine,
                Encoding.UTF8
            );

            ProcessStartInfo info =
                new ProcessStartInfo();

            info.FileName =
                @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe";

            info.Arguments =
                "-NoProfile " +
                "-NonInteractive " +
                "-ExecutionPolicy Bypass " +
                "-File \"" +
                CleanupScript +
                "\"";

            info.WorkingDirectory =
                BaseDirectory;

            info.CreateNoWindow = true;
            info.UseShellExecute = false;

            info.RedirectStandardOutput = true;
            info.RedirectStandardError = true;

            using (Process process = new Process())
            {
                process.StartInfo = info;

                StringBuilder output =
                    new StringBuilder();

                StringBuilder error =
                    new StringBuilder();

                process.OutputDataReceived +=
                    delegate(
                        object sender,
                        DataReceivedEventArgs e
                    )
                    {
                        if (e.Data != null)
                        {
                            output.AppendLine(e.Data);
                        }
                    };

                process.ErrorDataReceived +=
                    delegate(
                        object sender,
                        DataReceivedEventArgs e
                    )
                    {
                        if (e.Data != null)
                        {
                            error.AppendLine(e.Data);
                        }
                    };

                WriteLog(
                    "[RUN SYSTEM] " +
                    info.FileName +
                    " " +
                    info.Arguments
                );

                if (!process.Start())
                {
                    WriteLog(
                        "[FAIL] Cannot start PowerShell."
                    );

                    return false;
                }

                process.BeginOutputReadLine();
                process.BeginErrorReadLine();

                bool finished =
                    process.WaitForExit(
                        SystemCleanupTimeoutMilliseconds
                    );

                if (!finished)
                {
                    WriteLog(
                        "[TIMEOUT] System cleanup exceeded " +
                        SystemCleanupTimeoutMilliseconds +
                        " ms"
                    );

                    try
                    {
                        process.Kill();
                    }
                    catch
                    {
                    }

                    AppendCleanupLog(
                        output.ToString(),
                        error.ToString(),
                        -1
                    );

                    return false;
                }

                process.WaitForExit();

                int exitCode =
                    process.ExitCode;

                AppendCleanupLog(
                    output.ToString(),
                    error.ToString(),
                    exitCode
                );

                WriteLog(
                    "[SYSTEM CLEANUP EXIT] " +
                    exitCode
                );

                return exitCode == 0;
            }
        }
        catch (Exception exception)
        {
            WriteLog(
                "[FAIL] System cleanup exception: " +
                exception
            );

            return false;
        }
    }

    // =====================================================
    // EMPTY RECYCLE BIN BANG USER DANG LOGIN
    // =====================================================

    private static bool RunRecycleBinAsLoggedOnUser(
        uint sessionId
    )
    {
        IntPtr userToken = IntPtr.Zero;
        IntPtr primaryToken = IntPtr.Zero;
        IntPtr environment = IntPtr.Zero;

        PROCESS_INFORMATION processInformation =
            new PROCESS_INFORMATION();

        try
        {
            WriteLog(
                "[RECYCLE] Active session: " +
                sessionId
            );

            if (
                !WTSQueryUserToken(
                    sessionId,
                    out userToken
                )
            )
            {
                WriteLog(
                    "[FAIL] WTSQueryUserToken error=" +
                    Marshal.GetLastWin32Error()
                );

                return false;
            }

            SECURITY_ATTRIBUTES tokenAttributes =
                new SECURITY_ATTRIBUTES();

            tokenAttributes.length =
                Marshal.SizeOf(
                    typeof(SECURITY_ATTRIBUTES)
                );

            if (
                !DuplicateTokenEx(
                    userToken,
                    MAXIMUM_ALLOWED,
                    ref tokenAttributes,
                    SecurityImpersonation,
                    TokenPrimary,
                    out primaryToken
                )
            )
            {
                WriteLog(
                    "[FAIL] DuplicateTokenEx error=" +
                    Marshal.GetLastWin32Error()
                );

                return false;
            }

            bool environmentCreated =
                CreateEnvironmentBlock(
                    out environment,
                    primaryToken,
                    false
                );

            if (!environmentCreated)
            {
                WriteLog(
                    "[WARN] CreateEnvironmentBlock error=" +
                    Marshal.GetLastWin32Error()
                );

                environment = IntPtr.Zero;
            }

            string powershellPath =
                @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe";

            string command =
                "\"" +
                powershellPath +
                "\" " +
                "-NoProfile " +
                "-NonInteractive " +
                "-ExecutionPolicy Bypass " +
                "-Command " +
                "\"Clear-RecycleBin " +
                "-Force " +
                "-ErrorAction Stop\"";

            StringBuilder commandLine =
                new StringBuilder(command);

            SECURITY_ATTRIBUTES processAttributes =
                new SECURITY_ATTRIBUTES();

            processAttributes.length =
                Marshal.SizeOf(
                    typeof(SECURITY_ATTRIBUTES)
                );

            SECURITY_ATTRIBUTES threadAttributes =
                new SECURITY_ATTRIBUTES();

            threadAttributes.length =
                Marshal.SizeOf(
                    typeof(SECURITY_ATTRIBUTES)
                );

            STARTUPINFO startupInfo =
                new STARTUPINFO();

            startupInfo.cb =
                Marshal.SizeOf(
                    typeof(STARTUPINFO)
                );

            startupInfo.desktop =
                @"winsta0\default";

            uint creationFlags =
                CREATE_NO_WINDOW;

            if (environment != IntPtr.Zero)
            {
                creationFlags |=
                    CREATE_UNICODE_ENVIRONMENT;
            }

            WriteLog(
                "[RUN USER] " + command
            );

            bool created =
                CreateProcessAsUser(
                    primaryToken,
                    powershellPath,
                    commandLine,
                    ref processAttributes,
                    ref threadAttributes,
                    false,
                    creationFlags,
                    environment,
                    null,
                    ref startupInfo,
                    out processInformation
                );

            if (!created)
            {
                WriteLog(
                    "[FAIL] CreateProcessAsUser error=" +
                    Marshal.GetLastWin32Error()
                );

                return false;
            }

            uint waitResult =
                WaitForSingleObject(
                    processInformation.process,
                    UserRecycleTimeoutMilliseconds
                );

            if (waitResult == WAIT_TIMEOUT)
            {
                WriteLog(
                    "[WARN] User Clear-RecycleBin timeout."
                );

                TerminateProcess(
                    processInformation.process,
                    1
                );

                return false;
            }

            if (waitResult != WAIT_OBJECT_0)
            {
                WriteLog(
                    "[WARN] WaitForSingleObject result=" +
                    waitResult
                );

                return false;
            }

            uint exitCode;

            if (
                !GetExitCodeProcess(
                    processInformation.process,
                    out exitCode
                )
            )
            {
                WriteLog(
                    "[FAIL] GetExitCodeProcess error=" +
                    Marshal.GetLastWin32Error()
                );

                return false;
            }

            WriteLog(
                "[USER RECYCLE EXIT] " +
                exitCode
            );

            if (exitCode == 0)
            {
                WriteLog(
                    "[OK] User Clear-RecycleBin completed."
                );

                return true;
            }

            WriteLog(
                "[FAIL] User Clear-RecycleBin exit code=" +
                exitCode
            );

            return false;
        }
        catch (Exception exception)
        {
            WriteLog(
                "[FAIL] User recycle exception: " +
                exception
            );

            return false;
        }
        finally
        {
            if (
                processInformation.thread !=
                IntPtr.Zero
            )
            {
                CloseHandle(
                    processInformation.thread
                );
            }

            if (
                processInformation.process !=
                IntPtr.Zero
            )
            {
                CloseHandle(
                    processInformation.process
                );
            }

            if (environment != IntPtr.Zero)
            {
                DestroyEnvironmentBlock(
                    environment
                );
            }

            if (primaryToken != IntPtr.Zero)
            {
                CloseHandle(primaryToken);
            }

            if (userToken != IntPtr.Zero)
            {
                CloseHandle(userToken);
            }
        }
    }

    // =====================================================
    // DAT PRESHUTDOWN TIMEOUT
    // =====================================================

    private static void ConfigurePreShutdownTimeout()
    {
        IntPtr serviceControlManager =
            IntPtr.Zero;

        IntPtr serviceHandle =
            IntPtr.Zero;

        try
        {
            serviceControlManager =
                OpenSCManager(
                    null,
                    null,
                    SC_MANAGER_CONNECT
                );

            if (
                serviceControlManager ==
                IntPtr.Zero
            )
            {
                WriteLog(
                    "[WARN] OpenSCManager error=" +
                    Marshal.GetLastWin32Error()
                );

                return;
            }

            serviceHandle =
                OpenService(
                    serviceControlManager,
                    ServiceName,
                    SERVICE_CHANGE_CONFIG
                );

            if (serviceHandle == IntPtr.Zero)
            {
                WriteLog(
                    "[WARN] OpenService error=" +
                    Marshal.GetLastWin32Error()
                );

                return;
            }

            SERVICE_PRESHUTDOWN_INFO info =
                new SERVICE_PRESHUTDOWN_INFO();

            info.preShutdownTimeout =
                PreShutdownTimeoutMilliseconds;

            bool changed =
                ChangeServiceConfig2(
                    serviceHandle,
                    SERVICE_CONFIG_PRESHUTDOWN_INFO,
                    ref info
                );

            if (changed)
            {
                WriteLog(
                    "[OK] Preshutdown timeout set to " +
                    PreShutdownTimeoutMilliseconds +
                    " ms"
                );
            }
            else
            {
                WriteLog(
                    "[WARN] ChangeServiceConfig2 error=" +
                    Marshal.GetLastWin32Error()
                );
            }
        }
        catch (Exception exception)
        {
            WriteLog(
                "[WARN] Configure timeout exception: " +
                exception.Message
            );
        }
        finally
        {
            if (serviceHandle != IntPtr.Zero)
            {
                CloseServiceHandle(
                    serviceHandle
                );
            }

            if (
                serviceControlManager !=
                IntPtr.Zero
            )
            {
                CloseServiceHandle(
                    serviceControlManager
                );
            }
        }
    }

    // =====================================================
    // BAO TRANG THAI SERVICE
    // =====================================================

    private static void ReportStatus(
        int currentState,
        int controlsAccepted,
        int waitHint
    )
    {
        if (
            serviceStatusHandle ==
            IntPtr.Zero
        )
        {
            return;
        }

        SERVICE_STATUS status =
            new SERVICE_STATUS();

        status.serviceType =
            SERVICE_WIN32_OWN_PROCESS;

        status.currentState =
            currentState;

        status.controlsAccepted =
            controlsAccepted;

        status.win32ExitCode = 0;
        status.serviceSpecificExitCode = 0;
        status.waitHint = waitHint;

        if (
            currentState ==
            SERVICE_START_PENDING ||
            currentState ==
            SERVICE_STOP_PENDING
        )
        {
            status.checkPoint =
                Interlocked.Increment(
                    ref statusCheckpoint
                );
        }
        else
        {
            status.checkPoint = 0;
        }

        bool result =
            SetServiceStatus(
                serviceStatusHandle,
                ref status
            );

        if (!result)
        {
            WriteLog(
                "[WARN] SetServiceStatus error=" +
                Marshal.GetLastWin32Error()
            );
        }
    }

    // =====================================================
    // LOG
    // =====================================================

    private static void EnsureDirectories()
    {
        try
        {
            Directory.CreateDirectory(
                BaseDirectory
            );

            Directory.CreateDirectory(
                LogDirectory
            );
        }
        catch
        {
        }
    }

    private static void WriteLog(
        string text
    )
    {
        try
        {
            EnsureDirectories();

            File.AppendAllText(
                ServiceLog,
                DateTime.Now.ToString(
                    "yyyy-MM-dd HH:mm:ss.fff"
                ) +
                " " +
                text +
                Environment.NewLine,
                Encoding.UTF8
            );
        }
        catch
        {
        }
    }

    private static void WriteLastResult(
        string text
    )
    {
        try
        {
            EnsureDirectories();

            File.WriteAllText(
                LastResultFile,
                text,
                Encoding.UTF8
            );
        }
        catch
        {
        }
    }

    private static void AppendCleanupLog(
        string output,
        string error,
        int exitCode
    )
    {
        try
        {
            File.AppendAllText(
                CleanupLog,
                Environment.NewLine +
                "===== STANDARD OUTPUT =====" +
                Environment.NewLine +
                output +
                Environment.NewLine +
                "===== STANDARD ERROR =====" +
                Environment.NewLine +
                error +
                Environment.NewLine +
                "EXIT CODE: " +
                exitCode +
                Environment.NewLine +
                "END " +
                DateTime.Now.ToString(
                    "yyyy-MM-dd HH:mm:ss"
                ) +
                Environment.NewLine,
                Encoding.UTF8
            );
        }
        catch
        {
        }
    }
}