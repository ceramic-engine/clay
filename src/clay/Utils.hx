package clay;

class Utils {

    static var _nextUniqueIntCursor:Int = 0;
    static var _nextUniqueInt0:Int = Std.int(Math.random() * 0x7ffffffe);
    static var _nextUniqueInt1:Int = Std.int(Date.now().getTime() * 0.0001);
    static var _nextUniqueInt2:Int = Std.int(Math.random() * 0x7ffffffe);
    static var _nextUniqueInt3:Int = Std.int(Math.random() * 0x7ffffffe);

    #if (cpp || cs || sys)
    static var _uniqueIdMutex:sys.thread.Mutex = new sys.thread.Mutex();
    #end

    /** Provides an identifier which is garanteed to be unique on this local device.
        It however doesn't garantee that this identifier is not predictable. */
    public static function uniqueId():String {

        #if (cpp || cs || sys)
        _uniqueIdMutex.acquire();
        #end

        switch (_nextUniqueIntCursor) {
            case 0:
                _nextUniqueInt0 = (_nextUniqueInt0 + 1) % 0x7fffffff;
            case 1:
                _nextUniqueInt1 = (_nextUniqueInt1 + 1) % 0x7fffffff;
            case 2:
                _nextUniqueInt2 = (_nextUniqueInt2 + 1) % 0x7fffffff;
            case 3:
                _nextUniqueInt3 = (_nextUniqueInt3 + 1) % 0x7fffffff;
        }
        _nextUniqueIntCursor = (_nextUniqueIntCursor + 1) % 4;

        var result = base62Id(_nextUniqueInt0) + '-' + base62Id() + '-' + base62Id(_nextUniqueInt1) + '-' + base62Id() + '-' + base62Id(_nextUniqueInt2) + '-' + base62Id() + '-' + base62Id(_nextUniqueInt3);

        #if (cpp || cs || sys)
        _uniqueIdMutex.release();
        #end

        return result;

    }

    inline public static function base62Id(?val:Null<Int>):String {

        // http://www.anotherchris.net/csharp/friendly-unique-id-generation-part-2/#base62

        if (val == null) {
            val = Std.int(Math.random() * 0x7ffffffe);
        }

        inline function toChar(value:Int):String {
            if (value > 9) {
                var ascii = (65 + (value - 10));
                if (ascii > 90) { ascii += 6; }
                return String.fromCharCode(ascii);
            } else return Std.string(value).charAt(0);
        }

        var r = Std.int(val % 62);
        var q = Std.int(val / 62);
        if (q > 0) return base62Id(q) + toChar(r);
        else return Std.string(toChar(r));

    }

}
