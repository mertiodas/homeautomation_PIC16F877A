; ======================================================
; FILE: main_board1.asm
; AUTHOR : SAFIULLAH SEDIQI 152120211031
; BOARD  : PIC16F877A - BOARD #1
; DESC   : Home Air Conditioner System
; ======================================================
        processor 16F877A
        #include <xc.inc>

CONFIG FOSC=XT, WDTE=OFF, PWRTE=ON, BOREN=OFF, LVP=OFF, CPD=OFF, WRT=OFF, CP=OFF


; =========================
; RAM VARIABLES
; =========================
        PSECT udata_bank0

; --- Temperature & Fan ---
AmbientTemp_INT:   DS 1        ; Ambient temperature integer (10?50)
AmbientTemp_FRAC:  DS 1        ; Ambient temperature fraction (0?9)
UART_Buf: DS 1
DesiredTemp_INT:   DS 1        ; Desired temperature integer (10?50)
DesiredTemp_FRAC:  DS 1        ; Desired temperature fraction (0?9)

FanSpeed_RPS:      DS 1        ; Fan speed (integer)

; --- Display ---
NUM_1: DS 1                   ; Tens digit
NUM_2: DS 1                   ; Ones digit + decimal point
NUM_3: DS 1                   ; Fraction digit

; --- Helpers ---
D1_VAR: DS 1
D2_VAR: DS 1
D3_VAR: DS 1

MODE_COUNT: DS 1              ; 0: Ambient, 1: Desired, 2: Fan
LOOP_TIMER: DS 1              ; Mode switching timer


; =========================
; RESET VECTOR
; =========================
        PSECT resetVec, class=CODE, delta=2
        ORG 0x00
        goto MAIN


; =========================
; CODE SECTION
; =========================
        PSECT code

        ;include "display.asm"
        ;include "keypad.asm"
        ;include "temp_adc.asm"
        


; =========================
; MAIN
; =========================
MAIN:
        call init_ports_and_config
	call INIT_UART

        ; === INITIAL VALUES ===
        movlw 35
        movwf AmbientTemp_INT
        movlw 7
        movwf AmbientTemp_FRAC        ; 35.7 °C

        movlw 25
        movwf DesiredTemp_INT
        movlw 3
        movwf DesiredTemp_FRAC        ; 25.3 °C

        movlw 45
        movwf FanSpeed_RPS

        clrf MODE_COUNT
        clrf LOOP_TIMER


; =========================
; MAIN LOOP
; =========================
MAIN_LOOP:
        ; --- CLAMP TEMPERATURE EVERY LOOP ---
        movf AmbientTemp_INT, W
        call Clamp_Temperature_10_50
        movwf AmbientTemp_INT

        movf DesiredTemp_INT, W
        call Clamp_Temperature_10_50
        movwf DesiredTemp_INT

        call Temperature_Control_Logic
	call UART_Process

        ; --- MODE SWITCHING LOGIC ---
        incf LOOP_TIMER, F
        movf LOOP_TIMER, W
        xorlw 250
        btfss STATUS, 2
        goto SHOW_CURRENT

        clrf LOOP_TIMER
        incf MODE_COUNT, F
        movf MODE_COUNT, W
        xorlw 3
        btfsc STATUS, 2
        clrf MODE_COUNT

SHOW_CURRENT:
        movf MODE_COUNT, W
        xorlw 0
        btfsc STATUS, 2
        call SET_AMBIENT_DATA

        movf MODE_COUNT, W
        xorlw 1
        btfsc STATUS, 2
        call SET_DESIRED_DATA

        movf MODE_COUNT, W
        xorlw 2
        btfsc STATUS, 2
        call SET_FAN_DATA

        call REFRESH_DISPLAY_FAST
        goto MAIN_LOOP


; ======================================================
; DISPLAY DATA PREPARATION
; ======================================================

SET_AMBIENT_DATA:
        movf AmbientTemp_INT, W
        call VALUE_TO_XX_DOT_X
        movf AmbientTemp_FRAC, W
        call DIGIT_TO_7SEG
        movwf NUM_3
        return

SET_DESIRED_DATA:
        movf DesiredTemp_INT, W
        call VALUE_TO_XX_DOT_X
        movf DesiredTemp_FRAC, W
        call DIGIT_TO_7SEG
        movwf NUM_3
        return

SET_FAN_DATA:
        movf FanSpeed_RPS, W
        call VALUE_TO_XX_DOT_0
        return


