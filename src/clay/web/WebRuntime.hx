package clay.web;

import clay.opengl.GL;
import clay.Config;
import clay.Types;

typedef WindowHandle = js.html.CanvasElement;

@:access(clay.Clay)
@:access(clay.Input)
@:access(clay.Screen)
class WebRuntime extends clay.base.BaseRuntime {

/// Properties

    /** internal start time, allowing 0 based time values */
    static var timestampStart:Float = 0.0;

    /** The window id to use for events */
    static inline var webWindowId:Int = 1;

    public var gamepadsSupported:Bool = false;

    /** The runtime window canvas */
    public var window:WindowHandle;

/// Internal

    /** The window x position. 
        Internal, set by update_window_bounds */
    var windowX:Int = 0;

    /** The window y position.
        Internal, set by update_window_bounds */
    var windowY:Int = 0;

    var windowW:Int;

    var windowH:Int;

    var windowDpr:Float = 1.0;

    var touches:IntMap<{x:Float, y:Float}> = new IntMap();

    var gamepadButtonCache:Array<Array<Float>>;

    var gamepadAxisCache:Array<Array<Float>>;

/// Lifecycle

    override function init() {

        timestampStart = (js.Browser.window.performance.now() / 1000.0);
        name = 'web';

        initGamepads();

    }

    override function ready() {

        createWindow();

        Log.debug('Web / ready');
        
    }

    override function run():Bool {

        Log.debug('Web / run');

        loop(0);

        return false;

    }

    /**
     * Runtime loop, run at every frame
     */
    function loop(t:Float = 0.016):Bool {

        if (app.hasShutdown)
            return false;

        if (app.ready) {

            if (gamepadsSupported)
                pollGamepads();

            updateWindowBounds();

        }

        app.emitTick();

        if (!app.shuttingDown) {
            js.Browser.window.requestAnimationFrame(loop);
        }

        return true;

    }

/// Internal

    function createWindow() {

        var config = app.config.window;
        window = js.Browser.document.createCanvasElement();

        // For High DPI, we scale the config sizes
        windowDpr = windowDevicePixelRatio();
        window.width = Math.floor(config.width * windowDpr);
        window.height = Math.floor(config.height * windowDpr);

        // These are in css device pixels
        windowW = config.width;
        windowH = config.height;
        window.style.width = config.width + 'px';
        window.style.height = config.height + 'px';

        // This is typically required for our WebGL blending
        window.style.background = '#000000';

        Log.debug('Web / Created window at $windowX,$windowY - ${window.width}x${window.height} pixels (${config.width}x${config.height}@${windowDpr}x)');

        window.id = app.config.runtime.windowId;
        app.config.runtime.windowParent.appendChild(window);

        if (config.title != null) {
            js.Browser.document.title = config.title;
        }

        if (!createRenderContext(window)) {
            createRenderContextFailed();
            return;
        }
        
        postRenderContext(window);

        setupEvents();

    }

    function createRenderContext(window:WindowHandle):Bool {

        var config = app.config.render;

        var attr = applyGLAttributes(config);

        var gl = null;

        if (config.webgl.version != 1) {
            gl = window.getContext('webgl${config.webgl.version}');
            if (gl == null) {
                gl = window.getContext('experimental-webgl${config.webgl.version}');
            }
        }

        // Minimum requirement: webgl 1 (if nothing else worked)
        gl = window.getContextWebGL(attr);

        clay.opengl.GL.gl = gl;

        Log.debug('GL / context: ${gl != null}');

        return gl != null;

    }

