#!/usr/bin/env python3
"""Install the official Map Downloader in an isolated temporary home only."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='uleapp-map-live-') as directory:
 folder=Path(directory).resolve(); source=folder/'main.swift'
 source.write_text('''import Foundation
import AppKit
let home = URL(fileURLWithPath: CommandLine.arguments[1]).resolvingSymlinksInPath()
let store = DirectMacStore(home: home)
let tool = LEAPPTool.all.first { $0.id == "mapdownloader" }!
do {
    let installed = try DirectMacInstaller().install(tool, store: store, cancellation: DirectMacCancellation(), phase: { print($0) }, progress: { _ in })
    let selected = try store.current(tool)!
    precondition(selected.0.version == installed.version && selected.1.path.hasPrefix(home.path + "/"))
    try DirectMacInstaller.assessPublisher(selected.1)
    let quarantine = try DirectMacInstaller.command("/usr/bin/xattr", ["-p", "com.apple.quarantine", selected.1.path])
    precondition(quarantine.contains(";uLEAPP;"))
    print("PASS: official Map Downloader download, checksum, version, architecture, publisher identity, Gatekeeper, quarantine and isolated selected record.")
} catch { FileHandle.standardError.write(Data((error.localizedDescription + "\\n").utf8)); exit(1) }
''')
 sources=[str(p) for p in sorted((root/'Sources').glob('*.swift')) if p.name!='main.swift']
 binary=folder/'map-live'
 subprocess.run(['xcrun','swiftc','-swift-version','5','-module-cache-path',str(root/'build/module-cache'),*sources,str(source),'-o',str(binary)],check=True)
 subprocess.run([str(binary),str(folder/'home')],check=True,timeout=600)
