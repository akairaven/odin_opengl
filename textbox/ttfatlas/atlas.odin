package ttflas

import "core:log"
import "core:strings"
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
Runes will keep position, will have unused data padded... Size vs convenience... Optimize size?
Use destroyAtlas to delete/free
*/
makeAtlas :: proc(fontfile : ^[]u8, width: i32, height: i32, fontSize: f32, startRune : i32, numRune : i32, 
                  atlas : ^FontAtlas, allocator:= context.allocator) {
    packCtx : truetype.pack_context
    fontInfo : truetype.fontinfo
    if !truetype.InitFont(&fontInfo, &fontfile[0], 0) {
        log.errorf("Error init font")
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
    bmpOutput := make([]u8, width*height, allocator=allocator)
    
    packedChars :=  make([]truetype.packedchar, startRune+numRune, allocator=allocator)
    quads := make([]truetype.aligned_quad, startRune + numRune, allocator=allocator)
    
    truetype.PackBegin(&packCtx, raw_data(bmpOutput), width, height, 0, 1, nil)
    truetype.PackFontRange(&packCtx, &fontfile[0], 0, fontSize, startRune, numRune, &packedChars[startRune]) 
    truetype.PackEnd(&packCtx)
    for i in startRune..<(startRune+numRune) {
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

/*
Calculate the minimal rectangle size of a string of text
*/
calculateBox :: proc(font: ^FontAtlas, text: string) -> (width: f32, height: f32) {
    width = 0
    height = 0
	for a_rune in text {
		glyph_rect := font.packedChar[a_rune]
		glyph_quad := font.quads[a_rune]
		width += glyph_rect.xadvance
        height = font.fontSize
	}
	return width, height
}

/* This will allocate a dynamic array strings using temp allocator by default 
*/
wordwrap_text :: proc(font: ^FontAtlas, text: string, maxWidth: f32, 
                      allocator:=context.temp_allocator) -> [dynamic]string {

    outputLines := make([dynamic]string,0, allocator)

    str_builder := strings.builder_make_len_cap(0, len(text), allocator) 
    defer strings.builder_destroy(&str_builder)
    words := strings.split(text, " ", allocator)
    defer delete(words, allocator)
    
    space_width := f32(font.packedChar[' '].xadvance)
    x_pos := f32(0)
    lineString : string

    for word, idx in words {
        wordWidth, wordHeight := calculateBox(font, word)
        if wordWidth > maxWidth {
            log.errorf("Word %s is larger than max width... skipping", word)
            continue
        }
        
        // add each word
        
        // if larger than width, scroll
        if ((x_pos + wordWidth + space_width) > maxWidth) {
            lineString = strings.clone(strings.to_string(str_builder), allocator)
            // append(output_lines, lineString)
            append(&outputLines, lineString)
            strings.builder_reset(&str_builder)
            x_pos = 0
        }

        // if not at the leftmost add a space
        if x_pos != 0 {
            strings.write_rune(&str_builder, ' ')
            x_pos += space_width
        }
   
        strings.write_string(&str_builder, word)
        x_pos += wordWidth

        // if at the last word flush the buffer
        if idx == (len(words)-1) {
            lineString = strings.clone(strings.to_string(str_builder), allocator)
            // append(output_lines, lineString)
            append(&outputLines, lineString)
        }
    }
    return outputLines
}
