; FILE: lcd_control.asm
LCD_RS      EQU 4
LCD_EN      EQU 5

LCD_Enable_Pulse:
    BANKSEL PORTB
    bsf PORTB, LCD_EN
    call lcd_delay
    bcf PORTB, LCD_EN
    return

lcd_delay:
    BANKSEL d2_count
    movlw 40
    movwf d2_count
dly:
    decfsz d2_count, F
    goto dly
    return

LCD_Send4:
    BANKSEL LCD_TMP
    movwf LCD_TMP
    BANKSEL PORTD
    movf  PORTD, W
    andlw 0xF0
    movwf PORTD
    BANKSEL LCD_TMP
    movf  LCD_TMP, W
    andlw 0x0F
    BANKSEL PORTD
    iorwf PORTD, F
    call LCD_Enable_Pulse
    return

LCD_Command:
    BANKSEL PORTB
    bcf PORTB, LCD_RS
    goto LCD_Split

LCD_WriteChar:
    BANKSEL PORTB
    bsf PORTB, LCD_RS

LCD_Split:
    BANKSEL LCD_TMP
    movwf LCD_TMP
    swapf LCD_TMP, W
    andlw 0x0F
    call LCD_Send4
    BANKSEL LCD_TMP
    movf LCD_TMP, W
    andlw 0x0F
    call LCD_Send4
    return

LCD_Init:
    call lcd_delay
    call lcd_delay
    movlw 0x03
    call LCD_Send4
    call lcd_delay
    movlw 0x03
    call LCD_Send4
    call lcd_delay
    movlw 0x03
    call LCD_Send4
    call lcd_delay
    movlw 0x02
    call LCD_Send4
    movlw 0x28
    call LCD_Command
    movlw 0x0C
    call LCD_Command
    movlw 0x06
    call LCD_Command
    movlw 0x01
    call LCD_Command
    return


