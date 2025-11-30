; ======================================================
; FILE: main_board1.asm
; AUTHOR: SAFIULLAH SEDIQI 152120211031
; CLEAN + BANK-ISOLATED (RE0=HEATER, RE1=COOLER)
; ======================================================

        processor 16F877A
        #include <xc.inc>

; --- CONFIG ---
CONFIG  FOSC=XT, WDTE=OFF, PWRTE=ON, BOREN=OFF, LVP=OFF, CPD=OFF, WRT=OFF, CP=OFF
; Not: ADCON1 = 0x8E = ADFM=1 + PCFG=1110 (AN0 analog, right-justified)

; --------------------------------------------------
; GLOBAL DE???KENLER (BANK0)
; --------------------------------------------------
        PSECT udata_bank0
DesiredTemp_INT:        DS 1
DesiredTemp_FRAC:       DS 1
AmbientTemp_INT:        DS 1
AmbientTemp_FRAC:       DS 1
FanSpeed_RPS:           DS 1
Temp_ADC_RESULT:        DS 1
Timer1_Overflow_Count:  DS 1
Display_Data_Select:    DS 1
Display_Timer_2sec:     DS 1

W_TEMP:                 DS 1
STATUS_TEMP:            DS 1
PCLATH_TEMP:            DS 1

; --------------------------------------------------
; INTERRUPT VEKTÖRÜ (basit iskelet)
; --------------------------------------------------
        PSECT intVec, class=CODE, delta=2
        ORG 0x04
ISR:
        movwf   W_TEMP
        swapf   STATUS, W
        movwf   STATUS_TEMP
        movf    PCLATH, W
        movwf   PCLATH_TEMP

        ; (UART / Keypad / TMR1 handler'lar modüllerde iskelet, PORTE/TRISE?e dokunmaz)
        btfsc   PIR1, PIR1_RCIF_POSITION
        call    UART_RX_ISR

        btfsc   INTCON, INTCON_RBIF_POSITION
        call    Keypad_Interrupt_Handler
        bcf     INTCON, INTCON_RBIF_POSITION

        btfsc   PIR1, PIR1_TMR1IF_POSITION
        call    Timer1_ISR_Handler

        movf    PCLATH_TEMP, W
        movwf   PCLATH
        swapf   STATUS_TEMP, W
        movwf   STATUS
        swapf   W_TEMP, F
        swapf   W_TEMP, W
        retfie

; --------------------------------------------------
; RESET VEKTÖRÜ
; --------------------------------------------------
        PSECT resetVec, class=CODE, delta=2
        ORG 0x00
        goto MAIN

; --------------------------------------------------
; MAIN
; --------------------------------------------------
        PSECT code

MAIN:
        call init_ports_and_config
        call init_peripherals
        call init_ram_vars

MAIN_LOOP:
        ; --- sensör/hesap ---
        call Read_Ambient_Temp_ADC
        call Read_Fan_Speed
        call Temperature_Control_Logic

        ; --- (?imdilik bo?) display ---
        call Display_Multiplex_Routine

        goto MAIN_LOOP

; --------------------------------------------------
; PORT / ADCON1 / KESME AYARI
; --------------------------------------------------
init_ports_and_config:
        BANKSEL TRISA
        movlw 0x01              ; RA0 IN (AN0), di?erleri OUT
        movwf TRISA

        BANKSEL TRISB
        movlw 0x0F              ; RB0..RB3 IN (keypad), RB4..RB7 OUT
        movwf TRISB

        BANKSEL TRISC
        movlw 0x81              ; RC7 RX IN, RC6 TX OUT, RC0 IN
        movwf TRISC

        BANKSEL TRISD
        clrf TRISD              ; display OUT

        BANKSEL TRISE
        clrf TRISE              ; RE0=HEATER, RE1=COOLER OUT

        BANKSEL ADCON1
        movlw 0x8E              ; ADFM=1 + PCFG=1110  (AN0 analog)
        movwf ADCON1

        ; portlar? temizle
        BANKSEL PORTA
        clrf PORTA
        BANKSEL PORTB
        clrf PORTB
        BANKSEL PORTC
        clrf PORTC
        BANKSEL PORTD
        clrf PORTD
        BANKSEL PORTE
        clrf PORTE              ; heater+cooler OFF

        ; kesmeler (sade)
        bcf INTCON, INTCON_GIE_POSITION
        bsf INTCON, INTCON_PEIE_POSITION
        bsf INTCON, INTCON_RBIE_POSITION
        bsf PIE1, PIE1_RCIE_POSITION
        bsf PIE1, PIE1_TMR1IE_POSITION
        bsf INTCON, INTCON_GIE_POSITION
        return

; --------------------------------------------------
; ÇALI?MA RAM BA?LANGIÇ DE?ERLER?
; --------------------------------------------------
init_ram_vars:
        clrf DesiredTemp_INT
        clrf DesiredTemp_FRAC
        clrf AmbientTemp_INT
        clrf AmbientTemp_FRAC
        clrf FanSpeed_RPS
        clrf Temp_ADC_RESULT
        clrf Timer1_Overflow_Count
        clrf Display_Data_Select
        clrf Display_Timer_2sec
        return

; --------------------------------------------------
; PERIPHERAL INIT (modüller PORTE/TRISE?e dokunmaz)
; --------------------------------------------------
init_peripherals:
        call INIT_UART
        call INIT_ADC_Timer
        call INIT_Display
        call INIT_Keypad
        return

; --------------------------------------------------
; S?cakl?k kontrolü (RE0=HEATER, RE1=COOLER)
; --------------------------------------------------
Temperature_Control_Logic:
        movf AmbientTemp_INT, W
        subwf DesiredTemp_INT, W

        btfsc STATUS, STATUS_Z_POSITION
        goto _cmp_frac

        ; C=0 ? Ambient < Desired ? HEATER ON
        btfss STATUS, STATUS_C_POSITION
        goto HEATER_ON
        goto COOLER_ON

_cmp_frac:
        movf AmbientTemp_FRAC, W
        subwf DesiredTemp_FRAC, W

        btfss STATUS, STATUS_C_POSITION
        goto HEATER_ON
        goto COOLER_ON

HEATER_ON:
        BANKSEL PORTE
        bcf PORTE,1      ; cooler OFF (RE1=0)
        bsf PORTE,0      ; heater ON  (RE0=1)
        return

COOLER_ON:
        BANKSEL PORTE
        bcf PORTE,0      ; heater OFF (RE0=0)
        bsf PORTE,1      ; cooler ON  (RE1=1)
        return

; --------------------------------------------------
; MODÜLLER? GÖM
; --------------------------------------------------
#include "temp_adc.asm"
#include "display.asm"
#include "keypad.asm"
#include "uart_board1.asm"

END
