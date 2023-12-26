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

INCLUDE "generic.inc"

INCLUDE "biker.inc"

; compile-time constants (with macros)
VMEMADR 		EQU 0A0000h	; video memory address
SCRWIDTH 		EQU 320		; screen witdth
SCRHEIGHT 		EQU 200		; screen height
BACKGROUNDCOL 	EQU 0		; background color
BIKERSPEED 		EQU 1		; Speed of Biker
BIKERW			EQU 5
BIKERH			EQU 11

BORDERCOLOR		EQU 12
INVISIBLECOL	EQU 33

IMGSIZE EQU BIKERW*BIKERH

RAND_A = 1103515245
RAND_C = 12345

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG

MACRO HideMouse
	push eax
	mov  ax, 0002h  ; hide mouse
	int  33h
	pop eax
ENDM HideMouse

PROC rotateIMG	; performs a matrix transpose on the sprite (spites are symmetrical in both axis)
	ARG	 @@OGIMGPtr:dword, @@IMGPtr:dword, @@w:dword, @@h:dword
	USES esi, edi, ecx, eax, edx, ebx
	
	mov edi, [@@IMGPtr]
	mov esi, [@@OGIMGPtr]
	mov ecx, [@@h]
	
	mov ebx, edi
	
	HorizontalLoop:
	mov edx, ecx
	mov ecx, [@@w]
	
	VericalLoop:
	mov al, [esi]
	mov [edi], al
	
	inc esi
	add edi, [@@h]
	loop VericalLoop
	
	add ebx, 1
	mov edi, ebx
	
	mov ecx, edx
	loop HorizontalLoop
	ret	
ENDP rotateIMG

PROC ReplaceRectangleDWORD		; replaceses col by another col, prevents to draw over a color from another biker/border to avoid gaps in line
	ARG 	@@PtrStartScreen:dword, @@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@OGCol: dword, @@newCol: dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	
	mov ecx, [@@x0]
	shl ecx, 2
	; Compute the index of the rectangle's top left corner
	mov eax, [@@y0]
	mov edx, SCRWIDTH * 4
	mul edx ;multiply EAX by EDX, store in EAX
	add	eax, ecx

	; Compute top left corner address
	mov edi, [@@PtrStartScreen]
	add edi, eax
	
	; Plot the top horizontal edge.
	mov edx, [@@w]	; store width in edx for later reuse
	mov	ecx, edx
	shl edx, 2
	
	mov ebx, [@@h]
	;shl ebx, 2
	
	mov	esi, [@@OGCol]
	mov eax, [@@newCol]
	
	@@startRectDraw:
	cmp [edi], esi
	jne DontChangeCol
	mov [edi], eax
	
	DontChangeCol:
	add edi, 4
	loop @@startRectDraw
	
	;rep stosd
	
	sub edi, edx		; reset edi to left-top corner
	add edi, SCRWIDTH * 4
	mov ecx, edx
	shr ecx, 2
	
	dec ebx
	cmp ebx, 0
	jg @@startRectDraw
	
	ret
ENDP ReplaceRectangleDWORD

PROC initiateBikers
	ARG		@@PtrBikers:dword, @@PtrInitArray:dword, @@PtrVelInitArray:dword, @@PtrPlayGround:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrBikers]
	mov esi, [@@PtrInitArray]
	mov edx, [@@PtrVelInitArray]
	mov ebx, [BikerSize]
	mov ecx, [TotalOfBikers]
	
	BikersInitLoop:		; reset biker structs
	
	mov eax, [esi]
	mov [edi + BIKER.X], eax		; read position of biker in array
	add esi, 4
	
	mov eax, [esi]
	mov [edi + BIKER.Y], eax
	add esi, 4
	
	mov eax, [edx]
	mov [edi + BIKER.velX], eax		; read start speed of biker in array
	add edx, 4
	
	mov eax, [edx]
	mov [edi + BIKER.velY], eax
	add edx, 4
	
	cmp eax, 0
	je BikerIsHorizontal
	mov [edi + BIKER.W], BIKERW
	mov [edi + BIKER.H], BIKERH		; set right shape for specific start speed
	
	jmp EndBikerRotationInit
	BikerIsHorizontal:
	mov [edi + BIKER.W], BIKERH
	mov [edi + BIKER.H], BIKERW
	
	EndBikerRotationInit:
	
	mov [edi + BIKER.alive], 1
	
	mov [edi + BIKER.col], ecx
	
	add edi, ebx
	loop BikersInitLoop
	
	mov edi, [@@PtrPlayGround]		; reset PlayGround to black (background)
	xor eax, eax
	mov ecx, SCRWIDTH*SCRHEIGHT
	rep stosd			; reset PlayGround
	
	
	mov eax, BORDERCOLOR			; draw the border
	mov ecx, SCRWIDTH
	mov edi, [@@PtrPlayGround]
	
	rep stosd
	
	;dec edi
	
	mov eax, BORDERCOLOR
	mov ecx, SCRHEIGHT - 2
	
	LeftAndRightEdgeLoop:
	mov [edi], eax
	
	add edi, SCRWIDTH * 4
	
	sub edi, 4
	mov [edi], eax
	add edi, 4
	
	loop LeftAndRightEdgeLoop
	
	mov eax, BORDERCOLOR
	mov ecx, SCRWIDTH
	
	rep stosd
	
	ret
