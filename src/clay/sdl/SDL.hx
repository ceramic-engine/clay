package clay.sdl;

import cpp.ConstCharStar;
import cpp.Float32;
import cpp.Int16;
import cpp.Pointer;
import cpp.RawConstPointer;
import cpp.RawPointer;
import cpp.UInt16;
import cpp.UInt32;
import cpp.UInt64;
import cpp.UInt8;
import haxe.io.BytesData;

// SDL Types
typedef SDLWindowID = UInt32;
typedef SDLDisplayID = UInt32;
typedef SDLJoystickID = UInt32;
typedef SDLWindowFlags = UInt64;
typedef SDLWindowFlagsPointer = RawPointer<UInt64>;
typedef SDLInitFlags = UInt32;
typedef SDLWindowPointer = RawPointer<SDLNativeWindow>;
typedef SDLGamepadPointer = Pointer<SDLNativeGamepad>;
typedef SDLJoystickPointer = RawPointer<SDLNativeJoystick>;
typedef SDLEventPointer = RawPointer<SDLNativeEvent>;
typedef SDLIOStreamPointer = RawPointer<SDLNativeIOStream>;
typedef SDLDisplayModeConstPointer = RawConstPointer<SDLDisplayMode>;
typedef SDLRectConstPointer = RawConstPointer<SDLNativeRect>;
typedef SDLRectPointer = RawPointer<SDLNativeRect>;
typedef SDLSizePointer = RawPointer<SDLNativeSize>;
typedef SDLPointPointer = RawPointer<SDLNativePoint>;

// Native types (opaque)
@:native("SDL_Window")
extern class SDLNativeWindow {}

@:unreflective
@:native("SDL_GLContext")
extern class SDLGLContext {
    inline function isNull():Bool return untyped __cpp__('{0} == 0', this);
}

@:native("SDL_Gamepad")
extern class SDLNativeGamepad {}

@:native("SDL_Joystick")
extern class SDLNativeJoystick {}

@:native("SDL_Event")
extern class SDLNativeEvent {
    var type:UInt32;
    var timestamp:UInt64;
}

@:native("SDL_DisplayMode")
extern class SDLDisplayMode {}

@:native("SDL_IOStream")
extern class SDLNativeIOStream {}

@:native("SDL_Rect")
extern class SDLNativeRect {}

@:native("::linc::sdl::SDLSize")
extern class SDLNativeSize {}

@:native("::linc::sdl::SDLPoint")
extern class SDLNativePoint {}

@:headerCode('#include "linc_sdl.h"')
abstract SDLRect(SDLRectPointer) {

    public function new(ptr:SDLRectPointer) {
        this = ptr;
    }

    @:to function toConstPointer():SDLRectConstPointer {
        return untyped __cpp__('(const SDL_Rect*){0}', this);
    }

    @:to function toPointer():SDLRectPointer {
        return untyped __cpp__('(SDL_Rect*){0}', this);
    }

    @:keep
    public var x(get, set):Int;
    inline function get_x():Int {
        return untyped __cpp__("{0}->x", this);
    }
    inline function set_x(x:Int):Int {
        return untyped __cpp__("{0}->x = {1}", this, x);
    }

    @:keep
    public var y(get, set):Int;
    inline function get_y():Int {
        return untyped __cpp__("{0}->y", this);
    }
    inline function set_y(y:Int):Int {
        return untyped __cpp__("{0}->y = {1}", this, y);
    }

    @:keep
    public var w(get, set):Int;
    inline function get_w():Int {
        return untyped __cpp__("{0}->w", this);
    }
    inline function set_w(w:Int):Int {
        return untyped __cpp__("{0}->w = {1}", this, w);
    }

    @:keep
    public var h(get, set):Int;
    inline function get_h():Int {
        return untyped __cpp__("{0}->h", this);
    }
    inline function set_h(h:Int):Int {
        return untyped __cpp__("{0}->h = {1}", this, h);
    }

}

@:headerCode('#include "linc_sdl.h"')
abstract SDLSize(SDLSizePointer) {

    public function new(ptr:SDLSizePointer) {
        this = ptr;
    }

    @:keep
    public var w(get, set):Int;
    inline function get_w():Int {
        return untyped __cpp__("{0}->w", this);
    }
    inline function set_w(w:Int):Int {
        return untyped __cpp__("{0}->w = {1}", this, w);
    }

    @:keep
    public var h(get, set):Int;
    inline function get_h():Int {
        return untyped __cpp__("{0}->h", this);
    }
    inline function set_h(h:Int):Int {
        return untyped __cpp__("{0}->h = {1}", this, h);
    }

}

@:headerCode('#include "linc_sdl.h"')
abstract SDLPoint(SDLPointPointer) {

    public function new(ptr:SDLPointPointer) {
        this = ptr;
    }

    @:keep
    public var x(get, set):Int;
    inline function get_x():Int {
        return untyped __cpp__("{0}->x", this);
    }
    inline function set_x(x:Int):Int {
        return untyped __cpp__("{0}->x = {1}", this, x);
    }

    @:keep
    public var y(get, set):Int;
    inline function get_y():Int {
        return untyped __cpp__("{0}->y", this);
    }
    inline function set_y(y:Int):Int {
        return untyped __cpp__("{0}->y = {1}", this, y);
    }

}

@:headerCode('#include <SDL3/SDL.h>')
abstract SDLEvent(SDLEventPointer) {

    public function new(ptr:SDLEventPointer) {
        this = ptr;
    }

    @:keep
    public var type(get, never):UInt32;
    inline function get_type():UInt32 {
        return untyped __cpp__("{0}->type", this);
    }

    @:keep
    public var timestamp(get, never):UInt64;
    inline function get_timestamp():UInt64 {
        return untyped __cpp__("{0}->common.timestamp", this);
    }

    // Window events
    @:keep
    public var windowID(get, never):SDLWindowID;
    inline function get_windowID():SDLWindowID {
        return untyped __cpp__("{0}->window.windowID", this);
    }

    @:keep
    public var windowData1(get, never):Int;
    inline function get_windowData1():Int {
        return untyped __cpp__("{0}->window.data1", this);
    }

    @:keep
    public var windowData2(get, never):Int;
    inline function get_windowData2():Int {
        return untyped __cpp__("{0}->window.data2", this);
    }

    // Key events
    @:keep
    public var keyDown(get, never):Bool;
    inline function get_keyDown():Bool {
        return untyped __cpp__("{0}->key.down", this);
    }

    @:keep
    public var keyRepeat(get, never):Bool;
    inline function get_keyRepeat():Bool {
        return untyped __cpp__("{0}->key.repeat", this);
    }

    @:keep
    public var keyScancode(get, never):UInt32;
    inline function get_keyScancode():UInt32 {
        return untyped __cpp__("{0}->key.scancode", this);
    }

    @:keep
    public var keycode(get, never):UInt32;
    inline function get_keycode():UInt32 {
        return untyped __cpp__("{0}->key.key", this);
    }

    @:keep
    public var keymod(get, never):UInt16;
    inline function get_keymod():UInt16 {
        return untyped __cpp__("{0}->key.mod", this);
    }

    // Mouse events
    @:keep
    public var mouseButton(get, never):UInt8;
    inline function get_mouseButton():UInt8 {
        return untyped __cpp__("{0}->button.button", this);
    }

    @:keep
    public var mouseX(get, never):Float;
    inline function get_mouseX():Float {
        return untyped __cpp__("{0}->button.x", this);
    }

    @:keep
    public var mouseY(get, never):Float;
    inline function get_mouseY():Float {
        return untyped __cpp__("{0}->button.y", this);
    }

    @:keep
    public var mouseDown(get, never):Bool;
    inline function get_mouseDown():Bool {
        return untyped __cpp__("{0}->button.down", this);
    }

    @:keep
    public var motionX(get, never):Float;
    inline function get_motionX():Float {
        return untyped __cpp__("{0}->motion.x", this);
    }

    @:keep
    public var motionY(get, never):Float;
    inline function get_motionY():Float {
        return untyped __cpp__("{0}->motion.y", this);
    }

    @:keep
    public var motionXrel(get, never):Float;
    inline function get_motionXrel():Float {
        return untyped __cpp__("{0}->motion.xrel", this);
    }

    @:keep
    public var motionYrel(get, never):Float;
    inline function get_motionYrel():Float {
        return untyped __cpp__("{0}->motion.yrel", this);
    }

    @:keep
    public var wheelX(get, never):Float;
    inline function get_wheelX():Float {
        return untyped __cpp__("{0}->wheel.x", this);
    }

    @:keep
    public var wheelY(get, never):Float;
    inline function get_wheelY():Float {
        return untyped __cpp__("{0}->wheel.y", this);
    }

    // Touch events
    @:keep
    public var tfingerId(get, never):UInt64;
    inline function get_tfingerId():UInt64 {
        return untyped __cpp__("{0}->tfinger.fingerID", this);
    }

    @:keep
    public var tfingerX(get, never):Float;
    inline function get_tfingerX():Float {
        return untyped __cpp__("{0}->tfinger.x", this);
    }

    @:keep
    public var tfingerY(get, never):Float;
    inline function get_tfingerY():Float {
        return untyped __cpp__("{0}->tfinger.y", this);
    }

    @:keep
    public var tfingerDx(get, never):Float;
    inline function get_tfingerDx():Float {
        return untyped __cpp__("{0}->tfinger.dx", this);
    }

    @:keep
    public var tfingerDy(get, never):Float;
    inline function get_tfingerDy():Float {
        return untyped __cpp__("{0}->tfinger.dy", this);
    }

    @:keep
    public var editText(get, never):String;
    inline function get_editText():String {
        return untyped __cpp__("::String({0}->edit.text)", this);
    }

    @:keep
    public var editStart(get, never):Int;
    inline function get_editStart():Int {
        return untyped __cpp__("{0}->edit.start", this);
    }

    @:keep
    public var editLength(get, never):Int;
    inline function get_editLength():Int {
        return untyped __cpp__("{0}->edit.length", this);
    }

    @:keep
    public var textText(get, never):String;
    inline function get_textText():String {
        return untyped __cpp__("::String({0}->text.text)", this);
    }

    // Gamepad events
    @:keep
    public var gdeviceWhich(get, never):SDLJoystickID;
    inline function get_gdeviceWhich():SDLJoystickID {
        return untyped __cpp__("{0}->gdevice.which", this);
    }

    @:keep
    public var gaxisWhich(get, never):SDLJoystickID;
    inline function get_gaxisWhich():SDLJoystickID {
        return untyped __cpp__("{0}->gaxis.which", this);
    }

    @:keep
    public var gaxisAxis(get, never):UInt8;
    inline function get_gaxisAxis():UInt8 {
        return untyped __cpp__("{0}->gaxis.axis", this);
    }

    @:keep
    public var gaxisValue(get, never):Int16;
    inline function get_gaxisValue():Int16 {
        return untyped __cpp__("{0}->gaxis.value", this);
    }

    @:keep
    public var gbuttonWhich(get, never):SDLJoystickID;
    inline function get_gbuttonWhich():SDLJoystickID {
        return untyped __cpp__("{0}->gbutton.which", this);
    }

    @:keep
    public var gbuttonButton(get, never):UInt8;
    inline function get_gbuttonButton():UInt8 {
        return untyped __cpp__("{0}->gbutton.button", this);
    }

    @:keep
    public var gbuttonDown(get, never):Bool;
    inline function get_gbuttonDown():Bool {
        return untyped __cpp__("{0}->gbutton.down", this);
    }

    @:keep
    public var gsensorWhich(get, never):SDLJoystickID;
    inline function get_gsensorWhich():SDLJoystickID {
        return untyped __cpp__("{0}->gsensor.which", this);
    }

    @:keep
    public var gsensorSensor(get, never):Int;
    inline function get_gsensorSensor():Int {
        return untyped __cpp__("{0}->gsensor.sensor", this);
    }

    @:keep
    public var gsensorData(get, never):Array<Float>;
    inline function get_gsensorData():Array<Float> {
        var data = new Array<Float>();
        data.push(untyped __cpp__("{0}->gsensor.data[0]", this));
        data.push(untyped __cpp__("{0}->gsensor.data[1]", this));
        data.push(untyped __cpp__("{0}->gsensor.data[2]", this));
        return data;
    }

    // Joystick events
    @:keep
    public var jaxisWhich(get, never):SDLJoystickID;
    inline function get_jaxisWhich():SDLJoystickID {
        return untyped __cpp__("{0}->jaxis.which", this);
    }

    @:keep
    public var jaxisAxis(get, never):UInt8;
    inline function get_jaxisAxis():UInt8 {
        return untyped __cpp__("{0}->jaxis.axis", this);
    }

    @:keep
    public var jaxisValue(get, never):Int16;
    inline function get_jaxisValue():Int16 {
        return untyped __cpp__("{0}->jaxis.value", this);
    }

    @:keep
    public var jbuttonWhich(get, never):SDLJoystickID;
    inline function get_jbuttonWhich():SDLJoystickID {
        return untyped __cpp__("{0}->jbutton.which", this);
    }

    @:keep
    public var jbuttonButton(get, never):UInt8;
    inline function get_jbuttonButton():UInt8 {
        return untyped __cpp__("{0}->jbutton.button", this);
    }

    @:keep
    public var jbuttonDown(get, never):Bool;
    inline function get_jbuttonDown():Bool {
        return untyped __cpp__("{0}->jbutton.down", this);
    }

    @:keep
    public var jdeviceWhich(get, never):SDLJoystickID;
    inline function get_jdeviceWhich():SDLJoystickID {
        return untyped __cpp__("{0}->jdevice.which", this);
    }
}

