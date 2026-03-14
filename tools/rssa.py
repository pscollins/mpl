from dataclasses import dataclass, field
from typing import List, Optional, Tuple, Union, Any
import re

@dataclass
class Type:
    name: str
    def __str__(self):
        return self.name

@dataclass
class Var:
    name: str
    def __str__(self):
        return self.name

@dataclass
class Label:
    name: str
    def __str__(self):
        return self.name

@dataclass
class Func:
    name: str
    def __str__(self):
        return self.name

@dataclass
class Const:
    value: str
    def __str__(self):
        return self.value

@dataclass
class ObjptrTycon:
    name: str
    def __str__(self):
        return self.name

@dataclass
class GCField:
    name: str
    def __str__(self):
        return self.name

# Operand
@dataclass
class Operand:
    def get_vars(self) -> List[Var]:
        return []

@dataclass
class Cast(Operand):
    operand: Operand
    ty: Type
    def __str__(self):
        return f"Cast ({self.operand}, {self.ty})"
    def get_vars(self) -> List[Var]:
        return self.operand.get_vars()

@dataclass
class ConstOperand(Operand):
    const: Const
    def __str__(self):
        return str(self.const)

@dataclass
class GCStateOperand(Operand):
    def __str__(self):
        return "<GCState>"

@dataclass
class Offset(Operand):
    base: Operand
    offset: int
    ty: Type
    def __str__(self):
        return f"Offset {{base: {self.base}, offset: {self.offset}, ty: {self.ty}}}"
    def get_vars(self) -> List[Var]:
        return self.base.get_vars()

@dataclass
class ObjptrTyconOperand(Operand):
    tycon: ObjptrTycon
    def __str__(self):
        return str(self.tycon)

@dataclass
class RuntimeOperand(Operand):
    field: GCField
    def __str__(self):
        return f"Runtime {self.field}"

@dataclass
class SequenceOffset(Operand):
    base: Operand
    index: Operand
    offset: int
    scale: int
    ty: Type
    def __str__(self):
        return f"SequenceOffset {{base: {self.base}, index: {self.index}, offset: {self.offset}, scale: {self.scale}, ty: {self.ty}}}"
    def get_vars(self) -> List[Var]:
        return self.base.get_vars() + self.index.get_vars()

@dataclass
class VarOperand(Operand):
    var: Var
    ty: Type
    def __str__(self):
        return str(self.var)
    def get_vars(self) -> List[Var]:
        return [self.var]

@dataclass
class Address(Operand):
    operand: Operand
    def __str__(self):
        return f"Address {self.operand}"
    def get_vars(self) -> List[Var]:
        return self.operand.get_vars()

# Object
@dataclass
class ObjectDef:
    def get_vars(self) -> List[Var]:
        return []

@dataclass
class NormalObject(ObjectDef):
    tycon: ObjptrTycon
    init: List[dict] # {offset, src}
    def __str__(self):
        inits = ", ".join([f"{{offset = {i['offset']}, src = {i['src']}}}" for i in self.init])
        return f"NormalObject {{init = ({inits}), tycon = {self.tycon}}}"
    def get_vars(self) -> List[Var]:
        res = []
        for i in self.init:
            res.extend(i['src'].get_vars())
        return res

@dataclass
class SequenceObject(ObjectDef):
    tycon: ObjptrTycon
    init: List[Operand]
    def __str__(self):
        inits = ", ".join([str(i) for i in self.init])
        return f"SequenceObject {{init = ({inits}), tycon = {self.tycon}}}"
    def get_vars(self) -> List[Var]:
        res = []
        for i in self.init:
            res.extend(i.get_vars())
        return res

# Statement
@dataclass
class Statement:
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        return [], []

@dataclass
class Bind(Statement):
    dst: Tuple[Var, Type]
    pinned: bool
    src: Operand
    def __str__(self):
        pinned_str = "pinned " if self.pinned else ""
        return f"{self.dst[0]}: {self.dst[1]} = {pinned_str}{self.src}"
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        return [self.dst[0]], self.src.get_vars()

