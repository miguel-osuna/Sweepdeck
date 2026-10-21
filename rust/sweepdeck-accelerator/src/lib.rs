#![no_std]

#[cfg(test)]
extern crate std;

#[cfg(not(test))]
unsafe extern "C" {
    fn abort() -> !;
}

#[cfg(not(test))]
#[panic_handler]
fn panic_handler(_: &core::panic::PanicInfo<'_>) -> ! {
    // SAFETY: Darwin's C runtime provides abort; the FFI boundary cannot unwind.
    unsafe { abort() }
}

#[repr(C)]
pub struct SortRow {
    pub value: i64,
    pub subvalue: i64,
    pub path_offset: u32,
    pub path_length: u32,
}

fn compare_indices(
    left_index: u32,
    right_index: u32,
    rows: &[SortRow],
    paths: &[u8],
    descending: u8,
) -> core::cmp::Ordering {
    let left = &rows[left_index as usize];
    let right = &rows[right_index as usize];
    let value_order = if descending == 1 {
        right
            .value
            .cmp(&left.value)
            .then_with(|| right.subvalue.cmp(&left.subvalue))
    } else {
        left.value
            .cmp(&right.value)
            .then_with(|| left.subvalue.cmp(&right.subvalue))
    };
    let left_path =
        &paths[left.path_offset as usize..left.path_offset as usize + left.path_length as usize];
    let right_path =
        &paths[right.path_offset as usize..right.path_offset as usize + right.path_length as usize];
    value_order
        .then_with(|| left_path.cmp(right_path))
        .then_with(|| left_index.cmp(&right_index))
}

fn sift_down(
    values: &mut [u32],
    mut root: usize,
    end: usize,
    rows: &[SortRow],
    paths: &[u8],
    descending: u8,
) {
    loop {
        let left_child = root * 2 + 1;
        if left_child >= end {
            return;
        }
        let right_child = left_child + 1;
        let greater_child = if right_child < end
            && compare_indices(
                values[left_child],
                values[right_child],
                rows,
                paths,
                descending,
            ) == core::cmp::Ordering::Less
        {
            right_child
        } else {
            left_child
        };

        if compare_indices(values[root], values[greater_child], rows, paths, descending)
            != core::cmp::Ordering::Less
        {
            return;
        }
        values.swap(root, greater_child);
        root = greater_child;
    }
}

const SUCCESS: i32 = 0;
const INVALID_POINTER: i32 = 1;
const INVALID_ORDER: i32 = 2;
const INVALID_PATH_RANGE: i32 = 3;
const OVERLAPPING_BUFFERS: i32 = 4;

fn ranges_are_disjoint(
    left_start: usize,
    left_length: usize,
    right_start: usize,
    right_length: usize,
) -> bool {
    if left_length == 0 || right_length == 0 {
        return true;
    }
    let Some(left_end) = left_start.checked_add(left_length) else {
        return false;
    };
    let Some(right_end) = right_start.checked_add(right_length) else {
        return false;
    };
    left_end <= right_start || right_end <= left_start
}

/// Sorts a batch of numeric keys with deterministic path tie-breaking.
///
/// # Safety
/// For a non-empty batch, `rows` must point to `row_count` readable, aligned
/// `SortRow` values and `output_indices` to `row_count` writable, aligned `u32`
/// values. If `path_byte_count` is nonzero, `paths` must point to that many
/// readable bytes; when it is zero, `paths` may be null. The output byte range
/// is checked against both input byte ranges and overlap is rejected before any
/// Rust slices are created. The input ranges may overlap.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn sweepdeck_sort_indices(
    rows: *const SortRow,
    row_count: u32,
    paths: *const u8,
    path_byte_count: u32,
    descending: u8,
    output_indices: *mut u32,
) -> i32 {
    if descending > 1 {
        return INVALID_ORDER;
    }
    if row_count == 0 {
        return SUCCESS;
    }
    if rows.is_null() || output_indices.is_null() || (path_byte_count > 0 && paths.is_null()) {
        return INVALID_POINTER;
    }
    if !rows.addr().is_multiple_of(core::mem::align_of::<SortRow>())
        || !output_indices
            .addr()
            .is_multiple_of(core::mem::align_of::<u32>())
    {
        return INVALID_POINTER;
    }
    let Some(rows_byte_count) = (row_count as usize).checked_mul(core::mem::size_of::<SortRow>())
    else {
        return INVALID_POINTER;
    };
    let Some(output_byte_count) = (row_count as usize).checked_mul(core::mem::size_of::<u32>())
    else {
        return INVALID_POINTER;
    };
    if !ranges_are_disjoint(
        rows.addr(),
        rows_byte_count,
        output_indices.addr(),
        output_byte_count,
    ) || (path_byte_count > 0
        && !ranges_are_disjoint(
            paths.addr(),
            path_byte_count as usize,
            output_indices.addr(),
            output_byte_count,
        ))
    {
        return OVERLAPPING_BUFFERS;
    }

    // SAFETY: the caller promises that these pointers reference valid buffers
    // of the lengths passed to this function. The output is disjoint from both
    // input ranges, and all path offsets are validated before sorting.
    let rows = unsafe { core::slice::from_raw_parts(rows, row_count as usize) };
    let paths: &[u8] = if path_byte_count == 0 {
        &[]
    } else {
        // SAFETY: a non-null pointer to `path_byte_count` readable bytes is required.
        unsafe { core::slice::from_raw_parts(paths, path_byte_count as usize) }
    };
    for row in rows {
        let Some(end) = (row.path_offset as usize).checked_add(row.path_length as usize) else {
            return INVALID_PATH_RANGE;
        };
        if end > paths.len() {
            return INVALID_PATH_RANGE;
        }
    }

    // SAFETY: the caller provides one writable output slot per row.
    let output = unsafe { core::slice::from_raw_parts_mut(output_indices, row_count as usize) };
    for (index, value) in output.iter_mut().enumerate() {
        *value = index as u32;
    }
    for start in (0..output.len() / 2).rev() {
        sift_down(output, start, output.len(), rows, paths, descending);
    }
    for end in (1..output.len()).rev() {
        output.swap(0, end);
        sift_down(output, 0, end, rows, paths, descending);
    }

    SUCCESS
}

