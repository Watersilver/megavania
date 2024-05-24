shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

bool is_col(vec4 c, float r, float g, float b) {
	if (!(c.r > r - 0.1 && c.r < r + 0.1)) return false;
	if (!(c.g > g - 0.1 && c.g < g + 0.1)) return false;
	if (!(c.b > b - 0.1 && c.b < b + 0.1)) return false;
	return true;
}

void set_col(inout vec4 c, float r, float g, float b) {
	c.r = r;
	c.g = g;
	c.b = b;
}

void fragment() {
	
	if (
		// Dark Yellow
		is_col(COLOR, 0.82, 0.8, 0.376)
	) {
		set_col(COLOR, 0.675, 0.196, 0.196);
	} else if (
		// Yellow
		is_col(COLOR, 0.984, 0.949, 0.212)
	) {
		set_col(COLOR, 0.675, 0.196, 0.196);
	} else if (
		// Light Red
		is_col(COLOR, 0.851, 0.341, 0.388)
	) {
		set_col(COLOR, 0.851, 0.341, 0.388);
	} else if (
		// Dark Red
		is_col(COLOR, 0.675, 0.196, 0.196)
	) {
		set_col(COLOR, 0.851, 0.341, 0.388);
	} else if (
		// Dark Green
		is_col(COLOR, 0.416, 0.745, 0.188)
	) {
		set_col(COLOR, 0.416, 0.745, 0.188);
	} else if (
		// Light Green
		is_col(COLOR, 0.600, 0.898, 0.314)
	) {
		set_col(COLOR, 0.600, 0.898, 0.314);
	} else if (
		// Dark Purple
		is_col(COLOR, 0.584, 0.090, 0.600)
	) {
		set_col(COLOR, 0.416, 0.745, 0.188);
	} else if (
		// Light Purple
		is_col(COLOR, 0.686, 0.102, 0.698)
	) {
		set_col(COLOR, 0.600, 0.898, 0.314);
	} else if (
		// Light Brown
		is_col(COLOR, 0.875, 0.443, 0.149)
	) {
		set_col(COLOR, 0.686, 0.102, 0.698);
	} else if (
		// Dark Brown
		is_col(COLOR, 0.769, 0.392, 0.137)
	) {
		set_col(COLOR, 0.584, 0.090, 0.600);
	} else if (
		// Blue
		is_col(COLOR, 0.373, 0.804, 0.894)
	) {
		set_col(COLOR, 0.373, 0.804, 0.894);
	}
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
