# db-migrations

Standalone Flyway project for the shared eCharge MySQL database.

> This is intentionally **not** a module in the parent `pom.xml`. It is never built as part of the application build. Migrations are run independently before any backend deployment.

## Setup

Create `flyway.conf` to identity the database that we are working with:


```conf
# Flyway configuration

flyway.url=jdbc:mysql://YOUR_HOST:3306/YOUR_DATABASE?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Hong_Kong
flyway.user=YOUR_USER
flyway.password=YOUR_PASSWORD

# Migration script location
flyway.locations=filesystem:src/main/resources/db/migration

# Set to true ONCE on the first run against the existing database to baseline it,
# then set back to false after baselining.
flyway.baselineOnMigrate=false
flyway.baselineVersion=0

flyway.outOfOrder=false
flyway.validateOnMigrate=true
```

## Commands

```bash
# First-time setup on an existing database — does two things:
# 1. Creates the flyway_schema_history table in the database
# 2. Inserts one row for version 0 (your baseline marker)
# After this, flyway:migrate will only run scripts with version > 0.
# Run once per database, never again.
mvn flyway:baseline

# Check pending migrations
mvn flyway:info

# Apply pending migrations
mvn flyway:migrate

# Validate applied migrations match scripts on disk
mvn flyway:validate

# Repair checksum mismatches (use with caution)
mvn flyway:repair
```

Or override credentials inline:

```bash
mvn flyway:migrate \
  -Dflyway.url="jdbc:mysql://host:3306/echarge" \
  -Dflyway.user="user" \
  -Dflyway.password="password"
```

## How it works

Flyway auto-creates a `flyway_schema_history` table in your database on first run. Every applied migration is recorded there with a checksum:

```
installed_rank  version  description             script                           checksum     success
1               0        baseline                V0__baseline.sql                 null         true
2               1        add payment method col  V1__add_payment_method_col.sql   -1234567890  true
3               2        create ev link table    V2__create_ev_link_table.sql     987654321    true
```

**On every `mvn flyway:migrate`:**
1. Connects to the DB
2. Reads `flyway_schema_history` to see what has already been applied
3. Scans `db/migration/` for `V*.sql` files
4. Anything not in the history table is "pending"
5. Runs pending scripts in version order, records each one with a CRC32 checksum
6. If a script fails, it is marked `success=false` and Flyway stops

**Checksum protection (`validateOnMigrate=true`):**
- On every run, Flyway recalculates the checksum of every script on disk and compares it against the stored value
- If a previously applied script has been edited, Flyway **throws an error and refuses to run**
- Fix with `mvn flyway:repair` — but the root cause is always: never edit a script after it has been applied anywhere
- To make a change, always add a new versioned script instead

Running `mvn flyway:migrate` is safe and idempotent — already-applied scripts are skipped, only new ones run.

## Walkthrough — first-time setup on an existing database

**Starting state:** database already has tables (`users`, `profiles`, etc.) created manually:

```sql
CREATE TABLE users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE profiles (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    bio TEXT,
    date_of_birth DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_profiles_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
```

**Step 1 — baseline the existing database:**

```bash
mvn flyway:baseline
```

Flyway creates the `flyway_schema_history` table and marks version `0` as applied. It does **not** touch `users`, `profiles`, or any other existing table. Your data and schema are completely untouched.

```
installed_rank  version  description  script            checksum  success
1               0        baseline     V0__baseline.sql  null      true
```

**Step 2 — add a new migration script** (`V1__create_event_table.sql`) and run:

```bash
mvn flyway:migrate
```

Flyway sees that `V1` is not in the history table, executes the script, and records it:

```
installed_rank  version  description          script                       checksum    success
1               0        baseline             V0__baseline.sql             null        true
2               1        create event table   V1__create_event_table.sql   123456789   true
```

The new table is created. All subsequent `mvn flyway:migrate` calls are no-ops until you add a `V2` script.

## Adding a migration

Name files using the Flyway convention:

```
V{version}__{description}.sql
```

Examples:
```
V1__add_payment_method_column.sql
V2__create_ev_link_status_table.sql
```

- Version must be strictly increasing
- Double underscore between version and description
- Never modify a script that has already been applied to any environment

## File structure

```
db-migrations/
  pom.xml
  flyway.conf                ← committed, fill in real credentials
  .gitignore
  src/main/resources/db/migration/
    V0__baseline.sql         ← baseline marker for existing DBs
    V1__....sql
```
