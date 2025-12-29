; ======================================================
; MODULE: uart_board1.asm - 
; Author: Mert Cengiz aka mertiodas
; ======================================================

INIT_UART:
    BANKSEL SPBRG
    movlw   25              ; 9600 Baud @ 4MHz
    movwf   SPBRG
    BANKSEL TXSTA
    movlw   0x24            ; TXEN=1, BRGH=1
    movwf   TXSTA
    BANKSEL RCSTA
    movlw   0x90            ; SPEN=1, CREN=1
    movwf   RCSTA
    BANKSEL PORTA           ; Back to Bank 0
    return

UART_Process:
    BANKSEL PIR1
    btfss   PIR1, 5         ; Check RCIF (Did a byte arrive?)
    return                  

    BANKSEL RCREG
    movf    RCREG, W        ; Read byte from Python
    movwf   UART_Buf

    ; --- GETTERS (Python requests data) ---
    xorlw   0x01            ; Command 0x01 -> Get Desired INT
    btfsc   STATUS, 2
    goto    TX_Desired_Int

    movf    UART_Buf, W
    xorlw   0x02            ; Command 0x02 -> Get Desired FRAC
    btfsc   STATUS, 2
    goto    TX_Desired_Frac

    movf    UART_Buf, W
    xorlw   0x03            ; Command 0x03 -> Get Ambient INT
    btfsc   STATUS, 2
    goto    TX_Ambient_Int

    movf    UART_Buf, W
    xorlw   0x04            ; Command 0x04 -> Get Ambient FRAC
    btfsc   STATUS, 2
    goto    TX_Ambient_Frac

    ; --- SETTERS (Python sends data) ---
    movf    UART_Buf, W
    xorlw   0x80            ; Command 0x80 -> Set Desired INT
    btfsc   STATUS, 2
    goto    RX_Set_Desired_Int

    movf    UART_Buf, W
    xorlw   0x81            ; Command 0x81 -> Set Desired FRAC
    btfsc   STATUS, 2
    goto    RX_Set_Desired_Frac
    
    return

; --- TRANSMIT SUBROUTINES ---
TX_Desired_Int:
    movf    DesiredTemp_INT, W
    goto    UART_TX_Send

TX_Desired_Frac:
    movf    DesiredTemp_FRAC, W
    goto    UART_TX_Send

TX_Ambient_Int:
    movf    AmbientTemp_INT, W
    goto    UART_TX_Send

TX_Ambient_Frac:
    movf    AmbientTemp_FRAC, W
    goto    UART_TX_Send

UART_TX_Send:
    BANKSEL TXSTA
_tx_wait:
    btfss   TXSTA, 1        ; Wait for TRMT (Shift Register Empty)
    goto    _tx_wait
    BANKSEL TXREG
    movwf   TXREG           ; Transmit
    return

; --- RECEIVE SUBROUTINES ---
RX_Set_Desired_Int:
    call    Wait_For_Byte
    movwf   DesiredTemp_INT
    return

RX_Set_Desired_Frac:
    call    Wait_For_Byte
    movwf   DesiredTemp_FRAC
    return

Wait_For_Byte:
    ; Check for Overrun/Framing Errors
    BANKSEL RCSTA
    btfss   RCSTA, 1        ; OERR bit
    goto    _no_err
    bcf     RCSTA, 4        ; Clear CREN to reset error
    bsf     RCSTA, 4        ; Re-enable CREN
_no_err:
    BANKSEL PIR1
_w_byte:
    btfss   PIR1, 5         ; Wait for next byte in sequence
    goto    _w_byte
    BANKSEL RCREG
    movf    RCREG, W        ; Return the value in W
    return