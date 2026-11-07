param([string]$RomPath='D:\zx\test\BSROM140_EL.rom',[string]$SnapshotPath='D:\zx\48k.sna')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'rom-cpu.ps1')
$sy=[Collections.Generic.Dictionary[string,int]]::new();Get-Content (Join-Path $PSScriptRoot '..\source\terminal11_next_setup.sym')|ForEach-Object{if($_ -match '^[^.]+\.([^:]+): EQU 0x([0-9a-fA-F]+)'){$sy[$matches[1]]=[Convert]::ToInt32($matches[2],16)}}
$sy['rom_char']=16
$bin=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot '..\source\terminal11_next_setup.bin'))
function Assert($v,$why){if(-not $v){throw $why}}
function Cpu {
 $c=[TerminalCpu]::new($bin,$sy,30000);$c.RealRom=$true;$c.StepLimit=20000000;$c.IX=$sy['FLAGS'];$c.Uart=0
 [Array]::Copy([IO.File]::ReadAllBytes($RomPath),0,$c.M,0,16384)
 $sna=[IO.File]::ReadAllBytes($SnapshotPath);[Array]::Copy($sna,(27+0x1C00),$c.M,0x5C00,0x140)
 $c.M[0x5C3B]=$c.M[0x5C3B]-band 253;$c.M[0x5C3C]=$c.M[0x5C3C]-band 254;$c.M[0x5C91]=0;$c.M[0x5C8D]=56;$c.M[0x5C8F]=56;$c.M[0x5C8E]=0;$c.M[0x5C90]=0
 $c.M[0x5C51]=0xB6;$c.M[0x5C52]=0x5C;$c.M[0x5CB6]=0xF4;$c.M[0x5CB7]=0x09
 $c.ClearScreen();return $c
}
function Decode($c,$row){$chars='';for($x=0;$x -lt 32;$x++){$found='?';foreach($ch in 32..126){$same=$true;for($y=0;$y -lt 8;$y++){if($c.M[$c.Pixel($row,$x)+($y-shl 8)] -ne $c.M[0x3C00+$ch*8+$y]){$same=$false;break}};if($same){$found=[char]$ch;break}};$chars+=$found};return $chars}
function Cycle($c,$count,[bool]$oldWipe=$false){$c.Run('start1');$c.Run('ui_show');for($i=0;$i -lt $count;$i++){if($oldWipe){$c.Run('ui_hide');$c.A=32;$c.Run('rom_char');$c.A=8;$c.Run('rom_char')};$c.A=7;$c.SP=0xEFFA;$c.Run('check_baud_change');$c.Run('ui_show')}}
$c=Cpu;Cycle $c 15;$lines=0;for($r=0;$r -lt 20;$r++){$line=Decode $c $r;if($line.Contains('---')){Assert ($line.StartsWith('---------------------')) ('Damaged separator: '+$line);$lines++}};Assert ($lines -ge 4) 'Missing BAUD separators';Assert ($c.M[$sy['CURBAUD']] -eq 0) '15-speed cycle failed'
foreach($key in [Text.Encoding]::ASCII.GetBytes('ATE0')){$c.A=$key;$c.SP=0xEFFA;$c.Run('not_lower');$c.Run('ui_show')};$c.SP=0xEFFA;$c.Run('do_CRLF');$c.Run('ui_show');foreach($v in [Text.Encoding]::ASCII.GetBytes("`r`nOK`r`n")){$c.Rx.Enqueue($v);$c.SP=0xEFFA;$c.Run('read_rx')};$c.Run('ui_show');$c.Run('ui_hide');$echo=$false;for($r=0;$r -lt 22;$r++){if((Decode $c $r).StartsWith('ATE0')){$echo=$true}};Assert ($echo) 'ATE0 echo damaged after ROM scrolling'
'PASS: real local BSROM print/CR/scroll routines align all 15 speeds after fix and preserve ATE0 after RX. No complete machine emulation.'