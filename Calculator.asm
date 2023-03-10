;----------
;Import Definitions
;----------

;----------
;Port Definitions
;----------

;Port def for buttons aand switches
BUTTONS_in 										   DSIN $02
SWITCHES_in 		   			   				   DSIN $03


char21 	  			   			   				   DSOUT $04
;port def for 2 lower 7SD
char43	  			   			   				   DSOUT $05
;port def for 2 upper 7SD
LEDS_out	  			   			   			   DSOUT $06
;port def for LEDs

temp1 	  			   			   				   EQU 01
;Temporary register, scratchpad 01
temp2	  			   			   				   EQU 02
;Temporary register, scratchpad 01
temp3	  			   			   			   	   EQU 03
;Temporary register, scratchpad 01

;--------------------
;Main routine
;-
;Handles reading inputs and loading them into registers
;Then calls the appropriate calculation subroutine
;--------------------
start:
	  
	  ;-----
	  ;First two numbers from Switches:
	  ;-----
	  
	  ;Load switch values into register s0
	  IN		   	s0,SWITCHES_in
	  
	  ;Store register s0 into temporary memory
	  STORE	 		s0,temp1
	
 	  ;Output stored value to display
	  OUT	 		s0,char43
	  
	  ;100ms delay & check for reset
	  CALL	 	    delay_reset
	
	  ;-----
	  ;Read desired operation from Buttons:
	  ;-----

read_buttons:
	
 	  ;Load button values into register s1
	  IN		   	s1,BUTTONS_in
	
	  ;Store register s1 into temporary memory
	  STORE	 		s1,temp2
	
 	  ;Output stored value to LEDs
	  OUT	 		s1,LEDS_out
	
	  ;100ms delay & check for reset
	  CALL	 	    delay_reset
	
	  ;If no buttons are pressed,
	  ; assume the user is still entering the second digit,
	  ; so loop until they press a button
	  COMP		 s1, $00
	  JUMP		 Z, read_buttons
	  	
	  ;-----
	  ;Second two numbers from Switches:
	  ;-----
	
	  ;Load switch values into register s2
	  IN		   	s2,SWITCHES_in
	
	  ;Store register s2 into temporary memory
	  STORE	 		s2,temp1
	
 	  ;Output stored value to display
	  OUT	 		s2,char43
	
	  ;100ms delay & check for reset
	  CALL	 	    delay_reset
	
	  ;-----
	  ;Flash LEDs twice to acknowledge inputted values
	  ;-----
	  
	  ;Load value 1 into register sB (flash alternating LEDs twice)
	  LOAD		    sB, $01
	  
	  ;Call LED flash subroutine:
	  CALL			flash_LEDs
	  
	  ;100ms delay & check for reset
	  CALL	 	    delay_reset
	  
	  ;-----
	  ;Read which operation to do from pushbuttons:
	  ;-----
	
	  ;Addition check
	  ;if PB 2 is activated, s1 = 0x2
	  COMP	   	  	s1, $02
	  JUMP			Z, addition
	  
	  ;Subtraction check
	  ;if PB 3 is activated, s1 = 0x4
	  COMP	   	  	s1, $04
	  JUMP			Z, subtraction
	  
	  ;Multoplication check
	  ;if PB 4 is activated, s1 = 0x8
	  COMP	   	  	s1, $08
	  JUMP			Z, multiplication
	  
	  ;Division check
	  ;if PB 5 is activated, s1 = 0x10
	  COMP	   	  	s1, $10
	  JUMP			Z, division
	  
 finish:
	  
	  ;100ms delay & check for reset
	  CALL			delay_reset
	  
	  ;Load value 2 into register sB (flash alternating LEDs 4 times)
	  LOAD		    sB, $02
	  CALL 			flash_LEDs
	  
 wait_for_buttons:
 
	  ;Only prepare for another calculation if all buttons have been released
	  IN		   	s1,BUTTONS_in			
	  COMP		 	s1, $00
	  JUMP		 	NZ, wait_for_buttons
	  
	  ;Restart main program loop
	  ;Skip entering of digit A into register S0 so that S0 can
	  ; act as an Accumulator (peristst over multiple calculations)
	  JUMP			read_buttons
	
;--------------------
;Calculation Subroutine definitions
;-
;Defines the subroutines that do the 4 main calculations:
;(Addition, Subtraction, Multiplication, Division)
;--------------------

