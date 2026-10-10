"""Bounded interpreter for isolated, whitelisted ICR2 integer routines.

No DOS program, operating-system calls, or general executable entry point runs.
Used to check reconstructions against the actual instruction bytes.
"""
from capstone import Cs, CS_ARCH_X86, CS_MODE_32
from capstone.x86 import X86_OP_REG, X86_OP_IMM, X86_OP_MEM


def signed(value, bits):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


class IntegerCore:
    def __init__(self, binary, code_start, data_start):
        cs = Cs(CS_ARCH_X86, CS_MODE_32)
        cs.detail = True
        self.instructions = {}
        for lo, hi in [(0x195A4, 0x19674), (0x19690, 0x1978A)]:
            off = code_start + lo - 0x10000
            self.instructions.update((i.address, i) for i in cs.disasm(binary[off:off + hi-lo], lo))
        self.mem = bytearray(0x120000)
        self.mem[:len(binary)-data_start] = binary[data_start:]
        self.regs = dict.fromkeys(['eax','ebx','ecx','edx','esi','edi','ebp'], 0)
        self.regs['esp'] = 0x100000
        self.comparison = (0, 0, 32)

    def reg(self, name, value=None):
        if name in self.regs:
            if value is not None: self.regs[name] = value & 0xFFFFFFFF
            return self.regs[name]
        base = {'ax':'eax','bx':'ebx','cx':'ecx','dx':'edx','si':'esi','di':'edi',
                'bp':'ebp','sp':'esp','al':'eax','ah':'eax','bl':'ebx','bh':'ebx',
                'cl':'ecx','ch':'ecx','dl':'edx','dh':'edx'}[name]
        shift = 8 if name in ['ah','bh','ch','dh'] else 0
        bits = 8 if len(name)==2 and name[1] in 'lh' else 16
        mask = ((1 << bits)-1) << shift
        if value is not None: self.regs[base] = (self.regs[base] & ~mask) | ((value << shift) & mask)
        return (self.regs[base] & mask) >> shift

    def memory(self, address, size, value=None):
        if not 0 <= address <= len(self.mem)-size: raise ValueError('Out-of-bounds memory')
        if value is not None: self.mem[address:address+size] = (value & ((1 << (size*8))-1)).to_bytes(size,'little')
        return int.from_bytes(self.mem[address:address+size], 'little')

    def operand(self, instruction, op, value=None):
        if op.type == X86_OP_REG: return self.reg(instruction.reg_name(op.reg), value)
        if op.type == X86_OP_IMM:
            if value is not None: raise ValueError('Write to immediate')
            return op.imm & ((1 << (op.size*8))-1)
        if op.type == X86_OP_MEM:
            m=op.mem
            address=m.disp+(self.reg(instruction.reg_name(m.base)) if m.base else 0)+(self.reg(instruction.reg_name(m.index))*m.scale if m.index else 0)
            return self.memory(address, op.size, value)
        raise ValueError('Unsupported operand')

    def push(self, value):
        self.reg('esp', self.reg('esp')-4)
        self.memory(self.reg('esp'),4,value)

    def pop(self):
        value=self.memory(self.reg('esp'),4)
        self.reg('esp',self.reg('esp')+4)
        return value

    def run(self, address, registers, arguments=()):
        self.reg('esp',0x100000)
        for name,value in registers.items(): self.reg(name,value)
        for value in reversed(arguments): self.push(value)
        self.push(0xFFFFFFFF)
        pc=address
        for step in range(2000):
            if pc==0xFFFFFFFF: return self.reg('eax')
            i=self.instructions.get(pc)
            if i is None: raise ValueError(f'Instruction outside whitelist: {pc:x}')
            ops=i.operands; mn=i.mnemonic; nxt=pc+i.size
            get=lambda n:self.operand(i,ops[n])
            put=lambda n,v:self.operand(i,ops[n],v)
            bits=ops[0].size*8 if ops else 32
            if mn=='push':self.push(get(0))
            elif mn=='pop':put(0,self.pop())
            elif mn=='mov':put(0,get(1))
            elif mn=='movsx':put(0,signed(get(1),ops[1].size*8))
            elif mn=='cwde':self.reg('eax',signed(self.reg('ax'),16))
            elif mn=='lea':
                m=ops[1].mem
                put(0,m.disp+(self.reg(i.reg_name(m.base)) if m.base else 0)+(self.reg(i.reg_name(m.index))*m.scale if m.index else 0))
            elif mn in ['xor','and','add','sub','sar','shr','shl']:
                a,b=get(0),get(1)
                result={'xor':lambda:a^b,'and':lambda:a&b,'add':lambda:a+b,'sub':lambda:a-b,
                        'sar':lambda:signed(a,bits)>>(b&31),'shr':lambda:a>>(b&31),'shl':lambda:a<<(b&31)}[mn]()
                put(0,result)
            elif mn=='neg':put(0,-get(0))
            elif mn=='imul':
                if len(ops)==1:
                    product=signed(self.reg('eax'),32)*signed(get(0),bits)
                    self.reg('eax',product);self.reg('edx',product>>32)
                else:put(0,signed(get(0 if len(ops)==2 else 1),bits)*signed(get(1 if len(ops)==2 else 2),bits))
            elif mn in ['idiv','div']:
                numerator=(self.reg('edx')<<32)|self.reg('eax'); divisor=get(0)
                if mn=='idiv':numerator=signed(numerator,64);divisor=signed(divisor,bits)
                quotient=abs(numerator)//abs(divisor)
                if (numerator<0)!=(divisor<0):quotient=-quotient
                self.reg('eax',quotient);self.reg('edx',numerator-quotient*divisor)
            elif mn=='cmp':self.comparison=(get(0),get(1),bits)
            elif mn=='test':self.comparison=(get(0)&get(1),0,bits)
            elif mn.startswith('j'):
                a,b,width=self.comparison;sa,sb=signed(a,width),signed(b,width)
                condition={'jmp':True,'jge':sa>=sb,'jle':sa<=sb,'jg':sa>sb,'jl':sa<sb,
                           'jae':a>=b,'jbe':a<=b,'ja':a>b,'jb':a<b,'je':a==b,'jne':a!=b}[mn]
                if condition:nxt=get(0)
            elif mn=='call':self.push(nxt);nxt=get(0)
            elif mn=='ret':
                nxt=self.pop()
                if ops:self.reg('esp',self.reg('esp')+get(0))
            elif mn in ['nop']:pass
            else:raise ValueError(f'Unsupported instruction: {mn} {i.op_str}')
            pc=nxt
        raise ValueError('Instruction limit exceeded')
