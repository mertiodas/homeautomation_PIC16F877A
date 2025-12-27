; ===============================
; UART INITIALIZATION
; ===============================
UART_Init:
    banksel TRISC
    bcf     TRISC, 6       ; TX = Output
    bsf     TRISC, 7       ; RX = Input

    banksel TXSTA
    movlw   00100100B      ; BRGH=1, TXEN=1
    movwf   TXSTA

    banksel SPBRG
    movlw   25             ; 9600 baud @ 4MHz
    movwf   SPBRG

    banksel RCSTA
    movlw   10010000B      ; SPEN=1, CREN=1
    movwf   RCSTA

    banksel PIE1
    bsf     PIE1, RCIE     ; Enable RX Interrupt
    return

; ===============================
; UART SEND BYTE (Safe Version)
; ===============================
UART_Send:
    banksel PIR1
WAIT_TX:
    btfss   PIR1, TXIF     ; Wait for TX buffer to be empty
    goto    WAIT_TX
    banksel TXREG
    movwf   TXREG          ; Send W
    return

; ===============================
; UART PROCESS (BOARD 2)
; ===============================
UART_PROCESS_B2:
    banksel PIR1
    btfss   PIR1, RCIF     ; Data arrived?
    return

    banksel RCSTA
    btfsc   RCSTA, OERR    ; Overrun Error check
    goto    ERR_RESET_B2

    banksel RCREG
    movf    RCREG, W       ; Read byte
    banksel RX_TEMP
    movwf   RX_TEMP

    btfsc   RX_TEMP, 7     ; Bit7=1 -> SET, Bit7=0 -> GET
    goto    B2_SET_CMD
    goto    B2_GET_CMD

ERR_RESET_B2:
    bcf     RCSTA, CREN
    bsf     RCSTA, CREN
    return

; ===============================
; SET COMMANDS (1-Byte Method)
; ===============================
B2_SET_CMD:
    btfsc   RX_TEMP, 6     ; Bit6=1 -> INT, Bit6=0 -> FRAC
    goto    SET_CURTAIN_INT

SET_CURTAIN_FRAC:
    movf    RX_TEMP, W
    andlw   00111111B      ; Keep only the value bits (0-63)
    banksel Curtain_FRAC
    movwf   Curtain_FRAC
    return

SET_CURTAIN_INT:
    movf    RX_TEMP, W
    andlw   00111111B      ; Keep only the value bits (0-63)
    banksel Curtain_INT
    movwf   Curtain_INT
    return

; ===============================
; GET COMMANDS (Jump Table)
; ===============================
B2_GET_CMD:
    movf    RX_TEMP, W
    andlw   00001111B      ; Clean the command bits

    addwf   PCL, F
    goto    GET_IGNORE        ; 0: Ignore
    goto    GET_CURTAIN_FRAC  ; 1
    goto    GET_CURTAIN_INT   ; 2
    goto    GET_TEMP_L        ; 3
    goto    GET_TEMP_H        ; 4
    goto    GET_PRESS_L       ; 5
    goto    GET_PRESS_H       ; 6
    goto    GET_LIGHT_FRAC    ; 7
    goto    GET_LIGHT_INT     ; 8

GET_IGNORE:
    return

GET_CURTAIN_FRAC:
    banksel Curtain_FRAC
    movf    Curtain_FRAC, W
    call    UART_Send
    return

GET_CURTAIN_INT:
    banksel Curtain_INT
    movf Curtain_INT, W
    call UART_Send
    return

GET_TEMP_L:
    banksel BMP_Temp_L
    movf BMP_Temp_L, W
    call UART_Send
    return

GET_TEMP_H:
    banksel BMP_Temp_H
    movf BMP_Temp_H, W
    call UART_Send
    return

GET_PRESS_L:
    banksel BMP_Press_L
    movf BMP_Press_L, W
    call UART_Send
    return

GET_PRESS_H:
    banksel BMP_Press_H
    movf BMP_Press_H, W
    call UART_Send
    return

GET_LIGHT_FRAC:
    banksel Light_FRAC
    movf Light_FRAC, W
    call UART_Send
    return

GET_LIGHT_INT:
    banksel Light_INT
    movf Light_INT, W
    call UART_Send
    return
