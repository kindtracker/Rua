const char *FileName = "<Anonymous>";
int Row = 1;

int VmReadUint8(State *Vm, uint8_t *Result) {
  *Result = Vm->Bytecode[Vm->Pc++];
  return RuaOk;
}

int VmReadUint16(State *Vm, uint16_t *Result) {
  uint8_t A, B;

  VmReadUint8(Vm, &A);
  VmReadUint8(Vm, &B);

  *Result = (uint16_t)(A | ((uint16_t)B << 8));
  return RuaOk;
}

int VmReadUint32(State *Vm, uint32_t *Result) {
  uint8_t A, B, C, D;

  VmReadUint8(Vm, &A);
  VmReadUint8(Vm, &B);
  VmReadUint8(Vm, &C);
  VmReadUint8(Vm, &D);

  *Result = (uint32_t)A | ((uint32_t)B << 8) | ((uint32_t)C << 16) |
            ((uint32_t)D << 24);

  return RuaOk;
}

int VmReadFloat32(State *Vm, float *Result) {
  uint32_t Bits;

  VmReadUint32(Vm, &Bits);
  memcpy(Result, &Bits, sizeof(float));

  return RuaOk;
}

int VmRun(State *Vm) {
  while (Vm->Pc < Vm->BytecodeSize) {
    uint8_t Opcode;
    VmReadUint8(Vm, &Opcode);

    switch (Opcode) {
    case OpLoadNumber: {
      float Number;
      uint16_t Destination;

      VmReadFloat32(Vm, &Number);
      VmReadUint16(Vm, &Destination);

      Vm->Registers[Destination] = Number;
      break;
    }

    case OpMove: {
      uint16_t Source;
      uint16_t Destination;

      VmReadUint16(Vm, &Source);
      VmReadUint16(Vm, &Destination);

      Vm->Registers[Destination] = Vm->Registers[Source];
      break;
    }

    default:
      Crash("Unknown opcode: %u", Opcode);
      break;
    }
  }

  return RuaOk;
}
