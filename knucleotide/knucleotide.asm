struc vector d,s
{
	.data dd d
	.size dd s
	.elements dd 0
}

macro ccall proc,[arg]                  ; call CDECL procedure
{ 
  common
    local size
    size = 0   
   reverse   
    pushd arg
    size = size+4
   common
    call proc
    add esp,size 
}

macro sys_exit rc
{
	mov eax,1 ; exit
	mov ebx,rc
	int 0x80
}

macro sys_read fd, buf, size
{
	mov eax, 3 ; sys_read
	mov ebx, fd
	mov ecx, buf
	mov edx, size
	int 0x80
}
macro sys_write fd, buf, size
{
	mov eax, 4 ; sys_write
	mov ebx, fd
	mov ecx, buf
	mov edx, size
	int 0x80
}

CLONE_VM		equ 0x00000100
CLONE_FS		equ 0x00000200
CLONE_FILES		equ 0x00000400
CLONE_SIGHAND	equ 0x00000800
CLONE_THREAD	equ 0x00010000

macro sys_clone stack
{
	mov eax,120 ; sys_clone
	mov ebx,CLONE_VM or CLONE_FS or CLONE_FILES \
	or CLONE_SIGHAND;
	mov ecx,stack ; choose stack
	xor edx,edx ; no struct
	int 0x80
}

__WNOTHREAD	equ 0x20000000
__WALL		equ 0x40000000
__WCLONE	equ 0x80000000

macro sys_wait pid
{
	mov ebx,pid
	mov eax,114 ; sys_wait4
	xor ecx,ecx
	xor esi,esi
	mov edx,__WALL;
	int 0x80
}

macro read fd, buf,size
{
	local l1,l2,l3
	mov eax, dword [fptr]
	and eax,eax
	jnz l2
	l1:
	sys_read fd,filebuf,fsize
	and eax,eax
	jz l3
	lea eax, [eax+filebuf]
	mov dword [fend], eax
	mov dword [fptr], filebuf
	l2:
	mov ecx, size
	mov ebx, size
	mov eax, dword [fend]
	sub eax, dword [fptr]
	jz l1
	cmp eax,ecx
	cmovl ecx,eax
	mov eax,ecx
	sub ebx, ecx
	strncpy buf,dword [fptr], ecx, 0
	and ebx,ebx
	mov dword [fptr],esi
	jnz l1
	l3:
}

macro getLine fd, buf, size
{
	local l1,l2
	mov ecx, size
	mov edi, buf
	l1:
	and ecx,ecx
	jz l2
	push ecx
	push edi
	read fd,dword[esp],1
	pop edi
	pop ecx
	cmp eax,1
	jne l2;
	dec ecx
	inc edi
	cmp byte [edi-1], 0xa
	jnz l1
	dec edi
	l2:
	mov byte [edi],0
}

macro dwordnset s, c, count
{
	mov edi,s
	mov eax,c
	mov ecx,count
	cld
	rep stosd
}

macro strnset s,c, size
{
	mov edi,s
	mov eax,c
	mov ecx,size
	cld
	rep stosb
}

macro dwordncmp s1, s2, size, dir
{
	if ~ dir
		cld
	else
		std
	end if
	mov esi,s2
	mov edi,s1
	mov ecx,size
	repe cmpsd
	if dir
		cld
	end if
}

macro strncmp s1, s2, size, dir
{
	if ~ dir 
		cld
	else
		std
	end if
	mov esi,s2
	mov edi,s1
	mov ecx,size
	repe cmpsb
	if dir
		cld
	end if
}

macro dwordncpy s1,s2, size, dir
{
	if ~ dir
		cld
	else
		std
	end if
	mov esi,s2
	mov edi,s1
	mov ecx, size
	rep movsd
	if dir
		cld
	end if
}

macro strncpy s1,s2, size, dir
{
	if ~ dir
		cld
	else
		std
	end if
	mov esi,s2
	mov edi,s1
	mov ecx, size
	rep movsb
	if dir
		cld
	end if
}

macro to_num src
{
	mov al,src
	xlatb
}

macro to_char src
{
	mov al,src
	xlatb
}

macro pack_str dst,src,size,f
{
	if ~f
	local l1
	mov esi,src
	mov edi,dst
	mov ecx,size
	mov edx,0
	mov ebx,xtbl
	l1:
	to_num byte [esi]
	mov byte [edi], al
	inc edi
	inc esi
	inc edx
	dec ecx
	jnz l1
	else
	strncpy dst,src,size,0
	end if
}

macro really_pack_str dst,src,size,f
{
	local l1,l2,e1
	mov esi,src
	mov edi,dst
	mov ecx,size
	mov edx,1
	l1:
	mov ebx,4
	mov byte [edi],0
	l2:
	mov al,byte [esi]
	shl byte [edi],2
	or byte [edi], al
	inc esi
	dec ecx
	jz e1
	dec ebx
	jnz l2
	inc edi
	inc edx ; count
	jmp l1
	e1:
}

