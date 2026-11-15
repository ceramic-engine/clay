package;

import clay.IdleThrottle;

/**
 * Tests of `clay.IdleThrottle`. Run from the clay folder:
 * `haxe test/test-throttle.hxml` (interpreter), or
 * `haxe test/test-throttle-js.hxml && node test/out/test-throttle.js`.
 */
class IdleThrottleTest {

    static var failures:Int = 0;

    static var checks:Int = 0;

    static function main() {

        testOffByDefault();
        testIdleAfterDelay();
        testActivityRestartsDelay();
        testDrawnFramesNotThrottledWhenFocused();
        testContinuousKeepsActive();
        testFocusLostThrottlesAtOnce();
        testInputWhileUnfocused();
        testHidden();
        testDeadline();
        testRateChangedAtRuntime();

        println('IdleThrottleTest: ' + (checks - failures) + '/' + checks + ' passed');
        #if sys
        Sys.exit(failures > 0 ? 1 : 0);
        #elseif js
        js.Syntax.code("process.exit({0})", failures > 0 ? 1 : 0);
        #end

    }

    static function check(cond:Bool, what:String):Void {
        checks++;
        if (!cond) {
            failures++;
            println('FAIL: ' + what);
        }
    }

    static function println(line:String):Void {
        #if sys
        Sys.println(line);
        #elseif js
        js.Syntax.code("console.log({0})", line);
        #end
    }

    static function near(a:Float, b:Float):Bool {
        return Math.abs(a - b) < 1e-9;
    }

    /** Default rate 0: never throttled, whatever happens (the loops behave as before). */
    static function testOffByDefault() {
        var t = new IdleThrottle();
        check(t.rate == 0, 'rate is 0 by default');
        check(!t.enabled, 'not enabled by default');
        check(near(t.delay, 0.5), 'delay is 0.5 by default');
        for (i in 0...100) {
            var now = i * 0.1;
            check(t.interval(now, false, false) == 0, 'default: idle tick not throttled at ' + now);
        }
        t.focusChanged(false);
        check(t.interval(20, true, false) == 0, 'default: unfocused not throttled');
        t.visibilityChanged(false);
        check(t.interval(21, false, false) == 0, 'default: hidden not throttled');
        check(!t.activityPending, 'default: activity cleared');
    }

    static function testIdleAfterDelay() {
        var t = new IdleThrottle();
        t.rate = 10;
        check(t.interval(0, false, false) == 0, 'active at start');
        check(t.interval(0.49, false, false) == 0, 'active before the delay');
        check(near(t.interval(0.5, false, false), 0.1), 'throttled after the delay');
        check(near(t.interval(5, false, false), 0.1), 'still throttled');
    }

    static function testActivityRestartsDelay() {
        var t = new IdleThrottle();
        t.rate = 10;
        t.interval(0, false, false);
        check(near(t.interval(1, false, false), 0.1), 'throttled');
        t.markActive();
        check(t.interval(1.05, false, false) == 0, 'input: back to the normal rate');
        check(t.interval(1.5, false, false) == 0, 'active within the delay');
        check(near(t.interval(1.56, false, false), 0.1), 'throttled again after the delay');
    }

    static function testDrawnFramesNotThrottledWhenFocused() {
        var t = new IdleThrottle();
        t.rate = 10;
        t.interval(0, false, false);
        // A cursor that blinks: a frame drawn every 0.5 s does not keep the app active
        check(t.interval(1.0, true, false) == 0, 'drawn frame: next tick at the normal rate');
        check(near(t.interval(1.016, false, false), 0.1), 'the tick after it is throttled');
        check(t.interval(1.5, true, false) == 0, 'next blink: normal rate');
        check(near(t.interval(1.516, false, false), 0.1), 'and throttled again');
    }

    static function testContinuousKeepsActive() {
        var t = new IdleThrottle();
        t.rate = 10;
        t.interval(0, false, false);
        check(t.interval(2, false, true) == 0, 'continuous render: active');
        check(t.interval(2.4, false, false) == 0, 'within the delay after it');
        check(near(t.interval(2.6, false, false), 0.1), 'throttled after the delay');
    }

    static function testFocusLostThrottlesAtOnce() {
        var t = new IdleThrottle();
        t.rate = 10;
        t.interval(0, false, false);
        t.markActive();
        t.interval(0.1, false, false);
        t.focusChanged(false);
        check(near(t.interval(0.12, false, false), 0.1), 'focus lost: throttled at once');
        check(near(t.interval(0.2, true, false), 0.1), 'unfocused: drawn frames throttled');
        check(near(t.interval(0.3, true, true), 0.1), 'unfocused: continuous render does not count');
        t.focusChanged(true);
        check(t.interval(0.4, false, false) == 0, 'focus back: normal rate');
    }

    static function testInputWhileUnfocused() {
        var t = new IdleThrottle();
        t.rate = 10;
        t.interval(0, false, false);
        t.focusChanged(false);
        t.interval(0.1, false, false);
        t.markActive(); // the mouse over an unfocused window
        check(t.interval(0.2, true, false) == 0, 'input while unfocused: normal rate');
        check(t.interval(0.6, true, false) == 0, 'within the delay');
        check(near(t.interval(0.75, true, false), 0.1), 'throttled after the delay');
    }

    static function testHidden() {
        var t = new IdleThrottle();
        t.rate = 4;
        t.interval(0, false, false);
        t.visibilityChanged(false);
        check(near(t.interval(0.01, true, true), 0.25), 'hidden: throttled at once, everything');
        t.markActive();
        check(near(t.interval(0.02, false, false), 0.25), 'hidden: even after activity');
        t.visibilityChanged(true);
        check(t.interval(0.03, false, false) == 0, 'shown: normal rate');
    }

    static function testDeadline() {
        // base: next tick without the throttle (one display period after the tick)
        check(near(IdleThrottle.deadline(10.016, 10, 0.1, -1), 10.1), 'no timer: interval');
        check(near(IdleThrottle.deadline(10.016, 10, 0.1, 0.05), 10.051), 'timer before: timer plus margin');
        check(near(IdleThrottle.deadline(10.016, 10, 0.1, 0.5), 10.1), 'timer after: interval');
        check(near(IdleThrottle.deadline(10.016, 10, 0.1, 0), 10.016), 'never before the base');
    }

    static function testRateChangedAtRuntime() {
        var t = new IdleThrottle();
        t.rate = 10;
        t.interval(0, false, false);
        check(near(t.interval(1, false, false), 0.1), 'throttled');
        t.rate = 0;
        check(t.interval(1.1, false, false) == 0, 'rate set to 0: off at once');
        t.rate = 2;
        check(near(t.interval(1.2, false, false), 0.5), 'rate 2: interval 0.5');
    }

}
