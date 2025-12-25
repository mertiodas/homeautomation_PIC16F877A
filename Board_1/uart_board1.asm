; ======================================================
; MODULE: uart_board1.asm
; UART RX/TX
; ======================================================

; --- Variables should be in main file or properly declared ---
; If not already declared in main, add:
;       PSECT udata_bank0
; UART_RX_Byte: DS 1
; UART_Flag:    DS 1

; --------------------------------------------------
; INIT UART (9600 baud @ 4MHz)
; --------------------------------------------------
INIT_UART:
        BANKSEL TRISC
        BSF     TRISC, 6    ; RX Giriş
        BCF     TRISC, 7    ; TX Çıkış
        BANKSEL TXSTA
        MOVLW   0x24        ; BRGH=1, TXEN=1
        MOVWF   TXSTA
        BANKSEL RCSTA
        MOVLW   0x90        ; SPEN=1, CREN=1
        MOVWF   RCSTA
        BANKSEL SPBRG
        MOVLW   25          ; 9600 Baud
        MOVWF   SPBRG
        BANKSEL PIE1
        BSF     PIE1, 5     ; RCIE aktif
        RETURN

; --------------------------------------------------
; UART RX ISR
; --------------------------------------------------
UART_RX_ISR:
        BANKSEL RCREG
        MOVF    RCREG, W
        BANKSEL UART_RX_Byte
        MOVWF   UART_RX_Byte
        MOVLW   1
        MOVWF   UART_Flag
        RETURN

; --------------------------------------------------
; UART PROCESS
; --------------------------------------------------
UART_Process:
        BANKSEL UART_Flag
        MOVF    UART_Flag, W
        BTFSC   STATUS, 2
        RETURN              ; If 0, no data received
        CLRF    UART_Flag   ; Reset flag

        BANKSEL UART_RX_Byte
        MOVF    UART_RX_Byte, W

        ; --- STEP 1: Check for SET Commands (Bit 7 is 1) ---
        ; Matches 10xxxxxx (Frac) or 11xxxxxx (Int)
        BTFSC   UART_RX_Byte, 7
        GOTO    RECEIVE_DESIRED_TEMP

        ; --- STEP 2: Check for GET Commands (Binary) ---
        ; We check W against the specific codes in the table

        MOVF    UART_RX_Byte, W
        XORLW   0x03        ; Python asks for Ambient Low (Fractional)
        BTFSC   STATUS, 2
        GOTO    SEND_AMB_FRAC

        MOVF    UART_RX_Byte, W
        XORLW   0x04        ; Python asks for Ambient High (Integral)
        BTFSC   STATUS, 2
        GOTO    SEND_AMB_INT

        MOVF    UART_RX_Byte, W
        XORLW   0x05        ; Get Fan Speed (RPS)?
        BTFSC   STATUS, 2
        GOTO    SEND_FAN_SPEED

        RETURN              ; Unknown command, just exit


UART_HEATER:
        BANKSEL PORTE
        BSF     PORTE, 0    ; RE0 ON
        BCF     PORTE, 1    ; RE1 OFF
        RETURN

UART_COOLER:
        BANKSEL PORTE
        BSF     PORTE, 1    ; RE1 ON
        BCF     PORTE, 0    ; RE0 OFF
        RETURN

UART_OFF:
        BANKSEL PORTE
        BCF     PORTE, 0    ; RE0 OFF
        BCF     PORTE, 1    ; RE1 OFF
        RETURN

SEND_DES_LOW:
        BANKSEL DesiredTemp_FRAC    ; Changed from _Low to match your SET logic
        MOVF    DesiredTemp_FRAC, W
        CALL    UART_Send_Char
        RETURN

SEND_DES_HIGH:
        BANKSEL DesiredTemp_INT     ; Changed from _High to match your SET logic
        MOVF    DesiredTemp_INT, W
        CALL    UART_Send_Char
        RETURN

SEND_AMB_INT:
        BANKSEL AmbientTemp_INT
        MOVF    AmbientTemp_INT, W
        CALL    UART_Send_Char
        RETURN

SEND_AMB_FRAC:
        BANKSEL AmbientTemp_FRAC
        MOVF    AmbientTemp_FRAC, W
        CALL    UART_Send_Char
        RETURN

SEND_FAN_SPEED:
        BANKSEL FanSpeed_RPS
        MOVF    FanSpeed_RPS, W
        CALL    UART_Send_Char
        RETURN

; --- SET FUNCTIONS (Receiving from Python) ---

RECEIVE_DESIRED_TEMP:
        ; Note: UART_RX_Byte should be in W before calling this or
        ; you can MOVF UART_RX_Byte, W here to be safe.
        BTFSC   UART_RX_Byte, 6
        GOTO    SET_INT_VAL     ; If bits are 11xxxxxx
        GOTO    SET_FRAC_VAL    ; If bits are 10xxxxxx

SET_INT_VAL:
        MOVF    UART_RX_Byte, W
        ANDLW   0x3F            ; Mask bits 7 & 6, keep the 6-bit value
        BANKSEL DesiredTemp_INT
        MOVWF   DesiredTemp_INT
        RETURN

SET_FRAC_VAL:
        MOVF    UART_RX_Byte, W
        ANDLW   0x3F            ; Mask bits 7 & 6, keep the 6-bit value
        BANKSEL DesiredTemp_FRAC
        MOVWF   DesiredTemp_FRAC
        RETURN

; --- YARDIMCI TX FONKSİYONLARI ---

UART_Send_Char:
        BANKSEL TXSTA       ; Go to Bank 1
WAIT_TX:
        BTFSS   TXSTA, 1    ; Check TRMT bit (TSR empty?)
        GOTO    WAIT_TX
        BANKSEL TXREG       ; Go to Bank 0
        MOVWF   TXREG       ; Load the byte from W into TXREG
        RETURN
DIV_LOOP:
        MOVLW   10
        SUBWF   0x70, W     ; W = Değer - 10
        BTFSS   STATUS, 0   ; Borç (Carry) var mı? (Değer < 10 mu?)
        GOTO    PRINT_DIGITS
        MOVWF   0x70        ; Değer = Değer - 10
        INCF    0x71, F     ; Onlar hanesini artır
        GOTO    DIV_LOOP
PRINT_DIGITS:
        MOVF    0x71, W
        ADDLW   0x30        ; ASCII yap
        CALL    UART_Send_Char
        MOVF    0x70, W
        ADDLW   0x30        ; ASCII yap
        CALL    UART_Send_Char
        RETURN