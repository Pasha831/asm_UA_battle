CODE_SEG	SEGMENT
    ASSUME	CS:CODE_SEG,DS:CODE_SEG,SS:CODE_SEG
    ORG	100H
    .386

    START:
    jmp begin

    ;;; old vectors
        old_1Ch dd ?
        int_2Fh_vector DD ?
        old_09h DD ?
    ;;;

    ;;; flags used in program
        flag_off    DB  0
        flag DB 0
    ;;;

    ;;; messages to store
        msg         DB  'already '
        msg1        DB  'installed',13,10,'$'
        msg4        DB  'just '
        msg3        DB  'not '
        msg2        DB  'uninstalled',13,10,'$'
        key DB '/off'
        game_over_message db "GAME OVER."
    ;;;

    ;;; other variables
        is_all_bombs_dropped db 1
        is_game_over db 0
        count dw 0  
        seed	dw 2
    ;;;

    ;;; car variables
		last_row dw 80*2*23
        left_wheel db 5
        car_length dw 5
		car db "====="
    ;;;
	
	;;; plane variables
		is_plane_in_sky db 0
		tail db 0
		plane_speed dw 0
		plane_row db 0
		plane db "\==="
		plane_count dw 0
	;;;
	
	bomb_struct struc
		is_activated db 0
		row db 0
		shift dw 0
        body db '0'
        position dw 0
	bomb_struct ends
	
	bomb1 bomb_struct <>
    bomb2 bomb_struct <>
    bomb3 bomb_struct <>
    bomb4 bomb_struct <>
    bomb5 bomb_struct <>

    push_all_regs macro
        push	AX
        push	BX
        push	CX
        push	DX
    endm

    pop_all_regs macro
        pop		DX
        pop		CX
        pop		BX
        pop		AX
    endm

    Print_Word_dec	macro	src
        local	l1, l2, ex
        push DS
        push CS
        pop DS
        
        push_all_regs

            mov		AX,	src					;	Выводимое число в регисте EAX
            push		-1					;	Сохраним признак конца числа
            mov		cx,	10					;	Делим на 10
        l1:	
            xor		dx,	dx					;	Очистим регистр dx 
            div		cx						;	Делим 
            push		DX						;	Сохраним цифру
            or 			AX,	AX				;	Остался 0? (это оптимальнее, чем  cmp	ax,	0 )
            jne		l1						;	нет -> продолжим
            mov		ah,	2h
        l2:	
            pop		DX						;	Восстановим цифру
            cmp		dx,	-1					;	Дошли до конца -> выход {оптимальнее: or EDX,dx jl ex}
            je			ex
            add		dl,	'0'					;	Преобразуем число в цифру
            int		21h						;	Выведем цифру на экран
            jmp	l2							;	И продолжим
        ex:
        
        print_letter ' '
        pop_all_regs
        pop DS
    endm

    rand8	proc near
		mov	AX,		word ptr	seed
		mov	CX,		8	

        newbit:	
            mov	BX,		AX
            and	BX,		002Fh
            xor	BH,	BL
            clc
            jpe	shift_
            stc
            shift_:	
                rcr	AX,	1
        loop	newbit

        mov	word	ptr	seed,	AX
        mov	AH,	0  ; rand only in AL!
        ret
    rand8 endp
    
    print_letter	macro	letter
        push	AX
        push	DX
        mov	DL, letter
        mov	AH,	02
        int	21h
        pop	DX
        pop	AX
    endm

    print_mes	macro	message
        local	msg, nxt
        push	AX
        push	DX
        mov	DX, offset msg
        mov	AH,	09h
        int	21h
        pop	DX
        pop	AX
        jmp nxt
        msg	DB message,'$'
        nxt:
	endm

    print PROC NEAR
        MOV AH, 09H
        INT 21H
        RET
    print ENDP

    clean_screen proc near
        mov ah, 06h
        mov al, 0
        mov bh, 00h
        mov ch, 0
        mov cl, 0
        mov dh, 23
        mov dl, 80
        int 10h

        ret
    endp
	
	print_road proc near
        mov ax, 0B800h
		mov es, ax
		mov di, last_row
		mov cx, 80
		build_road:
			mov es:di, '='
			mov es:di + 1, 70h
			add di, 2
		loop build_road

        mov di, last_row
        sub di, 160
        mov cx, 5
        build_obstacle1:
            mov es:di, '#'
            mov es:di + 1, 70h
            add di, 2
        loop build_obstacle1

        mov di, last_row
        sub di, 10
        mov cx, 5
        build_obstacle2:
            mov es:di, '#'
            mov es:di + 1, 70h
            add di, 2
        loop build_obstacle2

        ret
    endp

    print_car proc near
		;;; print the main body of the car
			mov al, 0
			mov bh, 0
			mov bl, 09h
			mov cx, cs:car_length
			mov dl, cs:left_wheel
			mov dh, 21
			push cs
			pop es
			mov bp, offset cs:car
			mov ah, 13h
			int 10h
		;;;
		
		;;; set es on B800h
			mov ax, 0B800h
			mov es, ax
		;;;
		
		;;; assign di on the last row
			mov di, last_row
			sub di, 160
		;;;
		
		;;; skip the loop if left_wheel == 0
			cmp left_wheel, 0
			je skip
			mov cl, left_wheel
			left_loop:
				inc di
				inc di
			loop left_loop
		;;;
		
		skip:
		;;; display left wheel
			mov es:di, '0'
			mov es:di + 1, 0Eh
		;;;
		;;; display right wheel
			mov es:di + 8, '0'
			mov es:di + 9, 0Eh
		;;;
        ret
    endp
	
	generate_plane proc near
		mov cs:tail, 0
		mov cs:plane_count, 0
	
		;;; assign a flying echelon for a plane (0 - 8)
			call rand8
			mov bl, 9
			div bl
			mov plane_row, ah
		;;;
		
		;;; assign a speed to a plane (1 - 9)
			call rand8
			mov bl, 2
			div bl
			mov al, ah
			xor ah, ah
			mov cs:plane_speed, ax
			inc cs:plane_speed
		;;;
	    ret
	endp
	
	print_plane proc near
		;;; cs -> ds
			push ds
			push cs
			pop ds
		;;;
		
		;;; print the main body of the plane
			mov al, 0
			mov bh, 0
			mov bl, 0Ch
			mov cx, 4
			mov dl, tail
			mov dh, plane_row
			push cs
			pop es
			mov bp, offset plane
			mov ah, 13h
			int 10h
		;;;
		
		cmp tail, 76
		je exit2
		
		mov dx, plane_speed
		;Print_Word_dec plane_speed
		cmp plane_count, dx
		jne skip1
			inc tail
			mov plane_count, 0
		
		skip1:
		inc plane_count
		jmp exit1

		
		exit2:
			mov is_plane_in_sky, 0
		
		exit1:
		pop ds
	    ret
	endp

    generate_bomb macro bomb, shift_, row_
        local skip4, alter_the_position

        mov bomb.is_activated, 1

        mov ah, row_
		mov bomb.row, ah
        inc bomb.row

        call rand8
        mov bl, 15
        div bl
        mov al, ah
        xor ah, ah
        add ax, shift_
        mov bomb.shift, ax

        mov bomb.position, 0
        cmp bomb.row, 0
        je skip4
        mov cl, bomb.row
        alter_the_position:
            add bomb.position, 160
        loop alter_the_position

        skip4:
        mov ax, bomb.shift
        add ax, bomb.shift
        add bomb.position, ax
    endm

    print_bomb macro bomb
        local skip5
        ;;; cs -> ds
			push ds
			push cs
			pop ds
		;;;

        push_all_regs

        mov ax, 0B800h
        mov es, ax

        cmp bomb.row, 23
        je skip5

        mov di, bomb.position
        mov es:di, '0'
        mov es:di + 1, 0Fh

        add bomb.position, 160
        inc bomb.row

        skip5:
        pop_all_regs
        pop ds
    endm

    is_touched macro bomb
        local skip1

        cmp bomb.row, 21
        jne skip1

        mov al, left_wheel
        cbw
        cmp bomb.shift, ax
        jl skip1

        add ax, 4
        cmp bomb.shift, ax
        jg skip1

        mov dl, 1

        skip1:
    endm

    show_game_over proc near
        ;;; set DS on CS
            push DS
            push CS
            pop DS
        ;;;

        ;;; print the main body of the car
			mov al, 0
			mov bh, 0
			mov bl, 02h
			mov cx, car_length
			mov dl, left_wheel
			mov dh, 21
			push cs
			pop es
			mov bp, offset car
			mov ah, 13h
			int 10h
		;;;
		
		;;; set es on B800h
			mov ax, 0B800h
			mov es, ax
		;;;
		
		;;; assign di on the last row
			mov di, last_row
			sub di, 160
		;;;
		
		;;; skip the loop if left_wheel == 0
			cmp left_wheel, 0
			je skipp
			mov cl, left_wheel
			left_loopp:
				inc di
				inc di
			loop left_loopp
		;;;
		
		skipp:
		;;; display left wheel
			mov es:di, '0'
			mov es:di + 1, 02h
		;;;
		;;; display right wheel
			mov es:di + 8, '0'
			mov es:di + 9, 02h
		;;;

        mov ax, 0B800h
        mov es, ax
        mov di, 2*80*11 + 2*35
        lea bx, game_over_message
        mov cx, 10
        printCyclee:
            mov al, [bx]
            mov ah, 04h

            mov es:[di], ax

            inc bx
            add di, 2
        loop printCyclee

        push ds
        ret
    endp

    new_1Ch proc far
        ;;; set DS on CS
            push DS
            push CS
            pop DS
        ;;;

        call clean_screen
		call print_road
		call print_car

		;;; if no plane in sky - do not print it
		cmp is_plane_in_sky, 0
		je skip3
			call print_plane
		;;;
		skip3:

        ;;; show the bombs
        cmp is_all_bombs_dropped, 1
        je skip6
            ;;; if the last bomb have touched the ground?
                cmp bomb5.row, 23
                jne continue
                    mov is_all_bombs_dropped, 1
                    jmp skip6
            ;;;
            continue:

            mov al, tail
            cbw

            cmp ax, bomb1.shift
            jl to1
            print_bomb bomb1

            to1:
            cmp ax, bomb2.shift
            jl to2
            print_bomb bomb2

            to2:
            cmp ax, bomb3.shift
            jl to3
            print_bomb bomb3

            to3:
            cmp ax, bomb4.shift
            jl to4
            print_bomb bomb4

            to4:
            cmp ax, bomb5.shift
            jl to_hell
            print_bomb bomb5

            to_hell:
        skip6:
        ;;;
		
        ;;; if game is over (some bomb destroyed the vehicle)
        cmp is_all_bombs_dropped, 1
        je continue1
            xor dl, dl
            
            is_touched bomb1
            cmp dl, 1
            je isOver

            is_touched bomb2
            cmp dl, 1
            je isOver

            is_touched bomb3
            cmp dl, 1
            je isOver

            is_touched bomb4
            cmp dl, 1
            je isOver

            is_touched bomb5
            cmp dl, 1
            je isOver

            jmp notIsOver

            isOver:
                mov is_game_over, 1
            
            notIsOver:
        ;;;

        ;;; is game over?
        cmp is_game_over, 1
        jne continue1
            call show_game_over
            mov ax, 0C701h
            int 2Fh
        ;;;
        continue1:

        inc count
        mov cx, 18
        cmp count, cx
        jne nig
			;;; checking for existing plane / generating a new one
			cmp is_plane_in_sky, 0
			jne skip2
            cmp is_all_bombs_dropped, 1
            jne skip2
				call generate_plane  ; first things first!

                generate_bomb bomb1, 0, plane_row
                generate_bomb bomb2, 15, plane_row
                generate_bomb bomb3, 30, plane_row
                generate_bomb bomb4, 45, plane_row
                generate_bomb bomb5, 60, plane_row

                mov is_all_bombs_dropped, 0
				mov is_plane_in_sky, 1
			;;;
			
			skip2:
			mov count, 0
	
        nig:
        pop DS
        jmp dword ptr cs:[old_1Ch]
    endp

    new_09h proc far
        push ax
        pushf

        xor ax, ax
        in al, 60h
		cmp al, 77
		je right
		cmp al, 75
		je left
		cmp al, 28
		jmp exit
		
		left:
			cmp cs:left_wheel, 5
			je exit
			dec cs:left_wheel
			jmp exit
			
		right:
			cmp cs:left_wheel, 70
			je exit
			inc cs:left_wheel
			jmp exit
        
        exit:
            popf
            pop ax
            jmp dword ptr cs:[old_09h]
    endp

    int_2Fh proc far
        cmp ah, 0c7h
        jne Pass_2Fh
        cmp al, 00h
        je inst
        cmp al, 01h
        je unins
        jmp short Pass_2Fh

        inst:
        mov al, 0ffh
        iret

        Pass_2Fh:
        jmp dword ptr cs:[int_2Fh_vector]


        unins:
        push    BX
        push    CX
        push    DX
        push    ES

        mov     CX,CS  ; move into CX <- CS

        ;;; get int 1Ch
            mov     AX, 351Ch
            int     21h
        ;;;

        ;;; is new handler of 1Ch from the previos CS?  // DX -> ES, in CX - CS
            mov     DX,ES
            cmp     CX,DX
            jne     Not_remove
        ;;;
    
        ;;; is new handler of 1Ch is our new_1Ch procedure?
            cmp     BX, offset CS:new_1Ch
            jne     Not_remove
        ;;;

        ;;; get int 2Fh
            mov     AX,352Fh
            int     21h
        ;;;
    
        ;;; is new handler of 2Fh from the previous CS?
            mov     DX,ES
            cmp     CX,DX
            jne     Not_remove
        ;;;

        ;;; is new handler of 2Fh is our new int_2Fh procedure?
            cmp     BX, offset CS:int_2Fh
            jne     Not_remove
        ;;;

        ;;; get int 09h
            mov ax, 3509h
            int 21H
        ;;;

        ;;; is new handler of 09h from the previous CS?
            mov dx, es
            cmp cx, dx
            jne Not_remove
        ;;;

        ;;; is new handler of 2Fh is our new int_2Fh procedure?
            cmp bx, offset cs:new_09h
            jne Not_remove
        ;;;


        push    DS
        ;;; load in DX old handler of 1Ch
            lds     DX, CS:old_1Ch
            mov     AX,251Ch
            int     21h
        ;;;
    
        ;;; load in DX old handler of 2Fh
            lds     DX, CS:int_2Fh_vector
            mov     AX,252Fh
            int     21h
        ;;;

        ;;; load in DX old handler of 09h
            lds dx, cs:old_09h
            mov ax, 2509h
            int 21h
        ;;;
        pop     DS
    
        ;;; clear the environment (2Ch in psp)
            mov     ES,CS:2Ch
            mov     AH, 49h
            int     21h
        ;;;
    
        ;;; clear the psp itself
            push CS
            pop ES
            mov     AH, 49h
            int     21h
        ;;;
    

        ;;; set AL as 0F - uninstalled program
            mov     AL,0Fh
        ;;;

        jmp     short pop_ret
        Not_remove:
            mov     AL,0F0h  ; set AL as F0 - no uninstallation
        pop_ret:
            ;;; pop all register that were used
                pop     ES
                pop     DX
                pop     CX
                pop     BX
            ;;;

        iret
    int_2Fh endp

    begin:
        call rand8
        mov CL, ES:80h  ; length of PSP

        ;;; skip spaces before parametrs
            xor CH,CH
            cld
            mov DI, 81h
            mov AL, ' '
            repe    scasb
            dec DI
        ;;;

        ;;; is psp is truly "/off"?
            mov SI,offset key
            mov CX, 4
            repe    cmpsb
        ;;;

        jne check_install  ; if ZF == 0, then skip incrementaion of flag_off
        inc flag_off  ; if ZF == 1, set the flag to unistall the interrupt

        check_install:
            ;;; run int 2Fh to check C7 code
                mov AX, 0C700h
                int 2Fh
            ;;;

            ;;; if AL == FF, then program is already installed
                cmp AL, 0FFh
                je  already_ins
            ;;;

            ;;; if "/off", but program is not installed
                cmp flag_off,1
                je  xm_stranno
            ;;; strange things...

            ;;; get int 2Fh
                mov AX,352Fh
                int 21h
            ;;;

            ;;; save old int 2Fh 
                mov word ptr int_2Fh_vector, BX
                mov word ptr int_2Fh_vector + 2, ES
            ;;;

            ;;; load new int 2Fh
                mov DX,offset int_2Fh
                mov AX,252Fh
                int 21h
            ;;;
            
            ;;; get int 1Ch
                mov AX,351Ch
                int 21h
            ;;;

            ;;; save old int 1Ch
                mov word ptr old_1Ch,BX
                mov word ptr old_1Ch+2,ES
            ;;;

            ;;; load new int 1Ch
                mov DX,offset new_1Ch
                mov AX,251Ch
                int 21h
            ;;;

            ;;; get int 09h
                mov ax, 3509h
                int 21h
            ;;;

            ;;; save old int 09h
                mov word ptr old_09h, bx
                mov word ptr old_09h + 2, es
            ;;;

            ;;; load new int 09h
                mov dx, offset new_09h
                mov ax, 2509h
                int 21h
            ;;;
	
            ;;; successful instalation
                mov DX,offset msg1
                call    print
            ;;;

        ;;; make it resident
            mov DX,offset   begin
            int 27h
        ;;;
    
;=========================Show errors===========================
    already_ins:
        cmp flag_off,1
        je  uninstall
        lea DX,msg
        call    print
    int 20h

    uninstall:
        mov AX,0C701h
        int 2Fh
        cmp AL,0F0h
        je  not_sucsess
        cmp AL,0Fh
        jne not_sucsess
        mov DX,offset msg2
        call    print
    int 20h

    not_sucsess:
        mov DX,offset msg3
        call    print
    int 20h
        
    xm_stranno:
        mov DX,offset msg4
        call    print
    int 20h
;==============================================================

CODE_SEG ENDS
    end START