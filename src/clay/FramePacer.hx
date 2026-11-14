package clay;

/**
 * Margin frame pacing: tells a render loop how long it can sleep after it got its drawable,
 * so that input is read as late as possible and the frame still reaches the next vsync.
 *
 * The loop this class serves waits for its drawable first (a blocking call that returns at a
 * vsync when the drawable queue is full), then reads the input, updates, draws and presents.
 * Without pacing the input is read right after a vsync and shown at the next one or later:
 * the time left in the period after the work is wasted. With pacing the loop sleeps until
 * `next vsync - margin` before it reads the input.
 *
 * This class is pure logic: it makes no platform call and reads no clock. Every time is given
 * by the caller, in seconds, from one monotonic clock.
 *
 * Vsync clock: the return of the drawable wait. Returns are only ever late, never early
 * (measured on macOS at 60 Hz: median 0.07 ms late, 99 % under 1 ms). So the phase follows
 * the earliest of the recent returns: a return earlier than predicted is taken as is, a later
 * one moves the phase by `LATE_SLEW` at most. The period is the median of the recent intervals
 * between two returns of waits that blocked (`MIN_PERIOD` to `MAX_PERIOD`), so it follows a
 * display that changes its refresh rate.
 *
 * Deadline: a frame that starts at the drawable return must end before `period - floor`
 * (`deadline()`). The floor covers what is not measured: the GPU time after the submit, the
 * wake up jitter and the lead the compositor needs.
 *
 * Margin: `floor + multiple x worst work of the recent frames`, plus `MISS_WIDEN`
 * for a while after a paced miss. Pacing engages only when the margin fits in the period
 * (`floor + multiple x worst work <= period`). The worst work goes up at once when a slower
 * frame comes and goes down slowly (time constant `WORK_DECAY` seconds). A frame whose work
 * exceeded the deadline (a loading step, a GC pause) counts as one full period: while it is
 * in the window the margin does not fit and pacing stays off, and pacing comes back when it
 * leaves the window (it is not smoothed on the way down) and the lock is there. Whether such
 * frames stop the wait for the drawable first is the business of `DrawableWaitGate`.
 *
 * Window: the worst work is taken over the last `effectiveWindow` frames, which adapts
 * between `minWindow` and `window` on the pattern "try early, back off when it fails"
 * (`RetryBackoff`). It starts at `minWindow`, so pacing is tried again that many frames
 * after a long frame (plus the lock). When a frame over the deadline or a paced miss comes
 * less than a second after pacing engaged again, it doubles (up to `window`). It halves
 * after each 5 seconds without such an event (down to `minWindow`).
 *
 * No pacing (`acquired()` returns 0) when: disabled, not locked (fewer than `LOCK_RETURNS`
 * consistent returns in a row, which is the case after `interrupt()` and after a miss), the
 * wait did not block (no vsync signal), the margin exceeds the period, or pacing was turned
 * off by paced misses.
 *
 * Miss: about two periods between two returns (the frame was shown one vsync late, which is a
 * repeated image in an animation, not latency). Every miss breaks the lock. Only a paced miss
 * (the frame was paced and its work was within the deadline, so the pacing itself slept too
 * long) brings a penalty: the margin is widened by `MISS_WIDEN` for `MISS_WIDEN_TIME` seconds,
 * and `MISS_LIMIT` paced misses within `MISS_SPAN` seconds turn pacing off for `OFF_TIME`
 * seconds and restart the period estimate. A miss caused by a long frame brings none.
 *
 * Usage, each frame that waits for its drawable first:
 * `var until = pacer.acquired(waitStart, waitEnd); sleep until that time when not 0;`
 * then after the frame was presented: `pacer.frameDone(work, now)`. A frame that did not wait for
 * its drawable first (idle period, fallback) calls `pacer.interrupt()`.
 */
class FramePacer {

    /** A wait longer than this (seconds) blocked: its return is a vsync signal. */
    public static inline var BLOCKED_WAIT:Float = 0.0005;

    /** Shortest period accepted, seconds (500 Hz). */
    public static inline var MIN_PERIOD:Float = 0.002;

    /** Longest period accepted, seconds (20 Hz). */
    public static inline var MAX_PERIOD:Float = 0.050;

    /** Intervals kept for the median. */
    public static inline var PERIOD_SAMPLES:Int = 31;

    /** Intervals needed before a period is given. */
    public static inline var PERIOD_MIN_SAMPLES:Int = 9;

    /** A return within this share of the period around the prediction keeps the lock. */
    public static inline var LOCK_TOLERANCE:Float = 0.25;

    /** Consistent returns in a row needed before pacing. */
    public static inline var LOCK_RETURNS:Int = 5;

    /** How far a late return can move the phase, seconds. */
    public static inline var LATE_SLEW:Float = 0.0001;

    /** Time constant of the way down of the worst work, seconds. */
    public static inline var WORK_DECAY:Float = 1.0;

