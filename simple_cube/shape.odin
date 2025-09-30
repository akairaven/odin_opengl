package glfw_window

import glm "core:math/linalg/glsl"

make_cube :: proc(width: f32 = 1, texture_count: f32 = 1) -> [36]Vertex {
	value := width / 2
	tv := texture_count
	front_top_left := glm.vec3{-value, value, value}
	front_top_right := glm.vec3{value, value, value}
	front_bottom_left := glm.vec3{-value, -value, value}
	front_bottom_right := glm.vec3{value, -value, value}
	back_top_left := glm.vec3{-value, value, -value}
	back_top_right := glm.vec3{value, value, -value}
	back_bottom_left := glm.vec3{-value, -value, -value}
	back_bottom_right := glm.vec3{value, -value, -value}
	shape: [36]Vertex = {
		// front top right
		{front_top_left, {0, tv}},
		{front_top_right, {tv, tv}},
		{front_bottom_right, {tv, 0}},
		// front bottom left
		{front_top_left, {0, tv}},
		{front_bottom_right, {tv, 0}},
		{front_bottom_left, {0, 0}},
		//back 1
		{back_bottom_left, {0, -tv}},
		{back_bottom_right, {-tv, -tv}},
		{back_top_right, {-tv, 0}},
		//back 2
		{back_bottom_left, {0, -tv}},
		{back_top_right, {-tv, 0}},
		{back_top_left, {0, 0}},
		//left 1
		{back_top_left, {0, tv}},
		{front_top_left, {tv, tv}},
		{front_bottom_left, {tv, 0}},
		//left 2
		{back_top_left, {0, tv}},
		{front_bottom_left, {tv, 0}},
		{back_bottom_left, {0, 0}},
		//right 1
		{front_top_right, {0, tv}},
		{back_top_right, {tv, tv}},
		{back_bottom_right, {tv, 0}},
		//right 2
		{front_top_right, {0, tv}},
		{back_bottom_right, {tv, 0}},
		{front_bottom_right, {0, 0}},
		//top 1
		{back_top_left, {0, -tv}},
		{back_top_right, {-tv, -tv}},
		{front_top_right, {-tv, 0}},
		//top 2
		{back_top_left, {0, -tv}},
		{front_top_right, {-tv, 0}},
		{front_top_left, {0, 0}},
		//bottom 1
		{front_bottom_left, {0, -tv}},
		{front_bottom_right, {-tv, -tv}},
		{back_bottom_right, {-tv, 0}},
		//bottom 2
		{front_bottom_left, {0, -tv}},
		{back_bottom_right, {-tv, 0}},
		{back_bottom_left, {0, 0}},
	}
	return shape

}