macro unpack_str dst,src,size
{
	local l1
	mov esi,src
	mov edi,dst
	mov ecx,size
	mov ebx,xtbl
	l1:
	to_char byte [esi]
	mov byte [edi], al
	inc edi
	inc esi
	dec ecx
	jnz l1
}

macro initvector data,oldsize,size,block
{
	local e1,e2
	mov eax, size
	imul eax, block
	push eax
	ccall realloc,dword[data],eax
	pop ebx
	and eax,eax
	jz e1
	mov dword[data],eax
	mov dword[oldsize],ebx
	jmp e2
	e1:
	ccall perror, err1
	sys_exit -1
	e2:
}

macro freevector data,size
{	
	local l1
	mov ecx,size
	mov ebx,data
	l1:
	push ebx ecx
	ccall free,dword[ebx]
	pop ecx ebx
	mov dword[ebx],0
	add ebx,4
	dec ecx
	jnz l1
}

macro hash str,size
{
	local l1,l2,l3
	mov ecx,size
	mov ebx,str
	xor eax,eax
	mov esi,16
	mov edi,2
	l1:
	shl eax,2
	movzx edx,byte [ebx]
	or eax,edx
	inc ebx
	dec esi
	jnz l2
	push eax
	xor eax,eax
	mov esi,16
	dec edi
	l2:
	dec ecx
	jnz l1
	l3:
	push eax
	dec edi
	jnz l3
}

macro hashfind data,elements,block,srchstr,srchlen
{
	pushd srchstr
	hash srchstr,srchlen
	mov ebx,data
	strfind elements,block
}

macro strfind elements,block
{
	local l1,l2,l3,l4,l5,s1,e1
	pop edx eax ecx
	push eax
	xor esi,esi
	and eax,0xffff
	shl eax,2
	cmp dword[ebx+eax],0
	push eax ebx
	jne l3
	l1:
	; allocate
	s1:
	mov ebx,1
	xor eax,eax
	lock cmpxchg dword[sema],ebx ; test and set
	and eax,eax
	jnz s1
	add esi,20
	pop ebx eax
	push ebx eax ecx edx
	ccall realloc,dword[ebx+eax],esi ; realloc is not thread safe
	lock and dword[sema],0 ; reset
	mov esi,eax
	and esi,esi
	jz e2
	pop edx ecx ebx eax
	cmp dword[ebx+eax],0
	mov dword[ebx+eax],esi
	jne l2
	mov esi, dword[ebx+eax]
	mov dword[esi],0
	l2:
	mov ebx,dword[ebx+eax]
	add ebx,4
	mov eax,dword[ebx-4]
	imul eax,16
	mov dword[ebx+eax+12],edx
	mov esi,dword[esp]
	mov dword[ebx+eax+8],esi
	mov dword[ebx+eax+4],ecx
	mov dword[ebx+eax],0
	inc dword[elements]
	inc dword[ebx-4]
	push esi esi
	jmp e1
	;search
	l3:
	mov ebx,dword[ebx+eax]
	add ebx,4
	xor eax,eax

	l4:
	mov esi,dword[ebx-4]
	imul esi,16
	cmp eax,esi
	jge l1 ; we need to reallocate
	mov esi,dword[esp+8]
	cmp dword[ebx+eax+8],esi
	jne l5
	cmp dword[ebx+eax+12],edx
	je e1

	l5:
	add eax,16
	jmp l4
	e1:
	pop esi esi esi
	lea eax,[ebx+eax]
}

macro find data,elements,block,srchstr
; binary search and insert
{
	
	local l1,l2,e1,e2,e3
	pushd data
	mov ecx,srchstr
	mov ebx,dword[esp]
	add ebx,4
	mov eax,dword[ebx-4]
	lea edx,[ebx+eax*block]
	l1:
	
	if 0
	pusha
	ccall printf,fmt1,dword[ebx-4]
	popa
	end if
	
	and eax,eax
	jz e1
	cmp edx,ebx
	jle e1
	shr eax,1
	mov esi,dword[ecx]
	cmp dword[ebx+eax*block],esi
	jle l1
	and eax,eax
	jnz l2
	inc eax
	l2:
	lea ebx, [ebx+eax*block]
	jmp l1
	e1:
	mov eax,dword[esp]
	add eax,4
	lea edx,[eax-4]
	mov edx,dword[edx]
	lea eax, [eax+edx*block]
	mov edx, eax
	add edx,block
	dec edx
	sub eax,ebx
	jl e2
	push ecx
	lea ecx, [edx-block]

	if 0
	pusha
	ccall printf,fmt5,eax,dword[ecx]
	popa
	end if

	strncpy edx,ecx,eax,1
	pop ecx

	if 0
	pusha
	ccall printf,fmt5,eax,ecx
	popa
	end if
	
	mov esi,dword[ecx]
	mov dword [ebx],esi ; count
	mov esi,dword[ecx+4]
	mov dword [ebx+4],esi ;ptrstring
	mov eax,dword[esp]
	inc dword[eax]
	inc dword[elements]
	xor eax,eax
	jmp e3
	e2:
	ccall printf,fmt,err2
	sys_exit -1
	e3:
	pop ecx
	lea eax,[ebx+eax*block]
}


