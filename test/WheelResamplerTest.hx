package;

import clay.WheelResampler;

/**
 * Tests of `clay.WheelResampler`. Run from the clay folder:
 * `haxe test/test.hxml` (interpreter), or `haxe test/test-js.hxml && node test/out/test.js`.
 */
class WheelResamplerTest {

    static var failures:Int = 0;

    static var checks:Int = 0;

    static var seed:Float = 1;

    static function main() {

        testJitteredStreamsGetEvenSteps();
        testTotalIsPreservedAndEndIsFlushed();
        testNeverMovesBeyondReceived();
        testAlignedDeliveryGoesThroughUntouched();
        testUnevenDeliveryStartsResampling();
        testFlush();
        testPauseInsideStream();

        trace('WheelResamplerTest: ' + checks + ' checks, ' + failures + ' failed');
        #if sys
        Sys.exit(failures > 0 ? 1 : 0);
        #elseif js
        js.Syntax.code("process.exit({0})", failures > 0 ? 1 : 0);
        #end

    }

    static function check(cond:Bool, what:String) {
        checks++;
        if (!cond) {
            failures++;
            trace('FAILED: ' + what);
        }
    }

    /** Deterministic random in [0, 1) */
    static function rnd():Float {
        seed = (seed * 16807.0) % 2147483647.0;
        return (seed - 1) / 2147483646;
    }

    /**
     * A momentum stream: `n` events from `start` at `rate` per second, deltas decaying from
     * `d0`, time stamps jittered by +-`jitterMs`, delivered `0..delayMs` after their time.
     * Returns [times, arrivals, deltas].
     */
    static function stream(start:Float, rate:Float, n:Int, d0:Float, decay:Float, jitterMs:Float, delayMs:Float):Array<Array<Float>> {
        var times = [], arrivals = [], deltas = [];
        var d = d0;
        for (k in 0...n) {
            var t = start + k / rate + (rnd() * 2 - 1) * jitterMs / 1000;
            if (k > 0 && t < times[k - 1])
                t = times[k - 1];
            var a = t + rnd() * delayMs / 1000;
            if (k > 0 && a < arrivals[k - 1])
                a = arrivals[k - 1];
            times.push(t);
            arrivals.push(a);
            deltas.push(d);
            d *= decay;
        }
        return [times, arrivals, deltas];
    }

    /**
     * Runs a stream against frames at `frameRate` (phase `phase` seconds), returns the step
     * of each frame (resampled steps plus the deltas the resampler let through).
     */
    static function run(r:WheelResampler, s:Array<Array<Float>>, frameRate:Float, phase:Float, frameCount:Int):Array<Float> {
        var times = s[0], arrivals = s[1], deltas = s[2];
        var steps = [];
        var k = 0;
        var period = 1.0 / frameRate;
        for (f in 0...frameCount) {
            var frameTime = phase + f * period;
            var direct = 0.0;
            while (k < times.length && arrivals[k] <= frameTime) {
                if (!r.add(times[k], arrivals[k], 0, deltas[k]))
                    direct += deltas[k];
                k++;
            }
            r.sample(frameTime, period);
            steps.push(r.stepY + direct);
        }
        return steps;
    }

    static function sum(a:Array<Float>):Float {
        var s = 0.0;
        for (v in a)
            s += v;
        return s;
    }

    static function testJitteredStreamsGetEvenSteps() {

        // Event clocks drifting against 60 Hz frames (the stutter of Safari: frames with no
        // event and frames with two), small time stamp jitter, uneven delivery
        var directZerosTotal = 0;
        for (rate in [59.4, 59.8, 60.2, 60.6]) {
            for (phase in [0.0, 0.004, 0.009, 0.013]) {
                var r = new WheelResampler();
                r.auto = false;
                var s = stream(0.1, rate, 120, 140, 0.975, 0.5, 6);
                var steps = run(r, s, 60, phase, 200);
                var label = 'rate ' + rate + ' phase ' + phase;

                // Frames inside the stream: from the third frame with motion to the frame of
                // the last event
                var first = 0;
                while (steps[first] == 0)
                    first++;
                var lastArrival = s[1][s[1].length - 1];
                var last = Math.floor((lastArrival - phase) * 60);
                var zeros = 0;
                var maxChange = 0.0;
                for (i in first + 2...last) {
                    if (steps[i] == 0)
                        zeros++;
                    var change = Math.abs(steps[i] - steps[i - 1]) / Math.max(steps[i], steps[i - 1]);
                    if (change > maxChange)
                        maxChange = change;
                }
                check(zeros == 0, label + ': every frame inside the stream moves (' + zeros + ' frames without motion)');
                if (maxChange >= 0.25) trace(steps.slice(first, last + 3).map(v -> Math.round(v)).join(' '));
                check(maxChange < 0.25, label + ': step to step change ' + maxChange + ' < 0.25');
                check(Math.abs(sum(steps) - sum(s[2])) < 1e-9, label + ': total ' + sum(steps) + ' == ' + sum(s[2]));
                check(!r.active, label + ': stream ended');

                // The same stream delivered as it comes: frames with no event and frames with two
                var directZeros = 0;
                var k = 0;
                for (f in first + 2...last) {
                    var frameTime = phase + f / 60;
                    var n = 0;
                    while (k < s[1].length && s[1][k] <= frameTime) {
                        if (s[1][k] > frameTime - 1 / 60)
                            n++;
                        k++;
                    }
                    if (n == 0)
                        directZeros++;
                }
                directZerosTotal += directZeros;
            }
        }
        check(directZerosTotal > 0, 'the same streams delivered as they come have frames without motion (' + directZerosTotal + ')');

    }

