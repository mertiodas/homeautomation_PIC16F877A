; ======================================================
; MODULE: uart_board1.asm
; UART RX/TX + COMMAND PARSER
; ======================================================

        PSECT udata_bank0
UART_RX_Byte: DS 1
UART_Flag:    DS 1


; --------------------------------------------------
; INIT UART (9600 baud @ 4MHz)
; --------------------------------------------------
INIT_UART:
        BANKSEL TXSTA
        movlw b'00100100'
        movwf TXSTA

        BANKSEL RCSTA
        movlw b'10010000'
        movwf RCSTA

        BANKSEL SPBRG
        movlw 25
        movwf SPBRG

        BANKSEL PIE1
        bsf PIE1, PIE1_RCIE_POSITION
        return


; --------------------------------------------------
; UART RX ISR
; --------------------------------------------------
UART_RX_ISR:
        BANKSEL RCREG
        movf RCREG, W
        movwf UART_RX_Byte

        BANKSEL UART_Flag
        movlw 1
        movwf UART_Flag
        return


; --------------------------------------------------
; UART PROCESS (called in main loop)
; --------------------------------------------------
UART_Process:
        BANKSEL UART_Flag
        movf UART_Flag, W
        btfsc STATUS, STATUS_Z_POSITION
        return

        clrf UART_Flag

        BANKSEL UART_RX_Byte
        movf UART_RX_Byte, W

        xorlw 'H'
        btfsc STATUS, STATUS_Z_POSITION
        goto UART_HEATER

        movf UART_RX_Byte, W
        xorlw 'C'
        btfsc STATUS, STATUS_Z_POSITION
        goto UART_COOLER

        movf UART_RX_Byte, W
        xorlw 'O'
        btfsc STATUS, STATUS_Z_POSITION
        goto UART_OFF

        return


UART_HEATER:
        BANKSEL PORTE
        bsf PORTE,0
        bcf PORTE,1
        return

UART_COOLER:
        BANKSEL PORTE
        bsf PORTE,1
        bcf PORTE,0
        return

UART_OFF:
        BANKSEL PORTE
        bcf PORTE,0
        bcf PORTE,1
        return
