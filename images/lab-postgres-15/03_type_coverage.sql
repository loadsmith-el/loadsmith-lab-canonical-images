-- Type-coverage fixture for the postgres connector (catalog cases
-- postgres-to-parquet-types / postgres-to-postgres-types, bundle postgres-types).
--
-- The canonical telemetry table is all int/decimal/text/timestamp, so it never
-- exercises timestamptz, BC dates, NaN/Infinity, arrays of temporal/binary types,
-- or an all-NULL row. Four hand-written rows cover them:
--   1  typical values
--   2  a second instant (read back under a non-UTC session TimeZone by the case)
--   3  edge values: NaN/±Infinity, BC date/timestamp, huge numeric, empty arrays
--   4  every column NULL
-- Expected decoded values live in the bundle's check script — keep them in sync.

CREATE TABLE type_coverage (
    id                 INT PRIMARY KEY,
    c_int2             SMALLINT,
    c_int4             INT,
    c_int8             BIGINT,
    c_float4           REAL,
    c_float8           DOUBLE PRECISION,
    c_numeric          NUMERIC,
    c_numeric_10_2     NUMERIC(10,2),
    c_bool             BOOLEAN,
    c_text             TEXT,
    c_varchar          VARCHAR(20),
    c_char             CHAR(3),
    c_date             DATE,
    c_timestamp        TIMESTAMP(6),
    c_timestamptz      TIMESTAMPTZ(6),
    c_time             TIME,
    c_timetz           TIMETZ,
    c_interval         INTERVAL,
    c_uuid             UUID,
    c_json             JSON,
    c_jsonb            JSONB,
    c_inet             INET,
    c_bytea            BYTEA,
    c_int4_arr         INT[],
    c_text_arr         TEXT[],
    c_numeric_arr      NUMERIC[],
    c_date_arr         DATE[],
    c_timestamptz_arr  TIMESTAMPTZ[],
    c_bytea_arr        BYTEA[]
);

-- Destination round-trip target (scalar columns only: the destination doesn't
-- write Arrow List columns yet). Created before the rows are inserted so the
-- readiness probe (row id=4 exists) implies the whole fixture is in place.
CREATE TABLE type_coverage_sink AS
SELECT id, c_int2, c_int4, c_int8, c_float4, c_float8, c_numeric, c_numeric_10_2,
       c_bool, c_text, c_varchar, c_char, c_date, c_timestamp, c_timestamptz,
       c_time, c_timetz, c_interval, c_uuid, c_json, c_jsonb, c_inet, c_bytea
FROM type_coverage WITH NO DATA;

INSERT INTO type_coverage VALUES
(1, 12, 123456, 9007199254740993, 1.5, 2.25,
 '12345.6789', '99.95', true,
 'hello', 'varchar', 'abc',
 '2024-01-15', '2024-01-15 12:30:45.123456', '2024-01-15 12:30:45.123456+00',
 '12:30:45', '12:30:45+02', '1 day 02:03:04',
 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '{"k": "v"}', '{"k": "v"}', '192.168.0.1/24',
 '\xdeadbeef',
 '{1,2,NULL,4}', '{"a","b c","say \"hi\""}', '{1.5,NULL,-2}',
 '{2024-01-15,NULL,1999-12-31}',
 '{"2024-01-15 12:30:45+00","2000-01-01 00:00:00+00"}',
 '{"\\xdead","\\xbeef"}'),
(2, -12, -123456, -9007199254740993, -1.5, -2.25,
 '-0.000001', '-99.95', false,
 '', 'ção ✓', 'x',
 '1970-01-01', '1969-12-31 23:59:59.999', '2024-06-30 23:59:59.999-03',
 '00:00:00', '23:59:59-05:30', '-1 mon',
 '00000000-0000-0000-0000-000000000000', '[]', '[1, 2]', '::1',
 '\x',
 '{}', '{}', '{}', '{}', '{}', '{}'),
(3, 32767, 2147483647, 9223372036854775807, 'NaN', 'Infinity',
 '123456789012345678901234567890.123456789', '-12345678.99', NULL,
 'tab	and
newline', NULL, NULL,
 '0044-03-15 BC', '0044-03-15 12:00:00 BC', '0001-01-01 00:00:00+00',
 '24:00:00', NULL, '1 year 2 mons 3 days',
 NULL, 'null', '{"nested": {"a": [1, 2]}}', NULL,
 '\x00ff',
 '{-2147483648}', '{NULL}', '{NaN}', '{0044-03-15 BC}', '{NULL}', '{NULL}'),
(4, NULL, NULL, NULL, NULL, NULL,
 NULL, NULL, NULL,
 NULL, NULL, NULL,
 NULL, NULL, NULL,
 NULL, NULL, NULL,
 NULL, NULL, NULL, NULL,
 NULL,
 NULL, NULL, NULL, NULL, NULL, NULL);
