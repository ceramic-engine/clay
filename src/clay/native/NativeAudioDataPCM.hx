package clay.native;

import clay.Types;
import clay.audio.AudioData;
import clay.buffers.Uint8Array;

class NativeAudioDataPCM extends AudioData {

    public var handle:FileHandle;

    inline public function new(app:Clay, handle:FileHandle, options:AudioDataOptions) {

        this.handle = handle;

        super(app, options);

    }

    override public function destroy() {

        if (handle != null) {
            app.io.fileClose(handle);
            handle = null;
        }

        app = null;
        handle = null;

        super.destroy();

    }

    override public function seek(to:Int):Bool {

        if (handle == null) return false;

        var result = app.io.fileSeek(handle, to, FileSeek.SET);

        return (result == 0);

    }

    override public function portion(into:Uint8Array, start:Int, len:Int, intoResult:Array<Int>):Array<Int> {

        inline function fail() {
            intoResult[0] = 0;
            intoResult[1] = 1;
            return intoResult;
        }

        if (handle == null) return fail();

        if (start != -1) {
            seek(start);
        }

        var complete = false;
        var readLen = len;
        var curPos = app.io.fileTell(handle);
        var distanceToEnd = length - curPos;

        if (distanceToEnd <= readLen) {
            readLen = distanceToEnd;
            complete = true;
        }

        if (readLen <= 0) return fail();

        Log.debug('Audio / PCM / reading $readLen bytes from $start');

        // resize to fit the requested/remaining length
        var byteGap = (readLen & 0x03);
        var nElements = 1;
        var elementsRead = app.io.fileRead(handle, into, readLen, nElements);

        // If no elements were read, it was an error
        // or end of file so either way it's complete.
        if (elementsRead == 0) complete = true;

        Log.debug('Audio / PCM / total read $readLen bytes, complete? $complete');

        intoResult[0] = readLen;
        intoResult[1] = (complete) ? 1 : 0;

        return intoResult;

    }

}


class PCM {

    public static function fromFile(app:Clay, path:String, isStream:Bool):AudioData {

        var handle = app.io.fileHandle(path, 'rb');
        if (handle == null) return null;

        var length = app.io.fileSize(handle);
        var samples:Uint8Array = null;

        if (!isStream) {
            samples = new Uint8Array(length);
            var read = app.io.fileRead(handle, samples, length, 1);
            if (read != length) {
                samples = null;
                return null;
            }
        }

        // The sound format values are sane defaults -
        // change these values right before creating the sound itself.

        return new NativeAudioDataPCM(app, handle, {
            id:         path,
            isStream:   isStream,
            format:     PCM,
            samples:    samples,
            length:     length,
            channels:   1,
            rate:       44100
        });

    }

    public static function fromBytes(app:Clay, id:String, bytes:Uint8Array):AudioData {

        return new NativeAudioDataPCM(app, null, {
            id:         id,
            isStream:   false,
            format:     PCM,
            samples:    bytes,
            length:     bytes.length,
            channels:   1,
            rate:       44100
        });

    }


}
