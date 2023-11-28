; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	Stijn Bettens, David Blinder
; date:		25/09/2017
; program:	Hello World!
; -------------------------------------------------------------------



IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height
BACKGROUNDCOL EQU 0	; background color
BIKERSPEED EQU 1	; Speed of Biker

RAND_A = 1103515245
RAND_C = 12345

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG

PROC rand
    USES    ebx, ecx, edx
	
	;code copied from RAND example
	
    mov     eax, [randSeed]
    mov     ecx, RAND_A
    mul     ecx
    add     eax, RAND_C
    mov		ebx, eax
	shr		ebx, 16
	
	mul		ecx
	add     eax, RAND_C
	mov     [randSeed], eax
	mov		ax, bx

    ret
ENDP rand

; Set the video mode
PROC setVideoMode
	ARG 	@@VM:byte
	USES 	eax

	movzx ax,[@@VM]
	int 10h

	ret
ENDP setVideoMode

; Fill the background (for mode 13h) faster
; (uses stosd optimization)
;	* fillcolor: input color
PROC fillBackgroundFaster
	ARG 	@@fillcolor:byte
	USES 	eax, ecx, edi

	; Initialize video memory address.
	mov	edi, VMEMADR
	
	; copy color value across all bytes of eax
	mov al, [@@fillcolor]	; ???B
	mov ah, al				; ??BB
	mov cx, ax			
	shl eax, 16				; BB00
	mov ax, cx				; BBBB

	; Scan the whole video memory and assign the background colour.
	mov	ecx, SCRWIDTH*SCRHEIGHT/4
	rep	stosd ;uses stosd (stores whole 4 bytes)

	ret
ENDP fillBackgroundFaster

PROC randBetweenVal
	ARG @@min:dword, @@max:dword
	USES ebx, edx
	
	call rand	; rand value in eax
	
	mov ebx, [@@max]	;get eax mod (max - min)
	sub ebx, [@@min]
	
	xor edx, edx
	div ebx				;div eax by ebx result in eax rest in edx
	
	mov eax, edx		; return in eax
	add eax, [@@min]	; get output between min and max
	
	ret
ENDP randBetweenVal

; Draw a rectangle (video mode 13h)
; 	* draws the rectangle from position (x0,y0) with
;	  positive width 'w' and height 'h', with color "col"
PROC drawRectangle
	ARG 	@@x0:word, @@y0:word, @@w:word, @@h:word, @@col: byte
	USES 	eax, ecx, edx, edi, ebx

	; Compute the index of the rectangle's top left corner
	movzx eax, [@@y0]
	mov edx, SCRWIDTH
	mul edx ;multiply EAX by EDX, store in EAX
	add	ax, [@@x0]
	
	;call print, eax

	; Compute top left corner address
	mov edi, VMEMADR
	add edi, eax
	
	;call print, edi
	
	;sub edi, 3200
	; Plot the top horizontal edge.
	movzx edx, [@@w]	; store width in edx for later reuse
	mov	ecx, edx
	mov	al,[@@col]
	
	;call print, edi
	
	;rep stosb
	movzx ebx, [@@h]
	@@horLoop:
		mov [edi], al
		inc edi
		loop @@horLoop
	
	sub edi, edx		; reset edi to left-top corner
	
	;add edi, 7136;wierd offset to align vertical with horizontal
	
	; plot both vertical edges
	movzx ecx, [@@h]
	@@vertLoop:
		mov	[edi], al		; left edge
		mov	[edi + edx - 1], al	; right edge
		add	edi, SCRWIDTH
		loop @@vertLoop
	; edi should point at the bottom-left corner now
	sub edi, SCRWIDTH
	
	;sub edi, 6496;wierd offset to align vertical with horizontal
	
	; Plot the bottom horizontal edge.
	mov	ecx, edx
	
	@@horLoop2:
		mov [edi], al
		inc edi
		loop @@horLoop2
	;rep stosb
	ret
ENDP drawRectangle

PROC drawFilledRectangle
	ARG 	@@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@col: dword
	USES 	eax, ecx, edx, edi, ebx, esi
	
	; Compute the index of the rectangle's top left corner
	mov eax, [@@y0]
	mov edx, SCRWIDTH
	mov esi, edx
	mul edx ;multiply EAX by EDX, store in EAX
	add	eax, [@@x0]

	; Compute top left corner address
	mov edi, VMEMADR
	add edi, eax
	
	; Plot the top horizontal edge.
	mov edx, [@@w]	; store width in edx for later reuse
	mov	ecx, edx
	mov	eax,[@@col]
	
	mov ebx, [@@h]
	
	@@startRectDraw:
		mov [edi], al
		inc edi
		loop @@startRectDraw
	
	sub edi, edx		; reset edi to left-top corner
	add edi, esi
	mov ecx, edx
	
	dec ebx
	
	cmp ebx, 0
	jge @@startRectDraw
	
	ret
