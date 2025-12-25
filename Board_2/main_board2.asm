; ======================================================
; FILE: main_board2.asm
; BOARD #2 ? BMP180 + LCD (I2C)
; ======================================================

    PROCESSOR 16F877A
    #include <xc.inc>

CONFIG  FOSC=XT, WDTE=OFF, PWRTE=ON, BOREN=OFF, LVP=OFF, CPD=OFF, WRT=OFF, CP=OFF

    PSECT udata_bank0
BMP_Temp_H:     DS 1
BMP_Temp_L:     DS 1
BMP_Press_H:    DS 1
BMP_Press_L:    DS 1
LCD_STATE:      DS 1
LCD_TEMP:       DS 1
LCD_PRESS:      DS 1
d1_count:       DS 1
d2_count:       DS 1
LCD_TMP:        DS 1
W_TEMP:         DS 1
STATUS_TEMP:    DS 1
PCLATH_TEMP:    DS 1

    PSECT resetVec, class=CODE, delta=2
    ORG 0x00
    goto MAIN

    PSECT intVec, class=CODE, delta=2
    ORG 0x04
ISR:
    movwf   W_TEMP
    swapf   STATUS, W
    movwf   STATUS_TEMP
    movf    PCLATH, W
    movwf   PCLATH_TEMP
ISR_End:
    movf    PCLATH_TEMP, W
    movwf   PCLATH
    swapf   STATUS_TEMP, W
    movwf   STATUS
    swapf   W_TEMP, F
    swapf   W_TEMP, W
    retfie

    PSECT code
MAIN:
    BANKSEL TRISC
    movlw   0b00011000
    movwf   TRISC
    BANKSEL TRISD
    clrf    TRISD
    BANKSEL TRISB
    bcf     TRISB, 4
    bcf     TRISB, 5
    
    BANKSEL PORTD
    clrf PORTD
    BANKSEL PORTB
    clrf PORTB

    call INIT_I2C
    call LCD_Init

MAIN_LOOP:
    call BMP180_Read_Temp
    call BMP180_Read_Press
    call LCD_Init
    call UART_PROCESS_B2
    movlw 'T'
    call LCD_WriteChar
    movlw ':'
    call LCD_WriteChar
    goto MAIN_LOOP

#include "bmp180_i2c.asm"
#include "lcd_control.asm"

END