@dataclass
class Move(Statement):
    dst: Operand
    src: Operand
    def __str__(self):
        return f"{self.dst} = {self.src}"
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        # Move can be Var = Var or Offset = Var etc.
        # If dst is Var, it's a def.
        defs = []
        if isinstance(self.dst, VarOperand):
            defs.append(self.dst.var)
        uses = self.src.get_vars()
        if not isinstance(self.dst, VarOperand):
            uses.extend(self.dst.get_vars())
        return defs, uses

@dataclass
class ObjectStmt(Statement):
    dst: Tuple[Var, Type]
    obj: ObjectDef
    def __str__(self):
        return f"{self.dst[0]}: {self.dst[1]} = {self.obj}"
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        return [self.dst[0]], self.obj.get_vars()

@dataclass
class PrimApp(Statement):
    dst: Optional[Tuple[Var, Type]]
    prim: str
    args: List[Operand]
    def __str__(self):
        args_str = ", ".join([str(a) for a in self.args])
        dst_str = f"{self.dst[0]}: {self.dst[1]} = " if self.dst else ""
        return f"{dst_str}{self.prim} ({args_str})"
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        defs = [self.dst[0]] if self.dst else []
        uses = []
        for a in self.args:
            uses.extend(a.get_vars())
        return defs, uses

@dataclass
class SetHandler(Statement):
    label: Label
    def __str__(self):
        return f"SetHandler ({self.label})"

# Transfer
@dataclass
class Transfer:
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        return [], []

@dataclass
class Goto(Transfer):
    dst: Label
    args: List[Operand]
    def __str__(self):
        args_str = ", ".join([str(a) for a in self.args])
        return f"{self.dst} ({args_str})"
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        uses = []
        for a in self.args:
            uses.extend(a.get_vars())
        return [], uses

@dataclass
class Call(Transfer):
    func: Func
    args: List[Operand]
    return_label: Label
    def __str__(self):
        args_str = ", ".join([str(a) for a in self.args])
        return f"{self.func} ({args_str}) return {self.return_label}"
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        uses = []
        for a in self.args:
            uses.extend(a.get_vars())
        return [], uses

@dataclass
class TailCall(Transfer):
    func: Func
    args: List[Operand]
    def __str__(self):
        args_str = ", ".join([str(a) for a in self.args])
        return f"{self.func} ({args_str}) Tail"
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        uses = []
        for a in self.args:
            uses.extend(a.get_vars())
        return [], uses

@dataclass
class CCall(Transfer):
    func: str
    args: List[Operand]
    return_label: Optional[Label] = None
    def __str__(self):
        args_str = ", ".join([str(a) for a in self.args])
        ret_str = f" return {self.return_label}" if self.return_label else ""
        return f"ccall {self.func} ({args_str}){ret_str}"
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        uses = []
        for a in self.args:
            uses.extend(a.get_vars())
        return [], uses

@dataclass
class Return(Transfer):
    args: List[Operand]
    def __str__(self):
        args_str = ", ".join([str(a) for a in self.args])
        return f"return ({args_str})"
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        uses = []
        for a in self.args:
            uses.extend(a.get_vars())
        return [], uses

@dataclass
class Raise(Transfer):
    args: List[Operand]
    def __str__(self):
        args_str = ", ".join([str(a) for a in self.args])
        return f"raise ({args_str})"
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        uses = []
        for a in self.args:
            uses.extend(a.get_vars())
        return [], uses

@dataclass
class Switch(Transfer):
    test: Operand
    cases: List[Tuple[Const, Label]]
    default: Optional[Label]
    def __str__(self):
        cases_str = ", ".join([f"({c[0]}, {c[1]})" for c in self.cases])
        default_str = f", default = {self.default}" if self.default else ""
        return f"switch {{test = {self.test}, cases = ({cases_str}){default_str}}}"
    def get_defs_uses(self) -> Tuple[List[Var], List[Var]]:
        return [], self.test.get_vars()

