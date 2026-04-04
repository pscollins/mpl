#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

bool ABP_deque_push_bot2(void* elem_to_push_op)
{
  return true;
}

void* ABP_deque_try_pop_bot2(void* s,
                             void* top_op,
                             void* bot_op,
                             void* data_op,
                             void* fail_value) {
  return NULL;
}

void GC_HH_joinIntoParentBeforeFastClone2(
                                         void* s,
                                         void* threadp,
                                         uint32_t newDepth,
                                         uint64_t tidLeft,
                                         uint64_t tidRight)
{ }

void GC_HH_decheckFork2(void* s, uint64_t *left, uint64_t *right) { }


