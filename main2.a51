;********************************************************
;	Author :	Gilad Savoray
;	Date :		30 Nov 2022
;	File :		main2.a51
;
;	Hardware :	Any 8052 based MicroConverter (ADuC8xx)
;	Description:	Player two in Pong!
;********************************************************
;	Displays scores and sends player's two inputs to player one
;	
;	
;********************************************************

#include <aduc841.h>
#include <protocol.asm>

LED EQU P3.4
FLAG_SEARCH_AVG EQU 1


DSEG at 30h
	DRAW_STATE: DS 1	; drawing digit number #
	DRAW_LENGTH: DS 1
	
	SCORES_DIGIT_START:
	PLAYER_TWO_SCORE: DS 2
	PLAYER_ONE_SCORE: DS 2
	
	_AVG: DS 2
	_MIN: DS 2
	_MAX: DS 2
		
	_MAX_t_high: DS 1
	_MIN_t: DS 2
BSEG
	TIMER_DRAW_FLAG: DBIT 1  ; waits for this flag to go up in order to start drawing
		
		_IGNORE_BUTTON: DBIT 1

CSEG at 0000h
jmp START

;________________________________________________________
; SUBROUTINES
CSEG AT 000Bh ; ISR of timer 0 interrupt	-	frame tick
	jmp timer0_isr
	
CSEG AT 0023h ; ISR of UART interrupt
	jmp UART_isr
	
CSEG AT 002Bh ; ISR of timer 2 interrupt	-	input tick
	jmp timer2_isr

;________________________________________________________
; MAIN PROGRAM
CSEG AT 0200h ; start far away
START:
	CALL INIT_INTS
	
	mov _MIN, #0h
	mov _MIN+1, #0h
	
	mov _MAX, #0FFh
	mov _MAX+1, #0FFh
	
	;% debug timers
	; good timers - original
	;mov _AVG+1, #0FFh
	;mov _AVG, #3Ah
	
	; after searching:
	mov _AVG+1, #0FBh
	mov _AVG, #0FEh
			
	call update_AVG
		
		
	
	; drawing the frame tick of DRAW_INDEX
	CLR TIMER_DRAW_FLAG
	CLR _IGNORE_BUTTON
	
	; orgenize register meanings....
	; ...
	MOV R0, #0		; R0 - current draw index (overriden in DRAW_POINT_FRAME)
	MOV DRAW_LENGTH, #0		; current length of segment
	
	MOV R2, #0		; R2 - player one score
	MOV R3, #0		; R3 - player two score
	mov R4, #0		; R4 - current digit X pos
	
	
	MOV R6, #0		; R6 - DAC0 output (overriden in DRAW_POINT_FRAME)
	MOV R7, #0		; R7 - DAC1 output (overriden in DRAW_POINT_FRAME)
	
	call NEW_FRAME_INIT
	
    ;infinite loop
	INF_LOOP:
		JNB TIMER_DRAW_FLAG, INF_LOOP
		call DRAW_POINT_FRAME
		CLR TIMER_DRAW_FLAG
	jmp INF_LOOP
    
;________________________________________________________
; Sets the correct timer, UART and DAC settings

	INIT_INTS:
		CLR EA  			; DISABLES INTS GLOBALLY

		
		; Timers 0 & 1
		mov TMOD, #00100001b ; timer1 is a timer, mode=10 so 8 bit with reload from TL1
							 ; timer0 is a timer, mode=01 so 16 bit, no auto reload!
				
		; Timer 0
		SETB ET0 	; enable Timer 0 interrupts
		SETB TR0 	; turn on timer 0   
		MOV TL0, #10h	; 1 TICK
		MOV TH0, #00h	; 1 TICK   	; SAME AS LOW FOR INIT
		
		; Timer 1
		CLR ET1 	; disables Timer 1 interrupts
		CLR TR1 	; turn off timer 1

		;Timer 2
		SETB ET2	; enables interrupts Timer2
		SETB TR2	; turn on Timer2
		MOV TH2, #28h ; 1240d in timer2 registers for it to make 5[ms] interrupts
		MOV TL2, #00h
		; 16 bit -if timer 2 registers are 0 it overflows every 5.9 [ms] - for us every 5[ms]
		CLR RCLK	; when these 2 bits of T2CON are clear, Timer[1 or 3] is serial clock
		CLR TCLK
		CLR EXEN2	; bit 3 of T2CON - should be cleared
		CLR CNT2	; bit 2 of T2CON - set to function as a timer
		CLR CAP2	; bit 1 of T2CON - should be cleared
		

		; DAC0 & DAC1
		MOV DACCON, #11111111b	; 8bit, VDD DAC1, VDD DAC0, real output 0 of DAC1, real output of DAC0, sync, DAC1 on, DAC0 on
		mov DAC0H, #0	; reset both registers
		mov DAC0L, #0
		
		; UART
		SETB ES 		; disables UART interrupts
		CLR SM0
		SETB SM1	; UART in mode 1 - 8bit
		SETB REN	; allows the serial port re receive data
		; Timer3 (UART baud rate)
		orl T3CON, #10000111b ; T3BAUDEN=1, X, X, X, X, DIV2, DIV1, DIV0
		; baudrate = 57600 = actual BR		DIV=3	T3FD=32
		; set DIV2=0, DIV1=1, DIV0=1	and T3FD
		anl T3CON, #11111011b
		mov T3FD, #32
		
		
		SETB EA 	; ENABLES INTS GLOBALLY	
	RET