# Kind
@dataclass
class Kind:
    pass

@dataclass
class JumpKind(Kind):
    def __str__(self): return "Jump"

@dataclass
class HandlerKind(Kind):
    def __str__(self): return "Handler"

# Block
@dataclass
class Block:
    label: Label
    args: List[Tuple[Var, Type]]
    kind: Kind
    statements: List[Statement]
    transfer: Transfer
    def __str__(self):
        args_str = ", ".join([f"{v}: {t}" for v, t in self.args])
        res = f"  {self.label} ({args_str}) {self.kind} = \n"
        for stmt in self.statements:
            res += f"    {stmt}\n"
        res += f"    {self.transfer}"
        return res

# Function
@dataclass
class Function:
    name: Func
    args: List[Tuple[Var, Type]]
    start: Label
    blocks: List[Block]
    raises: Optional[List[Type]] = None
    returns: Optional[List[Type]] = None
    def __str__(self):
        args_str = ", ".join([f"{v}: {t}" for v, t in self.args])
        raises_str = "None" if self.raises is None else f"Some ({', '.join(map(str, self.raises))})"
        returns_str = "None" if self.returns is None else f"Some ({', '.join(map(str, self.returns))})"
        res = f"fun {self.name} ({args_str}): {{raises = {raises_str}, returns = {returns_str}}} = {self.start} ()\n"
        for block in self.blocks:
            res += str(block) + "\n"
        return res

# Program
@dataclass
class Program:
    functions: List[Function]
    main: Optional[Function] = None
    object_types: List[dict] = field(default_factory=list)
    statics: List[dict] = field(default_factory=list)

    def __str__(self):
        res = ""
        if self.object_types:
            res += "ObjectTypes:\n"
            for ot in self.object_types:
                res += f"{ot['name']} = {ot['def']}\n"
            res += "\n"
        if self.statics:
            res += "Statics:\n"
            for s in self.statics:
                res += f"{s['name']} = {s['def']}\n"
            res += "\n"
        if self.main:
            res += "Main:\n"
            res += str(self.main) + "\n"
        res += "Functions:\n"
        for f in self.functions:
            res += str(f) + "\n"
        return res

    def get_use_def_subgraph(self, target_var_name: str) -> List[Any]:
        # Maps var name to list of (parent, element) where element is Stmt/Transfer/Header
        # and parent is Function/Block
        var_to_defs = {}
        var_to_uses = {}
        
        all_elements = [] # List of (function, block, element)

        def add_def(v, f, b, e):
            name = str(v)
            if name not in var_to_defs: var_to_defs[name] = []
            var_to_defs[name].append((f, b, e))
        
        def add_use(v, f, b, e):
            name = str(v)
            if name not in var_to_uses: var_to_uses[name] = []
            var_to_uses[name].append((f, b, e))

        funcs = self.functions + ([self.main] if self.main else [])
        for f in funcs:
            # Header defs
            for v, t in f.args:
                add_def(v, f, None, f)
            
            for b in f.blocks:
                # Block arg defs
                for v, t in b.args:
                    add_def(v, f, b, b)
                
                for s in b.statements:
                    defs, uses = s.get_defs_uses()
                    for d in defs: add_def(d, f, b, s)
                    for u in uses: add_use(u, f, b, s)
                
                defs, uses = b.transfer.get_defs_uses()
                for d in defs: add_def(d, f, b, b.transfer)
                for u in uses: add_use(u, f, b, b.transfer)

                # Special case: Goto/Call/etc. define variables in the target block
                if isinstance(b.transfer, Goto):
                    # Find target block
                    target = next((bt for bt in f.blocks if bt.label.name == b.transfer.dst.name), None)
                    if target:
                        for i, arg_op in enumerate(b.transfer.args):
                            if i < len(target.args):
                                dst_var = target.args[i][0]
                                # This is a "use-def" edge: dst_var is defined by b.transfer (which uses arg_op)
                                # For simplicity, we'll just say the transfer uses the operands and "defines" the target block args
                                add_def(dst_var, f, target, b.transfer)
                                for u in arg_op.get_vars():
                                    add_use(u, f, b, b.transfer)

        # BFS
        visited_vars = set()
        visited_elements_ids = set()
        visited_elements = []
        queue = [target_var_name]
        
        while queue:
            curr_var = queue.pop(0)
            if curr_var in visited_vars: continue
            visited_vars.add(curr_var)
            
            # Definitions of this var
            for f, b, e in var_to_defs.get(curr_var, []):
                triple_id = (id(f), id(b), id(e))
                if triple_id not in visited_elements_ids:
                    visited_elements_ids.add(triple_id)
                    visited_elements.append((f, b, e))
                
                # Add all variables USED in this definition
                uses = []
                if isinstance(e, Statement) or isinstance(e, Transfer):
                    _, uses = e.get_defs_uses()
                
                for u in uses:
                    u_name = str(u)
                    if u_name not in visited_vars:
                        queue.append(u_name)

            # Uses of this var
            # Only follow uses for local variables or if it's the target var
            if not curr_var.startswith("global_") or curr_var == target_var_name:
                for f, b, e in var_to_uses.get(curr_var, []):
                    triple_id = (id(f), id(b), id(e))
                    if triple_id not in visited_elements_ids:
                        visited_elements_ids.add(triple_id)
                        visited_elements.append((f, b, e))
                    
                    # Add all variables DEFINED by this use
                    defs = []
                    if isinstance(e, Statement) or isinstance(e, Transfer):
                        defs, _ = e.get_defs_uses()
                    elif isinstance(e, Block): # Block arg header
                        # The variables are the block arguments
                        defs = [a[0] for a in e.args]
                    
                    for d in defs:
                        d_name = str(d)
                        if d_name not in visited_vars:
                            queue.append(d_name)

        return visited_elements

