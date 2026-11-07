 DEVICE ZXSPECTRUM128
 MODULE v1
 INCLUDE "terminal11_main_el_mb.asm"
 SAVEBIN "terminal11_el_mb.bin",start_address,total_len
 ENDMODULE
 ; Standalone BASIC loader. Code binary above excludes this loader.
 ORG #5C00
basic_start:
 DB 0,1
 DW basic_end-basic_line
basic_line:
 DB #FD,"27647",#0E,0,0
 DW 27647
 DB 0,':',#EF,'"','"',#AF,':',#F9,#C0,"30000",#0E,0,0
 DW 30000
 DB 0,13
basic_end:
 EMPTYTAP "Terminal11_el_mb.tap"
 SAVETAP "Terminal11_el_mb.tap",BASIC,"terminal11",basic_start,basic_end-basic_start,1
 SAVETAP "Terminal11_el_mb.tap",CODE,"terminal11",v1.start_address,v1.total_len,v1.start_address