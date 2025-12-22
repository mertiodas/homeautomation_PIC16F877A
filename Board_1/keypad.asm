; ======================================================
; MODULE: keypad.asm 
; AUTHOR: HILAL 
; 4x4 Matrix Keypad - Temperature Input
; PORTB: RB0-RB3 (Columns Input), RB4-RB7 (Rows Output)
; User enters Desired Temperature (XX.X format)
; ======================================================

; --- Local RAM (BANK2) ---
        PSECT udata_bank2

Keypad_State:           DS 1
Keypad_Digit_Count:     DS 1
Temp_Tens:              DS 1
Temp_Ones:              DS 1
Temp_Decimal:           DS 1
Last_Key:               DS 1
Key_Released:           DS 1
Temp_Multiply:          DS 1    

; --- Code Section ---
        PSECT keypad_code, class=CODE, delta=2


; --------------------------------------------------
; INIT_Keypad
; --------------------------------------------------
INIT_Keypad:
        BANKSEL TRISB
        movlw   0x0F
        movwf   TRISB
        
        BANKSEL OPTION_REG
        bcf     OPTION_REG, 7
        
        BANKSEL Keypad_State
        clrf    Keypad_State
        clrf    Keypad_Digit_Count
        clrf    Temp_Tens
        clrf    Temp_Ones
        clrf    Temp_Decimal
        clrf    Last_Key
        movlw   1
        movwf   Key_Released
        
        BANKSEL DesiredTemp_INT
        movlw   20
        movwf   DesiredTemp_INT
        clrf    DesiredTemp_FRAC
        
        return


; --------------------------------------------------
; Keypad_Interrupt_Handler
; --------------------------------------------------
Keypad_Interrupt_Handler:
        BANKSEL PORTB
        movf    PORTB, W
        
        andlw   0x0F
        xorlw   0x0F
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_Was_Released
        
        BANKSEL Key_Released
        movf    Key_Released, W
        btfss   STATUS, STATUS_Z_POSITION
        call    Scan_Keypad
        
        clrf    Key_Released
        return

Key_Was_Released:
        BANKSEL Key_Released
        movlw   1
        movwf   Key_Released
        return


; --------------------------------------------------
; Scan_Keypad
; --------------------------------------------------
Scan_Keypad:
        BANKSEL PORTB
        
        ; Row 1
        movlw   0xE0
        movwf   PORTB
        nop
        nop
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0E
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_1
        
        BANKSEL PORTB
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0D
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_2
        
        BANKSEL PORTB
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0B
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_3
        
        ; Row 2
        BANKSEL PORTB
        movlw   0xD0
        movwf   PORTB
        nop
        nop
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0E
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_4
        
        BANKSEL PORTB
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0D
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_5
        
        BANKSEL PORTB
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0B
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_6
        
        ; Row 3
        BANKSEL PORTB
        movlw   0xB0
        movwf   PORTB
        nop
        nop
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0E
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_7
        
        BANKSEL PORTB
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0D
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_8
        
        BANKSEL PORTB
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0B
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_9
        
        ; Row 4
        BANKSEL PORTB
        movlw   0x70
        movwf   PORTB
        nop
        nop
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0E
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_Star
        
        BANKSEL PORTB
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0D
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_0
        
        BANKSEL PORTB
        movf    PORTB, W
        andlw   0x0F
        xorlw   0x0B
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_Hash
        
        BANKSEL PORTB
        movlw   0xF0
        movwf   PORTB
        return


; --------------------------------------------------
; KEY HANDLERS
; --------------------------------------------------
Key_0:
        movlw   0
        goto    Process_Digit

Key_1:
        movlw   1
        goto    Process_Digit

Key_2:
        movlw   2
        goto    Process_Digit

Key_3:
        movlw   3
        goto    Process_Digit

Key_4:
        movlw   4
        goto    Process_Digit

Key_5:
        movlw   5
        goto    Process_Digit

Key_6:
        movlw   6
        goto    Process_Digit

Key_7:
        movlw   7
        goto    Process_Digit

Key_8:
        movlw   8
        goto    Process_Digit

Key_9:
        movlw   9
        goto    Process_Digit


; --------------------------------------------------
; Process_Digit (FIXED)
; --------------------------------------------------
Process_Digit:
        BANKSEL Last_Key
        movwf   Last_Key
        
        BANKSEL Keypad_Digit_Count
        movf    Keypad_Digit_Count, W
        xorlw   0
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Enter_Tens
        
        BANKSEL Keypad_Digit_Count
        movf    Keypad_Digit_Count, W
        xorlw   1
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Enter_Ones
        
        BANKSEL Keypad_Digit_Count
        movf    Keypad_Digit_Count, W
        xorlw   2
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Enter_Decimal
        
        goto    Process_Digit_Done

