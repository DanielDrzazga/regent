# Domain glossary — Notes

## Terms

**Note** — a User's record: a title and a body, with a creation date.
_Avoid:_ entry, post, memo

**Title** — a Note's short name by which the User and the Consultant recognize it.
_Avoid:_ heading, subject

**Archiving** — taking a Note off the list without deleting it; the Note can be restored.
_Avoid:_ soft delete, trash

**User** — a person who creates and reads their own Notes.
_Avoid:_ customer, client

**Consultant** — a customer support employee who looks up a User's Notes at the User's request.
_Avoid:_ support, agent, helpdesk

## Relations

- A User has many Notes
- A Note has exactly one Title
- A Consultant works on the Notes of the User who made the request
