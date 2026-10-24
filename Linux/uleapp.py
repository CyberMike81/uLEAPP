#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""uLEAPP Linux desktop interface. No app downloads occur on startup; optional release metadata is checked."""
import argparse
from pathlib import Path
import queue
import sys
import threading
import webbrowser
from self_update import check_update
from cleanup import old_installs, trash_old_installs
from core import TOOLS, VERSION, Store, architecture, latest, needs_update, Cancelled, check_cancel


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', action='version', version='uLEAPP ' + VERSION)
    parser.add_argument('--no-update-check', action='store_true', help='Disable automatic uLEAPP update requests for this run')
    parser.add_argument('--smoke-test', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument('--demo', action='store_true', help='Preview without downloads or launching apps')
    args = parser.parse_args()
    if sys.platform != 'linux' and not args.demo:
        parser.error('This build runs on Linux. Use --demo to preview elsewhere.')
    import tkinter as tk
    from tkinter import ttk, messagebox

    root = tk.Tk()
    root.title('uLEAPP for Linux')
    root.geometry('920x720')
    root.minsize(800, 640)
    style = ttk.Style(root)
    style.theme_use('clam')
    style.configure('.', background='#18211c', foreground='#edf5ef', font=('Sans', 11))
    style.configure('TButton', padding=(10, 5), background='#2c4031')
    style.map('TButton', background=[('active', '#405c44')], foreground=[('disabled', '#89938b')])
    style.configure('Heading.TLabel', font=('Sans', 22, 'bold'))
    root.configure(background='#18211c')
    store = Store()
    from preferences import load_automatic, save_automatic
    automatic_updates = tk.BooleanVar(value=not args.no_update_check and load_automatic(store.root))
    arch = architecture()
    events = queue.Queue()
    releases, records, row_status, actions, launches = {}, {}, {}, {}, {}
    busy = False
    cancellation = threading.Event()
    title = tk.StringVar(value='One place. Every LEAPP up to date.')
    subtitle = tk.StringVar(value='Check for releases to install or update your tools.')
    frame = ttk.Frame(root, padding=16)
    frame.pack(fill='both', expand=True)
    ttk.Label(frame, text='uLEAPP FOR LINUX · ' + VERSION, foreground='#8ee563').pack(anchor='w')
    ttk.Label(frame, textvariable=title, style='Heading.TLabel').pack(anchor='w', pady=(8, 4))
    ttk.Label(frame, textvariable=subtitle, wraplength=850).pack(anchor='w', pady=(0, 18))
    app_update = {}
    def set_automatic():
        try: save_automatic(store.root, automatic_updates.get())
        except Exception as error: append('Could not save update preference: ' + str(error))
        if automatic_updates.get(): check_self_update(schedule=False)
        else: update_banner.pack_forget()
    preference = ttk.Checkbutton(frame, text='Check for uLEAPP updates automatically', variable=automatic_updates, command=set_automatic)
    preference.pack(anchor='w', pady=(0, 8))
    if args.no_update_check or args.demo: preference.configure(state='disabled')

    update_banner = ttk.Frame(frame)
    app_update_text = tk.StringVar()
    ttk.Label(update_banner, textvariable=app_update_text, foreground='#8ee563').pack(side='left')
    ttk.Button(update_banner, text='Download update', command=lambda: webbrowser.open(app_update['url'])).pack(side='right')
    ttk.Button(update_banner, text='Release notes', command=lambda: webbrowser.open(app_update['page'])).pack(side='right', padx=8)
    rows = ttk.Frame(frame)
    rows.pack(fill='x')
    rows.columnconfigure(0, weight=1)
    log = tk.Text(frame, height=4, background='#101712', foreground='#d6e6d9',
                  relief='flat', wrap='word', state='disabled')

    def append(text):
        log.configure(state='normal')
        log.insert('end', text + '\n')
        log.see('end')
        log.configure(state='disabled')

    def refresh_buttons():
        for tool in TOOLS:
            record, release = records.get(tool.id), releases.get(tool.id)
            available = release and (not record or needs_update(record['version'], release.version))
            actions[tool.id].configure(text='Update' if record else 'Install',
                                      state='normal' if available and not busy else 'disabled')
            launches[tool.id].configure(state='normal' if record and not busy else 'disabled')
        check.configure(state='disabled' if busy else 'normal')
        cleanup.configure(state='disabled' if busy or args.demo else 'normal')
        stop.configure(state='normal' if busy and not cancellation.is_set() else 'disabled')
        update.configure(state='normal' if not busy and any(
            t.id in releases and t.id in records and needs_update(records[t.id]['version'], releases[t.id].version)
            for t in TOOLS) else 'disabled')

    def run(work):
        nonlocal busy
        if busy: return
        busy = True
        cancellation.clear()
        refresh_buttons()
        def worker():
            try: work()
            except Cancelled: events.put(('stopped', None))
            except Exception as error: events.put(('error', str(error)))
            finally: events.put(('done', None))
        threading.Thread(target=worker, daemon=True).start()

    def check_releases():
        def work():
            for tool in TOOLS:
                check_cancel(cancellation)
                events.put(('status', (tool.id, 'Checking…')))
                try:
                    if args.demo:
                        events.put(('status', (tool.id, 'Demo · no changes')))
                        continue
                    release = latest(tool, arch, cancellation)
                    events.put(('release', (tool.id, release)))
                except Cancelled: raise
                except Exception as error:
                    events.put(('unavailable', (tool.id, str(error))))
        run(work)

    def install_tools(tools):
        selected = list(tools)
        if any(t.id == 'lava' for t in selected):
            if not messagebox.askyesno('LAVA license',
                'LAVA is freeware with separate terms. Review its license using the LAVA license link below. '
                'Have you reviewed and accepted those terms?', parent=root): return
        def work():
            for tool in selected:
                check_cancel(cancellation)
                try:
                    events.put(('status', (tool.id, 'Downloading…')))
                    record = store.install(tool, releases[tool.id],
                        lambda fraction, tid=tool.id: events.put(('status', (tid, f'Downloading {fraction:.0%}'))), cancellation)
                    events.put(('installed', (tool.id, record)))
                except Cancelled:
                    events.put(('status', (tool.id, 'Stopped')))
                    raise
                except Exception as error:
                    events.put(('status', (tool.id, 'Needs attention')))
                    events.put(('error', tool.name + ': ' + str(error)))
        if not args.demo: run(work)

    def review_cleanup(candidates):
        if busy or args.demo: return
        if not candidates:
            messagebox.showinfo('Remove old installs', 'No eligible old installs. The current and previous versions, changed folders and older copies without a file inventory are kept.', parent=root)
            return
        detail = 'Keep the current and one previous version of each tool. Move these older installs to Trash?\n\n' + '\n'.join(item.label for item in candidates)
        if not messagebox.askyesno('Remove old installs', detail, parent=root): return
        def work():
            moved = trash_old_installs(store, candidates, cancellation,
                progress=lambda item: events.put(('cleanup_log', item.label + ': moved to Trash')))
            events.put(('cleanup_log', f'{len(moved)} old installs moved to Trash. Current and previous versions kept.'))
        run(work)

    def scan_old_installs():
        if args.demo: return
        def work():
            candidates = old_installs(store, cancel=cancellation)
            check_cancel(cancellation)
            events.put(('cleanup_review', candidates))
        run(work)

    def show_launch_error(tool, message):
        dialog = tk.Toplevel(root)
        dialog.title('Could not start ' + tool.name)
        dialog.transient(root)
        dialog.geometry('760x430')
        dialog.minsize(480, 280)
        content = ttk.Frame(dialog, padding=16)
        content.pack(fill='both', expand=True)
        ttk.Label(content, text=tool.name + ' exited with an error', font=('Sans', 13, 'bold')).pack(anchor='w', pady=(0, 10))
        details = ttk.Frame(content)
        details.pack(fill='both', expand=True)
        text = tk.Text(details, wrap='word', background='#101712', foreground='#edf5ef', relief='flat')
        scrollbar = ttk.Scrollbar(details, command=text.yview)
        text.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side='right', fill='y')
        text.pack(fill='both', expand=True)
        text.insert('1.0', message)
        text.configure(state='disabled')
        buttons = ttk.Frame(content)
        buttons.pack(fill='x', pady=(12, 0))
        def copy_error():
            root.clipboard_clear()
            root.clipboard_append(message)
        ttk.Button(buttons, text='Copy error', command=copy_error).pack(side='left')
        ttk.Button(buttons, text='Close', command=dialog.destroy).pack(side='right')
        dialog.grab_set()
        text.focus_set()

    def launch(tool):
        if busy or args.demo: return
        try:
            launch = store.launch(tool)
            append('Opening ' + tool.name + '. Log: ' + str(launch.log_path))
            def check_exit():
                code = launch.poll()
                if code is None:
                    root.after(500, check_exit)
                elif code != 0:
                    message = launch.failure_message()
                    append(tool.name + ': ' + message)
                    show_launch_error(tool, message)
            root.after(500, check_exit)
        except Exception as error: messagebox.showerror('Could not launch ' + tool.name, str(error), parent=root)

    for index, tool in enumerate(TOOLS):
        try:
            record = None if args.demo else store.installed(tool)
            if record: records[tool.id] = record
            status = record['version'] + ' · Installed' if record else 'Not installed'
        except Exception as error: status = 'Needs attention: ' + str(error)
        ttk.Label(rows, text=tool.name, font=('Sans', 13, 'bold')).grid(row=index, column=0, sticky='w', pady=5)
        row_status[tool.id] = tk.StringVar(value=status)
        ttk.Label(rows, textvariable=row_status[tool.id], wraplength=380).grid(row=index, column=1, padx=12)
        launches[tool.id] = ttk.Button(rows, text='Launch', command=lambda t=tool: launch(t))
        launches[tool.id].grid(row=index, column=2, padx=4)
        actions[tool.id] = ttk.Button(rows, text='Install', command=lambda t=tool: install_tools([t]))
        actions[tool.id].grid(row=index, column=3, padx=4)
    controls = ttk.Frame(frame)
    controls.pack(fill='x', pady=10)
    def request_stop():
        cancellation.set()
        subtitle.set('Stopping downloads; completed installations are kept.')
        refresh_buttons()
    stop = ttk.Button(controls, text='Stop', command=request_stop)
    stop.pack(side='right', padx=4)
    check = ttk.Button(controls, text='Check for updates', command=check_releases)
    check.pack(side='right')
    update = ttk.Button(controls, text='Update installed apps', command=lambda: install_tools(
        t for t in TOOLS if t.id in records and t.id in releases and needs_update(records[t.id]['version'], releases[t.id].version)))
    update.pack(side='right', padx=8)
    ttk.Button(controls, text='LAVA license', command=lambda: webbrowser.open(
        'https://github.com/leapps-org/LAVA-releases/blob/main/LICENSE')).pack(side='left')
    cleanup = ttk.Button(frame, text='Remove old installs', command=scan_old_installs)
    cleanup.pack(anchor='w', pady=(0, 8))
    ttk.Label(frame, text='Close LEAPP apps before updating. Older versions and case files are kept.',
              wraplength=850).pack(anchor='w', pady=(0, 8))
    log.pack(fill='both', expand=True)
    append('Demo mode · no downloads or apps will run.' if args.demo else 'Apps: ' + str(store.root / 'apps'))

    def poll():
        nonlocal busy
        for _ in range(100):
            try: kind, value = events.get_nowait()
            except queue.Empty: break
            if kind == 'done':
                busy = False
                subtitle.set('Stopped. Completed installations have been kept.' if cancellation.is_set() else 'Finished. Review the app statuses and details below.')
            elif kind == 'cleanup_review': root.after_idle(lambda candidates=value: review_cleanup(candidates))
            elif kind == 'cleanup_log': append(value)
            elif kind == 'stopped': append('Stopped at your request.')
            elif kind == 'app_update':
                if value and automatic_updates.get():
                    app_update.update(value)
                    app_update_text.set('uLEAPP ' + value['version'] + ' is available')
                    update_banner.pack(fill='x', pady=(0, 10), before=rows)
            elif kind == 'error': append(value)
            elif kind in ('status', 'unavailable'):
                tid, text = value
                row_status[tid].set(text if kind == 'status' else 'Unavailable · see details')
                if kind == 'unavailable':
                    releases.pop(tid, None)
                    append(tid + ': ' + text)
            elif kind == 'release':
                tid, release = value
                releases[tid] = release
                record = records.get(tid)
                text = ('Update available · ' if record and needs_update(record['version'], release.version)
                        else 'Up to date · ' if record else 'Available · ')
                row_status[tid].set(text + release.version)
            elif kind == 'installed':
                tid, record = value
                records[tid] = record
                row_status[tid].set(record['version'] + ' · Installed')
                append(tid + ': installed and verified')
        refresh_buttons()
        root.after(100, poll)

    def close():
        if busy:
            messagebox.showinfo('Operation in progress', 'Wait for the current downloads and installations to finish before closing.', parent=root)
        else: root.destroy()
    def check_self_update(schedule=True):
        if schedule: root.after(24 * 60 * 60 * 1000, check_self_update)
        if args.demo or args.smoke_test or args.no_update_check or not automatic_updates.get(): return
        def work():
            try: events.put(('app_update', check_update()))
            except Exception as error: events.put(('error', 'uLEAPP update check: ' + str(error)))
        threading.Thread(target=work, daemon=True).start()
    root.after(500, check_self_update)
    root.update_idletasks()
    available_width = max(720, root.winfo_screenwidth() - 48)
    available_height = max(520, root.winfo_screenheight() - 80)
    root.minsize(min(840, available_width), min(620, available_height))
    root.geometry(f'{min(1000, available_width)}x{min(max(root.winfo_reqheight(), 660), available_height)}')
    root.protocol('WM_DELETE_WINDOW', close)
    refresh_buttons()
    root.after(100, poll)
    if args.smoke_test:
        assert len(actions) == len(TOOLS) and len(launches) == len(TOOLS)
        assert cleanup.cget('text') == 'Remove old installs'
        if args.demo: assert cleanup.instate(['disabled'])
        root.update_idletasks()
        sample = 'The app exited with exit code 7.\n\nUnable to load libexample.so\n\nLaunch log: /tmp/example.log'
        show_launch_error(TOOLS[-1], sample)
        def descendants(widget):
            for child in widget.winfo_children():
                yield child
                yield from descendants(child)
        widgets = list(descendants(root))
        error_texts = [widget for widget in widgets if isinstance(widget, tk.Text) and sample in widget.get('1.0', 'end')]
        assert len(error_texts) == 1
        copy = next(widget for widget in widgets if isinstance(widget, ttk.Button) and widget.cget('text') == 'Copy error')
        copy.invoke()
        assert root.clipboard_get() == sample
        root.after(300, root.destroy)
    root.mainloop()


if __name__ == '__main__': main()
