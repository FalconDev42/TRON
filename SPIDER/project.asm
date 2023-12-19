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
;INCLUDE "spider.inc"
; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height

IMGSIZE EQU 5*5
SPID_H EQU 5
SPID_W EQU 5
PLAY_H EQU 5
PLAY_W EQU 5
SPIDER_TRUE_MOVE EQU 2; gives the ratio of true moves a spider makes out of ten, higher number = more true moves

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
	
PROC updatespider_bullet; controls behaviour of spiders, dead and alive, and bullet while active 
    USES eax, ebx, esi, edx,ecx,edi
    mov ebx, offset player;gets player position
    mov ecx, [spideramount]; counter for the amount of spiders we will iterate over
    ;mov ecx, ecx    ; The counter for the loop
    mov esi, offset spiders
	mov eax, 0
	mov edi, [spidersize]
    updateloop:
		mov eax, [esi+SPIDER.ALIVE]
		cmp eax, 1; check to see if spider is alive, if not reset x and y to spawn locations, if want to completely randomize this can write new function
		
		jge spider_alive
		jmp respawn_spider; had to use a jump, otherwise loop would become too large
		spider_alive:
		
		mov edx,offset bullet
		mov eax, [edx+BULLET.active]
		cmp eax,1; now check to see if bullet active, if not can skip whole collision action
		jl nocollision
		
		call collision,[esi+SPIDER.X],[esi+SPIDER.Y],1,1,[edx+BULLET.X], [edx+BULLET.Y],1,1,3; check for collision between spider and bullet
		
		cmp eax, 1
		jl nocollision
		mov [esi+SPIDER.ALIVE],0	;if hit set alive for spider to 0, dead, and active for bullet to 0, inactive
		mov [edx+BULLET.active],0
		
	
		nocollision:; from here starts movement sequence 
		call randBetweenVal, 0, 10 ; find random value between 0 and 10, to decide whether movement in x-axis random or not
		cmp eax, SPIDER_TRUE_MOVE; can change value here to change percentage of true or random moves
		jl truemove_x
		jge randommove_x
		
		RETURN_X_CHECK:
		
		call randBetweenVal, 0, 10
		cmp eax, SPIDER_TRUE_MOVE; can change value here to change percentage of true or random moves
		jl truemove_y
		jge randommove_y
		
		RETURN_Y_CHECK:
   		reenterupdateloop:
        add esi, edi

		loop updateloop;having the loop here is tooo far away, so need to work around it
		
        jmp  exitspider
		
		truemove_x:
		mov edx, [esi + SPIDER.X] 
		cmp edx,[ebx + PLAYER.X]; checks if player is left or right of spider
		jg movespiderLEFT
		jl movespiderRIGHT
		jmp RETURN_X_CHECK
		
		randommove_x:
		mov edx, [esi + SPIDER.X]
		call randBetweenVal, 0, 4
		cmp eax, 2
		jl movespiderLEFT
		jge movespiderRIGHT
		
		truemove_y:
		mov edx, [esi + SPIDER.Y]
		cmp edx, [ebx + PLAYER.Y]; checks if spider height is lower or greater than playerheight
		jl movespiderDOWN
		jg movespiderUP
		jmp RETURN_Y_CHECK
		
		randommove_y:
		mov edx, [esi + SPIDER.Y]
		call randBetweenVal, 0, 4
		cmp eax,2
		jl movespiderUP
		jge movespiderDOWN
		
		movespiderLEFT:
		dec edx
		cmp edx, 3
		jl RETURN_X_CHECK
		mov [esi+SPIDER.X],edx
		jmp RETURN_X_CHECK
		
		movespiderRIGHT:
		inc edx
		cmp edx, SCRWIDTH-3
		jge RETURN_X_CHECK
		mov [esi+SPIDER.X],edx
		jmp RETURN_X_CHECK
		
		movespiderDOWN:
		inc edx
		cmp edx, SCRHEIGHT -3
		jge RETURN_Y_CHECK
		mov [esi+SPIDER.Y],edx
		jmp RETURN_Y_CHECK
		
		movespiderUP:
		dec edx
		cmp edx, 3
		jl RETURN_Y_CHECK
		mov [esi+SPIDER.Y],edx
		jmp RETURN_Y_CHECK
		
		respawn_spider:
		call randomize_spawn
		call collision,[esi+SPIDER.RES_X],[esi+SPIDER.RES_Y],1,1,[ebx + PLAYER.X],[ebx + PLAYER.Y],1,1,15
		cmp eax,1
		jge reenterupdateloop
		mov [esi+SPIDER.ALIVE],1; set spider on alive
		mov eax, [esi+SPIDER.RES_X]
		mov [esi+SPIDER.X],eax
		mov eax , [esi+SPIDER.RES_Y]
		mov [esi+SPIDER.Y],eax
		jmp spider_alive
		exitspider:
	;bullet
	mov esi, offset bullet
	mov eax , [esi+BULLET.active]
	cmp eax,1
	jl exitbullet
    mov eax, [esi+BULLET.X]
	add eax, [esi+BULLET.velX]
	
	cmp eax,0
	jl bullet_leaves
	cmp eax,SCRWIDTH
	jg bullet_leaves
	
	mov [esi+BULLET.X],eax
	
	mov eax, [esi+BULLET.Y]
	add eax, [esi+BULLET.velY]
	
	cmp eax,0
	jl SHORT bullet_leaves
	cmp eax,SCRHEIGHT
	jg SHORT bullet_leaves
	
	mov [esi+BULLET.Y],eax
	jmp SHORT exitbullet
	
	
	bullet_leaves:
	mov [esi+BULLET.active],0
	
	exitbullet:
	ret
