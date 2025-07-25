package clay.sdl;

import clay.Config;
import clay.Types;
import clay.opengl.GLGraphics;
import clay.sdl.SDL;
import cpp.Float32;
import cpp.Int16;
import cpp.Int64;
import cpp.NativeArray;
import cpp.UInt16;
import cpp.UInt32;
import cpp.UInt64;
import haxe.atomic.AtomicBool;
import haxe.io.Path;
import sys.FileSystem;
import timestamp.Timestamp;

#if clay_use_glew
import glew.GLEW;
#end

#if clay_use_glad
import glad.GLAD;
#end

#if (!clay_no_initial_glclear && linc_opengl)
import opengl.WebGL as GL;
#end

typedef WindowHandle = UInt32;

#if (gles_angle && ios)
@:headerCode('
#include "linc_sdl.h"
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES3/gl3.h>
')
#elseif (clay_dwm_flush && windows)
@:headerCode('
#include "linc_sdl.h"
#ifdef _WIN32
#include <dwmapi.h>
#pragma comment(lib, "dwmapi.lib")
#endif
')
#else
@:headerCode('#include "linc_sdl.h"')
#end
@:access(clay.Clay)
@:access(clay.Input)
@:access(clay.Screen)
class SDLRuntime extends clay.base.BaseRuntime {

/// Properties

    public var gl:SDLGLContext;
    public var window:SDLWindowPointer;
    public var currentSdlEvent:SDLEvent = null;
    public var skipMouseEvents:Bool = false;
    public var skipKeyboardEvents:Bool = false;
    public var minFrameTime:Float = 0.005;

/// Internal

    static var timestampStart:Float = 0.0;
    var windowW:Int;
    var windowH:Int;
    var windowDpr:Float = 1.0;
    var windowFocused:Bool = true;

    #if (ios || tvos || android)
    var mobileInBackground:AtomicBool = new AtomicBool(false);
    #end

    var gamepads:haxe.ds.IntMap<SDLGamepadPointer>;
    var gamepadInstanceIds:haxe.ds.IntMap<Int> = new haxe.ds.IntMap();
    var joysticks:haxe.ds.IntMap<SDLJoystickPointer>;
    var isSdlFullscreen:Bool = false;
    var fingerIdList:Map<Int64, Int> = new Map();
    var nextFingerId:Int = 1;
    var lastFrameTime:Float = 0;

    var _sdlEvent:SDLEventPointer = null;
    var _sdlPoint:SDLPoint = null;
    var _sdlSize:SDLSize = null;

    #if (gles_angle && ios)
    var _eglDisplay:cpp.RawPointer<Void>;
    var _eglSurface:cpp.RawPointer<Void>;
    var _eglConfig:cpp.RawPointer<Void>;
    #end

    #if (clay_dwm_flush && windows)
    var dwmFlushAvailable:Bool = false;
    #end

/// Lifecycle

    override function init() {

        timestampStart = Timestamp.now();
        name = 'sdl';

        gamepads = new haxe.ds.IntMap();
        joysticks = new haxe.ds.IntMap();

        initSDL();
        initCwd();

        #if android
        cleanupExtractedDirectory();
        #end

    }

    override function ready() {

        createWindow();

        #if (clay_dwm_flush && windows)
        initDwmFlush();
        #end

        Log.debug('SDL / ready');

    }

    override function run():Bool {

        var done = true;

        #if (ios || tvos)

        done = false;
        Log.debug('SDL / iOS / attach animation callback');
        SDL.setiOSAnimationCallback(window, iOSAnimationCallback);

        #else

        Log.debug('SDL / running main loop');

        lastFrameTime = Timestamp.now();
        while (!app.shuttingDown) {
            loop(0);
        }

        #end

        return done;

    }

    #if (ios || tvos)
    function iOSAnimationCallback():Void {
        loop(0);
    }
    #end

    override function shutdown(immediate:Bool = false) {

        if (!immediate) {
            SDL.quit();
            Log.debug('SDL / shutdown');
        } else {
            Log.debug('SDL / shutdown immediate');
        }

    }

/// Internal

    #if (clay_dwm_flush && windows)

    function initDwmFlush():Void {
        // Check if DWM composition is available and enabled
        var dwmEnabled = untyped __cpp__('
            BOOL enabled = FALSE;
            HRESULT hr = DwmIsCompositionEnabled(&enabled);
            (SUCCEEDED(hr) && enabled)
        ');

        if (dwmEnabled) {
            dwmFlushAvailable = true;
            Log.info('SDL / DWM composition enabled - using DwmFlush() for reliable vsync');
        } else {
            Log.info('SDL / DWM composition disabled - using standard vsync');
        }
    }

    function dwmFlush():Bool {
        if (!dwmFlushAvailable) return false;

        var result = untyped __cpp__('DwmFlush()');
        return result == 0; // S_OK
    }

    #end

    function initSDL() {

        SDL.bind();

        #if (gles_angle && !ios)
        // Set SDL hint to use ANGLE for OpenGL ES
        SDL.setHint(SDL.SDL_HINT_OPENGL_ES_DRIVER, "1");
        #end

        // Init value pointers
        _sdlEvent = untyped __cpp__('new SDL_Event()');
        _sdlSize = untyped __cpp__('new ::linc::sdl::SDLSize()');
        _sdlPoint = untyped __cpp__('new ::linc::sdl::SDLPoint()');

        // Init SDL
        var status = SDL.init();
        if (!status) {
            throw 'SDL / failed to init: ${SDL.getError()}';
        }

        // Init SDL events subsystem
        if (!SDL.initSubSystem(SDL.SDL_INIT_EVENTS)) {
            throw 'SDL / failed to init events: ${SDL.getError()}';
        } else {
            Log.debug('SDL / init events');
        }

        // Init video
        if (!SDL.initSubSystem(SDL.SDL_INIT_VIDEO)) {
            throw 'SDL / failed to init video: ${SDL.getError()}';
        } else {
            Log.debug('SDL / init video');
        }

        #if (soloud_use_sdl || sdl_enable_audio)
        // Init audio
        if (!SDL.initSubSystem(SDL.SDL_INIT_AUDIO)) {
            Log.warning('SDL / failed to init audio: ${SDL.getError()}');
        } else {
            Log.debug('SDL / init audio');
        }
        #end

        // Init controllers
        if (!SDL.initSubSystem(SDL.SDL_INIT_GAMEPAD)) {
            Log.warning('SDL / failed to init gamepad: ${SDL.getError()}');
        } else {
            Log.debug('SDL / init gamepad');
        }

        #if clay_sdl_init_sensor
        // Init sensors
        if (!SDL.initSubSystem(SDL.SDL_INIT_SENSOR)) {
            throw 'SDL / failed to init sensor: ${SDL.getError()}';
        } else {
            Log.debug('SDL / init sensor');
        }
        #end

        // Init joystick
        if (!SDL.initSubSystem(SDL.SDL_INIT_JOYSTICK)) {
            Log.warning('SDL / failed to init joystick: ${SDL.getError()}');
        } else {
            Log.debug('SDL / init joystick');
        }

        // Init gamepad
        if (!SDL.initSubSystem(SDL.SDL_INIT_GAMEPAD)) {
            throw 'SDL / failed to init gamepad: ${SDL.getError()}';
        } else {
            Log.debug('SDL / init gamepad');
        }

        // Init haptic
        if (!SDL.initSubSystem(SDL.SDL_INIT_HAPTIC)) {
            Log.warning('SDL / failed to init haptic: ${SDL.getError()}');
        } else {
            Log.debug('SDL / init haptic');
        }

        // Mobile events
        #if (android || ios || tvos)
        SDL.setEventWatch(window, handleSdlEventWatch);
        #end

        Log.success('SDL / init success');

    }

    function initCwd() {

        var appPath = app.io.appPath();

        Log.debug('Runtime / init with app path $appPath');
        if (appPath != null && appPath != '') {
            Sys.setCwd(appPath);
        } else {
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
        if (!SDL.initSubSystem(SDL.SDL_INIT_VIDEO)) {
            throw 'SDL / failed to init video: ${SDL.getError()}';
        } else {
            Log.debug('SDL / init video (window)');
        }

        #if windows
        // Get DPI info (needed on windows to adapt window size)
        var displayID = SDL.getPrimaryDisplay();
        var contentScale = SDL.getDisplayContentScale(displayID);
        var createWindowWidth:Int = Std.int(windowConfig.width * contentScale);
        var createWindowHeight:Int = Std.int(windowConfig.height * contentScale);
        #else
        var createWindowWidth:Int = windowConfig.width;
        var createWindowHeight:Int = windowConfig.height;
        #end

        // Create window
        window = SDL.createWindow(
            windowConfig.title != null ? windowConfig.title : 'clay app',
            windowConfig.x, windowConfig.y,
            createWindowWidth, createWindowHeight,
            windowFlags(windowConfig)
        );

        if (window == null) {
            throw 'SDL / failed to create window: ${SDL.getError()}';
        }

        untyped __cpp__('SDL_SyncWindow({0})', window);

        var windowId:Int = SDL.getWindowID(window);

        Log.debug('SDL / created window with id: $windowId');
        Log.debug('SDL / creating render context...');

        if (!createRenderContext(window, config.render)) {
            throw 'SDL / failed to create render context: ${SDL.getError()}';
        }

        if (setVSync(config.render.vsync)) {
            Log.info('SDL / vsync ${config.render.vsync ? 'enabled' : 'disabled'}');
        }
        else {
            Log.warning('SDL / failed to ${config.render.vsync ? 'enable' : 'disable'} vsync');
        }

        postRenderContext(window);

        var actualConfig = app.copyWindowConfig(windowConfig);
        var actualRender = app.copyRenderConfig(config.render);

        actualConfig = updateWindowConfig(window, actualConfig);
        actualRender = updateRenderConfig(window, actualRender);

    }

    function applyGLAttributes(render:RenderConfig) {

        Log.debug('SDL / GL / RBGA / ${render.redBits} ${render.greenBits} ${render.blueBits} ${render.alphaBits}');

        SDL.GL_SetAttribute(SDL.SDL_GL_RED_SIZE, render.redBits);
        SDL.GL_SetAttribute(SDL.SDL_GL_GREEN_SIZE, render.greenBits);
        SDL.GL_SetAttribute(SDL.SDL_GL_BLUE_SIZE, render.blueBits);
        SDL.GL_SetAttribute(SDL.SDL_GL_ALPHA_SIZE, render.alphaBits);
        SDL.GL_SetAttribute(SDL.SDL_GL_DOUBLEBUFFER, 1);

        if (render.depth > 0) {
            Log.debug('SDL / GL / depth / ${render.depth}');
            SDL.GL_SetAttribute(SDL.SDL_GL_DEPTH_SIZE, render.depth);
        }

        if (render.stencil > 0) {
            Log.debug('SDL / GL / stencil / ${render.stencil}');
            SDL.GL_SetAttribute(SDL.SDL_GL_STENCIL_SIZE, render.stencil);
        }

        if (render.antialiasing > 0) {
            Log.debug('SDL / GL / MSAA / ${render.antialiasing}');
            SDL.GL_SetAttribute(SDL.SDL_GL_MULTISAMPLEBUFFERS, 1);
            SDL.GL_SetAttribute(SDL.SDL_GL_MULTISAMPLESAMPLES, render.antialiasing);
        }

        var glProfile = switch render.opengl.profile {
            case COMPATIBILITY: SDL.SDL_GL_CONTEXT_PROFILE_COMPATIBILITY;
            case CORE: SDL.SDL_GL_CONTEXT_PROFILE_CORE;
            case GLES: SDL.SDL_GL_CONTEXT_PROFILE_ES;
        }

        Log.debug('SDL / GL / profile / ${render.opengl.profile}');
        SDL.GL_SetAttribute(SDL.SDL_GL_CONTEXT_PROFILE_MASK, glProfile);

        if (render.opengl.profile == CORE) {
            SDL.GL_SetAttribute(SDL.SDL_GL_ACCELERATED_VISUAL, 1);
        } else if (render.opengl.profile == GLES) {
            SDL.GL_SetAttribute(SDL.SDL_GL_ACCELERATED_VISUAL, 1);

            if (render.opengl.major == 0) {
                render.opengl.major = 2;
                render.opengl.minor = 0;
            }
        }

        if (render.opengl.major != 0) {
            Log.debug('SDL / GL / version / ${render.opengl.major}.${render.opengl.minor}');
            SDL.GL_SetAttribute(SDL.SDL_GL_CONTEXT_MAJOR_VERSION, render.opengl.major);
            SDL.GL_SetAttribute(SDL.SDL_GL_CONTEXT_MINOR_VERSION, render.opengl.minor);
        }

    }

    function windowFlags(config:WindowConfig):SDLWindowFlags {

        var flags:SDLWindowFlags = 0;

        #if clay_sdl_headless
        untyped __cpp__('{0} |= {1}', flags, SDL.SDL_WINDOW_HIDDEN);
        #end

        #if (gles_angle && ios)
        untyped __cpp__('{0} |= {1}', flags, SDL.SDL_WINDOW_METAL);
        #else
        untyped __cpp__('{0} |= {1}', flags, SDL.SDL_WINDOW_OPENGL);
        #end

        untyped __cpp__('{0} |= {1}', flags, SDL.SDL_WINDOW_HIGH_PIXEL_DENSITY);

        if (config.resizable)  untyped __cpp__('{0} |= {1}', flags, SDL.SDL_WINDOW_RESIZABLE);
        if (config.borderless) untyped __cpp__('{0} |= {1}', flags, SDL.SDL_WINDOW_BORDERLESS);

        if (config.fullscreen) {
            isSdlFullscreen = true;
            if (!config.trueFullscreen) {
                untyped __cpp__('{0} |= {1}', flags, SDL.SDL_WINDOW_FULLSCREEN);
            } else {
                #if !mac
                untyped __cpp__('{0} |= {1}', flags, SDL.SDL_WINDOW_FULLSCREEN);
                #end
            }
        }

        return flags;

    }

    function createRenderContext(window:SDLWindowPointer, render:RenderConfig):Bool {

        #if (gles_angle && ios)

        // On iOS, when using ANGLE, we need to use EGL API and explicit METAL view
        // THANK YOU: https://gist.github.com/SasLuca/307a523d2c6f2900af5823f0792a8a93

        untyped __cpp__('SDL_MetalView metal_view = SDL_Metal_CreateView({0})', window);
        untyped __cpp__('void* metal_layer = SDL_Metal_GetLayer(metal_view)');

        untyped __cpp__('
        EGLAttrib egl_display_attribs[] = {
            EGL_PLATFORM_ANGLE_TYPE_ANGLE, EGL_PLATFORM_ANGLE_TYPE_METAL_ANGLE,
            EGL_POWER_PREFERENCE_ANGLE, EGL_HIGH_POWER_ANGLE,
            EGL_NONE
        }');

        untyped __cpp__('EGLDisplay egl_display = eglGetPlatformDisplay(EGL_PLATFORM_ANGLE_ANGLE, (void*) EGL_DEFAULT_DISPLAY, egl_display_attribs)');
        if (untyped __cpp__('egl_display == EGL_NO_DISPLAY')) {
            Log.error('SDL / failed to get EGL display');
            return false;
        }

        if (untyped __cpp__('eglInitialize(egl_display, NULL, NULL) == false')) {
            Log.error('SDL / failed to initialize EGL');
            return false;
        }

        untyped __cpp__('
        EGLint egl_config_attribs[] = {
            EGL_RED_SIZE, {0},
            EGL_GREEN_SIZE, {1},
            EGL_BLUE_SIZE, {2},
            EGL_ALPHA_SIZE, {3},
            EGL_DEPTH_SIZE, {4},
            EGL_STENCIL_SIZE, {5},
            EGL_COLOR_BUFFER_TYPE, EGL_RGB_BUFFER,
            EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
            EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
            EGL_SAMPLE_BUFFERS, {6},
            EGL_SAMPLES, {7},
            EGL_NONE
        }',
        render.redBits,
        render.greenBits,
        render.blueBits,
        render.alphaBites,
        render.depth,
        render.stencil,
        render.antialiasing > 0 ? 1 : 0,
        render.antialiasing
        );

        untyped __cpp__('EGLConfig egl_config');
        untyped __cpp__('EGLint egl_configs_count');
        if (untyped __cpp__('!eglChooseConfig(egl_display, egl_config_attribs, &egl_config, 1, &egl_configs_count)')) {
            Log.error('SDL / failed to choose EGL config');
            return false;
        }

        untyped __cpp__('
        EGLint egl_context_attribs[] = {
            EGL_CONTEXT_CLIENT_VERSION, 3,
            EGL_NONE
        }');
        untyped __cpp__('EGLContext egl_context = eglCreateContext(egl_display, egl_config, EGL_NO_CONTEXT, egl_context_attribs)');
        if (untyped __cpp__('egl_context == EGL_NO_CONTEXT')) {
            Log.error('SDL / failed to create EGL contex');
            return false;
        }

        untyped __cpp__('EGLSurface egl_surface = eglCreateWindowSurface(egl_display, egl_config, metal_layer, NULL)');
        if (untyped __cpp__('egl_surface == EGL_NO_SURFACE'))
        {
            Log.error('SDL / failed to create EGL surface');
            return false;
        }

        if (untyped __cpp__('!eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context)'))
        {
            Log.error('SDL / failed to make EGL context current');
            return false;
        }

        _eglDisplay = untyped __cpp__('egl_display');
        _eglSurface = untyped __cpp__('egl_surface');
        _eglConfig = untyped __cpp__('egl_config');

        var success = true;

        #else

        // Standard SDL GL context creation
        gl = SDL.GL_CreateContext(window);
        var success = (!gl.isNull());

        #end

        if (success) {
            Log.success('SDL / GL init success');
        } else {
            Log.error('SDL / GL init error');
        }

        return success;

    }

    function postRenderContext(window:SDLWindowPointer) {

        if (gl != null) {
            SDL.GL_MakeCurrent(window, gl);
        }

        #if clay_use_glew
        var result = GLEW.init();
        if (result != GLEW.OK) {
            throw 'SDL / failed to setup created render context: ${GLEW.error(result)}';
        } else {
            Log.debug('SDL / GLEW init / ok');
        }
        #end

        // Log OpenGL information
        var vendor = GL.getParameter(GL.VENDOR);
        var renderer = GL.getParameter(GL.RENDERER);
        var version = GL.getParameter(GL.VERSION);

        Log.info('SDL / GL / Vendor: $vendor');
        Log.info('SDL / GL / Renderer: $renderer');
        Log.info('SDL / GL / Version: $version');

        // Also clear the garbage in both front/back buffer
        #if (!clay_no_initial_gl_clear && linc_opengl)

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

    function setVSync(enabled:Bool):Bool {
        #if (gles_angle && ios)
        // EGL path
        return untyped __cpp__('eglSwapInterval({0}, {1}) == EGL_TRUE', _eglDisplay, enabled ? 1 : 0);
        #else
        // Standard SDL path (Windows ANGLE D3D11, Linux, etc.)
        return SDL.GL_SetSwapInterval(enabled ? 1 : 0);
        #end
    }

    function updateWindowConfig(window:SDLWindowPointer, config:WindowConfig):WindowConfig {

        if (config.fullscreen) {
            if (config.trueFullscreen) {
                #if mac
                SDL.setWindowFullscreen(window, true);
                #end
            }
        }

        SDL.getWindowSizeInPixels(window, _sdlSize);
        var _windowW = _sdlSize.w;
        var _windowH = _sdlSize.h;
        SDL.getWindowPosition(window, _sdlPoint);
        config.x = _sdlPoint.x;
        config.y = _sdlPoint.y;

        windowDpr = windowDevicePixelRatio();
        windowW = toPixels(_windowW);
        windowH = toPixels(_windowH);
        config.width = windowW;
        config.height = windowH;

        Log.debug('SDL / window / x=${config.x} y=${config.y} w=${config.width} h=${config.height} scale=$windowDpr');

        return config;

    }

    function updateRenderConfig(window:SDLWindowPointer, render:RenderConfig):RenderConfig {

        #if (gles_angle && ios)

        untyped __cpp__('
        EGLDisplay egl_display = {0};
        EGLConfig egl_config = {1};

        EGLint actual_red_size, actual_green_size, actual_blue_size, actual_alpha_size;
        EGLint actual_depth_size, actual_stencil_size;
        EGLint actual_surface_type, actual_renderable_type;
        EGLint actual_sample_buffers, actual_samples;

        eglGetConfigAttrib(egl_display, egl_config, EGL_RED_SIZE, &actual_red_size);
        eglGetConfigAttrib(egl_display, egl_config, EGL_GREEN_SIZE, &actual_green_size);
        eglGetConfigAttrib(egl_display, egl_config, EGL_BLUE_SIZE, &actual_blue_size);
        eglGetConfigAttrib(egl_display, egl_config, EGL_ALPHA_SIZE, &actual_alpha_size);
        eglGetConfigAttrib(egl_display, egl_config, EGL_DEPTH_SIZE, &actual_depth_size);
        eglGetConfigAttrib(egl_display, egl_config, EGL_STENCIL_SIZE, &actual_stencil_size);
        eglGetConfigAttrib(egl_display, egl_config, EGL_SURFACE_TYPE, &actual_surface_type);
        eglGetConfigAttrib(egl_display, egl_config, EGL_RENDERABLE_TYPE, &actual_renderable_type);
        eglGetConfigAttrib(egl_display, egl_config, EGL_SAMPLE_BUFFERS, &actual_sample_buffers);
        eglGetConfigAttrib(egl_display, egl_config, EGL_SAMPLES, &actual_samples);
        ',
        _eglDisplay, _eglConfig);

        render.antialiasing = untyped __cpp__('actual_samples');
        render.redBits      = untyped __cpp__('actual_red_size');
        render.greenBits    = untyped __cpp__('actual_green_size');
        render.blueBits     = untyped __cpp__('actual_blue_size');
        render.alphaBits    = untyped __cpp__('actual_alpha_size');
        render.depth        = untyped __cpp__('actual_depth_size');
        render.stencil      = untyped __cpp__('actual_stencil_size');

        render.opengl.major = 3;
        render.opengl.minor = 0;
        render.opengl.profile = GLES;

        #else

        render.antialiasing = SDL.GL_GetAttribute(SDL.SDL_GL_MULTISAMPLESAMPLES);
        render.redBits      = SDL.GL_GetAttribute(SDL.SDL_GL_RED_SIZE);
        render.greenBits    = SDL.GL_GetAttribute(SDL.SDL_GL_GREEN_SIZE);
        render.blueBits     = SDL.GL_GetAttribute(SDL.SDL_GL_BLUE_SIZE);
        render.alphaBits    = SDL.GL_GetAttribute(SDL.SDL_GL_ALPHA_SIZE);
        render.depth        = SDL.GL_GetAttribute(SDL.SDL_GL_DEPTH_SIZE);
        render.stencil      = SDL.GL_GetAttribute(SDL.SDL_GL_STENCIL_SIZE);

        render.opengl.major = SDL.GL_GetAttribute(SDL.SDL_GL_CONTEXT_MAJOR_VERSION);
        render.opengl.minor = SDL.GL_GetAttribute(SDL.SDL_GL_CONTEXT_MINOR_VERSION);

        var profile:Int = SDL.GL_GetAttribute(SDL.SDL_GL_CONTEXT_PROFILE_MASK);
        switch profile {

            case SDL.SDL_GL_CONTEXT_PROFILE_COMPATIBILITY:
               render.opengl.profile = COMPATIBILITY;

            case SDL.SDL_GL_CONTEXT_PROFILE_CORE:
               render.opengl.profile = CORE;

            case SDL.SDL_GL_CONTEXT_PROFILE_ES:
               render.opengl.profile = GLES;

        }

        #end

        return render;

    }

    #if android

    function cleanupExtractedDirectory() {

        var extractedPathDir = Path.join([app.io.appPathPrefs(), 'clay', 'extracted']);
        if (FileSystem.exists(extractedPathDir)) {
            Log.debug('Android / cleanup extracted directory');
            Files.deleteRecursive(extractedPathDir);
        }

    }

    #end

/// Public API

    #if !clay_no_compute_density

    var _didFetchDPI:Bool = false;
    var _computedDensity:Float = 1.0;

    #end

    override function windowDevicePixelRatio():Float {

        #if !clay_no_compute_density

        if (!_didFetchDPI) {
            _didFetchDPI = true;

            untyped __cpp__('SDL_DisplayID display = SDL_GetDisplayForWindow({0})', window);
            final scale:Float = untyped __cpp__('(::Float)SDL_GetDisplayContentScale(display)');
            var density = Math.round(scale * 2) / 2;
            if (density < 1) {
                density = 1;
            }
            _computedDensity = density;
        }

        return _computedDensity;

        #else

        SDL.getWindowSizeInPixels(window, _sdlSize);
        var pixelHeight = _sdlSize.w;

        SDL.getWindowSize(window, _sdlSize);
        var deviceHeight = _sdlSize.w;

        return pixelHeight / deviceHeight;

        #end

    }

    override inline public function windowWidth():Int {

        return windowW;

    }

    override inline public function windowHeight():Int {

        return windowH;

    }

    public function setWindowTitle(title:String):Void {

        app.config.window.title = title;
        SDL.setWindowTitle(window, title);

    }

    public function setWindowBorderless(borderless:Bool):Void {

        app.config.window.borderless = borderless;
        SDL.setWindowBordered(window, !borderless);

    }

    inline function clamp(n:Float) return Math.max(0, Math.min(n, 1));

    public function startGamepadRumble(gamepadId:Int, lowFrequency:Float, highFrequency:Float, duration: Float) {

        var _gamepad = gamepads.get(gamepadId);
        if (_gamepad == null || !SDL.gamepadHasRumble(_gamepad)) return;

        var low:UInt16 = Std.int(0xffff * clamp(lowFrequency));
        var high:UInt16 = Std.int(0xffff * clamp(highFrequency));

        SDL.rumbleGamepad(_gamepad, low, high, Std.int(duration * 1000));

    }

    public function stopGamepadRumble(gamepadId:Int) {

        var _gamepad = gamepads.get(gamepadId);
        if (_gamepad == null || !SDL.gamepadHasRumble(_gamepad)) return;
        SDL.rumbleGamepad(_gamepad, 0, 0, 1);

    }

    public function getGamepadName(index:Int):String {

        var deviceIndex = gamepadInstanceIds.exists(index) ? gamepadInstanceIds.get(index) : index;
        return SDL.getGamepadNameForID(deviceIndex);

    }

    public function setWindowFullscreen(fullscreen:Bool):Bool {

        #if mac
        if (SDL.isWindowInFullscreenSpace(window) && !isSdlFullscreen) {
            Log.debug('Clay / Ignore fullscreen setting because already using mac space fullscreen.');
            return fullscreen;
        }
        #end

        if (app.config.window.fullscreen == fullscreen) {
            // Ignore, same setting as previous
            return true;
        }

        isSdlFullscreen = fullscreen;
        app.config.window.fullscreen = fullscreen;

        return SDL.setWindowFullscreen(window, fullscreen);

    }

    #if (clay_native_sync_objects || clay_native_unfocused_sync_objects)
    /// OpenGL ES 3.0 sync object constants
    static final GL_SYNC_GPU_COMMANDS_COMPLETE = 0x9117;
    static final GL_TIMEOUT_EXPIRED = 0x911B;
    #end

    public function windowSwap() {

        #if (gles_angle && ios)
        untyped __cpp__('eglSwapBuffers({0}, {1})', _eglDisplay, _eglSurface);
        #else
        SDL.GL_SwapWindow(window);
        #end

        #if (clay_dwm_flush && windows)
        // Apply DwmFlush() after SwapBuffers for reliable windowed vsync on Windows
        if (dwmFlushAvailable && !app.config.window.fullscreen) {
            dwmFlush();
        }
        #end

        #if (clay_native_sync_objects || clay_native_unfocused_sync_objects)
        #if clay_native_unfocused_sync_objects
        if (!windowFocused) {
        #end
            untyped __cpp__('GLsync fenceSyncResult = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)');
            if (untyped __cpp__('fenceSyncResult != 0')) {
                var result:Int = GL_TIMEOUT_EXPIRED;
                while (result == GL_TIMEOUT_EXPIRED) {
                    result = untyped __cpp__('glClientWaitSync(fenceSyncResult, 0, 0)'); // Non-blocking poll
                    if (result == GL_TIMEOUT_EXPIRED) {
                        Sys.sleep(0.0001); // Sleep 0.1ms between polls
                    }
                    // Continue until GL_ALREADY_SIGNALED or GL_CONDITION_SATISFIED
                }
                untyped __cpp__('glDeleteSync(fenceSyncResult)');
            }
        #if clay_native_unfocused_sync_objects
        }
        #end
        #elseif clay_unfocused_gl_finish
        if (!windowFocused) {
            GL.finish();
        }
        #elseif clay_gl_finish
        GL.finish();
        #end

    }

    function loop(_) {

        var doUpdate = false;

        inline function _loop() {

            while (SDL.pollEvent(_sdlEvent)) {

                var e = new SDLEvent(_sdlEvent);
                currentSdlEvent = e;

                app.events.sdlEvent(cast _sdlEvent);

                handleInputEvent(e);
                handleWindowEvent(e);

                if (e.type == SDL.SDL_EVENT_QUIT) {
                    app.emitQuit();
                }

                currentSdlEvent = null;

            }

            var newTimestamp = timestamp();
            doUpdate = app.shouldUpdate(newTimestamp);
            if (doUpdate) {
                app.emitTick(newTimestamp);
                app.emitRender();

                #if (mac || windows || linux)
                #if clay_unfocused_native_sleep_after_render
                if (!windowFocused) {
                    var spent = Timestamp.now() - lastFrameTime;
                    if (spent < minFrameTime) Sys.sleep(minFrameTime - spent);
                }
                #elseif clay_native_sleep_after_render
                var spent = Timestamp.now() - lastFrameTime;
                if (spent < minFrameTime) Sys.sleep(minFrameTime - spent);
                #end
                #end
            } else {
                #if !clay_native_no_tick_sleep
                Sys.sleep(0.0001);
                #end
            }

            if (app.config.runtime.autoSwap && !app.hasShutdown) {

                #if ios
                // iOS doesn't like it when we send GPU commands when app is in background
                if (!mobileInBackground.load()) {
                #end
                    if (doUpdate) {
                        windowSwap();
                    }
                #if ios
                }
                #end
            }

            if (doUpdate) {
                lastFrameTime = Timestamp.now();
            }

        }

        if (app.config.runtime.uncaughtErrorHandler != null) {
            try {
                _loop();
            } catch (e:Dynamic) {
                app.config.runtime.uncaughtErrorHandler(e);
            }
        } else {
            _loop();
        }

    }

/// Input

    function handleInputEvent(e:SDLEvent) {

        switch e.type {

        /// Keys

            case SDL.SDL_EVENT_KEY_DOWN:
                if (!skipKeyboardEvents) {
                    app.input.emitKeyDown(
                        e.keycode,
                        e.keyScancode,
                        e.keyRepeat,
                        toKeyMod(e.keymod),
                        e.timestamp.toInt() / 1000.0,
                        Std.int(e.windowID)
                    );
                }

            case SDL.SDL_EVENT_KEY_UP:
                if (!skipKeyboardEvents) {
                    app.input.emitKeyUp(
                        e.keycode,
                        e.keyScancode,
                        e.keyRepeat,
                        toKeyMod(e.keymod),
                        e.timestamp.toInt() / 1000.0,
                        Std.int(e.windowID)
                    );
                }

            case SDL.SDL_EVENT_TEXT_EDITING:
                if (!skipKeyboardEvents) {
                    app.input.emitText(
                        e.editText,
                        e.editStart,
                        e.editLength,
                        TextEventType.EDIT,
                        e.timestamp.toInt() / 1000.0,
                        Std.int(e.windowID)
                    );
                }

            case SDL.SDL_EVENT_TEXT_INPUT:
                if (!skipKeyboardEvents) {
                    app.input.emitText(
                        e.textText,
                        0,
                        0,
                        TextEventType.INPUT,
                        e.timestamp.toInt() / 1000.0,
                        Std.int(e.windowID)
                    );
                }

        /// Mouse

            case SDL.SDL_EVENT_MOUSE_MOTION:
                if (!skipMouseEvents) {
                    app.input.emitMouseMove(
                        toPixels(e.motionX),
                        toPixels(e.motionY),
                        toPixels(e.motionXrel),
                        toPixels(e.motionYrel),
                        e.timestamp.toInt() / 1000.0,
                        Std.int(e.windowID)
                    );
                }

            case SDL.SDL_EVENT_MOUSE_BUTTON_DOWN:
                if (!skipMouseEvents) {
                    app.input.emitMouseDown(
                        toPixels(e.mouseX),
                        toPixels(e.mouseY),
                        e.mouseButton - 1,
                        e.timestamp.toInt() / 1000.0,
                        Std.int(e.windowID)
                    );
                }
            case SDL.SDL_EVENT_MOUSE_BUTTON_UP:
                if (!skipMouseEvents) {
                    app.input.emitMouseUp(
                        toPixels(e.mouseX),
                        toPixels(e.mouseY),
                        e.mouseButton - 1,
                        e.timestamp.toInt() / 1000.0,
                        Std.int(e.windowID)
                    );
                }

            case SDL.SDL_EVENT_MOUSE_WHEEL:
                if (!skipMouseEvents) {
                    final wheelFactor = -5.0; // Try to have consistent behavior between web and native platforms
                    app.input.emitMouseWheel(
                        #if !clay_no_wheel_round
                        Math.round(e.wheelX * wheelFactor),
                        Math.round(e.wheelY * wheelFactor),
                        #else
                        e.wheelX * wheelFactor,
                        e.wheelY * wheelFactor,
                        #end
                        e.timestamp.toInt() / 1000.0,
                        Std.int(e.windowID)
                    );
                }

        /// Touch

            case SDL.SDL_EVENT_FINGER_DOWN:
                app.input.emitTouchDown(
                    e.tfingerX,
                    e.tfingerY,
                    e.tfingerDx,
                    e.tfingerDy,
                    toFingerId(e.tfingerId.toInt()),
                    e.timestamp.toInt() / 1000.0
                );

            case SDL.SDL_EVENT_FINGER_UP:
                app.input.emitTouchUp(
                    e.tfingerX,
                    e.tfingerY,
                    e.tfingerDx,
                    e.tfingerDy,
                    toFingerId(e.tfingerId.toInt()),
                    e.timestamp.toInt() / 1000.0
                );
                removeFingerId(e.tfingerId.toInt());

            case SDL.SDL_EVENT_FINGER_MOTION:
                app.input.emitTouchMove(
                    e.tfingerX,
                    e.tfingerY,
                    e.tfingerDx,
                    e.tfingerDy,
                    toFingerId(e.tfingerId.toInt()),
                    e.timestamp.toInt() / 1000.0
                );

        #if clay_sdl_joystick_to_gamepad

        /// Joystick events

            case SDL.SDL_EVENT_JOYSTICK_AXIS_MOTION:

                if (!SDL.isGamepad(e.jaxisWhich)) {
                    // (range: -32768 to 32767)
                    var val:Float = (e.jaxisValue+32768)/(32767+32768);
                    var normalizedVal = (-0.5 + val) * 2.0;

                    app.input.emitGamepadAxis(
                        e.jaxisWhich,
                        e.jaxisAxis,
                        normalizedVal,
                        e.timestamp.toInt() / 1000.0
                    );
                }

            case SDL.SDL_EVENT_JOYSTICK_BUTTON_DOWN:

                if (!SDL.isGamepad(e.jbuttonWhich)) {
                    app.input.emitGamepadDown(
                        e.jbuttonWhich,
                        e.jbuttonButton,
                        1,
                        e.timestamp.toInt() / 1000.0
                    );
                }

            case SDL.SDL_EVENT_JOYSTICK_BUTTON_UP:

                if (!SDL.isGamepad(e.jbuttonWhich)) {
                    app.input.emitGamepadUp(
                        e.jbuttonWhich,
                        e.jbuttonButton,
                        0,
                        e.timestamp.toInt() / 1000.0
                    );
                }

            case SDL.SDL_EVENT_JOYSTICK_ADDED:

                if (!SDL.isGamepad(e.jdeviceWhich)) {
                    var joystick = SDL.openJoystick(e.jdeviceWhich);
                    joysticks.set(e.jdeviceWhich, joystick);

                    app.input.emitGamepadDevice(
                        e.jdeviceWhich,
                        SDL.getJoystickNameForID(e.jdeviceWhich),
                        GamepadDeviceEventType.DEVICE_ADDED,
                        e.timestamp.toInt() / 1000.0
                    );
                }

            case SDL.SDL_EVENT_JOYSTICK_REMOVED:

                if (!SDL.isGamepad(e.jdeviceWhich)) {
                    var joystick = joysticks.get(e.jdeviceWhich);
                    SDL.closeJoystick(joystick);
                    joysticks.remove(e.jdeviceWhich);

                    app.input.emitGamepadDevice(
                        e.jdeviceWhich,
                        SDL.getJoystickNameForID(e.jdeviceWhich),
                        GamepadDeviceEventType.DEVICE_REMOVED,
                        e.timestamp.toInt() / 1000.0
                    );
                }

        #end

        /// Gamepad

            case SDL.SDL_EVENT_GAMEPAD_AXIS_MOTION:
                // (range: -32768 to 32767)
                var val:Float = (e.gaxisValue+32768)/(32767+32768);
                var normalizedVal = (-0.5 + val) * 2.0;
                app.input.emitGamepadAxis(
                    e.gaxisWhich,
                    e.gaxisAxis,
                    normalizedVal,
                    e.timestamp.toInt() / 1000.0
                );

            case SDL.SDL_EVENT_GAMEPAD_BUTTON_DOWN:
                app.input.emitGamepadDown(
                    e.gbuttonWhich,
                    e.gbuttonButton,
                    1,
                    e.timestamp.toInt() / 1000.0
                );

            case SDL.SDL_EVENT_GAMEPAD_BUTTON_UP:
                app.input.emitGamepadUp(
                    e.gbuttonWhich,
                    e.gbuttonButton,
                    0,
                    e.timestamp.toInt() / 1000.0
                );

            case SDL.SDL_EVENT_GAMEPAD_ADDED:

                var _gamepad = SDL.openGamepad(e.gdeviceWhich);
                var instanceId = SDL.getJoystickID(cast _gamepad);
                gamepads.set(e.gdeviceWhich, _gamepad);
                gamepadInstanceIds.set(instanceId, e.gdeviceWhich);

                #if !clay_no_gamepad_sensor
                SDL.setGamepadSensorEnabled(_gamepad, SDL.SDL_SENSOR_GYRO, true);
                #end

                app.input.emitGamepadDevice(
                    instanceId,
                    SDL.getGamepadNameForID(e.gdeviceWhich),
                    GamepadDeviceEventType.DEVICE_ADDED,
                    e.timestamp.toInt() / 1000.0
                );

            case SDL.SDL_EVENT_GAMEPAD_REMOVED:

                var _gamepad = gamepads.get(e.gdeviceWhich);
                SDL.closeGamepad(_gamepad);
                gamepads.remove(e.gdeviceWhich);

                var deviceIndex = gamepadInstanceIds.exists(e.gdeviceWhich) ? gamepadInstanceIds.get(e.gdeviceWhich) : e.gdeviceWhich;

                app.input.emitGamepadDevice(
                    e.gdeviceWhich,
                    SDL.getGamepadNameForID(deviceIndex),
                    GamepadDeviceEventType.DEVICE_REMOVED,
                    e.timestamp.toInt() / 1000.0
                );

            case SDL.SDL_EVENT_GAMEPAD_REMAPPED:

                var deviceIndex = gamepadInstanceIds.exists(e.gdeviceWhich) ? gamepadInstanceIds.get(e.gdeviceWhich) : e.gdeviceWhich;

                app.input.emitGamepadDevice(
                    e.gdeviceWhich,
                    SDL.getGamepadNameForID(deviceIndex),
                    GamepadDeviceEventType.DEVICE_REMAPPED,
                    e.timestamp.toInt() / 1000.0
                );

            case SDL.SDL_EVENT_GAMEPAD_SENSOR_UPDATE:
                if (e.gsensorSensor == SDL.SDL_SENSOR_GYRO) {
                    var data = e.gsensorData;
                    app.input.emitGamepadGyro(
                        e.gsensorWhich,
                        data[0], data[1], data[2],
                        e.timestamp.toInt() / 1000.0
                    );
                }

            case _:

        }

    }

    function toFingerId(value:Int64):Int {

        if (!fingerIdList.exists(value)) {
            fingerIdList.set(value, nextFingerId);
            nextFingerId++;
            if (nextFingerId > 999999999)
                nextFingerId = 1;
        }
        return fingerIdList.get(value);

    }

    function removeFingerId(value:Int64):Void {

        if (fingerIdList.exists(value)) {
            fingerIdList.remove(value);
        }

    }

    inline function toPixels(value:Float):Int {
        return Math.floor(value);
    }

    /** Helper to return a `ModState` (shift, ctrl etc) from a given `InputEvent` */
    function toKeyMod(modValue:Int):ModState {

        var input = app.input;

        input.modState.none    = (modValue == SDL.SDL_KMOD_NONE);
        input.modState.lshift  = (modValue == SDL.SDL_KMOD_LSHIFT);
        input.modState.rshift  = (modValue == SDL.SDL_KMOD_RSHIFT);
        input.modState.lctrl   = (modValue == SDL.SDL_KMOD_LCTRL);
        input.modState.rctrl   = (modValue == SDL.SDL_KMOD_RCTRL);
        input.modState.lalt    = (modValue == SDL.SDL_KMOD_LALT);
        input.modState.ralt    = (modValue == SDL.SDL_KMOD_RALT);
        input.modState.lmeta   = (modValue == SDL.SDL_KMOD_LGUI);
        input.modState.rmeta   = (modValue == SDL.SDL_KMOD_RGUI);
        input.modState.num     = (modValue == SDL.SDL_KMOD_NUM);
        input.modState.caps    = (modValue == SDL.SDL_KMOD_CAPS);
        input.modState.mode    = (modValue == SDL.SDL_KMOD_MODE);
        input.modState.ctrl    = (modValue == SDL.SDL_KMOD_CTRL  || modValue == SDL.SDL_KMOD_LCTRL  || modValue == SDL.SDL_KMOD_RCTRL);
        input.modState.shift   = (modValue == SDL.SDL_KMOD_SHIFT || modValue == SDL.SDL_KMOD_LSHIFT || modValue == SDL.SDL_KMOD_RSHIFT);
        input.modState.alt     = (modValue == SDL.SDL_KMOD_ALT   || modValue == SDL.SDL_KMOD_LALT   || modValue == SDL.SDL_KMOD_RALT);
        input.modState.meta    = (modValue == SDL.SDL_KMOD_GUI   || modValue == SDL.SDL_KMOD_LGUI   || modValue == SDL.SDL_KMOD_RGUI);

        return app.input.modState;

    }

/// Window

    function handleWindowEvent(e:SDLEvent) {

        var data1 = e.windowData1;
        var data2 = e.windowData2;

        var type:WindowEventType = UNKNOWN;
        switch e.type {

            case SDL.SDL_EVENT_WINDOW_SHOWN:
                type = SHOWN;

            case SDL.SDL_EVENT_WINDOW_HIDDEN:
                type = HIDDEN;

            case SDL.SDL_EVENT_WINDOW_EXPOSED:
                type = EXPOSED;

            case SDL.SDL_EVENT_WINDOW_MOVED:
                type = MOVED;

            case SDL.SDL_EVENT_WINDOW_MINIMIZED:
                type = MINIMIZED;

            case SDL.SDL_EVENT_WINDOW_MAXIMIZED:
                type = MAXIMIZED;
                checkFullscreenState(e);

            case SDL.SDL_EVENT_WINDOW_RESTORED:
                type = RESTORED;
                checkFullscreenState(e);

            case SDL.SDL_EVENT_WINDOW_MOUSE_ENTER:
                type = ENTER;

            case SDL.SDL_EVENT_WINDOW_MOUSE_LEAVE:
                type = LEAVE;

            case SDL.SDL_EVENT_WINDOW_FOCUS_GAINED:
                type = FOCUS_GAINED;
                windowFocused = true;

            case SDL.SDL_EVENT_WINDOW_FOCUS_LOST:
                type = FOCUS_LOST;
                windowFocused = false;

            case SDL.SDL_EVENT_WINDOW_CLOSE_REQUESTED:
                type = CLOSE;

            case SDL.SDL_EVENT_WINDOW_RESIZED:
                type = RESIZED;
                #if !clay_no_compute_density
                _didFetchDPI = false;
                #end
                windowDpr = windowDevicePixelRatio();
                windowW = toPixels(data1);
                windowH = toPixels(data2);
                data1 = windowW;
                data2 = windowH;

            case SDL.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED:
                #if !clay_no_compute_density
                _didFetchDPI = false;
                #end
                windowDpr = windowDevicePixelRatio();
                SDL.getWindowSizeInPixels(window, _sdlSize);
                var _windowW = _sdlSize.w;
                var _windowH = _sdlSize.h;
                windowW = toPixels(_windowW);
                windowH = toPixels(_windowH);

            case SDL.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
                type = SIZE_CHANGED;
                #if !clay_no_compute_density
                _didFetchDPI = false;
                #end
                windowDpr = windowDevicePixelRatio();
                windowW = toPixels(data1);
                windowH = toPixels(data2);
                data1 = windowW;
                data2 = windowH;

            case _:

        }

        if (type != UNKNOWN) {
            app.emitWindowEvent(type, e.timestamp.toInt() / 1000.0, Std.int(e.windowID), data1, data2);
        }

    }

    function checkFullscreenState(e:SDLEvent):Void {

        #if mac
        var fullscreenSpace = SDL.isWindowInFullscreenSpace(window);
        #else
        var fullscreenSpace = false;
        #end

        var isFullscreen = fullscreenSpace || isSdlFullscreen;
        if (isFullscreen != app.config.window.fullscreen) {
            app.config.window.fullscreen = isFullscreen;

            if (isFullscreen) {
                app.emitWindowEvent(ENTER_FULLSCREEN, e.timestamp.toInt() / 1000.0, Std.int(e.windowID), 0, 0);
            } else {
                app.emitWindowEvent(EXIT_FULLSCREEN, e.timestamp.toInt() / 1000.0, Std.int(e.windowID), 0, 0);
            }
        }

    }

/// Mobile

    #if (android || ios || tvos)

    function handleSdlEventWatch(type:UInt32):Void {

        var type:AppEventType = UNKNOWN;

        switch (type) {
            case SDL.SDL_EVENT_TERMINATING:
                type = TERMINATING;
            case SDL.SDL_EVENT_LOW_MEMORY:
                type = LOW_MEMORY;
            case SDL.SDL_EVENT_WILL_ENTER_BACKGROUND:
                type = WILL_ENTER_BACKGROUND;
            case SDL.SDL_EVENT_DID_ENTER_BACKGROUND:
                type = DID_ENTER_BACKGROUND;
                mobileInBackground.store(true);
            case SDL.SDL_EVENT_WILL_ENTER_FOREGROUND:
                type = WILL_ENTER_FOREGROUND;
                mobileInBackground.store(false);
            case SDL.SDL_EVENT_DID_ENTER_FOREGROUND:
                type = DID_ENTER_FOREGROUND;
            case _:
        }

        app.emitAppEvent(type);

    }

    #end

/// Helpers

    inline public static function timestamp():Float {

        return Timestamp.now() - timestampStart;

    }

    public static function defaultConfig():RuntimeConfig {

        return {
            uncaughtErrorHandler: null
        };

    }

}