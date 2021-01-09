package clay.sdl;

import clay.opengl.GLGraphics;
import clay.Config;
import clay.Types;

import sdl.SDL;
import timestamp.Timestamp;

#if clay_use_glew
import glew.GLEW;
#end

#if (!clay_no_initial_glclear && linc_opengl)
import opengl.WebGL as GL;
#end

/**
 * Native runtime, using SDL to operate
 */
@:access(clay.Clay)
@:access(clay.Input)
@:access(clay.Screen)
class SDLRuntime extends clay.base.BaseRuntime {

/// Properties

    /**
     * The SDL GL context
     */
    public var gl:sdl.GLContext;

    /**
     * The SDL window handle
     */
    public var window:sdl.Window;

    /**
     * Current SDL event being handled, if any
     */
    public var currentSdlEvent:sdl.Event = null;

/// Internal

    var timestampStart:Float;

    var windowW:Int;

    var windowH:Int;

    var windowDpr:Float = 1.0;

    /** Map of gamepad index to SDL gamepad instance */
    var gamepads:IntMap<sdl.GameController>;

    /** Map of joystick index to SDL joystick instance */
    var joysticks:IntMap<sdl.Joystick>;

/// Lifecycle

    override function init() {

        timestampStart = Timestamp.now();
        name = 'sdl';

        gamepads = new IntMap();
        joysticks = new IntMap();

        initSDL();
        initCwd();

    }

    override function ready() {

        createWindow();

        Log.debug('SDL / ready');
        
    }

    override function run():Bool {

        var done = true;

        #if (ios || tvos)

        done = false;
        Log.debug('SDL / attaching iOS CADisplayLink loop');
        SDL.iPhoneSetAnimationCallback(window, 1, loop, null);

        #else

        Log.debug('SDL / running main loop');

        while (!app.shuttingDown) {
            loop(0);
        }

        #end

        return done;

    }

    override function shutdown(immediate:Bool = false) {

        if (!immediate) {
            SDL.quit();
            Log.debug('SDL / shutdown');
        } else {
            Log.debug('SDL / shutdown immediate');
        }

    }

/// Internal

    function initSDL() {

        // Init SDL
        var status = SDL.init(SDL_INIT_TIMER);
        if (status != 0) {
            throw 'SDL / Failed to init: ${SDL.getError()}';
        }

        // Init video
        var status = SDL.initSubSystem(SDL_INIT_VIDEO);
        if (status != 0) {
            throw 'SDL / Failed to init video: ${SDL.getError()}';
        }
        else {
            Log.debug('SDL / init video');
        }

        // Init controllers
        var status = SDL.initSubSystem(SDL_INIT_GAMECONTROLLER);
        if (status == -1) {
            Log.warning('SDL / Failed to init controller: ${SDL.getError()}');
        }
        else {
            Log.debug('SDL / init controller');
        }

        // Init joystick
        var status = SDL.initSubSystem(SDL_INIT_JOYSTICK);
        if (status == -1) {
            Log.warning('SDL / Failed to init joystick: ${SDL.getError()}');
        }
        else {
            Log.debug('SDL / init joystick');
        }

        // Init haptic
        var status = SDL.initSubSystem(SDL_INIT_HAPTIC);
        if (status == -1) {
            Log.warning('SDL / Failed to init haptic: ${SDL.getError()}');
        }
        else {
            Log.debug('SDL / init haptic');
        }

        // Mobile events
        #if (android || ios || tvos)
        SDL.addEventWatch(handleSdlEventWatch, null);
        #end

        Log.success('SDL / init success');

    }

    function initCwd() {

        var appPath = app.io.appPath();

        Log.debug('Runtime / init with app path $appPath');
        if (appPath != null && appPath != '') {
            Sys.setCwd(appPath);
        }
        else {
            Log.debug('Runtime / no need to change cwd');
        }

    }

