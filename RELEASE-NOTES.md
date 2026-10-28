# uLEAPP 0.3.15 — Community Preview

- Windows new installs now use the saved destination automatically, without asking for a path for each app. New users default to the per-user AppData LEAPPs folder.
- Settings → Choose folder now sets the actual parent folder for future portable installs. Existing apps stay in their selected locations.
- Added Restart as administrator in Settings and after permission failures. Windows shows its UAC prompt; cancelling keeps the original window open. After a successful restart, choose Update again.
- The restart preserves the same Windows account, saved app locations and automatic-check preferences, and waits for the original window to exit before reopening.
- Existing-location updates, rollback copies and Start menu shortcuts remain supported. Publisher setup installers keep their own location choices.

Mac and Linux are rebuilt at the same version; their functionality is unchanged.

Mac builds are ad hoc signed; Windows builds are unsigned. Linux requires Python 3.10+ and Tk.

SHA256SUMS-0.3.15.txt covers all downloads.
