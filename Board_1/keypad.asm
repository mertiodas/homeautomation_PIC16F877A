; ======================================================
; MODULE: keypad.asm
; AUTHOR: HILAL ONGOR
; TASK: Keypad Scanning, Parsing, Validation (10.0-50.0)
; COMPATIBILITY: Matches main_board1.asm (Shared Memory Logic)
; NOTE: Binary literals changed to HEX for compatibility
; ======================================================

        PROCESSOR 16F877A
        #include <xc.inc>

; ============================================================
; EXTERNAL DECLARATIONS (Variables defined in MAIN)
; ============================================================
        ; Main global variables (Shared Memory)
        EXTERN _DesiredTemp_INT
        EXTERN _DesiredTemp_FRAC
        
        ; Keypad specific variables (Defined in MAIN)
        EXTERN _KEY_VAL, _LAST_KEY, _STATE
        EXTERN _DIGIT1, _DIGIT2, _DIGIT_FRAC
        EXTERN _TEMP_CALC, _HAS_DOT
        EXTERN _DELAY_VAR, _DELAY_VAR2

; ============================================================
; GLOBAL DECLARATIONS (Functions accessible by MAIN)
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
; Called by Main during system startup
; --------------------------------------------------
_INIT_Keypad:
        BANKSEL _STATE
        clrf    _STATE          ; State 0: Idle Mode
        clrf    _KEY_VAL
        clrf    _DIGIT1
        clrf    _DIGIT2
        clrf    _DIGIT_FRAC
        return

; --------------------------------------------------
; Keypad_Interrupt_Handler
; Called by ISR when 'A' or any key triggers RB Change
; --------------------------------------------------
_Keypad_Interrupt_Handler:
        BANKSEL PORTB
        movf    PORTB, W        ; Read Port to clear mismatch
        return

