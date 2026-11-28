unsigned char Bytecode[] = BYTECODE;
State Vm = {0};

int main(int Argc, char *Argv[]) {
  Vm.Bytecode = Bytecode;
  Vm.BytecodeSize = sizeof(Bytecode);

  if (Vm.BytecodeSize < 8) {
    Crash("Invalid Rua file");
  }

  if (memcmp(Vm.Bytecode, "\177Rua", 4) != 0) {
    Crash("Invalid Rua file");
  }

  Vm.Pc = 4;

  uint32_t ConstantCount;
  VmReadUint32(&Vm, &ConstantCount);

  // TODO: Implement constants

  for (uint32_t I = 0; I < ConstantCount; I++) {
    uint32_t Length;
    VmReadUint32(&Vm, &Length);

    Vm.Pc += Length;
  }

  if (VmRun(&Vm) == RuaFail) {
    return 1;
  }

  for (int I = 0; I < RegisterCount; I++) {
    if (Vm.Registers[I] != 0) {
      printf("Register %d = %g\n", I, Vm.Registers[I]);
    }
  }

  return 0;
}