ENDP initiateBikers

PROC rotateBikerUp
	ARG		@@PtrBiker:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrBiker]
	
	mov eax, BIKERW
	shr eax, 1
	neg eax
	
	cmp [edi + BIKER.velX], 0		; depending on place of line different translation
	jg BikerWasGoingRightU
	add eax, BIKERH
	BikerWasGoingRightU:
	
	add eax, [edi + BIKER.X]
	mov [edi + BIKER.X], eax
	
	mov eax, BIKERW				; simple matrix rotation with translation
	shr eax, 1
	sub eax, BIKERH
	add eax, [edi + BIKER.Y]
	mov [edi + BIKER.Y], eax
	
	
	mov [edi + BIKER.velX], 0
	mov [edi + BIKER.velY], -BIKERSPEED
	mov [edi + BIKER.W], BIKERW
	mov [edi + BIKER.H], BIKERH
	
	ret
ENDP rotateBikerUp

PROC rotateBikerDown
	ARG		@@PtrBiker:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrBiker]
	
	mov eax, BIKERW
	shr eax, 1
	neg eax
	
	cmp [edi + BIKER.velX], 0	; depending on place of line different translation
	jg BikerWasGoingRightD
	add eax, BIKERH
	BikerWasGoingRightD:
	
	add eax, [edi + BIKER.X]
	mov [edi + BIKER.X], eax
	
	mov eax, BIKERW			; matrix rotation and translation
	shr eax, 1
	;sub eax, BIKERH
	add eax, [edi + BIKER.Y]
	mov [edi + BIKER.Y], eax
	
	mov [edi + BIKER.velX], 0			; set new speed and shape
	mov [edi + BIKER.velY], BIKERSPEED
	mov [edi + BIKER.W], BIKERW
	mov [edi + BIKER.H], BIKERH
	
	ret
ENDP rotateBikerDown

PROC rotateBikerRight
	ARG		@@PtrBiker:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrBiker]
	
	mov eax, BIKERW
	shr eax, 1
	add [edi + BIKER.X], eax	; simple matrix rotation with translation
	
	mov eax, BIKERW
	shr eax, 1
	neg eax
	
	cmp [edi + BIKER.velY], 0	; depending on place of line different translation
	jg BikerWasGoingDownR
	add eax, BIKERH
	BikerWasGoingDownR:
	
	add [edi + BIKER.Y], eax
	
	mov [edi + BIKER.velX], BIKERSPEED	; set new speed and shape
	mov [edi + BIKER.velY], 0
	mov [edi + BIKER.W], BIKERH
	mov [edi + BIKER.H], BIKERW
	
	ret
ENDP rotateBikerRight

PROC rotateBikerLeft	; rotates the biker left arround the end of the line
	ARG		@@PtrBiker:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrBiker]
	
	mov eax, BIKERW
	shr eax, 1
	sub eax, BIKERH
	inc eax
	add [edi + BIKER.X], eax		; simple matrix rotation with translation
	
	mov eax, BIKERW
	shr eax, 1
	neg eax
	
	cmp [edi + BIKER.velY], 0	; depending on the direction of the biker the line is at another place so different translation
	jg BikerWasGoingDownL
	add eax, BIKERH
	BikerWasGoingDownL:
	
	add eax, [edi + BIKER.Y]
	mov [edi + BIKER.Y], eax
	
	mov [edi + BIKER.velX], -BIKERSPEED		; set he new speed and shape
	mov [edi + BIKER.velY], 0
	mov [edi + BIKER.W], BIKERH
	mov [edi + BIKER.H], BIKERW
	
	ret
ENDP rotateBikerLeft

