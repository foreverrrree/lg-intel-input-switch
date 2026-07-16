param(
    [Parameter(Position = 0)]
    [ValidateSet("scan", "hdmi1", "hdmi2", "dp", "usbc", "usbc2")]
    [string] $InputName = "scan"
)

$ErrorActionPreference = "Stop"

$inputValues = @{
    hdmi1 = 0x90
    hdmi2 = 0x91
    dp    = 0xD0
    usbc  = 0xD1
    usbc2 = 0xD2
}

$sourceAddress = 0x50

$csharp = @"
using System;
using System.Runtime.InteropServices;

public static class IntelIgclDdc
{
    const uint CTL_IMPL_MAJOR_VERSION = 1;
    const uint CTL_IMPL_MINOR_VERSION = 0;
    const uint CTL_OPERATION_TYPE_WRITE = 2;
    const uint LOAD_LIBRARY_SEARCH_SYSTEM32 = 0x00000800;
    const uint CTL_I2C_FLAG_DRIVER_OVERRIDE = 1u << 7;
    const uint CTL_I2C_FLAG_SPEED_BIT_BASH = 1u << 6;
    const uint CTL_I2C_FLAG_START = 1u << 8;
    const uint CTL_I2C_FLAG_STOP = 1u << 9;

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetDefaultDllDirectories(uint DirectoryFlags);

    [StructLayout(LayoutKind.Sequential)]
    struct CtlApplicationId
    {
        public uint Data1;
        public ushort Data2;
        public ushort Data3;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
        public byte[] Data4;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct CtlInitArgs
    {
        public uint Size;
        public byte Version;
        public uint AppVersion;
        public uint flags;
        public uint SupportedVersion;
        public CtlApplicationId ApplicationUID;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct CtlI2cAccessArgs
    {
        public uint Size;
        public byte Version;
        public uint DataSize;
        public uint Address;
        public uint OpType;
        public uint Offset;
        public uint Flags;
        public ulong RAD;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 128)]
        public byte[] Data;
    }

    [DllImport("ControlLib.dll", CallingConvention = CallingConvention.Cdecl)]
    static extern uint ctlInit(ref CtlInitArgs init, out IntPtr apiHandle);

    [DllImport("ControlLib.dll", CallingConvention = CallingConvention.Cdecl)]
    static extern uint ctlClose(IntPtr apiHandle);

    [DllImport("ControlLib.dll", CallingConvention = CallingConvention.Cdecl)]
    static extern uint ctlEnumerateDevices(IntPtr apiHandle, ref uint count, [Out] IntPtr[] devices);

    [DllImport("ControlLib.dll", CallingConvention = CallingConvention.Cdecl)]
    static extern uint ctlEnumerateDisplayOutputs(IntPtr device, ref uint count, [Out] IntPtr[] outputs);

    [DllImport("ControlLib.dll", CallingConvention = CallingConvention.Cdecl)]
    static extern uint ctlI2CAccess(IntPtr displayOutput, ref CtlI2cAccessArgs args);

    static uint MakeVersion(uint major, uint minor)
    {
        return (major << 16) | (minor & 0x0000ffff);
    }

    static byte Checksum(byte source, byte length, byte opcode, byte vcp, byte high, byte low)
    {
        return (byte)(0x6E ^ source ^ length ^ opcode ^ vcp ^ high ^ low);
    }

    static void Check(uint result, string call)
    {
        if (result != 0)
            Console.WriteLine(call + " returned 0x" + result.ToString("X8"));
    }

    static IntPtr Init()
    {
        SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32);

        var init = new CtlInitArgs();
        init.Size = (uint)Marshal.SizeOf(typeof(CtlInitArgs));
        init.Version = 0;
        init.AppVersion = MakeVersion(CTL_IMPL_MAJOR_VERSION, CTL_IMPL_MINOR_VERSION);
        init.flags = 0;
        init.ApplicationUID = new CtlApplicationId { Data4 = new byte[8] };

