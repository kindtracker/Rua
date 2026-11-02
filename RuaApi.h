#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct RuaValueType RuaValueType;
typedef struct RuaTableType RuaTableType;
typedef struct RuaFunctionType RuaFunctionType;
typedef struct RuaState RuaState;

typedef void (*RuaCFunction)();

typedef enum {
  RuaNil,
  RuaBoolean,
  RuaNumber,
  RuaString,
  RuaFunction,
  RuaTable
} RuaValueTypeEnum;

struct RuaValueType {
  RuaValueTypeEnum Type;

  union {
    bool Boolean;
    double Number;
    const char *String;
    RuaFunctionType *Function;
    TableType *Table;
  } Value;
};

struct RuaTableType {
  ValueType *Items;
  size_t Count;
  size_t Capacity;
};

struct RuaFunctionType {
  uint32_t Address;
  RuaCFunction CFunction;
  bool IsCFunction;
};

struct RuaState {
  uint32_t Pc;
  bool Running;
  bool PcChanged;
  const char *FileName;
  int Row;
  ContextType *CurrentContext;
  ValueType Stack[STACK_CAPACITY];
  int StackSize;
  CallFrameType CallStack[CALLSTACK_CAPACITY];
  int CallStackSize;
  GlobalType Globals[GLOBAL_CAPACITY];
  size_t GlobalCount;
};

void RuaPushValue(ValueType Value);
void RuaPushNil();
void RuaPushBoolean(bool Value);
void RuaPushNumber(double Value);
void RuaPushString(const char *Value);
void RuaCreateTable();
void RuaPushCFunction(RuaCFunction Function);

void RuaPop();
double RuaPopNumber();
const char *RuaPopString();
bool RuaPopBoolean();

void RuaGetGlobal(const char *Name);
void RuaSetGlobal(const char *Name);

// Define RUA_USER_INITIALIZE and declare RuaUserInitialize
// if you want to run custom initialization code when Rua starts.
void RuaUserInitialize();
