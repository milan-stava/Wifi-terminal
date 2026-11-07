# WiFi Terminal 1.1 - EL/MB release notes

A shared main source builds the standalone terminal and the setup component using IFDEF setup. Version 1.0 remains unchanged in the historical archive.

## Editor and display

The editor uses ROM stream 1 on physical rows 22-23. UART output uses ROM stream 2 on rows 0-21. The ROM handles channel switching and character output, preserving the active 32/64-column mode, font, and patch banking.

The viewport holds 63 or 127 characters plus the cursor. Long commands scroll with the cursor while the complete command remains in the buffer, up to 256 characters. Enter sends the complete command. At capacity, additional input is ignored; commands are never sent automatically. The inverse cursor is 8 or 4 pixels wide.

- UP/DOWN: recall history directly into the editable command.
- LEFT/RIGHT: move the cursor.
- DELETE: remove the preceding character; typing inserts at the cursor.
- SS+W: clear the current command without sending it or clearing history.
- SS+E: set host UART to 115200; no baud-change command is sent to ESP.
- EDIT: cycle UART speeds.
- SS+Q: ask DELETE COMMAND HISTORY? Y/y confirms, N/n cancels, other letters are ignored. No Enter is required.
- CS+SS: show help again.
- SS+SPACE: return to BASIC with WiFi left on.
- SS+ENTER: return to BASIC and request WiFi power-off.

Power-off works on MB. eLeMeNt cannot switch ESP power off, although the shared exit message still reports power-off. The setup component returns with WiFi on.

## Memory and final outputs

History uses 7000-73FF, 1 KB, with WORD length plus text records.
The two-row screen backup uses 6C00-6E3F, 576 bytes; editor state uses 6E40-6E4F.
Code starts at 30000. The BASIC loader uses CLEAR 27647.

| File | Bytes |
|---|---:|
| Terminal11_el_mb.tap | 5411 |
| terminal11_el_mb.bin | 5325 |
| terminal11_el_mb_setup.bin | 5256 |

Run assembly.bat in the package root. Outputs are copied to runable/.
Two inherited assembler warnings truncate the backslash literal to the same byte 5C as version 1.0.

## Development history

The lower-screen editor replaced a design that scrolled the output area when recalling commands. Subsequent fixes addressed cursor inversion, ROM 32/64-column handling, separators after baud changes, preservation of ATE0, and immediate Y/N confirmation.

Adding standalone exit shortcuts increased the then-current TAP from 5362 to 5407 bytes; moving only the second help column two characters right added another 4 bytes, producing the final 5411-byte TAP. The setup component remained 5256 bytes.

An early setup integration measured 16113/16157/16157 bytes for standalone/flash/debug. These are historical figures, not the current WiFi Setup release sizes. Development backups remain outside this repository in the working archive.

## Verification

The current packaged setup component passed 2960 integrated editor scenarios in the assembled-code CPU model. Earlier development checks covered 2951 scenarios per variant, targeted Y/N and exit cases, and 104 real-ROM instruction scenarios for 32/64-column printing.

ROM checks cover Busy ZXrom64m and m64a4 installation with modelled banks 0/10, inverse cursor rendering, long commands, output separation, baud cycling, repeated RX scrolling, and help. BSROM tests cover all 24 rates, separators, and ATE0 preservation after RX. Banking is simulated; physical testing is not exhaustive.

Tests: tests/test_editor.ps1, optionally -Standalone; tests/test_rom_baud.ps1; tests/test_rom_width.ps1 with -RomPath and optional -M64InstallerPath; tests/verify_release.ps1.

ROM files, snapshots, and installers are not distributed.