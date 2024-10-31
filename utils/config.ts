import { readFile } from "astal/file";

export const CONFIG: {
    primary_monitor: string;
} = JSON.parse(readFile("./config.json"));
