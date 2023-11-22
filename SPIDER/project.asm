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
	
PROC spider
    USES eax, ebx, esi, edx,ecx,edi
    mov ebx, offset player;gets player position
    mov ecx, [spideramount]; counter for the amount of spiders we will iterate over
    ;mov ecx, ecx    ; The counter for the loop
    mov esi,offset spiders
	mov eax,0
	mov edi,[spidersize]; define so that we can run the collision checks
    drawloop:
		
        ; Get the x and y positions from spiderpos array
        mov edx,[esi+spiders.X]     ; X position
                    ; Move to the next position in the array
		call randBetweenVal,0,10 ; find random value between 0 and 10
		
		cmp eax,7; can change value here to change percentage of true or random moves
		jl truemove_x
		jge randommove_x
		
		RETURN_X_CHECK:
		
		; Move to the next position in the array
        mov edx,[esi+spiders.Y]
        
		call randBetweenVal,0,10
		cmp eax,7; can change value here to change percentage of true or random moves
		jl truemove_y
		jge randommove_y
		
		RETURN_Y_CHECK:
		;add esi,4 
        call drawspider, [esi+spiders.X], [esi+spiders.Y], 1  ; Color 1 (red); Call drawDot to draw the spider
        
        ; Decrease the loop counter and check if we've processed all spiders
        add esi, edi
		loop drawloop
        jmp exitspider
		
		truemove_x:
		cmp edx,[ebx+player.X]; checks if player is left or right of spider
		jg movespiderLEFT
		jl movespiderRIGHT
		jmp RETURN_X_CHECK
		
		randommove_x:
		call randBetweenVal,0,2
		cmp eax,1
		jl movespiderLEFT
		jge movespiderRIGHT
		
		truemove_y:
		cmp edx, [ebx+player.Y]; checks if spider height is lower or greater than playerheight
		jl movespiderDOWN
		jg movespiderUP
		jmp RETURN_Y_CHECK
		
		randommove_y:
		call randBetweenVal,0,2
		cmp eax,1
		jl movespiderUP
		jge movespiderDOWN
		
		movespiderLEFT:
		dec edx
		mov [esi+spiders.X],edx
		jmp RETURN_X_CHECK
		
		movespiderRIGHT:
		inc edx
		mov [esi+spiders.X],edx
		jmp RETURN_X_CHECK
		
		movespiderDOWN:
		inc edx
		mov [esi+spiders.Y],edx
		jmp RETURN_Y_CHECK
		
		movespiderUP:
		dec edx
		mov [esi+spiders.Y],edx
		jmp RETURN_Y_CHECK
		
		exitspider:
		
    ret
ENDP spider

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

PROC spiderterrain
	USES eax,ebx,esi,edx,ecx
	mov esi, offset safezone
	mov eax,[esi+4];takes largest x-valkue
	mov edx,[esi]
	sub eax,edx;finds the width of the safezone
	mov ebx,[esi+12];take the largest y-value
	mov ecx,[esi+8]
	sub ebx,ecx;finds the height
	
	call fillBackground,15
	call drawRectangle,edx,ecx,eax,ebx,30; need to find color for green, this rectangle will be safe zone/victory zone 
	ret
ENDP spiderterrain

PROC setupspider
	call setVideoMode,13h
	call initialize_spider_player,100,100
	call initialize_spider_spider
	call spiderterrain
	gameloop:
	call spidergame,001Bh
	; in this need to implement time system, that or in the keystrojke section
	jmp gameloop

	ret
ENDP setupspider



