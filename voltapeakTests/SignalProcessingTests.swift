//
//  SignalProcessingTests.swift
//  voltapeakTests
//
//  Property-based tests for SignalProcessing.detectPeak / calculateBaseline /
//  savitzkyGolayFilter. The private helpers `gradient` and `polynomialFit` are
//  covered indirectly through the public entry points that exercise them.
//

import Foundation
import Testing
@testable import voltapeak

@Suite struct SignalProcessingTests {

    // MARK: - savitzkyGolayFilter (moving-average implementation in SignalProcessing)

    @Test func savitzkyGolayFilterPreservesLength() {
        let signal = linspace(0, 1, 30).map { $0 * $0 }
        let smoothed = SignalProcessing.savitzkyGolayFilter(signal)
        #expect(smoothed.count == signal.count)
    }

    @Test func savitzkyGolayFilterReturnsUnchangedForTinySignal() {
        let signal: [Double] = [1, 2, 3]
        let smoothed = SignalProcessing.savitzkyGolayFilter(signal)
        expectArrayApproxEqual(smoothed, signal, accuracy: 0)
    }

    // MARK: - detectPeak

    /// On a clean Gaussian, the detected peak must land within one sample of the true center.
    @Test func detectPeakOnGaussian() {
        let xs = linspace(-5, 5, 101)
        let signal = xs.map { gaussian(x: $0, center: 0, amplitude: 1, width: 1.0) }
        let (peakPotential, peakCurrent) = SignalProcessing.detectPeak(
            signal: signal,
            potentials: xs,
            marginRatio: 0.10,
            maxSlope: nil
        )
        // The true maximum is at xs[50] = 0.0
        #expect(abs(peakPotential - 0.0) < (xs[1] - xs[0]) * 1.5,
                "peak potential \(peakPotential) should be within ~1 sample of 0")
        #expect(abs(peakCurrent - 1.0) < 1e-9,
                "peak current \(peakCurrent) should equal amplitude 1.0")
    }

    /// detectPeak excludes a `marginRatio` fraction at each end. A peak placed inside
    /// that excluded zone must NOT be returned: the detector falls back to a peak in
    /// the searchable region.
    @Test func detectPeakRespectsMargin() {
        let xs = linspace(0, 100, 100)
        // True maximum at index 2 (within the 10% left margin)
        var signal = xs.map { _ in 0.0 }
        signal[2] = 10.0          // excluded peak
        signal[50] = 5.0          // smaller peak inside the searchable region

        let (peakPotential, peakCurrent) = SignalProcessing.detectPeak(
            signal: signal,
            potentials: xs,
            marginRatio: 0.10,
            maxSlope: nil
        )
        #expect(peakCurrent == 5.0,
                "detector should have ignored the larger peak inside the margin, got current=\(peakCurrent)")
        #expect(abs(peakPotential - xs[50]) < 1e-9)
    }

    // MARK: - calculateBaseline

    @Test func calculateBaselineLengthMatchesInput() {
        let xs = linspace(-1, 1, 50)
        let signal = xs.map { gaussian(x: $0, center: 0, amplitude: 1, width: 0.3) }
        let (baseline, _) = SignalProcessing.calculateBaseline(
            signal: signal,
            potentials: xs,
            peakPotential: 0.0
        )
        #expect(baseline.count == signal.count)
        for v in baseline {
            #expect(v.isFinite, "non-finite baseline value: \(v)")
        }
    }

    /// The returned exclusionRange must straddle the supplied peakPotential.
    @Test func calculateBaselineExclusionRangeContainsPeak() {
        let xs = linspace(-2, 2, 60)
        let signal = xs.map { gaussian(x: $0, center: 0.5, amplitude: 2, width: 0.3) }
        let (_, range) = SignalProcessing.calculateBaseline(
            signal: signal,
            potentials: xs,
            peakPotential: 0.5,
            exclusionWidthRatio: 0.05
        )
        #expect(range.0 < 0.5 && 0.5 < range.1,
                "peakPotential 0.5 should fall inside exclusion range (\(range.0), \(range.1))")

        // Width sanity: exclusionWidth = 0.05 * (xs.last - xs.first) = 0.05 * 4 = 0.2,
        // so total range width = 2 * 0.2 = 0.4.
        let width = range.1 - range.0
        #expect(abs(width - 0.4) < 1e-9,
                "exclusion range width \(width) should equal 2 * exclusionWidthRatio * span = 0.4")
    }
}
