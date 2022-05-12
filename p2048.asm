
;*****************************************************
; author: Asif Solomon                               *
; 2048 game                                          *
;*****************************************************

jumps
IDEAL
MODEL small
STACK 100h

; colours definitions
;--------------------- 
BLACK_COLOR       equ 0
LIGHTGRAY_COLOR   equ 7

UP                equ 48h
DOWN              equ 50h
LEFT              equ 4Bh
RIGHT             equ 4Dh

P_ESCAPE          equ 1h
P_I               equ 17h
P_ENTER           equ 1Ch


;-------------------------------------------
; Macro: MACֹֹ_call3_times
;   macro to call a func as parameter 3 times and 
;clear the boolean area that present what is posible
; to merge and what no (due to privious merge on the same turn)
;-------------------------------------------
macro MACֹֹ_call3_times func_to_call
    call &func_to_call
	call &func_to_call
	call &func_to_call
	call clearBool
endm	

;-------------
; DATA SEGMET
;--------------
DATASEG            

; pictures bmp files definitions
;--------------------- 
img_1 db '1.bmp',0
img_2 db '2.bmp',0
img_3 db '3.bmp',0
img_4 db '4.bmp',0
img_5 db '5.bmp',0
img_6 db '6.bmp',0
img_7 db '7.bmp',0
img_8 db '8.bmp',0
img_9 db '9.bmp',0
img_10 db '10.bmp',0
img_11 db '11.bmp',0

; pages
img_lose db 'lose.bmp',0
img_win db 'win.bmp',0
img_inst db 'inst.bmp',0
img_home db 'home.bmp',0
img_game db 'game.bmp',0

; show bmp files helpers
;---------------------
filehandle dw ?
Header db 54 dup (0)
Palette db 256*4 dup (0)
ScreenLineMax db 320 dup (0)  ; One Color line read buffer
ErrorMsg db 'Error', 13, 10,'$'

; global vars to print bmp pics
;---------------------
BmpLeft dw ?
BmpTop dw ?
BmpColSize dw ?
BmpRowSize dw ?


; for indexing in game table
verticlal_size dw 45
horizontal_size dw 51
div4 db 4

lines db 16 dup(0)      ; 4 X 4 table
merge_bool db 16 dup(1) ; bool, 1 = possible to merge (privious merges)

was_change db 0  ; 0 no , 1 yes

; 0 = game, 1 = lose,2 = win, 3 = instruction
PageNum db 4 ; 4 = home , 5 = exit program

delay_time db 0 ; wait x/18.2 secs
;-------------
; CODE SEGMET
;--------------
CODESEG


;***********************************************************
; fllowing procs for display image						   *
;***********************************************************

; input :
;	1. BmpLeft offset from left (where to start draw the picture) 
;	2. BmpTop offset from top
;	3. BmpColSize picture width 
;	4. BmpRowSize bmp height 
;	5. dx offset to file name with zero at the end 
;
; output : display image in the input position
proc OpenShowBmp
	push cx                   ; save
	push bx
	
	call OpenBmpFile
	call ReadBmpHeader
	
	; from  here assume bx is global param with file handle. 
	call ReadBmpPalette
	call CopyBmpPalette
	call ShowBMP
	call CloseBmpFile

	pop bx                    ; restore
	pop cx
	ret
endp OpenShowBmp

; open a file
; input: dx = filename to open
proc OpenBmpFile
	
	mov ah, 3Dh
	xor al, al
	int 21h
	jc ErrorAtOpen            ; if was error
	mov [filehandle], ax
	jmp ExitProc
	
ErrorAtOpen:
	mov dx, offset ErrorMsg
	mov ah, 9h
	int 21h                   ; print error message
	
ExitProc:	
	ret
endp OpenBmpFile
 
 
; Close file. Bx = file handle
proc CloseBmpFile
	mov ah,3Eh
	mov bx, [filehandle]
	int 21h
	ret
endp CloseBmpFile


