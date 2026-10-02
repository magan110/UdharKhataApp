-- Environment-local key for authenticated, encrypted read cursors. Never returned or logged.
CREATE TABLE cursor_keys (
 id INTEGER NOT NULL PRIMARY KEY CHECK(id=1),
 key_hex TEXT NOT NULL CHECK(length(key_hex)=64 AND key_hex NOT GLOB '*[^0-9a-f]*')
);
