structure Float32x8 = MLton.Float32x8

val fromList = let
    fun doLoad vec = Float32x8.fromVec (vec, 0)
in
    doLoad o Vector.fromList
end

val _ = let 
  val v1 = fromList [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
  val v2 = Float32x8.toVec v1
in
  ()
end
