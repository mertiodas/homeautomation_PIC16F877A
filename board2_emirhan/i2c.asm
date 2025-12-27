; ============================================
; i2c.asm - Board 2 I2C Master Driver
; ============================================

I2C_INIT:
    BSF     STATUS, 5       ; Bank 1
    BSF     TRISC, 3        ; SCL giri?i
    BSF     TRISC, 4        ; SDA giri?i
    MOVLW   0x80        
    MOVWF   SSPSTAT         ; SMP=1
    CLRF    SSPCON2
    MOVLW   9
    MOVWF   SSPADD          ; SCL = 100kHz
    BCF     STATUS, 5       ; Bank 0
    MOVLW   0x28
    MOVWF   SSPCON          ; I2C Master mode 
    RETURN

I2C_WAIT:
    BSF     STATUS, 5       ; Bank 1
WAIT_RW:
    BTFSC   SSPSTAT, 2      ; R/W kontrolü
    GOTO    WAIT_RW
    MOVF    SSPCON2, W      
    ANDLW   0x1F
    BTFSS   STATUS, 2       ; Zero bit kontrolü
    GOTO    WAIT_RW
    BCF     STATUS, 5       ; Bank 0
    RETURN

I2C_START:
    CALL    I2C_WAIT
    BSF     STATUS, 5
    BSF     SSPCON2, 0      ; SEN=1 START
    BCF     STATUS, 5
    RETURN

I2C_RESTART:
    CALL    I2C_WAIT
    BSF     STATUS, 5
    BSF     SSPCON2, 1      ; RSEN=1 Repeated START
    BCF     STATUS, 5
    RETURN

I2C_STOP:
    CALL    I2C_WAIT
    BSF     STATUS, 5
    BSF     SSPCON2, 2      ; PEN=1 STOP
    BCF     STATUS, 5
    RETURN

I2C_WRITE:
    CALL    I2C_WAIT
    MOVWF   SSPBUF
    CALL    I2C_WAIT
    BSF     STATUS, 5
    BTFSC   SSPCON2, 6      ; ACKSTAT kontrolü
    GOTO    WRITE_NACK
    BCF     STATUS, 0       ; ACK al?nd? (Carry=0)
    GOTO    WRITE_EXIT
WRITE_NACK:
    BSF     STATUS, 0       ; NACK al?nd? (Carry=1)
WRITE_EXIT:
    BCF     STATUS, 5
    RETURN
    
I2C_READ:
    MOVWF   TEMP_WORK
    CALL    I2C_WAIT
    BSF     STATUS, 5
    BSF     SSPCON2, 3      ; RCEN=1
    BCF     STATUS, 5
    CALL    I2C_WAIT
    MOVF    SSPBUF, W
    MOVWF   UART_TX_BYTE
    CALL    I2C_WAIT
    BSF     STATUS, 5
    BTFSC   TEMP_WORK, 0    ; ACK/NACK seçimi
    GOTO    SEND_NAK_BIT
    BCF     SSPCON2, 5      ; ACK gönder
    GOTO    START_ACK
SEND_NAK_BIT:
    BSF     SSPCON2, 5      ; NACK gönder
START_ACK:
    BSF     SSPCON2, 4      ; ACKEN=1
    BCF     STATUS, 5
    MOVF    UART_TX_BYTE, W
    RETURN