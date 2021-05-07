;****************** main.s ***************
; Program written by: Anthony Do
; Date Created: 2/4/2017
; Last Modified: 1/17/2021
; Brief description of the program
;   The LED toggles at 2 Hz and a varying duty-cycle
; Hardware connections (External: One button and one LED)
;  PE1 is Button input  (1 means pressed, 0 means not pressed)
;  PE2 is LED output (1 activates external LED on protoboard)
;  PF4 is builtin button SW1 on Launchpad (Internal) 
;        Negative Logic (0 means pressed, 1 means not pressed)
; Overall functionality of this system is to operate like this
;   1) Make PE2 an output and make PE1 and PF4 inputs.
;   2) The system starts with the the LED toggling at 2Hz,
;      which is 2 times per second with a duty-cycle of 30%.
;      Therefore, the LED is ON for 150ms and off for 350 ms.
;   3) When the button (PE1) is pressed-and-released increase
;      the duty cycle by 20% (modulo 100%). Therefore for each
;      press-and-release the duty cycle changes from 30% to 70% to 70%
;      to 90% to 10% to 30% so on
;   4) Implement a "breathing LED" when SW1 (PF4) on the Launchpad is pressed:
;      a) Be creative and play around with what "breathing" means.
;         An example of "breathing" is most computers power LED in sleep mode
;         (e.g., https://www.youtube.com/watch?v=ZT6siXyIjvQ).
;      b) When (PF4) is released while in breathing mode, resume blinking at 2Hz.
;         The duty cycle can either match the most recent duty-
;         cycle or reset to 30%.
;      TIP: debugging the breathing LED algorithm using the real board.
; PortE device registers
GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C
; PortF device registers
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_PUR_R   EQU 0x40025510
GPIO_PORTF_DEN_R   EQU 0x4002551C
GPIO_PORTF_LOCK_R  EQU 0x40025520
GPIO_PORTF_CR_R    EQU 0x40025524
GPIO_LOCK_KEY      EQU 0x4C4F434B  ; Unlocks the GPIO_CR register
SYSCTL_RCGCGPIO_R  EQU 0x400FE608

       IMPORT  TExaS_Init
       THUMB
       AREA    DATA, ALIGN=2
;global variables go here

ONDuty	SPACE 4
OFFDuty	SPACE 4
BDutyON	SPACE 4
BDutyOFF	SPACE 4
SlopeCt	SPACE 1
RampFlag	SPACE 1
       AREA    |.text|, CODE, READONLY, ALIGN=2
       THUMB

       EXPORT  Start
		   
;Delays the sim/circuit depending on the value initialized in R2
Delay  SUBS R2, R2, #1
	   BNE  Delay
	   BX LR



Start
 ; TExaS_Init sets bus clock at 80 MHz
     BL  TExaS_Init
	;A. Turn on the clock on port E and F
	LDR R0, =SYSCTL_RCGCGPIO_R ;read
	LDRB R1, [R0]
	ORR R1, #0x30 ;modify
	STRB R1, [R0]
	;B. Wait for clock to stabalize
	NOP 
	NOP
	;C. Define Input and output for Port E (DIR)
	LDR R0, =GPIO_PORTE_DIR_R
	LDRB R1, [R0]
	AND R1, #0xFD
	ORR R1, #0x04
	STRB R1, [R0]
	;D. Digitally enable E pins (DEN)
	LDR R0, =GPIO_PORTE_DEN_R
	LDRB R1, [R0]
	ORR R1, #0x06
	STRB R1, [R0]
	;E. Define Input and output for Port F (DIR)
	LDR R0, =GPIO_PORTF_DIR_R
	LDRB R1, [R0]
	BIC R1, R1, #0x10
	STRB R1, [R0]
	;F. Digitally enable F pins (DEN)
	LDR R0, =GPIO_PORTF_DEN_R
	LDRB R1, [R0]
	ORR R1, #0x10
	STRB R1, [R0]
	;G. Activate pull-up register to make PF4 negative logic (PUR)
	LDR R0, =GPIO_PORTF_PUR_R
	LDRB R1, [R0]
	MOV R1, #0x10
	STRB R1, [R0]
; voltmeter, scope on PD3
; Initialization goes here
    CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
	LDR R0, =3000000
	LDR R1, =ONDuty	;ON Duty cycle init. 30%
	STR R0, [R1]
	LDR R0, =7000000 
	LDR R1, =OFFDuty ;OFF Duty cycle init. 70%
	STR R0, [R1]
	LDR R0, =20000
	LDR R1, =BDutyON ;Breathing ON Duty cycle init. 10%
	STR R0, [R1] 
	LDR R0, =180000
	LDR R1, =BDutyOFF ;Breathing OFF Duty cycle init. 90%
	STR R0, [R1]
	LDR R2, =0	;Previous state init not pressed
	MOV R0, #8
	LDR R1, =SlopeCt
	STRB R0, [R1]	;slope count starts at 8
	MOV R0, #1
	LDR R1, =RampFlag	;if RampFlag = 1, bfunc ramping, otherwise ramp down
	STRB R0, [R1]
