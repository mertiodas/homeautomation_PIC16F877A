; ============================================
; adc.asm - Board 2 LDR Light Sensor Driver
; Sensor: LDR on RA0/AN0
; Logic: If Light < Threshold (Dark), Close Curtain.
; ============================================

; --- Constants ---
; 10-bit ADC but only used bit 8 to 10. 
LDR_DARK_THRESH_H   EQU 0x03   ;(if LDR<=10k, step motor turns CCW)

; --------------------------------------------
; ADC_INIT
; Configures ADC for AN0 input, Left Justified.
; --------------------------------------------
ADC_INIT:
    ; --- Switch to BANK 1 ---
    BANKSEL ADCON1    ; Select ADCON1 Bank
    ; ADCON1 Setup:
    ; bit 7: ADFM = 0 (Left Justified, 8-bit MSB result)
    ; bit 3-0: PCFG = 0010 (AN0-AN4 Analog, others Digital)
    MOVLW   0b00000010
    MOVWF   ADCON1

    ; --- Switch back to BANK 0 ---
    BANKSEL ADCON0       ; Select ADCON0 Bank

    ; ADCON0 Setup:
    ; bit 7-6: ADCS = 01 (Fosc/8)
    ; bit 5-3: CHS = 000 (Select Channel AN0 - LDR)
    ; bit 2: GO/DONE = 0
    ; bit 0: ADON = 1 (ADC Enable)
    MOVLW   0b01000001
    MOVWF   ADCON0

    RETURN

; --------------------------------------------
; READ_LIGHT_SENSOR
; Reads AN0, Stores result, Checks threshold.
; --------------------------------------------
READ_LIGHT_SENSOR:
    BANKSEL ADCON0
    ; Ensure Channel AN0 is selected
    BCF     ADCON0, 5
    BCF     ADCON0, 4
    BCF     ADCON0, 3       ; CHS=000

    ; Short delay for acquisition (For ADC Capacitor)
    NOP
    NOP
    NOP
    
    ; Start Conversion
    BSF     ADCON0, 2       ; GO/DONE = 1

WAIT_LDR_ADC:
    BTFSC   ADCON0, 2       ; Wait for conversion
    GOTO    WAIT_LDR_ADC

    ; Read Result (Right Justified)
    MOVF    ADRESH, W
    MOVWF   LIGHT_INTENSITY_H
    MOVF    ADRESL, W             
    MOVWF   LIGHT_INTENSITY_L

    ; --- Check Darkness Threshold ---
    ; Logic: If ADRESH >= 3, it is Dark -> Close Curtain
    MOVF    LIGHT_INTENSITY_H, W
    SUBLW   LDR_DARK_THRESH_H   ; Thresh - Current
   
    BTFSC STATUS, 0     ;This part is prevent reverse logic of LDR
    GOTO  CARRY_ONE     
    BSF   STATUS, 0     
    GOTO  CODE_RUN      
CARRY_ONE:
    BCF   STATUS, 0     

CODE_RUN:		;Carry was reversed (C=0 >> C=1 ; C=1 >> C=0)
    BTFSC   STATUS, 0   ; Check Carry
    RETURN		;(Thresh > Current), Do nothing.
    
    ; --- It is Dark! ---
    ; Auto-Close Curtain (Set Desired to 100%)
    CLRF    LDR_FLAG		; Flag for POT<LDR
    MOVLW   100
    MOVWF   DES_CURTAIN_STATUS
    CLRF    DES_CURTAIN_STATUS_L 
    
    RETURN

READ_POT_SENSOR:
    BANKSEL ADCON0
    ; Channel AN2 is selected
    BCF     ADCON0, 5
    BSF     ADCON0, 4
    BCF     ADCON0, 3       ; CHS=010

    ; Short delay for acquisition
    NOP
    NOP
    NOP
    
    ; Start Conversion
    BSF     ADCON0, 2       ; GO/DONE = 1

WAIT_POT_ADC:
    BTFSC   ADCON0, 2       ; Wait for conversion
    GOTO    WAIT_POT_ADC

    ; Read Result (Left Justified)
    ; ADRESH = High 8 bits, ADRESL = Low 2 bits
    MOVF    ADRESH, W
    MOVWF   POT_H
    MOVF    ADRESL, W       
    MOVWF   POT_L

    ; Convert ADC value to 0-100
    CLRF    TEMP_WORK
    CLRF    TEMP_WORK2
    MOVF    POT_H,W
    MOVWF   TEMP_WORK
    BCF	    STATUS,0
    RRF	    TEMP_WORK,F     ;TEMP_REG/2 (1/2)
    MOVF    TEMP_WORK,W
    MOVWF   TEMP_WORK2	    ;TEMP_REG/2=TEMP_REG2 
    BCF	    STATUS,0
    RRF	    TEMP_WORK2,F    ;TEMP_REG2/2 (1/4)
    BCF	    STATUS,0
    RRF	    TEMP_WORK2,F    ;TEMP_REG2/2 (1/8)
    MOVF    TEMP_WORK2,W
    SUBWF   TEMP_WORK,F	    ;Result * (1/2 - 1/8)
    MOVF    TEMP_WORK,W
    MOVWF   DES_CURTAIN_STATUS
    CLRF    DES_CURTAIN_STATUS_L 
    
        ; -------- POT MAX CLAMP --------
    MOVF    DES_CURTAIN_STATUS, W
    SUBLW   95		    ; 95 - POT_H
    BTFSC   STATUS, 0       ; if DES_CURTAIN_STATUS >= 95
    GOTO    POT_NOT_MAX
    MOVLW   100
    MOVWF   DES_CURTAIN_STATUS
POT_NOT_MAX:
    RETURN