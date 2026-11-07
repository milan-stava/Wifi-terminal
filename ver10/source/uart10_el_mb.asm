	DEVICE  ZXSPECTRUM48

;	DEFINE setup		;version for setup, does not turn wifi off at quit
				;otherwise newly it is one version for el, mb, or el+mb
				;defined in 2 ASM files

/* old
;	DEFINE mb03plus_setup	;version for MB03+ and wifi setup
	DEFINE eLeMeNtZX	;version for eLeMeNt ZX
;	DEFINE mb03plus_setup	;version for MB03+ wifi setup
;	DEFINE eLeMeNtZX_setup	;version for eLeMeNt ZX for wifi setup.... nonsence can be removed
*/

	IFDEF setup
	output el_mb_terminal10_setup.bin
	ELSE
	output el_mb_terminal10.bin
	ENDIF


g_ZXi_port0	equ #7C3B
g_ZXi_port1	equ #7D3B	
; TBBlue / ZX Spectrum Next project
; Copyright (c) 2010-2018 
;
; UART - Tim Gilberts, Victor Trucco and Jim Bagley
;
; All rights reserved
;
; Redistribution and use in source and synthezised forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; Redistributions of source code must retain the above copyright notice,
; this list of conditions and the following disclaimer.
;
; Redistributions in synthesized form must reproduce the above copyright
; notice, this list of conditions and the following disclaimer in the
; documentation and/or other materials provided with the distribution.
;
; Neither the name of the author nor the names of other contributors may
; be used to endorse or promote products derived from this software without
; specific prior written permission.
;
; THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
; THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
; PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.
;
; You are responsible for any legal issues arising from your use of this code.
;
;-------------------------------------------------------------------------------
;
; Victor also credits Jim Bagley with help with the Key scancode elsewhere.
; 
; Adapted to z80asm for Z88DK, bug fixes, baud rate change and adapted to UART buffering status by Tim Gilberts
;
; See also excellent documentation by Allen Albright:
; https://github.com/z88dk/z88dk/blob/master/libsrc/_DEVELOPMENT/target/zxn/config/config_zxn_uart.m4
;
;Version 2.1
;Version 2.2 adding CIPSEND/IPD and some ANSI support etc
;2.2 a minor patch aborted speed tester for prescaler
;2.2 b change to use dual write to BAUD RATE for full scalar access and correct credits.
;2.2 c correct available speeds to match some of the minicom ones on a Linux box
;2.2 d added ability to send EOT (to support 4G modem card)
;2.2 e added find ESP mode that tries all PreScaler values


;Hood's version 0.1 based on Tim's 2.2e and his kind approval
;news:	- can send bytes as numbers in CIPSEND mode (de/activated by INV.VIDEO)
;	- arrow up invokes the last command
;	- keyboard routine replaced (better routine+ no char print slow down)
;Hood's version 0.12 (based of 22f)
;0.3= separate versions for eLeMeNtZX and MB03+
; - new speed modes
;ver 1.0- new name, new version, one for all configuration, el, mb, el+mb

;Org in memory for test and debug

	org 30000		;7530h
start_address
uart	
maincode
ramcode

;	DEFC	TX_CHKREADY = 4923	;133Bh Write is byte to send, when read is status 0x01 = RX_AVAIL or 0x02 - TX_READY
TX_CHKREADY	equ 4923	
;	DEFC	RX_SETBAUD = 5179	;143Bh Read is byte received, when written sets the BAUD rate. (now two bytes of prescaler TBU >.28)
RX_SETBAUD	equ 5179	
;To set BAUD prescaler first write must be 0-127 which are the lowest 7 bits (the 0 in BIT 7 resets the value loader).  Second byte must
;be 1mmmmmml where l is the 8th bit of the prescaler and mmmmmm is the top six bits of the prescaler value (1 just stops the reset)

;These are known in Z88DK as:
	
;	DEFC __IO_UART_BAUD_RATE = 0x143b
	
;Note old defs from Z88DK repurposed for default timing constants at VGA.
;
;	DEFC __IUBR_115200 = 243
;	DEFC __IUBR_57600 = 486
;	DEFC __IUBR_38400 = 729
;	DEFC __IUBR_31250 = 896
;	DEFC __IUBR_19200 = 1458
;	DEFC __IUBR_9600 = 2916
;	DEFC __IUBR_4800 = 5833
;	DEFC __IUBR_2400 = 11666

;The undocumented Next register 0x11 (17) can be used. I.e. OUT 9275,17 followed by IN 9531 (OUT 0x243B,0x11 IN 0x253B)
;Victor used it to change the PLL
;when X"11" => -- 17
;		register_data_s 	<= "00000" & machine_video_timing;

start1:
			DI
		call openscreen		;needs to be called, Tim has forgotten

		ld bc,#703B		;turn Wifi module on alway. It is either MB wifi, which needs to turn on wifi, or el wifi, which is turned on automatically
		ld a,5
		out (c),a
		inc b
		in a,(c)
		or 1			
		out (c),a		;Wifi ON
;		ld a,2
;		out (254),a

		ld hl,turningon
		call print

;		ld a,(23624)		;return border colour
;		out (254),a

;		ld hl,OK
;		call print


		jr cont
	
turningon	defb 13
		defm "Turning WiFi ON... "
		defb 13,0
wifion		defb 13
		defm "WiFi is ON"
		defb 13,0
turnoff		defb 13
		defm "WiFi turned OFF. Bye."
		defb 0

cont			PUSH IX

			LD IX,FLAGS
			LD (IX),%00000000		;Default is not to echo CIPSEND command data at the moment.
			
			ld a,h
			or l
			JR z,normal_start  ;if we dont have parameters it is a read command

			LD A,(HL)

			CP '-'		;options flag - ignore any other junk
			JR NZ,normal_start
	
			INC HL
			LD A,(HL)
			CP 'f'		; 
			JR NZ,normal_start

;MB03 code start
		ld b,3
wftime1		ld de,0			;Wifi Timeout
wftime0		dec de
		ld a,d
		or e
		jr nz,wftime0
		djnz wftime1
;		ld b,#13
;wifibusy0	in a,(c)
;		bit 0,a
;		jr z,wifibusy0
;MB03 code end


//LMN			JP find_esp

normal_start:	
			LD HL,Welcome
			CALL print

			; clear the buffer area
			ld hl, Buffer1
			PUSH HL ;save the initial buffer position

			ld ( HL ),0
			ld de, Buffer1 + 1
			ld bc, Endbuffers - Buffer1
			ldir
			
set_baud_115200:	XOR A
			
set_baud_rate:		LD (CURBAUD),A

;Now we calculate the prescaler value to set for our VGA timing.

			PUSH AF
			
			LD HL,Timing
