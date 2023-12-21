; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; authors:	Thijs Verschuuren, Ethan Fack
; group: 	G20
; date:		28/11/2023
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "generic.inc"

INCLUDE "spider.inc"
INCLUDE "biker.inc"
INCLUDE "tower.inc"
INCLUDE "tank.inc"

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

MACRO HideMouse
	push eax
	mov  ax, 0002h  ; show mouse
	int  33h
	pop eax
ENDM HideMouse

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
	mov eax, [edi + SELECTOR.Y]
	dec eax ; moves position
	mov [edi + SELECTOR.Y], eax
	
	mov eax, 1
	jmp notRIGHT
	
	notUP:
	
	cmp al, 's'
	jne notDOWN
	
	mov eax, [edi + SELECTOR.Y]
	inc eax ; moves position
	mov [edi + SELECTOR.Y], eax
	
	mov eax, 1
	jmp notRIGHT
	
	notDOWN:
	
	cmp al, 'q'
	jne notLEFT
	
	mov eax, [edi + SELECTOR.X]
	dec eax ; moves position
	mov [edi + SELECTOR.X], eax
	
	mov eax, 1
	jmp notRIGHT
	
	notLEFT:
	
	cmp al, 'd'
	jne noGoodKeyPress
	
	mov eax, [edi + SELECTOR.X]
	inc eax ; moves position
	mov [edi + SELECTOR.X], eax
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
	call DrawIMG, offset playerIMG, [esi + SELECTOR.X], [esi + SELECTOR.Y], 5, 5
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
	mov [esi + SELECTOR.X], 159
	mov [esi + SELECTOR.Y], 115
	
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
	jg TankOrBiker
		cmp ebx, 44		; x - y = 159 - 115 = 44
		jg Tower
		;spider
		call WaitForEmptyBuffer
		
		call setupspider
		
		jmp endOfSelctor
		
		Tower:
		; tower
		call WaitForEmptyBuffer
		
		call setuptower
		jmp endOfSelctor
		
	TankOrBiker:
		cmp ebx, 44		; x - y = 159 - 115 = 44
		jg	Biker
		; tank
		call WaitForEmptyBuffer
		
		call TankGame
		
		jmp endOfSelctor
		
		Biker:
		; biker
		call WaitForEmptyBuffer
		
		call BikerGame, 2, 5
		
		jmp endOfSelctor
	
	
	jmp endOfSelctor
	NoGameSelected:
	
	mov eax, 3	; no need to reset everyting
	
	endOfSelctor:
	ret
ENDP selectGame

PROC WaitForEmptyBuffer
	USES eax, ebx, ecx, edx
	
	stillSomethingHappening:
	
	mov ah, 01h 		; function 01h (check if key is pressed)
	int 16h 			; call keyboard BIOS
	jnz SHORT stillSomethingHappening	; if key not pressed than there is a 0 flag
	
	mov  ax, 0003h  ; get mouse position and buttonstatus
	int  33h        ; -> BX CX DX
	test ebx, 1      ; check left mouse click
	jnz SHORT stillSomethingHappening		; zero if no click
	
	; no actions anymore
	
	ret
ENDP WaitForEmptyBuffer

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
	
	mov esi, offset selector
	
	call ReadFile, offset player_file, offset playerIMG, PLAYERIMGSIZE 
	call ReadFile, offset backgroundIMG_file, offset backgroundIMG, SCRWIDTH*SCRHEIGHT 
	call ReadFile, offset winIMG_file, offset winIMG, 30*120
	call ReadFile, offset lossIMG_file, offset lossIMG, 30*120
	
	ReSetupTron:
	call setuptron, esi
	mov ecx, 1
	
	mov edx, 50	; number of frames without game selction
	
	xor edi, edi
	cmp ebx, 1
	jg EscapedGame
	jl LostGame
	mov ecx, 500		; number of frames to show win/loss msg
	mov edi, offset winIMG
	
	jmp redrawBackground
	LostGame:
	mov ecx, 500
	mov edi, offset lossIMG
	
	jmp redrawBackground
	EscapedGame:
	
	mainLoopTRON:
	call playerInput, esi
	
	cmp ecx, 1
	je redrawBackground
	cmp eax, 1
	jne DontRedrawBackgrnd
		redrawBackground:
		HideMouse
		call drawBackground
		cmp ecx, 1
		jle NoImg
		cmp edi, 0
		je NoImg
		call DrawIMG, edi, 100, 5, 120, 30
		NoImg:
		ShowMouse
	DontRedrawBackgrnd:
	
	call drawTronEntities, esi
	
	cmp edx, 1
	jg DontSelectGameYet
	
	call selectGame, [esi + SELECTOR.X], [esi + SELECTOR.Y], 5, 5
	mov ebx, eax
	cmp ebx, 3
	jl ReSetupTron
	
	push ecx
	push ebx
	push edx
	xor edx, edx
	xor ecx, ecx
	
	mov  ax, 0003h  ; get mouse position and buttonstatus
	int  33h        ; -> BX CX DX
	
	mov eax, 3
	
	test ebx, 1      ; check left mouse click
	jz SHORT NoMouseClick		; zero if no click
	shr ecx, 1
	
	call selectGame, ecx, edx, 1, 1
	
	NoMouseClick:
	pop edx
	pop ebx
	pop ecx
	
	mov ebx, eax
	cmp ebx, 3
	jl ReSetupTron
	
	DontSelectGameYet:
	
	cmp edx, 1
	jle DontDecrementEDX
	dec edx
	DontDecrementEDX:
	
	call wait_VBLANK, 1
	
	cmp ecx, 0
	jle mainLoopTRON	; if ecx is 0 dont decrement
	dec ecx
	
	jmp mainLoopTRON
	;; groote project: herschrijf alles om zoveel van de TANKS file opnieuw te gebruiken, zou doenbaar moeten zijn denk ik dan 	
	
	call terminateProcess

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------

; if add spider as struct: only need 2 pieces of info on spider, namely position, in x and y, and if alive doesnt matter=> insta respawn at start position spider

STRUC SELECTOR
	X dd 159
	Y dd 115
ENDS SELECTOR


DATASEG

	msg	db "Hello User! Welcome to the TRON game, use ZQSD to move your player around and left mouse to shoot, press any button to continue.", 13, 10, '$'
	
	selector		SELECTOR		1		dup(<,>)

	victory db "you won!", 13, 10, '$'
	
	lossmessage db "you lost!", 13, 10, '$'
	
	player_file db "player.bin", 0
	backgroundIMG_file db "backgrnd.bin", 0
	winIMG_file db "winscrn.bin", 0
	lossIMG_file db "lossscrn.bin", 0
	
UDATASEG
	playerIMG db PLAYERIMGSIZE dup (?)
	
	backgroundIMG db SCRWIDTH*SCRHEIGHT dup (?)
	winIMG db 30*120 dup (?)
	lossIMG db 30*120 dup (?)
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END start

; 12 is colorcode for red
; 10 voor groen