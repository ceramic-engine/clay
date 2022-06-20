package clay.web;

import clay.Config;
import clay.Types;
import clay.opengl.GL;

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

    /**
     * For advanced usage: disable handling of mouse events
     */
    public var skipMouseEvents:Bool = false;

    /**
     * For advanced usage: disable handling of keyboard events
     */
    public var skipKeyboardEvents:Bool = false;

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

    var pendingKeyUps:Array<Dynamic> = [];

    var keyDownStates = new IntMap<Bool>();

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

        var newTimestamp = timestamp();
        if (app.shouldUpdate(newTimestamp)) {
            app.emitTick(newTimestamp);
        }

        clearPendingKeyUps();

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
            gl = window.getContext('webgl${config.webgl.version}', attr);
            if (gl == null) {
                gl = window.getContext('experimental-webgl${config.webgl.version}', attr);
            }
        }

        // Minimum requirement: webgl 1 (if nothing else worked)
        if (gl == null) {
            gl = window.getContextWebGL(attr);
        }

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

        js.Browser.document.addEventListener('fullscreenchange', handleFullscreenChange);
        js.Browser.document.addEventListener('fullscreenerror', handleFullscreenError);

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

    function handleFullscreenChange(ev:js.html.Event) {

        // document.fullscreenElement will point to the element that
        // is in fullscreen mode if there is one. If there isn't one,
        // the value of the property is null.
        var document = js.Browser.document;
        var fullscreenElement = untyped document.fullscreenElement;
        if (fullscreenElement != null) {
            Log.debug('Web / Entering fullscreen (id=${fullscreenElement.id})');
            app.config.window.fullscreen = true;
            app.emitWindowEvent(ENTER_FULLSCREEN, timestamp(), webWindowId, 0, 0);
        }
        else {
            Log.debug('Web / Leaving fullscreen');
            app.config.window.fullscreen = false;
            app.emitWindowEvent(EXIT_FULLSCREEN, timestamp(), webWindowId, 0, 0);
        }

    }

    function handleFullscreenError(ev:js.html.Event) {

        Log.warning('Web / Failed to change fullscreen setting: ' + ev);

    }

    function handleMouseEnter(ev:js.html.MouseEvent) {

        app.emitWindowEvent(ENTER, timestamp(), webWindowId, 0, 0);

    }

    function handleMouseLeave(ev:js.html.MouseEvent) {

        app.emitWindowEvent(LEAVE, timestamp(), webWindowId, 0, 0);

    }

    function handleMouseDown(ev:js.html.MouseEvent) {

        if (skipMouseEvents)
            return;

        app.input.emitMouseDown(
            translateMouseX(ev),
            translateMouseY(ev),
            ev.button,
            timestamp(),
            webWindowId
        );

    }

    function handleMouseUp(ev:js.html.MouseEvent) {

        if (skipMouseEvents)
            return;

        app.input.emitMouseUp(
            translateMouseX(ev),
            translateMouseY(ev),
            ev.button,
            timestamp(),
            webWindowId
        );

    }

    function handleMouseMove(ev:js.html.MouseEvent) {

        if (skipMouseEvents)
            return;

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

        if (skipMouseEvents)
            return;

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

    function clearPendingKeyUps() {

        while (pendingKeyUps.length > 0) {
            var info = pendingKeyUps.shift();

            if (keyDownStates.get(info.keyCode) == true) {
                keyDownStates.set(info.keyCode, false);
                app.input.emitKeyUp(
                    info.keyCode,
                    info.scanCode,
                    info.repeat,
                    info.modState,
                    timestamp(),
                    info.windowId
                );
            }
        }

    }

    function handleKeyDown(ev:js.html.KeyboardEvent) {

        if (skipKeyboardEvents)
            return;

        var keyCode = convertKeyCode(ev.keyCode);
        var scanCode = convertScanCode(ev.code, keyCode);
        var modState = modStateFromEvent(ev);

        if (!modState.none) {
            switch keyCode {
                case LCTRL | RCTRL | LMETA | RMETA | LSHIFT | RSHIFT | LALT | RALT:
                default:
                    if (modState.lctrl || modState.rctrl || modState.lalt || modState.ralt || modState.lmeta || modState.rmeta) {
                        // On web (and apparently specifically on mac), keyUp events are not fired by
                        // the browser if a modifier key is pressed. So in that case, we trigger a fake
                        // keyUp event in the next frame of the keys pressed with a modifier key to
                        // try to keep a consistent behaviour with other targets
                        pendingKeyUps.push({
                            keyCode: keyCode,
                            scanCode: scanCode,
                            repeat: ev.repeat,
                            modState: modState,
                            windowId: webWindowId
                        });
                    }
            }
        }

        if (app.config.runtime.preventDefaultKeys.indexOf(keyCode) != -1) {
            ev.preventDefault();
        }

        keyDownStates.set(keyCode, true);

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

        if (skipKeyboardEvents)
            return;

        var keyCode = convertKeyCode(ev.keyCode);
        var scanCode = convertScanCode(ev.code, keyCode);
        var modState = modStateFromEvent(ev);

        if (app.config.runtime.preventDefaultKeys.indexOf(keyCode) != -1) {
            ev.preventDefault();
        }

        if (keyDownStates.get(keyCode) == true) {
            keyDownStates.set(keyCode, false);
            app.input.emitKeyUp(
                keyCode,
                scanCode,
                ev.repeat,
                modState,
                timestamp(),
                webWindowId
            );
        }

    }

    function handleKeyPress(ev:js.html.KeyboardEvent) {

        if (skipKeyboardEvents)
            return;

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

    /** This taks a KeyboardEvent.code value and returns a clay ScanCode value */
    function convertScanCode(rawCode:String, keyCode:KeyCode):ScanCode {

        if (rawCode == null)
            return KeyCode.toScanCode(keyCode);

        return switch rawCode {
            default: KeyCode.toScanCode(keyCode);
            case 'Escape': ScanCode.ESCAPE;
            case 'Digit1': ScanCode.KEY_1;
            case 'Digit2': ScanCode.KEY_2;
            case 'Digit3': ScanCode.KEY_3;
            case 'Digit4': ScanCode.KEY_4;
            case 'Digit5': ScanCode.KEY_5;
            case 'Digit6': ScanCode.KEY_6;
            case 'Digit7': ScanCode.KEY_7;
            case 'Digit8': ScanCode.KEY_8;
            case 'Digit9': ScanCode.KEY_9;
            case 'Digit0': ScanCode.KEY_0;
            case 'Minus': ScanCode.MINUS;
            case 'Equal': ScanCode.EQUALS;
            case 'Backspace': ScanCode.BACKSPACE;
            case 'Tab': ScanCode.TAB;
            case 'KeyA': ScanCode.KEY_A;
            case 'KeyB': ScanCode.KEY_B;
            case 'KeyC': ScanCode.KEY_C;
            case 'KeyD': ScanCode.KEY_D;
            case 'KeyE': ScanCode.KEY_E;
            case 'KeyF': ScanCode.KEY_F;
            case 'KeyG': ScanCode.KEY_G;
            case 'KeyH': ScanCode.KEY_H;
            case 'KeyI': ScanCode.KEY_I;
            case 'KeyJ': ScanCode.KEY_J;
            case 'KeyK': ScanCode.KEY_K;
            case 'KeyL': ScanCode.KEY_L;
            case 'KeyM': ScanCode.KEY_M;
            case 'KeyN': ScanCode.KEY_N;
            case 'KeyO': ScanCode.KEY_O;
            case 'KeyP': ScanCode.KEY_P;
            case 'KeyQ': ScanCode.KEY_Q;
            case 'KeyR': ScanCode.KEY_R;
            case 'KeyS': ScanCode.KEY_S;
            case 'KeyT': ScanCode.KEY_T;
            case 'KeyU': ScanCode.KEY_U;
            case 'KeyV': ScanCode.KEY_V;
            case 'KeyW': ScanCode.KEY_W;
            case 'KeyX': ScanCode.KEY_X;
            case 'KeyY': ScanCode.KEY_Y;
            case 'KeyZ': ScanCode.KEY_Z;
            case 'BracketLeft': ScanCode.LEFTBRACKET;
            case 'BracketRight': ScanCode.RIGHTBRACKET;
            case 'Enter': ScanCode.ENTER;
            case 'ControlLeft': ScanCode.LCTRL;
            case 'ControlRight': ScanCode.RCTRL;
            case 'Semicolon': ScanCode.SEMICOLON;
            case 'Quote': ScanCode.APOSTROPHE;
            case 'Backquote': ScanCode.GRAVE;
            case 'ShiftLeft': ScanCode.LSHIFT;
            case 'ShiftRight': ScanCode.RSHIFT;
            case 'Backslash': ScanCode.BACKSLASH;
            case 'Comma': ScanCode.COMMA;
            case 'Period': ScanCode.PERIOD;
            case 'Slash': ScanCode.SLASH;
            case 'AltLeft': ScanCode.LALT;
            case 'AltRight': ScanCode.RALT;
            case 'Space': ScanCode.SPACE;
            case 'CapsLock': ScanCode.CAPSLOCK;
            case 'F1': ScanCode.F1;
            case 'F2': ScanCode.F2;
            case 'F3': ScanCode.F3;
            case 'F4': ScanCode.F4;
            case 'F5': ScanCode.F5;
            case 'F6': ScanCode.F6;
            case 'F7': ScanCode.F7;
            case 'F8': ScanCode.F8;
            case 'F9': ScanCode.F9;
            case 'F10': ScanCode.F10;
            case 'F11': ScanCode.F11;
            case 'F12': ScanCode.F12;
            case 'Pause': ScanCode.PAUSE;
            case 'ScrollLock': ScanCode.SCROLLLOCK;
            case 'Numpad0': ScanCode.KP_0;
            case 'Numpad1': ScanCode.KP_1;
            case 'Numpad2': ScanCode.KP_2;
            case 'Numpad3': ScanCode.KP_3;
            case 'Numpad4': ScanCode.KP_4;
            case 'Numpad5': ScanCode.KP_5;
            case 'Numpad6': ScanCode.KP_6;
            case 'Numpad7': ScanCode.KP_7;
            case 'Numpad8': ScanCode.KP_8;
            case 'Numpad9': ScanCode.KP_9;
            case 'NumpadMultiply': ScanCode.KP_MULTIPLY;
            case 'NumpadSubtract': ScanCode.KP_MINUS;
            case 'NumpadAdd': ScanCode.KP_PLUS;
            case 'NumpadDecimal': ScanCode.KP_DECIMAL;
            case 'NumpadEqual': ScanCode.KP_EQUALS;
            case 'NumpadComma': ScanCode.KP_COMMA;
            case 'NumpadEnter': ScanCode.KP_ENTER;
            case 'NumpadDivide': ScanCode.KP_DIVIDE;
            case 'PrintScreen': ScanCode.PRINTSCREEN;
            case 'IntlBackslash': ScanCode.NONUSBACKSLASH;
            case 'Lang1' | 'KanaMode': ScanCode.LANG1;
            case 'Lang2': ScanCode.LANG2;
            case 'Lang3': ScanCode.LANG3;
            case 'Lang4': ScanCode.LANG4;
            case 'Lang5': ScanCode.LANG5;
            case 'Lang6': ScanCode.LANG6;
            case 'Lang7': ScanCode.LANG7;
            case 'Lang8': ScanCode.LANG8;
            case 'Lang9': ScanCode.LANG9;
            case 'MediaTrackNext': ScanCode.AUDIONEXT;
            case 'MediaTrackPrevious': ScanCode.AUDIOPREV;
            case 'MediaPlayPause': ScanCode.AUDIOPLAY;
            case 'MediaStop': ScanCode.AUDIOSTOP;
            case 'AudioVolumeMute': ScanCode.AUDIOMUTE;
            case 'LaunchApp1': ScanCode.APP1;
            case 'LaunchApp2': ScanCode.APP2;
            case 'VolumeDown' | 'AudioVolumeDown': ScanCode.VOLUMEDOWN;
            case 'VolumeUp' | 'AudioVolumeUp': ScanCode.VOLUMEUP;
            case 'NumLock': ScanCode.NUMLOCKCLEAR;
            case 'Home': ScanCode.HOME;
            case 'ArrowUp': ScanCode.UP;
            case 'ArrowDown': ScanCode.DOWN;
            case 'ArrowRight': ScanCode.RIGHT;
            case 'ArrowLeft': ScanCode.LEFT;
            case 'End': ScanCode.END;
            case 'PageUp': ScanCode.PAGEUP;
            case 'PageDown': ScanCode.PAGEDOWN;
            case 'Insert' | 'Help': ScanCode.INSERT;
            case 'Delete': ScanCode.DELETE;
            case 'OSLeft' | 'MetaLeft': ScanCode.LMETA;
            case 'OSRight' | 'MetaRight': ScanCode.RMETA;
            case 'ContextMenu': ScanCode.MENU;
            case 'Power': ScanCode.POWER;
            case 'BrowserHome': ScanCode.AC_HOME;
            case 'BrowserSearch': ScanCode.AC_SEARCH;
            case 'BrowserFavorites': ScanCode.AC_BOOKMARKS;
            case 'BrowserRefresh': ScanCode.AC_REFRESH;
            case 'BrowserStop': ScanCode.AC_STOP;
            case 'BrowserForward': ScanCode.AC_FORWARD;
            case 'BrowserBack': ScanCode.AC_BACK;
            case 'Cancel': ScanCode.CANCEL;
            case 'LaunchMail': ScanCode.MAIL;
            case 'MediaSelect': ScanCode.MEDIASELECT;
        }

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

    public function setWindowFullscreen(fullscreen:Bool):Bool {

        if (fullscreen) {
            window.requestFullscreen();
        }
        else {
            js.Browser.document.exitFullscreen();
        }

        return true;

    }

    public function setWindowTitle(title:String):Void {

        app.config.window.title = title;

        js.Browser.document.title = title;

    }

    inline function clamp(n:Float) return Math.max(0, Math.min(n, 1));

    public function startGamepadRumble(gamepadId:Int, lowFrequency:Float, highFrequency:Float, duration:Float) {

        var list = getGamepadList();
        var gamepad = list[gamepadId];
        if (gamepad == null) return;

        var vibrationActuator = untyped gamepad.vibrationActuator;
        if (vibrationActuator == null) return;

        vibrationActuator.playEffect('dual-rumble', {
            duration: duration * 1000,
            weakMagnitude: clamp(lowFrequency),
            strongMagnitude: clamp(highFrequency),
        });

    }

    public function stopGamepadRumble(gamepadId:Int) {

        var list = getGamepadList();
        var gamepad = list[gamepadId];
        if (gamepad == null) return;

        var vibrationActuator = untyped gamepad.vibrationActuator;
        if (vibrationActuator == null) return;
        vibrationActuator.playEffect('dual-rumble', {
            duration: 1,
            weakMagnitude: 0,
            strongMagnitude: 0,
        });

    }

    public function getGamepadName(index:Int):String {

        var list = getGamepadList();
        if (list != null) {
            for (gamepad in list) {
                if (gamepad != null && gamepad.index == index) {
                    return gamepad.id;
                }
            }
        }

        return null;

    }

/// Helpers

    inline public static function timestamp():Float {

        return (js.Browser.window.performance.now() / 1000.0) - timestampStart;

    }

    public static function defaultConfig():RuntimeConfig {

        return {
            windowId: 'app',
            windowParent: js.Browser.document.body,
            preventDefaultContextMenu: #if clay_allow_default_context_menu false #else true #end,
            preventDefaultMouseWheel: #if clay_allow_default_mouse_wheel false #else true #end,
            preventDefaultTouches: #if clay_allow_default_touches false #else true #end,
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