ENDP updatespider_bullet




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
PROC spiderterrain; draws the terrain around the map
	USES eax,ebx,esi,edx,ecx
	mov esi, offset safezone
	mov eax,[esi+4];takes largest x-valkue
	mov edx,[esi]
	sub eax,edx;finds the width of the safezone
	mov ebx,[esi+12];take the largest y-value
	mov ecx,[esi+8]
	sub ebx,ecx;finds the height
	
	call fillBackground,0
	call drawFilledRectangle,edx,ecx,eax,ebx,10; need to find color for green, this rectangle will be safe zone/victory zone 
	ret
ENDP spiderterrain

PROC setupspider ; set up the game, this proc is mainly used as to keep the main clean
	call setVideoMode,13h
	NoMouse:
	mov  ax, 0000h  ; reset mouse
	int  33h        ; -> AX BX
	cmp  ax, 0FFFFh
	jne  NoMouse
	mov  ax, 0001h  ; show mouse
	int  33h
	;read data to draw the spider and player
	call ReadFile, offset player_file, offset playerread, IMGSIZE 
	call ReadFile, offset spider_file, offset spiderread, IMGSIZE 
	
	call initialize_spider_player; sets start point of player
	
	call randomize_spawn; assign semi random spawn points to the spiders
	call initialize_spider_spider; set the spiders on alive and assign them their spawns
	
	call spiderterrain
	
	call spidergame,001Bh;  exit button on esc
	ret
ENDP setupspider



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

PROC randomize_spawn
	USES eax,ebx,ecx,edx,esi,edi
	mov esi, offset spiders
	mov edi, offset spiderpos
	mov ecx, [spideramount]
	mov ebx, [spidersize]
	spider_rand_spawn_loop:
		mov edx,[edi]
		sub edx,10; add this step because randbetweenval cant give negative(i think not sure)
		call randBetweenVal,0,20
		add edx,eax
		cmp edx,1
		jl base_X; base being the starting position assigned in the array spiderpos
		cmp edx, SCRWIDTH-1
		jg base_X
		mov [esi +SPIDER.RES_X], edx
		jmp exit_X
		
		base_X:
		mov edx,[edi]
		mov [esi +SPIDER.RES_X], edx
		
		exit_X:
	
		add edi,4
		mov edx,[edi]
		sub edx,10
		call randBetweenVal,0,20
		add edx,eax
		cmp edx,1
		jl base_Y; base being the starting position assigned in the array spiderpos
		cmp edx, SCRHEIGHT-1
		jg base_X
		mov [esi +SPIDER.RES_Y], edx
		jmp exit_Y
	
		base_Y:
		mov edx,[edi]
		mov [esi +SPIDER.RES_Y], edx
		
		exit_Y:
		
		add edi,4
		
		add esi, ebx; iterate to the next spider
	
	loop spider_rand_spawn_loop
	ret

