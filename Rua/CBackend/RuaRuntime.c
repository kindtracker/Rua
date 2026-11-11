#include <limits.h>
#include <math.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define REGISTER_CAPACITY 256
#define STACK_CAPACITY 256
#define CALLSTACK_CAPACITY 4096
#define GLOBAL_CAPACITY 256

char *FileName = "<Anonymous>";
int Row = 1;

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

typedef enum {
  RuaNil,
  RuaBoolean,
  RuaNumber,
  RuaString,
  RuaFunction,
  RuaTable
} ValueTypeEnum;

typedef struct ValueType ValueType;
typedef struct TableType TableType;
typedef struct FunctionType FunctionType;
typedef struct ContextType ContextType;

typedef void (*RuaCFunction)(void);

struct ValueType {
  ValueTypeEnum Type;

  union {
    bool Boolean;
    double Number;
    const char *String;
    FunctionType *Function;
    TableType *Table;
  } Value;
};

typedef struct {
  ValueType Key;
  ValueType Value;
} TableFieldType;

struct TableType {
  TableFieldType *Fields;
  size_t Count;
  size_t Capacity;
};

struct FunctionType {
  uint32_t Address;
  RuaCFunction CFunction;
  bool IsCFunction;
};

struct ContextType {
  ValueType Registers[REGISTER_CAPACITY];
  ContextType *PreviousContext;
};

typedef struct {
  const char *Name;
  ValueType Value;
} GlobalType;

typedef struct {
  ContextType *PreviousContext;
  uint32_t ReturnAddress;
} CallFrameType;

typedef struct {
  const char *Key;
  ValueType Value;
  uint64_t Hash;
  bool Used;
} HashTableEntry;

typedef struct {
  size_t Capacity;
  size_t Count;
  HashTableEntry *Array;
} HashTable;

uint32_t Pc = 1;
bool Running = true;
bool PcChanged = true;

ContextType *CurrentContext = NULL;

ValueType Stack[STACK_CAPACITY];
int StackSize = 0;

CallFrameType CallStack[CALLSTACK_CAPACITY];
int CallStackSize = 0;

HashTable *Globals;

static ContextType *CreateContext(void) {
  ContextType *Context = calloc(1, sizeof(ContextType));

  if (!Context) {
    Crash("0x%x: CreateContext: Failed to allocate context", Pc);
  }

  return Context;
}

static void NewContext(void) {
  ContextType *Context = CreateContext();

  Context->PreviousContext = CurrentContext;
  CurrentContext = Context;
}

static ValueType *GetRegister(int Register) {
  if (!CurrentContext || Register < 0 || Register >= REGISTER_CAPACITY) {
    Crash("0x%x: GetRegister: Invalid register access", Pc);
  }

  return &CurrentContext->Registers[Register];
}

static ValueType *GetRegisterUpvalue(int Register) {
  if (!CurrentContext || Register < 0 || Register >= REGISTER_CAPACITY) {
    Crash("0x%x: GetRegisterUpvalue: Invalid register access", Pc);
  }

  ContextType *Context = CurrentContext;
  while (Context) {
    ValueType *Value = &Context->Registers[Register];
    if (Value->Type != RuaNil) {
      return Value;
    }

    Context = Context->PreviousContext;
  }

  return &CurrentContext->Registers[Register];
}

static ValueType CreateNil(void) {
  ValueType Result = {0};
  Result.Type = RuaNil;
  return Result;
}

static void PutNil(ValueType *Register) {
  if (Register) {
    *Register = CreateNil();
  }
}

static void Push(ValueType *Register) {
  if (!Register) {
    Crash("0x%x: Push: Attempt to push a NULL register", Pc);
  }

  if (StackSize >= STACK_CAPACITY) {
    Crash("0x%x: Push: Stack overflow (Capacity %d)", Pc, STACK_CAPACITY);
  }

  Stack[StackSize++] = *Register;
}

static ValueType Pop(void) {
  if (StackSize <= 0) {
    Crash("0x%x: Pop: Attempt to pop from an empty stack", Pc);
  }

  return Stack[--StackSize];
}

static void ClearStack(void) { StackSize = 0; }

static TableType *NewTable(size_t Capacity) {
  TableType *Table = calloc(1, sizeof(TableType));

  if (!Table) {
    Crash("0x%x: NewTable: Failed to allocate table", Pc);
  }

  if (Capacity > SIZE_MAX / sizeof(TableFieldType)) {
    free(Table);
    Crash("0x%x: NewTable: Table capacity overflow", Pc);
  }

  Table->Capacity = Capacity;

  if (Capacity > 0) {
    Table->Fields = calloc(Capacity, sizeof(TableFieldType));

    if (!Table->Fields) {
      free(Table);
      Crash("0x%x: NewTable: Failed to allocate table fields", Pc);
    }
  }

  return Table;
}

