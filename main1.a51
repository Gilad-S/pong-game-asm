;********************************************************
;	Author :	Gilad Savoray
;	Date :		22 Nov 2022
;	File :		main1.a51
;
;	Hardware :	Any 8052 based MicroConverter (ADuC8xx)
;	Description:	Player one in Pong! main computer.
;********************************************************
;	R0 gets overriden in draw
;	R1 gets overriden in calc
;	
;	To-Do:
;		add back timer1 - consistent ball movement - test IRL
;		random ball movement
;		reset score button(?)
;
;********************************************************
;	Timer0 - Frame-dot tick. 60 FPS = 233*60 ticks per second = 791 cycles;	120 FPS = 233*120 ticks per second = 395 cycles
;	Timer1 - Game-tick	- every 4(ms), moves ball every 20(ms)
;	Timer2 - Read keypad input - every 5(ms)
;	Timer3 - UART, baud rate of 57600
;********************************************************

#include <aduc841.h>
#include <protocol.asm>

LED EQU P3.4

GAME_STATE_PLAYING	EQU 0
GAME_STATE_P1_LOST	EQU 1
GAME_STATE_P2_LOST	EQU 2
GAME_STATE_IDLE		EQU 3

PEDAL_STEP			EQU 2
GAME_TICK_DIV_BY	EQU 5


;		20FPS		30 FPS		60 FPS		120 FPS		240 FPS
; TH =	F6h			F9h			FCh			FEh			FFh
; TL =	BAh			D1h			E8h			75h			3Ah
; dec =	63,162		63,953		64,744		65,140		65,338

; originally it had 185 FPS


; AUTO-RELOADS of timers
TIMER0_TH			EQU 0FFh	; 120 FPS x 233 DOTS = 2^16-395
TIMER0_TL			EQU 03Ah	; 120 FPS

TIMER1_TH			EQU 53h		; 21,298d in timer1 registers for it to make 5[ms] interrupt
TIMER1_TL			EQU	32h

TIMER2_TH			EQU 27h		; 10,239d in timer2 registers for it to make 5[ms] interrupt
TIMER2_TL			EQU	0ffh



DSEG at 30h
	DRAW_INDEX: DS 1  ; DRAW_INDEX goes from 0 to 255
	
	PEDAL_LEFT_Y: DS 1
	PEDAL_RIGHT_Y: DS 1
	BALL_X_POS: DS 1
	BALL_Y_POS: DS 1
	BALL_X_VEL: DS 1
	BALL_Y_VEL: DS 1
	
	DRAW_PEDAL_LEFT_Y: DS 1
	DRAW_PEDAL_RIGHT_Y: DS 1
	DRAW_BALL_X_POS: DS 1
	DRAW_BALL_Y_POS: DS 1
	
	GAME_STATE: DS 1	; indicates the game state. 0 = playing, 1=p1 lost, 2=p2 lost, 3=waiting for input
	GAME_TICK_DIV: DS 1	; every GAME_TICK_DIV frames, the game will get an update
	
	RANDOM_VALUE: DS 1
	
BSEG
	TIMER_DRAW_FLAG: DBIT 1  ; waits for this flag to go up in order to start drawing
	GAME_TICK_FLAG: DBIT 1  ; waits for this flag to go up in order to move a game tick
	
	__IS_DRAWING_BALL_UP: DBIT 1
	__IS_DRAWING_BALL_NOW: DBIT 1
	
	BALL_Y_VEL_DIR: DBIT 1
	BALL_X_VEL_DIR: DBIT 1
	
	IS_RANDOM_BUSY: DBIT 1

CSEG at 0000h
jmp START

;________________________________________________________
; SUBROUTINES
CSEG AT 000Bh ; ISR of timer 0 interrupt	-	frame tick
	jmp timer0_isr
	
CSEG AT 0023h ; ISR of UART interrupt
	jmp UART_isr
	
CSEG AT 001Bh ; ISR of timer 1 interrupt	-	game tick
	jmp timer1_isr
	
CSEG AT 002Bh ; ISR of timer 2 interrupt	-	input tick
	jmp timer2_isr
	
