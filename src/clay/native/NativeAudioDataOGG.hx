package clay.native;

import clay.Types;
import clay.audio.AudioData;
import clay.buffers.Uint8Array;
import ogg.Ogg;

class NativeAudioDataOGG extends clay.audio.AudioData {

    public var handle:FileHandle;

    public var oggFile:OggVorbisFile;

    inline public function new(app:Clay, handle:FileHandle, oggFile:OggVorbisFile, options:AudioDataOptions) {

        this.handle = handle;
        this.oggFile = oggFile;

        super(app, options);

    }

    override public function destroy() {

        if (handle != null) {
            app.io.fileClose(handle);
        }

        handle = null;
        Ogg.ov_clear(oggFile);
        oggFile = null;

        super.destroy();

    }

    override public function seek(to:Int):Bool {

        // pcm seek is in samples, not bytes
        // TODO ogg is always 16?
        var toSamples = haxe.Int64.ofInt(Std.int(to/16));
        var res = Ogg.ov_pcm_seek(oggFile, toSamples);

        return (res == 0);

    }

    override public function portion(into:Uint8Array, start:Int, len:Int, intoResult:Array<Int>):Array<Int> {

        var complete = false;
        var word = 2; // 1 for 8 bit, 2 for 16 bit. 2 is typical
        var sgned = 1; // 0 for unsigned, 1 is typical
        var bitStream = 1;

        var readLen = len;

        #if clay_debug_audio_verbose
        Log.debug('Audio / OGG > requested ogg portion start $start / len $len');
        #end

        var st = Ogg.ov_time_tell(oggFile);
        var sp = Ogg.ov_pcm_tell(oggFile);
        var sr = Ogg.ov_raw_tell(oggFile);
        var ct = Ogg.ov_time_total(oggFile, -1);
        var cp = Ogg.ov_pcm_total(oggFile, -1);
        var cr = Ogg.ov_raw_total(oggFile, -1);

        #if clay_debug_audio_verbose
        Log.debug('Audio / OGG > tell time $st / $ct');
        Log.debug('Audio / OGG > tell pcm $sp / $cp');
        Log.debug('Audio / OGG > tell raw $sr / $cr');
        #end

        if (start != -1) {
            seek(start);
        }

        // Resize to fit the requested length, but pad it slightly to align
        // var byteGap = (readLen & 0x03);
        // outBuffer.resize(readLen + byteGap);
        // TODO check these alignment paddings

        var reading = true;
        var bytesLeft = readLen;
        var totalRead = 0;
        var bytesRead = 0;
        var OGG_BUFFER_LENGTH = 128;

        while (reading) {

            var readMax = OGG_BUFFER_LENGTH;

            if (bytesLeft < readMax) {
                readMax = bytesLeft;
            }

            // Read the decoded sound data
            bytesRead = Ogg.ov_read(oggFile, into.buffer, totalRead, readMax, OggEndian.TYPICAL, OggWord.TYPICAL, OggSigned.TYPICAL);

            totalRead += bytesRead;
            bytesLeft -= bytesRead;

            // At the end?
            if (bytesRead == 0) {
                reading = false;
                complete = true;
            }

            if (totalRead >= readLen) {
                reading = false;
            }

        }

        // We need the buffer length to reflect the real size,
        // Just in case it read shorter than requested
        if (totalRead != readLen) {
            var byteGap = (readLen & 0x03);
            #if clay_debug_audio_verbose
            Log.debug('Audio / OGG > total read doesn\'t match expected read: $totalRead / $readLen');
            #end
            // out_buffer.resize(total_read+byte_gap);
            //:todo: check these alignment paddings in snow alpha-2.0
        }

        intoResult[0] = totalRead;
        intoResult[1] = (complete) ? 1 : 0;

        return intoResult;

    }

}


@:allow(snow.core.native.assets.Assets)
class OGG {

    public static function fromFile(app:Clay, path:String, isStream:Bool):AudioData {

        Log.debug('Audio / from file isStream:$isStream `$path`');

        var handle = app.io.fileHandle(path, 'rb');

        return fromFileHandle(app, handle, path, isStream);

    }


    public static function fromBytes(app:Clay, path:String, bytes:Uint8Array):AudioData {

        Log.debug('Audio / from bytes `$path`');

        var handle = app.io.fileHandleFromMem(bytes, bytes.length);

        return fromFileHandle(app, handle, path, false);

    }

