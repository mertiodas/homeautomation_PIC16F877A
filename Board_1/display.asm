; ======================================================
; MODULE: display.asm
; AUTHOR: SAFIULLAH SEDIQI 152120211031
; 7-Segment Display - Multiplexed 4 Digit
; Shows: Desired Temp, Ambient Temp, Fan Speed (2 sec intervals)
; Corrected for pins:
; Segments: RD0-RD7, Digit selects: RC1-RC4
; ======================================================

; --- Local RAM (BANK3) ---
        PSECT udata_bank3
Digit1:         DS 1
Digit2:         DS 1
Digit3:         DS 1
Digit4:         DS 1
Current_Digit:  DS 1
Multiplex_Counter: DS 1
Display_Counter_2sec: DS 1

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
        BANKSEL PORTC
        bcf     PORTC, 1
        bcf     PORTC, 2
        bcf     PORTC, 3
        bcf     PORTC, 4
        
        return

; --------------------------------------------------
; Display_Multiplex_Routine
; Call this frequently from main loop
; Cycles through 4 digits rapidly + handles 2-sec rotation
; --------------------------------------------------
Display_Multiplex_Routine:
        BANKSEL Multiplex_Counter
        incf    Multiplex_Counter, F
        movf    Multiplex_Counter, W
        xorlw   200
        btfss   STATUS, STATUS_Z_POSITION
        goto    Multiplex_Show_Digit
        
        clrf    Multiplex_Counter
        incf    Current_Digit, F
        movf    Current_Digit, W
        xorlw   4
        btfss   STATUS, STATUS_Z_POSITION
        goto    Multiplex_Show_Digit
        clrf    Current_Digit

        incf    Display_Counter_2sec, F
        movf    Display_Counter_2sec, W
        xorlw   100
        btfss   STATUS, STATUS_Z_POSITION
        goto    Multiplex_Show_Digit

        clrf    Display_Counter_2sec
        call    Update_Display_Data

Multiplex_Show_Digit:
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

Show_Desired_Temp:
        BANKSEL DesiredTemp_INT
        movf    DesiredTemp_INT, W
        call    Split_Into_Digits_2
        movwf   Digit1
        
        movf    DesiredTemp_FRAC, W
        movwf   Digit3
        
        movlw   10
        movwf   Digit4
        return

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

Show_Fan_Speed:
        BANKSEL FanSpeed_RPS
        movf    FanSpeed_RPS, W
        call    Split_Into_Digits_3
        movwf   Digit1
        
        movlw   10
        movwf   Digit4
        return

; --------------------------------------------------
; Split_Into_Digits_2
Split_Into_Digits_2:
        movwf   Digit2
        clrf    Digit1
Split2_Loop:
        movf    Digit2, W
        sublw   9
        btfsc   STATUS, STATUS_C_POSITION
        goto    Split2_Done
        
        movlw   10
        subwf   Digit2, F
        incf    Digit1, F
        goto    Split2_Loop

Split2_Done:
        movf    Digit1, W
        return

; --------------------------------------------------
; Split_Into_Digits_3
Split_Into_Digits_3:
        movwf   Digit3
        clrf    Digit1
        clrf    Digit2

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
        movf    Digit1, W
        return

; --------------------------------------------------
; Select_And_Show_Current_Digit
Select_And_Show_Current_Digit:
        BANKSEL PORTC
        bcf     PORTC, 1
        bcf     PORTC, 2
        bcf     PORTC, 3
        bcf     PORTC, 4
        
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
        BANKSEL PORTC
        bsf     PORTC, 1
        return

Show_D2:
        movf    Digit2, W
        call    Segment_Table
        BANKSEL Display_Data_Select
        movf    Display_Data_Select, W
        xorlw   2
        btfsc   STATUS, STATUS_Z_POSITION
        goto    No_DP_D2
        
        BANKSEL PORTD
        iorlw   0x80
        movwf   PORTD
        goto    Enable_D2

No_DP_D2:
        BANKSEL PORTD
        movwf   PORTD

Enable_D2:
        BANKSEL PORTC
        bsf     PORTC, 2
        return

Show_D3:
        movf    Digit3, W
        call    Segment_Table
        BANKSEL PORTD
        movwf   PORTD
        BANKSEL PORTC
        bsf     PORTC, 3
        return

Show_D4:
        movf    Digit4, W
        call    Segment_Table
        BANKSEL PORTD
        movwf   PORTD
        BANKSEL PORTC
        bsf     PORTC, 4
        return
