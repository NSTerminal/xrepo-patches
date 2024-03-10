package("libsdl3_image")
    set_homepage("http://www.libsdl.org/projects/SDL_image/")
    set_description("Simple DirectMedia Layer image loading library")
    set_license("zlib")

    add_urls("https://github.com/libsdl-org/SDL_image.git")
    add_versions("20240224", "08fd30bd8eb01fecee59c42e1a74672c6575e38c")

    if is_plat("macosx", "iphoneos") then
        add_frameworks("CoreFoundation", "CoreGraphics", "ImageIO", "CoreServices")
    elseif is_plat("wasm") then
        add_configs("shared", {description = "Build shared library.", default = false, type = "boolean", readonly = true})
    end

    add_deps("cmake")

    add_includedirs("include", "include/SDL3_image")

    on_load(function (package)
        if package:config("shared") then
            package:add("deps", "libsdl3", { configs = { shared = true }})
        else
            package:add("deps", "libsdl3")
        end
    end)

    on_install(function (package)
        local configs = {"-DSDL3IMAGE_SAMPLES=OFF", "-DSDL3IMAGE_TESTS=OFF"}
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
                    if libfile:match("SDL3%..+$") or libfile:match("SDL2-static%..+$") then
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
            #include <SDL3_image/SDL_image.h>
            int main(int argc, char** argv) {
                IMG_Init(IMG_INIT_PNG);
                IMG_Quit();
                return 0;
            }
        ]]}, {configs = {defines = "SDL_MAIN_HANDLED"}}));
    end)
