format ELF64

NUMQ equ 4
CPUSETSIZE = NUMQ * 8
STACKSIZE = 4096
NUMTHREADS = 503

FUTEX_WAIT   equ           0 
FUTEX_WAKE   equ           1 
FUTEX_PRIVATE_FLAG equ     128

struc cpu_set_t{
	.bits dq NUMQ dup(?)
}

struc Thread{
.mutex rd 1
.node_id rd 1
.next_id rd 1
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

macro acquire sema{
	local .L0,.L1
	mov ebx,1
.L0:
	xor eax,eax
	lock cmpxchg [sema],ebx
	test eax,eax
    jz .L1
    pause 
	jmp .L0
.L1:    
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

virtual at 0
	oThread Thread
end virtual

section '.text' executable align 16
public main
extrn printf
extrn atoi

main:
	mov qword[token],1000
	mov rax,rdi ; argc
	cmp rax,2
	jl .begin
	mov rdi,[rsi+8] ; argv[1]
	call atoi
	mov [token],rax
.begin:
	sub rsp,16

	mov qword[myset.bits],1
	sys_sched_setaffinity myset

;	call get_cpu_count
;	mov rdi,msgcount
;	mov rsi, rax
;	mov rdx, [token]
;	xor eax,eax
;	call printf
	
;	mov ecx,NUMQ
;.L0:
;	xor eax,eax
;	mov rdi,msgmask
;	mov rsi,rcx
;	mov rdx, [myset + ecx*8-8]
;	push rcx
;	call printf
;	pop rcx
;	loop .L0

;	mov rdx,stacks+4096
;	mov rsi,thread
;	mov rdi,167
;	call start_thread
	
	xor rcx,rcx
.L1:
	mov rsi,rcx
	imul rbx,rcx,12
	lea rdi,[threads+rbx]
	push rcx rbx
	call init_ring_thread
	pop rbx rcx
	
	imul rdx,rcx,STACKSIZE
	add rdx, STACKSIZE
	mov rsi,ring_thread
	lea rdx,[stacks+rdx]
	lea rdi,[threads+rbx]
	push rcx
	call start_thread
	pop rcx
	inc rcx
	cmp rcx,NUMTHREADS
	jl .L1
	
;	acquire sema
	
;	mov rdi,msgwait
;	xor eax,eax
;	call printf
	
;	release sema

	lea rsi,[threads+oThread.mutex]
	futex_release rsi ; let's start ring
	
	futex_acquire leavesema ; wait for exit
	
;	mov rdi,msgdonewait
;	xor eax,eax
;	call printf
	
	xor eax,eax
	add rsp,16
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
	loop .L1
	inc edx
	cmp edx,NUMQ
	jl .L0
.L2:
	ret
; rsi ptr to function, rdi arg to function , rdx top of stack
; returns pid in eax
start_thread:
	
	push rdi rsi
	
	mov rbp,rsp
	mov rsp, rdx;
	push rdi rsi
	sub rdx,16
	mov rsp,rbp
	
	sys_clone rdx
	test eax,eax
	jnz .L0
	; child
	pop rsi rdi
	call rsi
	sys_exit 0
.L0:; parent
	add rsp,16
	ret

	virtual at rdi
		rThread Thread
	end virtual

; rdi pointer to object, rsi id
init_ring_thread:
	mov [rThread.node_id],esi
	inc esi
	xor eax,eax
	cmp esi,NUMTHREADS
	cmove esi,eax
	mov [rThread.next_id],esi
	
;	acquire sema
;	mov esi,[rThread.node_id]
;	mov edx,[rThread.next_id]
;	mov ecx,[rThread.mutex]
;	xor eax,eax
;	mov rdi,msginit
;	call printf
;	release sema

	ret
	
ring_thread:
	sub rsp,8
.L0:
	lea rsi,[rThread.mutex]
	push rdi
	futex_acquire rsi
	pop rdi
	
	;push rdi
	;acquire sema
	;mov esi,[rThread.node_id]
	;mov edx,[rThread.next_id]
	;mov ecx,[rThread.mutex]
	;xor eax,eax
	;mov rdi,msgorig
	;call printf
	;release sema
	;pop rdi
	
	cmp qword[token],0
	je .L1
	dec qword[token]
	
	mov ebx,[rThread.next_id]
	imul rbx,rbx,12
	lea rbx,[threads+rbx+oThread.mutex]
	
	push rdi
	futex_release rbx
	pop rdi
	
	;push rdi
	
	;push rbx
	;acquire sema
	;pop rbx
	
	;mov esi,[rbx + oThread.node_id]
	;mov edx,[rbx + oThread.next_id]
	;mov ecx,[rbx + oThread.mutex]
	;xor eax,eax
	;mov rdi,msgnext
	;call printf
	;release sema
	;pop rdi

	jmp .L0
.L1:
	mov esi,[rThread.node_id]
	inc esi
	xor eax,eax
	mov rdi,msgnode
	call printf
	futex_release leavesema
	add rsp,8
	ret
	
thread: ; demo function
	sub rsp,2048
	mov rdx,rdi
	lea rdi,[rsp]
	mov rcx,2048
	mov rax,255
	rep stosb
	
	acquire sema
	
	mov rdi,msgthread
	mov rsi,rdx
	xor eax,eax
	call printf
	
	release sema
	
	sys_nanosleep myspec
	add rsp,2048
	futex_release leavesema
	ret
	
section '.data' writeable align 16

myset cpu_set_t
myspec timespec 5,0

msgmask db 'mask %2u : %16lx',0xa,0
msgcount db 'cpu count : %lu, input param : %lu',0xa,0
msgwait db 'parent, waiting for child',0xa,0
msgdonewait db 'parent, child exited',0xa,0
msgthread db 'child received %u, sleeping',0xa,0 
msgnode db '%u',0xa,0
msginit db 'Init node_id : %u next_id : %u'
		db ' mutex : %u',0xa,0
msgorig db 'Original node_id : %u next_id : %u'
		db ' mutex : %u',0xa,0
msgnext db 'Next node_id : %u next_id : %u'
		db ' mutex : %u',0xa,0
msgenter db 'enter',0xa,0
align 8
threads dd NUMTHREADS dup(1,0,0)
sema dd 0
leavesema dd 1

section '.bss' writeable align 16
stacks rd STACKSIZE*NUMTHREADS
token rq 1
