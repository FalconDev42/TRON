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
ENDM ShowMouse

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
	ARG	 @@IMGPtr:dword, @@x:dword, @@y:dword, @@w:dword, @@h:dword
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

PROC rotateIMG
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
	rep stosd
	
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
	mov ebx, [BikerSize]
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
	
	
	mov eax, BORDERCOLOR
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
	inc eax
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
	
	; push ecx
		
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
	shl eax, 2
	add eax, [edi + BIKER.X]
	
	push ebx
	
	mov ebx, [edi + BIKER.velY]
	shl ebx, 2
	add ebx, [edi + BIKER.Y]
	
	call checkColorsInRectangle, [@@PtrPlayGround], eax, ebx, [edi + BIKER.W], [edi + BIKER.H]	; test if this orientation does not contain line
		
	pop ebx
	
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
	
	mov eax, edx
	mul ecx
	mov edx, [BikerSize]
	sub eax, edx
	add edi, eax
	
	BikerColisionLoop:
		cmp [edi + BIKER.alive], 0
		je SHORT skipBikerDead
		
		; mov eax, [edi + BIKER.velX]
		; mov ebx, [edi + BIKER.velY]
		
		; cmp eax, 0
		; je ColVelIsVert
		
		; inc ebx
		; add eax, [edi + BIKER.X]
		; add ebx, [edi + BIKER.Y]
		; call checkColorsInRectangle, esi, eax, ebx, [edi + BIKER.W], BIKERW - 2		; only the inside pixels
		
		; jmp CheckIfDead
		; ColVelIsVert:
		
		; inc eax
		; add eax, [edi + BIKER.X]
		; add ebx, [edi + BIKER.Y]
		; call checkColorsInRectangle, esi, eax, ebx, BIKERW - 2, [edi + BIKER.H]		; only the inside pixels
		
		; CheckIfDead:
		
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
		
		mov ebx, [edi + BIKER.Y]
		add ebx, [edi + BIKER.velY]
		
		mov [edi + BIKER.X], eax
		mov [edi + BIKER.Y], ebx
		
		
		call drawFilledRectangleDWORD, esi, eax, ebx, [edi + BIKER.W], [edi + BIKER.H], INVISIBLECOL
		call drawLine, esi, eax, ebx, [edi + BIKER.W], [edi + BIKER.H], [edi + BIKER.velX], [edi + BIKER.velY], [edi + BIKER.col]
		
		BikerLongDead:
	
	sub edi, edx
	dec ecx
	cmp ecx, 0
	jg BikerColisionLoop
	
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
	jne SHORT EndLineReset

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
	jne LineIsNotBottom
	add edi, 4 * SCRWIDTH
	jmp ResetPixelOfLine
	LineIsNotBottom:
	
	;; two time further (to solve problem where you had line staying because of the fast turnin of the AI)
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
	

	EndLineReset:
	
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
	jne NoLineReset
		
		;if line reset:
		; find pixel where line was drawn: check if color equal to that of dead biker
		; check surrounding pixels
		; if all checks return false every pixel of line has been erased
		; else repeat
		
		; afterwards erase for the last time the biker and set alive status to 0 such that we dont draw over him anymore
		
		
		call EraseLine, esi, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], [edi + BIKER.velX], [edi + BIKER.velY], [edi + BIKER.col]
		
		call drawFilledRectangleDWORD, esi, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], 0
		
		call drawFilledRectangle, 0, 0, SCRWIDTH, SCRHEIGHT, 0
		
		mov [edi + BIKER.velX], 0
		mov [edi + BIKER.velY], 0
		
		xor eax, eax
		mov [edi + BIKER.alive], eax
	NoLineReset:
	
	cmp eax, 1
	jne DontResetRect
	call drawFilledRectangleDWORD, esi, [edi + BIKER.X], [edi + BIKER.Y], [edi + BIKER.W], [edi + BIKER.H], 0
	
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
	mov eax, [esi]
	
	; remove residual lines if not yet removed
	;jmp NoColorChange ; debugging
	cmp al, 0
	je NoColorChange
	cmp al, BORDERCOLOR
	je NoColorChange
	cmp al, INVISIBLECOL
	je EndPixelUpdate
	
	cmp eax, ebx
	je PlayerColor
	
	; remove residual lines if not yet removed
	sub eax, [TotalOfBikers]
	neg eax
	push edx
	mul [BikerSize]
	pop edx
	 
	cmp [edx + eax + BIKER.alive], 1
	je ShowPix
	xor eax, eax
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
	
	mov edx, [@@PtrBiker]
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
	
	mov esi, offset ennemyIMG
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

;returns a value in eax; test if eax = 10000(bin) then player wins, if eax < 10000(bin) ennemies win
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


PROC BikerGame
    sti            ; set The Interrupt Flag => enable interrupts
    cld            ; clear The Direction Flag
	
	push ds
	pop es
	
	call	setVideoMode, 13h ;320x200 pixels, A palette of 256 colors, 6 bits per RGB channel (control with 1 byte)
	
	call ReadFile, offset ennemyFile, offset ennemyIMG, IMGSIZE
	call ReadFile, offset playerFile, offset playerIMG, IMGSIZE
	
	call rotateIMG, offset ennemyIMG, offset ennemyIMGH, BIKERW, BIKERH
	call rotateIMG, offset playerIMG, offset playerIMGH, BIKERW, BIKERH
	
	mov edi, offset Bikers
	mov edx, offset BikerPosInitArr
	mov eax, offset BikerVelInitArr
	mov esi, offset PlayGround
	call initiateBikers, edi, edx, eax, esi
	
	mov ebx, 1
	mov ecx, [TotalOfBikers]
	shl ebx, cl
	
	mov ecx, 20000
	drawLoop:
	
	HideMouse
	
	call selectiveBackgroundFiller, edi, esi
	
	call inputFromPlayer, edi
	
	call BikerAI, edi, esi
	
	
	call moveBiker, edi, esi
	
	call show, esi, edi
	
	call wait_VBLANK, 2
	
	call endConditionBiker, edi
	
	cmp eax, ebx
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
randSeed		dd			2003630

Bikers			BIKER		5	dup	(<,,,,,,,>)
BikerSize	 	dd 			32
TotalOfBikers	dd			5

BikerPosInitArr	dd				155, 150, 		10, 10, 		295, 10, 		10, 180, 		295, 180
BikerVelInitArr	dd				0, -BIKERSPEED,	BIKERSPEED, 0, 	0, BIKERSPEED,	0, -BIKERSPEED, -BIKERSPEED, 0

PlayGround		dd 			SCRWIDTH*SCRHEIGHT dup (0)

WinMsg			db 	"You WON!", 13, 10, '$'
LoseMsg			db 	"You LOST", 13, 10, '$'


ennemyFile db "biker.bin", 0
playerFile db "bikerply.bin", 0

openErrorMsg db "could not open file", 13, 10, '$'
readErrorMsg db "could not read data", 13, 10, '$'
closeErrorMsg db "error during file closing", 13, 10, '$'



UDATASEG
ennemyIMG db IMGSIZE dup (?)
ennemyIMGH db IMGSIZE dup (?)
playerIMG db IMGSIZE dup (?)
playerIMGH db IMGSIZE dup (?)
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END BikerGame