ENDP randomize_spawn




PROC initialize_spider_spider; will read from an array, and set semi random start positions for the spiders
	USES eax,ebx,ecx,edx,esi,edi
	mov esi, offset spiders
	mov ecx, [spideramount]
	mov ebx, [spidersize]
	spider_init_loop:
		mov eax, [esi+SPIDER.RES_X]
		mov [esi+SPIDER.X],eax
		mov eax , [esi+SPIDER.RES_Y]
		mov [esi+SPIDER.Y],eax
		mov [esi+SPIDER.ALIVE],1; set spider on alive
		add esi, ebx
	loop spider_init_loop
	ret
ENDP initialize_spider_spider
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

PROC checkendcollision; will be used to check collision for victory det, collision of player with spiders and for collision between bullet and spiders
	USES ebx,ecx,edx,esi,edi
	mov esi,offset player
	mov eax,offset safezone
	
	mov edx,[eax+4]
	mov ecx,[eax]
	sub edx,ecx
	mov edi,[eax+12]
	mov ebx,[eax+8]
	sub edi,ebx
	
	
	
	call collision,ecx,ebx,edx,edi,[esi+PLAYER.X], [esi+PLAYER.Y],1,1,2
	cmp eax,1
	jl no_victory_collision
	mov eax,1
	jmp exit_collision
	no_victory_collision:
	mov edi,offset spiders
	mov ecx,[spideramount]
	mov edx,[spidersize]
	
	spider_check_loop:
	mov eax, [edi+SPIDER.ALIVE]
	cmp eax,1
	jl dead_spider
	call collision,[edi+SPIDER.X],[edi+SPIDER.Y],1,1,[esi+PLAYER.X], [esi+PLAYER.Y],1,1,3
	cmp eax,1
	jge defeat
	dead_spider:
	add edi, edx
	loop spider_check_loop
	mov eax,2 
	jmp exit_collision
	defeat:
	mov eax,0
	exit_collision:
	ret
ENDP checkendcollision


PROC initialize_spider_player; give the correct starting
	USES eax,ebx,esi,edx
	mov eax, offset playerpos
	mov esi, offset player
	mov edx,[eax]
	mov [esi+PLAYER.X],edx
	add eax,4
	mov edx, [eax]
	mov [esi+PLAYER.Y],edx
	mov [esi +PLAYER.ALIVE],1
	mov [esi+PLAYER.COL],1
	ret
ENDP initialize_spider_player
PROC spidergame
	ARG 	@@key:byte
	USES 	 ebx,esi,edi	
	mov esi, offset player
	mov edi, offset bullet
	spidergameloop:
		xor eax, eax 
		call spiderterrain; activate if want to clear behind character 
		call DrawEntities
		call checkendcollision
		cmp eax, 2
		jl exit
		
		call wait_VBLANK, 2
		mov ah, 01h ; function 01h (check if key is pressed)
		int 16h ; call keyboard BIOS
		
		jz SHORT re_spidergameloop;if key not pressed than there is a 0 flag ; SHORT means short jump (+127 or -128 bytes) solves warning message
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
		re_spidergameloop:
		
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
		call updatespider_bullet
		
	jne	spidergameloop ; if doesnt find anything restart
	
	UP:
	;xor al,al
	mov ecx,[esi+PLAYER.Y]
	cmp ecx,3 ; checks borders
	jl re_spidergameloop
	
	dec ecx ; moves position
	mov [esi+PLAYER.Y],ecx
	jmp re_spidergameloop ;returns to wait for keypress
	DOWN:
	mov ecx,[esi+PLAYER.Y]
	cmp ecx, SCRHEIGHT-3
	jge re_spidergameloop
	inc ecx
	mov [esi+PLAYER.Y],ecx
	jmp re_spidergameloop
	
	LEFT:
	;xor al,al
	mov ecx, [esi+PLAYER.X]
	cmp ecx,3
	jl re_spidergameloop
	
	dec ecx
	mov [esi+PLAYER.X],ecx
	jmp re_spidergameloop
	
	RIGHT:
	;xor al,al
	mov ecx,[esi+PLAYER.X]
	cmp ecx, SCRWIDTH-3
	jge re_spidergameloop
	inc ecx
	mov [esi+PLAYER.X],ecx
	jmp re_spidergameloop
	exit:
	mov [edi + BULLET.active],0
	ret
