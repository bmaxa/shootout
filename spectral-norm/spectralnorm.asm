format ELF64

NUMQ equ 4
CPUSETSIZE = NUMQ * 8
STACKSIZE = 4096

FUTEX_WAIT   equ           0 
FUTEX_WAKE   equ           1 
FUTEX_PRIVATE_FLAG equ     128

struc cpu_set_t{
	.bits dq NUMQ dup(?)
}

macro futex_acquire sema{
	local .L0,.L1
	mov r15,sema
.L0:
	mov ebx,1
	xor eax,eax
	lock cmpxchg [r15],ebx
	test eax,eax
	jz .L1
	mov eax, 202
	mov rdi, r15
	mov rsi, FUTEX_WAIT or FUTEX_PRIVATE_FLAG
	mov edx, 1
	xor r10,r10
	syscall
	jmp .L0
.L1:
}

macro futex_release sema{
	lock and dword[sema],0
	mov eax,202
	mov rdi, sema
	mov rsi, FUTEX_WAKE or FUTEX_PRIVATE_FLAG
	mov rdx,1
	syscall
}

struc barrier num{
	.count dd num
	.num dd num
	.mutex dd 0
}

virtual at 0
	oBarrier barrier 0
end virtual

macro futex_barrier barrier{
	local .L0, .L1
	mov r15,barrier
	acquire r15 + oBarrier.mutex
	dec dword[r15 + oBarrier.count]
	jz .L0
	release r15 + oBarrier.mutex
	mov eax, 202
	lea rdi, [r15 + oBarrier.num]
	mov rsi, FUTEX_WAIT or FUTEX_PRIVATE_FLAG
	mov edx, [r15 + oBarrier.num]
	xor r10,r10
	syscall
	jmp .L1
.L0:
;	sys_nanosleep myspec
	sys_sched_yield
	mov eax,[r15 + oBarrier.num]
	mov dword[r15 + oBarrier.count],eax
	mov eax,202
	lea rdi, [r15 + oBarrier.num]
	mov rsi, FUTEX_WAKE or FUTEX_PRIVATE_FLAG
	mov edx, [r15 + oBarrier.num]
	syscall
	release r15 + oBarrier.mutex
.L1:
}

macro acquire sema{
	local .L0
	mov ebx,1
.L0:
	xor eax,eax
	lock cmpxchg [sema],ebx
	test eax,eax
	jnz .L0
}

macro release sema{
	lock and dword[sema],0
}

macro sys_sched_getaffinity set{
	mov eax,204
	xor edi,edi
	mov esi, CPUSETSIZE
	mov rdx,set
	syscall
}

macro sys_sched_setaffinity set{
	mov eax,203
	xor edi,edi
	mov esi, CPUSETSIZE
	mov rdx,set
	syscall
}

CLONE_VM		equ 0x00000100
CLONE_FS		equ 0x00000200
CLONE_FILES		equ 0x00000400
CLONE_SIGHAND	equ 0x00000800
CLONE_THREAD	equ 0x00010000

macro sys_clone stack{
	mov eax,56 ; sys_clone
	mov rdi,CLONE_VM or CLONE_FS or CLONE_FILES \
	or CLONE_SIGHAND or CLONE_THREAD;
	mov rsi,stack ; choose stack
	syscall
}

__WNOTHREAD	equ 0x20000000
__WALL		equ 0x40000000
__WCLONE	equ 0x80000000

macro sys_wait pid{
	mov eax,61 ; sys_wait4
	mov edi,pid
	xor esi,esi
	mov edx,__WALL;
	xor r10d,r10d
	syscall
}

macro sys_gettid{
	mov eax,186 
	syscall
}

macro sys_sched_yield {
	mov eax,24
	syscall
}

macro sys_exit err{
	mov eax,60
	mov rdi,err
	syscall
}

macro sys_exit_group err{
	mov eax,231
	mov rdi,err
	syscall
}

struc timespec tv_sec,tv_nsec{
.tv_sec  dq tv_sec ; seconds 
.tv_nsec dq tv_nsec ; nanoseconds (it must be in range 0 to 999999999)
}

macro sys_nanosleep spec{
	mov eax, 35
	mov rdi, spec
	xor esi,esi
	syscall
}

