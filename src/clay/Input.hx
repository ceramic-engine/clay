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

    inline public function emitKeyDown(keyCode:KeyCode, scanCode:ScanCode, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {

        app.throttle.markActive();

        app.events.keyDown(keyCode, scanCode, repeat, mod, timestamp, windowId);

    }

    inline public function emitKeyUp(keyCode:KeyCode, scanCode:ScanCode, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {

        app.throttle.markActive();

        app.events.keyUp(keyCode, scanCode, repeat, mod, timestamp, windowId);

    }

    inline public function emitText(text:String, start:Int, length:Int, type:TextEventType, timestamp:Float, windowId:Int) {

        app.throttle.markActive();

        app.events.text(text, start, length, type, timestamp, windowId);

    }

    inline public function emitMouseMove(x:Int, y:Int, xrel:Int, yrel:Int, timestamp:Float, windowId:Int) {

        app.throttle.markActive();

        app.events.mouseMove(x, y, xrel, yrel, timestamp, windowId);

    }

    inline public function emitMouseDown(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {

        app.throttle.markActive();

        app.events.mouseDown(x, y, button, timestamp, windowId);

    }

    inline public function emitMouseUp(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {

        app.throttle.markActive();

        app.events.mouseUp(x, y, button, timestamp, windowId);

    }

    inline public function emitMouseWheel(x:Float, y:Float, timestamp:Float, windowId:Int) {

        app.throttle.markActive();

        app.events.mouseWheel(x, y, timestamp, windowId);

    }

    /**
     * Scrolling with the deltas as the device reports them, unlike
     * `emitMouseWheel` which scales and rounds them into a unit of its own.
     * `deltaX` and `deltaY` are positive when the content should move up or
     * left (the browser `wheel` sign); `unit` is 0 for logical pixels
     * (trackpads, smooth scrolling) and 1 for lines (notched mouse wheels).
     * `phase` is the phase of the gesture the event belongs to, readable as
     * `mouseScrollPhase` while `Events.mouseScroll` runs.
     */
    inline public function emitMouseScroll(deltaX:Float, deltaY:Float, unit:Int, timestamp:Float, windowId:Int, phase:Int = 0) {

        app.throttle.markActive();

        mouseScrollPhase = phase;
        app.events.mouseScroll(deltaX, deltaY, unit, timestamp, windowId);
        mouseScrollPhase = 0;

    }

    /**
     * Phase of the scroll event being emitted (valid while
     * `Events.mouseScroll` runs, 0 otherwise): 0 none (a mouse wheel, or a
     * platform that does not tell), 1 gesture began, 2 gesture, 3 gesture
     * ended, 4 gesture cancelled, 5 momentum began, 6 momentum, 7 momentum
     * ended, 8 gesture may begin (the fingers touch the trackpad). Only the
     * SDL runtime on macOS reports phases (`linc_sdl_scroll_mac.mm`).
     */
    public var mouseScrollPhase(default, null):Int = 0;

    inline public function emitTouchDown(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {

        app.throttle.markActive();

        app.events.touchDown(x, y, dx, dy, touchId, timestamp);

    }

    inline public function emitTouchUp(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {

        app.throttle.markActive();

        app.events.touchUp(x, y, dx, dy, touchId, timestamp);

    }

    inline public function emitTouchMove(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {

        app.throttle.markActive();

        app.events.touchMove(x, y, dx, dy, touchId, timestamp);

    }

    inline public function emitTouchCancel(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {

        app.throttle.markActive();

        app.events.touchCancel(x, y, dx, dy, touchId, timestamp);

    }

    inline public function emitGamepadAxis(gamepad:Int, axis:Int, value:Float, timestamp:Float) {

        app.throttle.markActive();

        app.events.gamepadAxis(gamepad, axis, value, timestamp);

    }

    inline public function emitGamepadDown(gamepad:Int, button:Int, value:Float, timestamp:Float) {

        app.throttle.markActive();

        app.events.gamepadDown(gamepad, button, value, timestamp);

    }

    inline public function emitGamepadUp(gamepad:Int, button:Int, value:Float, timestamp:Float) {

        app.throttle.markActive();

        app.events.gamepadUp(gamepad, button, value, timestamp);

    }

    inline public function emitGamepadGyro(gamepad:Int, dx:Float, dy:Float, dz:Float, timestamp:Float) {

        app.throttle.markActive();

        app.events.gamepadGyro(gamepad, dx, dy, dz, timestamp);

    }

    inline public function emitGamepadDevice(gamepad:Int, name:String, type:GamepadDeviceEventType, timestamp:Float) {

        app.throttle.markActive();

        app.events.gamepadDevice(gamepad, name, type, timestamp);

    }

}
