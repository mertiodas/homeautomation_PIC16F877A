; ============================================================================
; FILE: Board_1/keypad.inc
; AUTHOR: Hilal Ongor
; TASK: Keypad Scanning, Input Parsing, Validation (10.0-50.0)
; NOTE: Optimized for integration with main_board1.asm
; ============================================================================

    PSECT udata_bank0
; -- MODULE VARIABLES --
KEY_VAL:        DS 1
LAST_KEY:       DS 1
STATE:          DS 1
DIGIT1:         DS 1
DIGIT2:         DS 1
DIGIT_FRAC:     DS 1
TEMP_CALC:      DS 1
HAS_DOT:        DS 1
KEYPAD_ACTIVE:  DS 1  ; 0: Idle, 1: Data Entry Mode
KEY_DELAY_V:    DS 1
KEY_DELAY_V2:   DS 1

    PSECT code

; ----------------------------------------------------------------------------
; INIT_Keypad
; Called by: main_board1.asm -> init_peripherals
; ----------------------------------------------------------------------------
INIT_Keypad:
    ; Keypad Port Settings (RB0-RB3 Output, RB4-RB7 Input)
    BANKSEL TRISB
    MOVLW 0xF0
    MOVWF TRISB
    
    BANKSEL PORTB
    CLRF PORTB
    
    ; Reset Variables
    BANKSEL STATE
    CLRF STATE
    CLRF KEYPAD_ACTIVE
    CLRF DIGIT1
    CLRF DIGIT2
    CLRF DIGIT_FRAC
    
    ; Default state set to 1
    MOVLW 1
    MOVWF STATE
    RETURN

; ----------------------------------------------------------------------------
; Keypad_Interrupt_Handler
; Called by: main_board1.asm -> ISR
; ----------------------------------------------------------------------------
Keypad_Interrupt_Handler:
    ; When interrupt occurs, enable Input Mode
    BANKSEL KEYPAD_ACTIVE
    MOVLW 1
    MOVWF KEYPAD_ACTIVE
    RETURN

; ----------------------------------------------------------------------------
; Keypad_Task_Run
; IMPORTANT: Safiullah must call this inside MAIN_LOOP
; ----------------------------------------------------------------------------
Keypad_Task_Run:
    ; If not active, return immediately
    BANKSEL KEYPAD_ACTIVE
    MOVF KEYPAD_ACTIVE, W
    BTFSC STATUS, 2     ; If Zero bit is set (Value is 0)
    RETURN

    ; --- ACTIVE MODE: SCAN AND PROCESS ---

    ; 1. Scan Keypad
    CALL SCAN_KEYPAD
    BANKSEL KEY_VAL
    MOVWF KEY_VAL

    ; 2. If No Key, Return
    MOVF KEY_VAL, W
    BTFSC STATUS, 2
    RETURN

    ; 3. Debounce
    BANKSEL LAST_KEY
    MOVWF LAST_KEY
    CALL DELAY_MS_KEY

    ; --- STATE MACHINE LOGIC ---
    
    ; 'A' Key -> Reset
    MOVF LAST_KEY, W
    SUBLW 0x77          ; 'A' ASCII
    BTFSC STATUS, 2
    GOTO TASK_RESET

    ; Check State
    BANKSEL STATE
    MOVF STATE, W
    SUBLW 1
    BTFSC STATUS, 2
    GOTO TASK_SAVE_D1

    MOVF STATE, W
    SUBLW 2
    BTFSC STATUS, 2
    GOTO TASK_SAVE_D2

    MOVF STATE, W
    SUBLW 3
    BTFSC STATUS, 2
    GOTO TASK_CHECK_DOT_OR_ENTER

    MOVF STATE, W
    SUBLW 4
    BTFSC STATUS, 2
    GOTO TASK_SAVE_FRAC

    MOVF STATE, W
    SUBLW 5
    BTFSC STATUS, 2
    GOTO TASK_WAIT_ENTER

    RETURN ; End of task run

; --- TASK SUBROUTINES ---

TASK_RESET:
    BANKSEL STATE
    MOVLW 1
    MOVWF STATE
    CLRF DIGIT1
    CLRF DIGIT2
    CLRF DIGIT_FRAC
    CLRF HAS_DOT
    RETURN

TASK_SAVE_D1:
    CALL GET_NUMBER
    MOVWF TEMP_CALC
    XORLW 0xFF       ; If not a number
    BTFSC STATUS, 2
    RETURN           ; Exit

    ; Save Digit 1
    MOVF TEMP_CALC, W
    BANKSEL DIGIT1
    MOVWF DIGIT1
    MOVLW 2          ; Go to State 2
    MOVWF STATE
    RETURN

