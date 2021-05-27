format ELF64

SIZEOFBODY equ 64
SIZEOFDIFF equ 32
struc diff{
.dx dq ?
.dy dq ?
.dz dq ?
.filler dq ?
}
struc body {
.x	dq ?
.y	dq ?
.z	dq ?
.filler dq ?
.vx	dq ?
.vy	dq ?
.vz	dq ?
.mass	dq ?
}

macro init_body b, x,y,z,vx,vy,vz,mass{
	mov rax,x
	mov rbx,y
	mov rcx,z
	mov [b#.x],rax
	mov [b#.y],rbx
	mov [b#.z],rcx

	movsd xmm1,[DAYS_PER_YEAR]
	
	mov rax, vx
	movq xmm0,rax
	mulsd xmm0,xmm1
	movsd [b#.vx],xmm0

	mov rax,vy
	movq xmm0,rax
	mulsd xmm0,xmm1
	movsd [b#.vy],xmm0

	mov rax,vz
	movq xmm0,rax
	mulsd xmm0,xmm1
	movsd [b#.vz],xmm0

	mov rax,mass
	movq xmm0,rax
	mulsd xmm0,[SOLAR_MASS]
	movsd [b#.mass],xmm0
}

virtual at 0
	oBody body
end virtual
virtual at 0
	 r diff
end virtual

macro advance
{
; xmm15 holds dt
local .L0,.L1,.L2,.L3,.L4,.L5
	mov ecx,4 ; ecx - > i
	mov rsi,rr
	mov rbx,sun
.L0:
	mov r9d, ecx ; r9 -> j 
	lea rdx, [rbx + SIZEOFBODY]
.L1:

	movapd xmm0,dqword[rbx + oBody.x]
	movsd xmm1,[rbx + oBody.z]
	
	subpd xmm0, dqword[rdx + oBody.x]; dx,dy -> xmm0
	subsd xmm1,[rdx + oBody.z] ; dz -> xmm2

	movapd dqword[rsi+r.dx],xmm0
	movsd [rsi+r.dz],xmm1

	add rsi, SIZEOFDIFF
	add rdx, SIZEOFBODY
	dec r9d
	jnz .L1
	add rbx, SIZEOFBODY
	dec ecx
	jnz .L0
;-----------------------------------	
	mov ecx,5
	mov rsi,rr
	mov rdi,mag
.L2:

	movsd xmm3,[rsi+r.dx]
	movsd xmm4,[rsi+r.dy]
	movsd xmm5,[rsi+r.dz]
	
	movhpd xmm3,[rsi+r.dx+SIZEOFDIFF]
	movhpd xmm4,[rsi+r.dy+SIZEOFDIFF]
	movhpd xmm5,[rsi+r.dz+SIZEOFDIFF]

	movddup xmm6,xmm15
	
	mulpd xmm3,xmm3
	mulpd xmm4,xmm4
	mulpd xmm5,xmm5
	
	addpd xmm3,xmm4
	addpd xmm3,xmm5 ; dsquared -> xmm3
	
	;sqrtpd xmm4, xmm3 ; distance -> xmm4
;	cvtpd2ps xmm4,xmm3
;	rsqrtps xmm4,xmm4
        sqrtpd xmm7,xmm3
        mulpd xmm3,xmm7
	divpd xmm6,xmm3 
;	mulpd xmm3,dqword[L2]
;	cvtps2pd xmm4,xmm4
	;--------------------
	
;	movapd xmm7, xmm4
	
;	movapd xmm8,xmm3
;	mulpd xmm8, xmm7
;	mulpd xmm8, xmm7
;	mulpd xmm8, xmm7

;	mulpd xmm7,dqword[L1]

;	subpd xmm7,xmm8
	
	;------------------------
	
;	movapd xmm8,xmm3
;	mulpd xmm8, xmm7
;	mulpd xmm8, xmm7
;	mulpd xmm8, xmm7

;	mulpd xmm7,dqword[L1]
	
;	subpd xmm7,xmm8 ; distance -> xmm7
	
	;--------------------------
	
;	mulpd xmm6,xmm7 ; mag -> xmm6
	
	movapd dqword[rdi],xmm6

	add rdi,16
	add rsi,2*SIZEOFDIFF
	dec ecx
	jnz .L2
;-----------------------------------------------	
	mov ecx,4
	mov rbx,sun
	mov rsi,rr
	mov rdi,mag
.L3:
	mov r9d, ecx
	lea rdx, [rbx+SIZEOFBODY]
.L4:	
	movsd xmm6, [rdx + oBody.mass]
	mulsd xmm6, [rdi] ; precompute bodies[j].mass * mag
	movddup xmm6,xmm6

	movapd xmm10,dqword[rsi+r.dx]
	movsd xmm11,[rsi+r.dz]
	
	movapd xmm3, dqword[rbx + oBody.vx]
	movsd xmm4, [rbx + oBody.vz]
	
	movapd xmm8, xmm10
	movapd xmm9, xmm11
	mulpd xmm8, xmm6
	mulsd xmm9, xmm6
	subpd xmm3,xmm8
	subsd xmm4,xmm9

	movapd dqword[rbx + oBody.vx],xmm3 
	; iBody.vx -= dx * bodies[j].mass * mag;
	movsd [rbx + oBody.vz],xmm4
; ----------------------------------------------
	movsd xmm7, [rbx + oBody.mass]
	mulsd xmm7, [rdi] ; precompute iBody.mass * mag
	movddup xmm7,xmm7

	movapd xmm3, dqword[rdx + oBody.vx]
	movsd xmm4, [rdx + oBody.vz]
	
	movapd xmm0, xmm10
	movapd xmm2, xmm11
	mulpd xmm0, xmm7
	mulsd xmm2, xmm7
	addpd xmm3, xmm0
	addsd xmm4, xmm2

	movapd dqword[rdx + oBody.vx], xmm3 
	; bodies[j].vx += dx * iBody.mass * mag;
	movsd [rdx + oBody.vz], xmm4
;-----------------------------------------	
	add rdx,SIZEOFBODY
	add rsi,SIZEOFDIFF
	add rdi,8
	dec r9d
	jnz .L4
	add rbx,SIZEOFBODY
	dec ecx
	jnz .L3

	mov rbx,sun
	mov ecx,5
.L5:
	movapd xmm0, dqword[rbx + oBody.x]
	movsd xmm1, [rbx + oBody.z]

	movddup xmm2 , xmm15
	movapd xmm3, xmm15
	
	mulpd xmm2,dqword[rbx + oBody.vx]
	mulsd xmm3, [rbx + oBody.vz]
	addpd xmm0, xmm2
	addsd xmm1, xmm3

	movapd dqword[rbx + oBody.x], xmm0
	movsd [rbx + oBody.z], xmm1

	add rbx,SIZEOFBODY
	dec ecx
	jnz .L5
	
}

section '.text' executable align 16
extrn printf
extrn atoi
public main

main:
	mov qword[n],1
	; rdi - > argc , rsi -> argv
	cmp rdi,2
	jl .begin
	mov rdi,qword[rsi+8] ; argv[1] -> rdi
	call plt atoi
	mov qword[n],rax
	
	mov eax,0
	mov rdi, argv
	mov rsi,[n]
	sub rsp,8
	call plt printf
	add rsp,8
.begin:
	sub rsp,8
	mov eax,2
	mov rdi,message

	; init solar mass 
	movsd xmm0, qword[PI]
	movsd xmm1,xmm0
	mulsd xmm0,qword[SOLAR_MASS]
	mulsd xmm0,xmm1
	movsd [SOLAR_MASS],xmm0
	call plt printf

	; init bodies 
	init_body sun,0f,0f,0f,0f,0f,0f,1f

	init_body jupiter,4.84143144246472090e+00, \
                          -1.16032004402742839e+00,\
                          -1.03622044471123109e-01,\
                          1.66007664274403694e-03, \
                          7.69901118419740425e-03, \
                          -6.90460016972063023e-05,\
                          9.54791938424326609e-04;
        mov rbx,jupiter
	call print_body

	init_body saturn,8.34336671824457987e+00, \
                         4.12479856412430479e+00, \
                         -4.03523417114321381e-01,\
                         -2.76742510726862411e-03,\
                         4.99852801234917238e-03, \
                         2.30417297573763929e-05, \
                         2.85885980666130812e-04;
        mov rbx,saturn
	call print_body

	init_body uranus,1.28943695621391310e+01, \
                         -1.51111514016986312e+01,\
                         -2.23307578892655734e-01,\
                         2.96460137564761618e-03, \
                         2.37847173959480950e-03, \
                         -2.96589568540237556e-05,\
                         4.36624404335156298e-05
        mov rbx,uranus
	call print_body

	init_body neptune,1.53796971148509165e+01, \
                          -2.59193146099879641e+01,\
                          1.79258772950371181e-01, \
                          2.68067772490389322e-03, \
                          1.62824170038242295e-03, \
                          -9.51592254519715870e-05,\
                          5.15138902046611451e-05;
        mov rbx,neptune
	call print_body

	pxor xmm0,xmm0
	pxor xmm1,xmm1
	pxor xmm2,xmm2
	
	virtual at rbx
		.oBody body
	end virtual
	
	mov rbx,sun
	mov ecx,5
; init
; ----------------------------------
.L0:
	movsd xmm3, [.oBody.vx]
	mulsd xmm3, [.oBody.mass]
	addsd xmm0, xmm3
	
	movsd xmm3, [.oBody.vy]
	mulsd xmm3, [.oBody.mass]
	addsd xmm1, xmm3

	movsd xmm3, [.oBody.vz]
	mulsd xmm3, [.oBody.mass]
	addsd xmm2, xmm3
	
	add rbx, SIZEOFBODY ; 
	dec ecx
	jnz .L0

	mov rbx,sun
	call offset_momentum
	call print_body
; ----------------------------------------	
	call energy
	call print_energy

	mov r8, [n]
	mov rax,0.01
	movq xmm15,rax
.L1:
	advance
	dec r8
	jnz .L1

	call energy
	call print_energy

	add rsp,8
	xor eax,eax
	ret

; px xmm0 , py xmm1 , pz xmm2
offset_momentum:
	virtual at rbx
		.oBody body
	end virtual

	mov rax,0x8000000000000000
	movq xmm3, rax

	xorpd xmm0,xmm3
	xorpd xmm1,xmm3
	xorpd xmm2,xmm3
	divsd xmm0,[SOLAR_MASS]
	divsd xmm1,[SOLAR_MASS]
	divsd xmm2,[SOLAR_MASS]
	movsd [.oBody.vx],xmm0
	movsd [.oBody.vy],xmm1
	movsd [.oBody.vz],xmm2
	ret

print_body:
	virtual at rbx
		.oBody body
	end virtual
	sub rsp,8
	mov eax,7
	mov rdi,bmsg
	movq xmm0,[.oBody.x]
	movq xmm1,[.oBody.y]
	movq xmm2,[.oBody.z]
	movq xmm3,[.oBody.vx]
	movq xmm4,[.oBody.vy]
	movq xmm5,[.oBody.vz]
	movq xmm6,[.oBody.mass]
	call plt printf
	add rsp,8
	ret
; xmm0 resulting energy
energy:
	virtual at rbx
		.iBody body
	end virtual
	virtual at rdx
		.jBody body
	end virtual
	mov rbx, sun
	mov ecx, 5
	mov rax,0.0
	movq xmm0, rax
	mov rax,0.5
.L0:
	
	movsd xmm1, [.iBody.vx]
	mulsd xmm1,xmm1
	
	movsd xmm2, [.iBody.vy]
	mulsd xmm2,xmm2
	
	movsd xmm3, [.iBody.vz]
	mulsd xmm3,xmm3
	
	addsd xmm1, xmm2
	addsd xmm1, xmm3
	
	mulsd xmm1, [.iBody.mass]
	
	movq xmm2, rax
	mulsd xmm2, xmm1
	
	addsd xmm0, xmm2
	
	dec ecx
	jz .L2

	lea rdx, [rbx+SIZEOFBODY]
	push rcx
.L1:
	movsd xmm1, [.iBody.x]	
	subsd xmm1, [.jBody.x]

	movsd xmm2, [.iBody.y]	
	subsd xmm2, [.jBody.y]

	movsd xmm3, [.iBody.z]	
	subsd xmm3, [.jBody.z]
	
	mulsd xmm1,xmm1
	mulsd xmm2,xmm2
	mulsd xmm3,xmm3
	
	addsd xmm1, xmm2
	addsd xmm1, xmm3
	
	sqrtsd xmm1,xmm1
	
	movsd xmm2, [.iBody.mass]
	mulsd xmm2, [.jBody.mass]
	divsd xmm2, xmm1
	
	subsd xmm0, xmm2
	add rdx, SIZEOFBODY
	dec ecx
	jnz .L1

	add rbx, SIZEOFBODY
	pop rcx
	jmp .L0	
.L2:
	ret

print_energy:
	sub rsp,8
	mov eax,1
	mov rdi, msg
	call plt printf
	add rsp, 8
	ret
	
section '.data' writeable align 16

message db	'Hello World %2.9f %2.9f !',0xa,0
bmsg db 'x: %.9f',0xa,'y: %.9f',0xa,'z: %.9f',0xa, \
        'vx: %.9f',0xa,'vy: %.9f',0xa,'vz: %.9f',0xa, \
        'mass: %.9f',0xa,0xa,0
msg db '%.9f',0xa,0
argv db 'argv : %d',0xa,0
align 8
PI dq 3.141592653589793
SOLAR_MASS dq 4.0
DAYS_PER_YEAR dq 365.24
align 16
L1 dq 2 dup(1.5)
L2 dq 2 dup(0.5)

section '.bss' writeable align 16

sun body
jupiter body
saturn body
uranus body
neptune body

rr rq 40
mag rq 10

n rq 1
