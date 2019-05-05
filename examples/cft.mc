// -*- mcasm -*-
// This is one version of the CFT CPU's microcode.
// You can read more about it here: http://www.bedroomlan.org/hardware/cft
//
// CAUTION: Many of the comments about the hardware are likely to be
// heavily misleading. The microcode itself is correct and tested,
// though.

// Define the opcodes for convenience.

#define TRAP 0000
#define IOT 0001
#define LOAD 0010
#define STORE 0011
#define IN 0100
#define OUT 0101
#define JMP 0110
#define JSR 0111
#define ADD 1000
#define AND 1001
#define OR 1010
#define XOR 1011
#define OP1 1100
#define OP2 1101
#define UNUSED2 1110
#define LI 1111

//              MODES
// Instruction  Literal  Direct  Indirect  Autoindex    Special
// ----------------------------------------------------------------------------
// TRAP            X         X                 X
// IOT             X         X                 X
// LOAD            X         X                 X
// STORE           X         X                 X
// IN              X         X                 X
// OUT             X         X                 X
// JMP             X         X                 X
// JSR             X         X                 X
// ADD                       X       X         X
// AND                       X       X         X
// OR                        X       X         X
// XOR                       X       X         X
// OP1                                                    X
// OP2                                                    X
// LI              X
// ----------------------------------------------------------------------------


///////////////////////////////////////////////////////////////////////////////
//
// Conditions: fields embedded in the MicroROM address.
//
///////////////////////////////////////////////////////////////////////////////

cond RST:1;                   // Resetting
cond INT:1;                   // Servicing an interrupt request
cond OP:4;                    // The opcode field of the IR.
cond I:1;                     // The indirection field of the IR.
cond SKIP:1;                  // The skip flag from the skip logic.
cond INC:1;		      // The IR points to an autoincrement location.

// The uaddr field of the address is mandatory. This just sets its width.
cond uaddr:4;

///////////////////////////////////////////////////////////////////////////////
//
// Signals: outputs of the MicroROM
//
///////////////////////////////////////////////////////////////////////////////

// Register order: MAR, IR, A, DR, PC, dbus.
//
// UNIT   LHS   RHS
// ----------------
// DBUS   001   001
// MAR    010
// PC     011   011
// IR     100
// DR     101   100
// A      110   101
// AGL          010
// CONST        110   When OP[0] = 0: CONST = 0000. When OP[0] = 1: CONST = 0001.
// ALU          111

field  R_UNIT         = ____________________XXXX; // Read unit field
//signal r_dbus       = ....................0001; // Read from the data bus
signal r_agl          = ....................0010; // Read from address generation logic
signal r_pc           = ....................0011; // Read from PC
signal r_dr           = ....................0100; // Read from DR
signal r_a            = ....................0101; // Read from the Accumulator
//signal r_spare6     = ....................0110; //   ** RESERVED
//signal r_spare7     = ....................0111; //   ** RESERVED
//
signal alu_add        = ....................1000; // ALU: Read from the Adder unit
signal alu_and        = ....................1001; // ALU: Read from the AND unit
signal alu_or         = ....................1010; // ALU: Read from the OR unit
signal alu_xor        = ....................1011; // ALU: Read from the XOR unit
signal alu_roll       = ....................1100; // ALU: Read from the ROLL unit (roll op controlled by IR)
signal alu_not        = ....................1101; // ALU: Read from the NOT unit
signal r_cs1          = ....................1110; // ALU: Read from the Constant Store (bank 1)
signal r_cs2          = ....................1111; // ALU: Read from the Constant Store (bank 2)

field  W_UNIT         = _________________XXX____; // Write unit field
//signal w_dbus       = .................001....; // Write to the data bus
signal w_mar          = .................010....; // Write to the MAR
signal w_pc           = .................011....; // Write to the PC
signal w_ir           = .................100....; // Write to the IR
signal w_dr           = .................101....; // Write to the DR
signal w_a            = .................110....; // Write to the Accumulator
signal w_alu          = .................111....; // Write to the ALU's B port

