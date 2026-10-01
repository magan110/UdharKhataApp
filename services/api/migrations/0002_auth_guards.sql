CREATE TRIGGER access_session_insert_guard BEFORE INSERT ON access_sessions BEGIN
 SELECT RAISE(ABORT,'ACCESS_SESSION_INVALID') WHERE NEW.token_hash GLOB '*[^0-9a-f]*' OR NEW.created_at_ms > 9007199254740991 OR NEW.expires_at_ms > 9007199254740991;
END;
CREATE TRIGGER access_session_update_guard BEFORE UPDATE ON access_sessions BEGIN
 SELECT RAISE(ABORT,'ACCESS_SESSION_IMMUTABLE');
END;
CREATE TABLE spent_refresh_tokens (
 token_hash TEXT NOT NULL PRIMARY KEY CHECK(length(token_hash)=64 AND token_hash NOT GLOB '*[^0-9a-f]*'),
 session_id TEXT NOT NULL REFERENCES refresh_sessions(id) ON DELETE CASCADE
);
CREATE INDEX ix_spent_refresh_session ON spent_refresh_tokens(session_id);
CREATE TABLE auth_rate_limits (
 key_hash TEXT NOT NULL PRIMARY KEY CHECK(length(key_hash)=64 AND key_hash NOT GLOB '*[^0-9a-f]*'),
 window_start_ms INTEGER NOT NULL,
 attempts INTEGER NOT NULL CHECK(attempts>0)
);
