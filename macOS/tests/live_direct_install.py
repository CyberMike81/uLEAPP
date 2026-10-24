#!/usr/bin/env python3
"""Optional network integration: install official ALEAPP into an isolated temp home.
Leaves real Applications, Homebrew receipts and uLEAPP settings unchanged.
SPDX-License-Identifier: MIT
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='uleapp-direct-live-') as directory:
    temporary = Path(directory).resolve()
    source = temporary / 'main.swift'
    source.write_text('''import Foundation
import AppKit
let home = URL(fileURLWithPath: CommandLine.arguments[1]).resolvingSymlinksInPath()
let store = DirectMacStore(home: home)
var tool = LEAPPTool.all.first { $0.id == "aleapp-gui" }!
tool.version = "2026.4.3"
do {
    DirectMacInstaller.selfCheck()
    let result = try DirectMacInstaller().install(tool, store: store, cancellation: DirectMacCancellation(),
        phase: { print($0) }, progress: { _ in })
    let selected = try store.current(tool)!
    precondition(selected.0.version == result.version)
    precondition(selected.1.path.hasPrefix(home.path + "/"))
    precondition(FileManager.default.fileExists(atPath: selected.1.appendingPathComponent("Contents/Info.plist").path))
    try DirectMacInstaller.command("/usr/bin/codesign", ["--verify", "--strict", "--deep", selected.1.path])
    print("PASS: official download, checksum, disk-image mount, app version, architecture, signature, copy and selected-install record verified in a temporary home.")
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\\n").utf8))
    exit(1)
}
''')
    binary = temporary / 'test-direct'
    sources = sorted(str(p) for p in (root / 'Sources').glob('*.swift') if p.name != 'main.swift')
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-module-cache-path', str(root / 'build/module-cache'), *sources, str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary), str(temporary / 'home')], check=True, timeout=1200)
