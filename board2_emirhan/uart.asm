; ============================================
; uart.asm - Board 2 UART Driver & Command Parser
; Baud Rate: 9600 @ 4MHz (SPBRG=25, BRGH=1)
; Handles Curtain, Temp, Pressure, Light commands.
; Author: Mert Cengiz, aka mertiodas
; ============================================

; --------------------------------------------
; UART_INIT
; Initializes UART module (9600, 8N1)
; --------------------------------------------
UART_INIT:
    ; --- Bank 1 Settings ---
    BSF     STATUS, 5       ; Select Bank 1

    ; SPBRG = 25 (9600 Baud)
    MOVLW   25
    MOVWF   SPBRG

    ; TXSTA: BRGH=1, SYNC=0, TXEN=1
    MOVLW   0b00100100
    MOVWF   TXSTA

    ; --- Bank 0 Settings ---
    BCF     STATUS, 5       ; Select Bank 0

    ; RCSTA: SPEN=1, CREN=1
    MOVLW   0b10010000
    MOVWF   RCSTA

    RETURN

; --------------------------------------------
; UART_TX_W
; Transmits W register to PC
; --------------------------------------------
UART_TX_W:
    BSF     STATUS, 5       ; Bank 1
TX_WAIT:
    BTFSS   TXSTA, 1        ; Check TRMT
    GOTO    TX_WAIT
    BCF     STATUS, 5       ; Bank 0
    MOVWF   TXREG
    RETURN

; --------------------------------------------
; UART_SERVICE
; Main polling loop for communication
; --------------------------------------------
UART_SERVICE:
    BTFSS PIR1,5        ; RCIF? No data
    RETURN

    ; Check for errors
    BTFSC RCSTA,1       ; OERR?
    GOTO UART_ERR_OERR
    BTFSC RCSTA,2       ; FERR?
    GOTO UART_ERR_FERR

    ; Read incoming byte
    MOVF RCREG,W
    MOVWF UART_RX_BYTE

    ; --- SET Commands ---
    ; 10xxxxxx = Fractional
    MOVF UART_RX_BYTE,W
    ANDLW 0xC0
    XORLW 0x80
    BTFSC STATUS,2
    GOTO CMD_SET_CURTAIN_LOW

    ; 11xxxxxx = Integral
    MOVF UART_RX_BYTE,W
    ANDLW 0xC0
    XORLW 0xC0
    BTFSC STATUS,2
    GOTO CMD_SET_CURTAIN_HIGH

    ; --- GET Commands ---
    MOVF UART_RX_BYTE,W
    XORLW 0x01
    BTFSC STATUS,2
    GOTO CMD_GET_CURTAIN_LOW

    MOVF UART_RX_BYTE,W
    XORLW 0x02
    BTFSC STATUS,2
    GOTO CMD_GET_CURTAIN_HIGH

    MOVF UART_RX_BYTE,W
    XORLW 0x03
    BTFSC STATUS,2
    GOTO CMD_GET_TEMP_LOW

    MOVF UART_RX_BYTE,W
    XORLW 0x04
    BTFSC STATUS,2
    GOTO CMD_GET_TEMP_HIGH

    MOVF UART_RX_BYTE,W
    XORLW 0x05
    BTFSC STATUS,2
    GOTO CMD_GET_PRESS_LOW

    MOVF UART_RX_BYTE,W
    XORLW 0x06
    BTFSC STATUS,2
    GOTO CMD_GET_PRESS_HIGH

    MOVF UART_RX_BYTE,W
    XORLW 0x07
    BTFSC STATUS,2
    GOTO CMD_GET_LIGHT_LOW

    MOVF UART_RX_BYTE,W
    XORLW 0x08
    BTFSC STATUS,2
    GOTO CMD_GET_LIGHT_HIGH

    RETURN

; --- Command Implementations ---

; SET Handlers
CMD_SET_CURTAIN_LOW:
    MOVF    UART_RX_BYTE, W
    ANDLW   0x3F            ; Mask data
    ; We need a variable for fractional part. 
    ; Assuming DES_CURTAIN_STATUS_L exists in main.asm
    MOVWF   DES_CURTAIN_STATUS_L 
    RETURN

CMD_SET_CURTAIN_HIGH:
    MOVF    UART_RX_BYTE, W
    ANDLW   0x3F
    MOVWF   DES_CURTAIN_STATUS ; Integer part
    RETURN

; GET Handlers (Response)
CMD_GET_CURTAIN_LOW:
    MOVLW   0               ; Currently 0 (Fractional not implemented yet)
    CALL    UART_TX_W
    RETURN

CMD_GET_CURTAIN_HIGH:
    MOVF    CURTAIN_STATUS, W
    CALL    UART_TX_W
    RETURN

CMD_GET_TEMP_LOW:
    MOVF    OUTDOOR_TEMP_L, W
    CALL    UART_TX_W
    RETURN

CMD_GET_TEMP_HIGH:
    MOVF    OUTDOOR_TEMP_H, W
    CALL    UART_TX_W
    RETURN

CMD_GET_PRESS_LOW:
    MOVF    OUTDOOR_PRESS_L, W
    CALL    UART_TX_W
    RETURN

CMD_GET_PRESS_HIGH:
    MOVF    OUTDOOR_PRESS_H, W
    CALL    UART_TX_W
    RETURN

CMD_GET_LIGHT_LOW:
    MOVF    LIGHT_INTENSITY_L, W
    CALL    UART_TX_W
    RETURN

CMD_GET_LIGHT_HIGH:
    MOVF    LIGHT_INTENSITY_H, W
    CALL    UART_TX_W
    RETURN

; --- Error Handlers ---
UART_ERR_OERR:
    BCF     RCSTA, 4
    BSF     RCSTA, 4
    RETURN

UART_ERR_FERR:
    MOVF    RCREG, W
    RETURN



    
    