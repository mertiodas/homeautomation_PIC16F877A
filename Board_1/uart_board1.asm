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
        BANKSEL TRISC
        BSF     TRISC, 7    ; RX Giriş
        BCF     TRISC, 6    ; TX Çıkış
        BANKSEL TXSTA
        MOVLW   0x24        ; BRGH=1, TXEN=1
        MOVWF   TXSTA
        BANKSEL RCSTA
        MOVLW   0x90        ; SPEN=1, CREN=1
        MOVWF   RCSTA
        BANKSEL SPBRG
        MOVLW   25          ; 9600 Baud
        MOVWF   SPBRG
        BANKSEL PIE1
        BSF     PIE1, 5     ; RCIE aktif
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
        BTFSC   STATUS, 2   ; Veri yoksa dön
        RETURN
        CLRF    UART_Flag

        BANKSEL UART_RX_Byte
        MOVF    UART_RX_Byte, W

        ; --- Python Komutları ---
        XORLW   'G'         ; Python "Veri gönder" dedi mi?
        BTFSC   STATUS, 2
        GOTO    SEND_TELEMETRY

        MOVF    UART_RX_Byte, W
        XORLW   'D'         ; Python "Yeni hedef sıcaklık" dedi mi?
        BTFSC   STATUS, 2
        GOTO    RECEIVE_DESIRED_TEMP

        ; --- Manuel Kontrol Komutları ---
        MOVF    UART_RX_Byte, W
        XORLW   'H'         ; Heater ON
        BTFSC   STATUS, 2
        GOTO    UART_HEATER

        MOVF    UART_RX_Byte, W
        XORLW   'C'         ; Cooler ON
        BTFSC   STATUS, 2
        GOTO    UART_COOLER

        MOVF    UART_RX_Byte, W
        XORLW   'O'         ; All OFF
        BTFSC   STATUS, 2
        GOTO    UART_OFF

        RETURN

; --- ALT PROGRAMLAR ---

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

SEND_TELEMETRY:
        ; Python'a "Axx\n" gönder (Ambient)
        MOVLW   'A'
        CALL    UART_Send_Char
        BANKSEL AmbientTemp_INT
        MOVF    AmbientTemp_INT, W
        CALL    UART_Send_Value_As_String
        MOVLW   0x0A ; \n
        CALL    UART_Send_Char

        ; Python'a "Fxxx\n" gönder (Fan)
        MOVLW   'F'
        CALL    UART_Send_Char
        BANKSEL FanSpeed_RPS
        MOVF    FanSpeed_RPS, W
        CALL    UART_Send_Value_As_String
        MOVLW   0x0A ; \n
        CALL    UART_Send_Char
        RETURN

RECEIVE_DESIRED_TEMP:
        ; Burada Python'dan gelen Dxx formatındaki xx kısmını
        ; yakalamak için ekstra mantık gerekir, şimdilik boş geçiyoruz.
        RETURN

; --- YARDIMCI TX FONKSİYONLARI ---

UART_Send_Char:
        BANKSEL TXSTA
WAIT_TX:
        BTFSS   TXSTA, 1    ; TRMT biti kontrolü
        GOTO    WAIT_TX
        BANKSEL TXREG
        MOVWF   TXREG
        RETURN

UART_Send_Value_As_String:
        MOVWF   0x70        ; W'yi geçici adrese al
        CLRF    0x71        ; Onlar hanesi sayacı
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