package utils.pg

import rego.v1

profile(user) := profile if {
    profile := call_pg("SELECT profile($1) AS profile", [user.id])
}

full_profile(user) := profile if {
    profile := call_pg("SELECT full_profile($1) AS profile", [user.id])
}

groups(user) := gs if {
    gs := call_pg("SELECT groups($1) AS groups", [user.id])
}

call_pg(query, args) := result if {
    response := sql.send({
        "driver": "postgres",
        "data_source_name": data.pg.connection,
        "query": query,
        "args": args
    })
    
    count(response.rows) > 0
    raw_text := response.rows[0][0]
    is_string(raw_text)
    result := json.unmarshal(raw_text)
}

call_resource_pg(query, args) := result if {
    response := sql.send({
        "driver": "postgres",
        "data_source_name": input.pg.connection,
        "query": query,
        "args": args
    })
    
    count(response.rows) > 0
    raw_text := response.rows[0][0]
    is_string(raw_text)
    result := json.unmarshal(raw_text)
}
