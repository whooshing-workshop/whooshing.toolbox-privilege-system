package authz

import rego.v1
import data.rules

rules_allowing := [ info |
    some m, t, r
    match_if_input_exist("module_id", m)
    match_if_input_exist("type_id", t)
    match_if_input_exist("rule_id", r)
    rule_content := rules[m][t][r]
    rule_content.allow == input.allow
    info := {
        "module_id": m,
        "type_id": t,
        "rule_id": r
    }
]

match_if_input_exist(path, data_key) if {
    object.get(input, path, null) == data_key
}

match_if_input_exist(path, _) if {
    object.get(input, path, null) == null
}
