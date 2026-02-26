CREATE OR REPLACE FUNCTION profile(target_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    result_json TEXT;
BEGIN
    SELECT jsonb_build_object(
        'id', ui.id,
        'user_id', ui.user_id,
        'id_number', ui.id_number,
        'birthday', as_date(ui.birthday),
        'created_at', as_date(ui.created_at),
        'updated_at', as_date(ui.updated_at)
    )::text
    INTO result_json
    FROM user_infos ui
    WHERE ui.user_id = target_user_id;

    RETURN result_json;
END;
$$ LANGUAGE plpgsql STABLE;