;modifies the speed of the ennemy Bikers
PROC inputFromPlayer
	ARG		@@PtrPlayerBiker:dword
	USES 	ebx, ecx, edx, edi, esi
	
	mov ah, 01h ; function 01h (check if key is pressed)
	int 16h ; call keyboard BIOS
	jz SHORT @@notpressed ;if key not pressed than there is a 0 flag ; SHORT means short jump (+127 or -128 bytes) solves warning message
	
	mov ah, 00h ;get key from buffer (ascii code in al)
	int 16h
	
	cmp	al, 001Bh	; ='esc' checks to see if we ditch program
	jne  noEXIT
	mov eax, 2
	jmp EXITGAME
	noEXIT:
	
	mov edi, [@@PtrPlayerBiker]
	
	cmp al, 'z' ; up
	jne SHORT @@notup
	cmp [edi + BIKER.velY], 0
	jne @@notpressed
	
	call rotateBikerUp, edi
	
	jmp @@notpressed
	
	@@notup:
	cmp al, 'q' ; left
	jne SHORT @@notleft
	cmp [edi + BIKER.velX], 0
	jne @@notpressed
	
	call rotateBikerLeft, edi
	
	jmp SHORT @@notpressed
	
	@@notleft:
	cmp al, 's' ; down
	jne SHORT @@notdown
	cmp [edi + BIKER.velY], 0
	jne SHORT @@notpressed
	
	call rotateBikerDown, edi
	
	jmp SHORT @@notpressed
	
	@@notdown:
	cmp al, 'd' ; right
	jne SHORT @@notpressed
	cmp [edi + BIKER.velX], 0
	jne SHORT @@notpressed
	
	call rotateBikerRight, edi
	;@@notright:
	
	@@notpressed:
	
	xor eax, eax
	
	EXITGAME:
	
	ret
ENDP inputFromPlayer

