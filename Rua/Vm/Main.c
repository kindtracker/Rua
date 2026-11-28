unsigned char Bytecode[] = BYTECODE;
State Vm = {0};

int main(int Argc, char *Argv[]) {
  Vm.Bytecode = Bytecode;
  Vm.BytecodeSize = sizeof(Bytecode);

  if (Vm.BytecodeSize < 8) {
    fprintf(stderr, "Invalid bytecode\n");
    return 1;
  }

  if (memcmp(Vm.Bytecode, "\177Rua", 4) != 0) {
    fprintf(stderr, "Invalid Rua file\n");
    return 1;
  }

  Vm.Pc = 4;

  uint32_t ConstantCount;

  if (!VmReadUint32(&Vm, &ConstantCount))
    return 1;

  // TODO: Implement constants

  for (uint32_t I = 0; I < ConstantCount; I++) {
    uint32_t Length;

    if (!VmReadUint32(&Vm, &Length))
      return 1;

    if (Length > Vm.BytecodeSize - Vm.Pc)
      return 1;

    Vm.Pc += Length;
  }

  if (!VmRun(&Vm))
    return 1;

  for (int I = 0; I < RegisterCount; I++) {
    if (Vm.Registers[I] != 0)
      printf("Register %d = %g\n", I, Vm.Registers[I]);
  }

  return 0;
}
