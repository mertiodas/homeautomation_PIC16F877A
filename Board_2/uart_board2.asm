; ===========================================================================
; UART MODULE FOR BOARD 2 - UPDATED FOR BMP180 VARIABLE NAMES
; Handled Commands: 0x01 to 0x08 (GET) and 0x80+ (SET)
; ===========================================================================

UART_PROCESS_B2:
    banksel PIR1
    btfss PIR1, 5           ; Check RCIF (Data in RCREG?)
    return                  ; If no data, exit

    movf RCREG, W           ; Load received byte
    banksel RX_TEMP
    movwf RX_TEMP           ; Store in temporary variable

    ; --- STEP 1: Identify Command Type (SET vs GET) ---
    btfsc RX_TEMP, 7        ; If Bit 7 is 1, it's a "SET" command
    goto B2_SET_LOGIC

    ; --- STEP 2: GET COMMAND LOGIC ---
B2_GET_LOGIC:
    ; Compare with 0x01 (Get Curtain Frac)
    movlw 00000001B
    subwf RX_TEMP, W
    btfsc STATUS, 2
    goto B2_SEND_CURT_FRAC

    ; Compare with 0x02 (Get Curtain Int)
    movlw 00000010B
    subwf RX_TEMP, W
    btfsc STATUS, 2
    goto B2_SEND_CURT_INT

    ; Compare with 0x03 (Get OutTemp Frac)
    movlw 00000011B
    subwf RX_TEMP, W
    btfsc STATUS, 2
    goto B2_SEND_OT_FRAC

    ; Compare with 0x04 (Get OutTemp Int)
    movlw 00000100B
    subwf RX_TEMP, W
    btfsc STATUS, 2
    goto B2_SEND_OT_INT

    ; Compare with 0x05 (Get Pressure Frac)
    movlw 00000101B
    subwf RX_TEMP, W
    btfsc STATUS, 2
    goto B2_SEND_PR_FRAC

    ; Compare with 0x06 (Get Pressure Int)
    movlw 00000110B
    subwf RX_TEMP, W
    btfsc STATUS, 2
    goto B2_SEND_PR_INT

    ; Compare with 0x07 (Get Light Frac)
    movlw 00000111B
    subwf RX_TEMP, W
    btfsc STATUS, 2
    goto B2_SEND_LI_FRAC

    ; Compare with 0x08 (Get Light Int)
    movlw 00001000B
    subwf RX_TEMP, W
    btfsc STATUS, 2
    goto B2_SEND_LI_INT

    return

    ; --- STEP 3: SET COMMAND LOGIC ---
B2_SET_LOGIC:
    movf RX_TEMP, W
    andlw 11000000B
    xorlw 10000000B         ; Check if "10" (Set Frac)
    btfsc STATUS, 2
    goto B2_DO_SET_FRAC

    movf RX_TEMP, W
    andlw 11000000B
    xorlw 11000000B         ; Check if "11" (Set Int)
    btfsc STATUS, 2
    goto B2_DO_SET_INT
    return

    ; --- EXECUTION SUBROUTINES (MAPPED TO YOUR VARIABLES) ---

B2_SEND_CURT_FRAC: movf Curtain_FRAC, W  | goto B2_TX
B2_SEND_CURT_INT:  movf Curtain_INT, W   | goto B2_TX
B2_SEND_OT_FRAC:   movf BMP_Temp_L, W    | goto B2_TX ; Mapped to BMP180 Temp Low
B2_SEND_OT_INT:    movf BMP_Temp_H, W    | goto B2_TX ; Mapped to BMP180 Temp High
B2_SEND_PR_FRAC:   movf BMP_Press_L, W   | goto B2_TX ; Mapped to BMP180 Press Low
B2_SEND_PR_INT:    movf BMP_Press_H, W   | goto B2_TX ; Mapped to BMP180 Press High
B2_SEND_LI_FRAC:   movf Light_FRAC, W    | goto B2_TX
B2_SEND_LI_INT:    movf Light_INT, W     | goto B2_TX

B2_TX:
    banksel TXREG
    movwf TXREG
    banksel TXSTA
    btfss TXSTA, 1          ; Wait for TRMT (bit 1)
    goto $-1
    return

B2_DO_SET_FRAC:
    banksel RX_TEMP
    movf RX_TEMP, W
    andlw 00111111B
    movwf Curtain_FRAC
    return

B2_DO_SET_INT:
    banksel RX_TEMP
    movf RX_TEMP, W
    andlw 00111111B
    movwf Curtain_INT
    return