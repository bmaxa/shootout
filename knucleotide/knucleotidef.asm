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
	mov edi,buf
	mov ebx,size
	xor ecx,ecx
	mov eax, dword [fptr]
	and eax,eax
	jnz l2
	l1:
	push ebx ecx edx edi
	strncpy fileresbuf,filebuf,fsize,0
	sys_read fd,filebuf,fsize
	pop edi edx ecx ebx
	and eax,eax
	jz l3
	lea eax, [eax+filebuf]
	mov dword [fend], eax
	mov dword [fptr], filebuf
	l2:
	mov eax, dword [fend]
	sub eax, dword [fptr]
	jz l1
	cmp eax,ebx
	cmovg eax,ebx
	sub ebx, eax
	add ecx,eax
	push ecx
	strncpy edi,dword [fptr], eax, 0
	pop ecx
	and ebx,ebx
	mov dword [fptr],esi
	jnz l1
	l3:
	mov eax,ecx
}

macro back size
{
	sub dword[fptr],size
}

macro getLine fd, buf, size, hint
{
	local l1,l2,l3
	mov ecx, size
	mov ebx,hint
	cmp ecx,ebx
	cmovl ebx,ecx
	xor edx,edx
	mov edi, buf
	l1:
	cmp ecx,0
	jle l2
	push ebx ecx edx edi
	read fd,dword[esp],ebx
	pop edi edx ecx ebx
	add edx,eax
	test eax,eax
	jz l2;
	sub ecx,eax
	push ecx eax
	mov ecx,eax
	strnchr edi,0xa,ecx
	pop eax ecx
	cmp byte [edi-1], 0xa
	jne l1
	dec edi
	l2:
	mov byte [edi],0
	sub edi,buf
	mov eax,edx
	dec eax
	sub eax,edi
	jle l3
	back eax
	l3:
}

macro strnchr s,c,count
{
	mov edi,s
	mov eax,c
	mov ecx,count
	cld
	repne scasb
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
	push ebx
	mov ebx,xtbl
	to_num byte [esi]
	pop ebx
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
	local l1,s1,s2,e1,e2
	mov ecx,size
	mov ebx,str
	mov edi,4
	mov esi,16
	xor eax,eax
	
	cmp ecx,4
	jle s1
	pxor xmm2,xmm2
	pcmpeqb xmm2,xmm1
	pmovmskb edx,xmm2
	xor dx,0xffff
	je l1
	cmp ecx,16
	jg s2
	sub ecx,4
	add ebx,ecx
	shl ecx,1
	sub ecx,64
	neg ecx
	movd xmm2,ecx
	psllq xmm1,xmm2
	psrlq xmm1,xmm2
	movd eax,xmm1
	mov ecx,4
	s1:
	pxor xmm1,xmm1
	jmp l1
	s2:
	movd edx,xmm1
	psrldq xmm1,4
	movd eax,xmm1
	cmp ecx,20
	jge s1
	sub ecx,4
	add ebx,ecx
	sub ecx,12
	mov edi,4
	sub edi,ecx
	mov esi,edi
	shl ecx,1
	mov edi,ecx
	sub ecx,32
	neg ecx
	shl edx,cl
	shld eax,edx,8
	sub edi,8
	neg edi
	mov ecx,edi
	shr eax,cl
	mov ecx,4
	mov edi,4
	jmp s1
	l1:
	shl eax,2
	movzx edx,byte[ebx]
	or eax,edx
	dec ecx
	jle e1
	inc ebx
	dec esi
	jnz l1
	pslldq xmm1,4
	movdqa xmm2,xmm1
	movd xmm1,eax
	por xmm1,xmm2
	xor eax,eax
	mov esi,16
	dec edi
	jz e2
	jmp l1
	e1:
	pslldq xmm1,4
	movdqa xmm2,xmm1
	movd xmm1,eax
	por xmm1,xmm2
	dec edi
	e2:
}

macro hashfind data,elements,block,srchstr,srchlen
{
	mov eax,srchstr
	movd xmm0,eax
	hash srchstr,srchlen
	mov ebx,data
	strfind elements,block
}