ENDP drawFilledRectangle

PROC initiateBikers
	ARG		@@PtrBikers:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrBikers]
	mov ebx, [Bikersize]
	mov ecx, [TotalOfBikers]
	
	BikersShowLoop:
	cmp [edi + BIKER.alive], 0
	jne StillAlive
		mov [edi + BIKER.col], 25
	StillAlive:
	
	call drawFilledRectangle, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], [edi + BIKER.col]
	
	add edi, ebx
	loop BikersShowLoop
	
	ret
ENDP initiateBikers


;modifies the speed of the ennemy Bikers
;Initiates a bullet if the mouse is clicked
PROC inputFromPlayer
	ARG		@@PtrPlayerBiker:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov ah, 01h ; function 01h (check if key is pressed)
	int 16h ; call keyboard BIOS
	jz SHORT @@notpressed ;if key not pressed than there is a 0 flag ; SHORT means short jump (+127 or -128 bytes) solves warning message
	
	mov ah, 00h ;get key from buffer (ascii code in al)
	int 16h
	
	mov edi, [@@PtrPlayerBiker]
	
	cmp al, 'z' ; up
	jne @@notup
	mov [edi + BIKER.velX], 0
	mov [edi + BIKER.velY], -BIKERSPEED
	jmp @@notpressed
	
	@@notup:
	cmp al, 'q' ; left
	jne @@notleft
	mov [edi + BIKER.velX], -BIKERSPEED
	mov [edi + BIKER.velY], 0
	jmp @@notpressed
	
	@@notleft:
	cmp al, 's' ; down
	jne @@notdown
	mov [edi + BIKER.velX], 0
	mov [edi + BIKER.velY], BIKERSPEED
	jmp @@notpressed
	
	@@notdown:
	cmp al, 'd' ; right
	jne @@notpressed
	mov [edi + BIKER.velX], BIKERSPEED
	mov [edi + BIKER.velY], 0
	
	;@@notright:
	
	@@notpressed:
	
	ret
ENDP inputFromPlayer

PROC isInInterval
	ARG		@@a:dword, @@z:dword, @@b:dword
	USES	ecx, edx
	
	; test if a <= z <= b
	; returns in eax 1 if true, returns 2 if smaller than both
	
	mov eax, [@@a]
	mov ecx, [@@z]
	mov edx, [@@b]
	
	cmp eax, ecx
	jg NotInIntA
	
	cmp ecx, edx
	jg NotInInt
	
	mov eax, 1
	jmp endIntTest
	
	NotInIntA:
	mov eax, 2
	
	jmp endIntTest
	
	NotInInt:
	mov eax, 0
	
	endIntTest:
	
	ret
ENDP isInInterval

