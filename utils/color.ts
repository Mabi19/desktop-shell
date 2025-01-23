import { Gdk } from "astal/gtk4";

export interface OklabColor {
    l: number;
    a: number;
    b: number;
}

type Vector = [number, number, number];
type Matrix = [number, number, number, number, number, number, number, number, number];

function transformVector(vec: Vector, matrix: Matrix): Vector {
    return [
        matrix[0] * vec[0] + matrix[1] * vec[1] + matrix[2] * vec[2],
        matrix[3] * vec[0] + matrix[4] * vec[1] + matrix[5] * vec[2],
        matrix[6] * vec[0] + matrix[7] * vec[1] + matrix[8] * vec[2],
    ];
}

// prettier-ignore
const oklabToLMS: Matrix = [
    1,  0.3963377774,  0.2158037573,
    1, -0.1055613458, -0.0638541728,
    1, -0.0894841775, -1.2914855480
];

// prettier-ignore
const lmsToLinearRGB: Matrix = [
    4.0767416621, -3.3077115913,  0.2309699292,
    -1.2684380046,  2.6097574011, -0.3413193965,
    -0.0041960863, -0.7034186147,  1.7076147010,
];

export function convertOklabToGdk(color: OklabColor): Gdk.RGBA {
    let vec: Vector = [color.l, color.a, color.b];

    // convert to L'M'S'
    vec = transformVector(vec, oklabToLMS);
    // non-linear step to get LMS
    vec = vec.map((channelValue) => channelValue ** 3) as Vector;
    // LMS to linear RGB
    vec = transformVector(vec, lmsToLinearRGB);
    // apply gamma to get sRGB
    function applyGamma(channelValue: number) {
        if (Math.abs(channelValue) > 0.0031308)
            return Math.sign(channelValue) * (1.055 * Math.pow(Math.abs(channelValue), 1 / 2.4) - 0.055);
        else return 12.92 * channelValue;
    }
    vec = vec.map(applyGamma) as Vector;

    return new Gdk.RGBA({
        red: vec[0],
        green: vec[1],
        blue: vec[2],
        alpha: 1.0,
    });
}

export function formatOklabAsCSS(color: OklabColor) {
    return `oklab(${color.l} ${color.a} ${color.b})`;
}

export function formatRGBAsCSS(color: Gdk.RGBA) {
    function formatChannel(value: number) {
        return Math.round(value * 255)
            .toString(16)
            .padStart(2, "0");
    }

    return "#" + formatChannel(color.red) + formatChannel(color.green) + formatChannel(color.blue);
}
