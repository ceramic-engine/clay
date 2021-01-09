package clay;

/** A bunch of static extensions to make life easier. */
class Extensions<T> {

/// Array extensions

    #if !clay_debug_unsafe inline #end public static function unsafeGet<T>(array:Array<T>, index:Int):T {
#if clay_debug_unsafe
        if (index < 0 || index >= array.length) throw 'Invalid unsafeGet: index=$index length=${array.length}';
#end
#if cpp
        return cpp.NativeArray.unsafeGet(array, index);
#else
        return array[index];
#end
    }

    #if !clay_debug_unsafe inline #end public static function unsafeSet<T>(array:Array<T>, index:Int, value:T):Void {
#if clay_debug_unsafe
        if (index < 0 || index >= array.length) throw 'Invalid unsafeSet: index=$index length=${array.length}';
#end
#if cpp
        cpp.NativeArray.unsafeSet(array, index, value);
#else
        array[index] = value;
#end
    }

}
