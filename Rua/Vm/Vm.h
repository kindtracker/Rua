#pragma once
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define RegisterCount 65536
#define RuaOk 1
#define RuaFail 0

#define Crash(...)                                                             \
  do {                                                                         \
    fflush(stdout);                                                            \
    fprintf(stderr,                                                            \
            "\x1b[38;2;255;100;100mRua:\x1b[0m %s:%d: "                        \
            "\x1b[31mError:\x1b[0m ",                                          \
            FileName, Row);                                                    \
    fprintf(stderr, __VA_ARGS__);                                              \
    fputc('\n', stderr);                                                       \
    exit(1);                                                                   \
  } while (0)

typedef struct {
  double Registers[RegisterCount];
  const unsigned char *Bytecode;
  size_t BytecodeSize;
  size_t Pc;
} State;

enum {
  OpLoadConstant = 1,
  OpLoadNumber = 2,
  OpLoadBoolean = 3,
  OpLoadNil = 4,
  OpLoadTable = 5,
  OpDeclarationFunction = 6,
  OpDeclarationVariable = 7,
  OpIndex = 8,
  OpNewIndex = 9,
  OpPush = 10,
  OpPop = 11,
  OpCall = 12,
  OpMove = 13,
  OpJumpTrue = 14,
  OpJumpFalse = 15,
  OpJumpAlways = 16,
  OpJumpAlwaysRegister = 17,
  OpGetPc = 18,
  OpFile = 19,
  OpRow = 20,
  OpAdd = 21,
  OpSubtract = 22,
  OpMultiply = 23,
  OpDivide = 24,
  OpFloorDivide = 25,
  OpModulo = 26,
  OpPower = 27,
  OpBitwiseAnd = 28,
  OpBitwiseOr = 29,
  OpBitwiseXor = 30,
  OpShiftLeft = 31,
  OpShiftRight = 32,
  OpConcatenate = 33,
  OpEqual = 34,
  OpNotEqual = 35,
  OpLessThan = 36,
  OpLessThanOrEqual = 37,
  OpGreaterThan = 38,
  OpGreaterThanOrEqual = 39,
  OpBitwiseNot = 40,
  OpNegate = 41,
  OpLength = 42,
  OpNot = 43
};

extern const char *FileName;
extern int Row;

int VmReadUint8(State *Vm, uint8_t *Result);
int VmReadUint16(State *Vm, uint16_t *Result);
int VmReadUint32(State *Vm, uint32_t *Result);
int VmReadFloat32(State *Vm, float *Result);
int VmRun(State *Vm);