; --------------------------------------------------
; Keypad_Process
; Called repeatedly inside MAIN_LOOP
; --------------------------------------------------
_Keypad_Process:
        ; 1. Scan Keypad
        call    SCAN_KEYPAD
        
        BANKSEL _KEY_VAL
        movf    _KEY_VAL, W
        btfsc   STATUS, 2       ; If no key (0), return
        return

        ; 2. Debounce
        call    DELAY_MS_KEY
        
        ; 3. Save current key
        BANKSEL _KEY_VAL
        movf    _KEY_VAL, W
        BANKSEL _LAST_KEY
        movwf   _LAST_KEY

        ; 4. Check 'A' (ALWAYS RESET)
        movf    _LAST_KEY, W
        xorlw   'A'
        btfsc   STATUS, 2
        goto    State_0_Idle
        
        ; --- STATE MACHINE ---
        BANKSEL _STATE
        movf    _STATE, W
        
        xorlw   0
        btfsc   STATUS, 2
        goto    State_0_Idle    ; Wait for A
        
        movf    _STATE, W
        xorlw   1
        btfsc   STATUS, 2
        goto    State_1_Digit1  ; Tens digit

        movf    _STATE, W
        xorlw   2
        btfsc   STATUS, 2
        goto    State_2_Digit2  ; Ones digit

        movf    _STATE, W
        xorlw   3
        btfsc   STATUS, 2
        goto    State_3_Dot     ; Dot

        movf    _STATE, W
        xorlw   4
        btfsc   STATUS, 2
        goto    State_4_Frac    ; Fraction
        
        movf    _STATE, W
        xorlw   5
        btfsc   STATUS, 2
        goto    State_5_Enter   ; Confirm (#)
        
        return

; --- STATES ---

State_0_Idle:
        ; Only accept 'A'
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   'A'
        btfss   STATUS, 2
        return                  ; Not 'A', exit
        
        ; 'A' Pressed: Reset variables
        BANKSEL _DIGIT1
        clrf    _DIGIT1
        clrf    _DIGIT2
        clrf    _DIGIT_FRAC
        
        BANKSEL _STATE
        movlw   1
        movwf   _STATE
        return

State_1_Digit1:
        ; Get Tens Digit
        call    GET_NUMERIC_VAL
        movwf   _TEMP_CALC
        incf    _TEMP_CALC, W   ; Check 0xFF
        btfsc   STATUS, 2
        return                  ; Not a number
        
        BANKSEL _TEMP_CALC
        movf    _TEMP_CALC, W
        BANKSEL _DIGIT1
        movwf   _DIGIT1
        
        BANKSEL _STATE
        movlw   2
        movwf   _STATE
        return

State_2_Digit2:
        ; Get Ones Digit OR Dot
        
        ; Check Dot
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   '*'             ; '*' is Dot
        btfsc   STATUS, 2
        goto    Dot_Pressed_Early

        ; Check Number
        call    GET_NUMERIC_VAL
        movwf   _TEMP_CALC
        incf    _TEMP_CALC, W
        btfsc   STATUS, 2
        return
        
        BANKSEL _TEMP_CALC
        movf    _TEMP_CALC, W
        BANKSEL _DIGIT2
        movwf   _DIGIT2
        
        BANKSEL _STATE
        movlw   3
        movwf   _STATE
        return

Dot_Pressed_Early:
        ; User typed "X." (e.g., "5.")
        ; Digit1=5, Digit2=0. Go to Frac.
        BANKSEL _STATE
        movlw   4
        movwf   _STATE
        return

State_3_Dot:
        ; Expect Dot
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   '*'
        btfss   STATUS, 2
        return
        
        BANKSEL _STATE
        movlw   4
        movwf   _STATE
        return

State_4_Frac:
        ; Get Fractional Digit
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
        ; Expect Enter (#)
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   '#'
        btfss   STATUS, 2
        return
        
        ; Proceed to Validation
        goto    VALIDATE_AND_UPDATE

; --------------------------------------------------
; VALIDATE & UPDATE
; Range: 10.0 to 50.0
; --------------------------------------------------
VALIDATE_AND_UPDATE:
        ; 1. Check Tens (_DIGIT1)
        BANKSEL _DIGIT1
        movf    _DIGIT1, W
        sublw   0
        btfsc   STATUS, 2       ; If 0 -> Fail (<10)
        goto    Invalid_Input
        
        movf    _DIGIT1, W
        sublw   5
        btfss   STATUS, 0       ; If >5 -> Fail (>59)
        goto    Invalid_Input
        
        ; If 5, check limits
        movf    _DIGIT1, W
        xorlw   5
        btfss   STATUS, 2
        goto    Valid_Range     ; 1,2,3,4 -> OK
        
        ; Tens=5. Check Ones.
        BANKSEL _DIGIT2
        movf    _DIGIT2, W
        xorlw   0
        btfss   STATUS, 2       ; If not 0 -> Fail (51...)
        goto    Invalid_Input
        
        ; Tens=5, Ones=0 (50). Check Frac.
        BANKSEL _DIGIT_FRAC
        movf    _DIGIT_FRAC, W
        xorlw   0
        btfss   STATUS, 2       ; If not 0 -> Fail (50.1)
        goto    Invalid_Input
        
Valid_Range:
        ; --- UPDATE SYSTEM VARIABLES ---
        ; DesiredTemp_INT = (D1 * 10) + D2
        
        BANKSEL _DIGIT1
        movf    _DIGIT1, W
        movwf   _TEMP_CALC
        
        ; Multiply by 10 (Shift algorithm)
        bcf     STATUS, 0
        rlf     _TEMP_CALC, F   ; x2
        movf    _TEMP_CALC, W
        
        bcf     STATUS, 0
        rlf     _TEMP_CALC, F   ; x4
        bcf     STATUS, 0
        rlf     _TEMP_CALC, F   ; x8
        
        addwf   _TEMP_CALC, F   ; x8 + x2 = x10
        
        BANKSEL _DIGIT2
        movf    _DIGIT2, W
        BANKSEL _TEMP_CALC
        addwf   _TEMP_CALC, W   ; W = Final Integer
        
        ; Write to Main Variable
        BANKSEL _DesiredTemp_INT
        movwf   _DesiredTemp_INT
        
        ; Write Fraction
        BANKSEL _DIGIT_FRAC
        movf    _DIGIT_FRAC, W
        BANKSEL _DesiredTemp_FRAC
        movwf   _DesiredTemp_FRAC
        
        goto    Reset_State

Invalid_Input:
        ; Reject
        goto    Reset_State

Reset_State:
        BANKSEL _STATE
        clrf    _STATE
        return

; --------------------------------------------------
; HELPER: GET_NUMERIC_VAL
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
; --------------------------------------------------
SCAN_KEYPAD:
        BANKSEL _KEY_VAL
        clrf    _KEY_VAL

        ; Col 1 (RB4 Low) - Replaced binary with HEX for safety
        BANKSEL PORTB
        movlw   0xEF            ; Was b'11101111'
        movwf   PORTB
        nop
        nop
        btfss   PORTB, 0
        retlw   '1'
        btfss   PORTB, 1
        retlw   '4'
        btfss   PORTB, 2
        retlw   '7'
        btfss   PORTB, 3
        retlw   '*'

        ; Col 2 (RB5 Low)
        movlw   0xDF            ; Was b'11011111'
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

        ; Col 3 (RB6 Low)
        movlw   0xBF            ; Was b'10111111'
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

        ; Col 4 (RB7 Low)
        movlw   0x7F            ; Was b'01111111'
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

        ; Reset Port
        movlw   0xF0
        movwf   PORTB
        
        retlw   0

; --------------------------------------------------
; DELAY_MS_KEY
; --------------------------------------------------
DELAY_MS_KEY:
        BANKSEL _DELAY_VAR
        movlw   0xFF
        movwf   _DELAY_VAR
loop1:  decfsz  _DELAY_VAR, F
        goto    loop1
        return
