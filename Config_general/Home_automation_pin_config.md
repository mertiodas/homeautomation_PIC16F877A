# HOME AUTOMATION PROJECT - PIN CONFIGURATION (R2_1)

---

## BOARD #1: AIR CONDITIONER SYSTEM (COM11)
**PIC Microcontroller:** PIC16F877A  
**Goal:** Temperature Control and User Input (Keypad)

| Peripheral Module    | Component Pin       | I/O Type     | PIC Pin            | Pin Function / Constraint         |
|----------------------|----------------------|--------------|--------------------|-----------------------------------|
| Temperature System   | Temp (LM35)          | Analog In    | RA0                | AN0 (Ambient Temp Read)           |
|                      | Heater               | Digital Out  | RE0                | Controls Heater                   |
|                      | Cooler               | Digital Out  | RE1                | Controls Fan/Cooler               |
|                      | Tach (Fan Spd)       | Timer In     | RC0                | T1CKI (Fan Speed Count)           |
| Keypad               | Rows (L1-L4)         | Digital In   | RB0-RB3            | Keypad Rows                       |
|                      | Columns (C1-C4)      | Digital Out  | RB4-RB7            | Keypad Columns                    |
| 7-Segment Display    | Segments (a-g, dp)   | Digital Out  | RD0-RD7            | 8 Segments (DP is RD4)            |
|                      | Select (D1-D4)       | Digital Out  | RE2, RA3, RA4, RA5 | 4 Digit Selectors                 |
| UART IO Module       | P2-RX (Receive)      | Serial In    | RC6                | PIC Hardware RX Pin               |
|                      | P3-TX (Transmit)     | Serial Out   | RC7                | PIC Hardware TX Pin               |
| UART Config          | Port                 | N/A          | COM11               | Serial Connection to PC           |

---

## BOARD #2: CURTAIN CONTROL SYSTEM (COM6)
**PIC Microcontroller:** PIC16F877A  
**Goal:** Curtain Motor Control, Light/Outdoor Sensing, LCD Display

| Peripheral Module    | Component Pin       | I/O Type         | PIC Pin          | Pin Function / Constraint         |
|----------------------|----------------------|------------------|------------------|-----------------------------------|
| UART IO Module       | P2-RX (Receive)      | Serial In        | RC7              | PIC Hardware RX Pin               |
|                      | P3-TX (Transmit)     | Serial Out       | RC6              | PIC Hardware TX Pin               |
| Step Motor           | Pin 1 - Pin 4        | Digital Out      | RD0-RD3          | Motor Control Coils               |
|                      | Home                 | Digital In       | RC1              | Motor Limit Switch (0% Status)    |
| BMP180               | SCL / SDA            | I²C Clock/Data   | RC3 / RC4        | I²C Protocol Pins                 |
| LDR Light Sensor     | A0                   | Analog In        | RA1              | AN1 (Light Intensity)             |
| Potentiometer        | POT1                 | Analog In        | RA2              | AN2 (Desired Curtain Status Set)  |
| LCD hd44780          | RS / EN              | Digital Out      | RE0 / RE1        | LCD Control Pins                  |
|                      | D4 - D7              | Digital Out      | RB0-RB3          | LCD Data Bus (4-bit mode)         |
| UART Config          | Port                 | N/A              | COM6             | Serial Connection to PC           |

---

