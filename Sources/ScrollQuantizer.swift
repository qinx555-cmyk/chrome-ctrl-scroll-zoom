import Foundation

/// A mouse detent advances once. Smooth wheels/trackpads accumulate 40 points.
struct ScrollQuantizer {
    private var remainder = 0.0
    private var lastTime = -Double.infinity
    private var wasContinuous = false

    mutating func reset() {
        remainder = 0
        lastTime = -Double.infinity
    }

    mutating func steps(delta: Double, continuous: Bool, time: Double,
                        gestureStart: Bool = false) -> Int {
        if gestureStart { reset() }
        guard delta.isFinite, time.isFinite, delta != 0 else { return 0 }
        if gestureStart || time - lastTime > 0.25 || time < lastTime ||
            continuous != wasContinuous || remainder * delta < 0 {
            remainder = 0
        }
        lastTime = time
        wasContinuous = continuous
        if !continuous { return delta > 0 ? 1 : -1 }
        remainder += delta
        let count = Int(min(abs(remainder) / 40, 4))
        let result = remainder > 0 ? count : -count
        // Bound a single event so a driver spike cannot jump to an extreme.
        if abs(remainder) >= 200 { remainder = 0 }
        else { remainder -= Double(result) * 40 }
        return result
    }
}
