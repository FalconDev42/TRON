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

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height

RAND_A = 1103515245
RAND_C = 12345
CODESEG

PROC setVideoMode
	ARG arg1:word
	USES eax
	;int 10h; AH=0, AL=mode.
	mov AX, [arg1] ; video mode whatever
	int 10h
	ret
ENDP setVideoMode

; use rand with seed, if need be see tank code

PROC fillBackground
	ARG color:byte
	USES ecx,edi,eax,esi
	mov EDI, VMEMADR ; start of video memory
	mov ecx, SCRWIDTH*SCRHEIGHT
	mov AL, [color] 
	xor esi,esi
	backgroundloop:
	
	mov[EDI+esi],AL
	inc esi
	loop backgroundloop
	rep stosb
	ret
ENDP fillBackground
PROC drawRectangle
	ARG x0:word,y0:word,w:word,h:word,col:byte
	;will be using two independant loops, one drawing vertical lines the other drawing horizontal
	USES eax,ecx,edi,edx
	mov al,[col]
	xor EDI,EDI
	mov EDI, VMEMADR
	;mov ecx,w
	movzx eax,[y0]
	mov edx, SCRWIDTH
	mul edx
	movzx ebx, [x0]
	
	add edi,eax
	add edi,ebx
	
	movzx eax,[h]
	mov edx, SCRWIDTH
	mul edx
	
	movzx edx,[w]
	mov ecx,edx
	horloop:
	mov [edi],al
	mov [edi +eax],al
	inc edi
	loop horloop
	sub edi, edx
	movzx ecx, [h]
	vertloop:
	mov [edi], AL
	mov [edi+edx-1],AL
	add edi,SCRWIDTH
	loop vertloop
	
	ret
ENDP drawRectangle

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

PROC towerterrain
	USES eax,ebx,esi,edx,ecx
	mov esi, offset safezone
	mov eax,[esi+4];takes largest x-valkue
	mov edx,[esi]
	sub eax,edx;finds the width of the safezone
	mov ebx,[esi+12];take the largest y-value
	mov ecx,[esi+8]
	sub ebx,ecx;finds the height
	
	call fillBackground,15
	call drawFilledRectangle,edx,ecx,eax,ebx,10; need to find color for green, this rectangle will be safe zone/victory zone 
	call drawRectangle,0,0,edx,SCRHEIGHT,16
	call drawRectangle,0,0,SCRWIDTH,ecx,16
	
	mov eax,[esi+4];takes largest x-valkue
	mov ebx, SCRWIDTH
	sub ebx,eax
	;call initialize_bricks
	call drawRectangle,eax,0,ebx,SCRHEIGHT,16
	call initialize_bricks
	
	ret
ENDP towerterrain

PROC setuptower
	call setVideoMode,13h
	call initialize_tower_player,160,200
	call initialize_bricks
	call towergame,001Bh
	ret
ENDP setuptower



PROC drawDot
	ARG x:dword, y:dword, col:dword;,y:word,
	USES eax, edi, esi, ebx, edx
	mov edi, VMEMADR 
	mov esi, [x];haalt de x-positie
	mov eax,[y] ; haalt de y pos
	mov ebx, SCRWIDTH
	mul ebx
	add esi, eax
	mov eax, [col]
	mov[edi + esi], al
	ret
ENDP drawDot



;Terminate the program.
PROC terminateProcess
	USES eax
	call setVideoMode, 03h
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess


PROC victorydet; checks the conditions for the win, sure its manual but seems cho to me tbh
	USES eax,edi,esi
	mov edi, offset player
	mov esi, offset safezone
	mov eax,[edi+PLAYER.X]
	cmp eax,[esi];checks first border for x
	jl notSafe
	add esi,4
	cmp eax,[esi];checks second border for x
	jg notSafe
	add esi,4
	mov eax,[edi+PLAYER.Y]
	cmp eax,[esi];checks first border for y
	jl notSafe
	add esi,4
	cmp eax,[esi]; checks second border for y
	jg notSafe
	call terminateProcess
	notSafe:; if doesnt match any=> exit 
	ret
ENDP victorydet
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