Enter_Tens:
        BANKSEL Last_Key
        movf    Last_Key, W
        BANKSEL Temp_Tens
        movwf   Temp_Tens
        
        ; Check if 0 (invalid)
        movf    Temp_Tens, W
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Invalid_Input
        
        ; Check if > 5 (invalid)
        movlw   6
        BANKSEL Temp_Tens
        subwf   Temp_Tens, W
        btfss   STATUS, STATUS_C_POSITION
        goto    Tens_Valid
        goto    Invalid_Input

Tens_Valid:
        BANKSEL Keypad_Digit_Count
        incf    Keypad_Digit_Count, F
        goto    Process_Digit_Done

Enter_Ones:
        BANKSEL Last_Key
        movf    Last_Key, W
        BANKSEL Temp_Ones
        movwf   Temp_Ones
        BANKSEL Keypad_Digit_Count
        incf    Keypad_Digit_Count, F
        goto    Process_Digit_Done

Enter_Decimal:
        BANKSEL Last_Key
        movf    Last_Key, W
        BANKSEL Temp_Decimal
        movwf   Temp_Decimal
        BANKSEL Keypad_Digit_Count
        incf    Keypad_Digit_Count, F
        goto    Process_Digit_Done

Invalid_Input:
        BANKSEL Keypad_Digit_Count
        clrf    Keypad_Digit_Count
        BANKSEL Temp_Tens
        clrf    Temp_Tens
        clrf    Temp_Ones
        clrf    Temp_Decimal

Process_Digit_Done:
        BANKSEL PORTB
        movlw   0xF0
        movwf   PORTB
        return


; --------------------------------------------------
; Key_Star - Clear
; --------------------------------------------------
Key_Star:
        BANKSEL Keypad_Digit_Count
        clrf    Keypad_Digit_Count
        BANKSEL Temp_Tens
        clrf    Temp_Tens
        clrf    Temp_Ones
        clrf    Temp_Decimal
        
        BANKSEL PORTB
        movlw   0xF0
        movwf   PORTB
        return


; --------------------------------------------------
; Key_Hash - Confirm (FIXED)
; --------------------------------------------------
Key_Hash:
        BANKSEL Keypad_Digit_Count
        movf    Keypad_Digit_Count, W
        sublw   1
        btfsc   STATUS, STATUS_C_POSITION
        goto    Hash_Ignore
        
        ; Calculate INT = (Tens × 10) + Ones
        BANKSEL Temp_Tens
        movf    Temp_Tens, W
        BANKSEL DesiredTemp_INT
        movwf   DesiredTemp_INT
        
        ; FIX: Use Temp_Multiply instead of overwriting Temp_Ones
        ; Multiply by 10: (x<<3) + (x<<1)
        bcf     STATUS, STATUS_C_POSITION
        rlf     DesiredTemp_INT, F      ; ×2
        BANKSEL Temp_Multiply
        movf    DesiredTemp_INT, W
        movwf   Temp_Multiply           ; Save ×2
        
        BANKSEL DesiredTemp_INT
        rlf     DesiredTemp_INT, F      ; ×4
        rlf     DesiredTemp_INT, F      ; ×8
        
        BANKSEL Temp_Multiply
        movf    Temp_Multiply, W
        BANKSEL DesiredTemp_INT
        addwf   DesiredTemp_INT, F      ; ×8 + ×2 = ×10
        
        ; Add ones digit
        BANKSEL Temp_Ones
        movf    Temp_Ones, W
        BANKSEL DesiredTemp_INT
        addwf   DesiredTemp_INT, F
        
        ; FIX: Validate range 10-50
        ; Check lower bound (< 10)
        movf    DesiredTemp_INT, W
        sublw   10                      ; 10 - W
        btfss   STATUS, STATUS_C_POSITION
        goto    Check_Upper             ; W >= 10, OK
        goto    Hash_Invalid            ; W < 10

Check_Upper:
        ; Check upper bound (> 50)
        BANKSEL DesiredTemp_INT
        movf    DesiredTemp_INT, W
        sublw   50                      ; 50 - W
        btfss   STATUS, STATUS_C_POSITION
        goto    Hash_Invalid            ; W > 50
        
        ; Valid! Save decimal
        BANKSEL Temp_Decimal
        movf    Temp_Decimal, W
        BANKSEL DesiredTemp_FRAC
        movwf   DesiredTemp_FRAC
        goto    Hash_Reset

Hash_Invalid:
        ; Reset to 20.0°C
        BANKSEL DesiredTemp_INT
        movlw   20
        movwf   DesiredTemp_INT
        clrf    DesiredTemp_FRAC

Hash_Reset:
        BANKSEL Keypad_Digit_Count
        clrf    Keypad_Digit_Count
        BANKSEL Temp_Tens
        clrf    Temp_Tens
        clrf    Temp_Ones
        clrf    Temp_Decimal

Hash_Ignore:
        BANKSEL PORTB
        movlw   0xF0
        movwf   PORTB
        return