field  OP_IF          = _____________XXXX_______; // OPx IF field
signal if9            = .............0111.......; // SKIP = IR[9]
signal if8            = .............0110.......; // SKIP = IR[8]
signal if7            = .............0101.......; // SKIP = IR[7]
signal if6            = .............0100.......; // SKIP = IR[6]
signal if5            = .............0011.......; // SKIP = IR[5]
signal if4            = .............0010.......; // SKIP = IR[4]
signal if3            = .............0001.......; // SKIP = IR[3]
signal ifroll         = .............1011.......; // SKIP = roll_logic(IR[2:0])
signal ifbranch       = .............1111.......; // SKIP = skip_logic(IR[3:0])

signal /inc_a         = ............1...........; // Step the A counter.
signal cpl            = ...........1............; // Complement L (active low)
signal /cll           = ..........1.............; // Clear L flag
signal /sti           = .........1..............; // Set I flag
signal /cli           = ........1...............; // Clear I flag
signal /pc_inc        = .......1................; // Step the PC

signal /inc_dr        = ......1.................; // Inc/Dec DR (for autoinc/autodec mode)
//signal RESERVED     = .....1..................; // 
signal /mem           = ....1...................; // Memory access
signal /io            = ...1....................; // Input/Output enable
signal /R             = ..1.....................; // Memory read
signal /W             = .1......................; // Memory write
signal /END           = 1.......................; // Reset microprogram, go to fetch state.

// ALU ops:
//
// 001 ADD
// 010 AND
// 011 OR
// 100 XOR
// 101 NOT
// 110 ROLLS (RBL, RBR, RNL, RNR)

// Also:
//
// OP1/2 bit testing logic (3 bits)
//
// * OP1: L <- 0
// * OP1: L <- ~L
// * OP1: A <- ~A
// * OP1: INC <L,A>
// * OP1: RBL
// * OP1: RBR
// * OP1: RNL
// * OP1: RNR
// * OP1: HALT
//
// * OP2: Skip logic enable
// * OP2: CLI
// * OP2: SEI


///////////////////////////////////////////////////////////////////////////////
//
// Crucial microcode macros.
//
///////////////////////////////////////////////////////////////////////////////


// This macro defines a memory read cycle, i.e. steps 2 to 4 above.
#define _MEMREAD(_areg, _dreg) \
    w_mar, r_##_areg; \
    /MEM, /R; \
    w_##_dreg, hold
    //-/DAB, -/MEM, -/IO, -/R, -/W
    

// At the end of this macro, /DAB, and /MEM are still active. It's assumed that
// the caller of the macro will deactivate the lines, deselecting the
// memory. This may not be necessary, though.

// This macro deselects the memory and terminates memory access. Needed between memory read cycles.
#define _DESEL \
    -/MEM, -/IO, -/R, -/W	   // 5. Deselect I/O and memory.


#define _MEMWRITE(_areg, _dreg) \
    w_mar, r_##_areg; \
    r_##_dreg, /mem, /w; \
    r_##_dreg, /mem


// This macro implements step 1. Useful for JMP-like instructions and literal
// addressing. And of course as a basis for direct and indirect modes.

#define _FETCH_IR \
	_MEMREAD(PC, IR), /pc_inc


#define _FETCH_DIRECT \
	_FETCH_IR; \
	_MEMREAD(agl, DR)

#define _FETCH_LITERAL _FETCH_DIRECT


// This macro takes care of most of the autoincrement
// microsteps. NOTE: this can be combined with the last step of
// another macro (as long as it doesn't modify the DR), as the only
// thing it does on its first microstep is to increase the DR.

#define _AUTOINC \
	r_agl, w_mar, /inc_dr; \
        r_dr, /mem, /w;	\
        r_dr, /mem


///////////////////////////////////////////////////////////////////////////////
//
// Fill the entire microcode ROM with /end signals.
//
// This removes a glitch with Autoincrement modes: at the end of autoincrement
// microinstructions, control briefly jumps to the non-autoincrement variety,
// so we need to fill with /end.
//
// This microprogram doesn't clobber others because the microcode assembler
// assembles microprograms in order of increasing specificity (decreasing
// number of don't-care [X] values.)
//
///////////////////////////////////////////////////////////////////////////////

start INT=X, RST=X, OP=XXXX, I=X, SKIP=X, INC=X;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;

///////////////////////////////////////////////////////////////////////////////
//
// The Microcode itself.
//
///////////////////////////////////////////////////////////////////////////////

