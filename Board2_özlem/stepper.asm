; ============================================
; stepper.asm - Board 2 Step Motor Driver
; Motor: Unipolar Stepper (4 Coils) on RB0-RB3
; Resolution: 1% = 10 Steps (Total 1000 Steps)
; Logic: Compares DES_CURTAIN vs CURTAIN and moves motor.
; ============================================

; --- Variables (Defined in main.asm) ---
; CURTAIN_STATUS
; DES_CURTAIN_STATUS
; STEP_INDEX (0-3 for step sequence)
; TEMP_WORK (Working register)

; --------------------------------------------
; STEPPER_INIT
; Initializes motor state
; --------------------------------------------
STEPPER_INIT:
    ; Motor pins (RB0-RB3) are already configured as Output in INIT
    ; Ensure motor is stopped initially
    BANKSEL STEP_INDEX           ; Bank 0           
    CLRF    STEP_INDEX
    MOVLW   0x02		 ; Motor will be run at T=0, S=0 (for correction)
    MOVWF   STEP_INDEX
    CALL    OUTPUT_STEP		 
    BANKSEL PORTB
    MOVWF   PORTB       
    RETURN

; --------------------------------------------
; CURTAIN_LOGIC
; Main logic called from MAIN_LOOP.
; checks if movement is needed.
; --------------------------------------------
CURTAIN_LOGIC:
    ; Check if Desired == Current
    MOVF    CURTAIN_STATUS, W
    SUBWF   DES_CURTAIN_STATUS, W
    BTFSC   STATUS, 2       ; Z=1 if Equal
    RETURN                  ; No movement needed
    
    ; Check Direction (Carry Flag)
    ; SUBWF: DES - CURR
    ; If DES < CURR -> C=0 (Open Curtain)
    ; If DES > CURR -> C=1 (Close Curtain)
    BTFSS   STATUS, 0
    GOTO    MOVE_OPEN       ; Go towards 0%

    ; Else, MOVE_CLOSE (Go towards 100%)
    GOTO    MOVE_CLOSE
    
; --------------------------------------------
; MOVE_CLOSE (Increase %)
; Rotates motor CCW 
; Moves 10 steps to increase Status by 1%
; --------------------------------------------
MOVE_CLOSE:
    ; We need to move 10 steps to change 1%
    ; Loop 10 times
    MOVLW   10
    MOVWF   TEMP_WORK       ; Use TEMP_WORK as loop counter

CLOSE_LOOP:
    CALL    STEP_CW         ; Perform 1 physical step
    CALL    STEP_DELAY      ; Wait for motor
    DECFSZ  TEMP_WORK, F
    GOTO    CLOSE_LOOP
    BANKSEL CURTAIN_STATUS
    ; After 10 steps, increment status
    INCF    CURTAIN_STATUS, F
    
    RETURN

; --------------------------------------------
; MOVE_OPEN (Decrease %)
; Rotates motor CCW
; Moves 10 steps to decrease Status by 1%
; --------------------------------------------
MOVE_OPEN:
    ; Loop 10 times
    MOVLW   10
    MOVWF   TEMP_WORK

OPEN_LOOP:
    CALL    STEP_CCW        ; Perform 1 physical step
    CALL    STEP_DELAY
    BANKSEL TEMP_WORK
    DECFSZ  TEMP_WORK, F
    GOTO    OPEN_LOOP
    BANKSEL CURTAIN_STATUS
    ; After 10 steps, decrement status
    DECF    CURTAIN_STATUS, F
    RETURN

; ============================================
; LOW LEVEL STEPPING FUNCTIONS
; Sequence: 1->2->4->8 (Wave Drive)
; ============================================

STEP_CW:
    BANKSEL STEP_INDEX
    ; Increment Step Index (0-1-2-3-0...)
    INCF    STEP_INDEX, F
    MOVF    STEP_INDEX, W
    ANDLW   0x03
    MOVWF   STEP_INDEX
    CALL    OUTPUT_STEP
    BANKSEL PORTB
    MOVWF   PORTB
    RETURN

STEP_CCW:
    BANKSEL STEP_INDEX
    ; Decrement Step Index (0-3-2-1-0...)
    DECF    STEP_INDEX, F
    MOVF    STEP_INDEX, W
    ANDLW   0x03
    MOVWF   STEP_INDEX
    CALL    OUTPUT_STEP
    BANKSEL PORTB
    MOVWF   PORTB
    RETURN
    
OUTPUT_STEP:
    BANKSEL STEP_INDEX
    MOVF    STEP_INDEX, W        ; W = 0..3
    ; W == 0 
    XORLW   0
    BTFSC   STATUS, 2
    GOTO    STEP_PAT0
    ; W == 1 
    MOVF    STEP_INDEX, W
    XORLW   1
    BTFSC   STATUS, 2
    GOTO    STEP_PAT1
    ; W == 2 
    MOVF    STEP_INDEX, W
    XORLW   2
    BTFSC   STATUS, 2
    GOTO    STEP_PAT2
    ; W == 3
STEP_PAT3:
    MOVLW   0b00000001          ; RB0
    RETURN

STEP_PAT2:
    MOVLW   0b00000010          ; RB1
    RETURN

STEP_PAT1:
    MOVLW   0b00000100          ; RB2
    RETURN

STEP_PAT0:
    MOVLW   0b00001000          ; RB3
    RETURN
    
; --------------------------------------------
; STEP_DELAY
; --------------------------------------------
STEP_DELAY:
    BANKSEL STEP_DELAY_OUT
    MOVLW   0x20
    MOVWF   STEP_DELAY_OUT
DELAY_OUTER:
    MOVLW   0x20
    MOVWF   STEP_DELAY_IN
DELAY_INNER:
    DECFSZ  STEP_DELAY_IN, F
    GOTO    DELAY_INNER
    DECFSZ  STEP_DELAY_OUT, F
    GOTO    DELAY_OUTER
    RETURN