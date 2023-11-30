; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
; -------------------------------------------------------------------

;Group: G20



IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height
TANKSPEED EQU 12	; screen height (16 is 1 << 4)
SCALARBITSHIFT EQU 4	;scales every coordinate/speed

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
	shl eax, SCALARBITSHIFT
	mov [edi + BLOCK.W], eax
	shr eax, SCALARBITSHIFT
	
	push eax
	sub esi, eax
	
	; rand X coord
	call randBetweenVal, edx, esi
	shl eax, SCALARBITSHIFT
	mov [edi + BLOCK.X], eax
	;shr eax, SCALARBITSHIFT
	
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
	shl eax, SCALARBITSHIFT
	mov [edi + BLOCK.H], eax
	shr eax, SCALARBITSHIFT
	
	push eax
	sub esi, eax
	; rand Y coord
	call randBetweenVal, edx, esi
	shl eax, SCALARBITSHIFT
	mov [edi + BLOCK.Y], eax
	;shr eax, SCALARBITSHIFT
	
	pop eax
	add esi, eax
	
	add edi, ebx		; to next struct
	
	loop BlocksInitLoopY
	
	add esp, 12			; poping without poping (reseting stack pointer to where it should be)
	
	ret
ENDP initiateBlocks

; Set ennemy tanks in corners and player tank in the center
PROC initiateTanks
	ARG 	@@PtrTanks:dword, @@PtrInitArray:dword
	USES 	eax, ebx, ecx, edi, edx, esi
	
	mov edi, [@@PtrTanks]
	mov ebx, [TankSize]
	mov esi, [@@PtrInitArray]
	
	
	; mov [edi + TANK.X], 140
	; mov [edi + TANK.Y], 150
	
	; mov [edi + TANK.velX], 0
	; mov [edi + TANK.velY], 0
	
	; mov [edi + TANK.W], 25
	; mov [edi + TANK.H], 20
	
	; mov [edi + TANK.alive], 1
	; mov [edi + TANK.col], 1
	
	; mov edx, SCRWIDTH
	; sub edx, [edi + TANK.W]
	
	; add edi, ebx
	
	mov ecx, [TotalOfTanks]
	; dec ecx
	
	; resetXTank:
	; xor eax, eax
	
	; TanksInitLoop:
	; cmp eax, SCRWIDTH
	; jg resetXTank
	
	; mov [edi + TANK.X], eax
	; mov [edi + TANK.Y], 0
	
	; mov [edi + TANK.velX], 0
	; mov [edi + TANK.velY], 0
	
	; mov [edi + TANK.W], 25
	; mov [edi + TANK.H], 20
	
	; mov [edi + TANK.alive], 1
	; mov [edi + TANK.col], 14
	
	; add eax, edx
	
	; add edi, ebx
	; loop TanksInitLoop
	
	; mov edi, [@@PtrTanks]
	; add edi, ebx
	
	; mov edx, SCRHEIGHT
	; sub edx, [edi + TANK.H]
	
	; mov ecx, [TotalOfTanks]
	; shr ecx, 1
	
	; mov eax, edx
	
	; TanksInitLoopY:
	; mov [edi + TANK.Y], eax
	
	; add edi, ebx
	; loop TanksInitLoopY
	
	TanksInitLoop:
	
	mov eax, [esi]
	shl eax, SCALARBITSHIFT
	mov [edi + TANK.X], eax
	add esi, 4
	
	mov eax, [esi]
	shl eax, SCALARBITSHIFT
	mov [edi + TANK.Y], eax
	add esi, 4
	
	mov [edi + TANK.velX], 0
	mov [edi + TANK.velY], 0
	
	mov [edi + TANK.W], 400	; 25 shl 4
	mov [edi + TANK.H], 320	; 20 shl 4
	
	mov [edi + TANK.alive], 1
	
	cmp ecx, [TotalOfTanks]
	jne TankIsNotPlayer
	mov [edi + TANK.col], 1
	jmp TankIsEnnemy
	TankIsNotPlayer:
	mov [edi + TANK.col], 14
	TankIsEnnemy:
	
	add edi, ebx
	loop TanksInitLoop
	
	ret
