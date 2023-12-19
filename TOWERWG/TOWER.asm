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

INCLUDE "generic.inc"

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height

TOWER_SIZE EQU 60 * 20
PLAYER_SIZE EQU 5*5
TOW_H EQU 20
TOW_W EQU 60
PLAY_H EQU 5
PLAY_W EQU 5

TOWER_SPEED EQU 6  ; decides how fast the tower descends, the lower the number the faster it descends, and thus the harder the game
ROTATE_SPEED EQU 3;decides how fast the tower rotates, the lower the number the faster rotation 

RAND_A = 1103515245
RAND_C = 12345
CODESEG



PROC towerterrain
	USES eax,ebx,esi,edx,ecx
	mov esi, offset safezone
	mov eax,[esi+4];takes largest x-valkue
	mov edx,[esi]
	sub eax,edx;finds the width of the safezone
	mov ebx,[esi+12];take the largest y-value
	mov ecx,[esi+8]
	sub ebx,ecx;finds the height
	
	call fillBackground, 16
	
	add ecx,ebx
	inc ecx
	call drawFilledRectangle,edx,ecx,eax,SCRHEIGHT,15; draw the white path on which we play
	dec ecx
	sub ecx,ebx
	;call drawFilledRectangle,edx,ecx,eax,ebx,10; need to find color for green, this rectangle will be safe zone/victory zone 
	call DrawIMG, offset tower_safezone_read,edx,ecx,TOW_W,TOW_H
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
	call ReadFile, offset player_file, offset player_read, PLAYER_SIZE
	call ReadFile, offset tower_safezone_file, offset tower_safezone_read, TOWER_SIZE
	
	
	call initialize_bricks
	call towergame,001Bh
	ret
ENDP setuptower

PROC endcollisioncheck_bricks; checks the conditions for the win, sure its manual but seems cho to me tbh
	USES ebx,ecx,edx,esi,edi
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
	mov eax, 1 ; 1 = win
	jmp exit_collision
	
	
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
	mov eax,2; 2 meaning no end condition hit
	jmp exit_collision
	defeat:
	mov eax,0; 0 = loss
	
	exit_collision:
	ret
ENDP endcollisioncheck_bricks

PROC initialize_bricks; can also do this just usning a matrix, and would be a lot less of a headache ptn
	USES eax,ebx,ecx,edx,edi,esi
	mov edi, offset bricks
	mov ebx, offset brickmatrix
	mov ecx, [brickamount]
	mov edx, [bricksize]; doint it statically rn, to save edx and headache
	brick_init_loop:
	mov esi,[ebx]
	mov [edi+BRICK.X],esi
	add ebx,4
	mov esi,[ebx]
	mov [edi+BRICK.Y],esi
	add ebx,4
	mov [edi+BRICK.W],10
	mov [edi+BRICK.H],10
	mov [edi+BRICK.ALIVE],1
	call randBetweenVal,2,12
	mov [edi +BRICK.COL],eax
	add edi, edx
	loop brick_init_loop
	
	ret
ENDP initialize_bricks

PROC update_bullet
	USES esi,eax ,ebx,ecx,edx,edi
	mov esi, offset bullet
	mov eax, [esi+BULLET.active]
	mov edx, offset safezone
	cmp eax, 1
	jl SHORT exitbullet
    mov eax, [esi+BULLET.X]
	add eax, [esi+BULLET.velX]
	
	cmp eax,[edx]
	jl bullet_bounces_X
	cmp eax,[edx+4]
	jl return_bullet_x
	
	bullet_bounces_X:
	mov edi, [esi+BULLET.bounces]
	cmp edi, 3
	jge SHORT bullet_leaves
	mov ebx, [esi+BULLET.velX]
	neg ebx
	mov [esi+BULLET.velX], ebx
	mov eax, [esi+BULLET.X]
	add eax, ebx
	mov [esi+BULLET.X],eax
	inc edi
	mov [esi+BULLET.bounces], edi
	
	return_bullet_x:
	
	mov [esi+BULLET.X],eax
	
	mov eax, [esi+BULLET.Y]
	add eax, [esi+BULLET.velY]
	
	cmp eax,[edx+8]
	jl SHORT bullet_bounces_Y
	cmp eax,SCRHEIGHT
	jg SHORT bullet_bounces_Y
	
	mov [esi+BULLET.Y],eax
	jmp SHORT exitbullet
	
	
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
	mov esi, offset bricks
	mov ecx, [brickamount]
	mov edx, [bricksize]
	
	drawloop:
	
	mov eax, [esi+BRICK.ALIVE]
	cmp eax,1
	jl check_return
	mov edi,[esi+BRICK.X]
	mov ebx,[esi+BRICK.Y]
	
	call drawFilledRectangle,[esi+BRICK.X],[esi+BRICK.Y],[esi+BRICK.W],[esi+BRICK.H],[esi+BRICK.COL]
	check_return:
	add esi, edx
	loop drawloop
	mov esi, offset player
	call DrawIMG,offset player_read, [esi+PLAYER.X],[esi+PLAYER.Y],PLAY_W,PLAY_H; draws new position
	mov edi, offset bullet
	mov eax, [edi+BULLET.active]
	cmp eax,1
	jl nobullet
	call drawDot,[edi+BULLET.X],[edi+BULLET.Y],[edi+BULLET.COL]
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
	
	call collision, [esi + BRICK.X],[esi + BRICK.Y],[esi + BRICK.W],[esi + BRICK.H],[edi +PLAYER.X],[edi +PLAYER.Y],1,1,15; moe hier nog even deftige waarden uitrekenen
	cmp eax, 1
	jge reenter_respawn_loop
	mov ebx,[esi + BRICK.RES_CHANCE]
	call randBetweenVal,0,100
	cmp eax,ebx
	jge no_respawn
	mov [esi+BRICK.ALIVE],1
	mov [esi + BRICK.RES_CHANCE],0
	jmp reenter_respawn_loop
	no_respawn:
	inc ebx
	mov [esi + BRICK.RES_CHANCE],ebx ; zou dit niet moet stijgen met ebx ?? deze moet ook reset worden als de block respawned
	reenter_respawn_loop:
	add esi, edx
	loop respawnloop
	ret
