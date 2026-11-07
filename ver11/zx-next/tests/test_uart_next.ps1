param([switch]$Standalone)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'editor-cpu.ps1')
$stem=if($Standalone){'terminal11_next'}else{'terminal11_next_setup'}
$sy=[Collections.Generic.Dictionary[string,int]]::new();Get-Content (Join-Path $PSScriptRoot ('..\source\'+$stem+'.sym'))|ForEach-Object{if($_ -match '^[^.]+\.([^:]+): EQU 0x([0-9A-Fa-f]+)'){$sy[$matches[1]]=[Convert]::ToInt32($matches[2],16)}}
$bin=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot ('..\source\'+$stem+'.bin')))
function Assert($v,$why){if(-not $v){throw $why}}
function Cpu{$c=[TerminalCpu]::new($bin,$sy,30000);$c.IX=$sy['FLAGS'];$c.ClearScreen();$c.Run('ui_configure');return $c}
$rates=@(115200,57600,38400,31250,19200,9600,4800,2400,230400,460800,576000,921600,1152000,1500000,2000000)
$freq=@(28000000,28571429,29464286,30000000,31000000,32000000,33000000,27000000)
$count=0
foreach($timing in 0..7){foreach($rate in 0..14){
 $c=Cpu;$c.Uart=64;$c.Prescaler=131071;$c.Frame=231;$c.Timing=0xF8-bor $timing;$c.Run('next_uart_init');Assert ($c.Uart -eq 0 -and $c.Frame -eq 24) 'ESP/8N1 initialization';$c.A=$rate;$c.Run('set_baud_rate');$expected=[int][Math]::Floor($freq[$timing]/$rates[$rate]+0.5);Assert ($c.Prescaler -eq $expected -and $c.M[$sy['CURBAUD']] -eq $rate) "Wrong divider timing=$timing rate=$rate expected=$expected got=$($c.Prescaler)";Assert ($c.OutPorts -notcontains 0x7D3B -and $c.OutPorts -notcontains 0x703B -and $c.OutPorts -notcontains 0x713B) 'MB output on Next';Assert ($c.NextSelect -eq 17) 'Timing register';Assert (([Text.Encoding]::ASCII.GetString($c.Printed.ToArray())).Contains(([string]$rates[$rate] -replace '(\d)(?=(\d{3})+$)','$1_'))) 'Wrong printed baud label';$count++
}}
foreach($timing in 0..7){$c=Cpu;$c.Timing=$timing;$c.Run('start1');$c.Put($sy['Buffer1'],'DRAFT');$p=$sy['Buffer1']+5;$c.M[$sy['text_end']]=[byte]($p-band 255);$c.M[$sy['text_end']+1]=[byte]($p-shr 8);$p=$sy['Buffer1']+2;$c.M[$sy['cursor']]=[byte]($p-band 255);$c.M[$sy['cursor']+1]=[byte]($p-shr 8)
 for($i=1;$i -le 15;$i++){$c.A=7;$c.Run('check_baud_change');Assert ($c.M[$sy['CURBAUD']] -eq ($i%15)) 'EDIT cycle';$c.Run('ui_show')};$c.A=201;$c.Run('check_history_confirm');Assert ($c.Prescaler -eq [int][Math]::Floor($freq[$timing]/115200+0.5)) 'SS+E default';Assert ([Text.Encoding]::ASCII.GetString($c.M,$sy['Buffer1'],5) -eq 'DRAFT') 'Baud lost draft';$count++
}
$c=Cpu;$c.Uart=64;$c.Frame=231;$c.Run('start1');Assert ($c.Uart -eq 0 -and $c.Frame -eq 24 -and $c.Prescaler -eq 243) 'Full startup';$count++
$c.Rx.Enqueue(65);$c.Run('read_rx');Assert ($c.Rx.Count -eq 0) 'RX';$count++
foreach($port in $c.OutPorts){Assert ($port -in @(0x133B,0x143B,0x153B,0x163B,0x243B) -or ($port-band 255) -eq 254) ('Unexpected output port '+$port.ToString('X4'))};$count++
"PASS: $count Next UART scenarios ($stem): 15 rates x 8 timings, stale Pi/high divider, 8N1, EDIT/default, RX, allowed ports."