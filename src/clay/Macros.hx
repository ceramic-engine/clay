package clay;

class Macros {

    macro static public function definedValue(define:String):haxe.macro.Expr {

        return macro $v{haxe.macro.Context.definedValue(define)};

    }

}