format  ELF64
public print_str

        SYSCALL_EXIT    equ 1     ; syscall to function exit()
        SYSCALL_WRITE   equ 4     ; syscall to function write()
        STDOUT          equ 1     ; file descriptor of standard output
        ESC             equ 0x1b  ; escape character

print_str:
; first clear the screen
        mov     eax, SYSCALL_WRITE
        mov     ebx, STDOUT
        mov     ecx, clear_screen
        mov     edx, clear_screen_size
        int     0x80
; move cursor to (x:25, y:12)
        mov     eax, SYSCALL_WRITE
        mov     ebx, STDOUT
        mov     ecx, move_cursor
        mov     edx, move_cursor_size
        int     0x80
; write the message
        mov     eax, SYSCALL_WRITE
        mov     ebx, STDOUT
        mov     ecx, message
        mov     edx, message_size
        int     0x80
; exit from the program
        mov     eax, SYSCALL_EXIT
        xor     ebx, ebx
        int     0x80

clear_screen: db ESC, "[2J"
clear_screen_size = $ - clear_screen
move_cursor:  db ESC, "[12;25H"
move_cursor_size = $ - move_cursor
message:      db ESC, "[31m", ESC, "[5m", ESC, "[4m" ; red, blink on, underline on
              db "Programming linux is easy", 0xa
              db ESC, "[25m", ESC, "[24m" ; blink off, underline off
message_size = $ - message
