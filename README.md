# f256_xdev
CrossDev Firmware for F256Jr, and F256K computer

The idea here is that this acts as the initial kernel "program", it looks to see if it needs to do something.  If it doesn't, it just launched the next program in the firmware.

Current features:

CrossDev Springboard (if you load a PGX, or PGZ file using FoenixMgr, detect this, and launch it)

PCopy - If you have copied a file into ram using FoenixMgr, and we see it there, save it out to the SDCARD

