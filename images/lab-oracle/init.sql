-- Seeds the canonical spacecraft_telemetry_events dataset into Oracle.
--
-- gvenzl runs *.sql init scripts as `sqlplus / as sysdba` against the CDB root,
-- so we switch into the FREEPDB1 pluggable database (where gvenzl already
-- created the APP_USER `lab`) and build everything in the LAB schema.
--
-- The CSV is loaded with an ORACLE_LOADER external table → INSERT SELECT, which
-- is the pure-SQL equivalent of postgres COPY / mysql LOAD DATA. The seed file
-- is normalized to LF in the image build (see Dockerfile), so the external
-- table can use the simple `RECORDS DELIMITED BY NEWLINE`.

ALTER SESSION SET CONTAINER = FREEPDB1;

-- The directory the external table reads the seed CSV from (oracle owns it).
CREATE OR REPLACE DIRECTORY lab_seed_dir AS '/opt/oracle/seed';
GRANT READ, WRITE ON DIRECTORY lab_seed_dir TO lab;

-- Build all objects in the app schema.
ALTER SESSION SET CURRENT_SCHEMA = LAB;

-- ── External table over the raw CSV (every column read as text) ───────────────
-- All columns VARCHAR2 (read as text); CHAR maxes at 2000 bytes, too small for
-- the JSON column, and padding would corrupt the values anyway.
CREATE TABLE ext_events (
  id               VARCHAR2(36),  spacecraft_id  VARCHAR2(50),  mission_id     VARCHAR2(50),
  event_sequence   VARCHAR2(20),  sensor_name    VARCHAR2(100), sensor_type    VARCHAR2(50),
  reading_int      VARCHAR2(20),  reading_bigint VARCHAR2(20),  reading_decimal VARCHAR2(40),
  reading_double   VARCHAR2(40),  reading_bool   VARCHAR2(5),   reading_text   VARCHAR2(200),
  status_code      VARCHAR2(10),  severity       VARCHAR2(20),  is_anomaly     VARCHAR2(5),
  event_date       VARCHAR2(10),  event_time     VARCHAR2(8),   event_timestamp VARCHAR2(19),
  received_at      VARCHAR2(19),  latitude       VARCHAR2(20),  longitude      VARCHAR2(20),
  altitude_km      VARCHAR2(20),  velocity_kmh   VARCHAR2(20),  temperature_c  VARCHAR2(20),
  radiation_level  VARCHAR2(20),  battery_percent VARCHAR2(20), payload_mass_kg VARCHAR2(20),
  operator_notes   VARCHAR2(200), raw_payload_json VARCHAR2(4000), tags        VARCHAR2(200),
  checksum         VARCHAR2(64),  created_at     VARCHAR2(19),  updated_at     VARCHAR2(19),
  deleted_at       VARCHAR2(19)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER
  DEFAULT DIRECTORY lab_seed_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE SKIP 1
    LOGFILE lab_seed_dir:'events.log'
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
    (
      id, spacecraft_id, mission_id, event_sequence, sensor_name, sensor_type,
      reading_int, reading_bigint, reading_decimal, reading_double, reading_bool,
      reading_text, status_code, severity, is_anomaly, event_date, event_time,
      event_timestamp, received_at, latitude, longitude, altitude_km, velocity_kmh,
      temperature_c, radiation_level, battery_percent, payload_mass_kg,
      operator_notes, raw_payload_json, tags, checksum, created_at, updated_at,
      deleted_at
    )
  )
  LOCATION ('events.csv')
)
REJECT LIMIT UNLIMITED;

