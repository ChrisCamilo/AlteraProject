# AlteraProject
### This is an undergraduate project of Microprocessors II discipline in the Computer Science program at São Paulo State University to create a console application that accepts user commands and for each command, perform a certain action on the Altera DE2 board

The project was implemented using the Nios II processor assembly language through the use of the DE2 board produced by Altera and through the available online simulator, CPUlator (https://cpulator.01xz.net/?sys=nios-de2).
This project aimed to use all the topics presented, with the exception of the AD/DA converter. Therefore, issues such as bit manipulation, memory accesses, interrupt I/O, programmed I/O (polling) and other concepts, as well as the use of input and output peripherals (1 push button, 1 slider switch, red LEDs, seven-segment displays and VGA video buffer) were extensively exploited throughout functions and subroutines.

| Command         | Action         |
| :-------------: | :------------- |
| 00 XX           | Turns on XX-th red led |
| 01 XX           | Turns off XX-th red led |
| 10              | Starts an animation with red LEDs given by the state of the switch SW0: if down, clockwise; if upwards, counterclockwise. The animation consists of turning on a red LED for 200ms, turning it off and then turning on its neighbor (right or left, depending on the state of switch SW0). This process must be continued repeatedly for all red LEDs |
| 11              | Stops LED animation |
| 20              | Starts a stopwatch using 4 7-segment displays. Additionally, the KEY1 button must control the stopwatch pause: if counting in progress, it must be paused; if paused, count must be resumed |
| 21              | Cancels the stopwatch |
| 30              | Performs the digital processing of the UNESP logo image in the VGA pixel buffer |
| 31              | Clears the VGA pixel buffer, ie erases any rendered image |