;________________________________________________________
; TIMER 0 ISR - set DRAW_POINT_FLAG
	TIMER0_ISR:
		push psw
		SETB TIMER_DRAW_FLAG
		;MOV TL0, #10h	; 1 TICK
		;MOV TH0, #00h	
		mov TH0, _AVG+1
		mov TL0,  _AVG
		pop psw
	RETI
;________________________________________________________
; draw a point of the current frame

	DRAW_POINT_FRAME:
		push psw
		push ACC
		
		CPL LED
		
		; R0 - index
		; R6 - DAC0 (X)
		; R7 - DAC1 (Y)
		
		; check if we are at the end of the current digit
		mov A, R0
		CJNE A, DRAW_LENGTH, skip_next_digit_load
		
		; inc DRAW_STATE to the next digit
		inc DRAW_STATE	; next digit
		; next R4 value
		call _INC_X_OFFSET
		
		mov A, DRAW_STATE
		CJNE A, #2, DRAW_CONT1
		call _INC_X_OFFSET
		call _INC_X_OFFSET
		
		DRAW_CONT1:
		; check if DRAW_STATE is too high
		mov A, DRAW_STATE
		CJNE A, #4, DONT_RESET_STATE
		mov DRAW_STATE, #0	; reset draw_state (the digit we are drawing)
		mov R4, #START_X_POS
		call NEW_FRAME_INIT
		
		DONT_RESET_STATE:
			; finished digit, load the new one
			mov A, #SCORES_DIGIT_START
			add A, DRAW_STATE
			mov R1, A
			mov A, @R1	; next digit in A and R1
			mov R1, A
			
			mov DPTR, #LENGTHS
			MOVC A, @A+DPTR	; read length
			xch A, R1	; R1=length, A=digit
			mov DRAW_LENGTH, R1
			
			; reset draw index
			mov R0, #0
			
			; base DPTR
			CJNE A, #0, $ + 3 + 3
			mov DPTR, #NUMBER0_X
			CJNE A, #1, $ + 3 + 3
			mov DPTR, #NUMBER1_X
			CJNE A, #2, $ + 3 + 3
			mov DPTR, #NUMBER2_X
			CJNE A, #3, $ + 3 + 3
			mov DPTR, #NUMBER3_X
			CJNE A, #4, $ + 3 + 3
			mov DPTR, #NUMBER4_X
			CJNE A, #5, $ + 3 + 3
			mov DPTR, #NUMBER5_X
			CJNE A, #6, $ + 3 + 3
			mov DPTR, #NUMBER6_X
			CJNE A, #7, $ + 3 + 3
			mov DPTR, #NUMBER7_X
			CJNE A, #8, $ + 3 + 3
			mov DPTR, #NUMBER8_X
			CJNE A, #9, $ + 3 + 3
			mov DPTR, #NUMBER9_X

		
		skip_next_digit_load:
		
		; set DAC0 (R6)
		mov A, R0	; index to A
		MOVC A, @A+DPTR	; read next X value
		add A, R4	; offset X pos
		mov R6, A
		
		; set DAC1 (R7)
		mov A, R0	; index to A
		add A, DRAW_LENGTH	; fix A to Y value address
		MOVC A, @A+DPTR		; read next Y value
		add A, #START_Y_POS	; offset Y pos
		mov R7, A
		
		inc R0	; next index



		
		PUSH_TO_DACS:
		ANL DACCON, #11111011b	; clear sync bit
		MOV DAC0L, R6
		MOV DAC1L, R7
		ORL DACCON, #00000100b	; set sync bit
		

		pop ACC
		pop psw
	reti
	
	; adds offset jump to X the next positions
	_INC_X_OFFSET:
		push ACC
			mov A, R4
			add A, #OFFSET_X_JUMP
			mov R4, A
		pop ACC
	RET
