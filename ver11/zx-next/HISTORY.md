# ZX Next WiFi Terminal 1.1

6. 11. 2026. Samostatná Next větev odvozená z finální EL/MB 1.1.
Finální EL/MB zdroje a výstupy zůstávají nedotčené; kontrolní součty jsou v tests/elmb-final-manifest.json.

## Výstupy

- runable/Terminal11_next.tap: 5400 B, samostatný terminál s BASIC loaderem.
- runable/terminal11_next_setup.bin: 5314 B, komponenta pro Next WiFi Setup 1.8.
- source/terminal11_next.bin: 5314 B, samotný kód samostatné varianty.

Jeden hlavní zdroj source/terminal11_main.asm, dva obaly; IFDEF setup určuje
variantu pro začlenění. Oba obaly definují ZXNEXT. Sestavení: source/assembly.bat,
SjASMPlus 1.20.3. Dvě původní výstrahy u zpětného lomítka dávají bajt #5C jako EL/MB.

TAP spouštěj v 48 BASIC / USR 0 prostředí Nextu s běžným ULA displejem a dostupnými
48K ROM rutinami. Není to .NEX ani nativní 64/80sloupcový režim NextBASICu.
Loader: CLEAR 27647, LOAD CODE, RANDOMIZE USR 30000. Start kódu 30000.
Historie #7000–#73FF (1 KB), backing editoru #6C00–#6E3F a stav #6E40–#6E4F.
Volající setup zajišťuje odpovídající mapování RAM/ROM, zásobník pod scratch oblastí
a dostupné ROM tiskové kanály. Po návratu jsou obnoveny IX/zásobník, přerušení jsou zapnutá.

## Hardware Nextu

- Inicializace explicitně vybere ESP UART přes #153B (bit 6 = 0).
- Rámec #163B = #18: 8N1, bez flow control, breaku a drženého UART resetu.
- Rychlost používá dělič Nextu, nikoli indexový port MB #7D3B.
- Tabulka 15 rychlostí × 8 časování: 2400 až 2000000 baud, výchozí 115200.
  Pořadí zůstává 115200, 57600, 38400, 31250, 19200, 9600, 4800, 2400,
  230400, 460800, 576000, 921600, 1152000, 1500000, 2000000.
- NextReg #11 čte časování 0–7; dělič = zaokrouhlené Fsys / baud.
  VGA: 28 / 28.571429 / 29.464286 / 30 / 31 / 32 / 33 MHz; HDMI: 27 MHz.
  Nezávisí na aktuální rychlosti CPU. Vyšší přenosové rychlosti vyžadují ověření
  na konkrétním ESP a Nextu; uvedená rychlost je nominální, dělič ji zaokrouhluje.
- Každý zápis rychlosti vybere ESP a vynuluje horní 3 bity 17bitového děliče
  zápisem #153B = #10, potom zapíše dolní a horní 7bitovou část do #143B.
- RX: #133B bit 0. TX: #133B bit 1 = FIFO plné. Čtení dat: #143B, zápis: #133B.
- Nepoužívají se řídicí porty MB/eLeMeNt #703B/#713B/#7D3B.
- Není zde řízení napájení ESP. SS+SPACE ukončí terminál a ponechá Wi-Fi ON.
  SS+ENTER nevypíná ESP a je ignorován; TRUE VIDEO má nadále vlastní funkci.
- Nemění se CPU speed, MMU, režim displeje ani reset ESP/expansion busu.
  Předpoklad: UART porty jsou povolené a ESP UART není přesměrovaný na joystick.
  Za běhu terminálu nesmí jiný kód přepínat sdílený UART na Pi.

## Ovládání a obrazovka

Info: ZX Next WiFi Terminal, ver 1.1; autorství 2020-26.
Editor používá spodní ROM kanál na fyzických řádcích 22–23, UART horních 22 řádků.
UP/DOWN vybírá historii přímo do editoru; LEFT/RIGHT pohyb, DELETE maže před kurzorem.
Výřez dlouhého příkazu se posouvá, příkaz v bufferu zůstává celý (nejvýše 256 B).
Enter odešle celý příkaz. Při dosažení limitu se znak ignoruje, nic se samo neodesílá.
Inverzní kurzor a tisk zůstávají vedené ROM. Kompatibilita m64 ROM 32/64 je zachovaná;
nejde o implementaci nativního NextBASIC tiskového režimu.

SS+W vymaže příkaz. SS+Q vymaže historii po jediném stisku Y/y; N/n zruší,
jiné písmeno se ignoruje. Y/N se ihned zobrazí a odřádkuje, bez Enteru.
EDIT cykluje 15 rychlostí, SS+E nastaví hostitelský UART na 115200.
CS+SS zobrazí nápovědu. CAPS LOCK, TRUE/INV VIDEO, CIPSEND a další funkce jsou zachované.

## Ověření

- 2951 scénářů editoru/historie pro každou variantu; model ROM a UART.
- 131 Next UART scénářů pro každou variantu: všech 120 rychlost/časování kombinací,
  stale Pi selection / horní bity děliče, 8N1, cyklus EDIT, SS+E, RX a povolené porty.
  Kontrolují i vytištěný číselný popis rychlosti po úsporném zabalení tabulky.
- 86 scénářů se skutečnými instrukcemi Busy ROM a m64a4 32/64 pro obě varianty:
  kurzor, editor, plný Enter, UART scrolling, help a změny rychlosti.
- Samostatná kontrola skutečné BSROM: 15 rychlostí, oddělovače a ATE0 po RX.
- TAP: struktura, checksumy, shoda CODE s BIN, loader a paměťové hranice.

CPU/ROM testy nejsou testem fyzického Nextu ani plnou FPGA emulací.
Zkušební ROM, RAM snapshot a m64 instalátor nejsou distribuované; cesty lze předat parametrům testů.

Příkazy:

powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/test_editor.ps1 [-Standalone]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/test_uart_next.ps1 [-Standalone]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/test_rom_baud.ps1 -RomPath cesta
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/test_rom_width.ps1 -RomPath cesta [-M64InstallerPath cesta] [-Standalone]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/verify_release.ps1

## Setup 1.8 a limit 16384

Tento balíček dodává hotovou terminálovou komponentu pro budoucí Next setup.
Neobsahuje dosud kompletní port hardware backendu setupu; rodičovský setup ani
referenční ZXNext/base_1.8 se nemění.

Pouhá kontrola kapacity v oddělené kopii aktuálního setupu s BIOSem Next 2.1 (698 B)
a tímto terminálem: raw standalone 16303 B, flash/debug 16347 B. Všechny ASSERT
vyžadující velikost pod 16384 prošly; rezerva největší varianty je 37 B.
Nejde o funkční Next vydání setupu: jeho zbývající MB hardware přístupy se musí teprve portovat.

## Primární dokumentace

- https://wiki.specnext.dev/UART_Control
- https://wiki.specnext.dev/UART_Frame
- https://wiki.specnext.dev/UART_RX
- https://wiki.specnext.dev/UART_TX
- https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/-/raw/master/cores/zxnext/nextreg.txt

Frekvence VGA 0–6 a identifikace HDMI 7 vycházejí z NextReg #11; HDMI 27 MHz a
prescaler mechanismus také z dokumentace UART RX. Tabulky odpovídají dříve prověřenému
BIOSu Next 2.1; výpočty se v testu ověřují nezávisle podle frekvencí.