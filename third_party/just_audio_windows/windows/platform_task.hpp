#pragma once

#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <functional>
#include <optional>

namespace just_audio_windows {

// Media Foundation callbacks run off the UI thread. Flutter EventSink must
// not be touched there. RegisterTopLevelWindowProcDelegate hooks the *top-level*
// HWND, so posts must go there — not the Flutter view child HWND.
constexpr UINT kTaskMessage = WM_APP + 0x4A01;

class PlatformTasks {
 public:
  static PlatformTasks& Instance() {
    static PlatformTasks instance;
    return instance;
  }

  void Bind(flutter::PluginRegistrarWindows* registrar) {
    if (registrar == nullptr) {
      return;
    }
    ui_thread_id_ = GetCurrentThreadId();
    auto* view = registrar->GetView();
    HWND view_hwnd = view != nullptr ? view->GetNativeWindow() : nullptr;
    hwnd_ = view_hwnd != nullptr ? GetAncestor(view_hwnd, GA_ROOT) : nullptr;
    if (hwnd_ == nullptr) {
      hwnd_ = view_hwnd;
    }
    if (delegate_id_ == 0) {
      delegate_id_ = registrar->RegisterTopLevelWindowProcDelegate(
          [](HWND, UINT message, WPARAM, LPARAM lparam) -> std::optional<LRESULT> {
            if (message != kTaskMessage) {
              return std::nullopt;
            }
            auto* fn = reinterpret_cast<std::function<void()>*>(lparam);
            if (fn != nullptr) {
              (*fn)();
              delete fn;
            }
            return 0;
          });
    }
  }

  void Post(std::function<void()> fn) {
    if (!fn) {
      return;
    }
    if (hwnd_ == nullptr || GetCurrentThreadId() == ui_thread_id_) {
      fn();
      return;
    }
    auto* heap = new std::function<void()>(std::move(fn));
    if (!PostMessageW(hwnd_, kTaskMessage, 0, reinterpret_cast<LPARAM>(heap))) {
      delete heap;
      fn();
    }
  }

 private:
  HWND hwnd_ = nullptr;
  DWORD ui_thread_id_ = 0;
  int delegate_id_ = 0;
};

}  // namespace just_audio_windows
