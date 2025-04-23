# Mimimal Postgresql client for Jai

This module contains `libpq` bindings as well as some higher-level functions for…
* … connecting to a Postgresql database,
* … executing parameterized queries and
* … optionally parsing the results into a typed array.

It only supports synchronous execution for now.

## Usage

First connect to a Postgresql instance using a connection uri string:

```Jai
connection_str := "postgres://<username>:<password>@<host>:<port>/<db>";
conn, success := connect(connection_str);
defer disconnect(conn);
```

Then use `conn` to execute statements…

```Jai
// Restrict schema access
success = execute(conn, "SELECT pg_catalog.set_config('search_path', 'public', false)");
```

… or execute a query and automatically parse the result into an array of any given type:

```Jai 
query :: #string END
	SELECT * FROM tourist_attractions
	WHERE city = $1 AND price < $2 AND min_age < $3
	ORDER BY name
END

Attraction :: struct {
	name: string;
	city: string;
	price: string; // Numerics are parsed into strings
	min_age: int;
	is_open: bool;
}

// Query parameters can be passed as variadic args after `query`:
city := "Vienna";
price := 50;
min_age := 18;
attractions, success = execute(conn, Attraction, query, city, price, min_age);
```

By default, `execute` fails if the result contains a column that has no corresponding member in the struct type you passed.
You can pass `ignore_unknown = true` to `execute(…)` to ignore unknown columns instead.

If your struct type contains members that aren’t present in the result (or are null), they will be left at their default values.

## Memory model

You’re responsible for freeing everything (including strings) in the result array.
Using a Pool allocator around your `execute` calls might be a good idea.

## Supported query parameter types

* All integer types
* `float` and `float64`
* `string`
* `bool`

## Supported return value column types

* `INT2`, `INT4`, `INT8`
* `FLOAT4`, `FLOAT8`
* `NUMERIC` (currently only parsed into `string` fields)
* `BOOL`
* `CHAR`, `BPCHAR`, `VARCHAR`, `NAME`, `TEXT`
* `DATE`, `TIMESTAMP`, `TIMESTAMPTZ`
* `BYTEA`
* `OID`
* `UUID`
* Custom enum types (`CREATE TYPE … AS ENUM`), which can be parsed into `string` or `enum` member fields.
