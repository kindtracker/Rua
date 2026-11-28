#pragma once
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

enum { OpLoadNumber = 2, OpMove = 13 };

#define RegisterCount 65536

typedef struct {
  double Registers[RegisterCount];
  const unsigned char *Bytecode;
  size_t BytecodeSize;
  size_t Pc;
} State;

int VmReadUint8(State *Vm, uint8_t *Result);
int VmReadUint16(State *Vm, uint16_t *Result);
int VmReadUint32(State *Vm, uint32_t *Result);
int VmReadFloat32(State *Vm, float *Result);
int VmRun(State *Vm);
