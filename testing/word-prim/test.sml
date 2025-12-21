structure W = Word32
val _ = let
  val a = W.fromInt 2 
  val b = W.fromInt 3
in
  W.+ (a, b)
end
