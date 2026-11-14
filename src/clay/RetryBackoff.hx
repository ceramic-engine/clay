package clay;

/**
 * "Try early, back off when it fails": the shared part of `DrawableWaitGate` and
 * `FramePacer`. Both leave their best mode when something goes wrong and try it again soon
 * after. When the retry fails quickly, the next one must wait longer.
 *
 * `level` is the number of doublings to apply to whatever the owner waits for before a
 * retry. It goes up by one when a failure comes less than `FLAP_TIME` seconds after a retry
 * (once per retry), and down by one after each `CALM_TIME` seconds without a failure.
 *
 * Pure logic: times are given by the caller, in seconds.
 */
class RetryBackoff {

    /** A failure less than this many seconds after a retry raises the level. */
    public static inline var FLAP_TIME:Float = 1.0;

    /** Seconds without a failure after which the level goes down by one. */
    public static inline var CALM_TIME:Float = 5.0;

    /** Doublings to apply (0: none). */
    public var level(default, null):Int = 0;

    var lastRetry:Float = -1;

    var calmSince:Float = -1;

    public function new() {}

    /** The best mode was tried again at `now`. */
    public function retried(now:Float):Void {

        lastRetry = now;

    }

    /**
     * Something went wrong at `now`. The level goes up when this comes soon after a retry
     * and `canGrow` (the owner says whether one more doubling still changes anything).
     */
    public function failed(now:Float, canGrow:Bool):Void {

        if (lastRetry >= 0 && now - lastRetry < FLAP_TIME && canGrow) level++;
        lastRetry = -1;
        calmSince = now;

    }

    /** To call regularly: lowers the level after a calm period. */
    public function update(now:Float):Void {

        if (calmSince < 0) calmSince = now;
        if (level > 0 && now - calmSince >= CALM_TIME) {
            level--;
            calmSince = now;
        }

    }

}