CSEG AT 0033h ; ISR of ADC	-	when finished converting
	jmp ADC_isr

;________________________________________________________
; MAIN PROGRAM
CSEG AT 0200h ; start far away
START:
	CALL INIT_INTS
	
	CALL SAMPLE_NEW_RANDOM
	jb IS_RANDOM_BUSY, $	; wait until first random bit is here
	
	
	; drawing the frame tick of DRAW_INDEX
	MOV DRAW_INDEX, #0
	CLR TIMER_DRAW_FLAG
	CLR GAME_TICK_FLAG
	
	; orgenize register meanings.... TODO
	; ...
	MOV R0, #0		; R0 - current draw index (overriden in DRAW_POINT_FRAME)
	
	call RESET_GAME
	
	
	MOV R6, #0		; R6 - DAC0 output (overriden in DRAW_POINT_FRAME)
	MOV R7, #0		; R7 - DAC1 output (overriden in DRAW_POINT_FRAME)
	

	
	call NEW_FRAME_INIT
	
    ; infinite (game & draw) loop
	INF_LOOP:
		_INF_LOOP_NEXT0:
		JNB GAME_TICK_FLAG, _INF_LOOP_NEXT1
		clr LED ; temporary
		call CALC_GAME_TICK
		call HANDLE_GAME_STATE
		CLR GAME_TICK_FLAG
		
		
		_INF_LOOP_NEXT1:
		JNB TIMER_DRAW_FLAG, _INF_LOOP_NEXT2
		call DRAW_POINT_FRAME
		CLR TIMER_DRAW_FLAG


		;_INF_LOOP_NEXT2:
		;JNB GAME_TICK_FLAG, _INF_LOOP_NEXT3
		;call CALC_GAME_TICK
		;CLR GAME_TICK_FLAG
		
		_INF_LOOP_NEXT2:
	jmp INF_LOOP
    
;________________________________________________________
; Sets the correct timer, UART and DAC settings

	INIT_INTS:
		CLR EA  			; DISABLES INTS GLOBALLY

		; Timers 0 & 1
		mov TMOD, #00010001b ; timer1 is a timer, mode=01 so 16 bit with reload from TL1			0 0 01
							 ; timer0 is a timer, mode=01 so 16 bit with reload from TL0,TH0		0 0 01
				
		; Timer 0
		SETB ET0 	; enable Timer 0 interrupts
		SETB TR0 	; turn on timer 0   
		MOV TL0, #TIMER0_TL
		MOV TH0, #TIMER0_TH
		
		; Timer 1
		SETB ET1 	; enables Timer 1 interrupts
		SETB TR1 	; turn on timer 1
		MOV TL1, #40h	; 1 game TICK
		MOV TH1, #00h	; 1 TICK   	; SAME AS LOW FOR INIT

		;Timer 2
		SETB ET2	; enables interrupts Timer2
		SETB TR2	; turn on Timer2
		mov RCAP2L, #TIMER2_TL
		mov RCAP2H, #TIMER2_TH
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
		
		
		; ADC
		MOV ADCCON1, #10110000b ; active[1], use internal referance[0], CLK/2[11], 1 acquire cycle (maybe change)[00], not with T2[0], dnt ext trigger[0]
		; ADCCON2 - channel selection [000]
		CLR CS0
		CLR CS1
		CLR CS2
		CLR CS3
		SETB EADC ; enables interrupts
		
		SETB EA 	; ENABLES INTS GLOBALLY	
	RET
;________________________________________________________
; TIMER 0 ISR - set DRAW_POINT_FLAG
	TIMER0_ISR:
		push PSW
			MOV TL0, #TIMER0_TL
			MOV TH0, #TIMER0_TH
			
			SETB TIMER_DRAW_FLAG
		pop PSW
	RETI
	
	TIMER1_ISR:
		push PSW
			MOV TL1, #TIMER1_TL
			MOV TH1, #TIMER1_TH
				
			DJNZ GAME_TICK_DIV, $ + 3 + 2 + 3 + 2			; 3
			SETB GAME_TICK_FLAG	; will move the ball		; 2
			MOV GAME_TICK_DIV, #GAME_TICK_DIV_BY			; 3
			setb LED										; 2 temporary

		pop PSW
	RETI
