;=============================================================================
; FILE: Board_1/keypad.inc
; AUTHOR: HILAL ONGOR
; BOARD: Board #1
; TASK: Implement Keypad scanning, 'A' interrupt, input parsing, 
;       and validation (10.0 to 50.0).
;
; VALIDATION RULES:
; 10 <= Number <= 50 -> P (Pass)
; Others -> r (Reject)
;
; SPECIAL CASES:
; 50 (#) -> P (Pass)
; 51 (#) -> r (Reject)
; 09 (#) -> r (Reject)
; 5.0 (#) -> P (Pass)
;=============================================================================

    PROCESSOR 16F877A
    #include <xc.inc>

    ; --- CONFIGURATION ---
    CONFIG FOSC = XT
    CONFIG WDTE = OFF
    CONFIG PWRTE = ON
    CONFIG BOREN = OFF
    CONFIG LVP = OFF
    CONFIG CPD = OFF
    CONFIG WRT = OFF
    CONFIG CP = OFF

    ; --- VARIABLES ---
    PSECT udata_bank0
DELAY_VAR:      DS 1
DELAY_VAR2:     DS 1
KEY_VAL:        DS 1
LAST_KEY:       DS 1
STATE:          DS 1
DIGIT1:         DS 1
DIGIT2:         DS 1
DIGIT_FRAC:     DS 1
TEMP_CALC:      DS 1
HAS_DOT:        DS 1
UART_RX_Byte:   DS 1
UART_Flag:      DS 1

    ; --- RESET VECTOR ---
    PSECT resetVec, class=CODE, delta=2
resetVec:
    PAGESEL START
    GOTO    START

    ; --- CODE SECTION ---
    PSECT code

START:
    CALL    INIT_SYSTEM
    CALL    INIT_Keypad
    
    BANKSEL KEY_VAL
    CLRF    KEY_VAL
    CLRF    LAST_KEY
    CLRF    DIGIT1
    CLRF    DIGIT2
    CLRF    DIGIT_FRAC
    CLRF    HAS_DOT
    
    MOVLW   1
    MOVWF   STATE

    ; START SCREEN: '-'
    MOVLW   0x40
    MOVWF   PORTD

MAIN_LOOP1:
    ; 1. Scan Keypad
    CALL    SCAN_KEYPAD
    BANKSEL KEY_VAL
    MOVWF   KEY_VAL

    ; 2. No Key -> Wait
    MOVF    KEY_VAL, W
    BTFSC   STATUS, 2
    GOTO    NO_KEY

    ; 3. Key Found -> SHOW on Screen
    MOVF    KEY_VAL, W
    MOVWF   PORTD

    ; Debounce
    BANKSEL LAST_KEY
    MOVWF   LAST_KEY
    CALL    DELAY_MS

    ; --- TASK CONTROL ---

    ; 'A' Reset Check
    BANKSEL LAST_KEY
    MOVF    LAST_KEY, W
    SUBLW   0x77            ; 'A'
    BTFSC   STATUS, 2
    GOTO    TASK_RESET

    ; State Machine Logic
    BANKSEL STATE
    MOVF    STATE, W
    SUBLW   1
    BTFSC   STATUS, 2
    GOTO    TASK_SAVE_D1

    MOVF    STATE, W
    SUBLW   2
    BTFSC   STATUS, 2
    GOTO    TASK_SAVE_D2

    MOVF    STATE, W
    SUBLW   3
    BTFSC   STATUS, 2
    GOTO    TASK_CHECK_DOT_OR_ENTER

    MOVF    STATE, W
    SUBLW   4
    BTFSC   STATUS, 2
    GOTO    TASK_SAVE_FRAC

    MOVF    STATE, W
    SUBLW   5
    BTFSC   STATUS, 2
    GOTO    TASK_WAIT_ENTER

    GOTO    WAIT_RELEASE

; --- TASK SUBROUTINES ---

TASK_RESET:
    CALL    DELAY_LONG
    
    MOVLW   0x40            ; '-'
    MOVWF   PORTD
    
    BANKSEL STATE
    MOVLW   1
    MOVWF   STATE
    CLRF    DIGIT1
    CLRF    DIGIT2
    CLRF    DIGIT_FRAC
    CLRF    HAS_DOT
    
    GOTO    WAIT_RELEASE

TASK_SAVE_D1:
    ; Save first digit
    CALL    GET_NUMBER
    MOVWF   TEMP_CALC
    XORLW   0xFF
    BTFSC   STATUS, 2
    GOTO    WAIT_RELEASE

    MOVF    TEMP_CALC, W
    BANKSEL DIGIT1
    MOVWF   DIGIT1
    MOVLW   2
    MOVWF   STATE
    GOTO    WAIT_RELEASE

TASK_SAVE_D2:
    ; Enter check - Single digit case
    BANKSEL LAST_KEY
    MOVF    LAST_KEY, W
    SUBLW   0x71            ; '#' (Enter)
    BTFSC   STATUS, 2
    GOTO    HANDLE_SINGLE_DIGIT

    ; Is it a digit?
    CALL    GET_NUMBER
    MOVWF   TEMP_CALC
    
    ; Check if 0xFF (not a digit)
    MOVF    TEMP_CALC, W
    XORLW   0xFF
    BTFSC   STATUS, 2
    GOTO    WAIT_RELEASE    ; Not a digit -> wait

    ; Save digit (0-9 range)
    MOVF    TEMP_CALC, W
    BANKSEL DIGIT2
    MOVWF   DIGIT2
    MOVLW   3
    MOVWF   STATE
    GOTO    WAIT_RELEASE

HANDLE_SINGLE_DIGIT:
    ; User entered single digit (e.g: 4 -> #)
    ; 0-4 -> r, 5-9 -> make it two digits (05-09)
    BANKSEL DIGIT1
    MOVF    DIGIT1, W
    
    ; Is it less than or equal to 4?
    SUBLW   4
    BTFSC   STATUS, 0       ; Carry=1 if DIGIT1 <= 4
    GOTO    SHOW_FAIL
    
    ; Between 5-9, make it 05-09
    MOVF    DIGIT1, W
    MOVWF   DIGIT2
    CLRF    DIGIT1
    GOTO    VALIDATION_LOGIC

TASK_CHECK_DOT_OR_ENTER:
    ; '#' check - Enter
    BANKSEL LAST_KEY
    MOVF    LAST_KEY, W
    SUBLW   0x71            ; '#' (Enter)
    BTFSC   STATUS, 2
    GOTO    VALIDATION_LOGIC
    
    ; '.' check
    MOVF    LAST_KEY, W
    SUBLW   0x80            ; '.' 
    BTFSS   STATUS, 2
    GOTO    WAIT_RELEASE
    
    ; Dot pressed
    BANKSEL HAS_DOT
    MOVLW   1
    MOVWF   HAS_DOT
    CLRF    DIGIT_FRAC

    MOVLW   4
    MOVWF   STATE
    GOTO    WAIT_RELEASE

TASK_SAVE_FRAC:
    ; Enter check - Direct Enter after dot
    BANKSEL LAST_KEY
    MOVF    LAST_KEY, W
    SUBLW   0x71            ; '#' (Enter)
    BTFSC   STATUS, 2
    GOTO    VALIDATION_LOGIC ; Enter -> Go to Validation
    
    ; Check if digit
    CALL    GET_NUMBER
    MOVWF   TEMP_CALC
    XORLW   0xFF
    BTFSC   STATUS, 2
    GOTO    WAIT_RELEASE    ; Not a digit -> wait

    ; If digit, save it
    MOVF    TEMP_CALC, W
    BANKSEL DIGIT_FRAC
    MOVWF   DIGIT_FRAC
    MOVLW   5
    MOVWF   STATE
    GOTO    WAIT_RELEASE

TASK_WAIT_ENTER:
    BANKSEL LAST_KEY
    MOVF    LAST_KEY, W
    SUBLW   0x71            ; '#' (Enter)
    BTFSS   STATUS, 2
    GOTO    WAIT_RELEASE

    GOTO    VALIDATION_LOGIC

; ============================================================================
; VALIDATION LOGIC (CORRECTED SECTION)
; ============================================================================
VALIDATION_LOGIC:
    ; 2. DIGIT1 based check
    BANKSEL DIGIT1
    MOVF    DIGIT1, W
    
    ; DIGIT1 = 0? -> ERROR (00-09)
    BTFSC   STATUS, 2
    GOTO    SHOW_FAIL
    
    ; DIGIT1 = 6,7,8,9 -> ERROR
    XORLW   6
    BTFSC   STATUS, 2
    GOTO    SHOW_FAIL
    
    MOVF    DIGIT1, W
    XORLW   7
    BTFSC   STATUS, 2
    GOTO    SHOW_FAIL

    MOVF    DIGIT1, W
    XORLW   8
    BTFSC   STATUS, 2
    GOTO    SHOW_FAIL
    
    MOVF    DIGIT1, W
    XORLW   9
    BTFSC   STATUS, 2
    GOTO    SHOW_FAIL
    
    ; DIGIT1 = 5? -> Check DIGIT2
    MOVF    DIGIT1, W
    XORLW   5
    BTFSC   STATUS, 2
    GOTO    CHECK_IF_50
    
    ; DIGIT1 = 1,2,3,4 -> PASS
    GOTO    SHOW_PASS

CHECK_IF_50:
    ; If DIGIT1 is 5, comes here.
    ; If DIGIT2 is 0 (50) -> PASS
    ; If DIGIT2 != 0 (51, 52...) -> FAIL
    
    BANKSEL DIGIT2
    MOVF    DIGIT2, W
    XORLW   0               ; Is W register 0? (Is DIGIT2 0?)
    BTFSS   STATUS, 2       ; Z=1 (Equal) skip to PASS
    GOTO    SHOW_FAIL       ; Z=0 (Not Equal) FAIL (51, 52...)
    
    GOTO    SHOW_PASS       ; 50 -> PASS

SHOW_PASS:
    MOVLW   0x73            ; 'P'
    MOVWF   PORTD
    CALL    DELAY_LONG
    CALL    DELAY_LONG
    GOTO    RESET_SCREEN

SHOW_FAIL:
    MOVLW   0x50            ; 'r'
    MOVWF   PORTD
    CALL    DELAY_LONG
    CALL    DELAY_LONG
    GOTO    RESET_SCREEN

RESET_SCREEN:
    MOVLW   0x40            ; '-'
    MOVWF   PORTD
    
    BANKSEL STATE
    MOVLW   1
    MOVWF   STATE
    CLRF    DIGIT1
    CLRF    DIGIT2
    CLRF    DIGIT_FRAC
    CLRF    HAS_DOT
    GOTO    WAIT_RELEASE

WAIT_RELEASE:
    CALL    DELAY_MS
    CALL    SCAN_KEYPAD
    BANKSEL KEY_VAL
    MOVWF   KEY_VAL
    MOVF    KEY_VAL, W
    BTFSS   STATUS, 2
    GOTO    WAIT_RELEASE
    GOTO    MAIN_LOOP1

NO_KEY:
    GOTO    MAIN_LOOP1

GET_NUMBER:
    BANKSEL TEMP_CALC
    MOVF    LAST_KEY, W
    MOVWF   TEMP_CALC
    
    ; Check for 0
    MOVF    TEMP_CALC, W
    XORLW   0x3F            ; 0x3F = '0'
    BTFSC   STATUS, 2
    RETLW   0
    
    ; Check for 1
    MOVF    TEMP_CALC, W
    XORLW   0x06            ; 0x06 = '1'
    BTFSC   STATUS, 2
    RETLW   1
    
    ; Check for 2
    MOVF    TEMP_CALC, W
    XORLW   0x5B            ; 0x5B = '2'
    BTFSC   STATUS, 2
    RETLW   2
    
    ; Check for 3
    MOVF    TEMP_CALC, W
    XORLW   0x4F            ; 0x4F = '3'
    BTFSC   STATUS, 2
    RETLW   3
    
    ; Check for 4
    MOVF    TEMP_CALC, W
    XORLW   0x66            ; 0x66 = '4'
    BTFSC   STATUS, 2
    RETLW   4
    
    ; Check for 5
    MOVF    TEMP_CALC, W
    XORLW   0x6D            ; 0x6D = '5'
    BTFSC   STATUS, 2
    RETLW   5
    
    ; Check for 6
    MOVF    TEMP_CALC, W
    XORLW   0x7D            ; 0x7D = '6'
    BTFSC   STATUS, 2
    RETLW   6
    
    ; Check for 7
    MOVF    TEMP_CALC, W
    XORLW   0x07            ; 0x07 = '7'
    BTFSC   STATUS, 2
    RETLW   7
    
    ; Check for 8
    MOVF    TEMP_CALC, W
    XORLW   0x7F            ; 0x7F = '8'
    BTFSC   STATUS, 2
    RETLW   8
    
    ; Check for 9
    MOVF    TEMP_CALC, W
    XORLW   0x6F            ; 0x6F = '9'
    BTFSC   STATUS, 2
    RETLW   9
    
    ; Not a digit
    RETLW   0xFF

; --- INIT ---
INIT_SYSTEM:
    BANKSEL TRISA
    MOVLW   0x06
    MOVWF   ADCON1
    MOVLW   0x01
    MOVWF   TRISA
    MOVLW   0x0F
    MOVWF   TRISB
    BCF     OPTION_REG, 7
    CLRF    TRISD
    CLRF    TRISE
    BANKSEL PORTA
    CLRF    PORTA
    CLRF    PORTD
    MOVLW   0xF0
    MOVWF   PORTB
    BSF     PORTA, 5
    RETURN

; --- KEYPAD INIT (Stub for main compatibility) ---
INIT_Keypad:
    ; Keypad already initialized in INIT_SYSTEM
    RETURN

; --- KEYPAD INTERRUPT HANDLER (Stub for main compatibility) ---
Keypad_Interrupt_Handler:
    ; Handle interrupt if needed
    RETURN

; --- SCAN ---
SCAN_KEYPAD:
    BANKSEL PORTB
    
    ; Col 1
    MOVLW   0xE0
    MOVWF   PORTB
    CALL    DELAY_SCAN
    BTFSS   PORTB, 0
    RETLW   0x06            ; 1
    BTFSS   PORTB, 1
    RETLW   0x66            ; 4
    BTFSS   PORTB, 2
    RETLW   0x07            ; 7
    BTFSS   PORTB, 3
    RETLW   0x80            ; * (.)
    
    ; Col 2
    MOVLW   0xD0
    MOVWF   PORTB
    CALL    DELAY_SCAN
    BTFSS   PORTB, 0
    RETLW   0x5B            ; 2
    BTFSS   PORTB, 1
    RETLW   0x6D            ; 5
    BTFSS   PORTB, 2
    RETLW   0x7F            ; 8
    BTFSS   PORTB, 3
    RETLW   0x3F            ; 0
    
    ; Col 3
    MOVLW   0xB0
    MOVWF   PORTB
    CALL    DELAY_SCAN
    BTFSS   PORTB, 0
    RETLW   0x4F            ; 3
    BTFSS   PORTB, 1
    RETLW   0x7D            ; 6
    BTFSS   PORTB, 2
    RETLW   0x6F            ; 9
    BTFSS   PORTB, 3
    RETLW   0x71            ; # (ENTER)
    
    ; Col 4
    MOVLW   0x70
    MOVWF   PORTB
    CALL    DELAY_SCAN
    BTFSS   PORTB, 0
    RETLW   0x77            ; A
    BTFSS   PORTB, 1
    RETLW   0x7C            ; B
    BTFSS   PORTB, 2
    RETLW   0x39            ; C
    BTFSS   PORTB, 3
    RETLW   0x5E            ; D

    MOVLW   0xF0
    MOVWF   PORTB
    RETLW   0x00

; --- DELAYS ---
DELAY_SCAN:
    MOVLW   0x10
    MOVWF   DELAY_VAR
S_LOOP: 
    DECFSZ  DELAY_VAR, F
    GOTO    S_LOOP
    RETURN

DELAY_MS:
    MOVLW   0xFF
    MOVWF   DELAY_VAR
M_LOOP: 
    DECFSZ  DELAY_VAR, F
    GOTO    M_LOOP
    RETURN

DELAY_LONG:
    MOVLW   0xFF
    MOVWF   DELAY_VAR2
LONG_OUTER:
    MOVLW   0xFF
    MOVWF   DELAY_VAR
LONG_INNER:
    NOP
    NOP
    NOP
    NOP
    DECFSZ  DELAY_VAR, F
    GOTO    LONG_INNER
    DECFSZ  DELAY_VAR2, F
    GOTO    LONG_OUTER
    
    MOVLW   0xFF
    MOVWF   DELAY_VAR2
LONG_OUTER2:
    MOVLW   0xFF
    MOVWF   DELAY_VAR
LONG_INNER2:
    NOP
    NOP
    NOP
    NOP
    DECFSZ  DELAY_VAR, F
    GOTO    LONG_INNER2
    DECFSZ  DELAY_VAR2, F
    GOTO    LONG_OUTER2
    RETURN
