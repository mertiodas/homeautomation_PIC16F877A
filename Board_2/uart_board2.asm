; ===========================================================================
; UART MODULE FOR BOARD 2
; Handled Commands: 0x01 to 0x08 (GET) and 0x80+ (SET)
; ===========================================================================

UART_PROCESS_B2:
    btfss PIR1, 5           ; Check if data is actually in RCREG (RCIF)
    return                  ; If not, exit

    movf RCREG, W           ; Load received byte into W
    movwf RX_TEMP           ; Store in temporary variable

    ; --- STEP 1: Identify Command Type (SET vs GET) ---
    btfsc RX_TEMP, 7        ; If Bit 7 is 1, it's a "SET" command (10xxxxxx or 11xxxxxx)
    goto B2_SET_LOGIC

    ; --- STEP 2: GET COMMAND LOGIC (0000xxxx) ---
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

    return                  ; Unknown command

    ; --- STEP 3: SET COMMAND LOGIC (10c5-c0 or 11c5-c0) ---
B2_SET_LOGIC:
    ; Mask the top two bits to see if it is 10xxxxxx (Frac) or 11xxxxxx (Int)
    movf RX_TEMP, W
    andlw 11000000B         ; Keep only bit 7 and 6
    xorlw 10000000B         ; Check if it is "10"
    btfsc STATUS, 2
    goto B2_DO_SET_FRAC

    movf RX_TEMP, W
    andlw 11000000B
    xorlw 11000000B         ; Check if it is "11"
    btfsc STATUS, 2
    goto B2_DO_SET_INT
    return

    ; --- EXECUTION SUBROUTINES ---

B2_SEND_CURT_FRAC: movf Curtain_FRAC, W  | goto B2_TX
B2_SEND_CURT_INT:  movf Curtain_INT, W   | goto B2_TX
B2_SEND_OT_FRAC:   movf OutTemp_FRAC, W  | goto B2_TX
B2_SEND_OT_INT:    movf OutTemp_INT, W   | goto B2_TX
B2_SEND_PR_FRAC:   movf OutPress_FRAC, W | goto B2_TX
B2_SEND_PR_INT:    movf OutPress_INT, W  | goto B2_TX
B2_SEND_LI_FRAC:   movf Light_FRAC, W    | goto B2_TX
B2_SEND_LI_INT:    movf Light_INT, W     | goto B2_TX

B2_TX:
    movwf TXREG             ; Load data to transmit register
    btfss TXSTA, 1          ; Check TRMT (bit 1) - wait for shift register empty
    goto $-1
    return

B2_DO_SET_FRAC:
    movf RX_TEMP, W         ; Get the raw byte
    andlw 00111111B         ; MASK bit 7 and 6, keep the 6-bit data
    movwf Curtain_FRAC      ; Save to memory
    return

B2_DO_SET_INT:
    movf RX_TEMP, W         ; Get the raw byte
    andlw 00111111B         ; MASK bit 7 and 6, keep the 6-bit data
    movwf Curtain_INT       ; Save to memory
    return