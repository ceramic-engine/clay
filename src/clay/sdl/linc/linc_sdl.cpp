#include <hxcpp.h>
#include "./linc_sdl.h"

#include <locale.h>

#if (defined(SDL_PLATFORM_IOS) || defined(SDL_PLATFORM_TVOS))
#include <stdio.h>
#include <SDL3/SDL_main.h>

extern "C" const char *hxRunLibrary();
extern "C" void hxcpp_set_top_of_stack();

extern "C" int main(int argc, char *argv[]) {

    hxcpp_set_top_of_stack();

    const char *err = NULL;
    err = hxRunLibrary();

    if (err) {
        printf(" Error %s\n", err );
        return -1;
    }

    return 0;
}
#endif

#if defined(LINC_SDL_WITH_SDL_MAIN)
#include <SDL3/SDL_main.h>

    extern "C" { void hxcpp_main(); }
    extern "C" __attribute__((visibility("default"))) int SDL_main(int argc, char** argv);
    extern "C" int main(int argc, char *argv[]) {

        #if !defined(LINC_SDL_NO_HXCPP_MAIN_CALL)
            SDL_Log("Calling hxcpp_main() from SDL_main!");
            hxcpp_main();
        #endif

        #if !defined(LINC_SDL_NO_EXIT_CALL)
            SDL_Log("Calling exit() from SDL_main!");
            exit(0);
        #endif

        return 0;
    }

#endif

namespace linc {
    namespace sdl {

        bool init() {
            return SDL_Init(0);
        }

        void bind() {
            // placeholder
        }

        void quit() {
            SDL_Quit();
        }

        bool setHint(const char* name, const char* value) {
            return SDL_SetHint(name, value);
        }

        void setLCNumericCLocale() {
            setlocale(LC_NUMERIC, "C");
        }

        bool initSubSystem(Uint32 flags) {
            return SDL_InitSubSystem(flags);
        }

        void quitSubSystem(Uint32 flags) {
            SDL_QuitSubSystem(flags);
        }

        bool setVideoDriver(::String driver) {
            return SDL_SetHint(SDL_HINT_VIDEO_DRIVER, driver.utf8_str());
        }

        ::String getError() {
            const char* err = SDL_GetError();
            ::String result = err ? ::String(err) : ::String("");
            return result;
        }

