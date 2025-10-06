package main

import "core:mem"
import "core:fmt"
import "core:strings"
import "core:log"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "shader"
import "ttfatlas"

Longtext :: `Lorem ipsum dolor sit amet, consectetur adipiscing elit. In ligula justo, accumsan eu risus vel, dapibus ultricies urna. Aenean suscipit ut enim et elementum.`

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Hello Textbox!"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

Text_align :: enum {
    Left,
    Center,
    Right,
}

AppContext :: struct {
    shaders : map[string]u32,
    rectBuffer : RectBuffer,
}

Image :: struct {
    width:  i32,
    height: i32,
    dim:    i32,
    data:   ^u8,
}

RectBuffer :: struct {
    initialized : bool,
    vao : u32,
    vbo : u32,
}

initWindow :: proc() -> glfw.WindowHandle {

    if !bool(glfw.Init()) {
        log.errorf("GLFW has failed to load.")
        return nil
    }
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)
    window_handle := glfw.CreateWindow(WIDTH, HEIGHT, TITLE, nil, nil)

    if window_handle == nil {
        log.errorf("GLFW has failed to load the window.")
        return nil
    }
    glfw.MakeContextCurrent(window_handle)
    gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)
    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.Viewport(0, 0, WIDTH, HEIGHT);
    
    glfw.SetInputMode(window_handle, glfw.CURSOR, glfw.CURSOR_DISABLED)

    // Center the window in the primary monitor
    primary_monitor := glfw.GetPrimaryMonitor()
    video_mode := glfw.GetVideoMode(primary_monitor)
    x_pos := (video_mode.width - WIDTH) / 2
    y_pos := (video_mode.height - HEIGHT) / 2
    glfw.SetWindowPos(window_handle, x_pos, y_pos)
    
    return window_handle
}

destroyContext :: proc(ctx: AppContext) {
    delete(ctx.shaders)
}

initContext :: proc() -> AppContext {
    ctx := AppContext{}
    
    ctx.rectBuffer =  initRectBuffer()

    ctx.shaders["main"] = shader.load_texture_shader()
    ctx.shaders["text"] = shader.load_text_shader()
    ctx.shaders["simple"] = shader.load_simple_shader()
    ctx.shaders["roundShape"] = shader.load_simple_rounded_shader()

    projection := glm.mat4Ortho3d(0, WIDTH, HEIGHT, 0, -1, 1)
    gl.UseProgram(ctx.shaders["main"])
    shader.setMat4(ctx.shaders["main"], "projection", &projection)

    gl.UseProgram(ctx.shaders["text"])
    shader.setMat4(ctx.shaders["text"], "projection", &projection)

    gl.UseProgram(ctx.shaders["simple"])
    shader.setMat4(ctx.shaders["simple"], "projection", &projection)
    
    gl.UseProgram(ctx.shaders["roundShape"])
    shader.setMat4(ctx.shaders["roundShape"], "projection", &projection)
    return ctx
}

loadAtlasTexture :: proc(bitmap : ^u8, width : i32, height : i32) -> u32 {
    texture: u32
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.TexImage2D( gl.TEXTURE_2D, 0, gl.RED, width, height, 0, gl.RED, gl.UNSIGNED_BYTE, bitmap)
    gl.GenerateMipmap(gl.TEXTURE_2D)
    return texture
}

initRectBuffer :: proc() -> RectBuffer {
    vertices : [4]glm.vec2 = {{0,0},
                              {0,1},
                              {1,0},
                              {1,1}}
    rectBuffer : RectBuffer
    gl.GenVertexArrays(1, &rectBuffer.vao)
    gl.GenBuffers(1, &rectBuffer.vbo)
    gl.BindVertexArray(rectBuffer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rectBuffer.vbo)

    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(vertices[0]), &vertices[0], gl.STATIC_DRAW)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * size_of(f32), uintptr(0))

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
    rectBuffer.initialized = true
    return rectBuffer
}

drawText :: proc(ctx : AppContext, textureID: u32, text: string, atlas : ttfatlas.FontAtlas, 
                position : glm.vec2, rotate : f32, color : glm.vec4) -> (width, height : f32)
{
    textShader := ctx.shaders["text"]
    assert(textShader != 0)
    width = 0
    height = atlas.fontSize
    nTri :i32= i32(len(text)) * 6 // 6 vertices per quad (2 triangles)
    vertices := make([]glm.vec4, len(text)*6)
    vPos := 0
    xPos :f32 = 0
    for r, idx in text { 
        packedChar := atlas.packedChar[r]
        quad := atlas.quads[r]
        x0 :f32 = xPos + quad.x0
        x1 :f32 = xPos + quad.x1 
        y0 :f32 = atlas.ascent + packedChar.yoff
        y1 :f32 = atlas.ascent + packedChar.yoff2 
        vertices[vPos]   = glm.vec4{x0, y0, quad.s0, quad.t0}
        vertices[vPos+1] = glm.vec4{x0, y1, quad.s0, quad.t1}
        vertices[vPos+2] = glm.vec4{x1, y0, quad.s1, quad.t0}
        vertices[vPos+3] = glm.vec4{x1, y1, quad.s1, quad.t1}
        vertices[vPos+4] = glm.vec4{x1, y0, quad.s1, quad.t0}
        vertices[vPos+5] = glm.vec4{x0, y1, quad.s0, quad.t1}
        vPos += 6
        xPos += packedChar.xadvance 
        width += xPos
    }
    width = xPos
    gl.UseProgram(textShader)
    model := glm.mat4(1)
    model *= glm.mat4Translate(glm.vec3{position.x, position.y, 0}) // position on screen
    model *= glm.mat4Translate(glm.vec3{.5*width, .5*height, 0}) // move to center of sprite
    model *= glm.mat4Rotate(glm.vec3{0,0,1}, glm.radians_f32(rotate)) //  do rotation
    model *= glm.mat4Translate(glm.vec3{-.5*width, -.5*height, 0}) // move back to top left corner of sprite
    shader.setMat4(textShader, "model", &model)

    colorV := color
    shader.setVec4(textShader, "textColor", &colorV)
    textVao, textVbo : u32
    gl.GenVertexArrays(1, &textVao)
    gl.GenBuffers(1, &textVbo)

    gl.BindVertexArray(textVao)
    gl.BindBuffer(gl.ARRAY_BUFFER, textVbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(vertices[0]), raw_data(vertices), gl.STATIC_DRAW)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * size_of(f32), uintptr(0))
    gl.EnableVertexAttribArray(0)

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, textureID);

    gl.DrawArrays(gl.TRIANGLES, 0, nTri)

    // cleanup
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.DeleteBuffers(1, &textVbo)
    gl.BindVertexArray(0);
    gl.DeleteVertexArrays(1, &textVao)
    delete(vertices)
    return width, height
}