    function createRenderContextFailed() {

        var msg =  'WebGL is required to run this!<br/><br/>';
            msg += 'visit <a style="color:#06b4fb; text-decoration:none;" href="http://get.webgl.org/">get.webgl.com</a> for info<br/>';
            msg += 'and contact the developer of this app';

        var textEl:js.html.Element;
        var overlayEl:js.html.Element;

        textEl = js.Browser.document.createDivElement();
        overlayEl = js.Browser.document.createDivElement();

        textEl.style.marginLeft = 'auto';
        textEl.style.marginRight = 'auto';
        textEl.style.color = '#d3d3d3';
        textEl.style.marginTop = '5em';
        textEl.style.fontSize = '1.4em';
        textEl.style.fontFamily = 'Helvetica, sans-serif';
        textEl.innerHTML = msg;

        overlayEl.style.top = '0';
        overlayEl.style.left = '0';
        overlayEl.style.width = '100%';
        overlayEl.style.height = '100%';
        overlayEl.style.display = 'block';
        overlayEl.style.minWidth = '100%';
        overlayEl.style.minHeight = '100%';
        overlayEl.style.textAlign = 'center';
        overlayEl.style.position = 'absolute';
        overlayEl.style.background = 'rgba(1,1,1,0.90)';

        overlayEl.appendChild(textEl);
        js.Browser.document.body.appendChild(overlayEl);

        throw 'Web / Failed to create render context';

    }

    function applyGLAttributes(config:RenderConfig):js.html.webgl.ContextAttributes {

        var attr:js.html.webgl.ContextAttributes = {
            alpha: config.webgl.alpha,
            antialias: config.webgl.antialias,
            depth: config.webgl.depth,
            stencil: config.webgl.stencil,
            failIfMajorPerformanceCaveat: config.webgl.failIfMajorPerformanceCaveat,
            premultipliedAlpha: config.webgl.premultipliedAlpha,
            preserveDrawingBuffer: config.webgl.preserveDrawingBuffer,
        };

        if (config.antialiasing > 0)
            attr.antialias = true;

        if (config.depth > 0)
            attr.depth = true;

        if (config.stencil > 0)
            attr.stencil = true;

        return attr;

    }

    function postRenderContext(window:WindowHandle) {

        #if (!clay_no_initial_gl_clear)

        var color = app.config.render.defaultClear;

        GL.clearDepth(1.0);
        GL.clearStencil(0);
        GL.clearColor(color.r, color.g, color.b, color.a);
        GL.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT | GL.STENCIL_BUFFER_BIT);

        #end

    }

    function setupEvents() {

        // Window events

        window.addEventListener('mouseenter', handleMouseEnter);
        window.addEventListener('mouseleave', handleMouseLeave);

        js.Browser.document.addEventListener('visibilitychange', handleVisibilityChange);

        // Key events

        js.Browser.document.addEventListener('keydown',  handleKeyDown);
        js.Browser.document.addEventListener('keyup',    handleKeyUp);
        js.Browser.document.addEventListener('keypress', handleKeyPress);

        // Mouse events

        window.addEventListener('contextmenu', handleContextMenu);

        var eventsWindow = app.config.runtime.mouseUseBrowserWindowEvents ? js.Browser.window : window;
        
        eventsWindow.addEventListener('mousedown', handleMouseDown);
        eventsWindow.addEventListener('mouseup', handleMouseUp);
        eventsWindow.addEventListener('mousemove', handleMouseMove);

        window.addEventListener('wheel', handleWheel);

        // Touch events

        window.addEventListener('touchstart', handleTouchStart);
        window.addEventListener('touchend', handleTouchEnd);
        window.addEventListener('touchmove', handleTouchMove);

        // Gamepad events

        js.Browser.window.addEventListener("gamepadconnected",    handleGamepadConnected);
        js.Browser.window.addEventListener("gamepaddisconnected", handleGamepadDisconnected);

        // Orientation events (TODO)

    }

/// Event handlers

    function handleVisibilityChange(_) {

        if (js.Browser.document.hidden) {
            app.emitWindowEvent(HIDDEN, timestamp(), webWindowId, 0, 0);
            app.emitWindowEvent(MINIMIZED, timestamp(), webWindowId, 0, 0);
            app.emitWindowEvent(FOCUS_LOST, timestamp(), webWindowId, 0, 0);
        }
        else {
            app.emitWindowEvent(SHOWN, timestamp(), webWindowId, 0, 0);
            app.emitWindowEvent(RESTORED, timestamp(), webWindowId, 0, 0);
            app.emitWindowEvent(FOCUS_GAINED, timestamp(), webWindowId, 0, 0);
        }

    }

