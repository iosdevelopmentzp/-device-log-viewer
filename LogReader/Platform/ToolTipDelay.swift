import LogReaderKit

enum ToolTipDelay {

    static func register(in store: any KeyValueStore) {
        store.register(defaults: ["NSInitialToolTipDelay": 1_200])
    }
}