PROC BikerAI
	ARG		@@PtrBikers:dword, @@PtrPlayGround:dword
	USES 	eax, ebx, ecx, edx, edi, esi

	mov edi, [@@PtrBikers]
	mov ecx, [TotalOfBikers]
	mov ebx, [BikerSize]
	
	add edi, [BikerSize]
	dec ecx
	
	mov esi, [@@PtrBikers] ;Ptr to playerBiker
	
	BikerAILoop:
	cmp [edi + BIKER.alive], 1
	jne AIBikerNotAlive
	
	; push ecx	; deprecated code to make the biker target the closest biker instead of only the player (made game to easy)
		
	; mov ecx, [TotalOfBikers]
	; mov edx, [@@PtrBikers]
		
	; push edx		; Player is default closest Biker
	; push SCRWIDTH*SCRHEIGHT
	
	; FindTargetAILoop:	; find closest tank
		; cmp edi, edx	; edx loops through differnet Bikers
		; je ThisBikerIsFurther	; dont take same Biker
		; cmp [edx + BIKER.alive], 1
		; jne ThisBikerIsFurther	; dont check distance to dead Biker
			
		; mov eax, [edi + BIKER.X]
		; sub eax, [edx + BIKER.X]
			
		; cmp eax, 0
		; jg EAXIsPos1
		; neg eax
		; EAXIsPos1:
		
		; mov esi, [edi + BIKER.Y]
		; sub esi, [edx + BIKER.Y]
		
		; cmp esi, 0
		; jg ESIIsPos2
		; neg esi
		; ESIIsPos2:
		
		; add eax, esi
		
		; cmp [esp], eax
		; jl ThisBikerIsFurther
		; mov [esp], eax
		; mov [esp + 4], edx
		; ThisBikerIsFurther:
		
		; add edx, ebx
	; loop FindTargetAILoop
	
	; pop edx		; edx contains smallest distance
	
	; pop esi		; esi conatains adress to closest Biker
	
	; pop ecx
	
	
	
	mov eax, [edi + BIKER.X]	; AI Biker
	sub eax, [esi + BIKER.X] 	; Target Biker
	
	cmp eax, 0
	jge DeltaBikerPosX	; abs val
	neg eax
	DeltaBikerPosX:
	
	mov edx, [edi + BIKER.Y]
	sub edx, [esi + BIKER.Y]
	
	cmp edx, 0
	jg EDXIsPos2
	neg edx
	EDXIsPos2:
	
	;sub edx, eax	; edx contains Ydelta, eax Xdelta
	
	push [edi + BIKER.H]
	push [edi + BIKER.W]		; store the values of the struct to reset the biker if necessary
	push [edi + BIKER.velY]
	push [edi + BIKER.velX]
	push [edi + BIKER.Y]
	push [edi + BIKER.X]
	
	push eax
	call randBetweenVal, 10, 80
	cmp eax, 15		; chance that AI Biker moves towards player
	pop eax
	jg ColisionTestRandomBiker
	
	
	jmp skipIntermadiatejmp
	BikerAILoopIntermadiate:
	jmp BikerAILoop
	skipIntermadiatejmp:
	
	cmp edx, eax
	mov edx, 0 ; dont trigger 0-flag
	jg MoveInYAI
	
	MoveInXAI:
	
	; Delta in X is greater so move in X
	cmp [edi + BIKER.velX], 0
	jne SHORT TestedXDirection		; if velX is not 0 it means were eiter moving in the right direction or were moving in an impossible direction
	
	mov eax, [edi + BIKER.X]
	cmp [esi + BIKER.X], eax
	jl NegVelXAI
	
	PosVelXAI:
	test edx, 1
	jnz NegVelXAI
	or edx, 1
	call rotateBikerRight, edi
	jmp SHORT ColisionTest
	
	NegVelXAI:
	test edx, 2
	jnz TestedXDirection
	or edx, 2
	call rotateBikerLeft, edi
	jmp ColisionTest
	
	MoveInYAI:
	; Delta in Y is greater so move in Y
	or edx, 16	; mov in Y flag
	cmp [edi + BIKER.velY], 0
	jne TestedYDirection		; if velX is not 0 it means were eiter moving in the right direction or were moving in an impossible direction
	
	mov eax, [edi + BIKER.Y]
	cmp [esi + BIKER.Y], eax
	jl NegVelYAI
	
	PosVelYAI:
	test edx, 4
	jnz NegVelYAI
	or edx, 4
	call rotateBikerDown, edi
	jmp ColisionTest
	
	NegVelYAI:
	test edx, 8
	jnz TestedYDirection
	or edx, 8
	call rotateBikerUp, edi
	jmp ColisionTest
	
	TestedXDirection:
	or edx, 3	; 1 + 2
	jmp ColisionTest
	
	TestedYDirection:
	or edx, 12	; 4 + 8
	jmp ColisionTest
	
	ColisionTestRandomBiker:
	xor edx, edx
	
	ColisionTest:
	
	mov eax, [edi + BIKER.velX]
	;shl eax, 1
	add eax, [edi + BIKER.X]
	
	push edx
	
	mov edx, [edi + BIKER.velY]
	;shl edx, 1
	add edx, [edi + BIKER.Y]
	
	call checkColorsInRectangle, [@@PtrPlayGround], eax, edx, [edi + BIKER.W], [edi + BIKER.H]	; test if this orientation does not contain line
	
	cmp eax, 0
	jne SHORT skipBikerBikerColision
	
	push ecx
	mov ecx, [TotalOfBikers]
	push esi	;esi already on first biker
	
	;dec ecx
	;add esi, ebx
	
	push eax	; store result of line collision
	
	mov edx, [edi + BIKER.velY]
	shl edx, 1
	add edx, [edi + BIKER.Y]
	
	otherBikersCollisionLoop:
		cmp edi, esi
		je SHORT dontTestSameBikerCollision
		cmp [esi + BIKER.alive], 0
		je SHORT dontTestSameBikerCollision	; biker long dead so no colision possible
			mov eax, [edi + BIKER.velX]
			shl eax, 1
			add eax, [edi + BIKER.X]
			push eax
			
			call collision, eax, edx, [edi + BIKER.W], [edi + BIKER.H], [esi + BIKER.X], [esi + BIKER.Y], [esi + BIKER.W], [esi + BIKER.H], 0
			or [esp + 4], eax	; store every colision result in ebx
			
			pop eax
			call collision, [esi + BIKER.X], [esi + BIKER.Y], [esi + BIKER.W], [esi + BIKER.H], eax, edx, [edi + BIKER.W], [edi + BIKER.H], 0
			or [esp], eax	; store every colision result in ebx
				
		dontTestSameBikerCollision:
		add esi, ebx
	loop otherBikersCollisionLoop
	pop eax
	pop esi
	pop ecx
	
	skipBikerBikerColision:
	pop edx
	
	;jmp SHORT SetForNextBiker
	
	cmp eax, 0		; returns 0 if no color in rect
	je SHORT SetForNextBiker	; jmp to the end (biker is not dead)
	
	; if here: there is a line in the chosen orientation
	
	mov eax, [esp]			; reset everything because of rotate
	mov [edi + BIKER.X], eax
	mov eax, [esp + 4]
	mov [edi + BIKER.Y], eax
	mov eax, [esp + 8]
	mov [edi + BIKER.velX], eax
	mov eax, [esp + 12]
	mov [edi + BIKER.velY], eax
	mov eax, [esp + 16]
	mov [edi + BIKER.W], eax
	mov eax, [esp + 20]
	mov [edi + BIKER.H], eax
	
	cmp edx, 31		;if every possibility has been tested this biker is done
	je SetForNextBiker
	
	; choose new direction
	
	; edx contains the chosen decisions
	; if edx == 3 => X not possible anymore (got refused in = 0 test || every possibility in X used)
	; -> jump to test Y
	
	; if edx == 28 => there is no possibility in Y	(got refused in = 0 test || every possibility in Y used)
	; -> jump to test X
	
	; if edx < 3 => there is another possibility in X but first test Y
	; -> jump to test Y
	
	; if here: x != 3 != 28 > 3
	; if edx < 28 => there is another possibility in Y but first test X
	; if edx and 3 zero => jmp to test X
	; else: jump to PosVelYAI
	
	; if edx < 31 => there is another possibility in X
	; -> jump to PosVelXAI
	
	cmp edx, 3
	je MoveInYAI
	
	cmp edx, 28
	je MoveInXAI
	
	cmp edx, 3
	jl MoveInYAI
	
	cmp edx, 28
	jg PosVelXAI
	
	test edx, 3
	jz MoveInXAI
	
	jmp PosVelYAI
	
	SetForNextBiker:
	
	add esp, 24
	
	AIBikerNotAlive:
	
	add edi, ebx
	dec ecx
	cmp ecx, 0
	jg BikerAILoopIntermadiate
	
	ret
