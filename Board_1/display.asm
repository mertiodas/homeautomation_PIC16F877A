; ======================================================
; MODULE: display.asm
; AUTHOR: SAFIULLAH SEDIQI 152120211031
; 7-Segment Display - Multiplexed 4 Digit
; Shows: Desired Temp, Ambient Temp, Fan Speed (2 sec intervals)
; ======================================================

; --- Local RAM (BANK3) ---
        PSECT udata_bank3
Digit1:         DS 1    ; En soldaki digit
Digit2:         DS 1
Digit3:         DS 1
Digit4:         DS 1    ; En sa?daki digit
Current_Digit:  DS 1    ; 0-3 aras? hangi digit aktif
Multiplex_Counter: DS 1 ; Multiplexing h?z sayac?
Display_Counter_2sec: DS 1 ; 2 saniye sayac?

; --- Code Section ---
        PSECT display_code, class=CODE, delta=2

; 7-Segment lookup table (0-9 + decimal point)
; Segment order: dp-g-f-e-d-c-b-a (RD7-RD0)
Segment_Table:
        addwf   PCL, F
        retlw   0x3F    ; 0
        retlw   0x06    ; 1
        retlw   0x5B    ; 2
        retlw   0x4F    ; 3
        retlw   0x66    ; 4
        retlw   0x6D    ; 5
        retlw   0x7D    ; 6
        retlw   0x07    ; 7
        retlw   0x7F    ; 8
        retlw   0x6F    ; 9
        retlw   0x80    ; Decimal point (dp)


; --------------------------------------------------
; INIT_Display
; Initialize display variables and ports
; --------------------------------------------------
INIT_Display:
        BANKSEL Digit1
        clrf    Digit1
        clrf    Digit2
        clrf    Digit3
        clrf    Digit4
        clrf    Current_Digit
        clrf    Multiplex_Counter
        clrf    Display_Counter_2sec
        
        ; Turn off all digits initially
        BANKSEL PORTE
        bcf     PORTE, 2    ; D1 off
        BANKSEL PORTA
        bcf     PORTA, 3    ; D2 off
        bcf     PORTA, 4    ; D3 off
        bcf     PORTA, 5    ; D4 off
        
        return


; --------------------------------------------------
; Display_Multiplex_Routine
; Call this frequently from main loop
; Cycles through 4 digits rapidly + handles 2-sec rotation
; --------------------------------------------------
Display_Multiplex_Routine:
        ; Increment multiplex counter
        BANKSEL Multiplex_Counter
        incf    Multiplex_Counter, F
        movf    Multiplex_Counter, W
        xorlw   200                     ; ~200 loops = reasonable delay
        btfss   STATUS, STATUS_Z_POSITION
        goto    Multiplex_Show_Digit
        
        ; Reset counter and switch to next digit
        clrf    Multiplex_Counter
        incf    Current_Digit, F
        movf    Current_Digit, W
        xorlw   4
        btfss   STATUS, STATUS_Z_POSITION
        goto    Multiplex_Show_Digit
        clrf    Current_Digit           ; Wrap around to digit 0
        
        ; Also increment 2-second counter
        incf    Display_Counter_2sec, F
        movf    Display_Counter_2sec, W
        xorlw   100                     ; Adjust this for ~2 seconds
        btfss   STATUS, STATUS_Z_POSITION
        goto    Multiplex_Show_Digit
        
        ; 2 seconds passed - update display data
        clrf    Display_Counter_2sec
        call    Update_Display_Data

Multiplex_Show_Digit:
        ; Show current digit
        call    Select_And_Show_Current_Digit
        return


; --------------------------------------------------
; Update_Display_Data
; Rotates between 3 displays every 2 seconds:
; Mode 0: Desired Temp (XX.X)
; Mode 1: Ambient Temp (XX.X)
; Mode 2: Fan Speed (XXX rps - no decimal)
; --------------------------------------------------
Update_Display_Data:
        BANKSEL Display_Data_Select
        incf    Display_Data_Select, F
        movf    Display_Data_Select, W
        xorlw   3
        btfss   STATUS, STATUS_Z_POSITION
        goto    Check_Mode
        clrf    Display_Data_Select

Check_Mode:
        movf    Display_Data_Select, W
        xorlw   0
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Show_Desired_Temp
        
        movf    Display_Data_Select, W
        xorlw   1
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Show_Ambient_Temp
        
        goto    Show_Fan_Speed

; Mode 0: Desired Temperature (XX.X)
Show_Desired_Temp:
        BANKSEL DesiredTemp_INT
        movf    DesiredTemp_INT, W
        call    Split_Into_Digits_2     ; Returns tens in W, ones in Digit2
        movwf   Digit1
        
        movf    DesiredTemp_FRAC, W
        movwf   Digit3
        
        movlw   10                      ; Blank digit 4
        movwf   Digit4
        return

