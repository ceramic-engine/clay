package;

import clay.DrawableWaitGate;
import clay.FramePacer;

/**
 * Tests of `clay.FramePacer` and `clay.DrawableWaitGate`. Run from the clay folder:
 * `haxe test/test-pacer.hxml` (interpreter), or
 * `haxe test/test-pacer-js.hxml && node test/out/test-pacer.js`.
 *
 * `Sim` is a model of a display and of the native loop: vsyncs every `period`, two
 * drawables (a drawable comes back at the vsync that shows the frame presented before),
 * a compositor that needs `lead` seconds before the vsync, returns that are a little late.
 */
class FramePacerTest {

    static var failures:Int = 0;

    static var checks:Int = 0;

    static inline var P60:Float = 1.0 / 60;

    static inline var P120:Float = 1.0 / 120;

    static function main() {

        testLockAndPeriod();
        testLateReturnsIgnored();
        testPeriodFollowsDisplay();
        testNoPacingWhenWaitDidNotBlock();
        testNoPacingAfterIdle();
        testPacingEngagesWhenMarginFits();
        testMarginGrowth();
        testWindowSetting();
        testPacedMissesWidenThenSwitchOff();
        testLongFrameMissBringsNoPenalty();
        testSingleLongFrame();
        testPeriodicLongFrame();
        testLoadingThenFast();
        testGateDropAndResume();
        testGateIsolatedSlowFrame();
        testGateSlowFrameRestartsFastRun();
        testGateBackoff();
        testGateBlockingCheck();
        testOverBudgetFallbackFrameRate();
        testRecordedLight();
        testRecordedHeavy();

        trace('FramePacerTest: ' + checks + ' checks, ' + failures + ' failed');
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

    static function near(a:Float, b:Float, tolerance:Float):Bool {
        return Math.abs(a - b) <= tolerance;
    }

    static function ms(v:Float):String {
        return Std.string(Math.round(v * 100000) / 100) + ' ms';
    }

/// Pacer alone, synthetic returns

    /** Feeds `count` returns one period apart, each wait having blocked, each frame taking `work`. */
    static function feed(pacer:FramePacer, start:Float, period:Float, count:Int, work:Float, ?late:(i:Int) -> Float):Float {
        var until = 0.0;
        for (i in 0...count) {
            var t = start + i * period + (late != null ? late(i) : 0);
            until = pacer.acquired(t - 0.010, t);
            pacer.frameDone(work, t + work);
        }
        return until;
    }

    static function testLockAndPeriod() {

        var pacer = new FramePacer();
        check(pacer.acquired(0.990, 1.0) == 0, 'first return is not paced');
        pacer.frameDone(0.001, 1.001);
        var firstPaced = -1;
        for (i in 1...40) {
            var t = 1.0 + i * P60;
            var until = pacer.acquired(t - 0.010, t);
            pacer.frameDone(0.001, t + 0.001);
            if (until > 0 && firstPaced < 0) firstPaced = i;
            if (i < FramePacer.PERIOD_MIN_SAMPLES) check(until == 0 && pacer.period == 0, 'no period before ' + FramePacer.PERIOD_MIN_SAMPLES + ' intervals');
        }
        check(near(pacer.period, P60, 0.00001), 'period is the interval of the returns: ' + ms(pacer.period));
        // 9 intervals for the period (the ninth return sets the phase), then 5 consistent returns
        check(firstPaced == FramePacer.PERIOD_MIN_SAMPLES + FramePacer.LOCK_RETURNS, 'paced once locked, at return ' + firstPaced);
        var t = 1.0 + 40 * P60;
        var until = pacer.acquired(t - 0.010, t);
        check(near(until, t + P60 - (0.004 + 2.0 * 0.001), 0.00002), 'sleeps until next vsync minus floor + multiple x work: ' + ms(t + P60 - until));
        check(near(pacer.margin, 0.006, 0.00001), 'margin 6 ms: ' + ms(pacer.margin));

    }

    static function testLateReturnsIgnored() {

        var pacer = new FramePacer();
        // Returns late by 0 to 0.3 ms, one in ten by up to 1 ms (they are never early)
        var seed = 11.0;
        var late = (i:Int) -> {
            seed = (seed * 16807) % 2147483647;
            var r = seed / 2147483647;
            return r < 0.9 ? r * 0.00033 : 0.0003 + (r - 0.9) * 0.007;
        };
        feed(pacer, 1.0, P60, 200, 0.001, late);
        var t = 1.0 + 200 * P60 + 0.001;
        var until = pacer.acquired(t - 0.010, t);
        var vsync = 1.0 + 201 * P60;
        // The target is placed from the true vsync, not from the late return
        check(near(until, vsync - 0.006, 0.0005), 'a late return does not move the phase: off by ' + ms(until - (vsync - 0.006)));
        check(pacer.misses == 0, 'no miss with late returns');
        check(near(pacer.period, P60, 0.0003), 'period with late returns: ' + ms(pacer.period));

    }

    static function testPeriodFollowsDisplay() {

        var pacer = new FramePacer();
        feed(pacer, 1.0, P60, 100, 0.001);
        check(near(pacer.period, P60, 0.00001), '60 Hz first');
        // The display switches to 120 Hz
        var start = 1.0 + 100 * P60;
        feed(pacer, start, P120, 100, 0.001);
        check(near(pacer.period, P120, 0.00001), 'then 120 Hz: ' + ms(pacer.period));
        var t = start + 100 * P120;
        check(pacer.acquired(t - 0.005, t) > 0, 'paced at 120 Hz');

    }

    static function testNoPacingWhenWaitDidNotBlock() {

        var pacer = new FramePacer();
        feed(pacer, 1.0, P60, 60, 0.001);
        var t = 1.0 + 60 * P60;
        check(pacer.acquired(t - 0.0001, t) == 0, 'a wait that returned at once gives no vsync signal');
        check(pacer.locked == 0, 'and breaks the lock');
        var unpaced = 0;
        for (i in 1...10) {
            var u = t + i * P60;
            if (pacer.acquired(u - 0.010, u) == 0) unpaced++;
        }
        check(unpaced == FramePacer.LOCK_RETURNS, 'paced again after ' + FramePacer.LOCK_RETURNS + ' consistent returns, not ' + unpaced);

    }

    static function testNoPacingAfterIdle() {

        var pacer = new FramePacer();
        feed(pacer, 1.0, P60, 60, 0.001);
        pacer.interrupt();
        // The loop was idle for a while, at no particular phase
        var t = 1.0 + 60 * P60 + 0.7301;
        var unpaced = 0;
        for (i in 0...12) {
            var u = t + i * P60;
            if (pacer.acquired(u - 0.010, u) == 0) unpaced++;
            pacer.frameDone(0.001, u + 0.001);
        }
        check(unpaced == FramePacer.LOCK_RETURNS, 'frames after idle are not paced until locked: ' + unpaced);
        check(pacer.misses == 0, 'the idle gap is not a miss');
        check(near(pacer.period, P60, 0.00001), 'the period survives idle');

    }

    static function pacedShare(period:Float, work:Float, multiple:Float = 2.0):Float {
        var pacer = new FramePacer();
        pacer.multiple = multiple;
        pacer.nominalPeriod = period;
        feed(pacer, 1.0, period, 200, work);
        return pacer.pacedFrames / 200;
    }

    static function testPacingEngagesWhenMarginFits() {

        // floor 4 ms + 2.0 x work must fit in the period
        check(pacedShare(P60, 0.005) > 0.9, '60 Hz: paced with 5 ms frames (4 + 10 <= 16.7)');
        check(pacedShare(P60, 0.007) == 0, '60 Hz: not paced with 7 ms frames (4 + 14 > 16.7)');
        check(pacedShare(P60, 0.0063) > 0.9, '60 Hz: paced with 6.3 ms frames');
        check(pacedShare(P60, 0.0064) == 0, '60 Hz: not paced with 6.4 ms frames');
        check(pacedShare(P120, 0.002) > 0.9, '120 Hz: paced with 2 ms frames (4 + 4 <= 8.3)');
        check(pacedShare(P120, 0.0025) == 0, '120 Hz: not paced with 2.5 ms frames (4 + 5 > 8.3)');
        check(pacedShare(P60, 0.007, 1.5) > 0.9, 'the multiple applies: 7 ms frames paced at 1.5');

    }

    static function testMarginGrowth() {

        var pacer = new FramePacer();
        feed(pacer, 1.0, P60, 100, 0.001);
        check(near(pacer.margin, 0.006, 0.00001), 'margin 4 + 2 x 1 ms');
        check(pacer.effectiveWindow == 8, 'the window starts at its minimum: ' + pacer.effectiveWindow);
        // One slower frame (within the deadline): up at once
        var t = 1.0 + 100 * P60;
        pacer.acquired(t - 0.010, t);
        pacer.frameDone(0.003, t + 0.003);
        t += P60;
        pacer.acquired(t - 0.010, t);
        pacer.frameDone(0.001, t + 0.001);
        check(near(pacer.margin, 0.010, 0.00001), 'margin up at once: ' + ms(pacer.margin));
        // It stays while the frame is in the window (8 frames)
        feed(pacer, t + P60, P60, 6, 0.001);
        check(near(pacer.margin, 0.010, 0.00001), 'margin kept over the window: ' + ms(pacer.margin));
        // Then down slowly
        feed(pacer, t + 7 * P60, P60, 20, 0.001);
        check(pacer.margin < 0.010 && pacer.margin > 0.008, 'margin goes down slowly: ' + ms(pacer.margin));
        feed(pacer, t + 27 * P60, P60, 400, 0.001);
        check(near(pacer.margin, 0.006, 0.0001), 'margin back: ' + ms(pacer.margin));
        check(pacer.effectiveWindow == 8, 'a slower frame within the deadline does not grow the window');

    }

    static function testWindowSetting() {

        var pacer = new FramePacer();
        pacer.minWindow = 30;
        feed(pacer, 1.0, P60, 100, 0.001);
        var t = 1.0 + 100 * P60;
        pacer.acquired(t - 0.010, t);
        pacer.frameDone(0.003, t + 0.003);
        feed(pacer, t + P60, P60, 25, 0.001);
        check(near(pacer.margin, 0.010, 0.00001), 'minWindow 30: kept for 30 frames');
        feed(pacer, t + 26 * P60, P60, 10, 0.001);
        check(pacer.margin < 0.010, 'minWindow 30: going down after 30 frames');

        // The window never exceeds `window`
        var small = new FramePacer();
        small.window = 4;
        check(small.effectiveWindow == 4, 'window below minWindow: ' + small.effectiveWindow);

    }

/// Model of the display and of the loop

    static function testPacedMissesWidenThenSwitchOff() {

        // The compositor needs 4.5 ms, more than the floor covers with a tiny frame: paced frames miss
        var sim = new Sim(P60);
        sim.lead = 0.0045;
        sim.pacer.floor = 0.003;
        sim.run(40, (_) -> 0.0002);
        check(sim.pacer.pacedMisses >= 1, 'a paced frame missed its vsync');
        check(near(sim.pacer.margin, 0.003 + FramePacer.MISS_WIDEN + 2 * 0.0002, 0.0002) || sim.pacer.offUntil > 0, 'margin widened by 2 ms after the miss: ' + ms(sim.pacer.margin));
        // Wider is enough here (5.4 ms > 4.5 ms): no further miss, pacing goes on
        var before = sim.pacer.pacedMisses;
        var paced = sim.pacer.pacedFrames;
        sim.run(120, (_) -> 0.0002);
        check(sim.pacer.pacedMisses == before, 'no more miss with the wider margin');
        check(sim.pacer.pacedFrames - paced > 100, 'still paced');

        // A lead no widening covers: 3 paced misses within 2 s switch pacing off for 10 s
        var bad = new Sim(P60);
        bad.lead = 0.009;
        bad.pacer.floor = 0.003;
        bad.run(200, (_) -> 0.0002);
        check(bad.pacer.pacedMisses == FramePacer.MISS_LIMIT, 'three paced misses: ' + bad.pacer.pacedMisses);
        check(bad.pacer.offUntil > 0, 'pacing switched off');
        var missesAtOff = bad.pacer.misses;
        var pacedAtOff = bad.pacer.pacedFrames;
        bad.run(400, (_) -> 0.0002);
        check(bad.pacer.pacedFrames == pacedAtOff, 'not paced while off');
        check(bad.pacer.misses == missesAtOff, 'no miss streak persists: ' + (bad.pacer.misses - missesAtOff));
        bad.run(400, (_) -> 0.0002);
        check(bad.pacer.pacedFrames > pacedAtOff, 'pacing tried again after 10 s');

    }

    static function testLongFrameMissBringsNoPenalty() {

        var sim = new Sim(P60);
        sim.run(200, (_) -> 0.002);
        var margin = sim.pacer.margin;
        // Long frames now and then, far enough apart to leave the window in between
        sim.run(1000, (i) -> i % 250 == 100 ? 0.030 : 0.002);
        check(sim.pacer.pacedMisses == 0, 'a long frame is never a paced miss');
        check(sim.pacer.offUntil == 0, 'pacing never switched off');
        sim.run(200, (_) -> 0.002);
        check(near(sim.pacer.margin, margin, 0.00001), 'margin not widened: ' + ms(sim.pacer.margin));

        // Two periods between two returns, after a paced frame
        for (longFrame in [true, false]) {
            var pacer = new FramePacer();
            pacer.nominalPeriod = P60;
            feed(pacer, 1.0, P60, 60, 0.001);
            var t = 1.0 + 60 * P60;
            check(pacer.acquired(t - 0.010, t) > 0, 'paced frame');
            pacer.frameDone(longFrame ? 0.020 : 0.001, t + 0.021);
            t += 2 * P60;
            check(pacer.acquired(t - 0.010, t) == 0, 'no pacing right after a miss');
            pacer.frameDone(0.001, t + 0.001);
            check(pacer.misses == 1, 'two periods between two returns is a miss');
            check(pacer.pacedMisses == (longFrame ? 0 : 1), longFrame ? 'a long frame: not a paced miss' : 'work within the deadline: a paced miss');
            var paced = 0;
            for (i in 1...FramePacer.LOCK_RETURNS + 1) {
                if (pacer.acquired(t + i * P60 - 0.010, t + i * P60) > 0) paced++;
                pacer.frameDone(0.001, t + i * P60 + 0.001);
            }
            if (longFrame) {
                // The long frame is in the window: counted as one period, no pacing
                check(paced == 0 && near(pacer.worstWork, P60, 0.0001), 'the long frame counts as one period: ' + ms(pacer.worstWork));
            }
            else {
                check(paced == 1, 'paced again at the fifth consistent return');
                check(near(pacer.margin, 0.006 + FramePacer.MISS_WIDEN, 0.00001), 'margin widened by 2 ms: ' + ms(pacer.margin));
                feed(pacer, t + 6 * P60, P60, 320, 0.001);
                check(near(pacer.margin, 0.006, 0.00001), 'for 5 s: ' + ms(pacer.margin));
            }
        }

    }



    static function testSingleLongFrame() {

        var sim = new Sim(P60);
        sim.run(300, (_) -> 0.002);
        var margin = sim.pacer.margin;
        check(sim.lastPaced, 'paced before the long frame');
        sim.run(1, (_) -> 0.030);
        var frames = 0;
        var back = -1;
        var waitFirstLost = false;
        while (frames < 400) {
            sim.run(1, (_) -> 0.002);
            frames++;
            if (!sim.gate.waitFirst) waitFirstLost = true;
            if (sim.lastPaced && back < 0) back = frames;
        }
        check(!waitFirstLost && sim.gate.drops == 0, 'wait first kept through one long frame');
        check(sim.pacer.pacedMisses == 0 && sim.pacer.offUntil == 0, 'no penalty');
        check(near(sim.pacer.margin, margin, 0.00001), 'margin as before once back: ' + ms(sim.pacer.margin));
        check(sim.pacer.effectiveWindow == 8, 'the window stays at its minimum: ' + sim.pacer.effectiveWindow);
        // Off while the long frame is in the window (8 frames), engaged again right after
        check(back > 0 && back <= 8 + FramePacer.LOCK_RETURNS, 'pacing back after ' + back + ' frames');
        trace('single 30 ms frame in 2 ms frames: wait first never lost (0 frames), pacing back after ' + back + ' frames');

    }

    static function testPeriodicLongFrame() {

        var sim = new Sim(P60);
        sim.run(300, (_) -> 0.002);
        var paced = 0;
        var waitFirstFrames = 0;
        var windows:Array<Int> = [];
        var engaged = 0;
        var wasPaced = true;
        var pacedLate = 0;
        // A 30 ms frame every 30 frames, for 20 seconds
        for (i in 0...1200) {
            var long = i % 30 == 0;
            sim.run(1, (_) -> long ? 0.030 : 0.002);
            if (sim.lastWaitedFirst) waitFirstFrames++;
            if (sim.lastPaced) {
                paced++;
                if (i >= 120) pacedLate++;
                if (!wasPaced) engaged++;
            }
            wasPaced = sim.lastPaced;
            var w = sim.pacer.effectiveWindow;
            if (windows.length == 0 || windows[windows.length - 1] != w) windows.push(w);
        }
        check(windows.join(',') == '8,16,32', 'the window grows until pacing stops being tried: ' + windows.join(','));
        check(pacedLate == 0, 'pacing settles off, no oscillation: ' + pacedLate + ' paced frames after the first 2 s');
        check(engaged <= 3, 'pacing engaged again ' + engaged + ' times in all');
        check(sim.gate.drops == 0 && waitFirstFrames == 1200, 'wait first stays on: ' + waitFirstFrames + ' / 1200');
        check(sim.pacer.pacedMisses == 0 && sim.pacer.offUntil == 0, 'no penalty accumulates');
        trace('30 ms frame every 30 frames: window ' + windows.join(' > ') + ', paced ' + paced + ' / 1200 frames (none after the first 2 s), wait first on 1200 / 1200');

        // The long frames stop: pacing is back after the window, and the window halves every 5 s
        var back = -1;
        var atMinimum = -1;
        for (i in 0...900) {
            sim.run(1, (_) -> 0.002);
            if (sim.lastPaced && back < 0) back = i + 1;
            if (sim.pacer.effectiveWindow == 8 && atMinimum < 0) atMinimum = i + 1;
        }
        check(back > 0 && back <= 32 + FramePacer.LOCK_RETURNS, 'pacing back ' + back + ' frames after the long frames stopped');
        check(atMinimum > 500 && atMinimum <= 620, 'window back to 8 after two calm periods of 5 s: ' + atMinimum + ' frames');
        check(sim.lastPaced && near(sim.pacer.margin, 0.008, 0.0001), 'pacing at its best again: margin ' + ms(sim.pacer.margin));
        trace('then 2 ms frames only: pacing back after ' + back + ' frames, window back to 8 after ' + atMinimum + ' frames');

    }

    static function testLoadingThenFast() {

        var sim = new Sim(P60);
        sim.run(300, (_) -> 0.002);
        var droppedAt = -1;
        for (i in 0...40) {
            sim.run(1, (_) -> 0.100);
            if (!sim.gate.waitFirst && droppedAt < 0) droppedAt = i + 1;
        }
        check(droppedAt == 3, 'loading: wait first dropped at the third long frame: ' + droppedAt);
        var waitFirstBack = -1;
        var pacingBack = -1;
        for (i in 0...400) {
            sim.run(1, (_) -> 0.002);
            if (sim.lastWaitedFirst && waitFirstBack < 0) waitFirstBack = i + 1;
            if (sim.lastPaced && pacingBack < 0) pacingBack = i + 1;
        }
        // 8 fast frames resume it, the frame after is the first to wait first
        check(waitFirstBack == 9, 'loading: wait first back after ' + waitFirstBack + ' frames');
        check(sim.gate.backoff == 0, 'loading: no backoff');
        // Pacing: the long frames are out of its window by then, it needs its lock
        check(pacingBack > waitFirstBack && pacingBack <= waitFirstBack + 8 + FramePacer.LOCK_RETURNS, 'loading: pacing back after ' + pacingBack + ' frames');
        check(sim.pacer.pacedMisses == 0 && sim.pacer.offUntil == 0, 'loading: no penalty');
        check(sim.pacer.effectiveWindow == 8, 'loading: the window stays at its minimum: ' + sim.pacer.effectiveWindow);
        trace('loading (40 frames of 100 ms) then 2 ms frames: wait first back after ' + waitFirstBack + ' frames, pacing back after ' + pacingBack + ' frames');

    }

/// Gate alone

    /** Feeds frames of `work` to a gate, one period apart. Returns the time after. */
    static function gateFeed(gate:DrawableWaitGate, now:Float, period:Float, floor:Float, count:Int, work:Float):Float {
        for (i in 0...count) {
            now += Math.max(period, work);
            gate.frameDone(work, period - floor, period, now);
        }
        return now;
    }

    static function gateCase(period:Float, slow:Float, fine:Float, label:String) {

        var floor = 0.004;
        var gate = new DrawableWaitGate();
        var now = gateFeed(gate, 1.0, period, floor, 2, slow);
        check(gate.waitFirst, label + ': two slow frames do not drop');
        now = gateFeed(gate, now, period, floor, 1, slow);
        check(!gate.waitFirst, label + ': three ' + ms(slow) + ' frames in a row drop');
        now = gateFeed(gate, now, period, floor, 7, fine);
        check(!gate.waitFirst, label + ': seven fast frames do not resume');
        now = gateFeed(gate, now, period, floor, 1, fine);
        check(gate.waitFirst, label + ': eight frames of ' + ms(fine) + ' resume');

        var steady = new DrawableWaitGate();
        gateFeed(steady, 1.0, period, floor, 2000, fine);
        check(steady.waitFirst && steady.drops == 0, label + ': ' + ms(fine) + ' frames never drop');

    }

    static function testGateDropAndResume() {

        // Deadline = period - floor: 12.67 ms at 60 Hz, 4.33 ms at 120 Hz
        gateCase(P60, 0.013, 0.012, '60 Hz');
        gateCase(P60, 0.0127, 0.0126, '60 Hz, at the deadline');
        gateCase(P120, 0.005, 0.004, '120 Hz');
        gateCase(P120, 0.0044, 0.0043, '120 Hz, at the deadline');

        var gate = new DrawableWaitGate();
        gate.slowFrames = 5;
        gate.fastFrames = 2;
        var now = gateFeed(gate, 1.0, P60, 0.004, 4, 0.020);
        check(gate.waitFirst, 'slowFrames setting: 4 of 5');
        now = gateFeed(gate, now, P60, 0.004, 1, 0.020);
        check(!gate.waitFirst, 'slowFrames setting: 5 of 5');
        now = gateFeed(gate, now, P60, 0.004, 2, 0.001);
        check(gate.waitFirst, 'fastFrames setting: 2');

    }

    static function testGateIsolatedSlowFrame() {

        var gate = new DrawableWaitGate();
        var now = 1.0;
        for (i in 0...50) {
            now = gateFeed(gate, now, P60, 0.004, 20, 0.002);
            now = gateFeed(gate, now, P60, 0.004, 2, 0.050);
        }
        check(gate.waitFirst && gate.drops == 0, 'one or two slow frames in a row never drop');

    }

    static function testGateSlowFrameRestartsFastRun() {

        var gate = new DrawableWaitGate();
        var now = gateFeed(gate, 1.0, P60, 0.004, 3, 0.020);
        check(!gate.waitFirst, 'dropped');
        now = gateFeed(gate, now, P60, 0.004, 7, 0.002);
        now = gateFeed(gate, now, P60, 0.004, 1, 0.020);
        now = gateFeed(gate, now, P60, 0.004, 7, 0.002);
        check(!gate.waitFirst, 'a slow frame during the fast run restarts the count');
        now = gateFeed(gate, now, P60, 0.004, 1, 0.002);
        check(gate.waitFirst, 'resumed after 8 in a row');

    }

    static function testGateBackoff() {

        var gate = new DrawableWaitGate();
        var now = 1.0;
        var runs:Array<Int> = [];
        // An app at the limit of its budget: slow as soon as it waits first again
        for (cycle in 0...8) {
            now = gateFeed(gate, now, P60, 0.004, 3, 0.020);
            check(!gate.waitFirst, 'cycle ' + cycle + ': dropped');
            var run = 0;
            while (!gate.waitFirst && run < 1000) {
                now = gateFeed(gate, now, P60, 0.004, 1, 0.002);
                run++;
            }
            runs.push(run);
        }
        check(runs.join(',') == '8,16,32,64,120,120,120,120', 'the run needed doubles up to 2 s of frames: ' + runs.join(','));

        // Calm: it halves every 5 s without a drop (2 s went by in the last resume)
        now = gateFeed(gate, now, P60, 0.004, 170, 0.002);
        check(gate.requiredRun(P60) == 120, 'still at the cap before 5 s: ' + gate.requiredRun(P60));
        now = gateFeed(gate, now, P60, 0.004, 20, 0.002);
        check(gate.requiredRun(P60) == 64, 'halved after 5 s: ' + gate.requiredRun(P60));
        now = gateFeed(gate, now, P60, 0.004, 4 * 300 + 10, 0.002);
        check(gate.requiredRun(P60) == 8 && gate.backoff == 0, 'back to 8 after a calm period: ' + gate.requiredRun(P60));

        // The cap is in seconds: twice as many frames at 120 Hz
        var fast = new DrawableWaitGate();
        now = 1.0;
        for (cycle in 0...8) {
            now = gateFeed(fast, now, P120, 0.004, 3, 0.010);
            while (!fast.waitFirst) now = gateFeed(fast, now, P120, 0.004, 1, 0.001);
        }
        check(fast.requiredRun(P120) == 240, 'the cap is in seconds: 240 frames at 120 Hz: ' + fast.requiredRun(P120));

        // A drop long after a resume is not flapping
        var calm = new DrawableWaitGate();
        now = gateFeed(calm, 1.0, P60, 0.004, 3, 0.020);
        now = gateFeed(calm, now, P60, 0.004, 100, 0.002);
        now = gateFeed(calm, now, P60, 0.004, 3, 0.020);
        check(!calm.waitFirst && calm.backoff == 0, 'a drop more than 1 s after the resume does not double');

        // backoffCap setting
        var capped = new DrawableWaitGate();
        capped.backoffCap = 0.5;
        now = 1.0;
        for (cycle in 0...6) {
            now = gateFeed(capped, now, P60, 0.004, 3, 0.020);
            while (!capped.waitFirst) now = gateFeed(capped, now, P60, 0.004, 1, 0.002);
        }
        check(capped.requiredRun(P60) == 30, 'backoffCap 0.5 s: 30 frames at 60 Hz: ' + capped.requiredRun(P60));

    }

    static function testGateBlockingCheck() {

        var gate = new DrawableWaitGate();
        for (i in 0...119) gate.waitDone(false, true);
        check(!gate.disabled, 'not judged before 120 frames');
        gate.waitDone(false, true);
        check(gate.disabled && !gate.active, 'a wait that never blocks switches wait first off for the session');

        var fine = new DrawableWaitGate();
        for (i in 0...1200) fine.waitDone(i % 50 != 0, true);
        check(!fine.disabled, 'a wait that blocks keeps it on');

        var hidden = new DrawableWaitGate();
        for (i in 0...1200) hidden.waitDone(false, false);
        check(!hidden.disabled, 'waits that were not expected to block are not counted');

        var slow = new DrawableWaitGate();
        var now = 1.0;
        for (i in 0...600) {
            // Two slow frames then a fast one, for ever: never dropped, and the waits after a slow frame do not block
            var work = i % 3 == 2 ? 0.002 : 0.030;
            now += 0.034;
            slow.frameDone(work, P60 - 0.004, P60, now);
            slow.waitDone(i % 3 == 2, true);
        }
        check(!slow.disabled, 'waits after a slow frame are not counted');

    }

    static function testOverBudgetFallbackFrameRate() {

        // 20 ms of work per frame at 60 Hz (measured: 29.9 fps waiting first, 49.7 without)
        var sim = new Sim(P60);
        sim.run(100, (_) -> 0.002);
        var t0 = sim.now;
        sim.run(500, (_) -> 0.020);
        var fps = 500 / (sim.now - t0);
        check(sim.gate.drops == 1 && !sim.gate.waitFirst, 'over budget: wait first dropped once and for all');
        check(fps > 48, 'over budget: the loop runs at the rate of the work, not at 30 fps: ' + Math.round(fps * 10) / 10);

        var forced = new Sim(P60);
        forced.gate.slowFrames = 1000000;
        forced.run(100, (_) -> 0.002);
        t0 = forced.now;
        forced.run(500, (_) -> 0.020);
        var forcedFps = 500 / (forced.now - t0);
        check(near(forcedFps, 30, 0.5), 'the model shows the 30 fps without the fallback: ' + Math.round(forcedFps * 10) / 10);
        trace('20 ms frames at 60 Hz: ' + Math.round(fps * 10) / 10 + ' fps with the fallback, ' + Math.round(forcedFps * 10) / 10 + ' without');

    }

/// Recorded returns

    static function testRecordedLight() {

        var frames = FramePacerRecorded.LIGHT_FRAMES;
        var returns = FramePacerRecorded.LIGHT_RETURNS;
        var works = FramePacerRecorded.LIGHT_WORKS;
        var pacer = new FramePacer();
        pacer.nominalPeriod = P60;
        var real = 0;
        var paced = 0;
        var safe = 0;
        var judged = 0;
        var worstLead = 1.0;
        for (i in 0...frames.length) {
            if (i > 0) {
                // The recording has gaps (8 frames logged after each key): the frames in
                // between are placed evenly, the recorded ones keep their real times
                var gap = frames[i] - frames[i - 1];
                for (k in 1...gap) {
                    var t = returns[i - 1] + (returns[i] - returns[i - 1]) * k / gap;
                    pacer.acquired(t - 0.010, t);
                    pacer.frameDone(0.0005, t + 0.0005);
                }
            }
            var contiguous = i > 0 && frames[i] == frames[i - 1] + 1;
            var waitStart = contiguous ? returns[i - 1] + works[i - 1] : returns[i] - 0.010;
            var until = pacer.acquired(waitStart, returns[i]);
            pacer.frameDone(works[i], returns[i] + works[i]);
            real++;
            if (until > 0) {
                paced++;
                if (i + 1 < frames.length && frames[i + 1] == frames[i] + 1) {
                    // Where the real next return came, against the time the pacer would have slept until
                    judged++;
                    var lead = returns[i + 1] - until;
                    if (lead < worstLead) worstLead = lead;
                    if (lead >= pacer.margin - 0.0005) safe++;
                }
            }
        }
        check(near(pacer.period, P60, 0.0001), 'recorded: period ' + ms(pacer.period));
        check(paced > 0.75 * real, 'recorded: locked and paced on most frames: ' + paced + ' / ' + real);
        check(safe >= 0.98 * judged, 'recorded: the next return is a margin after the target: ' + safe + ' / ' + judged);
        check(worstLead > 0.003, 'recorded: worst lead ' + ms(worstLead));
        check(pacer.pacedMisses == 0, 'recorded: no paced miss (the recording was not paced)');
        trace('recorded light frames: period ' + ms(pacer.period) + ', paced ' + paced + ' / ' + real + ', margin ' + ms(pacer.margin) + ', worst lead ' + ms(worstLead) + ', misses seen ' + pacer.misses);

    }

    static function testRecordedHeavy() {

        // Every frame takes 20 ms: the returns are 33 ms apart (half the display rate)
        var frames = FramePacerRecorded.HEAVY_FRAMES;
        var returns = FramePacerRecorded.HEAVY_RETURNS;
        var works = FramePacerRecorded.HEAVY_WORKS;
        var pacer = new FramePacer();
        pacer.nominalPeriod = P60;
        var gate = new DrawableWaitGate();
        var droppedAt = -1;
        var paced = 0;
        for (i in 0...frames.length) {
            var waitStart = i > 0 ? returns[i - 1] + works[i - 1] : returns[i] - 0.010;
            if (pacer.acquired(waitStart, returns[i]) > 0) paced++;
            pacer.frameDone(works[i], returns[i] + works[i]);
            gate.frameDone(works[i], pacer.deadline(P60), pacer.period > 0 ? pacer.period : P60, returns[i] + works[i]);
            if (!gate.waitFirst && droppedAt < 0) droppedAt = i + 1;
        }
        check(droppedAt == 3, 'recorded heavy: wait first dropped at frame ' + droppedAt);
        check(paced == 0, 'recorded heavy: never paced');
        check(pacer.period == 0, 'recorded heavy: half rate is not read as a 30 Hz display: ' + ms(pacer.period));

    }

}

/**
 * Model of a display with two drawables and of the native loop that waits for its drawable
 * first, as `clay.sdl.SDLRuntime` drives `FramePacer` and `DrawableWaitGate`.
 */
class Sim {