// We'll be adding fetch cycles with no execution cycles to all available
// microprogram positions in the microcode ROM. This way, no matter what its
// state, the CPU will always be able to fetch an instruction. Upon fetching,
// the microcode ROM address (fed from the IR, which the fetch cycle modifies),
// will jump to the right microcode program. We don't NEED to use separate
// microprograms for direct and indirect modes, since, at the time of the fetch
// cycle, the I flag (which is about to be fetched along with the rest of the
// IR) is invalid anyway.
//
// Assumption: the steps that fetch the IR from memory are identical for both
// direct (I=0) and indirect mode (I=1).

start INT=X, RST=1, OP=XXXX, I=X, SKIP=X, INC=X;
      _FETCH_IR;		// Just fetch an instruction.


///////////////////////////////////////////////////////////////////////////////
//
// Reset code
//
///////////////////////////////////////////////////////////////////////////////

// The reset sequence is little more than a fetch sequence, but we pad
// it with a few NOPs.

start INT=X, RST=0, OP=XXXX, I=X, SKIP=X, INC=X;
      w_pc, r_cs1, /cli, /end;
      hold;
      hold;
      hold;
      hold;	
      /end;


///////////////////////////////////////////////////////////////////////////////
//
// Interrupt service code
//
///////////////////////////////////////////////////////////////////////////////

start INT=0, RST=1, OP=XXXX, I=X, SKIP=X, INC=X;
      /cli, _MEMWRITE(cs1, pc);	// Store PC at location 0001.
      w_pc, r_cs2, /end;		// Jump to location ffff.
      // TODO: JUMP TO ISR here.
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;
      /end;

///////////////////////////////////////////////////////////////////////////////
//
// Load instruction.
//
///////////////////////////////////////////////////////////////////////////////

// LITERAL MODE INSTRUCTION: agl used for I=0, direct mode for I=1.
start INT=1, RST=1, OP=LOAD, I=0, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(agl, A);		// A <- mem[agl].
      _DESEL, /end;	 // The fetch cycle begins with a memory read.

// Indirect mode.
start INT=1, RST=1, OP=LOAD, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;		// Fetch the address and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(dr, A);		// A <- mem[DR].
      _DESEL, /end;

// FIXED: Autoindex mode
start INT=1, RST=1, OP=LOAD, I=1, SKIP=X, INC=1;
      _FETCH_IR;                // Fetch cycle
      _MEMREAD(agl, dr);        // DR <- mem[agl]
      //_DESEL;			// Deselect all memory signals and wait.
      _MEMREAD(dr, a);		// Indirection step: A <- mem[DR]
      _AUTOINC;			// mem[agl] <- ++DR
      _DESEL, /end;	        // The fetch cycle begins with a memory read.



///////////////////////////////////////////////////////////////////////////////
//
// STORE instruction.
//
///////////////////////////////////////////////////////////////////////////////

// LITERAL MODE INSTRUCTION: agl used for I=0, direct mode for I=1.
start INT=1, RST=1, OP=STORE, I=0, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand.
      _MEMWRITE(agl, a);	// mem[agl] <- A
      _DESEL, /end;		// The fetch cycle begins with a memory read.

// Indirect mode.
start INT=1, RST=1, OP=STORE, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;		// Fetch the instruction and operand.
      _MEMWRITE(dr, a);		// mem[DR] <- A
      _DESEL, /end;

// FIXED: Autoindex mode
start INT=1, RST=1, OP=STORE, I=1, SKIP=X, INC=1;
      _FETCH_IR;                // Fetch cycle
      _MEMREAD(agl, dr);        // DR <- mem[agl]
      //_DESEL;			// Deselect all memory signals and wait.
      _MEMWRITE(dr, a);		// Indirection step: mem[DR] <- A
      _AUTOINC;			// mem[agl] <- ++DR
      _DESEL, /end;	        // The fetch cycle begins with a memory read.


///////////////////////////////////////////////////////////////////////////////
//
// IOT instruction: OUT A, wait, then IN a. Implements CPU extensions
// or memory-mapped 'functions'.
//
///////////////////////////////////////////////////////////////////////////////

// LITERAL MODE INSTRUCTION: agl used for I=0, direct mode for I=1.
start INT=1, RST=1, OP=IOT, I=0, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand.
      w_mar, r_agl;
      r_a, /io, /w;
      r_a, /io;
      
      // The CPU may be inhibited here to get wait states.

      w_a, /io, /r;
      /io, /r, /end;


