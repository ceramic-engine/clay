package clay.soloud;

import clay.audio.AudioData;
import soloud.Wav;
import soloud.WavStream;

class SoloudAudioData extends clay.audio.AudioData {

    @:unreflective public var wav:Wav;
    @:unreflective public var wavStream:WavStream;

    inline public function new(
        app:Clay,
        // ?wav:Wav,
        // ?wavStream:WavStream,
        options:AudioDataOptions
    ) {

        // this.wav = wav;
        // this.wavStream = wavStream;

        super(app, options);

    }

    override public function destroy() {

        if (destroyed)
            return;

        if (wav != null) {
            wav.destroy();
            wav = untyped __cpp__('NULL');
        }

        if (wavStream != null) {
            wavStream.destroy();
            wavStream = untyped __cpp__('NULL');
        }

        super.destroy();

    }

}
