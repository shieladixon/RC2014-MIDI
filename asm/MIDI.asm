; This file is part of RC2014 MIDI framework.
; RC2014 MIDI framework is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
; as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
;
; Copyright 2023 Shiela Dixon 
;
;
;
;
;
; to receive MIDI - 
; call MIDI_task frequenty
; it will call your midi_message_received:  when there is a full message
; handles running status
; you can find the message in midi_message: (3 bytes) or midi_message, midi_note and midi_velocity


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




SIOB_C				EQU	$82
SIOB_D				EQU	$83

SIOA_C				EQU	$80
SIOA_D				EQU	$81

RTS_HIGH			EQU	0E8H
RTS_LOW				EQU	0EAH

SER_BUFSIZE_A		EQU	60	; keyboard buffer - same size as with CPM
SER_BUFSIZE_B		EQU	200	; MIDI in buffer		; make sure <256 as only the low byte is compared with the end of buffer to indicate need to wrap
SER_FULLSIZE		EQU	50	; these only apply to A. B is our MIDI in/out and it doesn't use CTS or RTS
SER_EMPTYSIZE		EQU	5

serABuf:			ds	SER_BUFSIZE_A	; SIO A Serial buffer
serAInPtr:			dw	0000			; very important that this follows serABuf as it's also used as a pointer to the end of the buffer
serARdPtr:			dw	0000
serABufUsed:		db	000
serBBuf:			ds	SER_BUFSIZE_B	; SIO B Serial buffer
serBInPtr:			dw	0000			; very important that this follows serBBuf as it's also used as a pointer to the end of the buffer
serBRdPtr:			dw	0000
serBBufUsed:		db	00h

vectorstore:		dw 0000


init_serial:
		xor	a		

		ld	(serABufUsed),A
		ld	(serBBufUsed),A
		ld	HL,serABuf
		ld	(serAInPtr),HL
		ld	(serARdPtr),HL

		ld	HL,serBBuf
		ld	(serBInPtr),HL
		ld	(serBRdPtr),HL


; set up interrupts

		; DI disables interupts
		; EI enables

		di
		
		; NB CPM (or at least the version I have) does this to set the SIO2's interrupt address FFE0
		; and put the interrupt servicing routine's address at FFE0
		; 
		; we're going to stick the address of our own routine in there. (after saving the existing address so that we can restore it and exit gracefully)
		; under a different system it may be necessary to use the code below to set up our interupt properly
		;
		; I might put this into place anyway, so that this program will work on any system with a SIO2 (as long as $FFE0 is available)
		
		
		;	LD	A,$02
		;	OUT	(SIOB_C),A
		;	LD	A,$E0		; INTERRUPT VECTOR ADDRESS
		;	OUT	(SIOB_C),A


		; Interrupt vector in page FF
		;	LD	A,$FF
		;	LD	I,A
		
		

		ld hl,($FFE0)
		ld (vectorstore),hl
		
		ld	hl,serial_task		; ADDress of serial interrupt.
		ld	($FFE0),hl
					
		ei
		

		ret



restore_system:
		di
		ld hl,(vectorstore)
		ld ($FFE0),hl
		ei

		ret






;================================================================================================
; Interrupt routine - serial in buffering
; based on CP/M code  
;================================================================================================


serial_task:

		push	af
		push	hl
		push 	bc
		
		

		; Check if there is a char in channel A
		; If not, Check if there is a char in channel B
		sub	a
		out (SIOA_C),a
		in  a,(SIOA_C)	; Status byte D2=TX Buff Empty, D0=RX char ready	
		rrca			; Rotates RX status into Carry Flag,	
		jr	nc, serialIntB

serialIntA:
		ld	bc,serAInPtr
		ld	hl,(serAInPtr)
		inc	hl
		ld	a,l
		cp	c
		jr	nz, notAWrap
		ld	hl,serABuf
notAWrap:
		ld	(serAInPtr),hl
		in	a,(SIOA_D)
		ld	(hl),a

		ld	a,(serABufUsed)
		inc	a
		ld	(serABufUsed),a
		cp	SER_FULLSIZE
		jr	C,rtsA0
	    ld	a,$05
		out  (SIOA_C),a
	    ld	a,RTS_HIGH
		out	(SIOA_C),a
rtsA0:
		pop bc
		POP	hl
		POP	af
		ei
		reti


serialIntB:

		sub	a
		out (SIOB_C),a
		in  a,(SIOB_C)	; Status byte D2=TX Buff Empty, D0=RX char ready	
		rrca			; Rotates RX status into Carry Flag,	
		jr	nc,rtsB0


		ld bc,serBInPtr		; is address of end of buffer
		ld	hl,(serBInPtr)
		INC	hl
		ld	a,l
		CP	c
		jr	nz,notBWrap
		ld	hl,serBBuf
notBWrap:
		ld	(serBInPtr),hl
		in	a,(SIOB_D)
		
		ld	(hl),a
		ld	a,(serBBufUsed)
		inc	a
		ld	(serBBufUsed),a
		
		; this is irrelevant with MIDI, there is no flow control. We're relying on a bigger buffer and this computer being fast compared to the MIDI serial speed (31.25k baud)
		;CP	SER_FULLSIZE
		;JR	C,rtsB0
;rtsBskp:		
	    ;LD   	A,$05
		;OUT  	(SIOB_C),A
	    ;LD   	A,RTS_HIGH
		;OUT  	(SIOB_C),A
