; ============================================
; config.inc - PIC16F877A Configuration Bits
; This file must be included in main.asm.
; ============================================

    CONFIG FOSC = XT        ; Oscillator Selection bits (XT oscillator)
    CONFIG WDTE = OFF       ; Watchdog Timer Enable bit (WDT disabled)
    CONFIG PWRTE = ON       ; Power-up Timer Enable bit (PWRT enabled)
    CONFIG BOREN = ON       ; Brown-out Reset Enable bit (BOR enabled)
    CONFIG LVP = OFF        ; Low-Voltage Programming disabled (CRITICAL!)
    CONFIG CPD = OFF        ; Data EEPROM Memory Code Protection off
    CONFIG WRT = OFF        ; Flash Program Memory Write Enable off
    CONFIG CP = OFF         ; Flash Program Memory Code Protection off


