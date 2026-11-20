#include "PCH.h"
#include "Logger.h"

#include <Windows.h>
#include <ShlObj.h>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ole32.lib")

namespace logger = SKSE::log;
namespace util { using SKSE::stl::report_and_fail; }

namespace TMS_FollowerSexNative
{
namespace
{
	constexpr auto kPluginName = "TMS_FollowerSexNative";
	constexpr auto kLogFileName = "TMS_FollowerSexNative.log";
	std::filesystem::path GetDocumentsPath()
	{
		PWSTR rawPath = nullptr;

		const HRESULT result = SHGetKnownFolderPath(
			FOLDERID_Documents,
			KF_FLAG_DEFAULT,
			nullptr,
			&rawPath
		);

		if (FAILED(result) || rawPath == nullptr) {
			return {};
		}

		std::filesystem::path path(rawPath);
		CoTaskMemFree(rawPath);

		return path;
	}

	std::filesystem::path GetLogPath()
	{
		return GetDocumentsPath() /
			"My Games" /
			"Skyrim Special Edition" /
			"SKSE" /
			kLogFileName;
	}

}

	void InitializeLog()
	{
		auto path = GetLogPath();

		if (path.empty()) {
			util::report_and_fail("TMS_FollowerSexNative: failed to find Documents log path"sv);
		}

		try {
			std::filesystem::create_directories(path.parent_path());
		} catch (...) {
			util::report_and_fail("TMS_FollowerSexNative: failed to create log directory"sv);
		}

		auto sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(path.string(), true);
		auto log = std::make_shared<spdlog::logger>("global log"s, std::move(sink));

		log->set_level(spdlog::level::info);
		log->flush_on(spdlog::level::info);

		spdlog::set_default_logger(std::move(log));
		spdlog::set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] [%t] [%s:%#] %v"s);

		logger::info("{} logger initialized", kPluginName);
		logger::info("Log path: {}", path.string());
	}

}
