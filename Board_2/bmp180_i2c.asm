; FILE: bmp180_i2c.asm
BMP180_ADDR_WRITE   EQU 0xEE
BMP180_ADDR_READ    EQU 0xEF
REG_CONTROL         EQU 0xF4
REG_OUT_MSB         EQU 0xF6
CMD_TEMP            EQU 0x2E
CMD_PRESSURE        EQU 0x34

INIT_I2C:
    BANKSEL SSPCON
    movlw   0x28
    movwf   SSPCON
    BANKSEL SSPADD
    movlw   0x09
    movwf   SSPADD
    BANKSEL SSPSTAT
    clrf    SSPSTAT
    BANKSEL SSPCON
    bsf     SSPCON, 5
    return

I2C_Wait:
    BANKSEL PIR1
wait_loop:
    btfss   PIR1, 3
    goto    wait_loop
    bcf     PIR1, 3
    return

I2C_Start:
    BANKSEL SSPCON2
    bsf     SSPCON2, 0
    call    I2C_Wait
    return

I2C_Stop:
    BANKSEL SSPCON2
    bsf     SSPCON2, 2
    call    I2C_Wait
    return

I2C_Write:
    BANKSEL SSPBUF
    movwf   SSPBUF
    call    I2C_Wait
    return

I2C_Read_ACK:
    BANKSEL SSPCON2
    bcf     SSPCON2, 5
    bsf     SSPCON2, 4
    call    I2C_Wait
    return

I2C_Read_NACK:
    BANKSEL SSPCON2
    bsf     SSPCON2, 5
    bsf     SSPCON2, 4
    call    I2C_Wait
    return

BMP180_Read_Temp:
    call I2C_Start
    movlw BMP180_ADDR_WRITE
    call I2C_Write
    movlw REG_CONTROL
    call I2C_Write
    movlw CMD_TEMP
    call I2C_Write
    call I2C_Stop
    call bmp_delay5ms
    call I2C_Start
    movlw BMP180_ADDR_WRITE
    call I2C_Write
    movlw REG_OUT_MSB
    call I2C_Write
    call I2C_Start
    movlw BMP180_ADDR_READ
    call I2C_Write
    BANKSEL SSPCON2
    bsf SSPCON2, 3
    call I2C_Wait
    BANKSEL SSPBUF
    movf SSPBUF, W
    BANKSEL BMP_Temp_H
    movwf BMP_Temp_H
    call I2C_Read_ACK
    BANKSEL SSPCON2
    bsf SSPCON2, 3
    call I2C_Wait
    BANKSEL SSPBUF
    movf SSPBUF, W
    BANKSEL BMP_Temp_L
    movwf BMP_Temp_L
    call I2C_Read_NACK
    call I2C_Stop
    return

BMP180_Read_Press:
    call I2C_Start
    movlw BMP180_ADDR_WRITE
    call I2C_Write
    movlw REG_CONTROL
    call I2C_Write
    movlw CMD_PRESSURE
    call I2C_Write
    call I2C_Stop
    call bmp_delay8ms
    call I2C_Start
    movlw BMP180_ADDR_WRITE
    call I2C_Write
    movlw REG_OUT_MSB
    call I2C_Write
    call I2C_Start
    movlw BMP180_ADDR_READ
    call I2C_Write
    BANKSEL SSPCON2
    bsf SSPCON2, 3
    call I2C_Wait
    BANKSEL SSPBUF
    movf SSPBUF, W
    BANKSEL BMP_Press_H
    movwf BMP_Press_H
    call I2C_Read_ACK
    BANKSEL SSPCON2
    bsf SSPCON2, 3
    call I2C_Wait
    BANKSEL SSPBUF
    movf SSPBUF, W
    BANKSEL BMP_Press_L
    movwf BMP_Press_L
    call I2C_Read_NACK
    call I2C_Stop
    return

bmp_delay5ms:
    BANKSEL d1_count
    movlw 200
    movwf d1_count
d1_loop:
    nop
    decfsz d1_count, F
    goto d1_loop
    return

bmp_delay8ms:
    BANKSEL d1_count
    movlw 255
    movwf d1_count
d2_loop:
    nop
    decfsz d1_count, F
    goto d2_loop
    return