ENDP BikerAI

PROC checkColorsInRectangle
	ARG 	@@PlayGroundPtr:dword, @@x0:dword, @@y0:dword, @@w:dword, @@h:dword
	USES 	ebx, ecx, edx, edi, esi
	
	; return in eax 0 if only color was background (0)
	
	mov ecx, [@@x0]
	shl ecx, 2
	; Compute the index of the rectangle's top left corner
	mov eax, [@@y0]
	mov edx, SCRWIDTH * 4
	mov esi, edx
	mul edx ;multiply EAX by EDX, store in EAX
	add	eax, ecx

	; Compute top left corner address
	mov edi, [@@PlayGroundPtr]
	add edi, eax
	
	; Plot the top horizontal edge.
	mov edx, [@@w]	; store width in edx for later reuse
	mov	ecx, edx
	shl edx, 2
	
	mov ebx, [@@h]
	;shl ebx, 2
	
	xor	eax, eax
	
	@@checkRect:
		or eax, [edi]
		add edi, 4
		loop @@checkRect
	
	sub edi, edx		; reset edi to left-top corner
	add edi, esi
	mov ecx, edx
	shr ecx, 2
	
	dec ebx
	
	cmp ebx, 0
	jg @@checkRect
	
	ret
ENDP checkColorsInRectangle

PROC drawLine
	ARG 	@@PlayGroundPtr:dword, @@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@VelX:dword, @@VelY:dword, @@col:dword
	USES 	eax, ebx, ecx, edx, edi
	
	mov ecx, [@@x0]
	shl ecx, 2
	;Compute the index of the rectangle's top left corner
	mov eax, [@@y0]
	mov edx, SCRWIDTH * 4
	mov ebx, edx
	mul edx ;multiply EAX by EDX, store in EAX
	add	eax, ecx

	;Compute top left corner address
	mov edi, [@@PlayGroundPtr]
	add edi, eax
	
	mov eax, [@@h]
	shr eax, 1	;div by 2 to get center but also mul by 4 to work with dwords
	mul ebx	;horizontal center of bike in eax
	
	cmp [@@VelX], 0
	je VelIsVert
	jg VelXIsPos
	add edi, eax
	mov eax, [@@w]
	shl eax, 2
	add edi, eax	; right of bike
	jmp EndDrawLine
	
	VelXIsPos:
	add edi, eax
	sub edi, 4			; left of bike
	jmp EndDrawLine
	
	VelIsVert:
	mov eax, [@@w]
	shr eax, 1		;div by 2 to get center but also mul by 4 to work with dwords
	shl eax, 2		; if just shl 1 there is a residual bit on the first place that gives wrong byte to write to
	add edi, eax	;top of bike
	
	cmp [@@VelY], 0
	je DontDrawLine
	jl VelYIsNeg
	sub edi, ebx	;top of bike
	;sub edi, ebx
	jmp EndDrawLine
	
	VelYIsNeg:
	mov eax, [@@h]
	inc eax
	mul ebx
	add edi, eax	; bottom of bike
	
	EndDrawLine:
	
	mov eax, [@@col]
	mov [edi], eax
	
	DontDrawLine:
	
	ret
ENDP drawLine