-- ── Canonical schema in Oracle dialect ────────────────────────────────────────
-- 12c–19c-compatible types (the connector's target range): no native BOOLEAN
-- (NUMBER(1) carries true/false as 1/0), no TIME (VARCHAR2(8) HH24:MI:SS).
-- reading_double is BINARY_DOUBLE on purpose, to exercise that connector path.
CREATE TABLE spacecraft_telemetry_events (
  id               VARCHAR2(36)  NOT NULL,
  spacecraft_id    VARCHAR2(50)  NOT NULL,
  mission_id       VARCHAR2(50)  NOT NULL,
  event_sequence   NUMBER(19)    NOT NULL,
  sensor_name      VARCHAR2(100) NOT NULL,
  sensor_type      VARCHAR2(50)  NOT NULL,
  reading_int      NUMBER(10),
  reading_bigint   NUMBER(19),
  reading_decimal  NUMBER(18,6),
  reading_double   BINARY_DOUBLE,
  reading_bool     NUMBER(1),
  reading_text     VARCHAR2(200),
  status_code      NUMBER(5)     NOT NULL,
  severity         VARCHAR2(20)  NOT NULL,
  is_anomaly       NUMBER(1)     NOT NULL,
  event_date       DATE          NOT NULL,
  event_time       VARCHAR2(8),
  event_timestamp  TIMESTAMP     NOT NULL,
  received_at      TIMESTAMP,
  latitude         NUMBER(9,6),
  longitude        NUMBER(9,6),
  altitude_km      NUMBER(12,3),
  velocity_kmh     NUMBER(12,3),
  temperature_c    NUMBER(8,3),
  radiation_level  NUMBER(10,5),
  battery_percent  NUMBER(5,2),
  payload_mass_kg  NUMBER(10,3),
  operator_notes   VARCHAR2(200),
  raw_payload_json VARCHAR2(4000),
  tags             VARCHAR2(200),
  checksum         CHAR(64),
  created_at       TIMESTAMP     NOT NULL,
  updated_at       TIMESTAMP     NOT NULL,
  deleted_at       TIMESTAMP,
  CONSTRAINT pk_ste PRIMARY KEY (id)
);

-- Load with explicit text→type conversions (NLS-independent, mirrors how the
-- connector reads/writes). Empty CSV fields arrive as NULL from the ext table.
INSERT INTO spacecraft_telemetry_events
SELECT
  id, spacecraft_id, mission_id, TO_NUMBER(event_sequence), sensor_name, sensor_type,
  TO_NUMBER(reading_int), TO_NUMBER(reading_bigint), TO_NUMBER(reading_decimal),
  TO_BINARY_DOUBLE(reading_double),
  DECODE(reading_bool, 'true', 1, 'false', 0, NULL),
  reading_text, TO_NUMBER(status_code), severity,
  DECODE(is_anomaly, 'true', 1, 'false', 0, NULL),
  TO_DATE(event_date, 'YYYY-MM-DD'), event_time,
  TO_TIMESTAMP(event_timestamp, 'YYYY-MM-DD HH24:MI:SS'),
  TO_TIMESTAMP(received_at, 'YYYY-MM-DD HH24:MI:SS'),
  TO_NUMBER(latitude), TO_NUMBER(longitude), TO_NUMBER(altitude_km), TO_NUMBER(velocity_kmh),
  TO_NUMBER(temperature_c), TO_NUMBER(radiation_level), TO_NUMBER(battery_percent),
  TO_NUMBER(payload_mass_kg),
  operator_notes, raw_payload_json, tags, checksum,
  TO_TIMESTAMP(created_at, 'YYYY-MM-DD HH24:MI:SS'),
  TO_TIMESTAMP(updated_at, 'YYYY-MM-DD HH24:MI:SS'),
  TO_TIMESTAMP(deleted_at, 'YYYY-MM-DD HH24:MI:SS')
FROM ext_events;

COMMIT;

DROP TABLE ext_events;

CREATE INDEX idx_ste_spacecraft  ON spacecraft_telemetry_events (spacecraft_id);
CREATE INDEX idx_ste_mission     ON spacecraft_telemetry_events (mission_id);
CREATE INDEX idx_ste_sensor_type ON spacecraft_telemetry_events (sensor_type);
CREATE INDEX idx_ste_timestamp   ON spacecraft_telemetry_events (event_timestamp);

-- Empty target table for the oracle-to-oracle destination cases (atomic INSERT
-- and staged_merge MERGE by id). Same schema + PK; starts empty, recreated
-- fresh per case run (each case gets a new container).
CREATE TABLE events_sink AS SELECT * FROM spacecraft_telemetry_events WHERE 1 = 0;
ALTER TABLE events_sink ADD CONSTRAINT pk_sink PRIMARY KEY (id);

-- Binary/LOB fixture. The 34-column telemetry table is all text/number/temporal,
-- so it never exercises the connector's binary path: RAW/BLOB are read as Arrow
-- Binary (Cell::Bytes) and CLOB as text (TO_CHAR), then bound back on write. This
-- small table + its sink let the oracle-to-oracle-lob case round-trip those types
-- against a real Oracle. Kept ASCII so init-time charset handling is irrelevant;
-- row 3 covers NULL RAW/LOB.
CREATE TABLE lob_roundtrip (
  id        NUMBER(10) NOT NULL PRIMARY KEY,
  raw_data  RAW(2000),
  blob_data BLOB,
  clob_data CLOB
);
INSERT INTO lob_roundtrip (id, raw_data, blob_data, clob_data) VALUES
  (1, HEXTORAW('48656C6C6F2C204F7261636C652100'),
      TO_BLOB(HEXTORAW('DEADBEEF0102030405060708090A0B0C0D0E0F')),
      TO_CLOB('the quick brown fox jumps over the lazy dog'));
INSERT INTO lob_roundtrip (id, raw_data, blob_data, clob_data) VALUES
  (2, HEXTORAW('00FF00FF7F8081FE'),
      TO_BLOB(HEXTORAW('0011223344556677889900AABBCCDDEEFF')),
      TO_CLOB('lorem ipsum dolor sit amet, consectetur adipiscing elit'));
INSERT INTO lob_roundtrip (id, raw_data, blob_data, clob_data) VALUES
  (3, NULL, NULL, NULL);
COMMIT;

CREATE TABLE lob_roundtrip_sink AS SELECT * FROM lob_roundtrip WHERE 1 = 0;
ALTER TABLE lob_roundtrip_sink ADD CONSTRAINT pk_lob_sink PRIMARY KEY (id);

exit;