//			call print

			POP AF
			
			LD D,0
			SLA A		; *2
			RL D
			SLA A		; *4
			RL D
			SLA A		; *8
			RL D
			SLA A		; *16
			RL D	
			LD E,A		
			LD HL,BaudPrescale	; HL now points at the BAUD to use.
			ADD HL,DE

			LD BC,9275	;Now adjust for the set Video timing.
			LD A,17
			OUT (C),A
			LD BC,9531
			IN A,(C)	;get timing adjustment
			LD E,A
			RLC E		;*2 guaranteed as <127
			LD D,0
			ADD HL,DE

			LD E,(HL)
			INC HL
			LD D,(HL)
			EX DE,HL

			PUSH HL		; This is prescaler
			PUSH AF		; and value
						
			LD BC,RX_SETBAUD
			LD A,L
			AND %01111111	; Res BIT 7 to request write to lower 7 bits
//LMN			OUT (C),A
			LD A,H
			RL L		; Bit 7 in Carry
			RLA		; Now in Bit 0
			OR %10000000	; Set MSB to request write to upper 7 bits
			LD a, (CURBAUD) //LMN
			OUT (C),A

			POP AF
			LD L,A
			LD H,0
//LMN			CALL prt_dec
				
			LD HL,Prescaler
//LMN			CALL print

			pop hl
//LMN			call prt_dec
	
;MB03 start
			ld hl,wifion
			call print
;MB03 end
			call print_baud

read_key:			
			LD A,143	;Print character block
			RST 16
			LD A,8		;BS
			RST 16

			ld a,255	;SCR_CT keep this above 1 and screen never asks Scroll?
			LD(23692),a	;Do it here in case we get no response before we reach bottom of screen

read_key_nc:		xor a	;MB03, to speed up print of characters if no key pressed
			in a,(254)
			cpl
			and 31
			jp z,read_rx	;no key pressed,do not call slow keyboard routine
			
			call scankeys
			
			cp 00
			JP z, read_rx ; jump to read RX if we dont have keys to send

	 		cp 6		;Exit is SYMBOL SHIFT and SPACE 
			JP Z, finish

			CP 3		;TRUE VIDEO - toggle diags on and off
			JR NZ,not_toggle_diags

			LD A,(IX+0)
			XOR %01000000
			LD (IX+0),A			
			JR read_key_nc
			
not_toggle_diags:	
			CP 2		; Toggle CAPS LOCK on and OFF (Not shift lock)
			JR NZ, check_baud_change
			
			LD A,(CapsLock+1)
			XOR %00100000
			LD (CapsLock+1),A
			
			JR read_key_nc
			
check_baud_change:	CP 7; was 1	MB03	; Request to cycle BAUD rate with EDIT key
			JR NZ, no_baud_change 

			LD A,' '	;Wipe our cursor
			RST 16
			LD A,8
			RST 16		;to move print position back as Baud change will do a newline

			LD A,(CURBAUD)
			INC A
			//LMN CP 15
			CP 24 //LMN
			JP Z,set_baud_115200
			JP set_baud_rate

no_baud_change:		
			CP 4		;Want CIPSEND mode on/off
			JR NZ,not_set_cipsend

			LD A,(IX+0)
			XOR %00000001
			LD (IX+0),A
			
			LD A,' '	;Wipe our cursor
			RST 16
			LD A,8
			RST 16		;to move print position back as change will do a newline
						
			CALL print_newline
			LD HL,CIPOFF
			BIT 0,(IX+0)
			JR Z,cipsend_state
	
			LD HL,ATE0	;Make sure local ECHO is OFF
			CALL tx_out

			LD HL,CIPON						
cipsend_state:		
			call print
			LD HL, str_separator
			CALL print			
			JP read_key

not_set_cipsend:
			CP 5
			JR NZ,not_set_ansi
			LD A,26			;Send EOT used for 3g Modem
			JP emit_EOT		;also does a flush of buffer

;			JR not_set_ansi		;***TODO dropped support in 2.2

;			CP 5		;Want ANSI mode on/off
;			JR NZ,not_set_ansi

;			LD A,(IX+0)
;			XOR %00000010
;			LD (IX+0),A

;			LD A,' '	;Wipe our cursor
;			RST 16
;			LD A,8
;			RST 16		;to move print position back as change will do a newline			

;			CALL print_newline
;			LD HL,ANSIOFF
;			BIT 1,(IX+0)
;			JR Z,ansi_state
;			LD HL,ANSION						
;ansi_state:		
;			call print
;			LD HL, str_separator
;			CALL print			
;			JP read_key

not_set_ansi:
			CP 8
			JR nz,revoke_last_command

			POP HL
			PUSH HL
			XOR A			;Clear carry for SBC
			LD DE,Buffer1		;If we are at the start delete not allowed
			SBC HL,DE

			JP Z, read_key_nc	;So just ignore it.

			POP HL			
			DEC HL
			PUSH HL	
			
			LD A,' '	;Wipe our cursor
			RST 16
			LD A,8
			RST 16		;to move print position back
			LD A,8
			RST 16
			
			JP restore_cur



revoke_last_command	cp #B		;MB03
			jr nz,save_char ; not BS, save the char on buffer

			ld hl,Buffer4	;if 0 or 13 in the buffer, do no action
			ld a,(hl)
			or a
			jp z,restore_cur
			cp 13
			jp z,restore_cur
			push hl

			ld a,32		;wipe cursor
			rst 16

			pop hl
					;ldir last command to SEND buffer
			ld de,Buffer1
			push de
com_l			ld bc,#55	;length of the last command
			ldir
			dec de
			dec de
			ld h,d
			ld l,e
			ld (hl),c	;put zero at the end of a string

			call print_newline

			pop hl
			call print	;print last command

			ld hl,zalo	;renew sys.vars for the last command
			ld de,23679
			ld bc,13
			ldir

hlko			ld hl,#55	
			dec hl		;cursor position to follow last command
			ex (sp),hl	
			jr restore_cur			
			
zalo			ds 13
;save the key on the TX buffer	if there is room - if not, force transmit buffer and also if it is CR		



		
save_char:		cp 13		;MB03- for print accept only chars 32-127
			jr z,not_lower

			cp 32			
			jp c,read_key
			cp 127+1
			jp nc,read_key		;end MB03

			CP 'a'
			JR C,not_lower
			
			CP 'z'+1
			JR NC,not_lower

;	DEFC CapsLock = ASMPC+1			;Self modify of next statement


CapsLock		XOR %00100000		;By default is on

not_lower:
			POP HL
			ld ( HL ),a
			inc HL
			PUSH HL

			CP 13			;If it was a newline 
			JR Z,do_CRLF
						
			RST 16			;Print it and check if that was the end of the buffer

			LD DE,Endbuffers-1	;Space for a forced CR (LF there anyway)
			XOR A			;Clear carry for SBC
			SBC HL,DE
			JR Z,force_CRLF

restore_cur:
			LD A,143		;So regenerate cursor block
			RST 16
			LD A,8
			RST 16
			
			JP read_key

force_CRLF:		POP HL			;Stick an automatic CR in the buffer
			LD A,13
			LD (HL),A
			INC HL
			PUSH HL

