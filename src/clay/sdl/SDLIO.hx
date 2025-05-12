package clay.sdl;

import clay.buffers.ArrayBufferView;
import clay.buffers.Uint8Array;
import clay.native.NativeIO;
import clay.sdl.SDL;

typedef FileHandle = SDLIOStreamPointer;

enum abstract FileSeek(Int) from Int to Int {
    var SET = SDL.SDL_IO_SEEK_SET;
    var CUR = SDL.SDL_IO_SEEK_CUR;
    var END = SDL.SDL_IO_SEEK_END;
}

@:headerCode('#include <SDL3/SDL.h>')
class SDLIO extends NativeIO {

    override public function isSynchronous():Bool {

        return true;

    }

    override function appPath():String {

        var path = SDL.getBasePath();
        if (path == null) path = '';

        return path;

    }

    override function appPathPrefs():String {

        var parts = Clay.app.appId.split('.');
        var appName = parts.pop();
        var org = parts.join('.');

        return SDL.getPrefPath(org, appName);

    }

    override function loadData(path:String, binary:Bool = false, async:Bool = false, ?callback:(data:Uint8Array)->Void):Uint8Array {

        if (path == null)
            throw 'Path is null!';

        var dest:Uint8Array = null;
        if (async) {
            Clay.app.backgroundQueue.schedule(function() {
                dest = _doLoadData(path, binary);
                Runner.runInMain(function() {
                    if (callback != null) {
                        Immediate.push(() -> {
                            callback(dest);
                        });
                    }
                });
            });
        }
        else {
            dest = _doLoadData(path, binary);
            if (callback != null) {
                Immediate.push(() -> {
                    callback(dest);
                });
            }
        }
        return dest;

    }

    private function _doLoadData(path:String, binary:Bool):Uint8Array {

        var file = SDL.ioFromFile(path, binary ? 'rb' : 'r');

        if (file == null) {
            return null;
        }
        var size = fileSize(file);
        var dest = new Uint8Array(size);

        if (size != 0) {
            // In SDL3, ioRead returns the number of bytes read directly
            var bytesRead = fileRead(file, dest, 1, size);
            if (bytesRead != size) {
                Log.warning('SDLIO / Warning: Expected to read $size bytes but got $bytesRead');
            }
        }

        // close + release the file handle
        fileClose(file);

        return dest;

    }

/// File IO

    public function fileHandle(path:String, mode:String = "rb"):FileHandle {

        return SDL.ioFromFile(path, mode);

    }

    public function fileHandleFromMem(mem:ArrayBufferView, size:Int):FileHandle {

        return SDL.ioFromMem(mem.buffer, size);

    }

    public function fileRead(file:FileHandle, dest:ArrayBufferView, size:Int, maxnum:Int):Int {

        if (file == null)
            throw 'Parameter `file` should not be null';

        // SDL3's ioRead directly reads total bytes, so we calculate the total bytes to read
        var totalBytes = size * maxnum;
        var bytesRead = SDL.ioRead(file, dest.buffer, totalBytes);

        // Return the number of items read (compatible with SDL2 API)
        if (size > 0) {
            return Std.int(bytesRead / size);
        }
        return 0;

    }

    public function fileWrite(file:FileHandle, src:ArrayBufferView, size:Int, num:Int):Int {

        if (file == null)
            throw 'Parameter `file` should not be null';

        // SDL3's ioWrite directly writes total bytes, so we calculate the total bytes to write
        var totalBytes = size * num;
        var bytesWritten = SDL.ioWrite(file, src.buffer, totalBytes);

        // Return the number of items written (compatible with SDL2 API)
        if (size > 0) {
            return Std.int(bytesWritten / size);
        }
        return 0;

    }

    public function fileSeek(file:FileHandle, offset:Int, whence:Int):Int {

        if (file == null)
            throw 'Parameter `file` should not be null';

        return SDL.ioSeek(file, offset, whence);

    }

    public function fileTell(file:FileHandle):Int {

        if (file == null)
            throw 'Parameter `file` should not be null';

        return SDL.ioTell(file);

    }

    public function fileClose(file:FileHandle):Int {

        if (file == null)
            throw 'Parameter `file` should not be null';

        // SDL3's ioClose returns bool, but the original API expects an int
        // Return 0 for success (consistent with SDL2 behavior)
        return SDL.ioClose(file) ? 0 : -1;

    }

    public function fileSize(handle:FileHandle):UInt {

        var cur = fileTell(handle);
        fileSeek(handle, 0, FileSeek.END);
        var size = fileTell(handle);
        fileSeek(handle, cur, FileSeek.SET);
        return size;

    }

}