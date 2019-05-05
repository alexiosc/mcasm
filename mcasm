#!/usr/bin/python2.6
#coding:utf-8

"""
A microcode generator/assembler for Microcode ROMs.

Blank lines are ignored. Comments are marked with a hash (#), which cause
the rest of the line to be ignored. Everything else must be one of three
things, corresponding to these three sections:

* Conditionals: inputs to the Microcode ROM.
* Signals: outputs from the Microcode ROM.
* Microprograms: the contents of the ROM.

==Conditionals==

Conditionals are defined with the 'cond' instruction. E.g:

  cond OP:4

defines an input called OP, and is 4 bits wide. Conditionals form the input of
the MicroROM, and must be defined in order from most-significant to
least-significant address bits.

Conditionals are made up of letters, numbers, and non-whitespace characters
except colons (:) and equal signs (=).

An implicit condition 'uaddr' must always be present. Its bit width may be
freely defined. The uaddr field contains the microinstruction address. This is
also part of the ROM addressing, and is almost always defined to use the
least-significant bits of the full ROM address. (so it will probably be the
last cond encountered in the microcode source)

==Signals==

Signals are the outputs of the microcode ROM. They'll be used to drive the rest
of the CPU. Each signal has a particular bit pattern, which may be defined with
the signal keyword:

  signal /MEMIO        = 0000000000000001
  signal DATA_BUS <- A = 0000000000000010

Signal names may contain any character exept the equals sign (=), notably also
spaces (for legibility). A signal may not start with a minus sign (-).

Each signal is equivalent to a particular bit sring, which is specified in
binary to the right of the equals sign (=). The bitstring may be specified in
traditional form, or with dots (.) or hyphens (-) replacing zeroes (also for
legibility). For example, the above example may be rewritten:

  signal /MEMIO        = ...............1
  signal DATA_BUS <- A = ..............1.

The bitstring can be of arbitrary length, depending on the word width of the
microinstruction.

==Microprograms==

A microprogram starts with the ‘start’ keyword, and a comma-separated list of
conditions.

Each condition is in the form COND=NUM, where COND is one of the CPU's
conditions defined in conds. NUM is the state of that condition signal, which
can be a binary number of appropriate width for the signal (usually just 0 or
1), or X. X is the don't care value.

The microprogram will start at an address in the microcode ROM constructed by
concatenating the values of all the conditions (in their canonical order), plus
a microaddress field of 0. If one or more don't cares are specified as
conditions, the microprogram will repeat in the ROM, to account for the don't
care state. This is a good way to implement the handling of asynchronous
signalling like interrupts, such that the execute part of the instruction works
the same way regardless of the value of IRQ.

Microprogram lines after the 'start' keyword contain one microinstruction per
line. Each microinstruction is specified as a comma-separated list of signals
to set or clear, or the 'hold' keyword.

A signal NAME is set by simply typing NAME. It is cleared by typing -NAME. All
signals set are ORred together, and signals cleared are masked out.

Every microinstruction starts with all signals cleared, so the bitstring is all
zeroes. If the 'hold' keyword is specified, then any signals active in the
previous microinstruction will stay active.

For example:

  cond OP:4
  cond uaadr:3

  signal MEMIO     = ....1
  signal MREAD     = ...1.
  signal MWRITE    = ..1..
  signal MAR <- PC = .1...
  signal IR <- MEM = 1....

  start OP=XXXX # A tiny fetch instruction
    MEMIO, MREAD, MAR <- PC     # 
    hold                        # Same as MEMIO, MREAD, MAR <- PC
    hold, -MREAD, IR <- MEM     # Same as MEMIO, MAR <- PC, IR <- MEM

"""

import re
import os
import sys
import array
import pprint
import StringIO
import optparse
import subprocess

