;********************************************************
; Author :	Gilad Savoray
; Date :	4 Dec 2022
; File :	draw2.asm
;
; Hardware : Any 8052 based MicroConverter (ADuC8xx)
; Description: Look-up-table values for drawing the score screen.
;********************************************************
H EQU 20				; height of square segment
W EQU 20				; width of square segment
T EQU 20				; a floating offset from the buttom of the screen

OFFSET_X_JUMP EQU -40	; X position difference of digits
START_X_POS EQU 255-10	; start X position for the first digit
START_Y_POS EQU 40		; start Y position for all digits

;********************************************************
LENGTHS:
	DB NUMBER0_Y-NUMBER0_X	; ZERO
	DB NUMBER1_Y-NUMBER1_X	; ONE
	DB NUMBER2_Y-NUMBER2_X	; TWO
	DB NUMBER3_Y-NUMBER3_X	; THREE
	DB NUMBER4_Y-NUMBER4_X	; FOUR
	DB NUMBER5_Y-NUMBER5_X	; FIVE
	DB NUMBER6_Y-NUMBER6_X	; SIX
	DB NUMBER7_Y-NUMBER7_X	; SEVEN
	DB NUMBER8_Y-NUMBER8_X	; EIGHT
	DB NUMBER9_Y-NUMBER9_X	; NINE
	
SegmentsX:
	DB NUMBER0_X-START_SEGMENTS
	DB NUMBER1_X-START_SEGMENTS
	DB NUMBER2_X-START_SEGMENTS
	DB NUMBER3_X-START_SEGMENTS
	DB NUMBER4_X-START_SEGMENTS
	DB NUMBER5_X-START_SEGMENTS
	DB NUMBER6_X-START_SEGMENTS
	DB NUMBER7_X-START_SEGMENTS
	DB NUMBER8_X-START_SEGMENTS
	DB NUMBER9_X-START_SEGMENTS
	
SegmentsY:
	DB NUMBER0_Y-START_SEGMENTS
	DB NUMBER1_Y-START_SEGMENTS
	DB NUMBER2_Y-START_SEGMENTS
	DB NUMBER3_Y-START_SEGMENTS
	DB NUMBER4_Y-START_SEGMENTS
	DB NUMBER5_Y-START_SEGMENTS
	DB NUMBER6_Y-START_SEGMENTS
	DB NUMBER7_Y-START_SEGMENTS
	DB NUMBER8_Y-START_SEGMENTS
	DB NUMBER9_Y-START_SEGMENTS
	
START_SEGMENTS:
	NUMBER0_X:
		DB 0
		
		DB 0
		DB 0
		DB -W
		DB -W
		DB 0
		
		DB 0
		
	NUMBER0_Y:
		DB -T
		
		DB 0
		DB 2*H
		DB 2*H
		DB 0
		DB 0
		
		DB -T
		
	NUMBER1_X:
		DB 0
		
		DB 0
		DB 0
		DB 0
		
		DB 0
		
	NUMBER1_Y:
		DB -T
		
		DB 0
		DB 2*H
		DB 0
		
		DB -T
	
	NUMBER2_X:
		DB 0
		
		DB 0
		DB -W
		DB -W
		DB 0
		DB 0
		DB -W
		
		DB 0
		DB 0
		DB -W
		DB -W
		DB 0
		
		DB 0
		
	NUMBER2_Y:
		DB -T
	
		DB 0
		DB 0
		DB H
		DB H
		DB 2*H
		DB 2*H
		
		DB 2*H
		DB H
		DB H
		DB 0
		DB 0
		
		DB -T
		
	NUMBER3_X:
		DB 0
		
		DB 0
		DB -W
		DB 0
		DB 0
		DB -W
		DB 0
		DB 0
		DB -W
		
		DB 0
		DB 0
		
		DB 0
		
	NUMBER3_Y:
		DB -T
		
		DB 0
		DB 0
		DB 0
		DB H
		DB H
		DB H
		DB 2*H
		DB 2*H
		
		DB 2*H
		DB 0
		
		DB -T
		
	NUMBER4_X:
		DB 0
		
		DB 0
		DB 0
		DB 0
		DB -W
		DB -W
		
		DB -W
		DB 0
		DB 0
		
		DB 0
		
	NUMBER4_Y:
		DB -T
		
		DB 0
		DB 2*H
		DB H
		DB H
		DB 2*H
		
		DB H
		DB H
		DB 0
		
		DB -T
		
	NUMBER5_X:
		DB 0
		
		DB 0
		DB -W
		DB 0
		DB 0
		DB -W
		DB -W
		DB 0
		
		DB -W
		DB -W
		DB 0
		DB 0
		
		DB 0
		
	NUMBER5_Y:
		DB -T
		
		DB 0
		DB 0
		DB 0
		DB H
		DB H
		DB 2*H
		DB 2*H
		
		DB 2*H
		DB H
		DB H
		DB 0
		
		DB -T
		
	NUMBER6_X:
		DB 0
		
		DB 0
		DB -W
		DB -W
		DB 0
		
		DB -W
		DB -W
		DB 0
		DB 0
		
		DB 0
		
	NUMBER6_Y:
		DB -T
		
		DB 0
		DB 0
		DB 2*H
		DB 2*H
		
		DB 2*H
		DB H
		DB H
		DB 0
		
		DB -T
	
	NUMBER7_X:
		DB 0
		
		DB 0
		DB 0
		DB -W
		
		DB 0
		DB 0
		
		DB 0
		
	NUMBER7_Y:
		DB -T
		
		DB 0
		DB 2*H
		DB 2*H
		
		DB 2*H
		DB 0
		
		DB -T
	
	NUMBER8_X:
		DB 0
		
		DB 0
		DB -W
		DB -W
		DB 0
		DB 0
		DB -W
		DB 0
		DB 0
		
		DB 0
		
	NUMBER8_Y:
		DB -T
		
		DB 0
		DB 0
		DB 2*H
		DB 2*H
		DB H
		DB H
		DB H
		DB 0
		
		DB -T
		
	NUMBER9_X:
		DB 0
		
		DB 0
		DB -W
		DB 0
		DB 0
		DB -W
		DB -W
		DB 0
		DB 0
		
		DB 0
	
	NUMBER9_Y:
		DB -T
		
		DB 0
		DB 0
		DB 0
		DB 2*H
		DB 2*H
		DB H
		DB H
		DB 0
		
		DB -T
