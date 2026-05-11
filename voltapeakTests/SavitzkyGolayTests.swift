//
//  SavitzkyGolayTests.swift
//  voltapeakTests
//
//  Property-based tests for SavitzkyGolay.filter (window=11, polyorder=2).
//  Reference: scipy.signal.savgol_filter with mode='interp'.
//

import Foundation
import Testing
@testable import voltapeak

@Suite struct SavitzkyGolayTests {

    @Test func preservesLength() {
        let signal = linspace(-1, 1, 30).map { $0 * $0 }
        let filtered = SavitzkyGolay.filter(signal)
        #expect(filtered.count == signal.count)
    }

    @Test func preservesConstantSignal() {
        let signal = [Double](repeating: 5.0, count: 30)
        let filtered = SavitzkyGolay.filter(signal)
        expectArrayApproxEqual(filtered, signal, accuracy: 1e-10)
    }

    /// SG with polyorder=2 must reproduce affine signals exactly (up to floating-point noise).
    @Test func preservesLinearSignal() {
        let xs = linspace(0, 10, 40)
        let signal = xs.map { 2.0 * $0 + 3.0 }
        let filtered = SavitzkyGolay.filter(signal)
        expectArrayApproxEqual(filtered, signal, accuracy: 1e-9)
    }

    /// SG with polyorder=2 must also reproduce quadratic signals exactly.
    @Test func preservesQuadraticSignal() {
        let xs = linspace(-5, 5, 50)
        let signal = xs.map { $0 * $0 }
        let filtered = SavitzkyGolay.filter(signal)
        expectArrayApproxEqual(filtered, signal, accuracy: 1e-9)
    }

    /// Deterministic high-frequency component (±0.1 alternation) on top of a smooth baseline:
    /// the SG output must collapse much closer to the baseline than the input does.
    @Test func reducesHighFrequencyOscillation() {
        let xs = linspace(-3, 3, 60)
        let baseline = xs.map { gaussian(x: $0, center: 0, amplitude: 1, width: 1.5) }
        let noisy = baseline.enumerated().map { idx, b in
            b + (idx.isMultiple(of: 2) ? 0.1 : -0.1)
        }

        let filtered = SavitzkyGolay.filter(noisy)

        // Compare residuals against the noise-free baseline on the interior only
        // (boundary points are exercised by other tests).
        let interior = 5..<(noisy.count - 5)
        let inputResiduals = interior.map { noisy[$0] - baseline[$0] }
        let outputResiduals = interior.map { filtered[$0] - baseline[$0] }

        #expect(variance(outputResiduals) < 0.1 * variance(inputResiduals),
                "SG filter should reduce alternating-noise variance by at least 10×")
    }

    @Test func returnsUnchangedForShortSignal() {
        let signal: [Double] = [1, 2, 3, 4, 5]
        let filtered = SavitzkyGolay.filter(signal)
        expectArrayApproxEqual(filtered, signal, accuracy: 0)
    }

    @Test func isDeterministic() {
        let xs = linspace(0, 1, 25)
        let signal = xs.map { sin(2 * .pi * $0) }
        let a = SavitzkyGolay.filter(signal)
        let b = SavitzkyGolay.filter(signal)
        expectArrayApproxEqual(a, b, accuracy: 0)
    }
}
