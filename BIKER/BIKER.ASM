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
VMEMADR 		EQU 0A0000h	; video memory address
SCRWIDTH 		EQU 320		; screen witdth
SCRHEIGHT 		EQU 200		; screen height
BACKGROUNDCOL 	EQU 0		; background color
BIKERSPEED 		EQU 1		; Speed of Biker
BIKERW			EQU 5
BIKERH			EQU 11

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

PROC drawFilledRectangleDWORD
	ARG 	@@PtrStartScreen:dword, @@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@col: dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	
	mov ecx, [@@x0]
	shl ecx, 2
	; Compute the index of the rectangle's top left corner
	mov eax, [@@y0]
	mov edx, SCRWIDTH * 4
	mov esi, edx
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
	
	mov	eax,[@@col]
	
	@@startRectDraw:
		mov [edi], eax
		add edi, 4
		loop @@startRectDraw
	
	sub edi, edx		; reset edi to left-top corner
	add edi, esi
	mov ecx, edx
	shr ecx, 2
	
	dec ebx
	
	cmp ebx, 0
	jge @@startRectDraw
	
	ret
ENDP drawFilledRectangleDWORD

PROC initiateBikers
	ARG		@@PtrBikers:dword, @@PtrInitArray:dword, @@PtrVelInitArray:dword, @@PtrPlayGround:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrBikers]
	mov esi, [@@PtrInitArray]
	mov edx, [@@PtrVelInitArray]
	mov ebx, [Bikersize]
	mov ecx, [TotalOfBikers]
	
	BikersInitLoop:		; reset biker structs
	
	mov eax, [esi]
	mov [edi + BIKER.X], eax
	add esi, 4
	
	mov eax, [esi]
	mov [edi + BIKER.Y], eax
	add esi, 4
	
	mov eax, [edx]
	mov [edi + BIKER.velX], eax
	add edx, 4
	
	mov eax, [edx]
	mov [edi + BIKER.velY], eax
	add edx, 4
	
	cmp eax, 0
	je BikerIsHorizontal
	mov [edi + BIKER.W], BIKERW
	mov [edi + BIKER.H], BIKERH
	
	jmp EndBikerRotationInit
	BikerIsHorizontal:
	mov [edi + BIKER.W], BIKERH
	mov [edi + BIKER.H], BIKERW
	
	EndBikerRotationInit:
	
	mov [edi + BIKER.alive], 1
	
	mov [edi + BIKER.col], ecx
	
	add edi, ebx
	loop BikersInitLoop
	
	mov edi, [@@PtrPlayGround]
	xor eax, eax
	mov ecx, SCRWIDTH*SCRHEIGHT
	rep stosd			; reset PlayGround
	
	
	mov eax, 8
	mov ecx, SCRWIDTH
	mov edi, [@@PtrPlayGround]
	
	rep stosd
	
	;dec edi
	
	mov eax, 8h
	mov ecx, SCRHEIGHT - 2
	
	LeftAndRightEdgeLoop:
	mov [edi], eax
	
	add edi, SCRWIDTH * 4
	
	sub edi, 4
	mov [edi], eax
	add edi, 4
	
	loop LeftAndRightEdgeLoop
	
	mov eax, 8
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
	
	cmp [edi + BIKER.velX], 0
	jg BikerWasGoingRightU
	add eax, BIKERH
	BikerWasGoingRightU:
	
	add eax, [edi + BIKER.X]
	mov [edi + BIKER.X], eax
	
	mov eax, BIKERW
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
	
	cmp [edi + BIKER.velX], 0
	jg BikerWasGoingRightD
	add eax, BIKERH
	BikerWasGoingRightD:
	
	add eax, [edi + BIKER.X]
	mov [edi + BIKER.X], eax
	
	mov eax, BIKERW
	shr eax, 1
	;sub eax, BIKERH
	add eax, [edi + BIKER.Y]
	mov [edi + BIKER.Y], eax
	
	mov [edi + BIKER.velX], 0
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
	add [edi + BIKER.X], eax
	
	mov eax, BIKERW
	shr eax, 1
	neg eax
	
	cmp [edi + BIKER.velY], 0
	jg BikerWasGoingDownR
	add eax, BIKERH
	BikerWasGoingDownR:
	
	add [edi + BIKER.Y], eax
	
	mov [edi + BIKER.velX], BIKERSPEED
	mov [edi + BIKER.velY], 0
	mov [edi + BIKER.W], BIKERH
	mov [edi + BIKER.H], BIKERW
	
	ret
ENDP rotateBikerRight

PROC rotateBikerLeft
	ARG		@@PtrBiker:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrBiker]
	
	mov eax, BIKERW
	shr eax, 1
	sub eax, BIKERH
	;add eax, [edi + BIKER.X]
	add [edi + BIKER.X], eax
	
	mov eax, BIKERW
	shr eax, 1
	neg eax
	
	cmp [edi + BIKER.velY], 0
	jg BikerWasGoingDownL
	add eax, BIKERH
	BikerWasGoingDownL:
	
	add eax, [edi + BIKER.Y]
	mov [edi + BIKER.Y], eax
	
	mov [edi + BIKER.velX], -BIKERSPEED
	mov [edi + BIKER.velY], 0
	mov [edi + BIKER.W], BIKERH
	mov [edi + BIKER.H], BIKERW
	
	ret
ENDP rotateBikerLeft

