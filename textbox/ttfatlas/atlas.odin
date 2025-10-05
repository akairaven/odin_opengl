package ttflas

import "core:fmt"
import "vendor:stb/truetype"

FontAtlas :: struct {
    fontSize:       f32,
    ascent:         f32,
    descent:        f32,
    lineGap:        f32,
    bitmapWidth:    i32,
    bitmapHeight:   i32,
    bitmap:         []u8,
    packedChar:     []truetype.packedchar,
    quads:          []truetype.aligned_quad,
}

/*
Creates an atlas, resources are allocated on context allocator by default
Use destroyAtlas to delete/free
*/
makeAtlas :: proc(fontfile : ^[]u8, width: i32, height: i32, fontSize: f32, startRune : i32, numRune : i32, 
                  atlas : ^FontAtlas, allocator:= context.allocator) {
    packCtx : truetype.pack_context
    fontInfo : truetype.fontinfo
    if !truetype.InitFont(&fontInfo, &fontfile[0], 0) {
        fmt.eprintf("Error init font\n")
        return
    }
    atlas.fontSize = fontSize 
    scale := truetype.ScaleForPixelHeight(&fontInfo, fontSize)
    ascent, descent, lineGap : i32
    truetype.GetFontVMetrics(&fontInfo, &ascent, &descent, &lineGap)
    atlas.ascent = f32(ascent) * scale
    atlas.descent = f32(descent) * scale
    atlas.lineGap = f32(lineGap) * scale

    atlas.bitmapWidth = width
    atlas.bitmapHeight = height 
    packedChars :=  make([]truetype.packedchar, numRune, allocator=allocator)
    bmpOutput := make([]u8, width*height, allocator=allocator)
    quads := make([]truetype.aligned_quad, numRune, allocator=allocator)
    truetype.PackBegin(&packCtx, raw_data(bmpOutput), width, height, 0, 1, nil)
    truetype.PackFontRange(&packCtx, &fontfile[0], 0, fontSize, startRune, numRune, &packedChars[0]) 
    truetype.PackEnd(&packCtx)
    for i in 0..<numRune {
        xp, yp : f32
        truetype.GetPackedQuad(&packedChars[0], width, height, i, &xp, &yp, &quads[i], false)
    }
    atlas.packedChar = packedChars
    atlas.bitmap = bmpOutput
    atlas.quads = quads
}


/*
Free the resources in the atlas
*/
destroyAtlas :: proc(atlas : ^FontAtlas) {
    delete(atlas.quads)
    delete(atlas.packedChar)
    delete(atlas.bitmap)
}