ENDP initiateTanks

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

;modifies the speed of the ennemy tanks
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
	mov [edi + TANK.velY], -TANKSPEED
	jmp @@notpressed
	
	@@notup:
	cmp al, 'q' ; left
	jne @@notleft
	mov [edi + TANK.velX], -TANKSPEED
	mov [edi + TANK.velY], 0
	jmp @@notpressed
	
	@@notleft:
	cmp al, 's' ; down
	jne @@notdown
	mov [edi + TANK.velX], 0
	mov [edi + TANK.velY], TANKSPEED
	jmp @@notpressed
	
	@@notdown:
	cmp al, 'd' ; right
	jne @@notpressed
	mov [edi + TANK.velX], TANKSPEED
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
	jz SHORT MouseNC		; zero if no click
	shr ecx, 1
	
	;calculating normalized speed
	
	shl ecx, SCALARBITSHIFT
	shl edx, SCALARBITSHIFT
	
	mov eax, [edi + TANK.W]
	shr eax, 1				; Tank center X
	add eax, [edi + TANK.X]
	
	mov ebx, [edi + TANK.H]
	shr ebx, 1				; Tank center Y
	add ebx, [edi + TANK.Y]
	
	call ShootBullet, esi, eax, ebx, ecx, edx
	
	MouseNC:
	
	ret
ENDP inputFromPlayer
	
PROC ShootBullet
	ARG		@@PtrBullets:dword, @@Xstart:dword, @@Ystart:dword, @@Xend:dword, @@Yend:dword
	USES 	eax, ebx, ecx, edx, esi
	
	mov esi, [@@PtrBullets]
	
	mov edx, [@@Yend]
	sub edx, [@@Ystart]
	;shl edx, SCALARBITSHIFT
	
	mov ecx, [@@Xend]
	sub ecx, [@@Xstart]
	;shl ecx, SCALARBITSHIFT
	
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
	
	;shr ecx, 2	;dividing by 4 to get magnitude of speed vector (k)
	shr ecx, SCALARBITSHIFT + 2
	
	cmp ecx, 0	;protection against division by 0
	je SHORT BulletCannotShoot
	
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
	
	mov ecx, [esi + BULLET.W]
	shr ecx, 1		; divide with of bullet by 2 to get middle to place it in the middle of the tank
	
	mov eax, [@@Xstart]
	
	sub eax, ecx
	mov [esi + BULLET.X], eax		;first element in array is for player
	
	mov ecx, [esi + BULLET.H]
	shr ecx, 1		; divide with of bullet by 2 to get middle to place it in the middle of the tank
	
	mov eax, [@@Ystart]
	
	sub eax, ecx
	mov [esi + BULLET.Y], eax		;first element in array is for player
	
	mov [esi + BULLET.bounces], 0
	mov [esi + BULLET.active], 1
	
	BulletCannotShoot:
	
	ret
ENDP ShootBullet

