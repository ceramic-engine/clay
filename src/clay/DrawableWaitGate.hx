package clay;

/**
 * Decides whether a render loop waits for its drawable first (at the start of the frame,
 * before reading the input) or lets the wait happen where it always did (in the first draw
 * call of the frame, after the update).
 *
 * Waiting first shows input one vsync earlier, but it costs a whole period when the work of
 * a frame does not fit in what is left of the period: with every frame over budget the loop
 * falls to half the display rate (measured: 29.9 instead of 49.7 frames per second with 20 ms
 * frames at 60 Hz). So the loop stops waiting first while frames are slow, and resumes as soon
 * as they are fast again.
 *
 * This class is pure logic: no platform call, no clock. Times are given by the caller, in
 * seconds.
 *
 * One threshold, the deadline of `FramePacer`: a frame that starts at the drawable return
 * must end before `period - floor`. A frame is slow when its work exceeds it.
 * - Drop: `slowFrames` slow frames in a row. One isolated long frame (a GC pause) changes
 *   nothing.
 * - Resume: `fastFrames` frames in a row within the deadline. A slow frame restarts the count.
 * - Backoff against flapping (`RetryBackoff`): when a drop comes less than a second after a
 *   resume, the run needed to resume doubles, up to `backoffCap` seconds of frames. It halves
 *   again after each 5 seconds without a drop. A loading screen followed by fast frames
 *   resumes after `fastFrames` frames, an app at the limit of its budget settles in the
 *   fallback.
 *
 * It also checks the assumption the whole scheme rests on, that the wait at the start of the
 * frame is the one that blocks: when it returned at once on nearly every frame that should
 * have blocked (`CHECK_FRAMES` such frames, fewer than `CHECK_MIN_BLOCKED` of them blocked),
 * `disabled` is set for the rest of the session.
 */
class DrawableWaitGate {

    /** Frames looked at by the check of the blocking wait. */
    public static inline var CHECK_FRAMES:Int = 120;

    /** Blocked waits below which, out of `CHECK_FRAMES`, the wait is declared not blocking. */
    public static inline var CHECK_MIN_BLOCKED:Int = 12;

    /** Slow frames in a row that stop waiting first. */
    public var slowFrames:Int = 3;

    /** Frames within the deadline in a row that resume waiting first (before backoff). */
    public var fastFrames:Int = 8;

    /** Longest run needed to resume once doubled by the backoff, in seconds of frames. */
    public var backoffCap:Float = 2.0;

    /** False while waiting first is dropped because frames are slow. */
    public var waitFirst(default, null):Bool = true;

    /** True once the wait at the start of the frame was found not to block: off for the session. */
    public var disabled(default, null):Bool = false;

    /** Times the run needed to resume was doubled and not halved back yet (0: no backoff). */
    public var backoff(get, never):Int;
    inline function get_backoff():Int {
        return retry.level;
    }

    var retry:RetryBackoff = new RetryBackoff();

    /** Drops so far. */
    public var drops(default, null):Int = 0;

    /** Resumes so far. */
    public var resumes(default, null):Int = 0;

    var slowRun:Int = 0;

    var fastRun:Int = 0;

    var lastSlow:Bool = false;

    var checked:Int = 0;

    var checkedBlocked:Int = 0;

    public function new() {}

    /** Whether the next frame should wait for its drawable first. */
    public var active(get, never):Bool;
    inline function get_active():Bool {
        return waitFirst && !disabled;
    }

    /** Frames within the deadline in a row needed to resume, backoff included. */
    public function requiredRun(period:Float):Int {

        var run = fastFrames;
        if (backoff > 0) {
            var cap = capRun(period);
            for (i in 0...backoff) {
                run *= 2;
                if (run >= cap) {
                    run = cap;
                    break;
                }
            }
        }
        return run;

    }

    function capRun(period:Float):Int {

        var cap = period > 0 ? Math.ceil(backoffCap / period) : fastFrames;
        return cap < fastFrames ? fastFrames : cap;

    }

    /**
     * A frame was presented at `now`. `work` is the time from reading the input to the end
     * of the present, without the wait for the drawable; `deadline` is `period - floor`.
     */
    public function frameDone(work:Float, deadline:Float, period:Float, now:Float):Void {

        retry.update(now);

        var slow = work > deadline;
        lastSlow = slow;

        if (waitFirst) {
            if (slow) {
                slowRun++;
                if (slowRun >= slowFrames) {
                    waitFirst = false;
                    drops++;
                    slowRun = 0;
                    fastRun = 0;
                    // A doubling counts only while it still changes the run needed
                    retry.failed(now, requiredRun(period) < capRun(period));
                }
            }
            else {
                slowRun = 0;
            }
        }
        else {
            if (slow) {
                fastRun = 0;
            }
            else {
                fastRun++;
                if (fastRun >= requiredRun(period)) {
                    waitFirst = true;
                    resumes++;
                    fastRun = 0;
                    slowRun = 0;
                    retry.retried(now);
                }
            }
        }

    }

    /**
     * The wait at the start of a frame returned, having blocked or not. `expected` tells
     * whether it should have blocked: the frame before was presented, vsync is on and the
     * window is in front. Waits after a slow frame are left out here (the drawable is free
     * by then).
     */
    public function waitDone(blocked:Bool, expected:Bool):Void {

        if (disabled || !expected || lastSlow) return;
        checked++;
        if (blocked) checkedBlocked++;
        if (checked >= CHECK_FRAMES) {
            if (checkedBlocked < CHECK_MIN_BLOCKED) disabled = true;
            checked = 0;
            checkedBlocked = 0;
        }

    }

}
