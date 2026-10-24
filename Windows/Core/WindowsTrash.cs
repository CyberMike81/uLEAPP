// SPDX-License-Identifier: MIT
using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;

namespace uLEAPP;

// IFileOperation's RECYCLEONDELETE explicitly requests recycling, rather than
// falling back to a permanent directory deletion. There is no delete fallback.
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
        IFileOperation? operation = null;
        IShellItem? item = null;
        try {
            operation = (IFileOperation)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("3AD05575-8857-4850-9277-11B85BDB8E09"))!)!;
            const uint Silent = 0x4, NoConfirmation = 0x10, NoErrorUI = 0x400;
            const uint RecycleOnDelete = 0x80000, EarlyFailure = 0x100000, AddUndoRecord = 0x20000000;
            operation.SetOperationFlags(Silent | NoConfirmation | NoErrorUI | RecycleOnDelete | EarlyFailure | AddUndoRecord);
            Guid iid = typeof(IShellItem).GUID;
            SHCreateItemFromParsingName(Path.GetFullPath(folder),IntPtr.Zero,ref iid,out item);
            operation.DeleteItem(item,IntPtr.Zero);
            operation.PerformOperations();
            operation.GetAnyOperationsAborted(out bool aborted);
            if (aborted || Directory.Exists(folder)) throw new IOException("The old install could not be moved to the Recycle Bin. It was not permanently deleted.");
        }
        finally {
            if (item != null) Marshal.ReleaseComObject(item);
            if (operation != null) Marshal.ReleaseComObject(operation);
        }
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
        void DeleteItem(IShellItem item,IntPtr sink);
        void DeleteItems([MarshalAs(UnmanagedType.IUnknown)] object items);
        void NewItem(IShellItem destination,uint attributes,[MarshalAs(UnmanagedType.LPWStr)] string name,[MarshalAs(UnmanagedType.LPWStr)] string template,IntPtr sink);
        void PerformOperations();
        void GetAnyOperationsAborted([MarshalAs(UnmanagedType.Bool)] out bool aborted);
    }
}
