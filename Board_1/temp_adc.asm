; ======================================================
; MODULE: temp_adc.asm  (BANK1 udata)
; AUTHOR : SAFIULLAH SEDIQI 152120211031
; LM35 + 10-bit ADC, RA1/RA2 for Heater/Cooler, RC0 for Tach
; ======================================================

; --- Local RAM (BANK1) ---
        PSECT udata_bank1
ADC_L:      DS 1
ADC_H:      DS 1
ACC0:       DS 1
ACC1:       DS 1
ACC2:       DS 1
TMP0:       DS 1
TMP1:       DS 1
CNT7:       DS 1
TX10_L:     DS 1
TX10_H:     DS 1
REM10:      DS 1

; --- Code Section ---
        PSECT adc_code, class=CODE, delta=2

; Global variables in bank0:
; AmbientTemp_INT / AmbientTemp_FRAC / Timer1_Overflow_Count / FanSpeed_RPS

INIT_ADC_Timer:
        ; Set RA0 as input for ADC (AN0), RA1/RA2 as outputs for Heater/Cooler
        BANKSEL TRISA
        bsf TRISA, 0       ; RA0 input (Temp sensor)
        bcf TRISA, 1       ; RA1 output (Heater)
        bcf TRISA, 2       ; RA2 output (Cooler)

        ; ADCON1 = 0x8E (ADFM=1, PCFG=1110 -> RA0 analog, rest digital)
        BANKSEL ADCON1
        movlw   0x8E
        movwf   ADCON1

        ; ADCON0 = 0x81 (ADON=1, CH0=AN0, Fosc/32)
        BANKSEL ADCON0
        movlw   0x81
        movwf   ADCON0

        ; Timer1 setup (example, leaves RE pins untouched)
        BANKSEL T1CON
        movlw   0b00110001
        movwf T1CON

        ; Clear Timer1 interrupt flag
        BANKSEL PIR1
        bcf PIR1, PIR1_TMR1IF_POSITION
        return

; ======================================================
Read_Ambient_Temp_ADC:
        ; Start ADC conversion
        BANKSEL ADCON0
        bsf ADCON0, ADCON0_GO_nDONE_POSITION
_adcwait:
        btfsc ADCON0, ADCON0_GO_nDONE_POSITION
        goto _adcwait

        ; Read 10-bit result
        BANKSEL ADRESL
        movf ADRESL, W
        movwf ADC_L
        movf ADRESH, W
        movwf ADC_H

        ; Clear accumulator
        clrf ACC0
        clrf ACC1
        clrf ACC2

        ; ACC = ADC * 625 (shift-add multiplication)
        ; Step 1: <<9
        movf ADC_L, W
        movwf TMP0
        movf ADC_H, W
        movwf TMP1
        clrf ACC0
        movf TMP0, W
        movwf ACC1
        movf TMP1, W
        movwf ACC2
        rlf ACC0, F
        rlf ACC1, F
        rlf ACC2, F

        ; Step 2: <<6 = <<4 + <<2
        movf ADC_L, W
        movwf TMP0
        movf ADC_H, W
        movwf TMP1
        rlf TMP0, F
        rlf TMP1, F
        rlf TMP0, F
        rlf TMP1, F
        rlf TMP0, F
        rlf TMP1, F
        rlf TMP0, F
        rlf TMP1, F
        movf TMP0, W
        addwf ACC0, F
        movf TMP1, W
        btfsc STATUS, STATUS_C_POSITION
        incf TMP1, F
        addwf ACC1, F
        btfsc STATUS, STATUS_C_POSITION
        incf ACC2, F

        ; Step 3: <<5
        movf ADC_L, W
        movwf TMP0
        movf ADC_H, W
        movwf TMP1
        rlf TMP0, F
        rlf TMP1, F
        rlf TMP0, F
        rlf TMP1, F
        rlf TMP0, F
        rlf TMP1, F
        rlf TMP0, F
        rlf TMP1, F
        movf TMP0, W
        addwf ACC0, F
        movf TMP1, W
        btfsc STATUS, STATUS_C_POSITION
        incf TMP1, F
        addwf ACC1, F
        btfsc STATUS, STATUS_C_POSITION
        incf ACC2, F

        ; Step 4: <<4
        movf ADC_L, W
        movwf TMP0
        movf ADC_H, W
        movwf TMP1
        rlf TMP0, F
        rlf TMP1, F
        rlf TMP0, F
        rlf TMP1, F
        rlf TMP0, F
        rlf TMP1, F
        rlf TMP0, F
        rlf TMP1, F
        movf TMP0, W
        addwf ACC0, F
        movf TMP1, W
        btfsc STATUS, STATUS_C_POSITION
        incf TMP1, F
        addwf ACC1, F
        btfsc STATUS, STATUS_C_POSITION
        incf ACC2, F

        ; Step 5: x1
        movf ADC_L, W
        addwf ACC0, F
        movf ADC_H, W
        btfsc STATUS, STATUS_C_POSITION
        incf ADC_H, F
        addwf ACC1, F
        btfsc STATUS, STATUS_C_POSITION
        incf ACC2, F

        ; Round +64
        movlw 64
        addwf ACC0, F
        btfsc STATUS, STATUS_C_POSITION
        incf ACC1, F
        btfsc STATUS, STATUS_C_POSITION
        incf ACC2, F

        ; >>7
        movlw 7
        movwf CNT7
_sh7:
        rrf ACC2, F
        rrf ACC1, F
        rrf ACC0, F
        decfsz CNT7, F
        goto _sh7

        movf ACC0, W
        movwf TX10_L
        movf ACC1, W
        movwf TX10_H

        ; INT = /10, FRAC = %10
        BANKSEL AmbientTemp_INT
        clrf AmbientTemp_INT
        clrf REM10

_div10:
        movf TX10_H, W
        iorwf TX10_L, W
        btfsc STATUS, STATUS_Z_POSITION
        goto _store

        decf TX10_L, F
        btfss STATUS, STATUS_Z_POSITION
        goto $+3
        decf TX10_H, F
        nop
        incf REM10, F
        movf REM10, W
        xorlw 10
        btfss STATUS, STATUS_Z_POSITION
        goto _div10
        incf AmbientTemp_INT, F
        clrf REM10
        goto _div10

_store:
        BANKSEL AmbientTemp_FRAC
        movf REM10, W
        movwf AmbientTemp_FRAC
        return

; ======================================================
Read_Fan_Speed:
        ; RC0 (T1CKI) used for counting pulses externally
        BANKSEL FanSpeed_RPS
        movlw 10        ; Placeholder: implement real counting logic here
        movwf FanSpeed_RPS
        return

; ======================================================
Timer1_ISR_Handler:
        BANKSEL PIR1
        bcf PIR1, PIR1_TMR1IF_POSITION
        BANKSEL Timer1_Overflow_Count
        incf Timer1_Overflow_Count, F
        return