PROC drawplayer; will be drawing the player as a cross similar to '+'
    ARG x_player: dword, y_player: dword, color: dword
    USES eax, ebx, ecx, edx, esi

    mov eax, [x_player]
    mov ebx, [y_player]
    mov esi, [color]
    mov ecx, eax
    mov edx, ebx

    ; Draw the five pixels to form a cross '+'
    call drawDot, ecx, edx, esi  ; Center pixel
    add ecx, 1
    call drawDot, ecx, edx, esi  ; Right pixel
    sub ecx, 2
    call drawDot, ecx, edx, esi  ; Left pixel

    ; Reset x-coordinate and adjust y-coordinate for the upper and lower pixels
    mov ecx, eax
    add edx, 1
    call drawDot, ecx, edx, esi  ; Upper pixel
    sub edx, 2
    call drawDot, ecx, edx, esi  ; Lower pixel

    ret
ENDP drawplayer
PROC initialize_bricks; can also do this just usning a matrix, and would be a lot less of a headache ptn
	USES eax,ebx,ecx,edx,edi,esi
	mov eax, offset bricks
	;mov ebx, offset safezone
	mov ecx, [brickamount]
	mov edx, [bricksize]; doint it statically rn, to save edx and headache
	; need to find the width, height is set to 6 for the moment being
	;xor esi,esi
	;mov esi, offset brickmatrix
	;brick_init_loop:
	;mov ebx,[esi]
	;mov [eax+BRICK.X_0], ebx
	;add esi, 4
	;mov ebx,[esi]
	;mov [eax+BRICK.Y_0], ebx
	;add esi,4
	;add eax,edx
	;loop brick_init_loop
	
	
	
	mov edx, [ebx+12]
	inc edx; add one so no overlap with safezone
	
	mov ecx, 3; 6x3 layer of bricks so need a loop
	brick_vert_loop:
	
	mov esi, [ebx]
	push ecx
	mov ecx,6
	brick_hor_loop:
	mov [eax+BRICK.X_0], esi
	add esi,8
	mov [eax+BRICK.W],8
	mov [eax+BRICK.H],6
	mov [eax+BRICK.Y_0],edx
	add eax, 24; 24 is bricksize
	
	
	
	
	loop brick_hor_loop
	add edx,7; increase height by 6+1 so no overlap
	pop ecx
	loop brick_vert_loop
	
	ret
ENDP initialize_bricks


PROC drawbricks
	USES eax,ebx,ecx,edx,edi,esi
	
	;mov esi, offset bricks
	xor esi,esi
	mov esi, offset brickamount
	mov ecx, [brickamount]
	mov edx, [bricksize]
	
	drawloop:
	;push ecx
	;mov eax, [esi+bricks.ALIVE]
	;cmp eax,1
	;jl check_return
	
	;call drawRectangle,2,6,6,8,12
	mov edi,[esi+BRICK.X_0]
	mov ebx,[esi+BRICK.Y_0]
	
	;mov edi, [esi]
	;add esi, 4
	;mov ebx, [esi]
	;add esi,4
	call randBetweenVal,1,14
	call drawRectangle,edi,ebx,8,6,eax
	;check_return:
	add esi, edx
	;pop ecx
	loop drawloop
	ret
ENDP drawbricks		

PROC initialize_tower_player; give the correct starting
	USES eax,ebx,esi
	mov eax, [playerspawn]
	mov ebx, [playerspawn+4]
	mov esi, offset player
	mov [esi+PLAYER.X],eax
	mov [esi+PLAYER.Y],ebx
	mov [esi +PLAYER.ALIVE],1
	mov [esi+PLAYER.COL],1
	ret
ENDP initialize_tower_player
PROC lowertower
	mov eax, [safezone+8]
	mov ebx,[safezone+12]
	inc eax
	inc ebx
	mov [safezone+8],eax
	mov [safezone+12],ebx
	;add code here for the bricks
	ret
	
	
	
ENDP lowertower


PROC towergame
	ARG 	@@key:byte
	USES 	eax,ecx,edx, ebx,esi,edi	
	mov esi, offset player
