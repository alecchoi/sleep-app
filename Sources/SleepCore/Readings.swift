import Foundation

public struct QuietReading: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let setting: String
    public let body: String

    public static let all: [QuietReading] = [
        QuietReading(id: "harbor", title: "The harbor at dusk", setting: "A small place beside the water", body: """
        By the time the lamps came on, the last small boat had returned to the harbor.

        Its owner tied the rope around a wooden post, checked the knot, and set a folded cloth over the seat. There would be time to clean the boat tomorrow. For now, it sat quietly among the others, rising and settling with the water.

        Along the path, a woman closed the shutters of a little shop. She brought in the basket that had stood by the door all afternoon. Then she turned the sign, drew the curtain, and left a single light glowing in the back room.

        The harbor did not become silent all at once. First there was the sound of footsteps moving away. Then a bicycle bell, farther up the street. A cup was set down on a table somewhere behind an open window.

        Slowly, those sounds made room for the water.

        It touched the stone wall, slipped between the boats, and moved back out again. Nothing needed to be hurried. Each small wave reached the shore in its own time.

        On a bench beside the path lay a scattering of pale leaves. The wind moved one a little closer to the edge. The others stayed where they were.

        Above the rooftops, the sky held the last of the evening color. A soft blue remained over the water, while the narrow streets had already turned gray.

        In the little shop, the light in the back room went out.

        The boats settled. The rope held. The water kept its gentle rhythm.

        There was nothing more to do at the harbor tonight.
        """),
        QuietReading(id: "rain", title: "A room with rain", setting: "An ordinary evening indoors", body: """
        The rain began just after the kettle clicked off.

        At first it made only a few quiet marks on the window. Then the garden path grew darker, and the leaves of the small tree began to move under the drops.

        Inside, a cup stood on the table beside a folded newspaper. Someone had left a book open, face down, with just a few pages remaining. It could wait.

        The room was warm in the way familiar rooms can be warm. A chair stood where it always stood. A blanket rested over its arm. On the shelf, three smooth stones held a row of books in place.

        Beyond the glass, the rain continued its ordinary work. It filled the shallow bowl beneath a flowerpot. It followed a line down the window. It gathered briefly at the edge of a leaf, then fell.

        No one needed to keep track of the drops.

        The cup was moved to the sink. The book was closed, a ribbon left between the pages. The blanket was lifted from the chair and folded once, then again.

        The garden would still be there in the morning. So would the path, and the little tree, and the bowl beneath the flowerpot.

        For now, there was only the room, and the window, and the soft sound of rain.
        """),
        QuietReading(id: "greenhouse", title: "Closing the greenhouse", setting: "A quiet corner of a garden", body: """
        At the end of the afternoon, the gardener made one last walk through the greenhouse.

        The watering can was empty. She set it beside the door, with its handle turned toward the path, ready for the next morning.

        On the lowest shelf stood six small clay pots. In each, a little green stem leaned toward the glass. Nothing had changed very much since yesterday. That was how growing usually happened.

        She brushed a little soil from the edge of the bench. She placed the trowel in a wooden box and laid her gloves beside it. A length of string went back onto its hook.

        Outside, the garden was losing its sharp edges. The gravel path became a pale line between the beds. The blue flowers near the gate looked almost gray.

        She checked the greenhouse window and left it open just a little. The plants would have the air they needed.

        There were things to do tomorrow. A pot to move, a label to write, a few leaves to gather from the path. None of those things belonged to this evening.

        She stepped outside and pulled the door gently into place.

        Through the glass, the rows of pots rested in the fading light.

        The garden had enough for today.
        """)
    ]

    public static func find(_ id: String) -> QuietReading {
        all.first { $0.id == id } ?? all[0]
    }
}