struc Approximate{
	.u rq 1
	.v rq 1
	.tmp rq 1
	.begin rd 1
	.end rd 1
	.m_vBv rq 1
	.m_vv rq 1
	.mutex rd 1
}


macro padnum [params] 
{   times params-1 db "f" ;66h 
    db 90h 
} 
macro AMDPad16 
{   virtual 
        align 16 
        a = $-$$ 
    end virtual 
                  ;  a+3 
    c=(a+3) shr 2 ;  --- 
                  ;   4 
    repeat c 
        padnum (a-%+c)/c 
    end repeat 
}  

virtual at 0
	Approximate Approximate
	ApproximateSz = $-Approximate
end virtual

section '.text' executable align 16
public main
extrn printf
extrn atoi
extrn malloc
extrn free
extrn valloc

main:
	mov qword[n],100
	mov rax,rdi ; argc
	cmp rax,2
	jl .begin
	mov rdi,[rsi+8] ; argv[1]
	call atoi
	mov [n],rax
.begin:

;	mov qword[myset.bits],1
;	sys_sched_setaffinity myset

	call get_cpu_count
	
	push rax
	mov rdi,msgcount
	mov rsi, rax
	mov rdx, [n]
	xor eax,eax
	call printf
	pop rax

	mov [sbarrier.num],eax
	mov [sbarrier.count],eax
	mov [threadnum],rax
	mov rbp, rsp
	
	sub rsp, 4*8 ; reserve local variables

	u equ rbp-8
	v equ rbp-16
	tmp equ rbp-24
	ap equ rbp-32

	mov rdi,[n]
	imul rdi,8
	call malloc
	mov [u],rax
	
	mov rdi,[n]
	imul rdi,8
	call malloc
	mov [v],rax
	
	mov rdi,[n]
	imul rdi,8
	call malloc
	mov [tmp],rax

	mov rdi,[threadnum]
	imul rdi,ApproximateSz
	call malloc
	mov [ap],rax
	
	mov rdi,[threadnum]
	imul rdi,STACKSIZE
	call valloc
	mov [stacks],rax

	mov rdi,[u]
	mov rax,1.0
	mov rcx,[n]
	cld
	rep stosq ; initialize array u to 1

	xor edx,edx
	mov rax,[n]
	div [threadnum]
	mov r15,rax ; r15 -> chunk
	xor ecx,ecx
.L0:
	mov r14,r15
	imul r14,rcx ; r14 -> begin
	mov r12, [n] ; r12 -> end
	mov r11, r15
	add r11, r14 ; chunk + begin
	mov r13,[threadnum]
	dec r13
	cmp rcx,r13
	cmovl r12,r11 
	
	mov rbx,[ap]
	mov rdi,ApproximateSz
	imul rdi,rcx
	lea rbx,[rbx+rdi]
	
	; init Approx
	mov rax, [u]
	mov [rbx+Approximate.u],rax
	mov rax, [v]
	mov [rbx+Approximate.v],rax
	mov rax, [tmp]
	mov [rbx+Approximate.tmp],rax
	mov [rbx+Approximate.begin],r14d
	mov [rbx+Approximate.end],r12d
	mov qword[rbx+Approximate.m_vBv],0.0
	mov qword[rbx+Approximate.m_vv],0.0
	mov dword[rbx+Approximate.mutex],1
	
	inc rcx
	cmp rcx,[threadnum]
	jl .L0

;	xor ecx,ecx
;.L1:
;	push rcx
;	mov rdi,[ap]
;	imul rbx,rcx,ApproximateSz
;	add rdi,rbx
;	call print_Approximate
;	pop rcx
;	inc rcx
;	cmp rcx,[threadnum]
;	jl .L1
	
	mov rcx,[threadnum]
.L2:
	mov rdx,[stacks]
	imul rbx,rcx,STACKSIZE
	add rdx,rbx
	mov rsi,Approximate_thread
	mov rdi,[ap]
	dec rcx
	imul rbx,rcx,ApproximateSz
	add rdi,rbx
	push rcx
	call start_thread
	pop rcx
	test rcx,rcx
	jnz .L2

	xorpd xmm0,xmm0 ; -> vBv
	xorpd xmm1,xmm1 ; -> vv
	mov rcx,[threadnum]