PROC colision
	ARG		@@X1:dword, @@Y1:dword, @@W1:dword, @@H1:dword, @@X2:dword, @@Y2:dword, @@W2:dword, @@H2:dword, @@BufferSpace:dword
	USES	ebx, ecx, edx, edi, esi
	;eax return a value from 0 or other:
	;0000 no colision, 0001 upper left colision of obj2, 0010 upper right colision of obj2, 0100 down left colision of obj2, 1000 down right colision of obj2
	;if two or more bits set -> multiple corners in obj1
	; BufferSpace: space to have between object and block
	
	;IMPORTANT: IF THE obj1 HAS A SMALLER RECTANGLE THAN obj2 THERE COULD BE NO COLISION DETECTED, IF IT IS POSSIBLE THAT obj1 IS SMALLER THAN obj2 RECALL THE PROC WITH INVERTED ORDER OF obj1 AND obj2
	
	xor esi, esi ; Stores return during PROC because eax gets used for calls
				; 0000
	
	mov ebx, [@@X1]
	mov edx, [@@X2]
	
	mov edi, ebx
	
	mov ecx, [@@BufferSpace]
	
	; test if upper left in obj1
	
	sub ebx, ecx			; X1 - Buffer
	add edi, ecx			
	add edi, [@@W1]			; X1 + Buffer + W1
	
	call isInInterval, ebx, edx, edi	; X1 - Buffer < X2 < X1 + Buffer + W1
	cmp eax, 2							; X2 < X1 - Buffer : If true -> only right side could have colision
	je testRight
	
	cmp eax, 1						; If eax is 1 then X2 is in interval
	jne testRight						; if X2 > X1 + Buffer + W1 > X1 - Buffer thus no colision possible
	
	; test if same holds for Y
	
	mov ebx, [@@Y1]
	mov edx, [@@Y2]
	
	mov edi, ebx
	
	sub ebx, ecx			; Y1 - Buffer
	add edi, ecx			
	add edi, [@@H1]			; Y1 + Buffer + H1
	
	call isInInterval, ebx, edx, edi	; Y1 - Buffer < Y2 < Y1 + Buffer + H1
	cmp eax, 1						; If eax is 1 then Y2 is in interval
	jne LeftUpperNotInInt
	;Both X and Y were in there respective interval so corner must be in obj1
	xor esi, 1
	
	LeftUpperNotInInt:
	;Since we are here we can test if down left is in obj1
	add edx, [@@H2]
	
	call isInInterval, ebx, edx, edi	; Y1 - Buffer < Y2 + H2 < Y1 + Buffer + H1
	cmp eax, 1						; I eax is 1 the X2 is in interval
	jne testRight
	xor esi, 4
	
	testRight:
	
	;cmp esi, 0						; if esi still 0 then we mustt have jumped from the first cmp
	;je NoReInitNecessary
	mov ebx, [@@X1]
	mov edx, [@@X2]
	
	mov edi, ebx
	
	; test if upper right in obj1
	
	sub ebx, ecx			; X1 - Buffer
	add edi, ecx			
	add edi, [@@W1]			; X1 + Buffer + W1
	
	;NoReInitNecessary:
	
	add edx, [@@W2]
	
	call isInInterval, ebx, edx, edi	; X1 - Buffer < X2 + W2 < X1 + Buffer + W1
	cmp eax, 2							; X2 + W2 < X1 - Buffer : If true -> no colision because obj2 completely to the right of obj1
	je NoCol
	
	cmp eax, 1						; If eax is 1 then X2 + W2 is in interval
	jne NoCol						; if X2 + W2 > X1 + Buffer + W1 > X1 - Buffer thus no colision possible
	
	; test if same holds for Y
	
	mov ebx, [@@Y1]
	mov edx, [@@Y2]
	
	mov edi, ebx
	
	sub ebx, ecx			; Y1 - Buffer
	add edi, ecx			
	add edi, [@@H1]			; Y1 + Buffer + H1
	
	call isInInterval, ebx, edx, edi	; Y1 - Buffer < Y2 < Y1 + Buffer + H1
	cmp eax, 1							; If eax is 1 then Y2 is in interval
	jne RightUpperNotInInt
	; Both X and Y were in there respective interval so corner must be in obj1
	xor esi, 2
	
	RightUpperNotInInt:
	;Since we are here we can test if down right is in obj1
	add edx, [@@H2]
	
	call isInInterval, ebx, edx, edi	; Y1 - Buffer < Y2 + H2 < Y1 + Buffer + H1
	cmp eax, 1							; If eax is 1 then X2 is in interval
	jne NoCol
	
	xor esi, 8
	
	NoCol:
	
	mov eax, esi					; put val of esi in eax for return value
	ret
ENDP colision

PROC checkColorsInRectangle
	ARG 	@@x0:dword, @@y0:dword, @@w:dword, @@h:dword
	USES 	eax, ecx, edx, edi, ebx, esi
	
	; Compute the index of the rectangle's top left corner
	mov eax, [@@y0]
	mov edx, SCRWIDTH
	mov esi, edx
	mul edx ;multiply EAX by EDX, store in EAX
	add	eax, [@@x0]

	; Compute top left corner address
	mov edi, VMEMADR
	add edi, eax
	
	; Plot the top horizontal edge.
	mov edx, [@@w]	; store width in edx for later reuse
	mov	ecx, edx
	mov	eax,[@@col]
	
	mov ebx, [@@h]
	
	@@startRectDraw:
		mov [edi], al
		inc edi
		loop @@startRectDraw
	
	sub edi, edx		; reset edi to left-top corner
	add edi, esi
	mov ecx, edx
	
	dec ebx
	
	cmp ebx, 0
	jge @@startRectDraw
	
	ret
ENDP checkColorsInRectangle

PROC moveBiker
	ARG		@@PtrBikers:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	; each bike has its own color different from the background, check if color on wich the bike will be drawn background is
	; if not then kill biker else move biker forward
	
	mov edi, [@@PtrBikers]
	mov edx, [Bikersize]
	mov ecx, [TotalOfBikers]
	
	BikerColisionLoop:
		cmp [edi + BIKER.alive], 0
		je skipBiker
		
		mov eax, [edi + BIKER.X]
		add eax, [edi + BIKER.velX]
		mov esi, eax
		mov ebx, [edi + BIKER.Y]
		add ebx, [edi + BIKER.velY]
		
		call checkColorsInRectangle, eax, ebx, [edi + BIKER.W], [edi + BIKER.H]
		
		cmp eax, 0 ; if eax is not equal to 0 then there is a color in the future rectangle so biker must die
		jne BikerIsDead
		mov [edi + BIKER.X], esi
		mov [edi + BIKER.Y], ebx
		
		jmp skipBiker
		BikerIsDead:
		mov [edi + BIKER.alive], 0
		
		skipBiker:
	
	add edi, edx
	loop BikerColisionLoop
	
	ret
