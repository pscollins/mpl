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

Word256 __attribute__((always_inline))
Simd_Float32x8_mul(Word256 in1, Word256 in2) {
  return _mm256_mul_ps(in1, in2);
}

float
Simd_Float32x8_reduce_add(Word256 in1) {
  // https://stackoverflow.com/a/23190168
  /* ( x3+x7, x2+x6, x1+x5, x0+x4 ) */
  const __m128 x128 = _mm_add_ps(_mm256_extractf128_ps(in1, 1), _mm256_castps256_ps128(in1));
  /* ( -, -, x1+x3+x5+x7, x0+x2+x4+x6 ) */
  const __m128 x64 = _mm_add_ps(x128, _mm_movehl_ps(x128, x128));
  /* ( -, -, -, x0+x1+x2+x3+x4+x5+x6+x7 ) */
  const __m128 x32 = _mm_add_ss(x64, _mm_shuffle_ps(x64, x64, 0x55));
  /* Conversion to float is a no-op on x86-64 */
  return _mm_cvtss_f32(x32);
}

// Mutable pointers correspond `real array`, const pointers correspond to `real
// vector`

Word256 __attribute__((always_inline))
 Simd_Float32x8_load(Pointer in, int64_t offset) {
  const float* inf = (const float*)in;
  // Issue unaligned loads to be safe
  return _mm256_loadu_ps(inf + offset);
}

void __attribute__((always_inline))
Simd_Float32x8_store(Word256 in, Pointer out) {
  const float* outf = (const float*)out;
  // Issue unaligned stores to be safe
  _mm256_storeu_ps(outf, in);
}

#endif  // _SIMD_OPS_H
