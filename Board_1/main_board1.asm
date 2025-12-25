; ======================================================
; FILE: main_board1.asm
; AUTHOR : SAFIULLAH SEDIQI 152120211031
; BOARD  : PIC16F877A - BOARD #1
; DESC   : Home Air Conditioner System
; ======================================================

        processor 16F877A
        #include <xc.inc>

; --------------------------------------------------
; CONFIGURATION BITS
; --------------------------------------------------
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
UART_RX_Byte: DS 1
UART_Flag:    DS 1

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

        ; UART RX INTERRUPT
        btfsc   PIR1, PIR1_RCIF_POSITION
        call    UART_RX_ISR

        ; KEYPAD INTERRUPT
        btfsc   INTCON, INTCON_RBIF_POSITION
        call    Keypad_Interrupt_Handler
        bcf     INTCON, INTCON_RBIF_POSITION

        ; TIMER1 INTERRUPT
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
; MAIN PROGRAM
; --------------------------------------------------
        PSECT code

MAIN:
        call init_ports_and_config
        call init_peripherals
        call init_ram_vars

MAIN_LOOP:

; ==================================================
; TEST BLOCK (COMMENTED ? FOR REPORT)
; ==================================================
; Ambient = 15.0 �C
; Desired = 25.0 �C
; Expected: FAN ON, HEATER OFF
;
       movlw   15
       movwf   AmbientTemp_INT
       clrf    AmbientTemp_FRAC

       movlw   25
       movwf   DesiredTemp_INT
       clrf    DesiredTemp_FRAC

       call Temperature_Control_Logic
       call delay_big
; ==================================================

        ;call Read_Ambient_Temp_ADC
        ;call Read_Fan_Speed
        ;call Temperature_Control_Logic
        ;call Display_Multiplex_Routine
        ;call UART_Process

        goto MAIN_LOOP


; --------------------------------------------------
; PORT INITIALIZATION
; --------------------------------------------------
init_ports_and_config:

        BANKSEL TRISA
        movlw   0x01            ; RA0 analog input (LM35)
        movwf   TRISA

        BANKSEL TRISB
        movlw   0x0F            ; RB0?RB3 keypad
        movwf   TRISB

        BANKSEL TRISC
        movlw   0x81            ; UART RX/TX
        movwf   TRISC

        BANKSEL TRISD
        clrf    TRISD           ; Display

        BANKSEL TRISE
        clrf    TRISE           ; RE0 Heater, RE1 Fan

        BANKSEL ADCON1
        movlw   0x8E
        movwf   ADCON1

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

        ; INTERRUPTS
        bcf INTCON, INTCON_GIE_POSITION
        bsf INTCON, INTCON_PEIE_POSITION
        bsf INTCON, INTCON_RBIE_POSITION
        bsf PIE1, PIE1_RCIE_POSITION
        bsf PIE1, PIE1_TMR1IE_POSITION
        bsf INTCON, INTCON_GIE_POSITION

        return


; --------------------------------------------------
; PERIPHERAL INITIALIZATION
; --------------------------------------------------
init_peripherals:
        call INIT_UART
        call INIT_ADC_Timer
        call INIT_Display
        call INIT_Keypad
        return


; --------------------------------------------------
; RAM INITIALIZATION
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
; TEMPERATURE CONTROL LOGIC (FIXED)
; --------------------------------------------------
Temperature_Control_Logic:

        movf AmbientTemp_INT, W
        subwf DesiredTemp_INT, W     ; Desired - Ambient

        btfsc STATUS, STATUS_Z_POSITION
        goto Compare_Frac

        ; Z=0
        ; C=1 -> Desired > Ambient
        ; C=0 -> Desired < Ambient

        btfss STATUS, STATUS_C_POSITION
        goto HEATER_ON
        goto COOLER_ON


Compare_Frac:
        movf AmbientTemp_FRAC, W
        subwf DesiredTemp_FRAC, W

        btfsc STATUS, STATUS_Z_POSITION
        goto BOTH_OFF

        btfss STATUS, STATUS_C_POSITION
        goto HEATER_ON
        goto COOLER_ON


HEATER_ON:
        BANKSEL PORTE
        bcf PORTE,1               ; Fan OFF
        bsf PORTE,0               ; Heater ON
        return

COOLER_ON:
        BANKSEL PORTE
        bcf PORTE,0               ; Heater OFF
        bsf PORTE,1               ; Fan ON
        return

BOTH_OFF:
        BANKSEL PORTE
        bcf PORTE,0
        bcf PORTE,1
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
        goto    d2_loop
        decfsz  d1, F
        goto    d1_loop
        return


; --------------------------------------------------
; MODULE INCLUDES
; --------------------------------------------------
#include "temp_adc.asm"
#include "display.asm"
#include "keypad.asm"
#include "uart_board1.asm"

END MAIN