; Read 54 bytes the Header
proc ReadBmpHeader					
	push cx
	push dx
	
	mov ah,3fh
	mov bx, [FileHandle]
	mov cx,54
	mov dx,offset Header
	int 21h                    ; read cx bytes to [dx]
	
	pop dx
	pop cx
	ret
endp ReadBmpHeader



; Read BMP file color palette, 256 colors * 4 bytes (400h)
; 4 bytes for each color BGR + null)
proc ReadBmpPalette      			
	push cx
	push dx
	
	mov ah,3fh
	mov cx,400h
	mov dx,offset Palette
	int 21h                    ; read cx bytes to [dx]
	
	pop dx
	pop cx
	
	ret
endp ReadBmpPalette

; Will move out to screen memory the colors
; video ports are 3C8h for number of first color
; and 3C9h for all rest
proc CopyBmpPalette					
										
	push cx
	push dx
	
	mov si,offset Palette
	mov cx,256
	mov dx,3C8h
	mov al,0  ; black first							
	out dx,al ;3C8h
	inc dx	  ;3C9h
CopyNextColor:
	mov al,[si+2] 		; Red				
	shr al,2 			; divide by 4 Max (cos max is 63 and we have here max 255 ) (loosing color resolution).				
	out dx,al 						
	mov al,[si+1] 		; Green.				
	shr al,2            
	out dx,al 							
	mov al,[si] 		; Blue.				
	shr al,2            
	out dx,al 							
	add si,4 			; Point to next color.  (4 bytes for each color BGR + null)				
								
	loop CopyNextColor
	
	pop dx
	pop cx
	
	ret
endp CopyBmpPalette

; show image
proc ShowBMP 
; BMP graphics are saved upside-down.
; Read the graphic line by line (BmpRowSize lines in VGA format),
; displaying the lines from bottom to top.
	push cx
	
	mov ax, 0A000h
	mov es, ax
	
	mov cx,[BmpRowSize]
	
	mov ax,[BmpColSize] ; row size must dived by 4 so if it less we must calculate the extra padding bytes
	xor dx,dx
	mov si,4
	div si
	mov bp,dx
	
	mov dx,[BmpLeft]
	
NextLine:
	push cx
	push dx
	
	mov di,cx  ; Current Row at the small bmp (each time -1)
	add di,[BmpTop] ; add the Y on entire screen
	
 
	; next 5 lines  di will be  = cx*320 + dx , point to the correct screen line
	mov cx,di
	shl cx,6
	shl di,8
	add di,cx
	add di,dx
	
	; small Read one line
	mov ah,3fh
	mov cx,[BmpColSize]  
	add cx,bp  ; extra  bytes to each row must be divided by 4
	mov dx,offset ScreenLineMax
	int 21h
	; Copy one line into video memory
	cld ; Clear direction flag, for movsb
	mov cx,[BmpColSize]  
	mov si,offset ScreenLineMax
	rep movsb ; Copy line to the screen
	
	pop dx
	pop cx
	 
	loop NextLine
	
	pop cx
	ret
endp ShowBMP 



;***********************************************************
; Procedure: HLine                                         *
;  This procedure draws an horizontal line according to a  *
;  given location.                                         *
;                                                          *
;  Input parametrs:                                        *
;   1. [bp+10] - x first pixel  (left column)              *
;   2. [bp+ 8] - x last pixel   (right column)             *
;   3. [bp+ 6] - row number                                *
;   4. [bp+ 4] - color                                     *
;                                                          *
;***********************************************************

proc HLine
	push bp           
	mov bp,sp

	; save registers
	push ax                
	push bx
	push cx
	push dx
	
	mov cx, [bp+10]          ; x 1st (left) pixel to draw, used also as loop counter 
	
HLoop:
	  mov ah, 0ch              ; int 10h/0ch
	  mov bx, [bp+4]           ; color -> al 
	  mov al, bl 		       ; 
	  mov dx, [bp+6]	       ; raw  -> dx
	  int 10h                  ; draw the pixel 
	  inc cx
	  cmp cx, [bp+8]	         ; x first == x last 
	  jbe HLoop                ; if below or equal do additional iteration

	; restore registers 	
	pop dx            
	pop cx
	pop bx
	pop ax
	
	pop bp
	
	ret 8