; Mode 1: Ambient Temperature (XX.X)
Show_Ambient_Temp:
        BANKSEL AmbientTemp_INT
        movf    AmbientTemp_INT, W
        call    Split_Into_Digits_2
        movwf   Digit1
        
        movf    AmbientTemp_FRAC, W
        movwf   Digit3
        
        movlw   10
        movwf   Digit4
        return

; Mode 2: Fan Speed (XXX rps)
Show_Fan_Speed:
        BANKSEL FanSpeed_RPS
        movf    FanSpeed_RPS, W
        call    Split_Into_Digits_3     ; Returns hundreds, tens, ones
        ; W = hundreds, Digit2 = tens, Digit3 = ones
        movwf   Digit1
        
        movlw   10                      ; Blank digit 4
        movwf   Digit4
        return


; --------------------------------------------------
; Split_Into_Digits_2
; Input: W = 0-99
; Output: W = tens digit, Digit2 = ones digit
; --------------------------------------------------
Split_Into_Digits_2:
        movwf   Digit2          ; Store original value
        clrf    Digit1          ; Tens counter
Split2_Loop:
        movf    Digit2, W
        sublw   9
        btfsc   STATUS, STATUS_C_POSITION
        goto    Split2_Done     ; If Digit2 <= 9, done
        
        movlw   10
        subwf   Digit2, F
        incf    Digit1, F
        goto    Split2_Loop

Split2_Done:
        movf    Digit1, W       ; Return tens in W
        return


; --------------------------------------------------
; Split_Into_Digits_3
; Input: W = 0-255
; Output: W = hundreds, Digit2 = tens, Digit3 = ones
; --------------------------------------------------
Split_Into_Digits_3:
        movwf   Digit3          ; Store original
        clrf    Digit1          ; Hundreds
        clrf    Digit2          ; Tens

Split3_Hundreds:
        movf    Digit3, W
        sublw   99
        btfsc   STATUS, STATUS_C_POSITION
        goto    Split3_Tens
        
        movlw   100
        subwf   Digit3, F
        incf    Digit1, F
        goto    Split3_Hundreds

Split3_Tens:
        movf    Digit3, W
        sublw   9
        btfsc   STATUS, STATUS_C_POSITION
        goto    Split3_Done
        
        movlw   10
        subwf   Digit3, F
        incf    Digit2, F
        goto    Split3_Tens

Split3_Done:
        movf    Digit1, W       ; Return hundreds in W
        return


; --------------------------------------------------
; Select_And_Show_Current_Digit
; Shows the current digit on 7-segment display
; --------------------------------------------------
Select_And_Show_Current_Digit:
        ; Turn off all digits first
        BANKSEL PORTE
        bcf     PORTE, 2
        BANKSEL PORTA
        bcf     PORTA, 3
        bcf     PORTA, 4
        bcf     PORTA, 5
        
        ; Select which digit to show
        BANKSEL Current_Digit
        movf    Current_Digit, W
        xorlw   0
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Show_D1
        
        movf    Current_Digit, W
        xorlw   1
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Show_D2
        
        movf    Current_Digit, W
        xorlw   2
        btfsc   STATUS, STATUS_Z_POSITION
        goto    Show_D3
        
        goto    Show_D4

Show_D1:
        movf    Digit1, W
        call    Segment_Table
        BANKSEL PORTD
        movwf   PORTD
        BANKSEL PORTE
        bsf     PORTE, 2        ; D1 on (RE2)
        return

Show_D2:
        movf    Digit2, W
        call    Segment_Table
        ; Add decimal point for temperature displays
        BANKSEL Display_Data_Select
        movf    Display_Data_Select, W
        xorlw   2               ; If mode != 2 (not fan speed)
        btfsc   STATUS, STATUS_Z_POSITION
        goto    No_DP_D2
        
        BANKSEL PORTD
        iorlw   0x80            ; Add decimal point
        movwf   PORTD
        goto    Enable_D2
        
No_DP_D2:
        BANKSEL PORTD
        movwf   PORTD
        
Enable_D2:
        BANKSEL PORTA
        bsf     PORTA, 3        ; D2 on (RA3)
        return

Show_D3:
        movf    Digit3, W
        call    Segment_Table
        BANKSEL PORTD
        movwf   PORTD
        BANKSEL PORTA
        bsf     PORTA, 4        ; D3 on (RA4)
        return

Show_D4:
        movf    Digit4, W
        call    Segment_Table
        BANKSEL PORTD
        movwf   PORTD
        BANKSEL PORTA
        bsf     PORTA, 5        ; D4 on (RA5)
        return