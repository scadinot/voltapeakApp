//
//  TestHelpers.swift
//  voltapeakTests
//
//  Shared helpers for property-based tests of the numerical pipeline.
//

import Foundation
import Testing

/// numpy.linspace equivalent: `count` evenly spaced points from `start` to `stop` inclusive.
func linspace(_ start: Double, _ stop: Double, _ count: Int) -> [Double] {
    precondition(count >= 2, "linspace requires count >= 2")
    let step = (stop - start) / Double(count - 1)
    return (0..<count).map { start + Double($0) * step }
}

/// Gaussian g(x) = amplitude * exp(-((x - center) / width)^2 / 2).
func gaussian(x: Double, center: Double, amplitude: Double, width: Double) -> Double {
    let z = (x - center) / width
    return amplitude * exp(-0.5 * z * z)
}

/// Asserts that two arrays have the same length and that every element pair differs by less than `accuracy`.
func expectArrayApproxEqual(
    _ actual: [Double],
    _ expected: [Double],
    accuracy: Double,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(actual.count == expected.count,
            "length mismatch: \(actual.count) vs \(expected.count)",
            sourceLocation: sourceLocation)
    guard actual.count == expected.count else { return }
    for i in 0..<actual.count {
        let diff = abs(actual[i] - expected[i])
        #expect(diff < accuracy,
                "index \(i): \(actual[i]) vs \(expected[i]) (diff=\(diff) >= \(accuracy))",
                sourceLocation: sourceLocation)
    }
}

/// Sample variance (Bessel's correction).
func variance(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let mean = values.reduce(0, +) / Double(values.count)
    let sumSq = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
    return sumSq / Double(values.count - 1)
}
