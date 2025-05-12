#pragma once

#ifndef HXCPP_H
#include <hxcpp.h>
#endif

#include <SDL3/SDL.h>

namespace linc {
    namespace sdl {

        struct SDLSize {
            int w;
            int h;
        };

        struct SDLPoint {
            int x;
            int y;
        };

        struct SDLRenderConfig {
            int depth;
            int stencil;
            int antialiasing;
            int redBits;
            int greenBits;
            int blueBits;
            int alphaBits;
            float defaultClearR;
            float defaultClearG;
            float defaultClearB;
            float defaultClearA;
            int openglMajor;
            int openglMinor;
            int openglProfile; // GLES = 2
        };

        struct SDLNativePointers {
            SDL_Window* window;
            SDL_GLContext gl;
            SDL_Event* currentEvent;
            bool skipMouseEvents;
            bool skipKeyboardEvents;
            float minFrameTime;
        };

        // Initialization
        bool init();
        void bind();
        void quit();
        bool setHint(const char* name, const char* value);

        // Locale workaround
        extern void setLCNumericCLocale();

        // Video
        bool initSubSystem(Uint32 flags);
        void quitSubSystem(Uint32 flags);
        bool setVideoDriver(::String driver);
        ::String getError();

        // Window management
        SDL_Window* createWindow(::String title, int x, int y, int width, int height, Uint32 flags);
        SDL_WindowID getWindowID(SDL_Window* window);
        void setWindowTitle(SDL_Window* window, const char* title);
        void setWindowBordered(SDL_Window* window, bool bordered);
        bool setWindowFullscreenMode(SDL_Window* window, const SDL_DisplayMode* mode);
        bool setWindowFullscreen(SDL_Window* window, bool fullscreen);
        bool getWindowSize(SDL_Window* window, SDLSize* size);
        bool getWindowSizeInPixels(SDL_Window* window, SDLSize* size);
        bool getWindowPosition(SDL_Window* window, SDLPoint* position);
        const SDL_DisplayMode* getWindowFullscreenMode(SDL_Window* window);
        const SDL_DisplayMode* getDesktopDisplayMode(SDL_DisplayID displayID);
        SDL_DisplayID getPrimaryDisplay();
        SDL_DisplayID getDisplayForWindow(SDL_Window* window);
        bool getWindowFlags(SDL_Window* window, SDL_WindowFlags* flags);

        // OpenGL
        bool GL_SetAttribute(int attr, int value);
        SDL_GLContext GL_CreateContext(SDL_Window* window);
        SDL_GLContext GL_GetCurrentContext();
        int GL_GetAttribute(int attr);
        bool GL_MakeCurrent(SDL_Window* window, SDL_GLContext context);
        bool GL_SwapWindow(SDL_Window* window);
        bool GL_SetSwapInterval(int interval);
        void GL_DestroyContext(SDL_GLContext context);

        // Timer
        Uint64 getTicks();
        void delay(Uint32 ms);

        // Events
        bool pollEvent(SDL_Event* event);
        void pumpEvents();

        // Joystick/Gamepad
        int getNumJoysticks();
        bool isGamepad(SDL_JoystickID instance_id);
        SDL_Joystick* openJoystick(SDL_JoystickID instance_id);
        void closeJoystick(SDL_Joystick* joystick);
        SDL_Gamepad* openGamepad(SDL_JoystickID instance_id);
        void closeGamepad(SDL_Gamepad* gamepad);
        const char* getGamepadNameForID(SDL_JoystickID instance_id);
        const char* getJoystickNameForID(SDL_JoystickID instance_id);
        bool gamepadHasRumble(SDL_Gamepad* gamepad);
        bool rumbleGamepad(SDL_Gamepad* gamepad, Uint16 low_frequency_rumble, Uint16 high_frequency_rumble, Uint32 duration_ms);
        bool setGamepadSensorEnabled(SDL_Gamepad* gamepad, int type, bool enabled);
        SDL_JoystickID getJoystickID(SDL_Joystick* joystick);

        // Display
        float getDisplayContentScale(SDL_DisplayID displayID);
        void getDisplayUsableBounds(SDL_DisplayID displayID, SDL_Rect* rect);

        // Event handlers
        #if (defined(SDL_PLATFORM_IOS) || defined(SDL_PLATFORM_TVOS))
        typedef ::cpp::Function < void() > InternaliOSAnimationCallback;
        bool setiOSAnimationCallback(SDL_Window* window, InternaliOSAnimationCallback callback);
        #endif

        typedef ::cpp::Function < int(SDL_Event*) > InternalEventWatcherCallback;
        bool setEventWatch(SDL_Window* window, InternalEventWatcherCallback eventWatcher);

        // Base path
        ::String getBasePath();

        // Text input
        void startTextInput(SDL_Window* window);
        void stopTextInput(SDL_Window* window);
        void setTextInputArea(SDL_Window* window, const SDL_Rect* rect, int cursor);

        // IO operations
        SDL_IOStream* ioFromFile(const char* file, const char* mode);
        SDL_IOStream* ioFromMem(::Array<unsigned char> mem, size_t size);
        size_t ioRead(SDL_IOStream* context, ::Array<unsigned char> dest, size_t size);
        size_t ioWrite(SDL_IOStream* context, ::Array<unsigned char> src, size_t size);
        Sint64 ioSeek(SDL_IOStream* context, Sint64 offset, int whence);
        Sint64 ioTell(SDL_IOStream* context);
        bool ioClose(SDL_IOStream* context);

        // Path operations
        const char* getPrefPath(const char* org, const char* app);

        // Clipboard
        bool hasClipboardText();
        ::String getClipboardText();
        bool setClipboardText(const char* text);

        bool byteOrderIsBigEndian();
        SDL_Surface* createRGBSurfaceFrom(::Array<unsigned char> pixels, int width, int height, int depth, int pitch, Uint32 rmask, Uint32 gmask, Uint32 bmask, Uint32 amask);
        void freeSurface(SDL_Surface* surface);
    }
}