macro strfind elements,block
{
	local l1,l2,l3,l4,l5,s1,s2,s3,e1
	movdqa xmm2,xmm1
	mov edx,4
	sub edx,edi
	xor eax,eax
	s2:
	movd ecx,xmm2
	shld eax,ecx,16
	and ecx,0xffff
	add eax,ecx
	psrldq xmm2,4
	dec edx
	jnz s2
	s3:
	and eax,0xffff
	xor esi,esi
	shl eax,2
	movd xmm2,eax
	movd xmm3,ebx
	cmp dword[ebx+eax],0
	jne l3
	l1:
	; allocate
	s1:
	mov ebx,1
	xor eax,eax
	lock cmpxchg dword[sema],ebx ; test and set
	and eax,eax
	jnz s1
	add esi,28
	movd eax,xmm2
	movd ebx,xmm3
	ccall realloc,dword[ebx+eax],esi ; realloc is not thread safe
	lock and dword[sema],0 ; reset
	mov esi,eax
	and esi,esi
	jz e2
	movd eax,xmm2
	movd ebx,xmm3
	cmp dword[ebx+eax],0
	mov dword[ebx+eax],esi
	jne l2
	mov esi, dword[ebx+eax]
	mov dword[esi],0
	l2:
	mov ebx,dword[ebx+eax]
	add ebx,4
	mov eax,dword[ebx-4]
	imul eax,24
	mov dword[ebx+eax],0
	movd [ebx+eax+4],xmm0
	movdqu [ebx+eax+8],xmm1
	inc dword[elements]
	inc dword[ebx-4]
	jmp e1
	;search
	l3:
	mov ebx,dword[ebx+eax]
	add ebx,4
	xor eax,eax

	l4:
	mov esi,dword[ebx-4]
	imul esi,24
	cmp eax,esi
	jge l1 ; we need to reallocate
	movdqu xmm4,[ebx+eax+8]
	pcmpeqb xmm4,xmm1
	pmovmskb esi,xmm4
	xor si,0xffff
	jz e1
	
	l5:
	add eax,24
	jmp l4
	e1:
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
	emms
	mov esi,size
	mov ebx,ptr
	mov ecx,dword[ebx]
	cmp ecx,0
	jz e1
	mov edx,dword[sdta]
	inc edx
	sub edx,esi
	push edx
	fild dword[esp]
	mov dword[esp],100
	fild dword[esp]
	add ebx,4
	add esp,4
	l1:
	push ecx ebx esi
	unpack_str lngbuf,dword[ebx+4],size
	pop esi
	mov byte[lngbuf+esi],0
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
	local l1,l2,l3,t1,e1
	mov ecx,size/4
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
	inc dword[cnt]
	l2:
	push ebx ecx
	pxor xmm1,xmm1
	hashfind data,hashtable.elements,8,dword[ebx+4],srchlen
	dec dword[hashtable.elements]
	
	pop ecx ebx
	mov esi, dword[ebx]
	add dword[eax],esi
	add ebx,24
	dec ecx
	jnz l2
	pop ecx ebx
	l3:
	add ebx,4
	dec ecx
	jnz l1
	e1:
}

macro frequencies size
{
	local l1,l2,l3,e1
	mov edx,size
	mov ebx,dword[dta]
	mov ecx,dword[sdta]
	inc ecx
	sub ecx,edx ; loop count
	pushd dword[hashtable.data]
	pushd dword[hashtable.elements]
	push ebx ecx edx
	strncpy tstck-5*4,esp,5*4,0
	strncpy tstck1-5*4,esp,5*4,0
	strncpy tstck2-5*4,esp,5*4,0
	strncpy tstck3-5*4,esp,5*4,0

	sub dword[tstck1-4*4],1
	add dword[tstck1-3*4],1
	add dword[tstck1-1*4],0x40000
	sub dword[tstck2-4*4],2
	add dword[tstck2-3*4],2
	add dword[tstck2-1*4],0x80000
	sub dword[tstck3-4*4],3
	add dword[tstck3-3*4],3
	add dword[tstck3-1*4],0xc0000
	
	sys_clone tstck ;1
	and eax,eax
	jz l1
	push eax
	sys_clone tstck1;2
	and eax,eax
	jz l1
	push eax
	sys_clone tstck2;3
	and eax,eax
	jz l1
	push eax
	sys_clone tstck3;4
	and eax,eax
	jz l1
	sys_wait eax ;1
	pop eax
	sys_wait eax ;2
	pop eax
	sys_wait eax ;3
	pop eax
	sys_wait eax ;4
	pop edx ecx ebx esi esi
	jmp e1
	l1:
	mov ebp,esp
	sub esp,5*4
	
	if 0
	ccall printf,fmt1,ecx
	ccall printf,fmt1,edx
	ccall printf,fmt2,ebx
	end if
	
	l2:
	pop edx ecx ebx
	push ebp
	mov ebp,esp
	pxor xmm1,xmm1
	l3:
;	push ebx ecx edx
	movd xmm5,edx
	movd xmm6,ecx
	movd xmm7,ebx
	hashfind dword [ebp+8], ebp+4,8,ebx,edx
;	pop edx ecx ebx
	movd edx,xmm5
	movd ecx,xmm6
	movd ebx,xmm7
	inc dword[eax]
	add ebx,4 ; interleave
	sub ecx,4
	jg l3
	mov esp,ebp
	pop ebp
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
	sub dword[esp],ecx ; was bug, ecx wasnt counted
						; when raw had more than 1
	l2:
	push ebx ecx
	find dword[sortedtable.data],sortedtable.elements,8,ebx
	pop ecx ebx
	add ebx,24
	dec ecx
	jnz l2
	pop ecx ebx
	and ecx,ecx ; no decrement here
	jz e1
	l3:
	add ebx,4
	jmp l1
	e1:
}

