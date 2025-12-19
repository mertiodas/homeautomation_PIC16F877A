;=============================================================================
; FILE: keypad_final_WORKING_v2.asm
; AUTHOR: Hilal Ongör (Final Düzeltilmi? Versiyon)
;
; KURAL SET?:
; 10 <= Say? <= 50 -> P (Pass)
; Di?erleri -> r (Reject)
;
; ÖZEL DURUMLAR:
; 50 (#) -> P (Pass) - (KES?N ÇÖZÜM EKLEND?)
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
    CONFIG BOREN = ON
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

    ; --- RESET VECTOR ---
    PSECT resetVec, class=CODE, delta=2
resetVec:
    PAGESEL START
    GOTO    START

    ; --- CODE SECTION ---
    PSECT code

START:
    CALL    INIT_SYSTEM
    
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

MAIN_LOOP:
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
    ; ?lk rakam? kaydet
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
    ; Enter kontrolü - Tek basamak durumu
    BANKSEL LAST_KEY
    MOVF    LAST_KEY, W
    SUBLW   0x71            ; '#' (Enter)
    BTFSC   STATUS, 2
    GOTO    HANDLE_SINGLE_DIGIT

    ; Rakam m??
    CALL    GET_NUMBER
    MOVWF   TEMP_CALC
    
    ; 0xFF m? kontrol et (rakam de?il)
    MOVF    TEMP_CALC, W
    XORLW   0xFF
    BTFSC   STATUS, 2
    GOTO    WAIT_RELEASE    ; Rakam de?il -> bekle

    ; Rakam? kaydet (0-9 aras?)
    MOVF    TEMP_CALC, W
    BANKSEL DIGIT2
    MOVWF   DIGIT2
    MOVLW   3
    MOVWF   STATE
    GOTO    WAIT_RELEASE

HANDLE_SINGLE_DIGIT:
    ; Kullan?c? tek rakam girdi (örn: 4 -> #)
    ; 0-4 -> r, 5-9 -> onu iki basamak yap (05-09)
    BANKSEL DIGIT1
    MOVF    DIGIT1, W
    
    ; 4'ten küçük veya e?it mi?
    SUBLW   4
    BTFSC   STATUS, 0       ; Carry=1 ise DIGIT1 <= 4
    GOTO    SHOW_FAIL
    
    ; 5-9 aras?, onu 05-09 yap
    MOVF    DIGIT1, W
    MOVWF   DIGIT2
    CLRF    DIGIT1
    GOTO    VALIDATION_LOGIC

TASK_CHECK_DOT_OR_ENTER:
    ; '#' kontrolü - Enter
    BANKSEL LAST_KEY
    MOVF    LAST_KEY, W
    SUBLW   0x71            ; '#' (Enter)
    BTFSC   STATUS, 2
    GOTO    VALIDATION_LOGIC
    
    ; '.' kontrolü
    MOVF    LAST_KEY, W
    SUBLW   0x80            ; '.' 
    BTFSS   STATUS, 2
    GOTO    WAIT_RELEASE
    
    ; Nokta bas?ld?
    BANKSEL HAS_DOT
    MOVLW   1
    MOVWF   HAS_DOT
    CLRF    DIGIT_FRAC

    MOVLW   4
    MOVWF   STATE
    GOTO    WAIT_RELEASE

TASK_SAVE_FRAC:
    ; Enter kontrolü - Nokta sonras? direkt Enter
    BANKSEL LAST_KEY
    MOVF    LAST_KEY, W
    SUBLW   0x71            ; '#' (Enter)
    BTFSC   STATUS, 2
    GOTO    VALIDATION_LOGIC ; Enter -> Validation'a git
    
    ; Rakam m? kontrol et
    CALL    GET_NUMBER
    MOVWF   TEMP_CALC
    XORLW   0xFF
    BTFSC   STATUS, 2
    GOTO    WAIT_RELEASE    ; Rakam de?il -> bekle

    ; Rakamsa kaydet
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
; VALIDATION LOGIC (DUZELTILMIS KISIM)
; ============================================================================
VALIDATION_LOGIC:
    ; 1. Ondal?k kontrol - Nokta varsa DIGIT_FRAC 0 olmal?
    BANKSEL HAS_DOT
    MOVF    HAS_DOT, W
    BTFSC   STATUS, 2
    GOTO    SKIP_FRAC_CHECK
    
    ; Nokta var, frac kontrol et
    BANKSEL DIGIT_FRAC
    MOVF    DIGIT_FRAC, W
    BTFSS   STATUS, 2        ; Z=1 ise (FRAC=0) atla
    GOTO    SHOW_FAIL        ; FRAC != 0 -> HATA (12.5 gibi)

SKIP_FRAC_CHECK:
    ; 2. DIGIT1 bazl? kontrol
    BANKSEL DIGIT1
    MOVF    DIGIT1, W
    
    ; DIGIT1 = 0? -> HATA (00-09)
    BTFSC   STATUS, 2
    GOTO    SHOW_FAIL
    
    ; DIGIT1 = 6,7,8,9 -> HATA
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
    
    ; DIGIT1 = 5? -> DIGIT2 kontrol et
    MOVF    DIGIT1, W
    XORLW   5
    BTFSC   STATUS, 2
    GOTO    CHECK_IF_50
    
    ; DIGIT1 = 1,2,3,4 -> PASS
    GOTO    SHOW_PASS

CHECK_IF_50:
    ; DIGIT1 5 ise buraya gelir.
    ; E?er DIGIT2 0 ise (50) -> PASS
    ; E?er DIGIT2 != 0 ise (51, 52...) -> FAIL
    
    BANKSEL DIGIT2
    MOVF    DIGIT2, W
    XORLW   0               ; W register 0 m?? (Yani DIGIT2 0 m??)
    BTFSS   STATUS, 2       ; Z=1 (E?it) ise PASS'a atla
    GOTO    SHOW_FAIL       ; Z=0 (E?it De?il) ise FAIL (51, 52...)
    
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
    GOTO    MAIN_LOOP

NO_KEY:
    GOTO    MAIN_LOOP

GET_NUMBER:
    BANKSEL TEMP_CALC
    MOVF    LAST_KEY, W
    MOVWF   TEMP_CALC
    
    ; 0 kontrolü
    MOVF    TEMP_CALC, W
    XORLW   0x3F            ; 0x3F = '0'
    BTFSC   STATUS, 2
    RETLW   0
    
    ; 1 kontrolü
    MOVF    TEMP_CALC, W
    XORLW   0x06            ; 0x06 = '1'
    BTFSC   STATUS, 2
    RETLW   1
    
    ; 2 kontrolü
    MOVF    TEMP_CALC, W
    XORLW   0x5B            ; 0x5B = '2'
    BTFSC   STATUS, 2
    RETLW   2
    
    ; 3 kontrolü
    MOVF    TEMP_CALC, W
    XORLW   0x4F            ; 0x4F = '3'
    BTFSC   STATUS, 2
    RETLW   3
    
    ; 4 kontrolü
    MOVF    TEMP_CALC, W
    XORLW   0x66            ; 0x66 = '4'
    BTFSC   STATUS, 2
    RETLW   4
    
    ; 5 kontrolü
    MOVF    TEMP_CALC, W
    XORLW   0x6D            ; 0x6D = '5'
    BTFSC   STATUS, 2
    RETLW   5
    
    ; 6 kontrolü
    MOVF    TEMP_CALC, W
    XORLW   0x7D            ; 0x7D = '6'
    BTFSC   STATUS, 2
    RETLW   6
    
    ; 7 kontrolü
    MOVF    TEMP_CALC, W
    XORLW   0x07            ; 0x07 = '7'
    BTFSC   STATUS, 2
    RETLW   7
    
    ; 8 kontrolü
    MOVF    TEMP_CALC, W
    XORLW   0x7F            ; 0x7F = '8'
    BTFSC   STATUS, 2
    RETLW   8
    
    ; 9 kontrolü
    MOVF    TEMP_CALC, W
    XORLW   0x6F            ; 0x6F = '9'
    BTFSC   STATUS, 2
    RETLW   9
    
    ; Rakam de?il
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

    END resetVec
