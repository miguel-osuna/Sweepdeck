import Foundation
import Darwin

public struct DiskSnapshot: Sendable {
    public let total: Int64
    public let available: Int64
    public var used: Int64 { max(0, total - available) }
    public static func read(at url: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> DiskSnapshot {
        let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        guard let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity else {
            throw SweepError.refused("Disk capacity is unavailable for this volume.")
        }
        return DiskSnapshot(total: Int64(total), available: Int64(available))
    }
}
public struct HealthSnapshot: Sendable {
    public let physicalMemory: UInt64
    public let usedMemory: UInt64?
    public let swapUsed: UInt64?
    public let cpuPercent: Double?
    public let thermalState: String
}
public actor MetricsProvider {
    private var previousCPU: (busy: UInt64, total: UInt64)?
    public init() {}
    public func reset() { previousCPU = nil }
    public func sample() -> HealthSnapshot {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }

        var vm = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let vmResult = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &vmCount)
            }
        }
        var pageSize: vm_size_t = 0
        let pageResult = host_page_size(host, &pageSize)
        let used = vmResult == KERN_SUCCESS && pageResult == KERN_SUCCESS ?
            (UInt64(vm.active_count) + UInt64(vm.wire_count) + UInt64(vm.compressor_page_count)) * UInt64(pageSize) : nil
        var swap = xsw_usage(); var swapSize = MemoryLayout<xsw_usage>.size
        let swapResult = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0)
        var cpu = host_cpu_load_info()
        var cpuCount = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let cpuResult = withUnsafeMutablePointer(to: &cpu) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(cpuCount)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &cpuCount)
            }
        }
        var percent: Double?
        if cpuResult == KERN_SUCCESS {
            let ticks = cpu.cpu_ticks
            let busy = UInt64(ticks.0) + UInt64(ticks.1) + UInt64(ticks.3)
            let total = busy + UInt64(ticks.2)
            if let last = previousCPU, total > last.total, busy >= last.busy {
                percent = min(100, max(0, Double(busy - last.busy) / Double(total - last.total) * 100))
            }
            previousCPU = (busy, total)
        }
        let thermal: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "Nominal"
        case .fair: thermal = "Fair"
        case .serious: thermal = "Serious"
        case .critical: thermal = "Critical"
        @unknown default: thermal = "Unavailable"
        }
        return HealthSnapshot(physicalMemory: ProcessInfo.processInfo.physicalMemory, usedMemory: used,
                              swapUsed: swapResult == 0 ? swap.xsu_used : nil, cpuPercent: percent, thermalState: thermal)
    }
}