typedef SDLSurfacePointer = RawPointer<SDLNativeSurface>;

@:native("SDL_Surface")
extern class SDLNativeSurface {}

class SDL {

    @:keep public static function bind():Void {
        SDL_Extern.bind();
    }

    inline public static function init():Bool {
        return SDL_Extern.init();
    }

    inline public static function quit():Void {
        SDL_Extern.quit();
    }

    inline public static function setHint(name:String, value:String):Bool {
        return SDL_Extern.setHint(name, value);
    }

    inline public static function setLCNumericCLocale():Void {
        SDL_Extern.setLCNumericCLocale();
    }

    inline public static function initSubSystem(flags:UInt32):Bool {
        return SDL_Extern.initSubSystem(flags);
    }

    inline public static function quitSubSystem(flags:UInt32):Void {
        SDL_Extern.quitSubSystem(flags);
    }

    inline public static function setVideoDriver(driver:String):Bool {
        return SDL_Extern.setVideoDriver(driver);
    }

    inline public static function getError():String {
        return SDL_Extern.getError();
    }

    inline public static function createWindow(title:String, x:Int, y:Int, width:Int, height:Int, flags:SDLWindowFlags):SDLWindowPointer {
        return SDL_Extern.createWindow(title, x, y, width, height, flags);
    }

    inline public static function getWindowID(window:SDLWindowPointer):SDLWindowID {
        return SDL_Extern.getWindowID(window);
    }

    inline public static function setWindowTitle(window:SDLWindowPointer, title:String):Void {
        SDL_Extern.setWindowTitle(window, title);
    }

    inline public static function setWindowBordered(window:SDLWindowPointer, bordered:Bool):Void {
        SDL_Extern.setWindowBordered(window, bordered);
    }

    inline public static function setWindowFullscreenMode(window:SDLWindowPointer, mode:SDLDisplayModeConstPointer):Bool {
        return SDL_Extern.setWindowFullscreenMode(window, mode);
    }

    inline public static function setWindowFullscreen(window:SDLWindowPointer, fullscreen:Bool):Bool {
        return SDL_Extern.setWindowFullscreen(window, fullscreen);
    }


    #if mac
    public static function setWindowFullscreenSpace(window:SDLWindowPointer, state:Bool):Bool {
        // TODO
        return false;
    }

    public static function isWindowInFullscreenSpace(window:SDLWindowPointer):Bool {
        // TODO
        return false;
    }
    #end

    inline public static function getWindowSize(window:SDLWindowPointer, size:SDLSize):Bool {
        return SDL_Extern.getWindowSize(window, size);
    }

    inline public static function getWindowSizeInPixels(window:SDLWindowPointer, size:SDLSize):Bool {
        return SDL_Extern.getWindowSizeInPixels(window, size);
    }

    inline public static function getWindowPosition(window:SDLWindowPointer, position:SDLPoint):Bool {
        return SDL_Extern.getWindowPosition(window, position);
    }

    inline public static function getWindowFullscreenMode(window:SDLWindowPointer):SDLDisplayModeConstPointer {
        return SDL_Extern.getWindowFullscreenMode(window);
    }

    inline public static function getDesktopDisplayMode(displayID:SDLDisplayID):SDLDisplayModeConstPointer {
        return SDL_Extern.getDesktopDisplayMode(displayID);
    }

    inline public static function getPrimaryDisplay():SDLDisplayID {
        return SDL_Extern.getPrimaryDisplay();
    }

    inline public static function getDisplayForWindow(window:SDLWindowPointer):SDLDisplayID {
        return SDL_Extern.getDisplayForWindow(window);
    }

    public static function getWindowFlags(window:SDLWindowPointer):SDLWindowFlags {
        final flags:SDLWindowFlags = 0;
        SDL_Extern.getWindowFlags(window, untyped __cpp__('&{0}', flags));
        return flags;
    }

    inline public static function GL_SetAttribute(attr:Int, value:Int):Bool {
        return SDL_Extern.GL_SetAttribute(attr, value);
    }

    inline public static function GL_CreateContext(window:SDLWindowPointer):SDLGLContext {
        return SDL_Extern.GL_CreateContext(window);
    }

    inline public static function GL_GetCurrentContext():SDLGLContext {
        return SDL_Extern.GL_GetCurrentContext();
    }

    inline public static function GL_GetAttribute(attr:Int):Int {
        return SDL_Extern.GL_GetAttribute(attr);
    }

    inline public static function GL_MakeCurrent(window:SDLWindowPointer, context:SDLGLContext):Bool {
        return SDL_Extern.GL_MakeCurrent(window, context);
    }

    inline public static function GL_SwapWindow(window:SDLWindowPointer):Bool {
        return SDL_Extern.GL_SwapWindow(window);
    }

    inline public static function GL_SetSwapInterval(interval:Int):Bool {
        return SDL_Extern.GL_SetSwapInterval(interval);
    }

    inline public static function GL_DestroyContext(context:SDLGLContext):Void {
        SDL_Extern.GL_DestroyContext(context);
    }

    inline public static function getTicks():UInt64 {
        return SDL_Extern.getTicks();
    }

    inline public static function delay(ms:UInt32):Void {
        SDL_Extern.delay(ms);
    }

    inline public static function pollEvent(event:SDLEventPointer):Bool {
        return SDL_Extern.pollEvent(event);
    }

    inline public static function pumpEvents():Void {
        SDL_Extern.pumpEvents();
    }

    inline public static function getNumJoysticks():Int {
        return SDL_Extern.getNumJoysticks();
    }

    inline public static function isGamepad(instance_id:SDLJoystickID):Bool {
        return SDL_Extern.isGamepad(instance_id);
    }

    inline public static function openJoystick(instance_id:SDLJoystickID):SDLJoystickPointer {
        return SDL_Extern.openJoystick(instance_id);
    }

    inline public static function closeJoystick(joystick:SDLJoystickPointer):Void {
        SDL_Extern.closeJoystick(joystick);
    }

    inline public static function openGamepad(instance_id:SDLJoystickID):SDLGamepadPointer {
        return SDL_Extern.openGamepad(instance_id);
    }

    inline public static function closeGamepad(gamepad:SDLGamepadPointer):Void {
        SDL_Extern.closeGamepad(gamepad);
    }

    inline public static function getGamepadNameForID(instance_id:SDLJoystickID):String {
        return SDL_Extern.getGamepadNameForID(instance_id);
    }

    inline public static function getJoystickNameForID(instance_id:SDLJoystickID):String {
        return SDL_Extern.getJoystickNameForID(instance_id);
    }

    inline public static function gamepadHasRumble(gamepad:SDLGamepadPointer):Bool {
        return SDL_Extern.gamepadHasRumble(gamepad);
    }

    inline public static function rumbleGamepad(gamepad:SDLGamepadPointer, low_frequency_rumble:UInt16, high_frequency_rumble:UInt16, duration_ms:UInt32):Bool {
        return SDL_Extern.rumbleGamepad(gamepad, low_frequency_rumble, high_frequency_rumble, duration_ms);
    }

    inline public static function setGamepadSensorEnabled(gamepad:SDLGamepadPointer, type:Int, enabled:Bool):Bool {
        return SDL_Extern.setGamepadSensorEnabled(gamepad, type, enabled);
    }

    inline public static function getJoystickID(joystick:SDLJoystickPointer):SDLJoystickID {
        return SDL_Extern.getJoystickID(joystick);
    }

    #if (ios || tvos)
    static var iOSAnimationCallback:()->Void = null;

    static function handleiOSAnimationCallback():Void {
        iOSAnimationCallback();
    }

    inline public static function setiOSAnimationCallback(window:SDLWindowPointer, callback:()->Void):Bool {
        SDL.iOSAnimationCallback = callback;
        return SDL_Extern.setiOSAnimationCallback(window, cpp.Callable.fromStaticFunction(handleiOSAnimationCallback));
    }
    #end

    static var eventWatcher:(event:UInt32)->Void = null;

    static function handleEventWatch(e:SDLEvent):Int {
        eventWatcher(e.type);
        return 1;
    }

    public static function setEventWatch(window:SDLWindowPointer, eventWatcher:(event:UInt32)->Void):Bool {
        SDL.eventWatcher = eventWatcher;
        return SDL_Extern.setEventWatch(window, cpp.Callable.fromStaticFunction(handleEventWatch));
    }


    inline public static function getDisplayContentScale(displayID:SDLDisplayID):Float {
        return SDL_Extern.getDisplayContentScale(displayID);
    }

    inline public static function getDisplayUsableBounds(displayID:SDLDisplayID, rect:SDLRect):Void {
        SDL_Extern.getDisplayUsableBounds(displayID, rect);
    }

    inline public static function getBasePath():String {
        return SDL_Extern.getBasePath();
    }

    inline public static function startTextInput(window:SDLWindowPointer):Void {
        SDL_Extern.startTextInput(window);
    }

    inline public static function stopTextInput(window:SDLWindowPointer):Void {
        SDL_Extern.stopTextInput(window);
    }

    inline public static function setTextInputArea(window:SDLWindowPointer, rect:SDLRect, cursor:Int):Void {
        SDL_Extern.setTextInputArea(window, rect, cursor);
    }

    // IO operations
    inline public static function ioFromFile(file:String, mode:String):SDLIOStreamPointer {
        return SDL_Extern.ioFromFile(file, mode);
    }

    inline public static function ioFromMem(mem:BytesData, size:Int):SDLIOStreamPointer {
        return SDL_Extern.ioFromMem(mem, size);
    }

    inline public static function ioRead(context:SDLIOStreamPointer, dest:BytesData, size:Int):Int {
        return SDL_Extern.ioRead(context, dest, size);
    }

    inline public static function ioWrite(context:SDLIOStreamPointer, src:BytesData, size:Int):Int {
        return SDL_Extern.ioWrite(context, src, size);
    }

    inline public static function ioSeek(context:SDLIOStreamPointer, offset:Int, whence:Int):Int {
        return SDL_Extern.ioSeek(context, offset, whence).toInt();
    }

    inline public static function ioTell(context:SDLIOStreamPointer):Int {
        return SDL_Extern.ioTell(context).toInt();
    }

    inline public static function ioClose(context:SDLIOStreamPointer):Bool {
        return SDL_Extern.ioClose(context);
    }

    // Path operations
    inline public static function getPrefPath(org:String, app:String):String {
        var result = SDL_Extern.getPrefPath(org, app);
        return result;
    }

    inline public static function hasClipboardText():Bool {
        return SDL_Extern.hasClipboardText();
    }

    inline public static function getClipboardText():String {
        return SDL_Extern.getClipboardText();
    }

    inline public static function setClipboardText(text:String):Bool {
        return SDL_Extern.setClipboardText(text);
    }

    inline public static function byteOrderIsBigEndian():Bool {
        return untyped __cpp__("SDL_BYTEORDER == SDL_BIG_ENDIAN");
    }

    inline public static function createRGBSurfaceFrom(pixels:BytesData, width:Int, height:Int, depth:Int, pitch:Int, rmask:UInt32, gmask:UInt32, bmask:UInt32, amask:UInt32):SDLSurfacePointer {
        return SDL_Extern.createRGBSurfaceFrom(pixels, width, height, depth, pitch, rmask, gmask, bmask, amask);
    }

    inline public static function freeSurface(surface:SDLSurfacePointer):Void {
        SDL_Extern.freeSurface(surface);
    }

    // IO seek constants
    @:native('LINC_SDL_IO_SEEK_SET') public static inline var SDL_IO_SEEK_SET:Int = 0;
    @:native('LINC_SDL_IO_SEEK_CUR') public static inline var SDL_IO_SEEK_CUR:Int = 1;
    @:native('LINC_SDL_IO_SEEK_END') public static inline var SDL_IO_SEEK_END:Int = 2;

    // Constants
    @:native('LINC_SDL_INIT_AUDIO') public static inline var SDL_INIT_AUDIO:UInt32 = 0x00000010;
    @:native('LINC_SDL_INIT_VIDEO') public static inline var SDL_INIT_VIDEO:UInt32 = 0x00000020;
    @:native('LINC_SDL_INIT_JOYSTICK') public static inline var SDL_INIT_JOYSTICK:UInt32 = 0x00000200;
    @:native('LINC_SDL_INIT_HAPTIC') public static inline var SDL_INIT_HAPTIC:UInt32 = 0x00001000;
    @:native('LINC_SDL_INIT_GAMEPAD') public static inline var SDL_INIT_GAMEPAD:UInt32 = 0x00002000;
    @:native('LINC_SDL_INIT_EVENTS') public static inline var SDL_INIT_EVENTS:UInt32 = 0x00004000;
    @:native('LINC_SDL_INIT_SENSOR') public static inline var SDL_INIT_SENSOR:UInt32 = 0x00008000;
    @:native('LINC_SDL_INIT_CAMERA') public static inline var SDL_INIT_CAMERA:UInt32 = 0x00010000;

