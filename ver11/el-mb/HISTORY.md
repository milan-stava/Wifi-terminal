# ELMB WiFi Terminal 1.1

6. 11. 2026. Společný zdroj pro samostatný terminál a součást setupu (IFDEF setup).
Verze 1.0 je nedotčená.

Editor nyní používá spodní kanál ROM (stream 1), fyzické řádky 22–23.
Výpis UARTu používá horní kanál ROM (stream 2), řádky 0–21. Odpadá
odrolování horního výpisu kvůli editoru. Přepnutí kanálů a tisk znaků zajišťuje
ROM; zachovává se aktivní režim 32/64 znaků, font i bankovní obsluha patche.

Výřez obsahuje 63/127 znaků plus pozici kurzoru. Dlouhý příkaz se posouvá
s kurzorem, celý obsah zůstává v bufferu (nejvýše 256 znaků). Enter odešle
celý příkaz, nikoli jen viditelný výřez nebo část před kurzorem. Na limitu
se další znak nevloží a příkaz se sám neodešle. Kurzor je inverzní, 8/4 pixely.

↑/↓ vybírá příkaz z historie přímo do editoru; lze jej dále upravovat.
←/→ posouvá kurzor, DELETE maže předchozí znak, psaní vkládá znak.
SS+W smaže celý rozepsaný příkaz bez odeslání a bez mazání historie.
SS+E nastaví hostitelský UART na 115200; neodesílá změnu rychlosti do ESP.
EDIT cykluje rychlosti. SS+Q žádá potvrzení DELETE COMMAND HISTORY? (Y/N).
CS+SS obnoví nápovědu; SS+SPACE ukončí terminál. Ostatní původní funkce zůstávají.

Historie: #7000–#73FF (1 KB), záznamy WORD délka + text.
Záloha dvou spodních obrazových řádků: #6C00–#6E3F (576 B).
Stav editoru: #6E40–#6E4F. Start kódu: 30000. BASIC loader CLEAR 27647.

## Sestavení a velikosti

Spusť source/assembly.bat. Výstupy se kopírují do runable/.

| Soubor | Bajtů |
|---|---:|
| Terminal11_el_mb.tap | 5411 |
| terminal11_el_mb.bin | 5325 |
| terminal11_el_mb_setup.bin | 5256 |

Aktuální oprava odpovědi Y/N přidává 11 B proti TAPu 5351 B. Celkem o 10 B méně než TAP 5372 B. Předchozí vydání je
zálohované v before-bottom-editor/. Všechny starší zálohy zůstávají.
Dvě původní assemblerová varování u zpětného lomítka dávají stejný bajt #5C jako 1.0.

## Ověření

Základní vydání prošlo 2951 modelovými scénáři pro každou variantu: editace, historie, limity,
Enter/EOT/CIPSEND, UART, nápověda, klávesové zkratky a návrat do BASICu.
Model tisku rozlišuje horní a spodní kanál ROM.

104 scénářů se skutečnými ROM instrukcemi v režimech 32/64 znaků:
Busy ZXrom64m a m64a4 nainstalovaný původním instalátorem do modelu bank 0/10.
Kontroluje se inverzní kurzor, dlouhé příkazy, oddělení horního výpisu,
všech 24 rychlostí přes EDIT, opakovaný RX scroll a nápověda.
M64 sada prošla také pro standalone. Samostatný test BSROM kontroluje
všech 24 rychlostí, zarovnání oddělovačů a zachování ATE0 po příjmu.
Bankování je simulované; reálný MB je potřeba ověřit. ROM a snapshot nejsou přibalené.

Testy: tests/test_editor.ps1 (také -Standalone), tests/test_rom_baud.ps1,
tests/test_rom_width.ps1 -RomPath cesta [-M64InstallerPath cesta] [-Standalone],
tests/verify_release.ps1.

## Kontrolní integrace do setupu 1.8

V oddělené pracovní kopii, bez změn rodičovského setupu:

| Raw výstup | Bajtů | Rezerva do 16384 |
|---|---:|---:|
| standalone | 16113 | 271 |
| flash | 16157 | 227 |
| flash debug | 16157 | 227 |

Všechny sestavy splnily ASSERT total_len < 16384; 112 regresních scénářů setupu prošlo.
Oprava Y/N: odpověď se ihned vytiskne za dotazem a odřádkuje, modalita se zruší bez Enteru. Aktuálně 54 cílených scénářů pro každou variantu, včetně Y/y/N/n a SS+SPACE, okamžité změny historie a následné editace. Jiné písmeno zůstává ignorované. Záloha před opravou: before-history-answer/.

## Volba Wi-Fi při ukončení samostatné varianty

SS+SPACE vrátí do BASICu a ponechá Wi-Fi zapnutou: WiFi is ON.
SS+ENTER vrátí do BASICu a vypne Wi-Fi: WiFi turned OFF. Bye.
Bez potvrzovacího dotazu. SS+ENTER má kód 202, TRUE VIDEO nadále 3.
Nápověda obsahuje obě zkratky. Ověřeno přímo přes čtení matice klávesnice.
Nárůst proti TAPu 5362 B: 45 B, aktuální TAP 5407 B, standalone BIN 5321 B.
Setupová varianta zůstává binárně shodná (5256 B); při návratu zachovává Wi-Fi ON.
Cílené kontroly: 59 scénářů standalone, 58 setup; 104 ROM 32/64 scénářů standalone.
Předchozí vydání: before-exit-choice/.

V nápovědě SS+SPACE a SS+ENTER zůstává první sloupec vlevo; pouze druhý sloupec je posunut o dva znaky doprava (+4 B). Aktuální TAP 5411 B, standalone BIN 5325 B; setup BIN beze změny.
