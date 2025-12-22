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

// void Simd_Float32x8_addArr(Pointer in1, Pointer in2, Pointer out) {
//   // The compiler passes us:
//   //   (real vec * real vec * real arr)
//   // which all "decay" to `unsigned char*`
//   const float* in1f = (const float*)in1;
//   const float* in2f = (const float*)in2;
//   float* outf = (const float*)out;
//   // Issue unaligned load/stores to be safe
//   //
//   // out[0:7] = in1[0:7] + in2[0:7]
//   __m256 vec1 = _mm256_loadu_ps(in1f);
//   __m256 vec2 = _mm256_loadu_ps(in2f);
//   __m256 sum = _mm256_add_ps(vec1, vec2);
//   _mm256_storeu_ps(outf, sum);
// }

#include <assert.h>

__m256 Simd_Float32x8_add(__m256 in1, __m256 in2) {
  return _mm256_add_ps(in1, in2);
}

__m256 Simd_Float32x8_load(Pointer in) {
  assert(in != NULL);
  const float* inf = (const float*)in;
  return _mm256_loadu_ps(inf);
}

void Simd_Float32x8_store(__m256 in, Pointer out) {
  assert(out != NULL);
  const float* outf = (const float*)out;
  _mm256_storeu_ps(outf, in);
}

#endif  // _SIMD_OPS_H
