import Foundation

@testable import Hiint

let helloJSON = """
    {
        "v": 1,
        "workspace": {
            "slug": "driftnote",
            "name": "Driftnote",
            "logo_url": "https://files.hiint.app/workspaces/1/logo/a.png",
            "brand_colour": "#3e63dd"
        },
        "board_url": "https://feedback.driftnote.app",
        "sections": { "roadmap": true, "changelog": false },
        "boards": [{ "slug": "ideas", "name": "Ideas" }, { "slug": "bugs", "name": "Bugs" }],
        "recent_updates": ["2026-11-01T09:12:00.000Z", "2026-10-28T16:40:00Z"],
        "a_field_from_a_later_version": { "anything": true }
    }
    """

func makeHello() throws -> Hello {
    try Hello.decode(Data(helloJSON.utf8))
}