;________________________________________________________
; debug frame rate helper

	update_AVG:
		push psw
		push ACC
			mov A, #FLAG_SEARCH_AVG
			jz _update_avg_skip

			;; calc MIN /= 2
			;CLR C
			;mov A, _MIN+1
			;RRC A
			;mov _MIN_t+1, A
			;mov A, _MIN
			;RRC A
			;mov _MIN_t, A
			
			;; calc MAX /= 2
			;CLR C
			;mov A, _MAX+1
			;RRC A
			;mov _MAX_t_high, A
			;mov A, _MAX
			;RRC A
			;;redundent		mov _MAX_t, A		; line(*)
			
			
			;; calc AVG = MIN + MAX
			;;reduntent		mov _AVG, _MIN_t
			;mov _AVG+1, _MIN_t+1
			;; redundent bc line(*) 		mov A, _MAX
			;add A, _MIN_t
			;mov _AVG, A
			;mov A, _MAX_t_high
			;addc A, _AVG+1
			;mov _AVG+1, A
			
			
			; calc AVG = MIN + MAX
			mov _AVG, _MIN
			mov _AVG+1, _MIN+1
			
			mov A, _MAX
			add A, _AVG
			mov _AVG, A
			mov A, _MAX+1
			addc A, _AVG+1
			
			; calc AVG /= 2
			RRC A
			mov _AVG+1,A
			mov A, _AVG
			RRC A
			mov _AVG, A
			_update_avg_skip:
		pop ACC
		pop psw
	RET
;________________________________________________________
; locks digit string in memory, in order to draw a single frame

	NEW_FRAME_INIT:
		mov R0, #0	; reset DRAW INDEX
		
		mov A, R2
		mov B, #10d
		div AB
		mov PLAYER_ONE_SCORE + 0, B
		mov PLAYER_ONE_SCORE + 1, A
		
		mov A, R3
		mov B, #10d
		div AB
		mov PLAYER_TWO_SCORE + 0, B
		mov PLAYER_TWO_SCORE + 1, A
	RET
;________________________________________________________
; a UART event

; Bit TI is the serial port transmit interrupt flag. This bit is set when the UART has finished
;		transmitting a byte. Because there is only one serial port interrupt, the processor must have some
;		way of informing the user whether the interrupt was triggered by the end of the transmission of a
;		byte or by the reception of one byte. This bit and RI allow you to determine what the cause of
;		the interrupt was.
; Bit RI is the serial port receive interrupt flag. It is set when a byte has been received. Note that
;		TI and RI are not cleared by the ADuC841. They must be cleared in the interrupt subroutine.

	UART_ISR:
		push PSW
		jnb RI, UART_SENT
		UART_RECEIVED:
			CLR RI
			push ACC
				mov A, SBUF
				
				_UART_NEXT0:
				CJNE A, #PR_P1scoreInc, _UART_NEXT1	; increment P1 score
				call INC_PLAYER_ONE_SCORE
				
				_UART_NEXT1:
				CJNE A, #PR_P2scoreInc, _UART_NEXT2	; increment P2 score
				call INC_PLAYER_TWO_SCORE
				
				_UART_NEXT2:
				CJNE A, #PR_ResetScores, _UART_NEXT_FINISH	; reset both scores
				call SCORE_RESET
				
				_UART_NEXT4:
				CJNE A, #PR_ResetDEBUG, _UART_NEXT_FINISH	; reset game debug req 	00000011b	(DEBUG ONLY)
				call RESET_REQUEST
				
				_UART_NEXT_FINISH:
			pop ACC
			
			jmp UART_END_ISR
		UART_SENT:
		
		UART_END_ISR:
		CLR TI	; cleared manualy
		pop PSW
	RETI