PROC drawDot
	ARG x:word, y:word, col:byte;,y:word,
	USES eax,edx,esi
	mov EDI, VMEMADR 
	movzx esi, [x];haalt de x-positie
	movzx eax,[y] ; haalt de y pos
	mov ebx, SCRWIDTH
	mul ebx
	add esi, eax
	mov AL, [col]
	mov[EDI+esi],AL
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
PROC collisiondet; will be checking in a three by three area around the players position
	ARG x_pos:dword,y_pos:dword, mode:dword; mode shows for what it is used, 1 for player-spider detection, 2 for spider-spider collsion
	USES ebx, ecx, edx, edi, esi
    mov eax, [mode] ; Initialize collision flag
	push eax
	
    ; Get spider count, spider and player positions
    mov ecx, [spideramount]
    mov edx, offset spiders
    mov esi, [x_pos]
	mov ebx, [y_pos]
    ; Check for collisions
    xor edi, edi ; Clear index register for spider loop
	spiderloop:
	;xor eax,eax
    mov edi, [edx+spiders.X] ; Get spider x
    pop eax
	cmp eax,1
	jge spiderskip_x
	push eax
	xor eax,eax
	
	
	cmp edi, esi ; Check player x 
    je sameaxis_x
	spiderskip_x:
	push eax
	xor eax,eax
	
	inc edi
    cmp edi, esi ; Check player x + 1
    je sameaxis_x
	inc edi
	cmp edi, esi ; Check player x + 2
    je sameaxis_x
    sub edi, 3
    cmp edi, esi ; Check player x - 1
    je sameaxis_x
	sub edi,1
	 cmp edi, esi ; Check player x - 2
    je sameaxis_x
	return_x:
    ; Move to the next spider
	
    ; If no collision detected, exit
    ;spiderloop_y:
	mov edi, eax ; stores current value for eax to edi, as will be using eax to check which mode
	pop eax; gets the mode number
	cmp eax,1
	jge spiderskip_y
	push eax;pushes it back to stack
	xor eax,eax
	mov eax,edi
	mov edi, [edx+spiders.Y]
	jge spiderskip_y
    cmp edi, ebx ; Check player y, for some reason if i dont add this it doesnt collision doesnt trigger using the other checks if plpayer doesnt move, if they do move and collide in movement it does, dont know why that happens isnt logical
    je sameaxis_y
	spiderskip_y:
	inc edi
    cmp edi, ebx ; Check player y + 1
    je sameaxis_y
	inc edi
    cmp edi, ebx ; Check player y + 2
    je sameaxis_y
    sub edi, 3
    cmp edi, ebx ; Check player y - 1
    je sameaxis_y
	sub edi,1
	sub edi, ebx ; Check player y - 2
    je sameaxis_y
	return_y:
	jmp collisiontest
    ; Move to the next spider
	restartloop:
    add edx, [spideramount]
    dec ecx ; Decrease spider count
    jnz spiderloop ; Jump if not zero to continue checking collisions
	;xor eax,eax
	jmp exitcollisiondet
	
	;jmp exitcollisiondet
	;call terminateProcess
	sameaxis_x:
    add eax,1
    ; If collision detected, perform actions here, like terminating the process
	jmp return_x
	sameaxis_y:
	add eax,1
	jmp return_y
	
	collisiontest:
	cmp eax,2
	jl restartloop
	jge collisionTRUE
	

	
	collisionTRUE:
	;call terminateProcess
	mov eax,1
	jmp getouttahere
	exitcollisiondet:
	mov eax,0
	getouttahere:
	ret
ENDP collisiondet

	
PROC collisiondet2; tried to make a smoother collision detection, for some reason it doesnt work, it should give a zero as long as nothing is collision detected and a 1 or more for each colision
	ARG x_pos:dword,y_pos:dword; mode shows for what it is used, 1 for player-spider detection, 2 for spider-spider collsion
	USES ebx, ecx, edx, edi, esi
	xor eax,eax ; Initialize collision flag
	;push eax
	
    ; Get spider count, spider and player positions
    mov ecx, [spideramount]
    mov edx, offset spiderpos
    
    ; Check for collisions
    xor edi, edi 
	spider2loop:
	mov edi, [edx]; assign x of spider
	mov esi, [x_pos]
	mov ebx, [y_pos]
	
	sub esi,2
	cmp esi,edi
	jg exitcollisiondet2
	add esi,4
	cmp esi,edi
	jl exitcollisiondet2
	add edx,4
	mov edi,[edx] ; assign y of spider
	sub ebx,2
	cmp ebx,edi
	jg exitcollisiondet2
	add ebx, 4
	cmp ebx,edi
	jl exitcollisiondet2
	
	inc eax
	exitcollisiondet2:
	add edx,4
	loop spider2loop 
	;exitcollisiondet2:
	ret
	
ENDP collisiondet2


PROC victorydet; checks the conditions for the win, sure its manual but seems cho to me tbh
	USES eax,edi,esi
	mov edi, offset player
	mov esi, offset safezone
	mov eax,[edi+player.X]
	cmp eax,[esi];checks first border for x
	jl notSafe
	add esi,4
	cmp eax,[esi];checks second border for x
	jg notSafe
	add esi,4
	mov eax,[edi+player.Y]
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

PROC drawspider; will be drawing the spider as a cross similar to 'X'
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
	add edx,1
    call drawDot, ecx, edx, esi  ; bottom right pixel
    sub ecx, 2
	sub edx ,2
    call drawDot, ecx, edx, esi  ;  top left pixel

    ; Reset x-coordinate and adjust y-coordinate for the upper and lower pixels
    
    add edx, 2
    call drawDot, ecx, edx, esi  ; Upper -right pixel
    sub edx, 2
	add ecx,2
    call drawDot, ecx, edx, esi  ; Lower-left  pixel

    ret
ENDP drawspider