;________________________________________________________
; draw a point of the current frame

	DRAW_POINT_FRAME:
		push DPL
		push DPH
		push psw
		push ACC
		
		; R0 - index
		; R2 - 
		; R6 - DAC0 (X)
		; R7 - DAC1 (Y)

		mov R0, DRAW_INDEX
		; fix DRAW_INDEX to branch logic (when needed):
		
		__DRAW_NEXT_0:
		; if not drawing the ball up, skip to a later DRAW_INDEX
		CJNE R0, #BALL_UP_START_INDEX, __DRAW_NEXT_1
		setb __IS_DRAWING_BALL_NOW
		JB __IS_DRAWING_BALL_UP, __DRAW_NEXT_1
		clr __IS_DRAWING_BALL_NOW
		mov R0, #BALL_UP_END_INDEX	; skip drawing ball_up
		mov DRAW_INDEX, R0
		jmp __DRAW_START_X
		
		__DRAW_NEXT_1:
		; if got to BALL_UP_END_INDEX, set __IS_DRAWING_BALL_NOW to 0
		CJNE R0, #BALL_UP_END_INDEX, __DRAW_NEXT_2
		clr __IS_DRAWING_BALL_NOW
		jmp __DRAW_START_X
		
		__DRAW_NEXT_2:
		; if not drawing the ball down, skip to a later DRAW_INDEX
		CJNE R0, #BALL_DOWN_START_INDEX, __DRAW_NEXT_3
		setb __IS_DRAWING_BALL_NOW
		JnB __IS_DRAWING_BALL_UP, __DRAW_NEXT_3
		clr __IS_DRAWING_BALL_NOW
		mov R0, #BALL_DOWN_END_INDEX	; skip drawing ball_down
		mov DRAW_INDEX, R0
		jmp __DRAW_START_X
		
		__DRAW_NEXT_3:
		; if got to BALL_DOWN_END_INDEX, set __IS_DRAWING_BALL_NOW to 0
		CJNE R0, #BALL_DOWN_END_INDEX, __DRAW_START_X
		clr __IS_DRAWING_BALL_NOW
		
		
		__DRAW_START_X:
		mov DPTR, #SegmentsX	; DPTR will point to the BoxXvalues table 
		mov A, R0
	
		; add extra values to R6 if needed
		call ADD_EXTRA_X
		
		MOVC A, @A+DPTR	; read X segmant value
		ADD A, R6	; add extra to A
		MOV R6, A
		
		
		
		
		mov DPTR, #SegmentsY	; DPTR will point to the SegmantY table 
		mov A, R0
	
		; add extra values to R7 if needed
		call ADD_EXTRA_Y
		
		MOVC A, @A+DPTR	; read X segmant value
		ADD A, R7	; add extra to A
		MOV R7, A
		
		



		; increment counters
		INC DRAW_INDEX
		mov A, #LOOPAROUND_DRAW_INDEX
		CJNE A, DRAW_INDEX, PUSH_TO_DACS
		; loop around DRAW_INDEX to 0
		call NEW_FRAME_INIT
		
		PUSH_TO_DACS:
		ANL DACCON, #11111011b	; clear sync bit
		MOV DAC0L, R6
		MOV DAC1L, R7
		ORL DACCON, #00000100b	; set sync bit
		

		pop ACC
		pop psw
		pop DPH
		pop DPL
	reti
