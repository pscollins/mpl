#ifndef _SIMD_OPS_H
#define _SIMD_OPS_H

// SIMD primitives

#ifdef __AVX__
#include <immintrin.h>
#else  // __AVX__
// TODO(pscollins): Add a scalar fallback (or at least a runtime crash) so that
// non-SIMD code still builds properly.
#error "Must compile with -mavx!"
#endif

// `mpl` doesn't guarantee alignment for `Word256`s allocated on the stack,
// which causes confusing segfaults unless we mark the type as unaligned here.
typedef __m256 Word256 __attribute__((aligned(1)));

Word256 __attribute__((always_inline))
Simd_Float32x8_add(Word256 in1, Word256 in2) {
  return _mm256_add_ps(in1, in2);
}

// Mutable pointers correspond `real array`, const pointers correspond to `real
// vector`

Word256 __attribute__((always_inline))
 Simd_Float32x8_load(Pointer in) {
  const float* inf = (const float*)in;
  // Issue unaligned loads to be safe
  return _mm256_loadu_ps(inf);
}

void __attribute__((always_inline))
Simd_Float32x8_store(Word256 in, Pointer out) {
  const float* outf = (const float*)out;
  // Issue unaligned stores to be safe
  _mm256_storeu_ps(outf, in);
}

#endif  // _SIMD_OPS_H
