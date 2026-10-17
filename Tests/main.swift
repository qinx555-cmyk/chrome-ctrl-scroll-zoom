import Foundation

// Compile with Sources/ScrollQuantizer.swift; no UI or accessibility access needed.
private var checks = 0
private var failures = 0

private func expect(_ actual: Int, _ expected: Int, _ label: String,
                    file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    guard actual != expected else { return }
    failures += 1
    fputs("FAIL \(label): got \(actual), expected \(expected) (\(file):\(line))\n", stderr)
}

private func testDiscreteWheel() {
    var q = ScrollQuantizer()
    expect(q.steps(delta: 1, continuous: false, time: 0), 1, "one upward detent")
    expect(q.steps(delta: -1, continuous: false, time: 0.01), -1, "one downward detent")
    expect(q.steps(delta: 120, continuous: false, time: 0.02), 1, "driver units do not multiply detents")
    expect(q.steps(delta: -120, continuous: false, time: 0.03), -1, "large negative detent")
    expect(q.steps(delta: 0, continuous: false, time: 0.04), 0, "zero wheel event")
}

private func testAccumulation() {
    var q = ScrollQuantizer()
    expect(q.steps(delta: 15, continuous: true, time: 0), 0, "partial smooth event")
    expect(q.steps(delta: 24, continuous: true, time: 0.1), 0, "39 points stay below threshold")
    expect(q.steps(delta: 1, continuous: true, time: 0.2), 1, "40 accumulated points advance once")
    expect(q.steps(delta: 90, continuous: true, time: 0.3), 2, "multiple smooth steps")
    expect(q.steps(delta: 30, continuous: true, time: 0.4), 1, "fractional remainder survives")

    var down = ScrollQuantizer()
    expect(down.steps(delta: -39, continuous: true, time: 0), 0, "negative partial event")
    expect(down.steps(delta: -81, continuous: true, time: 0.1), -3, "negative cumulative steps")
}

private func testDirectionAndReset() {
    var q = ScrollQuantizer()
    expect(q.steps(delta: 35, continuous: true, time: 0), 0, "prepare upward remainder")
    expect(q.steps(delta: -20, continuous: true, time: 0.1), 0, "reversal clears upward remainder")
    expect(q.steps(delta: -20, continuous: true, time: 0.2), -1, "reverse direction accumulates independently")
    expect(q.steps(delta: 30, continuous: true, time: 0.3), 0, "prepare reset remainder")
    q.reset()
    expect(q.steps(delta: 10, continuous: true, time: 0.4), 0, "explicit reset clears remainder")
    expect(q.steps(delta: 30, continuous: true, time: 0.5), 1, "accumulate after reset")
}

private func testGestureBoundaries() {
    var timed = ScrollQuantizer()
    expect(timed.steps(delta: 30, continuous: true, time: 1), 0, "prepare timeout remainder")
    expect(timed.steps(delta: 10, continuous: true, time: 1.25), 1, "exact 250 ms boundary preserves remainder")
    expect(timed.steps(delta: 30, continuous: true, time: 2), 0, "prepare next timeout remainder")
    expect(timed.steps(delta: 10, continuous: true, time: 2.251), 0, "pause over 250 ms clears remainder")
    expect(timed.steps(delta: 30, continuous: true, time: 2.3), 1, "new sequence still accumulates")

    var gesture = ScrollQuantizer()
    expect(gesture.steps(delta: 35, continuous: true, time: 0), 0, "prepare gesture remainder")
    expect(gesture.steps(delta: 5, continuous: true, time: 0.1, gestureStart: true), 0,
           "new gesture clears remainder without waiting")
    expect(gesture.steps(delta: 35, continuous: true, time: 0.2), 1, "new gesture accumulates")

    var zeroStart = ScrollQuantizer()
    expect(zeroStart.steps(delta: 35, continuous: true, time: 0), 0,
           "prepare remainder before zero-displacement gesture start")
    expect(zeroStart.steps(delta: 0, continuous: true, time: 0.1, gestureStart: true), 0,
           "zero-displacement gesture start emits no zoom")
    expect(zeroStart.steps(delta: 5, continuous: true, time: 0.11), 0,
           "zero-displacement gesture start clears old remainder")
    expect(zeroStart.steps(delta: 35, continuous: true, time: 0.12), 1,
           "new gesture accumulates after zero-displacement start")

    var clock = ScrollQuantizer()
    expect(clock.steps(delta: 35, continuous: true, time: 10), 0, "prepare backward-clock remainder")
    expect(clock.steps(delta: 5, continuous: true, time: 9), 0, "backward clock clears remainder")
    expect(clock.steps(delta: 35, continuous: true, time: 9.1), 1, "accumulate after backward clock")
}

private func testDeviceModeSwitch() {
    var q = ScrollQuantizer()
    expect(q.steps(delta: 35, continuous: true, time: 0), 0, "smooth device remainder")
    expect(q.steps(delta: 1, continuous: false, time: 0.1), 1, "discrete device responds immediately")
    expect(q.steps(delta: 5, continuous: true, time: 0.2), 0, "return to smooth device discards old remainder")
    expect(q.steps(delta: 35, continuous: true, time: 0.3), 1, "new smooth sequence accumulates")
}

private func testSpikes() {
    var q = ScrollQuantizer()
    expect(q.steps(delta: 200, continuous: true, time: 0), 4, "spike is capped at four steps")
    expect(q.steps(delta: 1, continuous: true, time: 0.1), 0, "spike leaves no backlog")
    expect(q.steps(delta: -Double.greatestFiniteMagnitude, continuous: true, time: 0.2), -4,
           "largest finite negative input is bounded")
    expect(q.steps(delta: -1, continuous: true, time: 0.3), 0, "large negative input leaves no backlog")
    expect(q.steps(delta: Double.greatestFiniteMagnitude, continuous: true, time: 0.4), 4,
           "largest finite positive input is bounded")
    expect(q.steps(delta: 40, continuous: true, time: 0.5), 1, "normal input works after spike")

    var nearLimit = ScrollQuantizer()
    expect(nearLimit.steps(delta: 199, continuous: true, time: 0), 4, "sub-spike event is bounded")
    expect(nearLimit.steps(delta: 1, continuous: true, time: 0.1), 1,
           "sub-spike event preserves useful remainder")
}

private func testInvalidInputs() {
    var q = ScrollQuantizer()
    expect(q.steps(delta: 30, continuous: true, time: 1), 0, "prepare invalid-input remainder")
    expect(q.steps(delta: .nan, continuous: true, time: 1.01), 0, "NaN delta is ignored")
    expect(q.steps(delta: .infinity, continuous: true, time: 1.02), 0, "infinite delta is ignored")
    expect(q.steps(delta: -.infinity, continuous: true, time: 1.03), 0, "negative infinite delta is ignored")
    expect(q.steps(delta: 10, continuous: true, time: .nan), 0, "NaN timestamp is ignored")
    expect(q.steps(delta: 10, continuous: true, time: .infinity), 0, "infinite timestamp is ignored")
    expect(q.steps(delta: 0, continuous: true, time: 1.04), 0, "zero delta is ignored")
    expect(q.steps(delta: 10, continuous: true, time: 1.1), 1,
           "invalid inputs do not poison valid accumulation")
}

testDiscreteWheel()
testAccumulation()
testDirectionAndReset()
testGestureBoundaries()
testDeviceModeSwitch()
testSpikes()
testInvalidInputs()

if failures > 0 {
    fputs("\(failures) of \(checks) checks failed.\n", stderr)
    exit(1)
}
print("PASS: \(checks) scroll quantizer behavior checks")