PROC TankAI
	ARG		@@PtrTanks:dword, @@PtrBullets:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov ecx, [TotalOfTanks]
	
	add edi, [TankSize]
	dec ecx
	
	TanksAILoop:
	mov esi, [@@PtrTanks] ;Ptr to playerTank
	
	cmp [edi + TANK.alive], 0
	je AITankNotAlive
	
	; first check distance to playertank
	; if distance less than 60 (Wtank + Wblock + buffer)
	; then move away from player (sign change)
	; else move towards tank (sign change)
	; check if block is in the way, if so take other option that maximises the attitude (X->Y or Y->X)
	; shoot if distance less than 60 and no block in the way
	; if no direct way to see player shoot halfway distance in biggest delta and shoot boundary
	
	mov eax, [edi + TANK.X]	; AI tank
	sub eax, [esi + TANK.X] ; Player tank
	
	push 1
	cmp eax, 0
	jge DeltaTanksPosX	; abs val
	neg eax
	add esp, 4
	push -1				; remember in wich direction the tank should move
	DeltaTanksPosX:
	
	mov edx, [edi + TANK.Y]	; AI tank
	sub edx, [esi + TANK.Y] ; Player tank
	
	push 1
	cmp edx, 0
	jge DeltaTanksPosY	; abs val
	neg edx
	add esp, 4
	push -1			; remember in wich direction the tank should move
	DeltaTanksPosY:
	
	mov ebx, TANKSPEED			; speed of tank
	add edx, eax				; distance player -> tank
	
	push eax
	
	call randBetweenVal, 10, 80
	cmp eax, 15					; chance that AI Tank moves towards player increases as the player apprauches the player
	pop eax
	jg AITankNoMove
	
	cmp edx, 960				; 60 shl 4
	jg SHORT AIAvoidPlayer		; if distance to player is less than 60 keep moving in same direction
	
	neg ebx
	
	AIAvoidPlayer:
	
	push ebx
	
	sub edx, eax
	
	cmp edx, eax
	jg MoveInYAI
	
	mov ebx, [edi + TANK.velX]		; prevent AI from getting stuck
	xor ebx, [edi + TANK.velY]
	cmp ebx, 0
	je MoveInYAINoTest
	
	MoveInXAI:
	; Delta in X is greater so move in X
	add esp, 8
	pop ebx
	cmp ebx, 0
	jg NegVelXAI
	mov ebx, [esp - 12]
	mov [edi + TANK.velX], ebx
	mov [edi + TANK.velY], 0
	jmp ShootBulletAITank
	
	NegVelXAI:
	mov ebx, [esp - 12]
	neg ebx
	mov [edi + TANK.velX], ebx
	mov [edi + TANK.velY], 0
	jmp ShootBulletAITank
	
	MoveInYAI:
	mov ebx, [edi + TANK.velX]		; prevent AI from getting stuck
	xor ebx, [edi + TANK.velY]
	cmp ebx, 0
	je MoveInXAI
	
	MoveInYAINoTest:
	; Delta in Y is greater so move in Y
	add esp, 4
	pop ebx
	add esp, 4
	cmp ebx, 0
	jg NegVelYAI
	
	mov ebx, [esp - 12]
	mov [edi + TANK.velX], 0
	mov [edi + TANK.velY], ebx
	jmp ShootBulletAITank
	
	NegVelYAI:
	mov ebx, [esp - 12]
	neg ebx
	mov [edi + TANK.velX], 0
	mov [edi + TANK.velY], ebx
	jmp ShootBulletAITank
	
	AITankNoMove:
	add esp, 8
	
	ShootBulletAITank:
	
	add edx, eax
	cmp edx, 2240			;120 shl 4
	jg SHORT AITankNotAlive
	
	mov esi, [@@PtrBullets]
	mov eax, [TotalOfTanks]
	sub eax, ecx
	mul [BulletSize]
	add esi, eax
	
	cmp [esi + BULLET.active], 0
	jg SHORT AITankNotAlive
	
	call randBetweenVal, 10, 80
	cmp eax, 11
	jg SHORT AITankNotAlive
	
	mov eax, [edi + TANK.W]
	shr eax, 1				; Tank center X
	add eax, [edi + TANK.X]
	
	mov ebx, [edi + TANK.H]
	shr ebx, 1				; Tank center Y
	add ebx, [edi + TANK.Y]
	
	push edi
	push ecx
	mov edi, [@@PtrTanks]
	
	mov ecx, [edi + TANK.W]
	shr ecx, 1				; PlayerTank center X
	add ecx, [edi + TANK.X]
	
	mov edx, [edi + TANK.H]
	shr edx, 1				; PlayerTank center Y
	add edx, [edi + TANK.Y]
	
	call ShootBullet, esi, eax, ebx, ecx, edx
	
	pop ecx
	pop edi
	
	AITankNotAlive:

	add edi, [TankSize]
	dec ecx
	cmp ecx, 0
	jg TanksAILoop
	
	ret
