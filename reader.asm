close_all_file macro
	;------------close data_file
	mov ah,3eh
	mov bx,data_handle
	int 21h
	;------------close eng_file
	mov ah,3eh
	mov bx,eng_handle
	int 21h
	;------------close hzk_file
	mov ah,3eh
	mov bx,hzk_handle
	int 21h
	endm
restart macro
	close_all_file
	;-------------jmp to 'begin' for new display function
	jmp begin
endm
clear_num macro
	mov char_num,0
	mov last_char_num,0
	mov first_line_charnum,0
	mov last_line_charnum,0
endm
data  segment
line dw 0				;the line of char
column dw 0				;the column of char
;---------
line_interval dw 0		;the interval of line between chars
column_interval dw 0	;the interval of column between chars
;---------
line_off dw 0			;the offset of line in a single char
column_off dw 0			;the offset of column in a single char
;--------
max_char_num equ 2400	;the max number of chars that a screen can display
;--------
line_auto_mov db 0		;set automatically moving next line
scr_auto_mov db 0		;set automatically moving next screen
;--------
italic_char db 0		;set whether the char is of italic/normal type
change_init_col db 0	;italic mode: check whether the initialized column is changed
;--------
char_color db 0ah		;set the color the chars
;--------
eng_file db '.\ASC16',0	;filename of 'asc16'
hzk_file db '.\Hzk16',0 ;filename of 'hzk16'
data_file_name db 100	;the max length of the input filename of data_file
		  db ?			;the actual length of the input filename of data_file
		  db 100 dup(?)	;the string buffer of the input filename of data_file
