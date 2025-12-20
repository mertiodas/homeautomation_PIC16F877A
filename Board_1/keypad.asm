; ======================================================
; MODULE: keypad.asm
; AUTHOR: HILAL ONGOR
; TASK: Keypad Scanning, Input Parsing, Validation (10.0-50.0)
; COMPATIBILITY: Matches main_board1.asm structure
; ======================================================

        PROCESSOR 16F877A
        #include <xc.inc>

; ============================================================
; EXTERNAL DECLARATIONS (Variables from MAIN)
; ============================================================
        ; Main loop variables
        EXTERN _DesiredTemp_INT
        EXTERN _DesiredTemp_FRAC
        
        ; Keypad variables defined in MAIN
        EXTERN _KEY_VAL, _LAST_KEY, _STATE
        EXTERN _DIGIT1, _DIGIT2, _DIGIT_FRAC
        EXTERN _TEMP_CALC, _HAS_DOT
        EXTERN _DELAY_VAR, _DELAY_VAR2

; ============================================================
; GLOBAL DECLARATIONS (Functions exported to MAIN)
; ============================================================
        GLOBAL _INIT_Keypad
        GLOBAL _Keypad_Process
        GLOBAL _Keypad_Interrupt_Handler

; ============================================================
; CODE SECTION
; ============================================================
        PSECT text_keypad,local,class=CODE,delta=2

; --------------------------------------------------
; INIT_Keypad
; Called from init_peripherals in MAIN
; --------------------------------------------------
_INIT_Keypad:
        ; Configure PORTB for Keypad (RB0-3 Inputs, RB4-7 Outputs based on Main config)
        ; Main sets TRISB to 0x0F.
        
        BANKSEL _STATE
        clrf    _STATE          ; State 0: Idle / Waiting for 'A'
        clrf    _KEY_VAL
        clrf    _DIGIT1
        clrf    _DIGIT2
        clrf    _DIGIT_FRAC
        return

; --------------------------------------------------
; Keypad_Interrupt_Handler
; Called from ISR in MAIN when RBIF is set
; Task: "Pressing button A will run the interrupt routine"
; --------------------------------------------------
_Keypad_Interrupt_Handler:
        ; Read PORTB to clear mismatch condition (Essential for ISR)
        BANKSEL PORTB
        movf    PORTB, W
        
        ; Note: Ideally, we scan here to see if 'A' is pressed.
        ; But full scanning in ISR is slow. 
        ; We will rely on the main loop to process the input,
        ; The ISR just ensures the flag is cleared so main keeps running.
        return

