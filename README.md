## Scripts

This directory contains utility scripts for database and data-quality workflows.

- **Audience**: data engineers, DBAs, and developers
- **Platform**: Bash scripts; compatible with Linux/macOS. On Windows, use WSL or Git Bash.

### Prerequisites

- Bash 4+ (or compatible shell)
- Oracle client with `sqlplus` available in `PATH`
- Network access and privileges to query target database metadata and tables

## Available scripts

### `find_bad_char.sh`

When loading delimiter file into postgresql compatible database, if there are special chars, the copy command will fail, when this happend, let "find_bad_char.sh" to find rows that contain problematic/special characters in `CHAR`/`VARCHAR` columns for a specific row key in an Oracle table. It generates two SQL snippets you can run to inspect the data.

#### Usage

```bash
./find_bad_char.sh SCHEMA.TABLENAME ID_COLUMN ID_VALUE
```

Example:

```bash
./find_bad_char.sh HR.EMPLOYEES EMPLOYEE_ID 101
```

#### What it does

- Queries Oracle data dictionary to list all columns and types for the table
- Detects the ID column type to decide whether to quote the `ID_VALUE`
- Targets textual columns (`NVARCHAR2`, `VARCHAR2`, `CHAR`)
- Emits two SQL queries:
  - A single-row SELECT returning, for each text column, which special char was found
  - A UNION ALL view listing one row per match with `column_name` and `column_value`

Characters checked:

- `CHR(6)`  (delimiter)
- `CHR(0)`
- `CHR(92)` (backslash)
- `CHR(10)` (newline)
- `CHR(13)` (carriage return)

Temporary files created in the working directory:

- `all_columns.tmp`, `char_columns.tmp`, `id_type.tmp`

#### Connection notes

- The script uses `sqlplus -s / as sysdba` by default. If you are not using OS authentication or should not connect as SYSDBA, change that line to a standard connection string like:

  ```bash
  sqlplus -s user/password@HOST:PORT/SERVICE
  ```

## Contributing / adding scripts

- Place new scripts in this folder
- Add a short section here with name, purpose, usage, and prerequisites
- Keep examples minimal and anonymized


