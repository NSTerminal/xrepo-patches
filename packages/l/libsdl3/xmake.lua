package("libsdl3")
    set_homepage("https://www.libsdl.org/")
    set_description("Simple DirectMedia Layer")

    set_license("zlib")

    add_urls("https://github.com/libsdl-org/SDL.git")
    add_versions("20230604", "6150b5b3cbde0e592c4ffe822f66aa5f9c90c3d9")

    add_deps("cmake")

    add_includedirs("include", "include")

    add_configs("use_sdlmain", {description = "Use SDL_main entry point", default = true, type = "boolean"})
    if is_plat("linux") then
        add_configs("with_x", {description = "Enables X support (requires it on the system)", default = true, type = "boolean"})
    end

    if is_plat("wasm") then
        add_cxflags("-sUSE_SDL=0")
    end

    on_load(function (package)
        if package:config("use_sdlmain") then
            package:add("components", "main")
        end
        package:add("components", "lib")
        if package:is_plat("linux") and package:config("with_x") then
            package:add("deps", "libxext", {private = true})
        end
    end)

    on_component("main", function (package, component)
        local libsuffix = package:is_debug() and "d" or ""
        component:add("links", "SDL2main" .. libsuffix)
        component:add("defines", "SDL_MAIN_HANDLED")
        component:add("deps", "lib")
    end)

    on_component("lib", function (package, component)
        local libsuffix = package:is_debug() and "d" or ""
        if package:config("shared") then
            component:add("links", "SDL3" .. libsuffix)
        else
            component:add("links", (package:is_plat("windows") and "SDL3-static" or "SDL3") .. libsuffix)
            if package:is_plat("windows", "mingw") then
                component:add("syslinks", "user32", "gdi32", "winmm", "imm32", "ole32", "oleaut32", "version", "uuid", "advapi32", "setupapi", "shell32")
            elseif package:is_plat("linux", "bsd") then
                component:add("syslinks", "pthread", "dl")
                if package:is_plat("bsd") then
                    component:add("syslinks", "usbhid")
                end
            elseif package:is_plat("android") then
                component:add("syslinks", "dl", "log", "android", "GLESv1_CM", "GLESv2", "OpenSLES")
            elseif package:is_plat("iphoneos", "macosx") then
                component:add("frameworks", "AudioToolbox", "AVFoundation", "CoreAudio", "CoreVideo", "Foundation", "Metal", "QuartzCore", "CoreFoundation")
		        component:add("syslinks", "iconv")
                if package:is_plat("macosx") then
                    component:add("frameworks", "Cocoa", "Carbon", "ForceFeedback", "IOKit")
                else
                    component:add("frameworks", "CoreBluetooth", "CoreGraphics", "CoreMotion", "OpenGLES", "UIKit")
		end
                if package:version():ge("2.0.14") then
                    package:add("frameworks", "CoreHaptics", "GameController")
                end
            end
        end
    end)

    on_fetch("linux", "macosx", "bsd", function (package, opt)
        if opt.system then
            -- use sdl3-config
            local sdl2conf = try {function() return os.iorunv("sdl3-config", {"--version", "--cflags", "--libs"}) end}
            if sdl2conf then
                sdl2conf = os.argv(sdl2conf)
                local sdl2ver = table.remove(sdl2conf, 1)
                local result = {version = sdl2ver}
                for _, flag in ipairs(sdl2conf) do
                    if flag:startswith("-L") and #flag > 2 then
                        -- get linkdirs
                        local linkdir = flag:sub(3)
                        if linkdir and os.isdir(linkdir) then
                            result.linkdirs = result.linkdirs or {}
                            table.insert(result.linkdirs, linkdir)
                        end
                    elseif flag:startswith("-I") and #flag > 2 then
                        -- get includedirs
                        local includedir = flag:sub(3)
                        if includedir and os.isdir(includedir) then
                            result.includedirs = result.includedirs or {}
                            table.insert(result.includedirs, includedir)
                        end
                    elseif flag:startswith("-l") and #flag > 2 then
                        -- get links
                        local link = flag:sub(3)
                        result.links = result.links or {}
                        table.insert(result.links, link)
                    elseif flag:startswith("-D") and #flag > 2 then
                        -- get defines
                        local define = flag:sub(3)
                        result.defines = result.defines or {}
                        table.insert(result.defines, define)
                    end
                end

                return result
            end
        end
    end)

    on_install(function (package)
        local configs = {}
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"))
        table.insert(configs, "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"))
        table.insert(configs, "-DSDL_TEST=OFF")
        local opt
        if package:is_plat("linux", "cross") then
            local includedirs = {}
            for _, depname in ipairs({"libxext", "libx11", "xorgproto"}) do
                local dep = package:dep(depname)
                if dep then
                    local depfetch = dep:fetch()
                    if depfetch then
                        for _, includedir in ipairs(depfetch.includedirs or depfetch.sysincludedirs) do
                            table.insert(includedirs, includedir)
                        end
                    end
                end
            end
            if #includedirs > 0 then
                includedirs = table.unique(includedirs)

                local cflags = {}
                opt = opt or {}
                opt.cflags = cflags
                for _, includedir in ipairs(includedirs) do
                    table.insert(cflags, "-I" .. includedir)
                end
                table.insert(configs, "-DCMAKE_INCLUDE_PATH=" .. table.concat(includedirs, ";"))
            end
        elseif package:is_plat("wasm") then
            -- emscripten enables USE_SDL by default which will conflict with the sdl headers
            opt = opt or {}
            opt.cflags = {"-sUSE_SDL=0"}
        end
        import("package.tools.cmake").install(package, configs, opt)
    end)

    on_test(function (package)
        assert(package:has_cfuncs("SDL_Init",
            {includes = "SDL3/SDL.h", configs = {defines = "SDL_MAIN_HANDLED"}}))
    end)
