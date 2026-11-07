param([Parameter(Mandatory=$true)][string]$RomPath,[string]$SnapshotPath='D:\zx\48k.sna',[string]$M64InstallerPath='',[switch]$Standalone)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'rom-cpu.ps1')
$stem=if($Standalone){'terminal11_el_mb'}else{'terminal11_el_mb_setup'}
$sy=[Collections.Generic.Dictionary[string,int]]::new();Get-Content (Join-Path $PSScriptRoot ('..\source\'+$stem+'.sym'))|ForEach-Object{if($_ -match '^[^.]+\.([^:]+): EQU 0x([0-9a-fA-F]+)'){$sy[$matches[1]]=[Convert]::ToInt32($matches[2],16)}}
$sy['rom_char']=16
$bin=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot ('..\source\'+$stem+'.bin')))
function Assert($v,$why){if(-not $v){throw $why}}
function Cpu {
 $c=[TerminalCpu]::new($bin,$sy,30000);$c.RealRom=$true;$c.StepLimit=20000000;$c.IX=$sy['FLAGS'];$c.Uart=0
 [Array]::Copy([IO.File]::ReadAllBytes($RomPath),0,$c.M,0,16384)
 $sna=[IO.File]::ReadAllBytes($SnapshotPath);[Array]::Copy($sna,(27+0x1C00),$c.M,0x5C00,0x140)
 $c.M[0x5C3B]=$c.M[0x5C3B]-band 253;$c.M[0x5C3C]=$c.M[0x5C3C]-band 254;$c.M[0x5C91]=0;$c.M[0x5C8D]=56;$c.M[0x5C8F]=56;$c.M[0x5C8E]=0;$c.M[0x5C90]=0
 $c.M[0x5C51]=0xB6;$c.M[0x5C52]=0x5C;$c.M[0x5CB6]=0xF4;$c.M[0x5CB7]=0x09
 $c.ClearScreen();if($M64InstallerPath){$savedSy=$c.S;$is=[Collections.Generic.Dictionary[string,int]]::new($sy);$is['read_key']=65535;$is['read_key_nc']=65534;$is['restore_cur']=65533;$is['openscreen']=65532;$is['m64_install']=30208;$c.S=$is;$c.Banked=$true;$tap=[IO.File]::ReadAllBytes($M64InstallerPath);[Array]::Copy($tap,24,$c.M,30208,2299);$c.M[30214]=0x4A;$c.M[30215]=0x6A;$c.SP=0x6B00;$c.Run('m64_install');if($c.EndBC() -ne 0 -or $c.Bank -ne 0){throw 'm64 installation failed'};$c.S=$savedSy;[Array]::Copy($bin,0,$c.M,30000,$bin.Length);$c.SP=0xF000};return $c
}
function Word($c,$n,$v){$c.M[$sy[$n]]=[byte]($v-band 255);$c.M[$sy[$n]+1]=[byte]($v-shr 8)}
function W($c,$n){return [BitConverter]::ToUInt16($c.M,$sy[$n])}
$count=0
foreach($wide in @(0,16)){
 $c=Cpu;$c.M[23611]=($c.M[23611]-band 239)-bor $wide;$c.Run('start1');$cols=if($wide){64}else{32};Assert ($c.M[$sy['ui_columns']] -eq $cols -and $c.M[$sy['ui_capacity']] -eq 2*$cols-1 -and ($c.M[23611]-band 16) -eq $wide) 'ROM mode/configuration';$c.Run('ui_show');$count++
 foreach($pos in @(0,1,31,32,33,62,63,64,65,126,127,128,254,255,256)){
  $c.Run('ui_hide');$c.Put($sy['Buffer1'],('A'*256));Word $c 'cursor' ($sy['Buffer1']+$pos);Word $c 'text_end' ($sy['Buffer1']+256);Word $c 'window' $sy['Buffer1'];$c.Run('ui_show');$offset=(W $c 'cursor')-(W $c 'window');Assert ($offset -ge 0 -and $offset -lt 2*$cols-1) 'ROM viewport';$pixel=0x50C0+$(if($wide){[Math]::Floor($offset/2)}else{$offset});$mask=if(-not $wide){255}elseif($offset%2){15}else{240};$before=[byte[]]$c.M[0x5000..0x57FF];$flags=$c.M[23697];$c.Run('ui_cursor_off');for($i=0;$i -lt 2048;$i++){$expected=$before[$i];if((0x5000+$i-$pixel) -in @(0,256,512,768,1024,1280,1536,1792)){$expected=$expected-bxor $mask};Assert ($c.M[0x5000+$i] -eq $expected) "ROM cursor inversion width mode=$cols pos=$pos at=$i"};Assert ($c.M[23697] -eq $flags) 'Cursor changed ROM flags';$c.Run('ui_cursor_on');Assert ([Convert]::ToBase64String([byte[]]$c.M[0x5000..0x57FF]) -eq [Convert]::ToBase64String($before)) 'ROM cursor toggle lost glyph';$count++
 }
 # Exercise actual patch printing beyond the old half-screen and both new keys.
 $c.Run('ui_hide');$c.Put($sy['Buffer1'],'DRAFT');Word $c 'text_end' ($sy['Buffer1']+5);Word $c 'cursor' ($sy['Buffer1']+2);Word $c 'window' $sy['Buffer1'];$c.Run('ui_show');$c.A=200;$c.Run('check_history_confirm');$c.Run('ui_show');Assert ((W $c 'text_end') -eq $sy['Buffer1'] -and (W $c 'cursor') -eq $sy['Buffer1'] -and $c.Tx.Count -eq 0) 'ROM SS+W';$count++
 $c.Put($sy['Buffer1'],'DRAFT');Word $c 'text_end' ($sy['Buffer1']+5);Word $c 'cursor' ($sy['Buffer1']+2);$c.M[$sy['CURBAUD']]=23;$c.A=201;$c.Run('check_history_confirm');$c.Run('ui_show');Assert ($c.M[$sy['CURBAUD']] -eq 0 -and $c.SpeedCode -eq 0 -and (W $c 'text_end') -eq $sy['Buffer1']+5 -and (W $c 'cursor') -eq $sy['Buffer1']+2) 'ROM SS+E';$count++
 $c.Run('ui_hide');$c.SetBC(5*256);$c.Run('ui_at');foreach($ch in [Text.Encoding]::ASCII.GetBytes(('X'*50))){$c.Rx.Enqueue($ch);$c.Run('read_rx')};$expectedCol=if($wide){50}else{36};Assert ($c.M[23688] -eq $expectedCol) 'ROM 50-char RX column';$count++
 $c.Put($sy['Buffer1'],('Z'*256));Word $c 'text_end' ($sy['Buffer1']+256);Word $c 'cursor' ($sy['Buffer1']+1);Word $c 'window' $sy['Buffer1'];$c.Run('ui_show');$c.Run('do_CRLF');Assert ([Text.Encoding]::ASCII.GetString($c.Tx.ToArray()) -eq ('Z'*256)+"`r`n") 'ROM full Enter';Assert (($c.M[23611]-band 16) -eq $wide) 'ROM mode changed';$count++
 # Returning output at different encoded columns must never reinterpret S-POSN.
 foreach($col in @(0,1,15,31,($cols-1))){$c.Run('ui_hide');$c.SetBC(21*256+$col);$c.Run('ui_at');$oldCol=$c.M[23688];$c.Run('ui_show');$c.Run('ui_hide');Assert ($c.M[23688] -eq $oldCol -and ($c.M[23611]-band 16) -eq $wide) 'ROM output position/mode restore';$count++}
 # Native lower editor must leave every upper pixel/attribute unchanged.
 $upper=[Collections.Generic.List[byte]]::new();for($r=0;$r -lt 22;$r++){for($y=0;$y -lt 8;$y++){for($x=0;$x -lt 32;$x++){$upper.Add($c.M[$c.Pixel($r,$x)+($y-shl 8)])}}};$upper.AddRange([byte[]]$c.M[0x5800..0x5ABF]);$saved=[Convert]::ToBase64String($upper.ToArray());$c.Run('ui_show');$upper.Clear();for($r=0;$r -lt 22;$r++){for($y=0;$y -lt 8;$y++){for($x=0;$x -lt 32;$x++){$upper.Add($c.M[$c.Pixel($r,$x)+($y-shl 8)])}}};$upper.AddRange([byte[]]$c.M[0x5800..0x5ABF]);Assert ([Convert]::ToBase64String($upper.ToArray()) -eq $saved) 'Lower editor altered upper UART pixels';$count++
 # All EDIT speeds must preserve mode, draft, cursor and a usable lower channel.
 $c.Put($sy['Buffer1'],'DRAFT');Word $c 'text_end' ($sy['Buffer1']+5);Word $c 'cursor' ($sy['Buffer1']+2);Word $c 'window' $sy['Buffer1'];$c.Run('ui_redraw');for($speed=0;$speed -lt 24;$speed++){$c.A=7;$c.SP=0xEFFA;$c.Run('check_baud_change');$c.Run('ui_show');Assert ((W $c 'cursor') -eq $sy['Buffer1']+2 -and (W $c 'text_end') -eq $sy['Buffer1']+5 -and ($c.M[23611]-band 16) -eq $wide -and ($c.M[23612]-band 1) -eq 1) 'EDIT changed lower channel/draft/mode';$count++}
 # Repeated RX scrolling and help must keep lower editing usable.
 $c.Run('ui_hide');$c.SetBC(21*256);$c.Run('ui_at');for($line=0;$line -lt 30;$line++){$c.Rx.Enqueue(13);$c.Run('read_rx');$c.Run('ui_show')};Assert ((W $c 'cursor') -eq $sy['Buffer1']+2 -and (W $c 'text_end') -eq $sy['Buffer1']+5 -and ($c.M[23612]-band 1) -eq 1) 'RX scroll damaged lower editor';$count++
 $c.Run('help_screen');$c.Run('ui_show');Assert ((W $c 'cursor') -eq $sy['Buffer1']+2 -and ($c.M[23611]-band 16) -eq $wide -and ($c.M[23612]-band 1) -eq 1) 'Help damaged lower editor';$count++
}
"PASS: $count actual Busy ROM 32/64 scenarios; original ROM control/printing routines, 8/4-bit cursor masks, viewport and opaque position restore. MB bank switching is simulated; no physical machine test."