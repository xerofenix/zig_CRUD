## This is basic learning backend program written in [zig](https://ziglang.org) programming language.

## [Zap](https://zigzap.org) is a web framework that is used in this program.

## Postgres database is used for storing user data.

### Right now only Create, Read and Delete operation is available.

Want to try it out ?  
-- Prerequisit:
install [zig](https://ziglang.org) (currently works with zig 0.16.0) and [postgres](https://postgresql.org) database

1. Clone this repository

```bash
git clone https://github.com/xerofenix/zig_CRUD
```

2. Go to zig_CRUD directory

```bash
cd zig_CRUD
```

3. Rename `.env.example` file to `.env` and add your Database Credentials  
   or  
   create a `.env` file at the root of the project and copy the env variables from `.env.example` to `.env` and add your Database Credentials.

#### If your database doesn't support SSL, you need to disable SSL configuration, viz:

a. Go to `build.zig` file and comment this line `.openssl_lib_name = "ssl",`  
b. Go to `db_config.zig` and comment out this line `.tls = .{ .verify_full = null },` <br> <br> 4. Run the program

```bash
zig build run
```

5. To verify the go to [http://localhost:3000](http://localhost:3000)

### Contributions are welcome

I would love to take contributions from your side. Open a pull request if you want to add, enhance and fix something.