do_CRLF:	ld (hlko_alter),hl
		ld hl,23679
		ld de,zalo1
		ld bc,13
		ldir

;		ld a,(#5C88)		;last cursor position;MB03-dirty trick valid for only last command invoke
;			ld (last_cursor+1),a			
;			ld a,(#5C84)
;			ld (last_cursor2+1),a			
			LD A,' '		;wipe cursor
			RST 16			;Before going straight to empty the buffer
			LD A,13
			RST 16
					
empty_buffer:		
			LD A,10			;put LF at the end of the buffer

emit_EOT:
			POP HL
			LD (HL),A 

			call save_last_com	;MB03 save the command

			BIT 0,(IX+0)		
			JP Z,not_sipsend
/*
Hood's part. Extending syntax of a commad being sent. Old way commands preserved.
command syntax: "x1, "x2", ...", where x1= number in decimal of max length 5, x2= ASCII string of any length enclosed in quotation marks. Such type of command is needed for communication with eg. TNFS servers. See Spectranet info on Wiki.

eg: 	1234,"hello"...   valid
	"1234","hello"... valid
	"1234a","hello"... valid
	1234           ...valid
	"hello"       ... valid
	"1234",hello... invalid
	1234a,"hello"...invalid
	123456,"hello"...invalid
	"1234","hello... invalid

	1234.... will be converted to #4D2, so bytes #D2 and 4 will be sent
	123..... will be converted to #7B, so byte #7B will be sent
*/
		ld de,Buffer3
		ld (buf3+1),de
		ld de,Buffer1		;now decide if user has sent an old way command
		ld a,(de)		;ie. a plain input from the keyboard	
		cp 34			;quotation mark?
		jp z,ASCIIstring	
		cp "0"
		jp c,old_way_command
		cp "9"+1
		jp nc,old_way_command


evalloop	ld a,(de)		;now we deal with new way command, analyse its segments,ie. individual x1, x2... 
		cp 34			;evaluate if it is a valid command string
		jp z,ASCIIstring

evalnumb	ld c,6		;now evaluate number string, look for "," or EOL (13,10)
		push de		
evalnumbloop	cp ","
		jr z,evalnumbend

eval1310	cp 13
		jr nz,evalNUMB
		inc de
		ld a,(de)
		cp 10
		jr z,evalnumbend

evalNUMB	cp "0"
		jr c,invalid
		cp "9"+1
		jr nc,invalid		
		dec c
		jr z,invalid
		inc de
		ld a,(de)
		jr evalnumbloop		

evalnumbend	pop de		;starting address of the numberin the string
		ex af,af'
;		ld a,6
;		sub c		;A=len of number
		call ConvRStr16:;convert ASCII number to number in HL
		inc de
		ld b,d
		ld c,e
buf3		ld de,Buffer3	;put the number in HL to Buffer3
		ld a,l
		ld (de),a
		ld a,h
		or a
		jr z,_8bitvalue

_16bitvalue	inc de
		ld (de),a

_8bitvalue	ex af,af'

		inc de
		ld (buf3+1),de
		
		cp 10		;total end of string?
		jr z,endofstring
		ld d,b
		ld e,c		
		jr evalloop

endofstring	ld a,13		;add 13,10
		ld (de),a
		inc de
		ld a,10
		ld (de),a	;now we have command to be sent
		inc de		;calculate its length
		ld hl,Buffer3
		ex de,hl
		or a
		sbc hl,de
		ld b,h
		ld c,l		;BC= len of command, max. 255 bytes (enough in real life)
		ld a,c
		ld hl,Buffer3
		ld de,Buffer1	;move Buffer3 to Buffer1
		ldir
		ld h,c
		ld l,a		;HL=len of command
		jp place_com_len	;and connect to the main program


	
ASCIIstring	ld c,0		;now evaluate ASCII string
		push de		;start of ASCII string -1
ASCIIstringloop	inc de
		ld a,(de)
		cp 34
		jr z,ASCII1310
		inc c
		jr nz,ASCIIstringloop
invalid		ld hl,SYNERR
		call print
		jp reset_buffer	;invalid syntax, connect to the main program
				;no second " found, invalid
ASCII1310	inc de
		ld a,(de)
		cp 13
		jr nz,ASCIIcomma
		inc de
		ld a,(de)
		cp 10
		jr z,ASCIIstringend

ASCIIcomma	cp ","
		jr nz,invalid
		
ASCIIstringend	ex af,af'		;A= either , or 10 to determin evaluation end
		pop hl		;was DE, now move the string from Buffer3 to Buffer1
		inc hl


		ld de,(buf3+1)
		ld b,0
		ld a,c
		ldir
		ld (buf3+1),de
		ex af,af'
		cp 10
		jr z,endofstring
		ld d,h
		ld e,l		;DE=source Buffer1
		inc de
		inc de
		jp nz,evalloop	;evaluate next segment
;end of Hood's part



old_way_command		INC HL			;So calc length to send
			LD DE,Buffer1
			OR A			;CCF
			SBC HL,DE			

place_com_len		LD DE,STRINGNUM
			CALL string_dec
			LD A,13
			LD (DE),A
			INC DE
			LD A,10
			LD (DE),A
			
			LD HL,CIPSEND
;			PUSH HL
;			CALL print
;			POP HL
			CALL tx_out

;Now wait for OK to send ***TODO make this a generic string receive subroutine...

			LD HL,CIPSTART
			CALL wait_streamstring
			
			JR C,cancel_sipsend		;abandon if not received

			CALL DiagRST16			;Print char if in diagnostic mode
				
not_sipsend:			
			ld hl, Buffer1
			CALL tx_out
			
			BIT 0,(IX+0)
			JR Z,reset_buffer
			
			LD HL,CIPSOK			;Wait for SEND OK skipping other data.
			CALL wait_streamstring
			JR NC,reset_buffer

cancel_sipsend:		
			CALL tx_timeout


reset_buffer:		LD HL,Buffer1
			PUSH HL
			
			JP read_key

save_last_com		push hl		;save last command to Buffer4- history buffer
			inc hl
			ld de,Buffer1

			ld a,(de)	;if buffer is empty (ENTER was pressed),no action
			cp 13
			jr z,slend

			or a
			sbc hl,de
			ld b,h
			ld c,l
			ld (com_l+1),bc	;length of command, enough for 1 command. For more commands, lengths have to be calculated in invoke routine
			ld h,d
			ld l,e
			ld de,Buffer4
			ldir

			ld hl,zalo1	;renew sys.vars for the last command
			ld de,zalo
			ld bc,13
			ldir
			ld hl,(hlko_alter)
			ld (hlko+1),hl

slend			pop hl
			ret			
zalo1			ds 13		;if only enter pressed, do no ldir of cursor pos.
hlko_alter		dw #55		;if only enter, no cursor pos preserved		
			
read_rx:
			CALL GET_BYTE
			JP C,read_key
			
;*** TODO This limits 8 bit transmission so probably redundant with status register?	Added
;back on New TBU >7 as now seem to get one.							
			cp 0ffh
			jp z, read_key 			; if we dont have anything to show
		
			cp 10 				; dont show the line feed
			jp z, read_key

;Check for any other codes to process here
			CP 13
			JR NZ,not_rec_CR
			
			PUSH AF
			LD A,' '			;Erase our cursor as we have a newline
			RST 16
			POP AF			
						
			JP print1	

not_rec_CR:		BIT 0,(IX+0)			;Are we in CIPSEND mode?
			JP Z,not_ipdstart

			CP '+'
			JP NZ,not_ipdstart
			
			SET 2,(IX+0)			;Start looking for IPDDATA

			CALL GET_BYTE_WAIT		;Wait a while (should not check for IPD inside one...)
			JR C,cancel_ipdstart		;abandon if not received.1
			CP 'I'
			JR NZ,cancel_ipdstart		;or is wrong char
			CALL GET_BYTE_WAIT		;Wait a while
			JR C,cancel_ipdstart		;abandon if not received
			CP 'P'
			JR NZ,cancel_ipdstart
			CALL GET_BYTE_WAIT		;Wait a while
			JR C,cancel_ipdstart		;abandon if not received.1
			CP 'D'
			JR NZ,cancel_ipdstart
			CALL GET_BYTE_WAIT		;Wait a while
			JR C,cancel_ipdstart		;abandon if not received.1
			CP ','
			JR NZ,cancel_ipdstart
			CALL GET_NUM			;get a number stream terminated with : or ;
			JR C,cancel_ipdstart
			LD (IX+1),L			;Could be a while 2K packet perhaps so size is in DE 
			LD (IX+2),H
			EX DE,HL

			LD HL,Buf2Pos-Buffer2		;Check length not longer than buffer
			OR A
			SBC HL,DE
			JR C,cancel_ipdstart
		
; OK Lets get the data from the IPD packet as quickly as possible.
			BIT 6,(IX+0)			;unless in command debug mode skip.
			JR Z, just_get_ipdpacket

			PUSH DE
			LD A,'['
			RST 16
			LD HL,IPDSTART
			CALL print
			LD HL,GOTNUM	
			CALL print
			LD A,']'
			RST 16
			POP DE
				
just_get_ipdpacket:	LD HL,Buffer2

get_fast_packet:	
			PUSH DE
			CALL GET_BYTE
			POP DE
;			JR C,get_fast_timeout
			
			LD (HL),A
 			INC HL
 			DEC DE
 			LD A,E
 			OR D
 			JR NZ,get_fast_packet
 			LD (HL),0
 			JR print_ipdpacket
 
get_fast_timeout:	LD (HL),0
			LD HL,str_TIMEOUTRX
			CALL print
	
	
print_ipdpacket:	LD HL,Buffer2
			CALL print

			LD A,13				;End up double spaced but, at least all packets end on a newline. 
			RST 16

			JP read_rx
			

cancel_ipdstart:	BIT 6,(IX+0)			;unless in command debug mode skip.
			JR Z, print_ipdpacket

			LD HL,IPDABORT
			CALL print
			JP read_rx
			
			
not_ipdstart:		BIT 1,(IX+0)
			CP 27				;Is this an ESC sequence starting
			JR NZ,not_rec_ESC

;If so then look to see if we get a sequence
			SET 2,(IX+0)			;Mark we are looking for an ESC sequence
			JP read_rx

not_rec_ESC:		

			CP 32
			JR C,escaped			;less than 32 are escaped
	
			CP 128
			JR C,print1			;32-127 just printed
						
escaped:		PUSH AF
			LD A,'\\'
			RST 16
			POP AF
			CALL prt_hex
			JP read_key		

print1:		
			rst 16 ;print the char
			
			JP read_key
			


;---------------------------------------------------------------------------------
;find_esp: Tries all pre-scaler values to locate an ESP - then sets a known
;good baud rate of 115200 before entering the terminal!
;
;Note that Screen timing is irrelevant here as we set our end to something
;that works once we get ERROR and OK!

find_esp:
			LD HL,Searching
			CALL print

			LD HL,1		; Lowest pre-scaler we can use > 2Mbs
			
find_esp_next:			
			PUSH HL

			LD A,'/'
			RST 16
			LD A,8
			RST 16

			POP HL
			PUSH HL

			LD BC,RX_SETBAUD
			LD A,L
			AND %01111111	; Res BIT 7 to request write to lower 7 bits
			OUT (C),A
			LD A,H
			RL L		; Bit 7 in Carry
			RLA		; Now in Bit 0
			OR %10000000	; Set MSB to request write to upper 7 bits
			OUT (C),A

			LD A,'-'
			RST 16
			LD A,8
			RST 16
			
			LD HL,CRLF	; Send a CRLF
			CALL tx_out
			
			LD HL,ERROR
			CALL wait_streamstring
			JR NC,find_esp_maybe

			LD A,'\\'
			RST 16
			LD A,8
			RST 16	
			
			POP HL
			
			JR find_esp_nextps

find_esp_maybe:			
			LD A,'o'	; Mark a try to get OK
			RST 16
			
			LD HL,DEFBAUD
			CALL tx_out

			LD HL,OK
			CALL wait_streamstring

			POP HL	
			
			JR C,find_esp_nextps
			
			LD A,13
			RST 16
						
			JP normal_start

find_esp_nextps:
			INC HL		; OK failed so try next prescaler.

			XOR A
			OR L
			JR NZ,find_esp_nopace
			
			PUSH HL
			LD A,'.'
			RST 16
			POP HL
			
find_esp_nopace:			
			BIT 6,H		; At 16384 stop as that is max prescaler
			JR Z,find_esp_next ;Keep searching
		
			JP finish_nothl	; Restore system and exit not found
			

					
;---------------------------------------------------------------------------------
finish:			

finish_nothl:

		IFNDEF setup		;no setup version will turn wifi off
;MB03 code
			ld bc,#703B	;turn Wifi off
			ld a,5
			out (c),a
			inc b
			in a,(c)
			and %11111110
			out (C),a
			ld hl,turnoff
			call print
		ENDIF
;end of MB03 code
			xor	a			;No error
			pop	hl			;Dump buffer position			
			POP	IX
			EI
			ret			
			
;---------------------------------------------------------------------------------
; Send Bytes from HL terminated with LF char 10


tx_timeout:		LD HL, str_TIMEOUTCS
			CALL print

end_tx:			RET


tx_out:			
			LD DE,2048		;Delay timeout - was 20 at 112500 baud - need to be higher at lower baud rates...
						
			LD BC,TX_CHKREADY
tx_out_wait:		IN A,(C)
			AND %00000010		;Check if TX available for send, wait until it is (with timeout)
			JR Z,tx_out_ready
					
			DEC DE
			LD A,D
			OR E
			JR NZ,tx_out_wait

			LD HL, str_TIMEOUT	;Prints an error if we do not become ready...
			JP print
			
tx_out_ready:		LD A,(HL)
			OUT (c),a		
	
			CP 10
			RET Z
			
;			DEC E
;			RET Z

			INC HL
			JR tx_out

;---------------------------------------------------------------------------------
;Code to wait for a specific string in the Bitstream...
;HL points at the string we are waiting for.
;
;Return Carry SET if a timeout either waiting for characters in the stream or too many false starts
;

wait_streamstring:
			LD C,20				;We will slip the stream upto X times

loop_slipstart:
			PUSH HL				;Preseve in case we need to reset to slip.
			LD B,30				;We will skip over upto 30 chars looking for our start char

loop_waitstart:
			PUSH BC

			CALL GET_BYTE_ALLOWIPD
;			JR C,end_waitstring		;abandon if not received (skipped at mo 0 returned to allow 20 retries)
			CP (HL)
			JR Z,begin_waitstring		;if it is the first character then lets look

			POP BC
			
			DJNZ loop_waitstart
			
			SCF
			JR end_waitstring_2		;Timeout waiting for a start character.

begin_waitstring:	CALL DiagRST16			; We are going to destroy A so print now if needed.
			INC HL				;Next char to look for
			
			LD A,(HL)			;If next char to find is a Zero (end of string marker)
			OR A				;also CCF
			JR Z,end_waitstring 		;Then we have a match
			
			CALL GET_BYTE_ALLOWIPD
			JR C,end_waitstring		;abandon if not received
			CP (HL)				;check if a match
			JR Z,begin_waitstring		
			
			POP BC				;Any character which does not match restarts the look
			POP HL
			DEC C			
			JR NZ,loop_slipstart
			SCF
			RET

end_waitstring:
			POP BC
end_waitstring_2:
			POP HL

			RET
			
;---------------------------------------------------------------------------------
;Get a decimal number from bytestream in BC - uses D and HL as E and BC destroyed by subs used
;Carry set if more than 4 digits received which would overflow buffers in more ways than one.

GET_NUM:		LD D,4				;Max of 4 characters
			LD HL,GOTNUM
GN_LOOP:
			CALL GET_BYTE_WAIT_NUM	
			JR C,GN_END
			LD (HL),A
			INC HL
			DEC D
			JR NZ,GN_LOOP
			SCF				;error too many digits
			RET

GN_END:			LD (HL),0			;terminate Number early with a zero

;Drop through to actually convert string at HL to number in BC

			LD DE,GOTNUM

ConvRStr16:
;===============================================================
;http://z80-heaven.wikidot.com/math#toc32
;Input: 
;     DE points to the base 10 number string in RAM. 
;Outputs: 
;     HL is the 16-bit value of the number 
;     DE points to the byte after the number 
;     BC is HL/10 
;     z flag reset (nz)
;     c flag reset (nc)
;Destroys: 
;     A (actually, add 30h and you get the ending token) 
;Size:  23 bytes 
;Speed: 104n+42+11c
;       n is the number of digits 
;       c is at most n-2 
;       at most 595 cycles for any 16-bit decimal value 
;===============================================================
     ld hl,0          ;  10 : 210000 
ConvLoop:             ; 
     ld a,(de)        ;   7 : 1A 
     sub 30h          ;   7 : D630 
     cp 10            ;   7 : FE0A 
     ret nc           ;5|11 : D0 
     inc de           ;   6 : 13 
                      ; 
     ld b,h           ;   4 : 44 
     ld c,l           ;   4 : 4D 
     add hl,hl        ;  11 : 29 
     add hl,hl        ;  11 : 29 
     add hl,bc        ;  11 : 09 
     add hl,hl        ;  11 : 29 
                      ; 
     add a,l          ;   4 : 85 
     ld l,a           ;   4 : 6F 
     jr nc,ConvLoop   ;12|23: 30EE 
     inc h            ; --- : 24 			
     jr ConvLoop      ; --- : 18EB
     

;---------------------------------------------------------------------------------
;Should be calling allow IPD even in one for when in ASCII?				

GET_BYTE_WAIT_NUM:	CALL GET_BYTE_ALLOWIPD
			RET C
			CP '0'
			RET C
			CP '9'+1
			JR C,GBWN_ISDIGIT
			SCF
			RET

GBWN_ISDIGIT:		OR A			;CCF
			RET


;Print previous received byte for debugging in CIPSEND command echo mode

GET_BYTE_ALLOWIPD_T:	CALL DiagRST16

;Get a byte but allow an IPD incoming if in SIPSEND mode

GET_BYTE_ALLOWIPD:	BIT 0,(IX+0)
			JR Z,GET_BYTE_WAIT
			
;***TODO move IPD receive code to here

;Wait quite a while or a short while to receive a byte...


GET_BYTE_WAIT:		LD E,255
			JR GET_BYTE_2

GET_BYTE:		LD E,20

GET_BYTE_2:		LD BC,TX_CHKREADY
			IN A,(C)    ;mus� zde z�stat!!!!! vynechano jen za ucely testovani v emulu
			AND %00000001
			JR NZ,GET_BYTE_READY
			
			DEC E
			JR NZ,GET_BYTE_2
			SCF
			RET				;We timed out
			
GET_BYTE_READY:			
			LD A,14h			;143Bh - RX_SETBAUD
			IN A,(3Bh)			;Used as no effect on Flags for Zero from above
			
			OR A				;CCF
			RET
			
;---------------------------------------------------------------------------------
;Print a char in Inverse if Dignostics on
;***TODO really shoudl go to log or error channel.

DiagRST16:	
			BIT 6,(IX+0)
			RET Z
			
			PUSH AF
			PUSH AF
			LD A,'['
			RST 16
			POP AF
			CP 10
			JR NZ,Diag_NotLF
			LD A,'\\'
			RST 16
			LD A,'0'
			RST 16
			LD A,'A'
Diag_NotLF:		RST 16
			LD A,']'
			RST 16
			POP AF
				
			RET

;---------------------------------------------------------------------------------
;Keyboard scanning

;/* update 21:18 2.10.2016
;
;Busy's inkey routine taken from MRS
;
;
;"# inkey 03"
;Rutina INKEY na zacitanie prave stlacenej klavesy
;...pracuje presne tak ako funkcia INKEY$ v basicu
;Vracia:ASCII-kod prave stlacenej klavesy v registri A
;ak nie je nic stlacene tak vrati nulu
;prizrak ZERO sa nastavi podla nulovosti registra A
;*/
otherkey	defb $55
lastkey		defb $55
keywait		ld b,20
kw2		push bc
		ld b,0
kw1		djnz kw1
		pop bc
		djnz kw2
		ret
keysound  db 0		;0=zvuk klaves ano, 1=ne


scankeys
keyboard	
		call keywait
		call inkey	;Busy's MRS solution- the best:))
		or a
		jr nz,keyb1
		ld (lastkey),a
		ret		;if no key pressed, RETurn with A=0 and Z flag
;		jr keyboard
keyb1		ld bc,$400
keyb2		dec c
		jr nz,keyb2
		djnz keyb2
		ld c,a
		call inkey
		cp c
		jr nz,keyboard
		ld a,(lastkey)
		cp c
		jr z,keyb3
		ld a,$80
		jr keyb4
keyb3		ld a,(otherkey)
		ld b,a
keyb7		xor a
keyb5		dec a
		jr nz,keyb5
		call inkey
		cp c
		jr nz,keyboard
		djnz keyb7
		ld a,1
keyb4		ld (otherkey),a
		ld a,c
		ld (lastkey),a
beep		push af
;		or a			;tento or je pro rutinu MRS dulezity, jinak rutina kvici
		call beepk		;beep
		pop af
		ret		;end of Busy's solution			

beepk		ld a,(keysound)		;Busyho nahradni rutina,kratsi
		or a
		ret nz
		ld a,(23624)		;BORDER sys. variable
		rrca
		rrca
		rrca
		or #18
		out ($fe),a
		ld b,$1c
beepk1		djnz beepk1
		and 7
		out ($fe),a
		ret






za	
inkey	push hl                  ;Odlozenie
	push de                  ;povodneho
	push bc                  ;obsahu registrov
	ld   bc,$7ffe            ;adresa portu prvej polrady
	ld   h,$00               ;h=pocitadlo klaves
	ld   d,h                 ;d,e=pomocny buffer pre
	ld   e,h                 ;dve stlacene klavesy
ii1	ld   l,$05               ;v kazdej polrade je 5 klaves
	in   a,(c)               ;nacitanie polrady klavesnice
ii2	inc  h                   ;pre kazdy test sa pripocita +1
	rrca                     ;test jednej klavesy z polrady
	jr   c,ii3               ;nestlacena - skok
	ld   d,e                 ;stlacena: zapise sa do pomocneho
	ld   e,h                 ;buffera (tvoreneho registrom de)
ii3	dec  l                   ;A toto vsetko opakuj
	jr   nz,ii2              ;pre vsetky klavesy z polrady
	rrc  b                   ;A toto vsetko opakuj
	jr   c,ii1               ;pre vsetky polrady klavesnice
	ld   a,e                 ;\

	cp   $24                 ;Prehodenie poradia klaves tak
	jr   nz,ii5              ;aby shifty boli v registri D
	ld   e,d                 ;a vyznamne klavesy v E
	ld   d,$24               ; |
ii5	cp   $02                 ; |
	jr   nz,ii6              ; |
	ld   e,d                 ; |
	ld   d,$02               ;/
ii6	ld   hl,iinn             ;Z tabulky pre neshiftove
	xor  a                   ;klavesy sa bude citat
	xor  d                   ;ak nebol stlaceny ziadny shift
	jr   z,ii7               ;- vtedy skoc
	ld   hl,iiss             ;Ak bol stlaceny symbol shift
	cp   $02                 ;tak sa bude citat z tejto
	jr   z,ii7               ;tabulky - vtedy skoc
	ld   hl,iics             ;A na koniec je tu tabulka
	cp   $24                 ;pre caps shift
	jr   z,ii7               ;- vtedy skoc
	ld   a,$01               ;Ak su stlacene dve vyznamne
	jr   ii8                 ;klavesy - vtedy sa vrati kod #01
ii7	ld   d,$00               ;Prekodovanie kodovania klaves
	add  hl,de               ;podla pocitadla na kod ASCII
	ld   a,(hl)              ;Ak nie je nic stlacene,
ii8	and  a                   ;bude a=#00 a teda aj zero.
	pop  bc                  ;Obnovenie
	pop  de                  ;povodneho
	pop  hl                  ;obsahu registrov
	ret                      ;a koniec rutinky.

iinn	db   $00," ",$1c,"mnb"   ;Tabulka klaves
        db   13,"lkjh"           ;pre neshiftove klavesy
        db   "poiuy"
        db   "09876"
        db   "12345"
        db   "qwert"
        db   "asdfg"
        db   $00,"zxcv"
iics	db   $00,1,$0e,"MNB"   ;Tabulka klaves
        db   $02,"LKJH"          ;pre caps shift
        db   "POIUY"
        db   $08,$05,$09,$0b,$0a ;delete,graph,right,up,down
        db   $07,$02,$03,$04,$08 ;edit,caps lock,true.v.,inv.v.,left
        db   "QWERT"
        db   "ASDFG"
        db   $1f,"ZXCV"
;Tabulka klaves pre symbol shift, bohuzel pro MBC nutno prekopat
iiss	db   $00,$6,$1e,".,*"  ;SPC,SS,mnb
        db   $03,"=+-^"         ;ENT,lkjh
	db   $22,";]["		;poiuy 
        db   "_)(","'","&"	;09876
	db   "!@#$%"		;12345
	db   199,200,201,"<>"	;qwert	    misto 199 bylo #12
        db   "~|",$5C,$7B,$7D	;asdfg	    \{}
        db   $1d,":`?/"		;CS,zxcv
ko
le      =    ko-za





/* old one, working badly
oldkeys:		DEFB	0,0,0,0,0,0,0,0
newkeys:		DEFB	0,0,0,0,0,0,0,0
debkeys:		DEFB	0,0,0,0,0,0,0,0

scankeys:		ld	a,%01111111
			ld hl,oldkeys			;previous scan results
			ld de,newkeys			;new scan results
			ld bc,debkeys			;debounced keys ( press initiated this frame )
lp:			push af				;store A
			ld a,(de)			;get previous scan's result
			ld (hl),a			;store it in oldkey
			pop af				;restore A
			push af				;store A again
			in a,(254)			;get key row
			cpl				;invert bits 0 = not pressed 1 = pressed
			ld (de),a			;store in newkeys
			and (hl)			;and with old key
			ex de,hl			;swap regs for xor
			xor (hl)			;xor new key ( sets bit only when key initially pressed this scan ) 
			ex de,hl			;swap regs back
			ld (bc),a			;store in debounced keys
			pop af				;restore A
			inc  hl				;inc pointers
			inc de				;inc pointers
			inc bc				;inc pointers
			rrca				;next keyrow
			jr c,lp				;loop
			
			ld	de,KeyMap2		;point to new keymap
			ld	a,(oldkeys+0)		;test  for symbol shift
			and 2				;mask out symbol shift key
			jr z,nsym			;if not pressed ship
			ld a,(debkeys+0)		;remove symbol shift key
			and 31-2			;remove symbol shift key
			ld (debkeys+0),a		;remove symbol shift key
			ld de,KeyMapS			;set Symbol Shift key table
nsym:
			ld	a,(oldkeys+7)		;test  for caps
			and 1				;mask out caps key
			jr z,ncap			;if not pressed ship
			ld a,(debkeys+7)		;remove caps key
			and 31-1			;remove caps key
			ld (debkeys+7),a		;remove caps key
			ld de,KeyMapC			;set Caps key table
ncap:
			
			ld	hl,debkeys		;point to debounced keys
			ld	b,8			;8 rows
blp:			ld	a,(hl)			;get row
			or a				;has it got a key pressed
			jr nz,got1			;if so go to .got1
			inc de				;point to next keymap row
			inc de
			inc de
			inc de
			inc de
			inc hl				;point to next debounced row
			djnz blp			;loop 8 rows
			xor a				;nothing found
			ret				;return
got1:			rra				;get bit
			jr c,gotit			;if set we've got our key
			inc de				;point to next keymap
			jr got1				;loop until we find which key it was
gotit:			ld a,(de)			;get key ascii value
			ret				;return

KeyMap2:		DEFB " ",0,"m","n","b"
			DEFB 13,"l","k","j","h"
			DEFB "p","o","i","u","y"
			DEFB "0","9","8","7","6"
			DEFB "1","2","3","4","5"
			DEFB "q","w","e","r","t"
			DEFB "a","s","d","f","g"
			DEFB 0,"z","x","c","v"

KeyMapS:		DEFB 6,0,".",",","*"
			DEFB 13,"=","+","-","^"
			DEFB 34,";",0,93,91
			DEFB "_",")","(","'","&"
			DEFB "!","@","#","$","%"
			DEFB 0,0,0,"<",">"
			DEFB 126,124,92,123,125
			DEFB 0,":",96,63,47

KeyMapC:		DEFB " ",0,"M","N","B"
			DEFB 13,"L","K","J","H"
			DEFB "P","O","I","U","Y"
			DEFB 8,5,"8","7","6"			
			DEFB 1,2,3,4,"5"
			DEFB "Q","W","E","R","T"
			DEFB "A","S","D","F","G"
			DEFB 0,"Z","X","C","V"
				
*/

;---------------------------------------------------------------------------------

;Diagnostic routines...

print_regs:
			PUSH AF
			push BC
			push DE
			push HL
			
			
			ld HL, str_HL
			call print
			pop hl
			call prt_hex_16
			call print_newline
			
			ld HL, str_DE
			call print
			pop hl
			call prt_hex_16
			call print_newline
			
			ld HL, str_BC
			call print
			pop hl
			call prt_hex_16
			call print_newline

			ld HL, str_ACC
			call print
			pop af
			ld L,a
			call prt_hex
			call print_newline
			
			JR seperate
			
print_baud:		CALL print_newline

			LD HL, str_BAUD
			CALL print
			
			LD HL,(CURBAUD)		;Index into 8 long string lookup table
			LD DE,BaudTable
			ADD HL,HL		;multiply by 8
			ADD HL,HL
			ADD HL,HL
			ADD HL,HL   //LMN by 16
			ADD HL,DE		;and add base address
			CALL print
			
			CALL print_newline

seperate:		ld HL, str_separator
			call print
			
			ret

;Create a decimal string from number in HL at DE

string_dec:		res 7,(IX+0)		;Leading zero suppression
			ld bc,10000
			call string_dl
			ld bc,1000
			call string_dl
			ld bc,100
			call string_dl
			ld bc,10
			call string_dl
			ld a,l
			add a,'0'
			LD (DE),A
			INC DE
			RET
			
string_dl:		ld a,'0'-1

string_lp2:		inc a
			or a
			sbc hl,bc
			jr nc,string_lp2
			add hl,bc
			CP '0'
			JR Z,string_store

			SET 7,(IX+0)		;Had something other than zero

string_store:		BIT 7,(IX+0)		;Test if still leading zeros
			RET Z						
			LD (DE),A		;If not store it	
			INC DE
			RET
			
;---------------------------------------------		

openscreen:		ld a,2
			jp $1601
			
sprint:			pop	hl
			call print
			jp (hl)

print:			ld	a,(hl)
			inc hl
			or a
			ret z
			bit 7,a
			ret nz
			cp 10			;Suppress stray LF
			jr z,print
			rst 16
			jr print

print_newline:		ld hl,newline
			call print
			ret

hextab:			DEFM	"0123456789ABCDEF"

space:			ld	a,' '
			jp 16

prt_hex_16:		ld	a,h
			call prt_hex
			ld a,l
			
prt_hex:		push af
			rra
			rra
			rra
			rra
			call prt_hex_4
			pop af

prt_hex_4:		push hl
			and	15
			add a,hextab&255
			ld l,a
			adc a,hextab/256
			sub l
			ld h,a
			ld a,(hl)
			pop hl
			jp 16

prt_dec:		
			ld bc,10000
			call dl
			ld bc,1000
			call dl
			ld bc,100
			call dl
			ld bc,10
			call dl
			ld a,l
			add a,'0'
			jp 16
			
dl:			ld a,'0'-1

lp2:			inc a
			or a
			sbc hl,bc
			jr nc,lp2
			add hl,bc
			jp 16

Line1:		DEFB		0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
Line2:		DEFB		16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31

str_HL:		DEFM "HL   : "
		DEFB 0

str_DE:		DEFM "DE   : "
		DEFB 0

str_BC:		DEFM "BC   : "
		DEFB 0

str_ACC:	DEFM "ACC  : "
		DEFB 0

str_BAUD:	DEFB 13
		DEFB "BAUD : "
		DEFB 0

str_TIMEOUT:	DEFB "[Timeout on send - buffer lost]"
		DEFB 0

str_TIMEOUTCS:	DEFB "[Timeout on CIPSEND - sync lost]"
		DEFB 0		

str_TIMEOUTRX:	DEFB "[Timeout on recv - bytes lost]"
		DEFB 0

str_separator: 	DEFM "---------------------"
		DEFB 13,0

newline:	DEFB 13,0

Welcome:	DEFM "UART2.2f Simple ZX Next Terminal"
		DEFB 13
		DEFM "by Tim Gilberts based on code"
		DEFB 13
		DEFM "originally by Victor Trucco."
		DEFB 13
		DEFM "EDIT - change BAUD rate"
		DEFB 13
		DEFM "CAPS LOCK - ON/OFF (default ON)"
		DEFB 13
		DEFM "TRUE VIDEO - Debug CIPSEND/IPD"
		DEFB 13
		DEFM "INV VIDEO - CIPSEND mode ON/OFF"
		DEFB 13
		DEFM "GRAPHICS - EMIT EOT (1Ah)"
		DEFB 13
		DEFM "To exit press Sym Shift + SPACE"
		DEFB 13
;		DEFM "Start with -f option to find ESP"
;		DEFB 13
		defm "Arrow up - invokes last commmand"   ;MB03
		defb 13
		defm "Hood's ver.0.3-can send bytes"
		defb 13
		defm "version: "
	IFDEF	mb03plus
		defm "MB03+"
	ENDIF
	IFDEF	mb03plus_setup
		defm "MB03+"
	ENDIF
	IFDEF	eLeMeNtZX	
		defm "eLeMeNt ZX"
	ENDIF
	IFDEF	eLeMeNtZX_setup
		defm "eLeMeNt ZX"
	ENDIF


		DEFB 0

Searching:
		DEFM "Started with -f option."
		DEFB 13
		DEFM "Finding ESP"
		DEFB 13
		DEFM "(This may take some time)"
		DEFB 13
		DEFB 0
		
Timing:
		DEFM "Timing "
		DEFB 0
		 
Prescaler:	DEFM " applying prescaler "
		DEFB	0
		
BaudTable:			;All 8 bytes long for simple mult. Useful now we have higher speeds.
	DC "115_200         " ; 0

	DC "57_600          " ; 1

	DC "38_400          " ; 2

	DC "31_250          " ; 3

	DC "19_200          " ; 4

	DC "9_600           " ; 5

	DC "4_800           " ; 6

	DC "2_400           " ; 7

	DC "230_400         " ; 8

	DC "460_800         " ; 9

	DC "576_000         " ; 10

	DC "921_600         " ; 11

	DC "1_152_000       " ; 12

	DC "1_500_000       " ; 13

	DC "2_000_000       " ; 14

	DC "2_304_000       " ; 15

	DC "3_456_000       " ; 16

	DC "4_608_000       " ; 17

	DC "5_760_000       " ; 18

	DC "6_912_000       " ; 19

	DC "8_064_000       " ; 20

	DC "9_216_000       " ; 21

	DC "10_368_000      " ; 22
;	DEFW 0
	DC "11_520_000      " ; 23
;	DEFW 0		
BaudPrescale:

	DEFW 243,248,256,260,269,278,286,234 ; Was 0 - 115200 adjust for 0-7
	DEFW 486,496,512,521,538,556,573,469 ; 56k
	DEFW 729,744,767,781,807,833,859,703 ; 38k
	DEFW 896,914,943,960,992,1024,1056,864 ; 31250 (MIDI)
	DEFW 1458,1488,1535,1563,1615,1667,1719,1406 ; 19200
	DEFW 2917,2976,3069,3125,3229,3333,3438,2813 ; 9600
	DEFW 5833,5952,6138,6250,6458,6667,6875,5625 ; 4800
	DEFW 11667,11905,12277,12500,12917,13333,13750,11250 ; 2400
	DEFW 122,124,128,130,135,139,143,117 ; 230400 -8
	DEFW 61,62,64,65,67,69,72,59 ;460800 -9
	DEFW 49,50,51,52,54,56,57,47 ;576000 -10
	DEFW 30,31,32,33,34,35,36,29 ;921600 -11
	DEFW 24,25,26,26,27,28,29,23 ;1152000 -12
	DEFW 19,19,20,20,21,21,22,18 ;1500000 -13
	DEFW 14,14,15,15,16,16,17,14 ;2000000 -14
	
;Cannot go to 1200 as requires a pre-scaler greater than the 14 bit register available.
;For info on why the faster rates will be less accurate and reliable...
;https://arduino.stackexchange.com/questions/296/how-high-of-a-baud-rate-can-i-go-without-errors
	
SYNERR		DEFB 13
		DEFM "SYNTAX ERROR, try again.."
		DEFB 13,0

CIPON:		DEFB 13
		DEFM "CIPSEND ON (ECHO OFF)"
		DEFB 13,0
	
CIPOFF:		DEFB 13
		DEFM "CIPSEND OFF"
		DEFB 13,0

ANSION:		DEFB 13
		DEFM "ANSI ON"
		DEFB 13,0
		
ANSIOFF:	DEFB 13
		DEFM "ANSI OFF"
		DEFB 13,0
	
IPDABORT:	DEFM "[IPD,abort]"
		DEFB 0

ATE0:		DEFM "ATE0"	; Need to ensure no local echo in CIPSEND mode
		DEFB 13,10,0

DEFBAUD:	DEFM "AT+UART=115200,8,1,0,0"
		DEFB 13,10,0

;Response Messages - these are the things we need to wait for to confirm things

;**TODO convert from inline
;
IPDSTART:	DEFM "IPD,"		; May not match this one as inline allows us to avoid check for IPD IN an IPD!
		DEFB 0

CIPSTART:	DEFM "OK"		; Sip send skip 
		DEFB 13,10,'>',0

CIPSOK:		DEFM "SEND " ; After a CIPSEND we need to skip over the Recv x bytes \n SEND OK ...

OK:		DEFM "OK"		

CRLF:		DEFB 13,10,0

ERROR:		DEFM "ERROR"
		DEFB 13,10,0

	
;---------------------------------------------------------------------------------
;Variables and buffers 


CURBAUD:	DEFB 0			;start at 115200
		DEFB 0			;Zero for easy load at 16bits

Buffer1:	DEFS 256		; SEND BUFFER
		defb 13,10
Endbuffers:	DEFB 10			; A default LF to finish

Buffer2:	DEFS 1024		; RECV BUFFER (in CIPSEND/IPD mode) May need to increase
Buf2Pos:	DEFW Buffer2		; Where are we in Buffer2

;MB03
Buffer3		DEFS 256		; special buffer for a new command
Buffer4		DEFS 256		; history buffer,curently uses only 1 entry. Invoked by arrow up.
;end MB03

FLAGS:		DEFB 0			; IX+0 First of the IX accessed FLAGS When bit set : 0=CIPSEND MODE, 1=ANSI, 2=Looking for ESC, 3=BUFFER2
					; 6 = debug command print mode, 7=leading zero suppression in number prints.
IPDSIZE:	DEFW 0			; IX+1,2
GOTNUM:		DEFS 10			; Space to decode 
ESCPARAMS:	DEFB 0			; IX+13 count of number of ESC paramters
		DEFS 20			; Space for upto 20
ESCCMD:		DEFB 0			; IX+33 The actual ANSI command


CIPSEND:	DEFM "AT+CIPSEND="
STRINGNUM:	DEFS 7			;Space to create  65536\CR\lf
		DEFB 0


;		DEFC Buffer1 = 09000h	;36864
;		DEFC Buffer2 = 09100h	;37120
;		DEFC Endbuffers = 09200h ;40960

last:
;savebin "uart",start1,.last-start1
;SAVESNA "uart.sna",start1
endramcode
total_len	equ	$-start_addresss
	
;-------------------------------
CODE	=	#AF
USR		=	#C0
LOAD	=	#EF
CLEAR	=	#FD
RANDOMIZE =	#F9
		
	org	#5C00		;; Basic loader
baszac	db	0,1			;; Line number
	dw	linlen			;; Line length
linzac
	db	CLEAR,'8',#0E,0,0
	dw	ramcode-1
	db	0,':'
	db	LOAD,'""',CODE,':'
	db	RANDOMIZE,USR,'8',#0E,0,0
	dw	ramcode
	db	0,#0D
linlen	=	$-linzac
baslen	=	$-baszac
	
		
	savesna  "uart.sna",ramcode
	EMPTYTAP "uart.tap"
	SAVETAP  "uart.tap" , BASIC, uart , baszac,baslen,1
	SAVETAP  "uart.tap",CODE,"uart",maincode,endramcode-maincode,maincode

	