// Direct mode.
start INT=1, RST=1, OP=IOT, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;		// Fetch the instruction and operand.
      w_mar, r_dr;		// Indirection.
      r_a, /io, /w;
      r_a, /io;

      // The CPU may be inhibited here to get wait states.

      w_a, /io, /r;
      /io, /r, /end;

// FIXED: Autoindex mode.
start INT=1, RST=1, OP=IOT, I=1, SKIP=X, INC=1;
      _FETCH_IR;                // Fetch cycle
      _MEMREAD(agl, dr);        // DR <- mem[agl]
      //_DESEL;			// Deselect all memory signals and wait.
      w_mar, r_dr;		// Indirection: io[dr] <- A
      r_a, /io, /w;
      r_a, /io;

      // The CPU may be inhibited here to get wait states.

      w_a, /io, /r;
      /io, /r, /end;
      _AUTOINC;			// mem[agl] <- ++DR
      _DESEL, /end;	        // The fetch cycle begins with a memory read.
      


///////////////////////////////////////////////////////////////////////////////
//
// IN instruction.
//
///////////////////////////////////////////////////////////////////////////////

// LITERAL MODE INSTRUCTION: agl used for I=0, direct mode for I=1.
start INT=1, RST=1, OP=IN, I=0, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand.
      w_mar, r_agl;
      w_a, /io, /r;
      _DESEL, /end;	// Hold the address and data bus.

// Direct mode. (I=1, one level of indirection)
start INT=1, RST=1, OP=IN, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;		// Fetch the instruction and operand.
      w_mar, r_agl;
      w_a, /io, /r;
      _DESEL, /end;	// Hold the address and data bus.

// Autoindex mode.
start INT=1, RST=1, OP=IN, I=1, SKIP=X, INC=0;
      _FETCH_IR;                // Fetch cycle
      _MEMREAD(agl, dr);        // DR <- mem[agl]
      //_DESEL;			// Deselect all memory signals and wait.

      w_mar, r_dr;
      w_a, /io, /r;
      ///io, /r;

      _AUTOINC;			// mem[agl] <- ++DR
      _DESEL, /end;	        // The fetch cycle begins with a memory read.



///////////////////////////////////////////////////////////////////////////////
//
// OUT instruction.
//
///////////////////////////////////////////////////////////////////////////////

// LITERAL MODE INSTRUCTION: agl used for I=0, direct mode for I=1.
start INT=1, RST=1, OP=OUT, I=0, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand.
      w_mar, r_agl;
      r_a, /io, /w;
      r_a, /io, /end;

// Direct mode.
start INT=1, RST=1, OP=OUT, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;		// Fetch the instruction and operand.
      w_mar, r_dr;		// Indirection.
      r_a, /io, /w;
      r_a, /io, /end;

// FIXED: Autoindex mode.
start INT=1, RST=1, OP=OUT, I=1, SKIP=X, INC=1;
      _FETCH_IR;                // Fetch cycle
      _MEMREAD(agl, dr);        // DR <- mem[agl]
      //_DESEL;			// Deselect all memory signals and wait.

      w_mar, r_dr;		// was: r_agl (why?)
      r_a, /io, /w;
      r_a, /io;

      _AUTOINC;			// mem[agl] <- ++DR
      _DESEL, /end;	        // The fetch cycle begins with a memory read.


///////////////////////////////////////////////////////////////////////////////
//
// ADD instruction.
//
///////////////////////////////////////////////////////////////////////////////

// The ALU operation is decoded directly for the IR. Further, the ALU is
// always enabled and always performs operations between A and DR. There's
// very little we need to do here but latch data from the ALU back to A.
//
// We use a register for the output of the ALU to ensure the result is stable
// before sticking it back into A.
start INT=1, RST=1, OP=ADD, I=0, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(agl, alu);       // B <- mem[DR].
      w_a, alu_add, /end;	// A <- A + B.
 
start INT=1, RST=1, OP=ADD, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;		// Fetch the address and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(dr, alu);	// B <- mem[DR].
      w_a, alu_add, /end;	// A <- A + B.

// FIXED: Autoincrement
start INT=1, RST=1, OP=ADD, I=1, SKIP=X, INC=1;
      _FETCH_LITERAL;		// Fetch the address and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(dr, alu);	// B <- mem[DR].
      w_a, alu_add;		// A <- A + B.
      _AUTOINC;			// Autoindex
      _DESEL, /end;	        // The fetch cycle begins with a memory read.


