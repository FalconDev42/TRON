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
	ARG x0:dword,y0:dword,w:dword,h:dword,col:byte
	;will be using two independant loops, one drawing vertical lines the other drawing horizontal
	USES eax,ecx,edi,edx
	mov al,[col]
	xor EDI,EDI
	mov EDI, VMEMADR
	;mov ecx,w
	mov eax,[y0]
	mov edx, SCRWIDTH
	mul edx
	mov ebx, [x0]
	
	add edi,eax
	add edi,ebx
	
	mov eax,[h]
	mov edx, SCRWIDTH
	mul edx
	
	mov edx,[w]
	mov ecx,edx
	horloop:
	mov [edi],al
	mov [edi +eax],al
	inc edi
	loop horloop
	sub edi, edx
	mov ecx, [h]
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
	call drawRectangle,eax,0,ebx,SCRHEIGHT,16
	ret
ENDP towerterrain

PROC setuptower
	call setVideoMode,13h
	NoMouse:
	mov  ax, 0000h  ; reset mouse
	int  33h        ; -> AX BX
	cmp  ax, 0FFFFh
	jne  NoMouse
	mov  ax, 0001h  ; show mouse
	int  33h
	
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

PROC collision
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
ENDP collision

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

PROC endcollisioncheck_bricks; checks the conditions for the win, sure its manual but seems cho to me tbh
	USES eax,ebx,ecx,edx,esi,edi
	mov esi,offset player
	mov eax,offset safezone
	
	mov edx,[eax+4]
	mov ecx,[eax]
	sub edx,ecx
	mov edi,[eax+12]
	mov ebx,[eax+8]
	sub edi,ebx
	
	
	
	call collision,ecx,ebx,edx,edi,[esi+PLAYER.X], [esi+PLAYER.Y],1,1,0
	cmp eax,1
	jl no_victory_collision
	; input code here for victory screen, for the moment just end game
	;call setVideoMode,3h
	;call waitForSpecificKeystroke, 001Bh
	call terminateProcess
	
	no_victory_collision:
	mov edi,offset bricks
	mov ecx,[brickamount]
	mov edx,[bricksize]
	
	brick_check_loop:
	mov eax, [edi+BRICK.ALIVE]
	cmp eax, 1
	jl nocollision
	call collision,[edi+BRICK.X],[edi+BRICK.Y],[edi+BRICK.W],[edi+BRICK.H],[esi+PLAYER.X], [esi+PLAYER.Y],1,1,2
	cmp eax,1
	jge defeat
	nocollision:
	add edi, edx
	loop brick_check_loop
	jmp exit_collision
	defeat:
	call terminateProcess
	;call setVideoMode,3h
	;call waitForSpecificKeystroke, 001Bh
	
	exit_collision:
	ret
ENDP endcollisioncheck_bricks
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
	mov ebx, offset brickmatrix
	mov ecx, [brickamount]
	mov edx, [bricksize]; doint it statically rn, to save edx and headache
	brick_init_loop:
	mov esi,[ebx]
	mov [eax+BRICK.X],esi
	add ebx,4
	mov esi,[ebx]
	mov [eax+BRICK.Y],esi
	add ebx,4
	mov [eax+BRICK.W],8
	mov [eax+BRICK.H],6
	mov [eax+BRICK.ALIVE],1
	add eax, edx
	loop brick_init_loop
	
	ret
