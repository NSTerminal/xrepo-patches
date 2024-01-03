package("botan")
    set_homepage("https://botan.randombit.net")
    set_description("C++ cryptography library released under the permissive Simplified BSD license")
    set_license("BSD-2-Clause")

    add_urls("https://botan.randombit.net/releases/Botan-$(version).tar.xz")
    add_versions("3.2.0", "049c847835fcf6ef3a9e206b33de05dd38999c325e247482772a5598d9e5ece3")
    add_deps("python", "ninja")

    if is_plat("macosx") then
        add_frameworks("CoreFoundation", "Security")
    end

    add_links("botan-3")
    add_includedirs("include/botan-3")

    on_install("windows", "macosx", "linux", function (package)
        local bindir = package:installdir("bin")
        local libdir = package:installdir("lib")

        if package:is_plat("windows") then
            import("core.tool.toolchain")
            local msvc = toolchain.load("msvc", {plat = "windows", arch = os.arch()})
            local runenvs = msvc:runenvs()
            os.vrun("python configure.py --build-targets=static --cc=msvc --build-tool=ninja --prefix=" .. package:installdir(), { envs = runenvs })
            import("package.tools.ninja").install(package, {}, { envs = runenvs })
        else
            os.vrun("python configure.py --build-targets=static --cc=clang --build-tool=ninja --prefix=" .. package:installdir())
            import("package.tools.ninja").install(package)
        end
    end)

    on_test(function (package)
        assert(package:has_cxxtypes("Botan::TLS::Client", { includes = "botan/tls_client.h", configs = { languages = "c++20" } }))
    end)