endp HLine



;***********************************************************
; Procedure: PrintRect                                   *
;                                                          *
;  This procedure draws square ( or rectangular) according *
;  x, y location and height/width                          *
;                                                          *
;  Input parametrs:                                        *
;   1. [bp+12] - x first pixel  (1st col)                  *
;   2. [bp+10] - y first pixel  (lst row )                 *
;   3. [bp+ 8] - square/rect width  (x first+width)        *
;   4. [bp+ 6] - square/rect. height (y first+height)      *
;   5. [bp+ 4] - color                                     *
;                                                          *
;***********************************************************
proc PrintRect
    ; lower x: bp+12
	; lower y: bp+10
	; width :  bp+8
	; height:  bp+6
	; color:   bp+4
	
    push bp
	mov bp, sp
	
	push ax                 ; save registers
	push cx
	push di
	
	mov ax, [bp + 12]       ; get X first location (most left)
	add ax, [bp + 8]        ; last X =  X first + Width -> ax
	 
	mov di, [bp + 10]       ; Y first to di 
	mov cx, [bp + 6]        ; height -> cx for loop counting
	
PrintRect_loop:
	push [bp+ 12]           ; x first 
    push ax                 ; x last 
    push di	                ; y (row number)
	push [bp + 4]           ; color
	 
	call HLine              ; draw single hor. line
	inc di                  ; inc y value
    loop PrintRect_loop    ; go print new hor. line 
	
	pop di                  ; restore registers
	pop cx
	pop ax
	
	pop bp

	ret 10  
endp PrintRect


;***********************************************************
; indexes:												   *
; 0  1  2  3                                               *
; 4  5  6  7                                               *
; 8  9  10 11                                              *
; 12 13 14 15               							   *
;***********************************************************

;***********************************************************
; Procedure: checkLose                                     *
;                                                          *
;  This procedure checks if the are no moves               *
;  output: page number = 1(if lose)                        *
;***********************************************************

proc checkLose

	push ax					; save registers
	push bx				 	
	push cx


	mov cx,9            	; loop 9 times
	mov bx, offset lines 	; index of squares
	
	loop_checkL:
		mov al,[byte bx] 	; curr color
		cmp al,BLACK_COLOR  ; is black?
		je endCheckLose
		
		mov ah,[byte bx+1]  ; right color
		cmp al,ah           ; merge?
		je endCheckLose
		
		cmp ah,BLACK_COLOR  ; is black?
		je endCheckLose
		
		mov ah,[byte bx+4]  ; down color
		cmp al,ah           ; merge?
		je endCheckLose
		
		cmp ah,BLACK_COLOR  ; is black?
		je endCheckLose
		
		
	check_next:	
		inc bx			 	; next index
		mov ax,bx           ; index
		sub ax,offset lines
		
		div [div4]          ; ah = ax mod 4, al = ax div 4
		cmp ah,3            ; bx = last in row
		je check_next
		
		loop loop_checkL
	
	
	; check remaining sqares
	mov al,[byte lines+15]
	cmp al,[byte lines+11]  ; merge?
	je endCheckLose
	
	cmp al,BLACK_COLOR
	je endCheckLose         ; is black?
	
	cmp al,[byte lines+14]  ; merge?
	je endCheckLose         
	
	mov al,[byte lines+13]
	cmp al,[byte lines+14]  ; merge?
	je endCheckLose
	
	cmp al,[byte lines+12]  ; merge?
	je endCheckLose
	
	mov al,[byte lines+7]
	cmp al,[byte lines+3]  ; merge?
	je endCheckLose
	
	cmp al,[byte lines+11]  ; merge?
	je endCheckLose
	
	mov [PageNum],1
	
endCheckLose:	
	pop cx			     	; restore registers
	pop bx
	pop ax
	
	ret
endp checkLose

;***********************************************************
; Procedure: movRight                                      *
;                                                          *
;  This procedure handle right press key                   *
;  Should be called 3 times                                *
;  output: update the array and if change                  *
;***********************************************************