data_file equ (offset data_file_name+2)	;the actual filename of data file
;---------the current file header of data file
data_file_header_high dw 0
data_file_header_low dw 0
;---------information of input
info db 'Please enter the file name:',0dh,0ah,24h
;---------error message
eng_file_error db 'Error: open C:\ASC16!',0dh,0ah,24h
hzk_file_error db 'Error: open C:\Hzk16!',0dh,0ah,24h
data_file_error db 'Error: open data.txt!',0dh,0ah,24h
head_exceed_error db 'Error: file head exceed!',0dh,0ah,24h
;----------file handle
eng_handle dw ?
hzk_handle dw ?
data_handle dw ?
;----------buffer of chars that a screen can display
disp_data db 2400 dup(0)
;----------
char_num_limit dw ?		;the limit of chars' number that can display(sometimes the number of chars of the file isn't as many as max_char_num)
char_num dw 0			;the actual number of chars displayed on the current screen
last_char_num dw 0		;the saved number of chars displayed on the previous screen
first_line_charnum dw 0	;the number of chars displayed in the current first line
last_line_charnum dw 0	;the saved number of chars displayed in the pevious first line
;-----------buffer for a single char
eng_buffer db 16 dup(0)
hzk_buffer db 32 dup(0)
data  ends
stack  segment
stack  ends
code  segment
assume  cs:code,  ds:data,  es:data,  ss:stack
start:
	mov ax,data
	mov ds,ax
	;设置为80×25/16色文本模式
	mov ax,3h
	int 10h
	;显示info字符串
	mov ah,09h
	lea dx,info
	int 21h
	;得到要显示的文件的文件名
	read_file_name:
		;从键盘读入字符串
		mov ah,0ah
		mov dx,offset data_file_name
		int 21h
		;回车换行
		mov dl,0ah
		mov ah,02h
		int 21h
		mov dl,0dh
		mov ah,02h
		int 21h
		;在文件名字符串后加结束符
		lea si,data_file_name
		inc si
		mov al,[si]
		xor ah,ah				;ax存放文件名字符串的实际长度
		inc si
		add si,ax
		mov byte ptr [si],0		;在文件名字符串后一个字节写0
	begin:	
		;初始化行值和列值
		mov line,0
		mov column,0
		;打开data_file文件
		mov ax,3d00h
		mov dx,data_file
		int 21h
		jnb data_file_suc
		;若打开data_file文件失败，则显示相应错误信息并退出
		mov ah,09h
		lea dx,data_file_error
		int 21h
		jmp _EXIT
	;打开data_file文件成功
	data_file_suc:
		;保存file handle
		mov data_handle,ax
		;--------------????
		cmp data_file_header_low,8000h
		jb fseek_data_file
		sub data_file_header_low,8000h
		add data_file_header_high,1
	;移动文件指针
	fseek_data_file:
		mov cx,data_file_header_high
		mov dx,data_file_header_low		;cx:dx=number of bytes that pointer moved
		mov ax,4200h
		mov bx,data_handle
		int 21h
		jc file_head_error
		jmp read_data
	;移动文件指针出错
	file_head_error:
		;显示错误信息
		mov ah,09h
		lea dx,head_exceed_error
		int 21h
		;从键盘读入字符
		xor ah,ah
		int 16h
		;将file header清零
		mov data_file_header_high,0
		mov data_file_header_low,0
		;关闭data_file文件
		mov ah,3eh
		mov bx,data_handle
		int 21h
		;------------
		jmp start
		;jmp _EXIT
	;从data_file文件读取数据
	read_data:
		mov ah,3fh
		mov bx,data_handle
		mov cx,max_char_num			;number of bytes to be read
		mov dx,offset disp_data		;ds:dx=the address of a memory buffer to store file data
		int 21h
		;设置max_char_num
		;ax stores the actual number of bytes read from the file
		cmp ax,max_char_num
		jb store_char_num_limit
		mov char_num_limit,cx			;设置char_num_limit为max_char_num
		jmp open_eng_file
	store_char_num_limit:
		mov char_num_limit,ax			;设置char_num_limit为实际从文件读到的字节数
	;英文asc16点阵文件处理
	open_eng_file:
		;打开asc16点阵文件
		mov ax,3d00h
		mov dx,offset eng_file
		int 21h
		jnb eng_file_suc
		;若打开asc16点阵文件失败，则显示相应错误信息并退出
		mov ah,09h
		lea dx,eng_file_error
		int 21h
		jmp _EXIT
	;打开asc16点阵文件成功
	eng_file_suc:
		;保存file handle
		mov eng_handle,ax
	;中文hzk16点阵文件处理
	open_hzk_file:
		;打开hzk16点阵文件
		mov ax,3d00h
		mov dx,offset hzk_file
		int 21h
		jnb hzk_file_suc
		;若打开hzk16点阵文件失败，则显示相应错误信息并退出
		mov ah,09h
		lea dx,hzk_file_error
		int 21h
		jmp _EXIT
	;打开hzk16点阵文件成功
	hzk_file_suc:
		;保存file handle
		mov hzk_handle,ax
	;------------
	mov dx,data
	mov ds,dx
	mov si,offset disp_data
	;---------
	mov ax,12h
	int 10h  				;设置640*480/16色显示模式
	;设char_num_limit为循环次数
	mov cx,char_num_limit
	cld
	_LOOP:
		;---------保存计数器
		push cx
		;---------
	;如果列数已满，则换行
	check_column_full:
		cmp column,640
		jb check_line
		call change_line
	;如果当前行数不够继续显示一行字符串，则跳出循环
	check_line:
		cmp line,464
		ja _OUT
		;--------
		lodsb				;al=(*s)
		;计算实际显示的字节数
		add char_num,1
		;计算第一行的字节数
		cmp line,0
		jne check_char_line
		add first_line_charnum,1
	;处理回车换行
	check_char_line:
		cmp al,0dh			;回车
		je check_line		;遇到回车则跳过该字符
		cmp al,0ah			;换行
		jne check_char_tab
	char_change_line:
		call change_line	;遇到换行则换行
		jmp check_line
	;处理tab键输入
	check_char_tab:
		cmp al,09h			;'\t'
		je trans_tab
		jmp handle
	trans_tab:
		mov al,' '			;'\t'用' '代替
	;当前字符处理
	handle:
		;判断当前读到的字符是英文还是中文，并进行相应处理
		cmp al,127
		jbe handle_eng
		;jmp handle_hzk
	;处理中文字符
	handle_hzk:
		call hzk_char_handle
		;--------恢复计数器
		pop cx
		dec cx				;hzk needs 2 byte
		;--------
		jmp reset_offset
		;---------end of handle_hzk	
	;处理英文字符
	handle_eng:
		call eng_char_handle
		;--------恢复计数器
		pop cx
		;--------
	;重置字内行和列的偏移量为0
	reset_offset:
		mov line_off,0
		mov column_off,0
	;检查是否有按键输入
	check_press_key:
		mov ah,0bh
		int 21h
		cmp al,0ffh
		je _OUT				;若有按键输入，则跳出循环
		;----------
		loop _LOOP
		;----------
	_OUT:
		call auto_mov_screen
		call auto_mov_line	
		call func
	_EXIT:
		;设置为80×25/16色文本模式
		mov ax,3h
		int 10h			
		;程序退出
		mov ah,4ch
		int 21h