PROC moveBiker
	ARG		@@PtrBikers:dword, @@PtrPlayGround:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	; each bike has its own color different from the background, check if color on wich the bike will be drawn background is
	; if not then kill biker else move biker forward
	
	mov edi, [@@PtrBikers]
	mov esi, [@@PtrPlayGround]
	mov edx, [BikerSize]
	mov ecx, [TotalOfBikers]
	
	BikerColisionLoop:
		cmp [edi + BIKER.alive], 0
		je SHORT skipBikerDead
		
		mov eax, [edi + BIKER.velX]
		mov ebx, [edi + BIKER.velY]
		add eax, [edi + BIKER.X]
		add ebx, [edi + BIKER.Y]
		call checkColorsInRectangle, esi, eax, ebx, [edi + BIKER.W], [edi + BIKER.H]		; only the inside pixels
		
		;xor eax, eax
		cmp eax, 0 ; if eax is not equal to 0 then there is a color in the future rectangle so biker must die
		je skipBikerDead
		
		mov [edi + BIKER.alive], 2		; 2 means that the biker has to be erased
		skipBikerDead:
		
		cmp [edi + BIKER.alive], 0
		je BikerLongDead
		
		mov eax, [edi + BIKER.X]
		add eax, [edi + BIKER.velX]
		
		;mov ebx, [edi + BIKER.Y]
		;add ebx, [edi + BIKER.velY]
		
		mov [edi + BIKER.X], eax
		mov [edi + BIKER.Y], ebx
		
		
		call ReplaceRectangleDWORD, esi, eax, ebx, [edi + BIKER.W], [edi + BIKER.H], 0, INVISIBLECOL
		call drawLine, esi, eax, ebx, [edi + BIKER.W], [edi + BIKER.H], [edi + BIKER.velX], [edi + BIKER.velY], [edi + BIKER.col]
		
		BikerLongDead:
	
	add edi, edx
	loop BikerColisionLoop
	
	mov edi, [@@PtrBikers]
	mov ecx, [TotalOfBikers]
	
	BikerBikerColisionLoop:
		cmp [edi + BIKER.alive], 1
		jne SHORT DontNeedToTestForDeath
		
		xor ebx, ebx
		
		push ecx
		mov ecx, [TotalOfBikers]
		mov esi, [@@PtrBikers]
		
		otherBikersLoop:
			cmp edi, esi
			je SHORT dontTestSameBiker
			cmp [esi + BIKER.alive], 0
			je SHORT dontTestSameBiker	; biker long dead so no colision possible
				
				;@@X1:dword, @@Y1:dword, @@W1:dword, @@H1:dword, @@X2:dword, @@Y2:dword, @@W2:dword, @@H2:dword, @@BufferSpace:dword
				call collision, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], [esi + BIKER.X], [esi + BIKER.Y], [esi + BIKER.W], [esi + BIKER.H], 0
				or ebx, eax	; store every colision result in ebx
				
				call collision, [esi + BIKER.X], [esi + BIKER.Y], [esi + BIKER.W], [esi + BIKER.H], [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], 0
				or ebx, eax	; store every colision result in ebx
				
			dontTestSameBiker:
			add esi, edx
		loop otherBikersLoop
		pop ecx

		cmp ebx, 0 ; if eax is not equal to 0 then there is a color in the future rectangle so biker must die
		je DontNeedToTestForDeath	; no collision with other Biker
			mov [edi + BIKER.alive], 2
			
		DontNeedToTestForDeath:
	
		add edi, edx
	loop BikerBikerColisionLoop
	
	ret
ENDP moveBiker

PROC EraseLine
	ARG 	@@PlayGroundPtr:dword, @@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@VelX:dword, @@VelY:dword, @@col:dword
	USES 	eax, ebx, ecx, edx, edi
	
	
	mov ecx, [@@x0]
	shl ecx, 2
	;Compute the index of the rectangle's top left corner (in dwords)
	mov eax, [@@y0]
	mov edx, SCRWIDTH * 4
	mov ebx, edx
	mul edx ;multiply EAX by EDX, store in EAX
	add	eax, ecx

	;Compute top left corner address
	mov edi, [@@PlayGroundPtr]
	add edi, eax
	
	; calculate where the end of the line should be
	mov eax, [@@h]
	shr eax, 1	;div by 2 to get center but also mul by 4 to work with dwords
	mul ebx	;horizontal center of bike in eax
	
	cmp [@@VelX], 0
	je VelLineIsVert
	jg VelXLineIsPos
	add edi, eax
	add edi, 4
	mov eax, [@@w]
	shl eax, 2
	add edi, eax	; right of bike
	jmp FoundEndLine
	
	VelXLineIsPos:
	add edi, eax
	sub edi, 4			; left of bike
	jmp FoundEndLine
	
	VelLineIsVert:
	mov eax, [@@w]
	shr eax, 1		;div by 2 to get center but also mul by 4 to work with dwords
	shl eax, 2		; if just shl 1 there is a residual bit on the first place that gives wrong byte to write to
	add edi, eax	;top of bike
	
	cmp [@@VelY], 0
	jl VelYLineIsNeg
	sub edi, ebx	;top of bike
	jmp FoundEndLine
	
	VelYLineIsNeg:
	mov eax, [@@h]
	inc eax
	mul ebx
	add edi, eax	; bottom of bike
	
	FoundEndLine:
	
	
	mov eax, [@@col]	; once end of line is found check if that pix is of right color
	cmp [edi], eax
	;jne SHORT EndLineReset
	jne dontRemoveThatCol	; if we dont have the right color it may be that the biker rotated wich gave the wrong address so dont remove that pixel but look for the line

	ResetPixelOfLine:
	xor ebx, ebx		; mov 0 (background) to the place where the line was
	mov [edi], ebx
	
	dontRemoveThatCol:

	cmp[edi - 4], eax	; check surrounding pixels to find the line
	jne LineIsNotLeft
	sub edi, 4
	jmp ResetPixelOfLine
	LineIsNotLeft:

	cmp[edi + 4], eax
	jne LineIsNotRight
	add edi, 4
	jmp ResetPixelOfLine
	LineIsNotRight:

	cmp[edi - 4 * SCRWIDTH], eax
	jne LineIsNotTop
	sub edi, 4 * SCRWIDTH
	jmp ResetPixelOfLine
	LineIsNotTop:

	cmp[edi + 4 * SCRWIDTH], eax
	jne LineIsNotBottom
	add edi, 4 * SCRWIDTH
	jmp ResetPixelOfLine
	LineIsNotBottom:
	
	;; two time further (to solve problem where you had line staying because of the fast turnin of the AI) (didn't solve every edge case so used loop in show to remove residual)
	cmp[edi - 8], eax
	jne LineIsNotLeft2
	sub edi, 8
	jmp ResetPixelOfLine
	LineIsNotLeft2:

	cmp[edi + 8], eax
	jne LineIsNotRight2
	add edi, 8
	jmp ResetPixelOfLine
	LineIsNotRight2:

	cmp[edi - 8 * SCRWIDTH], eax
	jne LineIsNotTop2
	sub edi, 8 * SCRWIDTH
	jmp ResetPixelOfLine
	LineIsNotTop2:

	cmp[edi + 8 * SCRWIDTH], eax
	jne LineIsNotBottom2
	add edi, 8 * SCRWIDTH
	jmp ResetPixelOfLine
	LineIsNotBottom2:
	

	;EndLineReset:	; if we find no other pixel with line color end the proc
	
	ret
	
ENDP EraseLine

PROC selectiveBackgroundFiller
	ARG		@@PtrBikers:dword, @@PtrPlayGround:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrBikers]
	mov esi, [@@PtrPlayGround]
	mov ebx, [BikerSize]
	mov edx, [TotalOfBikers]
	
	BikersBackgoundLoop:
	mov eax, [edi + BIKER.alive]
	
	cmp eax, 2
	jne SHORT NoLineReset
		
		;if line reset:
		; find pixel where line was drawn: check if color equal to that of dead biker
		; check surrounding pixels
		; if all checks return false every pixel of line has been erased
		; else repeat
		
		; afterwards erase for the last time the biker and set alive status to 0 such that we dont draw over him anymore
		
		
		call ReplaceRectangleDWORD, esi, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], INVISIBLECOL, 0
		call EraseLine, esi, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], [edi + BIKER.velX], [edi + BIKER.velY], [edi + BIKER.col]
		
		
		;call drawFilledRectangle, 0, 0, SCRWIDTH, SCRHEIGHT, 0
		
		mov [edi + BIKER.velX], 0
		mov [edi + BIKER.velY], 0
		
		xor eax, eax
		mov [edi + BIKER.alive], eax
	NoLineReset:
	
	cmp eax, 1
	jne DontResetRect
	call ReplaceRectangleDWORD, esi, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], INVISIBLECOL, 0
	
	DontResetRect:
	
	
	add edi, ebx
	dec edx
	cmp edx, 0
	jg BikersBackgoundLoop
	
	ret