ENDP TankAI

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
	
	mov ecx, [TotalOfBlocks]
	
	;----------------------------------------------------------------------------------------------------
	;tank COLISION
	;----------------------------------------------------------------------------------------------------

	mov esi, [@@PtrTanks]
	mov edx, [TotalOfTanks]
	
	
	SetTankCoor:
	mov	edi, [@@PtrBlocks]
	
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
	
	mov ebx, [esi + TANK.Y]
	add ebx, [esi + TANK.velY]
	mov eax, [esi + TANK.X]
	add eax, [esi + TANK.velX]
	
	call colision, 0, 0, SCRWIDTH * 16, SCRHEIGHT * 16, eax, ebx, [esi + TANK.W], [esi + TANK.H], 0
	xor eax, 0Fh
	
	cmp eax, 0
	je SHORT NoColisionWithBoundary
		cmp [esi + TANK.velX], 0
		je speedIsVertB
		jl speedXIsNegB
		;VelX is pos.
		mov eax, SCRWIDTH * 16
		sub eax, [esi + TANK.W]
		dec eax
		
		mov [esi + TANK.X], eax
		
		jmp SetVelZeroB
		
		speedXIsNegB:
		;VelX is neg
		mov [esi + TANK.X], 1
		
		jmp SetVelZeroB
		
		speedIsVertB:
		cmp [esi + TANK.velY], 0
		je SetVelZeroB
		jl speedYIsNegB
		; VelY is pos
		mov eax, SCRHEIGHT * 16
		sub eax, [esi + TANK.H]
		dec eax
		
		mov [esi + TANK.Y], eax
		
		jmp SetVelZeroB
		
		speedYIsNegB:
		;VelY is neg
		mov [esi + TANK.Y], 1
		
		SetVelZeroB:
	
		mov [esi + TANK.velX], 0
		mov [esi + TANK.velY], 0
	
	NoColisionWithBoundary:
	
	;---------------------------------------------------------------------------------------------
	;Tank Tank colisionloop
	;---------------------------------------------------------------------------------------------
	
	mov edi, [@@PtrTanks]
	mov ecx, [TotalOfTanks]
	
	TankTanksColisionLoop:
	cmp ecx, edx
	je SHORT NoColisionWithTank ;same tank so no colision possible
	
	mov ebx, [esi + TANK.Y]
	add ebx, [esi + TANK.velY]
	
	mov eax, [esi + TANK.X]
	add eax, [esi + TANK.velX]

	
	;ARG			@@X1:dword, 	@@Y1:dword, 	@@W1:dword, 	 @@H1:dword, @@X2:dword, @@Y2:dword,@@W2:dword,@@H2:dword, @@BufferSpace:dword
	call colision, [edi + TANK.X], [edi + TANK.Y], [edi + TANK.W], [edi + TANK.H], eax, ebx, [esi + TANK.W], [esi + TANK.H], 0
	;call print, eax
	
	cmp eax, 0
	je SHORT NoColisionWithTank
		mov [esi + TANK.velX], 0
		mov [esi + TANK.velY], 0
	
	NoColisionWithTank:
	
	add edi, [TankSize]
	dec ecx
	cmp ecx, 0
	jg TankTanksColisionLoop
	
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
	jl NoCalcBulletColision
	
	mov eax, [esi + BULLET.X]
	add eax, [esi + BULLET.velX]

	mov ebx, [esi + BULLET.Y]
	add ebx, [esi + BULLET.velY]
	
	;ARG			@@X1:dword, 	@@Y1:dword, 	@@W1:dword, 	 @@H1:dword, @@X2:dword, @@Y2:dword,@@W2:dword,@@H2:dword, @@BufferSpace:dword
	call colision, [edi + BLOCK.X], [edi + BLOCK.Y], [edi + BLOCK.W], [edi + BLOCK.H], eax, ebx, [esi + BULLET.W], [esi + BULLET.H], 0
	;call print, eax
	cmp eax, 0
	je SHORT NoBulletColisionWithBlock
		inc [esi + BULLET.bounces]
	
		mov eax, [edi + BLOCK.X]
		;sub eax, [esi + BULLET.W]
		cmp eax, [esi + BULLET.X]
		jge NegVelXBullet
		
		add eax, [edi + BLOCK.W]
		;sub eax, [esi + BULLET.W]
		;sub eax, [esi + BULLET.W]
		cmp eax, [esi + BULLET.X]
		jle NegVelXBullet
		
		
		mov eax, [edi + BLOCK.Y]
		;add eax, [esi + BULLET.H]
		cmp eax, [esi + BULLET.Y]
		jge NegVelYBullet
		
		add eax, [edi + BLOCK.H]
		;sub eax, [esi + BULLET.H]
		;sub eax, [esi + BULLET.H]
		cmp eax, [esi + BULLET.Y]
		jle NegVelYBullet
		
		NegVelXBullet:
		mov ebx, [esi + BULLET.velX]
		neg ebx
		mov [esi + BULLET.velX], ebx
		jmp NoBulletColisionWithBlock
		
		NegVelYBullet:
		mov ebx, [esi + BULLET.velY]
		neg ebx
		mov [esi + BULLET.velY], ebx
		
	NoBulletColisionWithBlock:
	
	add edi, [BlockSize]
	loop BulletsColisionLoop
	
	mov eax, [esi + BULLET.X]
	add eax, [esi + BULLET.velX]		;calc future position

	mov ebx, [esi + BULLET.Y]
	add ebx, [esi + BULLET.velY]
	
	call colision, 0, 0, SCRWIDTH * 16, SCRHEIGHT * 16, eax, ebx, [esi + BULLET.W], [esi + BULLET.H], 0
	xor eax, 0Fh
	
	cmp eax, 0
	je SHORT NoBulletColisionWithBoundary
		inc [esi + BULLET.bounces]
	
		cmp ebx, [esi + BULLET.H]		;ebx still contains Y future (compare top side of screen (0 + H))
		jl NegVelYBulletBoundary
		mov eax, SCRHEIGHT * 16
		sub eax, [esi + BULLET.H]
		cmp ebx, eax
		jg NegVelYBulletBoundary
		
		mov ebx, [esi + BULLET.X]
		add ebx, [esi + BULLET.velX]
		
		cmp ebx, [esi + BULLET.W]
		jl NegVelXBulletBoundary
		
		mov eax, SCRWIDTH * 16
		sub eax, [esi + BULLET.W]
		cmp ebx, eax
		jg NegVelXBulletBoundary
		
		NegVelXBulletBoundary:
		mov ebx, [esi + BULLET.velX]
		neg ebx
		mov [esi + BULLET.velX], ebx
		jmp NoBulletColisionWithBoundary
		
		NegVelYBulletBoundary:
		mov ebx, [esi + BULLET.velY]
		neg ebx
		mov [esi + BULLET.velY], ebx
	
	NoBulletColisionWithBoundary:
	
	mov eax, [esi + BULLET.X]
	add eax, [esi + BULLET.velX]
	mov [esi + BULLET.X], eax
	
	mov eax, [esi + BULLET.Y]
	add eax, [esi + BULLET.velY]
	mov [esi + BULLET.Y], eax
	
	cmp [esi + BULLET.bounces], 6
	jl NoCalcBulletColision
	mov [esi + BULLET.bounces], 0
	mov [esi + BULLET.active], 0
	
	NoCalcBulletColision:
	
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
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrTanks]
	mov ecx, [TotalOfTanks]
	
	TanksBackgoundLoop:
	;cmp [edi + TANK.alive], 0
	;je SHORT noBackgroundResetNeededTank
	
	mov eax, [edi + TANK.X]
	mov ebx, [edi + TANK.Y]
	mov edx, [edi + TANK.W]
	mov esi, [edi + TANK.H]
	shr eax, SCALARBITSHIFT
	shr ebx, SCALARBITSHIFT
	shr edx, SCALARBITSHIFT
	shr esi, SCALARBITSHIFT
	
	call drawFilledRectangle, eax, ebx, edx, esi, 0
	
	;noBackgroundResetNeededTank:
	add edi, [TankSize]
	loop TanksBackgoundLoop
	
	mov	edi, [@@PtrBullets]
	mov ecx, [TotalOfBullets]
	
	BulletsBackgoundLoop:
	; cannot ignore non active bullets because they may still be drawn
	mov eax, [edi + BULLET.X]
	mov ebx, [edi + BULLET.Y]
	mov edx, [edi + BULLET.W]
	mov esi, [edi + BULLET.H]
	shr eax, SCALARBITSHIFT
	shr ebx, SCALARBITSHIFT
	shr edx, SCALARBITSHIFT
	shr esi, SCALARBITSHIFT
	
	call drawRectangle, eax, ebx, edx, esi, 0
	
	add edi, [BulletSize]
	loop BulletsBackgoundLoop
	
	mov	edi, VMEMADR
	
	xor ecx, ecx
	xor edx, edx
	mov  ax, 0003h  ; get mouse position and buttonstatus
	int  33h        ; -> BX CX DX
	; make everyting above the mouse black
	shr cx, 1
	push ecx
	
	mov ebx, edx
	mov eax, SCRWIDTH/4
	
	xor edx, edx
	mul ebx
	
	mov ecx, eax
	
	xor eax, eax	;background is black (0)
	rep	stosd ;uses stosd (stores whole 4 bytes)
	
	pop ecx
	add edi, ecx
	
	;add edi, SCRWIDTH*17
	
	;add edi, 15
	mov edx, 17
	horizontalMouseLoopClear:
	
		add edi, 8
		mov ecx, (SCRWIDTH - 8)/4
		
		rep stosd
		
		
		cmp edi, (SCRWIDTH*SCRHEIGHT) + VMEMADR
		jg MouseTooLow	; edi is further than last pixel of screen so dont Draw
	
	dec edx
	cmp edx, 0
	jg horizontalMouseLoopClear
	
	mov ecx, SCRWIDTH*SCRHEIGHT
	add ecx, VMEMADR
	
	cmp edi, ecx
	jg MouseTooLow	; edi is further than last pixel of screen so dont Draw
	
	sub ecx, edi
	
	shr ecx, 2 
	
	rep stosd
	
	MouseTooLow:
	
	ret
