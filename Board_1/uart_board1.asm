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
    ; --- Step 1: Set Pins (Bank 1) ---
    BANKSEL TRISC
    BCF     TRISC, 6    ; TX Output
    BSF     TRISC, 7    ; RX Input

    ; --- Step 2: Set Baud Rate (Bank 1) ---
    BANKSEL SPBRG
    MOVLW   25          ; 9600 Baud @ 4MHz
    MOVWF   SPBRG

    ; --- Step 3: Set TX Status (Bank 1) ---
    MOVLW   0x24        ; TXEN=1, BRGH=1
    MOVWF   TXSTA

    ; --- Step 4: Set RX Status (Bank 0) ---
    BANKSEL RCSTA
    MOVLW   0x90        ; SPEN=1, CREN=1
    MOVWF   RCSTA

    ; --- Step 5: Enable Interrupts (Bank 1) ---
    BANKSEL PIE1
    BSF     PIE1, RCIE  ; Enable Receive Interrupt

    BANKSEL 0           ; Always return to Bank 0
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
        RETURN
        CLRF    UART_Flag

        ; SET commands
        BTFSC   UART_RX_Byte, 7
        GOTO    RECEIVE_DESIRED_TEMP

        ; GET desired temp low
        MOVF    UART_RX_Byte, W
        XORLW   0x01
        BTFSC   STATUS, 2
        GOTO    SEND_DES_LOW

        ; GET desired temp high
        MOVF    UART_RX_Byte, W
        XORLW   0x02
        BTFSC   STATUS, 2
        GOTO    SEND_DES_HIGH

        ; GET ambient temp low
        MOVF    UART_RX_Byte, W
        XORLW   0x03
        BTFSC   STATUS, 2
        GOTO    SEND_AMB_FRAC

        ; GET ambient temp high
        MOVF    UART_RX_Byte, W
        XORLW   0x04
        BTFSC   STATUS, 2
        GOTO    SEND_AMB_INT

        ; GET fan speed
        MOVF    UART_RX_Byte, W
        XORLW   0x05
        BTFSC   STATUS, 2
        GOTO    SEND_FAN_SPEED

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