        SDL_Window* createWindow(::String title, int x, int y, int width, int height, Uint32 flags) {
            SDL_PropertiesID props = SDL_CreateProperties();

            SDL_SetStringProperty(props, SDL_PROP_WINDOW_CREATE_TITLE_STRING, title.utf8_str());
            SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_X_NUMBER, x);
            SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_Y_NUMBER, y);
            SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER, width);
            SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER, height);
            SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_FLAGS_NUMBER, flags);

            SDL_Window* window = SDL_CreateWindowWithProperties(props);
            SDL_DestroyProperties(props);

            return window;
        }

        SDL_WindowID getWindowID(SDL_Window* window) {
            return SDL_GetWindowID(window);
        }

        void setWindowTitle(SDL_Window* window, const char* title) {
            SDL_SetWindowTitle(window, title);
        }

        void setWindowBordered(SDL_Window* window, bool bordered) {
            SDL_SetWindowBordered(window, bordered);
        }

        bool setWindowFullscreenMode(SDL_Window* window, const SDL_DisplayMode* mode) {
            return SDL_SetWindowFullscreenMode(window, mode);
        }

        bool setWindowFullscreen(SDL_Window* window, bool fullscreen) {
            return SDL_SetWindowFullscreen(window, fullscreen);
        }

        bool getWindowPosition(SDL_Window* window, SDLPoint* position) {
            int x = 0;
            int y = 0;
            bool result = SDL_GetWindowPosition(window, &x, &y);
            position->x = x;
            position->y = y;
            return result;
        }

        const SDL_DisplayMode* getWindowFullscreenMode(SDL_Window* window) {
            return SDL_GetWindowFullscreenMode(window);
        }

        const SDL_DisplayMode* getDesktopDisplayMode(SDL_DisplayID displayID) {
            return SDL_GetDesktopDisplayMode(displayID);
        }

        SDL_DisplayID getPrimaryDisplay() {
            return SDL_GetPrimaryDisplay();
        }

        SDL_DisplayID getDisplayForWindow(SDL_Window* window) {
            return SDL_GetDisplayForWindow(window);
        }

        bool getWindowFlags(SDL_Window* window, SDL_WindowFlags* flags) {
            *flags = SDL_GetWindowFlags(window);
            return true;
        }

        bool GL_SetAttribute(int attr, int value) {
            return SDL_GL_SetAttribute((SDL_GLAttr)attr, value);
        }

        SDL_GLContext GL_CreateContext(SDL_Window* window) {
            return SDL_GL_CreateContext(window);
        }

        SDL_GLContext GL_GetCurrentContext() {
            return SDL_GL_GetCurrentContext();
        }

        int GL_GetAttribute(int attr) {
            int value = 0;
            SDL_GL_GetAttribute((SDL_GLAttr)attr, &value);
            return value;
        }

        bool GL_MakeCurrent(SDL_Window* window, SDL_GLContext context) {
            return SDL_GL_MakeCurrent(window, context);
        }

        bool GL_SwapWindow(SDL_Window* window) {
            return SDL_GL_SwapWindow(window);
        }

        bool GL_SetSwapInterval(int interval) {
            return SDL_GL_SetSwapInterval(interval);
        }

        void GL_DestroyContext(SDL_GLContext context) {
            SDL_GL_DestroyContext(context);
        }

        Uint64 getTicks() {
            return SDL_GetTicks();
        }

        void delay(Uint32 ms) {
            SDL_Delay(ms);
        }

        bool pollEvent(SDL_Event* event) {
            return SDL_PollEvent(event);
        }

        void pumpEvents() {
            SDL_PumpEvents();
        }

        int getNumJoysticks() {
            int count = 0;
            SDL_free(SDL_GetJoysticks(&count));
            return count;
        }

        bool isGamepad(SDL_JoystickID instance_id) {
            return SDL_IsGamepad(instance_id);
        }

        SDL_Joystick* openJoystick(SDL_JoystickID instance_id) {
            return SDL_OpenJoystick(instance_id);
        }

        void closeJoystick(SDL_Joystick* joystick) {
            SDL_CloseJoystick(joystick);
        }

        SDL_Gamepad* openGamepad(SDL_JoystickID instance_id) {
            return SDL_OpenGamepad(instance_id);
        }

        void closeGamepad(SDL_Gamepad* gamepad) {
            SDL_CloseGamepad(gamepad);
        }

        const char* getGamepadNameForID(SDL_JoystickID instance_id) {
            return SDL_GetGamepadNameForID(instance_id);
        }

        const char* getJoystickNameForID(SDL_JoystickID instance_id) {
            return SDL_GetJoystickNameForID(instance_id);
        }

        bool gamepadHasRumble(SDL_Gamepad* gamepad) {
            return (bool)SDL_GetNumberProperty(SDL_GetGamepadProperties(gamepad), SDL_PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN, false);
        }

        bool rumbleGamepad(SDL_Gamepad* gamepad, Uint16 low_frequency_rumble, Uint16 high_frequency_rumble, Uint32 duration_ms) {
            return SDL_RumbleGamepad(gamepad, low_frequency_rumble, high_frequency_rumble, duration_ms);
        }

        bool setGamepadSensorEnabled(SDL_Gamepad* gamepad, int type, bool enabled) {
            return SDL_SetGamepadSensorEnabled(gamepad, (SDL_SensorType)type, enabled);
        }

        SDL_JoystickID getJoystickID(SDL_Joystick* joystick) {
            return SDL_GetJoystickID(joystick);
        }
        float getDisplayContentScale(SDL_DisplayID displayID) {
            return SDL_GetDisplayContentScale(displayID);
        }

        void getDisplayUsableBounds(SDL_DisplayID displayID, SDL_Rect* rect) {
            SDL_GetDisplayUsableBounds(displayID, rect);
        }

        #if (defined(SDL_PLATFORM_IOS) || defined(SDL_PLATFORM_TVOS))
        bool _setiOSAnimationCallback_didBind = false;
        InternaliOSAnimationCallback _setiOSAnimationCallback_callback;

        void _setiOSAnimationCallback_handler(void* userdata) {
            int haxe_stack_ = 99;
            hx::SetTopOfStack(&haxe_stack_, true);
            _setiOSAnimationCallback_callback();
            hx::SetTopOfStack((int *)0, true);
        }

        bool setiOSAnimationCallback(SDL_Window* window, InternaliOSAnimationCallback callback) {
            if (!_setiOSAnimationCallback_didBind) {
                _setiOSAnimationCallback_didBind = true;
                _setiOSAnimationCallback_callback = callback;
                SDL_SetiOSAnimationCallback(window, 1, _setiOSAnimationCallback_handler, NULL);
            }
            else {
                _setiOSAnimationCallback_callback = callback;
            }
            return true;
        }
        #endif

        bool _setEventWatch_didBind = false;
        static InternalEventWatcherCallback _setEventWatch_eventWatcher;

        static bool _setEventWatch_handler(void* userdata, SDL_Event* event) {
            unsigned int type = event->type;
            if (type != SDL_EVENT_TERMINATING           &&
                type != SDL_EVENT_LOW_MEMORY            &&
                type != SDL_EVENT_WILL_ENTER_BACKGROUND &&
                type != SDL_EVENT_DID_ENTER_BACKGROUND  &&
                type != SDL_EVENT_WILL_ENTER_FOREGROUND &&
                type != SDL_EVENT_DID_ENTER_FOREGROUND
            ) {
                return true;
            }
            else {
                int haxe_stack_ = 99;
                hx::SetTopOfStack(&haxe_stack_, true);
                _setEventWatch_eventWatcher(event);
                hx::SetTopOfStack((int *)0, true);
            }
            return true;
        }

        bool setEventWatch(SDL_Window* window, InternalEventWatcherCallback eventWatcher) {
            if (!_setEventWatch_didBind) {
                _setEventWatch_didBind = true;
                _setEventWatch_eventWatcher = eventWatcher;
                SDL_AddEventWatch(_setEventWatch_handler, NULL);
            }
            else {
                _setEventWatch_eventWatcher = eventWatcher;
            }
            return true;
        }

        ::String getBasePath() {
            const char* path = SDL_GetBasePath();
            ::String result = path ? ::String(path) : ::String("");
            return result;
        }

        void startTextInput(SDL_Window* window) {
            SDL_StartTextInput(window);
        }

        void stopTextInput(SDL_Window* window) {
            SDL_StopTextInput(window);
        }

        void setTextInputArea(SDL_Window* window, const SDL_Rect* rect, int cursor) {
            SDL_SetTextInputArea(window, rect, cursor);
        }

        bool getWindowSize(SDL_Window* window, SDLSize* size) {
            int w = 0;
            int h = 0;
            bool result = SDL_GetWindowSize(window, &w, &h);
            size->w = w;
            size->h = h;
            return result;
        }

        bool getWindowSizeInPixels(SDL_Window* window, SDLSize* size) {
            int w = 0;
            int h = 0;
            bool result = SDL_GetWindowSizeInPixels(window, &w, &h);
            size->w = w;
            size->h = h;
            return result;
        }

        SDL_IOStream* ioFromFile(const char* file, const char* mode) {
            return SDL_IOFromFile(file, mode);
        }

        SDL_IOStream* ioFromMem(::Array<unsigned char> mem, size_t size) {
            return SDL_IOFromMem((void*)&mem[0], size);
        }

        size_t ioRead(SDL_IOStream* context, ::Array<unsigned char> dest, size_t size) {
            return SDL_ReadIO(context, (void*)&dest[0], size);
        }

        size_t ioWrite(SDL_IOStream* context, ::Array<unsigned char> src, size_t size) {
            return SDL_WriteIO(context, (const void*)&src[0], size);
        }

        Sint64 ioSeek(SDL_IOStream* context, Sint64 offset, int whence) {
            return SDL_SeekIO(context, offset, (SDL_IOWhence)whence);
        }

        Sint64 ioTell(SDL_IOStream* context) {
            return SDL_TellIO(context);
        }

        bool ioClose(SDL_IOStream* context) {
            return SDL_CloseIO(context);
        }

        const char* getPrefPath(const char* org, const char* app) {
            return SDL_GetPrefPath(org, app);
        }

        bool hasClipboardText() {
            return SDL_HasClipboardText();
        }

        ::String getClipboardText() {
            char* text = SDL_GetClipboardText();
            if (text) {
                ::String result = ::String(text);
                SDL_free(text);
                return result;
            }
            return ::String("");
        }

        bool setClipboardText(const char* text) {
            return SDL_SetClipboardText(text);
        }

        bool byteOrderIsBigEndian() {
            return SDL_BYTEORDER == SDL_BIG_ENDIAN;
        }

        SDL_Surface* createRGBSurfaceFrom(::Array<unsigned char> pixels, int width, int height, int depth, int pitch, Uint32 rmask, Uint32 gmask, Uint32 bmask, Uint32 amask) {
            // In SDL3, CreateRGBSurfaceFrom has been replaced with CreateSurfaceFrom
            SDL_PixelFormat format = SDL_GetPixelFormatForMasks(depth, rmask, gmask, bmask, amask);
            return SDL_CreateSurfaceFrom(width, height, format, (void*)&pixels[0], pitch);
        }

        void freeSurface(SDL_Surface* surface) {
            SDL_DestroySurface(surface);
        }
    }
}