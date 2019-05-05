// -*- conf -*-
// Minimum Microcode file.

cond OP:4;
cond uaddr:3;

signal /MEMIO     = ....1;
signal MREAD      = ...1.;
signal MWRITE     = ..1..;
field  REGMOVE    = XX___;
signal MAR <- PC  = 01...;
signal IR <- MEM  = 10...;

start OP=XXXX; // A tiny fetch instruction
  /MEMIO, MREAD, MAR <- PC;   //
  hold;                       // Same as MEMIO, MREAD, MAR <- PC
  hold, -MREAD, IR <- MEM;    // Same as MEMIO, MAR <- PC, IR <- MEM

// End of file.
