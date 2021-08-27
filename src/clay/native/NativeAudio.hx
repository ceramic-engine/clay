package clay.native;

import clay.Types;
import clay.audio.AudioData;
import clay.audio.AudioFormat;
import clay.buffers.Uint8Array;
import clay.native.NativeAudioDataOGG;
import clay.native.NativeAudioDataPCM;
import clay.native.NativeAudioDataWAV;

class NativeAudio extends clay.base.BaseAudio {

    override function isSynchronous():Bool {

        return true;

    }

    override function loadData(path:String, isStream:Bool, format:AudioFormat, async:Bool = false, ?callback:(data:AudioData)->Void):AudioData {

        if (path == null)
            throw 'path is null!';

        if (format == null)
            format = AudioFormat.fromPath(path);

        if (async) {
            Clay.app.backgroundQueue.schedule(function() {
                var data = loadData(path, isStream, format, false);
                Runner.runInMain(function() {
                    if (callback != null) {
                        Immediate.push(() -> {
                            callback(data);
                        });
                    }
                });
            });
            return null;
        }

        var data:AudioData = switch format {
            case WAV: NativeAudioDataWAV.WAV.fromFile(app, path, isStream);
            case OGG: NativeAudioDataOGG.OGG.fromFile(app, path, isStream);
            case PCM: NativeAudioDataPCM.PCM.fromFile(app, path, isStream);
            case _: null;
        }

        if (callback != null) {
            Immediate.push(() -> {
                callback(data);
            });
        }
        return data;

    }

    /** Returns an AudioData instance from the given bytes */
    public static function dataFromBytes(app:Clay, id:String, bytes:Uint8Array, ?format:AudioFormat):AudioData {

        if (id == null)
            throw 'id is null!';
        if (bytes == null)
            throw 'bytes is null!';

        if (format == null) format = AudioFormat.fromPath(id);

        var info = switch format {
            case WAV: NativeAudioDataWAV.WAV.fromBytes(app, id, bytes);
            case OGG: NativeAudioDataOGG.OGG.fromBytes(app, id, bytes);
            case PCM: NativeAudioDataPCM.PCM.fromBytes(app, id, bytes);
            case _: null;
        }

        return info;

    }

}