__code = """
# This is an example of microcode.

###############################################################################
#
# Conditions: fields embedded in the MicroROM address.
#
###############################################################################

cond RST:1                    # Resetting
cond IRQ:1                    # IRQ request
cond F:1                      # Fetch mode
cond OP:4                     # The opcode field of the IR.
cond I:1                      # The indirection field of the IR.
cond SKIP:1                   # The skip flag from the skip logic.

# The uaddr field of the address is mandatory. This just sets its width.
cond uaddr:4

###############################################################################
#
# Signals: outputs of the MicroROM
#
###############################################################################

signal pc++           = .......................1 # Step the PC

signal mar <- pc      = ......................1. # Latch: MAR = PC
signal mar <- operand = .....................1.. # Latch: MAR = IR.operand
signal mar <- dr      = ....................1... # Latch: MAR = DR

signal ir <- dbus     = ...................1.... # Latch: IR from data bus
signal dr <- dbus     = ..................1..... # Latch: DR from data bus

signal /dab           = .................1...... # Drive Address bus
signal /mem           = ................1....... # Memory access
signal /io            = ...............1........ # Input/Output enable
signal /mr            = ..............1......... # Memory read
signal /mw            = .............1.......... # Memory write

###############################################################################
#
# The Microcode itself.
#
###############################################################################

start IRQ=X, RST=X, F=1, OP=XXXX, I=X, SKIP=X
  MAR <- PC, /DAB, /MEM, /MR       # Drive address bus with PC
  /DAB, /MEM, /MR                  # Wait state (optional?)
  IR <- DBUS, hold                 # Latch data, keep driving.
  -/DAB, -/MEM, -/MR, PC++         # Stop driving bus. Data is now in IR.
#
  MAR <- OPERAND, /DAB, /MEM, /MR  # Drive address bus with OPERAND
  /DAB, /MEM, /MR                  # Wait state
  DR <- DBUS, hold                 # Latch data, keep driving.
  -/DAB, -/MEM, -/MR               # Stop driving. DR = mem[OPERAND].
#
  MAR <- DR, /DAB, /MEM, /MR       # Drive address bus with DR
  /DAB, /MEM, /MR                  # Wait state
  DR <- DBUS, hold                 # Latch data, keep driving.
  -/DAB, -/MEM, -/MR               # Stop driving. DR = mem[mem[OPERAND]].

"""


VERILOG_PREAMBLE = """// -*- verilog -*-
//
// Generated automatically, DO NOT EDIT.

`ifdef EXTERNAL_TIMESCALE
  `include "timescale.v"
`else
  `timescale 1ns/1ps
`endif // EXTERNAL_TIMESCALE

`ifndef __MICROCODE_V__
`define __MICROCODE_V__ 1

"""

VERILOG_POSTAMBLE = """
endmodule

`endif // __MICROCODE_V__

// End of file.
"""

MIF_HEADER = """-- Altera Memory Initialisation Format (MIF)
-- Generated automatically, do not edit!

DEPTH = %(s)d; -- Number of entries in this ROM
WIDTH = %(w)d; -- Number of data bits per word.
ADDRESS_RADIX = BIN;
DATA_RADIX = BIN;
CONTENT
BEGIN
"""

MIF_FOOTER = """END;

-- End of file.
"""

