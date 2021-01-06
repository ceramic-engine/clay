package clay;

import clay.Types;

class Input {

    /**
     * Clay app
     */
    public var app(default, null):Clay;

    var modState:ModState;

    function new(app:Clay) {

        this.app = app;
        
        modState = new ModState();
        modState.none = true;

    }

    public function init():Void {}

    public function shutdown():Void {}

    inline public function emitKeyDown(keycode:Int, scancode:Int, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {

        app.events.keyDown(keycode, scancode, repeat, mod, timestamp, windowId);

    }

    inline public function emitKeyUp(keycode:Int, scancode:Int, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {

        app.events.keyUp(keycode, scancode, repeat, mod, timestamp, windowId);

    }

    inline public function emitText(text:String, start:Int, length:Int, type:TextEventType, timestamp:Float, windowId:Int) {

        app.events.text(text, start, length, type, timestamp, windowId);

    }

    inline public function emitMouseMove(x:Int, y:Int, xrel:Int, yrel:Int, timestamp:Float, windowId:Int) {

        app.events.mouseMove(x, y, xrel, yrel, timestamp, windowId);

    }

    inline public function emitMouseDown(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {

        app.events.mouseDown(x, y, button, timestamp, windowId);

    }

    inline public function emitMouseUp(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {

        app.events.mouseUp(x, y, button, timestamp, windowId);

    }

    inline public function emitMouseWheel(x:Float, y:Float, timestamp:Float, windowId:Int) {

        app.events.mouseWheel(x, y, timestamp, windowId);

    }

    inline public function emitTouchDown(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {

        app.events.touchDown(x, y, dx, dy, touchId, timestamp);

    }

    inline public function emitTouchUp(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {

        app.events.touchUp(x, y, dx, dy, touchId, timestamp);

    }

    inline public function emitTouchMove(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {

        app.events.touchMove(x, y, dx, dy, touchId, timestamp);

    }

    inline public function emitGamepadAxis(gamepad:Int, axis:Int, value:Float, timestamp:Float) {

        app.events.gamepadAxis(gamepad, axis, value, timestamp);

    }

    inline public function emitGamepadDown(gamepad:Int, button:Int, value:Float, timestamp:Float) {

        app.events.gamepadDown(gamepad, button, value, timestamp);

    }

    inline public function emitGamepadUp(gamepad:Int, button:Int, value:Float, timestamp:Float) {

        app.events.gamepadUp(gamepad, button, value, timestamp);

    }

    inline public function emitGamepadDevice(gamepad:Int, id:String, type:GamepadDeviceEventType, timestamp:Float) {

        app.events.gamepadDevice(gamepad, id, type, timestamp);

    }

}
