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
        BANKSEL TXSTA
        MOVLW   0x24        ; 0b00100100
        MOVWF   TXSTA
        BANKSEL RCSTA
        MOVLW   0x90        ; 0b10010000
        MOVWF   RCSTA
        BANKSEL SPBRG
        MOVLW   25
        MOVWF   SPBRG
        BANKSEL PIE1
        BSF     PIE1, 5     ; RCIE bit position
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
; UART PROCESS (called in main)
; --------------------------------------------------
UART_Process:
        BANKSEL UART_Flag
        MOVF    UART_Flag, W
        BTFSC   STATUS, 2   ; Z bit
        RETURN
        CLRF    UART_Flag
        
        BANKSEL UART_RX_Byte
        MOVF    UART_RX_Byte, W
        XORLW   'H'
        BTFSC   STATUS, 2
        GOTO    UART_HEATER
        
        MOVF    UART_RX_Byte, W
        XORLW   'C'
        BTFSC   STATUS, 2
        GOTO    UART_COOLER
        
        MOVF    UART_RX_Byte, W
        XORLW   'O'
        BTFSC   STATUS, 2
        GOTO    UART_OFF
        RETURN

UART_HEATER:
        BANKSEL PORTE
        BSF     PORTE, 0
        BCF     PORTE, 1
        RETURN

UART_COOLER:
        BANKSEL PORTE
        BSF     PORTE, 1
        BCF     PORTE, 0
        RETURN

UART_OFF:
        BANKSEL PORTE
        BCF     PORTE, 0
        BCF     PORTE, 1
        RETURN