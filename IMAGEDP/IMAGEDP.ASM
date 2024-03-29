; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	David Blinder
; date:		
; program:	Simple image load and display for mode 13h
;
; image source: https://www.pxfuel.com/en/free-photo-obrvr
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height

BIKERW EQU 5
BIKERH EQU 11

IMGSIZE EQU BIKERW*BIKERH

; -------------------------------------------------------------------
CODESEG


; Halt program until keystroke is pressed.
MACRO waitForKeystroke
	mov	ah,00h
	int	16h
ENDM waitForKeystroke

; terminate if key is pressed
PROC terminateAfterKeystroke
	USES eax
	mov	ah, 01h
	int	16h
	jz @@charfound
	ret
	
@@charfound:
	call terminateProcess
ENDP terminateAfterKeystroke


PROC terminateProcess
	USES eax
	call setVideoMode, 03h
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess

; -------------------------------------------------------------------

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

PROC setVideoMode
	ARG 	@@VM:byte
	USES 	eax

	movzx ax,[@@VM]
	int 10h

	ret
ENDP setVideoMode

PROC DrawBG
	ARG	 @@dataptr: dword 
	USES esi,edi,ecx
	mov esi, [@@dataptr]
	mov edi, VMEMADR
	mov ecx, IMGSIZE
	rep movsb	
	ret	
ENDP DrawBG

PROC DrawIMG
	ARG	 @@IMGPtr: dword, @@x:dword, @@y:dword, @@w:dword, @@h:dword
	USES esi, edi, ecx, eax, edx
	
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

PROC main
	sti
	cld
	
	push ds
	pop	es
	call setVideoMode, 13h
	call ReadFile, offset ennemyFile, offset ennemyIMG, IMGSIZE
	
	
	call rotateIMG, offset ennemyIMG, offset ennemyIMGH, BIKERW, BIKERH
	
	
	;call DrawBG, offset dataread
	
	call DrawIMG, offset ennemyIMG, 25, 25, BIKERW, BIKERH
	
	call DrawIMG, offset ennemyIMGH, 60, 25, BIKERH, BIKERW
	
	waitForKeystroke	
	call terminateProcess

ENDP main

; -------------------------------------------------------------------
DATASEG
ennemyFile db "biker.bin", 0

openErrorMsg db "could not open file", 13, 10, '$'
readErrorMsg db "could not read data", 13, 10, '$'
closeErrorMsg db "error during file closing", 13, 10, '$'



UDATASEG
ennemyIMG db IMGSIZE dup (?)
ennemyIMGH db IMGSIZE dup (?)
; -------------------------------------------------------------------
STACK 100h

END main
