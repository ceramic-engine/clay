package clay;

class Log {

    public static function debug(message:String, ?pos:haxe.PosInfos):Void {

        #if clay_debug
        haxe.Log.trace('[debug] ' + message, pos);
        #end

    }

    public static function info(message:String, ?pos:haxe.PosInfos):Void {

        haxe.Log.trace('[info] ' + message, pos);

    }

    public static function warning(message:String, ?pos:haxe.PosInfos):Void {

        haxe.Log.trace('[warning] ' + message, pos);

    }

    public static function error(message:String, ?pos:haxe.PosInfos):Void {

        haxe.Log.trace('[error] ' + message, pos);

    }

    public static function success(message:String, ?pos:haxe.PosInfos):Void {

        haxe.Log.trace('[success] ' + message, pos);

    }

}
