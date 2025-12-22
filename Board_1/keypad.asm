; ======================================================
; MODULE: keypad.asm (FINAL VERSION)
; AUTHOR: HILAL
; 4x4 Matrix Keypad - Temperature Input
; PORTB: RB0-RB3 (Columns Input), RB4-RB7 (Rows Output)
; User enters Desired Temperature (XX.X format)
; Compatible with display.asm format
; ======================================================

; --- Local RAM (BANK2) - Matching display.asm format ---
        PSECT udata_bank2

Keypad_State:           DS 1
Keypad_Digit_Count:     DS 1
Temp_Tens:              DS 1
Temp_Ones:              DS 1
Temp_Decimal:           DS 1
Last_Key:               DS 1
Key_Released:           DS 1
Temp_Multiply:          DS 1    ; For multiply operation

; --- Code Section ---
        PSECT keypad_code, class=CODE, delta=2


; --------------------------------------------------
; INIT_Keypad
; Initialize keypad pins and variables
; --------------------------------------------------
INIT_Keypad:
        ; PORTB setup: RB0-RB3 input (columns), RB4-RB7 output (rows)
        BANKSEL TRISB
        movlw   0x0F
        movwf   TRISB
        
        ; Enable PORTB pull-ups
        BANKSEL OPTION_REG
        bcf     OPTION_REG, 7
        
        ; Initialize variables
        BANKSEL Keypad_State
        clrf    Keypad_State
        clrf    Keypad_Digit_Count
        clrf    Temp_Tens
        clrf    Temp_Ones
        clrf    Temp_Decimal
        clrf    Last_Key
        movlw   1
        movwf   Key_Released
        
        ; Set initial DesiredTemp to 20.0°C
        BANKSEL DesiredTemp_INT
        movlw   20
        movwf   DesiredTemp_INT
        clrf    DesiredTemp_FRAC
        
        return


; --------------------------------------------------
; Keypad_Interrupt_Handler
; Called from ISR when RBIF is set
; --------------------------------------------------
Keypad_Interrupt_Handler:
        ; Read PORTB to clear mismatch
        BANKSEL PORTB
        movf    PORTB, W
        
        ; Check if all keys released (all columns high)
        andlw   0x0F
        xorlw   0x0F
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Key_Was_Released
        
        ; Key pressed - check if it was already pressed
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
; Scan matrix to find which key is pressed
; --------------------------------------------------
Scan_Keypad:
        ; Row 1 (RB4 = 0): Keys 1, 2, 3
        BANKSEL PORTB
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
        
        ; Row 2 (RB5 = 0): Keys 4, 5, 6
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
        
        ; Row 3 (RB6 = 0): Keys 7, 8, 9
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
        
        ; Row 4 (RB7 = 0): Keys *, 0, #
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
        
        ; Restore PORTB
        BANKSEL PORTB
        movlw   0xF0
        movwf   PORTB
        return


; --------------------------------------------------
; KEY HANDLERS - Process key presses
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
; Process_Digit
; Input: W contains digit (0-9)
; Builds temperature in format XX.X
; Valid range: 10.0 to 50.0 °C
; --------------------------------------------------
Process_Digit:
        ; Save digit
        BANKSEL Last_Key
        movwf   Last_Key
        
        ; Check which digit position we're at
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
        
        ; Already entered 3 digits - ignore
        goto    Process_Digit_Done

Enter_Tens:
        ; First digit (tens) - must be 1-5
        BANKSEL Last_Key
        movf    Last_Key, W
        BANKSEL Temp_Tens
        movwf   Temp_Tens
        
        ; Check if 0 (invalid)
        movf    Temp_Tens, W
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Invalid_Input
        
        ; Check if > 5 (invalid for 10-50 range)
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
        ; Second digit (ones)
        BANKSEL Last_Key
        movf    Last_Key, W
        BANKSEL Temp_Ones
        movwf   Temp_Ones
        BANKSEL Keypad_Digit_Count
        incf    Keypad_Digit_Count, F
        goto    Process_Digit_Done

Enter_Decimal:
        ; Third digit (decimal)
        BANKSEL Last_Key
        movf    Last_Key, W
        BANKSEL Temp_Decimal
        movwf   Temp_Decimal
        BANKSEL Keypad_Digit_Count
        incf    Keypad_Digit_Count, F
        goto    Process_Digit_Done

Invalid_Input:
        ; Clear and start over
        BANKSEL Keypad_Digit_Count
        clrf    Keypad_Digit_Count
        BANKSEL Temp_Tens
        clrf    Temp_Tens
        clrf    Temp_Ones
        clrf    Temp_Decimal

Process_Digit_Done:
        ; Restore PORTB
        BANKSEL PORTB
        movlw   0xF0
        movwf   PORTB
        return


; --------------------------------------------------
; Key_Star - Clear input
; --------------------------------------------------
Key_Star:
        BANKSEL Keypad_Digit_Count
        clrf    Keypad_Digit_Count
        BANKSEL Temp_Tens
        clrf    Temp_Tens
        clrf    Temp_Ones
        clrf    Temp_Decimal
        
        ; Restore PORTB
        BANKSEL PORTB
        movlw   0xF0
        movwf   PORTB
        return


; --------------------------------------------------
; Key_Hash - Confirm and save temperature
; Format: XX.X (10.0 to 50.0 °C)
; --------------------------------------------------
Key_Hash:
        BANKSEL Keypad_Digit_Count
        
        ; Check if at least 2 digits entered
        movf    Keypad_Digit_Count, W
        sublw   1
        btfsc   STATUS, STATUS_C_POSITION
        goto    Hash_Ignore
        
        ; Calculate INT = (Tens × 10) + Ones
        BANKSEL Temp_Tens
        movf    Temp_Tens, W
        BANKSEL DesiredTemp_INT
        movwf   DesiredTemp_INT
        
        ; Multiply by 10 using shifts: (x<<3) + (x<<1)
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
        
        ; Validate range: 10 <= temp <= 50
        ; Check lower bound (temp < 10)
        movf    DesiredTemp_INT, W
        sublw   10                      ; 10 - W
        btfss   STATUS, STATUS_C_POSITION
        goto    Check_Upper             ; W >= 10, check upper
        goto    Hash_Invalid            ; W < 10

Check_Upper:
        ; Check upper bound (temp > 50)
        BANKSEL DesiredTemp_INT
        movf    DesiredTemp_INT, W
        sublw   50                      ; 50 - W
        btfss   STATUS, STATUS_C_POSITION
        goto    Hash_Invalid            ; W > 50
        
        ; Valid temperature! Save decimal part
        BANKSEL Temp_Decimal
        movf    Temp_Decimal, W
        BANKSEL DesiredTemp_FRAC
        movwf   DesiredTemp_FRAC
        goto    Hash_Reset

Hash_Invalid:
        ; Invalid range - reset to 20.0°C
        BANKSEL DesiredTemp_INT
        movlw   20
        movwf   DesiredTemp_INT
        clrf    DesiredTemp_FRAC

Hash_Reset:
        ; Clear input state
        BANKSEL Keypad_Digit_Count
        clrf    Keypad_Digit_Count
        BANKSEL Temp_Tens
        clrf    Temp_Tens
        clrf    Temp_Ones
        clrf    Temp_Decimal

Hash_Ignore:
        ; Restore PORTB
        BANKSEL PORTB
        movlw   0xF0
        movwf   PORTB
        return