        IntPtr api;
        uint result = ctlInit(ref init, out api);
        if (result != 0)
            throw new Exception("ctlInit returned 0x" + result.ToString("X8"));
        return api;
    }

    static IntPtr[] EnumerateDevices(IntPtr api)
    {
        uint count = 0;
        uint result = ctlEnumerateDevices(api, ref count, null);
        if (result != 0)
            throw new Exception("ctlEnumerateDevices(count) returned 0x" + result.ToString("X8"));
        var devices = new IntPtr[count];
        result = ctlEnumerateDevices(api, ref count, devices);
        if (result != 0)
            throw new Exception("ctlEnumerateDevices(handles) returned 0x" + result.ToString("X8"));
        return devices;
    }

    static IntPtr[] EnumerateOutputs(IntPtr device)
    {
        uint count = 0;
        uint result = ctlEnumerateDisplayOutputs(device, ref count, null);
        if (result != 0)
        {
            Check(result, "ctlEnumerateDisplayOutputs(count)");
            return new IntPtr[0];
        }

        var outputs = new IntPtr[count];
        result = ctlEnumerateDisplayOutputs(device, ref count, outputs);
        if (result != 0)
        {
            Check(result, "ctlEnumerateDisplayOutputs(handles)");
            return new IntPtr[0];
        }
        return outputs;
    }

    public static int Scan()
    {
        IntPtr api = Init();
        try
        {
            var devices = EnumerateDevices(api);
            Console.WriteLine("Intel adapter count: " + devices.Length);
            for (int i = 0; i < devices.Length; i++)
            {
                var outputs = EnumerateOutputs(devices[i]);
                Console.WriteLine("Adapter " + i + " display output count: " + outputs.Length);
                for (int j = 0; j < outputs.Length; j++)
                    Console.WriteLine("  Output " + j + ": 0x" + outputs[j].ToInt64().ToString("X"));
            }
            return 0;
        }
        finally
        {
            ctlClose(api);
        }
    }

    static uint TryI2cWrite(IntPtr output, byte inputValue, byte i2cAddress, byte offset, bool withOverride, bool includeSourceInData, string label)
    {
        var args = new CtlI2cAccessArgs();
        args.Size = (uint)Marshal.SizeOf(typeof(CtlI2cAccessArgs));
        args.Version = 0;
        args.Address = i2cAddress;
        args.OpType = CTL_OPERATION_TYPE_WRITE;
        args.Offset = offset;
        args.Flags = withOverride
            ? CTL_I2C_FLAG_DRIVER_OVERRIDE | CTL_I2C_FLAG_SPEED_BIT_BASH | CTL_I2C_FLAG_START | CTL_I2C_FLAG_STOP
            : 0;
        args.RAD = 0;
        args.Data = new byte[128];

        byte checksum = Checksum(0x50, 0x84, 0x03, 0xF4, 0x00, inputValue);
        if (includeSourceInData)
        {
            args.DataSize = 7;
            args.Data[0] = 0x50;
            args.Data[1] = 0x84;
            args.Data[2] = 0x03;
            args.Data[3] = 0xF4;
            args.Data[4] = 0x00;
            args.Data[5] = inputValue;
            args.Data[6] = checksum;
        }
        else
        {
            args.DataSize = 6;
            args.Data[0] = 0x84;
            args.Data[1] = 0x03;
            args.Data[2] = 0xF4;
            args.Data[3] = 0x00;
            args.Data[4] = inputValue;
            args.Data[5] = checksum;
        }

        uint result = ctlI2CAccess(output, ref args);
        Console.WriteLine(label + " output 0x" + output.ToInt64().ToString("X") + " value 0x" + inputValue.ToString("X2") + " -> 0x" + result.ToString("X8"));
        return result;
    }

    public static int SwitchInput(byte inputValue, byte sourceAddress)
    {
        IntPtr api = Init();
        int success = 0;
        try
        {
            var devices = EnumerateDevices(api);
            foreach (var device in devices)
            {
                foreach (var output in EnumerateOutputs(device))
                {
                    uint result1 = TryI2cWrite(output, inputValue, 0x6E, 0x50, false, false, "addr6e-off50");
                    uint result2 = TryI2cWrite(output, inputValue, 0x6E, 0x50, true, false, "addr6e-off50-override");
                    uint result3 = TryI2cWrite(output, inputValue, 0x37, 0x50, false, false, "addr37-off50");
                    uint result4 = TryI2cWrite(output, inputValue, 0x37, 0x50, true, false, "addr37-off50-override");
                    uint result5 = TryI2cWrite(output, inputValue, 0x6E, 0x00, false, true, "addr6e-fullpacket");
                    uint result6 = TryI2cWrite(output, inputValue, 0x6E, 0x00, true, true, "addr6e-fullpacket-override");

                    if (result1 == 0 || result2 == 0 || result3 == 0 || result4 == 0 || result5 == 0 || result6 == 0)
                        success++;
                }
            }
        }
        finally
        {
            ctlClose(api);
        }
        return success > 0 ? 0 : 1;
    }
}
"@

if (-not ("IntelIgclDdc" -as [type])) {
    Add-Type -TypeDefinition $csharp
}

if ($InputName -eq "scan") {
    $code = [IntelIgclDdc]::Scan()
    exit $code
}

$value = [byte] $inputValues[$InputName]
$code = [IntelIgclDdc]::SwitchInput($value, [byte] $sourceAddress)
exit $code