ENDP moveEntities

PROC selectiveBackgroundFiller
	ARG		@@PtrBikers:dword, @@PtrBullets:dword
	USES 	ebx, ecx, edi
	
	mov edi, [@@PtrBikers]
	mov ebx, [Bikersize]
	mov ecx, [TotalOfBikers]
	
	BikersBackgoundLoop:
	cmp [edi + BIKER.alive], 0
	je SHORT noBackgroundResetNeededBiker
	
	call drawFilledRectangle, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], BACKGROUNDCOL
	
	noBackgroundResetNeededBiker:
	add edi, ebx
	loop BikersBackgoundLoop
	
	mov	edi, [@@PtrBullets]
	mov ebx, [BulletSize]
	mov ecx, [TotalOfBullets]
	
	BulletsBackgoundLoop:
	; cannot ignore non active bullets because they may still be drawn
	call drawFilledRectangle, [edi + BULLET.X], [edi + BULLET.Y], [edi + BULLET.W], [edi + BULLET.H], BACKGROUNDCOL
	
	add edi, ebx
	loop BulletsBackgoundLoop
	
	ret
ENDP selectiveBackgroundFiller

PROC show
	ARG		@@PtrBikers:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrBikers]
	mov ebx, [Bikersize]
	mov ecx, [TotalOfBikers]
	
	BikersShowLoop:
	cmp [edi + BIKER.alive], 0
	jne StillAlive
		mov [edi + BIKER.col], 25
	StillAlive:
	
	call drawFilledRectangle, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], [edi + BIKER.col]
	
	add edi, ebx
	loop BikersShowLoop
	
	ret
ENDP show

PROC endConditionBiker
	ARG 	@@PtrBikers:dword
	USES 	edi, ebx, ecx
	; returns a value in eax; test if eax = 10000(bin) then player wins, if eax < 10000(bin) ennemies win
	
	mov edi, [@@PtrBikers]
	mov ebx, [Bikersize]
	mov ecx, [TotalOfBikers]
	
	xor eax, eax
	
	BikersAliveTestLoop:
	or eax, [edi + BIKER.alive]
	shl eax, 1
	
	add edi, ebx
	loop BikersAliveTestLoop
	
	ret
ENDP endConditionBiker

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

; Terminate the program.
PROC terminateProcess
	USES eax
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess

;waits until the update of the next frame, does this for framecount number of times
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


start:
    sti            ; set The Interrupt Flag => enable interrupts
    cld            ; clear The Direction Flag
	
	push ds
	pop es
	
	call	setVideoMode,13h ;320x200 pixels, A palette of 256 colors, 6 bits per RGB channel (control with 1 byte)
	
	
	mov edi, offset Bikers
	call initiateBikers, edi
	
	mov ecx, 5000
	drawLoop:
	
	call selectiveBackgroundFiller, edi
	
	call inputFromPlayer, edi
	
	call moveEntities, edi
	
	call show, edi
	
	call	wait_VBLANK, 1
	
	call endConditionBiker, edi
	
	cmp eax, 32
	je EndBikerGamePlayerWin
	jl EndBikerGamePlayerLose
	
	loop drawLoop
	
	EndBikerGamePlayerWin:
	call setVideoMode, 03h	;back to text
	
	mov ah, 09h
	mov edx, offset WinMsg
	int 21h
	
	jmp SHORT EndBikerGame
	
	EndBikerGamePlayerLose:
	call setVideoMode, 03h	;back to text
	
	mov ah, 09h
	mov edx, offset LoseMsg
	int 21h
	
	EndBikerGame:
	;call showPalette

	call	waitForSpecificKeystroke, 001Bh ;press esc to kill program
	call	terminateProcess

; -------------------------------------------------------------------
; STRUCTS
; -------------------------------------------------------------------

STRUC BIKER
    X		dd 160
	Y		dd 100
	velX 	dd 0
	velY 	dd 0
	W		dd 23
	H		dd 20
	alive 	dd 1
	col 	dd 1
ENDS BIKER

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
randSeed		dd			2003630

Bikers			BIKER		5	dup	(<,,,,,,,>)
Bikersize	 	dd 			32
TotalOfBikers	dd			5

WinMsg			db 	"You WON!", 13, 10, '$'
LoseMsg			db 	"You LOST", 13, 10, '$'

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END start