/// Input handlers

    function handleContextMenu(ev:js.html.MouseEvent) {

        if (app.config.runtime.preventDefaultContextMenu) {
            ev.preventDefault();
        }

    }

    function handleMouseEnter(ev:js.html.MouseEvent) {

        app.events.mouseEnter(ev);

    }

    function handleMouseLeave(ev:js.html.MouseEvent) {

        app.events.mouseLeave(ev);

    }

    function handleMouseDown(ev:js.html.MouseEvent) {

        app.input.emitMouseDown(
            translateMouseX(ev),
            translateMouseY(ev),
            ev.button,
            timestamp(),
            webWindowId
        );

    }

    function handleMouseUp(ev:js.html.MouseEvent) {

        app.input.emitMouseUp(
            translateMouseX(ev),
            translateMouseY(ev),
            ev.button,
            timestamp(),
            webWindowId
        );

    }

    function handleMouseMove(ev:js.html.MouseEvent) {

        var movementX = ev.movementX == null ? 0 : ev.movementX;
        var movementY = ev.movementY == null ? 0 : ev.movementY;
        movementX = Math.floor(movementX * windowDpr);
        movementY = Math.floor(movementY * windowDpr);

        app.input.emitMouseMove(
            translateMouseX(ev),
            translateMouseY(ev),
            movementX,
            movementY,
            timestamp(),
            webWindowId
        );

    }

    function handleWheel(ev:js.html.WheelEvent) {

        if (app.config.runtime.preventDefaultMouseWheel) {
            ev.preventDefault();
        }

        final wheelFactor = 0.1; // Try to have consistent behavior between web and native platforms
        app.input.emitMouseWheel(
            #if !clay_no_wheel_round
            Math.round(ev.deltaX * wheelFactor),
            Math.round(ev.deltaY * wheelFactor),
            #else
            ev.deltaX * wheelFactor,
            ev.deltaY * wheelFactor,
            #end
            timestamp(),
            webWindowId
        );

    }

    function handleTouchStart(ev:js.html.TouchEvent) {

        if (app.config.runtime.preventDefaultTouches) {
            ev.preventDefault();
        }

        var bound = window.getBoundingClientRect();
        for (touch in ev.changedTouches) {

            var x:Float = (touch.clientX - bound.left);
            var y:Float = (touch.clientY - bound.top);
            x = x / bound.width;
            y = y / bound.height;

            var touchInfo = touches.get(touch.identifier);
            if (touchInfo == null) {
                touchInfo = { x: x, y: y};
                touches.set(touch.identifier, touchInfo);
            }
            else {
                touchInfo.x = x;
                touchInfo.y = y;
            }

            app.input.emitTouchDown(
                x,
                y,
                0,
                0,
                touch.identifier,
                timestamp()
            );
        
        }

    }

    function handleTouchEnd(ev:js.html.TouchEvent) {

        if (app.config.runtime.preventDefaultTouches) {
            ev.preventDefault();
        }

        var bound = window.getBoundingClientRect();
        for (touch in ev.changedTouches) {

            var x:Float = touch.clientX - bound.left;
            var y:Float = touch.clientY - bound.top;
            x = x / bound.width;
            y = y / bound.height;

            var touchInfo = touches.get(touch.identifier);
            if (touchInfo == null) {
                touchInfo = { x: x, y: y};
                touches.set(touch.identifier, touchInfo);
            }

            app.input.emitTouchUp(
                x,
                y,
                x - touchInfo.x,
                y - touchInfo.y,
                touch.identifier,
                timestamp()
            );

            touchInfo.x = x;
            touchInfo.y = y;

        }

    }

    function handleTouchMove(ev:js.html.TouchEvent) {

        if (app.config.runtime.preventDefaultTouches) {
            ev.preventDefault();
        }

        var bound = window.getBoundingClientRect();
        for (touch in ev.changedTouches) {

            var x:Float = touch.clientX - bound.left;
            var y:Float = touch.clientY - bound.top;
            x = x / bound.width;
            y = y / bound.height;

            var touchInfo = touches.get(touch.identifier);
            if (touchInfo == null) {
                touchInfo = { x: x, y: y};
                touches.set(touch.identifier, touchInfo);
            }

            app.input.emitTouchMove(
                x,
                y,
                x - touchInfo.x,
                y - touchInfo.y,
                touch.identifier,
                timestamp()
            );

            touchInfo.x = x;
            touchInfo.y = y;

        }

    }

    function handleKeyDown(ev:js.html.KeyboardEvent) {

        var keyCode = convertKeyCode(ev.keyCode);
        var scanCode = KeyCode.toScanCode(keyCode);
        var modState = modStateFromEvent(ev);

        if (app.config.runtime.preventDefaultKeys.indexOf(keyCode) != -1) {
            ev.preventDefault();
        }

        app.input.emitKeyDown(
            keyCode,
            scanCode,
            ev.repeat,
            modState,
            timestamp(),
            webWindowId
        );

    }

    function handleKeyUp(ev:js.html.KeyboardEvent) {

        var keyCode = convertKeyCode(ev.keyCode);
        var scanCode = KeyCode.toScanCode(keyCode);
        var modState = modStateFromEvent(ev);

        if (app.config.runtime.preventDefaultKeys.indexOf(keyCode) != -1) {
            ev.preventDefault();
        }

        app.input.emitKeyUp(
            keyCode,
            scanCode,
            ev.repeat,
            modState,
            timestamp(),
            webWindowId
        );

    }

    function handleKeyPress(ev:js.html.KeyboardEvent) {

        if (ev.which != 0 && ev.keyCode != KeyCode.BACKSPACE && ev.keyCode != KeyCode.ENTER) {

            var text = String.fromCharCode(ev.charCode);

            app.input.emitText(
                text, 0, text.length,
                INPUT,
                timestamp(),
                webWindowId
            );

        }

    }

    function handleGamepadConnected(ev:js.html.GamepadEvent) {

        Log.debug('Gamepad connected at index ${ev.gamepad.index}: ${ev.gamepad.id}. ${ev.gamepad.buttons.length} buttons, ${ev.gamepad.axes.length} axes');

        initGamepadCacheIfNeeded(ev.gamepad);

        app.input.emitGamepadDevice(
            ev.gamepad.index,
            ev.gamepad.id,
            DEVICE_ADDED,
            timestamp()
        );

    }

    function handleGamepadDisconnected(ev:js.html.GamepadEvent) {

        Log.debug('Gamepad disconnected at index ${ev.gamepad.index}: ${ev.gamepad.id}');

        deleteGamepadCache(ev.gamepad);

        app.input.emitGamepadDevice(
            ev.gamepad.index,
            ev.gamepad.id,
            DEVICE_REMOVED,
            timestamp()
        );

    }

    /** This takes a *DOM* keycode and returns a clay KeyCode value */
    function convertKeyCode(domKeyCode:Int):KeyCode {

        // This converts the uppercase into lower case,
        // since those are fixed values it doesn't need to be checked
        if (domKeyCode >= 65 && domKeyCode <= 90) {
            return domKeyCode + 32;
        }

        // This will pass back the same value if unmapped
        return DOMKeys.domKeyToKeyCode(domKeyCode);

    }

    function modStateFromEvent(keyEvent:js.html.KeyboardEvent):ModState {

        var none:Bool =
            !keyEvent.altKey &&
            !keyEvent.ctrlKey &&
            !keyEvent.metaKey &&
            !keyEvent.shiftKey;

        app.input.modState.none    = none;
        app.input.modState.lshift  = keyEvent.shiftKey;
        app.input.modState.rshift  = keyEvent.shiftKey;
        app.input.modState.lctrl   = keyEvent.ctrlKey;
        app.input.modState.rctrl   = keyEvent.ctrlKey;
        app.input.modState.lalt    = keyEvent.altKey;
        app.input.modState.ralt    = keyEvent.altKey;
        app.input.modState.lmeta   = keyEvent.metaKey;
        app.input.modState.rmeta   = keyEvent.metaKey;
        app.input.modState.num     = false;                // Unsupported
        app.input.modState.caps    = false;                // Unsupported
        app.input.modState.mode    = false;                // Unsupported
        app.input.modState.ctrl    = keyEvent.ctrlKey;
        app.input.modState.shift   = keyEvent.shiftKey;
        app.input.modState.alt     = keyEvent.altKey;
        app.input.modState.meta    = keyEvent.metaKey;
        
        return app.input.modState;

    }

