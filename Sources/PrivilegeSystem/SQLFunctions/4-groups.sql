CREATE OR REPLACE FUNCTION groups(target_user_id UUID)
RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'groups', jsonb_object_agg(
                current_groups.id,
                jsonb_build_object(
                    'id', current_groups.id,
                    'parent_id', current_groups.parent_id,
                    'name', current_groups.name,
                    'summary', current_groups.summary,
                    'created_at', as_date(current_groups.created_at),
                    'updated_at', as_date(current_groups.updated_at),
                    'ancestors', (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id', a.id,
                                'parent_id', a.parent_id,
                                'name', a.name,
                                'summary', a.summary,
                                'created_at', as_date(a.created_at),
                                'updated_at', as_date(a.updated_at),
                                'depth', gp.depth
                            ) ORDER BY gp.depth DESC
                        )
                        FROM group_paths gp
                        JOIN groups a ON gp.ancestor_id = a.id
                        WHERE gp.descendant_id = current_groups.id
                    )
                )
            )
        )::text
        FROM groups current_groups
        JOIN user_group_map ugm ON current_groups.id = ugm.group_id
        WHERE ugm.user_id = target_user_id
    );
END;
$$ LANGUAGE plpgsql STABLE;