#[cfg(test)]
mod tests {
    use super::{SortRow, ranges_are_disjoint, sweepdeck_sort_indices};
    use std::vec;
    use std::vec::Vec;

    #[test]
    fn range_check_accepts_adjacent_buffers_and_empty_ranges() {
        assert!(ranges_are_disjoint(100, 16, 116, 4));
        assert!(ranges_are_disjoint(100, 0, 100, 4));
    }

    #[test]
    fn range_check_rejects_overlapping_buffers_and_address_overflow() {
        assert!(!ranges_are_disjoint(100, 16, 108, 4));
        assert!(!ranges_are_disjoint(usize::MAX - 3, 8, 20, 4));
    }

    #[test]
    fn rejects_output_that_overlaps_rows_before_creating_slices() {
        let mut rows = [
            SortRow {
                value: 2,
                subvalue: 0,
                path_offset: 0,
                path_length: 0,
            },
            SortRow {
                value: 1,
                subvalue: 0,
                path_offset: 0,
                path_length: 0,
            },
        ];
        let rows_ptr = rows.as_mut_ptr();
        let output_ptr = rows.as_mut_ptr().cast::<u32>();

        // SAFETY: both pointers cover aligned, live memory for the lengths
        // passed. The function must reject their overlap before making slices.
        let status =
            unsafe { sweepdeck_sort_indices(rows_ptr, 2, core::ptr::null(), 0, 0, output_ptr) };

        assert_eq!(status, 4);
        assert_eq!(rows[0].value, 2);
        assert_eq!(rows[1].value, 1);
    }

    fn sort(rows: &[SortRow], paths: &[u8], descending: u8) -> (i32, Vec<u32>) {
        let mut output = vec![u32::MAX; rows.len()];
        // SAFETY: each pointer refers to a live slice for the duration of the call;
        // output has one writable element per row.
        let status = unsafe {
            sweepdeck_sort_indices(
                rows.as_ptr(),
                rows.len() as u32,
                paths.as_ptr(),
                paths.len() as u32,
                descending,
                output.as_mut_ptr(),
            )
        };
        (status, output)
    }

    #[test]
    fn sorts_largest_first_and_breaks_ties_by_path() {
        let paths = b"z.dmgA.dmgm.dmg";
        let rows = [
            SortRow {
                value: 10,
                subvalue: 0,
                path_offset: 0,
                path_length: 5,
            },
            SortRow {
                value: 30,
                subvalue: 0,
                path_offset: 10,
                path_length: 5,
            },
            SortRow {
                value: 10,
                subvalue: 0,
                path_offset: 5,
                path_length: 5,
            },
        ];

        let (status, output) = sort(&rows, paths, 1);

        assert_eq!(status, 0);
        assert_eq!(output, [1, 2, 0]);
    }

    #[test]
    fn sorts_oldest_first_and_breaks_ties_by_path() {
        let paths = b"new.dmgold.dmgmid.dmg";
        let rows = [
            SortRow {
                value: 200,
                subvalue: 0,
                path_offset: 0,
                path_length: 7,
            },
            SortRow {
                value: 100,
                subvalue: 100,
                path_offset: 7,
                path_length: 7,
            },
            SortRow {
                value: 100,
                subvalue: 200,
                path_offset: 14,
                path_length: 7,
            },
        ];

        let (status, output) = sort(&rows, paths, 0);

        assert_eq!(status, 0);
        assert_eq!(output, [1, 2, 0]);
    }

    #[test]
    fn rejects_path_ranges_outside_the_input_buffer() {
        let paths = b"short";
        let rows = [SortRow {
            value: 1,
            subvalue: 0,
            path_offset: 3,
            path_length: 4,
        }];

        let (status, _) = sort(&rows, paths, 1);

        assert_eq!(status, 3);
    }

    #[test]
    fn accepts_null_path_buffer_when_all_paths_are_empty() {
        let rows = [SortRow {
            value: 1,
            subvalue: 0,
            path_offset: 0,
            path_length: 0,
        }];
        let mut output = [u32::MAX];
        // SAFETY: the row and output pointers refer to valid one-element arrays;
        // the path buffer is empty and null is allowed for zero bytes.
        let status = unsafe {
            sweepdeck_sort_indices(
                rows.as_ptr(),
                rows.len() as u32,
                std::ptr::null(),
                0,
                0,
                output.as_mut_ptr(),
            )
        };

        assert_eq!(status, 0);
        assert_eq!(output, [0]);
    }

    #[test]
    fn accepts_an_empty_batch_without_dereferencing_pointers() {
        // SAFETY: empty input permits null pointers by contract.
        let status = unsafe {
            sweepdeck_sort_indices(
                std::ptr::null(),
                0,
                std::ptr::null(),
                0,
                1,
                std::ptr::null_mut(),
            )
        };

        assert_eq!(status, 0);
    }
}