;中文字符处理函数
hzk_char_handle proc
	;计算足够显示最后一个中文字符的最大列值
	mov bx,624			
	;如果设置为斜体，需要再多出8 byte的空间
	cmp italic_char,1
	jne hzk_check_column
	sub bx,8
	;判断是否足够显示最后一个中文字符
	hzk_check_column:
		cmp column,bx		;check whether there's enough space to display a chinese char
		jbe get_full_char
		call change_line
	;--------
	get_full_char:
		mov ah,al
		lodsb				;ax=(*s)
	;更新实际显示的字节数
	add char_num,1
	;更新第一行的字节数
	cmp line,0
	jne disp_hzk_char
	add first_line_charnum,1
	;--------
	disp_hzk_char:
		call get_hzk_dots
		call hzk_disp
	;更新列值
	mov ax,column_interval	;字符之间的列间距
	add ax,16				;中文字符长度
	add column,ax
	;-----------
	ret
hzk_char_handle endp
;英文字符处理函数
eng_char_handle proc
	;计算足够显示最后一个英文字符的最大列值
	mov bx,632
	sub bx,column_interval
	;如果设置为斜体，需要再多出8 byte的空间
	cmp italic_char,1
	jne eng_check_column
	sub bx,8
	;判断是否足够显示最后一个英文字符
	eng_check_column:
		cmp column,bx		;check whether there's enough space to display an english char
		jbe disp_eng_char
		call change_line
	;----------
	disp_eng_char:
		call get_eng_dots
		call eng_disp
	;更新列值
	mov ax,column_interval	;字符之间的列间距
	add ax,8				;英文字符长度
	add column,ax
	;-----------
	ret
eng_char_handle endp
;按键功能处理函数
func proc
	mov ah,07h
	int 21h					;无回显不过滤的键盘输入
	;输入q(quit)退出重新返回选择文件界面
	q_func:
		cmp al,'q'
		jne s_func
		close_all_file
		clear_num
		jmp start
	;输入s(slant)设置斜体
	s_func:
		cmp al,'s'
		jne bigA_func
		call control_italic
	;输入A(Auto)设置自动翻屏
	bigA_func:
		cmp al,'A'
		jne a_func
	;	cmp scr_auto_mov,1
	;	je reset_scr_auto
		mov scr_auto_mov,1
		clear_num
		restart
	;reset_scr_auto:
	;	mov scr_auto_mov,0
	;输入a(auto)设置自动下一行
	a_func:
		cmp al,'a'
		jne bigI_func
	;	cmp line_auto_mov,1
	;	je reset_line_auto
		mov line_auto_mov,1
	;	call auto_mov_line
		clear_num
		restart
	;reset_line_auto:
	;	mov line_auto_mov,0
	;输入I(Increase)增加行间距
	bigI_func:
		cmp al,'I'
		jne bigD_func
		call inc_line_interval
	;输入D(Decrease)减少行间距
	bigD_func:
		cmp al,'D'
		jne i_func
		call dec_line_interval
	;输入i(increase)增加列间距
	i_func:
		cmp al,'i'
		jne d_func
		call inc_col_interval
	;输入d(decrease)减少列间距
	d_func:
		cmp al,'d'
		jne c_func
		call dec_col_interval
	;输入c(color)改变字体颜色
	c_func:
		cmp al,'c'
		jne n_func
		call change_char_color
	;输入n(next)转到下一行
	n_func:
		cmp al,'n'
		jne p_func
		call next_line
	;输入p(previous)转到前一行
	p_func:
		cmp al,'p'
		jne bigN_func
		call pre_line
	;输入N(Next)转到下一屏
	bigN_func:
		cmp al,'N'
		jne bigP_func
		call next_screen
	;输入P(Previous)转到前一屏
	bigP_func:
		cmp al,'P'
		jne func_out
		call pre_screen
	func_out:
		ret
func endp
;设置斜体的函数
control_italic proc
	cmp italic_char,1
	je reset_italic_char
	mov italic_char,1
	jmp control_italic_out
	reset_italic_char:
		mov italic_char,0
	control_italic_out:
		clear_num
		restart