ENDP initialize_bricks
PROC update_bullet
	USES esi,eax ,ebx,ecx,edx,edi
	mov esi, offset bullet
	mov eax , [esi+BULLET.active]
	mov edx, offset safezone
	cmp eax,1
	jl exitbullet
    mov eax, [esi+BULLET.X]
	add eax, [esi+BULLET.velX]
	
	cmp eax,[edx]
	jl bullet_bounces_X
	cmp eax,[edx+4]
	jg bullet_bounces_X
	
	mov [esi+BULLET.X],eax
	return_bullet_x:
	mov eax, [esi+BULLET.Y]
	add eax, [esi+BULLET.velY]
	
	cmp eax,[edx+8]
	jl SHORT bullet_bounces_Y
	cmp eax,SCRHEIGHT
	jg SHORT bullet_bounces_Y
	
	mov [esi+BULLET.Y],eax
	jmp SHORT exitbullet
	
	bullet_bounces_X:
	mov edi, [esi+BULLET.bounces]
	cmp edi, 3
	jge bullet_leaves
	mov ebx, [esi+BULLET.velX]
	neg ebx
	mov [esi+BULLET.velX], ebx
	mov eax, [esi+BULLET.X]
	add eax, ebx
	mov [esi+BULLET.X],eax
	inc edi
	mov [esi+BULLET.bounces], edi
	
	jmp return_bullet_x
	
	bullet_bounces_Y:
	mov edi, [esi+BULLET.bounces]
	cmp edi, 3
	jge bullet_leaves
	mov ebx, [esi+BULLET.velY]
	neg ebx
	mov [esi+BULLET.velY], ebx
	mov eax, [esi+BULLET.Y]
	add eax, ebx
	mov [esi+BULLET.Y],eax
	inc edi
	mov [esi+BULLET.bounces], edi
	jmp exitbullet
	bullet_leaves:
	mov [esi+BULLET.active],0
	mov [esi+BULLET.bounces],0
	exitbullet:
	ret
ENDP update_bullet

PROC drawbrickentities
	USES eax,ebx,ecx,edx,edi,esi
	
	;mov esi, offset bricks
	xor esi,esi
	mov esi, offset bricks
	mov ecx, [brickamount]
	mov edx, [bricksize]
	
	drawloop:
	
	mov eax, [esi+BRICK.ALIVE]
	cmp eax,1
	jl check_return
	mov edi,[esi+BRICK.X]
	mov ebx,[esi+BRICK.Y]
	
	;call randBetweenVal,1,14
	call drawRectangle,[esi+BRICK.X],[esi+BRICK.Y],[esi+BRICK.W],[esi+BRICK.H],12
	check_return:
	add esi, edx
	loop drawloop
	mov esi, offset player
	call drawplayer,[esi+PLAYER.X],[esi+PLAYER.Y],[esi+PLAYER.COL]; draws new position
	mov edi, offset bullet
	mov eax, [edi+BULLET.active]
	cmp eax,1
	jl nobullet
	call drawDot,[edi+BULLET.X],[edi+BULLET.Y],1,1,[edi+BULLET.COL]
	nobullet:
	ret
ENDP drawbrickentities		
PROC respawnbricks; two ways to approach, either completely random, or as intended in the game, being that brick can only respawn if touching adjacent brick, now thats a tough one to solve aint gonna lie broski
	USES eax,ebx,ecx,edx,esi,edi
	mov esi, offset bricks
	mov ecx, [brickamount]
	mov edx, [bricksize]
	mov edi, offset player
	respawnloop:
	mov eax, [esi+BRICK.ALIVE]
	cmp eax, 1
	jge reenter_respawn_loop
	
	call collision, [esi + BRICK.X],[esi + BRICK.Y],[esi + BRICK.W],[esi + BRICK.H],[edi +PLAYER.X],[edi +PLAYER.Y],1,1,8
	cmp eax, 1
	jge reenter_respawn_loop
	mov ebx,[esi + BRICK.RES_CHANCE]
	call randBetweenVal,0,100
	cmp eax,ebx
	jge no_respawn
	mov [esi+BRICK.ALIVE],1
	
	jmp reenter_respawn_loop
	no_respawn:
	inc ebx
	mov [esi + BRICK.RES_CHANCE],1
	reenter_respawn_loop:
	add esi, edx
	loop respawnloop
	ret
