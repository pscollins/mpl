(* Copyright (C) 2009,2017,2019-2020 Matthew Fluet.
 * Copyright (C) 2004-2008 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

(*
 * DeepFlatten implements a compiler pass that recursively flattens nested
 * immutable objects (tuples and records) into their parent objects.
 *
 * For example, if we have a tuple (int, (real, bool)), deep flattening
 * might transform it into a single flat object (int, real, bool).
 * This reduces heap allocations and indirection.
 *
 * The pass consists of two main phases:
 * 1. Analysis: A dataflow-style analysis that determines which objects
 *    can be safely and profitably flattened. It uses a unification-based
 *    approach to ensure consistency across the program.
 * 2. Transformation: Rewrites the SSA2 program to use the flattened
 *    representations, updating Select, Update, Object, and Sequence
 *    expressions.
 *)

functor DeepFlatten (S: SSA2_TRANSFORM_STRUCTS): SSA2_TRANSFORM =
struct

open S

datatype z = datatype Exp.t
datatype z = datatype Statement.t
datatype z = datatype Transfer.t

structure Tree = Tree (structure Seq = Prod)

(* TypeTree represents the flattened structure of a type.
 * A TypeTree is either 'Flat' (meaning its components are pulled up into
 * the parent) or 'NotFlat' (meaning it remains a distinct object).
 *)
structure TypeTree =
   struct
      datatype t = datatype Tree.t

      datatype info =
         Flat
       | NotFlat of {ty: Type.t,
                     var: Var.t option}

      type t = info Tree.t

      fun layout (t: t): Layout.t =
         Tree.layout
         (t,
          let
             open Layout
          in
             fn Flat => str "Flat"
              | NotFlat {ty, var} =>
                   seq [str "NotFlat ",
                        record [("ty", Type.layout ty),
                                ("var", Option.layout Var.layout var)]]
          end)

      val isFlat: t -> bool =
         fn T (i, _) =>
         case i of
            Flat => true
          | NotFlat _ => false
   end

(* VarTree maps a variable to a tree of variables that represent its
 * flattened components.
 *)
structure VarTree =
   struct
      open TypeTree

      val labelRoot: t * Var.t -> t =
         fn (t as T (info, ts), x) =>
         case info of
            Flat => t
          | NotFlat {ty, ...} => T (NotFlat {ty = ty, var = SOME x}, ts)

      val fromTypeTree: TypeTree.t -> t = fn t => t

      (* Collects all variables that serve as "roots" (unflattened parts)
       * in this VarTree.
       *)
      val foldRoots: t * 'a * (Var.t * 'a -> 'a) -> 'a =
         fn (t, a, f) =>
         let
            fun loop (T (info, children), a: 'a): 'a =
               case info of
                  Flat => Prod.fold (children, a, loop)
                | NotFlat {var, ...} =>
                     case var of
                        NONE => Error.bug "DeepFlatten.VarTree.foldRoots"
                      | SOME x => f (x, a)
         in
            loop (t, a)
         end

      fun foreachRoot (t, f) = foldRoots (t, (), f o #1)

      val rootsOnto: t * Var.t list -> Var.t list =
         fn (t, ac) =>
         List.appendRev (foldRoots (t, [], op ::), ac)

      val rec dropVars: t -> t =
         fn T (info, ts) =>
         let
            val info =
               case info of
                  Flat => Flat
                | NotFlat {ty, ...} => NotFlat {ty = ty, var = NONE}
         in
            T (info, Prod.map (ts, dropVars))
         end

      (* Generates Select statements to fill in the variable roots of a VarTree
       * from a base object and offset.
       *
       * This is used when a variable is projected from a flattened field
       * but its own components are not (yet) available as variables.
       *)
      fun fillInRoots (t: t, {base: Var.t Base.t, offset: int, readBarrier})
         : t * Statement.t list =
         let
            fun loop (t as T (info, ts), offset, ac) =
               case info of
                  Flat =>
                     (* Recurse into children of a flattened object.
                      * The offset remains the same because the children
                      * are mapped directly onto the parent's layout.
                      *)
                     let
                        val (ts, (offset, ac)) =
                           Vector.mapAndFold
                           (Prod.dest ts, (offset, ac),
                            fn ({elt = t, isMutable}, (offset, ac)) =>
                            let
                               val (t, offset, ac) = loop (t, offset, ac)
                            in
                               ({elt = t, isMutable = isMutable},
                                (offset, ac))
                            end)
                     in
                        (T (Flat, Prod.make ts), offset, ac)
                     end
                | NotFlat {ty, var} =>
                     (* Found a root (an unflattened object or primitive).
                      * If it doesn't have a variable name yet, create one
                      * and generate the Select statement.
                      *)
                     let
                        val (t, ac) =
                           case var of
                              NONE =>
                                 let
                                    val var = Var.newNoname ()
                                 in
                                    (T (NotFlat {ty = ty, var = SOME var}, ts),
                                     Bind
                                     {exp = Select {base = base,
                                                    offset = offset,
                                                    readBarrier = readBarrier},
                                      ty = ty,
                                      var = SOME var} :: ac)
                                 end
                            | SOME _ => (t, ac)
                     in
                        (* Move to the next field in the physical layout. *)
                        (t, offset + 1, ac)
                     end
            val (t, _, ac) = loop (t, offset, [])
         in
            (t, List.rev ac)
         end

      val fillInRoots =
         Trace.trace2 ("DeepFlatten.VarTree.fillInRoots",
                       layout,
                       fn {base, offset, readBarrier} =>
                       Layout.record [("base", Base.layout (base, Var.layout)),
                                      ("offset", Int.layout offset),
                                      ("readBarrier", Bool.layout readBarrier)],
                       Layout.tuple2 (layout, List.layout Statement.layout))
         fillInRoots
   end

(* flatten and flattensAt handle the recursive logic of mapping a VarTree
 * from one layout (represented by VarTree.t) to another (represented by TypeTree.t).
 * This is used when values are passed between variables with different
 * flattening decisions (e.g., at function calls or assignments).
 *)
fun flatten {base: Var.t Base.t option,
             from: VarTree.t,
             offset: int,
             to: TypeTree.t}: {offset: int} * VarTree.t * Statement.t list =
   let
      val Tree.T (from, fs) = from
   in
      case from of
         VarTree.Flat =>
            (* Source is already flat. If the target is also flat,
             * we recursively map the components.
             *)
            if TypeTree.isFlat to
               then flattensAt {base = base,
                                froms = fs,
                                offset = offset,
                                tos = Tree.children to}
            else Error.bug "DeepFlatten.flatten: cannot flatten from Flat to NotFlat"
       | VarTree.NotFlat {ty, var} =>
            (* Source is not flat (it's a single object variable).
             * We might need to project it from a base (if it doesn't have a name),
             * or if the target is flat, we decompose this object.
             *)
            let
               val (var, ss) =
                  case var of
                     NONE =>
                        let
                           val base =
                              case base of
                                 NONE => Error.bug "DeepFlatten.flatten: flatten missing base"
                               | SOME base => base
                           val result = Var.newNoname ()
                        in
                           (result,
                            [Bind {exp = Select {base = base,
                                                 offset = offset,
                                                 readBarrier = false},
                                   ty = ty,
                                   var = SOME result}])
                        end
                   | SOME var => (var, [])
               val (r, ss) =
                  if TypeTree.isFlat to
                     then
                        (* Target is flat, so decompose this object variable
                         * by selecting its fields.
                         *)
                        let
                           val (_, r, ss') =
                              flattensAt {base = SOME (Base.Object var),
                                          froms = fs,
                                          offset = 0,
                                          tos = Tree.children to}
                        in
                           (r, ss @ ss')
                        end
                  else (Tree.T (VarTree.NotFlat {ty = ty, var = SOME var},
                                fs),
                        ss)
            in
               (* Increment offset by 1 because this was one object/primitive
                * in the physical layout of the parent.
                *)
               ({offset = 1 + offset}, r, ss)
            end
   end
and flattensAt {base: Var.t Base.t option,
                froms: VarTree.t Prod.t,
                offset: int,
                tos: TypeTree.t Prod.t} =
   let
      val (ts, (off, ss)) =
         Vector.map2AndFold
         (Prod.dest froms, Prod.dest tos, ({offset = offset}, []),
          fn ({elt = f, isMutable}, {elt = t, ...}, ({offset}, ss)) =>
          let
             val () =
                if isMutable
                   then Error.bug "DeepFlatten.flattensAt: mutable"
                else ()
             val ({offset}, t, ss') =
                flatten {base = base,
                         from = f,
                         offset = offset,
                         to = t}
          in
             ({elt = t, isMutable = false},
              ({offset = offset}, ss' @ ss))
          end)
   in
      (off, Tree.T (VarTree.Flat, Prod.make ts), ss)
   end

fun coerceTree {from: VarTree.t, to: TypeTree.t}: VarTree.t * Statement.t list =
   let
      val (_, r, ss) =
         flatten {base = NONE,
                  from = from,
                  offset = 0,
                  to = to}
   in
      (r, ss)
   end

val coerceTree =
   let
      open Layout
   in
      Trace.trace ("DeepFlatten.coerceTree",
                   fn {from, to} =>
                   record [("from", VarTree.layout from),
                           ("to", TypeTree.layout to)],
                   fn (vt, ss) =>
                   tuple [VarTree.layout vt,
                          List.layout Statement.layout ss])
      coerceTree
   end

structure Flat =
   struct
      datatype t = Flat | NotFlat

      val toString: t -> string =
         fn Flat => "Flat"
          | NotFlat => "NotFlat"

      val layout = Layout.str o toString
   end

datatype z = datatype Flat.t

(* Value represents the analysis domain.
 * Ground: A primitive or unflattened type.
 * Object: A potentially flattened object.
 * Weak: A weak pointer.
 *)
structure Value =
   struct
      datatype t =
         Ground of Type.t
       | Object of object Equatable.t
       | Weak of {arg: t}
      withtype object = {args: t Prod.t,
                         coercedFrom: t AppendList.t ref,
                         con: ObjectCon.t,
                         finalOffsets: int vector option ref,
                         finalTree: TypeTree.t option ref,
                         finalType: Type.t option ref,
                         finalTypes: Type.t Prod.t option ref,
                         flat: Flat.t ref}

      fun layout (v: t): Layout.t =
         let
            open Layout
         in
            case v of
               Ground t => Type.layout t
             | Object e =>
                  Equatable.layout
                  (e, fn {args, con, flat, ...} =>
                   seq [str "Object ",
                        record [("args", Prod.layout (args, layout)),
                                ("con", ObjectCon.layout con),
                                ("flat", Flat.layout (! flat))]])
             | Weak {arg, ...} => seq [str "Weak ", layout arg]
         end

      val ground = Ground

      val traceCoerce =
         Trace.trace ("DeepFlatten.Value.coerce",
                      fn {from, to} =>
                      Layout.record [("from", layout from),
                                     ("to", layout to)],
                      Unit.layout)

      val traceUnify =
         Trace.trace2 ("DeepFlatten.Value.unify", layout, layout, Unit.layout)

      (* Unify two values, ensuring they have the same flattening decision.
       * If one must be NotFlat, then the other (and all equated objects)
       * must also be NotFlat.
       *)
      val rec unify: t * t -> unit =
         fn arg =>
         traceUnify
         (fn (v, v') =>
          case (v, v') of
             (Ground _, Ground _) => ()
           | (Object e, Object e') =>
                let
                   val callDont = ref false
                   val () =
                      Equatable.equate
                      (e, e',
                       fn (z as {args = a, coercedFrom = c, flat = f, ...},
                           z' as {args = a', coercedFrom = c', flat = f', ...}) =>
                       let
                          (* Recursively unify children. *)
                          val () = unifyProd (a, a')
                       in
                          (* If either side was previously marked Flat but
                           * the other is NotFlat, we must trigger 'dontFlatten'
                           * to propagate the NotFlat decision.
                           *)
                          case (!f, !f') of
                             (Flat, Flat) =>
                                (c := AppendList.append (!c', !c); z)
                           | (Flat, NotFlat) =>
                                (callDont := true; z)
                           | (NotFlat, Flat) =>
                                (callDont := true; z')
                           | (NotFlat, NotFlat) => z
                       end)
                in
                   if !callDont
                      then dontFlatten v
                   else ()
                end
           | (Weak {arg = a, ...}, Weak {arg = a', ...}) =>
                unify (a, a')
           | _ => Error.bug "DeepFlatten.unify: strange") arg
      and unifyProd =
         fn (p, p') =>
         Vector.foreach2
         (Prod.dest p, Prod.dest p',
          fn ({elt = e, ...}, {elt = e', ...}) => unify (e, e'))
      
      (* Explicitly mark a value as NotFlat and propagate this decision. *)
      and dontFlatten: t -> unit =
         fn v =>
         case v of
            Object e =>
               let
                  val {coercedFrom, flat, ...} = Equatable.value e
               in
                  case ! flat of
                     Flat =>
                        let
                           val () = flat := NotFlat
                           val from = !coercedFrom
                           val () = coercedFrom := AppendList.empty
                        in
                           AppendList.foreach (from, fn v' => unify (v, v'))
                        end
                   | NotFlat => ()
               end
          | _ => ()

      (* Coerce one value to another. If the target is Flat, then the source
       * must be compatible with being flattened.
       *
       * Coercion is weaker than unification: if 'to' is NotFlat, 'from'
       * can still be Flat. But if 'to' is Flat, 'from' MUST also be Flat.
       *)
      val rec coerce =
         fn arg as {from, to} =>
         traceCoerce
         (fn _ =>
          case (from, to) of
             (Ground _, Ground _) => ()
           | (Object e, Object e') =>
                if Equatable.equals (e, e')
                   then ()
                else
                   Equatable.whenComputed
                   (e', fn {args = a', coercedFrom = c', flat = f', ...} =>
                    let
                       val {args = a, con, ...} = Equatable.value e
                    in
                       (* Sequences and mutable objects cannot be flattened. *)
                       if Prod.someIsMutable a orelse ObjectCon.isSequence con
                          then unify (from, to)
                       else
                          case !f' of
                             Flat => 
                                (* Target is flat, so source must be too.
                                 * We record the relationship in coercedFrom
                                 * so that if source later becomes NotFlat,
                                 * target can also be marked NotFlat.
                                 *)
                                (AppendList.push (c', from)
                                 ; coerceProd {from = a, to = a'})
                           | NotFlat => 
                                (* Target is not flat, so source doesn't have
                                 * to be. Just unify to be safe.
                                 *)
                                unify (from, to)
                    end)
           | (Weak _, Weak _) => unify (from, to)
           | _ => Error.bug "DeepFlatten.coerce: strange") arg
      and coerceProd =
         fn {from = p, to = p'} =>
         Vector.foreach2
         (Prod.dest p, Prod.dest p', fn ({elt = e, ...}, {elt = e', ...}) =>
          coerce {from = e, to = e'})

      (* Heuristics for deciding whether an object can be flattened. *)
      fun mayFlatten {args, con}: bool = let
         (* Don't flatten constructors, since they are part of a sum type.
          * Don't flatten unit (empty args).
          * Don't flatten sequences (handled elsewhere).
          * Don't flatten objects with mutable fields, since identity/sharing
          * must be preserved.
          *)
         val notEmpty = not (Prod.isEmpty args)
         val isImmut = Prod.allAreImmutable args
         val badCon = 
             (case con of
                  ObjectCon.Con _ => false
                | ObjectCon.Sequence => false
                | ObjectCon.Tuple => true)
         val _ = print (String.concat ["mayFlatten: notEmpty=",
                                       Bool.toString notEmpty,
                                       " isImmut=",
                                       Bool.toString isImmut,
                                       " badCon=",
                                       Bool.toString badCon, "\n"])
      in
         notEmpty andalso isImmut andalso badCon
      end

      fun objectFields {args, con} =
         let
            (* Don't flatten object components that are immutable fields.  Those
             * have already had a chance to be flattened by other passes.
             *)
            val _  =
               if (case con  of
                       ObjectCon.Con _ => (print "NO: CON!\n"; true)
                     | ObjectCon.Tuple => (print "YES: TUPLE!\n"; true)
                     | ObjectCon.Sequence => (print "NO: SEQ!\n"; false))
                  then Vector.foreach (Prod.dest args, fn {elt, isMutable} =>
                                       if isMutable
                                          then ()
                                       else dontFlatten elt)
               else ()
            val flat =
               if mayFlatten {args = args, con = con}
               then (print "MayFlatten: YES!\n"; Flat.Flat)
               else (print "MayFlatten: NO!\n"; Flat.NotFlat)
         in
            {args = args,
             coercedFrom = ref AppendList.empty,
             con = con,
             finalOffsets = ref NONE,
             finalTree = ref NONE,
             finalType = ref NONE,
             finalTypes = ref NONE,
             flat = ref flat}
         end

      fun object f =
         Object (Equatable.delay (fn () => objectFields (f ())))

      val tuple: t Prod.t -> t =
         fn vs =>
         Object (Equatable.new (objectFields {args = vs, con = ObjectCon.Tuple}))

      val tuple =
         Trace.trace ("DeepFlatten.Value.tuple",
                      fn p => Prod.layout (p, layout),
                      layout)
         tuple

      fun weak (arg: t) = Weak {arg = arg}

      val deObject: t -> object option =
         fn v =>
         case v of
            Object e => SOME (Equatable.value e)
          | _ => NONE

      fun origType (v: t): Type.t =
         case v of
            Ground ty => ty
          | Weak {arg} => Type.weak (origType arg)
          | Object e =>
               let
                  val {args, con, ...} = Equatable.value e
               in
                  Type.object {args = Prod.map (args, origType),
                               con = con}
               end

      val traceFinalType =
         Trace.trace ("DeepFlatten.Value.finalType", layout, Type.layout)
      val traceFinalTypes =
         Trace.trace ("DeepFlatten.Value.finalTypes",
                      layout,
                      fn p => Prod.layout (p, Type.layout))

      (* Computes the final TypeTree after all unification and coercion. *)
      fun finalTree (v: t): TypeTree.t =
         let
            fun notFlat (): TypeTree.info =
               TypeTree.NotFlat {ty = finalType v, var = NONE}
         in
            case deObject v of
               NONE => Tree.T (notFlat (), Prod.empty ())
             | SOME {args, finalTree = r, flat, ...} =>
                  Ref.memoize
                  (r, fn () =>
                   let
                      val info =
                         case !flat of
                            Flat => TypeTree.Flat
                          | NotFlat => notFlat ()
                   in
                      Tree.T (info, Prod.map (args, finalTree))
                   end)
         end
      
      (* Computes the final Type.t of a value. If flattened, this will be
       * the consolidated type.
       *)
      and finalType arg: Type.t =
         traceFinalType
         (fn v =>
          case v of
             Ground t => t
           | Object e =>
                let
                   val {finalType = r, ...} = Equatable.value e
                in
                   Ref.memoize (r, fn () => Prod.elt (finalTypes v, 0))
                end
           | Weak {arg, ...} => Type.weak (finalType arg)) arg
      
      (* Computes the product of types for a potentially flattened object. *)
      and finalTypes arg: Type.t Prod.t =
         traceFinalTypes
         (fn v =>
          case deObject v of
             NONE =>
                Prod.make (Vector.new1 {elt = finalType v,
                                        isMutable = false})
           | SOME {args, con, finalTypes, flat, ...} =>
                Ref.memoize
                (finalTypes, fn () =>
                 let
                    val args = prodFinalTypes args
                 in
                    case !flat of
                       Flat => args
                     | NotFlat =>
                          Prod.make
                          (Vector.new1
                           {elt = Type.object {args = args, con = con},
                            isMutable = false})
                 end)) arg
      and prodFinalTypes (p: t Prod.t): Type.t Prod.t =
         Prod.make
         (Vector.fromList
          (Vector.foldr
           (Prod.dest p, [], fn ({elt, isMutable = i}, ac) =>
            Vector.foldr
            (Prod.dest (finalTypes elt), ac, fn ({elt, isMutable = i'}, ac) =>
             {elt = elt, isMutable = i orelse i'} :: ac))))
   end

structure Object =
   struct
      type t = Value.object

      fun select ({args, ...}: t, offset): Value.t =
         Prod.elt (args, offset)

      (* Computes the final offsets of fields in a flattened object. *)
      fun finalOffsets ({args, finalOffsets = r, ...}: t): int vector =
         Ref.memoize
         (r, fn () =>
          Vector.fromListRev
          (#2 (Prod.fold
               (args, (0, []), fn (elt, (offset, offsets)) =>
                (offset + Prod.length (Value.finalTypes elt),
                 offset :: offsets)))))

      fun finalOffset (object, offset) =
         Vector.sub (finalOffsets object, offset)
   end

(* The main entry point for the transformation. *)
fun transform2 (program as Program.T {datatypes, functions, globals, main}) =
   let
      (* Analysis phase: use the standard SSA analysis framework to propagate
       * flattening decisions through the program.
       *)
      val _ = print "========= BEGIN DEEP FLATTEN\n"
      val {get = conValue: Con.t -> Value.t option ref, ...} =
         Property.get (Con.plist, Property.initFun (fn _ => ref NONE))
      val conValue =
         Trace.trace ("DeepFlatten.conValue",
                      Con.layout, Ref.layout (Option.layout Value.layout))
         conValue
      datatype 'a make =
         Const of 'a
       | Make of unit -> 'a
      val traceMakeTypeValue =
         Trace.trace ("DeepFlatten.makeTypeValue",
                      Type.layout o #1,
                      Layout.ignore)
      fun makeValue m =
         case m of
            Const v => v
          | Make f => f ()
      fun needToMakeProd p =
         Vector.exists (Prod.dest p, fn {elt, ...} =>
                        case elt of
                           Const _ => false
                         | Make _ => true)
      fun makeProd p = Prod.map (p, makeValue)
      val {get = makeTypeValue: Type.t -> Value.t make, ...} =
         Property.get
         (Type.plist,
          Property.initRec
          (traceMakeTypeValue
           (fn (t, makeTypeValue) =>
            let
               fun const () = Const (Value.ground t)
               datatype z = datatype Type.dest
            in
               case Type.dest t of
                  Object {args, con} =>
                     let
                        val args = Prod.map (args, makeTypeValue)
                        fun doit () =
                           if needToMakeProd args
                              orelse Value.mayFlatten {args = args, con = con}
                              then
                                 Make
                                 (fn () =>
                                  Value.object (fn () => {args = makeProd args,
                                                          con = con}))
                           else const ()
                        datatype z = datatype ObjectCon.t
                     in
                        case con of
                           Con c =>
                              Const (Ref.memoize
                                     (conValue c, fn () =>
                                      makeValue (doit ())))
                         | Tuple => doit ()
                         | Sequence => doit ()
                     end
                | Weak t =>
                     (case makeTypeValue t of
                         Const _ => const ()
                       | Make f => Make (fn () => Value.weak (f ())))
                | _ => const ()
            end)))
      fun typeValue (t: Type.t): Value.t =
         makeValue (makeTypeValue t)
      val typeValue =
         Trace.trace ("DeepFlatten.typeValue", Type.layout, Value.layout)
         typeValue
      val (coerce, coerceProd) = (Value.coerce, Value.coerceProd)
      fun base b =
         case b of
            Base.Object obj => obj
          | Base.SequenceSub {sequence, ...} => sequence
      fun const c = typeValue (Type.ofConst c)
      fun select {base, offset} =
         let
            datatype z = datatype Value.t
         in
            case base of
               Ground t =>
                  (case Type.dest t of
                      Type.Object {args, ...} =>
                         typeValue (Prod.elt (args, offset))
                    | _ => Error.bug "DeepFlatten.select: Ground")
             | Object e => Object.select (Equatable.value e, offset)
             | _ => Error.bug "DeepFlatten.select:"
         end
      fun update {base, offset, value, writeBarrier} =
         coerce {from = value,
                 to = select {base = base, offset = offset}}
      fun inject {sum, variant = _} = typeValue (Type.datatypee sum)
      fun object {args, con, resultType} =
         let
            val m = makeTypeValue resultType
         in
            case con of
               NONE =>
                  (case m of
                      Const v => v
                    | Make _ => Value.tuple args)
             | SOME _ =>
                  (case m of
                      Const v =>
                         let
                            val () =
                               case Value.deObject v of
                                  NONE => ()
                                | SOME {args = args', ...} =>
                                     coerceProd {from = args, to = args'}
                         in
                            v
                         end
                    | _ => Error.bug "DeepFlatten.object: strange con value")
         end
      val object =
         Trace.trace
         ("DeepFlatten.object",
          fn {args, con, ...} =>
          Layout.record [("args", Prod.layout (args, Value.layout)),
                         ("con", Option.layout Con.layout con)],
          Value.layout)
         object
      val deWeak : Value.t -> Value.t =
         fn v =>
         case v of
            Value.Ground t =>
               typeValue (case Type.dest t of
                             Type.Weak t => t
                           | _ => Error.bug "DeepFlatten.primApp: deWeak")
          | Value.Weak {arg, ...} => arg
          | _ => Error.bug "DeepFlatten.primApp: Value.deWeak"

      val {get = sporkDataValue: Type.t -> Value.t, ...} =
         Property.get (Type.plist, Property.initFun typeValue)
      
      (* Primitives have specific rules for whether they allow flattening
       * of their arguments.
       *)
      fun primApp {args, prim, resultVar = _, resultType} =
         let
            fun weak v =
               case makeTypeValue resultType of
                  Const v => v
                | Make _ => Value.weak v
            fun arg i = Vector.sub (args, i)
            fun result () = typeValue resultType
            fun dontFlatten () =
               (Vector.foreach (args, Value.dontFlatten)
                ; result ())
            fun equal () =
               (Value.unify (arg 0, arg 1)
                ; Value.dontFlatten (arg 0)
                ; result ())
         in
            case prim of
               Prim.Array_cas _ =>
                 let
                    val c = select {base = arg 0, offset = 0}
                 in
                    Value.dontFlatten c
                    ; Value.unify (arg 2, c)
                    ; Value.unify (arg 3, c)
                    ; c
                 end
             | Prim.Array_toArray =>
                  let
                     val res = result ()
                     val () =
                        case (Value.deObject (arg 0), Value.deObject res) of
                           (NONE, NONE) => ()
                         | (SOME {args = a, ...}, SOME {args = a', ...}) =>
                              Vector.foreach2
                              (Prod.dest a, Prod.dest a',
                               fn ({elt = v, ...}, {elt = v', ...}) =>
                               Value.unify (v, v'))
                         | _ => Error.bug "DeepFlatten.primApp: Array_toArray"
                  in
                     res
                  end
             | Prim.Array_toVector =>
                  let
                     val res = result ()
                     val () =
                        case (Value.deObject (arg 0), Value.deObject res) of
                           (NONE, NONE) => ()
                         | (SOME {args = a, ...}, SOME {args = a', ...}) =>
                              Vector.foreach2
                              (Prod.dest a, Prod.dest a',
                               fn ({elt = v, ...}, {elt = v', ...}) =>
                               Value.unify (v, v'))
                         | _ => Error.bug "DeepFlatten.primApp: Array_toVector"
                  in
                     res
                  end
             | Prim.CFunction _ =>
                  (* Some imports, like Real64.modf, take ref cells that can not
                   * be flattened.
                   *)
                  dontFlatten ()
             | Prim.MLton_eq => equal ()
             | Prim.MLton_equal => equal ()
             | Prim.MLton_size => dontFlatten ()
             | Prim.MLton_share => dontFlatten ()
             | Prim.Spork_forkThreadAndSetData _ =>
                  let
                     val x = Vector.sub (args, 1)
                     val _ = Value.dontFlatten x
                  in
                     (* Value.coerce {from = x, to = sporkDataValue (Value.origType x)} *)
                     Value.unify (x, sporkDataValue (Value.origType x))
                     ; dontFlatten ()
                  end
             | Prim.Spork_getData _ => sporkDataValue resultType
             | Prim.Ref_cas _ =>
                 let
                    val c = select {base = arg 0, offset = 0}
                 in
                    Value.dontFlatten c
                    ; Value.unify (arg 1, c)
                    ; Value.unify (arg 2, c)
                    ; c
                 end
             | Prim.Weak_get => deWeak (arg 0)
             | Prim.Weak_new =>
                  let val a = arg 0
                  in (Value.dontFlatten a; weak a)
                  end
             | Prim.Trace_sourceMarkValue =>  dontFlatten()
             | Prim.Trace_staticSourceMarkValue _ =>  dontFlatten()
             | _ => dontFlatten ()
         end
      fun base b =
         case b of
            Base.Object obj => obj
          | Base.SequenceSub {sequence, ...} => sequence
      fun select {base, offset} =
         let
            datatype z = datatype Value.t
         in
            case base of
               Ground t =>
                  (case Type.dest t of
                      Type.Object {args, ...} =>
                         typeValue (Prod.elt (args, offset))
                    | _ => Error.bug "DeepFlatten.select: Ground")
             | Object e => Object.select (Equatable.value e, offset)
             | _ => Error.bug "DeepFlatten.select:"
         end
      fun update {base, offset, value, writeBarrier = _} =
         coerce {from = value,
                 to = select {base = base, offset = offset}}
      fun const c = typeValue (Type.ofConst c)
      fun sequence {args, resultType} =
         let
            val v = typeValue resultType
            val _ =
               Vector.foreach
               (args, fn args =>
                Vector.foreachi
                (Prod.dest args, fn (offset, {elt, ...}) =>
                 update {base = v,
                         offset = offset,
                         value = elt,
                         writeBarrier = false}))
         in
            v
         end
      
      (* Perform the whole-program analysis. *)
      val {func, value= varValue: Var.t -> Value.t, ...} =
      (* val {get = varValue: Var.t -> Value.t, func, ...} = *)
         analyze {base = base,
                  coerce = coerce,
                  const = const,
                  filter = fn _ => (),
                  filterWord = fn _ => (),
                  fromType = typeValue,
                  inject = inject,
                  layout = Value.layout,
                  object = object,
                  primApp = primApp,
                  program = program,
                  select = fn {base, offset, ...} => select {base = base,
                                                             offset = offset},
                  sequence = sequence,
                  update = update,
                  useFromTypeOnBinds = false}
      
      (* Don't flatten outermost part of formal parameters, as they must match
       * the expected calling convention.
       *)
      fun dontFlattenFormals (xts: (Var.t * Type.t) vector): unit =
         Vector.foreach (xts, fn (x, _) => Value.dontFlatten (varValue x))
      val () =
         List.foreach
         (functions, fn f =>
          let
             val {args, blocks, ...} = Function.dest f
             val () = dontFlattenFormals args
             val () = Vector.foreach (blocks, fn Block.T {args, ...} =>
                                      dontFlattenFormals args)
          in
             ()
          end)
      val () =
         Control.diagnostics
         (fn display =>
          let
             open Layout
             val () =
                Vector.foreach
                (datatypes, fn Datatype.T {cons, ...} =>
                 Vector.foreach
                 (cons, fn {con, ...} =>
                  display (Option.layout Value.layout (! (conValue con)))))
             val () =
                Program.foreachVar
                (program, fn (x, _) =>
                 display
                 (seq [Var.layout x, str " ", Value.layout (varValue x)]))
          in
             ()
          end)
      
      (* Transformation phase: rewrite the program based on analysis results. *)
      val datatypes =
         Vector.map
         (datatypes, fn Datatype.T {cons, tycon} =>
          let
             val cons =
                Vector.map
                (cons, fn {con, args} =>
                 let
                    val args =
                       case ! (conValue con) of
                          NONE => args
                        | SOME v =>
                             case Type.dest (Value.finalType v) of
                                Type.Object {args, ...} => args
                              | _ => Error.bug "DeepFlatten.datatypes: strange con"
                 in
                    {args = args, con = con}
                 end)
          in
             Datatype.T {cons = cons, tycon = tycon}
          end)
      val valueType = Value.finalType
      fun valuesTypes vs = Vector.map (vs, Value.finalType)
      val {get = varTree: Var.t -> VarTree.t, set = setVarTree, ...} =
         Property.getSetOnce (Var.plist,
                              Property.initRaise ("tree", Var.layout))
      val setVarTree =
         Trace.trace2 ("DeepFlatten.setVarTree",
                       Var.layout, VarTree.layout, Unit.layout)
         setVarTree
      fun simpleVarTree (x: Var.t): unit =
         (print (concat ["simpleVarTree: ", Var.toString x, "\n"])
          ; setVarTree
            (x, VarTree.labelRoot (VarTree.fromTypeTree
                                   (Value.finalTree (varValue x)),
                                   x)))
      fun transformFormals xts =
         Vector.map (xts, fn (x, _) =>
                     let
                        val () = simpleVarTree x
                     in
                        (x, Value.finalType (varValue x))
                     end)
      fun replaceVar (x: Var.t): Var.t =
         let
            fun bug () = Error.bug (concat ["DeepFlatten.replaceVar ", Var.toString x])
            val Tree.T (info, _) = varTree x
         in
            case info of
               VarTree.Flat => bug ()
             | VarTree.NotFlat {var, ...} =>
                  case var of
                     NONE => bug ()
                   | SOME y => y
         end
      
      (* Transforms a Bind expression. If the result is flattened, it might
       * generate multiple statements or none (if the components are handled).
       *)
      fun transformBind {exp, ty, var}: Statement.t list =
         let
            fun simpleTree () = Option.app (var, simpleVarTree)
            fun doit (e: Exp.t) =
               let
                  val ty =
                     case var of
                        NONE => ty
                      | SOME var => valueType (varValue var)
               in
                  [Bind {exp = e, ty = ty, var = var}]
               end
            fun simple () =
               (simpleTree ()
                ; doit (Exp.replaceVar (exp, replaceVar)))
            fun none () = []
         in
            case exp of
               Exp.Const _ => simple ()
             | Inject _ => simple ()
             | Object {args, con} =>
                  (case var of
                      NONE => none ()
                    | SOME var =>
                         let
                            val v = varValue var
                         in
                            case Value.deObject v of
                               NONE => simple ()
                             | SOME {args = expects, flat, ...} =>
                                  let
                                     (* Recursively transform components. *)
                                     val z =
                                        Vector.map2
                                        (args, Prod.dest expects,
                                         fn (arg, {elt, isMutable}) =>
                                         let
                                            val (vt, ss) =
                                               coerceTree
                                               {from = varTree arg,
                                                to = Value.finalTree elt}
                                         in
                                            ({elt = vt,
                                              isMutable = isMutable},
                                             ss)
                                         end)
                                     val vts = Vector.map (z, #1)
                                     fun set info =
                                        setVarTree (var,
                                                    Tree.T (info,
                                                            Prod.make vts))
                                  in
                                     case !flat of
                                        Flat => 
                                           (* If target object is Flat, we don't
                                            * generate an Object expression.
                                            * We just update the VarTree mapping.
                                            *)
                                           (set VarTree.Flat; none ())
                                      | NotFlat =>
                                           (* Target is NotFlat, so generate
                                            * a physical Object expression
                                            * with (potentially) flattened fields.
                                            *)
                                           let
                                              val ty = Value.finalType v
                                              val () =
                                                 set (VarTree.NotFlat
                                                      {ty = ty,
                                                       var = SOME var})
                                              val args =
                                                 Vector.fromList
                                                 (Vector.foldr
                                                  (vts, [],
                                                   fn ({elt = vt, ...}, ac) =>
                                                   VarTree.rootsOnto (vt, ac)))
                                              val obj =
                                                 Bind
                                                 {exp = Object {args = args,
                                                                con = con},
                                                  ty = ty,
                                                  var = SOME var}
                                           in
                                              Vector.foldr
                                              (z, [obj],
                                               fn ((_, ss), ac) => ss @ ac)
                                           end
                                  end
                         end)
             | PrimApp _ => simple ()
             | Select {base, offset, readBarrier} =>
                  (case var of
                      NONE => none ()
                    | SOME var =>
                         let
                            val baseVar = Base.object base
                         in
                            case Value.deObject (varValue baseVar) of
                               NONE => simple ()
                             | SOME obj =>
                                  let
                                     val Tree.T (info, children) =
                                        varTree baseVar
                                     val {elt = child, isMutable} =
                                        Prod.sub (children, offset)
                                     val (child, ss) =
                                        case info of
                                           VarTree.Flat => (child, [])
                                         | VarTree.NotFlat _ =>
                                              let
                                                 val child =
                                                    (* Don't simplify a select out
                                                     * of a mutable field.
                                                     * Something may have mutated
                                                     * it.
                                                     *)
                                                    if isMutable
                                                       then VarTree.dropVars child
                                                    else child
                                              in
                                                 VarTree.fillInRoots
                                                 (child,
                                                  {base = Base.map (base, replaceVar),
                                                   offset = (Object.finalOffset
                                                             (obj, offset)),
                                                   readBarrier = readBarrier})
                                              end
                                     val () = setVarTree (var, child)
                                  in
                                     ss
                                  end
                         end)
             | Sequence {args} =>
                  (case var of
                      NONE => none ()
                    | SOME var =>
                         let
                            val v = varValue var
                         in
                            case Value.deObject v of
                               NONE => simple ()
                             | SOME {args = expects, flat, ...} =>
                                  let
                                     val z =
                                        Vector.map
                                        (args, fn args =>
                                         Vector.map2
                                         (args, Prod.dest expects,
                                          fn (arg, {elt, ...}) =>
                                          let
                                             val (vt, ss) =
                                                coerceTree
                                                {from = varTree arg,
                                                 to = Value.finalTree elt}
                                          in
                                             (vt, ss)
                                          end))
                                     val () = simpleVarTree var
                                  in
                                     case !flat of
                                        Flat => Error.bug "DeepFlatten.transformBind: Sequence, Flat"
                                      | NotFlat =>
                                           let
                                              val ty = Value.finalType v
                                              val args =
                                                 Vector.map
                                                 (z, fn z =>
                                                  Vector.fromList
                                                  (Vector.foldr
                                                   (z, [], fn ((vt, _), ac) =>
                                                    VarTree.rootsOnto (vt, ac))))
                                              val obj =
                                                 Bind
                                                 {exp = Sequence {args = args},
                                                  ty = ty,
                                                  var = SOME var}
                                           in
                                              Vector.foldr
                                              (z, [obj], fn (z, ac) =>
                                               Vector.foldr
                                               (z, ac, fn ((_, ss), ac) =>
                                                ss @ ac))
                                           end
                                  end
                         end)
             | Var x =>
                  (Option.app (var, fn y => setVarTree (y, varTree x))
                   ; none ())
         end
      
      (* Transforms a statement, potentially expanding a single Update into
       * multiple updates if the object being updated is flattened.
       *)
      fun transformStatement (s: Statement.t): Statement.t list =
         (print (concat ["transformStatement: ", Layout.toString (Statement.layout s), "\n"])
          ; let
               fun simple () = [Statement.replaceUses (s, replaceVar)]
            in
               case s of
                  Bind b =>  transformBind b
                | Profile _ => simple ()
                | Update {base, offset, value, writeBarrier} =>
                     let
                        val baseVar =
                           case base of
                              Base.Object x => x
                            | Base.SequenceSub {sequence = x, ...} => x
                     in
                        case Value.deObject (varValue baseVar) of
                           NONE => simple ()
                         | SOME object =>
                              let
                                 val ss = ref []
                                 val child =
                                    Value.finalTree (Object.select (object, offset))
                                 val offset = Object.finalOffset (object, offset)
                                 val base = Base.map (base, replaceVar)
                                 val us =
                                    if not (TypeTree.isFlat child)
                                       then [Update {base = base,
                                                     offset = offset,
                                                     value = replaceVar value,
                                                     writeBarrier = writeBarrier}]
                                    else
                                       let
                                          val (vt, ss') =
                                             coerceTree {from = varTree value,
                                                         to = child}
                                          val () = ss := ss' @ (!ss)
                                          val r = ref offset
                                          val us = ref []
                                          val () =
                                             VarTree.foreachRoot
                                             (vt, fn var =>
                                              let
                                                 val offset = !r
                                                 val () = r := 1 + !r
                                              in
                                                 List.push (us,
                                                            Update {base = base,
                                                                    offset = offset,
                                                                    value = var,
                                                                    writeBarrier = writeBarrier})
                                              end)
                                       in
                                          !us
                                       end
                              in
                                 !ss @ us
                              end
                     end
             end)
      val transformStatement =
          Trace.trace ("DeepFlatten.transformStatement",
                      Statement.layout,
                      List.layout Statement.layout)
         transformStatement
      fun transformStatements ss =
         Vector.concatV
         (Vector.map (ss, Vector.fromList o transformStatement))
      fun transformTransfer t =
         (print (concat ["transFormTransfer: ", Layout.toString (Transfer.layout t), "\n"])
          ; Transfer.replaceVar (t, replaceVar))
      val transformTransfer =
          Trace.trace ("DeepFlatten.transformTransfer",
                      Transfer.layout, Transfer.layout)
         transformTransfer
      fun transformBlock (b as Block.T {args, label, statements, transfer}) =
         (print (concat ["transFormBlock: ", Layout.toString (Block.layout b), "\n"])
          ; Block.T {args = transformFormals args,
                     label = label,
                     statements = transformStatements statements,
                     transfer = transformTransfer transfer})
      fun transformFunction (f: Function.t): Function.t =
          let
             val {args, inline, name, start, ...} = Function.dest f
             val {raises, returns, ...} = func name
             val args = transformFormals args
             val raises = Option.map (raises, valuesTypes)
             val returns = Option.map (returns, valuesTypes)
             val blocks = ref []
             val () =
                Function.dfs (f, fn b =>
                              (List.push (blocks, transformBlock b)
                               ; fn () => ()))
          in
             Function.new {args = args,
                           blocks = Vector.fromList (!blocks),
                           inline = inline,
                           name = name,
                           raises = raises,
                           returns = returns,
                           start = start}
          end
      val globals = transformStatements globals
      val functions = List.revMap (functions, transformFunction)
      val program =
         Program.T {datatypes = datatypes,
                    functions = functions,
                    globals = globals,
                    main = main}
      val () = Program.clear program
      val result = shrink program
      val _ = print "========= END DEEP FLATTEN\n"
   in
      result
   end

end
