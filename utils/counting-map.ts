import { Variable } from "astal/variable";

export class CountingMap<K, V> extends Map<K, V> {
    count: Variable<number>;
    constructor() {
        super();
        this.count = new Variable(0);
    }

    clear() {
        super.clear();
        this.count.set(0);
    }

    delete(key: K): boolean {
        const result = super.delete(key);
        if (result) this.count.set(this.size);
        return result;
    }

    set(key: K, value: V): this {
        super.set(key, value);
        this.count.set(this.size);
        return this;
    }
}
