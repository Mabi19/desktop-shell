namespace ColorConversion {
const double MATRIX_OKLAB_TO_LMS[9] = {
    1.0, 0.3963377774, 0.2158037573,
    1.0, -0.1055613458, -0.0638541728,
    1.0, -0.0894841775, -1.2914855480,
};

const double MATRIX_LMS_TO_LINEAR_RGB[9] = {
    4.0767416621, -3.3077115913, 0.2309699292,
    -1.2684380046, 2.6097574011, -0.3413193965,
    -0.0041960863, -0.7034186147, 1.7076147010,
};

const double MATRIX_LMS_TO_OKLAB[9] = {
    0.2104542682, 0.7936177747, -0.0040720430,
    1.9779985323, -2.4285922419, 0.4505937095,
    0.0259040424, 0.7827717124, -0.8086757549,
};

const double MATRIX_LINEAR_RGB_TO_LMS[9] = {
    0.4122214708, 0.5363325363, 0.0514459928,
    0.2119034982, 0.6806995451, 0.1073969566,
    0.0883024618, 0.2817188376, 0.6299787004,
};

void apply_matrix(double[] vec, double matrix[9]) {
    double n1 = matrix[0] * vec[0] + matrix[1] * vec[1] + matrix[2] * vec[2];
    double n2 = matrix[3] * vec[0] + matrix[4] * vec[1] + matrix[5] * vec[2];
    double n3 = matrix[6] * vec[0] + matrix[7] * vec[1] + matrix[8] * vec[2];
    vec[0] = n1;
    vec[1] = n2;
    vec[2] = n3;
}
}


/**
 * A color in the Oklab color space, which also stores an RGBA representation for quick usage.
 */
struct Color {
    public float l;
    public float a;
    public float b;
    public float alpha;
    public Gdk.RGBA rgba;

    /**
     * Compute the Oklab representation of a color from its RGBA representation.
     */
    public static Color from_rgba(Gdk.RGBA rgba) {
        double vec[3] = {rgba.red, rgba.green, rgba.blue};
        for (int i = 0; i < 3; i++) {
            var value = vec[i].clamp(0, 1);
            if (value > 0.04045) {
                value = Math.pow((value + 0.055) / 1.055, 2.4);
            } else {
                value = value / 12.92;
            }
            vec[i] = value;
        }
        ColorConversion.apply_matrix(vec, ColorConversion.MATRIX_LINEAR_RGB_TO_LMS);
        for (int i = 0; i < 3; i++) {
            vec[i] = Math.cbrt(vec[i]);
        }
        ColorConversion.apply_matrix(vec, ColorConversion.MATRIX_LMS_TO_OKLAB);

        var result = Color() {
            l = (float)vec[0],
            a = (float)vec[1],
            b = (float)vec[2],
            alpha = rgba.alpha,
            rgba = rgba,
        };
        return result;
    }

    /**
     * Recompute the RGBA representation of a color. Call this after manually modifying the struct's fields. Returns self for easier chaining.
     */
    public Color recompute_rgba() {
        double vec[3] = {l, a, b};
        ColorConversion.apply_matrix(vec, ColorConversion.MATRIX_OKLAB_TO_LMS);
        for (int i = 0; i < 3; i++) {
            vec[i] = vec[i] * vec[i] * vec[i];
        }
        ColorConversion.apply_matrix(vec, ColorConversion.MATRIX_LMS_TO_LINEAR_RGB);
        for (int i = 0; i < 3; i++) {
            var value = vec[i].clamp(0, 1);
            if (value > 0.0031308) {
                value = (1.055 * Math.pow(value, 1 / 2.4) - 0.055);
            } else {
                value = 12.92 * value;
            }
            vec[i] = value;
        }
        rgba = Gdk.RGBA() {
            red = (float)vec[0], green = (float)vec[1], blue = (float)vec[2], alpha = alpha
        };
        return this;
    }

    public static Color lerp(Color a, Color b, float factor) {
        return Color() {
            l = a.l * (1 - factor) + b.l * factor,
            a = a.a * (1 - factor) + b.a * factor,
            b = a.b * (1 - factor) + b.b * factor,
            alpha = a.alpha * (1 - factor) + b.alpha * factor,
        }.recompute_rgba();
    }
}