.L3:
	mov rdx,[ap]
	dec rcx
	imul rbx,rcx,ApproximateSz
	add rdx,rbx
	lea rdx,[rdx+Approximate.mutex]
	push rcx rbx
	futex_acquire rdx
	pop rbx
	mov rdx,[ap]
	addsd xmm0,[rdx+rbx+Approximate.m_vBv]
	addsd xmm1,[rdx+rbx+Approximate.m_vv]
	pop rcx
	test rcx,rcx
	jnz .L3

	divsd xmm0,xmm1
	sqrtsd xmm0,xmm0
	
	sub rsp,8
	mov eax,1
	mov rdi,msgresult
	call printf
	add rsp,8
	
	mov rdi,[u]
	call free
	mov rdi,[v]
	call free
	mov rdi,[tmp]
	call free
	mov rdi,[ap]
	call free
	mov rdi,[stacks]
	call free
	
	xor eax,eax
	mov rsp,rbp
	ret
	
; rax return cpu count
get_cpu_count:
	sys_sched_getaffinity myset
	xor eax,eax
	xor edx,edx
.L0:
	mov ecx,64
	mov rbx,[myset+edx*8]
.L1:
	shr rbx,1
	jnc .L2
	inc eax
.L2:
	loop .L1
	inc edx
	cmp edx,NUMQ
	jl .L0
	ret
; rsi ptr to function, rdi arg to function , rdx top of stack
; returns pid in eax
start_thread:
	push rbp
	mov rbp,rsp
	mov rsp, rdx;
	push rdi rsi
	sub rdx,16 ; adjust stack for thread
	mov rsp,rbp
	
	sys_clone rdx
	test eax,eax
	jnz .L0
	; child
	pop rsi rdi
	call rsi
	sys_exit 0
.L0:; parent
	pop rbp
	ret

align 16
; rdi object
Approximate_thread:
	sub rsp,8 ; align on 16 bytes
	lea rbx, [rdi+Approximate.mutex]
	push rdi rbx
	mov ecx,10
	pop rbx rdi
.L0:
	push rdi rbx rcx
	mov rsi, [rdi+Approximate.u]
	mov rdx, [rdi+Approximate.tmp]
	mov rcx, [rdi+Approximate.v]
	call MultiplyAtAv
	pop rcx rbx rdi
	push rdi rbx rcx
	mov rsi, [rdi+Approximate.v]
	mov rdx, [rdi+Approximate.tmp]
	mov rcx, [rdi+Approximate.u]
	call MultiplyAtAv
	
	pop rcx rbx rdi
	loop .L0

	push rdi rbx
	mov ecx,[rdi+Approximate.begin]
	xorpd xmm2,xmm2
	xorpd xmm3,xmm3
.L1:
	mov rsi,[rdi+Approximate.u]
	movsd xmm0,[rsi+rcx*8]
	mov rsi,[rdi+Approximate.v]
	movsd xmm1,[rsi+rcx*8]
	mulsd xmm0,xmm1
	mulsd xmm1,xmm1
	addsd xmm2,xmm0
	addsd xmm3,xmm1
	inc ecx
	cmp ecx,[rdi+Approximate.end]
	jl .L1
	movsd [rdi+Approximate.m_vBv],xmm2
	movsd [rdi+Approximate.m_vv],xmm3
	;sys_nanosleep myspec
	;acquire sema
	;call print_Approximate
	;release sema
	pop rbx
	futex_release rbx
	pop rdi
	add rsp,8
	ret

; rcx i , rbx j, returns xmm1
macro eval_A i,j{
	mov eax,i
	add eax,j ; i+j
	mov edx,eax
	inc edx ; i+j+1
	imul eax,edx ;
	shr eax,1
	sub edx,j ; i+1
	add eax,edx
	cvtsi2sd xmm1,eax
}

; rdi object , rsi v, rdx Av
align 16
MultiplyAv:
	push rdx rsi
	v equ rsp
	Atv equ rsp+8
	
	mov ecx,[rdi+Approximate.begin]
	mov r8, [n]
;	AMDPad16
.L0:
	dec r8
	xorpd xmm0,xmm0
	xor ebx,ebx
