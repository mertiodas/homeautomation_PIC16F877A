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
        ; --- Set UART pins ---
        BANKSEL TRISC
        BSF     TRISC, 7          ; RC7 = RX (input)
        BCF     TRISC, 6          ; RC6 = TX (output)

        ; --- Baud rate: 9600 @ 4MHz ---
        BANKSEL SPBRG
        MOVLW   25
        MOVWF   SPBRG

        ; --- Transmit control ---
        BANKSEL TXSTA
        MOVLW   0x24              ; BRGH=1, TXEN=1
        MOVWF   TXSTA

        ; --- Receive control ---
        BANKSEL RCSTA
        MOVLW   0x90              ; SPEN=1, CREN=1
        MOVWF   RCSTA

                ; --- UART recovery / flush ---
        BANKSEL RCSTA
        BCF     RCSTA, 4          ; CREN = 0
        BSF     RCSTA, 4          ; CREN = 1

        BANKSEL RCREG
        MOVF    RCREG, W          ; flush garbage

        ; --- CLEAR RX INTERRUPT FLAG (IMPORTANT) ---
        BANKSEL PIR1
        BCF     PIR1, PIR1_RCIF_POSITION

        ; --- ENABLE UART RX INTERRUPT ---
        BANKSEL PIE1
        BSF     PIE1, PIE1_RCIE_POSITION

        ; --- ENABLE GLOBAL INTERRUPTS ---
        BANKSEL INTCON
        BSF     INTCON, INTCON_PEIE_POSITION
        BSF     INTCON, INTCON_GIE_POSITION

        RETURN



; --------------------------------------------------
; UART RX ISR
; --------------------------------------------------
UART_RX_ISR:
    BANKSEL RCSTA
    BTFSC RCSTA, 1        ; OERR?
    CALL UART_CLEAR_OERR

    BANKSEL RCREG
    MOVF RCREG, W         ; READ RX BYTE (clears RCIF)

    BANKSEL UART_RX_Byte
    MOVWF UART_RX_Byte    ; STORE BYTE

    MOVLW 1
    MOVWF UART_Flag       ; SET FLAG

    BANKSEL PORTE
    BSF PORTE, 0          ; LED ON = RX CONFIRMED

    ; --- IMMEDIATE RESPONSE ---
    CALL UART_Process     ; sends correct byte back to Python

    RETURN



UART_CLEAR_OERR:
        BANKSEL RCSTA
        BCF     RCSTA, 4        ; CREN = 0
        BSF     RCSTA, 4        ; CREN = 1
        BANKSEL RCREG
        MOVF    RCREG, W        ; flush
        RETURN




; --------------------------------------------------
; UART PROCESS
; --------------------------------------------------
UART_Process:
    BANKSEL UART_Flag
    MOVF UART_Flag,W
    BTFSC STATUS,2
    RETURN
    CLRF UART_Flag

    BANKSEL UART_RX_Byte
    MOVF UART_RX_Byte,W

    ; Command handling
    XORLW 0x01
    BTFSC STATUS,2
    GOTO SEND_DES_LOW

    XORLW 0x02
    BTFSC STATUS,2
    GOTO SEND_DES_HIGH

    XORLW 0x03
    BTFSC STATUS,2
    GOTO SEND_AMB_FRAC

    XORLW 0x04
    BTFSC STATUS,2
    GOTO SEND_AMB_INT

    XORLW 0x05
    BTFSC STATUS,2
    GOTO SEND_FAN_SPEED

    ; --- Unknown command fallback: echo received byte ---
    MOVF UART_RX_Byte,W
    CALL UART_Send_Char
    RETURN



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
        BANKSEL DesiredTemp_FRAC    ; Changed from _Low to match logic
        MOVF    DesiredTemp_FRAC, W
        CALL    UART_Send_Char
        RETURN

SEND_DES_HIGH:
        BANKSEL DesiredTemp_INT     ; Changed from _High to match SET logic
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

; --- YARDIMCI TX FONKSÄ°YONLARI ---

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
        SUBWF   0x70, W     ; W = DeÄ?er - 10
        BTFSS   STATUS, 0   ; BorÃ§ (Carry) var mÄ±? (DeÄ?er < 10 mu?)
        GOTO    PRINT_DIGITS
        MOVWF   0x70        ; DeÄ?er = DeÄ?er - 10
        INCF    0x71, F     ; Onlar hanesini artÄ±r
        GOTO    DIV_LOOP
PRINT_DIGITS:
        MOVF    0x71, W
        ADDLW   0x30        ; ASCII yap
        CALL    UART_Send_Char
        MOVF    0x70, W
        ADDLW   0x30        ; ASCII yap
        CALL    UART_Send_Char
        RETURN