/// Window helpers
    
    inline function getWindowX(bounds:js.html.DOMRect) {
        return Math.round(bounds.left + js.Browser.window.pageXOffset - js.Browser.document.body.clientTop);
    }
    
    inline function getWindowY(bounds:js.html.DOMRect) {
        return Math.round(bounds.top + js.Browser.window.pageYOffset - js.Browser.document.body.clientLeft);
    }

    inline function translateMouseX(ev:js.html.MouseEvent) {
        return Math.floor(windowDpr * (ev.pageX - windowX));
    }

    inline function translateMouseY(ev:js.html.MouseEvent) {
        return Math.floor(windowDpr * (ev.pageY - windowY));
    }

    function updateWindowBounds() {

        var dpr = windowDpr;
        windowDpr = windowDevicePixelRatio();

        var bounds = window.getBoundingClientRect();

        var x = getWindowX(bounds);
        var y = getWindowY(bounds);
        var w = Math.round(bounds.width);
        var h = Math.round(bounds.height);

        if (x != windowX || y != windowY) {
            windowX = x;
            windowY = y;
            app.emitWindowEvent(MOVED, timestamp(), webWindowId, windowX, windowY);
        }

        if (w != windowW || h != windowH || dpr != windowDpr) {
            windowW = w;
            windowH = h;
            window.width = Math.floor(windowW * windowDpr);
            window.height = Math.floor(windowH * windowDpr);
            app.emitWindowEvent(SIZE_CHANGED, timestamp(), webWindowId, window.width, window.height);
        }

    }

