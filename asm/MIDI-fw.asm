;=========================================================
; MIDI_fw	- RC2014 MIDI framework
; S Dixon https://peacockmedia.software

; for S.Dixon's MIDI board for RC2014 with SIO2 and CP/M
;
;
; This file is part of RC2014 MIDI framework.
; RC2014 MIDI framework is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
; as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
;
; Copyright 2023 Shiela Dixon 
;
;
; last updated 23 Mar 2023
; builds with zasm or z88dk 
;
; if z88dk, uncomment the indicated lines 
; and compile with something like zcc +rc2014 -vn -startup=31 myprog.asm -o myprog.com

;=========================================================


; This is a template or framework. 
;
; usage
; =====
;
; duplicate this file and name it something appropriate for your project
; edit the introduction: string
;
; make sure MIDI.asm is in the same location as this file and that this file includes MIDI.asm
;
; call init_serial  to set up the buffers and the interrupts.
;
; to receive MIDI - 
; call MIDI_task frequenty
; write a callback labeled midi_message_received:  which will be called when there is a full message
; you can access the message in midi_message: (3 bytes) or midi_message, midi_note and midi_velocity
;
; optionally uncomment the lines indicated in MIDI.asm and write your own callback called midi_byte_received
;
;
; to send MIDI - 
; 	send_note_off:
			; a = channel
			; b = note
; 	send_note_on:			
			; a = channel
			; b = note
			; c = velocity
;	send_midi_message:			
			; a = message / channel  mmmmcccc
			; b = second byte, eg note
			; c = third byte, eg velocity
; 	send_midi_byte:	
			; can be used to build your own messages, particularly where you need to send a different number of bytes than 3
			; byte in e	
;
;
; call restore_system  to restore interrupts to cp/m before exit
;
;
;
;



; for zasm
#target BIN
#code PAGE1,$100	; for cpm 
;
; for z88dk
; ORG $100	; for CPM
; PUBLIC _main
;




BDOS			equ $05

A_STATIN		equ 7		; Entered with C=7. Returns A=0 or 0FFh.
A_STATOUT		equ 8

GETIOBYTE		equ 7
SETIOBYTE		equ 8


A_READ			equ 3			; Entered with C=3. Returns A=L=ASCII character. Note that this call can hang if the auxiliary input never sends data.
A_WRITE			equ 4			; Entered with C=4, E=ASCII character.

C_READ			equ  1			;READ CONSOLE  C_READ
C_WRITE			equ  2			;TYPE FUNCTION C_WRITE
PRINT_STR		equ  9			;BUFFER PRINT ENTRY
CONS_STAT		equ  11			;(TRUE IF CHAR READY)   Returns A=0 if no characters are waiting, nonzero if a character is waiting.
C_READSTR		equ	 10			; reads characters from the keyboard into a memory buffer until RETURN is pressed. The Delete key is handled correctly
								; On entry, DE is the address of a buffer.
C_RAWIO			equ 6

echo_mode		equ 30






CHANNEL			equ 0


		


_main:
	    ld      (OldSP),sp                      ; save old Stack poitner
	    ld      sp, Stack                       ; set up Stack


;=========================================================
; intro / menu

		call printCR
		ld de,introduction
		call print_str
		call printCR
		call printCR	
		

		call init_serial
		
						

main_loop:		


testkey:	
		; test
		LD	A,(serABufUsed)
		CP	$00
		JR	Z, testmidi
		
		call coninA	; blocking, test with serABufUsed before using. 
		
		cp 27
		jr z,gracefulexit




testmidi:
		call MIDI_task

		jp main_loop
			
			
			
			
			



gracefulexit:

		call restore_system
        ld      sp, (OldSP)
        rst     0




;=========================================================
; this is our callback routine, 
; called whenwe have a full midi message
; you can find the message in midi_message: (3 bytes)
; or midi_message, midi_note and (guess) midi_velocity

			
midi_message_received:


		
		ld a,(midi_message)
		call outbits
		ld a,' '
		call chrout
		ld a,(midi_note)
		call outbits
		ld a,' '
		call chrout
		ld a,(midi_velocity)
		call outbits
		ld a,' '
		call chrout
		
		call printCR
		call printCR


		ret








;=========================================================
; subroutines - general utilities

outbits:
		; outputs A as binary, ie 01010101
		push af
		push bc
		
		ld b,8
obloop:		
		bit 7,a
		jr z,ob0	; 0

ob1:		
		push af
		push bc
		ld a,'1'
		call chrout
		; affects C & E
		pop bc
		pop af
		jr obendlp
		
ob0:
		push af
		push bc
		ld a,'0'
		call chrout
		; affects C & E
		pop bc
		pop af
	
obendlp:
		sla a
		djnz obloop

		pop bc
		pop af
		ret



outhex:

		; Output A in hexidecimal

        push    af
        rra
        rra
        rra
        rra
        call    nybhex
        call    chrout
        pop     af
        call    nybhex
        jp      chrout

; convert lower nybble of A to hex (also in A)
; from http://map.grauw.nl/sources/external/z80bits.html#5.1
nybhex:
        or      0f0h
        daa
        add     a, 0a0h
        adc     a, 40h
        ret





printCR:
		ld A,$0d
		call chrout
		ld A,$0a
		call chrout
		ret
	
	
printSpace:
		ld A,$20
		call chrout
		ret
		



bell:
		ld A,$07	;esc
		call chrout
	
		ret	


	
	
	
print_str:
		;D,E ADDRESSES OF MESSAGE ENDING WITH "$"
		ld c,PRINT_STR
		call BDOS
				
		ret
	
	
chrout:
		; affects C & E
		ld E,A
		ld C,C_WRITE
		call BDOS
		ret
chrin:
		;Entered with C=1. Returns A=L=character.
		ld C,C_READ
		call BDOS
		ret


clr_buffer:
		ld C,CONS_STAT
		call BDOS
		cp 0	
		ret z
		
		; clear it
		call chrin
		jp clr_buffer







RND8:
		call fastRND
		and %00000111	; 0-7

		ret


	
		; Fast RND
		;
		; An 8-bit pseudo-random number generator,
		; using a similar method to the Spectrum ROM,
		; - without the overhead of the Spectrum ROM.
		;
		; R = random number seed
		; an integer in the range [1, 256]
		;
		; R -> (33*R) mod 257
		;
		; S = R - 1
		; an 8-bit unsigned integer

fastRND:
        push    hl
        push    de
        ld      hl,(seed)
        ld      a,r
        ld      d,a
        ld      e,(hl)
        add     hl,de
        add     a,l
        xor     h
        ld      (seed),hl
        pop     de
        pop     hl
        ret





#include "./MIDI.asm"




;=========================================================
; vars



seed: 				defb 00,00

soundVoiceFrequencyLowCache: 		defb $c5,$d6,0
soundVoiceFrequencyHighCache: 		defb 01,0,0




introduction:
	dm "Software framework for RC2014 and MIDI module",10,13,"S Dixon 2023",'$'
	
	
	
OldSP:
        defw 0
        defs 64
Stack:	
	