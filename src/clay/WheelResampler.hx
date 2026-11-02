package clay;

/**
 * Delivers a stream of smooth scrolling deltas (trackpads, smooth wheels) on the beat of the
 * frames instead of the beat of the events.
 *
 * Some browsers (Safari) dispatch wheel events on a clock of their own, not aligned with the
 * animation frames: at 60 events per second against 60 frames per second, a frame now and
 * then receives no event and the next one receives two, so a scroll that applies each delta
 * as it comes stops for a frame and then jumps twice as far. Chromium dispatches wheel input
 * aligned with the frames (one coalesced event per frame) and does not show this.
 *
 * Resampling: the received deltas are kept as a cumulative curve over the event times. Each
 * frame takes the curve at `frameTime - latency`, linearly interpolated between the two events
 * around that time, and emits the difference with what was emitted before. When the latency
 * is at least the age of the newest event known at a frame, there is an event on each side of
 * the sample, so each frame moves by the distance the device covered during one frame,
 * whatever the phase between events and frames.
 *
 * The latency adapts to the browser: a frame that comes just before an event arrives knows
 * only the event before, so the samples stay behind the frames by the time from an event to
 * the arrival of the next one (one event interval plus the delivery delay of the browser),
 * taken near its largest value over the last events. This holds whatever the phase between
 * events and frames, which drifts. The latency rises quickly and falls slowly so that steps
 * stay even.
 *
 * The timestamps are smoothed a little before use (their jitter would make the interpolated
 * steps uneven), and never placed after the arrival of their event.
 *
 * Nothing is extrapolated: when the sample time is past the last event, the curve holds at
 * the total received. When no event came for `endGap` seconds, the stream ends and whatever
 * remains is emitted at once, so the total distance is exactly the sum of the deltas.
 *
 * Automatic mode (`auto`, the default): events go through untouched (`add()` returns `false`)
 * as long as the delivery is even, so a browser that already aligns wheel input with the
 * frames gets no latency. Resampling starts at the first uneven frame (a frame without an
 * event between two events that came at the frame rate, or a frame with two events or more)
 * and stops at the end of a stream once `EVEN_FRAMES` frames in a row were even again.
 *
 * Usage, at each event: `if (!resampler.add(...)) emit the event as is`; at each frame,
 * before the update: `if (resampler.sample(frameTime, period)) emit stepX, stepY`.
 */
class WheelResampler {

    /** Seconds without an event after which a stream ends (its remainder is emitted). */
    public var endGap:Float = 0.04;

    /** Smallest latency, in frame periods. */
    public var minLatency:Float = 0.25;

    /** Largest latency, in frame periods. */
    public var maxLatency:Float = 3.0;

    /**
     * Resample only when the delivery is uneven (see above). When `false`, every stream is
     * resampled.
     */
    public var auto:Bool = true;

    /** Latency used by the last `sample()` call (seconds), `-1` before any. */
    public var latency(default, null):Float = -1;

    /** Whether a resampled stream is in progress (deltas received and not all emitted yet). */
    public var active(default, null):Bool = false;

    /** Whether events are resampled now (always when `auto` is `false`). */
    public var resampling(default, null):Bool = false;

    /** Horizontal step computed by the last `sample()` or `flush()` call. */
    public var stepX(default, null):Float = 0;

    /** Vertical step computed by the last `sample()` or `flush()` call. */
    public var stepY(default, null):Float = 0;

    /** Event times of the stream points (seconds), increasing. */
    var times:Array<Float> = [];

    /** Cumulative horizontal delta at each point. */
    var cumX:Array<Float> = [];

    /** Cumulative vertical delta at each point. */
    var cumY:Array<Float> = [];

    var count:Int = 0;

    var receivedX:Float = 0;

    var receivedY:Float = 0;

    var emittedX:Float = 0;

    var emittedY:Float = 0;

    /** Time of the last event, resampled or not (seconds), `-1` before any. */
    var lastEventTime:Float = -1;

    /** Last sample time of the stream (seconds): sample times never go back. */
    var lastSampleTime:Float = 0;

    /**
     * Last measured ages of the newest event a frame can know (seconds), in a ring: the time
     * from an event to the arrival of the next one.
     */
    var ages:Array<Float> = [for (_ in 0...AGE_COUNT) 0.0];

    var ageIndex:Int = 0;

    var ageCount:Int = 0;

    /** Events added since the last `sample()`. */
    var eventsSinceSample:Int = 0;

    /** Whether a frame without an event came since the last event. */
    var pendingEmptyFrame:Bool = false;

