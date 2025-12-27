; ============================================
; bmp180.asm - Board 2 Sensor Driver
; ============================================

BMP180_ADDR_W   EQU 0xEE
BMP180_ADDR_R   EQU 0xEF

BMP180_INIT:
    CALL    I2C_INIT
    RETURN

READ_BMP180:
    ; --- S?cakl?k Okuma ---
    CALL    I2C_START
    MOVLW   BMP180_ADDR_W
    CALL    I2C_WRITE
    MOVLW   0xF4
    CALL    I2C_WRITE
    MOVLW   0x2E
    CALL    I2C_WRITE
    CALL    I2C_STOP

    MOVLW   5
    MOVWF   TEMP_WORK
BMP_DELAY_T:
    CALL    LCD_DELAY_MS
    DECFSZ  TEMP_WORK, F
    GOTO    BMP_DELAY_T

    CALL    I2C_START
    MOVLW   BMP180_ADDR_W
    CALL    I2C_WRITE
    MOVLW   0xF6
    CALL    I2C_WRITE
    CALL    I2C_RESTART
    MOVLW   BMP180_ADDR_R
    CALL    I2C_WRITE
    MOVLW   0
    CALL    I2C_READ
    MOVWF   OUTDOOR_TEMP_H
    MOVLW   1
    CALL    I2C_READ
    MOVWF   OUTDOOR_TEMP_L
    CALL    I2C_STOP

    ; --- Bas?nç Okuma ---
    CALL    I2C_START
    MOVLW   BMP180_ADDR_W
    CALL    I2C_WRITE
    MOVLW   0xF4
    CALL    I2C_WRITE
    MOVLW   0x34
    CALL    I2C_WRITE
    CALL    I2C_STOP

    MOVLW   5
    MOVWF   TEMP_WORK
BMP_DELAY_P:
    CALL    LCD_DELAY_MS
    DECFSZ  TEMP_WORK, F
    GOTO    BMP_DELAY_P

    CALL    I2C_START
    MOVLW   BMP180_ADDR_W
    CALL    I2C_WRITE
    MOVLW   0xF6
    CALL    I2C_WRITE
    CALL    I2C_RESTART
    MOVLW   BMP180_ADDR_R
    CALL    I2C_WRITE
    MOVLW   0
    CALL    I2C_READ
    MOVWF   OUTDOOR_PRESS_H
    MOVLW   1
    CALL    I2C_READ
    MOVWF   OUTDOOR_PRESS_L
    CALL    I2C_STOP

    RETURN