TASK_SAVE_D2:
    ; Check Enter (#) for single digit input
    BANKSEL LAST_KEY
    MOVF LAST_KEY, W
    SUBLW 0x71       ; '#'
    BTFSC STATUS, 2
    GOTO HANDLE_SINGLE_DIGIT

    ; Check if Number
    CALL GET_NUMBER
    MOVWF TEMP_CALC
    XORLW 0xFF
    BTFSC STATUS, 2
    RETURN

    ; Save Digit 2
    MOVF TEMP_CALC, W
    BANKSEL DIGIT2
    MOVWF DIGIT2
    MOVLW 3          ; Go to State 3
    MOVWF STATE
    RETURN

HANDLE_SINGLE_DIGIT:
    ; Shift logic: 5# -> 05
    BANKSEL DIGIT1
    MOVF DIGIT1, W
    BANKSEL DIGIT2
    MOVWF DIGIT2
    BANKSEL DIGIT1
    CLRF DIGIT1
    GOTO VALIDATION_LOGIC

TASK_CHECK_DOT_OR_ENTER:
    BANKSEL LAST_KEY
    MOVF LAST_KEY, W
    SUBLW 0x71       ; '#'
    BTFSC STATUS, 2
    GOTO VALIDATION_LOGIC
    
    MOVF LAST_KEY, W
    SUBLW 0x80       ; '.'
    BTFSS STATUS, 2
    RETURN
    
    ; Dot Pressed
    MOVLW 1
    MOVWF HAS_DOT
    CLRF DIGIT_FRAC
    MOVLW 4
    MOVWF STATE
    RETURN

TASK_SAVE_FRAC:
    ; Check Enter (#)
    BANKSEL LAST_KEY
    MOVF LAST_KEY, W
    SUBLW 0x71       ; '#'
    BTFSC STATUS, 2
    GOTO VALIDATION_LOGIC
    
    ; Check Number
    CALL GET_NUMBER
    MOVWF TEMP_CALC
    XORLW 0xFF
    BTFSC STATUS, 2
    RETURN

    ; Save Fraction
    MOVF TEMP_CALC, W
    BANKSEL DIGIT_FRAC
    MOVWF DIGIT_FRAC
    MOVLW 5
    MOVWF STATE
    RETURN

TASK_WAIT_ENTER:
    BANKSEL LAST_KEY
    MOVF LAST_KEY, W
    SUBLW 0x71       ; '#'
    BTFSS STATUS, 2
    RETURN
    GOTO VALIDATION_LOGIC

; --- VALIDATION AND DATA TRANSFER ---
VALIDATION_LOGIC:
    ; Rule: 10.0 <= Temperature <= 50.0
    
    ; Check DIGIT1 (Tens place)
    BANKSEL DIGIT1
    MOVF DIGIT1, W
    BTFSC STATUS, 2   ; If 0 (Range 00-09) -> Fail
    GOTO VALID_FAIL
    
    SUBLW 4           ; If <= 4 (10-49) -> Pass
    BTFSC STATUS, 0   ; Carry set if W <= 4
    GOTO VALID_PASS
    
    ; If DIGIT1 >= 5
    BANKSEL DIGIT1
    MOVF DIGIT1, W
    XORLW 5           ; Is it exactly 5?
    BTFSS STATUS, 2
    GOTO VALID_FAIL   ; If 6,7,8,9 -> Fail
    
    ; If Tens is 5, Ones (DIGIT2) must be 0
    BANKSEL DIGIT2
    MOVF DIGIT2, W
    BTFSS STATUS, 2   ; If not 0 (51, 52...) -> Fail
    GOTO VALID_FAIL
    
    ; If here, it is 50 -> Pass

VALID_PASS:
    ; --- TRANSFER DATA TO MAIN VARIABLES ---
    ; Formula: DesiredTemp_INT = (DIGIT1 * 10) + DIGIT2
    
    ; Multiply DIGIT1 by 10: (x*8) + (x*2)
    BANKSEL DIGIT1
    MOVF DIGIT1, W
    MOVWF TEMP_CALC   ; Temp = D1
    ADDWF TEMP_CALC, F; Temp = 2*D1
    
    BCF STATUS, 0
    RLF DIGIT1, F     ; D1 = 2*D1
    BCF STATUS, 0
    RLF DIGIT1, F     ; D1 = 4*D1
    BCF STATUS, 0
    RLF DIGIT1, F     ; D1 = 8*D1
    
    MOVF TEMP_CALC, W ; W = 2*D1_original
    ADDWF DIGIT1, W   ; W = 8*D1 + 2*D1 = 10*D1
    
    BANKSEL DIGIT2
    ADDWF DIGIT2, W   ; W = 10*D1 + D2 (Result)
    
    ; Write to Global Variable (Defined in main_board1.asm)
    BANKSEL DesiredTemp_INT
    MOVWF DesiredTemp_INT
    
    ; Write Fraction
    BANKSEL DIGIT_FRAC
    MOVF DIGIT_FRAC, W
    BANKSEL DesiredTemp_FRAC
    MOVWF DesiredTemp_FRAC

    ; Show Success ('P') on Port D (Debug)
    MOVLW 0x73 ; 'P'
    BANKSEL PORTD
    MOVWF PORTD
    CALL DELAY_LONG_KEY

    ; Finish Task
    BANKSEL KEYPAD_ACTIVE
    CLRF KEYPAD_ACTIVE
    MOVLW 1
    MOVWF STATE
    RETURN

VALID_FAIL:
    ; Show Fail ('r') and Reset
    MOVLW 0x50 ; 'r'
    BANKSEL PORTD
    MOVWF PORTD
    CALL DELAY_LONG_KEY
    GOTO TASK_RESET


; --- HELPER FUNCTIONS ---

GET_NUMBER:
    BANKSEL TEMP_CALC
    MOVF LAST_KEY, W
    MOVWF TEMP_CALC
    XORLW 0x3F
    BTFSC STATUS, 2
    RETLW 0
    MOVF TEMP_CALC, W
    XORLW 0x06
    BTFSC STATUS, 2
    RETLW 1
    MOVF TEMP_CALC, W
    XORLW 0x5B
    BTFSC STATUS, 2
    RETLW 2
    MOVF TEMP_CALC, W
    XORLW 0x4F
    BTFSC STATUS, 2
    RETLW 3
    MOVF TEMP_CALC, W
    XORLW 0x66
    BTFSC STATUS, 2
    RETLW 4
    MOVF TEMP_CALC, W
    XORLW 0x6D
    BTFSC STATUS, 2
    RETLW 5
    MOVF TEMP_CALC, W
    XORLW 0x7D
    BTFSC STATUS, 2
    RETLW 6
    MOVF TEMP_CALC, W
    XORLW 0x07
    BTFSC STATUS, 2
    RETLW 7
    MOVF TEMP_CALC, W
    XORLW 0x7F
    BTFSC STATUS, 2
    RETLW 8
    MOVF TEMP_CALC, W
    XORLW 0x6F
    BTFSC STATUS, 2
    RETLW 9
    RETLW 0xFF

SCAN_KEYPAD:
    BANKSEL PORTB
    MOVLW 0xE0
    MOVWF PORTB
    CALL DELAY_SCAN_KEY
    BTFSS PORTB, 0
    RETLW 0x06 ; 1
    BTFSS PORTB, 1
    RETLW 0x66 ; 4
    BTFSS PORTB, 2
    RETLW 0x07 ; 7
    BTFSS PORTB, 3
    RETLW 0x80 ; .
    
    MOVLW 0xD0
    MOVWF PORTB
    CALL DELAY_SCAN_KEY
    BTFSS PORTB, 0
    RETLW 0x5B ; 2
    BTFSS PORTB, 1
    RETLW 0x6D ; 5
    BTFSS PORTB, 2
    RETLW 0x7F ; 8
    BTFSS PORTB, 3
    RETLW 0x3F ; 0
    
    MOVLW 0xB0
    MOVWF PORTB
    CALL DELAY_SCAN_KEY
    BTFSS PORTB, 0
    RETLW 0x4F ; 3
    BTFSS PORTB, 1
    RETLW 0x7D ; 6
    BTFSS PORTB, 2
    RETLW 0x6F ; 9
    BTFSS PORTB, 3
    RETLW 0x71 ; #
    
    MOVLW 0x70
    MOVWF PORTB
    CALL DELAY_SCAN_KEY
    BTFSS PORTB, 0
    RETLW 0x77 ; A
    BTFSS PORTB, 1
    RETLW 0x7C ; B
    BTFSS PORTB, 2
    RETLW 0x39 ; C
    BTFSS PORTB, 3
    RETLW 0x5E ; D

    MOVLW 0xF0
    MOVWF PORTB
    RETLW 0x00

DELAY_SCAN_KEY:
    MOVLW 0x10
    BANKSEL KEY_DELAY_V
    MOVWF KEY_DELAY_V
D_LOOP1: 
    DECFSZ KEY_DELAY_V, F
    GOTO D_LOOP1
    RETURN

DELAY_MS_KEY:
    MOVLW 0xFF
    BANKSEL KEY_DELAY_V
    MOVWF KEY_DELAY_V
D_LOOP2: 
    DECFSZ KEY_DELAY_V, F
    GOTO D_LOOP2
    RETURN

DELAY_LONG_KEY:
    MOVLW 0xFF
    BANKSEL KEY_DELAY_V2
    MOVWF KEY_DELAY_V2
LONG_OUTER_K:
    MOVLW 0xFF
    MOVWF KEY_DELAY_V
LONG_INNER_K:
    NOP
    DECFSZ KEY_DELAY_V, F
    GOTO LONG_INNER_K
    DECFSZ KEY_DELAY_V2, F
    GOTO LONG_OUTER_K
    RETURN