;modifies the speed of the ennemy Bikers
;Initiates a bullet if the mouse is clicked
PROC inputFromPlayer
	ARG		@@PtrPlayerBiker:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov ah, 01h ; function 01h (check if key is pressed)
	int 16h ; call keyboard BIOS
	jz @@notpressed ;if key not pressed than there is a 0 flag ; SHORT means short jump (+127 or -128 bytes) solves warning message
	
	mov ah, 00h ;get key from buffer (ascii code in al)
	int 16h
	
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
	
	ret
ENDP inputFromPlayer

PROC checkColorsInRectangle
	ARG 	@@PlayGroundPtr:dword, @@x0:dword, @@y0:dword, @@w:dword, @@h:dword
	USES 	ebx, ecx, edx, edi, esi
	
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
	jge @@checkRect
	
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
	add edi, 4
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
	mov edx, [Bikersize]
	mov ecx, [TotalOfBikers]
	
	BikerColisionLoop:
		cmp [edi + BIKER.alive], 0
		je SHORT skipBikerDead
		
		mov eax, [edi + BIKER.X]
		add eax, [edi + BIKER.velX]
		mov ebx, [edi + BIKER.Y]
		add ebx, [edi + BIKER.velY]
		
		call checkColorsInRectangle, esi, eax, ebx, [edi + BIKER.W], [edi + BIKER.H]
		;xor eax, eax
		cmp eax, 0 ; if eax is not equal to 0 then there is a color in the future rectangle so biker must die
		jne BikerIsDead
		mov eax, [edi + BIKER.X]
		add eax, [edi + BIKER.velX]
		
		mov [edi + BIKER.X], eax
		mov [edi + BIKER.Y], ebx
		
		call drawFilledRectangleDWORD, esi, eax, ebx, [edi + BIKER.W], [edi + BIKER.H], [edi + BIKER.col]
		call drawLine, esi, eax, ebx, [edi + BIKER.W], [edi + BIKER.H], [edi + BIKER.velX], [edi + BIKER.velY], [edi + BIKER.col]
		
		jmp SHORT skipBikerDead
		BikerIsDead:
		mov [edi + BIKER.alive], 0
		
		skipBikerDead:
	
	add edi, edx
	loop BikerColisionLoop
	
	ret
ENDP moveBiker

PROC EraseLine
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
	;sub edi, ebx
	jmp FoundEndLine
	
	VelYLineIsNeg:
	mov eax, [@@h]
	inc eax
	mul ebx
	add edi, eax	; bottom of bike
	
	FoundEndLine:
	
	
	mov eax, [@@col]
	cmp [edi], eax
	jne EndLineReset

	ResetPixelOfLine:
	xor ebx, ebx
	mov [edi], ebx

	cmp[edi - 4], eax
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
	jne EndLineReset
	add edi, 4 * SCRWIDTH
	jmp ResetPixelOfLine
	EndLineReset:
	
	ret
	
ENDP EraseLine

PROC selectiveBackgroundFiller
	ARG		@@PtrBikers:dword, @@PtrPlayGround:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov edi, [@@PtrBikers]
	mov esi, [@@PtrPlayGround]
	mov ebx, [Bikersize]
	mov edx, [TotalOfBikers]
	
	BikersBackgoundLoop:
	cmp [edi + BIKER.alive], 0
	;jmp NoLineReset
	jne NoLineReset
		
		;if line reset:
		; find pixel where line was drawn: check if color equal to that of dead biker
		; check surrounding pixels
		; if all checks return false every pixel of line has been erased
		; else repeat
		
		call EraseLine, esi, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], [edi + BIKER.velX], [edi + BIKER.velY], [edi + BIKER.col]
	NoLineReset:
	
	call drawFilledRectangleDWORD, esi, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], 0
	
	add edi, ebx
	dec edx
	cmp edx, 0
	jg BikersBackgoundLoop
	
	ret
ENDP selectiveBackgroundFiller

PROC show
	ARG		@@PtrPlayGround:dword, @@PtrPlayGround:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	mov esi, [@@PtrPlayGround]
	mov edi, VMEMADR
	mov ecx, SCRWIDTH*SCRHEIGHT
	mov ebx, [TotalOfBikers]
	
	xor eax, eax
	
	BikersShowLoop:
	mov eax, [esi]
	
	cmp eax, ebx
	je PlayerColor
	cmp al, 0
	je NoColorChange
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
	
	ret
ENDP show

;returns a value in eax; test if eax = 10000(bin) then player wins, if eax < 10000(bin) ennemies win
PROC endConditionBiker
	ARG 	@@PtrBikers:dword
	USES 	edi, ebx, ecx
	
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
	
	call	setVideoMode, 13h ;320x200 pixels, A palette of 256 colors, 6 bits per RGB channel (control with 1 byte)
	
	
	mov edi, offset Bikers
	mov edx, offset BikerPosInitArr
	mov eax, offset BikerVelInitArr
	mov esi, offset PlayGround
	call initiateBikers, edi, edx, eax, esi
	
	mov ecx, 1000
	drawLoop:
	
	call selectiveBackgroundFiller, edi, esi
	
	call inputFromPlayer, edi
	
	call moveBiker, edi, esi
	
	call show, edi, esi
	
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
	W		dd BIKERW
	H		dd BIKERH
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

BikerPosInitArr	dd				155, 150, 		10, 10, 		295, 10, 		10, 180, 		295, 180
BikerVelInitArr	dd				0, -BIKERSPEED,	BIKERSPEED, 0, 	0, BIKERSPEED,	0, -BIKERSPEED, -BIKERSPEED, 0

PlayGround		dd 			SCRWIDTH*SCRHEIGHT dup (0)

WinMsg			db 	"You WON!", 13, 10, '$'
LoseMsg			db 	"You LOST", 13, 10, '$'

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END start
