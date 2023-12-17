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

PLAYERW EQU 5
PLAYERH EQU 5

MIDZONEX EQU 133
MIDZONEY EQU 89
MIDZONEW EQU 56
MIDZONEH EQU 56

EXZONEX EQU 83
EXZONEY EQU 40
EXZONEW EQU 156
EXZONEH EQU 156

CODESEG


MACRO ShowMouse
	push eax
	mov  ax, 0001h  ; show mouse
	int  33h
	pop eax
ENDM ShowMouse

PROC playerInput
	ARG 	@@PtrPlayer:dword
	USES 	ebx, ecx, edx, esi, edi	
	mov edi, [@@PtrPlayer]

	mov ah, 01h 		; function 01h (check if key is pressed)
	int 16h 			; call keyboard BIOS
	jz SHORT noGoodKeyPress	; if key not pressed than there is a 0 flag
	
	mov ah, 00h 		;get key from buffer (ascii code in al)
	int 16h
	
	cmp	al, 001Bh	; ='esc' checks to see if we ditch program
	jne  noEXIT
	call terminateProcess
	noEXIT:
	
	cmp al, 'z'
	jne notUP
	mov eax, [edi + PLAYER.Y]
	dec eax ; moves position
	mov [edi + PLAYER.Y], eax
	
	mov eax, 1
	jmp notRIGHT
	
	notUP:
	
	cmp al, 's'
	jne notDOWN
	
	mov eax, [edi + PLAYER.Y]
	inc eax ; moves position
	mov [edi + PLAYER.Y], eax
	
	mov eax, 1
	jmp notRIGHT
	
	notDOWN:
	
	cmp al, 'q'
	jne notLEFT
	
	mov eax, [edi + PLAYER.X]
	dec eax ; moves position
	mov [edi + PLAYER.X], eax
	
	mov eax, 1
	jmp notRIGHT
	
	notLEFT:
	
	cmp al, 'd'
	jne noGoodKeyPress
	
	mov eax, [edi + PLAYER.X]
	inc eax ; moves position
	mov [edi + PLAYER.X], eax
	mov eax, 1
	jmp notRIGHT
	
	noGoodKeyPress:
	xor eax, eax
	
	notRIGHT:

	ret
ENDP playerInput

PROC drawTronEntities
	ARG 	@@PtrPlayer:dword
	USES eax, esi, ecx, edx, ebx, edi
	
	mov esi, [@@PtrPlayer]
	call DrawIMG, offset playerIMG, [esi + PLAYER.X], [esi + PLAYER.Y], 5, 5
	ret
ENDP drawTronEntities

PROC drawBackground
	call DrawBG, offset backgroundIMG, SCRWIDTH*SCRHEIGHT
	
	ret
ENDP drawBackground


PROC setuptron
	ARG 	@@PtrPlayer:dword
	USES eax, ebx, edx,ecx
	
	call setVideoMode,13h
	; insert the call readfile here for the background
	
	mov esi, [@@PtrPlayer]
	mov [esi + PLAYER.X], 159
	mov [esi + PLAYER.Y], 115
	
	call drawBackground
	
	ShowMouse
	
	ret
ENDP setuptron