proc movRight

	push ax					; save registers
	push bx				 	
	push cx
	push dx
	push si

	mov cx,12            	; loop 12 times
	mov bx, offset lines 	; index of squares
	xor si,si               ; si = 0
	
	loop_right:
		mov al,[byte bx] 	; curr color
		cmp al,BLACK_COLOR  ; if curr == black: stay
		je right_stay
		
		mov ah,[byte bx+1]  ; next color
		cmp al,ah           ; if merge
		je merge_right
		
	
		cmp ah,BLACK_COLOR  ; if next == black: stay
		jne right_stay
		
		mov [byte bx+1],al 	; move right
		mov [byte bx],BLACK_COLOR
		
		mov dl,[merge_bool+si] ; update bool array so it stay (merge or not)
		mov [merge_bool+si+1],dl
		
		mov [was_change],1    ; for random
		jmp right_stay
		
	merge_right:
		mov dl,[merge_bool+si+1] ; dl = to merge
		cmp dl,0                 ; if not to merge
		je right_stay            ; do not merge
		mov dl,[merge_bool+si]   ; dl = to merge
		cmp dl,0                 ; if not to merge
		je right_stay            ; do not merge
		
		inc al				; merge color
		mov [byte bx+1],al 	; next color
		mov [byte bx],BLACK_COLOR
		mov [merge_bool+si],0    ; not merge
		mov [merge_bool+si+1],0  ; not merge

		mov [was_change],1  ; for random
		
	right_stay:	
		inc si              ; next index
		inc bx			 	; next index
		mov ax,bx           ; index
		sub ax,offset lines
		
		div [div4]          ; ah = ax mod 4, al = ax div 4
		cmp ah,3            ; bx = last in row
		je right_stay
		
		loop loop_right
		
	pop si					; restore registers
	pop dx
	pop cx			     	
	pop bx
	pop ax
	
	ret
endp movRight


;***********************************************************
; Procedure: movLeft                                       *
;                                                          *
;  This procedure handle left press key                    *
;  Should be called 3 times                                *
;  output: update the array and if change                  *
;***********************************************************

proc movLeft
	
	push ax					; save registers
	push bx				 	
	push cx
	push dx
	push si

	mov cx,12            	; loop 12 times
	mov bx, offset lines 	; index of squares
	add bx,15				; last index
	mov si,15               ; si = 15(last index)
	
	loop_left:
		mov al,[byte bx] 	; curr color
		cmp al,BLACK_COLOR  ; black?
		je left_stay
		
		mov ah,[byte bx-1]  ; next color
		cmp al,ah			; merge?
		je merge_left
		
		
		cmp ah,BLACK_COLOR  ; black?
		jne left_stay
		
		mov [byte bx-1],al 	 ; move left
		mov [byte bx],BLACK_COLOR
		
		mov dl,[merge_bool+si] ; update merge_bool
		mov [merge_bool+si-1],dl
		
		mov [was_change],1    ; was change
		jmp left_stay

	merge_left:
		mov dl,[merge_bool+si-1] ; dl = to merge
		cmp dl,0                 ; if not to merge
		je left_stay             ; do not merge
		
		mov dl,[merge_bool+si]   ; dl = to merge
		cmp dl,0                 ; if not to merge
		je left_stay             ; do not merge
	
		inc al					 ; merge color
		mov [byte bx-1],al 		 ; next color
		mov [byte bx],BLACK_COLOR
		mov [merge_bool+si],0    ; not merge
		mov [merge_bool+si-1],0  ; not merge
		mov [was_change],1       ; was change
	left_stay:	
		dec si              ; next index
		dec bx			 	; next index
		mov ax,bx           ; index
		sub ax,offset lines
		
		cmp ax,0
		je Divby0_left      ; to not divide by 0
		div [div4]          ; ah = ax mod 4, al = ax div 4
		cmp ah,0            ; bx = last in row
		je left_stay
		
	Divby0_left:
		loop loop_left
		
	pop si					; restore registers
	pop dx
	pop cx			     	
	pop bx
	pop ax
	
	ret 
