format ELF64

SIZEOFBODY equ 96
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
.filler1 dq ?
.mass	dq 4 dup(?)
}

macro init_body b, x,y,z,vx,vy,vz,mass{
	mov rax,x
	mov rbx,y
	mov rcx,z
	xor rdx,rdx
	mov [b#.x],rax
	mov [b#.y],rbx
	mov [b#.z],rcx
	mov [b#.filler],rdx

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

	mov [b#.filler1],rdx

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
local .L0,.L1,.L2,.L3,.L4,.L5
	mov ecx,4 ; ecx - > i
	mov rsi,rr
	mov rbx,sun
.L0:
	mov r9d, ecx ; r9 -> j 
	lea rdx, [rbx + SIZEOFBODY]
	vmovapd ymm0,qqword[rbx + oBody.x]
.L1:
	vsubpd ymm1, ymm0, qqword[rdx + oBody.x]; dx,dy,dz -> xmm0

	vmovapd qqword[rsi+r.dx],ymm1

	add rsi, SIZEOFDIFF
	add rdx, SIZEOFBODY
	dec r9d
	jnz .L1
	add rbx, SIZEOFBODY
	dec ecx
	jnz .L0
;-----------------------------------
	mov ecx,3
	mov rsi,rr
	mov rdi,mag
.L2:

	vmovsd xmm3,[rsi+r.dx]
	vmovsd xmm4,[rsi+r.dy]
	vmovsd xmm5,[rsi+r.dz]
	
	vmovhpd xmm3,xmm3,[rsi+r.dx+SIZEOFDIFF]
	vmovhpd xmm4,xmm4,[rsi+r.dy+SIZEOFDIFF]
	vmovhpd xmm5,xmm5,[rsi+r.dz+SIZEOFDIFF]

	vmovsd xmm13,[rsi+r.dx+2*SIZEOFDIFF]
	vmovsd xmm14,[rsi+r.dy+2*SIZEOFDIFF]
	vmovsd xmm15,[rsi+r.dz+2*SIZEOFDIFF]
	
	vmovhpd xmm13,xmm13,[rsi+r.dx+3*SIZEOFDIFF]
	vmovhpd xmm14,xmm14,[rsi+r.dy+3*SIZEOFDIFF]
	vmovhpd xmm15,xmm15,[rsi+r.dz+3*SIZEOFDIFF]

	vinsertf128 ymm3,ymm3,xmm13,1
	vinsertf128 ymm4,ymm4,xmm14,1
	vinsertf128 ymm5,ymm5,xmm15,1

	vmulpd ymm3,ymm3,ymm3
	vmulpd ymm4,ymm4,ymm4
	vmulpd ymm5,ymm5,ymm5
	
	vaddpd ymm3,ymm3,ymm4
	vaddpd ymm3,ymm3,ymm5 ; dsquared -> xmm3
	
	;vcvtpd2ps xmm4, ymm3
	;vrsqrtps xmm4,xmm4
	;vcvtps2pd ymm4,xmm4
    vsqrtpd ymm4,ymm3
    vmulpd ymm3,ymm3,ymm4
	;----------------------------------------
	vdivpd ymm6,ymm12,ymm3
	;vmulpd ymm3,ymm3,yword[L2]
	;vmovapd ymm7,ymm4
	
	;vmovapd ymm8,ymm3
	;vmulpd ymm8,ymm8,ymm7
	;vmulpd ymm8,ymm8,ymm7
	;vmulpd ymm8,ymm8,ymm7

	;vmulpd ymm7,ymm7,yword[L1]
	
	;vsubpd ymm7,ymm7,ymm8
	;-----------------------------------------
	;vmovapd ymm8,ymm3
	;vmulpd ymm8,ymm8,ymm7
	;vmulpd ymm8,ymm8,ymm7
	;vmulpd ymm8,ymm8,ymm7

	;vmulpd ymm7,ymm7,yword[L1]

	;vsubpd ymm7,ymm7,ymm8
	;-----------------------------------------
	
	;vmulpd ymm6,ymm6,ymm7 ; mag -> xmm6
	
	vmovapd yword[rdi],ymm6

	add rdi,32
	add rsi,4*SIZEOFDIFF
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
	vbroadcastsd ymm6, [rdx + oBody.mass]
	vbroadcastsd ymm7, [rdi]
	vmulpd ymm6, ymm6, ymm7 ; precompute bodies[j].mass * mag
	
	vmovapd ymm10,qqword[rsi+r.dx]
	vmovapd ymm3, qqword[rbx + oBody.vx]
	
	vmulpd ymm8, ymm10, ymm6
	vsubpd ymm3, ymm3, ymm8

	vmovapd qqword[rbx + oBody.vx],ymm3 
	; iBody.vx -= dx * bodies[j].mass * mag;
; ----------------------------------------------
	vbroadcastsd ymm6, [rbx + oBody.mass]
	vmulpd ymm6, ymm6, ymm7 ; precompute iBody.mass * mag

	vmovapd ymm3, qqword[rdx + oBody.vx]
	
	vmulpd ymm0, ymm10, ymm6
	vaddpd ymm3, ymm3, ymm0

	vmovapd qqword[rdx + oBody.vx], ymm3 
	; bodies[j].vx += dx * iBody.mass * mag;
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
	vmovapd ymm0, qqword[rbx + oBody.x]
	
	vmulpd ymm3, ymm12, qqword[rbx + oBody.vx]
	vaddpd ymm0, ymm0, ymm3

	vmovapd qqword[rbx + oBody.x], ymm0

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
	call printf
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
	call printf

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
	mov [det],rax
	vzeroall
	vbroadcastsd ymm12,[det]
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
	call printf
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
	call printf
	add rsp, 8
	ret
	
section '.data' writeable align 32

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
align 32
L1 dq 4 dup(1.5)
L2 dq 4 dup(0.5)
align 32
rr dq 4 * 20 dup(0.0)
align 32
mag dq 20 dup(0.0)

section '.bss' writeable align 32

sun body
jupiter body
saturn body
uranus body
neptune body


n rq 1
det rq 1
