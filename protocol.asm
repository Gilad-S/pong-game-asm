;********************************************************
; Author :	Gilad Savoray
; Date :	3 Dec 2022
; File :	protocol.asm
;
; Hardware : Any 8052 based MicroConverter (ADuC8xx)
; Description: Byte values for the UART game protocol
;********************************************************


; SENT FROM ONE TO TWO
PR_P1scoreInc EQU 37h	; not sent yet
PR_P2scoreInc EQU 38h	; not sent yet
PR_ResetScores EQU 39h	; not sent yet


; SENT FROM TWO TO ONE
PR_RightPedalUp EQU 32h
PR_RightPedalDown EQU 31h


; DEBUGGING
PR_LeftPedalUp EQU 35h
PR_LeftPedalDown EQU 34h
PR_ResetDEBUG EQU 30h
