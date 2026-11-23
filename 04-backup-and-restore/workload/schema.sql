CREATE TABLE IF NOT EXISTS events (
    id         BIGSERIAL    PRIMARY KEY,
    written_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    payload    TEXT         NOT NULL,
    checksum   TEXT         NOT NULL
);