///////////////////////////////////////////////////////////////////////////////
//
// AND instruction.
//
///////////////////////////////////////////////////////////////////////////////

start INT=1, RST=1, OP=AND, I=0, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(agl, alu);       // B <- mem[DR].
      w_a, alu_and, /end;	// A <- A & B.
 
start INT=1, RST=1, OP=AND, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;		// Fetch the address and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(dr, alu);	// B <- mem[DR].
      w_a, alu_and, /end;	// A <- A & B.

// FIXED: Autoincrement
start INT=1, RST=1, OP=AND, I=1, SKIP=X, INC=1;
      _FETCH_LITERAL;		// Fetch the address and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(dr, alu);	// B <- mem[DR].
      w_a, alu_and;		// A <- A & B.
      _AUTOINC;			// Autoindex
      _DESEL, /end;	        // The fetch cycle begins with a memory read.

///////////////////////////////////////////////////////////////////////////////
//
// OR instruction.
//
///////////////////////////////////////////////////////////////////////////////

start INT=1, RST=1, OP=OR, I=0, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(agl, alu);       // B <- mem[DR].
      w_a, alu_or, /end;	// A <- A | B.
 
start INT=1, RST=1, OP=OR, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;		// Fetch the address and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(dr, alu);	// B <- mem[DR].
      w_a, alu_or, /end;	// A <- A | B.

// FIXED: Autoincrement
start INT=1, RST=1, OP=OR, I=1, SKIP=X, INC=1;
      _FETCH_LITERAL;		// Fetch the address and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(dr, alu);	// B <- mem[DR].
      w_a, alu_or;		// A <- A | B.
      _AUTOINC;			// Autoindex
      _DESEL, /end;	        // The fetch cycle begins with a memory read.


///////////////////////////////////////////////////////////////////////////////
//
// XOR instruction.
//
///////////////////////////////////////////////////////////////////////////////

start INT=1, RST=1, OP=XOR, I=0, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(agl, alu);       // B <- mem[DR].
      w_a, alu_xor, /end;	// A <- A | B.
 
start INT=1, RST=1, OP=XOR, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;		// Fetch the address and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(dr, alu);	// B <- mem[DR].
      w_a, alu_xor, /end;	// A <- A | B.

// FIXED: Autoincrement
start INT=1, RST=1, OP=XOR, I=1, SKIP=X, INC=1;
      _FETCH_LITERAL;		// Fetch the address and operand.
      //_DESEL;			// Prepare for the next memory read.
      _MEMREAD(dr, alu);	// B <- mem[DR].
      w_a, alu_xor;		// A <- A | B.
      _AUTOINC;			// Autoindex
      _DESEL, /end;	        // The fetch cycle begins with a memory read.



///////////////////////////////////////////////////////////////////////////////
//
// JMP instruction.
//
///////////////////////////////////////////////////////////////////////////////

// The JMP instruction simply transfers the result of the address generation
// logic to the PC.
//
// The addressing mode of this one is literal! JMP 0000 doesn't involve reading
// the value of mem[0000] from memory, we just set the PC to that address.
//
// JMP I 0000 *DOES* involve reading mem[0000], though. Basically, JMP-like
// instructions involve one less memory read cycle.


// LITERAL MODE INSTRUCTION: agl used for I=0, direct mode for I=1.

start INT=1, RST=1, OP=JMP, I=0, SKIP=X, INC=X;
      _FETCH_IR;	 // Fetch the instruction and operand. That's
	    	         // all we need.
      w_pc, r_agl, /end;	 // Set the PC from AGL(<PR,IR.operand>)

// The _FETCH macro fetches the IR and operand, and then loads into DR the
// value stored in mem[operand]. This is all the indirection we need here (one
// less indirection step than normal).

start INT=1, RST=1, OP=JMP, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;	// Fetch the instruction and operand.
      w_pc, r_dr, /end;	// Set the PC from DR.

start INT=1, RST=1, OP=JMP, I=1, SKIP=X, INC=1;
      _FETCH_LITERAL;	        // Fetch the instruction and operand. Autoincrement.
      w_pc, r_dr;	        // Set the PC from DR.
      _AUTOINC;		        // Autoindex
      _DESEL, /end;	        // The fetch cycle begins with a memory read.


///////////////////////////////////////////////////////////////////////////////
//
// JSR instruction.
//
///////////////////////////////////////////////////////////////////////////////

