; ============================================
; lcd.asm - Board 2 LCD Driver (HD44780 4-bit)
; Pin Mapping:
;  RS -> RE0, E -> RE1
;  D4 -> RD4, D5 -> RD5, D6 -> RD6, D7 -> RD7
;  R/W -> GND
; ============================================

; --- Constants ---
LCD_CMD_CLEAR       EQU 0x01	;Clear the screen.
LCD_CMD_HOME        EQU 0x02	;Move the cursor to the "home" position.
LCD_CMD_ENTRY_MODE  EQU 0x06	;Entry mode: Move the cursor to the right after typing.
LCD_CMD_DISPLAY_ON  EQU 0x0C	;Display on, cursor off, blink off.
LCD_CMD_FUNCTION    EQU 0x28    ;4-bit interface, 2-lines, 5x7 font
LCD_CMD_SET_DDRAM   EQU 0x80	

; --- Variables (Defined in main.asm) ---
; OUTDOOR_TEMP_H, OUTDOOR_TEMP_L
; OUTDOOR_PRESS_H, OUTDOOR_PRESS_L
; CURTAIN_STATUS
; LIGHT_INTENSITY_H, LIGHT_INTENSITY_L

; --------------------------------------------
; LCD_INIT
; Initializes the LCD in 4-bit mode.
; --------------------------------------------
LCD_INIT:
    ; Wait for LCD power up (>15ms)
    CALL    LCD_DELAY_MS
    CALL    LCD_DELAY_MS

    ; --- Switch Bank 0 just in case ---
    BANKSEL PORTD

    ; --- Soft Reset Sequence (Magic sequence) ---
    BCF     PORTE, 0        ; RS = 0 (Command)
    
    ; Send 0x30 (Nibble)
    MOVLW   0x30
    MOVWF   PORTD
    CALL    LCD_PULSE_E
    CALL    LCD_DELAY_MS    ; Wait > 4.1ms

    ; Send 0x03 (Nibble)
    CALL    LCD_PULSE_E
    CALL    LCD_DELAY_US    ; Wait > 100us

    ; Send 0x03 (Nibble)
    CALL    LCD_PULSE_E
    CALL    LCD_DELAY_US

    ; Send 0x02 (Set 4-bit mode)
    MOVLW   0x20
    MOVWF   PORTD
    CALL    LCD_PULSE_E
    CALL    LCD_DELAY_US

    ; --- Configuration Commands ---
    MOVLW   LCD_CMD_FUNCTION
    CALL    LCD_SEND_CMD

    MOVLW   LCD_CMD_DISPLAY_ON
    CALL    LCD_SEND_CMD

    MOVLW   LCD_CMD_ENTRY_MODE
    CALL    LCD_SEND_CMD

    MOVLW   LCD_CMD_CLEAR
    CALL    LCD_SEND_CMD
    CALL    LCD_DELAY_MS    ; Clear takes long time

    RETURN

; --------------------------------------------
; UPDATE_LCD
; Updates the screen with current sensor values.
; Format Line 1: "+TT.T°C  PPPPhPa" (approx)
; Format Line 2: "LLLLLLUX CC.C%"
; --------------------------------------------
UPDATE_LCD:
    ; --- Line 1 ---
    MOVLW   LCD_CMD_SET_DDRAM | 0x00
    CALL    LCD_SEND_CMD

    ; 1. Temperature (Sign + XX.X)
    MOVLW   '+'             
    CALL    LCD_SEND_DATA
    
    MOVF    OUTDOOR_TEMP_H, W
    CALL    PRINT_2DIGIT_NUM
    
    MOVLW   '.'
    CALL    LCD_SEND_DATA
    
    MOVF    OUTDOOR_TEMP_L, W
    CALL    PRINT_1DIGIT_NUM
    
    MOVLW   0xDF        ; HD44780 degree symbol
    CALL    LCD_SEND_DATA
    MOVLW   'C'
    CALL    LCD_SEND_DATA
    MOVLW   ' '
    CALL    LCD_SEND_DATA
    MOVLW   ' '
    CALL    LCD_SEND_DATA
    MOVLW   ' '
    CALL    LCD_SEND_DATA
    ; 2. Pressure (XXXX hPa)
    ; Showing High Byte as 3 digits:
    MOVF    OUTDOOR_PRESS_H, W
    CALL    PRINT_3DIGIT_NUM
    
    MOVLW   'h'
    CALL    LCD_SEND_DATA
    MOVLW   'P'
    CALL    LCD_SEND_DATA
    MOVLW   'a'
    CALL    LCD_SEND_DATA

    ; --- Line 2 ---
    MOVLW   LCD_CMD_SET_DDRAM | 0x40    ; Move to 2nd Line
    CALL    LCD_SEND_CMD

    ; 3. Light (L:XXX)
    MOVLW   'L'
    CALL    LCD_SEND_DATA
    MOVLW   ':'
    CALL    LCD_SEND_DATA
    
    ; Light is 10-bit (High + Low). Just show High Byte (0-3 approx) * 25 for scale?
    ; Or just show High Byte raw.
    MOVF    LIGHT_INTENSITY_H, W
    CALL    PRINT_3DIGIT_NUM
    
    MOVLW   'L'
    CALL    LCD_SEND_DATA
    MOVLW   'u'
    CALL    LCD_SEND_DATA
    MOVLW   'x'
    CALL    LCD_SEND_DATA
    MOVLW   ' '
    CALL    LCD_SEND_DATA
    MOVLW   ' '
    CALL    LCD_SEND_DATA
    ; 4. Curtain Status (XX%)
    MOVF    CURTAIN_STATUS, W
    CALL    PRINT_3DIGIT_NUM    ; Can be 100
    
    MOVLW   '%'
    CALL    LCD_SEND_DATA
    MOVLW   ' '
    CALL    LCD_SEND_DATA
    
    RETURN

