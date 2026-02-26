CREATE OR REPLACE FUNCTION as_date(t TIMESTAMP WITH TIME ZONE)
RETURNS JSONB AS $$
DECLARE
    utc_t TIMESTAMP;
BEGIN
    IF t IS NULL THEN RETURN NULL; END IF;
    
    utc_t := t AT TIME ZONE 'UTC';

    RETURN jsonb_build_object(
        'year',         EXTRACT(YEAR FROM utc_t)::INT,
        'month',        EXTRACT(MONTH FROM utc_t)::INT,
        'day',          EXTRACT(DAY FROM utc_t)::INT,
        'hour',         EXTRACT(HOUR FROM utc_t)::INT,
        'minute',       EXTRACT(MINUTE FROM utc_t)::INT,
        'second',       EXTRACT(SECOND FROM utc_t)::INT,
        'millisecond',  (EXTRACT(MILLISECONDS FROM utc_t)::INT % 1000),
        'microsecond',  (EXTRACT(MICROSECONDS FROM utc_t)::INT % 1000000),
        'weekday',      TO_CHAR(utc_t, 'FMDay'),
        'iso8601',      TO_CHAR(utc_t, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'raw',          (EXTRACT(EPOCH FROM utc_t) * 1000000000)::BIGINT
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;