ENDP respawnbricks
;PROC respawnbricks_correct
;	uses eax,ebx,ecx,edx,esi,edi
;	mov esi, offset bricks
;	mov ecx, [brickamount]
;	mov edx, [bricksize]
;	xor eax,eax ; will use eax to keep track of position
;	
;	respawnloop:
;	mov eax, [esi+BRICK.ALIVE]
;	cmp eax, 1
;	jge reenter_respawn_loop
;	cmp edx,144;insert 6*24
;	jl skip_up_check
;	mov ebx, offset bricks
;	mov edi, esi
;	sub edi, 144
;	add ebx, edi
;	mov edi,[ebx+BRICK.ALIVE]
;	cmp edi,1
;	jl left_check
;	inc [esi+BRICK.RES_CHANCE]
;	left_check:
;	mov ebx, offset bricks
;	mov edi, esi
;	sub edi, 24
;	add ebx, edi
;	mov edi,[ebx+BRICK.ALIVE]
;	cmp edi,1
;	jl right_check
;	inc [esi+BRICK.RES_CHANCE]
;	jl skip
;	
;	
;	
;	
;	
;	reenter_respawn_loop:
;	add esi, edx
;	loop respawnloop
;	ret
;ENDP respawnbricks_correct


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
	USES eax,ebx,ecx,edx,esi,edi
	mov eax, [safezone+8]
	mov ebx,[safezone+12]
	inc eax
	inc ebx
	mov [safezone+8],eax
	mov [safezone+12],ebx
	;add code here for the bricks
	xor eax,eax
	mov esi, offset bricks
	mov ecx, [brickamount]
	mov edx, [bricksize]
	lower_brick_loop:
	mov eax, [esi+BRICK.Y]
	add eax,1
	mov [esi+BRICK.Y],eax
	add esi, edx
	loop lower_brick_loop
	mov ebx, [rotatecount]
	cmp ebx,15; adjust value here to adjust speed of rotation
	jg rotate_tower
	inc ebx
	mov [rotatecount], ebx
	jmp skip_rotate
	rotate_tower:
	call rotatetower
	mov [rotatecount], 0
	skip_rotate:
	call respawnbricks
	ret
ENDP lowertower
PROC rotatetower
	USES eax, ebx, ecx, edx, esi, edi
	mov esi, offset bricks
	mov ecx, [brickamount]
	mov edx, [bricksize]
	rotate_loop:
	mov eax,[esi+BRICK.X]
	add eax, [esi+BRICK.W]
	cmp eax, [safezone+4]
	jge right_to_left
	mov [esi+BRICK.X],eax
	jmp skip_L_to_R
	right_to_left:
	mov ebx,[safezone]
	mov [esi+BRICK.X], ebx
	skip_L_to_R:
	add esi, edx
	loop rotate_loop

	ret
ENDP rotatetower
PROC checkbrickbulletcollision
	USES eax,ebx,ecx,edx,esi,edi
	mov esi, offset bricks
	mov ecx, [brickamount]
	mov edx, [bricksize]
	mov edi, offset bullet
	
	brickloop:
	mov eax,[edi +BULLET.active]
	cmp eax,1
	jl exit_bullet_collision
	mov eax, [esi+BRICK.ALIVE]
	cmp eax,1
	jge brick_alive
	;insert code for respawn right here
	jmp re_enterbrickloop
	brick_alive:
	call collision,[esi+BRICK.X],[esi+BRICK.Y],[esi+BRICK.W],[esi+BRICK.H],[edi +BULLET.X],[edi +BULLET.Y],1,1,1
	cmp eax,1
	jl re_enterbrickloop
	mov [esi+BRICK.ALIVE],0
	mov [edi+BULLET.active],0
	re_enterbrickloop:
	add esi, edx
	loop brickloop
	exit_bullet_collision:
	ret
ENDP checkbrickbulletcollision

PROC towergame
	ARG 	@@key:byte
	USES 	eax,ecx,edx, ebx,esi,edi	
	mov esi, offset player
