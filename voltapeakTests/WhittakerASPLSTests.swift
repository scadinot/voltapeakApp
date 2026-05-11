//
//  WhittakerASPLSTests.swift
//  voltapeakTests
//
//  Property-based tests for WhittakerASPLS.aspls
//  (pybaselines.whittaker.aspls reference implementation).
//

import Foundation
import Testing
@testable import voltapeak

@Suite struct WhittakerASPLSTests {

    @Test func preservesLength() {
        let y = linspace(0, 1, 50).map { sin(2 * .pi * $0) }
        let baseline = WhittakerASPLS.aspls(y: y, lam: 1e4, maxIter: 10)
        #expect(baseline.count == y.count)
    }

    /// Baseline of a constant signal must be that same constant.
    @Test func onConstantSignal() {
        let y = [Double](repeating: 3.0, count: 40)
        let baseline = WhittakerASPLS.aspls(y: y, lam: 1e5, maxIter: 20)
        expectArrayApproxEqual(baseline, y, accuracy: 1e-3)
    }

    /// Baseline of a linear signal must approximate that same line.
    /// A degree-2 difference penalty has zero second difference on affine signals,
    /// so asPLS recovers them up to its weight-update tolerance.
    @Test func onLinearSignal() {
        let xs = linspace(0, 10, 40)
        let y = xs.map { 0.5 * $0 + 1.0 }
        let baseline = WhittakerASPLS.aspls(y: y, lam: 1e5, maxIter: 30)
        // Interior tolerance is tighter than near edges where DTD's penalty weakens.
        let interior = 3..<(y.count - 3)
        let baselineInterior = interior.map { baseline[$0] }
        let yInterior = interior.map { y[$0] }
        expectArrayApproxEqual(baselineInterior, yInterior, accuracy: 5e-2)
    }

    /// On a linear baseline + sharp Gaussian peak, asPLS must leave the peak
    /// above the estimated baseline (i.e. residual is positive on the peak region).
    @Test func leavesGaussianPeakAboveBaseline() {
        let xs = linspace(-5, 5, 80)
        let trueBaseline = xs.map { 0.2 * $0 + 1.0 }
        let peak = xs.map { gaussian(x: $0, center: 0, amplitude: 5, width: 0.4) }
        let y = zip(trueBaseline, peak).map(+)

        let baseline = WhittakerASPLS.aspls(y: y, lam: 1e5, maxIter: 50)

        // Around the peak center (index 40 ± 5), residual y - baseline should be strongly positive.
        let center = xs.count / 2
        let peakWindow = (center - 3)...(center + 3)
        for i in peakWindow {
            #expect(y[i] - baseline[i] > 1.0,
                    "residual at index \(i) should be > 1.0 (peak amplitude=5), got \(y[i] - baseline[i])")
        }

        // Far from the peak, baseline should track the true linear baseline closely.
        for i in [5, 10, 70, 74] {
            let err = abs(baseline[i] - trueBaseline[i])
            #expect(err < 0.5,
                    "far from peak (i=\(i)): |baseline - trueBaseline| = \(err) should be < 0.5")
        }
    }

    @Test func handlesShortSignal() {
        let y = (0..<10).map { Double($0) }
        let baseline = WhittakerASPLS.aspls(y: y, lam: 100, maxIter: 5)
        #expect(baseline.count == y.count)
        // Sanity: result must be finite.
        for v in baseline {
            #expect(v.isFinite, "non-finite value in short-signal baseline: \(v)")
        }
    }

    @Test func isDeterministic() {
        let xs = linspace(0, 1, 30)
        let y = xs.map { sin(2 * .pi * $0) + 0.5 * $0 }
        let a = WhittakerASPLS.aspls(y: y, lam: 1e3, maxIter: 10)
        let b = WhittakerASPLS.aspls(y: y, lam: 1e3, maxIter: 10)
        expectArrayApproxEqual(a, b, accuracy: 0)
    }
}