;________________________________________________________

	TIMER2_ISR:
		; row1 [1][2][3]
		; row2 [4][5][6]
		; row3 [7][8][9]
		; row4 [*][0][#]
		
		;check which key was pressed - lower voltage on each column and check to see if voltage
		;on any of the rows has gone low as well
		CLR TF2 ;bit 7 of T2CON -must be cleared after interrupt
		MOV TH2, #28h ; 1240d in timer2 registers for it to make 5[ms] interrupt
		MOV TL2, #00h


		; row1 [1][2][3]
		MOV P2, #11111110b ; OUT0:2.0 OUT1(read INPUT): 2.4, 2.5, 2.6
		JNB P2.4, KEYPAD_1
		JNB P2.5, KEYPAD_2_portal
		JNB P2.6, KEYPAD_3
		
		; row2 [4][5][6]
		MOV P2, #11111101b ; OUT0:2.1 OUT1(read INPUT): 2.4, 2.5, 2.6v
		JNB P2.4, KEYPAD_4
		JNB P2.5, KEYPAD_5
		JNB P2.6, KEYPAD_6
		
		; row3 [7][8][9]
		MOV P2, #11111011b ; OUT0:2.2 OUT1(read INPUT): 2.4, 2.5, 2.6
		JNB P2.4, KEYPAD_7
		JNB P2.5, KEYPAD_8
		JNB P2.6, KEYPAD_9
		
		; row4 [*][0][#]
		MOV P2, #11110111b ; OUT0:2.3 OUT1(read INPUT): 2.4, 2.5, 2.6
		JNB P2.4, KEYPAD_star
		JNB P2.5, KEYPAD_0
		JNB P2.6, KEYPAD_hashtag
		
		KEYPAD_NONE:
			CLR _IGNORE_BUTTON
		KEYPAD_CONT:
		RETI
		
; =-=-=-=-=-=-=-=-==-=-=-=-=-=-=-

		; empty keys
		KEYPAD_5:
			jmp KEYPAD_CONT
		
		; === SEND MIN ===
		KEYPAD_1:
			JB _IGNORE_BUTTON, KEYPAD_CONT
			;% debug timer
			mov SBUF, _MIN+1
			
			SETB _IGNORE_BUTTON
			jmp KEYPAD_CONT
		KEYPAD_3:
			JB _IGNORE_BUTTON, KEYPAD_CONT
			;% debug timer
			mov SBUF, _MIN
			
			SETB _IGNORE_BUTTON
			jmp KEYPAD_CONT
		; === SEND AVG ===
		KEYPAD_4:
			JB _IGNORE_BUTTON, KEYPAD_CONT
			;% debug timer
			mov SBUF, _AVG+1
			
			SETB _IGNORE_BUTTON
			jmp KEYPAD_CONT
		KEYPAD_6:
			JB _IGNORE_BUTTON, KEYPAD_CONT
			;% debug timer
			mov SBUF, _AVG
			
			SETB _IGNORE_BUTTON
			jmp KEYPAD_CONT
		; === SEND MAX ===
		KEYPAD_7:
			JB _IGNORE_BUTTON, KEYPAD_CONT
			;% debug timer
			mov SBUF, _MAX+1
			
			SETB _IGNORE_BUTTON
			jmp KEYPAD_CONT
		KEYPAD_9:
			JB _IGNORE_BUTTON, KEYPAD_CONT
			;% debug timer
			mov SBUF, _MAX
			
			SETB _IGNORE_BUTTON
			jmp KEYPAD_CONT
		; === CHANGE VALUES ===
		KEYPAD_star:
			jb _IGNORE_BUTTON, KEYPAD_CONT
			;% debug timer WANT SMALLER VALUE
			mov _MAX, _AVG
			mov _MAX+1,_AVG+1
			mov SBUF, #'4'
			call update_AVG
			
			setb _IGNORE_BUTTON
			jmp KEYPAD_CONT
																KEYPAD_2_portal: jmp KEYPAD_2
		KEYPAD_hashtag:
			jb _IGNORE_BUTTON, KEYPAD_CONT
			;% debug timer WANT BIGGER VALUE
			mov _MIN, _AVG
			mov _MIN+1,_AVG+1
			mov SBUF, #'6'
			call update_AVG
			
			SETB _IGNORE_BUTTON
			jmp KEYPAD_CONT
			
		
		; ACTUAL GAME KEYS
		KEYPAD_2:
			; MOVE_RIGHT_PEDAL_UP
			mov SBUF, #PR_RightPedalUp
			jmp KEYPAD_CONT
		KEYPAD_8:
			; MOVE_RIGHT_PEDAL_DOWN
			mov SBUF, #PR_RightPedalDown
			jmp KEYPAD_CONT
		KEYPAD_0:
			; SEND RESET REQUEST
			mov SBUF, #PR_ResetDEBUG
			jmp KEYPAD_CONT

	reti
;________________________________________________________

	INC_PLAYER_ONE_SCORE:
		inc R2
	RET
	
	
	INC_PLAYER_TWO_SCORE:
		inc R3
	RET
	
	
	SCORE_RESET:
		mov R2, #0
		mov R3, #0
	RET
	
	
	RESET_REQUEST:
		call SCORE_RESET
	RET
;________________________________________________________
#include <draw2.asm>
END