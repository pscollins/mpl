(* Copyright (C) 1999-2006 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

(*
 * Flatten arguments to jumps, constructors, and functions.
 * If a tuple is explicitly available at all uses of a jump (resp. function)
 * then
 *   - The formals and call sites are changed so that the components of the
 *     tuple are passed.
 *   - The tuple is reconstructed at the beginning of the body of the jump.
 *
 * Similarly, if a tuple is explicitly available at all uses of a constructor,
 *   - The constructor argument type is changed to flatten the tuple type.
 *   - The tuple is passed flat at each ConApp.
 *   - The tuple is reconstructed at each Case target.
 *)

functor Flatten (S: SSA_TRANSFORM_STRUCTS): SSA_TRANSFORM = 
struct

open S
open Exp Transfer

structure Rep =
   struct
      structure L = TwoPointLattice (val bottom = "flatten"
                                     val top = "don't flatten")

      open L

      val isFlat = not o isTop

      fun fromType (t, msg: unit -> Layout.t) =
         let
            val r = new ()
            val _ = addHandler (r, fn () =>
               Control.diagnostics (fn display =>
                  display (Layout.seq [Layout.str "Don't flatten ", msg (),
                                       Layout.str " because it is Top"])))
         in
            case Type.deTupleOpt t of
               NONE => (makeTop r; r)
             | SOME _ => r
         end

      fun fromTypes (ts: Type.t vector, msg: int -> Layout.t): t vector =
         Vector.mapi (ts, fn (i, t) => fromType (t, fn () => msg i))

      val tuplize: t -> unit = makeTop

      val coerce = op <=

      fun coerces (rs, rs') = Vector.foreach2 (rs, rs', coerce)

      val unify = op ==

      fun unifys (rs, rs') = Vector.foreach2 (rs, rs', unify)
   end

fun transform (Program.T {datatypes, globals, functions, main}) =
   let
      val {get = conInfo: Con.t -> {argsTypes: Type.t vector,
                                    args: Rep.t vector},
           set = setConInfo, ...} =
         Property.getSetOnce
         (Con.plist, Property.initRaise ("Flatten.conInfo", Con.layout))
      val conArgs = #args o conInfo
      val {get = funcInfo: Func.t -> {args: Rep.t vector,
                                      returns: Rep.t vector option,
                                      raises: Rep.t vector option},
           set = setFuncInfo, ...} =
         Property.getSetOnce
         (Func.plist, Property.initRaise ("Flatten.funcInfo", Func.layout))
      val funcArgs = #args o funcInfo
      val {get = labelInfo: Label.t -> {args: Rep.t vector},
           set = setLabelInfo, ...} =
         Property.getSetOnce
         (Label.plist, Property.initRaise ("Flatten.labelInfo", Label.layout))
      val labelArgs = #args o labelInfo
      val {get = varInfo: Var.t -> {rep: Rep.t, 
                                    tuple: Var.t vector option ref},
           set = setVarInfo, ...} =
         Property.getSetOnce
         (Var.plist, Property.initFun 
                     (fn x => {rep = let val r = Rep.new ()
                                         val _ =
                                            Rep.addHandler
                                            (r, fn () =>
                                             Control.diagnostics
                                             (fn display =>
                                              display
                                              (Layout.seq
                                               [Layout.str "Don't flatten ",
                                                Var.layout x,
                                                Layout.str " because it is Top (default)"])))
                                     in Rep.tuplize r; r 
                                     end,
                               tuple = ref NONE}))
      val fromFormal = fn (x, ty) => let val r = Rep.fromType (ty, fn () => Var.layout x)
                                     in
                                       setVarInfo (x, {rep = r,
                                                       tuple = ref NONE})
                                       ; r
                                     end
      val fromFormals = fn xtys => Vector.map (xtys, fromFormal)
      val varRep = #rep o varInfo
      val varTuple = #tuple o varInfo
      fun coerce (x: Var.t, r: Rep.t) =
         let
            val _ =
               Rep.addHandler (varRep x, fn () =>
                  Control.diagnostics (fn display =>
                     display (Layout.seq [Layout.str "Propagating Top from ",
                                          Var.layout x])))
         in
            Rep.coerce (varRep x, r)
         end
      fun coerces (xs: Var.t vector, rs: Rep.t vector) =
         Vector.foreach2 (xs, rs, coerce)

      val _ =
         Vector.foreach
         (datatypes, fn Datatype.T {cons, ...} =>
          Vector.foreach
          (cons, fn {con, args} =>
           setConInfo (con, {argsTypes = args,
                             args = Rep.fromTypes (args, fn i =>
                                                   Layout.seq
                                                   [Con.layout con,
                                                    Layout.str " arg ",
                                                    Int.layout i])})))
      val _ = 
         List.foreach
         (functions, fn f =>
          let val {args, name, raises, returns, ...} = Function.dest f
          in 
            setFuncInfo (name, {args = fromFormals args,
                                returns = Option.map (returns, fn ts =>
                                                      Rep.fromTypes (ts, fn i =>
                                                                     Layout.seq
                                                                     [Func.layout name,
                                                                      Layout.str " return ",
                                                                      Int.layout i])),
                                raises = Option.map (raises, fn ts =>
                                                     Rep.fromTypes (ts, fn i =>
                                                                    Layout.seq
                                                                    [Func.layout name,
                                                                     Layout.str " raise ",
                                                                     Int.layout i]))})
          end)

      fun doitStatement (Statement.T {exp, var, ...}) =
         case exp of
            Tuple xs =>
               Option.app
               (var, fn var =>
                let
                   val r = Rep.new ()
                   val _ =
                      Rep.addHandler
                      (r, fn () =>
                       Control.diagnostics
                       (fn display =>
                        display
                        (Layout.seq
                         [Layout.str "Don't flatten ",
                          Var.layout var,
                          Layout.str " (tuple definition) because it is Top"])))
                in
                   setVarInfo (var, {rep = r,
                                     tuple = ref (SOME xs)})
                end)
          | ConApp {con, args} => coerces (args, conArgs con)
          | Var x => setVarInfo (valOf var, varInfo x)
          | _ => ()
      val _ = Vector.foreach (globals, doitStatement)
      val _ =
         List.foreach
         (functions, fn f =>
          let
             val {blocks, name, ...} = Function.dest f
             val {raises, returns, ...} = funcInfo name
             fun unify (rs1, rs2, msg) =
                Vector.foreach2 (rs1, rs2, fn (r1, r2) =>
                   let
                      val _ = Rep.addHandler (r1, fn () =>
                         Control.diagnostics (fn display =>
                            display (Layout.seq [Layout.str "Propagating Top via unify (",
                                                 msg (),
                                                 Layout.str ")"])))
                      val _ = Rep.addHandler (r2, fn () =>
                         Control.diagnostics (fn display =>
                            display (Layout.seq [Layout.str "Propagating Top via unify (",
                                                 msg (),
                                                 Layout.str ")"])))
                   in
                      Rep.unify (r1, r2)
                   end)
          in
             Vector.foreach
             (blocks, fn Block.T {label, args, statements, ...} =>
              (setLabelInfo (label, {args = fromFormals args})
               ; Vector.foreach (statements, doitStatement)))
             ; Vector.foreach
               (blocks, fn Block.T {transfer, ...} =>
                case transfer of
                   Return xs =>
                      (case returns of
                          NONE => Error.bug "Flatten.flatten: return mismatch"
                        | SOME rs => coerces (xs, rs))
                 | Raise xs =>
                      (case raises of
                          NONE => Error.bug "Flatten.flatten: raise mismatch"
                        | SOME rs => coerces (xs, rs))
                 | Call {func, args, return, ...} =>
                      let
                        val {args = funcArgs, 
                             returns = funcReturns,
                             raises = funcRaises} =
                          funcInfo func
                        val _ = coerces (args, funcArgs)
                        fun unifyReturns () =
                           case (funcReturns, returns) of
                              (SOME rs, SOME rs') => 
                                 unify (rs, rs', fn () => Layout.str "return")
                            | _ => ()           
                        fun unifyRaises () =
                           case (funcRaises, raises) of
                              (SOME rs, SOME rs') => 
                                 unify (rs, rs', fn () => Layout.str "raise")
                            | _ => ()
                      in
                        case return of
                           Return.Dead => ()
                         | Return.NonTail {cont, handler} =>
                              (Option.app 
                               (funcReturns, fn rs =>
                                unify (rs, labelArgs cont, fn () => Layout.str "return"))
                               ; case handler of
                                    Handler.Caller => unifyRaises ()
                                  | Handler.Dead => ()
                                  | Handler.Handle handler =>
                                       Option.app
                                       (funcRaises, fn rs =>
                                        unify (rs, labelArgs handler, fn () => Layout.str "raise")))
                         | Return.Tail => (unifyReturns (); unifyRaises ())
                      end
                 | Goto {dst, args} => coerces (args, labelArgs dst)
                 | Case {cases = Cases.Con cases, ...} =>
                      Vector.foreach
                      (cases, fn (con, label) =>
                       Rep.coerces (conArgs con, labelArgs label))
                 | _ => ())
          end)
      val _ =
         Control.diagnostics
         (fn display =>
          List.foreach
          (functions, fn f => 
           let 
              val name = Function.name f
              val {args, raises, returns} = funcInfo name
              open Layout
           in 
              display
              (seq [Func.layout name,
                    str " ",
                    record
                    [("args", Vector.layout Rep.layout args),
                     ("returns", Option.layout (Vector.layout Rep.layout) returns),
                     ("raises", Option.layout (Vector.layout Rep.layout) raises)]])
           end))
      fun flattenTypes (ts: Type.t vector, rs: Rep.t vector): Type.t vector =
         Vector.fromList
         (Vector.fold2 (ts, rs, [], fn (t, r, ts) =>
                        if Rep.isFlat r
                           then Vector.fold (Type.deTuple t, ts, op ::)
                        else t :: ts))
      val datatypes =
         Vector.map
         (datatypes, fn Datatype.T {tycon, cons} =>
          Datatype.T {tycon = tycon,
                      cons = (Vector.map
                              (cons, fn {con, args} =>
                               {con = con,
                                args = flattenTypes (args, conArgs con)}))})
      fun flattens (xs as xsX: Var.t vector, rs: Rep.t vector) =
         Vector.fromList
         (Vector.fold2 (xs, rs, [],
                        fn (x, r, xs) =>
                        if Rep.isFlat r
                           then (case !(varTuple x) of
                                    SOME ys => Vector.fold (ys, xs, op ::)
                                  | _ => (Error.bug 
                                          (concat
                                           ["Flatten.flattens: tuple unavailable: ",
                                            (Var.toString x), " ",
                                            (Layout.toString
                                             (Vector.layout Var.layout xsX))])))
                        else x :: xs))
      fun doitStatement (stmt as Statement.T {var, ty, exp}) =
         case exp of
            ConApp {con, args} =>
               Statement.T {var = var,
                            ty = ty,
                            exp = ConApp {con = con,
                                          args = flattens (args, conArgs con)}}
          | _ => stmt
      val globals = Vector.map (globals, doitStatement)
      fun doitFunction f =
         let
            val {args, inline, name, raises, returns, start, ...} =
               Function.dest f
            val {args = argsReps, returns = returnsReps, raises = raisesReps} = 
              funcInfo name

            val newBlocks = ref []

            fun doitArgs (args, reps) =
               let
                  val (args, stmts) =
                     Vector.fold2
                     (args, reps, ([], []), fn ((x, ty), r, (args, stmts)) =>
                      if Rep.isFlat r
                         then let
                                 val tys = Type.deTuple ty
                                 val xs = Vector.map (tys, fn _ => Var.newNoname ())
                                 val _ = varTuple x := SOME xs
                                 val args =
                                    Vector.fold2
                                    (xs, tys, args, fn (x, ty, args) =>
                                     (x, ty) :: args)
                              in 
                                 (args,
                                  Statement.T {var = SOME x,
                                               ty = ty,
                                               exp = Tuple xs}
                                  :: stmts)
                              end
                      else ((x, ty) :: args, stmts))
               in
                 (Vector.fromList args, Vector.fromList stmts)
               end

            fun doitCaseCon {test, cases, default} =
               let
                  val cases =
                     Vector.map
                     (cases, fn (c, l) =>
                      let
                         val {args, argsTypes} = conInfo c
                         val actualReps = labelArgs l
                      in if Vector.forall2
                            (args, actualReps, fn (r, r') =>
                             Rep.isFlat r = Rep.isFlat r')
                            then (c, l)
                         else 
                         (* Coerce from the constructor representation to the
                          * formals the jump expects.
                          *)
                         let
                            val l' = Label.newNoname ()
                            (* The formals need to match the type of the con.
                             * The actuals need to match the type of l.
                             *)
                            val (stmts, formals, actuals) =
                               Vector.fold3
                               (args, actualReps, argsTypes,
                                ([], [], []),
                                fn (r, r', ty, (stmts, formals, actuals)) =>
                                if Rep.isFlat r
                                   then
                                   (* The con is flat *)
                                   let
                                      val xts =
                                         Vector.map
                                         (Type.deTuple ty, fn ty =>
                                          (Var.newNoname (), ty))
                                      val xs = Vector.map (xts, #1)
                                      val formals =
                                         Vector.fold (xts, formals, op ::)
                                      val (stmts, actuals) =
                                         if Rep.isFlat r'
                                            then (stmts,
                                                  Vector.fold 
                                                  (xs, actuals, op ::))
                                         else
                                         let
                                            val x = Var.newNoname ()
                                         in
                                           (Statement.T {var = SOME x,
                                                         ty = ty,
                                                         exp = Tuple xs}
                                            :: stmts,
                                            x :: actuals)
                                         end
                                   in (stmts, formals, actuals)
                                   end
                                else
                                (* The con is tupled *)
                                let
                                   val tuple = Var.newNoname ()
                                   val formals = (tuple, ty) :: formals
                                   val (stmts, actuals) =
                                      if Rep.isFlat r'
                                         then
                                         let
                                            val xts =
                                               Vector.map
                                               (Type.deTuple ty, fn ty =>
                                                (Var.newNoname (), ty))
                                            val xs = Vector.map (xts, #1)
                                            val actuals =
                                               Vector.fold
                                               (xs, actuals, op ::)
                                            val stmts =
                                               Vector.foldi
                                               (xts, stmts,
                                                fn (i, (x, ty), stmts) =>
                                                Statement.T 
                                                {var = SOME x,
                                                 ty = ty,
                                                 exp = Select {tuple = tuple,
                                                               offset = i}}
                                                :: stmts)
                                         in (stmts, actuals)
                                         end
                                      else (stmts, tuple :: actuals)
                                in (stmts, formals, actuals)
                                end)
                            val _ =
                               List.push
                               (newBlocks,
                                Block.T
                                {label = l',
                                 args = Vector.fromList formals,
                                 statements = Vector.fromList stmts,
                                 transfer = Goto {dst = l,
                                                  args = Vector.fromList actuals}})
                         in
                           (c, l')
                         end
                      end)
               in Case {test = test,
                        cases = Cases.Con cases,
                        default = default}
               end 
            fun doitTransfer transfer =
               case transfer of
                  Call {func, args, inline, return} =>
                     Call {func = func, 
                           args = flattens (args, funcArgs func),
                           inline = inline,
                           return = return}
                | Case {test, cases = Cases.Con cases, default} =>
                     doitCaseCon {test = test, 
                                  cases = cases, 
                                  default = default}
                | Goto {dst, args} =>
                     Goto {dst = dst,
                           args = flattens (args, labelArgs dst)}
                | Raise xs => Raise (flattens (xs, valOf raisesReps))
                | Return xs => Return (flattens (xs, valOf returnsReps))
                | _ => transfer

            fun doitBlock (Block.T {label, args, statements, transfer}) =
               let
                 val (args, stmts) = doitArgs (args, labelArgs label)
                 val statements = Vector.map (statements, doitStatement)
                 val statements = Vector.concat [stmts, statements]
                 val transfer = doitTransfer transfer
               in
                  Block.T {label = label,
                           args = args,
                           statements = statements,
                           transfer = transfer}
               end

            val (args, stmts) = doitArgs (args, argsReps)
            val start' = Label.newNoname ()
            val _ = List.push
                    (newBlocks,
                     Block.T {label = start',
                              args = Vector.new0 (),
                              statements = stmts,
                              transfer = Goto {dst = start, 
                                               args = Vector.new0 ()}})
            val start = start'
            val _ = Function.dfs 
                    (f, fn b => let val _ = List.push (newBlocks, doitBlock b)
                                in fn () => ()
                                end)
            val blocks = Vector.fromList (!newBlocks)
            val returns =
               Option.map
               (returns, fn ts =>
                flattenTypes (ts, valOf returnsReps))
            val raises =
               Option.map
               (raises, fn ts =>
                flattenTypes (ts, valOf raisesReps))
         in
            Function.new {args = args,
                          blocks = blocks,
                          inline = inline,
                          name = name,
                          raises = raises,
                          returns = returns,
                          start = start}
         end

      val shrink = shrinkFunction {globals = globals}
      val functions = List.revMap (functions, shrink o doitFunction)
      val program =
         Program.T {datatypes = datatypes,
                    globals = globals,
                    functions = functions,
                    main = main}
      val _ = Program.clearTop program
   in
      program
   end

end