ENDP selectiveBackgroundFiller

PROC show
	ARG		@@PtrTanks:dword, @@PtrBullets:dword, @@PtrBlock:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrTanks]
	mov ecx, [TotalOfTanks]
	
	TanksShowLoop:
	cmp [edi + TANK.alive], 0
	jne StillAlive
		mov [edi + TANK.col], 25
	StillAlive:
	
	mov eax, [edi + TANK.X]
	mov ebx, [edi + TANK.Y]
	mov edx, [edi + TANK.W]
	mov esi, [edi + TANK.H]
	shr eax, SCALARBITSHIFT
	shr ebx, SCALARBITSHIFT
	shr edx, SCALARBITSHIFT
	shr esi, SCALARBITSHIFT
	
	call drawFilledRectangle, eax, ebx, edx, esi, [edi + TANK.col]
	
	add edi, [TankSize]
	loop TanksShowLoop
	
	
	mov	edi, [@@PtrBlock]
	mov ecx, [TotalOfBlocks]
	
	BlocksShowLoop:
	mov eax, [edi + BLOCK.X]
	mov ebx, [edi + BLOCK.Y]
	mov edx, [edi + BLOCK.W]
	mov esi, [edi + BLOCK.H]
	shr eax, SCALARBITSHIFT
	shr ebx, SCALARBITSHIFT
	shr edx, SCALARBITSHIFT
	shr esi, SCALARBITSHIFT
	
	call drawRectangle, eax, ebx, edx, esi, [edi + BLOCK.col]
	
	add edi, [BlockSize]
	loop BlocksShowLoop
	
	mov	edi, [@@PtrBullets]
	mov ecx, [TotalOfBullets]
	
	BulletsShowLoop:
	cmp [edi + BULLET.active], 0
	je SHORT bulletNotActive
	
	mov eax, [edi + BULLET.X]
	mov ebx, [edi + BULLET.Y]
	mov edx, [edi + BULLET.W]
	mov esi, [edi + BULLET.H]
	shr eax, SCALARBITSHIFT
	shr ebx, SCALARBITSHIFT
	shr edx, SCALARBITSHIFT
	shr esi, SCALARBITSHIFT
	
	call drawRectangle, eax, ebx, edx, esi, [edi + BULLET.col]
	
	bulletNotActive:
	add edi, [BulletSize]
	loop BulletsShowLoop
	
	ret