PROC selectGame
	ARG 	@@x:dword, @@y:dword, @@w:dword, @@h:dword
	USES 	ebx, ecx, edx, edi, esi
	
	mov ecx, [@@x]
	mov edx, [@@y]
	mov edi, [@@w]
	mov esi, [@@h]
	
	;call drawRectangle, MIDZONEX, MIDZONEY, MIDZONEW, MIDZONEH, 3
	
	call collision, MIDZONEX, MIDZONEY, MIDZONEW, MIDZONEH, ecx, edx, edi, esi, 0
	
	
	mov ebx, eax
	
	call collision, EXZONEX, EXZONEY, EXZONEW, EXZONEH, ecx, edx, edi, esi, 0
	
	xor eax, 0Fh ; invert the return
	
	or eax, ebx
	
	cmp eax, 0
	jne NoGameSelected
	; background: game selection is divided into four triangles
	; we just have to determine in wich triangle the player is positioned
	
	; use equation of two lines to divide the screen into four parts
	
	mov eax, ecx
	add eax, edx
	
	mov ebx, ecx
	sub ebx, edx
	
	cmp eax, 274	; x + y = 159 + 115 = 274
	jg TowerOrBiker
		cmp ebx, 44		; x - y = 159 - 115 = 44
		jg Tower
		;spider
		
		;call SpiderSetup
		
		jmp endOfSelctor
		
		Tower:
						; tower
		;call TowerSetup
		jmp endOfSelctor
		
	TowerOrBiker:
		cmp ebx, 44		; x - y = 159 - 115 = 44
		jg	Biker
		; tank
		
		;call tankGame
		
		jmp endOfSelctor
		
		Biker:
		; biker
		
		; call bikerGame
		
		jmp endOfSelctor
	
	
	mov eax, 1		; reset everyting
	
	jmp endOfSelctor
	NoGameSelected:
	
	xor eax, eax	; no need to reset everyting
	
	endOfSelctor:
	ret
ENDP selectGame

start:
     sti            ; set The Interrupt Flag => enable interrupts
     cld            ; clear The Direction Flag

	push ds
	pop es
	
	NoMouse:
	mov  ax, 0000h  ; reset mouse
	int  33h        ; -> AX BX
	cmp  ax, 0FFFFh
	jne  NoMouse
	
	mov esi, offset player
	
	call ReadFile, offset player_file, offset playerIMG, PLAYERIMGSIZE 
	call ReadFile, offset backgroundIMG_file, offset backgroundIMG, SCRWIDTH*SCRHEIGHT 
	
	; ReSetupTron:
	call setuptron, esi
	mov ecx, 1
	
	mainLoopTRON:
	
	
	
	call playerInput, esi
	
	cmp eax, 1
	jne DontRedrawBackgrnd
		call drawBackground
		ShowMouse
	DontRedrawBackgrnd:
	
	call drawTronEntities, esi
	
	call selectGame, [esi + PLAYER.X], [esi + PLAYER.Y], 5, 5
	
	
	push ecx
	push ebx
	push edx
	mov  ax, 0003h  ; get mouse position and buttonstatus
	int  33h        ; -> BX CX DX
	
	test ebx, 1      ; check left mouse click
	jz SHORT NoMouseClick		; zero if no click
	shr ecx, 1
	
	call selectGame, ecx, edx, 1, 1
	
	NoMouseClick:
	pop edx
	pop ebx
	pop ecx
	
	call wait_VBLANK, 1
	
	inc ecx	;infinite loop
	loop mainLoopTRON
	;; groote project: herschrijf alles om zoveel van de TANKS file opnieuw te gebruiken, zou doenbaar moeten zijn denk ik dan 	
	
	call terminateProcess

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------

; if add spider as struct: only need 2 pieces of info on spider, namely position, in x and y, and if alive doesnt matter=> insta respawn at start position spider

STRUC PLAYER
	X dd 159
	Y dd 115
ENDS PLAYER


DATASEG

	msg	db "Hello User! Welcome to the TRON game, use ZQSD to move your player around and left mouse to shoot, press any button to continue.", 13, 10, '$'
	
	player		PLAYER		1		dup(<,>)

	victory db "you won!", 13, 10, '$'
	
	lossmessage db "you lost!", 13, 10, '$'
	
	player_file db "player.bin", 0
	backgroundIMG_file db "backgrnd.bin", 0
	
	
UDATASEG
	playerIMG db PLAYERIMGSIZE dup (?)
	
	backgroundIMG db SCRWIDTH*SCRHEIGHT dup (?)
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END start

; 12 is colorcode for red
; 10 voor groen