; ======================================================
; MODULE: keypad.asm
; AUTHOR: HILAL ONGOR
; TASK: Keypad Scanning, Parsing, Validation (10.0-50.0)
; COMPATIBILITY: Matches main_board1.asm (Shared Memory Logic)
; NOTE: NO 'END' DIRECTIVE as requested
; ======================================================

        PROCESSOR 16F877A
        #include <xc.inc>

; ============================================================
; EXTERNAL DECLARATIONS (Main dosyasından gelen değişkenler)
; ============================================================
        ; Bu değişkenlere sen YAZACAKSIN, Display buradan OKUYACAK
        EXTERN _DesiredTemp_INT
        EXTERN _DesiredTemp_FRAC
        
        ; Keypad modülü için Main'de ayrılmış özel değişkenler
        EXTERN _KEY_VAL, _LAST_KEY, _STATE
        EXTERN _DIGIT1, _DIGIT2, _DIGIT_FRAC
        EXTERN _TEMP_CALC, _HAS_DOT
        EXTERN _DELAY_VAR, _DELAY_VAR2

; ============================================================
; GLOBAL DECLARATIONS (Main'e açılan fonksiyonlar)
; ============================================================
        GLOBAL _INIT_Keypad
        GLOBAL _Keypad_Process
        GLOBAL _Keypad_Interrupt_Handler

; ============================================================
; CODE SECTION
; ============================================================
        PSECT text_keypad,local,class=CODE,delta=2

; --------------------------------------------------
; INIT_Keypad
; Sistem açılışında çağrılır, değişkenleri temizler
; --------------------------------------------------
_INIT_Keypad:
        BANKSEL _STATE
        clrf    _STATE          ; State 0: Bekleme Modu (A tuşu bekleniyor)
        clrf    _KEY_VAL
        clrf    _DIGIT1
        clrf    _DIGIT2
        clrf    _DIGIT_FRAC
        return

; --------------------------------------------------
; Keypad_Interrupt_Handler
; ISR içinden çağrılır (Kesme bayrağını yönetmek için)
; --------------------------------------------------
_Keypad_Interrupt_Handler:
        BANKSEL PORTB
        movf    PORTB, W        ; Portu oku (Mismatch condition temizlemek için)
        return

; --------------------------------------------------
; Keypad_Process
; Main Loop içinde sürekli döner
; --------------------------------------------------
_Keypad_Process:
        ; 1. Tuş Tara
        call    SCAN_KEYPAD
        
        BANKSEL _KEY_VAL
        movf    _KEY_VAL, W
        btfsc   STATUS, 2       ; Eğer tuş yoksa (0), geri dön
        return

        ; 2. Titreme Önleme (Debounce)
        call    DELAY_MS_KEY
        
        ; 3. Tuşu Kaydet
        BANKSEL _KEY_VAL
        movf    _KEY_VAL, W
        BANKSEL _LAST_KEY
        movwf   _LAST_KEY

        ; 4. 'A' Tuşu Kontrolü (Her zaman RESET atar ve girişi başlatır)
        movf    _LAST_KEY, W
        xorlw   'A'
        btfsc   STATUS, 2
        goto    State_0_Idle
        
        ; --- STATE MACHINE (Durum Makinesi) ---
        BANKSEL _STATE
        movf    _STATE, W
        
        xorlw   0
        btfsc   STATUS, 2
        goto    State_0_Idle    ; 'A' bekleme durumu
        
        movf    _STATE, W
        xorlw   1
        btfsc   STATUS, 2
        goto    State_1_Digit1  ; İlk rakam (Onlar basamağı)

        movf    _STATE, W
        xorlw   2
        btfsc   STATUS, 2
        goto    State_2_Digit2  ; İkinci rakam (Birler basamağı)

        movf    _STATE, W
        xorlw   3
        btfsc   STATUS, 2
        goto    State_3_Dot     ; Nokta (.)

        movf    _STATE, W
        xorlw   4
        btfsc   STATUS, 2
        goto    State_4_Frac    ; Küsürat rakamı
        
        movf    _STATE, W
        xorlw   5
        btfsc   STATUS, 2
        goto    State_5_Enter   ; Onay (#)
        
        return

; --- DURUMLAR ---

State_0_Idle:
        ; Sadece 'A' tuşuna izin ver
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   'A'
        btfss   STATUS, 2
        return                  ; 'A' değilse çık
        
        ; 'A' basıldı: Değişkenleri sıfırla ve girişi başlat
        BANKSEL _DIGIT1
        clrf    _DIGIT1
        clrf    _DIGIT2
        clrf    _DIGIT_FRAC
        
        BANKSEL _STATE
        movlw   1
        movwf   _STATE
        return

State_1_Digit1:
        ; İlk Rakamı Al
        call    GET_NUMERIC_VAL
        movwf   _TEMP_CALC
        incf    _TEMP_CALC, W   ; Hata kontrolü
        btfsc   STATUS, 2
        return                  ; Sayı değilse çık
        
        BANKSEL _TEMP_CALC
        movf    _TEMP_CALC, W
        BANKSEL _DIGIT1
        movwf   _DIGIT1
        
        BANKSEL _STATE
        movlw   2
        movwf   _STATE
        return

State_2_Digit2:
        ; İkinci Rakamı veya Noktayı Al
        
        ; Nokta mı basıldı?
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   '*'             ; Keypad'de '*' tuşu nokta (.) kabul edilir
        btfsc   STATUS, 2
        goto    Dot_Pressed_Early

        ; Sayı mı basıldı?
        call    GET_NUMERIC_VAL
        movwf   _TEMP_CALC
        incf    _TEMP_CALC, W
        btfsc   STATUS, 2
        return
        
        BANKSEL _TEMP_CALC
        movf    _TEMP_CALC, W
        BANKSEL _DIGIT2
        movwf   _DIGIT2
        
        BANKSEL _STATE
        movlw   3
        movwf   _STATE
        return

Dot_Pressed_Early:
        ; Tek haneden sonra nokta basıldı (Örn: "5.")
        ; Digit1=5, Digit2=0 kalır. Doğrudan Küsürat adımına geç.
        BANKSEL _STATE
        movlw   4
        movwf   _STATE
        return

State_3_Dot:
        ; Nokta Bekle
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   '*'
        btfss   STATUS, 2
        return
        
        BANKSEL _STATE
        movlw   4
        movwf   _STATE
        return

State_4_Frac:
        ; Küsürat Rakamını Al
        call    GET_NUMERIC_VAL
        movwf   _TEMP_CALC
        incf    _TEMP_CALC, W
        btfsc   STATUS, 2
        return
        
        BANKSEL _TEMP_CALC
        movf    _TEMP_CALC, W
        BANKSEL _DIGIT_FRAC
        movwf   _DIGIT_FRAC
        
        BANKSEL _STATE
        movlw   5
        movwf   _STATE
        return

State_5_Enter:
        ; Kare (#) Tuşu Bekle (Onaylamak için)
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        xorlw   '#'
        btfss   STATUS, 2
        return
        
        ; Doğrulama ve Kaydetme
        goto    VALIDATE_AND_UPDATE

; --------------------------------------------------
; VALIDATE & UPDATE (Doğrulama ve Kayıt)
; Kural: 10.0 <= Sıcaklık <= 50.0
; --------------------------------------------------
VALIDATE_AND_UPDATE:
        ; 1. Onlar Basamağı (_DIGIT1) Kontrolü
        BANKSEL _DIGIT1
        movf    _DIGIT1, W
        sublw   0
        btfsc   STATUS, 2       ; Eğer 0 ise (0x.x) -> HATA (<10)
        goto    Invalid_Input
        
        movf    _DIGIT1, W
        sublw   5
        btfss   STATUS, 0       ; Eğer 5'ten büyükse (6,7,8,9) -> HATA (>59)
        goto    Invalid_Input
        
        ; Eğer 5 ise detaylı kontrol
        movf    _DIGIT1, W
        xorlw   5
        btfss   STATUS, 2
        goto    Valid_Range     ; 1,2,3,4 ise GEÇERLİ
        
        ; Onlar=5. Birler=0 olmalı.
        BANKSEL _DIGIT2
        movf    _DIGIT2, W
        xorlw   0
        btfss   STATUS, 2       ; 0 değilse (51, 52...) -> HATA
        goto    Invalid_Input
        
        ; Onlar=5, Birler=0. Küsürat=0 olmalı (Tam 50.0)
        BANKSEL _DIGIT_FRAC
        movf    _DIGIT_FRAC, W
        xorlw   0
        btfss   STATUS, 2       ; Küsürat varsa (50.1) -> HATA
        goto    Invalid_Input
        
Valid_Range:
        ; --- ORTAK HAFIZAYI GÜNCELLE ---
        ; Formül: DesiredTemp_INT = (D1 * 10) + D2
        
        BANKSEL _DIGIT1
        movf    _DIGIT1, W
        movwf   _TEMP_CALC
        
        ; 10 ile çarpma (x8 + x2 algoritması)
        bcf     STATUS, 0
        rlf     _TEMP_CALC, F   ; x2
        movf    _TEMP_CALC, W   ; 2 katını sakla
        
        bcf     STATUS, 0
        rlf     _TEMP_CALC, F   ; x4
        bcf     STATUS, 0
        rlf     _TEMP_CALC, F   ; x8
        
        addwf   _TEMP_CALC, F   ; x8 + x2 = x10
        
        BANKSEL _DIGIT2
        movf    _DIGIT2, W
        BANKSEL _TEMP_CALC
        addwf   _TEMP_CALC, W   ; W = Tam Sayı Sonuç
        
        ; Main değişkenine yaz (Display buradan okuyacak)
        BANKSEL _DesiredTemp_INT
        movwf   _DesiredTemp_INT
        
        ; Küsüratı yaz
        BANKSEL _DIGIT_FRAC
        movf    _DIGIT_FRAC, W
        BANKSEL _DesiredTemp_FRAC
        movwf   _DesiredTemp_FRAC
        
        goto    Reset_State

Invalid_Input:
        ; Hatalı giriş, kaydetmeden sıfırla
        goto    Reset_State

Reset_State:
        BANKSEL _STATE
        clrf    _STATE
        return

; --------------------------------------------------
; YARDIMCI: GET_NUMERIC_VAL
; Tuşu sayıya çevirir (ASCII -> Sayı)
; --------------------------------------------------
GET_NUMERIC_VAL:
        BANKSEL _LAST_KEY
        movf    _LAST_KEY, W
        
        xorlw   '0'
        btfsc   STATUS, 2
        retlw   0
        
        movf    _LAST_KEY, W
        xorlw   '1'
        btfsc   STATUS, 2
        retlw   1
        
        movf    _LAST_KEY, W
        xorlw   '2'
        btfsc   STATUS, 2
        retlw   2
        
        movf    _LAST_KEY, W
        xorlw   '3'
        btfsc   STATUS, 2
        retlw   3
        
        movf    _LAST_KEY, W
        xorlw   '4'
        btfsc   STATUS, 2
        retlw   4
        
        movf    _LAST_KEY, W
        xorlw   '5'
        btfsc   STATUS, 2
        retlw   5
        
        movf    _LAST_KEY, W
        xorlw   '6'
        btfsc   STATUS, 2
        retlw   6
        
        movf    _LAST_KEY, W
        xorlw   '7'
        btfsc   STATUS, 2
        retlw   7
        
        movf    _LAST_KEY, W
        xorlw   '8'
        btfsc   STATUS, 2
        retlw   8
        
        movf    _LAST_KEY, W
        xorlw   '9'
        btfsc   STATUS, 2
        retlw   9
        
        retlw   0xFF

; --------------------------------------------------
; SCAN_KEYPAD
; Tuşları tarar ve ASCII kodunu döner
; --------------------------------------------------
SCAN_KEYPAD:
        BANKSEL _KEY_VAL
        clrf    _KEY_VAL

        ; Sütun 1
        BANKSEL PORTB
        movlw   b'11101111'     
        movwf   PORTB
        nop
        nop
        btfss   PORTB, 0
        retlw   '1'
        btfss   PORTB, 1
        retlw   '4'
        btfss   PORTB, 2
        retlw   '7'
        btfss   PORTB, 3
        retlw   '*'

        ; Sütun 2
        movlw   b'11011111'     
        movwf   PORTB
        nop
        nop
        btfss   PORTB, 0
        retlw   '2'
        btfss   PORTB, 1
        retlw   '5'
        btfss   PORTB, 2
        retlw   '8'
        btfss   PORTB, 3
        retlw   '0'

        ; Sütun 3
        movlw   b'10111111'     
        movwf   PORTB
        nop
        nop
        btfss   PORTB, 0
        retlw   '3'
        btfss   PORTB, 1
        retlw   '6'
        btfss   PORTB, 2
        retlw   '9'
        btfss   PORTB, 3
        retlw   '#'

        ; Sütun 4
        movlw   b'01111111'     
        movwf   PORTB
        nop
        nop
        btfss   PORTB, 0
        retlw   'A'
        btfss   PORTB, 1
        retlw   'B'
        btfss   PORTB, 2
        retlw   'C'
        btfss   PORTB, 3
        retlw   'D'

        ; Portu eski haline getir
        movlw   0xF0
        movwf   PORTB
        
        retlw   0

; --------------------------------------------------
; DELAY_MS_KEY
; Gecikme fonksiyonu
; --------------------------------------------------
DELAY_MS_KEY:
        BANKSEL _DELAY_VAR
        movlw   0xFF
        movwf   _DELAY_VAR
loop1:  decfsz  _DELAY_VAR, F
        goto    loop1
        return