    /** Frame period given to the last `sample()` (seconds). */
    var period:Float = 1.0 / 60.0;

    /** Even frames inside streams since the last uneven one. */
    var evenFrames:Int = EVEN_FRAMES;

    static inline final AGE_COUNT:Int = 40;

    /** Timestamp of the last resampled event before smoothing (seconds). */
    var lastRawTime:Float = 0;

    /** Mean interval between the timestamps of a stream (seconds), `-1` before any. */
    var meanInterval:Float = -1;

    /** Fraction of the way from the predicted time to the timestamp (see `add()`). */
    static inline final TIME_SMOOTHING:Float = 0.25;

    /** Weight of a new interval in the mean interval. */
    static inline final INTERVAL_SMOOTHING:Float = 0.15;

    /** Added to the measured age (seconds). */
    static inline final LATENCY_MARGIN:Float = 0.001;

    /** Largest rise of the latency from a frame to the next, in frame periods. */
    static inline final LATENCY_RISE:Float = 0.25;

    /** Largest fall of the latency from a frame to the next, in frame periods. */
    static inline final LATENCY_FALL:Float = 0.05;

    /** Even frames in a row after which the automatic mode stops resampling (at a stream end). */
    static inline final EVEN_FRAMES:Int = 180;

    public function new() {}

    /**
     * Takes the deltas of an event that happened at `time` and was received at `arrival`
     * (seconds, on the clock of the frame times given to `sample()`). Returns `true` when the
     * event is resampled (its deltas will come out of `sample()`), `false` when the caller
     * should emit it as is.
     */
    public function add(time:Float, arrival:Float, deltaX:Float, deltaY:Float):Bool {

        if (time > arrival || time != time)
            time = arrival;

        // Delivery evenness: a frame went by without an event while events came at the frame rate
        var inStream = lastEventTime >= 0 && time - lastEventTime <= endGap;
        if (pendingEmptyFrame && inStream && time - lastEventTime < 1.5 * period)
            uneven();
        pendingEmptyFrame = false;
        var firstSinceFrame = eventsSinceSample == 0;
        eventsSinceSample++;

        if (!resampling && (!auto || evenFrames < EVEN_FRAMES))
            startResampling();

        if (!resampling) {
            if (time > lastEventTime)
                lastEventTime = time;
            return false;
        }

        if (active && time < times[count - 1])
            time = times[count - 1];

        // Smoothed event time: interpolation would turn the jitter of the timestamps into
        // uneven steps. The time follows the mean interval and moves a fraction of the way
        // toward the timestamp (a phase locked loop), never after the arrival.
        if (active && time - lastEventTime <= endGap) {
            var interval = time - lastRawTime;
            if (interval > 0)
                meanInterval = meanInterval < 0 ? interval : meanInterval + (interval - meanInterval) * INTERVAL_SMOOTHING;
            lastRawTime = time;
            if (meanInterval > 0) {
                var predicted = times[count - 1] + meanInterval;
                var smoothed = predicted + (time - predicted) * TIME_SMOOTHING;
                if (smoothed > arrival)
                    smoothed = arrival;
                if (smoothed < times[count - 1])
                    smoothed = times[count - 1];
                time = smoothed;
            }
        }
        else {
            lastRawTime = time;
        }

        if (!active) {
            receivedX = 0;
            receivedY = 0;
            emittedX = 0;
            emittedY = 0;
            count = 0;
            var anchor = time - period;
            if (anchor < lastSampleTime)
                anchor = lastSampleTime;
            if (anchor > time)
                anchor = time;
            lastSampleTime = anchor;
            push(anchor, 0, 0);
            active = true;
        }
        else if (time - lastEventTime > endGap) {
            // A pause inside the stream: start again from the last point, as a new stream would
            var anchor = time - period;
            if (anchor < times[count - 1])
                anchor = times[count - 1];
            push(anchor, receivedX, receivedY);
        }
        else if (firstSinceFrame) {
            // How far behind the frames the samples must be: a frame comes at the latest just
            // before this event arrives, and the newest event it knows is the previous one
            // (events that arrive together after a stall of the page had no frame in between)
            ages[ageIndex] = arrival - times[count - 1];
            ageIndex = (ageIndex + 1) % AGE_COUNT;
            if (ageCount < AGE_COUNT)
                ageCount++;
        }

        receivedX += deltaX;
        receivedY += deltaY;
        push(time, receivedX, receivedY);
        lastEventTime = time;
        return true;

    }

