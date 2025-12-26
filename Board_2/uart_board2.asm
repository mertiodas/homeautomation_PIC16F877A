PSECT code

; ===============================
; UART INITIALIZATION
; ===============================
UART_Init:
    banksel TXSTA
    movlw   00100100B      ; BRGH=1, TXEN=1
    movwf   TXSTA

    banksel RCSTA
    movlw   10010000B      ; SPEN=1, CREN=1
    movwf   RCSTA

    banksel SPBRG
    movlw   25             ; 9600 baud @ 4MHz
    movwf   SPBRG
    return


; ===============================
; UART SEND BYTE
; ===============================
UART_Send:
    banksel PIR1
WAIT_TX:
    btfss   PIR1, 4        ; TXIF
    goto    WAIT_TX
    banksel TXREG
    movwf   TXREG
    return


; ===============================
; UART PROCESS (BOARD 2)
; ===============================
UART_PROCESS_B2:
    banksel PIR1
    btfss   PIR1, 5        ; RCIF?
    return

    banksel RCREG
    movf    RCREG, W
    banksel RX_TEMP
    movwf   RX_TEMP

    btfsc   RX_TEMP, 7     ; bit7=1 → SET
    goto    B2_SET_CMD

    goto    B2_GET_CMD


; ===============================
; SET COMMANDS
; ===============================
B2_SET_CMD:
    btfsc   RX_TEMP, 6     ; bit6=1 → INT
    goto    SET_CURTAIN_INT

SET_CURTAIN_FRAC:
    movf    RX_TEMP, W
    andlw   00111111B
    banksel Curtain_FRAC
    movwf   Curtain_FRAC
    return

SET_CURTAIN_INT:
    movf    RX_TEMP, W
    andlw   00111111B
    banksel Curtain_INT
    movwf   Curtain_INT
    return


; ===============================
; GET COMMANDS
; ===============================
B2_GET_CMD:
    movf RX_TEMP, W
    andlw 00001111B

    addwf PCL, F

    goto GET_CURTAIN_FRAC     ; 0001
    goto GET_CURTAIN_INT      ; 0010
    goto GET_TEMP_L           ; 0011
    goto GET_TEMP_H           ; 0100
    goto GET_PRESS_L          ; 0101
    goto GET_PRESS_H          ; 0110
    goto GET_LIGHT_FRAC       ; 0111
    goto GET_LIGHT_INT        ; 1000


GET_CURTAIN_FRAC:
    banksel Curtain_FRAC
    movf Curtain_FRAC, W
    call UART_Send
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