    // Window flags (technically UInt64 in SDL3, but using UInt32 for Haxe compatibility)
    @:native('LINC_SDL_WINDOW_FULLSCREEN') public static inline var SDL_WINDOW_FULLSCREEN:UInt32 = 0x00000001;
    @:native('LINC_SDL_WINDOW_OPENGL') public static inline var SDL_WINDOW_OPENGL:UInt32 = 0x00000002;
    @:native('LINC_SDL_WINDOW_OCCLUDED') public static inline var SDL_WINDOW_OCCLUDED:UInt32 = 0x00000004;
    @:native('LINC_SDL_WINDOW_HIDDEN') public static inline var SDL_WINDOW_HIDDEN:UInt32 = 0x00000008;
    @:native('LINC_SDL_WINDOW_BORDERLESS') public static inline var SDL_WINDOW_BORDERLESS:UInt32 = 0x00000010;
    @:native('LINC_SDL_WINDOW_RESIZABLE') public static inline var SDL_WINDOW_RESIZABLE:UInt32 = 0x00000020;
    @:native('LINC_SDL_WINDOW_MINIMIZED') public static inline var SDL_WINDOW_MINIMIZED:UInt32 = 0x00000040;
    @:native('LINC_SDL_WINDOW_MAXIMIZED') public static inline var SDL_WINDOW_MAXIMIZED:UInt32 = 0x00000080;
    @:native('LINC_SDL_WINDOW_MOUSE_GRABBED') public static inline var SDL_WINDOW_MOUSE_GRABBED:UInt32 = 0x00000100;
    @:native('LINC_SDL_WINDOW_INPUT_FOCUS') public static inline var SDL_WINDOW_INPUT_FOCUS:UInt32 = 0x00000200;
    @:native('LINC_SDL_WINDOW_MOUSE_FOCUS') public static inline var SDL_WINDOW_MOUSE_FOCUS:UInt32 = 0x00000400;
    @:native('LINC_SDL_WINDOW_EXTERNAL') public static inline var SDL_WINDOW_EXTERNAL:UInt32 = 0x00000800;
    @:native('LINC_SDL_WINDOW_MODAL') public static inline var SDL_WINDOW_MODAL:UInt32 = 0x00001000;
    @:native('LINC_SDL_WINDOW_HIGH_PIXEL_DENSITY') public static inline var SDL_WINDOW_HIGH_PIXEL_DENSITY:UInt32 = 0x00002000;
    @:native('LINC_SDL_WINDOW_MOUSE_CAPTURE') public static inline var SDL_WINDOW_MOUSE_CAPTURE:UInt32 = 0x00004000;
    @:native('LINC_SDL_WINDOW_MOUSE_RELATIVE_MODE') public static inline var SDL_WINDOW_MOUSE_RELATIVE_MODE:UInt32 = 0x00008000;
    @:native('LINC_SDL_WINDOW_ALWAYS_ON_TOP') public static inline var SDL_WINDOW_ALWAYS_ON_TOP:UInt32 = 0x00010000;
    @:native('LINC_SDL_WINDOW_UTILITY') public static inline var SDL_WINDOW_UTILITY:UInt32 = 0x00020000;
    @:native('LINC_SDL_WINDOW_TOOLTIP') public static inline var SDL_WINDOW_TOOLTIP:UInt32 = 0x00040000;
    @:native('LINC_SDL_WINDOW_POPUP_MENU') public static inline var SDL_WINDOW_POPUP_MENU:UInt32 = 0x00080000;
    @:native('LINC_SDL_WINDOW_KEYBOARD_GRABBED') public static inline var SDL_WINDOW_KEYBOARD_GRABBED:UInt32 = 0x00100000;
    @:native('LINC_SDL_WINDOW_VULKAN') public static inline var SDL_WINDOW_VULKAN:UInt32 = 0x10000000;
    @:native('LINC_SDL_WINDOW_METAL') public static inline var SDL_WINDOW_METAL:UInt32 = 0x20000000;
    @:native('LINC_SDL_WINDOW_TRANSPARENT') public static inline var SDL_WINDOW_TRANSPARENT:UInt32 = 0x40000000;
    @:native('LINC_SDL_WINDOW_NOT_FOCUSABLE') public static inline var SDL_WINDOW_NOT_FOCUSABLE:UInt32 = 0x80000000;

    // Events
    @:native('LINC_SDL_EVENT_QUIT') public static inline var SDL_EVENT_QUIT:UInt32 = 0x100;

    // Window events
    @:native('LINC_SDL_EVENT_WINDOW_SHOWN') public static inline var SDL_EVENT_WINDOW_SHOWN:UInt32 = 0x202;
    @:native('LINC_SDL_EVENT_WINDOW_HIDDEN') public static inline var SDL_EVENT_WINDOW_HIDDEN:UInt32 = 0x203;
    @:native('LINC_SDL_EVENT_WINDOW_EXPOSED') public static inline var SDL_EVENT_WINDOW_EXPOSED:UInt32 = 0x204;
    @:native('LINC_SDL_EVENT_WINDOW_MOVED') public static inline var SDL_EVENT_WINDOW_MOVED:UInt32 = 0x205;
    @:native('LINC_SDL_EVENT_WINDOW_RESIZED') public static inline var SDL_EVENT_WINDOW_RESIZED:UInt32 = 0x206;
    @:native('LINC_SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED') public static inline var SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:UInt32 = 0x207;
    @:native('LINC_SDL_EVENT_WINDOW_METAL_VIEW_RESIZED') public static inline var SDL_EVENT_WINDOW_METAL_VIEW_RESIZED:UInt32 = 0x208;
    @:native('LINC_SDL_EVENT_WINDOW_MINIMIZED') public static inline var SDL_EVENT_WINDOW_MINIMIZED:UInt32 = 0x209;
    @:native('LINC_SDL_EVENT_WINDOW_MAXIMIZED') public static inline var SDL_EVENT_WINDOW_MAXIMIZED:UInt32 = 0x20A;
    @:native('LINC_SDL_EVENT_WINDOW_RESTORED') public static inline var SDL_EVENT_WINDOW_RESTORED:UInt32 = 0x20B;
    @:native('LINC_SDL_EVENT_WINDOW_MOUSE_ENTER') public static inline var SDL_EVENT_WINDOW_MOUSE_ENTER:UInt32 = 0x20C;
    @:native('LINC_SDL_EVENT_WINDOW_MOUSE_LEAVE') public static inline var SDL_EVENT_WINDOW_MOUSE_LEAVE:UInt32 = 0x20D;
    @:native('LINC_SDL_EVENT_WINDOW_FOCUS_GAINED') public static inline var SDL_EVENT_WINDOW_FOCUS_GAINED:UInt32 = 0x20E;
    @:native('LINC_SDL_EVENT_WINDOW_FOCUS_LOST') public static inline var SDL_EVENT_WINDOW_FOCUS_LOST:UInt32 = 0x20F;
    @:native('LINC_SDL_EVENT_WINDOW_CLOSE_REQUESTED') public static inline var SDL_EVENT_WINDOW_CLOSE_REQUESTED:UInt32 = 0x210;
    @:native('LINC_SDL_EVENT_WINDOW_HIT_TEST') public static inline var SDL_EVENT_WINDOW_HIT_TEST:UInt32 = 0x211;
    @:native('LINC_SDL_EVENT_WINDOW_ICCPROF_CHANGED') public static inline var SDL_EVENT_WINDOW_ICCPROF_CHANGED:UInt32 = 0x212;
    @:native('LINC_SDL_EVENT_WINDOW_DISPLAY_CHANGED') public static inline var SDL_EVENT_WINDOW_DISPLAY_CHANGED:UInt32 = 0x213;
    @:native('LINC_SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED') public static inline var SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED:UInt32 = 0x214;
    @:native('LINC_SDL_EVENT_WINDOW_SAFE_AREA_CHANGED') public static inline var SDL_EVENT_WINDOW_SAFE_AREA_CHANGED:UInt32 = 0x215;
    @:native('LINC_SDL_EVENT_WINDOW_OCCLUDED') public static inline var SDL_EVENT_WINDOW_OCCLUDED:UInt32 = 0x216;
    @:native('LINC_SDL_EVENT_WINDOW_ENTER_FULLSCREEN') public static inline var SDL_EVENT_WINDOW_ENTER_FULLSCREEN:UInt32 = 0x217;
    @:native('LINC_SDL_EVENT_WINDOW_LEAVE_FULLSCREEN') public static inline var SDL_EVENT_WINDOW_LEAVE_FULLSCREEN:UInt32 = 0x218;
    @:native('LINC_SDL_EVENT_WINDOW_DESTROYED') public static inline var SDL_EVENT_WINDOW_DESTROYED:UInt32 = 0x219;
    @:native('LINC_SDL_EVENT_WINDOW_HDR_STATE_CHANGED') public static inline var SDL_EVENT_WINDOW_HDR_STATE_CHANGED:UInt32 = 0x21A;

    // Key events
    @:native('LINC_SDL_EVENT_KEY_DOWN') public static inline var SDL_EVENT_KEY_DOWN:UInt32 = 0x300;
    @:native('LINC_SDL_EVENT_KEY_UP') public static inline var SDL_EVENT_KEY_UP:UInt32 = 0x301;
    @:native('LINC_SDL_EVENT_TEXT_EDITING') public static inline var SDL_EVENT_TEXT_EDITING:UInt32 = 0x302;
    @:native('LINC_SDL_EVENT_TEXT_INPUT') public static inline var SDL_EVENT_TEXT_INPUT:UInt32 = 0x303;
    @:native('LINC_SDL_EVENT_KEYMAP_CHANGED') public static inline var SDL_EVENT_KEYMAP_CHANGED:UInt32 = 0x304;
    @:native('LINC_SDL_EVENT_KEYBOARD_ADDED') public static inline var SDL_EVENT_KEYBOARD_ADDED:UInt32 = 0x305;
    @:native('LINC_SDL_EVENT_KEYBOARD_REMOVED') public static inline var SDL_EVENT_KEYBOARD_REMOVED:UInt32 = 0x306;
    @:native('LINC_SDL_EVENT_TEXT_EDITING_CANDIDATES') public static inline var SDL_EVENT_TEXT_EDITING_CANDIDATES:UInt32 = 0x307;

    // Mouse events
    @:native('LINC_SDL_EVENT_MOUSE_MOTION') public static inline var SDL_EVENT_MOUSE_MOTION:UInt32 = 0x400;
    @:native('LINC_SDL_EVENT_MOUSE_BUTTON_DOWN') public static inline var SDL_EVENT_MOUSE_BUTTON_DOWN:UInt32 = 0x401;
    @:native('LINC_SDL_EVENT_MOUSE_BUTTON_UP') public static inline var SDL_EVENT_MOUSE_BUTTON_UP:UInt32 = 0x402;
    @:native('LINC_SDL_EVENT_MOUSE_WHEEL') public static inline var SDL_EVENT_MOUSE_WHEEL:UInt32 = 0x403;
    @:native('LINC_SDL_EVENT_MOUSE_ADDED') public static inline var SDL_EVENT_MOUSE_ADDED:UInt32 = 0x404;
    @:native('LINC_SDL_EVENT_MOUSE_REMOVED') public static inline var SDL_EVENT_MOUSE_REMOVED:UInt32 = 0x405;

    // Joystick events
    @:native('LINC_SDL_EVENT_JOYSTICK_AXIS_MOTION') public static inline var SDL_EVENT_JOYSTICK_AXIS_MOTION:UInt32 = 0x600;
    @:native('LINC_SDL_EVENT_JOYSTICK_BALL_MOTION') public static inline var SDL_EVENT_JOYSTICK_BALL_MOTION:UInt32 = 0x601;
    @:native('LINC_SDL_EVENT_JOYSTICK_HAT_MOTION') public static inline var SDL_EVENT_JOYSTICK_HAT_MOTION:UInt32 = 0x602;
    @:native('LINC_SDL_EVENT_JOYSTICK_BUTTON_DOWN') public static inline var SDL_EVENT_JOYSTICK_BUTTON_DOWN:UInt32 = 0x603;
    @:native('LINC_SDL_EVENT_JOYSTICK_BUTTON_UP') public static inline var SDL_EVENT_JOYSTICK_BUTTON_UP:UInt32 = 0x604;
    @:native('LINC_SDL_EVENT_JOYSTICK_ADDED') public static inline var SDL_EVENT_JOYSTICK_ADDED:UInt32 = 0x605;
    @:native('LINC_SDL_EVENT_JOYSTICK_REMOVED') public static inline var SDL_EVENT_JOYSTICK_REMOVED:UInt32 = 0x606;
    @:native('LINC_SDL_EVENT_JOYSTICK_BATTERY_UPDATED') public static inline var SDL_EVENT_JOYSTICK_BATTERY_UPDATED:UInt32 = 0x607;
    @:native('LINC_SDL_EVENT_JOYSTICK_UPDATE_COMPLETE') public static inline var SDL_EVENT_JOYSTICK_UPDATE_COMPLETE:UInt32 = 0x608;

