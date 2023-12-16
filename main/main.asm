; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	Thijs Verschuuren
; date:		28/11/2023
; program:	SPIDER
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "generic.inc"

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height
PLAYERIMGSIZE EQU 5*5

PLAYERW EQU 3

CODESEG


PROC playerInput
	ARG 	@@PtrPlayer:dword
	USES 	eax, ebx, esi, edi	
	mov esi, [@@PtrPlayer]

	mov ah, 01h 		; function 01h (check if key is pressed)
	int 16h 			; call keyboard BIOS
	jz SHORT notRIGHT	; if key not pressed than there is a 0 flag
	
	mov ah, 00h 		;get key from buffer (ascii code in al)
	int 16h
	
	cmp	al, 001Bh	; ='esc' checks to see if we ditch program
	je  noEXIT
	call terminateProcess
	noEXIT:
	
	cmp al, 'z'
	jne notUP
	mov eax, [esi + PLAYER.Y]
	dec eax ; moves position
	mov [esi + PLAYER.Y], eax
	jmp notRIGHT
	
	notUP:
	
	cmp al, 's'
	jne notDOWN
	
	mov eax, [esi + PLAYER.Y]
	inc eax ; moves position
	mov [esi + PLAYER.Y], eax
	jmp notRIGHT
	
	notDOWN:
	
	cmp al, 'q'
	jne notLEFT
	
	mov eax, [esi + PLAYER.X]
	dec eax ; moves position
	mov [esi + PLAYER.X], eax
	jmp notRIGHT
	
	notLEFT:
	
	cmp al, 'd'
	jne notRIGHT
	
	mov eax, [esi + PLAYER.X]
	inc eax ; moves position
	mov [esi + PLAYER.X], eax

	notRIGHT:

	ret
ENDP playerInput

PROC drawTronEntities
	ARG 	@@PtrPlayer:dword
	USES eax, esi, ecx, edx, ebx, edi
	mov esi, [@@PtrPlayer]
	mov edx, [esi + PLAYER.X]
	
	call DrawIMG, offset playerIMG, edi, ebx, 5, 5
	ret
ENDP drawTronEntities


PROC tronTerrain
	; inset code here to draw terrain, will be with 
	ret
ENDP tronTerrain

PROC setuptron
	ARG 	@@PtrPlayer:dword
	USES eax, ebx, edx,ecx
	
	call setVideoMode,13h
	; insert the call readfile here for the background
	call ReadFile, offset player_file, offset playerIMG, PLAYERIMGSIZE 
	call tronTerrain
	
	mov esi, [@@PtrPlayer]
	mov [esi + PLAYER.X], 158
	mov [esi + PLAYER.Y], 98
	
	ret
ENDP setuptron

start:
     sti            ; set The Interrupt Flag => enable interrupts
     cld            ; clear The Direction Flag

	push ds
	pop es
	
	mov ah, 09h
	mov edx, offset msg
	
	int 21h
	
	mov ah,00h
	int 16h
	
	call setuptron
	
	call playerInput
	
	call drawTronEntities
	
	;; groote project: herschrijf alles om zoveel van de TANKS file opnieuw te gebruiken, zou doenbaar moeten zijn denk ik dan 	
	mov ah,00h
	int 16h
	

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------

; if add spider as struct: only need 2 pieces of info on spider, namely position, in x and y, and if alive doesnt matter=> insta respawn at start position spider

STRUC PLAYER
	X dd 158
	Y dd 98
ENDS PLAYER


DATASEG

	msg	db "Hello User! Welcome to the TRON game, use ZQSD to move your player around and left mouse to shoot, press any button to continue.", 13, 10, '$'
	
	player		PLAYER		1		dup(<,>)

	victory db "you won!", 13, 10, '$'
	
	lossmessage db "you lost!", 13, 10, '$'
	
	player_file db "player.bin", 0
	openErrorMsg db "could not open file", 13, 10, '$'
	readErrorMsg db "could not read data", 13, 10, '$'
	closeErrorMsg db "error during file closing", 13, 10, '$'
	; change shit here for the bin of the background
	
UDATASEG
	playerIMG db PLAYERIMGSIZE dup (?)
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END start

; 12 is colorcode for red
; 10 voor groen