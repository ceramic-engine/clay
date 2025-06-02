package clay.soloud;

import clay.audio.AudioHandle;
import clay.audio.AudioInstance;
import clay.audio.AudioSource;
import clay.audio.AudioState;

@:allow(clay.soloud.SoloudAudio)
class SoloudSound {

    var source:AudioSource = null;

    var soloudHandle:Int = -1;

    var audioInstance:AudioInstance = null;

    var handle:AudioHandle = -1;

    var state:AudioState = INVALID;

    var loop:Bool = false;

    var pan:Float = 0.0;

    var pitch:Float = 1.0;

    var volume:Float = 0.5;

    var timeResume:Float = -1;

    var timeResumeAppTime:Float = -1;

    var timePause:Float = -1;

    var channel:Int = -1;

    private function new() {
        //
    }

/// Pool

    static var _pool:Array<SoloudSound> = [];

    public static function get():SoloudSound {

        if (_pool.length > 0)
            return _pool.pop();
        else {
            var instance = new SoloudSound();
            return instance;
        }

    }

    public function recycle() {

        source = null;
        soloudHandle = -1;
        audioInstance = null;
        handle = -1;
        state = INVALID;
        loop = false;
        pan = 0.0;
        pitch = 1.0;
        timeResume = -1;
        timeResumeAppTime = -1;
        timePause = -1;
        channel = -1;
        _pool.push(this);

    }

}
