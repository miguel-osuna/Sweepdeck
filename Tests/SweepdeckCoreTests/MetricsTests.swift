import Testing
@testable import SweepdeckCore

@Test func healthMetricsStayWithinSupportedValues() async {
    let provider = MetricsProvider()
    await provider.reset()
    let first = await provider.sample()
    let second = await provider.sample()

    #expect(first.physicalMemory > 0)
    #expect(first.thermalState == "Nominal" || first.thermalState == "Fair" ||
            first.thermalState == "Serious" || first.thermalState == "Critical" ||
            first.thermalState == "Unavailable")
    if let cpu = second.cpuPercent {
        #expect(cpu >= 0)
        #expect(cpu <= 100)
    }
}
