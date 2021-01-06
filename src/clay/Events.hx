package clay;

import clay.Types;

class Events {

    public function tick():Void {}

    public function freeze():Void {}

    public function unfreeze():Void {}

    #if clay_sdl

    public function sdlEvent(event:sdl.Event):Void {}

    #end

    public function keyDown(keycode:Int, scancode:Int, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {}

    public function keyUp(keycode:Int, scancode:Int, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {}

    public function text(text:String, start:Int, length:Int, type:TextEventType, timestamp:Float, windowId:Int) {}

    public function mouseMove(x:Int, y:Int, xrel:Int, yrel:Int, timestamp:Float, windowId:Int) {}

    public function mouseDown(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {}

    public function mouseUp(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {}

    public function mouseWheel(x:Float, y:Float, timestamp:Float, windowId:Int) {}

    public function touchDown(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {}

    public function touchUp(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {}

    public function touchMove(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {}

    public function gamepadAxis(gamepad:Int, axis:Int, value:Float, timestamp:Float) {}

    public function gamepadDown(gamepad:Int, button:Int, value:Float, timestamp:Float) {}

    public function gamepadUp(gamepad:Int, button:Int, value:Float, timestamp:Float) {}

    public function gamepadDevice(gamepad:Int, id:String, type:GamepadDeviceEventType, timestamp:Float) {}

    public function windowEvent(type:WindowEventType, timestamp:Float, windowId:Int, x:Int, y:Int):Void {}

    public function appEvent(type:AppEventType):Void {}

}