// The JSR instruction saves the current PC to memory location 0000
// and performs a jump to the specified address.

start INT=1, RST=1, OP=JSR, I=0, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand. That's
				// all we need.
      _MEMWRITE(cs1, PC);	// Store PC at location 0000.
      w_pc, r_agl, /end;	// Set the PC from AGL(<PR,IR.operand>)

// The _FETCH macro fetches the IR and operand, and then loads into DR the
// value stored in mem[operand]. This is all the indirection we need here (one
// less indirection step than normal).

start INT=1, RST=1, OP=JSR, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;		// Fetch the instruction and operand.
      _DESEL;                   // Deselect memory before writing.
      _MEMWRITE(cs1, PC);	// Store PC at location 0000.
      w_pc, r_dr, /end;		// Set the PC from DR.

start INT=1, RST=1, OP=JSR, I=1, SKIP=X, INC=1;
      _FETCH_LITERAL;	        // Fetch the instruction and operand.
      _MEMWRITE(cs1, PC);	// Store PC at location 0000.
      w_pc, r_dr;
      _AUTOINC;		        // Autoindex
      _DESEL, /end;	        // The fetch cycle begins with a memory read.


///////////////////////////////////////////////////////////////////////////////
//
// TRAP instruction.
//
///////////////////////////////////////////////////////////////////////////////

// The TRAP instruction saves the current PC to memory location 0001
// and performs a jump to the specified address.

start INT=1, RST=1, OP=TRAP, I=0, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand. That's
				// all we need.
      _MEMWRITE(cs2, pc);	// Store PC at location 0001.
      w_pc, r_agl, /end;	// Set the PC from AGL(<PR,IR.operand>)

// The _FETCH macro fetches the IR and operand, and then loads into DR the
// value stored in mem[operand]. This is all the indirection we need here (one
// less indirection step than normal).

start INT=1, RST=1, OP=TRAP, I=1, SKIP=X, INC=0;
      _FETCH_LITERAL;		// Fetch the instruction and operand.
      //_DESEL;           // Clear interrupts (implicit memory deselection)
      _MEMWRITE(cs2, pc);	// Store PC at location 0001.
      w_pc, r_dr, /end;	        // Set the PC from DR.

start INT=1, RST=1, OP=TRAP, I=1, SKIP=X, INC=1;
      _FETCH_LITERAL;		// Fetch the instruction and operand.
      //_DESEL;           // Clear interrupts (implicit memory deselection)
      _MEMWRITE(cs2, pc);	// Store PC at location 0001.
      w_pc, r_dr;
      _AUTOINC;		        // Autoindex
      _DESEL, /end;	        // The fetch cycle begins with a memory read.



///////////////////////////////////////////////////////////////////////////////
//
// LI instruction.
//
///////////////////////////////////////////////////////////////////////////////

// The LI instruction operates in literal mode, just like the JMP instruction,
// but loads the Accumulator with its result, not the PC. The indirection bit
// is ignored for this, but the R flag is honoured.

start INT=1, RST=1, OP=LI, I=X, SKIP=X, INC=X;
      _FETCH_IR;		// Fetch the instruction and operand. That's
				// all we need.
      w_a, r_agl, /end; 	// A <- AGL(<PR,IR.operand>)



///////////////////////////////////////////////////////////////////////////////
//
// OP1 instruction.
//
///////////////////////////////////////////////////////////////////////////////

// PDP-8-style microcoded instruction. No addressing modes or AGL
// used, but SKIP is used to determine what gets executed and what not.
//
// Note: ifX microcode instructions apply the condition to the NEXT
// microstep, which is why we list them last. SKIP=1 means 'don't
// skip'.
//
// Bit allocation and sequencing:
//
//                     roll
//             98765 3///
// CLA = OP1  '1---------		; if9: A <- 0
// CLL = OP1  '-1--------		; if8: L <- 0
// NOT = OP1  '--1-------		; if7: A <- NOT A
// INC = OP1  '---1------		; if6: <L,A> <- <L,A> + 1
// NTL = OP1  '----1-----		; if5: L <- NOT L
// RBL = OP1  '-------010		; ifroll: <L,A> <- <L,A> >> 1
// RBR = OP1  '-------001		; <L,A> <- <L,A> << 1
// RNL = OP1  '-------110		; <L,A> <- <L,A> >> 4
// RNR = OP1  '-------101		; <L,A> <- <L,A> << 4
//
// (*) The final /end is necessary when the computer comes out of the
// HALT state.

