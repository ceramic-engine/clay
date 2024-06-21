package clay;

#if (cpp || cs)
import sys.thread.Mutex;
#end

/**
 * An utility to enqueue functions and execute them in background, in a serialized way,
 * meaning it is garanteed that no function in this queue will be run in parallel. An enqueued
 * function will always be started after every previous function has finished executing.
 */
class BackgroundQueue {

    /**
     * Time interval between each checks to see if there is something to run.
     */
    public var checkInterval:Float;

    var runsInBackground:Bool = false;

    var stop:Bool = false;

    var pending:Array<Void->Void> = [];

    #if (cpp || cs)
    var mutex:Mutex;
    #end

    public function new(checkInterval:Float = 0.05) {

        this.checkInterval = checkInterval;

        #if (cpp || cs)
        mutex = new Mutex();
        runsInBackground = true;
        Runner.runInBackground(internalRunInBackground);
        #end

    }

    public function schedule(fn:Void->Void):Void {

        #if (cpp || cs)

        // Run in background with ceramic.Runner
        mutex.acquire();
        pending.push(fn);
        mutex.release();

        #elseif ceramic

        // Defer in main thread if background threading is not available
        ceramic.App.app.onceImmediate(fn);

        #else

        fn();

        #end

    }

    #if (cpp || cs)

    private function internalRunInBackground():Void {

        #if (android && linc_sdl)
        // This lets us attach thread to JNI.
        // Required because some JNI calls could be done in background
        sdl.SDL.androidGetJNIEnv();
        #end

        while (!stop) {
            var shouldSleep = true;

            mutex.acquire();
            if (pending.length > 0) {
                var fn = pending.pop();
                mutex.release();

                shouldSleep = false;
                fn();
            }
            else {
                mutex.release();
            }

            if (shouldSleep) {
                Sys.sleep(checkInterval);
            }
        }

    }

    #end

    public function destroy():Void {

        #if (cpp || cs)

        mutex.acquire();
        stop = true;
        mutex.release();

        #else

        stop = true;

        #end

    }

}