addition:
	  ;Add the values of registers s0 and s2
	  ; and output the result (stored in s0) to 2 lower 7SDs
	  ADD			s0, s2
	  OUT			s0,char21
	  
	  JUMP			finish
	  
subtraction:
	  ;Subtract the values of registers s0 and s2
	  ; and output the result (stored in s0) to 2 lower 7SDs
	  SUB 			s0, s2
	  OUT			s0,char21
	  
	  JUMP			finish
	  
multiplication:
	  ;s0 - Multiplicand
	  ;s2 - Multiplier
	  ;s4 - Bit mask
	  ;s5 - result MSB
	  ;s6 - result LSB (and final output)
	  
	  ;Set Bit mask to 1 and MSB & LSB to 0
	  LOAD		   s4, $01
	  LOAD		   s5, $00
      LOAD		   s6, $00
	  
	  multiplication_loop:
			;Check if bit is set.
			;If TRUE/set, skip addition (jump to no_addition)
			;Else add MSB and Multiplcand
	        TEST		  s2, s4
	        JUMP		  Z, no_addition
	        ADD			  s5, s0
	        

	        no_addition:
			;Shift MSB right: carry moves to b7, LSB moves to carry
			;then shift LSB right: LSB from result MSB moves to b7
			;then shift bit mask left to examine next bit in multilier
	        SRA			  s5
	        SRA			  s6
	        SL0			  s4
	        
	        ;If bit mask is 0, all bits have been examined and result can be output
	        ; otherwise, repeat loop
	        JUMP 		  NZ, multiplication_loop
	        OUT			  s6, char21
	        
	        JUMP		  finish
	        
division:
	  ;s0 - Dividend
	  ;s2 - Divisor
	  ;s7 - Quotient (and final output)
	  ;s8 - Remainder
	  ;s9 - Bit mask
	
	  ;Set remainder to 0  and start bit mask at MSB
	  LOAD		   s8, $00
      LOAD		   s9, $80
	
	  division_loop:
			;Check if bit is set.
			;If TRUE/set, set carry
			;Shift carry into LSB of remainder
			;Shift quotient left (which doubles it)
			;Check if remainder > divisor?
			; If yes, skip subtraction (jump to no_subtraction)
			; and then subtract divisor from remainder.
	        TEST		  s0, s9
	        SLA		  	  s8
	        SL0			  s7
	        COMP		  s8, s2
			JUMP		  C, no_subtraction
			SUB			  s8, s2
			ADD			  s7, $01
			
	        no_subtraction:
	        ;Shift bit mask left, examining next bit
	        SR0			  s9

	        ;If bit mask is 0, all bits have been examined and result can be output
	        ; otherwise, repeat loop
	        JUMP 		  NZ, division_loop
	        OUT			  s7, char21
	
	        JUMP		  finish
	        
;--------------------
;Light flashing Subroutine definition
;--------------------
flash_LEDs:
	  ;Clear LEDs by loading 0 ($00) into them
	  LOAD 	      s3, 	$00
	  
	  ;Load register and then LEDs with hex $55 (0101010101010101)
	  LOAD		  sC, $55
	  OUT		  sC, LEDS_out
	  
	  ;Subtract 1 from sB (which stores how many times the lighs should flash)
	  SUB		  sB, $01
	  
	  ;Load register and then LEDs with hex %AA (1010101010101010)
	  ;This alternates the lights
	  LOAD		  sC, $AA
	  OUT		  sC, LEDS_out
	  
	  ;If sB does not equal zero, repeat this subroutine
	  JUMP		  NZ, flash_LEDs
	  
	  ;Turn off all LEDs
	  LOAD		  sC, $0
	  OUT		  sC, LEDS_out
	  
	  ;Return to where this subroutine was called in the main routine
	  RET
	  
;--------------------
;Delay & Reset Subroutine definition
;--------------------
delay_reset:
			
	  ;Read input pushbuttons and load them into register s1
	  ; if the value is 1 ($01) then the reset PB is being pressed.
	  ; (So jump to start)
	  IN	     s1, BUTTONS_in
	  COMP		 s1, $01
	  JUMP		 Z, start
	  
	  ;Otherwise continue with 100ms delay (value can be tuned to change delay)
	  LOAD		 sA, 3
	  
	  ;Loop until the value in sA is 0 (thus introducing a blocking delay)
	  delay1:
	  SUB		 sA, 01
	  JUMP		 NZ, delay1
	
	  ;Return to where this subroutine was called in the main routine
	  RET
	  

	  	