    function createWindow() {

        Log.debug('SDL / create window');

        var config = app.config;
        var windowConfig = config.window;

        applyGLAttributes(config.render);

        windowW = windowConfig.width;
        windowH = windowConfig.height;

        // Init SDL video subsystem
        var status = SDL.initSubSystem(SDL_INIT_VIDEO);
        if (status != 0) {
            throw 'SDL / failed to init video: ${SDL.getError()}';
        }
        else {
            Log.debug('SDL / init video');
        }

        #if windows
        // Get DPI info (needed on windows to adapt window size)
        var dpiInfo:Array<cpp.Float32> = [];
        SDL.getDisplayDPI(0, dpiInfo);
        var createWindowWidth:Int = Std.int(windowConfig.width * dpiInfo[1] / dpiInfo[3]);
        var createWindowHeight:Int = Std.int(windowConfig.height * dpiInfo[2] / dpiInfo[3]);
        #else
        var createWindowWidth:Int = windowConfig.width;
        var createWindowHeight:Int = windowConfig.height;
        #end

        // Create window
        window = SDL.createWindow('' + windowConfig.title, windowConfig.x, windowConfig.y, createWindowWidth, createWindowHeight, windowFlags(windowConfig));

        if (window == null) {
            throw 'SDL / failed to create window: ${SDL.getError()}';
        }

        var windowId:Int = SDL.getWindowID(window);

        Log.debug('SDL / created window with id: $windowId');
        Log.debug('SDL / creating render context...');

        if (!createRenderContext(window)) {
            throw 'SDL / failed to create render context: ${SDL.getError()}';
        }

        postRenderContext(window);

        var actualConfig = app.copyWindowConfig(windowConfig);
        var actualRender = app.copyRenderConfig(app.config.render);

        actualConfig = updateWindowConfig(window, actualConfig);
        actualRender = updateRenderConfig(window, actualRender);

    }

    function applyGLAttributes(render:RenderConfig) {

        Log.debug('SDL / GL / RBGA / ${render.redBits} ${render.greenBits} ${render.blueBits} ${render.alphaBits}');

        SDL.GL_SetAttribute(SDL_GL_RED_SIZE,     render.redBits);
        SDL.GL_SetAttribute(SDL_GL_GREEN_SIZE,   render.greenBits);
        SDL.GL_SetAttribute(SDL_GL_BLUE_SIZE,    render.blueBits);
        SDL.GL_SetAttribute(SDL_GL_ALPHA_SIZE,   render.alphaBits);
        SDL.GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

        if (render.depth > 0) {
            Log.debug('SDL / GL / depth / ${render.depth}');
            SDL.GL_SetAttribute(SDL_GL_DEPTH_SIZE, render.depth);
        }

        if (render.stencil > 0) {
            Log.debug('SDL / GL / stencil / ${render.stencil}');
            SDL.GL_SetAttribute(SDL_GL_STENCIL_SIZE, render.stencil);
        }

        if (render.antialiasing > 0) {
            Log.debug('SDL / GL / MSAA / ${render.antialiasing}');
            SDL.GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
            SDL.GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, render.antialiasing);
        }

        Log.debug('SDL / GL / profile / ${render.opengl.profile}');

        switch render.opengl.profile {

            case COMPATIBILITY:
                SDL.GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDLGLprofile.SDL_GL_CONTEXT_PROFILE_COMPATIBILITY);