/// Gamepads

    function initGamepads() {

        var list = getGamepadList();

        if (list != null) {
            gamepadsSupported = true;

            gamepadButtonCache = [];
            gamepadAxisCache = [];
            for (gamepad in list) {
                if (gamepad != null) {
                    initGamepadCacheIfNeeded(gamepad);
                }
            }
        }
        else {
            Log.warning("Gamepads are not supported in this browser :(");
        }

    }

    function getGamepadList():Array<js.html.Gamepad> {

        if (js.Browser.navigator.getGamepads != null) {
            return js.Browser.navigator.getGamepads();
        }

        if (untyped js.Browser.navigator.webkitGetGamepads != null) {
            return untyped js.Browser.navigator.webkitGetGamepads();
        }

        return null;

    }

    inline function initGamepadCacheIfNeeded(gamepad:js.html.Gamepad) {

        if (gamepadButtonCache[gamepad.index] == null) {

            gamepadButtonCache[gamepad.index] = [];
            for (i in 0...gamepad.buttons.length) {
                gamepadButtonCache[gamepad.index].push(0);
            }

            gamepadAxisCache[gamepad.index] = [];
            for (i in 0...gamepad.axes.length) {
                gamepadAxisCache[gamepad.index].push(0);
            }
        }

    }

    inline function deleteGamepadCache(gamepad:js.html.Gamepad) {

        gamepadButtonCache[gamepad.index] = null;
        gamepadAxisCache[gamepad.index] = null;

    }

    function pollGamepads() {

        var list = getGamepadList();

        if (list != null) {

            var len = list.length;
            var index = 0;

            while (index < len) {

                var gamepad = list[index];
                if (gamepad == null) {
                    index++;
                    continue;
                }
                
                initGamepadCacheIfNeeded(gamepad);

                var axisCache = gamepadAxisCache[gamepad.index];
                for (axisIndex in 0...gamepad.axes.length) {

                    var axis = gamepad.axes[axisIndex];
                    if (axis != axisCache[axisIndex]) {
                        axisCache[axisIndex] = axis;
                        app.input.emitGamepadAxis(
                            gamepad.index,
                            axisIndex,
                            axis,
                            timestamp()
                        );
                    }
                }

                var buttonCache = gamepadButtonCache[gamepad.index];
                for (buttonIndex in 0...gamepad.buttons.length) {

                    var button = gamepad.buttons[buttonIndex];

                    if (button.value != buttonCache[buttonIndex]) {
                        buttonCache[buttonIndex] = button.value;

                        if (button.pressed) {
                            app.input.emitGamepadDown(
                                gamepad.index,
                                buttonIndex,
                                button.value,
                                timestamp()
                            );
                        }
                        else {
                            app.input.emitGamepadUp(
                                gamepad.index,
                                buttonIndex,
                                button.value,
                                timestamp()
                            );
                        }
                    }
                }

                index++;
            }

        }

    }