start INT=1, RST=1, OP=OP1, I=X, SKIP=1, INC=X;
      _FETCH_IR;
      if9;		      // 1. Fetch the instruction and operand.
      w_a, r_cs1, if8;		// 2. If bit 9: clear A
      /cll, if7;		// 3. If bit 8: clear L
      w_a, alu_not, if6;	// 4. If bit 7: complement A
      /inc_a, if5;		// 5. If bit 6: increment A
      cpl, ifroll;		// 6. If bit 5: complement L
      w_a, alu_roll;		// 7. If roll: well, roll.
      /end;			// (*)

start INT=1, RST=1, OP=OP1, I=X, SKIP=0, INC=X;
      _FETCH_IR;
      if9;		// 1. Fetch the instruction and operand.
      if8;			// 2. If bit 9: clear A
      if7;			// 3. If bit 8: clear L
      if6;			// 4. If bit 7: complement A
      if5;			// 5. If bit 6: increment A
      ifroll;			// 6. If bit 5: complement L
      if3;			// 7. If roll: well, roll.
      /end;			// (*)

///////////////////////////////////////////////////////////////////////////////
//
// OP2 instruction.
//
///////////////////////////////////////////////////////////////////////////////

// PDP-8-style microcoded instruction. No addressing modes or AGL
// used, but SKIP is used to determine what gets executed and what not.
//
// Note: ifX microcode instructions apply the condition to the NEXT
// microstep, which is why we list them last. SKIP=1 means 'don't
// skip'.
//
// Bit allocation and sequencing:
//
//                    branch
//             987654////
// xxxLPG =  OP2 '1---------		; A <= PR *NOT USED*
// xxxSPG =  OP2 '-1--------		; PR <= A *NOT USED*
// xxxCPG =  OP2 '--1-------		; PR <= PC *NOT USED*
// NOP =  OP2 '------0000		; 
// SNA =  OP2 '------01--		; A < 0 ==> PC++  (1)
// SZA =  OP2 '------0-1-		; A == 0 ==> PC++ (1)
// SSL =  OP2 '------0--1		; L == 1 ==> PC++ (1)
// SKIP = OP2 '------1000		; PC++
// SNN =  OP2 '------11--		; a >=0 ==> PC++   (2)
// SNZ =  OP2 '------1-1-		; A != 0 ==> PC++ (2)
// SCL =  OP2 '------1--1		; L == 0 ==> PC++ (2)
// CLA2 = OP2 '---1------		; A <- 0
// CLI =  OP2 '----1-----		; INT <= 0
// TLI =  OP2 '-----1----		; INT <= !INT
//
// (1) Conditions ORred together
// (2) Conditions ANDed together. The OR/AND logic isn't microcoded,
// it's part of the hardwired decoding of the branch bits.
//
// The branch test logic, along with the bits set in the
// microinstruction, feed the SKIP field, so SKIP handles both
// microinstruction skips and machine code branches.

// TODO: I think r_cs produces 0001 here, not 0000. Check it!
start INT=1, RST=1, OP=OP2, I=X, SKIP=1, INC=X;
      _FETCH_IR;
      if9;		// 1. Fetch the instruction and operand.
      if8;		// 2. If bit 9: A <= PR
      if7;		// 3. If bit 8: PR <= A
      ifbranch;     // 4. If bit 7: PR <= PC (note: PC <- PC)
      /pc_inc, if6;		// 5. If branching: branch (if needed)
      w_a, r_cs1, if5;		// 6. If bit 6: A <= 0
      /cli, if4;		// 7. If bit 5: I <= 0
      /sti, /end;		// 8. If bit 4: I <= 1
      /end;			// (*)

start INT=1, RST=1, OP=OP2, I=X, SKIP=0, INC=X;
      _FETCH_IR;
      if9;		// 1. Fetch the instruction and operand.
      if8;			// 2. If bit 9: A <= PR
      if7;			// 3. If bit 8: PR <= A
      ifbranch;		        // 4. If bit 7: PR <= PC (note: PC <- PC)
      if6;		        // 5. If branching: branch (if needed)
      if5;		        // 6. If bit 6: A <= 0
      if4;		        // 7. If bit 5: I <= 0
      /end;		        // 8. If bit 4: I <= !I
      /end;			// (*)

// End of file.