; ======================================================
; VALUE_TO_XX_DOT_X  (XX.X)
; ======================================================
VALUE_TO_XX_DOT_X:
        movwf D3_VAR

        clrf NUM_1
V10_LOOP_X:
        movlw 10
        subwf D3_VAR, F
        btfss STATUS, 0
        goto V10_END_X
        incf NUM_1, F
        goto V10_LOOP_X

V10_END_X:
        addwf D3_VAR, F
        movf D3_VAR, W
        movwf NUM_2

        movf NUM_1, W
        call DIGIT_TO_7SEG
        movwf NUM_1

        movf NUM_2, W
        call DIGIT_TO_7SEG
        iorlw 0x80
        movwf NUM_2
        return


; ======================================================
; VALUE_TO_XX_DOT_0 (Fan)
; ======================================================
VALUE_TO_XX_DOT_0:
        call VALUE_TO_XX_DOT_X
        movlw 0x3F
        movwf NUM_3
        return


; ======================================================
; DIGIT TO 7-SEG
; ======================================================
DIGIT_TO_7SEG:
        movwf D1_VAR
        movlw high(SEG_TABLE)
        movwf PCLATH
        movf D1_VAR, W
        goto SEG_TABLE

SEG_TABLE:
        addwf PCL, F
        retlw 0x3F
        retlw 0x06
        retlw 0x5B
        retlw 0x4F
        retlw 0x66
        retlw 0x6D
        retlw 0x7D
        retlw 0x07
        retlw 0x7F
        retlw 0x6F


; =========================
; PORT CONFIGURATION
; =========================
init_ports_and_config:
        BANKSEL ADCON1
        movlw 0x06
        movwf ADCON1

        BANKSEL TRISA
        clrf TRISA
        BANKSEL TRISD
        clrf TRISD
        BANKSEL TRISE
        clrf TRISE
	BANKSEL TRISC
        movlw   0x81            ; Binary 10000001
        movwf   TRISC           ; RC7=In, RC0=In, others=Out

        BANKSEL PORTA
        clrf PORTA
        return


; =========================
; DISPLAY DRIVER
; =========================
REFRESH_DISPLAY_FAST:
        movlw 10
        movwf D2_VAR
L_REF:
        BANKSEL PORTA
        movlw 0x08
        movwf PORTA
        BANKSEL PORTD
        movf NUM_1, W
        movwf PORTD
        call SHORT_DELAY

        BANKSEL PORTA
        movlw 0x10
        movwf PORTA
        BANKSEL PORTD
        movf NUM_2, W
        movwf PORTD
        call SHORT_DELAY

        BANKSEL PORTA
        movlw 0x20
        movwf PORTA
        BANKSEL PORTD
        movf NUM_3, W
        movwf PORTD
        call SHORT_DELAY

        decfsz D2_VAR, F
        goto L_REF
        return

SHORT_DELAY:
        movlw 50
        movwf D1_VAR
SD_L:
        decfsz D1_VAR, F
        goto SD_L
        return


; =========================
; HEATER / COOLER CONTROL
; =========================
Temperature_Control_Logic:
        movf AmbientTemp_INT, W
        subwf DesiredTemp_INT, W
        btfsc STATUS, 2
        goto BOTH_OFF
        btfss STATUS, 0
        goto HEATER_ON
        goto COOLER_ON

HEATER_ON:
        BANKSEL PORTE
        bcf PORTE, 1
        bsf PORTE, 0
        return

COOLER_ON:
        BANKSEL PORTE
        bcf PORTE, 0
        bsf PORTE, 1
        return

BOTH_OFF:
        BANKSEL PORTE
        bcf PORTE, 0
        bcf PORTE, 1
        return


; ======================================================
; Clamp_Temperature_10_50
; Input : W
; Output: W clamped to 10..50
; ======================================================
Clamp_Temperature_10_50:
        movwf D3_VAR

        ; if < 10 -> 10
        movlw 10
        subwf D3_VAR, W
        btfsc STATUS, 0
        goto CHECK_MAX
        movlw 10
        return

CHECK_MAX:
        ; if > 50 -> 50
        movlw 50
        subwf D3_VAR, W
        btfss STATUS, 0
        goto OK_RANGE
        movlw 50
        return

OK_RANGE:
        movf D3_VAR, W
        return

#include "uart_board1.asm"
        END