    /** Margin added after a miss, seconds. */
    public static inline var MISS_WIDEN:Float = 0.002;

    /** How long the margin stays wider after a miss, seconds. */
    public static inline var MISS_WIDEN_TIME:Float = 5.0;

    /** Misses within `MISS_SPAN` seconds that turn pacing off. */
    public static inline var MISS_LIMIT:Int = 3;

    /** See `MISS_LIMIT`, seconds. */
    public static inline var MISS_SPAN:Float = 2.0;

    /** How long pacing stays off after too many misses, seconds. */
    public static inline var OFF_TIME:Float = 10.0;

    /** Pacing on or off. The vsync estimate keeps running when off. */
    public var enabled:Bool = true;

    /** Fixed part of the margin, seconds. */
    public var floor:Float = 0.004;

    /** The worst recent work is multiplied by this in the margin. */
    public var multiple:Float = 2.0;

    /** Largest number of frames over which the worst work is taken (frames, not time). */
    public var window(default, set):Int = 120;

    /** Smallest number of frames over which the worst work is taken (frames, not time). */
    public var minWindow:Int = 8;

    /** Number of frames over which the worst work is taken now: `minWindow` to `window`. */
    public var effectiveWindow(get, never):Int;
    function get_effectiveWindow():Int {
        var length = minWindow < 1 ? 1 : minWindow;
        for (i in 0...retry.level) {
            length *= 2;
            if (length >= window) break;
        }
        return length > window ? window : length;
    }

    var retry:RetryBackoff = new RetryBackoff();

    /** The frame before the current one was paced (to see pacing engage again). */
    var wasPaced:Bool = false;

    /**
     * Period of the display when known (seconds), else 0. Intervals longer than 1.5 times
     * this are not taken as period samples: an app that runs at half the display rate
     * because every frame is over budget must not be read as a slower display.
     */
    public var nominalPeriod:Float = 0;

    /** Estimated vsync period, seconds. 0 while unknown. */
    public var period(default, null):Float = 0;

    /** Consistent returns in a row. */
    public var locked(default, null):Int = 0;

    /** Margin used by the last paced frame, seconds. */
    public var margin(default, null):Float = 0;

    /** Worst recent work as used by the margin, seconds. */
    public var worstWork(default, null):Float = 0;

    /** Worst recent work among the frames within the deadline, smoothed on the way down. */
    var smoothedWork:Float = 0;

    /** Frames given to `acquired()`. */
    public var frames(default, null):Int = 0;

    /** Frames whose wait blocked. */
    public var blockedFrames(default, null):Int = 0;

    /** Frames that were paced (`acquired()` returned a time). */
    public var pacedFrames(default, null):Int = 0;

    /** Misses seen (paced or not). */
    public var misses(default, null):Int = 0;

    /** Misses of paced frames whose work was within the deadline (the ones that bring a penalty). */
    public var pacedMisses(default, null):Int = 0;

    /** Pacing is off until this time because of misses (0: not off). */
    public var offUntil(default, null):Float = 0;

    var lastReturn:Float = 0;

    var anchor:Float = 0;

    var intervals:Array<Float> = [];

    var sorted:Array<Float> = [];

    var works:Array<Float> = [];

    /** For each entry of `works`: the frame exceeded the deadline. */
    var overs:Array<Bool> = [];

    var workIndex:Int = 0;

    var smoothedAt:Float = 0;

    var widenUntil:Float = 0;

    var missTimes:Array<Float> = [];

    /** The last frame given to `acquired()` was paced. */
    var lastPaced:Bool = false;

    /** The work of the last frame exceeded the deadline. */
    var lastOverDeadline:Bool = false;

    public function new() {}

    function set_window(value:Int):Int {
        if (value < 1) value = 1;
        if (value != window) {
            window = value;
            works = [];
            overs = [];
            workIndex = 0;
        }
        return value;
    }

    /**
     * Time a frame that starts at the drawable return has for its work: `period - floor`.
     * `fallbackPeriod` is used while the period is not known yet.
     */
    public function deadline(fallbackPeriod:Float = 0):Float {

        var p = period > 0 ? period : fallbackPeriod;
        var d = p - floor;
        return d > 0 ? d : 0;

    }

