; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	Stijn Bettens, David Blinder
; date:		25/09/2017
; program:	Hello World!
; -------------------------------------------------------------------

;create struct for bullet
;create struct for tank
;move tanks (in grid) and bullets (all diag)



IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height

RAND_A = 1103515245
RAND_C = 12345

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG

PROC print
	ARG 	@@NUMBER:dword
	USES 	eax, ebx, ecx, edx
	
	mov eax, [@@NUMBER]
	mov ebx, 10
	xor ecx, ecx
	
	dividing:
	
	inc ecx
	
	xor edx, edx ; set EDX to zero (so EDX:EAX = EAX)
	div ebx ; eax result, edx remainder
	
	push edx
	
	test eax, eax
	
	jnz dividing
	
	mov ah, 02h
	
	printloop:
	pop edx
	add edx, '0'
	
	int 21h
	
	loop printloop

	ret
ENDP print

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

;Initiate rand coord for 1 block
PROC initiateBlocks		;problem with section division (has to come back to 0 when at end of hor line (same for Y)
	ARG 	@@PtrBlocks:dword
	USES 	eax, ebx, ecx, edi, edx, esi
	
	; Initialize video memory address.
	mov	edi, [@@PtrBlocks]
	mov ebx, [BlockSize]
	
	mov edx, [TotalOfBlocks]
	
	xor eax, eax
	
	DivAgain:
	mov ecx, edx
	shr ecx, 1		;divide number of blocks by 2 -> number of blocks in horizontal line
	
	inc eax			; val in eax is number of times we have to divide the Y by 2
	
	cmp ecx, 8		; 8 is maximum number of blocks on horizontal
	jg DivAgain
	
	push eax
	
	shr ecx, 1			; divide again by two to divide width by right amount
	
	mov esi, SCRWIDTH
	shr esi, cl			; width of 1 section in wich there will be 1 obstacle
	
	push esi			; value will be reused multiple times but not enough registers
	
	mov ecx, edx
	
	
	resetToStartX:
	mov edx, 30			; edx min val of section
	mov esi, [esp]
	sub esi, 30			; esi is max value of section
	
	BlocksInitLoop:
	
	cmp esi, SCRWIDTH
	jg resetToStartX
	
	call randBetweenVal, 30, 45
	mov [edi + BLOCK.W], eax
	
	push eax
	sub esi, eax
	
	; rand X coord
	call randBetweenVal, edx, esi
	mov [edi + BLOCK.X], eax
	
	pop eax
	add esi, eax
	
	mov eax, [esp]
	add esi, eax		; last pushed val is width of section
	add edx, eax
	
	add edi, ebx		; to next struct
	
	loop BlocksInitLoop
	
	add esp, 4			; poping without poping
	pop ecx
	
	mov	edi, [@@PtrBlocks]
	
	mov esi, SCRHEIGHT
	shr esi, cl			; divide Y in the correct number of rows
	
	mov edx, [TotalOfBlocks]
	mov eax, edx
	shr eax, cl			; number of blocks on one row
	
	push eax
	
	sub eax, edx
	neg eax				; first value at wich to reset
	
	push eax
	
	push esi			; offset between sections
	
						; the values in that are now used set the min distance between a block and the border of the screen
						; THE SUMATION OF THESE VALUES AND THE MAX H OF A BLOCK MUST BE LESS OR EQUAL TO THE HEIGHT OF A SECTION
	mov edx, 30			; edx min val of section (now in Y)
	sub esi, 25			; esi is max value of section (now in Y)
	
	mov ecx, [TotalOfBlocks]
	
	jmp BlocksInitLoopY
	
	resetToStartY:
	mov eax, [esp]
	add esi, eax		; last pushed val is width of section
	add edx, eax
	mov eax, [esp + 4]
	sub eax, [esp + 8]
	mov [esp + 4], eax
	
	BlocksInitLoopY:
	cmp ecx, [esp + 4]
	jle resetToStartY
	
	call randBetweenVal, 30, 45
	mov [edi + BLOCK.H], eax
	
	push eax
	sub esi, eax
	; rand Y coord
	call randBetweenVal, edx, esi
	mov [edi + BLOCK.Y], eax
	
	pop eax
	add esi, eax
	
	add edi, ebx		; to next struct
	
	loop BlocksInitLoopY
	
	add esp, 12			; poping without poping (reseting stack pointer to where it should be)
	
	ret
ENDP initiateBlocks

; Set ennemy tanks in corners and player tank in the center
PROC initiateTanks
	ARG 	@@PtrTanks:dword
	USES 	eax, ebx, ecx, edi, edx
	
	mov edi, [@@PtrTanks]
	mov ebx, [TankSize]
	
	
	mov [edi + TANK.X], 140
	mov [edi + TANK.Y], 150
	
	mov [edi + TANK.velX], 0
	mov [edi + TANK.velY], 0
	
	mov [edi + TANK.W], 25
	mov [edi + TANK.H], 20
	
	mov [edi + TANK.alive], 1
	mov [edi + TANK.col], 1
	
	mov edx, SCRWIDTH
	sub edx, [edi + TANK.W]
	
	add edi, ebx
	
	mov ecx, [TotalOfTanks]
	dec ecx
	
	resetXTank:
	xor eax, eax
	
	TanksInitLoop:
	cmp eax, SCRWIDTH
	jg resetXTank
	
	mov [edi + TANK.X], eax
	mov [edi + TANK.Y], 0
	
	mov [edi + TANK.velX], 0
	mov [edi + TANK.velY], 0
	
	mov [edi + TANK.W], 25
	mov [edi + TANK.H], 20
	
	mov [edi + TANK.alive], 1
	mov [edi + TANK.col], 14
	
	add eax, edx
	
	add edi, ebx
	loop TanksInitLoop
	
	mov edi, [@@PtrTanks]
	add edi, ebx
	
	mov edx, SCRHEIGHT
	sub edx, [edi + TANK.H]
	
	mov ecx, [TotalOfTanks]
	shr ecx, 1
	
	mov eax, edx
	
	TanksInitLoopY:
	mov [edi + TANK.Y], eax
	
	add edi, ebx
	loop TanksInitLoopY
	
	ret
ENDP initiateTanks

PROC showPalette
	USES 	eax, ecx, edi

	; Initialize video memory address.
	mov	edi, VMEMADR
	
	
	mov ecx, SCRHEIGHT
	@@vertLoop:
		push ecx
		mov ecx, 63
		mov al, 0
		@@horLoop:
			;linewidth 5px
			push ecx
			mov ecx, 4
			
			@@lineloop:
				mov [edi], al
				inc edi
				loop @@lineloop
				
			inc al
			
			pop ecx
			
			loop @@horLoop
		sub edi, 252
		add edi, SCRWIDTH
		pop ecx
		loop @@vertLoop
	ret
ENDP showPalette

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

;modifies the speed of the tank (if needed) given the keyboard input zqsd
;Initiates a bullet if the mouse is clicked
PROC inputFromPlayer
	ARG		@@PtrPlayerTank:dword, @@PtrBullets:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov ah, 01h ; function 01h (check if key is pressed)
	int 16h ; call keyboard BIOS
	jz SHORT @@notpressed ;if key not pressed than there is a 0 flag ; SHORT means short jump (+127 or -128 bytes) solves warning message
	
	mov ah, 00h ;get key from buffer (ascii code in al)
	int 16h
	
	mov edi, [@@PtrPlayerTank]
	
	cmp al, 'z' ; up
	jne @@notup
	mov [edi + TANK.velX], 0
	mov [edi + TANK.velY], -1
	
	@@notup:
	cmp al, 'q' ; left
	jne @@notleft
	mov [edi + TANK.velX], -1
	mov [edi + TANK.velY], 0
	
	@@notleft:
	cmp al, 's' ; down
	jne @@notdown
	mov [edi + TANK.velX], 0
	mov [edi + TANK.velY], 1
	
	@@notdown:
	cmp al, 'd' ; right
	jne @@notpressed
	mov [edi + TANK.velX], 1
	mov [edi + TANK.velY], 0
	
	;@@notright:
	
	@@notpressed:
	
	mov esi, [@@PtrBullets]
	
	cmp [esi + BULLET.active], 0
	jg  MouseNC
	
	xor ecx, ecx
	xor edx, edx
	
	mov  ax, 0003h  ; get mouse position and buttonstatus
	int  33h        ; -> BX CX DX
	
	test ebx, 1      ; check left mouse click
	jz MouseNC		; zero if no click
	shr ecx, 1
	
	;calculating normalized speed
	
	sub ecx, [edi + TANK.X];delta x
	mov eax, [edi + TANK.W]
	shr eax, 1				; Tank center
	sub ecx, eax
	
	sub edx, [edi + TANK.Y];delta y
	mov eax, [edi + TANK.H]
	shr eax, 1				; Tank center
	sub edx, eax
	
	cmp edx, 0	;calculating abs val of dx (delta y)
	jge PosD
	neg edx
	push -1
	jmp nextNegD
	PosD:
	push 1
	
	nextNegD:
	
	push edx
	
	cmp ecx, 0	;calculating abs val of cx (delta x)
	jge PosC
	neg ecx
	push -1
	jmp nextNegC
	PosC:
	push 1
	
	nextNegC:
	
	mov eax, ecx
	
	add ecx, edx	;aproximation of mag of delta vec |x|+|y|
	
	shr ecx, 2	;dividing by 4 to get magnitude of speed vector (k)
	
	cmp ecx, 0	;protection against division by 0
	je SHORT MouseNC
	
	xor edx, edx ; set EDX to zero
	div ecx ; eax result, edx remainder (A/k = a)
	
	pop edx
	cmp edx, 0
	jge XPositive
	neg eax
	XPositive:
	
	mov [esi + BULLET.velX], eax
	
	pop eax
	
	xor edx, edx ; set EDX to zero
	div ecx ; eax result, edx remainder (B/k = b)
	
	pop edx
	cmp edx, 0
	jge YPositive
	neg eax
	YPositive:
	
	mov [esi + BULLET.velY], eax
	
	mov ebx, [edi + TANK.W]
	shr ebx, 1		; divide by 2 to get middle of tank
	
	mov ecx, [esi + BULLET.W]
	shr ecx, 1		; divide with of bullet by 2 to get middle to place it in the middle of the tank
	
	mov eax, [edi + TANK.X]
	
	add eax, ebx
	sub eax, ecx
	mov [esi + BULLET.X], eax		;first element in array is for player
	
	mov ebx, [edi + TANK.H]
	shr ebx, 1		; divide by 2 to get middle of tank
	
	mov ecx, [esi + BULLET.H]
	shr ecx, 1		; divide with of bullet by 2 to get middle to place it in the middle of the tank
	
	mov eax, [edi + TANK.Y]
	
	add eax, ebx
	sub eax, ecx
	mov [esi + BULLET.Y], eax		;first element in array is for player
	
	mov [esi + BULLET.bounces], 0
	mov [esi + BULLET.active], 1
	
	MouseNC:
	
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

PROC moveEntities
	ARG		@@PtrTanks:dword, @@PtrBlocks:dword, @@PtrBullets:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov	edi, [@@PtrBlocks]
	mov ecx, [TotalOfBlocks]
	
	;----------------------------------------------------------------------------------------------------
	;tank COLISION
	;----------------------------------------------------------------------------------------------------

	mov esi, [@@PtrTanks]
	mov edx, [TotalOfTanks]
	
	
	SetTankCoor:
	cmp [esi + TANK.alive], 0
	je TankNotAlive
	mov ebx, [esi + TANK.Y]
	add ebx, [esi + TANK.velY]
	TanksColisionLoop:
	mov eax, [esi + TANK.X]
	add eax, [esi + TANK.velX]

	
	;ARG			@@X1:dword, 	@@Y1:dword, 	@@W1:dword, 	 @@H1:dword, @@X2:dword, @@Y2:dword,@@W2:dword,@@H2:dword, @@BufferSpace:dword
	call colision, [edi + BLOCK.X], [edi + BLOCK.Y], [edi + BLOCK.W], [edi + BLOCK.H], eax, ebx, [esi + TANK.W], [esi + TANK.H], 0
	;call print, eax
	
	cmp eax, 0
	je SHORT NoColisionWithBlock
		cmp [esi + TANK.velX], 0
		je speedIsVert
		jl speedXIsNeg
		;VelX is pos.
		mov eax, [edi + BLOCK.X]
		sub eax, [esi + TANK.W]
		dec eax
		
		mov [esi + TANK.X], eax
		
		jmp SetVelZero
		
		speedXIsNeg:
		;VelX is neg
		mov eax, [edi + BLOCK.X]
		add eax, [edi + BLOCK.W]
		inc eax
		
		mov [esi + TANK.X], eax
		
		jmp SetVelZero
		
		speedIsVert:
		cmp [esi + TANK.velY], 0
		je SetVelZero
		jl speedYIsNeg
		
		mov eax, [edi + BLOCK.Y]
		sub eax, [esi + TANK.H]
		dec eax
		
		mov [esi + TANK.Y], eax
		
		jmp SetVelZero
		
		speedYIsNeg:
		;VelY is neg
		mov eax, [edi + BLOCK.Y]
		add eax, [edi + BLOCK.H]
		inc eax
		
		mov [esi + TANK.Y], eax
		
		SetVelZero:
	
		mov [esi + TANK.velX], 0
		mov [esi + TANK.velY], 0
	
	NoColisionWithBlock:
	
	add edi, [BlockSize]
	loop TanksColisionLoop
	
	mov eax, [esi + TANK.X]
	add eax, [esi + TANK.velX]
	mov [esi + TANK.X], eax
	
	mov eax, [esi + TANK.Y]
	add eax, [esi + TANK.velY]
	mov [esi + TANK.Y], eax
	
	TankNotAlive:
	
	mov edi, [@@PtrBlocks]
	mov ecx, [TotalOfBlocks]
	add esi, [TankSize]
	
	dec edx
	cmp edx, 0
	jg SetTankCoor
	
	;----------------------------------------------------------------------------------------------------
	;bullet COLISION
	;----------------------------------------------------------------------------------------------------
	
	mov edi, [@@PtrBlocks]
	mov ecx, [TotalOfBlocks]

	mov esi, [@@PtrBullets]
	mov edx, [TotalOfBullets]
	
	BulletsColisionLoop:
	cmp [esi + BULLET.active], 1
	jl SHORT NoCalcBulletColision
	
	mov eax, [esi + BULLET.X]
	add eax, [esi + BULLET.velX]

	mov ebx, [esi + BULLET.Y]
	add ebx, [esi + BULLET.velY]
	
	;ARG			@@X1:dword, 	@@Y1:dword, 	@@W1:dword, 	 @@H1:dword, @@X2:dword, @@Y2:dword,@@W2:dword,@@H2:dword, @@BufferSpace:dword
	call colision, [edi + BLOCK.X], [edi + BLOCK.Y], [edi + BLOCK.W], [edi + BLOCK.H], eax, ebx, [esi + BULLET.W], [esi + BULLET.H], 0
	;call print, eax
	cmp eax, 0
	je SHORT NoBulletColisionWithBlock
		; cmp [esi + BULLET.velX], 0
		; je speedBulletIsVert
		; jl BulletSpeedXIsNeg
		; ;VelX is pos.
		; mov eax, [edi + BLOCK.X]
		; ;mov ebx, 
		; sub eax, [esi + BULLET.W]
		; dec eax
		
		; mov [esi + BULLET.X], eax
		
		; jmp SetVelZero
		
		; BulletSpeedXIsNeg:
		; ;VelX is neg
		; mov eax, [edi + BLOCK.X]
		; add eax, [edi + BLOCK.W]
		; inc eax
		
		; mov [esi + BULLET.X], eax
		
		; jmp SetVelZero
		
		; speedBulletIsVert:
		; cmp [esi + BULLET.velY], 0
		; je SetVelZero
		; jl speedYIsNeg
		
		; mov eax, [edi + BLOCK.Y]
		; sub eax, [esi + BULLET.H]
		; dec eax
		
		; mov [esi + BULLET.Y], eax
		
		; jmp SetVelZero
		
		; speedYIsNeg:
		; ;VelY is neg
		; mov eax, [edi + BLOCK.Y]
		; add eax, [edi + BLOCK.H]
		; inc eax
		
		; mov [esi + BULLET.Y], eax
		
		; SetVelZero:
	
		mov eax, [esi + BULLET.velX]
		neg eax
		mov [esi + BULLET.velX], eax
		
		mov eax, [esi + BULLET.velY]
		neg eax
		mov [esi + BULLET.velY], eax
		
	NoBulletColisionWithBlock:
	
	add edi, [BlockSize]
	loop BulletsColisionLoop
	
	NoCalcBulletColision:
	
	mov eax, [esi + BULLET.X]
	add eax, [esi + BULLET.velX]
	mov [esi + BULLET.X], eax
	
	mov eax, [esi + BULLET.Y]
	add eax, [esi + BULLET.velY]
	mov [esi + BULLET.Y], eax
	
	mov edi, [@@PtrBlocks]
	mov ecx, [TotalOfBlocks]
	add esi, [BulletSize]
	
	dec edx
	cmp edx, 0
	jg BulletsColisionLoop
	
	;---------------------------------------------------------------------------------------------
	;TankBulletColision
	;---------------------------------------------------------------------------------------------
	
	mov edi, [@@PtrTanks]
	mov ecx, [TotalOfTanks]

	mov esi, [@@PtrBullets]
	mov edx, [TotalOfBullets]
	
	BulletsTankColisionLoop:
	cmp [esi + BULLET.active], 0
	je SHORT BulletNotActive
	;Bullet active: check two things: colision with other tank or check if colision has stoped with og Tank
	
	;ARG			@@X1:dword, 	@@Y1:dword, 	@@W1:dword,    @@H1:dword,	   @@X2:dword, 		 @@Y2:dword,	   @@W2:dword,		 @@H2:dword, 	   @@BufferSpace:dword
	call colision, [edi + TANK.X], [edi + TANK.Y], [edi + TANK.W], [edi + TANK.H], [esi + BULLET.X], [esi + BULLET.Y], [esi + BULLET.W], [esi + BULLET.H], 0
	
	
	;inc eax
	;inc eax
	
	cmp eax, 0
	je SHORT InitiateBulletColision
		cmp [esi + BULLET.active], 1;moving bullet but cannot hit og tank
		je InitiateBulletColision
		
		cmp ecx, edx
		
		je NoBulletColisionWithTank
		
		mov [edi + TANK.alive], 0	; tank hit by completely active bullet so must die
		mov [esi + BULLET.active], 0
	
		jmp NoBulletColisionWithTank
	
	InitiateBulletColision:
	
	
	cmp [esi + BULLET.active], 1; bullet is only 1 active so cant hit yet, must be completely activated
	jne NoBulletColisionWithTank
	
	mov [esi + BULLET.active], 2
	
	NoBulletColisionWithTank:
	
	add edi, [TankSize]
	loop BulletsTankColisionLoop
	
	BulletNotActive:
	;Bullet not active so go to next bullet
	
	mov edi, [@@PtrTanks]
	mov ecx, [TotalOfTanks]
	add esi, [BulletSize]
	
	dec edx
	cmp edx, 0
	jg BulletsTankColisionLoop
	
	ret
ENDP moveEntities

PROC selectiveBackgroundFiller
	ARG		@@PtrTanks:dword, @@PtrBullets:dword
	USES 	ebx, ecx, edi
	
	mov edi, [@@PtrTanks]
	mov ebx, [TankSize]
	mov ecx, [TotalOfTanks]
	
	TanksBackgoundLoop:
	cmp [edi + TANK.alive], 0
	je SHORT noBackgroundResetNeededTank
	
	call drawFilledRectangle, [edi + TANK.X], [edi + TANK.Y], [edi + TANK.W], [edi + TANK.H], 0
	
	noBackgroundResetNeededTank:
	add edi, ebx
	loop TanksBackgoundLoop
	
	mov	edi, [@@PtrBullets]
	mov ebx, [BulletSize]
	mov ecx, [TotalOfBullets]
	
	BulletsBackgoundLoop:
	; cannot ignore non active bullets because they may still be drawn
	call drawFilledRectangle, [edi + BULLET.X], [edi + BULLET.Y], [edi + BULLET.W], [edi + BULLET.H], 0
	
	add edi, ebx
	loop BulletsBackgoundLoop
	
	ret
ENDP selectiveBackgroundFiller

PROC show
	ARG		@@PtrTanks:dword, @@PtrBullets:dword, @@PtrBlock:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrTanks]
	mov ebx, [TankSize]
	mov ecx, [TotalOfTanks]
	
	TanksShowLoop:
	cmp [edi + TANK.alive], 0
	jne StillAlive
		mov [edi + TANK.col], 25
	StillAlive:
	
	call drawFilledRectangle, [edi + TANK.X], [edi + TANK.Y], [edi + TANK.W], [edi + TANK.H], [edi + TANK.col]
	
	add edi, ebx
	loop TanksShowLoop
	
	
	mov	edi, [@@PtrBlock]
	mov ebx, [BlockSize]
	mov ecx, [TotalOfBlocks]
	
	BlocksShowLoop:
	call drawRectangle, [edi + BLOCK.X], [edi + BLOCK.Y], [edi + BLOCK.W], [edi + BLOCK.H], [edi + BLOCK.col]
	
	add edi, ebx
	loop BlocksShowLoop
	
	mov	edi, [@@PtrBullets]
	mov ebx, [BulletSize]
	mov ecx, [TotalOfBullets]
	
	BulletsShowLoop:
	cmp [edi + BULLET.active], 0
	je SHORT bulletNotActive
	
	mov eax, [edi + BULLET.active]
	inc eax
	mov [edi + BULLET.col], eax
	call drawRectangle, [edi + BULLET.X], [edi + BULLET.Y], [edi + BULLET.W], [edi + BULLET.H], [edi + BULLET.col]
	
	bulletNotActive:
	add edi, ebx
	loop BulletsShowLoop
	
	ret
