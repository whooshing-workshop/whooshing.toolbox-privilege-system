CREATE OR REPLACE FUNCTION full_profile(target_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    result_json TEXT;
BEGIN
    SELECT jsonb_build_object(
        'id', u.id,
        'email', u.email,
        'user_info_id', ui.id,
        'id_number', ui.id_number,
        'birthday', as_date(ui.birthday),
        'created_at', as_date(ui.created_at),
        'updated_at', as_date(ui.updated_at),
        'addresses', (
            SELECT jsonb_agg(jsonb_build_object(
                'id', uia.id,
                'address', uia.address,
                'order', uia.order,
                'description', uia.description,
                'created_at', as_date(uia.created_at),
                'updated_at', as_date(uia.updated_at)
            ))
            FROM user_info_addresses uia
            WHERE uia.user_info_id = ui.id
        ),
        'alternate_emails', (
            SELECT jsonb_agg(jsonb_build_object(
                'id', uie.id,
                'email', uie.alternate_email,
                'description', uie.description,
                'created_at', as_date(uie.created_at),
                'updated_at', as_date(uie.updated_at)
            ))
            FROM user_info_alternate_emails uie
            WHERE uie.user_info_id = ui.id
        ),
        'phones', (
            SELECT jsonb_agg(jsonb_build_object(
                'id', uip.id,
                'phone', uip.phone,
                'description', uip.description,
                'created_at', as_date(uip.created_at),
                'updated_at', as_date(uip.updated_at)
            ))
            FROM user_info_phones uip
            WHERE uip.user_info_id = ui.id
        )
    )::text
    INTO result_json
    FROM users u
    LEFT JOIN user_infos ui ON u.id = ui.user_id
    WHERE u.id = target_user_id;

    RETURN result_json;
END;
$$ LANGUAGE plpgsql STABLE;
