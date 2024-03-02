package("libsdl3_ttf")
    set_homepage("https://github.com/libsdl-org/SDL_ttf/")
    set_description("Simple DirectMedia Layer text rendering library")
    set_license("zlib")

    add_urls("https://github.com/libsdl-org/SDL_ttf.git")


    add_versions("20240229", "b8ba042e49dc81768ee34ba92225b742fd19372a")

    add_deps("cmake", "freetype")

    add_includedirs("include", "include/SDL3")

    if is_plat("wasm") then
        add_configs("shared", {description = "Build shared library.", default = false, type = "boolean", readonly = true})
    end

    on_load(function (package)
        if package:config("shared") then
            package:add("deps", "libsdl", { configs = { shared = true }})
        else
            package:add("deps", "libsdl")
        end
    end)

    on_install(function (package)
        local configs = {"-DSDL3TTF_SAMPLES=OFF"}
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"))
        table.insert(configs, "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"))
        table.insert(configs, "-DSDL3TTF_VENDORED=OFF")
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
                        table.insert(configs, "-DSDL3_LIBRARY=" .. libfile)
                    end
                end
            end
        end
        local freetype = package:dep("freetype")
        if freetype then
            local fetchinfo = freetype:fetch()
            if fetchinfo then
                local includedirs = table.wrap(fetchinfo.includedirs or fetchinfo.sysincludedirs)
                if #includedirs > 0 then
                    table.insert(configs, "-DFREETYPE_INCLUDE_DIRS=" .. table.concat(includedirs, ";"))
                end
                local libfiles = table.wrap(fetchinfo.libfiles)
                if #libfiles > 0 then
                    table.insert(configs, "-DFREETYPE_LIBRARY=" .. libfiles[1])
                end
                if not freetype:config("shared") then
                    local libfiles = {}
                    for _, dep in ipairs(freetype:librarydeps()) do
                        local depinfo = dep:fetch()
                        if depinfo then
                            table.join2(libfiles, depinfo.libfiles)
                        end
                    end
                    if #libfiles > 0 then
                        local libraries = ""
                        for _, libfile in ipairs(libfiles) do
                            libraries = libraries .. " " .. (libfile:gsub("\\", "/"))
                        end
                        io.replace("CMakeLists.txt", "target_link_libraries(SDL3_ttf PRIVATE Freetype::Freetype)",
                            "target_link_libraries(SDL3_ttf PRIVATE Freetype::Freetype " .. libraries .. ")", {plain = true})
                    end
                end
            end
        end
        import("package.tools.cmake").install(package, configs)
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            #include <SDL3/SDL.h>
            #include <SDL3_ttf/SDL_ttf.h>
            int main(int argc, char** argv) {
                TTF_Init();
                TTF_Quit();
                return 0;
            }
        ]]}, {configs = {defines = "SDL_MAIN_HANDLED"}}));
    end)
