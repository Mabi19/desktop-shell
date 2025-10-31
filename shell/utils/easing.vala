namespace Easing {
float ease_out_cubic(float t) {
    var m = 1.0f - t;
    return 1.0f - m * m * m;
}

/**
 * Get the progress t' for an ease-out-cubic animation,
 * which is the inverse of another ease-out-cubic animation,
 * so that their values match up.
 * That is, ease_out_cubic(t) = 1 - ease_out_cubic(ease_out_cubic_invert(t))
 */
float ease_out_cubic_invert(float t) {
    return 1.0f - Math.cbrtf(Math.powf(t - 1.0f, 3.0f) + 1.0f);
}

float ease_in_out_quad(float t) {
    return t < 0.5 ? 2 * t * t : 1 - Math.powf(-2 * t + 2, 2) / 2;
}
}
