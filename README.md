# Chaos Theory Local Fix

A reversible Windows PowerShell installer for **ThirteenAG's Splinter Cell: Chaos Theory Widescreen Fix**. Designed to make setup easy on modern PCs, including AMD systems.

The first version was reported working by its user on Windows 11 with a Ryzen 9 5900X and Radeon RX 9070. The new Steam detection and process-closing features still need Windows testing. This is not a universal AMD driver fix.

## Install

1. Install Chaos Theory through Steam. Save your progress and exit the game.
2. Download this repository using **Code → Download ZIP**, then extract it.
3. Double-click **Install-Borderless.cmd**.
4. Launch normally from Steam once installation succeeds.

The launcher finds the PowerShell script relative to its own location, so the download folder does not matter. The script locates Steam through the registry, reads its library list, and checks app ID **13570**. If it cannot find one unambiguous installation, it asks for a path. Game-folder, System-folder and executable paths are accepted.

If the selected game is running, the script offers to close it. Closing can lose unsaved progress. It tries a normal close first, then terminates that game process if necessary. It does not kill other games or Steam.

## What changes

- Downloads the current official Chaos Theory ZIP directly from ThirteenAG's GitHub release.
- Installs its files under this game's **System** folder only, including upstream audio/controller components.
- Sets a 60 FPS cap to avoid known AI/physics issues at higher rates.
- Enables raw mouse data and skips startup intros.
- The double-click launcher enables borderless fullscreen.
- Preserves upstream resolution and shadow defaults.
- Backs up all overwritten files, records hashes and attempts rollback after installation errors.

No registry writes, global execution-policy changes, Windows compatibility flags, driver changes, firewall changes, or settings for other games. It reads Steam's registry paths only. Downloads use HTTPS; the script verifies GitHub's SHA-256 digest when supplied by GitHub. The upstream release is fetched at runtime and can change independently of this repository.

## PowerShell options

```powershell
# Automatic Steam detection; fullscreen defaults
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-ChaosTheory.ps1

# Borderless, explicit game path
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-ChaosTheory.ps1 -Borderless -GamePath "A:\SteamLibrary\steamapps\common\Splintercell Chaos Theory"

# Explicitly authorize closing the selected game without prompting
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-ChaosTheory.ps1 -Borderless -CloseGame

# Restore original files
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-ChaosTheory.ps1 -Undo
```

`ExecutionPolicy Bypass` applies only to this process. No permanent execution-policy change is made. Windows PowerShell 5.1 or newer is required. Internet access is required for installation. Start without administrator privileges; protected game directories may require write permission.

## Undo and reinstall

Double-click **Undo.cmd**, or run the undo command above. Originals live in **ChaosTheory-Fix-Backup** inside the game folder. Keep that folder until you are finished with the patch.

Undo checks installed-file and backup hashes before restoring. If another mod or Steam has changed an installed file, undo stops instead of overwriting that change. Inspect the backup and resolve the conflict manually. Restore may leave empty directories behind.

After a successful undo, move the backup folder somewhere safe before installing again. The script refuses to overwrite an existing backup, including one retained after a failed attempt.

## Limitations and testing

Test night vision, thermal vision, optic cable, sticky cameras, audio, and your preferred controls in the first mission. AMD vision-mode problems are not guaranteed to be solved. This does not repair original-disc DRM, install every legacy runtime, or restore online multiplayer services. Co-op/Versus compatibility is not verified.

Do not run Steam verification, another mod installer, or the game while this installer runs. Ordinary errors trigger rollback; power loss or forcibly terminating PowerShell can interrupt it. Backups are retained for recovery.

The supplied workflow parses the script under Windows PowerShell and PowerShell 7; it does not test the game or download/install the patch. Contributions with reproducible test results are welcome. Include Windows version, GPU, storefront, relevant error output, and which vision modes fail; omit personal information.

## Credits

All game patches belong to their respective authors. This repository distributes installer code only, not game files or patch binaries.

- [ThirteenAG's official Chaos Theory release](https://github.com/ThirteenAG/WidescreenFixesPack/releases/tag/scct)
- [Upstream documentation](https://github.com/ThirteenAG/WidescreenFixesPack/blob/master/.github/docs/scct.md)
- [Upstream source and license](https://github.com/ThirteenAG/WidescreenFixesPack)

Not affiliated with Ubisoft, AMD, Valve, or ThirteenAG. The MIT license here covers this repository's original installer code only.
