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
    bsf     PIE1, 5        ; 5 is the bit position for RCIE in PIE1
    return

; ===============================
; UART SEND BYTE (Safe Version)
; ===============================
UART_Send:
    banksel PIR1
WAIT_TX:
    btfss   PIR1, 4        ; 4 is the bit position for TXIF in PIR1
    goto    WAIT_TX
    banksel TXREG
    movwf   TXREG          ; Send W
    return

; ===============================
; UART PROCESS (BOARD 2)
; ===============================
; ===============================
; UART PROCESS (BOARD 2)
; ===============================
UART_PROCESS_B2:
    banksel PIR1
    btfss   PIR1, 5        ; Use '5' instead of RCIF if it's giving errors
    return

    banksel RCSTA
    btfsc   RCSTA, 1       ; Use '1' instead of OERR
    goto    ERR_RESET_B2

    banksel RCREG
    movf    RCREG, W       ; Read received byte
    banksel RX_TEMP
    movwf   RX_TEMP

    ; Check Bit 7 (SET vs GET)
    btfsc   RX_TEMP, 7     
    goto    B2_SET_CMD
    goto    B2_GET_CMD

ERR_RESET_B2:
    banksel RCSTA
    bcf     RCSTA, 4       ; Use '4' instead of CREN to reset
    bsf     RCSTA, 4       ; Re-enable CREN
    return

; ===============================
; SET COMMANDS (1-Byte Method)
; ===============================
B2_SET_CMD:
    btfsc   RX_TEMP, 6     ; Check Bit 6
    goto    SET_CURTAIN_INT
    goto    SET_CURTAIN_FRAC

SET_CURTAIN_FRAC:
    movf    RX_TEMP, W
    andlw   0x3F           ; Same as 00111111B
    banksel Curtain_FRAC
    movwf   Curtain_FRAC
    return

SET_CURTAIN_INT:
    movf    RX_TEMP, W
    andlw   0x3F           ; Mask out command bits
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
