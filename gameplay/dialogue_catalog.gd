extends RefCounted
## Conversation content is independent of the renderer and NPC interaction.
## Add a new conversation with its own topic IDs, localized pages and optional
## objective IDs. A page can discover an objective without requiring a save.
const ENTRANCE := {
    "id": "entrance",
    "speaker": "croupier.name",
    "context": "croupier.context",
    "entry": "welcome",
    "topics": [
        {"id": "rules", "label": "croupier.option.rules", "pages": [
            {"text": "croupier.rules", "objective": "enter_main_casino"},
            {"text": "croupier.rules.choice"},
            {"text": "croupier.rules.streak"},
            {"text": "croupier.rules.mistake"}
        ]},
        {"id": "anomalies", "label": "croupier.option.anomalies", "pages": [
            {"text": "croupier.anomalies", "objective": "enter_main_casino"},
            {"text": "croupier.anomalies.subtle"},
            {"text": "croupier.anomalies.warning"}
        ]},
        {"id": "casino", "label": "croupier.option.casino", "pages": [
            {"text": "croupier.casino", "objective": "enter_main_casino"},
            {"text": "croupier.casino.galleries"},
            {"text": "croupier.casino.destination"}
        ]}
    ],
    "welcome": [{"text": "croupier.welcome"}, {"text": "croupier.welcome.second"}],
    "objectives": {"enter_main_casino": "objective.enter_main_casino"}
}


static func entrance(returning_guest: bool = false) -> Dictionary:
    var conversation := ENTRANCE.duplicate(true)
    if returning_guest:
        conversation["id"] = "entrance_returning"
        conversation["welcome"] = [
            {"text": "croupier.returning.welcome"},
            {"text": "croupier.returning.destination", "objective": "enter_main_casino"}
        ]
        var topics: Array = conversation["topics"]
        topics.append({"id": "recognition", "label": "croupier.option.recognition", "pages": [
            {"text": "croupier.returning.recognition"},
            {"text": "croupier.returning.memory"}
        ]})
    return conversation


static func pages(conversation: Dictionary, topic: String) -> Array:
    if topic == str(conversation.get("entry", "welcome")):
        return conversation.get("welcome", [])
    for record in conversation.get("topics", []):
        if str(record.get("id", "")) == topic:
            return record.get("pages", [])
    return []


static func objective_key(conversation: Dictionary, id: String) -> String:
    var objectives: Dictionary = conversation.get("objectives", {})
    return str(objectives.get(id, ""))


static func valid(conversation: Dictionary) -> bool:
    if str(conversation.get("id", "")).is_empty() or str(conversation.get("speaker", "")).is_empty() or str(conversation.get("context", "")).is_empty():
        return false
    var entry := str(conversation.get("entry", "welcome"))
    if entry.is_empty() or entry in ["leave","next","back"]:
        return false
    var ids: Dictionary = {"leave": true, "next": true, "back": true}
    ids[entry] = true
    var groups: Array = [conversation.get("welcome", [])]
    var topics: Array = conversation.get("topics", [])
    if topics.is_empty():
        return false
    for topic in topics:
        var id := str(topic.get("id", ""))
        if id.is_empty() or ids.has(id) or str(topic.get("label", "")).is_empty():
            return false
        ids[id] = true
        groups.append(topic.get("pages", []))
    for group in groups:
        if group.is_empty():
            return false
        for page in group:
            if str(page.get("text", "")).is_empty():
                return false
            var objective := str(page.get("objective", ""))
            if not objective.is_empty() and objective_key(conversation, objective).is_empty():
                return false
    return true
