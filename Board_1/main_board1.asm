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
AmbientTemp_INT:   DS 1        ; Ambient temperature value
DesiredTemp_INT:   DS 1        ; Desired (set) temperature
FanSpeed_RPS:      DS 1        ; Fan speed value

NUM_1: DS 1                   ; Display digit 1 (tens)
NUM_2: DS 1                   ; Display digit 2 (ones + decimal point)
NUM_3: DS 1                   ; Display digit 3 (always '0')

D1_VAR: DS 1                  ; Delay helper variable
D2_VAR: DS 1                  ; Display refresh counter
D3_VAR: DS 1                  ; Temporary calculation variable

MODE_COUNT: DS 1              ; 0: Ambient, 1: Desired, 2: Fan
LOOP_TIMER: DS 1              ; Counter used for mode switching timing


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
        ;include "uart_board1.asm"
	
; =========================
; MAIN
; =========================
MAIN:
        call init_ports_and_config

        ; === CHANGE VALUES FROM HERE ===
        movlw 35
        movwf AmbientTemp_INT

        movlw 25
        movwf DesiredTemp_INT

        movlw 45
        movwf FanSpeed_RPS

        clrf  MODE_COUNT
        clrf  LOOP_TIMER

MAIN_LOOP:
        call Temperature_Control_Logic

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
; DISPLAY DATA PREPARATION (DYNAMIC)
; Format: two digits + decimal point + 0  =>  XX.0
; NUM_1 = tens digit (7-seg)
; NUM_2 = ones digit + decimal point (7-seg | 0x80)
; NUM_3 = '0' (7-seg)
; ======================================================

SET_AMBIENT_DATA:
        movf AmbientTemp_INT, W
        call VALUE_TO_XX_DOT_0
        return

SET_DESIRED_DATA:
        movf DesiredTemp_INT, W
        call VALUE_TO_XX_DOT_0
        return

SET_FAN_DATA:
        movf FanSpeed_RPS, W
        call VALUE_TO_XX_DOT_0
        return


; ======================================================
; Input: W = 0..99 (values above 99 behave as last two digits)
; Output: NUM_1, NUM_2, NUM_3 contain 7-segment codes
; ======================================================
VALUE_TO_XX_DOT_0:
        movwf D3_VAR            ; Copy input value

        ; Tens digit = value / 10
        clrf NUM_1              ; Tens digit (as number)
V10_LOOP:
        movlw 10
        subwf D3_VAR, F
        btfss STATUS, 0
        goto V10_END
        incf NUM_1, F
        goto V10_LOOP

V10_END:
        addwf D3_VAR, F         ; Restore remainder, D3_VAR = ones digit

        ; Ones digit
        movf D3_VAR, W
        movwf NUM_2             ; Ones digit (as number)

        ; Convert digits to 7-segment codes
        movf NUM_1, W
        call DIGIT_TO_7SEG
        movwf NUM_1

        movf NUM_2, W
        call DIGIT_TO_7SEG
        iorlw 0x80              ; Add decimal point (same as original code)
        movwf NUM_2

        movlw 0x3F              ; '0'
        movwf NUM_3
        return


; ======================================================
; DIGIT_TO_7SEG
; Input: W = 0..9
; Output: W = 7-segment code
; ======================================================
DIGIT_TO_7SEG:
        movwf D1_VAR
        movlw high(SEG_TABLE)
        movwf PCLATH
        movf D1_VAR, W
        goto SEG_TABLE

SEG_TABLE:
        addwf PCL, F
        retlw 0x3F ; 0
        retlw 0x06 ; 1
        retlw 0x5B ; 2
        retlw 0x4F ; 3
        retlw 0x66 ; 4
        retlw 0x6D ; 5
        retlw 0x7D ; 6
        retlw 0x07 ; 7
        retlw 0x7F ; 8
        retlw 0x6F ; 9


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

        BANKSEL PORTA
        clrf PORTA
        return


; =========================
; DISPLAY DRIVER (MULTIPLEXING)
; =========================
REFRESH_DISPLAY_FAST:
        movlw 10
        movwf D2_VAR
L_REF:
        BANKSEL PORTA
        movlw 0x08          ; RA3 - Digit 1
        movwf PORTA
        BANKSEL PORTD
        movf NUM_1, W
        movwf PORTD
        call SHORT_DELAY

        BANKSEL PORTA
        movlw 0x10          ; RA4 - Digit 2
        movwf PORTA
        BANKSEL PORTD
        movf NUM_2, W
        movwf PORTD
        call SHORT_DELAY

        BANKSEL PORTA
        movlw 0x20          ; RA5 - Digit 3
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

        END