;	call spiderterrain;paint the canvas
	mov edi, offset safezone
	xor edx,edx
	towergameloop:
		call towerterrain; activate if want to clear behind character
		mov ecx,[esi+PLAYER.X]
		mov ebx,[esi+PLAYER.Y]
		call drawplayer,[esi+PLAYER.X],[esi+PLAYER.Y],[esi+PLAYER.COL]; draws new position
		call drawbricks
		call victorydet
		
		call wait_VBLANK, 3
		;mov ah, 01h ; function 01h (check if key is pressed)
		;int 16h ; call keyboard BIOS
		;
		;jz SHORT spidergameloop;if key not pressed than there is a 0 flag ; SHORT means short jump (+127 or -128 bytes) solves warning message
		inc edx
		cmp edx,5; change the amount to change dificulty, will decide how often the whole shit descends
		jl continuegameloop
		mov edx,0
		call lowertower
		continuegameloop:
		mov ah, 00h ;get key from buffer (ascii code in al)
		int 16h
		
		
		
		cmp	al,[@@key]; checks to see if we ditch program
		je exit
		cmp al,122; inset code for (W,) Z want in azerty 
		
		je UP
		cmp al,115; checks to see for S
		je DOWN
		cmp al,113; checks for Q
		je LEFT
		cmp al,100; checks for D
		je RIGHT
		
	jne	towergameloop ; if doesnt find anything restart
	
	UP:
	;xor al,al
	mov ecx,[esi+PLAYER.Y]
	cmp ecx,1 ; checks borders
	jl towergameloop
	
	dec ecx ; moves position
	mov [esi+PLAYER.Y],ecx
	jmp towergameloop ;returns to wait for keypress
	DOWN:
	mov ecx,[esi+PLAYER.Y]
	cmp ecx, SCRHEIGHT-1
	jge towergameloop
	inc ecx
	mov [esi+PLAYER.Y],ecx
	jmp towergameloop
	
	LEFT:
	;xor al,al
	mov ecx, [esi+PLAYER.X]
	push eax
	mov eax, [edi]
	inc eax
	cmp ecx, eax
	pop eax
	jl towergameloop
	
	dec ecx
	mov [esi+PLAYER.X],ecx
	jmp towergameloop
	
	RIGHT:
	;xor al,al
	mov ecx,[esi+PLAYER.X]
	push eax
	mov eax, [edi+4]
	dec eax
	cmp ecx, eax
	pop eax
	jge towergameloop
	inc ecx
	mov [esi+PLAYER.X],ecx
	jmp towergameloop
	exit:
	call terminateProcess
	ret
ENDP towergame
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
	
	; Wait for keystroke and read character.
	mov ah,00h
	int 16h
	;call setVideoMode,13h
	;call showPalette
	call setuptower
	
	mov ah,00h
	int 16h
	call terminateProcess
	;call terminateProcess
	; Terminate process with return code in response to a keystroke.
    mov	ax,4C00h
	int 	21h

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------

; if add spider as struct: only need 2 pieces of info on spider, namely position, in x and y, and if alive doesnt matter=> insta respawn at start position spider
STRUC BRICK
	X_0 dd 0
	Y_0 dd 0
	W dd 8
	H dd 6
	ALIVE dd 1; 1 will be for alive, 0 for dead
	COL dd 1
ENDS

STRUC PLAYER
	X dd 0
	Y dd 0
	ALIVE dd 1
	COL dd 1
ENDS

STRUC BULLET
	X		dd 0
	Y		dd 0
	velX 	dd 0
	velY 	dd 0
	bounces	dd 0
	active 	dd 0
	col 	dd 30
	W		dd 3
ENDS BULLET

DATASEG

	msg	db "Hello User! Welcome to the spider game, press any button to continue.", 13, 10, '$'
	
	palette		db 768 dup (?)
	player		PLAYER		1		dup(< ,,,>)
	playeramount dd 1;both this and the size shouldnt matter, atleast not how the procedures are set up now
	playersize dd 16;
	
	
	playerspawn dd 160,180; stores position of player
	
	
	bricks		BRICK	18		dup(< ,,,>)
	brickamount dd 18
	bricksize dd 24
	brickmatrix dd 136,41,144,41,152,41,160,41,168,41,176,41,136,47,144,47,152,47,160,47,168,47,176,47,136,53,144,53,152,53,160,53,168,53,176,53
	
	
	
	spiderpos dd 0,0,10,10,30,30,40,40,50,50,60,60,70,70,80,80,90,90; contains the x followed by y positions of each spider
	
	safezone dd 136,184,20,40 ; sets the boundaries for the x value and y value for the winzone, first two being lower and upper x and last two being lower and upper y
	
	victory db "you won!", 13, 10, '$'
	
	lossmessage db "you lost!", 13, 10, '$'
	
	randSeed		dd			2003630
	
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END start