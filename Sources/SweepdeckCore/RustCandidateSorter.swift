import Foundation
import SweepdeckRust

enum RustCandidateSorter {
    static let minimumBatchSize = 512

    static func sorted(_ candidates: [Candidate], by sort: CandidateSort) -> [Candidate]? {
        guard candidates.count >= minimumBatchSize,
              candidates.count <= Int(UInt32.max),
              sort == .size || sort == .oldest else { return nil }

        var rows: [SweepdeckSortRow] = []
        var paths: [UInt8] = []
        rows.reserveCapacity(candidates.count)

        for candidate in candidates {
            let path = candidate.id.utf8
            guard path.allSatisfy({ $0 < 0x80 }),
                  paths.count <= Int(UInt32.max),
                  path.count <= Int(UInt32.max) - paths.count else { return nil }

            let value: Int64
            let subvalue: Int64
            switch sort {
            case .size:
                value = candidate.size
                subvalue = 0
            case .oldest:
                value = candidate.file.metadata.modifiedSeconds
                subvalue = candidate.file.metadata.modifiedNanos
            case .name:
                return nil
            }

            rows.append(SweepdeckSortRow(
                value: value,
                subvalue: subvalue,
                path_offset: UInt32(paths.count),
                path_length: UInt32(path.count)
            ))
            paths.append(contentsOf: path)
        }

        var indices = [UInt32](repeating: 0, count: candidates.count)
        let status = rows.withUnsafeBufferPointer { rowBuffer in
            paths.withUnsafeBufferPointer { pathBuffer in
                indices.withUnsafeMutableBufferPointer { outputBuffer in
                    sweepdeck_sort_indices(
                        rowBuffer.baseAddress,
                        UInt32(rowBuffer.count),
                        pathBuffer.baseAddress,
                        UInt32(pathBuffer.count),
                        sort == .size ? 1 : 0,
                        outputBuffer.baseAddress
                    )
                }
            }
        }

        guard status == 0, indices.allSatisfy({ Int($0) < candidates.count }) else { return nil }
        return indices.map { candidates[Int($0)] }
    }
}
