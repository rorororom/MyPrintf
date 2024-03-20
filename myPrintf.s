DEFAULT REL                             ; устанавливаем относительное адресование
                                        ; относительное адресование - адреса данных рассчитываются
                                        ; относительно значения регистра индекса
section .text
    global _MyPrintf                    ; делаем метку _MyPrintf доступной извне текущего модуля
                                        ; и говорим компилятору, что _MyPrintf является глобальной меткой,
                                        ; которую можно использовать для обращения к функции
                                        ; или символу в других модулях программы

; ====================================================================================================
;                          _MyPrintf
; ====================================================================================================
; Основная функция вывода форматированной строки.
;
; Вход:
;        - Аргументы передаются через стек (кроме первых 6, они в rdi, rsi, rdx, rcx, r8, r9)
; Выход:
;        - Выводит отформатированную строку на стандартный вывод
;        - Возвращает управление в вызывающую функцию
; Изменения:
;        - Изменяет регистры rax, rdi, rsi, rcx, rdx, r8, r9, rbx, rbp
;        - Записывает результат в буфер и на стандартный вывод
;-----------------------------------------------------------------------------------------------------
_MyPrintf:
    pop rax                             ; cохраняем адрес возврата в rax и
    mov [rel ret_adress], rax           ; копируем его в переменную ret_adress

    push r9                             ; сохраняем регистры
    push r8
    push rcx
    push rdx
    push rsi
    push rdi

    call PrintFFF

    pop rdi                             ; восстанавливаем регистры
    pop rsi
    pop rdx
    pop rcx
    pop r8
    pop r9

    push rax
    mov rax, 0x2000004
    mov rdi, 1
    mov rdx, msg_len
    mov rsi, buffer
    syscall

    mov rdi, buffer                     ; загружаем адрес буфера в rdi
    mov rcx, 512                        ; загружаем размер буфера в rcx
    xor al, al                          ; oбнуляем al
    rep stosb                           ; заполняем буфер нулями

    pop rax                             ; rax = len
    push qword [rel ret_adress]         ; Восстанавливаем адрес возврата
    ret

; ====================================================================================================
;                          PrintFFF
; ====================================================================================================
; Функция преобразования форматной строки.
;
; Вход:
;        - Адрес строки формата передается через стек
; Выход:
;        - rax сохраняется длину преобразования форматной строки
; Побочные эффекты:
;        - Изменяет регистры rdi, rbx, rax, r8, r9 (в последствие в других фукнциях меняются
;                                                   вообще все регистры)
;-----------------------------------------------------------------------------------------------------
PrintFFF:
    mov rdi, qword [rsp + 8]            ; берем адрес rdi
    push rbp                            ; cохраняем адрес текущего базового указателя

    lea rbx, [rel buffer]               ; загружаем адрес буфера в rbx
                                        ; r9 - счетчик форматной строки
    mov r9, 16                          ; пропускаем в стеке адрес возврата и адрес текущего базового указателя
                                        ; в программе при взятии какого-то значения из стека
                                        ; r9 всегда сначала увеличивается на 8

    xor r8, r8                          ; r8 - счетчик для буфера

    PrintFLoop:
        xor rax, rax
        mov al, byte [rdi]              ; загружаем текущий символ из строки
        cmp al, string_end              ; сравниваем с символом конца строки
        je PrintExit                    ; если это конец строки, завершаем цикл

        cmp al, '%'                     ; if (symbol == '%') ---> jmp InputType
        je InputType

        mov byte [rbx + r8], al         ; копируем символ в буфер
        inc r8

        inc rdi                         ; переходим к следующему символу
        jmp PrintFLoop                  ; переходим к следующей итерации цикла

    PrintExit:
        pop rbp                         ; восстанавливаем базовый указатель

        mov rax, r8                     ; rax -  регистр, в который кладется возвращаемое значение из функции
        ret                             ; возвращает управление из текущей функции обратно в вызывающую ее функцию