    static function testTotalIsPreservedAndEndIsFlushed() {

        var r = new WheelResampler();
        r.auto = false;
        var s = stream(0.05, 60.3, 40, 90, 0.95, 1, 3);
        var period = 1 / 60;
        var total = 0.0;
        var k = 0;
        var frameTime = 0.0;
        var endFrame = -1;
        for (f in 0...100) {
            frameTime = f * period;
            while (k < 40 && s[1][k] <= frameTime) {
                check(r.add(s[0][k], s[1][k], 0, s[2][k]), 'resampled when auto is off');
                k++;
            }
            if (r.sample(frameTime, period))
                total += r.stepY;
            if (endFrame < 0 && k == 40 && !r.active)
                endFrame = f;
        }
        check(Math.abs(total - sum(s[2])) < 1e-9, 'total preserved: ' + total + ' == ' + sum(s[2]));
        // The stream ends at most endGap plus one frame after its last event
        var lastTime = s[0][39];
        check(endFrame >= 0 && endFrame * period <= lastTime + r.endGap + period + 1e-9, 'end of stream flushed after endGap (' + endFrame + ')');

    }

    static function testNeverMovesBeyondReceived() {

        var r = new WheelResampler();
        r.auto = false;
        var s = stream(0.1, 59.7, 80, 120, 0.97, 2, 8);
        var period = 1 / 60;
        var received = 0.0;
        var emitted = 0.0;
        var ok = true;
        var negative = false;
        var k = 0;
        for (f in 0...200) {
            var frameTime = f * period;
            while (k < 80 && s[1][k] <= frameTime) {
                r.add(s[0][k], s[1][k], 0, s[2][k]);
                received += s[2][k];
                k++;
            }
            r.sample(frameTime, period);
            emitted += r.stepY;
            if (emitted > received + 1e-9)
                ok = false;
            if (r.stepY < 0)
                negative = true;
        }
        check(ok, 'emitted never exceeds received');
        check(!negative, 'no step against the direction of the stream');

    }

    static function testAlignedDeliveryGoesThroughUntouched() {

        // Chromium: one event per frame, delivered just before the frame
        var r = new WheelResampler();
        var period = 1 / 60;
        var through = true;
        var resampledSteps = 0;
        for (f in 0...300) {
            var frameTime = f * period;
            if (f >= 10 && f < 250 && f % 120 < 100) {
                if (r.add(frameTime - 0.004, frameTime - 0.001, 0, 50))
                    through = false;
            }
            if (r.sample(frameTime, period))
                resampledSteps++;
        }
        check(through, 'aligned events go through untouched');
        check(resampledSteps == 0 && !r.resampling, 'nothing resampled for aligned delivery');

    }

    static function testUnevenDeliveryStartsResampling() {

        // Events at 59.5 Hz against 60 Hz frames: sooner or later a frame gets no event
        var r = new WheelResampler();
        var s = stream(0.1, 59.5, 200, 60, 1.0, 0, 0);
        var steps = run(r, s, 60, 0.0005, 260);
        check(r.resampling, 'uneven delivery switches to resampling');
        check(Math.abs(sum(steps) - sum(s[2])) < 1e-9, 'total preserved across the switch: ' + sum(steps));
        // After the switch every frame inside the stream moves
        var lastZero = -1;
        var first = 0;
        while (steps[first] == 0)
            first++;
        var last = Math.floor((s[1][199]) * 60);
        for (i in first...last)
            if (steps[i] == 0)
                lastZero = i;
        var zerosAfter = 0;
        for (i in lastZero + 1...last)
            if (steps[i] == 0)
                zerosAfter++;
        check(lastZero < first + 80, 'at most the detection glitch early in the stream (last zero at frame ' + lastZero + ')');
        check(zerosAfter == 0, 'no frame without motion after the switch');

        // A later stream is resampled from its start
        var s2 = stream(4.5, 59.5, 60, 60, 1.0, 0, 0);
        check(r.add(s2[0][0], s2[1][0], 0, s2[2][0]), 'next stream resampled from its first event');

    }

    static function testFlush() {

        var r = new WheelResampler();
        r.auto = false;
        r.add(0.100, 0.101, 3, 10);
        r.add(0.116, 0.117, 3, 10);
        r.sample(0.120, 1 / 60);
        var partialX = r.stepX;
        var partialY = r.stepY;
        check(r.flush(), 'flush has a remainder');
        check(Math.abs(partialX + r.stepX - 6) < 1e-9 && Math.abs(partialY + r.stepY - 20) < 1e-9, 'flush emits exactly the remainder');
        check(!r.active, 'flush ends the stream');
        check(!r.flush(), 'nothing left after flush');

    }

    static function testPauseInsideStream() {

        // A pause longer than endGap between two bursts (no frame in between): the second
        // burst does not spread over the pause
        var r = new WheelResampler();
        r.auto = false;
        var period = 1 / 60;
        r.add(0.100, 0.100, 0, 30);
        r.add(0.200, 0.200, 0, 30);
        var total = 0.0;
        for (f in 0...30) {
            var frameTime = 0.2 + f * period;
            r.sample(frameTime, period);
            total += r.stepY;
            if (f == 0)
                check(r.stepY <= 30 + 1e-9, 'the burst after the pause is not emitted with the one before (' + r.stepY + ')');
        }
        check(Math.abs(total - 60) < 1e-9, 'total after pause: ' + total);

    }

}
