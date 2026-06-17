-- The default `lab` user keeps the server-default caching_sha2_password (the
-- only plugin in MySQL 9); the connector authenticates it over plaintext via
-- the RSA public-key exchange. A second `lab_native` user covers the legacy
-- mysql_native_password path (MySQL 5.x / older 8.x), so both connector auth
-- modes are tested. The native plugin is re-enabled by native-auth.cnf on 8.4.
CREATE USER 'lab_native'@'%' IDENTIFIED WITH mysql_native_password BY 'lab';
GRANT ALL PRIVILEGES ON lab.* TO 'lab_native'@'%';

-- The canonical 34-column schema in MySQL dialect (see
-- loadsmith-lab-canonical-data). DATETIME (not TIMESTAMP) avoids the 2038 range
-- limit and MySQL's implicit auto-init/update on the first TIMESTAMP column.
CREATE TABLE spacecraft_telemetry_events (
    id                VARCHAR(36)   NOT NULL PRIMARY KEY,
    spacecraft_id     VARCHAR(50)   NOT NULL,
    mission_id        VARCHAR(50)   NOT NULL,
    event_sequence    BIGINT        NOT NULL,

    sensor_name       VARCHAR(100)  NOT NULL,
    sensor_type       VARCHAR(50)   NOT NULL,

    reading_int       INT           NULL,
    reading_bigint    BIGINT        NULL,
    reading_decimal   DECIMAL(18,6) NULL,
    reading_double    DOUBLE        NULL,
    reading_bool      TINYINT(1)    NULL,
    reading_text      TEXT          NULL,

    status_code       SMALLINT      NOT NULL,
    severity          VARCHAR(20)   NOT NULL,
    is_anomaly        TINYINT(1)    NOT NULL,

    event_date        DATE          NOT NULL,
    event_time        TIME          NULL,
    event_timestamp   DATETIME      NOT NULL,
    received_at       DATETIME      NULL,

    latitude          DECIMAL(9,6)  NULL,
    longitude         DECIMAL(9,6)  NULL,
    altitude_km       DECIMAL(12,3) NULL,
    velocity_kmh      DECIMAL(12,3) NULL,

    temperature_c     DECIMAL(8,3)  NULL,
    radiation_level   DECIMAL(10,5) NULL,
    battery_percent   DECIMAL(5,2)  NULL,
    payload_mass_kg   DECIMAL(10,3) NULL,

    operator_notes    TEXT          NULL,
    raw_payload_json  TEXT          NULL,
    tags              TEXT          NULL,

    checksum          CHAR(64)      NULL,

    created_at        DATETIME      NOT NULL,
    updated_at        DATETIME      NOT NULL,
    deleted_at        DATETIME      NULL
);

-- The canonical CSV encodes NULL as an empty field and booleans as true/false,
-- with CRLF line endings (Python csv writer). Load every column into a user
-- variable, then NULLIF empties and convert booleans in the SET clause.
LOAD DATA INFILE '/var/lib/mysql-files/events.csv'
INTO TABLE spacecraft_telemetry_events
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(@id,@spacecraft_id,@mission_id,@event_sequence,@sensor_name,@sensor_type,
 @reading_int,@reading_bigint,@reading_decimal,@reading_double,@reading_bool,@reading_text,
 @status_code,@severity,@is_anomaly,@event_date,@event_time,@event_timestamp,@received_at,
 @latitude,@longitude,@altitude_km,@velocity_kmh,@temperature_c,@radiation_level,
 @battery_percent,@payload_mass_kg,@operator_notes,@raw_payload_json,@tags,@checksum,
 @created_at,@updated_at,@deleted_at)
SET
  id               = @id,
  spacecraft_id    = @spacecraft_id,
  mission_id       = @mission_id,
  event_sequence   = @event_sequence,
  sensor_name      = @sensor_name,
  sensor_type      = @sensor_type,
  reading_int      = NULLIF(@reading_int, ''),
  reading_bigint   = NULLIF(@reading_bigint, ''),
  reading_decimal  = NULLIF(@reading_decimal, ''),
  reading_double   = NULLIF(@reading_double, ''),
  reading_bool     = IF(@reading_bool = '', NULL, @reading_bool = 'true'),
  reading_text     = NULLIF(@reading_text, ''),
  status_code      = @status_code,
  severity         = @severity,
  is_anomaly       = (@is_anomaly = 'true'),
  event_date       = @event_date,
  event_time       = NULLIF(@event_time, ''),
  event_timestamp  = @event_timestamp,
  received_at      = NULLIF(@received_at, ''),
  latitude         = NULLIF(@latitude, ''),
  longitude        = NULLIF(@longitude, ''),
  altitude_km      = NULLIF(@altitude_km, ''),
  velocity_kmh     = NULLIF(@velocity_kmh, ''),
  temperature_c    = NULLIF(@temperature_c, ''),
  radiation_level  = NULLIF(@radiation_level, ''),
  battery_percent  = NULLIF(@battery_percent, ''),
  payload_mass_kg  = NULLIF(@payload_mass_kg, ''),
  operator_notes   = NULLIF(@operator_notes, ''),
  raw_payload_json = NULLIF(@raw_payload_json, ''),
  tags             = NULLIF(@tags, ''),
  checksum         = NULLIF(@checksum, ''),
  created_at       = @created_at,
  updated_at       = @updated_at,
  deleted_at       = NULLIF(@deleted_at, '');

CREATE INDEX idx_spacecraft  ON spacecraft_telemetry_events (spacecraft_id);
CREATE INDEX idx_mission     ON spacecraft_telemetry_events (mission_id);
CREATE INDEX idx_sensor_type ON spacecraft_telemetry_events (sensor_type);
CREATE INDEX idx_timestamp   ON spacecraft_telemetry_events (event_timestamp);

-- Empty target table for the MySQL *destination* cases (mysql-to-mysql). Same
-- schema + PRIMARY KEY as the source, so atomic INSERT and staged_merge upsert
-- (ON DUPLICATE KEY by `id`) both have a table to write into. Starts empty and
-- is recreated fresh on every case run (each case gets a new container).
CREATE TABLE events_sink LIKE spacecraft_telemetry_events;