;________________________________________________________
; lock new draw parameters in memory in order to draw a single frame

	NEW_FRAME_INIT:
		mov DRAW_INDEX, #0
		; lock draw parameters for the whole frame
		mov DRAW_PEDAL_LEFT_Y, PEDAL_LEFT_Y
		mov DRAW_PEDAL_RIGHT_Y, PEDAL_RIGHT_Y
		mov DRAW_BALL_X_POS, BALL_X_POS
		mov DRAW_BALL_Y_POS, BALL_Y_POS
		
		; check if the ball is in the upper part
		push ACC
		CLR __IS_DRAWING_BALL_UP
		mov A, BALL_Y_POS
		anl A, #80h
		jz $ + 2 + 2
		SETB __IS_DRAWING_BALL_UP
		pop ACC
	RET
	
	
	RESET_GAME:
		MOV GAME_STATE, #GAME_STATE_PLAYING
		
		MOV PEDAL_LEFT_Y, #128-H/2		; R2 - left padel Y position
		MOV PEDAL_RIGHT_Y, #128-H/2		; R3 - right padel Y position
		MOV BALL_X_POS, #128		; R4 - ball X position
		MOV BALL_Y_POS, #128		; R5 - ball Y position
		clr BALL_X_VEL_DIR
		clr BALL_Y_VEL_DIR
		
		mov BALL_X_VEL, #1; TODO change later
		mov BALL_Y_VEL, #1;
		
		call RESET_ROUND
		
	RET
	
	RESET_ROUND:
		push PSW
		mov BALL_X_POS, #128
		mov BALL_Y_POS, #128
		CPL BALL_X_VEL_DIR
		
		mov GAME_STATE, #GAME_STATE_PLAYING
		mov GAME_TICK_DIV, #GAME_TICK_DIV_BY
		pop PSW
	RET
;________________________________________________________
; gets ACC and compares it to the fix boundries. Fix R6/7 accordingly

	; this macro sets TARGET to SET_VALUE iff LOW_VALUE <= A < HIGH_VALUE
	COMPARE_ACC_EXTRA macro LOW_VALUE, HIGH_VALUE, TARGET, SET_VALUE, FINISH_L, NEXT_L
		CJNE A, #LOW_VALUE, $+3
		jc FINISH_L	; c=A<L
		CJNE A, #HIGH_VALUE, $+3	; so A>=L
		jnc NEXT_L		; c=A<H, so go to next AND if A>=H
		mov TARGET, SET_VALUE				; so A>=L and L<=A<H
	ENDm


	ADD_EXTRA_X:
		mov R6, #0
		
		_EX_AND1:
		COMPARE_ACC_EXTRA LI_BallX_1, HI_BallX_1, R6, DRAW_BALL_X_POS, _EX_FINISH, _EX_AND2
		
		_EX_AND2:
		COMPARE_ACC_EXTRA LI_BallX_2, HI_BallX_2, R6, DRAW_BALL_X_POS, _EX_FINISH, _EX_FINISH
		
		_EX_FINISH:
	RET
	
	
	ADD_EXTRA_Y:
		mov R7, #0
		
		_EY_AND1:
		COMPARE_ACC_EXTRA LI_LeftPedal_1, HI_LeftPedal_1, R7, DRAW_PEDAL_LEFT_Y, _EY_FINISH, _EY_AND2
		
		_EY_AND2:
		COMPARE_ACC_EXTRA LI_BallY_1, HI_BallY_1, R7, DRAW_BALL_Y_POS, _EY_FINISH, _EY_AND3
		
		_EY_AND3:
		COMPARE_ACC_EXTRA LI_RightPedal_1, HI_RightPedal_1, R7, DRAW_PEDAL_RIGHT_Y, _EY_FINISH, _EY_AND4
		
		_EY_AND4:
		COMPARE_ACC_EXTRA LI_BallY_2, HI_BallY_2, R7, DRAW_BALL_Y_POS, _EY_FINISH, _EY_FINISH
		
		_EY_FINISH:
	RET