/// Public API

    override function windowDevicePixelRatio():Float {

        return js.Browser.window.devicePixelRatio == null ? 1.0 : js.Browser.window.devicePixelRatio;

    }

    override inline public function windowWidth():Int {

        return Math.round(windowW * windowDevicePixelRatio());

    }

    override inline public function windowHeight():Int {

        return Math.round(windowH * windowDevicePixelRatio());

    }

/// Helpers

    inline public static function timestamp():Float {

        return (js.Browser.window.performance.now() / 1000.0) - timestampStart;

    }

    public static function defaultConfig():RuntimeConfig {

        return {
            windowId: 'app',
            windowParent: js.Browser.document.body,
            preventDefaultContextMenu: true,
            preventDefaultMouseWheel: true,
            preventDefaultTouches: true,
            preventDefaultKeys: [
                KeyCode.LEFT, KeyCode.RIGHT, KeyCode.UP, KeyCode.DOWN,
                KeyCode.BACKSPACE, KeyCode.TAB, KeyCode.DELETE, KeyCode.SPACE
            ],
            mouseUseBrowserWindowEvents: true
        };

    }

}

private class DOMKeys {

    /** This function takes the DOM keycode and translates it into the
        corresponding snow Keycodes value - but only if needed for special cases */
    public static function domKeyToKeyCode(keyCode:Int) {

        switch (keyCode) {

            case dom_shift:         return KeyCode.LSHIFT;     // TODO this is both left/right but returns left
            case dom_ctrl:          return KeyCode.LCTRL;      // TODO ^
            case dom_alt:           return KeyCode.LALT;       // TODO ^
            case dom_capslock:      return KeyCode.CAPSLOCK;

            case dom_pageup:        return KeyCode.PAGEUP;
            case dom_pagedown:      return KeyCode.PAGEDOWN;
            case dom_end:           return KeyCode.END;
            case dom_home:          return KeyCode.HOME;
            case dom_left:          return KeyCode.LEFT;
            case dom_up:            return KeyCode.UP;
            case dom_right:         return KeyCode.RIGHT;
            case dom_down:          return KeyCode.DOWN;
            case dom_printscr:      return KeyCode.PRINTSCREEN;
            case dom_insert:        return KeyCode.INSERT;
            case dom_delete:        return KeyCode.DELETE;

            case dom_lmeta:         return KeyCode.LMETA;
            case dom_rmeta:         return KeyCode.RMETA;
            case dom_meta:          return KeyCode.LMETA;

            case dom_kp_0:          return KeyCode.KP_0;
            case dom_kp_1:          return KeyCode.KP_1;
            case dom_kp_2:          return KeyCode.KP_2;
            case dom_kp_3:          return KeyCode.KP_3;
            case dom_kp_4:          return KeyCode.KP_4;
            case dom_kp_5:          return KeyCode.KP_5;
            case dom_kp_6:          return KeyCode.KP_6;
            case dom_kp_7:          return KeyCode.KP_7;
            case dom_kp_8:          return KeyCode.KP_8;
            case dom_kp_9:          return KeyCode.KP_9;
            case dom_kp_multiply:   return KeyCode.KP_MULTIPLY;
            case dom_kp_plus:       return KeyCode.KP_PLUS;
            case dom_kp_minus:      return KeyCode.KP_MINUS;
            case dom_kp_decimal:    return KeyCode.KP_DECIMAL;
            case dom_kp_divide:     return KeyCode.KP_DIVIDE;
            case dom_kp_numlock:    return KeyCode.NUMLOCKCLEAR;

            case dom_f1:            return KeyCode.F1;
            case dom_f2:            return KeyCode.F2;
            case dom_f3:            return KeyCode.F3;
            case dom_f4:            return KeyCode.F4;
            case dom_f5:            return KeyCode.F5;
            case dom_f6:            return KeyCode.F6;
            case dom_f7:            return KeyCode.F7;
            case dom_f8:            return KeyCode.F8;
            case dom_f9:            return KeyCode.F9;
            case dom_f10:           return KeyCode.F10;
            case dom_f11:           return KeyCode.F11;
            case dom_f12:           return KeyCode.F12;
            case dom_f13:           return KeyCode.F13;
            case dom_f14:           return KeyCode.F14;
            case dom_f15:           return KeyCode.F15;
            case dom_f16:           return KeyCode.F16;
            case dom_f17:           return KeyCode.F17;
            case dom_f18:           return KeyCode.F18;
            case dom_f19:           return KeyCode.F19;
            case dom_f20:           return KeyCode.F20;
            case dom_f21:           return KeyCode.F21;
            case dom_f22:           return KeyCode.F22;
            case dom_f23:           return KeyCode.F23;
            case dom_f24:           return KeyCode.F24;

            case dom_caret:         return KeyCode.CARET;
            case dom_exclaim:       return KeyCode.EXCLAIM;
            case dom_quotedbl:      return KeyCode.QUOTEDBL;
            case dom_hash:          return KeyCode.HASH;
            case dom_dollar:        return KeyCode.DOLLAR;
            case dom_percent:       return KeyCode.PERCENT;
            case dom_ampersand:     return KeyCode.AMPERSAND;
            case dom_underscore:    return KeyCode.UNDERSCORE;
            case dom_leftparen:     return KeyCode.LEFTPAREN;
            case dom_rightparen:    return KeyCode.RIGHTPAREN;
            case dom_asterisk:      return KeyCode.ASTERISK;
            case dom_plus:          return KeyCode.PLUS;
            case dom_pipe:          return KeyCode.BACKSLASH; // pipe
            case dom_minus:         return KeyCode.MINUS;
            case dom_leftbrace:     return KeyCode.LEFTBRACKET; // {, same code as [ on native...
            case dom_rightbrace:    return KeyCode.RIGHTBRACKET; // }, same code as ] on native...
            case dom_tilde:         return KeyCode.BACKQUOTE; // tilde

            case dom_audiomute:     return KeyCode.AUDIOMUTE;
            case dom_volumedown:    return KeyCode.VOLUMEDOWN;
            case dom_volumeup:      return KeyCode.VOLUMEUP;

            case dom_comma:         return KeyCode.COMMA;
            case dom_period:        return KeyCode.PERIOD;
            case dom_slash:         return KeyCode.SLASH;
            case dom_backquote:     return KeyCode.BACKQUOTE;
            case dom_leftbracket:   return KeyCode.LEFTBRACKET;
            case dom_rightbracket:  return KeyCode.RIGHTBRACKET;
            case dom_backslash:     return KeyCode.BACKSLASH;
            case dom_quote:         return KeyCode.QUOTE;

        }

        return keyCode;

    }

