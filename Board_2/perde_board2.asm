; ==============================================================================
; PROJE: Board #2 - Perde Sistemi
; DURUM: ABSOLUTE MODE (Linker'i Devre Disi Birakip Zorla Adrese Yazma)
; ==============================================================================

    #include <xc.inc>

    ; --- KONFIGURASYON ---
    CONFIG FOSC = HS
    CONFIG WDTE = OFF
    CONFIG PWRTE = ON
    CONFIG BOREN = OFF
    CONFIG LVP = OFF
    CONFIG CPD = OFF
    CONFIG WRT = OFF
    CONFIG CP = OFF

    ; --- DEGISKENLER ---
    PSECT udata_bank0
Desired_Curtain:    DS 1
Current_Curtain:    DS 1
Light_Intensity:    DS 1
Pot_Value:          DS 1
Step_Index:         DS 1
Temp:               DS 1
Delay1:             DS 1
Delay2:             DS 1

    ; --- ABSOLUTE CODE BOLUMU ---
    ; "abs" parametresi derleyiciye "Adresleri ben verecegim" der.
    PSECT code, abs

    ; --------------------------------------------------------------------------
    ; RESET VEKTORU (0x0000)
    ; --------------------------------------------------------------------------
    ORG 0x0000
    GOTO    INIT_SYSTEM

    ; --------------------------------------------------------------------------
    ; INTERRUPT VEKTORU (0x0004)
    ; --------------------------------------------------------------------------
    ORG 0x0004
    RETFIE

    ; --------------------------------------------------------------------------
    ; DERLEYICIYI SUSTURMA YAMASI
    ; --------------------------------------------------------------------------
    ; Eger derleyici hala main ararsa diye bunlari ekliyoruz ama
    ; 'abs' modunda cogu zaman gerekmez. Yine de dursun.
    GLOBAL _main
    GLOBAL start_initialization

_main:
start_initialization:
    ; Buraya kod gelmeyecek, sadece etiket olarak varlar.

; ==============================================================================
; SISTEM BASLATMA (INIT)
; ==============================================================================
INIT_SYSTEM:
    ; Bank 1
    BSF     STATUS, 5       
    BCF     STATUS, 6
    
    MOVLW   0xFF
    MOVWF   TRISA           ; PORTA Giris
    CLRF    TRISB           ; PORTB Cikis
    CLRF    TRISD           ; PORTD Cikis
    
    ; ADC Ayari (Sola Dayali)
    MOVLW   00000010B       
    MOVWF   ADCON1
    
    ; Bank 0
    BCF     STATUS, 5
    
    CLRF    PORTA
    CLRF    PORTB
    CLRF    PORTD
    
    ; ADC Ac
    MOVLW   10000001B
    MOVWF   ADCON0
    
    CLRF    Current_Curtain
    CLRF    Desired_Curtain
    CLRF    Step_Index
    CLRF    Light_Intensity
    
    CALL    Flash_LEDs

; ==============================================================================
; ANA DONGU
; ==============================================================================
MAIN_LOOP:
    ; --- 1. POT OKU ---
    MOVLW   10010001B       ; Kanal 2 (RA2)
    MOVWF   ADCON0
    CALL    Delay_ADC
    BSF     ADCON0, 2       ; Baslat
Wait_Pot:
    BTFSC   ADCON0, 2
    GOTO    Wait_Pot
    
    ; Olcekleme
    BCF     STATUS, 0
    RRF     ADRESH, W
    MOVWF   Desired_Curtain
    
    ; 100 Siniri
    MOVLW   100
    SUBWF   Desired_Curtain, W
    BTFSC   STATUS, 0
    GOTO    Limit_Fix
    GOTO    Check_LDR
Limit_Fix:
    MOVLW   100
    MOVWF   Desired_Curtain

Check_LDR:
    ; --- 2. LDR OKU ---
    MOVLW   10001001B       ; Kanal 1 (RA1)
    MOVWF   ADCON0
    CALL    Delay_ADC
    BSF     ADCON0, 2       ; Baslat
Wait_LDR:
    BTFSC   ADCON0, 2
    GOTO    Wait_LDR
    
    MOVF    ADRESH, W
    MOVWF   Light_Intensity
    
    ; --- LDR MANTIGI ---
    MOVLW   100
    SUBWF   Light_Intensity, W
    
    BTFSC   STATUS, 0       ; Isik < 100 ise
    GOTO    Force_Close     ; Gece
    GOTO    Motor_Control   ; Gunduz

Force_Close:
    MOVLW   100
    MOVWF   Desired_Curtain

Motor_Control:
    CALL    Control_Step
    MOVF    Current_Curtain, W
    MOVWF   PORTD
    CALL    Delay_Short
    GOTO    MAIN_LOOP

; ==============================================================================
; ALT PROGRAMLAR
; ==============================================================================
Control_Step:
    MOVF    Desired_Curtain, W
    SUBWF   Current_Curtain, W
    BTFSC   STATUS, 2
    RETURN
    BTFSS   STATUS, 0
    GOTO    Go_Close
    GOTO    Go_Open

Go_Close:
    CALL    Step_CCW
    INCF    Current_Curtain, F
    MOVF    Current_Curtain, W
    MOVWF   PORTD
    RETURN

Go_Open:
    CALL    Step_CW
    DECF    Current_Curtain, F
    MOVF    Current_Curtain, W
    MOVWF   PORTD
    RETURN

Step_CW:
    INCF    Step_Index, F
    GOTO    Do_Step
Step_CCW:
    DECF    Step_Index, F
    GOTO    Do_Step

Do_Step:
    MOVF    Step_Index, W
    ANDLW   0x03
    MOVWF   Temp
    MOVF    Temp, W
    XORLW   0
    BTFSC   STATUS, 2
    GOTO    P0
    MOVF    Temp, W
    XORLW   1
    BTFSC   STATUS, 2
    GOTO    P1
    MOVF    Temp, W
    XORLW   2
    BTFSC   STATUS, 2
    GOTO    P2
    GOTO    P3
P0: MOVLW 0x09
    MOVWF PORTB
    CALL Delay_Motor
    RETURN
P1: MOVLW 0x0C
    MOVWF PORTB
    CALL Delay_Motor
    RETURN
P2: MOVLW 0x06
    MOVWF PORTB
    CALL Delay_Motor
    RETURN
P3: MOVLW 0x03
    MOVWF PORTB
    CALL Delay_Motor
    RETURN

Delay_ADC:
    MOVLW   50
    MOVWF   Delay1
L_A:DECFSZ  Delay1, F
    GOTO    L_A
    RETURN

Delay_Motor:
    MOVLW   50
    MOVWF   Delay1
LM1:MOVLW   50
    MOVWF   Delay2
LM2:DECFSZ  Delay2, F
    GOTO    LM2
    DECFSZ  Delay1, F
    GOTO    LM1
    RETURN

Delay_Short:
    MOVLW   50
    MOVWF   Delay1
L_S:DECFSZ  Delay1, F
    GOTO    L_S
    RETURN

Flash_LEDs:
    MOVLW   0xFF
    MOVWF   PORTD
    MOVLW   200
    MOVWF   Delay1
LF1:MOVLW   200
    MOVWF   Delay2
LF2:DECFSZ  Delay2, F
    GOTO    LF2
    DECFSZ  Delay1, F
    GOTO    LF1
    CLRF    PORTD
    MOVLW   200
    MOVWF   Delay1
LF3:MOVLW   200
    MOVWF   Delay2
LF4:DECFSZ  Delay2, F
    GOTO    LF4
    DECFSZ  Delay1, F
    GOTO    LF3
    RETURN

    END