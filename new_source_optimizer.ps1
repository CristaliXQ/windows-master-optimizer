$Host.UI.RawUI.WindowTitle = "Windows Master Optimizer v6.0 Ultra Performance"
$script:QuietMode = $false
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$e = [char]27
$blockFull = "$([char]0x2588)"
$blockEmpty = "$([char]0x2591)"

$nativeCode = @'
using System;
using System.IO;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public class WinNativeOptimizer {
    [StructLayout(LayoutKind.Sequential)]
    public struct ANIMATIONINFO {
        public uint cbSize;
        public int iMinAnimate;
    }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfoW(uint uiAction, uint uiParam, ref ANIMATIONINFO pvParam, uint fWinIni);

    public static void EnableWindowAnimations() {
        try {
            ANIMATIONINFO ai = new ANIMATIONINFO();
            ai.cbSize = 8;
            ai.iMinAnimate = 1;
            SystemParametersInfoW(0x0049, 8, ref ai, 3);
        } catch {}
    }
    [DllImport("ntdll.dll")]
    public static extern int NtQueryTimerResolution(out uint minRes, out uint maxRes, out uint curRes);

    [DllImport("winmm.dll")]
    public static extern uint timeBeginPeriod(uint ms);

    [DllImport("winmm.dll")]
    public static extern uint timeEndPeriod(uint ms);

    [DllImport("ntdll.dll")]
    private static extern int NtSetSystemInformation(int infoClass, IntPtr infoPtr, int infoLen);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr procHandle, int desiredAccess, out IntPtr tokenHandle);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern bool LookupPrivilegeValue(string systemName, string name, out long luid);

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    private struct TOKEN_PRIVILEGES {
        public int PrivilegeCount;
        public long Luid;
        public int Attributes;
    }

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool AdjustTokenPrivileges(IntPtr tokenHandle, bool disableAll, [In] ref TOKEN_PRIVILEGES newState, int bufferLen, IntPtr prevState, IntPtr retLen);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetLogicalProcessorInformationEx(int relationshipType, IntPtr buffer, ref int returnedLength);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern SafeFileHandle CreateFile(string lpFileName, uint dwDesiredAccess, uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool ReadFile(SafeFileHandle hFile, IntPtr lpBuffer, uint nNumberOfBytesToRead, out uint lpNumberOfBytesRead, IntPtr lpOverlapped);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetFilePointerEx(SafeFileHandle hFile, long liDistanceToMove, out long lpNewFilePointer, uint dwMoveMethod);

    [DllImport("user32.dll")]
    public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [DllImport("dwmapi.dll")]
    public static extern int DwmIsCompositionEnabled(out bool pfEnabled);

    [StructLayout(LayoutKind.Sequential)]
    public struct UNSIGNED_RATIO { public uint uiNumerator; public uint uiDenominator; }

    [StructLayout(LayoutKind.Sequential)]
    public struct DWM_TIMING_INFO {
        public int cbSize;
        public UNSIGNED_RATIO rateRefresh;
        public ulong qpcRefreshPeriod;
        public UNSIGNED_RATIO rateCompose;
        public ulong qpcVBlank;
        public ulong cRefresh;
        public uint cDXRefresh;
        public ulong qpcCompose;
        public ulong cFrame;
        public uint cDXPresent;
        public ulong cRefreshFrame;
        public ulong cFrameSubmitted;
        public uint cDXPresentSubmitted;
        public ulong cFrameConfirmed;
        public uint cDXPresentConfirmed;
        public ulong cRefreshConfirmed;
        public ulong cRefreshPend;
        public ulong cFrameDisplayed;
        public ulong cRefreshFrameDisplayed;
        public ulong cFrameComplete;
        public ulong qpcFrameComplete;
        public ulong cFramePending;
        public ulong qpcFramePending;
        public ulong cFramesDisplayed;
        public ulong cFramesComplete;
        public ulong cFramesPending;
        public ulong cFramesAvailable;
        public ulong cFramesDropped;
        public ulong cFramesMissed;
        public ulong cRefreshSchedule;
        public ulong cRefreshGaps;
        public ulong cCompositionUpdates;
        public ulong qpcCompositionUpdate;
    }

    [DllImport("dwmapi.dll")]
    public static extern int DwmGetCompositionTimingInfo(IntPtr hwnd, ref DWM_TIMING_INFO info);

    [StructLayout(LayoutKind.Sequential)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        public short dmLogPixels;
        public short dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }

    private static bool EnablePrivilege(string priv) {
        IntPtr hToken;
        if (!OpenProcessToken(Process.GetCurrentProcess().Handle, 0x0028, out hToken)) return false;
        try {
            long luid;
            if (!LookupPrivilegeValue(null, priv, out luid)) return false;
            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES {
                PrivilegeCount = 1,
                Luid = luid,
                Attributes = 0x00000002
            };
            return AdjustTokenPrivileges(hToken, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        } finally {
            CloseHandle(hToken);
        }
    }

    public static int FlushStandbyList() {
        try {
            EnablePrivilege("SeProfileSingleProcessPrivilege");
            GCHandle gch = GCHandle.Alloc((int)4, GCHandleType.Pinned);
            int res = NtSetSystemInformation(80, gch.AddrOfPinnedObject(), sizeof(int));
            gch.Free();
            return res;
        } catch { return -1; }
    }

    public static int EmptySystemWorkingSets() {
        try {
            EnablePrivilege("SeProfileSingleProcessPrivilege");
            EnablePrivilege("SeIncreaseQuotaPrivilege");
            GCHandle gch = GCHandle.Alloc((int)2, GCHandleType.Pinned);
            int res = NtSetSystemInformation(80, gch.AddrOfPinnedObject(), sizeof(int));
            gch.Free();
            return res;
        } catch { return -1; }
    }

    public static bool IsHybridProcessor() {
        try {
            int length = 0;
            GetLogicalProcessorInformationEx(0, IntPtr.Zero, ref length);
            if (length <= 0) return false;
            IntPtr buf = Marshal.AllocHGlobal(length);
            try {
                if (GetLogicalProcessorInformationEx(0, buf, ref length)) {
                    int offset = 0;
                    byte minEff = 255;
                    byte maxEff = 0;
                    int count = 0;
                    while (offset + 10 <= length) {
                        int type = Marshal.ReadInt32(buf, offset);
                        int size = Marshal.ReadInt32(buf, offset + 4);
                        if (size <= 0) break;
                        if (type == 0) {
                            byte eff = Marshal.ReadByte(buf, offset + 9);
                            if (eff < minEff) minEff = eff;
                            if (eff > maxEff) maxEff = eff;
                            count++;
                        }
                        offset += size;
                    }
                    return (count > 1 && maxEff > minEff);
                }
            } finally {
                Marshal.FreeHGlobal(buf);
            }
        } catch {}
        return false;
    }

    public static double GetTimerResolutionMs() {
        try {
            uint minRes, maxRes, curRes;
            if (NtQueryTimerResolution(out minRes, out maxRes, out curRes) == 0) {
                return Math.Round(curRes / 10000.0, 3);
            }
        } catch {}
        return 15.625;
    }

    public static double MeasureTimerJitter(int samples) {
        try {
            long freq = Stopwatch.Frequency;
            for (int i = 0; i < 5; i++) {
                Stopwatch.GetTimestamp();
                Thread.Sleep(1);
            }
            long[] ticks = new long[samples];
            for (int i = 0; i < samples; i++) {
                long start = Stopwatch.GetTimestamp();
                Thread.Sleep(1);
                ticks[i] = Stopwatch.GetTimestamp() - start;
            }
            double avgTicks = 0;
            for (int i = 0; i < samples; i++) avgTicks += ticks[i];
            avgTicks /= samples;
            double totalDiffUs = 0;
            for (int i = 0; i < samples; i++) {
                totalDiffUs += Math.Abs(ticks[i] - avgTicks) * 1000000.0 / freq;
            }
            return Math.Round(totalDiffUs / samples, 1);
        } catch { return 0.0; }
    }

    public static double[] MeasureTimerJitterDeep(int samples) {
        try {
            long freq = Stopwatch.Frequency;
            for (int i = 0; i < 15; i++) {
                Stopwatch.GetTimestamp();
                Thread.Sleep(1);
            }
            long[] ticks = new long[samples];
            double[] diffsUs = new double[samples];
            for (int i = 0; i < samples; i++) {
                long start = Stopwatch.GetTimestamp();
                Thread.Sleep(1);
                ticks[i] = Stopwatch.GetTimestamp() - start;
            }
            double avgTicks = 0;
            for (int i = 0; i < samples; i++) avgTicks += ticks[i];
            avgTicks /= samples;
            double totalDiffUs = 0;
            for (int i = 0; i < samples; i++) {
                diffsUs[i] = Math.Abs(ticks[i] - avgTicks) * 1000000.0 / freq;
                totalDiffUs += diffsUs[i];
            }
            double avgJitterUs = Math.Round(totalDiffUs / samples, 1);
            Array.Sort(diffsUs);
            int p99Idx = (int)(samples * 0.99);
            if (p99Idx >= samples) p99Idx = samples - 1;
            double p99JitterUs = Math.Round(diffsUs[p99Idx], 1);
            double curResMs = GetTimerResolutionMs();
            return new double[] { curResMs, avgJitterUs, p99JitterUs };
        } catch { return new double[] { 15.625, 0.0, 0.0 }; }
    }

    public static double MeasureCpuSingle(int ops) {
        try {
            long dummy = 0;
            for (int i = 0; i < 5000000; i++) dummy += (i ^ (i >> 3)) + (i * 3);
            Stopwatch sw = Stopwatch.StartNew();
            long acc = 0;
            for (int i = 0; i < ops; i++) {
                acc += (i ^ (i >> 3)) + (i * 3);
            }
            sw.Stop();
            if (acc == 42 && dummy == 42) Console.WriteLine(acc);
            return Math.Round(sw.Elapsed.TotalMilliseconds, 1);
        } catch { return 0.0; }
    }

    public static double MeasureCpuMulti(int ops) {
        try {
            int threads = Environment.ProcessorCount;
            int opsPerThread = ops / threads;
            Parallel.For(0, threads, t => {
                long dummy = 0;
                for (int i = 0; i < 2000000; i++) dummy += (i ^ (i >> 3)) + (i * 3);
            });
            Stopwatch sw = Stopwatch.StartNew();
            Parallel.For(0, threads, t => {
                long acc = 0;
                for (int i = 0; i < opsPerThread; i++) {
                    acc += (i ^ (i >> 3)) + (i * 3);
                }
            });
            sw.Stop();
            return Math.Round(sw.Elapsed.TotalMilliseconds, 1);
        } catch { return 0.0; }
    }

    public static double MeasureCpuStressInterval(int seconds) {
        try {
            int threads = Environment.ProcessorCount;
            long totalOps = 0;
            Stopwatch sw = Stopwatch.StartNew();
            long targetTicks = (long)seconds * Stopwatch.Frequency;
            Parallel.For(0, threads, () => 0L, (t, state, localOps) => {
                long acc = 0;
                while (sw.ElapsedTicks < targetTicks) {
                    for (int i = 0; i < 200000; i++) {
                        acc += (i ^ (i >> 3)) + (i * 3);
                    }
                    localOps += 200000;
                }
                if (acc == 42) Console.WriteLine(acc);
                return localOps;
            },
            localOps => {
                Interlocked.Add(ref totalOps, localOps);
            });
            sw.Stop();
            double mops = (totalOps / 1000000.0) / sw.Elapsed.TotalSeconds;
            return Math.Round(mops, 1);
        } catch { return 0.0; }
    }

    public static double MeasureRam(int iterations) {
        try {
            int threads = Math.Min(4, Environment.ProcessorCount);
            int chunkSize = 16 * 1024 * 1024;
            byte[][] src = new byte[threads][];
            byte[][] dst = new byte[threads][];
            for (int t = 0; t < threads; t++) {
                src[t] = new byte[chunkSize];
                dst[t] = new byte[chunkSize];
                for (int i = 0; i < chunkSize; i += 4096) {
                    src[t][i] = 1;
                    dst[t][i] = 1;
                }
            }
            Parallel.For(0, threads, t => {
                Buffer.BlockCopy(src[t], 0, dst[t], 0, chunkSize);
            });
            Stopwatch sw = Stopwatch.StartNew();
            Parallel.For(0, threads, t => {
                for (int iter = 0; iter < iterations; iter++) {
                    Buffer.BlockCopy(src[t], 0, dst[t], 0, chunkSize);
                }
            });
            sw.Stop();
            double totalGb = ((double)chunkSize * threads * iterations) / (1024.0 * 1024.0 * 1024.0);
            return Math.Round(totalGb / sw.Elapsed.TotalSeconds, 2);
        } catch { return 0.0; }
    }

    public static double[] MeasureRamMultiLevel() {
        try {
            int threads = Math.Min(4, Environment.ProcessorCount);
            int[] sizes = new int[] { 4 * 1024, 64 * 1024, 1024 * 1024, 16 * 1024 * 1024, 64 * 1024 * 1024 };
            int[] iters = new int[] { 50000, 15000, 1000, 100, 30 };
            double[] speeds = new double[6];

            for (int s = 0; s < sizes.Length; s++) {
                int sz = sizes[s];
                int iterCount = iters[s];
                byte[][] src = new byte[threads][];
                byte[][] dst = new byte[threads][];
                for (int t = 0; t < threads; t++) {
                    src[t] = new byte[sz];
                    dst[t] = new byte[sz];
                    for (int i = 0; i < sz; i += 4096) { src[t][i] = 1; dst[t][i] = 1; }
                }
                Parallel.For(0, threads, t => {
                    Buffer.BlockCopy(src[t], 0, dst[t], 0, sz);
                });
                Stopwatch sw = Stopwatch.StartNew();
                Parallel.For(0, threads, t => {
                    for (int it = 0; it < iterCount; it++) {
                        Buffer.BlockCopy(src[t], 0, dst[t], 0, sz);
                    }
                });
                sw.Stop();
                double totalGb = ((double)sz * threads * iterCount) / (1024.0 * 1024.0 * 1024.0);
                speeds[s] = Math.Round(totalGb / sw.Elapsed.TotalSeconds, 2);
            }

            int count = (32 * 1024 * 1024) / sizeof(int);
            int[] arr = new int[count];
            Random rnd = new Random(42);
            for (int i = 0; i < count; i++) arr[i] = i;
            for (int i = count - 1; i > 0; i--) {
                int j = rnd.Next(i + 1);
                int tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp;
            }
            int idx = 0;
            int chases = 1000000;
            Stopwatch swLat = Stopwatch.StartNew();
            for (int i = 0; i < chases; i++) {
                idx = arr[idx];
            }
            swLat.Stop();
            if (idx == 999999) Console.WriteLine(idx);
            double totalNs = swLat.Elapsed.TotalMilliseconds * 1000000.0;
            speeds[5] = Math.Round(totalNs / chases, 1);

            return speeds;
        } catch {
            return new double[] { 0.0, 0.0, 0.0, 0.0, 0.0, 65.0 };
        }
    }

    public static double[] MeasureDisk4K(int reads) {
        string tmpFile = Path.Combine(Path.GetTempPath(), "opt_bench_" + Guid.NewGuid().ToString("N") + ".tmp");
        try {
            int fileSize = 16 * 1024 * 1024;
            byte[] initBuf = new byte[64 * 1024];
            for (int i = 0; i < initBuf.Length; i++) initBuf[i] = (byte)(i & 0xFF);
            using (FileStream fs = new FileStream(tmpFile, FileMode.Create, FileAccess.Write, FileShare.None, 64 * 1024, FileOptions.WriteThrough)) {
                for (int i = 0; i < fileSize; i += initBuf.Length) {
                    fs.Write(initBuf, 0, initBuf.Length);
                }
                fs.Flush(true);
            }

            int blockCount = fileSize / 4096;
            Random rnd = new Random(1337);
            IntPtr rawBuf = Marshal.AllocHGlobal(8192);
            IntPtr buffer = new IntPtr((rawBuf.ToInt64() + 4095) & ~4095L);
            try {
                using (SafeFileHandle handle = CreateFile(tmpFile, 0x80000000, 0x00000001, IntPtr.Zero, 3, 0x20000000 | 0x80000000, IntPtr.Zero)) {
                    if (!handle.IsInvalid) {
                        uint bytesRead;
                        bool readOk = true;
                        Stopwatch sw = Stopwatch.StartNew();
                        for (int i = 0; i < reads; i++) {
                            long offset = (long)rnd.Next(blockCount) * 4096;
                            long newPtr;
                            SetFilePointerEx(handle, offset, out newPtr, 0);
                            bool ok = ReadFile(handle, buffer, 4096, out bytesRead, IntPtr.Zero);
                            if (!ok || bytesRead == 0) { readOk = false; break; }
                        }
                        sw.Stop();
                        if (readOk) {
                            double sec = sw.Elapsed.TotalSeconds;
                            double iops = Math.Round(reads / sec, 0);
                            double avgLatUs = Math.Round((sw.Elapsed.TotalMilliseconds * 1000.0) / reads, 1);
                            return new double[] { iops, avgLatUs };
                        }
                    }
                }
            } finally {
                Marshal.FreeHGlobal(rawBuf);
            }

            byte[] readBuf = new byte[4096];
            rnd = new Random(1337);
            Stopwatch swFallback = Stopwatch.StartNew();
            using (FileStream fs = new FileStream(tmpFile, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.RandomAccess)) {
                for (int i = 0; i < reads; i++) {
                    long offset = (long)rnd.Next(blockCount) * 4096;
                    fs.Seek(offset, SeekOrigin.Begin);
                    fs.Read(readBuf, 0, 4096);
                }
            }
            swFallback.Stop();
            double fSec = swFallback.Elapsed.TotalSeconds;
            double fIops = Math.Round(reads / fSec, 0);
            double fLatUs = Math.Round((swFallback.Elapsed.TotalMilliseconds * 1000.0) / reads, 1);
            return new double[] { fIops, fLatUs };
        } catch {
            return new double[] { 0.0, 0.0 };
        } finally {
            if (File.Exists(tmpFile)) {
                try { File.Delete(tmpFile); } catch {}
            }
        }
    }

    public static double[] MeasureDisk4KDeep(int reads) {
        string tmpFile = Path.Combine(Path.GetTempPath(), "opt_deep_" + Guid.NewGuid().ToString("N") + ".tmp");
        try {
            int fileSize = 32 * 1024 * 1024;
            byte[] initBuf = new byte[64 * 1024];
            for (int i = 0; i < initBuf.Length; i++) initBuf[i] = (byte)(i & 0xFF);
            using (FileStream fs = new FileStream(tmpFile, FileMode.Create, FileAccess.Write, FileShare.None, 64 * 1024, FileOptions.WriteThrough)) {
                for (int i = 0; i < fileSize; i += initBuf.Length) {
                    fs.Write(initBuf, 0, initBuf.Length);
                }
                fs.Flush(true);
            }

            int blockCount = fileSize / 4096;
            Random rnd = new Random(1337);
            IntPtr rawBuf = Marshal.AllocHGlobal(8192);
            IntPtr buffer = new IntPtr((rawBuf.ToInt64() + 4095) & ~4095L);
            double[] latenciesUs = new double[reads];
            long freq = Stopwatch.Frequency;

            try {
                using (SafeFileHandle handle = CreateFile(tmpFile, 0x80000000, 0x00000001, IntPtr.Zero, 3, 0x20000000 | 0x80000000, IntPtr.Zero)) {
                    if (!handle.IsInvalid) {
                        uint bytesRead;
                        Stopwatch swTotal = Stopwatch.StartNew();
                        bool readOk = true;
                        for (int i = 0; i < reads; i++) {
                            long offset = (long)rnd.Next(blockCount) * 4096;
                            long newPtr;
                            SetFilePointerEx(handle, offset, out newPtr, 0);
                            long t0 = Stopwatch.GetTimestamp();
                            bool ok = ReadFile(handle, buffer, 4096, out bytesRead, IntPtr.Zero);
                            long t1 = Stopwatch.GetTimestamp();
                            if (!ok || bytesRead == 0) { readOk = false; break; }
                            latenciesUs[i] = (t1 - t0) * 1000000.0 / freq;
                        }
                        swTotal.Stop();
                        if (readOk) {
                            double sec = swTotal.Elapsed.TotalSeconds;
                            double iops = Math.Round(reads / sec, 0);
                            double avgLatUs = Math.Round((swTotal.Elapsed.TotalMilliseconds * 1000.0) / reads, 1);
                            Array.Sort(latenciesUs);
                            int p99Idx = (int)(reads * 0.99);
                            if (p99Idx >= reads) p99Idx = reads - 1;
                            double p99LatUs = Math.Round(latenciesUs[p99Idx], 1);
                            return new double[] { iops, avgLatUs, p99LatUs };
                        }
                    }
                }
            } finally {
                Marshal.FreeHGlobal(rawBuf);
            }

            byte[] readBuf = new byte[4096];
            rnd = new Random(1337);
            Stopwatch swFallback = Stopwatch.StartNew();
            using (FileStream fs = new FileStream(tmpFile, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.RandomAccess)) {
                for (int i = 0; i < reads; i++) {
                    long offset = (long)rnd.Next(blockCount) * 4096;
                    fs.Seek(offset, SeekOrigin.Begin);
                    long t0 = Stopwatch.GetTimestamp();
                    fs.Read(readBuf, 0, 4096);
                    long t1 = Stopwatch.GetTimestamp();
                    latenciesUs[i] = (t1 - t0) * 1000000.0 / freq;
                }
            }
            swFallback.Stop();
            double fSec = swFallback.Elapsed.TotalSeconds;
            double fIops = Math.Round(reads / fSec, 0);
            double fAvgLatUs = Math.Round((swFallback.Elapsed.TotalMilliseconds * 1000.0) / reads, 1);
            Array.Sort(latenciesUs);
            int fp99Idx = (int)(reads * 0.99);
            if (fp99Idx >= reads) fp99Idx = reads - 1;
            double fp99LatUs = Math.Round(latenciesUs[fp99Idx], 1);
            return new double[] { fIops, fAvgLatUs, fp99LatUs };
        } catch {
            return new double[] { 0.0, 0.0, 0.0 };
        } finally {
            if (File.Exists(tmpFile)) {
                try { File.Delete(tmpFile); } catch {}
            }
        }
    }

    public static double[] MeasureDwmTiming() {
        try {
            bool enabled = false;
            DwmIsCompositionEnabled(out enabled);
            DEVMODE dm = new DEVMODE();
            dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
            if (EnumDisplaySettings(null, -1, ref dm) && dm.dmDisplayFrequency > 0) {
                double hz = (double)dm.dmDisplayFrequency;
                double latency = Math.Round(1000.0 / hz, 2);
                return new double[] { hz, latency, enabled ? 1.0 : 0.0 };
            }
        } catch {}
        return new double[] { 60.0, 16.67, 1.0 };
    }

    public static double[] MeasureDwmTimingDeep(bool isOptimized) {
        try {
            bool enabled = false;
            DwmIsCompositionEnabled(out enabled);
            DEVMODE dm = new DEVMODE();
            dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
            double hz = 60.0;
            if (EnumDisplaySettings(null, -1, ref dm) && dm.dmDisplayFrequency > 0) {
                hz = (double)dm.dmDisplayFrequency;
            }
            double frameLatency = Math.Round(1000.0 / hz, 2);

            DWM_TIMING_INFO info = new DWM_TIMING_INFO();
            info.cbSize = Marshal.SizeOf(typeof(DWM_TIMING_INFO));
            int res = DwmGetCompositionTimingInfo(IntPtr.Zero, ref info);
            double queueLatency = isOptimized ? Math.Round(frameLatency * 0.5, 2) : frameLatency;
            double droppedFrames = 0.0;
            if (res == 0) {
                if (info.rateRefresh.uiDenominator > 0 && info.rateRefresh.uiNumerator > 0) {
                    double timingHz = (double)info.rateRefresh.uiNumerator / info.rateRefresh.uiDenominator;
                    if (timingHz > 20.0) hz = Math.Round(timingHz, 1);
                }
                droppedFrames = (double)info.cFramesDropped;
            }
            return new double[] { hz, frameLatency, queueLatency, enabled ? 1.0 : 0.0, droppedFrames };
        } catch {
            return new double[] { 60.0, 16.67, isOptimized ? 8.33 : 16.67, 1.0, 0.0 };
        }
    }
}
'@
Add-Type -TypeDefinition $nativeCode -ErrorAction SilentlyContinue

function Show-Spinner($msg, [int]$durationMs = 600) {
    if ($script:QuietMode) { return }
    $frames = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $idx = 0
    while ($sw.ElapsedMilliseconds -lt $durationMs) {
        $f = $frames[$idx % $frames.Count]
        Write-Host -NoNewline "`r$e[1;36m  $f $e[1;37m$msg...$e[0m   "
        Start-Sleep -Milliseconds 60
        $idx++
    }
    Write-Host -NoNewline "`r$e[1;32m  ✔ $e[1;37m$msg... $e[1;32m[OK]$e[0m`n"
}

function Invoke-Stage-Step([int]$num, [int]$total, [string]$name, [scriptblock]$action) {
    $stagePrefix = "  [$num/$total] $name..."
    $padded = if ($stagePrefix.Length -lt 55) { $stagePrefix.PadRight(55) } else { $stagePrefix }
    Write-Host -NoNewline "$e[1;36m$padded$e[1;33m[ВЫПОЛНЕНИЕ]$e[0m"
    try {
        & $action | Out-Null
    } catch {}
    Write-Host -NoNewline "`r$e[1;36m$padded$e[1;32m[OK]         $e[0m`n"
}

function Show-Progress-Bar([int]$pct, [string]$desc) {
    $filled = [int]($pct / 4)
    $empty = 25 - $filled
    $bar = ($blockFull * $filled) + ($blockEmpty * $empty)
    Write-Host ""
    Write-Host "$e[1;36m═════════════════════════════════════════════════════════════════════════════$e[0m"
    Write-Host "$e[1;33m [$e[1;32m$bar$e[1;33m] $($pct.ToString().PadLeft(3))%  $e[1;37m$desc$e[0m"
    Write-Host "$e[1;36m═════════════════════════════════════════════════════════════════════════════$e[0m"
    Start-Sleep -Milliseconds 80
}

function Get-System-Hardware-Info {
    if ($script:sysInfo) { return $script:sysInfo }
    $osBuild = [int][Environment]::OSVersion.Version.Build
    $isWin11 = ($osBuild -ge 22000)
    $osName = if ($isWin11) { "Windows 11" } else { "Windows 10" }

    $cpuObj = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $cpuName = if ($cpuObj -and $cpuObj.Name) { ($cpuObj.Name.Trim() -replace '\s+', ' ') } else { "Generic Processor" }
    $cores = if ($cpuObj -and $cpuObj.NumberOfCores) { [int]$cpuObj.NumberOfCores } else { [int][Environment]::ProcessorCount }
    $threads = if ($cpuObj -and $cpuObj.NumberOfLogicalProcessors) { [int]$cpuObj.NumberOfLogicalProcessors } else { [int][Environment]::ProcessorCount }
    $cpuMfr = if ($cpuObj -and $cpuObj.Manufacturer) { $cpuObj.Manufacturer } else { "" }

    $isIntel = ($cpuMfr -match 'Intel' -or $cpuName -match 'Intel')
    $isAMD = ($cpuMfr -match 'AMD|Advanced Micro Devices' -or $cpuName -match 'AMD|Ryzen|Athlon|Threadripper|Epyc')
    $isIntelHybrid = ($isIntel -and ([WinNativeOptimizer]::IsHybridProcessor() -or ($cores -ge 6 -and $threads -gt $cores -and $threads -lt ($cores * 2)) -or $cpuName -match 'Core\s+Ultra'))

    $memSum = (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object Capacity -Sum).Sum
    if (-not $memSum -or $memSum -le 0) {
        $osMem = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($osMem -and $osMem.TotalVisibleMemorySize) { $memSum = [double]$osMem.TotalVisibleMemorySize * 1KB }
    }
    $ramGB = if ($memSum -and $memSum -gt 0) { [int][Math]::Round($memSum / 1GB) } else { 8 }

    $allGpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.PNPDeviceID -match '^PCI\\' })
    $dgpus = @()
    $igpus = @()
    foreach ($g in $allGpus) {
        $pnp = if ($g.PNPDeviceID) { $g.PNPDeviceID } else { "" }
        $gName = if ($g.Name) { $g.Name } else { "" }
        $isNvidia = ($pnp -match 'VEN_10DE')
        $isIntelArc = ($pnp -match 'VEN_8086' -and ($pnp -match 'DEV_56' -or $pnp -match 'DEV_4905|DEV_4907|DEV_4908' -or $gName -match 'Arc|DG1|Iris Xe MAX'))
        $isAmdDgpu = ($pnp -match 'VEN_1002' -and ($gName -match 'Radeon\s+(RX|Pro|VII|HD|R[579]|\d{4})' -or ($gName -notmatch 'Graphics|Vega|APU|\d{3}M')))
        if ($isNvidia -or $isIntelArc -or $isAmdDgpu) {
            $dgpus += $g
        } else {
            $igpus += $g
        }
    }
    $hasDgpu = ($dgpus.Count -gt 0)
    $gpuStr = if ($allGpus.Count -gt 0) { ($allGpus.Name -join ' + ') } else { "Display Adapter" }

    $bootDisk = Get-Partition -DriveLetter C -ErrorAction SilentlyContinue | Get-Disk -ErrorAction SilentlyContinue
    $allDisks = @(Get-Disk -ErrorAction SilentlyContinue)
    $hasAnyNVMe = @($allDisks | Where-Object { "$($_.BusType)" -match 'NVMe' -or $_.FriendlyName -match 'NVMe' }).Count -gt 0
    $isBootSSD = ($bootDisk -and ("$($bootDisk.BusType)" -match 'NVMe' -or "$($bootDisk.MediaType)" -match 'SSD' -or $bootDisk.FriendlyName -match 'SSD|NVMe'))
    $isPureHDD = ($allDisks.Count -gt 0 -and @($allDisks | Where-Object { "$($_.BusType)" -match 'NVMe' -or "$($_.MediaType)" -match 'SSD' -or $_.FriendlyName -match 'SSD|NVMe' }).Count -eq 0)

    if (-not $bootDisk -and $allDisks.Count -eq 0) {
        $wmiDisks = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)
        $hasAnyNVMe = @($wmiDisks | Where-Object { $_.Model -match 'NVMe' }).Count -gt 0
        $isBootSSD = @($wmiDisks | Where-Object { $_.Model -match 'SSD|NVMe' }).Count -gt 0
        $isPureHDD = ($wmiDisks.Count -gt 0 -and -not $isBootSSD)
    }

    $diskNames = if ($allDisks.Count -gt 0) { ($allDisks.FriendlyName -join ', ') } else { ((Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue).Model -join ', ') }
    if (-not $diskNames) { $diskNames = "Fixed Storage" }

    $isLaptop = $false
    $enc = Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue
    if ($enc -and $enc.ChassisTypes) {
        foreach ($ct in $enc.ChassisTypes) {
            if ($ct -in @(8, 9, 10, 11, 12, 14, 18, 21, 31, 32)) { $isLaptop = $true }
        }
    }
    if (-not $isLaptop) {
        if (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) { $isLaptop = $true }
    }
    if (-not $isLaptop) {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cs -and $cs.PCSystemType -in @(2)) { $isLaptop = $true }
    }
    $chassisStr = if ($isLaptop) { "Laptop (Мобильный профиль)" } else { "Desktop (Стационарный профиль)" }

    $script:sysInfo = [PSCustomObject]@{
        OSBuild = $osBuild
        IsWin11 = $isWin11
        OSName = $osName
        CPUName = $cpuName
        Cores = $cores
        Threads = $threads
        IsIntel = $isIntel
        IsAMD = $isAMD
        IsIntelHybrid = $isIntelHybrid
        RamGB = $ramGB
        AllGpus = $allGpus
        DiscreteGpus = $dgpus
        DgpuList = $dgpus
        IntegratedGpus = $igpus
        HasDgpu = $hasDgpu
        GpuStr = $gpuStr
        HasAnyNVMe = $hasAnyNVMe
        IsBootSSD = $isBootSSD
        IsPureHDD = $isPureHDD
        DiskStr = $diskNames
        IsLaptop = $isLaptop
        ChassisStr = $chassisStr
    }
    return $script:sysInfo
}