    // the keycodes below are dom specific keycodes mapped to snow input names
    // these values *come from the browser* dom spec codes only, some info here
    // http://www.w3.org/TR/DOM-Level-3-Events/#determine-keydown-keyup-keyCode

    static inline var dom_shift          = 16;
    static inline var dom_ctrl           = 17;
    static inline var dom_alt            = 18;
    static inline var dom_capslock       = 20;

    static inline var dom_pageup         = 33;
    static inline var dom_pagedown       = 34;
    static inline var dom_end            = 35;
    static inline var dom_home           = 36;
    static inline var dom_left           = 37;
    static inline var dom_up             = 38;
    static inline var dom_right          = 39;
    static inline var dom_down           = 40;
    static inline var dom_printscr       = 44;
    static inline var dom_insert         = 45;
    static inline var dom_delete         = 46;

    static inline var dom_lmeta          = 91;
    static inline var dom_rmeta          = 93;

    static inline var dom_kp_0           = 96;
    static inline var dom_kp_1           = 97;
    static inline var dom_kp_2           = 98;
    static inline var dom_kp_3           = 99;
    static inline var dom_kp_4           = 100;
    static inline var dom_kp_5           = 101;
    static inline var dom_kp_6           = 102;
    static inline var dom_kp_7           = 103;
    static inline var dom_kp_8           = 104;
    static inline var dom_kp_9           = 105;
    static inline var dom_kp_multiply    = 106;
    static inline var dom_kp_plus        = 107;
    static inline var dom_kp_minus       = 109;
    static inline var dom_kp_decimal     = 110;
    static inline var dom_kp_divide      = 111;
    static inline var dom_kp_numlock     = 144;

