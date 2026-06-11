CREATE TABLE spacecraft_telemetry_events (
    id                VARCHAR(36)      PRIMARY KEY,
    spacecraft_id     VARCHAR(50)      NOT NULL,
    mission_id        VARCHAR(50)      NOT NULL,
    event_sequence    BIGINT           NOT NULL,

    sensor_name       VARCHAR(100)     NOT NULL,
    sensor_type       VARCHAR(50)      NOT NULL,

    reading_int       INTEGER          NULL,
    reading_bigint    BIGINT           NULL,
    reading_decimal   DECIMAL(18,6)    NULL,
    reading_double    DOUBLE PRECISION NULL,
    reading_bool      BOOLEAN          NULL,
    reading_text      TEXT             NULL,

    status_code       SMALLINT         NOT NULL,
    severity          VARCHAR(20)      NOT NULL,
    is_anomaly        BOOLEAN          NOT NULL,

    event_date        DATE             NOT NULL,
    event_time        TIME             NULL,
    event_timestamp   TIMESTAMP        NOT NULL,
    received_at       TIMESTAMP        NULL,

    latitude          DECIMAL(9,6)     NULL,
    longitude         DECIMAL(9,6)     NULL,
    altitude_km       DECIMAL(12,3)    NULL,
    velocity_kmh      DECIMAL(12,3)    NULL,

    temperature_c     DECIMAL(8,3)     NULL,
    radiation_level   DECIMAL(10,5)    NULL,
    battery_percent   DECIMAL(5,2)     NULL,
    payload_mass_kg   DECIMAL(10,3)    NULL,

    operator_notes    TEXT             NULL,
    raw_payload_json  TEXT             NULL,
    tags              TEXT             NULL,

    checksum          CHAR(64)         NULL,

    created_at        TIMESTAMP        NOT NULL,
    updated_at        TIMESTAMP        NOT NULL,
    deleted_at        TIMESTAMP        NULL
);

COPY spacecraft_telemetry_events
FROM '/docker-entrypoint-initdb.d/events.csv'
WITH (FORMAT CSV, HEADER true, NULL '');

CREATE INDEX idx_spacecraft ON spacecraft_telemetry_events (spacecraft_id);
CREATE INDEX idx_mission    ON spacecraft_telemetry_events (mission_id);
CREATE INDEX idx_sensor_type ON spacecraft_telemetry_events (sensor_type);
CREATE INDEX idx_timestamp  ON spacecraft_telemetry_events (event_timestamp);