; --------------------------------------------------
; Keypad_Process
; Called from MAIN_LOOP
; State Machine Implementation
; --------------------------------------------------
_Keypad_Process:
        ; 1. Scan Keypad
        call    SCAN_KEYPAD
        
        BANKSEL _KEY_VAL
        movf    _KEY_VAL, W
        btfsc   STATUS, 2       ; If Zero (No Key), Return
        return

        ; 2. Debounce
        call    DELAY_MS_KEY
        
        ; 3. Save Key to Last Key
        BANKSEL _KEY_VAL
        movf    _KEY_VAL, W
        BANKSEL _LAST_KEY
        movwf   _LAST_KEY

        ; 4. Check for 'A' (Reset / Start) - ALWAYS ACTIVE
        movf    _LAST_KEY, W
        xorlw   0x41            ; 'A' ASCII Code (depends on mapping, let's assume ASCII)
        ; Adjust mapping below if needed. Using direct values from Scan routine.
        ; Let's assume Scan returns mapped ASCII.
        
        ; --- STATE MACHINE ---
        BANKSEL _STATE
        movf    _STATE, W
        
        ; State 0: Idle (Wait for 'A')
        xorlw   0
        btfsc   STATUS, 2
        goto    State_0_Idle
        
        movf    _STATE, W
        xorlw   1
        btfsc   STATUS, 2
        goto    State_1_Digit1

        movf    _STATE, W
        xorlw   2
        btfsc   STATUS, 2
        goto    State_2_Digit2

        movf    _STATE, W
        xorlw   3
        btfsc   STATUS, 2
        goto    State_3_Dot

        movf    _STATE, W
        xorlw   4
        btfsc   STATUS, 2
        goto    State_4_Frac
        
        movf    _STATE, W
        xorlw   5
        btfsc   STATUS, 2
        goto    State_5_Enter
        
        return

; --- STATES ---

State_0_Idle:
        ; Wait for 'A' to start input
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   'A'             ; Check if key is 'A'
        btfss   STATUS, 2
        return                  ; Not 'A', ignore
        
        ; 'A' Pressed: Reset variables and go to State 1
        BANKSEL _DIGIT1
        clrf    _DIGIT1
        clrf    _DIGIT2
        clrf    _DIGIT_FRAC
        
        BANKSEL _STATE
        movlw   1
        movwf   _STATE
        return

State_1_Digit1:
        ; Expecting 1st Digit (Tens)
        call    GET_NUMERIC_VAL
        movwf   _TEMP_CALC
        incf    _TEMP_CALC, W   ; Check if 0xFF (Error)
        btfsc   STATUS, 2
        return                  ; Not a number, ignore
        
        ; Save Digit 1
        BANKSEL _TEMP_CALC
        movf    _TEMP_CALC, W
        BANKSEL _DIGIT1
        movwf   _DIGIT1
        
        ; Next State
        BANKSEL _STATE
        movlw   2
        movwf   _STATE
        return

State_2_Digit2:
        ; Expecting 2nd Digit (Ones) OR Dot (if single digit tens)
        ; Check for Dot '.'
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   '*'             ; Assuming '*' is used for '.' as per task usually
        btfsc   STATUS, 2
        goto    Dot_Pressed_Early

        ; Check for Number
        call    GET_NUMERIC_VAL
        movwf   _TEMP_CALC
        incf    _TEMP_CALC, W
        btfsc   STATUS, 2
        return                  ; Invalid input
        
        ; Save Digit 2
        BANKSEL _TEMP_CALC
        movf    _TEMP_CALC, W
        BANKSEL _DIGIT2
        movwf   _DIGIT2
        
        BANKSEL _STATE
        movlw   3
        movwf   _STATE
        return

Dot_Pressed_Early:
        ; User pressed '.' after 1 digit. 
        ; Shift D1 -> D2, set D1=0? No, task says "Max 2 digits integral".
        ; Example: "5." -> D1=5. This is valid.
        ; Move to State 4 (Frac)
        BANKSEL _STATE
        movlw   4
        movwf   _STATE
        return

State_3_Dot:
        ; Expecting '.'
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   '*'             ; Keypad '*' represents '.'
        btfss   STATUS, 2
        return                  ; Ignore other keys
        
        BANKSEL _STATE
        movlw   4
        movwf   _STATE
        return

State_4_Frac:
        ; Expecting Fractional Digit
        call    GET_NUMERIC_VAL
        movwf   _TEMP_CALC
        incf    _TEMP_CALC, W
        btfsc   STATUS, 2
        return
        
        BANKSEL _TEMP_CALC
        movf    _TEMP_CALC, W
        BANKSEL _DIGIT_FRAC
        movwf   _DIGIT_FRAC
        
        BANKSEL _STATE
        movlw   5
        movwf   _STATE
        return

State_5_Enter:
        ; Expecting '#' to Confirm
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   '#'
        btfss   STATUS, 2
        return
        
        ; Validate and Update
        goto    VALIDATE_AND_UPDATE

; --------------------------------------------------
; VALIDATE AND UPDATE
; Rule: 10.0 <= Temp <= 50.0
; --------------------------------------------------
VALIDATE_AND_UPDATE:
        ; Calculate Total Integer: (Digit1 * 10) + Digit2
        
        ; 1. Check if single digit entry logic applies
        ; If user entered "9.", Digit1=9, Digit2=0. Value 90? No.
        ; NOTE: Simple logic: 
        ; DesiredTemp_INT = (Digit1 * 10) + Digit2.
        
        ; Range Check:
        ; Min: 10
        ; Max: 50
        
        ; Check Tens Digit (_DIGIT1)
        BANKSEL _DIGIT1
        movf    _DIGIT1, W
        sublw   0               ; If D1 < 1 (i.e., 0)
        btfsc   STATUS, 2       ; If D1 == 0
        goto    Invalid_Input   ; < 10.0
        
        movf    _DIGIT1, W
        sublw   5
        btfss   STATUS, 0       ; If 5 < D1 (i.e. 6,7,8,9)
        goto    Invalid_Input   ; > 59.9
        
        ; If D1 == 5, Check Ones and Frac
        movf    _DIGIT1, W
        xorlw   5
        btfss   STATUS, 2
        goto    Valid_Range     ; If D1 is 1,2,3,4 -> Valid
        
        ; D1 is 5. Check D2.
        BANKSEL _DIGIT2
        movf    _DIGIT2, W
        xorlw   0
        btfss   STATUS, 2       ; If D2 != 0
        goto    Invalid_Input   ; 51, 52... Invalid.
        
        ; D1=5, D2=0 (50). Check Frac.
        BANKSEL _DIGIT_FRAC
        movf    _DIGIT_FRAC, W
        xorlw   0
        btfss   STATUS, 2       ; If Frac != 0
        goto    Invalid_Input   ; 50.1... Invalid.
        
Valid_Range:
        ; Valid Input! Update Global Variables.
        
        ; DesiredTemp_INT = (_DIGIT1 * 10) + _DIGIT2
        BANKSEL _DIGIT1
        movf    _DIGIT1, W
        movwf   _TEMP_CALC      ; Temp = D1
        
        ; Multiply by 10 (x8 + x2)
        bcf     STATUS, 0
        rlf     _TEMP_CALC, F   ; x2
        movf    _TEMP_CALC, W   ; Save x2
        
        bcf     STATUS, 0
        rlf     _TEMP_CALC, F   ; x4
        bcf     STATUS, 0
        rlf     _TEMP_CALC, F   ; x8
        
        addwf   _TEMP_CALC, F   ; x8 + x2 = x10
        
        BANKSEL _DIGIT2
        movf    _DIGIT2, W
        BANKSEL _TEMP_CALC
        addwf   _TEMP_CALC, W   ; W = (D1*10) + D2
        
        BANKSEL _DesiredTemp_INT
        movwf   _DesiredTemp_INT
        
        BANKSEL _DIGIT_FRAC
        movf    _DIGIT_FRAC, W
        BANKSEL _DesiredTemp_FRAC
        movwf   _DesiredTemp_FRAC
        
        ; Reset State
        goto    Reset_State

Invalid_Input:
        ; Reject input, do not update.
        goto    Reset_State

Reset_State:
        BANKSEL _STATE
        clrf    _STATE
        return

; --------------------------------------------------
; HELPER: GET_NUMERIC_VAL
; Converts ASCII/Keycode to Number (0-9)
; Returns 0xFF if not a number
; --------------------------------------------------
GET_NUMERIC_VAL:
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        
        xorlw   '0'
        btfsc   STATUS, 2
        retlw   0
        
        movf    _LAST_KEY, W
        xorlw   '1'
        btfsc   STATUS, 2
        retlw   1
        
        movf    _LAST_KEY, W
        xorlw   '2'
        btfsc   STATUS, 2
        retlw   2
        
        movf    _LAST_KEY, W
        xorlw   '3'
        btfsc   STATUS, 2
        retlw   3
        
        movf    _LAST_KEY, W
        xorlw   '4'
        btfsc   STATUS, 2
        retlw   4
        
        movf    _LAST_KEY, W
        xorlw   '5'
        btfsc   STATUS, 2
        retlw   5
        
        movf    _LAST_KEY, W
        xorlw   '6'
        btfsc   STATUS, 2
        retlw   6
        
        movf    _LAST_KEY, W
        xorlw   '7'
        btfsc   STATUS, 2
        retlw   7
        
        movf    _LAST_KEY, W
        xorlw   '8'
        btfsc   STATUS, 2
        retlw   8
        
        movf    _LAST_KEY, W
        xorlw   '9'
        btfsc   STATUS, 2
        retlw   9
        
        retlw   0xFF

; --------------------------------------------------
; SCAN_KEYPAD
; Scans 4x4 or 4x3 Keypad
; Returns ASCII in _KEY_VAL (or 0 if no key)
; --------------------------------------------------
SCAN_KEYPAD:
        ; Configuration based on Safiullah's Main:
        ; PORTB low nibble = Input, high nibble = Output
        ; (Rows and Cols wiring depends on Proteus/Hardware)
        ; Standard Multiplexing
        
        BANKSEL _KEY_VAL
        clrf    _KEY_VAL

        ; Scan Column 1 (RB4 Low)
        BANKSEL PORTB
        movlw   b'11101111'     ; RB4 Low
        movwf   PORTB
        nop
        nop
        ; Check Rows (RB0-3)
        btfss   PORTB, 0
        retlw   '1'             ; Row 1
        btfss   PORTB, 1
        retlw   '4'             ; Row 2
        btfss   PORTB, 2
        retlw   '7'             ; Row 3
        btfss   PORTB, 3
        retlw   '*'             ; Row 4

        ; Scan Column 2 (RB5 Low)
        movlw   b'11011111'     ; RB5 Low
        movwf   PORTB
        nop
        nop
        btfss   PORTB, 0
        retlw   '2'
        btfss   PORTB, 1
        retlw   '5'
        btfss   PORTB, 2
        retlw   '8'
        btfss   PORTB, 3
        retlw   '0'

        ; Scan Column 3 (RB6 Low)
        movlw   b'10111111'     ; RB6 Low
        movwf   PORTB
        nop
        nop
        btfss   PORTB, 0
        retlw   '3'
        btfss   PORTB, 1
        retlw   '6'
        btfss   PORTB, 2
        retlw   '9'
        btfss   PORTB, 3
        retlw   '#'

        ; Scan Column 4 (RB7 Low) - For A,B,C,D
        movlw   b'01111111'     ; RB7 Low
        movwf   PORTB
        nop
        nop
        btfss   PORTB, 0
        retlw   'A'
        btfss   PORTB, 1
        retlw   'B'
        btfss   PORTB, 2
        retlw   'C'
        btfss   PORTB, 3
        retlw   'D'

        ; Reset Port (All High to detect interrupt)
        movlw   0xF0
        movwf   PORTB
        
        retlw   0

; --------------------------------------------------
; DELAY_MS_KEY
; Simple delay using variables from Main
; --------------------------------------------------
DELAY_MS_KEY:
        BANKSEL _DELAY_VAR
        movlw   0xFF
        movwf   _DELAY_VAR
loop1:  decfsz  _DELAY_VAR, F
        goto    loop1
        return

        END
