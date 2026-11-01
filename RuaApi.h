#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct RuaValueType RuaValueType;
typedef struct RuaTableType RuaTableType;
typedef struct RuaFunctionType RuaFunctionType;

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

void RuaPushValue(ValueType Value);
void RuaPushNil();
void RuaPushBoolean(bool Value);
void RuaPushNumber(double Value);
void RuaPushString(const char *Value);
void RuaCreateTable();
RuaValueType RuaCreateCFunction(RuaCFunction Function);

void RuaPop();
double RuaPopNumber();
const char *RuaPopString();
bool RuaPopBoolean();

void RuaGetGlobal(const char *Name);
void RuaSetGlobal(const char *Name);

// Define RUA_USER_INITIALIZE and declare RuaUserInitialize
// if you want to run custom initialization code when Rua starts.
void RuaUserInitialize();