            case CORE:
                SDL.GL_SetAttribute(SDL_GL_ACCELERATED_VISUAL, 1);
                SDL.GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDLGLprofile.SDL_GL_CONTEXT_PROFILE_CORE);

            case GLES:
                SDL.GL_SetAttribute(SDL_GL_ACCELERATED_VISUAL, 1);
                SDL.GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDLGLprofile.SDL_GL_CONTEXT_PROFILE_ES);

                if (render.opengl.major == 0) {
                    render.opengl.major = 2;
                    render.opengl.minor = 0;
                }
        }

        if (render.opengl.major != 0) {
            Log.debug('SDL / GL / version / ${render.opengl.major}.${render.opengl.minor}');
            SDL.GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, render.opengl.major);
            SDL.GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, render.opengl.minor);
        }

    }

    function windowFlags(config:WindowConfig) {

        var flags:SDLWindowFlags = 0;

        flags |= SDL_WINDOW_OPENGL;
        flags |= SDL_WINDOW_ALLOW_HIGHDPI;

        trace('RESIZABLE: ' + config.resizable);
        if (config.resizable)  flags |= SDL_WINDOW_RESIZABLE;
        if (config.borderless) flags |= SDL_WINDOW_BORDERLESS;

        if (config.fullscreen) {
            if (!config.trueFullscreen) {
                flags |= SDL_WINDOW_FULLSCREEN_DESKTOP;
            } else {
                #if !mac
                flags |= SDL_WINDOW_FULLSCREEN;
                #end
            }
        }

        return flags;

    }

    function createRenderContext(window:sdl.Window):Bool {

        gl = SDL.GL_CreateContext(window);

        var success = (gl.isnull() == false);

        if (success) {
            Log.success('SDL / GL init success');
        }
        else {
            Log.error('SDL / GL init error');
        }

        return success;

    }

    function postRenderContext(window:sdl.Window) {

        SDL.GL_MakeCurrent(window, gl);

        #if clay_use_glew
        var result = GLEW.init();
        if (result != GLEW.OK) {
            throw 'SDL / failed to setup created render context: ${GLEW.error(result)}';
        } else {
            Log.debug('SDL / GLEW init / ok');
        }
        #end

        // Also clear the garbage in both front/back buffer
        #if (!clay_no_initial_glclear && linc_opengl)

        var color = app.config.render.defaultClear;

        GL.clearDepth(1.0);
        GL.clearStencil(0);
        GL.clearColor(color.r, color.g, color.b, color.a);
        GL.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT | GL.STENCIL_BUFFER_BIT);
        windowSwap();
        GL.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT | GL.STENCIL_BUFFER_BIT);

        GLGraphics.setup();

        #end

    }

    function updateWindowConfig(window:sdl.Window, config:WindowConfig):WindowConfig {

        if (config.fullscreen) {
            if (config.trueFullscreen) {
                #if mac
                SDL.setWindowFullscreen(window, SDL_WINDOW_FULLSCREEN);
                #end
            }
        }

        var size = SDL.GL_GetDrawableSize(window, { w: config.width, h: config.height });
        var pos = SDL.getWindowPosition(window, { x: config.x, y: config.y });

        config.x = pos.x;
        config.y = pos.y;
        config.width = windowW = size.w;
        config.height = windowH = size.h;

        windowDpr = windowDevicePixelRatio();
        Log.debug('SDL / window / x=${config.x} y=${config.y} w=${config.width} h=${config.height} scale=$windowDpr');

        return config;

    }

    function updateRenderConfig(window:sdl.Window, render:RenderConfig):RenderConfig {

        render.antialiasing = SDL.GL_GetAttribute(SDL_GL_MULTISAMPLESAMPLES);
        render.redBits      = SDL.GL_GetAttribute(SDL_GL_RED_SIZE);
        render.greenBits    = SDL.GL_GetAttribute(SDL_GL_GREEN_SIZE);
        render.blueBits     = SDL.GL_GetAttribute(SDL_GL_BLUE_SIZE);
        render.alphaBits    = SDL.GL_GetAttribute(SDL_GL_ALPHA_SIZE);
        render.depth        = SDL.GL_GetAttribute(SDL_GL_DEPTH_SIZE);
        render.stencil      = SDL.GL_GetAttribute(SDL_GL_STENCIL_SIZE);

        render.opengl.major = SDL.GL_GetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION);
        render.opengl.minor = SDL.GL_GetAttribute(SDL_GL_CONTEXT_MINOR_VERSION);

        var profile:SDLGLprofile = SDL.GL_GetAttribute(SDL_GL_CONTEXT_PROFILE_MASK);
        switch profile {

            case SDL_GL_CONTEXT_PROFILE_COMPATIBILITY:
               render.opengl.profile = COMPATIBILITY;

            case SDL_GL_CONTEXT_PROFILE_CORE:
               render.opengl.profile = CORE;

            case SDL_GL_CONTEXT_PROFILE_ES:
               render.opengl.profile = GLES;

        }

        return render;

    }

    static var _sdlSize:SDLSize = { w:0, h:0 };

/// Public API

    override function windowDevicePixelRatio():Float {

        _sdlSize = SDL.GL_GetDrawableSize(window, _sdlSize);
        var pixelHeight = _sdlSize.w;

        _sdlSize = SDL.getWindowSize(window, _sdlSize);
        var deviceHeight = _sdlSize.w;

        return pixelHeight / deviceHeight;

    }

    override inline public function windowWidth():Int {

        return windowW;

    }

    override inline public function windowHeight():Int {

        return windowH;

    }

    public function windowSwap() {

        SDL.GL_SwapWindow(window);

    }

    function loop(_) {

        inline function _loop() {

            while (SDL.hasAnEvent()) {

                var e = SDL.pollEvent();

                currentSdlEvent = e;

                handleInputEvent(e);
                handleWindowEvent(e);

                app.events.sdlEvent(e);

                if (e.type == SDL_QUIT) {
                    app.emitQuit();
                }

                currentSdlEvent = null;

            }

            app.emitTick();

            if (app.config.runtime.autoSwap && !app.hasShutdown) {

                #if !clay_native_no_tick_sleep
        
                #if mac
                // Prevent the app from using 100% CPU for nothing because vsync
                // Doesn't work properly on mojave
                // TODO fix the actual vsync issue
                Sys.sleep(0.001);
                #else
                Sys.sleep(0);
                #end
        
                #end

                windowSwap();
            }

        }
        
        if (app.config.runtime.uncaughtErrorHandler != null) {
            try {
                _loop();
            } catch (e:Dynamic) {
                app.config.runtime.uncaughtErrorHandler(e);
            }
        }
        else {
            _loop();
        }

    }