;________________________________________________________
; calculates a game tick (move the ball and stuff)

	JUMP_TO_RET:
	RET

	CALC_GAME_TICK:
		; if game state is not playing, return (don't move ball)
		mov A, GAME_STATE
		CJNE A, #GAME_STATE_PLAYING, JUMP_TO_RET
		
	
		; MOVE THE BALL IN THE Y AXIS	
		mov A, BALL_Y_POS
		JB BALL_Y_VEL_DIR, _CALC_SUB_Y
		add A, BALL_Y_VEL
		jmp _CALC_Y_SKIP0
		_CALC_SUB_Y:
		subb A, BALL_Y_VEL
		
		_CALC_Y_SKIP0:
		jnc _CALC_EdgeY_SKIP0
		ANL A, #80h	; check if A>0 or A<0
		; if A<0, set A to 0. else to 255
		jz $ + 2 + 2
		mov A, #0FFh
		CPL A
		

		; check if A < BALL_H/2 or A > 255-BALL_H/2. if so, fix and flip Y vel
		_CALC_EdgeY_SKIP0:
		CJNE A, #BALL_H/2, $+3
		jnc _CALC_EdgeY_SKIP1 ; c = A<BALL_H/2
		; the ball is too low
		mov A, #BALL_H/2
		jmp _CALC_NEG_Y
		
		_CALC_EdgeY_SKIP1:
		CJNE A, #255-BALL_H/2, $+3
		jc _FINISH_MOVE_Y ; c = A<#255-BALL_H/2
		; the ball is too high
		mov A, #255-BALL_H/2
		; goes to _CALC_NEG_Y
		
		_CALC_NEG_Y:
		CPL BALL_Y_VEL_DIR
		

		_FINISH_MOVE_Y:
		mov R1, A
		mov BALL_Y_POS, A	; finish edge cases, save back BALL_X
		
		
		
		
		; MOVE THE BALL IN THE X AXIS	
		mov A, BALL_X_POS
		JB BALL_X_VEL_DIR, _CALC_SUB_X
		add A, BALL_X_VEL
		jmp _CALC_X_SKIP0
		_CALC_SUB_X:
		subb A, BALL_X_VEL
		
		_CALC_X_SKIP0:
		jnc _CALC_EdgeX_SKIP0
		ANL A, #80h	; check if A>0 or A<0
		; if A<0, set A to 0. else to 255
		jz $ + 2 + 2
		mov A, #0FFh
		CPL A
		
		
		; check if A < BALL_H/2 or A > 255-BALL_H/2. if so, finish the round
		_CALC_EdgeX_SKIP0:
		CJNE A, #BALL_H/2, $+3
		jnc _CALC_EdgeX_SKIP1 ; c = A<BALL_H/2
		; the ball is too left
		mov A, #BALL_H/2
		mov GAME_STATE, #GAME_STATE_P1_LOST
		jmp _FINISH_MOVE_X
		
		_CALC_EdgeX_SKIP1:
		CJNE A, #255-BALL_H/2, $+3
		jc _CALC_LeftPedalX_SKIP0 ; c = A<#255-BALL_H/2
		; the ball is too right
		mov A, #255-BALL_H/2
		mov GAME_STATE, #GAME_STATE_P2_LOST
		jmp _FINISH_MOVE_X
		
		
		; check if A < BALL_H/2 + W + PEDAL_X_OFFSET or A > 255 - BALL_H/2 - W - PEDAL_X_OFFSET. if so, check if the pedals hit
		_CALC_LeftPedalX_SKIP0:
		CJNE A, #BALL_H/2 + W + PEDAL_X_OFFSET, $+3
		jnc _CALC_RightPedalX_SKIP0 ; c = A<BALL_H/2 + W + PEDAL_X_OFFSET
		; the ball is in the left pedal line. check heights
		; check if 			PEDAL_LEFT_Y <= BALL_Y_POS <= PEDAL_LEFT_Y + H
		; meaning			0 <= BALL_Y_POS - PEDAL_LEFT_Y <= H
		push ACC
			; R1 = BALL_Y_POS
			mov A, PEDAL_LEFT_Y
			xch A, R1
			subb A, R1	; A = BALL_Y_POS - PEDAL_LEFT_Y
			; check if A <= H
			CJNE A, #H+1, $+3	; c = A < H+1 = A<=H
		pop ACC
		; heights do not match to _FINISH_MOVE_X
		jnc _FINISH_MOVE_X

		; left pedal hit!
		mov A, #BALL_H/2 + W + PEDAL_X_OFFSET
		jmp _CALC_NEG_X	; flip ball direction
		
		
		;-----------------------------------
		
		_CALC_RightPedalX_SKIP0:
		CJNE A, #255 - BALL_H/2 - W - PEDAL_X_OFFSET, $+3
		jc _FINISH_MOVE_X ; c = A<#255 - BALL_H/2 - W - PEDAL_X_OFFSET
		; the ball is in the right pedal line. check heights
		; check if 			PEDAL_RIGHT_Y <= BALL_Y_POS <= PEDAL_RIGHT_Y + H
		; meaning			0 <= BALL_Y_POS - PEDAL_RIGHT_Y <= H
		push ACC
			; R1 = BALL_Y_POS
			mov A, PEDAL_RIGHT_Y
			xch A, R1
			subb A, R1	; A = BALL_Y_POS - PEDAL_RIGHT_Y
			; check if A <= H
			CJNE A, #H+1, $+3	; c = A < H+1 = A<=H
		pop ACC
		; heights do not match to _FINISH_MOVE_X
		jnc _FINISH_MOVE_X
		
		; right pedal hit!
		mov A, #255 - BALL_H/2 - W - PEDAL_X_OFFSET
		jmp _CALC_NEG_X	; flip ball direction

		
		_CALC_NEG_X:
		CPL BALL_X_VEL_DIR
		

		_FINISH_MOVE_X:
		mov BALL_X_POS, A	; finish edge cases, save back BALL_X
	RET
;________________________________________________________
; start sampling a new random value from ADC
	
	SAMPLE_NEW_RANDOM:
		setb IS_RANDOM_BUSY
		setb SCONV ; initiate a new ADC measurement
	RET
	
	ADC_isr:
		mov RANDOM_VALUE, ADCDATAL
		clr IS_RANDOM_BUSY
	RETI
	
;________________________________________________________
; handle game state, send things to UART if needed
	
	HANDLE_GAME_STATE:
		push ACC
			mov A, GAME_STATE
			
			_HGS_SKIP0:
			CJNE A, #GAME_STATE_PLAYING, _HGS_SKIP1
			jmp _HGS_SKIP_END
			
			_HGS_SKIP1:
			CJNE A, #GAME_STATE_P1_LOST, _HGS_SKIP2
			mov SBUF, #PR_P2scoreInc
			mov GAME_STATE, #GAME_STATE_IDLE
			
			_HGS_SKIP2:
			CJNE A, #GAME_STATE_P2_LOST, _HGS_SKIP3
			mov SBUF, #PR_P1scoreInc
			mov GAME_STATE, #GAME_STATE_IDLE
			
			_HGS_SKIP3:
			CJNE A, #GAME_STATE_IDLE, _HGS_SKIP_END
			; jmp _HGS_SKIP_END
			
			_HGS_SKIP_END:
		pop ACC
	RET
	
; revive game after lost
	REVIVE_GAME:
		push ACC
		mov A, GAME_STATE
		CJNE A, #GAME_STATE_IDLE, _END_REVIVE_GAME
		mov GAME_STATE, #GAME_STATE_PLAYING
		call RESET_ROUND
		
		_END_REVIVE_GAME:
		pop ACC
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
		jnb RI, UART_SENT
		UART_RECEIVED:
			CLR RI
			push ACC
				mov A, SBUF
				
				_UART_NEXT0:
				CJNE A, #PR_RightPedalUp, _UART_NEXT1	; UP key of right pedal  00000001b
				call MOVE_RIGHT_PEDAL_UP
				
				_UART_NEXT1:
				CJNE A, #PR_RightPedalDown, _UART_NEXT2	; DOWN key of right pedal 	00000011b
				call MOVE_RIGHT_PEDAL_DOWN
				
				_UART_NEXT2:
				CJNE A, #PR_LeftPedalUp, _UART_NEXT3	; UP key of left pedal  00000001b		(DEBUG ONLY)
				call MOVE_LEFT_PEDAL_UP
				
				_UART_NEXT3:
				CJNE A, #PR_LeftPedalDown, _UART_NEXT4	; DOWN key of left pedal 	00000011b	(DEBUG ONLY)
				call MOVE_LEFT_PEDAL_DOWN
				
				_UART_NEXT4:
				CJNE A, #PR_ResetDEBUG, _UART_NEXT_FINISH	; reset game debug req 	00000011b	(DEBUG ONLY)
				call RESET_REQUEST
				
				_UART_NEXT_FINISH:
			pop ACC
			
			jmp UART_END_ISR
		UART_SENT:
		
		UART_END_ISR:
		CLR TI	; cleared manualy
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
		; timer 2 autoreloads from RCAP2L, RCAP2H
		
		; row1 [1][2][3]
		MOV P2, #11111110b ; OUT0:2.0 OUT1(read INPUT): 2.4, 2.5, 2.6
		JNB P2.4, KEYPAD_1
		JNB P2.5, KEYPAD_2
		JNB P2.6, KEYPAD_3
		
		; row2 [4][5][6]
		MOV P2, #11111101b ; OUT0:2.1 OUT1(read INPUT): 2.4, 2.5, 2.6
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
		RETI
		
		KEYPAD_1:
			RETI
		KEYPAD_2:
			call MOVE_LEFT_PEDAL_UP
			RETI
		KEYPAD_3:
			;call MOVE_RIGHT_PEDAL_UP
			RETI
		KEYPAD_4:
			RETI
		KEYPAD_5:
			RETI
		KEYPAD_6:
			RETI
		KEYPAD_7:
			RETI
		KEYPAD_8:
			call MOVE_LEFT_PEDAL_DOWN
			RETI
		KEYPAD_9:
			;call MOVE_RIGHT_PEDAL_DOWN
			RETI
		KEYPAD_0:
			RETI
		KEYPAD_star:
			RETI
		KEYPAD_hashtag:
			RETI
	reti
;________________________________________________________

	MOVE_LEFT_PEDAL_DOWN:
		push ACC
		
		call REVIVE_GAME
		
		mov A, PEDAL_LEFT_Y
		; if A-STEP < 0 set A to 0  <=>  A<STEP
		CJNE A, #PEDAL_STEP, $+3
		jnc _LPD_NO_A_CLR	; c = A < STEP
		clr A
		jmp LPD_SKIP_1
		
		_LPD_NO_A_CLR:
		SUBB A, #PEDAL_STEP
		
		LPD_SKIP_1:
		MOV PEDAL_LEFT_Y, A
		pop ACC
	RET
	
	
	MOVE_LEFT_PEDAL_UP:
		push ACC
		
		call REVIVE_GAME
		
		mov A, PEDAL_LEFT_Y
		; if A+STEP > 255-H: set A to 255-H
		CJNE A, #255-H-PEDAL_STEP, $+3
		jc _LPU_NO_A_CLR; c = A<255-H-STEP
		mov A, #255 - H ; set R2 to the upper limit: #255-H
		jmp LPU_SKIP_1
		
		_LPU_NO_A_CLR:
		ADD A, #PEDAL_STEP
		
		LPU_SKIP_1:
		mov PEDAL_LEFT_Y, A
		pop ACC
	RET
	
	
	MOVE_RIGHT_PEDAL_DOWN:
		push ACC
		
		call REVIVE_GAME
		
		mov A, PEDAL_RIGHT_Y
		; if A-STEP < 0 set A to 0  <=>  A<STEP
		CJNE A, #PEDAL_STEP, $+3
		jnc _RPD_NO_A_CLR	; c = A < STEP
		clr A
		jmp RPD_SKIP_1
		
		_RPD_NO_A_CLR:
		SUBB A, #PEDAL_STEP
		
		RPD_SKIP_1:
		MOV PEDAL_RIGHT_Y, A
		pop ACC
	RET
	
	
	MOVE_RIGHT_PEDAL_UP:
		push ACC
		
		call REVIVE_GAME
		
		mov A, PEDAL_RIGHT_Y
		; if A+STEP > 255-H: set A to 255-H
		CJNE A, #255-H-PEDAL_STEP, $+3
		jc _RPU_NO_A_CLR; c = A<255-H-STEP
		mov A, #255 - H ; set R2 to the upper limit: #255-H
		jmp RPU_SKIP_1
		
		_RPU_NO_A_CLR:
		ADD A, #PEDAL_STEP
		
		RPU_SKIP_1:
		mov PEDAL_RIGHT_Y, A
		pop ACC
	RET
	
	
	RESET_REQUEST:
		call RESET_ROUND
	RET
;________________________________________________________
#include <draw.asm>
END