; ====================================================================================================
;                          InputType
; ====================================================================================================
; Обработчик разных типов %?.
;
; Вход:
;        - Символ '%' (в rax)
; Выход:
;        - Переход к обработке соответствующего типа данных
; Побочные эффекты:
;        - Изменяет регистры rdi, rax, rdx
;-----------------------------------------------------------------------------------------------------
InputType:
    inc rdi                             ; увеличиваем адрес строки на 1 байт,
                                        ; тем самым сдвигаемся на следующий символ
    xor rax, rax                        ; rax = 0
    mov al, byte [rdi]                  ; al = символ

    cmp al, '%'                         ; if (symbol == '%') ---> jmp TypeSymbolProcent
    je TypeSymbolProcent

    sub rax, 'b'                        ; rax = rax - 'b'

    ; загрузить адрес таблицы в регистр rdx.
    lea rdx, [JmpTable]                 ; ъ
    imul rax, rax, 8                    ;  |
                                        ;  |  ---> rdx = [JmpTable + 8 * (symbol - 'b')]
    add rdx, rax                        ;  |
    jmp [rdx]                           ; /

; ====================================================================================================
;                         TypeSymbolProcent
; ====================================================================================================
; Запись символа '%' в буффер и переход к следующей итерации цикла
;
; Вход:
;        - rax - символ '%'
; Выход:
;        - Переход к обработке соответствующего типа данных
; Побочные эффекты:
;        - Изменяет регистры rdi, r8
;-----------------------------------------------------------------------------------------------------
TypeSymbolProcent:
    mov byte [rbx + r8], al             ; копируем символ в буфер
    inc r8                              ; увеличиваем указатель на буфер
    inc rdi                             ; переходим к следующему символу в форматной строке
    jmp PrintFLoop                      ; переходим к следующей итерации цикла

; ====================================================================================================
;                         TypeString
; ====================================================================================================
; Запись строки из аргумента в буфер и переход к следующей итерации цикла
;
; Вход:
;        -
; Выход:
;        - Переход к обработке соответствующего типа данных
; Побочные эффекты:
;        - Изменяет регистры rdi, rsi, r8, r9
;-----------------------------------------------------------------------------------------------------
TypeString:
    add r9, 8
    mov rsi, qword [rsp + r9]           ; получаем адрес строки из аргументов

    PrintFLoopS:
        mov al, byte [rsi]
        cmp al, string_end              ; сравниваем с символом конца строки
        je AfterStringLoop

        mov byte [rbx + r8], al

        inc r8
        inc rsi

        jmp PrintFLoopS

AfterStringLoop:
    inc rdi
    jmp PrintFLoop


; ====================================================================================================
;                         TypeInt
; ====================================================================================================
; Преобразование числа и запись его в буфер, переход к следующей итерации цикла
;
; Вход:
;        -
; Выход:
;        - Переход к обработке соответствующего типа данных
; Побочные эффекты:
;        - Изменяет регистры rdi, rsi, rax, rdx, rcx, r8, r9
;-----------------------------------------------------------------------------------------------------
TypeInt:
    push r9
    add r9, 16
    mov rax, qword [rsp + r9]  ; Получаем адрес строки из аргументов

itoa:
    xor rdx, rdx          ; Обнуляем rdx для деления
    xor rcx, rcx          ; Обнуляем rdi для счетчика
    mov r9, 10           ; Сохраняем основание системы счисления
    cmp rax, 0
    jne check_negative  ; Если число не ноль, проверяем на отрицательность
    mov byte [rbx + r8], '0' ; Если число ноль, записываем символ '0' в буфер
    inc r8              ; Увеличиваем счетчик
    jmp AfterItoaLoop   ; Завершаем функцию

check_negative:
    test rax, 80000000h    ; Проверяем знак числа
    jz itoa_loop                  ; Если число положительное, начинаем преобразование

    ; Если число отрицательное, переходим к метке number_is_negative

number_is_negative:
    ; Обработка отрицательных чисел
    neg eax                         ; Изменяем знак числа на положительный
    mov byte [rbx + r8], '-'        ; Записываем минус перед числом
    inc r8                          ; Увеличиваем счетчик

