# Reaction Game (Verilog)

This folder contains a simple HDL project implementing a reaction game.
It was designed for FPGA development boards or logic simulators and uses
three indicator LEDs, a single push button and four LEDs to display the
measured reaction time.

## Features
* One of three LEDs lights up after a random delay.
* Player must press the button as quickly as possible once the LED lights.
* Reaction time is measured in 10&nbsp;ms units and shown on four LEDs as a
  binary number (0&ndash;15).
* Pressing the button before the LED lights results in an error – all LEDs
  flash for a short time.
* A `reset` input restarts the game.

The main module is [`reaction_game.v`](reaction_game.v). The design is
self-contained and can be simulated with popular Verilog tools such as
`iverilog` or synthesized for an FPGA.
