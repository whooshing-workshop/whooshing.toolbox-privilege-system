#!/bin/zsh
# 测试前清理数据库脚本
# 用法: ./Scripts/clean_test_db.sh
# 或直接: make clean-test-db

set -e

DB_HOST="${GITHUB_PG_TESTING_HOST:-localhost}"
DB_PORT="${GITHUB_PG_TESTING_PORT:-5432}"
DB_USER="woo"
DB_NAME="privilege_system"

echo "🗑️  清理测试数据库 $DB_NAME..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
TRUNCATE TABLE
    role_user_in_group_map,
    role_group_map,
    user_domain_map,
    domain_group_map,
    user_group_map,
    group_paths,
    domain_policies,
    role_policies,
    groups,
    roles,
    domains,
    user_info_addresses,
    user_info_alternate_emails,
    user_info_phones,
    user_infos,
    tokens,
    users
CASCADE;
"

echo "✅  数据库清理完成，可以运行 swift test 了"
