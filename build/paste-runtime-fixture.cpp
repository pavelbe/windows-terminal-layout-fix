// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
// Native clipboard barrier and raw ConPTY input witness; synthetic data only.
#include <Windows.h>
#include <fstream>
#include <string>
#include <thread>

static std::wstring directory;
static std::wstring payload;
static bool bitmapData;

static bool exists(const std::wstring& path)
{
    return GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES;
}

static void mark(const std::wstring& path)
{
    std::ofstream{ path }.put('1');
}

static LRESULT CALLBACK windowProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam)
{
    if (message == WM_RENDERFORMAT)
    {
        mark(directory + L"\\requested");
        const auto deadline = GetTickCount64() + 20000;
        while (!exists(directory + L"\\release") && GetTickCount64() < deadline)
        {
            Sleep(20);
        }
        if (bitmapData)
        {
            const DWORD pixels[]{ 0x00ff0000, 0x0000ff00, 0x000000ff, 0x00ffffff };
            const auto bitmap = CreateBitmap(2, 2, 1, 32, pixels);
            if (!SetClipboardData(CF_BITMAP, bitmap))
            {
                DeleteObject(bitmap);
            }
        }
        else
        {
            const auto bytes = (payload.size() + 1) * sizeof(wchar_t);
            const auto memory = GlobalAlloc(GMEM_MOVEABLE, bytes);
            if (!memory)
            {
                return 0;
            }
            const auto data = GlobalLock(memory);
            if (!data)
            {
                GlobalFree(memory);
                return 0;
            }
            memcpy(data, payload.c_str(), bytes);
            GlobalUnlock(memory);
            if (!SetClipboardData(CF_UNICODETEXT, memory))
            {
                GlobalFree(memory);
            }
        }
        mark(directory + L"\\rendered");
        return 0;
    }
    return DefWindowProcW(window, message, wparam, lparam);
}

int wmain(int argc, wchar_t** argv)
{
    if (argc != 5)
    {
        return 2;
    }
    directory = argv[2];
    if (std::wstring_view{ argv[1] } == L"receive")
    {
        const auto input = GetStdHandle(STD_INPUT_HANDLE);
        const auto output = GetStdHandle(STD_OUTPUT_HANDLE);
        if (!SetConsoleMode(input, ENABLE_VIRTUAL_TERMINAL_INPUT) ||
            !SetConsoleMode(output, ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING))
        {
            return 3;
        }
        const std::string sequence = std::wstring_view{ argv[3] } == L"bracketed" ? "\x1b[?2004h" : "\x1b[?2004l";
        DWORD written;
        WriteFile(output, sequence.data(), static_cast<DWORD>(sequence.size()), &written, nullptr);
        const std::wstring name = argv[4];
        const auto path = directory + L"\\" + name;
        std::ofstream{ path + L".bin", std::ios::binary | std::ios::trunc };
        std::thread reader{ [input, path] {
            char buffer[4096];
            DWORD read;
            std::ofstream file{ path + L".bin", std::ios::binary | std::ios::app };
            while (ReadFile(input, buffer, sizeof(buffer), &read, nullptr) && read)
            {
                file.write(buffer, read);
                file.flush();
            }
        } };
        reader.detach();
        mark(path + L".ready");
        while (!exists(directory + L"\\stop"))
        {
            Sleep(25);
        }
        // The process owns only this witness thread and its output file.
        ExitProcess(0);
    }
    if (std::wstring_view{ argv[1] } != L"provide")
    {
        return 2;
    }
    bitmapData = std::wstring_view{ argv[3] } == L"bitmap";
    payload = argv[4];
    WNDCLASSW wc{};
    wc.lpfnWndProc = windowProc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = L"LF-SYNTHETIC-CLIPBOARD";
    if (!RegisterClassW(&wc))
    {
        return 4;
    }
    const auto window = CreateWindowW(wc.lpszClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, wc.hInstance, nullptr);
    bool opened = false;
    for (int attempt = 0; attempt < 100 && !opened; ++attempt)
    {
        opened = OpenClipboard(window) != FALSE;
        if (!opened)
        {
            Sleep(20);
        }
    }
    if (!window || !opened)
    {
        return 5;
    }
    EmptyClipboard();
    SetClipboardData(bitmapData ? CF_BITMAP : CF_UNICODETEXT, nullptr);
    CloseClipboard();
    mark(directory + L"\\provider.ready");
    const auto deadline = GetTickCount64() + 60000;
    while (!exists(directory + L"\\provider.stop") && GetTickCount64() < deadline)
    {
        MSG message;
        while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE))
        {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
        Sleep(10);
    }
    DestroyWindow(window);
    return 0;
}