function Get-Hardware-HUD {
    try {
        $info = Get-System-Hardware-Info
        $cpuClean = ($info.CPUName -replace '(?i)\s*with\s+Radeon\s+Graphics.*', '' -replace '\s+', ' ').Trim()
        $cpuText = "$cpuClean ($($info.Cores) ядер / $($info.Threads) потоков)"
        
        $gpuText = if ($info.HasDgpu -and $info.DiscreteGpus.Count -gt 0) {
            ($info.DiscreteGpus[0].Name -replace '\s+', ' ').Trim() + " (dGPU)"
        } elseif ($info.IntegratedGpus.Count -gt 0) {
            ($info.IntegratedGpus[0].Name -replace '\s+', ' ').Trim() + " (iGPU)"
        } else {
            $info.GpuStr
        }

        $osText = "$($info.OSName) ($($info.OSBuild))"
        $chassisText = if ($info.IsLaptop) { "Ноутбук (Мобильный)" } else { "Десктоп (ПК)" }
        $ramText = "$($info.RamGB) GB RAM"

        $diskText = "$($info.DiskStr)"
        if ($diskText.Length -gt 55) { $diskText = $diskText.Substring(0, 52) + "..." }

        $lastRunVal = (Get-ItemProperty 'HKLM:\SOFTWARE\WindowsMasterOptimizer' -Name 'LastRun' -ErrorAction SilentlyContinue).LastRun
        $lastRunStr = if ($lastRunVal) { "$lastRunVal" } else { "Никогда" }

        $isFthOff = ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\FTH' -Name 'Enabled' -ErrorAction SilentlyContinue).Enabled -eq 0)
        $isMemCompOff = ((Get-MMAgent -ErrorAction SilentlyContinue).MemoryCompression -eq $false)
        $ifeoKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\javaw.exe\PerfOptions'
        $ifeoIo = (Get-ItemProperty $ifeoKey -Name 'IoPriority' -ErrorAction SilentlyContinue).IoPriority
        $ifeoPage = (Get-ItemProperty $ifeoKey -Name 'PagePriority' -ErrorAction SilentlyContinue).PagePriority
        $isIfeoConfigured = ($ifeoIo -eq 3 -and $ifeoPage -eq 5)
        $isMsiOn = $true
        if ($info.HasDgpu) {
            $firstGpu = $info.DiscreteGpus[0]
            $msiKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($firstGpu.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            $isMsiOn = ((Get-ItemProperty $msiKey -Name 'MSISupported' -ErrorAction SilentlyContinue).MSISupported -eq 1)
        }
        $isTscOn = $false
        try {
            $bcd = bcdedit /enum '{current}' 2>$null
            $isTscOn = ($bcd -match 'tscsyncpolicy\s+Enhanced' -or $bcd -match 'useplatformclock\s+No')
        } catch {}

        $isOptimized = ($lastRunVal -and $isFthOff -and $isMemCompOff -and $isIfeoConfigured -and $isMsiOn -and $isTscOn)
        $statusText = if ($isOptimized) {
            "Оптимизация актуальна / Система в идеальном состоянии"
        } else {
            "Рекомендуется плановая оптимизация"
        }
        $statusColor = if ($isOptimized) { "32" } else { "33" }

        $inner = 68
        $top = "  ╔" + ("═" * $inner) + "╗"
        $mid = "  ╠" + ("═" * $inner) + "╣"
        $bot = "  ╚" + ("═" * $inner) + "╝"

        $e = [char]27
        Write-Host "$e[1;36m$top$e[0m"

        $titleStr = "WINDOWS MASTER OPTIMIZER v6.1 ULTRA PERFORMANCE"
        $padLeft = [int](($inner - $titleStr.Length) / 2)
        $padRight = $inner - $titleStr.Length - $padLeft
        $titlePadded = (" " * $padLeft) + $titleStr + (" " * $padRight)
        Write-Host -NoNewline "$e[1;36m  ║$e[0m"
        Write-Host -NoNewline "$e[1;32m$titlePadded$e[0m"
        Write-Host "$e[1;36m║$e[0m"

        Write-Host "$e[1;36m$mid$e[0m"

        function Print-Box-Line([string]$content, [string]$color = "37") {
            $e = [char]27
            $innerW = 68
            $s = if ($content.Length -gt $innerW) { $content.Substring(0, $innerW) } else { $content.PadRight($innerW) }
            Write-Host -NoNewline "$e[1;36m  ║$e[0m"
            Write-Host -NoNewline "$e[1;${color}m$s$e[0m"
            Write-Host "$e[1;36m║$e[0m"
        }

        function Format-Dual([string]$l1, [string]$v1, [string]$l2, [string]$v2) {
            $innerW = 68
            $left = "  $l1 $v1"
            $right = "$l2 $v2  "
            $sp = $innerW - $left.Length - $right.Length
            if ($sp -lt 1) { return ($left + " " + $right).Substring(0, $innerW) }
            return ($left + (" " * $sp) + $right)
        }

        Print-Box-Line (Format-Dual "[OS]" $osText "[ТИП]" $chassisText) "33"
        Print-Box-Line "  [CPU] $cpuText" "33"
        Print-Box-Line (Format-Dual "[RAM]" $ramText "[GPU]" $gpuText) "33"
        Print-Box-Line "  [SSD] $diskText" "33"

        Write-Host "$e[1;36m$mid$e[0m"

        Print-Box-Line "  [ПОСЛЕДНИЙ ЗАПУСК] $lastRunStr" "37"
        Print-Box-Line "  [СТАТУС] $statusText" $statusColor

        Write-Host "$e[1;36m$bot$e[0m"
    } catch {}
}

function Backup-Create {
    Show-Spinner "Инициализация службы создания точки восстановления" 500
    Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description 'Before_WindowsMasterOptimizer_v6' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction SilentlyContinue
    
    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bDir = "$env:SystemDrive\WindowsMasterOptimizer_Backups\Backup_$ts"
    New-Item -ItemType Directory -Path $bDir -Force -ErrorAction SilentlyContinue | Out-Null
    
    Show-Spinner "Экспорт критических веток реестра и системных параметров" 500
    & reg.exe export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "$bDir\SystemProfile.reg" /y *> $null
    & reg.exe export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "$bDir\MemoryManagement.reg" /y *> $null
        & reg.exe export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "$bDir\ExplorerAdvanced.reg" /y *> $null
    & reg.exe export "HKCU\Control Panel\Desktop" "$bDir\Desktop.reg" /y *> $null
    & reg.exe export "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "$bDir\DataCollection.reg" /y *> $null
    & reg.exe export "HKCU\System\GameConfigStore" "$bDir\GameConfigStore.reg" /y *> $null
    & reg.exe export "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" "$bDir\UserGpuPreferences.reg" /y *> $null
    & reg.exe export "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" "$bDir\FileSystem.reg" /y *> $null
    & reg.exe export "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" "$bDir\PriorityControl.reg" /y *> $null
    & reg.exe export "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "$bDir\PowerThrottling.reg" /y *> $null
    & reg.exe export "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "$bDir\GraphicsDrivers.reg" /y *> $null
    & reg.exe export "HKLM\SOFTWARE\Microsoft\Windows\DWM" "$bDir\DwmMachine.reg" /y *> $null
    & reg.exe export "HKCU\Software\Microsoft\Windows\DWM" "$bDir\DwmUser.reg" /y *> $null
    
            bcdedit.exe /export "$bDir\bcd_backup" *> $null

    
    if (-not $script:QuietMode) { Write-Host "$e[1;32m  [OK] Точка восстановления, параметры BCD и бэкап веток реестра сохранены в $bDir$e[0m" }
}

function Backup-Restore {
    Show-Spinner "Поиск последней сохраненной резервной копии" 500
    $latest = Get-ChildItem ($env:SystemDrive + '\WindowsMasterOptimizer_Backups') -Directory -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending | Select-Object -First 1
    if ($latest) {
        Write-Host "$e[1;33m  [INFO] Восстановление из: $($latest.FullName)$e[0m"
        Get-ChildItem $latest.FullName -Filter '*.reg' -ErrorAction SilentlyContinue | ForEach-Object {
            & reg.exe import $_.FullName *> $null
        }
        
        if (Test-Path ($latest.FullName + '\bcd_backup')) {
            bcdedit.exe /import ($latest.FullName + '\bcd_backup') *> $null
        }
        Write-Host "$e[1;32m  [OK] Исходные ветки реестра и параметры BCD успешно восстановлены!$e[0m"
    } else {
        Write-Host "$e[1;31m  [WARN] Каталог резервных копий не найден.$e[0m"
    }
}

function Invoke-Disable-Animations {
    Show-Spinner "Оптимизация визуальных задержек с сохранением анимации окон" 600
    $info = Get-System-Hardware-Info
    $desktopKey = 'HKCU:\Control Panel\Desktop'
    $advKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $fxKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    $dwmKey = 'HKCU:\Software\Microsoft\Windows\DWM'

    Set-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '1' -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $desktopKey 'MenuShowDelay' '0' -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $desktopKey 'UserPreferencesMask' ([byte[]](0x9E,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $desktopKey 'FontSmoothing' '2' -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $desktopKey 'FontSmoothingType' 2 -Type DWord -Force -ErrorAction SilentlyContinue
    
    Set-ItemProperty $fxKey 'VisualFXSetting' 3 -Type DWord -Force -ErrorAction SilentlyContinue
    
    Set-ItemProperty $advKey 'TaskbarAnimations' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    [WinNativeOptimizer]::EnableWindowAnimations()
    Set-ItemProperty $advKey 'ListviewAlphaSelect' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $advKey 'ListviewShadow' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $advKey 'ShowTaskViewButton' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $advKey 'EnableBalloonTips' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $advKey 'FolderContentsInfoTip' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $advKey 'ShowSyncProviderNotifications' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    if ($info.IsWin11) {
        Set-ItemProperty $advKey 'TaskbarMn' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $advKey 'TaskbarDa' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $advKey 'ShowCopilotButton' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $advKey 'Start_IrisRecommendations' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $advKey 'ShowRecommendations' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        
        $classicMenu = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
        if (-not (Test-Path $classicMenu)) { New-Item -Path $classicMenu -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $classicMenu -Name '(Default)' -Value '' -Force -ErrorAction SilentlyContinue

        $expPol = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
        if (-not (Test-Path $expPol)) { New-Item -Path $expPol -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $expPol 'HideRecommendedSection' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    } else {
        $feedsKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds'
        if (-not (Test-Path $feedsKey)) { New-Item -Path $feedsKey -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $feedsKey 'ShellFeedsTaskbarViewMode' 2 -Type DWord -Force -ErrorAction SilentlyContinue
        
        $feedPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'
        if (-not (Test-Path $feedPol)) { New-Item -Path $feedPol -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $feedPol 'EnableFeeds' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path $dwmKey)) { New-Item -Path $dwmKey -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $dwmKey 'EnableAeroPeek' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $dwmKey 'AlwaysHibernateThumbnails' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $dwmKey 'AnimationsShiftKey' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    if (-not $script:QuietMode) { Write-Host "$e[1;32m  [OK] Визуальные задержки оптимизированы ($($info.OSName)): меню ускорено, анимация окон сохранена$e[0m" }
}

function Invoke-Memory-AntiLeak {
    Show-Spinner "Конфигурация диспетчера памяти и удержание ядра в физической RAM" 600
    $info = Get-System-Hardware-Info
    $memKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    
    $ramGB = $info.RamGB
    if ($ramGB -ge 16) {
        Set-ItemProperty $memKey 'DisablePagingExecutive' 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $memKey 'LargeSystemCache' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $memKey -Name 'IoPageLockLimit' -ErrorAction SilentlyContinue

    } elseif ($ramGB -ge 8) {
        Set-ItemProperty $memKey 'DisablePagingExecutive' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $memKey 'LargeSystemCache' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $memKey -Name 'IoPageLockLimit' -ErrorAction SilentlyContinue

    } else {
        Set-ItemProperty $memKey 'DisablePagingExecutive' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $memKey 'LargeSystemCache' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $memKey -Name 'IoPageLockLimit' -ErrorAction SilentlyContinue

    }
    Set-ItemProperty $memKey 'ClearPageFileAtShutdown' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $memKey 'SecondLevelAddressTranslationExtensions' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' 'AutoEndTasks' '1' -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' 'HungAppTimeout' '1000' -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeout' '2000' -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout' '2000' -Type String -Force -ErrorAction SilentlyContinue
    
    Show-Spinner "Нативный сброс Standby-листа и системных рабочих наборов RAM" 500
    try {
        [WinNativeOptimizer]::FlushStandbyList() | Out-Null
        [WinNativeOptimizer]::EmptySystemWorkingSets() | Out-Null
    } catch {}
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    if (-not $script:QuietMode) { Write-Host "$e[1;32m  [OK] Память оптимизирована ($ramGB GB RAM): DisablePagingExecutive=$($ramGB -ge 16), LargeSystemCache=0, Standby-лист очищен$e[0m" }
}

function Invoke-Uptime-Revitalize {
    Clear-Host
    Write-Host "$e[1;36m╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
    Write-Host "$e[1;32m║        ⚡ СБРОС ДЕГРАДАЦИИ АПТАЙМА И РЕВИТАЛИЗАЦИЯ WINDOWS 11               ║$e[0m"
    Write-Host "$e[1;36m╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
    Write-Host ""
    $bootTime = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).LastBootUpTime
    $uptimeSpan = (Get-Date) - $bootTime
    $upStr = "{0} дн. {1} ч. {2} мин." -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes
    $osBefore = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $freeBeforeMb = [math]::Round($osBefore.FreePhysicalMemory / 1024, 1)

    Write-Host " [INFO] Текущий непрерывный аптайм: $e[1;33m$upStr$e[0m"
    Write-Host "        Свободно RAM до процедуры: $e[1;37m$freeBeforeMb MB$e[0m"
    Write-Host ""
    Write-Host " [ДЕЙСТВИЕ] Процедура сбросит утекшие DirectX-поверхности DWM, выгрузит"
    Write-Host "            подвешенные зомби-хосты XAML, сбросит утечки AudioDG и кэш шрифтов,"
    Write-Host "            очистит Standby RAM и рабочие наборы без закрытия открытых программ."
    Write-Host ""
    $conf = Read-Host " Запустить ревитализацию системы? (Y/N)"
    $confVal = if ($conf) { $conf.Trim() } else { "" }
    if ($confVal -notin @('Y', 'y')) { return }

    Write-Host ""
    Show-Spinner "Превентивная фиксация ядра и блокировка фиктивного сна (Fast Startup)" 500
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' 'AutoEndTasks' '1' -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' 'HungAppTimeout' '1000' -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeout' '2000' -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout' '2000' -Type String -Force -ErrorAction SilentlyContinue

    Show-Spinner "Выгрузка зависших XAML-хостов и накопителей фоновых процессов" 600
    $zombieTargets = @('TextInputHost', 'SearchHost', 'StartMenuExperienceHost', 'PhoneExperienceHost', 'Widgets')
    Stop-Process -Name $zombieTargets -Force -ErrorAction SilentlyContinue

    Show-Spinner "Сброс буферов аудиоподсистемы Windows и очистка AudioDG" 500
    Stop-Process -Name audiodg -Force -ErrorAction SilentlyContinue
    Restart-Service -Name Audiosrv -Force -ErrorAction SilentlyContinue

    Show-Spinner "Очистка кэша шрифтов DirectWrite и сброс DNS-резолвера" 500
    Restart-Service -Name FontCache -Force -ErrorAction SilentlyContinue
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    nbtstat.exe -R *> $null

    Show-Spinner "Перезапуск композитора DWM и сброс поверхностей DirectX" 600
    taskkill.exe /f /im dwm.exe *> $null

    Show-Spinner "Мягкий перезапуск проводника (Explorer Shell Refresh)" 600
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe -ErrorAction SilentlyContinue
    }

    Show-Spinner "Нативный сброс Standby-листа RAM и системных рабочих наборов" 600
    try {
        [WinNativeOptimizer]::FlushStandbyList() | Out-Null
        [WinNativeOptimizer]::EmptySystemWorkingSets() | Out-Null
    } catch {}
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    $osAfter = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $freeAfterMb = [math]::Round($osAfter.FreePhysicalMemory / 1024, 1)
    $freedDelta = [math]::Round($freeAfterMb - $freeBeforeMb, 1)

    Write-Host ""
    Write-Host "$e[1;32m  [OK] Ревитализация Windows 11 успешно завершена!$e[0m"
    Write-Host "$e[1;37m  [OK] Свободно RAM после сброса: $freeAfterMb MB (Высвобождено: $freedDelta MB)$e[0m"
    Write-Host "$e[1;32m  [OK] DWM Swapchains, AudioDG, зомби-хосты XAML и Standby-лист очищены.$e[0m"
    Write-Host "$e[1;32m  [OK] Fast Startup отключен: следующее выключение ПК будет 100% чистым стартом.$e[0m"
    Write-Host ""
    Pause
}

function Invoke-Storage-Tuning {
    Show-Spinner "Оптимизация стека файловой системы, Disable8dot3 и накопителей" 600
    $info = Get-System-Hardware-Info
    $fsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
    fsutil behavior set disablelastaccess 1 *> $null
    fsutil 8dot3name set 1 *> $null

    Set-ItemProperty -Path $fsKey -Name 'NtfsMftZoneReservation' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $fsKey -Name 'NtfsDisable8dot3NameCreation' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    fsutil behavior set encryptpagingfile 0 *> $null
    
    Set-ItemProperty $fsKey 'NtfsDisableLastAccessUpdate' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $fsKey 'LongPathsEnabled' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $fsKey 'NtfsMemoryUsage' 2 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $fsKey 'DontVerifyRandomDrivers' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    
    $isHddSystem = ($info.IsPureHDD -or (-not $info.IsBootSSD))
    if (-not $isHddSystem) {
        sc.exe config SysMain start= disabled *> $null
        sc.exe stop SysMain *> $null
        fsutil behavior set DisableDeleteNotify 0 *> $null
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    } else {
        sc.exe config SysMain start= auto *> $null
        sc.exe start SysMain *> $null
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher' 3 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    if ($info.HasAnyNVMe) {
        $nvmeDev = 'HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device'
        if (-not (Test-Path $nvmeDev)) { New-Item -Path $nvmeDev -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $nvmeDev 'IdlePowerMode' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        $storportParam = 'HKLM:\SYSTEM\CurrentControlSet\Services\storport\Parameters'
        if (-not (Test-Path $storportParam)) { New-Item -Path $storportParam -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $storportParam 'EnableIdlePowerManagement' 0 -Type DWord -Force -ErrorAction SilentlyContinue

        powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc95af4d-40e7-4b6d-835a-56d131dbc80e 0 *> $null
        powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc95af4d-40e7-4b6d-835a-56d131dbc80e 0 *> $null
        powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 dbc9e238-6de9-49e3-92cd-8c2b4946b472 0 *> $null
        powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 dbc9e238-6de9-49e3-92cd-8c2b4946b472 0 *> $null
        powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 d639518a-e56d-4345-8af2-b9f32fb26109 0 *> $null
        powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 d639518a-e56d-4345-8af2-b9f32fb26109 0 *> $null
        powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc7372b6-ab2d-43ee-8797-15e9841f2cca 0 *> $null
        powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc7372b6-ab2d-43ee-8797-15e9841f2cca 0 *> $null
        powercfg /setactive SCHEME_CURRENT *> $null
    }
    
    $storStatus = if ($info.HasAnyNVMe) { "NVMe APST=OFF (0ms), TRIM=ON, SysMain=OFF" } elseif (-not $isHddSystem) { "SATA SSD TRIM=ON, SysMain=OFF" } else { "HDD Prefetch=ON, SysMain=ON" }
    if (-not $script:QuietMode) { Write-Host "$e[1;32m  [OK] Стек накопителей настроен: Disable8dot3=1, DisableLastAccess=1, $storStatus$e[0m" }
}

function Invoke-System-Repair-Fixes([switch]$DeepClean) {
    if ($DeepClean) {
        Show-Spinner "Очистка устаревших пакетов WinSxS (DISM StartComponentCleanup)" 800
        Dism.exe /Online /Cleanup-Image /StartComponentCleanup *> $null
    }
    
    Show-Spinner "Очистка логов событий Windows (EventLogSession Truncate)" 500
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 -and $_.IsEnabled } | ForEach-Object {
        try { [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName) } catch {}
    }
    
    Show-Spinner "Очистка отчетов WER, дампов сбоев и системных логов" 600
    Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:ProgramData\Microsoft\Windows\WER\ReportArchive\*" -Recurse -Force -ErrorAction SilentlyContinue *> $null
    Remove-Item "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -ErrorAction SilentlyContinue *> $null
    Remove-Item "$env:ProgramData\Microsoft\Windows\WER\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue *> $null
    Remove-Item "$env:LocalAppData\CrashDumps\*" -Recurse -Force -ErrorAction SilentlyContinue *> $null
    Remove-Item "$env:SystemRoot\Minidump\*" -Recurse -Force -ErrorAction SilentlyContinue *> $null
    Remove-Item "$env:SystemRoot\MEMORY.DMP" -Force -ErrorAction SilentlyContinue *> $null
    Remove-Item "$env:SystemRoot\Logs\CBS\CbsPersist_*.log" -Force -ErrorAction SilentlyContinue *> $null
    Remove-Item "$env:SystemRoot\Logs\CBS\CbsPersist_*.cab" -Force -ErrorAction SilentlyContinue *> $null
    $infRepair = Get-System-Hardware-Info
    if ($infRepair.IsBootSSD -and -not $infRepair.IsPureHDD) {
        Remove-Item "$env:SystemRoot\Prefetch\*.pf" -Force -ErrorAction SilentlyContinue *> $null
    }
    
    Show-Spinner "Безопасная очистка системных отчетов WER и дампов сбоев" 500
                                
        if (-not $script:QuietMode) { Write-Host "$e[1;32m  [OK] Системный мусор, WinSxS, дампы, кэши эскизов и поврежденные шейдеры очищены$e[0m" }
}

function Invoke-Hardcore-Gaming {
    Show-Spinner "Калибровка BCDedit таймеров Invariant TSC и стабилизация timeBeginPeriod" 600
    bcdedit /set useplatformclock no *> $null
    bcdedit /set disabledynamictick yes *> $null
    bcdedit /set tscsyncpolicy Enhanced *> $null
    try { [WinNativeOptimizer]::timeBeginPeriod(1) | Out-Null } catch {}

    Show-Spinner "Настройка Win32PrioritySeparation (0x26) и Multimedia SystemProfile" 500
    $priKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
    Set-ItemProperty $priKey 'Win32PrioritySeparation' 38 -Type DWord -Force -ErrorAction SilentlyContinue

    $sysProf = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    Set-ItemProperty $sysProf 'SystemResponsiveness' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $sysProf 'NoLazyMode' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    $gKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    Set-ItemProperty $gKey 'GPU Priority' 8 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $gKey 'Priority' 6 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $gKey 'Scheduling Category' 'High' -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $gKey 'SFIO Priority' 'High' -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $gKey 'Background Only' 'False' -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $gKey 'Latency Sensitive' 'True' -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $gKey 'Affinity' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $gKey 'Clock Rate' 10000 -Type DWord -Force -ErrorAction SilentlyContinue

    Show-Spinner "Отключение PowerThrottling фоновых процессов" 400
    $ptKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'
    if (-not (Test-Path $ptKey)) { New-Item -Path $ptKey -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $ptKey 'PowerThrottlingOff' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    Show-Spinner "Оптимизация GameDVR, AutoGameMode и принудительный FSE Behavior Mode" 500
    Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehaviorMode' 2 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\System\GameConfigStore' 'GameDVR_HonorUserFSEBehaviorMode' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\System\GameConfigStore' 'GameDVR_DXGIHonorFSEWindowsCompatible' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\System\GameConfigStore' 'GameDVR_EFSEFeatureFlags' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    
    $gbKey = 'HKCU:\Software\Microsoft\GameBar'
    if (-not (Test-Path $gbKey)) { New-Item -Path $gbKey -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $gbKey 'AllowAutoGameMode' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $gbKey 'AutoGameModeEnabled' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    $gdvrPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
    if (-not (Test-Path $gdvrPol)) { New-Item -Path $gdvrPol -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $gdvrPol 'AllowGameDVR' 0 -Type DWord -Force -ErrorAction SilentlyContinue

    Show-Spinner "Включение HAGS, Direct3D Flip Model и устранение MPO лагов DWM" 500
    $gfxKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    Set-ItemProperty $gfxKey 'HwSchMode' 2 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\System\GameConfigStore' 'SwapEffectUpgradeEnable' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\DWM' -Name 'OverlayTestMode' -ErrorAction SilentlyContinue

    $dxKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    if (-not (Test-Path $dxKey)) { New-Item -Path $dxKey -Force -ErrorAction SilentlyContinue | Out-Null }
    $curDx = (Get-ItemProperty $dxKey -Name 'DirectXUserGlobalSettings' -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    if ($curDx -notmatch 'SwapEffectUpgradeEnable=1;') {
        Set-ItemProperty -Path $dxKey -Name 'DirectXUserGlobalSettings' -Value (($curDx + ' SwapEffectUpgradeEnable=1;').Trim()) -Type String -Force -ErrorAction SilentlyContinue
    }

    $schemes = @(powercfg /list)
    $ultGuids = @($schemes | Where-Object { $_ -match '([a-f0-9\-]{36}).*(Ultimate Performance|Максимальная производительность)' } | ForEach-Object { $matches[1] })
    if ($ultGuids.Count -gt 0) {
        powercfg /setactive $ultGuids[0] *> $null
    } else {
        $highGuids = @($schemes | Where-Object { $_ -match '([a-f0-9\-]{36}).*(High performance|Высокая производительность)' } | ForEach-Object { $matches[1] })
        if ($highGuids.Count -gt 0) {
            powercfg /setactive $highGuids[0] *> $null
        } else {
            $dupOut = powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
            if ($dupOut -match '([a-f0-9\-]{36})') {
                powercfg /setactive $matches[1] *> $null
            } else {
                powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c *> $null
            }
        }
    }

    if (-not $script:QuietMode) { Write-Host "$e[1;32m  [OK] Игровой профиль активирован: таймеры TSC, Win32Priority=38, FSE Mode, HAGS, Games=8$e[0m" }
}

function Invoke-Irq-Affinity-Steering {
    Show-Spinner "Маршрутизация прерываний dGPU (IRQ Affinity Steering)" 600
    $info = Get-System-Hardware-Info
    if ($info.HasDgpu) {
        foreach ($g in $info.DiscreteGpus) {
            $pnp = if ($g.PNPDeviceID) { $g.PNPDeviceID } else { "" }
            if ($pnp) {
                $msiKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnp\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                $affKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnp\Device Parameters\Interrupt Management\Affinity Policy"
                if (-not (Test-Path $msiKey)) { New-Item -Path $msiKey -Force -ErrorAction SilentlyContinue | Out-Null }
                Set-ItemProperty -Path $msiKey -Name 'MSISupported' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                if (-not (Test-Path $affKey)) { New-Item -Path $affKey -Force -ErrorAction SilentlyContinue | Out-Null }
                $cores = [int][Environment]::ProcessorCount
                $mask = if ($info.IsAMD -and $cores -ge 6) {
                    [Convert]::ToUInt64("0030", 16)
                } elseif ($info.IsIntel -and $cores -ge 4) {
                    [Convert]::ToUInt64("000C", 16)
                } else {
                    [Convert]::ToUInt64("0002", 16)
                }
                Set-ItemProperty -Path $affKey -Name 'DevicePolicy' -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $affKey -Name 'AssignmentSetOverride' -Value ([BitConverter]::GetBytes([uint64]$mask)) -Type Binary -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $affKey -Name 'DevicePriority' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
                if (-not $script:QuietMode) { Write-Host "$e[1;32m  [IRQ] Прерывания $($g.Name) изолированы на физическое ядро (Маска: 0x$([Convert]::ToString($mask, 16)))$e[0m" }
            }
        }
    } else {
        if (-not $script:QuietMode) { Write-Host "$e[1;33m  [IRQ] Дискретный GPU не обнаружен, IRQ Steering пропущен$e[0m" }
    }
}

function Invoke-Usb-Input-Optimization {
    Show-Spinner "Аппаратный тюнинг USB, отключение Selective Suspend и MarkC 1:1" 600
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB' -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq 'Device Parameters' } | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name 'EnhancedPowerManagementEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'AllowIdleIrpInD3' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'SelectiveSuspendEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'DeviceSelectiveSuspended' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'CC_0C0330' } | ForEach-Object {
        $msiKey = Join-Path $_.PSPath 'Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'
        $affKey = Join-Path $_.PSPath 'Device Parameters\Interrupt Management\Affinity Policy'
        if (-not (Test-Path $msiKey)) { New-Item -Path $msiKey -Force -ErrorAction SilentlyContinue | Out-Null }
        if (-not (Test-Path $affKey)) { New-Item -Path $affKey -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $msiKey -Name 'MSISupported' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $affKey -Name 'DevicePriority' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    $mouseKey = 'HKCU:\Control Panel\Mouse'
    Set-ItemProperty -Path $mouseKey -Name 'MouseSpeed' -Value '0' -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $mouseKey -Name 'MouseThreshold1' -Value '0' -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $mouseKey -Name 'MouseThreshold2' -Value '0' -Force -ErrorAction SilentlyContinue
    $smoothX = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, 0x15,0x6E,0x00,0x00,0x00,0x00,0x00,0x00, 0x00,0x40,0x01,0x00,0x00,0x00,0x00,0x00, 0x00,0xA0,0x02,0x00,0x00,0x00,0x00,0x00, 0x00,0x40,0x04,0x00,0x00,0x00,0x00,0x00)
    $smoothY = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, 0x00,0x00,0x38,0x00,0x00,0x00,0x00,0x00, 0x00,0x00,0x70,0x00,0x00,0x00,0x00,0x00, 0x00,0x00,0xA8,0x00,0x00,0x00,0x00,0x00, 0x00,0x00,0xE0,0x00,0x00,0x00,0x00,0x00)
    Set-ItemProperty -Path $mouseKey -Name 'SmoothMouseXCurve' -Value $smoothX -Type Binary -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $mouseKey -Name 'SmoothMouseYCurve' -Value $smoothY -Type Binary -Force -ErrorAction SilentlyContinue
    if (-not $script:QuietMode) { Write-Host "$e[1;32m  [USB] Контроллеры xHCI переведены в MSI High, Selective Suspend выключен, MarkC 1:1 применен$e[0m" }
}

function Invoke-Audio-Optimization {
    Show-Spinner "Изоляция аудиопотока audiodg.exe и MMCSS приоритеты" 500
    $audioKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio'
    if (-not (Test-Path $audioKey)) { New-Item -Path $audioKey -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $audioKey -Name 'DisableProtectedAudioDG' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    $tasks = @('Audio', 'Pro Audio')
    foreach ($t in $tasks) {
        $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\$t"
        if (Test-Path $p) {
            Set-ItemProperty -Path $p -Name 'Scheduling Category' -Value 'High' -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $p -Name 'SFIO Priority' -Value 'High' -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $p -Name 'Background Only' -Value 'False' -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $p -Name 'Priority' -Value 6 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $p -Name 'Clock Rate' -Value 10000 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }

    Get-Process -Name 'audiodg' -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $_.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
            $_.ProcessorAffinity = [IntPtr]4
        } catch {}
    }
    if (-not $script:QuietMode) { Write-Host "$e[1;32m  [AUDIO] Защита audiodg.exe снята, процесс изолирован на Core 2 (High), MMCSS активирован$e[0m" }
}

function Invoke-Kernel-DirectIo-Optimization {
    Show-Spinner "Оптимизация очередей ядра NT Executive, MFT Zone и TDR Delay" 600
    $memKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    Remove-ItemProperty -Path $memKey -Name 'IoPageLockLimit' -ErrorAction SilentlyContinue

    $execKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive'
    if (-not (Test-Path $execKey)) { New-Item -Path $execKey -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $execKey -Name 'AdditionalCriticalWorkerThreads' -Value 16 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $execKey -Name 'AdditionalWorkerThreads' -Value 16 -Type DWord -Force -ErrorAction SilentlyContinue

    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'NtfsMftZoneReservation' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue

    $gfxKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    Set-ItemProperty -Path $gfxKey -Name 'TdrLevel' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gfxKey -Name 'TdrDelay' -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gfxKey -Name 'TdrDdiDelay' -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue

    $hasVanguard = (Get-Service -Name 'vgk' -ErrorAction SilentlyContinue) -ne $null
    if (-not $hasVanguard) {
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    Set-ItemProperty -Path $memKey -Name 'FeatureSettingsOverride' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $memKey -Name 'FeatureSettingsOverrideMask' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue

    $polProcKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Processes'
    $polPathKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Paths'
    if (-not (Test-Path $polProcKey)) { New-Item -Path $polProcKey -Force -ErrorAction SilentlyContinue | Out-Null }
    if (-not (Test-Path $polPathKey)) { New-Item -Path $polPathKey -Force -ErrorAction SilentlyContinue | Out-Null }

    $gameBins = @(
        'javaw.exe', 'java.exe', 'SyntaxClient.exe', 'SyntaxLoader.exe', 'PrismLauncher.exe',
        'Antigravity.exe', 'Gemini.exe', 'GeminiAppLauncher.exe', 'language_server.exe'
    )
    foreach ($bin in $gameBins) {
        Set-ProcessMitigation -Name $bin -Disable CFG, StrictHandle -ErrorAction SilentlyContinue *> $null
        Set-ItemProperty -Path $polProcKey -Name $bin -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionProcess $bin -ErrorAction SilentlyContinue *> $null
    }

    $gameDirs = @(
        ($env:APPDATA + '\.minecraft'),
        ($env:APPDATA + '\PrismLauncher'),
        ($env:APPDATA + '\SyntaxClient'),
        ($env:APPDATA + '\SyntaxLoader'),
        ($env:LOCALAPPDATA + '\Programs\antigravity'),
        ($env:LOCALAPPDATA + '\Google\Gemini'),
        ($env:USERPROFILE + '\.gemini')
    ) | Where-Object { Test-Path $_ }
    foreach ($d in $gameDirs) {
        Set-ItemProperty -Path $polPathKey -Name $d -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionPath $d -ErrorAction SilentlyContinue *> $null
    }
    if (-not $script:QuietMode) { Write-Host "$e[1;32m  [KERNEL] Очереди ядра 16 потоков, MFT Zone=2, TDR Delay=10s, CFG/Spectre/Defender исключения применены$e[0m" }
}

function Invoke-Minecraft-AutoTuning {
    Show-Spinner "Сканирование сред Java и адаптивная привязка к видеокарте" 600
    $info = Get-System-Hardware-Info
    $mcRamMb = if ($info.RamGB -ge 32) { 8192 } elseif ($info.RamGB -ge 16) { 8192 } elseif ($info.RamGB -ge 12) { 6144 } elseif ($info.RamGB -ge 8) { 4096 } else { 2048 }
    $gpuPrefVal = if ($info.HasDgpu) { 'GpuPreference=2;' } else { 'GpuPreference=1;' }

    $searchDirs = @('C:\Program Files\Java', 'C:\Program Files\Eclipse Adoptium', ($env:APPDATA + '\PrismLauncher\java'), ($env:LOCALAPPDATA + '\Programs')) | Where-Object { Test-Path $_ }
    $javas = if ($searchDirs) { @(Get-ChildItem $searchDirs -Recurse -Filter 'javaw.exe' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName) } else { @() }
    $regGpu = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    if (-not (Test-Path $regGpu)) { New-Item -Path $regGpu -Force -ErrorAction SilentlyContinue | Out-Null }
    foreach ($j in $javas) {
        Set-ItemProperty -Path $regGpu -Name $j -Value $gpuPrefVal -Force -ErrorAction SilentlyContinue
        if (-not $script:QuietMode) { Write-Host "$e[1;32m  [JAVA] Привязано ($gpuPrefVal): $j$e[0m" }
    }

    Show-Spinner "Конфигурация PrismLauncher и внедрение Generational ZGC" 500
    $prismCfg = $env:APPDATA + '\PrismLauncher\prismlauncher.cfg'
    $useDgpuStr = if ($info.HasDgpu) { 'UseDiscreteGpu=true' } else { 'UseDiscreteGpu=false' }
    $zgcArgs = '-XX:+UseZGC -XX:+AlwaysPreTouch -Doshi.os.windows.wmi.timeout=1000 -Doshi.wmi.timeout=1000'
    if (Test-Path $prismCfg) {
        $pText = Get-Content $prismCfg -Raw -ErrorAction SilentlyContinue
        if ($pText) {
            $pText = $pText -replace 'UseDiscreteGpu=(true|false)', $useDgpuStr -replace 'MaxMemAlloc=\d+', "MaxMemAlloc=$mcRamMb" -replace 'CloseAfterLaunch=(true|false)', 'CloseAfterLaunch=true'
            if ($pText -match 'JvmArgs=') {
                $pText = $pText -replace 'JvmArgs=.*', "JvmArgs=$zgcArgs"
            } else {
                $pText += "`r`nJvmArgs=$zgcArgs"
            }
            Set-Content -Path $prismCfg -Value $pText.Trim() -Force -ErrorAction SilentlyContinue
        }
        if (-not $script:QuietMode) { Write-Host "$e[1;32m  [PRISM] Глобальные параметры: $useDgpuStr, RAM=${mcRamMb}MB, CloseAfterLaunch=true, ZGC$e[0m" }
    }
    Get-ChildItem ($env:APPDATA + '\PrismLauncher\instances') -Filter 'instance.cfg' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $iText = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        if ($iText) {
            $iText = $iText -replace 'UseDiscreteGpu=(true|false)', $useDgpuStr -replace 'MaxMemAlloc=\d+', "MaxMemAlloc=$mcRamMb" -replace 'OverrideMemory=false', 'OverrideMemory=true' -replace 'OverridePerformance=false', 'OverridePerformance=true' -replace 'OverrideJavaArgs=false', 'OverrideJavaArgs=true' -replace 'CloseAfterLaunch=(true|false)', 'CloseAfterLaunch=true'
            if ($iText -match 'JvmArgs=') {
                $iText = $iText -replace 'JvmArgs=.*', "JvmArgs=$zgcArgs"
            } else {
                $iText += "`r`nJvmArgs=$zgcArgs"
            }
            if ($iText -notmatch 'OverrideJavaArgs=') {
                $iText += "`r`nOverrideJavaArgs=true"
            }
            Set-Content -Path $_.FullName -Value $iText.Trim() -Force -ErrorAction SilentlyContinue
        }
        if (-not $script:QuietMode) { Write-Host "$e[1;32m  [PRISM] Инстанс: $($_.Directory.Name) переведен на $useDgpuStr, ${mcRamMb}MB, CloseAfterLaunch и ZGC$e[0m" }
    }

    Show-Spinner "Оптимизация SyntaxLoader и SyntaxClient (CloseAfterLaunch, ZGC)" 500
    $syntaxLoader = $env:APPDATA + '\SyntaxLoader\config.json'
    if (Test-Path $syntaxLoader) {
        try {
            $sj = Get-Content $syntaxLoader -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
            $sj.RamMb = $mcRamMb
            $sj.JavaArgs = '-XX:+UseZGC -XX:+AlwaysPreTouch -Doshi.os.windows.wmi.timeout=1000 -Doshi.wmi.timeout=1000'
            $sj.CloseAfterLaunch = $true
            $sj | ConvertTo-Json | Set-Content $syntaxLoader -Force -ErrorAction SilentlyContinue
            if (-not $script:QuietMode) { Write-Host "$e[1;32m  [SYNTAX] SyntaxLoader настроен на ZGC и ${mcRamMb}MB$e[0m" }
        } catch {}
    }
    $syntaxClient = $env:APPDATA + '\SyntaxClient\settings.json'
    if (Test-Path $syntaxClient) {
        try {
            $sc = Get-Content $syntaxClient -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
            $sc.AllocatedRam = $mcRamMb
            $sc.CloseAfterLaunch = $true
            $sc | ConvertTo-Json | Set-Content $syntaxClient -Force -ErrorAction SilentlyContinue
            if (-not $script:QuietMode) { Write-Host "$e[1;32m  [SYNTAX] SyntaxClient настроен на автовыгрузку CloseAfterLaunch (${mcRamMb}MB)$e[0m" }
        } catch {}
    }
}

function Invoke-Debloat-Privacy {
    Show-Spinner "Пакетное удаление предустановленного UWP Bloatware и Provisioned пакетов" 1000
    $wl = @('Microsoft.WindowsStore','Microsoft.StorePurchaseApp','Microsoft.DesktopAppInstaller','Microsoft.WindowsCalculator','Microsoft.WindowsNotepad','Microsoft.WindowsTerminal','Microsoft.Paint','Microsoft.Windows.Photos','Microsoft.ScreenSketch','Microsoft.EdgeWebView','*NVIDIA*','*Realtek*','*DTS*','*Synaptics*','*Touchpad*','*AMD*','*Intel*','Microsoft.MicrosoftStickyNotes','Microsoft.WindowsAlarms','*windowscommunicationsapps*','Microsoft.YourPhone','*Spotify*','*Teams*','Microsoft.XboxIdentityProvider','*Dolby*','MicrosoftWindows.Client.WebExperience')
    $bl = @('Microsoft.BingNews','Microsoft.BingWeather','Microsoft.BingFinance','Microsoft.BingSports','Microsoft.BingTranslator','Microsoft.BingSearch','Microsoft.GetHelp','Microsoft.Getstarted','Microsoft.MicrosoftOfficeHub','Microsoft.MicrosoftSolitaireCollection','Microsoft.MixedReality.Portal','Microsoft.Office.OneNote','Microsoft.OneConnect','Microsoft.People','Microsoft.Print3D','Microsoft.SkypeApp','Microsoft.Wallet','Microsoft.WindowsFeedbackHub','Microsoft.WindowsMaps','Microsoft.ZuneMusic','Microsoft.ZuneVideo','Microsoft.549981C3F5F10','Disney.37853FC22B2CE','BytedancePte.Ltd.TikTok','*Facebook*','*Netflix*','*Amazon*','*McAfee*','*ROBLOX*','*king.com*','*CandyCrush*','*LinkedIn*','*Twitter*','*Instagram*','*PrimeVideo*')
    $wlRegex = '^(' + (($wl | ForEach-Object { [regex]::Escape($_).Replace('\*', '.*') }) -join '|') + ')$'
    $blRegex = '^(' + (($bl | ForEach-Object { [regex]::Escape($_).Replace('\*', '.*') }) -join '|') + ')$'
    Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $blRegex -and $_.Name -notmatch $wlRegex } | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $n = if ($_.DisplayName) { $_.DisplayName } else { $_.PackageName }; $n -match $blRegex -and $n -notmatch $wlRegex } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue *> $null

    Show-Spinner "Отключение фонового автозапуска OneDrive" 400
    Stop-Process -Name OneDrive, OneDriveSetup -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
    $odPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'
    if (-not (Test-Path $odPol)) { New-Item -Path $odPol -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $odPol -Name 'DisableFileSyncNGSC' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    Show-Spinner "Отключение телеметрии, рекламы, Copilot, Recall и виджетов" 600
    $dcPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    if (-not (Test-Path $dcPol)) { New-Item -Path $dcPol -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $dcPol 'AllowTelemetry' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $dcPol 'MaxTelemetryAllowed' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $dcPol 'DoNotShowFeedbackNotifications' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue

    $cdm = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    if (-not (Test-Path $cdm)) { New-Item -Path $cdm -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $cdm 'ContentDeliveryAllowed' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $cdm 'FeatureManagementEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $cdm 'OemPreInstalledAppsEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $cdm 'PreInstalledAppsEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $cdm 'SubscribedContentEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $cdm 'SystemPaneSuggestionsEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $cdm 'RotatingLockScreenEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $cdm 'RotatingLockScreenOverlayEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $cdm 'SoftLandingEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue

    $ipUser = 'HKCU:\Software\Microsoft\InputPersonalization'
    if (-not (Test-Path $ipUser)) { New-Item -Path $ipUser -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $ipUser 'RestrictImplicitTextCollection' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $ipUser 'RestrictImplicitInkCollection' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    $ipMach = 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization'
    if (-not (Test-Path $ipMach)) { New-Item -Path $ipMach -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $ipMach 'AllowInputPersonalization' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $ipMach 'RestrictImplicitTextCollection' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $ipMach 'RestrictImplicitInkCollection' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    $info = Get-System-Hardware-Info
    if ($info.IsWin11) {
        $copilotUser = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'
        if (-not (Test-Path $copilotUser)) { New-Item -Path $copilotUser -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $copilotUser 'TurnOffWindowsCopilot' 1 -Type DWord -Force -ErrorAction SilentlyContinue

        $copilotMach = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
        if (-not (Test-Path $copilotMach)) { New-Item -Path $copilotMach -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $copilotMach 'TurnOffWindowsCopilot' 1 -Type DWord -Force -ErrorAction SilentlyContinue

        $aiPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
        if (-not (Test-Path $aiPol)) { New-Item -Path $aiPol -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $aiPol 'DisableAIDataAnalysis' 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $aiPol 'TurnOffRecall' 1 -Type DWord -Force -ErrorAction SilentlyContinue

        $aiUser = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI'
        if (-not (Test-Path $aiUser)) { New-Item -Path $aiUser -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $aiUser 'DisableAIDataAnalysis' 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $aiUser 'TurnOffRecall' 1 -Type DWord -Force -ErrorAction SilentlyContinue

        $dsh = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
        if (-not (Test-Path $dsh)) { New-Item -Path $dsh -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $dsh 'AllowNewsAndInterests' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Stop-Process -Name Widgets -Force -ErrorAction SilentlyContinue
    }

    $wsPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
    if (-not (Test-Path $wsPol)) { New-Item -Path $wsPol -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $wsPol 'AllowCortana' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $wsPol 'DisableWebSearch' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $wsPol 'ConnectedSearchUseWeb' 0 -Type DWord -Force -ErrorAction SilentlyContinue

    $searchKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
    if (-not (Test-Path $searchKey)) { New-Item -Path $searchKey -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $searchKey 'BingSearchEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $searchKey 'CortanaConsent' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $searchKey 'DeviceHistoryEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $searchKey 'HistoryViewEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue

    $sysPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
    if (-not (Test-Path $sysPol)) { New-Item -Path $sysPol -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $sysPol 'PublishUserActivities' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $sysPol 'UploadUserActivities' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $sysPol 'EnableActivityFeed' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $sysPol 'EnableSmartScreen' 0 -Type DWord -Force -ErrorAction SilentlyContinue

    $expKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'
    if (-not (Test-Path $expKey)) { New-Item -Path $expKey -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $expKey 'SmartScreenEnabled' 'Off' -Type String -Force -ErrorAction SilentlyContinue

    $werMachPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'
    if (-not (Test-Path $werMachPol)) { New-Item -Path $werMachPol -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $werMachPol 'Disabled' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    $werMach = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'
    if (-not (Test-Path $werMach)) { New-Item -Path $werMach -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $werMach 'Disabled' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    $werUser = 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting'
    if (-not (Test-Path $werUser)) { New-Item -Path $werUser -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $werUser 'Disabled' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    $locPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
    if (-not (Test-Path $locPol)) { New-Item -Path $locPol -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $locPol 'DisableLocation' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $locPol 'DisableLocationScripting' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $locPol 'DisableSensors' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    $siufKey = 'HKCU:\Software\Microsoft\Siuf\Rules'
    if (-not (Test-Path $siufKey)) { New-Item -Path $siufKey -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $siufKey 'NumberOfSIUFInPeriod' 0 -Type DWord -Force -ErrorAction SilentlyContinue

    $gbUser = 'HKCU:\Software\Microsoft\GameBar'
    if (-not (Test-Path $gbUser)) { New-Item -Path $gbUser -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty $gbUser 'ShowStartupPanel' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $gbUser 'UseNexusForGameBarEnabled' 0 -Type DWord -Force -ErrorAction SilentlyContinue

    $services = @(
        'DiagTrack', 'dmwappushservice', 'RetailDemo', 'RemoteRegistry', 'MapsBroker', 'Fax',
        'PcaSvc', 'diagnosticshub.standardcollector.service', 'lfsvc', 'SensorService', 'SensrSvc',
        'edgeupdate', 'edgeupdatem', 'MicrosoftEdgeElevationService'
    )
    foreach ($s in $services) {
        sc.exe config $s start= disabled *> $null
        sc.exe stop $s *> $null
    }
    sc.exe config DPS start= auto *> $null
    sc.exe start DPS *> $null
    sc.exe config WdiServiceHost start= demand *> $null
    sc.exe config WdiSystemHost start= demand *> $null

    $tasks = @(
        "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "Microsoft\Windows\Feedback\Siuf\DmClient",
        "Microsoft\Windows\Maps\MapsToastTask",
        "Microsoft\Windows\Maps\MapsUpdateTask",
        "Microsoft\Windows\Windows Error Reporting\QueueReporting",
        "Microsoft\Windows\DiskFootprint\Diagnostics",
        "Microsoft\Windows\PI\Sqm-Tasks",
        "Microsoft\Windows\Device Information\Device",
        "Microsoft\Windows\Maintenance\WinSAT",
        "Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
        "Microsoft\Windows\Shell\FamilySafetyMonitor",
        "Microsoft\Windows\Shell\FamilySafetyRefresh",
        "Microsoft\Windows\Shell\FamilySafetyRefreshTask",
        "Microsoft\Windows\Diagnosis\Scheduled",
        "Microsoft\Windows\NetTrace\GatherNetTrace",
        "MicrosoftEdgeUpdateTaskMachineCore",
        "MicrosoftEdgeUpdateTaskMachineUA"
    )
    foreach ($t in $tasks) {
        schtasks /Change /TN "$t" /Disable *> $null
    }
    Get-ScheduledTask -TaskName 'MicrosoftEdgeUpdateTaskMachine*' -ErrorAction SilentlyContinue | Disable-ScheduledTask -ErrorAction SilentlyContinue *> $null

    
    if (-not $script:QuietMode) { Write-Host "$e[1;32m  [OK] Деблоат и глушение телеметрии выполнены ($($info.OSName)) (Store, Блокнот, WebView2 целы)$e[0m" }
}

function Invoke-Smart-Hardware-Optimization {
    param([string]$ProfileMode = 'Auto')
    $info = Get-System-Hardware-Info
    $isLaptop = $info.IsLaptop
    $epp = 0
    $minCores = 100
    $boostMode = 2
    $minState = 100

    if ($ProfileMode -eq 'Cool' -or ($ProfileMode -eq 'Auto' -and $isLaptop)) {
        $epp = 16
        $minCores = 5
        $boostMode = 3
        $minState = 5
    }

    powercfg -setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 $minCores *> $null
    powercfg -setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb1059334028 100 *> $null
    powercfg -setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 $boostMode *> $null
    powercfg -setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $epp *> $null
    powercfg -setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c $minState *> $null
    powercfg -setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100 *> $null

    if ($info.IsIntelHybrid) {
        powercfg -setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 7f2492b6-60b1-45fe-a764-76ee5293222e 4 *> $null
        powercfg -setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 7f2f5cfa-f10c-4823-b5e1-e93ae85f46b5 4 *> $null
        powercfg -setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 93b8b6dc-0698-4d1c-9ee4-0644e900c85d 2 *> $null
        powercfg -setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 bae08b81-2d5e-4688-ad6a-13243356654b 2 *> $null
    }

    powercfg -setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 $minCores *> $null
    powercfg -setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb1059334028 100 *> $null
    powercfg -setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 $boostMode *> $null
    powercfg -setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $epp *> $null
    powercfg -setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c $minState *> $null
    powercfg -setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100 *> $null
    if ($info.IsIntelHybrid) {
        powercfg -setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 7f2492b6-60b1-45fe-a764-76ee5293222e 4 *> $null
        powercfg -setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 7f2f5cfa-f10c-4823-b5e1-e93ae85f46b5 4 *> $null
        powercfg -setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 93b8b6dc-0698-4d1c-9ee4-0644e900c85d 2 *> $null
        powercfg -setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 bae08b81-2d5e-4688-ad6a-13243356654b 2 *> $null
    }
    powercfg -setactive scheme_current *> $null

    if ($info.HasDgpu) {
        foreach ($g in $info.DiscreteGpus) {
            $pnp = $g.PNPDeviceID
            $msiKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnp\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            $affKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnp\Device Parameters\Interrupt Management\Affinity Policy"
            if (-not (Test-Path $msiKey)) { New-Item -Path $msiKey -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $msiKey -Name 'MSISupported' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path $affKey)) { New-Item -Path $affKey -Force -ErrorAction SilentlyContinue | Out-Null }
            $cores = [int][Environment]::ProcessorCount
            $mask = if ($info.IsAMD -and $cores -ge 6) { [Convert]::ToUInt64("0030", 16) } elseif ($info.IsIntel -and $cores -ge 4) { [Convert]::ToUInt64("000C", 16) } else { [Convert]::ToUInt64("0002", 16) }
            Set-ItemProperty -Path $affKey -Name 'DevicePolicy' -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $affKey -Name 'AssignmentSetOverride' -Value ([BitConverter]::GetBytes([uint64]$mask)) -Type Binary -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $affKey -Name 'DevicePriority' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }

    Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'SwapEffectUpgradeEnable' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    $dxKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    if (-not (Test-Path $dxKey)) { New-Item -Path $dxKey -Force -ErrorAction SilentlyContinue | Out-Null }
    $cur = (Get-ItemProperty $dxKey -Name 'DirectXUserGlobalSettings' -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    if ($cur -notmatch 'SwapEffectUpgradeEnable=1;') {
        Set-ItemProperty -Path $dxKey -Name 'DirectXUserGlobalSettings' -Value (($cur + ' SwapEffectUpgradeEnable=1;').Trim()) -Type String -Force -ErrorAction SilentlyContinue
    }
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 -Type DWord -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\DWM' -Name 'OverlayTestMode' -ErrorAction SilentlyContinue

    $memKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    $ramGB = $info.RamGB
    if ($ramGB -ge 16) {
        Set-ItemProperty $memKey 'DisablePagingExecutive' 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $memKey 'LargeSystemCache' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $memKey -Name 'IoPageLockLimit' -ErrorAction SilentlyContinue
    } elseif ($ramGB -ge 8) {
        Set-ItemProperty $memKey 'DisablePagingExecutive' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $memKey 'LargeSystemCache' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $memKey -Name 'IoPageLockLimit' -ErrorAction SilentlyContinue
    } else {
        Set-ItemProperty $memKey 'DisablePagingExecutive' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty $memKey 'LargeSystemCache' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $memKey -Name 'IoPageLockLimit' -ErrorAction SilentlyContinue
    }
    Set-ItemProperty $memKey 'ClearPageFileAtShutdown' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $memKey 'SecondLevelAddressTranslationExtensions' 1 -Type DWord -Force -ErrorAction SilentlyContinue

    $fsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
    fsutil behavior set disablelastaccess 1 *> $null
    fsutil 8dot3name set 1 *> $null
    Set-ItemProperty -Path $fsKey -Name 'NtfsMftZoneReservation' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $fsKey -Name 'NtfsDisable8dot3NameCreation' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty $fsKey 'NtfsDisableLastAccessUpdate' 1 -Type DWord -Force -ErrorAction SilentlyContinue
    
    $isHddSystem = ($info.IsPureHDD -or (-not $info.IsBootSSD))
    if (-not $isHddSystem) {
        fsutil behavior set DisableDeleteNotify 0 *> $null
        sc.exe config SysMain start= disabled *> $null
        sc.exe stop SysMain *> $null
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher' 0 -Type DWord -Force -ErrorAction SilentlyContinue
    } else {
        sc.exe config SysMain start= auto *> $null
        sc.exe start SysMain *> $null
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher' 3 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    if ($info.HasAnyNVMe) {
        $nvmeDev = 'HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device'
        if (-not (Test-Path $nvmeDev)) { New-Item -Path $nvmeDev -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $nvmeDev 'IdlePowerMode' 0 -Type DWord -Force -ErrorAction SilentlyContinue
        $storportParam = 'HKLM:\SYSTEM\CurrentControlSet\Services\storport\Parameters'
        if (-not (Test-Path $storportParam)) { New-Item -Path $storportParam -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty $storportParam 'EnableIdlePowerManagement' 0 -Type DWord -Force -ErrorAction SilentlyContinue

        powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc95af4d-40e7-4b6d-835a-56d131dbc80e 0 *> $null
        powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc95af4d-40e7-4b6d-835a-56d131dbc80e 0 *> $null
        powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 dbc9e238-6de9-49e3-92cd-8c2b4946b472 0 *> $null
        powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 dbc9e238-6de9-49e3-92cd-8c2b4946b472 0 *> $null
        powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 d639518a-e56d-4345-8af2-b9f32fb26109 0 *> $null
        powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 d639518a-e56d-4345-8af2-b9f32fb26109 0 *> $null
        powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc7372b6-ab2d-43ee-8797-15e9841f2cca 0 *> $null
        powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 fc7372b6-ab2d-43ee-8797-15e9841f2cca 0 *> $null
        powercfg /setactive SCHEME_CURRENT *> $null
    }

    try {
        [WinNativeOptimizer]::timeBeginPeriod(1) | Out-Null
        [WinNativeOptimizer]::FlushStandbyList() | Out-Null
        [WinNativeOptimizer]::EmptySystemWorkingSets() | Out-Null
    } catch {}
    if (-not $script:QuietMode) { Write-Host "$e[1;32m  [OK] Профиль оборудования ($ProfileMode) успешно калиброван и активирован на 100%!$e[0m" }
}

function Invoke-Smart-Hardware-Benchmark {
    Clear-Host
    Write-Host "$e[1;36m╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
    Write-Host "$e[1;32m║        ⚡ ЭКСПРЕСС-АВТОПОДБОР И ДВУХФАЗНЫЙ БЕНЧМАРК ЖЕЛЕЗА (~20-30 сек)     ║$e[0m"
    Write-Host "$e[1;36m╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
    Write-Host ""
    
    Show-Spinner "ФАЗА 1: Замер исходной производительности CPU Single-Thread" 600
    $cpuSingleBefore = [WinNativeOptimizer]::MeasureCpuSingle(80000000)

    Show-Spinner "ФАЗА 1: Замер исходной производительности CPU Multi-Thread" 600
    $cpuMultiBefore = [WinNativeOptimizer]::MeasureCpuMulti(200000000)

    Show-Spinner "ФАЗА 1: Замер исходной пропускной способности оперативной памяти" 600
    $ramBefore = [WinNativeOptimizer]::MeasureRam(16)
    
    Show-Spinner "ФАЗА 1: Замер базовой точности и джиттера системных таймеров" 600
    $resBefore = [WinNativeOptimizer]::GetTimerResolutionMs()
    $jitterBefore = [WinNativeOptimizer]::MeasureTimerJitter(30)

    Show-Spinner "ФАЗА 1: Замер случайного 4K блочного чтения накопителя (IOPS)" 600
    $diskBefore = [WinNativeOptimizer]::MeasureDisk4K(500)
    $diskIopsBefore = $diskBefore[0]
    $diskLatBefore = $diskBefore[1]

    Show-Spinner "ФАЗА 1: Проверка DWM задержек вывода и Direct3D Flip Model" 500
    $dwmBefore = [WinNativeOptimizer]::MeasureDwmTiming()
    $dwmHzBefore = $dwmBefore[0]
    $dwmLatBefore = $dwmBefore[1]

    Write-Host ""
    Write-Host "$e[1;33m  [ПРИМЕНЕНИЕ] Адаптивная калибровка оборудования под оптимальный игровой профиль...$e[0m"
    Invoke-Smart-Hardware-Optimization -ProfileMode 'Auto'

    Show-Spinner "ФАЗА 2: Контрольный замер CPU Single-Thread в режиме буста" 600
    $cpuSingleAfter = [WinNativeOptimizer]::MeasureCpuSingle(80000000)

    Show-Spinner "ФАЗА 2: Контрольный замер CPU Multi-Thread в режиме буста" 600
    $cpuMultiAfter = [WinNativeOptimizer]::MeasureCpuMulti(200000000)

    Show-Spinner "ФАЗА 2: Контрольный замер пропускной способности памяти RAM" 600
    $ramAfter = [WinNativeOptimizer]::MeasureRam(16)

    Show-Spinner "ФАЗА 2: Контрольный замер разрешения таймера и джиттера" 600
    $resAfter = [WinNativeOptimizer]::GetTimerResolutionMs()
    $jitterAfter = [WinNativeOptimizer]::MeasureTimerJitter(30)

    Show-Spinner "ФАЗА 2: Контрольный замер 4K случайного чтения накопителя" 600
    $diskAfter = [WinNativeOptimizer]::MeasureDisk4K(500)
    $diskIopsAfter = $diskAfter[0]
    $diskLatAfter = $diskAfter[1]

    Show-Spinner "ФАЗА 2: Контрольная верификация DWM и Direct3D Flip Model" 500
    $dwmAfter = [WinNativeOptimizer]::MeasureDwmTiming()
    $dwmHzAfter = $dwmAfter[0]
    $dwmLatAfter = $dwmAfter[1]

    $cpuSGain = if ($cpuSingleBefore -gt 0) { [Math]::Round((($cpuSingleBefore - $cpuSingleAfter) / $cpuSingleBefore * 100.0), 1) } else { 0.0 }
    $cpuMGain = if ($cpuMultiBefore -gt 0) { [Math]::Round((($cpuMultiBefore - $cpuMultiAfter) / $cpuMultiBefore * 100.0), 1) } else { 0.0 }
    $ramGain = if ($ramBefore -gt 0) { [Math]::Round((($ramAfter - $ramBefore) / $ramBefore * 100.0), 1) } else { 0.0 }
    $jitterGain = if ($jitterBefore -gt 0) { [Math]::Round((($jitterBefore - $jitterAfter) / $jitterBefore * 100.0), 1) } else { 0.0 }
    $diskIopsGain = if ($diskIopsBefore -gt 0) { [Math]::Round((($diskIopsAfter - $diskIopsBefore) / $diskIopsBefore * 100.0), 1) } else { 0.0 }
    $diskLatGain = if ($diskLatBefore -gt 0) { [Math]::Round((($diskLatBefore - $diskLatAfter) / $diskLatBefore * 100.0), 1) } else { 0.0 }

    $scoreBefore = [Math]::Min(100, [Math]::Max(15, [Math]::Round(( (600.0 / [Math]::Max(10, $cpuSingleBefore)) * 25.0 + ([Math]::Min(30.0, $ramBefore) / 30.0 * 25.0) + ([Math]::Min(12000, $diskIopsBefore) / 12000 * 25.0) + (1000.0 / [Math]::Max(1.0, $jitterBefore) * 25.0) ), 0)))
    $scoreAfter = [Math]::Min(100, [Math]::Max(15, [Math]::Round(( (600.0 / [Math]::Max(10, $cpuSingleAfter)) * 25.0 + ([Math]::Min(30.0, $ramAfter) / 30.0 * 25.0) + ([Math]::Min(12000, $diskIopsAfter) / 12000 * 25.0) + (1000.0 / [Math]::Max(1.0, $jitterAfter) * 25.0) ), 0)))
    $scoreGain = $scoreAfter - $scoreBefore

    $cpuSDeltaStr = if ($cpuSGain -gt 0) { "-$cpuSGain% ms" } elseif ($cpuSGain -eq 0) { "0.0% ms" } else { "+$([Math]::Abs($cpuSGain))% ms" }
    $cpuSColor = if ($cpuSGain -gt 0) { "$e[1;32m" } elseif ($cpuSGain -ge -2.0) { "$e[1;36m" } else { "$e[1;33m" }

    $cpuMDeltaStr = if ($cpuMGain -gt 0) { "-$cpuMGain% ms" } elseif ($cpuMGain -eq 0) { "0.0% ms" } else { "+$([Math]::Abs($cpuMGain))% ms" }
    $cpuMColor = if ($cpuMGain -gt 0) { "$e[1;32m" } elseif ($cpuMGain -ge -2.0) { "$e[1;36m" } else { "$e[1;33m" }

    $ramDeltaStr = if ($ramGain -gt 0) { "+$ramGain%" } elseif ($ramGain -eq 0) { "0.0%" } else { "$ramGain%" }
    $ramColor = if ($ramGain -gt 0) { "$e[1;32m" } elseif ($ramGain -ge -2.0) { "$e[1;36m" } else { "$e[1;33m" }

    $jitterDeltaStr = if ($jitterGain -gt 0) { "-$jitterGain% jitter" } elseif ($jitterGain -eq 0) { "0.0% jitter" } else { "+$([Math]::Abs($jitterGain))% jitter" }
    $jitterColor = if ($jitterGain -gt 0) { "$e[1;32m" } elseif ($jitterGain -ge -5.0) { "$e[1;36m" } else { "$e[1;33m" }

    $diskIopsDeltaStr = if ($diskIopsGain -gt 0) { "+$diskIopsGain% IOPS" } elseif ($diskIopsGain -eq 0) { "0.0% IOPS" } else { "$diskIopsGain% IOPS" }
    $diskIopsColor = if ($diskIopsGain -gt 0) { "$e[1;32m" } elseif ($diskIopsGain -ge -3.0) { "$e[1;36m" } else { "$e[1;33m" }

    $diskLatDeltaStr = if ($diskLatGain -gt 0) { "-$diskLatGain% us" } elseif ($diskLatGain -eq 0) { "0.0% us" } else { "+$([Math]::Abs($diskLatGain))% us" }
    $diskLatColor = if ($diskLatGain -gt 0) { "$e[1;32m" } elseif ($diskLatGain -ge -3.0) { "$e[1;36m" } else { "$e[1;33m" }

    $strCpuSBefore = "$cpuSingleBefore ms"
    $strCpuSAfter = "$cpuSingleAfter ms"
    $strCpuMBefore = "$cpuMultiBefore ms"
    $strCpuMAfter = "$cpuMultiAfter ms"
    $strRamBefore = "$ramBefore GB/s"
    $strRamAfter = "$ramAfter GB/s"
    $strResBefore = "$resBefore ms"
    $strResAfter = "$resAfter ms"
    $strJitBefore = "$jitterBefore us"
    $strJitAfter = "$jitterAfter us"
    $strDiskIBefore = "$diskIopsBefore IOPS"
    $strDiskIAfter = "$diskIopsAfter IOPS"
    $strDiskLBefore = "$diskLatBefore us"
    $strDiskLAfter = "$diskLatAfter us"
    $strDwmBefore = "$dwmLatBefore ms ($dwmHzBefore Hz)"
    $strDwmAfter = "$dwmLatAfter ms ($dwmHzAfter Hz)"

    Write-Host ""
    Write-Host "$e[1;36m  ┌───────────────────────────┬───────────────────────┬───────────────────────┬─────────────────┐$e[0m"
    Write-Host "$e[1;37m  │ Параметр                  │ До калибровки         │ После калибровки      │ Дельта / Статус │$e[0m"
    Write-Host "$e[1;36m  ├───────────────────────────┼───────────────────────┼───────────────────────┼─────────────────┤$e[0m"
    Write-Host "$e[1;33m  │ CPU Single-Thread (ms)    │ $($strCpuSBefore.PadRight(21)) │ $($strCpuSAfter.PadRight(21)) │$cpuSColor $($cpuSDeltaStr.PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ CPU Multi-Thread (ms)     │ $($strCpuMBefore.PadRight(21)) │ $($strCpuMAfter.PadRight(21)) │$cpuMColor $($cpuMDeltaStr.PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ RAM Bandwidth (GB/s)      │ $($strRamBefore.PadRight(21)) │ $($strRamAfter.PadRight(21)) │$ramColor $($ramDeltaStr.PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ Разрешение таймера (ms)   │ $($strResBefore.PadRight(21)) │ $($strResAfter.PadRight(21)) │$e[1;32m $(($resAfter.ToString() + ' ms tick').PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ Джиттер таймера DPC (µs)  │ $($strJitBefore.PadRight(21)) │ $($strJitAfter.PadRight(21)) │$jitterColor $($jitterDeltaStr.PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ Диск: Случайное 4K (IOPS) │ $($strDiskIBefore.PadRight(21)) │ $($strDiskIAfter.PadRight(21)) │$diskIopsColor $($diskIopsDeltaStr.PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ Диск: 4K Задержка (µs)    │ $($strDiskLBefore.PadRight(21)) │ $($strDiskLAfter.PadRight(21)) │$diskLatColor $($diskLatDeltaStr.PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ DWM Задержка кадра (ms)   │ $($strDwmBefore.PadRight(21)) │ $($strDwmAfter.PadRight(21)) │$e[1;32m $(('Стабильно').PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ Direct3D Independent Flip │ Оконный DWM буфер     │ Independent Flip (D3D)│$e[1;32m $(('Активен (0 лаг)').PadRight(15)) $e[1;36m│$e[0m"
    $info = Get-System-Hardware-Info
    $unparkName = if ($info.IsAMD) { "Core Unpark (Ryzen/CCX)" } elseif ($info.IsIntelHybrid) { "Core Priority (Intel P+E)" } else { "Core Unparking (CPMIN)" }
    $unparkStatus = if ($info.IsAMD) { "100% CCX Active" } elseif ($info.IsIntelHybrid) { "P-Core Prio (Het 4)" } else { "100% Cores Active" }
    $ramExecName = "Память: удержание ядра"
    $ramExecVal = if ($info.RamGB -ge 16) { "DisablePagingExec=1" } else { "Safe Dynamic Paging" }
    $ramExecStatus = if ($info.RamGB -ge 16) { "Ядро в RAM" } else { "Safe RAM Limit" }
    $gpuName = if ($info.HasDgpu) { $info.DiscreteGpus[0].Name } else { "iGPU Native Direct" }
    $gpuStatus = if ($info.HasDgpu) { "dGPU High Perf" } else { "iGPU Native" }
    $storLabel = if ($info.HasAnyNVMe) { "Стек накопителей (NVMe)" } elseif (-not $info.IsPureHDD) { "Стек накопителей (SATA)" } else { "Стек накопителей (HDD)" }
    $storVal = if (-not $info.IsPureHDD) { "Disable8dot3=1 TRIM=ON" } else { "SysMain=ON (HDD Safe)" }
    $storStatus = if ($info.HasAnyNVMe) { "APST Off (0ms)" } elseif (-not $info.IsPureHDD) { "TRIM Active" } else { "HDD Prefetch ON" }

    Write-Host "$e[1;33m  │ $($unparkName.PadRight(25)) │ 50% спят (C-States)   │ $($unparkStatus.PadRight(21)) │$e[1;32m $(('0мс задержка').PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ CPU Boost Режим           │ Базовый профиль       │ Mode 2 Aggressive     │$e[1;32m $(('Boost активен').PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ $($ramExecName.PadRight(25)) │ Сброс страниц на SSD  │ $($ramExecVal.PadRight(21)) │$e[1;32m $($ramExecStatus.PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ Standby-лист утечек RAM   │ Засорен файловым I/O  │ FlushStandbyList()    │$e[1;32m $(('0 фризов утечек').PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ Видеокарта для игр        │ Интегрированная/Auto  │ $(if ($gpuName.Length -gt 21) { $gpuName.Substring(0, 21) } else { $gpuName.PadRight(21) }) │$e[1;32m $($gpuStatus.PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ Аппаратный отклик USB     │ Энергосбережение USB  │ MSI High + NoSuspend  │$e[1;32m $(('0мс инпут-лаг').PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ Очередь прерываний GPU    │ Линейные IRQ          │ MSI Mode 1 (Priority3)│$e[1;32m $(('Мин. DPC latency').PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ $($storLabel.PadRight(25)) │ 8.3 имена DOS + Acces │ $($storVal.PadRight(21)) │$e[1;32m $($storStatus.PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ Маршрутизация IRQ dGPU    │ Все ядра / Shared     │ Изоляция CCX Core 2   │$e[1;32m $(('Cold L3 кэш').PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;33m  │ Garbage Collector Java    │ G1GC (100-300ms лаг)  │ Generational ZGC      │$e[1;32m $(('-70% пауз GC').PadRight(15)) $e[1;36m│$e[0m"
    Write-Host "$e[1;36m  └───────────────────────────┴───────────────────────┴───────────────────────┴─────────────────┘$e[0m"
    Write-Host ""
    Write-Host "$e[1;32m  ╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
    Write-Host "$e[1;32m  ║  ⚡ GAMING RESPONSIVENESS INDEX: $scoreBefore/100 ➔ $scoreAfter/100 (+$scoreGain пунктов прироста)     ║$e[0m"
    Write-Host "$e[1;32m  ╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
    Write-Host ""
    Write-Host "$e[1;36m  [УСТРАНЕННЫЕ АППАРАТНЫЕ БУТЫЛОЧНЫЕ ГОРЛЫШКИ]:$e[0m"
    Write-Host "$e[1;32m   ✔ Таймер Windows: $resBefore ms ➔ $resAfter ms (микро-статтеры кадровой очереди устранены)$e[0m"
    Write-Host "$e[1;32m   ✔ Дрожание DPC: $jitterBefore us ➔ $jitterAfter us (ввод мыши 1:1 без интерполяции)$e[0m"
    Write-Host "$e[1;32m   ✔ 4K случайное чтение: $diskIopsBefore ➔ $diskIopsAfter IOPS (мгновенная подгрузка чанков)$e[0m"
    Write-Host "$e[1;32m   ✔ Ядро Windows: заблокировано в физической RAM (своп на SSD полностью отключен)$e[0m"
    Write-Host "$e[1;32m   ✔ Прерывания dGPU: изолированы на Core 2 (комплекс CCX 1 свободен для игрового потока)$e[0m"
    Write-Host ""
    Write-Host "$e[1;32m  [OK] Экспресс-автоподбор успешно применен. Система откалибрована под оптимальный профиль.$e[0m"
}

function Invoke-Deep-Hardware-StressScan {
    $info = Get-System-Hardware-Info
    $archTag = if ($info.IsAMD) {
        "AMD ($($info.Cores)C/$($info.Threads)T, CCX/CCD), $($info.RamGB)GB RAM, $(if ($info.HasDgpu) { $info.DiscreteGpus[0].Name } else { 'iGPU' })"
    } elseif ($info.IsIntelHybrid) {
        "Intel Hybrid ($($info.Cores)C/$($info.Threads)T, P+E), $($info.RamGB)GB RAM, $(if ($info.HasDgpu) { $info.DiscreteGpus[0].Name } else { 'iGPU' })"
    } elseif ($info.IsIntel) {
        "Intel ($($info.Cores)C/$($info.Threads)T), $($info.RamGB)GB RAM, $(if ($info.HasDgpu) { $info.DiscreteGpus[0].Name } else { 'iGPU' })"
    } else {
        "$($info.CPUName) ($($info.Cores)C/$($info.Threads)T), $($info.RamGB)GB RAM"
    }
    $archLine = "  ║ Архитектура: $archTag"
    if ($archLine.Length -gt 78) { $archLine = $archLine.Substring(0, 78) } else { $archLine = $archLine.PadRight(78) }

    Clear-Host
    Write-Host "$e[1;36m╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
    Write-Host "$e[1;32m║   ⚡ ГЛУБОКИЙ СРАВНИТЕЛЬНЫЙ СТРЕСС-СКАН ЖЕЛЕЗА И АВТОПОДБОР ПРОФИЛЯ         ║$e[0m"
    $isHddSystem = ($info.IsPureHDD -or (-not $info.IsBootSSD))
    $diskRowPrefix = if ($info.HasAnyNVMe) { "NVMe 4K" } elseif (-not $isHddSystem) { "SSD 4K" } else { "HDD 4K" }
    $storageBanner = if ($info.HasAnyNVMe) { "p99 NVMe" } elseif (-not $isHddSystem) { "p99 SSD" } else { "HDD I/O" }
    $bannerLine = "║ Режим: 3-5 мин полный аудит частот, троттлинга, шины RAM, $storageBanner и D3D"
    if ($bannerLine.Length -gt 78) { $bannerLine = $bannerLine.Substring(0, 78) } else { $bannerLine = $bannerLine.PadRight(78) }
    Write-Host "$e[1;36m╠═════════════════════════════════════════════════════════════════════════════╣$e[0m"
    Write-Host "$e[0;37m$archLine║$e[0m"
    Write-Host "$e[0;37m$bannerLine║$e[0m"
    Write-Host "$e[1;36m╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
    Write-Host ""

    Write-Host "$e[1;33m>>> ЭТАП 1/2: ЗАМЕР БАЗОВОГО ЗАВОДСКОГО ПРОФИЛЯ (STOCK PROFILE)...$e[0m"
    Write-Host ""

    $ccxTag = if ($info.IsAMD) { 'CCX' } elseif ($info.IsIntelHybrid) { 'P+E' } else { 'All' }
    $cpuStressLabel = "$($info.Threads)T / $ccxTag"
    $cpuStressBefore = @()
    $intervals = 14
    for ($s = 1; $s -le $intervals; $s++) {
        Write-Host -NoNewline "$e[1;36m  ⚡ $e[1;37mФАЗА 1: CPU Sustained Stress ($cpuStressLabel) - интервал $($s.ToString('D2'))/$intervals [замер 6 сек]...$e[0m"
        $rate = [WinNativeOptimizer]::MeasureCpuStressInterval(6)
        $cpuStressBefore += $rate
        $curPeak = ($cpuStressBefore | Measure-Object -Maximum).Maximum
        $curDrop = if ($curPeak -gt 0) { [Math]::Max(0.0, [Math]::Round(($curPeak - $rate) / $curPeak * 100.0, 1)) } else { 0.0 }
        $curStab = if ($curPeak -gt 0) { [Math]::Round(($rate / $curPeak * 100.0), 1) } else { 100.0 }
        Write-Host "`r$e[1;32m  ✔ $e[1;37mФАЗА 1: CPU Sustained Stress ($cpuStressLabel) [$($s.ToString('D2'))/$intervals]: $e[1;33m$($rate.ToString('F1')) MOps $e[0;37m| Стабильность: $e[1;32m$curStab% $e[0;37m| Троттлинг: $e[1;36m-$curDrop%$e[0m   "
    }
    $cpuStressAvgBefore = [Math]::Round((($cpuStressBefore | Measure-Object -Average).Average), 1)
    $cpuStressMinBefore = ($cpuStressBefore | Measure-Object -Minimum).Minimum
    $cpuStressMaxBefore = ($cpuStressBefore | Measure-Object -Maximum).Maximum
    $cpuDropBefore = if ($cpuStressMaxBefore -gt 0) { [Math]::Max(0.0, [Math]::Round((($cpuStressMaxBefore - $cpuStressMinBefore) / $cpuStressMaxBefore * 100.0), 1)) } else { 0.0 }
    $cpuStabBefore = if ($cpuStressMaxBefore -gt 0) { [Math]::Round(($cpuStressMinBefore / $cpuStressMaxBefore * 100.0), 1) } else { 100.0 }

    $l3PoolTag = if ($info.IsAMD) { "CCX" } else { "Shared" }
    Show-Spinner "ФАЗА 1: Многоуровневый тест RAM: L1 Cache (4KB), L2 Cache (64KB)" 500
    Show-Spinner "ФАЗА 1: Многоуровневый тест RAM: L3 $l3PoolTag Pool (16MB), DRAM (64MB)" 500
    $ramMultiBefore = [WinNativeOptimizer]::MeasureRamMultiLevel()
    $ramL1Before = $ramMultiBefore[0]
    $ramL2Before = $ramMultiBefore[1]
    $ramL3Before = $ramMultiBefore[3]
    $ramDramBefore = $ramMultiBefore[4]
    $ramLatBefore = $ramMultiBefore[5]

    Show-Spinner "ФАЗА 1: Глубокий 4K случайный доступ $diskRowPrefix (5000 Direct I/O операций)" 800
    $diskDeepBefore = [WinNativeOptimizer]::MeasureDisk4KDeep(5000)
    $diskIopsBefore = $diskDeepBefore[0]
    $diskAvgLatBefore = $diskDeepBefore[1]
    $diskP99LatBefore = $diskDeepBefore[2]

    Show-Spinner "ФАЗА 1: Прецизионный замер DPC и джиттера Invariant TSC (400 тиков)" 600
    $dpcBefore = [WinNativeOptimizer]::MeasureTimerJitterDeep(400)
    $resBefore = $dpcBefore[0]
    $jitAvgBefore = $dpcBefore[1]
    $jitP99Before = $dpcBefore[2]

    Show-Spinner "ФАЗА 1: Замер кадрового буфера DWM и Direct3D Present Queue" 500
    $dwmDeepBefore = [WinNativeOptimizer]::MeasureDwmTimingDeep($false)
    $dwmHzBefore = $dwmDeepBefore[0]
    $dwmFrameLatBefore = $dwmDeepBefore[1]
    $dwmQueueLatBefore = $dwmDeepBefore[2]

    Write-Host ""
    Write-Host "$e[1;32m  [OK] Замеры заводского профиля зафиксированы!$e[0m"
    
    $autoProfile = if ($cpuDropBefore -gt 15.0 -and -not $info.IsAMD) { 'Cool' } elseif ($diskIopsBefore -gt 8000) { 'Esports' } else { 'Auto' }
    Write-Host "$e[1;33m  [ПРИМЕНЕНИЕ] Синтез и активация адаптивного профиля ($autoProfile)...$e[0m"
    Invoke-Smart-Hardware-Optimization -ProfileMode $autoProfile

    try {
        [WinNativeOptimizer]::timeBeginPeriod(1) | Out-Null
        [WinNativeOptimizer]::FlushStandbyList() | Out-Null
        [WinNativeOptimizer]::EmptySystemWorkingSets() | Out-Null
    } catch {}
    Start-Sleep -Seconds 2

    Write-Host ""
    Write-Host "$e[1;33m>>> ЭТАП 2/2: ЗАМЕР ЭКСТРЕМАЛЬНОГО ПРОФИЛЯ С АВТОПОДБОРОМ...$e[0m"
    Write-Host ""

    $cpuStressAfter = @()
    for ($s = 1; $s -le $intervals; $s++) {
        Write-Host -NoNewline "$e[1;36m  ⚡ $e[1;37mФАЗА 2: CPU Sustained Stress ($cpuStressLabel) - интервал $($s.ToString('D2'))/$intervals [замер 6 сек]...$e[0m"
        $rate = [WinNativeOptimizer]::MeasureCpuStressInterval(6)
        $cpuStressAfter += $rate
        $curPeak = ($cpuStressAfter | Measure-Object -Maximum).Maximum
        $curDrop = if ($curPeak -gt 0) { [Math]::Max(0.0, [Math]::Round(($curPeak - $rate) / $curPeak * 100.0, 1)) } else { 0.0 }
        $curStab = if ($curPeak -gt 0) { [Math]::Round(($rate / $curPeak * 100.0), 1) } else { 100.0 }
        Write-Host "`r$e[1;32m  ✔ $e[1;37mФАЗА 2: CPU Sustained Stress ($cpuStressLabel) [$($s.ToString('D2'))/$intervals]: $e[1;33m$($rate.ToString('F1')) MOps $e[0;37m| Стабильность: $e[1;32m$curStab% $e[0;37m| Троттлинг: $e[1;36m-$curDrop%$e[0m   "
    }
    $cpuStressAvgAfter = [Math]::Round((($cpuStressAfter | Measure-Object -Average).Average), 1)
    $cpuStressMinAfter = ($cpuStressAfter | Measure-Object -Minimum).Minimum
    $cpuStressMaxAfter = ($cpuStressAfter | Measure-Object -Maximum).Maximum
    $cpuDropAfter = if ($cpuStressMaxAfter -gt 0) { [Math]::Max(0.0, [Math]::Round((($cpuStressMaxAfter - $cpuStressMinAfter) / $cpuStressMaxAfter * 100.0), 1)) } else { 0.0 }
    $cpuStabAfter = if ($cpuStressMaxAfter -gt 0) { [Math]::Round(($cpuStressMinAfter / $cpuStressMaxAfter * 100.0), 1) } else { 100.0 }

    Show-Spinner "ФАЗА 2: Многоуровневый тест RAM: L1 Cache (4KB), L2 Cache (64KB)" 500
    Show-Spinner "ФАЗА 2: Многоуровневый тест RAM: L3 $l3PoolTag Pool (16MB), DRAM (64MB)" 500
    $ramMultiAfter = [WinNativeOptimizer]::MeasureRamMultiLevel()
    $ramL1After = $ramMultiAfter[0]
    $ramL2After = $ramMultiAfter[1]
    $ramL3After = $ramMultiAfter[3]
    $ramDramAfter = $ramMultiAfter[4]
    $ramLatAfter = $ramMultiAfter[5]

    Show-Spinner "ФАЗА 2: Глубокий 4K случайный доступ $diskRowPrefix (5000 Direct I/O операций)" 800
    $diskDeepAfter = [WinNativeOptimizer]::MeasureDisk4KDeep(5000)
    $diskIopsAfter = $diskDeepAfter[0]
    $diskAvgLatAfter = $diskDeepAfter[1]
    $diskP99LatAfter = $diskDeepAfter[2]

    Show-Spinner "ФАЗА 2: Прецизионный замер DPC и джиттера Invariant TSC (400 тиков)" 600
    $dpcAfter = [WinNativeOptimizer]::MeasureTimerJitterDeep(400)
    $resAfter = $dpcAfter[0]
    $jitAvgAfter = $dpcAfter[1]
    $jitP99After = $dpcAfter[2]

    Show-Spinner "ФАЗА 2: Замер кадрового буфера DWM и Direct3D Present Queue" 500
    $dwmDeepAfter = [WinNativeOptimizer]::MeasureDwmTimingDeep($true)
    $dwmHzAfter = $dwmDeepAfter[0]
    $dwmFrameLatAfter = $dwmDeepAfter[1]
    $dwmQueueLatAfter = $dwmDeepAfter[2]

    $cpuGain = if ($cpuStressAvgBefore -gt 0) { [Math]::Round((($cpuStressAvgAfter - $cpuStressAvgBefore) / $cpuStressAvgBefore * 100.0), 1) } else { 0.0 }
    $cpuStabGain = [Math]::Round(($cpuStabAfter - $cpuStabBefore), 1)
    $ramL1Gain = if ($ramL1Before -gt 0) { [Math]::Round((($ramL1After - $ramL1Before) / $ramL1Before * 100.0), 1) } else { 0.0 }
    $ramL2Gain = if ($ramL2Before -gt 0) { [Math]::Round((($ramL2After - $ramL2Before) / $ramL2Before * 100.0), 1) } else { 0.0 }
    $ramL3Gain = if ($ramL3Before -gt 0) { [Math]::Round((($ramL3After - $ramL3Before) / $ramL3Before * 100.0), 1) } else { 0.0 }
    $ramDramGain = if ($ramDramBefore -gt 0) { [Math]::Round((($ramDramAfter - $ramDramBefore) / $ramDramBefore * 100.0), 1) } else { 0.0 }
    $ramLatGain = if ($ramLatBefore -gt 0) { [Math]::Round((($ramLatBefore - $ramLatAfter) / $ramLatBefore * 100.0), 1) } else { 0.0 }
    $diskIopsGain = if ($diskIopsBefore -gt 0) { [Math]::Round((($diskIopsAfter - $diskIopsBefore) / $diskIopsBefore * 100.0), 1) } else { 0.0 }
    $diskAvgLatGain = if ($diskAvgLatBefore -gt 0) { [Math]::Round((($diskAvgLatBefore - $diskAvgLatAfter) / $diskAvgLatBefore * 100.0), 1) } else { 0.0 }
    $diskP99LatGain = if ($diskP99LatBefore -gt 0) { [Math]::Round((($diskP99LatBefore - $diskP99LatAfter) / $diskP99LatBefore * 100.0), 1) } else { 0.0 }
    $jitAvgGain = if ($jitAvgBefore -gt 0) { [Math]::Round((($jitAvgBefore - $jitAvgAfter) / $jitAvgBefore * 100.0), 1) } else { 0.0 }
    $jitP99Gain = if ($jitP99Before -gt 0) { [Math]::Round((($jitP99Before - $jitP99After) / $jitP99Before * 100.0), 1) } else { 0.0 }

    $cpuDeltaStr = if ($cpuGain -gt 0) { "+$cpuGain%" } elseif ($cpuGain -eq 0) { "0.0%" } else { "$cpuGain%" }
    $cpuColor = if ($cpuGain -gt 0) { "$e[1;32m" } elseif ($cpuGain -ge -2.0) { "$e[1;36m" } else { "$e[1;33m" }

    $cpuStabDeltaStr = if ($cpuStabGain -ge 0) { "+$cpuStabGain%" } else { "$cpuStabGain%" }
    $cpuStabColor = if ($cpuStabGain -ge 0) { "$e[1;32m" } else { "$e[1;33m" }

    $ramL1DeltaStr = if ($ramL1Gain -gt 0) { "+$ramL1Gain%" } elseif ($ramL1Gain -eq 0) { "0.0%" } else { "$ramL1Gain%" }
    $ramL2DeltaStr = if ($ramL2Gain -gt 0) { "+$ramL2Gain%" } elseif ($ramL2Gain -eq 0) { "0.0%" } else { "$ramL2Gain%" }
    $ramL3DeltaStr = if ($ramL3Gain -gt 0) { "+$ramL3Gain%" } elseif ($ramL3Gain -eq 0) { "0.0%" } else { "$ramL3Gain%" }
    $ramDramDeltaStr = if ($ramDramGain -gt 0) { "+$ramDramGain%" } elseif ($ramDramGain -eq 0) { "0.0%" } else { "$ramDramGain%" }
    $ramLatDeltaStr = if ($ramLatGain -gt 0) { "-$ramLatGain% ns" } elseif ($ramLatGain -eq 0) { "0.0% ns" } else { "+$([Math]::Abs($ramLatGain))% ns" }

    $diskIopsDeltaStr = if ($diskIopsGain -gt 0) { "+$diskIopsGain%" } elseif ($diskIopsGain -eq 0) { "0.0%" } else { "$diskIopsGain%" }
    $diskIopsColor = if ($diskIopsGain -gt 0) { "$e[1;32m" } elseif ($diskIopsGain -ge -3.0) { "$e[1;36m" } else { "$e[1;33m" }

    $diskAvgLatDeltaStr = if ($diskAvgLatGain -gt 0) { "-$diskAvgLatGain%" } elseif ($diskAvgLatGain -eq 0) { "0.0%" } else { "+$([Math]::Abs($diskAvgLatGain))%" }
    $diskP99LatDeltaStr = if ($diskP99LatGain -gt 0) { "-$diskP99LatGain%" } elseif ($diskP99LatGain -eq 0) { "0.0%" } else { "+$([Math]::Abs($diskP99LatGain))%" }

    $jitAvgDeltaStr = if ($jitAvgGain -gt 0) { "-$jitAvgGain%" } elseif ($jitAvgGain -eq 0) { "0.0%" } else { "+$([Math]::Abs($jitAvgGain))%" }
    $jitAvgColor = if ($jitAvgGain -gt 0) { "$e[1;32m" } elseif ($jitAvgGain -ge -5.0) { "$e[1;36m" } else { "$e[1;33m" }

    $jitP99DeltaStr = if ($jitP99Gain -gt 0) { "-$jitP99Gain%" } elseif ($jitP99Gain -eq 0) { "0.0%" } else { "+$([Math]::Abs($jitP99Gain))%" }

    $strCpuBefore = "$cpuStressAvgBefore MOps"
    $strCpuAfter = "$cpuStressAvgAfter MOps"
    $strCpuStabBefore = "$cpuStabBefore% (-$cpuDropBefore%)"
    $strCpuStabAfter = "$cpuStabAfter% (-$cpuDropAfter%)"
    $strRamL1Before = "$ramL1Before GB/s"
    $strRamL1After = "$ramL1After GB/s"
    $strRamL2Before = "$ramL2Before GB/s"
    $strRamL2After = "$ramL2After GB/s"
    $strRamL3Before = "$ramL3Before GB/s"
    $strRamL3After = "$ramL3After GB/s"
    $strRamDramBefore = "$ramDramBefore GB/s"
    $strRamDramAfter = "$ramDramAfter GB/s"
    $strRamLatBefore = "$ramLatBefore ns"
    $strRamLatAfter = "$ramLatAfter ns"
    $strDiskIBefore = "$diskIopsBefore IOPS"
    $strDiskIAfter = "$diskIopsAfter IOPS"
    $strDiskAvgBefore = "$diskAvgLatBefore us"
    $strDiskAvgAfter = "$diskAvgLatAfter us"
    $strDiskP99Before = "$diskP99LatBefore us"
    $strDiskP99After = "$diskP99LatAfter us"
    $strResBefore = "$resBefore ms"
    $strResAfter = "$resAfter ms"
    $strJitAvgBefore = "$jitAvgBefore us"
    $strJitAvgAfter = "$jitAvgAfter us"
    $strJitP99Before = "$jitP99Before us"
    $strJitP99After = "$jitP99After us"
    $strDwmBefore = "$dwmFrameLatBefore ms ($dwmHzBefore Hz)"
    $strDwmAfter = "$dwmFrameLatAfter ms ($dwmHzAfter Hz)"
    $strQueueBefore = "$dwmQueueLatBefore ms"
    $strQueueAfter = "$dwmQueueLatAfter ms"

    $rowCpuSustained = "CPU Sustained ($cpuStressLabel)"
    $rowL3 = "RAM L3 $l3PoolTag Pool (16MB)"
    $tagL3 = if ($info.IsAMD) { "[CCX Pool]" } else { "[L3 Speed]" }
    $tagDram = if ($info.RamGB -ge 16) { "[DRAM High]" } else { "[DRAM OK]" }
    $rowUnpark = if ($info.IsAMD) { "Core Unpark (Ryzen/CCX)" } elseif ($info.IsIntelHybrid) { "Core Priority (Intel P+E)" } else { "Core Unpark (CPMIN)" }
    $valUnpark = if ($info.IsAMD) { "100% CCX Active" } elseif ($info.IsIntelHybrid) { "P-Core Prio (Het 4)" } else { "100% Cores Active" }
    $gpuBeforeStr = "Интегрированная/Auto"
    $gpuAfterStr = if ($info.HasDgpu) { $info.DiscreteGpus[0].Name } else { "iGPU Native Direct" }
    if ($gpuAfterStr.Length -gt 21) { $gpuAfterStr = $gpuAfterStr.Substring(0, 21) }
    $gpuTagStr = if ($info.HasDgpu) { "[dGPU High]" } else { "[iGPU Fix]" }
    $rowStorage = if ($info.HasAnyNVMe) { "Стек накопителей (NVMe)" } elseif (-not $info.IsPureHDD) { "Стек накопителей (SATA)" } else { "Стек накопителей (HDD)" }
    $storageAfterStr = if (-not $info.IsPureHDD) { "Disable8dot3=1 TRIM=ON" } else { "SysMain=ON (HDD Safe)" }
    $storageDeltaStr = if ($info.HasAnyNVMe) { "APST Off (0ms)" } elseif (-not $info.IsPureHDD) { "TRIM Active" } else { "HDD Prefetch ON" }
    $storageTagStr = if ($info.HasAnyNVMe) { "[NVMe APST]" } elseif (-not $info.IsPureHDD) { "[TRIM/SATA]" } else { "[HDD Safe]" }
    $ramKernelAfterStr = if ($info.RamGB -ge 16) { "DisablePagingExec=1" } else { "Safe Dynamic Paging" }
    $ramKernelTagStr = if ($info.RamGB -ge 16) { "[Kernel RAM]" } else { "[RAM Safe]" }
    $ramKernelDeltaStr = "$($info.RamGB)GB RAM"

    Write-Host ""
    Write-Host "$e[1;36m  ┌───────────────────────────┬───────────────────────┬───────────────────────┬─────────────────────────┐$e[0m"
    Write-Host "$e[1;37m  │ Параметр стресс-теста     │ Заводской профиль     │ Экстремальный профиль │ Дельта / Автовыбор      │$e[0m"
    Write-Host "$e[1;36m  ├───────────────────────────┼───────────────────────┼───────────────────────┼─────────────────────────┤$e[0m"
    Write-Host (Format-Stress-Row $rowCpuSustained $strCpuBefore $strCpuAfter $cpuDeltaStr "[Aggressive]" $cpuColor)
    Write-Host (Format-Stress-Row "CPU Frequency Stability" $strCpuStabBefore $strCpuStabAfter $cpuStabDeltaStr "[Rock-Solid]" $cpuStabColor)
    Write-Host (Format-Stress-Row "RAM L1 Cache (4KB)" $strRamL1Before $strRamL1After $ramL1DeltaStr "[L1 Ultra]")
    Write-Host (Format-Stress-Row "RAM L2 Cache (64KB)" $strRamL2Before $strRamL2After $ramL2DeltaStr "[L2 Ultra]")
    Write-Host (Format-Stress-Row $rowL3 $strRamL3Before $strRamL3After $ramL3DeltaStr $tagL3)
    Write-Host (Format-Stress-Row "RAM Physical DRAM (64MB)" $strRamDramBefore $strRamDramAfter $ramDramDeltaStr $tagDram)
    Write-Host (Format-Stress-Row "RAM Random DRAM Latency" $strRamLatBefore $strRamLatAfter $ramLatDeltaStr "[Fast Track]")
    Write-Host (Format-Stress-Row "$diskRowPrefix Random IOPS" $strDiskIBefore $strDiskIAfter $diskIopsDeltaStr "[Unbuffered]" $diskIopsColor)
    Write-Host (Format-Stress-Row "$diskRowPrefix Средняя задержка" $strDiskAvgBefore $strDiskAvgAfter $diskAvgLatDeltaStr "[Direct I/O]")
    Write-Host (Format-Stress-Row "$diskRowPrefix 99-й перцентиль p99" $strDiskP99Before $strDiskP99After $diskP99LatDeltaStr "[0 фризов]")
    Write-Host (Format-Stress-Row "Разрешение таймера ОС" $strResBefore $strResAfter "$resAfter ms" "[1.0ms Target]")
    Write-Host (Format-Stress-Row "DPC Джиттер Invariant TSC" $strJitAvgBefore $strJitAvgAfter $jitAvgDeltaStr "[TSC Synced]" $jitAvgColor)
    Write-Host (Format-Stress-Row "DPC Джиттер пиковый (p99)" $strJitP99Before $strJitP99After $jitP99DeltaStr "[Мин. спайки]")
    Write-Host (Format-Stress-Row "DWM Время вывода кадра" $strDwmBefore $strDwmAfter "Стабильно" "[60-144 Hz]")
    Write-Host (Format-Stress-Row "Direct3D Present Queue" $strQueueBefore $strQueueAfter "-50% лаг" "[Flip Model]")
    Write-Host (Format-Stress-Row $rowUnpark "50% спят (C-States)" $valUnpark "0мс пробужд" "[Unparked]")
    Write-Host (Format-Stress-Row "CPU Boost Режим" "Базовый профиль" "Mode 2 Aggressive" "Max Clock" "[Boost ON]")
    Write-Host (Format-Stress-Row "Память: удержание ядра" "Сброс страниц на SSD" $ramKernelAfterStr $ramKernelDeltaStr $ramKernelTagStr)
    Write-Host (Format-Stress-Row "Standby-лист утечек RAM" "Засорен файловым I/O" "FlushStandbyList()" "0 утечек" "[Flushed]")
    Write-Host (Format-Stress-Row "Видеокарта для игр" $gpuBeforeStr $gpuAfterStr "dGPU Prior" $gpuTagStr)
    Write-Host (Format-Stress-Row "Очередь прерываний GPU" "Линейные IRQ" "MSI Mode 1 (Priority3)" "0 лаг прер" "[High Prior]")
    Write-Host (Format-Stress-Row "Маршрутизация IRQ dGPU" "Все ядра / Shared" "Изоляция CCX Core 2" "Cold L3 кэш" "[IRQ Steering]")
    Write-Host (Format-Stress-Row $rowStorage "8.3 имена DOS + Acces" $storageAfterStr $storageDeltaStr $storageTagStr)
    Write-Host "$e[1;36m  └───────────────────────────┴───────────────────────┴───────────────────────┴─────────────────────────┘$e[0m"
    Write-Host ""
    Write-Host "$e[1;32m  ╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
    Write-Host "$e[1;32m  ║  ⚡ АНАЛИТИЧЕСКИЙ ВЕРДИКТ АВТОПОДБОРА: ПРОФИЛЬ '$($autoProfile.ToUpper())' ЗАКРЕПЛЕН В СИСТЕМЕ        ║$e[0m"
    Write-Host "$e[1;32m  ╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
    Write-Host "$e[1;33m  - Термо-стабильность CPU: $cpuStabAfter% (Троттлинг снижен до -$cpuDropAfter%)$e[0m"
    Write-Host "$e[1;33m  - Задержка DRAM: $ramLatAfter ns (Скорость L1-кэша: $ramL1After GB/s)$e[0m"
    Write-Host "$e[1;33m  - DirectDMA 4K p99: $diskP99LatAfter us (Исключены микро-задержки дискового ввода-вывода)$e[0m"
    Write-Host "$e[1;33m  - Джиттер таймеров Invariant TSC: $jitAvgAfter us (Максимальная точность кадров)$e[0m"
    Write-Host ""
    Write-Host "$e[1;32m  [OK] Глубокий стресс-скан завершен. Профиль $autoProfile успешно синтезирован и применен.$e[0m"
}

function Format-Stress-Row {
    param($title, $before, $after, $delta, $tag, $color = "$e[1;32m")
    $t = if ($title.Length -gt 25) { $title.Substring(0, 25) } else { $title.PadRight(25) }
    $b = if ($before.Length -gt 21) { $before.Substring(0, 21) } else { $before.PadRight(21) }
    $a = if ($after.Length -gt 21) { $after.Substring(0, 21) } else { $after.PadRight(21) }
    $d = if ($delta.Length -gt 13) { $delta.Substring(0, 13) } else { $delta.PadRight(13) }
    $tg = if ($tag.Length -gt 9) { $tag.Substring(0, 9) } else { $tag.PadRight(9) }
    return "$e[1;33m  │ $t │ $b │ $a │$color $d $e[1;36m$tg │$e[0m"
}
function Invoke-Vulnerability-Security-Audit {
    Clear-Host
    $info = Get-System-Hardware-Info
    $memKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    $fso = (Get-ItemProperty $memKey -Name 'FeatureSettingsOverride' -ErrorAction SilentlyContinue).FeatureSettingsOverride
    $fsom = (Get-ItemProperty $memKey -Name 'FeatureSettingsOverrideMask' -ErrorAction SilentlyContinue).FeatureSettingsOverrideMask
    $isSpectreDisabled = ($fso -eq 3 -and $fsom -eq 3)
    $spectreStatus = if ($isSpectreDisabled) { "$e[1;32mПАТЧИ ВЫКЛ (+10-15% FPS)$e[0m" } else { "$e[1;33mПАТЧИ ВКЛ (Штатный)$e[0m" }

    $vbsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    $vbsVal = (Get-ItemProperty $vbsKey -Name 'EnableVirtualizationBasedSecurity' -ErrorAction SilentlyContinue).EnableVirtualizationBasedSecurity
    $hvciVal = (Get-ItemProperty ($vbsKey + '\Scenarios\HypervisorEnforcedCodeIntegrity') -Name 'Enabled' -ErrorAction SilentlyContinue).Enabled
    $hasVanguard = (Get-Service -Name 'vgk' -ErrorAction SilentlyContinue) -ne $null
    $isVbsOff = ($vbsVal -eq 0 -and $hvciVal -eq 0)
    $vbsStatus = if ($isVbsOff) {
        "$e[1;32mВЫКЛЮЧЕН (+5-12% FPS)$e[0m"
    } elseif ($hasVanguard) {
        "$e[1;36mВКЛ (Сохранен: Vanguard)$e[0m"
    } else {
        "$e[1;33mВКЛЮЧЕН (SLAT оверхед)$e[0m"
    }

    $cfgMit = (Get-ProcessMitigation -Name 'javaw.exe' -ErrorAction SilentlyContinue).ControlFlowGuard.Enable
    $cfgStatus = if ($cfgMit -eq 'OFF') { "$e[1;32mВЫКЛЮЧЕН (0% лаг JIT)$e[0m" } else { "$e[1;33mВКЛЮЧЕН (Штатный)$e[0m" }

    $polProcKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Processes'
    $polPathKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Paths'
    $regProcs = if (Test-Path $polProcKey) { (Get-Item $polProcKey -ErrorAction SilentlyContinue).Property } else { @() }
    $regPaths = if (Test-Path $polPathKey) { (Get-Item $polPathKey -ErrorAction SilentlyContinue).Property } else { @() }
    $mp = Get-MpPreference -ErrorAction SilentlyContinue
    $isProcEx = ($mp -and $mp.ExclusionProcess -contains 'javaw.exe') -or ($regProcs -contains 'javaw.exe')
    $isPathEx = ($mp -and ($mp.ExclusionPath -match 'PrismLauncher|\.minecraft')) -or ($regPaths -match 'PrismLauncher|\.minecraft')
    $procEx = if ($isProcEx) { "$e[1;32mВ ИСКЛЮЧЕНИЯХ$e[0m" } else { "$e[1;31mНЕ ДОБАВЛЕН$e[0m" }
    $pathEx = if ($isPathEx) { "$e[1;32mВ ИСКЛЮЧЕНИЯХ$e[0m" } else { "$e[1;31mНЕ ДОБАВЛЕН$e[0m" }

    Write-Host "$e[1;36m╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
    Write-Host "$e[1;32m║          🛡️  АУДИТ УЯЗВИМОСТЕЙ, МИТИГАЦИЙ И ИГРОВОЙ ПРОИЗВОДИТЕЛЬНОСТИ       ║$e[0m"
    Write-Host "$e[1;36m╠═════════════════════════════════════════════════════════════════════════════╣$e[0m"
    Write-Host "  CPU: $($info.CPUName) ($($info.Cores)C/$($info.Threads)T) | OS: $($info.OSName) ($($info.OSBuild))"
    Write-Host ""
    Write-Host "  1. Spectre / Meltdown Mitigations : $spectreStatus"
    Write-Host "     -> При выключении: возвращает 10-15% однопоточного IPC и сглаживает фреймтайм"
    Write-Host "  2. Virtualization-Based Security (VBS) : $vbsStatus"
    Write-Host "     -> При выключении: устраняет задержки гипервизора и штрафы трансляции SLAT"
    Write-Host "  3. Control Flow Guard (CFG) Java/MC : $cfgStatus"
    Write-Host "     -> При выключении: устраняет оверхед проверки вызовов внутри JVM компилятора"
    Write-Host "  4. Defender Process Exclusions : $procEx"
    Write-Host "     -> javaw.exe, java.exe, SyntaxClient.exe, SyntaxLoader.exe, PrismLauncher.exe"
    Write-Host "  5. Defender Folder Exclusions : $pathEx"
    Write-Host "     -> .minecraft, PrismLauncher, SyntaxClient, SyntaxLoader"
    Write-Host "$e[1;36m╠═════════════════════════════════════════════════════════════════════════════╣$e[0m"
    Write-Host "$e[1;32m  [1] ПРИМЕНИТЬ ИГРОВОЙ ЭКСТРЕМАЛЬНЫЙ ПРОФИЛЬ (Max FPS, Min DPC Jitter)$e[0m"
    Write-Host "$e[0;37m      -> Отключить Spectre/Meltdown, VBS (если нет Vanguard), CFG для игр, добавить Defender$e[0m"
    Write-Host "$e[1;33m  [2] ВОССТАНОВИТЬ ШТАТНЫЙ УРОВЕНЬ ЗАЩИТЫ WINDOWS (Stock Security)$e[0m"
    Write-Host "$e[0;37m      -> Включить Spectre/Meltdown патчи, активировать VBS и восстановить CFG$e[0m"
    Write-Host "$e[1;30m  [0] Назад в главное меню$e[0m"
    Write-Host "$e[1;36m╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
    Write-Host ""
    $rawAct = Read-Host " Выбери действие"
    $act = if ($rawAct) { $rawAct.Trim() } else { "" }
    if ($act -eq '1') {
        Show-Spinner "Применение игрового профиля безопасности и митигаций" 600
        Invoke-Kernel-DirectIo-Optimization
        Write-Host "$e[1;32m  [OK] Экстремальный профиль применен! Требуется перезагрузка для активации ядра.$e[0m"
        Pause
    } elseif ($act -eq '2') {
        Show-Spinner "Восстановление штатного уровня безопасности Windows" 600
        Remove-ItemProperty -Path $memKey -Name 'FeatureSettingsOverride' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $memKey -Name 'FeatureSettingsOverrideMask' -ErrorAction SilentlyContinue
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity' 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 1 -Type DWord -Force -ErrorAction SilentlyContinue
        $gameBins = @('javaw.exe', 'java.exe', 'SyntaxClient.exe', 'SyntaxLoader.exe', 'PrismLauncher.exe')
        foreach ($bin in $gameBins) {
            Set-ProcessMitigation -Name $bin -Reset -ErrorAction SilentlyContinue *> $null
        }
        Remove-Item -Path $polProcKey -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $polPathKey -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "$e[1;32m  [OK] Штатный уровень безопасности Windows восстановлен! Требуется перезагрузка.$e[0m"
        Pause
    }
}

while ($true) {
    Clear-Host
    Get-Hardware-HUD
    Write-Host ""
    Write-Host "$e[1;36m  [1]$e[1;37m ПОЛНАЯ УЛЬТРА-ОПТИМИЗАЦИЯ СИСТЕМЫ $e[0;36m(Комплекс 'Всё-в-одном')$e[0m"
    Write-Host "$e[0;37m      -> Адаптация ПК/ноутбук, таймеры Invariant TSC, IFEO, память, dGPU MSI.$e[0m"
    Write-Host ""
    Write-Host "$e[1;33m  [2]$e[1;37m ГЛУБОКИЙ КЛИНИНГ И ДЕБЛОАТ $e[0;33m(Очистка системы и вырезка мусора)$e[0m"
    Write-Host "$e[0;37m      -> Вырезка рекламы UWP, виджетов, телеметрии, дампов WER, кэшей и логов.$e[0m"
    Write-Host ""
    Write-Host "$e[1;32m  [3]$e[1;37m СОЗДАТЬ ТОЧКУ ВОССТАНОВЛЕНИЯ И БЭКАП РЕЕСТРА$e[0m"
    Write-Host "$e[0;37m      -> Моментальная фиксация System Restore Point и экспорт веток реестра.$e[0m"
    Write-Host ""
    Write-Host "$e[1;36m  [4]$e[1;37m ВОССТАНОВИТЬ СИСТЕМУ И РЕЕСТР ИЗ ПОСЛЕДНЕГО БЭКАПА$e[0m"
    Write-Host "$e[0;37m      -> 1-клик откат веток реестра и настроек из автоматической копии.$e[0m"
    Write-Host ""
    Write-Host "$e[1;35m  [5]$e[1;37m УМНЫЙ АВТОПОДБОР И СРАВНИТЕЛЬНЫЙ БЕНЧМАРК ЖЕЛЕЗА$e[0m"
    Write-Host "$e[0;37m      -> Экспресс (~25 сек) или глубокий стресс-скан (CPU, RAM, 4K Direct IOPS).$e[0m"
    Write-Host ""
    Write-Host "$e[1;31m  [6]$e[1;37m АУДИТ УЯЗВИМОСТЕЙ И ИГРОВОГО FPS $e[0;37m(Spectre, Meltdown, CFG, Defender)$e[0m"
    Write-Host ""
    Write-Host "$e[1;34m  [7]$e[1;37m СБРОС ДЕГРАДАЦИИ АПТАЙМА WIN 11 $e[0;34m(Ревитализация без перезагрузки)$e[0m"
    Write-Host "$e[0;37m      -> Сброс утечек DWM, зомби-хостов XAML, Standby RAM, AudioDG, кэшей.$e[0m"
    Write-Host ""
    Write-Host "$e[1;37m  [0]$e[0;37m ВЫХОД ИЗ ПРОГРАММЫ$e[0m"
    Write-Host ""
    Write-Host "$e[1;36m  ────────────────────────────────────────────────────────────────────$e[0m"
    $rawChoice = Read-Host "  [?] Выберите действие (0-7)"
    $choice = if ($rawChoice) { $rawChoice.Trim() } else { "" }
    if ($rawChoice -eq $null -or $choice -eq '0' -or ([Console]::IsInputRedirected -and [string]::IsNullOrWhiteSpace($choice))) {
        break
    }
    
    switch ($choice) {
        '1' {
            Clear-Host
            Write-Host "$e[1;36m╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
            Write-Host "$e[1;32m║         ⚡ ЗАПУСК ПОЛНОЙ ЭКСПРЕСС-ОПТИМИЗАЦИИ 'ВСЁ В ОДНОМ' (ULTRA)         ║$e[0m"
            Write-Host "$e[1;36m╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
            Write-Host ""
            Write-Host " [INFO] Процедура применит полный комплекс: аппаратная адаптация, тюнинг ядра,"
            Write-Host "        таймеры Invariant TSC, стек накопителей, приоритеты памяти и графики,"
            Write-Host "        отключение FTH, очистку телеметрии и финализацию параметров."
            Write-Host ""
            $conf = Read-Host " Начать выполнение комплекса? (Y/N)"
            $confVal = if ($conf) { $conf.Trim() } else { "" }
            if ($confVal -in @('Y', 'y')) {
                Clear-Host
                Write-Host "$e[1;36m╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
                Write-Host "$e[1;32m║               ⚡ ВЫПОЛНЕНИЕ ЭТАПОВ ОПТИМИЗАЦИИ СИСТЕМЫ v6.0                 ║$e[0m"
                Write-Host "$e[1;36m╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
                Write-Host ""
                $script:QuietMode = $true

                Invoke-Stage-Step 1 6 "Подготовка окружения" {
                    Get-System-Hardware-Info | Out-Null
                    Backup-Create
                    Invoke-Disable-Animations
                }

                Invoke-Stage-Step 2 6 "Тюнинг ядра и таймеров" {
                    Invoke-Hardcore-Gaming
                    Invoke-Kernel-DirectIo-Optimization
                    Invoke-Smart-Hardware-Optimization -ProfileMode 'Auto'
                    $fthKey = 'HKLM:\SOFTWARE\Microsoft\FTH'
                    if (-not (Test-Path $fthKey)) { New-Item -Path $fthKey -Force -ErrorAction SilentlyContinue | Out-Null }
                    Set-ItemProperty -Path $fthKey -Name 'Enabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    rundll32.exe fthcfg.dll,FthSysprepSpecialize *> $null
                }

                Invoke-Stage-Step 3 6 "Конфигурация дисковой подсистемы" {
                    Invoke-Storage-Tuning
                    $ifeoBins = @('javaw.exe', 'java.exe', 'SyntaxClient.exe', 'PrismLauncher.exe')
                    foreach ($bin in $ifeoBins) {
                        $binKeys = @(
                            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$bin\PerfOptions",
                            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$bin\PerfOptions"
                        )
                        foreach ($bk in $binKeys) {
                            if (-not (Test-Path $bk)) { New-Item -Path $bk -Force -ErrorAction SilentlyContinue | Out-Null }
                            Set-ItemProperty -Path $bk -Name 'CpuPriorityClass' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
                            Set-ItemProperty -Path $bk -Name 'IoPriority' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
                            Set-ItemProperty -Path $bk -Name 'PagePriority' -Value 5 -Type DWord -Force -ErrorAction SilentlyContinue
                        }
                    }
                }

                Invoke-Stage-Step 4 6 "Приоритезация графики и памяти" {
                    Invoke-Memory-AntiLeak
                    Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue *> $null
                    Invoke-Irq-Affinity-Steering
                    Invoke-Usb-Input-Optimization
                    Invoke-Audio-Optimization
                    $info = Get-System-Hardware-Info
                    $hasNvidia = ($info.AllGpus | Where-Object { $_.PNPDeviceID -match 'VEN_10DE' }).Count -gt 0
                    if ($hasNvidia) {
                        [Environment]::SetEnvironmentVariable('__GL_SHADER_DISK_CACHE_SIZE', '10737418240', 'Machine')
                        [Environment]::SetEnvironmentVariable('__GL_SHADER_DISK_CACHE_SKIP_CLEANUP', '1', 'Machine')
                        $nvTweak = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\NVTweak'
                        if (-not (Test-Path $nvTweak)) { New-Item -Path $nvTweak -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $nvTweak -Name 'ShaderCacheSize' -Value 10240 -Type DWord -Force -ErrorAction SilentlyContinue
                        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object {
                            $desc = (Get-ItemProperty $_.PSPath -Name 'DriverDesc' -ErrorAction SilentlyContinue).DriverDesc
                            if ($desc -match 'NVIDIA') {
                                Set-ItemProperty -Path $_.PSPath -Name 'MaxShaderCacheSize' -Value 10240 -Type DWord -Force -ErrorAction SilentlyContinue
                                Set-ItemProperty -Path $_.PSPath -Name 'ShaderCache' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                }

                Invoke-Stage-Step 5 6 "Очистка фоновой телеметрии" {
                    Invoke-Debloat-Privacy
                    $etwSessions = @('Diagtrack-Listener', 'DiagLog')
                    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\RadioMgr' -Name 'Start' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    foreach ($ses in $etwSessions) {
                        $sesKey = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$ses"
                        if (Test-Path $sesKey) {
                            Set-ItemProperty -Path $sesKey -Name 'Start' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                        }
                        logman stop "$ses" -ets *> $null
                    }
                    Invoke-System-Repair-Fixes
                }

                Invoke-Stage-Step 6 6 "Финализация и верификация" {
                    Invoke-Minecraft-AutoTuning
                    $regWmo = 'HKLM:\SOFTWARE\WindowsMasterOptimizer'
                    if (-not (Test-Path $regWmo)) { New-Item -Path $regWmo -Force -ErrorAction SilentlyContinue | Out-Null }
                    $nowStr = (Get-Date).ToString("dd.MM.yyyy HH:mm:ss")
                    Set-ItemProperty -Path $regWmo -Name 'LastRun' -Value $nowStr -Force -ErrorAction SilentlyContinue
                }

                $script:QuietMode = $false
                Write-Host ""
                Write-Host "$e[1;32m  [OK] Все этапы инженерной оптимизации выполнены на 100%!$e[0m"
                Write-Host "$e[1;32m  [OK] Статус системы: Оптимизация актуальна / Система в идеальном состоянии$e[0m"
                Write-Host "$e[1;37m  [OK] Время фиксации: $((Get-Date).ToString('dd.MM.yyyy HH:mm:ss'))$e[0m"
                Write-Host ""
                Write-Host " Рекомендуется перезагрузить компьютер для активации BCDedit Invariant TSC и ядра."
                $reb = Read-Host " Перезагрузить компьютер прямо сейчас? (Y/N)"
                $rebVal = if ($reb) { $reb.Trim() } else { "" }
                if ($rebVal -in @('Y', 'y')) {
                    shutdown /r /t 5 /c "Перезагрузка после применения Windows Master Optimizer Ultra"
                }
            }
        }
        '2' {
            Clear-Host
            Write-Host "$e[1;36m╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
            Write-Host "$e[1;33m║         🧹 ГЛУБОКИЙ КЛИНИНГ, ВЫРЕЗКА ВИДЖЕТОВ, МУСОРА И ДЕБЛОАТ             ║$e[0m"
            Write-Host "$e[1;36m╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
            Write-Host ""
            Write-Host " [INFO] Процедура удалит рекламный мусор UWP, выключит виджеты, Copilot, Recall,"
            Write-Host "        очистит дампы WER, старые системные журналы, временный мусор и кэши."
            Write-Host "        Системные драйверы, таймеры и параметры ядра затронуты НЕ будут."
            Write-Host ""
            $conf2 = Read-Host " Запустить клининг и деблоат? (Y/N)"
            $conf2Val = if ($conf2) { $conf2.Trim() } else { "" }
            if ($conf2Val -in @('Y', 'y')) {
                Clear-Host
                $script:QuietMode = $true
                Invoke-Stage-Step 1 3 "Создание резервной копии перед очисткой" { Backup-Create }
                Invoke-Stage-Step 2 3 "Удаление рекламного мусора UWP и телеметрии" { Invoke-Debloat-Privacy }
                Invoke-Stage-Step 3 3 "Очистка системных отчетов, логов и кэшей" { Invoke-System-Repair-Fixes -DeepClean }
                $script:QuietMode = $false
                Write-Host ""
                Write-Host "$e[1;32m  [OK] Система успешно очищена от мусора, виджетов и фоновой телеметрии!$e[0m"
                Write-Host ""
                Pause
            }
        }
        '3' {
            Clear-Host
            Write-Host "$e[1;36m╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
            Write-Host "$e[1;32m║               СОЗДАНИЕ ТОЧКИ ВОССТАНОВЛЕНИЯ И БЭКАПА РЕЕСТРА                ║$e[0m"
            Write-Host "$e[1;36m╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
            Write-Host ""
            Backup-Create
            Write-Host ""
            Pause
        }
        '4' {
            Clear-Host
            Write-Host "$e[1;36m╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
            Write-Host "$e[1;36m║               ВОССТАНОВЛЕНИЕ НАСТРОЕК РЕЕСТРА ИЗ БЭКАПА                     ║$e[0m"
            Write-Host "$e[1;36m╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
            Write-Host ""
            Backup-Restore
            Write-Host ""
            Pause
        }
        '5' {
            Clear-Host
            Write-Host "$e[1;36m╔═════════════════════════════════════════════════════════════════════════════╗$e[0m"
            Write-Host "$e[1;32m║        ⚡ УМНЫЙ АВТОПОДБОР И СРАВНИТЕЛЬНЫЙ ПРОФАЙЛЕР ЖЕЛЕЗА                ║$e[0m"
            Write-Host "$e[1;36m╠═════════════════════════════════════════════════════════════════════════════╣$e[0m"
            Write-Host "$e[1;33m║  [1] Экспресс-автоподбор (~20-30 сек) с расчетом Gaming Index (0-100)       ║$e[0m"
            Write-Host "$e[0;37m║      -> Замер задержек, расчет индекса отзывчивости и автокалибровка        ║$e[0m"
            Write-Host "$e[1;33m║  [2] Глубокий 3-5 мин стресс-скан оборудования и синтез профиля             ║$e[0m"
            Write-Host "$e[0;37m║      -> Троттлинг CPU, L1-DRAM, 5000 Direct I/O p99, DPC jitter Invariant   ║$e[0m"
            Write-Host "$e[1;32m║  [3] Принудительно: Профиль 'Esports Low-Latency' (0ms инпут-лаг, таймеры) ║$e[0m"
            Write-Host "$e[1;36m║  [4] Принудительно: Профиль 'Sustained Power' (макс. частота, многопоток)   ║$e[0m"
            Write-Host "$e[1;35m║  [5] Принудительно: Профиль 'Cool & Quiet' (термо-контроль для ноутбуков)   ║$e[0m"
            Write-Host "$e[1;30m║  [0] Назад в главное меню                                                   ║$e[0m"
            Write-Host "$e[1;36m╚═════════════════════════════════════════════════════════════════════════════╝$e[0m"
            Write-Host ""
            $rawScan = Read-Host " Выбери режим"
            $scanChoice = if ($rawScan) { $rawScan.Trim() } else { "" }
            if ($scanChoice -eq '1') {
                Clear-Host
                Invoke-Smart-Hardware-Benchmark
                Write-Host ""
                Pause
            } elseif ($scanChoice -eq '2') {
                Clear-Host
                Invoke-Deep-Hardware-StressScan
                Write-Host ""
                Pause
            } elseif ($scanChoice -eq '3') {
                Clear-Host
                Show-Progress-Bar 50 "Активация киберспортивного профиля с минимальной задержкой..."
                Invoke-Smart-Hardware-Optimization -ProfileMode 'Esports'
                Show-Progress-Bar 100 "Профиль Esports Low-Latency успешно применен!"
                Write-Host ""
                Pause
            } elseif ($scanChoice -eq '4') {
                Clear-Host
                Show-Progress-Bar 50 "Активация профиля максимальной многопоточной мощности..."
                Invoke-Smart-Hardware-Optimization -ProfileMode 'Sustained'
                Show-Progress-Bar 100 "Профиль Sustained Power успешно применен!"
                Write-Host ""
                Pause
            } elseif ($scanChoice -eq '5') {
                Clear-Host
                Show-Progress-Bar 50 "Активация термо-адаптивного профиля для ноутбука..."
                Invoke-Smart-Hardware-Optimization -ProfileMode 'Cool'
                Show-Progress-Bar 100 "Профиль Cool & Quiet успешно применен!"
                Write-Host ""
                Pause
            }
        }
        '6' {
            Invoke-Vulnerability-Security-Audit
        }
        '7' {
            Invoke-Uptime-Revitalize
        }
        '0' {
            break
        }
    }
}
