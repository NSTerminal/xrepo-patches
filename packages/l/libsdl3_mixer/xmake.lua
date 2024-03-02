package("libsdl3_mixer")
    set_license("zlib")

    add_urls("https://github.com/libsdl-org/SDL_mixer")
    add_versions("20240224", "ef5373696f3a3bfd90e98be0a145196b7118a665")

    add_deps("cmake")

    add_includedirs("include", "include/SDL3")

    if is_plat("wasm") then
        add_configs("shared", {description = "Build shared library.", default = false, type = "boolean", readonly = true})
    end

    on_load(function (package)
        if package:config("shared") then
            package:add("deps", "libsdl3", { configs = { shared = true }})
        else
            package:add("deps", "libsdl3")
        end
    end)

    on_install(function (package)
        local configs = {
                            "-DSDL3MIXER_CMD=OFF",
                            "-DSDL3MIXER_FLAC=OFF",
                            "-DSDL3MIXER_GME=OFF",
                            "-DSDL3MIXER_MIDI=OFF",
                            "-DSDL3MIXER_MOD=OFF",
                            "-DSDL3MIXER_MP3=ON", -- was on by not being here
                            "-DSDL3MIXER_OPUS=OFF",
                            "-DSDL3MIXER_SAMPLES=OFF",
                            "-DSDL3MIXER_WAVE=ON", -- was on by not being here
                            "-DSDL3MIXER_WAVPACK=OFF",
                        }
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"))
        table.insert(configs, "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"))
        local libsdl = package:dep("libsdl")
        if libsdl and not libsdl:is_system() then
            table.insert(configs, "-DSDL3_DIR=" .. libsdl:installdir())
            local fetchinfo = libsdl:fetch()
            if fetchinfo then
                for _, dir in ipairs(fetchinfo.includedirs or fetchinfo.sysincludedirs) do
                    if os.isfile(path.join(dir, "SDL_version.h")) then
                        table.insert(configs, "-DSDL3_INCLUDE_DIR=" .. dir)
                        break
                    end
                end
                for _, libfile in ipairs(fetchinfo.libfiles) do
                    if libfile:match("SDL3%..+$") or libfile:match("SDL3-static%..+$") then
                        table.insert(configs, "-DSDL3_LIBRARY=" .. table.concat(fetchinfo.libfiles, ";"))
                    end
                end
            end
        end
        import("package.tools.cmake").install(package, configs)
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            #include <SDL3/SDL.h>
            #include <SDL3_mixer/SDL_mixer.h>
            int main(int argc, char** argv) {
                Mix_Init(MIX_INIT_OGG);
                Mix_Quit();
                return 0;
            }
        ]]}, {configs = {defines = "SDL_MAIN_HANDLED"}}));
    end)
