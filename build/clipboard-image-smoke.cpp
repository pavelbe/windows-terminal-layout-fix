// Native Windows smoke for the exact header used by TerminalApp.
// Does not change the clipboard; generated fixtures are deleted after each run.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include "ClipboardImage.h"
#include "ClipboardFiles.h"
#include <shlobj_core.h>
#include <array>
#include <iostream>

static void require(bool value, const char* message)
{
    if (!value) throw std::runtime_error(message);
}

static void checkFiles(const std::vector<std::wstring>& paths, const std::vector<std::wstring>& expected, bool rejected = false)
{
    std::wstring names;
    for (const auto& path : paths) { names.append(path); names.push_back(L'\0'); }
    names.push_back(L'\0');
    if (paths.empty()) names.push_back(L'\0');
    wil::unique_hglobal memory{ GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, sizeof(DROPFILES) + names.size() * sizeof(wchar_t)) };
    require(!!memory, "cannot allocate file fixture");
    {
        wil::unique_hglobal_locked lock{ memory.get() };
        auto* drop = static_cast<DROPFILES*>(lock.get());
        require(drop != nullptr, "cannot lock file fixture");
        drop->pFiles = sizeof(DROPFILES);
        drop->fWide = TRUE;
        memcpy(reinterpret_cast<BYTE*>(drop) + sizeof(DROPFILES), names.data(), names.size() * sizeof(wchar_t));
    }
    bool failed = false;
    try { require(clipboard::readFilePastes(static_cast<HDROP>(memory.get())) == expected, "lost/reordered file or wrong paste boundary"); }
    catch (const wil::ResultException&) { failed = true; }
    require(failed == rejected, "wrong file-list rejection");
}

static void checkPng(const std::wstring& path)
{
    const auto factory = wil::CoCreateInstance<IWICImagingFactory>(CLSID_WICImagingFactory);
    wil::com_ptr<IWICBitmapDecoder> decoder;
    THROW_IF_FAILED(factory->CreateDecoderFromFilename(path.c_str(), nullptr, GENERIC_READ, WICDecodeMetadataCacheOnLoad, decoder.put()));
    GUID format{};
    THROW_IF_FAILED(decoder->GetContainerFormat(&format));
    require(format == GUID_ContainerFormatPng, "not PNG");
    wil::com_ptr<IWICBitmapFrameDecode> frame;
    THROW_IF_FAILED(decoder->GetFrame(0, frame.put()));
    UINT width{}, height{};
    THROW_IF_FAILED(frame->GetSize(&width, &height));
    require(width == 2 && height == 2, "wrong dimensions");
    wil::com_ptr<IWICFormatConverter> converted;
    THROW_IF_FAILED(factory->CreateFormatConverter(converted.put()));
    THROW_IF_FAILED(converted->Initialize(frame.get(), GUID_WICPixelFormat32bppBGRA, WICBitmapDitherTypeNone, nullptr, 0, WICBitmapPaletteTypeCustom));
    std::array<DWORD, 4> pixels{};
    THROW_IF_FAILED(converted->CopyPixels(nullptr, 8, sizeof(pixels), reinterpret_cast<BYTE*>(pixels.data())));
    require(pixels == std::array<DWORD, 4>{ 0xffff0000, 0xff00ff00, 0xff0000ff, 0xffffffff }, "pixels changed, flipped, or transparent");
}

int wmain(int argc, wchar_t** argv)
try
{
    const auto apartment = wil::CoInitializeEx();
    checkFiles({}, {});
    checkFiles({ L"C:\\one.png" }, { L"\"C:\\one.png\"" });
    checkFiles({ L"C:\\one.png", L"C:\\Снимки экрана\\два.png", L"C:\\three.txt" },
               { L"\"C:\\one.png\"", L" \"C:\\Снимки экрана\\два.png\"", L" \"C:\\three.txt\"" });
    checkFiles({ L"C:\\bad\r\nname.png" }, {}, true);
    checkFiles(std::vector<std::wstring>(257, L"C:\\one.png"), {}, true);
    std::cout << "PASS all Explorer files; order; individual pastes; Unicode/spaces; empty/single; malformed/oversized list refusal\n";
    BITMAPINFO info{};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = 2;
    info.bmiHeader.biHeight = -2;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    void* data{};
    wil::unique_hbitmap bitmap{ CreateDIBSection(nullptr, &info, DIB_RGB_COLORS, &data, nullptr, 0) };
    THROW_LAST_ERROR_IF(!bitmap);
    const std::array<DWORD, 4> pixels{ 0x00ff0000, 0x0000ff00, 0x000000ff, 0x00ffffff };
    memcpy(data, pixels.data(), sizeof(pixels));
    auto copy = clipboard::copyBitmap(bitmap.get(), nullptr);
    bitmap.reset(); // Snapshot must outlive the clipboard-owned bitmap.
    const auto first = clipboard::saveTemporaryPng(copy.get());
    auto cleanupFirst = wil::scope_exit([&] { DeleteFileW(first.c_str()); });
    checkPng(first);
    const auto second = clipboard::saveTemporaryPng(copy.get());
    auto cleanupSecond = wil::scope_exit([&] { DeleteFileW(second.c_str()); });
    require(first != second, "repeated paste reused filename");
    checkPng(second);
    checkPng(first); // A second paste must not overwrite the first attachment.
    std::cout << "PASS snapshot lifetime; PNG roundtrip; colors/orientation/opaque alpha; unique retained files\n";

    std::wstring oldTmp(32768, L'\0');
    const auto oldLength = GetEnvironmentVariableW(L"TMP", oldTmp.data(), static_cast<DWORD>(oldTmp.size()));
    require(oldLength < oldTmp.size(), "TMP too long");
    oldTmp.resize(oldLength);
    auto restoreTmp = wil::scope_exit([&] { SetEnvironmentVariableW(L"TMP", oldLength ? oldTmp.c_str() : nullptr); });
    // Use an existing PNG file as a directory: no write can succeed beneath it.
    THROW_IF_WIN32_BOOL_FALSE(SetEnvironmentVariableW(L"TMP", first.c_str()));
    bool failed = false;
    try { clipboard::saveTemporaryPng(copy.get()); }
    catch (const wil::ResultException&) { failed = true; }
    require(failed, "unwritable destination returned a path");
    THROW_IF_WIN32_BOOL_FALSE(SetEnvironmentVariableW(L"TMP", oldLength ? oldTmp.c_str() : nullptr));
    checkPng(first);
    std::cout << "PASS write failure does not return a path or damage existing file\n";

    if (argc == 2 && std::wstring_view{ argv[1] } == L"--clipboard")
    {
        wil::com_ptr<IWICBitmap> screenshot;
        THROW_IF_WIN32_BOOL_FALSE(OpenClipboard(nullptr));
        {
            auto close = wil::scope_exit([] { CloseClipboard(); });
            if (auto handle = GetClipboardData(CF_BITMAP))
                screenshot = clipboard::copyBitmap(static_cast<HBITMAP>(handle), static_cast<HPALETTE>(GetClipboardData(CF_PALETTE)));
        }
        require(!!screenshot, "current clipboard has no bitmap");
        UINT width{}, height{};
        THROW_IF_FAILED(screenshot->GetSize(&width, &height));
        const auto path = clipboard::saveTemporaryPng(screenshot.get());
        std::wcout << L"CLIPBOARD_PNG=" << path << L"\nSIZE=" << width << L"x" << height << L"\n";
    }
    return 0;
}
catch (const std::exception& e)
{
    std::cerr << "FAIL: " << e.what() << '\n';
    return 1;
}
