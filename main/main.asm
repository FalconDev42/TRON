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
INCLUDE "spider.inc"
; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height
IMGSIZE EQU 5*5

CODESEG


PROC wait_VBLANK
	ARG @@framecount: word
	USES eax, ecx, edx
	
	;code copied from DANCER
	
	mov dx, 03dah 					; Wait for screen refresh
	movzx ecx, [@@framecount]
	
		@@VBlank_phase1:
		in al, dx 
		and al, 8
		jnz @@VBlank_phase1
		@@VBlank_phase2:
		in al, dx 
		and al, 8
		jz @@VBlank_phase2
	loop @@VBlank_phase1
	
	ret 
ENDP wait_VBLANK

PROC troninterface
	ARG 	@@key:byte
	USES 	eax, ebx,esi,edi	
	mov esi, offset player
	;mov edi, offset bullet
	troninterfaceloop:
		call DrawTronEntities
		
		
		call wait_VBLANK, 2
		;mov ah, 01h ; function 01h (check if key is pressed)
		;int 16h ; call keyboard BIOS
		
		;jz SHORT re_troninterfaceloop;if key not pressed than there is a 0 flag ; SHORT means short jump (+127 or -128 bytes) solves warning message
		
		mov ah, 00h ;get key from buffer (ascii code in al)
		int 16h
		
		cmp	al,[@@key]; checks to see if we ditch program
		je  exit
		cmp al,122; inset code for (W,) Z want in azerty 
		
		je UP
		cmp al,115; checks to see for S
		je DOWN
		cmp al,113; checks for Q
		je LEFT
		cmp al,100; checks for D
		je RIGHT
		re_troninterfaceloop:
	
	jne	troninterfaceloop ; if doesnt find anything restart
	
	UP:
	;xor al,al
	mov ecx,[esi+PLAYER.Y]
	cmp ecx,3 ; checks borders
	jl re_troninterfaceloop
	
	dec ecx ; moves position
	mov [esi+PLAYER.Y],ecx
	jmp re_troninterfaceloop ;returns to wait for keypress
	
	DOWN:
	mov ecx,[esi+PLAYER.Y]
	cmp ecx, SCRHEIGHT-3
	jge re_troninterfaceloop
	inc ecx
	mov [esi+PLAYER.Y],ecx
	jmp re_troninterfaceloop
	
	LEFT:
	;xor al,al
	mov ecx, [esi+PLAYER.X]
	cmp ecx,3
	jl re_troninterfaceloop
	
	dec ecx
	mov [esi+PLAYER.X],ecx
	jmp re_troninterfaceloop
	
	RIGHT:
	;xor al,al
	mov ecx,[esi+PLAYER.X]
	cmp ecx, SCRWIDTH-3
	jge re_troninterfaceloop
	inc ecx
	mov [esi+PLAYER.X],ecx
	jmp re_troninterfaceloop
	exit:
	call setupspider
	;call terminateProcess
	ret
ENDP troninterface

PROC DrawTronEntities
	USES eax,esi,ecx,edx,ebx,edi
	mov esi, offset player
	mov edi, [esi+PLAYER.X]
	sub edi, 2; to get the topleft corner
	mov ebx,[esi+PLAYER.Y]
	sub ebx, 2
	call DrawIMG, offset playerread, edi, ebx, 5, 5
	ret
ENDP DrawTronEntities

PROC ReadFile
	ARG	 @@filepathptr: dword,@@dataptr: dword,@@noofbytes: dword 
	USES eax, ebx, ecx, edx, esi, edi
	
	; open file, get filehandle in AX
	mov al, 0 ; read only
	mov edx, [@@filepathptr]
	mov ah, 3dh
	int 21h
	
	mov  edx, offset openErrorMsg
	jc @@print_error ; carry flag is set if error occurs

	; read file data 
	mov bx, ax ; move filehandle to bx
	mov ecx, [@@noofbytes]
	mov edx, [@@dataptr]
	mov ah, 3fh
	int 21h

	mov  edx, offset readErrorMsg
	jc @@print_error
	
	; close file
	mov ah, 3Eh
	int 21h
	
	mov  edx, offset closeErrorMsg
	jc @@print_error
	
	ret

