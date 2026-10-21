#ifndef SWEEPDECK_RUST_H
#define SWEEPDECK_RUST_H

#include <stdint.h>

typedef struct {
    int64_t value;
    int64_t subvalue;
    uint32_t path_offset;
    uint32_t path_length;
} SweepdeckSortRow;

/*
 Sort candidate indices by value, then subvalue, then ASCII path bytes.
 `descending` must be 0 (ascending) or 1 (descending). Returns 0 on success,
 1 when a required non-empty buffer pointer is null, 2 for an invalid order,
 and 3 for a bad path range. An empty batch succeeds without dereferencing any
 pointers. For a non-empty batch, `rows` and `output_indices` must be non-null;
 `paths` may be null only when `path_byte_count` is zero. `rows` and
 `output_indices` must be aligned for their element types. The function checks
 that the output byte range does not overlap either input before creating Rust
 slices. Returns 4 when the output range overlaps an input or a buffer address
 range overflows.
 */
int32_t sweepdeck_sort_indices(const SweepdeckSortRow *rows,
                               uint32_t row_count,
                               const uint8_t *paths,
                               uint32_t path_byte_count,
                               uint8_t descending,
                               uint32_t *output_indices);

#endif
