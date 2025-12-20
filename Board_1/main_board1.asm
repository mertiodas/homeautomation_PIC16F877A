; ======================================================
; FILE: main_board1.asm
; AUTHOR : SAFIULLAH SEDIQI 152120211031	
; CLEAN + TEST COMMENT BLOCK INCLUDED
; ======================================================

        processor 16F877A
        #include <xc.inc>

; --- CONFIG ---
CONFIG  FOSC=XT, WDTE=OFF, PWRTE=ON, BOREN=OFF, LVP=OFF, CPD=OFF, WRT=OFF, CP=OFF


; --------------------------------------------------
; GLOBAL VARIABLES (BANK0)
; --------------------------------------------------
        PSECT udata_bank0
DesiredTemp_INT:       DS 1
DesiredTemp_FRAC:      DS 1
AmbientTemp_INT:       DS 1
AmbientTemp_FRAC:      DS 1
FanSpeed_RPS:          DS 1
Timer1_Overflow_Count: DS 1
Display_Data_Select:   DS 1
Display_Timer_2sec:    DS 1

W_TEMP:                DS 1
STATUS_TEMP:           DS 1
PCLATH_TEMP:           DS 1

d1: DS 1
d2: DS 1


; --------------------------------------------------
; INTERRUPT VECTOR
; --------------------------------------------------
        PSECT intVec, class=CODE, delta=2
        ORG 0x04

ISR:
        movwf   W_TEMP
        swapf   STATUS, W
        movwf   STATUS_TEMP
        movf    PCLATH, W
        movwf   PCLATH_TEMP

        ; UART RX
        btfsc   PIR1, PIR1_RCIF_POSITION
        call    UART_RX_ISR

        ; KEYPAD
        btfsc   INTCON, INTCON_RBIF_POSITION
        call    Keypad_Interrupt_Handler
        bcf     INTCON, INTCON_RBIF_POSITION

        ; TIMER1
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
; RESET VECTOR
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

; ==========================================================
; ========== SCENARIO-1 TEST BLOCK (commented) =============
; ==========================================================
;
; ====== SCENARIO ====================================
; Ambient 15.0°C, Desired 25.0°C ? HEATER ON (RE0=1)

      movlw   15
      movwf   AmbientTemp_INT
      clrf    AmbientTemp_FRAC

      movlw   25
      movwf   DesiredTemp_INT
      clrf    DesiredTemp_FRAC

      call Temperature_Control_Logic
      call delay_big
;
; ==========================================================
; ================ END OF TEST BLOCK =======================
; ==========================================================


        call Read_Ambient_Temp_ADC
        call Read_Fan_Speed
        call Temperature_Control_Logic
        call Display_Multiplex_Routine

        goto MAIN_LOOP



; --------------------------------------------------
; PORT INIT
; --------------------------------------------------
init_ports_and_config:

        BANKSEL TRISA
        movlw 0x01
        movwf TRISA

        BANKSEL TRISB
        movlw 0x0F
        movwf TRISB

        BANKSEL TRISC
        movlw 0x81
        movwf TRISC

        BANKSEL TRISD
        clrf TRISD

        BANKSEL TRISE
        clrf TRISE

        BANKSEL ADCON1
        movlw 0x8E
        movwf ADCON1

        BANKSEL PORTA
        clrf PORTA
        BANKSEL PORTB
        clrf PORTB
        BANKSEL PORTC
        clrf PORTC
        BANKSEL PORTD
        clrf PORTD
        BANKSEL PORTE
        clrf PORTE

        bcf INTCON, INTCON_GIE_POSITION
        bsf INTCON, INTCON_PEIE_POSITION
        bsf INTCON, INTCON_RBIE_POSITION
        bsf PIE1, PIE1_RCIE_POSITION
        bsf PIE1, PIE1_TMR1IE_POSITION
        bsf INTCON, INTCON_GIE_POSITION
        return



; --------------------------------------------------
; PERIPHERAL INIT
; --------------------------------------------------
init_peripherals:
        call INIT_UART
        call INIT_ADC_Timer
        call INIT_Display
        call INIT_Keypad
        return



; --------------------------------------------------
; RAM INIT
; --------------------------------------------------
init_ram_vars:
        clrf DesiredTemp_INT
        clrf DesiredTemp_FRAC
        clrf AmbientTemp_INT
        clrf AmbientTemp_FRAC
        clrf FanSpeed_RPS
        clrf Timer1_Overflow_Count
        clrf Display_Data_Select
        clrf Display_Timer_2sec
        return



; --------------------------------------------------
; TEMPERATURE CONTROL LOGIC
; --------------------------------------------------
Temperature_Control_Logic:

        movf AmbientTemp_INT, W     ; W = Ambient_INT
        subwf DesiredTemp_INT, W    ; Operation: Desired_INT - Ambient_INT (W - f)

        btfsc STATUS, STATUS_Z_POSITION ; If Z=1 (EQUAL), check fractional part.
        goto Compare_Frac

        ; If Z=0 (NOT EQUAL).
        ; C=1 means (Desired >= Ambient)
        ; C=0 means (Desired < Ambient)

        btfss STATUS, STATUS_C_POSITION
        goto COOLER_ON            ; C=0, Z=0 -> Desired < Ambient -> Ambient HIGH -> COOLER ON
        goto HEATER_ON            ; C=1, Z=0 -> Desired > Ambient -> Ambient LOW -> HEATER ON

Compare_Frac:
        movf AmbientTemp_FRAC, W    ; W = Ambient_FRAC
        subwf DesiredTemp_FRAC, W   ; Operation: Desired_FRAC - Ambient_FRAC (W - f)

        btfsc STATUS, STATUS_Z_POSITION ; If Z=1 (EQUAL). Fully equal.
        goto BOTH_OFF             ; Both parts are equal -> OFF

        ; If Z=0 (NOT EQUAL). (Integer part is equal, fractional part is different)
        ; C=1 means (Desired >= Ambient)
        ; C=0 means (Desired < Ambient)

        btfss STATUS, STATUS_C_POSITION
        goto COOLER_ON            ; C=0, Z=0 -> Desired_FRAC < Ambient_FRAC -> Ambient HIGH -> COOLER ON
        goto HEATER_ON            ; C=1, Z=0 -> Desired_FRAC > Ambient_FRAC -> Ambient LOW -> HEATER ON


HEATER_ON:
        BANKSEL PORTE
        bcf PORTE,1               ; Cooler OFF (RE1)
        bsf PORTE,0               ; Heater ON (RE0)
        return

COOLER_ON:
        BANKSEL PORTE
        bcf PORTE,0               ; Heater OFF (RE0)
        bsf PORTE,1               ; Cooler ON (RE1)
        return

BOTH_OFF:
        BANKSEL PORTE
        bcf PORTE,0               ; Heater OFF (RE0)
        bcf PORTE,1               ; Cooler OFF (RE1)
        return



; --------------------------------------------------
; DELAY ROUTINE
; --------------------------------------------------
delay_big:
    movlw   0xAF
    movwf   d1
d1_loop:
    movlw   0xFF
    movwf   d2
d2_loop:
    nop
    decfsz  d2, F
    goto d2_loop
    decfsz  d1, F
    goto d1_loop
    return



; --------------------------------------------------
; MODULE INCLUDES
; --------------------------------------------------
#include "temp_adc.asm"
#include "display.asm"
#include "keypad.asm"
#include "uart_board1.asm"

END MAIN