itoa_loop:
    test rax, rax         ; Проверяем, не закончилось ли число
    jz BuffNumLoop        ; Если число равно нулю, завершаем

    inc rcx               ; Увеличиваем счетчик разрядов
    xor rdx, rdx          ; Обнуляем rdx для деления
    div r9                ; Делим число на основание системы счисления (mod в rdx, res в rax)
    push rdx              ; Сохраняем остаток на стеке
    jmp itoa_loop         ; Повторяем цикл

BuffNumLoop:
    pop rax              ; Извлекаем сохраненные остатки из стека
    add al, '0'
    mov byte [rbx + r8], al             ; Копируем символ в буфер
    inc r8
    dec rcx              ; Уменьшаем счетчик
    jnz BuffNumLoop      ; Повторяем, пока не завершим все разряды

AfterItoaLoop:
    pop r9
    add r9, 8
    inc rdi
    jmp PrintFLoop  ; Завершаем цикл

; ====================================================================================================
; Как происходит деление:
;       DIV R9 ----> RDX:RAX \ r9
;                       ^
;                       |
;                       |
;       (64-битный регистр засчет конкатенации)

;                    RDX:RAX \ r9
;                     ^   ^
;                    /    |
;                   /     |
;                  /      |
;                 /       |
;              остаток  частное
; ====================================================================================================

; ====================================================================================================
;                         TypeHex
; ====================================================================================================
; Преобразование числа в 16 вид, переход к функции записи числа в буфер,
; переход к следующей итерации цикла
;
; Вход:
;        -
; Выход:
;        - Переход к обработке соответствующего типа данных
; Побочные эффекты:
;        - Изменяет регистры rdi, rsi, rax, rdx, rcx, r8, r9
;-----------------------------------------------------------------------------------------------------
TypeHex:
    add r9, 8
    mov eax, [rsp + r9]

itoa_hex:
    xor rcx, rcx                        ; rcx - счетчик(разрядов)

    push rdi
    mov rcx, 4
    mov rdi, 0xF

    call HandleNumberCondition

    pop rdi
    jmp AfterLoop

; ====================================================================================================
;                         TypeOct
; ====================================================================================================
; Преобразование числа в 8 вид, переход к функции записи числа в буфер,
; переход к следующей итерации цикла
;
; Вход:
;        -
; Выход:
;        - Переход к обработке соответствующего типа данных
; Побочные эффекты:
;        - Изменяет регистры rdi, rsi, rax, rdx, rcx, r8, r9
;-----------------------------------------------------------------------------------------------------
TypeOct:
    add r9, 8
    mov eax, [rsp + r9]

itoa_oct:
    xor rcx, rcx

    push rdi
    mov rcx, 3
    mov rdi, 7

    call HandleNumberCondition

    pop rdi
    jmp AfterLoop

; ====================================================================================================
;                         TypeBinary
; ====================================================================================================
; Преобразование числа в 2 вид, переход к функции записи числа в буфер,
; переход к следующей итерации цикла
;
; Вход:
;        -
; Выход:
;        - Переход к обработке соответствующего типа данных
; Побочные эффекты:
;        - Изменяет регистры rdi, rsi, rax, rdx, rcx, r8, r9
;-----------------------------------------------------------------------------------------------------
TypeBinary:
    add r9, 8
    mov eax, [rsp + r9]           ; получаем адрес строки из аргументов

itoa_binary:
    xor rdx, rdx
    xor rcx, rcx

    push rdi
    mov rcx, 1
    mov rdi, 1

    call HandleNumberCondition

    pop rdi
    jmp AfterLoop

; ====================================================================================================
;                         AfterLoop
; ====================================================================================================
; Метка - переход к следующей итерации цикла
;-----------------------------------------------------------------------------------------------------
AfterLoop:
    inc rdi
    jmp PrintFLoop

; ====================================================================================================
;                         TypeChar
; ====================================================================================================
; Запись символа в буфер, переход к следующей итериции цикла
;
; Вход:
;        -
; Выход:
;        - Переход к обработке соответствующего типа данных
; Побочные эффекты:
;        - Изменяет регистры rsi, rax, r8, r9
;-----------------------------------------------------------------------------------------------------
TypeChar:
    add r9, 8
    mov rax, qword [rsp + r9]

    mov byte [rbx + r8], al             ; копируем символ в буфер

    inc r8
    inc rsi

    jmp AfterLoop

