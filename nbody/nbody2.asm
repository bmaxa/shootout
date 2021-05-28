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

macro scatterq p1,p2,p3,p4 {
  i=0
  repeat 2
    pextrq rax,p2,i
    pextrq r15,p4,i
    mov [p1+rax*p3],r15
    i=i+1
  end repeat
}


macro init_body b, x,y,z,vx,vy,vz,mass{
	mov rax,x
	mov rbx,y
	mov rcx,z
	mov rdx,[bodyindex]
	mov [b#.x],rax
	mov [bodyx+rdx*8],rax
	mov [b#.y],rbx
	mov [bodyy+rdx*8],rbx
	mov [b#.z],rcx
	mov [bodyz+rdx*8],rcx

	movsd xmm1,[DAYS_PER_YEAR]

	mov rax, vx
	movq xmm0,rax
	mulsd xmm0,xmm1
	movsd [b#.vx],xmm0
  movsd [bodyvx+rdx*8],xmm0
	mov rax,vy
	movq xmm0,rax
	mulsd xmm0,xmm1
	movsd [b#.vy],xmm0
  movsd [bodyvy+rdx*8],xmm0

	mov rax,vz
	movq xmm0,rax
	mulsd xmm0,xmm1
	movsd [b#.vz],xmm0
  movsd [bodyvz+rdx*8],xmm0

	mov rax,mass
	movq xmm0,rax
	mulsd xmm0,[SOLAR_MASS]
	movsd [b#.mass],xmm0
	movsd [bodymass+rdx*8],xmm0
	inc [bodyindex]
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

if 0
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
else
	mov ecx,3 ; ecx - > i
	mov rsi,rr
	mov rdi,0
	mov rbx,0
	lea rdx, [rbx + 8]

;  movapd xmm6,dqword[indexdiff]

	vbroadcastsd ymm0,[rbx + bodyx]
	vbroadcastsd ymm1,[rbx + bodyy]
	vbroadcastsd ymm2,[rbx + bodyz]

	vmovupd ymm3,yword[rdx + bodyx]
	vmovupd ymm4,yword[rdx + bodyy]
	vmovupd ymm5,yword[rdx + bodyz]

	vsubpd ymm0,ymm0, ymm3; dx -> xmm0
	vsubpd ymm1,ymm1, ymm4; dy -> xmm1
	vsubpd ymm2,ymm2, ymm5; dz -> xmm2
	if 0
	movsd [rsi+r.dx],xmm0
	movsd [rsi+r.dy],xmm1
	movsd [rsi+r.dz],xmm2
	else
;  scatterq rsi+r.dx,xmm6,1,xmm0
;  scatterq rsi+r.dy,xmm6,1,xmm1
;  scatterq rsi+r.dz,xmm6,1,xmm2
  end if
  vmovupd yword[rdi + diffx],ymm0
  vmovupd yword[rdi + diffy],ymm1
  vmovupd yword[rdi + diffz],ymm2
  add rbx,8
  add rsi,32
  add rdi,32
.L0:
	mov r9d, ecx ; r9 -> j
	lea rdx, [rbx + 8]
.L1:
  cmp r9d,1
  jz @f
	vmovddup xmm0,[rbx + bodyx]
	vmovddup xmm1,[rbx + bodyy]
	vmovddup xmm2,[rbx + bodyz]

	vmovupd xmm3,dqword[rdx + bodyx]
	vmovupd xmm4,dqword[rdx + bodyy]
	vmovupd xmm5,dqword[rdx + bodyz]

	vsubpd xmm0,xmm0, xmm3; dx -> xmm0
	vsubpd xmm1,xmm1, xmm4; dy -> xmm1
	vsubpd xmm2,xmm2, xmm5; dz -> xmm2
	if 0
	movsd [rsi+r.dx],xmm0
	movsd [rsi+r.dy],xmm1
	movsd [rsi+r.dz],xmm2
	else
;  scatterq rsi+r.dx,xmm6,1,xmm0
;  scatterq rsi+r.dy,xmm6,1,xmm1
;  scatterq rsi+r.dz,xmm6,1,xmm2
  end if
  vmovupd dqword[rdi + diffx],xmm0
  vmovupd dqword[rdi + diffy],xmm1
  vmovupd dqword[rdi + diffz],xmm2
	add rsi, 2*SIZEOFDIFF
	add rdi,16
	add rdx,16
	sub r9d,2
  jmp .dskip1

  @@:
	vmovsd xmm0,[rbx + bodyx]
	vmovsd xmm1,[rbx + bodyy]
	vmovsd xmm2,[rbx + bodyz]

	vmovsd xmm3,[rdx + bodyx]
	vmovsd xmm4,[rdx + bodyy]
	vmovsd xmm5,[rdx + bodyz]

	vsubsd xmm0,xmm0, xmm3; dx -> xmm0
	vsubsd xmm1,xmm1, xmm4; dy -> xmm1
	vsubsd xmm2,xmm2, xmm5; dz -> xmm2
	if 1
	;movsd [rsi+r.dx],xmm0
	;movsd [rsi+r.dy],xmm1
	;movsd [rsi+r.dz],xmm2
	else
  scatterq rsi+r.dx,xmm6,1,xmm0
  scatterq rsi+r.dy,xmm6,1,xmm1
  scatterq rsi+r.dz,xmm6,1,xmm2
  end if
  vmovsd [rdi + diffx],xmm0
  vmovsd [rdi + diffy],xmm1
  vmovsd [rdi + diffz],xmm2
	add rsi, SIZEOFDIFF
	add rdi,8
	add rdx,8
	dec r9d

.dskip1:
	jg .L1
	add rbx,8
	dec ecx
	jnz .L0
	vzeroupper
end if
;-----------------------------------
if 0
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
else
	mov ecx,3
	mov rsi,0
	mov rdi,mag
.L2:

	vmovupd ymm3,yword[rsi+diffx]
	vmovupd ymm4,yword[rsi+diffy]
	vmovupd ymm5,yword[rsi+diffz]

	vbroadcastsd ymm6,xmm15

	vmulpd ymm3,ymm3,ymm3
	;vmulpd ymm4,ymm4,ymm4
	;vmulpd ymm5,ymm5,ymm5

	;vaddpd ymm3,ymm3,ymm4
	;vaddpd ymm3,ymm3,ymm5 ; dsquared -> xmm3
  vfmadd231pd ymm3,ymm4,ymm4
  vfmadd231pd ymm3,ymm5,ymm5

  vsqrtpd ymm7,ymm3
  vmulpd ymm3,ymm3,ymm7
	vdivpd ymm6,ymm6,ymm3

	;--------------------------


	vmovupd yword[rdi],ymm6
	add rdi,32
	add rsi,32
	dec ecx
	jnz .L2
  vzeroupper
end if
;-----------------------------------------------
if 0
	mov ecx,4
	mov rbx,sun
    mov r11,0
	mov rsi,rr
	mov rdi,mag
.L3:
	mov r9d, ecx
	lea rdx, [rbx+SIZEOFBODY]
    lea r10, [r11+8]
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
    movlpd [r11+bodyvx],xmm3
    movhpd [r11+bodyvy],xmm3
    movsd [r11+bodyvz],xmm4
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
    movlpd [r10+bodyvx],xmm3
    movhpd [r10+bodyvy],xmm3
    movsd [r10+bodyvz],xmm4
;-----------------------------------------
	add rdx,SIZEOFBODY
	add rsi,SIZEOFDIFF
	add rdi,8
	dec r9d
	jnz .L4
	add rbx,SIZEOFBODY
    add r11,8
	dec ecx
	jnz .L3
else
	mov ecx,3
	mov rbx,sun
  mov r11,0
	mov rsi,0
	mov rdi,mag
	lea rdx, [rbx+SIZEOFBODY]
  lea r10, [r11+8]
	vmovupd ymm6, yword[r10 + bodymass]
	vmovupd ymm5, yword[rdi]
	vmulpd ymm6,ymm6, ymm5 ; precompute bodies[j].mass * mag

	vmovupd ymm10,yword[rsi+diffx]
	vmovupd ymm11,yword[rsi+diffy]
	vmovupd ymm12,yword[rsi+diffz]

	vmovsd xmm3, [r11 + bodyvx]
	vmovsd xmm4, [r11 + bodyvy]
	vmovsd xmm5, [r11 + bodyvz]

	vmovapd ymm7, ymm10
	vmovapd ymm8, ymm11
	vmovapd ymm9, ymm12
	vmulpd ymm7,ymm7, ymm6
	vmulpd ymm8,ymm8, ymm6
	vmulpd ymm9,ymm9, ymm6
	vhaddpd ymm7,ymm7,ymm7
	vhaddpd ymm8,ymm8,ymm8
	vhaddpd ymm9,ymm9,ymm9
	vextractf128 xmm0,ymm7,1
	vextractf128 xmm1,ymm8,1
	vextractf128 xmm2,ymm9,1
	vaddsd xmm7,xmm7,xmm0
	vaddsd xmm8,xmm8,xmm1
	vaddsd xmm9,xmm9,xmm2
	vsubsd xmm3,xmm3,xmm7
	vsubsd xmm4,xmm4,xmm8
	vsubsd xmm5,xmm5,xmm9

	;movsd [rbx + oBody.vx],xmm3
	;movsd [rbx + oBody.vy],xmm4
	;movsd [rbx + oBody.vz],xmm5
  vmovsd [r11+bodyvx],xmm3
  vmovsd [r11+bodyvy],xmm4
  vmovsd [r11+bodyvz],xmm5
	; iBody.vx -= dx * bodies[j].mass * mag;
; ----------------------------------------------
	vbroadcastsd ymm7, [r11 + bodymass]
	vmovupd ymm6, yword[rdi]
	vmulpd ymm7,ymm7,ymm6 ; precompute iBody.mass * mag

	vmovupd ymm3, yword[r10 + bodyvx]
	vmovupd ymm4, yword[r10 + bodyvy]
	vmovupd ymm5, yword[r10 + bodyvz]

	vmovapd ymm0, ymm10
	vmovapd ymm1, ymm11
	vmovapd ymm2, ymm12
	;vmulpd ymm0,ymm0, ymm7
	;vmulpd ymm1,ymm1, ymm7
	;vmulpd ymm2,ymm2, ymm7
	;vaddpd ymm3,ymm3, ymm0
	;vaddpd ymm4,ymm4, ymm1
	;vaddpd ymm5,ymm5, ymm2
	vfmadd231pd ymm3,ymm0,ymm7
	vfmadd231pd ymm4,ymm1,ymm7
	vfmadd231pd ymm5,ymm2,ymm7

	;movlpd [rdx + oBody.vx], xmm3
	;movlpd [rdx + oBody.vy], xmm4
	;movlpd [rdx + oBody.vz], xmm5
	;movhpd [rdx + oBody.vx + SIZEOFBODY], xmm3
	;movhpd [rdx + oBody.vy + SIZEOFBODY], xmm4
	;movhpd [rdx + oBody.vz + SIZEOFBODY], xmm5

  vmovupd yword[r10+bodyvx],ymm3
  vmovupd yword[r10+bodyvy],ymm4
  vmovupd yword[r10+bodyvz],ymm5
  ; bodies[j].vx += dx * iBody.mass * mag;
	add rdx,4*SIZEOFBODY
	add rsi,32
	add rdi,32
	add r10,32
	sub r9d,4
	add rbx,SIZEOFBODY
	add r11,8
.L3:
	mov r9d, ecx
	lea rdx, [rbx+SIZEOFBODY]
  lea r10, [r11+8]
.L4:
  cmp r9d,1
  jz @f
	vmovupd xmm6, dqword[r10 + bodymass]
	vmovupd xmm5, dqword[rdi]
	vmulpd xmm6,xmm6, xmm5 ; precompute bodies[j].mass * mag

	vmovupd xmm10,dqword[rsi+diffx]
	vmovupd xmm11,dqword[rsi+diffy]
	vmovupd xmm12,dqword[rsi+diffz]

	vmovsd xmm3, [r11 + bodyvx]
	vmovsd xmm4, [r11 + bodyvy]
	vmovsd xmm5, [r11 + bodyvz]

	vmovapd xmm7, xmm10
	vmovapd xmm8, xmm11
	vmovapd xmm9, xmm12
	vmulpd xmm7,xmm7, xmm6
	vmulpd xmm8,xmm8, xmm6
	vmulpd xmm9,xmm9, xmm6
	vhaddpd xmm7,xmm7,xmm7
	vhaddpd xmm8,xmm8,xmm8
	vhaddpd xmm9,xmm9,xmm9
	vsubsd xmm3,xmm3,xmm7
	vsubsd xmm4,xmm4,xmm8
	vsubsd xmm5,xmm5,xmm9
	;movsd [rbx + oBody.vx],xmm3
	;movsd [rbx + oBody.vy],xmm4
	;movsd [rbx + oBody.vz],xmm5
  vmovsd [r11+bodyvx],xmm3
  vmovsd [r11+bodyvy],xmm4
  vmovsd [r11+bodyvz],xmm5
	; iBody.vx -= dx * bodies[j].mass * mag;
; ----------------------------------------------
	vmovddup xmm7, [r11 + bodymass]
	vmovupd xmm6, dqword[rdi]
	vmulpd xmm7,xmm7,xmm6 ; precompute iBody.mass * mag

	vmovupd xmm3, dqword[r10 + bodyvx]
	vmovupd xmm4, dqword[r10 + bodyvy]
	vmovupd xmm5, dqword[r10 + bodyvz]

	vmovapd xmm0, xmm10
	vmovapd xmm1, xmm11
	vmovapd xmm2, xmm12
	;vmulpd xmm0,xmm0, xmm7
	;vmulpd xmm1,xmm1, xmm7
	;vmulpd xmm2,xmm2, xmm7
	;vaddpd xmm3,xmm3, xmm0
	;vaddpd xmm4,xmm4, xmm1
	;vaddpd xmm5,xmm5, xmm2
  vfmadd231pd xmm3,xmm0,xmm7
  vfmadd231pd xmm4,xmm1,xmm7
  vfmadd231pd xmm5,xmm2,xmm7
	;movlpd [rdx + oBody.vx], xmm3
	;movlpd [rdx + oBody.vy], xmm4
	;movlpd [rdx + oBody.vz], xmm5
	;movhpd [rdx + oBody.vx + SIZEOFBODY], xmm3
	;movhpd [rdx + oBody.vy + SIZEOFBODY], xmm4
	;movhpd [rdx + oBody.vz + SIZEOFBODY], xmm5

  vmovupd dqword[r10+bodyvx],xmm3
  vmovupd dqword[r10+bodyvy],xmm4
  vmovupd dqword[r10+bodyvz],xmm5
  ; bodies[j].vx += dx * iBody.mass * mag;
	add rdx,2*SIZEOFBODY
	add rsi,16
	add rdi,16
	add r10,16
	sub r9d,2
	jmp .mskip1
@@:
	vmovsd xmm6, [r10 + bodymass]
	vmovsd xmm5, [rdi]
	vmulsd xmm6,xmm6, xmm5 ; precompute bodies[j].mass * mag

	vmovsd xmm10,[rsi+diffx]
	vmovsd xmm11,[rsi+diffy]
	vmovsd xmm12,[rsi+diffz]

	vmovsd xmm3, [r11 + bodyvx]
	vmovsd xmm4, [r11 + bodyvy]
	vmovsd xmm5, [r11 + bodyvz]

	vmovsd xmm7,xmm7, xmm10
	vmovsd xmm8,xmm8, xmm11
	vmovsd xmm9,xmm9, xmm12
	;vmulsd xmm7,xmm7, xmm6
	;vmulsd xmm8,xmm8, xmm6
	;vmulsd xmm9,xmm9, xmm6
	;vsubsd xmm3,xmm3,xmm7
	;vsubsd xmm4,xmm4,xmm8
	;vsubsd xmm5,xmm5,xmm9
	vfnmadd231pd xmm3,xmm7,xmm6
	vfnmadd231pd xmm4,xmm8,xmm6
	vfnmadd231pd xmm5,xmm9,xmm6

	;movsd [rbx + oBody.vx],xmm3
	;movsd [rbx + oBody.vy],xmm4
	;movsd [rbx + oBody.vz],xmm5
  vmovsd [r11+bodyvx],xmm3
  vmovsd [r11+bodyvy],xmm4
  vmovsd [r11+bodyvz],xmm5
	; iBody.vx -= dx * bodies[j].mass * mag;
; ----------------------------------------------
	vmovsd xmm7, [r11 + bodymass]
	vmovsd xmm6, [rdi]
	vmulsd xmm7,xmm7,xmm6 ; precompute iBody.mass * mag

	vmovsd xmm3, [r10 + bodyvx]
	vmovsd xmm4, [r10 + bodyvy]
	vmovsd xmm5, [r10 + bodyvz]

	vmovsd xmm0,xmm0, xmm10
	vmovsd xmm1,xmm1, xmm11
	vmovsd xmm2,xmm2, xmm12
	;vmulsd xmm0,xmm0, xmm7
	;vmulsd xmm1,xmm1, xmm7
	;vmulsd xmm2,xmm2, xmm7
	;vaddsd xmm3,xmm3, xmm0
	;vaddsd xmm4,xmm4, xmm1
	;vaddsd xmm5,xmm5, xmm2i
	vfmadd231pd xmm3,xmm0,xmm7
	vfmadd231pd xmm4,xmm1,xmm7
	vfmadd231pd xmm5,xmm2,xmm7

	;movsd [rdx + oBody.vx], xmm3
	;movsd [rdx + oBody.vy], xmm4
	;movsd [rdx + oBody.vz], xmm5

  vmovsd [r10+bodyvx],xmm3
  vmovsd [r10+bodyvy],xmm4
  vmovsd [r10+bodyvz],xmm5
	; bodies[j].vx += dx * iBody.mass * mag;
	add rdx,SIZEOFBODY
	add rsi,8
	add rdi,8
	add r10,8
	dec r9d
;-----------------------------------------
.mskip1:
	jg .L4
	add rbx,SIZEOFBODY
  add r11,8
	dec ecx
	jnz .L3
end if

if 0
	mov rbx,sun
  mov r9,0
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
    movlpd [r9+bodyx],xmm0
    movhpd [r9+bodyy],xmm0
    movsd [r9+bodyz],xmm1

	add rbx,SIZEOFBODY
    add r9,8
	dec ecx
	jnz .L5
else
	mov rbx,sun
  mov r9,0
 ;mov ecx,5
 ;.L5:
 ; cmp ecx,1
 ; jnz @f
	vmovsd xmm0, [r9 + bodyx]
	vmovsd xmm1, [r9 + bodyy]
	vmovsd xmm2, [r9 + bodyz]

	vmovsd xmm3,xmm3, xmm15
	vmovapd xmm4,xmm3
  vmovapd xmm5,xmm3

  vmovsd xmm6, [r9 + bodyvx]
	vmovsd xmm7, [r9 + bodyvy]
	vmovsd xmm8, [r9 + bodyvz]

	;vmulsd xmm3,xmm3,xmm6
	;vmulsd xmm4,xmm4,xmm7
	;vmulsd xmm5,xmm5,xmm8
	;vaddsd xmm0,xmm0,xmm3
	;vaddsd xmm1,xmm1,xmm4
	;vaddsd xmm2,xmm2,xmm5
  vfmadd231pd xmm0,xmm3,xmm6
  vfmadd231pd xmm1,xmm4,xmm7
  vfmadd231pd xmm2,xmm5,xmm8

	;movsd [rbx + oBody.x], xmm0
	;movsd [rbx + oBody.y], xmm1
	;movsd [rbx + oBody.z], xmm2
  vmovsd [r9+bodyx],xmm0
  vmovsd [r9+bodyy],xmm1
  vmovsd [r9+bodyz],xmm2

	add rbx,SIZEOFBODY
  add r9,8
	dec ecx
	;jmp .kskip1
  ;@@:
	vmovupd ymm0, yword[r9 + bodyx]
	vmovupd ymm1, yword[r9 + bodyy]
	vmovupd ymm2, yword[r9 + bodyz]

	vbroadcastsd ymm3, xmm15
	vmovapd ymm4,ymm3
  vmovapd ymm5,ymm3

  vmovupd ymm6, yword[r9 + bodyvx]
	vmovupd ymm7, yword[r9 + bodyvy]
	vmovupd ymm8, yword[r9 + bodyvz]

	;vmulpd ymm3,ymm3,ymm6
	;vmulpd ymm4,ymm4,ymm7
	;vmulpd ymm5,ymm5,ymm8
	;vaddpd ymm0,ymm0,ymm3
	;vaddpd ymm1,ymm1,ymm4
	;vaddpd ymm2,ymm2,ymm5

	vfmadd231pd ymm0,ymm3,ymm6
	vfmadd231pd ymm1,ymm4,ymm7
	vfmadd231pd ymm2,ymm5,ymm8
	;movlpd [rbx + oBody.x], xmm0
	;movlpd [rbx + oBody.y], xmm1
	;movlpd [rbx + oBody.z], xmm2
	;movhpd [rbx + oBody.x + SIZEOFBODY], xmm0
	;movhpd [rbx + oBody.y + SIZEOFBODY], xmm1
	;movhpd [rbx + oBody.z + SIZEOFBODY], xmm2
  vmovupd yword[r9+bodyx],ymm0
  vmovupd yword[r9+bodyy],ymm1
  vmovupd yword[r9+bodyz],ymm2

	;add rbx,4*SIZEOFBODY
  ;add r9,32
  ;.kskip1:
	;jg .L5
	vzeroupper
end if
}

section '.text' executable align 16
extrn printf
extrn atoi
extrn exit
public main

main:
	mov qword[n],1
	; rdi - > argc , rsi -> argv
	cmp rdi,2
	jl .begin
	mov rdi,qword[rsi+8] ; argv[1] -> rdi
	call plt atoi
	mov qword[n],rax
  mov rdi,bodyx
  mov ecx,7*80
  mov al,0
  rep stosb
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
  mov [bodyindex],0
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
	mov [bodyindex],0
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
  mov rdx,[bodyindex]
	mov rax,0x8000000000000000
	movq xmm3, rax

	xorpd xmm0,xmm3
	xorpd xmm1,xmm3
	xorpd xmm2,xmm3
	divsd xmm0,[SOLAR_MASS]
	divsd xmm1,[SOLAR_MASS]
	divsd xmm2,[SOLAR_MASS]
	movsd [rdx*8+bodyvx],xmm0
	movsd [rdx*8+bodyvy],xmm1
	movsd [rdx*8+bodyvz],xmm2
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
	mov rbx, 0
	mov ecx, 5
	mov rax,0.0
	movq xmm0, rax
  movddup xmm0,xmm0
	mov rax,0.5
.L0:

	movsd xmm1, [rbx + bodyvx]
	mulsd xmm1,xmm1

	movsd xmm2, [rbx + bodyvy]
	mulsd xmm2,xmm2

	movsd xmm3, [rbx + bodyvz]
	mulsd xmm3,xmm3

	addsd xmm1, xmm2
	addsd xmm1, xmm3

	movsd xmm2, [rbx+bodymass]
	mulsd xmm1,xmm2

	movq xmm2, rax
	mulsd xmm2, xmm1

  movhlps xmm1,xmm0
	addsd xmm0,xmm2
	movlhps xmm0,xmm1
  dec ecx
  jz .L2

	push rcx
	lea rdx,[rbx+8]
.L1:
	movddup xmm1, [rbx + bodyx]
	movupd xmm2, dqword[rdx + bodyx]
	subpd xmm1, xmm2

	movddup xmm2, [rbx + bodyy]
	movupd xmm3, dqword[rdx + bodyy]
	subpd xmm2, xmm3

	movddup xmm3, [rbx + bodyz]
	movupd xmm4, dqword[rdx + bodyz]
	subpd xmm3, xmm4

	mulpd xmm1,xmm1
	mulpd xmm2,xmm2
	mulpd xmm3,xmm3

	addpd xmm1, xmm2
	addpd xmm1, xmm3
	sqrtpd xmm1,xmm1

	movddup xmm2, [rbx + bodymass]
	movupd xmm3, dqword[rdx + bodymass]
	mulpd xmm2, xmm3
	divpd xmm2, xmm1
  subpd xmm0, xmm2
	add rdx, 16
	sub ecx,2
	jg .L1
	add rbx, 8
	pop rcx
	jmp .L0
.L2:
  haddpd xmm0,xmm0
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
indexdiff dq 0,SIZEOFDIFF
mask dq 2 dup(-1)
section '.bss' writeable align 16
sun body
jupiter body
saturn body
uranus body
neptune body
align 16
bodyx rq 64
bodyy rq 64
bodyz rq 64
bodyvx rq 64
bodyvy rq 64
bodyvz rq 64
bodymass rq 64
bodyindex rq 1
diffx rq 64
diffy rq 64
diffz rq 64
n rq 1
align 16
mag rq 64
rr rq 64
