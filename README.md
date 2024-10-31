# [Colecovision](https://en.wikipedia.org/wiki/ColecoVision) and [Sega SG-1000](https://en.wikipedia.org/wiki/SG-1000) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

### LLAPI Note
#### Atari 5800 Controller

If directions dont work for your Atari5800 controller, please report as the stick on this controller is analogic with a problematic deadzone. The LLAPI implementation translates it into digital directions (U,D,L,R) based on limits that will vary from one controller to the other.
This can be tweaked in the source code to accomodate most controllers and cover a large range of cases but we need feedbacks for this.

#### Coleco + SAC controller

If your Coleco controller is not detected, press RIGHT trigger or PURPLE button (SAC) while connecting the controller or resetting the BliSTer port

### Installation
* Copy the *.rbf file to the root of the system SD card.
* Place ROMs into Coleco folder

### Supported Filetypes
 * .col/.bin/.rom files for Coleco system
 * .sg files for SG-1000 system

Original core https://github.com/wsoltys/mist-cores/tree/master/fpga_colecovision
