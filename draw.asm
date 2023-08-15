;********************************************************
; Author :	Gilad Savoray
; Date :	22 Nov 2022
; File :	draw.asm
;
; Hardware : Any 8052 based MicroConverter (ADuC8xx)
; Description: Look-up-table values for drawing the main screen.
;********************************************************
H EQU 40				; height of pedal
W EQU 15				; width of pedal
BALL_H EQU 20			; height of ball
PEDAL_X_OFFSET EQU 4	; offset of pedals from the left/right screen edges

;********************************************************
; Fixes boundries for adding Reg values
;	e.g _FPR1E = _FixPedalRight1End

; calculate boundries in terms of INDEXes
LI_BallX_1 EQU _FBX1S - SegmentsX
HI_BallX_1 EQU _FBX1E - SegmentsX
LI_BallX_2 EQU _FBX2S - SegmentsX
HI_BallX_2 EQU _FBX2E - SegmentsX

LI_LeftPedal_1 EQU _FPL1S - SegmentsY
HI_LeftPedal_1 EQU _FPL1E - SegmentsY
LI_BallY_1 EQU _FBY1S - SegmentsY
HI_BallY_1 EQU _FBY1E - SegmentsY
LI_RightPedal_1 EQU _FPR1S - SegmentsY
HI_RightPedal_1 EQU _FPR1E - SegmentsY
LI_BallY_2 EQU _FBY2S - SegmentsY
HI_BallY_2 EQU _FBY2E - SegmentsY


; index of looparound and other branch control logic
LOOPAROUND_DRAW_INDEX EQU __LOOPAROUND - SegmentsX
BALL_UP_START_INDEX EQU __BALL_UP_BRANCH_START - SegmentsX
BALL_UP_END_INDEX EQU __BALL_UP_BRANCH_END - SegmentsX
BALL_DOWN_START_INDEX EQU __BALL_DOWN_BRANCH_START - SegmentsX
BALL_DOWN_END_INDEX EQU __BALL_DOWN_BRANCH_END - SegmentsX
;********************************************************

	
SegmentsX:
	; Bottom Left wall
	SEGMENT1_X:
		DB 0
		DB 0
		DB PEDAL_X_OFFSET
		
	; Left padal
	SEGMENT2_X:
		DB PEDAL_X_OFFSET
		DB PEDAL_X_OFFSET
		DB PEDAL_X_OFFSET + W
		DB PEDAL_X_OFFSET + W
		DB PEDAL_X_OFFSET
		DB PEDAL_X_OFFSET
		
	; Top Left wall
	SEGMENT3_X:
		DB PEDAL_X_OFFSET
		DB 0
		DB 0
__BALL_UP_BRANCH_START:
_FBX1S:	DB 0	; Ball X pos
		DB 0	; Ball X pos

	SEGMENT4_X:	;	BALL_DOWN_X
		DB 0
		DB 0
		DB -1
		DB -1
		DB -2
		DB -3
		DB -3
		DB -4
		DB -4
		DB -5
		DB -5
		DB -6
		DB -6
		DB -7
		DB -7
		DB -8
		DB -8
		DB -8
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -10
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -8
		DB -8
		DB -8
		DB -7
		DB -7
		DB -6
		DB -6
		DB -5
		DB -5
		DB -4
		DB -4
		DB -3
		DB -3
		DB -2
		DB -1
		DB -1
		DB 0
		DB 0
		DB 0
		DB 1
		DB 1
		DB 2
		DB 3
		DB 3
		DB 4
		DB 4
		DB 5
		DB 5
		DB 6
		DB 6
		DB 7
		DB 7
		DB 8
		DB 8
		DB 8
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 10
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 8
		DB 8
		DB 8
		DB 7
		DB 7
		DB 6
		DB 6
		DB 5
		DB 5
		DB 4
		DB 4
		DB 3
		DB 3
		DB 2
		DB 1
		DB 1
		DB 0

	; Top Right wall
	SEGMENT5_X:
		DB 0	; Ball X pos
		DB 0	; Ball X pos
__BALL_UP_BRANCH_END:
_FBX1E:	DB 255
		DB 255
		DB 255 - PEDAL_X_OFFSET
		
	; Right pedal
	SEGMENT6_X:
		DB 255 - PEDAL_X_OFFSET
		DB 255 - PEDAL_X_OFFSET
		DB 255 - PEDAL_X_OFFSET - W
		DB 255 - PEDAL_X_OFFSET - W
		DB 255 - PEDAL_X_OFFSET
		DB 255 - PEDAL_X_OFFSET
	
	; Bottom Left wall
	SEGMENT7_X:
		DB 255 - PEDAL_X_OFFSET
		DB 255
		DB 255