PROC initialize_spider_spider; will read from an array, and set semi random start positions for the spiders
	USES eax,ebx,ecx,edx,esi,edi
	mov esi, offset spiders
	mov edi, offset spiderpos
	mov ecx, [spideramount]
	mov ebx, [spidersize]
	spider_init_loop:
	;	mov edx,[edi]
	;	sub edx,5; add this step because randbetweenval cant give negative(i think not sure)
	;	call randBetweenVal,0,10
	;	add edx,eax
	;	cmp edx,0
	;	jl base_X; base being the starting position assigned in the array spiderpos
	;	cmp edx, SCRWIDTH
	;	jg base_X
	;	mov [esi +spiders.X], edx
	;	jmp exit_X
	;	
	;	base_X:
	;	mov edx,[edi]
	;	mov [esi +spiders.X], edx
	;	
	;	exit_X:
		
	;	add edi,4
	;	mov edx,[edi]
	;	sub edx,5
	;	call randBetweenVal,0,10
	;	add edx,eax
	;	cmp edx,0
	;	jl base_Y; base being the starting position assigned in the array spiderpos
	;	cmp edx, SCRHEIGHT
	;	jg base_X
	;	mov [esi +spiders.Y], edx
	;	jmp exit_Y
		
	;	base_Y:
	;	mov edx,[edi]
	;	mov [esi +spiders.Y], edx
	;	
	;	exit_Y:
	;	
	;	add edi,4
	;	mov [esi+spiders.ALIVE],1; set spider on alive
	;	add esi, ebx; iterate to the next spider
	;
		mov edx,[edi]
		mov [esi +spiders.X], edx
		
		add edi,4
		mov edx,[edi]
		mov [esi +spiders.Y], edx
		add edi,4
		mov [esi+spiders.ALIVE],1; set spider on alive
		add esi, ebx; iterate to the next spider
	
	
	loop spider_init_loop
	ret
ENDP initialize_spider_spider

PROC initialize_spider_player; give the correct starting
	arg @@Start_X:dword, @@Start_Y:dword
	USES eax,ebx,esi
	mov eax, [@@Start_X]
	mov ebx, [@@Start_Y]
	USES eax,ebx,esi
	mov esi, offset player
	mov [esi+player.X],eax
	mov [esi+player.Y],ebx
	mov [esi +player.ALIVE],1
	mov [esi+player.COL],1
	ret
ENDP initialize_spider_player
PROC spidergame
	ARG 	@@key:byte
	USES 	eax, ebx,esi,edi	
	mov esi, offset player
;	call spiderterrain;paint the canvas
	spidergameloop:
		call spiderterrain; activate if want to clear behind character
		mov ecx,[esi+player.X]
		mov ebx,[esi+player.Y]
		call drawplayer,[esi+player.X],[esi+player.Y],[esi+player.COL]; draws new position
		call victorydet
		
		push esi
		xor eax,eax; have to push as for some reason collisiondet effects esi, although im not sure where
		call collisiondet,ecx,ebx,eax
		;call drawDot,eax,eax,1;to debug
		cmp eax,1
		jge exit; make a loss screen from this
		pop esi
		
		call spider;,ecx,ebx
		call wait_VBLANK, 3
		;mov ah, 01h ; function 01h (check if key is pressed)
		;int 16h ; call keyboard BIOS
		;
		;jz SHORT spidergameloop;if key not pressed than there is a 0 flag ; SHORT means short jump (+127 or -128 bytes) solves warning message
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
		
	jne	spidergameloop ; if doesnt find anything restart
	
	UP:
	;xor al,al
	mov ecx,[esi+player.Y]
	cmp ecx,1 ; checks borders
	jl spidergameloop
	
	dec ecx ; moves position
	mov [esi+player.Y],ecx
	jmp spidergameloop ;returns to wait for keypress
	DOWN:
	mov ecx,[esi+player.Y]
	cmp ecx, SCRHEIGHT-1
	jge spidergameloop
	inc ecx
	mov [esi+player.Y],ecx
	jmp spidergameloop
	
	LEFT:
	;xor al,al
	mov ecx, [esi+player.X]
	cmp ecx,1
	jl spidergameloop
	
	dec ecx
	mov [esi+player.X],ecx
	jmp spidergameloop
	
	RIGHT:
	;xor al,al
	mov ecx,[esi+player.X]
	cmp ecx, SCRWIDTH-1
	jge spidergameloop
	inc ecx
	mov [esi+player.X],ecx
	jmp spidergameloop
	exit:
	call terminateProcess
	ret
ENDP spidergame
start:
     sti            ; set The Interrupt Flag => enable interrupts
     cld            ; clear The Direction Flag

	push eax; clearing all
	push ebx
	push ecx
	push edx
	push edi
	push esi
	mov ah, 09h
	mov edx, offset msg
	int 21h
	xor ah,ah
	xor edx,edx
	
	; Wait for keystroke and read character.
	mov ah,00h
	int 16h
	call setupspider
	;call randombit
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
STRUC SPIDER
	X dd 0
	Y dd 0
	ALIVE dd 1; 1 will be for alive, 0 for dead
	RES_X dd 0; will be the respawn point of the spider once it dies
	RES_Y dd 0; same as RES_X except now the Y coordinate
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
	
	
	playerpos dd 100,100; stores position of player
	
	
	
	spiders 	SPIDER		9		dup	(<,,,,,>)
	spideramount dd 9; stores amount of spiders
	spidersize dd 24
	
	
	
	spiderpos dd 0,0,10,10,30,30,40,40,50,50,60,60,70,70,80,80,90,90; contains the x followed by y positions of each spider
	
	safezone dd 150,170,90,110 ; sets the boundaries for the x value and y value for the winzone, first two being lower and upper x and last two being lower and upper y
	
	victory db "you won!", 13, 10, '$'
	
	lossmessage db "you lost!", 13, 10, '$'
	
	randSeed		dd			2003630
	
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END start

; 12 is colorcode for red
; 10 voor groen