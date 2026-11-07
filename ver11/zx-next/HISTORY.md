# WiFi Terminal 1.1 - ZX Next release notes

The Next port is based on the final EL/MB 1.1 terminal. The EL/MB sources and binaries are maintained separately.

## Outputs and startup

| File in runable/ | Bytes |
|---|---:|
| Terminal11_next.tap | 5400 |
| terminal11_next.bin | 5314 |
| terminal11_next_setup.bin | 5314 |

One main source, source/terminal11_main.asm, is used by two wrappers. Both define ZXNEXT; IFDEF setup selects the embedded component. Run assembly.bat in the package root with SjASMPlus 1.20.3. Two inherited backslash-literal warnings still produce byte 5C.

Start the TAP in 48 BASIC / USR 0 with the standard ULA display and available 48K ROM routines. It is not a .NEX file or a native NextBASIC 64/80-column application.

The loader uses CLEAR 27647, LOAD CODE, RANDOMIZE USR 30000.
History uses 7000-73FF; editor backup uses 6C00-6E3F and state uses 6E40-6E4F.
The calling setup must provide compatible RAM/ROM mapping, ROM streams, and a stack below the scratch area. IX and the stack are restored on return; interrupts are enabled.

## Next UART

- Initialization selects ESP using port 153B, bit 6 cleared.
- Port 163B is set to 18: 8N1, no flow control, break, or held UART reset.
- Rates use Next prescalers, not MB indexed baud ports.
- Fifteen rates across eight video timings cover 2400 through 2000000 baud; default is 115200.
- EDIT order: 115200, 57600, 38400, 31250, 19200, 9600, 4800, 2400, 230400, 460800, 576000, 921600, 1152000, 1500000, 2000000.
- NextReg 11 selects timing 0..7. Prescaler is rounded Fsys/baud. VGA clocks are 28, 28.571429, 29.464286, 30, 31, 32, and 33 MHz; HDMI is 27 MHz.
- Each baud write selects ESP, clears the upper three 17-bit prescaler bits through 153B=10, and writes the lower/upper seven-bit parts through 143B.
- Status RX-ready is bit 0 and TX-full is bit 1 of 133B. Read data at 143B; write data at 133B.
- MB/eLeMeNt control ports 703B/713B/7D3B are not used.

Rates are nominal and independent of the current CPU speed. High-speed transfers require validation with the actual Next and ESP.

There is no ESP power control. SS+SPACE exits with WiFi left on. SS+ENTER is ignored. CPU speed, MMU, display mode, ESP reset, and expansion-bus reset are not changed.

UART ports must be enabled and ESP must not be routed to joystick pins. Other code must not switch the shared UART to Pi while this terminal runs.

## Editing and shortcuts

The lower ROM stream provides the editor on rows 22-23; the upper 22 rows display UART output. UP/DOWN recalls history into the editor. LEFT/RIGHT moves the cursor, DELETE removes the preceding character, and typing inserts text.

Long commands use a scrolling viewport; the complete command remains in the buffer, up to 256 bytes. Enter sends all of it. Additional characters at capacity are ignored without sending.

The inverse cursor and printing use ROM behavior, including compatible m64 32/64-column patches; native NextBASIC printing is not implemented.

SS+W clears the command. SS+Q clears history after Y/y; N/n cancels, other letters are ignored. Confirmation is immediate, without Enter.
EDIT cycles rates; SS+E sets host UART to 115200. CS+SS shows help. Existing CAPS LOCK, TRUE/INV VIDEO, and CIPSEND functions are retained.
The information screen identifies version 1.1 for ZX Next, copyright 2020-26.

## Verification

- 2951 modelled editor/history scenarios for the packaged setup component.
- 131 Next UART scenarios per variant, including all 120 rate/timing combinations, stale Pi selection, upper prescaler bits, frame setup, EDIT, SS+E, RX, printed rates, and permitted ports.
- Earlier checks executed 86 Busy/m64 ROM scenarios for both variants.
- BSROM checks cover 15 rates, separators, and ATE0 preservation.
- TAP verification checks blocks, checksums, CODE/BIN equality, loader, and memory layout.

Tests execute assembled Z80 code with modelled hardware; they are not exhaustive physical or FPGA testing. ROM files, snapshots, and the m64 installer are not distributed.

Run tests/test_editor.ps1 or tests/test_uart_next.ps1, optionally with -Standalone.
ROM tests accept -RomPath and, where needed, -M64InstallerPath.
Run tests/verify_release.ps1 for package checks.

## Integration and references

The setup component is included in the separate WiFi Setup 1.8 Next release. Early development size experiments predated the complete setup port and should not be treated as current release measurements.

- https://wiki.specnext.dev/UART_Control
- https://wiki.specnext.dev/UART_Frame
- https://wiki.specnext.dev/UART_RX
- https://wiki.specnext.dev/UART_TX
- https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/-/raw/master/cores/zxnext/nextreg.txt