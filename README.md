# WebTV/MSN TV ROM Part Assembler

A Perl script written by Eric MacDonald (eMac) that assembles `.rom` (app ROM) and `.brom` (boot ROM) upgrade parts downloaded from the WebTV/MSN TV service into a full .o binary. Originally named "WebTV Build/TellyScript Decompression Tool," but that name is awfully generic and the script as far as we know doesn't handle TellyScripts anyway.

The script itself hasn't been majorly messed with outside of fixing a mistake where the .o file was written to the input directory instead of the output directory. Currently only tested on Windows machines, but from glancing at the source code it should theoretically work on macOS/Linux as well.

This tool is being uploaded for educational purposes, as to have some documentation on the WebTV ROM parts. And also in the event that un-assembled WebTV/MSN TV builds come our way and we need a way to assemble them. :p

## How to Use

- Make sure you have Perl installed on your machine before proceeding. For Windows users, ActivePerl is recommended: https://www.activestate.com/products/perl/downloads/

- In the same directory the assembler script is in (`decompressTool.pl`), you must create two folders named "in" and "out" (THIS IS IMPORTANT! IF THE `out` FOLDER ISN'T PRESENT, THE SCRIPT WON'T RUN PROPERLY.). Fill the `in` folder with the necessary ROM parts of your target WebTV/MSN TV build.

- In the command line, type in `perl decompressTool.pl`. The script will automatically go through the given ROM parts and write either an `_approm.o` or `_bootstraprom.o` file in the `out` folder, depending on what type of ROM you're dealing with.

- Enjoy your newly assembled ROM!