endp movLeft



;***********************************************************
; Procedure: movUp                                         *
;                                                          *
;  This procedure handle up press key                      *
;  Should be called 3 times                                *
;  output: update the array and if change                  *
;***********************************************************
proc movUp

	push ax					; save registers
	push bx				 	
	push cx
	push dx
	push si

	mov cx,12            	; loop 12 time
	mov bx, offset lines 	; index of squares
	add bx,15               ; last square
	mov si,15               ; si = 15
	
	
	loop_up:
		mov al,[byte bx] 	; curr color
		cmp al,BLACK_COLOR  ; black?
		je up_stay
		
		mov ah,[byte bx-4]  ; next color
		cmp al,ah           ; merge up?
		je merge_up
		
		cmp ah,BLACK_COLOR  ; next black?
		jne up_stay
		
		mov [byte bx-4],al 	; move up
		mov [byte bx],BLACK_COLOR
		
		mov dl,[merge_bool+si]  ; move not merge up
		mov [merge_bool+si-4],dl
		mov [was_change],1      ; was change 

		jmp up_stay
		
	merge_up:
		mov dl,[merge_bool+si-4] ; dl = to merge
		cmp dl,0                 ; if not to merge
		je up_stay               ; do not merge
	
		mov dl,[merge_bool+si]   ; dl = to merge
		cmp dl,0                 ; if not to merge
		je up_stay               ; do not merge
	
		inc al					 ; merge color
		mov [byte bx-4],al 		 ; next color
		mov [byte bx],BLACK_COLOR
		mov [merge_bool+si],0    ; not to merge
		mov [merge_bool+si-4],0  ; not to merge
		
		mov [was_change],1
	up_stay:
		dec si              ; next index
		dec bx			 	; next index
		loop loop_up
		
		
	pop si					; restore registers
	pop dx
	pop cx			     	
	pop bx
	pop ax
	
	ret
endp movUp


;***********************************************************
; Procedure: movDown                                       *
;                                                          *
;  This procedure handle down press key                    *
;  Should be called 3 times                                *
;  output: update the array and if change                  *
;***********************************************************
proc movDown

	push ax					; save registers
	push bx				 	
	push cx
	push dx
	push si

	mov cx,12            	; loop 12 times
	mov bx, offset lines 	; index of squares
	xor si,si               ; si = 0
	
	loop_down:
		mov al,[byte bx] 	; curr color
		cmp al,BLACK_COLOR  ; black?
		je down_stay
		
		mov ah,[byte bx+4]  ; next color
		cmp al,ah           ; merge down?
		je merge_down
		
		
		cmp ah,BLACK_COLOR  ; down black?
		jne down_stay
		
		mov [byte bx+4],al 	; move down
		mov [byte bx],BLACK_COLOR
		
		mov dl,[merge_bool+si]  ; move merge bool down
		mov [merge_bool+si+4],dl
		
		mov [was_change],1      ; was change
		jmp down_stay
		
	merge_down:
		mov dl,[merge_bool+si+4] ; dl = to merge
		cmp dl,0                 ; if not to merge
		je down_stay             ; do not merge
	
		mov dl,[merge_bool+si]   ; dl = to merge
		cmp dl,0                 ; if not to merge
		je down_stay             ; do not merge
	
		inc al					 ; merge color
		mov [byte bx+4],al 		 ; next color
		mov [byte bx],BLACK_COLOR
		mov [merge_bool+si],0    ; not merge
		mov [merge_bool+si+4],0  ; not merge
		mov [was_change],1
	down_stay:
		inc si              ; next index
		inc bx			 	; next index
		loop loop_down
		
	pop si					; restore registers
	pop dx
	pop cx			     	
	pop bx
	pop ax
	
	ret  
endp movDown


;***********************************************************
; Procedure: paintAll                                      *
;                                                          *
;  This procedure paint the board by the array of lines    *
;***********************************************************