ENDP selectiveBackgroundFiller

PROC show
	ARG		@@PtrPlayGround:dword, @@PtrBiker:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov esi, [@@PtrPlayGround]
	mov edi, VMEMADR
	mov ecx, SCRWIDTH*SCRHEIGHT
	mov ebx, [TotalOfBikers]
	
	
	mov edx, [@@PtrBiker]
	
	BikersShowLoop:
	mov eax, [esi]; move color to eax
	
	; remove residual lines if not yet removed
	;jmp NoColorChange ; debugging
	cmp al, 0	; if color is 0 (background) or BORDERCOLOR dont change anything if color is INVISIBLECOL then dont copy
	je NoColorChange
	cmp al, BORDERCOLOR
	je NoColorChange
	cmp al, INVISIBLECOL
	je EndPixelUpdate
	
	cmp eax, ebx
	je PlayerColor	; if color is first color -> player -> player color
	
	; remove residual lines if not yet removed
	sub eax, [TotalOfBikers]	; calculate the address of the biker to check if dead
	neg eax
	push edx
	mul [BikerSize]
	pop edx
	 
	cmp [edx + eax + BIKER.alive], 1	; if biker still alive just show right color
	je ShowPix
	xor eax, eax		; if biker dead remove that color from both the playground and the screen
	mov [esi], eax
	mov [edi], al
	ShowPix:
	
	mov al, 14
	mov [edi], al		; Ennemy color
	jmp EndPixelUpdate
	
	PlayerColor:
	mov al, 1
	mov [edi], al		; Player color
	jmp EndPixelUpdate
	
	NoColorChange:
	mov [edi], al
	
	EndPixelUpdate:
	
	;mov [edi], al
	
	inc edi
	add esi, 4
	loop BikersShowLoop
	
	mov edx, [@@PtrBiker]	; draw sprites where bikers are
	mov eax, [BikerSize]
	mov ecx, [TotalOfBikers]

	; show player
	cmp [edx + BIKER.velX], 0
	je PlyVelIsVertShow
		call DrawIMG, offset playerIMGH, [edx + BIKER.X], [edx + BIKER.Y], BIKERH, BIKERW
		jmp showEnnemyBikers
	PlyVelIsVertShow:
		call DrawIMG, offset playerIMG, [edx + BIKER.X], [edx + BIKER.Y], BIKERW, BIKERH
		
	showEnnemyBikers:
	
	add edx, eax
	dec ecx
	
	mov esi, offset ennemyIMG	; load sprites for ennemies and loop through them
	mov edi, offset ennemyIMGH
	
	imgLoop:
		cmp [edx + BIKER.alive], 1
		jne showNextBiker
		
		cmp [edx + BIKER.velX], 0
		je VelIsVertShow
			call DrawIMG, edi, [edx + BIKER.X], [edx + BIKER.Y], BIKERH, BIKERW
			jmp showNextBiker
		VelIsVertShow:
			call DrawIMG, esi, [edx + BIKER.X], [edx + BIKER.Y], BIKERW, BIKERH
		
		showNextBiker:
		
		add edx, eax
	loop imgLoop
	
	ret