/// Input

    function handleInputEvent(e:sdl.Event) {

        switch e.type {

        /// Keys

            case SDL_KEYDOWN:
                app.input.emitKeyDown(
                    e.key.keysym.sym,
                    e.key.keysym.scancode,
                    e.key.repeat,
                    toKeyMod(e.key.keysym.mod),
                    e.key.timestamp / 1000.0,
                    Std.int(e.key.windowID)
                );

            case SDL_KEYUP:
                app.input.emitKeyUp(
                    e.key.keysym.sym,
                    e.key.keysym.scancode,
                    e.key.repeat,
                    toKeyMod(e.key.keysym.mod),
                    e.key.timestamp / 1000.0,
                    Std.int(e.key.windowID)
                );

            case SDL_TEXTEDITING:
                app.input.emitText(
                    e.edit.text,
                    e.edit.start,
                    e.edit.length,
                    TextEventType.EDIT,
                    e.edit.timestamp / 1000.0,
                    Std.int(e.edit.windowID)
                );

            case SDL_TEXTINPUT:
                app.input.emitText(
                    e.text.text,
                    0,
                    0,
                    TextEventType.INPUT,
                    e.text.timestamp / 1000.0,
                    Std.int(e.text.windowID)
                );

        /// Mouse

            case SDL_MOUSEMOTION:
                app.input.emitMouseMove(
                    toPixels(e.motion.x),
                    toPixels(e.motion.y),
                    toPixels(e.motion.xrel),
                    toPixels(e.motion.yrel),
                    e.motion.timestamp / 1000.0,
                    Std.int(e.motion.windowID)
                );

            case SDL_MOUSEBUTTONDOWN:
                app.input.emitMouseDown(
                    toPixels(e.button.x),
                    toPixels(e.button.y),
                    e.button.button,
                    e.button.timestamp / 1000.0,
                    Std.int(e.button.windowID)
                );
            case SDL_MOUSEBUTTONUP:
                app.input.emitMouseUp(
                    toPixels(e.button.x),
                    toPixels(e.button.y),
                    e.button.button,
                    e.button.timestamp / 1000.0,
                    Std.int(e.button.windowID)
                );

            case SDL_MOUSEWHEEL:
                app.input.emitMouseWheel(
                    e.wheel.x,
                    e.wheel.y,
                    e.wheel.timestamp / 1000.0,
                    Std.int(e.wheel.windowID)
                );

        /// Touch

            case SDL_FINGERDOWN:
                app.input.emitTouchDown(
                    e.tfinger.x,
                    e.tfinger.y,
                    e.tfinger.dx,
                    e.tfinger.dy,
                    Std.int(e.tfinger.fingerId),
                    e.tfinger.timestamp / 1000.0
                );

            case SDL_FINGERUP:
                app.input.emitTouchUp(
                    e.tfinger.x,
                    e.tfinger.y,
                    e.tfinger.dx,
                    e.tfinger.dy,
                    Std.int(e.tfinger.fingerId),
                    e.tfinger.timestamp / 1000.0
                );

            case SDL_FINGERMOTION:
                app.input.emitTouchMove(
                    e.tfinger.x,
                    e.tfinger.y,
                    e.tfinger.dx,
                    e.tfinger.dy,
                    Std.int(e.tfinger.fingerId),
                    e.tfinger.timestamp / 1000.0
                );

        /// Joystick events

            case SDL_JOYAXISMOTION:

                if (!SDL.isGameController(e.jaxis.which)) {
                    // (range: -32768 to 32767)
                    var val:Float = (e.jaxis.value+32768)/(32767+32768);
                    var normalizedVal = (-0.5 + val) * 2.0;
                    app.input.emitGamepadAxis(
                        e.jaxis.which,
                        e.jaxis.axis,
                        normalizedVal,
                        e.jaxis.timestamp / 1000.0
                    );
                }

            case SDL_JOYBUTTONDOWN:

                if (!SDL.isGameController(e.jbutton.which)) {
                    app.input.emitGamepadDown(
                        e.jbutton.which,
                        e.jbutton.button,
                        1,
                        e.jbutton.timestamp / 1000.0
                    );
                }

            case SDL_JOYBUTTONUP:

                if (!SDL.isGameController(e.jbutton.which)) {
                    app.input.emitGamepadUp(
                        e.jbutton.which,
                        e.jbutton.button,
                        0,
                        e.jbutton.timestamp / 1000.0
                    );
                }

            case SDL_JOYDEVICEADDED:

                if (!SDL.isGameController(e.jdevice.which)) {
                    var joystick = SDL.joystickOpen(e.jdevice.which);
                    joysticks.set(e.jdevice.which, joystick);

                    app.input.emitGamepadDevice(
                        e.jdevice.which,
                        SDL.joystickNameForIndex(e.jdevice.which),
                        GamepadDeviceEventType.DEVICE_ADDED,
                        e.jdevice.timestamp / 1000.0
                    );
                }

            case SDL_JOYDEVICEREMOVED:

                if (!SDL.isGameController(e.jdevice.which)) {
                    var joystick = joysticks.get(e.jdevice.which);
                    SDL.joystickClose(joystick);
                    joysticks.remove(e.jdevice.which);

                    app.input.emitGamepadDevice(
                        e.jdevice.which,
                        SDL.joystickNameForIndex(e.jdevice.which),
                        GamepadDeviceEventType.DEVICE_REMOVED,
                        e.jdevice.timestamp / 1000.0
                    );
                }

        /// Gamepad

            case SDL_CONTROLLERAXISMOTION:
                // (range: -32768 to 32767)
                var val:Float = (e.caxis.value+32768)/(32767+32768);
                var normalizedVal = (-0.5 + val) * 2.0;
                app.input.emitGamepadAxis(
                    e.caxis.which,
                    e.caxis.axis,
                    normalizedVal,
                    e.caxis.timestamp / 1000.0
                );

            case SDL_CONTROLLERBUTTONDOWN:
                app.input.emitGamepadDown(
                    e.cbutton.which,
                    e.cbutton.button,
                    1,
                    e.cbutton.timestamp / 1000.0
                );

            case SDL_CONTROLLERBUTTONUP:
                app.input.emitGamepadUp(
                    e.cbutton.which,
                    e.cbutton.button,
                    0,
                    e.cbutton.timestamp / 1000.0
                );

            case SDL_CONTROLLERDEVICEADDED:

                var _gamepad = SDL.gameControllerOpen(e.cdevice.which);
                gamepads.set(e.cdevice.which, _gamepad);

                app.input.emitGamepadDevice(
                    e.cdevice.which,
                    SDL.gameControllerNameForIndex(e.cdevice.which),
                    GamepadDeviceEventType.DEVICE_ADDED,
                    e.cdevice.timestamp / 1000.0
                );

            case SDL_CONTROLLERDEVICEREMOVED:

                var _gamepad = gamepads.get(e.cdevice.which);
                SDL.gameControllerClose(_gamepad);
                gamepads.remove(e.cdevice.which);

                app.input.emitGamepadDevice(
                    e.cdevice.which,
                    SDL.gameControllerNameForIndex(e.cdevice.which),
                    GamepadDeviceEventType.DEVICE_REMOVED,
                    e.cdevice.timestamp / 1000.0
                );

            case SDL_CONTROLLERDEVICEREMAPPED:
                app.input.emitGamepadDevice(
                    e.cdevice.which,
                    SDL.gameControllerNameForIndex(e.cdevice.which),
                    GamepadDeviceEventType.DEVICE_REMAPPED,
                    e.cdevice.timestamp / 1000.0
                );

            case _:

        }

    }

    inline function toPixels(value:Float):Int {
        return Math.floor(windowDpr * value);
    }

    /** Helper to return a `ModState` (shift, ctrl etc) from a given `InputEvent` */
    function toKeyMod(modValue:Int):ModState {

        var input = app.input;

        input.modState.none    = (modValue == KMOD_NONE);
        input.modState.lshift  = (modValue == KMOD_LSHIFT);
        input.modState.rshift  = (modValue == KMOD_RSHIFT);
        input.modState.lctrl   = (modValue == KMOD_LCTRL);
        input.modState.rctrl   = (modValue == KMOD_RCTRL);
        input.modState.lalt    = (modValue == KMOD_LALT);
        input.modState.ralt    = (modValue == KMOD_RALT);
        input.modState.lmeta   = (modValue == KMOD_LGUI);
        input.modState.rmeta   = (modValue == KMOD_RGUI);
        input.modState.num     = (modValue == KMOD_NUM);
        input.modState.caps    = (modValue == KMOD_CAPS);
        input.modState.mode    = (modValue == KMOD_MODE);
        input.modState.ctrl    = (modValue == KMOD_CTRL  || modValue == KMOD_LCTRL  || modValue == KMOD_RCTRL);
        input.modState.shift   = (modValue == KMOD_SHIFT || modValue == KMOD_LSHIFT || modValue == KMOD_RSHIFT);
        input.modState.alt     = (modValue == KMOD_ALT   || modValue == KMOD_LALT   || modValue == KMOD_RALT);
        input.modState.meta    = (modValue == KMOD_GUI   || modValue == KMOD_LGUI   || modValue == KMOD_RGUI);

        return app.input.modState;

    }