control_italic endp
;自动翻屏的函数
auto_mov_screen proc
	cmp scr_auto_mov,0
	je mov_scr_out
	call delay
	mov ah,0bh
	cmp al,0
	je mov_scr_out
	call next_screen
	mov ah,0bh
	cmp al,0
	je mov_scr_out
	jmp auto_mov_screen
	mov_scr_out:
		mov scr_auto_mov,0
		ret
auto_mov_screen endp
;自动跳转下一行的函数
auto_mov_line proc
	cmp line_auto_mov,0
	je mov_line_out
	mov ah,0bh
	cmp al,0				
	je mov_line_out		;press key
	call delay
	call next_line
	jmp auto_mov_line
	mov_line_out:
		mov line_auto_mov,0
		ret
auto_mov_line endp
;延时函数
delay proc
	mov bx,0ffffh
	delay_outer_loop:
		mov cx,0ffffh
		delay_inner_loop:
			loop delay_inner_loop
		dec bx
		cmp bx,0
		jnz delay_outer_loop
	ret
delay endp
;增加行间距的函数
inc_line_interval proc
	add line_interval,2
	clear_num
	restart
	ret
inc_line_interval endp
;减少行间距的函数
dec_line_interval proc
	cmp line_interval,0
	jbe reset_line_interval
	sub line_interval,2
	clear_num
	restart
	ret
	reset_line_interval:
		mov line_interval,0
		clear_num
		restart
		ret
dec_line_interval endp
;增加列间距的函数
inc_col_interval proc
	add column_interval,2
	clear_num
	restart
	ret
inc_col_interval endp
;减少列间距的函数
dec_col_interval proc
	cmp column_interval,0
	jbe reset_col_interval
	sub column_interval,2
	clear_num
	restart
	ret
	reset_col_interval:
		mov column_interval,0
		clear_num
		restart
		ret
dec_col_interval endp
;改变字体颜色的函数
change_char_color proc
	;--------
	push ax
	push cx
	;--------
	inc char_color
	mov al,char_color
	mov cl,16
	div cl
	cmp ah,0
	jnz change_char_color_out
	add char_color,1
	change_char_color_out:
		clear_num
		restart
		;--------
		pop cx
		pop ax
		;---------
		ret
change_char_color endp
;跳转到下一行的函数
next_line proc
	mov ax,first_line_charnum
	add data_file_header_low,ax
	mov last_line_charnum,ax
	mov first_line_charnum,0
	mov char_num,0
	mov last_char_num,0
	restart
	ret
next_line endp
;跳转到前一行的函数
pre_line proc
	mov ax,last_line_charnum
	cmp data_file_header_low,ax
	jb pre_line_out
	sub data_file_header_low,ax
	clear_num
	pre_line_out:
		restart
		ret
pre_line endp
;跳转到下一屏的函数
next_screen proc
	mov ax,char_num
	add data_file_header_low,ax
	mov last_char_num,ax
	mov char_num,0
	mov first_line_charnum,0
	mov last_line_charnum,0
	restart
	ret
next_screen endp
;跳转到上一屏的函数
pre_screen proc
	mov ax,last_char_num
	cmp data_file_header_low,ax
	jb pre_screen_out
	sub data_file_header_low,ax
	clear_num
	pre_screen_out:
		restart
		ret
pre_screen endp
;换行函数
change_line proc
	push ax
	mov column,0			;列值清零
	mov ax,line_interval	;换行时要留出字符之间的行间距
	add ax,16
	add line,ax
	pop ax
	ret
change_line endp
;得到英文字符点阵的函数
get_eng_dots proc
	;--------
	mov bl,16
	mul bl			;ax=(*s)*16
	;--------
	;fseek(eng_handle,(*s)*16,0)
	xor cx,cx
	mov dx,ax
	mov ax,4200h
	mov bx,eng_handle
	int 21h
	;---------
	;fread(eng_buffer,1,16,eng_handle)
	mov ah,3fh
	mov cx,16
	mov dx,offset eng_buffer
	int 21h
	ret