macro print_strs ptr,size
{
	local l1,e1
	mov ebx,ptr
    mov ecx,dword[ebx]
    cmp ecx,0
    jz e1
    mov edx,dword[sdta]
	inc edx
	sub edx,size
	push edx
	fild dword[esp]
	mov dword[esp],100
	fild dword[esp]
	add ebx,4
	add esp,4
	l1:
	push ecx ebx
	unpack_str lngbuf,dword[ebx+4],size
	mov byte[lngbuf+size],0
	pop ebx
	push ebx
	fild dword[ebx]
	fmul st0,st1
	fdiv st0,st2
	sub esp,8
	fstp qword[esp]
	ccall printf,fmt, lngbuf
	add esp,8
	pop ebx ecx
	add ebx,8
	dec ecx
	jnz l1
	e1:
}

macro merge data,data1,size,srchlen
{
	local l1,l2,l3,e1,t1
	mov ecx,size/2
	cmp ecx,0
	jz e1
	mov ebx,data1
	l1:
	cmp dword[ebx],0
	jz l3
	push ebx ecx
	mov ebx,dword[ebx]
	mov ecx,dword[ebx]

	if 0
	pusha
	ccall printf,fmt6,ecx,dword[ebx+4]
	popa
	end if

	add ebx,4
	add dword[sum],ecx
	l2:
	push ebx ecx
	hashfind data,hashtable.elements,8,dword[ebx+4],srchlen
	dec dword[hashtable.elements]
	
	pop ecx ebx
	mov esi, dword[ebx]
	add dword[eax],esi
	add ebx,16
	dec ecx
	jnz l2
	pop ecx ebx
	dec ecx
	jz e1
	l3:
	add ebx,4
	dec ecx
	jnz l1
	e1:
}

macro frequencies size
{
	local l1,l2,e1
	mov edx,size
	mov ebx,dword[dta]
	mov ecx,dword[sdta]
	inc ecx
	sub ecx,edx
	pushd dword[hashtable.data]
	pushd dword[hashtable.elements]
	push ebx ecx edx
		
	strncpy tstck-5*4,esp,5*4,0
	strncpy tstck1-5*4,esp,5*4,0
	inc dword[tstck1-3*4]
	add dword[tstck1-1*4],0x80000
	sys_clone tstck1
	and eax,eax
	jz l1
	push eax
	sys_clone tstck
	and eax,eax
	jz l1
	sys_wait eax
	pop eax
	sys_wait eax
	pop edx ecx ebx esi esi
	jmp e1
	l1:
	mov ebp,esp
	sub esp,5*4
	pop edx ecx ebx
	
	if 0
	pusha
	ccall printf,fmt1,ecx
	popa
	pusha
	ccall printf,fmt1,edx
	popa
	pusha
	ccall printf,fmt2,ebx
	popa
	end if
	
	l2:
	push ebp
	mov ebp,esp
	push ebx ecx edx
	hashfind dword [ebp+8], ebp+4,8,ebx,edx
	pop edx ecx ebx
	mov esp,ebp
	pop ebp
	inc dword[eax]
	add ebx,2
	sub ecx,2
	jg l2
	pop esi
	lock add dword[hashtable.elements],esi
	pop esi
	sys_exit 0
	e1:
	
}

macro frequencies1
{
	local l1,l2,l3,e1
	mov ecx,dword[hashtable.elements]
	cmp ecx,0
	jz e1
	mov ebx,dword[hashtable.data]
	l1:
	cmp dword[ebx],0
	jz l3
	push ebx ecx
	mov ebx,dword[ebx]
	mov ecx,dword[ebx]

	if 0
	pusha
	ccall printf,fmt6,ecx,dword[ebx+4]
	popa
	end if

	add ebx,4
	l2:
	push ebx ecx
	find dword[sortedtable.data],sortedtable.elements,8,ebx
	pop ecx ebx
	add ebx,16
	dec ecx
	jnz l2
	pop ecx ebx
	dec ecx
	jz e1
	l3:
	add ebx,4
	jmp l1
	e1:
}

