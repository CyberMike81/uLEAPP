// SPDX-License-Identifier: MIT
using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace uLEAPP;

// Request recycling explicitly and require the shell's PostDeleteItem callback
// to identify the new item in Recycle Bin. No permanent-delete API is used.
public static class WindowsTrash
{
    public static void Move(string folder)
    {
        Exception? failure = null;
        var thread = new Thread(() => { try { Recycle(folder); } catch (Exception error) { failure = error; } });
        thread.SetApartmentState(ApartmentState.STA); thread.Start(); thread.Join();
        if (failure != null) ExceptionDispatchInfo.Capture(failure).Throw();
    }
    private static void Recycle(string folder)
    {
        RequireRecyclingDrive(folder);
        IFileOperation? operation = null;
        IShellItem? item = null;
        try {
            operation = (IFileOperation)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("3AD05575-8857-4850-9277-11B85BDB8E09"))!)!;
            const uint Silent = 0x4, NoConfirmation = 0x10, NoErrorUI = 0x400;
            const uint RecycleOnDelete = 0x80000, EarlyFailure = 0x100000, AddUndoRecord = 0x20000000;
            operation.SetOperationFlags(Silent | NoConfirmation | NoErrorUI | RecycleOnDelete | EarlyFailure | AddUndoRecord);
            Guid iid = typeof(IShellItem).GUID;
            SHCreateItemFromParsingName(Path.GetFullPath(folder),IntPtr.Zero,ref iid,out item);
            var confirmation = new RecycleConfirmation();
            operation.DeleteItem(item,confirmation);
            operation.PerformOperations();
            operation.GetAnyOperationsAborted(out bool aborted);
            if (aborted || !confirmation.Recycled || Directory.Exists(folder))
                throw new IOException("Windows did not confirm that the old install reached the Recycle Bin. Check the Recycle Bin before continuing.");
        }
        finally {
            if (item != null) Marshal.ReleaseComObject(item);
            if (operation != null) Marshal.ReleaseComObject(operation);
        }
    }
    public static bool IsSupportedDrive(DriveType drive) => drive == DriveType.Fixed;
    private static void RequireRecyclingDrive(string folder)
    {
        string root = Path.GetPathRoot(Path.GetFullPath(folder))!;
        if (!IsSupportedDrive(new DriveInfo(root).DriveType)) throw new IOException("Cleanup requires a fixed local drive with Recycle Bin support. This folder was preserved.");
        foreach (var hive in new[] { Registry.CurrentUser, Registry.LocalMachine })
        {
            using var policy = hive.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer");
            if (Convert.ToInt32(policy?.GetValue("NoRecycleFiles",0) ?? 0) != 0) throw new IOException("Recycle Bin is disabled by policy. Cleanup was refused.");
        }
        using var settings = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Explorer\BitBucket");
        if (Convert.ToInt32(settings?.GetValue("NukeOnDelete",0) ?? 0) != 0) throw new IOException("Recycle Bin is disabled. Cleanup was refused.");
        var volume = new System.Text.StringBuilder(128);
        if (!GetVolumeNameForVolumeMountPoint(root,volume,volume.Capacity)) throw new IOException("Could not verify the drive's Recycle Bin settings. Cleanup was refused.");
        string name = volume.ToString();
        int start = name.IndexOf('{'); int end = name.IndexOf('}');
        if (start < 0 || end <= start) throw new IOException("Could not identify the recycling drive. Cleanup was refused.");
        using var drive = settings?.OpenSubKey("Volume\\" + name[start..(end+1)]);
        if (Convert.ToInt32(drive?.GetValue("NukeOnDelete",0) ?? 0) != 0) throw new IOException("Recycle Bin is disabled for this drive. Cleanup was refused.");
    }
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetVolumeNameForVolumeMountPoint(string path,System.Text.StringBuilder volume,int length);

    [ComVisible(true),ClassInterface(ClassInterfaceType.None)]
    public sealed class RecycleConfirmation : IFileOperationProgressSink
    {
        public bool Recycled { get; private set; }
        public int StartOperations() => 0;
        public int FinishOperations(int result) => 0;
        public int PreRenameItem(uint flags,IntPtr item,string name) => 0;
        public int PostRenameItem(uint flags,IntPtr item,string name,int result,IntPtr created) => 0;
        public int PreMoveItem(uint flags,IntPtr item,IntPtr destination,string name) => 0;
        public int PostMoveItem(uint flags,IntPtr item,IntPtr destination,string name,int result,IntPtr created) => 0;
        public int PreCopyItem(uint flags,IntPtr item,IntPtr destination,string name) => 0;
        public int PostCopyItem(uint flags,IntPtr item,IntPtr destination,string name,int result,IntPtr created) => 0;
        public int PreDeleteItem(uint flags,IntPtr item) => 0;
        public int PostDeleteItem(uint flags,IntPtr item,int result,IntPtr created) { Recycled = result >= 0 && created != IntPtr.Zero; return Recycled ? 0 : unchecked((int)0x80004005); }
        public int PreNewItem(uint flags,IntPtr destination,string name) => 0;
        public int PostNewItem(uint flags,IntPtr destination,string name,string template,uint attributes,int result,IntPtr created) => 0;
        public int UpdateProgress(uint total,uint complete) => 0;
        public int ResetTimer() => 0;
        public int PauseTimer() => 0;
        public int ResumeTimer() => 0;
    }
    [ComVisible(true),Guid("04b0f1a7-9490-44bc-96e1-4296a31252e2"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IFileOperationProgressSink
    {
        [PreserveSig] int StartOperations();
        [PreserveSig] int FinishOperations(int result);
        [PreserveSig] int PreRenameItem(uint flags,IntPtr item,[MarshalAs(UnmanagedType.LPWStr)] string name);
        [PreserveSig] int PostRenameItem(uint flags,IntPtr item,[MarshalAs(UnmanagedType.LPWStr)] string name,int result,IntPtr created);
        [PreserveSig] int PreMoveItem(uint flags,IntPtr item,IntPtr destination,[MarshalAs(UnmanagedType.LPWStr)] string name);
        [PreserveSig] int PostMoveItem(uint flags,IntPtr item,IntPtr destination,[MarshalAs(UnmanagedType.LPWStr)] string name,int result,IntPtr created);
        [PreserveSig] int PreCopyItem(uint flags,IntPtr item,IntPtr destination,[MarshalAs(UnmanagedType.LPWStr)] string name);
        [PreserveSig] int PostCopyItem(uint flags,IntPtr item,IntPtr destination,[MarshalAs(UnmanagedType.LPWStr)] string name,int result,IntPtr created);
        [PreserveSig] int PreDeleteItem(uint flags,IntPtr item);
        [PreserveSig] int PostDeleteItem(uint flags,IntPtr item,int result,IntPtr created);
        [PreserveSig] int PreNewItem(uint flags,IntPtr destination,[MarshalAs(UnmanagedType.LPWStr)] string name);
        [PreserveSig] int PostNewItem(uint flags,IntPtr destination,[MarshalAs(UnmanagedType.LPWStr)] string name,[MarshalAs(UnmanagedType.LPWStr)] string template,uint attributes,int result,IntPtr created);
        [PreserveSig] int UpdateProgress(uint total,uint complete);
        [PreserveSig] int ResetTimer();
        [PreserveSig] int PauseTimer();
        [PreserveSig] int ResumeTimer();
    }
    [DllImport("shell32.dll",CharSet=CharSet.Unicode,PreserveSig=false)]
    private static extern void SHCreateItemFromParsingName(string path,IntPtr binding,ref Guid iid,[MarshalAs(UnmanagedType.Interface)] out IShellItem item);
    [ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IShellItem { }
    [ComImport, Guid("947AAB5F-0A5C-4C13-B4D6-4BF7836FC9F8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IFileOperation
    {
        void Advise(IntPtr sink,out uint cookie);
        void Unadvise(uint cookie);
        void SetOperationFlags(uint flags);
        void SetProgressMessage([MarshalAs(UnmanagedType.LPWStr)] string message);
        void SetProgressDialog(IntPtr dialog);
        void SetProperties(IntPtr changes);
        void SetOwnerWindow(IntPtr window);
        void ApplyPropertiesToItem(IShellItem item);
        void ApplyPropertiesToItems([MarshalAs(UnmanagedType.IUnknown)] object items);
        void RenameItem(IShellItem item,[MarshalAs(UnmanagedType.LPWStr)] string name,IntPtr sink);
        void RenameItems([MarshalAs(UnmanagedType.IUnknown)] object items,[MarshalAs(UnmanagedType.LPWStr)] string name);
        void MoveItem(IShellItem item,IShellItem destination,[MarshalAs(UnmanagedType.LPWStr)] string name,IntPtr sink);
        void MoveItems([MarshalAs(UnmanagedType.IUnknown)] object items,IShellItem destination);
        void CopyItem(IShellItem item,IShellItem destination,[MarshalAs(UnmanagedType.LPWStr)] string name,IntPtr sink);
        void CopyItems([MarshalAs(UnmanagedType.IUnknown)] object items,IShellItem destination);
        void DeleteItem(IShellItem item,[MarshalAs(UnmanagedType.Interface)] IFileOperationProgressSink sink);
        void DeleteItems([MarshalAs(UnmanagedType.IUnknown)] object items);
        void NewItem(IShellItem destination,uint attributes,[MarshalAs(UnmanagedType.LPWStr)] string name,[MarshalAs(UnmanagedType.LPWStr)] string template,IntPtr sink);
        void PerformOperations();
        void GetAnyOperationsAborted([MarshalAs(UnmanagedType.Bool)] out bool aborted);
    }
}
