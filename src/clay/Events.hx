package clay;

import clay.Types;
import clay.audio.AudioEvent;
import clay.audio.AudioHandle;

#if clay_sdl
import clay.sdl.SDL;
#end

#if clay_sdl
@:headerCode('#include <SDL3/SDL.h>')
#end
class Events {

    public function ready():Void {}

    public function tick(delta:Float):Void {}

    public function render():Void {}

    public function freeze():Void {}

    public function unfreeze():Void {}

    #if clay_sdl

    public function sdlEvent(event:SDLEvent):Void {}

    #end

    public function keyDown(keycode:Int, scancode:Int, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {}

    public function keyUp(keycode:Int, scancode:Int, repeat:Bool, mod:ModState, timestamp:Float, windowId:Int) {}

    public function text(text:String, start:Int, length:Int, type:TextEventType, timestamp:Float, windowId:Int) {}

    public function mouseMove(x:Int, y:Int, xrel:Int, yrel:Int, timestamp:Float, windowId:Int) {}

    public function mouseDown(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {}

    public function mouseUp(x:Int, y:Int, button:Int, timestamp:Float, windowId:Int) {}

    public function mouseWheel(x:Float, y:Float, timestamp:Float, windowId:Int) {}

    /** Scrolling with the deltas as the device reports them (`unit`: 0 pixels, 1 lines), see `Input.emitMouseScroll` */
    public function mouseScroll(deltaX:Float, deltaY:Float, unit:Int, timestamp:Float, windowId:Int) {}

    public function touchDown(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {}

    public function touchUp(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {}

    public function touchMove(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {}

    /** The system took over a touch (native gesture, touch removed): no `touchUp` follows from the platform */
    public function touchCancel(x:Float, y:Float, dx:Float, dy:Float, touchId:Int, timestamp:Float) {}

    public function gamepadAxis(gamepad:Int, axis:Int, value:Float, timestamp:Float) {}

    public function gamepadDown(gamepad:Int, button:Int, value:Float, timestamp:Float) {}

    public function gamepadUp(gamepad:Int, button:Int, value:Float, timestamp:Float) {}

    public function gamepadGyro(gamepad:Int, dx:Float, dy:Float, dz:Float, timestamp:Float) {}

    public function gamepadDevice(gamepad:Int, name:String, type:GamepadDeviceEventType, timestamp:Float) {}

    public function windowEvent(type:WindowEventType, timestamp:Float, windowId:Int, x:Int, y:Int):Void {}

    public function appEvent(type:AppEventType):Void {}

    public function audioEvent(event:AudioEvent, handle:AudioHandle):Void {}

    /**
     * The light or dark theme of the system changed (see
     * `runtime.isSystemThemeDark`).
     */
    public function systemThemeChange(dark:Bool):Void {}

    /**
     * Whether the user prefers scrollbars that only show while scrolling
     * changed (see `runtime.autoHideScrollbars`).
     */
    public function autoHideScrollbarsChange(autoHide:Bool):Void {}

    /**
     * An item of the native menu bar (`runtime.setMenuBar`) or of the dock
     * menu (`runtime.setDockMenu`) was chosen.
     */
    public function menuAction(id:Int):Void {}

    /**
     * The key down just emitted (`keyDown`) matches the shortcut of the
     * native menu bar item `id`: the menu left the key to the app first, and
     * the item runs only if the app decides so (it is not triggered by the
     * system).
     */
    public function menuKeyEquivalent(id:Int):Void {}

    /** A menu of the native menu bar, or the dock menu, opens. */
    public function menuWillOpen():Void {}

    /**
     * Whether the native menu bar item `id` can be chosen, asked
     * synchronously when the system validates the items.
     */
    public function menuItemEnabled(id:Int):Bool {
        return true;
    }

}
