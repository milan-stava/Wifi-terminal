$ErrorActionPreference='Stop'
function Assert($ok,$why){if(-not $ok){throw $why}}
$source=Join-Path $PSScriptRoot '..\source'
$tap=[IO.File]::ReadAllBytes((Join-Path $source 'Terminal11_el_mb.tap'))
$blocks=[Collections.Generic.List[byte[]]]::new();$p=0
while($p -lt $tap.Length){Assert ($p+2 -le $tap.Length) 'Truncated TAP';$len=[BitConverter]::ToUInt16($tap,$p);$p+=2;Assert ($p+$len -le $tap.Length -and $len -ge 2) 'TAP length';[byte[]]$block=$tap[$p..($p+$len-1)];$xor=0;foreach($b in $block){$xor=$xor-bxor $b};Assert ($xor -eq 0) 'TAP checksum';$blocks.Add($block);$p+=$len}
Assert ($blocks.Count -eq 4 -and $blocks[0][1] -eq 0 -and $blocks[2][1] -eq 3) 'BASIC/CODE block structure'
Assert ([BitConverter]::ToUInt16($blocks[2],14) -eq 30000) 'TAP CODE load address'
$bin=[IO.File]::ReadAllBytes((Join-Path $source 'terminal11_el_mb.bin'))
Assert ([BitConverter]::ToUInt16($blocks[2],12) -eq $bin.Length -and $blocks[3].Length -eq $bin.Length+2) 'TAP CODE length'
for($i=0;$i -lt $bin.Length;$i++){Assert ($blocks[3][$i+1] -eq $bin[$i]) 'TAP CODE payload mismatch'}
$loader=[Text.Encoding]::ASCII.GetString($blocks[1]);Assert ($loader.Contains('27647') -and $loader.Contains('30000')) 'Loader memory reservation'
foreach($kind in @('terminal11_el_mb','terminal11_el_mb_setup')){
 $symbols=@{};Get-Content (Join-Path $source ($kind+'.sym'))|ForEach-Object{if($_ -match '^[^.]+\.([^:]+): EQU 0x([0-9A-Fa-f]+)'){$symbols[$matches[1]]=[Convert]::ToInt32($matches[2],16)}}
 Assert ($symbols.Buffer4 -eq 28672 -and $symbols.history_size -eq 1024 -and $symbols.start_address -eq 30000 -and $symbols.Buffer4+$symbols.history_size -le $symbols.start_address) 'History memory map'
 Assert ($symbols.ui_backup -eq 27648 -and $symbols.ui_capacity -lt $symbols.Buffer4) 'Editor scratch memory map'
 Assert ($symbols.endramcode -lt 49152) 'Terminal exceeds C000'
}
Assert ((Get-Item (Join-Path $source 'terminal11_el_mb.bin')).Length -eq 5325 -and (Get-Item (Join-Path $source 'terminal11_el_mb_setup.bin')).Length -eq 5256) 'Unexpected binary size'
"PASS: TAP structure/checksums/payload, loader CLEAR, memory map, binary sizes."