ENDP respawnbricks

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

	mov esi, offset bricks
	mov ecx, [brickamount]
	mov edx, [bricksize]
	lower_brick_loop:
	mov eax, [esi+BRICK.Y]
	inc eax
	mov [esi+BRICK.Y],eax
	add esi, edx
	loop lower_brick_loop
	mov ebx, [rotatecount]
	cmp ebx,ROTATE_SPEED; adjust value here to adjust speed of rotation
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
	cmp eax,0
	je re_enterbrickloop
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
	USES 	ecx,edx, ebx,esi,edi	
	mov esi, offset player
	mov ebx, offset safezone
	xor edx,edx
	towergameloop:
		xor eax,eax
		call towerterrain; activate if want to clear behind character
		
		call drawbrickentities
		call endcollisioncheck_bricks
		cmp eax, 2
		jl exit
		inc edx
		call wait_VBLANK, 2
		call checkbrickbulletcollision
		cmp edx,TOWER_SPEED; change the amount to change dificulty, will decide how often the whole shit descends
		jl continuegameloop	; edx start bij 0 dan word 1 en dan als het kleiner is dan 10 opnieuw 0?? (btw deze jump is de reden dat de tower plotseling trager naar beneden ging)
		mov edx,0																						 ;(edx wordt wss ergens verandert waardoor het enkel gebeurde wanneer de bullet geactiveerd werd)
		call lowertower
		continuegameloop:
		
		
		mov ah, 01h ; function 01h (check if key is pressed)
		int 16h ; call keyboard BIOS
		;
		jz SHORT re_towergameloop;if key not pressed than there is a 0 flag ; SHORT means short jump (+127 or -128 bytes) solves warning message
		
		
		mov ah, 00h ;get key from buffer (ascii code in al)
		int 16h
		
		
		
		cmp	al,[@@key]; checks to see if we ditch program
		je exit_esc
		cmp al,122; inset code for (W,) Z want in azerty 
		
		je UP
		cmp al,115; checks to see for S
		je DOWN
		cmp al,113; checks for Q
		je LEFT
		cmp al,100; checks for D		; gaat moeten geswitched worden naar azerty je kan 'd' gebruiken voor de keycode ipv een getal
		je RIGHT
		re_towergameloop:
		push edx
		mov edi, offset bullet
		; getting an error here that the bullet slows down the tower relative to when there is no bullet present
		; cant seem to find where=> will keep bullet alive, yet throw it to 1,1 with 0 velocity if it is 
		cmp [edi + BULLET.active], 0
		jg  MouseNC
		
		xor ecx, ecx
		xor edx, edx
		xor ebx, ebx
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
		jmp skip_MouseNC
		MouseNC:
		;call wait_VBLANK,4; tried adding this to compensate for the large gap in speed, somewhat works
		skip_MouseNC:
		call update_bullet
		pop edx
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
	exit_esc:
	mov eax,2
	exit:
	mov [edi + BULLET.active],0
	mov edi, offset safezone
	mov ebx, offset safezone_start
	mov esi, [ebx]
	mov [edi],esi
	mov esi, [ebx+4]
	mov [edi+4],esi 
	mov esi, [ebx+8]
	mov [edi+8],esi
	mov esi,[ebx+12]
	mov [edi+12], esi
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
	call setuptower
	
	mov ah,00h
	int 16h
	call terminateProcess

; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------

; if add spider as struct: only need 2 pieces of info on spider, namely position, in x and y, and if alive doesnt matter=> insta respawn at start position spider
STRUC BRICK
	X dd 0
	Y dd 0
	W dd 10
	H dd 10
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
	COL 	dd 1
	W		dd 3
ENDS BULLET

DATASEG

	msg	db "Hello User! Welcome to the tower game, press any button to continue.", 13, 10, '$'
	
	player		PLAYER		1		dup(< ,,,>)
	playeramount dd 1;both this and the size shouldnt matter, atleast not how the procedures are set up now
	playersize dd 16;
	
	rotatecount dd 0
	
	
	playerspawn dd 160,180; stores position of player
	
	
	bricks		BRICK	18		dup(< ,,,>)
	brickamount dd 18
	bricksize dd 24
	brickmatrix dd 130,41,140,41,150,41,160,41,170,41,180,41,130,52,140,52,150,52,160,52,170,52,180,52,130,63,140,63,150,63,160,63,170,63,180,63
	
	bullet		BULLET 1		dup(<,,,,,,,>)
	
	safezone_start dd 130,190,20,40
	safezone dd 130,190,20,40 ; sets the boundaries for the x value and y value for the winzone, first two being lower and upper x and last two being lower and upper y
	; width of safezone needs to be a 6 times width of bricks
	victory db "you won!", 13, 10, '$'
	
	lossmessage db "you lost!", 13, 10, '$'
	
	randSeed		dd			2003630
	tower_safezone_file db "safe.bin", 0
	player_file db "player.bin", 0
	openErrorMsg db "could not open file", 13, 10, '$'
	readErrorMsg db "could not read data", 13, 10, '$'
	closeErrorMsg db "error during file closing", 13, 10, '$'
	
	
UDATASEG
	tower_safezone_read db TOWER_SIZE dup (?)
	player_read db PLAYER_SIZE dup (?)
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END start