;	AMDPad16
.L1:
	mov rsi,[v]
	movupd xmm2,[rsi+rbx*8]
	eval_A ecx,ebx
	movapd xmm3,xmm1
	inc ebx
	eval_A ecx,ebx
	shufpd xmm3,xmm1,0
	divpd xmm2,xmm3
	addpd xmm0,xmm2
	inc ebx
	cmp rbx,r8
	jl .L1
	inc r8
	cmp rbx,r8
	jge .L2
	mov rsi,[v]
	movsd xmm2,[rsi+rbx*8]
	eval_A ecx,ebx
	divsd xmm2,xmm1
	addpd xmm0,xmm2
.L2:
	haddpd xmm0,xmm0
	mov rdx,[Atv]
	movsd [rdx+rcx*8],xmm0
	inc ecx
	cmp ecx,[rdi+Approximate.end]
	jl .L0
	add rsp,16 
	ret

align 16	
; rdi object, rsi v , rdx Atv
MultiplyAtv:
	push rdx rsi
	v equ rsp
	Atv equ rsp+8
	
	mov ecx,[rdi+Approximate.begin]
	mov r8, [n]
;	AMDPad16
.L0:
	dec r8
	xorpd xmm0,xmm0
	xor ebx,ebx
;	AMDPad16
.L1:
	mov rsi,[v]
	movupd xmm2,[rsi+rbx*8]
	eval_A ebx,ecx
	movapd xmm3,xmm1
	inc ebx
	eval_A ebx,ecx
	shufpd xmm3,xmm1,0
	divpd xmm2,xmm3
	addpd xmm0,xmm2
	inc ebx
	cmp rbx,r8
	jl .L1
	inc r8
	cmp rbx,r8
	jge .L2
	mov rsi,[v]
	movsd xmm2,[rsi+rbx*8]
	eval_A ebx,ecx
	divsd xmm2,xmm1
	addpd xmm0,xmm2
.L2:
	haddpd xmm0,xmm0
	mov rdx,[Atv]
	movsd [rdx+rcx*8],xmm0
	inc ecx
	cmp ecx,[rdi+Approximate.end]
	jl .L0
	add rsp,16 
	ret

align 16
; rdi object, rsi v, rdx tmp, rcx AtAv
MultiplyAtAv:
	push rdi rsi rdx rcx
	call MultiplyAv
	futex_barrier sbarrier
	pop rcx rdx rsi rdi
	mov rsi,rdx
	mov rdx,rcx
	call MultiplyAtv
	futex_barrier sbarrier
	ret
	
print_Approximate:
	push rdi
	mov esi, [rdi+Approximate.begin]
	mov edx, [rdi+Approximate.end]
	mov ecx, [rdi+Approximate.mutex]
	movsd xmm0, [rdi+Approximate.m_vBv]
	movsd xmm1, [rdi+Approximate.m_vv]
	mov rdi, msgap
	mov eax,2
	call printf
	mov rdi,[rsp]
	mov ecx,[rdi+Approximate.begin]
.L0:
	mov rdi,[rsp]
	push rcx rcx
	mov rsi,[rdi+Approximate.u]
	movsd xmm0,[rsi+rcx*8]
	mov rsi,[rdi+Approximate.v]
	movsd xmm1,[rsi+rcx*8]
	mov rsi,[rdi+Approximate.tmp]
	movsd xmm2,[rsi+rcx*8]
	mov rsi,rcx
	mov rdx,rcx
	mov rdi,msgarr
	mov eax,3
	call printf
	pop rcx rcx
	inc ecx
	mov rdi,[rsp]
	cmp ecx,[rdi+Approximate.end]
	jl .L0
	pop rdi
	ret
	
section '.data' writeable align 16

myset cpu_set_t
myspec timespec 0,1000

msgcount db 'cpu count : %lu, input param : %lu',0xa,0
msgresult db '%.9f',0xa,0
msgap db 'begin: %u , end %u , m_vBv %.9f, m_vv %.9f , mutex %u',0xa,0
msgarr db 'u[%u] = %.9f, v[%u] = %.9f, tmp[%u] = %.9f',0xa,0
align 8
sema dd 0
leavesema dd 1
tbarrier barrier 10
sbarrier barrier 0

section '.bss' writeable align 16
stacks rq 1
n rq 1
threadnum rq 1
