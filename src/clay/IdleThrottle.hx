package clay;

/**
 * The throttled state of the loop (`config.idleUpdateRate`): the most ticks per second while
 * the app is at rest or in the background, the same rule for the native and the web loops.
 *
 * Off by default (`rate` is 0): the loops then behave exactly as without this class.
 *
 * With a rate above 0, the loop is throttled:
 * - after `delay` seconds without activity, for the ticks whose frame was not drawn (a frame
 *   drawn because something changed is always followed by a tick at the normal rate, so a
 *   sequence of drawn frames is never throttled);
 * - at once when the window loses the focus, and then for every tick, drawn or not, until
 *   an input event comes (it gives `delay` seconds at the normal rate again) or the focus
 *   comes back;
 * - at once while the window is hidden, minimized or occluded, for every tick.
 *
 * With a sleep delay (`sleepDelay`, off by default), the loop sleeps once the window was not
 * visible for that long: `interval()` returns `SLEEP` and the loop waits for an event without
 * a timeout (the next timer of the app is not waited for). Activity while asleep (an event,
 * work posted from another thread) gives one tick, then the loop sleeps again until the
 * window is visible.
 *
 * Activity is an input event (keys, text, mouse moves and buttons, wheel, touches, gamepads),
 * a window event, work posted from another thread (`Runner.runInMain`) and, while the window
 * has the focus, something that renders continuously (a tween, a continuous render request:
 * `Clay.renderContinuous`).
 *
 * This class is pure logic: it makes no platform call and reads no clock. Every time is given
 * by the caller, in seconds, on one clock of its choice.
 */
class IdleThrottle {

    /**
     * The most ticks per second while throttled. 0 or less: never throttled (default).
     */
    public var rate:Float = 0;

    /**
     * Seconds at the normal rate after the last activity (default 0.5).
     */
    public var delay:Float = 0.5;

    /**
     * Something made the app active since the last call to `interval()` (an input event, a
     * window event, work posted from another thread). Read and cleared by `interval()`.
     */
    public var activityPending:Bool = false;

    /** Whether the window lost the focus (and did not get it back). */
    public var unfocused(default, null):Bool = false;

    /** Whether the window is hidden, minimized or occluded (not visible at all). */
    public var hidden(default, null):Bool = false;

    /**
     * Seconds after the window stops being visible before the loop sleeps (see `SLEEP`).
     * Below 0: never (default).
     */
    public var sleepDelay:Float = -1;

    /** Whether the last call to `interval()` returned `SLEEP`. */
    public var asleep(default, null):Bool = false;

    /** Time the window was first seen not visible by `interval()`, -1 while visible. */
    var hiddenStart:Float = -1;

    /** Time of the last activity, once `started` */
    var lastActivity:Float = 0;

    /** Whether `lastActivity` was set once (the app is active when it starts) */
    var started:Bool = false;

    /** The focus was lost since the last call to `interval()` */
    var focusLost:Bool = false;

    public function new() {}

    /** Whether ticks can be throttled at all (`rate` above 0, or a `sleepDelay`). */
    public var enabled(get, never):Bool;
    inline function get_enabled():Bool {
        return rate > 0 || sleepDelay >= 0;
    }

    /** Something made the app active: see `activityPending`. */
    inline public function markActive():Void {
        activityPending = true;
    }

    /** The window got (`true`) or lost (`false`) the focus. Losing it throttles at once. */
    public function focusChanged(focused:Bool):Void {
        if (focused) {
            unfocused = false;
            activityPending = true;
        }
        else {
            unfocused = true;
            focusLost = true;
        }
    }

    /**
     * The window was shown, restored or exposed (`true`), or hidden, minimized or occluded
     * (`false`).
     */
    public function visibilityChanged(visible:Bool):Void {
        hidden = !visible;
        if (visible) {
            activityPending = true;
            hiddenStart = -1;
            asleep = false;
        }
    }

    /**
     * Called once per tick, after it (`drawn`: whether its frame was drawn; `continuous`:
     * whether something renders continuously, see `Clay.renderContinuous`). Returns the
     * least time between this tick and the next one, in seconds, or 0 when the loop is not
     * throttled (the next tick comes at the normal rate).
     */
    public function interval(now:Float, drawn:Bool, continuous:Bool):Float {

        if (hidden && sleepDelay >= 0) {
            if (hiddenStart < 0) hiddenStart = now;
            if (now - hiddenStart >= sleepDelay) {
                // Activity while asleep gave this tick: asleep again after it
                asleep = true;
                activityPending = false;
                focusLost = false;
                return SLEEP;
            }
        }
        asleep = false;

        if (rate <= 0) {
            activityPending = false;
            focusLost = false;
            return 0;
        }

        if (!started) {
            started = true;
            lastActivity = now;
        }

        if (focusLost) {
            // Throttled at once, unless an input event came with the loss of the focus
            focusLost = false;
            lastActivity = now - delay;
        }

        var background = unfocused || hidden;
        if (activityPending || (continuous && !background)) {
            activityPending = false;
            lastActivity = now;
        }

        if (hidden)
            return 1.0 / rate;

        if (now - lastActivity < delay)
            return 0;

        // At rest with the focus, only the ticks that drew nothing are throttled
        if (drawn && !unfocused)
            return 0;

        return 1.0 / rate;

    }

    /**
     * The time of the next tick while throttled: `interval` (from `interval()`, above 0)
     * after `tickTime`, or earlier when the app has work due at `tickTime + workDelay` (its
     * next timer; `workDelay` below 0: none), never before `base` (the time of the next tick
     * without the throttle).
     */
    public static function deadline(base:Float, tickTime:Float, interval:Float, workDelay:Float):Float {

        // Asleep: timers are frozen, only an event wakes the loop
        if (interval == SLEEP) return SLEEP;

        var result = tickTime + interval;
        if (workDelay >= 0) {
            // A little after the work is due: the app compares its own clock to it
            var due = tickTime + workDelay + WORK_MARGIN;
            if (due < result) result = due;
        }
        return result > base ? result : base;

    }

    /**
     * Returned by `interval()` while asleep (`sleepDelay`): the loop waits for an event,
     * without a timeout.
     */
    public static final SLEEP:Float = Math.POSITIVE_INFINITY;

    /** Seconds added to the time of the app's next timer, so that it is due when the tick comes */
    public static inline final WORK_MARGIN:Float = 0.001;

}