ENDP show

;returns a value in eax; test if eax = 10000(bin) then player wins, if eax < 10000(bin) ennemies win (for 5 bikers)
PROC endConditionBiker
	ARG 	@@PtrBikers:dword
	USES 	edi, ebx, ecx
	
	mov edi, [@@PtrBikers]
	mov ebx, [BikerSize]
	mov ecx, [TotalOfBikers]
	
	xor eax, eax
	
	BikersAliveTestLoop:
	or eax, [edi + BIKER.alive]
	shl eax, 1
	
	add edi, ebx
	loop BikersAliveTestLoop
	
	ret
ENDP endConditionBiker

; returns in eax, 0 for loss, 1 for win, 2 for quit
PROC BikerGame
	ARG 	@@WaitNFrames:dword, @@NBikers:dword
	USES 	ebx, ecx, edx, edi, esi
    ;sti            ; set The Interrupt Flag => enable interrupts
    ;cld            ; clear The Direction Flag
	
	;push ds
	;pop es
	;call setVideoMode, 13h ;320x200 pixels, A palette of 256 colors, 6 bits per RGB channel (control with 1 byte)
	
	call ReadFile, offset ennemyFile, offset ennemyIMG, IMGSIZE
	call ReadFile, offset playerFile, offset playerIMG, IMGSIZE
	
	call rotateIMG, offset ennemyIMG, offset ennemyIMGH, BIKERW, BIKERH	; create hor version of sprite
	call rotateIMG, offset playerIMG, offset playerIMGH, BIKERW, BIKERH
	
	mov edi, offset Bikers
	mov edx, offset BikerPosInitArr
	mov eax, offset BikerVelInitArr
	mov esi, offset PlayGround
	call initiateBikers, edi, edx, eax, esi
	
	mov edx, [@@WaitNFrames]
	
	mov ebx, 1
	mov ecx, [@@NBikers]	; calculate the value we have to compare to for a given number of bikers
	shl ebx, cl
	
	mov ecx, 20000
	drawLoop:
	
	HideMouse		; hide the mouse every frame to be sure it doesn't appear
	
	call selectiveBackgroundFiller, edi, esi
	
	call inputFromPlayer, edi
	
	cmp eax, 2
	je EndBikerGame
	
	call BikerAI, edi, esi
	
	
	call moveBiker, edi, esi
	
	call show, esi, edi
	
	call wait_VBLANK, dx
	
	call endConditionBiker, edi
	
	cmp eax, ebx
	je EndBikerGamePlayerWin
	jl EndBikerGamePlayerLose
	
	loop drawLoop
	
	EndBikerGamePlayerWin:
		mov eax, 1
	jmp SHORT EndBikerGame
	
	EndBikerGamePlayerLose:
		xor eax, eax
	EndBikerGame:


	;call	waitForSpecificKeystroke, 001Bh ;press esc to kill program
	;call	terminateProcess
	ret
ENDP BikerGame
; -------------------------------------------------------------------
; STRUCTS
; -------------------------------------------------------------------

STRUC BIKER
    X		dd 160
	Y		dd 100
	velX 	dd 0
	velY 	dd 0
	W		dd 0
	H		dd 0
	alive 	dd 1
	col 	dd 1
ENDS BIKER

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
Bikers			BIKER		5	dup	(<,,,,,,,>)
BikerSize	 	dd 			32
TotalOfBikers	dd			5

BikerPosInitArr	dd				155, 150, 		10, 10, 		295, 10, 		10, 180, 		295, 180
BikerVelInitArr	dd				0, -BIKERSPEED,	BIKERSPEED, 0, 	0, BIKERSPEED,	0, -BIKERSPEED, -BIKERSPEED, 0

PlayGround		dd 			SCRWIDTH*SCRHEIGHT dup (0)

ennemyFile db "biker.bin", 0
playerFile db "bikerply.bin", 0


UDATASEG
ennemyIMG db IMGSIZE dup (?)
ennemyIMGH db IMGSIZE dup (?)
playerIMG db IMGSIZE dup (?)
playerIMGH db IMGSIZE dup (?)
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------

END
