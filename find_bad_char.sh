#!/bin/bash

# Usage: ./find_special_char_columns.sh SCHEMA.TABLENAME ID_COLUMN ID_VALUE

if [ $# -ne 3 ]; then
  echo "Usage: $0 SCHEMA.TABLENAME ID_COLUMN ID_VALUE"
  exit 1
fi

INPUT="$1"
ID_COL="$2"
ID_VAL="$3"

SCHEMA=$(echo "$INPUT" | cut -d'.' -f1 | tr '[:lower:]' '[:upper:]')
TBL_NAME=$(echo "$INPUT" | cut -d'.' -f2 | tr '[:lower:]' '[:upper:]')

ALL_COLS_FILE="all_columns.tmp"
CHAR_COLS_FILE="char_columns.tmp"
ID_TYPE_FILE="id_type.tmp"

# Step 1: Get all column types
sqlplus -s / as sysdba <<EOF > $ALL_COLS_FILE
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT column_name || '|' || data_type 
FROM all_tab_columns 
WHERE table_name = '$TBL_NAME' AND owner = '$SCHEMA'
ORDER BY column_id;
EXIT;
EOF

# Step 2: Extract ID column type to decide quoting
grep -i "^$ID_COL|" "$ALL_COLS_FILE" > "$ID_TYPE_FILE"
ID_TYPE=$(cut -d'|' -f2 "$ID_TYPE_FILE" | tr '[:lower:]' '[:upper:]')

if [[ "$ID_TYPE" == "NVARCHAR" || "$ID_TYPE" == "NVARCHAR2" || "$ID_TYPE" == "VARCHAR2" || "$ID_TYPE" == "CHAR" ]]; then
  WHERE_ID="$ID_COL = '$ID_VAL'"
else
  WHERE_ID="$ID_COL = $ID_VAL"
fi

# Step 3: Extract CHAR/VARCHAR2 columns
grep -E '\|(NVARCHAR|NVARCHAR2|VARCHAR2|CHAR)$' "$ALL_COLS_FILE" | cut -d'|' -f1 > "$CHAR_COLS_FILE"

# Step 4: Generate SQL - part A: Multi-column SELECT with CASE
echo
echo "? SQL to show each matched column in one field:"
echo "SELECT $ID_COL,"

awk -v indent="  " '{
  printf indent "CASE\n"
  printf indent "  WHEN %s LIKE '\''%%'\''||CHR(6)||'\''%%'\'' THEN '\''%s=CHR(6)'\''\n", $1, $1
  printf indent "  WHEN %s LIKE '\''%%'\''||CHR(0)||'\''%%'\'' THEN '\''%s=CHR(0)'\''\n", $1, $1
  printf indent "  WHEN %s LIKE '\''%%'\''||CHR(92)||'\''%%'\'' THEN '\''%s=CHR(92)'\''\n", $1, $1
  printf indent "  WHEN %s LIKE '\''%%'\''||CHR(10)||'\''%%'\'' THEN '\''%s=CHR(10)'\''\n", $1, $1
  printf indent "  WHEN %s LIKE '\''%%'\''||CHR(13)||'\''%%'\'' THEN '\''%s=CHR(13)'\''\n", $1, $1
  printf indent "  ELSE NULL END AS %s_result,\n", $1
}' "$CHAR_COLS_FILE"

echo "  'done' as sentinel"
echo "FROM $SCHEMA.$TBL_NAME"
echo "WHERE $WHERE_ID;"

# Step 5: Generate SQL - part B: One row per match (UNION ALL)
echo
echo "? SQL to show each match as one row:"
echo "SELECT '$ID_VAL' AS $ID_COL, column_name, column_value FROM ("

awk -v id_col="$ID_COL" -v id_val="$ID_VAL" -v tbl="$SCHEMA.$TBL_NAME" -v where="$WHERE_ID" '
BEGIN { first = 1 }
/./ {
  col = $1
  if (!first) print "UNION ALL"
  first = 0
  printf "SELECT '\''%s'\'' AS column_name,%s as column_value FROM %s WHERE (%s LIKE '\''%%'\''||CHR(6)||'\''%%'\'' OR %s LIKE '\''%%'\''||CHR(0)||'\''%%'\'' OR %s LIKE '\''%%'\''||chr(92)||'\''%%'\'' OR %s LIKE '\''%%'\''||chr(10)||'\''%%'\'' OR %s LIKE '\''%%'\''||chr(13)||'\''%%'\'') AND %s\n", col,col, tbl, col, col, col,col, col, where
}' "$CHAR_COLS_FILE"

echo ") WHERE column_name IS NOT NULL;"