    // Gamepad events
    @:native('LINC_SDL_EVENT_GAMEPAD_AXIS_MOTION') public static inline var SDL_EVENT_GAMEPAD_AXIS_MOTION:UInt32 = 0x650;
    @:native('LINC_SDL_EVENT_GAMEPAD_BUTTON_DOWN') public static inline var SDL_EVENT_GAMEPAD_BUTTON_DOWN:UInt32 = 0x651;
    @:native('LINC_SDL_EVENT_GAMEPAD_BUTTON_UP') public static inline var SDL_EVENT_GAMEPAD_BUTTON_UP:UInt32 = 0x652;
    @:native('LINC_SDL_EVENT_GAMEPAD_ADDED') public static inline var SDL_EVENT_GAMEPAD_ADDED:UInt32 = 0x653;
    @:native('LINC_SDL_EVENT_GAMEPAD_REMOVED') public static inline var SDL_EVENT_GAMEPAD_REMOVED:UInt32 = 0x654;
    @:native('LINC_SDL_EVENT_GAMEPAD_REMAPPED') public static inline var SDL_EVENT_GAMEPAD_REMAPPED:UInt32 = 0x655;
    @:native('LINC_SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN') public static inline var SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN:UInt32 = 0x656;
    @:native('LINC_SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION') public static inline var SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION:UInt32 = 0x657;
    @:native('LINC_SDL_EVENT_GAMEPAD_TOUCHPAD_UP') public static inline var SDL_EVENT_GAMEPAD_TOUCHPAD_UP:UInt32 = 0x658;
    @:native('LINC_SDL_EVENT_GAMEPAD_SENSOR_UPDATE') public static inline var SDL_EVENT_GAMEPAD_SENSOR_UPDATE:UInt32 = 0x659;
    @:native('LINC_SDL_EVENT_GAMEPAD_UPDATE_COMPLETE') public static inline var SDL_EVENT_GAMEPAD_UPDATE_COMPLETE:UInt32 = 0x65A;
    @:native('LINC_SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED') public static inline var SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED:UInt32 = 0x65B;

    // Touch events
    @:native('LINC_SDL_EVENT_FINGER_DOWN') public static inline var SDL_EVENT_FINGER_DOWN:UInt32 = 0x700;
    @:native('LINC_SDL_EVENT_FINGER_UP') public static inline var SDL_EVENT_FINGER_UP:UInt32 = 0x701;
    @:native('LINC_SDL_EVENT_FINGER_MOTION') public static inline var SDL_EVENT_FINGER_MOTION:UInt32 = 0x702;
    @:native('LINC_SDL_EVENT_FINGER_CANCELED') public static inline var SDL_EVENT_FINGER_CANCELED:UInt32 = 0x703;

    // App events
    @:native('LINC_SDL_EVENT_TERMINATING') public static inline var SDL_EVENT_TERMINATING:UInt32 = 0x101;
    @:native('LINC_SDL_EVENT_LOW_MEMORY') public static inline var SDL_EVENT_LOW_MEMORY:UInt32 = 0x102;
    @:native('LINC_SDL_EVENT_WILL_ENTER_BACKGROUND') public static inline var SDL_EVENT_WILL_ENTER_BACKGROUND:UInt32 = 0x103;
    @:native('LINC_SDL_EVENT_DID_ENTER_BACKGROUND') public static inline var SDL_EVENT_DID_ENTER_BACKGROUND:UInt32 = 0x104;
    @:native('LINC_SDL_EVENT_WILL_ENTER_FOREGROUND') public static inline var SDL_EVENT_WILL_ENTER_FOREGROUND:UInt32 = 0x105;
    @:native('LINC_SDL_EVENT_DID_ENTER_FOREGROUND') public static inline var SDL_EVENT_DID_ENTER_FOREGROUND:UInt32 = 0x106;
    @:native('LINC_SDL_EVENT_LOCALE_CHANGED') public static inline var SDL_EVENT_LOCALE_CHANGED:UInt32 = 0x107;
    @:native('LINC_SDL_EVENT_SYSTEM_THEME_CHANGED') public static inline var SDL_EVENT_SYSTEM_THEME_CHANGED:UInt32 = 0x108;

    // Other events
    @:native('LINC_SDL_EVENT_CLIPBOARD_UPDATE') public static inline var SDL_EVENT_CLIPBOARD_UPDATE:UInt32 = 0x900;
    @:native('LINC_SDL_EVENT_DROP_FILE') public static inline var SDL_EVENT_DROP_FILE:UInt32 = 0x1000;
    @:native('LINC_SDL_EVENT_DROP_TEXT') public static inline var SDL_EVENT_DROP_TEXT:UInt32 = 0x1001;
    @:native('LINC_SDL_EVENT_DROP_BEGIN') public static inline var SDL_EVENT_DROP_BEGIN:UInt32 = 0x1002;
    @:native('LINC_SDL_EVENT_DROP_COMPLETE') public static inline var SDL_EVENT_DROP_COMPLETE:UInt32 = 0x1003;
    @:native('LINC_SDL_EVENT_DROP_POSITION') public static inline var SDL_EVENT_DROP_POSITION:UInt32 = 0x1004;
    @:native('LINC_SDL_EVENT_AUDIO_DEVICE_ADDED') public static inline var SDL_EVENT_AUDIO_DEVICE_ADDED:UInt32 = 0x1100;
    @:native('LINC_SDL_EVENT_AUDIO_DEVICE_REMOVED') public static inline var SDL_EVENT_AUDIO_DEVICE_REMOVED:UInt32 = 0x1101;
    @:native('LINC_SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED') public static inline var SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED:UInt32 = 0x1102;
    @:native('LINC_SDL_EVENT_SENSOR_UPDATE') public static inline var SDL_EVENT_SENSOR_UPDATE:UInt32 = 0x1200;

    // Pen events
    @:native('LINC_SDL_EVENT_PEN_PROXIMITY_IN') public static inline var SDL_EVENT_PEN_PROXIMITY_IN:UInt32 = 0x1300;
    @:native('LINC_SDL_EVENT_PEN_PROXIMITY_OUT') public static inline var SDL_EVENT_PEN_PROXIMITY_OUT:UInt32 = 0x1301;
    @:native('LINC_SDL_EVENT_PEN_DOWN') public static inline var SDL_EVENT_PEN_DOWN:UInt32 = 0x1302;
    @:native('LINC_SDL_EVENT_PEN_UP') public static inline var SDL_EVENT_PEN_UP:UInt32 = 0x1303;
    @:native('LINC_SDL_EVENT_PEN_BUTTON_DOWN') public static inline var SDL_EVENT_PEN_BUTTON_DOWN:UInt32 = 0x1304;
    @:native('LINC_SDL_EVENT_PEN_BUTTON_UP') public static inline var SDL_EVENT_PEN_BUTTON_UP:UInt32 = 0x1305;
    @:native('LINC_SDL_EVENT_PEN_MOTION') public static inline var SDL_EVENT_PEN_MOTION:UInt32 = 0x1306;
    @:native('LINC_SDL_EVENT_PEN_AXIS') public static inline var SDL_EVENT_PEN_AXIS:UInt32 = 0x1307;

    // Camera events
    @:native('LINC_SDL_EVENT_CAMERA_DEVICE_ADDED') public static inline var SDL_EVENT_CAMERA_DEVICE_ADDED:UInt32 = 0x1400;
    @:native('LINC_SDL_EVENT_CAMERA_DEVICE_REMOVED') public static inline var SDL_EVENT_CAMERA_DEVICE_REMOVED:UInt32 = 0x1401;
    @:native('LINC_SDL_EVENT_CAMERA_DEVICE_APPROVED') public static inline var SDL_EVENT_CAMERA_DEVICE_APPROVED:UInt32 = 0x1402;
    @:native('LINC_SDL_EVENT_CAMERA_DEVICE_DENIED') public static inline var SDL_EVENT_CAMERA_DEVICE_DENIED:UInt32 = 0x1403;

    // Render events
    @:native('LINC_SDL_EVENT_RENDER_TARGETS_RESET') public static inline var SDL_EVENT_RENDER_TARGETS_RESET:UInt32 = 0x2000;
    @:native('LINC_SDL_EVENT_RENDER_DEVICE_RESET') public static inline var SDL_EVENT_RENDER_DEVICE_RESET:UInt32 = 0x2001;
    @:native('LINC_SDL_EVENT_RENDER_DEVICE_LOST') public static inline var SDL_EVENT_RENDER_DEVICE_LOST:UInt32 = 0x2002;

    // GL attributes
    @:native('LINC_SDL_GL_RED_SIZE') public static inline var SDL_GL_RED_SIZE:Int = 0;
    @:native('LINC_SDL_GL_GREEN_SIZE') public static inline var SDL_GL_GREEN_SIZE:Int = 1;
    @:native('LINC_SDL_GL_BLUE_SIZE') public static inline var SDL_GL_BLUE_SIZE:Int = 2;
    @:native('LINC_SDL_GL_ALPHA_SIZE') public static inline var SDL_GL_ALPHA_SIZE:Int = 3;
    @:native('LINC_SDL_GL_BUFFER_SIZE') public static inline var SDL_GL_BUFFER_SIZE:Int = 4;
    @:native('LINC_SDL_GL_DOUBLEBUFFER') public static inline var SDL_GL_DOUBLEBUFFER:Int = 5;
    @:native('LINC_SDL_GL_DEPTH_SIZE') public static inline var SDL_GL_DEPTH_SIZE:Int = 6;
    @:native('LINC_SDL_GL_STENCIL_SIZE') public static inline var SDL_GL_STENCIL_SIZE:Int = 7;
    @:native('LINC_SDL_GL_ACCUM_RED_SIZE') public static inline var SDL_GL_ACCUM_RED_SIZE:Int = 8;
    @:native('LINC_SDL_GL_ACCUM_GREEN_SIZE') public static inline var SDL_GL_ACCUM_GREEN_SIZE:Int = 9;
    @:native('LINC_SDL_GL_ACCUM_BLUE_SIZE') public static inline var SDL_GL_ACCUM_BLUE_SIZE:Int = 10;
    @:native('LINC_SDL_GL_ACCUM_ALPHA_SIZE') public static inline var SDL_GL_ACCUM_ALPHA_SIZE:Int = 11;
    @:native('LINC_SDL_GL_STEREO') public static inline var SDL_GL_STEREO:Int = 12;
    @:native('LINC_SDL_GL_MULTISAMPLEBUFFERS') public static inline var SDL_GL_MULTISAMPLEBUFFERS:Int = 13;
    @:native('LINC_SDL_GL_MULTISAMPLESAMPLES') public static inline var SDL_GL_MULTISAMPLESAMPLES:Int = 14;
    @:native('LINC_SDL_GL_ACCELERATED_VISUAL') public static inline var SDL_GL_ACCELERATED_VISUAL:Int = 15;
    @:native('LINC_SDL_GL_CONTEXT_MAJOR_VERSION') public static inline var SDL_GL_CONTEXT_MAJOR_VERSION:Int = 17;
    @:native('LINC_SDL_GL_CONTEXT_MINOR_VERSION') public static inline var SDL_GL_CONTEXT_MINOR_VERSION:Int = 18;
    @:native('LINC_SDL_GL_CONTEXT_FLAGS') public static inline var SDL_GL_CONTEXT_FLAGS:Int = 19;
    @:native('LINC_SDL_GL_CONTEXT_PROFILE_MASK') public static inline var SDL_GL_CONTEXT_PROFILE_MASK:Int = 20;
    @:native('LINC_SDL_GL_SHARE_WITH_CURRENT_CONTEXT') public static inline var SDL_GL_SHARE_WITH_CURRENT_CONTEXT:Int = 21;
    @:native('LINC_SDL_GL_FRAMEBUFFER_SRGB_CAPABLE') public static inline var SDL_GL_FRAMEBUFFER_SRGB_CAPABLE:Int = 22;
    @:native('LINC_SDL_GL_CONTEXT_RELEASE_BEHAVIOR') public static inline var SDL_GL_CONTEXT_RELEASE_BEHAVIOR:Int = 23;
    @:native('LINC_SDL_GL_CONTEXT_RESET_NOTIFICATION') public static inline var SDL_GL_CONTEXT_RESET_NOTIFICATION:Int = 24;
    @:native('LINC_SDL_GL_CONTEXT_NO_ERROR') public static inline var SDL_GL_CONTEXT_NO_ERROR:Int = 25;
    @:native('LINC_SDL_GL_FLOATBUFFERS') public static inline var SDL_GL_FLOATBUFFERS:Int = 26;
    @:native('LINC_SDL_GL_EGL_PLATFORM') public static inline var SDL_GL_EGL_PLATFORM:Int = 27;

    // GL Profile
    @:native('LINC_SDL_GL_CONTEXT_PROFILE_CORE') public static inline var SDL_GL_CONTEXT_PROFILE_CORE:Int = 0x0001;
    @:native('LINC_SDL_GL_CONTEXT_PROFILE_COMPATIBILITY') public static inline var SDL_GL_CONTEXT_PROFILE_COMPATIBILITY:Int = 0x0002;
    @:native('LINC_SDL_GL_CONTEXT_PROFILE_ES') public static inline var SDL_GL_CONTEXT_PROFILE_ES:Int = 0x0004;