    public var period:Float;

    /** Time the compositor needs before a vsync to show a frame at that vsync. */
    public var lead:Float = 0.002;

    public var pacer = new FramePacer();

    public var gate = new DrawableWaitGate();

    public var now:Float = 1.0;

    /** The last frame slept for its pacing. */
    public var lastPaced:Bool = false;

    /** The last frame waited for its drawable first. */
    public var lastWaitedFirst:Bool = false;

    /** Vsync at which the frame presented last is shown: its drawable is free again then. */
    var shownAt:Float = 0;

    var frame:Int = 0;

    var seed:Float = 7;

    public function new(period:Float) {
        this.period = period;
        pacer.nominalPeriod = period;
    }

    function random():Float {
        seed = (seed * 16807) % 2147483647;
        return seed / 2147483647;
    }

    /** Lateness of a return: 0 to 0.3 ms, now and then up to 1 ms. Never early. */
    function late():Float {
        var r = random();
        return r < 0.95 ? r * 0.0003 : 0.0003 + (r - 0.95) * 0.014;
    }

    function waitDrawable():Void {
        if (now < shownAt) now = shownAt + late();
    }

    public function run(count:Int, work:(i:Int) -> Float):Void {

        for (i in 0...count) {
            var w = work(frame++);
            lastPaced = false;
            lastWaitedFirst = false;
            if (gate.active) {
                lastWaitedFirst = true;
                var start = now;
                waitDrawable();
                gate.waitDone(now - start > FramePacer.BLOCKED_WAIT, true);
                var until = pacer.acquired(start, now);
                if (until > now) {
                    // The sleep overshoots a little
                    now = until + 0.00005;
                    lastPaced = true;
                }
                now += w;
            }
            else {
                pacer.interrupt();
                // The wait lands in the first draw call, after the update (most of the work)
                now += w * 0.9;
                waitDrawable();
                now += w * 0.1;
            }
            // Present: shown at the first vsync that is at least `lead` away
            shownAt = Math.fceil((now + lead) / period) * period;
            pacer.frameDone(w, now);
            gate.frameDone(w, pacer.deadline(period), pacer.period > 0 ? pacer.period : period, now);
        }

    }

}