; ====================================================================================================
;                         ConvertToBuffer
; ====================================================================================================
; Запись числа в буфер. Остатки достаются из стека, преобразовываются в цифры (символы) и записываются
; в буфер
;
; Вход:
;        -
; Выход:
;        - Переход к обработке соответствующего типа данных
; Побочные эффекты:
;        - Изменяет регистры rdi, rsi, rax, rdx, rcx, r8, r9
;-----------------------------------------------------------------------------------------------------
ConvertToBuffer:
    pop rbp
    dec r12
    BuffLoop:
        lea r13, [remainders_number]
        movzx rdx, byte [r13 + r12]         ; берем остаток
        mov [rel save_rsi], rsi
        movzx rax, dl                       ; помещаем остаток в rax
        mov rsi, alphabet                   ; rsi = адрес строки alphabet
        add rsi, rax                        ; смщение по строке alphabet
        mov al, [rsi]                       ; al = символ цифры

        mov byte [rbx + r8], al             ; копируем символ в буфер
        inc r8
        dec rcx
        dec r12
        jnz BuffLoop                        ; повторяем, пока не завершим все разряды
    push rbp
    mov rsi, qword [rel save_rsi]
    ret

; ====================================================================================================
;                          ConvertNumber
; ====================================================================================================
; Преобразование числа в определенную систему счисления
; Вход:
;        - rax - число для преобразования
;        - rcx - количество сдвига (степень двойки делителя)
;        - rdi - (делитель - 1)
; Выход:
;        - остатки в стеке
; Побочные эффекты:
;        - Изменяет регистры rbp, rdx, rdi, rcx
;-----------------------------------------------------------------------------------------------------
ConvertNumber:
    pop rbp
    mov [rel ret_a], rbp                ; сохраняем адрес возврата

    xor rbp, rbp
    xor r12, r12

convert_loop:
    test rax, rax                       ; проверяем, не закончилось ли число
    jz end_convert_loop                 ; если число равно нулю, завершаем

    inc rbp                             ; увеличиваем счетчик разрядов
    mov rdx, rax                        ; сохраняем число в rdx для деления
    and rdx, rdi                        ; получаем остаток от деления на основание системы счисления
    lea r13, [remainders_number]
    mov byte [r13 + r12], dl            ; сохраняем остаток в массив
    sar rax, cl                         ; делим число на основание системы счисления (сдвиг вправо на cl бит)
    inc r12

    jmp convert_loop

end_convert_loop:
    mov rcx, rbp
    push qword [rel ret_a]
    ret

; ====================================================================================================
;                          HandleNumberCondition
; ====================================================================================================
; Проверка числа на ноль и переход к дальнейшому его преобразованию
; Вход:
;        - rax - число
; Выход:
;        -
; Побочные эффекты:
;        - Изменяет регистры rbp, rcx
;-----------------------------------------------------------------------------------------------------
HandleNumberCondition:
    pop rbp
    mov [rel ret_a2], rbp

    cmp rax, 0                          ; проверяем, не равно ли число нулю
    jnz NotZero                         ; если число не равно нулю, прыгаем
    mov byte [rbx + r8], '0'                  ; записываем символ в буфер
    inc r8
    push qword [rel ret_a2]
    ret

NotZero:
    call ConvertNumber                  ; преобразуем число в правильную систему овнования
    call ConvertToBuffer                ; запись числа из стека в буффер
    push qword [rel ret_a2]
    ret

; ====================================================================================================
;                          JmpTable
; ====================================================================================================
align 8
JmpTable:
    dq TypeBinary
    dq TypeChar
    dq TypeInt
    times 10 dq 'd'                        ; times -> используется для повторения определенного блока кода
    dq TypeOct
    times 3 dq 'e'
    dq TypeString
    times 4 dq 'd'
    dq TypeHex

; ====================================================================================================
;                         DATA
; ====================================================================================================
section .data
    string_end equ 0x00
    ret_adress dq 0
    ret_a dq 0
    ret_a2 dq 0
    save_rsi dq 0
    buffer times 512 db 0
    msg_len equ $ - buffer
    alphabet db "0123456789ABCDEF"
    remainders_number db 0
