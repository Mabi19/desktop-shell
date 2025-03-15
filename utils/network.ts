import { register } from "astal/gobject";
import GObject from "gi://GObject?version=2.0";
import NM from "gi://NM?version=1.0";

let instance: NetworkService | null = null;

@register()
export class NetworkService extends GObject.Object {
    private client: NM.Client | null;

    constructor() {
        super();

        this.client = null;
        NM.Client.new_async(null, (_, res) => {
            this.client = NM.Client.new_finish(res);
            if (!this.client) {
                throw new Error("Couldn't connect to NetworkManager");
            }
        });
    }
    static getInstance() {
        if (!instance) {
            instance = new NetworkService();
        }
        return instance;
    }
}