class RSSAParser:
    def __init__(self, text: str):
        text = re.sub(r"\(\*.*?\*\)", "", text, flags=re.DOTALL)
        self.text = text

    def parse_program(self) -> Program:
        object_types = []
        statics = []
        main = None
        functions = []

        sections = re.split(r"^(ObjectTypes|Statics|Main|Functions):", self.text, flags=re.MULTILINE)
        
        for i in range(1, len(sections), 2):
            section_name = sections[i]
            section_content = sections[i+1].strip()
            
            if section_name == "ObjectTypes":
                ot_lines = self.split_into_definitions(section_content)
                for line in ot_lines:
                    if "=" in line:
                        name, definition = line.split("=", 1)
                        object_types.append({"name": name.strip(), "def": definition.strip()})
            elif section_name == "Statics":
                s_lines = self.split_into_definitions(section_content)
                for line in s_lines:
                    if "=" in line:
                        name, definition = line.split("=", 1)
                        statics.append({"name": name.strip(), "def": definition.strip()})
            elif section_name == "Main":
                main = self.parse_function(section_content)
            elif section_name == "Functions":
                f_matches = re.finditer(r"^fun\s+(.*?)(?=^fun|\Z)", section_content, re.MULTILINE | re.DOTALL)
                for m in f_matches:
                    f = self.parse_function("fun " + m.group(1))
                    if f: functions.append(f)
                            
        return Program(functions, main, object_types, statics)

    def split_into_definitions(self, text: str) -> List[str]:
        lines = text.split("\n")
        defs = []
        current = ""
        depth = 0
        for line in lines:
            if not line.strip(): continue
            if not line.startswith(" ") and "=" in line and depth == 0:
                if current: defs.append(current.strip())
                current = line
            else:
                current += "\n" + line
            depth += line.count("(") + line.count("{") - line.count(")") - line.count("}")
        if current: defs.append(current.strip())
        return defs

    def parse_function(self, text: str) -> Optional[Function]:
        # Handle headers with nested parens
        # fun name (args): {meta} = start ()
        header_re = r"fun\s+(\w+)\s*\((.*)\):\s*\{(.*)\}\s*=\s*(\w+)\s*\(\)"
        # We need to find the FIRST ): that is at depth 0 relative to the opening (
        # and the FIRST } = that is at depth 0 relative to the opening {
        
        m_name = re.match(r"fun\s+(\w+)", text)
        if not m_name: return None
        name = m_name.group(1)
        
        # Find args
        args_start = text.find("(", m_name.end())
        if args_start == -1: return None
        args_end = self.find_matching_char(text, args_start, "(", ")")
        if args_end == -1: return None
        args_str = text[args_start+1:args_end]
        
        # Find meta
        meta_start = text.find("{", args_end)
        if meta_start == -1: return None
        meta_end = self.find_matching_char(text, meta_start, "{", "}")
        if meta_end == -1: return None
        meta_str = text[meta_start+1:meta_end]
        
        # Find start label
        start_match = re.search(r"=\s*(\w+)\s*\(\)", text[meta_end:])
        if not start_match: return None
        start_label = Label(start_match.group(1))
        
        func_name = Func(name)
        args = self.parse_args(args_str)
        
        raises = None
        returns = None
        m_raises = re.search(r"raises\s*=\s*(None|Some\s*\((.*?)\))", meta_str)
        if m_raises:
            if m_raises.group(1) == "None": raises = None
            else: raises = [Type(t.strip()) for t in self.split_by_comma(m_raises.group(2))]
        m_returns = re.search(r"returns\s*=\s*(None|Some\s*\((.*?)\))", meta_str)
        if m_returns:
            if m_returns.group(1) == "None": returns = None
            else: returns = [Type(t.strip()) for t in self.split_by_comma(m_returns.group(2))]

        # Blocks
        block_parts = re.split(r"^\s+(\w+)\s*\((.*?)\)\s*(\w+)\s*=", text, flags=re.MULTILINE)
        blocks = []
        for i in range(1, len(block_parts), 4):
            label = Label(block_parts[i])
            b_args = self.parse_args(block_parts[i+1])
            kind = JumpKind() if block_parts[i+2] == "Jump" else HandlerKind()
            
            body = block_parts[i+3]
            stmts_and_transfer = self.split_statements(body)
            
            statements = []
            transfer = Goto(Label("error"), [])
            if stmts_and_transfer:
                for line in stmts_and_transfer[:-1]:
                    stmt = self.parse_statement(line)
                    if stmt: statements.append(stmt)
                transfer = self.parse_transfer(stmts_and_transfer[-1])
            
            blocks.append(Block(label, b_args, kind, statements, transfer))
            
        return Function(func_name, args, start_label, blocks, raises, returns)

    def find_matching_char(self, s: str, start: int, open_c: str, close_c: str) -> int:
        depth = 0
        for i in range(start, len(s)):
            if s[i] == open_c: depth += 1
            elif s[i] == close_c:
                depth -= 1
                if depth == 0: return i
        return -1

    def split_statements(self, text: str) -> List[str]:
        lines = text.split("\n")
        stmts = []
        current = ""
        depth = 0
        for line in lines:
            if not line.strip(): continue
            is_new = line.startswith("    ") and not line.startswith("     ") and depth == 0
            if is_new and current:
                stmts.append(current.strip())
                current = line
            else:
                current += ("\n" if current else "") + line
            depth += line.count("(") + line.count("{") - line.count(")") - line.count("}")
        if current: stmts.append(current.strip())
        return stmts

    def parse_args(self, args_str: str) -> List[Tuple[Var, Type]]:
        if not args_str.strip(): return []
        parts = self.split_by_comma(args_str)
        args = []
        for p in parts:
            if ":" in p:
                v, t = p.split(":", 1)
                args.append((Var(v.strip()), Type(t.strip())))
        return args

    def split_by_comma(self, s: str) -> List[str]:
        parts = []
        current = ""
        depth = 0
        for char in s:
            if char in "({": depth += 1
            if char in ")}": depth -= 1
            if char == ',' and depth == 0:
                parts.append(current.strip())
                current = ""
            else:
                current += char
        parts.append(current.strip())
        return [p for p in parts if p]

    def parse_statement(self, line: str) -> Optional[Statement]:
        line = line.strip()
        if line.startswith("SetHandler"):
            m = re.match(r"SetHandler\s*\((.*?)\)", line)
            if m: return SetHandler(Label(m.group(1).strip()))

        eq_idx = self.find_top_level(line, "=")
        if eq_idx != -1:
            lhs = line[:eq_idx].strip()
            rhs = line[eq_idx+1:].strip()
            pinned = False
            if lhs.startswith("pinned "):
                pinned = True
                lhs = lhs[7:].strip()
            
            if ":" in lhs:
                v_str, t_str = lhs.split(":", 1)
                dst = (Var(v_str.strip()), Type(t_str.strip()))
                if rhs.startswith("NormalObject") or rhs.startswith("SequenceObject"):
                    return ObjectStmt(dst, self.parse_object_def(rhs))
                m_prim = re.match(r"^(\w+)\s*\((.*)\)$", rhs, re.DOTALL)
                if m_prim and m_prim.group(1) not in ["OW64", "OP", "XW8", "XW64", "Cast"]:
                    return PrimApp(dst, m_prim.group(1), self.parse_operand_list(m_prim.group(2)))
                return Bind(dst, pinned, self.parse_operand(rhs))
            else:
                return Move(self.parse_operand(lhs), self.parse_operand(rhs))

        m_prim = re.match(r"^(\w+)\s*\((.*)\)$", line, re.DOTALL)
        if m_prim and m_prim.group(1) not in ["OW64", "OP", "XW8", "XW64", "Cast", "SetHandler"]:
            return PrimApp(None, m_prim.group(1), self.parse_operand_list(m_prim.group(2)))
        return None

    def find_top_level(self, s: str, char: str) -> int:
        depth = 0
        for i, c in enumerate(s):
            if c in "({": depth += 1
            elif c in ")}": depth -= 1
            elif c == char and depth == 0: return i
        return -1

    def parse_object_def(self, s: str) -> ObjectDef:
        if s.startswith("NormalObject"):
            body = s[12:].strip().strip("{}")
            tycon_match = re.search(r"tycon\s*=\s*(\w+)", body)
            tycon = ObjptrTycon(tycon_match.group(1)) if tycon_match else ObjptrTycon("unknown")
            init = []
            init_match = re.search(r"init\s*=\s*\((.*)\)", body, re.DOTALL)
            if init_match:
                items = self.split_braced_items(init_match.group(1))
                for item in items:
                    item = item.strip("{} ")
                    m_off = re.search(r"offset\s*=\s*(\d+)", item)
                    m_src = re.search(r"src\s*=\s*(.*)", item, re.DOTALL)
                    if m_off and m_src:
                        init.append({"offset": int(m_off.group(1)), "src": self.parse_operand(m_src.group(1).strip())})
            return NormalObject(tycon, init)
        return SequenceObject(ObjptrTycon("unknown"), [])

    def split_braced_items(self, s: str) -> List[str]:
        items = []
        current = ""
        depth = 0
        for char in s:
            if char == '{': depth += 1
            current += char
            if char == '}':
                depth -= 1
                if depth == 0:
                    items.append(current.strip())
                    current = ""
        return items

    def parse_transfer(self, line: str) -> Transfer:
        line = line.strip()
        if line.startswith("return"):
            m = re.match(r"return\s*\((.*)\)", line, re.DOTALL)
            return Return(self.parse_operand_list(m.group(1)) if m else [])
        if line.startswith("raise"):
            m = re.match(r"raise\s*\((.*)\)", line, re.DOTALL)
            return Raise(self.parse_operand_list(m.group(1)) if m else [])
        if line.startswith("switch"):
            body = line[6:].strip().strip("{}")
            test_match = re.search(r"test\s*=\s*(.*?),", body, re.DOTALL)
            test = self.parse_operand(test_match.group(1)) if test_match else ConstOperand(Const("unknown"))
            default = None
            def_match = re.search(r"default\s*=\s*(None|(\w+))", body)
            if def_match and def_match.group(2): default = Label(def_match.group(2))
            cases = []
            cases_match = re.search(r"cases\s*=\s*\((.*)\)", body, re.DOTALL)
            if cases_match:
                c_items = re.findall(r"\((.*?),\s*(\w+)\)", cases_match.group(1))
                for c, l in c_items: cases.append((Const(c.strip()), Label(l)))
            return Switch(test, cases, default)
        if "ccall" in line:
            m = re.match(r"ccall\s+(\w+)\s*\((.*?)\)(\s+return\s+(\w+))?", line, re.DOTALL)
            if m: return CCall(m.group(1), self.parse_operand_list(m.group(2)), Label(m.group(4)) if m.group(4) else None)
        if line.endswith("Tail"):
            m = re.match(r"(\w+)\s*\((.*?)\)\s*Tail", line, re.DOTALL)
            if m: return TailCall(Func(m.group(1)), self.parse_operand_list(m.group(2)))
        m = re.match(r"(\w+)\s*\((.*?)\)(\s+return\s+(\w+))?", line, re.DOTALL)
        if m:
            target, args_s = m.group(1), m.group(2)
            args = self.parse_operand_list(args_s)
            return Call(Func(target), args, Label(m.group(4))) if m.group(4) else Goto(Label(target), args)
        return Goto(Label(line), [])

    def parse_operand_list(self, s: str) -> List[Operand]:
        return [self.parse_operand(p) for p in self.split_by_comma(s) if p.strip()]

    def find_last_top_level(self, s: str, char: str) -> int:
        depth = 0
        last_idx = -1
        for i, c in enumerate(s):
            if c in "({": depth += 1
            elif c in ")}": depth -= 1
            elif c == char and depth == 0: last_idx = i
        return last_idx

    def parse_operand(self, s: str) -> Operand:
        s = s.strip()
        idx = self.find_last_top_level(s, ":")
        if idx != -1:
            # Only strip if what follows is likely a type (starts with Uppercase)
            # Or if it's the last part of a constant like 0x0:w32: Word32
            after = s[idx+1:].strip()
            if after and (after[0].isupper() or after == "unknown"):
                s = s[:idx].strip()
        if s == "<GCState>": return GCStateOperand()
        if s.startswith("Cast"):
            m = re.match(r"Cast\s*\((.*),\s*(.*)\)", s, re.DOTALL)
            if m: return Cast(self.parse_operand(m.group(1)), Type(m.group(2).strip()))
        for pre, ty in [("OW64", "Word64"), ("OP", "Objptr")]:
            m = re.match(r"^" + pre + r"\b\s*\((.*),\s*(.*)\)$", s, re.DOTALL)
            if m: return Offset(self.parse_operand(m.group(1)), int(m.group(2).replace("~", "-")), Type(ty))
        for pre, ty in [("XW8", "Word8"), ("XW64", "Word64")]:
            m = re.match(r"^" + pre + r"\b\s*\((.*),\s*(.*),\s*(.*),\s*(.*)\)$", s, re.DOTALL)
            if m: return SequenceOffset(self.parse_operand(m.group(1)), self.parse_operand(m.group(2)), int(m.group(4).replace("~", "-")), int(m.group(3)), Type(ty))
        if s.startswith("Runtime"): return RuntimeOperand(GCField(s[7:].strip()))
        if "0x" in s or s.lstrip("-~").isdigit() or s.startswith("\"") or s in ["NULL", "true", "false"]: return ConstOperand(Const(s))
        return VarOperand(Var(s), Type("unknown"))

def parse_rssa(text: str) -> Program:
    return RSSAParser(text).parse_program()
