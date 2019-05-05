# MCASM—A Microcode Assembler for Hobbyist Projects

This is a simple microcode assembler (or microassembler). It can be used to
generate wide, horizontal microcode ROMs for relatively simple CPU
architectures. It's mainly intended for hobbyists working on home-designed
CPUs. Using a description of the microcode, it generates one or more ROM,
EPROM, EEPROM, Flash et cetera images suitable for inclusion in a software
emulator, a hardware device, or for use in a hardware description language such
as Verilog or VHDL.

For a full description, please visit https://www.bedroomlan.org/projects/mcasm/.
 
This tool was written to build the microcode for my scratch-built 16-bit
minicomputer, the CFT. Read about that at https://www.bedroomlan.org/cft/.

## Requirements

To run mcasm, you will need:

* Python 3.
* The C Preprocessor (`cpp`). This usually comes with your C compiler.

## Microcode in Theory

Microcode is a collection of *microprograms*. Each microprogram depends on a
number of *conditions* and is made up of a number of *microinstructions*. Each
microinstruction is in turn made up of a number of *signal* specifications.

*Microprograms* implement basic functions. In most cases, each microprogram
will implement one machine instruction. This, of course, depends on the machine
architecture.

*Conditions* are inputs to the computer's sequencer. They include major states
of the machine such as whether an interrupt is being serviced, whether the
machine is being reset, et cetera. A microprogram counter (the offset into the
current microprogram) is also part of the conditions. Conditions may be
don't-care values. Conditions are grouped in multi-bit fields for convenience
or to define multi-bit values like opcodes. Microprograms are selected and
executed when the conditions match. The matching itself is down to the
hardware. For instance, to match an opcode field, a value from the opcode field
of the instruction register would be fed to the corresponding address lines in
a microcode ROM.

*Microinstructions* perform tasks simultaneously by directly manipulating the
sequencer by (you guessed it), signals. Signals may be asserted or
de-asserted. Some signals are active-high, others are active-low. Signals may
be grouped together into *fields* if they are semantically similar,
mutually-exclusive, or if they represent a multi-bit field such as a register
number.

This, of course, is theory. The assembler may generate microcode that is used
in vastly different ways. The architecture determines how the bits produced by
`mcasm` are interpreted in practice.

## Preprocessor

A lot of microcode writing can be repetitive, and repeating structures by hand
makes things prone to errors. Errors in microcode have potentially disastrous
effects, so `mcasm` uses `cpp`, the C Preprocessor to prepare input for
it. That makes the assembler syntax fairly C-like in some respects. As a bonus,
you get parametric macros, conditional compilation, and all the other goodies
`cpp` has to offer.

The syntax of `cpp` is beyond the scope of this article. Please refer to its
documentation.

## Syntax

Here is a very brief example of a microcode input file:

```
// Minimum Microcode file.

cond OP:4;
cond uaddr:3;

signal /MEMIO    = ....1;
signal MREAD     = ...1.;
signal MWRITE    = ..1..;

field  REGMOVE   = XX___;
signal MAR <- PC = 01...;
signal IR <- MEM = 10...;

start OP=XXXX; // A tiny fetch instruction
  /MEMIO, MREAD, MAR <- PC;   // 
  hold;                       // Same as MEMIO, MREAD, MAR <- PC
  hold, -MREAD, IR <- MEM;    // Same as MEMIO, MAR <- PC, IR <- MEM

// End of file.
```

C multi-line comments `/* ... */` and C++ single-line comments `// ...` are
both understood.

All declarations and microinstructions must end in a semicolon.

This example defines two condition fields in the ROM's address: the `OP` field,
four bits wide, and the `uaddr` field, which is three bits wide. This field is
the microprogram counter used to address the currently executing
instruction. It is mandatory to include it, but its width is completely
arbitrary. `mcasm` will warn you if any of your microprograms are too big for
the chosen size of `uaddr`. The last `cond` defined is the least significant
part of the address.

The `signal` declarations define the output of the ROM. The bitfield for each
signal is specified in binary. You may use the traditional values 0 and 1. For
increased readability, you may also use the characters `.` or `-` for zero.

Conditionals are made up of letters, numbers, and non-whitespace characters
except colons (`:`), semicolons (`;`) and equal signs (`=`).

Signal names may contain any character except the equals sign (`=`). Notably,
they may include spaces (for legibility). A signal may not start with a minus
sign (`-`).

Signals starting with a slash (`/`) are recognised as active-low signals. The
corresponding bits are inverted when the ROM bitmap is written.

Signal fields may be named for convenience. Macros to extract field values will
be added to any C output generated (in future versions, more functionality will
be attached to them). Field definitions may use `X`, `x` or `+` to specify a
bit that's included in the field, and `.`, `_`, or `-` to specify bits that are
excluded from the field.

Microprograms are declared with the `start` keyword, followed by a
comma-separated set of conditionals and their values in the format
`cond=value`. If a particular field is immaterial to a microprogram, a don't
care value may be specified using the standard electronics don't care symbol,
`X`.

After the `start` keyword and condition specification, the microprogram
follows. Each line of the microprogram defines a comma separated list of zero
or more signal names as defined previously. The order of signals in each line
does not matter. Lines are terminated with semicolons (so that, in practice,
each may span multiple actual lines in the source code).

A special keyword used in some cases is `hold`. When encountered, it indicates
that the set of signals active on the previous line should be active on the
line where `hold` appears. In this case, some signals may be deactivated by
listing them prefixed with a minus. For example, the `-MREAD` specification on
line 3 of the microprogram above turns off the `MREAD` signal.

Multiple microprograms may be specified with multiple `start` keywords. When
using don't-care values, start with the least specific (most `X` bits)
microprograms and move on to the most specific ones.

## Restrictions

`mcasm` can generate microcode for architectures where microcode jumps around a
lot, but its syntax is more suited to architectures where microcode is executed
mostly sequentially with occasional jumps. If your architecture doesn't even
have the notion of a microprogram, `mcasm` may not suit you.