static bool ValuesEqual(ValueType Left, ValueType Right) {
  if (Left.Type != Right.Type) {
    return false;
  }

  switch (Left.Type) {
  case RuaNil:
    return true;

  case RuaBoolean:
    return Left.Value.Boolean == Right.Value.Boolean;

  case RuaNumber:
    return Left.Value.Number == Right.Value.Number;

  case RuaString:
    if (!Left.Value.String || !Right.Value.String) {
      return Left.Value.String == Right.Value.String;
    }

    return strcmp(Left.Value.String, Right.Value.String) == 0;

  case RuaFunction:
    return Left.Value.Function == Right.Value.Function;

  case RuaTable:
    return Left.Value.Table == Right.Value.Table;
  }

  return false;
}

static void TablePush(TableType *Table, ValueType Key, ValueType Value) {
  if (!Table) {
    Crash("0x%x: TablePush: Attempt to push a field into a non-table", Pc);
  }

  if (Key.Type == RuaNil) {
    Crash("0x%x: TablePush: Table index is nil", Pc);
  }

  if (Table->Count >= Table->Capacity) {
    size_t NewCapacity = Table->Capacity == 0 ? 4 : Table->Capacity * 2;

    if (NewCapacity < Table->Capacity ||
        NewCapacity > SIZE_MAX / sizeof(TableFieldType)) {
      Crash("0x%x: TablePush: Table capacity overflow", Pc);
    }

    TableFieldType *NewFields =
        realloc(Table->Fields, NewCapacity * sizeof(TableFieldType));

    if (!NewFields) {
      Crash("0x%x: TablePush: Failed to allocate table fields", Pc);
    }

    Table->Fields = NewFields;
    Table->Capacity = NewCapacity;
  }

  Table->Fields[Table->Count++] = (TableFieldType){.Key = Key, .Value = Value};
}

static ValueType TableIndex(TableType *Table, ValueType Key) {
  if (!Table) {
    Crash("0x%x: TableIndex: Attempt to index a non-table", Pc);
  }

  if (Key.Type == RuaNil) {
    Crash("0x%x: TableIndex: Table index is nil", Pc);
  }

  for (size_t Idx = 0; Idx < Table->Count; Idx++) {
    TableFieldType *Field = &Table->Fields[Idx];

    if (ValuesEqual(Field->Key, Key)) {
      return Field->Value;
    }
  }

  return CreateNil();
}

static void TableNewIndex(TableType *Table, ValueType Key, ValueType Value) {
  if (!Table) {
    Crash("0x%x: TableNewIndex: Attempt to newindex a non-table", Pc);
  }

  if (Key.Type == RuaNil) {
    Crash("0x%x: TableNewIndex: Table index is nil", Pc);
  }

  for (size_t Idx = 0; Idx < Table->Count; Idx++) {
    TableFieldType *Field = &Table->Fields[Idx];

    if (ValuesEqual(Field->Key, Key)) {
      if (Value.Type == RuaNil) {
        memmove(&Table->Fields[Idx], &Table->Fields[Idx + 1],
                (Table->Count - Idx - 1) * sizeof(TableFieldType));

        Table->Count--;
      } else {
        Field->Value = Value;
      }

      return;
    }
  }

  if (Value.Type != RuaNil) {
    TablePush(Table, Key, Value);
  }
}

static uint64_t HashString(const char *String) {
  uint64_t Hash = 14695981039346656037ULL;

  while (*String) {
    Hash ^= (unsigned char)*String++;
    Hash *= 1099511628211ULL;
  }

  return Hash;
}

static HashTableEntry *HashTableFind(HashTable *Table, const char *Key,
                                     uint64_t Hash) {
  size_t Index = Hash % Table->Capacity;

  for (size_t Idx = 0; Idx < Table->Capacity; Idx++) {
    HashTableEntry *Entry = &Table->Array[Index];

    if (!Entry->Used) {
      return NULL;
    }

    if (Entry->Hash == Hash && strcmp(Entry->Key, Key) == 0) {
      return Entry;
    }

    Index = (Index + 1) % Table->Capacity;
  }

  return NULL;
}

static ValueType HashTableIndex(HashTable *Table, const char *Key) {
  uint64_t Hash = HashString(Key);
  HashTableEntry *Entry = HashTableFind(Table, Key, Hash);
  return Entry ? Entry->Value : CreateNil();
}

static void HashTableNewIndex(HashTable *Table, const char *Key,
                              ValueType Value) {
  uint64_t Hash = HashString(Key);
  HashTableEntry *Entry = HashTableFind(Table, Key, Hash);
  if (Entry) {
    Entry->Value = Value;
    return;
  }

  if (Table->Count >= Table->Capacity) {
    Crash("HashTableNewIndex: Hash table overflow");
  }

  size_t Index = Hash % Table->Capacity;

  while (Table->Array[Index].Used) {
    Index = (Index + 1) % Table->Capacity;
  }

  Table->Array[Index] = (HashTableEntry){
      .Key = Key,
      .Value = Value,
      .Hash = Hash,
      .Used = true,
  };

  Table->Count++;
}