drawBoxedText :: proc(ctx: AppContext, textureID: u32, text: string, atlas: ^ttfatlas.FontAtlas,
                      position: glm.vec2, color: glm.vec4, width: f32, align: Text_align, draw: bool) -> (resultWidth, resultHeight : f32) {

    lines := ttfatlas.wordwrap_text(atlas, text, width)
    defer delete(lines)

    xPos := position.x
    yPos := position.y
    for line in lines {
        xPos = position.x
        boxW, boxH := ttfatlas.calculateBox(atlas, line)
        #partial switch align {
        case .Right:
            xPos += width - boxW
        case .Center:
            xPos += (width - boxW)/2 
        }
        if draw {
            drawText(ctx, textureID, line, atlas^, {xPos, yPos}, 0, color)
        }
        yPos += atlas.fontSize
    }
    resultWidth = width
    resultHeight = f32(len(lines)) * atlas.fontSize
    return resultWidth, resultHeight
}


main :: proc() {
	context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)
    log.infof("Starting App...")

    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

    fontfile := #load("Cousine-Regular.ttf")
    atlas : ttfatlas.FontAtlas
    ttfatlas.makeAtlas(&fontfile, 512, 256, 32, 32, 95, &atlas, allocator=context.allocator) // load basic ascii 32~127
    defer ttfatlas.destroyAtlas(&atlas)

    window_handle := initWindow()
    if window_handle == nil {
        panic("Unable to init")
    }
    ctx := initContext()

    atlasTexture := loadAtlasTexture(&atlas.bitmap[0], atlas.bitmapWidth, atlas.bitmapHeight)
    
    currentTime := f32(glfw.GetTime())
    dt: f32 = 0
    lastTime: f32 = 0
    running := true

    text := fmt.tprintf("0 FPS")

    boxsize : f32 = 400
    boxalign : Text_align = .Left

    for running {
        
        currentTime = f32(glfw.GetTime())
        dt = currentTime - lastTime
        lastTime = currentTime

        glfw.PollEvents()
        // handle input
        if glfw.WindowShouldClose(window_handle) {
            running = false
        }

        if glfw.GetKey(window_handle, glfw.KEY_ESCAPE) != 0 {
            running = false
        }

        if glfw.GetKey(window_handle, glfw.KEY_RIGHT) != 0 {
            boxsize += 5
        }
        if glfw.GetKey(window_handle, glfw.KEY_LEFT) != 0 {
            boxsize -= 5
        }
        if glfw.GetKey(window_handle, glfw.KEY_L) != 0 {
            boxalign = .Left
        }
        if glfw.GetKey(window_handle, glfw.KEY_C) != 0 {
            boxalign = .Center
        }
        if glfw.GetKey(window_handle, glfw.KEY_R) != 0 {
            boxalign = .Right
        }

        // render display
        gl.ClearColor(0.1, 0.3, 0.5, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)
  
        // box with border
        drawRoundRect(ctx, {45,55,1510,710}, 20, {1,1,1,1} )      
        drawRoundRect(ctx, {50,60,1500,700}, 15, {.25,.25,.25,1} )      

        // FPS
        text = fmt.tprintf("%.f FPS", 1/dt)

        w, h := ttfatlas.calculateBox(&atlas, text)
        drawRect(ctx, {1470,855,w+10,h+10}, {.2,.2,.6,1})
        w, h = drawText(ctx, atlasTexture, text, atlas, {1475, 860}, 0, glm.vec4{1,1,0,1})

        boxX :f32 = 200
        boxY :f32 = 130
        wi, he := drawBoxedText(ctx, atlasTexture, Longtext, &atlas, {boxX, boxY}, glm.vec4{1,1,1,1}, boxsize, boxalign, false)
        drawRoundRect(ctx, {boxX-10, boxY-10, wi+20, he+20}, 10, {.1,.3,.9,.9}) // outline border
        drawRoundRect(ctx, {boxX-5, boxY-5, wi+10, he+10}, 8, {.1,.7,.8,.4}) // background
        drawBoxedText(ctx, atlasTexture, Longtext, &atlas, {boxX+2, boxY+2}, glm.vec4{.1,.1,.1,1}, boxsize, boxalign, true) // Shadow
        drawBoxedText(ctx, atlasTexture, Longtext, &atlas, {boxX, boxY}, glm.vec4{1,1,1,1}, boxsize, boxalign, true) // Text

        glfw.SwapBuffers(window_handle)
        free_all(context.temp_allocator)      
    }
    destroyContext(ctx)
    glfw.Terminate()
}

