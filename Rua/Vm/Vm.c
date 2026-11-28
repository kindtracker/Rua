int VmReadUint8(State *Vm, uint8_t *Result) {
  if (Vm->Pc >= Vm->BytecodeSize)
    return 0;

  *Result = Vm->Bytecode[Vm->Pc++];
  return 1;
}

int VmReadUint16(State *Vm, uint16_t *Result) {
  uint8_t A, B;

  if (!VmReadUint8(Vm, &A) || !VmReadUint8(Vm, &B))
    return 0;

  *Result = (uint16_t)(A | ((uint16_t)B << 8));
  return 1;
}

int VmReadUint32(State *Vm, uint32_t *Result) {
  uint8_t A, B, C, D;

  if (!VmReadUint8(Vm, &A) || !VmReadUint8(Vm, &B) || !VmReadUint8(Vm, &C) ||
      !VmReadUint8(Vm, &D))
    return 0;

  *Result = (uint32_t)A | ((uint32_t)B << 8) | ((uint32_t)C << 16) |
            ((uint32_t)D << 24);

  return 1;
}

int VmReadFloat32(State *Vm, float *Result) {
  uint32_t Bits;

  if (!VmReadUint32(Vm, &Bits))
    return 0;

  memcpy(Result, &Bits, sizeof(float));
  return 1;
}

int VmRun(State *Vm) {
  while (Vm->Pc < Vm->BytecodeSize) {
    uint8_t Opcode;

    if (!VmReadUint8(Vm, &Opcode))
      return 0;

    switch (Opcode) {
    case OpLoadNumber: {
      float Number;
      uint16_t Destination;

      if (!VmReadFloat32(Vm, &Number) || !VmReadUint16(Vm, &Destination))
        return 0;

      Vm->Registers[Destination] = Number;
      break;
    }

    case OpMove: {
      uint16_t Source;
      uint16_t Destination;

      if (!VmReadUint16(Vm, &Source) || !VmReadUint16(Vm, &Destination))
        return 0;

      Vm->Registers[Destination] = Vm->Registers[Source];

      break;
    }

    default:
      fprintf(stderr, "Unknown opcode: %u\n", Opcode);
      return 0;
    }
  }

  return 1;
}
