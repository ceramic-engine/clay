// System settings of Windows that SDL does not expose, compiled on Windows only.
//
// UNTESTED: written without a Windows machine. The first run on Windows
// should check that `autoHideScrollbars` follows Settings, Accessibility,
// Visual effects, "Always show scrollbars" (Windows 11; on Windows 10:
// Ease of Access, Display, "Automatically hide scroll bars in Windows").
//
// Scrollbar style: like GPUI's Windows platform, the value of
// `Windows.UI.ViewManagement.UISettings.AutoHideScrollBars` (Windows 10
// 1903 and later), read through plain COM: RoActivateInstance, then
// QueryInterface for IUISettings5 and get_AutoHideScrollBars. The interface
// is declared below instead of including the large ABI header
// windows.ui.viewmanagement.h next to hxcpp's global types. When WinRT
// cannot give it (older Windows, activation failure), the registry value
// HKCU\Control Panel\Accessibility\DynamicScrollbars is read instead (a
// DWORD, non zero: scroll bars hide automatically). False when neither can
// be read. The runtime reads it once (no change notification, like GPUI).

#include <hxcpp.h>
#include "linc_sdl.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <inspectable.h>
#include <roapi.h>
#include <winstring.h>

namespace {

    // Windows.UI.ViewManagement.IUISettings5: get_AutoHideScrollBars is the
    // first method after the six of IInspectable (vtable slot 6). The
    // methods after it (the change event) are not used, so not declared.
    struct ClayUISettings5 : public IInspectable {
        virtual HRESULT STDMETHODCALLTYPE get_AutoHideScrollBars(boolean *value) = 0;
    };

    // {5349D588-0CB5-5F05-BD34-706B3231F0BD}
    const IID clayIidUISettings5 = { 0x5349d588, 0x0cb5, 0x5f05, { 0xbd, 0x34, 0x70, 0x6b, 0x32, 0x31, 0xf0, 0xbd } };

    // Sets `autoHide` and returns true when UISettings answered
    bool readUISettings(bool &autoHide) {

        // The main thread may already be in an apartment (SDL initializes
        // COM as single threaded for some subsystems): RPC_E_CHANGED_MODE
        // then, and WinRT is usable anyway. Only a successful call here is
        // balanced by RoUninitialize.
        HRESULT init = RoInitialize(RO_INIT_SINGLETHREADED);
        bool uninitialize = SUCCEEDED(init);
        if (FAILED(init) && init != RPC_E_CHANGED_MODE) {
            return false;
        }

        bool answered = false;
        static const wchar_t className[] = L"Windows.UI.ViewManagement.UISettings";
        HSTRING classId = NULL;
        if (SUCCEEDED(WindowsCreateString(className, (UINT32)(sizeof(className) / sizeof(className[0]) - 1), &classId))) {
            IInspectable *settings = NULL;
            if (SUCCEEDED(RoActivateInstance(classId, &settings)) && settings != NULL) {
                ClayUISettings5 *settings5 = NULL;
                if (SUCCEEDED(settings->QueryInterface(clayIidUISettings5, (void **)&settings5)) && settings5 != NULL) {
                    boolean value = 0;
                    if (SUCCEEDED(settings5->get_AutoHideScrollBars(&value))) {
                        autoHide = value != 0;
                        answered = true;
                    }
                    settings5->Release();
                }
                settings->Release();
            }
            WindowsDeleteString(classId);
        }

        if (uninitialize) {
            RoUninitialize();
        }
        return answered;

    }

    // Sets `autoHide` and returns true when the registry value exists
    bool readRegistry(bool &autoHide) {

        DWORD value = 0;
        DWORD size = sizeof(value);
        LSTATUS status = RegGetValueW(HKEY_CURRENT_USER, L"Control Panel\\Accessibility", L"DynamicScrollbars", RRF_RT_REG_DWORD, NULL, &value, &size);
        if (status != ERROR_SUCCESS) {
            return false;
        }
        autoHide = value != 0;
        return true;

    }

}

namespace linc {
    namespace sdl {

        bool autoHideScrollbars() {
            bool autoHide = false;
            if (readUISettings(autoHide)) {
                return autoHide;
            }
            if (readRegistry(autoHide)) {
                return autoHide;
            }
            return false;
        }

    }
}