    public static function fromFileHandle(app:Clay, handle:FileHandle, path:String, isStream:Bool):AudioData {

        if (handle == null) return null;

        var oggFile = Ogg.newOggVorbisFile();

        var ogg = new NativeAudioDataOGG(app, handle, oggFile, {
            id:         path,
            isStream:   isStream,
            format:     OGG,
            samples:    null,
            length:     0,
            channels:   0,
            rate:       0
        });

        var oggResult = Ogg.ov_open_callbacks(ogg, oggFile, null, 0, {
            read_fn:  oggRead,
            seek_fn:  oggSeek,
            close_fn: null,
            tell_fn:  oggTell
        });

        if (oggResult < 0) {

            app.io.fileClose(handle);

            Log.error('Audio / ogg file failed to open!? / result:$oggResult code: ${codeToString(oggResult)}');

            return null;

        }

        var oggInfo = Ogg.ov_info(oggFile, -1);

        Log.debug('Audio / path: '+path);
        #if clay_debug_audio_verbose
        Log.debug('Audio / version: '+Std.int(oggInfo.version));
        Log.debug('Audio / serial: '+Std.int(Ogg.ov_serialnumber(oggFile,-1)));
        Log.debug('Audio / seekable: '+Std.int(Ogg.ov_seekable(oggFile)));
        Log.debug('Audio / streams: '+Std.int(Ogg.ov_streams(oggFile)));
        Log.debug('Audio / rate: '+Std.int(oggInfo.rate));
        Log.debug('Audio / channels: '+Std.int(oggInfo.channels));
        #end

        Log.debug('Audio / pcm: '+Std.string( Ogg.ov_pcm_total(oggFile,-1) ));
        #if clay_debug_audio_verbose
        Log.debug('Audio / raw: '+Std.string( Ogg.ov_raw_total(oggFile,-1) ));
        #end
        Log.debug('Audio / time: '+Std.string( Ogg.ov_time_total(oggFile,-1) ));

        #if clay_debug_audio_verbose
        Log.debug('Audio / ov_bitrate: ' + codeToString(Ogg.ov_bitrate(oggFile, -1)));
        Log.debug('Audio / ov_bitrate_instant: ' + codeToString(Ogg.ov_bitrate_instant(oggFile)));
        Log.debug('Audio / bitrate_lower: '+Std.int(oggInfo.bitrate_lower));
        Log.debug('Audio / bitrate_nominal: '+Std.int(oggInfo.bitrate_nominal));
        Log.debug('Audio / bitrate_upper: '+Std.int(oggInfo.bitrate_upper));
        Log.debug('Audio / bitrate_window: '+Std.int(oggInfo.bitrate_window));

        Log.debug('Audio / pcm tell: '+codeToString( cast Ogg.ov_pcm_tell(oggFile) ));
        Log.debug('Audio / raw tell: '+codeToString( cast Ogg.ov_raw_tell(oggFile) ));
        Log.debug('Audio / time tell: '+codeToString( cast Ogg.ov_time_tell(oggFile) ));
        #end

        var totalPcmLength : UInt = haxe.Int64.toInt(Ogg.ov_pcm_total(oggFile, -1)) * oggInfo.channels * 2;

        ogg.channels = oggInfo.channels;
        ogg.rate = Std.int(oggInfo.rate);
        ogg.length = totalPcmLength;
        var bitrate = Std.int(oggInfo.bitrate_nominal);

        ogg.seek(0);

        var comment = Ogg.ov_comment(oggFile, -1);
        #if clay_debug_audio_verbose
        Log.debug('Audio / vendor: ' + comment.vendor);
        for(c in comment.comments) {
            Log.debug('Audio /            $c');
        }
        #end

        if (!isStream) {
            Log.debug('Audio / samples: loading length of $totalPcmLength');
            ogg.samples = new Uint8Array(totalPcmLength);
            ogg.portion(ogg.samples, 0, totalPcmLength, []);
        } else {
            Log.debug('Audio / samples: streams don\'t load samples');
        }

        return ogg;

    }

/// Helpers

    /**
     * Converts return code to string
     */
    inline static function codeToString(code:OggCode) : String {
        return switch code {
            case OggCode.OV_EBADHEADER: 'OV_EBADHEADER';
            case OggCode.OV_EBADLINK: 'OV_EBADLINK';
            case OggCode.OV_EBADPACKET: 'OV_EBADPACKET';
            case OggCode.OV_EFAULT: 'OV_EFAULT';
            case OggCode.OV_EIMPL: 'OV_EIMPL';
            case OggCode.OV_EINVAL: 'OV_EINVAL';
            case OggCode.OV_ENOSEEK: 'OV_ENOSEEK';
            case OggCode.OV_ENOTAUDIO: 'OV_ENOTAUDIO';
            case OggCode.OV_ENOTVORBIS: 'OV_ENOTVORBIS';
            case OggCode.OV_EOF: 'OV_EOF';
            case OggCode.OV_EREAD: 'OV_EREAD';
            case OggCode.OV_EVERSION: 'OV_EVERSION';
            case OggCode.OV_FALSE: 'OV_FALSE';
            case OggCode.OV_HOLE: 'OV_HOLE';
            case _: '$code';
        }
    }

 /// OGG callbacks

    /**
     * Read function for ogg callbacks
     */
    static function oggRead(ogg:NativeAudioDataOGG, size:Int, nmemb:Int, data:haxe.io.BytesData):Int {

        var total = size * nmemb;
        var buffer = Uint8Array.fromBuffer(data, 0, data.length);

        // fileRead past the end of file may return 0 amount read,
        // which can mislead the amounts, so we work out how much is left if near the end
        var fileSize:Int = ogg.app.io.fileSize(ogg.handle);
        var fileCur = ogg.app.io.fileTell(ogg.handle);
        var readSize = Std.int(Math.min(fileSize - fileCur, total));

        var readN = ogg.app.io.fileRead(ogg.handle, buffer, readSize, 1);
        var read = (readN * readSize);

        return read;

    }

    /**
     * Seek function for ogg callbacks
     */
    static function oggSeek(ogg:NativeAudioDataOGG, offset:Int, whence:OggWhence):Void {

        var w:FileSeek = switch(whence) {
            case OGG_SEEK_CUR: CUR;
            case OGG_SEEK_END: END;
            case OGG_SEEK_SET: SET;
        }

        ogg.app.io.fileSeek(ogg.handle, offset, w);

    }

    /**
     * Tell function for ogg callbacks
     */
    static function oggTell(ogg:NativeAudioDataOGG):Int {

        var res = ogg.app.io.fileTell(ogg.handle);

        return res;

    }

}