ENDP show

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
	call setVideoMode, 03h
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
	
	mov edx, offset Blocks
	
	call initiateBlocks, edx
	
	mov edi, offset Tanks
	call initiateTanks, edi
	
	
	
	NoMouse:
	mov  ax, 0000h  ; reset mouse
	int  33h        ; -> AX BX
	cmp  ax, 0FFFFh
	jne  NoMouse
	mov  ax, 0001h  ; show mouse
	int  33h
	
	
	mov ebx, offset Bullets
	
	mov ecx, 1000
	drawLoop:
	
	call selectiveBackgroundFiller, edi, ebx
	
	call inputFromPlayer, edi, ebx
	
	call moveEntities, edi, edx, ebx
	
	
	
	call show, edi, ebx, edx
	
	
	;call	drawRectangle, ecx, 50, 60, 90, 32
	
	call	wait_VBLANK, 1
	
	;call print, edx
	
	loop drawLoop
	
	;call showPalette

	call	waitForSpecificKeystroke, 001Bh ;press esc to kill program
	call	terminateProcess

; -------------------------------------------------------------------
; STRUCTS
; -------------------------------------------------------------------

STRUC BLOCK
	X		dd 0
	Y		dd 0
	W 		dd 0
	H		dd 0
	col 	dd 15
ENDS BLOCK

STRUC BULLET
	X		dd 0
	Y		dd 0
	velX 	dd 0
	velY 	dd 0
	bounces	dd 0
	active 	dd 0
	col 	dd 30
	W		dd 3
	H		dd 3
ENDS BULLET

STRUC TANK
    X		dd 160
	Y		dd 100
	velX 	dd 0
	velY 	dd 0
	alive 	dd 1
	col 	dd 1
	W		dd 23
	H		dd 20
ENDS TANK

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
randSeed		dd			2003630

Tanks			TANK		5	dup	(<,,,,,,,>)
TankSize	 	dd 			32
TotalOfTanks	dd			5

Bullets 		BULLET		5	dup	(<,,,,,,,>)
BulletSize	 	dd 			36
TotalOfBullets	dd			5

Blocks			BLOCK		4	dup	(<,,,,>)
BlockSize	 	dd 			20
TotalOfBlocks	dd			4

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END start