proc paintAll

	push ax                  ; save registers
	push bx
	push cx
	push dx
	
	
	mov bx, offset lines
	mov cx,16            ; 16 times loop
	add bx,15            ; last index
	
loop_all:
	dec cx               ; index 15 to 1
	xor dx,dx            ; dx = 0
	mov ax,cx            ; ax = cx
	div [div4]           ; ah = cx mod 4, al = cx div 4
	mov dl,ah
	
	xor ah, ah           ; ax = al
	
	push dx              ; i value ah
	push ax              ; j value al
	
	mov al,[byte bx]     ; al = color of current index
	push ax              ; color value
	
	call paintSquareBoard 

	dec bx               ; next index (last to first)

	cmp cx,0
	jne loop_all
	
	
	pop dx 				 ; restore registers
	pop cx					
	pop bx
	pop ax
	
	ret  
endp paintAll


;***********************************************************
; Procedure: paintSquareBoard                              *
;                                                          *
;  This procedure paint squre according to index i index j *
;  and number (2,4,8,16....2048) repesnts by numbers       *
;  1=2,2=4,3=8,4=16,5=32,6=64,7=128......                  *
;  Input parametrs:                                        *
;   1. [bp+ 8] - index i(0 - 3)                            *
;   2. [bp+ 6] - index j(0 - 3)                            *
;   3. [bp+ 4] - color(number)                             *
;                                                          *
;***********************************************************

proc paintSquareBoard 
    push bp
	mov bp, sp
	
	push ax                  ; save registers
	push bx
	push cx
	
	mov bx, 30               ; 30 - 81 - 132 - 183 (paint 51)
	mov cx, 12               ; 12 - 57 - 102 - 147 (paint 45)

	
	mov ax, [bp+ 8]
	mul [horizontal_size]    ; index i * 51
	add bx,ax                ; 82 + index i * 51

	mov ax, [bp+ 6]
	mul [verticlal_size]     ; index j * 45
	add cx,ax                ; 32 + index i * 45
	
	mov ax,[bp+ 4]           ; color
   
	
	cmp ax,BLACK_COLOR       ; if black               
	jne not_0
	push bx                  ; X start location
	push cx                  ; Y start location
	push 47                  ; Line width
	push 43                  ; Line height
	push BLACK_COLOR
	call PrintRect           ; black Square
	jmp endPaint
	
not_0:
	dec cx         ; fix for image
	mov [BmpLeft],bx
	mov [BmpTop],cx
	mov [BmpColSize],48
	mov [BmpRowSize],43
	
;************************
; move to dx the image
;************************
	cmp ax,1
	jne not_1

	mov dx,offset img_1
	jmp Pimg
not_1:
	cmp ax,2
	jne not_2
	mov dx, offset img_2
	jmp Pimg
not_2:
	cmp ax,3
	jne not_3
	mov dx, offset img_3
	jmp Pimg
not_3:
	cmp ax,4
	jne not_4
	mov dx, offset img_4
	jmp Pimg
not_4:
	cmp ax,5
	jne not_5
	mov dx, offset img_5
	jmp Pimg
not_5:
	cmp ax,6
	jne not_6
	mov dx, offset img_6
	jmp Pimg
not_6:
	cmp ax,7
	jne not_7
	mov dx, offset img_7
	jmp Pimg
not_7:
	cmp ax,8
	jne not_8
	mov dx, offset img_8
	jmp Pimg
not_8:
	cmp ax,9
	jne not_9
	mov dx, offset img_9
	jmp Pimg
not_9:
	cmp ax,10
	jne not_10
	mov dx, offset img_10
	jmp Pimg
not_10:
	mov dx, offset img_11
	mov [PageNum],2
Pimg:
	call OpenShowBmp
	
endPaint:	
	pop cx					 ; restore registers
	pop bx
	pop ax
	
	pop bp
	ret 6  
endp paintSquareBoard 


;***********************************************************
; Procedure: clearBool                                    *
;                                                          *
;  This procedure clear the bool array                     *
;***********************************************************

proc clearBool

	push si              ; save registers
	push cx
	
	
	mov cx,16             ; 16 times loop
	xor si,si             ; si = 0