/// Window

    function handleWindowEvent(e:sdl.Event) {

        var data1 = e.window.data1;
        var data2 = e.window.data2;

        if (e.type == SDL_WINDOWEVENT) {
            var type:WindowEventType = UNKNOWN;
            switch e.window.event {

                case SDL_WINDOWEVENT_SHOWN:
                    type = SHOWN;

                case SDL_WINDOWEVENT_HIDDEN:
                    type = HIDDEN;

                case SDL_WINDOWEVENT_EXPOSED:
                    type = EXPOSED;

                case SDL_WINDOWEVENT_MOVED:
                    type = MOVED;

                case SDL_WINDOWEVENT_MINIMIZED:
                    type = MINIMIZED;

                case SDL_WINDOWEVENT_MAXIMIZED:
                    type = MAXIMIZED;

                case SDL_WINDOWEVENT_RESTORED:
                    type = RESTORED;

                case SDL_WINDOWEVENT_ENTER:
                    type = ENTER;

                case SDL_WINDOWEVENT_LEAVE:
                    type = LEAVE;

                case SDL_WINDOWEVENT_FOCUS_GAINED:
                    type = FOCUS_GAINED;

                case SDL_WINDOWEVENT_FOCUS_LOST:
                    type = FOCUS_LOST;

                case SDL_WINDOWEVENT_CLOSE:
                    type = CLOSE;

                case SDL_WINDOWEVENT_RESIZED:
                    type = RESIZED;
                    windowDpr = windowDevicePixelRatio();
                    windowW = data1 = toPixels(data1);
                    windowH = data2 = toPixels(data2);

                case SDL_WINDOWEVENT_SIZE_CHANGED:
                    type = SIZE_CHANGED;
                    windowDpr = windowDevicePixelRatio();
                    windowW = data1 = toPixels(data1);
                    windowH = data2 = toPixels(data2);

                case SDL_WINDOWEVENT_NONE:

            }

            if (type != UNKNOWN) {
                app.emitWindowEvent(type, e.window.timestamp / 1000.0, Std.int(e.window.windowID), data1, data2);
            }
        }

    }

/// Mobile

    function handleSdlEventWatch(_, e:sdl.Event):Int {

        var type:AppEventType = UNKNOWN;

        switch (e.type) {
            case SDL_APP_TERMINATING:
                type = TERMINATING;
            case SDL_APP_LOWMEMORY:
                type = LOW_MEMORY;
            case SDL_APP_WILLENTERBACKGROUND:
                type = WILL_ENTER_BACKGROUND;
            case SDL_APP_DIDENTERBACKGROUND:
                type = DID_ENTER_BACKGROUND;
            case SDL_APP_WILLENTERFOREGROUND:
                type = WILL_ENTER_FOREGROUND;
            case SDL_APP_DIDENTERFOREGROUND:
                type = DID_ENTER_FOREGROUND;
            case _:
                return 0;
        }

        app.emitAppEvent(type);

        return 1;

    }

/// Helpers

    inline public static function timestamp():Float {

        return haxe.Timer.stamp();

    }

}