    static inline var dom_f1             = 112;
    static inline var dom_f2             = 113;
    static inline var dom_f3             = 114;
    static inline var dom_f4             = 115;
    static inline var dom_f5             = 116;
    static inline var dom_f6             = 117;
    static inline var dom_f7             = 118;
    static inline var dom_f8             = 119;
    static inline var dom_f9             = 120;
    static inline var dom_f10            = 121;
    static inline var dom_f11            = 122;
    static inline var dom_f12            = 123;
    static inline var dom_f13            = 124;
    static inline var dom_f14            = 125;
    static inline var dom_f15            = 126;
    static inline var dom_f16            = 127;
    static inline var dom_f17            = 128;
    static inline var dom_f18            = 129;
    static inline var dom_f19            = 130;
    static inline var dom_f20            = 131;
    static inline var dom_f21            = 132;
    static inline var dom_f22            = 133;
    static inline var dom_f23            = 134;
    static inline var dom_f24            = 135;

    static inline var dom_caret          = 160;
    static inline var dom_exclaim        = 161;
    static inline var dom_quotedbl       = 162;
    static inline var dom_hash           = 163;
    static inline var dom_dollar         = 164;
    static inline var dom_percent        = 165;
    static inline var dom_ampersand      = 166;
    static inline var dom_underscore     = 167;
    static inline var dom_leftparen      = 168;
    static inline var dom_rightparen     = 169;
    static inline var dom_asterisk       = 170;
    static inline var dom_plus           = 171;
    static inline var dom_pipe           = 172; //backslash
    static inline var dom_minus          = 173;
    static inline var dom_leftbrace      = 174;
    static inline var dom_rightbrace     = 175;
    static inline var dom_tilde          = 176;

    static inline var dom_audiomute      = 181;
    static inline var dom_volumedown     = 182;
    static inline var dom_volumeup       = 183;

    static inline var dom_comma          = 188;
    static inline var dom_period         = 190;
    static inline var dom_slash          = 191;
    static inline var dom_backquote      = 192;
    static inline var dom_leftbracket    = 219;
    static inline var dom_rightbracket   = 221;
    static inline var dom_backslash      = 220;
    static inline var dom_quote          = 222;
    static inline var dom_meta           = 224;

}
