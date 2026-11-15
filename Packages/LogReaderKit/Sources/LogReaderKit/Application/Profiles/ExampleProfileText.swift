import Foundation

public enum ExampleProfileText {

    public static let json = """
    {
      "name": "My App",
      "discovery": {
        "bundleIDPrefix": "com.example",
        "logsPath": "Library/Application Support/Logs",
        "fileExtension": "txt",
        "fileNamePrefix": "log-"
      },
      "framing": { "kind": "header" },
      "entry": {
        "kind": "trailing",
        "tokens": [
          { "kind": "time" },
          { "kind": "delimited", "attribute": "source", "open": "[", "close": "]", "pattern": "file:line" },
          { "kind": "delimited", "attribute": "category", "open": "[", "close": "]", "requires": "level" },
          { "kind": "level" },
          { "kind": "list", "attribute": "tags", "prefix": "#", "requires": "level" }
        ]
      },
      "timestamp": { "format": "yyyy-MM-dd HH:mm:ss.SSS", "timeZone": "UTC" },
      "levels": [
        { "id": "debug", "codes": ["DBG"], "title": "Debug", "style": "secondary" },
        { "id": "info", "codes": ["INF"], "title": "Info", "style": "blue" },
        { "id": "notice", "codes": ["NTC"], "title": "Notice", "style": "teal" },
        { "id": "warning", "codes": ["WRN"], "title": "Warning", "style": "orange", "highlightsRow": true },
        { "id": "error", "codes": ["ERR"], "title": "Error", "style": "red", "alerts": true, "highlightsRow": true, "colorsMessage": true },
        { "id": "fault", "codes": ["FLT"], "title": "Fault", "style": "purple", "alerts": true, "highlightsRow": true, "colorsMessage": true }
      ],
      "attributes": [
        { "id": "tags", "title": "Tags", "kind": "list", "prefix": "#", "columnWidth": 110 },
        { "id": "category", "title": "Category", "columnWidth": 90 },
        { "id": "source", "title": "Source", "role": "source", "columnWidth": 170 }
      ],
      "fields": { "indent": 2 },
      "source": { "fileExtension": "swift", "editorCommand": "/usr/bin/xed", "editorArguments": ["--line", "{line}", "{path}"] }
    }

    """
}
