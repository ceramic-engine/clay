package clay.native;

import clay.Types;
import clay.audio.AudioData;

import clay.buffers.Uint8Array;

@:structInit
class WavChunk {
    public var id:String;
    public var offset:Int;
    public var data:Uint8Array;
    public var dataLength:Int;
}

@:structInit
class WavHandle {
    public var handle:FileHandle;
    public var offset:Int;
}

class NativeAudioDataWAV extends AudioData {

    public var dataOffset:Int;

    public var handle:FileHandle;

    inline public function new(app:Clay, handle:FileHandle, offset:Int, options:AudioDataOptions) {

        this.handle = handle;
        this.dataOffset = offset;

        super(app, options);

    }

    override public function destroy() {

        if (handle != null) {
            app.io.fileClose(handle);
        }

        handle = null;

        super.destroy();

    }

    override public function seek(to:Int):Bool {

        var result = app.io.fileSeek(handle, dataOffset + to, FileSeek.SET);

        return result == 0;

    }

    override public function portion(into:Uint8Array, start:Int, len:Int, intoResult:Array<Int>):Array<Int> {

        if (start != -1) {
            seek(start + dataOffset);
        }

        var complete = false;
        var readLen = len;
        var currentPos = app.io.fileTell(handle) - dataOffset;
        var distanceToEnd = length - currentPos;

        if (distanceToEnd <= readLen) {
            readLen = distanceToEnd;
            complete = true;
        }

        if (readLen <= 0) {
            intoResult[0] = 0;
            intoResult[1] = 1;
            return intoResult;
        }

        Log.debug('Audio / WAV / reading $readLen bytes from $start');

        // Resize to fit the requested/remaining length
        var byteGap = (readLen & 0x03);

        var nElements = 1;
        var elementsRead = app.io.fileRead(handle, into, readLen, nElements);

        // If no elements were read, it was an error
        // or end of file so either way it's complete.
        if (elementsRead == 0) complete = true;

        Log.debug('Audio / WAV / total read $readLen bytes, complete? $complete');

        intoResult[0] = readLen;
        intoResult[1] = (complete) ? 1 : 0;

        return intoResult;

    }

}

class WAV {

    public static function fromFile(app:Clay, path:String, isStream:Bool):AudioData {

        var handle = app.io.fileHandle(path, 'rb');

        return fromFileHandle(app, handle, path, isStream);

    }

    public static function fromBytes(app:Clay, path:String, bytes:Uint8Array):AudioData {

        var handle = app.io.fileHandleFromMem(bytes, bytes.length);

        return fromFileHandle(app, handle, path, false);

    }

/// Helpers

    static var ID_DATA  = 'data'; 
    static var ID_FMT   = 'fmt '; 
    static var ID_WAVE  = 'WAVE';
    static var ID_RIFF  = 'RIFF';

    public static function fromFileHandle(app:Clay, handle:FileHandle, path:String, isStream:Bool):AudioData {

        if (handle == null) return null;

        var length = 0;
        var info = new NativeAudioDataWAV(app, handle, 0, {
            id         : path,
            isStream   : isStream,
            format     : WAV,
            samples    : null,
            length     : length,
            channels   : 1,
            rate       : 44100
        });

        var header = new Uint8Array(12);
        app.io.fileRead(handle, header, 12, 1);

        var bytes = header.toBytes();
        var fileId = bytes.getString(0, 4);
        var fileFormat = bytes.getString(8, 4);

        header = null;
        bytes = null;

        if (fileId != ID_RIFF) {
            Log.debug('Audio / WAV / file `$path` has invalid header (id `$fileId`, expected RIFF)');
            return null;
        }

        if(fileFormat != ID_WAVE) {
            Log.debug('Audio / WAV / file `$path` has invalid header (id `$fileFormat`, expected WAVE)');
            return null;
        }

        var foundData = false;
        var foundFormat = false;
        var limit = 0;

        while (!foundFormat || !foundData) {

            var chunk = readChunk(app, handle, isStream);

            if (chunk.id == ID_FMT) {
                foundFormat = true;

                // 16 bytes                 size /  at
                // short audioFormat;         2  /  0
                // short numChannels;         2  /  2
                // unsigned int sampleRate;   4  /  4
                // unsigned int byteRate;     4  /  8
                // short blockAlign;          2  /  12
                // short bitsPerSample;       2  /  14

                var format = chunk.data.toBytes();
                var bitrate = format.getInt32(8);
                info.bitsPerSample = format.getUInt16(14);
                info.channels = format.getUInt16(2);
                info.rate = format.getInt32(4);
                format = null;
            }

            if (chunk.id == ID_DATA) {
                foundData = true;
                info.samples = chunk.data;
                info.length = chunk.dataLength;
                info.dataOffset = chunk.offset;
            }

            chunk.data = null;
            chunk = null;

            ++limit;
            
            if (limit >= 32) break;

        }

        return info;

    }

    public static function readChunk(app:Clay, handle:FileHandle, isStream:Bool):WavChunk {

        var headerSize = 8;
        var header = new Uint8Array(headerSize);

        app.io.fileRead(handle, header, headerSize, 1);

        var headerBytes = header.toBytes();
        var chunkId = headerBytes.getString(0, 4);
        var chunkSize = headerBytes.getInt32(4);

        header = null;
        headerBytes = null;

        var data:Uint8Array = null;
        var pos = app.io.fileTell(handle);

        // We only read data/fmt chunks
        var isData = (chunkId == ID_DATA);
        var isFmt  = (chunkId == ID_FMT);
        var shouldRead = isData || isFmt;

        // We don't need to read the sample data if streaming
        if (isData && isStream) {
            shouldRead = false;
        }

        if (shouldRead) {
            data = new Uint8Array(chunkSize);
            app.io.fileRead(handle, data, chunkSize, 1);
        }
        else {
            app.io.fileSeek(handle, pos + headerSize + chunkSize, SET);
        }

        return {
            id: chunkId,
            offset: pos,
            data: data,
            dataLength: chunkSize
        };

    }

}