ENDP spidergame

PROC DrawEntities
	USES eax,esi,ecx,edx,ebx,edi
	mov esi, offset spiders
	mov ecx, [spideramount]
	mov edx, [spidersize]
	
	spiderdrawloop:
	mov eax, [esi+SPIDER.ALIVE]; check if alive
	cmp eax,1
	jl no_draw_spider
	
	mov edi, [esi+SPIDER.X]
	sub edi, 2; to get the topleft corner
	mov ebx,[esi+SPIDER.Y]
	sub ebx, 2
	call DrawIMG, offset spiderread, edi, ebx, SPID_W, SPID_H
	no_draw_spider:
	add esi, edx
	loop spiderdrawloop
	
	
	
	mov esi, offset player
	
	mov edi, [esi+PLAYER.X]
	sub edi, 2; to get the topleft corner
	mov ebx,[esi+PLAYER.Y]
	sub ebx, 2
	call DrawIMG, offset playerread, edi, ebx, PLAY_W, PLAY_H
	
	mov esi, offset bullet
	mov eax, [esi+BULLET.active]
	cmp eax, 1
	jl bullet_inactive
	call drawDot, [esi+BULLET.X],[esi+BULLET.Y],15
	bullet_inactive:
	ret
ENDP DrawEntities

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
	call setupspider
	call setVideoMode,3h
	cmp eax,1
	je win
	jl loss
	jmp no_message
	
	win:
	mov ah, 09h
	mov edx,offset victorymessage
	int 21h
	jmp no_message
	loss:
	mov ah, 09h
	mov edx, offset lossmessage
	int 21h
	no_message:
	mov ah,00h
	int 16h
	
	call terminateProcess

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
	RES_CHANCE dd 0; implement a chance for respawn instead of just instant res
	COL dd 1
ENDS SPIDER

STRUC PLAYER
	X dd 0;160
	Y dd 0;160
	ALIVE dd 1
	COL dd 15
ENDS PLAYER

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
	
	
	playerpos dd 160,160; stores position of player
	
	
	
	spiders 	SPIDER		9		dup	(<,,,,,>)
	
	spideramount dd 9; stores amount of spiders
	spidersize dd 24
	
	
	bullet 		BULLET		1	dup	(<,,,,,,,>)
	BulletSize	 	dd 			36
	TotalOfBullets	dd			5
	
	
	spiderpos dd 150,90,160,90,170,90,150,50,160,50,170,50,140,70,180,70,160,100; contains the starting x followed by y positions of first the player,and than each spider, will also be used to assing the respawn points of the spiders
	safezone dd 150,170,60,80 ; sets the boundaries for the x value and y value for the winzone, first two being lower and upper x and last two being lower and upper y
	
	victorymessage db "you won!", 13, 10, '$'
	
	lossmessage db "you lost!", 13, 10, '$'
	
	randSeed		dd			2003630
	spider_file db "spider.bin", 0
	player_file db "player.bin", 0
	openErrorMsg db "could not open file", 13, 10, '$'
	readErrorMsg db "could not read data", 13, 10, '$'
	closeErrorMsg db "error during file closing", 13, 10, '$'
	
	
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