; ======================================================
; MODULE: keypad.asm  (BANK2 udata, iskelet)
; ======================================================

        PSECT keypad_code, class=CODE, delta=2

INIT_Keypad:
        ; (Gerekli donan?m yoksa bo? b?rak?yoruz)
        return

Keypad_Interrupt_Handler:
        ; RB port de?i?imi vs. i?lemleri burada olurdu
        return
