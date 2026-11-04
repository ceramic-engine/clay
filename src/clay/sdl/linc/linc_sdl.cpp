#include <hxcpp.h>
#include "./linc_sdl.h"

#include <locale.h>
#include <vector>
#include <string>

#if defined(SDL_PLATFORM_WINDOWS)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

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

        ::String getCurrentVideoDriver() {
            const char* driver = SDL_GetCurrentVideoDriver();
            ::String result = driver ? ::String(driver) : ::String("");
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

        bool minimizeWindow(SDL_Window* window) {
            return SDL_MinimizeWindow(window);
        }

        bool maximizeWindow(SDL_Window* window) {
            return SDL_MaximizeWindow(window);
        }

        bool restoreWindow(SDL_Window* window) {
            return SDL_RestoreWindow(window);
        }

        bool isWindowMaximized(SDL_Window* window) {
            return (SDL_GetWindowFlags(window) & SDL_WINDOW_MAXIMIZED) != 0;
        }

        bool showWindowSystemMenu(SDL_Window* window, int x, int y) {
            return SDL_ShowWindowSystemMenu(window, x, y);
        }

        // Window hit regions: flat (x, y, width, height, SDL_HitTestResult)
        // in window coordinates, the last matching region wins. SDL may call
        // the hit test from another thread (Windows), hence the mutex.
        static std::vector<float> hitRegions;
        static SDL_Mutex* hitRegionsMutex = NULL;

        static SDL_HitTestResult SDLCALL hitTestCallback(SDL_Window* window, const SDL_Point* area, void* data) {
            SDL_HitTestResult result = SDL_HITTEST_NORMAL;
            SDL_LockMutex(hitRegionsMutex);
            for (int i = (int)hitRegions.size() - 5; i >= 0; i -= 5) {
                float x = hitRegions[i];
                float y = hitRegions[i + 1];
                if (area->x >= x && area->x < x + hitRegions[i + 2] && area->y >= y && area->y < y + hitRegions[i + 3]) {
                    result = (SDL_HitTestResult)(int)hitRegions[i + 4];
                    break;
                }
            }
            SDL_UnlockMutex(hitRegionsMutex);
            return result;
        }

        void setWindowHitRegions(SDL_Window* window, ::Array<Float> regions) {
            if (hitRegionsMutex == NULL) {
                hitRegionsMutex = SDL_CreateMutex();
            }
            int count = regions != null() ? regions->length : 0;
            SDL_LockMutex(hitRegionsMutex);
            hitRegions.clear();
            for (int i = 0; i + 4 < count; i += 5) {
                for (int k = 0; k < 5; k++) {
                    hitRegions.push_back((float)regions[i + k]);
                }
            }
            bool empty = hitRegions.empty();
            SDL_UnlockMutex(hitRegionsMutex);
            SDL_SetWindowHitTest(window, empty ? NULL : hitTestCallback, NULL);
        }

        void raiseWindow(SDL_Window* window) {
            SDL_RaiseWindow(window);
        }

        int getSystemTheme() {
            return (int)SDL_GetSystemTheme();
        }

        // File dialogs. SDL may run the callback on another thread (Windows,
        // the Linux portal) or later (macOS sheets), so each dialog keeps its
        // result here, guarded by a mutex, until the main loop polls it by id.
        // The filters must stay valid until the callback runs.
        struct FileDialogState {
            int id;
            int status; // 0 pending, 1 accepted, 2 cancelled, 3 failed
            std::vector<std::string> paths;
            std::string error;
            std::vector<std::string> filterStrings;
            std::vector<SDL_DialogFileFilter> filters;
        };

        static std::vector<FileDialogState*> fileDialogs;
        static SDL_Mutex* fileDialogsMutex = NULL;
        static int nextFileDialogId = 1;

        static FileDialogState* findFileDialog(int id) {
            for (size_t i = 0; i < fileDialogs.size(); i++) {
                if (fileDialogs[i]->id == id) return fileDialogs[i];
            }
            return NULL;
        }

        static void SDLCALL fileDialogCallback(void* userdata, const char* const* filelist, int filter) {
            int id = (int)(intptr_t)userdata;
            SDL_LockMutex(fileDialogsMutex);
            FileDialogState* state = findFileDialog(id);
            if (state != NULL) {
                if (filelist == NULL) {
                    const char* err = SDL_GetError();
                    state->error = err ? err : "";
                    state->status = 3;
                }
                else if (*filelist == NULL) {
                    state->status = 2;
                }
                else {
                    for (const char* const* file = filelist; *file != NULL; file++) {
                        state->paths.push_back(*file);
                    }
                    state->status = 1;
                }
            }
            SDL_UnlockMutex(fileDialogsMutex);
        }

        int showFileDialog(SDL_Window* window, int type, ::String title, ::String accept, ::String location, ::Array<::String> filters, bool many) {
            if (fileDialogsMutex == NULL) {
                fileDialogsMutex = SDL_CreateMutex();
            }
            FileDialogState* state = new FileDialogState();
            state->status = 0;
            int count = filters != null() ? filters->length : 0;
            for (int i = 0; i + 1 < count; i += 2) {
                ::String name = filters[i];
                ::String pattern = filters[i + 1];
                state->filterStrings.push_back(name != null() ? name.utf8_str() : "");
                state->filterStrings.push_back(pattern != null() ? pattern.utf8_str() : "");
            }
            // Pointers into filterStrings, which no longer changes
            for (size_t i = 0; i + 1 < state->filterStrings.size(); i += 2) {
                SDL_DialogFileFilter filter;
                filter.name = state->filterStrings[i].c_str();
                filter.pattern = state->filterStrings[i + 1].c_str();
                state->filters.push_back(filter);
            }
            SDL_LockMutex(fileDialogsMutex);
            int id = nextFileDialogId++;
            state->id = id;
            fileDialogs.push_back(state);
            SDL_UnlockMutex(fileDialogsMutex);

            SDL_PropertiesID props = SDL_CreateProperties();
            if (!state->filters.empty()) {
                SDL_SetPointerProperty(props, SDL_PROP_FILE_DIALOG_FILTERS_POINTER, state->filters.data());
                SDL_SetNumberProperty(props, SDL_PROP_FILE_DIALOG_NFILTERS_NUMBER, (Sint64)state->filters.size());
            }
            if (window != NULL) {
                SDL_SetPointerProperty(props, SDL_PROP_FILE_DIALOG_WINDOW_POINTER, window);
            }
            if (location != null() && location.length > 0) {
                SDL_SetStringProperty(props, SDL_PROP_FILE_DIALOG_LOCATION_STRING, location.utf8_str());
            }
            if (title != null() && title.length > 0) {
                SDL_SetStringProperty(props, SDL_PROP_FILE_DIALOG_TITLE_STRING, title.utf8_str());
            }
            if (accept != null() && accept.length > 0) {
                SDL_SetStringProperty(props, SDL_PROP_FILE_DIALOG_ACCEPT_STRING, accept.utf8_str());
            }
            SDL_SetBooleanProperty(props, SDL_PROP_FILE_DIALOG_MANY_BOOLEAN, many);
            SDL_ShowFileDialogWithProperties((SDL_FileDialogType)type, fileDialogCallback, (void*)(intptr_t)id, props);
            SDL_DestroyProperties(props);
            return id;
        }

        int fileDialogStatus(int id) {
            if (fileDialogsMutex == NULL) return -1;
            SDL_LockMutex(fileDialogsMutex);
            FileDialogState* state = findFileDialog(id);
            int status = state != NULL ? state->status : -1;
            SDL_UnlockMutex(fileDialogsMutex);
            return status;
        }

        ::Array<::String> fileDialogPaths(int id) {
            ::Array<::String> result = ::Array_obj<::String>::__new(0, 0);
            if (fileDialogsMutex == NULL) return result;
            SDL_LockMutex(fileDialogsMutex);
            FileDialogState* state = findFileDialog(id);
            if (state != NULL) {
                for (size_t i = 0; i < state->paths.size(); i++) {
                    result->push(::String::create(state->paths[i].c_str()));
                }
            }
            SDL_UnlockMutex(fileDialogsMutex);
            return result;
        }

        ::String fileDialogError(int id) {
            ::String result = ::String("");
            if (fileDialogsMutex == NULL) return result;
            SDL_LockMutex(fileDialogsMutex);
            FileDialogState* state = findFileDialog(id);
            if (state != NULL) {
                result = ::String::create(state->error.c_str());
            }
            SDL_UnlockMutex(fileDialogsMutex);
            return result;
        }

        void releaseFileDialog(int id) {
            if (fileDialogsMutex == NULL) return;
            SDL_LockMutex(fileDialogsMutex);
            for (size_t i = 0; i < fileDialogs.size(); i++) {
                if (fileDialogs[i]->id == id) {
                    // A pending dialog keeps its state: its callback still writes to it
                    if (fileDialogs[i]->status != 0) {
                        delete fileDialogs[i];
                        fileDialogs.erase(fileDialogs.begin() + i);
                    }
                    break;
                }
            }
            SDL_UnlockMutex(fileDialogsMutex);
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

        bool showCursor() {
            return SDL_ShowCursor();
        }

        bool hideCursor() {
            return SDL_HideCursor();
        }

        int getKeyFromScancode(int scancode) {
            // Key produced by this physical key with the current keyboard layout, no modifier
            return (int)SDL_GetKeyFromScancode((SDL_Scancode)scancode, SDL_KMOD_NONE, false);
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

        float getWindowPixelDensity(SDL_Window* window) {
            return SDL_GetWindowPixelDensity(window);
        }

        float getWindowDisplayScale(SDL_Window* window) {
            return SDL_GetWindowDisplayScale(window);
        }

        #if defined(SDL_PLATFORM_WINDOWS)

        typedef UINT (WINAPI *GetDpiForWindowFunc)(HWND);
        typedef HRESULT (WINAPI *GetDpiForMonitorFunc)(HMONITOR, int, UINT*, UINT*);

        static SDL_Window* dpiWindow = NULL;
        static HWND dpiHwnd = NULL;
        static WNDPROC dpiPrevWndProc = NULL;
        static GetDpiForWindowFunc dpiGetDpiForWindow = NULL;
        static GetDpiForMonitorFunc dpiGetDpiForMonitor = NULL;
        static bool dpiBypass = false;
        static UINT dpiCurrent = 0;
        // Client size in logical units (pixels at 96 DPI), as of the last resize at a stable DPI
        static double dpiLogicalWidth = 0;
        static double dpiLogicalHeight = 0;

        // Resize the window so that its client area has exactly the given size in pixels
        static void dpiSetClientSize(HWND hwnd, int x, int y, int clientWidth, int clientHeight) {
            for (int attempt = 0; attempt < 2; attempt++) {
                RECT windowRect, clientRect;
                GetWindowRect(hwnd, &windowRect);
                GetClientRect(hwnd, &clientRect);
                const int frameWidth = (windowRect.right - windowRect.left) - clientRect.right;
                const int frameHeight = (windowRect.bottom - windowRect.top) - clientRect.bottom;
                if (attempt > 0 && clientRect.right == clientWidth && clientRect.bottom == clientHeight) {
                    return;
                }
                SetWindowPos(
                    hwnd, NULL,
                    x, y,
                    clientWidth + frameWidth, clientHeight + frameHeight,
                    SWP_NOZORDER | SWP_NOACTIVATE | (attempt > 0 ? SWP_NOMOVE : 0)
                );
            }
        }

        // Whether the window and its monitor both use the DPI we were last notified about
        static bool dpiIsStable(HWND hwnd) {
            if (dpiGetDpiForWindow(hwnd) != dpiCurrent) return false;
            UINT dpiX = 0, dpiY = 0;
            HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
            if (monitor == NULL || dpiGetDpiForMonitor(monitor, 0 /* MDT_EFFECTIVE_DPI */, &dpiX, &dpiY) != S_OK) return false;
            return dpiX == dpiCurrent;
        }

        static LRESULT CALLBACK dpiWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
            if (msg == WM_SIZE) {
                // Track the logical client size, but only when the DPI is stable
                // (Windows may resize the window before notifying a DPI change)
                const int width = LOWORD(lParam);
                const int height = HIWORD(lParam);
                if (wParam != SIZE_MINIMIZED && width > 0 && height > 0 && dpiIsStable(hwnd)) {
                    dpiLogicalWidth = width * 96.0 / dpiCurrent;
                    dpiLogicalHeight = height * 96.0 / dpiCurrent;
                }
            }
            else if (msg == WM_DPICHANGED) {
                const UINT newDpi = HIWORD(wParam);
                dpiCurrent = newDpi;

                if (!dpiBypass && newDpi != 0 && dpiLogicalWidth > 0 && dpiLogicalHeight > 0 &&
                    !IsZoomed(hwnd) && (SDL_GetWindowFlags(dpiWindow) & SDL_WINDOW_FULLSCREEN) == 0) {
                    // Keep the logical client size on the new DPI (SDL would keep the size in pixels),
                    // at the position suggested by Windows (which keeps the window on the new display)
                    const RECT* suggested = (const RECT*)lParam;
                    dpiSetClientSize(
                        hwnd,
                        suggested->left, suggested->top,
                        (int)(dpiLogicalWidth * newDpi / 96.0 + 0.5),
                        (int)(dpiLogicalHeight * newDpi / 96.0 + 0.5)
                    );
                    return 0;
                }
            }
            return CallWindowProc(dpiPrevWndProc, hwnd, msg, wParam, lParam);
        }

        bool installDpiChangeHandler(SDL_Window* window) {
            if (dpiHwnd != NULL) return false;
            HWND hwnd = (HWND)SDL_GetPointerProperty(SDL_GetWindowProperties(window), SDL_PROP_WINDOW_WIN32_HWND_POINTER, NULL);
            if (hwnd == NULL) return false;
            // Windows 10 1607+ functions, loaded dynamically
            HMODULE user32 = GetModuleHandleW(L"user32.dll");
            if (user32 == NULL) return false;
            dpiGetDpiForWindow = (GetDpiForWindowFunc)GetProcAddress(user32, "GetDpiForWindow");
            if (dpiGetDpiForWindow == NULL) return false;
            HMODULE shcore = LoadLibraryW(L"shcore.dll");
            if (shcore == NULL) return false;
            dpiGetDpiForMonitor = (GetDpiForMonitorFunc)GetProcAddress(shcore, "GetDpiForMonitor");
            if (dpiGetDpiForMonitor == NULL) return false;
            dpiPrevWndProc = (WNDPROC)GetWindowLongPtr(hwnd, GWLP_WNDPROC);
            if (dpiPrevWndProc == NULL) return false;
            dpiCurrent = dpiGetDpiForWindow(hwnd);
            if (dpiCurrent == 0) return false;
            RECT clientRect;
            GetClientRect(hwnd, &clientRect);
            dpiLogicalWidth = clientRect.right * 96.0 / dpiCurrent;
            dpiLogicalHeight = clientRect.bottom * 96.0 / dpiCurrent;
            dpiWindow = window;
            dpiHwnd = hwnd;
            SetWindowLongPtr(hwnd, GWLP_WNDPROC, (LONG_PTR)dpiWndProc);
            return true;
        }

        void uninstallDpiChangeHandler() {
            if (dpiHwnd == NULL) return;
            SetWindowLongPtr(dpiHwnd, GWLP_WNDPROC, (LONG_PTR)dpiPrevWndProc);
            dpiWindow = NULL;
            dpiHwnd = NULL;
            dpiPrevWndProc = NULL;
        }

        void setDpiChangeHandlerBypass(bool bypass) {
            dpiBypass = bypass;
        }

        #else

        bool installDpiChangeHandler(SDL_Window* window) {
            return false;
        }

        void uninstallDpiChangeHandler() {}

        void setDpiChangeHandlerBypass(bool bypass) {}

        #endif

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

        // Between two animation callbacks the main thread sits in the native
        // run loop, where it never reaches a GC safe point: a collection
        // pause requested meanwhile (e.g. a concurrent GC remark) would have
        // to wait until the thread re-enters haxe code — up to a whole
        // frame. Parking the thread in a GC free zone while it is handed
        // back to the run loop lets collections proceed during that idle
        // time. Trampolines that re-enter haxe code exit the zone first
        // (done automatically by hx::SetTopOfStack) and park again when the
        // outermost trampoline returns; the depth guard keeps a nested
        // trampoline (e.g. an event watch fired while pumping events inside
        // the frame callback) from parking in the middle of haxe code. All
        // of it is thread local so a trampoline running on another thread
        // can never park that thread by mistake.
        static thread_local int _trampolineDepth = 0;
        static thread_local bool _parkInGcFreeZoneAfterTrampoline = false;

        static void _handleTrampolineReturn() {
            if (_trampolineDepth == 0 && _parkInGcFreeZoneAfterTrampoline) {
                hx::EnterGCFreeZone();
            }
        }

        #if (defined(SDL_PLATFORM_IOS) || defined(SDL_PLATFORM_TVOS))
        bool _setiOSAnimationCallback_didBind = false;
        InternaliOSAnimationCallback _setiOSAnimationCallback_callback;

        void _setiOSAnimationCallback_handler(void* userdata) {
            int haxe_stack_ = 99;
            _trampolineDepth++;
            hx::SetTopOfStack(&haxe_stack_, true);
            _setiOSAnimationCallback_callback();
            hx::SetTopOfStack((int *)0, true);
            _trampolineDepth--;
            _parkInGcFreeZoneAfterTrampoline = true;
            _handleTrampolineReturn();
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
                _trampolineDepth++;
                hx::SetTopOfStack(&haxe_stack_, true);
                _setEventWatch_eventWatcher(::cpp::Pointer<SDL_Event>(event));
                hx::SetTopOfStack((int *)0, true);
                _trampolineDepth--;
                _handleTrampolineReturn();
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

        // SDL_GetPrefPath() allocates its result: copied into a Haxe string
        // and freed here, like getClipboardText(), otherwise every call
        // (one per storage access) leaks the path
        ::String getPrefPath(const char* org, const char* app) {
            char* path = SDL_GetPrefPath(org, app);
            if (path) {
                ::String result = ::String(path);
                SDL_free(path);
                return result;
            }
            return ::String("");
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

        bool openURL(const char* url) {
            return SDL_OpenURL(url);
        }

        ::String getPlatform() {
            return ::String(SDL_GetPlatform());
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