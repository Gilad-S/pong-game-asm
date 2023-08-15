# Pong Game in assembly
A Pong game written in ASM, for the ADuC841 microcontroller.

_Created by Gilad Savoray, 2022-2023._


**Demonstration video:**

 [![here](https://img.youtube.com/vi/O59dhMnIBnE/mqdefault.jpg)](https://youtu.be/O59dhMnIBnE)
 
# Run & Setup
Build and compile the code for the ADuC841 (I used µVision).
Run the compiled main1.a51 on the first board, and the main2.a51 on the second board.


**Connect the two boards UART ports like so:**
  >P3.0 of board 1 <=> P3.1 of board 2

  >P3.1 of board 1 <=> P3.0 of board 2

It is recommended to unplug all pins of the serial communication port (RS-232), which can be found in the top right corner of the evaluation board, in each of the devices.


**Connect the displays (for k=1, 2):**
  >DAC0 of board k <=> Channel 1 of oscilloscope k

  >DAC1 of board k <=> Channel 2 of oscilloscope k

  >Ground the probes of the k's scope to GND of board k

Put both scopes in XY display mode.

**Connect the keypad of each board:**
```
 <Keypad view>
   C   A   E
B [1] [2] [3]
G [4] [5] [6]
F [7] [8] [9]
D [*] [0] [#]

<Pin connection view>
  A <=> P2.5
  B <=> P2.0
  C <=> P2.4
  D <=> P2.3
  E <=> P2.6
  F <=> P2.2
  G <=> P2.1

```