@@print_error:
	call setVideoMode, 03h
	mov  ah, 09h
	int  21h
	
	mov	ah,00h
	int	16h
	call terminateProcess	
ENDP ReadFile

PROC DrawIMG
	ARG	 @@IMGPtr: dword, @@x:dword, @@y:dword, @@w:dword, @@h:dword
	USES esi, edi, ecx, eax,edx
	
	mov eax, [@@y]
	mov ecx, SCRWIDTH
	mul ecx 		;multiply EAX by ECX, store in EAX
	add	eax, [@@x]
	
	;call print, eax

	; Compute top left corner address
	mov edi, VMEMADR
	add edi, eax
	
	mov esi, [@@IMGPtr]
	mov ecx, [@@h]
	
	DrawLineOfIMG:
	mov edx, ecx
	mov ecx, [@@w]
	rep movsb
	
	add edi, SCRWIDTH
	sub edi, [@@w]
	mov ecx, edx
	loop DrawLineOfIMG
	ret	
ENDP DrawIMG

PROC DrawBG
	ARG	 @@dataptr: dword 
	USES esi,edi,ecx
	mov esi, [@@dataptr]
	mov edi, VMEMADR
	mov ecx, IMGSIZE
	rep movsb	
	ret	
ENDP DrawBG

PROC waitForSpecificKeystroke
	ARG 	@@key:byte
	USES 	eax

	@@waitForKeystroke:
		mov	ah,00h
		int	16h
		cmp	al,[@@key]
	jne	@@waitForKeystroke

	ret
ENDP waitForSpecificKeystroke

;Terminate the program.
PROC terminateProcess
	USES eax
	call setVideoMode, 03h
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess

PROC setVideoMode
	ARG arg1:word
	USES eax
	;int 10h; AH=0, AL=mode.
	mov AX, [arg1] ; video mode whatever
	int 10h
	ret
ENDP setVideoMode

PROC tronTerrain
	; inset code here to draw terrain, will be with 
	ret
ENDP tronTerrain

PROC setuptron
	USES eax, ebx, edx,ecx
	
	call setVideoMode,13h
	; insert the call readfile here for the background
	call ReadFile, offset player_file, offset playerread, IMGSIZE 
	call tronTerrain
	call troninterface,001Bh
	
	
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
	xor ah,ah
	xor edx,edx
	

	mov ah,00h
	int 16h
	
	call setuptron
	;; groote project: herschrijf alles om zoveel van de TANKS file opnieuw te gebruiken, zou doenbaar moeten zijn denk ik dan 	
	mov ah,00h
	int 16h
	call	waitForSpecificKeystroke, 001Bh ;press esc to kill program
	call terminateProcess

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------

; if add spider as struct: only need 2 pieces of info on spider, namely position, in x and y, and if alive doesnt matter=> insta respawn at start position spider

STRUC PLAYER
	X dd 160
	Y dd 100
	ALIVE dd 1
	COL dd 15
ENDS PLAYER


DATASEG

	msg	db "Hello User! Welcome to the TRON game, use ZQSD to move your player aroun and left mouse to shoot, press any button to continue.", 13, 10, '$'
	
	palette		db 768 dup (?)
	player		PLAYER		1		dup(< ,,,>)
	playeramount dd 1;both this and the size shouldnt matter, atleast not how the procedures are set up now
	playersize dd 16;
	
	
	playerpos dd 100,100; stores position of player
	
	
	
	victory db "you won!", 13, 10, '$'
	
	lossmessage db "you lost!", 13, 10, '$'
	
	randSeed		dd			2003630
	spider_file db "spider.bin", 0
	player_file db "player.bin", 0
	openErrorMsg db "could not open file", 13, 10, '$'
	readErrorMsg db "could not read data", 13, 10, '$'
	closeErrorMsg db "error during file closing", 13, 10, '$'
	; change shit here for the bin of the background
	
UDATASEG
	spiderread db IMGSIZE dup (?)
	playerread db IMGSIZE dup (?)
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END start

; 12 is colorcode for red
; 10 voor groen