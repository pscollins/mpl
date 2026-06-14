# RSSA IR Cheat Sheet

RSSA (Register-based SSA) is a low-level intermediate representation in MLton/MPL. It is in SSA form where blocks can take arguments (representing phi-nodes).

## Program Structure
- **Control Flags**: Comments at the top showing compiler configuration.
- **ObjectType Definitions**: `opt_N = Normal { components = (...) }` - Defines memory layouts.
- **Statics**: `var: Type = NormalObject { init = (...) }` - Global static objects.
- **Functions**: Inter-procedural units.

## Function Syntax
```rssa
fun name_N (arg1: Type1, ...): {raises = ..., returns = ...} = start_label ()
  Block1
  Block2
  ...
```

## Block Syntax
```rssa
  Label (arg1: Type1, ...) Kind = 
    Statement1
    Statement2
    Transfer
```

### Kinds
- `Jump`: Basic block.
- `CReturn { func = ... }`: Return point from a C call.
- `Cont { handler = ... }`: Continuation point for exceptions or control flow.
- `Handler`: Exception handler entry point.
- `SporkSpwn { spid = ... }`: Spawn point in MPL.
- `SpoinSync { spid = ... }`: Sync point in MPL.

## Statements
- **Bind/Move**: `var: Type = Operand`
- **PrimApp**: `var: Type = PrimName (args)` - Primitive application.
- **Object Allocation**: `var: Type = NormalObject { init = ..., tycon = ... }`
- **SetHandler**: `SetHandler (Label)` - Installs an exception handler.

## Operands
- `Var`: `x_N` or `global_N`.
- `Const`: `0x1:w64`, `0x0:w32`, etc.
- `GCState`: `<GCState>` - Pointer to global GC state.
- `Cast (operand, Type)`: Explicit type cast.
- `Offset`:
  - `OW64 (base, offset)` - Word64 offset.
  - `OP (base, offset)` - Objptr offset.
  - `Runtime (GCField)` - Access to runtime fields.
- `SequenceOffset`:
  - `XW8 (base, index, scale, offset)` - Array/Sequence access (e.g., Word8).
- `Address (operand)`: Takes the address of an offset.

## Transfers
- **Goto**: `Label (args)` - Transfer to another block in the same function.
- **Return**: `return (args)` - Return from function.
- **Switch**:
  ```rssa
  switch {test = operand,
          default = Some Label,
          expect = None,
          cases = ((val1, Label1), (val2, Label2))}
  ```
- **CCall**:
  ```rssa
  CCall {args = (...),
         func = { ... },
         return = Some Label}
  ```
- **Call**: ML function call.
  ```rssa
  func_name (args) return Label
  ```
- **Raise**: `raise (args)`
- **Spork**: Fork-like spawn in MPL.
- **Spoin**: Join-like sync in MPL.

## Common Types
- `WordN`: e.g., `Word32`, `Word64`.
- `Objptr (opt_N)`: Pointer to an object of type `opt_N`.
- `BitsN`: Padding or raw bits.
- `RealN`: Floating point.
- `CPointer`: Raw C pointer.
