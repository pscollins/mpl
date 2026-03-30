import sys

with open('header.txt', 'r') as f:
    header = f.read()

body = """
val x_64407: (word8) vector = "bug"
val x_76660: unit = ()
val x_76662: word32 = 0x1:w32

fun main_4 (): {returns = Some (unit), raises = None} = L_0 ()
  block L_0 ()
    val x_double: real64 = 1.0
    case parforEnv_0  of
      parforEnv_0 => L_1
  block L_1 (env_dummy: (lambdas_27, lambdas_28) tuple)
    val par_dummy: lambdas_28 = #1 (env_dummy)
    val env: (real64, lambdas_28) tuple = (x_double, par_dummy)
    call L_2 (f_1341 (env, x_76662)) handle _ => L_3
  block L_2 (x: unit)
    return (())
  block L_3 (e: exn)
    bug

fun f_1341 (env_715: (real64, lambdas_28) tuple, x_78254: word32):
  {returns = Some (unit), raises = Some (exn)} =
L_1867 ()
  block L_1867 ()
    val x_78256: real64 = #0 (env_715)
    val _: real64 = prim Trace_noTuple[real64] (x_78256)
    return (x_76660 )

main_4
"""

with open('lit-tests/scratch/minimize.ssa', 'w') as f:
    f.write(header)
    f.write(body)