; ============================================
; LOW LEVEL LCD FUNCTIONS
; ============================================

LCD_SEND_CMD:
    BCF     PORTE, 0        ; RS = 0 (Command)
    GOTO    LCD_SEND_BYTE

LCD_SEND_DATA:
    BSF     PORTE, 0        ; RS = 1 (Data)
    GOTO    LCD_SEND_BYTE

LCD_SEND_BYTE:
    MOVWF   TEMP_WORK       ; Save Data
    
    ; Send High Nibble
    ANDLW   0xF0            ; Mask Low Nibble
    MOVWF   PORTD           ; Send to Port
    CALL    LCD_PULSE_E
    
    ; Send Low Nibble
    SWAPF   TEMP_WORK, W    ; Swap nibbles
    ANDLW   0xF0
    MOVWF   PORTD
    CALL    LCD_PULSE_E
    
    CALL    LCD_DELAY_US
    RETURN

LCD_PULSE_E:
    BSF     PORTE, 1        ; E = 1
    NOP			    ; LCD latches data.
    NOP
    NOP
    BCF     PORTE, 1        ; E = 0
    RETURN

; ============================================
; HELPER: NUMBER PRINTING
; ============================================

PRINT_1DIGIT_NUM:
    ANDLW   0x0F
    ADDLW   '0'		    ;0X30=0 add for displaying on LCD
    CALL    LCD_SEND_DATA
    RETURN

PRINT_2DIGIT_NUM:
    ; Input W: 0-99
    MOVWF   UART_TX_BYTE    ; Reuse variable as Number
    
    ; Tens
    MOVLW   0
    MOVWF   UART_RX_BYTE    ; Reuse variable as Tens Counter
FIND_TENS:
    MOVF    UART_TX_BYTE, W
    SUBLW   9		    ; 9 - W
    BTFSC   STATUS, 0       ; If Num <= 9, Done
    GOTO    PRINT_DIGITS
    
    MOVLW   10
    SUBWF   UART_TX_BYTE, F ; Num -= 10
    INCF    UART_RX_BYTE, F ; Tens++
    GOTO    FIND_TENS

PRINT_DIGITS:
    MOVF    UART_RX_BYTE, W
    ADDLW   '0'
    CALL    LCD_SEND_DATA   ; Print Tens
    
    MOVF    UART_TX_BYTE, W
    ADDLW   '0'
    CALL    LCD_SEND_DATA   ; Print Ones
    RETURN

PRINT_3DIGIT_NUM:
    ; Hundreds, Tens, Ones.
    ; (Omitting full Binary-to-BCD for brevity, using simple logic)
    MOVWF   UART_TX_BYTE    ; Num
    
    ; Hundreds
    CLRF    TEMP_WORK       ; Hundreds Counter
FIND_HUNDREDS:
    MOVF    UART_TX_BYTE, W
    SUBLW   99
    BTFSC   STATUS, 0       ; If Num <= 99, Done
    GOTO    FIND_TENS_3
    
    MOVLW   100
    SUBWF   UART_TX_BYTE, F
    INCF    TEMP_WORK, F
    GOTO    FIND_HUNDREDS

FIND_TENS_3:
    MOVF    TEMP_WORK, W
    BTFSS   STATUS, 2       ; If hundreds > 0
    GOTO    PRINT_HUND      ; Print it
    ; Lets print digit 
    MOVLW   '0'
    CALL    LCD_SEND_DATA
    GOTO    DO_TENS

PRINT_HUND:
    MOVF    TEMP_WORK, W
    ADDLW   '0'
    CALL    LCD_SEND_DATA

DO_TENS:
    ; Now use 2-digit logic for remaining
    CLRF    TEMP_WORK       ; Tens Counter
LOOP_TENS:
    MOVF    UART_TX_BYTE, W
    SUBLW   9
    BTFSC   STATUS, 0
    GOTO    DO_ONES
    MOVLW   10
    SUBWF   UART_TX_BYTE, F
    INCF    TEMP_WORK, F
    GOTO    LOOP_TENS

DO_ONES:
    MOVF    TEMP_WORK, W
    ADDLW   '0'
    CALL    LCD_SEND_DATA
    
    MOVF    UART_TX_BYTE, W
    ADDLW   '0'
    CALL    LCD_SEND_DATA
    RETURN

; ============================================
; DELAY ROUTINES
; ============================================
LCD_DELAY_MS:
    MOVLW   250
    MOVWF   UART_RX_BYTE
D_MS_LOOP:
    NOP
    DECFSZ  UART_RX_BYTE, F
    GOTO    D_MS_LOOP
    RETURN

LCD_DELAY_US:
    MOVLW   10
    MOVWF   UART_RX_BYTE
D_US_LOOP:
    DECFSZ  UART_RX_BYTE, F
    GOTO    D_US_LOOP
    RETURN