    // Keymod masks
    @:native('LINC_SDL_KMOD_NONE') public static inline var SDL_KMOD_NONE:UInt16 = 0x0000;
    @:native('LINC_SDL_KMOD_LSHIFT') public static inline var SDL_KMOD_LSHIFT:UInt16 = 0x0001;
    @:native('LINC_SDL_KMOD_RSHIFT') public static inline var SDL_KMOD_RSHIFT:UInt16 = 0x0002;
    @:native('LINC_SDL_KMOD_LCTRL') public static inline var SDL_KMOD_LCTRL:UInt16 = 0x0040;
    @:native('LINC_SDL_KMOD_RCTRL') public static inline var SDL_KMOD_RCTRL:UInt16 = 0x0080;
    @:native('LINC_SDL_KMOD_LALT') public static inline var SDL_KMOD_LALT:UInt16 = 0x0100;
    @:native('LINC_SDL_KMOD_RALT') public static inline var SDL_KMOD_RALT:UInt16 = 0x0200;
    @:native('LINC_SDL_KMOD_LGUI') public static inline var SDL_KMOD_LGUI:UInt16 = 0x0400;
    @:native('LINC_SDL_KMOD_RGUI') public static inline var SDL_KMOD_RGUI:UInt16 = 0x0800;
    @:native('LINC_SDL_KMOD_NUM') public static inline var SDL_KMOD_NUM:UInt16 = 0x1000;
    @:native('LINC_SDL_KMOD_CAPS') public static inline var SDL_KMOD_CAPS:UInt16 = 0x2000;
    @:native('LINC_SDL_KMOD_MODE') public static inline var SDL_KMOD_MODE:UInt16 = 0x4000;
    @:native('LINC_SDL_KMOD_SCROLL') public static inline var SDL_KMOD_SCROLL:UInt16 = 0x8000;

    @:native('LINC_SDL_KMOD_CTRL') public static inline var SDL_KMOD_CTRL:UInt16 = SDL_KMOD_LCTRL | SDL_KMOD_RCTRL;
    @:native('LINC_SDL_KMOD_SHIFT') public static inline var SDL_KMOD_SHIFT:UInt16 = SDL_KMOD_LSHIFT | SDL_KMOD_RSHIFT;
    @:native('LINC_SDL_KMOD_ALT') public static inline var SDL_KMOD_ALT:UInt16 = SDL_KMOD_LALT | SDL_KMOD_RALT;
    @:native('LINC_SDL_KMOD_GUI') public static inline var SDL_KMOD_GUI:UInt16 = SDL_KMOD_LGUI | SDL_KMOD_RGUI;

    // Sensor types
    @:native('LINC_SDL_SENSOR_INVALID') public static inline var SDL_SENSOR_INVALID:Int = -1;
    @:native('LINC_SDL_SENSOR_UNKNOWN') public static inline var SDL_SENSOR_UNKNOWN:Int = 0;
    @:native('LINC_SDL_SENSOR_ACCEL') public static inline var SDL_SENSOR_ACCEL:Int = 1;
    @:native('LINC_SDL_SENSOR_GYRO') public static inline var SDL_SENSOR_GYRO:Int = 2;
    @:native('LINC_SDL_SENSOR_ACCEL_L') public static inline var SDL_SENSOR_ACCEL_L:Int = 3;
    @:native('LINC_SDL_SENSOR_GYRO_L') public static inline var SDL_SENSOR_GYRO_L:Int = 4;
    @:native('LINC_SDL_SENSOR_ACCEL_R') public static inline var SDL_SENSOR_ACCEL_R:Int = 5;
    @:native('LINC_SDL_SENSOR_GYRO_R') public static inline var SDL_SENSOR_GYRO_R:Int = 6;

    // Window position
    @:native('LINC_SDL_WINDOWPOS_UNDEFINED_MASK') public static inline var SDL_WINDOWPOS_UNDEFINED_MASK:UInt32 = 0x1FFF0000;
    @:native('LINC_SDL_WINDOWPOS_CENTERED_MASK') public static inline var SDL_WINDOWPOS_CENTERED_MASK:UInt32 = 0x2FFF0000;
    @:native('LINC_SDL_WINDOWPOS_UNDEFINED') public static inline var SDL_WINDOWPOS_UNDEFINED:UInt32 = SDL_WINDOWPOS_UNDEFINED_MASK;
    @:native('LINC_SDL_WINDOWPOS_CENTERED') public static inline var SDL_WINDOWPOS_CENTERED:UInt32 = SDL_WINDOWPOS_CENTERED_MASK;

    // Audio hints
    @:native('LINC_SDL_HINT_AUDIO_DEVICE_APP_ICON_NAME') public static inline var SDL_HINT_AUDIO_DEVICE_APP_ICON_NAME:String = "SDL_AUDIO_DEVICE_APP_ICON_NAME";
    @:native('LINC_SDL_HINT_AUDIO_DEVICE_SAMPLE_FRAMES') public static inline var SDL_HINT_AUDIO_DEVICE_SAMPLE_FRAMES:String = "SDL_AUDIO_DEVICE_SAMPLE_FRAMES";
    @:native('LINC_SDL_HINT_AUDIO_DEVICE_STREAM_ROLE') public static inline var SDL_HINT_AUDIO_DEVICE_STREAM_ROLE:String = "SDL_AUDIO_DEVICE_STREAM_ROLE";
    @:native('LINC_SDL_HINT_AUDIO_DRIVER') public static inline var SDL_HINT_AUDIO_DRIVER:String = "SDL_AUDIO_DRIVER";
    @:native('LINC_SDL_HINT_AUDIO_DUMMY_TIMESCALE') public static inline var SDL_HINT_AUDIO_DUMMY_TIMESCALE:String = "SDL_AUDIO_DUMMY_TIMESCALE";
    @:native('LINC_SDL_HINT_AUDIO_FORMAT') public static inline var SDL_HINT_AUDIO_FORMAT:String = "SDL_AUDIO_FORMAT";
    @:native('LINC_SDL_HINT_AUDIO_FREQUENCY') public static inline var SDL_HINT_AUDIO_FREQUENCY:String = "SDL_AUDIO_FREQUENCY";
    @:native('LINC_SDL_HINT_AUDIO_CHANNELS') public static inline var SDL_HINT_AUDIO_CHANNELS:String = "SDL_AUDIO_CHANNELS";
    @:native('LINC_SDL_HINT_AUDIO_ALSA_DEFAULT_DEVICE') public static inline var SDL_HINT_AUDIO_ALSA_DEFAULT_DEVICE:String = "SDL_AUDIO_ALSA_DEFAULT_DEVICE";
    @:native('LINC_SDL_HINT_AUDIO_DISK_INPUT_FILE') public static inline var SDL_HINT_AUDIO_DISK_INPUT_FILE:String = "SDL_AUDIO_DISK_INPUT_FILE";
    @:native('LINC_SDL_HINT_AUDIO_DISK_OUTPUT_FILE') public static inline var SDL_HINT_AUDIO_DISK_OUTPUT_FILE:String = "SDL_AUDIO_DISK_OUTPUT_FILE";
    @:native('LINC_SDL_HINT_AUDIO_DISK_TIMESCALE') public static inline var SDL_HINT_AUDIO_DISK_TIMESCALE:String = "SDL_AUDIO_DISK_TIMESCALE";
    @:native('LINC_SDL_HINT_AUDIO_INCLUDE_MONITORS') public static inline var SDL_HINT_AUDIO_INCLUDE_MONITORS:String = "SDL_AUDIO_INCLUDE_MONITORS";

    // Video hints
    @:native('LINC_SDL_HINT_VIDEO_DRIVER') public static inline var SDL_HINT_VIDEO_DRIVER:String = "SDL_VIDEO_DRIVER";
    @:native('LINC_SDL_HINT_VIDEO_FORCE_EGL') public static inline var SDL_HINT_VIDEO_FORCE_EGL:String = "SDL_VIDEO_FORCE_EGL";
    @:native('LINC_SDL_HINT_VIDEO_SYNC_WINDOW_OPERATIONS') public static inline var SDL_HINT_VIDEO_SYNC_WINDOW_OPERATIONS:String = "SDL_VIDEO_SYNC_WINDOW_OPERATIONS";
    @:native('LINC_SDL_HINT_VIDEO_WAYLAND_MODE_SCALING') public static inline var SDL_HINT_VIDEO_WAYLAND_MODE_SCALING:String = "SDL_VIDEO_WAYLAND_MODE_SCALING";
    @:native('LINC_SDL_HINT_VIDEO_WAYLAND_SCALE_BUFFER') public static inline var SDL_HINT_VIDEO_WAYLAND_SCALE_BUFFER:String = "SDL_VIDEO_WAYLAND_SCALE_BUFFER";

    // Render hints
    @:native('LINC_SDL_HINT_RENDER_DRIVER') public static inline var SDL_HINT_RENDER_DRIVER:String = "SDL_RENDER_DRIVER";
    @:native('LINC_SDL_HINT_RENDER_VSYNC') public static inline var SDL_HINT_RENDER_VSYNC:String = "SDL_RENDER_VSYNC";
    @:native('LINC_SDL_HINT_RENDER_GPU_DEBUG') public static inline var SDL_HINT_RENDER_GPU_DEBUG:String = "SDL_RENDER_GPU_DEBUG";
    @:native('LINC_SDL_HINT_RENDER_GPU_LOW_POWER') public static inline var SDL_HINT_RENDER_GPU_LOW_POWER:String = "SDL_RENDER_GPU_LOW_POWER";
    @:native('LINC_SDL_HINT_RENDER_VULKAN_DEBUG') public static inline var SDL_HINT_RENDER_VULKAN_DEBUG:String = "SDL_RENDER_VULKAN_DEBUG";

    // Window hints
    @:native('LINC_SDL_HINT_WINDOW_ALLOW_TOPMOST') public static inline var SDL_HINT_WINDOW_ALLOW_TOPMOST:String = "SDL_WINDOW_ALLOW_TOPMOST";
    @:native('LINC_SDL_HINT_WINDOW_ACTIVATE_WHEN_RAISED') public static inline var SDL_HINT_WINDOW_ACTIVATE_WHEN_RAISED:String = "SDL_WINDOW_ACTIVATE_WHEN_RAISED";
    @:native('LINC_SDL_HINT_WINDOW_ACTIVATE_WHEN_SHOWN') public static inline var SDL_HINT_WINDOW_ACTIVATE_WHEN_SHOWN:String = "SDL_WINDOW_ACTIVATE_WHEN_SHOWN";
    @:native('LINC_SDL_HINT_WINDOW_FRAME_USABLE_WHILE_CURSOR_HIDDEN') public static inline var SDL_HINT_WINDOW_FRAME_USABLE_WHILE_CURSOR_HIDDEN:String = "SDL_WINDOW_FRAME_USABLE_WHILE_CURSOR_HIDDEN";

