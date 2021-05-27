format ELF64

SIZEOFBODY equ 56
struc body {
.x	dq ?
.y	dq ?
.z	dq ?
.vx	dq ?
.vy	dq ?
.vz	dq ?
.mass	dq ?
}

macro init_body b, x,y,z,vx,vy,vz,mass{
	mov rax,x
	mov [b#.x],rax
	mov rax,y
	mov [b#.y],rax
	mov rax,z
	mov [b#.z],rax

	mov rax, vx
	movq xmm0,rax
	mulsd xmm0,[DAYS_PER_YEAR]
	movsd [b#.vx],xmm0

	mov rax,vy
	movq xmm0,rax
	mulsd xmm0,[DAYS_PER_YEAR]
	movsd [b#.vy],xmm0

	mov rax,vz
	movq xmm0,rax
	mulsd xmm0,[DAYS_PER_YEAR]
	movsd [b#.vz],xmm0

	mov rax,mass
	movq xmm0,rax
	mulsd xmm0,[SOLAR_MASS]
	movsd [b#.mass],xmm0
}

virtual at 0
	oBody body
end virtual

macro advance dt
{
local .L0,.L1,.L2,.L3
	mov ecx,5 ; ecx - > i
	mov rax,dt
	mov rbx,sun
.L0:
	dec ecx
	jz .L2
	mov r9, rcx ; r9 -> j 
	lea rdx, [rbx+SIZEOFBODY]
.L1:
	movsd xmm0,[rbx + oBody.x]
	movsd xmm1,[rbx + oBody.y]
	movsd xmm2,[rbx + oBody.z]

	subsd xmm0,[rdx + oBody.x] ; dx -> xmm0
	subsd xmm1,[rdx + oBody.y] ; dy -> xmm1
	subsd xmm2,[rdx + oBody.z] ; dz -> xmm2
	
	movsd xmm3,xmm0
	movsd xmm4,xmm1
	movsd xmm5,xmm2
	
	mulsd xmm3,xmm3
	mulsd xmm4,xmm4
	mulsd xmm5,xmm5
	
	addsd xmm3,xmm4
	addsd xmm3,xmm5 ; dsquared -> xmm3
	
	sqrtsd xmm4, xmm3 ; distance -> xmm4
	
	mulsd xmm3,xmm4
	movq xmm5, rax
	divsd xmm5,xmm3 ; mag -> xmm5
	
	movsd xmm6, [rdx + oBody.mass]
	mulsd xmm6, xmm5 ; precompute bodies[j].mass * mag

	movsd xmm3, [rbx + oBody.vx]
	movsd xmm4, xmm0
	mulsd xmm4, xmm6
	subsd xmm3,xmm4
	movsd [rbx + oBody.vx],xmm3 ; iBody.vx -= dx * bodies[j].mass * mag;

	movsd xmm3, [rbx + oBody.vy]
	movsd xmm4, xmm1
	mulsd xmm4, xmm6
	subsd xmm3,xmm4
	movsd [rbx + oBody.vy],xmm3

	movsd xmm3, [rbx + oBody.vz]
	movsd xmm4, xmm2
	mulsd xmm4, xmm6
	subsd xmm3,xmm4
	movsd [rbx + oBody.vz],xmm3
; ----------------------------------------------
	movsd xmm6, [rbx + oBody.mass]
	mulsd xmm6, xmm5 ; precompute iBody.mass * mag

	movsd xmm3, [rdx + oBody.vx]
	movsd xmm4, xmm0
	mulsd xmm4, xmm6
	addsd xmm3, xmm4
	movsd [rdx + oBody.vx], xmm3 ; bodies[j].vx += dx * iBody.mass * mag;

	movsd xmm3, [rdx + oBody.vy]
	movsd xmm4, xmm1
	mulsd xmm4, xmm6
	addsd xmm3, xmm4
	movsd [rdx + oBody.vy], xmm3

	movsd xmm3, [rdx + oBody.vz]
	movsd xmm4, xmm2
	mulsd xmm4, xmm6
	addsd xmm3, xmm4
	movsd [rdx + oBody.vz], xmm3
;-----------------------------------------	
	add rdx,SIZEOFBODY
	dec r9
	jnz .L1
	add rbx,SIZEOFBODY
	jmp .L0
.L2:
	mov rbx,sun
	mov ecx,5
.L3:
	movsd xmm0, [rbx + oBody.x]
	movsd xmm1, [rbx + oBody.y]
	movsd xmm2, [rbx + oBody.z]
	
	movq xmm3 , rax
	mulsd xmm3, [rbx + oBody.vx]
	addsd xmm0, xmm3
	movsd [rbx + oBody.x], xmm0
	
	movq xmm3 , rax
	mulsd xmm3, [rbx + oBody.vy]
	addsd xmm1, xmm3
	movsd [rbx + oBody.y], xmm1

	movq xmm3 , rax
	mulsd xmm3, [rbx + oBody.vz]
	addsd xmm2, xmm3
	movsd [rbx + oBody.z], xmm2

	add rbx,SIZEOFBODY
	dec ecx
	jnz .L3
	
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
	call atoi
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
.L1:
	advance 0.01
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

section '.bss' writeable align 16


sun body
jupiter body
saturn body
uranus body
neptune body

n rq 1
