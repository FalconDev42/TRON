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

INCLUDE "generic.inc"
INCLUDE "spider.inc"
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
	USES ebx, ecx, edx, edi, esi
	;call setVideoMode,13h
	
	;push ds
	;pop es
	
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
	
	call initialize_spider_player,160,160; sets start point of player
	
	call randomize_spawn; assign semi random spawn points to the spiders
	call initialize_spider_spider; set the spiders on alive and assign them their spawns
	
	call spiderterrain
	
	call spidergame,001Bh;  exit button on esc

	ret
ENDP setupspider

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
	arg @@Start_X:dword, @@Start_Y:dword
	USES eax,ebx,esi
	mov eax, [@@Start_X]
	mov ebx, [@@Start_Y]
	mov esi, offset player
	mov [esi+player.X],eax
	mov [esi+player.Y],ebx
	mov [esi +player.ALIVE],1
	mov [esi+player.COL],1
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
	X dd 160
	Y dd 160
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
	
	
	playerpos dd 100,100; stores position of player
	
	
	
	spiders 	SPIDER		9		dup	(<,,,,,>)
	
	spideramount dd 9; stores amount of spiders
	spidersize dd 24
	
	
	bullet 		BULLET		1	dup	(<,,,,,,,>)
	BulletSize	 	dd 			36
	TotalOfBullets	dd			5
	
	
	spiderpos dd 150,90,160,90,170,90,150,50,160,50,170,50,140,70,180,70,160,100; contains the starting x followed by y positions of first the player,and than each spider, will also be used to assing the respawn points of the spiders
	safezone dd 150,170,60,80 ; sets the boundaries for the x value and y value for the winzone, first two being lower and upper x and last two being lower and upper y
	
	victory db "you won!", 13, 10, '$'
	
	lossmessage db "you lost!", 13, 10, '$'
	
	randSeed		dd			2003630
	spider_file db "spider.bin", 0
	player_file db "player.bin", 0
	
	
UDATASEG
	spiderread db IMGSIZE dup (?)
	playerread db IMGSIZE dup (?)


END