class MicrocodeAssembler(object):

    CPP_LOCATION = '/usr/bin/cpp'

    UINSTR_LENGTH = 24
    
    def __init__(self, options):
        self.options = options

        # Regular expressions
        self.re_comment = re.compile('(#|//).*$')

        # Internal state.
        self.fname = '?'
        self.lnum = 0
        self.want_colour = self.options.color and os.isatty(sys.stdout.fileno())
        self.maxuaddr = 0
        self.uprograms = 0

        # Where's the C Preprocessor?
        self.cpp = os.environ.get('CPP', self.CPP_LOCATION)


    def ansi(self, s):
        """Mark up in colour, where available."""
        if not self.want_colour:
            return re.sub('\033\[[^m]+m', '', s)
        return s.replace('\n', '\033[0m\n')
    
    
    def pansi(self, *args):
        """Print with colour."""
        print self.ansi(' '.join(args))
        
    
    def wansi(self, *args):
        """Print with colour."""
        sys.stdout.write(self.ansi(' '.join(args)))
        
    
    def error(self, msg):
        sys.stderr.write(self.ansi("%s:%d: \033[0;1;31m%s\n" % (self.fname, self.lnum, msg)))
        sys.exit(1)
    

    def warning(self, msg):
        sys.stderr.write(self.ansi("%s:%d: \033[0;1;33mwarning: %s\n" % (self.fname, self.lnum, msg)))
    

    def proper_bin(self, x, nb=16):
        return bin(x)[2:].zfill(nb)
    

    def permute(self, a):
        if a == '':
            yield ''
        elif a[0] == 'x':
            for rest in self.permute(a[1:]):
                yield '0' + rest
                yield '1' + rest
        else:
            for rest in self.permute(a[1:]):
                yield a[0] + rest
    
    
    def set_microcode(self, addr, data, notes=''):
        addr = ''.join(addr).lower()
        try:
            self.microcode[int(addr, 2)] = (data, addr)
            return
        except ValueError:
            # There are don't-care values (X) in the address.
            for a in self.permute(addr):
                inta = int(a, 2)
                assert a not in self.microcode
                if a in self.microcode:
                    self.pansi('\033[0;1;35m Overwriting address %s (0x%x).' % (a, inta))
                self.microcode[inta] = (data, addr + notes)


    def idleinstr(self):
        """Return the 'idle' instruction bitfield, i.e. one that does nothing."""
        uinstr = 0
        for instr, bits in self.signals.items():
            # Is this an active low signal?
            if instr.startswith('/'):
                uinstr |= bits
        return uinstr


    def handle_label(self, line):
        # Is there a label?
        if ':' in line:
            label, line = line.split(':', 1)
            if self.options.verbose:
                self.pansi('\033[0;1;35m%s\033[0m' % label)
        return line


    def getstatement(self, source):
        """Read the source file, yielding complete statements."""
        buf = ''
        self.lnum = 0
        for line in source:
            #print '***', self.lnum, line.rstrip()
            self.lnum += 1
            if not line:
                yield ''
                break

            # Parse line number magic comments from cpp.
            x = re.findall('^# (\d+) ".+"$', line.strip())
            if x:
                self.lnum = int(x[0])
    
            line = self.re_comment.sub('', line)
            line = line.strip()
            
            buf += ' ' + line
            while ';' in buf:
                x = buf.split(';', 1)
                yield x[0].strip()
                buf = x[1].strip()
    
        if buf:
            yield buf

        
    def process(self, fname, outfname):
        self.fname = fname

        # Initialise conditions.
        self.conds = list()
        self.condwidths = dict()
        self.signals = dict()
        self.microcode = dict()
        self.condspecs = []
        self.fields = list()

        uaddr = 0
        state = 0
        uinstr = 0

        used_signals = set()

        # Spawn preprocessor.
        
        cmd = '%s %s' % (self.cpp, fname)
        source = subprocess.Popen(cmd, shell=True, bufsize=4096, stdout=subprocess.PIPE).stdout

        if self.options.preprocess:
            sys.stdout.write(source.read())
            sys.exit(0)

        for line in self.getstatement(source):
            # Skip empty lines.
            if not line:
                continue

            if line.startswith('cond'):
                if not re.match('^cond\s+([^:]+)(\s*:\s*(\d+))$', line):
                    self.error('Syntax error parsing "cond" directive.')

                try:
                    condspec = re.findall('cond\s+([^:]+)(\s*:\s*(\d+))$', line).pop()
                except:
                    self.error('Expected "cond SOME-COND [:BITS]"')
                condname = condspec[0].strip()
                condbits = int(condspec[2].strip() or '1')
                if condbits < 1:
                    self.error("Condition '%s' width must be a natural number." % (condname))
                self.conds.append(condname)
                self.condwidths[condname] = condbits
                if self.options.mappings:
                    self.pansi('# cond %s: %d' % (condname, condbits))
        
            elif line.startswith('field'):
                try:
                    sigspec = re.findall('field\s+(.*\S)\s*=\s*(\S+)', line).pop()
                    fieldname = sigspec[0].strip()
                    if fieldname.startswith('-'):
                        self.error("Field name '%s' starts with a '-', which is not allowed." % (fieldname,))
                    fieldbits = sigspec[1].strip()
                except:
                    self.error('Expected "field SOME-FIELD = MASK-FIELD"')
                    
                try:
                    fieldbits = re.sub('[._-]', '0', fieldbits)
                    fieldbits = re.sub('[X+x]', '1', fieldbits)
                    fieldbits = int(fieldbits, 2)
                    if fieldbits == 0:
                        self.error("Field '%s' contains no bits (zero value)." % fieldname)
                    shift = 0
                    while ((fieldbits >> shift) & 1) == 0:
                        shift +=1
                        
                    self.fields.append((fieldname, fieldbits, shift, fieldbits >> shift))
                except:
                    self.error('Bit field should be a binary number (. or - are aliases of 0 for readability)')
                    
                if self.options.mappings:
                    self.pansi('# field', fieldname, self.proper_bin(fieldbits, 1))
                
            elif line.startswith('signal'):
                try:
                    sigspec = re.findall('signal\s+(.*\S)\s*=\s*(\S+)', line).pop()
                    signame = sigspec[0].strip()
                    if signame.startswith('-'):
                        self.error("Signal name '%s' starts with a '-', which is not allowed." % (signame,))
                    sigbits = sigspec[1].strip()
                except:
                    self.error('Expected "signal SOME-SIGNAL = BIT-FIELD"')
                    
                try:
                    sigbits = re.sub('[.-]', '0', sigbits)
                    sigbits = int(sigbits, 2)
                except:
                    self.error('Bit field should be a binary number (. or - are aliases of 0 for readability)')
                    
                self.signals[signame.lower()] = sigbits
                if self.options.mappings:
                    self.pansi('# signal', signame, self.proper_bin(sigbits, 1))
        
            elif line.startswith('start'):
                condre = '(\w+)\s*=\s*([01xX]+)'
                if not re.match('^start\s+' + condre + '(\s*,\s*' + condre + ')*\s*$', line):
                    print line
                    self.error('Syntax error parsing "start" directive.')
                if 'uaddr' not in self.conds:
                    self.error("The mandatory conditional 'uaddr' has not been defined.")
                #self.pansi("Starting new microprogram.")
                self.uprograms += 1
                self.condspecs = re.findall(condre, line)
                if not self.condspecs:
                    self.error('No conditions specified')
                uinstr = self.idleinstr()
                uaddr = 0
                state = 1
                if self.options.verbose:
                    print
        
            else:
                if state == 0:
                    self.error("Microcode seen before first 'start' keyword.")
                sigspec = [x.strip() for x in line.split(',')]
                if 'hold' not in sigspec:
                    uinstr = self.idleinstr()
                else:
                    sigspec = [x for x in sigspec if x != 'hold']
        
                for signal in sigspec:
                    used_signals = used_signals | set([signal.lower()])
                    enable = True
                    if signal.startswith('-'):
                        enable = False
                        signal = signal[1:].strip()

                    # If it's an active-low signal, negate the semantics.
                    if signal.startswith('/'):
                        enable = not enable
                        pass
        
                    try:
                        if enable:
                            uinstr |= self.signals[signal.lower()]
                        else:
                            uinstr &= ~self.signals[signal.lower()]
        
                    except KeyError:
                        self.error("Unknown signal name '%s'." % signal)
        
                # Output the microcode line.
                #self.pansi(condspecs + [('uaddr', bin(uaddr)[2:])], signals)
        
                # Prepare for encoding.
                d = dict()
        
                # Add the microaddress to the conditions.
                self.condspecs.append(('uaddr', self.proper_bin(uaddr, self.condwidths['uaddr'])))
        
                # Turn the conditions into a dictionary.
                for sig, val in self.condspecs:
                    d[sig] = val # self.proper_bin(val, self.condwidths[sig])
                    
                # Order the conditions using the order of conds
                romaddr = list()
                for c in self.conds:
                    try:
                        assert c in d
                        if len(d[c]) != self.condwidths[c]:
                            self.error("Condition '%s' should specify exactly %d bits, %d seen instead." % (c, self.condwidths[c], len(d[c])))
                        romaddr.append(d[c])
                    except (AssertionError, KeyError):
                        self.error("Missing value for condition '%s'" % c)
        
                # Print out the conditions.
                if self.options.verbose:
                    for c in self.conds:
                        self.wansi('%s:\033[1;32m%s\033[0m ' % (c, d[c]))
                    self.wansi(': \033[1;33m%s\033[0m ; %s' % (bin(uinstr)[2:].zfill(self.UINSTR_LENGTH), line))
                    print
                    
                # Write to the ROM.
                self.set_microcode(romaddr, uinstr, (' %-40s ' % ' '.join(sigspec)))
        
                uaddr += 1
                self.maxuaddr = max(self.maxuaddr, uaddr)
                if uaddr > (1 << self.condwidths['uaddr']):
                    uaddr = uaddr & ((1 << self.condwidths['uaddr']) - 1)
                    self.warning("uaddr wraps around to zero after this microinstruction.")

        unused_signals = set(self.signals.keys()) - used_signals
        if unused_signals:
            for a in unused_signals:
                self.warning('Unused signal "%s".' % a)
        
        self.totalconds = sum(self.condwidths.values())
        self.romsize = 1 << self.totalconds
        self.totalsigs = max(len(bin(x)) for x in self.signals.values()) - 2
        self.numroms = (self.totalsigs + 7) // 8

        if self.options.stats:
            slackbits = 0
            usedbits = 0
            x = max(0, self.maxuaddr - 1)
            while x:
                usedbits += 1
                x = x >> 1

            self.pansi('\n')
            self.pansi('# Total microprograms:       %3d' % (self.uprograms,))
            self.pansi('# Biggest microprogram:      %3d microinstructions' % (self.maxuaddr,))
            self.pansi('# Uaddr width:               %3d bits' % self.condwidths['uaddr'])
            self.pansi('# Uaddr should be:           %3d bits wide' % usedbits)
            self.pansi('# Unneeded uaddr bits:       %3d bits' % (self.condwidths['uaddr'] - slackbits))
            self.pansi('# Total address bits needed: %3d (%d bytes)' % (self.totalconds, self.romsize))
            self.pansi('# Total data bits needed:    %3d (%d ROM ICs in parallel)' % (self.totalsigs, self.numroms))
        
        if self.options.dump:
            self.dump()
        if self.options.vhdl:
            self.vhdl()

        # Write the ROM dumps.
        self.writeroms(outfname)
        if self.options.verilog:
            self.writeroms_verilog(outfname)
            self.writeroms_verilog_code(outfname)
        if self.options.altera:
            self.writeroms_altera(outfname)
        if self.options.rsar:
            self.writeroms_rsar(outfname)
        if self.options.c:
            self.writeroms_c(outfname)


    def dump(self):
        """Dump the microcode ROMs."""
        idle = self.idleinstr()
        for addr in range(self.romsize):
            data, pattern = self.microcode.get(addr, (idle, '------------'))
            
            bytedata = list()
            d = data
            for x in range(self.numroms):
                bytedata.insert(0, '%02x' % (d & 0xff))
                d = d >> 8
            bytedata = ' '.join(bytedata)

            self.pansi("%06x: %s ; %s => %s " % (addr, bytedata, pattern,
                                                 self.proper_bin(data, self.totalsigs)))


    def vhdl(self):
        """Dump the microcode ROMs as VHDL."""
        for addr in range(self.romsize):
            data = self.microcode.get(addr, 0)
            
            bytedata = list()
            try:
                d = data[0]
                data = data[0]
            except TypeError:
                pass
            for x in range(self.numroms):
                bytedata.insert(0, '%02x' % (d & 0xff))
                d = d >> 8
            bytedata = ' '.join(bytedata)

            data = self.proper_bin(data, self.totalsigs)
            
            self.pansi("  d <= \"%s\" when a=\"%s\" and oe='0' and ce='0' else" % \
                           (data, self.proper_bin(addr, self.totalconds)))

        self.pansi("  d <= \"%s\";" % ('Z' * self.totalsigs))


    def writeroms(self, outfname):
        """Write one binary file per microcode ROM."""
        for nrom in range(self.numroms):
            fname = '%s-%02d.bin' % (outfname, nrom)
            shift = 8 * nrom
            mask = 0xff << shift
            print "Writing %s... (mask %x)" % (fname, mask)
            outdata = array.array('c')
            idle = self.idleinstr()
            for addr in range(self.romsize):
                data, pattern = self.microcode.get(addr, (idle, '------------'))
                outdata.append(chr((data & mask) >> shift))
            outdata.tofile(open(fname, 'wb'))


    def writeroms_verilog(self, outfname):
        """Write one binary file per microcode ROM in Verilog binary
        (human-readable binary, that is) format."""
        for nrom in range(self.numroms):
            fname = '%s-%02d.list' % (outfname, nrom)
            shift = 8 * nrom
            mask = 0xff << shift
            print "Writing %s... (mask %x)" % (fname, mask)
            outdata = array.array('c')
            f = open(fname, 'w')
            idle = self.idleinstr()
            for addr in range(self.romsize):
                data, pattern = self.microcode.get(addr, (idle, '------------'))
                f.write('%s // addr=%04x\n' % \
                            (bin((data & mask) >> shift)[2:].zfill(8),
                             addr))
            f.close()


    def writeroms_altera(self, outfname):
        """Write a binary file in Altera MIF format."""

        fname = '%s.mif' % (outfname,)
        print "Writing %s..." % (fname,)
        f = open(fname, 'w')
        s = self.romsize
        d = self.totalconds
        w = self.totalsigs
        idle = self.idleinstr()
        f.write(MIF_HEADER % locals())

        template = "%%0%ds : %%0%ds;\n" % ((d + 3) // 4, (w + 3) // 4)

        for addr in range(self.romsize):
            data, pattern = self.microcode.get(addr, (idle, '------------'))
            f.write(template % (self.proper_bin(addr, d), self.proper_bin(data, w)))
        f.write(MIF_FOOTER % locals())
        f.close()


    def writeroms_rsar(self, outfname):
        """Write a dataset for minimisation by RSAR."""

        d = self.totalconds
        w = self.totalsigs
        idle = self.idleinstr()

        for cls in range(self.totalsigs):
            fname = '%s-%03d.rsar' % (outfname, cls)
            print "Writing %s..." % (fname,)
            f = open(fname, 'w')

            for addr in range(self.romsize):
                data, pattern = self.microcode.get(addr, (idle, '------------'))
                x = ' '.join(self.proper_bin(addr, d))
                y = int((data & (1 << cls)) != 0)
                f.write('%s  %d\n' % (x, y))
            f.close()


    def writeroms_verilog_code(self, outfname):
        """Write Verilog code to simulate the microcode ROM."""

        fname = '%s.v' % (outfname, )
        f = open(fname, 'w')
        f.write(VERILOG_PREAMBLE)

        conds = ', '.join('in_' + self.to_v(x, lower=True) for x in self.conds)
        
        f.write('module Microcode(')
        #f.write(conds)
        #f.write(',\n                 ')
        f.write('cond_vector, control_vector);\n\n')

        #for x in self.conds:
        #    w = self.condwidths[x]
        #    if self.condwidths[x] > 1:
        #        f.write('    input [%d:0] in_%s;\n' % (w - 1, self.to_v(x, lower=True)))
        #    else:
        #        f.write('    input in_%s;\n' % (self.to_v(x, lower=True),))

        f.write('\n    input [%d:0] cond_vector;\n' % (self.totalconds - 1, ))
        f.write('\n    output reg [%d:0] control_vector;\n\n' % (self.totalsigs - 1, ))

        #f.write('    assign cond_vector = {%s};\n\n' % conds)

        f.write('    always @(cond_vector) begin\n')
        f.write('        case (cond_vector) // synthesis parallel_case\n')

        # Find the default pattern.
        idle = self.idleinstr()
        hist = dict()
        for addr in range(self.romsize):
            data, pattern = self.microcode.get(addr, (idle, '------------'))
            try:
                hist[data] += 1
            except:
                hist[data] = 1
        keys = hist.keys()
        keys.sort(cmp=lambda a, b: cmp(hist[b], hist[a]))
        default = keys[0]

        for addr in range(self.romsize):
            data, pattern = self.microcode.get(addr, (idle, '------------'))
            if data == default:
                continue
            f.write("            (%d'b%s): control_vector <= %d'b%s;\n" % \
                        (self.totalconds, self.proper_bin(addr, self.totalconds),
                         self.totalsigs, self.proper_bin(data, self.totalsigs)))
        f.write("            default: control_vector <= %d'b%s;\n" % \
                    (self.totalsigs, self.proper_bin(data, self.totalsigs)))
        f.write('        endcase\n')
        f.write('    end\n')

        f.write(VERILOG_POSTAMBLE)


    C_RESERVED_KEYWORDS = [
        # These are C reserved words

	'_Packed',
	'else',
	'enum',
	'extern',
	'float',
	'for',
	'goto',
	'if',
	'int',
	'long',
	'register',
	'return',
	'short',
	'signed',
	'sizeof',
	'static',
	'struct',
	'switch',
	'typedef',
	'union',
	'unsigned',
	'void',
	'volatile',
	'while',
        'auto',
        'break',
        'case',
        'char',
        'const',
        'continue',
        'default',
        'do',
        'double',
        ]

    
    VERILOG_RESERVED_KEYWORDS = [
        # These are Verilog reserved words
        'always',
        'assign',
        'automatic',
        'begin',
        'casex',
        'casez',
        'cell',
        'config',
        'deassign',
        'defparam',
        'design',
        'disable',
        'edge',
        'end',
        'endcase',
        'endconfig',
        'endfunction',
        'endgenerate',
        'endmodule',
        'endprimitive',
        'endspecify',
        'endtable',
        'endtask',
        'event',
        'force',
        'forever',
        'fork',
        'function',
        'generate',
        'genvar',
        'ifnone',
        'incdir',
        'include',
        'initial',
        'inout',
        'input',
        'instance',
        'join',
        'liblist',
        'library',
        'localparam',
        'macromodule',
        'module',
        'negedge',
        'noshowcancelled',
        'output',
        'parameter',
        'posedge',
        'primitive',
        'pulsestyle_ondetect',
        'pulsestyle_onevent',
        'reg',
        'release',
        'repeat',
        'scalared',
        'showcancelled',
        'specify',
        'specparam',
        'strength',
        'table',
        'task',
        'tri0',
        'tri1',
        'triand',
        'wand',
        'trior',
        'wor',
        'trireg',
        'use',
        'vectored',
        'wait',
        'while',
        'wire',




        ]

    def to_c(self, x, lower=False):
        """Convert x to a C macro identifier."""
        x = re.sub('^([0-9])', r'N\\1',
                   re.sub('[^A-Za-z0-9_]', '_', x))
        if lower:
            x = x.lower()
        else:
            x = x.upper()

        if x in self.C_RESERVED_KEYWORDS:
            x = x + '_'

        return x
            
    def to_v(self, x, lower=False):
        """Convert x to a Verilog identifier."""
        if x.startswith('/'):
            x = x[1:] + '_n';

        x = re.sub('^([0-9])', r'N\\1',
                   re.sub('[^A-Za-z0-9_]', '_', x))
        if lower:
            x = x.lower()
        else:
            x = x.upper()

        if x in self.VERILOG_RESERVED_KEYWORDS:
            x = x + '_'

        return x
            
    def countbits(self, x):
        """
        Count the bits in a number.
        
        This is a low-performance way of doing it.
        """
        return len([x for x in bin(x)[2:] if x == '1'])

            
    def find_field(self, pattern):
        """Return the field with the fewest bits that matches pattern."""
        shortest = None
        shortest_bits = 1e9

        for fieldname, fieldbits, shift, shiftbits in self.fields:
            # Does this match the pattern?
            if pattern & fieldbits == pattern:
                numbits = self.countbits(fieldbits)
                if numbits < shortest_bits:
                    shortest_bits = numbits
                    shortest = (fieldname, fieldbits, shift, shiftbits)
        return shortest


    def writeroms_c(self, outfname):
        """Write a single C99 source code file with the microcode."""
        fname = '%s.h' % outfname
        f = open(fname, 'w')
        print "Writing %s..." % fname
        idle = self.idleinstr()
        f.write('/* Automatically generated, do not modify! */\n\n')
        f.write('#ifndef __MICROCODE_H__\n')
        f.write('#define __MICROCODE_H__ 1\n')
        f.write('\n\n')

        # Output the conditions
        f.write('typedef struct {\n')
        for cond in self.conds:
            condid = self.to_c(cond, lower=True)
            f.write('        uint32_t %s:%d;\n' % (condid, self.condwidths[cond]))
        f.write('} __microcode_conds_t_msb_1st;\n\n')

        f.write('typedef struct {\n')
        for cond in reversed(self.conds):
            condid = self.to_c(cond, lower=True)
            f.write('        uint32_t %s:%d;\n' % (condid, self.condwidths[cond]))
        f.write('} __microcode_conds_t_lsb_1st;\n\n')

        # Also add a macro to generate uROM addresses based on the conditionals.
        condlist = ', '.join(self.to_c(x, lower=True) for x in self.conds)
        f.write('#define MAKE_ADDR(%(condlist)s) ((\\\n' % locals())
        shift = 0
        code = list()
        for cond in reversed(self.conds):
            bits = self.condwidths[cond]
            mask = (1 << bits) - 1
            condid = self.to_c(cond, lower=True)
            if shift:
                code.append('        (((%(condid)s) & 0x%(mask)x) << %(shift)d)' % locals())
            else:
                code.append('        ((%(condid)s) & 0x%(mask)x)' % locals())
            shift += bits
        f.write(' | \\\n'.join(code) + ') & 0x%x)\n\n' % (self.romsize - 1))

        # Output the fields
        for fieldname, fieldbits, shift, shiftbits in self.fields:
            fieldname = self.to_c(fieldname)
            if shift:
                f.write(('#define GET_%(fieldname)s(x) ' + \
                             '(((x) >> 0x%(shift)x) & 0x%(shiftbits)x)\n') % locals())
            else:
                f.write(('#define GET_%(fieldname)s(x) ' + \
                             '((x) & 0x%(shiftbits)x)\n') % locals())

        # Output the signals in a way similar to the conditions.
        sigcmp = lambda a,b: cmp(self.signals[a], self.signals[b])
        for sig in sorted(self.signals.keys(), cmp=sigcmp):
            pattern = self.signals[sig]

            # If this is an active-low signal, negate the semantics to
            # allow the IS_x macros to make sense.
            op, comment = '==', ''
            if sig[0] == '/':
                op = '!='
                comment = ' /* Active low in uROM */'
                sig = sig[1:]
            
            sig = re.sub('[^A-Za-z0-9_]', '_', sig).upper()

            # Find a field, if one is available.
            field = self.find_field(pattern)
            if field:
                fieldname, fieldbits, shift, shiftbits = field

                fieldname = re.sub('[^A-Za-z0-9_]', '_', field[0]).upper()
                pat = (pattern >> shift) & shiftbits

                f.write(('#define IS_%(sig)s(x) (GET_%(fieldname)s(x) %(op)s 0x%(pat)x)' + 
                         '%(comment)s\n') %
                        locals())
            else:

                f.write(('#define IS_%(sig)s(x) (((x) & 0x%(pattern)x) %(op)s 0x%(pattern)x)' +
                         '%(comment)s\n') %
                        locals())

        f.write('\n\n')

        # Finally, output the microcode itself.
        
        # First, decide on the most compact datatype.

        width = 1 << self.totalconds
        maxbits = self.totalsigs
        romsize = self.romsize

        dt = 'unsigned int'
        if maxbits <= 8:
            dt = 'uint8_t'
        elif maxbits <= 16:
            dt = 'uint16_t'
        elif maxbits <= 32:
            dt = 'uint32_t'
        elif maxbits <= 64:
            dt = 'uint64_t'
        else:
            self.warning('uROM is wider than 64 bits. ' +
                         'Using arbitrary uint%d_t for the C code. Good luck.' % maxbits)
        pad = str((maxbits + 3) // 4)

        f.write('/*\n * MICROCODE ROM STARTS HERE\n *\n')
        f.write(' * uROM contains %(romsize)d entries of %(totalsigs)d bits each.\n */\n'
                % self.__dict__)
        romsize += 1
        f.write('#define MICROCODE_TOCALCONDS %(totalconds)d\n' % self.__dict__)
        f.write('#define MICROCODE_TOTALSIGS %(totalsigs)d\n' % self.__dict__)
        f.write('#define MICROCODE_ROMSIZE %(romsize)d\n' % self.__dict__)

        f.write('#ifndef WANT_MICROCODE_ROM\n')
        f.write('extern const %(dt)s microcode[%(romsize)d];\n' % locals())
        f.write('#else\n')
        f.write('const %(dt)s microcode[%(romsize)d] = {\n' % locals())

        for addr in range(self.romsize):
            data, pattern = self.microcode.get(addr, (idle, '------------'))
            
            bytedata = list()
            d = data
            for x in range(self.numroms):
                bytedata.insert(0, '%02x' % (d & 0xff))
                d = d >> 8
            bytedata = ' '.join(bytedata)

            f.write(('        0x%0' + pad + 'x, /* %06x: %s */\n') % \
                        (data, addr, pattern.rstrip()))
            #f.write(('        0x%0' + pad + 'x,\n') % data)
        f.write('        -1\n};\n\n')
        f.write('#endif /* WANT_MICROCODE_ROM */ \n')
        f.write('\n\n')
        f.write('#endif /* __MICROCODE_H__ */\n')
        f.close()

            

p = optparse.OptionParser()
p.add_option('-d', '--dump', action='store_true',
             help='Print out raw hex values for the entire microcode ROM.')
p.add_option('-m', '--mappings', action='store_true',
             help='Print out the symbol to bit mappings for conditions and signals.')
p.add_option('-o', '--out', metavar='FILENAME',
             help='Output object file to FILENAME.')
p.add_option('-p', '--preprocess', action='store_true',
             help='Preprocess to standard output and stop. Useful for debugging preprocessing bugs.')
p.add_option('-s', '--stats', action='store_true',
             help='Print out statistics about the assembled microcode ROM.')
p.add_option('-V', '--vhdl', action='store_true',
             help='Print out the ROM as a VHDL code fragment.')
p.add_option('-e', '--verilog', action='store_true',
             help='Print out the ROM as one or more verilog binary list files.')
p.add_option('-a', '--altera', action='store_true',
             help='Generate the ROM in Altera MIF format.')
p.add_option('-r', '--rsar', action='store_true',
             help='Generate an RSAR dataset.')
p.add_option('-c', '--c', action='store_true',
             help='Write out the ROM as C code.')
p.add_option('-v', '--verbose', action='store_true',
             help='Print out assembled microcode in human-readable format.')
p.add_option('-C', '--color', action='store_true',
             help='Output messages in colour, if possible.')

(options, args) = p.parse_args()

#code = StringIO.StringIO(code)
#fname = 'example.ucode'

def die(x):
    sys.stderr.write('%s: %s\n' % (sys.argv[0], x))
    sys.exit(1)
    
if not args:
    die('An input file must be provided.')
    
for arg in args:
    try:
        outname = options.out or os.path.splitext(arg)[0]
        MicrocodeAssembler(options).process(arg, outname)

    except IOError, e:
        die('reading %s: %s' % (arg, e))
    
# End of file.