static HashTable *HashTableNew(size_t Capacity) {
  if (Capacity == 0) {
    Capacity = 256;
  }

  HashTable *Table = calloc(1, sizeof(HashTable));

  if (!Table) {
    Crash("HashTableNew: Failed to allocate hash table");
  }

  Table->Array = calloc(Capacity, sizeof(HashTableEntry));

  if (!Table->Array) {
    free(Table);
    Crash("HashTableNew: Failed to allocate entries");
  }

  Table->Capacity = Capacity;

  return Table;
}

static void SetGlobal(const char *Name, ValueType Value) {
  if (!Name) {
    Crash("0x%x: SetGlobal: Attempt to use a NULL global name", Pc);
  }

  HashTableNewIndex(Globals, Name, Value);
}

static ValueType GetGlobal(const char *Name) {
  if (!Name) {
    Crash("0x%x: GetGlobal: Attempt to use a NULL global name", Pc);
  }

  return HashTableIndex(Globals, Name);
}

static void Jump(uint32_t TargetPc) {
  if (CallStackSize >= CALLSTACK_CAPACITY) {
    Crash("0x%x: Jump: CallStack overflow", Pc);
  }

  if (TargetPc == 0) {
    Crash("0x%x: Jump: Invalid target address", Pc);
  }

  ContextType *Context = CreateContext();
  Context->PreviousContext = CurrentContext;
  CallFrameType *Frame = &CallStack[CallStackSize++];
  Frame->PreviousContext = CurrentContext;
  Frame->ReturnAddress = Pc + 1;

  CurrentContext = Context;

  Pc = TargetPc;
  PcChanged = true;
}

static void Return(void) {
  if (CallStackSize <= 0) {
    Crash("0x%x: Return: Attempt to return without an active function call",
          Pc);
  }

  CallFrameType Frame = CallStack[--CallStackSize];

  free(CurrentContext);

  CurrentContext = Frame.PreviousContext;
  Pc = Frame.ReturnAddress;

  PcChanged = true;
}
void RuaPushNil(void) {
  ValueType Result = CreateNil();
  Push(&Result);
}

void RuaPushBoolean(bool Value) {
  ValueType Result = {0};
  Result.Type = RuaBoolean;
  Result.Value.Boolean = Value;
  Push(&Result);
}

void RuaPushNumber(double Value) {
  ValueType Result = {0};
  Result.Type = RuaNumber;
  Result.Value.Number = Value;
  Push(&Result);
}

void RuaPushString(const char *Value) {
  ValueType Result = {0};
  Result.Type = RuaString;
  Result.Value.String = Value;
  Push(&Result);
}

void RuaPop(void) { (void)Pop(); }

double RuaPopNumber(void) {
  ValueType Value = Pop();

  if (Value.Type != RuaNumber) {
    Crash("RuaPopNumber: Expected a number");
  }

  return Value.Value.Number;
}

const char *RuaPopString(void) {
  ValueType Value = Pop();

  if (Value.Type != RuaString) {
    Crash("RuaPopString: Expected a string");
  }

  return Value.Value.String;
}

bool RuaPopBoolean(void) {
  ValueType Value = Pop();

  if (Value.Type != RuaBoolean) {
    Crash("RuaPopBoolean: Expected a boolean");
  }

  return Value.Value.Boolean;
}

void RuaGetGlobal(const char *Name) {
  ValueType Result = GetGlobal(Name);
  Push(&Result);
}

void RuaSetGlobal(const char *Name) { SetGlobal(Name, Pop()); }

void RuaCreateTable(void) {
  ValueType Result = {0};
  Result.Type = RuaTable;
  Result.Value.Table = NewTable(0);
  Push(&Result);
}

void RuaPushCFunction(RuaCFunction Function) {
  if (!Function) {
    Crash("RuaPushCFunction: Attempt to create a NULL function");
  }

  FunctionType *Result = calloc(1, sizeof(FunctionType));

  if (!Result) {
    Crash("RuaPushCFunction: Failed to allocate function");
  }

  Result->CFunction = Function;
  Result->IsCFunction = true;

  ValueType Value = {0};
  Value.Type = RuaFunction;
  Value.Value.Function = Result;

  Push(&Value);
}

static void Print(void) {
  const char *String = RuaPopString();
  printf("%s\n", String);
}

static void LuaRuntimeInitialize(void) {
  RuaPushCFunction(Print);
  RuaSetGlobal("print");
}

// RuaExecuteIr

int RuaDefaultEntryPoint(int Argc, char *Argv[]) {
  (void)Argc;
  (void)Argv;

  Globals = HashTableNew(0);

  LuaRuntimeInitialize();

#ifdef RUA_USER_INITIALIZE
  RuaUserInitialize();
#endif

  while (Running) {
    PcChanged = false;

    RuaExecuteIr();

    if (Running && !PcChanged) {
      Pc++;
    }
  }

  while (CallStackSize > 0) {
    free(CurrentContext);

    CallFrameType Frame = CallStack[--CallStackSize];
    CurrentContext = Frame.PreviousContext;
  }

  free(CurrentContext);
  CurrentContext = NULL;

  return 0;
}