__BALL_DOWN_BRANCH_START:
_FBX2S:	DB 0	; Ball X Pos
		DB 0	; Ball X Pos

	SEGMENT8_X:	;	BALL_DOWN_X
		DB 0
		DB 0
		DB 1
		DB 1
		DB 2
		DB 3
		DB 3
		DB 4
		DB 4
		DB 5
		DB 5
		DB 6
		DB 6
		DB 7
		DB 7
		DB 8
		DB 8
		DB 8
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 10
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 8
		DB 8
		DB 8
		DB 7
		DB 7
		DB 6
		DB 6
		DB 5
		DB 5
		DB 4
		DB 4
		DB 3
		DB 3
		DB 2
		DB 1
		DB 1
		DB 0
		DB 0
		DB 0
		DB -1
		DB -1
		DB -2
		DB -3
		DB -3
		DB -4
		DB -4
		DB -5
		DB -5
		DB -6
		DB -6
		DB -7
		DB -7
		DB -8
		DB -8
		DB -8
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -10
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -8
		DB -8
		DB -8
		DB -7
		DB -7
		DB -6
		DB -6
		DB -5
		DB -5
		DB -4
		DB -4
		DB -3
		DB -3
		DB -2
		DB -1
		DB -1
		DB 0
		
	; Bottom Right wall
	SEGMENT9_X:
		DB 0	; Ball X Pos
		DB 0	; Ball X Pos
__BALL_DOWN_BRANCH_END:
_FBX2E:	DB 0
__LOOPAROUND:




SegmentsY:
	; Bottom Left wall
	SEGMENT1_Y:
		DB 0
_FPL1S:	DB H/2	; R2 + H/2
		DB H/2	; R2 + H/2

	; Left padal
	SEGMENT2_Y:
		DB H/2	; R2 + H/2
		DB 0	; R2
		DB 0	; R2
		DB H	; R2 + H
		DB H	; R2 + H
		DB H/2	; R2 + H/2

	; Top Left wall
	SEGMENT3_Y:
		DB H/2	; R2 + H/2
		DB H/2	; R2 + H/2
_FPL1E:	DB 255
		DB 255
_FBY1S:	DB BALL_H/2	; Ball Y pos + BALL_H/2

	SEGMENT4_Y: ;	BALL_UP_Y:
		DB 10
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 8
		DB 8
		DB 8
		DB 7
		DB 7
		DB 6
		DB 6
		DB 5
		DB 5
		DB 4
		DB 4
		DB 3
		DB 3
		DB 2
		DB 1
		DB 1
		DB 0
		DB 0
		DB 0
		DB -1
		DB -1
		DB -2
		DB -3
		DB -3
		DB -4
		DB -4
		DB -5
		DB -5
		DB -6
		DB -6
		DB -7
		DB -7
		DB -8
		DB -8
		DB -8
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -10
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -8
		DB -8
		DB -8
		DB -7
		DB -7
		DB -6
		DB -6
		DB -5
		DB -5
		DB -4
		DB -4
		DB -3
		DB -3
		DB -2
		DB -1
		DB -1
		DB 0
		DB 0
		DB 0
		DB 1
		DB 1
		DB 2
		DB 3
		DB 3
		DB 4
		DB 4
		DB 5
		DB 5
		DB 6
		DB 6
		DB 7
		DB 7
		DB 8
		DB 8
		DB 8
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9

	; Top Right wall
	SEGMENT5_Y:
		DB BALL_H/2	; Ball Y pos + BALL_H/2
_FBY1E:	DB 255
		DB 255
_FPR1S:	DB H/2	; R3 + H/2
		DB H/2	; R3 + H/2

	; Right pedal
	SEGMENT6_Y:
		DB H/2	; R3 + H/2
		DB H	; R3 + H
		DB H	; R3 + H
		DB 0	; R3
		DB 0	; R3
		DB H/2	; R3 + H/2
		
	; Bottom Left wall
	SEGMENT7_Y:
		DB H/2	; R3 + H/2
		DB H/2	; R3 + H/2
_FPR1E:	DB 0
		DB 0
_FBY2S:	DB -BALL_H/2	; Ball Y Pos - BALL_H/2

	SEGMENT8_Y: ;	BALL_DOWN_Y:
		DB -10
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -8
		DB -8
		DB -8
		DB -7
		DB -7
		DB -6
		DB -6
		DB -5
		DB -5
		DB -4
		DB -4
		DB -3
		DB -3
		DB -2
		DB -1
		DB -1
		DB 0
		DB 0
		DB 0
		DB 1
		DB 1
		DB 2
		DB 3
		DB 3
		DB 4
		DB 4
		DB 5
		DB 5
		DB 6
		DB 6
		DB 7
		DB 7
		DB 8
		DB 8
		DB 8
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 10
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 9
		DB 8
		DB 8
		DB 8
		DB 7
		DB 7
		DB 6
		DB 6
		DB 5
		DB 5
		DB 4
		DB 4
		DB 3
		DB 3
		DB 2
		DB 1
		DB 1
		DB 0
		DB 0
		DB 0
		DB -1
		DB -1
		DB -2
		DB -3
		DB -3
		DB -4
		DB -4
		DB -5
		DB -5
		DB -6
		DB -6
		DB -7
		DB -7
		DB -8
		DB -8
		DB -8
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		DB -9
		
	; Bottom Right wall
	SEGMENT9_Y:
		DB -BALL_H/2	; Ball Y Pos - BALL_H/2
_FBY2E:	DB 0
		DB 0
		

