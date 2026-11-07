 DEVICE ZXSPECTRUM128
 DEFINE setup
 DEFINE ZXNEXT
 MODULE v0
 INCLUDE "terminal11_main.asm"
 SAVEBIN "terminal11_next_setup.bin",start_address,total_len
 ENDMODULE
 UNDEFINE setup