loop_clear:
	mov [merge_bool+si],1 ; 1 is default
	inc si                ; next index
	loop loop_clear
	
	pop cx				  ; restore registers
	pop si

	ret  
endp clearBool


;---------------------------------
; new random (0-15) at free place
;---------------------------------
proc Rand 
	push bx			   ; save
    push ax    
	push si
	push cx
	push dx
	
    mov ah, 00
    int 1Ah            ; read time
    and dl, 00001111b  ; rand 0-15
	xor dh,dh          ; dl = 0-15
    mov si,dx          ; first index to check
	
put_square:
    cmp [lines+si],BLACK_COLOR ; free square?
	jne next_square
	
	dec dx      ; dx--
	cmp dl,0    ; search for the x free square in order to find random (without new number)
	jne next_square
	
	mov [delay_time],4  ; delay 4/18.2 sec
	call Delay
	
	mov [lines+si],1    ; new square
	jmp end_rand
	
next_square:	
    inc si         ; next index
	cmp si,16
	jne put_square
	xor si,si      ; si=0
	
	jmp put_square

end_rand:

	pop dx        ; restore
	pop cx 
	pop si
	pop ax
	pop bx
    ret
    
endp Rand

;----------------
; Delay 
;----------------
proc Delay 
    push ax    ; save
	push bx
	push cx
	push dx
	
    mov ah, 00
    int 1Ah          ; read time
    mov bx, dx
    
jmp_delay:
    int 1Ah          ; read time
    sub dx, bx
    ;there are about 18 ticks in a second, 10 ticks are about enough
    cmp dl, [delay_time]                                                    
    jl jmp_delay 

	pop dx ; restore
	pop cx 
	pop bx
	pop ax
    ret
endp Delay


;***********************************************************
; Procedure: gameW                                         *
;                                                          *
;  This procedure handles game window                      *
;***********************************************************

proc gameW
	mov [PageNum],0   ; page = game (maybe is not essential)
	
	; display home
	mov [BmpLeft],0
	mov [BmpTop],0
	mov [BmpColSize],320
	mov [BmpRowSize],200
	mov dx, offset img_game
	call OpenShowBmp
	
	; clear the board for reuse
	mov cx,16
	xor si,si
	
	clear_board:
		mov [lines+si],BLACK_COLOR
		inc si
		loop clear_board
	
	
	;draw the board (4X4)
	
	mov cx,5        ; 4 on 4
	mov ax,10       ; ax = 10
	mov bx,27       ; bx = 27
	
	draw_board:
		
		; horizontal
		push 27                  ; X start location
		push ax                  ; Y start location
		push 206                 ; Line length
		push 2                   ; Line width              
		push LightGray_COLOR     ; color of line 
		call PrintRect
		
		add ax,45                ; 10 - 55 - 100 - 145 - 190
		
		push bx                  ; X start location
		push 10                  ; Y start location
		push 2                   ; Line length
		push 182                 ; Line width              
		push LightGray_COLOR     ; color of line 
		call PrintRect
		
		add bx,51				 ; 27 - 78 - 129 - 180 - 231
		
		loop draw_board


; first item
mov [lines],1
mov [lines+1],1

loop_gameW:
	call paintAll   ; update board by array
	
	; if was change put new item
	cmp [was_change],1
	jne no_rand
	call Rand
	call paintAll
	mov [was_change],0

no_rand:
	call checkLose   ; return to PageNum 1 if lose
	cmp [PageNum],0
	je game
	
	jmp finish_game
	
; handles keys
game:	
	xor ah, ah 		
	int 16h
	
	cmp ah,RIGHT
	jne not_right	; If 'right' is not pressed, continue.
	
	MACֹֹ_call3_times movRight
	
	jmp loop_gameW

not_right:
	cmp ah,DOWN
	jne not_down	; If 'down' is not pressed, continue.

	MACֹֹ_call3_times movDown
	jmp loop_gameW
	