    /**
     * Computes the step of the frame at `frameTime` into `stepX` and `stepY`. `period` is the
     * frame period (seconds). Returns `true` when there is a step to emit. Call it at every
     * frame, resampling or not: it also watches how evenly the events come.
     */
    public function sample(frameTime:Float, period:Float):Bool {

        stepX = 0;
        stepY = 0;
        if (period > 0)
            this.period = period;

        var age = frameTime - lastEventTime;
        var inStream = lastEventTime >= 0 && age <= endGap;
        if (inStream) {
            if (eventsSinceSample >= 2)
                uneven();
            else if (eventsSinceSample == 0)
                pendingEmptyFrame = true;
            else if (evenFrames < EVEN_FRAMES)
                evenFrames++;
        }
        eventsSinceSample = 0;

        if (!active) {
            if (resampling && auto && evenFrames >= EVEN_FRAMES)
                resampling = false;
            return false;
        }

        var x:Float;
        var y:Float;
        var ended = age > endGap;

        if (ended) {
            x = receivedX;
            y = receivedY;
        }
        else {
            // Latency: see targetLatency(), rising quickly and falling slowly
            var target = targetLatency();
            if (latency < 0 || target > latency + LATENCY_RISE * this.period)
                latency = latency < 0 ? target : latency + LATENCY_RISE * this.period;
            else if (target < latency - LATENCY_FALL * this.period)
                latency -= LATENCY_FALL * this.period;
            else
                latency = target;

            var s = frameTime - latency;
            if (s < lastSampleTime)
                s = lastSampleTime;
            lastSampleTime = s;

            if (s <= times[0]) {
                x = cumX[0];
                y = cumY[0];
            }
            else if (s >= times[count - 1]) {
                x = cumX[count - 1];
                y = cumY[count - 1];
            }
            else {
                var i = 1;
                while (times[i] <= s)
                    i++;
                // times[i - 1] <= s < times[i]
                var t0 = times[i - 1];
                var span = times[i] - t0;
                var f = span > 0 ? (s - t0) / span : 1.0;
                x = cumX[i - 1] + (cumX[i] - cumX[i - 1]) * f;
                y = cumY[i - 1] + (cumY[i] - cumY[i - 1]) * f;
                // The points before i - 1 will not be needed again
                if (i > 1) {
                    var drop = i - 1;
                    times.splice(0, drop);
                    cumX.splice(0, drop);
                    cumY.splice(0, drop);
                    count -= drop;
                }
            }
        }

        stepX = x - emittedX;
        stepY = y - emittedY;
        emittedX = x;
        emittedY = y;

        if (ended) {
            clear();
            if (auto && evenFrames >= EVEN_FRAMES)
                resampling = false;
        }

        return stepX != 0 || stepY != 0;

    }

    /**
     * Ends the stream now: computes everything not emitted yet into `stepX` and `stepY`.
     * Returns `true` when there is a step to emit.
     */
    public function flush():Bool {

        stepX = 0;
        stepY = 0;
        if (!active)
            return false;
        stepX = receivedX - emittedX;
        stepY = receivedY - emittedY;
        emittedX = receivedX;
        emittedY = receivedY;
        clear();
        return stepX != 0 || stepY != 0;

    }

    function uneven():Void {

        evenFrames = 0;
        if (!resampling)
            startResampling();

    }

    /**
     * Starts resampling, possibly in the middle of a stream whose events went through as is:
     * the curve starts from the newest event, so nothing already emitted comes out again.
     */
    function startResampling():Void {

        resampling = true;
        if (lastEventTime >= 0)
            lastSampleTime = lastEventTime;

    }

    /**
     * The latency the samples aim at (seconds): the second largest time from an event to the
     * arrival of the next one among the last measures (one late event does not count), within
     * the bounds.
     */
    function targetLatency():Float {

        var second = 1.25 * period;
        if (ageCount >= 2) {
            var first = 0.0;
            second = 0.0;
            for (i in 0...ageCount) {
                var value = ages[i];
                if (value > first) {
                    second = first;
                    first = value;
                }
                else if (value > second) {
                    second = value;
                }
            }
        }
        var result = second + LATENCY_MARGIN;
        if (result < minLatency * period)
            result = minLatency * period;
        if (result > maxLatency * period)
            result = maxLatency * period;
        return result;

    }

    function clear():Void {

        active = false;
        count = 0;
        times.resize(0);
        cumX.resize(0);
        cumY.resize(0);

    }

    function push(time:Float, x:Float, y:Float):Void {

        if (count < times.length) {
            times[count] = time;
            cumX[count] = x;
            cumY[count] = y;
        }
        else {
            times.push(time);
            cumX.push(x);
            cumY.push(y);
        }
        count++;

    }

}