get_eng_dots endp
;显示英文字符的函数
eng_disp proc
	;---------
	push si
	;---------
	mov si,offset eng_buffer
	mov cx,16			;外循环16次(行)
	;若当前为斜体显示，则初始列值加8
	cmp italic_char,1
	jne eng_LOOP1
	add column,8
	;-----------
	eng_LOOP1:
		;----------
		push cx
		;----------
		mov ax,data
		mov ds,ax
		lodsb			;al=ds:[si],si++
		;----------	
		mov cx,8		;内循环8次(列)
		eng_LOOP2:
			;---------
			shl al,1
			;---------
			push ax
			push cx
			;----------
			jc eng_is_char		;eng_buffer[]<<1
			xor al,al			;blackground
			jmp eng_put_pixel
		eng_is_char:
			mov al,char_color	;设置字体颜色
		;putpixel(X,Y,color)
		;(CX,DX)＝column,line
		eng_put_pixel:
			;---------
			mov ah,0ch
			mov cx,column
			add cx,column_off
			mov dx,line
			add dx,line_off
			xor bh,bh
			int 10h
			;----------
			pop cx
			pop ax
			;----------
			inc column_off
			;----------
			loop eng_LOOP2
		;若当前为斜体显示，则每2次换行后初始列值减1
		cmp italic_char,1
		jne eng_next_line
		cmp change_init_col,1
		je eng_reset_init_col
		dec column
		mov change_init_col,1
		jmp eng_next_line
		eng_reset_init_col:
			mov change_init_col,0
		;----------
		eng_next_line:
			inc line_off
			mov column_off,0	;新的一行要将列的偏移量清0
		;----------
		pop cx
		;----------
		loop eng_LOOP1
	;----------
	pop si
	;----------
	ret
eng_disp endp
;得到中文字符点阵的函数
get_hzk_dots proc
	;------------
	push ax
	;------------计算汉字点阵数据在字库中的偏移量
	;16*16汉字点阵数据在字库中的偏移量为((区码-a1h)*94 + (区内编码-a1h))*32
	sub ax,0a1a1h 	;区码-a1h,区内编码-a1h
	cwd				;将ax中的符号位扩展到dx中
	mov dl,al  		;dl=区内编码-a1h
	mov al,ah  		;al=区码-a1h
	cbw				;将al的最高位扩展至ah，al不变
	mov bl,94
	mul bl			;al=(区码-a1h)*94
	add ax,dx		;al=(区码-a1h)*94 + (区内编码-a1h)
	mov bx,32
	mul bx			;dx-ax:position
	;-----------
	;fseek(hzk_handle,position,0)
	mov cx,dx
	mov dx,ax
	mov ax,4200h
	mov bx,hzk_handle
	int 21h
	;------------
	;fread(hzk_buffer,1,32,hzk_handle)
	mov ah,3fh
	mov cx,32
	mov dx,offset hzk_buffer
	int 21h
	;------------
	pop ax
	;------------
;	add di,32
	ret
get_hzk_dots endp
;显示中文字符的函数
hzk_disp proc
	;---------
	push si
	;---------
	mov si,offset hzk_buffer
	mov cx,16			;外循环16次
	;若当前为斜体显示，则初始列值加8
	cmp italic_char,1
	jne hzk_LOOP1
	add column,8
	;---------
	hzk_LOOP1:
		;----------
		push cx
		;----------
		mov ax,data
		mov ds,ax
		lodsb
		;----------
		mov ah,al
		lodsb
		;----------	
		mov cx,16		;内循环16次
		hzk_LOOP2:
			;---------
			shl ax,1
			;---------
			push ax
			push cx
			;----------
			jc hzk_is_char		;hzk_buffer[]<<1
			xor al,al			;blackground
			jmp hzk_put_pixel
		hzk_is_char:
			mov al,char_color	;设置字体颜色
		;putpixel(X,Y,color)
		;(CX,DX)＝column,line
		hzk_put_pixel:
			;---------
			mov ah,0ch
			mov cx,column
			add cx,column_off
			mov dx,line
			add dx,line_off
			xor bh,bh
			int 10h
			;----------
			pop cx
			pop ax
			;----------
			inc column_off
			;----------
			loop hzk_LOOP2
		;若当前为斜体显示，则每2次换行后初始列值减1
		cmp italic_char,1
		jne hzk_next_line
		cmp change_init_col,1
		je hzk_reset_init_col
		dec column
		mov change_init_col,1
		jmp hzk_next_line
		hzk_reset_init_col:
			mov change_init_col,0
		;----------
		hzk_next_line:
			inc line_off
			mov column_off,0	;新的一行要将列的偏移量清0
		;----------
		pop cx
		;----------
		loop hzk_LOOP1
	;----------
	pop si
	;----------
	ret
hzk_disp endp
	code ends
end start