    // Joystick/gamepad hints
    @:native('LINC_SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS') public static inline var SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS:String = "SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS";
    @:native('LINC_SDL_HINT_JOYSTICK_ARCADESTICK_DEVICES') public static inline var SDL_HINT_JOYSTICK_ARCADESTICK_DEVICES:String = "SDL_JOYSTICK_ARCADESTICK_DEVICES";
    @:native('LINC_SDL_HINT_JOYSTICK_ARCADESTICK_DEVICES_EXCLUDED') public static inline var SDL_HINT_JOYSTICK_ARCADESTICK_DEVICES_EXCLUDED:String = "SDL_JOYSTICK_ARCADESTICK_DEVICES_EXCLUDED";
    @:native('LINC_SDL_HINT_JOYSTICK_BLACKLIST_DEVICES') public static inline var SDL_HINT_JOYSTICK_BLACKLIST_DEVICES:String = "SDL_JOYSTICK_BLACKLIST_DEVICES";
    @:native('LINC_SDL_HINT_JOYSTICK_BLACKLIST_DEVICES_EXCLUDED') public static inline var SDL_HINT_JOYSTICK_BLACKLIST_DEVICES_EXCLUDED:String = "SDL_JOYSTICK_BLACKLIST_DEVICES_EXCLUDED";
    @:native('LINC_SDL_HINT_JOYSTICK_DEVICE') public static inline var SDL_HINT_JOYSTICK_DEVICE:String = "SDL_JOYSTICK_DEVICE";
    @:native('LINC_SDL_HINT_JOYSTICK_DIRECTINPUT') public static inline var SDL_HINT_JOYSTICK_DIRECTINPUT:String = "SDL_JOYSTICK_DIRECTINPUT";
    @:native('LINC_SDL_HINT_JOYSTICK_ENHANCED_REPORTS') public static inline var SDL_HINT_JOYSTICK_ENHANCED_REPORTS:String = "SDL_JOYSTICK_ENHANCED_REPORTS";
    @:native('LINC_SDL_HINT_JOYSTICK_FLIGHTSTICK_DEVICES') public static inline var SDL_HINT_JOYSTICK_FLIGHTSTICK_DEVICES:String = "SDL_JOYSTICK_FLIGHTSTICK_DEVICES";
    @:native('LINC_SDL_HINT_JOYSTICK_FLIGHTSTICK_DEVICES_EXCLUDED') public static inline var SDL_HINT_JOYSTICK_FLIGHTSTICK_DEVICES_EXCLUDED:String = "SDL_JOYSTICK_FLIGHTSTICK_DEVICES_EXCLUDED";
    @:native('LINC_SDL_HINT_JOYSTICK_GAMEINPUT') public static inline var SDL_HINT_JOYSTICK_GAMEINPUT:String = "SDL_JOYSTICK_GAMEINPUT";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI') public static inline var SDL_HINT_JOYSTICK_HIDAPI:String = "SDL_JOYSTICK_HIDAPI";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_COMBINE_JOY_CONS') public static inline var SDL_HINT_JOYSTICK_HIDAPI_COMBINE_JOY_CONS:String = "SDL_JOYSTICK_HIDAPI_COMBINE_JOY_CONS";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_GAMECUBE') public static inline var SDL_HINT_JOYSTICK_HIDAPI_GAMECUBE:String = "SDL_JOYSTICK_HIDAPI_GAMECUBE";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_GAMECUBE_RUMBLE_BRAKE') public static inline var SDL_HINT_JOYSTICK_HIDAPI_GAMECUBE_RUMBLE_BRAKE:String = "SDL_JOYSTICK_HIDAPI_GAMECUBE_RUMBLE_BRAKE";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_JOY_CONS') public static inline var SDL_HINT_JOYSTICK_HIDAPI_JOY_CONS:String = "SDL_JOYSTICK_HIDAPI_JOY_CONS";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_LUNA') public static inline var SDL_HINT_JOYSTICK_HIDAPI_LUNA:String = "SDL_JOYSTICK_HIDAPI_LUNA";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_NINTENDO_CLASSIC') public static inline var SDL_HINT_JOYSTICK_HIDAPI_NINTENDO_CLASSIC:String = "SDL_JOYSTICK_HIDAPI_NINTENDO_CLASSIC";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_PS3') public static inline var SDL_HINT_JOYSTICK_HIDAPI_PS3:String = "SDL_JOYSTICK_HIDAPI_PS3";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER') public static inline var SDL_HINT_JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER:String = "SDL_JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_PS4') public static inline var SDL_HINT_JOYSTICK_HIDAPI_PS4:String = "SDL_JOYSTICK_HIDAPI_PS4";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_PS5') public static inline var SDL_HINT_JOYSTICK_HIDAPI_PS5:String = "SDL_JOYSTICK_HIDAPI_PS5";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_PS5_PLAYER_LED') public static inline var SDL_HINT_JOYSTICK_HIDAPI_PS5_PLAYER_LED:String = "SDL_JOYSTICK_HIDAPI_PS5_PLAYER_LED";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_SHIELD') public static inline var SDL_HINT_JOYSTICK_HIDAPI_SHIELD:String = "SDL_JOYSTICK_HIDAPI_SHIELD";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_STADIA') public static inline var SDL_HINT_JOYSTICK_HIDAPI_STADIA:String = "SDL_JOYSTICK_HIDAPI_STADIA";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_STEAM') public static inline var SDL_HINT_JOYSTICK_HIDAPI_STEAM:String = "SDL_JOYSTICK_HIDAPI_STEAM";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_STEAMDECK') public static inline var SDL_HINT_JOYSTICK_HIDAPI_STEAMDECK:String = "SDL_JOYSTICK_HIDAPI_STEAMDECK";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_STEAM_HORI') public static inline var SDL_HINT_JOYSTICK_HIDAPI_STEAM_HORI:String = "SDL_JOYSTICK_HIDAPI_STEAM_HORI";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_SWITCH') public static inline var SDL_HINT_JOYSTICK_HIDAPI_SWITCH:String = "SDL_JOYSTICK_HIDAPI_SWITCH";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_SWITCH_HOME_LED') public static inline var SDL_HINT_JOYSTICK_HIDAPI_SWITCH_HOME_LED:String = "SDL_JOYSTICK_HIDAPI_SWITCH_HOME_LED";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_SWITCH_PLAYER_LED') public static inline var SDL_HINT_JOYSTICK_HIDAPI_SWITCH_PLAYER_LED:String = "SDL_JOYSTICK_HIDAPI_SWITCH_PLAYER_LED";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_VERTICAL_JOY_CONS') public static inline var SDL_HINT_JOYSTICK_HIDAPI_VERTICAL_JOY_CONS:String = "SDL_JOYSTICK_HIDAPI_VERTICAL_JOY_CONS";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_WII') public static inline var SDL_HINT_JOYSTICK_HIDAPI_WII:String = "SDL_JOYSTICK_HIDAPI_WII";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_WII_PLAYER_LED') public static inline var SDL_HINT_JOYSTICK_HIDAPI_WII_PLAYER_LED:String = "SDL_JOYSTICK_HIDAPI_WII_PLAYER_LED";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_XBOX') public static inline var SDL_HINT_JOYSTICK_HIDAPI_XBOX:String = "SDL_JOYSTICK_HIDAPI_XBOX";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_XBOX_360') public static inline var SDL_HINT_JOYSTICK_HIDAPI_XBOX_360:String = "SDL_JOYSTICK_HIDAPI_XBOX_360";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_XBOX_360_PLAYER_LED') public static inline var SDL_HINT_JOYSTICK_HIDAPI_XBOX_360_PLAYER_LED:String = "SDL_JOYSTICK_HIDAPI_XBOX_360_PLAYER_LED";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_XBOX_360_WIRELESS') public static inline var SDL_HINT_JOYSTICK_HIDAPI_XBOX_360_WIRELESS:String = "SDL_JOYSTICK_HIDAPI_XBOX_360_WIRELESS";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_XBOX_ONE') public static inline var SDL_HINT_JOYSTICK_HIDAPI_XBOX_ONE:String = "SDL_JOYSTICK_HIDAPI_XBOX_ONE";
    @:native('LINC_SDL_HINT_JOYSTICK_HIDAPI_XBOX_ONE_HOME_LED') public static inline var SDL_HINT_JOYSTICK_HIDAPI_XBOX_ONE_HOME_LED:String = "SDL_JOYSTICK_HIDAPI_XBOX_ONE_HOME_LED";
    @:native('LINC_SDL_HINT_JOYSTICK_IOKIT') public static inline var SDL_HINT_JOYSTICK_IOKIT:String = "SDL_JOYSTICK_IOKIT";
    @:native('LINC_SDL_HINT_JOYSTICK_LINUX_CLASSIC') public static inline var SDL_HINT_JOYSTICK_LINUX_CLASSIC:String = "SDL_JOYSTICK_LINUX_CLASSIC";
    @:native('LINC_SDL_HINT_JOYSTICK_LINUX_DEADZONES') public static inline var SDL_HINT_JOYSTICK_LINUX_DEADZONES:String = "SDL_JOYSTICK_LINUX_DEADZONES";
    @:native('LINC_SDL_HINT_JOYSTICK_LINUX_DIGITAL_HATS') public static inline var SDL_HINT_JOYSTICK_LINUX_DIGITAL_HATS:String = "SDL_JOYSTICK_LINUX_DIGITAL_HATS";
    @:native('LINC_SDL_HINT_JOYSTICK_LINUX_HAT_DEADZONES') public static inline var SDL_HINT_JOYSTICK_LINUX_HAT_DEADZONES:String = "SDL_JOYSTICK_LINUX_HAT_DEADZONES";
    @:native('LINC_SDL_HINT_JOYSTICK_MFI') public static inline var SDL_HINT_JOYSTICK_MFI:String = "SDL_JOYSTICK_MFI";
    @:native('LINC_SDL_HINT_JOYSTICK_RAWINPUT') public static inline var SDL_HINT_JOYSTICK_RAWINPUT:String = "SDL_JOYSTICK_RAWINPUT";
    @:native('LINC_SDL_HINT_JOYSTICK_RAWINPUT_CORRELATE_XINPUT') public static inline var SDL_HINT_JOYSTICK_RAWINPUT_CORRELATE_XINPUT:String = "SDL_JOYSTICK_RAWINPUT_CORRELATE_XINPUT";
    @:native('LINC_SDL_HINT_JOYSTICK_ROG_CHAKRAM') public static inline var SDL_HINT_JOYSTICK_ROG_CHAKRAM:String = "SDL_JOYSTICK_ROG_CHAKRAM";
    @:native('LINC_SDL_HINT_JOYSTICK_THREAD') public static inline var SDL_HINT_JOYSTICK_THREAD:String = "SDL_JOYSTICK_THREAD";
    @:native('LINC_SDL_HINT_JOYSTICK_THROTTLE_DEVICES') public static inline var SDL_HINT_JOYSTICK_THROTTLE_DEVICES:String = "SDL_JOYSTICK_THROTTLE_DEVICES";
    @:native('LINC_SDL_HINT_JOYSTICK_THROTTLE_DEVICES_EXCLUDED') public static inline var SDL_HINT_JOYSTICK_THROTTLE_DEVICES_EXCLUDED:String = "SDL_JOYSTICK_THROTTLE_DEVICES_EXCLUDED";
    @:native('LINC_SDL_HINT_JOYSTICK_WHEEL_DEVICES') public static inline var SDL_HINT_JOYSTICK_WHEEL_DEVICES:String = "SDL_JOYSTICK_WHEEL_DEVICES";
    @:native('LINC_SDL_HINT_JOYSTICK_WHEEL_DEVICES_EXCLUDED') public static inline var SDL_HINT_JOYSTICK_WHEEL_DEVICES_EXCLUDED:String = "SDL_JOYSTICK_WHEEL_DEVICES_EXCLUDED";
    @:native('LINC_SDL_HINT_JOYSTICK_WGI') public static inline var SDL_HINT_JOYSTICK_WGI:String = "SDL_JOYSTICK_WGI";
    @:native('LINC_SDL_HINT_JOYSTICK_ZERO_CENTERED_DEVICES') public static inline var SDL_HINT_JOYSTICK_ZERO_CENTERED_DEVICES:String = "SDL_JOYSTICK_ZERO_CENTERED_DEVICES";

    // Gamepad hints
    @:native('LINC_SDL_HINT_GAMECONTROLLERCONFIG') public static inline var SDL_HINT_GAMECONTROLLERCONFIG:String = "SDL_GAMECONTROLLERCONFIG";
    @:native('LINC_SDL_HINT_GAMECONTROLLERCONFIG_FILE') public static inline var SDL_HINT_GAMECONTROLLERCONFIG_FILE:String = "SDL_GAMECONTROLLERCONFIG_FILE";
    @:native('LINC_SDL_HINT_GAMECONTROLLERTYPE') public static inline var SDL_HINT_GAMECONTROLLERTYPE:String = "SDL_GAMECONTROLLERTYPE";
    @:native('LINC_SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES') public static inline var SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES:String = "SDL_GAMECONTROLLER_IGNORE_DEVICES";
    @:native('LINC_SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT') public static inline var SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT:String = "SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT";

    // Mouse hints
    @:native('LINC_SDL_HINT_MOUSE_AUTO_CAPTURE') public static inline var SDL_HINT_MOUSE_AUTO_CAPTURE:String = "SDL_MOUSE_AUTO_CAPTURE";
    @:native('LINC_SDL_HINT_MOUSE_DEFAULT_SYSTEM_CURSOR') public static inline var SDL_HINT_MOUSE_DEFAULT_SYSTEM_CURSOR:String = "SDL_MOUSE_DEFAULT_SYSTEM_CURSOR";
    @:native('LINC_SDL_HINT_MOUSE_DOUBLE_CLICK_RADIUS') public static inline var SDL_HINT_MOUSE_DOUBLE_CLICK_RADIUS:String = "SDL_MOUSE_DOUBLE_CLICK_RADIUS";
    @:native('LINC_SDL_HINT_MOUSE_DOUBLE_CLICK_TIME') public static inline var SDL_HINT_MOUSE_DOUBLE_CLICK_TIME:String = "SDL_MOUSE_DOUBLE_CLICK_TIME";
    @:native('LINC_SDL_HINT_MOUSE_EMULATE_WARP_WITH_RELATIVE') public static inline var SDL_HINT_MOUSE_EMULATE_WARP_WITH_RELATIVE:String = "SDL_MOUSE_EMULATE_WARP_WITH_RELATIVE";
    @:native('LINC_SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH') public static inline var SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH:String = "SDL_MOUSE_FOCUS_CLICKTHROUGH";
    @:native('LINC_SDL_HINT_MOUSE_NORMAL_SPEED_SCALE') public static inline var SDL_HINT_MOUSE_NORMAL_SPEED_SCALE:String = "SDL_MOUSE_NORMAL_SPEED_SCALE";
    @:native('LINC_SDL_HINT_MOUSE_RELATIVE_CURSOR_VISIBLE') public static inline var SDL_HINT_MOUSE_RELATIVE_CURSOR_VISIBLE:String = "SDL_MOUSE_RELATIVE_CURSOR_VISIBLE";
    @:native('LINC_SDL_HINT_MOUSE_RELATIVE_MODE_CENTER') public static inline var SDL_HINT_MOUSE_RELATIVE_MODE_CENTER:String = "SDL_MOUSE_RELATIVE_MODE_CENTER";
    @:native('LINC_SDL_HINT_MOUSE_RELATIVE_SPEED_SCALE') public static inline var SDL_HINT_MOUSE_RELATIVE_SPEED_SCALE:String = "SDL_MOUSE_RELATIVE_SPEED_SCALE";
    @:native('LINC_SDL_HINT_MOUSE_RELATIVE_SYSTEM_SCALE') public static inline var SDL_HINT_MOUSE_RELATIVE_SYSTEM_SCALE:String = "SDL_MOUSE_RELATIVE_SYSTEM_SCALE";
    @:native('LINC_SDL_HINT_MOUSE_RELATIVE_WM_MOTION') public static inline var SDL_HINT_MOUSE_RELATIVE_WM_MOTION:String = "SDL_MOUSE_RELATIVE_WM_MOTION";
    @:native('LINC_SDL_HINT_MOUSE_TOUCH_EVENTS') public static inline var SDL_HINT_MOUSE_TOUCH_EVENTS:String = "SDL_MOUSE_TOUCH_EVENTS";

    // Keyboard hints
    @:native('LINC_SDL_HINT_KEYCODE_OPTIONS') public static inline var SDL_HINT_KEYCODE_OPTIONS:String = "SDL_KEYCODE_OPTIONS";
    @:native('LINC_SDL_HINT_MUTE_CONSOLE_KEYBOARD') public static inline var SDL_HINT_MUTE_CONSOLE_KEYBOARD:String = "SDL_MUTE_CONSOLE_KEYBOARD";

    // Touch hints
    @:native('LINC_SDL_HINT_TOUCH_MOUSE_EVENTS') public static inline var SDL_HINT_TOUCH_MOUSE_EVENTS:String = "SDL_TOUCH_MOUSE_EVENTS";

    // Android specific
    @:native('LINC_SDL_HINT_ANDROID_ALLOW_RECREATE_ACTIVITY') public static inline var SDL_HINT_ANDROID_ALLOW_RECREATE_ACTIVITY:String = "SDL_ANDROID_ALLOW_RECREATE_ACTIVITY";
    @:native('LINC_SDL_HINT_ANDROID_BLOCK_ON_PAUSE') public static inline var SDL_HINT_ANDROID_BLOCK_ON_PAUSE:String = "SDL_ANDROID_BLOCK_ON_PAUSE";
    @:native('LINC_SDL_HINT_ANDROID_LOW_LATENCY_AUDIO') public static inline var SDL_HINT_ANDROID_LOW_LATENCY_AUDIO:String = "SDL_ANDROID_LOW_LATENCY_AUDIO";
    @:native('LINC_SDL_HINT_ANDROID_TRAP_BACK_BUTTON') public static inline var SDL_HINT_ANDROID_TRAP_BACK_BUTTON:String = "SDL_ANDROID_TRAP_BACK_BUTTON";

    // iOS specific
    @:native('LINC_SDL_HINT_IOS_HIDE_HOME_INDICATOR') public static inline var SDL_HINT_IOS_HIDE_HOME_INDICATOR:String = "SDL_IOS_HIDE_HOME_INDICATOR";
    @:native('LINC_SDL_HINT_IOS_HIDE_MOUSE_CURSOR') public static inline var SDL_HINT_IOS_HIDE_MOUSE_CURSOR:String = "SDL_IOS_HIDE_MOUSE_CURSOR";
    @:native('LINC_SDL_HINT_IOS_HIDE_OTHER_APPS') public static inline var SDL_HINT_IOS_HIDE_OTHER_APPS:String = "SDL_IOS_HIDE_OTHER_APPS";
    @:native('LINC_SDL_HINT_IOS_SCREEN_REFRESH_RATE') public static inline var SDL_HINT_IOS_SCREEN_REFRESH_RATE:String = "SDL_IOS_SCREEN_REFRESH_RATE";

    // Apple specific
    @:native('LINC_SDL_HINT_APPLE_TV_CONTROLLER_UI_EVENTS') public static inline var SDL_HINT_APPLE_TV_CONTROLLER_UI_EVENTS:String = "SDL_APPLE_TV_CONTROLLER_UI_EVENTS";
    @:native('LINC_SDL_HINT_APPLE_TV_REMOTE_ALLOW_ROTATION') public static inline var SDL_HINT_APPLE_TV_REMOTE_ALLOW_ROTATION:String = "SDL_APPLE_TV_REMOTE_ALLOW_ROTATION";
    @:native('LINC_SDL_HINT_MAC_BACKGROUND_APP') public static inline var SDL_HINT_MAC_BACKGROUND_APP:String = "SDL_MAC_BACKGROUND_APP";
    @:native('LINC_SDL_HINT_MAC_CTRL_CLICK_EMULATE_RIGHT_CLICK') public static inline var SDL_HINT_MAC_CTRL_CLICK_EMULATE_RIGHT_CLICK:String = "SDL_MAC_CTRL_CLICK_EMULATE_RIGHT_CLICK";
    @:native('LINC_SDL_HINT_MAC_OPTION_AS_ALT') public static inline var SDL_HINT_MAC_OPTION_AS_ALT:String = "SDL_MAC_OPTION_AS_ALT";

    // Windows specific
    @:native('LINC_SDL_HINT_WINDOWS_CLOSE_ON_ALT_F4') public static inline var SDL_HINT_WINDOWS_CLOSE_ON_ALT_F4:String = "SDL_WINDOWS_CLOSE_ON_ALT_F4";
    @:native('LINC_SDL_HINT_WINDOWS_ENABLE_MENU_MNEMONICS') public static inline var SDL_HINT_WINDOWS_ENABLE_MENU_MNEMONICS:String = "SDL_WINDOWS_ENABLE_MENU_MNEMONICS";
    @:native('LINC_SDL_HINT_WINDOWS_ENABLE_MESSAGELOOP') public static inline var SDL_HINT_WINDOWS_ENABLE_MESSAGELOOP:String = "SDL_WINDOWS_ENABLE_MESSAGELOOP";
    @:native('LINC_SDL_HINT_WINDOWS_GAMEINPUT') public static inline var SDL_HINT_WINDOWS_GAMEINPUT:String = "SDL_WINDOWS_GAMEINPUT";
    @:native('LINC_SDL_HINT_WINDOWS_RAW_KEYBOARD') public static inline var SDL_HINT_WINDOWS_RAW_KEYBOARD:String = "SDL_WINDOWS_RAW_KEYBOARD";
    @:native('LINC_SDL_HINT_WINDOWS_USE_D3D9EX') public static inline var SDL_HINT_WINDOWS_USE_D3D9EX:String = "SDL_WINDOWS_USE_D3D9EX";

    // Other platform specific
    @:native('LINC_SDL_HINT_GDK_TEXTINPUT_DEFAULT_TEXT') public static inline var SDL_HINT_GDK_TEXTINPUT_DEFAULT_TEXT:String = "SDL_GDK_TEXTINPUT_DEFAULT_TEXT";
    @:native('LINC_SDL_HINT_GDK_TEXTINPUT_DESCRIPTION') public static inline var SDL_HINT_GDK_TEXTINPUT_DESCRIPTION:String = "SDL_GDK_TEXTINPUT_DESCRIPTION";
    @:native('LINC_SDL_HINT_GDK_TEXTINPUT_MAX_LENGTH') public static inline var SDL_HINT_GDK_TEXTINPUT_MAX_LENGTH:String = "SDL_GDK_TEXTINPUT_MAX_LENGTH";
    @:native('LINC_SDL_HINT_GDK_TEXTINPUT_SCOPE') public static inline var SDL_HINT_GDK_TEXTINPUT_SCOPE:String = "SDL_GDK_TEXTINPUT_SCOPE";
    @:native('LINC_SDL_HINT_GDK_TEXTINPUT_TITLE') public static inline var SDL_HINT_GDK_TEXTINPUT_TITLE:String = "SDL_GDK_TEXTINPUT_TITLE";
    @:native('LINC_SDL_HINT_XINPUT_ENABLED') public static inline var SDL_HINT_XINPUT_ENABLED:String = "SDL_XINPUT_ENABLED";

    // IME hints
    @:native('LINC_SDL_HINT_IME_IMPLEMENTED_UI') public static inline var SDL_HINT_IME_IMPLEMENTED_UI:String = "SDL_IME_IMPLEMENTED_UI";

    // Other hints
    @:native('LINC_SDL_HINT_APP_ID') public static inline var SDL_HINT_APP_ID:String = "SDL_APP_ID";
    @:native('LINC_SDL_HINT_APP_NAME') public static inline var SDL_HINT_APP_NAME:String = "SDL_APP_NAME";
    @:native('LINC_SDL_HINT_AUTO_UPDATE_JOYSTICKS') public static inline var SDL_HINT_AUTO_UPDATE_JOYSTICKS:String = "SDL_AUTO_UPDATE_JOYSTICKS";
    @:native('LINC_SDL_HINT_AUTO_UPDATE_SENSORS') public static inline var SDL_HINT_AUTO_UPDATE_SENSORS:String = "SDL_AUTO_UPDATE_SENSORS";
    @:native('LINC_SDL_HINT_BMP_SAVE_LEGACY_FORMAT') public static inline var SDL_HINT_BMP_SAVE_LEGACY_FORMAT:String = "SDL_BMP_SAVE_LEGACY_FORMAT";
    @:native('LINC_SDL_HINT_CPU_FEATURE_MASK') public static inline var SDL_HINT_CPU_FEATURE_MASK:String = "SDL_CPU_FEATURE_MASK";
    @:native('LINC_SDL_HINT_DISPLAY_USABLE_BOUNDS') public static inline var SDL_HINT_DISPLAY_USABLE_BOUNDS:String = "SDL_DISPLAY_USABLE_BOUNDS";
    @:native('LINC_SDL_HINT_EMSCRIPTEN_CANVAS_SELECTOR') public static inline var SDL_HINT_EMSCRIPTEN_CANVAS_SELECTOR:String = "SDL_EMSCRIPTEN_CANVAS_SELECTOR";
    @:native('LINC_SDL_HINT_EMSCRIPTEN_KEYBOARD_ELEMENT') public static inline var SDL_HINT_EMSCRIPTEN_KEYBOARD_ELEMENT:String = "SDL_EMSCRIPTEN_KEYBOARD_ELEMENT";
    @:native('LINC_SDL_HINT_ENABLE_SCREEN_KEYBOARD') public static inline var SDL_HINT_ENABLE_SCREEN_KEYBOARD:String = "SDL_ENABLE_SCREEN_KEYBOARD";
    @:native('LINC_SDL_HINT_EVDEV_DEVICES') public static inline var SDL_HINT_EVDEV_DEVICES:String = "SDL_EVDEV_DEVICES";
    @:native('LINC_SDL_HINT_EVENT_LOGGING') public static inline var SDL_HINT_EVENT_LOGGING:String = "SDL_EVENT_LOGGING";
    @:native('LINC_SDL_HINT_FILE_DIALOG_DRIVER') public static inline var SDL_HINT_FILE_DIALOG_DRIVER:String = "SDL_FILE_DIALOG_DRIVER";
    @:native('LINC_SDL_HINT_FORCE_RAISEWINDOW') public static inline var SDL_HINT_FORCE_RAISEWINDOW:String = "SDL_FORCE_RAISEWINDOW";
    @:native('LINC_SDL_HINT_FRAMEBUFFER_ACCELERATION') public static inline var SDL_HINT_FRAMEBUFFER_ACCELERATION:String = "SDL_FRAMEBUFFER_ACCELERATION";
    @:native('LINC_SDL_HINT_HIDAPI_LIBUSB') public static inline var SDL_HINT_HIDAPI_LIBUSB:String = "SDL_HIDAPI_LIBUSB";
    @:native('LINC_SDL_HINT_HIDAPI_LIBUSB_WHITELIST') public static inline var SDL_HINT_HIDAPI_LIBUSB_WHITELIST:String = "SDL_HIDAPI_LIBUSB_WHITELIST";
    @:native('LINC_SDL_HINT_HIDAPI_UDEV') public static inline var SDL_HINT_HIDAPI_UDEV:String = "SDL_HIDAPI_UDEV";
    @:native('LINC_SDL_HINT_HIDAPI_IGNORE_DEVICES') public static inline var SDL_HINT_HIDAPI_IGNORE_DEVICES:String = "SDL_HIDAPI_IGNORE_DEVICES";
    @:native('LINC_SDL_HINT_KMSDRM_DEVICE_INDEX') public static inline var SDL_HINT_KMSDRM_DEVICE_INDEX:String = "SDL_KMSDRM_DEVICE_INDEX";
    @:native('LINC_SDL_HINT_KMSDRM_REQUIRE_DRM_MASTER') public static inline var SDL_HINT_KMSDRM_REQUIRE_DRM_MASTER:String = "SDL_KMSDRM_REQUIRE_DRM_MASTER";
    @:native('LINC_SDL_HINT_LOGGING') public static inline var SDL_HINT_LOGGING:String = "SDL_LOGGING";
    @:native('LINC_SDL_HINT_MAIN_CALLBACK_RATE') public static inline var SDL_HINT_MAIN_CALLBACK_RATE:String = "SDL_MAIN_CALLBACK_RATE";
    @:native('LINC_SDL_HINT_NO_SIGNAL_HANDLERS') public static inline var SDL_HINT_NO_SIGNAL_HANDLERS:String = "SDL_NO_SIGNAL_HANDLERS";
    @:native('LINC_SDL_HINT_OPENGL_LIBRARY') public static inline var SDL_HINT_OPENGL_LIBRARY:String = "SDL_OPENGL_LIBRARY";
    @:native('LINC_SDL_HINT_EGL_LIBRARY') public static inline var SDL_HINT_EGL_LIBRARY:String = "SDL_EGL_LIBRARY";
    @:native('LINC_SDL_HINT_OPENGL_ES_DRIVER') public static inline var SDL_HINT_OPENGL_ES_DRIVER:String = "SDL_OPENGL_ES_DRIVER";
    @:native('LINC_SDL_HINT_ORIENTATIONS') public static inline var SDL_HINT_ORIENTATIONS:String = "SDL_ORIENTATIONS";
    @:native('LINC_SDL_HINT_PREFERRED_LOCALES') public static inline var SDL_HINT_PREFERRED_LOCALES:String = "SDL_PREFERRED_LOCALES";
    @:native('LINC_SDL_HINT_QUIT_ON_LAST_WINDOW_CLOSE') public static inline var SDL_HINT_QUIT_ON_LAST_WINDOW_CLOSE:String = "SDL_QUIT_ON_LAST_WINDOW_CLOSE";
    @:native('LINC_SDL_HINT_SCREENSAVER_INHIBIT_ACTIVITY_NAME') public static inline var SDL_HINT_SCREENSAVER_INHIBIT_ACTIVITY_NAME:String = "SDL_SCREENSAVER_INHIBIT_ACTIVITY_NAME";
    @:native('LINC_SDL_HINT_SHUTDOWN_DBUS_ON_QUIT') public static inline var SDL_HINT_SHUTDOWN_DBUS_ON_QUIT:String = "SDL_SHUTDOWN_DBUS_ON_QUIT";
    @:native('LINC_SDL_HINT_TIMER_RESOLUTION') public static inline var SDL_HINT_TIMER_RESOLUTION:String = "SDL_TIMER_RESOLUTION";
    @:native('LINC_SDL_HINT_TRACKPAD_IS_TOUCH_ONLY') public static inline var SDL_HINT_TRACKPAD_IS_TOUCH_ONLY:String = "SDL_TRACKPAD_IS_TOUCH_ONLY";
    @:native('LINC_SDL_HINT_TV_REMOTE_AS_JOYSTICK') public static inline var SDL_HINT_TV_REMOTE_AS_JOYSTICK:String = "SDL_TV_REMOTE_AS_JOYSTICK";
    @:native('LINC_SDL_HINT_VULKAN_LIBRARY') public static inline var SDL_HINT_VULKAN_LIBRARY:String = "SDL_VULKAN_LIBRARY";
    @:native('LINC_SDL_HINT_X11_FORCE_OVERRIDE_REDIRECT') public static inline var SDL_HINT_X11_FORCE_OVERRIDE_REDIRECT:String = "SDL_X11_FORCE_OVERRIDE_REDIRECT";
    @:native('LINC_SDL_HINT_X11_HIDE_MOUSE_CURSOR') public static inline var SDL_HINT_X11_HIDE_MOUSE_CURSOR:String = "SDL_X11_HIDE_MOUSE_CURSOR";
    @:native('LINC_SDL_HINT_X11_WINDOW_TYPE') public static inline var SDL_HINT_X11_WINDOW_TYPE:String = "SDL_X11_WINDOW_TYPE";

}