not_down:
	cmp ah,LEFT
	jne not_left	; If 'left' is not pressed, continue.

	MACֹֹ_call3_times movLeft
	jmp loop_gameW
	
not_left:
	cmp ah,UP
	jne not_up	; If 'up' is not pressed, continue.

	MACֹֹ_call3_times movUp
	jmp loop_gameW
	
not_up:
	cmp ah, P_ESCAPE			
	jne loop_gameW	; If 'esc' is not pressed
	mov [PageNum],4
	
	
finish_game:
	ret
endp gameW


;***********************************************************
; Procedure: homeW                                         *
;                                                          *
;  This procedure handles home window                      *
;***********************************************************
proc homeW

	;display home
	mov [BmpLeft],0
	mov [BmpTop],0
	mov [BmpColSize],320
	mov [BmpRowSize],200
	mov dx, offset img_home
	call OpenShowBmp
	
	
; handles keys	
home:	
	xor ah, ah 		
	int 16h
	

	cmp ah,P_I
	jne not_i   	; If 'i' is not pressed, continue.
	mov [PageNum],3
	jmp finish_home
	
not_i:
	cmp ah, P_ENTER
	jne home_not_enter	; If 'enter' is not pressed, continue.
	mov [PageNum],0
	jmp finish_home
	
home_not_enter:
	cmp ah, P_ESCAPE			
	jne home	    ; If 'esc' is pressed
	mov [PageNum],5
	
	
finish_home:
	ret
endp homeW


;***********************************************************
; Procedure: instW                                         *
;                                                          *
;  This procedure handles instructions window              *
;***********************************************************
proc instW

	; display instructions
	mov [BmpLeft],0
	mov [BmpTop],0
	mov [BmpColSize],320
	mov [BmpRowSize],200
	mov dx, offset img_inst
	call OpenShowBmp
	
; handles keys
inst:	
	xor ah, ah 		
	int 16h
	
	cmp ah, P_ESCAPE			
	je finish_inst	; If 'esc' is pressed, quit the program.
	jmp inst
	
	
finish_inst:
	mov [PageNum],4
	ret
endp instW



;***********************************************************
; Procedure: endW                                          *
;                                                          *
;  This procedure handles end window                       *
;  input: dx = offset img                                  *
;***********************************************************
proc endW
	
	; wait 24/18.2 secs
	mov [delay_time],24
	call Delay

	; display win/lose
	mov [BmpLeft],0
	mov [BmpTop],0
	mov [BmpColSize],320
	mov [BmpRowSize],200
	call OpenShowBmp
	
	
; handles keys
endWloop:	
	xor ah, ah 		
	int 16h
	
	cmp ah,P_ENTER
	jne end_not_enter
	mov [PageNum],0
	jmp finish_end
	
end_not_enter:
	cmp ah, P_ESCAPE			
	jne endWloop	; If 'esc' is not pressed
	mov [PageNum],4
	
finish_end:
	ret
	
endp endW



;-----------------
; MAIN 
;----------------- 
start:
    mov ax, @data
    mov ds, ax
	
		
	; set Graphic mode
    mov ax, 13h
    int 10h 

;***********************************************************
; PageNum:                                                 *
;                                                          *
;  0 = game window                                         *
;  1 = lose window                                         *
;  2 = win window                                          *
;  3 = instructions window                                 *
;  4 = home window (default)                               *
;  5 = esc                                                 *
;***********************************************************

pages:
	cmp [PageNum],0
	jne no_game
	call gameW
	
no_game:
	cmp [PageNum],1
	jne no_lose
	mov dx,offset img_lose
	call endW
	
no_lose:
	cmp [PageNum],2
	jne no_win
	mov dx,offset img_win
	call endW
no_win:
	cmp [PageNum],3
	jne no_inst
	call instW
no_inst:
	cmp [PageNum],4
	jne not_home
	call homeW
not_home:
	cmp [PageNum],5
	je exit_2048
	jmp pages
	
exit_2048:
	
; set Text mode
    mov ax, 03h
    int 10h
		
exit:
    mov ax, 4c00h
    int 21h

END start