macro mwrite_frequencies ; len
{
	push ebp
	mov ebp,esp
	calc_frequencies dword[ebp+8]
	mov esi,dword[hashtable.data]
	add esi,0x40000
	merge dword[hashtable.data],esi,SIZE,dword[ebp+8]
	mov esi,dword[hashtable.data]
	add esi,0x80000
	merge dword[hashtable.data],esi,SIZE,dword[ebp+8]
	mov esi,dword[hashtable.data]
	add esi,0xc0000
	merge dword[hashtable.data],esi,SIZE,dword[ebp+8]
;	ccall printf,fmt1,dword[cnt]
;	ccall printf,fmt1,dword[sum]
;	ccall printf, fmt1, dword [hashtable.elements]
	initvector sortedtable.data,sortedtable.size,dword[hashtable.elements],24
	mov ebx,dword[hashtable.elements]
	imul ebx,6
	dwordnset dword[sortedtable.data],0,ebx
	sort_frequencies dword[ebp+8]
	print_strs dword[sortedtable.data],dword[ebp+8]
;	ccall printf,fmt1,dword[sortedtable.elements]
	mov dword[sortedtable.elements],0
	mov dword [hashtable.elements],0
	freevector dword[hashtable.data],SIZE
	ccall printf,nl
	mov esp,ebp
	pop ebp
}

macro mwrite_count ; len,str
{
	push ebp
	mov ebp,esp
	mov dword[sum],0
	mov dword[cnt],0
	calc_frequencies dword[ebp+12]
;	ccall printf, fmt1, dword [hashtable.elements]
	mov esi,dword[hashtable.data]
	add esi,0x40000
	merge dword[hashtable.data],esi,SIZE,dword[ebp+12]
	mov esi,dword[hashtable.data]
	add esi,0x80000
	merge dword[hashtable.data],esi,SIZE,dword[ebp+12]
	mov esi,dword[hashtable.data]
	add esi,0xc0000
	merge dword[hashtable.data],esi,SIZE,dword[ebp+12]
;	ccall printf,fmt1,dword[cnt]
;	ccall printf,fmt1,dword[sum]
	pack_str lngbuf,dword[ebp+8],dword[ebp+12],0
	pxor xmm1,xmm1
	hashfind dword[hashtable.data],hashtable.elements,8,lngbuf,edx
	push eax
	unpack_str dword[ebp+8],dword[eax+4],dword[ebp+12]
	pop eax
	ccall printf, fmt5, dword [eax],dword[ebp+8]
;	ccall printf, fmt1, dword [hashtable.elements]
	mov dword [hashtable.elements],0
	freevector dword[hashtable.data],SIZE
	mov esp,ebp
	pop ebp
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

macro write_frequencies len
{
	pushd len
	call swrite_fruequencies
	add esp,4
}

macro write_count len,str
{
	pushd len str
	call swrite_count
	add esp,8
}

STDIN equ 0
STDOUT equ 1
STDERR equ 2
fsize equ 4096
SIZE equ 0x40000 ; play with size and mask in strfind
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
swrite_fruequencies:
	mwrite_frequencies	
	ret
swrite_count:
	mwrite_count
	ret
main:
	strnset xtbl,'A',0
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
	getLine STDIN, buf, 256, 61
	movzx eax, byte [buf]
	and eax,eax
	jz e1
	strncmp buf,three,6,0
	and ecx,ecx
	jnz l2
	l1:
	getLine STDIN, buf, 256, 61
	movzx eax, byte [buf]
	and eax,eax
	jz e1
	cmp eax,'>'
	je e1
	mov eax,edi
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

;	ccall printf,fmt1,dword[sdta]
	cmp dword[sdta],0
	je e3
	
	write_frequencies 1	
	write_frequencies 2

	write_count 3,lngstr4
	write_count 4,lngstr3
	write_count 6,lngstr2
	write_count 12,lngstr1
;	write_count 17,lngstr
	write_count 18,lngstr
;	write_count 19,lngstr
;	write_count 64,lngstr
	e3:
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
fmt4 db "%s %u",0xa,0
fmt5 db "%u",9,"%s",0xa,0
fmt6 db "%u %u",0xa,0
fmt7 db "%x",0xa,0
err1 db "realloc failed",0
err2 db "index error",0
lngstr db "gGtattTtaatttatagt",0
lngstr1 db "ggtATTttaatt",0
lngstr2 db "gGtAtt",0
lngstr3 db "gGta",0
lngstr4 db "GgT",0
three db ">THREE"
nl db 0xa,0

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
fileresbuf rb fsize
filebuf rb fsize
align 4
xtbl rb 256
align 4
lngbuf rb 128
align 4
bstck rb 4095
tstck rb 1
align 4
bstck1 rb 4095
tstck1 rb 1
align 4
bstck2 rb 4095
tstck2 rb 1
align 4
bstck3 rb 4095
tstck3 rb 1
sum rd 1
cnt rd 1
