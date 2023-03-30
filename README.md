# RC2014-MIDI
framework and example programs that work with my MIDI module for RC2014

The MIDI module Adds MIDI in and MIDI out to a RC2014 computer (requires enhanced backplane, SIO/2 module and cp/m.)


# usage

duplicate this file and name it something appropriate for your project

edit the introduction: string

make sure MIDI.asm is in the same location as this file and that this file includes MIDI.asm

call init_serial  to set up the buffers and the interrupts.

to receive MIDI - 
>call MIDI_task frequenty
>write a callback labeled midi_message_received:  which will be called when there is a full message
>you can access the message in midi_message: (3 bytes) or midi_message, midi_note and midi_velocity

optionally uncomment the lines indicated in MIDI.asm and write a callback called midi_byte_received:


to send MIDI - 
>call send_note_off:
- a = channel
- b = note
>call send_note_on:			
- a = channel
- b = note
- c = velocity
>call send_midi_message:			
- a = message / channel  mmmmcccc
- b = second byte, eg note
- c = third byte, eg velocity
>call send_midi_byte:	
>can be used to build your own messages, particularly where you need to send a different number of bytes than 3
- byte in e	

>call restore_system  to restore interrupts to cp/m before exit


