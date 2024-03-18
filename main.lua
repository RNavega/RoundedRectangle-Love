-- ==========================================================
-- Example of a round-corner rectangle using a pixel shader.
-- By Rafael Navega (2024)
--
-- License: Public Domain
-- ==========================================================

io.stdout:setvbuf('no')

local rect = {
    x1 = 80.0,         y1 = 140.0,
    x2 = 80.0 + 400.0, y2 = 140.0 + 160.0,
    borderData = {
        -- Width (px)
        nil,
        -- Height (px)
        nil,
        -- Initial corner radius (px)
        50.0,
        -- Initial border thickness (px)
        12.0
    }
}
local mesh
local shader

local PIXEL_SOURCE = [[
uniform vec4 border_data;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    // The default Löve shader code, unused:

    //vec4 texcolor = Texel(tex, texture_coords);
    //return texcolor * color;

    // --------------------------------------------------------------

    // The rounded rectangle & border code:

    const vec4 WHITE_COLOR = vec4(1.0);

    vec2 local_pixel = texture_coords * border_data.xy;

    vec2 center_pixel = border_data.xy / 2.0;

    vec2 center_offset = abs(local_pixel - center_pixel);
    vec2 corner_offset = center_offset - (center_pixel - border_data.z);
    vec2 is_corner = step(0.0, corner_offset);

    float corner_offset_length = length(corner_offset);
    // This +0.5 constant seems to give the smoothest result.
    float corner_antialias = corner_offset_length + 0.5 - border_data.z;

    vec2 border_offset = center_offset - (center_pixel - border_data.w);
    vec2 is_edge_border = step(0.0, border_offset);
    float border_antialias = corner_offset_length + 0.5 - (border_data.z - border_data.w);
    float is_corner_border = (border_antialias * is_corner.x * is_corner.y);
    float border_factor = clamp(is_edge_border.x + is_edge_border.y + is_corner_border, 0.0, 1.0);
    vec4 final_color = mix(color, WHITE_COLOR, border_factor);

    final_color.a = 1.0 - (corner_antialias * is_corner.x * is_corner.y);
    return final_color;
}
]]

-- Cosmetic, used for dragging the corners.
local draggedCorner = nil
local highlightedCorner = nil
local dragOffset = {0.0, 0.0}
local cornerKeys = {{'x1', 'y1'}, {'x2', 'y1'}, {'x2', 'y2'}, {'x1', 'y2'}}


function love.load()
    mesh = love.graphics.newMesh(4, 'fan', 'static')
    -- Default format: x, y, u, v, r, g, b, a.
    -- Setting only x, y, u, v.
    -- Creating the mesh sized at 1 x 1 px, to be scaled to its proper width & height
    -- using the 'sx' and 'sy' parameters of love.graphics.draw().
    mesh:setVertices({
        {0.0, 0.0, 0.0, 0.0},
        {1.0, 0.0, 1.0, 0.0},
        {1.0, 1.0, 1.0, 1.0},
        {0.0, 1.0, 0.0, 1.0},
    })
    -- TODO: it's also possible to use a custom mesh format, and then setup the
    -- "borderData" information per vertex, so that you can have many rounded
    -- rectangles of different sizes and borders, all stored in the same mesh.
    mesh:setVertexMap(1, 2, 3, 4)
    shader = love.graphics.newShader(PIXEL_SOURCE)
    love.keyboard.setKeyRepeat(true)
end


function love.draw()
    love.graphics.setShader(shader)
    love.graphics.setColor(0.5, 0.5, 0.5)
    rect.borderData[1] = rect.x2 - rect.x1
    rect.borderData[2] = rect.y2 - rect.y1
    shader:send('border_data', rect.borderData)
    love.graphics.draw(mesh, rect.x1, rect.y1, 0.0, rect.borderData[1], rect.borderData[2])

    love.graphics.setShader()

    if highlightedCorner then
        local keys = cornerKeys[highlightedCorner]
        love.graphics.setColor(0.0, 1.0, 1.0, 0.333)
        local x = rect[keys[1]]
        local y = rect[keys[2]]
        local tolerance = rect.borderData[3] > 32 and rect.borderData[3] or 32
        if highlightedCorner == 2 or highlightedCorner == 3 then
            x = x - tolerance
        end
        if highlightedCorner == 3 or highlightedCorner == 4 then
            y = y - tolerance
        end
        love.graphics.rectangle('fill', x, y, tolerance, tolerance)
    end
    love.graphics.setColor(1.0, 1.0, 1.0)
    local info = string.format('Drag the rectangle corners to resize it (%d x %d px).\n\n'
                             ..'Press and hold Up / Down to resize the corner radius (%d px).\n\n'
                             ..'Press and hold Left / Right to resize the border thickness (%d px).\n\n'
                             ..'Press Esc to quit.',
                               rect.x2 - rect.x1,
                               rect.y2 - rect.y1,
                               rect.borderData[3],
                               rect.borderData[4])
    love.graphics.print(info, 10, 10)
end


function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'up' then
        rect.borderData[3] = (rect.borderData[3] > 0.0 and rect.borderData[3] - 1.0 or 0.0)
    elseif key == 'down' then
        local halfHeight = math.abs(rect.y2 - rect.y1) / 2.0
        rect.borderData[3] = (rect.borderData[3] < halfHeight and rect.borderData[3] + 1.0
                              or halfHeight)
    elseif key == 'left' then
        rect.borderData[4] = (rect.borderData[4] > 0.0 and rect.borderData[4] - 1.0 or 0.0)
    elseif key == 'right' then
        local halfHeight = math.abs(rect.y2 - rect.y1) / 2.0
        rect.borderData[4] = (rect.borderData[4] < halfHeight and rect.borderData[4] + 1.0
                              or halfHeight)
    end
end


function love.mousemoved(x, y, dx, dy)
    if draggedCorner then
        local keys = cornerKeys[draggedCorner]
        rect[keys[1]] = dragOffset[1] + x
        rect[keys[2]] = dragOffset[2] + y
    else
        highlightedCorner = findCorner(x, y)
    end
end


function love.mousepressed(x, y, button)
    local corner = findCorner(x, y)
    if corner then
        draggedCorner = corner
        local keys = cornerKeys[corner]
        dragOffset[1] = rect[keys[1]] - x
        dragOffset[2] = rect[keys[2]] - y
    end
end


function love.mousereleased(x, y)
    draggedCorner = nil
    highlightedCorner = findCorner(x, y)
end


function findCorner(x, y)
    local tolerance = rect.borderData[3] > 32 and rect.borderData[3] or 32
    local leftEdge   = x >= rect.x1 and x <= rect.x1 + tolerance
    local rightEdge  = x >= rect.x2 - tolerance and x <= rect.x2
    local topEdge    = y >= rect.y1 and y <= rect.y1 + tolerance
    local bottomEdge = y >= rect.y2 - tolerance and y <= rect.y2
    if leftEdge and topEdge then
        return 1
    elseif rightEdge and topEdge then
        return 2
    elseif rightEdge and bottomEdge then
        return 3
    elseif leftEdge and bottomEdge then
        return 4
    end
    return nil
end