macro calc_frequencies size
{
	mov edx,size
	call cfrequencies
}

macro sort_frequencies size
{
	call sfrequencies
}

STDIN equ 0
STDOUT equ 1
STDERR equ 2
fsize equ 8192
SIZE equ 0x40000
format ELF

section '.text' executable

public main
extrn printf
extrn perror
extrn realloc
extrn free

cfrequencies:
	frequencies edx
	ret
sfrequencies:
	frequencies1
	ret
	
main:
	mov ebx ,xtbl
	mov byte[ebx+'a'],0
	mov byte[ebx+'A'],0
	mov byte[ebx+'c'],1
	mov byte[ebx+'C'],1
	mov byte[ebx+'g'],2
	mov byte[ebx+'G'],2
	mov byte[ebx+'t'],3
	mov byte[ebx+'T'],3

	mov byte[ebx+0],'A'
	mov byte[ebx+1],'C'
	mov byte[ebx+2],'G'
	mov byte[ebx+3],'T'

	l2:
	getLine STDIN, buf, 256
	movzx eax, byte [buf]
	and eax,eax
	jz e1
	strncmp buf,three,6,0
	and ecx,ecx
	jnz l2
	l1:
	getLine STDIN, buf, 256
	movzx eax, byte [buf]
	and eax,eax
	jz e1
	cmp eax,'>'
	je e1
	mov eax,256
	sub eax,ecx
	dec eax
	push eax
	add eax, dword [sdta]
	ccall realloc,dword[dta], eax
	and eax,eax
	jz e2
	mov dword[dta],eax
	pop eax
	mov ebx, dword [sdta]
	add ebx, dword [dta]
	push eax
	pack_str ebx,buf,eax,0
	pop eax
	add dword[sdta],edx
	jmp l1
	e1:
	initvector hashtable.data,hashtable.size,SIZE,4
	dwordnset dword[hashtable.data],0,SIZE

;	sys_write STDOUT, dword [dta], dword[sdta]

macro write_frequencies len	
{
	calc_frequencies len
	mov esi,dword[hashtable.data]
	add esi,0x80000
	merge dword[hashtable.data],esi,SIZE,len
;	ccall printf, fmt1, dword [hashtable.elements]
	initvector sortedtable.data,sortedtable.size,100,16
	mov ebx,100
	imul ebx,4
	dwordnset dword[sortedtable.data],0,ebx
	sort_frequencies len
	print_strs dword[sortedtable.data],len
	ccall printf,fmt1,dword[sortedtable.elements]
	mov dword[sortedtable.elements],0
	mov dword [hashtable.elements],0
	freevector dword[hashtable.data],SIZE
}
	write_frequencies 1	
	write_frequencies 2

macro write_count len,str
{
	mov dword[sum],0
	calc_frequencies len
	ccall printf, fmt1, dword [hashtable.elements]
	mov esi,dword[hashtable.data]
	add esi,0x80000
	merge dword[hashtable.data],esi,SIZE,len
	ccall printf,fmt1,dword[sum]
	pack_str lngbuf,str,len,0
	hashfind dword[hashtable.data],hashtable.elements,8,lngbuf,edx
	push eax
	unpack_str str,dword[eax+4],len
	pop eax
	ccall printf, fmt5, dword [eax],str
	ccall printf, fmt1, dword [hashtable.elements]
	mov dword [hashtable.elements],0
	freevector dword[hashtable.data],SIZE
}
	write_count 3,lngstr4
	write_count 4,lngstr3
	write_count 6,lngstr2
	write_count 12,lngstr1
	write_count 18,lngstr
	
	xor eax,eax
	ret
	e2:
	ccall perror, err1
	sys_exit -1

section	'.data' writeable

align 4
fmt db "%s %.3f",0xa,0
fmt1 db "%u",0xa,0
fmt2 db "%p",0xa,0
fmt3 db "%c",0xa,0
fmt4 db "%s %u %u",0xa,0
fmt5 db "%u",9,"%s",0xa,0
fmt6 db "%u %u",0xa,0
err1 db "realloc failed",0
err2 db "index error",0
lngstr db "gGtattTtaatttatagt",0
lngstr1 db "ggtATTttaatt",0
lngstr2 db "gGtAtt",0
lngstr3 db "gGta",0
lngstr4 db "GgT",0
three db ">THREE"

align 4
fptr dd 0
fend dd 0
dta dd 0
sdta dd 0
hashtable vector 0,0
sortedtable vector 0,0
align 4
sema dd 0

section '.bss' writeable

align 4
buf rb 256
align 4
filebuf rb fsize
align 4
xtbl rb 256
align 4
lngbuf rb 18
align 4
bstck rb 4095
tstck rb 1
align 4
bstck1 rb 4095
tstck1 rb 1
sum rd 1