;	call spiderterrain;paint the canvas
	mov ebx, offset safezone
	xor edx,edx
	towergameloop:
		call towerterrain; activate if want to clear behind character
		;mov ecx,[esi+PLAYER.X]
		;mov ebx,[esi+PLAYER.Y]
		
		call drawbrickentities
		call endcollisioncheck_bricks
		inc edx
		
		cmp edx,10; change the amount to change dificulty, will decide how often the whole shit descends
		jl continuegameloop
		mov edx,0
		call lowertower
		continuegameloop:
		
		call wait_VBLANK, 3
		mov ah, 01h ; function 01h (check if key is pressed)
		int 16h ; call keyboard BIOS
		;
		jz SHORT re_towergameloop;if key not pressed than there is a 0 flag ; SHORT means short jump (+127 or -128 bytes) solves warning message
		
		
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
		re_towergameloop:
		
		mov edi, offset bullet
	
		cmp [edi + BULLET.active], 0
		jg  MouseNC
		
		xor ecx, ecx
		xor edx, edx
		xor ebx,ebx
		mov  ax, 0003h  ; get mouse position and buttonstatus
		int  33h        ; -> BX CX DX
		
		test ebx, 1      ; check left mouse click
		jz SHORT MouseNC		; zero if no click
		shr ecx, 1
		
		;calculating normalized speed
		
		sub ecx, [esi + PLAYER.X];delta x
		sub ecx, eax
		
		sub edx, [esi + PLAYER.Y];delta y
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
		
		mov [edi + BULLET.velX], eax
		
		pop eax
		
		xor edx, edx ; set EDX to zero
		div ecx ; eax result, edx remainder (B/k = b)
		
		pop edx
		cmp edx, 0
		jge YPositive
		neg eax
		YPositive:
		
		mov [edi + BULLET.velY], eax
		
		mov eax,[esi+PLAYER.X]
		mov [edi + BULLET.X], 	eax	;first element in array is for player
		
		mov eax,[esi+PLAYER.Y]
		mov [edi + BULLET.Y], eax		;first element in array is for player
		
		mov [edi + BULLET.bounces], 0
		mov [edi + BULLET.active], 1
		
		MouseNC:
		call checkbrickbulletcollision
		call update_bullet
	jne	towergameloop ; if doesnt find anything restart
	
	UP:
	;xor al,al
	mov ecx,[esi+PLAYER.Y]
	cmp ecx,1 ; checks borders
	jl re_towergameloop
	
	dec ecx ; moves position
	mov [esi+PLAYER.Y],ecx
	jmp re_towergameloop ;returns to wait for keypress
	DOWN:
	mov ecx,[esi+PLAYER.Y]
	cmp ecx, SCRHEIGHT-1
	jge re_towergameloop
	inc ecx
	mov [esi+PLAYER.Y],ecx
	jmp re_towergameloop
	
	LEFT:
	mov ebx, offset safezone
	;xor al,al
	mov ecx, [esi+PLAYER.X]
	push eax
	mov eax, [ebx]
	inc eax
	cmp ecx, eax
	pop eax
	jl re_towergameloop
	
	dec ecx
	mov [esi+PLAYER.X],ecx
	jmp re_towergameloop
	
	RIGHT:
	mov ebx, offset safezone
	;xor al,al
	mov ecx,[esi+PLAYER.X]
	push eax
	mov eax, [ebx+4]
	dec eax
	cmp ecx, eax
	pop eax
	jge re_towergameloop
	inc ecx
	mov [esi+PLAYER.X],ecx
	jmp re_towergameloop
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
	X dd 0
	Y dd 0
	W dd 8
	H dd 6
	ALIVE dd 1; 1 will be for alive, 0 for dead
	RES_CHANCE dd 1
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
	COL 	dd 30
	W		dd 3
ENDS BULLET

DATASEG

	msg	db "Hello User! Welcome to the spider game, press any button to continue.", 13, 10, '$'
	
	palette		db 768 dup (?)
	player		PLAYER		1		dup(< ,,,>)
	playeramount dd 1;both this and the size shouldnt matter, atleast not how the procedures are set up now
	playersize dd 16;
	
	rotatecount dd 0
	
	
	playerspawn dd 160,180; stores position of player
	
	
	bricks		BRICK	18		dup(< ,,,>)
	brickamount dd 18
	bricksize dd 24
	brickmatrix dd 136,41,144,41,152,41,160,41,168,41,176,41,136,47,144,47,152,47,160,47,168,47,176,47,136,53,144,53,152,53,160,53,168,53,176,53
	
	bullet		BULLET 1		dup(<,,,,,,,>)
	
	
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