rtsB0:

		
		pop bc
		pop	hl
		pop	af
		ei
		reti





;===================================================================================================================
; Accessors - test serABufUsed / serBBufUsed first if you want to avoid blocking (if they're zero, no byte waiting)
; or use as is to wait for the next byte
;===================================================================================================================


coninA:					; blocking routine

waitForCharA:
		ld	A,(serABufUsed)
		cp	$00
		jr	z, waitForCharA
		ld	hl,(serARdPtr)
		inc	hl
		ld	a,l
		ld BC,serAInPtr
		cp	c
		jr	NZ, notRdWrapA
		ld	hl,serABuf		; wrap
notRdWrapA:
		ld	(serARdPtr),hl

		ld	a,(serABufUsed)
		dec	a
		ld	(serABufUsed),a

		cp	SER_EMPTYSIZE
		jr	nc,rtsA1
	    ld 	a,$05
		out	(SIOA_C),a
	    ld	a,RTS_LOW
		out	(SIOA_C),a
rtsA1:
		ld	a,(hl)

		ret			; Char ready in A




coninB:					; blocking routine

waitForCharB:
		ld	a,(serBBufUsed)
		cp	$00
		jr	z,waitForCharB
		ld	hl,(serBRdPtr)
		inc	hl
		ld	a,l
		ld	bc,serBInPtr
		cp	c
		jr	NZ,notRdWrapB
		ld	hl,serBBuf		; wrap
notRdWrapB:

		ld	(serBRdPtr),hl

		ld	a,(serBBufUsed)
		dec	a
		ld	(serBBufUsed),a

		; this is irrelevant for port B (MIDI) as it has no flow control. 
		;CP	SER_EMPTYSIZE
		;JR	NC,rtsB1
	    ;LD   	A,$05
		;OUT  	(SIOB_C),A
	    ;LD   	A,RTS_LOW
		;OUT  	(SIOB_C),A
;rtsB1:
		ld	a,(hl)

		ret			; Char ready in A






;========================================================================================================
; MIDI Task
; Call this frequently. It handles the input buffer and makes a callback when there's a complete message
;========================================================================================================


MIDI_task:

			ld	a,(serBBufUsed)
			cp	$00
			ret	z		; nothing waiting in buffer
			
			call coninB	; blocking, test with serBBufUsed before using.
			
			
			; new byte received is in A
			cp $fe
			jr z,dunlogging		; ignore fe	- Active Sensing - sent at a fast rate, so as to be a problem.
								; should probably nip in the bud earlier and not buffer it.
												
			cp $f8
			jr nz,notClock
			
			ld hl,(clock_count)		; 16-bit value
			inc hl					; read clock_count in your program. it'll reach 24 every quarter note from the start of the song. 
			ld (clock_count),hl	
			jp dunlogging
					
		
notClock:			
			ld(byte_received),a	; store it, we'll need to retrieve this a few times
			
			
			; uncomment this line and implement midi_byte_received in your program to do something with that byte, eg print it
			;call midi_byte_received
			

			
			
			ld a,(byte_received)
			and %10000000
			jr z,notMessage
			
; we have a 1xxxxxxx  byte			
			ld a,(byte_received)
			ld (midi_message),a
			ld a,1
			ld (message_pointer),a
			jr dunlogging
			
			
notMessage:			
; we have a 0xxxxxxx byte
			ld a,(message_pointer)
			cp 0
			;  This may be 'running status' - assume this is the 'note' byte and the message is the same as the previous message
			jr z,notebyte

			cp 2
			jr z, velocitybyte		
notebyte:			
			ld a,(byte_received)
			ld (midi_note),a
			ld a,2
			ld (message_pointer),a	; next will be velocity
			jr dunlogging
			
velocitybyte:
			ld a,(byte_received)
			ld (midi_velocity),a
			ld a,0
			ld (message_pointer),a	; next will be message


; we have the full 3 bytes of a message - handle with a callback
		
			call midi_message_received
			
		
	
			
dunlogging:			

			; how about looping to see whether there's anything else in the buffer?
			; only return when the buffer is empty
			jp MIDI_task
			;ret
			
			
			
			
			
		
;========================================================================================================
; Some useful convenience functions for sending MIDI out
; 
;========================================================================================================



send_note_off:
			; a = channel
			; b = note
			
			or a,$80
			ld c,0
			call send_midi_message
			ret


send_note_on:			
			; a = channel
			; b = note
			; c = velocity

			or a,$90		
			call send_midi_message
			ret
			
			
			
send_midi_message:			
			; a = message / channel  mmmmcccc
			; b = second byte, eg note
			; c = third byte, eg velocity
			
			push bc
			push bc
			
			ld e,a
			call send_midi_byte
			
			pop bc		; restore saved velocity (c)
			ld e,b
			call send_midi_byte	

			pop bc		; restore saved velocity (c)
			ld e,c
			call send_midi_byte	

			ret
			
			
send_midi_byte:	
			; byte in e	
			;push de
			ld C,A_WRITE ; Entered with C=4, E=ASCII character.
			call BDOS
			;pop de
			;ld a,e
			;call outbits
			;call printCR
			
			ret
			
			


			
;=========================================================
; vars		
;=========================================================	

byte_received:		defb 00

message_pointer:	defb 00		; 0 is message, 1 is note, 2 is velocity

midi_message:		defb 00
midi_note:			defb 00
midi_velocity:		defb 00

clock_count: 		defw 0000

midi_channel:		defb 00