    /**
     * The wait for the drawable started at `waitStart` and returned at `waitEnd`.
     * Returns the time to sleep until before reading the input, or 0 for no pacing.
     */
    public function acquired(waitStart:Float, waitEnd:Float):Float {

        frames++;
        var blocked = (waitEnd - waitStart) > BLOCKED_WAIT;
        if (blocked) blockedFrames++;

        if (lastReturn > 0) {
            var interval = waitEnd - lastReturn;
            if (period > 0 && interval > 1.6 * period && interval < 2.6 * period) {
                miss(waitEnd, lastPaced && !lastOverDeadline);
            }
            else if (blocked && interval > MIN_PERIOD && interval < MAX_PERIOD
                && (nominalPeriod <= 0 || interval < 1.5 * nominalPeriod)) {
                intervals.push(interval);
                if (intervals.length > PERIOD_SAMPLES) intervals.shift();
                if (intervals.length >= PERIOD_MIN_SAMPLES) period = median();
            }
        }
        lastReturn = waitEnd;
        wasPaced = lastPaced;
        lastPaced = false;
        lastOverDeadline = false;
        retry.update(waitEnd);

        if (!blocked || period <= 0) {
            anchor = 0;
            locked = 0;
            return 0;
        }

        var predicted = anchor + period;
        if (anchor > 0 && Math.abs(waitEnd - predicted) < LOCK_TOLERANCE * period) {
            // Returns are only ever late: an earlier one is the better phase,
            // a later one moves it a little (it also absorbs the period error)
            var cap = predicted + LATE_SLEW;
            anchor = waitEnd < cap ? waitEnd : cap;
            locked++;
        }
        else {
            anchor = waitEnd;
            locked = 0;
        }

        var worst = updateWorstWork(waitEnd);

        if (!enabled || locked < LOCK_RETURNS) return 0;
        if (offUntil > 0) {
            if (waitEnd < offUntil) return 0;
            offUntil = 0;
        }

        var m = floor + multiple * worst;
        if (waitEnd < widenUntil) m += MISS_WIDEN;
        if (m > period) return 0;

        margin = m;
        pacedFrames++;
        lastPaced = true;
        if (!wasPaced) retry.retried(waitEnd);
        return anchor + period - m;

    }

    /**
     * A frame was presented at `now`: `work` is the time it took from reading the input to
     * the end of the present (without the wait for the drawable).
     */
    public function frameDone(work:Float, now:Float):Void {

        if (work < 0) work = 0;
        retry.update(now);
        var over = false;
        var limit = deadline(nominalPeriod);
        if (limit > 0 && work > limit) {
            // Over the deadline: counts as one full period
            over = true;
            lastOverDeadline = true;
            retry.failed(now, effectiveWindow < window);
            var p = period > 0 ? period : nominalPeriod;
            if (work > p) work = p;
        }
        if (works.length < window) {
            works.push(work);
            overs.push(over);
        }
        else {
            works[workIndex] = work;
            overs[workIndex] = over;
            workIndex = (workIndex + 1) % window;
        }
        // Up at once
        if (!over && work > smoothedWork) smoothedWork = work;

    }

    /**
     * The chain of drawable waits is broken (idle period, a frame that did not wait first):
     * the next returns must lock again before pacing. The period is kept.
     */
    public function interrupt():Void {

        wasPaced = false;
        lastPaced = false;
        lastReturn = 0;
        anchor = 0;
        locked = 0;

    }

    function updateWorstWork(now:Float):Float {

        var max = 0.0;
        var maxOver = 0.0;
        // The last `effectiveWindow` frames: `workIndex` is the oldest entry once the ring is full
        var stored = works.length;
        var count = effectiveWindow;
        if (count > stored) count = stored;
        var newest = stored < window ? stored - 1 : workIndex - 1;
        for (k in 0...count) {
            var i = newest - k;
            if (i < 0) i += stored;
            var w = works[i];
            if (overs[i]) {
                if (w > maxOver) maxOver = w;
            }
            else if (w > max) {
                max = w;
            }
        }
        if (max >= smoothedWork || smoothedAt <= 0) {
            smoothedWork = max;
        }
        else {
            // Down slowly
            var dt = now - smoothedAt;
            if (dt > 0) smoothedWork = max + (smoothedWork - max) * Math.exp(-dt / WORK_DECAY);
        }
        smoothedAt = now;
        worstWork = maxOver > smoothedWork ? maxOver : smoothedWork;
        return worstWork;

    }

    function miss(now:Float, paced:Bool):Void {

        misses++;
        locked = 0;
        anchor = 0;
        if (!paced) return;

        pacedMisses++;
        retry.failed(now, effectiveWindow < window);
        widenUntil = now + MISS_WIDEN_TIME;

        missTimes.push(now);
        while (missTimes.length > 0 && now - missTimes[0] > MISS_SPAN) missTimes.shift();
        if (missTimes.length >= MISS_LIMIT) {
            // Never let a miss streak persist: stop pacing and learn the period again
            // (the display may have changed its rate)
            offUntil = now + OFF_TIME;
            missTimes = [];
            intervals = [];
            period = 0;
        }

    }

    function median():Float {

        var n = intervals.length;
        sorted.resize(n);
        // Insertion sort into a reused array (no allocation per frame)
        for (i in 0...n) {
            var v = intervals[i];
            var j = i - 1;
            while (j >= 0 && sorted[j] > v) {
                sorted[j + 1] = sorted[j];
                j--;
            }
            sorted[j + 1] = v;
        }
        return sorted[n >> 1];

    }

}