@:keep
#if !display
@:build(clay.sdl.Linc.touch())
@:build(clay.sdl.Linc.xml('sdl', '../sdl'))
#end
@:include('linc_sdl.h')
@:noCompletion extern class SDL_Extern {

    @:native('::linc::sdl::bind')
    static function bind():Void;

    @:native('::linc::sdl::init')
    static function init():Bool;

    @:native('::linc::sdl::quit')
    static function quit():Void;

    @:native('::linc::sdl::setHint')
    static function setHint(name:String, value:String):Bool;

    /** Expose this method to be able to patch locale as Std.parseFloat() may break otherwise. */
    @:native('::linc::sdl::setLCNumericCLocale')
    static function setLCNumericCLocale():Void;

    @:native('::linc::sdl::initSubSystem')
    static function initSubSystem(flags:UInt32):Bool;

    @:native('::linc::sdl::quitSubSystem')
    static function quitSubSystem(flags:UInt32):Void;

    @:native('::linc::sdl::setVideoDriver')
    static function setVideoDriver(driver:String):Bool;

    @:native('::linc::sdl::getError')
    static function getError():String;

    @:native('::linc::sdl::createWindow')
    static function createWindow(title:String, x:Int, y:Int, width:Int, height:Int, flags:SDLWindowFlags):SDLWindowPointer;

    @:native('::linc::sdl::getWindowID')
    static function getWindowID(window:SDLWindowPointer):SDLWindowID;

    @:native('::linc::sdl::setWindowTitle')
    static function setWindowTitle(window:SDLWindowPointer, title:String):Void;

    @:native('::linc::sdl::setWindowBordered')
    static function setWindowBordered(window:SDLWindowPointer, bordered:Bool):Void;

    @:native('::linc::sdl::setWindowFullscreenMode')
    static function setWindowFullscreenMode(window:SDLWindowPointer, mode:SDLDisplayModeConstPointer):Bool;

    @:native('::linc::sdl::setWindowFullscreen')
    static function setWindowFullscreen(window:SDLWindowPointer, fullscreen:Bool):Bool;

    @:native('::linc::sdl::getWindowSize')
    static function getWindowSize(window:SDLWindowPointer, size:SDLSize):Bool;

    @:native('::linc::sdl::getWindowSizeInPixels')
    static function getWindowSizeInPixels(window:SDLWindowPointer, size:SDLSize):Bool;

    @:native('::linc::sdl::getWindowPosition')
    static function getWindowPosition(window:SDLWindowPointer, position:SDLPoint):Bool;

    @:native('::linc::sdl::getWindowFullscreenMode')
    static function getWindowFullscreenMode(window:SDLWindowPointer):SDLDisplayModeConstPointer;

    @:native('::linc::sdl::getDesktopDisplayMode')
    static function getDesktopDisplayMode(displayID:SDLDisplayID):SDLDisplayModeConstPointer;

    @:native('::linc::sdl::getPrimaryDisplay')
    static function getPrimaryDisplay():SDLDisplayID;

    @:native('::linc::sdl::getDisplayForWindow')
    static function getDisplayForWindow(window:SDLWindowPointer):SDLDisplayID;

    @:native('::linc::sdl::getWindowFlags')
    static function getWindowFlags(window:SDLWindowPointer, flags:SDLWindowFlagsPointer):Bool;

    @:native('::linc::sdl::GL_SetAttribute')
    static function GL_SetAttribute(attr:Int, value:Int):Bool;

    @:native('::linc::sdl::GL_CreateContext')
    static function GL_CreateContext(window:SDLWindowPointer):SDLGLContext;

    @:native('::linc::sdl::GL_GetCurrentContext')
    static function GL_GetCurrentContext():SDLGLContext;

    @:native('::linc::sdl::GL_GetAttribute')
    static function GL_GetAttribute(attr:Int):Int;

    @:native('::linc::sdl::GL_MakeCurrent')
    static function GL_MakeCurrent(window:SDLWindowPointer, context:SDLGLContext):Bool;

    @:native('::linc::sdl::GL_SwapWindow')
    static function GL_SwapWindow(window:SDLWindowPointer):Bool;

    @:native('::linc::sdl::GL_SetSwapInterval')
    static function GL_SetSwapInterval(interval:Int):Bool;

    @:native('::linc::sdl::GL_DestroyContext')
    static function GL_DestroyContext(context:SDLGLContext):Void;

    @:native('::linc::sdl::getTicks')
    static function getTicks():UInt64;

    @:native('::linc::sdl::delay')
    static function delay(ms:UInt32):Void;

    @:native('::linc::sdl::pollEvent')
    static function pollEvent(event:SDLEventPointer):Bool;

    @:native('::linc::sdl::pumpEvents')
    static function pumpEvents():Void;

    @:native('::linc::sdl::getNumJoysticks')
    static function getNumJoysticks():Int;

    @:native('::linc::sdl::isGamepad')
    static function isGamepad(instance_id:SDLJoystickID):Bool;

    @:native('::linc::sdl::openJoystick')
    static function openJoystick(instance_id:SDLJoystickID):SDLJoystickPointer;

    @:native('::linc::sdl::closeJoystick')
    static function closeJoystick(joystick:SDLJoystickPointer):Void;

    @:native('::linc::sdl::openGamepad')
    static function openGamepad(instance_id:SDLJoystickID):SDLGamepadPointer;

    @:native('::linc::sdl::closeGamepad')
    static function closeGamepad(gamepad:SDLGamepadPointer):Void;

    @:native('::linc::sdl::getGamepadNameForID')
    static function getGamepadNameForID(instance_id:SDLJoystickID):ConstCharStar;

    @:native('::linc::sdl::getJoystickNameForID')
    static function getJoystickNameForID(instance_id:SDLJoystickID):ConstCharStar;

    @:native('::linc::sdl::gamepadHasRumble')
    static function gamepadHasRumble(gamepad:SDLGamepadPointer):Bool;

    @:native('::linc::sdl::rumbleGamepad')
    static function rumbleGamepad(gamepad:SDLGamepadPointer, low_frequency_rumble:UInt16, high_frequency_rumble:UInt16, duration_ms:UInt32):Bool;

    @:native('::linc::sdl::setGamepadSensorEnabled')
    static function setGamepadSensorEnabled(gamepad:SDLGamepadPointer, type:Int, enabled:Bool):Bool;

    @:native('::linc::sdl::getJoystickID')
    static function getJoystickID(joystick:SDLJoystickPointer):SDLJoystickID;

    #if (ios || tvos)
    @:native('::linc::sdl::setiOSAnimationCallback')
    static function setiOSAnimationCallback(window:SDLWindowPointer, callback:cpp.Callable<()->Void>):Bool;
    #end

    @:native('::linc::sdl::setEventWatch')
    static function setEventWatch(window:SDLWindowPointer, eventWatcher:cpp.Callable<SDLEvent->Int>):Bool;

    @:native('::linc::sdl::getDisplayContentScale')
    static function getDisplayContentScale(displayID:SDLDisplayID):Float;

    @:native('::linc::sdl::getDisplayUsableBounds')
    static function getDisplayUsableBounds(displayID:SDLDisplayID, rect:SDLRectPointer):Void;

    @:native('::linc::sdl::isWindowInFullscreenSpace')
    static function isWindowInFullscreenSpace(window:SDLWindowPointer):Bool;

    @:native('::linc::sdl::getBasePath')
    static function getBasePath():String;

    @:native('::linc::sdl::startTextInput')
    static function startTextInput(window:SDLWindowPointer):Void;

    @:native('::linc::sdl::stopTextInput')
    static function stopTextInput(window:SDLWindowPointer):Void;

    @:native('::linc::sdl::setTextInputArea')
    static function setTextInputArea(window:SDLWindowPointer, rect:SDLRectConstPointer, cursor:Int):Void;

    // IO operations
    @:native('::linc::sdl::ioFromFile')
    static function ioFromFile(file:String, mode:String):SDLIOStreamPointer;

    @:native('::linc::sdl::ioFromMem')
    static function ioFromMem(mem:BytesData, size:Int):SDLIOStreamPointer;

    @:native('::linc::sdl::ioRead')
    static function ioRead(context:SDLIOStreamPointer, dest:BytesData, size:Int):Int;

    @:native('::linc::sdl::ioWrite')
    static function ioWrite(context:SDLIOStreamPointer, src:BytesData, size:Int):Int;

    @:native('::linc::sdl::ioSeek')
    static function ioSeek(context:SDLIOStreamPointer, offset:cpp.Int64, whence:Int):cpp.Int64;

    @:native('::linc::sdl::ioTell')
    static function ioTell(context:SDLIOStreamPointer):cpp.Int64;

    @:native('::linc::sdl::ioClose')
    static function ioClose(context:SDLIOStreamPointer):Bool;

    @:native('::linc::sdl::getPrefPath')
    static function getPrefPath(org:String, app:String):ConstCharStar;

    @:native('::linc::sdl::hasClipboardText')
    static function hasClipboardText():Bool;

    @:native('::linc::sdl::getClipboardText')
    static function getClipboardText():String;

    @:native('::linc::sdl::setClipboardText')
    static function setClipboardText(text:String):Bool;

    @:native('::linc::sdl::createRGBSurfaceFrom')
    static function createRGBSurfaceFrom(pixels:BytesData, width:Int, height:Int, depth:Int, pitch:Int, rmask:UInt32, gmask:UInt32, bmask:UInt32, amask:UInt32):SDLSurfacePointer;

    @:native('::linc::sdl::freeSurface')
    static function freeSurface(surface:SDLSurfacePointer):Void;

}