loop
	MOV R10, #0 ;number of cycles so far
	LDR R0, =GPIO_PORTF_DATA_R
	LDRB R1, [R0]
	AND R1, #0x10	;isolating PF4 bit
	CMP R1, #0x10	;checking if PF4 is 0 or 1
	BEQ Normal	;equal, so PF4 is 1 (negative logic), go to Normal
BsetPE2
	LDR R0, =GPIO_PORTE_DATA_R
	MOV R1, #0x04
	STRB R1, [R0]
	LDR R5, =BDutyON
	LDR R2, [R5]
	BL Delay
	BIC R1, R1, #0x04
	STRB R1, [R0]
	LDR R5, =BDutyOFF
	LDR R2, [R5]
	BL Delay
	ADD R10, R10, #1
	LDR R11, =12 ;total number of cycles
	CMP R10, R11
	BNE BsetPE2
	LDR R5, =SlopeCt
	LDRB R8, [R5]
	MOV R5, #8
	CMP R8, R5
	BEQ SetRampUp
	MOV R5, #0
	CMP R8, R5
	BEQ SetRampDown
ChooseRamp
	LDR R5, =RampFlag
	LDRB R9, [R5]
	MOV R5, #0
	CMP R9, R5
	BNE RampUp
	B RampDown
SetRampUp
	LDR R5, =RampFlag
	MOV R9, #1
	STRB R9, [R5]
	B ChooseRamp
SetRampDown
	LDR R5, =RampFlag
	MOV R9, #0
	STRB R9, [R5]
	B ChooseRamp
RampDown
	ADD R8, R8, #1
	LDR R5, =SlopeCt
	STRB R8, [R5]
	LDR R5, =BDutyON
	LDR R6, [R5]
	LDR R5, =BDutyOFF
	LDR R7, [R5]
	LDR R5, =20000 ;change
	SUB R6, R6, R5	
	ADD R7, R7, R5	
	LDR R5, =BDutyON
	STR R6, [R5]	;Breathing ON Duty -=10
	LDR R5, =BDutyOFF
	STR R7, [R5]	;Breathing OFF Duty +=10
	B loop
RampUp
	SUB R8, R8, #1
	LDR R5, =SlopeCt
	STRB R8, [R5]
	LDR R5, =BDutyON
	LDR R6, [R5]
	LDR R5, =BDutyOFF
	LDR R7, [R5]
	LDR R5, =20000 ;change
	ADD R6, R6, R5	
	SUB R7, R7, R5	
	LDR R5, =BDutyON
	STR R6, [R5]	;Breathing ON Duty +=10
	LDR R5, =BDutyOFF
	STR R7, [R5]	;Breathing OFF Duty -=10
	B loop

;Precondition: takes R1(current state) and R2(previous state)
;Postcondition: Both not pressed, go to setPE2
;				Previous (R2): Pressed, Current (R1): Pressed/Not -> Keep Polling
;				Previous (R2): Not pressed, Current (R1): Pressed -> Change Duty Cycle
Normal
	LDR R0, =GPIO_PORTE_DATA_R
	LDRB R1, [R0]
	AND R1, #0x02	;isolating PE1 bit
	CMP R2, #2	;checking if the previous state was pressed
	BNE	CompSt	;Previous not pressed, compare again
	MOV R2, R1	;setting previous state
	B loop
CompSt	;comparing the states
	CMP R2, R1
	BNE Change	;Previous (R2): Not pressed, Current (R1): Pressed 
	MOV R2, R1
	B setPE2	;Both not pressed
Change
	LDR R5, =ONDuty
	LDR R3, [R5]
	LDR R5, =OFFDuty
	LDR R4, [R5]
	MOV R2, R1
	LDR R5, =9000000	;temp register
	CMP R3, R5
	BEQ	Recycle	;if ONDuty = 90%, recycle duties
	LDR R5, =2000000
	ADD R3, R3, R5	
	SUB R4, R4, R5	
	LDR R5, =ONDuty
	STR R3, [R5]	;ON Duty +=20%
	LDR R5, =OFFDuty
	STR R4, [R5]	;OFF Duty -=20%
	B setPE2
Recycle
	LDR R3, =1000000	
	LDR R5, =ONDuty
	STR R3, [R5]	;ON Duty = 10%
	LDR R4, =9000000	
	LDR R5, =OFFDuty
	STR R4, [R5]	;OFF Duty = 90%
	B setPE2
setPE2	
	MOV R1, #0x04
	STRB R1, [R0]
	LDR R5, =ONDuty
	LDR R2, [R5]
	BL Delay
	BIC R1, R1, #0x04
	STRB R1, [R0]
	LDR R5, =OFFDuty
	LDR R2, [R5]
	BL Delay	
; main engine goes here
     
	 B    loop
     

      
     ALIGN      ; make sure the end of this section is aligned
     END        ; end of file

