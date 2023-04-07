# RC2014-MIDI
framework and example programs that work with my MIDI module for RC2014

The MIDI module Adds MIDI in and MIDI out to a RC2014 computer (requires enhanced backplane, SIO/2 module and cp/m.)

# setting up

Important: If you're using the dual clock module, make sure that the jumper for Clock 2 is removed completely, or if you have no Ext clock in place on that board, move the jumper to the 'ext' (rightmost) setting. Also, remove the jumper on the SIO/2 module for Port B Clock.  All of this is necessary so that the MIDI module can clock your Port B at the correct speed via the Clck2 bus line.

If you remove the MIDI module, remember to set the jumpers back to their original setting. I believe the SIO2 needs a clock signal for Port B even if you're not using it. 

# usage

duplicate mid-fw.asm and name it something appropriate for your project

edit the introduction: string

make sure that it ncludes MIDI.asm and that MIDI.asm is in the same location.

call init_serial   sets up the buffers and the interrupts.

to receive MIDI - 
* call MIDI_task frequenty
* write a callback labeled midi_message_received:  which will be called when there is a full message
* you can access the message in midi_message: (3 bytes) or midi_message, midi_note and midi_velocity
* optionally uncomment the lines indicated in MIDI.asm and write a callback called midi_byte_received:


to send MIDI - 
* call send_note_off
  * a = channel
  * b = note
* call send_note_on			
  * a = channel
  * b = note
  * c = velocity
* call send_midi_message	
  * a = message / channel  mmmmcccc
  * b = second byte, eg note
  * c = third byte, eg velocity
* call send_midi_byte
  * can be used to build your own messages, particularly where you need to send a different number of bytes than 3
  * byte in e	

* call restore_system  to restore interrupts to cp/m before exit


