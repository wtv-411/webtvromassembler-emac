# WebTV/MSN TV ROM Part Assembler

A Perl script written by Eric MacDonald (a.k.a. eMac) that assembles `.rom` (app ROM) and `.brom` (boot ROM) upgrade parts downloaded from the WebTV/MSN TV service into a full .o binary. Originally named "WebTV Build/TellyScript Decompression Tool", but that name is awfully vague and the script as far as I could tell doesn't handle TellyScripts anyway.

The script itself hasn't been majorly messed with outside of fixing an error where the .o file was written to the input directory instead of the output directory. Currently only tested on Windows machines, but from glancing at the source code it should work on macOS and Linux as well.

This script is being uploaded here as a mirror for educational purposes to have some documentation on the WebTV/MSN TV upgrade parts, and also in the event that anyone needs to assemble WebTV/MSN TV builds from ROM parts (i.e., old Classic/bf0app builds available online). I do not claim any ownership of the code uploaded here.

This repository won't be actively updated. Feel free to fork this if you want to make your own additions to the code.

## How to Use

- Make sure you have Perl installed on your machine before proceeding. For Windows users, ActivePerl is recommended: https://www.activestate.com/products/perl/downloads/

- In the same directory the assembler script is in (`decompressTool.pl`), you must create two folders named `in` (for input) and `out` (for output of the resulting .o binary). **YOU MUST CREATE THE `out` FOLDER, OR ELSE THE SCRIPT WON'T RUN PROPERLY**. Fill the `in` folder with the necessary ROM parts from your target WebTV/MSN TV build.

- In the command line, type in `perl decompressTool.pl`. The script will automatically go through the given ROM parts and write either an `_approm.o` or `_bootstraprom.o` file in the `out` folder, depending on what type of ROM you gave to the script.

- Enjoy your newly assembled ROM!