ENDP show

PROC endConditionTank
	ARG 	@@PtrTanks:dword
	USES 	edi, ebx, ecx
	; returns a value in eax; test if eax = 10000(bin) then player wins, if eax < 10000(bin) ennemies win
	
	mov edi, [@@PtrTanks]
	mov ebx, [TankSize]
	mov ecx, [TotalOfTanks]
	
	xor eax, eax
	
	TanksAliveTestLoop:
	or eax, [edi + TANK.alive]
	shl eax, 1
	
	add edi, ebx
	loop TanksAliveTestLoop
	
	ret
ENDP endConditionTank

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
	
	mov edx, offset Blocks
	
	call initiateBlocks, edx
	
	mov edi, offset Tanks
	mov eax, offset TankPosInitArr
	call initiateTanks, edi, eax
	
	
	NoMouse:
	mov  ax, 0000h  ; reset mouse
	int  33h        ; -> AX BX
	cmp  ax, 0FFFFh
	jne  NoMouse
	mov  ax, 0001h  ; show mouse
	int  33h
	
	
	mov ebx, offset Bullets
	
	mov ecx, 5000
	drawLoop:
	
	call selectiveBackgroundFiller, edi, ebx
	
	call inputFromPlayer, edi, ebx
	
				;@@PtrTanks:dword, @@PtrBullets:dword
	call TankAI, edi, ebx
	
	call moveEntities, edi, edx, ebx
	
	call show, edi, ebx, edx
	
	call	wait_VBLANK, 1
	
	call endConditionTank, edi
	
	cmp eax, 32
	je EndTankGamePlayerWin
	jl EndTankGamePlayerLose
	
	loop drawLoop
	
	EndTankGamePlayerWin:
	call setVideoMode, 03h	;back to text
	
	mov ah, 09h
	mov edx, offset WinMsg
	int 21h
	
	jmp SHORT EndTankGame
	
	EndTankGamePlayerLose:
	call setVideoMode, 03h	;back to text
	
	mov ah, 09h
	mov edx, offset LoseMsg
	int 21h
	
	EndTankGame:
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
	W		dd 48	; 3 shl 4
	H		dd 48	; 3 shl 4
	bounces	dd 0
	active 	dd 0
	col 	dd 3
ENDS BULLET

STRUC TANK
    X		dd 160
	Y		dd 100
	velX 	dd 0
	velY 	dd 0
	W		dd 23
	H		dd 20
	alive 	dd 1
	col 	dd 1
ENDS TANK

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
randSeed		dd			2003630

Tanks			TANK		5	dup	(<,,,,,,,>)
TankSize	 	dd 			32
TotalOfTanks	dd			5

TankPosInitArr	dd				160, 150, 	0, 0, 	295, 0, 	0, 180, 	295, 180

Bullets 		BULLET		5	dup	(<,,,,,,,>)
BulletSize	 	dd 			36
TotalOfBullets	dd			5

Blocks			BLOCK		4	dup	(<,,,,>)
BlockSize	 	dd 			20
TotalOfBlocks	dd			4

WinMsg			db 	"You WON!", 13, 10, '$'
LoseMsg			db 	"You LOST", 13, 10, '$'

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END start
